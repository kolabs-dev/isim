// isim Core Image kernels (CIKernel, CIColorKernel, CIWarpKernel, CIBlendKernel) run by isim's interpreter
// (CIKernelLang.c), CISampler, CIFilterShape, CIImageAccumulator and CIImageProcessorKernel.
#import "CIInternal.h"
#include "CIKernelLang.h"

CI_HIDDEN int ci_blend_mode_named(NSString *name);
CI_HIDDEN void ci_blend_mode_px(int mode, const float *s, const float *d, float *o);

/* ================= CIFilterShape ================= */
@implementation CIFilterShape { CGRect _r; }
+ (instancetype)shapeWithRect:(CGRect)r { return [[self alloc] initWithRect:r]; }
- (instancetype)initWithRect:(CGRect)r { if ((self = [super init])) _r = r; return self; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (CGRect)extent { return _r; }
- (CIFilterShape *)transformBy:(CGAffineTransform)m interior:(BOOL)flag { return [CIFilterShape shapeWithRect:ci_infinite(_r) ? _r : CGRectApplyAffineTransform(_r, m)]; }
- (CIFilterShape *)insetByX:(int)dx Y:(int)dy { return [CIFilterShape shapeWithRect:ci_infinite(_r) ? _r : CGRectInset(_r, dx, dy)]; }
- (CIFilterShape *)unionWith:(CIFilterShape *)s { return [CIFilterShape shapeWithRect:CGRectUnion(_r, s.extent)]; }
- (CIFilterShape *)unionWithRect:(CGRect)r { return [CIFilterShape shapeWithRect:CGRectUnion(_r, r)]; }
- (CIFilterShape *)intersectWith:(CIFilterShape *)s { return [CIFilterShape shapeWithRect:CGRectIntersection(_r, s.extent)]; }
- (CIFilterShape *)intersectWithRect:(CGRect)r { return [CIFilterShape shapeWithRect:CGRectIntersection(_r, r)]; }
- (NSString *)description { return [NSString stringWithFormat:@"<CIFilterShape: %p> [%g %g %g %g]", self, _r.origin.x, _r.origin.y, _r.size.width, _r.size.height]; }
@end

/* ================= CISampler ================= */
NSString *const kCISamplerAffineMatrix = @"CIAffineMatrix", *const kCISamplerWrapMode = @"CIWrapMode", *const kCISamplerFilterMode = @"CIFilterMode",
    *const kCISamplerWrapBlack = @"CIWrapBlack", *const kCISamplerWrapClamp = @"CIWrapClamp", *const kCISamplerFilterNearest = @"CIFilterNearest",
    *const kCISamplerFilterLinear = @"CIFilterLinear", *const kCISamplerColorSpace = @"CIColorSpace";
@interface CISampler ()
@property (nonatomic, strong) CIImage *isimImage;
@property (nonatomic) CGAffineTransform isimMatrix;        /* image space -> sampler space */
@property (nonatomic) BOOL isimClamp, isimNearest;
@property (nonatomic, strong) id isimColorSpace;
@end
@implementation CISampler
+ (instancetype)samplerWithImage:(CIImage *)im { return [[self alloc] initWithImage:im options:nil]; }
+ (instancetype)samplerWithImage:(CIImage *)im options:(NSDictionary *)o { return [[self alloc] initWithImage:im options:o]; }
+ (instancetype)samplerWithImage:(CIImage *)im keysAndValues:(id)key0, ... {
    NSMutableDictionary *o = [NSMutableDictionary dictionary];
    va_list ap; va_start(ap, key0);
    for (id k = key0; k; k = va_arg(ap, id)) { id v = va_arg(ap, id); if (v) o[k] = v; }
    va_end(ap);
    return [[self alloc] initWithImage:im options:o];
}
- (instancetype)initWithImage:(CIImage *)im { return [self initWithImage:im options:nil]; }
- (instancetype)initWithImage:(CIImage *)im keysAndValues:(id)key0, ... {
    NSMutableDictionary *o = [NSMutableDictionary dictionary];
    va_list ap; va_start(ap, key0);
    for (id k = key0; k; k = va_arg(ap, id)) { id v = va_arg(ap, id); if (v) o[k] = v; }
    va_end(ap);
    return [self initWithImage:im options:o];
}
- (instancetype)initWithImage:(CIImage *)im options:(NSDictionary *)o {
    if (!(self = [super init])) return nil;
    _isimImage = im ?: [CIImage emptyImage];
    _isimMatrix = CGAffineTransformIdentity;
    id m = o[kCISamplerAffineMatrix];
    if ([m isKindOfClass:[NSArray class]] && [m count] >= 6) _isimMatrix = CGAffineTransformMake([m[0] doubleValue], [m[1] doubleValue], [m[2] doubleValue], [m[3] doubleValue], [m[4] doubleValue], [m[5] doubleValue]);
    else if (m) _isimMatrix = ci_xform(m);
    _isimClamp = [o[kCISamplerWrapMode] isEqual:kCISamplerWrapClamp];
    _isimNearest = [o[kCISamplerFilterMode] isEqual:kCISamplerFilterNearest] || im.isimSampling == CI_SAMPLE_NEAREST;
    _isimColorSpace = o[kCISamplerColorSpace];
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (CGRect)extent {
    CGRect e = _isimImage.extent;
    if (_isimClamp) return CGRectInfinite;
    return ci_infinite(e) ? e : CGRectApplyAffineTransform(e, _isimMatrix);
}
- (CIFilterShape *)definition { return [CIFilterShape shapeWithRect:self.extent]; }
@end

/* ================= kernels ================= */
@interface CIKernel ()
@property (nonatomic) ck_program *isimProgram;
@property (nonatomic) ck_func *isimFunc;
@property (nonatomic, strong) id isimProgramOwner;   /* keeps the program alive while kernels share it */
@property (nonatomic) int isimBlendMode;             /* built-in blend kernels: >= 0 */
@property (nonatomic) SEL isimROISelector;
@end
@interface __CIProgramBox : NSObject { @public ck_program *p; }
@end
@implementation __CIProgramBox
- (void)dealloc { ck_free(p); }
@end

static NSError *kerr(NSString *msg) { return [NSError errorWithDomain:@"CIKernel" code:1 userInfo:@{ NSLocalizedDescriptionKey: msg }]; }
/* the kernel class for a function: color kernels take only samples / colors / numbers and return a color; warp
   kernels return a position; blend kernels take exactly two samples */
static Class kind_of(ck_func *f) {
    int rn; int rk = ck_ret(f, &rn);
    BOOL hasSampler = NO; int nsample = 0, other = 0;
    for (int i = 0; i < ck_nparams(f); i++) {
        int k = ck_param(f, i, NULL);
        if (k == CK_SAMPLER) hasSampler = YES;
        else if (k == CK_SAMPLE) nsample++;
        else if (k != CK_DEST) other++;
    }
    if (rk == CK_FLOAT && rn == 2) return [CIWarpKernel class];
    if (!hasSampler && rn == 4) return nsample == 2 && other == 0 ? [CIBlendKernel class] : [CIColorKernel class];
    return [CIKernel class];
}
static NSArray *kernels_from(NSString *src, BOOL metal, NSError **error) {
    char err[256] = "";
    ck_program *pg = ck_parse(src.UTF8String, err, sizeof err);
    if (!pg) {
        NSLog(@"isim: Core Image kernel: %s", err);
        if (error) *error = kerr([NSString stringWithFormat:@"kernel did not compile: %s", err]);
        return nil;
    }
    __CIProgramBox *box = [__CIProgramBox new]; box->p = pg;
    NSMutableArray *out = [NSMutableArray array];
    for (int i = 0; i < ck_count(pg); i++) {
        ck_func *f = ck_func_at(pg, i);
        if (!metal && !ck_is_kernel(f)) continue;
        if (metal) {     /* Metal: functions with a Core Image parameter or a color result */
            BOOL ci = NO; int rn; ck_ret(f, &rn);
            for (int j = 0; j < ck_nparams(f); j++) { int k = ck_param(f, j, NULL); if (k == CK_SAMPLER || k == CK_SAMPLE || k == CK_DEST) ci = YES; }
            if (!ci) continue;
        }
        CIKernel *k = [kind_of(f) new];
        k.isimProgram = pg; k.isimFunc = f; k.isimProgramOwner = box; k.isimBlendMode = -1;
        [out addObject:k];
    }
    return out;
}
/* isim's default.metallib: the Metal sources (the isim build tools write it), "ISIMMETALLIB 1\n" + sources */
static NSString *metallib_source(NSData *data, NSError **error) {
    const char *magic = "ISIMMETALLIB";
    if (data.length >= 12 && !memcmp(data.bytes, magic, 12)) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSRange nl = [s rangeOfString:@"\n"];
        return nl.location == NSNotFound ? @"" : [s substringFromIndex:nl.location + 1];
    }
    if (data.length >= 4 && !memcmp(data.bytes, "MTLB", 4)) {
        NSLog(@"isim: Core Image: this metallib holds Apple GPU code (built by Xcode); isim runs Core Image kernels from the Metal sources in a default.metallib built by isim");
        if (error) *error = kerr(@"Apple-compiled Metal libraries cannot run on isim; build the app with isim so default.metallib holds the kernel sources");
        return nil;
    }
    if (error) *error = kerr(@"not a Metal library");
    return nil;
}

typedef struct {
    ck_host h;
    double dx, dy;
    ci_buf *bufs; CGAffineTransform *inv; int *mode; int *clamp; CGRect *ext; int n;
} khost;
static void kh_dest(ck_host *h, double *x, double *y) { khost *k = (khost *)h; *x = k->dx; *y = k->dy; }
static void kh_sample(ck_host *h, int s, double x, double y, float out[4]) {
    khost *k = (khost *)h;
    if (s < 0 || s >= k->n) { out[0] = out[1] = out[2] = out[3] = 0; return; }
    CGPoint p = CGPointApplyAffineTransform(CGPointMake(x, y), k->inv[s]);     /* sampler space -> image space */
    if (k->clamp[s]) ci_sample_clamped(&k->bufs[s], p.x, p.y, k->mode[s], out); else ci_sample(&k->bufs[s], p.x, p.y, k->mode[s], out);
}
static void kh_transform(ck_host *h, int s, double x, double y, double *ox, double *oy) { *ox = x; *oy = y; }
static void kh_extent(ck_host *h, int s, double e[4]) {
    khost *k = (khost *)h;
    CGRect r = s >= 0 && s < k->n ? k->ext[s] : CGRectZero;
    if (ci_infinite(r)) r = CGRectMake(-1e9, -1e9, 2e9, 2e9);
    e[0] = r.origin.x; e[1] = r.origin.y; e[2] = r.size.width; e[3] = r.size.height;
}

/* converts an argument to a kernel parameter */
static BOOL arg_value(id a, int kind, const ci_rctx *rc, ck_arg *out) {
    memset(out, 0, sizeof *out);
    if ([a isKindOfClass:[NSNumber class]]) { out->n = 1; out->v[0] = [a floatValue]; return YES; }
    if ([a isKindOfClass:[CIVector class]]) { CIVector *v = a; out->n = (int)MIN(v.count, 16); for (int i = 0; i < out->n; i++) out->v[i] = (float)[v valueAtIndex:i]; return YES; }
    if ([a isKindOfClass:[CIColor class]]) { out->n = 4; ci_color_ws(a, rc, out->v); return YES; }
    if ([a isKindOfClass:[NSValue class]]) {
        const char *t = [a objCType];
        if (!strcmp(t, @encode(CGPoint))) { CGPoint p = [a CGPointValue]; out->n = 2; out->v[0] = (float)p.x; out->v[1] = (float)p.y; return YES; }
        if (!strcmp(t, @encode(CGRect))) { CGRect r = [a CGRectValue]; out->n = 4; out->v[0] = (float)r.origin.x; out->v[1] = (float)r.origin.y; out->v[2] = (float)r.size.width; out->v[3] = (float)r.size.height; return YES; }
        if (!strcmp(t, @encode(CGAffineTransform))) { CGAffineTransform x = [a CGAffineTransformValue]; float v[6] = { (float)x.a, (float)x.b, (float)x.c, (float)x.d, (float)x.tx, (float)x.ty }; out->n = 6; memcpy(out->v, v, sizeof v); return YES; }
    }
    if ([a isKindOfClass:[NSData class]]) { NSData *d = a; out->n = (int)MIN(d.length / sizeof(float), 16); memcpy(out->v, d.bytes, sizeof(float) * out->n); return YES; }
    return NO;
}

@implementation CIKernel
+ (NSArray<CIKernel *> *)kernelsWithString:(NSString *)s { return kernels_from(s, NO, NULL); }
+ (NSArray<CIKernel *> *)kernelsWithMetalString:(NSString *)s error:(NSError **)e { return kernels_from(s, YES, e); }
+ (instancetype)kernelWithString:(NSString *)s {
    for (CIKernel *k in kernels_from(s, NO, NULL)) if ([k isKindOfClass:self]) return k;
    return nil;
}
+ (instancetype)kernelWithFunctionName:(NSString *)name fromMetalLibraryData:(NSData *)data error:(NSError **)error {
    return [self kernelWithFunctionName:name fromMetalLibraryData:data outputPixelFormat:0 error:error];
}
+ (instancetype)kernelWithFunctionName:(NSString *)name fromMetalLibraryData:(NSData *)data outputPixelFormat:(CIFormat)fmt error:(NSError **)error {
    NSString *src = metallib_source(data, error);
    if (!src) return nil;
    char err[256] = "";
    ck_program *pg = ck_parse(src.UTF8String, err, sizeof err);
    if (!pg) { if (error) *error = kerr([NSString stringWithFormat:@"the Metal source did not parse: %s", err]); NSLog(@"isim: Core Image: %s", err); return nil; }
    ck_func *f = ck_find(pg, name.UTF8String);
    if (!f) { ck_free(pg); if (error) *error = kerr([NSString stringWithFormat:@"no function named %@ in the Metal library", name]); return nil; }
    __CIProgramBox *box = [__CIProgramBox new]; box->p = pg;
    Class c = kind_of(f);
    if (self != [CIKernel class] && ![c isSubclassOfClass:self] && !(self == [CIColorKernel class] && c == [CIBlendKernel class])) {
        if (error) *error = kerr([NSString stringWithFormat:@"%@ is not a %@", name, NSStringFromClass(self)]);
        return nil;
    }
    CIKernel *k = [(self == [CIKernel class] ? c : self) new];
    k.isimProgram = pg; k.isimFunc = f; k.isimProgramOwner = box; k.isimBlendMode = -1;
    return k;
}
+ (NSArray<NSString *> *)kernelNamesFromMetalLibraryData:(NSData *)data {
    NSMutableArray *names = [NSMutableArray array];
    for (CIKernel *k in kernels_from(metallib_source(data, NULL) ?: @"", YES, NULL)) [names addObject:k.name];
    return names;
}
- (NSString *)name { return self.isimFunc ? @(ck_name(self.isimFunc)) : self.isimBlendMode >= 0 ? @"blend" : @""; }
- (BOOL)setROISelector:(SEL)method { self.isimROISelector = method; return YES; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p> %@", NSStringFromClass([self class]), self, self.name]; }

/* the general apply: samplers (CIImage / CISampler) are rendered over their region of interest */
- (CIImage *)applyWithExtent:(CGRect)extent roiCallback:(CIKernelROICallback)roi arguments:(NSArray *)args {
    ck_func *f = self.isimFunc;
    if (!f) return nil;
    int np = ck_nparams(f);
    NSMutableArray *params = [NSMutableArray array];       /* the argument for each parameter (NSNull for destination) */
    int ai = 0;
    for (int i = 0; i < np; i++) {
        int k = ck_param(f, i, NULL);
        if (k == CK_DEST) { [params addObject:[NSNull null]]; continue; }
        if (ai >= (int)args.count) { NSLog(@"isim: Core Image: kernel %@ needs %d arguments", self.name, np); return nil; }
        [params addObject:args[ai++]];
    }
    __strong id owner = self.isimProgramOwner;
    ck_program *pg = self.isimProgram;
    CIKernelROICallback cb = [roi copy];
    BOOL color = [self isKindOfClass:[CIColorKernel class]];
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        (void)owner;
        int n = np;
        ci_buf bufs[24]; CGAffineTransform inv[24]; int mode[24], clamp[24], sindex[24]; CGRect ext[24];
        ck_arg cargs[24]; int ns = 0;
        float *direct[24] = { 0 };                        /* color kernels: samples rendered over r */
        for (int i = 0; i < n && i < 24; i++) {
            id a = params[i]; int k = ck_param(f, i, NULL);
            sindex[i] = -1;
            if (k == CK_DEST) { memset(&cargs[i], 0, sizeof cargs[i]); continue; }
            if (k == CK_SAMPLER || k == CK_SAMPLE) {
                CISampler *s = [a isKindOfClass:[CISampler class]] ? a : [a isKindOfClass:[CIImage class]] ? [CISampler samplerWithImage:a] : nil;
                if (!s) { memset(&cargs[i], 0, sizeof cargs[i]); continue; }
                if (k == CK_SAMPLE || color) { direct[i] = ci_render_new(s.isimImage, r, rc); continue; }
                CGRect want = cb ? cb(ns, r) : CGRectInfinite;
                if (ci_infinite(want)) want = CGRectInset(r, -16, -16);
                CGAffineTransform m = s.isimMatrix, mi = CGAffineTransformInvert(m);
                CGRect src = CGRectApplyAffineTransform(want, mi);
                bufs[ns] = ci_buf_render(s.isimClamp ? [s.isimImage imageByClampingToExtent] : s.isimImage, src, 2, rc);
                inv[ns] = mi; mode[ns] = s.isimNearest ? CI_SAMPLE_NEAREST : CI_SAMPLE_LINEAR; clamp[ns] = s.isimClamp; ext[ns] = s.extent;
                memset(&cargs[i], 0, sizeof cargs[i]); cargs[i].sampler = ns; sindex[i] = ns;
                ns++;
                continue;
            }
            if (!arg_value(a, k, rc, &cargs[i])) memset(&cargs[i], 0, sizeof cargs[i]);
        }
        khost h = { { kh_dest, kh_sample, kh_transform, kh_extent, NULL }, 0, 0, bufs, inv, mode, clamp, ext, ns };
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            h.dx = ci_px_x(r, i); h.dy = ci_px_y(r, j);
            for (int q = 0; q < n && q < 24; q++) if (direct[q]) { cargs[q].n = 4; memcpy(cargs[q].v, direct[q] + ((size_t)j * W + i) * 4, 16); }
            float o[4]; ck_run(pg, f, cargs, n, &h.h, o);
            memcpy(out + ((size_t)j * W + i) * 4, o, sizeof o);
        }
        for (int q = 0; q < ns; q++) ci_buf_free(&bufs[q]);
        for (int q = 0; q < n && q < 24; q++) free(direct[q]);
    });
}
@end

