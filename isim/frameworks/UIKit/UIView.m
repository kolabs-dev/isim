/* isim UIKit: UIResponder, UIView, layout guides, NSLayoutConstraint/anchors and a small
 * constraint resolver (ARC).
 *
 * Auto Layout: a Cassowary solver (Cassowary.c) per window; see "Auto Layout engine" below. */
#import "UIKitPrivate.h"
#import "CAPrivate.h"
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
    @public struct anim_state *_anim;                            /* running property animations (presentation values) */
    UITraitCollection *_traitCache, *_traitReported; unsigned _traitGen;   /* traits (UITraits.m) */
    UIViewTintAdjustmentMode _tintMode;
    id<UITraitOverrides> _traitOverrides;
    double *_vfx;                                                /* SwiftUI visual effects (_isim_setVisualEffect:), 32 values */
}
@end
/* view animation engine (bottom of this file) */
enum { AK_FRAME, AK_ALPHA, AK_TRANSFORM, AK_BG, AK_RADIUS, AK_BORDERW, AK_BORDERCOLOR, AK_SHADOWOP, AK_SHADOWRAD, AK_SHADOWOFF, AK_COUNT };
static void anim_set(UIView *v, int key, const double *model_old, const double *model_new, int n);
static BOOL anim_presentation(UIView *v, int key, double *out);
static BOOL anim_capturing(void);
static void anim_rebase(UIView *v, int key, const double *model_old, const double *model_new, int n);
static void anim_remove_all(UIView *v);

/* a view's own layer: corner radius, border and shadow changes animate inside animation blocks (views in a window) */
@interface __IsimViewLayer : CALayer { @public __weak UIView *_isim_view; }
@end
static void anim_layer_changed(UIView *v, int key, const double *old, const double *nw, int n) {
    if (!v) return;
    if (anim_capturing() && v.window) anim_set(v, key, old, nw, n); else if (v->_anim) anim_rebase(v, key, old, nw, n);
}
static void cg_rgba(CGColorRef c, double out[4]) {
    if (!c) { out[0] = out[1] = out[2] = out[3] = 0; return; }
    isim_cg_color_rgba(c, out);          /* sRGB, whatever the color's space */
}
@implementation __IsimViewLayer
- (void)setCornerRadius:(CGFloat)r { double a = self.cornerRadius, b = r; anim_layer_changed(_isim_view, AK_RADIUS, &a, &b, 1); [super setCornerRadius:r]; }
- (void)setBorderWidth:(CGFloat)w { double a = self.borderWidth, b = w; anim_layer_changed(_isim_view, AK_BORDERW, &a, &b, 1); [super setBorderWidth:w]; }
- (void)setShadowOpacity:(float)o { double a = self.shadowOpacity, b = o; anim_layer_changed(_isim_view, AK_SHADOWOP, &a, &b, 1); [super setShadowOpacity:o]; isim_ui_set_needs_display(); }
- (void)setShadowRadius:(CGFloat)r { double a = self.shadowRadius, b = r; anim_layer_changed(_isim_view, AK_SHADOWRAD, &a, &b, 1); [super setShadowRadius:r]; isim_ui_set_needs_display(); }
- (void)setShadowOffset:(CGSize)o { CGSize c = self.shadowOffset; double a[2] = { c.width, c.height }, b[2] = { o.width, o.height }; anim_layer_changed(_isim_view, AK_SHADOWOFF, a, b, 2); [super setShadowOffset:o]; isim_ui_set_needs_display(); }
- (void)setBorderColor:(CGColorRef)c {
    double a[4], b[4]; cg_rgba(self.borderColor, a); cg_rgba(c, b);
    if (!self.borderColor) { memcpy(a, b, sizeof a); a[3] = 0; }
    anim_layer_changed(_isim_view, AK_BORDERCOLOR, a, b, 4);
    [super setBorderColor:c];
}
- (void)removeAllAnimations { UIView *v = _isim_view; if (v) anim_remove_all(v); [super removeAllAnimations]; }
/* a snapshot with the in-flight values (frame is the transformed bounding box, like Core Animation) */
- (instancetype)presentationLayer {
    UIView *v = _isim_view;
    if (!v) return self;
    isim_ui_animations_tick();                       /* values for now, not for the last rendered frame */
    double x[6];
    CGRect f = v.frame; CGAffineTransform t = v.transform; double alpha = v.alpha;
    CALayer *p = [CALayer new];
    p.cornerRadius = self.cornerRadius; p.borderWidth = self.borderWidth; p.shadowOpacity = self.shadowOpacity; p.shadowRadius = self.shadowRadius;
    p.shadowOffset = self.shadowOffset; p.borderColor = self.borderColor; p.shadowColor = self.shadowColor; p.backgroundColor = v.backgroundColor.CGColor ?: self.backgroundColor;
    if (anim_presentation(v, AK_FRAME, x)) f = CGRectMake(x[0], x[1], x[2], x[3]);
    if (anim_presentation(v, AK_TRANSFORM, x)) t = (CGAffineTransform){ x[0], x[1], x[2], x[3], x[4], x[5] };
    if (anim_presentation(v, AK_ALPHA, x)) alpha = x[0];
    if (anim_presentation(v, AK_RADIUS, x)) p.cornerRadius = x[0];
    if (anim_presentation(v, AK_BORDERW, x)) p.borderWidth = x[0];
    if (anim_presentation(v, AK_SHADOWOP, x)) p.shadowOpacity = (float)x[0];
    if (anim_presentation(v, AK_SHADOWRAD, x)) p.shadowRadius = x[0];
    if (anim_presentation(v, AK_SHADOWOFF, x)) p.shadowOffset = CGSizeMake(x[0], x[1]);
    if (anim_presentation(v, AK_BG, x)) p.backgroundColor = [UIColor colorWithRed:x[0] green:x[1] blue:x[2] alpha:x[3]].CGColor;
    p.bounds = CGRectMake(0, 0, f.size.width, f.size.height);
    CGPoint c = CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f));
    CGRect r = CGRectApplyAffineTransform(CGRectMake(-f.size.width / 2, -f.size.height / 2, f.size.width, f.size.height), t);
    p.frame = CGRectOffset(r, c.x, c.y);
    p.opacity = (float)(alpha * self.opacity);
    if ([self _isim_hasAnimations]) [self _isim_applyAnimationsTo:p at:CACurrentMediaTime()];   /* Core Animation (CoreAnimation.m) */
    return (id)p;
}
@end

