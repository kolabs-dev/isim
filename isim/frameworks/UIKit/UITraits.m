/* Trait collections (ARC): the iOS 17 trait system. A UITraitCollection is an immutable dictionary of the traits it
 * specifies, keyed by trait identifier (the system trait class names, an Objective-C custom trait class's
 * +identifier or class name, a Swift trait type's identifier). Views, view controllers, windows and window scenes
 * inherit their parent's traits and apply their overrides (overrideUserInterfaceStyle, traitOverrides); the result
 * is cached per view until a trait generation counter moves (an override, the hierarchy, the settings, rotation or a
 * scene size changed). Before each layout pass, isim_ui_traits_flush() walks the invalidated parts of the window
 * tree and calls traitCollectionDidChange: on views and view controllers whose traits changed.
 *
 * Dynamic colors resolve against the "current" traits: the collection set with UITraitCollection.current /
 * performAsCurrent, else the top of the render stack (UIKit pushes a view's traits while it lays out and draws a
 * view controller's view, a window or a view with overrides), else the screen's traits. */
#import "UIKitPrivate.h"
#include <objc/runtime.h>
#include <objc/message.h>
#include <math.h>

/* ================= keys and defaults ================= */
#define K_STYLE @"UITraitUserInterfaceStyle"
#define K_IDIOM @"UITraitUserInterfaceIdiom"
#define K_HSIZE @"UITraitHorizontalSizeClass"
#define K_VSIZE @"UITraitVerticalSizeClass"
#define K_SCALE @"UITraitDisplayScale"
#define K_DIR @"UITraitLayoutDirection"
#define K_FORCE @"UITraitForceTouchCapability"
#define K_CATEGORY @"UITraitPreferredContentSizeCategory"
#define K_GAMUT @"UITraitDisplayGamut"
#define K_CONTRAST @"UITraitAccessibilityContrast"
#define K_LEVEL @"UITraitUserInterfaceLevel"
#define K_LEGIBILITY @"UITraitLegibilityWeight"
#define K_ACTIVE @"UITraitActiveAppearance"
#define K_LIST @"UITraitListEnvironment"
#define K_TABACC @"UITraitTabAccessoryEnvironment"

static NSDictionary<NSString *, id> *builtin_defaults(void) {
    static NSDictionary *d;
    if (!d) d = @{ K_STYLE: @(UIUserInterfaceStyleUnspecified), K_IDIOM: @(UIUserInterfaceIdiomUnspecified), K_HSIZE: @(UIUserInterfaceSizeClassUnspecified),
                   K_VSIZE: @(UIUserInterfaceSizeClassUnspecified), K_SCALE: @0.0, K_DIR: @(UITraitEnvironmentLayoutDirectionUnspecified),
                   K_FORCE: @(UIForceTouchCapabilityUnknown), K_CATEGORY: @"_UICTContentSizeCategoryUnspecified", K_GAMUT: @(UIDisplayGamutUnspecified),
                   K_CONTRAST: @(UIAccessibilityContrastUnspecified), K_LEVEL: @(UIUserInterfaceLevelUnspecified),
                   K_LEGIBILITY: @(UILegibilityWeightUnspecified), K_ACTIVE: @(UIUserInterfaceActiveAppearanceUnspecified), K_LIST: @(UIListEnvironmentUnspecified),
                   K_TABACC: @(UITabAccessoryEnvironmentUnspecified) };
    return d;
}
/* traits whose change alters how dynamic colors resolve; Swift custom traits register here (affectsColorAppearance) */
static NSMutableSet<NSString *> *color_keys(void) {
    static NSMutableSet *s;
    if (!s) s = [NSMutableSet setWithArray:@[K_STYLE, K_CONTRAST, K_LEVEL, K_GAMUT, K_ACTIVE]];
    return s;
}
void isim_ui_trait_register_identifier(NSString *identifier, BOOL affectsColorAppearance) {
    if (affectsColorAppearance && identifier) [color_keys() addObject:identifier];
}

