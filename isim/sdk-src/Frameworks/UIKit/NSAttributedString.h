#pragma once
/* isim: UIKit's attributed-string keys, paragraph styles, shadows and string drawing. Text renders through the
   host's Pango (fonts, colours, kerning, underline/strikethrough, baseline offset, alignment, line spacing). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UILabel.h>
#include <CoreGraphics/CGGeometry.h>
#include <CoreText/CTTextTab.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFont, UIColor, NSTextBlock;
UIKIT_EXTERN NSAttributedStringKey const NSFontAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSParagraphStyleAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSForegroundColorAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSBackgroundColorAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSLigatureAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSKernAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSTrackingAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSStrikethroughStyleAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSUnderlineStyleAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSStrokeColorAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSStrokeWidthAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSShadowAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSAttachmentAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSLinkAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSBaselineOffsetAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSUnderlineColorAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSStrikethroughColorAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSObliquenessAttributeName;
UIKIT_EXTERN NSAttributedStringKey const NSExpansionAttributeName;
/* text highlights (iOS 18): text views draw a rounded background behind the range, in the colour scheme's colour */
UIKIT_EXTERN NSAttributedStringKey const NSTextHighlightStyleAttributeName API_AVAILABLE(ios(18.0));
UIKIT_EXTERN NSAttributedStringKey const NSTextHighlightColorSchemeAttributeName API_AVAILABLE(ios(18.0));
typedef NSString *NSAttributedStringTextHighlightStyle NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSAttributedString.TextHighlightStyle) API_AVAILABLE(ios(18.0));
typedef NSString *NSAttributedStringTextHighlightColorScheme NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSAttributedString.TextHighlightColorScheme) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN NSAttributedStringTextHighlightStyle const NSTextHighlightStyleDefault API_AVAILABLE(ios(18.0));
UIKIT_EXTERN NSAttributedStringTextHighlightColorScheme const NSTextHighlightColorSchemeDefault, NSTextHighlightColorSchemePurple, NSTextHighlightColorSchemePink,
    NSTextHighlightColorSchemeOrange, NSTextHighlightColorSchemeMint, NSTextHighlightColorSchemeBlue API_AVAILABLE(ios(18.0));

typedef NS_OPTIONS(NSInteger, NSUnderlineStyle) {
    NSUnderlineStyleNone = 0x00, NSUnderlineStyleSingle = 0x01, NSUnderlineStyleThick = 0x02, NSUnderlineStyleDouble = 0x09,
    NSUnderlineStylePatternSolid = 0x0000, NSUnderlineStylePatternDot = 0x0100, NSUnderlineStylePatternDash = 0x0200,
    NSUnderlineStylePatternDashDot = 0x0300, NSUnderlineStylePatternDashDotDot = 0x0400, NSUnderlineStyleByWord = 0x8000 };

typedef NS_ENUM(NSInteger, NSWritingDirection) { NSWritingDirectionNatural = -1, NSWritingDirectionLeftToRight = 0, NSWritingDirectionRightToLeft = 1 };
/* NSTextAlignment <-> Core Text's (their values differ: right and center are swapped) */
UIKIT_EXTERN CTTextAlignment NSTextAlignmentToCTTextAlignment(NSTextAlignment nsTextAlignment) API_AVAILABLE(ios(6.0));
UIKIT_EXTERN NSTextAlignment NSTextAlignmentFromCTTextAlignment(CTTextAlignment ctTextAlignment) NS_SWIFT_NAME(NSTextAlignment.init(_:)) API_AVAILABLE(ios(6.0));
/* tab stops: text after a tab starts at the next stop (from the line fragment's leading edge), aligned to it */
@class NSTextList;
typedef NSString *NSTextTabOptionKey NS_TYPED_ENUM NS_SWIFT_NAME(NSTextTab.OptionKey);
/* an NSCharacterSet: a right-aligned tab with column terminators aligns at them (decimal tabs) */
UIKIT_EXTERN NSTextTabOptionKey const NSTabColumnTerminatorsAttributeName NS_SWIFT_NAME(columnTerminators);
API_AVAILABLE(ios(7.0))
@interface NSTextTab : NSObject <NSCopying, NSSecureCoding>
/* the decimal separator of the locale (the current one when nil) */
+ (NSCharacterSet *)columnTerminatorsForLocale:(nullable NSLocale *)aLocale;
- (instancetype)initWithTextAlignment:(NSTextAlignment)alignment location:(CGFloat)loc options:(NSDictionary<NSTextTabOptionKey, id> *)options NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (readonly) NSTextAlignment alignment;
@property (readonly) CGFloat location;
@property (readonly) NSDictionary<NSTextTabOptionKey, id> *options;
@end

