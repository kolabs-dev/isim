// isim Core Image: CIImage recipes rendered on the CPU. Pixels are premultiplied RGBA floats in sRGB (Apple works in
// linear sRGB on the GPU; results here are close, not identical). Buffers are rows top-down: row 0 is the top (max y)
// of the rendered rect, matching CGImage rows.
#import <CoreImage/CoreImage.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#include <objc/runtime.h>
#include <math.h>

int isim_qr_encode(const uint8_t *msg, int len, int ecl, uint8_t *out);
CIFormat kCIFormatRGBA8 = 24, kCIFormatBGRA8 = 23, kCIFormatARGB8 = 22, kCIFormatRGBAf = 34;
static BOOL infinite(CGRect r) { return CGRectIsNull(r) || r.size.width > 1e8 || r.size.height > 1e8; }
static float clampf(float v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
typedef struct { float v[4]; } f4;          /* arrays captured by blocks */
typedef struct { float m[5][4]; } f54;

/* ================= CIVector / CIColor ================= */
@implementation CIVector { CGFloat _v[16]; size_t _n; }
+ (instancetype)vectorWithValues:(const CGFloat *)v count:(size_t)n { return [[self alloc] initWithValues:v count:n]; }
+ (instancetype)vectorWithX:(CGFloat)x { return [[self alloc] initWithX:x]; }
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y { return [[self alloc] initWithX:x Y:y]; }
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z { return [[self alloc] initWithX:x Y:y Z:z]; }
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w { return [[self alloc] initWithX:x Y:y Z:z W:w]; }
+ (instancetype)vectorWithCGPoint:(CGPoint)p { return [[self alloc] initWithCGPoint:p]; }
+ (instancetype)vectorWithCGRect:(CGRect)r { return [[self alloc] initWithCGRect:r]; }
+ (instancetype)vectorWithCGAffineTransform:(CGAffineTransform)t { return [[self alloc] initWithCGAffineTransform:t]; }
- (instancetype)initWithValues:(const CGFloat *)v count:(size_t)n {
    if ((self = [super init])) { _n = n > 16 ? 16 : n; for (size_t i = 0; i < _n; i++) _v[i] = v[i]; }
    return self;
}
- (instancetype)initWithX:(CGFloat)x { CGFloat v[] = { x }; return [self initWithValues:v count:1]; }
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y { CGFloat v[] = { x, y }; return [self initWithValues:v count:2]; }
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z { CGFloat v[] = { x, y, z }; return [self initWithValues:v count:3]; }
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w { CGFloat v[] = { x, y, z, w }; return [self initWithValues:v count:4]; }
- (instancetype)initWithCGPoint:(CGPoint)p { return [self initWithX:p.x Y:p.y]; }
- (instancetype)initWithCGRect:(CGRect)r { return [self initWithX:r.origin.x Y:r.origin.y Z:r.size.width W:r.size.height]; }
- (instancetype)initWithCGAffineTransform:(CGAffineTransform)t { CGFloat v[] = { t.a, t.b, t.c, t.d, t.tx, t.ty }; return [self initWithValues:v count:6]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (CGFloat)valueAtIndex:(size_t)i { return i < _n ? _v[i] : 0; }
- (size_t)count { return _n; }
- (CGFloat)X { return _v[0]; } - (CGFloat)Y { return _v[1]; } - (CGFloat)Z { return _v[2]; } - (CGFloat)W { return _v[3]; }
- (CGPoint)CGPointValue { return CGPointMake(_v[0], _v[1]); }
- (CGRect)CGRectValue { return CGRectMake(_v[0], _v[1], _v[2], _v[3]); }
- (CGAffineTransform)CGAffineTransformValue { return CGAffineTransformMake(_v[0], _v[1], _v[2], _v[3], _v[4], _v[5]); }
- (NSString *)stringRepresentation {
    NSMutableArray *a = [NSMutableArray array]; for (size_t i = 0; i < _n; i++) [a addObject:[NSString stringWithFormat:@"%g", _v[i]]];
    return [NSString stringWithFormat:@"[%@]", [a componentsJoinedByString:@" "]];
}
- (NSString *)description { return [NSString stringWithFormat:@"<CIVector %p> %@", self, self.stringRepresentation]; }
@end

@interface NSObject (IsimCGColorDuck)
- (CGColorRef)CGColor;
@end
@implementation CIColor { CGFloat _c[4]; }
+ (instancetype)colorWithCGColor:(CGColorRef)c { return [[self alloc] initWithCGColor:c]; }
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a { return [[self alloc] initWithRed:r green:g blue:b alpha:a]; }
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b { return [[self alloc] initWithRed:r green:g blue:b alpha:1]; }
+ (instancetype)colorWithString:(NSString *)s {
    NSArray *p = [[s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[] "]] componentsSeparatedByString:@" "];
    if (p.count < 3) return nil;
    return [self colorWithRed:[p[0] doubleValue] green:[p[1] doubleValue] blue:[p[2] doubleValue] alpha:p.count > 3 ? [p[3] doubleValue] : 1];
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    if ((self = [super init])) { _c[0] = r; _c[1] = g; _c[2] = b; _c[3] = a; }
    return self;
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b { return [self initWithRed:r green:g blue:b alpha:1]; }
- (instancetype)initWithCGColor:(CGColorRef)c { double v[4]; isim_cg_color_rgba(c, v); return [self initWithRed:v[0] green:v[1] blue:v[2] alpha:v[3]]; }
- (instancetype)initWithColor:(id)color { return [self initWithCGColor:[color CGColor]]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (size_t)numberOfComponents { return 4; }
- (const CGFloat *)components { return _c; }
- (CGFloat)red { return _c[0]; } - (CGFloat)green { return _c[1]; } - (CGFloat)blue { return _c[2]; } - (CGFloat)alpha { return _c[3]; }
- (CGColorSpaceRef)colorSpace { static CGColorSpaceRef s; if (!s) s = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); return s; }
- (NSString *)stringRepresentation { return [NSString stringWithFormat:@"%g %g %g %g", _c[0], _c[1], _c[2], _c[3]]; }
- (NSString *)description { return [NSString stringWithFormat:@"<CIColor %p> (%@)", self, self.stringRepresentation]; }
+ (CIColor *)blackColor { return [self colorWithRed:0 green:0 blue:0]; }
+ (CIColor *)whiteColor { return [self colorWithRed:1 green:1 blue:1]; }
+ (CIColor *)grayColor { return [self colorWithRed:0.5 green:0.5 blue:0.5]; }
+ (CIColor *)redColor { return [self colorWithRed:1 green:0 blue:0]; }
+ (CIColor *)greenColor { return [self colorWithRed:0 green:1 blue:0]; }
+ (CIColor *)blueColor { return [self colorWithRed:0 green:0 blue:1]; }
+ (CIColor *)cyanColor { return [self colorWithRed:0 green:1 blue:1]; }
+ (CIColor *)magentaColor { return [self colorWithRed:1 green:0 blue:1]; }
+ (CIColor *)yellowColor { return [self colorWithRed:1 green:1 blue:0]; }
+ (CIColor *)clearColor { return [self colorWithRed:0 green:0 blue:0 alpha:0]; }
@end

/* ================= images (recipes) ================= */
@interface CIImage ()
@property (nonatomic) CGRect isimExtent;
- (void)_render:(CGRect)r into:(float *)buf;     /* r integral; buf r.w*r.h*4 premultiplied floats, rows top-down */
@end
static float *render_new(CIImage *im, CGRect r) {
    size_t n = (size_t)r.size.width * (size_t)r.size.height * 4;
    float *b = calloc(n ? n : 4, sizeof(float));
    if (n) [im _render:r into:b];
    return b;
}
@interface __CIBitmap : CIImage { @public float *_px; int _w, _h; CGImageRef _cg; }
@end
@interface __CIGenerator : CIImage { @public void (^_fn)(double x, double y, float out[4]); }
@end
@interface __CIMap : CIImage { @public CIImage *_in; void (^_fn)(float px[4]); }
@end
@interface __CITransform : CIImage { @public CIImage *_in; CGAffineTransform _t; }
@end
@interface __CICrop : CIImage { @public CIImage *_in; CGRect _rect; }
@end
@interface __CIClamp : CIImage { @public CIImage *_in; CGRect _rect; }
@end
@interface __CIBlur : CIImage { @public CIImage *_in; double _sigma; }
@end
@interface __CIComposite : CIImage { @public CIImage *_fg, *_bg; int _op; }
@end
@interface __CIPositional : CIImage { @public CIImage *_in; void (^_fn)(double x, double y, float px[4]); }
@end

@implementation CIImage
+ (CIImage *)imageWithCGImage:(CGImageRef)image { return [[self alloc] initWithCGImage:image]; }
+ (CIImage *)imageWithCGImage:(CGImageRef)image options:(NSDictionary *)o { return [[self alloc] initWithCGImage:image options:o]; }
+ (CIImage *)imageWithData:(NSData *)d { return [[self alloc] initWithData:d]; }
+ (CIImage *)imageWithContentsOfURL:(NSURL *)url { return [[self alloc] initWithContentsOfURL:url]; }
+ (CIImage *)imageWithColor:(CIColor *)c { return [[self alloc] initWithColor:c]; }
+ (CIImage *)emptyImage { CIImage *i = [CIImage new]; i.isimExtent = CGRectZero; return i; }
+ (CIImage *)imageWithBitmapData:(NSData *)d bytesPerRow:(size_t)bpr size:(CGSize)s format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    return [[self alloc] initWithBitmapData:d bytesPerRow:bpr size:s format:f colorSpace:cs];
}
- (instancetype)init { if ((self = [super init])) _isimExtent = CGRectZero; return self; }
static __CIBitmap *bitmap_from_rgba(const unsigned char *px, int w, int h, int bpr, int premultiplied) {
    __CIBitmap *b = [__CIBitmap new];
    b->_w = w; b->_h = h; b->_px = malloc((size_t)w * h * 4 * sizeof(float));
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        const unsigned char *p = px + (size_t)y * bpr + (size_t)x * 4; float *o = b->_px + ((size_t)y * w + x) * 4;
        float a = p[3] / 255.0f;
        for (int k = 0; k < 3; k++) o[k] = premultiplied ? p[k] / 255.0f : p[k] / 255.0f * a;
        o[3] = a;
    }
    b.isimExtent = CGRectMake(0, 0, w, h);
    return b;
}
- (instancetype)initWithCGImage:(CGImageRef)image { return [self initWithCGImage:image options:nil]; }
- (instancetype)initWithCGImage:(CGImageRef)image options:(NSDictionary *)o {
    size_t w, h; unsigned char *px = isim_cg_image_rgba(image, &w, &h);
    if (!px) return (id)[CIImage emptyImage];
    __CIBitmap *b = bitmap_from_rgba(px, (int)w, (int)h, (int)w * 4, 1);
    free(px);
    b->_cg = CGImageRetain(image);
    return (id)b;
}
- (instancetype)initWithData:(NSData *)d {
    CGImageSourceRef s = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
    CGImageRef im = s ? CGImageSourceCreateImageAtIndex(s, 0, NULL) : NULL;
    if (s) CFRelease(s);
    if (!im) return nil;
    CIImage *r = [self initWithCGImage:im];
    CGImageRelease(im);
    return r;
}
- (instancetype)initWithContentsOfURL:(NSURL *)url { NSData *d = [NSData dataWithContentsOfURL:url]; return d ? [self initWithData:d] : nil; }
- (instancetype)initWithColor:(CIColor *)c {
    __CIGenerator *g = [__CIGenerator new];
    f4 v = { { (float)(c.red * c.alpha), (float)(c.green * c.alpha), (float)(c.blue * c.alpha), (float)c.alpha } };
    g->_fn = ^(double x, double y, float out[4]) { memcpy(out, v.v, sizeof v.v); };
    g.isimExtent = CGRectInfinite;
    return (id)g;
}
- (instancetype)initWithBitmapData:(NSData *)d bytesPerRow:(size_t)bpr size:(CGSize)s format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    int w = (int)s.width, h = (int)s.height;
    unsigned char *px = malloc((size_t)w * h * 4); const unsigned char *src = d.bytes;
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        const unsigned char *p = src + (size_t)y * bpr + (size_t)x * 4; unsigned char *o = px + ((size_t)y * w + x) * 4;
        if (f == kCIFormatBGRA8) { o[0] = p[2]; o[1] = p[1]; o[2] = p[0]; o[3] = p[3]; }
        else if (f == kCIFormatARGB8) { o[0] = p[1]; o[1] = p[2]; o[2] = p[3]; o[3] = p[0]; }
        else memcpy(o, p, 4);
    }
    __CIBitmap *b = bitmap_from_rgba(px, w, h, w * 4, 1);
    free(px);
    return (id)b;
}
- (instancetype)initWithImage:(id)image { return [self initWithImage:image options:nil]; }
- (instancetype)initWithImage:(id)image options:(NSDictionary *)o {
    CGImageRef cg = [image isKindOfClass:[UIImage class]] ? [(UIImage *)image CGImage] : NULL;
    if (!cg) return [image isKindOfClass:[UIImage class]] ? [(UIImage *)image CIImage] : nil;
    return [self initWithCGImage:cg options:o];
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (CGRect)extent { return _isimExtent; }
- (CGImageRef)CGImage { return NULL; }
- (NSDictionary *)properties { return @{}; }
- (CGColorSpaceRef)colorSpace { static CGColorSpaceRef s; if (!s) s = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); return s; }
- (NSURL *)url { return nil; }
- (NSString *)description { CGRect e = self.extent; return [NSString stringWithFormat:@"<%@ %p> extent [%g %g %g %g]", NSStringFromClass([self class]), self, e.origin.x, e.origin.y, e.size.width, e.size.height]; }
- (void)_render:(CGRect)r into:(float *)buf {}

- (CIImage *)imageByApplyingTransform:(CGAffineTransform)t {
    if (CGAffineTransformIsIdentity(t)) return self;
    __CITransform *i = [__CITransform new]; i->_in = self; i->_t = t;
    i.isimExtent = infinite(self.extent) ? CGRectInfinite : CGRectApplyAffineTransform(self.extent, t);
    return i;
}
- (CIImage *)imageByApplyingTransform:(CGAffineTransform)t highQualityDownsample:(BOOL)hq { return [self imageByApplyingTransform:t]; }
- (CGAffineTransform)imageTransformForOrientation:(int)o {
    CGRect e = self.extent; double w = e.size.width, h = e.size.height;
    /* the EXIF orientation (1...8) of the stored pixels -> transform that shows them upright (y-up space) */
    switch (o) {
    case 2: return CGAffineTransformMake(-1, 0, 0, 1, w, 0);
    case 3: return CGAffineTransformMake(-1, 0, 0, -1, w, h);
    case 4: return CGAffineTransformMake(1, 0, 0, -1, 0, h);
    case 5: return CGAffineTransformMake(0, -1, -1, 0, h, w);
    case 6: return CGAffineTransformMake(0, -1, 1, 0, 0, w);
    case 7: return CGAffineTransformMake(0, 1, 1, 0, 0, 0);
    case 8: return CGAffineTransformMake(0, 1, -1, 0, h, 0);
    default: return CGAffineTransformIdentity;
    }
}
- (CIImage *)imageByApplyingOrientation:(int)o {
    CGAffineTransform t = [self imageTransformForOrientation:o];
    CGRect e = self.extent;
    t = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-e.origin.x, -e.origin.y), t);
    return [self imageByApplyingTransform:t];
}
- (CIImage *)imageByApplyingCGOrientation:(CGImagePropertyOrientation)o { return [self imageByApplyingOrientation:(int)o]; }
- (CIImage *)imageByCroppingToRect:(CGRect)rect {
    __CICrop *c = [__CICrop new]; c->_in = self; c->_rect = rect;
    CGRect e = CGRectIntersection(self.extent, rect);
    c.isimExtent = CGRectIsNull(e) ? CGRectZero : e;
    return c;
}
- (CIImage *)imageByClampingToRect:(CGRect)rect {
    __CIClamp *c = [__CIClamp new]; c->_in = self; c->_rect = rect; c.isimExtent = CGRectInfinite; return c;
}
- (CIImage *)imageByClampingToExtent { return [self imageByClampingToRect:self.extent]; }
- (CIImage *)imageByCompositingOverImage:(CIImage *)dest {
    __CIComposite *c = [__CIComposite new]; c->_fg = self; c->_bg = dest; c->_op = 0;
    c.isimExtent = CGRectUnion(self.extent, dest.extent);
    return c;
}
- (CIImage *)imageByApplyingFilter:(NSString *)name withInputParameters:(NSDictionary *)params {
    CIFilter *f = [CIFilter filterWithName:name];
    [f setValue:self forKey:kCIInputImageKey];
    for (NSString *k in params) [f setValue:params[k] forKey:k];
    return f.outputImage ?: [CIImage emptyImage];
}
- (CIImage *)imageByApplyingFilter:(NSString *)name { return [self imageByApplyingFilter:name withInputParameters:nil]; }
- (CIImage *)imageByApplyingGaussianBlurWithSigma:(double)sigma {
    if (sigma <= 0) return self;
    __CIBlur *b = [__CIBlur new]; b->_in = self; b->_sigma = sigma;
    b.isimExtent = infinite(self.extent) ? CGRectInfinite : CGRectInset(self.extent, -ceil(3 * sigma), -ceil(3 * sigma));
    return b;
}
- (CIImage *)imageBySettingAlphaOneInExtent:(CGRect)e {
    __CIMap *m = [__CIMap new]; m->_in = self; m->_fn = ^(float p[4]) { p[3] = 1; };
    m.isimExtent = self.extent;
    return [m imageByCroppingToRect:e];
}
- (CIImage *)imageByPremultiplyingAlpha { __CIMap *m = [__CIMap new]; m->_in = self; m->_fn = ^(float p[4]) { for (int k = 0; k < 3; k++) p[k] *= p[3]; }; m.isimExtent = self.extent; return m; }
- (CIImage *)imageByUnpremultiplyingAlpha { __CIMap *m = [__CIMap new]; m->_in = self; m->_fn = ^(float p[4]) { if (p[3] > 0) for (int k = 0; k < 3; k++) p[k] /= p[3]; }; m.isimExtent = self.extent; return m; }
@end

