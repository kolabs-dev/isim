// isim Core Image filters: tile effects. Each folds the plane into a tile's fundamental domain (in a frame at
// `center`, rotated by `angle`, `width` per tile) and samples the image there; the results are infinite images.
#import "CIFilterImpl.h"

CI_HIDDEN BOOL ci_homography(const double *src, const double *dst, double *H);

typedef void (^fold_fn)(double *u, double *v);
static double mirror(double t) { t = fmod(t, 2); if (t < 0) t += 2; return t <= 1 ? t : 2 - t; }
static double wrap(double t) { return t - floor(t); }
/* a tile filter: frame (center, angle, width) + a fold of the frame coordinates */
static CIImage *tiled(CIImage *im, CGPoint c, double angle, double w, fold_fn fold) {
    w = fmax(w, 1e-3);
    double cs = cos(angle), sn = sin(angle);
    CIImage *src = [im imageByClampingToExtent];
    return ci_warp(src, CGRectInfinite, ^(double x, double y, double *sx, double *sy) {
        double dx = x - c.x, dy = y - c.y, u = (dx * cs + dy * sn) / w, v = (-dx * sn + dy * cs) / w;
        fold(&u, &v);
        *sx = c.x + (u * cs - v * sn) * w; *sy = c.y + (u * sn + v * cs) * w;
    });
}
/* hexagonal lattice: the nearest center (unit spacing) */
static void hex_local(double *u, double *v) {
    double b = *v / (sqrt(3) / 2), a = *u - b * 0.5;
    double best = INFINITY, bu = 0, bv = 0;
    for (int i = 0; i <= 1; i++) for (int j = 0; j <= 1; j++) {
        double ia = floor(a) + i, ib = floor(b) + j, cu = ia + ib * 0.5, cv = ib * sqrt(3) / 2;
        double d = (*u - cu) * (*u - cu) + (*v - cv) * (*v - cv);
        if (d < best) { best = d; bu = cu; bv = cv; }
    }
    *u -= bu; *v -= bv;
}
static void polar_fold(double *u, double *v, double wedge, BOOL reflect) {
    double r = hypot(*u, *v), a = atan2(*v, *u);
    double m = fmod(a, reflect ? 2 * wedge : wedge); if (m < 0) m += reflect ? 2 * wedge : wedge;
    if (reflect && m > wedge) m = 2 * wedge - m;
    *u = r * cos(m); *v = r * sin(m);
}

void ci_register_tile_filters(void) {
    REG(@"CIAffineClamp", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return [[im imageByApplyingTransform:ci_xform(in[kCIInputTransformKey])] imageByClampingToExtent];
    });
    REG(@"CIAffineTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CIImage *t = [im imageByApplyingTransform:ci_xform(in[kCIInputTransformKey])];
        CGRect e = t.extent;
        if (ci_infinite(e) || CGRectIsEmpty(e)) return t;
        return ci_warp(t, CGRectInfinite, ^(double x, double y, double *sx, double *sy) {
            *sx = e.origin.x + wrap((x - e.origin.x) / e.size.width) * e.size.width;
            *sy = e.origin.y + wrap((y - e.origin.y) / e.size.height) * e.size.height;
        });
    });
#define FRAME CGPoint c = PT(kCIInputCenterKey, 150, 150); double ang = NUM(kCIInputAngleKey, 0), w = NUM(kCIInputWidthKey, 100)
    REG(@"CIFourfoldTranslatedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        double al = NUM(@"inputAcuteAngle", M_PI / 2), ca = cos(al), sa = sin(al);
        return tiled(im, c, ang, w, ^(double *u, double *v) {
            double b = *v / sa, a = *u - b * ca; a = wrap(a); b = wrap(b);
            *u = a + b * ca; *v = b * sa;
        });
    });
    REG(@"CIParallelogramTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        double al = NUM(@"inputAcuteAngle", M_PI / 2), ca = cos(al), sa = sin(al);
        return tiled(im, c, ang, w, ^(double *u, double *v) {
            double b = *v / sa, a = *u - b * ca; a = mirror(a); b = wrap(b);
            *u = a + b * ca; *v = b * sa;
        });
    });
    REG(@"CIFourfoldReflectedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        double al = NUM(@"inputAcuteAngle", M_PI / 2), ca = cos(al), sa = sin(al);
        return tiled(im, c, ang, w, ^(double *u, double *v) {
            double b = *v / sa, a = *u - b * ca; a = mirror(a); b = mirror(b);
            *u = a + b * ca; *v = b * sa;
        });
    });
    REG(@"CIFourfoldRotatedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) {
            long i = (long)floor(*u), j = (long)floor(*v);
            double fu = *u - i - 0.5, fv = *v - j - 0.5;
            int k = (int)((i & 1) + 2 * (j & 1));
            for (int r = 0; r < k; r++) { double t = fu; fu = -fv; fv = t; }
            *u = fu + 0.5; *v = fv + 0.5;
        });
    });
    REG(@"CIEightfoldReflectedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) {
            double a = mirror(*u), b = mirror(*v);
            if (b > a) { double t = a; a = b; b = t; }         /* the diagonal mirror */
            *u = a; *v = b;
        });
    });
    REG(@"CIGlideReflectedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) {
            long j = (long)floor(*v);
            double a = (j & 1) ? 1 - wrap(*u + 0.5) : wrap(*u);
            *u = a; *v = wrap(*v);
        });
    });
    REG(@"CISixfoldRotatedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) { hex_local(u, v); polar_fold(u, v, M_PI / 3, NO); });
    });
    REG(@"CISixfoldReflectedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) { hex_local(u, v); polar_fold(u, v, M_PI / 3, YES); });
    });
    REG(@"CITwelvefoldReflectedTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) { hex_local(u, v); polar_fold(u, v, M_PI / 6, YES); });
    });
    REG(@"CITriangleTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil; FRAME;
        return tiled(im, c, ang, w, ^(double *u, double *v) { hex_local(u, v); polar_fold(u, v, 2 * M_PI / 3, NO); });
    });
