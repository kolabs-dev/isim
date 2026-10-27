/* isim MetalPerformanceShaders: the image kernels (adapted: isim's own filters on float RGBA, on the CPU). A unary
   kernel writes destination pixel (x, y) of its clip rectangle from the source around (x + offset.x, y + offset.y),
   reading outside the source by its edge mode; each slice of an array texture is filtered alike. */
#import "mps_internal.h"
#include <float.h>

typedef struct { MPSOffset off; MPSImageEdgeMode edge; } mps_ctx;
#define S(X_, Y_) mps_at(s, (NSInteger)(X_) + c.off.x, (NSInteger)(Y_) + c.off.y, c.edge)

@interface MPSUnaryImageKernel ()
/* filters the region of the destination from the source; returns the region it wrote */
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c;
@end

@implementation MPSUnaryImageKernel
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self = [super initWithDevice:device])) { _clipRect = MPSRectNoClip; _edgeMode = MPSImageEdgeModeZero; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder device:(id<MTLDevice>)device {
    if ((self = [super initWithCoder:coder device:device])) { _clipRect = MPSRectNoClip; _edgeMode = (MPSImageEdgeMode)[coder decodeIntegerForKey:@"edgeMode"]; }
    return self;
}
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) mps_set(d, x, y, S(x, y));
    return r;
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceTexture:(id<MTLTexture>)src destinationTexture:(id<MTLTexture>)dst {
    mps_ctx c = { _offset, _edgeMode };
    MTLRegion clip = _clipRect;
    mps_enqueue(cb, ^{
        NSUInteger slices = MIN(mps_slices(src), mps_slices(dst));
        for (NSUInteger sl = 0; sl < slices; sl++) {
            mps_img s = mps_read(src, sl), d = mps_read(dst, sl);
            MTLRegion w = [self _isim_run:&s dst:&d region:mps_clip(clip, dst) ctx:c];
            mps_write(dst, sl, &d, w);
            mps_free(&s); mps_free(&d);
        }
    });
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceImage:(MPSImage *)src destinationImage:(MPSImage *)dst {
    [self encodeToCommandBuffer:cb sourceTexture:src.texture destinationTexture:dst.texture];
}
/* isim filters from a copy of the source, so every kernel can run in place */
- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb inPlaceTexture:(__strong id<MTLTexture> *)texture fallbackCopyAllocator:(MPSCopyAllocator)alloc {
    [self encodeToCommandBuffer:cb sourceTexture:*texture destinationTexture:*texture];
    return YES;
}
- (MPSRegion)sourceRegionForDestinationSize:(MTLSize)size {
    return (MPSRegion){ { (double)_offset.x, (double)_offset.y, 0 }, { (double)size.width, (double)size.height, 1 } };
}
@end

/* ---------------- separable filters ---------------- */
/* d = the source filtered by wx (nx taps, centered) along rows, then wy along columns */
static void separable(const mps_img *s, mps_img *d, MTLRegion r, mps_ctx c, const float *wx, int nx, const float *wy, int ny) {
    int rx = nx / 2, ry = ny / 2;
    NSUInteger tw = r.size.width, th = r.size.height + 2 * (NSUInteger)ry;
    simd_float4 *t = calloc(tw * th + 1, sizeof(simd_float4));
    for (NSUInteger j = 0; j < th; j++)
        for (NSUInteger x = 0; x < tw; x++) {
            simd_float4 a = 0;
            NSInteger sy = (NSInteger)r.origin.y - ry + (NSInteger)j, sx = (NSInteger)(r.origin.x + x);
            for (int k = 0; k < nx; k++) a += wx[k] * S(sx + k - rx, sy);
            t[j * tw + x] = a;
        }
    for (NSUInteger y = 0; y < r.size.height; y++)
        for (NSUInteger x = 0; x < tw; x++) {
            simd_float4 a = 0;
            for (int k = 0; k < ny; k++) a += wy[k] * t[(y + (NSUInteger)k) * tw + x];
            mps_set(d, r.origin.x + x, r.origin.y + y, a);
        }
    free(t);
}

@implementation MPSImageGaussianBlur
- (instancetype)initWithDevice:(id<MTLDevice>)device sigma:(float)sigma { if ((self = [super initWithDevice:device])) { _sigma = sigma; self.edgeMode = MPSImageEdgeModeClamp; } return self; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    if (_sigma <= 0) return [super _isim_run:s dst:d region:r ctx:c];
    int rad = (int)ceilf(3 * _sigma), n = 2 * rad + 1;
    float *w = malloc(sizeof(float) * (size_t)n), sum = 0;
    for (int i = 0; i < n; i++) { w[i] = expf(-(float)((i - rad) * (i - rad)) / (2 * _sigma * _sigma)); sum += w[i]; }
    for (int i = 0; i < n; i++) w[i] /= sum;
    separable(s, d, r, c, w, n, w, n);
    free(w);
    return r;
}
@end

@implementation MPSImageBox
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelWidth:(NSUInteger)kw kernelHeight:(NSUInteger)kh {
    if ((self = [super initWithDevice:device])) { _kernelWidth = kw | 1; _kernelHeight = kh | 1; self.edgeMode = MPSImageEdgeModeClamp; }
    return self;
}
- (float)_isim_weight:(int)i radius:(int)rad { return 1; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    int nx = (int)_kernelWidth, ny = (int)_kernelHeight;
    float *wx = malloc(sizeof(float) * (size_t)nx), *wy = malloc(sizeof(float) * (size_t)ny), sx = 0, sy = 0;
    for (int i = 0; i < nx; i++) sx += wx[i] = [self _isim_weight:i - nx / 2 radius:nx / 2];
    for (int i = 0; i < ny; i++) sy += wy[i] = [self _isim_weight:i - ny / 2 radius:ny / 2];
    for (int i = 0; i < nx; i++) wx[i] /= sx;
    for (int i = 0; i < ny; i++) wy[i] /= sy;
    separable(s, d, r, c, wx, nx, wy, ny);
    free(wx); free(wy);
    return r;
}
@end
@implementation MPSImageTent
- (float)_isim_weight:(int)i radius:(int)rad { return (float)(rad + 1 - abs(i)); }
@end

/* ---------------- windows: convolution, median, morphology ---------------- */
@implementation MPSImageConvolution {
    float *_weights;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelWidth:(NSUInteger)kw kernelHeight:(NSUInteger)kh weights:(const float *)weights {
    if ((self = [super initWithDevice:device])) {
        _kernelWidth = kw; _kernelHeight = kh;
        _weights = malloc(sizeof(float) * kw * kh);
        memcpy(_weights, weights, sizeof(float) * kw * kh);
    }
    return self;
}
- (void)dealloc { free(_weights); }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    NSInteger hw = (NSInteger)_kernelWidth / 2, hh = (NSInteger)_kernelHeight / 2;
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 a = _bias;
            for (NSUInteger j = 0; j < _kernelHeight; j++)
                for (NSUInteger i = 0; i < _kernelWidth; i++) a += _weights[j * _kernelWidth + i] * S((NSInteger)x + (NSInteger)i - hw, (NSInteger)y + (NSInteger)j - hh);
            mps_set(d, x, y, a);
        }
    return r;
}
@end

