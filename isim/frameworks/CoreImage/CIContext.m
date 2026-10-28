// isim CIContext: renders image recipes on the CPU in parallel horizontal bands, color-manages from the working space
// to the output space, and writes bitmaps, CGImages, image files and render destinations.
#import "CIInternal.h"

extern long sysconf(int name);

CIContextOption const kCIContextOutputColorSpace = @"output_color_space", kCIContextWorkingColorSpace = @"working_color_space",
    kCIContextWorkingFormat = @"working_format", kCIContextHighQualityDownsample = @"high_quality_downsample",
    kCIContextOutputPremultiplied = @"output_premultiplied", kCIContextCacheIntermediates = @"kCIContextCacheIntermediates",
    kCIContextUseSoftwareRenderer = @"software_renderer", kCIContextPriorityRequestLow = @"priority_request_low",
    kCIContextAllowLowPower = @"allow_low_power", kCIContextName = @"name", kCIContextMemoryLimit = @"memory_limit",
    kCIContextMemoryTarget = @"memory_target";

@implementation CIContext {
    CGContextRef _cg;
    NSDictionary *_opts;
    @public BOOL _managed; ci_space _ws; id _wsObj, _outObj; BOOL _hq, _premul;
}
+ (CIContext *)contextWithOptions:(NSDictionary *)o { return [[self alloc] initWithOptions:o]; }
+ (CIContext *)contextWithMTLDevice:(id<MTLDevice>)device { return [self contextWithOptions:nil]; }
+ (CIContext *)contextWithMTLDevice:(id<MTLDevice>)device options:(NSDictionary *)o { return [self contextWithOptions:o]; }
+ (CIContext *)contextWithMTLCommandQueue:(id<MTLCommandQueue>)queue { return [self contextWithOptions:nil]; }
+ (CIContext *)contextWithMTLCommandQueue:(id<MTLCommandQueue>)queue options:(NSDictionary *)o { return [self contextWithOptions:o]; }
+ (CIContext *)context { return [self new]; }
+ (CIContext *)contextWithCGContext:(CGContextRef)c options:(NSDictionary *)o {
    CIContext *x = [[self alloc] initWithOptions:o];
    if (c) x->_cg = (CGContextRef)CFRetain(c);
    return x;
}
- (instancetype)init { return [self initWithOptions:nil]; }
- (instancetype)initWithOptions:(NSDictionary *)o {
    if (!(self = [super init])) return nil;
    _opts = [o copy] ?: @{};
    _managed = YES; _ws = ci_space_linear;
    id ws = _opts[kCIContextWorkingColorSpace];
    if (ci_is_null(ws)) _managed = NO;
    else if (ci_is_cgspace(ws)) { _wsObj = ws; _ws = ci_space_of((__bridge CGColorSpaceRef)ws); }
    id os = _opts[kCIContextOutputColorSpace];
    if (ci_is_cgspace(os)) _outObj = os;
    else if (ci_is_null(os)) _outObj = [NSNull null];
    _hq = _opts[kCIContextHighQualityDownsample] ? [_opts[kCIContextHighQualityDownsample] boolValue] : NO;
    _premul = _opts[kCIContextOutputPremultiplied] ? [_opts[kCIContextOutputPremultiplied] boolValue] : YES;
    return self;
}
- (void)dealloc { if (_cg) CFRelease(_cg); }
- (CGColorSpaceRef)workingColorSpace {
    if (!_managed) return NULL;
    return _wsObj ? (__bridge CGColorSpaceRef)_wsObj : ci_cgspace_named(kCGColorSpaceExtendedLinearSRGB);
}
- (CIFormat)workingFormat { id f = _opts[kCIContextWorkingFormat]; return f ? (CIFormat)[f intValue] : kCIFormatRGBAh; }
- (void)clearCaches {}
- (void)reclaimResources {}
- (CGSize)inputImageMaximumSize { return CGSizeMake(16384, 16384); }
- (CGSize)outputImageMaximumSize { return CGSizeMake(16384, 16384); }
- (CIImage *)calculateHDRStatsForImage:(CIImage *)image {
    CGRect e = image.extent;
    if (CGRectIsEmpty(e) || ci_infinite(e)) return nil;
    CIImage *mx = [image imageByApplyingFilter:@"CIAreaMaximum" withInputParameters:@{ kCIInputExtentKey: [CIVector vectorWithCGRect:e] }];
    CIImage *av = [image imageByApplyingFilter:@"CIAreaAverage" withInputParameters:@{ kCIInputExtentKey: [CIVector vectorWithCGRect:e] }];
    CGColorSpaceRef lin = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearSRGB);
    float m[4] = { 0 }, a[4] = { 0 };
    [self render:mx toBitmap:m rowBytes:16 bounds:CGRectMake(0, 0, 1, 1) format:kCIFormatRGBAf colorSpace:lin];
    [self render:av toBitmap:a rowBytes:16 bounds:CGRectMake(0, 0, 1, 1) format:kCIFormatRGBAf colorSpace:lin];
    CGColorSpaceRelease(lin);
    float peak = fmaxf(m[0], fmaxf(m[1], m[2])), mean = 0.2126f * a[0] + 0.7152f * a[1] + 0.0722f * a[2];
    return [[image imageBySettingContentHeadroom:fmaxf(1, peak)] imageBySettingContentAverageLightLevel:fmaxf(0, mean)];
}
- (NSString *)description { return [NSString stringWithFormat:@"<CIContext: %p (CPU)%@>", self, _opts[kCIContextName] ? [@" " stringByAppendingString:_opts[kCIContextName]] : @""]; }
- (ci_rctx)_rctx {
    ci_rctx rc = ci_rctx_default();
    rc.managed = _managed; rc.ws = _ws; rc.hq = _hq; rc.context = self;
    return rc;
}

