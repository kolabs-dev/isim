/* isim vImage: convolution, morphology, histograms, alpha compositing, colour matrices, lookup tables and gamma.
   Kernels are applied as given (a correlation, not flipped), centred on each destination pixel; 8-bit results are
   rounded to nearest. Adapted where noted below. */
#include "vimage_t.h"

/* ---- convolution ---- */

/* the source pixel for destination (x, y) is (x + offx, y + offy); kernels are kh x kw, row-major */
typedef struct {
    const vImage_Buffer *s, *d;
    vfmt f;
    long offx, offy;
    int kh, kw;
    const float *k[4];      /* per channel */
    float div[4], bias[4];
    float bg[4];
    int edge, keep_alpha;
} vconv;

static vImage_Error conv_check(const vconv *c) {
    vImage_Error e = vcheck2(c->s, c->d);
    if (e) return e;
    if (c->s->data == c->d->data) return kvImageOutOfPlaceOperationRequired;
    if (!(c->kh & 1) || !(c->kw & 1) || c->kh <= 0 || c->kw <= 0) return kvImageInvalidKernelSize;
    if (c->offx < 0 || c->offx >= (long)c->s->width) return kvImageInvalidOffset_X;
    if (c->offy < 0 || c->offy >= (long)c->s->height) return kvImageInvalidOffset_Y;
    if ((long)c->d->width + c->offx > (long)c->s->width || (long)c->d->height + c->offy > (long)c->s->height) return kvImageRoiLargerThanInputBuffer;
    if (!c->edge) return kvImageInvalidEdgeStyle;
    return kvImageNoError;
}

static vImage_Error conv2d(vconv *c) {
    vImage_Error e = conv_check(c);
    if (e) return e;
    long sw = (long)c->s->width, sh = (long)c->s->height, rh = c->kh / 2, rw = c->kw / 2;
    float total[4] = { 0 };
    for (int ch = 0; ch < c->f.ch; ch++) for (int i = 0; i < c->kh * c->kw; i++) total[ch] += c->k[ch][i];
    for (long y = 0; y < (long)c->d->height; y++) for (long x = 0; x < (long)c->d->width; x++) {
        long cx = x + c->offx, cy = y + c->offy;
        float out[4], src[4];
        vget(c->s, c->f, cx, cy, src);
        int inside = cx - rw >= 0 && cy - rh >= 0 && cx + rw < sw && cy + rh < sh;
        if (!inside && c->edge == kvImageCopyInPlace) { vput(c->d, c->f, x, y, src); continue; }
        float acc[4] = { 0 }, wsum[4] = { 0 }, px[4];
        for (int i = 0; i < c->kh; i++) for (int j = 0; j < c->kw; j++) {
            long sx = cx - rw + j, sy = cy - rh + i;
            int out_of = sx < 0 || sy < 0 || sx >= sw || sy >= sh;
            if (out_of && c->edge == kvImageTruncateKernel) continue;
            vsample_px(c->s, c->f, sx, sy, c->edge == kvImageEdgeExtend, c->bg, px);
            for (int ch = 0; ch < c->f.ch; ch++) { float w = c->k[ch][i * c->kw + j]; acc[ch] += w * px[ch]; wsum[ch] += w; }
        }
        for (int ch = 0; ch < c->f.ch; ch++) {
            float a = acc[ch];
            if (c->edge == kvImageTruncateKernel && !inside && wsum[ch] != 0 && total[ch] != 0) a *= total[ch] / wsum[ch];
            out[ch] = (a + c->bias[ch]) / c->div[ch];
        }
        if (c->keep_alpha) out[0] = src[0];
        vput(c->d, c->f, x, y, out);
    }
    return kvImageNoError;
}

/* separable kernels (box, tent, SepConvolve): a horizontal pass over the source rows, then a vertical one */
static vImage_Error conv_sep(vconv *c, const float *kx, const float *ky, float bias) {
    vImage_Error e = conv_check(c);
    if (e) return e;
    long sw = (long)c->s->width, sh = (long)c->s->height, dw = (long)c->d->width, dh = (long)c->d->height;
    long rw = c->kw / 2, rh = c->kh / 2, ch = c->f.ch;
    long y0 = c->offy - rh, y1 = c->offy + dh - 1 + rh, rows = y1 - y0 + 1;
    float *tmp = malloc(sizeof(float) * (size_t)(rows * dw * ch)), *valid = malloc(sizeof(float) * (size_t)rows);
    if (!tmp || !valid) { free(tmp); free(valid); return kvImageMemoryAllocationError; }
    float tx = 0, ty = 0;
    for (int i = 0; i < c->kw; i++) tx += kx[i];
    for (int i = 0; i < c->kh; i++) ty += ky[i];
    for (long r = 0; r < rows; r++) {
        long sy = y0 + r;
        int row_out = sy < 0 || sy >= sh;
        valid[r] = !row_out;
        long syc = sy < 0 ? 0 : sy >= sh ? sh - 1 : sy;
        for (long x = 0; x < dw; x++) {
            float acc[4] = { 0 }, ws = 0, px[4];
            for (int j = 0; j < c->kw; j++) {
                long sx = x + c->offx - rw + j;
                int out_of = sx < 0 || sx >= sw;
                if (out_of && c->edge == kvImageTruncateKernel) continue;
                if (row_out && c->edge != kvImageEdgeExtend) { for (int k = 0; k < ch; k++) px[k] = c->bg[k]; }
                else vsample_px(c->s, c->f, sx, syc, c->edge == kvImageEdgeExtend, c->bg, px);
                for (int k = 0; k < ch; k++) acc[k] += kx[j] * px[k];
                ws += kx[j];
            }
            if (c->edge == kvImageTruncateKernel && ws != 0 && tx != 0) for (int k = 0; k < ch; k++) acc[k] *= tx / ws;
            for (int k = 0; k < ch; k++) tmp[(r * dw + x) * ch + k] = acc[k];
        }
    }
    for (long y = 0; y < dh; y++) for (long x = 0; x < dw; x++) {
        long cx = x + c->offx, cy = y + c->offy;
        float src[4], out[4];
        vget(c->s, c->f, cx, cy, src);
        int inside = cx - rw >= 0 && cy - rh >= 0 && cx + rw < sw && cy + rh < sh;
        if (!inside && c->edge == kvImageCopyInPlace) { vput(c->d, c->f, x, y, src); continue; }
        float acc[4] = { 0 }, ws = 0;
        for (int i = 0; i < c->kh; i++) {
            long r = y + i;   /* the tmp row of source row cy - rh + i */
            if (c->edge == kvImageTruncateKernel && !valid[r]) continue;
            for (int k = 0; k < ch; k++) acc[k] += ky[i] * tmp[(r * dw + x) * ch + k];
            ws += ky[i];
        }
        if (c->edge == kvImageTruncateKernel && ws != 0 && ty != 0) for (int k = 0; k < ch; k++) acc[k] *= ty / ws;
        for (int k = 0; k < ch; k++) out[k] = (acc[k] + bias) / c->div[k];
        if (c->keep_alpha) out[0] = src[0];
        vput(c->d, c->f, x, y, out);
    }
    free(tmp); free(valid);
    return kvImageNoError;
}

static float *kernel_f(const int16_t *k, int n) {
    float *o = malloc(sizeof(float) * (size_t)(n > 0 ? n : 1));
    for (int i = 0; i < n; i++) o[i] = k[i];
    return o;
}
static void conv_init(vconv *c, const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, vImagePixelCount ox, vImagePixelCount oy,
                      uint32_t kh, uint32_t kw, vImage_Flags flags) {
    memset(c, 0, sizeof *c);
    c->s = s; c->d = d; c->f = f; c->offx = (long)ox; c->offy = (long)oy; c->kh = (int)kh; c->kw = (int)kw;
    c->edge = vedge(flags);
    c->keep_alpha = f.ch == 4 && (flags & kvImageLeaveAlphaUnchanged);
    for (int i = 0; i < 4; i++) c->div[i] = 1;
}
static vImage_Error conv_int(const vImage_Buffer *src, const vImage_Buffer *dest, vfmt f, vImagePixelCount ox, vImagePixelCount oy,
                             const int16_t *kernel, uint32_t kh, uint32_t kw, int32_t divisor, int32_t bias, const float *bg, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!kernel) return kvImageNullPointerArgument;
    if (divisor == 0) return kvImageInvalidParameter;
    vconv c; conv_init(&c, src, dest, f, ox, oy, kh, kw, flags);
    float *k = kernel_f(kernel, (int)(kh * kw));
    for (int i = 0; i < 4; i++) { c.k[i] = k; c.div[i] = (float)divisor; c.bias[i] = (float)bias; c.bg[i] = bg[i]; }
    vImage_Error e = conv2d(&c);
    free(k);
    return e;
}
static vImage_Error conv_float(const vImage_Buffer *src, const vImage_Buffer *dest, vfmt f, vImagePixelCount ox, vImagePixelCount oy,
                               const float *kernel, uint32_t kh, uint32_t kw, float bias, const float *bg, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!kernel) return kvImageNullPointerArgument;
    vconv c; conv_init(&c, src, dest, f, ox, oy, kh, kw, flags);
    for (int i = 0; i < 4; i++) { c.k[i] = kernel; c.bias[i] = bias; c.bg[i] = bg[i]; }
    return conv2d(&c);
}

