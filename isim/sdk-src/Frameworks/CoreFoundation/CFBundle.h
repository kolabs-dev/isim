#pragma once
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
/* isim: a CFBundleRef is the NSBundle of the same bundle (Apple's CFBundle is not toll-free bridged) */
typedef struct __CFBundle *CFBundleRef;
CF_EXPORT const CFStringRef kCFBundleInfoDictionaryVersionKey;
CF_EXPORT const CFStringRef kCFBundleExecutableKey;
CF_EXPORT const CFStringRef kCFBundleIdentifierKey;
CF_EXPORT const CFStringRef kCFBundleVersionKey;
CF_EXPORT const CFStringRef kCFBundleNameKey;
CF_EXPORT const CFStringRef kCFBundleDevelopmentRegionKey;
CF_EXPORT CFBundleRef CFBundleGetMainBundle(void);
CF_EXPORT CFBundleRef CFBundleGetBundleWithIdentifier(CFStringRef bundleID);
CF_EXPORT CFStringRef CFBundleGetIdentifier(CFBundleRef bundle);
CF_EXPORT CFTypeRef CFBundleGetValueForInfoDictionaryKey(CFBundleRef bundle, CFStringRef key);
CF_EXPORT CFDictionaryRef CFBundleGetInfoDictionary(CFBundleRef bundle);
CF_EXPORT UInt32 CFBundleGetVersionNumber(CFBundleRef bundle);
__END_DECLS