@implementation UIView
@synthesize layer = _layer;
+ (Class)layerClass { return [__IsimViewLayer class]; }
- (instancetype)init { return [self initWithFrame:CGRectZero]; }
- (instancetype)initWithCoder:(NSCoder *)c { extern id isim_ib_init_with_coder(id, NSCoder *); return isim_ib_init_with_coder(self, c); }   /* UIStoryboard.m */
- (void)encodeWithCoder:(NSCoder *)c {}   /* isim: archiving is not implemented */
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super init])) {
        _frame = frame; _subs = [NSMutableArray array]; _alpha = 1; _userInteractionEnabled = YES; _autoresizesSubviews = YES;
        _translatesAutoresizingMaskIntoConstraints = YES; _layer = [[[self class] layerClass] new]; [_layer _isim_setOwnerView:self]; _needsLayout = YES;
        if ([_layer isKindOfClass:[__IsimViewLayer class]]) ((__IsimViewLayer *)_layer)->_isim_view = self;
        _layoutMargins = UIEdgeInsetsMake(8, 8, 8, 8); _clearsContextBeforeDrawing = YES; _multipleTouchEnabled = NO;
        _transform = CGAffineTransformIdentity;
        _hug[0] = _hug[1] = UILayoutPriorityDefaultLow; _resist[0] = _resist[1] = UILayoutPriorityDefaultHigh;
    }
    return self;
}
- (void)dealloc { free(_anim); free(_vfx); }
- (void)_isim_removeAllAnimations { anim_remove_all(self); }
/* colour matrix, blur, content drop shadow and blend mode applied to this view and its subviews as one group
   (layout: isim_gfx_pop_group_filtered); NULL removes them */