NS_SWIFT_UI_ACTOR
@interface NSParagraphStyle : NSObject <NSCopying, NSMutableCopying>
/* the base direction of a language's script (right to left for Arabic, Hebrew, Persian, Urdu ...); nil: natural */
+ (NSWritingDirection)defaultWritingDirectionForLanguage:(nullable NSString *)languageName;
@property (class, readonly, copy) NSParagraphStyle *defaultParagraphStyle;
@property (readonly) CGFloat lineSpacing;
@property (readonly) CGFloat paragraphSpacing;
@property (readonly) NSTextAlignment alignment;
@property (readonly) CGFloat headIndent;
@property (readonly) CGFloat tailIndent;
@property (readonly) CGFloat firstLineHeadIndent;
@property (readonly) CGFloat minimumLineHeight;
@property (readonly) CGFloat maximumLineHeight;
@property (readonly) NSLineBreakMode lineBreakMode;
@property (readonly) NSWritingDirection baseWritingDirection;
@property (readonly) CGFloat lineHeightMultiple;
@property (readonly) CGFloat paragraphSpacingBefore;
@property (readonly) float hyphenationFactor;
/* the blocks (NSTextTable.h) holding the paragraph, outermost first */
@property (readonly, copy) NSArray<NSTextBlock *> *textBlocks;
/* tab stops (default: 12 left tabs 28 points apart) and the interval of the stops after them (0: none) */
@property (readonly, copy) NSArray<NSTextTab *> *tabStops API_AVAILABLE(ios(7.0));
@property (readonly) CGFloat defaultTabInterval API_AVAILABLE(ios(7.0));
/* the lists (NSTextList.h) holding the paragraph, outermost first */
@property (readonly, copy) NSArray<NSTextList *> *textLists API_AVAILABLE(ios(7.0));
@property (readonly) NSLineBreakStrategy lineBreakStrategy API_AVAILABLE(ios(9.0));
@property (readonly) BOOL allowsDefaultTighteningForTruncation API_AVAILABLE(ios(9.0));
@property (readonly) BOOL usesDefaultHyphenation API_AVAILABLE(ios(15.0));
@end
NS_SWIFT_UI_ACTOR
@interface NSMutableParagraphStyle : NSParagraphStyle
@property CGFloat lineSpacing;
@property CGFloat paragraphSpacing;
@property NSTextAlignment alignment;
@property CGFloat firstLineHeadIndent;
@property CGFloat headIndent;
@property CGFloat tailIndent;
@property NSLineBreakMode lineBreakMode;
@property CGFloat minimumLineHeight;
@property CGFloat maximumLineHeight;
@property NSWritingDirection baseWritingDirection;
@property CGFloat lineHeightMultiple;
@property CGFloat paragraphSpacingBefore;
@property float hyphenationFactor;
@property (copy) NSArray<NSTextBlock *> *textBlocks;
@property (null_resettable, copy) NSArray<NSTextTab *> *tabStops API_AVAILABLE(ios(7.0));
@property CGFloat defaultTabInterval API_AVAILABLE(ios(7.0));
@property (copy) NSArray<NSTextList *> *textLists API_AVAILABLE(ios(7.0));
@property NSLineBreakStrategy lineBreakStrategy API_AVAILABLE(ios(9.0));
@property BOOL allowsDefaultTighteningForTruncation API_AVAILABLE(ios(9.0));
@property BOOL usesDefaultHyphenation API_AVAILABLE(ios(15.0));
- (void)addTabStop:(NSTextTab *)anObject API_AVAILABLE(ios(9.0));
/* removes the first tab stop with the same location and alignment */
- (void)removeTabStop:(NSTextTab *)anObject API_AVAILABLE(ios(9.0));
- (void)setParagraphStyle:(NSParagraphStyle *)obj API_AVAILABLE(ios(9.0));
@end
NS_SWIFT_UI_ACTOR
@interface NSShadow : NSObject <NSCopying>
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic) CGFloat shadowBlurRadius;
@property (nullable, nonatomic, strong) id shadowColor;
@end

