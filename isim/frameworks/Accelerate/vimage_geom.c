/* isim vImage: geometry. Scaling and shearing resample with a Lanczos kernel (3 lobes; 5 with
   kvImageHighQualityResampling), widened when shrinking; rotation and warps sample bilinearly (adapted: Apple's warps
   also resample with Lanczos when asked for high quality). Pixel centers sit at half-integers for scaling and at
   integers for warps, whose transforms map source coordinates to destination ones. */
#include "vimage_t.h"

float _isim_vimage_lanczos(float x, float a) {
    if (x == 0) return 1;
    if (x <= -a || x >= a) return 0;
    double px = M_PI * x;
    return (float)(a * sin(px) * sin(px / a) / (px * px));
}

/* ---- resampling filters (for the shears) ---- */

typedef void (*vkernel_fn)(const float *xArray, float *yArray, unsigned long count, void *userData);
typedef struct { uint32_t magic; float scale, width; vkernel_fn fn; void *user; } vfilter;
#define VFILTER_MAGIC 0x76464c54u

static float filter_eval(const vfilter *f, float x) {
    if (f->fn) { float y = 0; f->fn(&x, &y, 1, f->user); return y; }
    return _isim_vimage_lanczos(x, f->width);
}

ResamplingFilter vImageNewResamplingFilter(float scale, vImage_Flags flags) {
    if (!(scale > 0)) return NULL;
    vfilter *f = calloc(1, sizeof *f);
    f->magic = VFILTER_MAGIC; f->scale = scale; f->width = flags & kvImageHighQualityResampling ? 5 : 3;
    return f;
}
void vImageDestroyResamplingFilter(ResamplingFilter filter) { free(filter); }
size_t vImageGetResamplingFilterSize(float scale, vkernel_fn kernelFunc, float kernelWidth, vImage_Flags flags) { return sizeof(vfilter); }
vImage_Error vImageNewResamplingFilterForFunctionUsingBuffer(ResamplingFilter filter, float scale, vkernel_fn kernelFunc, float kernelWidth,
                                                             void *userData, vImage_Flags flags) {
    if (!filter || !kernelFunc) return kvImageNullPointerArgument;
    if (!(scale > 0) || !(kernelWidth > 0)) return kvImageInvalidParameter;
    vfilter *f = filter;
    f->magic = VFILTER_MAGIC; f->scale = scale; f->width = kernelWidth / 2; f->fn = kernelFunc; f->user = userData;
    return kvImageNoError;
}
vImagePixelCount vImageGetResamplingFilterExtent(ResamplingFilter filter, vImage_Flags flags) {
    const vfilter *f = filter;
    if (!f) return 0;
    float s = f->scale < 1 ? f->scale : 1;
    return (vImagePixelCount)ceilf(2 * f->width / s);
}

/* the weights of one output sample centred on `c` (source coordinates) */
typedef struct { long first; int n; float w[64]; } vtaps;
static void taps(vtaps *t, double c, double scale, const vfilter *filter, float a) {
    double fs = scale < 1 ? scale : 1, radius = (filter ? filter->width : a) / fs;
    if (radius > 31) { fs = (filter ? filter->width : a) / 31; radius = 31; }
    long lo = (long)ceil(c - radius), hi = (long)floor(c + radius);
    if (hi - lo + 1 > 64) hi = lo + 63;
    t->first = lo; t->n = (int)(hi - lo + 1);
    float sum = 0;
    for (int i = 0; i < t->n; i++) {
        float x = (float)((lo + i - c) * fs);
        t->w[i] = filter ? filter_eval(filter, x) : _isim_vimage_lanczos(x, a);
        sum += t->w[i];
    }
    if (sum != 0) for (int i = 0; i < t->n; i++) t->w[i] /= sum;
}

/* ---- scale ---- */