@implementation __CIBitmap
- (void)dealloc { free(_px); if (_cg) CGImageRelease(_cg); }
- (CGImageRef)CGImage { return _cg; }
- (void)_render:(CGRect)r into:(float *)buf {
    int W = (int)r.size.width, H = (int)r.size.height;
    CGRect e = self.isimExtent;
    for (int j = 0; j < H; j++) {
        int y = (int)(r.origin.y + r.size.height) - 1 - j;          /* CI y of this output row */
        int sy = (int)(e.origin.y + _h) - 1 - y;                     /* bitmap row (top-down) */
        if (sy < 0 || sy >= _h) continue;
        for (int i = 0; i < W; i++) {
            int sx = (int)r.origin.x + i - (int)e.origin.x;
            if (sx < 0 || sx >= _w) continue;
            memcpy(buf + ((size_t)j * W + i) * 4, _px + ((size_t)sy * _w + sx) * 4, 4 * sizeof(float));
        }
    }
}
@end
@implementation __CIGenerator
- (void)_render:(CGRect)r into:(float *)buf {
    int W = (int)r.size.width, H = (int)r.size.height;
    for (int j = 0; j < H; j++) for (int i = 0; i < W; i++)
        _fn(r.origin.x + i + 0.5, r.origin.y + r.size.height - 1 - j + 0.5, buf + ((size_t)j * W + i) * 4);
}
@end
@implementation __CIMap
- (void)_render:(CGRect)r into:(float *)buf {
    [_in _render:r into:buf];
    size_t n = (size_t)r.size.width * (size_t)r.size.height;
    for (size_t i = 0; i < n; i++) _fn(buf + i * 4);
}
@end
@implementation __CIPositional
- (void)_render:(CGRect)r into:(float *)buf {
    [_in _render:r into:buf];
    int W = (int)r.size.width, H = (int)r.size.height;
    for (int j = 0; j < H; j++) for (int i = 0; i < W; i++)
        _fn(r.origin.x + i + 0.5, r.origin.y + r.size.height - 1 - j + 0.5, buf + ((size_t)j * W + i) * 4);
}
@end
/* bilinear sample of a top-down buffer covering rect s at CI point (x, y) */
static void sample(const float *b, CGRect s, double x, double y, float out[4]) {
    int W = (int)s.size.width, H = (int)s.size.height;
    double fx = x - s.origin.x - 0.5, fy = (s.origin.y + s.size.height) - y - 0.5;   /* buffer coords (row from top) */
    int x0 = (int)floor(fx), y0 = (int)floor(fy); double ax = fx - x0, ay = fy - y0;
    for (int k = 0; k < 4; k++) out[k] = 0;
    for (int dy = 0; dy < 2; dy++) for (int dx = 0; dx < 2; dx++) {
        int xx = x0 + dx, yy = y0 + dy;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        double w = (dx ? ax : 1 - ax) * (dy ? ay : 1 - ay);
        const float *p = b + ((size_t)yy * W + xx) * 4;
        for (int k = 0; k < 4; k++) out[k] += (float)(p[k] * w);
    }
}
@implementation __CITransform
- (void)_render:(CGRect)r into:(float *)buf {
    CGAffineTransform inv = CGAffineTransformInvert(_t);
    CGRect src = CGRectIntegral(CGRectInset(CGRectApplyAffineTransform(r, inv), -2, -2));
    if (!infinite(_in.extent)) { src = CGRectIntersection(src, CGRectIntegral(CGRectInset(_in.extent, -1, -1))); if (CGRectIsNull(src) || CGRectIsEmpty(src)) return; }
    float *b = render_new(_in, src);
    int W = (int)r.size.width, H = (int)r.size.height;
    for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
        CGPoint p = CGPointApplyAffineTransform(CGPointMake(r.origin.x + i + 0.5, r.origin.y + r.size.height - 1 - j + 0.5), inv);
        sample(b, src, p.x, p.y, buf + ((size_t)j * W + i) * 4);
    }
    free(b);
}
@end
@implementation __CICrop
- (void)_render:(CGRect)r into:(float *)buf {
    [_in _render:r into:buf];
    int W = (int)r.size.width, H = (int)r.size.height;
    for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
        double x = r.origin.x + i + 0.5, y = r.origin.y + r.size.height - 1 - j + 0.5;
        if (!CGRectContainsPoint(_rect, CGPointMake(x, y))) memset(buf + ((size_t)j * W + i) * 4, 0, 4 * sizeof(float));
    }
}
@end
@implementation __CIClamp
- (void)_render:(CGRect)r into:(float *)buf {
    CGRect e = CGRectIntegral(_rect);
    if (infinite(e) || CGRectIsEmpty(e)) { [_in _render:r into:buf]; return; }
    float *b = render_new(_in, e);
    int W = (int)r.size.width, H = (int)r.size.height, EW = (int)e.size.width, EH = (int)e.size.height;
    for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
        int x = (int)r.origin.x + i - (int)e.origin.x, y = (int)(r.origin.y + r.size.height) - 1 - j;
        int row = (int)(e.origin.y + e.size.height) - 1 - y;
        x = x < 0 ? 0 : x >= EW ? EW - 1 : x; row = row < 0 ? 0 : row >= EH ? EH - 1 : row;
        memcpy(buf + ((size_t)j * W + i) * 4, b + ((size_t)row * EW + x) * 4, 4 * sizeof(float));
    }
    free(b);
}
@end
@implementation __CIBlur
- (void)_render:(CGRect)r into:(float *)buf {
    int pad = (int)ceil(3 * _sigma);
    CGRect src = CGRectInset(r, -pad, -pad);
    float *b = render_new(_in, src);
    int W = (int)src.size.width, H = (int)src.size.height, n = 2 * pad + 1;
    float *k = malloc(sizeof(float) * (size_t)n); double sum = 0;
    for (int i = 0; i < n; i++) { double d = i - pad; k[i] = (float)exp(-d * d / (2 * _sigma * _sigma)); sum += k[i]; }
    for (int i = 0; i < n; i++) k[i] /= (float)sum;
    float *t = calloc((size_t)W * H * 4, sizeof(float));
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {           /* horizontal */
        float acc[4] = { 0 };
        for (int q = -pad; q <= pad; q++) { int xx = x + q; if (xx < 0 || xx >= W) continue; const float *p = b + ((size_t)y * W + xx) * 4; for (int c = 0; c < 4; c++) acc[c] += p[c] * k[q + pad]; }
        memcpy(t + ((size_t)y * W + x) * 4, acc, sizeof acc);
    }
    int RW = (int)r.size.width, RH = (int)r.size.height;
    for (int y = 0; y < RH; y++) for (int x = 0; x < RW; x++) {         /* vertical, into the output rect */
        float acc[4] = { 0 }; int sx = x + pad, sy = y + pad;
        for (int q = -pad; q <= pad; q++) { int yy = sy + q; if (yy < 0 || yy >= H) continue; const float *p = t + ((size_t)yy * W + sx) * 4; for (int c = 0; c < 4; c++) acc[c] += p[c] * k[q + pad]; }
        memcpy(buf + ((size_t)y * RW + x) * 4, acc, sizeof acc);
    }
    free(b); free(t); free(k);
}
@end
@implementation __CIComposite
- (void)_render:(CGRect)r into:(float *)buf {
    float *f = render_new(_fg, r);
    [_bg _render:r into:buf];
    size_t n = (size_t)r.size.width * (size_t)r.size.height;
    for (size_t i = 0; i < n; i++) {
        float *d = buf + i * 4, *s = f + i * 4;
        for (int c = 0; c < 4; c++) {
            if (_op == 1 && c < 3) d[c] = s[c] * d[c] + s[c] * (1 - d[3]) + d[c] * (1 - s[3]);
            else d[c] = s[c] + d[c] * (1 - s[3]);
        }
    }
    free(f);
}
@end

