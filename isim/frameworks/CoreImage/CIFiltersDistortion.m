// isim Core Image filters: distortion effects. Each is an inverse map (output position -> source position) sampled
// bilinearly; the shapes follow Core Image's descriptions (adapted: the exact falloff curves are isim's).
#import "CIFilterImpl.h"

typedef void (^ci_map2)(double x, double y, double *sx, double *sy);
#define WARP(extent, ...) ci_warp(im, extent, ^(double x, double y, double *sx, double *sy) __VA_ARGS__)

void ci_register_distortion_filters(void) {
    REG(@"CIBumpDistortion", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = fmax(NUM(kCIInputRadiusKey, 300), 1e-3), s = NUM(kCIInputScaleKey, 0.5f);
        return WARP(im.extent, {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy) / R;
            double k = d < 1 ? 1 - s * (1 - d) * (1 - d) : 1;
            *sx = c.x + vx * k; *sy = c.y + vy * k;
        });
    });
    REG(@"CIBumpDistortionLinear", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 300, 300); double R = fmax(NUM(kCIInputRadiusKey, 300), 1e-3), s = NUM(kCIInputScaleKey, 0.5f), a = NUM(kCIInputAngleKey, 0);
        double nx = -sin(a), ny = cos(a);            /* normal of the line through the center */
        return WARP(im.extent, {
            double vx = x - c.x, vy = y - c.y, p = vx * nx + vy * ny, d = fabs(p) / R;
            double k = d < 1 ? 1 - s * (1 - d) * (1 - d) : 1;
            *sx = x - nx * p * (1 - k); *sy = y - ny * p * (1 - k);
        });
    });
    REG(@"CICircleSplashDistortion", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = NUM(kCIInputRadiusKey, 150);
        return WARP(CGRectInfinite, {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy);
            if (d <= R || d == 0) { *sx = x; *sy = y; return; }
            *sx = c.x + vx / d * (R - 0.5); *sy = c.y + vy / d * (R - 0.5);
        });
    });
    REG(@"CICircularWrap", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e)) return im;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = fmax(NUM(kCIInputRadiusKey, 150), 1), a0 = NUM(kCIInputAngleKey, 0);
        /* the image's width wraps around the circle (angle -> x), its height extends outward from the radius */
        double circ = 2 * M_PI * R, sc = e.size.width > circ ? e.size.width / circ : 1;
        double outer = R + e.size.height;
        return WARP(CGRectMake(c.x - outer, c.y - outer, 2 * outer, 2 * outer), {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy);
            if (d < R) { *sx = *sy = NAN; return; }
            double t = atan2(vy, vx) - a0;
            t = fmod(t + 3 * M_PI, 2 * M_PI) - M_PI;
            *sx = CGRectGetMidX(e) - t * R * sc; *sy = e.origin.y + (d - R);
        });
    });
    REG(@"CIDisplacementDistortion", {
        CIImage *im = IMG(kCIInputImageKey), *dm = IMG(@"inputDisplacementImage"); if (!im) return nil;
        if (!dm) return im;
        double s = NUM(kCIInputScaleKey, 50);
        CIImage *disp = [dm imageByClampingToExtent];
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float *d = ci_render_new(disp, r, rc);
            int pad = (int)ceil(fabs(s)) + 2;
            ci_buf b = ci_buf_render(im, CGRectInset(r, -pad, -pad), 2, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                float *p = d + ((size_t)j * W + i) * 4, a = p[3] > 0 ? p[3] : 1;
                float u = ci_trc_encode(CI_TRC_SRGB, p[0] / a) - 0.5f, v = ci_trc_encode(CI_TRC_SRGB, p[1] / a) - 0.5f;
                ci_sample(&b, ci_px_x(r, i) + u * s, ci_px_y(r, j) + v * s, CI_SAMPLE_LINEAR, out + ((size_t)j * W + i) * 4);
            }
            free(d); ci_buf_free(&b);
        });
    });
    REG(@"CIDroste", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e)) return im;
        CGPoint p0 = PT(@"inputInsetPoint0", 200, 200), p1 = PT(@"inputInsetPoint1", 400, 400);
        double strands = NUM(@"inputStrands", 1), period = fmax(NUM(@"inputPeriodicity", 1), 1), rot = NUM(@"inputRotation", 0), zoom = fmax(NUM(@"inputZoom", 1), 0.01);
        double cx = (p0.x + p1.x) / 2, cy = (p0.y + p1.y) / 2;
        double r1 = fmax(fmin(fabs(p1.x - p0.x), fabs(p1.y - p0.y)) / 2, 1);                 /* the inset (inner copy) */
        double r2 = fmax(fmax(fmax(cx - e.origin.x, CGRectGetMaxX(e) - cx), fmax(cy - e.origin.y, CGRectGetMaxY(e) - cy)), r1 * 1.01);
        double lnr = log(r2 / r1);
        /* the Escher / Droste spiral (after Tom Beddard): rotate and scale log-polar space so that the image repeats */
        double al = atan(period / strands * lnr / (2 * M_PI)), f = cos(al);
        double bre = f * cos(al), bim = f * sin(al);
        CIImage *clamped = [im imageByClampingToExtent];
        return ci_warp(clamped, e, ^(double x, double y, double *sx, double *sy) {
            double zx = (x - cx) / zoom, zy = (y - cy) / zoom;
            double cr = cos(rot), sr = sin(rot), tx = zx * cr - zy * sr, ty = zx * sr + zy * cr;
            double lr = log(fmax(hypot(tx, ty), 1e-9)) - log(r1), th = atan2(ty, tx);
            /* divide by beta */
            double den = bre * bre + bim * bim, wr = (lr * bre + th * bim) / den, wi = (th * bre - lr * bim) / den;
            wi *= strands;
            wr = fmod(wr, lnr); if (wr < 0) wr += lnr;
            double m = exp(wr) * r1;
            *sx = cx + m * cos(wi); *sy = cy + m * sin(wi);
        });
    });
    REG(@"CIGlassDistortion", {
        CIImage *im = IMG(kCIInputImageKey), *tex = IMG(@"inputTexture"); if (!im) return nil;
        if (!tex || CGRectIsEmpty(tex.extent)) return im;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double s = NUM(kCIInputScaleKey, 200);
        CGRect te = ci_integral(tex.extent);
        if (ci_infinite(te)) te = CGRectMake(0, 0, 256, 256);
        return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
            float *t = ci_render_new(tex, te, rc);
            int TW = (int)te.size.width, TH = (int)te.size.height;
            /* texture height = luminance, tiled and centered on `center`; displacement = its gradient * scale */
            float (^hgt)(int, int) = ^float(int tx, int ty) {
                tx = ((tx % TW) + TW) % TW; ty = ((ty % TH) + TH) % TH;
                float *p = t + ((size_t)(TH - 1 - ty) * TW + tx) * 4;
                return lumaf(p);
            };
            int pad = (int)ceil(fabs(s) * 0.05) + 3;
            ci_buf b = ci_buf_render(im, CGRectInset(r, -pad, -pad), 2, rc);
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                int tx = (int)floor(ci_px_x(r, i) - c.x + TW / 2), ty = (int)floor(ci_px_y(r, j) - c.y + TH / 2);
                float gx = hgt(tx + 1, ty) - hgt(tx - 1, ty), gy = hgt(tx, ty + 1) - hgt(tx, ty - 1);
                ci_sample(&b, ci_px_x(r, i) + gx * s * 0.05, ci_px_y(r, j) + gy * s * 0.05, CI_SAMPLE_LINEAR, out + ((size_t)j * W + i) * 4);
            }
            free(t); ci_buf_free(&b);
        });
    });
    REG(@"CIGlassLozenge", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint a = PT(@"inputPoint0", 150, 150), b = PT(@"inputPoint1", 350, 150);
        double R = fmax(NUM(kCIInputRadiusKey, 100), 1e-3), n = NUM(kCIInputRefractionKey, 1.7f);
        double dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy;
        return WARP(im.extent, {
            double t = L2 > 0 ? fmax(0, fmin(1, ((x - a.x) * dx + (y - a.y) * dy) / L2)) : 0;
            double qx = a.x + t * dx, qy = a.y + t * dy, vx = x - qx, vy = y - qy, d = hypot(vx, vy) / R;
            if (d >= 1) { *sx = x; *sy = y; return; }
            double k = 1 - (n - 1) * 0.5 * (1 - d * d);       /* the lens magnifies toward its axis */
            *sx = qx + vx * k; *sy = qy + vy * k;
        });
    });
    REG(@"CIHoleDistortion", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = NUM(kCIInputRadiusKey, 150);
        return WARP(im.extent, {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy);
            if (d <= R) { *sx = *sy = NAN; return; }
            double sd = sqrt(d * d - R * R);                 /* pixels pushed outward from the hole */
            *sx = c.x + vx / d * sd; *sy = c.y + vy / d * sd;
        });
    });
    REG(@"CILightTunnel", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double rot = NUM(@"inputRotation", 0), R = fmax(NUM(kCIInputRadiusKey, 100), 1);
        return WARP(im.extent, {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy);
            if (d <= R) { *sx = x; *sy = y; return; }
            double th = atan2(vy, vx) + rot * log(d / R);     /* outside: the circle's rim, spiraling */
            *sx = c.x + R * cos(th); *sy = c.y + R * sin(th);
        });
    });
    void (^nine)(NSString *, BOOL) = ^(NSString *name, BOOL tiled) {
        ci_register_impl(name, ^CIImage *(NSDictionary *in) {
            CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
            CGRect e = im.extent; if (ci_infinite(e)) return im;
            CGPoint b0 = PT(@"inputBreakpoint0", 50, 50), b1 = PT(@"inputBreakpoint1", 150, 150);
            CGPoint g = ci_point(in[@"inputGrowAmount"], CGPointMake(100, 100));
            BOOL flipY = in[@"inputFlipYTiles"] ? BOOLV(@"inputFlipYTiles") : YES;
            double x0 = e.origin.x + fmin(b0.x, b1.x), x1 = e.origin.x + fmax(b0.x, b1.x), y0 = e.origin.y + fmin(b0.y, b1.y), y1 = e.origin.y + fmax(b0.y, b1.y);
            double mw = x1 - x0, mh = y1 - y0;
            CGRect oe = CGRectMake(e.origin.x, e.origin.y, e.size.width + g.x, e.size.height + g.y);
            double (^axis)(double, double, double, double, double, BOOL) = ^double(double v, double lo, double mid, double grow, double start, BOOL flip) {
                if (v < lo) return v;
                if (v < lo + mid + grow) {
                    double t = v - lo;
                    if (!tiled) return lo + t * mid / (mid + grow);
                    if (mid <= 0) return lo;
                    double k = floor(t / mid), f = t - k * mid;
                    return lo + ((flip && ((long)k & 1)) ? mid - f : f);
                }
                return v - grow;
            };
            return ci_warp_mode(im, oe, 1, ^(double x, double y, double *sx, double *sy) {
                *sx = axis(x, x0, mw, g.x, e.origin.x, NO);
                *sy = axis(y, y0, mh, g.y, e.origin.y, flipY);
            });
        });
    };
    nine(@"CINinePartStretched", NO);
    nine(@"CINinePartTiled", YES);
    REG(@"CIPinchDistortion", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = fmax(NUM(kCIInputRadiusKey, 300), 1e-3), s = NUM(kCIInputScaleKey, 0.5f);
        return WARP(im.extent, {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy), t = d / R;
            if (t >= 1 || d == 0) { *sx = x; *sy = y; return; }
            double sd = R * pow(t, 1 / (1 + s));
            *sx = c.x + vx / d * sd; *sy = c.y + vy / d * sd;
        });
    });
    REG(@"CIStretchCrop", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent; if (ci_infinite(e) || CGRectIsEmpty(e)) return im;
        CGPoint sz = ci_point(in[@"inputSize"], CGPointMake(1280, 720));
        double crop = ci_clamp01(NUM(@"inputCropAmount", 0.25f)), cs = ci_clamp01(NUM(@"inputCenterStretchAmount", 0.25f));
        double W = fmax(sz.x, 1), H = fmax(sz.y, 1), w = e.size.width, h = e.size.height;
        /* crop part of the aspect mismatch away, stretch the rest (more in the center than at the edges) */
        double ta = W / H, sa = w / h, cw = w, ch = h;
        if (ta > sa) ch = h - (h - w / ta) * crop; else cw = w - (w - h * ta) * crop;
        double ox = e.origin.x + (w - cw) / 2, oy = e.origin.y + (h - ch) / 2;
        return ci_warp_mode(im, CGRectMake(0, 0, W, H), 1, ^(double x, double y, double *sx, double *sy) {
            double u = x / W - 0.5, v = y / H - 0.5;
            /* blend linear and center-weighted mappings: u' = u + cs * (sign(u) u^2 * 2 - u) */
            double uu = u + cs * (copysign(u * u * 2, u) - u), vv = v + cs * (copysign(v * v * 2, v) - v);
            *sx = ox + (uu + 0.5) * cw; *sy = oy + (vv + 0.5) * ch;
        });
    });
    REG(@"CITorusLensDistortion", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = NUM(kCIInputRadiusKey, 160), w = fmax(NUM(kCIInputWidthKey, 80), 1e-3), n = NUM(kCIInputRefractionKey, 1.7f);
        return WARP(im.extent, {
            double vx = x - c.x, vy = y - c.y, d = hypot(vx, vy), t = (d - R) / (w / 2);
            if (fabs(t) >= 1 || d == 0) { *sx = x; *sy = y; return; }
            double k = 1 - (n - 1) * 0.5 * (1 - t * t), sd = R + (d - R) * k;      /* magnified toward the ring's center line */
            *sx = c.x + vx / d * sd; *sy = c.y + vy / d * sd;
        });
    });
    void (^twirl)(NSString *, double, double) = ^(NSString *name, double defAngle, double expo) {
        ci_register_impl(name, ^CIImage *(NSDictionary *in) {
            CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
            CGPoint c = PT(kCIInputCenterKey, 150, 150); double R = fmax(NUM(kCIInputRadiusKey, 300), 1e-3), a = NUM(kCIInputAngleKey, defAngle);
            return WARP(im.extent, {
                double vx = x - c.x, vy = y - c.y, t = hypot(vx, vy) / R;
                if (t >= 1) { *sx = x; *sy = y; return; }
                double r = a * pow(1 - t, expo), cs = cos(r), sn = sin(r);
                *sx = c.x + vx * cs - vy * sn; *sy = c.y + vx * sn + vy * cs;
            });
        });
    };
    twirl(@"CITwirlDistortion", M_PI, 2);
    twirl(@"CIVortexDistortion", 56.55, 3);
}
