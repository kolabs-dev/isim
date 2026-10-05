/* isim UIKit: UIResponder, UIView, layout guides, NSLayoutConstraint/anchors and a small
 * constraint resolver (ARC).
 *
 * Auto Layout subset: required/optional EQUAL constraints between a view's direct subviews,
 * the view itself and its layout guides are resolved iteratively per axis; width/height
 * inequalities with constants clamp sizes; other inequalities are ignored (approximation). */
#import "UIKitPrivate.h"
#include <math.h>

const CGFloat UIViewNoIntrinsicMetric = -1;
const CGSize UILayoutFittingCompressedSize = { 0, 0 };
const CGSize UILayoutFittingExpandedSize = { 10000, 10000 };

/* ================= UIResponder ================= */
@implementation UIResponder
- (UIResponder *)nextResponder { return nil; }
- (BOOL)canBecomeFirstResponder { return NO; }
- (BOOL)canResignFirstResponder { return YES; }
- (BOOL)isFirstResponder { return NO; }
- (BOOL)becomeFirstResponder { return NO; }
- (BOOL)resignFirstResponder { return YES; }
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
static void relayout_item(id item) {
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
- (void)setConstant:(CGFloat)c { _constant = c; if (_active) { relayout_item(self.firstItem); relayout_item(self.secondItem); } }
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

@implementation UILayoutGuide { CGRect (^_provider)(void); }
ANCHORS(UILayoutGuide)
- (void)_isim_setFrameProvider:(CGRect (^)(void))p { _provider = [p copy]; }
- (CGRect)layoutFrame { return _provider ? _provider() : CGRectZero; }
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
}
@end

@implementation UIView
@synthesize layer = _layer;
+ (Class)layerClass { return [CALayer class]; }
- (instancetype)init { return [self initWithFrame:CGRectZero]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithFrame:CGRectZero]; }
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
    if ([_superview isKindOfClass:[UIStackView class]]) [_superview setNeedsLayout];
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
- (void)setLayoutMargins:(UIEdgeInsets)m { _layoutMargins = m; [self setNeedsLayout]; }
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
- (void)addLayoutGuide:(UILayoutGuide *)g { if (!_guides) _guides = [NSMutableArray array]; g.owningView = self; [_guides addObject:g]; }
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
- (void)setTranslatesAutoresizingMaskIntoConstraints:(BOOL)t { _translatesAutoresizingMaskIntoConstraints = t; [_superview setNeedsLayout]; }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric); }
- (void)invalidateIntrinsicContentSize {
    [_superview setNeedsLayout];
    if ([_superview isKindOfClass:[UIStackView class]]) [_superview invalidateIntrinsicContentSize];
}
- (CGSize)systemLayoutSizeFittingSize:(CGSize)t { CGSize s = [self _isim_fittingSize]; return CGSizeMake(s.width < 0 ? t.width : s.width, s.height < 0 ? t.height : s.height); }
- (UILayoutPriority)contentHuggingPriorityForAxis:(UILayoutConstraintAxis)a { return _hug[a]; }
- (void)setContentHuggingPriority:(UILayoutPriority)p forAxis:(UILayoutConstraintAxis)a { _hug[a] = p; }
- (UILayoutPriority)contentCompressionResistancePriorityForAxis:(UILayoutConstraintAxis)a { return _resist[a]; }
- (void)setContentCompressionResistancePriority:(UILayoutPriority)p forAxis:(UILayoutConstraintAxis)a { _resist[a] = p; }
- (void)setNeedsUpdateConstraints { [self setNeedsLayout]; }
- (void)updateConstraintsIfNeeded {}
- (void)updateConstraints {}
- (CGSize)_isim_fittingSize {
    CGSize s = [self intrinsicContentSize];
    for (NSLayoutConstraint *c in active_constraints) {
        if (c.firstItem != self || c.secondItem || (c.firstAttribute != NSLayoutAttributeWidth && c.firstAttribute != NSLayoutAttributeHeight)) continue;
        CGFloat *d = c.firstAttribute == NSLayoutAttributeWidth ? &s.width : &s.height;
        if (c.relation == NSLayoutRelationEqual) *d = c.constant;
        else if (c.relation == NSLayoutRelationGreaterThanOrEqual) *d = MAX(*d, c.constant);
        else if (*d >= 0) *d = MIN(*d, c.constant);
    }
    return s;
}
- (CGSize)sizeThatFits:(CGSize)size { CGSize s = [self intrinsicContentSize]; return CGSizeMake(s.width < 0 ? _frame.size.width : s.width, s.height < 0 ? _frame.size.height : s.height); }
- (void)sizeToFit { CGSize s = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)]; self.frame = (CGRect){ _frame.origin, s }; }

