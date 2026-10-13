/* The focus system (UIFocus.h): iPad keyboard navigation (iOS 15), adapted.
 *
 * Each iPad window has a focus system. Focus items are views whose canBecomeFocused is YES (custom views, text
 * fields, and the cells of table and collection views whose allowsFocus is on or whose delegate says they can),
 * shown, enabled for touches and on screen, in the topmost presented controller's view. They form focus groups: the
 * nearest focusGroupIdentifier (a view's or its view controller's), else the table or collection view they are in,
 * else the item alone. With a hardware keyboard Tab / Shift-Tab move to the next / previous group (to the item last
 * focused there, else the prioritized one, else the first in reading order) and the arrows to the nearest item in
 * that direction within the group; Return or Space presses the focused item (a cell is selected, a control sends its
 * primary action; other views get the presses, the focused view coming first in the responder chain). A focused
 * text field becomes the first responder; Tab in it moves focus on.
 *
 * An update asks shouldUpdateFocus(in:) of the environments around the old and the new item (and the table or
 * collection view's delegate), then calls didUpdateFocus(in:with:) on them with an animation coordinator and posts
 * UIFocusSystem.didUpdateNotification; a refused or impossible move posts movementDidFailNotification. The focused
 * item shows its focus effect (a halo in the tint colour by default). Programmatic focus (setNeedsFocusUpdate,
 * requestFocusUpdate) is deferred until the keyboard is used, unless the item's deferral mode is .never; a touch
 * hides the halo until the next key. */
#import "UIKitPrivate.h"
#import "UIKitInputPrivate.h"
#import <UIKit/UIFocus.h>
#import <objc/runtime.h>

NSNotificationName const UIFocusDidUpdateNotification = @"UIFocusDidUpdateNotification";
NSNotificationName const UIFocusMovementDidFailNotification = @"UIFocusMovementDidFailNotification";
NSString *const UIFocusUpdateContextKey = @"UIFocusUpdateContextKey";
NSString *const UIFocusUpdateAnimationCoordinatorKey = @"UIFocusUpdateAnimationCoordinatorKey";

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

@interface UIFocusSystem (IsimPrivate)
- (void)_isim_setNeedsUpdateFrom:(id<UIFocusEnvironment>)env;
- (NSArray<UIView *> *)_isim_itemsIn:(UIView *)root;
@end
@interface UITableView (IsimFocusPrivate)
- (void)_isim_cellTapped:(UITableViewCell *)c;
@end
@interface UICollectionView (IsimFocusPrivate)
- (void)_isim_cellTouched:(UICollectionViewCell *)c phase:(int)phase;
@end

/* ================= contexts, coordinators, hints ================= */
@interface UIFocusUpdateContext ()
@property (nonatomic, weak, readwrite) id<UIFocusItem> previouslyFocusedItem, nextFocusedItem;
@property (nonatomic, readwrite) UIFocusHeading focusHeading;
@end
@implementation UIFocusUpdateContext
- (UIView *)previouslyFocusedView { id i = self.previouslyFocusedItem; return [i isKindOfClass:[UIView class]] ? i : nil; }
- (UIView *)nextFocusedView { id i = self.nextFocusedItem; return [i isKindOfClass:[UIView class]] ? i : nil; }
@end
@interface UITableViewFocusUpdateContext ()
@property (nonatomic, strong, readwrite) NSIndexPath *previouslyFocusedIndexPath, *nextFocusedIndexPath;
@end
@implementation UITableViewFocusUpdateContext @end
@interface UICollectionViewFocusUpdateContext ()
@property (nonatomic, strong, readwrite) NSIndexPath *previouslyFocusedIndexPath, *nextFocusedIndexPath;
@end
@implementation UICollectionViewFocusUpdateContext @end

@interface __IsimFocusAnimationContext : NSObject <UIFocusAnimationContext>
@end
@implementation __IsimFocusAnimationContext
- (NSTimeInterval)duration { return 0.2; }
@end
@implementation UIFocusAnimationCoordinator { NSMutableArray *_anims, *_focusing, *_unfocusing, *_completions; }
- (instancetype)init { if ((self = [super init])) { _anims = [NSMutableArray array]; _focusing = [NSMutableArray array]; _unfocusing = [NSMutableArray array]; _completions = [NSMutableArray array]; } return self; }
- (void)addCoordinatedAnimations:(void (^)(void))a completion:(void (^)(void))c { if (a) [_anims addObject:[a copy]]; if (c) [_completions addObject:[c copy]]; }
- (void)addCoordinatedFocusingAnimations:(void (^)(id<UIFocusAnimationContext>))a completion:(void (^)(void))c { if (a) [_focusing addObject:[a copy]]; if (c) [_completions addObject:[c copy]]; }
- (void)addCoordinatedUnfocusingAnimations:(void (^)(id<UIFocusAnimationContext>))a completion:(void (^)(void))c { if (a) [_unfocusing addObject:[a copy]]; if (c) [_completions addObject:[c copy]]; }
- (void)_isim_run {
    NSArray *anims = [_anims copy], *focusing = [_focusing copy], *unfocusing = [_unfocusing copy], *done = [_completions copy];
    __IsimFocusAnimationContext *ctx = [__IsimFocusAnimationContext new];
    [UIView animateWithDuration:ctx.duration animations:^{
        for (void (^a)(void) in anims) a();
        for (void (^a)(id<UIFocusAnimationContext>) in unfocusing) a(ctx);
        for (void (^a)(id<UIFocusAnimationContext>) in focusing) a(ctx);
    } completion:^(BOOL f) { for (void (^c)(void) in done) c(); }];
}
@end

@implementation UIFocusMovementHint
- (id)copyWithZone:(NSZone *)z { return self; }
- (CGVector)movementDirection { return CGVectorMake(0, 0); }
- (CGVector)rotation { return CGVectorMake(0, 0); }
- (CGVector)translation { return CGVectorMake(0, 0); }
- (CATransform3D)perspectiveTransform { return CATransform3DIdentity; }
- (CATransform3D)interactionTransform { return CATransform3DIdentity; }
@end

