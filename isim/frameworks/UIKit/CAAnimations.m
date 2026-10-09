/* isim Core Animation: timing functions, CAAnimation classes and their evaluation, CATransaction and the frame
 * driver (a CADisplayLink that runs while layers animate).
 *
 * Evaluation follows CAMediaTiming: local = (t - beginTime) * speed + timeOffset, repeatCount/repeatDuration,
 * autoreverses and fillMode, then the timing function. Basic animations resolve from/to/by like Core Animation
 * (a missing end is the layer's current presentation value), with additive and cumulative modes; keyframe
 * animations support values or a path, keyTimes, per-segment timing functions, linear/discrete/paced/cubic
 * modes and rotationMode; springs are the damped harmonic oscillator; groups give their children the group's
 * local time. Animations apply to a presentation copy of the layer; the model is untouched. */
#import "CAPrivate.h"
#pragma clang diagnostic ignored "-Watomic-property-with-user-defined-accessor"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* ================= CAMediaTimingFunction ================= */
CAMediaTimingFunctionName const kCAMediaTimingFunctionLinear = @"linear", kCAMediaTimingFunctionEaseIn = @"easeIn",
    kCAMediaTimingFunctionEaseOut = @"easeOut", kCAMediaTimingFunctionEaseInEaseOut = @"easeInEaseOut", kCAMediaTimingFunctionDefault = @"default";
@implementation CAMediaTimingFunction { float _c[4]; NSString *_name; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithName:kCAMediaTimingFunctionLinear]; }
- (void)encodeWithCoder:(NSCoder *)c {}
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name { return [[self alloc] initWithName:name]; }
+ (instancetype)functionWithControlPoints:(float)a :(float)b :(float)c :(float)d { return [[self alloc] initWithControlPoints:a :b :c :d]; }
- (instancetype)initWithName:(CAMediaTimingFunctionName)name {
    float p[4] = { 0, 0, 1, 1 };
    if ([name isEqual:kCAMediaTimingFunctionEaseIn]) { p[0] = 0.42f; p[1] = 0; p[2] = 1; p[3] = 1; }
    else if ([name isEqual:kCAMediaTimingFunctionEaseOut]) { p[0] = 0; p[1] = 0; p[2] = 0.58f; p[3] = 1; }
    else if ([name isEqual:kCAMediaTimingFunctionEaseInEaseOut]) { p[0] = 0.42f; p[1] = 0; p[2] = 0.58f; p[3] = 1; }
    else if ([name isEqual:kCAMediaTimingFunctionDefault]) { p[0] = 0.25f; p[1] = 0.1f; p[2] = 0.25f; p[3] = 1; }
    self = [self initWithControlPoints:p[0] :p[1] :p[2] :p[3]];
    _name = name;
    return self;
}
- (instancetype)initWithControlPoints:(float)a :(float)b :(float)c :(float)d {
    if ((self = [super init])) { _c[0] = fminf(1, fmaxf(0, a)); _c[1] = b; _c[2] = fminf(1, fmaxf(0, c)); _c[3] = d; }
    return self;
}
- (void)getControlPointAtIndex:(size_t)i values:(float *)ptr {
    switch (i) {
    case 0: ptr[0] = 0; ptr[1] = 0; break;
    case 1: ptr[0] = _c[0]; ptr[1] = _c[1]; break;
    case 2: ptr[0] = _c[2]; ptr[1] = _c[3]; break;
    default: ptr[0] = 1; ptr[1] = 1; break;
    }
}
static double bez(double a, double b, double t) { double u = 1 - t; return 3 * a * u * u * t + 3 * b * u * t * t + t * t * t; }
static double bez_d(double a, double b, double t) { double u = 1 - t; return 3 * a * u * u + 6 * (b - a) * u * t + 3 * (1 - b) * t * t; }
- (float)_isim_solve:(float)x {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    if (_c[0] == _c[1] && _c[2] == _c[3]) return x;          /* linear */
    double t = x;
    for (int i = 0; i < 8; i++) {                               /* Newton, then bisection if it stalls */
        double e = bez(_c[0], _c[2], t) - x, d = bez_d(_c[0], _c[2], t);
        if (fabs(e) < 1e-7) return (float)bez(_c[1], _c[3], t);
        if (fabs(d) < 1e-6) break;
        t -= e / d;
    }
    double lo = 0, hi = 1; t = x;
    for (int i = 0; i < 40; i++) { double v = bez(_c[0], _c[2], t); if (fabs(v - x) < 1e-7) break; if (v < x) lo = t; else hi = t; t = (lo + hi) / 2; }
    return (float)bez(_c[1], _c[3], t);
}
- (NSString *)description { return _name ?: [NSString stringWithFormat:@"(%g, %g, %g, %g)", _c[0], _c[1], _c[2], _c[3]]; }
@end