vImage_Error vImageConvolve_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                    vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                    int32_t divisor, Pixel_8 backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return conv_int(src, dest, VF(1, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, divisor, 0, bg, flags);
}
vImage_Error vImageConvolveWithBias_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                            vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                            int32_t divisor, int32_t bias, Pixel_8 backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return conv_int(src, dest, VF(1, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, divisor, bias, bg, flags);
}
vImage_Error vImageConvolve_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                     vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                     int32_t divisor, const uint8_t *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return conv_int(src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, divisor, 0, bg, flags);
}
vImage_Error vImageConvolveWithBias_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                             vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                             int32_t divisor, int32_t bias, const uint8_t *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return conv_int(src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, divisor, bias, bg, flags);
}
vImage_Error vImageConvolve_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                    vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                    Pixel_F backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return conv_float(src, dest, VF(1, VT_F32), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, 0, bg, flags);
}
vImage_Error vImageConvolveWithBias_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                            vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                            float bias, Pixel_F backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return conv_float(src, dest, VF(1, VT_F32), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, bias, bg, flags);
}
vImage_Error vImageConvolve_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                     vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                     const float *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_F32), backgroundColor);
    return conv_float(src, dest, VF(4, VT_F32), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, 0, bg, flags);
}
vImage_Error vImageConvolveWithBias_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                             vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                             float bias, const float *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_F32), backgroundColor);
    return conv_float(src, dest, VF(4, VT_F32), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, bias, bg, flags);
}
/* the 16F forms take float kernels */
vImage_Error vImageConvolve_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                      vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                      Pixel_16F backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_PLANAR_PX(bg, VT_F16, backgroundColor);
    return conv_float(src, dest, VF(1, VT_F16), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, 0, bg, flags);
}
vImage_Error vImageConvolveWithBias_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                              vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                              float bias, Pixel_16F backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_PLANAR_PX(bg, VT_F16, backgroundColor);
    return conv_float(src, dest, VF(1, VT_F16), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, bias, bg, flags);
}
vImage_Error vImageConvolve_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                    vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                    const Pixel_16F *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_F16), backgroundColor);
    return conv_float(src, dest, VF(4, VT_F16), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, 0, bg, flags);
}
vImage_Error vImageConvolveWithBias_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                            vImagePixelCount srcOffsetToROI_Y, const float *kernel, uint32_t kernel_height, uint32_t kernel_width,
                                            float bias, const Pixel_16F *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_F16), backgroundColor);
    return conv_float(src, dest, VF(4, VT_F16), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, bias, bg, flags);
}
vImage_Error vImageConvolveFloatKernel_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer,
                                                vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const float *kernel,
                                                uint32_t kernel_height, uint32_t kernel_width, float bias, const uint8_t *backgroundColor,
                                                vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return conv_float(src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, bias, bg, flags);
}
vImage_Error vImageConvolveMultiKernel_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer,
                                                vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const int16_t *kernels[4],
                                                uint32_t kernel_height, uint32_t kernel_width, const int32_t divisors[4], const int32_t biases[4],
                                                const uint8_t *backgroundColor, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!kernels || !divisors || !biases) return kvImageNullPointerArgument;
    vconv c; conv_init(&c, src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, flags);
    float *k[4] = { 0 };
    VBG_MULTI_PX(c.bg, VF(4, VT_U8), backgroundColor);
    for (int i = 0; i < 4; i++) {
        if (!kernels[i] || !divisors[i]) { for (int j = 0; j < i; j++) free(k[j]); return kernels[i] ? kvImageInvalidParameter : kvImageNullPointerArgument; }
        k[i] = kernel_f(kernels[i], (int)(kernel_height * kernel_width)); c.k[i] = k[i]; c.div[i] = (float)divisors[i]; c.bias[i] = (float)biases[i];
    }
    vImage_Error e = conv2d(&c);
    for (int i = 0; i < 4; i++) free(k[i]);
    return e;
}
vImage_Error vImageConvolveMultiKernel_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer,
                                                vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const float *kernels[4],
                                                uint32_t kernel_height, uint32_t kernel_width, const float biases[4], const float *backgroundColor,
                                                vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!kernels || !biases) return kvImageNullPointerArgument;
    vconv c; conv_init(&c, src, dest, VF(4, VT_F32), srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, flags);
    VBG_MULTI_PX(c.bg, VF(4, VT_F32), backgroundColor);
    for (int i = 0; i < 4; i++) { if (!kernels[i]) return kvImageNullPointerArgument; c.k[i] = kernels[i]; c.bias[i] = biases[i]; }
    return conv2d(&c);
}

/* box and tent: separable kernels of ones and of triangles */
static vImage_Error box_tent(const vImage_Buffer *src, const vImage_Buffer *dest, vfmt f, vImagePixelCount ox, vImagePixelCount oy,
                             uint32_t kh, uint32_t kw, const float *bg, vImage_Flags flags, int tent) {
    if (flags & kvImageGetTempBufferSize) return 0;
    vconv c; conv_init(&c, src, dest, f, ox, oy, kh, kw, flags);
    for (int i = 0; i < 4; i++) c.bg[i] = bg[i];
    if (!(kh & 1) || !(kw & 1) || !kh || !kw) return kvImageInvalidKernelSize;
    float *kx = malloc(sizeof(float) * kw), *ky = malloc(sizeof(float) * kh), sx = 0, sy = 0;
    for (uint32_t i = 0; i < kw; i++) { kx[i] = tent ? (float)(kw / 2 + 1 - labs((long)i - (long)(kw / 2))) : 1; sx += kx[i]; }
    for (uint32_t i = 0; i < kh; i++) { ky[i] = tent ? (float)(kh / 2 + 1 - labs((long)i - (long)(kh / 2))) : 1; sy += ky[i]; }
    for (int i = 0; i < 4; i++) c.div[i] = sx * sy;
    vImage_Error e = conv_sep(&c, kx, ky, 0);
    free(kx); free(ky);
    return e;
}
vImage_Error vImageBoxConvolve_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                       vImagePixelCount srcOffsetToROI_Y, uint32_t kernel_height, uint32_t kernel_width, Pixel_8 backgroundColor,
                                       vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return box_tent(src, dest, VF(1, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, bg, flags, 0);
}
vImage_Error vImageBoxConvolve_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                        vImagePixelCount srcOffsetToROI_Y, uint32_t kernel_height, uint32_t kernel_width,
                                        const uint8_t *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return box_tent(src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, bg, flags, 0);
}
vImage_Error vImageTentConvolve_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                        vImagePixelCount srcOffsetToROI_Y, uint32_t kernel_height, uint32_t kernel_width, Pixel_8 backgroundColor,
                                        vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return box_tent(src, dest, VF(1, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, bg, flags, 1);
}
vImage_Error vImageTentConvolve_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                         vImagePixelCount srcOffsetToROI_Y, uint32_t kernel_height, uint32_t kernel_width,
                                         const uint8_t *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return box_tent(src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, bg, flags, 1);
}

