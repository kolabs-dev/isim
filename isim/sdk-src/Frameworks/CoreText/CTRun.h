#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: runs are Pango's glyph items, one per font, direction and attribute change, in string order. Glyph ids are
 * the HarfBuzz ids of the font Pango used (the requested font, or a fallback for characters it lacks; the run's
 * kCTFontAttributeName is that font); positions are from the line's origin, y-up; string indices are UTF-16. */
typedef const struct __attribute__((objc_bridge(id))) __CTRun *CTRunRef;
typedef CF_OPTIONS(uint32_t, CTRunStatus) { kCTRunStatusNoStatus = 0, kCTRunStatusRightToLeft = (1 << 0), kCTRunStatusNonMonotonic = (1 << 1), kCTRunStatusHasNonIdentityMatrix = (1 << 2) };
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
/* advances before positioning and the glyphs' offsets from their pen positions (marks, kerning adjustments) */
CT_EXPORT void CTRunGetBaseAdvancesAndOrigins(CTRunRef runRef, CFRange range, CGSize *_Nullable advancesBuffer, CGPoint *_Nullable originsBuffer);
CT_EXPORT double CTRunGetTypographicBounds(CTRunRef run, CFRange range, CGFloat *_Nullable ascent, CGFloat *_Nullable descent, CGFloat *_Nullable leading);
CT_EXPORT CGRect CTRunGetImageBounds(CTRunRef run, CGContextRef _Nullable context, CFRange range);
CT_EXPORT CGAffineTransform CTRunGetTextMatrix(CTRunRef run);
/* draws the glyphs of the range at the context's text position */
CT_EXPORT void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
