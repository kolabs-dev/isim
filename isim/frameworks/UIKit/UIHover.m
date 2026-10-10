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
- (CGFloat)zOffset { extern double isim_ui_pencil_hover_z; return fmax(0, isim_ui_pencil_hover_z); }
- (CGFloat)altitudeAngle { extern double isim_ui_pencil_hover_z; return isim_ui_pencil_hover_z >= 0 ? 1.1 : M_PI / 2; }
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

/* ================= tooltips (iOS 15) ================= */
@implementation UIToolTipConfiguration
+ (instancetype)configurationWithToolTip:(NSString *)t { return [self configurationWithToolTip:t inRect:CGRectNull]; }
+ (instancetype)configurationWithToolTip:(NSString *)t inRect:(CGRect)r {
    UIToolTipConfiguration *c = [super new]; c->_toolTip = [t copy] ?: @""; c->_sourceRect = r; return c;
}
@end
@interface __IsimToolTipWindow : UIWindow
@end
@implementation __IsimToolTipWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
@end
static __IsimToolTipWindow *tooltip_window;
static __weak UIToolTipInteraction *tooltip_owner;
static void tooltip_hide(void) {
    if (!tooltip_window || tooltip_window.hidden) return;
    for (UIView *v in [tooltip_window.subviews copy]) [v removeFromSuperview];
    tooltip_window.hidden = YES; tooltip_owner = nil;
    isim_ui_set_needs_display();
}
/* a platter next to the pointer (below and to the right, kept on screen) */
static void tooltip_show(NSString *text, CGPoint screenPoint) {
    if (!tooltip_window) { tooltip_window = [[__IsimToolTipWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; tooltip_window.windowLevel = 16000000; tooltip_window.backgroundColor = UIColor.clearColor; }
    for (UIView *v in [tooltip_window.subviews copy]) [v removeFromSuperview];
    UIFont *f = [UIFont systemFontOfSize:13];
    CGSize ts = isim_ui_measure(text, f, 280, 0);
    CGSize sz = CGSizeMake(ceil(ts.width) + 16, ceil(ts.height) + 10), scr = UIScreen.mainScreen.bounds.size;
    CGFloat x = fmin(fmax(4, screenPoint.x + 8), scr.width - sz.width - 4), y = screenPoint.y + 20;
    if (y + sz.height > scr.height - 4) y = screenPoint.y - sz.height - 8;
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(x, y, sz.width, sz.height)];
    box.backgroundColor = UIColor.secondarySystemBackgroundColor; box.layer.cornerRadius = 6; box.layer.cornerCurve = kCACornerCurveContinuous;
    box.layer.borderWidth = 0.5; box.layer.borderColor = UIColor.separatorColor.CGColor;
    box.layer.shadowOpacity = 0.15; box.layer.shadowRadius = 6; box.layer.shadowOffset = CGSizeMake(0, 2);
    box.accessibilityIdentifier = @"isim-tooltip";
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(8, 5, ceil(ts.width), ceil(ts.height))];
    l.text = text; l.font = f; l.textColor = UIColor.labelColor; l.numberOfLines = 0;
    [box addSubview:l]; [tooltip_window addSubview:box];
    tooltip_window.hidden = NO;
    NSLog(@"isim: tooltip \"%@\"", text);
    isim_ui_set_needs_display();
}
@implementation UIToolTipInteraction { __weak UIView *_view; UIHoverGestureRecognizer *_hover; NSTimer *_timer; CGPoint _at; CGRect _shownRect; }
- (instancetype)init {
    if ((self = [super init])) { _enabled = YES; _hover = [[UIHoverGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_hovered:)]; _shownRect = CGRectNull; }
    return self;
}
- (instancetype)initWithDefaultToolTip:(NSString *)t { if ((self = [self init])) _defaultToolTip = [t copy]; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { if (_view) [_view removeGestureRecognizer:_hover]; [self _isim_cancel]; }
- (void)didMoveToView:(UIView *)v { _view = v; if (v) [v addGestureRecognizer:_hover]; }
- (void)setEnabled:(BOOL)e { _enabled = e; if (!e) [self _isim_cancel]; }
- (void)_isim_cancel { [_timer invalidate]; _timer = nil; if (tooltip_owner == self) tooltip_hide(); _shownRect = CGRectNull; }
- (UIToolTipConfiguration *)_isim_configurationAt:(CGPoint)p {
    id<UIToolTipInteractionDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(toolTipInteraction:configurationAtPoint:)]) return [d toolTipInteraction:self configurationAtPoint:p];
    return _defaultToolTip.length ? [UIToolTipConfiguration configurationWithToolTip:_defaultToolTip] : nil;
}
- (void)_isim_hovered:(UIHoverGestureRecognizer *)g {
    UIView *v = _view;
    if (!_enabled || !v || g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) { [self _isim_cancel]; return; }
    if (v.traitCollection.userInterfaceIdiom != UIUserInterfaceIdiomPad) return;      /* tooltips need a pointer */
    _at = [g locationInView:v];
    if (tooltip_owner == self) {                       /* shown: it stays while the pointer is in its rect */
        if (!CGRectIsNull(_shownRect) && !CGRectContainsPoint(_shownRect, _at)) [self _isim_cancel]; else return;
    }
    [_timer invalidate];
    __weak UIToolTipInteraction *ws = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.7 repeats:NO block:^(NSTimer *t) { [ws _isim_fire]; }];
}
- (void)_isim_fire {
    _timer = nil;
    UIView *v = _view;
    if (!v.window || !_enabled) return;
    UIToolTipConfiguration *c = [self _isim_configurationAt:_at];
    if (!c.toolTip.length) return;
    CGRect r = CGRectIsNull(c.sourceRect) ? v.bounds : c.sourceRect;
    if (!CGRectContainsPoint(r, _at)) return;
    _shownRect = r; tooltip_owner = self;
    CGPoint sp = [v convertPoint:_at toView:nil]; sp.x += v.window.frame.origin.x; sp.y += v.window.frame.origin.y;
    tooltip_show(c.toolTip, sp);
}
@end
static char k_tooltip;
@implementation UIControl (UIToolTip)
- (UIToolTipInteraction *)toolTipInteraction { return objc_getAssociatedObject(self, &k_tooltip); }
- (NSString *)toolTip { return self.toolTipInteraction.defaultToolTip; }
- (void)setToolTip:(NSString *)t {
    UIToolTipInteraction *i = self.toolTipInteraction;
    if (!i && t.length) { i = [[UIToolTipInteraction alloc] init]; objc_setAssociatedObject(self, &k_tooltip, i, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self addInteraction:i]; }
    i.defaultToolTip = t;
}
@end

