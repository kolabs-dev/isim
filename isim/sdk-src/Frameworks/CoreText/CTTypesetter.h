#pragma once
#include <CoreText/CTLine.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: line and cluster breaks are those of a Pango layout of the paragraph at the width (words, or characters when
 * a word does not fit; clusters: grapheme clusters); lines are CTLines of the range */
typedef const struct __attribute__((objc_bridge(id))) __CTTypesetter *CTTypesetterRef;
CT_EXPORT CFTypeID CTTypesetterGetTypeID(void);
CT_EXPORT const CFStringRef kCTTypesetterOptionAllowUnboundedLayout;
CT_EXPORT const CFStringRef kCTTypesetterOptionForcedEmbeddingLevel;
CT_EXPORT CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef string) CF_RETURNS_RETAINED;
CT_EXPORT CTTypesetterRef _Nullable CTTypesetterCreateWithAttributedStringAndOptions(CFAttributedStringRef string, CFDictionaryRef _Nullable options)
    CF_RETURNS_RETAINED;
CT_EXPORT CTLineRef CTTypesetterCreateLineWithOffset(CTTypesetterRef typesetter, CFRange stringRange, double offset) CF_RETURNS_RETAINED;
CT_EXPORT CTLineRef CTTypesetterCreateLine(CTTypesetterRef typesetter, CFRange stringRange) CF_RETURNS_RETAINED;
CT_EXPORT CFIndex CTTypesetterSuggestLineBreakWithOffset(CTTypesetterRef typesetter, CFIndex startIndex, double width, double offset);
CT_EXPORT CFIndex CTTypesetterSuggestLineBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width);
CT_EXPORT CFIndex CTTypesetterSuggestClusterBreakWithOffset(CTTypesetterRef typesetter, CFIndex startIndex, double width, double offset);
CT_EXPORT CFIndex CTTypesetterSuggestClusterBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width);
CT_EXPORT CTFramesetterRef CTFramesetterCreateWithTypesetter(CTTypesetterRef typesetter) CF_RETURNS_RETAINED;
CT_EXPORT CTTypesetterRef CTFramesetterGetTypesetter(CTFramesetterRef framesetter);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
