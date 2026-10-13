// isim Core Image filters: transitions from inputImage (time 0) to inputTargetImage (time 1).
#import "CIFilterImpl.h"

static CIImage *clear_if_nil(CIImage *im) { return im ?: [CIImage clearImage]; }
/* per pixel: out = f(x, y, source pixel, target pixel) */
static CIImage *transition(CIImage *a, CIImage *b, CGRect extent, void (^fn)(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc)) {
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        float *fa = ci_render_new(a, r, rc), *fb = ci_render_new(b, r, rc);
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            size_t k = ((size_t)j * W + i) * 4;
            fn(ci_px_x(r, i), ci_px_y(r, j), fa + k, fb + k, out + k, rc);
        }
        free(fa); free(fb);
    });
}
static CGRect both(CIImage *a, CIImage *b) { return CGRectUnion(a.extent, b.extent); }

void ci_register_transition_filters(void) {
    REG(@"CIDissolveTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0));
        return transition(a, b, both(a, b), ^(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc) {
            for (int k = 0; k < 4; k++) o[k] = mixf(pa[k], pb[k], t);
        });
    });
    REG(@"CISwipeTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CGRect e = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 300, 300));
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), w = fmaxf(NUM(kCIInputWidthKey, 300), 1e-3f), op = NUM(@"inputOpacity", 0);
        double ang = NUM(kCIInputAngleKey, 0), dx = cos(ang), dy = sin(ang);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        /* a soft edge sweeps across the extent along the angle; behind it the target shows */
        double c0 = INFINITY, c1 = -INFINITY;
        for (int k = 0; k < 4; k++) { double px = k & 1 ? CGRectGetMaxX(e) : e.origin.x, py = k & 2 ? CGRectGetMaxY(e) : e.origin.y, d = px * dx + py * dy; c0 = fmin(c0, d); c1 = fmax(c1, d); }
        double pos = c0 - w + (c1 - c0 + 2 * w) * t;
        return transition(a, b, both(a, b), ^(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc) {
            float cc[4]; ci_color_ws(col, rc, cc);
            double d = x * dx + y * dy - pos;          /* < 0: swept (target) */
            float m = smoothf(-w / 2, w / 2, (float)d), band = 1 - fabsf((float)d) / (w / 2); band = band < 0 ? 0 : band;
            for (int k = 0; k < 4; k++) { o[k] = mixf(pb[k], pa[k], m); o[k] = mixf(o[k], cc[k], band * op); }
        });
    });
    REG(@"CIBarsSwipeTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), w = fmaxf(NUM(kCIInputWidthKey, 30), 1), off = NUM(@"inputBarOffset", 10);
        double ang = NUM(kCIInputAngleKey, M_PI), dx = cos(ang), dy = sin(ang);
        CGRect e = both(a, b);
        double span = ci_infinite(e) ? 1000 : hypot(e.size.width, e.size.height);
        return transition(a, b, e, ^(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc) {
            double along = x * dx + y * dy, across = -x * dy + y * dx;
            long bar = (long)floor(across / w);
            double edge = (t * (span + off * 20) - (bar & 1 ? off : 0) * ((bar % 7) + 1)) - (along + span / 2);
            const float *p = edge > 0 ? pb : pa;
            memcpy(o, p, 16);
        });
    });
    REG(@"CICopyMachineTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CGRect e = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 300, 300));
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), w = fmaxf(NUM(kCIInputWidthKey, 200), 1e-3f), op = NUM(@"inputOpacity", 1.3f);
        double ang = NUM(kCIInputAngleKey, 0), dx = cos(ang), dy = sin(ang);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:0.6 green:1 blue:1]);
        double c0 = INFINITY, c1 = -INFINITY;
        for (int k = 0; k < 4; k++) { double px = k & 1 ? CGRectGetMaxX(e) : e.origin.x, py = k & 2 ? CGRectGetMaxY(e) : e.origin.y, d = px * dx + py * dy; c0 = fmin(c0, d); c1 = fmax(c1, d); }
        double pos = c0 + (c1 - c0 + w) * t - w / 2;
        return transition(a, b, both(a, b), ^(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc) {
            float cc[4]; ci_color_ws(col, rc, cc);
            double d = x * dx + y * dy - pos;
            const float *p = d < 0 ? pb : pa;          /* the scanned part shows the target */
            float light = expf(-(float)(d * d) / (w * w / 8)) * op;
            for (int k = 0; k < 3; k++) o[k] = p[k] + cc[k] * light * (1 - p[k] / fmaxf(p[3], 1e-6f) * 0.5f);
            o[3] = fmaxf(p[3], fminf(1, light));
        });
    });
    REG(@"CIDisintegrateWithMaskTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)), *m = IMG(kCIInputMaskImageKey); if (!a) return nil;
        if (!m) m = [CIImage blackImage];
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), sr = NUM(@"inputShadowRadius", 8), sd = NUM(@"inputShadowDensity", 0.65f);
        CGPoint so = ci_point(in[@"inputShadowOffset"], CGPointMake(0, -10));
        CIImage *mask = [m imageByClampingToExtent];
        CIImage *shadow = [[[mask imageByApplyingTransform:CGAffineTransformMakeTranslation(so.x, so.y)] imageByApplyingGaussianBlurWithSigma:sr / 2] imageByCroppingToRect:both(a, b)];
        return ci_op(both(a, b), ^(CGRect r, float *out, const ci_rctx *rc) {
            float *fa = ci_render_new(a, r, rc), *fb = ci_render_new(b, r, rc), *fm = ci_render_new(mask, r, rc), *fs = ci_render_new(shadow, r, rc);
            size_t n = (size_t)r.size.width * r.size.height;
            for (size_t i = 0; i < n; i++) {
                /* pixels whose mask value is below the time have disintegrated (show the target); the rest casts a shadow */
                float mv = lumaf(fm + i * 4), sv = lumaf(fs + i * 4);
                BOOL gone = mv < t;
                float shade = gone ? 1 - sd * smoothf(t - 0.1f, t, sv) * (sv >= t ? 1 : 0) : 1;
                for (int k = 0; k < 4; k++) out[i * 4 + k] = gone ? fb[i * 4 + k] * (k < 3 ? shade : 1) : fa[i * 4 + k];
            }
            free(fa); free(fb); free(fm); free(fs);
        });
    });
    REG(@"CIFlashTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), ft = NUM(@"inputFadeThreshold", 0.85f), ss = NUM(@"inputStriationStrength", 0.5f), mr = NUM(@"inputMaxStriationRadius", 2.58f);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:1 green:0.8 blue:0.6]);
        CGRect e = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 300, 300));
        double R = hypot(e.size.width, e.size.height) / 2;
        return transition(a, b, both(a, b), ^(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc) {
            float cc[4]; ci_color_ws(col, rc, cc);
            /* the flash grows to cover everything at the fade threshold, then fades out over the target */
            double d = hypot(x - c.x, y - c.y) / fmax(R, 1), ang = atan2(y - c.y, x - c.x);
            float grow = t < ft ? t / ft : 1, fade = t < ft ? 1 : 1 - (t - ft) / fmaxf(1 - ft, 1e-3f);
            float stri = 1 + ss * (float)sin(ang * 24) * 0.5f;
            float flash = ci_clamp01((float)(grow * mr * 0.6 * stri - d * 0.8)) * fade;
            const float *p = t < ft ? pa : pb;
            for (int k = 0; k < 3; k++) o[k] = mixf(p[k], cc[k], flash);
            o[3] = fmaxf(p[3], flash);
        });
    });
    REG(@"CIModTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), R = fmaxf(NUM(kCIInputRadiusKey, 150), 1), comp = fmaxf(NUM(@"inputCompression", 300), 1);
        double ang = NUM(kCIInputAngleKey, 2);
        return transition(a, b, both(a, b), ^(double x, double y, const float *pa, const float *pb, float *o, const ci_rctx *rc) {
            /* rings and spokes whose phase advances with time: where the pattern is below the time, the target shows */
            double d = hypot(x - c.x, y - c.y), th = atan2(y - c.y, x - c.x) + ang;
            double v = fmod(d / R + sin(th * 3) * R / comp + 10, 1.0);
            memcpy(o, v < t ? pb : pa, 16);
        });
    });
    REG(@"CIRippleTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        CGRect e = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 300, 300));
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), w = fmaxf(NUM(kCIInputWidthKey, 100), 1), sc = NUM(kCIInputScaleKey, 50);
        CIImage *shade = IMG(kCIInputShadingImageKey);
        double R = hypot(e.size.width, e.size.height) + w, front = t * R;
        CIImage *sa = [a imageByClampingToExtent], *sb = [b imageByClampingToExtent];
        return ci_op(both(a, b), ^(CGRect r, float *out, const ci_rctx *rc) {
            int pad = (int)ceil(fabs(sc)) + 2;
            ci_buf ba = ci_buf_render(sa, CGRectInset(r, -pad, -pad), 0, rc), bb = ci_buf_render(sb, CGRectInset(r, -pad, -pad), 0, rc);
            CGRect se = shade ? ci_integral(shade.extent) : CGRectNull;
            ci_buf bs = { NULL };
            if (shade && !ci_infinite(se) && !CGRectIsEmpty(se)) bs = ci_buf_render(shade, se, 0, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                double x = ci_px_x(r, i), y = ci_px_y(r, j), dx = x - c.x, dy = y - c.y, d = hypot(dx, dy);
                double z = (d - front) / w;                 /* inside the ring band: displaced, shaded */
                float *o = out + ((size_t)j * W + i) * 4;
                double k = fabs(z) < 1 ? sin(z * M_PI) * sc * (1 - fabs(z)) : 0;
                double sx = d > 0 ? x + dx / d * k : x, sy = d > 0 ? y + dy / d * k : y;
                ci_sample_clamped(d < front ? &bb : &ba, sx, sy, CI_SAMPLE_LINEAR, o);
                if (bs.px && fabs(z) < 1) {
                    float s[4]; ci_sample_clamped(&bs, se.origin.x + (z * 0.5 + 0.5) * se.size.width, CGRectGetMidY(se), CI_SAMPLE_LINEAR, s);
                    for (int q = 0; q < 3; q++) o[q] = fminf(o[q] + s[q] * s[3] * 0.5f * (float)(1 - fabs(z)), o[3] > 0 ? o[3] : 1);
                }
            }
            ci_buf_free(&ba); ci_buf_free(&bb); if (bs.px) ci_buf_free(&bs);
        });
    });
    REG(@"CIAccordionFoldTransition", {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CGRect e = a.extent; if (ci_infinite(e)) return a;
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), bh = NUM(@"inputBottomHeight", 0), shadow = NUM(@"inputFoldShadowAmount", 0.1f);
        int folds = (int)lround(fmax(1, NUM(@"inputNumberOfFolds", 3)));
        /* the image folds like an accordion from the top down to bottomHeight, uncovering the target */
        double H = e.size.height, top = e.origin.y + bh + (H - bh) * (1 - t), fh = (top - e.origin.y - bh) / folds;
        CIImage *sa = [a imageByClampingToExtent];
        return ci_op(both(a, b), ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf ba = ci_buf_render(sa, e, 0, rc);
            float *fb = ci_render_new(b, r, rc);
            int W = (int)r.size.width, Hh = (int)r.size.height;
            for (int j = 0; j < Hh; j++) for (int i = 0; i < W; i++) {
                double x = ci_px_x(r, i), y = ci_px_y(r, j);
                float *o = out + ((size_t)j * W + i) * 4;
                if (y > top || x < e.origin.x || x > CGRectGetMaxX(e)) { memcpy(o, fb + ((size_t)j * W + i) * 4, 16); continue; }
                double sy;
                if (y < e.origin.y + bh) sy = y;
                else {
                    double u = (y - e.origin.y - bh) / fmax(fh, 1e-6); long k = (long)floor(u); double f = u - k;
                    double seg = (H - bh) / folds;           /* each fold shows one segment, compressed */
                    sy = e.origin.y + bh + (k + f) * seg;
                    float s = (float)(1 - shadow * (k & 1 ? f : 1 - f) * t * 2);
                    ci_sample_clamped(&ba, x, sy, CI_SAMPLE_LINEAR, o);
                    for (int q = 0; q < 3; q++) o[q] *= s;
                    continue;
                }
                ci_sample_clamped(&ba, x, sy, CI_SAMPLE_LINEAR, o);
            }
            ci_buf_free(&ba); free(fb);
        });
    });
    /* page curl: the page rolls around a cylinder of `radius` moving along the angle's direction */
    CIImage *(^curl)(NSDictionary *, BOOL) = ^CIImage *(NSDictionary *in, BOOL withShadow) {
        CIImage *a = IMG(kCIInputImageKey), *b = clear_if_nil(IMG(kCIInputTargetImageKey)); if (!a) return nil;
        CIImage *back = IMG(@"inputBacksideImage") ?: a, *shade = IMG(kCIInputShadingImageKey);
        CGRect e = ci_rect(in[kCIInputExtentKey], CGRectZero);
        if (CGRectIsEmpty(e)) e = a.extent;
        if (ci_infinite(e)) return a;
        float t = ci_clamp01(NUM(kCIInputTimeKey, 0)), R = fmaxf(NUM(kCIInputRadiusKey, 100), 0.01f);
        float sAmount = withShadow ? NUM(@"inputShadowAmount", 0.7f) : 0, sSize = withShadow ? NUM(@"inputShadowSize", 0.5f) : 0;
        double ang = NUM(kCIInputAngleKey, 0), dx = cos(ang), dy = sin(ang);
        double c0 = INFINITY, c1 = -INFINITY;
        for (int k = 0; k < 4; k++) { double px = k & 1 ? CGRectGetMaxX(e) : e.origin.x, py = k & 2 ? CGRectGetMaxY(e) : e.origin.y, d = px * dx + py * dy; c0 = fmin(c0, d); c1 = fmax(c1, d); }
        double line = c1 - (c1 - c0 + M_PI * R) * t;      /* the curl line moves from the far edge back */
        CIImage *sa = [a imageByCroppingToRect:e], *sbk = [back imageByCroppingToRect:e];
        return ci_op(both(a, b), ^(CGRect r, float *out, const ci_rctx *rc) {
            ci_buf ba = ci_buf_render(sa, e, 1, rc), bk = ci_buf_render(sbk, e, 1, rc);
            float *fb = ci_render_new(b, r, rc);
            CGRect se = shade ? ci_integral(shade.extent) : CGRectNull; ci_buf bs = { NULL };
            if (shade && !ci_infinite(se) && !CGRectIsEmpty(se)) bs = ci_buf_render(shade, se, 0, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                double x = ci_px_x(r, i), y = ci_px_y(r, j), d = x * dx + y * dy - line;
                float *o = out + ((size_t)j * W + i) * 4, *pb = fb + ((size_t)j * W + i) * 4;
                float front[4] = { 0 }, backs[4] = { 0 };
                BOOL hasFront = NO, hasBack = NO;
                if (d < 0) { ci_sample(&ba, x, y, CI_SAMPLE_LINEAR, front); hasFront = front[3] > 0; }
                else if (d < R) {
                    /* on the cylinder: the underside (back) at angle asin(d/R), the top (front) beyond it */
                    double a1 = asin(d / R), s1 = line + a1 * R, s2 = line + (M_PI - a1) * R;
                    double fx = x + (s1 - (line + d)) * dx, fy = y + (s1 - (line + d)) * dy, bx = x + (s2 - (line + d)) * dx, by = y + (s2 - (line + d)) * dy;
                    ci_sample(&bk, bx, by, CI_SAMPLE_LINEAR, backs); hasBack = backs[3] > 0;
                    if (!hasBack) { ci_sample(&ba, fx, fy, CI_SAMPLE_LINEAR, front); hasFront = front[3] > 0; }
                    if (hasBack) { float s = (float)(0.6 + 0.4 * cos(a1)); for (int q = 0; q < 3; q++) backs[q] *= s; }
                }
                if (hasBack) memcpy(o, backs, 16);
                else if (hasFront) memcpy(o, front, 16);
                else {
                    memcpy(o, pb, 16);
                    if (sAmount > 0 && d >= 0) {          /* the curl's shadow on the page below */
                        float k = sAmount * expf(-(float)(d - R > 0 ? d - R : 0) / fmaxf(R * sSize * 2, 1e-3f)) * (d < 2 * R + R * sSize * 4 ? 1 : 0);
                        for (int q = 0; q < 3; q++) o[q] *= 1 - k;
                    }
                }
                if (bs.px && hasBack) {
                    float s[4]; ci_sample_clamped(&bs, CGRectGetMidX(se), CGRectGetMidY(se), CI_SAMPLE_LINEAR, s);
                    for (int q = 0; q < 3; q++) o[q] = fminf(o[q] + s[q] * 0.2f, fmaxf(o[3], 1e-6f));
                }
            }
            ci_buf_free(&ba); ci_buf_free(&bk); free(fb); if (bs.px) ci_buf_free(&bs);
        });
    };
    REG(@"CIPageCurlTransition", { return curl(in, NO); });
    REG(@"CIPageCurlWithShadowTransition", { return curl(in, YES); });
}
