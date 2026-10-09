/* iOS 27.1 UIKit for foldable devices, as it behaves on isim's devices (none of which folds), and iOS 26 layout regions.
 *
 * - UIArrangementViewController (adapted): a container of a primary and a secondary view controller.
 *     split: side by side (horizontal axis) or stacked (vertical axis) within the arrangement's axes; with both
 *       axes allowed, compact width in portrait stacks, anything else is side by side. Sizes along the split axis
 *       come from the views' dimension ranges (preferred: absolute points, a fraction of the container, the view's
 *       intrinsic size, or automatic: an equal share of what is left; clamped to minimum / maximum); when they do
 *       not fill the container, the view with the lower layoutPriority takes the difference (the secondary on a
 *       tie). A missing view leaves the whole container to the other one.
 *     overlay: the primary layered over the secondary, both filling the container; it turns side by side only
 *       when a foldable device folds, which never happens on isim.
 *   The layout is logged ("isim: arrangement ...") and updateArrangement(_:animated: true) animates it.
 * - UIHingeInteraction: no hinge provides updates, so the handler is called with a nil hinge when the interaction
 *   joins or leaves a window.
 * - Reserved regions: occlusion is the Dynamic Island or the notch (on its side in landscape), active, no margins;
 *   no division regions (no hinge).
 * - Vertical bar: no device has one: verticalBarEdge is unspecified, the preferences are resolved and kept.
 * - Layout regions (iOS 26): safe area, margins and readable content (no window controls, so corner adaptation
 *   changes nothing) and (27.1) a bar strip of a given extent along an edge of the safe area.
 */
#import "UIKitPrivate.h"
#import <objc/runtime.h>

/* ================= arrangements ================= */
typedef NS_ENUM(NSInteger, IsimDim) { DimAutomatic, DimIntrinsic, DimAbsolute, DimFractional };
@interface UISplitArrangementDimension () { @public IsimDim _kind; CGFloat _value; }
@end
@implementation UISplitArrangementDimension
+ (instancetype)_isim:(IsimDim)k value:(CGFloat)v { UISplitArrangementDimension *d = [self new]; d->_kind = k; d->_value = v; return d; }
+ (instancetype)automaticDimension { return [self _isim:DimAutomatic value:0]; }
+ (instancetype)intrinsicDimension { return [self _isim:DimIntrinsic value:0]; }
+ (instancetype)absoluteDimension:(CGFloat)v { return [self _isim:DimAbsolute value:v]; }
+ (instancetype)fractionalDimension:(CGFloat)f { return [self _isim:DimFractional value:f]; }
- (id)copyWithZone:(NSZone *)z { return self; }                     /* immutable */
- (BOOL)isEqual:(UISplitArrangementDimension *)o { return [o isKindOfClass:[UISplitArrangementDimension class]] && o->_kind == _kind && o->_value == _value; }
- (NSUInteger)hash { return (NSUInteger)_kind * 31 + (NSUInteger)(_value * 1000); }
- (NSString *)description {
    switch (_kind) { case DimAutomatic: return @"automatic"; case DimIntrinsic: return @"intrinsic";
        case DimAbsolute: return [NSString stringWithFormat:@"%gpt", _value]; default: return [NSString stringWithFormat:@"%g%%", _value * 100]; }
}
@end
@implementation UISplitArrangementDimensionRange
- (instancetype)init {
    if ((self = [super init])) { _minimum = [UISplitArrangementDimension automaticDimension]; _preferred = _minimum; _maximum = _minimum; }
    return self;
}
- (id)copyWithZone:(NSZone *)z { UISplitArrangementDimensionRange *r = [UISplitArrangementDimensionRange new]; r.minimum = _minimum; r.preferred = _preferred; r.maximum = _maximum; return r; }
@end
@implementation UISplitArrangementViewProperties
- (instancetype)init { if ((self = [super init])) { _width = [UISplitArrangementDimensionRange new]; _height = [UISplitArrangementDimensionRange new]; } return self; }
- (id)copyWithZone:(NSZone *)z { UISplitArrangementViewProperties *p = [UISplitArrangementViewProperties new]; p.width = _width; p.height = _height; p.layoutPriority = _layoutPriority; return p; }
@end
@implementation UIOverlayArrangementViewProperties
- (instancetype)init { return [super init]; }
- (id)copyWithZone:(NSZone *)z { UIOverlayArrangementViewProperties *p = [UIOverlayArrangementViewProperties new]; p.edge = _edge; return p; }
@end

