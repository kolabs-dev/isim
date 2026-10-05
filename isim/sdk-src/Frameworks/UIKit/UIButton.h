#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UILabel, UIImage, UIImageView, UIColor, UIFont, UIButtonConfiguration, UIImageSymbolConfiguration;
typedef NS_ENUM(NSInteger, UIButtonType) { UIButtonTypeCustom = 0, UIButtonTypeSystem = 1, UIButtonTypeDetailDisclosure, UIButtonTypeInfoLight, UIButtonTypeInfoDark, UIButtonTypeContactAdd, UIButtonTypeClose = 7, UIButtonTypeRoundedRect = UIButtonTypeSystem };
@interface UIButton : UIControl
+ (instancetype)buttonWithType:(UIButtonType)buttonType;
+ (instancetype)systemButtonWithPrimaryAction:(nullable UIAction *)primaryAction;
+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)configuration primaryAction:(nullable UIAction *)primaryAction;
@property (nonatomic, readonly) UIButtonType buttonType;
@property (nonatomic, copy, nullable) UIButtonConfiguration *configuration;
- (void)setNeedsUpdateConfiguration;
@property (nonatomic) UIEdgeInsets contentEdgeInsets;
- (void)setTitle:(nullable NSString *)title forState:(UIControlState)state;
- (void)setTitleColor:(nullable UIColor *)color forState:(UIControlState)state;
- (void)setImage:(nullable UIImage *)image forState:(UIControlState)state;
- (nullable UIImage *)imageForState:(UIControlState)state;
@property (nullable, nonatomic, readonly, strong) UIImage *currentImage;
- (void)setPreferredSymbolConfiguration:(nullable UIImageSymbolConfiguration *)configuration forImageInState:(UIControlState)state;
- (nullable NSString *)titleForState:(UIControlState)state;
- (nullable UIColor *)titleColorForState:(UIControlState)state;
@property (nullable, nonatomic, readonly) NSString *currentTitle;
@property (nonatomic, readonly) UIColor *currentTitleColor;
@property (nullable, nonatomic, readonly, strong) UILabel *titleLabel;
@property (nullable, nonatomic, readonly, strong) UIImageView *imageView;
@end
typedef NS_ENUM(NSInteger, UIButtonConfigurationCornerStyle) { UIButtonConfigurationCornerStyleFixed = -1, UIButtonConfigurationCornerStyleDynamic, UIButtonConfigurationCornerStyleSmall, UIButtonConfigurationCornerStyleMedium, UIButtonConfigurationCornerStyleLarge, UIButtonConfigurationCornerStyleCapsule };
typedef NS_ENUM(NSInteger, UIButtonConfigurationSize) { UIButtonConfigurationSizeMedium = 0, UIButtonConfigurationSizeSmall, UIButtonConfigurationSizeMini, UIButtonConfigurationSizeLarge };
NS_SWIFT_UI_ACTOR
@interface UIButtonConfiguration : NSObject <NSCopying>
+ (instancetype)plainButtonConfiguration;
+ (instancetype)tintedButtonConfiguration;
+ (instancetype)grayButtonConfiguration;
+ (instancetype)filledButtonConfiguration;
+ (instancetype)borderlessButtonConfiguration;
+ (instancetype)borderedButtonConfiguration;
+ (instancetype)borderedTintedButtonConfiguration;
+ (instancetype)borderedProminentButtonConfiguration;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) UIColor *baseForegroundColor;
@property (nonatomic, strong, nullable) UIColor *baseBackgroundColor;
@property (nonatomic) UIButtonConfigurationCornerStyle cornerStyle;
@property (nonatomic) UIButtonConfigurationSize buttonSize;
@property (nonatomic) NSDirectionalEdgeInsets contentInsets;
@property (nonatomic) CGFloat imagePadding;
@end
NS_ASSUME_NONNULL_END