NSString *isim_ui_trait_key(id trait) {
    if (!trait) return nil;
    if ([trait isKindOfClass:[NSString class]]) return trait;          /* Swift trait identifiers pass through */
    if (!class_isMetaClass(object_getClass(trait))) return NSStringFromClass([trait class]);
    Class c = trait;
    if ([c respondsToSelector:@selector(identifier)]) {
        NSString *i = ((NSString *(*)(id, SEL))objc_msgSend)(c, @selector(identifier));
        if ([i isKindOfClass:[NSString class]] && i.length) {
            if ([c respondsToSelector:@selector(affectsColorAppearance)] && ((BOOL (*)(id, SEL))objc_msgSend)(c, @selector(affectsColorAppearance))) [color_keys() addObject:i];
            return i;
        }
    }
    return NSStringFromClass(c);
}
/* the default value of an Objective-C custom trait class */
static id class_default(Class c) {
    if (![c respondsToSelector:@selector(defaultValue)]) return nil;
    Method m = class_getClassMethod(c, @selector(defaultValue));
    const char *t = m ? method_getTypeEncoding(m) : "@";
    if (*t == 'd' || *t == 'f') return @(((double (*)(id, SEL))objc_msgSend)(c, @selector(defaultValue)));
    if (*t == 'q' || *t == 'l' || *t == 'i' || *t == 'Q' || *t == 'L') return @(((long (*)(id, SEL))objc_msgSend)(c, @selector(defaultValue)));
    return ((id (*)(id, SEL))objc_msgSend)(c, @selector(defaultValue));
}

