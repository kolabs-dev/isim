/* isim UIKit (ARC): the Interface Builder runtime — UIStoryboard, UIStoryboardSegue, UINib, nib-backed view
 * controllers, init(coder:) for IB-made objects, outlets/actions/segues, Auto Layout constraints from IB.
 *
 * Input is isim's IB archive format written by isim/tools/ibtool.py (an XML property list; see the format
 * description at the top of that file) — NOT Apple's compiled .nib/.storyboardc binary archives.
 *
 * Objects are made like on iOS: views and view controllers through -initWithCoder: with an NSCoder (here an
 * __IsimIBCoder over the archive node), so Swift subclasses' `required init?(coder:)` runs; UIKit's own
 * initWithCoder: implementations call isim_ib_init_with_coder(), which runs the nearest UIKit initializer
 * (initWithFrame:, initWithStyle:reuseIdentifier:, initWithNibName:bundle: ...) without dispatching to app
 * overrides (a Swift class that only implements init(coder:) traps in its synthesized init(frame:)), then decodes
 * the IB attributes, subviews and keyed objects. After all objects exist: constraints, connections (outlets,
 * outlet collections, target-actions, segues), user defined runtime attributes, then -awakeFromNib.
 * A storyboard view controller's view is loaded lazily (-loadView), like iOS; so are its outlets into the view. */
#import "UIKitPrivate.h"
#import <UIKit/UIStoryboard.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <string.h>

UINibOptionsKey const UINibExternalObjects = @"UINibExternalObjects";

@class __IsimIBLoader;
static id ib_value(id v, __IsimIBLoader *loader);
static void ib_apply_props(id obj, NSDictionary *props, __IsimIBLoader *loader);

static BOOL ib_verbose(void) { static int v = -1; if (v < 0) { const char *e = getenv("ISIM_IB_VERBOSE"); v = e && *e == '1'; } return v; }

/* ================= class resolution ================= */
static Class ib_resolve_class(NSDictionary *node) {
    NSString *custom = node[@"customClass"];
    Class base = NSClassFromString(node[@"class"]) ?: [NSObject class];
    if (!custom.length) return base;
    Class c = Nil;
    NSString *module = node[@"customModule"];
    if (!module.length && [node[@"customModuleProvider"] isEqualToString:@"target"]) {
        NSString *exe = NSBundle.mainBundle.infoDictionary[@"CFBundleExecutable"];
        module = [exe stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        module = [module stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    }
    if (module.length) c = NSClassFromString([NSString stringWithFormat:@"%@.%@", module, custom]);
    if (!c) c = NSClassFromString(custom);
    if (!c) { NSLog(@"isim: Unknown class %@ in Interface Builder file.", custom); return base; }
    return c;
}

/* the nearest superclass implemented outside the app (UIKit and other system frameworks): its initializers
   are run directly, never the app's overrides */
static Class ib_kit_class(Class c) {
    static NSString *appDir;
    if (!appDir) appDir = [NSBundle.mainBundle.bundlePath stringByStandardizingPath] ?: @"";
    for (Class k = c; k; k = class_getSuperclass(k)) {
        const char *img = class_getImageName(k);
        if (!img) return k;
        NSString *path = [@(img) stringByStandardizingPath];
        if (!appDir.length || ![path hasPrefix:appDir]) return k;
    }
    return c;
}

/* ================= the coder ================= */
@interface __IsimIBCoder : NSCoder
@property (nonatomic, strong) NSDictionary *node;
@property (nonatomic, weak) __IsimIBLoader *loader;
@end

/* ================= segue templates and triggers ================= */
@interface __IsimSegueTemplate : NSObject
@property (nonatomic, copy) NSDictionary *conn;
@property (nonatomic, weak) __IsimIBLoader *loader;
@property (nonatomic, weak) UIViewController *sourceController;
@property (nonatomic, strong) UIStoryboard *storyboard;
- (void)performWithSender:(id)sender checkShould:(BOOL)check;
@end
@interface __IsimSegueTrigger : NSObject
@property (nonatomic, strong) __IsimSegueTemplate *segue;
- (void)fire:(id)sender;
@end

/* the size-class variations of one view (applyVariations) */
@interface __IsimIBVariations : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) __IsimIBLoader *loader;
@property (nonatomic, strong) NSDictionary *node, *constraints, *subviews, *indices;
@property (nonatomic, copy) NSString *applied;
- (void)apply;
@end

/* ================= the loader: one instantiation of an archive ================= */
@interface __IsimIBLoader : NSObject
@property (nonatomic, strong) NSDictionary *archive;
@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) UIStoryboard *storyboard;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *objects;
@property (nonatomic, strong) NSMapTable<NSString *, id> *weakObjects;       /* objects owned elsewhere (owner, scene controller) */
@property (nonatomic, strong) NSMutableIndexSet *applied;
@property (nonatomic, strong) NSMutableArray *awake, *pendingConstraints, *pendingUserDefined, *pendingVariations;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSLayoutConstraint *> *constraintsByID;
@property (nonatomic, weak) UIViewController *sceneController;
@property (nonatomic, strong) __IsimIBLoader *parent;                       /* scene loader of a prototype cell */
@property (nonatomic, strong) NSString *ownerID;
- (id)instantiate:(NSDictionary *)node;
- (id)objectForID:(NSString *)ident found:(BOOL *)found;
- (void)finish;
@end

@interface UINib ()
@property (nonatomic, strong) NSDictionary *archive;
@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) __IsimIBLoader *sceneLoader;       /* prototype cells: the scene they belong to */
@property (nonatomic, copy) NSString *name;
@end

@interface UIStoryboard ()
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSDictionary *data;
- (UIViewController *)_isim_instantiateScene:(NSString *)sceneID creator:(UIStoryboardViewControllerCreator)creator;
@end

@implementation __IsimIBVariations
- (void)apply {
    UIView *view = _view;
    if (!view) return;
    UITraitCollection *t = view.window ? view.traitCollection : isim_ui_screen_traits();
    NSString *w = t.horizontalSizeClass == UIUserInterfaceSizeClassCompact ? @"compact" : @"regular";
    NSString *h = t.verticalSizeClass == UIUserInterfaceSizeClassCompact ? @"compact" : @"regular";
    NSString *key = [NSString stringWithFormat:@"%@/%@", w, h];
    if ([_applied isEqualToString:key]) return;
    _applied = key;
    /* the base ("default") masks, then matching variations, the more specific last */
    NSMutableArray *matching = [NSMutableArray array];
    for (NSDictionary *v in _node[@"variations"]) {
        if ([v[@"key"] isEqualToString:@"default"]) { [matching insertObject:v atIndex:0]; continue; }
        if ((v[@"w"] && ![v[@"w"] isEqualToString:w]) || (v[@"h"] && ![v[@"h"] isEqualToString:h])) continue;
        [matching addObject:v];
    }
    [matching sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSInteger sa = [a[@"key"] isEqualToString:@"default"] ? -1 : (a[@"w"] ? 1 : 0) + (a[@"h"] ? 1 : 0);
        NSInteger sb = [b[@"key"] isEqualToString:@"default"] ? -1 : (b[@"w"] ? 1 : 0) + (b[@"h"] ? 1 : 0);
        return sa < sb ? NSOrderedAscending : sa > sb ? NSOrderedDescending : NSOrderedSame; }];
    NSMutableDictionary *on = [NSMutableDictionary dictionary], *props = [NSMutableDictionary dictionary];
    for (NSString *ident in _constraints) on[ident] = @YES;
    for (NSString *ident in _subviews) on[ident] = @YES;
    for (NSDictionary *v in matching) {
        for (NSString *kind in @[@"constraints", @"subviews"]) {
            for (NSString *ident in v[@"include"][kind]) on[ident] = @YES;
            for (NSString *ident in v[@"exclude"][kind]) on[ident] = @NO;
        }
        [props addEntriesFromDictionary:v[@"props"] ?: @{}];
    }
    /* overridden properties not overridden now go back to their base values */
    for (NSDictionary *v in _node[@"variations"]) for (NSString *k in v[@"props"]) if (!props[k] && _node[@"props"][k]) props[k] = _node[@"props"][k];
    for (NSString *ident in _subviews) {
        UIView *sv = _subviews[ident];
        BOOL want = [on[ident] boolValue];
        if (want && sv.superview != view) [view insertSubview:sv atIndex:MIN([_indices[ident] unsignedIntegerValue], view.subviews.count)];
        else if (!want && sv.superview == view) [sv removeFromSuperview];
    }
    NSMutableArray *activate = [NSMutableArray array], *deactivate = [NSMutableArray array];
    for (NSString *ident in _constraints) [([on[ident] boolValue] ? activate : deactivate) addObject:_constraints[ident]];
    [NSLayoutConstraint deactivateConstraints:deactivate];
    NSMutableArray *ok = [NSMutableArray array];
    for (NSLayoutConstraint *c in activate) {
        UIView *a = [c.firstItem isKindOfClass:[UIView class]] ? c.firstItem : nil, *b = [c.secondItem isKindOfClass:[UIView class]] ? c.secondItem : nil;
        if ((a && !a.superview && a != view) || (b && !b.superview && b != view)) continue;        /* an item that is not installed */
        [ok addObject:c];
    }
    [NSLayoutConstraint activateConstraints:ok];
    if (props.count) ib_apply_props(view, props, _loader);
    NSLog(@"isim: IB size-class variation %@ for %@ (%lu constraints, %lu subviews installed)", key, view.accessibilityIdentifier ?: NSStringFromClass([view class]),
          (unsigned long)ok.count, (unsigned long)[[_subviews allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *k, NSDictionary *b0) { return [on[k] boolValue]; }]].count);
    [view setNeedsLayout];
}
@end

static char kLoaderKey, kStoryboardKey, kTemplatesKey, kTriggerKey, kNibNameKey, kNibBundleKey, kCellNibsKey, kCellSegueKey;

