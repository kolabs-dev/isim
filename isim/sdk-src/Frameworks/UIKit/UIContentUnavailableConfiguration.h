#pragma once
/* isim: UIContentUnavailableConfiguration (iOS 17) — a class here (UIKit's Swift overlay makes it a struct; adapted,
   like UIListContentConfiguration), UIContentUnavailableView and the view controller's contentUnavailableConfiguration. */
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UITableView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIColor, UIFont, UIButtonConfiguration, UIAction, UIMenu, UIBackgroundConfiguration;

NS_SWIFT_UI_ACTOR
@interface UIContentUnavailableImageProperties : NSObject <NSCopying>
@property (nullable, nonatomic, strong) UIColor *tintColor;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGSize maximumSize;
@end
NS_SWIFT_UI_ACTOR
@interface UIContentUnavailableTextProperties : NSObject <NSCopying>
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) NSTextAlignment alignment;
@property (nonatomic) NSInteger numberOfLines;
@end
NS_SWIFT_UI_ACTOR
@interface UIContentUnavailableButtonProperties : NSObject <NSCopying>
@property (nullable, nonatomic, copy) UIAction *primaryAction;
@property (nullable, nonatomic, copy) UIMenu *menu;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end

NS_SWIFT_UI_ACTOR
@interface UIContentUnavailableConfiguration : NSObject <UIContentConfiguration>
+ (instancetype)emptyConfiguration NS_SWIFT_NAME(empty());
+ (instancetype)loadingConfiguration NS_SWIFT_NAME(loading());
+ (instancetype)searchConfiguration NS_SWIFT_NAME(search());
@property (nullable, nonatomic, strong) UIImage *image;
@property (nonatomic, readonly) UIContentUnavailableImageProperties *imageProperties;
@property (nullable, nonatomic, copy) NSString *text;
@property (nonatomic, readonly) UIContentUnavailableTextProperties *textProperties;
@property (nullable, nonatomic, copy) NSString *secondaryText;
@property (nonatomic, readonly) UIContentUnavailableTextProperties *secondaryTextProperties;
@property (nullable, nonatomic, copy) UIButtonConfiguration *button;
@property (nonatomic, readonly) UIContentUnavailableButtonProperties *buttonProperties;
@property (nullable, nonatomic, copy) UIButtonConfiguration *secondaryButton;
@property (nonatomic, readonly) UIContentUnavailableButtonProperties *secondaryButtonProperties;
@property (nonatomic) NSDirectionalEdgeInsets directionalLayoutMargins;
@property (nonatomic) CGFloat imageToTextPadding, textToSecondaryTextPadding, textToButtonPadding, buttonToSecondaryButtonPadding;
@property (nullable, nonatomic, strong) UIColor *backgroundColor;      /* isim: stands in for `background` */
- (UIView *)makeContentView;
@end

NS_SWIFT_UI_ACTOR
@interface UIContentUnavailableView : UIView
- (instancetype)initWithConfiguration:(UIContentUnavailableConfiguration *)configuration;
@property (nonatomic, copy) UIContentUnavailableConfiguration *configuration;
@end

NS_SWIFT_UI_ACTOR
@interface UIContentUnavailableConfigurationState : NSObject <NSCopying>
@property (nullable, nonatomic, copy) NSString *searchText;
@end

@interface UIViewController (UIContentUnavailable)
@property (nullable, nonatomic, copy) id<UIContentConfiguration> contentUnavailableConfiguration;
@property (nonatomic, readonly) UIContentUnavailableConfigurationState *contentUnavailableConfigurationState;
- (void)setNeedsUpdateContentUnavailableConfiguration;
- (void)updateContentUnavailableConfigurationUsingState:(UIContentUnavailableConfigurationState *)state;
@end
NS_ASSUME_NONNULL_END
