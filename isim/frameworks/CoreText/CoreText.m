// isim CoreText: CTFont / CTFontDescriptor objects resolved through the host's fontconfig, glyph coverage,
// font registration. CT objects are Objective-C objects (as on Apple platforms, CF types are). Layout: CTLayout.m.
#import <Foundation/Foundation.h>
#include <CoreText/CoreText.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#import "CTPrivate.h"

const CFStringRef kCTFontNameAttribute = CFSTR("NSFontNameAttribute");
const CFStringRef kCTFontDisplayNameAttribute = CFSTR("NSFontVisibleNameAttribute");
const CFStringRef kCTFontFamilyNameAttribute = CFSTR("NSFontFamilyAttribute");
const CFStringRef kCTFontStyleNameAttribute = CFSTR("NSFontFaceAttribute");
const CFStringRef kCTFontSizeAttribute = CFSTR("NSFontSizeAttribute");
const CFStringRef kCTFontTraitsAttribute = CFSTR("NSCTFontTraitsAttribute");
const CFStringRef kCTFontSymbolicTrait = CFSTR("NSCTFontSymbolicTrait");
const CFStringRef kCTFontWeightTrait = CFSTR("NSCTFontWeightTrait");
const CFStringRef kCTFontWidthTrait = CFSTR("NSCTFontProportionTrait");
const CFStringRef kCTFontSlantTrait = CFSTR("NSCTFontSlantTrait");
const CFStringRef kCTFontFeatureSettingsAttribute = CFSTR("NSCTFontFeatureSettingsAttribute");
const CFStringRef kCTFontFeatureTypeIdentifierKey = CFSTR("CTFeatureTypeIdentifier");
const CFStringRef kCTFontFeatureSelectorIdentifierKey = CFSTR("CTFeatureSelectorIdentifier");
const CFStringRef kCTFontOpenTypeFeatureTag = CFSTR("CTFeatureOpenTypeTag");
const CFStringRef kCTFontOpenTypeFeatureValue = CFSTR("CTFeatureOpenTypeValue");

@implementation __NSCTFont
- (NSString *)description { return [NSString stringWithFormat:@"<CTFont %p> %@ (%@) %gpt%@%@", self, _name, _family ?: @"system", _size, _bold ? @" bold" : @"", _italic ? @" italic" : @""]; }
- (CGFloat)pointSize { return _size; }
- (NSString *)fontName { return _name; }
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

static __NSCTFont *F(CTFontRef f) { return (__bridge __NSCTFont *)f; }

CFTypeID CTFontGetTypeID(void) { return 0x4354; }
CFTypeID CTFontDescriptorGetTypeID(void) { return 0x4355; }

