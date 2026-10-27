/* isim MetalFX: the spatial and temporal scalers (adapted: isim's own upscaling on the CPU). The spatial scaler is an
   edge-adaptive Lanczos-2 upscale (after AMD FSR 1's EASU: the kernel stretches along edges, the result is clamped to the
   nearest pixels' range) followed by contrast-adaptive sharpening (after FSR 1's RCAS). The temporal scaler upscales
   each frame at its jitter and blends it into the history reprojected through the motion vectors, clamped to the
   frame's neighborhood. Encoding adds the work to isim's command buffer, in order with the rest. */
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#import <MetalFX/MetalFX.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

@interface NSObject (ISIMMTLCommands)
- (void)addCommand:(void (^)(void))command;   /* isim's Metal command buffers (frameworks/Metal/MTLCommand.m) */
@end
static void enqueue(id<MTLCommandBuffer> cb, void (^block)(void)) {
    if ([(NSObject *)cb respondsToSelector:@selector(addCommand:)]) [(NSObject *)cb addCommand:block];
    else block();
}

/* ---------------- texels as float RGBA ---------------- */
typedef struct { float *px; NSUInteger w, h; } img;
static float s2l(float c) { return c <= 0.04045f ? c / 12.92f : powf((c + 0.055f) / 1.055f, 2.4f); }
static float l2s(float c) { c = fminf(fmaxf(c, 0), 1); return c <= 0.0031308f ? c * 12.92f : 1.055f * powf(c, 1 / 2.4f) - 0.055f; }
/* bytes per pixel, channels, kind (0 unorm8, 1 half, 2 float), BGRA, sRGB */
static BOOL format(MTLPixelFormat f, int *bpp, int *n, int *kind, int *bgra, int *srgb) {
    *bgra = 0; *srgb = 0;
    switch (f) {
    case MTLPixelFormatRGBA8Unorm: *bpp = 4; *n = 4; *kind = 0; return YES;
    case MTLPixelFormatRGBA8Unorm_sRGB: *bpp = 4; *n = 4; *kind = 0; *srgb = 1; return YES;
    case MTLPixelFormatBGRA8Unorm: *bpp = 4; *n = 4; *kind = 0; *bgra = 1; return YES;
    case MTLPixelFormatBGRA8Unorm_sRGB: *bpp = 4; *n = 4; *kind = 0; *bgra = 1; *srgb = 1; return YES;
    case MTLPixelFormatRGBA16Float: *bpp = 8; *n = 4; *kind = 1; return YES;
    case MTLPixelFormatRG16Float: *bpp = 4; *n = 2; *kind = 1; return YES;
    case MTLPixelFormatR16Float: *bpp = 2; *n = 1; *kind = 1; return YES;
    case MTLPixelFormatRGBA32Float: *bpp = 16; *n = 4; *kind = 2; return YES;
    case MTLPixelFormatRG32Float: *bpp = 8; *n = 2; *kind = 2; return YES;
    case MTLPixelFormatR32Float: case MTLPixelFormatDepth32Float: *bpp = 4; *n = 1; *kind = 2; return YES;
    default: return NO;
    }
}
static img read_tex(id<MTLTexture> t, NSUInteger w, NSUInteger h) {
    img m = { calloc(MAX(w * h, (NSUInteger)1) * 4, sizeof(float)), w, h };
    int bpp, n, kind, bgra, srgb;
    if (!t || !format(t.pixelFormat, &bpp, &n, &kind, &bgra, &srgb)) { if (t) NSLog(@"isim MetalFX: pixel format %lu is not supported", (unsigned long)t.pixelFormat); return m; }
    w = MIN(w, t.width); h = MIN(h, t.height);
    uint8_t *raw = malloc((size_t)bpp * MAX(w * h, (NSUInteger)1));
    [t getBytes:raw bytesPerRow:(NSUInteger)bpp * w fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];
    for (NSUInteger y = 0; y < h; y++)
        for (NSUInteger x = 0; x < w; x++) {
            const uint8_t *p = raw + (y * w + x) * (NSUInteger)bpp;
            float c[4] = { 0, 0, 0, 1 };
            for (int k = 0; k < n; k++) c[k] = kind == 0 ? p[k] / 255.0f : kind == 1 ? (float)((const _Float16 *)p)[k] : ((const float *)p)[k];
            if (bgra) { float b = c[0]; c[0] = c[2]; c[2] = b; }
            if (srgb) for (int k = 0; k < 3; k++) c[k] = s2l(c[k]);
            memcpy(m.px + (y * m.w + x) * 4, c, sizeof c);
        }
    free(raw);
    return m;
}
static void write_tex(id<MTLTexture> t, const img *m) {
    int bpp, n, kind, bgra, srgb;
    if (!t || !format(t.pixelFormat, &bpp, &n, &kind, &bgra, &srgb)) return;
    NSUInteger w = MIN(m->w, t.width), h = MIN(m->h, t.height);
    uint8_t *raw = malloc((size_t)bpp * MAX(w * h, (NSUInteger)1));
    for (NSUInteger y = 0; y < h; y++)
        for (NSUInteger x = 0; x < w; x++) {
            float c[4];
            memcpy(c, m->px + (y * m->w + x) * 4, sizeof c);
            if (srgb) for (int k = 0; k < 3; k++) c[k] = l2s(c[k]);
            if (bgra) { float b = c[0]; c[0] = c[2]; c[2] = b; }
            uint8_t *p = raw + (y * w + x) * (NSUInteger)bpp;
            for (int k = 0; k < n; k++) {
                if (kind == 0) p[k] = (uint8_t)lrintf(fminf(fmaxf(c[k], 0), 1) * 255);
                else if (kind == 1) ((_Float16 *)p)[k] = (_Float16)c[k];
                else ((float *)p)[k] = c[k];
            }
        }
    [t replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:raw bytesPerRow:(NSUInteger)bpp * w];
    free(raw);
}
static inline const float *at(const img *m, NSInteger x, NSInteger y) {
    x = x < 0 ? 0 : x >= (NSInteger)m->w ? (NSInteger)m->w - 1 : x;
    y = y < 0 ? 0 : y >= (NSInteger)m->h ? (NSInteger)m->h - 1 : y;
    return m->px + ((NSUInteger)y * m->w + (NSUInteger)x) * 4;
}
static inline float luma(const float *c) { return 0.299f * c[0] + 0.587f * c[1] + 0.114f * c[2]; }
static float lanczos2(float x) {
    x = fabsf(x);
    if (x >= 2) return 0;
    if (x < 1e-6f) return 1;
    float a = (float)M_PI * x;
    return 2 * sinf(a) * sinf(a / 2) / (a * a);
}

