/* isim UIKit: UIResponder, UIView, layout guides, NSLayoutConstraint/anchors and a small
 * constraint resolver (ARC).
 *
 * Auto Layout: a Cassowary solver (Cassowary.c) per window; see "Auto Layout engine" below. */
#import "UIKitPrivate.h"
#include "Cassowary.h"
#include <math.h>

const CGFloat UIViewNoIntrinsicMetric = -1;
const CGSize UILayoutFittingCompressedSize = { 0, 0 };
const CGSize UILayoutFittingExpandedSize = { 10000, 10000 };

/* ================= UIResponder ================= */
@implementation UIResponder
- (UIResponder *)nextResponder { return nil; }
- (BOOL)canBecomeFirstResponder { return NO; }
- (BOOL)canResignFirstResponder { return YES; }
static __weak UIResponder *first_responder;
UIResponder *isim_ui_first_responder(void) { return first_responder; }
- (BOOL)isFirstResponder { return first_responder == self; }
- (BOOL)becomeFirstResponder {
    if (first_responder == self) return YES;
    if (!self.canBecomeFirstResponder) return NO;
    UIResponder *old = first_responder;
    if (old && ![old resignFirstResponder]) return NO;
    first_responder = self;
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimFirstResponderDidChange" object:self];
    return YES;
}
- (BOOL)resignFirstResponder {
    if (first_responder == self) {
        first_responder = nil;
        [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimFirstResponderDidChange" object:nil];
    }
    return YES;
}
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { [self.nextResponder touchesBegan:t withEvent:e]; }
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e { [self.nextResponder touchesMoved:t withEvent:e]; }
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self.nextResponder touchesEnded:t withEvent:e]; }
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { [self.nextResponder touchesCancelled:t withEvent:e]; }
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender { return [self respondsToSelector:action]; }
@end

/* ================= anchors & constraints ================= */
@interface NSLayoutAnchor ()
@property (nonatomic, weak) id item;
@property (nonatomic) NSLayoutAttribute attr;
+ (instancetype)_item:(id)item attr:(NSLayoutAttribute)a;
@end

@interface NSLayoutConstraint ()
@property (nullable, readwrite, weak) id firstItem, secondItem;
@property (readwrite) NSLayoutAttribute firstAttribute, secondAttribute;
@property (readwrite) NSLayoutRelation relation;
@property (readwrite) CGFloat multiplier;
@end

static NSMutableArray<NSLayoutConstraint *> *active_constraints;
static BOOL al_applying, al_tamic_moved;
void isim_ui_constraints_changed(void);
static void relayout_item(id item) {
    isim_ui_constraints_changed();
    if ([item isKindOfClass:[UIView class]]) { UIView *v = item; [v.superview setNeedsLayout]; [v setNeedsLayout]; if ([v.superview isKindOfClass:[UIStackView class]]) [v.superview.superview setNeedsLayout]; }
    else if ([item isKindOfClass:[UILayoutGuide class]]) [[item owningView] setNeedsLayout];
}

@implementation NSLayoutConstraint
+ (instancetype)constraintWithItem:(id)v1 attribute:(NSLayoutAttribute)a1 relatedBy:(NSLayoutRelation)rel toItem:(id)v2 attribute:(NSLayoutAttribute)a2 multiplier:(CGFloat)m constant:(CGFloat)c {
    NSLayoutConstraint *k = [self new];
    k.firstItem = v1; k.firstAttribute = a1; k.relation = rel; k.secondItem = v2; k.secondAttribute = v2 ? a2 : NSLayoutAttributeNotAnAttribute;
    k.multiplier = m; k.constant = c; k.priority = UILayoutPriorityRequired;
    return k;
}
+ (NSArray *)_isim_active { return active_constraints ?: @[]; }
+ (void)activateConstraints:(NSArray *)cs { for (NSLayoutConstraint *c in cs) c.active = YES; }
+ (void)deactivateConstraints:(NSArray *)cs { for (NSLayoutConstraint *c in cs) c.active = NO; }
- (void)setActive:(BOOL)active {
    if (active == _active) return;
    _active = active;
    if (!active_constraints) active_constraints = [NSMutableArray array];
    if (active) [active_constraints addObject:self]; else [active_constraints removeObjectIdenticalTo:self];
    relayout_item(self.firstItem); relayout_item(self.secondItem);
}
- (void)setPriority:(UILayoutPriority)p { if (p == _priority) return; _priority = p; if (_active) isim_ui_constraints_changed(); }
- (void)setConstant:(CGFloat)c { if (c == _constant) return; _constant = c; if (_active) { relayout_item(self.firstItem); relayout_item(self.secondItem); } }
- (NSLayoutAnchor *)firstAnchor { return [NSLayoutAnchor _item:self.firstItem attr:self.firstAttribute]; }
- (NSLayoutAnchor *)secondAnchor { return self.secondItem ? [NSLayoutAnchor _item:self.secondItem attr:self.secondAttribute] : nil; }
- (NSString *)description {
    return [NSString stringWithFormat:@"<NSLayoutConstraint:%p %@.%ld %s %@.%ld x%g %+g>", self, [self.firstItem class], (long)self.firstAttribute,
            self.relation == 0 ? "==" : self.relation > 0 ? ">=" : "<=", self.secondItem ? [self.secondItem class] : nil, (long)self.secondAttribute, self.multiplier, self.constant];
}
@end

@implementation NSLayoutAnchor
+ (instancetype)_item:(id)item attr:(NSLayoutAttribute)a { NSLayoutAnchor *x = [self new]; x.item = item; x.attr = a; return x; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)name { return [NSString stringWithFormat:@"%@.%ld", [self.item class], (long)self.attr]; }
- (NSLayoutConstraint *)_rel:(NSLayoutRelation)r to:(NSLayoutAnchor *)o m:(CGFloat)m c:(CGFloat)c {
    return [NSLayoutConstraint constraintWithItem:self.item attribute:self.attr relatedBy:r toItem:o.item attribute:o ? o.attr : NSLayoutAttributeNotAnAttribute multiplier:m constant:c];
}
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)a { return [self _rel:0 to:a m:1 c:0]; }
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)a { return [self _rel:1 to:a m:1 c:0]; }
- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)a { return [self _rel:-1 to:a m:1 c:0]; }
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)a constant:(CGFloat)c { return [self _rel:0 to:a m:1 c:c]; }
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)a constant:(CGFloat)c { return [self _rel:1 to:a m:1 c:c]; }
- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)a constant:(CGFloat)c { return [self _rel:-1 to:a m:1 c:c]; }
@end
@implementation NSLayoutXAxisAnchor
- (NSLayoutConstraint *)constraintEqualToSystemSpacingAfterAnchor:(NSLayoutXAxisAnchor *)a multiplier:(CGFloat)m { return [self _rel:0 to:a m:1 c:8 * m]; }
@end
@implementation NSLayoutYAxisAnchor
- (NSLayoutConstraint *)constraintEqualToSystemSpacingBelowAnchor:(NSLayoutYAxisAnchor *)a multiplier:(CGFloat)m { return [self _rel:0 to:a m:1 c:8 * m]; }
@end
@implementation NSLayoutDimension
- (NSLayoutConstraint *)constraintEqualToConstant:(CGFloat)c { return [self _rel:0 to:nil m:1 c:c]; }
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToConstant:(CGFloat)c { return [self _rel:1 to:nil m:1 c:c]; }
- (NSLayoutConstraint *)constraintLessThanOrEqualToConstant:(CGFloat)c { return [self _rel:-1 to:nil m:1 c:c]; }
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutDimension *)a multiplier:(CGFloat)m { return [self _rel:0 to:a m:m c:0]; }
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutDimension *)a multiplier:(CGFloat)m constant:(CGFloat)c { return [self _rel:0 to:a m:m c:c]; }
@end

