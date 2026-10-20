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

/* fonts' tables (CTFontCopyTable) */
typedef uint32_t FourCharCode;                  /* MacTypes */
typedef FourCharCode CTFontTableTag;
enum {
    kCTFontTableBASE = 'BASE', kCTFontTableCFF = 'CFF ', kCTFontTableCFF2 = 'CFF2', kCTFontTableDSIG = 'DSIG',
    kCTFontTableEBDT = 'EBDT', kCTFontTableEBLC = 'EBLC', kCTFontTableEBSC = 'EBSC', kCTFontTableGDEF = 'GDEF',
    kCTFontTableGPOS = 'GPOS', kCTFontTableGSUB = 'GSUB', kCTFontTableJSTF = 'JSTF', kCTFontTableLTSH = 'LTSH',
    kCTFontTableMATH = 'MATH', kCTFontTableOS2 = 'OS/2', kCTFontTablePCLT = 'PCLT', kCTFontTableVDMX = 'VDMX',
    kCTFontTableVORG = 'VORG', kCTFontTableZapf = 'Zapf', kCTFontTableAcnt = 'acnt',
    kCTFontTableAnkr = 'ankr', kCTFontTableAvar = 'avar', kCTFontTableBdat = 'bdat', kCTFontTableBhed = 'bhed',
    kCTFontTableBloc = 'bloc', kCTFontTableBsln = 'bsln', kCTFontTableCidg = 'cidg', kCTFontTableCmap = 'cmap',
    kCTFontTableCvar = 'cvar', kCTFontTableCvt = 'cvt ', kCTFontTableFdsc = 'fdsc', kCTFontTableFeat = 'feat',
    kCTFontTableFmtx = 'fmtx', kCTFontTableFond = 'fond', kCTFontTableFpgm = 'fpgm', kCTFontTableFvar = 'fvar',
    kCTFontTableGasp = 'gasp', kCTFontTableGlyf = 'glyf', kCTFontTableGvar = 'gvar', kCTFontTableHdmx = 'hdmx',
    kCTFontTableHead = 'head', kCTFontTableHhea = 'hhea', kCTFontTableHmtx = 'hmtx', kCTFontTableHsty = 'hsty',
    kCTFontTableJust = 'just', kCTFontTableKern = 'kern', kCTFontTableKerx = 'kerx', kCTFontTableLcar = 'lcar',
    kCTFontTableLtag = 'ltag', kCTFontTableLoca = 'loca', kCTFontTableMaxp = 'maxp', kCTFontTableMeta = 'meta',
    kCTFontTableMort = 'mort', kCTFontTableMorx = 'morx', kCTFontTableName = 'name', kCTFontTableOpbd = 'opbd',
    kCTFontTablePost = 'post', kCTFontTablePrep = 'prep', kCTFontTableProp = 'prop', kCTFontTableSbit = 'sbit',
    kCTFontTableSbix = 'sbix', kCTFontTableTrak = 'trak', kCTFontTableVhea = 'vhea', kCTFontTableVmtx = 'vmtx',
    kCTFontTableXref = 'xref', kCTFontTableCOLR = 'COLR', kCTFontTableCPAL = 'CPAL', kCTFontTableSVG = 'SVG ',
    kCTFontTableCBDT = 'CBDT', kCTFontTableCBLC = 'CBLC', kCTFontTableSTAT = 'STAT', kCTFontTableHVAR = 'HVAR',
    kCTFontTableVVAR = 'VVAR', kCTFontTableMVAR = 'MVAR'
};
typedef CF_OPTIONS(uint32_t, CTFontTableOptions) { kCTFontTableOptionNoOptions = 0, kCTFontTableOptionExcludeSynthetic = (1 << 0) };
/* the bytes of a table of the font's file (HarfBuzz); NULL when it has none */
CT_EXPORT CFDataRef _Nullable CTFontCopyTable(CTFontRef font, CTFontTableTag table, CTFontTableOptions options);
/* the tags of the font's tables (CFNumbers) */
CT_EXPORT CFArrayRef _Nullable CTFontCopyAvailableTables(CTFontRef font, CTFontTableOptions options);

/* variable fonts: the axes of the font's fvar table */
CT_EXPORT const CFStringRef kCTFontVariationAxisIdentifierKey;
CT_EXPORT const CFStringRef kCTFontVariationAxisMinimumValueKey;
CT_EXPORT const CFStringRef kCTFontVariationAxisMaximumValueKey;
CT_EXPORT const CFStringRef kCTFontVariationAxisDefaultValueKey;
CT_EXPORT const CFStringRef kCTFontVariationAxisNameKey;
CT_EXPORT const CFStringRef kCTFontVariationAxisHiddenKey API_AVAILABLE(macos(10.13), ios(11.0));
CT_EXPORT CFArrayRef _Nullable CTFontCopyVariationAxes(CTFontRef font);
/* isim: the axes' default values (isim draws a variable font's default instance) */
CT_EXPORT CFDictionaryRef _Nullable CTFontCopyVariation(CTFontRef font);

/* the font that best renders the start of the string range: the font itself when it has the characters, else the one
 * the host's Pango falls back to */
CT_EXPORT CTFontRef CTFontCreateForString(CTFontRef currentFont, CFStringRef string, CFRange range);
CT_EXPORT CTFontRef CTFontCreateForStringWithLanguage(CTFontRef currentFont, CFStringRef string, CFRange range, CFStringRef _Nullable language)
    API_AVAILABLE(macos(10.15), ios(13.0));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