/* ---- rendering ---- */
typedef struct { __unsafe_unretained CIImage *im; CGRect r; float *out; ci_rctx rc; int band, nbands; int rows; } band_job;
static void *band_main(void *arg) {
    band_job *j = arg;
    @autoreleasepool {
        int H = (int)j->r.size.height, W = (int)j->r.size.width;
        for (int b = j->band; b < (H + j->rows - 1) / j->rows; b += j->nbands) {
            int y0 = b * j->rows, y1 = y0 + j->rows > H ? H : y0 + j->rows;
            CGRect br = CGRectMake(j->r.origin.x, j->r.origin.y + H - y1, W, y1 - y0);
            [j->im _render:br into:j->out + (size_t)y0 * W * 4 ctx:&j->rc];
        }
    }
    return NULL;
}
static float *render_ex(CIContext *ctx, CIImage *im, CGRect r, CGColorSpaceRef outSpace, int match);
float *ci_context_render(CIContext *ctx, CIImage *im, CGRect r, CGColorSpaceRef outSpace) { return render_ex(ctx, im, r, outSpace, 1); }
static float *render_ex(CIContext *ctx, CIImage *im, CGRect r, CGColorSpaceRef outSpace, int match) {
    r = CGRectIntegral(r);
    int W = (int)r.size.width, H = (int)r.size.height;
    if (W <= 0 || H <= 0) return NULL;
    if ((double)W * H > 268e6) { NSLog(@"isim: CIContext: %dx%d is too large to render", W, H); return NULL; }
    float *out = calloc((size_t)W * H * 4, sizeof(float));
    ci_rctx rc = ctx ? [ctx _rctx] : ci_rctx_default();
    rc.cache = ci_cache_new();
    long ncpu = sysconf(58);
    int rows = 64, nb = (H + rows - 1) / rows;
    int nt = (int)(ncpu < 1 ? 1 : ncpu > 16 ? 16 : ncpu);
    if (nt > nb) nt = nb;
    if ((double)W * H < 64 * 64) nt = 1;
    band_job jobs[16]; pthread_t th[16];
    for (int t = 0; t < nt; t++) { jobs[t] = (band_job){ im, r, out, rc, t, nt, rows }; }
    for (int t = 1; t < nt; t++) pthread_create(&th[t], NULL, band_main, &jobs[t]);
    band_main(&jobs[0]);
    for (int t = 1; t < nt; t++) pthread_join(th[t], NULL);
    ci_cache_free(rc.cache);
    /* working space -> output space */
    if (rc.managed && match) {
        ci_space os = outSpace ? ci_space_of(outSpace) : ci_space_srgb;
        ci_convert(out, (size_t)W * H, rc.ws, os);
    }
    return out;
}
CGImageRef ci_cgimage_from(const float *px, int w, int h, CGColorSpaceRef space) {
    /* isim CGImages hold 8-bit sRGB pixels (CoreGraphics draws them as sRGB); the requested space is a tag */
    unsigned char *b = malloc((size_t)w * h * 4 + 4);
    for (size_t i = 0; i < (size_t)w * h; i++) {
        float a = ci_clamp01(px[i * 4 + 3]);
        for (int c = 0; c < 3; c++) b[i * 4 + c] = (unsigned char)lroundf(fminf(ci_clamp01(px[i * 4 + c]), a) * 255);
        b[i * 4 + 3] = (unsigned char)lroundf(a * 255);
    }
    int hd = isim_image_from_pixels(b, w, h, w * 4, ISIM_PX_RGBA_PREMUL, 4);
    free(b);
    CGImageRef cg = isim_cg_image_with_handle(hd);
    if (cg && space && CGColorSpaceGetNumberOfComponents(space) == 3 && !ci_space_eq(ci_space_of(space), ci_space_srgb)) {
        CGImageRef t = CGImageCreateCopyWithColorSpace(cg, space);
        if (t) { CGImageRelease(cg); cg = t; }
    }
    return cg;
}
- (CGColorSpaceRef)_outSpace:(CGColorSpaceRef)given {
    if (given) return given;
    if (_outObj && _outObj != [NSNull null]) return (__bridge CGColorSpaceRef)_outObj;
    return ci_cgspace_named(kCGColorSpaceSRGB);
}
- (CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)r { return [self createCGImage:image fromRect:r format:kCIFormatRGBA8 colorSpace:nil]; }
- (CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)r format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    if (!image || ci_infinite(r)) { NSLog(@"isim: CIContext: cannot render an infinite rect; crop the image first"); return NULL; }
    r = CGRectIntegral(r);
    if (r.size.width < 1 || r.size.height < 1) return NULL;
    CGColorSpaceRef out = [self _outSpace:cs];
    /* the CGImage's pixels are sRGB on isim: render to sRGB and tag the requested space */
    float *px = ci_context_render(self, image, r, ci_cgspace_named(kCGColorSpaceSRGB));
    if (!px) return NULL;
    CGImageRef cg = ci_cgimage_from(px, (int)r.size.width, (int)r.size.height, out);
    free(px);
    return cg;
}
- (CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)r format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs deferred:(BOOL)deferred {
    return [self createCGImage:image fromRect:r format:f colorSpace:cs];
}
- (void)render:(CIImage *)image toBitmap:(void *)data rowBytes:(ptrdiff_t)rb bounds:(CGRect)r format:(CIFormat)fmt colorSpace:(CGColorSpaceRef)cs {
    if (!image || !data || ci_infinite(r)) return;
    r = CGRectIntegral(r);
    /* nil: no color matching (the working space's values, as on iOS) */
    BOOL match = cs != NULL;
    float *px = render_ex(self, image, r, cs ?: [self _outSpace:NULL], match);
    if (!px) return;
    int W = (int)r.size.width, H = (int)r.size.height;
    if (!_premul) for (size_t i = 0; i < (size_t)W * H; i++) ci_unpremul(px + i * 4);
    ci_store(px, W, H, data, rb, fmt);
    free(px);
}
- (void)drawImage:(CIImage *)image inRect:(CGRect)in fromRect:(CGRect)from {
    CGImageRef cg = [self createCGImage:image fromRect:from];
    if (!cg) return;
    CGContextDrawImage(_cg ?: isim_cg_current_context(), in, cg);
    CGImageRelease(cg);
}
- (void)drawImage:(CIImage *)image atPoint:(CGPoint)p fromRect:(CGRect)from {
    [self drawImage:image inRect:CGRectMake(p.x, p.y, from.size.width, from.size.height) fromRect:from];
}
@end

