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
@class UIAccessibilityCustomAction, UIAccessibilityCustomRotor, UIBezierPath, UIImage, UIResponder;
typedef NSString *UIAccessibilityAssistiveTechnologyIdentifier NS_TYPED_ENUM;

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
/* the assistive technologies focused on the element (VoiceOver, Switch Control) */
- (nullable NSSet<UIAccessibilityAssistiveTechnologyIdentifier> *)accessibilityAssistiveTechnologyFocusedIdentifiers API_AVAILABLE(ios(9.0));
@end

/* ---- containers: their kind, data tables ---- */
typedef NS_ENUM(NSInteger, UIAccessibilityContainerType) {
    UIAccessibilityContainerTypeNone = 0, UIAccessibilityContainerTypeDataTable, UIAccessibilityContainerTypeList,
    UIAccessibilityContainerTypeLandmark, UIAccessibilityContainerTypeSemanticGroup API_AVAILABLE(ios(13.0)) } API_AVAILABLE(ios(11.0));
/* the cells of a data table container: VoiceOver says their row and column */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIAccessibilityContainerDataTableCell <NSObject>
@required
- (NSRange)accessibilityRowRange;
- (NSRange)accessibilityColumnRange;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIAccessibilityContainerDataTable <NSObject>
@required
- (nullable id<UIAccessibilityContainerDataTableCell>)accessibilityDataTableCellElementForRow:(NSUInteger)row column:(NSUInteger)column;
- (NSUInteger)accessibilityRowCount;
- (NSUInteger)accessibilityColumnCount;
@optional
- (nullable NSArray<id<UIAccessibilityContainerDataTableCell>> *)accessibilityHeaderElementsForRow:(NSUInteger)row;
- (nullable NSArray<id<UIAccessibilityContainerDataTableCell>> *)accessibilityHeaderElementsForColumn:(NSUInteger)column;
@end
/* elements that hold pages of text read line by line (VoiceOver's "read" command reads the page content) */
NS_SWIFT_UI_ACTOR
@protocol UIAccessibilityReadingContent
@required
- (NSInteger)accessibilityLineNumberForPoint:(CGPoint)point;
- (nullable NSString *)accessibilityContentForLineNumber:(NSInteger)lineNumber;
- (CGRect)accessibilityFrameForLineNumber:(NSInteger)lineNumber;
- (nullable NSString *)accessibilityPageContent;
@optional
- (nullable NSAttributedString *)accessibilityAttributedContentForLineNumber:(NSInteger)lineNumber API_AVAILABLE(ios(11.0));
- (nullable NSAttributedString *)accessibilityAttributedPageContent API_AVAILABLE(ios(11.0));
@end
/* image views and buttons draw their images larger at the accessibility text sizes */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIAccessibilityContentSizeCategoryImageAdjusting <NSObject>
@property (nonatomic) BOOL adjustsImageSizeForAccessibilityContentSizeCategory;
@end

/* ---- the kind of text an element holds (VoiceOver reads punctuation in source code, spreadsheets cell by cell…) ---- */
typedef NSString *UIAccessibilityTextualContext NS_TYPED_ENUM API_AVAILABLE(ios(13.0));
UIKIT_EXTERN UIAccessibilityTextualContext const UIAccessibilityTextualContextWordProcessing, UIAccessibilityTextualContextNarrative,
    UIAccessibilityTextualContextMessaging, UIAccessibilityTextualContextSpreadsheet, UIAccessibilityTextualContextFileSystem,
    UIAccessibilityTextualContextSourceCode, UIAccessibilityTextualContextConsole;
/* iOS 18: disclosure state VoiceOver speaks ("expanded" / "collapsed") */
typedef NS_ENUM(NSInteger, UIAccessibilityExpandedStatus) {
    UIAccessibilityExpandedStatusUnsupported = 0, UIAccessibilityExpandedStatusExpanded, UIAccessibilityExpandedStatusCollapsed } API_AVAILABLE(ios(18.0));
/* iOS 17: direct touch (allowsDirectInteraction) behaviour under VoiceOver */
typedef NS_OPTIONS(NSUInteger, UIAccessibilityDirectTouchOptions) {
    UIAccessibilityDirectTouchOptionNone = 0, UIAccessibilityDirectTouchOptionSilentOnTouch = 1 << 0,
    UIAccessibilityDirectTouchOptionRequiresActivation = 1 << 1 } API_AVAILABLE(ios(17.0));