/* ================= animation classes ================= */
CAAnimationCalculationMode const kCAAnimationLinear = @"linear", kCAAnimationDiscrete = @"discrete", kCAAnimationPaced = @"paced",
    kCAAnimationCubic = @"cubic", kCAAnimationCubicPaced = @"cubicPaced";
CAAnimationRotationMode const kCAAnimationRotateAuto = @"auto", kCAAnimationRotateAutoReverse = @"autoReverse";
NSString *const kCATransition = @"transition";
CATransitionType const kCATransitionFade = @"fade", kCATransitionMoveIn = @"moveIn", kCATransitionPush = @"push", kCATransitionReveal = @"reveal";
CATransitionSubtype const kCATransitionFromRight = @"fromRight", kCATransitionFromLeft = @"fromLeft", kCATransitionFromTop = @"fromTop",
    kCATransitionFromBottom = @"fromBottom";
CAValueFunctionName const kCAValueFunctionRotateX = @"rotateX", kCAValueFunctionRotateY = @"rotateY", kCAValueFunctionRotateZ = @"rotateZ",
    kCAValueFunctionScale = @"scale", kCAValueFunctionScaleX = @"scaleX", kCAValueFunctionScaleY = @"scaleY", kCAValueFunctionScaleZ = @"scaleZ",
    kCAValueFunctionTranslate = @"translate", kCAValueFunctionTranslateX = @"translateX", kCAValueFunctionTranslateY = @"translateY",
    kCAValueFunctionTranslateZ = @"translateZ";

@implementation CAAnimation { NSMutableDictionary *_extra; }
@synthesize beginTime = _beginTime, duration = _duration, timeOffset = _timeOffset, repeatDuration = _repeatDuration, speed = _speed,
    repeatCount = _repeatCount, autoreverses = _autoreverses, fillMode = _fillMode;
+ (instancetype)animation { return [self new]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)c {}
+ (id)defaultValueForKey:(NSString *)key { return nil; }
- (BOOL)shouldArchiveValueForKey:(NSString *)key { return YES; }
- (instancetype)init { if ((self = [super init])) { _speed = 1; _removedOnCompletion = YES; _fillMode = kCAFillModeRemoved; } return self; }
- (id)copyWithZone:(NSZone *)z {
    CAAnimation *a = [[[self class] alloc] init];
    a->_beginTime = _beginTime; a->_duration = _duration; a->_timeOffset = _timeOffset; a->_repeatDuration = _repeatDuration; a->_speed = _speed;
    a->_repeatCount = _repeatCount; a->_autoreverses = _autoreverses; a->_fillMode = _fillMode; a->_timingFunction = _timingFunction;
    a->_delegate = _delegate; a->_removedOnCompletion = _removedOnCompletion; a->_preferredFrameRateRange = _preferredFrameRateRange;
    a->_extra = [_extra mutableCopy];
    [self _isim_copyInto:a];
    return a;
}
- (void)_isim_copyInto:(CAAnimation *)a {}
/* animations are key-value containers (apps tag them with setValue:forKey:) */
- (void)setValue:(id)v forUndefinedKey:(NSString *)k { if (!_extra) _extra = [NSMutableDictionary dictionary]; if (v) _extra[k] = v; else [_extra removeObjectForKey:k]; }
- (id)valueForUndefinedKey:(NSString *)k { return _extra[k]; }
- (void)runActionForKey:(NSString *)event object:(id)o arguments:(NSDictionary *)d { if ([o isKindOfClass:[CALayer class]]) [(CALayer *)o addAnimation:self forKey:event]; }
@end

