/* UISplitViewController and UIPageViewController.
 *
 * UISplitViewController: in compact width (every iPhone) it is collapsed into one UINavigationController: the
 * primary column's stack, then (up to the delegate's top column, default .secondary; classic API: unless
 * collapseSecondaryViewController returns true) the supplementary and secondary columns' controllers pushed on
 * it. A .compact column replaces all of that. showDetailViewController pushes in place of the secondary. In
 * regular width the columns sit side by side (primary 320 pt or the preferred width/fraction).
 *
 * UIPageViewController: a paging scroll view holding the current page and its neighbours from the data source;
 * swiping (or setViewControllers(_:direction:animated:)) moves between them; the delegate hears
 * willTransitionTo / didFinishAnimating; presentationCount/Index show page dots. Page curl is shown as scroll
 * (adapted). */
#import "UIKitPrivate.h"
#import <UIKit/UISplitViewController.h>
#include <math.h>

/* ================= UISplitViewController ================= */
@implementation UISplitViewController {
    UIViewController *_cols[4];               /* primary, supplementary, secondary, compact (as given) */
    UINavigationController *_nav[3];          /* column navigation controllers (wrapping plain controllers) */
    UINavigationController *_compactNav;
    UIView *_separator;
    BOOL _built, _secondaryCollapsedAway;
    UIBarButtonItem *_modeItem;
}
- (instancetype)initWithStyle:(UISplitViewControllerStyle)style {
    if ((self = [super initWithNibName:nil bundle:nil])) { _style = style; _presentsWithGesture = YES; _showsSecondaryOnlyButton = NO; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithStyle:UISplitViewControllerStyleUnspecified]; }
- (BOOL)isCollapsed { return compact(self); }
static BOOL compact(UISplitViewController *s) { UIWindow *w = s.viewIfLoaded.window; return (w ? w.bounds.size.width : isim_ui_device()->width) < 700; }
- (UISplitViewControllerDisplayMode)displayMode {
    if (compact(self)) return UISplitViewControllerDisplayModeSecondaryOnly;
    return _cols[1] ? UISplitViewControllerDisplayModeTwoBesideSecondary : UISplitViewControllerDisplayModeOneBesideSecondary;
}
- (CGFloat)primaryColumnWidth {
    CGFloat W = self.viewIfLoaded.bounds.size.width ?: isim_ui_device()->width;
    CGFloat w = _preferredPrimaryColumnWidth > 0 ? _preferredPrimaryColumnWidth : _preferredPrimaryColumnWidthFraction > 0 ? W * _preferredPrimaryColumnWidthFraction : 320;
    if (_minimumPrimaryColumnWidth > 0) w = fmax(w, _minimumPrimaryColumnWidth);
    if (_maximumPrimaryColumnWidth > 0) w = fmin(w, _maximumPrimaryColumnWidth);
    return fmin(w, W / 2);
}
- (UIBarButtonItem *)displayModeButtonItem {
    if (!_modeItem) _modeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"sidebar.left"] style:UIBarButtonItemStylePlain target:nil action:NULL];
    return _modeItem;
}

/* ---- columns ---- */
static NSInteger col_index(UISplitViewControllerColumn c) { return c == UISplitViewControllerColumnPrimary ? 0 : c == UISplitViewControllerColumnSupplementary ? 1 : c == UISplitViewControllerColumnSecondary ? 2 : 3; }
- (void)setViewController:(UIViewController *)vc forColumn:(UISplitViewControllerColumn)column {
    NSInteger i = col_index(column);
    _cols[i] = vc;
    if (i < 3) _nav[i] = nil;
    [self _isim_rebuild];
}
- (UIViewController *)viewControllerForColumn:(UISplitViewControllerColumn)column {
    NSInteger i = col_index(column);
    if (i == 3) return _cols[3];
    return _nav[i] ?: _cols[i];
}
- (NSArray *)viewControllers {
    NSMutableArray *a = [NSMutableArray array];
    for (int i = 0; i < 3; i++) if (_cols[i]) [a addObject:_nav[i] ?: _cols[i]];
    return a;
}
- (void)setViewControllers:(NSArray *)vcs {                  /* classic API: [primary, secondary] */
    _cols[0] = vcs.count > 0 ? vcs[0] : nil;
    _cols[2] = vcs.count > 1 ? vcs[1] : nil;
    _nav[0] = _nav[2] = nil;
    [self _isim_rebuild];
}
/* a column's navigation controller; a wrapper starts empty and gets its root once adopted (so the root's
   viewDidLoad already sees the split view controller) */
