#pragma once
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFURL.h>
__BEGIN_DECLS
/* audited for ARC like Apple's CF headers: Swift manages Copy / Create results and takes Get results unretained */
CF_IMPLICIT_BRIDGING_ENABLED
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
CF_EXPORT CFTypeID CFBundleGetTypeID(void);
CF_EXPORT CFBundleRef CFBundleCreate(CFAllocatorRef allocator, CFURLRef bundleURL);
CF_EXPORT CFArrayRef CFBundleGetAllBundles(void);
CF_EXPORT CFURLRef CFBundleCopyBundleURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopyResourcesDirectoryURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopyExecutableURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopyBuiltInPlugInsURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopyPrivateFrameworksURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopySharedFrameworksURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopySharedSupportURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopySupportFilesDirectoryURL(CFBundleRef bundle);
CF_EXPORT CFURLRef CFBundleCopyResourceURL(CFBundleRef bundle, CFStringRef resourceName, CFStringRef resourceType, CFStringRef subDirName);
CF_EXPORT CFArrayRef CFBundleCopyResourceURLsOfType(CFBundleRef bundle, CFStringRef resourceType, CFStringRef subDirName);
CF_EXPORT CFURLRef CFBundleCopyResourceURLForLocalization(CFBundleRef bundle, CFStringRef resourceName, CFStringRef resourceType,
                                                         CFStringRef subDirName, CFStringRef localizationName);
CF_EXPORT CFURLRef CFBundleCopyResourceURLInDirectory(CFURLRef bundleURL, CFStringRef resourceName, CFStringRef resourceType, CFStringRef subDirName);
CF_EXPORT CFStringRef CFBundleCopyLocalizedString(CFBundleRef bundle, CFStringRef key, CFStringRef value, CFStringRef tableName);
CF_EXPORT CFStringRef CFBundleGetDevelopmentRegion(CFBundleRef bundle);
CF_EXPORT CFArrayRef CFBundleCopyBundleLocalizations(CFBundleRef bundle);
CF_EXPORT CFArrayRef CFBundleCopyPreferredLocalizationsFromArray(CFArrayRef locArray);
CF_EXPORT CFArrayRef CFBundleCopyLocalizationsForPreferences(CFArrayRef locArray, CFArrayRef prefArray);
CF_EXPORT CFDictionaryRef CFBundleGetLocalInfoDictionary(CFBundleRef bundle);
/* the bundle's executable (dlopen) */
CF_EXPORT Boolean CFBundleIsExecutableLoaded(CFBundleRef bundle);
CF_EXPORT Boolean CFBundleLoadExecutable(CFBundleRef bundle);
CF_EXPORT void *CFBundleGetFunctionPointerForName(CFBundleRef bundle, CFStringRef functionName);
CF_EXPORT void *CFBundleGetDataPointerForName(CFBundleRef bundle, CFStringRef symbolName);
CF_IMPLICIT_BRIDGING_DISABLED

#define CFCopyLocalizedString(key, comment) CFBundleCopyLocalizedString(CFBundleGetMainBundle(), (key), (key), NULL)
#define CFCopyLocalizedStringFromTable(key, tbl, comment) CFBundleCopyLocalizedString(CFBundleGetMainBundle(), (key), (key), (tbl))
#define CFCopyLocalizedStringFromTableInBundle(key, tbl, bundle, comment) CFBundleCopyLocalizedString((bundle), (key), (key), (tbl))
#define CFCopyLocalizedStringWithDefaultValue(key, tbl, bundle, value, comment) CFBundleCopyLocalizedString((bundle), (key), (value), (tbl))
__END_DECLS