/* announcement priorities (the UIAccessibilitySpeechAttributeAnnouncementPriority of an announcement) */
typedef NSString *UIAccessibilityPriority NS_TYPED_ENUM API_AVAILABLE(ios(17.0));
UIKIT_EXTERN UIAccessibilityPriority const UIAccessibilityPriorityHigh, UIAccessibilityPriorityDefault, UIAccessibilityPriorityLow API_AVAILABLE(ios(17.0));
/* speech attributes of attributed labels, values, hints and announcements (isim's VoiceOver reads
   SpellOut ranges letter by letter, says heading levels and logs an announcement's priority and queueing; punctuation,
   language, pitch and IPA notation are kept but not used by its speech) */
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributePunctuation NS_SWIFT_NAME(accessibilitySpeechPunctuation);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributeLanguage NS_SWIFT_NAME(accessibilitySpeechLanguage);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributePitch NS_SWIFT_NAME(accessibilitySpeechPitch);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributeQueueAnnouncement NS_SWIFT_NAME(accessibilitySpeechQueueAnnouncement);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributeIPANotation NS_SWIFT_NAME(accessibilitySpeechIPANotation);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributeSpellOut NS_SWIFT_NAME(accessibilitySpeechSpellOut);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilitySpeechAttributeAnnouncementPriority NS_SWIFT_NAME(accessibilitySpeechAnnouncementPriority) API_AVAILABLE(ios(17.0));
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilityTextAttributeHeadingLevel NS_SWIFT_NAME(accessibilityTextHeadingLevel);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilityTextAttributeCustom NS_SWIFT_NAME(accessibilityTextCustom);
UIKIT_EXTERN NSAttributedStringKey const UIAccessibilityTextAttributeContext NS_SWIFT_NAME(accessibilityTextualContext);

/* drag and drop for assistive technologies: where an element can be dragged from or dropped on */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@interface UIAccessibilityLocationDescriptor : NSObject
- (instancetype)initWithName:(NSString *)name view:(UIView *)view;
- (instancetype)initWithName:(NSString *)name point:(CGPoint)point inView:(UIView *)view;
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName point:(CGPoint)point inView:(UIView *)view NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, weak) UIView *view;
@property (nonatomic, readonly) CGPoint point;
@property (nonatomic, readonly, strong) NSString *name;
@property (nonatomic, readonly, strong) NSAttributedString *attributedName;
@end