typedef NS_OPTIONS(NSInteger, NSStringDrawingOptions) {
    NSStringDrawingUsesLineFragmentOrigin = 1 << 0, NSStringDrawingUsesFontLeading = 1 << 1,
    NSStringDrawingUsesDeviceMetrics = 1 << 3, NSStringDrawingTruncatesLastVisibleLine = 1 << 5,
    NSStringDrawingOptionsResolvesNaturalAlignmentWithBaseWritingDirection API_AVAILABLE(ios(18.0)) = 1 << 9 };
NS_SWIFT_UI_ACTOR
@interface NSStringDrawingContext : NSObject
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic, readonly) CGFloat actualScaleFactor;
@property (nonatomic, readonly) CGRect totalBounds;
@end
@interface NSString (NSStringDrawing)
- (CGSize)sizeWithAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs NS_SWIFT_NAME(size(withAttributes:));
- (void)drawAtPoint:(CGPoint)point withAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs;
- (void)drawInRect:(CGRect)rect withAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs;
- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes context:(nullable NSStringDrawingContext *)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes context:(nullable NSStringDrawingContext *)context;
@end
@interface NSAttributedString (NSStringDrawing)
- (CGSize)size;
- (void)drawAtPoint:(CGPoint)point;
- (void)drawInRect:(CGRect)rect;
- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options context:(nullable NSStringDrawingContext *)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options context:(nullable NSStringDrawingContext *)context;
@end
/* ---- document formats (issues #238, #239): reading and writing plain text, RTF, RTFD and HTML. Adapted: HTML is
   parsed by the host's libxml2 and mapped to attributes from its tags and CSS (inline styles, <style> rules with simple
   selectors), not laid out by WebKit; RTF by isim's RTF reader. ---- */
typedef NSString *NSAttributedStringDocumentType NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSAttributedString.DocumentType);
UIKIT_EXTERN NSAttributedStringDocumentType const NSPlainTextDocumentType NS_SWIFT_NAME(plain) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentType const NSRTFTextDocumentType NS_SWIFT_NAME(rtf) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentType const NSRTFDTextDocumentType NS_SWIFT_NAME(rtfd) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentType const NSHTMLTextDocumentType NS_SWIFT_NAME(html) API_AVAILABLE(ios(7.0));

typedef NSString *NSTextLayoutSectionKey NS_TYPED_ENUM NS_SWIFT_NAME(NSAttributedString.TextLayoutSectionKey);
UIKIT_EXTERN NSTextLayoutSectionKey const NSTextLayoutSectionOrientation NS_SWIFT_NAME(orientation) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextLayoutSectionKey const NSTextLayoutSectionRange NS_SWIFT_NAME(range) API_AVAILABLE(ios(7.0));

typedef NS_ENUM(NSInteger, NSTextScalingType) {
    NSTextScalingStandard = 0,
    NSTextScalingiOS,
} API_AVAILABLE(ios(13.0));