/* ================= trait classes ================= */
#define TRAIT_CLASS(cls, nm, color) \
@implementation cls \
+ (NSString *)identifier { return @#cls; } \
+ (NSString *)name { return nm; } \
+ (BOOL)affectsColorAppearance { return color; } \
@end
TRAIT_CLASS(UITraitUserInterfaceStyle, @"UserInterfaceStyle", YES)
TRAIT_CLASS(UITraitHorizontalSizeClass, @"HorizontalSizeClass", NO)
TRAIT_CLASS(UITraitVerticalSizeClass, @"VerticalSizeClass", NO)
TRAIT_CLASS(UITraitUserInterfaceIdiom, @"UserInterfaceIdiom", NO)
TRAIT_CLASS(UITraitDisplayScale, @"DisplayScale", NO)
TRAIT_CLASS(UITraitLayoutDirection, @"LayoutDirection", NO)
TRAIT_CLASS(UITraitForceTouchCapability, @"ForceTouchCapability", NO)
TRAIT_CLASS(UITraitPreferredContentSizeCategory, @"PreferredContentSizeCategory", NO)
TRAIT_CLASS(UITraitDisplayGamut, @"DisplayGamut", YES)
TRAIT_CLASS(UITraitAccessibilityContrast, @"AccessibilityContrast", YES)
TRAIT_CLASS(UITraitUserInterfaceLevel, @"UserInterfaceLevel", YES)
TRAIT_CLASS(UITraitLegibilityWeight, @"LegibilityWeight", NO)
TRAIT_CLASS(UITraitActiveAppearance, @"ActiveAppearance", YES)
TRAIT_CLASS(UITraitListEnvironment, @"ListEnvironment", NO)
TRAIT_CLASS(UITraitTabAccessoryEnvironment, @"TabAccessoryEnvironment", NO)

/* ================= mutable traits / trait overrides ================= */
@interface __IsimMutableTraits : NSObject <UITraitOverrides>
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *d;
@property (nonatomic, copy) void (^changed)(void);
@end
@implementation __IsimMutableTraits
- (instancetype)init { if ((self = [super init])) _d = [NSMutableDictionary dictionary]; return self; }
- (void)_set:(id)v key:(NSString *)k {
    id old = _d[k];
    if (v) _d[k] = v; else [_d removeObjectForKey:k];
    if (_changed && !((!old && !v) || [old isEqual:v])) _changed();
}
- (NSInteger)_int:(NSString *)k { id v = _d[k] ?: builtin_defaults()[k]; return [v integerValue]; }
- (void)setCGFloatValue:(CGFloat)value forTrait:(Class)trait { [self _set:@(value) key:isim_ui_trait_key(trait)]; }
- (void)setNSIntegerValue:(NSInteger)value forTrait:(Class)trait { [self _set:@(value) key:isim_ui_trait_key(trait)]; }
- (void)setObject:(id)object forTrait:(Class)trait { [self _set:object ?: [NSNull null] key:isim_ui_trait_key(trait)]; }
- (void)_isim_setObject:(id)object forTraitIdentifier:(NSString *)identifier { [self _set:object ?: [NSNull null] key:identifier]; }
- (id)_isim_objectForTraitIdentifier:(NSString *)identifier { id v = _d[identifier]; return v == [NSNull null] ? nil : v; }
- (BOOL)containsTrait:(Class)trait { return _d[isim_ui_trait_key(trait)] != nil; }
- (void)removeTrait:(Class)trait { [self _set:nil key:isim_ui_trait_key(trait)]; }
- (BOOL)_isim_containsTraitIdentifier:(NSString *)identifier { return _d[identifier] != nil; }
- (void)_isim_removeTraitIdentifier:(NSString *)identifier { [self _set:nil key:identifier]; }
#define MT_INT(getter, setter, TYPE, KEY) \
- (TYPE)getter { return (TYPE)[self _int:KEY]; } \
- (void)setter:(TYPE)v { [self _set:@(v) key:KEY]; }
MT_INT(userInterfaceIdiom, setUserInterfaceIdiom, UIUserInterfaceIdiom, K_IDIOM)
MT_INT(userInterfaceStyle, setUserInterfaceStyle, UIUserInterfaceStyle, K_STYLE)
MT_INT(layoutDirection, setLayoutDirection, UITraitEnvironmentLayoutDirection, K_DIR)
MT_INT(horizontalSizeClass, setHorizontalSizeClass, UIUserInterfaceSizeClass, K_HSIZE)
MT_INT(verticalSizeClass, setVerticalSizeClass, UIUserInterfaceSizeClass, K_VSIZE)
MT_INT(forceTouchCapability, setForceTouchCapability, UIForceTouchCapability, K_FORCE)
MT_INT(displayGamut, setDisplayGamut, UIDisplayGamut, K_GAMUT)
MT_INT(accessibilityContrast, setAccessibilityContrast, UIAccessibilityContrast, K_CONTRAST)
MT_INT(userInterfaceLevel, setUserInterfaceLevel, UIUserInterfaceLevel, K_LEVEL)
MT_INT(legibilityWeight, setLegibilityWeight, UILegibilityWeight, K_LEGIBILITY)
MT_INT(activeAppearance, setActiveAppearance, UIUserInterfaceActiveAppearance, K_ACTIVE)
- (CGFloat)displayScale { return [(_d[K_SCALE] ?: @0) doubleValue]; }
- (void)setDisplayScale:(CGFloat)s { [self _set:@(s) key:K_SCALE]; }
- (UIContentSizeCategory)preferredContentSizeCategory { return _d[K_CATEGORY] ?: UIContentSizeCategoryUnspecified; }
- (void)setPreferredContentSizeCategory:(UIContentSizeCategory)c { [self _set:[c copy] key:K_CATEGORY]; }
- (NSString *)description { return [NSString stringWithFormat:@"<UITraitOverrides %@>", _d]; }
@end
id<UITraitOverrides> isim_ui_new_trait_overrides(void (^changed)(void)) { __IsimMutableTraits *m = [__IsimMutableTraits new]; m.changed = changed; return m; }
BOOL isim_ui_trait_overrides_empty(id<UITraitOverrides> o) { return !o || !((__IsimMutableTraits *)o).d.count; }

/* ================= UITraitCollection ================= */
@interface UITraitCollection ()
- (instancetype)initWithIsimTraits:(NSDictionary *)d;
@end
@implementation UITraitCollection { NSDictionary<NSString *, id> *_t; NSUInteger _hash; }
- (instancetype)init { return [self initWithIsimTraits:@{}]; }
- (instancetype)initWithIsimTraits:(NSDictionary *)d {
    if ((self = [super init])) { _t = [d copy] ?: @{}; _hash = _t.count; for (NSString *k in _t) _hash ^= k.hash ^ [_t[k] hash]; }
    return self;
}
static UITraitCollection *with(NSString *k, id v) { return [[UITraitCollection alloc] initWithIsimTraits:@{ k: v }]; }
- (id)copyWithZone:(NSZone *)z { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_t forKey:@"traits"]; }
- (instancetype)initWithCoder:(NSCoder *)c { NSDictionary *d = [c decodeObjectForKey:@"traits"]; return [self initWithIsimTraits:[d isKindOfClass:[NSDictionary class]] ? d : @{}]; }
- (BOOL)isEqual:(id)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[UITraitCollection class]]) return NO;
    UITraitCollection *x = o;
    return _hash == x->_hash && [_t isEqualToDictionary:x->_t];
}
- (NSUInteger)hash { return _hash; }
- (NSDictionary *)_isim_traits { return _t; }
- (NSUInteger)_isim_traitCount { return _t.count; }
- (id)_isim_objectForTraitIdentifier:(NSString *)k { id v = _t[k]; return v == [NSNull null] ? nil : v; }
- (NSInteger)_int:(NSString *)k { id v = _t[k] ?: builtin_defaults()[k]; return [v integerValue]; }
- (UIUserInterfaceStyle)userInterfaceStyle { return (UIUserInterfaceStyle)[self _int:K_STYLE]; }
- (UIUserInterfaceIdiom)userInterfaceIdiom { return (UIUserInterfaceIdiom)[self _int:K_IDIOM]; }
- (UIUserInterfaceSizeClass)horizontalSizeClass { return (UIUserInterfaceSizeClass)[self _int:K_HSIZE]; }
- (UIUserInterfaceSizeClass)verticalSizeClass { return (UIUserInterfaceSizeClass)[self _int:K_VSIZE]; }
- (CGFloat)displayScale { return [(_t[K_SCALE] ?: @0) doubleValue]; }
- (UITraitEnvironmentLayoutDirection)layoutDirection { return (UITraitEnvironmentLayoutDirection)[self _int:K_DIR]; }
- (UIForceTouchCapability)forceTouchCapability { return (UIForceTouchCapability)[self _int:K_FORCE]; }
- (UIDisplayGamut)displayGamut { return (UIDisplayGamut)[self _int:K_GAMUT]; }
- (UIUserInterfaceLevel)userInterfaceLevel { return (UIUserInterfaceLevel)[self _int:K_LEVEL]; }
- (UIUserInterfaceActiveAppearance)activeAppearance { return (UIUserInterfaceActiveAppearance)[self _int:K_ACTIVE]; }
- (UIListEnvironment)listEnvironment { return (UIListEnvironment)[self _int:K_LIST]; }
- (UITabAccessoryEnvironment)tabAccessoryEnvironment { return (UITabAccessoryEnvironment)[self _int:K_TABACC]; }
- (UIContentSizeCategory)preferredContentSizeCategory { return _t[K_CATEGORY] ?: UIContentSizeCategoryUnspecified; }
- (UIAccessibilityContrast)accessibilityContrast { return (UIAccessibilityContrast)[self _int:K_CONTRAST]; }
- (UILegibilityWeight)legibilityWeight { return (UILegibilityWeight)[self _int:K_LEGIBILITY]; }

