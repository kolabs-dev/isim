// isim Core Image filters: color adjustment and color effect. Pixels arrive premultiplied in the working space
// (linear sRGB by default). Filters defined on perceptual (sRGB-encoded) values convert there and back (`perceptual`).
#import "CIFilterImpl.h"

/* runs fn on straight sRGB-encoded color when the image is color managed in a linear space */
static CIImage *perceptual(CIImage *im, void (^fn)(float *c)) {
    return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [im _render:r into:out ctx:rc];
        BOOL conv = rc->managed && rc->ws.trc == CI_TRC_LINEAR;
        size_t n = (size_t)r.size.width * (size_t)r.size.height;
        for (size_t i = 0; i < n; i++) {
            float *p = out + i * 4, a = p[3];
            if (a <= 0) continue;
            float c[3] = { p[0] / a, p[1] / a, p[2] / a };
            if (conv) for (int k = 0; k < 3; k++) c[k] = ci_trc_encode(CI_TRC_SRGB, c[k]);
            fn(c);
            if (conv) for (int k = 0; k < 3; k++) c[k] = ci_trc_decode(CI_TRC_SRGB, c[k]);
            p[0] = c[0] * a; p[1] = c[1] * a; p[2] = c[2] * a;
        }
    });
}
static float spow(float v, float p) { return v < 0 ? -powf(-v, p) : powf(v, p); }
static void vec4(CIVector *v, float o[4], const float d[4]) { for (int i = 0; i < 4; i++) o[i] = v && v.count > (size_t)i ? (float)[v valueAtIndex:i] : d[i]; }

/* ---- white points: color temperature (K) and tint -> linear sRGB white ---- */
static void cct_xy(double T, double *x, double *y) {        /* Kim et al. cubic spline of the Planckian locus */
    T = fmax(1667, fmin(25000, T));
    double t = 1e3 / T, t2 = t * t, t3 = t2 * t;
    *x = T <= 4000 ? -0.2661239 * t3 - 0.2343589 * t2 + 0.8776956 * t + 0.179910 : -3.0258469 * t3 + 2.1070379 * t2 + 0.2226347 * t + 0.240390;
    double X = *x, X2 = X * X, X3 = X2 * X;
    *y = T <= 2222 ? -1.1063814 * X3 - 1.34811020 * X2 + 2.18555832 * X - 0.20219683
       : T <= 4000 ? -0.9549476 * X3 - 1.37418593 * X2 + 2.09137015 * X - 0.16748867
       : 3.0817580 * X3 - 5.87338670 * X2 + 3.75112997 * X - 0.37001483;
}
static void white_rgb(double T, double tint, float rgb[3]) {
    double x, y; cct_xy(T, &x, &y);
    /* tint: a shift perpendicular to the locus in CIE 1960 uv (+: a greener light, which correcting turns magenta), 1 unit = 1/3000 */
    double d = -2 * x + 12 * y + 3, u = 4 * x / d, v = 6 * y / d;     /* CIE 1960 uv */
    double x2, y2; cct_xy(T + 10, &x2, &y2);
    double d2 = -2 * x2 + 12 * y2 + 3, u2 = 4 * x2 / d2, v2 = 6 * y2 / d2;
    double du = u2 - u, dv = v2 - v, l = hypot(du, dv);
    if (l > 0) { u += -dv / l * (-tint / 3000.0); v += du / l * (-tint / 3000.0); }
    x = 3 * u / (2 * u - 8 * v + 4); y = 2 * v / (2 * u - 8 * v + 4);
    double X = x / y, Y = 1, Z = (1 - x - y) / y;
    rgb[0] = (float)(3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z);
    rgb[1] = (float)(-0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z);
    rgb[2] = (float)(0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z);
}

void ci_white_rgb(double T, double tint, float rgb[3]) { white_rgb(T, tint, rgb); }

/* ---- tone curve: a monotone cubic (Fritsch-Carlson) through the points ---- */
typedef struct { float x[5], y[5], m[5]; int extrapolate; } curve5;
static void curve_init(curve5 *c) {
    float d[4];
    for (int i = 0; i < 4; i++) { float dx = c->x[i + 1] - c->x[i]; d[i] = dx != 0 ? (c->y[i + 1] - c->y[i]) / dx : 0; }
    c->m[0] = d[0]; c->m[4] = d[3];
    for (int i = 1; i < 4; i++) c->m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
    for (int i = 0; i < 4; i++) {
        if (d[i] == 0) { c->m[i] = c->m[i + 1] = 0; continue; }
        float a = c->m[i] / d[i], b = c->m[i + 1] / d[i], s = a * a + b * b;
        if (s > 9) { float t = 3 / sqrtf(s); c->m[i] = t * a * d[i]; c->m[i + 1] = t * b * d[i]; }
    }
}
static float curve_eval(const curve5 *c, float v) {
    if (v <= c->x[0]) return c->extrapolate ? c->y[0] + (v - c->x[0]) * c->m[0] : c->y[0];
    if (v >= c->x[4]) return c->extrapolate ? c->y[4] + (v - c->x[4]) * c->m[4] : c->y[4];
    int i = 0; while (i < 3 && v > c->x[i + 1]) i++;
    float h = c->x[i + 1] - c->x[i]; if (h <= 0) return c->y[i];
    float t = (v - c->x[i]) / h, t2 = t * t, t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * c->y[i] + (t3 - 2 * t2 + t) * h * c->m[i] + (-2 * t3 + 3 * t2) * c->y[i + 1] + (t3 - t2) * h * c->m[i + 1];
}