@implementation UIArrangement
- (id)copyWithZone:(NSZone *)z { return [[self class] new]; }
@end
@implementation UISplitArrangement { NSMutableDictionary<NSNumber *, UISplitArrangementViewProperties *> *_props; }
+ (instancetype)splitArrangement { return [self new]; }
- (instancetype)init { if ((self = [super init])) { _axes = UIAxisBoth; _props = [NSMutableDictionary dictionary]; } return self; }
- (UISplitArrangementViewProperties *)defaultViewProperties { return [UISplitArrangementViewProperties new]; }
- (void)setViewProperties:(UISplitArrangementViewProperties *)p forPlacement:(UIArrangementViewControllerViewPlacement)pl { if (p) _props[@(pl)] = [p copy]; else [_props removeObjectForKey:@(pl)]; }
- (UISplitArrangementViewProperties *)_isim_propertiesFor:(UIArrangementViewControllerViewPlacement)pl { return _props[@(pl)] ?: self.defaultViewProperties; }
- (id)copyWithZone:(NSZone *)z {
    UISplitArrangement *c = [UISplitArrangement new]; c.axes = _axes;
    for (NSNumber *k in _props) [c setViewProperties:_props[k] forPlacement:k.integerValue];
    return c;
}
@end
@implementation UIOverlayArrangement { NSMutableDictionary<NSNumber *, UIOverlayArrangementViewProperties *> *_props; }
+ (instancetype)overlayArrangement { return [self new]; }
- (instancetype)init { if ((self = [super init])) { _axes = UIAxisBoth; _props = [NSMutableDictionary dictionary]; } return self; }
- (UIOverlayArrangementViewProperties *)defaultViewProperties { return [UIOverlayArrangementViewProperties new]; }
- (void)setViewProperties:(UIOverlayArrangementViewProperties *)p forPlacement:(UIArrangementViewControllerViewPlacement)pl { if (p) _props[@(pl)] = [p copy]; else [_props removeObjectForKey:@(pl)]; }
- (id)copyWithZone:(NSZone *)z {
    UIOverlayArrangement *c = [UIOverlayArrangement new]; c.axes = _axes;
    for (NSNumber *k in _props) [c setViewProperties:_props[k] forPlacement:k.integerValue];
    return c;
}
@end

@interface UIArrangementViewState ()
@property (nonatomic, readwrite, getter=isHidden) BOOL hidden;
@property (nonatomic, readwrite) UIAxis splitAxis;
@property (nonatomic, readwrite) NSInteger zIndex;
@end
@implementation UIArrangementViewState @end