+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)s { return with(K_STYLE, @(s)); }
+ (UITraitCollection *)traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)i { return with(K_IDIOM, @(i)); }
+ (UITraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)c { return with(K_HSIZE, @(c)); }
+ (UITraitCollection *)traitCollectionWithVerticalSizeClass:(UIUserInterfaceSizeClass)c { return with(K_VSIZE, @(c)); }
+ (UITraitCollection *)traitCollectionWithDisplayScale:(CGFloat)s { return with(K_SCALE, @(s)); }
+ (UITraitCollection *)traitCollectionWithLayoutDirection:(UITraitEnvironmentLayoutDirection)d { return with(K_DIR, @(d)); }
+ (UITraitCollection *)traitCollectionWithDisplayGamut:(UIDisplayGamut)g { return with(K_GAMUT, @(g)); }
+ (UITraitCollection *)traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)c { return with(K_CONTRAST, @(c)); }
+ (UITraitCollection *)traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)l { return with(K_LEVEL, @(l)); }
+ (UITraitCollection *)traitCollectionWithLegibilityWeight:(UILegibilityWeight)w { return with(K_LEGIBILITY, @(w)); }
+ (UITraitCollection *)traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)a { return with(K_ACTIVE, @(a)); }
+ (UITraitCollection *)traitCollectionWithPreferredContentSizeCategory:(UIContentSizeCategory)c { return with(K_CATEGORY, [c copy] ?: UIContentSizeCategoryUnspecified); }
+ (UITraitCollection *)traitCollectionWithTraitsFromCollections:(NSArray<UITraitCollection *> *)cs {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (UITraitCollection *c in cs) if ([c isKindOfClass:[UITraitCollection class]]) [d addEntriesFromDictionary:c->_t];
    return [[UITraitCollection alloc] initWithIsimTraits:d];
}
+ (UITraitCollection *)traitCollectionWithTraits:(void (NS_NOESCAPE ^)(id<UIMutableTraits>))mutations {
    __IsimMutableTraits *m = [__IsimMutableTraits new];
    if (mutations) mutations(m);
    return [[UITraitCollection alloc] initWithIsimTraits:m.d];
}
- (UITraitCollection *)traitCollectionByModifyingTraits:(void (NS_NOESCAPE ^)(id<UIMutableTraits>))mutations {
    __IsimMutableTraits *m = [__IsimMutableTraits new];
    [m.d addEntriesFromDictionary:_t];
    if (mutations) mutations(m);
    return [[UITraitCollection alloc] initWithIsimTraits:m.d];
}
- (UITraitCollection *)_isim_byApplying:(NSDictionary *)overrides {
    if (!overrides.count) return self;
    NSMutableDictionary *d = [_t mutableCopy]; [d addEntriesFromDictionary:overrides];
    return [[UITraitCollection alloc] initWithIsimTraits:d];
}
- (BOOL)containsTraitsInCollection:(UITraitCollection *)o {
    if (!o) return YES;
    for (NSString *k in o->_t) if (![_t[k] isEqual:o->_t[k]]) return NO;
    return YES;
}
- (BOOL)hasDifferentColorAppearanceComparedToTraitCollection:(UITraitCollection *)o {
    for (NSString *k in color_keys()) {
        id a = _t[k] ?: builtin_defaults()[k], b = o ? (o->_t[k] ?: builtin_defaults()[k]) : builtin_defaults()[k];
        if (!((!a && !b) || [a isEqual:b])) return YES;
    }
    return NO;
}
- (NSSet<NSString *> *)_isim_changedTraitIdentifiersFrom:(UITraitCollection *)p {
    NSMutableSet *keys = [NSMutableSet setWithArray:_t.allKeys];
    if (p) [keys addObjectsFromArray:p->_t.allKeys];
    NSMutableSet *out = [NSMutableSet set];
    for (NSString *k in keys) { id a = _t[k], b = p ? p->_t[k] : nil; if (!((!a && !b) || [a isEqual:b])) [out addObject:k]; }
    return out;
}
- (CGFloat)valueForCGFloatTrait:(Class)trait { NSString *k = isim_ui_trait_key(trait); id v = _t[k] ?: builtin_defaults()[k] ?: class_default(trait); return [v doubleValue]; }
- (NSInteger)valueForNSIntegerTrait:(Class)trait { NSString *k = isim_ui_trait_key(trait); id v = _t[k] ?: builtin_defaults()[k] ?: class_default(trait); return [v integerValue]; }
- (id)objectForTrait:(Class)trait { NSString *k = isim_ui_trait_key(trait); id v = _t[k]; if (v == [NSNull null]) return nil; return v ?: class_default(trait); }
+ (NSString *)_isim_identifierForTrait:(Class)trait { return isim_ui_trait_key(trait); }
+ (void)_isim_registerTraitIdentifier:(NSString *)identifier affectsColorAppearance:(BOOL)a { isim_ui_trait_register_identifier(identifier, a); }
+ (NSArray<Class> *)systemTraitsAffectingColorAppearance {
    return @[[UITraitUserInterfaceStyle class], [UITraitAccessibilityContrast class], [UITraitUserInterfaceLevel class], [UITraitDisplayGamut class], [UITraitActiveAppearance class]];
}
+ (NSArray<Class> *)systemTraitsAffectingImageLookup {
    return @[[UITraitUserInterfaceStyle class], [UITraitAccessibilityContrast class], [UITraitDisplayScale class], [UITraitUserInterfaceIdiom class],
             [UITraitLayoutDirection class], [UITraitDisplayGamut class], [UITraitLegibilityWeight class], [UITraitHorizontalSizeClass class], [UITraitVerticalSizeClass class]];
}
- (NSString *)description {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *k in [_t.allKeys sortedArrayUsingSelector:@selector(compare:)])
        [parts addObject:[NSString stringWithFormat:@"%@ = %@", [k hasPrefix:@"UITrait"] ? [k substringFromIndex:7] : k, _t[k]]];
    return [NSString stringWithFormat:@"<UITraitCollection: %p; %@>", self, [parts componentsJoinedByString:@", "]];
}

