// isim Core Image filters: geometry adjustment (scaling, perspective, keystone, straighten, upsampling).
#import "CIFilterImpl.h"

/* ---- homographies ---- */
/* solves the 8 parameters mapping 4 points src -> dst (x' = (h0 x + h1 y + h2) / (h6 x + h7 y + 1), ...) */
CI_HIDDEN BOOL ci_homography(const double *src, const double *dst, double *H);
BOOL ci_homography(const double *src, const double *dst, double *H) {
    double A[8][9];
    for (int i = 0; i < 4; i++) {
        double x = src[i * 2], y = src[i * 2 + 1], u = dst[i * 2], v = dst[i * 2 + 1];
        double r0[9] = { x, y, 1, 0, 0, 0, -u * x, -u * y, u }, r1[9] = { 0, 0, 0, x, y, 1, -v * x, -v * y, v };
        memcpy(A[i * 2], r0, sizeof r0); memcpy(A[i * 2 + 1], r1, sizeof r1);
    }
    for (int c = 0; c < 8; c++) {
        int p = c; for (int r = c + 1; r < 8; r++) if (fabs(A[r][c]) > fabs(A[p][c])) p = r;
        if (fabs(A[p][c]) < 1e-12) return NO;
        if (p != c) for (int k = 0; k < 9; k++) { double t = A[c][k]; A[c][k] = A[p][k]; A[p][k] = t; }
        for (int r = 0; r < 8; r++) {
            if (r == c) continue;
            double f = A[r][c] / A[c][c];
            for (int k = c; k < 9; k++) A[r][k] -= f * A[c][k];
        }
    }
    for (int i = 0; i < 8; i++) H[i] = A[i][8] / A[i][i];
    H[8] = 1;
    return YES;
}
static void hmap(const double *H, double x, double y, double *u, double *v) {
    double w = H[6] * x + H[7] * y + H[8];
    *u = (H[0] * x + H[1] * y + H[2]) / w; *v = (H[3] * x + H[4] * y + H[5]) / w;
}
static BOOL hinvert(const double *H, double *I) {
    double a = H[0], b = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7], i = H[8];
    double A = e * i - f * h, B = -(d * i - f * g), C = d * h - e * g, det = a * A + b * B + c * C;
    if (fabs(det) < 1e-15) return NO;
    I[0] = A / det; I[1] = -(b * i - c * h) / det; I[2] = (b * f - c * e) / det;
    I[3] = B / det; I[4] = (a * i - c * g) / det; I[5] = -(a * f - c * d) / det;
    I[6] = C / det; I[7] = -(a * h - b * g) / det; I[8] = (a * e - b * d) / det;
    return YES;
}
typedef struct { double v[9]; } hbox;
/* the image warped by the homography (forward map H); extent: given, or the bounds of the mapped extent */
CI_HIDDEN CIImage *ci_homography_warp(CIImage *im, const double *H, CGRect extent);
CIImage *ci_homography_warp(CIImage *im, const double *H, CGRect extent) {
    hbox I;
    if (!hinvert(H, I.v)) return [CIImage emptyImage];
    if (CGRectIsNull(extent)) {
        CGRect e = im.extent;
        if (ci_infinite(e)) extent = CGRectInfinite;
        else {
            double pts[8] = { e.origin.x, e.origin.y, CGRectGetMaxX(e), e.origin.y, CGRectGetMaxX(e), CGRectGetMaxY(e), e.origin.x, CGRectGetMaxY(e) };
            double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
            for (int k = 0; k < 4; k++) {
                double u, v; hmap(H, pts[k * 2], pts[k * 2 + 1], &u, &v);
                x0 = fmin(x0, u); y0 = fmin(y0, v); x1 = fmax(x1, u); y1 = fmax(y1, v);
            }
            extent = CGRectMake(x0, y0, x1 - x0, y1 - y0);
        }
    }
    return ci_warp(im, extent, ^(double x, double y, double *sx, double *sy) {
        double w = I.v[6] * x + I.v[7] * y + I.v[8];
        if (w <= 0) { *sx = *sy = NAN; return; }
        hmap(I.v, x, y, sx, sy);
    });
}

