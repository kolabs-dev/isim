/* isim vImage: format conversions. Planar <-> interleaved, bit depths (8-bit, 16U, 16S, 16F, 16Q12, float), packed
   16-bit layouts (565, 1555, 5551), bit planes and indexed images, chunky <-> planar, and 8-bit Y'CbCr (4:2:0, 4:2:2,
   4:4:4) with the ITU-R 601 and 709 matrices. The _dithered conversions round to nearest instead of dithering
   (adapted). */
#include "vimage_t.h"

/* ---- one sample to one sample ---- */

typedef float (*vsfn)(float v, const float *p);
static vImage_Error map1(const vImage_Buffer *s, const vImage_Buffer *d, vt_t ts, vt_t td, vsfn fn, const float *p) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (s->data == d->data && vt_size(ts) < vt_size(td)) return kvImageOutOfPlaceOperationRequired;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) vwr(w, (long)x, td, fn(vrd(r, (long)x, ts), p));
    }
    return kvImageNoError;
}
static float f_8toF(float v, const float *p) { return p[1] + (p[0] - p[1]) * v / 255.f; }        /* p: max, min */
static float f_Fto8(float v, const float *p) { return p[0] > p[1] ? (v - p[1]) / (p[0] - p[1]) * 255.f : 0; }
static float f_offscale(float v, const float *p) { return p[0] + p[1] * v; }                      /* p: offset, scale */
static float f_unoffscale(float v, const float *p) { return p[1] != 0 ? (v - p[0]) / p[1] : 0; }
static float f_mul(float v, const float *p) { return v * p[0]; }

vImage_Error vImageConvert_Planar8toPlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, Pixel_F maxFloat, Pixel_F minFloat, vImage_Flags flags) {
    float p[2] = { maxFloat, minFloat }; return map1(src, dest, VT_U8, VT_F32, f_8toF, p);
}
vImage_Error vImageConvert_PlanarFtoPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, Pixel_F maxFloat, Pixel_F minFloat, vImage_Flags flags) {
    float p[2] = { maxFloat, minFloat }; return map1(src, dest, VT_F32, VT_U8, f_Fto8, p);
}
vImage_Error vImageConvert_PlanarFtoPlanar8_dithered(const vImage_Buffer *src, const vImage_Buffer *dest, Pixel_F maxFloat, Pixel_F minFloat,
                                                     int dither, vImage_Flags flags) {
    return vImageConvert_PlanarFtoPlanar8(src, dest, maxFloat, minFloat, flags);
}
vImage_Error vImageConvert_16UToF(const vImage_Buffer *src, const vImage_Buffer *dest, float offset, float scale, vImage_Flags flags) {
    float p[2] = { offset, scale }; return map1(src, dest, VT_U16, VT_F32, f_offscale, p);
}
vImage_Error vImageConvert_16SToF(const vImage_Buffer *src, const vImage_Buffer *dest, float offset, float scale, vImage_Flags flags) {
    float p[2] = { offset, scale }; return map1(src, dest, VT_S16, VT_F32, f_offscale, p);
}
vImage_Error vImageConvert_FTo16U(const vImage_Buffer *src, const vImage_Buffer *dest, float offset, float scale, vImage_Flags flags) {
    float p[2] = { offset, scale }; return map1(src, dest, VT_F32, VT_U16, f_unoffscale, p);
}
vImage_Error vImageConvert_FTo16S(const vImage_Buffer *src, const vImage_Buffer *dest, float offset, float scale, vImage_Flags flags) {
    float p[2] = { offset, scale }; return map1(src, dest, VT_F32, VT_S16, f_unoffscale, p);
}
#define SCALE1(name, ts, td, k) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { \
        float p[1] = { (float)(k) }; return map1(src, dest, ts, td, f_mul, p); }
SCALE1(Planar8To16U, VT_U8, VT_U16, 257.0) SCALE1(16UToPlanar8, VT_U16, VT_U8, 1 / 257.0)
SCALE1(12UTo16U, VT_U16, VT_U16, 65535.0 / 4095) SCALE1(16UTo12U, VT_U16, VT_U16, 4095.0 / 65535)
SCALE1(Planar16FtoPlanarF, VT_F16, VT_F32, 1) SCALE1(PlanarFtoPlanar16F, VT_F32, VT_F16, 1)
SCALE1(Planar8toPlanar16F, VT_U8, VT_F16, 1 / 255.0) SCALE1(Planar16FtoPlanar8, VT_F16, VT_U8, 255)
SCALE1(16Uto16F, VT_U16, VT_F16, 1 / 65535.0) SCALE1(16Fto16U, VT_F16, VT_U16, 65535)
SCALE1(8to16Q12, VT_U8, VT_Q12, 4096 / 255.0) SCALE1(16Q12to8, VT_Q12, VT_U8, 255 / 4096.0)
SCALE1(16Q12toF, VT_Q12, VT_F32, 1 / 4096.0) SCALE1(Fto16Q12, VT_F32, VT_Q12, 4096)
SCALE1(16Q12to16F, VT_Q12, VT_F16, 1 / 4096.0) SCALE1(16Fto16Q12, VT_F16, VT_Q12, 4096)
SCALE1(16Q12to16U, VT_Q12, VT_U16, 65535 / 4096.0) SCALE1(16Uto16Q12, VT_U16, VT_Q12, 4096 / 65535.0)
vImage_Error vImageConvert_Planar16UtoPlanar8_dithered(const vImage_Buffer *src, const vImage_Buffer *dest, int dither, vImage_Flags flags) {
    return vImageConvert_16UToPlanar8(src, dest, flags);
}

/* ---- planar <-> interleaved ----
   n planes of type tp <-> an interleaved buffer of `ch` channels of type ti; plane i is channel order[i] (order[i] < 0:
   that channel is filled with fill[i]); scale[i] / bias[i] map plane values to interleaved ones (inverted going back) */
typedef struct { int n, ch; vt_t tp, ti; int order[4]; float fill[4], scale[4], bias[4]; } vinter;

static vImage_Error interleave(const vImage_Buffer *const *planes, const vImage_Buffer *d, const vinter *v) {
    VCHECK_BUF(d);
    for (int i = 0; i < v->n; i++) if (v->order[i] >= 0) { vImage_Error e = vsame(planes[i], d); if (e) return e; }
    for (vImagePixelCount y = 0; y < d->height; y++) {
        uint8_t *w = vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++)
            for (int i = 0; i < v->n; i++) {
                float val = v->order[i] >= 0 ? vrd(vrow(planes[i], (long)y), (long)x, v->tp) * v->scale[i] + v->bias[i] : v->fill[i];
                vwr(w, (long)(x * (size_t)v->ch) + (v->order[i] >= 0 ? v->order[i] : -1 - v->order[i]), v->ti, val);
            }
    }
    return kvImageNoError;
}
static vImage_Error deinterleave(const vImage_Buffer *s, const vImage_Buffer *const *planes, const vinter *v) {
    VCHECK_BUF(s);
    for (int i = 0; i < v->n; i++) if (planes[i]) { vImage_Error e = vsame(s, planes[i]); if (e) return e; }
    for (vImagePixelCount y = 0; y < s->height; y++) {
        const uint8_t *r = vrow(s, (long)y);
        for (vImagePixelCount x = 0; x < s->width; x++)
            for (int i = 0; i < v->n; i++) {
                if (!planes[i] || x >= planes[i]->width || y >= planes[i]->height) continue;
                float val = vrd(r, (long)(x * (size_t)v->ch) + v->order[i], v->ti);
                vwr(vrowm(planes[i], (long)y), (long)x, v->tp, v->scale[i] != 0 ? (val - v->bias[i]) / v->scale[i] : 0);
            }
    }
    return kvImageNoError;
}
static vinter vi(int n, int ch, vt_t tp, vt_t ti, int o0, int o1, int o2, int o3) {
    vinter v = { n, ch, tp, ti, { o0, o1, o2, o3 }, { 0 }, { 1, 1, 1, 1 }, { 0 } };
    return v;
}
/* the plane -> interleaved scale that maps [0, 255] to [min, max] (8-bit planes to float) and back */
static void vi_range8(vinter *v, const float *maxf, const float *minf, int to_float) {
    for (int i = 0; i < 4; i++) {
        float mx = maxf ? maxf[i] : 1, mn = minf ? minf[i] : 0;
        if (to_float) { v->scale[i] = (mx - mn) / 255.f; v->bias[i] = mn; }
        else { v->scale[i] = mx > mn ? 255.f / (mx - mn) : 0; v->bias[i] = mx > mn ? -mn * 255.f / (mx - mn) : 0; }
    }
}