static vImage_Error sep(const vImage_Buffer *src, const vImage_Buffer *dest, vfmt f, vImagePixelCount ox, vImagePixelCount oy,
                        const float *kx, uint32_t kxw, const float *ky, uint32_t kyw, float bias, const float *bg, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!kx || !ky) return kvImageNullPointerArgument;
    vconv c; conv_init(&c, src, dest, f, ox, oy, kyw, kxw, flags);
    for (int i = 0; i < 4; i++) c.bg[i] = bg[i];
    return conv_sep(&c, kx, ky, bias);
}
vImage_Error vImageSepConvolve_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                       vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY,
                                       uint32_t kernelY_width, float bias, Pixel_16U backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return sep(src, dest, VF(1, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernelX, kernelX_width, kernelY, kernelY_width, bias, bg, flags);
}
vImage_Error vImageSepConvolve_Planar16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                         vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY,
                                         uint32_t kernelY_width, float bias, Pixel_16U backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return sep(src, dest, VF(1, VT_U16), srcOffsetToROI_X, srcOffsetToROI_Y, kernelX, kernelX_width, kernelY, kernelY_width, bias, bg, flags);
}
vImage_Error vImageSepConvolve_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                       vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY,
                                       uint32_t kernelY_width, float bias, Pixel_F backgroundColor, vImage_Flags flags) {
    float bg[4]; vbg_scalar(bg, backgroundColor);
    return sep(src, dest, VF(1, VT_F32), srcOffsetToROI_X, srcOffsetToROI_Y, kernelX, kernelX_width, kernelY, kernelY_width, bias, bg, flags);
}
vImage_Error vImageSepConvolve_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                         vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY,
                                         uint32_t kernelY_width, float bias, Pixel_16F backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_PLANAR_PX(bg, VT_F16, backgroundColor);
    return sep(src, dest, VF(1, VT_F16), srcOffsetToROI_X, srcOffsetToROI_Y, kernelX, kernelX_width, kernelY, kernelY_width, bias, bg, flags);
}
vImage_Error vImageSepConvolve_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X,
                                        vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY,
                                        uint32_t kernelY_width, float bias, const uint8_t *backgroundColor, vImage_Flags flags) {
    float bg[4]; VBG_MULTI_PX(bg, VF(4, VT_U8), backgroundColor);
    return sep(src, dest, VF(4, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernelX, kernelX_width, kernelY, kernelY_width, bias, bg, flags);
}

/* ---- morphology: dilate = max(src - kernel), erode = min(src + kernel); max / min over a rectangle ---- */

static vImage_Error morph(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, long offx, long offy, const float *k, long kh, long kw,
                          int dilate, vImage_Flags flags) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->data == d->data) return kvImageOutOfPlaceOperationRequired;
    if (!(kh & 1) || !(kw & 1) || kh <= 0 || kw <= 0) return kvImageInvalidKernelSize;
    if (offx < 0 || offx >= (long)s->width) return kvImageInvalidOffset_X;
    if (offy < 0 || offy >= (long)s->height) return kvImageInvalidOffset_Y;
    long sw = (long)s->width, sh = (long)s->height, rh = kh / 2, rw = kw / 2;
    int keep_alpha = f.ch == 4 && (flags & kvImageLeaveAlphaUnchanged);
    if (!k) {   /* a rectangle (Max / Min): separable */
        long dw = (long)d->width, dh = (long)d->height, ch = f.ch, y0 = offy - rh, rows = dh + 2 * rh;
        float *tmp = malloc(sizeof(float) * (size_t)(rows * dw * ch));
        if (!tmp) return kvImageMemoryAllocationError;
        for (long r = 0; r < rows; r++) {
            long sy = y0 + r;
            for (long x = 0; x < dw; x++) {
                float best[4], px[4]; int any = 0;
                for (long j = -rw; j <= rw; j++) {
                    long sx = x + offx + j;
                    if (sx < 0 || sx >= sw || sy < 0 || sy >= sh) continue;
                    vget(s, f, sx, sy, px);
                    for (int c = 0; c < ch; c++) if (!any || (dilate ? px[c] > best[c] : px[c] < best[c])) best[c] = px[c];
                    any = 1;
                }
                for (int c = 0; c < ch; c++) tmp[(r * dw + x) * ch + c] = any ? best[c] : (dilate ? -INFINITY : INFINITY);
            }
        }
        for (long y = 0; y < dh; y++) for (long x = 0; x < dw; x++) {
            float best[4], src[4];
            for (int c = 0; c < ch; c++) best[c] = dilate ? -INFINITY : INFINITY;
            for (long i = 0; i < kh; i++) for (int c = 0; c < ch; c++) {
                float v = tmp[((y + i) * dw + x) * ch + c];
                if (dilate ? v > best[c] : v < best[c]) best[c] = v;
            }
            if (keep_alpha) { vget(s, f, x + offx, y + offy, src); best[0] = src[0]; }
            vput(d, f, x, y, best);
        }
        free(tmp);
        return kvImageNoError;
    }
    for (long y = 0; y < (long)d->height; y++) for (long x = 0; x < (long)d->width; x++) {
        float best[4], px[4];
        for (int c = 0; c < f.ch; c++) best[c] = dilate ? -INFINITY : INFINITY;
        for (long i = 0; i < kh; i++) for (long j = 0; j < kw; j++) {
            long sx = x + offx - rw + j, sy = y + offy - rh + i;
            if (sx < 0 || sy < 0 || sx >= sw || sy >= sh) continue;
            vget(s, f, sx, sy, px);
            float kv = k[i * kw + j];
            for (int c = 0; c < f.ch; c++) { float v = dilate ? px[c] - kv : px[c] + kv; if (dilate ? v > best[c] : v < best[c]) best[c] = v; }
        }
        if (keep_alpha) { vget(s, f, x + offx, y + offy, px); best[0] = px[0]; }
        vput(d, f, x, y, best);
    }
    return kvImageNoError;
}
static vImage_Error morph8(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, vImagePixelCount ox, vImagePixelCount oy, const uint8_t *k,
                           vImagePixelCount kh, vImagePixelCount kw, int dilate, vImage_Flags flags) {
    if (!k) return kvImageNullPointerArgument;
    float *kf = malloc(sizeof(float) * (kh * kw ? kh * kw : 1));
    for (vImagePixelCount i = 0; i < kh * kw; i++) kf[i] = k[i];
    vImage_Error e = morph(s, d, f, (long)ox, (long)oy, kf, (long)kh, (long)kw, dilate, flags);
    free(kf);
    return e;
}
#define MORPH8(name, ch) \
    vImage_Error vImageDilate_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, \
                                     const unsigned char *kernel, vImagePixelCount kernel_height, vImagePixelCount kernel_width, vImage_Flags flags) { \
        return morph8(src, dest, VF(ch, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, 1, flags); } \
    vImage_Error vImageErode_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, \
                                    const unsigned char *kernel, vImagePixelCount kernel_height, vImagePixelCount kernel_width, vImage_Flags flags) { \
        return morph8(src, dest, VF(ch, VT_U8), srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, 0, flags); }
#define MORPHF(name, ch) \
    vImage_Error vImageDilate_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, \
                                     const float *kernel, vImagePixelCount kernel_height, vImagePixelCount kernel_width, vImage_Flags flags) { \
        if (!kernel) return kvImageNullPointerArgument; \
        return morph(src, dest, VF(ch, VT_F32), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, kernel, (long)kernel_height, (long)kernel_width, 1, flags); } \
    vImage_Error vImageErode_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, \
                                    const float *kernel, vImagePixelCount kernel_height, vImagePixelCount kernel_width, vImage_Flags flags) { \
        if (!kernel) return kvImageNullPointerArgument; \
        return morph(src, dest, VF(ch, VT_F32), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, kernel, (long)kernel_height, (long)kernel_width, 0, flags); }
#define MAXMIN(name, ch, t) \
    vImage_Error vImageMax_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, \
                                  vImagePixelCount srcOffsetToROI_Y, vImagePixelCount kernel_height, vImagePixelCount kernel_width, vImage_Flags flags) { \
        if (flags & kvImageGetTempBufferSize) return 0; \
        return morph(src, dest, VF(ch, t), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, NULL, (long)kernel_height, (long)kernel_width, 1, flags); } \
    vImage_Error vImageMin_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, \
                                  vImagePixelCount srcOffsetToROI_Y, vImagePixelCount kernel_height, vImagePixelCount kernel_width, vImage_Flags flags) { \
        if (flags & kvImageGetTempBufferSize) return 0; \
        return morph(src, dest, VF(ch, t), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, NULL, (long)kernel_height, (long)kernel_width, 0, flags); }
MORPH8(Planar8, 1) MORPH8(ARGB8888, 4) MORPHF(PlanarF, 1) MORPHF(ARGBFFFF, 4)
MAXMIN(Planar8, 1, VT_U8) MAXMIN(ARGB8888, 4, VT_U8) MAXMIN(PlanarF, 1, VT_F32) MAXMIN(ARGBFFFF, 4, VT_F32)

/* ---- histograms ---- */

/* channel c of an image binned into n bins over [lo, hi] (8-bit: 256 bins of the values) */
static void hist(const vImage_Buffer *s, vfmt f, int c, unsigned n, float lo, float hi, vImagePixelCount *h) {
    memset(h, 0, sizeof *h * n);
    for (vImagePixelCount y = 0; y < s->height; y++) {
        const uint8_t *r = vrow(s, (long)y);
        for (vImagePixelCount x = 0; x < s->width; x++) {
            float v = vrd(r, (long)(x * (size_t)f.ch) + c, f.t);
            long b = f.t == VT_U8 ? (long)v : hi > lo ? (long)floorf((v - lo) / (hi - lo) * (float)n) : 0;
            if (f.t != VT_U8 && v >= hi) b = n - 1;
            h[b < 0 ? 0 : b >= (long)n ? n - 1 : b]++;
        }
    }
}
vImage_Error vImageHistogramCalculation_Planar8(const vImage_Buffer *src, vImagePixelCount *histogram, vImage_Flags flags) {
    VCHECK_BUF(src); if (!histogram) return kvImageNullPointerArgument;
    hist(src, VF(1, VT_U8), 0, 256, 0, 255, histogram);
    return kvImageNoError;
}
vImage_Error vImageHistogramCalculation_PlanarF(const vImage_Buffer *src, vImagePixelCount *histogram, unsigned int histogram_entries,
                                                Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    VCHECK_BUF(src); if (!histogram) return kvImageNullPointerArgument;
    if (!histogram_entries || !(maxVal > minVal)) return kvImageInvalidParameter;
    hist(src, VF(1, VT_F32), 0, histogram_entries, minVal, maxVal, histogram);
    return kvImageNoError;
}
vImage_Error vImageHistogramCalculation_ARGB8888(const vImage_Buffer *src, vImagePixelCount *histogram[4], vImage_Flags flags) {
    VCHECK_BUF(src); if (!histogram) return kvImageNullPointerArgument;
    for (int c = 0; c < 4; c++) {
        if (c == 0 && (flags & kvImageLeaveAlphaUnchanged)) continue;
        if (!histogram[c]) return kvImageNullPointerArgument;
        hist(src, VF(4, VT_U8), c, 256, 0, 255, histogram[c]);
    }
    return kvImageNoError;
}
vImage_Error vImageHistogramCalculation_ARGBFFFF(const vImage_Buffer *src, vImagePixelCount *histogram[4], unsigned int histogram_entries,
                                                 Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    VCHECK_BUF(src); if (!histogram) return kvImageNullPointerArgument;
    if (!histogram_entries || !(maxVal > minVal)) return kvImageInvalidParameter;
    for (int c = 0; c < 4; c++) {
        if (c == 0 && (flags & kvImageLeaveAlphaUnchanged)) continue;
        if (!histogram[c]) return kvImageNullPointerArgument;
        hist(src, VF(4, VT_F32), c, histogram_entries, minVal, maxVal, histogram[c]);
    }
    return kvImageNoError;
}

/* maps a channel through a table of n bins: 8-bit samples index it directly, floats by their bin */
static void apply_map(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, int c, const float *map, unsigned n, float lo, float hi) {
    for (vImagePixelCount y = 0; y < d->height; y++) {
        const uint8_t *r = vrow(s, (long)y); uint8_t *w = vrowm(d, (long)y);
        for (vImagePixelCount x = 0; x < d->width; x++) {
            long i = (long)(x * (size_t)f.ch) + c;
            float v = vrd(r, i, f.t);
            long b = f.t == VT_U8 ? (long)v : hi > lo ? (long)floorf((v - lo) / (hi - lo) * (float)n) : 0;
            b = b < 0 ? 0 : b >= (long)n ? (long)n - 1 : b;
            vwr(w, i, f.t, map[b]);
        }
    }
}
static float bin_value(unsigned i, unsigned n, float lo, float hi, int eight) {
    return eight ? (float)i : lo + (hi - lo) * (n > 1 ? (float)i / (float)(n - 1) : 0);
}

