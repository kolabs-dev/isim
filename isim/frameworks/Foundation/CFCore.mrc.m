/* isim Foundation: more CoreFoundation over the toll-free bridged Foundation classes (as on iOS): CFNumber, mutable
 * CFArray / CFDictionary / CFSet, CFDate and absolute time, CFError, CFCopyDescription, the CoreFoundation version;
 * CFUUID is a CF type of its own (__NSCFUUID: 16 bytes), as it is not bridged to NSUUID on iOS. The collection
 * callbacks are not called: collections retain their values (the kCFType* behaviour, adapted). Without ARC: the
 * Create / Copy functions return +1 objects. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <isim_host.h>
#include <math.h>
#include <string.h>

/* ---------------- version numbers (isim's per emulated iOS version; see CFBase.h) ---------------- */
double kCFCoreFoundationVersionNumber = 2700.0;
double NSFoundationVersionNumber = 2700.0;
__attribute__((constructor)) static void isim_cf_versions(void) {
    int v = isim_os_version();                   /* 170000, 180000, 260000, 270100 ... */
    if (v > 0) kCFCoreFoundationVersionNumber = NSFoundationVersionNumber = 1000.0 + (v / 10000) * 100 + (v / 100 % 100);
}

/* ---------------- descriptions ---------------- */
CFStringRef CFCopyDescription(CFTypeRef cf) { return cf ? (CFStringRef)[[(id)cf description] copy] : NULL; }
CFStringRef CFCopyTypeIDDescription(CFTypeID t) {
    switch (t) {
    case 7: return CFSTR("CFString"); case 19: return CFSTR("CFArray"); case 18: return CFSTR("CFDictionary");
    case 17: return CFSTR("CFSet"); case 22: return CFSTR("CFNumber"); case 21: return CFSTR("CFBoolean");
    case 20: return CFSTR("CFData"); case 42: return CFSTR("CFDate"); case 43: return CFSTR("CFError"); case 44: return CFSTR("CFUUID");
    default: return CFSTR("CFType");
    }
}

/* ---------------- CFNumber ---------------- */
CFTypeID CFNumberGetTypeID(void) { return 22; }
CFTypeID CFBooleanGetTypeID(void) { return 21; }
CFNumberRef CFNumberCreate(CFAllocatorRef a, CFNumberType t, const void *p) {
    if (!p) return NULL;
    switch (t) {
    case kCFNumberSInt8Type: case kCFNumberCharType: return (CFNumberRef)[[NSNumber alloc] initWithInt:*(const int8_t *)p];
    case kCFNumberSInt16Type: case kCFNumberShortType: return (CFNumberRef)[[NSNumber alloc] initWithInt:*(const int16_t *)p];
    case kCFNumberSInt32Type: case kCFNumberIntType: return (CFNumberRef)[[NSNumber alloc] initWithInt:*(const int32_t *)p];
    case kCFNumberSInt64Type: case kCFNumberLongLongType: return (CFNumberRef)[[NSNumber alloc] initWithLongLong:*(const int64_t *)p];
    case kCFNumberLongType: case kCFNumberCFIndexType: case kCFNumberNSIntegerType: return (CFNumberRef)[[NSNumber alloc] initWithLongLong:*(const long *)p];
    case kCFNumberFloat32Type: case kCFNumberFloatType: return (CFNumberRef)[[NSNumber alloc] initWithFloat:*(const float *)p];
    case kCFNumberFloat64Type: case kCFNumberDoubleType: case kCFNumberCGFloatType: return (CFNumberRef)[[NSNumber alloc] initWithDouble:*(const double *)p];
    default: return NULL;
    }
}
/* the storage type, like CF: the signed sized types and Float32 / Float64 (BOOL / char as kCFNumberCharType) */
CFNumberType CFNumberGetType(CFNumberRef n) {
    const char *t = [(NSNumber *)n objCType];
    switch (t ? t[0] : 'q') {
    case 'c': case 'B': return kCFNumberCharType;
    case 'C': case 's': return kCFNumberSInt16Type;
    case 'S': case 'i': return kCFNumberSInt32Type;
    case 'f': return kCFNumberFloat32Type;
    case 'd': return kCFNumberFloat64Type;
    default: return kCFNumberSInt64Type;
    }
}
CFIndex CFNumberGetByteSize(CFNumberRef n) {
    switch (CFNumberGetType(n)) {
    case kCFNumberCharType: case kCFNumberSInt8Type: return 1;
    case kCFNumberSInt16Type: return 2;
    case kCFNumberSInt32Type: case kCFNumberFloat32Type: return 4;
    default: return 8;
    }
}
Boolean CFNumberIsFloatType(CFNumberRef n) { CFNumberType t = CFNumberGetType(n); return t == kCFNumberFloat32Type || t == kCFNumberFloat64Type; }
Boolean CFNumberGetValue(CFNumberRef n, CFNumberType t, void *out) {
    if (!n || !out) return false;
    NSNumber *x = (NSNumber *)n;
    double d = x.doubleValue;
    long long ll = x.longLongValue;
    BOOL isFloat = CFNumberIsFloatType(n);
#define INT_OUT(type, lo, hi) do { long long v = isFloat ? (long long)d : ll; *(type *)out = (type)v; \
        return (!isFloat || d == (double)v) && v >= (long long)(lo) && v <= (long long)(hi); } while (0)
    switch (t) {
    case kCFNumberSInt8Type: case kCFNumberCharType: INT_OUT(int8_t, INT8_MIN, INT8_MAX);
    case kCFNumberSInt16Type: case kCFNumberShortType: INT_OUT(int16_t, INT16_MIN, INT16_MAX);
    case kCFNumberSInt32Type: case kCFNumberIntType: INT_OUT(int32_t, INT32_MIN, INT32_MAX);
    case kCFNumberSInt64Type: case kCFNumberLongLongType: case kCFNumberLongType: case kCFNumberCFIndexType: case kCFNumberNSIntegerType:
        INT_OUT(int64_t, INT64_MIN, INT64_MAX);
    case kCFNumberFloat32Type: case kCFNumberFloatType: *(float *)out = (float)d; return isFloat ? (double)(float)d == d || isnan(d) : (long long)(float)ll == ll;
    case kCFNumberFloat64Type: case kCFNumberDoubleType: case kCFNumberCGFloatType: *(double *)out = d; return isFloat || (long long)d == ll;
    default: return false;
    }
