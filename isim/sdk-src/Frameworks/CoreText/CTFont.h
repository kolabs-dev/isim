#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CTFontDescriptor.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin      /* like Apple's CF_ASSUME_NONNULL_BEGIN: unannotated pointers are nonnull */
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
/* name keys of CTFontCopyName (the font's name table, as fontconfig reports it) */
CT_EXPORT const CFStringRef kCTFontCopyrightNameKey;
CT_EXPORT const CFStringRef kCTFontFamilyNameKey;
CT_EXPORT const CFStringRef kCTFontSubFamilyNameKey;
CT_EXPORT const CFStringRef kCTFontStyleNameKey;
CT_EXPORT const CFStringRef kCTFontUniqueNameKey;
CT_EXPORT const CFStringRef kCTFontFullNameKey;
CT_EXPORT const CFStringRef kCTFontVersionNameKey;
CT_EXPORT const CFStringRef kCTFontPostScriptNameKey;
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
CT_EXPORT CFStringRef _Nullable CTFontCopyName(CTFontRef font, CFStringRef nameKey);
CT_EXPORT CFStringRef _Nullable CTFontCopyLocalizedName(CTFontRef font, CFStringRef nameKey, CFStringRef _Nullable *_Nullable actualLanguage);
/* The Unicode characters the font has glyphs for. */
CT_EXPORT CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font);
CT_EXPORT CGFloat CTFontGetAscent(CTFontRef font);
CT_EXPORT CGFloat CTFontGetDescent(CTFontRef font);
CT_EXPORT CGFloat CTFontGetLeading(CTFontRef font);
CT_EXPORT CGFloat CTFontGetCapHeight(CTFontRef font);
CT_EXPORT CGFloat CTFontGetXHeight(CTFontRef font);
CT_EXPORT unsigned CTFontGetUnitsPerEm(CTFontRef font);
CT_EXPORT CFIndex CTFontGetGlyphCount(CTFontRef font);
CT_EXPORT CGRect CTFontGetBoundingBox(CTFontRef font);
CT_EXPORT CGFloat CTFontGetUnderlinePosition(CTFontRef font);
CT_EXPORT CGFloat CTFontGetUnderlineThickness(CTFontRef font);
CT_EXPORT CGFloat CTFontGetSlantAngle(CTFontRef font);
/* metrics, glyphs, advances, bounds and outlines are read from the font file the host's fontconfig picks for the font
 * (HarfBuzz); glyph ids are that font's, the same ids CTRun reports */
CT_EXPORT bool CTFontGetGlyphsForCharacters(CTFontRef font, const UniChar *characters, CGGlyph *glyphs, CFIndex count);
CT_EXPORT double CTFontGetAdvancesForGlyphs(CTFontRef font, CTFontOrientation orientation, const CGGlyph *glyphs, CGSize *_Nullable advances, CFIndex count);
CT_EXPORT CGRect CTFontGetBoundingRectsForGlyphs(CTFontRef font, CTFontOrientation orientation, const CGGlyph *glyphs, CGRect *_Nullable boundingRects, CFIndex count);
CT_EXPORT CGPathRef _Nullable CTFontCreatePathForGlyph(CTFontRef font, CGGlyph glyph, const CGAffineTransform *_Nullable matrix);
/* draws glyphs at positions in text space (the context's text matrix applies) with the context's fill color */
CT_EXPORT void CTFontDrawGlyphs(CTFontRef font, const CGGlyph *glyphs, const CGPoint *positions, size_t count, CGContextRef context);
CT_EXPORT CGFontRef CTFontCopyGraphicsFont(CTFontRef font, CTFontDescriptorRef _Nullable *_Nullable attributes);
CT_EXPORT CTFontRef CTFontCreateWithGraphicsFont(CGFontRef graphicsFont, CGFloat size, const CGAffineTransform *_Nullable matrix, CTFontDescriptorRef _Nullable attributes);
CT_EXPORT CFArrayRef _Nullable CTFontCopyFeatures(CTFontRef font);
CT_EXPORT CFArrayRef _Nullable CTFontCopyFeatureSettings(CTFontRef font);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