#define ANCHORS(cls) \
- (NSLayoutXAxisAnchor *)leadingAnchor { return [NSLayoutXAxisAnchor _item:self attr:NSLayoutAttributeLeading]; } \
- (NSLayoutXAxisAnchor *)trailingAnchor { return [NSLayoutXAxisAnchor _item:self attr:NSLayoutAttributeTrailing]; } \
- (NSLayoutXAxisAnchor *)leftAnchor { return [NSLayoutXAxisAnchor _item:self attr:NSLayoutAttributeLeft]; } \
- (NSLayoutXAxisAnchor *)rightAnchor { return [NSLayoutXAxisAnchor _item:self attr:NSLayoutAttributeRight]; } \
- (NSLayoutXAxisAnchor *)centerXAnchor { return [NSLayoutXAxisAnchor _item:self attr:NSLayoutAttributeCenterX]; } \
- (NSLayoutYAxisAnchor *)topAnchor { return [NSLayoutYAxisAnchor _item:self attr:NSLayoutAttributeTop]; } \
- (NSLayoutYAxisAnchor *)bottomAnchor { return [NSLayoutYAxisAnchor _item:self attr:NSLayoutAttributeBottom]; } \
- (NSLayoutYAxisAnchor *)centerYAnchor { return [NSLayoutYAxisAnchor _item:self attr:NSLayoutAttributeCenterY]; } \
- (NSLayoutDimension *)widthAnchor { return [NSLayoutDimension _item:self attr:NSLayoutAttributeWidth]; } \
- (NSLayoutDimension *)heightAnchor { return [NSLayoutDimension _item:self attr:NSLayoutAttributeHeight]; }

@implementation UILayoutGuide { CGRect (^_provider)(void); unsigned _alGen; int _alVars[4]; UIEdgeInsets _alInsets; CGRect _solved; }
ANCHORS(UILayoutGuide)
- (void)_isim_setFrameProvider:(CGRect (^)(void))p { _provider = [p copy]; }
- (CGRect)layoutFrame { return _provider ? _provider() : _solved; }
- (int *)_isim_alVars:(unsigned)gen { return _alGen == gen ? _alVars : NULL; }
- (void)_isim_allocVars:(cw_solver *)s gen:(unsigned)gen { _alGen = gen; for (int i = 0; i < 4; i++) _alVars[i] = cw_var(s); }
/* system guides: fixed insets from the owning view (re-solved if the insets move); custom guides: free */
- (UIEdgeInsets)_isim_insetsIn:(UIView *)owner {
    CGRect b = owner.bounds, f = _provider();
    return UIEdgeInsetsMake(f.origin.y - b.origin.y, f.origin.x - b.origin.x, CGRectGetMaxY(b) - CGRectGetMaxY(f), CGRectGetMaxX(b) - CGRectGetMaxX(f));
}
- (void)_isim_addEngineConstraints:(isim_al *)al owner:(UIView *)owner {
    if (!_provider) return;
    _alInsets = [self _isim_insetsIn:owner];
    UIEdgeInsets i = _alInsets;
    isim_al_add(al, self, NSLayoutAttributeLeft, NSLayoutRelationEqual, owner, NSLayoutAttributeLeft, 1, i.left, 1001);
    isim_al_add(al, self, NSLayoutAttributeTop, NSLayoutRelationEqual, owner, NSLayoutAttributeTop, 1, i.top, 1001);
    isim_al_add(al, self, NSLayoutAttributeRight, NSLayoutRelationEqual, owner, NSLayoutAttributeRight, 1, -i.right, 1001);
    isim_al_add(al, self, NSLayoutAttributeBottom, NSLayoutRelationEqual, owner, NSLayoutAttributeBottom, 1, -i.bottom, 1001);
}
- (BOOL)_isim_applySolution:(cw_solver *)s owner:(UIView *)owner {
    if (_provider) return !UIEdgeInsetsEqualToEdgeInsets([self _isim_insetsIn:owner], _alInsets);
    int *ov = [owner _isim_alVars:_alGen];
    if (!ov) return NO;
    _solved = CGRectMake(cw_value(s, _alVars[0]) - cw_value(s, ov[0]) + owner.bounds.origin.x, cw_value(s, _alVars[1]) - cw_value(s, ov[1]) + owner.bounds.origin.y,
                         cw_value(s, _alVars[2]), cw_value(s, _alVars[3]));
    return NO;
}
@end

/* ================= UIView ================= */
@interface UIView () {
    CGRect _frame;
    CGPoint _boundsOrigin;
    NSMutableArray<UIView *> *_subs;
    __weak UIView *_superview;
    __weak UIWindow *_window;
    BOOL _needsLayout;
    NSMutableArray *_installed, *_guides, *_gestures;
    UILayoutGuide *_safeGuide, *_marginsGuide;
    UIColor *_tint;
    UILayoutPriority _hug[2], _resist[2];
    __weak UIViewController *_vc;
    unsigned _alGen; int _alVars[4]; CGFloat _alUsedWidth;       /* Auto Layout engine */
}
@end

@implementation UIView
@synthesize layer = _layer;
+ (Class)layerClass { return [CALayer class]; }
- (instancetype)init { return [self initWithFrame:CGRectZero]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithFrame:CGRectZero]; }
- (void)encodeWithCoder:(NSCoder *)c {}   /* isim: archiving is not implemented */
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super init])) {
        _frame = frame; _subs = [NSMutableArray array]; _alpha = 1; _userInteractionEnabled = YES; _autoresizesSubviews = YES;
        _translatesAutoresizingMaskIntoConstraints = YES; _layer = [[[self class] layerClass] new]; _needsLayout = YES;
        _layoutMargins = UIEdgeInsetsMake(8, 8, 8, 8); _clearsContextBeforeDrawing = YES; _multipleTouchEnabled = NO;
        _transform = CGAffineTransformIdentity;
        _hug[0] = _hug[1] = UILayoutPriorityDefaultLow; _resist[0] = _resist[1] = UILayoutPriorityDefaultHigh;
    }
    return self;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; frame = (%g %g; %g %g)%s>", [self class], self, _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height, _hidden ? "; hidden" : ""];
}