#undef INT_OUT
}
CFComparisonResult CFNumberCompare(CFNumberRef a, CFNumberRef b, void *ctx) { return (CFComparisonResult)[(NSNumber *)a compare:(NSNumber *)b]; }
static NSNumber *num_inf, *num_ninf, *num_nan;
__attribute__((constructor)) static void isim_cf_numbers(void) {
    num_inf = [[NSNumber alloc] initWithDouble:INFINITY]; num_ninf = [[NSNumber alloc] initWithDouble:-INFINITY]; num_nan = [[NSNumber alloc] initWithDouble:NAN];
}
CFNumberRef isim_cf_pinf __asm__("_kCFNumberPositiveInfinity");
CFNumberRef isim_cf_ninf __asm__("_kCFNumberNegativeInfinity");
CFNumberRef isim_cf_nan __asm__("_kCFNumberNaN");
__attribute__((constructor(200))) static void isim_cf_number_constants(void) {
    if (!num_inf) isim_cf_numbers();
    isim_cf_pinf = (CFNumberRef)num_inf; isim_cf_ninf = (CFNumberRef)num_ninf; isim_cf_nan = (CFNumberRef)num_nan;
}

/* ---------------- arrays, dictionaries, sets ---------------- */
static NSRange ns_range(CFRange r) { return NSMakeRange((NSUInteger)r.location, (NSUInteger)r.length); }
CFTypeID CFArrayGetTypeID(void) { return 19; }
CFArrayRef CFArrayCreateCopy(CFAllocatorRef a, CFArrayRef arr) { return (CFArrayRef)[[NSArray alloc] initWithArray:(NSArray *)arr]; }
CFMutableArrayRef CFArrayCreateMutable(CFAllocatorRef a, CFIndex cap, const CFArrayCallBacks *cb) {
    return (CFMutableArrayRef)[[NSMutableArray alloc] initWithCapacity:(NSUInteger)(cap > 0 ? cap : 0)];
}
CFMutableArrayRef CFArrayCreateMutableCopy(CFAllocatorRef a, CFIndex cap, CFArrayRef arr) { return (CFMutableArrayRef)[[NSMutableArray alloc] initWithArray:(NSArray *)arr]; }
CFIndex CFArrayGetFirstIndexOfValue(CFArrayRef arr, CFRange r, const void *v) {
    NSUInteger i = [(NSArray *)arr indexOfObject:(id)v inRange:ns_range(r)];
    return i == NSNotFound ? kCFNotFound : (CFIndex)i;
}
Boolean CFArrayContainsValue(CFArrayRef arr, CFRange r, const void *v) { return CFArrayGetFirstIndexOfValue(arr, r, v) != kCFNotFound; }
CFIndex CFArrayGetCountOfValue(CFArrayRef arr, CFRange r, const void *v) {
    CFIndex n = 0;
    for (id o in [(NSArray *)arr subarrayWithRange:ns_range(r)]) if ([o isEqual:(id)v]) n++;
    return n;
}
void CFArrayGetValues(CFArrayRef arr, CFRange r, const void **values) {
    for (CFIndex i = 0; i < r.length; i++) values[i] = [(NSArray *)arr objectAtIndex:(NSUInteger)(r.location + i)];
}
void CFArrayAppendValue(CFMutableArrayRef arr, const void *v) { [(NSMutableArray *)arr addObject:(id)v]; }
void CFArrayInsertValueAtIndex(CFMutableArrayRef arr, CFIndex i, const void *v) { [(NSMutableArray *)arr insertObject:(id)v atIndex:(NSUInteger)i]; }
void CFArraySetValueAtIndex(CFMutableArrayRef arr, CFIndex i, const void *v) {
    NSMutableArray *m = (NSMutableArray *)arr;
    if ((NSUInteger)i == m.count) [m addObject:(id)v]; else [m replaceObjectAtIndex:(NSUInteger)i withObject:(id)v];
}
void CFArrayRemoveValueAtIndex(CFMutableArrayRef arr, CFIndex i) { [(NSMutableArray *)arr removeObjectAtIndex:(NSUInteger)i]; }
void CFArrayRemoveAllValues(CFMutableArrayRef arr) { [(NSMutableArray *)arr removeAllObjects]; }
void CFArrayAppendArray(CFMutableArrayRef arr, CFArrayRef other, CFRange r) { [(NSMutableArray *)arr addObjectsFromArray:[(NSArray *)other subarrayWithRange:ns_range(r)]]; }
void CFArrayExchangeValuesAtIndices(CFMutableArrayRef arr, CFIndex a, CFIndex b) { [(NSMutableArray *)arr exchangeObjectAtIndex:(NSUInteger)a withObjectAtIndex:(NSUInteger)b]; }

