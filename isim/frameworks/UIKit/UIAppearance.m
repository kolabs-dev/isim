/* UIAppearance proxies (adapted: isim's Objective-C runtime has no message forwarding, so a proxy cannot
 * record arbitrary invocations). +appearance returns a real offscreen instance of the class; setters run on
 * it normally. When a view first moves to a window, each proxy that applies to it (its class or a superclass,
 * matching containers / trait style) is compared with a pristine instance of the proxy's class over a list of
 * appearance properties; every property the proxy changed is copied to the view unless the view has its own
 * value (it differs from a pristine instance of the view's class). Subclass proxies win over superclass ones,
 * and contained-in proxies over plain ones. */
#import "UIKitPrivate.h"
#import <UIKit/UIAppearance.h>

/* appearance properties: getter names (setters are set<Getter>:, "is" getters map to set<Rest>:) */
static NSArray<NSString *> *appearance_keys(void) {
    return @[@"tintColor", @"backgroundColor", @"barTintColor", @"titleTextAttributes", @"largeTitleTextAttributes",
             @"standardAppearance", @"scrollEdgeAppearance", @"compactAppearance", @"prefersLargeTitles", @"isTranslucent", @"barStyle",
             @"onTintColor", @"thumbTintColor", @"minimumTrackTintColor", @"maximumTrackTintColor", @"selectedSegmentTintColor",
             @"unselectedItemTintColor", @"pageIndicatorTintColor", @"currentPageIndicatorTintColor", @"progressTintColor",
             @"trackTintColor", @"color", @"textColor", @"font", @"separatorColor", @"sectionIndexColor", @"searchBarStyle",
             @"placeholder"];
}
static SEL setter_for(NSString *g) {
    NSString *base = [g hasPrefix:@"is"] && g.length > 2 && isupper([g characterAtIndex:2]) ? [g substringFromIndex:2] : g;
    return NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [[base substringToIndex:1] uppercaseString], [base substringFromIndex:1]]);
}

static char kProxy, kApplied, kAppearanceSet;
@interface __IsimAppearanceEntry : NSObject
@property (nonatomic, strong) UIView *proxy;
@property (nonatomic, strong) NSArray *containers;
@property (nonatomic) UIUserInterfaceStyle style;
@end
@implementation __IsimAppearanceEntry @end

static NSMutableDictionary<NSString *, NSMutableArray<__IsimAppearanceEntry *> *> *entries;   /* class name -> proxies */
static NSMutableDictionary<NSString *, UIView *> *pristines;
static int creating;
extern void (*isim_ui_appearance_hook)(UIView *v);

