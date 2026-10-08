#pragma once
/* isim: UIFontPickerViewController — the font families iOS ships (and the app's UIAppFonts), each shown in its own
 * typeface, with search; picking one sets selectedFontDescriptor and tells the delegate. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIFontDescriptor.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFontPickerViewController;

NS_SWIFT_UI_ACTOR
@interface UIFontPickerViewControllerConfiguration : NSObject <NSCopying>
@property (nonatomic) BOOL includeFaces;
@property (nonatomic) BOOL displayUsingSystemFont;
@end

NS_SWIFT_UI_ACTOR
@protocol UIFontPickerViewControllerDelegate <NSObject>
@optional
- (void)fontPickerViewControllerDidCancel:(UIFontPickerViewController *)viewController;
- (void)fontPickerViewControllerDidPickFont:(UIFontPickerViewController *)viewController;
@end

NS_SWIFT_UI_ACTOR
@interface UIFontPickerViewController : UIViewController
- (instancetype)initWithConfiguration:(UIFontPickerViewControllerConfiguration *)configuration;
- (instancetype)init;
@property (nonatomic, readonly, copy) UIFontPickerViewControllerConfiguration *configuration;
@property (nullable, nonatomic, weak) id<UIFontPickerViewControllerDelegate> delegate;
@property (nullable, nonatomic, strong) UIFontDescriptor *selectedFontDescriptor;
@end
NS_ASSUME_NONNULL_END
