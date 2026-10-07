#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CTFontDescriptor.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
typedef const struct __attribute__((objc_bridge(id))) __CTFont *CTFontRef;
#ifndef CT_EXPORT
#define CT_EXPORT extern __attribute__((visibility("default")))
#endif
typedef CF_ENUM(uint32_t, CTFontUIFontType) {
    kCTFontUIFontNone = (uint32_t)-1, kCTFontUIFontUser = 0, kCTFontUIFontUserFixedPitch = 1, kCTFontUIFontSystem = 2,
    kCTFontUIFontEmphasizedSystem = 3, kCTFontUIFontSmallSystem = 4, kCTFontUIFontSmallEmphasizedSystem = 5,
    kCTFontUIFontMiniSystem = 6, kCTFontUIFontMiniEmphasizedSystem = 7, kCTFontUIFontLabel = 10
};
CT_EXPORT CFTypeID CTFontGetTypeID(void);
/* A font by PostScript or family name; unknown names give the system font (as on iOS). Names of iOS fonts that are
 * not on the host (Helvetica-Bold, Avenir-Heavy, ...) keep their weight/slant on the substitute. */
CT_EXPORT CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *_Nullable matrix);
CT_EXPORT CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size, const CGAffineTransform *_Nullable matrix);
CT_EXPORT CTFontRef _Nullable CTFontCreateUIFontForLanguage(CTFontUIFontType uiType, CGFloat size, CFStringRef _Nullable language);
CT_EXPORT CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size, const CGAffineTransform *_Nullable matrix, CTFontDescriptorRef _Nullable attributes);
CT_EXPORT CTFontRef _Nullable CTFontCreateCopyWithSymbolicTraits(CTFontRef font, CGFloat size, const CGAffineTransform *_Nullable matrix,
                                                                  CTFontSymbolicTraits symTraitValue, CTFontSymbolicTraits symTraitMask);
CT_EXPORT CTFontDescriptorRef CTFontCopyFontDescriptor(CTFontRef font);
CT_EXPORT CFTypeRef _Nullable CTFontCopyAttribute(CTFontRef font, CFStringRef attribute);
CT_EXPORT CTFontSymbolicTraits CTFontGetSymbolicTraits(CTFontRef font);
CT_EXPORT CFDictionaryRef CTFontCopyTraits(CTFontRef font);
CT_EXPORT CGFloat CTFontGetSize(CTFontRef font);
CT_EXPORT CGAffineTransform CTFontGetMatrix(CTFontRef font);
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
CT_EXPORT unsigned CTFontGetUnitsPerEm(CTFontRef font);
CT_EXPORT CGRect CTFontGetBoundingBox(CTFontRef font);
CT_EXPORT CGFloat CTFontGetUnderlinePosition(CTFontRef font);
CT_EXPORT CGFloat CTFontGetUnderlineThickness(CTFontRef font);
CT_EXPORT CGFloat CTFontGetSlantAngle(CTFontRef font);
/* glyphs are the host shaper's (HarfBuzz) glyph ids for this font */
CT_EXPORT bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *characters, CGGlyph *glyphs, CFIndex count);
CT_EXPORT double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation orientation, const CGGlyph *glyphs, CGSize *_Nullable advances, CFIndex count);
CT_EXPORT CGFontRef CTFontCopyGraphicsFont(CTFontRef font, CTFontDescriptorRef _Nullable *_Nullable attributes);
CT_EXPORT CTFontRef CTFontCreateWithGraphicsFont(CGFontRef graphicsFont, CGFloat size, const CGAffineTransform *_Nullable matrix, CTFontDescriptorRef _Nullable attributes);
CT_EXPORT CFArrayRef _Nullable CTFontCopyFeatures(CTFontRef font);
CT_EXPORT CFArrayRef _Nullable CTFontCopyFeatureSettings(CTFontRef font);
#pragma clang arc_cf_code_audited end
__END_DECLS