@implementation CIColorKernel
+ (instancetype)kernelWithString:(NSString *)s {
    for (CIKernel *k in kernels_from(s, NO, NULL)) if ([k isKindOfClass:[CIColorKernel class]]) return (id)k;
    NSLog(@"isim: Core Image: no color kernel in the source (a color kernel takes __sample / __color / number parameters and returns vec4)");
    return nil;
}
- (CIImage *)applyWithExtent:(CGRect)extent arguments:(NSArray *)args {
    return [self applyWithExtent:extent roiCallback:^CGRect(int i, CGRect r) { return r; } arguments:args];
}
@end

@implementation CIWarpKernel
+ (instancetype)kernelWithString:(NSString *)s {
    for (CIKernel *k in kernels_from(s, NO, NULL)) if ([k isKindOfClass:[CIWarpKernel class]]) return (id)k;
    NSLog(@"isim: Core Image: no warp kernel in the source (a warp kernel returns vec2)");
    return nil;
}
- (CIImage *)applyWithExtent:(CGRect)extent roiCallback:(CIKernelROICallback)roi inputImage:(CIImage *)image arguments:(NSArray *)args {
    ck_func *f = self.isimFunc;
    if (!f || !image) return nil;
    __strong id owner = self.isimProgramOwner;
    ck_program *pg = self.isimProgram;
    CIKernelROICallback cb = [roi copy];
    NSArray *a = [args copy] ?: @[];
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        (void)owner;
        int n = ck_nparams(f);
        ck_arg cargs[24]; int ai = 0;
        for (int i = 0; i < n && i < 24; i++) {
            int k = ck_param(f, i, NULL);
            memset(&cargs[i], 0, sizeof cargs[i]);
            if (k == CK_DEST) continue;
            if (ai < (int)a.count) arg_value(a[ai++], k, rc, &cargs[i]);
        }
        CGRect want = cb ? cb(0, r) : CGRectInfinite;
        if (ci_infinite(want)) want = CGRectInset(r, -64, -64);
        ci_buf b = ci_buf_render(image, want, 2, rc);
        khost h = { { kh_dest, kh_sample, kh_transform, kh_extent, NULL }, 0, 0, NULL, NULL, NULL, NULL, NULL, 0 };
        int W = (int)r.size.width, H = (int)r.size.height, mode = image.isimSampling;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            h.dx = ci_px_x(r, i); h.dy = ci_px_y(r, j);
            float o[4]; ck_run(pg, f, cargs, n, &h.h, o);
            ci_sample(&b, o[0], o[1], mode, out + ((size_t)j * W + i) * 4);
        }
        ci_buf_free(&b);
    });
}
@end

