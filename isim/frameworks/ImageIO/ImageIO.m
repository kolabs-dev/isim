// isim ImageIO: CGImageSource (container info, frames, properties, thumbnails) and CGImageDestination (PNG, JPEG,
// GIF) over the host's decoders/encoders (runtime/host_cg.c, host_image.c).
#import <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#include <math.h>

#define K(name, value) const CFStringRef name = CFSTR(value);
K(kCGImagePropertyFileSize, "FileSize") K(kCGImagePropertyPixelWidth, "PixelWidth") K(kCGImagePropertyPixelHeight, "PixelHeight")
K(kCGImagePropertyDepth, "Depth") K(kCGImagePropertyOrientation, "Orientation") K(kCGImagePropertyHasAlpha, "HasAlpha")
K(kCGImagePropertyColorModel, "ColorModel") K(kCGImagePropertyColorModelRGB, "RGB") K(kCGImagePropertyColorModelGray, "Gray")
K(kCGImagePropertyDPIWidth, "DPIWidth") K(kCGImagePropertyDPIHeight, "DPIHeight")
K(kCGImagePropertyTIFFDictionary, "{TIFF}") K(kCGImagePropertyTIFFOrientation, "Orientation") K(kCGImagePropertyExifDictionary, "{Exif}")
K(kCGImagePropertyJFIFDictionary, "{JFIF}") K(kCGImagePropertyPNGDictionary, "{PNG}") K(kCGImagePropertyGIFDictionary, "{GIF}")
K(kCGImagePropertyGIFDelayTime, "DelayTime") K(kCGImagePropertyGIFUnclampedDelayTime, "UnclampedDelayTime") K(kCGImagePropertyGIFLoopCount, "LoopCount")
K(kCGImagePropertyGIFHasGlobalColorMap, "HasGlobalColorMap") K(kCGImagePropertyWebPDictionary, "{WebP}") K(kCGImagePropertyWebPDelayTime, "DelayTime")
K(kCGImagePropertyWebPUnclampedDelayTime, "UnclampedDelayTime") K(kCGImagePropertyWebPLoopCount, "LoopCount") K(kCGImagePropertyHEICSDictionary, "{HEICS}")
K(kCGImageSourceTypeIdentifierHint, "kCGImageSourceTypeIdentifierHint") K(kCGImageSourceShouldCache, "kCGImageSourceShouldCache")
K(kCGImageSourceShouldCacheImmediately, "kCGImageSourceShouldCacheImmediately") K(kCGImageSourceShouldAllowFloat, "kCGImageSourceShouldAllowFloat")
K(kCGImageSourceCreateThumbnailFromImageIfAbsent, "kCGImageSourceCreateThumbnailFromImageIfAbsent")
K(kCGImageSourceCreateThumbnailFromImageAlways, "kCGImageSourceCreateThumbnailFromImageAlways")
K(kCGImageSourceThumbnailMaxPixelSize, "kCGImageSourceThumbnailMaxPixelSize") K(kCGImageSourceCreateThumbnailWithTransform, "kCGImageSourceCreateThumbnailWithTransform")
K(kCGImageDestinationLossyCompressionQuality, "kCGImageDestinationLossyCompressionQuality") K(kCGImageDestinationBackgroundColor, "kCGImageDestinationBackgroundColor")
#define S(k) ((__bridge NSString *)(k))

