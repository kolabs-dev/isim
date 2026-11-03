// isim vImage (issue #693): the 10-bit packed RGB formats (ARGB2101010, XRGB2101010, RGBA1010102 and the extended-range
// XRGB2101010W of the scale and shears), Planar8 to indexed, multidimensional lookup tables, Richardson-Lucy
// deconvolution, Planar8 to 16U separable convolution, the PNG decompression filters and the colour space
// constructors. Adapted: everything goes through float samples like the rest of isim's vImage.
#include "vimage_t.h"

/* ---- 10-bit packed RGB ----
   One 32-bit word per pixel in host order: ARGB2101010 / XRGB2101010 have A (or X) in bits 30-31, R in 20-29, G in
   10-19, B in 0-9; RGBA1010102 has R in 22-31, G in 12-21, B in 2-11 and A in 0-1. Ten-bit codes map linearly to
   0...1 between RangeMin and RangeMax (16Q12: BlackPoint and WhitePoint are the codes of 0.0 and 1.0, clamped to
   RangeMin...RangeMax). */
typedef struct { int rsh, gsh, bsh, ash; } p10;
static const p10 L2101010 = { 20, 10, 0, 30 }, L1010102 = { 22, 12, 2, 0 };
static inline uint32_t w32(const vImage_Buffer *b, long x, long y) { uint32_t v; memcpy(&v, vrow(b, y) + x * 4, 4); return v; }

/* map: code = black + v * (white - black), clamped to [lo, hi] */
typedef struct { float black, white, lo, hi; } r10;
static vImage_Error unpack10(const vImage_Buffer *s, const vImage_Buffer *d, p10 l, int has_alpha, float alpha, r10 r, vt_t t,
                             const uint8_t *permute) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (r.white == r.black) return kvImageInvalidParameter;
    float one = vt_one(t);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        uint32_t w = w32(s, (long)x, (long)y);
        float argb[4] = { has_alpha ? (float)(w >> l.ash & 3) / 3.f * one : alpha,
                          ((float)(w >> l.rsh & 1023) - r.black) / (r.white - r.black) * one,
                          ((float)(w >> l.gsh & 1023) - r.black) / (r.white - r.black) * one,
                          ((float)(w >> l.bsh & 1023) - r.black) / (r.white - r.black) * one };
        float px[4];
        for (int i = 0; i < 4; i++) px[i] = argb[permute ? permute[i] & 3 : i];
        vput(d, VF(4, t), (long)x, (long)y, px);
    }
    return kvImageNoError;
}
static vImage_Error pack10(const vImage_Buffer *s, const vImage_Buffer *d, p10 l, int keep_alpha, r10 r, vt_t t, const uint8_t *permute) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (r.lo > r.hi) return kvImageInvalidParameter;
    float one = vt_one(t);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], argb[4]; vget(s, VF(4, t), (long)x, (long)y, p);
        for (int i = 0; i < 4; i++) argb[i] = p[permute ? permute[i] & 3 : i] / one;
        uint32_t w = keep_alpha ? (uint32_t)lrintf(vclampf(argb[0], 0, 1) * 3) << l.ash : 3u << l.ash;
        for (int c = 1; c < 4; c++) {
            uint32_t code = (uint32_t)lrintf(vclampf(r.black + argb[c] * (r.white - r.black), r.lo, r.hi));
            w |= code << (c == 1 ? l.rsh : c == 2 ? l.gsh : l.bsh);
        }
        memcpy(vrowm(d, (long)y) + x * 4, &w, 4);
    }
    return kvImageNoError;
}
#define R10(lo, hi) ((r10){ (float)(lo), (float)(hi), (float)(lo), (float)(hi) })
#define R10Q(b, w) ((r10){ (float)(b), (float)(w), 0, 1023 })
#define R10Q4(b, w, lo, hi) ((r10){ (float)(b), (float)(w), (float)(lo), (float)(hi) })

/* to 10-bit */
#define TO10(name, l, keep, t) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, \
                                      const uint8_t permuteMap[4], vImage_Flags flags) { \
        return pack10(src, dest, l, keep, R10(RGB101010RangeMin, RGB101010RangeMax), t, permuteMap); }
TO10(ARGB8888ToARGB2101010, L2101010, 1, VT_U8) TO10(ARGB8888ToXRGB2101010, L2101010, 0, VT_U8) TO10(ARGB8888ToRGBA1010102, L1010102, 1, VT_U8)
TO10(ARGB16UToARGB2101010, L2101010, 1, VT_U16) TO10(ARGB16UToXRGB2101010, L2101010, 0, VT_U16) TO10(ARGB16UToRGBA1010102, L1010102, 1, VT_U16)
TO10(ARGBFFFFToARGB2101010, L2101010, 1, VT_F32) TO10(ARGBFFFFToXRGB2101010, L2101010, 0, VT_F32)
#define TO10Q(name, l, keep) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, \
                                      int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags) { \
        return pack10(src, dest, l, keep, R10Q4(RGB101010BlackPoint, RGB101010WhitePoint, RGB101010RangeMin, RGB101010RangeMax), VT_Q12, permuteMap); }
