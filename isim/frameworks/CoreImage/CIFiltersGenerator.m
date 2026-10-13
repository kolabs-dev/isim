// isim Core Image filters: generators and gradients (text, barcodes, patterns, light effects).
#import "CIFilterImpl.h"
#import <UIKit/UIKit.h>

int isim_qr_encode_ex(const uint8_t *msg, int len, int ecl, uint8_t *out, int *outVersion, int *outEcl, int *outMask, uint8_t *codewords, int *ncodewords);
int isim_qr_from_codewords(const uint8_t *cw, int n, int v, int ecl, int mask, uint8_t *out);
int isim_code128_encode(const uint8_t *msg, int len, uint8_t *out, int max);
int isim_aztec_encode(const uint8_t *msg, int len, int eccPercent, int wantLayers, int wantCompact, uint8_t *out, int max,
                      int *outCompact, int *outLayers, int *outDataWords, uint8_t *payload, int *payloadLen);
int isim_aztec_from_payload(const uint8_t *payload, int nbytes, int compact, int layers, int datawords, uint8_t *out, int max);
int isim_pdf417_available(void);
int isim_pdf417_encode(const uint8_t *msg, int len, int level, int minCols, int maxCols, int minRows, int maxRows, double aspect,
                       int compaction, int compact, uint8_t *out, int max, int *outW, int *outCols, int *payloadCw, int *npayload);
int isim_pdf417_from_codewords(const int *full, int total, int rows, int cols, int compact, uint8_t *out, int max, int *outW);
int isim_datamatrix_from_codewords(const uint8_t *cw, int n, int rows, int cols, uint8_t *out, int max);

/* a module matrix (1 = dark) as a black-on-white image, scaled by (sx, sy) pixels and with a quiet zone of `q` px */
static CIImage *modules_image(const uint8_t *m, int w, int h, int sx, int sy, int qx, int qy) {
    int W = w * sx + 2 * qx, H = h * sy + 2 * qy;
    float *px = malloc(sizeof(float) * 4 * (size_t)W * H);
    for (size_t i = 0; i < (size_t)W * H; i++) { px[i * 4] = px[i * 4 + 1] = px[i * 4 + 2] = 1; px[i * 4 + 3] = 1; }
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) if (m[y * w + x])
        for (int dy = 0; dy < sy; dy++) for (int dx = 0; dx < sx; dx++) {
            float *p = px + ((size_t)(qy + y * sy + dy) * W + qx + x * sx + dx) * 4; p[0] = p[1] = p[2] = 0;
        }
    /* black and white are the same in every space: no conversion needed */
    CIImage *im = ci_bitmap(px, W, H, CGRectMake(0, 0, W, H), ci_space_linear, NO);
    im.isimOpaque = YES;
    return im;
}
static NSData *message_of(id v) {
    if ([v isKindOfClass:[NSData class]]) return v;
    if ([v isKindOfClass:[NSString class]]) return [v dataUsingEncoding:NSUTF8StringEncoding];
    return nil;
}