/* ---- layout ---- */
- (void)setNeedsLayout { _needsLayout = YES; isim_ui_set_needs_layout(); }
- (void)layoutIfNeeded {
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
- (void)layoutSubviews { [self _isim_solveConstraints]; }

/* --- constraint resolution for direct subviews --- */
typedef struct { double v[4]; BOOL k[4]; } axis_t;     /* min, max, center, size */
enum { A_MIN, A_MAX, A_CEN, A_SIZE };
static int attr_axis(NSLayoutAttribute a) {
    switch (a) {
    case NSLayoutAttributeLeft: case NSLayoutAttributeRight: case NSLayoutAttributeLeading: case NSLayoutAttributeTrailing:
    case NSLayoutAttributeWidth: case NSLayoutAttributeCenterX: case NSLayoutAttributeLeftMargin: case NSLayoutAttributeRightMargin:
    case NSLayoutAttributeLeadingMargin: case NSLayoutAttributeTrailingMargin: case NSLayoutAttributeCenterXWithinMargins: return 0;
    default: return 1;
    }
}
static int attr_slot(NSLayoutAttribute a) {
    switch (a) {
    case NSLayoutAttributeLeft: case NSLayoutAttributeLeading: case NSLayoutAttributeTop: case NSLayoutAttributeLeftMargin:
    case NSLayoutAttributeLeadingMargin: case NSLayoutAttributeTopMargin: case NSLayoutAttributeFirstBaseline: return A_MIN;
    case NSLayoutAttributeRight: case NSLayoutAttributeTrailing: case NSLayoutAttributeBottom: case NSLayoutAttributeRightMargin:
    case NSLayoutAttributeTrailingMargin: case NSLayoutAttributeBottomMargin: case NSLayoutAttributeLastBaseline: return A_MAX;
    case NSLayoutAttributeCenterX: case NSLayoutAttributeCenterY: case NSLayoutAttributeCenterXWithinMargins: case NSLayoutAttributeCenterYWithinMargins: return A_CEN;
    default: return A_SIZE;
    }
}
/* margin attributes / baselines shift the value relative to the plain edge */
static double attr_offset(id item, NSLayoutAttribute a) {
    if (![item isKindOfClass:[UIView class]]) return 0;
    UIView *v = item; UIEdgeInsets m = v.layoutMargins;
    switch (a) {
    case NSLayoutAttributeLeftMargin: case NSLayoutAttributeLeadingMargin: return m.left;
    case NSLayoutAttributeRightMargin: case NSLayoutAttributeTrailingMargin: return -m.right;
    case NSLayoutAttributeTopMargin: return m.top;
    case NSLayoutAttributeBottomMargin: return -m.bottom;
    case NSLayoutAttributeFirstBaseline: return [v isKindOfClass:[UILabel class]] ? ceil(((UILabel *)v).font.ascender) : 0;
    case NSLayoutAttributeLastBaseline: return [v isKindOfClass:[UILabel class]] ? floor(((UILabel *)v).font.descender) : 0;
    default: return 0;
    }
}
static void axis_complete(axis_t *x) {
    for (int pass = 0; pass < 2; pass++) {
        if (x->k[A_MIN] && x->k[A_MAX] && !x->k[A_SIZE]) { x->v[A_SIZE] = x->v[A_MAX] - x->v[A_MIN]; x->k[A_SIZE] = YES; }
        if (x->k[A_SIZE]) {
            if (x->k[A_MIN]) { x->v[A_MAX] = x->v[A_MIN] + x->v[A_SIZE]; x->v[A_CEN] = x->v[A_MIN] + x->v[A_SIZE] / 2; x->k[A_MAX] = x->k[A_CEN] = YES; }
            else if (x->k[A_MAX]) { x->v[A_MIN] = x->v[A_MAX] - x->v[A_SIZE]; x->v[A_CEN] = x->v[A_MIN] + x->v[A_SIZE] / 2; x->k[A_MIN] = x->k[A_CEN] = YES; }
            else if (x->k[A_CEN]) { x->v[A_MIN] = x->v[A_CEN] - x->v[A_SIZE] / 2; x->v[A_MAX] = x->v[A_MIN] + x->v[A_SIZE]; x->k[A_MIN] = x->k[A_MAX] = YES; }
        } else if (x->k[A_CEN] && (x->k[A_MIN] || x->k[A_MAX])) {
            double half = x->k[A_MIN] ? x->v[A_CEN] - x->v[A_MIN] : x->v[A_MAX] - x->v[A_CEN];
            x->v[A_SIZE] = 2 * half; x->k[A_SIZE] = YES;
        }
    }
}
static void axis_from_rect(axis_t *x, CGRect r, int axis) {
    double o = axis ? r.origin.y : r.origin.x, s = axis ? r.size.height : r.size.width;
    x->v[A_MIN] = o; x->v[A_MAX] = o + s; x->v[A_CEN] = o + s / 2; x->v[A_SIZE] = s;
    x->k[A_MIN] = x->k[A_MAX] = x->k[A_CEN] = x->k[A_SIZE] = YES;
}

- (void)_isim_solveConstraints {
    NSMutableArray<UIView *> *managed = [NSMutableArray array];
    for (UIView *s in _subs) if (!s->_translatesAutoresizingMaskIntoConstraints) [managed addObject:s];
    if (!managed.count || !active_constraints.count) return;
    NSUInteger n = managed.count;
    axis_t (*st)[2] = calloc(n, sizeof *st);
    NSMutableArray<NSLayoutConstraint *> *cs = [NSMutableArray array];
    for (NSLayoutConstraint *c in active_constraints) {
        id a = c.firstItem, b = c.secondItem;
        BOOL ma = [managed indexOfObjectIdenticalTo:a] != NSNotFound, mb = b && [managed indexOfObjectIdenticalTo:b] != NSNotFound;
        if (ma || mb) [cs addObject:c];
    }
    [cs sortUsingComparator:^NSComparisonResult(NSLayoutConstraint *x, NSLayoutConstraint *y) { return x.priority > y.priority ? NSOrderedAscending : x.priority < y.priority ? NSOrderedDescending : NSOrderedSame; }];

    /* value of (item, attr) if known; YES on success */
    BOOL (^value)(id, NSLayoutAttribute, double *) = ^BOOL(id item, NSLayoutAttribute attr, double *out) {
        int axis = attr_axis(attr), slot = attr_slot(attr);
        axis_t tmp = { { 0 }, { 0 } }, *x = &tmp;
        NSUInteger idx = [managed indexOfObjectIdenticalTo:item];
        if (idx != NSNotFound) x = &st[idx][axis];
        else if (item == self) axis_from_rect(x, self.bounds, axis);
        else if ([item isKindOfClass:[UILayoutGuide class]]) {
            UILayoutGuide *g = item; UIView *owner = g.owningView;
            if (!owner) return NO;
            CGRect f = owner == self ? g.layoutFrame : [owner convertRect:g.layoutFrame toView:self];
            NSUInteger oi = [managed indexOfObjectIdenticalTo:owner];
            if (oi != NSNotFound) {           /* guide of a managed sibling: only usable once the sibling is solved */
                if (!st[oi][0].k[A_SIZE] || !st[oi][1].k[A_SIZE] || !st[oi][0].k[A_MIN] || !st[oi][1].k[A_MIN]) return NO;
                CGRect lf = g.layoutFrame;
                f = CGRectMake(st[oi][0].v[A_MIN] + lf.origin.x, st[oi][1].v[A_MIN] + lf.origin.y, lf.size.width, lf.size.height);
            }
            axis_from_rect(x, f, axis);
        } else if ([item isKindOfClass:[UIView class]]) {
            UIView *v = item;
            if (v->_superview != self) return NO;
            axis_from_rect(x, v.frame, axis);
        } else return NO;
        if (!x->k[slot]) return NO;
        *out = x->v[slot] + (slot == A_SIZE ? 0 : attr_offset(item, attr));
        return YES;
    };
    BOOL (^assign)(id, NSLayoutAttribute, double) = ^BOOL(id item, NSLayoutAttribute attr, double v) {
        NSUInteger idx = [managed indexOfObjectIdenticalTo:item];
        if (idx == NSNotFound) return NO;
        axis_t *x = &st[idx][attr_axis(attr)]; int slot = attr_slot(attr);
        if (x->k[slot]) return NO;
        x->v[slot] = v - (slot == A_SIZE ? 0 : attr_offset(item, attr)); x->k[slot] = YES;
        axis_complete(x);
        return YES;
    };

    for (int round = 0; round < 2; round++) {
        for (int pass = 0, progress = 1; progress && pass < 16; pass++) {
            progress = 0;
            for (NSLayoutConstraint *c in cs) {
                if (c.relation != NSLayoutRelationEqual) continue;
                double bv = 0;
                BOOL bk = c.secondItem ? value(c.secondItem, c.secondAttribute, &bv) : YES;
                if (bk && assign(c.firstItem, c.firstAttribute, c.multiplier * bv + c.constant)) { progress = 1; continue; }
                double av;
                if (c.secondItem && c.multiplier != 0 && value(c.firstItem, c.firstAttribute, &av) &&
                    assign(c.secondItem, c.secondAttribute, (av - c.constant) / c.multiplier)) progress = 1;
            }
        }
        if (round == 0) {      /* fall back to intrinsic / fixed sizes, clamped by inequalities, then iterate again */
            for (NSUInteger i = 0; i < n; i++) {
                CGSize fit = [managed[i] _isim_fittingSize];
                for (int axis = 0; axis < 2; axis++) {
                    axis_t *x = &st[i][axis];
                    if (x->k[A_SIZE]) continue;
                    double want = axis ? fit.height : fit.width;
                    if (want < 0) continue;
                    x->v[A_SIZE] = want; x->k[A_SIZE] = YES; axis_complete(x);
                }
            }
        }
    }
    for (NSUInteger i = 0; i < n; i++) {
        UIView *v = managed[i]; CGRect f = v.frame;
        for (int axis = 0; axis < 2; axis++) {
            axis_t *x = &st[i][axis];
            if (!x->k[A_SIZE]) { x->v[A_SIZE] = axis ? f.size.height : f.size.width; x->k[A_SIZE] = YES; axis_complete(x); }
            if (!x->k[A_MIN]) { x->v[A_MIN] = axis ? f.origin.y : f.origin.x; x->k[A_MIN] = YES; axis_complete(x); }
        }
        CGRect nf = CGRectMake(st[i][0].v[A_MIN], st[i][1].v[A_MIN], MAX(0, st[i][0].v[A_SIZE]), MAX(0, st[i][1].v[A_SIZE]));
        if (!CGRectEqualToRect(nf, f)) v.frame = nf;
    }
    free(st);
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
    if (!CGAffineTransformIsIdentity(_transform)) {
        isim_gfx_translate(sz.width / 2 + _transform.tx, sz.height / 2 + _transform.ty);
        isim_gfx_scale(_transform.a, _transform.d);
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