- (UINavigationController *)_isim_navFor:(NSInteger)i {
    if (!_cols[i]) return nil;
    if ([_cols[i] isKindOfClass:[UINavigationController class]]) return (UINavigationController *)_cols[i];
    if (!_nav[i]) _nav[i] = [[UINavigationController alloc] initWithNibName:nil bundle:nil];
    return _nav[i];
}

/* ---- building the hierarchy ---- */
- (void)viewDidLoad { [super viewDidLoad]; self.view.backgroundColor = UIColor.systemBackgroundColor; [self _isim_rebuild]; }
- (NSArray<UIViewController *> *)_isim_visibleChildren { return [self.childViewControllers copy]; }
- (void)_isim_rebuild {
    if (!self.isViewLoaded) return;
    for (UIViewController *c in [self.childViewControllers copy]) { [c willMoveToParentViewController:nil]; [c.viewIfLoaded removeFromSuperview]; [c removeFromParentViewController]; }
    [_separator removeFromSuperview];
    _compactNav = nil;
    if (compact(self)) [self _isim_buildCompact]; else [self _isim_buildColumns];
    [self.view setNeedsLayout];
}
- (void)_isim_adopt:(UIViewController *)c {
    [self addChildViewController:c];
    c.view.autoresizingMask = UIViewAutoresizingNone;
    [self.view addSubview:c.view];
    [c didMoveToParentViewController:self];
    if ([self _isim_isVisible]) { [c _isim_appear:YES]; [c _isim_didAppear]; }
}
static NSArray *unwrapped(UIViewController *vc) {
    if ([vc isKindOfClass:[UINavigationController class]]) return ((UINavigationController *)vc).viewControllers;
    return vc ? @[vc] : @[];
}
- (void)_isim_buildCompact {
    if (_cols[3]) {                                                 /* a dedicated compact column */
        UIViewController *c = _cols[3];
        _compactNav = [c isKindOfClass:[UINavigationController class]] ? (UINavigationController *)c : [[UINavigationController alloc] initWithRootViewController:c];
        [self _isim_adopt:_compactNav];
        return;
    }
    UINavigationController *nav = [self _isim_navFor:0];
    if (!nav) return;
    UISplitViewControllerColumn top = UISplitViewControllerColumnSecondary;
    id<UISplitViewControllerDelegate> d = _delegate;
    if (_style != UISplitViewControllerStyleUnspecified && [d respondsToSelector:@selector(splitViewController:topColumnForCollapsingToProposedTopColumn:)])
        top = [d splitViewController:self topColumnForCollapsingToProposedTopColumn:UISplitViewControllerColumnSecondary];
    if (_style == UISplitViewControllerStyleUnspecified && _cols[2] && [d respondsToSelector:@selector(splitViewController:collapseSecondaryViewController:ontoPrimaryViewController:)]
        && [d splitViewController:self collapseSecondaryViewController:_cols[2] ontoPrimaryViewController:_cols[0]]) top = UISplitViewControllerColumnPrimary;
    NSMutableArray *stack = [unwrapped(_cols[0]) mutableCopy];
    if (top != UISplitViewControllerColumnPrimary && _cols[1]) for (UIViewController *v in unwrapped(_cols[1])) if (![stack containsObject:v]) [stack addObject:v];
    if (top == UISplitViewControllerColumnSecondary && _cols[2]) for (UIViewController *v in unwrapped(_cols[2])) if (![stack containsObject:v]) [stack addObject:v];
    _compactNav = nav;
    [self _isim_adopt:nav];                                   /* first, so the columns' controllers find their split view controller */
    [nav setViewControllers:stack animated:NO];
    NSLog(@"isim: split view collapsed, top column %ld, %lu controllers", (long)top, (unsigned long)stack.count);
    if ([d respondsToSelector:@selector(splitViewControllerDidCollapse:)]) [d splitViewControllerDidCollapse:self];
}
- (void)_isim_buildColumns {
    for (int i = 0; i < 3; i++) {
        UINavigationController *n = [self _isim_navFor:i];
        if (!n) continue;
        [self _isim_adopt:n];
        if (n == _nav[i] && ![n.viewControllers containsObject:_cols[i]]) [n setViewControllers:@[_cols[i]] animated:NO];
    }
    _separator = [UIView new]; _separator.backgroundColor = UIColor.separatorColor;
    [self.view addSubview:_separator];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGRect b = self.view.bounds;
    if (_compactNav) { _compactNav.view.frame = b; return; }
    CGFloat x = 0, pw = self.primaryColumnWidth;
    for (int i = 0; i < 3; i++) {
        UIViewController *n = _nav[i] ?: _cols[i];
        if (!n) continue;
        CGFloat w = i == 2 ? b.size.width - x : pw;
        n.view.frame = CGRectMake(x, 0, w, b.size.height);
        x += w + (i < 2 ? 0.5 : 0);
    }
    _separator.frame = CGRectMake(pw, 0, 0.5, b.size.height);
}