/* ---- color cubes ---- */
typedef struct { const float *d; int n; } cube_t;
static void cube_lookup(const cube_t *cb, const float *c, int extrapolate, float out[4]) {
    int n = cb->n; float f[3]; int i0[3], i1[3]; float t[3];
    for (int k = 0; k < 3; k++) {
        float v = extrapolate ? c[k] : ci_clamp01(c[k]);
        float p = v * (n - 1);
        int a = (int)floorf(p); if (a < 0) a = 0; if (a > n - 2) a = n - 2;
        i0[k] = a; i1[k] = a + 1; t[k] = p - a; f[k] = p;
    }
    for (int k = 0; k < 4; k++) out[k] = 0;
    for (int dz = 0; dz < 2; dz++) for (int dy = 0; dy < 2; dy++) for (int dx = 0; dx < 2; dx++) {
        float w = (dx ? t[0] : 1 - t[0]) * (dy ? t[1] : 1 - t[1]) * (dz ? t[2] : 1 - t[2]);
        int x = dx ? i1[0] : i0[0], y = dy ? i1[1] : i0[1], z = dz ? i1[2] : i0[2];
        const float *e = cb->d + ((size_t)z * n * n + (size_t)y * n + x) * 4;
        for (int k = 0; k < 4; k++) out[k] += e[k] * w;
    }
    (void)f;
}
static BOOL cube_of(NSData *d, int n, cube_t *out) {
    if (n < 2 || n > 128 || ![d isKindOfClass:[NSData class]] || d.length < (size_t)n * n * n * 4 * sizeof(float)) return NO;
    out->d = d.bytes; out->n = n;
    return YES;
}
/* cube applied to straight colors in `space` (working space when NULL) */
static CIImage *apply_cube(CIImage *im, NSData *data, int n, BOOL extrap, id space, CIImage *mask, NSData *data1) {
    cube_t c0 = { 0 }, c1 = { 0 };
    if (!cube_of(data, n, &c0)) { NSLog(@"isim: Core Image: color cube data must hold %d^3 RGBA floats", n); return nil; }
    BOOL two = mask && cube_of(data1, n, &c1);
    BOOL hasSpace = ci_is_cgspace(space);
    ci_space sp = hasSpace ? ci_space_of((__bridge CGColorSpaceRef)space) : ci_space_linear;
    return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [im _render:r into:out ctx:rc];
        float *m = two ? ci_render_new(mask, r, rc) : NULL;
        size_t np = (size_t)r.size.width * (size_t)r.size.height;
        for (size_t i = 0; i < np; i++) {
            float *p = out + i * 4, a = p[3];
            if (a <= 0) continue;
            float c[3] = { p[0] / a, p[1] / a, p[2] / a }, o[4];
            if (hasSpace && rc->managed) ci_convert_rgb(c, rc->ws, sp);
            cube_lookup(&c0, c, extrap, o);
            if (two) {
                float o1[4], w = m[i * 4 + 3] > 0 ? ci_clamp01(lumaf(m + i * 4) / m[i * 4 + 3] * m[i * 4 + 3]) : 0;
                cube_lookup(&c1, c, extrap, o1);
                for (int k = 0; k < 4; k++) o[k] = mixf(o[k], o1[k], w);
            }
            float oa = o[3];
            float s[3] = { oa > 0 ? o[0] / oa : 0, oa > 0 ? o[1] / oa : 0, oa > 0 ? o[2] / oa : 0 };
            if (hasSpace && rc->managed) ci_convert_rgb(s, sp, rc->ws);
            float na = oa * a;
            p[0] = s[0] * na; p[1] = s[1] * na; p[2] = s[2] * na; p[3] = na;
        }
        free(m);
    });
}

/* ---- Lab ---- */
static float lab_f(float t) { return t > 0.008856f ? cbrtf(t) : 7.787f * t + 16 / 116.0f; }
static float lab_finv(float t) { float t3 = t * t * t; return t3 > 0.008856f ? t3 : (t - 16 / 116.0f) / 7.787f; }
static void rgb_to_lab(const float *lin, float *lab) {       /* linear sRGB, D65 */
    float X = 0.4124564f * lin[0] + 0.3575761f * lin[1] + 0.1804375f * lin[2];
    float Y = 0.2126729f * lin[0] + 0.7151522f * lin[1] + 0.0721750f * lin[2];
    float Z = 0.0193339f * lin[0] + 0.1191920f * lin[1] + 0.9503041f * lin[2];
    float fx = lab_f(X / 0.95047f), fy = lab_f(Y), fz = lab_f(Z / 1.08883f);
    lab[0] = 116 * fy - 16; lab[1] = 500 * (fx - fy); lab[2] = 200 * (fy - fz);
}
static void lab_to_rgb(const float *lab, float *lin) {
    float fy = (lab[0] + 16) / 116, fx = fy + lab[1] / 500, fz = fy - lab[2] / 200;
    float X = 0.95047f * lab_finv(fx), Y = lab_finv(fy), Z = 1.08883f * lab_finv(fz);
    lin[0] = 3.2404542f * X - 1.5371385f * Y - 0.4985314f * Z;
    lin[1] = -0.9692660f * X + 1.8760108f * Y + 0.0415560f * Z;
    lin[2] = 0.0556434f * X - 0.2040259f * Y + 1.0572252f * Z;
}
/* straight working-space color -> linear sRGB */
static void to_linear(const ci_rctx *rc, float *c) { if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_linear); }
static void from_linear(const ci_rctx *rc, float *c) { if (rc->managed) ci_convert_rgb(c, ci_space_linear, rc->ws); }
static float delta_e94(const float *a, const float *b) {
    float dL = a[0] - b[0], C1 = hypotf(a[1], a[2]), C2 = hypotf(b[1], b[2]), dC = C1 - C2;
    float da = a[1] - b[1], db = a[2] - b[2], dH2 = fmaxf(0, da * da + db * db - dC * dC);
    float SC = 1 + 0.045f * C1, SH = 1 + 0.015f * C1;
    return sqrtf(dL * dL + (dC / SC) * (dC / SC) + dH2 / (SH * SH));
}
CI_HIDDEN void ci_rgb_to_lab(const float *lin, float *lab) { rgb_to_lab(lin, lab); }

