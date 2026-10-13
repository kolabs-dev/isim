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
- (BOOL)getHue:(nullable CGFloat *)hue saturation:(nullable CGFloat *)saturation brightness:(nullable CGFloat *)brightness alpha:(nullable CGFloat *)alpha;
- (void)set;
- (void)setFill;
- (void)setStroke;
@property (nonatomic, readonly) CGColorRef CGColor;
@end

@class CIColor, UIImage;
typedef NS_ENUM(NSInteger, UIColorProminence) {
    UIColorProminencePrimary = 0, UIColorProminenceSecondary, UIColorProminenceTertiary, UIColorProminenceQuaternary,
} NS_SWIFT_NAME(UIColor.Prominence) API_AVAILABLE(ios(18.0));
@interface UIColor (UIColorExtras)
- (instancetype)initWithCGColor:(CGColorRef)cgColor;
- (instancetype)initWithDisplayP3Red:(CGFloat)displayP3Red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
/* a pattern: fills tile the image (from the context's origin) */
+ (UIColor *)colorWithPatternImage:(UIImage *)image;
- (instancetype)initWithPatternImage:(UIImage *)image;
/* Core Image colors (their red, green, blue and alpha) */
+ (UIColor *)colorWithCIColor:(CIColor *)ciColor;
- (instancetype)initWithCIColor:(CIColor *)ciColor;
@property (nonatomic, readonly) CIColor *CIColor;
/* a short description for VoiceOver ("dark blue", "light gray"; adapted: isim's own names from hue and lightness) */
@property (nonatomic, readonly) NSString *accessibilityName API_AVAILABLE(ios(14.0));
/* prominence (iOS 18): less prominent colors draw with the opacity of the matching label colour */
@property (nonatomic, readonly) UIColorProminence prominence API_AVAILABLE(ios(18.0));
- (UIColor *)colorWithProminence:(UIColorProminence)prominence NS_SWIFT_NAME(withProminence(_:)) API_AVAILABLE(ios(18.0));
/* HDR (iOS 26): isim draws standard dynamic range, so brighter-than-white components are clamped when drawn */
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha linearExposure:(CGFloat)linearExposure API_AVAILABLE(ios(26.0));
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha exposure:(CGFloat)exposure API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) CGFloat linearExposure API_AVAILABLE(ios(26.0));
- (UIColor *)colorByApplyingContentHeadroom:(CGFloat)contentHeadroom NS_SWIFT_NAME(applyingContentHeadroom(_:)) API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, copy) UIColor *standardDynamicRangeColor NS_SWIFT_NAME(standardDynamicRange) API_AVAILABLE(ios(26.0));
@end

/* named colors from the app's asset catalog (isim-assets.plist; implemented in UIImage.m) */
@interface UIColor (UIColorNamedColors)
+ (nullable UIColor *)colorNamed:(NSString *)name;
+ (nullable UIColor *)colorNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection;
@end
NS_ASSUME_NONNULL_END