CFTypeID CFDictionaryGetTypeID(void) { return 18; }
CFDictionaryRef CFDictionaryCreateCopy(CFAllocatorRef a, CFDictionaryRef d) { return (CFDictionaryRef)[[NSDictionary alloc] initWithDictionary:(NSDictionary *)d]; }
CFMutableDictionaryRef CFDictionaryCreateMutable(CFAllocatorRef a, CFIndex cap, const CFDictionaryKeyCallBacks *kc, const CFDictionaryValueCallBacks *vc) {
    return (CFMutableDictionaryRef)[[NSMutableDictionary alloc] initWithCapacity:(NSUInteger)(cap > 0 ? cap : 0)];
}
CFMutableDictionaryRef CFDictionaryCreateMutableCopy(CFAllocatorRef a, CFIndex cap, CFDictionaryRef d) {
    return (CFMutableDictionaryRef)[[NSMutableDictionary alloc] initWithDictionary:(NSDictionary *)d];
}
Boolean CFDictionaryContainsKey(CFDictionaryRef d, const void *k) { return k && [(NSDictionary *)d objectForKey:(id)k] != nil; }
Boolean CFDictionaryContainsValue(CFDictionaryRef d, const void *v) { return v && [[(NSDictionary *)d allValues] containsObject:(id)v]; }
Boolean CFDictionaryGetValueIfPresent(CFDictionaryRef d, const void *k, const void **v) {
    id o = k ? [(NSDictionary *)d objectForKey:(id)k] : nil;
    if (o && v) *v = (const void *)o;
    return o != nil;
}
void CFDictionaryGetKeysAndValues(CFDictionaryRef d, const void **keys, const void **values) {
    NSUInteger i = 0;
    for (id k in (NSDictionary *)d) {
        if (keys) keys[i] = (const void *)k;
        if (values) values[i] = (const void *)[(NSDictionary *)d objectForKey:k];
        i++;
    }
}
void CFDictionaryAddValue(CFMutableDictionaryRef d, const void *k, const void *v) { if (![(NSDictionary *)d objectForKey:(id)k]) [(NSMutableDictionary *)d setObject:(id)v forKey:(id)k]; }
void CFDictionarySetValue(CFMutableDictionaryRef d, const void *k, const void *v) {
    if (v) [(NSMutableDictionary *)d setObject:(id)v forKey:(id)k]; else [(NSMutableDictionary *)d removeObjectForKey:(id)k];
}
void CFDictionaryReplaceValue(CFMutableDictionaryRef d, const void *k, const void *v) { if ([(NSDictionary *)d objectForKey:(id)k]) CFDictionarySetValue(d, k, v); }
void CFDictionaryRemoveValue(CFMutableDictionaryRef d, const void *k) { if (k) [(NSMutableDictionary *)d removeObjectForKey:(id)k]; }
void CFDictionaryRemoveAllValues(CFMutableDictionaryRef d) { [(NSMutableDictionary *)d removeAllObjects]; }