- (void)_isim_setVisualEffect:(const double *)values {
    if (!values) { if (_vfx) { free(_vfx); _vfx = NULL; isim_ui_set_needs_display(); } return; }
    if (_vfx && !memcmp(_vfx, values, 32 * sizeof(double))) return;
    if (!_vfx) _vfx = malloc(32 * sizeof(double));
    memcpy(_vfx, values, 32 * sizeof(double));
    isim_ui_set_needs_display();
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
    if (anim_capturing() && !CGRectEqualToRect(f, _frame)) {
        double a[4] = { _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height }, b[4] = { f.origin.x, f.origin.y, f.size.width, f.size.height };
        anim_set(self, AK_FRAME, a, b, 4);
    } else if (_anim && !CGRectEqualToRect(f, _frame)) {
        double a[4] = { _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height }, b[4] = { f.origin.x, f.origin.y, f.size.width, f.size.height };
        anim_rebase(self, AK_FRAME, a, b, 4);
    }
    _frame = f;
    if (!CGSizeEqualToSize(old, f.size) && !_superview && [self isKindOfClass:[UIWindow class]]) isim_ui_traits_invalidate(self);   /* size classes */
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
- (void)setTransform:(CGAffineTransform)t {
    if (anim_capturing() && !CGAffineTransformEqualToTransform(t, _transform)) {
        double a[6] = { _transform.a, _transform.b, _transform.c, _transform.d, _transform.tx, _transform.ty }, b[6] = { t.a, t.b, t.c, t.d, t.tx, t.ty };
        anim_set(self, AK_TRANSFORM, a, b, 6);
    }
    _transform = t; isim_ui_set_needs_display();
}
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
void (*isim_ui_appearance_hook)(UIView *v);          /* UIAppearance.m: proxies apply when a view first enters a window */
- (void)_isim_movedToWindow:(UIWindow *)w {
    if (_window == w) return;
    if (w && isim_ui_appearance_hook) isim_ui_appearance_hook(self);
    /* a first responder leaving the window resigns (e.g. its page was popped), so the keyboard goes away */
    if (!w && (UIResponder *)self == first_responder) [self resignFirstResponder];
    [self willMoveToWindow:w];
    _window = w;
    if (w) isim_ui_traits_invalidate(self); else _traitReported = nil;
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
- (void)setBackgroundColor:(UIColor *)c {
    if (anim_capturing() && c != _backgroundColor) {
        double a[4] = { 0 }, b[4] = { 0 };
        if (_backgroundColor) isim_ui_rgba(_backgroundColor, a); else if (c) { isim_ui_rgba(c, a); a[3] = 0; }
        if (c) isim_ui_rgba(c, b); else { memcpy(b, a, sizeof b); b[3] = 0; }
        anim_set(self, AK_BG, a, b, 4);
    }
    _backgroundColor = c; isim_ui_set_needs_display();
}
- (void)setAlpha:(CGFloat)a {
    if (anim_capturing() && a != _alpha) { double x = _alpha, y = a; anim_set(self, AK_ALPHA, &x, &y, 1); }
    _alpha = a; isim_ui_set_needs_display();
}
- (void)setHidden:(BOOL)h {
    if (_hidden == h) return;
    _hidden = h; isim_ui_set_needs_display();
    if ([_superview isKindOfClass:[UIStackView class]]) { isim_ui_constraints_changed(); [_superview setNeedsLayout]; }
}
- (void)setClipsToBounds:(BOOL)c { _clipsToBounds = c; isim_ui_set_needs_display(); }
- (UIColor *)_isim_undimmedTint { return _tint ?: (_superview ? [_superview _isim_undimmedTint] : (isim_ui_accent_color() ?: UIColor.systemBlueColor)); }
- (UIColor *)tintColor {
    if (self.tintAdjustmentMode == UIViewTintAdjustmentModeDimmed) return [UIColor colorWithWhite:0.56 alpha:1];   /* dimmed: a desaturated gray */
    return [self _isim_undimmedTint];
}
- (void)setTintColor:(UIColor *)c { _tint = c; [self _isim_tintChanged]; }
- (void)_isim_tintChanged { [self tintColorDidChange]; for (UIView *s in _subs) if (!s->_tint || s->_tintMode == UIViewTintAdjustmentModeAutomatic) [s _isim_tintChanged]; isim_ui_set_needs_display(); }
- (UIViewTintAdjustmentMode)tintAdjustmentMode {
    for (UIView *v = self; v; v = v->_superview) if (v->_tintMode != UIViewTintAdjustmentModeAutomatic) return v->_tintMode;
    return UIViewTintAdjustmentModeNormal;
}
- (void)setTintAdjustmentMode:(UIViewTintAdjustmentMode)m {
    if (m == _tintMode) return;
    UIViewTintAdjustmentMode before = self.tintAdjustmentMode;
    _tintMode = m;
    if (self.tintAdjustmentMode != before) [self _isim_tintChanged];
}
- (void)tintColorDidChange {}
/* traits: the parent's (a presented controller's view: the presenter's; a window: its scene's, sized by the window),
   then the view controller's overrides, then the view's own (UITraits.m) */
- (UITraitCollection *)_isim_inheritedTraits {
    UIViewController *vc = _vc, *presenter = vc.presentingViewController;
    if (presenter && presenter.presentedViewController == vc && presenter != vc) return presenter.traitCollection;
    if (_superview) return _superview.traitCollection;
    if ([self isKindOfClass:[UIWindow class]]) return [((UIWindow *)self).windowScene _isim_traitsForWindowSize:_frame.size];
    return isim_ui_screen_traits();
}
- (UITraitCollection *)traitCollection {
    unsigned g = isim_ui_trait_generation();
    if (_traitCache && _traitGen == g) return _traitCache;
    UITraitCollection *t = [self _isim_inheritedTraits];
    UIViewController *vc = _vc;
    if (vc) t = [vc _isim_traitsFromBase:t];
    t = isim_ui_apply_overrides(t, _traitOverrides, _overrideUserInterfaceStyle);
    _traitCache = t; _traitGen = g;
    return t;
}
- (BOOL)_isim_hasTraitOverrides { return _overrideUserInterfaceStyle != UIUserInterfaceStyleUnspecified || !isim_ui_trait_overrides_empty(_traitOverrides); }
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)s {
    if (s == _overrideUserInterfaceStyle) return;
    _overrideUserInterfaceStyle = s; isim_ui_traits_invalidate(self); isim_ui_set_needs_display();
}
- (id<UITraitOverrides>)traitOverrides {
    if (!_traitOverrides) { __weak UIView *w = self; _traitOverrides = isim_ui_new_trait_overrides(^{ UIView *v = w; if (v) { isim_ui_traits_invalidate(v); isim_ui_set_needs_display(); } }); }
    return _traitOverrides;
}
- (void)updateTraitsIfNeeded { isim_ui_traits_flush(); }
/* the trait change pass (isim_ui_traits_flush): what changed since the last pass gets traitCollectionDidChange: */
- (void)_isim_traitsWalk {
    if (!_window && ![self isKindOfClass:[UIWindow class]]) return;
    UITraitCollection *t = self.traitCollection, *prev = _traitReported;
    _traitReported = t;
    UIViewController *vc = _vc;
    if (vc) [vc _isim_traitsCheck];
    if (prev && ![prev isEqual:t]) [self traitCollectionDidChange:prev];
    for (UIView *s in [_subs copy]) [s _isim_traitsWalk];
}
- (void)setNeedsDisplay { isim_ui_set_needs_display(); }
- (void)setNeedsDisplayInRect:(CGRect)r { isim_ui_set_needs_display(); }
- (void)drawRect:(CGRect)r {}
- (void)_isim_drawContent {}
- (void)_isim_drawOverlay {}
- (void)_isim_didSolve {}

/* ---- coordinates ---- */
/* a point in a view's bounds -> its superview, and back: transforms apply about the view's center, as drawn */
static inline CGPoint to_superview(UIView *v, CGPoint p, CGRect frame, CGPoint origin, CGAffineTransform t) {
    p.x -= origin.x; p.y -= origin.y;
    if (!CGAffineTransformIsIdentity(t)) {
        double cx = frame.size.width / 2, cy = frame.size.height / 2, x = p.x - cx, y = p.y - cy;
        p.x = t.a * x + t.c * y + t.tx + cx; p.y = t.b * x + t.d * y + t.ty + cy;
    }
    p.x += frame.origin.x; p.y += frame.origin.y;
    return p;
}
static inline CGPoint from_superview(UIView *v, CGPoint p, CGRect frame, CGPoint origin, CGAffineTransform t) {
    p.x -= frame.origin.x; p.y -= frame.origin.y;
    if (!CGAffineTransformIsIdentity(t)) {
        CGAffineTransform inv = CGAffineTransformInvert(t);
        double cx = frame.size.width / 2, cy = frame.size.height / 2, x = p.x - cx, y = p.y - cy;
        p.x = inv.a * x + inv.c * y + inv.tx + cx; p.y = inv.b * x + inv.d * y + inv.ty + cy;
    }
    p.x += origin.x; p.y += origin.y;
    return p;
}
- (CGPoint)_isim_toWindow:(CGPoint)p {
    for (UIView *v = self; v && ![v isKindOfClass:[UIWindow class]]; v = v->_superview) p = to_superview(v, p, v->_frame, v->_boundsOrigin, v->_transform);
    return p;
}
- (CGPoint)_isim_fromWindow:(CGPoint)p {
    UIView *chain[64]; int n = 0;
    for (UIView *v = self; v && ![v isKindOfClass:[UIWindow class]] && n < 64; v = v->_superview) chain[n++] = v;
    while (n > 0) { UIView *v = chain[--n]; p = from_superview(v, p, v->_frame, v->_boundsOrigin, v->_transform); }
    return p;
}
- (CGPoint)convertPoint:(CGPoint)p toView:(UIView *)v { CGPoint w = [self _isim_toWindow:p]; return v ? [v _isim_fromWindow:w] : w; }
- (CGPoint)convertPoint:(CGPoint)p fromView:(UIView *)v { CGPoint w = v ? [v _isim_toWindow:p] : p; return [self _isim_fromWindow:w]; }
- (CGRect)convertRect:(CGRect)r toView:(UIView *)v { r.origin = [self convertPoint:r.origin toView:v]; return r; }
- (CGRect)convertRect:(CGRect)r fromView:(UIView *)v { r.origin = [self convertPoint:r.origin fromView:v]; return r; }
- (CGPoint)convertPoint:(CGPoint)p toCoordinateSpace:(id<UICoordinateSpace>)s { return [s isKindOfClass:[UIView class]] ? [self convertPoint:p toView:(UIView *)s] : [self _isim_toWindow:p]; }
- (CGPoint)convertPoint:(CGPoint)p fromCoordinateSpace:(id<UICoordinateSpace>)s { return [s isKindOfClass:[UIView class]] ? [self convertPoint:p fromView:(UIView *)s] : [self _isim_fromWindow:p]; }

/* ---- safe area & margins ---- */
/* The safe area in window coordinates for content inside `v`: the device's safe area, narrowed by the
 * additionalSafeAreaInsets of every view controller whose view encloses `v` (navigation/tab bars). */
CGRect isim_ui_safe_rect(UIView *v) {
    UIWindow *w = v.window;
    if (!w) return CGRectNull;
    const struct isim_device *d = isim_ui_device();
    CGRect r = CGRectMake(d->safe_left, d->safe_top, MAX(0, w.bounds.size.width - d->safe_left - d->safe_right), MAX(0, w.bounds.size.height - d->safe_top - d->safe_bottom));
    NSMutableArray *chain = [NSMutableArray array];
    for (UIView *x = v; x && x != (UIView *)w; x = x.superview) [chain insertObject:x atIndex:0];
    for (UIView *a in chain) {
        UIViewController *vc = [a _isim_viewController];
        if (!vc) continue;
        UIEdgeInsets add = vc.additionalSafeAreaInsets;
        if (UIEdgeInsetsEqualToEdgeInsets(add, UIEdgeInsetsZero)) continue;
        CGRect af = a.superview ? [a.superview convertRect:a.frame toView:nil] : a.frame;
        CGRect inner = CGRectIntersection(r, af);
        if (CGRectIsNull(inner)) inner = af;
        r = UIEdgeInsetsInsetRect(inner, add);
    }
    return r;
}
UIEdgeInsets isim_ui_safe_insets_for_rect(UIView *v, CGRect inWin) {
    CGRect r = isim_ui_safe_rect(v);
    if (CGRectIsNull(r)) return UIEdgeInsetsZero;
    CGFloat top = MAX(0, CGRectGetMinY(r) - inWin.origin.y), bottom = MAX(0, CGRectGetMaxY(inWin) - CGRectGetMaxY(r));
    CGFloat left = MAX(0, CGRectGetMinX(r) - inWin.origin.x), right = MAX(0, CGRectGetMaxX(inWin) - CGRectGetMaxX(r));
    return UIEdgeInsetsMake(MIN(top, inWin.size.height), MIN(left, inWin.size.width), MIN(bottom, inWin.size.height), MIN(right, inWin.size.width));
}
- (UIEdgeInsets)safeAreaInsets {
    if (!_window) return UIEdgeInsetsZero;
    return isim_ui_safe_insets_for_rect(self, [self convertRect:self.bounds toView:nil]);
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
    if (isim_ui_os_major() >= 26) {                          /* iOS 26: properties before layout */
        UIViewController *pvc = self._isim_viewController;
        if (pvc) [pvc updatePropertiesIfNeeded];
        [self updatePropertiesIfNeeded];
    }
    if (_needsLayout) {
        _needsLayout = NO;
        UIViewController *vc = self._isim_viewController;
        isim_ui_push_traits(self.traitCollection);           /* UITraitCollection.current while laying out (iOS 17) */
        __weak UIView *weakSelf = self;
        /* automatic observation tracking (iOS 26): @Observable reads here invalidate the layout (UIUpdates.m) */
        if (vc) isim_ui_tracked(vc, @selector(viewWillLayoutSubviews), ^{ [vc viewWillLayoutSubviews]; }, ^{ [weakSelf setNeedsLayout]; isim_ui_set_needs_layout(); });
        isim_ui_tracked(self, @selector(layoutSubviews), ^{ [self layoutSubviews]; }, ^{ [weakSelf setNeedsLayout]; isim_ui_set_needs_layout(); });
        if (vc) isim_ui_tracked(vc, @selector(viewDidLayoutSubviews), ^{ [vc viewDidLayoutSubviews]; }, ^{ [weakSelf setNeedsLayout]; isim_ui_set_needs_layout(); });
        isim_ui_pop_traits();
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
        if (fabs(f.size.width - v->_alUsedWidth) > 0.5 && (([v isKindOfClass:[UILabel class]] && ((UILabel *)v).numberOfLines != 1)
            || ([v respondsToSelector:@selector(_isim_heightTracksWidth)] && [(id)v _isim_heightTracksWidth]))) again = YES;
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
        CGPoint q = from_superview(s, p, s->_frame, s->_boundsOrigin, s->_transform);
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
    /* presentation values: model values, or the in-flight value of a running animation */
    CGRect frame = _frame; CGFloat alpha = _alpha; CGAffineTransform xf = _transform;
    double pv[6]; BOOL bgAnim = NO; double bgv[4] = { 0 };
    double radius = _layer.cornerRadius, borderW = _layer.borderWidth, shadowOp = _layer.shadowOpacity, shadowRad = _layer.shadowRadius;
    CGSize shadowOff = _layer.shadowOffset; double borderC[4]; BOOL borderAnim = NO;
    if (_anim) {
        if (anim_presentation(self, AK_RADIUS, pv)) radius = fmax(0, pv[0]);
        if (anim_presentation(self, AK_BORDERW, pv)) borderW = fmax(0, pv[0]);
        if (anim_presentation(self, AK_SHADOWOP, pv)) shadowOp = fmin(1, fmax(0, pv[0]));
        if (anim_presentation(self, AK_SHADOWRAD, pv)) shadowRad = fmax(0, pv[0]);
        if (anim_presentation(self, AK_SHADOWOFF, pv)) shadowOff = CGSizeMake(pv[0], pv[1]);
        if (anim_presentation(self, AK_BORDERCOLOR, borderC)) borderAnim = YES;
        if (anim_presentation(self, AK_FRAME, pv)) frame = CGRectMake(pv[0], pv[1], fmax(0, pv[2]), fmax(0, pv[3]));
        if (anim_presentation(self, AK_ALPHA, pv)) alpha = fmin(1, fmax(0, pv[0]));
        if (anim_presentation(self, AK_TRANSFORM, pv)) xf = (CGAffineTransform){ pv[0], pv[1], pv[2], pv[3], pv[4], pv[5] };
        if (anim_presentation(self, AK_BG, bgv)) bgAnim = YES;
    }
    /* Core Animation on the view's layer: CA animations, 3D transforms (CoreAnimation.m) */
    double caOpacity = _layer.opacity; CATransform3D t3d; BOOL has3d = NO;
    isim_ca_view_values(_layer, &frame, &xf, &caOpacity, &radius, &borderW, borderC, &borderAnim, bgv, &bgAnim, &shadowOp, &shadowRad, &shadowOff, &t3d, &has3d);
    if (isim_ca_flat_view == self) { frame.origin = CGPointZero; xf = CGAffineTransformIdentity; has3d = NO; isim_ca_flat_view = nil; }
    if (_hidden || alpha <= 0.01 || _layer.hidden) return;
    if (has3d) { isim_ca_render_view_3d(self, frame, t3d); return; }
    CGSize sz = frame.size;
    isim_gfx_save();
    isim_gfx_translate(frame.origin.x, frame.origin.y);
    if (!CGAffineTransformIsIdentity(xf)) {      /* about the center, like UIKit */
        isim_gfx_translate(sz.width / 2, sz.height / 2);
        isim_gfx_concat(xf.a, xf.b, xf.c, xf.d, xf.tx, xf.ty);
        isim_gfx_translate(-sz.width / 2, -sz.height / 2);
    }
    /* a window, a view controller's view and a view with trait overrides draw with their own traits (dynamic colors) */
    BOOL pushedStyle = _vc || [self _isim_hasTraitOverrides] || !_superview;
    if (pushedStyle) isim_ui_push_traits(self.traitCollection);
    double a = alpha * caOpacity;
    CALayer *maskLayer = _layer.mask;
    BOOL group = a < 0.999 || maskLayer || _vfx;
    if (_vfx) isim_gfx_push_group();                 /* the effects apply to the masked content */
    if (group && (!_vfx || maskLayer)) isim_gfx_push_group();
    BOOL caTransition = isim_ca_view_transition_begin(_layer, sz);
    double bg[4];
    if (bgAnim) memcpy(bg, bgv, sizeof bg);
    else if (_backgroundColor) isim_ui_rgba(_backgroundColor, bg);
    else if (_layer.backgroundColor) cg_rgba(_layer.backgroundColor, bg);
    else bg[3] = 0;
    /* drop shadow of the shadow path or the background shape, Gaussian-blurred (CoreAnimation.m) */
    if ((bg[3] > 0 || _layer.shadowPath) && shadowOp > 0 && _layer.shadowColor) isim_ca_view_shadow(_layer, sz, radius, shadowOp, shadowRad, shadowOff);
    if (bg[3] > 0) isim_gfx_fill_rounded(0, 0, sz.width, sz.height, radius, bg);
    BOOL clip = _clipsToBounds || _layer.masksToBounds;
    if (clip) { isim_gfx_save(); isim_gfx_clip_rounded(0, 0, sz.width, sz.height, radius); }
    [self _isim_drawContent];
    [_layer _isim_renderLayerContents];      /* drawInContext: overrides (AVPlayerLayer) and sublayers */
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
    if (borderW > 0 && (_layer.borderColor || borderAnim)) {
        double bc[4]; if (borderAnim) memcpy(bc, borderC, sizeof bc); else cg_rgba(_layer.borderColor, bc);
        isim_gfx_stroke_rounded(borderW / 2, borderW / 2, sz.width - borderW, sz.height - borderW, fmax(0, radius - borderW / 2), borderW, bc);
    }
    if (caTransition) isim_ca_view_transition_end(_layer, sz);
    if (group && maskLayer) { isim_gfx_push_group(); isim_gfx_save(); isim_ca_render_mask(maskLayer); isim_gfx_restore(); isim_gfx_pop_group_masked(_vfx ? 1 : a); }
    else if (group && !_vfx) isim_gfx_pop_group(a);
    if (_vfx) isim_gfx_pop_group_filtered(_vfx, a, 0, 0, sz.width, sz.height);
    if (pushedStyle) isim_ui_pop_traits();
    isim_gfx_restore();
}

/* ---- animation ---- */
+ (void)animateWithDuration:(NSTimeInterval)d animations:(void (^)(void))a { [self animateWithDuration:d delay:0 options:0 animations:a completion:nil]; }
+ (void)animateWithDuration:(NSTimeInterval)d animations:(void (^)(void))a completion:(void (^)(BOOL))c { [self animateWithDuration:d delay:0 options:0 animations:a completion:c]; }
+ (void)animateWithDuration:(NSTimeInterval)d delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)damp initialSpringVelocity:(CGFloat)v options:(UIViewAnimationOptions)o animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    isim_ui_animate(d, delay, o, 1, damp, v, a, c);
}
+ (void)animateWithDuration:(NSTimeInterval)d delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)o animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    isim_ui_animate(d, delay, o, 0, 0, 0, a, c);
}
/* iOS 17: spring by perceptual duration and bounce (0 = critically damped) */
+ (void)animateWithSpringDuration:(NSTimeInterval)d bounce:(CGFloat)bounce initialSpringVelocity:(CGFloat)v delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)o animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    isim_ui_animate(d * 1.6, delay, o, 1, bounce >= 0 ? 1 - bounce : 1 / (1 + bounce), v, a, c);
}
+ (void)transitionWithView:(UIView *)view duration:(NSTimeInterval)d options:(UIViewAnimationOptions)o animations:(void (^)(void))a completion:(void (^)(BOOL))c {
    extern void isim_ui_transition_with_view(UIView *, double, UIViewAnimationOptions, void (^)(void), void (^)(BOOL));
    isim_ui_transition_with_view(view, d, o, a, c);       /* UIAnimation.m */
}
+ (void)performWithoutAnimation:(void (^)(void))a { isim_ui_without_animation(a); }
+ (void)setAnimationsEnabled:(BOOL)e { isim_ui_set_animations_enabled(e); }
+ (BOOL)areAnimationsEnabled { return isim_ui_animations_enabled(); }
+ (NSTimeInterval)inheritedAnimationDuration { return isim_ui_inherited_duration(); }
@end


