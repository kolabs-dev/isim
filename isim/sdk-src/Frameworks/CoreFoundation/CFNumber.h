#pragma once
/* isim SDK CoreFoundation subset: CFBoolean (toll-free bridged to NSNumber). Self-authored. */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
typedef const struct __attribute__((objc_bridge(NSNumber))) __CFBoolean *CFBooleanRef;
typedef const struct __attribute__((objc_bridge(NSNumber))) __CFNumber *CFNumberRef;
CF_EXPORT const CFBooleanRef kCFBooleanTrue;
CF_EXPORT const CFBooleanRef kCFBooleanFalse;
CF_EXPORT Boolean CFBooleanGetValue(CFBooleanRef boolean);
CF_EXPORT CFTypeID CFBooleanGetTypeID(void);
typedef CF_ENUM(CFIndex, CFNumberType) {
    kCFNumberSInt8Type = 1, kCFNumberSInt16Type = 2, kCFNumberSInt32Type = 3, kCFNumberSInt64Type = 4,
    kCFNumberFloat32Type = 5, kCFNumberFloat64Type = 6, kCFNumberCharType = 7, kCFNumberShortType = 8,
    kCFNumberIntType = 9, kCFNumberLongType = 10, kCFNumberLongLongType = 11, kCFNumberFloatType = 12,
    kCFNumberDoubleType = 13, kCFNumberCFIndexType = 14, kCFNumberNSIntegerType = 15, kCFNumberCGFloatType = 16,
    kCFNumberMaxType = 16
};
CF_EXPORT CFTypeID CFNumberGetTypeID(void);
CF_EXPORT CFNumberRef CFNumberCreate(CFAllocatorRef allocator, CFNumberType theType, const void *valuePtr) CF_RETURNS_RETAINED;
CF_EXPORT CFNumberType CFNumberGetType(CFNumberRef number);
CF_EXPORT CFIndex CFNumberGetByteSize(CFNumberRef number);
CF_EXPORT Boolean CFNumberIsFloatType(CFNumberRef number);
/* true when the value fits the type exactly (else the value is converted, like CF) */
CF_EXPORT Boolean CFNumberGetValue(CFNumberRef number, CFNumberType theType, void *valuePtr);
CF_EXPORT CFComparisonResult CFNumberCompare(CFNumberRef number, CFNumberRef otherNumber, void *context);
CF_EXPORT const CFNumberRef kCFNumberPositiveInfinity;
CF_EXPORT const CFNumberRef kCFNumberNegativeInfinity;
CF_EXPORT const CFNumberRef kCFNumberNaN;
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