/* iOS 17 block-based accessibility: a block set on an element answers the property instead of the stored value */
@class UIAccessibilityCustomAction, UIAccessibilityCustomRotor;
@protocol UITextInput;
typedef BOOL (^AXBoolReturnBlock)(void);
typedef NSString *_Nullable (^AXStringReturnBlock)(void);
typedef NSArray<NSString *> *_Nullable (^AXStringArrayReturnBlock)(void);
typedef NSAttributedString *_Nullable (^AXAttributedStringReturnBlock)(void);
typedef NSArray<NSAttributedString *> *_Nullable (^AXAttributedStringArrayReturnBlock)(void);
typedef CGRect (^AXRectReturnBlock)(void);
typedef UIBezierPath *_Nullable (^AXPathReturnBlock)(void);
typedef CGPoint (^AXPointReturnBlock)(void);
typedef id _Nullable (^AXObjectReturnBlock)(void);
typedef NSArray *_Nullable (^AXArrayReturnBlock)(void);
typedef void (^AXVoidReturnBlock)(void);
typedef UIAccessibilityTraits (^AXTraitsReturnBlock)(void);
typedef UIAccessibilityNavigationStyle (^AXNavigationStyleReturnBlock)(void);
typedef UIAccessibilityContainerType (^AXContainerTypeReturnBlock)(void);
typedef UIAccessibilityTextualContext _Nullable (^AXTextualContextReturnBlock)(void);
typedef NSArray<UIAccessibilityCustomAction *> *_Nullable (^AXCustomActionsReturnBlock)(void);
typedef NSArray<UIAccessibilityCustomRotor *> *_Nullable (^AXCustomRotorsReturnBlock)(void) API_AVAILABLE(ios(17.0));
typedef UIResponder<UITextInput> *_Nullable (^AXUITextInputReturnBlock)(void) API_AVAILABLE(ios(18.1));
@interface NSObject (UIAccessibilityAttributes)
@property (nullable, nonatomic, copy) NSAttributedString *accessibilityAttributedLabel API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, copy) NSAttributedString *accessibilityAttributedHint API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, copy) NSAttributedString *accessibilityAttributedValue API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, copy) NSArray<NSAttributedString *> *accessibilityAttributedUserInputLabels API_AVAILABLE(ios(13.0));
@property (nullable, nonatomic, strong) UIAccessibilityTextualContext accessibilityTextualContext API_AVAILABLE(ios(13.0));
@property (nonatomic) UIAccessibilityContainerType accessibilityContainerType API_AVAILABLE(ios(11.0));
@property (nonatomic) UIAccessibilityExpandedStatus accessibilityExpandedStatus API_AVAILABLE(ios(18.0));
@property (nonatomic) UIAccessibilityDirectTouchOptions accessibilityDirectTouchOptions API_AVAILABLE(ios(17.0));
/* the row / column headers of a data table cell */
@property (nullable, nonatomic, strong) NSArray *accessibilityHeaderElements API_AVAILABLE(ios(11.0));
/* where reading continues in text split over several elements */
@property (nullable, nonatomic, weak) id accessibilityNextTextNavigationElement API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, weak) id accessibilityPreviousTextNavigationElement API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, weak) UIResponder<UITextInput> *accessibilityTextInputResponder API_AVAILABLE(ios(18.1));
@property (nullable, nonatomic, copy) NSArray<UIAccessibilityLocationDescriptor *> *accessibilityDragSourceDescriptors API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, copy) NSArray<UIAccessibilityLocationDescriptor *> *accessibilityDropPointDescriptors API_AVAILABLE(ios(11.0));
/* elements UI tests see (XCUITest; isim's dump) in addition to the accessibility elements (iOS 17) */
@property (nullable, nonatomic, strong) NSArray *automationElements API_AVAILABLE(ios(17.0));
/* the element under a point in the receiver (screen coordinates; default: the accessibility element there) */
- (nullable id)accessibilityHitTest:(CGPoint)point withEvent:(nullable UIEvent *)event API_AVAILABLE(ios(18.0));
/* Zoom asks an element to zoom in or out (isim has no Zoom: never called) */
- (BOOL)accessibilityZoomInAtPoint:(CGPoint)point API_AVAILABLE(ios(17.0));
- (BOOL)accessibilityZoomOutAtPoint:(CGPoint)point API_AVAILABLE(ios(17.0));
/* the blocks */
@property (nullable, nonatomic, copy) AXBoolReturnBlock isAccessibilityElementBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityLabelBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedLabelBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityHintBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedHintBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityValueBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXAttributedStringReturnBlock accessibilityAttributedValueBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXTraitsReturnBlock accessibilityTraitsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityIdentifierBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXStringReturnBlock accessibilityLanguageBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXStringArrayReturnBlock accessibilityUserInputLabelsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXAttributedStringArrayReturnBlock accessibilityAttributedUserInputLabelsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXTextualContextReturnBlock accessibilityTextualContextBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXRectReturnBlock accessibilityFrameBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXPathReturnBlock accessibilityPathBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXPointReturnBlock accessibilityActivationPointBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityElementsHiddenBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityViewIsModalBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityShouldGroupAccessibilityChildrenBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityRespondsToUserInteractionBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXNavigationStyleReturnBlock accessibilityNavigationStyleBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXArrayReturnBlock accessibilityElementsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXContainerTypeReturnBlock accessibilityContainerTypeBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXArrayReturnBlock accessibilityHeaderElementsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityActivateBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXVoidReturnBlock accessibilityIncrementBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXVoidReturnBlock accessibilityDecrementBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityPerformEscapeBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXBoolReturnBlock accessibilityMagicTapBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXCustomActionsReturnBlock accessibilityCustomActionsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) AXCustomRotorsReturnBlock accessibilityCustomRotorsBlock API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) UIAccessibilityExpandedStatus (^accessibilityExpandedStatusBlock)(void) API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, copy) AXObjectReturnBlock accessibilityNextTextNavigationElementBlock API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, copy) AXObjectReturnBlock accessibilityPreviousTextNavigationElementBlock API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, copy) AXUITextInputReturnBlock accessibilityTextInputResponderBlock API_AVAILABLE(ios(18.1));
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
UIKIT_EXTERN NSString *const UIAccessibilityCustomActionCategoryEdit NS_SWIFT_NAME(UIAccessibilityCustomAction.editCategory) API_AVAILABLE(ios(18.0));
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityCustomAction : NSObject
- (instancetype)initWithName:(NSString *)name target:(nullable id)target selector:(SEL)selector;
- (instancetype)initWithName:(NSString *)name actionHandler:(UIAccessibilityCustomActionHandler)actionHandler;
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName target:(nullable id)target selector:(SEL)selector API_AVAILABLE(ios(11.0));
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName actionHandler:(UIAccessibilityCustomActionHandler)actionHandler API_AVAILABLE(ios(13.0));
- (instancetype)initWithName:(NSString *)name image:(nullable UIImage *)image target:(nullable id)target selector:(SEL)selector API_AVAILABLE(ios(14.0));
- (instancetype)initWithName:(NSString *)name image:(nullable UIImage *)image actionHandler:(UIAccessibilityCustomActionHandler)actionHandler API_AVAILABLE(ios(14.0));
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName image:(nullable UIImage *)image target:(nullable id)target selector:(SEL)selector API_AVAILABLE(ios(14.0));
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName image:(nullable UIImage *)image actionHandler:(UIAccessibilityCustomActionHandler)actionHandler API_AVAILABLE(ios(14.0));
@property (nonatomic, copy) NSAttributedString *attributedName API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, strong) UIImage *image API_AVAILABLE(ios(14.0));
/* iOS 18: the group VoiceOver lists the action in (the edit category: cut / copy / paste-like actions) */
@property (nullable, nonatomic, copy) NSString *category API_AVAILABLE(ios(18.0));
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
typedef NS_ENUM(NSInteger, UIAccessibilityCustomSystemRotorType) {
    UIAccessibilityCustomSystemRotorTypeNone = 0, UIAccessibilityCustomSystemRotorTypeLink, UIAccessibilityCustomSystemRotorTypeVisitedLink,
    UIAccessibilityCustomSystemRotorTypeHeading, UIAccessibilityCustomSystemRotorTypeHeadingLevel1, UIAccessibilityCustomSystemRotorTypeHeadingLevel2,
    UIAccessibilityCustomSystemRotorTypeHeadingLevel3, UIAccessibilityCustomSystemRotorTypeHeadingLevel4, UIAccessibilityCustomSystemRotorTypeHeadingLevel5,
    UIAccessibilityCustomSystemRotorTypeHeadingLevel6, UIAccessibilityCustomSystemRotorTypeBoldText, UIAccessibilityCustomSystemRotorTypeItalicText,
    UIAccessibilityCustomSystemRotorTypeUnderlineText, UIAccessibilityCustomSystemRotorTypeMisspelledWord, UIAccessibilityCustomSystemRotorTypeImage,
    UIAccessibilityCustomSystemRotorTypeTextField, UIAccessibilityCustomSystemRotorTypeTable, UIAccessibilityCustomSystemRotorTypeList,
    UIAccessibilityCustomSystemRotorTypeLandmark } NS_SWIFT_NAME(UIAccessibilityCustomRotor.SystemRotorType) API_AVAILABLE(ios(11.0));
