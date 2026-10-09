/* UISplitViewController and UIPageViewController.
 *
 * UISplitViewController: in compact width (every iPhone) it is collapsed into one UINavigationController: the
 * primary column's stack, then (up to the delegate's top column, default .secondary; classic API: unless
 * collapseSecondaryViewController returns true) the supplementary and secondary columns' controllers pushed on
 * it. A .compact column replaces all of that. showDetailViewController pushes in place of the secondary. In
 * regular width the display mode places the columns: beside the secondary (tile), over it (overlay: a shadow, a
 * tap on the secondary hides them) or pushing it aside (displace, dimmed); automatic is tile, or secondary-only
 * for the overlay behaviour. The sidebar button (displayModeButtonItem, shown in the secondary's navigation bar
 * while the primary is hidden for column-style split views) and a swipe from the left edge (presentsWithGesture)
 * show and hide the primary columns. When the size class changes (rotating a Pro Max iPhone) the split view
 * collapses into one stack or expands back into columns: the controllers pushed past the primary become the
 * secondary (classic delegate: separateSecondaryViewController), with didCollapse / didExpand.
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
    UIView *_separator, *_separator2;
    BOOL _built, _secondaryCollapsedAway;
    UIBarButtonItem *_modeItem;
    UISplitViewControllerDisplayMode _mode;   /* chosen by the button, gesture or showColumn (automatic = preferred) */
    UIControl *_dim;                          /* over / displace: covers the secondary, a tap hides the columns */
    int _wasCompact;                          /* -1 unknown */
    NSUInteger _primaryCount;                 /* the primary column's stack depth when collapsed */
    UIScreenEdgePanGestureRecognizer *_edge;
    __weak UINavigationItem *_buttonItemOwner;
}
- (instancetype)initWithStyle:(UISplitViewControllerStyle)style {
    if ((self = [super initWithNibName:nil bundle:nil])) { _style = style; _presentsWithGesture = YES; _showsSecondaryOnlyButton = NO; _wasCompact = -1; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithStyle:UISplitViewControllerStyleUnspecified]; }
