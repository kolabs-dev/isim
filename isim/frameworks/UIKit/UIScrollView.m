/* UIScrollView: contentOffset is bounds.origin; one-finger pan with rubber-banding beyond the
 * edges, deceleration (UIKit's per-millisecond rate) and a spring back; scroll indicators while
 * moving. Auto Layout: constraints from descendants to the scroll view's edges describe the content
 * area (contentLayoutGuide), which sets contentSize. */
#import "UIKitPrivate.h"
#include <math.h>

const UIScrollViewDecelerationRate UIScrollViewDecelerationRateNormal = 0.998, UIScrollViewDecelerationRateFast = 0.99;

@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@end

@implementation UIScrollView {
    UIPanGestureRecognizer *_pan;
    CGPoint _dragStart;
    CGPoint _velocity;
    NSTimer *_anim;
    double _lastTick, _indicatorUntil;
    BOOL _userScrolled;
    UILayoutGuide *_contentGuide, *_frameGuide;
    BOOL _contentFromLayout;
    UIEdgeInsets _lastAdjusted;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.clipsToBounds = YES;
        _bounces = YES; _scrollEnabled = YES; _showsVerticalScrollIndicator = YES; _showsHorizontalScrollIndicator = YES;
        _decelerationRate = UIScrollViewDecelerationRateNormal; _scrollsToTop = YES;
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_pan:)];
        [self addGestureRecognizer:_pan];
    }
    return self;
}
- (UIPanGestureRecognizer *)panGestureRecognizer { return _pan; }