static vImage_Error scale(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return (vImage_Error)(d->width * s->height * f.ch * sizeof(float));
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (!s->width || !s->height || !d->width || !d->height) return kvImageInvalidParameter;
    float a = flags & kvImageHighQualityResampling ? 5 : 3;
    long sw = (long)s->width, sh = (long)s->height, dw = (long)d->width, dh = (long)d->height, ch = f.ch;
    float *tmp = malloc(sizeof(float) * (size_t)(dw * sh * ch));
    if (!tmp) return kvImageMemoryAllocationError;
    double sx = (double)dw / sw, sy = (double)dh / sh;
    vtaps t;
    for (long x = 0; x < dw; x++) {
        taps(&t, (x + 0.5) / sx - 0.5, sx, NULL, a);
        for (long y = 0; y < sh; y++) {
            const uint8_t *r = vrow(s, y);
            float acc[4] = { 0 };
            for (int i = 0; i < t.n; i++) {
                long xi = t.first + i; xi = xi < 0 ? 0 : xi >= sw ? sw - 1 : xi;
                for (int c = 0; c < ch; c++) acc[c] += t.w[i] * vrd(r, xi * ch + c, f.t);
            }
            for (int c = 0; c < ch; c++) tmp[(y * dw + x) * ch + c] = acc[c];
        }
    }
    for (long y = 0; y < dh; y++) {
        taps(&t, (y + 0.5) / sy - 0.5, sy, NULL, a);
        uint8_t *r = vrowm(d, y);
        for (long x = 0; x < dw; x++) {
            float acc[4] = { 0 };
            for (int i = 0; i < t.n; i++) {
                long yi = t.first + i; yi = yi < 0 ? 0 : yi >= sh ? sh - 1 : yi;
                for (int c = 0; c < ch; c++) acc[c] += t.w[i] * tmp[(yi * dw + x) * ch + c];
            }
            for (int c = 0; c < ch; c++) vwr(r, x * ch + c, f.t, acc[c]);
        }
    }
    free(tmp);
    return kvImageNoError;
}
#define SCALE(name, ch, t, T) \
    vImage_Error vImageScale_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags) { \
        return scale(src, dest, VF(ch, t), flags); }
#define SCALE_P(name, ch, t, T) SCALE(name, ch, t, T)
VFORMATS_PLANAR(SCALE_P) VFORMATS_MULTI(SCALE)

/* ---- reflection, quarter turns ---- */

static vImage_Error reflect(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, int horizontal) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->width != d->width || s->height != d->height) return kvImageBufferSizeMismatch;
    long w = (long)d->width, h = (long)d->height;
    size_t B = vf_bytes(f);
    uint8_t *line = malloc((size_t)w * B);
    if (!line) return kvImageMemoryAllocationError;
    for (long y = 0; y < (horizontal ? h : (h + 1) / 2); y++) {
        if (horizontal) {
            memcpy(line, vrow(s, y), (size_t)w * B);
            uint8_t *r = vrowm(d, y);
            for (long x = 0; x < w; x++) memcpy(r + x * B, line + (w - 1 - x) * B, B);
        } else {
            long y2 = h - 1 - y;
            memcpy(line, vrow(s, y), (size_t)w * B);
            memmove(vrowm(d, y), vrow(s, y2), (size_t)w * B);
            memcpy(vrowm(d, y2), line, (size_t)w * B);
        }
    }
    free(line);
    return kvImageNoError;
}
#define REFLECT(name, ch, t, T) \
    vImage_Error vImageHorizontalReflect_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { \
        return reflect(src, dest, VF(ch, t), 1); } \
    vImage_Error vImageVerticalReflect_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImage_Flags flags) { \
        return reflect(src, dest, VF(ch, t), 0); }
VFORMATS_PLANAR(REFLECT) VFORMATS_MULTI(REFLECT)