/* ---- the current traits ---- */
static UITraitCollection *explicit_current;
+ (UITraitCollection *)currentTraitCollection { return isim_ui_current_traits(); }
+ (void)setCurrentTraitCollection:(UITraitCollection *)t { explicit_current = t; }
- (void)performAsCurrentTraitCollection:(void (NS_NOESCAPE ^)(void))actions {
    UITraitCollection *saved = explicit_current;
    explicit_current = self;
    @try { if (actions) actions(); } @finally { explicit_current = saved; }
}
@end

/* ================= screen / window traits, the render stack ================= */
extern UIUserInterfaceStyle isim_ui_base_style(void);
extern NSString *isim_ui_content_size_category(void);
static UITraitCollection *screen_traits;
static unsigned trait_gen = 1;
unsigned isim_ui_trait_generation(void) { return trait_gen; }

static UIUserInterfaceSizeClass hsize_for(CGSize s, BOOL pad, CGSize screen) {
    if (pad) return s.width >= 678 ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
    BOOL landscape = screen.width > screen.height;
    return landscape && MIN(screen.width, screen.height) >= 414 && s.width >= 0.9 * screen.width ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
}
UITraitCollection *isim_ui_screen_traits(void) {
    if (screen_traits) return screen_traits;
    const struct isim_device *d = isim_ui_device();
    BOOL pad = MIN(d->width, d->height) >= 700, landscape = d->width > d->height;
    CGSize screen = CGSizeMake(d->width, d->height);
    NSMutableDictionary *t = [NSMutableDictionary dictionary];
    t[K_STYLE] = @(isim_ui_base_style());
    t[K_IDIOM] = @(pad ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone);
    t[K_HSIZE] = @(hsize_for(screen, pad, screen));
    t[K_VSIZE] = @(pad || !landscape ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact);
    t[K_SCALE] = @(d->scale);
    t[K_DIR] = @(isim_ui_app_layout_direction() == UIUserInterfaceLayoutDirectionRightToLeft ? UITraitEnvironmentLayoutDirectionRightToLeft : UITraitEnvironmentLayoutDirectionLeftToRight);
    t[K_FORCE] = @(UIForceTouchCapabilityUnavailable);
    t[K_CATEGORY] = isim_ui_content_size_category() ?: UIContentSizeCategoryLarge;
    t[K_GAMUT] = @(UIDisplayGamutP3);
    t[K_CONTRAST] = @(UIAccessibilityIsDarkerSystemColorsEnabled() ? UIAccessibilityContrastHigh : UIAccessibilityContrastNormal);
    t[K_LEVEL] = @(UIUserInterfaceLevelBase);
    t[K_LEGIBILITY] = @(UIAccessibilityIsBoldTextEnabled() ? UILegibilityWeightBold : UILegibilityWeightRegular);
    t[K_ACTIVE] = @(UIUserInterfaceActiveAppearanceActive);
    screen_traits = [[UITraitCollection alloc] initWithIsimTraits:t];
    return screen_traits;
}
/* traits of a window (or window scene) of the given size: size classes follow its width (iPad split view) */
UITraitCollection *isim_ui_traits_for_size(CGSize size) {
    UITraitCollection *s = isim_ui_screen_traits();
    if (size.width <= 0 || size.height <= 0) return s;
    const struct isim_device *d = isim_ui_device();
    BOOL pad = MIN(d->width, d->height) >= 700;
    UIUserInterfaceSizeClass h = hsize_for(size, pad, CGSizeMake(d->width, d->height));
    if (h == s.horizontalSizeClass) return s;
    return [s _isim_byApplying:@{ K_HSIZE: @(h) }];
}
UITraitCollection *isim_ui_apply_overrides(UITraitCollection *base, id<UITraitOverrides> o, UIUserInterfaceStyle style) {
    NSMutableDictionary *d = nil;
    if (style != UIUserInterfaceStyleUnspecified) d = [@{ K_STYLE: @(style) } mutableCopy];
    if (!isim_ui_trait_overrides_empty(o)) { if (!d) d = [NSMutableDictionary dictionary]; [d addEntriesFromDictionary:((__IsimMutableTraits *)o).d]; }
    return d ? [base _isim_byApplying:d] : base;
}