/* ================= image representations ================= */
CIImageRepresentationOption const kCIImageRepresentationAVDepthData = @"kCIImageRepresentationAVDepthData",
    kCIImageRepresentationDepthImage = @"kCIImageRepresentationDepthImage", kCIImageRepresentationDisparityImage = @"kCIImageRepresentationDisparityImage",
    kCIImageRepresentationAVPortraitEffectsMatte = @"kCIImageRepresentationAVPortraitEffectsMatte",
    kCIImageRepresentationPortraitEffectsMatteImage = @"kCIImageRepresentationPortraitEffectsMatteImage",
    kCIImageRepresentationAVSemanticSegmentationMattes = @"kCIImageRepresentationAVSemanticSegmentationMattes",
    kCIImageRepresentationSemanticSegmentationSkinMatteImage = @"kCIImageRepresentationSemanticSegmentationSkinMatteImage",
    kCIImageRepresentationSemanticSegmentationHairMatteImage = @"kCIImageRepresentationSemanticSegmentationHairMatteImage",
    kCIImageRepresentationSemanticSegmentationTeethMatteImage = @"kCIImageRepresentationSemanticSegmentationTeethMatteImage",
    kCIImageRepresentationSemanticSegmentationGlassesMatteImage = @"kCIImageRepresentationSemanticSegmentationGlassesMatteImage",
    kCIImageRepresentationSemanticSegmentationSkyMatteImage = @"kCIImageRepresentationSemanticSegmentationSkyMatteImage",
    kCIImageRepresentationHDRImage = @"kCIImageRepresentationHDRImage", kCIImageRepresentationHDRGainMapImage = @"kCIImageRepresentationHDRGainMapImage";