@implementation MPSImageLaplacian
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 m = S(x, y), v = S(x - 1, y) + S(x + 1, y) + S(x, (NSInteger)y - 1) + S(x, y + 1) - 4 * m + _bias;
            v.w = m.w;
            mps_set(d, x, y, v);
        }
    return r;
}
@end

static const float rec601[3] = { 0.299f, 0.587f, 0.114f };
@implementation MPSImageSobel {
    float _t[3];
}
- (instancetype)initWithDevice:(id<MTLDevice>)device { return [self initWithDevice:device linearGrayColorTransform:rec601]; }
- (instancetype)initWithDevice:(id<MTLDevice>)device linearGrayColorTransform:(const float *)t {
    if ((self = [super initWithDevice:device])) memcpy(_t, t ?: rec601, sizeof _t);
    return self;
}
- (const float *)colorTransform { return _t; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            float l[3][3];
            for (int j = 0; j < 3; j++)
                for (int i = 0; i < 3; i++) { simd_float4 p = S((NSInteger)x + i - 1, (NSInteger)y + j - 1); l[j][i] = _t[0] * p.x + _t[1] * p.y + _t[2] * p.z; }
            float gx = (l[0][2] + 2 * l[1][2] + l[2][2]) - (l[0][0] + 2 * l[1][0] + l[2][0]);
            float gy = (l[2][0] + 2 * l[2][1] + l[2][2]) - (l[0][0] + 2 * l[0][1] + l[0][2]);
            float m = sqrtf(gx * gx + gy * gy);
            mps_set(d, x, y, (simd_float4){ m, m, m, 1 });
        }
    return r;
}
@end

