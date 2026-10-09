/* Visual Format Language, the keyboard layout guide, and trait change registration (iOS 17).
 * Trait registrations are checked once per frame: any change of a registered trait (appearance, rotation,
 * overrideUserInterfaceStyle) calls the handler with the previous traits. */
#import "UIKitPrivate.h"
#include <objc/runtime.h>

/* ================= Visual Format Language ================= */
static NSException *vfl_error(NSString *fmt, NSUInteger at, NSString *why) {
    return [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"Unable to parse constraint format: \n%@\n%@\n%@^", why, fmt, [@"" stringByPaddingToLength:at withString:@" " startingAtIndex:0]] userInfo:nil];
}
typedef struct { NSLayoutRelation rel; CGFloat constant; UILayoutPriority priority; __unsafe_unretained id view; BOOL hasView; } vfl_pred;   /* views stay alive in the views dictionary */
static NSData *box(vfl_pred p) { return [NSData dataWithBytes:&p length:sizeof p]; }

@interface __IsimVFL : NSObject
@property (nonatomic, copy) NSString *s;
@property (nonatomic) NSUInteger i;
@property (nonatomic, strong) NSDictionary *metrics, *views;
@end
@implementation __IsimVFL
- (unichar)peek { return _i < _s.length ? [_s characterAtIndex:_i] : 0; }
- (BOOL)eat:(unichar)c { if ([self peek] == c) { _i++; return YES; } return NO; }
- (NSString *)ident {
    NSUInteger st = _i;
    while (_i < _s.length) { unichar c = [_s characterAtIndex:_i]; if (!(isalnum(c) || c == '_')) break; _i++; }
    return _i > st ? [_s substringWithRange:NSMakeRange(st, _i - st)] : nil;
}
- (BOOL)number:(CGFloat *)out {
    NSUInteger st = _i;
    if ([self peek] == '-' || [self peek] == '+') _i++;
    while (_i < _s.length && (isdigit([_s characterAtIndex:_i]) || [_s characterAtIndex:_i] == '.')) _i++;
    if (_i == st || (_i == st + 1 && !isdigit([_s characterAtIndex:st]))) { _i = st; return NO; }
    *out = [[_s substringWithRange:NSMakeRange(st, _i - st)] doubleValue];
    return YES;
}
/* (relation)?(constant|metric|view)(@priority)? */
- (vfl_pred)predicate {
    vfl_pred p = { NSLayoutRelationEqual, 0, UILayoutPriorityRequired, nil, NO };
    if ([_s rangeOfString:@"==" options:NSAnchoredSearch range:NSMakeRange(_i, _s.length - _i)].location != NSNotFound) _i += 2;
    else if ([_s rangeOfString:@">=" options:NSAnchoredSearch range:NSMakeRange(_i, _s.length - _i)].location != NSNotFound) { _i += 2; p.rel = NSLayoutRelationGreaterThanOrEqual; }
    else if ([_s rangeOfString:@"<=" options:NSAnchoredSearch range:NSMakeRange(_i, _s.length - _i)].location != NSNotFound) { _i += 2; p.rel = NSLayoutRelationLessThanOrEqual; }
    CGFloat n;
    if ([self number:&n]) p.constant = n;
    else {
        NSString *name = [self ident];
        if (!name) @throw vfl_error(_s, _i, @"Expected a number, metric or view name.");
        if (_metrics[name]) p.constant = [_metrics[name] doubleValue];
        else if (_views[name]) { p.view = _views[name]; p.hasView = YES; }
        else @throw vfl_error(_s, _i, [NSString stringWithFormat:@"%@ is not a key in the views or metrics dictionary.", name]);
    }
    if ([self eat:'@']) {
        CGFloat pr; if ([self number:&pr]) p.priority = (UILayoutPriority)pr;
        else { NSString *m = [self ident]; p.priority = (UILayoutPriority)[_metrics[m] doubleValue]; }
    }
    return p;
}
- (NSArray *)predicateList {
    NSMutableArray *a = [NSMutableArray array];
    if ([self eat:'(']) {
        do { vfl_pred p = [self predicate]; [a addObject:box(p)]; } while ([self eat:',']);
        if (![self eat:')']) @throw vfl_error(_s, _i, @"Expected ')'.");
    } else {
        vfl_pred p = [self predicate]; [a addObject:box(p)];
    }
    return a;
}
@end

