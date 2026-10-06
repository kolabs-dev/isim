/* Two-finger gesture recognizers (UIPinchGestureRecognizer, UIRotationGestureRecognizer) and touch filters.
 * The host gives isim a second finger like the Simulator: Option-drag (mirrored around the screen centre: pinch and
 * rotate), Option+Shift-drag (two fingers together: two-finger pan), and the script commands
 * `pinch X Y SCALE SECS`, `rotate2 X Y DEGREES SECS`, `twofinger X Y DX DY SECS`. */
#import "UIKitInputPrivate.h"
#include <math.h>

@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@property (nonatomic) CGPoint startPoint, lastPoint;
@property (nonatomic, strong) NSMutableArray<UITouch *> *isimTouches;
- (void)_fire;
@end

/* ---- touch filters ---- */
static NSMutableArray<IsimTouchFilter> *touch_filters;
void isim_ui_add_touch_filter(IsimTouchFilter f) {
    if (!touch_filters) touch_filters = [NSMutableArray array];
    [touch_filters addObject:[f copy]];
}
BOOL isim_ui_touch_filtered(const struct isim_event *ev) {
    for (IsimTouchFilter f in [touch_filters copy]) if (f(ev)) return YES;
    return NO;
}

/* ---- shared two-finger tracking ---- */
/* the two touches (window coordinates): distance and angle between them, and their centroid */
static BOOL two_fingers(NSArray<UITouch *> *ts, UIView *v, double *dist, double *angle, CGPoint *centroid) {
    if (ts.count < 2) return NO;
    CGPoint a = [ts[0] locationInView:v.window], b = [ts[1] locationInView:v.window];
    *dist = hypot(b.x - a.x, b.y - a.y);
    *angle = atan2(b.y - a.y, b.x - a.x);
    *centroid = CGPointMake((a.x + b.x) / 2, (a.y + b.y) / 2);
    return YES;
}

/* ================= UIPinchGestureRecognizer ================= */
@implementation UIPinchGestureRecognizer {
    double _d0;                 /* finger distance at scale 1 */
    double _lastScale, _lastTime;
    BOOL _waitAllUp;
}
- (instancetype)initWithTarget:(id)t action:(SEL)a { if ((self = [super initWithTarget:t action:a])) _scale = 1; return self; }
- (BOOL)_isim_acceptsExtraTouches { return YES; }
- (void)setScale:(CGFloat)s {
    /* apps reset the scale (often to 1) after applying it: later changes are relative to now */
    double d, ang; CGPoint c;
    if (s > 0 && two_fingers(self.isimTouches, self.view, &d, &ang, &c)) _d0 = d / s;
    _scale = s; _lastScale = s;
}
- (CGPoint)locationInView:(UIView *)v { return [self.view.window convertPoint:self.lastPoint toView:v]; }
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    if (!self.isimTouches) self.isimTouches = [NSMutableArray array];
    NSMutableArray *ts = self.isimTouches;
    BOOL active = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged;
    double d, ang; CGPoint c;
    if (phase == UITouchPhaseBegan) {
        if (!ts.count) { _waitAllUp = NO; self.state = UIGestureRecognizerStatePossible; _scale = 1; _velocity = 0; }
        if (ts.count >= 2 || [ts containsObject:touch]) return;
        [ts addObject:touch];
        if (two_fingers(ts, self.view, &d, &ang, &c)) { _d0 = fmax(d, 1); _lastScale = 1; _lastTime = touch.timestamp; self.lastPoint = c; }
        else self.lastPoint = [touch locationInView:self.view.window];
        return;
    }
    if (![ts containsObject:touch]) return;
    if (phase == UITouchPhaseMoved) {
        if (_waitAllUp || !two_fingers(ts, self.view, &d, &ang, &c)) return;
        self.lastPoint = c;
        double s = d / _d0, dt = touch.timestamp - _lastTime;
        if (self.state == UIGestureRecognizerStatePossible) {
            if (fabs(d - _d0) < 4) return;                  /* hysteresis before a pinch begins */
            if (![self _isim_shouldBegin]) { self.state = UIGestureRecognizerStateFailed; _waitAllUp = YES; return; }
            _d0 = d / s;
            _scale = s; _velocity = 0; _lastScale = s; _lastTime = touch.timestamp;
            self.state = UIGestureRecognizerStateBegan; [self _fire];
            return;
        }
        if (!active) return;
        if (dt > 0.004) { _velocity = (s - _lastScale) / dt; _lastScale = s; _lastTime = touch.timestamp; }
        _scale = s;
        self.state = UIGestureRecognizerStateChanged; [self _fire];
        return;
    }
    [ts removeObjectIdenticalTo:touch];
    if (active && !_waitAllUp) {               /* a finger lifted: the pinch ends */
        self.state = phase == UITouchPhaseCancelled ? UIGestureRecognizerStateCancelled : UIGestureRecognizerStateEnded;
        [self _fire];
        self.state = UIGestureRecognizerStateFailed;
    }
    if (ts.count) _waitAllUp = YES;
    else { self.state = UIGestureRecognizerStatePossible; _waitAllUp = NO; }
}
@end