/* ================= view animations =================
 * Core Animation-style: inside an animation block, setting frame/center/bounds, alpha, transform,
 * backgroundColor or the layer's cornerRadius/border/shadow changes the model value at once and records a
 * track from the current presentation value to the new one. Each frame the tracks are evaluated (timing
 * curve, custom cubic Bézier or spring; delay, repeat, autoreverse) and rendering uses the in-flight values.
 * A block's completion runs when its tracks end.
 *
 * Keyframe animations (UIView.animateKeyframes) give a track further segments on the same clock; the
 * overall timing curve warps the whole keyframe timeline.
 *
 * Timelines (UIViewPropertyAnimator, interactive view-controller transitions): tracks captured for a
 * timeline read its virtual clock, which can be paused, scrubbed, reversed or run at another speed; they
 * stay until the timeline finishes at its end, its start (model values go back) or the current position. */
#define KF_MAX 16
typedef struct {
    BOOL active; int n;
    double from[6], to[6], cur[6];
    double start, dur;                      /* first segment (real or timeline time) */
    int curve;                              /* 0 ease in-out, 1 ease in, 2 ease out, 3 linear, 4 spring, 5 cubic Bézier */
    double bz[4];
    double damping, velocity;
    BOOL repeat, autoreverse;
    BOOL keyframed, discrete;               /* keyframes: extra segments, and the whole timeline's span */
    int nkf; double kfStart[KF_MAX], kfDur[KF_MAX], kfTo[KF_MAX][6];
    double kfBase, kfTotal;
    __unsafe_unretained id group;
} anim_track;
struct anim_state { anim_track t[AK_COUNT]; };