/* the render/layout stack */
static __strong UITraitCollection *trait_stack[64];
static int trait_depth = -1;
void isim_ui_push_traits(UITraitCollection *t) { if (trait_depth < 63) trait_stack[++trait_depth] = t ?: isim_ui_current_traits(); }
void isim_ui_pop_traits(void) { if (trait_depth >= 0) trait_stack[trait_depth--] = nil; }
UITraitCollection *isim_ui_current_traits(void) {
    if (explicit_current) return explicit_current;
    if (trait_depth >= 0) return trait_stack[trait_depth];
    return isim_ui_screen_traits();
}
/* the style dynamic colors resolve with (never unspecified) */
UIUserInterfaceStyle isim_ui_style(void) {
    UIUserInterfaceStyle s = isim_ui_current_traits().userInterfaceStyle;
    return s != UIUserInterfaceStyleUnspecified ? s : isim_ui_base_style();
}
void isim_ui_push_style(UIUserInterfaceStyle s) {
    UITraitCollection *cur = isim_ui_current_traits();
    if (s == UIUserInterfaceStyleUnspecified || cur.userInterfaceStyle == s) { isim_ui_push_traits(cur); return; }
    isim_ui_push_traits([cur _isim_byApplying:@{ K_STYLE: @(s) }]);
}
void isim_ui_pop_style(void) { isim_ui_pop_traits(); }