NS_SWIFT_UI_ACTOR
@interface UIAccessibilityCustomRotor : NSObject
- (instancetype)initWithName:(NSString *)name itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock;
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock API_AVAILABLE(ios(11.0));
/* takes the place of VoiceOver's own rotor of that type (named like it) */
- (instancetype)initWithSystemType:(UIAccessibilityCustomSystemRotorType)type itemSearchBlock:(UIAccessibilityCustomRotorSearch)itemSearchBlock API_AVAILABLE(ios(11.0));
@property (nonatomic, copy) NSAttributedString *attributedName API_AVAILABLE(ios(11.0));
@property (nonatomic, readonly) UIAccessibilityCustomSystemRotorType systemRotorType API_AVAILABLE(ios(11.0));
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
/* Apple's name of the Increase Contrast setting (UIAccessibilityIsDarkerSystemColorsEnabled is isim's older name) */
UIKIT_EXTERN BOOL UIAccessibilityDarkerSystemColorsEnabled(void);
/* Guided Access (script `guidedaccess on|off`), Mono Audio, Speak Screen / Selection, AssistiveTouch, Shake to Undo
   (Settings > Accessibility; isim keeps them as device preferences) */
UIKIT_EXTERN BOOL UIAccessibilityIsGuidedAccessEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsMonoAudioEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsSpeakScreenEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsSpeakSelectionEnabled(void);
UIKIT_EXTERN BOOL UIAccessibilityIsAssistiveTouchRunning(void);
UIKIT_EXTERN BOOL UIAccessibilityIsShakeToUndoEnabled(void);
typedef NS_OPTIONS(NSUInteger, UIAccessibilityHearingDeviceEar) {
    UIAccessibilityHearingDeviceEarNone = 0, UIAccessibilityHearingDeviceEarLeft = 1 << 1, UIAccessibilityHearingDeviceEarRight = 1 << 2,
    UIAccessibilityHearingDeviceEarBoth = UIAccessibilityHearingDeviceEarLeft | UIAccessibilityHearingDeviceEarRight };