#undef FRAME
    REG(@"CIKaleidoscope", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double ang = NUM(kCIInputAngleKey, 0);
        int n = (int)lround(fmax(1, NUM(@"inputCount", 6)));
        double wedge = M_PI / n;
        return ci_warp([im imageByClampingToExtent], CGRectInfinite, ^(double x, double y, double *sx, double *sy) {
            double dx = x - c.x, dy = y - c.y, r = hypot(dx, dy), a = atan2(dy, dx) - ang;
            double m = fmod(a, 2 * wedge); if (m < 0) m += 2 * wedge;
            if (m > wedge) m = 2 * wedge - m;
            *sx = c.x + r * cos(m + ang); *sy = c.y + r * sin(m + ang);
        });
    });
    REG(@"CITriangleKaleidoscope", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint p = PT(@"inputPoint", 150, 150);
        double size = fmax(NUM(@"inputSize", 700), 1), rot = NUM(@"inputRotation", 5.924f), decay = NUM(@"inputDecay", 0.85f);
        double cs = cos(rot), sn = sin(rot), side = size / 4;
        CIImage *src = [im imageByClampingToExtent];
        return ci_op(CGRectInfinite, ^(CGRect r, float *out, const ci_rctx *rc) {
            /* the equilateral triangle at `point` (side size / 4, rotated) reflected across its edges to fill the plane */
            CGRect tri = CGRectMake(p.x - side * 1.2, p.y - side * 1.2, side * 2.4, side * 2.4);
            ci_buf b = ci_buf_render(src, tri, 2, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                double dx = ci_px_x(r, i) - p.x, dy = ci_px_y(r, j) - p.y;
                double u = (dx * cs + dy * sn) / side, v = (-dx * sn + dy * cs) / side;
                int refl = 0;
                for (int it = 0; it < 64; it++) {      /* fold into the triangle (0,0) (1,0) (0.5, sqrt3/2) */
                    BOOL changed = NO;
                    if (v < 0) { v = -v; changed = YES; }
                    double s3 = sqrt(3);
                    double d1 = (s3 * u - v) / 2;                  /* edge through (0,0) and the top */
                    if (d1 < 0) { u -= s3 * d1; v += d1; changed = YES; }
                    double d2 = (s3 * (1 - u) - v) / 2;            /* edge through (1,0) and the top */
                    if (d2 < 0) { u += s3 * d2; v += d2; changed = YES; }
                    if (!changed) break;
                    refl++;
                }
                float *o = out + ((size_t)j * W + i) * 4;
                ci_sample_clamped(&b, p.x + (u * cs - v * sn) * side, p.y + (u * sn + v * cs) * side, CI_SAMPLE_LINEAR, o);
                float k = (float)pow(decay, refl / 6.0);
                for (int q = 0; q < 3; q++) o[q] *= k;
            }
            ci_buf_free(&b);
        });
    });
    REG(@"CIOpTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double s = fmax(NUM(kCIInputScaleKey, 2.8f), 1e-3), a = NUM(kCIInputAngleKey, 0), w = fmax(NUM(kCIInputWidthKey, 65), 1);
        double cs = cos(a), sn = sin(a);
        return ci_warp([im imageByClampingToExtent], CGRectInfinite, ^(double x, double y, double *sx, double *sy) {
            /* each tile shows the image around the tile's center, scaled and rotated */
            double cx = c.x + (floor((x - c.x) / w) + 0.5) * w, cy = c.y + (floor((y - c.y) / w) + 0.5) * w;
            double dx = (x - cx) / s, dy = (y - cy) / s;
            *sx = cx + dx * cs - dy * sn; *sy = cy + dx * sn + dy * cs;
        });
    });
    REG(@"CIPerspectiveTile", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e) || CGRectIsEmpty(e)) return im;
        CGPoint tl = PT(@"inputTopLeft", 118, 484), tr = PT(@"inputTopRight", 646, 507), br = PT(@"inputBottomRight", 548, 140), bl = PT(@"inputBottomLeft", 155, 153);
        double q[8] = { tl.x, tl.y, tr.x, tr.y, br.x, br.y, bl.x, bl.y };
        double s[8] = { e.origin.x, CGRectGetMaxY(e), CGRectGetMaxX(e), CGRectGetMaxY(e), CGRectGetMaxX(e), e.origin.y, e.origin.x, e.origin.y };
        double H[9]; if (!ci_homography(q, s, H)) return im;       /* output -> image (inverse map) */
        typedef struct { double v[9]; } hb; hb Hb; memcpy(Hb.v, H, sizeof H);
        return ci_warp(im, CGRectInfinite, ^(double x, double y, double *sx, double *sy) {
            double ww = Hb.v[6] * x + Hb.v[7] * y + Hb.v[8];
            if (ww <= 0) { *sx = *sy = NAN; return; }
            double u = (Hb.v[0] * x + Hb.v[1] * y + Hb.v[2]) / ww, v = (Hb.v[3] * x + Hb.v[4] * y + Hb.v[5]) / ww;
            *sx = e.origin.x + wrap((u - e.origin.x) / e.size.width) * e.size.width;
            *sy = e.origin.y + wrap((v - e.origin.y) / e.size.height) * e.size.height;
        });
    });
}