/* ---- separable resampling with a kernel (bicubic B/C, Lanczos) ---- */
typedef float (^kern_fn)(float x);
static CIImage *resample(CIImage *im, double sx, double sy, float support, kern_fn k) {
    if (sx <= 0 || sy <= 0) return [CIImage emptyImage];
    CGRect e = im.extent;
    CGRect oe = ci_infinite(e) ? CGRectInfinite : CGRectMake(e.origin.x * sx, e.origin.y * sy, e.size.width * sx, e.size.height * sy);
    CIImage *clamped = [im imageByClampingToExtent];
    return [ci_op(oe, ^(CGRect r, float *out, const ci_rctx *rc) {
        /* kernel width grows when downsampling (each output pixel covers 1/s input pixels) */
        double fx = sx < 1 ? 1 / sx : 1, fy = sy < 1 ? 1 / sy : 1;
        double rx = support * fx, ry = support * fy;
        CGRect src = CGRectMake(floor(r.origin.x / sx - rx) - 1, floor(r.origin.y / sy - ry) - 1, ceil(r.size.width / sx + 2 * rx) + 3, ceil(r.size.height / sy + 2 * ry) + 3);
        if (!ci_infinite(e)) src = CGRectIntersection(src, CGRectInset(ci_integral(e), -1, -1));
        if (CGRectIsNull(src) || CGRectIsEmpty(src)) return;
        ci_buf b = ci_buf_render(clamped, src, 0, rc);
        int W = (int)r.size.width, H = (int)r.size.height;
        /* horizontal pass: rows of b at output x positions */
        float *tmp = calloc((size_t)W * b.h * 4, sizeof(float));
        for (int i = 0; i < W; i++) {
            double cx = (ci_px_x(r, i)) / sx;                     /* source x (CI coords) */
            double bx = cx - b.r.origin.x - 0.5;                  /* buffer column coordinate */
            int x0 = (int)floor(bx - rx), x1 = (int)ceil(bx + rx);
            double wsum = 0; float acc_w[256]; int idx[256]; int n = 0;
            for (int x = x0; x <= x1 && n < 256; x++) {
                float w = k((float)((x - bx) / fx));
                if (w == 0) continue;
                int xc = x < 0 ? 0 : x >= b.w ? b.w - 1 : x;
                acc_w[n] = w; idx[n] = xc; n++; wsum += w;
            }
            for (int y = 0; y < b.h; y++) {
                float a[4] = { 0 };
                for (int q = 0; q < n; q++) { const float *p = b.px + ((size_t)y * b.w + idx[q]) * 4; for (int c = 0; c < 4; c++) a[c] += p[c] * acc_w[q]; }
                for (int c = 0; c < 4; c++) tmp[((size_t)y * W + i) * 4 + c] = wsum ? (float)(a[c] / wsum) : 0;
            }
        }
        for (int j = 0; j < H; j++) {
            double cy = ci_px_y(r, j) / sy;
            double by = (b.r.origin.y + b.r.size.height) - cy - 0.5;   /* buffer row coordinate (top-down) */
            int y0 = (int)floor(by - ry), y1 = (int)ceil(by + ry);
            double wsum = 0; float aw[256]; int idx[256]; int n = 0;
            for (int y = y0; y <= y1 && n < 256; y++) {
                float w = k((float)((y - by) / fy));
                if (w == 0) continue;
                aw[n] = w; idx[n] = y < 0 ? 0 : y >= b.h ? b.h - 1 : y; n++; wsum += w;
            }
            for (int i = 0; i < W; i++) {
                float a[4] = { 0 };
                for (int q = 0; q < n; q++) { const float *p = tmp + ((size_t)idx[q] * W + i) * 4; for (int c = 0; c < 4; c++) a[c] += p[c] * aw[q]; }
                for (int c = 0; c < 4; c++) out[((size_t)j * W + i) * 4 + c] = wsum ? (float)(a[c] / wsum) : 0;
            }
        }
        free(tmp); ci_buf_free(&b);
    }) imageByCroppingToRect:oe];
}
static kern_fn mitchell(float B, float C) {
    return ^float(float x) {
        x = fabsf(x);
        if (x < 1) return ((12 - 9 * B - 6 * C) * x * x * x + (-18 + 12 * B + 6 * C) * x * x + (6 - 2 * B)) / 6;
        if (x < 2) return ((-B - 6 * C) * x * x * x + (6 * B + 30 * C) * x * x + (-12 * B - 48 * C) * x + (8 * B + 24 * C)) / 6;
        return 0;
    };
}
static float sinc(float x) { if (fabsf(x) < 1e-6f) return 1; float px = (float)M_PI * x; return sinf(px) / px; }