vImage_Error vImageConvert_Planar8toARGB8888(const vImage_Buffer *srcA, const vImage_Buffer *srcR, const vImage_Buffer *srcG, const vImage_Buffer *srcB,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { srcA, srcR, srcG, srcB }; vinter v = vi(4, 4, VT_U8, VT_U8, 0, 1, 2, 3); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_ARGB8888toPlanar8(const vImage_Buffer *srcARGB, const vImage_Buffer *destA, const vImage_Buffer *destR,
                                             const vImage_Buffer *destG, const vImage_Buffer *destB, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { destA, destR, destG, destB }; vinter v = vi(4, 4, VT_U8, VT_U8, 0, 1, 2, 3); return deinterleave(srcARGB, p, &v);
}
vImage_Error vImageConvert_PlanarFtoARGBFFFF(const vImage_Buffer *srcA, const vImage_Buffer *srcR, const vImage_Buffer *srcG, const vImage_Buffer *srcB,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { srcA, srcR, srcG, srcB }; vinter v = vi(4, 4, VT_F32, VT_F32, 0, 1, 2, 3); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_ARGBFFFFtoPlanarF(const vImage_Buffer *srcARGB, const vImage_Buffer *destA, const vImage_Buffer *destR,
                                             const vImage_Buffer *destG, const vImage_Buffer *destB, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { destA, destR, destG, destB }; vinter v = vi(4, 4, VT_F32, VT_F32, 0, 1, 2, 3); return deinterleave(srcARGB, p, &v);
}
vImage_Error vImageConvert_Planar16UtoARGB16U(const vImage_Buffer *aSrc, const vImage_Buffer *rSrc, const vImage_Buffer *gSrc, const vImage_Buffer *bSrc,
                                              const vImage_Buffer *argbDest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { aSrc, rSrc, gSrc, bSrc }; vinter v = vi(4, 4, VT_U16, VT_U16, 0, 1, 2, 3); return interleave(p, argbDest, &v);
}
vImage_Error vImageConvert_ARGB16UtoPlanar16U(const vImage_Buffer *argbSrc, const vImage_Buffer *aDest, const vImage_Buffer *rDest,
                                              const vImage_Buffer *gDest, const vImage_Buffer *bDest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { aDest, rDest, gDest, bDest }; vinter v = vi(4, 4, VT_U16, VT_U16, 0, 1, 2, 3); return deinterleave(argbSrc, p, &v);
}
vImage_Error vImageConvert_Planar8toRGB888(const vImage_Buffer *planarRed, const vImage_Buffer *planarGreen, const vImage_Buffer *planarBlue,
                                           const vImage_Buffer *rgbDest, vImage_Flags flags) {
    const vImage_Buffer *p[3] = { planarRed, planarGreen, planarBlue }; vinter v = vi(3, 3, VT_U8, VT_U8, 0, 1, 2, 0); return interleave(p, rgbDest, &v);
}
vImage_Error vImageConvert_RGB888toPlanar8(const vImage_Buffer *rgbSrc, const vImage_Buffer *redDest, const vImage_Buffer *greenDest,
                                           const vImage_Buffer *blueDest, vImage_Flags flags) {
    const vImage_Buffer *p[3] = { redDest, greenDest, blueDest }; vinter v = vi(3, 3, VT_U8, VT_U8, 0, 1, 2, 0); return deinterleave(rgbSrc, p, &v);
}
vImage_Error vImageConvert_PlanarFtoRGBFFF(const vImage_Buffer *planarRed, const vImage_Buffer *planarGreen, const vImage_Buffer *planarBlue,
                                           const vImage_Buffer *rgbDest, vImage_Flags flags) {
    const vImage_Buffer *p[3] = { planarRed, planarGreen, planarBlue }; vinter v = vi(3, 3, VT_F32, VT_F32, 0, 1, 2, 0); return interleave(p, rgbDest, &v);
}
vImage_Error vImageConvert_RGBFFFtoPlanarF(const vImage_Buffer *rgbSrc, const vImage_Buffer *redDest, const vImage_Buffer *greenDest,
                                           const vImage_Buffer *blueDest, vImage_Flags flags) {
    const vImage_Buffer *p[3] = { redDest, greenDest, blueDest }; vinter v = vi(3, 3, VT_F32, VT_F32, 0, 1, 2, 0); return deinterleave(rgbSrc, p, &v);
}
vImage_Error vImageConvert_Planar16UtoRGB16U(const vImage_Buffer *rSrc, const vImage_Buffer *gSrc, const vImage_Buffer *bSrc, const vImage_Buffer *rgbDest,
                                             vImage_Flags flags) {
    const vImage_Buffer *p[3] = { rSrc, gSrc, bSrc }; vinter v = vi(3, 3, VT_U16, VT_U16, 0, 1, 2, 0); return interleave(p, rgbDest, &v);
}
vImage_Error vImageConvert_RGB16UtoPlanar16U(const vImage_Buffer *rgbSrc, const vImage_Buffer *rDest, const vImage_Buffer *gDest,
                                             const vImage_Buffer *bDest, vImage_Flags flags) {
    const vImage_Buffer *p[3] = { rDest, gDest, bDest }; vinter v = vi(3, 3, VT_U16, VT_U16, 0, 1, 2, 0); return deinterleave(rgbSrc, p, &v);
}

/* 8-bit planes <-> float interleaved with a range per channel, and the reverse */
vImage_Error vImageConvert_Planar8ToARGBFFFF(const vImage_Buffer *srcA, const vImage_Buffer *srcR, const vImage_Buffer *srcG, const vImage_Buffer *srcB,
                                             const vImage_Buffer *dest, const Pixel_FFFF maxFloat, const Pixel_FFFF minFloat, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { srcA, srcR, srcG, srcB }; vinter v = vi(4, 4, VT_U8, VT_F32, 0, 1, 2, 3);
    vi_range8(&v, maxFloat, minFloat, 1); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_ARGB8888toPlanarF(const vImage_Buffer *src, const vImage_Buffer *destA, const vImage_Buffer *destR, const vImage_Buffer *destG,
                                             const vImage_Buffer *destB, const Pixel_FFFF maxFloat, const Pixel_FFFF minFloat, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { destA, destR, destG, destB }; vinter v = vi(4, 4, VT_F32, VT_U8, 0, 1, 2, 3);
    vi_range8(&v, maxFloat, minFloat, 0); return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_PlanarFToARGB8888(const vImage_Buffer *srcA, const vImage_Buffer *srcR, const vImage_Buffer *srcG, const vImage_Buffer *srcB,
                                             const vImage_Buffer *dest, const Pixel_FFFF maxFloat, const Pixel_FFFF minFloat, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { srcA, srcR, srcG, srcB }; vinter v = vi(4, 4, VT_F32, VT_U8, 0, 1, 2, 3);
    vi_range8(&v, maxFloat, minFloat, 0); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_ARGBFFFFtoPlanar8(const vImage_Buffer *src, const vImage_Buffer *destA, const vImage_Buffer *destR, const vImage_Buffer *destG,
                                             const vImage_Buffer *destB, const Pixel_FFFF maxFloat, const Pixel_FFFF minFloat, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { destA, destR, destG, destB }; vinter v = vi(4, 4, VT_U8, VT_F32, 0, 1, 2, 3);
    vi_range8(&v, maxFloat, minFloat, 1); return deinterleave(src, p, &v);
}

/* XRGB / BGRX: three planes and a constant alpha (or pad) */
vImage_Error vImageConvert_Planar8ToXRGB8888(Pixel_8 alpha, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { NULL, red, green, blue }; vinter v = vi(4, 4, VT_U8, VT_U8, -1, 1, 2, 3); v.fill[0] = alpha; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_Planar8ToBGRX8888(const vImage_Buffer *blue, const vImage_Buffer *green, const vImage_Buffer *red, Pixel_8 alpha,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { blue, green, red, NULL }; vinter v = vi(4, 4, VT_U8, VT_U8, 0, 1, 2, -4); v.fill[3] = alpha; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_PlanarFToXRGBFFFF(Pixel_F alpha, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { NULL, red, green, blue }; vinter v = vi(4, 4, VT_F32, VT_F32, -1, 1, 2, 3); v.fill[0] = alpha; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_PlanarFToBGRXFFFF(const vImage_Buffer *blue, const vImage_Buffer *green, const vImage_Buffer *red, Pixel_F alpha,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { blue, green, red, NULL }; vinter v = vi(4, 4, VT_F32, VT_F32, 0, 1, 2, -4); v.fill[3] = alpha; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_Planar8ToXRGBFFFF(Pixel_F alpha, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                             const vImage_Buffer *dest, const Pixel_F maxFloat[3], const Pixel_F minFloat[3], vImage_Flags flags) {
    const vImage_Buffer *p[4] = { NULL, red, green, blue }; vinter v = vi(4, 4, VT_U8, VT_F32, -1, 1, 2, 3); v.fill[0] = alpha;
    float mx[4] = { 1, maxFloat ? maxFloat[0] : 1, maxFloat ? maxFloat[1] : 1, maxFloat ? maxFloat[2] : 1 };
    float mn[4] = { 0, minFloat ? minFloat[0] : 0, minFloat ? minFloat[1] : 0, minFloat ? minFloat[2] : 0 };
    vi_range8(&v, mx, mn, 1); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_Planar8ToBGRXFFFF(const vImage_Buffer *blue, const vImage_Buffer *green, const vImage_Buffer *red, Pixel_F alpha,
                                             const vImage_Buffer *dest, const Pixel_F maxFloat[3], const Pixel_F minFloat[3], vImage_Flags flags) {
    const vImage_Buffer *p[4] = { blue, green, red, NULL }; vinter v = vi(4, 4, VT_U8, VT_F32, 0, 1, 2, -4); v.fill[3] = alpha;
    vi_range8(&v, maxFloat, minFloat, 1); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_PlanarFToXRGB8888(Pixel_8 alpha, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                             const vImage_Buffer *dest, const Pixel_F maxFloat[3], const Pixel_F minFloat[3], vImage_Flags flags) {
    const vImage_Buffer *p[4] = { NULL, red, green, blue }; vinter v = vi(4, 4, VT_F32, VT_U8, -1, 1, 2, 3); v.fill[0] = alpha;
    float mx[4] = { 1, maxFloat ? maxFloat[0] : 1, maxFloat ? maxFloat[1] : 1, maxFloat ? maxFloat[2] : 1 };
    float mn[4] = { 0, minFloat ? minFloat[0] : 0, minFloat ? minFloat[1] : 0, minFloat ? minFloat[2] : 0 };
    vi_range8(&v, mx, mn, 0); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_PlanarFToBGRX8888(const vImage_Buffer *blue, const vImage_Buffer *green, const vImage_Buffer *red, Pixel_8 alpha,
                                             const vImage_Buffer *dest, const Pixel_F maxFloat[3], const Pixel_F minFloat[3], vImage_Flags flags) {
    const vImage_Buffer *p[4] = { blue, green, red, NULL }; vinter v = vi(4, 4, VT_F32, VT_U8, 0, 1, 2, -4); v.fill[3] = alpha;
    vi_range8(&v, maxFloat, minFloat, 0); return interleave(p, dest, &v);
}
vImage_Error vImageConvert_XRGB8888ToPlanar8(const vImage_Buffer *src, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                             vImage_Flags flags) {
    const vImage_Buffer *p[3] = { red, green, blue }; vinter v = vi(3, 4, VT_U8, VT_U8, 1, 2, 3, 0); return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_BGRX8888ToPlanar8(const vImage_Buffer *src, const vImage_Buffer *blue, const vImage_Buffer *green, const vImage_Buffer *red,
                                             vImage_Flags flags) {
    const vImage_Buffer *p[3] = { blue, green, red }; vinter v = vi(3, 4, VT_U8, VT_U8, 0, 1, 2, 0); return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_XRGBFFFFToPlanarF(const vImage_Buffer *src, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                             vImage_Flags flags) {
    const vImage_Buffer *p[3] = { red, green, blue }; vinter v = vi(3, 4, VT_F32, VT_F32, 1, 2, 3, 0); return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_BGRXFFFFToPlanarF(const vImage_Buffer *src, const vImage_Buffer *blue, const vImage_Buffer *green, const vImage_Buffer *red,
                                             vImage_Flags flags) {
    const vImage_Buffer *p[3] = { blue, green, red }; vinter v = vi(3, 4, VT_F32, VT_F32, 0, 1, 2, 0); return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_ARGB8888toPlanar16Q12(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *red, const vImage_Buffer *green,
                                                 const vImage_Buffer *blue, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { alpha, red, green, blue }; vinter v = vi(4, 4, VT_Q12, VT_U8, 0, 1, 2, 3);
    for (int i = 0; i < 4; i++) v.scale[i] = 255.f / 4096; return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_Planar16Q12toARGB8888(const vImage_Buffer *alpha, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                                 const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { alpha, red, green, blue }; vinter v = vi(4, 4, VT_Q12, VT_U8, 0, 1, 2, 3);
    for (int i = 0; i < 4; i++) v.scale[i] = 255.f / 4096; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_RGB888toPlanar16Q12(const vImage_Buffer *src, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                               vImage_Flags flags) {
    const vImage_Buffer *p[3] = { red, green, blue }; vinter v = vi(3, 3, VT_Q12, VT_U8, 0, 1, 2, 0);
    for (int i = 0; i < 3; i++) v.scale[i] = 255.f / 4096; return deinterleave(src, p, &v);
}
vImage_Error vImageConvert_Planar16Q12toRGB888(const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue, const vImage_Buffer *dest,
                                               vImage_Flags flags) {
    const vImage_Buffer *p[3] = { red, green, blue }; vinter v = vi(3, 3, VT_Q12, VT_U8, 0, 1, 2, 0);
    for (int i = 0; i < 3; i++) v.scale[i] = 255.f / 4096; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_Planar16Q12toARGB16F(const vImage_Buffer *alpha, const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue,
                                                const vImage_Buffer *dest, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { alpha, red, green, blue }; vinter v = vi(4, 4, VT_Q12, VT_F16, 0, 1, 2, 3);
    for (int i = 0; i < 4; i++) v.scale[i] = 1.f / 4096; return interleave(p, dest, &v);
}
vImage_Error vImageConvert_Planar16Q12toRGB16F(const vImage_Buffer *red, const vImage_Buffer *green, const vImage_Buffer *blue, const vImage_Buffer *dest,
                                               vImage_Flags flags) {
    const vImage_Buffer *p[3] = { red, green, blue }; vinter v = vi(3, 3, VT_Q12, VT_F16, 0, 1, 2, 0);
    for (int i = 0; i < 3; i++) v.scale[i] = 1.f / 4096; return interleave(p, dest, &v);
}

/* ---- interleaved <-> interleaved: drop or add alpha, reorder ---- */

/* each destination channel from source channel map[i], or (map[i] < 0) from the alpha plane / constant; premultiply optional */
static vImage_Error reshuffle(const vImage_Buffer *s, const vImage_Buffer *d, int sch, int dch, vt_t ts, vt_t td, const int *map,
                              const vImage_Buffer *alphaPlane, float alpha, int premul_alpha_at, float scale) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (alphaPlane && (e = vsame(alphaPlane, d))) return e;
    if (s->data == d->data && sch * (int)vt_size(ts) < dch * (int)vt_size(td)) return kvImageOutOfPlaceOperationRequired;
    float one = vt_one(td);
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        float a = alpha;
        for (vImagePixelCount x = 0; x < d->width; x++) {
            float px[4];
            if (alphaPlane) a = vrd(vrow(alphaPlane, (long)y), (long)x, td);
            for (int i = 0; i < dch; i++) px[i] = map[i] >= 0 ? vrd(r, (long)(x * (size_t)sch) + map[i], ts) * scale : a;
            if (premul_alpha_at >= 0) for (int i = 0; i < dch; i++) if (i != premul_alpha_at) px[i] *= a / one;
            for (int i = 0; i < dch; i++) vwr(w, (long)(x * (size_t)dch) + i, td, px[i]);
        }
    }
    return kvImageNoError;
}
#define DROP_ALPHA(name, t, m0, m1, m2) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { \
        int map[3] = { m0, m1, m2 }; return reshuffle(src, dest, 4, 3, t, t, map, NULL, 0, -1, 1); }
DROP_ALPHA(ARGB8888toRGB888, VT_U8, 1, 2, 3) DROP_ALPHA(RGBA8888toRGB888, VT_U8, 0, 1, 2) DROP_ALPHA(BGRA8888toRGB888, VT_U8, 2, 1, 0)
DROP_ALPHA(ARGBFFFFtoRGBFFF, VT_F32, 1, 2, 3) DROP_ALPHA(RGBAFFFFtoRGBFFF, VT_F32, 0, 1, 2) DROP_ALPHA(BGRAFFFFtoRGBFFF, VT_F32, 2, 1, 0)
DROP_ALPHA(ARGB16UtoRGB16U, VT_U16, 1, 2, 3) DROP_ALPHA(RGBA16UtoRGB16U, VT_U16, 0, 1, 2) DROP_ALPHA(BGRA16UtoRGB16U, VT_U16, 2, 1, 0)
#define ADD_ALPHA(name, t, T, m0, m1, m2, m3, ai) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *srcA, T alpha, const vImage_Buffer *dest, bool premultiply, \
                                      vImage_Flags flags) { \
        int map[4] = { m0, m1, m2, m3 }; \
        return reshuffle(src, dest, 3, 4, t, t, map, srcA, (float)alpha, premultiply ? ai : -1, 1); }
ADD_ALPHA(RGB888toARGB8888, VT_U8, Pixel_8, -1, 0, 1, 2, 0) ADD_ALPHA(RGB888toRGBA8888, VT_U8, Pixel_8, 0, 1, 2, -1, 3)
ADD_ALPHA(RGB888toBGRA8888, VT_U8, Pixel_8, 2, 1, 0, -1, 3)
ADD_ALPHA(RGBFFFtoARGBFFFF, VT_F32, Pixel_F, -1, 0, 1, 2, 0) ADD_ALPHA(RGBFFFtoRGBAFFFF, VT_F32, Pixel_F, 0, 1, 2, -1, 3)
ADD_ALPHA(RGBFFFtoBGRAFFFF, VT_F32, Pixel_F, 2, 1, 0, -1, 3)
ADD_ALPHA(RGB16UtoARGB16U, VT_U16, Pixel_16U, -1, 0, 1, 2, 0) ADD_ALPHA(RGB16UtoRGBA16U, VT_U16, Pixel_16U, 0, 1, 2, -1, 3)
ADD_ALPHA(RGB16UtoBGRA16U, VT_U16, Pixel_16U, 2, 1, 0, -1, 3)

/* 8 <-> 16 bits with a permutation; channels in copyMask (0x8 = first) come from the background colour */
static vImage_Error widen(const vImage_Buffer *s, const vImage_Buffer *d, int sch, int dch, vt_t ts, vt_t td, const uint8_t *permute,
                          uint8_t mask, const float *bg, float scale) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            float px[4];
            for (int i = 0; i < dch; i++) {
                int from = permute ? permute[i] : i;
                if (from >= sch) from = sch - 1;
                px[i] = (mask & (8 >> i)) ? bg[i] : vrd(r, (long)(x * (size_t)sch) + from, ts) * scale;
            }
            for (int i = 0; i < dch; i++) vwr(w, (long)(x * (size_t)dch) + i, td, px[i]);
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_ARGB8888ToARGB16U(const vImage_Buffer *argb8888Src, const vImage_Buffer *argb16UDest, const uint8_t permuteMap[4],
                                             uint8_t copyMask, const Pixel_ARGB_16U backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U16), backgroundColor);
    return widen(argb8888Src, argb16UDest, 4, 4, VT_U8, VT_U16, permuteMap, copyMask, bg, 257);
}
vImage_Error vImageConvert_ARGB16UToARGB8888(const vImage_Buffer *argb16USrc, const vImage_Buffer *argb8888Dest, const uint8_t permuteMap[4],
                                             uint8_t copyMask, const Pixel_8888 backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return widen(argb16USrc, argb8888Dest, 4, 4, VT_U16, VT_U8, permuteMap, copyMask, bg, 1 / 257.f);
}
vImage_Error vImageConvert_ARGB8888ToRGB16U(const vImage_Buffer *argb8888Src, const vImage_Buffer *rgb16UDest, const uint8_t permuteMap[4],
                                            uint8_t copyMask, const Pixel_16U backgroundColor[3], vImage_Flags flags) {
    float bg[4] = { 0 };
    for (int i = 0; i < 3 && backgroundColor; i++) bg[i] = backgroundColor[i];
    return widen(argb8888Src, rgb16UDest, 4, 3, VT_U8, VT_U16, permuteMap ? permuteMap + 1 : (const uint8_t[]){ 1, 2, 3 }, (uint8_t)(copyMask << 1), bg, 257);
}
vImage_Error vImageConvert_RGB16UToARGB8888(const vImage_Buffer *rgb16USrc, const vImage_Buffer *argb8888Dest, const uint8_t permuteMap[4],
                                            uint8_t copyMask, const Pixel_8888 backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return widen(rgb16USrc, argb8888Dest, 3, 4, VT_U16, VT_U8, permuteMap, copyMask, bg, 1 / 257.f);
}
vImage_Error vImageConvert_ARGB16UtoARGB8888_dithered(const vImage_Buffer *argb16USrc, const vImage_Buffer *argb8888Dest, int dither,
                                                      const uint8_t permuteMap[4], vImage_Flags flags) {
    return widen(argb16USrc, argb8888Dest, 4, 4, VT_U16, VT_U8, permuteMap, 0, (const float[4]){ 0 }, 1 / 257.f);
}
vImage_Error vImageConvert_RGB16UtoRGB888_dithered(const vImage_Buffer *rgb16USrc, const vImage_Buffer *rgb888Dest, int dither, vImage_Flags flags) {
    return widen(rgb16USrc, rgb888Dest, 3, 3, VT_U16, VT_U8, NULL, 0, (const float[4]){ 0 }, 1 / 257.f);
}
vImage_Error vImageConvert_ARGBFFFFtoARGB8888_dithered(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_FFFF maxFloat,
                                                       const Pixel_FFFF minFloat, int dither, const uint8_t permuteMap[4], vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!maxFloat || !minFloat) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) for (vImagePixelCount x = 0; x < dest->width; x++) {
        float p[4], o[4]; vget(src, VF(4, VT_F32), (long)x, (long)y, p);
        for (int i = 0; i < 4; i++) {
            int k = permuteMap ? permuteMap[i] & 3 : i;
            o[i] = maxFloat[k] > minFloat[k] ? (p[k] - minFloat[k]) / (maxFloat[k] - minFloat[k]) * 255 : 0;
        }
        vput(dest, VF(4, VT_U8), (long)x, (long)y, o);
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_RGBFFFtoRGB888_dithered(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_F maxFloat[3],
                                                   const Pixel_F minFloat[3], int dither, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!maxFloat || !minFloat) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) for (vImagePixelCount x = 0; x < dest->width; x++) {
        float p[4], o[4]; vget(src, VF(3, VT_F32), (long)x, (long)y, p);
        for (int i = 0; i < 3; i++) o[i] = maxFloat[i] > minFloat[i] ? (p[i] - minFloat[i]) / (maxFloat[i] - minFloat[i]) * 255 : 0;
        vput(dest, VF(3, VT_U8), (long)x, (long)y, o);
    }
    return kvImageNoError;
}

/* ---- packed 16-bit layouts: 565 (r5 g6 b5), 1555 (a1 r5 g5 b5), 5551 (r5 g5 b5 a1), in host-order words ---- */

typedef struct { int ash, abits, rsh, rbits, gsh, gbits, bsh, bbits; } vpack;
static const vpack P565 = { 0, 0, 11, 5, 5, 6, 0, 5 }, P1555 = { 15, 1, 10, 5, 5, 5, 0, 5 }, P5551 = { 0, 1, 11, 5, 6, 5, 1, 5 };
static inline float unpack_c(uint16_t w, int sh, int bits) { int m = (1 << bits) - 1; return bits ? (float)((w >> sh) & m) * 255.f / (float)m : 255.f; }
static inline uint16_t pack_c(float v, int sh, int bits) { int m = (1 << bits) - 1; return bits ? (uint16_t)(lrintf(vclampf(v, 0, 255) * (float)m / 255.f) << sh) : 0; }
/* argb: the order of a, r, g, b in an 8888 pixel (-1: not there; alpha then comes from `alpha`) */
static vImage_Error unpack(const vImage_Buffer *s, const vImage_Buffer *d, vpack p, int ia, int ir, int ig, int ib, int dch, float alpha) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (s->data == d->data) return kvImageOutOfPlaceOperationRequired;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint16_t *r = (const uint16_t *)vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            uint16_t v = r[x];
            float a = p.abits ? unpack_c(v, p.ash, p.abits) : alpha;
            if (ia >= 0) vwr(w, (long)(x * (size_t)dch) + ia, VT_U8, a);
            vwr(w, (long)(x * (size_t)dch) + ir, VT_U8, unpack_c(v, p.rsh, p.rbits));
            vwr(w, (long)(x * (size_t)dch) + ig, VT_U8, unpack_c(v, p.gsh, p.gbits));
            vwr(w, (long)(x * (size_t)dch) + ib, VT_U8, unpack_c(v, p.bsh, p.bbits));
        }
    }
    return kvImageNoError;
}
static vImage_Error pack(const vImage_Buffer *s, const vImage_Buffer *d, vpack p, int ia, int ir, int ig, int ib, int sch, int alpha_bit) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint16_t *w = (uint16_t *)vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            const uint8_t *q = r + x * (size_t)sch;
            uint16_t v = (uint16_t)(pack_c(q[ir], p.rsh, p.rbits) | pack_c(q[ig], p.gsh, p.gbits) | pack_c(q[ib], p.bsh, p.bbits));
            if (p.abits) v |= (uint16_t)(((ia >= 0 ? q[ia] >= 128 : alpha_bit) ? 1 : 0) << p.ash);
            w[x] = v;
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_RGB565toARGB8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return unpack(src, dest, P565, 0, 1, 2, 3, 4, alpha); }
vImage_Error vImageConvert_RGB565toRGBA8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return unpack(src, dest, P565, 3, 0, 1, 2, 4, alpha); }
vImage_Error vImageConvert_RGB565toBGRA8888(Pixel_8 alpha, const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return unpack(src, dest, P565, 3, 2, 1, 0, 4, alpha); }
vImage_Error vImageConvert_RGB565toRGB888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return unpack(src, dest, P565, -1, 0, 1, 2, 3, 255); }
vImage_Error vImageConvert_ARGB1555toARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return unpack(src, dest, P1555, 0, 1, 2, 3, 4, 255); }
vImage_Error vImageConvert_RGBA5551toRGBA8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return unpack(src, dest, P5551, 3, 0, 1, 2, 4, 255); }
vImage_Error vImageConvert_ARGB8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return pack(src, dest, P565, 0, 1, 2, 3, 4, 0); }
vImage_Error vImageConvert_RGBA8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return pack(src, dest, P565, 3, 0, 1, 2, 4, 0); }
vImage_Error vImageConvert_BGRA8888toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return pack(src, dest, P565, 3, 2, 1, 0, 4, 0); }
vImage_Error vImageConvert_ARGB8888toARGB1555(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return pack(src, dest, P1555, 0, 1, 2, 3, 4, 0); }
vImage_Error vImageConvert_RGBA8888toRGBA5551(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return pack(src, dest, P5551, 3, 0, 1, 2, 4, 0); }
#define PACK_DITHERED(name, plain) \
    vImage_Error vImageConvert_##name##_dithered(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, int dither, vImage_Flags flags) { \
        if (flags & kvImageGetTempBufferSize) return 0; return plain(src, dest, flags); }