/* ================= invalidation and the change pass ================= */
static NSHashTable<UIView *> *dirty_roots;
static BOOL dirty_all;
void isim_ui_traits_invalidate(UIView *root) {
    trait_gen++;
    if (!root) { dirty_all = YES; screen_traits = nil; }
    else { if (!dirty_roots) dirty_roots = [NSHashTable weakObjectsHashTable]; [dirty_roots addObject:root]; }
    isim_ui_set_needs_layout();
}
/* the change pass: views (and their controllers) whose traits differ from the ones they last saw get
   traitCollectionDidChange: (UIView.m walks the tree) */
@interface UIView (IsimTraitsWalk)
- (void)_isim_traitsWalk;
@end
void isim_ui_traits_flush(void) {
    if (!dirty_all && !dirty_roots.count) return;
    NSArray *roots;
    if (dirty_all) roots = UIApplication.sharedApplication.windows;
    else {
        NSMutableArray *r = [NSMutableArray array];
        for (UIView *v in dirty_roots) {
            BOOL covered = NO;
            for (UIView *o in dirty_roots) if (o != v && [v isDescendantOfView:o]) { covered = YES; break; }
            if (!covered) [r addObject:v];
        }
        roots = r;
    }
    dirty_all = NO; [dirty_roots removeAllObjects];
    for (UIView *v in roots) [v _isim_traitsWalk];
    extern void isim_ui_trait_registrations_tick(void);
    isim_ui_trait_registrations_tick();               /* registerForTraitChanges handlers */
}
