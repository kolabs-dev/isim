// isim Core Image filters: stylize and sharpen.
#import "CIFilterImpl.h"

CI_HIDDEN CIImage *ci_variable_blur(CIImage *im, CGRect extent, double maxSigma, CIImage *amount);

static ci_buf padded(CIImage *im, CGRect r, int pad, const ci_rctx *rc) {
    ci_buf b; b.r = CGRectInset(r, -pad, -pad); b.w = (int)b.r.size.width; b.h = (int)b.r.size.height;
    b.px = ci_render_new(im, b.r, rc);
    return b;
}
static inline const float *bpx(const ci_buf *b, int x, int y) {      /* buffer coords, clamped */
    x = x < 0 ? 0 : x >= b->w ? b->w - 1 : x; y = y < 0 ? 0 : y >= b->h ? b->h - 1 : y;
    return b->px + ((size_t)y * b->w + x) * 4;
}
static inline float PC(const ci_buf *b, int x, int y, int c, int dx, int dy) { return bpx(b, x + dx, y + dy)[c]; }
static float plum(const float *p) { return p[3] > 0 ? lumaf(p) / p[3] : 0; }
/* luminance gradients (Sobel) of a padded buffer at buffer pixel (x, y) */
static void sobel(const ci_buf *b, int x, int y, float *gx, float *gy) {
#define L(dx, dy) plum(bpx(b, x + (dx), y + (dy)))
    *gx = (L(1, -1) + 2 * L(1, 0) + L(1, 1)) - (L(-1, -1) + 2 * L(-1, 0) + L(-1, 1));
    *gy = (L(-1, -1) + 2 * L(0, -1) + L(1, -1)) - (L(-1, 1) + 2 * L(0, 1) + L(1, 1));   /* rows top-down: up is -1 */
#undef L
}
static CIImage *blend_mask(CIImage *fg, CIImage *bg, CIImage *mask, int channel /* 0 r, 2 b, 3 alpha, 4 luminance */) {
    CGRect e = CGRectUnion(fg.extent, bg ? bg.extent : CGRectNull);
    return ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
        float *f = ci_render_new(fg, r, rc), *m = mask ? ci_render_new(mask, r, rc) : NULL;
        if (bg) [bg _render:r into:out ctx:rc];
        size_t n = (size_t)r.size.width * r.size.height;
        for (size_t i = 0; i < n; i++) {
            float *mp = m ? m + i * 4 : NULL, w = 0;
            if (mp) w = channel == 4 ? ci_clamp01(lumaf(mp)) : channel == 3 ? ci_clamp01(mp[3]) : ci_clamp01(mp[channel]);
            if (mp && channel == 4 && rc->managed) w = ci_trc_encode(CI_TRC_SRGB, w);     /* mask luminance as seen */
            for (int k = 0; k < 4; k++) out[i * 4 + k] = mixf(out[i * 4 + k], f[i * 4 + k], w);
        }
        free(f); free(m);
    });
}
static CIImage *convolve(CIImage *im, const float *w, int kw, int kh, float bias, BOOL rgbOnly) {
    int hx = kw / 2, hy = kh / 2, pad = hx > hy ? hx : hy;
    fbox W = { { 0 } }; memcpy(W.v, w, sizeof(float) * (size_t)(kw * kh));
    CIImage *src = [im imageByClampingToExtent];
    return ci_op(ci_infinite(im.extent) ? CGRectInfinite : CGRectInset(im.extent, -pad, -pad), ^(CGRect r, float *out, const ci_rctx *rc) {
        ci_buf b = padded(src, r, pad, rc);
        int RW = (int)r.size.width, RH = (int)r.size.height;
        for (int y = 0; y < RH; y++) for (int x = 0; x < RW; x++) {
            float a[4] = { 0 };
            for (int j = 0; j < kh; j++) for (int i = 0; i < kw; i++) {
                const float *p = bpx(&b, x + pad + i - hx, y + pad + j - hy); float k = W.v[j * kw + i];
                for (int c = 0; c < 4; c++) a[c] += p[c] * k;
            }
            float *o = out + ((size_t)y * RW + x) * 4;
            for (int c = 0; c < 3; c++) o[c] = a[c] + bias;
            o[3] = rgbOnly ? bpx(&b, x + pad, y + pad)[3] : a[3] + bias;
        }
        ci_buf_free(&b);
    });
}
/* cells: the color of each cell's seed position (Voronoi when jitter > 0) */
static CIImage *cells(CIImage *im, CGPoint c, double size, int hex, double jitter, double dotRadius) {
    size = fmax(size, 1);
    CIImage *src = [im imageByClampingToExtent];
    return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        int pad = (int)ceil(size * 2) + 2;
        ci_buf b = padded(src, r, pad, rc);
        ci_buf bl = { NULL };
        if (dotRadius > 0) {        /* gaps between dots: the image blurred */
            bl = padded(src, r, pad, rc);
            ci_blur_buf(bl.px, bl.w, bl.h, size / 2);
        }
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            double x = ci_px_x(r, i), y = ci_px_y(r, j), sx, sy;
            if (hex) {                               /* hexagonal grid (flat rows offset by half a cell) */
                double h = size * sqrt(3) / 2, row = round((y - c.y) / h);
                double off = ((long)row & 1) ? size / 2 : 0, col = round((x - c.x - off) / size);
                double best = INFINITY; sx = x; sy = y;
                for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) {
                    double rr = row + dr, oo = ((long)rr & 1) ? size / 2 : 0, cx = c.x + (col + dc) * size + oo, cy = c.y + rr * h;
                    double d = hypot(x - cx, y - cy); if (d < best) { best = d; sx = cx; sy = cy; }
                }
            } else if (jitter > 0) {
                double gx = floor((x - c.x) / size), gy = floor((y - c.y) / size), best = INFINITY; sx = x; sy = y;
                for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
                    int cx = (int)gx + dx, cy = (int)gy + dy;
                    double px = c.x + (cx + 0.5 + (ci_hash01(cx, cy, 7) - 0.5) * jitter) * size, py = c.y + (cy + 0.5 + (ci_hash01(cx, cy, 11) - 0.5) * jitter) * size;
                    double d = hypot(x - px, y - py); if (d < best) { best = d; sx = px; sy = py; }
                }
                if (dotRadius > 0 && best > dotRadius) {
                    const float *p = ci_buf_at(&bl, (int)floor(x), (int)floor(y));
                    if (p) memcpy(out + ((size_t)j * W + i) * 4, p, 16);
                    continue;
                }
            } else {
                sx = c.x + (floor((x - c.x) / size) + 0.5) * size; sy = c.y + (floor((y - c.y) / size) + 0.5) * size;
            }
            ci_sample_clamped(&b, sx, sy, CI_SAMPLE_NEAREST, out + ((size_t)j * W + i) * 4);
        }
        ci_buf_free(&b); if (bl.px) ci_buf_free(&bl);
    });
}
/* exact Euclidean distance transform (Felzenszwalb & Huttenlocher) of a binary grid: 0 at feature pixels */
static void edt_1d(const float *f, int n, float *d, int *v, float *z) {
    int k = 0; v[0] = 0; z[0] = -INFINITY; z[1] = INFINITY;
    for (int q = 1; q < n; q++) {
        float s;
        for (;;) { s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0f * q - 2.0f * v[k]); if (s <= z[k] && k > 0) k--; else break; }
        if (s <= z[k]) { v[0] = q; z[0] = -INFINITY; z[1] = INFINITY; k = 0; continue; }
        k++; v[k] = q; z[k] = s; z[k + 1] = INFINITY;
    }
    k = 0;
    for (int q = 0; q < n; q++) { while (z[k + 1] < q) k++; d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]; }
}
static void edt(float *g, int w, int h) {         /* in: 0 feature, INF elsewhere; out: squared distance */
    int n = w > h ? w : h;
    float *f = malloc(sizeof(float) * n), *d = malloc(sizeof(float) * n), *z = malloc(sizeof(float) * (n + 1)); int *v = malloc(sizeof(int) * n);
    for (int x = 0; x < w; x++) { for (int y = 0; y < h; y++) f[y] = g[y * w + x]; edt_1d(f, h, d, v, z); for (int y = 0; y < h; y++) g[y * w + x] = d[y]; }
    for (int y = 0; y < h; y++) { memcpy(f, g + y * w, sizeof(float) * w); edt_1d(f, w, d, v, z); memcpy(g + y * w, d, sizeof(float) * w); }
    free(f); free(d); free(z); free(v);
}
static CIImage *distance_from_red(CIImage *im, double maxd, BOOL sign) {
    maxd = fmax(maxd, 1e-3);
    int pad = (int)ceil(maxd) + 1;
    return ci_op(CGRectInfinite, ^(CGRect r, float *out, const ci_rctx *rc) {
        ci_buf b = padded(im, r, pad, rc);
        size_t n = (size_t)b.w * b.h;
        float *outside = malloc(sizeof(float) * n), *inside = sign ? malloc(sizeof(float) * n) : NULL;
        for (size_t i = 0; i < n; i++) {
            BOOL m = b.px[i * 4] > 0.5f;
            outside[i] = m ? 0 : 1e20f;
            if (inside) inside[i] = m ? 1e20f : 0;
        }
        edt(outside, b.w, b.h); if (inside) edt(inside, b.w, b.h);
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            size_t i = (size_t)(y + pad) * b.w + x + pad;
            float d = sqrtf(outside[i]);
            if (inside && inside[i] > 0) d = -(sqrtf(inside[i]) - 1);      /* negative inside the mask */
            d = fminf(d, (float)maxd); if (sign) d = fmaxf(d, (float)-maxd);
            float *o = out + ((size_t)y * W + x) * 4; o[0] = o[1] = o[2] = d; o[3] = 1;
        }
        free(outside); free(inside); ci_buf_free(&b);
    });
}
static float plum_srgb(const float *p, const ci_rctx *rc) { float l = plum(p); return rc->managed ? ci_trc_encode(CI_TRC_SRGB, ci_clamp01(l)) : ci_clamp01(l); }

