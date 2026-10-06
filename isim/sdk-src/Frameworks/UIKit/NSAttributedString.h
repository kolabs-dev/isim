#pragma once
/* isim: UIKit's attributed-string keys, paragraph styles, shadows and string drawing. Text renders through the
   host's Pango (fonts, colours, kerning, underline/strikethrough, baseline offset, alignment, line spacing). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UILabel.h>
#include <CoreGraphics/CGGeometry.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFont, UIColor;
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

typedef NS_OPTIONS(NSInteger, NSUnderlineStyle) {
    NSUnderlineStyleNone = 0x00, NSUnderlineStyleSingle = 0x01, NSUnderlineStyleThick = 0x02, NSUnderlineStyleDouble = 0x09,
    NSUnderlineStylePatternSolid = 0x0000, NSUnderlineStylePatternDot = 0x0100, NSUnderlineStylePatternDash = 0x0200,
    NSUnderlineStylePatternDashDot = 0x0300, NSUnderlineStylePatternDashDotDot = 0x0400, NSUnderlineStyleByWord = 0x8000 };

typedef NS_ENUM(NSInteger, NSWritingDirection) { NSWritingDirectionNatural = -1, NSWritingDirectionLeftToRight = 0, NSWritingDirectionRightToLeft = 1 };
NS_SWIFT_UI_ACTOR
@interface NSParagraphStyle : NSObject <NSCopying, NSMutableCopying>
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
@end
NS_SWIFT_UI_ACTOR
@interface NSShadow : NSObject <NSCopying>
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic) CGFloat shadowBlurRadius;
@property (nullable, nonatomic, strong) id shadowColor;
@end

typedef NS_OPTIONS(NSInteger, NSStringDrawingOptions) {
    NSStringDrawingUsesLineFragmentOrigin = 1 << 0, NSStringDrawingUsesFontLeading = 1 << 1,
    NSStringDrawingUsesDeviceMetrics = 1 << 3, NSStringDrawingTruncatesLastVisibleLine = 1 << 5 };
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
NS_ASSUME_NONNULL_END