CFTypeID CFSetGetTypeID(void) { return 17; }
CFSetRef CFSetCreateCopy(CFAllocatorRef a, CFSetRef s) { return (CFSetRef)[[NSSet alloc] initWithArray:[(NSSet *)s allObjects]]; }
CFMutableSetRef CFSetCreateMutable(CFAllocatorRef a, CFIndex cap, const CFSetCallBacks *cb) {
    return (CFMutableSetRef)[[NSMutableSet alloc] init];
}
CFMutableSetRef CFSetCreateMutableCopy(CFAllocatorRef a, CFIndex cap, CFSetRef s) { return (CFMutableSetRef)[[NSMutableSet alloc] initWithArray:[(NSSet *)s allObjects]]; }
const void *CFSetGetValue(CFSetRef s, const void *v) { return v ? (const void *)[(NSSet *)s member:(id)v] : NULL; }
void CFSetGetValues(CFSetRef s, const void **values) { NSUInteger i = 0; for (id o in (NSSet *)s) values[i++] = (const void *)o; }
void CFSetAddValue(CFMutableSetRef s, const void *v) { if (v) [(NSMutableSet *)s addObject:(id)v]; }
void CFSetSetValue(CFMutableSetRef s, const void *v) { if (v) { [(NSMutableSet *)s removeObject:(id)v]; [(NSMutableSet *)s addObject:(id)v]; } }
void CFSetRemoveValue(CFMutableSetRef s, const void *v) { if (v) [(NSMutableSet *)s removeObject:(id)v]; }
void CFSetRemoveAllValues(CFMutableSetRef s) { [(NSMutableSet *)s removeAllObjects]; }

/* ---------------- absolute time, CFDate ---------------- */
const CFTimeInterval kCFAbsoluteTimeIntervalSince1970 = 978307200.0;
const CFTimeInterval kCFAbsoluteTimeIntervalSince1904 = 3061152000.0;
CFAbsoluteTime CFAbsoluteTimeGetCurrent(void) { return [NSDate timeIntervalSinceReferenceDate_isim]; }
CFTypeID CFDateGetTypeID(void) { return 42; }
CFDateRef CFDateCreate(CFAllocatorRef a, CFAbsoluteTime at) { return (CFDateRef)[[NSDate alloc] initWithTimeIntervalSinceReferenceDate:at]; }
CFAbsoluteTime CFDateGetAbsoluteTime(CFDateRef d) { return [(NSDate *)d timeIntervalSinceReferenceDate]; }
CFTimeInterval CFDateGetTimeIntervalSinceDate(CFDateRef d, CFDateRef o) { return [(NSDate *)d timeIntervalSinceDate:(NSDate *)o]; }
CFComparisonResult CFDateCompare(CFDateRef d, CFDateRef o, void *ctx) { return (CFComparisonResult)[(NSDate *)d compare:(NSDate *)o]; }