/* ================= effects ================= */
@implementation UIFocusEffect
+ (instancetype)effect { return [self new]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UIFocusHaloEffect { @package CGRect _rect; CGFloat _radius; UIBezierPath *_path; BOOL _hasShape; }
+ (instancetype)effectWithRect:(CGRect)rect { UIFocusHaloEffect *e = [self new]; e->_rect = rect; e->_hasShape = YES; return e; }
+ (instancetype)effectWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)r curve:(CALayerCornerCurve)curve {
    UIFocusHaloEffect *e = [self effectWithRect:rect]; e->_radius = r; return e;
}
+ (instancetype)effectWithPath:(UIBezierPath *)p { UIFocusHaloEffect *e = [self new]; e->_path = [p copy]; e->_rect = p.bounds; e->_hasShape = YES; return e; }
- (id)copyWithZone:(NSZone *)z {
    UIFocusHaloEffect *e = [[self class] new]; e->_rect = _rect; e->_radius = _radius; e->_path = _path; e->_hasShape = _hasShape;
    e.containerView = self.containerView; e.referenceView = self.referenceView; e.position = self.position; return e;
}
@end

/* the halo: a ring in the tint colour around the shape (outside by default) */
@interface __IsimFocusHalo : UIView
@property (nonatomic, strong) UIBezierPath *shape;      /* in the halo's coordinates */
@property (nonatomic, strong) UIColor *ringColor;
@end
@implementation __IsimFocusHalo
- (void)drawRect:(CGRect)r {
    [self.ringColor setStroke];
    self.shape.lineWidth = 3.5;
    [self.shape stroke];
}
@end

/* ================= views, controllers, guides ================= */
static char kGroupIdentifier, kFocusEffect, kGuidePreferred, kGuideEnabled, kSystem, kTableFollows;
@implementation UIView (UIFocus)
- (BOOL)isFocused { UIFocusSystem *s = [UIFocusSystem focusSystemForEnvironment:self]; return s && s.focusedItem == (id)self; }
- (NSArray *)preferredFocusEnvironments { return @[]; }
- (id<UIFocusEnvironment>)parentFocusEnvironment {
    if ([self.nextResponder isKindOfClass:[UIViewController class]]) return (UIViewController *)self.nextResponder;
    return self.superview;
}
- (id<UIFocusItemContainer>)focusItemContainer { return self; }
- (id<UICoordinateSpace>)coordinateSpace { return self; }
- (NSString *)focusGroupIdentifier { return get(self, &kGroupIdentifier); }
- (void)setFocusGroupIdentifier:(NSString *)i { put(self, &kGroupIdentifier, [i copy]); }
- (UIFocusEffect *)focusEffect { return get(self, &kFocusEffect); }
- (void)setFocusEffect:(UIFocusEffect *)e { put(self, &kFocusEffect, [e copy]); }
- (void)setNeedsFocusUpdate { [[UIFocusSystem focusSystemForEnvironment:self] _isim_setNeedsUpdateFrom:self]; }
- (void)updateFocusIfNeeded { [[UIFocusSystem focusSystemForEnvironment:self] updateFocusIfNeeded]; }
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)c { return YES; }
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)c withAnimationCoordinator:(UIFocusAnimationCoordinator *)a {}
- (NSArray *)focusItemsInRect:(CGRect)rect {
    NSMutableArray *out = [NSMutableArray array];
    UIFocusSystem *s = [UIFocusSystem focusSystemForEnvironment:self];
    for (UIView *v in [s _isim_itemsIn:self]) if (CGRectIntersectsRect(rect, [v convertRect:v.bounds toView:self])) [out addObject:v];
    return out;
}
@end
@implementation UIViewController (UIFocus)
- (NSArray *)preferredFocusEnvironments { return self.isViewLoaded ? @[ self.view ] : @[]; }
- (id<UIFocusEnvironment>)parentFocusEnvironment { return self.isViewLoaded ? self.view.superview : nil; }
- (id<UIFocusItemContainer>)focusItemContainer { return self.isViewLoaded ? self.view : nil; }
- (void)setNeedsFocusUpdate { if (self.isViewLoaded) [[UIFocusSystem focusSystemForEnvironment:self] _isim_setNeedsUpdateFrom:self]; }
- (void)updateFocusIfNeeded { if (self.isViewLoaded) [[UIFocusSystem focusSystemForEnvironment:self] updateFocusIfNeeded]; }
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)c { return YES; }
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)c withAnimationCoordinator:(UIFocusAnimationCoordinator *)a {}
@end
@implementation UIScrollView (UIFocus)
- (CGSize)visibleSize { return self.bounds.size; }
@end
@implementation UIFocusGuide
- (BOOL)isEnabled { NSNumber *n = get(self, &kGuideEnabled); return n ? n.boolValue : YES; }
- (void)setEnabled:(BOOL)e { put(self, &kGuideEnabled, @(e)); }
- (NSArray *)preferredFocusEnvironments { return get(self, &kGuidePreferred) ?: @[]; }
- (void)setPreferredFocusEnvironments:(NSArray *)p { put(self, &kGuidePreferred, [p copy]); }
@end
@implementation UITableView (IsimFocusFollows)
- (BOOL)selectionFollowsFocus { return [get(self, &kTableFollows) boolValue]; }
- (void)setSelectionFollowsFocus:(BOOL)f { put(self, &kTableFollows, @(f)); }
@end

