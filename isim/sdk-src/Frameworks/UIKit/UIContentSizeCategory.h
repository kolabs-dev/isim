#pragma once
/* isim: Dynamic Type. Settings > Accessibility > Display & Text Size > Larger Text picks the content size category;
   preferredFontForTextStyle:, UIFontMetrics and views with adjustsFontForContentSizeCategory follow it (Bold Text makes
   system fonts heavier). Increase Contrast sets accessibilityContrast; Bold Text sets legibilityWeight. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIFont.h>
#import <UIKit/UITraitCollection.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIInteraction.h>
NS_ASSUME_NONNULL_BEGIN
/* UIContentSizeCategory, UIAccessibilityContrast and UILegibilityWeight are declared in UITraitCollection.h */
UIKIT_EXTERN UIContentSizeCategory const UIContentSizeCategoryUnspecified, UIContentSizeCategoryExtraSmall, UIContentSizeCategorySmall,
    UIContentSizeCategoryMedium, UIContentSizeCategoryLarge, UIContentSizeCategoryExtraLarge, UIContentSizeCategoryExtraExtraLarge,
    UIContentSizeCategoryExtraExtraExtraLarge, UIContentSizeCategoryAccessibilityMedium, UIContentSizeCategoryAccessibilityLarge,
    UIContentSizeCategoryAccessibilityExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
UIKIT_EXTERN NSNotificationName const UIContentSizeCategoryDidChangeNotification;
UIKIT_EXTERN NSString *const UIContentSizeCategoryNewValueKey;
UIKIT_EXTERN BOOL UIContentSizeCategoryIsAccessibilityCategory(UIContentSizeCategory category) NS_REFINED_FOR_SWIFT;
UIKIT_EXTERN NSComparisonResult UIContentSizeCategoryCompareToCategory(UIContentSizeCategory lhs, UIContentSizeCategory rhs) NS_REFINED_FOR_SWIFT;

@interface UITraitCollection (UIContentSizeCategory)
@property (nonatomic, copy, readonly) UIContentSizeCategory preferredContentSizeCategory;
@property (nonatomic, readonly) UIAccessibilityContrast accessibilityContrast;
@property (nonatomic, readonly) UILegibilityWeight legibilityWeight;
+ (UITraitCollection *)traitCollectionWithPreferredContentSizeCategory:(UIContentSizeCategory)category;
@end
@interface UIApplication (UIContentSizeCategory)
@property (nonatomic, readonly) UIContentSizeCategory preferredContentSizeCategory;
@end
@interface UIFont (UIContentSizeCategory)
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection;
@end
NS_SWIFT_UI_ACTOR
@protocol UIContentSizeCategoryAdjusting <NSObject>
@property (nonatomic) BOOL adjustsFontForContentSizeCategory;
@end
@interface UITextField (UIContentSizeCategoryAdjusting) <UIContentSizeCategoryAdjusting>
@end
NS_SWIFT_UI_ACTOR
@interface UIFontMetrics : NSObject
@property (class, readonly, strong) UIFontMetrics *defaultMetrics;
+ (instancetype)metricsForTextStyle:(UIFontTextStyle)textStyle;
- (instancetype)initForTextStyle:(UIFontTextStyle)textStyle;
- (UIFont *)scaledFontForFont:(UIFont *)font;
- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize;
- (UIFont *)scaledFontForFont:(UIFont *)font compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection;
- (CGFloat)scaledValueForValue:(CGFloat)value;
- (CGFloat)scaledValueForValue:(CGFloat)value compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection;
@end

@protocol UILargeContentViewerInteractionDelegate;
@class UIViewController, UIGestureRecognizer;
NS_SWIFT_UI_ACTOR
@interface UILargeContentViewerInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(nullable id<UILargeContentViewerInteractionDelegate>)delegate;
@property (nonatomic, nullable, weak, readonly) id<UILargeContentViewerInteractionDelegate> delegate;
@property (class, nonatomic, readonly, getter=isEnabled) BOOL enabled;
/* the long press that shows the viewer (for failure / simultaneous recognition with other recognizers) */
@property (nonatomic, readonly) UIGestureRecognizer *gestureRecognizerForExclusionRelationship;
@end
/* posted when the viewer turns on or off (the text size enters or leaves the accessibility sizes) */
UIKIT_EXTERN NSNotificationName const UILargeContentViewerInteractionEnabledStatusDidChangeNotification NS_SWIFT_NAME(UILargeContentViewerInteraction.enabledStatusDidChangeNotification);
NS_SWIFT_UI_ACTOR
@protocol UILargeContentViewerInteractionDelegate <NSObject>
@optional
- (void)largeContentViewerInteraction:(UILargeContentViewerInteraction *)interaction didEndOnItem:(nullable id<UILargeContentViewerItem>)item atPoint:(CGPoint)point;
- (nullable id<UILargeContentViewerItem>)largeContentViewerInteraction:(UILargeContentViewerInteraction *)interaction itemAtPoint:(CGPoint)point;
/* the view controller whose view shows the viewer (centred); default: a system window over the app */
- (UIViewController *)viewControllerForLargeContentViewerInteraction:(UILargeContentViewerInteraction *)interaction NS_SWIFT_NAME(viewController(for:));
@end
NS_ASSUME_NONNULL_END