typedef enum { H_EQUALIZE, H_STRETCH, H_ENDS, H_SPECIFY } hop;
static vImage_Error hist_op(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, hop op, unsigned n, float lo, float hi,
                            const unsigned *low, const unsigned *high, const vImagePixelCount *const *desired, vImage_Flags flags) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    int eight = f.t == VT_U8;
    if (eight) { n = 256; lo = 0; hi = 255; }
    else if (!n || !(hi > lo)) return kvImageInvalidParameter;
    vImagePixelCount *h = malloc(sizeof *h * n), *cdf = malloc(sizeof *cdf * n);
    float *map = malloc(sizeof *map * n);
    vImagePixelCount total = s->width * s->height;
    for (int c = 0; c < f.ch; c++) {
        if (f.ch == 4 && c == 0 && (flags & kvImageLeaveAlphaUnchanged)) {
            float id[256];
            if (eight) { for (int i = 0; i < 256; i++) id[i] = (float)i; apply_map(s, d, f, c, id, 256, 0, 255); }
            else for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++)
                vwr(vrowm(d, (long)y), (long)(x * 4), f.t, vrd(vrow(s, (long)y), (long)(x * 4), f.t));
            continue;
        }
        hist(s, f, c, n, lo, hi, h);
        vImagePixelCount run = 0;
        for (unsigned i = 0; i < n; i++) { run += h[i]; cdf[i] = run; }
        unsigned first = 0, last = n - 1;
        while (first < n - 1 && !h[first]) first++;
        while (last > 0 && !h[last]) last--;
        for (unsigned i = 0; i < n; i++) {
            float v = bin_value(i, n, lo, hi, eight), t;
            switch (op) {
            case H_EQUALIZE: {
                vImagePixelCount c0 = cdf[first];
                t = total > c0 ? (float)(cdf[i] > c0 ? cdf[i] - c0 : 0) / (float)(total - c0) : 0;
                map[i] = lo + t * (hi - lo);
                break;
            }
            case H_STRETCH: case H_ENDS: {
                unsigned a = first, b = last;
                if (op == H_ENDS) {
                    double pl = (low ? low[c] : 0) / 100.0, ph = (high ? high[c] : 0) / 100.0;
                    a = 0; while (a < n - 1 && cdf[a] < pl * total) a++;
                    b = n - 1; while (b > 0 && (double)(total - cdf[b - 1]) <= ph * total && b > a) b--;
                }
                float va = bin_value(a, n, lo, hi, eight), vb = bin_value(b, n, lo, hi, eight);
                map[i] = vb > va ? lo + (v - va) / (vb - va) * (hi - lo) : v;
                break;
            }
            default: {   /* specification: the bin of the desired histogram whose CDF first reaches this one's */
                const vImagePixelCount *want = desired[c];
                vImagePixelCount wt = 0; for (unsigned k = 0; k < n; k++) wt += want[k];
                double p = total ? (double)cdf[i] / total : 0, acc = 0;
                unsigned k = 0;
                for (; k < n - 1; k++) { acc += wt ? (double)want[k] / wt : 0; if (acc >= p - 1e-12) break; }
                map[i] = bin_value(k, n, lo, hi, eight);
            }
            }
        }
        apply_map(s, d, f, c, map, n, lo, hi);
    }
    free(h); free(cdf); free(map);
    return kvImageNoError;
}
vImage_Error vImageEqualization_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return hist_op(src, dest, VF(1, VT_U8), H_EQUALIZE, 0, 0, 0, NULL, NULL, NULL, flags); }
vImage_Error vImageEqualization_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return hist_op(src, dest, VF(4, VT_U8), H_EQUALIZE, 0, 0, 0, NULL, NULL, NULL, flags); }
vImage_Error vImageEqualization_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, unsigned int histogram_entries,
                                        Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    return hist_op(src, dest, VF(1, VT_F32), H_EQUALIZE, histogram_entries, minVal, maxVal, NULL, NULL, NULL, flags);
}
vImage_Error vImageEqualization_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, unsigned int histogram_entries,
                                         Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    return hist_op(src, dest, VF(4, VT_F32), H_EQUALIZE, histogram_entries, minVal, maxVal, NULL, NULL, NULL, flags);
}
vImage_Error vImageContrastStretch_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return hist_op(src, dest, VF(1, VT_U8), H_STRETCH, 0, 0, 0, NULL, NULL, NULL, flags); }
vImage_Error vImageContrastStretch_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return hist_op(src, dest, VF(4, VT_U8), H_STRETCH, 0, 0, 0, NULL, NULL, NULL, flags); }
vImage_Error vImageContrastStretch_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, unsigned int histogram_entries,
                                           Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    return hist_op(src, dest, VF(1, VT_F32), H_STRETCH, histogram_entries, minVal, maxVal, NULL, NULL, NULL, flags);
}
vImage_Error vImageContrastStretch_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, unsigned int histogram_entries,
                                            Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    return hist_op(src, dest, VF(4, VT_F32), H_STRETCH, histogram_entries, minVal, maxVal, NULL, NULL, NULL, flags);
}
vImage_Error vImageEndsInContrastStretch_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, unsigned int percent_low,
                                                 unsigned int percent_high, vImage_Flags flags) {
    if (percent_low + percent_high > 100) return kvImageInvalidParameter;
    return hist_op(src, dest, VF(1, VT_U8), H_ENDS, 0, 0, 0, &percent_low, &percent_high, NULL, flags);
}
vImage_Error vImageEndsInContrastStretch_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const unsigned int percent_low[4],
                                                  const unsigned int percent_high[4], vImage_Flags flags) {
    if (!percent_low || !percent_high) return kvImageNullPointerArgument;
    for (int i = 0; i < 4; i++) if (percent_low[i] + percent_high[i] > 100) return kvImageInvalidParameter;
    return hist_op(src, dest, VF(4, VT_U8), H_ENDS, 0, 0, 0, percent_low, percent_high, NULL, flags);
}
vImage_Error vImageEndsInContrastStretch_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, unsigned int percent_low,
                                                 unsigned int percent_high, unsigned int histogram_entries, Pixel_F minVal, Pixel_F maxVal,
                                                 vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (percent_low + percent_high > 100) return kvImageInvalidParameter;
    return hist_op(src, dest, VF(1, VT_F32), H_ENDS, histogram_entries, minVal, maxVal, &percent_low, &percent_high, NULL, flags);
}
vImage_Error vImageEndsInContrastStretch_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer,
                                                  const unsigned int percent_low[4], const unsigned int percent_high[4],
                                                  unsigned int histogram_entries, Pixel_F minVal, Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!percent_low || !percent_high) return kvImageNullPointerArgument;
    return hist_op(src, dest, VF(4, VT_F32), H_ENDS, histogram_entries, minVal, maxVal, percent_low, percent_high, NULL, flags);
}
vImage_Error vImageHistogramSpecification_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImagePixelCount *desired_histogram,
                                                  vImage_Flags flags) {
    if (!desired_histogram) return kvImageNullPointerArgument;
    const vImagePixelCount *d[4] = { desired_histogram };
    return hist_op(src, dest, VF(1, VT_U8), H_SPECIFY, 0, 0, 0, NULL, NULL, d, flags);
}
vImage_Error vImageHistogramSpecification_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImagePixelCount *desired_histogram[4],
                                                   vImage_Flags flags) {
    if (!desired_histogram) return kvImageNullPointerArgument;
    for (int i = (flags & kvImageLeaveAlphaUnchanged) ? 1 : 0; i < 4; i++) if (!desired_histogram[i]) return kvImageNullPointerArgument;
    return hist_op(src, dest, VF(4, VT_U8), H_SPECIFY, 0, 0, 0, NULL, NULL, desired_histogram, flags);
}
vImage_Error vImageHistogramSpecification_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer,
                                                  const vImagePixelCount *desired_histogram, unsigned int histogram_entries, Pixel_F minVal,
                                                  Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!desired_histogram) return kvImageNullPointerArgument;
    const vImagePixelCount *d[4] = { desired_histogram };
    return hist_op(src, dest, VF(1, VT_F32), H_SPECIFY, histogram_entries, minVal, maxVal, NULL, NULL, d, flags);
}
vImage_Error vImageHistogramSpecification_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer,
                                                   const vImagePixelCount *desired_histogram[4], unsigned int histogram_entries, Pixel_F minVal,
                                                   Pixel_F maxVal, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!desired_histogram) return kvImageNullPointerArgument;
    return hist_op(src, dest, VF(4, VT_F32), H_SPECIFY, histogram_entries, minVal, maxVal, NULL, NULL, desired_histogram, flags);
}

/* ---- alpha ---- */

/* interleaved: alpha at index `ai` (0 for ARGB/BGRA, 3 for RGBA) */
static vImage_Error premul_inter(const vImage_Buffer *s, const vImage_Buffer *d, vt_t t, int ai, int unpremul) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    float one = vt_one(t);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4]; vget(s, VF(4, t), (long)x, (long)y, p);
        float a = p[ai] / one;
        for (int c = 0; c < 4; c++) if (c != ai) p[c] = unpremul ? (a > 0 ? (t == VT_U8 || t == VT_U16 ? fminf(p[c] / a, one) : p[c] / a) : 0) : p[c] * a;
        vput(d, VF(4, t), (long)x, (long)y, p);
    }
    return kvImageNoError;
}
#define PREMUL(name, t, ai) \
    vImage_Error vImagePremultiplyData_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return premul_inter(src, dest, t, ai, 0); } \
    vImage_Error vImageUnpremultiplyData_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return premul_inter(src, dest, t, ai, 1); }
