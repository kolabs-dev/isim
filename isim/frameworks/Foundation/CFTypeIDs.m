/* CFGetTypeID / CFStringGetTypeID and the CFString hash helpers the Swift runtime looks up with dlsym
 * (stdlib FoundationHelpers.mm: _swift_stdlib_isNSString, used when a native Swift string object receives
 * -isEqualToString: or -hash, e.g. the domain of a bridged Swift error). isim's CF types are its Foundation
 * classes, so type IDs come from the object's class; the hashes match -[NSString hash]. */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CoreFoundation/CFBase.h>

enum { ISIM_CF_OTHER = 1, ISIM_CF_STRING = 7, ISIM_CF_ARRAY = 19, ISIM_CF_DICTIONARY = 18, ISIM_CF_NUMBER = 22 };

CFTypeID CFStringGetTypeID(void) { return ISIM_CF_STRING; }
CFTypeID CFGetTypeID(CFTypeRef cf) {
    id o = (__bridge id)cf;
    if ([o isKindOfClass:[NSString class]]) return ISIM_CF_STRING;
    if ([o isKindOfClass:[NSArray class]]) return ISIM_CF_ARRAY;
    if ([o isKindOfClass:[NSDictionary class]]) return ISIM_CF_DICTIONARY;
    if ([o isKindOfClass:[NSNumber class]]) return ISIM_CF_NUMBER;
    if ([o isKindOfClass:[NSData class]]) return CFDataGetTypeID();       /* CFData.mrc.m */
    if ([o isKindOfClass:[NSSet class]]) return 17;                     /* CFCore.mrc.m: CFSetGetTypeID ... */
    if ([o isKindOfClass:[NSDate class]]) return 42;
    if ([o isKindOfClass:[NSError class]]) return 43;
    if ([o isKindOfClass:[NSURL class]]) return 29;                     /* CFURL.m: CFURLGetTypeID ... */
    if ([o isKindOfClass:[NSBundle class]]) return 31;
    if ([o isKindOfClass:[NSLocale class]]) return 41;                  /* CFLocale.m */
    if ([o isKindOfClass:[NSDateFormatter class]] || [o isKindOfClass:[NSISO8601DateFormatter class]]) return 50;
    if ([NSStringFromClass([o class]) isEqualToString:@"__NSCFUUID"]) return 44;
    /* Security's CF types that are Swift classes (no Objective-C methods): their ...GetTypeID values (Certificates.swift,
       SecKey.swift; SecTrust is Foundation's) */
    static const struct { const char *cls; CFTypeID tid; } swift_types[] = {
        { "_TtC8Security14SecCertificate", 0x5ec0 }, { "_TtC10Foundation8SecTrust", 0x5ec1 }, { "_TtC8Security11SecIdentity", 0x5ec2 },
        { "_TtC8Security9SecPolicy", 0x5ec3 }, { "_TtC8Security6SecKey", 0x5ec4 } };
    const char *cn = object_getClassName(o);
    for (size_t i = 0; cn && i < sizeof swift_types / sizeof swift_types[0]; i++) if (!strcmp(cn, swift_types[i].cls)) return swift_types[i].tid;
    /* CF types of other frameworks (Core Graphics objects, Security's SecAccessControlRef): the object knows its type ID */
    SEL own = NSSelectorFromString(@"_isimCFTypeID");
    if ([o respondsToSelector:own]) return ((CFTypeID (*)(id, SEL))[o methodForSelector:own])(o, own);
    return ISIM_CF_OTHER;
}
CFHashCode CFStringHashNSString(CFStringRef s) { return [(__bridge NSString *)s hash]; }
CFHashCode CFStringHashCString(const uint8_t *bytes, CFIndex length) {
    NSString *s = [[NSString alloc] initWithBytes:bytes length:(NSUInteger)length encoding:NSUTF8StringEncoding];
    return s.hash;
}

/* fast-path probes the Swift runtime sends to NSStrings it compares with or hashes against native Swift
 * strings; NULL means "no direct buffer", and Swift then reads the characters through -characterAtIndex: */
@implementation NSString (IsimSwiftStringProbes)
- (const char *)_fastCStringContents:(BOOL)nullTerminationRequired { return NULL; }
- (const unichar *)_fastCharacterContents { return NULL; }
@end
