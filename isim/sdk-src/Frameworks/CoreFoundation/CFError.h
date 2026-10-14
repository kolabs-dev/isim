#pragma once
/* isim SDK CoreFoundation subset: CFError (toll-free bridged to NSError). Self-authored. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
__BEGIN_DECLS
typedef CFStringRef CFErrorDomain;
CF_EXPORT const CFErrorDomain kCFErrorDomainPOSIX;
CF_EXPORT const CFErrorDomain kCFErrorDomainOSStatus;
CF_EXPORT const CFErrorDomain kCFErrorDomainMach;
CF_EXPORT const CFErrorDomain kCFErrorDomainCocoa;
CF_EXPORT const CFStringRef kCFErrorLocalizedDescriptionKey;
CF_EXPORT const CFStringRef kCFErrorLocalizedFailureReasonKey;
CF_EXPORT const CFStringRef kCFErrorLocalizedRecoverySuggestionKey;
CF_EXPORT const CFStringRef kCFErrorDescriptionKey;
CF_EXPORT const CFStringRef kCFErrorUnderlyingErrorKey;
CF_EXPORT const CFStringRef kCFErrorURLKey;
CF_EXPORT const CFStringRef kCFErrorFilePathKey;
CF_EXPORT CFTypeID CFErrorGetTypeID(void);
CF_EXPORT CFErrorRef CFErrorCreate(CFAllocatorRef allocator, CFErrorDomain domain, CFIndex code, CFDictionaryRef userInfo) CF_RETURNS_RETAINED;
CF_EXPORT CFErrorRef CFErrorCreateWithUserInfoKeysAndValues(CFAllocatorRef allocator, CFErrorDomain domain, CFIndex code,
                                                            const void *const *userInfoKeys, const void *const *userInfoValues, CFIndex numUserInfoValues) CF_RETURNS_RETAINED;
CF_EXPORT CFErrorDomain CFErrorGetDomain(CFErrorRef err);
CF_EXPORT CFIndex CFErrorGetCode(CFErrorRef err);
CF_EXPORT CFDictionaryRef CFErrorCopyUserInfo(CFErrorRef err) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFErrorCopyDescription(CFErrorRef err) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFErrorCopyFailureReason(CFErrorRef err) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFErrorCopyRecoverySuggestion(CFErrorRef err) CF_RETURNS_RETAINED;
__END_DECLS