static NSError *rep_error(NSString *msg) {
    return [NSError errorWithDomain:@"CIContextErrorDomain" code:1 userInfo:@{ NSLocalizedDescriptionKey: msg }];
}
/* minimal uncompressed TIFF (RGBA, 8 or 16 bits per sample, associated alpha) */
static NSData *tiff_encode(const float *px, int w, int h, int bits) {
    NSMutableData *d = [NSMutableData data];
    int bps = bits / 8;
    size_t img = (size_t)w * h * 4 * bps;
    uint8_t hdr[8] = { 'I', 'I', 42, 0, 8, 0, 0, 0 };
    [d appendBytes:hdr length:8];
    enum { N = 11 };
    uint32_t bits_off = 8 + 2 + 12 * N + 4, data_off = bits_off + 8;    /* IFD, BitsPerSample values, pixels */
    struct { uint16_t tag, type; uint32_t count, value; } e[N] = {
        { 256, 4, 1, (uint32_t)w }, { 257, 4, 1, (uint32_t)h }, { 258, 3, 4, bits_off }, { 259, 3, 1, 1 }, { 262, 3, 1, 2 },
        { 273, 4, 1, data_off }, { 277, 3, 1, 4 }, { 278, 4, 1, (uint32_t)h }, { 279, 4, 1, (uint32_t)img }, { 284, 3, 1, 1 },
        { 338, 3, 1, 1 },
    };
    uint16_t cnt = N; [d appendBytes:&cnt length:2];
    for (int i = 0; i < N; i++) [d appendBytes:&e[i] length:12];
    uint32_t next = 0; [d appendBytes:&next length:4];
    uint16_t bv[4] = { (uint16_t)bits, (uint16_t)bits, (uint16_t)bits, (uint16_t)bits }; [d appendBytes:bv length:8];
    for (size_t i = 0; i < (size_t)w * h; i++) {
        float a = ci_clamp01(px[i * 4 + 3]);
        for (int c = 0; c < 4; c++) {
            float v = c == 3 ? a : fminf(ci_clamp01(px[i * 4 + c]), a);
            if (bits == 8) { uint8_t b = (uint8_t)lroundf(v * 255); [d appendBytes:&b length:1]; }
            else { uint16_t s = (uint16_t)lroundf(v * 65535); [d appendBytes:&s length:2]; }
        }
    }
    return d;
}
/* OpenEXR (scanline, uncompressed, half RGBA, linear) */
static void exr_attr(NSMutableData *d, const char *name, const char *type, const void *v, uint32_t size) {
    [d appendBytes:name length:strlen(name) + 1]; [d appendBytes:type length:strlen(type) + 1];
    [d appendBytes:&size length:4]; [d appendBytes:v length:size];
}
static NSData *exr_encode(const float *px, int w, int h) {
    NSMutableData *d = [NSMutableData data];
    uint32_t magic = 20000630, version = 2; [d appendBytes:&magic length:4]; [d appendBytes:&version length:4];
    NSMutableData *ch = [NSMutableData data];
    for (const char *c = "ABGR"; *c; c++) {           /* channels sorted by name */
        char nm[2] = { *c, 0 }; [ch appendBytes:nm length:2];
        int32_t type = 1; uint8_t plin[4] = { 0, 0, 0, 0 }; int32_t xs = 1, ys = 1;
        [ch appendBytes:&type length:4]; [ch appendBytes:plin length:4]; [ch appendBytes:&xs length:4]; [ch appendBytes:&ys length:4];
    }
    uint8_t z = 0; [ch appendBytes:&z length:1];
    exr_attr(d, "channels", "chlist", ch.bytes, (uint32_t)ch.length);
    uint8_t comp = 0; exr_attr(d, "compression", "compression", &comp, 1);
    int32_t box[4] = { 0, 0, w - 1, h - 1 };
    exr_attr(d, "dataWindow", "box2i", box, 16); exr_attr(d, "displayWindow", "box2i", box, 16);
    uint8_t order = 0; exr_attr(d, "lineOrder", "lineOrder", &order, 1);
    float par = 1; exr_attr(d, "pixelAspectRatio", "float", &par, 4);
    float swc[2] = { 0, 0 }; exr_attr(d, "screenWindowCenter", "v2f", swc, 8);
    float sww = 1; exr_attr(d, "screenWindowWidth", "float", &sww, 4);
    [d appendBytes:&z length:1];
    uint64_t table = d.length + (uint64_t)h * 8, line = 8 + (uint64_t)w * 4 * 2;
    for (int y = 0; y < h; y++) { uint64_t off = table + (uint64_t)y * line; [d appendBytes:&off length:8]; }
    static const int chan[4] = { 3, 2, 1, 0 };   /* A B G R */
    for (int y = 0; y < h; y++) {
        int32_t yy = y; uint32_t size = (uint32_t)(w * 4 * 2);
        [d appendBytes:&yy length:4]; [d appendBytes:&size length:4];
        for (int c = 0; c < 4; c++) for (int x = 0; x < w; x++) {
            uint16_t hv = ci_f2h(px[((size_t)y * w + x) * 4 + chan[c]]); [d appendBytes:&hv length:2];
        }
    }
    return d;
}
@implementation CIContext (ImageRepresentation)
- (NSData *)_encode:(CIImage *)image type:(NSString *)type space:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    if (!image || ci_infinite(image.extent) || CGRectIsEmpty(image.extent)) return nil;
    CGImageRef cg = [self createCGImage:image fromRect:image.extent format:kCIFormatRGBA8 colorSpace:cs];
    if (!cg) return nil;
    NSMutableData *d = [NSMutableData data];
    NSMutableArray *aux = [NSMutableArray array];        /* auxiliary images become extra frames tagged by type */
    NSDictionary *map = @{ kCIImageRepresentationDepthImage: kCIImageAuxiliaryDepth, kCIImageRepresentationDisparityImage: kCIImageAuxiliaryDisparity,
                           kCIImageRepresentationPortraitEffectsMatteImage: kCIImageAuxiliaryPortraitEffectsMatte,
                           kCIImageRepresentationSemanticSegmentationSkinMatteImage: kCIImageAuxiliarySemanticSegmentationSkinMatte,
                           kCIImageRepresentationSemanticSegmentationHairMatteImage: kCIImageAuxiliarySemanticSegmentationHairMatte,
                           kCIImageRepresentationSemanticSegmentationTeethMatteImage: kCIImageAuxiliarySemanticSegmentationTeethMatte,
                           kCIImageRepresentationSemanticSegmentationGlassesMatteImage: kCIImageAuxiliarySemanticSegmentationGlassesMatte,
                           kCIImageRepresentationSemanticSegmentationSkyMatteImage: kCIImageAuxiliarySemanticSegmentationSkyMatte,
                           kCIImageRepresentationHDRGainMapImage: kCIImageAuxiliaryHDRGainMap };
    for (NSString *k in map) if ([o[k] isKindOfClass:[CIImage class]]) [aux addObject:@[ map[k], o[k] ]];
    BOOL gif = [type isEqualToString:@"com.compuserve.gif"];
    CGImageDestinationRef dst = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)d, (__bridge CFStringRef)type, 1 + (gif ? 0 : aux.count), NULL);
    if (!dst) { CGImageRelease(cg); return nil; }
    NSMutableDictionary *props = [NSMutableDictionary dictionary];
    id q = o[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality];
    props[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = q ?: @(0.9);
    if (image.properties.count) [props addEntriesFromDictionary:image.properties];
    props[(__bridge NSString *)kCGImagePropertyOrientation] = image.properties[(__bridge NSString *)kCGImagePropertyOrientation] ?: @1;
    CGImageDestinationAddImage(dst, cg, (__bridge CFDictionaryRef)props);
    CGImageRelease(cg);
    for (NSArray *a in aux) {
        CIImage *im = a[1];
        CGImageRef ac = [self createCGImage:im fromRect:im.extent];
        if (!ac) continue;
        CGImageDestinationAddImage(dst, ac, (__bridge CFDictionaryRef)@{ @"{isimAuxiliary}": @{ @"type": a[0] } });
        CGImageRelease(ac);
    }
    BOOL ok = CGImageDestinationFinalize(dst);
    CFRelease(dst);
    return ok ? d : nil;
}
- (NSData *)TIFFRepresentationOfImage:(CIImage *)image format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    if (!image || ci_infinite(image.extent) || CGRectIsEmpty(image.extent)) return nil;
    CGRect r = CGRectIntegral(image.extent);
    float *px = ci_context_render(self, image, r, cs);
    if (!px) return nil;
    ci_fmt fm; ci_fmt_of(f, &fm);
    NSData *d = tiff_encode(px, (int)r.size.width, (int)r.size.height, fm.bytes >= 2 ? 16 : 8);
    free(px);
    return d;
}
- (NSData *)JPEGRepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    return [self _encode:image type:@"public.jpeg" space:cs options:o];
}
- (NSData *)PNGRepresentationOfImage:(CIImage *)image format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    return [self _encode:image type:@"public.png" space:cs options:o];
}
- (NSData *)HEIFRepresentationOfImage:(CIImage *)image format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    NSData *d = [self _encode:image type:@"public.heic" space:cs options:o];
    if (!d) NSLog(@"isim: CIContext: HEIF needs the host's ffmpeg with libx265 (isim's HEIF writer)");
    return d;
}
- (NSData *)HEIF10RepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o error:(NSError **)err {
    /* isim's HEIF writer stores 8 bits per sample: the 10-bit variant writes the same file */
    NSData *d = [self HEIFRepresentationOfImage:image format:kCIFormatRGBA8 colorSpace:cs options:o];
    if (!d && err) *err = rep_error(@"HEIF encoding is not available (needs the host's ffmpeg with libx265)");
    return d;
}
- (NSData *)OpenEXRRepresentationOfImage:(CIImage *)image options:(NSDictionary *)o error:(NSError **)err {
    if (!image || ci_infinite(image.extent) || CGRectIsEmpty(image.extent)) { if (err) *err = rep_error(@"the image has no finite extent"); return nil; }
    CGRect r = CGRectIntegral(image.extent);
    float *px = ci_context_render(self, image, r, ci_cgspace_named(kCGColorSpaceExtendedLinearSRGB));
    if (!px) { if (err) *err = rep_error(@"render failed"); return nil; }
    NSData *d = exr_encode(px, (int)r.size.width, (int)r.size.height);
    free(px);
    return d;
}
static BOOL write_rep(NSData *d, NSURL *url, NSError **err) {
    if (!d) { if (err && !*err) *err = rep_error(@"the image could not be encoded"); return NO; }
    return [d writeToURL:url options:NSDataWritingAtomic error:err];
}
- (BOOL)writeTIFFRepresentationOfImage:(CIImage *)i toURL:(NSURL *)u format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o error:(NSError **)e {
    return write_rep([self TIFFRepresentationOfImage:i format:f colorSpace:cs options:o], u, e);
}
- (BOOL)writePNGRepresentationOfImage:(CIImage *)i toURL:(NSURL *)u format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o error:(NSError **)e {
    return write_rep([self PNGRepresentationOfImage:i format:f colorSpace:cs options:o], u, e);
}
- (BOOL)writeJPEGRepresentationOfImage:(CIImage *)i toURL:(NSURL *)u colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o error:(NSError **)e {
    return write_rep([self JPEGRepresentationOfImage:i colorSpace:cs options:o], u, e);
}
- (BOOL)writeHEIFRepresentationOfImage:(CIImage *)i toURL:(NSURL *)u format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o error:(NSError **)e {
    return write_rep([self HEIFRepresentationOfImage:i format:f colorSpace:cs options:o], u, e);
}
- (BOOL)writeHEIF10RepresentationOfImage:(CIImage *)i toURL:(NSURL *)u colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o error:(NSError **)e {
    return write_rep([self HEIF10RepresentationOfImage:i colorSpace:cs options:o error:e], u, e);
}
- (BOOL)writeOpenEXRRepresentationOfImage:(CIImage *)i toURL:(NSURL *)u options:(NSDictionary *)o error:(NSError **)e {
    return write_rep([self OpenEXRRepresentationOfImage:i options:o error:e], u, e);
}
@end