/* UIFont weights (-1...1) for CSS-like weight words in a font name */
static CGFloat weight_from_name(NSString *n) {
    NSString *l = n.lowercaseString;
    return [l containsString:@"black"] || [l containsString:@"heavy"] ? 0.56 : [l containsString:@"semibold"] || [l containsString:@"demibold"] ? 0.3
         : [l containsString:@"bold"] ? 0.4 : [l containsString:@"medium"] ? 0.23 : [l containsString:@"ultralight"] ? -0.8
         : [l containsString:@"thin"] ? -0.6 : [l containsString:@"light"] ? -0.4 : 0;
}
static __NSCTFont *font_named(NSString *name, CGFloat size) {
    __NSCTFont *f = [__NSCTFont new];
    f.size = size > 0 ? size : 12;
    char fam[256]; double w = 0; int italic = 0;
    if (name.length && isim_font_lookup(name.UTF8String, fam, sizeof fam, &w, &italic)) {
        f.name = name; f.family = [NSString stringWithUTF8String:fam]; f.weight = w; f.italic = italic;
    } else if (name.length && ![name hasPrefix:@"."]) {
        /* an iOS font that is not on the host: the system font with the name's weight and slant */
        NSString *l = name.lowercaseString;
        f.name = name; f.weight = weight_from_name(name);
        f.italic = [l containsString:@"italic"] || [l containsString:@"oblique"];
        f.mono = [l hasPrefix:@"menlo"] || [l hasPrefix:@"courier"] || [l hasPrefix:@"sfmono"];
    } else {
        f.name = @".SFUI-Regular";          /* like iOS: an unknown name gives the system font */
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
    f.italic = o.italic; f.bold = o.bold; f.mono = o.mono; f.features = o.features;
    return f;
}
static void apply_traits(__NSCTFont *f, uint32_t value, uint32_t mask) {
    if (mask & kCTFontTraitBold) { f.bold = (value & kCTFontTraitBold) != 0; f.weight = f.bold ? fmax(f.weight, 0.4) : (f.weight >= 0.3 ? 0 : f.weight); }
    if (mask & kCTFontTraitItalic) f.italic = (value & kCTFontTraitItalic) != 0;
    if (mask & kCTFontTraitMonoSpace) f.mono = (value & kCTFontTraitMonoSpace) != 0;
}
static void apply_attributes(__NSCTFont *f, NSDictionary *a) {
    NSString *family = a[(__bridge NSString *)kCTFontFamilyNameAttribute];
    if (family.length) {
        char fam[256]; double w = 0; int it = 0;
        if (isim_font_lookup(family.UTF8String, fam, sizeof fam, &w, &it)) f.family = [NSString stringWithUTF8String:fam];
        else f.family = nil;
        f.name = family;
    }
    NSDictionary *traits = a[(__bridge NSString *)kCTFontTraitsAttribute];
    if (traits[(__bridge NSString *)kCTFontWeightTrait]) { f.weight = [traits[(__bridge NSString *)kCTFontWeightTrait] doubleValue]; f.bold = f.weight >= 0.3; }
    if (traits[(__bridge NSString *)kCTFontSymbolicTrait]) apply_traits(f, [traits[(__bridge NSString *)kCTFontSymbolicTrait] unsignedIntValue], kCTFontTraitBold | kCTFontTraitItalic | kCTFontTraitMonoSpace);
    NSArray *features = a[(__bridge NSString *)kCTFontFeatureSettingsAttribute];
    if (features.count) f.features = [(f.features ?: @[]) arrayByAddingObjectsFromArray:features];
}
CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef d, CGFloat size, const CGAffineTransform *matrix) {
    NSDictionary *a = ((__bridge __NSCTFontDescriptor *)d).attributes;
    NSString *name = a[(__bridge NSString *)kCTFontNameAttribute] ?: a[(__bridge NSString *)kCTFontFamilyNameAttribute];
    CGFloat s = size > 0 ? size : [a[(__bridge NSString *)kCTFontSizeAttribute] doubleValue];
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
    return (f.bold ? kCTFontTraitBold : 0) | (f.italic ? kCTFontTraitItalic : 0) | (f.mono ? kCTFontTraitMonoSpace : 0) | (f.family ? 0 : kCTFontTraitUIOptimized);
}
CFDictionaryRef CTFontCopyTraits(CTFontRef font) {
    NSDictionary *d = @{ (__bridge NSString *)kCTFontSymbolicTrait: @(CTFontGetSymbolicTraits(font)), (__bridge NSString *)kCTFontWeightTrait: @(F(font).weight),
                         (__bridge NSString *)kCTFontSlantTrait: @(F(font).italic ? 0.07 : 0), (__bridge NSString *)kCTFontWidthTrait: @0 };
    return (CFDictionaryRef)CFBridgingRetain(d);
}
static NSDictionary *font_attributes(__NSCTFont *f) {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    a[(__bridge NSString *)kCTFontNameAttribute] = f.name ?: @".SFUI-Regular";
    a[(__bridge NSString *)kCTFontFamilyNameAttribute] = f.family ?: @".SF UI Text";
    a[(__bridge NSString *)kCTFontSizeAttribute] = @(f.size);
    a[(__bridge NSString *)kCTFontTraitsAttribute] = CFBridgingRelease(CTFontCopyTraits((__bridge CTFontRef)f));
    if (f.features.count) a[(__bridge NSString *)kCTFontFeatureSettingsAttribute] = f.features;
    return a;
}
CTFontDescriptorRef CTFontCopyFontDescriptor(CTFontRef font) {
    __NSCTFontDescriptor *d = [__NSCTFontDescriptor new];
    d.attributes = font_attributes(F(font));
    return (CTFontDescriptorRef)CFBridgingRetain(d);
}
CFTypeRef CTFontCopyAttribute(CTFontRef font, CFStringRef attr) {
    id v = font_attributes(F(font))[(__bridge NSString *)attr];
    return v ? CFBridgingRetain(v) : NULL;
}
CGFloat CTFontGetSize(CTFontRef font) { return F(font).size; }
CGAffineTransform CTFontGetMatrix(CTFontRef font) { return CGAffineTransformIdentity; }
CFStringRef CTFontCopyPostScriptName(CTFontRef font) { return (CFStringRef)CFBridgingRetain([F(font).name copy]); }
CFStringRef CTFontCopyFamilyName(CTFontRef font) { return (CFStringRef)CFBridgingRetain(F(font).family ?: @".SF UI Text"); }
CFStringRef CTFontCopyFullName(CTFontRef font) { return (CFStringRef)CFBridgingRetain(F(font).name ?: @""); }
CFStringRef CTFontCopyDisplayName(CTFontRef font) { return (CFStringRef)CFBridgingRetain(F(font).family ?: @"System Font"); }
CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font) {
    __NSCTFontCharacterSet *s = [__NSCTFontCharacterSet new];
    s.family = F(font).family ?: @"Adwaita Sans";
    return (CFCharacterSetRef)CFBridgingRetain(s);
}
CGFloat CTFontGetAscent(CTFontRef f) { return F(f).size * 0.952; }
CGFloat CTFontGetDescent(CTFontRef f) { return F(f).size * 0.241; }
CGFloat CTFontGetLeading(CTFontRef f) { return 0; }
CGFloat CTFontGetCapHeight(CTFontRef f) { return F(f).size * 0.705; }
CGFloat CTFontGetXHeight(CTFontRef f) { return F(f).size * 0.528; }
unsigned CTFontGetUnitsPerEm(CTFontRef f) { return 2048; }
CGRect CTFontGetBoundingBox(CTFontRef f) { CGFloat s = F(f).size; return CGRectMake(-0.2 * s, -0.3 * s, 1.4 * s, 1.3 * s); }
CGFloat CTFontGetUnderlinePosition(CTFontRef f) { return -F(f).size * 0.1; }
CGFloat CTFontGetUnderlineThickness(CTFontRef f) { return F(f).size * 0.05; }
CGFloat CTFontGetSlantAngle(CTFontRef f) { return F(f).italic ? -12 : 0; }
bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *chars, CGGlyph *glyphs, CFIndex count) {
    bool all = true;
    for (CFIndex i = 0; i < count; i++) {
        NSString *s = [NSString stringWithCharacters:&chars[i] length:1];
        NSAttributedString *a = [[NSAttributedString alloc] initWithString:s attributes:@{ NSFontAttributeName: (__bridge id)font }];
        NSString *mk = isim_ct_markup(a, NULL, NULL, NULL);
        void *l = isim_ct_layout_create(mk.UTF8String, 0, 0, 0, 1);
        unsigned short g = 0;
        if (l && isim_ct_line_runs(l, 0, NULL, 0) > 0) isim_ct_run_glyphs(l, 0, 0, &g, NULL, NULL, NULL, 1);
        isim_ct_layout_free(l);
        if (g & 0x8000 || (!isim_font_has_char((F(font).family ?: @"Adwaita Sans").UTF8String, chars[i]))) { g = 0; all = false; }
        glyphs[i] = g;
    }
    return all;
}
double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation o, const CGGlyph *glyphs, CGSize *adv, CFIndex count) {
    double total = 0, a = F(font).size * 0.55;          /* glyph tables are not read: an average advance */
    for (CFIndex i = 0; i < count; i++) { if (adv) adv[i] = CGSizeMake(a, 0); total += a; }
    return total;
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
CFArrayRef CTFontCopyFeatures(CTFontRef font) { return (CFArrayRef)CFBridgingRetain(@[]); }
CFArrayRef CTFontCopyFeatureSettings(CTFontRef font) { return F(font).features.count ? (CFArrayRef)CFBridgingRetain(F(font).features) : NULL; }

/* ---- descriptors ---- */
static CTFontDescriptorRef descriptor(NSDictionary *a) { __NSCTFontDescriptor *d = [__NSCTFontDescriptor new]; d.attributes = a ?: @{}; return (CTFontDescriptorRef)CFBridgingRetain(d); }
static NSDictionary *DA(CTFontDescriptorRef d) { return ((__bridge __NSCTFontDescriptor *)d).attributes; }
CTFontDescriptorRef CTFontDescriptorCreateWithNameAndSize(CFStringRef name, CGFloat size) {
    return descriptor(@{ (__bridge NSString *)kCTFontNameAttribute: (__bridge NSString *)name, (__bridge NSString *)kCTFontSizeAttribute: @(size) });
}
CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef a) { return descriptor((__bridge NSDictionary *)a); }
CTFontDescriptorRef CTFontDescriptorCreateCopyWithAttributes(CTFontDescriptorRef o, CFDictionaryRef a) {
    NSMutableDictionary *m = [DA(o) mutableCopy]; [m addEntriesFromDictionary:(__bridge NSDictionary *)a]; return descriptor(m);
}
CTFontDescriptorRef CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef o, CTFontSymbolicTraits v, CTFontSymbolicTraits mask) {
    NSMutableDictionary *m = [DA(o) mutableCopy];
    NSMutableDictionary *t = [m[(__bridge NSString *)kCTFontTraitsAttribute] mutableCopy] ?: [NSMutableDictionary dictionary];
    uint32_t cur = [t[(__bridge NSString *)kCTFontSymbolicTrait] unsignedIntValue];
    t[(__bridge NSString *)kCTFontSymbolicTrait] = @((cur & ~mask) | (v & mask));
    if (mask & kCTFontTraitBold) [t removeObjectForKey:(__bridge NSString *)kCTFontWeightTrait];
    m[(__bridge NSString *)kCTFontTraitsAttribute] = t;
    return descriptor(m);
}
CTFontDescriptorRef CTFontDescriptorCreateCopyWithFamily(CTFontDescriptorRef o, CFStringRef family) {
    NSMutableDictionary *m = [DA(o) mutableCopy]; m[(__bridge NSString *)kCTFontFamilyNameAttribute] = (__bridge NSString *)family;
    [m removeObjectForKey:(__bridge NSString *)kCTFontNameAttribute];
    return descriptor(m);
}
CTFontDescriptorRef CTFontDescriptorCreateCopyWithFeature(CTFontDescriptorRef o, CFNumberRef type, CFNumberRef sel) {
    NSMutableDictionary *m = [DA(o) mutableCopy];
    NSArray *f = m[(__bridge NSString *)kCTFontFeatureSettingsAttribute] ?: @[];
    m[(__bridge NSString *)kCTFontFeatureSettingsAttribute] = [f arrayByAddingObject:@{ (__bridge NSString *)kCTFontFeatureTypeIdentifierKey: (__bridge NSNumber *)type,
                                                                                         (__bridge NSString *)kCTFontFeatureSelectorIdentifierKey: (__bridge NSNumber *)sel }];
    return descriptor(m);
}
CFDictionaryRef CTFontDescriptorCopyAttributes(CTFontDescriptorRef d) { return (CFDictionaryRef)CFBridgingRetain([DA(d) copy]); }
CFTypeRef CTFontDescriptorCopyAttribute(CTFontDescriptorRef d, CFStringRef attr) { id v = DA(d)[(__bridge NSString *)attr]; return v ? CFBridgingRetain(v) : NULL; }

/* ---- font registration ---- */
bool CTFontManagerRegisterFontsForURL(CFURLRef url, CTFontManagerScope scope, CFErrorRef *error) {
    NSString *path = ((__bridge NSURL *)url).path;
    if (path && isim_font_register(path.UTF8String)) return true;
    if (error) *error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:@"com.apple.CoreText.CTFontManagerErrorDomain" code:105
                                                                      userInfo:@{ NSLocalizedDescriptionKey: @"The file could not be registered." }]);
    return false;
}
bool CTFontManagerUnregisterFontsForURL(CFURLRef url, CTFontManagerScope scope, CFErrorRef *error) { return true; }