@implementation NSLayoutConstraint (NSLayoutConstraintVisualFormat)
+ (NSArray *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)opts metrics:(NSDictionary *)metrics views:(NSDictionary *)views {
    __IsimVFL *p = [__IsimVFL new];
    p.s = [format stringByReplacingOccurrencesOfString:@" " withString:@""]; p.metrics = metrics ?: @{}; p.views = views ?: @{};
    BOOL vertical = NO;
    if ([p.s hasPrefix:@"V:"]) { vertical = YES; p.i = 2; } else if ([p.s hasPrefix:@"H:"]) p.i = 2;
    NSLayoutAttribute lead = vertical ? NSLayoutAttributeTop : NSLayoutAttributeLeading, trail = vertical ? NSLayoutAttributeBottom : NSLayoutAttributeTrailing;
    NSLayoutAttribute size = vertical ? NSLayoutAttributeHeight : NSLayoutAttributeWidth;
    if (!vertical) {
        if ((opts & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionLeftToRight) { lead = NSLayoutAttributeLeft; trail = NSLayoutAttributeRight; }
        else if ((opts & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionRightToLeft) { lead = NSLayoutAttributeRight; trail = NSLayoutAttributeLeft; }
    }
    NSMutableArray *out = [NSMutableArray array];
    id prev = nil; BOOL prevIsSuper = NO;
    NSMutableArray *chain = [NSMutableArray array];
    /* the pending connection (spacing) before the next item; nil = none */
    __block NSArray *pending = nil; __block BOOL pendingStandard = NO, hasConnection = NO;   /* read by connect() */
    if ([p eat:'|']) { prevIsSuper = YES; }
    void (^connect)(id, id, BOOL) = ^(id a, id b, BOOL toSuper) {
        /* a (or the superview edge when a is nil) followed by b (or the superview edge when b is nil) */
        NSArray *preds = pending;
        if (!preds) {
            vfl_pred z = { NSLayoutRelationEqual, pendingStandard ? (toSuper ? 20 : 8) : 0, UILayoutPriorityRequired, nil, NO };
            if (!hasConnection) z.constant = 0;
            preds = @[box(z)];
        }
        for (NSData *v in preds) {
            vfl_pred q; [v getBytes:&q length:sizeof q];
            id first = b, second = a; NSLayoutAttribute fa = lead, sa = trail;
            UIView *sup = [(UIView *)(a ?: b) superview];
            if (!a) { second = sup; sa = lead; }
            if (!b) { first = sup; fa = trail; }
            NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem:first attribute:fa relatedBy:q.rel toItem:second attribute:sa multiplier:1 constant:q.constant];
            c.priority = q.priority;
            [out addObject:c];
        }
    };
    while (p.i < p.s.length) {
        if ([p eat:'-']) {
            hasConnection = YES; pendingStandard = YES; pending = nil;
            if ([p peek] != '[' && [p peek] != '|') {        /* -predicate- */
                pending = [p predicateList]; pendingStandard = NO;
                if (![p eat:'-']) @throw vfl_error(p.s, p.i, @"Expected '-'.");
            }
            continue;
        }
        if ([p eat:'[']) {
            NSString *name = [p ident];
            id view = name ? views[name] : nil;
            if (!view) @throw vfl_error(p.s, p.i, [NSString stringWithFormat:@"%@ is not a key in the views dictionary.", name ?: @""]);
            if ([p peek] == '(') {
                for (NSData *v in [p predicateList]) {
                    vfl_pred q; [v getBytes:&q length:sizeof q];
                    NSLayoutConstraint *c = q.hasView ? [NSLayoutConstraint constraintWithItem:view attribute:size relatedBy:q.rel toItem:q.view attribute:size multiplier:1 constant:0]
                                                      : [NSLayoutConstraint constraintWithItem:view attribute:size relatedBy:q.rel toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:q.constant];
                    c.priority = q.priority; [out addObject:c];
                }
            }
            if (![p eat:']']) @throw vfl_error(p.s, p.i, @"Expected ']'.");
            if (prev || prevIsSuper) connect(prev, view, prevIsSuper);
            prev = view; prevIsSuper = NO; pending = nil; pendingStandard = NO; hasConnection = NO;
            [chain addObject:view];
            continue;
        }
        if ([p eat:'|']) {
            if (!prev) @throw vfl_error(p.s, p.i, @"A superview edge needs a view before it.");
            connect(prev, nil, YES);
            pending = nil; hasConnection = NO;
            continue;
        }
        @throw vfl_error(p.s, p.i, @"Unexpected character.");
    }
    /* alignment options: consecutive views share the attributes */
    NSUInteger align = opts & NSLayoutFormatAlignmentMask;
    for (NSUInteger k = 1; k < chain.count && align; k++)
        for (NSLayoutAttribute a = NSLayoutAttributeLeft; a <= NSLayoutAttributeFirstBaseline; a++)
            if (align & (1u << a)) [out addObject:[NSLayoutConstraint constraintWithItem:chain[k] attribute:a relatedBy:NSLayoutRelationEqual toItem:chain[k - 1] attribute:a multiplier:1 constant:0]];
    return out;
}
@end

/* ================= keyboard layout guide ================= */
@implementation UITrackingLayoutGuide @end
@implementation UIKeyboardLayoutGuide
- (instancetype)init { if ((self = [super init])) { _usesBottomSafeArea = YES; } return self; }
@end
static const char kKeyboardGuide = 0;
static void keyboard_moved(NSNotification *n) {
    isim_ui_constraints_changed();
    double dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    for (UIWindow *w in UIApplication.sharedApplication.windows) [w setNeedsLayout];
    if (dur > 0) [UIView animateWithDuration:dur animations:^{ for (UIWindow *w in UIApplication.sharedApplication.windows) [w layoutIfNeeded]; }];
}
@implementation UIView (UIKeyboardLayoutGuide)
- (UIKeyboardLayoutGuide *)keyboardLayoutGuide {
    UIKeyboardLayoutGuide *g = objc_getAssociatedObject(self, &kKeyboardGuide);
    if (g) return g;
    g = [UIKeyboardLayoutGuide new];
    g.identifier = @"UIViewKeyboardLayoutGuide";
    [self addLayoutGuide:g];
    __weak UIView *ws = self; __weak UIKeyboardLayoutGuide *wg = g;
    /* the part of the view the keyboard covers; with the keyboard hidden, the bottom safe area (iOS 15+) */
    [g _isim_setFrameProvider:^CGRect {
        UIView *v = ws; UIKeyboardLayoutGuide *gg = wg;
        if (!v) return CGRectZero;
        CGRect b = v.bounds, kb = isim_ui_keyboard_frame();
        CGFloat safe = gg.usesBottomSafeArea ? v.safeAreaInsets.bottom : 0;
        if (CGRectIsEmpty(kb) || !v.window) return CGRectMake(b.origin.x, CGRectGetMaxY(b) - safe, b.size.width, safe);
        CGRect k = [v convertRect:kb fromView:nil];
        CGFloat top = MIN(MAX(k.origin.y, b.origin.y), CGRectGetMaxY(b) - safe);
        return CGRectMake(b.origin.x, top, b.size.width, CGRectGetMaxY(b) - top);
    }];
    objc_setAssociatedObject(self, &kKeyboardGuide, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *name in @[UIKeyboardWillChangeFrameNotification, UIKeyboardWillShowNotification, UIKeyboardWillHideNotification])
            [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *n) { keyboard_moved(n); }];
    });
    return g;
}
@end