/* which list (table or collection view) a cell is in */
static UIScrollView *list_of(UIView *v) {
    for (UIView *s = v.superview; s; s = s.superview) if ([s isKindOfClass:[UITableView class]] || [s isKindOfClass:[UICollectionView class]]) return (UIScrollView *)s;
    return nil;
}
static NSIndexPath *index_of(UIView *cell, UIScrollView *list) {
    if ([list isKindOfClass:[UITableView class]] && [cell isKindOfClass:[UITableViewCell class]]) return [(UITableView *)list indexPathForCell:(UITableViewCell *)cell];
    if ([list isKindOfClass:[UICollectionView class]] && [cell isKindOfClass:[UICollectionViewCell class]]) return [(UICollectionView *)list indexPathForCell:(UICollectionViewCell *)cell];
    return nil;
}
@implementation UITableViewCell (IsimFocus)
- (BOOL)canBecomeFocused {
    UITableView *t = (UITableView *)list_of(self);
    NSIndexPath *ip = index_of(self, t);
    if (!t || !ip) return NO;
    id d = t.delegate;
    if ([d respondsToSelector:@selector(tableView:canFocusRowAtIndexPath:)]) return [d tableView:t canFocusRowAtIndexPath:ip];
    return t.allowsFocus;
}
@end
@implementation UICollectionViewCell (IsimFocus)
- (BOOL)canBecomeFocused {
    UICollectionView *c = (UICollectionView *)list_of(self);
    NSIndexPath *ip = index_of(self, c);
    if (!c || !ip) return NO;
    id d = c.delegate;
    if ([d respondsToSelector:@selector(collectionView:canFocusItemAtIndexPath:)]) return [d collectionView:c canFocusItemAtIndexPath:ip];
    return c.allowsFocus;
}
@end
@implementation UITextField (IsimFocus)
- (BOOL)canBecomeFocused { return self.enabled; }
@end

/* ================= the focus system ================= */
@interface UIFocusSystem ()
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, weak) id<UIFocusItem> focused, deferred;
@property (nonatomic, weak) id<UIFocusEnvironment> requested;
@property (nonatomic) BOOL needsUpdate, keyboardActive;
@property (nonatomic, strong) NSMapTable *lastInGroup;     /* group key -> the item last focused there */
@property (nonatomic, strong) __IsimFocusHalo *halo;
- (instancetype)initIsimWithWindow:(UIWindow *)w;
@end
static BOOL focus_supported(void) { return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad; }
static UIWindow *window_of(id env) {
    for (int i = 0; env && i < 200; i++) {
        if ([env isKindOfClass:[UIView class]]) return [env isKindOfClass:[UIWindow class]] ? env : ((UIView *)env).window;
        if ([env isKindOfClass:[UIViewController class]]) { UIViewController *vc = env; if (vc.isViewLoaded && vc.view.window) return vc.view.window; }
        if ([env isKindOfClass:[UILayoutGuide class]]) return ((UILayoutGuide *)env).owningView.window;
        env = [env respondsToSelector:@selector(parentFocusEnvironment)] ? [env parentFocusEnvironment] : nil;
    }
    return nil;
}
static NSString *describe(id item) {
    if (!item) return @"nothing";
    if ([item isKindOfClass:[UIView class]]) {
        UIView *v = item;
        NSString *n = v.accessibilityIdentifier ?: v.accessibilityLabel;
        return n.length ? [NSString stringWithFormat:@"%@ '%@'", NSStringFromClass(v.class), n] : NSStringFromClass(v.class);
    }
    return NSStringFromClass([item class]);
}
static NSString *heading_name(UIFocusHeading h) {
    switch (h) {
    case UIFocusHeadingUp: return @"up"; case UIFocusHeadingDown: return @"down"; case UIFocusHeadingLeft: return @"left"; case UIFocusHeadingRight: return @"right";
    case UIFocusHeadingNext: return @"next"; case UIFocusHeadingPrevious: return @"previous"; case UIFocusHeadingFirst: return @"first"; case UIFocusHeadingLast: return @"last";
    default: return @"none";
    }
}

@implementation UIFocusSystem
+ (UIFocusSystem *)focusSystemForEnvironment:(id<UIFocusEnvironment>)env {
    if (!focus_supported() || !env) return nil;
    UIWindow *w = window_of(env);
    if (!w) return nil;
    UIFocusSystem *s = get(w, &kSystem);
    if (!s) { s = [[UIFocusSystem alloc] initIsimWithWindow:w]; put(w, &kSystem, s); }
    return s;
}
- (instancetype)initIsimWithWindow:(UIWindow *)w {
    if ((self = [super init])) { _window = w; _lastInGroup = [NSMapTable strongToWeakObjectsMapTable]; }
    return self;
}
- (id<UIFocusItem>)focusedItem { return _focused; }
+ (BOOL)environment:(id<UIFocusEnvironment>)env containsEnvironment:(id<UIFocusEnvironment>)other {
    for (id e = other; e; e = [e parentFocusEnvironment]) if (e == env) return YES;
    return NO;
}
- (void)requestFocusUpdateToEnvironment:(id<UIFocusEnvironment>)env { _requested = env; [self _isim_schedule]; }
- (void)_isim_setNeedsUpdateFrom:(id<UIFocusEnvironment>)env {
    /* only an environment that holds focus (or any, while nothing is focused) can move it */
    id f = _focused;
    if (f && ![UIFocusSystem environment:env containsEnvironment:f]) return;
    if (!_requested) _requested = env;
    [self _isim_schedule];
}
- (void)_isim_schedule {
    if (_needsUpdate) return;
    _needsUpdate = YES;
    __weak UIFocusSystem *ws = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [ws updateFocusIfNeeded]; });
}
- (void)updateFocusIfNeeded {
    if (!_needsUpdate) return;
    _needsUpdate = NO;
    id env = _requested ?: (id)self.window.rootViewController;
    _requested = nil;
    UIView *next = [self _isim_resolve:env];
    if (!next) return;
    BOOL defer = !_keyboardActive && !([(id)next respondsToSelector:@selector(focusItemDeferralMode)] && [(id)next focusItemDeferralMode] == UIFocusItemDeferralModeNever);
    if (defer) { _deferred = (id)next; NSLog(@"isim: focus deferred to %@ until keyboard input", describe(next)); return; }
    [self _isim_moveTo:next heading:UIFocusHeadingNone];
}