@implementation CAPropertyAnimation
+ (instancetype)animationWithKeyPath:(NSString *)path { CAPropertyAnimation *a = [self new]; a.keyPath = path; return a; }
- (void)_isim_copyInto:(CAPropertyAnimation *)a { a->_keyPath = _keyPath; a->_additive = _additive; a->_cumulative = _cumulative; a->_valueFunction = _valueFunction; }
@end
@implementation CABasicAnimation
- (void)_isim_copyInto:(CABasicAnimation *)a { [super _isim_copyInto:a]; a->_fromValue = _fromValue; a->_toValue = _toValue; a->_byValue = _byValue; }
@end
@implementation CAKeyframeAnimation
- (instancetype)init { if ((self = [super init])) _calculationMode = kCAAnimationLinear; return self; }
- (void)dealloc { if (_path) CGPathRelease(_path); }
- (void)setPath:(CGPathRef)p { CGPathRetain(p); if (_path) CGPathRelease(_path); _path = p; }
- (void)_isim_copyInto:(CAKeyframeAnimation *)a {
    [super _isim_copyInto:a];
    a->_values = _values; a.path = _path; a->_keyTimes = _keyTimes; a->_timingFunctions = _timingFunctions; a->_calculationMode = _calculationMode;
    a->_tensionValues = _tensionValues; a->_continuityValues = _continuityValues; a->_biasValues = _biasValues; a->_rotationMode = _rotationMode;
}
@end
@implementation CASpringAnimation
- (instancetype)init { if ((self = [super init])) { _mass = 1; _stiffness = 100; _damping = 10; } return self; }
- (instancetype)initWithPerceptualDuration:(CFTimeInterval)d bounce:(CGFloat)b {
    if ((self = [self init])) {
        d = d > 0 ? d : 0.5;
        _mass = 1; _stiffness = pow(2 * M_PI / d, 2);
        _damping = b >= 0 ? 4 * M_PI * (1 - b) / d : 4 * M_PI / (d * (1 + b));
        self.duration = self.settlingDuration;
    }
    return self;
}
- (void)_isim_copyInto:(CASpringAnimation *)a {
    [super _isim_copyInto:a];
    a->_mass = _mass; a->_stiffness = _stiffness; a->_damping = _damping; a->_initialVelocity = _initialVelocity; a->_allowsOverdamping = _allowsOverdamping;
}
/* displacement from the target (start -1, target 0) at time t */
- (double)_isim_displacement:(double)t {
    double m = _mass > 0 ? _mass : 1, k = _stiffness > 0 ? _stiffness : 100, c = fmax(0, _damping);
    double w0 = sqrt(k / m), z = c / (2 * sqrt(k * m)), v0 = _initialVelocity, A = -1;
    if (!_allowsOverdamping && z > 1) z = 1;
    if (z < 1) {
        double wd = w0 * sqrt(1 - z * z), B = (v0 + z * w0 * A) / wd;
        return exp(-z * w0 * t) * (A * cos(wd * t) + B * sin(wd * t));
    }
    if (z == 1) return exp(-w0 * t) * (A + (v0 + w0 * A) * t);
    double r1 = -w0 * (z - sqrt(z * z - 1)), r2 = -w0 * (z + sqrt(z * z - 1));
    double C2 = (v0 - r1 * A) / (r2 - r1), C1 = A - C2;
    return C1 * exp(r1 * t) + C2 * exp(r2 * t);
}
- (CFTimeInterval)settlingDuration {
    /* until the motion stays within 0.1% of the distance */
    double last = 0;
    for (double t = 0; t < 60; t += 1.0 / 120) if (fabs([self _isim_displacement:t]) > 0.001) last = t;
    return last + 1.0 / 120;
}
- (CFTimeInterval)perceptualDuration { double k = _stiffness > 0 ? _stiffness : 100, m = _mass > 0 ? _mass : 1; return 2 * M_PI / sqrt(k / m); }
- (CGFloat)bounce {
    double d = self.perceptualDuration, c = _damping;
    double b = 1 - c * d / (4 * M_PI);
    return b >= 0 ? b : 4 * M_PI / (c * d) - 1;
}
@end
@implementation CAAnimationGroup
- (void)_isim_copyInto:(CAAnimationGroup *)a { NSMutableArray *c = [NSMutableArray array]; for (CAAnimation *x in _animations) [c addObject:[x copy]]; a->_animations = c; }
@end
@implementation CATransition { int _snapshot; }
- (instancetype)init { if ((self = [super init])) { _type = kCATransitionFade; _endProgress = 1; } return self; }
- (void)dealloc { if (_snapshot) isim_image_free(_snapshot); }
- (void)_isim_copyInto:(CATransition *)a { a->_type = _type; a->_subtype = _subtype; a->_startProgress = _startProgress; a->_endProgress = _endProgress; }
/* the layer's previous appearance (a screen snapshot taken when the transition was added) */
int ca_transition_snapshot(CATransition *tr) { return tr->_snapshot; }
void ca_transition_set_snapshot(CATransition *tr, int img) { if (tr->_snapshot) isim_image_free(tr->_snapshot); tr->_snapshot = img; }
@end
@implementation CAValueFunction { NSString *_n; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)c {}
+ (instancetype)functionWithName:(CAValueFunctionName)name { CAValueFunction *f = [self new]; f->_n = [name copy]; return f; }
- (CAValueFunctionName)name { return _n; }
@end