PACK_DITHERED(ARGB8888toRGB565, vImageConvert_ARGB8888toRGB565) PACK_DITHERED(RGBA8888toRGB565, vImageConvert_RGBA8888toRGB565)
PACK_DITHERED(BGRA8888toRGB565, vImageConvert_BGRA8888toRGB565) PACK_DITHERED(ARGB8888toARGB1555, vImageConvert_ARGB8888toARGB1555)
PACK_DITHERED(RGBA8888toRGBA5551, vImageConvert_RGBA8888toRGBA5551)
vImage_Error vImageConvert_RGB888toRGB565_dithered(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, int dither, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    return pack(src, dest, P565, -1, 0, 1, 2, 3, 0);
}
/* 16-bit layout to another: through 8888 */
static vImage_Error repack(const vImage_Buffer *s, const vImage_Buffer *d, vpack from, vpack to, int alpha_bit) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint16_t *r = (const uint16_t *)vrow(s, (long)y); uint16_t *w = (uint16_t *)vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            uint16_t v = r[x];
            float cr = unpack_c(v, from.rsh, from.rbits), cg = unpack_c(v, from.gsh, from.gbits), cb = unpack_c(v, from.bsh, from.bbits);
            int a = from.abits ? (v >> from.ash) & 1 : alpha_bit;
            uint16_t o = (uint16_t)(pack_c(cr, to.rsh, to.rbits) | pack_c(cg, to.gsh, to.gbits) | pack_c(cb, to.bsh, to.bbits));
            if (to.abits) o |= (uint16_t)(a << to.ash);
            w[x] = o;
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_ARGB1555toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return repack(src, dest, P1555, P565, 1); }
vImage_Error vImageConvert_RGBA5551toRGB565(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return repack(src, dest, P5551, P565, 1); }
vImage_Error vImageConvert_RGB565toARGB1555(const vImage_Buffer *src, const vImage_Buffer *dest, int alpha, vImage_Flags flags) { return repack(src, dest, P565, P1555, alpha != 0); }
vImage_Error vImageConvert_RGB565toRGBA5551(const vImage_Buffer *src, const vImage_Buffer *dest, int alpha, vImage_Flags flags) { return repack(src, dest, P565, P5551, alpha != 0); }
/* packed <-> planes */
static vImage_Error packed_planes(const vImage_Buffer *packed, const vImage_Buffer *const *planes, int n, vpack p, int to_planes) {
    VCHECK_BUF(packed);
    for (int i = 0; i < n; i++) { vImage_Error e = vsame(planes[i], packed); if (e) return e; }
    const int sh[4] = { p.ash, p.rsh, p.gsh, p.bsh }, bits[4] = { p.abits, p.rbits, p.gbits, p.bbits };
    int first = n == 3 ? 1 : 0;
    for (vImagePixelCount y = 0; y < packed->height; y++) {
        uint16_t *w = (uint16_t *)vrowm(packed, (long)y);
        for (vImagePixelCount x = 0; x < packed->width; x++) {
            if (to_planes) for (int i = 0; i < n; i++) vrowm(planes[i], (long)y)[x] = (uint8_t)lrintf(unpack_c(w[x], sh[first + i], bits[first + i]));
            else {
                uint16_t v = 0;
                for (int i = 0; i < n; i++) v |= pack_c(vrow(planes[i], (long)y)[x], sh[first + i], bits[first + i]);
                w[x] = v;
            }
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_RGB565toPlanar8(const vImage_Buffer *src, const vImage_Buffer *destR, const vImage_Buffer *destG, const vImage_Buffer *destB,
                                           vImage_Flags flags) {
    const vImage_Buffer *p[3] = { destR, destG, destB }; return packed_planes(src, p, 3, P565, 1);
}
vImage_Error vImageConvert_Planar8toRGB565(const vImage_Buffer *srcR, const vImage_Buffer *srcG, const vImage_Buffer *srcB, const vImage_Buffer *dest,
                                           vImage_Flags flags) {
    VCHECK_BUF(dest);
    const vImage_Buffer *p[3] = { srcR, srcG, srcB }; return packed_planes(dest, p, 3, P565, 0);
}
vImage_Error vImageConvert_ARGB1555toPlanar8(const vImage_Buffer *src, const vImage_Buffer *destA, const vImage_Buffer *destR, const vImage_Buffer *destG,
                                             const vImage_Buffer *destB, vImage_Flags flags) {
    const vImage_Buffer *p[4] = { destA, destR, destG, destB }; return packed_planes(src, p, 4, P1555, 1);
}
vImage_Error vImageConvert_Planar8toARGB1555(const vImage_Buffer *srcA, const vImage_Buffer *srcR, const vImage_Buffer *srcG, const vImage_Buffer *srcB,
                                             const vImage_Buffer *dest, vImage_Flags flags) {
    VCHECK_BUF(dest);
    const vImage_Buffer *p[4] = { srcA, srcR, srcG, srcB }; return packed_planes(dest, p, 4, P1555, 0);
}

/* ---- bit planes and indexed images (most significant bit first) ---- */

static vImage_Error bits_to8(const vImage_Buffer *s, const vImage_Buffer *d, int bits, const Pixel_8 *colors) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->height < d->height || s->width < d->width) return kvImageRoiLargerThanInputBuffer;
    int max = (1 << bits) - 1;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            size_t bit = x * (size_t)bits;
            int v = (r[bit / 8] >> (8 - bits - (int)(bit % 8))) & max;
            w[x] = colors ? colors[v] : (uint8_t)(v * 255 / max);
        }
    }
    return kvImageNoError;
}
static vImage_Error bits_from8(const vImage_Buffer *s, const vImage_Buffer *d, int bits) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->height < d->height || s->width < d->width) return kvImageRoiLargerThanInputBuffer;
    int max = (1 << bits) - 1;
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        memset(w, 0, (d->width * (size_t)bits + 7) / 8);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            size_t bit = x * (size_t)bits;
            int v = (r[x] * max + 127) / 255;
            w[bit / 8] |= (uint8_t)(v << (8 - bits - (int)(bit % 8)));
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_Planar1toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return bits_to8(src, dest, 1, NULL); }
vImage_Error vImageConvert_Planar2toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return bits_to8(src, dest, 2, NULL); }
vImage_Error vImageConvert_Planar4toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return bits_to8(src, dest, 4, NULL); }
vImage_Error vImageConvert_Indexed1toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 colors[2], vImage_Flags flags) { return colors ? bits_to8(src, dest, 1, colors) : kvImageNullPointerArgument; }
vImage_Error vImageConvert_Indexed2toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 colors[4], vImage_Flags flags) { return colors ? bits_to8(src, dest, 2, colors) : kvImageNullPointerArgument; }
vImage_Error vImageConvert_Indexed4toPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 colors[16], vImage_Flags flags) { return colors ? bits_to8(src, dest, 4, colors) : kvImageNullPointerArgument; }
#define TO_BITS(name, bits) \
    vImage_Error vImageConvert_Planar8to##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, int dither, vImage_Flags flags) { \
        if (flags & kvImageGetTempBufferSize) return 0; return bits_from8(src, dest, bits); }
