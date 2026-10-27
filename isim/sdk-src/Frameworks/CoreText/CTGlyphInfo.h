#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: glyph infos are created and read back; laying out text does not substitute their glyphs (kCTGlyphInfoAttributeName
 * is kept on the runs) */
typedef const struct __attribute__((objc_bridge(id))) __CTGlyphInfo *CTGlyphInfoRef;
CT_EXPORT CFTypeID CTGlyphInfoGetTypeID(void);
typedef CF_ENUM(uint16_t, CTCharacterCollection) {
    kCTCharacterCollectionIdentityMapping = 0, kCTCharacterCollectionAdobeCNS1 = 1, kCTCharacterCollectionAdobeGB1 = 2,
    kCTCharacterCollectionAdobeJapan1 = 3, kCTCharacterCollectionAdobeJapan2 = 4, kCTCharacterCollectionAdobeKorea1 = 5
};
CT_EXPORT CTGlyphInfoRef _Nullable CTGlyphInfoCreateWithGlyphName(CFStringRef glyphName, CTFontRef font, CFStringRef baseString) CF_RETURNS_RETAINED;
CT_EXPORT CTGlyphInfoRef _Nullable CTGlyphInfoCreateWithGlyph(CGGlyph glyph, CTFontRef font, CFStringRef baseString) CF_RETURNS_RETAINED;
CT_EXPORT CTGlyphInfoRef _Nullable CTGlyphInfoCreateWithCharacterIdentifier(CGFontIndex cid, CTCharacterCollection collection, CFStringRef baseString)
    CF_RETURNS_RETAINED;
CT_EXPORT CFStringRef _Nullable CTGlyphInfoGetGlyphName(CTGlyphInfoRef glyphInfo);
CT_EXPORT CGGlyph CTGlyphInfoGetGlyph(CTGlyphInfoRef glyphInfo);
CT_EXPORT CGFontIndex CTGlyphInfoGetCharacterIdentifier(CTGlyphInfoRef glyphInfo);
CT_EXPORT CTCharacterCollection CTGlyphInfoGetCharacterCollection(CTGlyphInfoRef glyphInfo);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