@implementation CIBlendKernel
+ (instancetype)kernelWithString:(NSString *)s {
    for (CIKernel *k in kernels_from(s, NO, NULL)) if ([k isKindOfClass:[CIBlendKernel class]]) return (id)k;
    NSLog(@"isim: Core Image: no blend kernel in the source (a blend kernel takes two __sample parameters)");
    return nil;
}
- (CIImage *)applyWithForeground:(CIImage *)fg background:(CIImage *)bg {
    if (!fg || !bg) return nil;
    CIBlendKernel *k = self;
    return ci_op(CGRectUnion(fg.extent, bg.extent), ^(CGRect r, float *out, const ci_rctx *rc) {
        float *s = ci_render_new(fg, r, rc);
        [bg _render:r into:out ctx:rc];
        size_t n = (size_t)r.size.width * r.size.height;
        for (size_t i = 0; i < n; i++) { float o[4]; ci_blend_apply(k, s + i * 4, out + i * 4, o); memcpy(out + i * 4, o, sizeof o); }
        free(s);
    });
}
- (CIImage *)applyWithForeground:(CIImage *)fg background:(CIImage *)bg colorSpace:(CGColorSpaceRef)cs {
    /* blend in the given space: convert both in, blend, convert the result back */
    CIImage *a = [fg imageByColorMatchingWorkingSpaceToColorSpace:cs], *b = [bg imageByColorMatchingWorkingSpaceToColorSpace:cs];
    return [[self applyWithForeground:a background:b] imageByColorMatchingColorSpaceToWorkingSpace:cs];
}
+ (CIBlendKernel *)_builtin:(NSString *)name {
    static NSMutableDictionary *cache; static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&m);
    if (!cache) cache = [NSMutableDictionary dictionary];
    CIBlendKernel *k = cache[name];
    if (!k) { k = [CIBlendKernel new]; k.isimBlendMode = ci_blend_mode_named(name); cache[name] = k; }
    pthread_mutex_unlock(&m);
    return k;
}
#define BK(n) + (CIBlendKernel *)n { return [self _builtin:@#n]; }
BK(componentAdd) BK(componentMultiply) BK(componentMin) BK(componentMax) BK(clear) BK(source) BK(destination) BK(sourceOver) BK(destinationOver)
BK(sourceIn) BK(destinationIn) BK(sourceOut) BK(destinationOut) BK(sourceAtop) BK(destinationAtop) BK(exclusiveOr) BK(multiply) BK(screen)
BK(overlay) BK(darken) BK(lighten) BK(colorDodge) BK(colorBurn) BK(hardLight) BK(softLight) BK(difference) BK(exclusion) BK(hue)
BK(saturation) BK(color) BK(luminosity) BK(subtract) BK(divide) BK(linearBurn) BK(linearDodge) BK(vividLight) BK(linearLight) BK(pinLight)
BK(hardMix) BK(darkerColor) BK(lighterColor)
#undef BK
- (NSString *)name { return self.isimBlendMode >= 0 ? @"builtin" : [super name]; }
@end

