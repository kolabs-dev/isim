#pragma once
#include <CoreGraphics/CGBase.h>
#include <CoreGraphics/CGDataProvider.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: a CGFont is a font name resolved by the host's fontconfig when text is drawn, or a font file's data; its tables
 * come from that file */
typedef struct CGFont *CGFontRef;
typedef unsigned short CGGlyph;
typedef unsigned short CGFontIndex;
enum : CGFontIndex { kCGFontIndexMax = ((1 << 16) - 2), kCGFontIndexInvalid = ((1 << 16) - 1), kCGGlyphMax = kCGFontIndexMax };
CG_EXTERN CFTypeID CGFontGetTypeID(void);
CG_EXTERN CGFontRef _Nullable CGFontCreateWithFontName(CFStringRef _Nullable name) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGFont.init(_:));
CG_EXTERN CGFontRef _Nullable CGFontCreateWithDataProvider(CGDataProviderRef provider) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGFont.init(_:));
CG_EXTERN CGFontRef _Nullable CGFontRetain(CGFontRef _Nullable font);
CG_EXTERN void CGFontRelease(CGFontRef _Nullable font);
CG_EXTERN CFStringRef _Nullable CGFontCopyPostScriptName(CGFontRef _Nullable font) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGFont.postScriptName(self:));
CG_EXTERN CFStringRef _Nullable CGFontCopyFullName(CGFontRef _Nullable font) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGFont.fullName(self:));
CG_EXTERN int CGFontGetUnitsPerEm(CGFontRef _Nullable font) CG_SWIFT_NAME(getter:CGFont.unitsPerEm(self:));
/* the tags (uint32_t values, not CFNumbers) of the font's tables, and one table's bytes */
CG_EXTERN CFArrayRef _Nullable CGFontCopyTableTags(CGFontRef _Nullable font) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGFont.tableTags(self:));
CG_EXTERN CFDataRef _Nullable CGFontCopyTableForTag(CGFontRef _Nullable font, uint32_t tag) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGFont.table(self:for:));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
