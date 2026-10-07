/* Keyframe animations, view transitions and UIViewPropertyAnimator (on the animation engine in UIView.m).
 *
 *  - animateKeyframes / addKeyframe: each keyframe's changes become a segment of one keyframe timeline per
 *    property; the options' curve (default ease in-out) warps the whole timeline; .calculationModeDiscrete jumps.
 *  - transition(with:): flips and curls are drawn as a 2D squash to the axis and back (adapted: no 3D
 *    perspective), with the animations block applied at the midpoint; cross dissolve fades out, applies the
 *    changes and fades back in.
 *  - transition(from:to:): cross dissolve fades between the two views; flips squash one and stretch the other.
 *  - UIViewPropertyAnimator: animations are captured on an engine timeline, so they can be paused, scrubbed
 *    (fractionComplete), reversed, stopped and finished at the start, end or current position. Timing:
 *    built-in and custom cubic curves, springs (damping ratio, mass/stiffness/damping, duration/bounce). */
#import "UIKitPrivate.h"
#import <UIKit/UIViewPropertyAnimator.h>
#include <math.h>

/* CALayer, its presentation layers and Core Animation animations: CoreAnimation.m */

/* ================= keyframes ================= */
@implementation UIView (UIViewKeyframeAnimations)
+ (void)animateKeyframesWithDuration:(NSTimeInterval)d delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)o
                          animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    if (!isim_ui_animations_enabled()) { [UIView performWithoutAnimation:a]; if (c) dispatch_async(dispatch_get_main_queue(), ^{ c(YES); }); return; }
    isim_ui_animate_keyframes(d, delay, o, a, c);
}
+ (void)addKeyframeWithRelativeStartTime:(double)s relativeDuration:(double)d animations:(void (^)(void))a { isim_ui_add_keyframe(s, d, a); }

/* ================= transitions ================= */
static int transition_kind(UIViewAnimationOptions o) { return (int)((o >> 20) & 7); }   /* 1/2 flip left/right, 3/4 curl up/down, 5 dissolve, 6/7 flip top/bottom */
static CGAffineTransform squashed(CGAffineTransform base, int kind) {
    BOOL vertical = kind == 3 || kind == 4 || kind == 6 || kind == 7;
    return CGAffineTransformScale(base, vertical ? 1 : 0.02, vertical ? 0.02 : 1);
}
void isim_ui_transition_with_view(UIView *view, double d, UIViewAnimationOptions o, void (^animations)(void), void (^completion)(BOOL)) {
    int kind = transition_kind(o);
    if (!view || kind == 0 || d <= 0 || !isim_ui_animations_enabled()) { isim_ui_animate(d, 0, o, 0, 0, 0, animations, completion); return; }
    UIViewAnimationOptions half = o & ~(UIViewAnimationOptions)(7 << 20);
    if (kind == 5) {                                         /* cross dissolve: fade out, swap the content, fade in */
        CGFloat alpha = view.alpha;
        isim_ui_animate(d / 2, 0, (half & ~(3 << 16)) | UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ view.alpha = alpha * 0.15; }, ^(BOOL f) {
            [UIView performWithoutAnimation:^{ if (animations) animations(); }];
            isim_ui_animate(d / 2, 0, (half & ~(3 << 16)) | UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ view.alpha = alpha; }, completion);
        });
        return;
    }
    /* flips and curls: squash to the axis, apply the changes, unfold */
    CGAffineTransform base = view.transform;
    isim_ui_animate(d / 2, 0, (half & ~(3 << 16)) | UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ view.transform = squashed(base, kind); }, ^(BOOL f) {
        [UIView performWithoutAnimation:^{ if (animations) animations(); }];
        isim_ui_animate(d / 2, 0, (half & ~(3 << 16)) | UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ view.transform = base; }, completion);
    });
}
+ (void)transitionFromView:(UIView *)from toView:(UIView *)to duration:(NSTimeInterval)d options:(UIViewAnimationOptions)o completion:(void (^)(BOOL))c {
    BOOL showHide = (o & UIViewAnimationOptionShowHideTransitionViews) != 0;
    UIView *sup = from.superview;
    void (^show)(void) = ^{
        if (showHide) to.hidden = NO;
        else if (to.superview != sup && sup) [sup insertSubview:to aboveSubview:from];
    };
    void (^hideFrom)(void) = ^{ if (showHide) from.hidden = YES; else [from removeFromSuperview]; };
    int kind = transition_kind(o);
    UIViewAnimationOptions half = o & ~(UIViewAnimationOptions)(7 << 20) & ~(UIViewAnimationOptions)(3 << 16);
    if (kind == 0 || d <= 0 || !isim_ui_animations_enabled()) {
        [UIView performWithoutAnimation:^{ show(); hideFrom(); }];
        if (c) dispatch_async(dispatch_get_main_queue(), ^{ c(YES); });
        return;
    }
    if (kind == 5) {
        CGFloat toAlpha = to.alpha, fromAlpha = from.alpha;
        [UIView performWithoutAnimation:^{ show(); to.alpha = 0; }];
        isim_ui_animate(d, 0, half, 0, 0, 0, ^{ to.alpha = toAlpha; from.alpha = 0; }, ^(BOOL f) {
            [UIView performWithoutAnimation:^{ hideFrom(); from.alpha = fromAlpha; }];
            if (c) c(f);
        });
        return;
    }
    CGAffineTransform fromBase = from.transform, toBase = to.transform;
    isim_ui_animate(d / 2, 0, half | UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ from.transform = squashed(fromBase, kind); }, ^(BOOL f) {
        [UIView performWithoutAnimation:^{ show(); hideFrom(); from.transform = fromBase; to.transform = squashed(toBase, kind); }];
        isim_ui_animate(d / 2, 0, half | UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ to.transform = toBase; }, c);
    });
}
@end