void ci_blend_apply(CIBlendKernel *k, const float *src, const float *dst, float *out) {
    if (k.isimBlendMode >= 0) { ci_blend_mode_px(k.isimBlendMode, src, dst, out); return; }
    ck_func *f = k.isimFunc;
    if (!f) { memcpy(out, src, 16); return; }
    ck_arg a[2]; memset(a, 0, sizeof a);
    a[0].n = 4; memcpy(a[0].v, src, 16); a[1].n = 4; memcpy(a[1].v, dst, 16);
    khost h = { { kh_dest, kh_sample, kh_transform, kh_extent, NULL }, 0, 0, NULL, NULL, NULL, NULL, NULL, 0 };
    ck_run(k.isimProgram, f, a, 2, &h.h, out);
}

/* ================= CIImageAccumulator ================= */
@implementation CIImageAccumulator { float *_px; CGRect _e; CIFormat _fmt; id _cs; pthread_mutex_t _m; }
+ (instancetype)imageAccumulatorWithExtent:(CGRect)e format:(CIFormat)f { return [[self alloc] initWithExtent:e format:f]; }
+ (instancetype)imageAccumulatorWithExtent:(CGRect)e format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs { return [[self alloc] initWithExtent:e format:f colorSpace:cs]; }
- (instancetype)initWithExtent:(CGRect)e format:(CIFormat)f { return [self initWithExtent:e format:f colorSpace:ci_cgspace_named(kCGColorSpaceSRGB)]; }
- (instancetype)initWithExtent:(CGRect)e format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    ci_fmt fm;
    if (ci_infinite(e) || CGRectIsEmpty(e) || !ci_fmt_of(f, &fm)) return nil;
    if (!(self = [super init])) return nil;
    _e = CGRectIntegral(e); _fmt = f; _cs = (__bridge id)cs;
    _px = calloc((size_t)_e.size.width * _e.size.height * 4, sizeof(float));
    pthread_mutex_init(&_m, NULL);
    return self;
}
- (void)dealloc { free(_px); pthread_mutex_destroy(&_m); }
- (CGRect)extent { return _e; }
- (CIFormat)format { return _fmt; }
- (CIImage *)image {
    pthread_mutex_lock(&_m);
    size_t n = (size_t)_e.size.width * _e.size.height * 4;
    float *copy = malloc(sizeof(float) * n); memcpy(copy, _px, sizeof(float) * n);
    pthread_mutex_unlock(&_m);
    /* the stored pixels are working-space values (linear sRGB): a raw bitmap in that space */
    return ci_bitmap(copy, (int)_e.size.width, (int)_e.size.height, _e, ci_space_linear, NO);
}
- (void)setImage:(CIImage *)image { [self setImage:image dirtyRect:_e]; }
- (void)setImage:(CIImage *)image dirtyRect:(CGRect)dirty {
    CGRect r = CGRectIntersection(CGRectIntegral(dirty), _e);
    if (CGRectIsNull(r) || CGRectIsEmpty(r) || !image) return;
    ci_rctx rc = ci_rctx_default(); rc.cache = ci_cache_new();
    float *px = ci_render_new(image, r, &rc);
    ci_cache_free(rc.cache);
    /* quantize like the accumulator's format would */
    ci_fmt fm; ci_fmt_of(_fmt, &fm);
    int W = (int)r.size.width, H = (int)r.size.height, EW = (int)_e.size.width;
    pthread_mutex_lock(&_m);
    for (int j = 0; j < H; j++) {
        int row = (int)(CGRectGetMaxY(_e) - CGRectGetMaxY(r)) + j, col = (int)(r.origin.x - _e.origin.x);
        float *d = _px + ((size_t)row * EW + col) * 4, *s = px + (size_t)j * W * 4;
        for (int i = 0; i < W * 4; i++) {
            float v = s[i];
            if (!fm.isfloat) { float q = fm.bytes == 1 ? 255 : 65535; v = roundf(ci_clamp01(v) * q) / q; }
            else if (fm.half) v = ci_h2f(ci_f2h(v));
            d[i] = v;
        }
    }
    pthread_mutex_unlock(&_m);
    free(px);
}
- (void)clear { pthread_mutex_lock(&_m); memset(_px, 0, sizeof(float) * (size_t)_e.size.width * _e.size.height * 4); pthread_mutex_unlock(&_m); }
@end

