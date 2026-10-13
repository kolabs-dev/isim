// isim Core Image filters: blur and morphology.
#import "CIFilterImpl.h"

/* ---- helpers: a padded source buffer for an output rect ---- */
static ci_buf src_for(CIImage *im, CGRect r, int pad, const ci_rctx *rc) {
    ci_buf b; b.r = CGRectInset(r, -pad, -pad); b.w = (int)b.r.size.width; b.h = (int)b.r.size.height;
    b.px = ci_render_new(im, b.r, rc);
    return b;
}
static void copy_center(const ci_buf *b, int pad, CGRect r, float *out) {
    int W = (int)r.size.width, H = (int)r.size.height;
    for (int y = 0; y < H; y++) memcpy(out + (size_t)y * W * 4, b->px + ((size_t)(y + pad) * b->w + pad) * 4, sizeof(float) * 4 * W);
}
static CGRect grow(CGRect e, double d) { return ci_infinite(e) ? CGRectInfinite : CGRectInset(e, -d, -d); }

/* disc-shaped kernel sums with per-row prefix sums: O(radius) per pixel */
static void disc_sum(const ci_buf *b, int pad, CGRect r, double rad, float *out, double *area) {
    int W = (int)r.size.width, H = (int)r.size.height, BW = b->w, R = (int)floor(rad);
    double *pre = malloc(sizeof(double) * 4 * (size_t)(BW + 1) * b->h);
    for (int y = 0; y < b->h; y++) {
        double *p = pre + (size_t)y * (BW + 1) * 4;
        p[0] = p[1] = p[2] = p[3] = 0;
        for (int x = 0; x < BW; x++) for (int k = 0; k < 4; k++) p[(x + 1) * 4 + k] = p[x * 4 + k] + b->px[((size_t)y * BW + x) * 4 + k];
    }
    int *half = malloc(sizeof(int) * (2 * R + 1)); double cnt = 0;
    for (int dy = -R; dy <= R; dy++) { half[dy + R] = (int)floor(sqrt(fmax(0, rad * rad - dy * dy))); cnt += 2 * half[dy + R] + 1; }
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
        double acc[4] = { 0 };
        for (int dy = -R; dy <= R; dy++) {
            int sy = y + pad + dy; if (sy < 0 || sy >= b->h) continue;
            int hw = half[dy + R], x0 = x + pad - hw, x1 = x + pad + hw + 1;
            if (x0 < 0) x0 = 0; if (x1 > BW) x1 = BW;
            const double *p = pre + (size_t)sy * (BW + 1) * 4;
            for (int k = 0; k < 4; k++) acc[k] += p[x1 * 4 + k] - p[x0 * 4 + k];
        }
        for (int k = 0; k < 4; k++) out[((size_t)y * W + x) * 4 + k] = (float)acc[k];
    }
    *area = cnt;
    free(pre); free(half);
}
/* sliding window max/min of n values over [i - h, i + h] (van Herk / Gil-Werman: O(1) per value) */
static void slide(const float *in, float *out, int n, int unused, int h, int isMax) {
    if (h <= 0) { memcpy(out, in, sizeof(float) * n); return; }
    int w = 2 * h + 1, m = n + 2 * h;
    float neutral = isMax ? -INFINITY : INFINITY;
    float *a = malloc(sizeof(float) * m), *g = malloc(sizeof(float) * m), *s = malloc(sizeof(float) * m);
    for (int i = 0; i < m; i++) a[i] = i < h || i >= n + h ? neutral : in[i - h];
    for (int i = 0; i < m; i++) g[i] = i % w == 0 ? a[i] : isMax ? fmaxf(g[i - 1], a[i]) : fminf(g[i - 1], a[i]);
    for (int i = m - 1; i >= 0; i--) s[i] = i == m - 1 || (i + 1) % w == 0 ? a[i] : isMax ? fmaxf(s[i + 1], a[i]) : fminf(s[i + 1], a[i]);
    for (int i = 0; i < n; i++) out[i] = isMax ? fmaxf(s[i], g[i + 2 * h]) : fminf(s[i], g[i + 2 * h]);
    free(a); free(g); free(s);
}
/* circular morphology (max or min over a disc) */
static CIImage *morph_disc(CIImage *im, double rad, int isMax) {
    if (rad < 0.5) return im;
    int R = (int)ceil(rad);
    return ci_op(grow(im.extent, isMax ? R : 0), ^(CGRect r, float *out, const ci_rctx *rc) {
        ci_buf b = src_for(im, r, R, rc);
        int W = (int)r.size.width, H = (int)r.size.height;
        float *line = malloc(sizeof(float) * b.w), *res = malloc(sizeof(float) * b.w);
        for (size_t i = 0; i < (size_t)W * H * 4; i++) out[i] = isMax ? -INFINITY : INFINITY;
        for (int dy = -R; dy <= R; dy++) {
            int hw = (int)floor(sqrt(fmax(0, rad * rad - dy * dy)));
            for (int y = 0; y < H; y++) {
                int sy = y + R + dy;
                for (int k = 0; k < 4; k++) {
                    for (int x = 0; x < b.w; x++) line[x] = b.px[((size_t)sy * b.w + x) * 4 + k];
                    slide(line, res, b.w, 1, hw, isMax);
                    float *o = out + (size_t)y * W * 4 + k;
                    for (int x = 0; x < W; x++) o[x * 4] = isMax ? fmaxf(o[x * 4], res[x + R]) : fminf(o[x * 4], res[x + R]);
                }
            }
        }
        free(line); free(res); ci_buf_free(&b);
    });
}
static CIImage *morph_rect(CIImage *im, int w, int h, int isMax) {
    int hx = (w - 1) / 2, hy = (h - 1) / 2;
    if (hx <= 0 && hy <= 0) return im;
    int pad = hx > hy ? hx : hy;
    return ci_op(isMax ? grow(im.extent, pad) : im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        ci_buf b = src_for(im, r, pad, rc);
        int n = b.w > b.h ? b.w : b.h;
        float *line = malloc(sizeof(float) * n), *res = malloc(sizeof(float) * n);
        for (int y = 0; y < b.h; y++) for (int k = 0; k < 4; k++) {
            for (int x = 0; x < b.w; x++) line[x] = b.px[((size_t)y * b.w + x) * 4 + k];
            slide(line, res, b.w, 1, hx, isMax);
            for (int x = 0; x < b.w; x++) b.px[((size_t)y * b.w + x) * 4 + k] = res[x];
        }
        for (int x = 0; x < b.w; x++) for (int k = 0; k < 4; k++) {
            for (int y = 0; y < b.h; y++) line[y] = b.px[((size_t)y * b.w + x) * 4 + k];
            slide(line, res, b.h, 1, hy, isMax);
            for (int y = 0; y < b.h; y++) b.px[((size_t)y * b.w + x) * 4 + k] = res[y];
        }
        copy_center(&b, pad, r, out);
        free(line); free(res); ci_buf_free(&b);
    });
}