TO10Q(ARGB16Q12ToARGB2101010, L2101010, 1) TO10Q(ARGB16Q12ToXRGB2101010, L2101010, 0) TO10Q(ARGB16Q12ToRGBA1010102, L1010102, 1)

/* from 10-bit with alpha */
#define FROM10(name, l, t) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, \
                                      const uint8_t permuteMap[4], vImage_Flags flags) { \
        return unpack10(src, dest, l, 1, 0, R10(RGB101010RangeMin, RGB101010RangeMax), t, permuteMap); }
FROM10(ARGB2101010ToARGB8888, L2101010, VT_U8) FROM10(ARGB2101010ToARGB16U, L2101010, VT_U16) FROM10(ARGB2101010ToARGBFFFF, L2101010, VT_F32)
FROM10(ARGB2101010ToARGB16F, L2101010, VT_F16) FROM10(RGBA1010102ToARGB8888, L1010102, VT_U8) FROM10(RGBA1010102ToARGB16U, L1010102, VT_U16)
#define FROM10Q(name, l) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, \
                                      const uint8_t permuteMap[4], vImage_Flags flags) { \
        return unpack10(src, dest, l, 1, 0, R10Q(RGB101010BlackPoint, RGB101010WhitePoint), VT_Q12, permuteMap); }
FROM10Q(ARGB2101010ToARGB16Q12, L2101010) FROM10Q(RGBA1010102ToARGB16Q12, L1010102)

/* from XRGB2101010 with an alpha value */
#define FROMX(name, t, AT) \
    vImage_Error vImageConvert_##name(const vImage_Buffer *src, AT alpha, const vImage_Buffer *dest, int32_t RGB101010RangeMin, \
                                      int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags) { \
        return unpack10(src, dest, L2101010, 0, (float)alpha, R10(RGB101010RangeMin, RGB101010RangeMax), t, permuteMap); }
FROMX(XRGB2101010ToARGB8888, VT_U8, Pixel_8) FROMX(XRGB2101010ToARGB16U, VT_U16, uint16_t) FROMX(XRGB2101010ToARGBFFFF, VT_F32, Pixel_F)
vImage_Error vImageConvert_XRGB2101010ToARGB16F(const vImage_Buffer *src, Pixel_F alpha, const vImage_Buffer *dest, int32_t RGB101010RangeMin,
                                                int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags) {
    return unpack10(src, dest, L2101010, 0, alpha, R10(RGB101010RangeMin, RGB101010RangeMax), VT_F16, permuteMap);
}
vImage_Error vImageConvert_XRGB2101010ToARGB16Q12(const vImage_Buffer *src, Pixel_16Q12 alpha, const vImage_Buffer *dest, int32_t RGB101010BlackPoint,
                                                  int32_t RGB101010WhitePoint, const uint8_t permuteMap[4], vImage_Flags flags) {
    return unpack10(src, dest, L2101010, 0, (float)alpha, R10Q(RGB101010BlackPoint, RGB101010WhitePoint), VT_Q12, permuteMap);
}

/* XRGB2101010W: extended range, code 384 is 0.0 and 894 is 1.0 (so -0.75...1.25); the scale and shears work on the
   values through ARGBFFFF, X stays 3 */
static const r10 RW = { 384, 894, 0, 1023 };
static vImage_Error w_to_f(const vImage_Buffer *s, vImage_Buffer *f) {
    f->width = s->width; f->height = s->height; f->rowBytes = s->width * 16;
    f->data = malloc(f->rowBytes * (s->height ? s->height : 1));
    if (!f->data) return kvImageMemoryAllocationError;
    return unpack10(s, f, L2101010, 0, 1, RW, VT_F32, NULL);
}
static vImage_Error f_to_w(const vImage_Buffer *f, const vImage_Buffer *d) { return pack10(f, d, L2101010, 0, RW, VT_F32, NULL); }
static void bg_w(Pixel_32U bg, float out[4]) {
    out[0] = 1;
    out[1] = ((float)(bg >> 20 & 1023) - 384) / 510; out[2] = ((float)(bg >> 10 & 1023) - 384) / 510; out[3] = ((float)(bg & 1023) - 384) / 510;
}
static vImage_Error tmp_dest(const vImage_Buffer *d, vImage_Buffer *f) {
    f->width = d->width; f->height = d->height; f->rowBytes = d->width * 16;
    f->data = calloc(f->rowBytes, d->height ? d->height : 1);
    return f->data ? kvImageNoError : kvImageMemoryAllocationError;
}
vImage_Error vImageScale_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    vImage_Error e = vcheck2(src, dest);
    if (e) return e;
    vImage_Buffer fs, fd;
    if ((e = w_to_f(src, &fs))) return e;
    if ((e = tmp_dest(dest, &fd))) { free(fs.data); return e; }
    e = vImageScale_ARGBFFFF(&fs, &fd, NULL, flags & ~kvImageNoAllocate);
    if (!e) e = f_to_w(&fd, dest);
    free(fs.data); free(fd.data);
    return e;
}
#define SHEAR_W(name, ffff) \
    vImage_Error vImage##name##_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, \
                                             vImagePixelCount srcOffsetToROI_Y, float xTranslate, float shearSlope, ResamplingFilter filter, \
                                             Pixel_32U backColor, vImage_Flags flags) { \
        vImage_Error e = vcheck2(src, dest); \
        if (e) return e; \
        vImage_Buffer fs, fd; float bg[4]; bg_w(backColor, bg); \
        if ((e = w_to_f(src, &fs))) return e; \
        if ((e = tmp_dest(dest, &fd))) { free(fs.data); return e; } \
        e = ffff(&fs, &fd, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, bg, flags); \
        if (!e) e = f_to_w(&fd, dest); \
        free(fs.data); free(fd.data); \
        return e; }
