/* Interactions on views (UIInteraction), pointer hover (UIHoverGestureRecognizer), iPad pointer effects
 * (UIPointerInteraction, UIButton.pointerInteractionEnabled) and UIPencilInteraction.
 * Hover comes from the host mouse moving without a button (or the script command `hover X Y` / `hover off`).
 * Hover recognizers work on every device; the pointer itself and its effects (highlight, lift, hover) exist on
 * iPad only, like iOS. Apple Pencil is not simulated: pencil interactions never get taps. */
#import "UIKitInputPrivate.h"
#import <objc/runtime.h>
#include <math.h>

@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@property (nonatomic) CGPoint startPoint, lastPoint;
- (void)_fire;
@end

/* ================= UIView interactions ================= */
static char k_interactions;
@implementation UIView (UIInteractions)
- (NSMutableArray *)_isim_interactionList {
    NSMutableArray *a = objc_getAssociatedObject(self, &k_interactions);
    if (!a) { a = [NSMutableArray array]; objc_setAssociatedObject(self, &k_interactions, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return a;
}
- (void)addInteraction:(id<UIInteraction>)i {
    if (!i || [[self _isim_interactionList] containsObject:i]) return;
    UIView *old = i.view;
    if (old && old != self) [old removeInteraction:i];
    [i willMoveToView:self];
    [[self _isim_interactionList] addObject:i];
    [i didMoveToView:self];
}
- (void)removeInteraction:(id<UIInteraction>)i {
    NSMutableArray *a = objc_getAssociatedObject(self, &k_interactions);
    if (![a containsObject:i]) return;
    [i willMoveToView:nil];
    [a removeObject:i];
    [i didMoveToView:nil];
}
- (NSArray *)interactions { return [objc_getAssociatedObject(self, &k_interactions) copy] ?: @[]; }
- (void)setInteractions:(NSArray *)list {
    for (id<UIInteraction> i in self.interactions) [self removeInteraction:i];
    for (id<UIInteraction> i in list) [self addInteraction:i];
}
@end

/* ================= UIHoverGestureRecognizer ================= */
@implementation UIHoverGestureRecognizer
- (CGFloat)zOffset { return 0; }
- (CGFloat)altitudeAngle { return M_PI / 2; }
- (CGFloat)azimuthAngleInView:(UIView *)v { return 0; }
- (CGPoint)locationInView:(UIView *)v { return [self.view.window convertPoint:self.lastPoint toView:v]; }
/* hover phases (the pointer entered, moved over, left the view) */
- (void)_isim_hoverAt:(CGPoint)windowPoint inside:(BOOL)inside {
    self.lastPoint = windowPoint;
    BOOL active = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged;
    if (inside && !active) {
        if (![self _isim_shouldBegin]) return;
        self.state = UIGestureRecognizerStateBegan; [self _fire];
    } else if (inside) { self.state = UIGestureRecognizerStateChanged; [self _fire]; }
    else if (active) { self.state = UIGestureRecognizerStateEnded; [self _fire]; self.state = UIGestureRecognizerStatePossible; }
}
/* touches don't drive a hover recognizer */
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {}
- (BOOL)_isim_acceptsExtraTouches { return NO; }
@end

/* ================= pointer types ================= */
@implementation UIPointerRegionRequest { CGPoint _loc; UIKeyModifierFlags _mods; }
- (instancetype)initWithIsimLocation:(CGPoint)p { if ((self = [super init])) _loc = p; return self; }
- (CGPoint)location { return _loc; }
- (UIKeyModifierFlags)modifiers { return _mods; }
@end
@implementation UIPointerRegion { CGRect _rect; id _ident; }
+ (instancetype)regionWithRect:(CGRect)r identifier:(id<NSObject>)i { UIPointerRegion *x = [self new]; x->_rect = r; x->_ident = i; return x; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (CGRect)rect { return _rect; }
- (id<NSObject>)identifier { return _ident; }
- (BOOL)_isim_sameAs:(UIPointerRegion *)o { return o && CGRectEqualToRect(_rect, o->_rect) && (_ident == o->_ident || [_ident isEqual:o->_ident]); }
@end
@implementation UIPointerEffect { UITargetedPreview *_preview; }
+ (instancetype)effectWithPreview:(UITargetedPreview *)p { UIPointerEffect *e = [self new]; e->_preview = p; return e; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (UITargetedPreview *)preview { return _preview; }
@end
@implementation UIPointerHighlightEffect @end
@implementation UIPointerLiftEffect @end
@implementation UIPointerHoverEffect @end
@implementation UIPointerShape { CGRect _rect; CGFloat _radius; int _kind; }
+ (instancetype)shapeWithPath:(UIBezierPath *)path { UIPointerShape *s = [self new]; s->_kind = 2; s->_rect = path.bounds; return s; }
+ (instancetype)shapeWithRoundedRect:(CGRect)r { return [self shapeWithRoundedRect:r cornerRadius:8]; }
+ (instancetype)shapeWithRoundedRect:(CGRect)r cornerRadius:(CGFloat)c { UIPointerShape *s = [self new]; s->_rect = r; s->_radius = c; return s; }
+ (instancetype)beamWithPreferredLength:(CGFloat)l axis:(UIAxis)a { UIPointerShape *s = [self new]; s->_kind = 1; s->_rect = a == UIAxisHorizontal ? CGRectMake(0, 0, l, 2) : CGRectMake(0, 0, 2, l); return s; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@interface UIPointerStyle ()
@property (nonatomic, strong) UIPointerEffect *isimEffect;
@property (nonatomic) BOOL isimHidden;
@end
@implementation UIPointerStyle
+ (instancetype)styleWithEffect:(UIPointerEffect *)e shape:(UIPointerShape *)s { UIPointerStyle *x = [self new]; x.isimEffect = e; return x; }
+ (instancetype)styleWithShape:(UIPointerShape *)s constrainedAxes:(UIAxis)a { return [self new]; }
+ (instancetype)hiddenPointerStyle { UIPointerStyle *x = [self new]; x.isimHidden = YES; return x; }
+ (instancetype)systemPointerStyle { return [self new]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@interface __IsimPointerAnimator : NSObject <UIPointerInteractionAnimating>
@property (nonatomic, strong) NSMutableArray *animations, *completions;
@end
@implementation __IsimPointerAnimator
- (instancetype)init { if ((self = [super init])) { _animations = [NSMutableArray array]; _completions = [NSMutableArray array]; } return self; }
- (void)addAnimations:(void (^)(void))a { if (a) [_animations addObject:[a copy]]; }
- (void)addCompletion:(void (^)(BOOL))c { if (c) [_completions addObject:[c copy]]; }
- (void)_run {
    NSArray *as = _animations, *cs = _completions;
    if (!as.count && !cs.count) return;
    [UIView animateWithDuration:0.2 animations:^{ for (void (^a)(void) in as) a(); } completion:^(BOOL f) { for (void (^c)(BOOL) in cs) c(f); }];
}
@end

@implementation UIPointerInteraction { __weak UIView *_view; __weak id<UIPointerInteractionDelegate> _delegate; }
- (instancetype)initWithDelegate:(id<UIPointerInteractionDelegate>)d { if ((self = [super init])) { _delegate = d; _enabled = YES; } return self; }
- (id<UIPointerInteractionDelegate>)delegate { return _delegate; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v { _view = v; }
- (void)invalidate { isim_ui_set_needs_display(); }
@end

static char k_button_pointer;
@implementation UIButton (UIPointer)
- (BOOL)isPointerInteractionEnabled { return [objc_getAssociatedObject(self, &k_button_pointer) boolValue]; }
- (void)setPointerInteractionEnabled:(BOOL)e { objc_setAssociatedObject(self, &k_button_pointer, @(e), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

/* ================= UIPencilInteraction (no pencil) ================= */
@implementation UIPencilInteraction { __weak UIView *_view; }
+ (UIPencilPreferredAction)preferredTapAction { return UIPencilPreferredActionSwitchEraser; }
+ (UIPencilPreferredAction)preferredSqueezeAction { return UIPencilPreferredActionShowContextualPalette; }
+ (BOOL)prefersPencilOnlyDrawing { return NO; }
+ (BOOL)prefersHoverToolPreview { return NO; }
- (instancetype)init { if ((self = [super init])) _enabled = YES; return self; }
- (instancetype)initWithDelegate:(id<UIPencilInteractionDelegate>)d { if ((self = [self init])) _delegate = d; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v { _view = v; }
@end

/* ================= the pointer (iPad) ================= */
static BOOL pointer_device(void) { return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad; }

/* a system window that draws the pointer above everything and never takes touches */
@interface __IsimPointerWindow : UIWindow
@property (nonatomic) CGPoint at;
@property (nonatomic) CGRect morph;          /* the pointer became this rounded rect (highlight effect); empty: a dot */
@end
@implementation __IsimPointerWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    double c[4] = { 0.45, 0.45, 0.45, 0.45 };
    if (isim_ui_style() == UIUserInterfaceStyleDark) c[0] = c[1] = c[2] = 0.75;
    if (!CGRectIsEmpty(_morph)) return;          /* the highlight is drawn by the effect */
    isim_gfx_fill_ellipse(_at.x - 9.5, _at.y - 9.5, 19, 19, c);
}
@end

static __IsimPointerWindow *pointer_window;
static NSMutableSet<UIHoverGestureRecognizer *> *hovering;
static __weak UIPointerInteraction *cur_interaction;
static __weak UIView *cur_pointer_view;
static UIPointerRegion *cur_region;
static UIView *highlight_view;            /* highlight effect: a platter behind the target */
static CGAffineTransform lifted_from;
static __weak UIView *lifted_view;

static UIWindow *hover_window(CGPoint p, UIView **hit) {
    NSArray *ws = [UIApplication.sharedApplication.windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
        return a.windowLevel > b.windowLevel ? NSOrderedAscending : a.windowLevel < b.windowLevel ? NSOrderedDescending : NSOrderedSame; }];
    for (UIWindow *w in ws) {
        if (w.hidden || w == pointer_window || !CGRectContainsPoint(w.frame, p)) continue;
        UIView *h = [w hitTest:CGPointMake(p.x - w.frame.origin.x, p.y - w.frame.origin.y) withEvent:nil];
        if (h) { *hit = h; return w; }
    }
    *hit = nil;
    return nil;
}

static void clear_effect(void) {
    [highlight_view removeFromSuperview]; highlight_view = nil;
    UIView *l = lifted_view;
    if (l) { l.transform = lifted_from; l.layer.shadowOpacity = 0; lifted_view = nil; }
    pointer_window.morph = CGRectZero;
}
static void apply_effect(UIView *target, UIPointerStyle *style) {
    clear_effect();
    UIPointerEffect *e = style.isimEffect;
    UIView *v = e.preview.view ?: target;
    if (!v.superview) return;
    if ([e isKindOfClass:[UIPointerLiftEffect class]]) {
        lifted_view = v; lifted_from = v.transform;
        v.transform = CGAffineTransformScale(lifted_from, 1.08, 1.08);
        v.layer.shadowColor = UIColor.blackColor.CGColor; v.layer.shadowOpacity = 0.25; v.layer.shadowRadius = 8; v.layer.shadowOffset = CGSizeMake(0, 4);
    } else if ([e isKindOfClass:[UIPointerHoverEffect class]]) {
        lifted_view = v; lifted_from = v.transform;
        if (((UIPointerHoverEffect *)e).prefersScaledContent) v.transform = CGAffineTransformScale(lifted_from, 1.04, 1.04);
        highlight_view = [[UIView alloc] initWithFrame:CGRectInset(v.frame, -4, -4)];
        highlight_view.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.08];
        highlight_view.layer.cornerRadius = 8; highlight_view.userInteractionEnabled = NO;
        [v.superview insertSubview:highlight_view aboveSubview:v];
    } else {                                     /* highlight (the default for buttons): the pointer morphs into a platter */
        highlight_view = [[UIView alloc] initWithFrame:CGRectInset(v.frame, -6, -4)];
        highlight_view.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.12];
        highlight_view.layer.cornerRadius = 10; highlight_view.userInteractionEnabled = NO;
        [v.superview insertSubview:highlight_view belowSubview:v];
        pointer_window.morph = [v convertRect:v.bounds toView:nil];
    }
    highlight_view.accessibilityIdentifier = @"isim-pointer-effect";
}

static void update_pointer(CGPoint p, UIView *hit, BOOL exited) {
    if (!pointer_device()) return;
    if (!pointer_window) {
        pointer_window = [[__IsimPointerWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        pointer_window.windowLevel = 20000000;
        pointer_window.backgroundColor = UIColor.clearColor;
        pointer_window.userInteractionEnabled = NO;
    }
    pointer_window.frame = UIScreen.mainScreen.bounds;
    pointer_window.hidden = exited;
    pointer_window.at = p;
    /* the deepest view with a pointer interaction (or a pointer-enabled button) */
    UIPointerInteraction *found = nil; UIView *target = nil;
    for (UIView *v = exited ? nil : hit; v && !target; v = v.superview) {
        for (id i in v.interactions) if ([i isKindOfClass:[UIPointerInteraction class]] && ((UIPointerInteraction *)i).enabled) { found = i; target = v; break; }
        if (!target && [v isKindOfClass:[UIButton class]] && ((UIButton *)v).pointerInteractionEnabled) target = v;
    }
    UIPointerRegion *region = nil;
    UIPointerStyle *style = nil;
    if (target) {
        CGPoint local = [target convertPoint:p fromView:nil];
        UIPointerRegion *def = [UIPointerRegion regionWithRect:target.bounds identifier:nil];
        id<UIPointerInteractionDelegate> d = found.delegate;
        region = def;
        if ([d respondsToSelector:@selector(pointerInteraction:regionForRequest:defaultRegion:)])
            region = [d pointerInteraction:found regionForRequest:[[UIPointerRegionRequest alloc] initWithIsimLocation:local] defaultRegion:def];
        if (region && [d respondsToSelector:@selector(pointerInteraction:styleForRegion:)]) style = [d pointerInteraction:found styleForRegion:region];
        if (region && !style) style = [UIPointerStyle styleWithEffect:[UIPointerHighlightEffect effectWithPreview:[[UITargetedPreview alloc] initWithView:target]] shape:nil];
    }
    BOOL same = target == cur_pointer_view && ((!region && !cur_region) || [region _isim_sameAs:cur_region]);
    if (!same) {
        UIPointerInteraction *oldI = cur_interaction;
        id<UIPointerInteractionDelegate> od = oldI.delegate;
        if (cur_region && [od respondsToSelector:@selector(pointerInteraction:willExitRegion:animator:)]) {
            __IsimPointerAnimator *a = [__IsimPointerAnimator new];
            [od pointerInteraction:oldI willExitRegion:cur_region animator:a]; [a _run];
        }
        clear_effect();
        cur_interaction = found; cur_pointer_view = target; cur_region = region;
        if (region) {
            id<UIPointerInteractionDelegate> d = found.delegate;
            if ([d respondsToSelector:@selector(pointerInteraction:willEnterRegion:animator:)]) {
                __IsimPointerAnimator *a = [__IsimPointerAnimator new];
                [d pointerInteraction:found willEnterRegion:region animator:a]; [a _run];
            }
            if (style.isimHidden) pointer_window.hidden = YES;
            else if (style.isimEffect) apply_effect(target, style);
            NSLog(@"isim: pointer entered %@ region %@", NSStringFromClass([target class]), NSStringFromCGRect(region.rect));
        }
    }
    isim_ui_set_needs_display();
}

void isim_ui_hover(double x, double y, BOOL exited) {
    CGPoint p = CGPointMake(x, y);
    UIView *hit = nil;
    UIWindow *w = exited ? nil : hover_window(p, &hit);
    NSMutableSet *now = [NSMutableSet set];
    for (UIView *v = hit; v; v = v.superview)
        for (UIGestureRecognizer *g in v.gestureRecognizers)
            if ([g isKindOfClass:[UIHoverGestureRecognizer class]] && g.enabled) [now addObject:g];
    if (!hovering) hovering = [NSMutableSet set];
    CGPoint wp = w ? CGPointMake(p.x - w.frame.origin.x, p.y - w.frame.origin.y) : p;
    for (UIHoverGestureRecognizer *g in [hovering copy]) if (![now containsObject:g]) { [g _isim_hoverAt:wp inside:NO]; [hovering removeObject:g]; }
    for (UIHoverGestureRecognizer *g in now) { [g _isim_hoverAt:wp inside:YES]; [hovering addObject:g]; }
    update_pointer(p, hit, exited);
}