typedef NSString *NSAttributedStringDocumentAttributeKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSAttributedString.DocumentAttributeKey);
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSDocumentTypeDocumentAttribute NS_SWIFT_NAME(documentType) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSCharacterEncodingDocumentAttribute NS_SWIFT_NAME(characterEncoding) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSDefaultAttributesDocumentAttribute NS_SWIFT_NAME(defaultAttributes) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSPaperSizeDocumentAttribute NS_SWIFT_NAME(paperSize) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSPaperMarginDocumentAttribute NS_SWIFT_NAME(paperMargin) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSViewSizeDocumentAttribute NS_SWIFT_NAME(viewSize) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSViewZoomDocumentAttribute NS_SWIFT_NAME(viewZoom) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSViewModeDocumentAttribute NS_SWIFT_NAME(viewMode) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSReadOnlyDocumentAttribute NS_SWIFT_NAME(readOnly) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSBackgroundColorDocumentAttribute NS_SWIFT_NAME(backgroundColor) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSHyphenationFactorDocumentAttribute NS_SWIFT_NAME(hyphenationFactor) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSDefaultTabIntervalDocumentAttribute NS_SWIFT_NAME(defaultTabInterval) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSTextLayoutSectionsAttribute NS_SWIFT_NAME(textLayoutSections) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSCocoaVersionDocumentAttribute NS_SWIFT_NAME(cocoaVersionDocumentAttribute) API_AVAILABLE(ios(13.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSSourceTextScalingDocumentAttribute NS_SWIFT_NAME(sourceTextScaling) API_AVAILABLE(ios(13.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSTextScalingDocumentAttribute NS_SWIFT_NAME(textScaling) API_AVAILABLE(ios(13.0));
UIKIT_EXTERN NSAttributedStringDocumentAttributeKey const NSDefaultFontExcludedDocumentAttribute NS_SWIFT_NAME(defaultFontExcluded) API_AVAILABLE(ios(17.0));

typedef NSString *NSAttributedStringDocumentReadingOptionKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSAttributedString.DocumentReadingOptionKey);
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSDocumentTypeDocumentOption NS_SWIFT_NAME(documentType) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSDefaultAttributesDocumentOption NS_SWIFT_NAME(defaultAttributes) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSCharacterEncodingDocumentOption NS_SWIFT_NAME(characterEncoding) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSReadAccessURLDocumentOption NS_SWIFT_NAME(readAccessURL) API_AVAILABLE(ios(13.0));
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSSourceTextScalingDocumentOption NS_SWIFT_NAME(sourceTextScaling) API_AVAILABLE(ios(13.0));
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSTargetTextScalingDocumentOption NS_SWIFT_NAME(targetTextScaling) API_AVAILABLE(ios(13.0));
UIKIT_EXTERN NSAttributedStringDocumentReadingOptionKey const NSTextKit1ListMarkerFormatDocumentOption NS_SWIFT_NAME(textKit1ListMarkerFormatDocumentOption) API_AVAILABLE(ios(18.0));

@interface NSAttributedString (NSAttributedStringDocumentFormats)
- (nullable instancetype)initWithURL:(NSURL *)url options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *)options
                  documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> *_Nullable *_Nullable)dict error:(NSError **)error API_AVAILABLE(ios(9.0));
- (nullable instancetype)initWithData:(NSData *)data options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *)options
                   documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> *_Nullable *_Nullable)dict error:(NSError **)error API_AVAILABLE(ios(7.0));
/* writing (issue #239): plain text, RTF, RTFD (a package: TXT.rtf and the attachments' files; as data, the file
   wrapper's serialized form) and HTML, in Cocoa's writers' shape */
- (nullable NSData *)dataFromRange:(NSRange)range documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> *)dict
                             error:(NSError **)error API_AVAILABLE(ios(7.0));
- (nullable NSFileWrapper *)fileWrapperFromRange:(NSRange)range documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> *)dict
                                           error:(NSError **)error API_AVAILABLE(ios(7.0));
@end
@interface NSMutableAttributedString (NSMutableAttributedStringDocumentFormats)
- (BOOL)readFromURL:(NSURL *)url options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *)opts
 documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> *_Nullable *_Nullable)dict error:(NSError **)error API_AVAILABLE(ios(9.0));
- (BOOL)readFromData:(NSData *)data options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *)opts
  documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> *_Nullable *_Nullable)dict error:(NSError **)error API_AVAILABLE(ios(7.0));
@end
NS_ASSUME_NONNULL_END