@implementation UIArrangementViewController {
    UIViewController *_primary, *_secondary;
    UIArrangement *_arrangement;
    NSMutableDictionary<NSNumber *, UIArrangementViewState *> *_states;
    NSString *_logged;
}
- (instancetype)init { if ((self = [super initWithNibName:nil bundle:nil])) { _arrangement = [UISplitArrangement new]; _states = [NSMutableDictionary dictionary]; } return self; }
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { if ((self = [super initWithNibName:n bundle:b])) { _arrangement = [UISplitArrangement new]; _states = [NSMutableDictionary dictionary]; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    for (UIViewController *vc in @[_primary ?: (id)NSNull.null, _secondary ?: (id)NSNull.null]) if ([vc isKindOfClass:[UIViewController class]]) [self _isim_install:vc];
    [self _isim_order];
}
- (void)_isim_install:(UIViewController *)vc {
    if (!self.isViewLoaded) return;
    vc.view.frame = self.view.bounds;
    [self.view addSubview:vc.view];
}
- (void)_isim_order {                               /* overlay: the primary on top; split: primary first */
    if (!self.isViewLoaded) return;
    if (_secondary.isViewLoaded && _secondary.view.superview == self.view) [self.view sendSubviewToBack:_secondary.view];
    if (_primary.isViewLoaded && _primary.view.superview == self.view) [self.view bringSubviewToFront:_primary.view];
}
- (UIViewController *)viewControllerForPlacement:(UIArrangementViewControllerViewPlacement)p {
    return p == UIArrangementViewControllerViewPlacementPrimary ? _primary : p == UIArrangementViewControllerViewPlacementSecondary ? _secondary : nil;
}
- (UIArrangementViewControllerViewPlacement)placementForViewController:(UIViewController *)vc {
    if (vc && vc == _primary) return UIArrangementViewControllerViewPlacementPrimary;
    if (vc && vc == _secondary) return UIArrangementViewControllerViewPlacementSecondary;
    return UIArrangementViewControllerViewPlacementNone;
}
- (void)setViewController:(UIViewController *)vc forPlacement:(UIArrangementViewControllerViewPlacement)p { [self setViewController:vc forPlacement:p animated:NO]; }
- (void)setViewController:(UIViewController *)vc forPlacement:(UIArrangementViewControllerViewPlacement)p animated:(BOOL)animated {
    if (p != UIArrangementViewControllerViewPlacementPrimary && p != UIArrangementViewControllerViewPlacementSecondary) return;
    UIViewController *old = [self viewControllerForPlacement:p];
    if (old == vc) return;
    UIArrangementViewControllerViewPlacement other = p == UIArrangementViewControllerViewPlacementPrimary ? UIArrangementViewControllerViewPlacementSecondary : UIArrangementViewControllerViewPlacementPrimary;
    if (vc && [self viewControllerForPlacement:other] == vc) {     /* moving from the other placement */
        if (other == UIArrangementViewControllerViewPlacementPrimary) _primary = nil; else _secondary = nil;
    } else if (vc) {
        [vc removeFromParentViewController];
        [self addChildViewController:vc];
    }
    if (old) { [old willMoveToParentViewController:nil]; if (old.isViewLoaded) [old.view removeFromSuperview]; [old removeFromParentViewController]; }
    if (p == UIArrangementViewControllerViewPlacementPrimary) _primary = vc; else _secondary = vc;
    if (vc) { if (!vc.view.superview || vc.view.superview != self.view) [self _isim_install:vc]; [vc didMoveToParentViewController:self]; }
    [self _isim_order];
    [self _isim_relayout:animated];
}
- (void)updateArrangement:(UIArrangement *)a { [self updateArrangement:a animated:NO]; }
- (void)updateArrangement:(UIArrangement *)a animated:(BOOL)animated {
    if (!a) return;
    _arrangement = [a copy];
    [self _isim_order];
    [self _isim_relayout:animated];
}
- (UIArrangementViewState *)stateForPlacement:(UIArrangementViewControllerViewPlacement)p {
    if (![self viewControllerForPlacement:p]) return nil;
    if (self.isViewLoaded) [self.view layoutIfNeeded];
    return _states[@(p)];
}
- (void)_isim_relayout:(BOOL)animated {
    if (!self.isViewLoaded) return;
    if (animated) { [self.view setNeedsLayout]; [UIView animateWithDuration:0.3 animations:^{ [self.view layoutIfNeeded]; }]; }
    else { [self.view setNeedsLayout]; [self.view layoutIfNeeded]; }
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self _isim_layout]; }

