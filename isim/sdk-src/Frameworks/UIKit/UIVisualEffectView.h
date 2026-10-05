#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIBlurEffectStyle) {
    UIBlurEffectStyleExtraLight, UIBlurEffectStyleLight, UIBlurEffectStyleDark,
    UIBlurEffectStyleRegular = 4, UIBlurEffectStyleProminent = 5,
    UIBlurEffectStyleSystemUltraThinMaterial = 6, UIBlurEffectStyleSystemThinMaterial = 7, UIBlurEffectStyleSystemMaterial = 8,
    UIBlurEffectStyleSystemThickMaterial = 9, UIBlurEffectStyleSystemChromeMaterial = 10,
    UIBlurEffectStyleSystemUltraThinMaterialLight = 11, UIBlurEffectStyleSystemThinMaterialLight = 12, UIBlurEffectStyleSystemMaterialLight = 13,
    UIBlurEffectStyleSystemThickMaterialLight = 14, UIBlurEffectStyleSystemChromeMaterialLight = 15,
    UIBlurEffectStyleSystemUltraThinMaterialDark = 16, UIBlurEffectStyleSystemThinMaterialDark = 17, UIBlurEffectStyleSystemMaterialDark = 18,
    UIBlurEffectStyleSystemThickMaterialDark = 19, UIBlurEffectStyleSystemChromeMaterialDark = 20,
};
typedef NS_ENUM(NSInteger, UIVibrancyEffectStyle) {
    UIVibrancyEffectStyleLabel, UIVibrancyEffectStyleSecondaryLabel, UIVibrancyEffectStyleTertiaryLabel, UIVibrancyEffectStyleQuaternaryLabel,
    UIVibrancyEffectStyleFill, UIVibrancyEffectStyleSecondaryFill, UIVibrancyEffectStyleTertiaryFill, UIVibrancyEffectStyleSeparator,
};
NS_SWIFT_UI_ACTOR
@interface UIVisualEffect : NSObject <NSCopying>
@end
/* isim: a real backdrop blur plus the style's tint (light/dark aware); saturation boost is not applied */
NS_SWIFT_UI_ACTOR
@interface UIBlurEffect : UIVisualEffect
+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style;
@property (nonatomic, readonly) UIBlurEffectStyle _isim_style;
@end
/* isim: vibrancy draws its content normally */
NS_SWIFT_UI_ACTOR
@interface UIVibrancyEffect : UIVisualEffect
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect;
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)blurEffect style:(UIVibrancyEffectStyle)style;
@end
NS_SWIFT_UI_ACTOR
@interface UIVisualEffectView : UIView
- (instancetype)initWithEffect:(nullable UIVisualEffect *)effect NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, copy, nullable) UIVisualEffect *effect;
@end
NS_ASSUME_NONNULL_END