@interface __IsimTimeline : NSObject {
@public
    double v0, t0, speed, duration;         /* virtual time = v0 + (now - t0) * speed (frozen at v0 while paused) */
    BOOL paused, autoFinish, done;
    void (^onFinish)(int position);         /* 0 end, 1 start */
    NSMutableArray *groups;                 /* groups without tracks: complete with the timeline */
    NSMutableArray *stopped;                /* tracks removed by a "current" finish: [view, key, from, to] */
}
@end
@implementation __IsimTimeline @end
static double tl_now(__IsimTimeline *tl) { return tl->paused ? tl->v0 : tl->v0 + (isim_time() - tl->t0) * tl->speed; }
static NSMutableArray<__IsimTimeline *> *timelines;    /* running timelines watched for their end */
static __IsimTimeline *capture_tl;                     /* isim_ui_timeline_capture_begin: plain animations join it */

@interface __IsimAnimationGroup : NSObject { @public void (^completion)(BOOL); int pending; BOOL closed; __IsimTimeline *timeline; }
@end
@implementation __IsimAnimationGroup
@end

typedef struct anim_ctx {
    double duration, delay; int curve; double bz[4]; double damping, velocity; BOOL repeat, autoreverse;
    BOOL keyframe, discrete; double kfBase, kfTotal;      /* inside animateKeyframes: delay/duration are relative to kfBase */
    __unsafe_unretained __IsimAnimationGroup *group; struct anim_ctx *prev;
} anim_ctx;
static anim_ctx *cur_ctx;
static int suppress_depth;
static BOOL animations_enabled = YES;
static NSMutableArray<UIView *> *animating;          /* views with active tracks (kept alive while animating, like CA) */
static NSMutableSet *live_groups;

