// isim Core Image filters: reductions (area statistics, histograms, k-means). Results are small images at the origin
// (1x1, Nx1, ...), computed once per render over the input's region.
#import "CIFilterImpl.h"

CI_HIDDEN void ci_rgb_to_lab(const float *lin, float *lab);

/* the region's pixels, cached for the render */
static NSData *region_pixels(CIImage *im, CGRect area, const ci_rctx *rc, id key) {
    return ci_cache_get(rc, key, ^id {
        CGRect r = ci_integral(CGRectIntersection(area, ci_infinite(im.extent) ? area : im.extent));
        if (CGRectIsNull(r) || CGRectIsEmpty(r) || ci_infinite(r)) return [NSData data];
        float *px = ci_render_new(im, r, rc);
        NSMutableData *d = [NSMutableData dataWithBytesNoCopy:px length:sizeof(float) * 4 * (size_t)r.size.width * r.size.height];
        return @[ d, [CIVector vectorWithCGRect:r] ];
    });
}
/* a reduction: compute(pixels, w, h, region, out) fills ow x oh result pixels, shown at (0, 0); the region is where the
   pixels are (rows top-down) */
static CIImage *reduction_at(CIImage *im, CGRect area, int ow, int oh,
                             void (^compute)(const float *px, int w, int h, CGRect region, float *out, const ci_rctx *rc)) {
    id key = [NSObject new], key2 = [NSObject new];
    return ci_op(CGRectMake(0, 0, ow, oh), ^(CGRect r, float *out, const ci_rctx *rc) {
        NSData *res = ci_cache_get(rc, key2, ^id {
            id got = region_pixels(im, area, rc, key);
            float *o = calloc((size_t)ow * oh * 4, sizeof(float));
            if ([got isKindOfClass:[NSArray class]]) {
                CGRect rr = [got[1] CGRectValue];
                compute([got[0] bytes], (int)rr.size.width, (int)rr.size.height, rr, o, rc);
            }
            return [NSData dataWithBytesNoCopy:o length:sizeof(float) * 4 * (size_t)ow * oh];
        });
        const float *o = res.bytes;
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            int x = (int)r.origin.x + i, y = (int)ci_px_y(r, j);
            if (x < 0 || y < 0 || x >= ow || y >= oh) continue;
            memcpy(out + ((size_t)j * W + i) * 4, o + ((size_t)(oh - 1 - y) * ow + x) * 4, 16);
        }
    });
}
static CIImage *reduction(CIImage *im, CGRect area, int ow, int oh, void (^compute)(const float *px, int w, int h, float *out, const ci_rctx *rc)) {
    return reduction_at(im, area, ow, oh, ^(const float *px, int w, int h, CGRect region, float *out, const ci_rctx *rc) { compute(px, w, h, out, rc); });
}
#define AREA(in) ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 640, 80))

