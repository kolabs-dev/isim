// isim Core Image detectors (adapted; see CIDetector.h): faces with OpenCV's Haar cascades evaluated by isim
// (CIHaar.c), rectangles with isim's own quadrilateral finder, QR codes through the host's zbar / zxing-cpp, text
// regions through the host's tesseract.
#import "CIInternal.h"

typedef struct haar_cascade haar_cascade;
haar_cascade *haar_load(const char *path);
int haar_detect(const haar_cascade *c, const float *gray, int w, int h, double scaleFactor, int minNeighbors, int minSize, int *out, int maxOut);
int isim_qr_encode_ex(const uint8_t *msg, int len, int ecl, uint8_t *out, int *outVersion, int *outEcl, int *outMask, uint8_t *codewords, int *ncodewords);

NSString *const CIFeatureTypeFace = @"Face", *const CIFeatureTypeRectangle = @"Rectangle", *const CIFeatureTypeQRCode = @"QRCode", *const CIFeatureTypeText = @"Text";
NSString *const CIDetectorTypeFace = @"CIDetectorTypeFace", *const CIDetectorTypeRectangle = @"CIDetectorTypeRectangle",
    *const CIDetectorTypeQRCode = @"CIDetectorTypeQRCode", *const CIDetectorTypeText = @"CIDetectorTypeText";
NSString *const CIDetectorAccuracy = @"CIDetectorAccuracy", *const CIDetectorAccuracyLow = @"CIDetectorAccuracyLow",
    *const CIDetectorAccuracyHigh = @"CIDetectorAccuracyHigh", *const CIDetectorTracking = @"CIDetectorTracking",
    *const CIDetectorMinFeatureSize = @"CIDetectorMinFeatureSize", *const CIDetectorMaxFeatureCount = @"CIDetectorMaxFeatureCount",
    *const CIDetectorNumberOfAngles = @"CIDetectorNumberOfAngles", *const CIDetectorImageOrientation = @"CIDetectorImageOrientation",
    *const CIDetectorEyeBlink = @"CIDetectorEyeBlink", *const CIDetectorSmile = @"CIDetectorSmile", *const CIDetectorFocalLength = @"CIDetectorFocalLength",
    *const CIDetectorAspectRatio = @"CIDetectorAspectRatio", *const CIDetectorReturnSubFeatures = @"CIDetectorReturnSubFeatures";

/* ================= features ================= */
@interface CIFeature ()
@property (nonatomic, readwrite, retain) NSString *type;
@property (nonatomic, readwrite) CGRect bounds;
@end
@implementation CIFeature
- (NSString *)description { CGRect b = self.bounds; return [NSString stringWithFormat:@"<%@: %p> %@ [%g %g %g %g]", NSStringFromClass([self class]), self, self.type, b.origin.x, b.origin.y, b.size.width, b.size.height]; }
@end
@interface CIFaceFeature ()
@property (readwrite) BOOL hasLeftEyePosition, hasRightEyePosition, hasMouthPosition, hasTrackingID, hasTrackingFrameCount, hasFaceAngle, hasSmile, leftEyeClosed, rightEyeClosed;
@property (readwrite) CGPoint leftEyePosition, rightEyePosition, mouthPosition;
@property (readwrite) int trackingID, trackingFrameCount;
@property (readwrite) float faceAngle;
@end
@implementation CIFaceFeature
@dynamic bounds;
@end
@interface CIRectangleFeature ()
@property (readwrite) CGPoint topLeft, topRight, bottomLeft, bottomRight;
@end
@implementation CIRectangleFeature
@dynamic bounds;
@end
@interface CIQRCodeFeature ()
@property (readwrite) CGPoint topLeft, topRight, bottomLeft, bottomRight;
@property (readwrite, copy) NSString *messageString;
@property (readwrite, strong) CIQRCodeDescriptor *symbolDescriptor;
@end
@implementation CIQRCodeFeature
@dynamic bounds;
+ (BOOL)supportsSecureCoding { return YES; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:self.messageString forKey:@"message"]; [c encodeObject:[CIVector vectorWithCGRect:self.bounds] forKey:@"bounds"];
    [c encodeObject:[CIVector vectorWithX:self.topLeft.x Y:self.topLeft.y Z:self.topRight.x W:self.topRight.y] forKey:@"top"];
    [c encodeObject:[CIVector vectorWithX:self.bottomLeft.x Y:self.bottomLeft.y Z:self.bottomRight.x W:self.bottomRight.y] forKey:@"bottom"];
    if (self.symbolDescriptor) [c encodeObject:self.symbolDescriptor forKey:@"descriptor"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if (!(self = [super init])) return nil;
    self.type = CIFeatureTypeQRCode;
    self.messageString = [c decodeObjectOfClass:[NSString class] forKey:@"message"];
    self.bounds = [[c decodeObjectOfClass:[CIVector class] forKey:@"bounds"] CGRectValue];
    CIVector *t = [c decodeObjectOfClass:[CIVector class] forKey:@"top"], *b = [c decodeObjectOfClass:[CIVector class] forKey:@"bottom"];
    self.topLeft = CGPointMake(t.X, t.Y); self.topRight = CGPointMake(t.Z, t.W); self.bottomLeft = CGPointMake(b.X, b.Y); self.bottomRight = CGPointMake(b.Z, b.W);
    self.symbolDescriptor = [c decodeObjectOfClass:[CIQRCodeDescriptor class] forKey:@"descriptor"];
    return self;
}
@end
@interface CITextFeature ()
@property (readwrite) CGPoint topLeft, topRight, bottomLeft, bottomRight;
@property (readwrite, copy) NSArray *subFeatures;
@end
@implementation CITextFeature
@dynamic bounds;
@end