SHEAR_W(HorizontalShear, vImageHorizontalShear_ARGBFFFF) SHEAR_W(VerticalShear, vImageVerticalShear_ARGBFFFF)

/* ---- Planar8 to indexed: the palette is chosen from the image (1-D k-means over its histogram, started at the
   quantiles); pixels map to the nearest entry, with ordered (4x4 Bayer) or error-diffusion (Floyd-Steinberg,
   Atkinson) dithering when asked; bits are packed most significant first, like Indexed*toPlanar8 reads them ---- */
static void palette_of(const vImage_Buffer *s, int n, Pixel_8 *pal) {
    double hist[256] = { 0 }, total = 0;
    for (vImagePixelCount y = 0; y < s->height; y++) for (vImagePixelCount x = 0; x < s->width; x++) hist[vrow(s, (long)y)[x]]++;
    for (int i = 0; i < 256; i++) total += hist[i];
    double c[16];
    double acc = 0; int k = 0;                                       /* start at the quantiles' midpoints */
    for (int i = 0; i < 256 && k < n; i++) { acc += hist[i]; while (k < n && acc >= total * (k + 0.5) / n) c[k++] = i; }
    while (k < n) { c[k] = k ? c[k - 1] : 0; k++; }
    for (int it = 0; it < 32; it++) {
        double sum[16] = { 0 }, cnt[16] = { 0 };
        for (int v = 0; v < 256; v++) {
            if (!hist[v]) continue;
            int best = 0;
            for (int j = 1; j < n; j++) if (fabs(v - c[j]) < fabs(v - c[best])) best = j;
            sum[best] += hist[v] * v; cnt[best] += hist[v];
        }
        int moved = 0;
        for (int j = 0; j < n; j++) if (cnt[j]) { double m = sum[j] / cnt[j]; if (fabs(m - c[j]) > 1e-3) moved = 1; c[j] = m; }
        if (!moved) break;
    }
    for (int j = 0; j < n; j++) pal[j] = (Pixel_8)lrint(vclampf((float)c[j], 0, 255));
    for (int i = 1; i < n; i++) for (int j = i; j > 0 && pal[j - 1] > pal[j]; j--) { Pixel_8 t = pal[j]; pal[j] = pal[j - 1]; pal[j - 1] = t; }
}
static int nearest(const Pixel_8 *pal, int n, float v) {
    int best = 0;
    for (int j = 1; j < n; j++) if (fabsf(v - pal[j]) < fabsf(v - pal[best])) best = j;
    return best;
}
static vImage_Error to_indexed(const vImage_Buffer *s, const vImage_Buffer *d, Pixel_8 *colors, int dither, int bits, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (!colors) return kvImageNullPointerArgument;
    int n = 1 << bits;
    palette_of(s, n, colors);
    long w = (long)d->width, h = (long)d->height;
    float *err = calloc((size_t)(w + 4) * 3, sizeof(float));        /* error rows for diffusion: this, next, the one after */
    if (!err) return kvImageMemoryAllocationError;
    int mode = dither & 0xff;
    static const float bayer[4][4] = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } };
    float step = n > 1 ? 255.f / (n - 1) : 255.f;
    for (long y = 0; y < h; y++) {
        float *e0 = err + ((y % 3)) * (w + 4) + 2, *e1 = err + ((y + 1) % 3) * (w + 4) + 2, *e2 = err + ((y + 2) % 3) * (w + 4) + 2;
        memset(e2 - 2, 0, sizeof(float) * (size_t)(w + 4));
        uint8_t *out = vrowm(d, y);
        memset(out, 0, ((size_t)w * (size_t)bits + 7) / 8);
        for (long x = 0; x < w; x++) {
            float v = vrow(s, y)[x];
            if (mode == kvImageConvert_DitherOrdered || mode == kvImageConvert_DitherOrderedReproducible)
                v += (bayer[y & 3][x & 3] / 16.f - 0.5f) * step;
            else if (mode == kvImageConvert_DitherFloydSteinberg || mode == kvImageConvert_DitherAtkinson) v += e0[x];
            int idx = nearest(colors, n, v);
            float q = v - colors[idx];
            if (mode == kvImageConvert_DitherFloydSteinberg) {
                e0[x + 1] += q * 7 / 16; e1[x - 1] += q * 3 / 16; e1[x] += q * 5 / 16; e1[x + 1] += q / 16;
            } else if (mode == kvImageConvert_DitherAtkinson) {
                e0[x + 1] += q / 8; e0[x + 2] += q / 8; e1[x - 1] += q / 8; e1[x] += q / 8; e1[x + 1] += q / 8; e2[x] += q / 8;
            }
            size_t bit = (size_t)x * (size_t)bits;
            out[bit / 8] |= (uint8_t)(idx << (8 - bits - (int)(bit % 8)));
        }
        memset(e0 - 2, 0, sizeof(float) * (size_t)(w + 4));
    }
    free(err);
    return kvImageNoError;
}
vImage_Error vImageConvert_Planar8toIndexed1(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, Pixel_8 colors[2], int dither, vImage_Flags flags) {
    return to_indexed(src, dest, colors, dither, 1, flags);
}
vImage_Error vImageConvert_Planar8toIndexed2(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, Pixel_8 colors[4], int dither, vImage_Flags flags) {
    return to_indexed(src, dest, colors, dither, 2, flags);
}
vImage_Error vImageConvert_Planar8toIndexed4(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, Pixel_8 colors[16], int dither, vImage_Flags flags) {
    return to_indexed(src, dest, colors, dither, 4, flags);
}