static void sort_f(float *v, int n) {
    for (int i = 1; i < n; i++) { float k = v[i]; int j = i - 1; while (j >= 0 && v[j] > k) { v[j + 1] = v[j]; j--; } v[j + 1] = k; }
}
@implementation MPSImageMedian
+ (NSUInteger)maxKernelDiameter { return 9; }
+ (NSUInteger)minKernelDiameter { return 3; }
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelDiameter:(NSUInteger)kd {
    if ((self = [super initWithDevice:device])) { _kernelDiameter = MIN(MAX(kd | 1, (NSUInteger)3), (NSUInteger)9); self.edgeMode = MPSImageEdgeModeClamp; }
    return self;
}
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    int n = (int)_kernelDiameter, h = n / 2, cnt = n * n;
    float v[4][81];
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            int k = 0;
            for (int j = -h; j <= h; j++)
                for (int i = -h; i <= h; i++, k++) { simd_float4 p = S((NSInteger)x + i, (NSInteger)y + j); v[0][k] = p.x; v[1][k] = p.y; v[2][k] = p.z; v[3][k] = p.w; }
            simd_float4 o;
            for (int ch = 0; ch < 4; ch++) { sort_f(v[ch], cnt); o[ch] = v[ch][cnt / 2]; }
            mps_set(d, x, y, o);
        }
    return r;
}
@end

@implementation MPSImageAreaMax
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelWidth:(NSUInteger)kw kernelHeight:(NSUInteger)kh {
    if ((self = [super initWithDevice:device])) { _kernelWidth = kw | 1; _kernelHeight = kh | 1; self.edgeMode = MPSImageEdgeModeClamp; }
    return self;
}
- (BOOL)_isim_max { return YES; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    NSInteger hw = (NSInteger)_kernelWidth / 2, hh = (NSInteger)_kernelHeight / 2;
    BOOL mx = [self _isim_max];
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 a = mx ? -FLT_MAX : FLT_MAX;
            for (NSInteger j = -hh; j <= hh; j++)
                for (NSInteger i = -hw; i <= hw; i++) a = mx ? v4max(a, S((NSInteger)x + i, (NSInteger)y + j)) : v4min(a, S((NSInteger)x + i, (NSInteger)y + j));
            mps_set(d, x, y, a);
        }
    return r;
}
@end
@implementation MPSImageAreaMin
- (BOOL)_isim_max { return NO; }
@end

@implementation MPSImageDilate {
    float *_values;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device kernelWidth:(NSUInteger)kw kernelHeight:(NSUInteger)kh values:(const float *)values {
    if ((self = [super initWithDevice:device])) {
        _kernelWidth = kw | 1; _kernelHeight = kh | 1; self.edgeMode = MPSImageEdgeModeClamp;
        _values = calloc(_kernelWidth * _kernelHeight, sizeof(float));
        for (NSUInteger j = 0; j < kh; j++) for (NSUInteger i = 0; i < kw; i++) _values[j * _kernelWidth + i] = values[j * kw + i];
    }
    return self;
}
- (void)dealloc { free(_values); }
- (BOOL)_isim_dilate { return YES; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    NSInteger hw = (NSInteger)_kernelWidth / 2, hh = (NSInteger)_kernelHeight / 2;
    BOOL dil = [self _isim_dilate];
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 a = dil ? -FLT_MAX : FLT_MAX;
            for (NSInteger j = -hh; j <= hh; j++)
                for (NSInteger i = -hw; i <= hw; i++) {
                    float p = _values[(j + hh) * (NSInteger)_kernelWidth + i + hw];
                    simd_float4 v = S((NSInteger)x + i, (NSInteger)y + j);
                    a = dil ? v4max(a, v - p) : v4min(a, v + p);
                }
            mps_set(d, x, y, a);
        }
    return r;
}
@end
@implementation MPSImageErode
- (BOOL)_isim_dilate { return NO; }
@end

/* ---------------- thresholds ---------------- */
#define THRESHOLD_IMPL(NAME, MAXV, EXPR) \
    @implementation NAME { float _t[3]; } \
    - (const float *)transform { return _t; } \
    - (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c { \
        float th = self.thresholdValue, mx = MAXV; (void)mx; \
        for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++) \
            for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) { \
                simd_float4 p = S(x, y); \
                float l = _t[0] * p.x + _t[1] * p.y + _t[2] * p.z, v = (EXPR); \
                mps_set(d, x, y, (simd_float4){ v, v, v, 1 }); \
            } \
        return r; \
    }