/* ================= band selection (iOS 15) ================= */
@interface UIPanGestureRecognizer (IsimDown)
- (CGPoint)_isim_downPoint;
@end
@implementation UIBandSelectionInteraction { __weak UIView *_view; UIPanGestureRecognizer *_pan; void (^_handler)(UIBandSelectionInteraction *); CGPoint _start; UIView *_band; }
- (instancetype)initWithSelectionHandler:(void (^)(UIBandSelectionInteraction *))h {
    if ((self = [super init])) {
        _enabled = YES; _handler = [h copy]; _selectionRect = CGRectNull;
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_dragged:)];
        _pan.allowedTouchTypes = @[@(UITouchTypeIndirectPointer)];      /* pointer drags only */
        _pan.cancelsTouchesInView = NO;
    }
    return self;
}
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { if (_view) [_view removeGestureRecognizer:_pan]; }
- (void)didMoveToView:(UIView *)v { _view = v; if (v) [v addGestureRecognizer:_pan]; }
- (void)setEnabled:(BOOL)e { _enabled = e; _pan.enabled = e; }
- (void)_isim_report { if (_handler) _handler(self); }
- (void)_isim_dragged:(UIPanGestureRecognizer *)g {
    UIView *v = _view;
    if (!v) return;
    CGPoint p = [g locationInView:v];
    switch (g.state) {
    case UIGestureRecognizerStateBegan: {
        _start = [g.view convertPoint:[g _isim_downPoint] fromView:g.view.window];     /* where the pointer went down */
        _start = [g.view convertPoint:_start toView:v];
        if (_shouldBeginHandler && !_shouldBeginHandler(self, _start)) { g.enabled = NO; g.enabled = _enabled; return; }
        _initialModifierFlags = g.modifierFlags;
        _band = [[UIView alloc] initWithFrame:CGRectZero];
        _band.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.2];
        _band.layer.borderColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.7].CGColor; _band.layer.borderWidth = 1;
        _band.userInteractionEnabled = NO; _band.accessibilityIdentifier = @"isim-selection-band";
        [v addSubview:_band];
        _state = UIBandSelectionInteractionStateBegan;
        _selectionRect = CGRectMake(_start.x, _start.y, 0, 0); _band.frame = _selectionRect;
        [self _isim_report];
        break; }
    case UIGestureRecognizerStateChanged:
        if (_state == UIBandSelectionInteractionStatePossible) return;
        _state = UIBandSelectionInteractionStateSelecting;
        _selectionRect = CGRectStandardize(CGRectMake(_start.x, _start.y, p.x - _start.x, p.y - _start.y));
        _band.frame = _selectionRect;
        [self _isim_report];
        break;
    default:
        if (_state == UIBandSelectionInteractionStatePossible) return;
        if (g.state == UIGestureRecognizerStateEnded) _selectionRect = CGRectStandardize(CGRectMake(_start.x, _start.y, p.x - _start.x, p.y - _start.y));
        _state = UIBandSelectionInteractionStateEnded;
        [self _isim_report];
        [_band removeFromSuperview]; _band = nil;
        _state = UIBandSelectionInteractionStatePossible; _selectionRect = CGRectNull;
    }
    isim_ui_set_needs_display();
}
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
@implementation UIPointerShape { @public CGRect _rect; CGFloat _radius; int _kind; UIAxis _axis; }   /* kind 0 rounded rect, 1 beam, 2 path */
+ (instancetype)shapeWithPath:(UIBezierPath *)path { UIPointerShape *s = [self new]; s->_kind = 2; s->_rect = path.bounds; s->_radius = 4; return s; }
+ (instancetype)shapeWithRoundedRect:(CGRect)r { return [self shapeWithRoundedRect:r cornerRadius:8]; }
+ (instancetype)shapeWithRoundedRect:(CGRect)r cornerRadius:(CGFloat)c { UIPointerShape *s = [self new]; s->_rect = r; s->_radius = c; return s; }
+ (instancetype)beamWithPreferredLength:(CGFloat)l axis:(UIAxis)a { UIPointerShape *s = [self new]; s->_kind = 1; s->_axis = a; s->_rect = a == UIAxisHorizontal ? CGRectMake(0, 0, l, 2) : CGRectMake(0, 0, 2, l); return s; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
const UIPointerAccessoryPosition UIPointerAccessoryPositionTop = { 8, 0 }, UIPointerAccessoryPositionTopRight = { 8, M_PI / 4 },
    UIPointerAccessoryPositionRight = { 8, M_PI / 2 }, UIPointerAccessoryPositionBottomRight = { 8, 3 * M_PI / 4 }, UIPointerAccessoryPositionBottom = { 8, M_PI },
    UIPointerAccessoryPositionBottomLeft = { 8, 5 * M_PI / 4 }, UIPointerAccessoryPositionLeft = { 8, 3 * M_PI / 2 }, UIPointerAccessoryPositionTopLeft = { 8, 7 * M_PI / 4 };
@implementation UIPointerAccessory
+ (instancetype)accessoryWithShape:(UIPointerShape *)shape position:(UIPointerAccessoryPosition)p {
    UIPointerAccessory *a = [super new]; a->_shape = shape; a->_position = p; a->_orientationMatchesAngle = YES; return a;
}
+ (instancetype)arrowAccessoryWithPosition:(UIPointerAccessoryPosition)p {
    UIBezierPath *tri = [UIBezierPath bezierPath];
    [tri moveToPoint:CGPointMake(0, -4)]; [tri addLineToPoint:CGPointMake(5, 3)]; [tri addLineToPoint:CGPointMake(-5, 3)]; [tri closePath];
    return [self accessoryWithShape:[UIPointerShape shapeWithPath:tri] position:p];
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@interface UIPointerStyle ()
@property (nonatomic, strong) UIPointerEffect *isimEffect;
@property (nonatomic, strong) UIPointerShape *isimShape;
@property (nonatomic) UIAxis isimAxes;
@property (nonatomic) BOOL isimHidden;
@end
@implementation UIPointerStyle
- (instancetype)init { if ((self = [super init])) _accessories = @[]; return self; }
+ (instancetype)styleWithEffect:(UIPointerEffect *)e shape:(UIPointerShape *)s { UIPointerStyle *x = [self new]; x.isimEffect = e; x.isimShape = s; return x; }
+ (instancetype)styleWithShape:(UIPointerShape *)s constrainedAxes:(UIAxis)a { UIPointerStyle *x = [self new]; x.isimShape = s; x.isimAxes = a; return x; }
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

/* ================= UIPencilInteraction (simulated Apple Pencil) ================= */
double isim_ui_pencil_hover_z = -1;
static double pencil_hover_x, pencil_hover_y;
@interface UIPencilHoverPose () - (instancetype)initWithIsimLocation:(CGPoint)p z:(double)z; @end
@interface UIPencilInteractionTap () - (instancetype)initWithIsimPose:(UIPencilHoverPose *)p; @end
@interface UIPencilInteractionSqueeze () - (instancetype)initWithIsimPhase:(UIPencilInteractionPhase)ph pose:(UIPencilHoverPose *)p; @end
@implementation UIPencilHoverPose
- (instancetype)initWithIsimLocation:(CGPoint)p z:(double)z {
    if ((self = [super init])) { _location = p; _zOffset = z; _altitudeAngle = 1.1; _azimuthAngle = 0; _azimuthUnitVector = CGVectorMake(1, 0); }
    return self;
}
@end
@implementation UIPencilInteractionTap
- (instancetype)initWithIsimPose:(UIPencilHoverPose *)p { if ((self = [super init])) { _timestamp = isim_time(); _hoverPose = p; } return self; }
@end
@implementation UIPencilInteractionSqueeze
- (instancetype)initWithIsimPhase:(UIPencilInteractionPhase)ph pose:(UIPencilHoverPose *)p { if ((self = [super init])) { _timestamp = isim_time(); _phase = ph; _hoverPose = p; } return self; }
@end

static NSHashTable<UIPencilInteraction *> *pencil_interactions;
static NSInteger pencil_pref(NSString *key, NSInteger def) {
    extern NSDictionary *isim_global_preferences(void);
    NSNumber *n = isim_global_preferences()[key];
    return [n isKindOfClass:[NSNumber class]] ? n.integerValue : def;
}
@implementation UIPencilInteraction { __weak UIView *_view; }
/* Settings > Apple Pencil (the actions the user picked) */
+ (UIPencilPreferredAction)preferredTapAction { return (UIPencilPreferredAction)pencil_pref(@"PencilTapAction", UIPencilPreferredActionSwitchEraser); }
+ (UIPencilPreferredAction)preferredSqueezeAction { return (UIPencilPreferredAction)pencil_pref(@"PencilSqueezeAction", UIPencilPreferredActionShowContextualPalette); }
+ (BOOL)prefersPencilOnlyDrawing { return pencil_pref(@"PencilOnlyDrawing", 0) != 0; }
+ (BOOL)prefersHoverToolPreview { return pencil_pref(@"PencilHoverPreview", 1) != 0; }
- (instancetype)init { if ((self = [super init])) _enabled = YES; return self; }
- (instancetype)initWithDelegate:(id<UIPencilInteractionDelegate>)d { if ((self = [self init])) _delegate = d; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v {
    _view = v;
    if (!pencil_interactions) pencil_interactions = [NSHashTable weakObjectsHashTable];
    if (v) [pencil_interactions addObject:self]; else [pencil_interactions removeObject:self];
}
@end
static NSString *pencil_action_name(UIPencilPreferredAction a) {
    switch (a) {
    case UIPencilPreferredActionSwitchEraser: return @"switchEraser";
    case UIPencilPreferredActionSwitchPrevious: return @"switchPrevious";
    case UIPencilPreferredActionShowColorPalette: return @"showColorPalette";
    case UIPencilPreferredActionShowInkAttributes: return @"showInkAttributes";
    case UIPencilPreferredActionShowContextualPalette: return @"showContextualPalette";
    case UIPencilPreferredActionRunSystemShortcut: return @"runSystemShortcut";
    default: return @"ignore";
    }
}
/* script `pencil tap` / `pencil squeeze`: the enabled interactions on screen hear it, like iOS */
void isim_ui_pencil_command(NSString *what) {
    BOOL tap = [what isEqualToString:@"tap"];
    UIPencilHoverPose *pose = isim_ui_pencil_hover_z >= 0 ? [[UIPencilHoverPose alloc] initWithIsimLocation:CGPointMake(pencil_hover_x, pencil_hover_y) z:isim_ui_pencil_hover_z] : nil;
    NSUInteger n = 0;
    for (UIPencilInteraction *i in pencil_interactions.allObjects) {
        UIView *v = i.view;
        if (!i.enabled || !v.window || v.window.hidden) continue;
        id<UIPencilInteractionDelegate> d = i.delegate;
        n++;
        if (tap) {
            if ([d respondsToSelector:@selector(pencilInteraction:didReceiveTap:)]) [d pencilInteraction:i didReceiveTap:[[UIPencilInteractionTap alloc] initWithIsimPose:pose]];
            else if ([d respondsToSelector:@selector(pencilInteractionDidTap:)]) [d pencilInteractionDidTap:i];
        } else if ([d respondsToSelector:@selector(pencilInteraction:didReceiveSqueeze:)]) {
            [d pencilInteraction:i didReceiveSqueeze:[[UIPencilInteractionSqueeze alloc] initWithIsimPhase:UIPencilInteractionPhaseBegan pose:pose]];
            [d pencilInteraction:i didReceiveSqueeze:[[UIPencilInteractionSqueeze alloc] initWithIsimPhase:UIPencilInteractionPhaseEnded pose:pose]];
        }
    }
    NSLog(@"isim: Apple Pencil %@ (preferred action %@) to %lu interaction(s)", tap ? @"double-tap" : @"squeeze",
          pencil_action_name(tap ? UIPencilInteraction.preferredTapAction : UIPencilInteraction.preferredSqueezeAction), (unsigned long)n);
}

/* ================= the pointer (iPad) ================= */
static BOOL pointer_device(void) { return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad; }

/* a system window that draws the pointer above everything and never takes touches */
@interface __IsimPointerWindow : UIWindow
@property (nonatomic) CGPoint at;
@property (nonatomic) CGRect morph;          /* the pointer became this rounded rect (highlight effect); empty: a dot */
@property (nonatomic) CGRect shapeRect;      /* a custom shape (window coordinates; a beam is centred on the pointer) */
@property (nonatomic) CGFloat shapeRadius;
@property (nonatomic) int shapeKind;         /* -1 none (the dot), 0 rounded rect, 1 beam, 2 path */
@property (nonatomic, copy) NSArray<UIPointerAccessory *> *accessories;
@end
@implementation __IsimPointerWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    double c[4] = { 0.45, 0.45, 0.45, 0.45 };
    if (isim_ui_style() == UIUserInterfaceStyleDark) c[0] = c[1] = c[2] = 0.75;
    if (!CGRectIsEmpty(_morph)) return;          /* the highlight is drawn by the effect */
    if (_shapeKind == 1) {                       /* a beam: the I-beam over text */
        CGRect r = _shapeRect;
        isim_gfx_fill_rounded(_at.x - r.size.width / 2, _at.y - r.size.height / 2, r.size.width, r.size.height, 1, c);
    } else if (_shapeKind == 0 || _shapeKind == 2) {
        isim_gfx_fill_rounded(_shapeRect.origin.x, _shapeRect.origin.y, _shapeRect.size.width, _shapeRect.size.height, _shapeRadius, c);
    } else isim_gfx_fill_ellipse(_at.x - 9.5, _at.y - 9.5, 19, 19, c);
    /* accessories: small arrows just outside the pointer's shape, pointing away from it (drawn as chevrons: adapted) */
    double hw = 9.5, hh = 9.5;
    if (_shapeKind == 1) { hw = _shapeRect.size.width / 2; hh = _shapeRect.size.height / 2; }
    else if (_shapeKind == 0 || _shapeKind == 2) { hw = _shapeRect.size.width / 2; hh = _shapeRect.size.height / 2; }
    for (UIPointerAccessory *a in _accessories) {
        double ang = a.position.angle, dx = sin(ang), dy = -cos(ang);
        double ext = fabs(dx) * hw + fabs(dy) * hh, off = ext + a.position.offset;
        double ax = _at.x + dx * off, ay = _at.y + dy * off;
        isim_gfx_save(); isim_gfx_translate(ax, ay); isim_gfx_rotate(ang);
        for (int side = -1; side <= 1; side += 2) {               /* the two strokes of a chevron pointing "up" (away) */
            isim_gfx_save(); isim_gfx_rotate(side * M_PI / 4);
            isim_gfx_fill_rounded(-1.5, -1.5, 3, 7.5, 1.5, c);
            isim_gfx_restore();
        }
        isim_gfx_restore();
    }
}
@end

static __IsimPointerWindow *pointer_window;
static NSMutableSet<UIHoverGestureRecognizer *> *hovering;
static __weak UIPointerInteraction *cur_interaction;
static __weak UIView *cur_pointer_view;
static UIPointerRegion *cur_region;
static UIPointerStyle *cur_style;
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
    UIPointerStyle *cs = cur_style; UIView *cv = cur_pointer_view;
    if (cs.isimAxes && cv && cur_region) {                      /* constrainedAxes: the pointer stays on the region's centre line */
        CGRect rr = [cv convertRect:cur_region.rect toView:nil];
        if (cs.isimAxes & UIAxisHorizontal) pointer_window.at = CGPointMake(CGRectGetMidX(rr), p.y);
        if (cs.isimAxes & UIAxisVertical) pointer_window.at = CGPointMake(pointer_window.at.x, CGRectGetMidY(rr));
    }
    /* the deepest view with a pointer interaction (or a pointer-enabled button) */
    UIPointerInteraction *found = nil; UIView *target = nil;
    for (UIView *v = exited ? nil : hit; v && !target; v = v.superview) {
        for (id i in v.interactions) if ([i isKindOfClass:[UIPointerInteraction class]] && ((UIPointerInteraction *)i).enabled) { found = i; target = v; break; }
        if (!target && [v isKindOfClass:[UIButton class]] && ((UIButton *)v).pointerInteractionEnabled) target = v;
    }
    UIPointerRegion *region = nil;
    UIPointerStyle *style = nil;
    if (!target && !exited) {                                   /* editable text: the I-beam, as tall as a line of its font */
        for (UIView *v = hit; v; v = v.superview) {
            BOOL editable = ([v isKindOfClass:[UITextField class]] && ((UITextField *)v).enabled) || ([v isKindOfClass:[UITextView class]] && ((UITextView *)v).editable);
            if (!editable) continue;
            UIFont *f = [v respondsToSelector:@selector(font)] ? [(id)v font] : nil;
            target = v;
            region = [UIPointerRegion regionWithRect:v.bounds identifier:@"isim.text"];
            style = [UIPointerStyle styleWithShape:[UIPointerShape beamWithPreferredLength:ceil((f ?: [UIFont systemFontOfSize:17]).lineHeight) axis:UIAxisVertical] constrainedAxes:0];
            break;
        }
    }
    if (target && !style) {
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
        pointer_window.shapeKind = -1; pointer_window.accessories = @[];
        cur_interaction = found; cur_pointer_view = target; cur_region = region; cur_style = style;
        if (region) {
            id<UIPointerInteractionDelegate> d = found.delegate;
            if ([d respondsToSelector:@selector(pointerInteraction:willEnterRegion:animator:)]) {
                __IsimPointerAnimator *a = [__IsimPointerAnimator new];
                [d pointerInteraction:found willEnterRegion:region animator:a]; [a _run];
            }
            if (style.isimHidden) pointer_window.hidden = YES;
            else if (style.isimEffect && !style.isimShape) apply_effect(target, style);
            else if (style.isimEffect) apply_effect(target, style), pointer_window.morph = CGRectZero;   /* the effect, drawn with the given shape */
            if (style.isimShape) {
                UIPointerShape *sh = style.isimShape;
                pointer_window.shapeKind = sh->_kind; pointer_window.shapeRadius = sh->_radius;
                pointer_window.shapeRect = sh->_kind == 1 ? sh->_rect : [target convertRect:sh->_rect toView:nil];
                NSLog(@"isim: pointer shape %@", sh->_kind == 1 ? @"beam" : sh->_kind == 2 ? @"path" : @"rounded rect");
            }
            pointer_window.accessories = style.accessories ?: @[];
            NSLog(@"isim: pointer entered %@ region %@", NSStringFromClass([target class]), NSStringFromCGRect(region.rect));
        }
    }
    isim_ui_set_needs_display();
}

void isim_ui_hover(double x, double y, BOOL exited) {
    CGPoint p = CGPointMake(x, y);
    if (isim_ui_pencil_hover_z >= 0) { pencil_hover_x = x; pencil_hover_y = y; }
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
