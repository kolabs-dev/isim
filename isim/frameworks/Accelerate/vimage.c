/* isim vImage: buffers, Core Graphics interoperation (vImage_CGImageFormat, images in and out, vImageConverter and
   vImageConvert_AnyToAny), copying and filling, and the channel operations. Adapted: pixels move between Core Graphics
   layouts through normalized float RGBA (no colour management: colour spaces only decide gray versus RGB); isim's
   Core Graphics images hold 8 bits per component, so deeper formats are converted when they become CGImages. */
#include "vimage_t.h"
#include <stdio.h>

void *isim_cg_obj_new(const char *kind, size_t size, void (*fin)(void *));   /* CoreGraphics (resolved at load time) */

/* ---- buffers ---- */

vImage_Error vImageBuffer_Init(vImage_Buffer *buf, vImagePixelCount height, vImagePixelCount width, uint32_t pixelBits, vImage_Flags flags) {
    if (!buf) return kvImageNullPointerArgument;
    if (!pixelBits || !width || !height) return kvImageInvalidParameter;
    size_t row = (width * pixelBits + 7) / 8;
    row = (row + 63) & ~(size_t)63;   /* Apple aligns rows for its vector units; 64 bytes here */
    buf->width = width; buf->height = height; buf->rowBytes = row;
    if (flags & kvImageNoAllocate) { buf->data = NULL; return 64; }   /* the preferred alignment */
    void *p = NULL;
    if (posix_memalign(&p, 64, row * height)) return kvImageMemoryAllocationError;
    buf->data = p;
    return kvImageNoError;
}

vImage_CGSize vImageBuffer_GetSize(const vImage_Buffer *buf) {
    return buf ? CGSizeMake((CGFloat)buf->width, (CGFloat)buf->height) : CGSizeMake(0, 0);
}

vImage_Error vImageCopyBuffer(const vImage_Buffer *src, const vImage_Buffer *dest, size_t pixelSize, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!pixelSize) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < dest->height; y++) memmove(vrowm(dest, (long)y), vrow(src, (long)y), dest->width * pixelSize);
    return kvImageNoError;
}

/* ---- fills ---- */

static vImage_Error fill(const vImage_Buffer *d, vfmt f, const float *px) {
    VCHECK_BUF(d);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) vput(d, f, (long)x, (long)y, px);
    return kvImageNoError;
}
#define FILL_MULTI(name, ch, t, T) \
    vImage_Error vImageBufferFill_##name(const vImage_Buffer *dest, const T *color, vImage_Flags flags) { \
        float px[4]; VBG_MULTI_PX(px, VF(ch, t), color); return fill(dest, VF(ch, t), px); }
FILL_MULTI(ARGB8888, 4, VT_U8, uint8_t) FILL_MULTI(ARGBFFFF, 4, VT_F32, float) FILL_MULTI(ARGB16U, 4, VT_U16, uint16_t)
FILL_MULTI(ARGB16S, 4, VT_S16, int16_t) FILL_MULTI(ARGB16F, 4, VT_F16, uint16_t) FILL_MULTI(CbCr8, 2, VT_U8, uint8_t)
FILL_MULTI(CbCr16U, 2, VT_U16, uint16_t) FILL_MULTI(CbCr16S, 2, VT_S16, int16_t)

#define SCALAR_PLANAR(name, t, T) \
    vImage_Error vImageOverwriteChannelsWithScalar_##name(T scalar, const vImage_Buffer *dest, vImage_Flags flags) { \
        float px[4]; VBG_PLANAR_PX(px, t, scalar); return fill(dest, VF(1, t), px); }
SCALAR_PLANAR(Planar8, VT_U8, Pixel_8) SCALAR_PLANAR(PlanarF, VT_F32, Pixel_F) SCALAR_PLANAR(Planar16U, VT_U16, Pixel_16U)
SCALAR_PLANAR(Planar16S, VT_S16, Pixel_16S) SCALAR_PLANAR(Planar16F, VT_F16, Pixel_16F)

/* ---- channels (ARGB: channel 0 is the first in memory, mask bit 0x8 is channel 0 ... 0x1 is channel 3) ---- */

