#pragma once
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGColor.h>
NS_ASSUME_NONNULL_BEGIN
@class UITraitCollection;
@interface UIColor : NSObject <NSCopying, NSSecureCoding>
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (UIColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithDisplayP3Red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithCGColor:(CGColorRef)cgColor;
+ (UIColor *)colorWithDynamicProvider:(UIColor * (^)(UITraitCollection *traitCollection))dynamicProvider;
- (instancetype)initWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (instancetype)initWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;
- (instancetype)initWithDynamicProvider:(UIColor * (^)(UITraitCollection *traitCollection))dynamicProvider;
@property (class, nonatomic, readonly) UIColor *blackColor, *darkGrayColor, *lightGrayColor, *whiteColor, *grayColor,
    *redColor, *greenColor, *blueColor, *cyanColor, *yellowColor, *magentaColor, *orangeColor, *purpleColor, *brownColor, *clearColor;
@property (class, nonatomic, readonly) UIColor *systemRedColor, *systemGreenColor, *systemBlueColor, *systemOrangeColor,
    *systemYellowColor, *systemPinkColor, *systemPurpleColor, *systemTealColor, *systemIndigoColor, *systemMintColor,
    *systemCyanColor, *systemBrownColor, *systemGrayColor, *systemGray2Color, *systemGray3Color, *systemGray4Color,
    *systemGray5Color, *systemGray6Color, *tintColor;
@property (class, nonatomic, readonly) UIColor *labelColor, *secondaryLabelColor, *tertiaryLabelColor, *quaternaryLabelColor,
    *linkColor, *placeholderTextColor, *separatorColor, *opaqueSeparatorColor, *systemBackgroundColor,
    *secondarySystemBackgroundColor, *tertiarySystemBackgroundColor, *systemGroupedBackgroundColor,
    *secondarySystemGroupedBackgroundColor, *tertiarySystemGroupedBackgroundColor, *systemFillColor,
    *secondarySystemFillColor, *tertiarySystemFillColor, *quaternarySystemFillColor, *lightTextColor, *darkTextColor;
- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha;
- (UIColor *)resolvedColorWithTraitCollection:(UITraitCollection *)traitCollection;
- (BOOL)getRed:(nullable CGFloat *)red green:(nullable CGFloat *)green blue:(nullable CGFloat *)blue alpha:(nullable CGFloat *)alpha;
- (BOOL)getWhite:(nullable CGFloat *)white alpha:(nullable CGFloat *)alpha;
- (void)set;
- (void)setFill;
- (void)setStroke;
@property (nonatomic, readonly) CGColorRef CGColor;
@end
NS_ASSUME_NONNULL_END