/* ================= depth blur effect ================= */
@implementation CIContext (CIDepthBlurEffect)
- (CIFilter *)depthBlurEffectFilterForImageURL:(NSURL *)url options:(NSDictionary *)o {
    NSData *d = [NSData dataWithContentsOfURL:url];
    return d ? [self depthBlurEffectFilterForImageData:d options:o] : nil;
}
- (CIFilter *)depthBlurEffectFilterForImageData:(NSData *)data options:(NSDictionary *)o {
    CIImage *im = [CIImage imageWithData:data options:@{ kCIImageApplyOrientationProperty: @YES }];
    CIImage *disp = [CIImage imageWithData:data options:@{ kCIImageAuxiliaryDisparity: @YES }];
    if (!disp) {
        CIImage *depth = [CIImage imageWithData:data options:@{ kCIImageAuxiliaryDepth: @YES }];
        if (depth) disp = [depth imageByApplyingFilter:@"CIDepthToDisparity"];
    }
    if (!im || !disp) return nil;
    CIImage *matte = [CIImage imageWithData:data options:@{ kCIImageAuxiliaryPortraitEffectsMatte: @YES }];
    return [self depthBlurEffectFilterForImage:im disparityImage:disp portraitEffectsMatte:matte orientation:kCGImagePropertyOrientationUp options:o];
}
- (CIFilter *)depthBlurEffectFilterForImage:(CIImage *)image disparityImage:(CIImage *)d portraitEffectsMatte:(CIImage *)m
                                orientation:(CGImagePropertyOrientation)or options:(NSDictionary *)o {
    return [self depthBlurEffectFilterForImage:image disparityImage:d portraitEffectsMatte:m hairSemanticSegmentation:nil glassesMatte:nil gainMap:nil orientation:or options:o];
}
- (CIFilter *)depthBlurEffectFilterForImage:(CIImage *)image disparityImage:(CIImage *)d portraitEffectsMatte:(CIImage *)m
                   hairSemanticSegmentation:(CIImage *)hair orientation:(CGImagePropertyOrientation)or options:(NSDictionary *)o {
    return [self depthBlurEffectFilterForImage:image disparityImage:d portraitEffectsMatte:m hairSemanticSegmentation:hair glassesMatte:nil gainMap:nil orientation:or options:o];
}
- (CIFilter *)depthBlurEffectFilterForImage:(CIImage *)image disparityImage:(CIImage *)d portraitEffectsMatte:(CIImage *)m
                   hairSemanticSegmentation:(CIImage *)hair glassesMatte:(CIImage *)glasses gainMap:(CIImage *)gain
                                orientation:(CGImagePropertyOrientation)or options:(NSDictionary *)o {
    if (!image || !d) return nil;
    CIFilter *f = [CIFilter filterWithName:@"CIDepthBlurEffect"];
    [f setValue:or > 1 ? [image imageByApplyingCGOrientation:or] : image forKey:kCIInputImageKey];
    [f setValue:or > 1 ? [d imageByApplyingCGOrientation:or] : d forKey:@"inputDisparityImage"];
    if (m) [f setValue:m forKey:@"inputMatteImage"];
    if (hair) [f setValue:hair forKey:@"inputHairImage"];
    if (glasses) [f setValue:glasses forKey:@"inputGlassesImage"];
    if (gain) [f setValue:gain forKey:@"inputGainMap"];
    [f setValue:@(4.5) forKey:@"inputAperture"];
    for (NSString *k in o) if ([k hasPrefix:@"input"]) [f setValue:o[k] forKey:k];
    return f;
}
@end

