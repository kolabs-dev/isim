#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: accessibility properties feed an accessibility tree that isim's VoiceOver simulation walks (Settings >
 * Accessibility > VoiceOver, script `voiceover on|off|next|prev|activate|increment|decrement|action|read|escape`):
 * a focus cursor is drawn around the element, its description is spoken with the host TTS (espeak-ng) and logged
 * ("isim: VoiceOver: ..."). Settings > Accessibility also sets Larger Text (Dynamic Type), Bold Text, Increase
 * Contrast, Reduce Motion and Reduce Transparency. The script driver uses accessibilityIdentifier (tapid). */
typedef uint64_t UIAccessibilityTraits NS_TYPED_ENUM;
UIKIT_EXTERN UIAccessibilityTraits const UIAccessibilityTraitNone, UIAccessibilityTraitButton, UIAccessibilityTraitLink,
    UIAccessibilityTraitHeader, UIAccessibilityTraitSearchField, UIAccessibilityTraitImage, UIAccessibilityTraitSelected,
    UIAccessibilityTraitPlaysSound, UIAccessibilityTraitKeyboardKey, UIAccessibilityTraitStaticText, UIAccessibilityTraitSummaryElement,
    UIAccessibilityTraitNotEnabled, UIAccessibilityTraitUpdatesFrequently, UIAccessibilityTraitAdjustable,
    UIAccessibilityTraitStartsMediaSession, UIAccessibilityTraitAllowsDirectInteraction, UIAccessibilityTraitCausesPageTurn,
    UIAccessibilityTraitTabBar, UIAccessibilityTraitToggleButton, UIAccessibilityTraitSupportsZoom;

typedef NS_ENUM(NSInteger, UIAccessibilityNavigationStyle) { UIAccessibilityNavigationStyleAutomatic = 0, UIAccessibilityNavigationStyleSeparate, UIAccessibilityNavigationStyleCombined };
typedef NS_ENUM(NSInteger, UIAccessibilityScrollDirection) { UIAccessibilityScrollDirectionRight = 1, UIAccessibilityScrollDirectionLeft, UIAccessibilityScrollDirectionUp, UIAccessibilityScrollDirectionDown, UIAccessibilityScrollDirectionNext, UIAccessibilityScrollDirectionPrevious };
@class UIAccessibilityCustomAction, UIAccessibilityCustomRotor, UIBezierPath, UIImage;

@interface NSObject (UIAccessibility)
@property (nonatomic) BOOL isAccessibilityElement;
@property (nullable, nonatomic, copy) NSString *accessibilityLabel;
@property (nullable, nonatomic, copy) NSString *accessibilityHint;
@property (nullable, nonatomic, copy) NSString *accessibilityValue;
@property (nonatomic) UIAccessibilityTraits accessibilityTraits;
@property (nonatomic) CGRect accessibilityFrame;                       /* screen coordinates; views: their frame */
@property (nullable, nonatomic, copy) UIBezierPath *accessibilityPath;
@property (nonatomic) CGPoint accessibilityActivationPoint;
@property (nullable, nonatomic, strong) NSString *accessibilityLanguage;
@property (nonatomic) BOOL accessibilityElementsHidden;
@property (nonatomic) BOOL accessibilityViewIsModal;
@property (nonatomic) BOOL shouldGroupAccessibilityChildren;
@property (nonatomic) BOOL accessibilityRespondsToUserInteraction;
@property (nonatomic) UIAccessibilityNavigationStyle accessibilityNavigationStyle;
@property (nullable, nonatomic, copy) NSArray<NSString *> *accessibilityUserInputLabels;
@end
@interface NSObject (UIAccessibilityContainer)
@property (nullable, nonatomic, strong) NSArray *accessibilityElements;     /* order VoiceOver visits, overriding geometry */
- (NSInteger)accessibilityElementCount;
- (nullable id)accessibilityElementAtIndex:(NSInteger)index;
- (NSInteger)indexOfAccessibilityElement:(id)element;
@end
@interface NSObject (UIAccessibilityAction)
- (BOOL)accessibilityActivate;
- (void)accessibilityIncrement;
- (void)accessibilityDecrement;
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction;
- (BOOL)accessibilityPerformEscape;
- (BOOL)accessibilityPerformMagicTap;
@property (nullable, nonatomic, strong) NSArray<UIAccessibilityCustomAction *> *accessibilityCustomActions;
@property (nullable, nonatomic, strong) NSArray<UIAccessibilityCustomRotor *> *accessibilityCustomRotors;
@end
@interface NSObject (UIAccessibilityFocus)
- (void)accessibilityElementDidBecomeFocused;
- (void)accessibilityElementDidLoseFocus;
- (BOOL)accessibilityElementIsFocused;
@end

NS_SWIFT_UI_ACTOR
@protocol UIAccessibilityIdentification <NSObject>
@required
@property (nullable, nonatomic, copy) NSString *accessibilityIdentifier;
@end
@interface UIView (UIAccessibilityIdentification) <UIAccessibilityIdentification>
@end

/* an element that is not a view (a drawn part of a view), placed in accessibilityElements of its container */
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityElement : NSObject <UIAccessibilityIdentification>
- (instancetype)initWithAccessibilityContainer:(id)container;
@property (nullable, nonatomic, weak) id accessibilityContainer;
@property (nonatomic) CGRect accessibilityFrameInContainerSpace;
@end