/* ---- the items ---- */
- (UIView *)_isim_root {
    UIViewController *vc = self.window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc.isViewLoaded && vc.view.window ? vc.view : self.window;
}
static BOOL shown_in(UIView *v, UIWindow *w) {
    if (v.hidden || v.alpha < 0.01 || !v.userInteractionEnabled) return NO;
    CGRect r = [v convertRect:v.bounds toView:w];
    return CGRectIntersectsRect(CGRectInset(r, 1, 1), w.bounds);
}
static void gather(UIView *v, UIWindow *w, NSMutableArray *out) {
    if (v.hidden || v.alpha < 0.01 || !v.userInteractionEnabled || [v isKindOfClass:[__IsimFocusHalo class]]) return;
    if (v.canBecomeFocused && shown_in(v, w)) [out addObject:v];
    for (UIView *s in v.subviews) gather(s, w, out);
}
/* reading order: rows (8 pt bands) top to bottom, then leading to trailing */
static NSArray *reading_order(NSArray *views, UIWindow *w) {
    return [views sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGRect ra = [a convertRect:a.bounds toView:w], rb = [b convertRect:b.bounds toView:w];
        long ya = lround(ra.origin.y / 8), yb = lround(rb.origin.y / 8);
        if (ya != yb) return ya < yb ? NSOrderedAscending : NSOrderedDescending;
        if (ra.origin.x != rb.origin.x) return ra.origin.x < rb.origin.x ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
}
- (NSArray<UIView *> *)_isim_itemsIn:(UIView *)root {
    UIWindow *w = self.window;
    if (!w || !root) return @[];
    NSMutableArray *a = [NSMutableArray array];
    gather(root, w, a);
    return reading_order(a, w);
}
/* the item's focus group: the nearest focusGroupIdentifier, else its list, else itself */
static id group_of(UIView *item) {
    for (UIView *v = item; v; v = v.superview) {
        if (v.focusGroupIdentifier.length) return v.focusGroupIdentifier;
        if ([v.nextResponder isKindOfClass:[UIViewController class]] && ((UIViewController *)v.nextResponder).focusGroupIdentifier.length)
            return ((UIViewController *)v.nextResponder).focusGroupIdentifier;
    }
    UIScrollView *list = list_of(item);
    return list ?: item;
}
/* where focus goes in an environment: itself if it is an item, else its preferred environments, else its first item */
- (UIView *)_isim_resolve:(id)env {
    return [self _isim_resolve:env depth:0];
}
- (UIView *)_isim_resolve:(id)env depth:(int)depth {
    if (!env || depth > 32) return nil;
    UIWindow *w = self.window;
    if ([env isKindOfClass:[UIView class]] && [(UIView *)env canBecomeFocused] && shown_in(env, w) && ((UIView *)env).window == w) return env;
    if ([env isKindOfClass:[UITableView class]] || [env isKindOfClass:[UICollectionView class]]) {
        id d = [env delegate]; NSIndexPath *ip = nil;
        if ([env isKindOfClass:[UITableView class]] && [d respondsToSelector:@selector(indexPathForPreferredFocusedViewInTableView:)]) {
            ip = [d indexPathForPreferredFocusedViewInTableView:env];
            if (ip) { UIView *c = [(UITableView *)env cellForRowAtIndexPath:ip]; if (c.canBecomeFocused) return c; }
        } else if ([env isKindOfClass:[UICollectionView class]] && [d respondsToSelector:@selector(indexPathForPreferredFocusedViewInCollectionView:)]) {
            ip = [d indexPathForPreferredFocusedViewInCollectionView:env];
            if (ip) { UIView *c = [(UICollectionView *)env cellForItemAtIndexPath:ip]; if (c.canBecomeFocused) return c; }
        }
    }
    if ([env respondsToSelector:@selector(preferredFocusEnvironments)])
        for (id p in [env preferredFocusEnvironments]) { if (p == env) continue; UIView *r = [self _isim_resolve:p depth:depth + 1]; if (r) return r; }
    UIView *root = [env isKindOfClass:[UIView class]] ? env : [env isKindOfClass:[UIViewController class]] && [env isViewLoaded] ? [env view] : nil;
    if (!root) return nil;
    return [self _isim_entryOf:[self _isim_itemsIn:root]];
}
/* the item to focus among a group's items: the prioritized one (focusGroupPriority), else the first */
- (UIView *)_isim_entryOf:(NSArray<UIView *> *)items {
    UIView *best = items.firstObject;
    for (UIView *v in items) if (v.focusGroupPriority > best.focusGroupPriority) best = v;
    return best;
}

/* ---- moving ---- */
static NSArray *chain(id item) {
    NSMutableArray *a = [NSMutableArray array];
    for (id e = item; e && a.count < 200; e = [e parentFocusEnvironment]) [a addObject:e];
    return a;
}
- (BOOL)_isim_moveTo:(UIView *)next heading:(UIFocusHeading)heading {
    id prev = _focused;
    if ((id)next == prev) { [self _isim_placeHalo]; return YES; }
    UIScrollView *prevList = [prev isKindOfClass:[UIView class]] ? list_of(prev) : nil, *nextList = list_of(next);
    UIScrollView *list = nextList ?: prevList;
    UIFocusUpdateContext *ctx;
    if ([list isKindOfClass:[UITableView class]]) {
        UITableViewFocusUpdateContext *c = [UITableViewFocusUpdateContext new];
        if (prevList == list) c.previouslyFocusedIndexPath = index_of(prev, list);
        if (nextList == list) c.nextFocusedIndexPath = index_of(next, list);
        ctx = c;
    } else if ([list isKindOfClass:[UICollectionView class]]) {
        UICollectionViewFocusUpdateContext *c = [UICollectionViewFocusUpdateContext new];
        if (prevList == list) c.previouslyFocusedIndexPath = index_of(prev, list);
        if (nextList == list) c.nextFocusedIndexPath = index_of(next, list);
        ctx = c;
    } else ctx = [UIFocusUpdateContext new];
    ctx.previouslyFocusedItem = prev; ctx.nextFocusedItem = (id)next; ctx.focusHeading = heading;
    NSMutableOrderedSet *envs = [NSMutableOrderedSet orderedSetWithArray:chain(prev)];
    [envs addObjectsFromArray:chain(next)];
    for (id e in envs) {
        if (![e shouldUpdateFocusInContext:ctx]) { [self _isim_fail:ctx why:[NSString stringWithFormat:@"%@ refused", describe(e)]]; return NO; }
    }
    for (UIScrollView *l in [NSSet setWithObjects:prevList ?: list, nextList ?: list, nil]) {
        id d = l.delegate;
        if ([l isKindOfClass:[UITableView class]] && [ctx isKindOfClass:[UITableViewFocusUpdateContext class]] && [d respondsToSelector:@selector(tableView:shouldUpdateFocusInContext:)]
            && ![d tableView:(UITableView *)l shouldUpdateFocusInContext:(UITableViewFocusUpdateContext *)ctx]) { [self _isim_fail:ctx why:@"the table view's delegate refused"]; return NO; }
        if ([l isKindOfClass:[UICollectionView class]] && [ctx isKindOfClass:[UICollectionViewFocusUpdateContext class]] && [d respondsToSelector:@selector(collectionView:shouldUpdateFocusInContext:)]
            && ![d collectionView:(UICollectionView *)l shouldUpdateFocusInContext:(UICollectionViewFocusUpdateContext *)ctx]) { [self _isim_fail:ctx why:@"the collection view's delegate refused"]; return NO; }
    }
    _focused = (id)next; _deferred = nil;
    [_lastInGroup setObject:next forKey:group_of(next)];
    /* a focused text field edits; leaving one ends its editing */
    if ([prev isKindOfClass:[UITextField class]] && [prev isFirstResponder] && ![next isKindOfClass:[UITextField class]]) [prev resignFirstResponder];
    if ([next isKindOfClass:[UITextField class]] && !next.isFirstResponder) [next becomeFirstResponder];
    [self _isim_placeHalo];
    UIFocusAnimationCoordinator *coord = [UIFocusAnimationCoordinator new];
    for (id e in envs) [e didUpdateFocusInContext:ctx withAnimationCoordinator:coord];
    for (UIScrollView *l in [NSSet setWithObjects:prevList ?: list, nextList ?: list, nil]) {
        id d = l.delegate;
        if ([l isKindOfClass:[UITableView class]] && [ctx isKindOfClass:[UITableViewFocusUpdateContext class]] && [d respondsToSelector:@selector(tableView:didUpdateFocusInContext:withAnimationCoordinator:)])
            [d tableView:(UITableView *)l didUpdateFocusInContext:(UITableViewFocusUpdateContext *)ctx withAnimationCoordinator:coord];
        if ([l isKindOfClass:[UICollectionView class]] && [ctx isKindOfClass:[UICollectionViewFocusUpdateContext class]] && [d respondsToSelector:@selector(collectionView:didUpdateFocusInContext:withAnimationCoordinator:)])
            [d collectionView:(UICollectionView *)l didUpdateFocusInContext:(UICollectionViewFocusUpdateContext *)ctx withAnimationCoordinator:coord];
    }
    [coord _isim_run];
    [self _isim_selectionFollows:next];
    /* keep it on screen */
    if (nextList) [nextList scrollRectToVisible:[next convertRect:next.bounds toView:nextList] animated:YES];
    [NSNotificationCenter.defaultCenter postNotificationName:UIFocusDidUpdateNotification object:self
                                                    userInfo:@{ UIFocusUpdateContextKey: ctx, UIFocusUpdateAnimationCoordinatorKey: coord }];
    NSLog(@"isim: focus moved %@ to %@", heading_name(heading), describe(next));
    return YES;
}
- (void)_isim_fail:(UIFocusUpdateContext *)ctx why:(NSString *)why {
    [NSNotificationCenter.defaultCenter postNotificationName:UIFocusMovementDidFailNotification object:self userInfo:@{ UIFocusUpdateContextKey: ctx }];
    NSLog(@"isim: focus movement %@ failed (%@)", heading_name(ctx.focusHeading), why);
}
- (void)_isim_selectionFollows:(UIView *)item {
    UIScrollView *l = list_of(item);
    NSIndexPath *ip = index_of(item, l);
    if (!ip) return;
    id d = l.delegate;
    if ([l isKindOfClass:[UICollectionView class]]) {
        UICollectionView *c = (UICollectionView *)l;
        BOOL follows = [d respondsToSelector:@selector(collectionView:selectionFollowsFocusForItemAtIndexPath:)] ? [d collectionView:c selectionFollowsFocusForItemAtIndexPath:ip] : c.selectionFollowsFocus;
        if (follows && ![c.indexPathsForSelectedItems containsObject:ip]) { [c _isim_cellTouched:(UICollectionViewCell *)item phase:0]; [c _isim_cellTouched:(UICollectionViewCell *)item phase:1]; }
    } else {
        UITableView *t = (UITableView *)l;
        BOOL follows = [d respondsToSelector:@selector(tableView:selectionFollowsFocusForRowAtIndexPath:)] ? [d tableView:t selectionFollowsFocusForRowAtIndexPath:ip] : t.selectionFollowsFocus;
        if (follows && ![t.indexPathsForSelectedRows containsObject:ip]) [t _isim_cellTapped:(UITableViewCell *)item];
    }
}

/* ---- the halo ---- */
- (void)_isim_placeHalo {
    UIView *item = [(id)_focused isKindOfClass:[UIView class]] ? (UIView *)_focused : nil;
    if (!item || !_keyboardActive || !item.window) { [self.halo removeFromSuperview]; return; }
    UIFocusEffect *effect = item.focusEffect;
    if (effect && ![effect isKindOfClass:[UIFocusHaloEffect class]]) { [self.halo removeFromSuperview]; return; }    /* a plain UIFocusEffect: no halo */
    UIFocusHaloEffect *halo = (UIFocusHaloEffect *)effect;
    UIView *container = halo.containerView ?: item.superview, *reference = halo.referenceView ?: item;
    if (!container) return;
    CGRect shape = halo && halo->_hasShape ? halo->_rect : reference.bounds;
    CGFloat radius = halo ? halo->_radius : reference.layer.cornerRadius;
    BOOL inside = halo.position == UIFocusHaloEffectPositionInside;
    CGFloat out = inside ? -3 : 4;
    CGRect inContainer = CGRectInset([reference convertRect:shape toView:container], -out, -out);
    if (!self.halo) {
        self.halo = [__IsimFocusHalo new];
        self.halo.userInteractionEnabled = NO; self.halo.backgroundColor = UIColor.clearColor; self.halo.accessibilityIdentifier = @"isim-focus-halo";
    }
    __IsimFocusHalo *h = self.halo;
    h.frame = CGRectInset(inContainer, -2, -2);
    h.ringColor = item.tintColor ?: UIColor.systemBlueColor;
    CGRect ring = CGRectInset(h.bounds, 2, 2);
    if (halo && halo->_path) {
        UIBezierPath *p = [halo->_path copy];
        CGRect pb = [reference convertRect:p.bounds toView:h];
        [p applyTransform:CGAffineTransformMakeTranslation(pb.origin.x - p.bounds.origin.x, pb.origin.y - p.bounds.origin.y)];
        h.shape = p;
    } else h.shape = [UIBezierPath bezierPathWithRoundedRect:ring cornerRadius:radius > 0 ? radius + out : 0];
    if (h.superview != container) [container addSubview:h];
    if (container == item.superview) [container insertSubview:h aboveSubview:item]; else [container bringSubviewToFront:h];
    [h setNeedsDisplay];
}

/* ---- keyboard ---- */
- (NSArray<UIView *> *)_isim_items { return [self _isim_itemsIn:[self _isim_root]]; }
- (BOOL)_isim_key:(int)hid shift:(BOOL)shift {
    BOOL tab = hid == 0x2B, arrow = hid >= 0x4F && hid <= 0x52, press = hid == 0x28 || hid == 0x58 || hid == 0x2C;
    if (!tab && !arrow && !press) return NO;
    BOOL wasActive = _keyboardActive;
    _keyboardActive = YES;
    UIView *cur = [(id)_focused isKindOfClass:[UIView class]] ? (UIView *)_focused : nil;
    if (cur && (!cur.window || !shown_in(cur, self.window) || !cur.canBecomeFocused)) cur = nil, _focused = nil;
    if (press) {
        if (!cur) return NO;
        if (!wasActive) { [self _isim_placeHalo]; }
        return [self _isim_press:cur];
    }
    UIView *deferred = [(id)_deferred isKindOfClass:[UIView class]] ? (UIView *)_deferred : nil;
    if (!cur && deferred && deferred.window) { [self _isim_moveTo:deferred heading:UIFocusHeadingNone]; return YES; }
    if (cur && !wasActive) { [self _isim_placeHalo]; NSLog(@"isim: focus shown on %@", describe(cur)); return YES; }
    NSArray<UIView *> *items = [self _isim_items];
    if (!items.count) return NO;
    UIWindow *w = self.window;
    if (!cur) {
        if (!tab) return NO;                            /* nothing focused: Tab starts (the arrows still scroll) */
        UIView *first = [self _isim_resolve:self.window.rootViewController] ?: items.firstObject;
        if (tab && shift) first = [self _isim_groupEntry:group_of(items.lastObject) items:items];
        [self _isim_moveTo:first heading:tab ? (shift ? UIFocusHeadingPrevious : UIFocusHeadingNext) : UIFocusHeadingNone];
        return YES;
    }
    if (tab) {                                          /* the next / previous group */
        NSMutableArray *groups = [NSMutableArray array];
        for (UIView *v in items) { id g = group_of(v); if (![groups containsObject:g]) [groups addObject:g]; }
        NSUInteger gi = [groups indexOfObject:group_of(cur)];
        UIFocusHeading h = shift ? UIFocusHeadingPrevious : UIFocusHeadingNext;
        if (gi == NSNotFound) gi = 0;
        if (groups.count < 2) { [self _isim_fail:[self _isim_contextTo:nil heading:h] why:@"no other focus group"]; return YES; }
        id g = groups[shift ? (gi + groups.count - 1) % groups.count : (gi + 1) % groups.count];
        [self _isim_moveTo:[self _isim_groupEntry:g items:items] heading:h];
        return YES;
    }
    /* arrows: the nearest item in the direction, in the group */
    UIFocusHeading h = hid == 0x52 ? UIFocusHeadingUp : hid == 0x51 ? UIFocusHeadingDown : hid == 0x50 ? UIFocusHeadingLeft : UIFocusHeadingRight;
    id g = group_of(cur);
    CGRect cr = [cur convertRect:cur.bounds toView:w];
    CGPoint cc = CGPointMake(CGRectGetMidX(cr), CGRectGetMidY(cr));
    UIView *best = nil; UIFocusGuide *bestGuide = nil; double bestScore = INFINITY;
    /* the group's items, and the enabled focus guides (empty areas that send focus on) */
    NSMutableArray *cands = [NSMutableArray array];
    for (UIView *v in items) if (v != cur && [group_of(v) isEqual:g]) [cands addObject:v];
    [cands addObjectsFromArray:[self _isim_guidesIn:[self _isim_root]]];
    for (id cand in cands) {
        UIView *v = [cand isKindOfClass:[UIView class]] ? cand : nil;
        UIFocusGuide *guide = v ? nil : cand;
        CGRect r = v ? [v convertRect:v.bounds toView:w] : [guide.owningView convertRect:guide.layoutFrame toView:w];
        if (guide && CGRectContainsRect(r, cr)) continue;   /* a guide around the focused item */
        CGPoint c = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
        double along, across;
        switch (h) {
        case UIFocusHeadingUp: along = cr.origin.y - CGRectGetMaxY(r) + r.size.height / 2; across = fabs(c.x - cc.x); if (c.y >= cc.y - 1) continue; break;
        case UIFocusHeadingDown: along = r.origin.y - CGRectGetMaxY(cr) + r.size.height / 2; across = fabs(c.x - cc.x); if (c.y <= cc.y + 1) continue; break;
        case UIFocusHeadingLeft: along = cr.origin.x - CGRectGetMaxX(r) + r.size.width / 2; across = fabs(c.y - cc.y); if (c.x >= cc.x - 1) continue; break;
        default: along = r.origin.x - CGRectGetMaxX(cr) + r.size.width / 2; across = fabs(c.y - cc.y); if (c.x <= cc.x + 1) continue; break;
        }
        double score = fmax(along, 0) + 3 * across;
        if (score < bestScore) { bestScore = score; best = v; bestGuide = guide; }
    }
    if (bestGuide) {                                    /* a guide: where it sends focus */
        UIView *to = nil;
        for (id p in bestGuide.preferredFocusEnvironments) if ((to = [self _isim_resolve:p])) break;
        if (to && to != cur) { NSLog(@"isim: focus guide sends focus to %@", describe(to)); [self _isim_moveTo:to heading:h]; return YES; }
        best = nil;
    }
    if (!best) { [self _isim_fail:[self _isim_contextTo:nil heading:h] why:@"nothing there"]; return YES; }
    [self _isim_moveTo:best heading:h];
    return YES;
}
static void gather_guides(UIView *v, NSMutableArray *out) {
    if (v.hidden || v.alpha < 0.01) return;
    for (UILayoutGuide *g in v.layoutGuides)
        if ([g isKindOfClass:[UIFocusGuide class]] && ((UIFocusGuide *)g).enabled && ((UIFocusGuide *)g).preferredFocusEnvironments.count) [out addObject:g];
    for (UIView *s in v.subviews) gather_guides(s, out);
}
- (NSArray<UIFocusGuide *> *)_isim_guidesIn:(UIView *)root { NSMutableArray *a = [NSMutableArray array]; if (root) gather_guides(root, a); return a; }
- (UIFocusUpdateContext *)_isim_contextTo:(UIView *)next heading:(UIFocusHeading)h {
    UIFocusUpdateContext *c = [UIFocusUpdateContext new]; c.previouslyFocusedItem = _focused; c.nextFocusedItem = (id)next; c.focusHeading = h; return c;
}
- (UIView *)_isim_groupEntry:(id)g items:(NSArray<UIView *> *)items {
    NSMutableArray *in = [NSMutableArray array];
    for (UIView *v in items) if ([group_of(v) isEqual:g]) [in addObject:v];
    UIView *last = [_lastInGroup objectForKey:g];
    if (last && [in containsObject:last]) {
        /* a prioritized item wins over the remembered one */
        UIView *e = [self _isim_entryOf:in];
        return e.focusGroupPriority > UIFocusGroupPriorityPreviouslyFocused ? e : last;
    }
    return [self _isim_entryOf:in];
}
- (BOOL)_isim_press:(UIView *)item {
    UIScrollView *l = list_of(item);
    if ([item isKindOfClass:[UITableViewCell class]] && [l isKindOfClass:[UITableView class]]) { [(UITableView *)l _isim_cellTapped:(UITableViewCell *)item]; NSLog(@"isim: focus pressed %@", describe(item)); return YES; }
    if ([item isKindOfClass:[UICollectionViewCell class]] && [l isKindOfClass:[UICollectionView class]]) {
        [(UICollectionView *)l _isim_cellTouched:(UICollectionViewCell *)item phase:0]; [(UICollectionView *)l _isim_cellTouched:(UICollectionViewCell *)item phase:1];
        NSLog(@"isim: focus pressed %@", describe(item)); return YES;
    }
    if ([item isKindOfClass:[UIControl class]] && ![item isKindOfClass:[UITextField class]]) {
        [(UIControl *)item sendActionsForControlEvents:UIControlEventPrimaryActionTriggered | UIControlEventTouchUpInside];
        NSLog(@"isim: focus pressed %@", describe(item)); return YES;
    }
    return NO;                                          /* the presses go to the focused view */
}
- (void)_isim_touched { if (_keyboardActive) { _keyboardActive = NO; [self.halo removeFromSuperview]; } }
@end

/* ================= hooks ================= */
static UIFocusSystem *key_window_system(void) {
    UIWindow *w = UIApplication.sharedApplication.keyWindow;
    return w ? [UIFocusSystem focusSystemForEnvironment:w] : nil;
}
/* a hardware key (no Command / Control / Option): YES when focus took it */
BOOL isim_ui_focus_key(int hid, UIKeyModifierFlags mods) {
    if (mods & (UIKeyModifierCommand | UIKeyModifierControl | UIKeyModifierAlternate)) return NO;
    UIFocusSystem *s = key_window_system();
    if (!s) return NO;
    static BOOL hooked;
    if (!hooked) {
        hooked = YES;
        isim_ui_add_touch_filter(^BOOL(const struct isim_event *ev) {
            if (ev->type == ISIM_EV_TOUCH_DOWN) [key_window_system() _isim_touched];
            return NO;
        });
    }
    id fr = isim_ui_first_responder();
    if ([fr respondsToSelector:@selector(insertText:)]) {
        /* typing: only Tab leaves a text field (a text view keeps its tabs) */
        if (!(hid == 0x2B && [fr isKindOfClass:[UITextField class]])) return NO;
        if (s.focused != fr) s.focused = fr;
    }
    return [s _isim_key:hid shift:(mods & UIKeyModifierShift) != 0];
}
/* the focused view, first in the responder chain for presses when nothing is first responder */
UIView *isim_ui_focused_view(void) {
    UIFocusSystem *s = key_window_system();
    id f = s.focused;
    return s.keyboardActive && [f isKindOfClass:[UIView class]] && [f window] ? f : nil;
}

/* ================= the debugger ================= */
@interface __IsimFocusDebuggerOutput : NSObject <UIFocusDebuggerOutput>
@property (nonatomic, copy) NSString *text;
@end
@implementation __IsimFocusDebuggerOutput
- (NSString *)description { return self.text; }
- (NSString *)debugDescription { return self.text; }
@end
static id<UIFocusDebuggerOutput> output(NSString *text) { __IsimFocusDebuggerOutput *o = [__IsimFocusDebuggerOutput new]; o.text = text; return o; }
@implementation UIFocusDebugger
+ (id<UIFocusDebuggerOutput>)help {
    return output(@"UIFocusDebugger: status, checkFocusability(for:), simulateFocusUpdateRequest(from:), focusGroups(for:), preferredFocusEnvironments(for:)");
}
+ (id<UIFocusDebuggerOutput>)status {
    UIFocusSystem *s = key_window_system();
    if (!s) return output(@"No focus system: keyboard focus is an iPad feature.");
    return output([NSString stringWithFormat:@"Focused item: %@\nFocus shown: %@", describe(s.focused), s.keyboardActive ? @"yes" : @"no (waiting for keyboard input)"]);
}
+ (id<UIFocusDebuggerOutput>)checkFocusabilityForItem:(id<UIFocusItem>)item {
    NSMutableArray *issues = [NSMutableArray array];
    if (![item canBecomeFocused]) [issues addObject:@"canBecomeFocused is NO"];
    if ([(id)item isKindOfClass:[UIView class]]) {
        UIView *v = (UIView *)item;
        if (!v.window) [issues addObject:@"it is not in a window"];
        for (UIView *a = v; a; a = a.superview) {
            if (a.hidden) { [issues addObject:[NSString stringWithFormat:@"%@ is hidden", a == v ? @"it" : describe(a)]]; break; }
            if (a.alpha < 0.01) { [issues addObject:[NSString stringWithFormat:@"%@ is transparent (alpha 0)", a == v ? @"it" : describe(a)]]; break; }
            if (!a.userInteractionEnabled) { [issues addObject:[NSString stringWithFormat:@"%@ has user interaction disabled", a == v ? @"it" : describe(a)]]; break; }
        }
        if (v.window && !shown_in(v, v.window)) [issues addObject:@"it is off screen"];
    }
    if (![UIFocusSystem focusSystemForEnvironment:item]) [issues addObject:@"there is no focus system (iPhone)"];
    if (!issues.count) return output([NSString stringWithFormat:@"%@ is focusable.", describe(item)]);
    return output([NSString stringWithFormat:@"%@ is not focusable:\n- %@", describe(item), [issues componentsJoinedByString:@"\n- "]]);
}
+ (id<UIFocusDebuggerOutput>)simulateFocusUpdateRequestFromEnvironment:(id<UIFocusEnvironment>)env {
    UIFocusSystem *s = [UIFocusSystem focusSystemForEnvironment:env];
    if (!s) return output(@"No focus system: keyboard focus is an iPad feature.");
    UIView *v = [s _isim_resolve:env];
    return output([NSString stringWithFormat:@"A focus update from %@ would focus %@.", describe(env), describe(v)]);
}
+ (id<UIFocusDebuggerOutput>)focusGroupsForEnvironment:(id<UIFocusEnvironment>)env {
    UIFocusSystem *s = env ? [UIFocusSystem focusSystemForEnvironment:env] : key_window_system();
    if (!s) return output(@"No focus system: keyboard focus is an iPad feature.");
    UIView *root = [(id)env isKindOfClass:[UIView class]] ? (UIView *)env : [(id)env isKindOfClass:[UIViewController class]] ? ((UIViewController *)env).view : [s _isim_root];
    NSMutableArray *groups = [NSMutableArray array]; NSMutableDictionary *names = [NSMutableDictionary dictionary];
    NSMapTable *members = [NSMapTable strongToStrongObjectsMapTable];
    for (UIView *v in [s _isim_itemsIn:root]) {
        id g = group_of(v);
        if (![groups containsObject:g]) { [groups addObject:g]; [members setObject:[NSMutableArray array] forKey:g]; }
        [[members objectForKey:g] addObject:describe(v)];
    }
    NSMutableString *t = [NSMutableString stringWithFormat:@"%lu focus group(s):", (unsigned long)groups.count];
    for (id g in groups) {
        NSString *n = [g isKindOfClass:[NSString class]] ? [NSString stringWithFormat:@"'%@'", g] : describe(g);
        names[n] = @YES;
        [t appendFormat:@"\n%@: %@", n, [[members objectForKey:g] componentsJoinedByString:@", "]];
    }
    return output(t);
}
+ (id<UIFocusDebuggerOutput>)preferredFocusEnvironmentsForEnvironment:(id<UIFocusEnvironment>)env {
    NSMutableString *t = [NSMutableString stringWithFormat:@"Preferred focus environments of %@:", describe(env)];
    NSInteger n = 0;
    for (id p in env.preferredFocusEnvironments) [t appendFormat:@"\n%ld. %@", (long)++n, describe(p)];
    if (!n) [t appendString:@"\n(none: its first focusable item in reading order)"];
    return output(t);
}
@end