static BOOL anim_capturing(void) { return cur_ctx && !suppress_depth && animations_enabled; }

static void group_done(__IsimAnimationGroup *g, BOOL finished) {
    if (!g || g->pending > 0 || !g->closed) return;
    void (^c)(BOOL) = g->completion; g->completion = nil;
    [live_groups removeObject:g];
    if (c) dispatch_async(dispatch_get_main_queue(), ^{ c(finished); });
}
static double ctx_clock(anim_ctx *c) { return c->group && c->group->timeline ? tl_now(c->group->timeline) : isim_time(); }

static void anim_set(UIView *v, int key, const double *model_old, const double *model_new, int n) {
    anim_ctx *c = cur_ctx;
    if (!v->_anim) v->_anim = calloc(1, sizeof *v->_anim);
    anim_track *t = &v->_anim->t[key];
    if (c->keyframe && t->active && t->keyframed && t->group == c->group && t->nkf < KF_MAX) {   /* a later keyframe of the same property */
        int i = t->nkf++;
        t->kfStart[i] = c->kfBase + c->delay; t->kfDur[i] = fmax(c->duration, 1e-4);
        memcpy(t->kfTo[i], model_new, sizeof(double) * (size_t)n);
        isim_ui_set_needs_display();
        return;
    }
    double from[6];
    if (t->active) {                                           /* retarget from where it is now (additive-like) */
        memcpy(from, t->cur, sizeof from);
        __IsimAnimationGroup *old = t->group;
        t->active = NO;
        if (old) { old->pending--; group_done(old, NO); }
    } else memcpy(from, model_old, sizeof(double) * (size_t)n);
    t->n = n;
    memcpy(t->from, from, sizeof(double) * (size_t)n);
    memcpy(t->to, model_new, sizeof(double) * (size_t)n);
    memcpy(t->cur, from, sizeof(double) * (size_t)n);
    t->keyframed = c->keyframe; t->discrete = c->discrete; t->nkf = 0;
    t->kfBase = c->kfBase; t->kfTotal = fmax(c->kfTotal, 1e-4);
    t->start = (c->keyframe ? c->kfBase : ctx_clock(c)) + c->delay;
    t->dur = c->duration > 0 ? c->duration : 0.0001;
    t->curve = c->curve; memcpy(t->bz, c->bz, sizeof t->bz); t->damping = c->damping; t->velocity = c->velocity;
    t->repeat = c->repeat; t->autoreverse = c->autoreverse;
    t->group = c->group;
    t->active = YES;
    if (c->group) c->group->pending++;
    if (!animating) animating = [NSMutableArray array];
    if ([animating indexOfObjectIdenticalTo:v] == NSNotFound) [animating addObject:v];
    isim_ui_set_needs_display();
}

static BOOL anim_presentation(UIView *v, int key, double *out) {
    if (!v->_anim || !v->_anim->t[key].active) return NO;
    memcpy(out, v->_anim->t[key].cur, sizeof(double) * (size_t)v->_anim->t[key].n);
    return YES;
}

/* cubic bezier timing (x(t) -> y) for the standard UIKit curves */
static double bezier(double x1, double y1, double x2, double y2, double x) {
    double t = x;
    for (int i = 0; i < 8; i++) {
        double cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
        double fx = ((ax * t + bx) * t + cx) * t - x, d = (3 * ax * t + 2 * bx) * t + cx;
        if (fabs(fx) < 1e-6 || fabs(d) < 1e-6) break;
        t -= fx / d;
    }
    t = fmin(1, fmax(0, t));
    double cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
    return ((ay * t + by) * t + cy) * t;
}
/* damped spring settling within `dur`; returns progress (may overshoot 1) */
static double spring(double zeta, double v0, double dur, double t) {
    if (zeta <= 0.01) zeta = 0.01;
    if (t >= dur) return 1;
    if (zeta < 1) {
        double w0 = 6.9 / (zeta * dur), wd = w0 * sqrt(1 - zeta * zeta);
        double e = exp(-zeta * w0 * t);
        return 1 - e * (cos(wd * t) + (zeta * w0 - v0 * w0) / wd * sin(wd * t));
    }
    double w0 = 9.2 / dur, e = exp(-w0 * t);
    return 1 - e * (1 + (w0 - v0 * w0) * t);
}
static double curve_at(int curve, const double *bz, double damping, double velocity, double dur, double x) {
    switch (curve) {
    case 1: return bezier(0.42, 0, 1, 1, x);
    case 2: return bezier(0, 0, 0.58, 1, x);
    case 3: return x;
    case 4: return spring(damping, velocity, dur, x * dur);
    case 5: return bezier(bz[0], bz[1], bz[2], bz[3], x);
    default: return bezier(0.42, 0, 0.58, 1, x);
    }
}
static double timing(const anim_track *t, double x, double elapsed) {
    return t->curve == 4 ? spring(t->damping, t->velocity, t->dur, elapsed) : curve_at(t->curve, t->bz, 0, 0, t->dur, x);
}
static void lerp(anim_track *t, const double *a, const double *b, double p) { for (int i = 0; i < t->n; i++) t->cur[i] = a[i] + (b[i] - a[i]) * p; }

/* keyframed track at clock time `now` (segments linear, or discrete jumps); YES once past its end */
static BOOL kf_eval(anim_track *t, double now) {
    double x = (now - t->kfBase) / t->kfTotal;
    BOOL done = x >= 1;
    double w = x <= 0 ? x : x >= 1 ? 1 : curve_at(t->curve, t->bz, t->damping, t->velocity, t->kfTotal, x);
    double tt = t->kfBase + w * t->kfTotal;
    const double *prev = t->from;
    double s = t->start, d = t->dur; const double *to = t->to;
    for (int i = -1; i < t->nkf; i++) {
        if (i >= 0) { prev = i == 0 ? t->to : t->kfTo[i - 1]; s = t->kfStart[i]; d = t->kfDur[i]; to = t->kfTo[i]; }
        if (tt < s) { lerp(t, prev, prev, 0); return done; }
        if (tt < s + d) { lerp(t, prev, to, t->discrete ? 0 : (tt - s) / d); if (t->discrete) lerp(t, to, to, 0); return done; }
    }
    lerp(t, to, to, 0);
    return done;
}

static BOOL timeline_running(__IsimTimeline *tl) { return tl && !tl->paused && !tl->done; }
static void timeline_finish(__IsimTimeline *tl, int position);