static vImage_Error rotate90(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, uint8_t turns, const float *bg) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->data == d->data) return kvImageOutOfPlaceOperationRequired;
    turns &= 3;
    double scx = s->width / 2.0, scy = s->height / 2.0, dcx = d->width / 2.0, dcy = d->height / 2.0;
    for (long y = 0; y < (long)d->height; y++) for (long x = 0; x < (long)d->width; x++) {
        double dx = x + 0.5 - dcx, dy = y + 0.5 - dcy, sx = dx, sy = dy;
        for (int k = 0; k < turns; k++) { double t = sx; sx = -sy; sy = t; }   /* back one counterclockwise quarter turn */
        float px[4];
        vsample_px(s, f, (long)floor(sx + scx), (long)floor(sy + scy), 0, bg, px);
        vput(d, f, x, y, px);
    }
    return kvImageNoError;
}
#define ROT90_P(name, ch, t, T) \
    vImage_Error vImageRotate90_##name(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant, T backColor, vImage_Flags flags) { \
        float bg[4]; VBG_PLANAR_PX(bg, t, backColor); return rotate90(src, dest, VF(ch, t), rotationConstant, bg); }
#define ROT90_M(name, ch, t, T) \
    vImage_Error vImageRotate90_##name(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant, const T *backColor, vImage_Flags flags) { \
        float bg[4]; VBG_MULTI_PX(bg, VF(ch, t), backColor); return rotate90(src, dest, VF(ch, t), rotationConstant, bg); }
VFORMATS_PLANAR(ROT90_P) VFORMATS_MULTI(ROT90_M)

/* ---- rotation by any angle, affine and perspective warps ---- */

/* map: destination (x, y) -> source (sx, sy); returns 0 when the point has no source (a perspective's horizon) */
typedef int (*vmap_fn)(const void *ctx, double x, double y, double *sx, double *sy);

static vImage_Error warp(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, vmap_fn map, const void *ctx, int nearest,
                         const float *bg, vImage_Flags flags) {
    if (flags & kvImageGetTempBufferSize) return 0;
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (s->data == d->data) return kvImageOutOfPlaceOperationRequired;
    int extend = (flags & kvImageEdgeExtend) != 0;
    for (long y = 0; y < (long)d->height; y++) for (long x = 0; x < (long)d->width; x++) {
        double sx, sy; float px[4];
        if (!map(ctx, x, y, &sx, &sy)) { for (int c = 0; c < f.ch; c++) px[c] = bg[c]; }
        else if (nearest) vsample_px(s, f, lround(sx), lround(sy), extend, bg, px);
        else {
            /* outside the source by more than half a pixel: background (unless extending) */
            if (!extend && (sx < -1 || sy < -1 || sx > s->width || sy > s->height)) { for (int c = 0; c < f.ch; c++) px[c] = bg[c]; }
            else vsample_linear(s, f, sx, sy, extend, bg, px);
        }
        vput(d, f, x, y, px);
    }
    return kvImageNoError;
}

typedef struct { double a, b, c, d, tx, ty; } vaff;   /* x' = a x + c y + tx, y' = b x + d y + ty */
static int aff_map(const void *ctx, double x, double y, double *sx, double *sy) {
    const vaff *m = ctx;
    *sx = m->a * x + m->c * y + m->tx; *sy = m->b * x + m->d * y + m->ty;
    return 1;
}
static int aff_inverse(vaff in, vaff *out) {
    double det = in.a * in.d - in.b * in.c;
    if (det == 0 || !isfinite(det)) return 0;
    out->a = in.d / det; out->b = -in.b / det; out->c = -in.c / det; out->d = in.a / det;
    out->tx = -(out->a * in.tx + out->c * in.ty); out->ty = -(out->b * in.tx + out->d * in.ty);
    return 1;
}
static vImage_Error affine(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, vaff m, const float *bg, vImage_Flags flags) {
    vaff inv;
    if (!aff_inverse(m, &inv)) return kvImageInvalidParameter;
    return warp(s, d, f, aff_map, &inv, 0, bg, flags);
}

