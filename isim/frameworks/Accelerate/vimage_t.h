/* isim vImage: the shared machinery. Every pixel format is a channel count and a sample type; generic operations read
   samples as float (their raw values: 0...255 for 8-bit, 0...65535 for 16U, 4096 per unit for Q12, the value for
   floats and halves) and write them back rounded and clamped, so one implementation serves every format. */
#pragma once
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* only what vImage.h declares is exported: the generic macros also define variants Apple does not have */
#pragma GCC visibility push(hidden)

typedef enum { VT_U8, VT_U16, VT_S16, VT_F16, VT_F32, VT_Q12 } vt_t;
typedef struct { int ch; vt_t t; } vfmt;

#define VF(ch, t) ((vfmt){ ch, t })

static inline size_t vt_size(vt_t t) { return t == VT_U8 ? 1 : t == VT_F32 ? 4 : 2; }
static inline size_t vf_bytes(vfmt f) { return (size_t)f.ch * vt_size(f.t); }
/* the value of 1.0 (opaque alpha, full intensity) */
static inline float vt_one(vt_t t) { return t == VT_U8 ? 255.f : t == VT_U16 ? 65535.f : t == VT_S16 ? 32767.f : t == VT_Q12 ? 4096.f : 1.f; }

static inline float vhalf_to_float(uint16_t h) {
    uint32_t s = (uint32_t)(h >> 15) << 31, e = (h >> 10) & 0x1f, m = h & 0x3ff, bits;
    if (e == 0) {
        if (m == 0) bits = s;
        else { e = 127 - 15 + 1; while (!(m & 0x400)) { m <<= 1; e--; } m &= 0x3ff; bits = s | (e << 23) | (m << 13); }
    } else if (e == 31) bits = s | 0x7f800000 | (m << 13);
    else bits = s | ((e - 15 + 127) << 23) | (m << 13);
    float f; memcpy(&f, &bits, 4); return f;
}
static inline uint16_t vfloat_to_half(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    uint32_t s = (x >> 16) & 0x8000; int32_t e = (int32_t)((x >> 23) & 0xff) - 127 + 15; uint32_t m = x & 0x7fffff;
    if (((x >> 23) & 0xff) == 0xff) return (uint16_t)(s | 0x7c00 | (m ? 0x200 : 0));
    if (e >= 31) return (uint16_t)(s | 0x7c00);
    if (e <= 0) {
        if (e < -10) return (uint16_t)s;
        m |= 0x800000; uint32_t shift = (uint32_t)(14 - e), r = m >> shift, rem = m & ((1u << shift) - 1), half = 1u << (shift - 1);
        if (rem > half || (rem == half && (r & 1))) r++;
        return (uint16_t)(s | r);
    }
    uint32_t r = (uint32_t)(e << 10) | (m >> 13), rem = m & 0x1fff;
    if (rem > 0x1000 || (rem == 0x1000 && (r & 1))) r++;
    return (uint16_t)(s | r);
}

static inline float vrd(const void *row, long i, vt_t t) {
    switch (t) {
    case VT_U8: return ((const uint8_t *)row)[i];
    case VT_U16: return ((const uint16_t *)row)[i];
    case VT_S16: case VT_Q12: return ((const int16_t *)row)[i];
    case VT_F16: return vhalf_to_float(((const uint16_t *)row)[i]);
    default: return ((const float *)row)[i];
    }
}
static inline float vclampf(float v, float lo, float hi) { return v < lo ? lo : v > hi ? hi : v; }
static inline void vwr(void *row, long i, vt_t t, float v) {
    switch (t) {
    case VT_U8: ((uint8_t *)row)[i] = (uint8_t)(v != v ? 0 : vclampf(v, 0, 255) + 0.5f); break;
    case VT_U16: ((uint16_t *)row)[i] = (uint16_t)(v != v ? 0 : vclampf(v, 0, 65535) + 0.5f); break;
    case VT_S16: case VT_Q12: ((int16_t *)row)[i] = (int16_t)(v != v ? 0 : lrintf(vclampf(v, -32768, 32767))); break;
    case VT_F16: ((uint16_t *)row)[i] = vfloat_to_half(v); break;
    default: ((float *)row)[i] = v;
    }
}

static inline const uint8_t *vrow(const vImage_Buffer *b, long y) { return (const uint8_t *)b->data + (size_t)y * b->rowBytes; }
static inline uint8_t *vrowm(const vImage_Buffer *b, long y) { return (uint8_t *)b->data + (size_t)y * b->rowBytes; }
static inline void vget(const vImage_Buffer *b, vfmt f, long x, long y, float *px) {
    const uint8_t *r = vrow(b, y);
    for (int c = 0; c < f.ch; c++) px[c] = vrd(r, x * f.ch + c, f.t);
}
static inline void vput(const vImage_Buffer *b, vfmt f, long x, long y, const float *px) {
    uint8_t *r = vrowm(b, y);
    for (int c = 0; c < f.ch; c++) vwr(r, x * f.ch + c, f.t, px[c]);
}

