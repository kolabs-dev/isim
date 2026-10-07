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
/* iOS 26 Liquid Glass. isim: drawn with isim's glass approximation (light backdrop blur, translucent body, specular
   rim) in the view's bounds and layer.cornerRadius; interactive glass brightens while touched (adapted). */
typedef NS_ENUM(NSInteger, UIGlassEffectStyle) { UIGlassEffectStyleRegular, UIGlassEffectStyleClear } NS_SWIFT_NAME(UIGlassEffect.Style) API_AVAILABLE(ios(26.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIGlassEffect : UIVisualEffect
+ (UIGlassEffect *)effectWithStyle:(UIGlassEffectStyle)style;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@property (nonatomic, copy, nullable) UIColor *tintColor;
@property (nonatomic, readonly) UIGlassEffectStyle _isim_style;
@end
/* isim: glass views inside a container draw as separate shapes (no merging/morphing between them) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIGlassContainerEffect : UIVisualEffect
@property (nonatomic) CGFloat spacing;
@end
NS_SWIFT_UI_ACTOR
@interface UIVisualEffectView : UIView
- (instancetype)initWithEffect:(nullable UIVisualEffect *)effect NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, copy, nullable) UIVisualEffect *effect;
@end
/* iOS 26: content that extends under sidebars and inspectors. isim has no such chrome: the content view fills the
   view (stub geometry, the content is shown unchanged). */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIBackgroundExtensionView : UIView
@property (nonatomic, strong, nullable) UIView *contentView;
@property (nonatomic) BOOL automaticallyPlacesContentView;
@end
NS_ASSUME_NONNULL_END
