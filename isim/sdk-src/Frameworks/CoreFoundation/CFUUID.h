#pragma once
/* isim SDK CoreFoundation subset: CFUUID (a CF type of its own, not bridged to NSUUID, as on iOS). Self-authored. */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
typedef const struct __attribute__((objc_bridge(id))) __CFUUID *CFUUIDRef;
typedef struct {
    UInt8 byte0, byte1, byte2, byte3, byte4, byte5, byte6, byte7, byte8, byte9, byte10, byte11, byte12, byte13, byte14, byte15;
} CFUUIDBytes;
CF_EXPORT CFTypeID CFUUIDGetTypeID(void);
CF_EXPORT CFUUIDRef CFUUIDCreate(CFAllocatorRef alloc) CF_RETURNS_RETAINED;
CF_EXPORT CFUUIDRef CFUUIDCreateWithBytes(CFAllocatorRef alloc, UInt8 byte0, UInt8 byte1, UInt8 byte2, UInt8 byte3, UInt8 byte4, UInt8 byte5,
                                          UInt8 byte6, UInt8 byte7, UInt8 byte8, UInt8 byte9, UInt8 byte10, UInt8 byte11, UInt8 byte12,
                                          UInt8 byte13, UInt8 byte14, UInt8 byte15) CF_RETURNS_RETAINED;
CF_EXPORT CFUUIDRef CFUUIDCreateFromString(CFAllocatorRef alloc, CFStringRef uuidStr) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFUUIDCreateString(CFAllocatorRef alloc, CFUUIDRef uuid) CF_RETURNS_RETAINED;
CF_EXPORT CFUUIDRef CFUUIDCreateFromUUIDBytes(CFAllocatorRef alloc, CFUUIDBytes bytes) CF_RETURNS_RETAINED;
CF_EXPORT CFUUIDBytes CFUUIDGetUUIDBytes(CFUUIDRef uuid);
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