/* ---------------- EASU: an edge-adaptive upscale of the content (cw x ch) of src to ow x oh ---------------- */
static img easu(const img *src, NSUInteger cw, NSUInteger ch, NSUInteger ow, NSUInteger oh, float jx, float jy) {
    img out = { calloc(MAX(ow * oh, (NSUInteger)1) * 4, sizeof(float)), ow, oh };
    float sx = (float)cw / (float)ow, sy = (float)ch / (float)oh;
    for (NSUInteger oy = 0; oy < oh; oy++)
        for (NSUInteger ox = 0; ox < ow; ox++) {
            float px = ((float)ox + 0.5f) * sx - 0.5f - jx, py = ((float)oy + 0.5f) * sy - 0.5f - jy;
            NSInteger ix = (NSInteger)floorf(px), iy = (NSInteger)floorf(py);
            /* the luminance gradient around the 2x2 center: its direction and strength */
            float gx = 0, gy = 0;
            for (int j = 0; j <= 1; j++)
                for (int i = 0; i <= 1; i++) {
                    gx += luma(at(src, ix + i + 1, iy + j)) - luma(at(src, ix + i - 1, iy + j));
                    gy += luma(at(src, ix + i, iy + j + 1)) - luma(at(src, ix + i, iy + j - 1));
                }
            float len = sqrtf(gx * gx + gy * gy), dx = 1, dy = 0;
            if (len > 1e-5f) { dx = gx / len; dy = gy / len; }
            float edge = fminf(len * 2, 1);                       /* 0 flat .. 1 a strong edge */
            float across = 1 + edge, along = 1 - 0.5f * edge;     /* sharper across the edge, wider along it */
            float acc[4] = { 0 }, wsum = 0, mn[4] = { INFINITY, INFINITY, INFINITY, INFINITY }, mx[4] = { -INFINITY, -INFINITY, -INFINITY, -INFINITY };
            for (int j = -1; j <= 2; j++)
                for (int i = -1; i <= 2; i++) {
                    const float *c = at(src, ix + i, iy + j);
                    float vx = (float)(ix + i) - px, vy = (float)(iy + j) - py;
                    float a = (vx * dx + vy * dy) * across, b = (-vx * dy + vy * dx) * along;
                    float w = lanczos2(sqrtf(a * a + b * b));
                    for (int k = 0; k < 4; k++) acc[k] += w * c[k];
                    wsum += w;
                    if (i >= 0 && i <= 1 && j >= 0 && j <= 1) for (int k = 0; k < 4; k++) { mn[k] = fminf(mn[k], c[k]); mx[k] = fmaxf(mx[k], c[k]); }
                }
            float *o = out.px + (oy * ow + ox) * 4;
            for (int k = 0; k < 4; k++) o[k] = fminf(fmaxf(wsum != 0 ? acc[k] / wsum : 0, mn[k]), mx[k]);   /* no ringing */
        }
    return out;
}
/* ---------------- RCAS: contrast-adaptive sharpening ---------------- */
static void rcas(img *m, float sharpness) {
    img src = { malloc(m->w * m->h * 4 * sizeof(float) + 1), m->w, m->h };
    memcpy(src.px, m->px, m->w * m->h * 4 * sizeof(float));
    for (NSUInteger y = 0; y < m->h; y++)
        for (NSUInteger x = 0; x < m->w; x++) {
            const float *c = at(&src, (NSInteger)x, (NSInteger)y), *n = at(&src, (NSInteger)x, (NSInteger)y - 1), *s = at(&src, (NSInteger)x, (NSInteger)y + 1);
            const float *e = at(&src, (NSInteger)x + 1, (NSInteger)y), *w = at(&src, (NSInteger)x - 1, (NSInteger)y);
            /* FSR's limits: the strongest negative lobe that keeps the result in [0, 1], from the four neighbors; the
               channel needing the least sharpening decides */
            float lobe = -INFINITY;
            for (int k = 0; k < 3; k++) {
                float mn = fminf(fminf(n[k], s[k]), fminf(e[k], w[k])), mx = fmaxf(fmaxf(n[k], s[k]), fmaxf(e[k], w[k]));
                float hitMin = mx > 0 ? mn / (4 * mx) : 0, hitMax = 4 * mn - 4 != 0 ? (1 - mx) / (4 * mn - 4) : 0;
                lobe = fmaxf(lobe, fmaxf(-hitMin, hitMax));
            }
            lobe = fmaxf(-0.1875f, fminf(lobe, 0)) * sharpness;
            float *o = m->px + (y * m->w + x) * 4;
            for (int k = 0; k < 3; k++) o[k] = (lobe * (n[k] + s[k] + e[k] + w[k]) + c[k]) / (4 * lobe + 1);
        }
    free(src.px);
}
/* HDR colors through a reversible tonemap while upscaling */
static void tonemap(img *m, BOOL inverse) {
    for (NSUInteger i = 0; i < m->w * m->h; i++) {
        float *c = m->px + i * 4, mx = fmaxf(fmaxf(c[0], c[1]), c[2]);
        float f = inverse ? (mx < 1 ? 1 / (1 - mx) : 1e4f) : 1 / (1 + mx);
        for (int k = 0; k < 3; k++) c[k] *= f;
    }
}