/* ---- geometry ---- */
- (CGRect)frame { return _frame; }
- (void)setFrame:(CGRect)f {
    if (isnan(f.origin.x) || isnan(f.origin.y) || isnan(f.size.width) || isnan(f.size.height)) return;
    CGSize old = _frame.size;
    if (_translatesAutoresizingMaskIntoConstraints && !CGRectEqualToRect(f, _frame)) { if (al_applying) al_tamic_moved = YES; else isim_ui_constraints_changed(); }
    _frame = f;
    if (!CGSizeEqualToSize(old, f.size)) {
        if (_autoresizesSubviews) for (UIView *s in _subs) [s _isim_autoresizeFrom:old to:f.size];
        [self setNeedsLayout];
    }
    isim_ui_set_needs_display();
}
- (CGRect)bounds { return (CGRect){ _boundsOrigin, _frame.size }; }
- (void)setBounds:(CGRect)b {
    CGPoint c = self.center;
    _boundsOrigin = b.origin;
    self.frame = CGRectMake(c.x - b.size.width / 2, c.y - b.size.height / 2, b.size.width, b.size.height);
}
- (CGPoint)center { return CGPointMake(CGRectGetMidX(_frame), CGRectGetMidY(_frame)); }
- (void)setCenter:(CGPoint)c { self.frame = CGRectMake(c.x - _frame.size.width / 2, c.y - _frame.size.height / 2, _frame.size.width, _frame.size.height); }
- (void)setTransform:(CGAffineTransform)t { _transform = t; isim_ui_set_needs_display(); }
- (void)_isim_autoresizeFrom:(CGSize)o to:(CGSize)n {
    UIViewAutoresizing m = _autoresizingMask;
    if (m == UIViewAutoresizingNone || !_translatesAutoresizingMaskIntoConstraints) return;
    CGRect f = _frame;
    for (int axis = 0; axis < 2; axis++) {
        double delta = axis ? n.height - o.height : n.width - o.width;
        BOOL fl = m & (axis ? UIViewAutoresizingFlexibleTopMargin : UIViewAutoresizingFlexibleLeftMargin);
        BOOL fs = m & (axis ? UIViewAutoresizingFlexibleHeight : UIViewAutoresizingFlexibleWidth);
        BOOL fr = m & (axis ? UIViewAutoresizingFlexibleBottomMargin : UIViewAutoresizingFlexibleRightMargin);
        int k = fl + fs + fr; if (!k) continue;
        double share = delta / k;
        double *pos = axis ? &f.origin.y : &f.origin.x, *size = axis ? &f.size.height : &f.size.width;
        if (fl) *pos += share;
        if (fs) *size += share;
    }
    self.frame = f;
}

/* ---- hierarchy ---- */
- (UIView *)superview { return _superview; }
- (NSArray *)subviews { return [_subs copy]; }
- (UIWindow *)window { return _window; }
- (void)_isim_movedToWindow:(UIWindow *)w {
    if (_window == w) return;
    /* a first responder leaving the window resigns (e.g. its page was popped), so the keyboard goes away */
    if (!w && (UIResponder *)self == first_responder) [self resignFirstResponder];
    [self willMoveToWindow:w];
    _window = w;
    for (UIView *s in _subs) [s _isim_movedToWindow:w];
    [self didMoveToWindow];
}
- (void)insertSubview:(UIView *)v atIndex:(NSInteger)i {
    if (!v || v == self) return;
    if (v->_superview == self) [_subs removeObjectIdenticalTo:v];
    else {
        [v removeFromSuperview];
        [v willMoveToSuperview:self];
        v->_superview = self;
    }
    if (i < 0) i = 0;
    if ((NSUInteger)i > _subs.count) i = (NSInteger)_subs.count;
    [_subs insertObject:v atIndex:(NSUInteger)i];
    [v _isim_movedToWindow:[self isKindOfClass:[UIWindow class]] ? (UIWindow *)self : _window];
    [v didMoveToSuperview];
    [self didAddSubview:v];
    isim_ui_constraints_changed();
    [self setNeedsLayout];
}
- (void)addSubview:(UIView *)v { [self insertSubview:v atIndex:(NSInteger)_subs.count + (v.superview == self ? -1 : 0)]; }
- (void)insertSubview:(UIView *)v belowSubview:(UIView *)s { NSUInteger i = [_subs indexOfObjectIdenticalTo:s]; [self insertSubview:v atIndex:i == NSNotFound ? 0 : (NSInteger)i]; }
- (void)insertSubview:(UIView *)v aboveSubview:(UIView *)s { NSUInteger i = [_subs indexOfObjectIdenticalTo:s]; [self insertSubview:v atIndex:i == NSNotFound ? (NSInteger)_subs.count : (NSInteger)i + 1]; }
- (void)bringSubviewToFront:(UIView *)v { if ([_subs indexOfObjectIdenticalTo:v] != NSNotFound) { [_subs removeObjectIdenticalTo:v]; [_subs addObject:v]; isim_ui_set_needs_display(); } }
- (void)sendSubviewToBack:(UIView *)v { if ([_subs indexOfObjectIdenticalTo:v] != NSNotFound) { [_subs removeObjectIdenticalTo:v]; [_subs insertObject:v atIndex:0]; isim_ui_set_needs_display(); } }
- (void)exchangeSubviewAtIndex:(NSInteger)a withSubviewAtIndex:(NSInteger)b { [_subs exchangeObjectAtIndex:(NSUInteger)a withObjectAtIndex:(NSUInteger)b]; isim_ui_set_needs_display(); }
- (void)removeFromSuperview {
    UIView *sup = _superview;
    if (!sup) return;
    [sup willRemoveSubview:self];
    [self willMoveToSuperview:nil];
    UIView *keep = self;                          /* keep alive through the callbacks */
    [sup->_subs removeObjectIdenticalTo:self];
    _superview = nil;
    [self _isim_movedToWindow:nil];
    [self didMoveToSuperview];
    for (NSLayoutConstraint *c in [active_constraints copy])
        if (c.firstItem == self || c.secondItem == self) {
            id other = c.firstItem == self ? c.secondItem : c.firstItem;
            if (other && other != self && ![other isKindOfClass:[UILayoutGuide class]] && ![(UIView *)other isDescendantOfView:self]) c.active = NO;
        }
    isim_ui_constraints_changed();
    [sup setNeedsLayout];
    (void)keep;
}
- (void)didAddSubview:(UIView *)s {}
- (void)willRemoveSubview:(UIView *)s {}
- (void)willMoveToSuperview:(UIView *)s {}
- (void)didMoveToSuperview {}
- (void)willMoveToWindow:(UIWindow *)w {}
- (void)didMoveToWindow {}
- (BOOL)isDescendantOfView:(UIView *)v { for (UIView *x = self; x; x = x->_superview) if (x == v) return YES; return NO; }
- (UIView *)viewWithTag:(NSInteger)tag {
    if (_tag == tag) return self;
    for (UIView *s in _subs) { UIView *r = [s viewWithTag:tag]; if (r) return r; }
    return nil;
}
- (UIViewController *)_isim_viewController { return _vc; }
- (void)_isim_setViewController:(UIViewController *)vc { _vc = vc; }
- (UIResponder *)nextResponder {
    UIViewController *vc = self._isim_viewController;
    if (vc) return vc;
    return _superview;
}