static vImage_Error rotate(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, float angle, const float *bg, vImage_Flags flags) {
    if (!s || !d) return kvImageNullPointerArgument;
    /* counterclockwise on screen (y down) about the centres: source = R(angle)^-1 (dest - dc) + sc */
    double c = cos(angle), sn = sin(angle);
    double scx = (s->width - 1) / 2.0, scy = (s->height - 1) / 2.0, dcx = (d->width - 1) / 2.0, dcy = (d->height - 1) / 2.0;
    vaff inv = { c, sn, -sn, c, 0, 0 };
    inv.tx = scx - (inv.a * dcx + inv.c * dcy); inv.ty = scy - (inv.b * dcx + inv.d * dcy);
    return warp(s, d, f, aff_map, &inv, 0, bg, flags);
}

#define WARPS_COMMON(name, ch, t, BGT, BGDECL) \
    vImage_Error vImageRotate_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, float angleInRadians, \
                                     BGT backColor, vImage_Flags flags) { \
        float bg[4]; BGDECL; return rotate(src, dest, VF(ch, t), angleInRadians, bg, flags); } \
    vImage_Error vImageAffineWarp_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, \
                                         const vImage_AffineTransform *transform, BGT backColor, vImage_Flags flags) { \
        if (!transform) return kvImageNullPointerArgument; \
        float bg[4]; BGDECL; vaff m = { transform->a, transform->b, transform->c, transform->d, transform->tx, transform->ty }; \
        return affine(src, dest, VF(ch, t), m, bg, flags); } \
    vImage_Error vImageAffineWarpD_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, \
                                          const vImage_AffineTransform_Double *transform, BGT backColor, vImage_Flags flags) { \
        if (!transform) return kvImageNullPointerArgument; \
        float bg[4]; BGDECL; vaff m = { transform->a, transform->b, transform->c, transform->d, transform->tx, transform->ty }; \
        return affine(src, dest, VF(ch, t), m, bg, flags); } \
    vImage_Error vImageAffineWarpCG_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, \
                                           const vImage_CGAffineTransform *transform, BGT backColor, vImage_Flags flags) { \
        if (!transform) return kvImageNullPointerArgument; \
        float bg[4]; BGDECL; vaff m = { transform->a, transform->b, transform->c, transform->d, transform->tx, transform->ty }; \
        return affine(src, dest, VF(ch, t), m, bg, flags); }
#define WARPS_P(name, ch, t, T) WARPS_COMMON(name, ch, t, T, VBG_PLANAR_PX(bg, t, backColor))
#define WARPS_M(name, ch, t, T) WARPS_COMMON(name, ch, t, const T *, VBG_MULTI_PX(bg, VF(ch, t), backColor))
VFORMATS_PLANAR(WARPS_P) VFORMATS_MULTI(WARPS_M)

/* perspective: x' = (a x + c y + tx) / w, y' = (b x + d y + ty) / w, w = vx x + vy y + v */
typedef struct { double m[9]; } vpersp;   /* inverse, row-major 3x3 on (x, y, 1) */
static int persp_map(const void *ctx, double x, double y, double *sx, double *sy) {
    const double *m = ((const vpersp *)ctx)->m;
    double w = m[6] * x + m[7] * y + m[8];
    if (w <= 0 || !isfinite(w)) return 0;
    *sx = (m[0] * x + m[1] * y + m[2]) / w; *sy = (m[3] * x + m[4] * y + m[5]) / w;
    return 1;
}
static int mat3_inverse(const double *a, double *o) {
    double det = a[0] * (a[4] * a[8] - a[5] * a[7]) - a[1] * (a[3] * a[8] - a[5] * a[6]) + a[2] * (a[3] * a[7] - a[4] * a[6]);
    if (det == 0 || !isfinite(det)) return 0;
    o[0] = (a[4] * a[8] - a[5] * a[7]) / det; o[1] = (a[2] * a[7] - a[1] * a[8]) / det; o[2] = (a[1] * a[5] - a[2] * a[4]) / det;
    o[3] = (a[5] * a[6] - a[3] * a[8]) / det; o[4] = (a[0] * a[8] - a[2] * a[6]) / det; o[5] = (a[2] * a[3] - a[0] * a[5]) / det;
    o[6] = (a[3] * a[7] - a[4] * a[6]) / det; o[7] = (a[1] * a[6] - a[0] * a[7]) / det; o[8] = (a[0] * a[4] - a[1] * a[3]) / det;
    return 1;
}
static vImage_Error perspective(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, const vImage_PerpsectiveTransform *t,
                                vImage_WarpInterpolation interp, const float *bg, vImage_Flags flags) {
    if (!t) return kvImageNullPointerArgument;
    double fwd[9] = { t->a, t->c, t->tx, t->b, t->d, t->ty, t->vx, t->vy, t->v };
    vpersp inv;
    if (!mat3_inverse(fwd, inv.m)) return kvImageInvalidParameter;
    return warp(s, d, f, persp_map, &inv, interp == kvImageInterpolationNearest, bg, flags);
}
#define PERSP_P(name, ch, t, T) \
    vImage_Error vImagePerspectiveWarp_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, \
                                              const vImage_PerpsectiveTransform *transform, vImage_WarpInterpolation interpolation, \
                                              T backColor, vImage_Flags flags) { \
        float bg[4]; VBG_PLANAR_PX(bg, t, backColor); return perspective(src, dest, VF(ch, t), transform, interpolation, bg, flags); }