/* ---- showing ---- */
- (void)showDetailViewController:(UIViewController *)vc sender:(id)sender {
    id<UISplitViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(splitViewController:showDetailViewController:sender:)] && [d splitViewController:self showDetailViewController:vc sender:sender]) return;
    if (_compactNav) {
        /* the secondary is replaced: back to the primary (and supplementary) level, then push */
        NSUInteger keep = unwrapped([self _isim_navFor:0] == _compactNav ? _cols[0] : _compactNav).count;
        if (_cols[1]) keep += unwrapped(_cols[1]).count;
        NSMutableArray *stack = [[_compactNav.viewControllers subarrayWithRange:NSMakeRange(0, MIN(keep, _compactNav.viewControllers.count))] mutableCopy];
        UIViewController *top = stack.lastObject;
        if (stack.count < _compactNav.viewControllers.count) [_compactNav popToViewController:top animated:NO];
        for (UIViewController *v in unwrapped(vc)) [_compactNav pushViewController:v animated:YES];
        NSLog(@"isim: split view shows detail %@", vc.title ?: NSStringFromClass([vc class]));
        return;
    }
    _cols[2] = vc; _nav[2] = nil;
    [self _isim_rebuild];
}
- (void)showColumn:(UISplitViewControllerColumn)column {
    id<UISplitViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(splitViewController:willShowColumn:)]) [d splitViewController:self willShowColumn:column];
    if (!_compactNav) return;
    NSInteger i = col_index(column);
    if (i == 0) { [_compactNav popToRootViewControllerAnimated:YES]; return; }
    UIViewController *first = unwrapped(_cols[i]).firstObject;
    if (!first) return;
    if ([_compactNav.viewControllers containsObject:first]) [_compactNav popToViewController:unwrapped(_cols[i]).lastObject animated:YES];
    else for (UIViewController *v in unwrapped(_cols[i])) [_compactNav pushViewController:v animated:YES];
}
- (void)hideColumn:(UISplitViewControllerColumn)column {
    id<UISplitViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(splitViewController:willHideColumn:)]) [d splitViewController:self willHideColumn:column];
    if (!_compactNav) return;
    UIViewController *first = unwrapped(_cols[col_index(column)]).firstObject;
    NSUInteger i = [_compactNav.viewControllers indexOfObjectIdenticalTo:first];
    if (i != NSNotFound && i > 0) [_compactNav popToViewController:_compactNav.viewControllers[i - 1] animated:YES];
}
@end

@implementation UIViewController (UISplitViewController)
- (UISplitViewController *)splitViewController {
    for (UIViewController *p = self.parentViewController; p; p = p.parentViewController) if ([p isKindOfClass:[UISplitViewController class]]) return (UISplitViewController *)p;
    return nil;
}
@end

/* ================= UIPageViewController ================= */
UIPageViewControllerOptionsKey const UIPageViewControllerOptionSpineLocationKey = @"UIPageViewControllerOptionSpineLocationKey";
UIPageViewControllerOptionsKey const UIPageViewControllerOptionInterPageSpacingKey = @"UIPageViewControllerOptionInterPageSpacingKey";

@interface UIPageViewController () <UIScrollViewDelegate>
@end
@implementation UIPageViewController {
    UIScrollView *_scroll; UIPageControl *_dots;
    UIViewController *_cur, *_prev, *_next;
    CGFloat _spacing;
    BOOL _notified, _programmatic;
}
- (instancetype)initWithTransitionStyle:(UIPageViewControllerTransitionStyle)style navigationOrientation:(UIPageViewControllerNavigationOrientation)o options:(NSDictionary *)options {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _transitionStyle = style; _navigationOrientation = o;
        _spacing = [options[UIPageViewControllerOptionInterPageSpacingKey] doubleValue];
        _spineLocation = style == UIPageViewControllerTransitionStylePageCurl ? UIPageViewControllerSpineLocationMin : UIPageViewControllerSpineLocationNone;
        if (style == UIPageViewControllerTransitionStylePageCurl) NSLog(@"isim: UIPageViewController page curl is shown as scroll (adapted)");
    }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil]; }
