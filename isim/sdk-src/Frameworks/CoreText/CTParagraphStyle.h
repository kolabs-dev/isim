#pragma once
#include <CoreText/CTTextTab.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: every setting is kept and read back; CTFramesetter lays each paragraph out with its style (alignment, indents,
 * tab stops, line break mode, line heights and spacing, paragraph spacing, writing direction). CTLine uses the tab
 * stops and the writing direction. */
typedef const struct __attribute__((objc_bridge(id))) __CTParagraphStyle *CTParagraphStyleRef;
typedef CF_ENUM(uint8_t, CTLineBreakMode) {
    kCTLineBreakByWordWrapping = 0, kCTLineBreakByCharWrapping = 1, kCTLineBreakByClipping = 2,
    kCTLineBreakByTruncatingHead = 3, kCTLineBreakByTruncatingTail = 4, kCTLineBreakByTruncatingMiddle = 5
};
typedef CF_ENUM(int8_t, CTWritingDirection) { kCTWritingDirectionNatural = -1, kCTWritingDirectionLeftToRight = 0, kCTWritingDirectionRightToLeft = 1 };
typedef CF_ENUM(uint32_t, CTParagraphStyleSpecifier) {
    kCTParagraphStyleSpecifierAlignment = 0, kCTParagraphStyleSpecifierFirstLineHeadIndent = 1, kCTParagraphStyleSpecifierHeadIndent = 2,
    kCTParagraphStyleSpecifierTailIndent = 3, kCTParagraphStyleSpecifierTabStops = 4, kCTParagraphStyleSpecifierDefaultTabInterval = 5,
    kCTParagraphStyleSpecifierLineBreakMode = 6, kCTParagraphStyleSpecifierLineHeightMultiple = 7,
    kCTParagraphStyleSpecifierMaximumLineHeight = 8, kCTParagraphStyleSpecifierMinimumLineHeight = 9,
    kCTParagraphStyleSpecifierLineSpacing = 10,         /* deprecated: sets the minimum and maximum line spacing */
    kCTParagraphStyleSpecifierParagraphSpacing = 11, kCTParagraphStyleSpecifierParagraphSpacingBefore = 12,
    kCTParagraphStyleSpecifierBaseWritingDirection = 13, kCTParagraphStyleSpecifierMaximumLineSpacing = 14,
    kCTParagraphStyleSpecifierMinimumLineSpacing = 15, kCTParagraphStyleSpecifierLineSpacingAdjustment = 16,
    kCTParagraphStyleSpecifierLineBoundsOptions = 17, kCTParagraphStyleSpecifierCount
};
typedef struct CTParagraphStyleSetting { CTParagraphStyleSpecifier spec; size_t valueSize; const void *value; } CTParagraphStyleSetting;
CT_EXPORT CFTypeID CTParagraphStyleGetTypeID(void);
CT_EXPORT CTParagraphStyleRef CTParagraphStyleCreate(const CTParagraphStyleSetting *_Nullable settings, size_t settingCount);
CT_EXPORT CTParagraphStyleRef CTParagraphStyleCreateCopy(CTParagraphStyleRef paragraphStyle);
/* tab stops come back as a CFArray of CTTextTab (not retained) */
CT_EXPORT bool CTParagraphStyleGetValueForSpecifier(CTParagraphStyleRef paragraphStyle, CTParagraphStyleSpecifier spec, size_t valueBufferSize, void *valueBuffer);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