/* ================= render destinations ================= */
@interface CIRenderDestination ()
@property (nonatomic) void *isimData;
@property (nonatomic) NSUInteger isimRowBytes;
@property (nonatomic) CIFormat isimFormat;
@property (nonatomic, copy) void (^isimWriteBack)(void);       /* CVPixelBuffer destinations (Swift overlay) */
@end
@implementation CIRenderDestination { id _cs; }
- (instancetype)initWithBitmapData:(void *)data width:(NSUInteger)w height:(NSUInteger)h bytesPerRow:(NSUInteger)bpr format:(CIFormat)f {
    if (!(self = [super init])) return nil;
    _isimData = data; _width = w; _height = h; _isimRowBytes = bpr; _isimFormat = f;
    ci_fmt fm; ci_fmt_of(f, &fm);
    _alphaMode = fm.alpha ? CIRenderDestinationAlphaPremultiplied : CIRenderDestinationAlphaNone;
    _clamped = !fm.isfloat;
    _cs = (__bridge id)ci_cgspace_named(fm.isfloat ? kCGColorSpaceExtendedSRGB : kCGColorSpaceSRGB);
    return self;
}
@synthesize width = _width, height = _height, alphaMode = _alphaMode, flipped = _flipped, dithered = _dithered, clamped = _clamped,
    blendKernel = _blendKernel, blendsInDestinationColorSpace = _blendsInDestinationColorSpace, captureTraceURL = _captureTraceURL;