/* ---- multidimensional lookup tables: numSrcChannels dimensions (the first varies slowest) of entries_per_dimension[i]
   grid points each, numDestChannels uint16_t values per point, read as 16Q12 (4096 is 1.0); interpolated
   multilinearly (half interpolation is treated as full: adapted) or taken at the nearest grid point ---- */
struct vImage_MultidimensionalTableData {
    int refs;
    uint32_t nsrc, ndst;
    uint32_t dims[8];
    float *values;
};
vImage_MultidimensionalTable vImageMultidimensionalTable_Create(const uint16_t *tableData, uint32_t numSrcChannels, uint32_t numDestChannels,
                                                                const uint8_t table_entries_per_dimension[], vImageMDTableUsageHint hint,
                                                                vImage_Flags flags, vImage_Error *err) {
    vImage_Error dummy; if (!err) err = &dummy;
    if (!tableData || !table_entries_per_dimension) { *err = kvImageNullPointerArgument; return NULL; }
    if (numSrcChannels < 1 || numSrcChannels > 8 || numDestChannels < 1 || numDestChannels > 16) { *err = kvImageInvalidParameter; return NULL; }
    size_t points = 1;
    for (uint32_t i = 0; i < numSrcChannels; i++) {
        if (table_entries_per_dimension[i] < 2) { *err = kvImageInvalidParameter; return NULL; }
        points *= table_entries_per_dimension[i];
    }
    struct vImage_MultidimensionalTableData *t = calloc(1, sizeof *t);
    if (t) t->values = malloc(sizeof(float) * points * numDestChannels);
    if (!t || !t->values) { if (t) free(t); *err = kvImageMemoryAllocationError; return NULL; }
    t->refs = 1; t->nsrc = numSrcChannels; t->ndst = numDestChannels;
    for (uint32_t i = 0; i < numSrcChannels; i++) t->dims[i] = table_entries_per_dimension[i];
    for (size_t i = 0; i < points * numDestChannels; i++) t->values[i] = tableData[i] / 4096.f;
    *err = kvImageNoError;
    return t;
}
vImage_Error vImageMultidimensionalTable_Retain(vImage_MultidimensionalTable table) {
    if (!table) return kvImageNullPointerArgument;
    __atomic_add_fetch(&table->refs, 1, __ATOMIC_RELAXED);
    return kvImageNoError;
}
vImage_Error vImageMultidimensionalTable_Release(vImage_MultidimensionalTable table) {
    if (!table) return kvImageNullPointerArgument;
    if (__atomic_sub_fetch(&table->refs, 1, __ATOMIC_ACQ_REL) == 0) { free(table->values); free(table); }
    return kvImageNoError;
}
static void md_lookup(const struct vImage_MultidimensionalTableData *t, const float *in, float *out, vImage_InterpolationMethod method) {
    long base[8]; float frac[8]; size_t stride[8];
    size_t s = t->ndst;
    for (int i = (int)t->nsrc - 1; i >= 0; i--) { stride[i] = s; s *= t->dims[i]; }
    for (uint32_t i = 0; i < t->nsrc; i++) {
        float p = vclampf(in[i], 0, 1) * (float)(t->dims[i] - 1);
        if (method == kvImageNoInterpolation) { base[i] = lrintf(p); frac[i] = 0; continue; }
        base[i] = (long)floorf(p);
        if (base[i] >= (long)t->dims[i] - 1) base[i] = (long)t->dims[i] - 2;
        frac[i] = p - (float)base[i];
    }
    for (uint32_t c = 0; c < t->ndst; c++) out[c] = 0;
    int corners = method == kvImageNoInterpolation ? 1 : 1 << t->nsrc;
    for (int k = 0; k < corners; k++) {
        float wgt = 1; size_t off = 0;
        for (uint32_t i = 0; i < t->nsrc; i++) {
            int hi = method != kvImageNoInterpolation && (k >> i & 1);
            wgt *= hi ? frac[i] : 1 - frac[i];
            off += (size_t)(base[i] + hi) * stride[i];
        }
        if (wgt == 0) continue;
        for (uint32_t c = 0; c < t->ndst; c++) out[c] += wgt * t->values[off + c];
    }
}
static vImage_Error md_apply(const vImage_Buffer srcs[], const vImage_Buffer dests[], vImage_MultidimensionalTable t,
                             vImage_InterpolationMethod method, vImage_Flags flags, vt_t vt) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!srcs || !dests || !t) return kvImageNullPointerArgument;
    for (uint32_t i = 0; i < t->nsrc; i++) { vImage_Error e = vsame(&srcs[i], &dests[0]); if (e) return e; }
    for (uint32_t c = 0; c < t->ndst; c++) { vImage_Error e = vcheck2(&dests[c], &dests[c]); if (e) return e; }
    float one = vt == VT_Q12 ? 4096.f : 1.f;
    for (vImagePixelCount y = 0; y < dests[0].height; y++) for (vImagePixelCount x = 0; x < dests[0].width; x++) {
        float in[8], out[16];
        for (uint32_t i = 0; i < t->nsrc; i++) in[i] = vrd(vrow(&srcs[i], (long)y), (long)x, vt) / one;
        md_lookup(t, in, out, method);
        for (uint32_t c = 0; c < t->ndst; c++) vwr(vrowm(&dests[c], (long)y), (long)x, vt, out[c] * one);
    }
    return kvImageNoError;
}
vImage_Error vImageMultiDimensionalInterpolatedLookupTable_PlanarF(const vImage_Buffer srcs[], const vImage_Buffer dests[], void *tempBuffer,
                                                                   vImage_MultidimensionalTable table, vImage_InterpolationMethod method,
                                                                   vImage_Flags flags) {
    return md_apply(srcs, dests, table, method, flags, VT_F32);
}
vImage_Error vImageMultiDimensionalInterpolatedLookupTable_Planar16Q12(const vImage_Buffer srcs[], const vImage_Buffer dests[], void *tempBuffer,
                                                                       vImage_MultidimensionalTable table, vImage_InterpolationMethod method,
                                                                       vImage_Flags flags) {
    return md_apply(srcs, dests, table, method, flags, VT_Q12);
}

