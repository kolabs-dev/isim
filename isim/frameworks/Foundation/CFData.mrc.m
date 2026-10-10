/* isim Foundation: CFData, CFArray, CFDictionary and CFSet functions over NSData / NSArray / NSDictionary / NSSet (toll-free bridged, as on iOS). */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>

CFTypeID CFDataGetTypeID(void) { return 0x4446; }
CFDataRef CFDataCreate(CFAllocatorRef a, const UInt8 *bytes, CFIndex len) { return (CFDataRef)[[NSData alloc] initWithBytes:bytes length:(NSUInteger)(len > 0 ? len : 0)]; }
CFDataRef CFDataCreateCopy(CFAllocatorRef a, CFDataRef d) { return (CFDataRef)[(NSData *)d copy]; }
CFMutableDataRef CFDataCreateMutable(CFAllocatorRef a, CFIndex cap) { return (CFMutableDataRef)[[NSMutableData alloc] initWithCapacity:(NSUInteger)(cap > 0 ? cap : 0)]; }
CFIndex CFDataGetLength(CFDataRef d) { return d ? (CFIndex)[(NSData *)d length] : 0; }
const UInt8 *CFDataGetBytePtr(CFDataRef d) { return d ? [(NSData *)d bytes] : NULL; }
UInt8 *CFDataGetMutableBytePtr(CFMutableDataRef d) { return d ? [(NSMutableData *)d mutableBytes] : NULL; }
void CFDataGetBytes(CFDataRef d, CFRange r, UInt8 *buf) { [(NSData *)d getBytes:buf range:NSMakeRange((NSUInteger)r.location, (NSUInteger)r.length)]; }
void CFDataAppendBytes(CFMutableDataRef d, const UInt8 *bytes, CFIndex len) { if (len > 0) [(NSMutableData *)d appendBytes:bytes length:(NSUInteger)len]; }
void CFDataSetLength(CFMutableDataRef d, CFIndex len) { [(NSMutableData *)d setLength:(NSUInteger)(len > 0 ? len : 0)]; }

const CFArrayCallBacks kCFTypeArrayCallBacks = { 0 };
const CFDictionaryKeyCallBacks kCFTypeDictionaryKeyCallBacks = { 0 };
const CFDictionaryValueCallBacks kCFTypeDictionaryValueCallBacks = { 0 };
CFArrayRef CFArrayCreate(CFAllocatorRef a, const void **values, CFIndex n, const CFArrayCallBacks *cb) {
    return (CFArrayRef)[[NSArray alloc] initWithObjects:(id *)values count:(NSUInteger)(n > 0 ? n : 0)];
}
CFIndex CFArrayGetCount(CFArrayRef a) { return a ? (CFIndex)[(NSArray *)a count] : 0; }
const void *CFArrayGetValueAtIndex(CFArrayRef a, CFIndex i) { return (const void *)[(NSArray *)a objectAtIndex:(NSUInteger)i]; }
CFDictionaryRef CFDictionaryCreate(CFAllocatorRef a, const void **keys, const void **values, CFIndex n, const CFDictionaryKeyCallBacks *kc, const CFDictionaryValueCallBacks *vc) {
    return (CFDictionaryRef)[[NSDictionary alloc] initWithObjects:(id *)values forKeys:(id *)keys count:(NSUInteger)(n > 0 ? n : 0)];
}
CFIndex CFDictionaryGetCount(CFDictionaryRef d) { return d ? (CFIndex)[(NSDictionary *)d count] : 0; }
const void *CFDictionaryGetValue(CFDictionaryRef d, const void *key) { return d && key ? (const void *)[(NSDictionary *)d objectForKey:(id)key] : NULL; }
const CFSetCallBacks kCFTypeSetCallBacks = { 0 };
CFSetRef CFSetCreate(CFAllocatorRef a, const void **values, CFIndex n, const CFSetCallBacks *cb) {
    return (CFSetRef)[[NSSet alloc] initWithObjects:(id *)values count:(NSUInteger)(n > 0 ? n : 0)];
}
CFIndex CFSetGetCount(CFSetRef s) { return s ? (CFIndex)[(NSSet *)s count] : 0; }
Boolean CFSetContainsValue(CFSetRef s, const void *v) { return s && v && [(NSSet *)s containsObject:(id)v]; }
