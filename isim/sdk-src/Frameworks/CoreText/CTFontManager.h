#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
typedef CF_ENUM(uint32_t, CTFontManagerScope) {
    kCTFontManagerScopeNone = 0, kCTFontManagerScopeProcess = 1, kCTFontManagerScopePersistent = 2,
    kCTFontManagerScopeSession = 3, kCTFontManagerScopeUser = 2
};
/* isim: fonts are registered for this process (any scope). */
CT_EXPORT bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef *error);
CT_EXPORT bool CTFontManagerUnregisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef *error);
#pragma clang arc_cf_code_audited end
__END_DECLS