/* ================= typed values ================= */
static UIFontWeight ib_weight(NSString *w) {
    NSDictionary *m = @{@"ultraLight": @(UIFontWeightUltraLight), @"thin": @(UIFontWeightThin), @"light": @(UIFontWeightLight),
                        @"regular": @(UIFontWeightRegular), @"medium": @(UIFontWeightMedium), @"semibold": @(UIFontWeightSemibold),
                        @"bold": @(UIFontWeightBold), @"heavy": @(UIFontWeightHeavy), @"black": @(UIFontWeightBlack)};
    return [m[w] doubleValue];
}
static UIFontTextStyle ib_text_style(NSString *s) {
    NSDictionary *m = @{@"UICTFontTextStyleTitle0": UIFontTextStyleLargeTitle, @"UICTFontTextStyleTitle1": UIFontTextStyleTitle1,
                        @"UICTFontTextStyleTitle2": UIFontTextStyleTitle2, @"UICTFontTextStyleTitle3": UIFontTextStyleTitle3,
                        @"UICTFontTextStyleHeadline": UIFontTextStyleHeadline, @"UICTFontTextStyleSubhead": UIFontTextStyleSubheadline,
                        @"UICTFontTextStyleBody": UIFontTextStyleBody, @"UICTFontTextStyleCallout": UIFontTextStyleCallout,
                        @"UICTFontTextStyleFootnote": UIFontTextStyleFootnote, @"UICTFontTextStyleCaption1": UIFontTextStyleCaption1,
                        @"UICTFontTextStyleCaption2": UIFontTextStyleCaption2};
    return m[s] ?: UIFontTextStyleBody;
}
static id ib_value(id v, __IsimIBLoader *loader) {
    if (![v isKindOfClass:[NSDictionary class]]) return v;
    NSDictionary *d = v; NSString *t = d[@"$t"];
    if (!t) return v;
    if ([t isEqualToString:@"nil"]) return nil;
    if ([t isEqualToString:@"color"]) {
        if (d[@"system"]) {
            NSString *n = d[@"system"];
            SEL s = NSSelectorFromString(n);
            if ([UIColor respondsToSelector:s]) return ((id (*)(id, SEL))objc_msgSend)([UIColor class], s);
            NSString *alt = [n hasSuffix:@"Color"] ? n : [n stringByAppendingString:@"Color"];
            s = NSSelectorFromString(alt);
            if ([UIColor respondsToSelector:s]) return ((id (*)(id, SEL))objc_msgSend)([UIColor class], s);
            NSLog(@"isim: Interface Builder system color %@ is not available", n);
            return nil;
        }
        if (d[@"named"]) {
            UIColor *c = [UIColor colorNamed:d[@"named"] inBundle:loader.bundle compatibleWithTraitCollection:nil] ?: [UIColor colorNamed:d[@"named"]];
            if (!c) NSLog(@"isim: Could not load the \"%@\" color referenced from an Interface Builder file", d[@"named"]);
            return c;
        }
        NSArray *rgba = d[@"rgba"];
        return [UIColor colorWithRed:[rgba[0] doubleValue] green:[rgba[1] doubleValue] blue:[rgba[2] doubleValue] alpha:[rgba[3] doubleValue]];
    }
    if ([t isEqualToString:@"font"]) {
        if (d[@"textStyle"]) return [UIFont preferredFontForTextStyle:ib_text_style(d[@"textStyle"])];
        CGFloat size = [d[@"size"] doubleValue] ?: 17;
        if (d[@"name"]) return [UIFont fontWithName:d[@"name"] size:size] ?: [UIFont systemFontOfSize:size];
        if (d[@"weight"]) return [UIFont systemFontOfSize:size weight:ib_weight(d[@"weight"])];
        if ([d[@"system"] isEqualToString:@"bold"]) return [UIFont boldSystemFontOfSize:size];
        if ([d[@"system"] isEqualToString:@"italic"]) return [UIFont italicSystemFontOfSize:size];
        return [UIFont systemFontOfSize:size];
    }
    if ([t isEqualToString:@"image"]) {
        NSString *n = d[@"name"];
        UIImage *img = [d[@"system"] boolValue] ? [UIImage systemImageNamed:n]
                     : ([UIImage imageNamed:n inBundle:loader.bundle withConfiguration:nil] ?: [UIImage imageNamed:n]);
        if (!img) img = [UIImage systemImageNamed:n];
        if (!img) NSLog(@"isim: Could not load the \"%@\" image referenced from an Interface Builder file", n);
        if (img && [d[@"rendering"] isEqualToString:@"template"]) img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        return img;
    }
    if ([t isEqualToString:@"date"]) return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[d[@"v"] doubleValue]];
    if ([t isEqualToString:@"locale"]) return [NSLocale localeWithLocaleIdentifier:d[@"v"]];
    if ([t isEqualToString:@"symbolConfig"]) {
        UIImageSymbolConfiguration *c = [UIImageSymbolConfiguration configurationWithScale:(UIImageSymbolScale)[d[@"scale"] integerValue]];
        if ([d[@"weight"] integerValue]) c = [c configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationWithWeight:(UIImageSymbolWeight)[d[@"weight"] integerValue]]];
        if ([d[@"size"] doubleValue] > 0) c = [c configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:[d[@"size"] doubleValue]]];
        return c;
    }
    NSArray *a = d[@"v"];
    if ([t isEqualToString:@"rect"]) return [NSValue valueWithCGRect:CGRectMake([a[0] doubleValue], [a[1] doubleValue], [a[2] doubleValue], [a[3] doubleValue])];
    if ([t isEqualToString:@"size"]) return [NSValue valueWithCGSize:CGSizeMake([a[0] doubleValue], [a[1] doubleValue])];
    if ([t isEqualToString:@"point"]) return [NSValue valueWithCGPoint:CGPointMake([a[0] doubleValue], [a[1] doubleValue])];
    if ([t isEqualToString:@"range"]) return [NSValue valueWithRange:NSMakeRange([a[0] unsignedIntegerValue], [a[1] unsignedIntegerValue])];
    return v;                     /* insets / dinsets: handled by ib_set (struct setters) */
}

/* KVC set only when the object has the key (isim's runtime has no ObjC exception catching) */
static BOOL ib_kvc_set(id obj, NSString *key, id value) {
    if (!obj || !key.length) return NO;
    NSString *cap = [[[key substringToIndex:1] uppercaseString] stringByAppendingString:[key substringFromIndex:1]];
    BOOL ok = [obj respondsToSelector:NSSelectorFromString([NSString stringWithFormat:@"set%@:", cap])] ||
              [obj respondsToSelector:NSSelectorFromString([NSString stringWithFormat:@"_set%@:", cap])];
    if (!ok && [[obj class] accessInstanceVariablesDirectly]) {
        NSArray *names = @[[@"_" stringByAppendingString:key], [@"_is" stringByAppendingString:cap], key, [@"is" stringByAppendingString:cap]];
        for (Class c = object_getClass(obj); c && !ok; c = class_getSuperclass(c)) {
            unsigned n = 0; Ivar *list = class_copyIvarList(c, &n);
            for (unsigned i = 0; i < n && !ok; i++) {
                const char *iv = ivar_getName(list[i]), *ty = ivar_getTypeEncoding(list[i]);
                if (iv && ty && *ty && [names containsObject:@(iv)]) ok = YES;
            }
            free(list);
        }
    }
    if (ok) [obj setValue:value forKey:key];
    return ok;
}

/* the type of a method's argument in its type encoding ("v24@0:8{CGRect=...}16"); arg 2 is the first explicit
   argument, as in method_getArgumentType (0 self, 1 _cmd) */
static const char *ib_arg_type(const char *types, int arg) {
    const char *t = types;
    for (int i = 0; t && *t; i++) {
        while (*t == 'r' || *t == 'n' || *t == 'N' || *t == 'o' || *t == 'O' || *t == 'R' || *t == 'V') t++;
        if (i == arg + 1) return t;                   /* arg 2 = first explicit argument (after return, self, _cmd) */
        if (*t == '{' || *t == '(' || *t == '[') {
            char open = *t, close = open == '{' ? '}' : open == '(' ? ')' : ']'; int depth = 0;
            do { if (*t == open) depth++; else if (*t == close) depth--; t++; } while (*t && depth);
        } else if (*t == '^') { t++; if (*t == '{') { int depth = 0; do { if (*t == '{') depth++; else if (*t == '}') depth--; t++; } while (*t && depth); } else t++; }
        else if (*t == '@' && t[1] == '?') t += 2;
        else if (*t == '@' && t[1] == '"') { t += 2; while (*t && *t != '"') t++; if (*t) t++; }
        else t++;
        while ((*t >= '0' && *t <= '9') || *t == '-') t++;
    }
    return "@";
}

/* -set<Key>: with the argument type the method takes (objects, numbers, CG structs, edge insets) */
static BOOL ib_set(id obj, NSString *key, id raw, __IsimIBLoader *loader) {
    if (!key.length) return NO;
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", [[key substringToIndex:1] uppercaseString], [key substringFromIndex:1]];
    SEL sel = NSSelectorFromString(setter);
    Method m = class_getInstanceMethod(object_getClass(obj), sel);
    if (!m) {
        if (ib_kvc_set(obj, key, ib_value(raw, loader))) return YES;
        if (ib_verbose()) NSLog(@"isim: IB: %@ has no property %@", [obj class], key);
        return NO;
    }
    const char *t = ib_arg_type(method_getTypeEncoding(m) ?: "v@:@", 2);
    const char *ty = t; while (*ty == 'r' || *ty == 'n' || *ty == 'N' || *ty == 'o' || *ty == 'O' || *ty == 'R' || *ty == 'V') ty++;
    IMP imp = method_getImplementation(m);
    NSDictionary *d = [raw isKindOfClass:[NSDictionary class]] ? raw : nil;
    NSArray *a = d[@"v"];
    if (!strncmp(ty, "{UIEdgeInsets", 13) && a.count == 4) {
        ((void (*)(id, SEL, UIEdgeInsets))imp)(obj, sel, UIEdgeInsetsMake([a[0] doubleValue], [a[1] doubleValue], [a[2] doubleValue], [a[3] doubleValue]));
        return YES;
    }
    if (!strncmp(ty, "{NSDirectionalEdgeInsets", 24) && a.count == 4) {
        ((void (*)(id, SEL, NSDirectionalEdgeInsets))imp)(obj, sel, NSDirectionalEdgeInsetsMake([a[0] doubleValue], [a[1] doubleValue], [a[2] doubleValue], [a[3] doubleValue]));
        return YES;
    }
    id v = ib_value(raw, loader);
    switch (*ty) {
    case '@': case '#': ((void (*)(id, SEL, id))imp)(obj, sel, v); return YES;
    case 'B': case 'c': case 'C': ((void (*)(id, SEL, BOOL))imp)(obj, sel, [v boolValue]); return YES;
    case 'i': case 'I': ((void (*)(id, SEL, int))imp)(obj, sel, [v intValue]); return YES;
    case 's': case 'S': ((void (*)(id, SEL, short))imp)(obj, sel, [v shortValue]); return YES;
    case 'l': case 'q': case 'L': case 'Q': ((void (*)(id, SEL, long long))imp)(obj, sel, [v longLongValue]); return YES;
    case 'f': ((void (*)(id, SEL, float))imp)(obj, sel, [v floatValue]); return YES;
    case 'd': ((void (*)(id, SEL, double))imp)(obj, sel, [v doubleValue]); return YES;
    case '{':
        if (!strncmp(ty, "{CGRect", 7)) { ((void (*)(id, SEL, CGRect))imp)(obj, sel, [v CGRectValue]); return YES; }
        if (!strncmp(ty, "{CGSize", 7)) { ((void (*)(id, SEL, CGSize))imp)(obj, sel, [v CGSizeValue]); return YES; }
        if (!strncmp(ty, "{CGPoint", 8)) { ((void (*)(id, SEL, CGPoint))imp)(obj, sel, [v CGPointValue]); return YES; }
        if (!strncmp(ty, "{_NSRange", 9)) { ((void (*)(id, SEL, NSRange))imp)(obj, sel, [v rangeValue]); return YES; }
        break;
    }
    if (ib_verbose()) NSLog(@"isim: IB: cannot set %@.%@ (type %s)", [obj class], key, t);
    return NO;
}