/* ================= context ================= */
CIContextOption const kCIContextUseSoftwareRenderer = @"software_renderer", kCIContextWorkingColorSpace = @"working_color_space",
    kCIContextOutputColorSpace = @"output_color_space", kCIContextCacheIntermediates = @"kCIContextCacheIntermediates";
@implementation CIContext { CGContextRef _cg; }
+ (CIContext *)contextWithOptions:(NSDictionary *)o { return [[self alloc] initWithOptions:o]; }
+ (CIContext *)context { return [self new]; }
+ (CIContext *)contextWithCGContext:(CGContextRef)c options:(NSDictionary *)o { CIContext *x = [[self alloc] initWithOptions:o]; x->_cg = (CGContextRef)CFRetain(c); return x; }
- (instancetype)initWithOptions:(NSDictionary *)o { return [super init]; }
- (instancetype)init { return [super init]; }
- (void)dealloc { if (_cg) CFRelease(_cg); }
- (CGColorSpaceRef)workingColorSpace { static CGColorSpaceRef s; if (!s) s = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); return s; }
- (void)clearCaches {}
static unsigned char *to_rgba8(const float *f, size_t n) {
    unsigned char *o = malloc(n * 4 ? n * 4 : 4);
    for (size_t i = 0; i < n; i++) {
        float a = clampf(f[i * 4 + 3]);
        for (int c = 0; c < 3; c++) { float v = f[i * 4 + c]; o[i * 4 + c] = (unsigned char)lroundf(fminf(clampf(v), a) * 255); }
        o[i * 4 + 3] = (unsigned char)lroundf(a * 255);
    }
    return o;
}
- (CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)r {
    if (!image || infinite(r)) { NSLog(@"isim: CIContext: cannot render an infinite rect; crop the image first"); return NULL; }
    r = CGRectIntegral(r);
    if (r.size.width < 1 || r.size.height < 1) return NULL;
    float *f = render_new(image, r);
    size_t n = (size_t)r.size.width * (size_t)r.size.height;
    unsigned char *px = to_rgba8(f, n); free(f);
    int hd = isim_image_from_pixels(px, (int)r.size.width, (int)r.size.height, (int)r.size.width * 4, ISIM_PX_RGBA_PREMUL, 4);
    free(px);
    return isim_cg_image_with_handle(hd);
}
- (CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)r format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs { return [self createCGImage:image fromRect:r]; }
- (void)render:(CIImage *)image toBitmap:(void *)data rowBytes:(ptrdiff_t)rb bounds:(CGRect)r format:(CIFormat)fmt colorSpace:(CGColorSpaceRef)cs {
    r = CGRectIntegral(r);
    float *f = render_new(image, r);
    int W = (int)r.size.width, H = (int)r.size.height;
    unsigned char *px = to_rgba8(f, (size_t)W * H); free(f);
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
        const unsigned char *p = px + ((size_t)y * W + x) * 4;
        if (fmt == kCIFormatRGBAf) { float *o = (float *)((char *)data + y * rb) + x * 4; for (int c = 0; c < 4; c++) o[c] = p[c] / 255.0f; continue; }
        unsigned char *o = (unsigned char *)data + y * rb + x * 4;
        if (fmt == kCIFormatBGRA8) { o[0] = p[2]; o[1] = p[1]; o[2] = p[0]; o[3] = p[3]; }
        else if (fmt == kCIFormatARGB8) { o[0] = p[3]; o[1] = p[0]; o[2] = p[1]; o[3] = p[2]; }
        else memcpy(o, p, 4);
    }
    free(px);
}
- (void)drawImage:(CIImage *)image inRect:(CGRect)in fromRect:(CGRect)from {
    CGImageRef cg = [self createCGImage:image fromRect:from];
    if (!cg) return;
    CGContextDrawImage(_cg ?: isim_cg_current_context(), in, cg);
    CGImageRelease(cg);
}
- (NSData *)_encode:(CIImage *)image type:(NSString *)type quality:(double)q {
    CGImageRef cg = [self createCGImage:image fromRect:image.extent];
    if (!cg) return nil;
    NSMutableData *d = [NSMutableData data];
    CGImageDestinationRef dst = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)d, (__bridge CFStringRef)type, 1, NULL);
    NSDictionary *props = @{ (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(q) };
    CGImageDestinationAddImage(dst, cg, (__bridge CFDictionaryRef)props);
    BOOL ok = CGImageDestinationFinalize(dst);
    CFRelease(dst); CGImageRelease(cg);
    return ok ? d : nil;
}
- (NSData *)PNGRepresentationOfImage:(CIImage *)image format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o { return [self _encode:image type:@"public.png" quality:1]; }
- (NSData *)JPEGRepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o { return [self _encode:image type:@"public.jpeg" quality:0.9]; }
@end

