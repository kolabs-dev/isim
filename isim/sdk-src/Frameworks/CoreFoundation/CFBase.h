#pragma once
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
__BEGIN_DECLS
#define CF_EXPORT extern __attribute__((visibility("default")))
#define CF_INLINE static inline
#ifndef CF_ENUM
#define CF_ENUM(_type, _name) enum __attribute__((enum_extensibility(open))) _name : _type _name; enum _name : _type
#define CF_OPTIONS(_type, _name) enum __attribute__((flag_enum, enum_extensibility(open))) _name : _type _name; enum _name : _type
#endif
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#define CF_IMPLICIT_BRIDGING_ENABLED
#define CF_IMPLICIT_BRIDGING_DISABLED
typedef unsigned char Boolean;
typedef unsigned char UInt8;
typedef unsigned short UInt16;
typedef UInt16 UniChar;
typedef signed long CFIndex;
typedef unsigned long CFTypeID;
typedef unsigned long CFOptionFlags;
typedef unsigned long CFHashCode;
typedef const void *CFTypeRef;
/* toll-free bridged to the Foundation classes, as on Apple platforms */
typedef const struct __attribute__((objc_bridge(NSString))) __CFString *CFStringRef;
typedef struct __attribute__((objc_bridge_mutable(NSMutableString))) __CFString *CFMutableStringRef;
typedef const struct __attribute__((objc_bridge(NSCharacterSet))) __CFCharacterSet *CFCharacterSetRef;
typedef const struct __attribute__((objc_bridge(NSURL))) __CFURL *CFURLRef;
typedef const struct __CFAllocator *CFAllocatorRef;
typedef const struct __attribute__((objc_bridge(NSDictionary))) __CFDictionary *CFDictionaryRef;
typedef const struct __attribute__((objc_bridge(NSArray))) __CFArray *CFArrayRef;
typedef struct __attribute__((objc_bridge(NSError))) __CFError *CFErrorRef;
typedef const struct __attribute__((objc_bridge(NSAttributedString))) __CFAttributedString *CFAttributedStringRef;
typedef struct __attribute__((objc_bridge_mutable(NSMutableAttributedString))) __CFAttributedString *CFMutableAttributedStringRef;
typedef uint32_t CFStringEncoding;
typedef struct { CFIndex location; CFIndex length; } CFRange;
CF_INLINE CFRange CFRangeMake(CFIndex loc, CFIndex len) { CFRange r = { loc, len }; return r; }
typedef CF_ENUM(CFIndex, CFComparisonResult) { kCFCompareLessThan = -1L, kCFCompareEqualTo = 0, kCFCompareGreaterThan = 1 };
#define kCFNotFound ((CFIndex)-1)
#ifndef CFSTR
#define CFSTR(cStr) ((CFStringRef)__builtin___CFStringMakeConstantString("" cStr ""))
#endif
CF_EXPORT CFTypeID CFGetTypeID(CFTypeRef cf);
CF_EXPORT CFTypeRef CFRetain(CFTypeRef cf);
CF_EXPORT void CFRelease(CFTypeRef cf);
CF_EXPORT CFTypeRef CFAutorelease(CFTypeRef cf);
CF_EXPORT CFIndex CFGetRetainCount(CFTypeRef cf);
CF_EXPORT Boolean CFEqual(CFTypeRef a, CFTypeRef b);
CF_EXPORT CFHashCode CFHash(CFTypeRef cf);
CF_EXPORT CFTypeID CFStringGetTypeID(void);
CF_EXPORT CFIndex CFStringGetLength(CFStringRef s);
CF_EXPORT CFHashCode CFStringHashNSString(CFStringRef s);
CF_EXPORT CFHashCode CFStringHashCString(const uint8_t *bytes, CFIndex len);
__END_DECLS
