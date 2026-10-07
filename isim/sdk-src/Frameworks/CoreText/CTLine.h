#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
/* isim: lines, runs and frames are laid out by the host's Pango (HarfBuzz shaping). Runs are Pango's glyph items:
 * a run per font and attribute change, glyph ids are HarfBuzz's for the substituted font. */
typedef const struct __attribute__((objc_bridge(id))) __CTLine *CTLineRef;
typedef const struct __attribute__((objc_bridge(id))) __CTRun *CTRunRef;
typedef const struct __attribute__((objc_bridge(id))) __CTFramesetter *CTFramesetterRef;
typedef const struct __attribute__((objc_bridge(id))) __CTFrame *CTFrameRef;
typedef const struct __attribute__((objc_bridge(id))) __CTParagraphStyle *CTParagraphStyleRef;
typedef CF_ENUM(uint32_t, CTLineTruncationType) { kCTLineTruncationStart = 0, kCTLineTruncationEnd = 1, kCTLineTruncationMiddle = 2 };
typedef CF_OPTIONS(CFOptionFlags, CTLineBoundsOptions) {
    kCTLineBoundsExcludeTypographicLeading = 1 << 0, kCTLineBoundsExcludeTypographicShifts = 1 << 1, kCTLineBoundsUseHangingPunctuation = 1 << 2,
    kCTLineBoundsUseGlyphPathBounds = 1 << 3, kCTLineBoundsUseOpticalBounds = 1 << 4, kCTLineBoundsIncludeLanguageExtents = 1 << 5
};
typedef CF_OPTIONS(uint32_t, CTRunStatus) { kCTRunStatusNoStatus = 0, kCTRunStatusRightToLeft = (1 << 0), kCTRunStatusNonMonotonic = (1 << 1), kCTRunStatusHasNonIdentityMatrix = (1 << 2) };
typedef CF_ENUM(uint8_t, CTTextAlignment) { kCTTextAlignmentLeft = 0, kCTTextAlignmentRight = 1, kCTTextAlignmentCenter = 2, kCTTextAlignmentJustified = 3, kCTTextAlignmentNatural = 4 };
typedef CF_ENUM(uint32_t, CTParagraphStyleSpecifier) {
    kCTParagraphStyleSpecifierAlignment = 0, kCTParagraphStyleSpecifierFirstLineHeadIndent = 1, kCTParagraphStyleSpecifierHeadIndent = 2,
    kCTParagraphStyleSpecifierTailIndent = 3, kCTParagraphStyleSpecifierLineBreakMode = 6, kCTParagraphStyleSpecifierLineHeightMultiple = 7,
    kCTParagraphStyleSpecifierParagraphSpacing = 10, kCTParagraphStyleSpecifierParagraphSpacingBefore = 11,
    kCTParagraphStyleSpecifierMaximumLineHeight = 14, kCTParagraphStyleSpecifierMinimumLineHeight = 15,
    kCTParagraphStyleSpecifierLineSpacingAdjustment = 16
};
typedef struct CTParagraphStyleSetting { CTParagraphStyleSpecifier spec; size_t valueSize; const void *value; } CTParagraphStyleSetting;

/* attribute keys (the same strings as UIKit's NSAttributedString keys where they overlap) */
CT_EXPORT const CFStringRef kCTFontAttributeName;
CT_EXPORT const CFStringRef kCTForegroundColorAttributeName;
CT_EXPORT const CFStringRef kCTForegroundColorFromContextAttributeName;
CT_EXPORT const CFStringRef kCTKernAttributeName;
CT_EXPORT const CFStringRef kCTParagraphStyleAttributeName;
CT_EXPORT const CFStringRef kCTUnderlineStyleAttributeName;
CT_EXPORT const CFStringRef kCTStrokeWidthAttributeName;
CT_EXPORT const CFStringRef kCTBaselineOffsetAttributeName;

CT_EXPORT CFTypeID CTParagraphStyleGetTypeID(void);
CT_EXPORT CTParagraphStyleRef CTParagraphStyleCreate(const CTParagraphStyleSetting *_Nullable settings, size_t settingCount);
CT_EXPORT bool CTParagraphStyleGetValueForSpecifier(CTParagraphStyleRef style, CTParagraphStyleSpecifier spec, size_t valueBufferSize, void *valueBuffer);