/* isim has no hearing devices: none */
UIKIT_EXTERN UIAccessibilityHearingDeviceEar UIAccessibilityHearingDevicePairedEar(void);
UIKIT_EXTERN NSNotificationName const UIAccessibilitySwitchControlStatusDidChangeNotification;   /* isim: Settings > Accessibility > Switch Control, script `switchcontrol` */
UIKIT_EXTERN NSNotificationName const UIAccessibilityVoiceOverStatusDidChangeNotification, UIAccessibilityReduceMotionStatusDidChangeNotification,
    UIAccessibilityBoldTextStatusDidChangeNotification, UIAccessibilityReduceTransparencyStatusDidChangeNotification,
    UIAccessibilityDarkerSystemColorsStatusDidChangeNotification, UIAccessibilityDifferentiateWithoutColorDidChangeNotification;
/* (UIAccessibilityDifferentiateWithoutColorDidChangeNotification is isim's older name of Apple's
   UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification; both are posted) */
UIKIT_EXTERN NSNotificationName const UIAccessibilityButtonShapesEnabledStatusDidChangeNotification API_AVAILABLE(ios(14.0));
UIKIT_EXTERN NSNotificationName const UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification,
    UIAccessibilityClosedCaptioningStatusDidChangeNotification, UIAccessibilityGrayscaleStatusDidChangeNotification,
    UIAccessibilityInvertColorsStatusDidChangeNotification, UIAccessibilityAssistiveTouchStatusDidChangeNotification,
    UIAccessibilityGuidedAccessStatusDidChangeNotification, UIAccessibilityMonoAudioStatusDidChangeNotification,
    UIAccessibilitySpeakScreenStatusDidChangeNotification, UIAccessibilitySpeakSelectionStatusDidChangeNotification,
    UIAccessibilityHearingDevicePairedEarDidChangeNotification, UIAccessibilityShakeToUndoDidChangeNotification,
    UIAccessibilityVideoAutoplayStatusDidChangeNotification, UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification,
    UIAccessibilityOnOffSwitchLabelsDidChangeNotification;
/* element focus notifications' extra keys and the assistive technology identifiers */
UIKIT_EXTERN NSString *const UIAccessibilityUnfocusedElementKey, *const UIAccessibilityAssistiveTechnologyKey;
UIKIT_EXTERN UIAccessibilityAssistiveTechnologyIdentifier const UIAccessibilityNotificationSwitchControlIdentifier NS_SWIFT_NAME(UIAccessibilityAssistiveTechnologyIdentifier.notificationSwitchControl);
UIKIT_EXTERN UIAccessibilityAssistiveTechnologyIdentifier const UIAccessibilityNotificationVoiceOverIdentifier NS_SWIFT_NAME(UIAccessibilityAssistiveTechnologyIdentifier.notificationVoiceOver);
/* the element an assistive technology has focused (nil: any of them) */
UIKIT_EXTERN id _Nullable UIAccessibilityFocusedElement(UIAccessibilityAssistiveTechnologyIdentifier _Nullable assistiveTechnologyIdentifier);
/* screen coordinates of a rect or path in a view (accessibilityFrame / accessibilityPath are in screen coordinates) */
UIKIT_EXTERN CGRect UIAccessibilityConvertFrameToScreenCoordinates(CGRect rect, UIView *view);
UIKIT_EXTERN UIBezierPath *UIAccessibilityConvertPathToScreenCoordinates(UIBezierPath *path, UIView *view);
/* Zoom: isim has no Zoom feature, so these only log */
typedef NS_ENUM(NSInteger, UIAccessibilityZoomType) { UIAccessibilityZoomTypeInsertionPoint };
UIKIT_EXTERN void UIAccessibilityZoomFocusChanged(UIAccessibilityZoomType type, CGRect frame, UIView *view);
UIKIT_EXTERN void UIAccessibilityRegisterGestureConflictWithZoom(void);