PREMUL(ARGB8888, VT_U8, 0) PREMUL(RGBA8888, VT_U8, 3) PREMUL(ARGBFFFF, VT_F32, 0) PREMUL(RGBAFFFF, VT_F32, 3)
PREMUL(ARGB16U, VT_U16, 0) PREMUL(RGBA16U, VT_U16, 3) PREMUL(ARGB16Q12, VT_Q12, 0) PREMUL(RGBA16Q12, VT_Q12, 3) PREMUL(RGBA16F, VT_F16, 3)

static vImage_Error premul_planar(const vImage_Buffer *s, const vImage_Buffer *alpha, const vImage_Buffer *d, vt_t t, int unpremul) {
    vImage_Error e = vsame(s, d);
    if (e || (e = vsame(alpha, d))) return e;
    float one = vt_one(t);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float v = vrd(vrow(s, (long)y), (long)x, t), a = vrd(vrow(alpha, (long)y), (long)x, t) / one;
        vwr(vrowm(d, (long)y), (long)x, t, unpremul ? (a > 0 ? (t == VT_U8 ? fminf(v / a, one) : v / a) : 0) : v * a);
    }
    return kvImageNoError;
}
vImage_Error vImagePremultiplyData_Planar8(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) { return premul_planar(src, alpha, dest, VT_U8, 0); }
vImage_Error vImagePremultiplyData_PlanarF(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) { return premul_planar(src, alpha, dest, VT_F32, 0); }
vImage_Error vImageUnpremultiplyData_Planar8(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) { return premul_planar(src, alpha, dest, VT_U8, 1); }
vImage_Error vImageUnpremultiplyData_PlanarF(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) { return premul_planar(src, alpha, dest, VT_F32, 1); }

/* compositing a top image over a bottom one; modes: 0 nonpremultiplied, 1 nonpremultiplied top over premultiplied bottom,
   2 premultiplied, 3 premultiplied with a constant alpha; blend modes for RGBA8888 below */
static void composite(float *top, const float *bot, int ai, int mode, float k, float one) {
    float ta = top[ai] / one, ba = bot[ai] / one, ra = ta + ba * (1 - ta);
    for (int c = 0; c < 4; c++) {
        if (c == ai) continue;
        switch (mode) {
        case 0: top[c] = ra > 0 ? (top[c] * ta + bot[c] * ba * (1 - ta)) / ra : 0; break;
        case 1: top[c] = top[c] * ta + bot[c] * (1 - ta); break;
        case 2: top[c] = top[c] + bot[c] * (1 - ta); break;
        default: top[c] = top[c] * k + bot[c] * (1 - ta * k);
        }
    }
    if (mode == 3) ra = ta * k + ba * (1 - ta * k);
    top[ai] = ra * one;
}
static vImage_Error blend_inter(const vImage_Buffer *t, const vImage_Buffer *b, const vImage_Buffer *d, vt_t ty, int ai, int mode, float k) {
    vImage_Error e = vsame(t, d);
    if (e || (e = vsame(b, d))) return e;
    float one = vt_one(ty);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], q[4]; vget(t, VF(4, ty), (long)x, (long)y, p); vget(b, VF(4, ty), (long)x, (long)y, q);
        composite(p, q, ai, mode, k, one);
        vput(d, VF(4, ty), (long)x, (long)y, p);
    }
    return kvImageNoError;
}
vImage_Error vImageAlphaBlend_ARGB8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_U8, 0, 0, 1); }
vImage_Error vImageAlphaBlend_ARGBFFFF(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_F32, 0, 0, 1); }
vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGB8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_U8, 0, 1, 1); }
vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGBFFFF(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_F32, 0, 1, 1); }
vImage_Error vImagePremultipliedAlphaBlend_ARGB8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_U8, 0, 2, 1); }
vImage_Error vImagePremultipliedAlphaBlend_BGRA8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_U8, 3, 2, 1); }
vImage_Error vImagePremultipliedAlphaBlend_ARGBFFFF(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_F32, 0, 2, 1); }
vImage_Error vImagePremultipliedAlphaBlend_BGRAFFFF(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_inter(srcTop, srcBottom, dest, VT_F32, 3, 2, 1); }
vImage_Error vImagePremultipliedConstAlphaBlend_ARGB8888(const vImage_Buffer *srcTop, Pixel_8 constAlpha, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_inter(srcTop, srcBottom, dest, VT_U8, 0, 3, constAlpha / 255.f);
}
vImage_Error vImagePremultipliedConstAlphaBlend_ARGBFFFF(const vImage_Buffer *srcTop, Pixel_F constAlpha, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_inter(srcTop, srcBottom, dest, VT_F32, 0, 3, constAlpha);
}
/* the RGBA8888 blend modes over premultiplied pixels */
static vImage_Error blend_mode(const vImage_Buffer *t, const vImage_Buffer *b, const vImage_Buffer *d, int mode) {
    vImage_Error e = vsame(t, d);
    if (e || (e = vsame(b, d))) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], q[4], o[4]; vget(t, VF(4, VT_U8), (long)x, (long)y, p); vget(b, VF(4, VT_U8), (long)x, (long)y, q);
        float ta = p[3] / 255, ba = q[3] / 255;
        for (int c = 0; c < 3; c++) {
            float s = p[c] / 255, dd = q[c] / 255, r;
            switch (mode) {
            case 0: r = s * dd + s * (1 - ba) + dd * (1 - ta); break;            /* multiply */
            case 1: r = s + dd - s * dd; break;                                    /* screen */
            case 2: r = fminf(s * ba, dd * ta) + s * (1 - ba) + dd * (1 - ta); break;   /* darken */
            default: r = fmaxf(s * ba, dd * ta) + s * (1 - ba) + dd * (1 - ta);       /* lighten */
            }
            o[c] = r * 255;
        }
        o[3] = (ta + ba - ta * ba) * 255;
        vput(d, VF(4, VT_U8), (long)x, (long)y, o);
    }
    return kvImageNoError;
}
vImage_Error vImagePremultipliedAlphaBlendMultiply_RGBA8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_mode(srcTop, srcBottom, dest, 0); }
vImage_Error vImagePremultipliedAlphaBlendScreen_RGBA8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_mode(srcTop, srcBottom, dest, 1); }
vImage_Error vImagePremultipliedAlphaBlendDarken_RGBA8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_mode(srcTop, srcBottom, dest, 2); }
vImage_Error vImagePremultipliedAlphaBlendLighten_RGBA8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) { return blend_mode(srcTop, srcBottom, dest, 3); }

/* the top image's channels permuted, then blended over the bottom one (premultiplied), alpha optionally made opaque */
static vImage_Error blend_permute(const vImage_Buffer *t, const vImage_Buffer *b, const vImage_Buffer *d, const uint8_t *map, bool makeOpaque, int ai) {
    vImage_Error e = vsame(t, d);
    if (e || (e = vsame(b, d))) return e;
    if (!map) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], q[4], r[4]; vget(t, VF(4, VT_U8), (long)x, (long)y, p); vget(b, VF(4, VT_U8), (long)x, (long)y, q);
        for (int c = 0; c < 4; c++) r[c] = p[map[c] & 3];
        composite(r, q, ai, 2, 1, 255);
        if (makeOpaque) r[ai] = 255;
        vput(d, VF(4, VT_U8), (long)x, (long)y, r);
    }
    return kvImageNoError;
}
vImage_Error vImagePremultipliedAlphaBlendWithPermute_ARGB8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest,
                                                               const uint8_t permuteMap[4], bool makeDestAlphaOpaque, vImage_Flags flags) {
    return blend_permute(srcTop, srcBottom, dest, permuteMap, makeDestAlphaOpaque, 0);
}
vImage_Error vImagePremultipliedAlphaBlendWithPermute_RGBA8888(const vImage_Buffer *srcTop, const vImage_Buffer *srcBottom, const vImage_Buffer *dest,
                                                               const uint8_t permuteMap[4], bool makeDestAlphaOpaque, vImage_Flags flags) {
    return blend_permute(srcTop, srcBottom, dest, permuteMap, makeDestAlphaOpaque, 3);
}