/* evaluates every running track; returns YES while any animation is running */
BOOL isim_ui_animations_tick(void) {
    /* timelines that reached their end (or their start, reversed) finish themselves */
    for (__IsimTimeline *tl in [timelines copy]) {
        if (tl->done || tl->paused || !tl->autoFinish) continue;
        double v = tl_now(tl);
        if (tl->speed > 0 && v >= tl->duration) { tl->paused = YES; tl->v0 = tl->duration; timeline_finish(tl, 0); }
        else if (tl->speed < 0 && v <= 0) { tl->paused = YES; tl->v0 = 0; timeline_finish(tl, 1); }
    }
    if (!animating.count) { for (__IsimTimeline *tl in timelines) if (timeline_running(tl)) return YES; return NO; }
    double real = isim_time();
    BOOL any = NO;
    for (UIView *v in [animating copy]) {
        BOOL viewActive = NO;
        for (int k = 0; k < AK_COUNT; k++) {
            anim_track *t = &v->_anim->t[k];
            if (!t->active) continue;
            __IsimTimeline *tl = t->group ? ((__IsimAnimationGroup *)t->group)->timeline : nil;
            double now = tl ? tl_now(tl) : real;
            BOOL done = NO;
            if (t->keyframed) {
                done = kf_eval(t, now);
                if (tl) done = NO;
            } else if (tl) {                                       /* scrubbable: clamp to the track's span, never done by itself */
                double el = fmin(t->dur, fmax(0, now - t->start));
                lerp(t, t->from, t->to, el <= 0 ? 0 : el >= t->dur ? 1 : timing(t, el / t->dur, el));
            } else {
                double el = now - t->start;
                if (el < 0) { viewActive = YES; continue; }          /* delayed: still at its start value */
                double cycle = t->dur, p, x;
                if (t->repeat) {
                    double period = t->autoreverse ? 2 * cycle : cycle, ph = fmod(el, period);
                    BOOL back = t->autoreverse && ph >= cycle;
                    double le = back ? ph - cycle : ph;
                    x = le / cycle; p = timing(t, x, le); if (back) p = 1 - p;
                } else if (t->autoreverse) {
                    if (el >= 2 * cycle) { done = YES; p = 1; }
                    else { BOOL back = el >= cycle; double le = back ? el - cycle : el; p = timing(t, le / cycle, le); if (back) p = 1 - p; }
                } else if (el >= cycle) { done = YES; p = 1; }
                else { x = el / cycle; p = timing(t, x, el); }
                lerp(t, t->from, t->to, p);
            }
            if (done) {
                t->active = NO;
                __IsimAnimationGroup *g = t->group; t->group = nil;
                if (g) { g->pending--; group_done(g, YES); }
            } else {
                viewActive = YES;
                if (!tl || timeline_running(tl)) any = YES;
            }
        }
        if (!viewActive) [animating removeObjectIdenticalTo:v];
    }
    isim_ui_set_needs_display();
    for (__IsimTimeline *tl in timelines) if (timeline_running(tl)) any = YES;
    return any;
}
BOOL isim_ui_animations_running(void) {
    for (UIView *v in animating)
        for (int k = 0; k < AK_COUNT; k++) {
            anim_track *t = &v->_anim->t[k];
            if (t->active && (!t->group || !((__IsimAnimationGroup *)t->group)->timeline || timeline_running(((__IsimAnimationGroup *)t->group)->timeline))) return YES;
        }
    for (__IsimTimeline *tl in timelines) if (timeline_running(tl)) return YES;
    return NO;
}

static void animate_ctx(anim_ctx ctx, void (^animations)(void), void (^completion)(BOOL), __IsimTimeline *tl) {
    __IsimAnimationGroup *g = [__IsimAnimationGroup new];
    g->completion = completion; g->timeline = tl;
    if (!live_groups) live_groups = [NSMutableSet set];
    [live_groups addObject:g];
    ctx.group = g; ctx.prev = cur_ctx;
    cur_ctx = &ctx;
    if (animations) animations();
    cur_ctx = ctx.prev;
    g->closed = YES;
    if (g->pending == 0) {                                   /* nothing animatable changed */
        if (tl) { if (!tl->groups) tl->groups = [NSMutableArray array]; [tl->groups addObject:g]; return; }   /* completes with the timeline */
        void (^c)(BOOL) = g->completion; g->completion = nil; [live_groups removeObject:g];
        double wait = ctx.keyframe ? ctx.kfBase + ctx.kfTotal - isim_time() : ctx.delay;
        if (c) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(fmax(0, wait) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ c(YES); });
    }
}
void isim_ui_animate(double duration, double delay, UIViewAnimationOptions o, int springy, double damping, double velocity,
                     void (^animations)(void), void (^completion)(BOOL)) {
    anim_ctx ctx = { duration, delay, springy ? 4 : (int)((o >> 16) & 3), { 0 }, damping, velocity, (o & (1 << 3)) != 0, (o & (1 << 4)) != 0 };
    animate_ctx(ctx, animations, completion, capture_tl);
}
void isim_ui_without_animation(void (^block)(void)) { suppress_depth++; if (block) block(); suppress_depth--; }
void isim_ui_set_animations_enabled(BOOL e) { animations_enabled = e; }
BOOL isim_ui_animations_enabled(void) { return animations_enabled; }
double isim_ui_inherited_duration(void) { return anim_capturing() ? (cur_ctx->keyframe ? cur_ctx->kfTotal : cur_ctx->duration) : 0; }

/* ---- keyframes ---- */
void isim_ui_animate_keyframes(double duration, double delay, NSUInteger options, void (^animations)(void), void (^completion)(BOOL)) {
    int mode = (int)((options >> 10) & 7);                   /* calculation mode: 1 discrete; linear/paced/cubic are linear here */
    anim_ctx ctx = { duration, 0, (int)((options >> 16) & 3), { 0 }, 0, 0, NO, NO, YES, mode == 1, (capture_tl ? tl_now(capture_tl) : isim_time()) + delay, fmax(duration, 1e-4) };
    animate_ctx(ctx, animations, completion, capture_tl);
}
void isim_ui_add_keyframe(double relStart, double relDuration, void (^animations)(void)) {
    anim_ctx *c = cur_ctx;
    if (!c || !c->keyframe) { if (animations) animations(); return; }     /* outside animateKeyframes: applies at once */
    anim_ctx k = *c;
    k.delay = fmax(0, relStart) * c->kfTotal; k.duration = fmax(0, relDuration) * c->kfTotal;
    k.prev = c;
    cur_ctx = &k;
    if (animations) animations();
    cur_ctx = c;
}