- (BOOL)isCollapsed { return compact(self); }
/* compact width: the window's horizontal size class (every iPhone in portrait; Pro Max / Plus iPhones are regular in landscape) */
static BOOL compact(UISplitViewController *s) {
    UIWindow *w = s.viewIfLoaded.window;
    if (w) return w.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    return isim_ui_screen_traits().horizontalSizeClass == UIUserInterfaceSizeClassCompact;
}
- (UISplitViewControllerSplitBehavior)splitBehavior {
    return _preferredSplitBehavior == UISplitViewControllerSplitBehaviorAutomatic ? UISplitViewControllerSplitBehaviorTile : _preferredSplitBehavior;
}
static BOOL triple(UISplitViewController *s) { return s->_cols[1] != nil; }
/* the display mode that shows the primary column(s) under the split behaviour */
- (UISplitViewControllerDisplayMode)_isim_shownMode {
    switch (self.splitBehavior) {
    case UISplitViewControllerSplitBehaviorOverlay: return triple(self) ? UISplitViewControllerDisplayModeTwoOverSecondary : UISplitViewControllerDisplayModeOneOverSecondary;
    case UISplitViewControllerSplitBehaviorDisplace: return triple(self) ? UISplitViewControllerDisplayModeTwoDisplaceSecondary : UISplitViewControllerDisplayModeOneBesideSecondary;
    default: return triple(self) ? UISplitViewControllerDisplayModeTwoBesideSecondary : UISplitViewControllerDisplayModeOneBesideSecondary;
    }
}
- (UISplitViewControllerDisplayMode)displayMode {
    if (compact(self)) return UISplitViewControllerDisplayModeSecondaryOnly;
    UISplitViewControllerDisplayMode m = _mode != UISplitViewControllerDisplayModeAutomatic ? _mode : _preferredDisplayMode;
    if (m == UISplitViewControllerDisplayModeAutomatic)
        m = self.splitBehavior == UISplitViewControllerSplitBehaviorOverlay ? UISplitViewControllerDisplayModeSecondaryOnly : [self _isim_shownMode];
    if (!triple(self) && (m == UISplitViewControllerDisplayModeTwoBesideSecondary || m == UISplitViewControllerDisplayModeTwoDisplaceSecondary)) m = UISplitViewControllerDisplayModeOneBesideSecondary;
    if (!triple(self) && m == UISplitViewControllerDisplayModeTwoOverSecondary) m = UISplitViewControllerDisplayModeOneOverSecondary;
    return m;
}
- (void)setPreferredDisplayMode:(UISplitViewControllerDisplayMode)m { _preferredDisplayMode = m; _mode = UISplitViewControllerDisplayModeAutomatic; [self _isim_modeChanged:NO]; }
- (void)setPreferredSplitBehavior:(UISplitViewControllerSplitBehavior)b { _preferredSplitBehavior = b; [self _isim_modeChanged:NO]; }
- (void)setPresentsWithGesture:(BOOL)p { _presentsWithGesture = p; [self _isim_updateButton]; }
- (void)setDisplayModeButtonVisibility:(UISplitViewControllerDisplayModeButtonVisibility)v { _displayModeButtonVisibility = v; [self _isim_updateButton]; }
static NSString *mode_name(UISplitViewControllerDisplayMode m) {
    switch (m) {
    case UISplitViewControllerDisplayModeSecondaryOnly: return @"secondaryOnly";
    case UISplitViewControllerDisplayModeOneBesideSecondary: return @"oneBesideSecondary";
    case UISplitViewControllerDisplayModeOneOverSecondary: return @"oneOverSecondary";
    case UISplitViewControllerDisplayModeTwoBesideSecondary: return @"twoBesideSecondary";
    case UISplitViewControllerDisplayModeTwoOverSecondary: return @"twoOverSecondary";
    case UISplitViewControllerDisplayModeTwoDisplaceSecondary: return @"twoDisplaceSecondary";
    default: return @"automatic";
    }
}
/* go to a display mode (button, gesture, showColumn, a tap on the dimmed secondary) */
- (void)_isim_setMode:(UISplitViewControllerDisplayMode)m {
    if (compact(self) || m == self.displayMode) return;
    id<UISplitViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(splitViewController:willChangeToDisplayMode:)]) [d splitViewController:self willChangeToDisplayMode:m];
    BOOL wasShown = self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly, shown = m != UISplitViewControllerDisplayModeSecondaryOnly;
    if (_style != UISplitViewControllerStyleUnspecified && wasShown != shown) {
        if (shown && [d respondsToSelector:@selector(splitViewController:willShowColumn:)]) [d splitViewController:self willShowColumn:UISplitViewControllerColumnPrimary];
        if (!shown && [d respondsToSelector:@selector(splitViewController:willHideColumn:)]) [d splitViewController:self willHideColumn:UISplitViewControllerColumnPrimary];
    }
    _mode = m;
    [self _isim_modeChanged:YES];
    NSLog(@"isim: split view display mode %@", mode_name(m));
}
- (void)_isim_modeChanged:(BOOL)animated {
    if (!self.isViewLoaded || _compactNav) return;
    [self _isim_updateButton];
    if (animated && self.view.window) {
        [self.view setNeedsLayout];
        [UIView animateWithDuration:0.3 animations:^{ [self.view layoutIfNeeded]; }];
    } else [self.view setNeedsLayout];
}
- (UISplitViewControllerDisplayMode)_isim_toggleTarget {
    id<UISplitViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(targetDisplayModeForActionInSplitViewController:)]) {
        UISplitViewControllerDisplayMode m = [d targetDisplayModeForActionInSplitViewController:self];
        if (m != UISplitViewControllerDisplayModeAutomatic) return m;
    }
    if (self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly) return UISplitViewControllerDisplayModeSecondaryOnly;
    if (self.splitBehavior == UISplitViewControllerSplitBehaviorTile && (_preferredDisplayMode == UISplitViewControllerDisplayModeSecondaryOnly || _preferredDisplayMode == UISplitViewControllerDisplayModeAutomatic))
        return [self _isim_shownMode];
    UISplitViewControllerDisplayMode p = _preferredDisplayMode;
    return p != UISplitViewControllerDisplayModeAutomatic && p != UISplitViewControllerDisplayModeSecondaryOnly ? p : [self _isim_shownMode];
}
- (void)_isim_toggle:(id)sender { [self _isim_setMode:[self _isim_toggleTarget]]; }
- (void)_isim_edge:(UIScreenEdgePanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan && self.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
        NSLog(@"isim: split view edge swipe");
        [self _isim_toggle:g];
    }
}
- (void)_isim_dimTapped { if (self.displayMode != UISplitViewControllerDisplayModeOneBesideSecondary && self.displayMode != UISplitViewControllerDisplayModeTwoBesideSecondary) [self _isim_setMode:UISplitViewControllerDisplayModeSecondaryOnly]; }
/* the sidebar button in the secondary column's navigation bar while the primary is hidden (column style) */
- (void)_isim_updateButton {
    UINavigationItem *old = _buttonItemOwner;
    if (old && [old.leftBarButtonItems containsObject:self.displayModeButtonItem]) {
        NSMutableArray *a = [old.leftBarButtonItems mutableCopy]; [a removeObject:self.displayModeButtonItem]; old.leftBarButtonItems = a;
    }
    _buttonItemOwner = nil;
    _edge.enabled = _presentsWithGesture && !_compactNav;
    if (_style == UISplitViewControllerStyleUnspecified || _compactNav || _displayModeButtonVisibility == UISplitViewControllerDisplayModeButtonVisibilityNever) return;
    BOOL hidden = self.displayMode == UISplitViewControllerDisplayModeSecondaryOnly;
    if (_displayModeButtonVisibility != UISplitViewControllerDisplayModeButtonVisibilityAlways && !(hidden && _presentsWithGesture)) return;
    UINavigationController *n = _nav[2] ?: ([_cols[2] isKindOfClass:[UINavigationController class]] ? (UINavigationController *)_cols[2] : nil);
    UINavigationItem *item = n.viewControllers.firstObject.navigationItem;
    if (!item) return;
    item.leftBarButtonItems = [@[self.displayModeButtonItem] arrayByAddingObjectsFromArray:item.leftBarButtonItems ?: @[]];
    _buttonItemOwner = item;
}
- (CGFloat)primaryColumnWidth {
    CGFloat W = self.viewIfLoaded.bounds.size.width ?: isim_ui_device()->width;
    CGFloat w = _preferredPrimaryColumnWidth > 0 ? _preferredPrimaryColumnWidth : _preferredPrimaryColumnWidthFraction > 0 ? W * _preferredPrimaryColumnWidthFraction : 320;
    if (_minimumPrimaryColumnWidth > 0) w = fmax(w, _minimumPrimaryColumnWidth);
    if (_maximumPrimaryColumnWidth > 0) w = fmin(w, _maximumPrimaryColumnWidth);
    return fmin(w, W / 2);
}
- (CGFloat)supplementaryColumnWidth {
    CGFloat W = self.viewIfLoaded.bounds.size.width ?: isim_ui_device()->width;
    CGFloat w = _preferredSupplementaryColumnWidth > 0 ? _preferredSupplementaryColumnWidth : _preferredSupplementaryColumnWidthFraction > 0 ? W * _preferredSupplementaryColumnWidthFraction : 320;
    return fmin(w, W / 2);
}
- (UIBarButtonItem *)displayModeButtonItem {
    if (!_modeItem) {
        _modeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"sidebar.left"] style:UIBarButtonItemStylePlain target:self action:@selector(_isim_toggle:)];
        _modeItem.accessibilityIdentifier = @"isim-split-toggle";
        _modeItem.accessibilityLabel = @"Show Sidebar";
    }
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
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _edge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_edge:)];
    _edge.edges = UIRectEdgeLeft;
    [self.view addGestureRecognizer:_edge];
    [self _isim_rebuild];
}
- (NSArray<UIViewController *> *)_isim_visibleChildren { return [self.childViewControllers copy]; }
- (void)_isim_rebuild {
    if (!self.isViewLoaded) return;
    for (UIViewController *c in [self.childViewControllers copy]) { [c willMoveToParentViewController:nil]; [c.viewIfLoaded removeFromSuperview]; [c removeFromParentViewController]; }
    [_separator removeFromSuperview]; [_separator2 removeFromSuperview]; [_dim removeFromSuperview];
    _compactNav = nil;
    _wasCompact = compact(self);
    if (_wasCompact) [self _isim_buildCompact]; else [self _isim_buildColumns];
    [self _isim_updateButton];
    [self.view setNeedsLayout];
}
/* the size class changed: collapse into one stack, or expand back into columns */
- (void)_isim_sizeClassChanged {
    BOOL now = compact(self);
    id<UISplitViewControllerDelegate> d = _delegate;
    if (!now && _compactNav && !_cols[3]) {
        /* controllers pushed past the primary (and supplementary) levels become the secondary column */
        NSArray *stack = _compactNav.viewControllers;
        NSUInteger keep = MIN(_primaryCount + (_cols[1] ? unwrapped(_cols[1]).count : 0), stack.count);
        NSArray *extra = [stack subarrayWithRange:NSMakeRange(keep, stack.count - keep)];
        [_compactNav setViewControllers:[stack subarrayWithRange:NSMakeRange(0, MIN(_primaryCount, stack.count))] animated:NO];
        UIViewController *separated = nil;
        if (_style == UISplitViewControllerStyleUnspecified && [d respondsToSelector:@selector(splitViewController:separateSecondaryViewControllerFromPrimaryViewController:)])
            separated = [d splitViewController:self separateSecondaryViewControllerFromPrimaryViewController:_cols[0]];
        if (separated) { _cols[2] = separated; _nav[2] = nil; }
        else if (extra.count && ![extra containsObject:unwrapped(_cols[2]).firstObject]) {
            if ([_cols[2] isKindOfClass:[UINavigationController class]]) [(UINavigationController *)_cols[2] setViewControllers:extra animated:NO];
            else { _cols[2] = extra.count == 1 ? extra[0] : [[UINavigationController alloc] init]; _nav[2] = nil;
                   if (extra.count > 1) [(UINavigationController *)_cols[2] setViewControllers:extra animated:NO]; }
        }
        [self _isim_rebuild];
        UISplitViewControllerDisplayMode m = self.displayMode;
        if ([d respondsToSelector:@selector(splitViewController:displayModeForExpandingToProposedDisplayMode:)]) {
            UISplitViewControllerDisplayMode want = [d splitViewController:self displayModeForExpandingToProposedDisplayMode:m];
            if (want != UISplitViewControllerDisplayModeAutomatic && want != m) { _mode = want; [self.view setNeedsLayout]; }
        }
        NSLog(@"isim: split view expanded (%@)", mode_name(self.displayMode));
        if ([d respondsToSelector:@selector(splitViewControllerDidExpand:)]) [d splitViewControllerDidExpand:self];
        return;
    }
    [self _isim_rebuild];
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
    _primaryCount = unwrapped(_cols[0]).count;
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
    _separator2 = [UIView new]; _separator2.backgroundColor = UIColor.separatorColor;
    [self.view addSubview:_separator2];
    _dim = [UIControl new];
    _dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    _dim.accessibilityIdentifier = @"isim-split-dimming";
    [_dim addTarget:self action:@selector(_isim_dimTapped) forControlEvents:UIControlEventTouchUpInside];
    _dim.hidden = YES;
    [self.view addSubview:_dim];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_wasCompact >= 0 && self.view.window && (BOOL)_wasCompact != compact(self)) { [self _isim_sizeClassChanged]; [self.view layoutIfNeeded]; return; }
    CGRect b = self.view.bounds;
    if (_compactNav) { _compactNav.view.frame = b; return; }
    UIView *pv = (_nav[0] ?: _cols[0]).view, *sv = (_nav[1] ?: _cols[1]).view, *dv = (_nav[2] ?: _cols[2]).view;
    CGFloat W = b.size.width, H = b.size.height, pw = self.primaryColumnWidth, swd = self.supplementaryColumnWidth;
    UISplitViewControllerDisplayMode m = self.displayMode;
    BOOL two = m == UISplitViewControllerDisplayModeTwoBesideSecondary || m == UISplitViewControllerDisplayModeTwoOverSecondary || m == UISplitViewControllerDisplayModeTwoDisplaceSecondary;
    BOOL over = m == UISplitViewControllerDisplayModeOneOverSecondary || m == UISplitViewControllerDisplayModeTwoOverSecondary;
    BOOL displace = m == UISplitViewControllerDisplayModeTwoDisplaceSecondary, hidden = m == UISplitViewControllerDisplayModeSecondaryOnly;
    /* the leading columns: "one" is the primary (double column) or the supplementary (triple column) */
    CGFloat lead = 0;
    if (triple(self)) {
        BOOL showPrimary = two, showSupp = !hidden;
        pv.frame = CGRectMake(showPrimary ? 0 : -pw - 1, 0, pw, H);
        CGFloat sx = showPrimary ? pw + 0.5 : (showSupp ? 0 : -pw - swd - 2);
        sv.frame = CGRectMake(sx, 0, swd, H);
        lead = showSupp ? sx + swd + 0.5 : 0;
    } else {
        pv.frame = CGRectMake(hidden ? -pw - 1 : 0, 0, pw, H);
        lead = hidden ? 0 : pw + 0.5;
    }
    if (over) dv.frame = CGRectMake(0, 0, W, H);
    else if (displace) dv.frame = CGRectMake(lead, 0, W - (triple(self) ? 0 : 0), H);
    else dv.frame = CGRectMake(lead, 0, W - lead, H);
    _dim.hidden = !(over || displace);
    _dim.frame = dv.frame;
    [self.view bringSubviewToFront:dv];
    [self.view bringSubviewToFront:_dim];
    [self.view bringSubviewToFront:sv]; [self.view bringSubviewToFront:pv];
    for (UIView *v in @[pv ?: [UIView new], sv ?: [UIView new]]) {
        v.layer.shadowColor = UIColor.blackColor.CGColor; v.layer.shadowOpacity = over ? 0.25 : 0; v.layer.shadowRadius = 12; v.layer.shadowOffset = CGSizeZero;
    }
    _separator.hidden = over || hidden; _separator2.hidden = over || hidden || !triple(self) || !two;
    _separator.frame = CGRectMake(triple(self) && !two ? swd : pw, 0, 0.5, H);
    _separator2.frame = CGRectMake(pw + 0.5 + swd, 0, 0.5, H);
    [self.view bringSubviewToFront:_separator]; [self.view bringSubviewToFront:_separator2];
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
    UISplitViewControllerDisplayMode m = self.displayMode;
    [self _isim_rebuild];
    /* columns over (or displacing) the secondary go away once it shows something new */
    if (m == UISplitViewControllerDisplayModeOneOverSecondary || m == UISplitViewControllerDisplayModeTwoOverSecondary || m == UISplitViewControllerDisplayModeTwoDisplaceSecondary)
        [self _isim_setMode:UISplitViewControllerDisplayModeSecondaryOnly];
}
- (void)showColumn:(UISplitViewControllerColumn)column {
    id<UISplitViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(splitViewController:willShowColumn:)]) [d splitViewController:self willShowColumn:column];
    if (!_compactNav) {
        UISplitViewControllerDisplayMode m = self.displayMode;
        if (column == UISplitViewControllerColumnPrimary && (m == UISplitViewControllerDisplayModeSecondaryOnly || (triple(self) && m == UISplitViewControllerDisplayModeOneBesideSecondary)))
            [self _isim_setMode:triple(self) ? (self.splitBehavior == UISplitViewControllerSplitBehaviorOverlay ? UISplitViewControllerDisplayModeTwoOverSecondary : self.splitBehavior == UISplitViewControllerSplitBehaviorDisplace ? UISplitViewControllerDisplayModeTwoDisplaceSecondary : UISplitViewControllerDisplayModeTwoBesideSecondary) : [self _isim_shownMode]];
        else if (column == UISplitViewControllerColumnSupplementary && m == UISplitViewControllerDisplayModeSecondaryOnly)
            [self _isim_setMode:self.splitBehavior == UISplitViewControllerSplitBehaviorOverlay ? UISplitViewControllerDisplayModeOneOverSecondary : UISplitViewControllerDisplayModeOneBesideSecondary];
        return;
    }
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
    if (!_compactNav) {
        if (column == UISplitViewControllerColumnPrimary && triple(self) && self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly)
            [self _isim_setMode:UISplitViewControllerDisplayModeOneBesideSecondary];
        else if (column != UISplitViewControllerColumnSecondary) [self _isim_setMode:UISplitViewControllerDisplayModeSecondaryOnly];
        return;
    }
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
