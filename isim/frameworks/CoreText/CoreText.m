// isim CoreText subset: CTFont objects resolved through the host's fontconfig, glyph coverage,
// font registration. CTFont objects are Objective-C objects (as on Apple platforms, CF types are).
#import <Foundation/Foundation.h>
#include <CoreText/CoreText.h>
#include <isim_host.h>

@interface __NSCTFont : NSObject
@property (copy) NSString *name, *family;
@property CGFloat size, weight;
@end
@implementation __NSCTFont
- (NSString *)description { return [NSString stringWithFormat:@"<CTFont %p> %@ (%@) %gpt", self, _name, _family ?: @"system", _size]; }
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

CTFontRef CTFontCreateWithName(CFStringRef cfname, CGFloat size, const CGAffineTransform *matrix) {
    NSString *name = (__bridge NSString *)cfname;
    __NSCTFont *f = [__NSCTFont new];
    f.size = size > 0 ? size : 12;
    char fam[256]; double w = 0; int italic = 0;
    if (name.length && isim_font_lookup(name.UTF8String, fam, sizeof fam, &w, &italic)) {
        f.name = name; f.family = [NSString stringWithUTF8String:fam]; f.weight = w;
    } else {
        f.name = @".SFUI-Regular";          /* like iOS: an unknown name gives the system font */
    }
    return (CTFontRef)CFBridgingRetain(f);
}
CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, const void *attributes) {
    __NSCTFont *f = [__NSCTFont new];
    f.name = F(font).name; f.family = F(font).family; f.weight = F(font).weight; f.size = size > 0 ? size : F(font).size;
    return (CTFontRef)CFBridgingRetain(f);
}
CGFloat CTFontGetSize(CTFontRef font) { return F(font).size; }
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

bool CTFontManagerRegisterFontsForURL(CFURLRef url, CTFontManagerScope scope, CFErrorRef *error) {
    NSString *path = ((__bridge NSURL *)url).path;
    if (path && isim_font_register(path.UTF8String)) return true;
    if (error) *error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:@"com.apple.CoreText.CTFontManagerErrorDomain" code:105
                                                                      userInfo:@{ NSLocalizedDescriptionKey: @"The file could not be registered." }]);
    return false;
}
bool CTFontManagerUnregisterFontsForURL(CFURLRef url, CTFontManagerScope scope, CFErrorRef *error) { return true; }