- (CGColorSpaceRef)colorSpace { return (__bridge CGColorSpaceRef)_cs; }
- (void)setColorSpace:(CGColorSpaceRef)cs { _cs = (__bridge id)cs; }
@end
@interface CIRenderInfo ()
@property (nonatomic) NSTimeInterval isimTime;
@property (nonatomic) NSInteger isimPixels, isimPasses;
@end
@implementation CIRenderInfo
- (NSTimeInterval)kernelExecutionTime { return _isimTime; }
- (NSTimeInterval)kernelCompileTime { return 0; }
- (NSInteger)passCount { return _isimPasses; }
- (NSInteger)pixelsProcessed { return _isimPixels; }
- (NSString *)description { return [NSString stringWithFormat:@"<CIRenderInfo: %p> %ld pixels, %ld pass(es), %.3f s", self, (long)_isimPixels, (long)_isimPasses, _isimTime]; }
@end
@interface CIRenderTask ()
@property (nonatomic, strong) CIRenderInfo *isimInfo;
@property (nonatomic, strong) NSError *isimError;
@end
@implementation CIRenderTask
- (CIRenderInfo *)waitUntilCompletedAndReturnError:(NSError **)error {
    if (_isimError && error) *error = _isimError;
    return _isimInfo;
}
@end