/* ================= filters ================= */
NSString *const kCIInputImageKey = @"inputImage", *const kCIInputBackgroundImageKey = @"inputBackgroundImage", *const kCIInputRadiusKey = @"inputRadius",
    *const kCIInputIntensityKey = @"inputIntensity", *const kCIInputSaturationKey = @"inputSaturation", *const kCIInputBrightnessKey = @"inputBrightness",
    *const kCIInputContrastKey = @"inputContrast", *const kCIInputCenterKey = @"inputCenter", *const kCIInputColorKey = @"inputColor",
    *const kCIInputWidthKey = @"inputWidth", *const kCIInputSharpnessKey = @"inputSharpness", *const kCIInputTransformKey = @"inputTransform",
    *const kCIInputAngleKey = @"inputAngle", *const kCIInputScaleKey = @"inputScale", *const kCIOutputImageKey = @"outputImage",
    *const kCIAttributeFilterName = @"CIAttributeFilterName", *const kCIAttributeFilterDisplayName = @"CIAttributeFilterDisplayName",
    *const kCIAttributeFilterCategories = @"CIAttributeFilterCategories", *const kCICategoryBuiltIn = @"CICategoryBuiltIn",
    *const kCICategoryBlur = @"CICategoryBlur", *const kCICategoryColorAdjustment = @"CICategoryColorAdjustment",
    *const kCICategoryColorEffect = @"CICategoryColorEffect", *const kCICategoryGenerator = @"CICategoryGenerator",
    *const kCICategoryGeometryAdjustment = @"CICategoryGeometryAdjustment", *const kCICategoryCompositeOperation = @"CICategoryCompositeOperation",
    *const kCICategoryStillImage = @"CICategoryStillImage";