static UIView *make_instance(Class cls) {
    creating++;
    UIView *v = [[cls alloc] initWithFrame:CGRectZero];
    creating--;
    objc_setAssociatedObject(v, &kProxy, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return v;
}
static UIView *pristine(Class cls) {
    NSString *k = NSStringFromClass(cls);
    if (!pristines) pristines = [NSMutableDictionary dictionary];
    if (!pristines[k]) pristines[k] = make_instance(cls);
    return pristines[k];
}

/* typed property access through the getter's type encoding; scalars come back boxed */
static char ret_type(id o, SEL g) {
    Method m = class_getInstanceMethod(object_getClass(o), g);
    const char *t = m ? method_getTypeEncoding(m) : NULL;
    if (!t) return 0;
    while (*t && strchr("rnNoORV", *t)) t++;
    return *t;
}
static id get_value(id o, SEL g) {
    if (![o respondsToSelector:g]) return nil;
    IMP imp = [o methodForSelector:g];
    switch (ret_type(o, g)) {
    case '@': return ((id (*)(id, SEL))imp)(o, g);
    case 'B': return @(((BOOL (*)(id, SEL))imp)(o, g));
    case 'c': return @(((signed char (*)(id, SEL))imp)(o, g));
    case 'q': case 'l': return @(((long (*)(id, SEL))imp)(o, g));
    case 'Q': case 'L': return @(((unsigned long (*)(id, SEL))imp)(o, g));
    case 'i': return @(((int (*)(id, SEL))imp)(o, g));
    case 'd': return @(((double (*)(id, SEL))imp)(o, g));
    case 'f': return @(((float (*)(id, SEL))imp)(o, g));
    }
    return nil;
}
static void set_value(id o, SEL g, SEL s, id v) {
    if (![o respondsToSelector:s]) return;
    IMP imp = [o methodForSelector:s];
    switch (ret_type(o, g)) {
    case '@': ((void (*)(id, SEL, id))imp)(o, s, v); break;
    case 'B': ((void (*)(id, SEL, BOOL))imp)(o, s, [v boolValue]); break;
    case 'c': ((void (*)(id, SEL, signed char))imp)(o, s, (signed char)[v charValue]); break;
    case 'q': case 'l': ((void (*)(id, SEL, long))imp)(o, s, [v longValue]); break;
    case 'Q': case 'L': ((void (*)(id, SEL, unsigned long))imp)(o, s, [v unsignedLongValue]); break;
    case 'i': ((void (*)(id, SEL, int))imp)(o, s, [v intValue]); break;
    case 'd': ((void (*)(id, SEL, double))imp)(o, s, [v doubleValue]); break;
    case 'f': ((void (*)(id, SEL, float))imp)(o, s, [v floatValue]); break;
    }
}

/* value equality that sees through fresh-but-identical objects (colors, bar appearances, attribute dictionaries) */
static BOOL same(id a, id b);
static BOOL same_color(UIColor *a, UIColor *b) {
    for (int st = 1; st <= 2; st++) {
        double x[4], y[4];
        isim_ui_push_style((UIUserInterfaceStyle)st); isim_ui_rgba(a, x); isim_ui_rgba(b, y); isim_ui_pop_style();
        for (int i = 0; i < 4; i++) if (fabs(x[i] - y[i]) > 0.002) return NO;
    }
    return YES;
}
static BOOL same(id a, id b) {
    if (a == b) return YES;
    if (!a || !b) return NO;
    if ([a isKindOfClass:[UIColor class]] && [b isKindOfClass:[UIColor class]]) return same_color(a, b);
    if ([a isKindOfClass:[NSDictionary class]] && [b isKindOfClass:[NSDictionary class]]) {
        if ([a count] != [b count]) return NO;
        for (id k in a) if (!same(a[k], b[k])) return NO;
        return YES;
    }
    if ([a isKindOfClass:[UIFont class]] && [b isKindOfClass:[UIFont class]])
        return ((UIFont *)a).pointSize == ((UIFont *)b).pointSize && ((UIFont *)a)._isim_weight == ((UIFont *)b)._isim_weight && same(((UIFont *)a)._isim_family, ((UIFont *)b)._isim_family);
    if ([a isKindOfClass:[UIBarAppearance class]] && [b isKindOfClass:[UIBarAppearance class]]) {
        UIBarAppearance *x = a, *y = b;
        if ([x class] != [y class] || !same(x.backgroundColor, y.backgroundColor) || !same(x.shadowColor, y.shadowColor) || !same(x.backgroundImage, y.backgroundImage)) return NO;
        if (!x.backgroundEffect != !y.backgroundEffect) return NO;
        if ([x isKindOfClass:[UINavigationBarAppearance class]])
            return same(((UINavigationBarAppearance *)x).titleTextAttributes, ((UINavigationBarAppearance *)y).titleTextAttributes)
                && same(((UINavigationBarAppearance *)x).largeTitleTextAttributes, ((UINavigationBarAppearance *)y).largeTitleTextAttributes);
        return YES;
    }
    return [a isEqual:b];
}

/* containers: each listed class must enclose the view (a superview, or the controller of one), in order */
static BOOL contained(UIView *v, NSArray *containers) {
    NSInteger want = (NSInteger)containers.count - 1;
    for (UIView *s = v.superview; s && want >= 0; s = s.superview) {
        Class c = containers[(NSUInteger)want];
        UIViewController *vc = [s _isim_viewController];
        if ([s isKindOfClass:c] || (vc && [vc isKindOfClass:c])) want--;
    }
    return want < 0;
}

static void apply_appearance(UIView *v) {
    if (creating || !entries.count || objc_getAssociatedObject(v, &kProxy) || objc_getAssociatedObject(v, &kApplied)) return;
    objc_setAssociatedObject(v, &kApplied, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray<Class> *chain = [NSMutableArray array];
    for (Class c = object_getClass(v); c && c != [UIResponder class]; c = class_getSuperclass(c)) [chain insertObject:c atIndex:0];
    NSMutableSet *mine = objc_getAssociatedObject(v, &kAppearanceSet);      /* keys set by appearance (may be overridden by later proxies) */
    UIUserInterfaceStyle style = v.traitCollection.userInterfaceStyle;
    for (Class c in chain) {
        NSArray *list = entries[NSStringFromClass(c)];
        if (!list) continue;
        NSArray *ordered = [list sortedArrayUsingComparator:^NSComparisonResult(__IsimAppearanceEntry *a, __IsimAppearanceEntry *b) {
            return a.containers.count < b.containers.count ? NSOrderedAscending : a.containers.count > b.containers.count ? NSOrderedDescending : NSOrderedSame; }];
        UIView *base = pristine(c), *own = pristine(object_getClass(v));
        for (__IsimAppearanceEntry *e in ordered) {
            if (e.containers.count && !contained(v, e.containers)) continue;
            if (e.style && e.style != style) continue;
            for (NSString *key in appearance_keys()) {
                SEL g = NSSelectorFromString(key), s = setter_for(key);
                if (![e.proxy respondsToSelector:g] || ![v respondsToSelector:s]) continue;
                id pv = get_value(e.proxy, g);
                if (same(pv, get_value(base, g))) continue;                         /* the proxy did not set it */
                BOOL explicitly;
                if ([key isEqualToString:@"tintColor"]) explicitly = !same(v.tintColor, v.superview ? v.superview.tintColor : UIColor.systemBlueColor);
                else explicitly = !same(get_value(v, g), get_value(own, g));
                if (explicitly && ![mine containsObject:key]) continue;             /* the view's own value wins */
                set_value(v, g, s, pv);
                if (!mine) { mine = [NSMutableSet set]; objc_setAssociatedObject(v, &kAppearanceSet, mine, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
                [mine addObject:key];
            }
        }
    }
}

static UIView *proxy_for(Class cls, NSArray *containers, UITraitCollection *trait) {
    if (!entries) entries = [NSMutableDictionary dictionary];
    isim_ui_appearance_hook = apply_appearance;
    NSString *k = NSStringFromClass(cls);
    NSMutableArray *list = entries[k] ?: (entries[k] = [NSMutableArray array]);
    UIUserInterfaceStyle st = trait ? trait.userInterfaceStyle : UIUserInterfaceStyleUnspecified;
    for (__IsimAppearanceEntry *e in list) if (e.style == st && [e.containers ?: @[] isEqualToArray:containers ?: @[]]) return e.proxy;
    __IsimAppearanceEntry *e = [__IsimAppearanceEntry new];
    e.proxy = make_instance(cls); e.containers = containers; e.style = st;
    [list addObject:e];
    return e.proxy;
}

@implementation UIView (UIAppearance)
+ (instancetype)appearance { return (id)proxy_for(self, nil, nil); }
+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray *)c { return (id)proxy_for(self, c, nil); }
+ (instancetype)appearanceForTraitCollection:(UITraitCollection *)t { return (id)proxy_for(self, nil, t); }
+ (instancetype)appearanceForTraitCollection:(UITraitCollection *)t whenContainedInInstancesOfClasses:(NSArray *)c { return (id)proxy_for(self, c, t); }
@end
@implementation UIViewController (UIAppearanceContainer)
@end