/* ================= props (the attribute inspector) ================= */
static UIControlState ib_state(NSDictionary *st) { return (UIControlState)[st[@"state"] unsignedIntegerValue]; }

static void ib_button_configuration(UIButton *b, NSDictionary *c, __IsimIBLoader *loader) {
    NSString *style = c[@"style"];
    UIButtonConfiguration *conf = [style isEqualToString:@"filled"] ? [UIButtonConfiguration filledButtonConfiguration]
                                : [style isEqualToString:@"tinted"] ? [UIButtonConfiguration tintedButtonConfiguration]
                                : [style isEqualToString:@"gray"] ? [UIButtonConfiguration grayButtonConfiguration]
                                : [UIButtonConfiguration plainButtonConfiguration];
    if (c[@"title"]) conf.title = c[@"title"];
    if (c[@"subtitle"]) conf.subtitle = c[@"subtitle"];
    if (c[@"image"]) conf.image = ib_value(c[@"image"], loader);
    if (c[@"baseForegroundColor"]) conf.baseForegroundColor = ib_value(c[@"baseForegroundColor"], loader);
    if (c[@"baseBackgroundColor"]) conf.baseBackgroundColor = ib_value(c[@"baseBackgroundColor"], loader);
    if (c[@"cornerStyle"]) conf.cornerStyle = [c[@"cornerStyle"] integerValue];
    if (c[@"buttonSize"]) conf.buttonSize = [c[@"buttonSize"] integerValue];
    if (c[@"imagePadding"]) conf.imagePadding = [c[@"imagePadding"] doubleValue];
    if (c[@"contentInsets"]) ib_set(conf, @"contentInsets", c[@"contentInsets"], loader);
    if (c[@"imagePlacement"] && [conf respondsToSelector:NSSelectorFromString(@"setImagePlacement:")]) ib_set(conf, @"imagePlacement", c[@"imagePlacement"], loader);
    b.configuration = conf;
}

static void ib_apply_props(id obj, NSDictionary *props, __IsimIBLoader *loader) {
    /* frame first: later attributes (autoresizing, constraints) build on it */
    if (props[@"frame"] && [obj isKindOfClass:[UIView class]]) ((UIView *)obj).frame = [ib_value(props[@"frame"], loader) CGRectValue];
    for (NSString *key in [props.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id v = props[key];
        if ([key isEqualToString:@"frame"]) continue;
        if ([key hasPrefix:@"$"]) {
            NSString *k = [key substringFromIndex:1];
            if ([k isEqualToString:@"huggingH"]) [obj setContentHuggingPriority:[v floatValue] forAxis:UILayoutConstraintAxisHorizontal];
            else if ([k isEqualToString:@"huggingV"]) [obj setContentHuggingPriority:[v floatValue] forAxis:UILayoutConstraintAxisVertical];
            else if ([k isEqualToString:@"resistanceH"]) [obj setContentCompressionResistancePriority:[v floatValue] forAxis:UILayoutConstraintAxisHorizontal];
            else if ([k isEqualToString:@"resistanceV"]) [obj setContentCompressionResistancePriority:[v floatValue] forAxis:UILayoutConstraintAxisVertical];
            else if ([k isEqualToString:@"userInterfaceStyle"]) {
                UIUserInterfaceStyle s = [v isEqualToString:@"dark"] ? UIUserInterfaceStyleDark : [v isEqualToString:@"light"] ? UIUserInterfaceStyleLight : UIUserInterfaceStyleUnspecified;
                [obj setOverrideUserInterfaceStyle:s];
            }
            else if ([k isEqualToString:@"states"] && [obj isKindOfClass:[UIButton class]]) {
                for (NSDictionary *st in v) {
                    if (st[@"title"]) [obj setTitle:st[@"title"] forState:ib_state(st)];
                    if (st[@"titleColor"]) [obj setTitleColor:ib_value(st[@"titleColor"], loader) forState:ib_state(st)];
                    if (st[@"image"]) [obj setImage:ib_value(st[@"image"], loader) forState:ib_state(st)];
                }
            }
            else if ([k isEqualToString:@"titleFont"] && [obj isKindOfClass:[UIButton class]]) ((UIButton *)obj).titleLabel.font = ib_value(v, loader);
            else if ([k isEqualToString:@"segments"] && [obj isKindOfClass:[UISegmentedControl class]]) {
                UISegmentedControl *sc = obj; [sc removeAllSegments];
                NSUInteger i = 0;
                for (NSDictionary *sg in v) {
                    if (sg[@"image"]) [sc insertSegmentWithImage:ib_value(sg[@"image"], loader) atIndex:i animated:NO];
                    else [sc insertSegmentWithTitle:sg[@"title"] ?: @"" atIndex:i animated:NO];
                    if (sg[@"enabled"] && ![sg[@"enabled"] boolValue]) [sc setEnabled:NO forSegmentAtIndex:i];
                    i++;
                }
            }
            else if ([k isEqualToString:@"activityStyle"] && [obj isKindOfClass:[UIActivityIndicatorView class]]) ((UIActivityIndicatorView *)obj).activityIndicatorViewStyle = [v integerValue];
            else if ([k isEqualToString:@"toolbarHidden"] && [obj isKindOfClass:[UINavigationController class]]) ((UINavigationController *)obj).toolbarHidden = [v boolValue];
            else if ([k isEqualToString:@"navigationBarHidden"] && [obj isKindOfClass:[UINavigationController class]]) ((UINavigationController *)obj).navigationBarHidden = [v boolValue];
            else if ([k isEqualToString:@"automaticEstimatedItemSize"] && [v boolValue] && [obj isKindOfClass:[UICollectionViewFlowLayout class]]) ((UICollectionViewFlowLayout *)obj).estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize;
            else if ([k isEqualToString:@"rowHeight"]) {}
            /* handled at init: buttonType, tableStyle, cellStyle, reuseIdentifier, builtin_*, systemItem, image, barButtonStyle, ... */
            continue;
        }
        ib_set(obj, key, v, loader);
    }
    /* things that need the other attributes first */
    if ([props[@"$selectedSegmentIndex"] isKindOfClass:[NSNumber class]] && [obj isKindOfClass:[UISegmentedControl class]])
        ((UISegmentedControl *)obj).selectedSegmentIndex = [props[@"$selectedSegmentIndex"] integerValue];
    if (props[@"$configuration"] && [obj isKindOfClass:[UIButton class]]) ib_button_configuration(obj, props[@"$configuration"], loader);
    if ([props[@"$animating"] boolValue] && [obj isKindOfClass:[UIActivityIndicatorView class]]) [obj startAnimating];
}

/* ================= coder ================= */
@implementation __IsimIBCoder
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)containsValueForKey:(NSString *)k { return _node[@"props"][k] != nil; }
- (id)decodeObjectForKey:(NSString *)k { return ib_value(_node[@"props"][k], _loader); }
- (int64_t)decodeInt64ForKey:(NSString *)k { return [_node[@"props"][k] longLongValue]; }
- (double)decodeDoubleForKey:(NSString *)k { return [_node[@"props"][k] doubleValue]; }
- (BOOL)decodeBoolForKey:(NSString *)k { return [_node[@"props"][k] boolValue]; }
@end

/* ================= init(coder:) for UIKit classes ================= */
id isim_ib_decode_object(id obj, __IsimIBCoder *coder);

/* Called by every UIKit -initWithCoder:. Returns the initialized object (IB attributes applied when the coder
   is isim's IB coder). */
id isim_ib_init_with_coder(id self, NSCoder *c) {
    __IsimIBCoder *coder = [c isKindOfClass:[__IsimIBCoder class]] ? (__IsimIBCoder *)c : nil;
    NSDictionary *props = coder.node[@"props"];
    Class kit = ib_kit_class(object_getClass(self));
    if ([self isKindOfClass:[UIViewController class]]) {
        if ([self isKindOfClass:[UITableViewController class]]) {
            SEL s = @selector(initWithStyle:);
            self = ((id (*)(id, SEL, UITableViewStyle))class_getMethodImplementation(kit, s))(self, s, UITableViewStylePlain);
        } else if ([self isKindOfClass:[UIPageViewController class]]) {
            SEL s = @selector(initWithTransitionStyle:navigationOrientation:options:);
            self = ((id (*)(id, SEL, NSInteger, NSInteger, id))class_getMethodImplementation(kit, s))(self, s,
                    props[@"$pageTransitionStyle"] ? [props[@"$pageTransitionStyle"] integerValue] : 1, [props[@"$pageNavigationOrientation"] integerValue], nil);
        } else {
            SEL s = @selector(initWithNibName:bundle:);
            self = ((id (*)(id, SEL, id, id))class_getMethodImplementation(kit, s))(self, s, nil, nil);
        }
    } else if ([self isKindOfClass:[UITableViewCell class]]) {
        SEL s = @selector(initWithStyle:reuseIdentifier:);
        self = ((id (*)(id, SEL, UITableViewCellStyle, id))class_getMethodImplementation(kit, s))(self, s, [props[@"$cellStyle"] integerValue], props[@"$reuseIdentifier"]);
    } else if ([self isKindOfClass:[UITableViewHeaderFooterView class]]) {
        SEL s = @selector(initWithReuseIdentifier:);
        self = ((id (*)(id, SEL, id))class_getMethodImplementation(kit, s))(self, s, props[@"$reuseIdentifier"]);
    } else if ([self isKindOfClass:[UITableView class]]) {
        SEL s = @selector(initWithFrame:style:);
        self = ((id (*)(id, SEL, CGRect, UITableViewStyle))class_getMethodImplementation(kit, s))(self, s, CGRectZero, [props[@"$tableStyle"] integerValue]);
    } else if ([self isKindOfClass:[UICollectionView class]]) {
        NSDictionary *layoutNode = coder.node[@"keyed"][@"collectionViewLayout"];
        UICollectionViewLayout *layout = layoutNode ? [coder.loader instantiate:layoutNode] : [UICollectionViewFlowLayout new];
        SEL s = @selector(initWithFrame:collectionViewLayout:);
        self = ((id (*)(id, SEL, CGRect, id))class_getMethodImplementation(kit, s))(self, s, CGRectZero, layout);
    } else if ([self isKindOfClass:[UIView class]]) {
        SEL s = @selector(initWithFrame:);
        CGRect f = props[@"frame"] ? [ib_value(props[@"frame"], nil) CGRectValue] : CGRectZero;
        self = ((id (*)(id, SEL, CGRect))class_getMethodImplementation(kit, s))(self, s, f);
    } else {
        SEL s = @selector(init);
        self = ((id (*)(id, SEL))class_getMethodImplementation(kit, s))(self, s);
    }
    if (self && coder) isim_ib_decode_object(self, coder);
    return self;
}

