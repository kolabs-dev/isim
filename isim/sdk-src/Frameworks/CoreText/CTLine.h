#pragma once
#include <CoreText/CTFont.h>
#include <CoreText/CTParagraphStyle.h>
#include <CoreText/CTRun.h>
#include <CoreText/CTStringAttributes.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: lines, runs and frames are laid out by the host's Pango (HarfBuzz shaping); a framesetter lays out each
 * paragraph with its CTParagraphStyle and places the lines itself (alignment, indents, line heights and spacing). */
typedef const struct __attribute__((objc_bridge(id))) __CTLine *CTLineRef;
typedef const struct __attribute__((objc_bridge(id))) __CTFramesetter *CTFramesetterRef;
typedef const struct __attribute__((objc_bridge(id))) __CTFrame *CTFrameRef;
typedef CF_ENUM(uint32_t, CTLineTruncationType) { kCTLineTruncationStart = 0, kCTLineTruncationEnd = 1, kCTLineTruncationMiddle = 2 };
typedef CF_OPTIONS(CFOptionFlags, CTLineBoundsOptions) {
    kCTLineBoundsExcludeTypographicLeading = 1 << 0, kCTLineBoundsExcludeTypographicShifts = 1 << 1, kCTLineBoundsUseHangingPunctuation = 1 << 2,
    kCTLineBoundsUseGlyphPathBounds = 1 << 3, kCTLineBoundsUseOpticalBounds = 1 << 4, kCTLineBoundsIncludeLanguageExtents = 1 << 5
};


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
/* each character's leading and trailing caret offsets, in string order */
CT_EXPORT void CTLineEnumerateCaretOffsets(CTLineRef line, void (^block)(double offset, CFIndex charIndex, bool leadingEdge, bool *stop))
    API_AVAILABLE(macos(10.11), ios(9.0));

/* frame attributes: kept and returned by CTFrameGetFrameAttributes; isim lays out top to bottom in the path's bounding box */
typedef CF_ENUM(uint32_t, CTFrameProgression) { kCTFrameProgressionTopToBottom = 0, kCTFrameProgressionRightToLeft = 1, kCTFrameProgressionLeftToRight = 2 };
typedef CF_ENUM(uint32_t, CTFramePathFillRule) { kCTFramePathFillEvenOdd = 0, kCTFramePathFillWindingNumber = 1 };
CT_EXPORT const CFStringRef kCTFrameProgressionAttributeName;
CT_EXPORT const CFStringRef kCTFramePathFillRuleAttributeName;
CT_EXPORT const CFStringRef kCTFramePathWidthAttributeName;
CT_EXPORT const CFStringRef kCTFrameClippingPathsAttributeName;
CT_EXPORT const CFStringRef kCTFramePathClippingPathAttributeName;
CT_EXPORT CFTypeID CTFramesetterGetTypeID(void);
CT_EXPORT CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef attrString);
CT_EXPORT CTFrameRef CTFramesetterCreateFrame(CTFramesetterRef framesetter, CFRange stringRange, CGPathRef path, CFDictionaryRef _Nullable frameAttributes);
CT_EXPORT CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef framesetter, CFRange stringRange, CFDictionaryRef _Nullable frameAttributes,
                                                              CGSize constraints, CFRange *_Nullable fitRange);
CT_EXPORT CFTypeID CTFrameGetTypeID(void);
CT_EXPORT CFRange CTFrameGetStringRange(CTFrameRef frame);
CT_EXPORT CFRange CTFrameGetVisibleStringRange(CTFrameRef frame);
CT_EXPORT CGPathRef CTFrameGetPath(CTFrameRef frame);
CT_EXPORT CFDictionaryRef _Nullable CTFrameGetFrameAttributes(CTFrameRef frame);
CT_EXPORT CFArrayRef CTFrameGetLines(CTFrameRef frame);
/* origins relative to the lower left of the path's bounding box (y up) */
CT_EXPORT void CTFrameGetLineOrigins(CTFrameRef frame, CFRange range, CGPoint *origins);
CT_EXPORT void CTFrameDraw(CTFrameRef frame, CGContextRef context);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