/* ---------------- the spatial scaler ---------------- */
@interface _ISIMFXSpatialScaler : NSObject <MTLFXSpatialScaler>
- (instancetype)initWithDescriptor:(MTLFXSpatialScalerDescriptor *)d;
@end
@implementation MTLFXSpatialScalerDescriptor
- (instancetype)init { if ((self = [super init])) { _colorTextureFormat = MTLPixelFormatRGBA8Unorm; _outputTextureFormat = MTLPixelFormatRGBA8Unorm; } return self; }
- (id)copyWithZone:(NSZone *)zone {
    MTLFXSpatialScalerDescriptor *d = [MTLFXSpatialScalerDescriptor new];
    d.colorTextureFormat = _colorTextureFormat; d.outputTextureFormat = _outputTextureFormat; d.inputWidth = _inputWidth; d.inputHeight = _inputHeight;
    d.outputWidth = _outputWidth; d.outputHeight = _outputHeight; d.colorProcessingMode = _colorProcessingMode;
    return d;
}
- (id<MTLFXSpatialScaler>)newSpatialScalerWithDevice:(id<MTLDevice>)device {
    if (!device || !_inputWidth || !_inputHeight || !_outputWidth || !_outputHeight) return nil;
    return [[_ISIMFXSpatialScaler alloc] initWithDescriptor:self];
}
+ (BOOL)supportsDevice:(id<MTLDevice>)device { return device != nil; }
@end