/* planar compositing: each image with its alpha plane */
static vImage_Error blend_planar(const vImage_Buffer *top, const vImage_Buffer *topA, const vImage_Buffer *bot, const vImage_Buffer *botA,
                                 const vImage_Buffer *alpha, const vImage_Buffer *d, vt_t t, int mode, float k) {
    vImage_Error e = vsame(top, d);
    if (e || (e = vsame(bot, d)) || (topA && (e = vsame(topA, d))) || (botA && (e = vsame(botA, d))) || (alpha && (e = vsame(alpha, d)))) return e;
    float one = vt_one(t);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        long X = (long)x, Y = (long)y;
        float s = vrd(vrow(top, Y), X, t), b = vrd(vrow(bot, Y), X, t);
        float ta = topA ? vrd(vrow(topA, Y), X, t) / one : 1, r;
        switch (mode) {
        case 0: {
            float ba = botA ? vrd(vrow(botA, Y), X, t) / one : 1, ra = alpha ? vrd(vrow(alpha, Y), X, t) / one : ta + ba * (1 - ta);
            r = ra > 0 ? (s * ta + b * ba * (1 - ta)) / ra : 0; break;
        }
        case 1: r = s * ta + b * (1 - ta); break;
        case 2: r = s + b * (1 - ta); break;
        default: r = s * k + b * (1 - ta * k);
        }
        vwr(vrowm(d, Y), X, t, r);
    }
    return kvImageNoError;
}
vImage_Error vImageAlphaBlend_Planar8(const vImage_Buffer *srcTop, const vImage_Buffer *srcTopAlpha, const vImage_Buffer *srcBottom,
                                      const vImage_Buffer *srcBottomAlpha, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, srcBottomAlpha, alpha, dest, VT_U8, 0, 1);
}
vImage_Error vImageAlphaBlend_PlanarF(const vImage_Buffer *srcTop, const vImage_Buffer *srcTopAlpha, const vImage_Buffer *srcBottom,
                                      const vImage_Buffer *srcBottomAlpha, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, srcBottomAlpha, alpha, dest, VT_F32, 0, 1);
}
vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_Planar8(const vImage_Buffer *srcTop, const vImage_Buffer *srcTopAlpha,
                                                                      const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, NULL, NULL, dest, VT_U8, 1, 1);
}
vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_PlanarF(const vImage_Buffer *srcTop, const vImage_Buffer *srcTopAlpha,
                                                                      const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, NULL, NULL, dest, VT_F32, 1, 1);
}
vImage_Error vImagePremultipliedAlphaBlend_Planar8(const vImage_Buffer *srcTop, const vImage_Buffer *srcTopAlpha, const vImage_Buffer *srcBottom,
                                                   const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, NULL, NULL, dest, VT_U8, 2, 1);
}
vImage_Error vImagePremultipliedAlphaBlend_PlanarF(const vImage_Buffer *srcTop, const vImage_Buffer *srcTopAlpha, const vImage_Buffer *srcBottom,
                                                   const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, NULL, NULL, dest, VT_F32, 2, 1);
}
vImage_Error vImagePremultipliedConstAlphaBlend_Planar8(const vImage_Buffer *srcTop, Pixel_8 constAlpha, const vImage_Buffer *srcTopAlpha,
                                                        const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, NULL, NULL, dest, VT_U8, 3, constAlpha / 255.f);
}
vImage_Error vImagePremultipliedConstAlphaBlend_PlanarF(const vImage_Buffer *srcTop, Pixel_F constAlpha, const vImage_Buffer *srcTopAlpha,
                                                        const vImage_Buffer *srcBottom, const vImage_Buffer *dest, vImage_Flags flags) {
    return blend_planar(srcTop, srcTopAlpha, srcBottom, NULL, NULL, dest, VT_F32, 3, constAlpha);
}

/* flattening over an opaque background colour */
static vImage_Error flatten(const vImage_Buffer *s, const vImage_Buffer *d, vt_t t, int ai, int out_ch, const float *bg, bool premul) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    float one = vt_one(t);
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4], o[4]; vget(s, VF(4, t), (long)x, (long)y, p);
        float a = p[ai] / one;
        int k = 0;
        for (int c = 0; c < 4; c++) {
            if (c == ai) continue;
            o[k++] = (premul ? p[c] : p[c] * a) + bg[c] * (1 - a);
        }
        if (out_ch == 4) {   /* in place of the input's layout */
            float r[4]; k = 0;
            for (int c = 0; c < 4; c++) r[c] = c == ai ? one : o[k++];
            vput(d, VF(4, t), (long)x, (long)y, r);
        } else vput(d, VF(3, t), (long)x, (long)y, o);
    }
    return kvImageNoError;
}
#define FLATTEN(name, t, T, ai, outch) \
    vImage_Error vImageFlatten_##name(const vImage_Buffer *argbSrc, const vImage_Buffer *argbDst, const T *backgroundColor, bool isImagePremultiplied, vImage_Flags flags) { \
        float bg[4]; VBG_MULTI_PX(bg, VF(4, t), backgroundColor); return flatten(argbSrc, argbDst, t, ai, outch, bg, isImagePremultiplied); }
FLATTEN(ARGB8888, VT_U8, uint8_t, 0, 4) FLATTEN(RGBA8888, VT_U8, uint8_t, 3, 4) FLATTEN(ARGBFFFF, VT_F32, float, 0, 4)
FLATTEN(RGBAFFFF, VT_F32, float, 3, 4) FLATTEN(ARGB16U, VT_U16, uint16_t, 0, 4) FLATTEN(RGBA16U, VT_U16, uint16_t, 3, 4)
FLATTEN(ARGB16Q12, VT_Q12, int16_t, 0, 4) FLATTEN(RGBA16Q12, VT_Q12, int16_t, 3, 4)
FLATTEN(ARGB8888ToRGB888, VT_U8, uint8_t, 0, 3) FLATTEN(RGBA8888ToRGB888, VT_U8, uint8_t, 3, 3) FLATTEN(BGRA8888ToRGB888, VT_U8, uint8_t, 3, 3)
FLATTEN(ARGBFFFFToRGBFFF, VT_F32, float, 0, 3) FLATTEN(RGBAFFFFToRGBFFF, VT_F32, float, 3, 3) FLATTEN(BGRAFFFFToRGBFFF, VT_F32, float, 3, 3)

/* the colour channels clipped to alpha */
static vImage_Error clip_alpha(const vImage_Buffer *s, const vImage_Buffer *d, vt_t t, int ai) {
    vImage_Error e = vsame(s, d);
    if (e) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float p[4]; vget(s, VF(4, t), (long)x, (long)y, p);
        for (int c = 0; c < 4; c++) if (c != ai && p[c] > p[ai]) p[c] = p[ai];
        vput(d, VF(4, t), (long)x, (long)y, p);
    }
    return kvImageNoError;
}
vImage_Error vImageClipToAlpha_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return clip_alpha(src, dest, VT_U8, 0); }
vImage_Error vImageClipToAlpha_RGBA8888(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return clip_alpha(src, dest, VT_U8, 3); }
vImage_Error vImageClipToAlpha_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return clip_alpha(src, dest, VT_F32, 0); }
vImage_Error vImageClipToAlpha_RGBAFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { return clip_alpha(src, dest, VT_F32, 3); }
static vImage_Error clip_alpha_planar(const vImage_Buffer *s, const vImage_Buffer *a, const vImage_Buffer *d, vt_t t) {
    vImage_Error e = vsame(s, d);
    if (e || (e = vsame(a, d))) return e;
    for (vImagePixelCount y = 0; y < d->height; y++) for (vImagePixelCount x = 0; x < d->width; x++) {
        float v = vrd(vrow(s, (long)y), (long)x, t), al = vrd(vrow(a, (long)y), (long)x, t);
        vwr(vrowm(d, (long)y), (long)x, t, v > al ? al : v);
    }
    return kvImageNoError;
}
vImage_Error vImageClipToAlpha_Planar8(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) { return clip_alpha_planar(src, alpha, dest, VT_U8); }
vImage_Error vImageClipToAlpha_PlanarF(const vImage_Buffer *src, const vImage_Buffer *alpha, const vImage_Buffer *dest, vImage_Flags flags) { return clip_alpha_planar(src, alpha, dest, VT_F32); }

vImage_Error vImageClip_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, Pixel_F maxFloat, Pixel_F minFloat, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const float *s = (const float *)vrow(src, (long)y); float *d = (float *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) d[x] = s[x] < minFloat ? minFloat : s[x] > maxFloat ? maxFloat : s[x];
    }
    return kvImageNoError;
}

/* ---- colour matrices: each pixel a row vector times the matrix (inputs down the rows, outputs across) ---- */

static vImage_Error matmul(const vImage_Buffer *const *srcs, const vImage_Buffer *const *dests, int ns, int nd, int inter_s, int inter_d,
                           vt_t t, const float *m, float div, const float *pre, const float *post) {
    if (!srcs || !dests || !m) return kvImageNullPointerArgument;
    const vImage_Buffer *ref = dests[0];
    if (!ref) return kvImageNullPointerArgument;
    for (int i = 0; i < (inter_s ? 1 : ns); i++) { vImage_Error e = vsame(srcs[i], ref); if (e) return e; }
    for (int i = 0; i < (inter_d ? 1 : nd); i++) { vImage_Error e = vcheck2(dests[i], ref); if (e) return e; }
    for (vImagePixelCount y = 0; y < ref->height; y++) for (vImagePixelCount x = 0; x < ref->width; x++) {
        float in[16], out[16];
        for (int i = 0; i < ns; i++) {
            float v = inter_s ? vrd(vrow(srcs[0], (long)y), (long)(x * (size_t)ns) + i, t) : vrd(vrow(srcs[i], (long)y), (long)x, t);
            in[i] = v + (pre ? pre[i] : 0);
        }
        for (int j = 0; j < nd; j++) {
            float acc = 0;
            for (int i = 0; i < ns; i++) acc += in[i] * m[i * nd + j];
            out[j] = (acc + (post ? post[j] : 0)) / div;
        }
        for (int j = 0; j < nd; j++) {
            if (inter_d) vwr(vrowm(dests[0], (long)y), (long)(x * (size_t)nd) + j, t, out[j]);
            else vwr(vrowm(dests[j], (long)y), (long)x, t, out[j]);
        }
    }
    return kvImageNoError;
}
static float *ints(const int16_t *a, int n) { if (!a) return NULL; float *o = malloc(sizeof(float) * (size_t)n); for (int i = 0; i < n; i++) o[i] = a[i]; return o; }
static float *ints32(const int32_t *a, int n) { if (!a) return NULL; float *o = malloc(sizeof(float) * (size_t)n); for (int i = 0; i < n; i++) o[i] = (float)a[i]; return o; }

