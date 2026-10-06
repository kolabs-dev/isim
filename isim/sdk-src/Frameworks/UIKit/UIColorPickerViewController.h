#pragma once
/* isim: UIColorPickerViewController (grid, spectrum and RGB sliders, opacity) and UIColorWell. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor, UIColorPickerViewController;

NS_SWIFT_UI_ACTOR
@protocol UIColorPickerViewControllerDelegate <NSObject>
@optional
- (void)colorPickerViewController:(UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(BOOL)continuously;
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController;
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController;
@end

NS_SWIFT_UI_ACTOR
@interface UIColorPickerViewController : UIViewController
@property (nullable, nonatomic, weak) id<UIColorPickerViewControllerDelegate> delegate;
@property (nonatomic, strong) UIColor *selectedColor;
@property (nonatomic) BOOL supportsAlpha;
@end

NS_SWIFT_UI_ACTOR
@interface UIColorWell : UIControl
- (instancetype)initWithFrame:(CGRect)frame;
@property (nullable, nonatomic, copy) NSString *title;
@property (nonatomic) BOOL supportsAlpha;
@property (nullable, nonatomic, strong) UIColor *selectedColor;
@end
NS_ASSUME_NONNULL_END