/* ================= detector ================= */
static NSString *cascade_path(NSString *file) {
    for (NSString *dir in @[ @"/usr/share/opencv4/haarcascades", @"/usr/share/opencv/haarcascades", @"/usr/local/share/opencv4/haarcascades",
                             @"/usr/share/OpenCV/haarcascades" ]) {
        NSString *p = [dir stringByAppendingPathComponent:file];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    return nil;
}
static haar_cascade *cascade(NSString *file) {
    static NSMutableDictionary *cache; static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&m);
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSValue *v = cache[file];
    if (!v) {
        NSString *p = cascade_path(file);
        haar_cascade *c = p ? haar_load(p.fileSystemRepresentation) : NULL;
        v = [NSValue valueWithPointer:c]; cache[file] = v;
    }
    pthread_mutex_unlock(&m);
    return v.pointerValue;
}

@implementation CIDetector {
    NSString *_type; NSDictionary *_opts; NSArray<CIFaceFeature *> *_tracked; int _nextID;
}
+ (CIDetector *)detectorOfType:(NSString *)type context:(CIContext *)context options:(NSDictionary *)options {
    if (![@[ CIDetectorTypeFace, CIDetectorTypeRectangle, CIDetectorTypeQRCode, CIDetectorTypeText ] containsObject:type]) return nil;
    CIDetector *d = [self new];
    d->_type = type; d->_opts = [options copy] ?: @{}; d->_nextID = 1;
    if ([type isEqualToString:CIDetectorTypeFace] && !cascade(@"haarcascade_frontalface_default.xml"))
        NSLog(@"isim: CIDetector: face detection needs OpenCV's Haar cascade files (the opencv-data package); no faces will be found");
    if ([type isEqualToString:CIDetectorTypeText] && !isim_vision_available(2))
        NSLog(@"isim: CIDetector: text detection needs the host's tesseract; no text will be found");
    return d;
}
- (NSArray<CIFeature *> *)featuresInImage:(CIImage *)image { return [self featuresInImage:image options:nil]; }
/* the image upright (orientation option), as 8-bit RGBA (top-down rows) with its extent and scale */
static unsigned char *rgba_of(CIImage *im, double maxSide, int *w, int *h, double *scale, CGRect *ext) {
    CGRect e = im.extent;
    if (ci_infinite(e) || CGRectIsEmpty(e)) return NULL;
    double s = fmin(1, maxSide / fmax(e.size.width, e.size.height));
    CIImage *t = s < 1 ? [im imageByApplyingTransform:CGAffineTransformMakeScale(s, s) highQualityDownsample:YES] : im;
    CGRect r = CGRectIntegral(t.extent);
    ci_rctx rc = ci_rctx_default(); rc.cache = ci_cache_new();
    float *px = ci_render_new(t, r, &rc);
    ci_cache_free(rc.cache);
    size_t n = (size_t)r.size.width * r.size.height;
    ci_convert(px, n, ci_space_linear, ci_space_srgb);
    unsigned char *o = malloc(n * 4);
    for (size_t i = 0; i < n; i++) {
        float a = ci_clamp01(px[i * 4 + 3]);
        for (int c = 0; c < 3; c++) { float v = a > 0 ? px[i * 4 + c] / a : 0; o[i * 4 + c] = (unsigned char)lroundf(ci_clamp01(v * a + (1 - a)) * 255); }  /* over white */
        o[i * 4 + 3] = 255;
    }
    free(px);
    *w = (int)r.size.width; *h = (int)r.size.height; *scale = s; *ext = r;
    return o;
}
- (NSArray<CIFeature *> *)featuresInImage:(CIImage *)image options:(NSDictionary *)options {
    if (!image) return @[];
    NSMutableDictionary *o = [_opts mutableCopy]; [o addEntriesFromDictionary:options ?: @{}];
    int orient = [o[CIDetectorImageOrientation] intValue];
    CIImage *im = image;
    CGAffineTransform toImage = CGAffineTransformIdentity;          /* oriented space -> the given image's space */
    if (orient > 1 && orient <= 8) {
        CGAffineTransform t = [image imageTransformForOrientation:orient];
        im = [image imageByApplyingTransform:t];
        toImage = CGAffineTransformInvert(t);
    }
    NSArray *f = @[];
    if ([_type isEqualToString:CIDetectorTypeFace]) f = [self _faces:im options:o];
    else if ([_type isEqualToString:CIDetectorTypeRectangle]) f = [self _rectangles:im options:o];
    else if ([_type isEqualToString:CIDetectorTypeQRCode]) f = [self _qr:im];
    else if ([_type isEqualToString:CIDetectorTypeText]) f = [self _text:im options:o];
    if (!CGAffineTransformIsIdentity(toImage)) for (CIFeature *x in f) [self _map:x by:toImage];
    return f;
}
- (void)_map:(CIFeature *)f by:(CGAffineTransform)t {
    f.bounds = CGRectApplyAffineTransform(f.bounds, t);
    if ([f isKindOfClass:[CIFaceFeature class]]) {
        CIFaceFeature *x = (id)f;
        x.leftEyePosition = CGPointApplyAffineTransform(x.leftEyePosition, t); x.rightEyePosition = CGPointApplyAffineTransform(x.rightEyePosition, t);
        x.mouthPosition = CGPointApplyAffineTransform(x.mouthPosition, t);
    } else if ([f respondsToSelector:@selector(topLeft)]) {
        id x = f;
        [x setTopLeft:CGPointApplyAffineTransform([x topLeft], t)]; [x setTopRight:CGPointApplyAffineTransform([x topRight], t)];
        [x setBottomLeft:CGPointApplyAffineTransform([x bottomLeft], t)]; [x setBottomRight:CGPointApplyAffineTransform([x bottomRight], t)];
    }
}