static vImage_Error overwrite_scalar(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, float v, uint8_t mask) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4]; vget(s, f, (long)x, (long)y, p);
        for (int c = 0; c < 4; c++) if (mask & (8 >> c)) p[c] = v;
        vput(d, f, (long)x, (long)y, p);
    }
    return kvImageNoError;
}
vImage_Error vImageOverwriteChannelsWithScalar_ARGB8888(Pixel_8 scalar, const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t copyMask,
                                                        vImage_Flags flags) {
    return overwrite_scalar(src, dest, VF(4, VT_U8), scalar, copyMask);
}
vImage_Error vImageOverwriteChannelsWithScalar_ARGBFFFF(Pixel_F scalar, const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t copyMask,
                                                        vImage_Flags flags) {
    return overwrite_scalar(src, dest, VF(4, VT_F32), scalar, copyMask);
}

static vImage_Error overwrite_pixel(const float *pix, const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, uint8_t mask) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4]; vget(s, f, (long)x, (long)y, p);
        for (int c = 0; c < 4; c++) if (mask & (8 >> c)) p[c] = pix[c];
        vput(d, f, (long)x, (long)y, p);
    }
    return kvImageNoError;
}
#define OVERWRITE_PIXEL(name, t, T) \
    vImage_Error vImageOverwriteChannelsWithPixel_##name(const T *the_pixel, const vImage_Buffer *src, const vImage_Buffer *dest, \
                                                        uint8_t copyMask, vImage_Flags flags) { \
        float px[4]; VBG_MULTI_PX(px, VF(4, t), the_pixel); return overwrite_pixel(px, src, dest, VF(4, t), copyMask); }
OVERWRITE_PIXEL(ARGB8888, VT_U8, uint8_t) OVERWRITE_PIXEL(ARGBFFFF, VT_F32, float) OVERWRITE_PIXEL(ARGB16U, VT_U16, uint16_t)

static vImage_Error overwrite_channels(const vImage_Buffer *n, const vImage_Buffer *o, const vImage_Buffer *d, vt_t t, uint8_t mask) {
    vImage_Error e = vsame(o, d);
    if (e || (e = vsame(n, d))) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], v; vget(o, VF(4, t), (long)x, (long)y, p); vget(n, VF(1, t), (long)x, (long)y, &v);
        for (int c = 0; c < 4; c++) if (mask & (8 >> c)) p[c] = v;
        vput(d, VF(4, t), (long)x, (long)y, p);
    }
    return kvImageNoError;
}
vImage_Error vImageOverwriteChannels_ARGB8888(const vImage_Buffer *newSrc, const vImage_Buffer *origSrc, const vImage_Buffer *dest,
                                              uint8_t copyMask, vImage_Flags flags) {
    return overwrite_channels(newSrc, origSrc, dest, VT_U8, copyMask);
}
vImage_Error vImageOverwriteChannels_ARGBFFFF(const vImage_Buffer *newSrc, const vImage_Buffer *origSrc, const vImage_Buffer *dest,
                                              uint8_t copyMask, vImage_Flags flags) {
    return overwrite_channels(newSrc, origSrc, dest, VT_F32, copyMask);
}

static vImage_Error select_channels(const vImage_Buffer *n, const vImage_Buffer *o, const vImage_Buffer *d, vt_t t, uint8_t mask) {
    vImage_Error e = vsame(o, d);
    if (e || (e = vsame(n, d))) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], q[4]; vget(o, VF(4, t), (long)x, (long)y, p); vget(n, VF(4, t), (long)x, (long)y, q);
        for (int c = 0; c < 4; c++) if (mask & (8 >> c)) p[c] = q[c];
        vput(d, VF(4, t), (long)x, (long)y, p);
    }
    return kvImageNoError;
}
vImage_Error vImageSelectChannels_ARGB8888(const vImage_Buffer *newSrc, const vImage_Buffer *origSrc, const vImage_Buffer *dest,
                                           uint8_t copyMask, vImage_Flags flags) {
    return select_channels(newSrc, origSrc, dest, VT_U8, copyMask);
}
vImage_Error vImageSelectChannels_ARGBFFFF(const vImage_Buffer *newSrc, const vImage_Buffer *origSrc, const vImage_Buffer *dest,
                                           uint8_t copyMask, vImage_Flags flags) {
    return select_channels(newSrc, origSrc, dest, VT_F32, copyMask);
}

