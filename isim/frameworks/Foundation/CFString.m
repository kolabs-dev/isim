// isim CoreFoundation: CFString (toll-free bridged to NSString), CFTimeZone (bridged to NSTimeZone) and CFBundle (a
// CFBundleRef is the NSBundle) functions apps and binary SDKs call from C. Allocators are accepted and ignored (all
// objects come from the default malloc zone, like kCFAllocatorDefault); kCFAllocatorNull is honoured only as "do not
// free" by the CF calls that take a deallocator, which isim does not offer.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

const CFAllocatorRef kCFAllocatorDefault = NULL;
const CFAllocatorRef kCFAllocatorSystemDefault = (CFAllocatorRef)(uintptr_t)1;
const CFAllocatorRef kCFAllocatorMalloc = (CFAllocatorRef)(uintptr_t)2;
const CFAllocatorRef kCFAllocatorNull = (CFAllocatorRef)(uintptr_t)3;

unsigned long CFStringConvertEncodingToNSStringEncoding(CFStringEncoding e) {
    switch (e) {
    case kCFStringEncodingUTF8: return NSUTF8StringEncoding;
    case kCFStringEncodingASCII: return NSASCIIStringEncoding;
    case kCFStringEncodingISOLatin1: return NSISOLatin1StringEncoding;
    case kCFStringEncodingWindowsLatin1: return NSWindowsCP1252StringEncoding;
    case kCFStringEncodingMacRoman: return NSMacOSRomanStringEncoding;
    case kCFStringEncodingNonLossyASCII: return NSNonLossyASCIIStringEncoding;
    case kCFStringEncodingUTF16: return NSUTF16StringEncoding;
    case kCFStringEncodingUTF16BE: return NSUTF16BigEndianStringEncoding;
    case kCFStringEncodingUTF16LE: return NSUTF16LittleEndianStringEncoding;
    case kCFStringEncodingUTF32: return NSUTF32StringEncoding;
    case kCFStringEncodingUTF32BE: return NSUTF32BigEndianStringEncoding;
    case kCFStringEncodingUTF32LE: return NSUTF32LittleEndianStringEncoding;
    default: return 0;   // unsupported (kCFStringEncodingInvalidId's counterpart)
    }
}
CFStringEncoding CFStringConvertNSStringEncodingToEncoding(unsigned long e) {
    static const CFStringEncoding all[] = { kCFStringEncodingUTF8, kCFStringEncodingASCII, kCFStringEncodingISOLatin1,
        kCFStringEncodingWindowsLatin1, kCFStringEncodingMacRoman, kCFStringEncodingNonLossyASCII, kCFStringEncodingUTF16,
        kCFStringEncodingUTF16BE, kCFStringEncodingUTF16LE, kCFStringEncodingUTF32, kCFStringEncodingUTF32BE, kCFStringEncodingUTF32LE };
    for (size_t i = 0; i < sizeof all / sizeof *all; i++) if (CFStringConvertEncodingToNSStringEncoding(all[i]) == e) return all[i];
    return kCFStringEncodingInvalidId;
}

CFIndex CFStringGetLength(CFStringRef s) { return s ? (CFIndex)((__bridge NSString *)s).length : 0; }
UniChar CFStringGetCharacterAtIndex(CFStringRef s, CFIndex i) { return [(__bridge NSString *)s characterAtIndex:(NSUInteger)i]; }
void CFStringGetCharacters(CFStringRef s, CFRange r, UniChar *buf) {
    [(__bridge NSString *)s getCharacters:buf range:NSMakeRange((NSUInteger)r.location, (NSUInteger)r.length)];
}
Boolean CFStringGetCString(CFStringRef s, char *buf, CFIndex size, CFStringEncoding e) {
    if (!s || !buf || size <= 0) return false;
    NSStringEncoding ns = CFStringConvertEncodingToNSStringEncoding(e);
    NSData *d = ns ? [(__bridge NSString *)s dataUsingEncoding:ns] : nil;
    if (!d || (CFIndex)d.length >= size) return false;              /* no room for the terminating NUL */
    memcpy(buf, d.bytes, d.length);
    buf[d.length] = 0;
    return true;
}
/* Apple returns NULL when the string has no such internal storage; callers then use CFStringGetCString */
const char *CFStringGetCStringPtr(CFStringRef s, CFStringEncoding e) { (void)s; (void)e; return NULL; }
CFIndex CFStringGetMaximumSizeForEncoding(CFIndex length, CFStringEncoding e) {
    switch (e) {
    case kCFStringEncodingUTF8: return length * 3;
    case kCFStringEncodingUTF16: case kCFStringEncodingUTF16BE: case kCFStringEncodingUTF16LE: return length * 2;
    case kCFStringEncodingUTF32: case kCFStringEncodingUTF32BE: case kCFStringEncodingUTF32LE: return length * 4;
    default: return length;
    }
}
CFStringRef CFStringCreateWithCString(CFAllocatorRef a, const char *c, CFStringEncoding e) {
    NSStringEncoding ns = CFStringConvertEncodingToNSStringEncoding(e);
    NSString *s = c && ns ? [[NSString alloc] initWithBytes:c length:strlen(c) encoding:ns] : nil;
    return s ? (CFStringRef)CFBridgingRetain(s) : NULL;
}
CFStringRef CFStringCreateWithBytes(CFAllocatorRef a, const UInt8 *bytes, CFIndex n, CFStringEncoding e, Boolean ext) {
    NSStringEncoding ns = CFStringConvertEncodingToNSStringEncoding(e);
    NSString *s = ns ? [[NSString alloc] initWithBytes:bytes length:(NSUInteger)n encoding:ns] : nil;
    return s ? (CFStringRef)CFBridgingRetain(s) : NULL;
}
CFStringRef CFStringCreateCopy(CFAllocatorRef a, CFStringRef s) { return (CFStringRef)CFBridgingRetain([(__bridge NSString *)s copy]); }
CFMutableStringRef CFStringCreateMutable(CFAllocatorRef a, CFIndex max) { return (CFMutableStringRef)CFBridgingRetain([NSMutableString string]); }
CFMutableStringRef CFStringCreateMutableCopy(CFAllocatorRef a, CFIndex max, CFStringRef s) {
    return (CFMutableStringRef)CFBridgingRetain([(__bridge NSString *)s mutableCopy]);
}
CFStringRef CFStringCreateWithFormatAndArguments(CFAllocatorRef a, CFDictionaryRef o, CFStringRef f, va_list ap) {
    return (CFStringRef)CFBridgingRetain([[NSString alloc] initWithFormat:(__bridge NSString *)f arguments:ap]);
}
CFStringRef CFStringCreateWithFormat(CFAllocatorRef a, CFDictionaryRef o, CFStringRef f, ...) {
    va_list ap; va_start(ap, f);
    CFStringRef s = CFStringCreateWithFormatAndArguments(a, o, f, ap);
    va_end(ap);
    return s;
}
CFComparisonResult CFStringCompare(CFStringRef a, CFStringRef b, CFOptionFlags opts) {
    return (CFComparisonResult)[(__bridge NSString *)a compare:(__bridge NSString *)b options:(NSStringCompareOptions)opts];
}
void CFStringAppend(CFMutableStringRef s, CFStringRef t) { [(__bridge NSMutableString *)s appendString:(__bridge NSString *)t]; }
void CFStringAppendCString(CFMutableStringRef s, const char *c, CFStringEncoding e) {
    NSString *t = [[NSString alloc] initWithBytes:c length:strlen(c) encoding:CFStringConvertEncodingToNSStringEncoding(e)];
    if (t) [(__bridge NSMutableString *)s appendString:t];
}
void CFStringAppendFormatAndArguments(CFMutableStringRef s, CFDictionaryRef o, CFStringRef f, va_list ap) {
    [(__bridge NSMutableString *)s appendString:[[NSString alloc] initWithFormat:(__bridge NSString *)f arguments:ap]];
}
void CFStringAppendFormat(CFMutableStringRef s, CFDictionaryRef o, CFStringRef f, ...) {
    va_list ap; va_start(ap, f);
    CFStringAppendFormatAndArguments(s, o, f, ap);
    va_end(ap);
}