vImage_Error vImageMatrixMultiply_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const int16_t matrix[16], int32_t divisor,
                                           const int16_t *pre_bias, const int32_t *post_bias, vImage_Flags flags) {
    if (!divisor) return kvImageInvalidParameter;
    float *m = ints(matrix, 16), *pre = ints(pre_bias, 4), *post = ints32(post_bias, 4);
    const vImage_Buffer *s[1] = { src }, *d[1] = { dest };
    vImage_Error e = matmul(s, d, 4, 4, 1, 1, VT_U8, m, (float)divisor, pre, post);
    free(m); free(pre); free(post);
    return e;
}
vImage_Error vImageMatrixMultiply_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, const float matrix[16], const float *pre_bias,
                                           const float *post_bias, vImage_Flags flags) {
    const vImage_Buffer *s[1] = { src }, *d[1] = { dest };
    return matmul(s, d, 4, 4, 1, 1, VT_F32, matrix, 1, pre_bias, post_bias);
}
vImage_Error vImageMatrixMultiply_ARGB8888ToPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const int16_t matrix[4], int32_t divisor,
                                                    const int16_t pre_bias[4], int32_t post_bias, vImage_Flags flags) {
    if (!divisor) return kvImageInvalidParameter;
    float *m = ints(matrix, 4), *pre = ints(pre_bias, 4), post = (float)post_bias;
    const vImage_Buffer *s[1] = { src }, *d[1] = { dest };
    vImage_Error e = matmul(s, d, 4, 1, 1, 1, VT_U8, m, (float)divisor, pre, &post);
    free(m); free(pre);
    return e;
}
vImage_Error vImageMatrixMultiply_ARGBFFFFToPlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, const float matrix[4], const float pre_bias[4],
                                                    float post_bias, vImage_Flags flags) {
    const vImage_Buffer *s[1] = { src }, *d[1] = { dest };
    return matmul(s, d, 4, 1, 1, 1, VT_F32, matrix, 1, pre_bias, &post_bias);
}
vImage_Error vImageMatrixMultiply_Planar8(const vImage_Buffer *srcs[], const vImage_Buffer *dests[], uint32_t src_planes, uint32_t dest_planes,
                                          const int16_t matrix[], int32_t divisor, const int16_t *pre_bias, const int32_t *post_bias, vImage_Flags flags) {
    if (!divisor || !src_planes || !dest_planes || src_planes > 16 || dest_planes > 16) return kvImageInvalidParameter;
    float *m = ints(matrix, (int)(src_planes * dest_planes)), *pre = ints(pre_bias, (int)src_planes), *post = ints32(post_bias, (int)dest_planes);
    vImage_Error e = matmul(srcs, dests, (int)src_planes, (int)dest_planes, 0, 0, VT_U8, m, (float)divisor, pre, post);
    free(m); free(pre); free(post);
    return e;
}
vImage_Error vImageMatrixMultiply_Planar16S(const vImage_Buffer *srcs[], const vImage_Buffer *dests[], uint32_t src_planes, uint32_t dest_planes,
                                            const int16_t matrix[], int32_t divisor, const int16_t *pre_bias, const int32_t *post_bias, vImage_Flags flags) {
    if (!divisor || !src_planes || !dest_planes || src_planes > 16 || dest_planes > 16) return kvImageInvalidParameter;
    float *m = ints(matrix, (int)(src_planes * dest_planes)), *pre = ints(pre_bias, (int)src_planes), *post = ints32(post_bias, (int)dest_planes);
    vImage_Error e = matmul(srcs, dests, (int)src_planes, (int)dest_planes, 0, 0, VT_S16, m, (float)divisor, pre, post);
    free(m); free(pre); free(post);
    return e;
}
vImage_Error vImageMatrixMultiply_PlanarF(const vImage_Buffer *srcs[], const vImage_Buffer *dests[], uint32_t src_planes, uint32_t dest_planes,
                                          const float matrix[], const float *pre_bias, const float *post_bias, vImage_Flags flags) {
    if (!src_planes || !dest_planes || src_planes > 16 || dest_planes > 16) return kvImageInvalidParameter;
    return matmul(srcs, dests, (int)src_planes, (int)dest_planes, 0, 0, VT_F32, matrix, 1, pre_bias, post_bias);
}

/* ---- lookup tables ---- */

vImage_Error vImageTableLookUp_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 table[256], vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!table) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const uint8_t *s = vrow(src, (long)y); uint8_t *d = vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) d[x] = table[s[x]];
    }
    return kvImageNoError;
}
vImage_Error vImageTableLookUp_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 alphaTable[256],
                                        const Pixel_8 redTable[256], const Pixel_8 greenTable[256], const Pixel_8 blueTable[256], vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    const Pixel_8 *t[4] = { alphaTable, redTable, greenTable, blueTable };   /* a NULL table leaves its channel unchanged */
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const uint8_t *s = vrow(src, (long)y); uint8_t *d = vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width * 4; x++) d[x] = t[x & 3] ? t[x & 3][s[x]] : s[x];
    }
    return kvImageNoError;
}
#define LUT8(name, OUT, outsize) \
    vImage_Error vImageLookupTable_##name(const vImage_Buffer *src, const vImage_Buffer *dest, const OUT *table, vImage_Flags flags) { \
        vImage_Error e = vsame(src, dest); if (e) return e; if (!table) return kvImageNullPointerArgument; \
        for (vImagePixelCount y = 0; y < dest->height; y++) { \
            const uint8_t *s = vrow(src, (long)y); uint8_t *d = vrowm(dest, (long)y); \
            for (vImagePixelCount x = 0; x < dest->width; x++) memcpy(d + x * (outsize), (const uint8_t *)table + s[x] * sizeof(OUT), (outsize)); } \
        return kvImageNoError; }
LUT8(Planar8toPlanarF, Pixel_F, 4) LUT8(Planar8toPlanar16, Pixel_16U, 2) LUT8(Planar8toPlanar24, uint32_t, 3)
LUT8(Planar8toPlanar48, uint64_t, 6) LUT8(Planar8toPlanar96, Pixel_FFFF, 12) LUT8(Planar8toPlanar128, Pixel_FFFF, 16)
LUT8(8to64U, uint64_t, 8)
vImage_Error vImageLookupTable_Planar16(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_16U table[65536], vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!table) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const uint16_t *s = (const uint16_t *)vrow(src, (long)y); uint16_t *d = (uint16_t *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) d[x] = table[s[x]];
    }
    return kvImageNoError;
}
/* floats in [0, 1] index a 4096-entry table */
vImage_Error vImageLookupTable_PlanarFtoPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_8 table[4096], vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!table) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const float *s = (const float *)vrow(src, (long)y); uint8_t *d = vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) { float v = s[x] != s[x] ? 0 : vclampf(s[x], 0, 1); d[x] = table[(int)lrintf(v * 4095)]; }
    }
    return kvImageNoError;
}
/* a table spanning [minFloat, maxFloat], linearly interpolated */
vImage_Error vImageInterpolatedLookupTable_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, const Pixel_F *table,
                                                   vImagePixelCount tableEntries, Pixel_F maxFloat, Pixel_F minFloat, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!table) return kvImageNullPointerArgument;
    if (tableEntries < 2 || !(maxFloat > minFloat)) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const float *s = (const float *)vrow(src, (long)y); float *d = (float *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) {
            float p = (vclampf(s[x], minFloat, maxFloat) - minFloat) / (maxFloat - minFloat) * (float)(tableEntries - 1);
            long i = (long)p; if (i >= (long)tableEntries - 1) i = (long)tableEntries - 2;
            float f = p - (float)i;
            d[x] = table[i] * (1 - f) + table[i + 1] * f;
        }
    }
    return kvImageNoError;
}

/* ---- gamma ---- */

typedef struct { int type; float gamma; } vgamma;
GammaFunction vImageCreateGammaFunction(float gamma, int gamma_type, vImage_Flags flags) {
    if (gamma_type < 0 || gamma_type > kvImageGamma_BT709_reverse_half_precision) return NULL;
    vgamma *g = malloc(sizeof *g);
    g->type = gamma_type;
    static const float fixed[] = { 0, 0, 5.f / 9, 9.f / 5, 5.f / 11, 11.f / 5, 0, 0, 11.f / 9, 9.f / 11 };
    g->gamma = gamma_type <= kvImageGamma_UseGammaValue_half_precision ? gamma : gamma_type < 10 ? fixed[gamma_type] : 0;
    return g;
}
void vImageDestroyGammaFunction(GammaFunction f) { free(f); }
static float gamma_apply(const vgamma *g, float x) {
    float a = fabsf(x), s = x < 0 ? -1.f : 1.f, r;
    switch (g->type) {
    case kvImageGamma_sRGB_forward_half_precision: r = a <= 0.0031308f ? 12.92f * a : 1.055f * powf(a, 1 / 2.4f) - 0.055f; break;
    case kvImageGamma_sRGB_reverse_half_precision: r = a <= 0.04045f ? a / 12.92f : powf((a + 0.055f) / 1.055f, 2.4f); break;
    case kvImageGamma_BT709_forward_half_precision: r = a < 0.018f ? 4.5f * a : 1.099f * powf(a, 0.45f) - 0.099f; break;
    case kvImageGamma_BT709_reverse_half_precision: r = a < 0.081f ? a / 4.5f : powf((a + 0.099f) / 1.099f, 1 / 0.45f); break;
    default: r = powf(a, g->gamma);
    }
    return s * r;
}
vImage_Error vImageGamma_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, const GammaFunction gamma, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!gamma) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const float *s = (const float *)vrow(src, (long)y); float *d = (float *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) d[x] = gamma_apply(gamma, s[x]);
    }
    return kvImageNoError;
}
vImage_Error vImageGamma_Planar8toPlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, const GammaFunction gamma, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!gamma) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const uint8_t *s = vrow(src, (long)y); float *d = (float *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) d[x] = gamma_apply(gamma, s[x] / 255.f);
    }
    return kvImageNoError;
}
vImage_Error vImageGamma_PlanarFtoPlanar8(const vImage_Buffer *src, const vImage_Buffer *dest, const GammaFunction gamma, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!gamma) return kvImageNullPointerArgument;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const float *s = (const float *)vrow(src, (long)y); uint8_t *d = vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) vwr(d, (long)x, VT_U8, gamma_apply(gamma, s[x]) * 255);
    }
    return kvImageNoError;
}