/* ---- Guided Access ----
   isim: script `guidedaccess on|off` starts and ends a session; `guidedaccess restrict ID allow|deny` changes one of
   the app delegate's restrictions (UIGuidedAccessRestrictionDelegate). requestGuidedAccessSession works as on a
   supervised device configured for Autonomous Single App Mode (adapted); configureForGuidedAccess logs the features. */
typedef NS_ENUM(NSInteger, UIGuidedAccessRestrictionState) { UIGuidedAccessRestrictionStateAllow, UIGuidedAccessRestrictionStateDeny };
NS_SWIFT_UI_ACTOR
@protocol UIGuidedAccessRestrictionDelegate <NSObject>
@required
@property (nonatomic, readonly, nullable) NSArray<NSString *> *guidedAccessRestrictionIdentifiers;
- (void)guidedAccessRestrictionWithIdentifier:(NSString *)restrictionIdentifier didChangeState:(UIGuidedAccessRestrictionState)newRestrictionState;
- (nullable NSString *)textForGuidedAccessRestrictionWithIdentifier:(NSString *)restrictionIdentifier;
@optional
- (nullable NSString *)detailTextForGuidedAccessRestrictionWithIdentifier:(NSString *)restrictionIdentifier;
@end
UIKIT_EXTERN UIGuidedAccessRestrictionState UIGuidedAccessRestrictionStateForIdentifier(NSString *restrictionIdentifier);
UIKIT_EXTERN void UIAccessibilityRequestGuidedAccessSession(BOOL enable, void (^completionHandler)(BOOL didSucceed));
typedef NS_OPTIONS(NSUInteger, UIGuidedAccessAccessibilityFeature) {
    UIGuidedAccessAccessibilityFeatureVoiceOver = 1 << 0, UIGuidedAccessAccessibilityFeatureZoom = 1 << 1,
    UIGuidedAccessAccessibilityFeatureAssistiveTouch = 1 << 2, UIGuidedAccessAccessibilityFeatureInvertColors = 1 << 3,
    UIGuidedAccessAccessibilityFeatureGrayscaleDisplay = 1 << 4 } API_AVAILABLE(ios(12.2));
UIKIT_EXTERN NSErrorDomain const UIGuidedAccessErrorDomain API_AVAILABLE(ios(12.2));
typedef NS_ERROR_ENUM(UIGuidedAccessErrorDomain, UIGuidedAccessErrorCode) { UIGuidedAccessErrorPermissionDenied, UIGuidedAccessErrorFailed = NSIntegerMax };
/* only during a Guided Access session (else UIGuidedAccessErrorPermissionDenied) */
UIKIT_EXTERN void UIGuidedAccessConfigureAccessibilityFeatures(UIGuidedAccessAccessibilityFeature features, BOOL enabled,
    void (^completion)(BOOL success, NSError *_Nullable error)) API_AVAILABLE(ios(12.2));

/* Large Content Viewer: at accessibility text sizes, a long press over an item shows it big in the middle */
NS_SWIFT_UI_ACTOR
@protocol UILargeContentViewerItem <NSObject>
@property (nonatomic, readonly) BOOL showsLargeContentViewer;
@property (nullable, nonatomic, readonly) NSString *largeContentTitle;
@property (nullable, nonatomic, readonly) UIImage *largeContentImage;
/* fitted to the viewer's image area (symbol images always are); else drawn at its own size */
@property (nonatomic, readonly) BOOL scalesLargeContentImage;
/* move the image for visual centring */
@property (nonatomic, readonly) UIEdgeInsets largeContentImageInsets;
@end
@class UILargeContentViewerInteraction;
@interface UIView (UILargeContentViewer) <UILargeContentViewerItem>
@property (nonatomic, readwrite) BOOL showsLargeContentViewer;
@property (nullable, nonatomic, readwrite, copy) NSString *largeContentTitle;
@property (nullable, nonatomic, readwrite, strong) UIImage *largeContentImage;
@property (nonatomic, readwrite) BOOL scalesLargeContentImage;
@property (nonatomic, readwrite) UIEdgeInsets largeContentImageInsets;
@end
NS_ASSUME_NONNULL_END