/* ================= evaluation ================= */
static BOOL fill_back(CAAnimation *a) { return [a.fillMode isEqual:kCAFillModeBackwards] || [a.fillMode isEqual:kCAFillModeBoth]; }
static BOOL fill_fwd(CAAnimation *a) { return [a.fillMode isEqual:kCAFillModeForwards] || [a.fillMode isEqual:kCAFillModeBoth]; }
static double anim_duration(CAAnimation *a) { return a.duration > 0 ? a.duration : 0.25; }
static double active_duration(CAAnimation *a) {
    double d = anim_duration(a), cycle = a.autoreverses ? 2 * d : d;
    if (a.repeatDuration > 0) return a.repeatDuration;
    double rc = a.repeatCount;
    if (isinf(rc) || rc >= 1e30) return INFINITY;
    return cycle * (rc > 0 ? rc : 1);
}
double ca_anim_active_end(CAAnimation *a) {
    double act = active_duration(a);
    if (isinf(act) || a.speed == 0) return INFINITY;
    return a.beginTime + (act - a.timeOffset) / fabs(a.speed);
}
/* 0 inactive, 1 active, 2 finished with its end value held, 3 finished without effect */
static int timing_state(CAAnimation *a, double t, double *frac, double *iter) {
    double d = anim_duration(a), cycle = a.autoreverses ? 2 * d : d;
    double local = (t - a.beginTime) * a.speed + a.timeOffset;
    double act = active_duration(a);
    int state = 1;
    if (local < 0) { if (!fill_back(a)) return 0; local = 0; }
    if (local >= act) { if (!fill_fwd(a)) return 3; local = act; state = 2; }
    double it = floor(local / cycle), pos = local - it * cycle;
    if (state == 2 && pos < 1e-9 && it > 0) { it -= 1; pos = cycle; }
    if (a.autoreverses && pos > d) pos = 2 * d - pos;
    *frac = fmin(1, fmax(0, pos / d)); *iter = it;
    return state;
}
static double ease(CAMediaTimingFunction *f, double x) { return f ? [f _isim_solve:(float)x] : x; }

static BOOL apply_basic(CABasicAnimation *a, CALayer *p, double f, double iter) {
    NSString *kp = a.keyPath; ca_val base;
    if (!kp || ![p _isim_getAnim:kp value:&base]) return NO;
    int kind = base.kind;
    ca_val from, to, by, A, B, v;
    BOOL hf = ca_val_from_id(a.fromValue, kind, &from), ht = ca_val_from_id(a.toValue, kind, &to), hb = ca_val_from_id(a.byValue, kind, &by);
    if (kind == CAV_OBJ) { hf = a.fromValue != nil; ht = a.toValue != nil; hb = NO; }
    if (hf && ht) { A = from; B = to; }
    else if (hf && hb) { A = from; ca_val_add(&from, &by, 1, &B); }
    else if (hb && ht) { ca_val_add(&to, &by, -1, &A); B = to; }
    else if (hf) { A = from; B = base; }
    else if (ht) { A = base; B = to; }
    else if (hb) { A = base; ca_val_add(&base, &by, 1, &B); }
    else return NO;
    if (a.additive && !hf && !ht && hb) { ca_val zero = base; for (int i = 0; i < zero.n; i++) zero.v[i] = 0; if (kind == CAV_T3D) { CATransform3D id3 = CATransform3DIdentity; memcpy(zero.v, &id3, sizeof id3); } A = zero; B = by; }
    if ([a isKindOfClass:[CASpringAnimation class]]) {
        CASpringAnimation *s = (CASpringAnimation *)a;
        double x = 1 + [s _isim_displacement:f * anim_duration(a)];
        ca_val diff; ca_val_add(&B, &A, -1, &diff);
        if (kind == CAV_T3D || kind == CAV_OBJ) ca_val_lerp(&A, &B, x, &v);
        else ca_val_add(&A, &diff, x, &v);
    } else ca_val_lerp(&A, &B, f, &v);
    if (a.cumulative && iter > 0) { ca_val diff; ca_val_add(&B, &A, -1, &diff); ca_val_add(&v, &diff, iter, &v); }
    if (a.additive) ca_val_add(&base, &v, 1, &v);
    return [p _isim_setAnim:kp value:&v];
}