/* ---- dominant tilt: the angle of the image's strongest near-horizontal / near-vertical edges ---- */
double ci_dominant_tilt(CIImage *im) {
    CGRect e = im.extent;
    if (ci_infinite(e) || CGRectIsEmpty(e)) return 0;
    double s = fmin(1, 400.0 / fmax(e.size.width, e.size.height));
    CIImage *small = [im imageByApplyingTransform:CGAffineTransformMakeScale(s, s) highQualityDownsample:YES];
    CGRect se = ci_integral(small.extent);
    ci_rctx rc = ci_rctx_default(); rc.cache = ci_cache_new();
    float *px = ci_render_new(small, se, &rc);
    ci_cache_free(rc.cache);
    int W = (int)se.size.width, H = (int)se.size.height;
    double hist[181] = { 0 };     /* -45...45 degrees in 0.5 degree bins */
    for (int y = 1; y < H - 1; y++) for (int x = 1; x < W - 1; x++) {
#define L(xx, yy) lumaf(px + ((size_t)(yy) * W + (xx)) * 4)
        float gx = (L(x + 1, y - 1) + 2 * L(x + 1, y) + L(x + 1, y + 1)) - (L(x - 1, y - 1) + 2 * L(x - 1, y) + L(x - 1, y + 1));
        float gy = (L(x - 1, y + 1) + 2 * L(x, y + 1) + L(x + 1, y + 1)) - (L(x - 1, y - 1) + 2 * L(x, y - 1) + L(x + 1, y - 1));
#undef L
        float m = hypotf(gx, gy);
        if (m < 0.2f) continue;
        double a = atan2(gy, gx) * 180 / M_PI;          /* gradient direction; edges are perpendicular */
        a = fmod(a + 360, 90);                           /* fold to 0...90 */
        if (a >= 45) a -= 90;                            /* -45...45 */
        int bin = (int)lround((a + 45) * 2);
        if (bin >= 0 && bin <= 180) hist[bin] += m;
    }
    free(px);
    int best = 90; double bv = 0;
    for (int i = 0; i <= 180; i++) { double v = (i > 0 ? hist[i - 1] : 0) * 0.5 + hist[i] + (i < 180 ? hist[i + 1] : 0) * 0.5; if (v > bv) { bv = v; best = i; } }
    double deg = best / 2.0 - 45;
    /* image rows are top-down: a gradient angle a in buffer space is -a in Core Image space */
    return -deg * M_PI / 180;
}

static void MUL(const double *A, const double *B, double *C) {
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) C[i * 3 + j] = A[i * 3] * B[j] + A[i * 3 + 1] * B[3 + j] + A[i * 3 + 2] * B[6 + j];
}
/* quad corners from the inputs: TL TR BR BL */
static void quad_of(NSDictionary *in, double q[8]) {
    CGPoint tl = PT(@"inputTopLeft", 118, 484), tr = PT(@"inputTopRight", 646, 507), br = PT(@"inputBottomRight", 548, 140), bl = PT(@"inputBottomLeft", 155, 153);
    double v[8] = { tl.x, tl.y, tr.x, tr.y, br.x, br.y, bl.x, bl.y };
    memcpy(q, v, sizeof v);
}

