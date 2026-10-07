#pragma once
/* isim SDK CoreFoundation subset: CFData (toll-free bridged to NSData). Self-authored. */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
typedef const struct __attribute__((objc_bridge(NSData))) __CFData *CFDataRef;
typedef struct __attribute__((objc_bridge_mutable(NSMutableData))) __CFData *CFMutableDataRef;
CF_EXPORT CFTypeID CFDataGetTypeID(void);
CF_EXPORT CFDataRef CFDataCreate(CFAllocatorRef allocator, const UInt8 *bytes, CFIndex length) CF_RETURNS_RETAINED;
CF_EXPORT CFDataRef CFDataCreateCopy(CFAllocatorRef allocator, CFDataRef data) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableDataRef CFDataCreateMutable(CFAllocatorRef allocator, CFIndex capacity) CF_RETURNS_RETAINED;
CF_EXPORT CFIndex CFDataGetLength(CFDataRef data);
CF_EXPORT const UInt8 *CFDataGetBytePtr(CFDataRef data);
CF_EXPORT UInt8 *CFDataGetMutableBytePtr(CFMutableDataRef data);
CF_EXPORT void CFDataGetBytes(CFDataRef data, CFRange range, UInt8 *buffer);
CF_EXPORT void CFDataAppendBytes(CFMutableDataRef data, const UInt8 *bytes, CFIndex length);
CF_EXPORT void CFDataSetLength(CFMutableDataRef data, CFIndex length);
__END_DECLS