/* path sampling: points along a flattened CGPath, with the element ends as keyframes */
typedef struct { CGPoint *pts; int n, cap; int *keyIdx; int nk, kcap; CGPoint last, start; } flat_path;
static void fp_add(flat_path *fp, CGPoint p) { if (fp->n == fp->cap) { fp->cap = fp->cap ? fp->cap * 2 : 64; fp->pts = realloc(fp->pts, fp->cap * sizeof(CGPoint)); } fp->pts[fp->n++] = p; }
static void fp_key(flat_path *fp) { if (fp->nk == fp->kcap) { fp->kcap = fp->kcap ? fp->kcap * 2 : 16; fp->keyIdx = realloc(fp->keyIdx, fp->kcap * sizeof(int)); } fp->keyIdx[fp->nk++] = fp->n - 1; }
static void fp_apply(void *info, const CGPathElement *e) {
    flat_path *fp = info;
    switch (e->type) {
    case kCGPathElementMoveToPoint: if (fp->n == 0) { fp_add(fp, e->points[0]); fp_key(fp); } else { fp_add(fp, e->points[0]); fp_key(fp); } fp->last = fp->start = e->points[0]; break;
    case kCGPathElementAddLineToPoint: fp_add(fp, e->points[0]); fp_key(fp); fp->last = e->points[0]; break;
    case kCGPathElementAddQuadCurveToPoint:
        for (int i = 1; i <= 16; i++) { double t = i / 16.0, u = 1 - t;
            fp_add(fp, CGPointMake(u * u * fp->last.x + 2 * u * t * e->points[0].x + t * t * e->points[1].x, u * u * fp->last.y + 2 * u * t * e->points[0].y + t * t * e->points[1].y)); }
        fp_key(fp); fp->last = e->points[1]; break;
    case kCGPathElementAddCurveToPoint:
        for (int i = 1; i <= 24; i++) { double t = i / 24.0, u = 1 - t;
            fp_add(fp, CGPointMake(u * u * u * fp->last.x + 3 * u * u * t * e->points[0].x + 3 * u * t * t * e->points[1].x + t * t * t * e->points[2].x,
                                   u * u * u * fp->last.y + 3 * u * u * t * e->points[0].y + 3 * u * t * t * e->points[1].y + t * t * t * e->points[2].y)); }
        fp_key(fp); fp->last = e->points[2]; break;
    case kCGPathElementCloseSubpath: fp_add(fp, fp->start); fp_key(fp); fp->last = fp->start; break;
    }
}
static double seg_len(CGPoint a, CGPoint b) { return hypot(b.x - a.x, b.y - a.y); }
/* position at fraction u of the polyline between point indices i0..i1; also the tangent angle */
static CGPoint poly_at(const CGPoint *pts, int i0, int i1, double u, double *angle) {
    double total = 0; for (int i = i0; i < i1; i++) total += seg_len(pts[i], pts[i + 1]);
    double target = u * total, acc = 0;
    for (int i = i0; i < i1; i++) {
        double l = seg_len(pts[i], pts[i + 1]);
        if (acc + l >= target || i == i1 - 1) {
            double k = l > 0 ? fmin(1, fmax(0, (target - acc) / l)) : 0;
            if (angle && l > 0) *angle = atan2(pts[i + 1].y - pts[i].y, pts[i + 1].x - pts[i].x);
            return CGPointMake(pts[i].x + (pts[i + 1].x - pts[i].x) * k, pts[i].y + (pts[i + 1].y - pts[i].y) * k);
        }
        acc += l;
    }
    return pts[i0];
}
static int segment_for(NSArray<NSNumber *> *keyTimes, int nseg, double f, double *u) {
    if (keyTimes.count == (NSUInteger)nseg + 1) {
        for (int i = 0; i < nseg; i++) {
            double t0 = keyTimes[i].doubleValue, t1 = keyTimes[i + 1].doubleValue;
            if (f <= t1 || i == nseg - 1) { *u = t1 > t0 ? fmin(1, fmax(0, (f - t0) / (t1 - t0))) : 1; return i; }
        }
    }
    double x = f * nseg; int i = (int)floor(x); if (i >= nseg) i = nseg - 1; if (i < 0) i = 0;
    *u = x - i; return i;
}
static BOOL apply_keyframe(CAKeyframeAnimation *a, CALayer *p, double f, double iter) {
    NSString *kp = a.keyPath; ca_val base;
    if (!kp || ![p _isim_getAnim:kp value:&base]) return NO;
    NSString *mode = a.calculationMode;
    BOOL paced = [mode isEqual:kCAAnimationPaced] || [mode isEqual:kCAAnimationCubicPaced];
    BOOL discrete = [mode isEqual:kCAAnimationDiscrete];
    BOOL cubic = [mode isEqual:kCAAnimationCubic] || [mode isEqual:kCAAnimationCubicPaced];
    ca_val v;
    if (a.path) {
        flat_path fp = { 0 };
        CGPathApply(a.path, &fp, fp_apply);
        if (fp.n < 2 || fp.nk < 2) { free(fp.pts); free(fp.keyIdx); return NO; }
        int nseg = fp.nk - 1; double u, angle = 0; CGPoint pt;
        if (paced) pt = poly_at(fp.pts, 0, fp.n - 1, f, &angle);
        else {
            int s = segment_for(a.keyTimes, nseg, f, &u);
            NSArray *tfs = a.timingFunctions; if (s < (int)tfs.count) u = ease(tfs[s], u);
            if (discrete) { int k = f >= 1 ? nseg : s; pt = fp.pts[fp.keyIdx[k]]; }
            else pt = poly_at(fp.pts, fp.keyIdx[s], fp.keyIdx[s + 1], u, &angle);
        }
        free(fp.pts); free(fp.keyIdx);
        v = base; v.kind = CAV_POINT; v.n = 2; v.v[0] = pt.x; v.v[1] = pt.y;
        if (a.additive) { v.v[0] += base.v[0]; v.v[1] += base.v[1]; }
        BOOL ok = [p _isim_setAnim:kp value:&v];
        if (a.rotationMode) {
            if ([a.rotationMode isEqual:kCAAnimationRotateAutoReverse]) angle += M_PI;
            ca_val r = { 0 }; r.kind = CAV_NUM; r.n = 1; r.v[0] = angle;
            [p _isim_setAnim:@"transform.rotation.z" value:&r];
        }
        return ok;
    }
    NSArray *values = a.values;
    int n = (int)values.count;
    if (n == 0) return NO;
    ca_val *vals = calloc((size_t)n, sizeof(ca_val));
    for (int i = 0; i < n; i++) if (!ca_val_from_id(values[i], base.kind, &vals[i])) vals[i] = base;
    if (n == 1) v = vals[0];
    else if (discrete) {
        NSArray<NSNumber *> *kt = a.keyTimes; int idx = 0;
        if (kt.count >= (NSUInteger)n) { for (int i = 0; i < n; i++) if (f >= kt[i].doubleValue) idx = i; }
        else { idx = (int)floor(f * n); if (idx >= n) idx = n - 1; }
        v = vals[idx];
    } else {
        int nseg = n - 1, s; double u;
        if (paced) {
            double *cum = calloc((size_t)n, sizeof(double));
            for (int i = 1; i < n; i++) cum[i] = cum[i - 1] + ca_val_distance(&vals[i - 1], &vals[i]);
            double total = cum[n - 1], target = f * total;
            s = nseg - 1; u = 1;
            for (int i = 0; i < nseg; i++) if (target <= cum[i + 1] || i == nseg - 1) { double l = cum[i + 1] - cum[i]; s = i; u = l > 0 ? (target - cum[i]) / l : 1; break; }
            free(cum);
        } else {
            s = segment_for(a.keyTimes, nseg, f, &u);
            NSArray *tfs = a.timingFunctions; if (s < (int)tfs.count) u = ease(tfs[s], u);
        }
        if (cubic && vals[0].kind != CAV_OBJ && vals[0].kind != CAV_T3D) {   /* Catmull-Rom through the values */
            const ca_val *p0 = &vals[s > 0 ? s - 1 : s], *p1 = &vals[s], *p2 = &vals[s + 1], *p3 = &vals[s + 2 < n ? s + 2 : s + 1];
            v = *p1; double u2 = u * u, u3 = u2 * u;
            for (int i = 0; i < v.n; i++)
                v.v[i] = 0.5 * (2 * p1->v[i] + (-p0->v[i] + p2->v[i]) * u + (2 * p0->v[i] - 5 * p1->v[i] + 4 * p2->v[i] - p3->v[i]) * u2 + (-p0->v[i] + 3 * p1->v[i] - 3 * p2->v[i] + p3->v[i]) * u3);
        } else ca_val_lerp(&vals[s], &vals[s + 1], u, &v);
    }
    if (a.cumulative && iter > 0 && n > 1) { ca_val diff; ca_val_add(&vals[n - 1], &vals[0], -1, &diff); ca_val_add(&v, &diff, iter, &v); }
    if (a.additive) ca_val_add(&base, &v, 1, &v);
    free(vals);
    return [p _isim_setAnim:kp value:&v];
}