TO_BITS(Planar1, 1) TO_BITS(Planar2, 2) TO_BITS(Planar4, 4)

/* ---- chunky <-> planar: channelCount channels at srcStrideBytes apart, each its own starting pointer ---- */

static vImage_Error chunky(const void *srcChannels[], const vImage_Buffer *destPlanarBuffers[], unsigned channelCount, size_t strideBytes,
                           vImagePixelCount w, vImagePixelCount h, size_t rowBytes, int fp, int to_planar) {
    if (!srcChannels || !destPlanarBuffers) return kvImageNullPointerArgument;
    size_t sz = fp ? 4 : 1;
    for (unsigned c = 0; c < channelCount; c++) {
        if (!srcChannels[c] || !destPlanarBuffers[c] || !destPlanarBuffers[c]->data) return kvImageNullPointerArgument;
        for (vImagePixelCount y = 0; y < h; y++) {
            uint8_t *chunk = (uint8_t *)srcChannels[c] + y * rowBytes;
            uint8_t *plane = vrowm(destPlanarBuffers[c], (long)y);
            for (vImagePixelCount x = 0; x < w; x++) {
                if (to_planar) memcpy(plane + x * sz, chunk + x * strideBytes, sz);
                else memcpy(chunk + x * strideBytes, plane + x * sz, sz);
            }
        }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_ChunkyToPlanar8(const void *srcChannels[], const vImage_Buffer *destPlanarBuffers[], unsigned int channelCount,
                                           size_t srcStrideBytes, vImagePixelCount srcWidth, vImagePixelCount srcHeight, size_t srcRowBytes,
                                           vImage_Flags flags) {
    return chunky(srcChannels, destPlanarBuffers, channelCount, srcStrideBytes, srcWidth, srcHeight, srcRowBytes, 0, 1);
}
vImage_Error vImageConvert_ChunkyToPlanarF(const void *srcChannels[], const vImage_Buffer *destPlanarBuffers[], unsigned int channelCount,
                                           size_t srcStrideBytes, vImagePixelCount srcWidth, vImagePixelCount srcHeight, size_t srcRowBytes,
                                           vImage_Flags flags) {
    return chunky(srcChannels, destPlanarBuffers, channelCount, srcStrideBytes, srcWidth, srcHeight, srcRowBytes, 1, 1);
}
vImage_Error vImageConvert_PlanarToChunky8(const vImage_Buffer *srcPlanarBuffers[], void *destChannels[], unsigned int channelCount,
                                           size_t destStrideBytes, vImagePixelCount destWidth, vImagePixelCount destHeight, size_t destRowBytes,
                                           vImage_Flags flags) {
    return chunky((const void **)destChannels, srcPlanarBuffers, channelCount, destStrideBytes, destWidth, destHeight, destRowBytes, 0, 0);
}
vImage_Error vImageConvert_PlanarToChunkyF(const vImage_Buffer *srcPlanarBuffers[], void *destChannels[], unsigned int channelCount,
                                           size_t destStrideBytes, vImagePixelCount destWidth, vImagePixelCount destHeight, size_t destRowBytes,
                                           vImage_Flags flags) {
    return chunky((const void **)destChannels, srcPlanarBuffers, channelCount, destStrideBytes, destWidth, destHeight, destRowBytes, 1, 0);
}

/* ---- Y'CbCr ---- */

static const vImage_YpCbCrToARGBMatrix m601 = { 1, 1.402f, -0.7141363f, -0.3441363f, 1.772f };
static const vImage_YpCbCrToARGBMatrix m709 = { 1, 1.5748f, -0.4681243f, -0.1873243f, 1.8556f };
static const vImage_ARGBToYpCbCrMatrix a601 = { 0.299f, 0.587f, 0.114f, -0.168736f, -0.331264f, 0.5f, -0.418688f, -0.081312f };
static const vImage_ARGBToYpCbCrMatrix a709 = { 0.2126f, 0.7152f, 0.0722f, -0.114572f, -0.385428f, 0.5f, -0.454153f, -0.045847f };
const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_601_4 = &m601;
const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_709_2 = &m709;
const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4 = &a601;
const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 = &a709;

/* what GenerateConversion stores in the opaque structures */
typedef struct {
    uint32_t magic, yptype;
    float m[8];               /* the matrix */
    float ybias, cbias, yscale, cscale, ymin, ymax, cmin, cmax;   /* code values <-> normalized (Y' 0...1, Cb/Cr -0.5...0.5) */
} vycc;
#define VYCC_MAGIC 0x79636321u
_Static_assert(sizeof(vycc) <= 128, "fits vImage's opaque info");

static void range_into(vycc *v, const vImage_YpCbCrPixelRange *r) {
    v->ybias = (float)r->Yp_bias; v->cbias = (float)r->CbCr_bias;
    v->yscale = (float)(r->YpRangeMax - r->Yp_bias); v->cscale = 2.f * (float)(r->CbCrRangeMax - r->CbCr_bias);
    v->ymin = (float)r->YpMin; v->ymax = (float)r->YpMax; v->cmin = (float)r->CbCrMin; v->cmax = (float)r->CbCrMax;
}
vImage_Error vImageConvert_YpCbCrToARGB_GenerateConversion(const vImage_YpCbCrToARGBMatrix *matrix, const vImage_YpCbCrPixelRange *pixelRange,
                                                           vImage_YpCbCrToARGB *outInfo, vImageYpCbCrType inYpCbCrType, vImageARGBType outARGBType,
                                                           vImage_Flags flags) {
    if (!matrix || !pixelRange || !outInfo) return kvImageNullPointerArgument;
    if (outARGBType != kvImageARGB8888) return kvImageUnsupportedConversion;
    if (pixelRange->YpRangeMax <= pixelRange->Yp_bias || pixelRange->CbCrRangeMax <= pixelRange->CbCr_bias) return kvImageInvalidParameter;
    vycc v = { VYCC_MAGIC, (uint32_t)inYpCbCrType, { matrix->Yp, matrix->Cr_R, matrix->Cr_G, matrix->Cb_G, matrix->Cb_B } };
    range_into(&v, pixelRange);
    memset(outInfo, 0, sizeof *outInfo);
    memcpy(outInfo->opaque, &v, sizeof v);
    return kvImageNoError;
}
vImage_Error vImageConvert_ARGBToYpCbCr_GenerateConversion(const vImage_ARGBToYpCbCrMatrix *matrix, const vImage_YpCbCrPixelRange *pixelRange,
                                                           vImage_ARGBToYpCbCr *outInfo, vImageARGBType inARGBType, vImageYpCbCrType outYpCbCrType,
                                                           vImage_Flags flags) {
    if (!matrix || !pixelRange || !outInfo) return kvImageNullPointerArgument;
    if (inARGBType != kvImageARGB8888) return kvImageUnsupportedConversion;
    if (pixelRange->YpRangeMax <= pixelRange->Yp_bias || pixelRange->CbCrRangeMax <= pixelRange->CbCr_bias) return kvImageInvalidParameter;
    vycc v = { VYCC_MAGIC, (uint32_t)outYpCbCrType, { matrix->R_Yp, matrix->G_Yp, matrix->B_Yp, matrix->R_Cb, matrix->G_Cb, matrix->B_Cb_R_Cr,
                                                       matrix->G_Cr, matrix->B_Cr } };
    range_into(&v, pixelRange);
    memset(outInfo, 0, sizeof *outInfo);
    memcpy(outInfo->opaque, &v, sizeof v);
    return kvImageNoError;
}

/* code values -> ARGB (0...255) */
static void ycc_to_argb(const vycc *v, float Y, float Cb, float Cr, float a, const uint8_t *permute, uint8_t *out) {
    float y = (Y - v->ybias) / v->yscale, cb = (Cb - v->cbias) / v->cscale, cr = (Cr - v->cbias) / v->cscale;
    float rgb[4] = { a, (v->m[0] * y + v->m[1] * cr) * 255, (v->m[0] * y + v->m[3] * cb + v->m[2] * cr) * 255, (v->m[0] * y + v->m[4] * cb) * 255 };
    for (int i = 0; i < 4; i++) vwr(out, i, VT_U8, rgb[permute ? permute[i] & 3 : i]);
}
/* ARGB -> code values (Y', Cb, Cr) */
static void argb_to_ycc(const vycc *v, const float *argb, float *Y, float *Cb, float *Cr) {
    float r = argb[1] / 255, g = argb[2] / 255, b = argb[3] / 255;
    float y = v->m[0] * r + v->m[1] * g + v->m[2] * b, cb = v->m[3] * r + v->m[4] * g + v->m[5] * b, cr = v->m[5] * r + v->m[6] * g + v->m[7] * b;
    *Y = vclampf(y * v->yscale + v->ybias, v->ymin, v->ymax);
    if (Cb) *Cb = vclampf(cb * v->cscale + v->cbias, v->cmin, v->cmax);
    if (Cr) *Cr = vclampf(cr * v->cscale + v->cbias, v->cmin, v->cmax);
}
static const vycc *ycc_info(const void *info) {
    const vycc *v = info;
    return v && v->magic == VYCC_MAGIC ? v : NULL;
}
static void src_argb(const vImage_Buffer *s, long x, long y, const uint8_t *permute, float *argb) {
    float p[4]; vget(s, VF(4, VT_U8), x, y, p);
    for (int i = 0; i < 4; i++) argb[i] = p[permute ? permute[i] & 3 : i];
}

/* 4:2:0: a Y' plane, chroma at half resolution (interleaved CbCr, or separate Cb and Cr planes) */
static vImage_Error from420(const vImage_Buffer *yp, const vImage_Buffer *cb, const vImage_Buffer *cr, const vImage_Buffer *d, const vycc *v,
                            const uint8_t *permute, uint8_t alpha) {
    if (!v) return kvImageInvalidParameter;
    vImage_Error e = vsame(yp, d);
    if (e || (e = vcheck2(cb, d))) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float Y = vrow(yp, (long)y)[x], Cb, Cr;
        if (cr) { Cb = vrow(cb, (long)(y / 2))[x / 2]; Cr = vrow(cr, (long)(y / 2))[x / 2]; }
        else { const uint8_t *c = vrow(cb, (long)(y / 2)) + (x / 2) * 2; Cb = c[0]; Cr = c[1]; }
        ycc_to_argb(v, Y, Cb, Cr, alpha, permute, vrowm(d, (long)y) + x * 4);
    }
    return kvImageNoError;
}
static vImage_Error to420(const vImage_Buffer *s, const vImage_Buffer *yp, const vImage_Buffer *cb, const vImage_Buffer *cr, const vycc *v,
                          const uint8_t *permute) {
    if (!v) return kvImageInvalidParameter;
    vImage_Error e = vsame(s, yp);
    if (e || (e = vcheck2(s, cb))) return e;
    if ((yp->width & 1) || (yp->height & 1)) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < yp->height; y += 2) for (vImagePixelCount x = 0; x < yp->width; x += 2) {
        float sCb = 0, sCr = 0;
        for (int dy = 0; dy < 2; dy++) for (int dx = 0; dx < 2; dx++) {
            float argb[4], Y, Cb, Cr; src_argb(s, (long)(x + dx), (long)(y + dy), permute, argb);
            argb_to_ycc(v, argb, &Y, &Cb, &Cr);
            vrowm(yp, (long)(y + dy))[x + dx] = (uint8_t)lrintf(Y);
            sCb += Cb; sCr += Cr;
        }
        if (cr) { vrowm(cb, (long)(y / 2))[x / 2] = (uint8_t)lrintf(sCb / 4); vrowm(cr, (long)(y / 2))[x / 2] = (uint8_t)lrintf(sCr / 4); }
        else { uint8_t *c = vrowm(cb, (long)(y / 2)) + (x / 2) * 2; c[0] = (uint8_t)lrintf(sCb / 4); c[1] = (uint8_t)lrintf(sCr / 4); }
    }
    return kvImageNoError;
}
vImage_Error vImageConvert_420Yp8_CbCr8ToARGB8888(const vImage_Buffer *srcYp, const vImage_Buffer *srcCbCr, const vImage_Buffer *dest,
                                                  const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags) {
    return info ? from420(srcYp, srcCbCr, NULL, dest, ycc_info(info->opaque), permuteMap, alpha) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(const vImage_Buffer *srcYp, const vImage_Buffer *srcCb, const vImage_Buffer *srcCr,
                                                    const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                    const uint8_t alpha, vImage_Flags flags) {
    if (!srcCr) return kvImageNullPointerArgument;
    return info ? from420(srcYp, srcCb, srcCr, dest, ycc_info(info->opaque), permuteMap, alpha) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To420Yp8_CbCr8(const vImage_Buffer *src, const vImage_Buffer *destYp, const vImage_Buffer *destCbCr,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? to420(src, destYp, destCbCr, NULL, ycc_info(info->opaque), permuteMap) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(const vImage_Buffer *src, const vImage_Buffer *destYp, const vImage_Buffer *destCb,
                                                    const vImage_Buffer *destCr, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                    vImage_Flags flags) {
    if (!destCr) return kvImageNullPointerArgument;
    return info ? to420(src, destYp, destCb, destCr, ycc_info(info->opaque), permuteMap) : kvImageNullPointerArgument;
}

/* 4:2:2 interleaved pairs: positions of Cb, Y0, Cr, Y1 in each 4-byte group */
static vImage_Error from422(const vImage_Buffer *s, const vImage_Buffer *d, const vycc *v, const uint8_t *permute, uint8_t alpha, const int *pos) {
    if (!v) return kvImageInvalidParameter;
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (d->width & 1) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x += 2) {
        const uint8_t *g = vrow(s, (long)y) + x * 2;
        ycc_to_argb(v, g[pos[1]], g[pos[0]], g[pos[2]], alpha, permute, vrowm(d, (long)y) + x * 4);
        ycc_to_argb(v, g[pos[3]], g[pos[0]], g[pos[2]], alpha, permute, vrowm(d, (long)y) + (x + 1) * 4);
    }
    return kvImageNoError;
}
static vImage_Error to422(const vImage_Buffer *s, const vImage_Buffer *d, const vycc *v, const uint8_t *permute, const int *pos) {
    if (!v) return kvImageInvalidParameter;
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->width & 1) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < s->height; y++) for (vImagePixelCount x = 0; x < s->width; x += 2) {
        float a[4], b[4], Y0, Y1, Cb0, Cr0, Cb1, Cr1;
        src_argb(s, (long)x, (long)y, permute, a); src_argb(s, (long)x + 1, (long)y, permute, b);
        argb_to_ycc(v, a, &Y0, &Cb0, &Cr0); argb_to_ycc(v, b, &Y1, &Cb1, &Cr1);
        uint8_t *g = vrowm(d, (long)y) + x * 2;
        g[pos[0]] = (uint8_t)lrintf((Cb0 + Cb1) / 2); g[pos[1]] = (uint8_t)lrintf(Y0);
        g[pos[2]] = (uint8_t)lrintf((Cr0 + Cr1) / 2); g[pos[3]] = (uint8_t)lrintf(Y1);
    }
    return kvImageNoError;
}
static const int uyvy[4] = { 0, 1, 2, 3 }, yuvs[4] = { 1, 0, 3, 2 };
vImage_Error vImageConvert_422CbYpCrYp8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                  const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags) {
    return info ? from422(src, dest, ycc_info(info->opaque), permuteMap, alpha, uyvy) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_422YpCbYpCr8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                  const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags) {
    return info ? from422(src, dest, ycc_info(info->opaque), permuteMap, alpha, yuvs) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To422CbYpCrYp8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,
                                                  const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? to422(src, dest, ycc_info(info->opaque), permuteMap, uyvy) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To422YpCbYpCr8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,
                                                  const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? to422(src, dest, ycc_info(info->opaque), permuteMap, yuvs) : kvImageNullPointerArgument;
}