/* a size along the axis from a dimension; -1 for automatic */
static CGFloat resolve(UISplitArrangementDimension *d, CGFloat length, UIViewController *vc, BOOL horizontal, CGFloat crossLength) {
    switch (d->_kind) {
        case DimAbsolute: return d->_value;
        case DimFractional: return d->_value * length;
        case DimIntrinsic: {
            CGSize pc = vc.preferredContentSize;
            CGFloat v = horizontal ? pc.width : pc.height;
            if (v > 0) return v;
            CGSize fit = [vc.view systemLayoutSizeFittingSize:horizontal ? CGSizeMake(0, crossLength) : CGSizeMake(crossLength, 0)];
            return horizontal ? fit.width : fit.height;
        }
        default: return -1;
    }
}
- (void)_isim_layout {
    CGRect b = self.view.bounds;
    UIArrangementViewState *(^state)(BOOL, UIAxis, NSInteger) = ^UIArrangementViewState *(BOOL hidden, UIAxis axis, NSInteger z) {
        UIArrangementViewState *s = [UIArrangementViewState new]; s.hidden = hidden; s.splitAxis = axis; s.zIndex = z; return s;
    };
    NSString *log;
    if ([_arrangement isKindOfClass:[UIOverlayArrangement class]]) {
        if (_primary) _primary.view.frame = b;
        if (_secondary) _secondary.view.frame = b;
        _states[@(UIArrangementViewControllerViewPlacementPrimary)] = state(!_primary, UIAxisNeither, 1);
        _states[@(UIArrangementViewControllerViewPlacementSecondary)] = state(!_secondary, UIAxisNeither, 0);
        log = @"overlay";
    } else {
        UISplitArrangement *sa = (UISplitArrangement *)_arrangement;
        UIAxis allowed = sa.axes & UIAxisBoth; if (!allowed) allowed = UIAxisBoth;
        BOOL compactPortrait = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact && b.size.height > b.size.width;
        UIAxis axis = allowed == UIAxisBoth ? (compactPortrait ? UIAxisVertical : UIAxisHorizontal) : allowed;
        BOOL h = axis == UIAxisHorizontal;
        CGFloat L = h ? b.size.width : b.size.height, cross = h ? b.size.height : b.size.width;
        if (!_primary || !_secondary) {
            UIViewController *only = _primary ?: _secondary;
            only.view.frame = b;
            _states[@(UIArrangementViewControllerViewPlacementPrimary)] = state(!_primary, axis, 0);
            _states[@(UIArrangementViewControllerViewPlacementSecondary)] = state(!_secondary, axis, 0);
            log = [NSString stringWithFormat:@"split %@ %@ only", h ? @"horizontal" : @"vertical", _primary ? @"primary" : _secondary ? @"secondary" : @"empty"];
        } else {
            UISplitArrangementViewProperties *pp = [sa _isim_propertiesFor:UIArrangementViewControllerViewPlacementPrimary],
                                             *sp = [sa _isim_propertiesFor:UIArrangementViewControllerViewPlacementSecondary];
            UISplitArrangementDimensionRange *pr = h ? pp.width : pp.height, *sr = h ? sp.width : sp.height;
            CGFloat p = resolve(pr.preferred, L, _primary, h, cross), s = resolve(sr.preferred, L, _secondary, h, cross);
            CGFloat pmin = fmax(0, resolve(pr.minimum, L, _primary, h, cross)), smin = fmax(0, resolve(sr.minimum, L, _secondary, h, cross));
            CGFloat pmax = resolve(pr.maximum, L, _primary, h, cross), smax = resolve(sr.maximum, L, _secondary, h, cross);
            if (pmax < 0) pmax = L; if (smax < 0) smax = L;
            if (p < 0 && s < 0) { p = L / 2; s = L - p; }
            else if (p < 0) { s = fmin(fmax(s, smin), smax); p = L - s; }
            else if (s < 0) { p = fmin(fmax(p, pmin), pmax); s = L - p; }
            else {                                       /* both fixed: the lower priority takes the difference */
                BOOL primaryGives = pp.layoutPriority < sp.layoutPriority;
                if (primaryGives) { s = fmin(fmax(s, smin), smax); p = L - s; } else { p = fmin(fmax(p, pmin), pmax); s = L - p; }
            }
            p = fmin(fmax(p, fmin(pmin, L)), fmax(fmin(pmax, L), 0)); s = L - p;
            p = round(p); s = L - p;
            _primary.view.frame = h ? CGRectMake(0, 0, p, b.size.height) : CGRectMake(0, 0, b.size.width, p);
            _secondary.view.frame = h ? CGRectMake(p, 0, s, b.size.height) : CGRectMake(0, p, b.size.width, s);
            _states[@(UIArrangementViewControllerViewPlacementPrimary)] = state(p <= 0, axis, 0);
            _states[@(UIArrangementViewControllerViewPlacementSecondary)] = state(s <= 0, axis, 0);
            log = [NSString stringWithFormat:@"split %@ primary %g secondary %g", h ? @"horizontal" : @"vertical", p, s];
        }
    }
    if (![log isEqualToString:_logged]) { _logged = log; NSLog(@"isim: arrangement %@", log); }
}
@end