/* piecewise gamma: below the boundary linear (l0 x + l1), above it (e0 x + e1)^gamma + e2; x normalized */
static float pgamma(float x, const float *ec, float gamma, const float *lc, float boundary, int symmetric) {
    float s = 1, a = x;
    if (symmetric && x < 0) { s = -1; a = -x; }
    float r = a < boundary ? lc[0] * a + lc[1] : powf(ec[0] * a + ec[1], gamma) + ec[2];
    return s * r;
}
#define PGAMMA(name, tin, tout, BT, bnorm, sym) \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const float exponentialCoeffs[3], float gamma, \
                      const float linearCoeffs[2], BT boundary, vImage_Flags flags) { \
        vImage_Error e = vsame(src, dest); if (e) return e; \
        if (!exponentialCoeffs || !linearCoeffs) return kvImageNullPointerArgument; \
        float oi = tin == VT_F32 ? 1 : vt_one(tin), oo = tout == VT_F32 ? 1 : vt_one(tout), b = (float)boundary / (bnorm); \
        for (vImagePixelCount y = 0; y < dest->height; y++) for (vImagePixelCount x = 0; x < dest->width; x++) { \
            float v = vrd(vrow(src, (long)y), (long)x, tin) / oi; \
            vwr(vrowm(dest, (long)y), (long)x, tout, pgamma(v, exponentialCoeffs, gamma, linearCoeffs, b, sym) * oo); } \
        return kvImageNoError; }
PGAMMA(vImagePiecewiseGamma_Planar8, VT_U8, VT_U8, Pixel_8, 255.f, 0)
PGAMMA(vImagePiecewiseGamma_Planar8toPlanarF, VT_U8, VT_F32, Pixel_8, 255.f, 0)
PGAMMA(vImagePiecewiseGamma_Planar8toPlanar16Q12, VT_U8, VT_Q12, Pixel_8, 255.f, 0)
PGAMMA(vImagePiecewiseGamma_PlanarF, VT_F32, VT_F32, float, 1.f, 0)
PGAMMA(vImagePiecewiseGamma_PlanarFtoPlanar8, VT_F32, VT_U8, float, 1.f, 0)
PGAMMA(vImagePiecewiseGamma_Planar16Q12, VT_Q12, VT_Q12, Pixel_16S, 4096.f, 0)
PGAMMA(vImagePiecewiseGamma_Planar16Q12toPlanar8, VT_Q12, VT_U8, Pixel_16S, 4096.f, 0)
PGAMMA(vImageSymmetricPiecewiseGamma_PlanarF, VT_F32, VT_F32, float, 1.f, 1)
PGAMMA(vImageSymmetricPiecewiseGamma_Planar16Q12, VT_Q12, VT_Q12, Pixel_16S, 4096.f, 1)

/* piecewise polynomials: boundaries[0..count], segment i uses coefficients[i] (order + 1 of them, constant first) */
static float ppoly(float x, const float *const *coeffs, const float *bounds, uint32_t order, uint32_t log2segments, int symmetric) {
    float s = 1;
    if (symmetric && x < 0) { s = -1; x = -x; }
    uint32_t n = 1u << log2segments, i = 0;
    if (x < bounds[0]) i = 0;
    else { while (i + 1 < n && x >= bounds[i + 1]) i++; }
    if (x > bounds[n]) i = n - 1;
    const float *c = coeffs[i];
    float r = 0;
    for (int k = (int)order; k >= 0; k--) r = r * x + c[k];
    return s * r;
}
#define PPOLY(name, tin, tout, sym) \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const float **coefficients, const float *boundaries, \
                      uint32_t order, uint32_t log2segments, vImage_Flags flags) { \
        vImage_Error e = vsame(src, dest); if (e) return e; \
        if (!coefficients || !boundaries) return kvImageNullPointerArgument; \
        if (log2segments > 16) return kvImageInvalidParameter; \
        float oi = tin == VT_F32 ? 1 : 255.f, oo = tout == VT_F32 ? 1 : 255.f; \
        for (vImagePixelCount y = 0; y < dest->height; y++) for (vImagePixelCount x = 0; x < dest->width; x++) { \
            float v = vrd(vrow(src, (long)y), (long)x, tin) / oi; \
            vwr(vrowm(dest, (long)y), (long)x, tout, ppoly(v, coefficients, boundaries, order, log2segments, sym) * oo); } \
        return kvImageNoError; }
PPOLY(vImagePiecewisePolynomial_PlanarF, VT_F32, VT_F32, 0)
PPOLY(vImagePiecewisePolynomial_Planar8toPlanarF, VT_U8, VT_F32, 0)
PPOLY(vImagePiecewisePolynomial_PlanarFtoPlanar8, VT_F32, VT_U8, 0)
PPOLY(vImageSymmetricPiecewisePolynomial_PlanarF, VT_F32, VT_F32, 1)

vImage_Error vImagePiecewiseRational_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, const float **topCoefficients,
                                             const float **bottomCoefficients, const float *boundaries, uint32_t topOrder, uint32_t bottomOrder,
                                             uint32_t log2segments, vImage_Flags flags) {
    vImage_Error e = vsame(src, dest);
    if (e) return e;
    if (!topCoefficients || !bottomCoefficients || !boundaries) return kvImageNullPointerArgument;
    if (log2segments > 16) return kvImageInvalidParameter;
    for (vImagePixelCount y = 0; y < dest->height; y++) {
        const float *s = (const float *)vrow(src, (long)y); float *d = (float *)vrowm(dest, (long)y);
        for (vImagePixelCount x = 0; x < dest->width; x++) {
            float t = ppoly(s[x], topCoefficients, boundaries, topOrder, log2segments, 0);
            float b = ppoly(s[x], bottomCoefficients, boundaries, bottomOrder, log2segments, 0);
            d[x] = t / b;
        }
    }
    return kvImageNoError;
}

/* ---- flood fill: 4- or 8-connected from a seed, replacing pixels equal to the seed's ---- */

static vImage_Error flood(const vImage_Buffer *b, vfmt f, long sx, long sy, const float *color, int connectivity) {
    VCHECK_BUF(b);
    if (sx < 0 || sx >= (long)b->width) return kvImageInvalidOffset_X;
    if (sy < 0 || sy >= (long)b->height) return kvImageInvalidOffset_Y;
    if (connectivity != 4 && connectivity != 8) return kvImageInvalidParameter;
    float seed[4], px[4];
    vget(b, f, sx, sy, seed);
    int same = 1;
    for (int c = 0; c < f.ch; c++) if (seed[c] != color[c]) same = 0;
    if (same) return kvImageNoError;
    size_t cap = 1024, n = 0;
    long *stack = malloc(sizeof(long) * 2 * cap);
    stack[n * 2] = sx; stack[n * 2 + 1] = sy; n++;
    while (n) {
        n--;
        long x = stack[n * 2], y = stack[n * 2 + 1];
        vget(b, f, x, y, px);
        int match = 1;
        for (int c = 0; c < f.ch; c++) if (px[c] != seed[c]) match = 0;
        if (!match) continue;
        vput(b, f, x, y, color);
        for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
            if (!dx && !dy) continue;
            if (connectivity == 4 && dx && dy) continue;
            long nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= (long)b->width || ny >= (long)b->height) continue;
            if (n == cap) { cap *= 2; stack = realloc(stack, sizeof(long) * 2 * cap); }
            stack[n * 2] = nx; stack[n * 2 + 1] = ny; n++;
        }
    }
    free(stack);
    return kvImageNoError;
}
vImage_Error vImageFloodFill_Planar8(const vImage_Buffer *srcDest, void *tempBuffer, vImagePixelCount seedX, vImagePixelCount seedY,
                                     Pixel_8 newValue, int connectivity, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    float c[4]; vbg_scalar(c, newValue);
    return flood(srcDest, VF(1, VT_U8), (long)seedX, (long)seedY, c, connectivity);
}
vImage_Error vImageFloodFill_Planar16U(const vImage_Buffer *srcDest, void *tempBuffer, vImagePixelCount seedX, vImagePixelCount seedY,
                                       Pixel_16U newValue, int connectivity, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    float c[4]; vbg_scalar(c, newValue);
    return flood(srcDest, VF(1, VT_U16), (long)seedX, (long)seedY, c, connectivity);
}
vImage_Error vImageFloodFill_ARGB8888(const vImage_Buffer *srcDest, void *tempBuffer, vImagePixelCount seedX, vImagePixelCount seedY,
                                      uint8_t *newValue, int connectivity, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!newValue) return kvImageNullPointerArgument;
    float c[4]; VBG_MULTI_PX(c, VF(4, VT_U8), newValue);
    return flood(srcDest, VF(4, VT_U8), (long)seedX, (long)seedY, c, connectivity);
}
vImage_Error vImageFloodFill_ARGB16U(const vImage_Buffer *srcDest, void *tempBuffer, vImagePixelCount seedX, vImagePixelCount seedY,
                                     uint16_t *newValue, int connectivity, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    if (!newValue) return kvImageNullPointerArgument;
    float c[4]; VBG_MULTI_PX(c, VF(4, VT_U16), newValue);
    return flood(srcDest, VF(4, VT_U16), (long)seedX, (long)seedY, c, connectivity);
}