/* 4:4:4 interleaved: positions of A, Y', Cb, Cr (A < 0: none) and the group size */
static vImage_Error from444(const vImage_Buffer *s, const vImage_Buffer *d, const vycc *v, const uint8_t *permute, int alpha, const int *pos, int n) {
    if (!v) return kvImageInvalidParameter;
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        const uint8_t *g = vrow(s, (long)y) + x * (size_t)n;
        ycc_to_argb(v, g[pos[1]], g[pos[2]], g[pos[3]], pos[0] >= 0 ? g[pos[0]] : (float)alpha, permute, vrowm(d, (long)y) + x * 4);
    }
    return kvImageNoError;
}
static vImage_Error to444(const vImage_Buffer *s, const vImage_Buffer *d, const vycc *v, const uint8_t *permute, const int *pos, int n) {
    if (!v) return kvImageInvalidParameter;
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float a[4], Y, Cb, Cr; src_argb(s, (long)x, (long)y, permute, a);
        argb_to_ycc(v, a, &Y, &Cb, &Cr);
        uint8_t *g = vrowm(d, (long)y) + x * (size_t)n;
        if (pos[0] >= 0) g[pos[0]] = (uint8_t)lrintf(a[0]);
        g[pos[1]] = (uint8_t)lrintf(Y); g[pos[2]] = (uint8_t)lrintf(Cb); g[pos[3]] = (uint8_t)lrintf(Cr);
    }
    return kvImageNoError;
}
static const int p444CrYpCb[4] = { -1, 1, 2, 0 }, p444AYpCbCr[4] = { 0, 1, 2, 3 }, p444CbYpCrA[4] = { 3, 1, 0, 2 };
vImage_Error vImageConvert_444CrYpCb8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags) {
    return info ? from444(src, dest, ycc_info(info->opaque), permuteMap, alpha, p444CrYpCb, 3) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_444AYpCbCr8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                 const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? from444(src, dest, ycc_info(info->opaque), permuteMap, 255, p444AYpCbCr, 4) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_444CbYpCrA8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                 const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? from444(src, dest, ycc_info(info->opaque), permuteMap, 255, p444CbYpCrA, 4) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To444CrYpCb8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,
                                                const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? to444(src, dest, ycc_info(info->opaque), permuteMap, p444CrYpCb, 3) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To444AYpCbCr8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,
                                                 const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? to444(src, dest, ycc_info(info->opaque), permuteMap, p444AYpCbCr, 4) : kvImageNullPointerArgument;
}
vImage_Error vImageConvert_ARGB8888To444CbYpCrA8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,
                                                 const uint8_t permuteMap[4], vImage_Flags flags) {
    return info ? to444(src, dest, ycc_info(info->opaque), permuteMap, p444CbYpCrA, 4) : kvImageNullPointerArgument;
}
