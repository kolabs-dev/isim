#pragma once
#import <UIKit/UIView.h>
#import <UIKit/UILetterformAwareAdjusting.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFont, UIColor, NSAttributedString;
typedef NS_ENUM(NSInteger, NSTextAlignment) { NSTextAlignmentLeft = 0, NSTextAlignmentCenter = 1, NSTextAlignmentRight = 2, NSTextAlignmentJustified = 3, NSTextAlignmentNatural = 4 };
typedef NS_ENUM(NSInteger, NSLineBreakMode) { NSLineBreakByWordWrapping = 0, NSLineBreakByCharWrapping, NSLineBreakByClipping, NSLineBreakByTruncatingHead, NSLineBreakByTruncatingTail, NSLineBreakByTruncatingMiddle };
typedef NS_ENUM(NSInteger, UIBaselineAdjustment) { UIBaselineAdjustmentAlignBaselines = 0, UIBaselineAdjustmentAlignCenters, UIBaselineAdjustmentNone };
typedef NS_ENUM(NSInteger, UILabelVibrancy) { UILabelVibrancyNone = 0, UILabelVibrancyAutomatic = 1 } API_AVAILABLE(ios(17.0));
typedef NS_OPTIONS(NSUInteger, NSLineBreakStrategy) {
    NSLineBreakStrategyNone = 0, NSLineBreakStrategyPushOut = 1 << 0, NSLineBreakStrategyHangulWordPriority = 1 << 1,
    NSLineBreakStrategyStandard = 0xFFFF } NS_SWIFT_NAME(NSParagraphStyle.LineBreakStrategy);
@interface UILabel : UIView <UILetterformAwareAdjusting>
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSAttributedString *attributedText;
@property (null_resettable, nonatomic, strong) UIFont *font;
@property (null_resettable, nonatomic, strong) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nullable, nonatomic, strong) UIColor *highlightedTextColor;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic) CGFloat preferredMaxLayoutWidth;
@property (nonatomic) BOOL adjustsFontForContentSizeCategory;
/* where shrunk text (adjustsFontSizeToFitWidth) sits: on the original baseline, centred, or at the top */
@property (nonatomic) UIBaselineAdjustment baselineAdjustment;
/* isim: stored; Pango tightens nothing before truncating */
@property (nonatomic) BOOL allowsDefaultTighteningForTruncation API_AVAILABLE(ios(9.0));
/* isim: stored; Pango breaks lines by its own (Unicode) rules */
@property (nonatomic) NSLineBreakStrategy lineBreakStrategy API_AVAILABLE(ios(14.0));
/* iPad pointer: hovering a truncated label shows its full text in a tooltip */
@property (nonatomic) BOOL showsExpansionTextWhenTruncated;
/* in a vibrancy effect's content the label is drawn vibrant unless .none (isim: vibrancy is drawn as the effect's tint) */
@property (nonatomic) UILabelVibrancy preferredVibrancy API_AVAILABLE(ios(17.0));
- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;
@end
NS_ASSUME_NONNULL_END
