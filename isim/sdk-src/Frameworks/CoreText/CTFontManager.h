#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
typedef CF_ENUM(uint32_t, CTFontManagerScope) {
    kCTFontManagerScopeNone = 0, kCTFontManagerScopeProcess = 1, kCTFontManagerScopePersistent = 2,
    kCTFontManagerScopeSession = 3, kCTFontManagerScopeUser = 2
};
CT_EXPORT const CFStringRef kCTFontManagerErrorDomain;
/* in an error's userInfo: the URLs (CFArray) it is about */
CT_EXPORT const CFStringRef kCTFontManagerErrorFontURLsKey;
typedef CF_ENUM(CFIndex, CTFontManagerError) {
    kCTFontManagerErrorFileNotFound = 101, kCTFontManagerErrorInsufficientPermissions = 102, kCTFontManagerErrorUnrecognizedFormat = 103,
    kCTFontManagerErrorInvalidFontData = 104, kCTFontManagerErrorAlreadyRegistered = 105, kCTFontManagerErrorExceededResourceLimit = 106,
    kCTFontManagerErrorAssetNotFound = 107, kCTFontManagerErrorNotRegistered = 201, kCTFontManagerErrorInUse = 202,
    kCTFontManagerErrorSystemRequired = 203, kCTFontManagerErrorRegistrationFailed = 301, kCTFontManagerErrorMissingEntitlement = 302,
    kCTFontManagerErrorInsufficientInfo = 303, kCTFontManagerErrorCancelledByUser = 304, kCTFontManagerErrorDuplicatedName = 305,
    kCTFontManagerErrorInvalidFilePath = 306, kCTFontManagerErrorUnsupportedScope = 307
};
/* isim: fonts are registered for this process (any scope); fontconfig cannot remove one, so unregistering only
 * forgets it */
CT_EXPORT bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef *error);
CT_EXPORT bool CTFontManagerUnregisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef *error);
/* the faces of font data (a font or a collection); isim makes them usable by name in this process, unlisted */
CT_EXPORT CFArrayRef _Nullable CTFontManagerCreateFontDescriptorsFromData(CFDataRef data) API_AVAILABLE(macos(10.13), ios(13.0));
CT_EXPORT CTFontDescriptorRef _Nullable CTFontManagerCreateFontDescriptorFromData(CFDataRef data);
CT_EXPORT CFArrayRef _Nullable CTFontManagerCreateFontDescriptorsFromURL(CFURLRef fileURL);
/* a CGFont made from data (CGFontCreateWithDataProvider) */
CT_EXPORT bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef _Nullable *_Nullable error);
CT_EXPORT bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef _Nullable *_Nullable error);
/* the handler gets the errors so far and whether all are done; returning false stops (isim calls it once, done) */
CT_EXPORT void CTFontManagerRegisterFontURLs(CFArrayRef fontURLs, CTFontManagerScope scope, bool enabled,
                                             bool (^_Nullable registrationHandler)(CFArrayRef errors, bool done)) API_AVAILABLE(macos(10.15), ios(13.0));
CT_EXPORT void CTFontManagerUnregisterFontURLs(CFArrayRef fontURLs, CTFontManagerScope scope,
                                               bool (^_Nullable registrationHandler)(CFArrayRef errors, bool done)) API_AVAILABLE(macos(10.15), ios(13.0));
#pragma clang arc_cf_code_audited end
__END_DECLS
