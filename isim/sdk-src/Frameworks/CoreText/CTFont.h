#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
typedef const struct __attribute__((objc_bridge(id))) __CTFont *CTFontRef;
#ifndef CT_EXPORT
#define CT_EXPORT extern __attribute__((visibility("default")))
#endif
CT_EXPORT CFTypeID CTFontGetTypeID(void);
/* A font by PostScript or family name; unknown names give the system font (as on iOS). */
CT_EXPORT CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix);
CT_EXPORT CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, const void *attributes);
CT_EXPORT CGFloat CTFontGetSize(CTFontRef font);
CT_EXPORT CFStringRef CTFontCopyPostScriptName(CTFontRef font);
CT_EXPORT CFStringRef CTFontCopyFamilyName(CTFontRef font);
CT_EXPORT CFStringRef CTFontCopyFullName(CTFontRef font);
CT_EXPORT CFStringRef CTFontCopyDisplayName(CTFontRef font);
/* The Unicode characters the font has glyphs for. */
CT_EXPORT CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font);
CT_EXPORT CGFloat CTFontGetAscent(CTFontRef font);
CT_EXPORT CGFloat CTFontGetDescent(CTFontRef font);
CT_EXPORT CGFloat CTFontGetLeading(CTFontRef font);
CT_EXPORT CGFloat CTFontGetCapHeight(CTFontRef font);
CT_EXPORT CGFloat CTFontGetXHeight(CTFontRef font);
#pragma clang arc_cf_code_audited end
__END_DECLS
