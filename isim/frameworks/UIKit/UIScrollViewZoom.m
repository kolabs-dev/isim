/* UIScrollView zooming: a pinch (two fingers: host Option-drag, script `pinch`) scales the delegate's
 * viewForZoomingInScrollView: between minimumZoomScale and maximumZoomScale (rubber-banding past them, then
 * springing back), keeping the content under the fingers in place; zoomScale / setZoomScale:animated: /
 * zoomToRect:animated: as in UIKit. The zoomed view gets a scale transform and sits at the content origin; the
 * content size is its scaled size. */
#import "UIKitInputPrivate.h"
#import <objc/runtime.h>
#include <math.h>

@interface __IsimZoomState : NSObject
@property (nonatomic) CGFloat minimum, maximum, scale, startScale;
@property (nonatomic) BOOL bouncesZoom, zooming, zoomBouncing;
@property (nonatomic) CGPoint anchor;                 /* content point (unscaled zoom-view coordinates) under the pinch */
@property (nonatomic, strong) UIPinchGestureRecognizer *pinch;
@property (nonatomic, strong) NSTimer *anim;
@end
@implementation __IsimZoomState @end

static char k_zoom;
@implementation UIScrollView (UIZooming)
- (__IsimZoomState *)_isim_zoom {
    __IsimZoomState *z = objc_getAssociatedObject(self, &k_zoom);
    if (!z) { z = [__IsimZoomState new]; z.minimum = z.maximum = z.scale = 1; z.bouncesZoom = YES; objc_setAssociatedObject(self, &k_zoom, z, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return z;
}
- (CGFloat)minimumZoomScale { return [self _isim_zoom].minimum; }
- (CGFloat)maximumZoomScale { return [self _isim_zoom].maximum; }
- (void)setMinimumZoomScale:(CGFloat)s { [self _isim_zoom].minimum = s; [self _isim_updatePinch]; }
- (void)setMaximumZoomScale:(CGFloat)s { [self _isim_zoom].maximum = s; [self _isim_updatePinch]; }
- (BOOL)bouncesZoom { return [self _isim_zoom].bouncesZoom; }
- (void)setBouncesZoom:(BOOL)b { [self _isim_zoom].bouncesZoom = b; }
- (BOOL)isZooming { return [self _isim_zoom].zooming; }
- (BOOL)isZoomBouncing { return [self _isim_zoom].zoomBouncing; }
- (CGFloat)zoomScale { return [self _isim_zoom].scale; }
- (UIPinchGestureRecognizer *)pinchGestureRecognizer { return [self _isim_zoom].pinch; }
/* the pinch recognizer exists while zooming is possible (minimum != maximum) */
- (void)_isim_updatePinch {
    __IsimZoomState *z = [self _isim_zoom];
    BOOL want = fabs(z.maximum - z.minimum) > 1e-6;
    if (want && !z.pinch) {
        z.pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_zoomPinch:)];
        [self addGestureRecognizer:z.pinch];
    } else if (!want && z.pinch) { [self removeGestureRecognizer:z.pinch]; z.pinch = nil; }
}
- (UIView *)_isim_zoomView {
    id<UIScrollViewDelegate> d = self.delegate;
    return [d respondsToSelector:@selector(viewForZoomingInScrollView:)] ? [d viewForZoomingInScrollView:self] : nil;
}
/* scale the zoom view about the content origin and size the content to it */
- (void)_isim_applyZoom:(CGFloat)s {
    UIView *v = [self _isim_zoomView];
    __IsimZoomState *z = [self _isim_zoom];
    z.scale = s;
    if (v) {
        CGSize b = v.bounds.size;
        v.transform = CGAffineTransformMakeScale(s, s);
        v.center = CGPointMake(b.width * s / 2, b.height * s / 2);
        self.contentSize = CGSizeMake(b.width * s, b.height * s);
    }
    id<UIScrollViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(scrollViewDidZoom:)]) [d scrollViewDidZoom:self];
    isim_ui_set_needs_display();
}
- (CGPoint)_isim_clampOffset:(CGPoint)o {
    UIEdgeInsets a = self.adjustedContentInset; CGSize b = self.bounds.size, c = self.contentSize;
    CGFloat maxX = MAX(-a.left, c.width + a.right - b.width), maxY = MAX(-a.top, c.height + a.bottom - b.height);
    return CGPointMake(fmin(fmax(o.x, -a.left), maxX), fmin(fmax(o.y, -a.top), maxY));
}
- (void)setZoomScale:(CGFloat)s { [self setZoomScale:s animated:NO]; }
- (void)setZoomScale:(CGFloat)s animated:(BOOL)animated {
    __IsimZoomState *z = [self _isim_zoom];
    s = fmin(fmax(s, z.minimum), z.maximum);
    /* keep the visible centre fixed */
    CGSize b = self.bounds.size; CGPoint o = self.contentOffset;
    CGPoint centre = CGPointMake((o.x + b.width / 2) / z.scale, (o.y + b.height / 2) / z.scale);
    CGRect target = CGRectMake(centre.x - b.width / s / 2, centre.y - b.height / s / 2, b.width / s, b.height / s);
    [self _isim_zoomTo:s rectOrigin:target.origin animated:animated];
}
- (void)zoomToRect:(CGRect)r animated:(BOOL)animated {
    __IsimZoomState *z = [self _isim_zoom];
    CGSize b = self.bounds.size;
    if (r.size.width <= 0 || r.size.height <= 0) return;
    CGFloat s = fmin(fmax(fmin(b.width / r.size.width, b.height / r.size.height), z.minimum), z.maximum);
    /* centre the rect */
    CGPoint origin = CGPointMake(CGRectGetMidX(r) - b.width / s / 2, CGRectGetMidY(r) - b.height / s / 2);
    [self _isim_zoomTo:s rectOrigin:origin animated:animated];
}
/* zoom to scale s with the unscaled content point `origin` at the top-left of the visible area */
- (void)_isim_zoomTo:(CGFloat)s rectOrigin:(CGPoint)origin animated:(BOOL)animated {
    __IsimZoomState *z = [self _isim_zoom];
    [z.anim invalidate]; z.anim = nil;
    UIView *v = [self _isim_zoomView];
    id<UIScrollViewDelegate> d = self.delegate;
    if (!animated) {
        [self _isim_applyZoom:s];
        self.contentOffset = [self _isim_clampOffset:CGPointMake(origin.x * s, origin.y * s)];
        return;
    }
    CGFloat s0 = z.scale; CGPoint o0 = self.contentOffset;
    CGPoint o1 = CGPointMake(origin.x * s, origin.y * s);
    double start = isim_time();
    __weak UIScrollView *ws = self;
    z.zoomBouncing = NO;
    z.anim = [NSTimer timerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *t) {
        UIScrollView *sv = ws; if (!sv) { [t invalidate]; return; }
        double k = fmin(1, (isim_time() - start) / 0.3), e = 1 - pow(1 - k, 3);
        CGFloat sc = s0 + (s - s0) * e;
        [sv _isim_applyZoom:sc];
        CGPoint end = [sv _isim_clampOffset:o1];
        sv.contentOffset = CGPointMake(o0.x + (end.x - o0.x) * e, o0.y + (end.y - o0.y) * e);
        if (k >= 1) {
            [t invalidate]; [sv _isim_zoom].anim = nil;
            if ([d respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) [d scrollViewDidEndZooming:sv withView:v atScale:s];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:z.anim forMode:NSRunLoopCommonModes];
}
- (void)_isim_zoomPinch:(UIPinchGestureRecognizer *)g {
    __IsimZoomState *z = [self _isim_zoom];
    UIView *v = [self _isim_zoomView];
    if (!v) return;
    id<UIScrollViewDelegate> d = self.delegate;
    CGPoint loc = [g locationInView:self];                  /* content coordinates */
    CGPoint vis = CGPointMake(loc.x - self.contentOffset.x, loc.y - self.contentOffset.y);
    switch (g.state) {
    case UIGestureRecognizerStateBegan:
        [z.anim invalidate]; z.anim = nil;
        z.zooming = YES; z.startScale = z.scale;
        z.anchor = CGPointMake(loc.x / z.scale, loc.y / z.scale);
        if ([d respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)]) [d scrollViewWillBeginZooming:self withView:v];
        /* fall through */
    case UIGestureRecognizerStateChanged: {
        CGFloat s = z.startScale * g.scale;
        if (s > z.maximum) s = z.bouncesZoom ? z.maximum * pow(s / z.maximum, 0.3) : z.maximum;     /* rubber band */
        if (s < z.minimum) s = z.bouncesZoom ? z.minimum * pow(s / z.minimum, 0.3) : z.minimum;
        [self _isim_applyZoom:s];
        /* the content point that began under the fingers stays under them */
        CGPoint o = CGPointMake(z.anchor.x * s - vis.x, z.anchor.y * s - vis.y);
        CGRect b = self.bounds; b.origin = o; self.bounds = b;
        if ([d respondsToSelector:@selector(scrollViewDidScroll:)]) [d scrollViewDidScroll:self];
        break; }
    case UIGestureRecognizerStateEnded: case UIGestureRecognizerStateCancelled: {
        z.zooming = NO;
        CGFloat s = z.scale, target = fmin(fmax(s, z.minimum), z.maximum);
        CGSize bs = self.bounds.size;
        if (fabs(target - s) > 1e-4) {
            z.zoomBouncing = YES;
            /* spring back around the pinch point */
            CGPoint origin = CGPointMake(z.anchor.x - vis.x / target, z.anchor.y - vis.y / target);
            (void)bs;
            [self _isim_zoomTo:target rectOrigin:origin animated:YES];
        } else {
            CGPoint c = [self _isim_clampOffset:self.contentOffset];
            if (!CGPointEqualToPoint(c, self.contentOffset)) [self setContentOffset:c animated:YES];
            if ([d respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) [d scrollViewDidEndZooming:self withView:v atScale:s];
        }
        break; }
    default: break;
    }
}
@end