static vImage_Error extract(const vImage_Buffer *s, const vImage_Buffer *d, vt_t t, long ch) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (ch < 0 || ch > 3) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++)
        vwr(vrowm(d, (long)y), (long)x, t, vrd(vrow(s, (long)y), (long)(x * 4) + ch, t));
    return kvImageNoError;
}
vImage_Error vImageExtractChannel_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex, vImage_Flags flags) { return extract(src, dest, VT_U8, channelIndex); }
vImage_Error vImageExtractChannel_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex, vImage_Flags flags) { return extract(src, dest, VT_F32, channelIndex); }
vImage_Error vImageExtractChannel_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex, vImage_Flags flags) { return extract(src, dest, VT_U16, channelIndex); }

static vImage_Error permute(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, const uint8_t *map, uint8_t mask, const float *bg) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    if (!map) return kvImageNullPointerArgument;
    for (int c = 0; c < f.ch; c++) if (map[c] >= f.ch) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], q[4]; vget(s, f, (long)x, (long)y, p);
        for (int c = 0; c < f.ch; c++) q[c] = bg && (mask & (8 >> c)) ? bg[c] : p[map[c]];
        vput(d, f, (long)x, (long)y, q);
    }
    return kvImageNoError;
}
#define PERMUTE(name, t) \
    vImage_Error vImagePermuteChannels_##name(const vImage_Buffer *src, const vImage_Buffer *dest, const uint8_t *permuteMap, vImage_Flags flags) { \
        return permute(src, dest, VF(4, t), permuteMap, 0, NULL); }
PERMUTE(ARGB8888, VT_U8) PERMUTE(ARGBFFFF, VT_F32) PERMUTE(ARGB16U, VT_U16) PERMUTE(ARGB16F, VT_F16)
vImage_Error vImagePermuteChannels_RGB888(const vImage_Buffer *src, const vImage_Buffer *dest, const uint8_t *permuteMap, vImage_Flags flags) {
    return permute(src, dest, VF(3, VT_U8), permuteMap, 0, NULL);
}
#define PERMUTE_INSERT(name, t, T) \
    vImage_Error vImagePermuteChannelsWithMaskedInsert_##name(const vImage_Buffer *src, const vImage_Buffer *dest, const uint8_t *permuteMap, \
                                                             uint8_t copyMask, const T *backgroundColor, vImage_Flags flags) { \
        float bg[4]; VBG_MULTI_PX(bg, VF(4, t), backgroundColor); return permute(src, dest, VF(4, t), permuteMap, copyMask, bg); }
PERMUTE_INSERT(ARGB8888, VT_U8, uint8_t) PERMUTE_INSERT(ARGBFFFF, VT_F32, float) PERMUTE_INSERT(ARGB16U, VT_U16, uint16_t)

vImage_Error vImageByteSwap_Planar16U(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const uint16_t *s = (const uint16_t *)vrow(src, (long)y); uint16_t *d = (uint16_t *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) d[x] = (uint16_t)(s[x] << 8 | s[x] >> 8);
    }
    return kvImageNoError;
}

/* ---- Core Graphics layouts ---- */

typedef struct {
    int bpc, bpp, ncolor, alpha_first, has_alpha, skip, premul, alpha_only, fp, little, nsamples;
    const CGFloat *decode;
} cglayout;