/* ---------------- sources ---------------- */
@interface __CGImageSource : NSObject {
@public NSData *_data; int _frames, _w, _h, _orientation, _alpha, _loops; char _type[64]; BOOL _final; NSMutableDictionary *_cache;
}
@end
@implementation __CGImageSource
- (NSString *)description { return [NSString stringWithFormat:@"<CGImageSource %p> %s, %d image(s)", self, _type, _frames]; }
- (void)dealloc { for (NSArray *c in _cache.allValues) isim_image_free([c[0] intValue]); }
- (void)scan {
    _frames = 0; _type[0] = 0;
    if (_data.length) isim_imgsrc_info(_data.bytes, (long)_data.length, &_frames, &_w, &_h, _type, sizeof _type, &_orientation, &_alpha, &_loops);
}
@end
static __CGImageSource *SRC(CGImageSourceRef s) { return (__bridge __CGImageSource *)s; }
CFTypeID CGImageSourceGetTypeID(void) { return 0x4953; }
CFArrayRef CGImageSourceCopyTypeIdentifiers(void) {
    return (CFArrayRef)CFBridgingRetain(@[ @"public.png", @"public.jpeg", @"com.compuserve.gif", @"org.webmproject.webp", @"com.microsoft.bmp",
                                           @"public.tiff", @"com.microsoft.ico", @"public.heic", @"public.avif" ]);
}
CGImageSourceRef CGImageSourceCreateWithData(CFDataRef data, CFDictionaryRef opts) {
    if (!data) return NULL;
    __CGImageSource *s = [__CGImageSource new];
    s->_data = [(__bridge NSData *)data copy]; s->_final = YES; s->_cache = [NSMutableDictionary dictionary];
    [s scan];
    return (CGImageSourceRef)CFBridgingRetain(s);    /* like ImageIO, unknown data still gives a source (count 0, status unknown type) */
}
CGImageSourceRef CGImageSourceCreateWithURL(CFURLRef url, CFDictionaryRef opts) {
    NSData *d = [NSData dataWithContentsOfURL:(__bridge NSURL *)url];
    return d ? CGImageSourceCreateWithData((__bridge CFDataRef)d, opts) : NULL;
}
CGImageSourceRef CGImageSourceCreateWithDataProvider(CGDataProviderRef p, CFDictionaryRef opts) {
    CFDataRef d = CGDataProviderCopyData(p);
    if (!d) return NULL;
    CGImageSourceRef s = CGImageSourceCreateWithData(d, opts);
    CFRelease(d);
    return s;
}
CGImageSourceRef CGImageSourceCreateIncremental(CFDictionaryRef opts) {
    __CGImageSource *s = [__CGImageSource new]; s->_data = [NSData data]; s->_cache = [NSMutableDictionary dictionary];
    return (CGImageSourceRef)CFBridgingRetain(s);
}
void CGImageSourceUpdateData(CGImageSourceRef src, CFDataRef data, bool final) {
    __CGImageSource *s = SRC(src); s->_data = [(__bridge NSData *)data copy]; s->_final = final; [s->_cache removeAllObjects];
    if (final) [s scan]; else s->_frames = 0;
}
CFStringRef CGImageSourceGetType(CGImageSourceRef src) {
    __CGImageSource *s = SRC(src);
    if (!s->_type[0]) return NULL;
    static NSMutableDictionary *interned; if (!interned) interned = [NSMutableDictionary dictionary];
    NSString *t = [NSString stringWithUTF8String:s->_type];
    if (!interned[t]) interned[t] = t;
    return (__bridge CFStringRef)interned[t];
}
size_t CGImageSourceGetCount(CGImageSourceRef src) { return (size_t)SRC(src)->_frames; }
size_t CGImageSourceGetPrimaryImageIndex(CGImageSourceRef src) { return 0; }
CGImageSourceStatus CGImageSourceGetStatus(CGImageSourceRef src) {
    __CGImageSource *s = SRC(src);
    if (!s->_final) return s->_data.length ? kCGImageStatusIncomplete : kCGImageStatusReadingHeader;
    return s->_frames > 0 ? kCGImageStatusComplete : s->_type[0] ? kCGImageStatusInvalidData : kCGImageStatusUnknownType;
}
CGImageSourceStatus CGImageSourceGetStatusAtIndex(CGImageSourceRef src, size_t i) {
    CGImageSourceStatus st = CGImageSourceGetStatus(src);
    return st == kCGImageStatusComplete && i >= (size_t)SRC(src)->_frames ? kCGImageStatusUnknownType : st;
}
static BOOL is(__CGImageSource *s, const char *t) { return !strcmp(s->_type, t); }
CFDictionaryRef CGImageSourceCopyProperties(CGImageSourceRef src, CFDictionaryRef opts) {
    __CGImageSource *s = SRC(src);
    if (!s->_frames) return NULL;
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:@(s->_data.length) forKey:S(kCGImagePropertyFileSize)];
    if (is(s, "com.compuserve.gif")) d[S(kCGImagePropertyGIFDictionary)] = @{ S(kCGImagePropertyGIFLoopCount): @(s->_loops), S(kCGImagePropertyGIFHasGlobalColorMap): @YES };
    if (is(s, "org.webmproject.webp") && s->_frames > 1) d[S(kCGImagePropertyWebPDictionary)] = @{ S(kCGImagePropertyWebPLoopCount): @(s->_loops) };
    return (CFDictionaryRef)CFBridgingRetain(d);
}
/* the frame's host image (decoded once) and its delay */
static int frame_handle(__CGImageSource *s, size_t i, double *delay) {
    NSArray *c = s->_cache[@(i)];
    if (c) { if (delay) *delay = [c[1] doubleValue]; return [c[0] intValue]; }
    double d = 0; int h = isim_imgsrc_frame(s->_data.bytes, (long)s->_data.length, (int)i, &d);
    if (!h) return 0;
    /* GIF: ImageIO reports the file's delay; values under 11 ms are clamped to 100 ms for DelayTime */
    s->_cache[@(i)] = @[ @(h), @(d) ];
    if (delay) *delay = d;
    return h;
}
/* GIF delays as written in the file (centiseconds), frame by frame */
static double gif_file_delay(NSData *data, size_t index) {
    const unsigned char *d = data.bytes; long len = (long)data.length;
    if (len < 13) return 0;
    long p = 13; size_t frame = 0; int delay = 0;
    if (d[10] & 0x80) p += 3L * (1 << ((d[10] & 7) + 1));
    while (p < len) {
        unsigned char b = d[p++];
        if (b == 0x3b) break;
        if (b == 0x21 && p < len) { unsigned char l = d[p++]; if (l == 0xf9 && p + 4 < len) delay = d[p + 2] | d[p + 3] << 8; while (p < len && d[p]) p += d[p] + 1; p++; }
        else if (b == 0x2c && p + 9 <= len) {
            unsigned char fl = d[p + 8]; p += 9; if (fl & 0x80) p += 3L * (1 << ((fl & 7) + 1)); p++;
            while (p < len && d[p]) p += d[p] + 1; p++;
            if (frame++ == index) return delay / 100.0;
            delay = 0;
        } else break;
    }
    return 0;
}
CFDictionaryRef CGImageSourceCopyPropertiesAtIndex(CGImageSourceRef src, size_t i, CFDictionaryRef opts) {
    __CGImageSource *s = SRC(src);
    if (i >= (size_t)s->_frames) return NULL;
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[S(kCGImagePropertyPixelWidth)] = @(s->_w); d[S(kCGImagePropertyPixelHeight)] = @(s->_h);
    d[S(kCGImagePropertyDepth)] = @8; d[S(kCGImagePropertyColorModel)] = S(kCGImagePropertyColorModelRGB);
    d[S(kCGImagePropertyHasAlpha)] = @(s->_alpha != 0);
    d[S(kCGImagePropertyDPIWidth)] = @72; d[S(kCGImagePropertyDPIHeight)] = @72;
    if (s->_orientation != 1 || is(s, "public.jpeg") || is(s, "public.tiff")) {
        d[S(kCGImagePropertyOrientation)] = @(s->_orientation);
        d[S(kCGImagePropertyTIFFDictionary)] = @{ S(kCGImagePropertyTIFFOrientation): @(s->_orientation) };
    }
    if (is(s, "public.png")) d[S(kCGImagePropertyPNGDictionary)] = @{};
    if (is(s, "public.jpeg")) d[S(kCGImagePropertyJFIFDictionary)] = @{};
    if (is(s, "com.compuserve.gif")) {
        double unclamped = gif_file_delay(s->_data, i);
        d[S(kCGImagePropertyGIFDictionary)] = @{ S(kCGImagePropertyGIFUnclampedDelayTime): @(unclamped),
                                                 S(kCGImagePropertyGIFDelayTime): @(unclamped < 0.011 ? 0.1 : unclamped) };
    }
    if (is(s, "org.webmproject.webp") && s->_frames > 1) {
        double delay = 0; frame_handle(s, i, &delay);
        d[S(kCGImagePropertyWebPDictionary)] = @{ S(kCGImagePropertyWebPDelayTime): @(delay), S(kCGImagePropertyWebPUnclampedDelayTime): @(delay) };
    }
    return (CFDictionaryRef)CFBridgingRetain(d);
}
static CGImageRef image_of_frame(__CGImageSource *s, size_t i) {
    int h = frame_handle(s, i, NULL);
    if (!h) return NULL;
    /* a copy owned by the CGImage (the source keeps its cached frame) */
    double w, hh; isim_image_pixel_size(h, &w, &hh);
    unsigned char *px = malloc((size_t)w * (size_t)hh * 4);
    isim_image_read_pixels(h, 0, 0, (int)w, (int)hh, px, (int)w * 4, ISIM_PX_RGBA_PREMUL, 4);
    int copy = isim_image_from_pixels(px, (int)w, (int)hh, (int)w * 4, ISIM_PX_RGBA_PREMUL, 4);
    free(px);
    CGImageRef im = isim_cg_image_with_handle(copy);
    if (im) isim_cg_image_set_uttype(im, CGImageSourceGetType((__bridge CGImageSourceRef)s));
    return im;
}
CGImageRef CGImageSourceCreateImageAtIndex(CGImageSourceRef src, size_t i, CFDictionaryRef opts) {
    __CGImageSource *s = SRC(src);
    return i < (size_t)s->_frames ? image_of_frame(s, i) : NULL;
}
/* draws `im` scaled to fit maxSize, applying an EXIF orientation (1...8) when asked */
static CGImageRef transformed(CGImageRef im, int orientation, double maxSize) {
    double w = (double)CGImageGetWidth(im), h = (double)CGImageGetHeight(im);
    BOOL swap = orientation >= 5 && orientation <= 8;
    double ow = swap ? h : w, oh = swap ? w : h, k = maxSize > 0 ? fmin(1, maxSize / fmax(ow, oh)) : 1;
    size_t W = (size_t)fmax(1, lround(ow * k)), H = (size_t)fmax(1, lround(oh * k));
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(NULL, W, H, 8, W * 4, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!c) return NULL;
    CGContextSetInterpolationQuality(c, kCGInterpolationHigh);
    /* Core Graphics space is y-up: build the transform from the oriented (displayed) image to the stored pixels */
    double sw = W, sh = H;
    CGAffineTransform t = CGAffineTransformIdentity;
    switch (orientation) {
    case 2: t = CGAffineTransformMake(-1, 0, 0, 1, sw, 0); break;
    case 3: t = CGAffineTransformMake(-1, 0, 0, -1, sw, sh); break;
    case 4: t = CGAffineTransformMake(1, 0, 0, -1, 0, sh); break;
    case 5: t = CGAffineTransformMake(0, -1, -1, 0, sw, sh); break;
    case 6: t = CGAffineTransformMake(0, -1, 1, 0, 0, sh); break;
    case 7: t = CGAffineTransformMake(0, 1, 1, 0, 0, 0); break;
    case 8: t = CGAffineTransformMake(0, 1, -1, 0, sw, 0); break;
    default: break;
    }
    CGContextConcatCTM(c, t);
    CGContextDrawImage(c, CGRectMake(0, 0, swap ? sh : sw, swap ? sw : sh), im);
    CGImageRef out = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return out;
}
CGImageRef CGImageSourceCreateThumbnailAtIndex(CGImageSourceRef src, size_t i, CFDictionaryRef opts) {
    __CGImageSource *s = SRC(src);
    NSDictionary *o = (__bridge NSDictionary *)opts;
    if (i >= (size_t)s->_frames) return NULL;
    /* the containers isim reads carry no embedded thumbnails: "if absent" and "always" both make one from the image */
    if (![o[S(kCGImageSourceCreateThumbnailFromImageAlways)] boolValue] && ![o[S(kCGImageSourceCreateThumbnailFromImageIfAbsent)] boolValue]) return NULL;
    CGImageRef full = image_of_frame(s, i);
    if (!full) return NULL;
    double max = [o[S(kCGImageSourceThumbnailMaxPixelSize)] doubleValue];
    int orient = [o[S(kCGImageSourceCreateThumbnailWithTransform)] boolValue] ? s->_orientation : 1;
    CGImageRef t = transformed(full, orient, max);
    CGImageRelease(full);
    return t;
}

