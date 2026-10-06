/* UIRefreshControl: pull to refresh. Assigned to scrollView.refreshControl it sits above the content; pulling
 * the content down reveals a spinner whose ticks fill in as you pull. Pulling past the threshold while
 * dragging starts refreshing (.valueChanged); on release the scroll view rests with the spinner visible
 * (contentInset.top grows by 60) until endRefreshing(), which animates the content back up. */
#import "UIKitPrivate.h"
#import <UIKit/UIRefreshControl.h>
#include <math.h>

#define RC_HEIGHT 60.0
#define RC_THRESHOLD 80.0

@implementation UIRefreshControl {
    __weak UIScrollView *_scroll;
    BOOL _insetApplied;
    CGFloat _pull;
    CADisplayLink *_spin;
    UIColor *_ownTint;
}
- (instancetype)init { return [self initWithFrame:CGRectMake(0, 0, 320, RC_HEIGHT)]; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.userInteractionEnabled = NO;
        self.accessibilityIdentifier = @"refresh-control";
    }
    return self;
}
- (void)dealloc { [_spin invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)setTintColor:(UIColor *)c { _ownTint = c; [super setTintColor:c]; }
- (NSString *)_isim_dumpText { return _refreshing ? @"refreshing" : [NSString stringWithFormat:@"idle, pulled %g", _pull]; }

/* attached to / detached from a scroll view */
- (void)_isim_attach:(UIScrollView *)sv {
    if (_scroll) { [NSNotificationCenter.defaultCenter removeObserver:self]; [_scroll.panGestureRecognizer removeTarget:self action:@selector(_isim_rcPan:)]; }
    _scroll = sv;
    if (!sv) return;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isim_rcScrolled:) name:@"_IsimScrollViewDidScroll" object:sv];
    [sv.panGestureRecognizer addTarget:self action:@selector(_isim_rcPan:)];
    [self _isim_rcUpdate];
}
- (CGFloat)_isim_baseTop { return _scroll.adjustedContentInset.top - (_insetApplied ? RC_HEIGHT : 0); }
- (void)_isim_rcScrolled:(NSNotification *)n { [self _isim_rcUpdate]; }
- (void)_isim_rcPan:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) [self _isim_applyInsetIfNeeded];
}
- (void)_isim_rcUpdate {
    UIScrollView *sv = _scroll;
    if (!sv) return;
    CGFloat pull = fmax(0, -(sv.contentOffset.y + [self _isim_baseTop]));
    _pull = pull;
    CGFloat W = sv.bounds.size.width;
    [UIView performWithoutAnimation:^{ self.frame = CGRectMake(0, -pull, W, pull); }];
    self.hidden = pull < 1 && !_refreshing;
    if (sv.isDragging && !_refreshing && pull >= RC_THRESHOLD) {
        _refreshing = YES;
        [self _isim_startSpinning];
        NSLog(@"isim: refresh control began refreshing");
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    if (!sv.isDragging) [self _isim_applyInsetIfNeeded];
    isim_ui_set_needs_display();
}
- (void)_isim_applyInsetIfNeeded {
    UIScrollView *sv = _scroll;
    if (!_refreshing || _insetApplied || !sv || sv.isDragging) return;
    _insetApplied = YES;
    UIEdgeInsets i = sv.contentInset; i.top += RC_HEIGHT; sv.contentInset = i;
}
- (void)beginRefreshing {
    if (_refreshing) return;
    _refreshing = YES;
    [self _isim_startSpinning];
    [self _isim_applyInsetIfNeeded];
    [self _isim_rcUpdate];
}
- (void)endRefreshing {
    if (!_refreshing) return;
    _refreshing = NO;
    [_spin invalidate]; _spin = nil;
    UIScrollView *sv = _scroll;
    NSLog(@"isim: refresh control ended refreshing");
    if (!_insetApplied || !sv) { [self _isim_rcUpdate]; return; }
    _insetApplied = NO;
    UIEdgeInsets i = sv.contentInset;
    CGFloat newTop = sv.adjustedContentInset.top - RC_HEIGHT;
    if (sv.contentOffset.y < -newTop) [sv setContentOffset:CGPointMake(sv.contentOffset.x, -newTop) animated:YES];   /* slide the content back up */
    i.top -= RC_HEIGHT; sv.contentInset = i;
    [self _isim_rcUpdate];
}
- (void)_isim_startSpinning {
    if (_spin) return;
    _spin = [CADisplayLink displayLinkWithTarget:self selector:@selector(_isim_spinTick:)];
    [_spin addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)_isim_spinTick:(CADisplayLink *)l { if (self.window && !self.hidden) isim_ui_set_needs_display(); }

/* the spinner: 8 ticks that appear one by one while pulling, then rotate while refreshing */
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    if (s.height < 1) return;
    double cx = s.width / 2, cy = fmin(s.height, RC_HEIGHT) / 2, r0 = 5.5, r1 = 10.5;
    int ticks = 8, shown = _refreshing ? ticks : (int)fmin(ticks, floor(_pull / RC_THRESHOLD * ticks));
    double col[4]; isim_ui_rgba(_ownTint ?: UIColor.secondaryLabelColor, col);
    double phase = _refreshing ? fmod(isim_time() * 1.25, 1.0) : 0;
    int head = (int)(phase * ticks);
    for (int i = 0; i < shown; i++) {
        double a = -M_PI / 2 + i * 2 * M_PI / ticks;
        double c[4] = { col[0], col[1], col[2], col[3] };
        if (_refreshing) c[3] *= 0.25 + 0.75 * (double)((i - head + ticks) % ticks) / (ticks - 1);
        isim_path_begin();
        isim_path_move(cx + r0 * cos(a), cy + r0 * sin(a));
        isim_path_line(cx + r1 * cos(a), cy + r1 * sin(a));
        isim_path_stroke(2.6, c);
    }
}
@end

static char kRefreshControl;
@implementation UIScrollView (UIRefreshControl)
- (UIRefreshControl *)refreshControl { return objc_getAssociatedObject(self, &kRefreshControl); }
- (void)setRefreshControl:(UIRefreshControl *)rc {
    UIRefreshControl *old = self.refreshControl;
    if (old == rc) return;
    [old _isim_attach:nil]; [old removeFromSuperview];
    objc_setAssociatedObject(self, &kRefreshControl, rc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (rc) { [self insertSubview:rc atIndex:0]; [rc _isim_attach:self]; }
}
@end
@implementation UITableViewController (UIRefreshControl)
- (UIRefreshControl *)refreshControl { return self.tableView.refreshControl; }
- (void)setRefreshControl:(UIRefreshControl *)rc { self.tableView.refreshControl = rc; }
@end