#define PERSP_M(name, ch, t, T) \
    vImage_Error vImagePerspectiveWarp_##name(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, \
                                              const vImage_PerpsectiveTransform *transform, vImage_WarpInterpolation interpolation, \
                                              T *backColor, vImage_Flags flags) { \
        float bg[4]; VBG_MULTI_PX(bg, VF(ch, t), backColor); return perspective(src, dest, VF(ch, t), transform, interpolation, bg, flags); }
PERSP_P(Planar8, 1, VT_U8, Pixel_8) PERSP_P(Planar16U, 1, VT_U16, Pixel_16U) PERSP_P(Planar16F, 1, VT_F16, Pixel_16F)
PERSP_M(ARGB8888, 4, VT_U8, uint8_t) PERSP_M(ARGB16U, 4, VT_U16, uint16_t) PERSP_M(ARGB16F, 4, VT_F16, uint16_t)

/* the perspective that takes four source points to four destination points (a homography) */
vImage_Error vImageGetPerspectiveWarp(const float srcPoints[4][2], const float destPoints[4][2], vImage_PerpsectiveTransform *transform,
                                      vImage_Flags flags) {
    if (!srcPoints || !destPoints || !transform) return kvImageNullPointerArgument;
    double A[8][9];
    for (int i = 0; i < 4; i++) {
        double x = srcPoints[i][0], y = srcPoints[i][1], u = destPoints[i][0], v = destPoints[i][1];
        double r1[9] = { x, y, 1, 0, 0, 0, -u * x, -u * y, u }, r2[9] = { 0, 0, 0, x, y, 1, -v * x, -v * y, v };
        memcpy(A[2 * i], r1, sizeof r1); memcpy(A[2 * i + 1], r2, sizeof r2);
    }
    for (int c = 0; c < 8; c++) {   /* Gauss-Jordan with partial pivoting on the 8x8 system */
        int p = c;
        for (int r = c + 1; r < 8; r++) if (fabs(A[r][c]) > fabs(A[p][c])) p = r;
        if (fabs(A[p][c]) < 1e-12) return kvImageInvalidParameter;
        if (p != c) for (int k = 0; k < 9; k++) { double t = A[c][k]; A[c][k] = A[p][k]; A[p][k] = t; }
        for (int r = 0; r < 8; r++) if (r != c) {
            double m = A[r][c] / A[c][c];
            for (int k = c; k < 9; k++) A[r][k] -= m * A[c][k];
        }
    }
    double h[8];
    for (int i = 0; i < 8; i++) h[i] = A[i][8] / A[i][i];
    /* u = (h0 x + h1 y + h2) / (h6 x + h7 y + 1) */
    transform->a = (float)h[0]; transform->c = (float)h[1]; transform->tx = (float)h[2];
    transform->b = (float)h[3]; transform->d = (float)h[4]; transform->ty = (float)h[5];
    transform->vx = (float)h[6]; transform->vy = (float)h[7]; transform->v = 1;
    return kvImageNoError;
}