- (BOOL)_isim_vertical { return _navigationOrientation == UIPageViewControllerNavigationOrientationVertical; }
- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll = [UIScrollView new];
    _scroll.pagingEnabled = YES; _scroll.showsHorizontalScrollIndicator = NO; _scroll.showsVerticalScrollIndicator = NO;
    _scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _scroll.clipsToBounds = YES;
    _scroll.delegate = self;
    _scroll.accessibilityIdentifier = @"isim-page-scroll";
    [v addSubview:_scroll];
    _dots = [UIPageControl new];
    _dots.userInteractionEnabled = NO;
    _dots.hidden = YES;
    _dots.accessibilityIdentifier = @"isim-page-dots";
    [v addSubview:_dots];
    self.view = v;
}
- (NSArray *)gestureRecognizers { return _scroll ? @[_scroll.panGestureRecognizer] : @[]; }
- (NSArray *)viewControllers { return _cur ? @[_cur] : @[]; }
- (NSArray<UIViewController *> *)_isim_visibleChildren { return _cur ? @[_cur] : @[]; }
- (CGFloat)_isim_page { CGSize s = self.view.bounds.size; return ([self _isim_vertical] ? s.height : s.width) + _spacing; }

- (void)_isim_attach:(UIViewController *)vc {
    if (!vc || vc.parentViewController == self) return;
    [self addChildViewController:vc];
    [_scroll addSubview:vc.view];
    [vc didMoveToParentViewController:self];
}
- (void)_isim_detach:(UIViewController *)vc {
    if (!vc || vc == _cur || vc == _prev || vc == _next) return;
    [vc willMoveToParentViewController:nil]; [vc.viewIfLoaded removeFromSuperview]; [vc removeFromParentViewController];
}
- (void)_isim_loadNeighbours {
    id<UIPageViewControllerDataSource> ds = _dataSource;
    UIViewController *oldPrev = _prev, *oldNext = _next;
    _prev = _cur ? [ds pageViewController:self viewControllerBeforeViewController:_cur] : nil;
    _next = _cur ? [ds pageViewController:self viewControllerAfterViewController:_cur] : nil;
    [self _isim_detach:oldPrev]; [self _isim_detach:oldNext];
    [self _isim_attach:_prev]; [self _isim_attach:_next]; [self _isim_attach:_cur];
}
/* pages laid out [prev] cur [next]; the scroll view rests on cur */
- (void)_isim_layoutPages {
    if (!_scroll) return;
    CGRect b = self.view.bounds;
    BOOL vert = [self _isim_vertical];
    CGFloat P = [self _isim_page];
    _scroll.frame = vert ? CGRectMake(0, 0, b.size.width, b.size.height + _spacing) : CGRectMake(0, 0, b.size.width + _spacing, b.size.height);
    NSMutableArray *slots = [NSMutableArray array];
    for (UIViewController *x in @[_prev ?: (id)[NSNull null], _cur ?: (id)[NSNull null], _next ?: (id)[NSNull null]]) if ((id)x != [NSNull null]) [slots addObject:x];
    [UIView performWithoutAnimation:^{
        for (NSUInteger i = 0; i < slots.count; i++) {
            UIViewController *vc = slots[i];
            vc.view.frame = vert ? CGRectMake(0, i * P, b.size.width, b.size.height) : CGRectMake(i * P, 0, b.size.width, b.size.height);
        }
        self->_scroll.contentSize = vert ? CGSizeMake(b.size.width, slots.count * P) : CGSizeMake(slots.count * P, b.size.height);
        NSUInteger ci = self->_cur ? [slots indexOfObjectIdenticalTo:self->_cur] : 0;
        self->_scroll.contentOffset = vert ? CGPointMake(0, ci * P) : CGPointMake(ci * P, 0);
    }];
    id<UIPageViewControllerDataSource> ds = _dataSource;
    BOOL dots = [ds respondsToSelector:@selector(presentationCountForPageViewController:)] && [ds respondsToSelector:@selector(presentationIndexForPageViewController:)];
    _dots.hidden = !dots;
    if (dots) {
        _dots.numberOfPages = [ds presentationCountForPageViewController:self];
        _dots.currentPage = [ds presentationIndexForPageViewController:self];
        CGFloat bottom = isim_ui_safe_insets_for_rect(self.view, [self.view convertRect:b toView:nil]).bottom;
        _dots.frame = CGRectMake(0, b.size.height - bottom - 30, b.size.width, 26);
        [self.view bringSubviewToFront:_dots];
    }
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if (!_scroll.isDragging && !_scroll.isDecelerating && !_programmatic) [self _isim_layoutPages]; }

