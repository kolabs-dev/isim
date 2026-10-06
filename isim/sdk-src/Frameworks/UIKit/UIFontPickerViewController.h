#pragma once
/* isim: UIFontPickerViewController — the font families iOS ships (and the app's UIAppFonts), each shown in its own
 * typeface, with search; picking one sets selectedFontDescriptor and tells the delegate. Plus a minimal
 * UIFontDescriptor (family / name / size attributes) for it. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIFont.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFontPickerViewController;

typedef NSString *UIFontDescriptorAttributeName NS_TYPED_ENUM NS_SWIFT_NAME(UIFontDescriptor.AttributeName);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute NS_SWIFT_NAME(family);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute NS_SWIFT_NAME(name);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute NS_SWIFT_NAME(size);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute NS_SWIFT_NAME(face);

NS_SWIFT_UI_ACTOR
@interface UIFontDescriptor : NSObject <NSCopying>
- (instancetype)initWithFontAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes NS_DESIGNATED_INITIALIZER;
+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes;
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size;
- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)newFamily;
- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)newPointSize;
- (nullable id)objectForKey:(UIFontDescriptorAttributeName)anAttribute;
@property (nonatomic, readonly) NSString *postscriptName;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) NSDictionary<UIFontDescriptorAttributeName, id> *fontAttributes;
@end

@interface UIFont (UIFontDescriptorSupport)
+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)pointSize;
@property (nonatomic, readonly) UIFontDescriptor *fontDescriptor;
+ (NSArray<NSString *> *)fontNamesForFamilyName:(NSString *)familyName;
@end

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