/* ================= keyed objects ================= */
static UIBarButtonItem *ib_bar_button(NSDictionary *node, __IsimIBLoader *loader) {
    Class cls = ib_resolve_class(node);
    NSDictionary *p = node[@"props"];
    UIBarButtonItem *item;
    if (p[@"$systemItem"]) item = [[cls alloc] initWithBarButtonSystemItem:[p[@"$systemItem"] integerValue] target:nil action:NULL];
    else item = [[cls alloc] init];
    if (p[@"$barButtonStyle"]) item.style = [p[@"$barButtonStyle"] integerValue];
    NSDictionary *custom = node[@"keyed"][@"customView"];
    if (custom) item.customView = [loader instantiate:custom];
    return item;
}
static UITabBarItem *ib_tab_item(NSDictionary *node) {
    Class cls = ib_resolve_class(node);
    NSDictionary *p = node[@"props"];
    if (p[@"$systemItem"]) return [[cls alloc] initWithTabBarSystemItem:[p[@"$systemItem"] integerValue] tag:[p[@"tag"] integerValue]];
    return [[cls alloc] init];
}

/* objects IB makes without NSCoding (bar items, gesture recognizers, layouts, custom objects) */
static id ib_make_plain(NSDictionary *node, __IsimIBLoader *loader) {
    Class cls = ib_resolve_class(node);
    NSString *tag = node[@"tag"];
    id obj;
    if ([tag isEqualToString:@"barButtonItem"]) obj = ib_bar_button(node, loader);
    else if ([tag isEqualToString:@"tabBarItem"]) obj = ib_tab_item(node);
    else if ([cls isSubclassOfClass:[UIGestureRecognizer class]]) obj = [[cls alloc] initWithTarget:nil action:NULL];
    else if ([cls isSubclassOfClass:[UINavigationItem class]]) obj = [[cls alloc] initWithTitle:node[@"props"][@"title"] ?: @""];
    else obj = [[cls alloc] init];
    return obj;
}

/* apply a node's attributes to an object that already exists (a controller's navigationItem, a cell's contentView) */
static void ib_configure_existing(id obj, NSDictionary *node, __IsimIBLoader *loader);

static void ib_keyed(id obj, NSDictionary *node, __IsimIBLoader *loader) {
    NSDictionary *keyed = node[@"keyed"];
    for (NSString *key in keyed) {
        id spec = keyed[key];
        if ([key isEqualToString:@"view"] && [obj isKindOfClass:[UIViewController class]]) continue;     /* loaded lazily */
        if ([key isEqualToString:@"collectionViewLayout"] || [key isEqualToString:@"customView"]) continue;   /* used at init */
        if ([spec isKindOfClass:[NSArray class]]) {
            NSMutableArray *items = [NSMutableArray array];
            for (NSDictionary *n in spec) { id o = [loader instantiate:n]; if (o) [items addObject:o]; }
            if ([key isEqualToString:@"toolbarItems"]) [(UIViewController *)obj setToolbarItems:items];
            else [obj setValue:items forKey:key];
            continue;
        }
        NSDictionary *n = spec;
        /* objects the owner already has: configure in place */
        if (([key isEqualToString:@"navigationItem"] && [obj isKindOfClass:[UIViewController class]]) ||
            ([key isEqualToString:@"navigationBar"] && [obj isKindOfClass:[UINavigationController class]]) ||
            ([key isEqualToString:@"toolbar"] && [obj isKindOfClass:[UINavigationController class]]) ||
            ([key isEqualToString:@"tabBar"] && [obj isKindOfClass:[UITabBarController class]]) ||
            ([key isEqualToString:@"contentView"] && ([obj isKindOfClass:[UITableViewCell class]] || [obj isKindOfClass:[UICollectionViewCell class]] ||
                                                       [obj isKindOfClass:[UITableViewHeaderFooterView class]]))) {
            ib_configure_existing([obj valueForKey:key], n, loader);
            continue;
        }
        id child = [loader instantiate:n];
        if (!child) continue;
        if ([key isEqualToString:@"tabBarItem"]) [(UIViewController *)obj setTabBarItem:child];
        else if ([obj isKindOfClass:[UINavigationItem class]] && [key hasSuffix:@"BarButtonItem"]) [obj setValue:child forKey:key];
        else ib_set(obj, key, child, loader);
    }
}

static void ib_add_subviews(UIView *view, NSDictionary *node, __IsimIBLoader *loader) {
    /* a style cell's content view: the subviews IB lists for textLabel/detailTextLabel/imageView are the built-in ones */
    NSMutableDictionary *builtin = [NSMutableDictionary dictionary];
    UITableViewCell *cell = nil;
    if ([view.superview isKindOfClass:[UITableViewCell class]] && ((UITableViewCell *)view.superview).contentView == view) cell = (UITableViewCell *)view.superview;
    if (cell) {
        NSDictionary *cp = objc_getAssociatedObject(cell, "isim.ib.cellprops");
        for (NSString *k in @[@"textLabel", @"detailTextLabel", @"imageView"]) {
            NSString *ident = cp[[@"$builtin_" stringByAppendingString:k]];
            if (ident) builtin[ident] = k;
        }
    }
    for (NSDictionary *sub in node[@"subviews"]) {
        NSString *b = builtin[sub[@"id"]];
        if (b && [cell valueForKey:b]) {                                   /* style cell: the built-in label/image */
            id existing = [cell valueForKey:b];
            ib_configure_existing(existing, sub, loader);
            continue;
        }
        UIView *v = [loader instantiate:sub];
        if (!v) continue;
        if ([view isKindOfClass:[UIStackView class]]) [(UIStackView *)view addArrangedSubview:v];
        else [view addSubview:v];
    }
}

static void ib_prototypes(id obj, NSDictionary *node, __IsimIBLoader *loader);

static void ib_configure_existing(id obj, NSDictionary *node, __IsimIBLoader *loader) {
    if (!obj) return;
    if (node[@"id"]) loader.objects[node[@"id"]] = obj;
    NSMutableDictionary *props = [node[@"props"] mutableCopy];
    if ([obj isKindOfClass:[UIView class]] && [node[@"tag"] hasSuffix:@"ContentView"]) {
        [props removeObjectForKey:@"frame"]; [props removeObjectForKey:@"autoresizingMask"];   /* the cell sizes it */
        /* a table cell's content view has the system cell margins (iPhone: 11 pt vertical, 20 pt horizontal) */
        if ([node[@"tag"] isEqualToString:@"tableViewCellContentView"] && !props[@"layoutMargins"] && !props[@"directionalLayoutMargins"])
            ((UIView *)obj).layoutMargins = UIEdgeInsetsMake(11, 20, 11, 20);
    }
    if ([obj isKindOfClass:[UILabel class]] || [obj isKindOfClass:[UIImageView class]]) {
        [props removeObjectForKey:@"frame"]; [props removeObjectForKey:@"autoresizingMask"];
        [props removeObjectForKey:@"translatesAutoresizingMaskIntoConstraints"];
    }
    ib_apply_props(obj, props, loader);
    if ([obj isKindOfClass:[UIView class]]) ib_add_subviews(obj, node, loader);
    ib_keyed(obj, node, loader);
    if (node[@"constraints"]) [loader.pendingConstraints addObject:@{@"owner": node[@"id"] ?: @"", @"list": node[@"constraints"]}];
    if (node[@"userDefined"]) [loader.pendingUserDefined addObject:@[obj, node[@"userDefined"]]];
    if (node[@"variations"] && [obj isKindOfClass:[UIView class]]) [loader.pendingVariations addObject:@[obj, node]];
}