/* ================= trait change registration ================= */
/* trait classes and values: UITraits.m. Registrations compare the registered traits (system trait classes, custom
   Objective-C trait classes, Swift trait identifiers) between the owner's last and current traits. */
static BOOL trait_differs(UITraitCollection *a, UITraitCollection *b, id trait) {
    NSString *k = isim_ui_trait_key(trait);
    if (!k) return NO;
    id x = [a _isim_objectForTraitIdentifier:k], y = [b _isim_objectForTraitIdentifier:k];
    return !((!x && !y) || [x isEqual:y]);
}
@interface __IsimTraitRegistration : NSObject <UITraitChangeRegistration>
@property (nonatomic, weak) id owner;
@property (nonatomic, copy) NSArray<Class> *traits;
@property (nonatomic, copy) UITraitChangeHandler handler;
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic, strong) UITraitCollection *last;
@end
@implementation __IsimTraitRegistration
- (id)copyWithZone:(NSZone *)z { return self; }
@end
static NSMutableArray<__IsimTraitRegistration *> *registrations;
static id register_traits(id owner, NSArray *traits, UITraitChangeHandler h, id target, SEL action) {
    if (!registrations) registrations = [NSMutableArray array];
    __IsimTraitRegistration *r = [__IsimTraitRegistration new];
    r.owner = owner; r.traits = traits; r.handler = h; r.target = target; r.action = action;
    r.last = [owner traitCollection];
    [registrations addObject:r];
    return r;
}
/* per frame: fire registrations whose traits changed */
void isim_ui_trait_registrations_tick(void) {
    static unsigned seen;
    if (!registrations.count || seen == isim_ui_trait_generation()) return;
    seen = isim_ui_trait_generation();
    for (__IsimTraitRegistration *r in [registrations copy]) {
        id owner = r.owner;
        if (!owner) { [registrations removeObjectIdenticalTo:r]; continue; }
        UITraitCollection *now = [owner traitCollection], *prev = r.last;
        BOOL changed = NO;
        for (id t in r.traits) if (trait_differs(now, prev, t)) changed = YES;
        r.last = now;
        if (!changed) continue;
        if (r.handler) r.handler(owner, prev);
        else {
            id target = r.target ?: owner;
            NSUInteger n = 2 + [NSStringFromSelector(r.action) componentsSeparatedByString:@":"].count - 1;   /* self, _cmd, colons */
            if (n <= 2) ((void (*)(id, SEL))[target methodForSelector:r.action])(target, r.action);
            else if (n == 3) ((void (*)(id, SEL, id))[target methodForSelector:r.action])(target, r.action, owner);
            else ((void (*)(id, SEL, id, id))[target methodForSelector:r.action])(target, r.action, owner, prev);
        }
    }
}
#define TRAIT_REG_IMPL \
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)h { return register_traits(self, traits, h, nil, NULL); } \
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)t action:(SEL)a { return register_traits(self, traits, nil, t, a); } \
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)a { return register_traits(self, traits, nil, nil, a); } \
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)r { [registrations removeObjectIdenticalTo:(id)r]; } \
- (id<UITraitChangeRegistration>)_isim_registerForTraits:(NSArray *)traits handler:(UITraitChangeHandler)h target:(id)t action:(SEL)a { return register_traits(self, traits, h, t, a); }
@implementation UIView (UITraitChangeObservable)
TRAIT_REG_IMPL
@end
@implementation UIViewController (UITraitChangeObservable)
TRAIT_REG_IMPL
@end
@implementation UIWindowScene (UITraitChangeObservable)
TRAIT_REG_IMPL
@end
@implementation UIPresentationController (UITraitChangeObservable)
TRAIT_REG_IMPL
@end