THRESHOLD_IMPL(MPSImageThresholdBinary, self.maximumValue, l > th ? mx : 0)
- (instancetype)initWithDevice:(id<MTLDevice>)device thresholdValue:(float)t maximumValue:(float)m linearGrayColorTransform:(const float *)tr {
    if ((self = [super initWithDevice:device])) { _thresholdValue = t; _maximumValue = m; memcpy(_t, tr ?: rec601, sizeof _t); }
    return self;
}
@end
THRESHOLD_IMPL(MPSImageThresholdBinaryInverse, self.maximumValue, l > th ? 0 : mx)
- (instancetype)initWithDevice:(id<MTLDevice>)device thresholdValue:(float)t maximumValue:(float)m linearGrayColorTransform:(const float *)tr {
    if ((self = [super initWithDevice:device])) { _thresholdValue = t; _maximumValue = m; memcpy(_t, tr ?: rec601, sizeof _t); }
    return self;
}
@end
THRESHOLD_IMPL(MPSImageThresholdTruncate, 0, l > th ? th : l)
- (instancetype)initWithDevice:(id<MTLDevice>)device thresholdValue:(float)t linearGrayColorTransform:(const float *)tr {
    if ((self = [super initWithDevice:device])) { _thresholdValue = t; memcpy(_t, tr ?: rec601, sizeof _t); }
    return self;
}
@end
THRESHOLD_IMPL(MPSImageThresholdToZero, 0, l > th ? l : 0)
- (instancetype)initWithDevice:(id<MTLDevice>)device thresholdValue:(float)t linearGrayColorTransform:(const float *)tr {
    if ((self = [super initWithDevice:device])) { _thresholdValue = t; memcpy(_t, tr ?: rec601, sizeof _t); }
    return self;
}
@end
THRESHOLD_IMPL(MPSImageThresholdToZeroInverse, 0, l > th ? 0 : l)
- (instancetype)initWithDevice:(id<MTLDevice>)device thresholdValue:(float)t linearGrayColorTransform:(const float *)tr {
    if ((self = [super initWithDevice:device])) { _thresholdValue = t; memcpy(_t, tr ?: rec601, sizeof _t); }
    return self;
}
@end

/* ---------------- resampling ---------------- */
@implementation MPSImageScale {
    MPSScaleTransform _transform; BOOL _hasTransform;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super initWithDevice:device])) self.edgeMode = MPSImageEdgeModeClamp; return self; }
- (const MPSScaleTransform *)scaleTransform { return _hasTransform ? &_transform : NULL; }
- (void)setScaleTransform:(const MPSScaleTransform *)t { _hasTransform = t != NULL; if (t) _transform = *t; }
- (int)_isim_lanczos { return 0; }
static float sinc(float x) { return x == 0 ? 1 : sinf((float)M_PI * x) / ((float)M_PI * x); }
/* weights of the source pixels for a destination pixel along one axis */
static int taps(float center, float scale, int lanczos, int n, int *first, float *w, int maxw) {
    if (!lanczos) {                                       /* bilinear */
        float f = floorf(center); *first = (int)f; float t = center - f;
        w[0] = 1 - t; w[1] = t; return 2;
    }
    float support = scale < 1 ? 3 / scale : 3, step = scale < 1 ? scale : 1;
    int lo = (int)floorf(center - support + 1), hi = (int)floorf(center + support), k = 0;
    float sum = 0;
    *first = lo;
    for (int i = lo; i <= hi && k < maxw; i++, k++) { float x = (i - center) * step; w[k] = fabsf(x) < 3 ? sinc(x) * sinc(x / 3) : 0; sum += w[k]; }
    for (int i = 0; i < k; i++) w[i] /= sum ? sum : 1;
    (void)n;
    return k;
}
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    MPSScaleTransform t = _hasTransform ? _transform : (MPSScaleTransform){ (double)d->w / s->w, (double)d->h / s->h, 0, 0 };
    int lz = [self _isim_lanczos], maxw = 512;
    float *wx = malloc(sizeof(float) * (size_t)maxw), *wy = malloc(sizeof(float) * (size_t)maxw);
    /* rows first: every source row at the destination's columns */
    NSUInteger tw = r.size.width;
    simd_float4 *tmp = calloc(tw * s->h + 1, sizeof(simd_float4));
    for (NSUInteger x = 0; x < tw; x++) {
        float cx = (float)(((double)(r.origin.x + x) + 0.5 - t.translateX) / t.scaleX - 0.5);
        int fx, nx = taps(cx, (float)t.scaleX, lz, (int)s->w, &fx, wx, maxw);
        for (NSUInteger y = 0; y < s->h; y++) {
            simd_float4 a = 0;
            for (int k = 0; k < nx; k++) a += wx[k] * mps_at(s, fx + k, (NSInteger)y, MPSImageEdgeModeClamp);
            tmp[y * tw + x] = a;
        }
    }
    for (NSUInteger y = 0; y < r.size.height; y++) {
        float cy = (float)(((double)(r.origin.y + y) + 0.5 - t.translateY) / t.scaleY - 0.5);
        int fy, ny = taps(cy, (float)t.scaleY, lz, (int)s->h, &fy, wy, maxw);
        for (NSUInteger x = 0; x < tw; x++) {
            simd_float4 a = 0;
            for (int k = 0; k < ny; k++) { NSInteger sy = MIN(MAX(fy + k, 0), (NSInteger)s->h - 1); a += wy[k] * tmp[(NSUInteger)sy * tw + x]; }
            mps_set(d, r.origin.x + x, r.origin.y + y, a);
        }
    }
    free(tmp); free(wx); free(wy);
    return r;
}
@end
@implementation MPSImageLanczosScale
- (instancetype)initWithDevice:(id<MTLDevice>)device { return [super initWithDevice:device]; }
- (int)_isim_lanczos { return 1; }
@end
@implementation MPSImageBilinearScale
- (instancetype)initWithDevice:(id<MTLDevice>)device { return [super initWithDevice:device]; }
@end