BOOL ca_anim_apply(CAAnimation *a, CALayer *p, double t, int *state) {
    double frac = 0, iter = 0;
    int st = timing_state(a, t, &frac, &iter);
    *state = st == 3 ? 2 : st;
    if (st == 0 || st == 3) return NO;
    if ([a isKindOfClass:[CAAnimationGroup class]]) {
        double d = anim_duration(a), gt = ease(a.timingFunction, frac) * d;
        BOOL any = NO;
        for (CAAnimation *c in ((CAAnimationGroup *)a).animations) {
            CAAnimation *child = c;
            if (child.duration <= 0) { child = [c copy]; child.duration = d; }
            int cs; if (ca_anim_apply(child, p, gt, &cs)) any = YES;
        }
        return any;
    }
    if ([a isKindOfClass:[CATransition class]]) return NO;           /* drawn by the renderer (ca_transition_progress) */
    if ([a isKindOfClass:[CASpringAnimation class]]) return apply_basic((CABasicAnimation *)a, p, frac, iter);
    double f = ease(a.timingFunction, frac);
    if ([a isKindOfClass:[CABasicAnimation class]]) return apply_basic((CABasicAnimation *)a, p, f, iter);
    if ([a isKindOfClass:[CAKeyframeAnimation class]]) return apply_keyframe((CAKeyframeAnimation *)a, p, f, iter);
    return NO;
}