void ci_register_geometry_filters(void) {
    REG(@"CIAffineTransform", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return [im imageByApplyingTransform:ci_xform(in[kCIInputTransformKey]) highQualityDownsample:YES];
    });
    REG(@"CICrop", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        return [im imageByCroppingToRect:ci_rect(in[@"inputRectangle"], CGRectInfinite)];
    });
    REG(@"CIBicubicScaleTransform", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float s = NUM(kCIInputScaleKey, 1), ar = NUM(kCIInputAspectRatioKey, 1);
        return resample(im, s * ar, s, 2, mitchell(NUM(@"inputB", 0), NUM(@"inputC", 0.75f)));
    });
    REG(@"CILanczosScaleTransform", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        float s = NUM(kCIInputScaleKey, 1), ar = NUM(kCIInputAspectRatioKey, 1);
        return resample(im, s * ar, s, 3, ^float(float x) { return fabsf(x) < 3 ? sinc(x) * sinc(x / 3) : 0; });
    });
    REG(@"CIEdgePreserveUpsampleFilter", {
        CIImage *im = IMG(kCIInputImageKey), *small = IMG(@"inputSmallImage"); if (!im) return nil;
        if (!small || CGRectIsEmpty(small.extent) || ci_infinite(im.extent)) return im;
        float ss = fmaxf(NUM(@"inputSpatialSigma", 3), 0.1f), ls = fmaxf(NUM(@"inputLumaSigma", 0.15f), 1e-3f);
        CGRect e = im.extent, se = small.extent;
        double kx = se.size.width / e.size.width, ky = se.size.height / e.size.height;
        /* the guide (the full-size image) downsampled to the small image's grid */
        CIImage *guideSmall = [im imageByApplyingTransform:CGAffineTransformMake(kx, 0, 0, ky, se.origin.x - e.origin.x * kx, se.origin.y - e.origin.y * ky)
                                     highQualityDownsample:YES];
        return ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
            CGRect sr = CGRectMake(se.origin.x + (r.origin.x - e.origin.x) * kx - 3, se.origin.y + (r.origin.y - e.origin.y) * ky - 3,
                                   r.size.width * kx + 7, r.size.height * ky + 7);
            ci_buf sb = ci_buf_render([small imageByClampingToExtent], sr, 0, rc), gb = ci_buf_render([guideSmall imageByClampingToExtent], sr, 0, rc);
            [im _render:r into:out ctx:rc];
            int W = (int)r.size.width, H = (int)r.size.height, rad = (int)ceil(ss) > 3 ? 3 : (int)ceil(ss);
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                float *g = out + ((size_t)j * W + i) * 4;
                float gl = g[3] > 0 ? lumaf(g) / g[3] : 0;
                double x = se.origin.x + (ci_px_x(r, i) - e.origin.x) * kx, y = se.origin.y + (ci_px_y(r, j) - e.origin.y) * ky;
                int cx = (int)floor(x), cy = (int)floor(y);
                float acc[4] = { 0 }; double ws = 0;
                for (int dy = -rad; dy <= rad; dy++) for (int dx = -rad; dx <= rad; dx++) {
                    const float *sp = ci_buf_at(&sb, cx + dx, cy + dy), *gp = ci_buf_at(&gb, cx + dx, cy + dy);
                    if (!sp || !gp) continue;
                    double ddx = cx + dx + 0.5 - x, ddy = cy + dy + 0.5 - y;
                    float sl = gp[3] > 0 ? lumaf(gp) / gp[3] : 0;
                    double w = exp(-(ddx * ddx + ddy * ddy) / (2 * ss * ss / 9)) * exp(-(sl - gl) * (sl - gl) / (2 * ls * ls));
                    for (int k = 0; k < 4; k++) acc[k] += (float)(sp[k] * w);
                    ws += w;
                }
                if (ws > 1e-12) for (int k = 0; k < 4; k++) g[k] = (float)(acc[k] / ws);
            }
            ci_buf_free(&sb); ci_buf_free(&gb);
        });
    });
    REG(@"CIPerspectiveTransform", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e)) return im;
        double q[8]; quad_of(in, q);
        double src[8] = { e.origin.x, CGRectGetMaxY(e), CGRectGetMaxX(e), CGRectGetMaxY(e), CGRectGetMaxX(e), e.origin.y, e.origin.x, e.origin.y };
        double H[9]; if (!ci_homography(src, q, H)) return [CIImage emptyImage];
        return ci_homography_warp(im, H, CGRectNull);
    });
    REG(@"CIPerspectiveTransformWithExtent", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 300, 300));
        double q[8]; quad_of(in, q);
        double src[8] = { e.origin.x, CGRectGetMaxY(e), CGRectGetMaxX(e), CGRectGetMaxY(e), CGRectGetMaxX(e), e.origin.y, e.origin.x, e.origin.y };
        double H[9]; if (!ci_homography(src, q, H)) return [CIImage emptyImage];
        return ci_homography_warp(im, H, CGRectNull);
    });
    REG(@"CIPerspectiveCorrection", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        double q[8]; quad_of(in, q);
        double w = fmax(hypot(q[2] - q[0], q[3] - q[1]), hypot(q[4] - q[6], q[5] - q[7]));
        double h = fmax(hypot(q[0] - q[6], q[1] - q[7]), hypot(q[2] - q[4], q[3] - q[5]));
        double ox = fmin(fmin(q[0], q[2]), fmin(q[4], q[6])), oy = fmin(fmin(q[1], q[3]), fmin(q[5], q[7]));
        double dst[8] = { ox, oy + h, ox + w, oy + h, ox + w, oy, ox, oy };
        double H[9]; if (!ci_homography(q, dst, H)) return [CIImage emptyImage];
        BOOL crop = in[@"inputCrop"] ? BOOLV(@"inputCrop") : YES;
        return ci_homography_warp(im, H, crop ? CGRectMake(ox, oy, w, h) : CGRectNull);
    });
    void (^keystone)(NSString *, int) = ^(NSString *name, int mode) {     /* 1 horizontal, 2 vertical, 3 both */
        ci_register_impl(name, ^CIImage *(NSDictionary *in) {
            CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
            double q[8]; quad_of(in, q);
            double t[8]; memcpy(t, q, sizeof t);
            if (mode & 2) {   /* vertical keystone: the converging left and right edges made vertical */
                double lx = (q[0] + q[6]) / 2, rx = (q[2] + q[4]) / 2;
                t[0] = t[6] = lx; t[2] = t[4] = rx;
            }
            if (mode & 1) {   /* horizontal keystone: top and bottom edges made level */
                double ty = (q[1] + q[3]) / 2, by = (q[5] + q[7]) / 2;
                t[1] = t[3] = ty; t[5] = t[7] = by;
            }
            double H[9]; if (!ci_homography(q, t, H)) return im;
            /* the focal length scales the correction: 28 mm (the default) applies it fully */
            float f = NUM(@"inputFocalLength", 28), k = f > 0 ? fminf(1, 28 / f * 1.0f) : 1;
            if (k < 1) for (int i = 0; i < 8; i++) t[i] = q[i] + (t[i] - q[i]) * k;
            if (k < 1 && !ci_homography(q, t, H)) return im;
            return ci_homography_warp(im, H, im.extent);
        });
    };
    keystone(@"CIKeystoneCorrectionHorizontal", 1);
    keystone(@"CIKeystoneCorrectionVertical", 2);
    keystone(@"CIKeystoneCorrectionCombined", 3);
    REG(@"CIPerspectiveRotate", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e)) return im;
        double f = NUM(@"inputFocalLength", 28), pitch = NUM(@"inputPitch", 0), yaw = NUM(@"inputYaw", 0), roll = NUM(@"inputRoll", 0);
        /* focal length as a 35 mm equivalent over the image diagonal */
        double fp = f / 43.27 * hypot(e.size.width, e.size.height), cx = CGRectGetMidX(e), cy = CGRectGetMidY(e);
        double cp = cos(pitch), sp = sin(pitch), cyw = cos(yaw), syw = sin(yaw), cr = cos(roll), sr = sin(roll);
        double Rx[9] = { 1, 0, 0, 0, cp, -sp, 0, sp, cp }, Ry[9] = { cyw, 0, syw, 0, 1, 0, -syw, 0, cyw }, Rz[9] = { cr, -sr, 0, sr, cr, 0, 0, 0, 1 };
        double T[9], R[9];
        MUL(Ry, Rx, T); MUL(Rz, T, R);
        double K[9] = { fp, 0, cx, 0, fp, cy, 0, 0, 1 }, Ki[9] = { 1 / fp, 0, -cx / fp, 0, 1 / fp, -cy / fp, 0, 0, 1 }, A[9], Hm[9];
        MUL(R, Ki, A); MUL(K, A, Hm);
        for (int i = 0; i < 9; i++) Hm[i] /= Hm[8];
        return ci_homography_warp(im, Hm, CGRectNull);
    });
    REG(@"CIStraightenFilter", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e)) return im;
        double a = NUM(kCIInputAngleKey, 0), w = e.size.width, h = e.size.height;
        /* rotate about the center and scale up so no corner of the extent shows outside the image */
        double c = fabs(cos(a)), s = fabs(sin(a)), k = fmax((w * c + h * s) / w, (w * s + h * c) / h);
        CGAffineTransform t = CGAffineTransformMakeTranslation(-CGRectGetMidX(e), -CGRectGetMidY(e));
        t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(a));
        t = CGAffineTransformConcat(t, CGAffineTransformMakeScale(k, k));
        t = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(CGRectGetMidX(e), CGRectGetMidY(e)));
        return [[im imageByApplyingTransform:t] imageByCroppingToRect:e];
    });
}