@implementation MPSImageConversion {
    float _bg[4]; BOOL _hasBG;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device srcAlpha:(MPSAlphaType)sa destAlpha:(MPSAlphaType)da backgroundColor:(CGFloat *)bg
                conversionInfo:(CGColorConversionInfoRef)info {
    if ((self = [super initWithDevice:device])) {
        _sourceAlpha = sa; _destinationAlpha = da;
        if (bg) { _hasBG = YES; for (int i = 0; i < 4; i++) _bg[i] = (float)bg[i]; }
    }
    return self;
}
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 p = S(x, y);
            if (_sourceAlpha == MPSAlphaTypeAlphaIsOne) p.w = 1;
            simd_float3 col = p.xyz;
            if (_sourceAlpha == MPSAlphaTypePremultiplied && p.w > 0) col /= p.w;        /* straight color */
            if (_destinationAlpha == MPSAlphaTypeAlphaIsOne) {
                if (_hasBG) col = col * p.w + (simd_float3){ _bg[0], _bg[1], _bg[2] } * (1 - p.w);
                p = (simd_float4){ col.x, col.y, col.z, 1 };
            } else if (_destinationAlpha == MPSAlphaTypePremultiplied) p = (simd_float4){ col.x * p.w, col.y * p.w, col.z * p.w, p.w };
            else p = (simd_float4){ col.x, col.y, col.z, p.w };
            mps_set(d, x, y, p);
        }
    return r;
}
@end

@implementation MPSImageTranspose
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) mps_set(d, x, y, S(y, x));
    return r;
}
@end

/* ---------------- statistics, integral images, reductions ---------------- */
static MTLRegion source_region(MTLRegion clip, const mps_img *s) {
    NSUInteger x0 = MIN(clip.origin.x, s->w), y0 = MIN(clip.origin.y, s->h);
    return MTLRegionMake2D(x0, y0, MIN(clip.size.width, s->w - x0), MIN(clip.size.height, s->h - y0));
}
@implementation MPSImageStatisticsMinAndMax
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super initWithDevice:device])) _clipRectSource = MPSRectNoClip; return self; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    MTLRegion sr = source_region(_clipRectSource, s);
    simd_float4 mn = FLT_MAX, mx = -FLT_MAX;
    for (NSUInteger y = sr.origin.y; y < sr.origin.y + sr.size.height; y++)
        for (NSUInteger x = sr.origin.x; x < sr.origin.x + sr.size.width; x++) { simd_float4 p = mps_at(s, (NSInteger)x, (NSInteger)y, c.edge); mn = v4min(mn, p); mx = v4max(mx, p); }
    if (r.size.width < 2 || !r.size.height) return MTLRegionMake2D(0, 0, 0, 0);
    mps_set(d, r.origin.x, r.origin.y, mn); mps_set(d, r.origin.x + 1, r.origin.y, mx);
    return MTLRegionMake2D(r.origin.x, r.origin.y, 2, 1);
}
@end
@implementation MPSImageStatisticsMeanAndVariance
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super initWithDevice:device])) _clipRectSource = MPSRectNoClip; return self; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    MTLRegion sr = source_region(_clipRectSource, s);
    mps_double4 sum = 0, sq = 0;
    double n = (double)(sr.size.width * sr.size.height);
    for (NSUInteger y = sr.origin.y; y < sr.origin.y + sr.size.height; y++)
        for (NSUInteger x = sr.origin.x; x < sr.origin.x + sr.size.width; x++) {
            simd_float4 p = mps_at(s, (NSInteger)x, (NSInteger)y, c.edge);
            mps_double4 q = v4d(p);
            sum += q; sq += q * q;
        }
    mps_double4 mean = n ? sum / n : 0, var = n ? sq / n - mean * mean : 0;
    if (r.size.width < 2 || !r.size.height) return MTLRegionMake2D(0, 0, 0, 0);
    mps_set(d, r.origin.x, r.origin.y, v4f(mean)); mps_set(d, r.origin.x + 1, r.origin.y, v4f(var));
    return MTLRegionMake2D(r.origin.x, r.origin.y, 2, 1);
}
@end
@implementation MPSImageStatisticsMean
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super initWithDevice:device])) _clipRectSource = MPSRectNoClip; return self; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    MTLRegion sr = source_region(_clipRectSource, s);
    mps_double4 sum = 0;
    double n = (double)(sr.size.width * sr.size.height);
    for (NSUInteger y = sr.origin.y; y < sr.origin.y + sr.size.height; y++)
        for (NSUInteger x = sr.origin.x; x < sr.origin.x + sr.size.width; x++) sum += v4d(mps_at(s, (NSInteger)x, (NSInteger)y, c.edge));
    if (!r.size.width || !r.size.height) return MTLRegionMake2D(0, 0, 0, 0);
    mps_set(d, r.origin.x, r.origin.y, v4f(n ? sum / n : 0));
    return MTLRegionMake2D(r.origin.x, r.origin.y, 1, 1);
}
@end

