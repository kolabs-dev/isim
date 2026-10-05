#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: accessibility properties are stored and used by isim's scripted test driver
 * (ISIM_SCRIPT "tapid <identifier>"); there is no VoiceOver. */
typedef uint64_t UIAccessibilityTraits NS_TYPED_ENUM;
UIKIT_EXTERN UIAccessibilityTraits const UIAccessibilityTraitNone, UIAccessibilityTraitButton, UIAccessibilityTraitLink,
    UIAccessibilityTraitHeader, UIAccessibilityTraitSearchField, UIAccessibilityTraitImage, UIAccessibilityTraitSelected,
    UIAccessibilityTraitPlaysSound, UIAccessibilityTraitKeyboardKey, UIAccessibilityTraitStaticText, UIAccessibilityTraitSummaryElement,
    UIAccessibilityTraitNotEnabled, UIAccessibilityTraitUpdatesFrequently, UIAccessibilityTraitAdjustable;
@interface NSObject (UIAccessibility)
@property (nonatomic) BOOL isAccessibilityElement;
@property (nullable, nonatomic, copy) NSString *accessibilityLabel;
@property (nullable, nonatomic, copy) NSString *accessibilityHint;
@property (nullable, nonatomic, copy) NSString *accessibilityValue;
@property (nonatomic) UIAccessibilityTraits accessibilityTraits;
@property (nonatomic) BOOL accessibilityElementsHidden;
@property (nonatomic) BOOL accessibilityViewIsModal;
@end
NS_SWIFT_UI_ACTOR
@protocol UIAccessibilityIdentification <NSObject>
@required
@property (nullable, nonatomic, copy) NSString *accessibilityIdentifier;
@end
@interface UIView (UIAccessibilityIdentification) <UIAccessibilityIdentification>
@end
UIKIT_EXTERN BOOL UIAccessibilityIsVoiceOverRunning(void);
UIKIT_EXTERN BOOL UIAccessibilityIsReduceMotionEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsBoldTextEnabled(void);
NS_ASSUME_NONNULL_END