/* ---- Richardson-Lucy deconvolution: estimate <- estimate * (kernel2 (x) (source / (kernel (x) estimate))), starting from
   the source; kernel2 defaults to the kernel; the kernels are correlated with edge extension (or the background colour
   with kvImageBackgroundColorFill) ---- */
static void correlate(const float *img, long w, long h, const float *k, long kh, long kw, int fill, float bg, float *out) {
    for (long y = 0; y < h; y++) for (long x = 0; x < w; x++) {
        float acc = 0;
        for (long j = 0; j < kh; j++) for (long i = 0; i < kw; i++) {
            long sy = y + j - kh / 2, sx = x + i - kw / 2;
            float v;
            if (sx < 0 || sy < 0 || sx >= w || sy >= h) {
                if (fill) v = bg; else v = img[(sy < 0 ? 0 : sy >= h ? h - 1 : sy) * w + (sx < 0 ? 0 : sx >= w ? w - 1 : sx)];
            } else v = img[sy * w + sx];
            acc += k[j * kw + i] * v;
        }
        out[y * w + x] = acc;
    }
}
static vImage_Error rl(const vImage_Buffer *s, const vImage_Buffer *d, vImagePixelCount ox, vImagePixelCount oy, vt_t vt, int ch,
                       const float *k1, const float *k2, uint32_t kh, uint32_t kw, uint32_t kh2, uint32_t kw2, const float *bg,
                       uint32_t iterations, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (!k1) return kvImageNullPointerArgument;
    if (!(kh & 1) || !(kw & 1) || (k2 && (!(kh2 & 1) || !(kw2 & 1)))) return kvImageInvalidKernelSize;
    if (ox + d->width > s->width || oy + d->height > s->height) return kvImageRoiLargerThanInputBuffer;
    if (!k2) { k2 = k1; kh2 = kh; kw2 = kw; }
    long w = (long)s->width, h = (long)s->height, n = w * h;
    float *src = malloc(sizeof(float) * (size_t)n * 4), *est = src + n, *tmp = src + 2 * n, *tmp2 = src + 3 * n;
    if (!src) return kvImageMemoryAllocationError;
    int fill = (flags & kvImageBackgroundColorFill) != 0;
    for (int c = 0; c < ch; c++) {
        if (ch == 4 && c == 0 && (flags & kvImageLeaveAlphaUnchanged)) {
            for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++)
                vwr(vrowm(d, (long)y), (long)x * 4, vt, vrd(vrow(s, (long)(y + oy)), (long)(x + ox) * 4, vt));
            continue;
        }
        for (long y = 0; y < h; y++) for (long x = 0; x < w; x++) src[y * w + x] = est[y * w + x] = vrd(vrow(s, y), x * ch + c, vt);
        for (uint32_t it = 0; it < iterations; it++) {
            correlate(est, w, h, k1, kh, kw, fill, bg[c], tmp);
            for (long i = 0; i < n; i++) tmp[i] = tmp[i] > 1e-6f ? src[i] / tmp[i] : 0;
            correlate(tmp, w, h, k2, kh2, kw2, fill, 1, tmp2);
            for (long i = 0; i < n; i++) est[i] *= tmp2[i];
        }
        for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++)
            vwr(vrowm(d, (long)y), (long)x * ch + c, vt, est[(long)(y + oy) * w + (long)(x + ox)]);
    }
    free(src);
    return kvImageNoError;
}
static float *kernel16(const int16_t *k, uint32_t kh, uint32_t kw, int32_t divisor) {
    if (!k) return NULL;
    float *f = malloc(sizeof(float) * kh * kw);
    if (f) for (uint32_t i = 0; i < kh * kw; i++) f[i] = (float)k[i] / (float)(divisor ? divisor : 1);
    return f;
}
vImage_Error vImageRichardsonLucyDeConvolve_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                                    vImagePixelCount srcOffsetToROI_Y, const float *kernel, const float *kernel2, uint32_t kernel_height,
                                                    uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, Pixel_F backgroundColor,
                                                    uint32_t iterationCount, vImage_Flags flags) {
    float bg[4] = { backgroundColor, backgroundColor, backgroundColor, backgroundColor };
    return rl(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, VT_F32, 1, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2,
              bg, iterationCount, flags);
}
vImage_Error vImageRichardsonLucyDeConvolve_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                                     vImagePixelCount srcOffsetToROI_Y, const float *kernel, const float *kernel2, uint32_t kernel_height,
                                                     uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, const Pixel_FFFF backgroundColor,
                                                     uint32_t iterationCount, vImage_Flags flags) {
    float bg[4] = { 0 };
    if (backgroundColor) for (int i = 0; i < 4; i++) bg[i] = backgroundColor[i];
    return rl(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, VT_F32, 4, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2,
              bg, iterationCount, flags);
}
#define RL16(name, ch, BGT) \
    vImage_Error vImageRichardsonLucyDeConvolve_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, \
            vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, const int16_t *kernel2, uint32_t kernel_height, \
            uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, int32_t divisor, int32_t divisor2, BGT backgroundColor, \
            uint32_t iterationCount, vImage_Flags flags) { \
        if (flags & kvImageGetTempBufferSize) return 0; \
        float bg[4] = { 0 }; RL_BG_##name \
        float *k1 = kernel16(kernel, kernel_height, kernel_width, divisor), *k2 = kernel16(kernel2, kernel_height2, kernel_width2, divisor2); \
        if (kernel && !k1) { free(k2); return kvImageMemoryAllocationError; } \
        vImage_Error e = rl(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, VT_U8, ch, k1, k2, kernel_height, kernel_width, kernel_height2, kernel_width2, \
                            bg, iterationCount, flags); \
        free(k1); free(k2); \
        return e; }