/* ---- geometry ---- */
- (CGPoint)contentOffset { return self.bounds.origin; }
- (void)setContentOffset:(CGPoint)o {
    _userScrolled = YES;                       /* an explicit position sticks (only an untouched view rests at the top) */
    [self _isim_applyOffset:o];
}
- (void)_isim_applyOffset:(CGPoint)o {
    CGRect b = self.bounds;
    if (CGPointEqualToPoint(o, b.origin)) return;
    b.origin = o;
    self.bounds = b;
    isim_ui_set_needs_display();
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimScrollViewDidScroll" object:self];    /* navigation bars follow their content */
    id<UIScrollViewDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(scrollViewDidScroll:)]) [d scrollViewDidScroll:self];
}
- (void)setContentOffset:(CGPoint)o animated:(BOOL)animated {
    [self _stopAnimation];
    if (!animated) { self.contentOffset = o; return; }
    CGPoint from = self.contentOffset; double start = isim_time();
    __weak UIScrollView *weakSelf = self;
    _anim = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *t) {
        UIScrollView *s = weakSelf;
        double k = fmin(1, (isim_time() - start) / 0.3); k = 1 - pow(1 - k, 3);
        s.contentOffset = CGPointMake(from.x + (o.x - from.x) * k, from.y + (o.y - from.y) * k);
        if (k >= 1) {
            [s _stopAnimation];
            id<UIScrollViewDelegate> d = s.delegate;
            if ([d respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) [d scrollViewDidEndScrollingAnimation:s];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:_anim forMode:NSRunLoopCommonModes];
}
- (void)setContentSize:(CGSize)s { if (CGSizeEqualToSize(s, _contentSize)) return; _contentSize = s; [self _clampIfIdle]; isim_ui_set_needs_display(); }
- (void)setContentInset:(UIEdgeInsets)i { _contentInset = i; [self setNeedsLayout]; }
- (UIEdgeInsets)adjustedContentInset {
    UIEdgeInsets a = _contentInset;
    BOOL adjust = _contentInsetAdjustmentBehavior == UIScrollViewContentInsetAdjustmentAlways ||
        _contentInsetAdjustmentBehavior == UIScrollViewContentInsetAdjustmentAutomatic ||
        (_contentInsetAdjustmentBehavior == UIScrollViewContentInsetAdjustmentScrollableAxes && _contentSize.height > self.bounds.size.height);
    if (adjust) {
        UIEdgeInsets s = self.safeAreaInsets;
        a.top += s.top; a.bottom += s.bottom; a.left += s.left; a.right += s.right;
    }
    return a;
}
- (UIEdgeInsets)safeAreaInsets {
    /* the safe area of a scroll view is measured on its frame (independent of scrolling) */
    UIView *sup = self.superview;
    if (!self.window || !sup) return UIEdgeInsetsZero;
    return isim_ui_safe_insets_for_rect(self, [sup convertRect:self.frame toView:nil]);
}
- (CGPoint)_minOffset { UIEdgeInsets a = self.adjustedContentInset; return CGPointMake(-a.left, -a.top); }
- (CGPoint)_maxOffset {
    UIEdgeInsets a = self.adjustedContentInset; CGSize b = self.bounds.size; CGPoint mn = [self _minOffset];
    return CGPointMake(MAX(mn.x, _contentSize.width + a.right - b.width), MAX(mn.y, _contentSize.height + a.bottom - b.height));
}
- (CGPoint)_clamped:(CGPoint)o {
    CGPoint mn = [self _minOffset], mx = [self _maxOffset];
    return CGPointMake(fmin(fmax(o.x, mn.x), mx.x), fmin(fmax(o.y, mn.y), mx.y));
}
- (BOOL)_canScrollX { return _alwaysBounceHorizontal || [self _maxOffset].x > [self _minOffset].x; }
- (BOOL)_canScrollY { return _alwaysBounceVertical || [self _maxOffset].y > [self _minOffset].y; }
- (void)_clampIfIdle {
    if (_dragging || _decelerating || _anim) return;
    if (!_userScrolled) { [self _isim_applyOffset:[self _minOffset]]; return; }     /* rest at the top until scrolled or positioned */
    CGPoint c = [self _clamped:self.contentOffset];
    if (!CGPointEqualToPoint(c, self.contentOffset)) self.contentOffset = c;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets a = self.adjustedContentInset;
    if (!UIEdgeInsetsEqualToEdgeInsets(a, _lastAdjusted)) {
        _lastAdjusted = a;
        id<UIScrollViewDelegate> d = _delegate;
        if ([d respondsToSelector:@selector(scrollViewDidChangeAdjustedContentInset:)]) [d scrollViewDidChangeAdjustedContentInset:self];
    }
    [self _clampIfIdle];
}
- (void)scrollRectToVisible:(CGRect)r animated:(BOOL)animated {
    CGPoint o = self.contentOffset; CGSize b = self.bounds.size; UIEdgeInsets a = self.adjustedContentInset;
    if (CGRectGetMaxY(r) > o.y + b.height - a.bottom) o.y = CGRectGetMaxY(r) - b.height + a.bottom;
    if (r.origin.y < o.y + a.top) o.y = r.origin.y - a.top;
    if (CGRectGetMaxX(r) > o.x + b.width - a.right) o.x = CGRectGetMaxX(r) - b.width + a.right;
    if (r.origin.x < o.x + a.left) o.x = r.origin.x - a.left;
    _userScrolled = YES;
    [self setContentOffset:[self _clamped:o] animated:animated];
}
- (void)flashScrollIndicators { _indicatorUntil = isim_time() + 0.6; isim_ui_set_needs_display(); }

/* ---- dragging ---- */
static double rubber(double overshoot, double dim) { double c = 0.55; return (1 - 1 / (fabs(overshoot) * c / fmax(dim, 1) + 1)) * dim * (overshoot < 0 ? -1 : 1); }
- (CGPoint)_rubberBanded:(CGPoint)o {
    CGPoint mn = [self _minOffset], mx = [self _maxOffset]; CGSize b = self.bounds.size;
    if (!_bounces) return [self _clamped:o];
    if (o.x < mn.x) o.x = mn.x + rubber(o.x - mn.x, b.width); else if (o.x > mx.x) o.x = mx.x + rubber(o.x - mx.x, b.width);
    if (o.y < mn.y) o.y = mn.y + rubber(o.y - mn.y, b.height); else if (o.y > mx.y) o.y = mx.y + rubber(o.y - mx.y, b.height);
    return o;
}
- (void)_isim_pan:(UIPanGestureRecognizer *)g {
    if (!_scrollEnabled) return;
    id<UIScrollViewDelegate> d = _delegate;
    switch (g.state) {
    case UIGestureRecognizerStateBegan:
        [self _stopAnimation];
        _dragging = _tracking = YES; _userScrolled = YES;
        _dragStart = self.contentOffset;
        if (_keyboardDismissMode != UIScrollViewKeyboardDismissModeNone) [isim_ui_first_responder() resignFirstResponder];
        if ([d respondsToSelector:@selector(scrollViewWillBeginDragging:)]) [d scrollViewWillBeginDragging:self];
        /* fall through */
    case UIGestureRecognizerStateChanged: {
        CGPoint t = [g translationInView:self];
        CGPoint o = CGPointMake(_dragStart.x - ([self _canScrollX] ? t.x : 0), _dragStart.y - ([self _canScrollY] ? t.y : 0));
        self.contentOffset = [self _rubberBanded:o];
        _indicatorUntil = isim_time() + 0.5;
        break; }
    case UIGestureRecognizerStateEnded: case UIGestureRecognizerStateCancelled: {
        _dragging = _tracking = NO;
        CGPoint v = [g velocityInView:self];
        _velocity = CGPointMake([self _canScrollX] ? -v.x : 0, [self _canScrollY] ? -v.y : 0);
        /* where deceleration would stop: v / (-1000 ln rate) past the current offset */
        CGPoint o = self.contentOffset; double kk = -1000 * log(_decelerationRate);
        CGPoint natural = [self _clamped:CGPointMake(o.x + _velocity.x / kk, o.y + _velocity.y / kk)], target = natural;
        if (_pagingEnabled) {
            CGSize page = self.bounds.size;
            for (int axis = 0; axis < 2; axis++) {
                double len = axis ? page.height : page.width; if (len <= 0) continue;
                double start = axis ? _dragStart.y : _dragStart.x, cur = axis ? o.y : o.x, vel = axis ? _velocity.y : _velocity.x;
                double base = round(start / len), idx = round(cur / len);
                if (fabs(vel) > 300) idx = base + (vel > 0 ? 1 : -1);
                idx = fmax(base - 1, fmin(base + 1, idx));
                if (axis) target.y = idx * len; else target.x = idx * len;
            }
            target = [self _clamped:target];
        }
        CGPoint proposed = target;
        if ([d respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)])
            [d scrollViewWillEndDragging:self withVelocity:CGPointMake(_velocity.x / 1000, _velocity.y / 1000) targetContentOffset:&target];   /* points per millisecond */
        BOOL snap = _pagingEnabled || !CGPointEqualToPoint(proposed, target) || !CGPointEqualToPoint(target, natural);
        BOOL decel = snap ? !CGPointEqualToPoint(target, o) : (hypot(_velocity.x, _velocity.y) > 30 || !CGPointEqualToPoint([self _clamped:o], o));
        if ([d respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) [d scrollViewDidEndDragging:self willDecelerate:decel];
        if (snap && decel) [self _snapTo:target];
        else if (decel) [self _startDeceleration];
        break; }
    default: break;
    }
}
- (void)_startDeceleration {
    _decelerating = YES;
    id<UIScrollViewDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) [d scrollViewWillBeginDecelerating:self];
    _lastTick = isim_time();
    __weak UIScrollView *weakSelf = self;
    _anim = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *t) { [weakSelf _decelStep]; }];
    [NSRunLoop.mainRunLoop addTimer:_anim forMode:NSRunLoopCommonModes];
}
- (void)_decelStep {
    double now = isim_time(), dt = fmin(now - _lastTick, 0.05); _lastTick = now;
    CGPoint o = self.contentOffset, c = [self _clamped:o];
    double decay = pow(_decelerationRate, dt * 1000);
    for (int axis = 0; axis < 2; axis++) {
        double *v = axis ? &_velocity.y : &_velocity.x, *p = axis ? &o.y : &o.x, lim = axis ? c.y : c.x;
        if (*p != lim) {                                   /* outside: spring back (critically damped) */
            double k = 1 - exp(-dt * 12);
            *v = 0; *p += (lim - *p) * k;
            if (fabs(*p - lim) < 0.5) *p = lim;
        } else {
            *p += *v * dt; *v *= decay;
            CGPoint cc = [self _clamped:o];
            double clim = axis ? cc.y : cc.x;
            if (*p != clim && !_bounces) { *p = clim; *v = 0; }
        }
    }
    self.contentOffset = o;
    _indicatorUntil = now + 0.5;
    CGPoint nc = [self _clamped:o];
    if (hypot(_velocity.x, _velocity.y) < 8 && CGPointEqualToPoint(nc, o)) {
        [self _stopAnimation];
        _decelerating = NO;
        id<UIScrollViewDelegate> d = _delegate;
        if ([d respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) [d scrollViewDidEndDecelerating:self];
    }
}
/* paging / adjusted targets: a short ease-out glide to the target, reported as deceleration */
- (void)_snapTo:(CGPoint)target {
    _decelerating = YES;
    id<UIScrollViewDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) [d scrollViewWillBeginDecelerating:self];
    CGPoint from = self.contentOffset; double start = isim_time(), dur = 0.35;
    __weak UIScrollView *weakSelf = self;
    _anim = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *t) {
        UIScrollView *s = weakSelf; if (!s) return;
        double k = fmin(1, (isim_time() - start) / dur); k = 1 - pow(1 - k, 3);
        [s _isim_applyOffset:CGPointMake(from.x + (target.x - from.x) * k, from.y + (target.y - from.y) * k)];
        s->_indicatorUntil = isim_time() + 0.5;
        if (k >= 1) {
            [s _stopAnimation]; s->_decelerating = NO;
            id<UIScrollViewDelegate> dd = s.delegate;
            if ([dd respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) [dd scrollViewDidEndDecelerating:s];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:_anim forMode:NSRunLoopCommonModes];
}
- (void)_stopAnimation { [_anim invalidate]; _anim = nil; }
- (void)dealloc { [_anim invalidate]; }

/* ---- indicators ---- */
- (void)_isim_drawOverlay {
    if (isim_time() > _indicatorUntil) return;
    CGSize b = self.bounds.size; CGPoint o = self.contentOffset; UIEdgeInsets a = self.adjustedContentInset;
    double col[4] = { 0, 0, 0, 0.35 };
    if (isim_ui_style() == UIUserInterfaceStyleDark) col[0] = col[1] = col[2] = 1;
    double contentH = _contentSize.height + a.top + a.bottom, viewH = b.height;
    if (_showsVerticalScrollIndicator && contentH > viewH + 0.5) {
        double track = viewH - a.top - a.bottom - 6, len = fmax(36, track * viewH / contentH);
        double pos = (o.y + a.top) / (contentH - viewH); pos = fmin(fmax(pos, 0), 1);
        isim_gfx_fill_rounded(o.x + b.width - 6, o.y + a.top + 3 + (track - len) * pos, 3, len, 1.5, col);
    }
    double contentW = _contentSize.width + a.left + a.right;
    if (_showsHorizontalScrollIndicator && contentW > b.width + 0.5) {
        double track = b.width - 6, len = fmax(36, track * b.width / contentW);
        double pos = (o.x + a.left) / (contentW - b.width); pos = fmin(fmax(pos, 0), 1);
        isim_gfx_fill_rounded(o.x + 3 + (track - len) * pos, o.y + b.height - a.bottom - 6, len, 3, 1.5, col);
    }
    dispatch_async(dispatch_get_main_queue(), ^{ isim_ui_set_needs_display(); });   /* keep redrawing until it fades */
}

/* ---- Auto Layout ---- */
- (UILayoutGuide *)contentLayoutGuide {
    if (!_contentGuide) { _contentGuide = [UILayoutGuide new]; _contentGuide.identifier = @"UIScrollView-contentLayoutGuide"; [self addLayoutGuide:_contentGuide]; }
    _contentFromLayout = YES;          /* whoever asks for the content guide sizes the content with it */
    return _contentGuide;
}
- (UILayoutGuide *)frameLayoutGuide {
    if (!_frameGuide) {
        _frameGuide = [UILayoutGuide new]; _frameGuide.owningView = self; _frameGuide.identifier = @"UIScrollView-frameLayoutGuide";
        __weak UIScrollView *w = self;
        [_frameGuide _isim_setFrameProvider:^CGRect { return w.bounds; }];
        [self addLayoutGuide:_frameGuide];
    }
    return _frameGuide;
}
- (void)_isim_addEngineConstraints:(isim_al *)al {
    if (!_contentGuide) return;
    /* the content area starts at the scroll view's origin; its size comes from the content's constraints */
    isim_al_add(al, _contentGuide, NSLayoutAttributeLeft, NSLayoutRelationEqual, self, NSLayoutAttributeLeft, 1, 0, 1001);
    isim_al_add(al, _contentGuide, NSLayoutAttributeTop, NSLayoutRelationEqual, self, NSLayoutAttributeTop, 1, 0, 1001);
    isim_al_add(al, _contentGuide, NSLayoutAttributeWidth, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, 1, _contentSize.width, 0.01);
    isim_al_add(al, _contentGuide, NSLayoutAttributeHeight, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, 1, _contentSize.height, 0.01);
}
- (void)_isim_didSolve {
    if (!_contentGuide || !_contentFromLayout) return;
    CGRect f = _contentGuide.layoutFrame;
    self.contentSize = CGSizeMake(MAX(0, f.size.width), MAX(0, f.size.height));
}
- (void)_isim_markContentFromLayout { _contentFromLayout = YES; }
@end