@implementation MPSImageIntegral
- (BOOL)_isim_squares { return NO; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    BOOL sq = [self _isim_squares];
    mps_double4 *col = calloc(r.size.width + 1, sizeof(mps_double4));
    for (NSUInteger y = 0; y < r.size.height; y++) {
        mps_double4 row = 0;
        for (NSUInteger x = 0; x < r.size.width; x++) {
            mps_double4 p = v4d(S(r.origin.x + x, r.origin.y + y));
            row += sq ? p * p : p;
            col[x] += row;
            mps_set(d, r.origin.x + x, r.origin.y + y, v4f(col[x]));
        }
    }
    free(col);
    return r;
}
@end
@implementation MPSImageIntegralOfSquares
- (BOOL)_isim_squares { return YES; }
@end

typedef enum { RED_MIN, RED_MAX, RED_MEAN, RED_SUM } reduction;
@implementation MPSImageReduceUnary
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super initWithDevice:device])) _clipRectSource = MPSRectNoClip; return self; }
- (reduction)_isim_op { return RED_SUM; }
- (BOOL)_isim_rows { return YES; }
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    MTLRegion sr = source_region(_clipRectSource, s);
    reduction op = [self _isim_op];
    BOOL rows = [self _isim_rows];
    NSUInteger outer = rows ? sr.size.height : sr.size.width, inner = rows ? sr.size.width : sr.size.height, written = 0;
    for (NSUInteger o = 0; o < outer; o++) {
        simd_float4 a = op == RED_MIN ? FLT_MAX : op == RED_MAX ? -FLT_MAX : 0;
        for (NSUInteger i = 0; i < inner; i++) {
            simd_float4 p = rows ? mps_at(s, (NSInteger)(sr.origin.x + i), (NSInteger)(sr.origin.y + o), c.edge)
                                 : mps_at(s, (NSInteger)(sr.origin.x + o), (NSInteger)(sr.origin.y + i), c.edge);
            a = op == RED_MIN ? v4min(a, p) : op == RED_MAX ? v4max(a, p) : a + p;
        }
        if (op == RED_MEAN && inner) a /= (float)inner;
        NSUInteger x = rows ? r.origin.x : r.origin.x + o, y = rows ? r.origin.y + o : r.origin.y;
        if (x < r.origin.x + r.size.width && y < r.origin.y + r.size.height) { mps_set(d, x, y, a); written++; }
    }
    if (!written) return MTLRegionMake2D(0, 0, 0, 0);
    return rows ? MTLRegionMake2D(r.origin.x, r.origin.y, 1, written) : MTLRegionMake2D(r.origin.x, r.origin.y, written, 1);
}
@end
#define REDUCE(NAME, OP, ROWS) @implementation NAME \
    - (instancetype)initWithDevice:(id<MTLDevice>)device { return [super initWithDevice:device]; } \
    - (reduction)_isim_op { return OP; } - (BOOL)_isim_rows { return ROWS; } @end
REDUCE(MPSImageReduceRowMin, RED_MIN, YES)
REDUCE(MPSImageReduceColumnMin, RED_MIN, NO)
REDUCE(MPSImageReduceRowMax, RED_MAX, YES)
REDUCE(MPSImageReduceColumnMax, RED_MAX, NO)
REDUCE(MPSImageReduceRowMean, RED_MEAN, YES)
REDUCE(MPSImageReduceColumnMean, RED_MEAN, NO)
REDUCE(MPSImageReduceRowSum, RED_SUM, YES)
REDUCE(MPSImageReduceColumnSum, RED_SUM, NO)