void ci_register_stylize_filters(void) {
    REG(@"CIBlendWithMask", { CIImage *f = IMG(kCIInputImageKey); return f ? blend_mask(f, IMG(kCIInputBackgroundImageKey), IMG(kCIInputMaskImageKey), 4) : nil; });
    REG(@"CIBlendWithAlphaMask", { CIImage *f = IMG(kCIInputImageKey); return f ? blend_mask(f, IMG(kCIInputBackgroundImageKey), IMG(kCIInputMaskImageKey), 3) : nil; });
    REG(@"CIBlendWithRedMask", { CIImage *f = IMG(kCIInputImageKey); return f ? blend_mask(f, IMG(kCIInputBackgroundImageKey), IMG(kCIInputMaskImageKey), 0) : nil; });
    REG(@"CIBlendWithBlueMask", { CIImage *f = IMG(kCIInputImageKey); return f ? blend_mask(f, IMG(kCIInputBackgroundImageKey), IMG(kCIInputMaskImageKey), 2) : nil; });
    REG(@"CIMix", {
        CIImage *f = IMG(kCIInputImageKey), *b = IMG(kCIInputBackgroundImageKey); if (!f) return nil;
        float a = ci_clamp01(NUM(kCIInputAmountKey, 1));
        if (!b) return ci_map(f, ^(float *p) { for (int k = 0; k < 4; k++) p[k] *= a; });
        return ci_combine(f, b, CGRectUnion(f.extent, b.extent), ^(float *o, const float *pf, const float *pb) { for (int k = 0; k < 4; k++) o[k] = mixf(pb[k], pf[k], a); });
    });
    REG(@"CIBloom", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 0.5f);
        CIImage *bl = [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:NUM(kCIInputRadiusKey, 10)];
        return ci_combine(im, bl, im.extent, ^(float *o, const float *a, const float *b) {      /* screen the glow over the image */
            for (int c = 0; c < 3; c++) { float g = b[c] * k; o[c] = a[c] + g - a[c] * g; }
            o[3] = a[3];
        });
    });
    REG(@"CIGloom", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 0.5f);
        CIImage *bl = [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:NUM(kCIInputRadiusKey, 10)];
        return ci_combine(im, bl, im.extent, ^(float *o, const float *a, const float *b) {      /* multiply by the blur: dulls highlights */
            for (int c = 0; c < 3; c++) o[c] = mixf(a[c], fminf(a[c], a[c] * b[c] / fmaxf(b[3], 1e-6f) * 1.2f), k);
            o[3] = a[3];
        });
    });
    for (NSString *n in @[ @"CIConvolution3X3", @"CIConvolution5X5", @"CIConvolution7X7", @"CIConvolution9Horizontal", @"CIConvolution9Vertical",
                           @"CIConvolutionRGB3X3", @"CIConvolutionRGB5X5", @"CIConvolutionRGB7X7", @"CIConvolutionRGB9Horizontal", @"CIConvolutionRGB9Vertical" ]) {
        int kw = [n hasSuffix:@"3X3"] ? 3 : [n hasSuffix:@"5X5"] ? 5 : [n hasSuffix:@"7X7"] ? 7 : [n hasSuffix:@"Horizontal"] ? 9 : 1;
        int kh = [n hasSuffix:@"Vertical"] ? 9 : [n hasSuffix:@"Horizontal"] ? 1 : kw;
        BOOL rgb = [n containsString:@"RGB"];
        ci_register_impl(n, ^CIImage *(NSDictionary *in) {
            CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
            CIVector *v = in[kCIInputWeightsKey];
            float w[49] = { 0 };
            for (int i = 0; i < kw * kh; i++) w[i] = v && v.count > (size_t)i ? (float)[v valueAtIndex:i] : (i == kw * kh / 2);
            return convolve(im, w, kw, kh, NUM(kCIInputBiasKey, 0), rgb);
        });
    }
    REG(@"CICrystallize", { CIImage *im = IMG(kCIInputImageKey); return im ? cells(im, PT(kCIInputCenterKey, 150, 150), NUM(kCIInputRadiusKey, 20), 0, 0.9, 0) : nil; });
    REG(@"CIPointillize", { CIImage *im = IMG(kCIInputImageKey); double r = NUM(kCIInputRadiusKey, 20); return im ? cells(im, PT(kCIInputCenterKey, 150, 150), r * 1.6, 0, 0.8, r * 0.75) : nil; });
    REG(@"CIPixellate", { CIImage *im = IMG(kCIInputImageKey); return im ? cells(im, PT(kCIInputCenterKey, 150, 150), NUM(kCIInputScaleKey, 8), 0, 0, 0) : nil; });
    REG(@"CIHexagonalPixellate", { CIImage *im = IMG(kCIInputImageKey); return im ? cells(im, PT(kCIInputCenterKey, 150, 150), NUM(kCIInputScaleKey, 8), 1, 0, 0) : nil; });
    REG(@"CIEdges", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 1);
        CIImage *src = [im imageByClampingToExtent];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = padded(src, r, 1, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float *o = out + ((size_t)y * W + x) * 4;
                for (int c = 0; c < 3; c++) {
                    float gx = (PC(&b, x + 1, y + 1, c, 1, -1) + 2 * PC(&b, x + 1, y + 1, c, 1, 0) + PC(&b, x + 1, y + 1, c, 1, 1)) - (PC(&b, x + 1, y + 1, c, -1, -1) + 2 * PC(&b, x + 1, y + 1, c, -1, 0) + PC(&b, x + 1, y + 1, c, -1, 1));
                    float gy = (PC(&b, x + 1, y + 1, c, -1, -1) + 2 * PC(&b, x + 1, y + 1, c, 0, -1) + PC(&b, x + 1, y + 1, c, 1, -1)) - (PC(&b, x + 1, y + 1, c, -1, 1) + 2 * PC(&b, x + 1, y + 1, c, 0, 1) + PC(&b, x + 1, y + 1, c, 1, 1));
                    o[c] = sqrtf(gx * gx + gy * gy) * k;
                }
                o[3] = 1;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CISobelGradients", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIImage *src = [im imageByClampingToExtent];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = padded(src, r, 1, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float mx = 0, my = 0;
                for (int c = 0; c < 4; c++) {          /* the largest gradient over the channels, sign kept */
                    float gx = (PC(&b, x + 1, y + 1, c, 1, -1) + 2 * PC(&b, x + 1, y + 1, c, 1, 0) + PC(&b, x + 1, y + 1, c, 1, 1)) - (PC(&b, x + 1, y + 1, c, -1, -1) + 2 * PC(&b, x + 1, y + 1, c, -1, 0) + PC(&b, x + 1, y + 1, c, -1, 1));
                    float gy = (PC(&b, x + 1, y + 1, c, -1, -1) + 2 * PC(&b, x + 1, y + 1, c, 0, -1) + PC(&b, x + 1, y + 1, c, 1, -1)) - (PC(&b, x + 1, y + 1, c, -1, 1) + 2 * PC(&b, x + 1, y + 1, c, 0, 1) + PC(&b, x + 1, y + 1, c, 1, 1));
                    if (fabsf(gx) > fabsf(mx)) mx = gx;
                    if (fabsf(gy) > fabsf(my)) my = gy;
                }
                float *o = out + ((size_t)y * W + x) * 4; o[0] = mx; o[1] = my; o[2] = 0; o[3] = 1;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CIGaborGradients", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIImage *src = [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:1.5];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = padded(src, r, 1, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float gx, gy; sobel(&b, x + 1, y + 1, &gx, &gy);
                float *o = out + ((size_t)y * W + x) * 4; o[0] = gx / 4; o[1] = gy / 4; o[2] = 0; o[3] = 1;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CICannyEdgeDetector", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double sigma = NUM(@"inputGaussianSigma", 1.6f);
        float hi = NUM(@"inputThresholdHigh", 0.05f), lo = NUM(@"inputThresholdLow", 0.02f);
        int passes = (int)lround(NUM(@"inputHysteresisPasses", 1));
        BOOL perceptual = BOOLV(@"inputPerceptual");
        CIImage *src = [im imageByClampingToExtent];
        if (sigma > 0) src = [src imageByApplyingGaussianBlurWithSigma:sigma];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            int pad = 2 + passes;
            ci_buf b = padded(src, r, pad, rc);
            if (perceptual) for (size_t i = 0; i < (size_t)b.w * b.h; i++) { float *p = b.px + i * 4; float l = plum_srgb(p, rc); p[0] = p[1] = p[2] = l; p[3] = 1; }
            int BW = b.w, BH = b.h;
            float *mag = calloc((size_t)BW * BH, sizeof(float)); uint8_t *dir = calloc((size_t)BW * BH, 1), *st = calloc((size_t)BW * BH, 1);
            for (int y = 1; y < BH - 1; y++) for (int x = 1; x < BW - 1; x++) {
                float gx, gy; sobel(&b, x, y, &gx, &gy);
                mag[y * BW + x] = hypotf(gx, gy) / 4;
                float a = atan2f(gy, gx); if (a < 0) a += (float)M_PI;
                dir[y * BW + x] = (uint8_t)((int)lroundf(a / (float)(M_PI / 4)) % 4);
            }
            static const int dx[4] = { 1, 1, 0, -1 }, dy[4] = { 0, -1, 1, -1 };
            for (int y = 1; y < BH - 1; y++) for (int x = 1; x < BW - 1; x++) {     /* non-maximum suppression, thresholds */
                float m = mag[y * BW + x]; int d = dir[y * BW + x];
                if (m < mag[(y + dy[d]) * BW + x + dx[d]] || m < mag[(y - dy[d]) * BW + x - dx[d]]) continue;
                st[y * BW + x] = m >= hi ? 2 : m >= lo ? 1 : 0;
            }
            for (int p = 0; p < passes; p++)             /* hysteresis: weak edges next to strong ones become strong */
                for (int y = 1; y < BH - 1; y++) for (int x = 1; x < BW - 1; x++) {
                    if (st[y * BW + x] != 1) continue;
                    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) if (st[(y + j) * BW + x + i] == 2) { st[y * BW + x] = 2; i = j = 2; }
                }
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float v = st[(y + pad) * BW + x + pad] == 2 ? 1 : 0, *o = out + ((size_t)y * W + x) * 4;
                o[0] = o[1] = o[2] = v; o[3] = 1;
            }
            free(mag); free(dir); free(st); ci_buf_free(&b);
        });
    });
    REG(@"CIEdgeWork", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = fmax(NUM(kCIInputRadiusKey, 3), 0.5);
        CIImage *src = [im imageByClampingToExtent], *a = [src imageByApplyingGaussianBlurWithSigma:rad * 0.5], *b = [src imageByApplyingGaussianBlurWithSigma:rad];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {    /* difference of Gaussians: woodcut lines */
            float *pa = ci_render_new(a, r, rc), *pb = ci_render_new(b, r, rc);
            size_t n = (size_t)r.size.width * r.size.height;
            for (size_t i = 0; i < n; i++) {
                float d = plum(pa + i * 4) - plum(pb + i * 4), v = d < -0.01f ? 0 : 1;
                out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = 0; out[i * 4 + 3] = 1 - v;
            }
            free(pa); free(pb);
        });
    });
    REG(@"CILineOverlay", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float nr = NUM(@"inputNRNoiseLevel", 0.07f), ei = NUM(@"inputEdgeIntensity", 1), th = NUM(@"inputThreshold", 0.1f), co = NUM(kCIInputContrastKey, 50);
        CIImage *src = [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:1 + nr * 10];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = padded(src, r, 1, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float gx, gy; sobel(&b, x + 1, y + 1, &gx, &gy);
                float e = hypotf(gx, gy) * ei / 4, a = ci_clamp01((e - th) * co);
                float *o = out + ((size_t)y * W + x) * 4; o[0] = o[1] = o[2] = 0; o[3] = a;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CIComicEffect", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIImage *src = [im imageByClampingToExtent], *smooth = [src imageByApplyingGaussianBlurWithSigma:1.2];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = padded(smooth, r, 1, rc);
            [im _render:r into:out ctx:rc];
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float *o = out + ((size_t)y * W + x) * 4, a = o[3];
                if (a <= 0) continue;
                float gx, gy; sobel(&b, x + 1, y + 1, &gx, &gy);
                float e = hypotf(gx, gy) / 4;
                float c[3] = { o[0] / a, o[1] / a, o[2] / a };
                for (int k = 0; k < 3; k++) {             /* posterized, saturated colors with dark outlines */
                    float v = rc->managed ? ci_trc_encode(CI_TRC_SRGB, ci_clamp01(c[k])) : ci_clamp01(c[k]);
                    v = roundf(v * 4) / 4;
                    c[k] = rc->managed ? ci_trc_decode(CI_TRC_SRGB, v) : v;
                }
                float k = e > 0.12f ? 0 : 1;
                for (int q = 0; q < 3; q++) o[q] = c[q] * k * a;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CIHeightFieldFromMask", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = fmax(NUM(kCIInputRadiusKey, 10), 0.5);
        /* the mask (white = raised) smoothed into a rounded height ramp */
        CIImage *m = ci_map(im, ^(float *p) { float l = ci_clamp01(lumaf(p)); p[0] = p[1] = p[2] = l; p[3] = 1; });
        CIImage *h = [[m imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:rad / 2];
        return [ci_map(h, ^(float *p) { float v = ci_clamp01(p[0]); v = sqrtf(v * (2 - v)); p[0] = p[1] = p[2] = v; p[3] = 1; }) imageByCroppingToRect:im.extent];
    });
    REG(@"CIShadedMaterial", {
        CIImage *im = IMG(kCIInputImageKey), *sh = IMG(kCIInputShadingImageKey); if (!im) return nil;
        if (!sh || ci_infinite(sh.extent) || CGRectIsEmpty(sh.extent)) return im;
        float scale = NUM(kCIInputScaleKey, 10);
        CGRect se = ci_integral(sh.extent);
        CIImage *src = [im imageByClampingToExtent];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = padded(src, r, 1, rc);
            float *s = ci_render_new(sh, se, rc);
            ci_buf sb = { s, se, (int)se.size.width, (int)se.size.height };
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                float gx, gy; sobel(&b, x + 1, y + 1, &gx, &gy);
                float nx = -gx * scale / 8, ny = gy * scale / 8, nz = 1, l = sqrtf(nx * nx + ny * ny + nz * nz);
                nx /= l; ny /= l;
                ci_sample_clamped(&sb, se.origin.x + (nx * 0.5 + 0.5) * se.size.width, se.origin.y + (ny * 0.5 + 0.5) * se.size.height, CI_SAMPLE_LINEAR,
                                  out + ((size_t)y * W + x) * 4);
                out[((size_t)y * W + x) * 4 + 3] *= bpx(&b, x + 1, y + 1)[3] > 0 ? 1 : 0;
            }
            free(s); ci_buf_free(&b);
        });
    });
    REG(@"CIHighlightShadowAdjust", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = NUM(kCIInputRadiusKey, 0);
        float sa = NUM(@"inputShadowAmount", 0), ha = NUM(@"inputHighlightAmount", 1);
        CIImage *base = rad > 0 ? [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:rad * 4] : im;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float *bp = rad > 0 ? ci_render_new(base, r, rc) : NULL;
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float l = plum_srgb(p, rc), bl = bp ? plum_srgb(bp + i * 4, rc) : l;
                float nl = l;
                if (sa != 0) nl += sa * 0.5f * (1 - bl) * (1 - bl) * (sa > 0 ? (1 - l) : l);     /* lift / deepen shadows */
                if (ha < 1) nl -= (1 - ha) * 0.5f * bl * bl * l;                                  /* recover highlights */
                nl = ci_clamp01(nl);
                float k = l > 1e-5f ? (rc->managed ? ci_trc_decode(CI_TRC_SRGB, nl) / fmaxf(ci_trc_decode(CI_TRC_SRGB, l), 1e-6f) : nl / l) : 1;
                p[0] *= k; p[1] *= k; p[2] *= k;
            }
            free(bp);
        });
    });
    REG(@"CISpotColor", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIColor *cc[3], *rp[3]; float cl[3], ct[3];
        for (int i = 0; i < 3; i++) {
            cc[i] = ci_colorv(in[[NSString stringWithFormat:@"inputCenterColor%d", i + 1]], [CIColor blackColor]);
            rp[i] = ci_colorv(in[[NSString stringWithFormat:@"inputReplacementColor%d", i + 1]], [CIColor blackColor]);
            cl[i] = (float)ci_num(in[[NSString stringWithFormat:@"inputCloseness%d", i + 1]], 0.2);
            ct[i] = (float)ci_num(in[[NSString stringWithFormat:@"inputContrast%d", i + 1]], 0.98);
        }
        CIColor *c0 = cc[0], *c1 = cc[1], *c2 = cc[2], *r0 = rp[0], *r1 = rp[1], *r2 = rp[2];
        fbox P = { { cl[0], cl[1], cl[2], ct[0], ct[1], ct[2] } };
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            CIColor *C[3] = { c0, c1, c2 }, *R[3] = { r0, r1, r2 };
            float cs[3][3], rs[3][3];
            for (int i = 0; i < 3; i++) { cs[i][0] = (float)C[i].red; cs[i][1] = (float)C[i].green; cs[i][2] = (float)C[i].blue; rs[i][0] = (float)R[i].red; rs[i][1] = (float)R[i].green; rs[i][2] = (float)R[i].blue; }
            size_t n = (size_t)r.size.width * r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_srgb);
                float l = lumaf(c), o[3] = { c[0], c[1], c[2] }, used = 0;
                for (int k = 0; k < 3; k++) {         /* colors near a center color take its replacement (shaded by luminance) */
                    float d = sqrtf((c[0] - cs[k][0]) * (c[0] - cs[k][0]) + (c[1] - cs[k][1]) * (c[1] - cs[k][1]) + (c[2] - cs[k][2]) * (c[2] - cs[k][2]));
                    float w = 1 - smoothf(P.v[k] * P.v[3 + k], P.v[k] * (2 - P.v[3 + k]) + 1e-4f, d);
                    if (w <= used) continue;
                    float cl_ = lumaf(cs[k]), shade = cl_ > 0.01f ? l / cl_ : 1;
                    for (int q = 0; q < 3; q++) o[q] = mixf(c[q], ci_clamp01(rs[k][q] * shade), w);
                    used = w;
                }
                if (rc->managed) ci_convert_rgb(o, ci_space_srgb, rc->ws);
                p[0] = o[0] * a; p[1] = o[1] * a; p[2] = o[2] * a;
            }
        });
    });
    REG(@"CISpotLight", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIVector *lp = in[@"inputLightPosition"], *la = in[@"inputLightPointsAt"];
        double px = lp ? lp.X : 400, py = lp ? lp.Y : 600, pz = lp ? lp.Z : 150, ax = la ? la.X : 200, ay = la ? la.Y : 200, az = la ? la.Z : 0;
        float br = NUM(kCIInputBrightnessKey, 3), conc = NUM(@"inputConcentration", 0.1f);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        double sx = ax - px, sy = ay - py, sz = az - pz, sl = sqrt(sx * sx + sy * sy + sz * sz); sx /= sl; sy /= sl; sz /= sl;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float c[4]; ci_color_ws(col, rc, c);
            [im _render:r into:out ctx:rc];
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                double x = ci_px_x(r, i), y = ci_px_y(r, j), lx = px - x, ly = py - y, lz = pz, ll = sqrt(lx * lx + ly * ly + lz * lz);
                lx /= ll; ly /= ll; lz /= ll;
                double spot = fmax(0, -(lx * sx + ly * sy + lz * sz)), diffuse = fmax(0, lz);
                float k = (float)(br * pow(spot, 1 / fmax(conc, 1e-3)) * diffuse);
                float *p = out + ((size_t)j * W + i) * 4;
                for (int q = 0; q < 3; q++) p[q] *= c[q] * k;
            }
        });
    });
    REG(@"CIDistanceGradientFromRedMask", { CIImage *im = IMG(kCIInputImageKey); return im ? distance_from_red(im, NUM(@"inputMaximumDistance", 10), NO) : nil; });
    REG(@"CISignedDistanceGradientFromRedMask", { CIImage *im = IMG(kCIInputImageKey); return im ? distance_from_red(im, NUM(@"inputMaximumDistance", 10), YES) : nil; });
    REG(@"CIDepthOfField", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint a = PT(@"inputPoint0", 0, 300), b = PT(@"inputPoint1", 300, 300);
        double rad = NUM(kCIInputRadiusKey, 6);
        float sat = NUM(kCIInputSaturationKey, 1.5f);
        /* tilt-shift: sharp along the line through point0 and point1, blurred with the distance from it */
        CGRect e = im.extent;
        double dx = b.x - a.x, dy = b.y - a.y, l = hypot(dx, dy); if (l == 0) { dx = 1; l = 1; }
        double nx = -dy / l, ny = dx / l, band = fmax(e.size.height, e.size.width) * 0.1, fall = fmax(e.size.height, e.size.width) * 0.3;
        CIImage *amount = ci_gen(e, ^(double x, double y, float *o, const ci_rctx *rc) {
            double d = fabs((x - a.x) * nx + (y - a.y) * ny);
            float v = smoothf((float)band, (float)(band + fall), (float)d);
            o[0] = o[1] = o[2] = v; o[3] = 1;
        });
        CIFilter *us = [CIFilter filterWithName:@"CIUnsharpMask" withInputParameters:@{ kCIInputImageKey: im, kCIInputRadiusKey: in[@"inputUnsharpMaskRadius"] ?: @2.5, kCIInputIntensityKey: in[@"inputUnsharpMaskIntensity"] ?: @0.5 }];
        CIImage *sharp = [us.outputImage imageByApplyingFilter:@"CIColorControls" withInputParameters:@{ kCIInputSaturationKey: @(sat) }];
        return ci_variable_blur([sharp imageByClampingToExtent], e, rad, amount);
    });
    /* sharpen */
    REG(@"CIUnsharpMask", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 0.5f);
        CIImage *bl = [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:NUM(kCIInputRadiusKey, 2.5f)];
        return ci_combine(im, bl, im.extent, ^(float *o, const float *a, const float *b) {
            for (int c = 0; c < 3; c++) o[c] = a[c] + (a[c] - b[c]) * k;
            o[3] = a[3];
        });
    });
    REG(@"CISharpenLuminance", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputSharpnessKey, 0.4f);
        CIImage *bl = [[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:NUM(kCIInputRadiusKey, 1.69f)];
        return ci_combine(im, bl, im.extent, ^(float *o, const float *a, const float *b) {     /* luminance detail added back */
            float d = (lumaf(a) - lumaf(b)) * k;
            for (int c = 0; c < 3; c++) o[c] = a[c] + d;
            o[3] = a[3];
        });
    });
}