typedef BOOL (^UIAccessibilityCustomActionHandler)(UIAccessibilityCustomAction *customAction);
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityCustomAction : NSObject
- (instancetype)initWithName:(NSString *)name target:(nullable id)target selector:(SEL)selector;
- (instancetype)initWithName:(NSString *)name actionHandler:(UIAccessibilityCustomActionHandler)actionHandler;
@property (nonatomic, copy) NSString *name;
@property (nullable, nonatomic, weak) id target;
@property (nonatomic) SEL selector;
@property (nullable, nonatomic, copy) UIAccessibilityCustomActionHandler actionHandler;
@end

typedef NS_ENUM(NSInteger, UIAccessibilityCustomRotorDirection) { UIAccessibilityCustomRotorDirectionPrevious, UIAccessibilityCustomRotorDirectionNext };
@class UIAccessibilityCustomRotorItemResult, UIAccessibilityCustomRotorSearchPredicate, UITextRange;
typedef UIAccessibilityCustomRotorItemResult *_Nullable (^UIAccessibilityCustomRotorSearch)(UIAccessibilityCustomRotorSearchPredicate *predicate);
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityCustomRotorSearchPredicate : NSObject
@property (nonatomic, retain) UIAccessibilityCustomRotorItemResult *currentItem;
@property (nonatomic) UIAccessibilityCustomRotorDirection searchDirection;
@end
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityCustomRotorItemResult : NSObject
- (instancetype)initWithTargetElement:(id<NSObject>)targetElement targetRange:(nullable UITextRange *)targetRange;
@property (nullable, nonatomic, weak) id<NSObject> targetElement;
@property (nullable, nonatomic, retain) UITextRange *targetRange;
@end
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityCustomRotor : NSObject
- (instancetype)initWithName:(NSString *)name itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) UIAccessibilityCustomRotorSearch itemSearchBlock;
@end

/* notifications posted to assistive technologies (logged; spoken by isim's VoiceOver) */
typedef uint32_t UIAccessibilityNotifications;    /* Swift: UIAccessibility.Notification (UIKit+Input.swift) */
UIKIT_EXTERN UIAccessibilityNotifications const UIAccessibilityScreenChangedNotification, UIAccessibilityLayoutChangedNotification,
    UIAccessibilityAnnouncementNotification, UIAccessibilityPageScrolledNotification, UIAccessibilityPauseAssistiveTechnologyNotification,
    UIAccessibilityResumeAssistiveTechnologyNotification;
UIKIT_EXTERN void UIAccessibilityPostNotification(UIAccessibilityNotifications notification, id _Nullable argument);
UIKIT_EXTERN NSNotificationName const UIAccessibilityAnnouncementDidFinishNotification, UIAccessibilityElementFocusedNotification;
UIKIT_EXTERN NSString *const UIAccessibilityAnnouncementKeyStringValue, *const UIAccessibilityAnnouncementKeyWasSuccessful, *const UIAccessibilityFocusedElementKey;

/* settings (Settings > Accessibility) and their change notifications */
UIKIT_EXTERN BOOL UIAccessibilityIsVoiceOverRunning(void);
UIKIT_EXTERN BOOL UIAccessibilityIsReduceMotionEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsBoldTextEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsReduceTransparencyEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsDarkerSystemColorsEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityShouldDifferentiateWithoutColor(void);
UIKIT_EXTERN BOOL UIAccessibilityIsInvertColorsEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsGrayscaleEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsSwitchControlRunning(void);
UIKIT_EXTERN BOOL UIAccessibilityIsClosedCaptioningEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsOnOffSwitchLabelsEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityButtonShapesEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityPrefersCrossFadeTransitions(void);
UIKIT_EXTERN BOOL UIAccessibilityIsVideoAutoplayEnabled(void);
UIKIT_EXTERN NSNotificationName const UIAccessibilityVoiceOverStatusDidChangeNotification, UIAccessibilityReduceMotionStatusDidChangeNotification,
    UIAccessibilityBoldTextStatusDidChangeNotification, UIAccessibilityReduceTransparencyStatusDidChangeNotification,
    UIAccessibilityDarkerSystemColorsStatusDidChangeNotification, UIAccessibilityDifferentiateWithoutColorDidChangeNotification;

/* Large Content Viewer: at accessibility text sizes, a long press over an item shows it big in the middle */
@protocol UILargeContentViewerItem <NSObject>
@property (nonatomic, readonly) BOOL showsLargeContentViewer;
@property (nullable, nonatomic, readonly) NSString *largeContentTitle;
@property (nullable, nonatomic, readonly) UIImage *largeContentImage;
@end
@class UILargeContentViewerInteraction;
@interface UIView (UILargeContentViewer) <UILargeContentViewerItem>
@property (nonatomic, readwrite) BOOL showsLargeContentViewer;
@property (nullable, nonatomic, readwrite, copy) NSString *largeContentTitle;
@property (nullable, nonatomic, readwrite, strong) UIImage *largeContentImage;
@end
NS_ASSUME_NONNULL_END