void ci_register_reduction_filters(void) {
    REG(@"CIAreaAverage", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            double s[4] = { 0 }; size_t n = (size_t)w * h;
            for (size_t i = 0; i < n; i++) for (int k = 0; k < 4; k++) s[k] += px[i * 4 + k];
            for (int k = 0; k < 4; k++) o[k] = n ? (float)(s[k] / n) : 0;
        });
    });
    REG(@"CIAreaMaximum", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            for (int k = 0; k < 4; k++) o[k] = -INFINITY;
            for (size_t i = 0; i < (size_t)w * h; i++) for (int k = 0; k < 4; k++) o[k] = fmaxf(o[k], px[i * 4 + k]);
            if (!w || !h) memset(o, 0, 16);
        });
    });
    REG(@"CIAreaMinimum", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            for (int k = 0; k < 4; k++) o[k] = INFINITY;
            for (size_t i = 0; i < (size_t)w * h; i++) for (int k = 0; k < 4; k++) o[k] = fminf(o[k], px[i * 4 + k]);
            if (!w || !h) memset(o, 0, 16);
        });
    });
    REG(@"CIAreaMaximumAlpha", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            size_t best = 0;
            for (size_t i = 1; i < (size_t)w * h; i++) if (px[i * 4 + 3] > px[best * 4 + 3]) best = i;
            if (w && h) memcpy(o, px + best * 4, 16);
        });
    });
    REG(@"CIAreaMinimumAlpha", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            size_t best = 0;
            for (size_t i = 1; i < (size_t)w * h; i++) if (px[i * 4 + 3] < px[best * 4 + 3]) best = i;
            if (w && h) memcpy(o, px + best * 4, 16);
        });
    });
    REG(@"CIAreaMinMax", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 2, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            for (int k = 0; k < 4; k++) { o[k] = INFINITY; o[4 + k] = -INFINITY; }
            for (size_t i = 0; i < (size_t)w * h; i++) for (int k = 0; k < 4; k++) { o[k] = fminf(o[k], px[i * 4 + k]); o[4 + k] = fmaxf(o[4 + k], px[i * 4 + k]); }
            if (!w || !h) memset(o, 0, 32);
        });
    });
    REG(@"CIAreaMinMaxRed", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            float mn = INFINITY, mx = -INFINITY;
            for (size_t i = 0; i < (size_t)w * h; i++) { mn = fminf(mn, px[i * 4]); mx = fmaxf(mx, px[i * 4]); }
            o[0] = w && h ? mn : 0; o[1] = w && h ? mx : 0; o[2] = 0; o[3] = 1;
        });
    });
    REG(@"CIColumnAverage", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect a = AREA(in);
        int W = (int)ci_integral(CGRectIntersection(a, ci_infinite(im.extent) ? a : im.extent)).size.width;
        if (W <= 0) return [CIImage emptyImage];
        return reduction(im, a, W, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            for (int x = 0; x < w && x < W; x++) { double s[4] = { 0 }; for (int y = 0; y < h; y++) for (int k = 0; k < 4; k++) s[k] += px[((size_t)y * w + x) * 4 + k]; for (int k = 0; k < 4; k++) o[x * 4 + k] = (float)(s[k] / h); }
        });
    });
    REG(@"CIRowAverage", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect a = AREA(in);
        int H = (int)ci_integral(CGRectIntersection(a, ci_infinite(im.extent) ? a : im.extent)).size.height;
        if (H <= 0) return [CIImage emptyImage];
        return reduction(im, a, 1, H, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            /* output row y (from the bottom) averages the input row at the same height */
            for (int y = 0; y < h && y < H; y++) { double s[4] = { 0 }; for (int x = 0; x < w; x++) for (int k = 0; k < 4; k++) s[k] += px[((size_t)y * w + x) * 4 + k]; for (int k = 0; k < 4; k++) o[(size_t)y * 4 + k] = (float)(s[k] / w); }
        });
    });
    void (^histogram)(NSString *, BOOL) = ^(NSString *name, BOOL logarithmic) {
        ci_register_impl(name, ^CIImage *(NSDictionary *in) {
            CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
            int count = (int)lround(fmin(2048, fmax(1, NUM(@"inputCount", 64))));
            float scale = NUM(kCIInputScaleKey, 1), lo = NUM(@"inputMinimumStop", -10), hi = NUM(@"inputMaximumStop", 4);
            return reduction(im, AREA(in), count, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
                size_t n = (size_t)w * h;
                for (size_t i = 0; i < n; i++) {
                    const float *p = px + i * 4;
                    for (int k = 0; k < 4; k++) {
                        float v = k < 3 ? (p[3] > 0 ? p[k] / p[3] : 0) : p[3];
                        if (k < 3 && rc->managed && !logarithmic) v = ci_trc_encode(CI_TRC_SRGB, v);
                        float t = logarithmic ? (log2f(fmaxf(v, 1e-12f)) - lo) / (hi - lo) : v;
                        int bin = (int)floorf(ci_clamp01(t) * count); if (bin >= count) bin = count - 1;
                        o[bin * 4 + k] += 1;
                    }
                }
                for (int b = 0; b < count * 4; b++) o[b] = n ? o[b] / n * scale : 0;
            });
        });
    };
    histogram(@"CIAreaHistogram", NO);
    /* iOS 18: each pixel counts by its alpha; the bins are fractions of the total alpha */
    REG(@"CIAreaAlphaWeightedHistogram", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        int count = (int)lround(fmin(2048, fmax(1, NUM(@"inputCount", 64))));
        float scale = NUM(kCIInputScaleKey, 1);
        return reduction(im, AREA(in), count, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            double total = 0;
            for (size_t i = 0; i < (size_t)w * h; i++) {
                const float *p = px + i * 4;
                float a = p[3]; if (a <= 0) continue;
                total += a;
                for (int k = 0; k < 4; k++) {
                    float v = k < 3 ? p[k] / a : a;
                    if (k < 3 && rc->managed) v = ci_trc_encode(CI_TRC_SRGB, v);
                    int bin = (int)floorf(ci_clamp01(v) * count); if (bin >= count) bin = count - 1;
                    o[bin * 4 + k] += a;
                }
            }
            for (int b = 0; b < count * 4; b++) o[b] = total > 0 ? (float)(o[b] / total) * scale : 0;
        });
    });
    /* iOS 18: the bounding box (x, y, width, height) of the pixels whose red is above zero, in the image's coordinates */
    REG(@"CIAreaBoundsRed", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction_at(im, AREA(in), 1, 1, ^(const float *px, int w, int h, CGRect rr, float *o, const ci_rctx *rc) {
            int x0 = INT_MAX, y0 = INT_MAX, x1 = -1, y1 = -1;
            for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) if (px[((size_t)j * w + i) * 4] > 0) {
                int y = h - 1 - j;
                if (i < x0) x0 = i; if (i > x1) x1 = i; if (y < y0) y0 = y; if (y > y1) y1 = y;
            }
            if (x1 < 0) { o[0] = o[1] = o[2] = o[3] = 0; return; }
            o[0] = (float)(rr.origin.x + x0); o[1] = (float)(rr.origin.y + y0); o[2] = (float)(x1 - x0 + 1); o[3] = (float)(y1 - y0 + 1);
        });
    });
    /* iOS 26: the average and the maximum of red, as (average, maximum, 0, 1) */
    REG(@"CIAreaAverageMaximumRed", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return reduction(im, AREA(in), 1, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            double s = 0; float mx = -INFINITY; size_t n = (size_t)w * h;
            for (size_t i = 0; i < n; i++) { s += px[i * 4]; mx = fmaxf(mx, px[i * 4]); }
            o[0] = n ? (float)(s / n) : 0; o[1] = n ? mx : 0; o[2] = 0; o[3] = 1;
        });
    });
    histogram(@"CIAreaLogarithmicHistogram", YES);
    REG(@"CIHistogramDisplayFilter", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = ci_integral(im.extent);
        if (ci_infinite(e) || CGRectIsEmpty(e)) return nil;
        int W = (int)e.size.width, H = (int)lround(fmax(1, NUM(@"inputHeight", 100)));
        float hiL = NUM(@"inputHighLimit", 1), loL = NUM(@"inputLowLimit", 0);
        id key = [NSObject new];
        return ci_op(CGRectMake(0, 0, W, H), ^(CGRect r, float *out, const ci_rctx *rc) {
            NSData *hist = ci_cache_get(rc, key, ^id {
                float *p = ci_render_new(im, CGRectMake(e.origin.x, e.origin.y, W, 1), rc);
                float mx = 1e-12f; for (int i = 0; i < W * 3; i++) mx = fmaxf(mx, p[(i / 3) * 4 + i % 3]);
                for (int i = 0; i < W * 4; i++) p[i] /= mx;
                return [NSData dataWithBytesNoCopy:p length:sizeof(float) * 4 * W];
            });
            const float *hp = hist.bytes;
            int RW = (int)r.size.width, RH = (int)r.size.height;
            for (int j = 0; j < RH; j++) for (int i = 0; i < RW; i++) {
                int x = (int)r.origin.x + i; double y = ci_px_y(r, j) / H;
                float *o = out + ((size_t)j * RW + i) * 4;
                if (x < 0 || x >= W) continue;
                for (int k = 0; k < 3; k++) { float v = (hp[x * 4 + k] - loL) / fmaxf(hiL - loL, 1e-6f); o[k] = y <= v ? 1 : 0; }
                o[3] = 1;
            }
        });
    });
    REG(@"CIKMeans", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        int K = (int)lround(fmin(128, fmax(1, NUM(@"inputCount", 8)))), passes = (int)lround(fmax(0, NUM(@"inputPasses", 5)));
        BOOL perceptual = BOOLV(@"inputPerceptual");
        CIImage *means = IMG(@"inputMeans");
        return reduction(im, AREA(in), K, 1, ^(const float *px, int w, int h, float *o, const ci_rctx *rc) {
            size_t n = (size_t)w * h;
            /* features: colors in the working space or Lab (perceptual); sample at most 64k pixels */
            size_t step = n > 65536 ? n / 65536 : 1, m = 0;
            float *f = malloc(sizeof(float) * 3 * (n / step + 1)), *wt = malloc(sizeof(float) * (n / step + 1));
            for (size_t i = 0; i < n; i += step) {
                const float *p = px + i * 4; if (p[3] <= 0) continue;
                float c[3] = { p[0] / p[3], p[1] / p[3], p[2] / p[3] };
                if (perceptual) { float lab[3]; if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_linear); ci_rgb_to_lab(c, lab); c[0] = lab[0] / 100; c[1] = lab[1] / 100; c[2] = lab[2] / 100; }
                memcpy(f + m * 3, c, sizeof c); wt[m] = p[3]; m++;
            }
            float *ctr = calloc((size_t)K * 3, sizeof(float)); double *acc = calloc((size_t)K * 4, sizeof(double));
            int seeded = 0;
            if (means && !ci_infinite(means.extent)) {
                CGRect me = ci_integral(means.extent);
                float *mp = ci_render_new(means, me, rc);
                for (int k = 0; k < K && k < (int)(me.size.width * me.size.height); k++) {
                    float c[3] = { mp[k * 4], mp[k * 4 + 1], mp[k * 4 + 2] };
                    if (mp[k * 4 + 3] > 0) for (int q = 0; q < 3; q++) c[q] /= mp[k * 4 + 3];
                    if (perceptual) { float lab[3]; if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_linear); ci_rgb_to_lab(c, lab); c[0] = lab[0] / 100; c[1] = lab[1] / 100; c[2] = lab[2] / 100; }
                    memcpy(ctr + k * 3, c, sizeof c); seeded++;
                }
                free(mp);
            }
            for (int k = seeded; k < K; k++) if (m) memcpy(ctr + k * 3, f + ((m * (2 * k + 1)) / (2 * K)) * 3, 12);   /* spread seeds */
            int *asg = calloc(m ? m : 1, sizeof(int));
            for (int pass = 0; pass <= passes; pass++) {
                memset(acc, 0, sizeof(double) * K * 4);
                for (size_t i = 0; i < m; i++) {
                    int best = 0; float bd = INFINITY;
                    for (int k = 0; k < K; k++) { float d = 0; for (int q = 0; q < 3; q++) { float t = f[i * 3 + q] - ctr[k * 3 + q]; d += t * t; } if (d < bd) { bd = d; best = k; } }
                    asg[i] = best;
                    for (int q = 0; q < 3; q++) acc[best * 4 + q] += f[i * 3 + q] * wt[i];
                    acc[best * 4 + 3] += wt[i];
                }
                if (pass < passes) for (int k = 0; k < K; k++) if (acc[k * 4 + 3] > 0) for (int q = 0; q < 3; q++) ctr[k * 3 + q] = (float)(acc[k * 4 + q] / acc[k * 4 + 3]);
            }
            double total = 0; for (int k = 0; k < K; k++) total += acc[k * 4 + 3];
            for (int k = 0; k < K; k++) {
                float c[3]; memcpy(c, ctr + k * 3, 12);
                if (perceptual) {                       /* Lab back to the working space */
                    float lab[3] = { c[0] * 100, c[1] * 100, c[2] * 100 }, fy = (lab[0] + 16) / 116, fx = fy + lab[1] / 500, fz = fy - lab[2] / 200;
                    float X = 0.95047f * (fx * fx * fx > 0.008856f ? fx * fx * fx : (fx - 16 / 116.0f) / 7.787f), Y = fy * fy * fy > 0.008856f ? fy * fy * fy : (fy - 16 / 116.0f) / 7.787f;
                    float Z = 1.08883f * (fz * fz * fz > 0.008856f ? fz * fz * fz : (fz - 16 / 116.0f) / 7.787f);
                    c[0] = 3.2404542f * X - 1.5371385f * Y - 0.4985314f * Z; c[1] = -0.9692660f * X + 1.8760108f * Y + 0.0415560f * Z; c[2] = 0.0556434f * X - 0.2040259f * Y + 1.0572252f * Z;
                    if (rc->managed) ci_convert_rgb(c, ci_space_linear, rc->ws);
                }
                float a = total > 0 ? (float)(acc[k * 4 + 3] / total) : 0;   /* alpha: the cluster's share of the pixels */
                o[k * 4] = c[0]; o[k * 4 + 1] = c[1]; o[k * 4 + 2] = c[2]; o[k * 4 + 3] = a;
            }
            free(f); free(wt); free(ctr); free(acc); free(asg);
        });
    });
}