/* ================= CATransition rendering ================= */
/* the transition's progress (0...1) at layer time t, or -1 when inactive */
double ca_transition_progress(CATransition *tr, double t) {
    double frac, iter;
    int st = timing_state(tr, t, &frac, &iter);
    if (st == 0 || st == 3 || st == 2) return -1;
    double f = ease(tr.timingFunction, frac);
    return tr.startProgress + (tr.endProgress - tr.startProgress) * f;
}

/* ================= CATransaction ================= */
NSString *const kCATransactionAnimationDuration = @"animationDuration", *const kCATransactionDisableActions = @"disableActions",
    *const kCATransactionAnimationTimingFunction = @"animationTimingFunction", *const kCATransactionCompletionBlock = @"completionBlock";
@interface __IsimCATx : NSObject { @public NSMutableDictionary *vals; int pending; BOOL committed; }
@end
@implementation __IsimCATx @end
static NSMutableArray<__IsimCATx *> *tx_stack;
static __IsimCATx *implicit_tx;
static void tx_check(__IsimCATx *tx) {
    if (!tx->committed || tx->pending > 0) return;
    void (^c)(void) = tx->vals[kCATransactionCompletionBlock];
    [tx->vals removeObjectForKey:kCATransactionCompletionBlock];
    if (c) dispatch_async(dispatch_get_main_queue(), c);
}
static __IsimCATx *tx_current(BOOL create) {
    if (tx_stack.count) return tx_stack.lastObject;
    if (!implicit_tx && create) {
        __IsimCATx *tx = implicit_tx = [__IsimCATx new];
        tx->vals = [NSMutableDictionary dictionary];
        dispatch_async(dispatch_get_main_queue(), ^{     /* the implicit transaction commits at the end of this run-loop turn */
            if (implicit_tx == tx) implicit_tx = nil;
            tx->committed = YES; tx_check(tx);
        });
    }
    return implicit_tx;
}
static id tx_value(NSString *key) {
    for (__IsimCATx *tx in [tx_stack reverseObjectEnumerator]) { id v = tx->vals[key]; if (v) return v; }
    return implicit_tx ? implicit_tx->vals[key] : nil;
}
NSArray *ca_tx_current_list(void) {
    NSMutableArray *a = [NSMutableArray arrayWithArray:tx_stack ?: @[]];
    if (implicit_tx) [a addObject:implicit_tx];
    return a.count ? a : nil;
}
void ca_tx_register(id entry) { for (__IsimCATx *tx in ca_tx_current_list()) tx->pending++; }
void ca_tx_entry_done(NSArray *txs) { for (__IsimCATx *tx in txs) { tx->pending--; tx_check(tx); } }
double ca_tx_duration(void) { id v = tx_value(kCATransactionAnimationDuration); return v ? [v doubleValue] : 0.25; }
CAMediaTimingFunction *ca_tx_timing(void) { return tx_value(kCATransactionAnimationTimingFunction); }
BOOL ca_tx_disabled(void) { return [tx_value(kCATransactionDisableActions) boolValue]; }