/* ---- appearance ---- */
- (void)setBackgroundColor:(UIColor *)c { _backgroundColor = c; isim_ui_set_needs_display(); }
- (void)setAlpha:(CGFloat)a { _alpha = a; isim_ui_set_needs_display(); }
- (void)setHidden:(BOOL)h {
    if (_hidden == h) return;
    _hidden = h; isim_ui_set_needs_display();
    if ([_superview isKindOfClass:[UIStackView class]]) { isim_ui_constraints_changed(); [_superview setNeedsLayout]; }
}
- (void)setClipsToBounds:(BOOL)c { _clipsToBounds = c; isim_ui_set_needs_display(); }
- (UIColor *)tintColor { return _tint ?: (_superview ? _superview.tintColor : UIColor.systemBlueColor); }
- (void)setTintColor:(UIColor *)c { _tint = c; [self _isim_tintChanged]; }
- (void)_isim_tintChanged { [self tintColorDidChange]; for (UIView *s in _subs) if (!s->_tint) [s _isim_tintChanged]; isim_ui_set_needs_display(); }
- (void)tintColorDidChange {}
- (UITraitCollection *)traitCollection {
    UIUserInterfaceStyle s = _overrideUserInterfaceStyle;
    for (UIView *v = _superview; !s && v; v = v->_superview) s = v->_overrideUserInterfaceStyle;
    return [UITraitCollection traitCollectionWithUserInterfaceStyle:s ?: isim_ui_style()];
}
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)s { _overrideUserInterfaceStyle = s; isim_ui_set_needs_display(); }
- (void)setNeedsDisplay { isim_ui_set_needs_display(); }
- (void)setNeedsDisplayInRect:(CGRect)r { isim_ui_set_needs_display(); }
- (void)drawRect:(CGRect)r {}
- (void)_isim_drawContent {}
- (void)_isim_drawOverlay {}
- (void)_isim_didSolve {}

/* ---- coordinates ---- */
- (CGPoint)_isim_toWindow:(CGPoint)p {
    for (UIView *v = self; v && ![v isKindOfClass:[UIWindow class]]; v = v->_superview) {
        p.x += v->_frame.origin.x - v->_boundsOrigin.x; p.y += v->_frame.origin.y - v->_boundsOrigin.y;
    }
    return p;
}
- (CGPoint)_isim_fromWindow:(CGPoint)p {
    CGPoint o = [self _isim_toWindow:CGPointZero];
    return CGPointMake(p.x - o.x, p.y - o.y);
}
- (CGPoint)convertPoint:(CGPoint)p toView:(UIView *)v { CGPoint w = [self _isim_toWindow:p]; return v ? [v _isim_fromWindow:w] : w; }
- (CGPoint)convertPoint:(CGPoint)p fromView:(UIView *)v { CGPoint w = v ? [v _isim_toWindow:p] : p; return [self _isim_fromWindow:w]; }
- (CGRect)convertRect:(CGRect)r toView:(UIView *)v { r.origin = [self convertPoint:r.origin toView:v]; return r; }
- (CGRect)convertRect:(CGRect)r fromView:(UIView *)v { r.origin = [self convertPoint:r.origin fromView:v]; return r; }
- (CGPoint)convertPoint:(CGPoint)p toCoordinateSpace:(id<UICoordinateSpace>)s { return [s isKindOfClass:[UIView class]] ? [self convertPoint:p toView:(UIView *)s] : [self _isim_toWindow:p]; }
- (CGPoint)convertPoint:(CGPoint)p fromCoordinateSpace:(id<UICoordinateSpace>)s { return [s isKindOfClass:[UIView class]] ? [self convertPoint:p fromView:(UIView *)s] : [self _isim_fromWindow:p]; }

/* ---- safe area & margins ---- */
- (UIEdgeInsets)safeAreaInsets {
    if (!_window) return UIEdgeInsetsZero;
    const struct isim_device *d = isim_ui_device();
    CGRect inWin = [self convertRect:self.bounds toView:nil];
    CGFloat top = MAX(0, d->safe_top - inWin.origin.y), bottom = MAX(0, CGRectGetMaxY(inWin) - (d->height - d->safe_bottom));
    return UIEdgeInsetsMake(MIN(top, inWin.size.height), 0, MIN(bottom, inWin.size.height), 0);
}
- (void)safeAreaInsetsDidChange {}
- (void)setLayoutMargins:(UIEdgeInsets)m { if (UIEdgeInsetsEqualToEdgeInsets(m, _layoutMargins)) return; _layoutMargins = m; isim_ui_constraints_changed(); [self setNeedsLayout]; }
- (NSDirectionalEdgeInsets)directionalLayoutMargins { return NSDirectionalEdgeInsetsMake(_layoutMargins.top, _layoutMargins.left, _layoutMargins.bottom, _layoutMargins.right); }
- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)m { self.layoutMargins = UIEdgeInsetsMake(m.top, m.leading, m.bottom, m.trailing); }
- (UILayoutGuide *)safeAreaLayoutGuide {
    if (!_safeGuide) {
        _safeGuide = [UILayoutGuide new]; _safeGuide.owningView = self; _safeGuide.identifier = @"UIViewSafeAreaLayoutGuide";
        __weak UIView *w = self;
        [_safeGuide _isim_setFrameProvider:^CGRect { UIView *s = w; return UIEdgeInsetsInsetRect(s.bounds, s.safeAreaInsets); }];
    }
    return _safeGuide;
}
- (UILayoutGuide *)layoutMarginsGuide {
    if (!_marginsGuide) {
        _marginsGuide = [UILayoutGuide new]; _marginsGuide.owningView = self; _marginsGuide.identifier = @"UIViewLayoutMarginsGuide";
        __weak UIView *w = self;
        [_marginsGuide _isim_setFrameProvider:^CGRect { UIView *s = w; return UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(s.bounds, s.safeAreaInsets), s.layoutMargins); }];
    }
    return _marginsGuide;
}
- (UILayoutGuide *)readableContentGuide { return self.layoutMarginsGuide; }
- (void)addLayoutGuide:(UILayoutGuide *)g { if (!_guides) _guides = [NSMutableArray array]; g.owningView = self; [_guides addObject:g]; isim_ui_constraints_changed(); }
- (void)removeLayoutGuide:(UILayoutGuide *)g { [_guides removeObjectIdenticalTo:g]; }
- (NSArray *)layoutGuides { return [_guides copy] ?: @[]; }