@implementation UIViewController (UIArrangementViewController)
- (UIArrangementViewController *)arrangementViewController {
    for (UIViewController *p = self.parentViewController; p; p = p.parentViewController)
        if ([p isKindOfClass:[UIArrangementViewController class]]) return (UIArrangementViewController *)p;
    return nil;
}
@end

/* ================= hinge ================= */
@implementation UIHinge { @public CGFloat _angle; UIHingeStatus _status; }
- (CGFloat)angle { return _angle; }
- (UIHingeStatus)status { return _status; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UIHingeInteractionUpdate { UIHinge *_hinge; }
- (instancetype)initForIsimWithHinge:(UIHinge *)h { if ((self = [super init])) _hinge = h; return self; }
- (UIHinge *)hinge { return _hinge; }
@end
@implementation UIHingeInteraction { void (^_handler)(UIHingeInteraction *, UIHingeInteractionUpdate *); }
@synthesize view = _view;
- (instancetype)initWithUpdateHandler:(void (^)(UIHingeInteraction *, UIHingeInteractionUpdate *))h { if ((self = [super init])) { _handler = [h copy]; _enabled = YES; } return self; }
- (void)willMoveToView:(UIView *)view {}
- (void)didMoveToView:(UIView *)view {
    _view = view;
    if (!_enabled) return;
    __weak UIHingeInteraction *ws = self;                /* after the caller finished adding it */
    dispatch_async(dispatch_get_main_queue(), ^{
        UIHingeInteraction *s = ws;
        if (!s || !s->_enabled || !s->_handler) return;
        NSLog(@"isim: hinge interaction: no hinge (the device does not fold)");
        s->_handler(s, [[UIHingeInteractionUpdate alloc] initForIsimWithHinge:nil]);
    });
}
@end

/* ================= vertical bar ================= */
static char kCompression, kAxis;
@implementation UINavigationItem (UIVerticalBar)
- (UIVerticalBarCompressionBehavior)verticalBarCompressionBehavior { return [objc_getAssociatedObject(self, &kCompression) integerValue]; }
- (void)setVerticalBarCompressionBehavior:(UIVerticalBarCompressionBehavior)b { objc_setAssociatedObject(self, &kCompression, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation UIBarButtonItem (UIBarButtonItemAxisBehavior)
- (UIBarButtonItemAxisBehavior)axisBehavior { return [objc_getAssociatedObject(self, &kAxis) integerValue]; }
- (void)setAxisBehavior:(UIBarButtonItemAxisBehavior)b { objc_setAssociatedObject(self, &kAxis, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation UIViewController (UIVerticalBar)
- (UIVerticalBarBehavior)preferredVerticalBarBehavior { return UIVerticalBarBehaviorAutomatic; }
- (UIViewController *)childViewControllerForPreferredVerticalBarBehavior { return nil; }
/* the preference in effect: down the child chain from this controller's window root */
- (void)setNeedsUpdateOfVerticalBarConfiguration {
    UIViewController *vc = self.viewIfLoaded.window.rootViewController ?: self;
    for (int i = 0; i < 32; i++) { UIViewController *c = vc.childViewControllerForPreferredVerticalBarBehavior; if (!c || c == vc) break; vc = c; }
    NSLog(@"isim: vertical bar behavior %@ (from %@; no vertical bar on this device)",
          vc.preferredVerticalBarBehavior == UIVerticalBarBehaviorDisabled ? @"disabled" : @"automatic", NSStringFromClass([vc class]));
}
@end
@implementation UINavigationController (UIVerticalBar)
- (UIViewController *)childViewControllerForPreferredVerticalBarBehavior { return self.topViewController; }
@end
@implementation UITabBarController (UIVerticalBar)
- (UIViewController *)childViewControllerForPreferredVerticalBarBehavior { return self.selectedViewController; }
@end
@implementation UITraitCollection (UIVerticalBar)
- (UIVerticalBarEdge)verticalBarEdge { return UIVerticalBarEdgeUnspecified; }
+ (NSArray<Class> *)systemTraitsAffectingVerticalBarEdge {
    return @[[UITraitHorizontalSizeClass class], [UITraitVerticalSizeClass class], [UITraitLayoutDirection class]];
}
@end

/* ================= layout regions ================= */
typedef NS_ENUM(NSInteger, IsimRegion) { RegionSafeArea, RegionMargins, RegionReadable, RegionBar };
@interface UIViewLayoutRegion () { @public IsimRegion _kind; UIViewLayoutRegionAdaptivityAxis _adapt; NSUInteger _edge; BOOL _directional; CGFloat _extent; }
@end
@implementation UIViewLayoutRegion
+ (instancetype)_isim:(IsimRegion)k adapt:(UIViewLayoutRegionAdaptivityAxis)a { UIViewLayoutRegion *r = [self new]; r->_kind = k; r->_adapt = a; return r; }
+ (UIViewLayoutRegion *)safeAreaLayoutRegionWithCornerAdaptation:(UIViewLayoutRegionAdaptivityAxis)a { return [self _isim:RegionSafeArea adapt:a]; }
+ (UIViewLayoutRegion *)marginsLayoutRegionWithCornerAdaptation:(UIViewLayoutRegionAdaptivityAxis)a { return [self _isim:RegionMargins adapt:a]; }
+ (UIViewLayoutRegion *)readableContentLayoutRegionWithCornerAdaptation:(UIViewLayoutRegionAdaptivityAxis)a { return [self _isim:RegionReadable adapt:a]; }
+ (UIViewLayoutRegion *)layoutRegionForBarOnEdge:(UIRectEdge)edge extent:(CGFloat)extent {
    UIViewLayoutRegion *r = [self _isim:RegionBar adapt:UIViewLayoutRegionAdaptivityAxisNone]; r->_edge = edge; r->_extent = extent; return r;
}
+ (UIViewLayoutRegion *)layoutRegionForBarOnDirectionalEdge:(NSDirectionalRectEdge)edge extent:(CGFloat)extent {
    UIViewLayoutRegion *r = [self _isim:RegionBar adapt:UIViewLayoutRegionAdaptivityAxisNone]; r->_edge = edge; r->_directional = YES; r->_extent = extent; return r;
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UIViewLayoutRegion *)o {
    return [o isKindOfClass:[UIViewLayoutRegion class]] && o->_kind == _kind && o->_adapt == _adapt && o->_edge == _edge && o->_directional == _directional && o->_extent == _extent;
}
- (NSUInteger)hash { return (NSUInteger)_kind * 1000003 + _adapt * 1009 + _edge * 31 + (_directional ? 7 : 0) + (NSUInteger)(_extent * 100); }
@end

static char kRegionGuides;
@implementation UIView (UIViewLayoutRegion)
/* the region's insets from the view's edges (left/top/right/bottom) */
- (UIEdgeInsets)edgeInsetsForLayoutRegion:(UIViewLayoutRegion *)r {
    if (!r) return UIEdgeInsetsZero;
    switch (r->_kind) {
        case RegionSafeArea: return self.safeAreaInsets;
        case RegionMargins: return self.layoutMargins;
        case RegionReadable: {
            CGRect f = self.readableContentGuide.layoutFrame, b = self.bounds;
            UIEdgeInsets m = self.layoutMargins;
            if (CGRectIsEmpty(f)) return m;
            return UIEdgeInsetsMake(m.top, CGRectGetMinX(f) - CGRectGetMinX(b), m.bottom, CGRectGetMaxX(b) - CGRectGetMaxX(f));
        }
        case RegionBar: {
            UIEdgeInsets s = self.safeAreaInsets; CGSize sz = self.bounds.size;
            BOOL rtl = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
            NSUInteger e = r->_edge;
            BOOL top = r->_directional ? (e & NSDirectionalRectEdgeTop) : (e & UIRectEdgeTop);
            BOOL bottom = r->_directional ? (e & NSDirectionalRectEdgeBottom) : (e & UIRectEdgeBottom);
            BOOL left = r->_directional ? (e & (rtl ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading)) : (e & UIRectEdgeLeft);
            BOOL right = r->_directional ? (e & (rtl ? NSDirectionalRectEdgeLeading : NSDirectionalRectEdgeTrailing)) : (e & UIRectEdgeRight);
            CGFloat x = r->_extent;
            if (left) return UIEdgeInsetsMake(s.top, s.left, s.bottom, fmax(0, sz.width - s.left - x));
            if (right) return UIEdgeInsetsMake(s.top, fmax(0, sz.width - s.right - x), s.bottom, s.right);
            if (top) return UIEdgeInsetsMake(s.top, s.left, fmax(0, sz.height - s.top - x), s.right);
            if (bottom) return UIEdgeInsetsMake(fmax(0, sz.height - s.bottom - x), s.left, s.bottom, s.right);
            return s;
        }
    }
    return UIEdgeInsetsZero;
}
- (NSDirectionalEdgeInsets)directionalEdgeInsetsForLayoutRegion:(UIViewLayoutRegion *)r {
    UIEdgeInsets i = [self edgeInsetsForLayoutRegion:r];
    BOOL rtl = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    return NSDirectionalEdgeInsetsMake(i.top, rtl ? i.right : i.left, i.bottom, rtl ? i.left : i.right);
}
- (UILayoutGuide *)layoutGuideForLayoutRegion:(UIViewLayoutRegion *)r {
    if (!r) return self.safeAreaLayoutGuide;
    switch (r->_kind) {
        case RegionSafeArea: return self.safeAreaLayoutGuide;
        case RegionMargins: return self.layoutMarginsGuide;
        case RegionReadable: return self.readableContentGuide;
        default: break;
    }
    NSMutableDictionary *guides = objc_getAssociatedObject(self, &kRegionGuides);
    if (!guides) { guides = [NSMutableDictionary dictionary]; objc_setAssociatedObject(self, &kRegionGuides, guides, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    UILayoutGuide *g = guides[r];
    if (g) return g;
    /* a bar strip along the edge of the safe area */
    g = [UILayoutGuide new];
    g.identifier = @"UIViewLayoutRegionBar";
    [self addLayoutGuide:g];
    UILayoutGuide *safe = self.safeAreaLayoutGuide;
    NSUInteger e = r->_edge; CGFloat x = r->_extent; BOOL d = r->_directional;
    NSMutableArray *cs = [NSMutableArray array];
    if (d ? (e & (NSDirectionalRectEdgeLeading | NSDirectionalRectEdgeTrailing)) : (e & (UIRectEdgeLeft | UIRectEdgeRight))) {
        [cs addObjectsFromArray:@[[g.topAnchor constraintEqualToAnchor:safe.topAnchor], [g.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor], [g.widthAnchor constraintEqualToConstant:x]]];
        if (d) [cs addObject:(e & NSDirectionalRectEdgeLeading) ? [g.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor] : [g.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor]];
        else [cs addObject:(e & UIRectEdgeLeft) ? [g.leftAnchor constraintEqualToAnchor:safe.leftAnchor] : [g.rightAnchor constraintEqualToAnchor:safe.rightAnchor]];
    } else {
        BOOL top = d ? (e & NSDirectionalRectEdgeTop) : (e & UIRectEdgeTop);
        [cs addObjectsFromArray:@[[g.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor], [g.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor], [g.heightAnchor constraintEqualToConstant:x],
                                  top ? [g.topAnchor constraintEqualToAnchor:safe.topAnchor] : [g.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor]]];
    }
    [NSLayoutConstraint activateConstraints:cs];
    guides[r] = g;
    return g;
}
@end

/* ================= reserved regions ================= */
@implementation UIViewReservedRegionKind { @public int _k; }
+ (instancetype)occlusionRegionKind { static UIViewReservedRegionKind *k; if (!k) { k = [self new]; k->_k = 1; } return k; }
+ (instancetype)divisionRegionKind { static UIViewReservedRegionKind *k; if (!k) { k = [self new]; k->_k = 2; } return k; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UIViewReservedRegionKind *)o { return [o isKindOfClass:[UIViewReservedRegionKind class]] && o->_k == _k; }
- (NSUInteger)hash { return (NSUInteger)_k; }
- (NSString *)description { return _k == 1 ? @"occlusion" : @"division"; }
@end
@implementation UIViewReservedRegionIdentifier { @public NSString *_name; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UIViewReservedRegionIdentifier *)o { return [o isKindOfClass:[UIViewReservedRegionIdentifier class]] && [o->_name isEqualToString:_name]; }
- (NSUInteger)hash { return _name.hash; }
- (NSString *)description { return _name; }
@end
@interface UIViewReservedRegion ()
@property (nonatomic, readwrite) CGRect frame;
@property (nonatomic, readwrite, getter=isActive) BOOL active;
@property (nonatomic, readwrite) UIViewReservedRegionKind *kind;
@property (nonatomic, readwrite) UIViewReservedRegionIdentifier *identifier;
@property (nonatomic, readwrite) UIEdgeInsets margins;
@end
@implementation UIViewReservedRegion
- (NSString *)description { return [NSString stringWithFormat:@"<UIViewReservedRegion %@ %@ %@%@>", _kind, _identifier, NSStringFromCGRect(_frame), _active ? @"" : @" inactive"]; }
@end

/* the sensor housing in screen points (as the shell draws it), or CGRectNull */
static CGRect housing_rect(NSString **name) {
    const struct isim_device *d = isim_ui_device();
    BOOL landscape = d->orientation == UIInterfaceOrientationLandscapeLeft || d->orientation == UIInterfaceOrientationLandscapeRight;
    BOOL left = d->orientation == UIInterfaceOrientationLandscapeRight;   /* the device's top edge points left */
    if (d->has_island == 1) {
        *name = @"dynamic-island";
        return landscape ? CGRectMake(left ? 11 : d->width - 11 - 37, d->height / 2 - 62.5, 37, 125) : CGRectMake(d->width / 2 - 62.5, 11, 125, 37);
    }
    if (d->has_island == 2) {
        *name = @"notch";
        return landscape ? CGRectMake(left ? 0 : d->width - 32, d->height / 2 - 81, 32, 162) : CGRectMake(d->width / 2 - 81, 0, 162, 32);
    }
    return CGRectNull;
}
@implementation UIView (UIViewReservedRegion)
- (NSArray<UIViewReservedRegion *> *)reservedRegionsOfKind:(UIViewReservedRegionKind *)kind { return [self reservedRegionsOfKind:kind options:UIViewReservedRegionQueryOptionsNone]; }
- (NSArray<UIViewReservedRegion *> *)reservedRegionsOfKind:(UIViewReservedRegionKind *)kind options:(UIViewReservedRegionQueryOptions)options {
    if (![kind isEqual:[UIViewReservedRegionKind occlusionRegionKind]]) return @[];      /* no hinge: no division */
    UIWindow *w = self.window;
    if (!w) return @[];
    if (w.screen && w.screen != UIScreen.mainScreen) return @[];                       /* another display */
    NSString *name = nil;
    CGRect screen = housing_rect(&name);
    if (CGRectIsNull(screen)) return @[];
    CGRect inWindow = CGRectOffset(screen, -w.frame.origin.x, -w.frame.origin.y);
    CGRect r = [self convertRect:inWindow fromView:w];
    if (!CGRectIntersectsRect(r, self.bounds)) return @[];
    UIViewReservedRegion *reg = [UIViewReservedRegion new];
    reg.frame = r; reg.active = YES; reg.kind = kind; reg.margins = UIEdgeInsetsZero;
    UIViewReservedRegionIdentifier *ident = [UIViewReservedRegionIdentifier new]; ident->_name = name;
    reg.identifier = ident;
    return @[reg];
}
@end