@implementation CATransaction
+ (void)begin {
    if (!tx_stack) tx_stack = [NSMutableArray array];
    __IsimCATx *tx = [__IsimCATx new]; tx->vals = [NSMutableDictionary dictionary];
    [tx_stack addObject:tx];
}
+ (void)commit {
    if (!tx_stack.count) return;
    __IsimCATx *tx = tx_stack.lastObject; [tx_stack removeLastObject];
    tx->committed = YES;
    tx_check(tx);
    isim_ui_set_needs_display();
}
+ (void)flush { isim_ui_set_needs_display(); }
+ (void)lock {}
+ (void)unlock {}
+ (CFTimeInterval)animationDuration { return ca_tx_duration(); }
+ (void)setAnimationDuration:(CFTimeInterval)d { [self setValue:@(d) forKey:kCATransactionAnimationDuration]; }
+ (CAMediaTimingFunction *)animationTimingFunction { return ca_tx_timing(); }
+ (void)setAnimationTimingFunction:(CAMediaTimingFunction *)f { [self setValue:f forKey:kCATransactionAnimationTimingFunction]; }
+ (BOOL)disableActions { return ca_tx_disabled(); }
+ (void)setDisableActions:(BOOL)flag { [self setValue:@(flag) forKey:kCATransactionDisableActions]; }
+ (void (^)(void))completionBlock { return tx_value(kCATransactionCompletionBlock); }
+ (void)setCompletionBlock:(void (^)(void))block { [self setValue:[block copy] forKey:kCATransactionCompletionBlock]; }
+ (id)valueForKey:(NSString *)key { return tx_value(key); }
+ (void)setValue:(id)v forKey:(NSString *)key {
    __IsimCATx *tx = tx_current(YES);
    if (v) tx->vals[key] = v; else [tx->vals removeObjectForKey:key];
}
@end

/* ================= frame driver ================= */
@interface __IsimCADriver : NSObject
@end
static CADisplayLink *driver_link;
static __IsimCADriver *driver;
static NSMutableArray *tickers;
@implementation __IsimCADriver
- (void)tick:(CADisplayLink *)l {
    double now = CACurrentMediaTime();
    BOOL any = NO;
    NSMutableArray *layers = ca_animated_layers();
    for (CALayer *layer in [layers copy]) {
        if ([layer _isim_tickAnimations:now]) any = YES;
        else [layers removeObjectIdenticalTo:layer];
    }
    for (id o in [tickers copy]) {
        if ([o _isim_tick:now]) any = YES;
        else [tickers removeObjectIdenticalTo:o];
    }
    /* layers or tickers added during this tick (e.g. an animation started from animationDidStop:) keep it going */
    if (!any && !layers.count && !tickers.count) { [driver_link invalidate]; driver_link = nil; }
}
@end
void ca_driver_wake(void) {
    if (driver_link) return;
    if (!driver) driver = [__IsimCADriver new];
    driver_link = [CADisplayLink displayLinkWithTarget:driver selector:@selector(tick:)];
    [driver_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    isim_ui_set_needs_display();
}
void ca_driver_add_ticker(id obj) {
    if (!tickers) tickers = [NSMutableArray array];
    if ([tickers indexOfObjectIdenticalTo:obj] == NSNotFound) [tickers addObject:obj];
    ca_driver_wake();
}
