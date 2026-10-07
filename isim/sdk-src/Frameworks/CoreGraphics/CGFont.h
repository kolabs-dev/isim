#pragma once
#include <CoreGraphics/CGBase.h>
#include <CoreGraphics/CGDataProvider.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: a CGFont is a font name resolved by the host's fontconfig when text is drawn (no glyph tables) */
typedef struct CGFont *CGFontRef;
typedef unsigned short CGGlyph;
CG_EXTERN CFTypeID CGFontGetTypeID(void);
CG_EXTERN CGFontRef _Nullable CGFontCreateWithFontName(CFStringRef _Nullable name) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGFont.init(_:));
CG_EXTERN CGFontRef _Nullable CGFontCreateWithDataProvider(CGDataProviderRef provider) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGFont.init(_:));
CG_EXTERN CGFontRef _Nullable CGFontRetain(CGFontRef _Nullable font);
CG_EXTERN void CGFontRelease(CGFontRef _Nullable font);
CG_EXTERN CFStringRef _Nullable CGFontCopyPostScriptName(CGFontRef _Nullable font) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGFont.postScriptName(self:));
CG_EXTERN CFStringRef _Nullable CGFontCopyFullName(CGFontRef _Nullable font) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGFont.fullName(self:));
CG_EXTERN int CGFontGetUnitsPerEm(CGFontRef _Nullable font) CG_SWIFT_NAME(getter:CGFont.unitsPerEm(self:));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