/* ---- photo effects (adapted: tone and color transforms in sRGB, not Apple's lookup tables) ---- */
static void adjust(float *c, float sat, float bright, float contrast) {
    float l = lumaf(c);
    for (int k = 0; k < 3; k++) { c[k] = l + sat * (c[k] - l); c[k] += bright; c[k] = (c[k] - 0.5f) * contrast + 0.5f; }
}
static void gray_tone(float *c, float contrast, float lift) {
    float l = lumaf(c);
    l = (l - 0.5f) * contrast + 0.5f + lift;
    c[0] = c[1] = c[2] = l;
}
static CIImage *photo_effect(CIImage *im, NSString *e, BOOL extrap) {
    void (^fx)(float *) = nil;
    if ([e isEqualToString:@"Mono"]) fx = ^(float *c) { gray_tone(c, 1, 0); };
    else if ([e isEqualToString:@"Noir"]) fx = ^(float *c) { gray_tone(c, 1.45f, -0.03f); };
    else if ([e isEqualToString:@"Tonal"]) fx = ^(float *c) { gray_tone(c, 1.1f, 0.02f); };
    else if ([e isEqualToString:@"Chrome"]) fx = ^(float *c) { adjust(c, 1.3f, 0, 1.1f); };
    else if ([e isEqualToString:@"Fade"]) fx = ^(float *c) { adjust(c, 0.7f, 0, 1); for (int k = 0; k < 3; k++) c[k] = 0.1f + 0.85f * c[k]; };
    else if ([e isEqualToString:@"Instant"]) fx = ^(float *c) { adjust(c, 0.85f, 0.02f, 0.95f); c[0] *= 1.05f; c[2] *= 0.92f; };
    else if ([e isEqualToString:@"Process"]) fx = ^(float *c) { adjust(c, 0.9f, 0, 1.08f); c[2] = c[2] * 1.08f + 0.02f; };
    else fx = ^(float *c) { adjust(c, 1.05f, 0, 1.05f); c[0] *= 1.08f; c[1] *= 1.02f; c[2] *= 0.9f; };   /* Transfer */
    return perceptual(im, ^(float *c) {
        float lo = extrap ? -INFINITY : 0, hi = extrap ? INFINITY : 1;
        if (!extrap) for (int k = 0; k < 3; k++) c[k] = ci_clamp01(c[k]);
        fx(c);
        for (int k = 0; k < 3; k++) c[k] = fminf(hi, fmaxf(lo, c[k]));
    });
}

/* ---- Otsu threshold of the luminance histogram (whole image, once per render) ---- */
static float otsu_threshold(CIImage *im, const ci_rctx *rc) {
    CGRect e = ci_integral(im.extent);
    if (ci_infinite(e) || CGRectIsEmpty(e)) return 0.5f;
    float *px = ci_render_new(im, e, rc);
    size_t n = (size_t)e.size.width * e.size.height;
    double hist[256] = { 0 }, total = 0;
    for (size_t i = 0; i < n; i++) {
        float *p = px + i * 4; if (p[3] <= 0) continue;
        float c[3] = { p[0] / p[3], p[1] / p[3], p[2] / p[3] };
        hist[(int)lroundf(ci_clamp01(lumaf(c)) * 255)] += 1; total += 1;
    }
    free(px);
    double sum = 0; for (int i = 0; i < 256; i++) sum += i * hist[i];
    double sumB = 0, wB = 0, best = -1; int th = 128;
    for (int t = 0; t < 256; t++) {
        wB += hist[t]; if (wB == 0) continue;
        double wF = total - wB; if (wF == 0) break;
        sumB += t * hist[t];
        double mB = sumB / wB, mF = (sum - sumB) / wF, v = wB * wF * (mB - mF) * (mB - mF);
        if (v > best) { best = v; th = t; }
    }
    return (th + 0.5f) / 255.0f;
}

/* ---- thermal / x-ray gradients ---- */
static void ramp(const float stops[][3], int n, float t, float *c) {
    t = ci_clamp01(t) * (n - 1);
    int i = (int)floorf(t); if (i >= n - 1) i = n - 2;
    float f = t - i;
    for (int k = 0; k < 3; k++) c[k] = mixf(stops[i][k], stops[i + 1][k], f);
}