/* ================= timing parameters ================= */
@implementation UICubicTimingParameters
- (instancetype)init { return [self initWithAnimationCurve:UIViewAnimationCurveEaseInOut]; }
- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)c {
    if ((self = [super init])) {
        _animationCurve = c;
        static const double pts[4][4] = { { 0.42, 0, 0.58, 1 }, { 0.42, 0, 1, 1 }, { 0, 0, 0.58, 1 }, { 0, 0, 1, 1 } };
        int i = c >= 0 && c <= 3 ? (int)c : 0;
        _controlPoint1 = CGPointMake(pts[i][0], pts[i][1]); _controlPoint2 = CGPointMake(pts[i][2], pts[i][3]);
    }
    return self;
}
- (instancetype)initWithControlPoint1:(CGPoint)p1 controlPoint2:(CGPoint)p2 {
    if ((self = [super init])) { _animationCurve = (UIViewAnimationCurve)-1; _controlPoint1 = p1; _controlPoint2 = p2; }
    return self;
}
- (UITimingCurveType)timingCurveType { return (NSInteger)_animationCurve < 0 ? UITimingCurveTypeCubic : UITimingCurveTypeBuiltin; }
- (UICubicTimingParameters *)cubicTimingParameters { return self; }
- (UISpringTimingParameters *)springTimingParameters { return nil; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
@end

@interface UISpringTimingParameters ()
@property (nonatomic) double _isim_damping, _isim_settle;       /* damping ratio; natural settling time (0 = the animator's duration) */
@end
@implementation UISpringTimingParameters
- (instancetype)init { return [self initWithDampingRatio:1]; }
- (instancetype)initWithDampingRatio:(CGFloat)r { return [self initWithDampingRatio:r initialVelocity:CGVectorMake(0, 0)]; }
- (instancetype)initWithDampingRatio:(CGFloat)r initialVelocity:(CGVector)v {
    if ((self = [super init])) { self._isim_damping = r; _initialVelocity = v; }
    return self;
}
- (instancetype)initWithMass:(CGFloat)m stiffness:(CGFloat)k damping:(CGFloat)c initialVelocity:(CGVector)v {
    if ((self = [super init])) {
        m = m > 0 ? m : 1; k = k > 0 ? k : 100;
        double w0 = sqrt(k / m), zeta = c / (2 * sqrt(k * m));
        self._isim_damping = zeta;
        self._isim_settle = zeta < 1 ? 6.9 / (fmax(zeta, 0.01) * w0) : 9.2 / w0;     /* until within ~0.1% (the engine's spring uses the same constants) */
        _initialVelocity = v;
    }
    return self;
}
- (instancetype)initWithDuration:(NSTimeInterval)d bounce:(CGFloat)b initialVelocity:(CGVector)v {
    if ((self = [super init])) { self._isim_damping = b >= 0 ? 1 - b : 1 / (1 + b); self._isim_settle = d * 1.6; _initialVelocity = v; }
    return self;
}
- (UITimingCurveType)timingCurveType { return UITimingCurveTypeSpring; }
- (UICubicTimingParameters *)cubicTimingParameters { return nil; }
- (UISpringTimingParameters *)springTimingParameters { return self; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
@end

/* ================= UIViewPropertyAnimator ================= */
static NSMutableSet *live_animators;               /* running animators stay alive, like UIKit's */

@implementation UIViewPropertyAnimator {
    id _tl;
    NSMutableArray *_pending, *_completions;
    int _curve; double _bz[4], _damping, _velocity, _effDuration, _speed;
    CGFloat _storedFraction;
    NSTimer *_watch;
}
- (instancetype)initWithDuration:(NSTimeInterval)d timingParameters:(id<UITimingCurveProvider>)p {
    if ((self = [super init])) {
        _duration = d; _timingParameters = p ?: [UICubicTimingParameters new];
        _pending = [NSMutableArray array]; _completions = [NSMutableArray array];
        _interruptible = YES; _userInteractionEnabled = YES; _scrubsLinearly = YES; _speed = 1;
        _effDuration = fmax(d, 1e-3);
        UISpringTimingParameters *sp = _timingParameters.springTimingParameters;
        UICubicTimingParameters *cu = _timingParameters.cubicTimingParameters;
        if (sp) {
            _curve = 4; _damping = sp._isim_damping;
            _velocity = sp.initialVelocity.dx != 0 ? sp.initialVelocity.dx : sp.initialVelocity.dy;
            if (sp._isim_settle > 0) _effDuration = sp._isim_settle;            /* UIKit ignores the duration for physical springs */
        } else if (cu && (NSInteger)cu.animationCurve >= 0) _curve = (int)cu.animationCurve;
        else if (cu) { _curve = 5; _bz[0] = cu.controlPoint1.x; _bz[1] = cu.controlPoint1.y; _bz[2] = cu.controlPoint2.x; _bz[3] = cu.controlPoint2.y; }
    }
    return self;
}
- (instancetype)init { return [self initWithDuration:0.3 timingParameters:[UICubicTimingParameters new]]; }
- (instancetype)initWithDuration:(NSTimeInterval)d curve:(UIViewAnimationCurve)c animations:(void (^)(void))a {
    if ((self = [self initWithDuration:d timingParameters:[[UICubicTimingParameters alloc] initWithAnimationCurve:c]]) && a) [_pending addObject:[a copy]];
    return self;
}
- (instancetype)initWithDuration:(NSTimeInterval)d controlPoint1:(CGPoint)p1 controlPoint2:(CGPoint)p2 animations:(void (^)(void))a {
    if ((self = [self initWithDuration:d timingParameters:[[UICubicTimingParameters alloc] initWithControlPoint1:p1 controlPoint2:p2]]) && a) [_pending addObject:[a copy]];
    return self;
}
- (instancetype)initWithDuration:(NSTimeInterval)d dampingRatio:(CGFloat)r animations:(void (^)(void))a {
    if ((self = [self initWithDuration:d timingParameters:[[UISpringTimingParameters alloc] initWithDampingRatio:r]]) && a) [_pending addObject:[a copy]];
    return self;
}
+ (instancetype)runningPropertyAnimatorWithDuration:(NSTimeInterval)d delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)o
                                          animations:(void (^)(void))a completion:(void (^)(UIViewAnimatingPosition))c {
    UIViewPropertyAnimator *p = [[self alloc] initWithDuration:d curve:(UIViewAnimationCurve)((o >> 16) & 3) animations:a];
    p->_delay = delay;
    if (c) [p addCompletion:c];
    [p startAnimation];
    return p;
}
- (id)copyWithZone:(NSZone *)z { return [[UIViewPropertyAnimator alloc] initWithDuration:_duration timingParameters:_timingParameters]; }
- (void)dealloc { [_watch invalidate]; }

/* ---- state ---- */
- (double)_isim_end { return _delay + _effDuration; }
- (void)_isim_activate {
    if (_state != UIViewAnimatingStateInactive) return;
    __weak UIViewPropertyAnimator *ws = self;
    _tl = isim_ui_timeline_create([self _isim_end], ^(int pos) { [ws _isim_reached:pos]; });
    isim_ui_timeline_set_autofinish(_tl, !_pausesOnCompletion);
    _state = UIViewAnimatingStateActive;
    if (!live_animators) live_animators = [NSMutableSet set];
    [live_animators addObject:self];
    NSArray *blocks = [_pending copy]; [_pending removeAllObjects];
    for (void (^b)(void) in blocks) isim_ui_timeline_capture(_tl, _effDuration, _delay, _curve, _bz, _damping, _velocity, b, nil);
    if (_storedFraction > 0) isim_ui_timeline_set(_tl, _delay + _storedFraction * _effDuration, YES, 1);
}
- (void)_isim_run {
    double v = isim_ui_timeline_time(_tl);
    isim_ui_timeline_set(_tl, v, NO, (_reversed ? -1 : 1) * _speed);
    _running = YES;
    if (_pausesOnCompletion && !_watch) {                       /* no automatic finish: pause at the end instead */
        __weak UIViewPropertyAnimator *ws = self;
        _watch = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *t) { [ws _isim_watch]; }];
        [NSRunLoop.mainRunLoop addTimer:_watch forMode:NSRunLoopCommonModes];
    }
}
- (void)_isim_watch {
    if (!_running || !_tl) return;
    double v = isim_ui_timeline_time(_tl);
    if ((!_reversed && v >= [self _isim_end]) || (_reversed && v <= 0)) {
        isim_ui_timeline_set(_tl, _reversed ? 0 : [self _isim_end], YES, 1);
        _running = NO;
    }
}
- (void)startAnimation {
    if (_state == UIViewAnimatingStateStopped) return;
    [self _isim_activate];
    [self _isim_run];
}
- (void)startAnimationAfterDelay:(NSTimeInterval)delay {
    [self _isim_activate];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (self->_state == UIViewAnimatingStateActive) [self _isim_run]; });
}
- (void)pauseAnimation {
    if (_state == UIViewAnimatingStateStopped) return;
    [self _isim_activate];
    isim_ui_timeline_set(_tl, isim_ui_timeline_time(_tl), YES, 1);
    _running = NO;
}
- (CGFloat)fractionComplete {
    if (_state == UIViewAnimatingStateInactive || !_tl) return _storedFraction;
    return (CGFloat)fmin(1, fmax(0, (isim_ui_timeline_time(_tl) - _delay) / _effDuration));
}
- (void)setFractionComplete:(CGFloat)f {
    f = fmin(1, fmax(0, f));
    if (_state == UIViewAnimatingStateStopped) return;
    if (_state == UIViewAnimatingStateInactive) { _storedFraction = f; [self _isim_activate]; _running = NO; return; }
    if (_running) return;                                          /* UIKit: only a paused animator scrubs */
    isim_ui_timeline_set(_tl, _delay + f * _effDuration, YES, 1);
}
- (void)setReversed:(BOOL)r {
    _reversed = r;
    if (_running && _tl) isim_ui_timeline_set(_tl, isim_ui_timeline_time(_tl), NO, (r ? -1 : 1) * _speed);
}
- (void)setPausesOnCompletion:(BOOL)p { _pausesOnCompletion = p; if (_tl) isim_ui_timeline_set_autofinish(_tl, !p); }
- (void)stopAnimation:(BOOL)withoutFinishing {
    if (_state != UIViewAnimatingStateActive) return;
    [_watch invalidate]; _watch = nil;
    isim_ui_timeline_finish(_tl, 2);                       /* the properties stay where they are now */
    _running = NO;
    if (withoutFinishing) { _state = UIViewAnimatingStateInactive; _tl = nil; [live_animators removeObject:self]; }
    else _state = UIViewAnimatingStateStopped;
}
- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)pos {
    if (_state == UIViewAnimatingStateActive && _pausesOnCompletion) {            /* a paused-at-completion animator */
        isim_ui_timeline_finish(_tl, pos == UIViewAnimatingPositionStart ? 1 : pos == UIViewAnimatingPositionEnd ? 0 : 2);
        [self _isim_done:pos];
        return;
    }
    if (_state != UIViewAnimatingStateStopped) return;
    if (pos != UIViewAnimatingPositionCurrent) isim_ui_timeline_settle(_tl, pos == UIViewAnimatingPositionStart ? 1 : 0);
    [self _isim_done:pos];
}
/* the timeline ran to its end (or back to its start when reversed) */
- (void)_isim_reached:(int)pos { [self _isim_done:pos == 1 ? UIViewAnimatingPositionStart : UIViewAnimatingPositionEnd]; }
- (void)_isim_done:(UIViewAnimatingPosition)pos {
    [_watch invalidate]; _watch = nil;
    _state = UIViewAnimatingStateInactive; _running = NO; _tl = nil; _storedFraction = 0;
    NSArray *cs = [_completions copy]; [_completions removeAllObjects];
    UIViewPropertyAnimator *keep = self;
    [live_animators removeObject:self];
    for (void (^c)(UIViewAnimatingPosition) in cs) c(pos);
    (void)keep;
}

/* ---- animations & completions ---- */
- (void)addAnimations:(void (^)(void))a { [self addAnimations:a delayFactor:0]; }
- (void)addAnimations:(void (^)(void))a delayFactor:(CGFloat)k {
    if (!a) return;
    if (_state == UIViewAnimatingStateInactive) { [_pending addObject:[a copy]]; return; }
    if (_state != UIViewAnimatingStateActive) return;
    double now = isim_ui_timeline_time(_tl), remaining = fmax(0.0001, [self _isim_end] - fmax(now, _delay));
    double startAt = fmax(now, _delay) + fmin(1, fmax(0, k)) * remaining;
    isim_ui_timeline_capture(_tl, [self _isim_end] - startAt, startAt - now, _curve, _bz, _damping, _velocity, a, nil);
}
- (void)addCompletion:(void (^)(UIViewAnimatingPosition))c { if (c) [_completions addObject:[c copy]]; }
- (void)continueAnimationWithTimingParameters:(id<UITimingCurveProvider>)p durationFactor:(CGFloat)f {
    if (_state != UIViewAnimatingStateActive) return;
    _speed = f > 0 ? 1 / f : 1;
    [self _isim_run];
}
@end