/* ---- barcode descriptors (CIBarcodeDescriptor.m) ---- */
CI_HIDDEN CIImage *ci_barcode_image(CIBarcodeDescriptor *d);
CIImage *ci_barcode_image(CIBarcodeDescriptor *d) {
    if ([d isKindOfClass:[CIQRCodeDescriptor class]]) {
        CIQRCodeDescriptor *q = (id)d;
        int e = q.errorCorrectionLevel == CIQRCodeErrorCorrectionLevelL ? 0 : q.errorCorrectionLevel == CIQRCodeErrorCorrectionLevelQ ? 2
              : q.errorCorrectionLevel == CIQRCodeErrorCorrectionLevelH ? 3 : 1;
        uint8_t *m = malloc(177 * 177);
        int s = isim_qr_from_codewords(q.errorCorrectedPayload.bytes, (int)q.errorCorrectedPayload.length, (int)q.symbolVersion, e, q.maskPattern, m);
        CIImage *im = s ? modules_image(m, s, s, 1, 1, 1, 1) : nil;
        free(m);
        return im;
    }
    if ([d isKindOfClass:[CIAztecCodeDescriptor class]]) {
        CIAztecCodeDescriptor *a = (id)d;
        uint8_t *m = malloc(151 * 151);
        int s = isim_aztec_from_payload(a.errorCorrectedPayload.bytes, (int)a.errorCorrectedPayload.length, a.isCompact, (int)a.layerCount, (int)a.dataCodewordCount, m, 151 * 151);
        CIImage *im = s ? modules_image(m, s, s, 1, 1, 1, 1) : nil;
        free(m);
        return im;
    }
    if ([d isKindOfClass:[CIPDF417CodeDescriptor class]]) {
        CIPDF417CodeDescriptor *p = (id)d;
        NSData *pl = p.errorCorrectedPayload;
        int n = (int)(pl.length / 2), *cw = malloc(sizeof(int) * (n ? n : 1));
        const uint8_t *b = pl.bytes;
        for (int i = 0; i < n; i++) cw[i] = b[i * 2] << 8 | b[i * 2 + 1];       /* codewords as big-endian 16-bit values */
        int W = 0, max = (17 * 30 + 69) * 90;
        uint8_t *m = malloc((size_t)max);
        int rows = isim_pdf417_from_codewords(cw, n, (int)p.rowCount, (int)p.columnCount, p.isCompact, m, max, &W);
        CIImage *im = rows ? modules_image(m, W, rows, 1, 3, 2, 2) : nil;
        free(m); free(cw);
        return im;
    }
    if ([d isKindOfClass:[CIDataMatrixCodeDescriptor class]]) {
        CIDataMatrixCodeDescriptor *x = (id)d;
        if (x.eccVersion != CIDataMatrixCodeECCVersion200) { NSLog(@"isim: Core Image: only ECC 200 Data Matrix symbols are drawn"); return nil; }
        int R = (int)x.rowCount, C = (int)x.columnCount;
        uint8_t *m = malloc((size_t)(R > 0 && C > 0 ? R * C : 1));
        int ok = R > 0 && C > 0 && isim_datamatrix_from_codewords(x.errorCorrectedPayload.bytes, (int)x.errorCorrectedPayload.length, R, C, m, R * C);
        CIImage *im = ok ? modules_image(m, C, R, 1, 1, 1, 1) : nil;
        free(m);
        return im;
    }
    return nil;
}

