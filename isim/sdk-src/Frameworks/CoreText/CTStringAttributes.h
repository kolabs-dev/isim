#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
/* the attributes of attributed strings Core Text lays out (the same strings as UIKit's NSAttributedString keys where
 * they overlap). isim: lines are laid out by the host's Pango; strokes are drawn from the glyph outlines. */
CT_EXPORT const CFStringRef kCTFontAttributeName;
/* a CTRunDelegate: each character takes its width, ascent and descent and draws nothing (CTRunDelegate.h) */
CT_EXPORT const CFStringRef kCTRunDelegateAttributeName;
/* a CTRubyAnnotation drawn with the characters (CTRubyAnnotation.h) */
CT_EXPORT const CFStringRef kCTRubyAnnotationAttributeName;
/* a CTGlyphInfo, kept on the run (CTGlyphInfo.h) */
CT_EXPORT const CFStringRef kCTGlyphInfoAttributeName;
CT_EXPORT const CFStringRef kCTForegroundColorFromContextAttributeName;
CT_EXPORT const CFStringRef kCTKernAttributeName;
/* points added between characters, like kern, without turning off ligatures */
CT_EXPORT const CFStringRef kCTTrackingAttributeName API_AVAILABLE(macos(11.0), ios(14.0));
/* 0: only the ligatures the script needs; 1 (default): the standard ones; 2: discretionary ones too */
CT_EXPORT const CFStringRef kCTLigatureAttributeName;
CT_EXPORT const CFStringRef kCTForegroundColorAttributeName;
CT_EXPORT const CFStringRef kCTParagraphStyleAttributeName;
/* percent of the font size: positive strokes the outlines without fill, negative fills and strokes */
CT_EXPORT const CFStringRef kCTStrokeWidthAttributeName;
/* default: the foreground color */
CT_EXPORT const CFStringRef kCTStrokeColorAttributeName;
CT_EXPORT const CFStringRef kCTUnderlineStyleAttributeName;
/* 1 superscript, -1 subscript */
CT_EXPORT const CFStringRef kCTSuperscriptAttributeName;
/* default: the foreground color */
CT_EXPORT const CFStringRef kCTUnderlineColorAttributeName;
/* a BCP 47 language: shaping and font fallback follow it */
CT_EXPORT const CFStringRef kCTLanguageAttributeName;
CT_EXPORT const CFStringRef kCTBaselineOffsetAttributeName;

/* isim: thick underlines and the patterns are drawn as single solid underlines (Pango has neither) */
typedef CF_OPTIONS(int32_t, CTUnderlineStyle) {
    kCTUnderlineStyleNone = 0x00, kCTUnderlineStyleSingle = 0x01, kCTUnderlineStyleThick = 0x02, kCTUnderlineStyleDouble = 0x09
};
typedef CF_OPTIONS(int32_t, CTUnderlineStyleModifiers) {
    kCTUnderlinePatternSolid = 0x0000, kCTUnderlinePatternDot = 0x0100, kCTUnderlinePatternDash = 0x0200,
    kCTUnderlinePatternDashDot = 0x0300, kCTUnderlinePatternDashDotDot = 0x0400
};
#pragma clang assume_nonnull end
__END_DECLS
