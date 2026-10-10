#pragma once
#include <CoreText/CTFont.h>
#include <CoreText/CTParagraphStyle.h>
#include <CoreText/CTRun.h>
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

/* attribute keys (the same strings as UIKit's NSAttributedString keys where they overlap) */
CT_EXPORT const CFStringRef kCTFontAttributeName;
CT_EXPORT const CFStringRef kCTForegroundColorAttributeName;
CT_EXPORT const CFStringRef kCTForegroundColorFromContextAttributeName;
CT_EXPORT const CFStringRef kCTKernAttributeName;
CT_EXPORT const CFStringRef kCTParagraphStyleAttributeName;
CT_EXPORT const CFStringRef kCTUnderlineStyleAttributeName;
CT_EXPORT const CFStringRef kCTStrokeWidthAttributeName;
CT_EXPORT const CFStringRef kCTBaselineOffsetAttributeName;


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
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