/* ================= UIRotationGestureRecognizer ================= */
@implementation UIRotationGestureRecognizer {
    double _a0;                 /* finger angle at rotation 0 (unwrapped) */
    double _lastAngle, _lastRotation, _lastTime;
    BOOL _waitAllUp;
}
- (BOOL)_isim_acceptsExtraTouches { return YES; }
- (void)setRotation:(CGFloat)r { _a0 = _lastAngle - r; _rotation = r; _lastRotation = r; }
- (CGPoint)locationInView:(UIView *)v { return [self.view.window convertPoint:self.lastPoint toView:v]; }
/* the finger angle, continuous across the -pi/pi seam */
- (double)_unwrap:(double)a { while (a - _lastAngle > M_PI) a -= 2 * M_PI; while (a - _lastAngle < -M_PI) a += 2 * M_PI; _lastAngle = a; return a; }
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    if (!self.isimTouches) self.isimTouches = [NSMutableArray array];
    NSMutableArray *ts = self.isimTouches;
    BOOL active = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged;
    double d, ang; CGPoint c;
    if (phase == UITouchPhaseBegan) {
        if (!ts.count) { _waitAllUp = NO; self.state = UIGestureRecognizerStatePossible; _rotation = 0; _velocity = 0; }
        if (ts.count >= 2 || [ts containsObject:touch]) return;
        [ts addObject:touch];
        if (two_fingers(ts, self.view, &d, &ang, &c)) { _lastAngle = ang; _a0 = ang; _lastRotation = 0; _lastTime = touch.timestamp; self.lastPoint = c; }
        else self.lastPoint = [touch locationInView:self.view.window];
        return;
    }
    if (![ts containsObject:touch]) return;
    if (phase == UITouchPhaseMoved) {
        if (_waitAllUp || !two_fingers(ts, self.view, &d, &ang, &c)) return;
        self.lastPoint = c;
        double a = [self _unwrap:ang], r = a - _a0, dt = touch.timestamp - _lastTime;
        if (self.state == UIGestureRecognizerStatePossible) {
            if (fabs(r) < 0.035) return;                     /* about 2 degrees before a rotation begins */
            if (![self _isim_shouldBegin]) { self.state = UIGestureRecognizerStateFailed; _waitAllUp = YES; return; }
            _rotation = r; _velocity = 0; _lastRotation = r; _lastTime = touch.timestamp;
            self.state = UIGestureRecognizerStateBegan; [self _fire];
            return;
        }
        if (!active) return;
        if (dt > 0.004) { _velocity = (r - _lastRotation) / dt; _lastRotation = r; _lastTime = touch.timestamp; }
        _rotation = r;
        self.state = UIGestureRecognizerStateChanged; [self _fire];
        return;
    }
    [ts removeObjectIdenticalTo:touch];
    if (active && !_waitAllUp) {
        self.state = phase == UITouchPhaseCancelled ? UIGestureRecognizerStateCancelled : UIGestureRecognizerStateEnded;
        [self _fire];
        self.state = UIGestureRecognizerStateFailed;
    }
    if (ts.count) _waitAllUp = YES;
    else { self.state = UIGestureRecognizerStatePossible; _waitAllUp = NO; }
}
@end