static int layout_of(const vImage_CGImageFormat *f, cglayout *l) {
    if (!f || !f->bitsPerComponent || !f->bitsPerPixel) return 0;
    memset(l, 0, sizeof *l);
    l->bpc = (int)f->bitsPerComponent; l->bpp = (int)f->bitsPerPixel; l->decode = f->decode;
    int alpha = f->bitmapInfo & kCGBitmapAlphaInfoMask, order = f->bitmapInfo & kCGBitmapByteOrderMask;
    l->fp = !!(f->bitmapInfo & kCGBitmapFloatComponents);
    l->little = order == kCGBitmapByteOrder16Little || order == kCGBitmapByteOrder32Little;
    l->alpha_only = alpha == kCGImageAlphaOnly;
    l->has_alpha = alpha != kCGImageAlphaNone;
    l->skip = alpha == kCGImageAlphaNoneSkipFirst || alpha == kCGImageAlphaNoneSkipLast;
    l->premul = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast;
    l->alpha_first = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaNoneSkipFirst;
    int total = l->bpp / l->bpc;
    l->ncolor = f->colorSpace ? (int)CGColorSpaceGetNumberOfComponents(f->colorSpace) : total - l->has_alpha >= 3 ? 3 : 1;
    if (l->alpha_only) l->ncolor = 0;
    l->nsamples = l->ncolor + (l->has_alpha ? 1 : 0);
    if (l->nsamples < 1 || l->nsamples > total || (l->bpc != 8 && l->bpc != 16 && l->bpc != 32 && l->bpc != 1 && l->bpc != 2 && l->bpc != 4)) return 0;
    if (l->fp && l->bpc != 16 && l->bpc != 32) return 0;
    if (l->bpc < 8 && l->nsamples != 1) return 0;
    return 1;
}

/* one sample at sample index i of a pixel starting at bit offset `bit` of the row, as 0...1 (or its float value) */
static float sample_in(const uint8_t *row, const cglayout *l, size_t px, int i) {
    if (l->bpc < 8) {
        size_t bit = px * (size_t)l->bpp; int v = (row[bit / 8] >> (8 - l->bpc - (int)(bit % 8))) & ((1 << l->bpc) - 1);
        return (float)v / (float)((1 << l->bpc) - 1);
    }
    size_t B = (size_t)l->bpc / 8, pxb = (size_t)l->bpp / 8;
    const uint8_t *p = row + px * pxb;
    size_t idx = (size_t)i;
    /* 32-bit little-endian words of 8-bit samples reverse the order of the four bytes */
    if (l->bpc == 8 && l->little && pxb == 4) idx = 3 - idx;
    else if (l->bpc == 8 && l->little && pxb == 2) idx = 1 - idx;
    p += idx * B;
    if (l->bpc == 8) return p[0] / 255.f;
    if (l->bpc == 16) {
        uint16_t v = l->little ? (uint16_t)(p[0] | p[1] << 8) : (uint16_t)(p[0] << 8 | p[1]);
        return l->fp ? vhalf_to_float(v) : v / 65535.f;
    }
    uint32_t v = l->little ? (uint32_t)(p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24) : (uint32_t)((uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]);
    if (l->fp) { float f; memcpy(&f, &v, 4); return f; }
    return (float)(v / 4294967295.0);
}
static void sample_out(uint8_t *row, const cglayout *l, size_t px, int i, float v) {
    if (l->bpc < 8) {
        size_t bit = px * (size_t)l->bpp; int max = (1 << l->bpc) - 1, sh = 8 - l->bpc - (int)(bit % 8);
        int q = (int)lrintf(vclampf(v, 0, 1) * max);
        row[bit / 8] = (uint8_t)((row[bit / 8] & ~(max << sh)) | q << sh);
        return;
    }
    size_t B = (size_t)l->bpc / 8, pxb = (size_t)l->bpp / 8, idx = (size_t)i;
    if (l->bpc == 8 && l->little && pxb == 4) idx = 3 - idx;
    else if (l->bpc == 8 && l->little && pxb == 2) idx = 1 - idx;
    uint8_t *p = row + px * pxb + idx * B;
    if (l->bpc == 8) { p[0] = (uint8_t)lrintf(vclampf(v, 0, 1) * 255); return; }
    if (l->bpc == 16) {
        uint16_t q = l->fp ? vfloat_to_half(v) : (uint16_t)lrintf(vclampf(v, 0, 1) * 65535);
        if (l->little) { p[0] = (uint8_t)q; p[1] = (uint8_t)(q >> 8); } else { p[0] = (uint8_t)(q >> 8); p[1] = (uint8_t)q; }
        return;
    }
    uint32_t q;
    if (l->fp) memcpy(&q, &v, 4); else q = (uint32_t)llrint(vclampf(v, 0, 1) * 4294967295.0);
    if (l->little) { p[0] = (uint8_t)q; p[1] = (uint8_t)(q >> 8); p[2] = (uint8_t)(q >> 16); p[3] = (uint8_t)(q >> 24); }
    else { p[0] = (uint8_t)(q >> 24); p[1] = (uint8_t)(q >> 16); p[2] = (uint8_t)(q >> 8); p[3] = (uint8_t)q; }
}

