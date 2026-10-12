// isim CoreText: CTFont / CTFontDescriptor objects resolved through the host's fontconfig, metrics, glyphs and
// outlines read from the font file (HarfBuzz), font features, font registration. CT objects are Objective-C objects
// (as on Apple platforms, CF types are); a UIFont works as a CTFont (toll-free bridged on iOS). Layout: CTLayout.m.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <CoreText/CoreText.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#include <math.h>
#import "CTPrivate.h"

const CFStringRef kCTFontNameAttribute = CFSTR("NSFontNameAttribute");
const CFStringRef kCTFontDisplayNameAttribute = CFSTR("NSFontVisibleNameAttribute");
const CFStringRef kCTFontFamilyNameAttribute = CFSTR("NSFontFamilyAttribute");
const CFStringRef kCTFontStyleNameAttribute = CFSTR("NSFontFaceAttribute");
const CFStringRef kCTFontSizeAttribute = CFSTR("NSFontSizeAttribute");
const CFStringRef kCTFontTraitsAttribute = CFSTR("NSCTFontTraitsAttribute");
const CFStringRef kCTFontURLAttribute = CFSTR("NSCTFontFileURLAttribute");
const CFStringRef kCTFontSymbolicTrait = CFSTR("NSCTFontSymbolicTrait");
const CFStringRef kCTFontWeightTrait = CFSTR("NSCTFontWeightTrait");
const CFStringRef kCTFontWidthTrait = CFSTR("NSCTFontProportionTrait");
const CFStringRef kCTFontSlantTrait = CFSTR("NSCTFontSlantTrait");
const CFStringRef kCTFontFeatureSettingsAttribute = CFSTR("NSCTFontFeatureSettingsAttribute");
const CFStringRef kCTFontFeaturesAttribute = CFSTR("NSCTFontFeaturesAttribute");
const CFStringRef kCTFontFeatureTypeIdentifierKey = CFSTR("CTFeatureTypeIdentifier");
const CFStringRef kCTFontFeatureTypeNameKey = CFSTR("CTFeatureTypeName");
const CFStringRef kCTFontFeatureTypeExclusiveKey = CFSTR("CTFeatureTypeExclusive");
const CFStringRef kCTFontFeatureTypeSelectorsKey = CFSTR("CTFeatureTypeSelectors");
const CFStringRef kCTFontFeatureSelectorIdentifierKey = CFSTR("CTFeatureSelectorIdentifier");
const CFStringRef kCTFontFeatureSelectorNameKey = CFSTR("CTFeatureSelectorName");
const CFStringRef kCTFontFeatureSelectorDefaultKey = CFSTR("CTFeatureSelectorDefault");
const CFStringRef kCTFontFeatureSelectorSettingKey = CFSTR("CTFeatureSelectorSetting");
const CFStringRef kCTFontOpenTypeFeatureTag = CFSTR("CTFeatureOpenTypeTag");
const CFStringRef kCTFontOpenTypeFeatureValue = CFSTR("CTFeatureOpenTypeValue");
const CFStringRef kCTFontCopyrightNameKey = CFSTR("CTFontCopyrightName");
const CFStringRef kCTFontFamilyNameKey = CFSTR("CTFontFamilyName");
const CFStringRef kCTFontSubFamilyNameKey = CFSTR("CTFontSubFamilyName");
const CFStringRef kCTFontStyleNameKey = CFSTR("CTFontStyleName");
const CFStringRef kCTFontUniqueNameKey = CFSTR("CTFontUniqueName");
const CFStringRef kCTFontFullNameKey = CFSTR("CTFontFullName");
const CFStringRef kCTFontVersionNameKey = CFSTR("CTFontVersionName");
const CFStringRef kCTFontPostScriptNameKey = CFSTR("CTFontPostScriptName");
#define K(x) ((__bridge NSString *)(x))

@implementation __NSCTFont { void *_host; BOOL _loaded; struct isim_ct_font_info _info; }
- (instancetype)init { if ((self = [super init])) _stretch = 4; return self; }
- (void)dealloc { isim_ct_font_free(_host); }
- (NSString *)description { return [NSString stringWithFormat:@"<CTFont %p> %@ (%@) %gpt%@%@", self, _name, _family ?: @"system", _size, _bold ? @" bold" : @"", _italic ? @" italic" : @""]; }
- (CGFloat)pointSize { return _size; }
- (NSString *)fontName { return _name; }
- (void *)host {
    if (!_loaded) {
        _loaded = YES;
        _host = isim_ct_font_load(isim_ct_family(self).UTF8String, isim_ct_pango_weight(_bold && _weight < 0.3 ? 0.4 : _weight), _italic, _stretch, _size);
        isim_ct_font_info(_host, &_info);
    }
    return _host;
}
- (const struct isim_ct_font_info *)info { [self host]; return &_info; }
@end
@implementation __NSCTFontDescriptor
- (NSString *)description { return [NSString stringWithFormat:@"<CTFontDescriptor %p> %@", self, _attributes]; }
@end