/* ---- Auto Layout API ---- */
ANCHORS(UIView)
- (NSLayoutYAxisAnchor *)firstBaselineAnchor { return [NSLayoutYAxisAnchor _item:self attr:NSLayoutAttributeFirstBaseline]; }
- (NSLayoutYAxisAnchor *)lastBaselineAnchor { return [NSLayoutYAxisAnchor _item:self attr:NSLayoutAttributeLastBaseline]; }
- (NSArray *)constraints { return [_installed copy] ?: @[]; }
- (void)addConstraint:(NSLayoutConstraint *)c { if (!_installed) _installed = [NSMutableArray array]; [_installed addObject:c]; c.active = YES; }
- (void)addConstraints:(NSArray *)cs { for (NSLayoutConstraint *c in cs) [self addConstraint:c]; }
- (void)removeConstraint:(NSLayoutConstraint *)c { [_installed removeObjectIdenticalTo:c]; c.active = NO; }
- (void)removeConstraints:(NSArray *)cs { for (NSLayoutConstraint *c in cs) [self removeConstraint:c]; }
- (void)setTranslatesAutoresizingMaskIntoConstraints:(BOOL)t { if (t == _translatesAutoresizingMaskIntoConstraints) return; _translatesAutoresizingMaskIntoConstraints = t; isim_ui_constraints_changed(); [_superview setNeedsLayout]; }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric); }
- (void)invalidateIntrinsicContentSize {
    isim_ui_constraints_changed();
    [_superview setNeedsLayout];
    if ([_superview isKindOfClass:[UIStackView class]]) [_superview invalidateIntrinsicContentSize];
}
- (UILayoutPriority)contentHuggingPriorityForAxis:(UILayoutConstraintAxis)a { return _hug[a]; }
- (void)setContentHuggingPriority:(UILayoutPriority)p forAxis:(UILayoutConstraintAxis)a { _hug[a] = p; }
- (UILayoutPriority)contentCompressionResistancePriorityForAxis:(UILayoutConstraintAxis)a { return _resist[a]; }
- (void)setContentCompressionResistancePriority:(UILayoutPriority)p forAxis:(UILayoutConstraintAxis)a { _resist[a] = p; }
- (void)setNeedsUpdateConstraints { [self setNeedsLayout]; }
- (void)updateConstraintsIfNeeded {}
- (void)updateConstraints {}
- (CGSize)sizeThatFits:(CGSize)size { CGSize s = [self intrinsicContentSize]; return CGSizeMake(s.width < 0 ? _frame.size.width : s.width, s.height < 0 ? _frame.size.height : s.height); }
- (void)sizeToFit { CGSize s = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)]; self.frame = (CGRect){ _frame.origin, s }; }

/* ---- layout ---- */
- (void)setNeedsLayout { _needsLayout = YES; isim_ui_set_needs_layout(); }
- (void)layoutIfNeeded {
    UIView *top = self; while (top->_superview) top = top->_superview;
    isim_ui_layout_window(top);
    UIView *root = self; while (root->_superview && root->_superview->_needsLayout) root = root->_superview;
    [root _isim_layoutPass];
}
- (void)_isim_layoutPass {
    if (_needsLayout) {
        _needsLayout = NO;
        UIViewController *vc = self._isim_viewController;
        [vc viewWillLayoutSubviews];
        [self layoutSubviews];
        [vc viewDidLayoutSubviews];
    }
    for (UIView *s in [_subs copy]) [s _isim_layoutPass];
}
- (void)layoutSubviews {}

/* ================= Auto Layout engine =================
 * One Cassowary solve per window over every view and layout guide in it (window
 * coordinates; 4 variables each: left, top, width, height). Inputs:
 *  - the window frame (required); translatesAutoresizingMaskIntoConstraints views: their
 *    current frame relative to the superview (structural strength);
 *  - system layout guides (safe area, margins): insets relative to the owning view;
 *  - active NSLayoutConstraints (priority -> strength; 1000 = "required" strength);
 *  - intrinsic content size: compression resistance (>=) and hugging (<=);
 *  - engine constraints from views (UIStackView arranges its subviews this way);
 *  - a weak pull towards each view's current frame (keeps under-constrained views put).
 * No input is truly "required" except the window, so conflicting constraints are resolved
 * by strength instead of failing (UIKit breaks one and logs; isim logs nothing yet).
 * Multi-line labels and safe-area insets depend on the result, so the solve repeats until
 * those inputs are stable (max 4 passes). */
struct isim_al { cw_solver *s; unsigned gen; };
static unsigned al_gen;
static BOOL al_dirty = YES;
void isim_ui_constraints_changed(void) { al_dirty = YES; isim_ui_set_needs_layout(); }
#define AL_STRUCTURAL 1e13
#define AL_WEAK 0.01
static double al_strength(UILayoutPriority p) { return p >= 1000 ? 1e12 : p <= 0 ? 0 : pow(10, p / 125.0); }

static int *al_vars(id item, unsigned gen);
static int al_attr_terms(id item, NSLayoutAttribute a, unsigned gen, int vars[2], double coeffs[2], double *offset) {
    int *v = al_vars(item, gen);
    if (!v) return 0;
    *offset = 0;
    UIEdgeInsets m = [item isKindOfClass:[UIView class]] ? ((UIView *)item).layoutMargins : UIEdgeInsetsZero;
    int L = v[0], T = v[1], W = v[2], H = v[3];
    #define ONE(x) (vars[0] = (x), coeffs[0] = 1, 1)
    #define TWO(x, y, k) (vars[0] = (x), coeffs[0] = 1, vars[1] = (y), coeffs[1] = (k), 2)
    switch (a) {
    case NSLayoutAttributeLeft: case NSLayoutAttributeLeading: return ONE(L);
    case NSLayoutAttributeRight: case NSLayoutAttributeTrailing: return TWO(L, W, 1);
    case NSLayoutAttributeCenterX: return TWO(L, W, 0.5);
    case NSLayoutAttributeWidth: return ONE(W);
    case NSLayoutAttributeTop: return ONE(T);
    case NSLayoutAttributeBottom: return TWO(T, H, 1);
    case NSLayoutAttributeCenterY: return TWO(T, H, 0.5);
    case NSLayoutAttributeHeight: return ONE(H);
    case NSLayoutAttributeLeftMargin: case NSLayoutAttributeLeadingMargin: *offset = m.left; return ONE(L);
    case NSLayoutAttributeRightMargin: case NSLayoutAttributeTrailingMargin: *offset = -m.right; return TWO(L, W, 1);
    case NSLayoutAttributeTopMargin: *offset = m.top; return ONE(T);
    case NSLayoutAttributeBottomMargin: *offset = -m.bottom; return TWO(T, H, 1);
    case NSLayoutAttributeCenterXWithinMargins: *offset = (m.left - m.right) / 2; return TWO(L, W, 0.5);
    case NSLayoutAttributeCenterYWithinMargins: *offset = (m.top - m.bottom) / 2; return TWO(T, H, 0.5);
    case NSLayoutAttributeFirstBaseline: case NSLayoutAttributeLastBaseline: {
        UIFont *f = [item isKindOfClass:[UILabel class]] ? ((UILabel *)item).font : [item isKindOfClass:[UIButton class]] ? ((UIButton *)item).titleLabel.font : nil;
        if (!f) return TWO(T, H, 1);                                             /* views without text: bottom edge */
        BOOL multi = [item isKindOfClass:[UILabel class]] && ((UILabel *)item).numberOfLines != 1;
        if (multi && a == NSLayoutAttributeFirstBaseline) { *offset = ceil(f.ascender); return ONE(T); }
        if (multi) { *offset = floor(f.descender); return TWO(T, H, 1); }
        *offset = f.ascender - f.lineHeight / 2;                                 /* single line: text is centered */
        return TWO(T, H, 0.5);
    }
    default: return 0;
    }
    #undef ONE
    #undef TWO
}