static double now_s(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
@implementation CIContext (CIRenderDestination)
- (CIRenderTask *)startTaskToRender:(CIImage *)image fromRect:(CGRect)from toDestination:(CIRenderDestination *)dst atPoint:(CGPoint)at error:(NSError **)error {
    CIRenderTask *task = [CIRenderTask new];
    if (!dst.isimData) { if (error) *error = rep_error(@"the destination has no bitmap"); return nil; }
    double t0 = now_s();
    from = CGRectIntegral(from);
    CGRect dr = CGRectIntersection(CGRectMake(at.x, at.y, from.size.width, from.size.height), CGRectMake(0, 0, dst.width, dst.height));
    if (CGRectIsNull(dr) || CGRectIsEmpty(dr)) { task.isimInfo = [CIRenderInfo new]; return task; }
    /* the source rect that lands on the destination */
    CGRect sr = CGRectMake(from.origin.x + (dr.origin.x - at.x), from.origin.y + (dr.origin.y - at.y), dr.size.width, dr.size.height);
    CIImage *im = image;
    float *px = ci_context_render(self, im, sr, dst.colorSpace);
    if (!px) { if (error) *error = rep_error(@"render failed"); return nil; }
    int W = (int)sr.size.width, H = (int)sr.size.height;
    ci_fmt fm; ci_fmt_of(dst.isimFormat, &fm);
    if (dst.alphaMode == CIRenderDestinationAlphaUnpremultiplied) for (size_t i = 0; i < (size_t)W * H; i++) ci_unpremul(px + i * 4);
    if (dst.alphaMode == CIRenderDestinationAlphaNone) for (size_t i = 0; i < (size_t)W * H; i++) { ci_unpremul(px + i * 4); px[i * 4 + 3] = 1; }
    if (dst.clamped) for (size_t i = 0; i < (size_t)W * H * 4; i++) px[i] = ci_clamp01(px[i]);
    if (dst.dithered && !fm.isfloat) {     /* ±0.5 LSB of ordered dither before quantizing */
        static const float bayer[4][4] = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } };
        float lsb = fm.bytes == 1 ? 1 / 255.0f : 1 / 65535.0f;
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            float d = (bayer[y & 3][x & 3] / 16.0f - 0.5f) * lsb;
            for (int c = 0; c < 3; c++) px[((size_t)y * W + x) * 4 + c] += d;
        }
    }
    /* destination rows: top-down unless flipped (then row 0 is the bottom) */
    int top = (int)(dst.height - dr.origin.y - dr.size.height);
    size_t pixbytes = (size_t)fm.ch * fm.bytes;
    if (dst.blendKernel) {
        /* blend over the destination's current pixels: read them, blend in the destination's working values */
        float *cur = ci_load(dst.isimData, (int)dst.width, (int)dst.height, (ptrdiff_t)dst.isimRowBytes, dst.isimFormat, 1);
        if (cur) {
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                int row = dst.flipped ? (int)dr.origin.y + (H - 1 - j) : top + j;
                float *d = cur + ((size_t)row * dst.width + (int)dr.origin.x + i) * 4, *s = px + ((size_t)j * W + i) * 4;
                float o[4]; ci_blend_apply(dst.blendKernel, s, d, o); memcpy(s, o, sizeof o);
            }
            free(cur);
        }
    }
    for (int j = 0; j < H; j++) {
        int row = dst.flipped ? (int)dr.origin.y + (H - 1 - j) : top + j;
        uint8_t *dp = (uint8_t *)dst.isimData + (size_t)row * dst.isimRowBytes + (size_t)dr.origin.x * pixbytes;
        ci_store(px + (size_t)j * W * 4, W, 1, dp, (ptrdiff_t)dst.isimRowBytes, dst.isimFormat);
    }
    free(px);
    if (dst.isimWriteBack) dst.isimWriteBack();
    CIRenderInfo *info = [CIRenderInfo new];
    info.isimTime = now_s() - t0; info.isimPixels = (NSInteger)W * H; info.isimPasses = 1;
    task.isimInfo = info;
    return task;
}
- (CIRenderTask *)startTaskToRender:(CIImage *)image toDestination:(CIRenderDestination *)dst error:(NSError **)error {
    CGRect r = CGRectMake(0, 0, dst.width, dst.height);
    return [self startTaskToRender:image fromRect:r toDestination:dst atPoint:CGPointZero error:error];
}
- (BOOL)prepareRender:(CIImage *)image fromRect:(CGRect)from toDestination:(CIRenderDestination *)dst atPoint:(CGPoint)at error:(NSError **)error {
    return image != nil && dst.isimData != NULL;
}
- (CIRenderTask *)startTaskToClear:(CIRenderDestination *)dst error:(NSError **)error {
    if (!dst.isimData) { if (error) *error = rep_error(@"the destination has no bitmap"); return nil; }
    for (NSUInteger y = 0; y < dst.height; y++) {
        ci_fmt fm; ci_fmt_of(dst.isimFormat, &fm);
        memset((uint8_t *)dst.isimData + y * dst.isimRowBytes, 0, dst.width * fm.ch * fm.bytes);
    }
    if (dst.isimWriteBack) dst.isimWriteBack();
    CIRenderTask *t = [CIRenderTask new]; t.isimInfo = [CIRenderInfo new];
    return t;
}
@end