/* Coverage of one family, cached per code point. */
@interface __NSCTFontCharacterSet : NSCharacterSet
@property (copy) NSString *family;
@end
@implementation __NSCTFontCharacterSet { NSMutableDictionary<NSNumber *, NSNumber *> *_cache; }
- (BOOL)longCharacterIsMember:(UTF32Char)c {
    if (!_family) return NO;
    if (!_cache) _cache = [NSMutableDictionary dictionary];
    NSNumber *k = @(c), *v = _cache[k];
    if (!v) { v = @(isim_font_has_char(_family.UTF8String, c) != 0); _cache[k] = v; }
    return v.boolValue;
}
- (BOOL)characterIsMember:(unichar)c { return [self longCharacterIsMember:c]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@interface NSObject (IsimCTFontDuck)
- (NSString *)_isim_family; - (CGFloat)_isim_weight; - (BOOL)_isim_mono; - (BOOL)_isim_italic; - (CGFloat)pointSize; - (NSString *)fontName;
@end
__NSCTFont *isim_ct_font(id f) {
    if (!f || [f isKindOfClass:[__NSCTFont class]]) return f;
    if (![f respondsToSelector:@selector(pointSize)]) return nil;
    static char key;
    __NSCTFont *c = objc_getAssociatedObject(f, &key);
    if (c) return c;
    c = [__NSCTFont new];                       /* a UIFont: the same family, weight and slant */
    c.size = [f pointSize];
    if ([f respondsToSelector:@selector(_isim_weight)]) c.weight = [f _isim_weight];
    if ([f respondsToSelector:@selector(_isim_family)]) c.family = [f _isim_family];
    if ([f respondsToSelector:@selector(_isim_mono)]) c.mono = [f _isim_mono];
    if ([f respondsToSelector:@selector(_isim_italic)]) c.italic = [f _isim_italic];
    c.name = [f respondsToSelector:@selector(fontName)] ? [f fontName] : @".SFUI-Regular";
    c.bold = c.weight >= 0.3;
    objc_setAssociatedObject(f, &key, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}
static __NSCTFont *F(CTFontRef f) { return isim_ct_font((__bridge id)f); }
NSString *isim_ct_family(__NSCTFont *f) { return f.family.length ? f.family : f.mono ? @"monospace" : nil; }
int isim_ct_pango_weight(CGFloat w) {
    return w < -0.6 ? 100 : w < -0.3 ? 200 : w < -0.1 ? 300 : w < 0.1 ? 400 : w < 0.26 ? 500 : w < 0.35 ? 600 : w < 0.5 ? 700 : w < 0.6 ? 800 : 900;
}
/* Pango / OpenType weight -> UIFont weight (-1...1) */
static CGFloat uiweight(int w) {
    return w <= 100 ? -0.8 : w <= 200 ? -0.6 : w <= 300 ? -0.4 : w <= 400 ? 0 : w <= 500 ? 0.23 : w <= 600 ? 0.3 : w <= 700 ? 0.4 : w <= 800 ? 0.56 : 0.62;
}
/* kCTFontWidthTrait (-1 condensed ... 1 expanded) <-> Pango stretch */
static int stretch_of_width(double w) {
    return w <= -0.7 ? 0 : w <= -0.5 ? 1 : w <= -0.2 ? 2 : w < -0.05 ? 3 : w <= 0.05 ? 4 : w < 0.2 ? 5 : w < 0.5 ? 6 : w < 0.7 ? 7 : 8;
}
static double width_of_stretch(int s) { static const double w[] = { -0.8, -0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6, 0.8 }; return w[s < 0 ? 0 : s > 8 ? 8 : s]; }
__NSCTFont *isim_ct_font_from_host(const char *family, int pw, int italic, int stretch, double size) {
    __NSCTFont *f = [__NSCTFont new];
    f.family = family && family[0] ? [NSString stringWithUTF8String:family] : nil;
    f.weight = uiweight(pw); f.bold = f.weight >= 0.3; f.italic = italic; f.stretch = stretch; f.size = size;
    const char *ps = f.info->psname;
    f.name = ps[0] ? [NSString stringWithUTF8String:ps] : f.family;
    return f;
}

CFTypeID CTFontGetTypeID(void) { return 0x4354; }
CFTypeID CTFontDescriptorGetTypeID(void) { return 0x4355; }

/* UIFont weights (-1...1) for CSS-like weight words in a font name */
static CGFloat weight_from_name(NSString *n) {
    NSString *l = n.lowercaseString;
    return [l containsString:@"black"] || [l containsString:@"heavy"] ? 0.56 : [l containsString:@"semibold"] || [l containsString:@"demibold"] ? 0.3
         : [l containsString:@"bold"] ? 0.4 : [l containsString:@"medium"] ? 0.23 : [l containsString:@"ultralight"] ? -0.8
         : [l containsString:@"thin"] ? -0.6 : [l containsString:@"light"] ? -0.4 : 0;
}
static int stretch_from_name(NSString *n) {
    NSString *l = n.lowercaseString;
    return [l containsString:@"ultracondensed"] || [l containsString:@"extracondensed"] ? 1 : [l containsString:@"semicondensed"] ? 3
         : [l containsString:@"condensed"] || [l containsString:@"narrow"] || [l containsString:@"compressed"] ? 2
         : [l containsString:@"semiexpanded"] ? 5 : [l containsString:@"expanded"] || [l containsString:@"wide"] ? 6 : 4;
}
static __NSCTFont *font_named(NSString *name, CGFloat size) {
    __NSCTFont *f = [__NSCTFont new];
    f.size = size > 0 ? size : 12;
    char fam[256]; double w = 0; int italic = 0;
    if (name.length && isim_font_lookup(name.UTF8String, fam, sizeof fam, &w, &italic)) {
        f.name = name; f.family = [NSString stringWithUTF8String:fam]; f.weight = w; f.italic = italic;
        f.stretch = stretch_from_name(name);
    } else if (name.length && ![name hasPrefix:@"."]) {
        /* an iOS font that is not on the host: the system font with the name's weight and slant */
        NSString *l = name.lowercaseString;
        f.name = name; f.weight = weight_from_name(name);
        f.italic = [l containsString:@"italic"] || [l containsString:@"oblique"];
        f.mono = [l hasPrefix:@"menlo"] || [l hasPrefix:@"courier"] || [l hasPrefix:@"sfmono"];
        f.stretch = stretch_from_name(name);
    } else {
        f.name = @".SFUI-Regular";          /* like iOS: an unknown name gives the system font */
        if (name.length) { f.weight = weight_from_name(name); f.italic = [name.lowercaseString containsString:@"italic"]; }
    }
    f.bold = f.weight >= 0.3;
    return f;
}
CTFontRef CTFontCreateWithName(CFStringRef cfname, CGFloat size, const CGAffineTransform *matrix) {
    return (CTFontRef)CFBridgingRetain(font_named((__bridge NSString *)cfname, size));
}
static __NSCTFont *copy_font(__NSCTFont *o, CGFloat size) {
    __NSCTFont *f = [__NSCTFont new];
    f.name = o.name; f.family = o.family; f.weight = o.weight; f.size = size > 0 ? size : o.size;
    f.italic = o.italic; f.bold = o.bold; f.mono = o.mono; f.features = o.features; f.stretch = o.stretch;
    return f;
}
static void apply_traits(__NSCTFont *f, uint32_t value, uint32_t mask) {
    if (mask & kCTFontTraitBold) { f.bold = (value & kCTFontTraitBold) != 0; f.weight = f.bold ? fmax(f.weight, 0.4) : (f.weight >= 0.3 ? 0 : f.weight); }
    if (mask & kCTFontTraitItalic) f.italic = (value & kCTFontTraitItalic) != 0;
    if (mask & kCTFontTraitMonoSpace) f.mono = (value & kCTFontTraitMonoSpace) != 0;
    if (mask & (kCTFontTraitCondensed | kCTFontTraitExpanded))
        f.stretch = value & kCTFontTraitCondensed & mask ? 2 : value & kCTFontTraitExpanded & mask ? 6 : 4;
}

/* ---- features: AAT type/selector pairs and the OpenType features they stand for ---- */
typedef struct { int type, sel; const char *ot, *typeName, *selName; BOOL exclusive, dflt; } feature_map;
static const feature_map FEATURES[] = {
    { 1, 0, "rlig 1", "Ligatures", "Required Ligatures", NO, YES }, { 1, 1, "rlig 0", "Ligatures", "Required Ligatures Off", NO, NO },
    { 1, 2, "liga 1", "Ligatures", "Common Ligatures", NO, YES }, { 1, 3, "liga 0", "Ligatures", "Common Ligatures Off", NO, NO },
    { 1, 4, "dlig 1", "Ligatures", "Rare Ligatures", NO, NO }, { 1, 5, "dlig 0", "Ligatures", "Rare Ligatures Off", NO, YES },
    { 1, 18, "clig 1", "Ligatures", "Contextual Ligatures", NO, YES }, { 1, 19, "clig 0", "Ligatures", "Contextual Ligatures Off", NO, NO },
    { 1, 20, "hlig 1", "Ligatures", "Historical Ligatures", NO, NO }, { 1, 21, "hlig 0", "Ligatures", "Historical Ligatures Off", NO, YES },
    { 6, 0, "tnum 1, pnum 0", "Number Spacing", "Monospaced Numbers", YES, NO }, { 6, 1, "pnum 1, tnum 0", "Number Spacing", "Proportional Numbers", YES, NO },
    { 6, 2, "twid 1", "Number Spacing", "Third-Width Numbers", YES, NO }, { 6, 3, "qwid 1", "Number Spacing", "Quarter-Width Numbers", YES, NO },
    { 10, 0, "sups 0, subs 0, ordn 0, sinf 0", "Vertical Position", "Normal Position", YES, YES }, { 10, 1, "sups 1", "Vertical Position", "Superiors", YES, NO },
    { 10, 2, "subs 1", "Vertical Position", "Inferiors", YES, NO }, { 10, 3, "ordn 1", "Vertical Position", "Ordinals", YES, NO },
    { 10, 4, "sinf 1", "Vertical Position", "Scientific Inferiors", YES, NO },
    { 11, 0, "frac 0, afrc 0", "Fractions", "No Fractions", YES, YES }, { 11, 1, "afrc 1", "Fractions", "Vertical Fractions", YES, NO },
    { 11, 2, "frac 1", "Fractions", "Diagonal Fractions", YES, NO },
    { 14, 4, "zero 1", "Typographic Extras", "Slashed Zero", NO, NO }, { 14, 5, "zero 0", "Typographic Extras", "Slashed Zero Off", NO, YES },
    { 21, 0, "onum 1, lnum 0", "Number Case", "Lower Case Numbers", YES, NO }, { 21, 1, "lnum 1, onum 0", "Number Case", "Upper Case Numbers", YES, NO },
    { 22, 0, "pwid 1", "Text Spacing", "Proportional", YES, NO }, { 22, 1, "fwid 1", "Text Spacing", "Monospaced", YES, NO },
    { 22, 2, "hwid 1", "Text Spacing", "Half-width", YES, NO },
    { 33, 0, "case 1", "Case-Sensitive Layout", "Case-Sensitive Layout", NO, NO }, { 33, 1, "case 0", "Case-Sensitive Layout", "Case-Sensitive Layout Off", NO, YES },
    { 36, 0, "calt 1", "Contextual Alternates", "Contextual Alternates", NO, YES }, { 36, 1, "calt 0", "Contextual Alternates", "Contextual Alternates Off", NO, NO },
    { 36, 2, "swsh 1", "Contextual Alternates", "Swash Alternates", NO, NO }, { 36, 3, "swsh 0", "Contextual Alternates", "Swash Alternates Off", NO, YES },
    { 36, 4, "cswh 1", "Contextual Alternates", "Contextual Swash Alternates", NO, NO }, { 36, 5, "cswh 0", "Contextual Alternates", "Contextual Swash Alternates Off", NO, YES },
    { 37, 0, "smcp 0, pcap 0", "Lower Case", "Default Lower Case", YES, YES }, { 37, 1, "smcp 1", "Lower Case", "Small Capitals", YES, NO },
    { 37, 2, "pcap 1", "Lower Case", "Petite Capitals", YES, NO },
    { 38, 0, "c2sc 0, c2pc 0", "Upper Case", "Default Upper Case", YES, YES }, { 38, 1, "c2sc 1", "Upper Case", "Small Capitals", YES, NO },
    { 38, 2, "c2pc 1", "Upper Case", "Petite Capitals", YES, NO },
};
#define NFEATURES (sizeof FEATURES / sizeof *FEATURES)
static BOOL type_exclusive(int type) {
    for (size_t i = 0; i < NFEATURES; i++) if (FEATURES[i].type == type) return FEATURES[i].exclusive;
    return type != 35;                        /* stylistic sets come in on/off pairs */
}
/* the OpenType settings of one feature setting ("tnum 1, pnum 0"); nil when it has no OpenType equivalent */
static NSString *feature_ot(NSDictionary *f) {
    if (![f isKindOfClass:[NSDictionary class]]) return nil;
    id tag = f[K(kCTFontOpenTypeFeatureTag)];
    if ([tag isKindOfClass:[NSString class]] && [tag length] == 4) {
        id v = f[K(kCTFontOpenTypeFeatureValue)];
        return [NSString stringWithFormat:@"%@ %d", tag, v ? [v intValue] : 1];
    }
    int type = [f[K(kCTFontFeatureTypeIdentifierKey)] intValue], sel = [f[K(kCTFontFeatureSelectorIdentifierKey)] intValue];
    if (type == 35 && sel >= 2 && sel <= 41) return [NSString stringWithFormat:@"ss%02d %d", sel / 2, sel % 2 ? 0 : 1];
    for (size_t i = 0; i < NFEATURES; i++) if (FEATURES[i].type == type && FEATURES[i].sel == sel) return @(FEATURES[i].ot);
    return nil;
}
NSString *isim_ct_feature_tags(NSArray *features) {
    NSMutableArray *tags = [NSMutableArray array];
    for (NSDictionary *f in features) { NSString *t = feature_ot(f); if (t) [tags addObject:t]; }
    return [tags componentsJoinedByString:@", "];
}
/* adds a setting; one of an exclusive type (or the same on/off pair) replaces the earlier one */
static NSArray *add_feature(NSArray *list, NSDictionary *f) {
    NSMutableArray *m = [NSMutableArray array];
    id tag = f[K(kCTFontOpenTypeFeatureTag)];
    int type = [f[K(kCTFontFeatureTypeIdentifierKey)] intValue], sel = [f[K(kCTFontFeatureSelectorIdentifierKey)] intValue];
    for (NSDictionary *o in list) {
        if (tag) { if ([o[K(kCTFontOpenTypeFeatureTag)] isEqual:tag]) continue; }
        else if (o[K(kCTFontFeatureTypeIdentifierKey)] && [o[K(kCTFontFeatureTypeIdentifierKey)] intValue] == type &&
                 (type_exclusive(type) || ([o[K(kCTFontFeatureSelectorIdentifierKey)] intValue] | 1) == (sel | 1))) continue;
        [m addObject:o];
    }
    [m addObject:f];
    return m;
}

static void apply_attributes(__NSCTFont *f, NSDictionary *a) {
    NSString *family = a[K(kCTFontFamilyNameAttribute)];
    if (family.length) {
        char fam[256]; double w = 0; int it = 0;
        if (isim_font_lookup(family.UTF8String, fam, sizeof fam, &w, &it)) f.family = [NSString stringWithUTF8String:fam];
        else f.family = nil;
        if (!a[K(kCTFontNameAttribute)]) f.name = family;
    }
    NSString *style = a[K(kCTFontStyleNameAttribute)];
    if (style.length) {
        NSString *l = style.lowercaseString;
        f.weight = weight_from_name(style); f.bold = f.weight >= 0.3;
        f.italic = [l containsString:@"italic"] || [l containsString:@"oblique"];
        f.stretch = stretch_from_name(style);
    }
    NSDictionary *traits = a[K(kCTFontTraitsAttribute)];
    if (traits[K(kCTFontWeightTrait)]) { f.weight = [traits[K(kCTFontWeightTrait)] doubleValue]; f.bold = f.weight >= 0.3; }
    if (traits[K(kCTFontWidthTrait)]) f.stretch = stretch_of_width([traits[K(kCTFontWidthTrait)] doubleValue]);
    if (traits[K(kCTFontSlantTrait)]) f.italic = [traits[K(kCTFontSlantTrait)] doubleValue] > 0.01;
    if (traits[K(kCTFontSymbolicTrait)]) {
        uint32_t t = [traits[K(kCTFontSymbolicTrait)] unsignedIntValue];
        /* a weight trait given with the bold trait wins over it */
        apply_traits(f, t, (traits[K(kCTFontWeightTrait)] ? 0 : kCTFontTraitBold) | kCTFontTraitItalic | kCTFontTraitMonoSpace |
                           (traits[K(kCTFontWidthTrait)] ? 0 : kCTFontTraitCondensed | kCTFontTraitExpanded));
    }
    NSArray *features = a[K(kCTFontFeatureSettingsAttribute)];
    if ([features isKindOfClass:[NSArray class]]) for (NSDictionary *x in features) f.features = add_feature(f.features ?: @[], x);
}
CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef d, CGFloat size, const CGAffineTransform *matrix) {
    NSDictionary *a = ((__bridge __NSCTFontDescriptor *)d).attributes;
    NSString *name = a[K(kCTFontNameAttribute)] ?: a[K(kCTFontFamilyNameAttribute)];
    CGFloat s = size > 0 ? size : [a[K(kCTFontSizeAttribute)] doubleValue];
    __NSCTFont *f = font_named(name, s);
    apply_attributes(f, a);
    return (CTFontRef)CFBridgingRetain(f);
}
CTFontRef CTFontCreateUIFontForLanguage(CTFontUIFontType t, CGFloat size, CFStringRef lang) {
    __NSCTFont *f = font_named(nil, size > 0 ? size : t == kCTFontUIFontSmallSystem || t == kCTFontUIFontSmallEmphasizedSystem ? 11 : 13);
    if (t == kCTFontUIFontEmphasizedSystem || t == kCTFontUIFontSmallEmphasizedSystem || t == kCTFontUIFontMiniEmphasizedSystem) { f.weight = 0.4; f.bold = YES; }
    if (t == kCTFontUIFontUserFixedPitch) f.mono = YES;
    return (CTFontRef)CFBridgingRetain(f);
}
CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, CTFontDescriptorRef attrs) {
    __NSCTFont *f = copy_font(F(font), size);
    if (attrs) apply_attributes(f, ((__bridge __NSCTFontDescriptor *)attrs).attributes);
    return (CTFontRef)CFBridgingRetain(f);
}
CTFontRef CTFontCreateCopyWithSymbolicTraits(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, CTFontSymbolicTraits v, CTFontSymbolicTraits m) {
    __NSCTFont *f = copy_font(F(font), size);
    apply_traits(f, v, m);
    return (CTFontRef)CFBridgingRetain(f);
}
CTFontSymbolicTraits CTFontGetSymbolicTraits(CTFontRef font) {
    __NSCTFont *f = F(font);
    const struct isim_ct_font_info *i = f.info;
    return (f.bold ? kCTFontTraitBold : 0) | (f.italic ? kCTFontTraitItalic : 0) | (f.mono || i->mono ? kCTFontTraitMonoSpace : 0) |
           (f.stretch < 4 ? kCTFontTraitCondensed : 0) | (f.stretch > 4 ? kCTFontTraitExpanded : 0) | (i->color ? kCTFontTraitColorGlyphs : 0) |
           (f.family ? 0 : kCTFontTraitUIOptimized);
}
CFDictionaryRef CTFontCopyTraits(CTFontRef font) {
    __NSCTFont *f = F(font);
    double angle = f.info->slant_angle, slant = angle ? -angle / 30 : f.italic ? 0.07 : 0;
    NSDictionary *d = @{ K(kCTFontSymbolicTrait): @(CTFontGetSymbolicTraits(font)), K(kCTFontWeightTrait): @(f.bold && f.weight < 0.3 ? 0.4 : f.weight),
                         K(kCTFontSlantTrait): @(slant), K(kCTFontWidthTrait): @(width_of_stretch(f.stretch)) };
    return (CFDictionaryRef)CFBridgingRetain(d);
}
/* the style name: the face's own, or one made of the weight and slant when they are synthesized (or the system font) */
static NSString *style_name(__NSCTFont *f) {
    const struct isim_ct_font_info *i = f.info;
    if (f.family && i->style[0] && !i->synthetic) return [NSString stringWithUTF8String:i->style];
    CGFloat w = f.bold && f.weight < 0.3 ? 0.4 : f.weight;
    NSString *ws = w < -0.7 ? @"Ultralight" : w < -0.5 ? @"Thin" : w < -0.1 ? @"Light" : w < 0.1 ? @"Regular" : w < 0.26 ? @"Medium"
                 : w < 0.35 ? @"Semibold" : w < 0.5 ? @"Bold" : w < 0.6 ? @"Heavy" : @"Black";
    if (!f.italic) return ws;
    return [ws isEqualToString:@"Regular"] ? @"Italic" : [ws stringByAppendingString:@" Italic"];
}
static NSDictionary *font_attributes(__NSCTFont *f) {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    a[K(kCTFontNameAttribute)] = f.name ?: @".SFUI-Regular";
    a[K(kCTFontFamilyNameAttribute)] = f.family ?: @".SF UI Text";
    a[K(kCTFontStyleNameAttribute)] = style_name(f);
    a[K(kCTFontSizeAttribute)] = @(f.size);
    a[K(kCTFontTraitsAttribute)] = CFBridgingRelease(CTFontCopyTraits((__bridge CTFontRef)f));
    if (f.info->file[0]) a[K(kCTFontURLAttribute)] = [NSURL fileURLWithPath:[NSString stringWithUTF8String:f.info->file]];
    if (f.features.count) a[K(kCTFontFeatureSettingsAttribute)] = f.features;
    return a;
}
CTFontDescriptorRef CTFontCopyFontDescriptor(CTFontRef font) {
    __NSCTFontDescriptor *d = [__NSCTFontDescriptor new];
    d.attributes = font_attributes(F(font));
    return (CTFontDescriptorRef)CFBridgingRetain(d);
}
CFTypeRef CTFontCopyAttribute(CTFontRef font, CFStringRef attr) {
    if (CFEqual(attr, kCTFontFeaturesAttribute)) return CTFontCopyFeatures(font);
    id v = font_attributes(F(font))[K(attr)];
    return v ? CFBridgingRetain(v) : NULL;
}
CGFloat CTFontGetSize(CTFontRef font) { return F(font).size; }
CGAffineTransform CTFontGetMatrix(CTFontRef font) { return CGAffineTransformIdentity; }
CFStringRef CTFontCopyPostScriptName(CTFontRef font) { return (CFStringRef)CFBridgingRetain([F(font).name copy]); }
CFStringRef CTFontCopyFamilyName(CTFontRef font) { return (CFStringRef)CFBridgingRetain(F(font).family ?: @".SF UI Text"); }
CFStringRef CTFontCopyFullName(CTFontRef font) { return (CFStringRef)CFBridgingRetain(F(font).name ?: @""); }
CFStringRef CTFontCopyDisplayName(CTFontRef font) { return (CFStringRef)CFBridgingRetain(F(font).family ?: @"System Font"); }
CFStringRef CTFontCopyName(CTFontRef font, CFStringRef key) {
    __NSCTFont *f = F(font);
    NSString *v = nil;
    if (CFEqual(key, kCTFontPostScriptNameKey)) v = f.name;
    else if (CFEqual(key, kCTFontFamilyNameKey)) v = f.family ?: @".SF UI Text";
    else if (CFEqual(key, kCTFontSubFamilyNameKey) || CFEqual(key, kCTFontStyleNameKey)) v = style_name(f);
    else if (CFEqual(key, kCTFontFullNameKey)) {
        NSString *st = style_name(f);
        v = [st isEqualToString:@"Regular"] ? (f.family ?: @"System Font") : [NSString stringWithFormat:@"%@ %@", f.family ?: @"System Font", st];
    }
    else if (CFEqual(key, kCTFontUniqueNameKey)) v = f.info->psname[0] ? [NSString stringWithUTF8String:f.info->psname] : f.name;
    return v ? (CFStringRef)CFBridgingRetain([v copy]) : NULL;
}
CFStringRef CTFontCopyLocalizedName(CTFontRef font, CFStringRef key, CFStringRef *lang) {
    if (lang) *lang = NULL;
    return CTFontCopyName(font, key);
}
CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font) {
    __NSCTFontCharacterSet *s = [__NSCTFontCharacterSet new];
    s.family = F(font).family ?: (F(font).info->family[0] ? [NSString stringWithUTF8String:F(font).info->family] : @"Adwaita Sans");
    return (CFCharacterSetRef)CFBridgingRetain(s);
}
/* metrics from the font file; estimates when the host has no font at all */
#define METRIC(expr, est) ({ __NSCTFont *_f = F(f); _f.info->units_per_em ? (CGFloat)(_f.info->expr) : _f.size * (est); })
CGFloat CTFontGetAscent(CTFontRef f) { return METRIC(ascent, 0.952); }
CGFloat CTFontGetDescent(CTFontRef f) { return METRIC(descent, 0.241); }
CGFloat CTFontGetLeading(CTFontRef f) { return METRIC(leading, 0); }
CGFloat CTFontGetCapHeight(CTFontRef f) { return METRIC(cap_height, 0.705); }
CGFloat CTFontGetXHeight(CTFontRef f) { return METRIC(x_height, 0.528); }
unsigned CTFontGetUnitsPerEm(CTFontRef f) { unsigned u = (unsigned)F(f).info->units_per_em; return u ? u : 2048; }
CFIndex CTFontGetGlyphCount(CTFontRef f) { return F(f).info->glyph_count; }
CGRect CTFontGetBoundingBox(CTFontRef f) {
    __NSCTFont *x = F(f); const double *b = x.info->bbox; CGFloat s = x.size;
    return b[2] > 0 ? CGRectMake(b[0], b[1], b[2], b[3]) : CGRectMake(-0.2 * s, -0.3 * s, 1.4 * s, 1.3 * s);
}
CGFloat CTFontGetUnderlinePosition(CTFontRef f) { return METRIC(underline_position, -0.1); }
CGFloat CTFontGetUnderlineThickness(CTFontRef f) { return METRIC(underline_thickness, 0.05); }
CGFloat CTFontGetSlantAngle(CTFontRef f) { __NSCTFont *x = F(f); return x.info->slant_angle ?: (x.italic ? -12 : 0); }
/* UTF-16 in, one glyph per code unit (a surrogate pair's glyph is at the high surrogate, 0 at the low one) */
bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *chars, CGGlyph *glyphs, CFIndex count) {
    if (count <= 0) return true;
    unsigned *cps = calloc((size_t)count, sizeof *cps);
    unsigned short *g = calloc((size_t)count, sizeof *g);
    BOOL *pair = calloc((size_t)count, sizeof *pair);
    for (CFIndex i = 0; i < count; i++) {
        UniChar c = chars[i];
        if (c >= 0xd800 && c < 0xdc00 && i + 1 < count && chars[i + 1] >= 0xdc00 && chars[i + 1] < 0xe000) {
            cps[i] = 0x10000 + ((unsigned)(c - 0xd800) << 10) + (chars[i + 1] - 0xdc00); pair[i + 1] = YES;
        } else cps[i] = c;
    }
    isim_ct_font_glyphs([F(font) host], cps, g, (int)count);
    bool all = true;
    for (CFIndex i = 0; i < count; i++) {
        glyphs[i] = pair[i] ? 0 : g[i];
        if (!pair[i] && !g[i]) all = false;
    }
    free(cps); free(g); free(pair);
    return all;
}
double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation o, const CGGlyph *glyphs, CGSize *adv, CFIndex count) {
    if (count <= 0) return 0;
    double *a = calloc((size_t)count, sizeof *a), total = 0;
    isim_ct_font_glyph_metrics([F(font) host], glyphs, (int)count, a, NULL);
    for (CFIndex i = 0; i < count; i++) {
        if (adv) adv[i] = o == kCTFontOrientationVertical ? CGSizeMake(0, F(font).info->ascent + F(font).info->descent) : CGSizeMake(a[i], 0);
        total += o == kCTFontOrientationVertical ? F(font).info->ascent + F(font).info->descent : a[i];
    }
    free(a);
    return total;
}
CGRect CTFontGetBoundingRectsForGlyphs(CTFontRef font, CTFontOrientation o, const CGGlyph *glyphs, CGRect *rects, CFIndex count) {
    if (count <= 0) return CGRectNull;
    double *r = calloc((size_t)count * 4, sizeof *r);
    isim_ct_font_glyph_metrics([F(font) host], glyphs, (int)count, NULL, r);
    CGRect all = CGRectNull;
    for (CFIndex i = 0; i < count; i++) {
        CGRect g = CGRectMake(r[4 * i], r[4 * i + 1], r[4 * i + 2], r[4 * i + 3]);
        if (rects) rects[i] = g;
        if (g.size.width > 0 || g.size.height > 0) all = CGRectUnion(all, g);
    }
    free(r);
    return CGRectIsNull(all) ? CGRectZero : all;
}
CGPathRef CTFontCreatePathForGlyph(CTFontRef font, CGGlyph glyph, const CGAffineTransform *m) {
    __NSCTFont *f = F(font);
    if (glyph >= f.info->glyph_count) return NULL;
    int n = isim_ct_font_glyph_path([f host], glyph, NULL, 0);
    double *ops = calloc((size_t)(n ? n : 1), sizeof *ops);
    isim_ct_font_glyph_path([f host], glyph, ops, n);
    CGMutablePathRef p = CGPathCreateMutable();
    for (int i = 0; i < n;) {
        int code = (int)ops[i++]; const double *q = ops + i;
        switch (code) {
        case 0: CGPathMoveToPoint(p, m, q[0], q[1]); i += 2; break;
        case 1: CGPathAddLineToPoint(p, m, q[0], q[1]); i += 2; break;
        case 2: CGPathAddQuadCurveToPoint(p, m, q[0], q[1], q[2], q[3]); i += 4; break;
        case 3: CGPathAddCurveToPoint(p, m, q[0], q[1], q[2], q[3], q[4], q[5]); i += 6; break;
        default: CGPathCloseSubpath(p); break;
        }
    }
    free(ops);
    return p;
}
void CTFontDrawGlyphs(CTFontRef font, const CGGlyph *glyphs, const CGPoint *positions, size_t count, CGContextRef c) {
    if (!count || !c) return;
    double *pos = calloc(count * 2, sizeof *pos);
    for (size_t i = 0; i < count; i++) { pos[2 * i] = positions[i].x; pos[2 * i + 1] = positions[i].y; }
    isim_cg_context_draw_glyphs(c, [F(font) host], glyphs, pos, (int)count);
    free(pos);
}
CGFontRef CTFontCopyGraphicsFont(CTFontRef font, CTFontDescriptorRef *attrs) {
    if (attrs) *attrs = NULL;
    return CGFontCreateWithFontName((__bridge CFStringRef)(F(font).name ?: @".SFUI-Regular"));
}
CTFontRef CTFontCreateWithGraphicsFont(CGFontRef g, CGFloat size, const CGAffineTransform *m, CTFontDescriptorRef attrs) {
    CFStringRef n = CGFontCopyPostScriptName(g);
    CTFontRef f = CTFontCreateWithName(n ?: CFSTR(".SFUI-Regular"), size, m);
    if (n) CFRelease(n);
    return f;
}
/* the font's features as Core Text lists them: a dictionary per AAT feature type whose OpenType features the font has */
CFArrayRef CTFontCopyFeatures(CTFontRef font) {
    unsigned tags[512];
    int n = isim_ct_font_features([F(font) host], tags, 512);
    NSMutableSet *have = [NSMutableSet set];
    for (int i = 0; i < n && i < 512; i++)
        [have addObject:[NSString stringWithFormat:@"%c%c%c%c", (char)(tags[i] >> 24), (char)(tags[i] >> 16), (char)(tags[i] >> 8), (char)tags[i]]];
    NSMutableArray *types = [NSMutableArray array];
    NSMutableDictionary<NSNumber *, NSMutableArray *> *sels = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber *, NSDictionary *> *heads = [NSMutableDictionary dictionary];
    for (size_t i = 0; i < NFEATURES; i++) {
        const feature_map *m = &FEATURES[i];
        /* a selector is listed when the font has the feature it turns on (or off, for a type's default) */
        NSString *first = [[@(m->ot) componentsSeparatedByString:@" "] firstObject];
        BOOL any = NO;
        for (size_t j = 0; j < NFEATURES; j++)
            if (FEATURES[j].type == m->type && [have containsObject:[[@(FEATURES[j].ot) componentsSeparatedByString:@" "] firstObject]]) any = YES;
        if (!any || (![have containsObject:first] && !m->dflt)) continue;
        NSNumber *t = @(m->type);
        if (!sels[t]) {
            sels[t] = [NSMutableArray array];
            heads[t] = @{ K(kCTFontFeatureTypeIdentifierKey): t, K(kCTFontFeatureTypeNameKey): @(m->typeName), K(kCTFontFeatureTypeExclusiveKey): @(m->exclusive) };
            [types addObject:t];
        }
        NSArray *ot = [[@(m->ot) componentsSeparatedByString:@","].firstObject componentsSeparatedByString:@" "];
        NSMutableDictionary *s = [@{ K(kCTFontFeatureSelectorIdentifierKey): @(m->sel), K(kCTFontFeatureSelectorNameKey): @(m->selName),
                                     K(kCTFontOpenTypeFeatureTag): ot[0], K(kCTFontOpenTypeFeatureValue): @([ot[1] intValue]) } mutableCopy];
        if (m->dflt) s[K(kCTFontFeatureSelectorDefaultKey)] = @YES;
        [sels[t] addObject:s];
    }
    for (int k = 1; k <= 20; k++) {                       /* stylistic sets */
        NSString *tag = [NSString stringWithFormat:@"ss%02d", k];
        if (![have containsObject:tag]) continue;
        if (!sels[@35]) {
            sels[@35] = [NSMutableArray array];
            heads[@35] = @{ K(kCTFontFeatureTypeIdentifierKey): @35, K(kCTFontFeatureTypeNameKey): @"Alternative Stylistic Sets", K(kCTFontFeatureTypeExclusiveKey): @NO };
            [types addObject:@35];
        }
        [sels[@35] addObject:@{ K(kCTFontFeatureSelectorIdentifierKey): @(2 * k), K(kCTFontFeatureSelectorNameKey): [NSString stringWithFormat:@"Stylistic Set %d", k],
                                K(kCTFontOpenTypeFeatureTag): tag, K(kCTFontOpenTypeFeatureValue): @1 }];
        [sels[@35] addObject:@{ K(kCTFontFeatureSelectorIdentifierKey): @(2 * k + 1), K(kCTFontFeatureSelectorNameKey): [NSString stringWithFormat:@"Stylistic Set %d Off", k],
                                K(kCTFontOpenTypeFeatureTag): tag, K(kCTFontOpenTypeFeatureValue): @0, K(kCTFontFeatureSelectorDefaultKey): @YES }];
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSNumber *t in types) {
        NSMutableDictionary *d = [heads[t] mutableCopy];
        d[K(kCTFontFeatureTypeSelectorsKey)] = sels[t];
        [out addObject:d];
    }
    return (CFArrayRef)CFBridgingRetain(out);
}
CFArrayRef CTFontCopyFeatureSettings(CTFontRef font) { return F(font).features.count ? (CFArrayRef)CFBridgingRetain(F(font).features) : NULL; }