/* ---------------- destinations ---------------- */
@interface __CGImageDestination : NSObject {
@public NSMutableData *_data; NSString *_path; CGDataConsumerRef _consumer; NSString *_type; size_t _count;
    NSMutableArray *_images; NSMutableArray<NSNumber *> *_delays; double _quality; int _loops; BOOL _done;
}
@end
@implementation __CGImageDestination
- (void)dealloc { if (_consumer) CFRelease(_consumer); }
@end
static __CGImageDestination *DST(CGImageDestinationRef d) { return (__bridge __CGImageDestination *)d; }
CFTypeID CGImageDestinationGetTypeID(void) { return 0x4944; }
CFArrayRef CGImageDestinationCopyTypeIdentifiers(void) { return (CFArrayRef)CFBridgingRetain(@[ @"public.png", @"public.jpeg", @"com.compuserve.gif" ]); }
static int fmt_of(NSString *t) {
    if ([t isEqualToString:@"public.png"]) return 0;
    if ([t isEqualToString:@"public.jpeg"] || [t isEqualToString:@"public.jpg"]) return 1;
    if ([t isEqualToString:@"com.compuserve.gif"]) return 2;
    return -1;
}
static CGImageDestinationRef dest(NSString *type, size_t count) {
    if (fmt_of(type) < 0) { NSLog(@"isim: CGImageDestination: unsupported type %@ (isim writes public.png, public.jpeg, com.compuserve.gif)", type); return NULL; }
    __CGImageDestination *d = [__CGImageDestination new];
    d->_type = [type copy]; d->_count = count; d->_images = [NSMutableArray array]; d->_delays = [NSMutableArray array]; d->_quality = 0.9; d->_loops = 0;
    return (CGImageDestinationRef)CFBridgingRetain(d);
}
CGImageDestinationRef CGImageDestinationCreateWithData(CFMutableDataRef data, CFStringRef type, size_t count, CFDictionaryRef opts) {
    CGImageDestinationRef r = dest((__bridge NSString *)type, count);
    if (r) DST(r)->_data = (__bridge NSMutableData *)data;
    return r;
}
CGImageDestinationRef CGImageDestinationCreateWithURL(CFURLRef url, CFStringRef type, size_t count, CFDictionaryRef opts) {
    CGImageDestinationRef r = dest((__bridge NSString *)type, count);
    if (r) DST(r)->_path = ((__bridge NSURL *)url).path;
    return r;
}
CGImageDestinationRef CGImageDestinationCreateWithDataConsumer(CGDataConsumerRef c, CFStringRef type, size_t count, CFDictionaryRef opts) {
    CGImageDestinationRef r = dest((__bridge NSString *)type, count);
    if (r) DST(r)->_consumer = (CGDataConsumerRef)CFRetain(c);
    return r;
}
static void read_props(__CGImageDestination *d, NSDictionary *p, double *delay) {
    if (p[S(kCGImageDestinationLossyCompressionQuality)]) d->_quality = [p[S(kCGImageDestinationLossyCompressionQuality)] doubleValue];
    NSDictionary *gif = p[S(kCGImagePropertyGIFDictionary)];
    if (gif[S(kCGImagePropertyGIFLoopCount)]) d->_loops = [gif[S(kCGImagePropertyGIFLoopCount)] intValue];
    if (delay && (gif[S(kCGImagePropertyGIFUnclampedDelayTime)] || gif[S(kCGImagePropertyGIFDelayTime)]))
        *delay = [(gif[S(kCGImagePropertyGIFUnclampedDelayTime)] ?: gif[S(kCGImagePropertyGIFDelayTime)]) doubleValue];
}
void CGImageDestinationSetProperties(CGImageDestinationRef dst, CFDictionaryRef props) { read_props(DST(dst), (__bridge NSDictionary *)props, NULL); }
void CGImageDestinationAddImage(CGImageDestinationRef dst, CGImageRef image, CFDictionaryRef props) {
    __CGImageDestination *d = DST(dst);
    if (!image || d->_done) return;
    if (d->_images.count >= d->_count) { NSLog(@"isim: CGImageDestinationAddImage: image count exceeds the %zu given at creation", d->_count); return; }
    double delay = 0; read_props(d, (__bridge NSDictionary *)props, &delay);
    [d->_images addObject:(__bridge id)image];
    [d->_delays addObject:@(delay)];
}
void CGImageDestinationAddImageFromSource(CGImageDestinationRef dst, CGImageSourceRef src, size_t i, CFDictionaryRef props) {
    CGImageRef im = CGImageSourceCreateImageAtIndex(src, i, NULL);
    if (!im) return;
    CGImageDestinationAddImage(dst, im, props);
    CGImageRelease(im);
}
/* a host image with exactly the CGImage's pixels (crops included) */
static int host_copy(CGImageRef im) {
    size_t w, h; unsigned char *px = isim_cg_image_rgba(im, &w, &h);
    if (!px) return 0;
    int hd = isim_image_from_pixels(px, (int)w, (int)h, (int)w * 4, ISIM_PX_RGBA_PREMUL, 4);
    free(px);
    return hd;
}
bool CGImageDestinationFinalize(CGImageDestinationRef dst) {
    __CGImageDestination *d = DST(dst);
    if (d->_done || !d->_images.count) return false;
    d->_done = YES;
    int fmt = fmt_of(d->_type);
    unsigned char *bytes = NULL; long n = 0;
    if (fmt == 2) {
        int count = (int)d->_images.count;
        int *hs = calloc((size_t)count, sizeof *hs); double *delays = calloc((size_t)count, sizeof *delays);
        for (int i = 0; i < count; i++) { hs[i] = host_copy((__bridge CGImageRef)d->_images[i]); delays[i] = d->_delays[i].doubleValue; }
        n = isim_image_encode_gif(hs, count, delays, d->_loops, &bytes);
        for (int i = 0; i < count; i++) if (hs[i]) isim_image_free(hs[i]);
        free(hs); free(delays);
    } else {
        int h = host_copy((__bridge CGImageRef)d->_images.firstObject);
        n = h ? isim_image_encode(h, fmt, d->_quality, &bytes) : 0;
        if (h) isim_image_free(h);
    }
    if (n <= 0) { isim_image_bytes_free(bytes); return false; }
    BOOL ok = YES;
    if (d->_data) [d->_data appendBytes:bytes length:(NSUInteger)n];
    else if (d->_path) ok = [[NSData dataWithBytes:bytes length:(NSUInteger)n] writeToFile:d->_path atomically:YES];
    else if (d->_consumer) ok = isim_cg_consumer_put(d->_consumer, bytes, (size_t)n) == (size_t)n;
    isim_image_bytes_free(bytes);
    return ok;
}