/* ---------------- CFError ---------------- */
const CFErrorDomain kCFErrorDomainPOSIX = CFSTR("NSPOSIXErrorDomain");
const CFErrorDomain kCFErrorDomainOSStatus = CFSTR("NSOSStatusErrorDomain");
const CFErrorDomain kCFErrorDomainMach = CFSTR("NSMachErrorDomain");
const CFErrorDomain kCFErrorDomainCocoa = CFSTR("NSCocoaErrorDomain");
const CFStringRef kCFErrorLocalizedDescriptionKey = CFSTR("NSLocalizedDescription");
const CFStringRef kCFErrorLocalizedFailureReasonKey = CFSTR("NSLocalizedFailureReason");
const CFStringRef kCFErrorLocalizedRecoverySuggestionKey = CFSTR("NSLocalizedRecoverySuggestion");
const CFStringRef kCFErrorDescriptionKey = CFSTR("NSDescription");
const CFStringRef kCFErrorUnderlyingErrorKey = CFSTR("NSUnderlyingError");
const CFStringRef kCFErrorURLKey = CFSTR("NSURL");
const CFStringRef kCFErrorFilePathKey = CFSTR("NSFilePath");
CFTypeID CFErrorGetTypeID(void) { return 43; }
CFErrorRef CFErrorCreate(CFAllocatorRef a, CFErrorDomain domain, CFIndex code, CFDictionaryRef userInfo) {
    return (CFErrorRef)[[NSError alloc] initWithDomain:(NSString *)domain code:code userInfo:(NSDictionary *)userInfo];
}
CFErrorRef CFErrorCreateWithUserInfoKeysAndValues(CFAllocatorRef a, CFErrorDomain domain, CFIndex code, const void *const *keys, const void *const *values, CFIndex n) {
    NSDictionary *info = [NSDictionary dictionaryWithObjects:(id *)values forKeys:(id *)keys count:(NSUInteger)(n > 0 ? n : 0)];
    return CFErrorCreate(a, domain, code, (CFDictionaryRef)info);
}
CFErrorDomain CFErrorGetDomain(CFErrorRef e) { return (CFErrorDomain)[(NSError *)e domain]; }
CFIndex CFErrorGetCode(CFErrorRef e) { return [(NSError *)e code]; }
CFDictionaryRef CFErrorCopyUserInfo(CFErrorRef e) { return (CFDictionaryRef)[([(NSError *)e userInfo] ?: @{}) copy]; }
CFStringRef CFErrorCopyDescription(CFErrorRef e) { return (CFStringRef)[[(NSError *)e localizedDescription] copy]; }
CFStringRef CFErrorCopyFailureReason(CFErrorRef e) { NSString *s = [(NSError *)e localizedFailureReason]; return s ? (CFStringRef)[s copy] : NULL; }
CFStringRef CFErrorCopyRecoverySuggestion(CFErrorRef e) { NSString *s = [(NSError *)e localizedRecoverySuggestion]; return s ? (CFStringRef)[s copy] : NULL; }

/* ---------------- CFUUID ---------------- */
@interface __NSCFUUID : NSObject { @public CFUUIDBytes _b; }
@end
@implementation __NSCFUUID
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[__NSCFUUID class]] && !memcmp(&_b, &((__NSCFUUID *)o)->_b, sizeof _b); }
- (NSUInteger)hash { NSUInteger h; memcpy(&h, &_b, sizeof h); return h; }
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
- (NSString *)uuidString {
    const UInt8 *u = &_b.byte0;
    return [NSString stringWithFormat:@"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15]];
}
- (NSString *)description { return [NSString stringWithFormat:@"<CFUUID %p> %@", self, [self uuidString]]; }
@end
static CFUUIDRef uuid_with(CFUUIDBytes b) { __NSCFUUID *u = [__NSCFUUID new]; u->_b = b; return (CFUUIDRef)u; }
CFTypeID CFUUIDGetTypeID(void) { return 44; }
CFUUIDRef CFUUIDCreate(CFAllocatorRef a) {
    uuid_t raw; [[NSUUID UUID] getUUIDBytes:raw];
    CFUUIDBytes b; memcpy(&b, raw, sizeof b);
    return uuid_with(b);
}
CFUUIDRef CFUUIDCreateWithBytes(CFAllocatorRef a, UInt8 b0, UInt8 b1, UInt8 b2, UInt8 b3, UInt8 b4, UInt8 b5, UInt8 b6, UInt8 b7,
                                UInt8 b8, UInt8 b9, UInt8 b10, UInt8 b11, UInt8 b12, UInt8 b13, UInt8 b14, UInt8 b15) {
    CFUUIDBytes b = { b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15 };
    return uuid_with(b);
}
CFUUIDRef CFUUIDCreateFromUUIDBytes(CFAllocatorRef a, CFUUIDBytes b) { return uuid_with(b); }
CFUUIDRef CFUUIDCreateFromString(CFAllocatorRef a, CFStringRef s) {
    NSUUID *n = [[NSUUID alloc] initWithUUIDString:(NSString *)s];
    if (!n) return NULL;
    uuid_t raw; [n getUUIDBytes:raw]; [n release];
    CFUUIDBytes b; memcpy(&b, raw, sizeof b);
    return uuid_with(b);
}
CFStringRef CFUUIDCreateString(CFAllocatorRef a, CFUUIDRef u) { return u ? (CFStringRef)[[(__NSCFUUID *)u uuidString] copy] : NULL; }
CFUUIDBytes CFUUIDGetUUIDBytes(CFUUIDRef u) { CFUUIDBytes z; memset(&z, 0, sizeof z); return u ? ((__NSCFUUID *)u)->_b : z; }