/* ---- shears ---- */

static vImage_Error shear(const vImage_Buffer *s, const vImage_Buffer *d, vfmt f, long offx, long offy, double translate, double slope,
                          const vfilter *filter, const float *bg, vImage_Flags flags, int horizontal) {
    vImage_Error e = vcheck2(s, d);
    if (e) return e;
    if (!filter || filter->magic != VFILTER_MAGIC) return kvImageNullPointerArgument;
    if (offx < 0 || offx >= (long)s->width) return kvImageInvalidOffset_X;
    if (offy < 0 || offy >= (long)s->height) return kvImageInvalidOffset_Y;
    int extend = (flags & kvImageEdgeExtend) != 0;
    vtaps t;
    for (long y = 0; y < (long)d->height; y++) for (long x = 0; x < (long)d->width; x++) {
        /* along the sheared axis the destination is the source scaled, translated and slid by slope x the other coordinate */
        double along = horizontal ? x : y, across = horizontal ? y : x;
        double c = (horizontal ? offx : offy) + (along + 0.5 - translate - slope * (across + 0.5)) / filter->scale - 0.5;
        taps(&t, c, filter->scale, filter, 3);
        float acc[4] = { 0 }, px[4];
        for (int i = 0; i < t.n; i++) {
            long a = t.first + i, sx = horizontal ? a : offx + x, sy = horizontal ? offy + y : a;
            vsample_px(s, f, sx, sy, extend, bg, px);
            for (int k = 0; k < f.ch; k++) acc[k] += t.w[i] * px[k];
        }
        vput(d, f, x, y, acc);
    }
    return kvImageNoError;
}
#define SHEARS_COMMON(name, ch, t, BGT, BGDECL) \
    vImage_Error vImageHorizontalShear_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, \
        vImagePixelCount srcOffsetToROI_Y, float xTranslate, float shearSlope, ResamplingFilter filter, BGT backColor, vImage_Flags flags) { \
        float bg[4]; BGDECL; return shear(src, dest, VF(ch, t), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, xTranslate, shearSlope, filter, bg, flags, 1); } \
    vImage_Error vImageVerticalShear_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, \
        vImagePixelCount srcOffsetToROI_Y, float yTranslate, float shearSlope, ResamplingFilter filter, BGT backColor, vImage_Flags flags) { \
        float bg[4]; BGDECL; return shear(src, dest, VF(ch, t), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, yTranslate, shearSlope, filter, bg, flags, 0); } \
    vImage_Error vImageHorizontalShearD_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, \
        vImagePixelCount srcOffsetToROI_Y, double xTranslate, double shearSlope, ResamplingFilter filter, BGT backColor, vImage_Flags flags) { \
        float bg[4]; BGDECL; return shear(src, dest, VF(ch, t), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, xTranslate, shearSlope, filter, bg, flags, 1); } \
    vImage_Error vImageVerticalShearD_##name(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, \
        vImagePixelCount srcOffsetToROI_Y, double yTranslate, double shearSlope, ResamplingFilter filter, BGT backColor, vImage_Flags flags) { \
        float bg[4]; BGDECL; return shear(src, dest, VF(ch, t), (long)srcOffsetToROI_X, (long)srcOffsetToROI_Y, yTranslate, shearSlope, filter, bg, flags, 0); }
#define SHEARS_P(name, ch, t, T) SHEARS_COMMON(name, ch, t, T, VBG_PLANAR_PX(bg, t, backColor))
#define SHEARS_M(name, ch, t, T) SHEARS_COMMON(name, ch, t, const T *, VBG_MULTI_PX(bg, VF(ch, t), backColor))
VFORMATS_PLANAR(SHEARS_P) VFORMATS_MULTI(SHEARS_M)