/* ---- faces ---- */
- (NSArray *)_faces:(CIImage *)im options:(NSDictionary *)o {
    haar_cascade *fc = cascade(@"haarcascade_frontalface_default.xml");
    if (!fc) return @[];
    BOOL high = [o[CIDetectorAccuracy] isEqual:CIDetectorAccuracyHigh];
    int w, h; double s; CGRect ext;
    unsigned char *px = rgba_of(im, high ? 1024 : 640, &w, &h, &s, &ext);
    if (!px) return @[];
    float *g = malloc(sizeof(float) * (size_t)w * h);
    for (size_t i = 0; i < (size_t)w * h; i++) g[i] = 0.299f * px[i * 4] + 0.587f * px[i * 4 + 1] + 0.114f * px[i * 4 + 2];
    free(px);
    double minFrac = o[CIDetectorMinFeatureSize] ? [o[CIDetectorMinFeatureSize] doubleValue] : 0.1;
    int minSize = (int)fmax(24, fmin(w, h) * minFrac);
    int det[5 * 64];
    int n = haar_detect(fc, g, w, h, high ? 1.05 : 1.1, 3, minSize, det, 64);
    haar_cascade *ec = cascade(@"haarcascade_eye.xml"), *sc = [o[CIDetectorSmile] boolValue] ? cascade(@"haarcascade_smile.xml") : NULL;
    BOOL blink = [o[CIDetectorEyeBlink] boolValue];
    NSMutableArray *out = [NSMutableArray array];
    int maxCount = o[CIDetectorMaxFeatureCount] ? [o[CIDetectorMaxFeatureCount] intValue] : 64;
    /* larger faces first */
    for (int i = 0; i < n; i++) for (int j = i + 1; j < n; j++) if (det[j * 5 + 2] > det[i * 5 + 2]) for (int k = 0; k < 5; k++) { int t = det[i * 5 + k]; det[i * 5 + k] = det[j * 5 + k]; det[j * 5 + k] = t; }
    /* buffer space (top-down) -> Core Image space of the input */
    CGPoint (^toCI)(double, double) = ^CGPoint(double x, double y) { return CGPointMake(ext.origin.x / s + x / s, (ext.origin.y + h - y) / s); };
    for (int i = 0; i < n && (int)out.count < maxCount; i++) {
        int fx = det[i * 5], fy = det[i * 5 + 1], fw = det[i * 5 + 2], fh = det[i * 5 + 3];
        CIFaceFeature *f = [CIFaceFeature new];
        f.type = CIFeatureTypeFace;
        CGPoint a = toCI(fx, fy + fh), b = toCI(fx + fw, fy);
        f.bounds = CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y);
        /* eyes: the eye cascade over the upper half of the face (left/right as the viewer sees them) */
        CGPoint le = toCI(fx + fw * 0.3, fy + fh * 0.38), re = toCI(fx + fw * 0.7, fy + fh * 0.38);
        BOOL foundL = NO, foundR = NO;
        if (ec) {
            int ew = fw, eh = fh / 2;
            float *sub = malloc(sizeof(float) * (size_t)ew * eh);
            for (int y = 0; y < eh; y++) for (int x = 0; x < ew; x++) {
                int sx = fx + x, sy = fy + y; sx = sx < w ? sx : w - 1; sy = sy < h ? sy : h - 1;
                sub[(size_t)y * ew + x] = g[(size_t)sy * w + sx];
            }
            int ed[5 * 16]; int ne = haar_detect(ec, sub, ew, eh, 1.08, 2, (int)fmax(10, fw * 0.12), ed, 16);
            for (int k = 0; k < ne; k++) {
                double cx = fx + ed[k * 5] + ed[k * 5 + 2] / 2.0, cy = fy + ed[k * 5 + 1] + ed[k * 5 + 3] / 2.0;
                if (cx < fx + fw / 2.0 && !foundL) { le = toCI(cx, cy); foundL = YES; }
                else if (cx >= fx + fw / 2.0 && !foundR) { re = toCI(cx, cy); foundR = YES; }
            }
            free(sub);
        }
        f.hasLeftEyePosition = YES; f.leftEyePosition = le;
        f.hasRightEyePosition = YES; f.rightEyePosition = re;
        f.hasMouthPosition = YES; f.mouthPosition = toCI(fx + fw * 0.5, fy + fh * 0.78);
        f.hasFaceAngle = YES; f.faceAngle = (float)(atan2(re.y - le.y, re.x - le.x) * 180 / M_PI);
        if (blink && ec) { f.leftEyeClosed = !foundL; f.rightEyeClosed = !foundR; }
        if (sc) {
            int mw = fw, mh = fh / 2, my = fy + fh / 2;
            float *sub = malloc(sizeof(float) * (size_t)mw * mh);
            for (int y = 0; y < mh; y++) for (int x = 0; x < mw; x++) {
                int sx = fx + x, sy = my + y; sx = sx < w ? sx : w - 1; sy = sy < h ? sy : h - 1;
                sub[(size_t)y * mw + x] = g[(size_t)sy * w + sx];
            }
            int sd[5 * 8]; f.hasSmile = haar_detect(sc, sub, mw, mh, 1.1, 18, (int)fmax(18, fw * 0.25), sd, 8) > 0;
            free(sub);
        }
        [out addObject:f];
    }
    free(g);
    if ([o[CIDetectorTracking] boolValue]) {        /* tracking: faces that overlap a face of the previous image keep its ID */
        for (CIFaceFeature *f in out) {
            CIFaceFeature *best = nil; double bo = 0.3;
            for (CIFaceFeature *p in _tracked) {
                CGRect in = CGRectIntersection(f.bounds, p.bounds);
                double ov = CGRectIsNull(in) ? 0 : in.size.width * in.size.height / fmax(f.bounds.size.width * f.bounds.size.height, 1);
                if (ov > bo) { bo = ov; best = p; }
            }
            f.hasTrackingID = YES; f.hasTrackingFrameCount = YES;
            f.trackingID = best ? best.trackingID : _nextID++;
            f.trackingFrameCount = best ? best.trackingFrameCount + 1 : 1;
        }
        _tracked = [out copy];
    }
    return out;
}