/* a pixel of a layout to non-premultiplied RGBA (0...1) */
static void decode_px(const uint8_t *row, const cglayout *l, size_t x, float *rgba) {
    float s[5] = { 0 };
    int n = l->ncolor + (l->has_alpha ? 1 : 0), color0 = l->has_alpha && l->alpha_first ? 1 : 0;
    for (int i = 0; i < n && i < 5; i++) s[i] = sample_in(row, l, x, i);
    if (l->decode) for (int i = 0; i < l->ncolor; i++) s[color0 + i] = (float)(l->decode[2 * i] + (l->decode[2 * i + 1] - l->decode[2 * i]) * s[color0 + i]);
    float a = !l->has_alpha || l->skip ? 1.f : l->alpha_first ? s[0] : s[l->ncolor];
    float c[4] = { 0, 0, 0, 0 };
    for (int i = 0; i < l->ncolor && i < 4; i++) c[i] = s[color0 + i];
    if (l->premul) for (int i = 0; i < 4; i++) c[i] = a > 0 ? c[i] / a : 0;
    if (l->alpha_only) { rgba[0] = rgba[1] = rgba[2] = 0; rgba[3] = s[0]; return; }
    if (l->ncolor == 1) { rgba[0] = rgba[1] = rgba[2] = c[0]; }
    else if (l->ncolor == 4) {   /* CMYK */
        for (int i = 0; i < 3; i++) rgba[i] = (1 - c[i]) * (1 - c[3]);
    } else { rgba[0] = c[0]; rgba[1] = c[1]; rgba[2] = c[2]; }
    rgba[3] = a;
}
static void encode_px(uint8_t *row, const cglayout *l, size_t x, const float *rgba, const float *bg) {
    float r = rgba[0], g = rgba[1], b = rgba[2], a = rgba[3];
    if (!l->has_alpha || l->skip) {   /* no alpha to keep: flatten over the background */
        if (bg && a < 1) { r = r * a + bg[0] * (1 - a); g = g * a + bg[1] * (1 - a); b = b * a + bg[2] * (1 - a); }
        a = 1;
    }
    float c[4] = { r, g, b, 0 };
    int nc = l->ncolor;
    if (nc == 1) c[0] = 0.2126f * r + 0.7152f * g + 0.0722f * b;
    else if (nc == 4) { float k = 1 - fmaxf(r, fmaxf(g, b)); for (int i = 0; i < 3; i++) c[i] = k < 1 ? (1 - c[i] - k) / (1 - k) : 0; c[3] = k; }
    if (l->premul) for (int i = 0; i < nc; i++) c[i] *= a;
    if (l->decode) for (int i = 0; i < nc; i++) {
        double lo = l->decode[2 * i], hi = l->decode[2 * i + 1];
        c[i] = hi != lo ? (float)((c[i] - lo) / (hi - lo)) : 0;
    }
    int color0 = l->has_alpha && l->alpha_first ? 1 : 0;
    if (l->alpha_only) { sample_out(row, l, x, 0, a); return; }
    if (l->has_alpha) sample_out(row, l, x, l->alpha_first ? 0 : nc, l->skip ? 1 : a);
    for (int i = 0; i < nc; i++) sample_out(row, l, x, color0 + i, c[i]);
}

static int pixels_convert(const void *src, size_t srb, const cglayout *sl, void *dst, size_t drb, const cglayout *dl,
                          size_t w, size_t h, const float *bg) {
    for (size_t y = 0; y < h; y++) {
        const uint8_t *s = (const uint8_t *)src + y * srb; uint8_t *d = (uint8_t *)dst + y * drb;
        if (dl->bpc < 8) memset(d, 0, (w * (size_t)dl->bpp + 7) / 8);
        for (size_t x = 0; x < w; x++) { float px[4]; decode_px(s, sl, x, px); encode_px(d, dl, x, px, bg); }
    }
    return 1;
}