/* checks shared by every entry point */
#define VCHECK_BUF(b) do { if (!(b) || !(b)->data) return kvImageNullPointerArgument; } while (0)
static inline vImage_Error vcheck2(const vImage_Buffer *s, const vImage_Buffer *d) {
    if (!s || !d || !s->data || !d->data) return kvImageNullPointerArgument;
    return kvImageNoError;
}
static inline vImage_Error vsame(const vImage_Buffer *s, const vImage_Buffer *d) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    return s->width < d->width || s->height < d->height ? kvImageRoiLargerThanInputBuffer : kvImageNoError;
}

/* exactly one edge mode among copy-in-place, background fill, edge extend and truncate kernel */
static inline int vedge(vImage_Flags flags) {
    vImage_Flags m = flags & (kvImageCopyInPlace | kvImageBackgroundColorFill | kvImageEdgeExtend | kvImageTruncateKernel);
    return m && !(m & (m - 1)) ? (int)m : 0;
}

/* the background colour of a planar (scalar) or interleaved (array) format as floats */
static inline void vbg_scalar(float *px, float v) { px[0] = v; px[1] = v; px[2] = v; px[3] = v; }
#define VBG_ARR(px, arr, n, conv) do { for (int c_ = 0; c_ < (n); c_++) (px)[c_] = (arr) ? conv((arr)[c_]) : 0; } while (0)
static inline float vid(float v) { return v; }
static inline float vh2f(uint16_t v) { return vhalf_to_float(v); }

/* the formats isim implements, with their background-colour parameter: X(suffix, channels, sample type, bg type, bg to px) */
#define VBGS(T) T
#define VFORMATS_PLANAR(X) \
    X(Planar8, 1, VT_U8, Pixel_8) X(PlanarF, 1, VT_F32, Pixel_F) X(Planar16U, 1, VT_U16, Pixel_16U) \
    X(Planar16S, 1, VT_S16, Pixel_16S) X(Planar16F, 1, VT_F16, Pixel_16F)
#define VFORMATS_MULTI(X) \
    X(ARGB8888, 4, VT_U8, uint8_t) X(ARGBFFFF, 4, VT_F32, float) X(ARGB16U, 4, VT_U16, uint16_t) \
    X(ARGB16S, 4, VT_S16, int16_t) X(ARGB16F, 4, VT_F16, uint16_t) X(CbCr8, 2, VT_U8, uint8_t) \
    X(CbCr16U, 2, VT_U16, uint16_t) X(CbCr16S, 2, VT_S16, int16_t) X(CbCr16F, 2, VT_F16, uint16_t)
/* a background parameter to floats: halves are stored as their bits */
#define VBG_PLANAR_PX(px, t, v) vbg_scalar(px, (t) == VT_F16 ? vhalf_to_float((uint16_t)(v)) : (float)(v))
#define VBG_MULTI_PX(px, f, arr) do { for (int c_ = 0; c_ < 4; c_++) (px)[c_] = 0; \
    if (arr) for (int c_ = 0; c_ < (f).ch; c_++) (px)[c_] = (f).t == VT_F16 ? vhalf_to_float((uint16_t)(arr)[c_]) : (float)(arr)[c_]; } while (0)

/* sampling with an edge mode: 0 background, 1 extend */
static inline void vsample_px(const vImage_Buffer *b, vfmt f, long x, long y, int extend, const float *bg, float *px) {
    if (x < 0 || y < 0 || x >= (long)b->width || y >= (long)b->height) {
        if (!extend) { for (int c = 0; c < f.ch; c++) px[c] = bg[c]; return; }
        x = x < 0 ? 0 : x >= (long)b->width ? (long)b->width - 1 : x;
        y = y < 0 ? 0 : y >= (long)b->height ? (long)b->height - 1 : y;
    }
    vget(b, f, x, y, px);
}
/* bilinear sampling at (x, y), pixel centers at integers */
static inline void vsample_linear(const vImage_Buffer *b, vfmt f, double x, double y, int extend, const float *bg, float *px) {
    long x0 = (long)floor(x), y0 = (long)floor(y);
    float fx = (float)(x - x0), fy = (float)(y - y0), a[4], bq[4], c[4], d[4];
    vsample_px(b, f, x0, y0, extend, bg, a); vsample_px(b, f, x0 + 1, y0, extend, bg, bq);
    vsample_px(b, f, x0, y0 + 1, extend, bg, c); vsample_px(b, f, x0 + 1, y0 + 1, extend, bg, d);
    for (int k = 0; k < f.ch; k++) px[k] = (a[k] * (1 - fx) + bq[k] * fx) * (1 - fy) + (c[k] * (1 - fx) + d[k] * fx) * fy;
}

/* defined in vimage_geom.c, used by the filters too */
float _isim_vimage_lanczos(float x, float a);