/* sum(coeffs[i] * attr(items[i])) + constant  REL  0 */
BOOL isim_al_add_expr(isim_al *al, NSUInteger n, __unsafe_unretained id const *items, const NSLayoutAttribute *attrs, const CGFloat *coeffs,
                      CGFloat constant, NSLayoutRelation rel, UILayoutPriority priority) {
    int vars[16]; double cs[16]; int k = 0; double c = constant;
    for (NSUInteger i = 0; i < n && k < 14; i++) {
        int tv[2]; double tc[2], off;
        int m = al_attr_terms(items[i], attrs[i], al->gen, tv, tc, &off);
        if (!m) return NO;
        for (int j = 0; j < m; j++) { vars[k] = tv[j]; cs[k++] = tc[j] * coeffs[i]; }
        c += off * coeffs[i];
    }
    int op = rel == NSLayoutRelationEqual ? CW_EQ : rel == NSLayoutRelationLessThanOrEqual ? CW_LE : CW_GE;
    /* priority > 1000: structural; 0 < priority < 1: raw tie-breaker strength */
    double strength = priority > 1000.5 ? AL_STRUCTURAL : priority > 0 && priority < 1 ? priority : al_strength(priority);
    if (strength <= 0) return YES;
    cw_add(al->s, vars, cs, k, c, op, strength);
    return YES;
}
/* constraints between a scroll view's edges and its descendants refer to the content area */
static id al_scroll_content(id item, id other) {
    if (![item isKindOfClass:[UIScrollView class]] || !other) return item;
    UIView *o = [other isKindOfClass:[UILayoutGuide class]] ? ((UILayoutGuide *)other).owningView : other;
    if (![o isKindOfClass:[UIView class]] || o == item || ![o isDescendantOfView:item]) return item;
    UIScrollView *sv = item;
    [sv _isim_markContentFromLayout];
    return sv.contentLayoutGuide;
}
BOOL isim_al_add(isim_al *al, id a, NSLayoutAttribute aa, NSLayoutRelation rel, id b, NSLayoutAttribute ba, CGFloat mult, CGFloat constant, UILayoutPriority priority) {
    if (priority <= 1000) { id a2 = al_scroll_content(a, b), b2 = al_scroll_content(b, a); a = a2; b = b2; }
    if (!b || ba == NSLayoutAttributeNotAnAttribute) { CGFloat one = 1; return isim_al_add_expr(al, 1, &a, &aa, &one, -constant, rel, priority); }
    __unsafe_unretained id items[2] = { a, b }; NSLayoutAttribute attrs[2] = { aa, ba }; CGFloat k[2] = { 1, -mult };
    return isim_al_add_expr(al, 2, items, attrs, k, -constant, rel, priority);
}
static void al_raw(isim_al *al, int n, const int *vars, const double *cs, double c, int op, double strength) { cw_add(al->s, vars, cs, n, c, op, strength); }

- (CGSize)_isim_intrinsicSizeForWidth:(CGFloat)w { return [self intrinsicContentSize]; }
- (void)_isim_addEngineConstraints:(isim_al *)al {}
- (int *)_isim_alVars:(unsigned)gen { return _alGen == gen ? _alVars : NULL; }
static int *al_vars(id item, unsigned gen) {
    if ([item isKindOfClass:[UIView class]]) return [(UIView *)item _isim_alVars:gen];
    if ([item isKindOfClass:[UILayoutGuide class]]) return [(UILayoutGuide *)item _isim_alVars:gen];
    return NULL;
}
static CGPoint al_bo(UIView *v) { return [v isKindOfClass:[UIScrollView class]] ? CGPointZero : v->_boundsOrigin; }
static void al_collect(UIView *v, NSMutableArray *out) { [out addObject:v]; for (UIView *s in v->_subs) al_collect(s, out); }
- (NSArray<UILayoutGuide *> *)_isim_allGuides {
    NSMutableArray *g = [NSMutableArray array];
    if (_safeGuide) [g addObject:_safeGuide];
    if (_marginsGuide) [g addObject:_marginsGuide];
    if (_guides) [g addObjectsFromArray:_guides];
    return g;
}