@implementation _ISIMFXSpatialScaler {
    MTLFXSpatialScalerDescriptor *_d;
}
@synthesize inputContentWidth = _inputContentWidth, inputContentHeight = _inputContentHeight, colorTexture = _colorTexture, outputTexture = _outputTexture, fence = _fence;
- (instancetype)initWithDescriptor:(MTLFXSpatialScalerDescriptor *)d {
    if ((self = [super init])) { _d = [d copy]; _inputContentWidth = d.inputWidth; _inputContentHeight = d.inputHeight; }
    return self;
}
- (MTLTextureUsage)colorTextureUsage { return MTLTextureUsageShaderRead; }
- (MTLTextureUsage)outputTextureUsage { return MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget; }
- (MTLPixelFormat)colorTextureFormat { return _d.colorTextureFormat; }
- (MTLPixelFormat)outputTextureFormat { return _d.outputTextureFormat; }
- (NSUInteger)inputWidth { return _d.inputWidth; }
- (NSUInteger)inputHeight { return _d.inputHeight; }
- (NSUInteger)outputWidth { return _d.outputWidth; }
- (NSUInteger)outputHeight { return _d.outputHeight; }
- (MTLFXSpatialScalerColorProcessingMode)colorProcessingMode { return _d.colorProcessingMode; }
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb {
    id<MTLTexture> color = _colorTexture, output = _outputTexture;
    NSUInteger cw = MIN(_inputContentWidth, _d.inputWidth), ch = MIN(_inputContentHeight, _d.inputHeight), ow = _d.outputWidth, oh = _d.outputHeight;
    MTLFXSpatialScalerColorProcessingMode mode = _d.colorProcessingMode;
    if (!color || !output) { NSLog(@"isim MetalFX: the spatial scaler needs its color and output textures"); return; }
    enqueue(cb, ^{
        img src = read_tex(color, cw, ch);
        if (mode == MTLFXSpatialScalerColorProcessingModeHDR) tonemap(&src, NO);
        img out = easu(&src, cw, ch, ow, oh, 0, 0);
        rcas(&out, 0.8f);
        if (mode == MTLFXSpatialScalerColorProcessingModeHDR) tonemap(&out, YES);
        write_tex(output, &out);
        free(src.px); free(out.px);
    });
}
@end