/* ---- text ---- */
static CIImage *text_image(NSAttributedString *s, double scale, double padding) {
    if (!s.length) return [CIImage emptyImage];
    CGRect b = [s boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    CGSize sz = CGSizeMake(ceil(b.size.width + 2 * padding), ceil(b.size.height + 2 * padding));
    if (sz.width < 1 || sz.height < 1) return [CIImage emptyImage];
    UIGraphicsBeginImageContextWithOptions(sz, NO, scale > 0 ? scale : 1);
    [s drawWithRect:CGRectMake(padding, padding, b.size.width, b.size.height) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img.CGImage ? [CIImage imageWithCGImage:img.CGImage] : [CIImage emptyImage];
}

/* ---- gradients and shapes ---- */
static CIImage *gradient(CGRect extent, CIColor *c0, CIColor *c1, float (^t)(double x, double y)) {
    return ci_gen(extent, ^(double x, double y, float *out, const ci_rctx *rc) {
        float a[4], b[4]; ci_color_ws(c0, rc, a); ci_color_ws(c1, rc, b);
        float k = t(x, y);
        for (int i = 0; i < 4; i++) out[i] = mixf(a[i], b[i], k);
    });
}
static float rounded_rect_dist(double x, double y, CGRect r, double rad) {    /* signed distance, negative inside */
    double cx = CGRectGetMidX(r), cy = CGRectGetMidY(r), hx = r.size.width / 2 - rad, hy = r.size.height / 2 - rad;
    double qx = fabs(x - cx) - hx, qy = fabs(y - cy) - hy;
    double ox = fmax(qx, 0), oy = fmax(qy, 0);
    return (float)(hypot(ox, oy) + fmin(fmax(qx, qy), 0) - rad);
}
static double erf_(double x) { return erf(x); }

void ci_register_generator_filters(void) {
    REG(@"CIConstantColorGenerator", {
        CIColor *c = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:1 green:0 blue:0]);
        return [CIImage imageWithColor:c];
    });
    REG(@"CIRandomGenerator", {
        return ci_gen(CGRectInfinite, ^(double x, double y, float *out, const ci_rctx *rc) {
            int ix = (int)floor(x), iy = (int)floor(y);
            for (int k = 0; k < 4; k++) out[k] = ci_hash01(ix, iy, k + 1);
            out[0] *= out[3]; out[1] *= out[3]; out[2] *= out[3];
        });
    });
    REG(@"CICheckerboardGenerator", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        double w = fmax(1e-3, NUM(kCIInputWidthKey, 80)), sharp = ci_clamp01(NUM(kCIInputSharpnessKey, 1));
        CIColor *c0 = ci_colorv(in[@"inputColor0"], [CIColor whiteColor]), *c1 = ci_colorv(in[@"inputColor1"], [CIColor blackColor]);
        double soft = (1 - sharp) * w / 2;
        return gradient(CGRectInfinite, c0, c1, ^float(double x, double y) {
            double fx = (x - c.x) / w, fy = (y - c.y) / w;
            int i = (int)floor(fx), j = (int)floor(fy);
            float v = ((i + j) & 1) ? 1 : 0;
            if (soft <= 0) return v;
            double dx = fmin(fx - i, i + 1 - fx) * w, dy = fmin(fy - j, j + 1 - fy) * w, d = fmin(dx, dy);
            float e = smoothf(0, (float)soft, (float)d);           /* blend toward the average at the edges */
            return mixf(0.5f, v, e);
        });
    });
    REG(@"CIStripesGenerator", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        double w = fmax(1e-3, NUM(kCIInputWidthKey, 80)), sharp = ci_clamp01(NUM(kCIInputSharpnessKey, 1));
        CIColor *c0 = ci_colorv(in[@"inputColor0"], [CIColor whiteColor]), *c1 = ci_colorv(in[@"inputColor1"], [CIColor blackColor]);
        double soft = (1 - sharp) * w / 2;
        return gradient(CGRectInfinite, c0, c1, ^float(double x, double y) {
            double f = (x - c.x) / w; int i = (int)floor(f);
            float v = (i & 1) ? 1 : 0;
            if (soft <= 0) return v;
            double d = fmin(f - i, i + 1 - f) * w;
            return mixf(0.5f, v, smoothf(0, (float)soft, (float)d));
        });
    });
    REG(@"CILinearGradient", {
        CGPoint a = PT(@"inputPoint0", 0, 0), b = PT(@"inputPoint1", 200, 200);
        double dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy;
        return gradient(CGRectInfinite, ci_colorv(in[@"inputColor0"], [CIColor whiteColor]), ci_colorv(in[@"inputColor1"], [CIColor blackColor]), ^float(double x, double y) {
            return L2 > 0 ? ci_clamp01((float)(((x - a.x) * dx + (y - a.y) * dy) / L2)) : 0;
        });
    });
    REG(@"CISmoothLinearGradient", {
        CGPoint a = PT(@"inputPoint0", 0, 0), b = PT(@"inputPoint1", 200, 200);
        double dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy;
        return gradient(CGRectInfinite, ci_colorv(in[@"inputColor0"], [CIColor whiteColor]), ci_colorv(in[@"inputColor1"], [CIColor blackColor]), ^float(double x, double y) {
            float t = L2 > 0 ? ci_clamp01((float)(((x - a.x) * dx + (y - a.y) * dy) / L2)) : 0;
            return t * t * (3 - 2 * t);
        });
    });
    REG(@"CIRadialGradient", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        double r0 = NUM(@"inputRadius0", 5), r1 = NUM(@"inputRadius1", 100);
        return gradient(CGRectInfinite, ci_colorv(in[@"inputColor0"], [CIColor whiteColor]), ci_colorv(in[@"inputColor1"], [CIColor blackColor]), ^float(double x, double y) {
            double d = hypot(x - c.x, y - c.y);
            return r1 == r0 ? (d >= r1 ? 1 : 0) : ci_clamp01((float)((d - r0) / (r1 - r0)));
        });
    });
    REG(@"CIGaussianGradient", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        double r = fmax(NUM(kCIInputRadiusKey, 300), 1e-3);
        return gradient(CGRectInfinite, ci_colorv(in[@"inputColor0"], [CIColor whiteColor]), ci_colorv(in[@"inputColor1"], [CIColor clearColor]), ^float(double x, double y) {
            double d = hypot(x - c.x, y - c.y) / r;
            return 1 - (float)exp(-d * d * 4.5);          /* sigma = radius / 3 */
        });
    });
    REG(@"CIHueSaturationValueGradient", {
        double R = fmax(NUM(kCIInputRadiusKey, 300), 1), V = ci_clamp01(NUM(@"inputValue", 1)), soft = NUM(@"inputSoftness", 1), dither = NUM(@"inputDither", 1);
        id cs = in[@"inputColorSpace"];
        ci_space sp = cs ? ci_space_of((__bridge CGColorSpaceRef)cs) : ci_space_srgb;
        return ci_gen(CGRectMake(0, 0, 2 * R, 2 * R), ^(double x, double y, float *out, const ci_rctx *rc) {
            double dx = x - R, dy = y - R, d = hypot(dx, dy);
            double edge = soft > 0 ? 1 - smoothf((float)(R - soft), (float)R, (float)d) : (d <= R ? 1 : 0);
            if (edge <= 0) { out[0] = out[1] = out[2] = out[3] = 0; return; }
            double h = atan2(dy, dx) / (2 * M_PI); if (h < 0) h += 1;
            double s = fmin(d / R, 1), hh = h * 6; int i = (int)floor(hh); double f = hh - i;
            double p = V * (1 - s), q = V * (1 - s * f), t = V * (1 - s * (1 - f)), rgb[3];
            switch (i % 6) { case 0: rgb[0] = V; rgb[1] = t; rgb[2] = p; break; case 1: rgb[0] = q; rgb[1] = V; rgb[2] = p; break;
                             case 2: rgb[0] = p; rgb[1] = V; rgb[2] = t; break; case 3: rgb[0] = p; rgb[1] = q; rgb[2] = V; break;
                             case 4: rgb[0] = t; rgb[1] = p; rgb[2] = V; break; default: rgb[0] = V; rgb[1] = p; rgb[2] = q; }
            float c[3];
            for (int k = 0; k < 3; k++) c[k] = (float)(rgb[k] + (ci_hash01((int)x, (int)y, k) - 0.5f) * dither / 255);
            if (rc->managed) ci_convert_rgb(c, sp, rc->ws);
            float a = (float)edge;
            out[0] = c[0] * a; out[1] = c[1] * a; out[2] = c[2] * a; out[3] = a;
        });
    });
    REG(@"CIRoundedRectangleGenerator", {
        CGRect r = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 100, 100));
        double rad = fmin(fmax(NUM(kCIInputRadiusKey, 10), 0), fmin(r.size.width, r.size.height) / 2);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        return ci_gen(r, ^(double x, double y, float *out, const ci_rctx *rc) {
            float c[4]; ci_color_ws(col, rc, c);
            float cov = ci_clamp01(0.5f - rounded_rect_dist(x, y, r, rad));
            for (int k = 0; k < 4; k++) out[k] = c[k] * cov;
        });
    });
    REG(@"CIRoundedRectangleStrokeGenerator", {
        CGRect r = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 100, 100));
        double rad = fmin(fmax(NUM(kCIInputRadiusKey, 10), 0), fmin(r.size.width, r.size.height) / 2), w = fmax(NUM(kCIInputWidthKey, 10), 0);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        return ci_gen(CGRectInset(r, -w / 2 - 1, -w / 2 - 1), ^(double x, double y, float *out, const ci_rctx *rc) {
            float c[4]; ci_color_ws(col, rc, c);
            float d = fabsf(rounded_rect_dist(x, y, r, rad)), cov = ci_clamp01((float)(w / 2) + 0.5f - d);
            for (int k = 0; k < 4; k++) out[k] = c[k] * cov;
        });
    });
    REG(@"CIBlurredRectangleGenerator", {
        CGRect r = ci_rect(in[kCIInputExtentKey], CGRectMake(0, 0, 100, 100));
        double s = fmax(NUM(@"inputSigma", 10), 1e-3);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        return ci_gen(CGRectInset(r, -3 * s, -3 * s), ^(double x, double y, float *out, const ci_rctx *rc) {
            float c[4]; ci_color_ws(col, rc, c);
            double k = sqrt(2) * s;
            double fx = 0.5 * (erf_((CGRectGetMaxX(r) - x) / k) - erf_((r.origin.x - x) / k)), fy = 0.5 * (erf_((CGRectGetMaxY(r) - y) / k) - erf_((r.origin.y - y) / k));
            float cov = (float)(fx * fy);
            for (int q = 0; q < 4; q++) out[q] = c[q] * cov;
        });
    });
    REG(@"CIMeshGenerator", {
        NSArray *mesh = in[@"inputMesh"];
        double w = fmax(NUM(kCIInputWidthKey, 1.5f), 0);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor whiteColor]);
        if (![mesh isKindOfClass:[NSArray class]] || !mesh.count) return [CIImage emptyImage];
        NSMutableData *segs = [NSMutableData data];
        CGRect bb = CGRectNull;
        for (id v in mesh) {
            if (![v isKindOfClass:[CIVector class]] || [v count] < 4) continue;
            double s[4] = { [v valueAtIndex:0], [v valueAtIndex:1], [v valueAtIndex:2], [v valueAtIndex:3] };
            [segs appendBytes:s length:sizeof s];
            bb = CGRectUnion(bb, CGRectMake(fmin(s[0], s[2]), fmin(s[1], s[3]), fabs(s[2] - s[0]), fabs(s[3] - s[1])));
        }
        if (CGRectIsNull(bb)) return [CIImage emptyImage];
        int n = (int)(segs.length / (4 * sizeof(double)));
        return ci_gen(CGRectInset(bb, -w - 1, -w - 1), ^(double x, double y, float *out, const ci_rctx *rc) {
            float c[4]; ci_color_ws(col, rc, c);
            const double *s = segs.bytes; double best = INFINITY;
            for (int i = 0; i < n; i++, s += 4) {
                double dx = s[2] - s[0], dy = s[3] - s[1], L = dx * dx + dy * dy;
                double t = L > 0 ? fmax(0, fmin(1, ((x - s[0]) * dx + (y - s[1]) * dy) / L)) : 0;
                best = fmin(best, hypot(x - s[0] - t * dx, y - s[1] - t * dy));
            }
            float cov = ci_clamp01((float)(w / 2 + 0.5 - best));
            for (int k = 0; k < 4; k++) out[k] = c[k] * cov;
        });
    });
    REG(@"CILenticularHaloGenerator", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:1 green:0.9 blue:0.8]);
        double hr = NUM(@"inputHaloRadius", 70), hw = fmax(NUM(@"inputHaloWidth", 87), 1e-3), ov = NUM(@"inputHaloOverlap", 0.77f);
        double ss = NUM(@"inputStriationStrength", 0.5f), sc = NUM(@"inputStriationContrast", 1), t = NUM(kCIInputTimeKey, 0);
        double ext = hr + hw * 2;
        return ci_gen(CGRectMake(c.x - ext, c.y - ext, 2 * ext, 2 * ext), ^(double x, double y, float *out, const ci_rctx *rc) {
            float col4[4]; ci_color_ws(col, rc, col4);
            double d = hypot(x - c.x, y - c.y), ang = atan2(y - c.y, x - c.x);
            /* three rings (R, G, B) offset by the overlap, modulated by angular striations */
            double stri = 1 + ss * pow(fabs(sin(ang * 23 + t * 6.28) * sin(ang * 37 - t * 3.1)), 1 / fmax(sc, 0.05)) - ss * 0.5;
            for (int k = 0; k < 3; k++) {
                double r0 = hr + (k - 1) * hw * (1 - ov) * 0.5, z = (d - r0) / (hw / 2);
                out[k] = (float)(col4[k] * exp(-z * z) * fmax(stri, 0));
            }
            out[3] = fmaxf(out[0], fmaxf(out[1], out[2]));
        });
    });
    REG(@"CIStarShineGenerator", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:1 green:0.8 blue:0.6]);
        double r = fmax(NUM(kCIInputRadiusKey, 50), 1e-3), cs = NUM(@"inputCrossScale", 15), ca = NUM(@"inputCrossAngle", 0.6f);
        double co = pow(10, NUM(@"inputCrossOpacity", -2) / 2), cw = fmax(NUM(@"inputCrossWidth", 2.5f), 1e-3), eps = pow(10, NUM(@"inputEpsilon", -2));
        double ext = r * fmax(cs, 3);
        return ci_gen(CGRectMake(c.x - ext, c.y - ext, 2 * ext, 2 * ext), ^(double x, double y, float *out, const ci_rctx *rc) {
            float col4[4]; ci_color_ws(col, rc, col4);
            double dx = x - c.x, dy = y - c.y, d = hypot(dx, dy);
            double glow = 1 / (1 + pow(d / r, 2) / (eps + 1e-6) * eps * 50 + pow(d / r, 3));
            double cr = cos(ca), sr = sin(ca), u = dx * cr + dy * sr, v = -dx * sr + dy * cr, arms = 0;
            arms += exp(-fabs(v) / cw) * exp(-fabs(u) / (r * cs)) + exp(-fabs(u) / cw) * exp(-fabs(v) / (r * cs));
            double k = fmin(1.0, glow + arms * co * 10);
            for (int q = 0; q < 3; q++) out[q] = (float)(col4[q] * k);
            out[3] = (float)k;
        });
    });
    REG(@"CISunbeamsGenerator", {
        CGPoint c = PT(kCIInputCenterKey, 150, 150);
        CIColor *col = ci_colorv(in[kCIInputColorKey], [CIColor colorWithRed:1 green:0.5 blue:0]);
        double sr = fmax(NUM(@"inputSunRadius", 40), 1e-3), mr = NUM(@"inputMaxStriationRadius", 2.58f), ss = NUM(@"inputStriationStrength", 0.5f);
        double sc = NUM(@"inputStriationContrast", 1.375f), t = NUM(kCIInputTimeKey, 0);
        double ext = sr * fmax(mr, 1) * 2 + sr;
        return ci_gen(CGRectMake(c.x - ext, c.y - ext, 2 * ext, 2 * ext), ^(double x, double y, float *out, const ci_rctx *rc) {
            float col4[4]; ci_color_ws(col, rc, col4);
            double dx = x - c.x, dy = y - c.y, d = hypot(dx, dy), ang = atan2(dy, dx);
            double disk = d <= sr ? 1 : exp(-(d - sr) / (sr * 0.15));
            double ray = 0.5 + 0.5 * sin(ang * 31 + t * 6.28) * sin(ang * 13 - t * 2.1 + 1.3);
            ray = pow(fmax(ray, 0), sc) * ss * exp(-fmax(d - sr, 0) / (sr * fmax(mr, 0.1)));
            double k = fmin(1, disk + ray);
            for (int q = 0; q < 3; q++) out[q] = (float)(col4[q] * k);
            out[3] = (float)k;
        });
    });

    /* -------- text -------- */
    REG(@"CITextImageGenerator", {
        NSString *text = in[@"inputText"];
        if (![text isKindOfClass:[NSString class]] || !text.length) return [CIImage emptyImage];
        NSString *fn = in[@"inputFontName"] ?: @"HelveticaNeue";
        double size = NUM(@"inputFontSize", 12);
        UIFont *font = [UIFont fontWithName:fn size:size] ?: [UIFont systemFontOfSize:size];
        NSAttributedString *s = [[NSAttributedString alloc] initWithString:text attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor blackColor] }];
        return text_image(s, NUM(@"inputScaleFactor", 1), NUM(@"inputPadding", 0));
    });
    REG(@"CIAttributedTextImageGenerator", {
        NSAttributedString *s = in[@"inputText"];
        if ([s isKindOfClass:[NSString class]]) s = [[NSAttributedString alloc] initWithString:(NSString *)s];
        if (![s isKindOfClass:[NSAttributedString class]]) return [CIImage emptyImage];
        return text_image(s, NUM(@"inputScaleFactor", 1), NUM(@"inputPadding", 0));
    });

    /* -------- barcodes -------- */
    REG(@"CIQRCodeGenerator", {
        NSData *msg = message_of(in[@"inputMessage"]);
        if (!msg) return nil;
        NSString *lvl = [in[@"inputCorrectionLevel"] uppercaseString] ?: @"M";
        int ecl = [lvl isEqualToString:@"L"] ? 0 : [lvl isEqualToString:@"Q"] ? 2 : [lvl isEqualToString:@"H"] ? 3 : 1;
        uint8_t *m = malloc(177 * 177);
        int s = isim_qr_encode_ex(msg.bytes, (int)msg.length, ecl, m, NULL, NULL, NULL, NULL, NULL);
        CIImage *im = s ? modules_image(m, s, s, 1, 1, 1, 1) : nil;       /* one module of quiet zone, as Core Image */
        free(m);
        return im;
    });
    REG(@"CICode128BarcodeGenerator", {
        NSData *msg = message_of(in[@"inputMessage"]);
        if (!msg) return nil;
        uint8_t *m = malloc(30000);
        int n = isim_code128_encode(msg.bytes, (int)msg.length, m, 30000);
        int q = (int)lround(NUM(@"inputQuietSpace", 7)), h = (int)lround(fmax(1, NUM(@"inputBarcodeHeight", 32)));
        CIImage *im = nil;
        if (n) {
            uint8_t *rows = malloc((size_t)n * h);
            for (int y = 0; y < h; y++) memcpy(rows + (size_t)y * n, m, (size_t)n);
            im = modules_image(rows, n, h, 1, 1, q, 0);
            free(rows);
        } else NSLog(@"isim: CICode128BarcodeGenerator: the message must be ASCII");
        free(m);
        return im;
    });
    REG(@"CIAztecCodeGenerator", {
        NSData *msg = message_of(in[@"inputMessage"]);
        if (!msg) return nil;
        int ecc = (int)lround(fmin(95, fmax(5, NUM(@"inputCorrectionLevel", 23))));
        id ly = in[@"inputLayers"], cs = in[@"inputCompactStyle"];
        int layers = ly ? (int)lround(ci_num(ly, 0)) : 0, compact = cs ? (ci_num(cs, 0) != 0) : -1;
        uint8_t *m = malloc(151 * 151);
        int s = isim_aztec_encode(msg.bytes, (int)msg.length, ecc, layers, compact, m, 151 * 151, NULL, NULL, NULL, NULL, NULL);
        CIImage *im = s ? modules_image(m, s, s, 1, 1, 1, 1) : nil;
        free(m);
        if (!s) NSLog(@"isim: CIAztecCodeGenerator: the message does not fit (layers %d)", layers);
        return im;
    });
    REG(@"CIPDF417BarcodeGenerator", {
        NSData *msg = message_of(in[@"inputMessage"]);
        if (!msg) return nil;
        if (!isim_pdf417_available()) {
            NSLog(@"isim: CIPDF417BarcodeGenerator needs the PDF417 codeword table from the host's zxing-cpp library (libZXing; the zxing-cpp-tools package)");
            return nil;
        }
        BOOL compact = ci_num(in[@"inputCompactStyle"], 0) != 0;
        int fixed = compact ? 35 : 69;
        double minW = ci_num(in[@"inputMinWidth"], NAN), maxW = ci_num(in[@"inputMaxWidth"], NAN), minH = ci_num(in[@"inputMinHeight"], NAN), maxH = ci_num(in[@"inputMaxHeight"], NAN);
        int cols = (int)lround(ci_num(in[@"inputDataColumns"], 0)), rowsW = (int)lround(ci_num(in[@"inputRows"], 0));
        int minC = isnan(minW) ? 1 : (int)ceil((minW - 4 - fixed) / 17), maxC = isnan(maxW) ? 30 : (int)floor((maxW - 4 - fixed) / 17);
        int minR = isnan(minH) ? 3 : (int)ceil((minH - 4) / 3.0), maxR = isnan(maxH) ? 90 : (int)floor((maxH - 4) / 3.0);
        if (cols > 0) minC = maxC = cols;
        if (rowsW > 0) minR = maxR = rowsW;
        int level = in[@"inputCorrectionLevel"] ? (int)lround(ci_num(in[@"inputCorrectionLevel"], 2)) : -1;
        int mode = (int)lround(ci_num(in[@"inputCompactionMode"], 0));
        double aspect = ci_num(in[@"inputPreferredAspectRatio"], 0);
        int max = (17 * 30 + 69) * 90, W = 0;
        uint8_t *m = malloc((size_t)max);
        int rows = isim_pdf417_encode(msg.bytes, (int)msg.length, level, minC < 1 ? 1 : minC, maxC > 30 ? 30 : maxC, minR < 3 ? 3 : minR, maxR > 90 ? 90 : maxR,
                                      aspect, mode, compact, m, max, &W, NULL, NULL, NULL);
        CIImage *im = rows ? modules_image(m, W, rows, 1, 3, 2, 2) : nil;
        free(m);
        if (!rows) NSLog(@"isim: CIPDF417BarcodeGenerator: the message does not fit the size limits");
        return im;
    });
    REG(@"CIBarcodeGenerator", {
        CIBarcodeDescriptor *d = in[@"inputBarcodeDescriptor"];
        return [d isKindOfClass:[CIBarcodeDescriptor class]] ? ci_barcode_image(d) : nil;
    });
}
