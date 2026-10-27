/* isim MetalPerformanceShaders: what the framework's files share. Kernels run on the CPU: encoding adds a block to the
   command buffer (isim's Metal runs a buffer's blocks in order when it is committed); textures are read and written as
   float RGBA through their bytes. */
#pragma once
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework implements what iOS 9-18 declare */
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define MPS_HIDDEN __attribute__((visibility("hidden")))   /* not part of the framework's ABI */

/* float4 helpers (no <simd/simd.h> in isim's SDK) */
typedef double mps_double4 __attribute__((__ext_vector_type__(4)));
static inline simd_float4 v4max(simd_float4 a, simd_float4 b) { return (simd_float4){ fmaxf(a.x, b.x), fmaxf(a.y, b.y), fmaxf(a.z, b.z), fmaxf(a.w, b.w) }; }
static inline simd_float4 v4min(simd_float4 a, simd_float4 b) { return (simd_float4){ fminf(a.x, b.x), fminf(a.y, b.y), fminf(a.z, b.z), fminf(a.w, b.w) }; }
static inline simd_float4 v4clamp(simd_float4 v, float lo, float hi) { return v4min(v4max(v, (simd_float4)lo), (simd_float4)hi); }
static inline mps_double4 v4d(simd_float4 v) { return __builtin_convertvector(v, mps_double4); }
static inline simd_float4 v4f(mps_double4 v) { return __builtin_convertvector(v, simd_float4); }

/* runs the block when the command buffer runs (isim's Metal command buffers take blocks) */
MPS_HIDDEN void mps_enqueue(id<MTLCommandBuffer> commandBuffer, void (^block)(void));

/* a slice of a texture's level 0 as float RGBA (missing channels: 0, alpha 1), row-major */
typedef struct { float *px; NSUInteger w, h; BOOL alpha; } mps_img;
MPS_HIDDEN BOOL mps_format_supported(MTLPixelFormat f);
MPS_HIDDEN NSUInteger mps_format_channels(MTLPixelFormat f);
MPS_HIDDEN mps_img mps_read(id<MTLTexture> t, NSUInteger slice);
/* writes the region of a float RGBA image into the texture (only the format's channels) */
MPS_HIDDEN void mps_write(id<MTLTexture> t, NSUInteger slice, const mps_img *img, MTLRegion region);
MPS_HIDDEN void mps_free(mps_img *img);
MPS_HIDDEN mps_img mps_alloc(NSUInteger w, NSUInteger h);
/* the pixel at (x, y), outside the image by the edge mode */
static inline simd_float4 mps_at(const mps_img *s, NSInteger x, NSInteger y, MPSImageEdgeMode edge) {
    NSInteger w = (NSInteger)s->w, h = (NSInteger)s->h;
    if (x < 0 || y < 0 || x >= w || y >= h) {
        switch (edge) {
        case MPSImageEdgeModeClamp: x = x < 0 ? 0 : x >= w ? w - 1 : x; y = y < 0 ? 0 : y >= h ? h - 1 : y; break;
        case MPSImageEdgeModeMirror:          /* reflected without repeating the edge */
            if (x < 0) x = -x; if (x >= w) x = 2 * w - 2 - x; if (y < 0) y = -y; if (y >= h) y = 2 * h - 2 - y;
            x = x < 0 ? 0 : x >= w ? w - 1 : x; y = y < 0 ? 0 : y >= h ? h - 1 : y; break;
        case MPSImageEdgeModeMirrorWithEdge:
            if (x < 0) x = -x - 1; if (x >= w) x = 2 * w - 1 - x; if (y < 0) y = -y - 1; if (y >= h) y = 2 * h - 1 - y;
            x = x < 0 ? 0 : x >= w ? w - 1 : x; y = y < 0 ? 0 : y >= h ? h - 1 : y; break;
        default: return s->alpha ? (simd_float4){ 0, 0, 0, 0 } : (simd_float4){ 0, 0, 0, 1 };
        }
    }
    const float *p = s->px + ((size_t)y * s->w + (size_t)x) * 4;
    return (simd_float4){ p[0], p[1], p[2], p[3] };
}
static inline void mps_set(mps_img *d, NSUInteger x, NSUInteger y, simd_float4 v) {
    float *p = d->px + ((size_t)y * d->w + x) * 4;
    p[0] = v.x; p[1] = v.y; p[2] = v.z; p[3] = v.w;
}
/* the region of the destination a kernel writes: its clip rectangle within the texture */
MPS_HIDDEN MTLRegion mps_clip(MTLRegion clip, id<MTLTexture> dst);
/* the slices a kernel runs over */
MPS_HIDDEN NSUInteger mps_slices(id<MTLTexture> t);

/* MPSImage: its pixel format for a channel format and channel count */
MPS_HIDDEN MTLPixelFormat mps_image_format(MPSImageFeatureChannelFormat f, NSUInteger channels);

/* data types: an element as a double, and back */
MPS_HIDDEN double mps_load(MPSDataType t, const void *p, NSUInteger i);
MPS_HIDDEN void mps_store(MPSDataType t, void *p, NSUInteger i, double v);
MPS_HIDDEN size_t mps_type_size(MPSDataType t);