/* a variable blur: per pixel sigma(x, y) in [0, maxSigma], interpolated between a stack of uniform blurs */
CI_HIDDEN CIImage *ci_variable_blur(CIImage *im, CGRect extent, double maxSigma, CIImage *amount /* luminance 0...1 */);
CIImage *ci_variable_blur(CIImage *im, CGRect extent, double maxSigma, CIImage *amount) {
    if (maxSigma <= 0) return im;
    enum { L = 6 };
    int pad = (int)ceil(3 * maxSigma);
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        ci_buf b = src_for(im, r, pad, rc);
        float *amt = ci_render_new(amount, r, rc);
        float *lev[L];
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int l = 0; l < L; l++) {
            lev[l] = malloc(sizeof(float) * 4 * (size_t)b.w * b.h);
            memcpy(lev[l], b.px, sizeof(float) * 4 * (size_t)b.w * b.h);
            ci_blur_buf(lev[l], b.w, b.h, maxSigma * l / (L - 1));
        }
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            float *a = amt + ((size_t)y * W + x) * 4;
            float t = ci_clamp01(lumaf(a)) * (L - 1);
            int l0 = (int)floorf(t); if (l0 >= L - 1) l0 = L - 2; float f = t - l0;
            size_t si = ((size_t)(y + pad) * b.w + x + pad) * 4;
            for (int k = 0; k < 4; k++) out[((size_t)y * W + x) * 4 + k] = mixf(lev[l0][si + k], lev[l0 + 1][si + k], f);
        }
        for (int l = 0; l < L; l++) free(lev[l]);
        free(amt); ci_buf_free(&b);
    });
}