static void bg_rgb(const vImage_CGImageFormat *f, const CGFloat *bg, float *out) {
    out[0] = out[1] = out[2] = 0;
    if (!bg) return;
    size_t n = f && f->colorSpace ? CGColorSpaceGetNumberOfComponents(f->colorSpace) : 3;
    if (n == 1) out[0] = out[1] = out[2] = (float)bg[0];
    else for (int i = 0; i < 3; i++) out[i] = (float)bg[i];
}

/* ---- vImage_CGImageFormat ---- */

bool vImageCGImageFormat_IsEqual(const vImage_CGImageFormat *f1, const vImage_CGImageFormat *f2) {
    if (!f1 || !f2) return f1 == f2;
    if (f1->bitsPerComponent != f2->bitsPerComponent || f1->bitsPerPixel != f2->bitsPerPixel || f1->bitmapInfo != f2->bitmapInfo ||
        f1->renderingIntent != f2->renderingIntent) return false;
    if (f1->colorSpace != f2->colorSpace) {
        if (!f1->colorSpace || !f2->colorSpace) return false;
        if (!CFEqual(f1->colorSpace, f2->colorSpace)) return false;
    }
    if (!f1->decode != !f2->decode) return false;
    if (f1->decode) {
        size_t n = f1->colorSpace ? CGColorSpaceGetNumberOfComponents(f1->colorSpace) : 3;
        for (size_t i = 0; i < 2 * n; i++) if (f1->decode[i] != f2->decode[i]) return false;
    }
    return true;
}

uint32_t vImageCGImageFormat_GetComponentCount(const vImage_CGImageFormat *format) {
    cglayout l;
    if (!layout_of(format, &l)) return 0;
    return (uint32_t)(l.ncolor + (l.has_alpha ? 1 : 0));
}

static const CGFloat q12_decode[8] = { -8, 8, -8, 8, -8, 8, -8, 8 };
const CGFloat *kvImageDecodeArray_16Q12Format = q12_decode;

/* ---- images in ---- */

vImage_Error vImageBuffer_InitWithCGImage(vImage_Buffer *buf, vImage_CGImageFormat *format, const CGFloat *backgroundColor,
                                          CGImageRef image, vImage_Flags flags) {
    if (!buf || !format || !image) return kvImageNullPointerArgument;
    size_t w = CGImageGetWidth(image), h = CGImageGetHeight(image);
    vImage_CGImageFormat src = {
        .bitsPerComponent = (uint32_t)CGImageGetBitsPerComponent(image), .bitsPerPixel = (uint32_t)CGImageGetBitsPerPixel(image),
        .colorSpace = CGImageGetColorSpace(image), .bitmapInfo = CGImageGetBitmapInfo(image),
        .decode = CGImageGetDecode(image), .renderingIntent = CGImageGetRenderingIntent(image),
    };
    if (!format->bitsPerComponent) {   /* an empty format: the image's own */
        *format = src;
        format->decode = NULL;
        if (format->colorSpace) CGColorSpaceRetain(format->colorSpace);
    }
    cglayout sl, dl;
    if (!layout_of(&src, &sl) || !layout_of(format, &dl)) return kvImageInvalidImageFormat;
    if (!(flags & kvImageNoAllocate)) {
        vImage_Error e = vImageBuffer_Init(buf, h, w, format->bitsPerPixel, flags);
        if (e) return e;
    } else if (!buf->data) return kvImageNullPointerArgument;
    else if (buf->width < w || buf->height < h) return kvImageRoiLargerThanInputBuffer;
    CGDataProviderRef prov = CGImageGetDataProvider(image);
    CFDataRef data = prov ? CGDataProviderCopyData(prov) : NULL;
    if (!data) return kvImageInvalidImageObject;
    size_t srb = CGImageGetBytesPerRow(image);
    if (!srb) srb = (w * src.bitsPerPixel + 7) / 8;
    if ((size_t)CFDataGetLength(data) < srb * (h - 1) + (w * src.bitsPerPixel + 7) / 8) { CFRelease(data); return kvImageInvalidImageObject; }
    float bg[3]; bg_rgb(format, backgroundColor, bg);
    pixels_convert(CFDataGetBytePtr(data), srb, &sl, buf->data, buf->rowBytes, &dl, w, h, bg);
    CFRelease(data);
    return kvImageNoError;
}

/* ---- images out ---- */