CFTimeZoneRef CFTimeZoneCopyDefault(void) { return (CFTimeZoneRef)CFBridgingRetain(NSTimeZone.defaultTimeZone); }
CFTimeZoneRef CFTimeZoneCopySystem(void) { return (CFTimeZoneRef)CFBridgingRetain(NSTimeZone.systemTimeZone); }
CFStringRef CFTimeZoneGetName(CFTimeZoneRef tz) { return (__bridge CFStringRef)((__bridge NSTimeZone *)tz).name; }

const CFStringRef kCFBundleInfoDictionaryVersionKey = CFSTR("CFBundleInfoDictionaryVersion");
const CFStringRef kCFBundleExecutableKey = CFSTR("CFBundleExecutable");
const CFStringRef kCFBundleIdentifierKey = CFSTR("CFBundleIdentifier");
const CFStringRef kCFBundleVersionKey = CFSTR("CFBundleVersion");
const CFStringRef kCFBundleNameKey = CFSTR("CFBundleName");
const CFStringRef kCFBundleDevelopmentRegionKey = CFSTR("CFBundleDevelopmentRegion");
CFBundleRef CFBundleGetMainBundle(void) { return (__bridge CFBundleRef)NSBundle.mainBundle; }
CFBundleRef CFBundleGetBundleWithIdentifier(CFStringRef i) { return (__bridge CFBundleRef)[NSBundle bundleWithIdentifier:(__bridge NSString *)i]; }
CFStringRef CFBundleGetIdentifier(CFBundleRef b) { return (__bridge CFStringRef)((__bridge NSBundle *)b).bundleIdentifier; }
CFTypeRef CFBundleGetValueForInfoDictionaryKey(CFBundleRef b, CFStringRef k) {
    return (__bridge CFTypeRef)[(__bridge NSBundle *)b objectForInfoDictionaryKey:(__bridge NSString *)k];
}
CFDictionaryRef CFBundleGetInfoDictionary(CFBundleRef b) { return (__bridge CFDictionaryRef)((__bridge NSBundle *)b).infoDictionary; }
/* the "vers" resource encoding of CFBundleVersion "M.m.b": BCD major, minor and bug-fix nibbles, final stage (0x80) */
UInt32 CFBundleGetVersionNumber(CFBundleRef b) {
    NSString *v = [(__bridge NSBundle *)b objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (![v isKindOfClass:NSString.class]) return 0;
    NSArray<NSString *> *p = [v componentsSeparatedByString:@"."];
    unsigned major = p.count > 0 ? (unsigned)p[0].intValue % 100 : 0, minor = p.count > 1 ? (unsigned)p[1].intValue & 15 : 0;
    unsigned bug = p.count > 2 ? (unsigned)p[2].intValue & 15 : 0;
    return ((major / 10) << 28) | ((major % 10) << 24) | (minor << 20) | (bug << 16) | (0x80u << 8);
}

/* Foundation */
Protocol *NSProtocolFromString(NSString *name) { return name ? objc_getProtocol(name.UTF8String) : nil; }
NSNotificationName const NSUserDefaultsDidChangeNotification = @"NSUserDefaultsDidChangeNotification";