/* one solve; returns YES if inputs that depend on the result changed (another pass needed) */
static BOOL al_solve_once(UIView *root, NSArray<UIView *> *views) {
    isim_al al = { cw_new(), ++al_gen };
    cw_solver *s = al.s;
    for (UIView *v in views) {
        v->_alGen = al.gen; for (int i = 0; i < 4; i++) v->_alVars[i] = cw_var(s);
        for (UILayoutGuide *g in [v _isim_allGuides]) [g _isim_allocVars:s gen:al.gen];
    }
    const double one = 1, mone = -1;
    /* root: window coordinates */
    { int *r = root->_alVars; CGSize sz = root->_frame.size;
      al_raw(&al, 1, &r[0], &one, 0, CW_EQ, CW_REQUIRED); al_raw(&al, 1, &r[1], &one, 0, CW_EQ, CW_REQUIRED);
      al_raw(&al, 1, &r[2], &one, -sz.width, CW_EQ, CW_REQUIRED); al_raw(&al, 1, &r[3], &one, -sz.height, CW_EQ, CW_REQUIRED); }
    for (UIView *v in views) {
        int *x = v->_alVars;
        double sw[2] = { 1, 0 };
        if (v != root) {
            UIView *sup = v->_superview; int *p = sup->_alVars;
            double off[2] = { v->_frame.origin.x - al_bo(sup).x, v->_frame.origin.y - al_bo(sup).y };
            double strength = v->_translatesAutoresizingMaskIntoConstraints ? AL_STRUCTURAL : AL_WEAK;
            for (int axis = 0; axis < 2; axis++) {
                int pv[2] = { x[axis], p[axis] }; double pc[2] = { 1, -1 };
                al_raw(&al, 2, pv, pc, -off[axis], CW_EQ, strength);
                double size = axis ? v->_frame.size.height : v->_frame.size.width;
                al_raw(&al, 1, &x[2 + axis], &one, -size, CW_EQ, strength);
            }
            if (!v->_translatesAutoresizingMaskIntoConstraints) {
                v->_alUsedWidth = v->_frame.size.width;
                CGSize ics = [v _isim_intrinsicSizeForWidth:v->_frame.size.width];
                for (int axis = 0; axis < 2; axis++) {
                    double want = axis ? ics.height : ics.width;
                    if (want < 0) continue;
                    al_raw(&al, 1, &x[2 + axis], &one, -want, CW_GE, al_strength(v->_resist[axis]));
                    al_raw(&al, 1, &x[2 + axis], &one, -want, CW_LE, al_strength(v->_hug[axis]));
                }
            }
        }
        (void)sw;
        al_raw(&al, 1, &x[2], &one, 0, CW_GE, AL_STRUCTURAL); al_raw(&al, 1, &x[3], &one, 0, CW_GE, AL_STRUCTURAL);
        for (UILayoutGuide *g in [v _isim_allGuides]) [g _isim_addEngineConstraints:&al owner:v];
        (void)mone;
    }
    for (NSLayoutConstraint *c in active_constraints)
        isim_al_add(&al, c.firstItem, c.firstAttribute, c.relation, c.secondItem, c.secondAttribute, c.multiplier, c.constant, c.priority);
    for (UIView *v in views) [v _isim_addEngineConstraints:&al];

    /* apply (parents first, so autoresizing of frame-based children sees final sizes) */
    BOOL again = NO;
    al_applying = YES; al_tamic_moved = NO;
    CGFloat scale = isim_ui_device()->scale ?: 1;
    for (UIView *v in views) {
        if (v == root || v->_translatesAutoresizingMaskIntoConstraints) continue;
        UIView *sup = v->_superview; int *x = v->_alVars, *p = sup->_alVars;
        #define PX(val) (round((val) * scale) / scale)
        double l = cw_value(s, x[0]) - cw_value(s, p[0]) + al_bo(sup).x, t = cw_value(s, x[1]) - cw_value(s, p[1]) + al_bo(sup).y;
        CGRect f = CGRectMake(PX(l), PX(t), PX(cw_value(s, x[0]) + cw_value(s, x[2])) - PX(cw_value(s, x[0])), PX(cw_value(s, x[1]) + cw_value(s, x[3])) - PX(cw_value(s, x[1])));
        #undef PX
        if (f.size.width < 0) f.size.width = 0;
        if (f.size.height < 0) f.size.height = 0;
        if (!CGRectEqualToRect(f, v->_frame)) v.frame = f;
        if (fabs(f.size.width - v->_alUsedWidth) > 0.5 && [v isKindOfClass:[UILabel class]] && ((UILabel *)v).numberOfLines != 1) again = YES;
    }
    for (UIView *v in views) for (UILayoutGuide *g in [v _isim_allGuides]) if ([g _isim_applySolution:s owner:v]) again = YES;
    for (UIView *v in views) [v _isim_didSolve];
    al_applying = NO;
    cw_free(s);
    return again || al_tamic_moved;
}
static void al_solve_root(UIView *root) {
    NSMutableArray *views = [NSMutableArray array];
    al_collect(root, views);
    BOOL any = active_constraints.count > 0;
    for (UIView *v in views) if (!v->_translatesAutoresizingMaskIntoConstraints && v != root) { any = YES; break; }
    if (!any) return;
    for (int pass = 0; pass < 4; pass++) if (!al_solve_once(root, views)) break;
}
/* engine inputs are tracked globally, so a dirty engine re-solves every root given */
void isim_ui_layout_roots(NSArray<UIView *> *roots) {
    for (int round = 0; round < 3 && al_dirty; round++) {
        al_dirty = NO;
        for (UIView *r in roots) al_solve_root(r);
    }
}
void isim_ui_layout_window(UIView *root) {
    if (!al_dirty) return;
    al_dirty = NO;
    al_solve_root(root);
    al_dirty = YES;      /* other roots (windows) may depend on the same changes */
}

/* fitting size: solve the view's subtree alone with its size pulled towards the target */
- (CGSize)systemLayoutSizeFittingSize:(CGSize)target withHorizontalFittingPriority:(UILayoutPriority)hp verticalFittingPriority:(UILayoutPriority)vp {
    NSMutableArray *views = [NSMutableArray array];
    al_collect(self, views);
    isim_al al = { cw_new(), ++al_gen };
    for (UIView *v in views) { v->_alGen = al.gen; for (int i = 0; i < 4; i++) v->_alVars[i] = cw_var(al.s); for (UILayoutGuide *g in [v _isim_allGuides]) [g _isim_allocVars:al.s gen:al.gen]; }
    const double one = 1;
    int *r = _alVars;
    al_raw(&al, 1, &r[0], &one, 0, CW_EQ, CW_REQUIRED); al_raw(&al, 1, &r[1], &one, 0, CW_EQ, CW_REQUIRED);
    al_raw(&al, 1, &r[2], &one, -target.width, CW_EQ, al_strength(hp)); al_raw(&al, 1, &r[3], &one, -target.height, CW_EQ, al_strength(vp));
    for (UIView *v in views) {
        int *x = v->_alVars;
        if (v != self) {
            UIView *sup = v->_superview; int *p = sup->_alVars;
            double strength = v->_translatesAutoresizingMaskIntoConstraints ? AL_STRUCTURAL : AL_WEAK;
            double off[2] = { v->_frame.origin.x - al_bo(sup).x, v->_frame.origin.y - al_bo(sup).y };
            for (int axis = 0; axis < 2; axis++) {
                int pv[2] = { x[axis], p[axis] }; double pc[2] = { 1, -1 };
                al_raw(&al, 2, pv, pc, -off[axis], CW_EQ, strength);
                al_raw(&al, 1, &x[2 + axis], &one, -(axis ? v->_frame.size.height : v->_frame.size.width), CW_EQ, strength);
            }
        }
        if (!v->_translatesAutoresizingMaskIntoConstraints || v == self) {
            CGSize ics = [v _isim_intrinsicSizeForWidth:v == self && target.width > 0 && hp >= 1000 ? target.width : v->_frame.size.width];
            for (int axis = 0; axis < 2; axis++) {
                double want = axis ? ics.height : ics.width;
                if (want < 0) continue;
                al_raw(&al, 1, &x[2 + axis], &one, -want, CW_GE, al_strength(v->_resist[axis]));
                al_raw(&al, 1, &x[2 + axis], &one, -want, CW_LE, al_strength(v->_hug[axis]));
            }
        }
        al_raw(&al, 1, &x[2], &one, 0, CW_GE, AL_STRUCTURAL); al_raw(&al, 1, &x[3], &one, 0, CW_GE, AL_STRUCTURAL);
        for (UILayoutGuide *g in [v _isim_allGuides]) [g _isim_addEngineConstraints:&al owner:v];
    }
    for (NSLayoutConstraint *c in active_constraints) {
        /* only constraints entirely inside the subtree */
        id a = c.firstItem, b = c.secondItem;
        if (!al_vars(a, al.gen) || (b && !al_vars(b, al.gen))) continue;
        isim_al_add(&al, a, c.firstAttribute, c.relation, b, c.secondAttribute, c.multiplier, c.constant, c.priority);
    }
    for (UIView *v in views) [v _isim_addEngineConstraints:&al];
    CGSize out = CGSizeMake(ceil(cw_value(al.s, r[2])), ceil(cw_value(al.s, r[3])));
    cw_free(al.s);
    _alGen = 0;
    return out;
}
- (CGSize)systemLayoutSizeFittingSize:(CGSize)t { return [self systemLayoutSizeFittingSize:t withHorizontalFittingPriority:UILayoutPriorityFittingSizeLevel verticalFittingPriority:UILayoutPriorityFittingSizeLevel]; }
- (CGSize)_isim_fittingSize {
    BOOL constrained = NO;
    for (NSLayoutConstraint *c in active_constraints) if (c.firstItem == self || c.secondItem == self) { constrained = YES; break; }
    if (!constrained && !_subs.count) return [self intrinsicContentSize];
    return [self systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
}

/* ---- hit testing & gestures ---- */
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return CGRectContainsPoint(self.bounds, p); }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (_hidden || !_userInteractionEnabled || _alpha < 0.01 || ![self pointInside:p withEvent:e]) return nil;
    for (NSInteger i = (NSInteger)_subs.count - 1; i >= 0; i--) {
        UIView *s = _subs[(NSUInteger)i];
        CGPoint q = CGPointMake(p.x - s->_frame.origin.x + s->_boundsOrigin.x, p.y - s->_frame.origin.y + s->_boundsOrigin.y);
        UIView *h = [s hitTest:q withEvent:e];
        if (h) return h;
    }
    return self;
}
- (NSArray *)gestureRecognizers { return [_gestures copy]; }
- (void)setGestureRecognizers:(NSArray *)g { _gestures = [g mutableCopy]; for (UIGestureRecognizer *r in g) [r _isim_setView:self]; }
- (void)addGestureRecognizer:(UIGestureRecognizer *)g { if (!_gestures) _gestures = [NSMutableArray array]; [_gestures addObject:g]; [g _isim_setView:self]; }
- (void)removeGestureRecognizer:(UIGestureRecognizer *)g { [_gestures removeObjectIdenticalTo:g]; [g _isim_setView:nil]; }