- (void)setViewControllers:(NSArray *)vcs direction:(UIPageViewControllerNavigationDirection)dir animated:(BOOL)animated completion:(void (^)(BOOL))completion {
    UIViewController *vc = vcs.firstObject;
    (void)self.view;
    UIViewController *old = _cur;
    BOOL visible = [self _isim_isVisible];
    if (animated && old && vc && old != vc && self.view.window) {
        /* slide: the new page comes in from the side while the old one leaves */
        _programmatic = YES;
        _cur = vc;
        if (visible) { [old _isim_appear:NO]; [vc _isim_appear:YES]; }
        [self _isim_loadNeighbours];
        [self _isim_layoutPages];
        UIView *ov = old.view, *nv = vc.view;
        if (ov.superview != _scroll) [_scroll addSubview:ov];
        CGRect f = nv.frame;
        BOOL fwd = dir == UIPageViewControllerNavigationDirectionForward, vert = [self _isim_vertical];
        CGFloat d = vert ? f.size.height : f.size.width;
        CGRect in = vert ? CGRectOffset(f, 0, fwd ? d : -d) : CGRectOffset(f, fwd ? d : -d, 0), out = vert ? CGRectOffset(f, 0, fwd ? -d : d) : CGRectOffset(f, fwd ? -d : d, 0);
        [UIView performWithoutAnimation:^{ ov.frame = f; nv.frame = in; }];
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{ ov.frame = out; nv.frame = f; } completion:^(BOOL fin) {
            self->_programmatic = NO;
            [self _isim_detach:old];
            [self _isim_layoutPages];
            if (visible) [vc _isim_didAppear];
            if (completion) completion(YES);
        }];
        return;
    }
    _cur = vc;
    if (old != vc) {
        if (visible) { [old _isim_appear:NO]; }
        [self _isim_loadNeighbours];
        [self _isim_detach:old];
        if (visible) { [vc _isim_appear:YES]; [vc _isim_didAppear]; }
    } else [self _isim_loadNeighbours];
    [self _isim_layoutPages];
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES); });
}

/* ---- scrolling ---- */
- (void)scrollViewDidScroll:(UIScrollView *)sv {
    if (!sv.isDragging || _notified || _programmatic) return;
    CGFloat P = [self _isim_page], pos = [self _isim_vertical] ? sv.contentOffset.y : sv.contentOffset.x;
    CGFloat base = (_prev ? 1 : 0) * P;
    UIViewController *pending = pos > base + 1 ? _next : pos < base - 1 ? _prev : nil;
    if (!pending) return;
    _notified = YES;
    id<UIPageViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(pageViewController:willTransitionToViewControllers:)]) [d pageViewController:self willTransitionToViewControllers:@[pending]];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)sv willDecelerate:(BOOL)decelerate { if (!decelerate) [self _isim_settled]; }
- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv { [self _isim_settled]; }
- (NSInteger)_isim_pageIndex { CGFloat P = [self _isim_page]; return (NSInteger)llround(([self _isim_vertical] ? _scroll.contentOffset.y : _scroll.contentOffset.x) / P); }
- (NSInteger)_isim_slotOf:(UIViewController *)vc {
    NSInteger i = 0;
    for (UIViewController *x in @[_prev ?: [NSNull null], _cur ?: [NSNull null], _next ?: [NSNull null]]) { if ((id)x == [NSNull null]) continue; if (x == vc) return i; i++; }
    return -1;
}
- (void)_isim_settled {
    BOOL notified = _notified; _notified = NO;
    NSInteger page = [self _isim_pageIndex];
    UIViewController *now = page == [self _isim_slotOf:_next] ? _next : page == [self _isim_slotOf:_prev] ? _prev : _cur;
    id<UIPageViewControllerDelegate> d = _delegate;
    UIViewController *old = _cur;
    BOOL completed = now != old;
    if (completed) {
        BOOL visible = [self _isim_isVisible];
        _cur = now;
        if (visible) { [old _isim_appear:NO]; [now _isim_appear:YES]; [now _isim_didAppear]; }
        [self _isim_loadNeighbours];
        [self _isim_detach:old];
        [self _isim_layoutPages];
        NSLog(@"isim: page view controller moved to %@", now.title ?: NSStringFromClass([now class]));
    }
    if ((notified || completed) && [d respondsToSelector:@selector(pageViewController:didFinishAnimating:previousViewControllers:transitionCompleted:)])
        [d pageViewController:self didFinishAnimating:YES previousViewControllers:old ? @[old] : @[] transitionCompleted:completed];
}
@end
