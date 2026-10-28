#pragma once
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
__BEGIN_DECLS
#if defined(__cplusplus)
#define CF_EXPORT extern "C" __attribute__((visibility("default")))
#else
#define CF_EXPORT extern __attribute__((visibility("default")))
#endif
#define CF_INLINE static inline
#if defined(__cplusplus)
#define CF_EXTERN_C_BEGIN extern "C" {
#define CF_EXTERN_C_END }
#else
#define CF_EXTERN_C_BEGIN
#define CF_EXTERN_C_END
#endif
#define CF_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define CF_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#ifndef CF_ENUM
#define CF_ENUM(_type, _name) enum __attribute__((enum_extensibility(open))) _name : _type _name; enum _name : _type
#if defined(__cplusplus)   /* like Apple's: in C++ the options are an integer typedef, so a | b stays that type */
#define CF_OPTIONS(_type, _name) __attribute__((availability(swift, unavailable))) _type _name; enum __attribute__((flag_enum, enum_extensibility(open))) : _name
#else
#define CF_OPTIONS(_type, _name) enum __attribute__((flag_enum, enum_extensibility(open))) _name : _type _name; enum _name : _type
#endif
#endif
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#define CF_RETURNS_NOT_RETAINED __attribute__((cf_returns_not_retained))
/* like Apple's: declarations between these are audited for ARC, so Swift manages the CF objects they return (Create /
   Copy results retained, others not) instead of handing out Unmanaged */
#define CF_IMPLICIT_BRIDGING_ENABLED _Pragma("clang arc_cf_code_audited begin")
#define CF_IMPLICIT_BRIDGING_DISABLED _Pragma("clang arc_cf_code_audited end")
typedef unsigned char Boolean;
typedef unsigned char UInt8;
typedef unsigned short UInt16;
typedef unsigned int UInt32;
typedef signed int SInt32;
typedef UInt16 UniChar;
typedef signed long CFIndex;
typedef unsigned long CFTypeID;
typedef unsigned long CFOptionFlags;
typedef unsigned long CFHashCode;
typedef const void *CFTypeRef;
typedef CFTypeRef CFPropertyListRef;
/* toll-free bridged to the Foundation classes, as on Apple platforms */
typedef const struct __attribute__((objc_bridge(NSString))) __CFString *CFStringRef;
typedef struct __attribute__((objc_bridge_mutable(NSMutableString))) __CFString *CFMutableStringRef;
typedef const struct __attribute__((objc_bridge(NSCharacterSet))) __CFCharacterSet *CFCharacterSetRef;
typedef const struct __attribute__((objc_bridge(NSURL))) __CFURL *CFURLRef;
typedef const struct __CFAllocator *CFAllocatorRef;
typedef const struct __attribute__((objc_bridge(NSDictionary))) __CFDictionary *CFDictionaryRef;
typedef const struct __attribute__((objc_bridge(NSArray))) __CFArray *CFArrayRef;
typedef const struct __attribute__((objc_bridge(NSSet))) __CFSet *CFSetRef;
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
CF_IMPLICIT_BRIDGING_ENABLED
CF_EXPORT CFTypeID CFGetTypeID(CFTypeRef cf);
CF_EXPORT CFTypeRef CFRetain(CFTypeRef cf);
CF_EXPORT void CFRelease(CFTypeRef cf);
CF_EXPORT CFTypeRef CFAutorelease(CFTypeRef cf);
CF_EXPORT CFIndex CFGetRetainCount(CFTypeRef cf);
CF_EXPORT Boolean CFEqual(CFTypeRef a, CFTypeRef b);
CF_EXPORT CFHashCode CFHash(CFTypeRef cf);
CF_EXPORT CFStringRef CFCopyDescription(CFTypeRef cf) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFCopyTypeIDDescription(CFTypeID type_id) CF_RETURNS_RETAINED;
/* the CoreFoundation version: isim's value for the iOS version it emulates (adapted: increases with the iOS version,
   above every kCFCoreFoundationVersionNumber_iOS_* constant; not Apple's exact build number) */
CF_EXPORT double kCFCoreFoundationVersionNumber;
#define kCFCoreFoundationVersionNumber_iOS_9_0 1240.1
#define kCFCoreFoundationVersionNumber_iOS_10_0 1348.0
#define kCFCoreFoundationVersionNumber_iOS_11_0 1443.0
#define kCFCoreFoundationVersionNumber_iOS_12_0 1556.0
CF_EXPORT CFTypeID CFStringGetTypeID(void);
CF_EXPORT CFIndex CFStringGetLength(CFStringRef s);
CF_EXPORT CFHashCode CFStringHashNSString(CFStringRef s);
CF_EXPORT CFHashCode CFStringHashCString(const uint8_t *bytes, CFIndex len);
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
