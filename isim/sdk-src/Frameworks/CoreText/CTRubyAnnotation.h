#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: kCTRubyAnnotationAttributeName ruby is drawn by CTLineDraw / CTFrameDraw over (before) or under (after) its
 * base text, at sizeFactor of the base font, aligned to it; the line's metrics leave no extra room for it */
typedef const struct __attribute__((objc_bridge(id))) __CTRubyAnnotation *CTRubyAnnotationRef;
CT_EXPORT CFTypeID CTRubyAnnotationGetTypeID(void);
typedef CF_ENUM(uint8_t, CTRubyAlignment) {
    kCTRubyAlignmentInvalid = (uint8_t)-1, kCTRubyAlignmentAuto = 0, kCTRubyAlignmentStart = 1, kCTRubyAlignmentCenter = 2,
    kCTRubyAlignmentEnd = 3, kCTRubyAlignmentDistributeLetter = 4, kCTRubyAlignmentDistributeSpace = 5, kCTRubyAlignmentLineEdge = 6
};
typedef CF_ENUM(uint8_t, CTRubyOverhang) {
    kCTRubyOverhangInvalid = (uint8_t)-1, kCTRubyOverhangAuto = 0, kCTRubyOverhangStart = 1, kCTRubyOverhangEnd = 2, kCTRubyOverhangNone = 3
};
typedef CF_ENUM(uint8_t, CTRubyPosition) {
    kCTRubyPositionBefore = 0, kCTRubyPositionAfter = 1, kCTRubyPositionInterCharacter = 2, kCTRubyPositionInline = 3, kCTRubyPositionCount = 4
};
CT_EXPORT const CFStringRef kCTRubyAnnotationSizeFactorAttributeName;
CT_EXPORT const CFStringRef kCTRubyAnnotationScaleToFitAttributeName;
CT_EXPORT CTRubyAnnotationRef CTRubyAnnotationCreate(CTRubyAlignment alignment, CTRubyOverhang overhang, CGFloat sizeFactor,
                                                     CFStringRef _Nullable text[_Nonnull kCTRubyPositionCount]) CF_RETURNS_RETAINED;
CT_EXPORT CTRubyAnnotationRef CTRubyAnnotationCreateWithAttributes(CTRubyAlignment alignment, CTRubyOverhang overhang, CTRubyPosition position,
                                                                   CFStringRef string, CFDictionaryRef attributes) CF_RETURNS_RETAINED;
CT_EXPORT CTRubyAnnotationRef CTRubyAnnotationCreateCopy(CTRubyAnnotationRef rubyAnnotation) CF_RETURNS_RETAINED;
CT_EXPORT CTRubyAlignment CTRubyAnnotationGetAlignment(CTRubyAnnotationRef rubyAnnotation);
CT_EXPORT CTRubyOverhang CTRubyAnnotationGetOverhang(CTRubyAnnotationRef rubyAnnotation);
CT_EXPORT CGFloat CTRubyAnnotationGetSizeFactor(CTRubyAnnotationRef rubyAnnotation);
CT_EXPORT CFStringRef _Nullable CTRubyAnnotationGetTextForPosition(CTRubyAnnotationRef rubyAnnotation, CTRubyPosition position);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