#define RL_BG_Planar8 bg[0] = backgroundColor;
#define RL_BG_ARGB8888 if (backgroundColor) for (int i = 0; i < 4; i++) bg[i] = backgroundColor[i];
RL16(Planar8, 1, Pixel_8) RL16(ARGB8888, 4, const Pixel_8888)

/* ---- Planar8 -> Planar16U separable convolution: the sum of products (on 0...255 samples), times scale, plus bias ---- */
vImage_Error vImageSepConvolve_Planar8to16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                            vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY,
                                            uint32_t kernelY_width, float scale, float bias, Pixel_8 backgroundColor, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    vImage_Error e = vcheck2(src, dest);
    if (e) return e;
    vImage_Buffer fs = { malloc(src->width * src->height * 4 + 4), src->height, src->width, src->width * 4 };
    vImage_Buffer fd = { malloc(dest->width * dest->height * 4 + 4), dest->height, dest->width, dest->width * 4 };
    if (!fs.data || !fd.data) { free(fs.data); free(fd.data); return kvImageMemoryAllocationError; }
    for (vImagePixelCount y = 0; y < src->height; y++) for (vImagePixelCount x = 0; x < src->width; x++)
        ((float *)vrowm(&fs, (long)y))[x] = vrow(src, (long)y)[x];
    e = vImageSepConvolve_PlanarF(&fs, &fd, NULL, srcOffsetToROI_X, srcOffsetToROI_Y, kernelX, kernelX_width, kernelY, kernelY_width, 0,
                                  backgroundColor, flags);
    if (!e) for (vImagePixelCount y = 0; y < dest->height; y++) for (vImagePixelCount x = 0; x < dest->width; x++)
        vwr(vrowm(dest, (long)y), (long)x, VT_U16, ((float *)vrow(&fd, (long)y))[x] * scale + bias);
    free(fs.data); free(fd.data);
    return e;
}

/* ---- PNG decompression filters (filter method 0), undone in place on scanlineCount rows from startScanline; the row
   before startScanline is the prior row (none for row 0) ---- */