/* ---------------- histograms ---------------- */
static NSUInteger hist_bin(float v, float mn, float mx, NSUInteger n) {
    float t = mx > mn ? (v - mn) / (mx - mn) : 0;
    NSInteger b = (NSInteger)floorf(t * (float)n);
    return (NSUInteger)(b < 0 ? 0 : b >= (NSInteger)n ? (NSInteger)n - 1 : b);
}
@implementation MPSImageHistogram
- (instancetype)initWithDevice:(id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *)info {
    if ((self = [super initWithDevice:device])) { _histogramInfo = *info; _clipRectSource = MPSRectNoClip; _zeroHistogram = YES; _minPixelThresholdValue = 0; }
    return self;
}
- (size_t)histogramSizeForSourceFormat:(MTLPixelFormat)f { return _histogramInfo.numberOfHistogramEntries * sizeof(uint32_t) * (_histogramInfo.histogramForAlpha ? 4 : 3); }
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceTexture:(id<MTLTexture>)source histogram:(id<MTLBuffer>)histogram histogramOffset:(NSUInteger)offset {
    MPSImageHistogramInfo info = _histogramInfo;
    MTLRegion clip = _clipRectSource;
    BOOL zero = _zeroHistogram;
    vector_float4 minT = _minPixelThresholdValue;
    size_t size = [self histogramSizeForSourceFormat:source.pixelFormat];
    mps_enqueue(cb, ^{
        uint32_t *h = (uint32_t *)((uint8_t *)histogram.contents + offset);
        if (zero) memset(h, 0, size);
        mps_img s = mps_read(source, 0);
        MTLRegion sr = source_region(clip, &s);
        int channels = info.histogramForAlpha ? 4 : 3;
        NSUInteger n = info.numberOfHistogramEntries;
        for (NSUInteger y = sr.origin.y; y < sr.origin.y + sr.size.height; y++)
            for (NSUInteger x = sr.origin.x; x < sr.origin.x + sr.size.width; x++) {
                simd_float4 p = mps_at(&s, (NSInteger)x, (NSInteger)y, MPSImageEdgeModeClamp);
                for (int ch = 0; ch < channels; ch++)
                    if (p[ch] >= minT[ch]) h[ch * n + hist_bin(p[ch], info.minPixelValue[ch], info.maxPixelValue[ch], n)]++;
            }
        mps_free(&s);
    });
}
@end

@implementation MPSImageHistogramEqualization {
    NSMutableData *_lut;      /* float per bin per channel */
}
- (instancetype)initWithDevice:(id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *)info {
    if ((self = [super initWithDevice:device])) { _histogramInfo = *info; _lut = [NSMutableData data]; }
    return self;
}
- (void)encodeTransformToCommandBuffer:(id<MTLCommandBuffer>)cb sourceTexture:(id<MTLTexture>)source histogram:(id<MTLBuffer>)histogram
                       histogramOffset:(NSUInteger)offset {
    MPSImageHistogramInfo info = _histogramInfo;
    NSMutableData *lut = _lut;
    mps_enqueue(cb, ^{
        const uint32_t *h = (const uint32_t *)((const uint8_t *)histogram.contents + offset);
        NSUInteger n = info.numberOfHistogramEntries;
        int channels = info.histogramForAlpha ? 4 : 3;
        lut.length = n * 4 * sizeof(float);
        float *l = lut.mutableBytes;
        for (int ch = 0; ch < 4; ch++) {
            if (ch >= channels) { for (NSUInteger i = 0; i < n; i++) l[ch * n + i] = -1; continue; }   /* unchanged */
            double total = 0, cdf = 0, first = 0;
            for (NSUInteger i = 0; i < n; i++) total += h[ch * n + i];
            for (NSUInteger i = 0; i < n; i++) if (h[ch * n + i]) { first = h[ch * n + i]; break; }
            for (NSUInteger i = 0; i < n; i++) {
                cdf += h[ch * n + i];
                double t = total > first ? (cdf - first) / (total - first) : 0;
                l[ch * n + i] = (float)(info.minPixelValue[ch] + fmax(t, 0) * (info.maxPixelValue[ch] - info.minPixelValue[ch]));
            }
        }
    });
}
- (MTLRegion)_isim_run:(const mps_img *)s dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)c {
    NSUInteger n = _histogramInfo.numberOfHistogramEntries;
    const float *l = _lut.length >= n * 4 * sizeof(float) ? _lut.bytes : NULL;
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 p = S(x, y);
            if (l) for (int ch = 0; ch < 4; ch++) {
                float m = l[ch * n + hist_bin(p[ch], _histogramInfo.minPixelValue[ch], _histogramInfo.maxPixelValue[ch], n)];
                if (m >= 0) p[ch] = m;
            }
            mps_set(d, x, y, p);
        }
    return r;
}
@end