/* ================= CIImageProcessorKernel ================= */
CI_HIDDEN @interface __CIProcessorIO : NSObject {
    @public CGRect _region; size_t _bpr; CIFormat _format; void *_base; uint64_t _digest; NSUInteger _tile, _tiles;
}
@end
@implementation __CIProcessorIO
- (CGRect)region { return _region; }
- (size_t)bytesPerRow { return _bpr; }
- (CIFormat)format { return _format; }
- (uint64_t)digest { return _digest; }
- (NSUInteger)roiTileIndex { return _tile; }
- (NSUInteger)roiTileCount { return _tiles; }
- (id)pixelBuffer { return nil; }
- (id)metalTexture { return nil; }
- (id)metalCommandBuffer { return nil; }
- (id)surface { return nil; }
@end
CI_HIDDEN @interface __CIProcessorInput : __CIProcessorIO <CIImageProcessorInput>
@end
@implementation __CIProcessorInput
@dynamic region, bytesPerRow, format, digest, roiTileIndex, roiTileCount;
- (const void *)baseAddress { return _base; }
@end
CI_HIDDEN @interface __CIProcessorOutput : __CIProcessorIO <CIImageProcessorOutput>
@end
@implementation __CIProcessorOutput
@dynamic region, bytesPerRow, format, digest;
- (void *)baseAddress { return _base; }
@end
static uint64_t digest_of(const void *p, size_t n, uint64_t seed) {
    uint64_t h = 1469598103934665603ULL ^ seed; const uint8_t *b = p;
    for (size_t i = 0; i < n; i += 7) { h ^= b[i]; h *= 1099511628211ULL; }
    return h;
}
@implementation CIImageProcessorKernel
+ (BOOL)processWithInputs:(NSArray *)inputs arguments:(NSDictionary *)arguments output:(id<CIImageProcessorOutput>)output error:(NSError **)error { return NO; }
+ (CGRect)roiForInput:(int)i arguments:(NSDictionary *)arguments outputRect:(CGRect)r { return r; }
+ (NSArray *)roiTileArrayForInput:(int)i arguments:(NSDictionary *)arguments outputRect:(CGRect)r { return nil; }
+ (CIFormat)formatForInputAtIndex:(int)i { return 0; }
+ (CIFormat)outputFormat { return 0; }
+ (BOOL)outputIsOpaque { return NO; }
+ (BOOL)synchronizeInputs { return YES; }
+ (CIFormat)outputFormatAtIndex:(int)i arguments:(NSDictionary *)arguments { return 0; }
+ (BOOL)processWithInputs:(NSArray *)inputs arguments:(NSDictionary *)arguments outputs:(NSArray *)outputs error:(NSError **)error {
    return outputs.count ? [self processWithInputs:inputs arguments:arguments output:outputs[0] error:error] : NO;
}
/* renders the inputs over their regions in their formats, runs the processor, reads the output back */
+ (BOOL)_process:(NSArray<CIImage *> *)inputs args:(NSDictionary *)args rect:(CGRect)r outputs:(int)nout index:(int)want into:(float *)buf ctx:(const ci_rctx *)rc {
    NSMutableArray *ins = [NSMutableArray array];
    NSMutableArray *keep = [NSMutableArray array];
    BOOL multi = nout > 1 || [self methodForSelector:@selector(processWithInputs:arguments:outputs:error:)] != [CIImageProcessorKernel methodForSelector:@selector(processWithInputs:arguments:outputs:error:)];
    NSMutableArray *outs = [NSMutableArray array];
    for (int o = 0; o < nout; o++) {
        CIFormat of = nout > 1 || multi ? [self outputFormatAtIndex:o arguments:args] : [self outputFormat];
        if (!of) of = [self outputFormat] ?: kCIFormatRGBAh;
        ci_fmt fm; ci_fmt_of(of, &fm);
        __CIProcessorIO *io = [__CIProcessorOutput new];
        io->_region = r; io->_format = of; io->_bpr = (size_t)r.size.width * fm.ch * fm.bytes;
        NSMutableData *d = [NSMutableData dataWithLength:io->_bpr * (size_t)r.size.height]; [keep addObject:d];
        io->_base = d.mutableBytes; io->_digest = digest_of(&r, sizeof r, (uint64_t)o);
        [outs addObject:io];
    }
    BOOL ok = YES;
    /* one pass per tile of the first input that asks for tiles (others: their whole region) */
    NSArray *tiles0 = inputs.count ? [self roiTileArrayForInput:0 arguments:args outputRect:r] : nil;
    NSUInteger ntiles = tiles0.count ? tiles0.count : 1;
    for (NSUInteger t = 0; t < ntiles && ok; t++) {
        [ins removeAllObjects];
        for (int i = 0; i < (int)inputs.count; i++) {
            CGRect roi = i == 0 && tiles0.count ? [tiles0[t] CGRectValue] : [self roiForInput:i arguments:args outputRect:r];
            roi = CGRectIntegral(roi);
            if (ci_infinite(roi)) roi = r;
            CIFormat f = [self formatForInputAtIndex:i] ?: kCIFormatRGBAh;
            ci_fmt fm; ci_fmt_of(f, &fm);
            float *px = ci_render_new(inputs[i], roi, rc);
            __CIProcessorIO *io = [__CIProcessorInput new];
            io->_region = roi; io->_format = f; io->_bpr = (size_t)roi.size.width * fm.ch * fm.bytes;
            NSMutableData *d = [NSMutableData dataWithLength:io->_bpr * (size_t)roi.size.height]; [keep addObject:d];
            ci_store(px, (int)roi.size.width, (int)roi.size.height, d.mutableBytes, (ptrdiff_t)io->_bpr, f);
            io->_base = d.mutableBytes; io->_digest = digest_of(d.bytes, d.length, (uint64_t)i);
            io->_tile = i == 0 ? t : 0; io->_tiles = i == 0 ? ntiles : 1;
            free(px);
            [ins addObject:io];
        }
        NSError *err = nil;
        ok = multi ? [self processWithInputs:ins arguments:args outputs:outs error:&err] : [self processWithInputs:ins arguments:args output:outs[0] error:&err];
        if (!ok) NSLog(@"isim: Core Image: %@ failed: %@", NSStringFromClass(self), err.localizedDescription ?: @"(no error)");
    }
    if (ok) {
        __CIProcessorIO *o = outs[want];
        float *px = ci_load(o->_base, (int)r.size.width, (int)r.size.height, (ptrdiff_t)o->_bpr, o->_format, 1);
        if (px) { memcpy(buf, px, sizeof(float) * 4 * (size_t)r.size.width * r.size.height); free(px); }
        if ([self outputIsOpaque]) for (size_t i = 0; i < (size_t)r.size.width * r.size.height; i++) buf[i * 4 + 3] = 1;
    }
    return ok;
}
+ (CIImage *)applyWithExtent:(CGRect)extent inputs:(NSArray<CIImage *> *)inputs arguments:(NSDictionary *)args error:(NSError **)error {
    if (self == [CIImageProcessorKernel class]) { if (error) *error = kerr(@"subclass CIImageProcessorKernel"); return nil; }
    Class cls = self;
    NSArray *ins = [inputs copy] ?: @[]; NSDictionary *a = [args copy];
    CIImage *im = ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [cls _process:ins args:a rect:r outputs:1 index:0 into:out ctx:rc];
    });
    im.isimOpaque = [self outputIsOpaque];
    return im;
}
+ (NSArray<CIImage *> *)applyWithExtents:(NSArray<CIVector *> *)extents inputs:(NSArray<CIImage *> *)inputs arguments:(NSDictionary *)args error:(NSError **)error {
    Class cls = self;
    NSArray *ins = [inputs copy] ?: @[]; NSDictionary *a = [args copy];
    NSMutableArray *out = [NSMutableArray array];
    int n = (int)extents.count;
    for (int i = 0; i < n; i++) {
        int idx = i;
        [out addObject:ci_op([extents[i] CGRectValue], ^(CGRect r, float *o, const ci_rctx *rc) {
            [cls _process:ins args:a rect:r outputs:n index:idx into:o ctx:rc];
        })];
    }
    return out;
}
@end