/* ---- descriptors ---- */
static CTFontDescriptorRef descriptor(NSDictionary *a) { __NSCTFontDescriptor *d = [__NSCTFontDescriptor new]; d.attributes = a ?: @{}; return (CTFontDescriptorRef)CFBridgingRetain(d); }
static NSDictionary *DA(CTFontDescriptorRef d) { return ((__bridge __NSCTFontDescriptor *)d).attributes; }
CTFontDescriptorRef CTFontDescriptorCreateWithNameAndSize(CFStringRef name, CGFloat size) {
    return descriptor(@{ K(kCTFontNameAttribute): (__bridge NSString *)name, K(kCTFontSizeAttribute): @(size) });
}
CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef a) { return descriptor((__bridge NSDictionary *)a); }
CTFontDescriptorRef CTFontDescriptorCreateCopyWithAttributes(CTFontDescriptorRef o, CFDictionaryRef a) {
    NSMutableDictionary *m = [DA(o) mutableCopy]; [m addEntriesFromDictionary:(__bridge NSDictionary *)a]; return descriptor(m);
}
CTFontDescriptorRef CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef o, CTFontSymbolicTraits v, CTFontSymbolicTraits mask) {
    NSMutableDictionary *m = [DA(o) mutableCopy];
    NSMutableDictionary *t = [m[K(kCTFontTraitsAttribute)] mutableCopy] ?: [NSMutableDictionary dictionary];
    uint32_t cur = [t[K(kCTFontSymbolicTrait)] unsignedIntValue];
    t[K(kCTFontSymbolicTrait)] = @((cur & ~mask) | (v & mask));
    if (mask & kCTFontTraitBold) [t removeObjectForKey:K(kCTFontWeightTrait)];
    if (mask & (kCTFontTraitCondensed | kCTFontTraitExpanded)) [t removeObjectForKey:K(kCTFontWidthTrait)];
    if (mask & kCTFontTraitItalic) [t removeObjectForKey:K(kCTFontSlantTrait)];
    m[K(kCTFontTraitsAttribute)] = t;
    if (mask & (kCTFontTraitBold | kCTFontTraitItalic)) [m removeObjectForKey:K(kCTFontStyleNameAttribute)];
    return descriptor(m);
}
CTFontDescriptorRef CTFontDescriptorCreateCopyWithFamily(CTFontDescriptorRef o, CFStringRef family) {
    NSMutableDictionary *m = [DA(o) mutableCopy]; m[K(kCTFontFamilyNameAttribute)] = (__bridge NSString *)family;
    [m removeObjectForKey:K(kCTFontNameAttribute)];
    return descriptor(m);
}
CTFontDescriptorRef CTFontDescriptorCreateCopyWithFeature(CTFontDescriptorRef o, CFNumberRef type, CFNumberRef sel) {
    NSMutableDictionary *m = [DA(o) mutableCopy];
    m[K(kCTFontFeatureSettingsAttribute)] = add_feature(m[K(kCTFontFeatureSettingsAttribute)] ?: @[], @{ K(kCTFontFeatureTypeIdentifierKey): (__bridge NSNumber *)type,
                                                                                                          K(kCTFontFeatureSelectorIdentifierKey): (__bridge NSNumber *)sel });
    return descriptor(m);
}
CFDictionaryRef CTFontDescriptorCopyAttributes(CTFontDescriptorRef d) { return (CFDictionaryRef)CFBridgingRetain([DA(d) copy]); }
CFTypeRef CTFontDescriptorCopyAttribute(CTFontDescriptorRef d, CFStringRef attr) { id v = DA(d)[K(attr)]; return v ? CFBridgingRetain(v) : NULL; }
CFTypeRef CTFontDescriptorCopyLocalizedAttribute(CTFontDescriptorRef d, CFStringRef attr, CFStringRef *lang) {
    if (lang) *lang = NULL;
    return CTFontDescriptorCopyAttribute(d, attr);
}
CTFontDescriptorRef CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef d, CFSetRef mandatory) {
    CFArrayRef all = CTFontDescriptorCreateMatchingFontDescriptors(d, mandatory);
    if (all) {
        CTFontDescriptorRef first = CFRetain(CFArrayGetValueAtIndex(all, 0));
        CFRelease(all);
        return first;
    }
    if (mandatory && CFSetGetCount(mandatory)) return NULL;
    CTFontRef f = CTFontCreateWithFontDescriptor(d, 0, NULL);
    CTFontDescriptorRef r = CTFontCopyFontDescriptor(f);
    CFRelease(f);
    return r;
}
/* the descriptors of a family's installed faces that match the descriptor's name, style and traits, closest first */
CFArrayRef CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef d, CFSetRef mandatory) {
    NSDictionary *a = DA(d);
    NSSet *must = (__bridge NSSet *)mandatory;
    CTFontRef font = CTFontCreateWithFontDescriptor(d, 0, NULL);
    __NSCTFont *f = CFBridgingRelease(font);
    NSString *family = f.family;
    if (!family.length) return NULL;                  /* the system font and fonts missing on the host have no installed faces */
    int len = 1 << 16; char *buf = malloc((size_t)len);
    isim_ct_font_faces(family.UTF8String, buf, len);
    NSString *list = [NSString stringWithUTF8String:buf];
    free(buf);
    NSString *name = a[K(kCTFontNameAttribute)], *style = a[K(kCTFontStyleNameAttribute)];
    NSDictionary *traits = a[K(kCTFontTraitsAttribute)];
    BOOL wantTraits = traits[K(kCTFontSymbolicTrait)] || traits[K(kCTFontWeightTrait)] || style.length;
    int wantWeight = isim_ct_pango_weight(f.bold && f.weight < 0.3 ? 0.4 : f.weight);
    NSMutableArray *faces = [NSMutableArray array];
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        NSArray *c = [line componentsSeparatedByString:@"\t"];
        if (c.count < 6) continue;
        NSString *ps = c[0], *st = c[1];
        int w = [c[3] intValue], it = [c[4] intValue];
        if (name.length && ![name isEqualToString:family] && [must containsObject:K(kCTFontNameAttribute)] && ![ps isEqualToString:name]) continue;
        if (style.length && [must containsObject:K(kCTFontStyleNameAttribute)] && [st caseInsensitiveCompare:style] != NSOrderedSame) continue;
        if ([must containsObject:K(kCTFontTraitsAttribute)] && ((w >= 600) != f.bold || it != f.italic)) continue;
        double dist = (name.length && [ps isEqualToString:name] ? -1e6 : 0) + (style.length && [st caseInsensitiveCompare:style] == NSOrderedSame ? -1e5 : 0) +
                      (wantTraits || name.length ? abs(w - wantWeight) + (it != f.italic) * 1000 : w == 400 && !it ? -1 : abs(w - 400) + it * 1000);
        NSDictionary *t = @{ K(kCTFontSymbolicTrait): @((w >= 600 ? kCTFontTraitBold : 0) | (it ? kCTFontTraitItalic : 0)), K(kCTFontWeightTrait): @(uiweight(w)) };
        NSMutableDictionary *fa = [@{ K(kCTFontNameAttribute): ps, K(kCTFontFamilyNameAttribute): c[2], K(kCTFontStyleNameAttribute): st,
                                      K(kCTFontTraitsAttribute): t } mutableCopy];
        if (a[K(kCTFontSizeAttribute)]) fa[K(kCTFontSizeAttribute)] = a[K(kCTFontSizeAttribute)];
        if (a[K(kCTFontFeatureSettingsAttribute)]) fa[K(kCTFontFeatureSettingsAttribute)] = a[K(kCTFontFeatureSettingsAttribute)];
        [faces addObject:@[ @(dist), ps, CFBridgingRelease(descriptor(fa)) ]];
    }
    if (!faces.count) return NULL;
    [faces sortUsingComparator:^NSComparisonResult(NSArray *x, NSArray *y) {
        NSComparisonResult r = [x[0] compare:y[0]]; return r != NSOrderedSame ? r : [x[1] compare:y[1]];
    }];
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSArray *e in faces) if (![seen containsObject:e[1]]) { [seen addObject:e[1]]; [out addObject:e[2]]; }
    return (CFArrayRef)CFBridgingRetain(out);
}

/* ---- font registration ---- */
bool CTFontManagerRegisterFontsForURL(CFURLRef url, CTFontManagerScope scope, CFErrorRef *error) {
    NSString *path = ((__bridge NSURL *)url).path;
    if (path && isim_font_register(path.UTF8String)) return true;
    if (error) *error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:@"com.apple.CoreText.CTFontManagerErrorDomain" code:105
                                                                      userInfo:@{ NSLocalizedDescriptionKey: @"The file could not be registered." }]);
    return false;
}
bool CTFontManagerUnregisterFontsForURL(CFURLRef url, CTFontManagerScope scope, CFErrorRef *error) { return true; }
