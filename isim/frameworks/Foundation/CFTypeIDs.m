/* CFGetTypeID / CFStringGetTypeID and the CFString hash helpers the Swift runtime looks up with dlsym
 * (stdlib FoundationHelpers.mm: _swift_stdlib_isNSString, used when a native Swift string object receives
 * -isEqualToString: or -hash, e.g. the domain of a bridged Swift error). isim's CF types are its Foundation
 * classes, so type IDs come from the object's class; the hashes match -[NSString hash]. */
#import <Foundation/Foundation.h>
#import <CoreFoundation/CFBase.h>

enum { ISIM_CF_OTHER = 1, ISIM_CF_STRING = 7, ISIM_CF_ARRAY = 19, ISIM_CF_DICTIONARY = 18, ISIM_CF_NUMBER = 22, ISIM_CF_DATA = 20 };

CFTypeID CFStringGetTypeID(void) { return ISIM_CF_STRING; }
CFTypeID CFGetTypeID(CFTypeRef cf) {
    id o = (__bridge id)cf;
    if ([o isKindOfClass:[NSString class]]) return ISIM_CF_STRING;
    if ([o isKindOfClass:[NSArray class]]) return ISIM_CF_ARRAY;
    if ([o isKindOfClass:[NSDictionary class]]) return ISIM_CF_DICTIONARY;
    if ([o isKindOfClass:[NSNumber class]]) return ISIM_CF_NUMBER;
    if ([o isKindOfClass:[NSData class]]) return ISIM_CF_DATA;
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