/* ---- timelines (UIViewPropertyAnimator, interactive transitions) ---- */
id isim_ui_timeline_create(double duration, void (^onFinish)(int position)) {
    __IsimTimeline *tl = [__IsimTimeline new];
    tl->duration = fmax(duration, 1e-4); tl->speed = 1; tl->paused = YES; tl->autoFinish = YES; tl->onFinish = [onFinish copy];
    if (!timelines) timelines = [NSMutableArray array];
    [timelines addObject:tl];
    return tl;
}
double isim_ui_timeline_time(id o) { return tl_now(o); }
void isim_ui_timeline_capture_begin(id o) { capture_tl = o; }
void isim_ui_timeline_capture_end(void) { capture_tl = nil; }
double isim_ui_timeline_duration(id o) { return ((__IsimTimeline *)o)->duration; }
void isim_ui_timeline_set(id o, double time, BOOL paused, double speed) {
    __IsimTimeline *tl = o;
    tl->v0 = time; tl->t0 = isim_time(); tl->paused = paused; tl->speed = speed;
    if (!tl->done && [timelines indexOfObjectIdenticalTo:tl] == NSNotFound) [timelines addObject:tl];
    isim_ui_set_needs_display();
}
void isim_ui_timeline_set_duration(id o, double duration) { ((__IsimTimeline *)o)->duration = fmax(duration, 1e-4); }
void isim_ui_timeline_set_autofinish(id o, BOOL a) { ((__IsimTimeline *)o)->autoFinish = a; }
/* curve: 0 ease in-out, 1 ease in, 2 ease out, 3 linear, 4 spring (damping ratio, velocity), 5 cubic Bézier (bz) */
void isim_ui_timeline_capture(id o, double duration, double delay, int curve, const double *bz, double damping, double velocity, void (^animations)(void), void (^completion)(BOOL)) {
    anim_ctx ctx = { duration, delay, curve, { 0 }, damping, velocity };
    if (bz) memcpy(ctx.bz, bz, sizeof ctx.bz);
    animate_ctx(ctx, animations, completion, o);
}
static void anim_apply_model(UIView *v, int key, const double *x) {
    suppress_depth++;
    switch (key) {
    case AK_FRAME: v.frame = CGRectMake(x[0], x[1], x[2], x[3]); break;
    case AK_ALPHA: v.alpha = x[0]; break;
    case AK_TRANSFORM: v.transform = (CGAffineTransform){ x[0], x[1], x[2], x[3], x[4], x[5] }; break;
    case AK_BG: v.backgroundColor = x[3] > 0 ? [UIColor colorWithRed:x[0] green:x[1] blue:x[2] alpha:x[3]] : v.backgroundColor ? [UIColor colorWithRed:x[0] green:x[1] blue:x[2] alpha:0] : nil; break;
    case AK_RADIUS: v.layer.cornerRadius = x[0]; break;
    case AK_BORDERW: v.layer.borderWidth = x[0]; break;
    case AK_SHADOWOP: v.layer.shadowOpacity = (float)x[0]; break;
    case AK_SHADOWRAD: v.layer.shadowRadius = x[0]; break;
    case AK_SHADOWOFF: v.layer.shadowOffset = CGSizeMake(x[0], x[1]); break;
    case AK_BORDERCOLOR: v.layer.borderColor = [UIColor colorWithRed:x[0] green:x[1] blue:x[2] alpha:x[3]].CGColor; break;
    }
    suppress_depth--;
}
/* position 0: end (model values stay), 1: start (model values go back), 2: current (model = presentation; the
   removed tracks are remembered for isim_ui_timeline_settle) */
static void timeline_finish(__IsimTimeline *tl, int position) {
    if (tl->done) return;
    tl->done = YES;
    [timelines removeObjectIdenticalTo:tl];
    NSMutableArray *groups = [NSMutableArray array];
    for (UIView *v in [animating copy]) {
        BOOL still = NO;
        for (int k = 0; k < AK_COUNT; k++) {
            anim_track *t = &v->_anim->t[k];
            if (!t->active) continue;
            __IsimAnimationGroup *g = t->group;
            if (g->timeline != tl) { still = YES; continue; }
            if (t->keyframed) kf_eval(t, tl_now(tl));
            double from[6], to[6], cur[6]; int n = t->n;
            memcpy(from, t->from, sizeof from); memcpy(cur, t->cur, sizeof cur);
            memcpy(to, t->keyframed && t->nkf ? t->kfTo[t->nkf - 1] : t->to, sizeof to);
            t->active = NO; t->group = nil;
            if (position == 1) anim_apply_model(v, k, from);
            else if (position == 2) {
                anim_apply_model(v, k, cur);
                if (!tl->stopped) tl->stopped = [NSMutableArray array];
                NSMutableArray *a = [NSMutableArray array], *b = [NSMutableArray array];
                for (int i = 0; i < n; i++) { [a addObject:@(from[i])]; [b addObject:@(to[i])]; }
                [tl->stopped addObject:@[v, @(k), a, b]];
            }
            g->pending--;
            if ([groups indexOfObjectIdenticalTo:g] == NSNotFound) [groups addObject:g];
        }
        if (!still) [animating removeObjectIdenticalTo:v];
    }
    for (__IsimAnimationGroup *g in groups) group_done(g, position != 2);
    for (__IsimAnimationGroup *g in tl->groups) { void (^c)(BOOL) = g->completion; g->completion = nil; [live_groups removeObject:g]; if (c) dispatch_async(dispatch_get_main_queue(), ^{ c(position != 2); }); }
    tl->groups = nil;
    void (^f)(int) = tl->onFinish; tl->onFinish = nil;
    if (f && position != 2) f(position);
    isim_ui_set_needs_display();
}
void isim_ui_timeline_finish(id o, int position) { timeline_finish(o, position); }
/* after a "current" finish: put the stopped properties at their start (1) or end (0) values */
void isim_ui_timeline_settle(id o, int position) {
    __IsimTimeline *tl = o;
    for (NSArray *r in tl->stopped) {
        NSArray *vals = position == 1 ? r[2] : r[3];
        double x[6] = { 0 };
        for (NSUInteger i = 0; i < vals.count && i < 6; i++) x[i] = [vals[i] doubleValue];
        anim_apply_model(r[0], [r[1] intValue], x);
    }
    tl->stopped = nil;
}

/* the model value changed without animation while a track runs: keep the motion, relative to the new value */
static void anim_rebase(UIView *v, int key, const double *model_old, const double *model_new, int n) {
    anim_track *t = &v->_anim->t[key];
    if (!t->active) return;
    for (int i = 0; i < n; i++) {
        double d = model_new[i] - model_old[i];
        t->from[i] += d; t->to[i] += d; t->cur[i] += d;
        for (int k = 0; k < t->nkf; k++) t->kfTo[k][i] += d;
    }
}
/* CALayer.removeAllAnimations(): presentation snaps to the model values; completions run with finished = NO */
static void anim_remove_all(UIView *v) {
    if (!v->_anim) return;
    for (int k = 0; k < AK_COUNT; k++) {
        anim_track *t = &v->_anim->t[k];
        if (!t->active) continue;
        t->active = NO;
        __IsimAnimationGroup *g = t->group; t->group = nil;
        if (g) { g->pending--; group_done(g, NO); }
    }
    [animating removeObjectIdenticalTo:v];
    isim_ui_set_needs_display();
}