struct release_info { void (*callback)(void *, void *); void *user; void *data; int owned; };
static void release_data(void *info, const void *data, size_t size) {
    struct release_info *r = info;
    if (r->owned) free(r->data);
    else if (r->callback) r->callback(r->user, r->data);
    free(r);
}

CGImageRef vImageCreateCGImageFromBuffer(const vImage_Buffer *buf, const vImage_CGImageFormat *format,
                                         void (*callback)(void *userData, void *buf_data), void *userData, vImage_Flags flags,
                                         vImage_Error *error) {
    vImage_Error dummy; if (!error) error = &dummy;
    *error = kvImageNoError;
    cglayout l;
    if (!buf || !buf->data || !format) { *error = kvImageNullPointerArgument; return NULL; }
    if (!layout_of(format, &l)) { *error = kvImageInvalidImageFormat; return NULL; }
    size_t w = buf->width, h = buf->height;
    CGColorSpaceRef cs = format->colorSpace;
    CGColorSpaceRef owned_cs = NULL;
    if (!cs) cs = owned_cs = l.ncolor == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    struct release_info *ri = calloc(1, sizeof *ri);
    CGImageRef im = NULL;
    /* isim's Core Graphics keeps 8 bits per component: other layouts are converted to 8-bit RGBA (or gray) */
    int native = l.bpc == 8 && !l.fp && !format->decode;
    if (native) {
        size_t size = buf->rowBytes * h;
        if (flags & kvImageNoAllocate) { ri->callback = callback; ri->user = userData; ri->data = buf->data; }
        else { ri->data = malloc(size); memcpy(ri->data, buf->data, size); ri->owned = 1; }
        CGDataProviderRef p = CGDataProviderCreateWithData(ri, ri->data, size, release_data);
        im = CGImageCreate(w, h, 8, (size_t)l.bpp, buf->rowBytes, cs, format->bitmapInfo, p, NULL, true, format->renderingIntent);
        CGDataProviderRelease(p);
        ri = NULL;   /* the provider owns it now */
        if (im) goto done;
        if (flags & kvImageNoAllocate) { *error = kvImageInvalidImageFormat; goto done; }
    }
    {
        int gray = l.ncolor == 1;
        vImage_CGImageFormat f8 = { 8, gray ? (l.has_alpha && !l.skip ? 16 : 8) : 32, NULL,
                                    (CGBitmapInfo)(gray ? (l.has_alpha && !l.skip ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone)
                                                        : (l.has_alpha && !l.skip ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast)),
                                    0, NULL, format->renderingIntent };
        cglayout l8; f8.colorSpace = gray ? cs : NULL;
        CGColorSpaceRef rgb = gray ? NULL : (l.ncolor == 3 ? CGColorSpaceRetain(cs) : CGColorSpaceCreateDeviceRGB());
        if (!gray) f8.colorSpace = rgb;
        layout_of(&f8, &l8);
        size_t rb = w * (f8.bitsPerPixel / 8);
        void *px = malloc(rb * h);
        pixels_convert(buf->data, buf->rowBytes, &l, px, rb, &l8, w, h, NULL);
        if (!ri) ri = calloc(1, sizeof *ri);
        ri->data = px; ri->owned = 1;
        CGDataProviderRef p = CGDataProviderCreateWithData(ri, px, rb * h, release_data);
        ri = NULL;
        im = CGImageCreate(w, h, 8, f8.bitsPerPixel, rb, f8.colorSpace, f8.bitmapInfo, p, NULL, true, format->renderingIntent);
        CGDataProviderRelease(p);
        if (rgb) CGColorSpaceRelease(rgb);
        if (!im) *error = kvImageInternalError;
        else if ((flags & kvImageNoAllocate) && callback) callback(userData, buf->data);   /* the pixels were copied */
    }
done:
    free(ri);
    if (owned_cs) CGColorSpaceRelease(owned_cs);
    return im;
}

/* ---- converters ---- */

/* a Core Graphics-style object (an Objective-C object with a finalizer), so CFRetain / CFRelease and Swift manage it */
struct vImageConverter {
    struct { void *isa; void (*fin)(void *); const char *kind; } hdr;
    vImage_CGImageFormat src, dst;
    float bg[3];
    int has_bg;
    vImageBufferTypeCode src_order[2], dst_order[2];
};