/* ---- rectangles: the largest filled quadrilateral of either polarity (Otsu threshold) ---- */
static double cross2(const double *o, const double *a, const double *b) { return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]); }
static int cmp_pt(const void *a, const void *b) { const double *p = a, *q = b; return p[0] < q[0] ? -1 : p[0] > q[0] ? 1 : p[1] < q[1] ? -1 : p[1] > q[1]; }
static int hull(double *pts, int n, double *out) {
    qsort(pts, (size_t)n, sizeof(double) * 2, cmp_pt);
    int k = 0;
    for (int i = 0; i < n; i++) { while (k >= 2 && cross2(out + (k - 2) * 2, out + (k - 1) * 2, pts + i * 2) <= 0) k--; memcpy(out + k * 2, pts + i * 2, 16); k++; }
    for (int i = n - 2, t = k + 1; i >= 0; i--) { while (k >= t && cross2(out + (k - 2) * 2, out + (k - 1) * 2, pts + i * 2) <= 0) k--; memcpy(out + k * 2, pts + i * 2, 16); k++; }
    return k - 1;
}
static double poly_area(const double *p, int n) { double a = 0; for (int i = 0; i < n; i++) { int j = (i + 1) % n; a += p[i * 2] * p[j * 2 + 1] - p[j * 2] * p[i * 2 + 1]; } return fabs(a) / 2; }
- (NSArray *)_rectangles:(CIImage *)im options:(NSDictionary *)o {
    int w, h; double s; CGRect ext;
    unsigned char *px = rgba_of(im, 400, &w, &h, &s, &ext);
    if (!px) return @[];
    size_t n = (size_t)w * h;
    uint8_t *g = malloc(n); int hist[256] = { 0 };
    for (size_t i = 0; i < n; i++) { g[i] = (uint8_t)((px[i * 4] * 77 + px[i * 4 + 1] * 150 + px[i * 4 + 2] * 29) >> 8); hist[g[i]]++; }
    free(px);
    double sum = 0; for (int i = 0; i < 256; i++) sum += (double)i * hist[i];
    double sb = 0, wb = 0, best = -1; int th = 128;
    for (int t = 0; t < 256; t++) { wb += hist[t]; if (!wb) continue; double wf = n - wb; if (!wf) break; sb += (double)t * hist[t]; double mb = sb / wb, mf = (sum - sb) / wf, v = wb * wf * (mb - mf) * (mb - mf); if (v > best) { best = v; th = t; } }
    double minFrac = o[CIDetectorMinFeatureSize] ? [o[CIDetectorMinFeatureSize] doubleValue] : 0.2;
    double wantAspect = o[CIDetectorAspectRatio] ? [o[CIDetectorAspectRatio] doubleValue] : 0;
    int *lab = malloc(sizeof(int) * n), *stack = malloc(sizeof(int) * n);
    double *pts = malloc(sizeof(double) * 2 * n), *hl = malloc(sizeof(double) * 2 * (n + 1));
    double bestScore = 0, bq[8] = { 0 };
    for (int pol = 0; pol < 2; pol++) {
        for (size_t i = 0; i < n; i++) lab[i] = 0;
        int next = 1;
        for (size_t s0 = 0; s0 < n; s0++) {
            if (lab[s0] || ((g[s0] > th) != (pol == 0))) continue;
            int sp = 0, cnt = 0, np = 0; stack[sp++] = (int)s0; lab[s0] = next;
            int touches = 0;
            while (sp) {
                int i = stack[--sp], x = i % w, y = i / w; cnt++;
                int border = 0;
                if (x == 0 || y == 0 || x == w - 1 || y == h - 1) touches = 1;
                static const int d4[4][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
                for (int k = 0; k < 4; k++) {
                    int xx = x + d4[k][0], yy = y + d4[k][1];
                    if (xx < 0 || yy < 0 || xx >= w || yy >= h) { border = 1; continue; }
                    int j = yy * w + xx;
                    if ((g[j] > th) != (pol == 0)) { border = 1; continue; }
                    if (!lab[j]) { lab[j] = next; stack[sp++] = j; }
                }
                if (border) { pts[np * 2] = x + 0.5; pts[np * 2 + 1] = y + 0.5; np++; }
            }
            next++;
            if (touches || cnt < minFrac * minFrac * n || np < 8) continue;
            int nh = hull(pts, np, hl);
            if (nh < 4) continue;
            while (nh > 4) {            /* simplify the hull to a quadrilateral: drop the vertex adding the least area */
                int bi = 0; double ba = INFINITY;
                for (int i = 0; i < nh; i++) {
                    double *a = hl + ((i + nh - 1) % nh) * 2, *b = hl + i * 2, *c = hl + ((i + 1) % nh) * 2;
                    double t = fabs(cross2(a, b, c)) / 2;
                    if (t < ba) { ba = t; bi = i; }
                }
                memmove(hl + bi * 2, hl + (bi + 1) * 2, sizeof(double) * 2 * (nh - bi - 1)); nh--;
            }
            double qa = poly_area(hl, 4);
            if (qa < 1 || cnt / qa < 0.85 || cnt / qa > 1.15) continue;        /* the region fills the quadrilateral */
            double e1 = hypot(hl[2] - hl[0], hl[3] - hl[1]), e2 = hypot(hl[4] - hl[2], hl[5] - hl[3]);
            double ar = fmax(e1, e2) / fmax(fmin(e1, e2), 1e-6);
            double score = qa * (wantAspect > 0 ? 1 / (1 + fabs(ar - fmax(wantAspect, 1 / wantAspect))) : 1);
            if (score > bestScore) { bestScore = score; memcpy(bq, hl, sizeof bq); }
        }
    }
    free(g); free(lab); free(stack); free(pts); free(hl);
    if (bestScore <= 0) return @[];
    /* corners in Core Image space; top-left is the corner nearest the image's top-left */
    CGPoint c[4];
    for (int i = 0; i < 4; i++) c[i] = CGPointMake(ext.origin.x / s + bq[i * 2] / s, (ext.origin.y + h - bq[i * 2 + 1]) / s);
    double ix = ext.origin.x / s, iy = (ext.origin.y + h) / s;
    int tl = 0; double bd = INFINITY;
    for (int i = 0; i < 4; i++) { double d = hypot(c[i].x - ix, c[i].y - iy); if (d < bd) { bd = d; tl = i; } }
    /* hull order is counter-clockwise in buffer space (y down) = clockwise in Core Image space */
    CIRectangleFeature *f = [CIRectangleFeature new];
    f.type = CIFeatureTypeRectangle;
    CGPoint q[4] = { c[tl], c[(tl + 1) % 4], c[(tl + 2) % 4], c[(tl + 3) % 4] };
    BOOL clockwise = (q[1].x - q[0].x) * (q[2].y - q[0].y) - (q[1].y - q[0].y) * (q[2].x - q[0].x) < 0;
    f.topLeft = q[0]; f.topRight = clockwise ? q[1] : q[3]; f.bottomRight = q[2]; f.bottomLeft = clockwise ? q[3] : q[1];
    double x0 = fmin(fmin(q[0].x, q[1].x), fmin(q[2].x, q[3].x)), x1 = fmax(fmax(q[0].x, q[1].x), fmax(q[2].x, q[3].x));
    double y0 = fmin(fmin(q[0].y, q[1].y), fmin(q[2].y, q[3].y)), y1 = fmax(fmax(q[0].y, q[1].y), fmax(q[2].y, q[3].y));
    f.bounds = CGRectMake(x0, y0, x1 - x0, y1 - y0);
    return @[ f ];
}

/* ---- QR codes ---- */
- (NSArray *)_qr:(CIImage *)im {
    int w, h; double s; CGRect ext;
    unsigned char *px = rgba_of(im, 2048, &w, &h, &s, &ext);
    if (!px) return @[];
    for (size_t i = 0; i < (size_t)w * h; i++) { unsigned char t = px[i * 4]; px[i * 4] = px[i * 4 + 2]; px[i * 4 + 2] = t; }   /* BGRA */
    char *raw = isim_vision_barcodes_ex(px, w, h, w * 4, 1);
    free(px);
    if (!raw) { NSLog(@"isim: CIDetector: QR detection needs the host's libzbar or zxing-cpp"); return @[]; }
    NSMutableArray *out = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    for (NSString *line in [@(raw) componentsSeparatedByString:@"\n"]) {
        NSArray *f = [line componentsSeparatedByString:@"\t"];
        if (f.count < 4) continue;
        NSString *name = f[0];
        if (!([name containsString:@"QR"] && ![name containsString:@"Micro"])) continue;
        NSString *hex = f[3]; NSMutableData *d = [NSMutableData data];
        for (NSUInteger i = 0; i + 1 < hex.length; i += 2) { unsigned v; sscanf([hex substringWithRange:NSMakeRange(i, 2)].UTF8String, "%x", &v); uint8_t b = (uint8_t)v; [d appendBytes:&b length:1]; }
        if ([seen containsObject:d]) continue;            /* zbar and zxing may both report a symbol */
        [seen addObject:d];
        NSMutableArray *pts = [NSMutableArray array];
        for (NSString *p in [f[2] componentsSeparatedByString:@";"]) {
            NSArray *xy = [p componentsSeparatedByString:@","];
            if (xy.count == 2) [pts addObject:[NSValue valueWithCGPoint:CGPointMake(ext.origin.x / s + [xy[0] doubleValue] / s, (ext.origin.y + h - [xy[1] doubleValue]) / s)]];
        }
        if (pts.count < 4) continue;
        CIQRCodeFeature *q = [CIQRCodeFeature new];
        q.type = CIFeatureTypeQRCode;
        BOOL zx = ![name isEqualToString:@"QR-Code"];
        CGPoint p0 = [pts[0] CGPointValue], p1 = [pts[1] CGPointValue], p2 = [pts[2] CGPointValue], p3 = [pts[3] CGPointValue];
        if (zx) { q.topLeft = p0; q.topRight = p1; q.bottomRight = p2; q.bottomLeft = p3; }
        else { q.topLeft = p0; q.bottomLeft = p1; q.bottomRight = p2; q.topRight = p3; }
        double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
        for (NSValue *v in pts) { CGPoint p = v.CGPointValue; x0 = fmin(x0, p.x); y0 = fmin(y0, p.y); x1 = fmax(x1, p.x); y1 = fmax(y1, p.y); }
        q.bounds = CGRectMake(x0, y0, x1 - x0, y1 - y0);
        q.messageString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
        /* the descriptor: the decoded message encoded again by isim (isim does not read the symbol's own codewords) */
        uint8_t mods[177 * 177], cw[4096]; int ncw = sizeof cw, ver = 0, ecl = 1, mask = 0;
        if (isim_qr_encode_ex(d.bytes, (int)d.length, 1, mods, &ver, &ecl, &mask, cw, &ncw)) {
            static const CIQRCodeErrorCorrectionLevel lv[4] = { CIQRCodeErrorCorrectionLevelL, CIQRCodeErrorCorrectionLevelM, CIQRCodeErrorCorrectionLevelQ, CIQRCodeErrorCorrectionLevelH };
            q.symbolDescriptor = [CIQRCodeDescriptor descriptorWithPayload:[NSData dataWithBytes:cw length:(NSUInteger)ncw] symbolVersion:ver maskPattern:(uint8_t)mask errorCorrectionLevel:lv[ecl]];
        }
        [out addObject:q];
    }
    isim_media_free(raw);
    return out;
}

/* ---- text: tesseract's line boxes (words as sub-features) ---- */
- (NSArray *)_text:(CIImage *)im options:(NSDictionary *)o {
    if (!isim_vision_available(2)) return @[];
    int w, h; double s; CGRect ext;
    unsigned char *px = rgba_of(im, 2048, &w, &h, &s, &ext);
    if (!px) return @[];
    for (size_t i = 0; i < (size_t)w * h; i++) { unsigned char t = px[i * 4]; px[i * 4] = px[i * 4 + 2]; px[i * 4 + 2] = t; }
    char *raw = isim_vision_text(px, w, h, w * 4, "eng");
    free(px);
    if (!raw) return @[];
    BOOL subs = [o[CIDetectorReturnSubFeatures] boolValue];
    NSMutableDictionary *lines = [NSMutableDictionary dictionary]; NSMutableArray *order = [NSMutableArray array];
    CGRect (^toCI)(double, double, double, double) = ^CGRect(double x, double y, double ww, double hh) {
        return CGRectMake(ext.origin.x / s + x / s, (ext.origin.y + h - y - hh) / s, ww / s, hh / s);
    };
    for (NSString *row in [[@(raw) componentsSeparatedByString:@"\n"] subarrayWithRange:NSMakeRange(1, MAX(0, (NSInteger)[@(raw) componentsSeparatedByString:@"\n"].count - 1))]) {
        NSArray *c = [row componentsSeparatedByString:@"\t"];
        if (c.count < 12 || ![c[0] isEqualToString:@"5"] || [c[10] doubleValue] < 0) continue;
        if (![[c[11] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] length]) continue;
        NSString *key = [NSString stringWithFormat:@"%@.%@.%@", c[2], c[3], c[4]];
        if (!lines[key]) { lines[key] = [NSMutableArray array]; [order addObject:key]; }
        [lines[key] addObject:[CIVector vectorWithCGRect:toCI([c[6] doubleValue], [c[7] doubleValue], [c[8] doubleValue], [c[9] doubleValue])]];
    }
    isim_media_free(raw);
    NSMutableArray *out = [NSMutableArray array];
    CITextFeature *(^feature)(CGRect) = ^CITextFeature *(CGRect r) {
        CITextFeature *f = [CITextFeature new];
        f.type = CIFeatureTypeText; f.bounds = r;
        f.topLeft = CGPointMake(r.origin.x, CGRectGetMaxY(r)); f.topRight = CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r));
        f.bottomLeft = r.origin; f.bottomRight = CGPointMake(CGRectGetMaxX(r), r.origin.y);
        return f;
    };
    for (NSString *k in order) {
        CGRect u = CGRectNull; NSMutableArray *words = [NSMutableArray array];
        for (CIVector *v in lines[k]) { u = CGRectUnion(u, v.CGRectValue); [words addObject:feature(v.CGRectValue)]; }
        CITextFeature *f = feature(u);
        if (subs) f.subFeatures = words;
        [out addObject:f];
    }
    return out;
}
@end