void ci_register_blur_filters(void) {
    REG(@"CIGaussianBlur", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return [im imageByApplyingGaussianBlurWithSigma:NUM(kCIInputRadiusKey, 10)];
    });
    REG(@"CIBoxBlur", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        int h = (int)lroundf(NUM(kCIInputRadiusKey, 10) / 2);
        if (h <= 0) return im;
        return ci_op(grow(im.extent, h), ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = src_for(im, r, h, rc);
            ci_box_blur_buf(b.px, b.w, b.h, h, h);
            copy_center(&b, h, r, out); ci_buf_free(&b);
        });
    });
    REG(@"CIDiscBlur", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = NUM(kCIInputRadiusKey, 8);
        if (rad < 0.5) return im;
        int R = (int)ceil(rad);
        return ci_op(grow(im.extent, R), ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = src_for(im, r, R, rc);
            double area; disc_sum(&b, R, r, rad, out, &area);
            for (size_t i = 0; i < (size_t)r.size.width * r.size.height * 4; i++) out[i] /= (float)area;
            ci_buf_free(&b);
        });
    });
    REG(@"CIBokehBlur", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = NUM(kCIInputRadiusKey, 20), ring = ci_clamp01(NUM(@"inputRingAmount", 0)), rs = NUM(@"inputRingSize", 0.1f), soft = NUM(@"inputSoftness", 1);
        if (rad < 0.5) return im;
        int R = (int)ceil(rad);
        CIImage *b = ci_op(grow(im.extent, R), ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = src_for(im, r, R, rc);
            size_t n = (size_t)r.size.width * r.size.height * 4;
            double a1, a2; float *inner = malloc(sizeof(float) * n);
            disc_sum(&b, R, r, rad, out, &a1);
            double rin = fmax(0, rad * (1 - fmax(rs, 0.01) * 2));
            disc_sum(&b, R, r, rin, inner, &a2);
            /* bright rims: (1 - ring) of the disc plus ring of the annulus */
            double wd = (1 - ring) / a1, wr = a1 - a2 > 0 ? ring / (a1 - a2) : 0;
            for (size_t i = 0; i < n; i++) out[i] = (float)(out[i] * wd + (out[i] - inner[i]) * wr);
            free(inner); ci_buf_free(&b);
        });
        return soft > 0 ? [[b imageByApplyingGaussianBlurWithSigma:soft] imageByCroppingToRect:grow(im.extent, R)] : b;
    });
    REG(@"CIMaskedVariableBlur", {
        CIImage *im = IMG(kCIInputImageKey), *mask = IMG(@"inputMask"); if (!im) return nil;
        double rad = NUM(kCIInputRadiusKey, 5);
        if (!mask) return [im imageByApplyingGaussianBlurWithSigma:rad];
        return ci_variable_blur([im imageByClampingToExtent], im.extent, rad, [mask imageByClampingToExtent]);
    });
    REG(@"CIMedianFilter", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = src_for([im imageByClampingToExtent], r, 1, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) for (int k = 0; k < 4; k++) {
                float v[9]; int n = 0;
                for (int dy = 0; dy < 3; dy++) for (int dx = 0; dx < 3; dx++) v[n++] = b.px[((size_t)(y + dy) * b.w + x + dx) * 4 + k];
                for (int i = 1; i < 9; i++) for (int j = i; j > 0 && v[j - 1] > v[j]; j--) { float t = v[j]; v[j] = v[j - 1]; v[j - 1] = t; }
                out[((size_t)y * W + x) * 4 + k] = v[4];
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CIMorphologyMaximum", { CIImage *im = IMG(kCIInputImageKey); return im ? morph_disc(im, NUM(kCIInputRadiusKey, 0), 1) : nil; });
    REG(@"CIMorphologyMinimum", { CIImage *im = IMG(kCIInputImageKey); return im ? morph_disc(im, NUM(kCIInputRadiusKey, 0), 0) : nil; });
    REG(@"CIMorphologyRectangleMaximum", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return morph_rect(im, (int)lroundf(NUM(kCIInputWidthKey, 5)), (int)lroundf(NUM(@"inputHeight", 5)), 1);
    });
    REG(@"CIMorphologyRectangleMinimum", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return morph_rect(im, (int)lroundf(NUM(kCIInputWidthKey, 5)), (int)lroundf(NUM(@"inputHeight", 5)), 0);
    });
    REG(@"CIMorphologyGradient", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = NUM(kCIInputRadiusKey, 5);
        CIImage *mx = morph_disc(im, rad, 1), *mn = morph_disc(im, rad, 0);
        return ci_combine(mx, mn, im.extent, ^(float *o, const float *a, const float *b) {
            for (int k = 0; k < 3; k++) o[k] = a[k] - b[k];
            o[3] = a[3];
        });
    });
    REG(@"CIMotionBlur", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double rad = NUM(kCIInputRadiusKey, 20), ang = NUM(kCIInputAngleKey, 0);
        if (rad < 0.5) return im;
        double dx = cos(ang), dy = sin(ang);
        int n = (int)ceil(rad) * 2 + 1;
        CGRect e = ci_infinite(im.extent) ? CGRectInfinite : CGRectInset(im.extent, -ceil(fabs(dx) * rad), -ceil(fabs(dy) * rad));
        return ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
            int pad = (int)ceil(rad) + 2;
            ci_buf b = ci_buf_render(im, CGRectInset(r, -pad, -pad), 2, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            /* samples along the line, weighted by a Gaussian across the length (sigma = radius / 2) */
            double wsum = 0; double *w = malloc(sizeof(double) * n);
            for (int i = 0; i < n; i++) { double t = (i - (n - 1) / 2.0) / ((n - 1) / 2.0); w[i] = exp(-t * t * 2); wsum += w[i]; }
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                double x = ci_px_x(r, i), y = ci_px_y(r, j); float acc[4] = { 0 };
                for (int s = 0; s < n; s++) {
                    double t = (s - (n - 1) / 2.0) / ((n - 1) / 2.0) * rad; float p[4];
                    ci_sample(&b, x + dx * t, y + dy * t, CI_SAMPLE_LINEAR, p);
                    for (int k = 0; k < 4; k++) acc[k] += (float)(p[k] * w[s]);
                }
                for (int k = 0; k < 4; k++) out[((size_t)j * W + i) * 4 + k] = (float)(acc[k] / wsum);
            }
            free(w); ci_buf_free(&b);
        });
    });
    REG(@"CIZoomBlur", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        double amount = NUM(kCIInputAmountKey, 20);
        if (fabs(amount) < 0.01) return im;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            /* samples along the line to the center: up to `amount` pixels per 100 pixels of distance... scaled toward c */
            enum { N = 24 };
            CGRect roi = CGRectUnion(r, CGRectMake(c.x, c.y, 1, 1));
            ci_buf b = ci_buf_render(im, CGRectInset(roi, -2, -2), 2, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                double x = ci_px_x(r, i), y = ci_px_y(r, j), d = hypot(x - c.x, y - c.y);
                double k = d > 0 ? fmin(1, amount / fmax(d, 1)) : 0;
                float acc[4] = { 0 };
                for (int s = 0; s < N; s++) {
                    double t = 1 - k * s / (double)N; float p[4];
                    ci_sample(&b, c.x + (x - c.x) * t, c.y + (y - c.y) * t, CI_SAMPLE_LINEAR, p);
                    for (int q = 0; q < 4; q++) acc[q] += p[q];
                }
                for (int q = 0; q < 4; q++) out[((size_t)j * W + i) * 4 + q] = acc[q] / N;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CINoiseReduction", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float level = NUM(@"inputNoiseLevel", 0.02f), sharp = NUM(kCIInputSharpnessKey, 0.4f);
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf b = src_for([im imageByClampingToExtent], r, 4, rc);
            float *bl = malloc(sizeof(float) * 4 * (size_t)b.w * b.h);
            memcpy(bl, b.px, sizeof(float) * 4 * (size_t)b.w * b.h);
            ci_blur_buf(bl, b.w, b.h, 1.0);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
                size_t si = ((size_t)(y + 4) * b.w + x + 4) * 4; float *o = out + ((size_t)y * W + x) * 4;
                float d[3] = { b.px[si] - bl[si], b.px[si + 1] - bl[si + 1], b.px[si + 2] - bl[si + 2] };
                float dl = fabsf(lumaf(d));
                for (int k = 0; k < 3; k++) o[k] = dl < level ? bl[si + k] : b.px[si + k] + sharp * d[k];
                o[3] = b.px[si + 3];
            }
            free(bl); ci_buf_free(&b);
        });
    });
    REG(@"CIDepthBlurEffect", {
        CIImage *im = IMG(kCIInputImageKey), *disp = IMG(kCIInputDisparityImageKey); if (!im) return nil;
        if (!disp) return im;
        CIImage *matte = IMG(kCIInputMatteImageKey);
        double ap = NUM(@"inputAperture", 0);
        if (ap <= 0) return im;
        CGRect e = im.extent, de = disp.extent;
        if (ci_infinite(e) || CGRectIsEmpty(de)) return im;
        /* disparity resampled over the image; the focus disparity is its median inside the focus rect (normalized
           0...1 in the image) or, without one, its maximum (the nearest subject) */
        CIImage *d = [[disp imageByApplyingTransform:CGAffineTransformMake(e.size.width / de.size.width, 0, 0, e.size.height / de.size.height,
                       e.origin.x - de.origin.x * e.size.width / de.size.width, e.origin.y - de.origin.y * e.size.height / de.size.height)] imageByClampingToExtent];
        CGRect fr = ci_rect(in[@"inputFocusRect"], CGRectZero);
        id key = [NSObject new];
        double maxSigma = ap * fmin(e.size.width, e.size.height) / 400;
        CIImage *amount = ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
            float focus = [ci_cache_get(rc, key, ^id {
                CGRect area = CGRectIsEmpty(fr) ? ci_integral(e) : ci_integral(CGRectMake(e.origin.x + fr.origin.x * e.size.width, e.origin.y + fr.origin.y * e.size.height,
                                                                                         fr.size.width * e.size.width, fr.size.height * e.size.height));
                double s = fmin(1, 128.0 / fmax(area.size.width, area.size.height));
                CGRect sa = CGRectIntegral(CGRectApplyAffineTransform(area, CGAffineTransformMakeScale(s, s)));
                float *px = ci_render_new([d imageByApplyingTransform:CGAffineTransformMakeScale(s, s)], sa, rc);
                size_t n = (size_t)sa.size.width * sa.size.height; float *v = malloc(sizeof(float) * (n ? n : 1));
                for (size_t i = 0; i < n; i++) v[i] = px[i * 4];
                float res = 0;
                if (n) {
                    if (CGRectIsEmpty(fr)) { res = v[0]; for (size_t i = 0; i < n; i++) res = fmaxf(res, v[i]); }
                    else { for (size_t i = 1; i < n; i++) for (size_t j = i; j > 0 && v[j - 1] > v[j]; j--) { float t = v[j]; v[j] = v[j - 1]; v[j - 1] = t; } res = v[n / 2]; }
                }
                free(px); free(v);
                return @(res);
            }) floatValue];
            float *dp = ci_render_new(d, r, rc), *mp = matte ? ci_render_new([matte imageByClampingToExtent], r, rc) : NULL;
            size_t n = (size_t)r.size.width * r.size.height;
            for (size_t i = 0; i < n; i++) {
                float a = ci_clamp01(fabsf(dp[i * 4] - focus) * 2);
                if (mp) a *= 1 - ci_clamp01(mp[i * 4]);
                out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = a; out[i * 4 + 3] = 1;
            }
            free(dp); free(mp);
        });
        return ci_variable_blur([im imageByClampingToExtent], e, maxSigma, amount);
    });
}