static void converter_free(void *p) {
    struct vImageConverter *c = p;
    if (c->src.colorSpace) CGColorSpaceRelease(c->src.colorSpace);
    if (c->dst.colorSpace) CGColorSpaceRelease(c->dst.colorSpace);
    free((void *)c->src.decode); free((void *)c->dst.decode);
}

static void format_copy(vImage_CGImageFormat *d, const vImage_CGImageFormat *s) {
    *d = *s;
    if (d->colorSpace) CGColorSpaceRetain(d->colorSpace);
    if (s->decode) {
        size_t n = 2 * (s->colorSpace ? CGColorSpaceGetNumberOfComponents(s->colorSpace) : 3);
        CGFloat *dec = malloc(n * sizeof(CGFloat)); memcpy(dec, s->decode, n * sizeof(CGFloat)); d->decode = dec;
    }
}

vImageConverterRef vImageConverter_CreateWithCGImageFormat(const vImage_CGImageFormat *srcFormat, const vImage_CGImageFormat *destFormat,
                                                           const CGFloat *backgroundColor, vImage_Flags flags, vImage_Error *error) {
    vImage_Error dummy; if (!error) error = &dummy;
    cglayout a, b;
    if (!srcFormat || !destFormat) { *error = kvImageNullPointerArgument; return NULL; }
    if (!layout_of(srcFormat, &a) || !layout_of(destFormat, &b)) { *error = kvImageInvalidImageFormat; return NULL; }
    struct vImageConverter *c = isim_cg_obj_new("vImageConverter", sizeof *c, converter_free);
    if (!c) { *error = kvImageMemoryAllocationError; return NULL; }
    format_copy(&c->src, srcFormat); format_copy(&c->dst, destFormat);
    if (backgroundColor) { c->has_bg = 1; bg_rgb(destFormat, backgroundColor, c->bg); }
    c->src_order[0] = c->dst_order[0] = kvImageBufferTypeCode_CGFormat;
    *error = kvImageNoError;
    return c;
}

vImageConverterRef vImageConverter_Retain(vImageConverterRef c) { return c ? (vImageConverterRef)CFRetain(c) : NULL; }
void vImageConverter_Release(vImageConverterRef c) { if (c) CFRelease(c); }
unsigned long vImageConverter_GetNumberOfSourceBuffers(const vImageConverterRef converter) { return converter ? 1 : 0; }
unsigned long vImageConverter_GetNumberOfDestinationBuffers(const vImageConverterRef converter) { return converter ? 1 : 0; }
const vImageBufferTypeCode *vImageConverter_GetSourceBufferOrder(const vImageConverterRef converter) { return converter ? converter->src_order : NULL; }
const vImageBufferTypeCode *vImageConverter_GetDestinationBufferOrder(const vImageConverterRef converter) { return converter ? converter->dst_order : NULL; }
vImage_Error vImageConverter_MustOperateOutOfPlace(const vImageConverterRef converter, const vImage_Buffer *srcs, const vImage_Buffer *dests,
                                                   vImage_Flags flags) {
    if (!converter) return kvImageNullPointerArgument;
    if (!srcs || !dests || srcs->data != dests->data) return kvImageNoError;
    return converter->src.bitsPerPixel == converter->dst.bitsPerPixel ? kvImageNoError : kvImageOutOfPlaceOperationRequired;
}

vImage_Error vImageConvert_AnyToAny(const vImageConverterRef converter, const vImage_Buffer *srcs, const vImage_Buffer *dests, void *tempBuffer,
                                    vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!converter || !srcs || !dests) return kvImageNullPointerArgument;
    vImage_Error e = vsame(srcs, dests);
    if (e) return e;
    cglayout a, b;
    layout_of(&converter->src, &a); layout_of(&converter->dst, &b);
    if (srcs->data == dests->data && a.bpp != b.bpp) return kvImageOutOfPlaceOperationRequired;
    pixels_convert(srcs->data, srcs->rowBytes, &a, dests->data, dests->rowBytes, &b, dests->width, dests->height,
                   converter->has_bg ? converter->bg : NULL);
    return kvImageNoError;
}
