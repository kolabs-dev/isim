#pragma once
#import <UIKit/UIAccessibility.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UILabel, UIImage, UIImageView, UIColor, UIFont, UIButtonConfiguration, UIImageSymbolConfiguration, UIMenu, NSAttributedString;
#ifndef ISIM_NSDIRECTIONALRECTEDGE_DEFINED
#define ISIM_NSDIRECTIONALRECTEDGE_DEFINED 1
typedef NS_OPTIONS(NSUInteger, NSDirectionalRectEdge) {
    NSDirectionalRectEdgeNone = 0, NSDirectionalRectEdgeTop = 1 << 0, NSDirectionalRectEdgeLeading = 1 << 1, NSDirectionalRectEdgeBottom = 1 << 2,
    NSDirectionalRectEdgeTrailing = 1 << 3, NSDirectionalRectEdgeAll = 15 };
#endif
@class UIButton;
typedef void (^UIButtonConfigurationUpdateHandler)(__kindof UIButton *button);
typedef NS_ENUM(NSInteger, UIButtonConfigurationTitleAlignment) { UIButtonConfigurationTitleAlignmentAutomatic = 0, UIButtonConfigurationTitleAlignmentLeading,
    UIButtonConfigurationTitleAlignmentCenter, UIButtonConfigurationTitleAlignmentTrailing };
typedef NS_ENUM(NSInteger, UIButtonType) { UIButtonTypeCustom = 0, UIButtonTypeSystem = 1, UIButtonTypeDetailDisclosure, UIButtonTypeInfoLight, UIButtonTypeInfoDark, UIButtonTypeContactAdd, UIButtonTypeClose = 7, UIButtonTypeRoundedRect = UIButtonTypeSystem };
@interface UIButton : UIControl <UIAccessibilityContentSizeCategoryImageAdjusting>
+ (instancetype)buttonWithType:(UIButtonType)buttonType;
+ (instancetype)systemButtonWithPrimaryAction:(nullable UIAction *)primaryAction;
+ (instancetype)buttonWithType:(UIButtonType)buttonType primaryAction:(nullable UIAction *)primaryAction;
+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)configuration primaryAction:(nullable UIAction *)primaryAction;
@property (nonatomic, readonly) UIButtonType buttonType;
@property (nonatomic, copy, nullable) UIButtonConfiguration *configuration;
@property (nullable, nonatomic, copy) UIMenu *menu;
@property (nonatomic) BOOL showsMenuAsPrimaryAction;
@property (nonatomic) BOOL changesSelectionAsPrimaryAction;
- (void)setNeedsUpdateConfiguration;
/* called when the button's state changes (highlighted, selected, enabled), after setNeedsUpdateConfiguration and when it
   first shows; the default calls configurationUpdateHandler */
- (void)updateConfiguration;
@property (nullable, nonatomic, copy) UIButtonConfigurationUpdateHandler configurationUpdateHandler;
@property (nonatomic) BOOL automaticallyUpdatesConfiguration;
@property (nonatomic) UIEdgeInsets contentEdgeInsets;
- (void)setTitle:(nullable NSString *)title forState:(UIControlState)state;
- (void)setTitleColor:(nullable UIColor *)color forState:(UIControlState)state;
- (void)setImage:(nullable UIImage *)image forState:(UIControlState)state;
- (nullable UIImage *)imageForState:(UIControlState)state;
/* background images per state, drawn stretched behind the content (resizable images draw as nine slices) */
- (void)setBackgroundImage:(nullable UIImage *)image forState:(UIControlState)state;
- (nullable UIImage *)backgroundImageForState:(UIControlState)state;
@property (nullable, nonatomic, readonly, strong) UIImage *currentBackgroundImage;
- (void)setTitleShadowColor:(nullable UIColor *)color forState:(UIControlState)state;
- (nullable UIColor *)titleShadowColorForState:(UIControlState)state;
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
/* iOS 26: how a button's symbol image changes when its configuration's image does. Swift:
   UISymbolContentTransition(.replace, options:) (UIKit overlay); isim plays the replace animation of image views */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UISymbolContentTransition : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/* kind: the Symbols effect kind (replace 6, automatic 7); direction: up 1, down -1; box: the Swift effect and options */
- (instancetype)initWithIsimKind:(NSInteger)kind direction:(NSInteger)direction speed:(double)speed box:(nullable id)box
    NS_SWIFT_NAME(init(_isimKind:direction:speed:box:)) NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) NSInteger _isim_effectKind;
@property (nonatomic, readonly) NSInteger _isim_effectDirection;
@property (nonatomic, readonly) double _isim_effectSpeed;
@property (nonatomic, readonly, nullable) id _isim_box;
@end
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
/* iOS 26 Liquid Glass buttons (isim: glass capsule; prominent = tinted with the tint color) */
+ (instancetype)glassButtonConfiguration API_AVAILABLE(ios(26.0));
+ (instancetype)prominentGlassButtonConfiguration API_AVAILABLE(ios(26.0));
+ (instancetype)clearGlassButtonConfiguration API_AVAILABLE(ios(26.0));
+ (instancetype)prominentClearGlassButtonConfiguration API_AVAILABLE(ios(26.0));
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) UIColor *baseForegroundColor;
@property (nonatomic, strong, nullable) UIColor *baseBackgroundColor;
@property (nonatomic) UIButtonConfigurationCornerStyle cornerStyle;
@property (nonatomic) UIButtonConfigurationSize buttonSize;
@property (nonatomic) NSDirectionalEdgeInsets contentInsets;
@property (nonatomic) CGFloat imagePadding;
/* attributed titles (Swift: AttributedString, UIKit overlay) override title / subtitle */
@property (nonatomic, copy, nullable) NSAttributedString *attributedTitle NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, nullable) NSAttributedString *attributedSubtitle NS_REFINED_FOR_SWIFT;
/* a spinning activity indicator in place of the image */
@property (nonatomic) BOOL showsActivityIndicator;
@property (nonatomic) NSDirectionalRectEdge imagePlacement;     /* leading (default), trailing, top or bottom */
@property (nonatomic) CGFloat titlePadding;
@property (nonatomic) UIButtonConfigurationTitleAlignment titleAlignment;
@property (nonatomic, copy, nullable) UISymbolContentTransition *symbolContentTransition API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