/* name -> { category, defaults } */
static NSDictionary *registry(void) {
    static NSDictionary *r;
    if (r) return r;
    CIVector *(^v)(CGFloat, CGFloat) = ^(CGFloat x, CGFloat y) { return [CIVector vectorWithX:x Y:y]; };
    NSDictionary *photo = @{ @"cat": kCICategoryColorEffect, @"def": @{} };
    r = @{
        @"CIGaussianBlur": @{ @"cat": kCICategoryBlur, @"def": @{ @"inputRadius": @10 } },
        @"CIColorControls": @{ @"cat": kCICategoryColorAdjustment, @"def": @{ @"inputSaturation": @1, @"inputBrightness": @0, @"inputContrast": @1 } },
        @"CISepiaTone": @{ @"cat": kCICategoryColorEffect, @"def": @{ @"inputIntensity": @1 } },
        @"CIColorInvert": @{ @"cat": kCICategoryColorEffect, @"def": @{} },
        @"CIColorMatrix": @{ @"cat": kCICategoryColorAdjustment, @"def": @{ @"inputRVector": [CIVector vectorWithX:1 Y:0 Z:0 W:0], @"inputGVector": [CIVector vectorWithX:0 Y:1 Z:0 W:0],
                                                                           @"inputBVector": [CIVector vectorWithX:0 Y:0 Z:1 W:0], @"inputAVector": [CIVector vectorWithX:0 Y:0 Z:0 W:1],
                                                                           @"inputBiasVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0] } },
        @"CIPhotoEffectMono": photo, @"CIPhotoEffectNoir": photo, @"CIPhotoEffectChrome": photo, @"CIPhotoEffectFade": photo,
        @"CIPhotoEffectInstant": photo, @"CIPhotoEffectProcess": photo, @"CIPhotoEffectTonal": photo, @"CIPhotoEffectTransfer": photo,
        @"CIVignette": @{ @"cat": kCICategoryColorEffect, @"def": @{ @"inputRadius": @1, @"inputIntensity": @0 } },
        @"CIAffineTransform": @{ @"cat": kCICategoryGeometryAdjustment, @"def": @{ @"inputTransform": [NSValue valueWithCGAffineTransform:CGAffineTransformIdentity] } },
        @"CICrop": @{ @"cat": kCICategoryGeometryAdjustment, @"def": @{ @"inputRectangle": [CIVector vectorWithX:-8.98846567431158e307 Y:-8.98846567431158e307 Z:1.7976931348623157e308 W:1.7976931348623157e308] } },
        @"CISourceOverCompositing": @{ @"cat": kCICategoryCompositeOperation, @"def": @{} },
        @"CIMultiplyCompositing": @{ @"cat": kCICategoryCompositeOperation, @"def": @{} },
        @"CIQRCodeGenerator": @{ @"cat": kCICategoryGenerator, @"def": @{ @"inputCorrectionLevel": @"M" } },
        @"CICheckerboardGenerator": @{ @"cat": kCICategoryGenerator, @"def": @{ @"inputCenter": v(150, 150), @"inputColor0": [CIColor whiteColor], @"inputColor1": [CIColor blackColor],
                                                                               @"inputWidth": @80, @"inputSharpness": @1 } },
        @"CIConstantColorGenerator": @{ @"cat": kCICategoryGenerator, @"def": @{ @"inputColor": [CIColor blackColor] } },
        @"CILinearGradient": @{ @"cat": kCICategoryGenerator, @"def": @{ @"inputPoint0": v(0, 0), @"inputPoint1": v(200, 200), @"inputColor0": [CIColor whiteColor], @"inputColor1": [CIColor blackColor] } },
    };
    return r;
}

@implementation CIFilter { NSMutableDictionary *_in; }
+ (CIFilter *)filterWithName:(NSString *)name {
    if (!registry()[name]) return nil;
    CIFilter *f = [self new]; f.name = name; f->_in = [NSMutableDictionary dictionary]; [f setDefaults];
    return f;
}
+ (CIFilter *)filterWithName:(NSString *)name withInputParameters:(NSDictionary *)params {
    CIFilter *f = [self filterWithName:name];
    for (NSString *k in params) [f setValue:params[k] forKey:k];
    return f;
}
+ (CIFilter *)filterWithName:(NSString *)name keysAndValues:(id)key0, ... {
    CIFilter *f = [self filterWithName:name];
    va_list ap; va_start(ap, key0);
    for (id k = key0; k; k = va_arg(ap, id)) { id v = va_arg(ap, id); [f setValue:v forKey:k]; }
    va_end(ap);
    return f;
}
+ (NSArray<NSString *> *)filterNamesInCategory:(NSString *)cat {
    NSMutableArray *a = [NSMutableArray array];
    [registry() enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSDictionary *v, BOOL *stop) {
        if (!cat || [cat isEqualToString:kCICategoryBuiltIn] || [cat isEqualToString:kCICategoryStillImage] || [v[@"cat"] isEqualToString:cat]) [a addObject:k];
    }];
    return [a sortedArrayUsingSelector:@selector(compare:)];
}
+ (NSArray<NSString *> *)filterNamesInCategories:(NSArray<NSString *> *)cats {
    if (!cats.count) return [self filterNamesInCategory:nil];
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSet];
    for (NSString *c in cats) [s addObjectsFromArray:[self filterNamesInCategory:c]];
    return s.array;
}
+ (NSString *)localizedNameForFilterName:(NSString *)n { return [n hasPrefix:@"CI"] ? [n substringFromIndex:2] : n; }
- (id)copyWithZone:(NSZone *)z { CIFilter *f = [CIFilter new]; f.name = _name; f->_in = [_in mutableCopy]; return f; }
- (void)setDefaults { [_in addEntriesFromDictionary:registry()[_name][@"def"]]; }
- (NSArray<NSString *> *)inputKeys {
    NSMutableArray *k = [[registry()[_name][@"def"] allKeys] mutableCopy];
    if (![registry()[_name][@"cat"] isEqualToString:kCICategoryGenerator]) [k insertObject:kCIInputImageKey atIndex:0];
    if ([registry()[_name][@"cat"] isEqualToString:kCICategoryCompositeOperation]) [k addObject:kCIInputBackgroundImageKey];
    if ([_name isEqualToString:@"CIQRCodeGenerator"]) [k insertObject:@"inputMessage" atIndex:0];
    return k;
}
- (NSArray<NSString *> *)outputKeys { return @[ kCIOutputImageKey ]; }
- (NSDictionary *)attributes {
    return @{ kCIAttributeFilterName: _name, kCIAttributeFilterDisplayName: [CIFilter localizedNameForFilterName:_name],
              kCIAttributeFilterCategories: @[ registry()[_name][@"cat"], kCICategoryBuiltIn, kCICategoryStillImage ] };
}
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key hasPrefix:@"input"]) { if (value) _in[key] = value; else [_in removeObjectForKey:key]; return; }
    [super setValue:value forKey:key];
}
- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:kCIOutputImageKey]) return self.outputImage;
    if ([key hasPrefix:@"input"]) return _in[key];
    return [super valueForKey:key];
}
- (NSString *)description { return [NSString stringWithFormat:@"<CIFilter %p> %@ %@", self, _name, _in]; }
static double num(id v, double d) { return [v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : d; }
static void rgba_of(CIColor *c, float o[4]) { o[3] = (float)c.alpha; o[0] = (float)(c.red * c.alpha); o[1] = (float)(c.green * c.alpha); o[2] = (float)(c.blue * c.alpha); }
static CIImage *map(CIImage *in, void (^fn)(float p[4])) { __CIMap *m = [__CIMap new]; m->_in = in; m->_fn = fn; m.isimExtent = in.extent; return m; }
/* straight-alpha color function over premultiplied pixels */
static CIImage *map_rgb(CIImage *in, void (^fn)(float c[3])) {
    return map(in, ^(float p[4]) {
        float a = p[3]; if (a <= 0) return;
        float c[3] = { p[0] / a, p[1] / a, p[2] / a };
        fn(c);
        for (int k = 0; k < 3; k++) p[k] = clampf(c[k]) * a;
    });
}
static void adjust(float c[3], float sat, float bright, float contrast) {
    float l = 0.2125f * c[0] + 0.7154f * c[1] + 0.0721f * c[2];
    for (int k = 0; k < 3; k++) { c[k] = l + sat * (c[k] - l); c[k] += bright; c[k] = (c[k] - 0.5f) * contrast + 0.5f; }
}
static void gray(float c[3], float contrast, float lift) {
    float l = 0.2125f * c[0] + 0.7154f * c[1] + 0.0721f * c[2];
    l = (l - 0.5f) * contrast + 0.5f + lift;
    c[0] = c[1] = c[2] = l;
}
- (CIImage *)outputImage {
    NSString *n = _name;
    CIImage *in = _in[kCIInputImageKey];
    BOOL generator = [registry()[n][@"cat"] isEqualToString:kCICategoryGenerator];
    if (!generator && !in) return nil;
    if ([n isEqualToString:@"CIGaussianBlur"]) return [in imageByApplyingGaussianBlurWithSigma:num(_in[kCIInputRadiusKey], 10)];
    if ([n isEqualToString:@"CIColorControls"]) {
        float s = (float)num(_in[kCIInputSaturationKey], 1), b = (float)num(_in[kCIInputBrightnessKey], 0), c = (float)num(_in[kCIInputContrastKey], 1);
        return map_rgb(in, ^(float x[3]) { adjust(x, s, b, c); });
    }
    if ([n isEqualToString:@"CISepiaTone"]) {
        float k = (float)num(_in[kCIInputIntensityKey], 1);
        return map_rgb(in, ^(float c[3]) {
            float r = 0.393f * c[0] + 0.769f * c[1] + 0.189f * c[2], g = 0.349f * c[0] + 0.686f * c[1] + 0.168f * c[2], b = 0.272f * c[0] + 0.534f * c[1] + 0.131f * c[2];
            c[0] += (r - c[0]) * k; c[1] += (g - c[1]) * k; c[2] += (b - c[2]) * k;
        });
    }
    if ([n isEqualToString:@"CIColorInvert"]) return map_rgb(in, ^(float c[3]) { for (int k = 0; k < 3; k++) c[k] = 1 - c[k]; });
    if ([n isEqualToString:@"CIColorMatrix"]) {
        CIVector *R = _in[@"inputRVector"], *G = _in[@"inputGVector"], *B = _in[@"inputBVector"], *A = _in[@"inputAVector"], *Z = _in[@"inputBiasVector"];
        f54 M; CIVector *vs[5] = { R, G, B, A, Z };
        for (int i = 0; i < 5; i++) for (int k = 0; k < 4; k++) M.m[i][k] = (float)[vs[i] valueAtIndex:k];
        return map(in, ^(float p[4]) {
            float a = p[3], c[4] = { a > 0 ? p[0] / a : 0, a > 0 ? p[1] / a : 0, a > 0 ? p[2] / a : 0, a }, o[4];
            for (int i = 0; i < 4; i++) o[i] = clampf(M.m[i][0] * c[0] + M.m[i][1] * c[1] + M.m[i][2] * c[2] + M.m[i][3] * c[3] + M.m[4][i]);
            for (int k = 0; k < 3; k++) p[k] = o[k] * o[3];
            p[3] = o[3];
        });
    }
    if ([n hasPrefix:@"CIPhotoEffect"]) {
        NSString *e = [n substringFromIndex:13];
        if ([e isEqualToString:@"Mono"]) return map_rgb(in, ^(float c[3]) { gray(c, 1, 0); });
        if ([e isEqualToString:@"Noir"]) return map_rgb(in, ^(float c[3]) { gray(c, 1.45f, -0.03f); });
        if ([e isEqualToString:@"Tonal"]) return map_rgb(in, ^(float c[3]) { gray(c, 1.1f, 0.02f); });
        if ([e isEqualToString:@"Chrome"]) return map_rgb(in, ^(float c[3]) { adjust(c, 1.3f, 0, 1.1f); });
        if ([e isEqualToString:@"Fade"]) return map_rgb(in, ^(float c[3]) { adjust(c, 0.7f, 0, 1); for (int k = 0; k < 3; k++) c[k] = 0.1f + 0.85f * c[k]; });
        if ([e isEqualToString:@"Instant"]) return map_rgb(in, ^(float c[3]) { adjust(c, 0.85f, 0.02f, 0.95f); c[0] *= 1.05f; c[2] *= 0.92f; });
        if ([e isEqualToString:@"Process"]) return map_rgb(in, ^(float c[3]) { adjust(c, 0.9f, 0, 1.08f); c[2] = c[2] * 1.08f + 0.02f; });
        return map_rgb(in, ^(float c[3]) { adjust(c, 1.05f, 0, 1.05f); c[0] *= 1.08f; c[1] *= 1.02f; c[2] *= 0.9f; });      /* Transfer */
    }
    if ([n isEqualToString:@"CIVignette"]) {
        float k = (float)num(_in[kCIInputIntensityKey], 0), rad = (float)num(_in[kCIInputRadiusKey], 1);
        CGRect e = in.extent; double cx = CGRectGetMidX(e), cy = CGRectGetMidY(e), R = hypot(e.size.width, e.size.height) / 2;
        __CIPositional *p = [__CIPositional new]; p->_in = in; p.isimExtent = e;
        p->_fn = ^(double x, double y, float px[4]) {
            double d = hypot(x - cx, y - cy) / (R > 0 ? R : 1), f = 1 - k * fmax(0, fmin(1, (d - 0.5 / fmax(rad, 0.01)) * 2));
            for (int c = 0; c < 3; c++) px[c] *= (float)fmax(0, f);
        };
        return p;
    }
    if ([n isEqualToString:@"CIAffineTransform"]) {
        id v = _in[kCIInputTransformKey]; CGAffineTransform t = CGAffineTransformIdentity;
        if ([v respondsToSelector:@selector(CGAffineTransformValue)]) t = [v CGAffineTransformValue];
        return [in imageByApplyingTransform:t];
    }
    if ([n isEqualToString:@"CICrop"]) return [in imageByCroppingToRect:[(CIVector *)_in[@"inputRectangle"] CGRectValue]];
    if ([n hasSuffix:@"Compositing"]) {
        CIImage *bg = _in[kCIInputBackgroundImageKey];
        if (!bg) return in;
        __CIComposite *c = [__CIComposite new]; c->_fg = in; c->_bg = bg; c->_op = [n hasPrefix:@"CIMultiply"] ? 1 : 0;
        c.isimExtent = CGRectUnion(in.extent, bg.extent);
        return c;
    }
    if ([n isEqualToString:@"CIConstantColorGenerator"]) return [CIImage imageWithColor:_in[kCIInputColorKey] ?: [CIColor blackColor]];
    if ([n isEqualToString:@"CICheckerboardGenerator"]) {
        CGPoint c = [(CIVector *)_in[kCIInputCenterKey] CGPointValue]; double w = fmax(1, num(_in[kCIInputWidthKey], 80));
        f4 c0, c1; rgba_of(_in[@"inputColor0"], c0.v); rgba_of(_in[@"inputColor1"], c1.v);
        __CIGenerator *g = [__CIGenerator new]; g.isimExtent = CGRectInfinite;
        g->_fn = ^(double x, double y, float out[4]) {
            long i = (long)floor((x - c.x) / w), j = (long)floor((y - c.y) / w);
            memcpy(out, ((i + j) & 1) ? c1.v : c0.v, 4 * sizeof(float));
        };
        return g;
    }
    if ([n isEqualToString:@"CILinearGradient"]) {
        CGPoint a = [(CIVector *)_in[@"inputPoint0"] CGPointValue], b = [(CIVector *)_in[@"inputPoint1"] CGPointValue];
        f4 c0, c1; rgba_of(_in[@"inputColor0"], c0.v); rgba_of(_in[@"inputColor1"], c1.v);
        double dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy;
        __CIGenerator *g = [__CIGenerator new]; g.isimExtent = CGRectInfinite;
        g->_fn = ^(double x, double y, float out[4]) {
            float t = L2 > 0 ? clampf((float)(((x - a.x) * dx + (y - a.y) * dy) / L2)) : 0;
            for (int k = 0; k < 4; k++) out[k] = c0.v[k] + (c1.v[k] - c0.v[k]) * t;
        };
        return g;
    }
    if ([n isEqualToString:@"CIQRCodeGenerator"]) {
        NSData *msg = _in[@"inputMessage"];
        if (![msg isKindOfClass:[NSData class]]) return nil;
        NSString *lvl = [_in[@"inputCorrectionLevel"] uppercaseString] ?: @"M";
        int ecl = [lvl isEqualToString:@"L"] ? 0 : [lvl isEqualToString:@"Q"] ? 2 : [lvl isEqualToString:@"H"] ? 3 : 1;
        uint8_t *mods = malloc(177 * 177);
        int s = isim_qr_encode(msg.bytes, (int)msg.length, ecl, mods);
        if (!s) { free(mods); return nil; }
        int W = s + 2;                                                     /* one module of quiet zone, as Core Image */
        unsigned char *px = malloc((size_t)W * W * 4);
        for (int y = 0; y < W; y++) for (int x = 0; x < W; x++) {
            int dark = x > 0 && y > 0 && x <= s && y <= s && mods[(y - 1) * s + (x - 1)];
            unsigned char *p = px + ((size_t)y * W + x) * 4; p[0] = p[1] = p[2] = dark ? 0 : 255; p[3] = 255;
        }
        free(mods);
        CIImage *im = bitmap_from_rgba(px, W, W, W * 4, 1);
        free(px);
        return im;
    }
    return nil;
}
/* typed accessors (CIFilterBuiltins) map to input keys */
#define OBJ(get, set, key) - (id)get { return _in[key]; } - (void)set:(id)v { [self setValue:v forKey:key]; }
#define FLT(get, set, key) - (float)get { return (float)num(_in[key], 0); } - (void)set:(float)v { [self setValue:@(v) forKey:key]; }
OBJ(inputImage, setInputImage, kCIInputImageKey)
OBJ(backgroundImage, setBackgroundImage, kCIInputBackgroundImageKey)
FLT(radius, setRadius, kCIInputRadiusKey)
FLT(saturation, setSaturation, kCIInputSaturationKey)
FLT(brightness, setBrightness, kCIInputBrightnessKey)
FLT(contrast, setContrast, kCIInputContrastKey)
FLT(intensity, setIntensity, kCIInputIntensityKey)
FLT(width, setWidth, kCIInputWidthKey)
FLT(sharpness, setSharpness, kCIInputSharpnessKey)
OBJ(color, setColor, kCIInputColorKey)
OBJ(color0, setColor0, @"inputColor0")
OBJ(color1, setColor1, @"inputColor1")
OBJ(message, setMessage, @"inputMessage")
OBJ(correctionLevel, setCorrectionLevel, @"inputCorrectionLevel")
OBJ(RVector, setRVector, @"inputRVector")
OBJ(GVector, setGVector, @"inputGVector")
OBJ(BVector, setBVector, @"inputBVector")
OBJ(AVector, setAVector, @"inputAVector")
OBJ(biasVector, setBiasVector, @"inputBiasVector")
- (CGPoint)center { return [(CIVector *)_in[kCIInputCenterKey] CGPointValue]; }
- (void)setCenter:(CGPoint)p { [self setValue:[CIVector vectorWithCGPoint:p] forKey:kCIInputCenterKey]; }
- (CGPoint)point0 { return [(CIVector *)_in[@"inputPoint0"] CGPointValue]; }
- (void)setPoint0:(CGPoint)p { [self setValue:[CIVector vectorWithCGPoint:p] forKey:@"inputPoint0"]; }
- (CGPoint)point1 { return [(CIVector *)_in[@"inputPoint1"] CGPointValue]; }
- (void)setPoint1:(CGPoint)p { [self setValue:[CIVector vectorWithCGPoint:p] forKey:@"inputPoint1"]; }
- (CGAffineTransform)transform { id v = _in[kCIInputTransformKey]; return [v respondsToSelector:@selector(CGAffineTransformValue)] ? [v CGAffineTransformValue] : CGAffineTransformIdentity; }
- (void)setTransform:(CGAffineTransform)t { [self setValue:[NSValue valueWithCGAffineTransform:t] forKey:kCIInputTransformKey]; }
@end

@implementation CIFilter (Builtins)
+ (CIFilter<CIGaussianBlur> *)gaussianBlurFilter { return (id)[self filterWithName:@"CIGaussianBlur"]; }
+ (CIFilter<CIColorControls> *)colorControlsFilter { return (id)[self filterWithName:@"CIColorControls"]; }
+ (CIFilter<CISepiaTone> *)sepiaToneFilter { return (id)[self filterWithName:@"CISepiaTone"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectMonoFilter { return (id)[self filterWithName:@"CIPhotoEffectMono"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectNoirFilter { return (id)[self filterWithName:@"CIPhotoEffectNoir"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectChromeFilter { return (id)[self filterWithName:@"CIPhotoEffectChrome"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectFadeFilter { return (id)[self filterWithName:@"CIPhotoEffectFade"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectInstantFilter { return (id)[self filterWithName:@"CIPhotoEffectInstant"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectProcessFilter { return (id)[self filterWithName:@"CIPhotoEffectProcess"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectTonalFilter { return (id)[self filterWithName:@"CIPhotoEffectTonal"]; }
+ (CIFilter<CIPhotoEffect> *)photoEffectTransferFilter { return (id)[self filterWithName:@"CIPhotoEffectTransfer"]; }
+ (CIFilter<CIColorInvert> *)colorInvertFilter { return (id)[self filterWithName:@"CIColorInvert"]; }
+ (CIFilter<CIColorMatrix> *)colorMatrixFilter { return (id)[self filterWithName:@"CIColorMatrix"]; }
+ (CIFilter<CIAffineTransform> *)affineTransformFilter { return (id)[self filterWithName:@"CIAffineTransform"]; }
+ (CIFilter<CICompositeOperation> *)sourceOverCompositingFilter { return (id)[self filterWithName:@"CISourceOverCompositing"]; }
+ (CIFilter<CICompositeOperation> *)multiplyCompositingFilter { return (id)[self filterWithName:@"CIMultiplyCompositing"]; }
+ (CIFilter<CIQRCodeGenerator> *)QRCodeGenerator { return (id)[self filterWithName:@"CIQRCodeGenerator"]; }
+ (CIFilter<CICheckerboardGenerator> *)checkerboardGeneratorFilter { return (id)[self filterWithName:@"CICheckerboardGenerator"]; }
+ (CIFilter<CIConstantColorGenerator> *)constantColorGeneratorFilter { return (id)[self filterWithName:@"CIConstantColorGenerator"]; }
+ (CIFilter<CILinearGradient> *)linearGradientFilter { return (id)[self filterWithName:@"CILinearGradient"]; }
+ (CIFilter<CIVignette> *)vignetteFilter { return (id)[self filterWithName:@"CIVignette"]; }
@end

/* ================= UIKit additions ================= */
static char ci_key;
@implementation UIImage (CoreImage)
+ (UIImage *)imageWithCIImage:(CIImage *)ci { return [[self alloc] initWithCIImage:ci]; }
+ (UIImage *)imageWithCIImage:(CIImage *)ci scale:(CGFloat)s orientation:(UIImageOrientation)o { return [[self alloc] initWithCIImage:ci scale:s orientation:o]; }
- (instancetype)initWithCIImage:(CIImage *)ci { return [self initWithCIImage:ci scale:1 orientation:UIImageOrientationUp]; }
- (instancetype)initWithCIImage:(CIImage *)ci scale:(CGFloat)s orientation:(UIImageOrientation)o {
    static CIContext *ctx; if (!ctx) ctx = [CIContext new];
    CGImageRef cg = ci && !infinite(ci.extent) ? [ctx createCGImage:ci fromRect:ci.extent] : NULL;
    if (!cg) return nil;
    UIImage *img = [self initWithCGImage:cg scale:s orientation:o];
    CGImageRelease(cg);
    if (img) objc_setAssociatedObject(img, &ci_key, ci, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return img;
}
- (CIImage *)CIImage { return objc_getAssociatedObject(self, &ci_key); }
@end