/* ---------------- binary kernels and arithmetic ---------------- */
@interface MPSBinaryImageKernel ()
- (MTLRegion)_isim_run:(const mps_img *)a :(const mps_img *)b dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)ca :(mps_ctx)cb;
@end
@implementation MPSBinaryImageKernel
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super initWithDevice:device])) _clipRect = MPSRectNoClip; return self; }
- (instancetype)initWithCoder:(NSCoder *)coder device:(id<MTLDevice>)device { if ((self = [super initWithCoder:coder device:device])) _clipRect = MPSRectNoClip; return self; }
- (MTLRegion)_isim_run:(const mps_img *)a :(const mps_img *)b dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)ca :(mps_ctx)cb { return r; }
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmd primaryTexture:(id<MTLTexture>)pt secondaryTexture:(id<MTLTexture>)st destinationTexture:(id<MTLTexture>)dt {
    mps_ctx ca = { _primaryOffset, _primaryEdgeMode }, cb = { _secondaryOffset, _secondaryEdgeMode };
    MTLRegion clip = _clipRect;
    mps_enqueue(cmd, ^{
        NSUInteger slices = MIN(MIN(mps_slices(pt), mps_slices(st)), mps_slices(dt));
        for (NSUInteger sl = 0; sl < slices; sl++) {
            mps_img a = mps_read(pt, sl), b = mps_read(st, sl), d = mps_read(dt, sl);
            MTLRegion w = [self _isim_run:&a :&b dst:&d region:mps_clip(clip, dt) ctx:ca :cb];
            mps_write(dt, sl, &d, w);
            mps_free(&a); mps_free(&b); mps_free(&d);
        }
    });
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmd primaryImage:(MPSImage *)p secondaryImage:(MPSImage *)s destinationImage:(MPSImage *)d {
    [self encodeToCommandBuffer:cmd primaryTexture:p.texture secondaryTexture:s.texture destinationTexture:d.texture];
}
- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmd primaryTexture:(id<MTLTexture>)p inPlaceSecondaryTexture:(__strong id<MTLTexture> *)s
        fallbackCopyAllocator:(MPSCopyAllocator)alloc {
    [self encodeToCommandBuffer:cmd primaryTexture:p secondaryTexture:*s destinationTexture:*s];
    return YES;
}
- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmd inPlacePrimaryTexture:(__strong id<MTLTexture> *)p secondaryTexture:(id<MTLTexture>)s
        fallbackCopyAllocator:(MPSCopyAllocator)alloc {
    [self encodeToCommandBuffer:cmd primaryTexture:*p secondaryTexture:s destinationTexture:*p];
    return YES;
}
- (MPSRegion)primarySourceRegionForDestinationSize:(MTLSize)size {
    return (MPSRegion){ { (double)_primaryOffset.x, (double)_primaryOffset.y, 0 }, { (double)size.width, (double)size.height, 1 } };
}
- (MPSRegion)secondarySourceRegionForDestinationSize:(MTLSize)size {
    return (MPSRegion){ { (double)_secondaryOffset.x, (double)_secondaryOffset.y, 0 }, { (double)size.width, (double)size.height, 1 } };
}
@end

typedef enum { AR_ADD, AR_SUB, AR_MUL, AR_DIV } arith;
@implementation MPSImageArithmetic
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self = [super initWithDevice:device])) {
        _primaryScale = 1; _secondaryScale = 1; _primaryStrideInPixels = MTLSizeMake(1, 1, 1); _secondaryStrideInPixels = MTLSizeMake(1, 1, 1);
        _minimumValue = -FLT_MAX; _maximumValue = FLT_MAX;
    }
    return self;
}
- (arith)_isim_op { return AR_ADD; }
- (MTLRegion)_isim_run:(const mps_img *)a :(const mps_img *)b dst:(mps_img *)d region:(MTLRegion)r ctx:(mps_ctx)ca :(mps_ctx)cb {
    arith op = [self _isim_op];
    MTLSize ps = _primaryStrideInPixels, ss = _secondaryStrideInPixels;
    for (NSUInteger y = r.origin.y; y < r.origin.y + r.size.height; y++)
        for (NSUInteger x = r.origin.x; x < r.origin.x + r.size.width; x++) {
            simd_float4 p = _primaryScale * mps_at(a, (NSInteger)(x * ps.width) + ca.off.x, (NSInteger)(y * ps.height) + ca.off.y, ca.edge);
            simd_float4 q = _secondaryScale * mps_at(b, (NSInteger)(x * ss.width) + cb.off.x, (NSInteger)(y * ss.height) + cb.off.y, cb.edge);
            simd_float4 v = op == AR_ADD ? p + q : op == AR_SUB ? p - q : op == AR_MUL ? p * q : p / q;
            mps_set(d, x, y, v4clamp(v + _bias, _minimumValue, _maximumValue));
        }
    return r;
}
@end
#define ARITH(NAME, OP) @implementation NAME \
    - (instancetype)initWithDevice:(id<MTLDevice>)device { return [super initWithDevice:device]; } \
    - (arith)_isim_op { return OP; } @end
ARITH(MPSImageAdd, AR_ADD)
ARITH(MPSImageSubtract, AR_SUB)
ARITH(MPSImageMultiply, AR_MUL)
ARITH(MPSImageDivide, AR_DIV)