/* everything a node describes, applied to a freshly initialized object */
id isim_ib_decode_object(id obj, __IsimIBCoder *coder) {
    __IsimIBLoader *loader = coder.loader;
    NSDictionary *node = coder.node;
    if (!loader || !node) return obj;
    if (node[@"id"]) loader.objects[node[@"id"]] = obj;
    [loader.awake addObject:obj];
    NSDictionary *props = node[@"props"];
    if ([obj isKindOfClass:[UIButton class]] && props[@"$buttonType"]) {
        [obj setValue:props[@"$buttonType"] forKey:@"buttonType"];
        if ([obj respondsToSelector:NSSelectorFromString(@"_isim_applyType")]) ((void (*)(id, SEL))objc_msgSend)(obj, NSSelectorFromString(@"_isim_applyType"));
    }
    if ([obj isKindOfClass:[UITableViewCell class]]) objc_setAssociatedObject(obj, "isim.ib.cellprops", props, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([obj isKindOfClass:[UIViewController class]]) {
        UIViewController *vc = obj;
        objc_setAssociatedObject(vc, &kLoaderKey, loader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (loader.storyboard) objc_setAssociatedObject(vc, &kStoryboardKey, loader.storyboard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!loader.sceneController) loader.sceneController = vc;
    }
    ib_apply_props(obj, props, loader);
    if ([obj isKindOfClass:[UIView class]] && ![obj isKindOfClass:[UIViewController class]]) ib_add_subviews(obj, node, loader);
    ib_keyed(obj, node, loader);
    if (node[@"prototypes"]) ib_prototypes(obj, node, loader);
    if (node[@"constraints"]) [loader.pendingConstraints addObject:@{@"owner": node[@"id"] ?: @"", @"list": node[@"constraints"]}];
    if (node[@"userDefined"]) [loader.pendingUserDefined addObject:@[obj, node[@"userDefined"]]];
    if (node[@"variations"] && [obj isKindOfClass:[UIView class]]) [loader.pendingVariations addObject:@[obj, node]];
    return obj;
}

/* ================= loader ================= */
@implementation __IsimIBLoader
- (instancetype)initWithArchive:(NSDictionary *)arc bundle:(NSBundle *)b {
    if ((self = [super init])) {
        _archive = arc; _bundle = b ?: NSBundle.mainBundle;
        _objects = [NSMutableDictionary dictionary]; _weakObjects = [NSMapTable strongToWeakObjectsMapTable];
        _applied = [NSMutableIndexSet indexSet];
        _awake = [NSMutableArray array]; _pendingConstraints = [NSMutableArray array]; _pendingUserDefined = [NSMutableArray array];
        _pendingVariations = [NSMutableArray array]; _constraintsByID = [NSMutableDictionary dictionary];
    }
    return self;
}
- (id)instantiate:(NSDictionary *)node {
    if (![node isKindOfClass:[NSDictionary class]]) return nil;
    Class cls = ib_resolve_class(node);
    NSString *tag = node[@"tag"];
    BOOL coded = [cls isSubclassOfClass:[UIView class]] || [cls isSubclassOfClass:[UIViewController class]];
    if (!coded) {
        id obj = ib_make_plain(node, self);
        if (!obj) return nil;
        if (node[@"id"]) _objects[node[@"id"]] = obj;
        [_awake addObject:obj];
        ib_apply_props(obj, node[@"props"], self);
        ib_keyed(obj, node, self);
        if (node[@"userDefined"]) [_pendingUserDefined addObject:@[obj, node[@"userDefined"]]];
        (void)tag;
        return obj;
    }
    __IsimIBCoder *coder = [__IsimIBCoder new]; coder.node = node; coder.loader = self;
    id obj = [[cls alloc] initWithCoder:coder];
    if (obj && node[@"id"] && !_objects[node[@"id"]]) {
        /* a class whose initWithCoder: did not reach UIKit's (e.g. it returned another object): decode now */
        isim_ib_decode_object(obj, coder);
    }
    return obj;
}
- (id)objectForID:(NSString *)ident found:(BOOL *)found {
    *found = YES;
    if (!ident) { *found = NO; return nil; }
    id o = _objects[ident];
    if (o) return o;
    o = [_weakObjects objectForKey:ident];
    if (o) return o;
    NSString *ph = _archive[@"placeholders"][ident];
    if ([ph isEqualToString:@"firstResponder"]) return nil;          /* nil target: the responder chain */
    if (_parent) return [_parent objectForID:ident found:found];
    *found = NO;
    return nil;
}
- (BOOL)isExit:(NSString *)ident {
    if ([_archive[@"placeholders"][ident] isEqualToString:@"exit"]) return YES;
    return _parent ? [_parent isExit:ident] : NO;
}
/* the item a constraint names: a view, or a layout guide of a view */
- (id)constraintItem:(NSString *)ident {
    BOOL found;
    id o = [self objectForID:ident found:&found];
    if (o) return o;
    NSDictionary *g = _archive[@"guides"][ident];
    for (__IsimIBLoader *l = self; !g && l.parent; l = l.parent) g = l.parent.archive[@"guides"][ident];
    if (!g) return nil;
    UIView *v = [self objectForID:g[@"view"] found:&found];
    NSString *kind = g[@"kind"];
    if ([kind isEqualToString:@"safeArea"]) return v.safeAreaLayoutGuide;
    if ([kind isEqualToString:@"layoutMargins"]) return v.layoutMarginsGuide;
    if ([kind isEqualToString:@"readableContent"]) return v.readableContentGuide;
    if ([kind isEqualToString:@"contentLayout"] && [v isKindOfClass:[UIScrollView class]]) return ((UIScrollView *)v).contentLayoutGuide;
    if ([kind isEqualToString:@"frameLayout"] && [v isKindOfClass:[UIScrollView class]]) return ((UIScrollView *)v).frameLayoutGuide;
    if ([kind isEqualToString:@"keyboard"] && [v respondsToSelector:NSSelectorFromString(@"keyboardLayoutGuide")]) return [v valueForKey:@"keyboardLayoutGuide"];
    if ([kind isEqualToString:@"keyboard"]) return v.safeAreaLayoutGuide;
    return nil;
}
- (void)applyConstraints {
    NSArray *pending = [_pendingConstraints copy];
    [_pendingConstraints removeAllObjects];
    NSMutableArray *all = [NSMutableArray array];
    for (NSDictionary *group in pending) {
        for (NSDictionary *c in group[@"list"]) {
            id first = [self constraintItem:c[@"first"]];
            id second = c[@"second"] ? [self constraintItem:c[@"second"]] : nil;
            if (!first || (c[@"second"] && !second)) { NSLog(@"isim: IB constraint %@: missing item", c[@"id"]); continue; }
            NSLayoutConstraint *k = [NSLayoutConstraint constraintWithItem:first attribute:[c[@"firstAttr"] integerValue] relatedBy:[c[@"relation"] integerValue]
                                                                    toItem:second attribute:second ? [c[@"secondAttr"] integerValue] : NSLayoutAttributeNotAnAttribute
                                                                multiplier:[c[@"multiplier"] doubleValue] constant:[c[@"constant"] doubleValue]];
            k.priority = [c[@"priority"] floatValue];
            if (c[@"identifier"]) k.identifier = c[@"identifier"];
            if ([c[@"id"] length]) _constraintsByID[c[@"id"]] = k;
            [all addObject:k];
        }
    }
    if (all.count) [NSLayoutConstraint activateConstraints:all];
}
/* size-class variations: which constraints and subviews are installed, and property overrides, for the view's current
   size classes; applied again whenever its size classes change (rotation, iPad multitasking) */
- (void)applyVariations {
    NSArray *pending = [_pendingVariations copy];
    [_pendingVariations removeAllObjects];
    for (NSArray *pair in pending) {
        UIView *view = pair[0];
        __IsimIBVariations *rec = [__IsimIBVariations new];
        rec.view = view; rec.node = pair[1]; rec.loader = self;
        NSMutableDictionary *cons = [NSMutableDictionary dictionary], *subs = [NSMutableDictionary dictionary];
        for (NSDictionary *v in rec.node[@"variations"])
            for (NSString *mode in @[@"include", @"exclude"]) {
                for (NSString *ident in v[mode][@"constraints"]) if (_constraintsByID[ident]) cons[ident] = _constraintsByID[ident];
                for (NSString *ident in v[mode][@"subviews"]) { BOOL f = NO; id o = [self objectForID:ident found:&f]; if ([o isKindOfClass:[UIView class]]) subs[ident] = o; }
            }
        rec.constraints = cons; rec.subviews = subs;
        NSMutableDictionary *indices = [NSMutableDictionary dictionary];
        for (NSString *ident in subs) { UIView *sv = subs[ident]; NSUInteger i = [view.subviews indexOfObjectIdenticalTo:sv]; if (i != NSNotFound) indices[ident] = @(i); }
        rec.indices = indices;
        objc_setAssociatedObject(view, "isim.ib.variations", rec, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [rec apply];
        __weak __IsimIBVariations *wr = rec;
        [view registerForTraitChanges:@[UITraitHorizontalSizeClass.class, UITraitVerticalSizeClass.class] withHandler:^(id env, UITraitCollection *prev) { [wr apply]; }];
    }
}
- (void)applyConnections {
    NSArray *conns = _archive[@"connections"];
    NSMutableDictionary<NSString *, NSMutableArray *> *collections = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableArray *> *tabChildren = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < conns.count; i++) {
        if ([_applied containsIndex:i]) continue;
        NSDictionary *c = conns[i];
        NSString *type = c[@"type"];
        BOOL fs = NO, fd = NO;
        id src = [self objectForID:c[@"source"] found:&fs];
        if (!fs) continue;                                            /* not loaded yet (e.g. inside the lazy view) */
        if ([type isEqualToString:@"segue"]) {
            NSString *kind = c[@"kind"];
            if ([kind isEqualToString:@"relationship"]) {
                UIViewController *child = [_storyboard _isim_instantiateScene:c[@"destination"] creator:nil];
                [_applied addIndex:i];
                if (!child) continue;
                NSString *rel = c[@"relationship"];
                if ([rel isEqualToString:@"rootViewController"] && [src isKindOfClass:[UINavigationController class]]) [(UINavigationController *)src setViewControllers:@[child] animated:NO];
                else if ([rel isEqualToString:@"viewControllers"]) {
                    NSString *k = c[@"source"];
                    if (!tabChildren[k]) tabChildren[k] = [NSMutableArray array];
                    [tabChildren[k] addObject:child];
                } else if ([src respondsToSelector:NSSelectorFromString(@"setViewControllers:")]) {
                    NSString *k = c[@"source"];
                    if (!tabChildren[k]) tabChildren[k] = [NSMutableArray array];
                    [tabChildren[k] addObject:child];
                }
                continue;
            }
            if ([kind isEqualToString:@"embed"]) {
                if (![src isKindOfClass:[UIView class]]) continue;
                [_applied addIndex:i];
                UIView *container = src;
                UIViewController *parent = _sceneController;
                UIViewController *child = [_storyboard _isim_instantiateScene:c[@"destination"] creator:nil];
                if (!child || !parent) continue;
                UIStoryboardSegue *segue = [[UIStoryboardSegue alloc] initWithIdentifier:c[@"identifier"] source:parent destination:child];
                [parent prepareForSegue:segue sender:nil];
                [parent addChildViewController:child];
                child.view.frame = container.bounds;
                child.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [container addSubview:child.view];
                [child didMoveToParentViewController:parent];
                continue;
            }
            /* show / present / custom / unwind: a template run when triggered or performed by identifier */
            [_applied addIndex:i];
            __IsimSegueTemplate *t = [__IsimSegueTemplate new];
            t.conn = c; t.loader = self; t.storyboard = _storyboard;
            t.sourceController = _sceneController;
            if (src == _sceneController || !src) {
                /* manual segue of the controller */
            } else if ([src isKindOfClass:[UIControl class]]) {
                __IsimSegueTrigger *trig = [__IsimSegueTrigger new]; trig.segue = t;
                objc_setAssociatedObject(src, &kTriggerKey, trig, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [(UIControl *)src addTarget:trig action:@selector(fire:) forControlEvents:UIControlEventPrimaryActionTriggered];
            } else if ([src isKindOfClass:[UIBarButtonItem class]]) {
                __IsimSegueTrigger *trig = [__IsimSegueTrigger new]; trig.segue = t;
                objc_setAssociatedObject(src, &kTriggerKey, trig, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                ((UIBarButtonItem *)src).target = trig; ((UIBarButtonItem *)src).action = @selector(fire:);
            } else if ([src isKindOfClass:[UIGestureRecognizer class]]) {
                __IsimSegueTrigger *trig = [__IsimSegueTrigger new]; trig.segue = t;
                objc_setAssociatedObject(src, &kTriggerKey, trig, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [(UIGestureRecognizer *)src addTarget:trig action:@selector(fire:)];
            } else if ([src isKindOfClass:[UITableViewCell class]] || [src isKindOfClass:[UICollectionViewCell class]]) {
                if (![c[@"trigger"] isEqualToString:@"accessoryAction"]) objc_setAssociatedObject(src, &kCellSegueKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (c[@"identifier"] && _sceneController) {
                NSMutableDictionary *ts = objc_getAssociatedObject(_sceneController, &kTemplatesKey);
                if (!ts) { ts = [NSMutableDictionary dictionary]; objc_setAssociatedObject(_sceneController, &kTemplatesKey, ts, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
                if (!ts[c[@"identifier"]]) ts[c[@"identifier"]] = t;
            }
            continue;
        }
        id dst = [self objectForID:c[@"destination"] found:&fd];
        if (!fd && ![_archive[@"placeholders"][c[@"destination"]] isEqualToString:@"firstResponder"]) continue;
        [_applied addIndex:i];
        if ([type isEqualToString:@"outlet"]) {
            if (!ib_kvc_set(src, c[@"property"], dst))
                NSLog(@"isim: [<%@ %p> setValue:forUndefinedKey:]: this class is not key value coding-compliant for the key %@ (IB outlet ignored)", [src class], src, c[@"property"]);
        } else if ([type isEqualToString:@"outletCollection"]) {
            if ([c[@"appends"] boolValue] && [c[@"property"] isEqualToString:@"gestureRecognizers"] && [src isKindOfClass:[UIView class]]) {
                if (dst) [(UIView *)src addGestureRecognizer:dst];
                continue;
            }
            NSString *k = [NSString stringWithFormat:@"%p/%@", src, c[@"property"]];
            if (!collections[k]) collections[k] = [NSMutableArray arrayWithObjects:src, c[@"property"], nil];
            if (dst) [collections[k] addObject:dst];
        } else if ([type isEqualToString:@"action"]) {
            SEL sel = NSSelectorFromString(c[@"selector"]);
            if ([src isKindOfClass:[UIControl class]])
                [(UIControl *)src addTarget:dst action:sel forControlEvents:c[@"events"] ? [c[@"events"] unsignedIntegerValue] : UIControlEventPrimaryActionTriggered];
            else if ([src isKindOfClass:[UIBarButtonItem class]]) { ((UIBarButtonItem *)src).target = dst; ((UIBarButtonItem *)src).action = sel; }
            else if ([src isKindOfClass:[UIGestureRecognizer class]]) [(UIGestureRecognizer *)src addTarget:dst action:sel];
            else NSLog(@"isim: IB action %@ from %@ is not supported", c[@"selector"], [src class]);
        }
    }
    for (NSString *k in collections) {
        NSMutableArray *a = collections[k];
        id src = a[0]; NSString *prop = a[1];
        NSArray *items = [a subarrayWithRange:NSMakeRange(2, a.count - 2)];
        if (!ib_kvc_set(src, prop, items)) NSLog(@"isim: IB outlet collection %@ of %@: no such property", prop, [src class]);
    }
    for (NSString *k in tabChildren) {
        BOOL f;
        id src = [self objectForID:k found:&f];
        if ([src isKindOfClass:[UITabBarController class]]) [(UITabBarController *)src setViewControllers:tabChildren[k]];
        else if ([src respondsToSelector:@selector(setViewControllers:)]) [src setViewControllers:tabChildren[k]];
    }
}
- (void)applyUserDefined {
    NSArray *pending = [_pendingUserDefined copy];
    [_pendingUserDefined removeAllObjects];
    for (NSArray *p in pending) {
        id obj = p[0];
        for (NSDictionary *a in p[1]) {
            NSString *kp = a[@"keyPath"];
            BOOL ok;
            if ([kp containsString:@"."]) {
                NSArray *parts = [kp componentsSeparatedByString:@"."];
                id target = obj;
                for (NSUInteger j = 0; j + 1 < parts.count && target; j++)
                    target = [target respondsToSelector:NSSelectorFromString(parts[j])] ? [target valueForKey:parts[j]] : nil;
                ok = target && ib_set(target, parts.lastObject, a[@"value"], self);
            } else ok = ib_set(obj, kp, a[@"value"], self);
            if (!ok) NSLog(@"isim: Failed to set (%@) user defined inspected property on (%@): this class is not key value coding-compliant for the key %@.", kp, [obj class], kp);
        }
    }
}
- (void)finish {
    [self applyConstraints];
    [self applyVariations];
    [self applyConnections];
    [self applyUserDefined];
    NSArray *aw = [_awake copy];
    [_awake removeAllObjects];
    for (id o in aw) [o awakeFromNib];
}
@end

/* ================= prototype cells: per-identifier nibs registered with the table/collection ================= */
static void ib_prototypes(id obj, NSDictionary *node, __IsimIBLoader *loader) {
    for (NSDictionary *arc in node[@"prototypes"]) {
        NSString *rid = arc[@"root"][@"props"][@"$reuseIdentifier"];
        if (!rid.length) continue;
        UINib *nib = [UINib new];
        nib.archive = arc; nib.bundle = loader.bundle; nib.sceneLoader = loader;
        nib.name = [NSString stringWithFormat:@"prototype %@", rid];
        if ([obj isKindOfClass:[UITableView class]]) [(UITableView *)obj registerNib:nib forCellReuseIdentifier:rid];
        else if ([obj isKindOfClass:[UICollectionView class]]) {
            if (arc[@"supplementaryKind"]) [(UICollectionView *)obj registerNib:nib forSupplementaryViewOfKind:arc[@"supplementaryKind"] withReuseIdentifier:rid];
            else [(UICollectionView *)obj registerNib:nib forCellWithReuseIdentifier:rid];
        }
    }
}

/* ================= UINib ================= */
static NSString *ib_find(NSBundle *bundle, NSString *name, NSString *ext, NSString *file) {
    NSString *p = [bundle pathForResource:name ofType:ext];
    if (p) {
        BOOL dir = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:p isDirectory:&dir] && dir) p = [p stringByAppendingPathComponent:file];
        if ([NSFileManager.defaultManager fileExistsAtPath:p]) return p;
    }
    return nil;
}

@implementation UINib
+ (UINib *)nibWithNibName:(NSString *)name bundle:(NSBundle *)bundle {
    bundle = bundle ?: NSBundle.mainBundle;
    NSString *base = [name hasSuffix:@".nib"] ? [name stringByDeletingPathExtension] : name;
    NSString *path = ib_find(bundle, base, @"nib", @"isim-nib.plist");
    UINib *nib = [UINib new];
    nib.bundle = bundle; nib.name = base;
    if (!path) return nib;                        /* like iOS: the error comes when it is instantiated */
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (![d[@"format"] isEqualToString:@"isim-nib"]) NSLog(@"isim: %@ is not an isim nib (rebuild it with `isim build`)", path);
    nib.archive = d[@"archive"];
    return nib;
}
+ (UINib *)nibWithData:(NSData *)data bundle:(NSBundle *)bundle {
    UINib *nib = [UINib new];
    nib.bundle = bundle ?: NSBundle.mainBundle;
    NSDictionary *d = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    nib.archive = d[@"archive"] ?: d;
    return nib;
}
- (NSArray *)instantiateWithOwner:(id)owner options:(NSDictionary *)options {
    if (!_archive) [NSException raise:NSInternalInconsistencyException format:@"Could not load NIB in bundle: '%@' with name '%@'", _bundle.bundlePath, _name];
    __IsimIBLoader *l = [[__IsimIBLoader alloc] initWithArchive:_archive bundle:_bundle];
    l.storyboard = _sceneLoader.storyboard;
    l.parent = _sceneLoader;
    l.sceneController = _sceneLoader.sceneController;
    NSDictionary *externals = options[UINibExternalObjects];
    [_archive[@"placeholders"] enumerateKeysAndObjectsUsingBlock:^(NSString *ident, NSString *kind, BOOL *stop) {
        if ([kind isEqualToString:@"owner"]) { if (owner) [l.weakObjects setObject:owner forKey:ident]; }
        else if (externals[kind]) [l.weakObjects setObject:externals[kind] forKey:ident];
    }];
    if ([owner isKindOfClass:[UIViewController class]] && !l.sceneController) l.sceneController = owner;
    NSMutableArray *top = [NSMutableArray array];
    if (_archive[@"root"]) { id o = [l instantiate:_archive[@"root"]]; if (o) [top addObject:o]; }
    for (NSDictionary *n in _archive[@"objects"]) { id o = [l instantiate:n]; if (o) [top addObject:o]; }
    [l finish];
    /* prototype cells keep their loader (segue templates refer to it) */
    for (id o in top) if (![o isKindOfClass:[UIViewController class]]) objc_setAssociatedObject(o, &kLoaderKey, l, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return top;
}
@end

@implementation NSBundle (UINibLoadingAdditions)
- (NSArray *)loadNibNamed:(NSString *)name owner:(id)owner options:(NSDictionary *)options {
    UINib *nib = [UINib nibWithNibName:name bundle:self];
    return [nib instantiateWithOwner:owner options:options];
}
@end

@implementation NSObject (UINibLoadingAdditions)
- (void)awakeFromNib {}
- (void)prepareForInterfaceBuilder {}
@end

/* ================= table / collection nib registration ================= */
static NSMutableDictionary *ib_nibs(id view) {
    NSMutableDictionary *d = objc_getAssociatedObject(view, &kCellNibsKey);
    if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(view, &kCellNibsKey, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return d;
}
static id ib_instantiate_registered(id view, NSString *key, NSString *rid) {
    UINib *nib = objc_getAssociatedObject(view, &kCellNibsKey)[key];
    if (!nib) return nil;
    for (id o in [nib instantiateWithOwner:nil options:nil]) {
        if ([o isKindOfClass:[UIView class]]) {
            if ([o respondsToSelector:@selector(reuseIdentifier)] && ![[o valueForKey:@"reuseIdentifier"] isEqual:rid]) {
                ib_kvc_set(o, @"reuseIdentifier", rid);
            }
            return o;
        }
    }
    [NSException raise:NSInternalInconsistencyException format:@"invalid nib registered for identifier (%@) - nib must contain exactly one top level object which must be a cell instance", rid];
    return nil;
}
UITableViewCell *isim_ib_dequeue_table_cell(UITableView *tv, NSString *rid) { return ib_instantiate_registered(tv, [@"cell/" stringByAppendingString:rid], rid); }
UIView *isim_ib_dequeue_table_header(UITableView *tv, NSString *rid) { return ib_instantiate_registered(tv, [@"hf/" stringByAppendingString:rid], rid); }
UIView *isim_ib_dequeue_collection(UICollectionView *cv, NSString *key, NSString *rid) { return ib_instantiate_registered(cv, key, rid); }

@implementation UITableView (UINibRegistration)
- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)rid {
    NSString *k = [@"cell/" stringByAppendingString:rid];
    if (nib) { ib_nibs(self)[k] = nib; [self registerClass:nil forCellReuseIdentifier:rid]; }
    else [ib_nibs(self) removeObjectForKey:k];
}
- (void)registerNib:(UINib *)nib forHeaderFooterViewReuseIdentifier:(NSString *)rid {
    NSString *k = [@"hf/" stringByAppendingString:rid];
    if (nib) ib_nibs(self)[k] = nib; else [ib_nibs(self) removeObjectForKey:k];
}
@end
@implementation UICollectionView (UINibRegistration)
- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)rid {
    NSString *k = [@"cell/" stringByAppendingString:rid];
    if (nib) ib_nibs(self)[k] = nib; else [ib_nibs(self) removeObjectForKey:k];
}
- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)rid {
    NSString *k = [kind stringByAppendingFormat:@"/%@", rid];
    if (nib) ib_nibs(self)[k] = nib; else [ib_nibs(self) removeObjectForKey:k];
}
@end

/* selecting a cell with a selection segue performs it (sender: the cell) */
void isim_ib_cell_selected(UIView *cell) {
    __IsimSegueTemplate *t = cell ? objc_getAssociatedObject(cell, &kCellSegueKey) : nil;
    if (t) [t performWithSender:cell checkShould:YES];
}

/* ================= UIStoryboard ================= */
@implementation UIStoryboard
+ (UIStoryboard *)storyboardWithName:(NSString *)name bundle:(NSBundle *)bundle {
    bundle = bundle ?: NSBundle.mainBundle;
    NSString *path = ib_find(bundle, name, @"storyboardc", @"isim-storyboard.plist");
    if (!path) [NSException raise:NSInvalidArgumentException format:@"Could not find a storyboard named '%@' in bundle %@", name, bundle];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (![d[@"format"] isEqualToString:@"isim-storyboard"])
        [NSException raise:NSInvalidArgumentException format:@"%@ is not an isim storyboard (compile it with `isim build`)", path];
    UIStoryboard *sb = [UIStoryboard new];
    sb.name = name; sb.bundle = bundle; sb.data = d;
    return sb;
}
- (UIViewController *)_isim_instantiateScene:(NSString *)sceneID creator:(UIStoryboardViewControllerCreator)creator {
    NSDictionary *arc = _data[@"scenes"][sceneID];
    if (!arc) { NSLog(@"isim: storyboard %@ has no scene %@", _name, sceneID); return nil; }
    NSDictionary *ref = arc[@"reference"];
    if (ref) {                                                    /* storyboard reference */
        UIStoryboard *other = ref[@"storyboardName"] ? [UIStoryboard storyboardWithName:ref[@"storyboardName"] bundle:_bundle] : self;
        return ref[@"referencedIdentifier"] ? [other instantiateViewControllerWithIdentifier:ref[@"referencedIdentifier"] creator:creator]
                                            : [other instantiateInitialViewControllerWithCreator:creator];
    }
    __IsimIBLoader *l = [[__IsimIBLoader alloc] initWithArchive:arc bundle:_bundle];
    l.storyboard = self;
    NSDictionary *root = arc[@"root"];
    __IsimIBCoder *coder = [__IsimIBCoder new]; coder.node = root; coder.loader = l;
    UIViewController *vc;
    if (creator) {
        vc = creator(coder);
        if (vc && ![vc isKindOfClass:ib_resolve_class(root)])
            [NSException raise:NSInternalInconsistencyException format:@"Custom instantiated %@ must be a kind of class %@", vc, NSStringFromClass(ib_resolve_class(root))];
        if (!vc) vc = [[ib_resolve_class(root) alloc] initWithCoder:coder];      /* nil: the storyboard's own class */
    } else {
        vc = [[ib_resolve_class(root) alloc] initWithCoder:coder];
    }
    if (!vc) return nil;
    if (!l.objects[root[@"id"]]) isim_ib_decode_object(vc, coder);
    l.sceneController = vc;
    [l.weakObjects setObject:vc forKey:root[@"id"]];
    [l.objects removeObjectForKey:root[@"id"]];                   /* the controller retains its loader, not vice versa */
    for (NSDictionary *n in arc[@"objects"]) [l instantiate:n];   /* other scene objects (gesture recognizers, ...) */
    [l finish];
    return vc;
}
- (UIViewController *)instantiateInitialViewController { return [self instantiateInitialViewControllerWithCreator:nil]; }
- (UIViewController *)instantiateInitialViewControllerWithCreator:(UIStoryboardViewControllerCreator)creator {
    NSString *initial = _data[@"initialViewController"];
    if (!initial) return nil;
    return [self _isim_instantiateScene:initial creator:creator];
}
- (UIViewController *)instantiateViewControllerWithIdentifier:(NSString *)identifier { return [self instantiateViewControllerWithIdentifier:identifier creator:nil]; }
- (UIViewController *)instantiateViewControllerWithIdentifier:(NSString *)identifier creator:(UIStoryboardViewControllerCreator)creator {
    NSString *scene = _data[@"identifiers"][identifier];
    if (!scene) [NSException raise:NSInvalidArgumentException format:@"Storyboard (<UIStoryboard: %p>) doesn't contain a view controller with identifier '%@'", self, identifier];
    return [self _isim_instantiateScene:scene creator:creator];
}
- (NSString *)description { return [NSString stringWithFormat:@"<UIStoryboard: %p> %@", self, _name]; }
@end

/* ================= segues ================= */
@interface UIStoryboardSegue ()
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic, copy) NSDictionary *conn;
@end
@implementation UIStoryboardSegue
+ (instancetype)segueWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination performHandler:(void (^)(void))h {
    UIStoryboardSegue *s = [[self alloc] initWithIdentifier:identifier source:source destination:destination];
    s.handler = h;
    return s;
}
- (instancetype)initWithIdentifier:(NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination {
    if ((self = [super init])) { _identifier = [identifier copy]; _sourceViewController = source; _destinationViewController = destination; }
    return self;
}
- (void)perform {
    if (_handler) { _handler(); return; }
    NSString *kind = _conn[@"kind"] ?: @"show";
    BOOL animated = _conn[@"animates"] ? [_conn[@"animates"] boolValue] : YES;
    UIViewController *src = _sourceViewController, *dst = _destinationViewController;
    if ([kind isEqualToString:@"show"] || [kind isEqualToString:@"push"]) {
        if ([kind isEqualToString:@"push"] && src.navigationController) [src.navigationController pushViewController:dst animated:animated];
        else if (animated) [src showViewController:dst sender:self];
        else if (src.navigationController) [src.navigationController pushViewController:dst animated:NO];
        else [src presentViewController:dst animated:NO completion:nil];
    } else if ([kind isEqualToString:@"showDetail"]) {
        [src showDetailViewController:dst sender:self];
    } else {                                                      /* presentation, modal, popoverPresentation */
        [src presentViewController:dst animated:animated completion:nil];
    }
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p identifier = %@, source = %@, destination = %@>", [self class], self, _identifier, _sourceViewController, _destinationViewController]; }
@end

@interface UIStoryboardUnwindSegueSource ()
@property (readwrite) UIViewController *sourceViewController;
@property (readwrite) SEL unwindAction;
@property (readwrite) id sender;
@end
@implementation UIStoryboardUnwindSegueSource @end

/* the unwind segue's transition: dismiss what is presented above the destination, pop back to it */
@interface __IsimUnwindSegue : UIStoryboardSegue @end
@implementation __IsimUnwindSegue
- (void)perform {
    UIViewController *dst = self.destinationViewController;
    UIViewController *presenter = nil;
    for (UIViewController *p = dst; p && !presenter; p = p.parentViewController) if (p.presentedViewController) presenter = p;
    BOOL animated = self.conn[@"animates"] ? [self.conn[@"animates"] boolValue] : YES;
    if (presenter) [presenter dismissViewControllerAnimated:animated completion:nil];
    UINavigationController *nav = dst.navigationController;
    if (nav && nav.topViewController != dst && [nav.viewControllers containsObject:dst]) [nav popToViewController:dst animated:animated && !presenter];
    UITabBarController *tab = dst.tabBarController;
    if (tab) for (UIViewController *c in tab.viewControllers) {
        for (UIViewController *p = dst; p; p = p.parentViewController) if (p == c && tab.selectedViewController != c) tab.selectedViewController = c;
    }
}
@end

static UIViewController *unwind_search_down(UIViewController *vc, SEL action, UIViewController *src, id sender, UIViewController *skip) {
    if (!vc || vc == skip) return nil;
    NSArray *children = nil;
    if ([vc isKindOfClass:[UINavigationController class]]) children = [[(UINavigationController *)vc viewControllers] reverseObjectEnumerator].allObjects;
    else if ([vc isKindOfClass:[UITabBarController class]]) children = [(UITabBarController *)vc selectedViewController] ? @[[(UITabBarController *)vc selectedViewController]] : @[];
    else children = vc.childViewControllers;
    for (UIViewController *c in children) {
        if (c == skip) continue;
        UIViewController *r = unwind_search_down(c, action, src, sender, skip);
        if (r) return r;
    }
    if (vc != src && [vc canPerformUnwindSegueAction:action fromViewController:src sender:sender]) return vc;
    return nil;
}
static UIViewController *unwind_destination(UIViewController *src, SEL action, id sender) {
    UIViewController *came = src;
    for (UIViewController *vc = src; vc; ) {
        UIViewController *up = vc.parentViewController;
        if (up) {
            /* siblings below in a navigation stack, then the container itself */
            if ([up isKindOfClass:[UINavigationController class]]) {
                NSArray *stack = [(UINavigationController *)up viewControllers];
                NSUInteger i = [stack indexOfObjectIdenticalTo:vc];
                for (NSInteger j = (NSInteger)(i == NSNotFound ? stack.count : i) - 1; j >= 0; j--) {
                    UIViewController *r = unwind_search_down(stack[j], action, src, sender, nil);
                    if (r) return r;
                }
            }
            if (up != src && [up canPerformUnwindSegueAction:action fromViewController:src sender:sender]) return up;
            came = vc; vc = up;
            continue;
        }
        UIViewController *presenter = vc.presentingViewController;
        if (!presenter) break;
        /* the presenter and everything visible in it */
        UIViewController *top = presenter; while (top.parentViewController) top = top.parentViewController;
        UIViewController *r = unwind_search_down(top, action, src, sender, vc);
        if (r) return r;
        came = vc; vc = presenter;
    }
    (void)came;
    return nil;
}

@implementation __IsimSegueTemplate
- (void)performWithSender:(id)sender checkShould:(BOOL)check {
    UIViewController *src = _sourceController;
    if (!src) return;
    NSString *ident = _conn[@"identifier"];
    if (check && ident && ![src shouldPerformSegueWithIdentifier:ident sender:sender]) return;
    BOOL f = NO;
    if ([_conn[@"kind"] isEqualToString:@"unwind"] || [_loader isExit:_conn[@"destination"]]) {
        SEL action = NSSelectorFromString(_conn[@"unwindAction"] ?: @"");
        UIViewController *dst = unwind_destination(src, action, sender);
        if (!dst) { NSLog(@"isim: no view controller handles the unwind action %@ (from %@)", _conn[@"unwindAction"], src); return; }
        __IsimUnwindSegue *segue = [[__IsimUnwindSegue alloc] initWithIdentifier:ident source:src destination:dst];
        segue.conn = _conn;
        [src prepareForSegue:segue sender:sender];
        ((void (*)(id, SEL, id))objc_msgSend)(dst, action, segue);
        [segue perform];
        return;
    }
    (void)f;
    /* @IBSegueAction: the source creates the destination from the coder (destinationCreationSelector) */
    UIStoryboardViewControllerCreator creator = nil;
    NSString *csel = _conn[@"destinationCreationSelector"];
    if (csel.length) {
        SEL cs = NSSelectorFromString(csel);
        NSUInteger args = [csel componentsSeparatedByString:@":"].count - 1;
        if ([src respondsToSelector:cs]) {
            __weak UIViewController *wsrc = src;
            creator = ^UIViewController *(NSCoder *coder) {
                UIViewController *s0 = wsrc;
                NSLog(@"isim: segue action %@ creates the destination", csel);
                if (args >= 3) return ((id (*)(id, SEL, id, id, id))objc_msgSend)(s0, cs, coder, sender, ident);
                if (args == 2) return ((id (*)(id, SEL, id, id))objc_msgSend)(s0, cs, coder, sender);
                return ((id (*)(id, SEL, id))objc_msgSend)(s0, cs, coder);
            };
        } else NSLog(@"isim: %@ does not implement the segue action %@", NSStringFromClass([src class]), csel);
    }
    UIViewController *dst = [_storyboard _isim_instantiateScene:_conn[@"destination"] creator:creator];
    if (!dst) return;
    if ([_conn[@"kind"] isEqualToString:@"popoverPresentation"]) {
        /* the popover's anchor: the segue's anchor view or bar button item, else the control that triggered it */
        dst.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController *pp = dst.popoverPresentationController;
        BOOL found = NO;
        id anchor = _conn[@"popoverAnchorView"] ? [_loader objectForID:_conn[@"popoverAnchorView"] found:&found]
                  : _conn[@"popoverAnchorBarButtonItem"] ? [_loader objectForID:_conn[@"popoverAnchorBarButtonItem"] found:&found] : sender;
        if ([anchor isKindOfClass:[UIBarButtonItem class]]) pp.barButtonItem = anchor;
        else if ([anchor isKindOfClass:[UIView class]]) { pp.sourceView = anchor; pp.sourceRect = ((UIView *)anchor).bounds; }
        else if ([anchor isKindOfClass:[UIGestureRecognizer class]]) { UIView *v = ((UIGestureRecognizer *)anchor).view; pp.sourceView = v; pp.sourceRect = v.bounds; }
        if (_conn[@"popoverArrowDirection"]) pp.permittedArrowDirections = [_conn[@"popoverArrowDirection"] unsignedIntegerValue];
        if (_conn[@"popoverAnchorView"] || _conn[@"popoverAnchorBarButtonItem"])
            NSLog(@"isim: popover segue anchored to %@", [anchor respondsToSelector:@selector(accessibilityIdentifier)] && [anchor accessibilityIdentifier] ? [anchor accessibilityIdentifier] : NSStringFromClass([anchor class]));
    }
    if (_conn[@"modalPresentationStyle"]) dst.modalPresentationStyle = [_conn[@"modalPresentationStyle"] integerValue];
    if (_conn[@"modalTransitionStyle"]) [dst setValue:_conn[@"modalTransitionStyle"] forKey:@"modalTransitionStyle"];
    Class cls = [UIStoryboardSegue class];
    if (_conn[@"customClass"]) cls = ib_resolve_class(@{@"class": @"UIStoryboardSegue", @"customClass": _conn[@"customClass"],
                                                        @"customModule": _conn[@"customModule"] ?: @""});
    UIStoryboardSegue *segue = [[cls alloc] initWithIdentifier:ident source:src destination:dst];
    if (![_conn[@"kind"] isEqualToString:@"custom"]) segue.conn = _conn;
    [src prepareForSegue:segue sender:sender];
    [segue perform];
}
@end
@implementation __IsimSegueTrigger
- (void)fire:(id)sender { [_segue performWithSender:sender checkShould:YES]; }
@end

/* ================= UIViewController ================= */
@implementation UIViewController (UIStoryboardSupport)
- (UIStoryboard *)storyboard {
    UIStoryboard *s = objc_getAssociatedObject(self, &kStoryboardKey);
    return s ?: self.parentViewController.storyboard;
}
- (void)performSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    __IsimSegueTemplate *t = objc_getAssociatedObject(self, &kTemplatesKey)[identifier];
    if (!t) [NSException raise:NSInvalidArgumentException format:@"Receiver (%@) has no segue with identifier '%@'", self, identifier];
    t.sourceController = self;
    [t performWithSender:sender checkShould:NO];
}
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender { return YES; }
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {}
- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController *)from sender:(id)sender {
    return action && self != from && [self respondsToSelector:action];
}
- (NSArray<UIViewController *> *)allowedChildViewControllersForUnwindingFromSource:(UIStoryboardUnwindSegueSource *)source { return self.childViewControllers; }
- (void)unwindForSegue:(UIStoryboardSegue *)unwindSegue towardsViewController:(UIViewController *)subsequentVC {}
@end

/* hooks used by UIViewController (UIApplication.m) */
void isim_ib_vc_set_nib(UIViewController *vc, NSString *name, NSBundle *bundle) {
    objc_setAssociatedObject(vc, &kNibNameKey, name, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(vc, &kNibBundleKey, bundle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
NSString *isim_ib_vc_nib_name(UIViewController *vc) { return objc_getAssociatedObject(vc, &kNibNameKey); }
NSBundle *isim_ib_vc_nib_bundle(UIViewController *vc) { return objc_getAssociatedObject(vc, &kNibBundleKey); }

/* -loadView: a storyboard controller's view, or the controller's nib (explicit nibName, else one named after the class) */
BOOL isim_ib_vc_load_view(UIViewController *vc) {
    __IsimIBLoader *l = objc_getAssociatedObject(vc, &kLoaderKey);
    NSDictionary *viewNode = l.archive[@"root"][@"keyed"][@"view"];
    if (l && viewNode && l.sceneController == vc) {
        UIView *v = [l instantiate:viewNode];
        if (!v) return NO;
        vc.view = v;
        [l finish];
        return YES;
    }
    NSString *nibName = isim_ib_vc_nib_name(vc);
    NSBundle *bundle = isim_ib_vc_nib_bundle(vc) ?: NSBundle.mainBundle;
    if (!nibName) {
        NSString *cls = NSStringFromClass([vc class]);
        cls = [cls componentsSeparatedByString:@"."].lastObject;
        NSMutableArray *candidates = [NSMutableArray array];
        if ([cls hasSuffix:@"Controller"]) [candidates addObject:[cls substringToIndex:cls.length - 10]];
        [candidates addObject:cls];
        for (NSString *c in candidates) if (ib_find(bundle, c, @"nib", @"isim-nib.plist")) { nibName = c; break; }
        if (!nibName) return NO;
    }
    UINib *nib = [UINib nibWithNibName:nibName bundle:bundle];
    [nib instantiateWithOwner:vc options:nil];
    if (!vc.viewIfLoaded)
        [NSException raise:NSInternalInconsistencyException format:@"-[%@ _loadViewFromNibNamed:bundle:] loaded the \"%@\" nib but the view outlet was not set.", [vc class], nibName];
    return YES;
}

/* ================= main storyboard (UIMainStoryboardFile, UISceneStoryboardFile) ================= */
UIWindow *isim_ib_storyboard_window(UIStoryboard *storyboard, UIWindowScene *scene, id delegate) {
    static NSMutableArray *keep;                  /* UIKit keeps the storyboard's window alive */
    if (!storyboard) return nil;
    UIWindow *w = nil;
    if ([delegate respondsToSelector:@selector(window)]) w = [delegate window];   /* an app-provided window is used as is */
    if (!w) {
        w = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        if (!keep) keep = [NSMutableArray array];
        [keep addObject:w];
        if ([delegate respondsToSelector:@selector(setWindow:)]) [delegate setWindow:w];
    }
    UIViewController *root = [storyboard instantiateInitialViewController];
    if (!root) NSLog(@"isim: storyboard %@ has no initial view controller", storyboard.name);
    else NSLog(@"isim: main storyboard %@: initial view controller %@", storyboard.name, NSStringFromClass([root class]));
    w.rootViewController = root;
    return w;
}
