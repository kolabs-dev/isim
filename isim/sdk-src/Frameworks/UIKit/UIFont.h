#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef CGFloat UIFontWeight NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN const UIFontWeight UIFontWeightUltraLight, UIFontWeightThin, UIFontWeightLight, UIFontWeightRegular,
    UIFontWeightMedium, UIFontWeightSemibold, UIFontWeightBold, UIFontWeightHeavy, UIFontWeightBlack;
typedef NSString *UIFontTextStyle NS_TYPED_ENUM;
UIKIT_EXTERN const UIFontTextStyle UIFontTextStyleLargeTitle, UIFontTextStyleTitle1, UIFontTextStyleTitle2,
    UIFontTextStyleTitle3, UIFontTextStyleHeadline, UIFontTextStyleSubheadline, UIFontTextStyleBody,
    UIFontTextStyleCallout, UIFontTextStyleFootnote, UIFontTextStyleCaption1, UIFontTextStyleCaption2;
@interface UIFont : NSObject <NSCopying>
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style;
+ (nullable UIFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize;
+ (UIFont *)systemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)italicSystemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)systemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;
+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;
@property (class, nonatomic, readonly) CGFloat labelFontSize, buttonFontSize, smallSystemFontSize, systemFontSize;
- (UIFont *)fontWithSize:(CGFloat)fontSize;
@property (nonatomic, readonly, strong) NSString *familyName;
@property (nonatomic, readonly, strong) NSString *fontName;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) CGFloat ascender, descender, capHeight, xHeight, lineHeight, leading;
@end
NS_ASSUME_NONNULL_END