void ci_register_color_filters(void) {
    /* -------- color adjustment -------- */
    REG(@"CIColorClamp", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float lo[4], hi[4]; const float z[4] = { 0, 0, 0, 0 }, o[4] = { 1, 1, 1, 1 };
        vec4(in[@"inputMinComponents"], lo, z); vec4(in[@"inputMaxComponents"], hi, o);
        fbox L = { { lo[0], lo[1], lo[2], lo[3] } }, H = { { hi[0], hi[1], hi[2], hi[3] } };
        return ci_map(im, ^(float *p) {
            ci_unpremul(p);
            for (int k = 0; k < 4; k++) p[k] = fminf(H.v[k], fmaxf(L.v[k], p[k]));
            ci_premul(p);
        });
    });
    REG(@"CIColorControls", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float s = NUM(kCIInputSaturationKey, 1), b = NUM(kCIInputBrightnessKey, 0), c = NUM(kCIInputContrastKey, 1);
        return ci_map_rgb(im, ^(float *x) { adjust(x, s, b, c); });
    });
    REG(@"CIColorMatrix", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        fbox M; const float d[5][4] = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 }, { 0, 0, 0, 0 } };
        NSString *keys[5] = { @"inputRVector", @"inputGVector", @"inputBVector", @"inputAVector", @"inputBiasVector" };
        for (int i = 0; i < 5; i++) vec4(in[keys[i]], M.v + i * 4, d[i]);
        return ci_map(im, ^(float *p) {
            float a = p[3], c[4] = { a > 0 ? p[0] / a : 0, a > 0 ? p[1] / a : 0, a > 0 ? p[2] / a : 0, a }, o[4];
            for (int i = 0; i < 4; i++) o[i] = M.v[i * 4] * c[0] + M.v[i * 4 + 1] * c[1] + M.v[i * 4 + 2] * c[2] + M.v[i * 4 + 3] * c[3] + M.v[16 + i];
            o[3] = ci_clamp01(o[3]);
            p[0] = o[0] * o[3]; p[1] = o[1] * o[3]; p[2] = o[2] * o[3]; p[3] = o[3];
        });
    });
    REG(@"CIColorPolynomial", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        fbox P; const float d[4] = { 0, 1, 0, 0 };
        vec4(in[@"inputRedCoefficients"], P.v, d); vec4(in[@"inputGreenCoefficients"], P.v + 4, d);
        vec4(in[@"inputBlueCoefficients"], P.v + 8, d); vec4(in[@"inputAlphaCoefficients"], P.v + 12, d);
        return ci_map(im, ^(float *p) {
            ci_unpremul(p);
            for (int k = 0; k < 4; k++) { float v = p[k]; const float *a = P.v + k * 4; p[k] = a[0] + v * (a[1] + v * (a[2] + v * a[3])); }
            p[3] = ci_clamp01(p[3]);
            ci_premul(p);
        });
    });
    REG(@"CIDepthToDisparity", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_map(im, ^(float *p) { for (int k = 0; k < 3; k++) p[k] = p[k] > 0 ? 1 / p[k] : 0; });
    });
    REG(@"CIDisparityToDepth", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_map(im, ^(float *p) { for (int k = 0; k < 3; k++) p[k] = p[k] > 0 ? 1 / p[k] : 0; });
    });
    REG(@"CIExposureAdjust", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = exp2f(NUM(kCIInputEVKey, 0));
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            BOOL lin = !rc->managed || rc->ws.trc == CI_TRC_LINEAR;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4;
                if (lin) { p[0] *= k; p[1] *= k; p[2] *= k; continue; }
                float a = p[3]; if (a <= 0) continue;
                for (int c = 0; c < 3; c++) p[c] = ci_trc_encode(rc->ws.trc, ci_trc_decode(rc->ws.trc, p[c] / a) * k) * a;
            }
        });
    });
    REG(@"CIGammaAdjust", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float g = NUM(@"inputPower", 1);
        return ci_map_rgb(im, ^(float *c) { for (int k = 0; k < 3; k++) c[k] = spow(c[k], g); });
    });
    REG(@"CIHueAdjust", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float ang = NUM(kCIInputAngleKey, 0), cs = cosf(ang), sn = sinf(ang);
        return ci_map_rgb(im, ^(float *c) {          /* rotation of the chroma plane in YIQ */
            float Y = 0.299f * c[0] + 0.587f * c[1] + 0.114f * c[2];
            float I = 0.596f * c[0] - 0.274f * c[1] - 0.322f * c[2];
            float Q = 0.211f * c[0] - 0.523f * c[1] + 0.312f * c[2];
            float I2 = I * cs - Q * sn, Q2 = I * sn + Q * cs;
            c[0] = Y + 0.956f * I2 + 0.621f * Q2; c[1] = Y - 0.272f * I2 - 0.647f * Q2; c[2] = Y - 1.106f * I2 + 1.703f * Q2;
        });
    });
    REG(@"CILinearToSRGBToneCurve", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_map_rgb(im, ^(float *c) { for (int k = 0; k < 3; k++) c[k] = ci_trc_encode(CI_TRC_SRGB, c[k]); });
    });
    REG(@"CISRGBToneCurveToLinear", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_map_rgb(im, ^(float *c) { for (int k = 0; k < 3; k++) c[k] = ci_trc_decode(CI_TRC_SRGB, c[k]); });
    });
    REG(@"CITemperatureAndTint", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIVector *n = in[@"inputNeutral"], *t = in[@"inputTargetNeutral"];
        float src[3], dst[3];
        white_rgb(n ? n.X : 6500, n ? n.Y : 0, src); white_rgb(t ? t.X : 6500, t ? t.Y : 0, dst);
        fbox G = { { dst[0] / src[0], dst[1] / src[1], dst[2] / src[2] } };
        /* keep the brightness of white: normalize the gains by luminance */
        float l = 0.2126f * G.v[0] + 0.7152f * G.v[1] + 0.0722f * G.v[2];
        for (int k = 0; k < 3; k++) G.v[k] /= l;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            size_t np = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < np; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                to_linear(rc, c);
                for (int k = 0; k < 3; k++) c[k] *= G.v[k];
                from_linear(rc, c);
                p[0] = c[0] * a; p[1] = c[1] * a; p[2] = c[2] * a;
            }
        });
    });
    REG(@"CIToneCurve", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        curve5 cv;
        for (int i = 0; i < 5; i++) {
            CGPoint p = ci_point(in[[NSString stringWithFormat:@"inputPoint%d", i]], CGPointMake(i * 0.25, i * 0.25));
            cv.x[i] = (float)p.x; cv.y[i] = (float)p.y;
        }
        cv.extrapolate = ci_num(in[@"inputExtrapolate"], 0) != 0;
        curve_init(&cv);
        /* applied in a perceptual (gamma 2) version of the working space, as Core Image documents */
        return ci_map_rgb(im, ^(float *c) {
            for (int k = 0; k < 3; k++) { float v = c[k] < 0 ? -sqrtf(-c[k]) : sqrtf(c[k]), o = curve_eval(&cv, v); c[k] = o < 0 ? -o * o : o * o; }
        });
    });
    REG(@"CIVibrance", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float amount = NUM(kCIInputAmountKey, 0);
        return ci_map_rgb(im, ^(float *c) {
            float avg = (c[0] + c[1] + c[2]) / 3, mx = fmaxf(c[0], fmaxf(c[1], c[2]));
            float amt = (mx - avg) * (-amount * 3);
            for (int k = 0; k < 3; k++) c[k] = mixf(c[k], mx, amt);
        });
    });
    REG(@"CIWhitePointAdjust", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            float w[4]; ci_color_ws(col, rc, w);
            if (w[3] > 0) { w[0] /= w[3]; w[1] /= w[3]; w[2] /= w[3]; }
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) { float *p = out + i * 4; p[0] *= w[0]; p[1] *= w[1]; p[2] *= w[2]; }
        });
    });
    REG(@"CIColorAbsoluteDifference", {
        CIImage *a = IMG(kCIInputImageKey), *b = IMG(@"inputImage2"); if (!a || !b) return a;
        return ci_combine(a, b, CGRectUnion(a.extent, b.extent), ^(float *o, const float *pa, const float *pb) {
            for (int k = 0; k < 3; k++) o[k] = fabsf(pa[k] - pb[k]);
            o[3] = fmaxf(pa[3], pb[3]);
        });
    });
    REG(@"CIColorThreshold", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float t = NUM(@"inputThreshold", 0.5f);
        return ci_map_rgb(im, ^(float *c) { for (int k = 0; k < 3; k++) c[k] = c[k] > t ? 1 : 0; });
    });
    REG(@"CIColorThresholdOtsu", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        id key = [NSObject new];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float t = [ci_cache_get(rc, key, ^id { return @(otsu_threshold(im, rc)); }) floatValue];
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                for (int k = 0; k < 3; k++) p[k] = p[k] / a > t ? a : 0;
            }
        });
    });
    REG(@"CIToneMapHeadroom", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float S = fmaxf(NUM(@"inputSourceHeadroom", 1), 1e-3f), T = fmaxf(NUM(@"inputTargetHeadroom", 1), 1e-3f);
        if (S <= T) return im;
        float k = 0.8f * T;
        return ci_map_rgb(im, ^(float *c) {         /* values up to the knee kept, above it rolled off toward T */
            float l = fmaxf(c[0], fmaxf(c[1], c[2]));
            if (l <= k) return;
            float x = (l - k) / (S - k), y = k + (T - k) * (1 - expf(-3 * x)) / (1 - expf(-3.0f));
            float s = y / l;
            for (int i = 0; i < 3; i++) c[i] *= s;
        });
    });

    /* iOS 26: tone maps to what the display shows for the preferred dynamic range: standard 1 (SDR), constrainedHigh up
       to 2, high the display's headroom; the image's headroom (contentHeadroom, 1 when unknown) is the source */
    REG(@"CISystemToneMap", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float display = fmaxf(NUM(@"inputDisplayHeadroom", 1), 1);
        NSString *pref = in[@"inputPreferredDynamicRange"];
        float target = [pref isEqual:kCIDynamicRangeStandard] ? 1 : [pref isEqual:kCIDynamicRangeConstrainedHigh] ? fminf(display, 2) : display;
        float source = fmaxf((float)im.isimHeadroom, 1);
        if (source <= target) return im;
        CIImage *r = [im imageByApplyingFilter:@"CIToneMapHeadroom" withInputParameters:@{ @"inputSourceHeadroom": @(source), @"inputTargetHeadroom": @(target) }];
        return [r imageBySettingContentHeadroom:target];
    });

    /* -------- color effect -------- */
    REG(@"CIColorCrossPolynomial", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        fbox P = { { 0 } };
        NSString *keys[3] = { @"inputRedCoefficients", @"inputGreenCoefficients", @"inputBlueCoefficients" };
        for (int c = 0; c < 3; c++) {
            CIVector *v = in[keys[c]];
            for (int i = 0; i < 10; i++) P.v[c * 10 + i] = v && v.count > (size_t)i ? (float)[v valueAtIndex:i] : (i == c ? 1 : 0);
        }
        return ci_map_rgb(im, ^(float *c) {
            float r = c[0], g = c[1], b = c[2], t[10] = { r, g, b, r * r, g * g, b * b, r * g, g * b, b * r, 1 }, o[3] = { 0, 0, 0 };
            for (int k = 0; k < 3; k++) for (int i = 0; i < 10; i++) o[k] += P.v[k * 10 + i] * t[i];
            c[0] = o[0]; c[1] = o[1]; c[2] = o[2];
        });
    });
    REG(@"CIColorCube", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return apply_cube(im, in[@"inputCubeData"], (int)NUM(@"inputCubeDimension", 2), ci_num(in[@"inputExtrapolate"], 0) != 0, nil, nil, nil);
    });
    REG(@"CIColorCubeWithColorSpace", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return apply_cube(im, in[@"inputCubeData"], (int)NUM(@"inputCubeDimension", 2), ci_num(in[@"inputExtrapolate"], 0) != 0, in[@"inputColorSpace"], nil, nil);
    });
    REG(@"CIColorCubesMixedWithMask", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIImage *mask = IMG(@"inputMaskImage");
        return apply_cube(im, in[@"inputCube0Data"], (int)NUM(@"inputCubeDimension", 2), ci_num(in[@"inputExtrapolate"], 0) != 0,
                          in[@"inputColorSpace"], mask ?: [CIImage blackImage], in[@"inputCube1Data"]);
    });
    REG(@"CIColorCurves", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        NSData *d = in[@"inputCurvesData"];
        CIVector *dom = in[@"inputCurvesDomain"];
        float lo = dom ? (float)dom.X : 0, hi = dom ? (float)dom.Y : 1;
        size_t n = [d isKindOfClass:[NSData class]] ? d.length / (3 * sizeof(float)) : 0;
        if (n < 2) return im;
        NSData *curve = [d copy];
        id space = in[@"inputColorSpace"];
        ci_space sp = space ? ci_space_of((__bridge CGColorSpaceRef)space) : ci_space_srgb;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            const float *cv = curve.bytes;
            size_t np = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < np; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                if (rc->managed) ci_convert_rgb(c, rc->ws, sp);
                for (int k = 0; k < 3; k++) {
                    float t = (c[k] - lo) / (hi - lo) * (n - 1);
                    if (t <= 0) { c[k] = cv[k]; continue; }
                    if (t >= n - 1) { c[k] = cv[(n - 1) * 3 + k]; continue; }
                    int j = (int)t; float f = t - j;
                    c[k] = mixf(cv[j * 3 + k], cv[(j + 1) * 3 + k], f);
                }
                if (rc->managed) ci_convert_rgb(c, sp, rc->ws);
                p[0] = c[0] * a; p[1] = c[1] * a; p[2] = c[2] * a;
            }
        });
    });
    REG(@"CIColorInvert", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return perceptual(im, ^(float *c) { for (int k = 0; k < 3; k++) c[k] = 1 - c[k]; });
    });
    REG(@"CIColorMap", {
        CIImage *im = IMG(kCIInputImageKey), *g = IMG(@"inputGradientImage"); if (!im) return nil;
        if (!g || ci_infinite(g.extent) || CGRectIsEmpty(g.extent)) return im;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            CGRect ge = ci_integral(g.extent);
            CGRect row = CGRectMake(ge.origin.x, floor(CGRectGetMidY(ge)), ge.size.width, 1);
            float *grad = ci_render_new(g, row, rc);
            int GW = (int)row.size.width;
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                float l = rc->managed ? ci_trc_encode(CI_TRC_SRGB, ci_clamp01(lumaf(c))) : ci_clamp01(lumaf(c));
                float t = l * (GW - 1); int j = (int)t; if (j >= GW - 1) j = GW - 2; if (j < 0) j = 0;
                float f = GW > 1 ? t - j : 0; const float *g0 = grad + j * 4, *g1 = grad + (GW > 1 ? j + 1 : j) * 4;
                for (int k = 0; k < 4; k++) p[k] = mixf(g0[k], g1[k], f) * a;
            }
            free(grad);
        });
    });
    REG(@"CIColorMonochrome", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:0.6 green:0.45 blue:0.3]);
        float k = NUM(kCIInputIntensityKey, 1);
        fbox C = { { (float)col.red, (float)col.green, (float)col.blue } };
        return perceptual(im, ^(float *c) {          /* luminance overlaid with the color */
            float l = lumaf(c), o[3];
            for (int i = 0; i < 3; i++) o[i] = l < 0.5f ? 2 * l * C.v[i] : 1 - 2 * (1 - l) * (1 - C.v[i]);
            for (int i = 0; i < 3; i++) c[i] = mixf(c[i], o[i], k);
        });
    });
    REG(@"CIColorPosterize", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float levels = fmaxf(2, NUM(@"inputLevels", 6));
        return perceptual(im, ^(float *c) { for (int k = 0; k < 3; k++) c[k] = roundf(ci_clamp01(c[k]) * (levels - 1)) / (levels - 1); });
    });
    REG(@"CIConvertRGBtoLab", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        BOOL norm = ci_num(in[@"inputNormalize"], 0) != 0;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a }, lab[3];
                to_linear(rc, c); rgb_to_lab(c, lab);
                if (norm) { lab[0] /= 100; lab[1] = (lab[1] + 128) / 255; lab[2] = (lab[2] + 128) / 255; }
                p[0] = lab[0] * a; p[1] = lab[1] * a; p[2] = lab[2] * a;
            }
        });
    });
    REG(@"CIConvertLabToRGB", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        BOOL norm = ci_num(in[@"inputNormalize"], 0) != 0;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float lab[3] = { p[0] / a, p[1] / a, p[2] / a }, c[3];
                if (norm) { lab[0] *= 100; lab[1] = lab[1] * 255 - 128; lab[2] = lab[2] * 255 - 128; }
                lab_to_rgb(lab, c); from_linear(rc, c);
                p[0] = c[0] * a; p[1] = c[1] * a; p[2] = c[2] * a;
            }
        });
    });
    REG(@"CIDither", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 0.1f) / 10;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            int W = (int)r.size.width, H = (int)r.size.height;
            BOOL conv = rc->managed && rc->ws.trc == CI_TRC_LINEAR;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                float *p = out + ((size_t)j * W + i) * 4, a = p[3]; if (a <= 0) continue;
                uint32_t h = (uint32_t)((int)(r.origin.x + i) * 73856093) ^ (uint32_t)((int)(ci_px_y(r, j)) * 19349663);
                h ^= h >> 13; h *= 0x5bd1e995; h ^= h >> 15;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                for (int q = 0; q < 3; q++) {
                    float v = conv ? ci_trc_encode(CI_TRC_SRGB, c[q]) : c[q];
                    v += (((h >> (q * 8)) & 0xff) / 255.0f - 0.5f) * k;
                    c[q] = conv ? ci_trc_decode(CI_TRC_SRGB, v) : v;
                }
                p[0] = c[0] * a; p[1] = c[1] * a; p[2] = c[2] * a;
            }
        });
    });
    REG(@"CIDocumentEnhancer", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float amount = NUM(kCIInputAmountKey, 1);
        CGRect e = im.extent;
        return ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
            /* paper background: a wide blur of the image's max channel; divide it out, then stretch contrast */
            double s = fmax(e.size.width, e.size.height) / 40;
            int pad = (int)ceil(3 * s);
            CGRect src = CGRectInset(r, -pad, -pad);
            if (!ci_infinite(e)) src = CGRectIntersection(src, ci_integral(e));
            ci_buf b = ci_buf_render([im imageByClampingToExtent], src, 0, rc);
            int BW = b.w, BH = b.h;
            float *bg = malloc(sizeof(float) * 4 * (size_t)BW * BH);
            for (size_t i = 0; i < (size_t)BW * BH; i++) { float *p = b.px + i * 4; float m = fmaxf(p[0], fmaxf(p[1], p[2])); bg[i * 4] = bg[i * 4 + 1] = bg[i * 4 + 2] = m; bg[i * 4 + 3] = 1; }
            ci_blur_buf(bg, BW, BH, s);
            [im _render:r into:out ctx:rc];
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                float *p = out + ((size_t)j * W + i) * 4, a = p[3]; if (a <= 0) continue;
                const float *q = ci_buf_at(&(ci_buf){ bg, b.r, BW, BH }, (int)r.origin.x + i, (int)ci_px_y(r, j));
                float g = q ? fmaxf(q[0], 0.05f) : 1;
                for (int k = 0; k < 3; k++) {
                    float v = p[k] / a, nv = ci_clamp01(v / g);
                    nv = ci_clamp01((nv - 0.5f) * (1 + 0.3f * amount) + 0.5f + 0.05f * amount);
                    p[k] = mixf(v, nv, fminf(amount, 1)) * a;
                }
            }
            free(bg); ci_buf_free(&b);
        });
    });
    REG(@"CIFalseColor", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIColor *c0 = ci_colorv(in[@"inputColor0"], [CIColor colorWithRed:0.3 green:0 blue:0]), *c1 = ci_colorv(in[@"inputColor1"], [CIColor colorWithRed:1 green:0.9 blue:0.8]);
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float a0[4], a1[4]; ci_color_ws(c0, rc, a0); ci_color_ws(c1, rc, a1);
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                float l = ci_clamp01(rc->managed ? ci_trc_encode(CI_TRC_SRGB, lumaf(c)) : lumaf(c));
                for (int k = 0; k < 4; k++) p[k] = mixf(a0[k], a1[k], l) * a;
            }
        });
    });
    REG(@"CILabDeltaE", {
        CIImage *a = IMG(kCIInputImageKey), *b = IMG(@"inputImage2"); if (!a || !b) return nil;
        return ci_op(CGRectIntersection(a.extent, b.extent), ^(CGRect r, float *out, const ci_rctx *rc) {
            float *fa = ci_render_new(a, r, rc), *fb = ci_render_new(b, r, rc);
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float c1[3], c2[3], l1[3], l2[3];
                for (int k = 0; k < 3; k++) { c1[k] = fa[i * 4 + 3] > 0 ? fa[i * 4 + k] / fa[i * 4 + 3] : 0; c2[k] = fb[i * 4 + 3] > 0 ? fb[i * 4 + k] / fb[i * 4 + 3] : 0; }
                to_linear(rc, c1); to_linear(rc, c2); rgb_to_lab(c1, l1); rgb_to_lab(c2, l2);
                float d = delta_e94(l1, l2);
                out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = d; out[i * 4 + 3] = 1;
            }
            free(fa); free(fb);
        });
    });
    REG(@"CIMaskToAlpha", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, c[3] = { p[0], p[1], p[2] };
                float l = rc->managed ? ci_trc_encode(CI_TRC_SRGB, ci_clamp01(lumaf(c))) : ci_clamp01(lumaf(c));
                p[0] = p[1] = p[2] = p[3] = l;
            }
        });
    });
    REG(@"CIMaximumComponent", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_map_rgb(im, ^(float *c) { c[0] = c[1] = c[2] = fmaxf(c[0], fmaxf(c[1], c[2])); });
    });
    REG(@"CIMinimumComponent", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return ci_map_rgb(im, ^(float *c) { c[0] = c[1] = c[2] = fminf(c[0], fminf(c[1], c[2])); });
    });
    /* palettes: an N x 1 (or N x M) image of colors */
    CIImage *(^palette_op)(NSDictionary *, BOOL) = ^CIImage *(NSDictionary *in, BOOL centroid) {
        CIImage *im = IMG(kCIInputImageKey), *pal = IMG(@"inputPaletteImage"); if (!im) return nil;
        if (!pal || ci_infinite(pal.extent) || CGRectIsEmpty(pal.extent)) return centroid ? nil : im;
        BOOL perceptual_ = ci_num(in[@"inputPerceptual"], 0) != 0;
        CGRect pe = ci_integral(pal.extent);
        int np = (int)(pe.size.width * pe.size.height);
        if (!centroid) return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float *pp = ci_render_new(pal, pe, rc), *lab = malloc(sizeof(float) * 3 * (size_t)np);
            for (int j = 0; j < np; j++) {
                float c[3] = { pp[j * 4], pp[j * 4 + 1], pp[j * 4 + 2] }; if (pp[j * 4 + 3] > 0) for (int k = 0; k < 3; k++) c[k] /= pp[j * 4 + 3];
                if (perceptual_) { to_linear(rc, c); rgb_to_lab(c, lab + j * 3); } else memcpy(lab + j * 3, c, sizeof c);
            }
            [im _render:r into:out ctx:rc];
            size_t n = (size_t)r.size.width * (size_t)r.size.height;
            for (size_t i = 0; i < n; i++) {
                float *p = out + i * 4, a = p[3]; if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a }, q[3];
                if (perceptual_) { to_linear(rc, c); rgb_to_lab(c, q); } else memcpy(q, c, sizeof q);
                int best = 0; float bd = INFINITY;
                for (int j = 0; j < np; j++) { float d = 0; for (int k = 0; k < 3; k++) d += (q[k] - lab[j * 3 + k]) * (q[k] - lab[j * 3 + k]); if (d < bd) { bd = d; best = j; } }
                float pa = pp[best * 4 + 3] > 0 ? pp[best * 4 + 3] : 1;
                for (int k = 0; k < 3; k++) p[k] = pp[best * 4 + k] / pa * a;
            }
            free(pp); free(lab);
        });
        /* centroid: for each palette color, the mean position of the pixels nearest to it -> (x, y, count, 1) */
        CGRect e = ci_integral(im.extent);
        if (ci_infinite(e)) return nil;
        id key = [NSObject new];
        return ci_op(CGRectMake(0, 0, np, 1), ^(CGRect r, float *out, const ci_rctx *rc) {
            NSData *res = ci_cache_get(rc, key, ^id {
                float *pp = ci_render_new(pal, pe, rc), *px = ci_render_new(im, e, rc);
                double *acc = calloc((size_t)np * 3, sizeof(double));
                int W = (int)e.size.width, H = (int)e.size.height;
                for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                    float *p = px + ((size_t)j * W + i) * 4; if (p[3] <= 0) continue;
                    float c[3] = { p[0] / p[3], p[1] / p[3], p[2] / p[3] };
                    int best = 0; float bd = INFINITY;
                    for (int q = 0; q < np; q++) { float d = 0, pa = pp[q * 4 + 3] > 0 ? pp[q * 4 + 3] : 1; for (int k = 0; k < 3; k++) { float t = c[k] - pp[q * 4 + k] / pa; d += t * t; } if (d < bd) { bd = d; best = q; } }
                    acc[best * 3] += ci_px_x(e, i); acc[best * 3 + 1] += ci_px_y(e, j); acc[best * 3 + 2] += 1;
                }
                float *o = malloc(sizeof(float) * 4 * (size_t)np);
                for (int q = 0; q < np; q++) {
                    double c = acc[q * 3 + 2];
                    o[q * 4] = c ? (float)(acc[q * 3] / c) : 0; o[q * 4 + 1] = c ? (float)(acc[q * 3 + 1] / c) : 0; o[q * 4 + 2] = (float)c; o[q * 4 + 3] = 1;
                }
                free(pp); free(px); free(acc);
                return [NSData dataWithBytesNoCopy:o length:sizeof(float) * 4 * (size_t)np];
            });
            const float *o = res.bytes;
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                int x = (int)r.origin.x + i, y = (int)ci_px_y(r, j);
                if (y == 0 && x >= 0 && x < np) memcpy(out + ((size_t)j * W + i) * 4, o + x * 4, 4 * sizeof(float));
            }
        });
    };
    REG(@"CIPalettize", { return palette_op(in, NO); });
    REG(@"CIPaletteCentroid", { return palette_op(in, YES); });
    for (NSString *e in @[ @"Chrome", @"Fade", @"Instant", @"Mono", @"Noir", @"Process", @"Tonal", @"Transfer" ]) {
        ci_register_impl([@"CIPhotoEffect" stringByAppendingString:e], ^CIImage *(NSDictionary *in) {
            CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
            return photo_effect(im, e, ci_num(in[@"inputExtrapolate"], 0) != 0);
        });
    }
    REG(@"CISepiaTone", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 1);
        return perceptual(im, ^(float *c) {
            float r = 0.393f * c[0] + 0.769f * c[1] + 0.189f * c[2], g = 0.349f * c[0] + 0.686f * c[1] + 0.168f * c[2], b = 0.272f * c[0] + 0.534f * c[1] + 0.131f * c[2];
            c[0] = mixf(c[0], fminf(r, 1), k); c[1] = mixf(c[1], fminf(g, 1), k); c[2] = mixf(c[2], fminf(b, 1), k);
        });
    });
    REG(@"CIThermal", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        static const float stops[][3] = { { 0, 0, 0.1f }, { 0.1f, 0, 0.6f }, { 0.6f, 0, 0.6f }, { 0.9f, 0.1f, 0.1f }, { 1, 0.6f, 0 }, { 1, 1, 0.2f }, { 1, 1, 1 } };
        return perceptual(im, ^(float *c) { ramp(stops, 7, lumaf(c), c); });
    });
    REG(@"CIXRay", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        static const float stops[][3] = { { 1, 1, 1 }, { 0.55f, 0.65f, 0.75f }, { 0.05f, 0.08f, 0.12f } };
        return perceptual(im, ^(float *c) { ramp(stops, 3, lumaf(c), c); });
    });
    REG(@"CIVignette", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float k = NUM(kCIInputIntensityKey, 0), rad = fmaxf(NUM(kCIInputRadiusKey, 1), 0.01f);
        CGRect e = im.extent;
        if (ci_infinite(e)) return im;
        double cx = CGRectGetMidX(e), cy = CGRectGetMidY(e), R = hypot(e.size.width, e.size.height) / 2;
        return ci_map_xy(im, e, ^(double x, double y, float *p) {
            float d = (float)(hypot(x - cx, y - cy) / (R > 0 ? R : 1));
            float f = 1 - k * smoothf(0.6f * (1 - rad / 2.5f), 1.0f + 0.5f * rad, d * 1.2f);
            f = fmaxf(f, 0);
            p[0] *= f; p[1] *= f; p[2] *= f;
        });
    });
    REG(@"CIVignetteEffect", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = ci_point(in[kCIInputCenterKey], CGPointMake(150, 150));
        float rad = fmaxf(NUM(kCIInputRadiusKey, 150), 1e-3f), k = NUM(kCIInputIntensityKey, 1), fall = ci_clamp01(NUM(@"inputFalloff", 0.5f));
        return ci_map_xy(im, im.extent, ^(double x, double y, float *p) {
            float d = (float)hypot(x - c.x, y - c.y);
            float f = 1 - k * smoothf(rad * (1 - fall), rad * (1 + fall * 0.25f) + 1e-3f, d);
            f = fmaxf(f, 0);
            p[0] *= f; p[1] *= f; p[2] *= f;
        });
    });
}