/* ---------------- the temporal scaler ---------------- */
@interface _ISIMFXTemporalScaler : NSObject <MTLFXTemporalScaler>
- (instancetype)initWithDescriptor:(MTLFXTemporalScalerDescriptor *)d;
@end
@implementation MTLFXTemporalScalerDescriptor
- (instancetype)init {
    if ((self = [super init])) {
        _colorTextureFormat = MTLPixelFormatRGBA16Float; _outputTextureFormat = MTLPixelFormatRGBA16Float;
        _depthTextureFormat = MTLPixelFormatDepth32Float; _motionTextureFormat = MTLPixelFormatRG16Float; _inputContentMinScale = 1; _inputContentMaxScale = 3;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLFXTemporalScalerDescriptor *d = [MTLFXTemporalScalerDescriptor new];
    d.colorTextureFormat = _colorTextureFormat; d.depthTextureFormat = _depthTextureFormat; d.motionTextureFormat = _motionTextureFormat;
    d.outputTextureFormat = _outputTextureFormat; d.inputWidth = _inputWidth; d.inputHeight = _inputHeight; d.outputWidth = _outputWidth;
    d.outputHeight = _outputHeight; d.autoExposureEnabled = _autoExposureEnabled; d.requiresSynchronousInitialization = _requiresSynchronousInitialization;
    d.inputContentPropertiesEnabled = _inputContentPropertiesEnabled; d.inputContentMinScale = _inputContentMinScale; d.inputContentMaxScale = _inputContentMaxScale;
    d.reactiveMaskTextureEnabled = _reactiveMaskTextureEnabled; d.reactiveMaskTextureFormat = _reactiveMaskTextureFormat;
    d.jitteredMotionVectorsEnabled = _jitteredMotionVectorsEnabled; d.outputResolutionMotionVectorsEnabled = _outputResolutionMotionVectorsEnabled;
    return d;
}
- (id<MTLFXTemporalScaler>)newTemporalScalerWithDevice:(id<MTLDevice>)device {
    if (!device || !_inputWidth || !_inputHeight || !_outputWidth || !_outputHeight) return nil;
    return [[_ISIMFXTemporalScaler alloc] initWithDescriptor:self];
}
+ (float)supportedInputContentMinScaleForDevice:(id<MTLDevice>)device { return 1; }
+ (float)supportedInputContentMaxScaleForDevice:(id<MTLDevice>)device { return 3; }
+ (BOOL)supportsDevice:(id<MTLDevice>)device { return device != nil; }
@end

@implementation _ISIMFXTemporalScaler {
    MTLFXTemporalScalerDescriptor *_d;
    float *_history;                 /* the previous output, float RGBA */
    NSLock *_lock;
}
@synthesize inputContentWidth = _inputContentWidth, inputContentHeight = _inputContentHeight, colorTexture = _colorTexture, depthTexture = _depthTexture,
            motionTexture = _motionTexture, outputTexture = _outputTexture, exposureTexture = _exposureTexture, reactiveMaskTexture = _reactiveMaskTexture,
            preExposure = _preExposure, jitterOffsetX = _jitterOffsetX, jitterOffsetY = _jitterOffsetY, motionVectorScaleX = _motionVectorScaleX,
            motionVectorScaleY = _motionVectorScaleY, reset = _reset, depthReversed = _depthReversed, fence = _fence,
            colorContentOffsetX = _colorContentOffsetX, colorContentOffsetY = _colorContentOffsetY, depthContentOffsetX = _depthContentOffsetX,
            depthContentOffsetY = _depthContentOffsetY, motionContentOffsetX = _motionContentOffsetX, motionContentOffsetY = _motionContentOffsetY,
            outputOffsetX = _outputOffsetX, outputOffsetY = _outputOffsetY, reactiveMaskContentOffsetX = _reactiveMaskContentOffsetX,
            reactiveMaskContentOffsetY = _reactiveMaskContentOffsetY;
- (instancetype)initWithDescriptor:(MTLFXTemporalScalerDescriptor *)d {
    if ((self = [super init])) {
        _d = [d copy]; _inputContentWidth = d.inputWidth; _inputContentHeight = d.inputHeight;
        _motionVectorScaleX = 1; _motionVectorScaleY = 1; _preExposure = 1; _lock = [NSLock new];
    }
    return self;
}
- (void)dealloc { free(_history); }
- (MTLTextureUsage)colorTextureUsage { return MTLTextureUsageShaderRead; }
- (MTLTextureUsage)depthTextureUsage { return MTLTextureUsageShaderRead; }
- (MTLTextureUsage)motionTextureUsage { return MTLTextureUsageShaderRead; }
- (MTLTextureUsage)reactiveTextureUsage { return MTLTextureUsageShaderRead; }
- (MTLTextureUsage)reactiveMaskTextureUsage { return MTLTextureUsageShaderRead; }
- (MTLTextureUsage)outputTextureUsage { return MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget; }
- (MTLPixelFormat)colorTextureFormat { return _d.colorTextureFormat; }
- (MTLPixelFormat)depthTextureFormat { return _d.depthTextureFormat; }
- (MTLPixelFormat)motionTextureFormat { return _d.motionTextureFormat; }
- (MTLPixelFormat)reactiveMaskTextureFormat { return _d.reactiveMaskTextureFormat; }
- (MTLPixelFormat)outputTextureFormat { return _d.outputTextureFormat; }
- (NSUInteger)inputWidth { return _d.inputWidth; }
- (NSUInteger)inputHeight { return _d.inputHeight; }
- (NSUInteger)outputWidth { return _d.outputWidth; }
- (NSUInteger)outputHeight { return _d.outputHeight; }
- (float)inputContentMinScale { return _d.inputContentMinScale; }
- (float)inputContentMaxScale { return _d.inputContentMaxScale; }
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb {
    id<MTLTexture> color = _colorTexture, motion = _motionTexture, output = _outputTexture;
    if (!color || !output) { NSLog(@"isim MetalFX: the temporal scaler needs its color and output textures"); return; }
    NSUInteger cw = MIN(_inputContentWidth, _d.inputWidth), ch = MIN(_inputContentHeight, _d.inputHeight), ow = _d.outputWidth, oh = _d.outputHeight;
    float jx = _jitterOffsetX, jy = _jitterOffsetY, mx = _motionVectorScaleX, my = _motionVectorScaleY;
    BOOL reset = _reset;
    _reset = NO;
    enqueue(cb, ^{
        img src = read_tex(color, cw, ch), mv = motion ? read_tex(motion, cw, ch) : (img){ NULL, 0, 0 };
        img cur = easu(&src, cw, ch, ow, oh, jx, jy);
        [self->_lock lock];
        BOOL fresh = reset || !self->_history;
        if (!self->_history) self->_history = calloc(ow * oh * 4, sizeof(float));
        float *hist = self->_history, *next = malloc(ow * oh * 4 * sizeof(float));
        float sx = (float)cw / (float)ow, sy = (float)ch / (float)oh;
        for (NSUInteger y = 0; y < oh; y++)
            for (NSUInteger x = 0; x < ow; x++) {
                float *o = next + (y * ow + x) * 4;
                const float *c = cur.px + (y * ow + x) * 4;
                if (fresh) { memcpy(o, c, 4 * sizeof(float)); continue; }
                /* where this pixel was: its motion vector, in input pixels, at output scale */
                float vx = 0, vy = 0;
                if (mv.px) {
                    const float *m = at(&mv, (NSInteger)(((float)x + 0.5f) * sx), (NSInteger)(((float)y + 0.5f) * sy));
                    vx = m[0] * mx / sx; vy = m[1] * my / sy;
                }
                NSInteger hx = (NSInteger)lrintf((float)x + vx), hy = (NSInteger)lrintf((float)y + vy);
                BOOL inside = hx >= 0 && hy >= 0 && hx < (NSInteger)ow && hy < (NSInteger)oh;
                /* the current frame's 3x3 neighborhood bounds the history */
                float lo[4] = { INFINITY, INFINITY, INFINITY, INFINITY }, hi[4] = { -INFINITY, -INFINITY, -INFINITY, -INFINITY };
                for (int j = -1; j <= 1; j++)
                    for (int i = -1; i <= 1; i++) {
                        NSInteger nx = MIN(MAX((NSInteger)x + i, 0), (NSInteger)ow - 1), ny = MIN(MAX((NSInteger)y + j, 0), (NSInteger)oh - 1);
                        const float *q = cur.px + ((NSUInteger)ny * ow + (NSUInteger)nx) * 4;
                        for (int k = 0; k < 4; k++) { lo[k] = fminf(lo[k], q[k]); hi[k] = fmaxf(hi[k], q[k]); }
                    }
                for (int k = 0; k < 4; k++) {
                    float h = inside ? fminf(fmaxf(hist[((NSUInteger)hy * ow + (NSUInteger)hx) * 4 + k], lo[k]), hi[k]) : c[k];
                    o[k] = h + (c[k] - h) * 0.1f;
                }
            }
        memcpy(hist, next, ow * oh * 4 * sizeof(float));
        [self->_lock unlock];
        img out = { next, ow, oh };
        write_tex(output, &out);
        free(next); free(src.px); free(mv.px); free(cur.px);
    });
}
@end