static inline int paeth(int a, int b, int c) {
    int p = a + b - c, pa = abs(p - a), pb = abs(p - b), pc = abs(p - c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}
vImage_Error vImagePNGDecompressionFilter(const vImage_Buffer *buffer, vImagePixelCount startScanline, vImagePixelCount scanlineCount,
                                          uint32_t bitsPerPixel, uint32_t filterMethodNumber, uint32_t filterType, vImage_Flags flags) {
    if (!buffer || !buffer->data) return kvImageNullPointerArgument;
    if (filterMethodNumber != 0 || filterType > kvImage_PNG_FILTER_VALUE_PAETH || bitsPerPixel == 0) return kvImageInvalidParameter;
    if (startScanline + scanlineCount > buffer->height) return kvImageRoiLargerThanInputBuffer;
    size_t bpp = (bitsPerPixel + 7) / 8, n = (buffer->width * bitsPerPixel + 7) / 8;
    for (vImagePixelCount y = startScanline; y < startScanline + scanlineCount; y++) {
        uint8_t *r = vrowm(buffer, (long)y);
        const uint8_t *p = y > 0 ? vrow(buffer, (long)y - 1) : NULL;
        for (size_t i = 0; i < n; i++) {
            int a = i >= bpp ? r[i - bpp] : 0, b = p ? p[i] : 0, c = p && i >= bpp ? p[i - bpp] : 0, add = 0;
            switch (filterType) {
            case kvImage_PNG_FILTER_VALUE_SUB: add = a; break;
            case kvImage_PNG_FILTER_VALUE_UP: add = b; break;
            case kvImage_PNG_FILTER_VALUE_AVG: add = (a + b) / 2; break;
            case kvImage_PNG_FILTER_VALUE_PAETH: add = paeth(a, b, c); break;
            default: break;
            }
            r[i] = (uint8_t)(r[i] + add);
        }
    }
    return kvImageNoError;
}

/* ---- colour spaces from primaries / a white point and a transfer function: an ICC v4 display profile (colorants
   Bradford-adapted to D50, parametric curves of function type 4) handed to CGColorSpaceCreateWithICCData ---- */
static void put32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }
static void puts15(uint8_t *p, double v) { put32(p, (uint32_t)(int32_t)lrint(v * 65536)); }
typedef struct { uint8_t *p; size_t n, tags, tagdata; } icc_w;
static void icc_tag(icc_w *w, const char *sig, const uint8_t *data, size_t len) {
    uint8_t *t = w->p + 132 + w->tags * 12;
    memcpy(t, sig, 4); put32(t + 4, (uint32_t)w->tagdata); put32(t + 8, (uint32_t)len);
    memcpy(w->p + w->tagdata, data, len);
    w->tagdata += (len + 3) & ~(size_t)3; w->tags++;
}
static size_t xyz_tag(uint8_t *b, const double *xyz) { memcpy(b, "XYZ ", 4); memset(b + 4, 0, 4); for (int i = 0; i < 3; i++) puts15(b + 8 + 4 * i, xyz[i]); return 20; }
static int para_tag(uint8_t *b, const vImageTransferFunction *f) {
    double g = f->gamma;
    if (!(g > 0)) return 0;
    double k = f->c0 > 0 ? pow(f->c0, 1 / g) : 0;
    double v[7] = { g, k * f->c1, k * f->c2, f->c4, f->cutoff, f->c3, f->c5 };   /* g a b c d e f */
    memcpy(b, "para", 4); memset(b + 4, 0, 4); b[8] = 0; b[9] = 3; b[10] = b[11] = 0;
    for (int i = 0; i < 7; i++) puts15(b + 12 + 4 * i, v[i]);
    return 40;
}
static const double D50[3] = { 0.9642, 1.0, 0.8249 };
static void xy_to_xyz(double x, double y, double *o) { o[0] = x / y; o[1] = 1; o[2] = (1 - x - y) / y; }
static void inv3(const double *m, double *o) {
    double d = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6]);
    o[0] = (m[4] * m[8] - m[5] * m[7]) / d; o[1] = (m[2] * m[7] - m[1] * m[8]) / d; o[2] = (m[1] * m[5] - m[2] * m[4]) / d;
    o[3] = (m[5] * m[6] - m[3] * m[8]) / d; o[4] = (m[0] * m[8] - m[2] * m[6]) / d; o[5] = (m[2] * m[3] - m[0] * m[5]) / d;
    o[6] = (m[3] * m[7] - m[4] * m[6]) / d; o[7] = (m[1] * m[6] - m[0] * m[7]) / d; o[8] = (m[0] * m[4] - m[1] * m[3]) / d;
}
static void mul33(const double *a, const double *b, double *o) {
    for (int r = 0; r < 3; r++) for (int c = 0; c < 3; c++) o[3 * r + c] = a[3 * r] * b[c] + a[3 * r + 1] * b[3 + c] + a[3 * r + 2] * b[6 + c];
}
/* the Bradford adaptation from white w (XYZ) to D50 */
static void bradford(const double *w, double *out) {
    static const double B[9] = { 0.8951, 0.2664, -0.1614, -0.7502, 1.7135, 0.0367, 0.0389, -0.0685, 1.0296 };
    double Bi[9], s[3], d[3], D[9] = { 0 }, t[9];
    inv3(B, Bi);
    for (int r = 0; r < 3; r++) { s[r] = B[3 * r] * w[0] + B[3 * r + 1] * w[1] + B[3 * r + 2] * w[2]; d[r] = B[3 * r] * D50[0] + B[3 * r + 1] * D50[1] + B[3 * r + 2] * D50[2]; }
    for (int i = 0; i < 3; i++) D[4 * i] = d[i] / s[i];
    mul33(D, B, t); mul33(Bi, t, out);
}
static CGColorSpaceRef icc_space(int gray, const double cols[3][3], const vImageTransferFunction *tf, CGColorRenderingIntent intent, vImage_Error *err) {
    uint8_t buf[1024] = { 0 }, tag[64];
    icc_w w = { buf, sizeof buf, 0, 0 };
    int ntags = gray ? 2 : 6;
    w.tagdata = 132 + (size_t)ntags * 12;
    put32(buf + 8, 0x04300000); memcpy(buf + 12, "mntr", 4); memcpy(buf + 16, gray ? "GRAY" : "RGB ", 4); memcpy(buf + 20, "XYZ ", 4);
    memcpy(buf + 36, "acsp", 4); put32(buf + 64, (uint32_t)intent);
    puts15(buf + 68, D50[0]); puts15(buf + 72, D50[1]); puts15(buf + 76, D50[2]);
    put32(buf + 128, (uint32_t)ntags);
    icc_tag(&w, "wtpt", tag, xyz_tag(tag, D50));
    int pl = para_tag(tag, tf);
    if (!pl) { *err = kvImageInvalidParameter; return NULL; }
    if (gray) icc_tag(&w, "kTRC", tag, (size_t)pl);
    else {
        static const char *xs[3] = { "rXYZ", "gXYZ", "bXYZ" }, *ts[3] = { "rTRC", "gTRC", "bTRC" };
        uint8_t xt[20];
        for (int i = 0; i < 3; i++) icc_tag(&w, xs[i], xt, xyz_tag(xt, cols[i]));
        for (int i = 0; i < 3; i++) icc_tag(&w, ts[i], tag, (size_t)pl);
    }
    put32(buf, (uint32_t)w.tagdata);
    CFDataRef data = CFDataCreate(NULL, buf, (CFIndex)w.tagdata);
    CGColorSpaceRef s = data ? CGColorSpaceCreateWithICCData(data) : NULL;
    if (data) CFRelease(data);
    *err = s ? kvImageNoError : kvImageInternalError;
    return s;
}
CGColorSpaceRef vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(const vImageRGBPrimaries *primaries, const vImageTransferFunction *tf,
                                                                          CGColorRenderingIntent intent, vImage_Flags flags, vImage_Error *error) {
    vImage_Error dummy; if (!error) error = &dummy;
    if (!primaries || !tf) { *error = kvImageNullPointerArgument; return NULL; }
    if (primaries->red_y <= 0 || primaries->green_y <= 0 || primaries->blue_y <= 0 || primaries->white_y <= 0) { *error = kvImageInvalidParameter; return NULL; }
    double r[3], g[3], b[3], wt[3], P[9], Pi[9], S[3], M[9], A[9], MA[9];
    xy_to_xyz(primaries->red_x, primaries->red_y, r); xy_to_xyz(primaries->green_x, primaries->green_y, g);
    xy_to_xyz(primaries->blue_x, primaries->blue_y, b); xy_to_xyz(primaries->white_x, primaries->white_y, wt);
    for (int i = 0; i < 3; i++) { P[3 * i] = r[i]; P[3 * i + 1] = g[i]; P[3 * i + 2] = b[i]; }
    inv3(P, Pi);
    for (int i = 0; i < 3; i++) S[i] = Pi[3 * i] * wt[0] + Pi[3 * i + 1] * wt[1] + Pi[3 * i + 2] * wt[2];
    for (int i = 0; i < 3; i++) for (int k = 0; k < 3; k++) M[3 * i + k] = P[3 * i + k] * S[k];
    bradford(wt, A); mul33(A, M, MA);
    double cols[3][3];
    for (int k = 0; k < 3; k++) for (int i = 0; i < 3; i++) cols[k][i] = MA[3 * i + k];
    return icc_space(0, cols, tf, intent, error);
}
CGColorSpaceRef vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction(const vImageWhitePoint *whitePoint, const vImageTransferFunction *tf,
                                                                                  CGColorRenderingIntent intent, vImage_Flags flags, vImage_Error *error) {
    vImage_Error dummy; if (!error) error = &dummy;
    if (!whitePoint || !tf) { *error = kvImageNullPointerArgument; return NULL; }
    if (whitePoint->white_y <= 0) { *error = kvImageInvalidParameter; return NULL; }
    return icc_space(1, NULL, tf, intent, error);
}
