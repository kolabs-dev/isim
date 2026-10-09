#pragma once
/* isim: UIFontPickerViewController — the font families iOS ships (and the app's UIAppFonts), each shown in its own
 * typeface (adapted: drawn with isim's fonts), with search; picking one sets selectedFontDescriptor and tells the
 * delegate. includeFaces: a family's faces open below it (its chevron); filteredTraits keeps the fonts with all the
 * given traits (a family when one of its faces has them); filteredLanguagesPredicate is evaluated against the
 * languages a font supports (isim's list: Latin-script languages, plus Greek and Cyrillic for some families). */
#import <UIKit/UIViewController.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIFontDescriptor.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFontPickerViewController;

NS_SWIFT_UI_ACTOR
NS_SWIFT_NAME(UIFontPickerViewController.Configuration)
@interface UIFontPickerViewControllerConfiguration : NSObject <NSCopying>
@property (nonatomic) BOOL includeFaces;
@property (nonatomic) BOOL displayUsingSystemFont;
@property (nonatomic) UIFontDescriptorSymbolicTraits filteredTraits;
@property (nullable, nonatomic, copy) NSPredicate *filteredLanguagesPredicate;
+ (nullable NSPredicate *)filterPredicateForFilteredLanguages:(NSArray<NSString *> *)filteredLanguages;
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