/* ---- rendering ---- */
static IMP base_drawRect;
- (void)_isim_render {
    if (_hidden || _alpha <= 0.01 || _layer.hidden) return;
    CGSize sz = _frame.size;
    isim_gfx_save();
    isim_gfx_translate(_frame.origin.x, _frame.origin.y);
    if (!CGAffineTransformIsIdentity(_transform)) {      /* about the center, like UIKit */
        isim_gfx_translate(sz.width / 2, sz.height / 2);
        isim_gfx_concat(_transform.a, _transform.b, _transform.c, _transform.d, _transform.tx, _transform.ty);
        isim_gfx_translate(-sz.width / 2, -sz.height / 2);
    }
    BOOL pushedStyle = _overrideUserInterfaceStyle != UIUserInterfaceStyleUnspecified;
    if (pushedStyle) isim_ui_push_style(_overrideUserInterfaceStyle);
    double a = _alpha * _layer.opacity;
    BOOL group = a < 0.999;
    if (group) isim_gfx_push_group();
    double radius = _layer.cornerRadius, bg[4];
    if (_backgroundColor) isim_ui_rgba(_backgroundColor, bg);
    else if (_layer.backgroundColor) { const CGFloat *c = CGColorGetComponents(_layer.backgroundColor); for (int i = 0; i < 4; i++) bg[i] = c[i]; }
    else bg[3] = 0;
    if (bg[3] > 0 && _layer.shadowOpacity > 0 && _layer.shadowColor) {
        /* drop shadow under the background shape; blur approximated by stacked expanding fills */
        const CGFloat *sc = CGColorGetComponents(_layer.shadowColor);
        CGSize o = _layer.shadowOffset; double blur = _layer.shadowRadius;
        int steps = blur > 0.5 ? 5 : 1;
        for (int i = steps - 1; i >= 0; i--) {
            double e = steps > 1 ? blur * (i + 1) / steps : 0;
            double col[4] = { sc[0], sc[1], sc[2], sc[3] * _layer.shadowOpacity / steps };
            isim_gfx_fill_rounded(o.width - e, o.height - e, sz.width + 2 * e, sz.height + 2 * e, radius + e, col);
        }
    }
    if (bg[3] > 0) isim_gfx_fill_rounded(0, 0, sz.width, sz.height, radius, bg);
    BOOL clip = _clipsToBounds || _layer.masksToBounds;
    if (clip) { isim_gfx_save(); isim_gfx_clip_rounded(0, 0, sz.width, sz.height, radius); }
    [self _isim_drawContent];
    if (!base_drawRect) base_drawRect = class_getMethodImplementation([UIView class], @selector(drawRect:));
    if (class_getMethodImplementation(object_getClass(self), @selector(drawRect:)) != base_drawRect) {
        isim_gfx_save(); CGContextSaveGState(isim_cg_current_context());
        [self drawRect:self.bounds];
        CGContextRestoreGState(isim_cg_current_context()); isim_gfx_restore();
    }
    isim_gfx_translate(-_boundsOrigin.x, -_boundsOrigin.y);
    for (UIView *s in _subs) [s _isim_render];
    [self _isim_drawOverlay];
    if (clip) isim_gfx_restore();
    if (_layer.borderWidth > 0 && _layer.borderColor) {
        const CGFloat *c = CGColorGetComponents(_layer.borderColor); double bc[4] = { c[0], c[1], c[2], c[3] };
        isim_gfx_stroke_rounded(0, 0, sz.width, sz.height, radius, _layer.borderWidth, bc);
    }
    if (group) isim_gfx_pop_group(a);
    if (pushedStyle) isim_ui_pop_style();
    isim_gfx_restore();
}

/* ---- animation (applied immediately) ---- */
+ (void)animateWithDuration:(NSTimeInterval)d animations:(void (^)(void))a { [self animateWithDuration:d delay:0 options:0 animations:a completion:nil]; }
+ (void)animateWithDuration:(NSTimeInterval)d animations:(void (^)(void))a completion:(void (^)(BOOL))c { [self animateWithDuration:d delay:0 options:0 animations:a completion:c]; }
+ (void)animateWithDuration:(NSTimeInterval)d delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)damp initialSpringVelocity:(CGFloat)v options:(UIViewAnimationOptions)o animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    [self animateWithDuration:d delay:delay options:o animations:a completion:c];
}
+ (void)animateWithDuration:(NSTimeInterval)d delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)o animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    void (^run)(void) = ^{
        if (a) a();
        if (c) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ c(YES); });
    };
    if (delay > 0) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), run);
    else run();
}
+ (void)performWithoutAnimation:(void (^)(void))a { a(); }
@end