CT_EXPORT CFTypeID CTLineGetTypeID(void);
CT_EXPORT CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef attrString);
CT_EXPORT CTLineRef _Nullable CTLineCreateTruncatedLine(CTLineRef line, double width, CTLineTruncationType truncationType, CTLineRef _Nullable truncationToken);
CT_EXPORT CTLineRef _Nullable CTLineCreateJustifiedLine(CTLineRef line, CGFloat justificationFactor, double justificationWidth);
CT_EXPORT CFIndex CTLineGetGlyphCount(CTLineRef line);
CT_EXPORT CFArrayRef CTLineGetGlyphRuns(CTLineRef line);
CT_EXPORT CFRange CTLineGetStringRange(CTLineRef line);
CT_EXPORT double CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat flushFactor, double flushWidth);
CT_EXPORT void CTLineDraw(CTLineRef line, CGContextRef context);
CT_EXPORT double CTLineGetTypographicBounds(CTLineRef line, CGFloat *_Nullable ascent, CGFloat *_Nullable descent, CGFloat *_Nullable leading);
CT_EXPORT CGRect CTLineGetBoundsWithOptions(CTLineRef line, CTLineBoundsOptions options);
CT_EXPORT double CTLineGetTrailingWhitespaceWidth(CTLineRef line);
CT_EXPORT CGRect CTLineGetImageBounds(CTLineRef line, CGContextRef _Nullable context);
CT_EXPORT CFIndex CTLineGetStringIndexForPosition(CTLineRef line, CGPoint position);
CT_EXPORT CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex charIndex, CGFloat *_Nullable secondaryOffset);

CT_EXPORT CFTypeID CTRunGetTypeID(void);
CT_EXPORT CFIndex CTRunGetGlyphCount(CTRunRef run);
CT_EXPORT CFDictionaryRef CTRunGetAttributes(CTRunRef run);
CT_EXPORT CTRunStatus CTRunGetStatus(CTRunRef run);
CT_EXPORT const CGGlyph *_Nullable CTRunGetGlyphsPtr(CTRunRef run);
CT_EXPORT void CTRunGetGlyphs(CTRunRef run, CFRange range, CGGlyph *buffer);
CT_EXPORT const CGPoint *_Nullable CTRunGetPositionsPtr(CTRunRef run);
CT_EXPORT void CTRunGetPositions(CTRunRef run, CFRange range, CGPoint *buffer);
CT_EXPORT const CGSize *_Nullable CTRunGetAdvancesPtr(CTRunRef run);
CT_EXPORT void CTRunGetAdvances(CTRunRef run, CFRange range, CGSize *buffer);
CT_EXPORT const CFIndex *_Nullable CTRunGetStringIndicesPtr(CTRunRef run);
CT_EXPORT void CTRunGetStringIndices(CTRunRef run, CFRange range, CFIndex *buffer);
CT_EXPORT CFRange CTRunGetStringRange(CTRunRef run);
CT_EXPORT double CTRunGetTypographicBounds(CTRunRef run, CFRange range, CGFloat *_Nullable ascent, CGFloat *_Nullable descent, CGFloat *_Nullable leading);
CT_EXPORT CGRect CTRunGetImageBounds(CTRunRef run, CGContextRef _Nullable context, CFRange range);
CT_EXPORT CGAffineTransform CTRunGetTextMatrix(CTRunRef run);
CT_EXPORT void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range);

CT_EXPORT CFTypeID CTFramesetterGetTypeID(void);
CT_EXPORT CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef attrString);
CT_EXPORT CTFrameRef CTFramesetterCreateFrame(CTFramesetterRef framesetter, CFRange stringRange, CGPathRef path, CFDictionaryRef _Nullable frameAttributes);
CT_EXPORT CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef framesetter, CFRange stringRange, CFDictionaryRef _Nullable frameAttributes,
                                                              CGSize constraints, CFRange *_Nullable fitRange);
CT_EXPORT CFTypeID CTFrameGetTypeID(void);
CT_EXPORT CFRange CTFrameGetStringRange(CTFrameRef frame);
CT_EXPORT CFRange CTFrameGetVisibleStringRange(CTFrameRef frame);
CT_EXPORT CGPathRef CTFrameGetPath(CTFrameRef frame);
CT_EXPORT CFArrayRef CTFrameGetLines(CTFrameRef frame);
/* origins relative to the lower left of the path's bounding box (y up) */
CT_EXPORT void CTFrameGetLineOrigins(CTFrameRef frame, CFRange range, CGPoint *origins);
CT_EXPORT void CTFrameDraw(CTFrameRef frame, CGContextRef context);
#pragma clang arc_cf_code_audited end
__END_DECLS
