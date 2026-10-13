// isim Core Image filters: halftone screens (CICategoryHalftoneEffect). Adapted: the screen pattern is computed per
// pixel from its position in a cell (rotated by inputAngle around inputCenter, inputWidth wide) and compared with the
// pixel's perceptual (sRGB-encoded) luminance; inputSharpness narrows the anti-aliased edge. Monochrome screens give
// black ink on white (alpha kept); CICMYKHalftone screens cyan, magenta, yellow and black at the classic 15° / 75° /
// 0° / 45° angles with gray component replacement and under color removal.
#import "CIFilterImpl.h"

typedef struct { double cx, cy, ca, sa, w, edge; } screen_t;
static screen_t screen_of(NSDictionary *in, double angle) {
    CGPoint c = PT(kCIInputCenterKey, 150, 150);
    double w = fmax(1, NUM(kCIInputWidthKey, 6)), sharp = fmin(1, fmax(0, NUM(kCIInputSharpnessKey, 0.7)));
    return (screen_t){ c.x, c.y, cos(angle), sin(angle), w, 0.01 + (1 - sharp) * 0.3 };
}
/* (u, v): the position in screen cells, rotated */
static void cell(const screen_t *s, double x, double y, double *u, double *v) {
    double dx = x - s->cx, dy = y - s->cy;
    *u = (dx * s->ca + dy * s->sa) / s->w; *v = (-dx * s->sa + dy * s->ca) / s->w;
}
static double fracc(double a) { return a - floor(a) - 0.5; }       /* -0.5 ... 0.5 from the cell center */
/* white where the tone is lighter than the pattern threshold t (0 = cell center, 1 = cell edge) */
static float screen_px(float tone, double t, double edge) {
    double d = tone - (1 - t);
    return (float)(d <= -edge ? 0 : d >= edge ? 1 : (d + edge) / (2 * edge));
}
/* a monochrome screen: pattern(u, v, tone) -> threshold position */
static CIImage *mono_screen(NSDictionary *in, double angle, double (^pattern)(double u, double v, double x, double y, float tone, const screen_t *s)) {
    CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
    screen_t s = screen_of(in, angle);
    return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [im _render:r into:out ctx:rc];
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            float *p = out + ((size_t)j * W + i) * 4, a = p[3];
            if (a <= 0) continue;
            float c[3] = { p[0] / a, p[1] / a, p[2] / a };
            if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_srgb);
            float tone = fminf(1, fmaxf(0, lumaf(c)));
            double x = ci_px_x(r, i), y = ci_px_y(r, j), u, v;
            cell(&s, x, y, &u, &v);
            float g = screen_px(tone, pattern(u, v, x, y, tone, &s), s.edge);
            float o[3] = { g, g, g };
            if (rc->managed) ci_convert_rgb(o, ci_space_srgb, rc->ws);
            p[0] = o[0] * a; p[1] = o[1] * a; p[2] = o[2] * a;
        }
    });
}

void ci_register_halftone_filters(void) {
    REG(@"CIDotScreen", {
        return mono_screen(in, NUM(kCIInputAngleKey, 0), ^double(double u, double v, double x, double y, float tone, const screen_t *s) {
            return fmin(1, hypot(fracc(u), fracc(v)) / M_SQRT1_2);
        });
    });
    REG(@"CILineScreen", {
        return mono_screen(in, NUM(kCIInputAngleKey, 0), ^double(double u, double v, double x, double y, float tone, const screen_t *s) {
            return fabs(fracc(v)) * 2;
        });
    });
    REG(@"CICircularScreen", {
        return mono_screen(in, 0, ^double(double u, double v, double x, double y, float tone, const screen_t *s) {
            return fabs(fracc(hypot(u, v))) * 2;
        });
    });
    REG(@"CIHatchedScreen", {
        /* light tones: lines in one direction; darker tones add the crossing lines */
        return mono_screen(in, NUM(kCIInputAngleKey, 0), ^double(double u, double v, double x, double y, float tone, const screen_t *s) {
            double t1 = fabs(fracc(v)) * 2, t2 = fabs(fracc(u)) * 2;
            return tone >= 0.5f ? 0.5 + t1 * 0.5 : fmin(t1, t2 * 0.5 + 0.25);
        });
    });
    REG(@"CICMYKHalftone", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double angle = NUM(kCIInputAngleKey, 0), gcr = fmin(1, fmax(0, NUM(@"inputGCR", 1))), ucr = fmin(1, fmax(0, NUM(@"inputUCR", 0.5)));
        typedef struct { screen_t s[4]; } screens_t;     /* blocks cannot capture arrays */
        screens_t S;
        const double deg[4] = { 15, 75, 0, 45 };          /* C, M, Y, K */
        for (int k = 0; k < 4; k++) S.s[k] = screen_of(in, angle + deg[k] * M_PI / 180);
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            [im _render:r into:out ctx:rc];
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                float *p = out + ((size_t)j * W + i) * 4, a = p[3];
                if (a <= 0) continue;
                float c[3] = { p[0] / a, p[1] / a, p[2] / a };
                if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_srgb);
                double cmy[3], ink[4];
                for (int q = 0; q < 3; q++) cmy[q] = 1 - fmin(1, fmax(0, c[q]));
                double kk = fmin(cmy[0], fmin(cmy[1], cmy[2])) * gcr;
                for (int q = 0; q < 3; q++) ink[q] = fmax(0, cmy[q] - kk * ucr);
                ink[3] = kk;
                double x = ci_px_x(r, i), y = ci_px_y(r, j), cov[4];
                for (int q = 0; q < 4; q++) {      /* ink coverage of this pixel: the dot of that screen */
                    double u, v; cell(&S.s[q], x, y, &u, &v);
                    cov[q] = 1 - screen_px((float)(1 - ink[q]), fmin(1, hypot(fracc(u), fracc(v)) / M_SQRT1_2), S.s[q].edge);
                }
                float o[3];
                for (int q = 0; q < 3; q++) o[q] = (float)((1 - cov[q]) * (1 - cov[3]));
                if (rc->managed) ci_convert_rgb(o, ci_space_srgb, rc->ws);
                p[0] = o[0] * a; p[1] = o[1] * a; p[2] = o[2] * a;
            }
        });
    });
}
