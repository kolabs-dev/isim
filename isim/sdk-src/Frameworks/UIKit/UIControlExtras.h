#pragma once
/* isim: control members from the documentation sweep (#9): UIControl handlers and context menus, UIButton
   attributed titles, roles, hover and the configuration's subtitle / transformers / indicator, segment actions and
   metrics, stepper images, switch styles, progress views following an NSProgress. UIControlExtras.m (drawing hooks
   in UIControls.m). Categories (no ivars: the classes' sizes must not change for apps' subclasses). */
#import <UIKit/UIButton.h>
#import <UIKit/UISwitch.h>
#import <UIKit/UIMoreControls.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UINavigationExtras.h>      /* UIBehavioralStyle */
#import <UIKit/UIContextMenuInteraction.h>
NS_ASSUME_NONNULL_BEGIN
@class UIContextMenuConfiguration, UIContextMenuInteraction, UIPointerEffect, UIPointerShape, UIPointerStyle, NSProgress;

/* UIControl answers its context menu interaction (UIButton: its menu on a long press) */
@interface UIControl (UIControlExtras) <UIContextMenuInteractionDelegate>
/* leading / trailing resolved to left / right for the layout direction */
@property (nonatomic, readonly) UIControlContentHorizontalAlignment effectiveContentHorizontalAlignment;
- (void)removeActionForIdentifier:(UIActionIdentifier)actionIdentifier forControlEvents:(UIControlEvents)controlEvents NS_SWIFT_NAME(removeAction(identifiedBy:for:));
/* every action and target-action pair with its events (Swift: (UIAction?, (Any?, Selector)?, UIControl.Event, inout Bool)) */
- (void)enumerateEventHandlers:(void (NS_NOESCAPE ^)(UIAction *_Nullable actionHandler, id _Nullable target, SEL _Nullable action,
                                                       UIControlEvents controlEvents, BOOL *stop))iterator NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(14.0));
/* sends the primary action (UIControlEventPrimaryActionTriggered), as a tap does */
- (void)performPrimaryAction API_AVAILABLE(ios(17.4));
/* the control's context menu (a long press shows the menu its subclass gives for contextMenuInteraction:
   configurationForMenuAtLocation:; UIButton: its menu) */
@property (nonatomic, getter=isContextMenuInteractionEnabled) BOOL contextMenuInteractionEnabled API_AVAILABLE(ios(14.0));
@property (nullable, nonatomic, readonly) UIContextMenuInteraction *contextMenuInteraction API_AVAILABLE(ios(14.0));
@property (nonatomic) BOOL showsMenuAsPrimaryAction API_AVAILABLE(ios(14.0));
- (CGPoint)menuAttachmentPointForConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(14.0));
@end

/* the button's role (Mac Catalyst styles and alert-like ordering; iOS: stored) */
typedef NS_ENUM(NSInteger, UIButtonRole) { UIButtonRoleNormal, UIButtonRolePrimary, UIButtonRoleCancel, UIButtonRoleDestructive }
    NS_SWIFT_NAME(UIButton.Role) API_AVAILABLE(ios(14.0));
typedef UIPointerStyle *_Nullable (^UIButtonPointerStyleProvider)(UIButton *button, UIPointerEffect *proposedEffect, UIPointerShape *proposedShape)
    NS_SWIFT_NAME(UIButton.PointerStyleProvider) API_AVAILABLE(ios(13.4));
@interface UIButton (UIButtonExtras)
/* a system button with an image (a symbol in the tint colour) */
+ (instancetype)systemButtonWithImage:(UIImage *)image target:(nullable id)target action:(nullable SEL)action;
/* attributed titles per state: drawn instead of the plain title (the state's, else the normal one) */
- (void)setAttributedTitle:(nullable NSAttributedString *)title forState:(UIControlState)state;
- (nullable NSAttributedString *)attributedTitleForState:(UIControlState)state;
@property (nullable, nonatomic, readonly, strong) NSAttributedString *currentAttributedTitle;
@property (nullable, nonatomic, readonly, strong) UIColor *currentTitleShadowColor;
- (nullable UIImageSymbolConfiguration *)preferredSymbolConfigurationForImageInState:(UIControlState)state;
@property (nullable, nonatomic, readonly) UIImageSymbolConfiguration *currentPreferredSymbolConfiguration;
/* the configuration's subtitle, as a label (not in the view hierarchy: isim draws the button's content itself) */
@property (nullable, nonatomic, readonly, strong) UILabel *subtitleLabel API_AVAILABLE(ios(15.0));
/* the pointer is over the button (iPad pointer, `hover X Y`) */
@property (nonatomic, readonly, getter=isHovered) BOOL hovered API_AVAILABLE(ios(17.0));
/* a touch has stayed down on the button for half a second (until it lifts or leaves); configuration updates follow */
@property (nonatomic, readonly, getter=isHeld) BOOL held API_AVAILABLE(ios(15.0));
@property (nonatomic) UIButtonRole role API_AVAILABLE(ios(14.0));
@property (nullable, nonatomic, copy) UIButtonPointerStyleProvider pointerStyleProvider API_AVAILABLE(ios(13.4));   /* isim: stored */
@property (nonatomic) UIBehavioralStyle preferredBehavioralStyle API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) UIBehavioralStyle behavioralStyle API_AVAILABLE(ios(15.0));      /* iOS: pad */
@end

/* configurations' transformers (Swift: UIConfigurationTextAttributesTransformer and UIConfigurationColorTransformer,
   the UIKit overlay) */
typedef NSDictionary<NSAttributedStringKey, id> *_Nonnull (^UIConfigurationTextAttributesTransformer)(NSDictionary<NSAttributedStringKey, id> *textAttributes)
    NS_SWIFT_NAME(__UIConfigurationTextAttributesTransformer) API_AVAILABLE(ios(15.0));
typedef UIColor *_Nonnull (^UIConfigurationColorTransformer)(UIColor *color) NS_SWIFT_NAME(__UIConfigurationColorTransformer) API_AVAILABLE(ios(14.0));
UIKIT_EXTERN UIConfigurationColorTransformer const UIConfigurationColorTransformerGrayscale NS_SWIFT_NAME(__UIConfigurationColorTransformerGrayscale);
UIKIT_EXTERN UIConfigurationColorTransformer const UIConfigurationColorTransformerPreferredTint NS_SWIFT_NAME(__UIConfigurationColorTransformerPreferredTint);
UIKIT_EXTERN UIConfigurationColorTransformer const UIConfigurationColorTransformerMonochromeTint NS_SWIFT_NAME(__UIConfigurationColorTransformerMonochromeTint);
/* the indicator after the title: automatic (a pop-up indicator for a button that shows its menu and changes
   selection), none, or the pop-up chevrons */
typedef NS_ENUM(NSInteger, UIButtonConfigurationIndicator) { UIButtonConfigurationIndicatorAutomatic, UIButtonConfigurationIndicatorNone,
    UIButtonConfigurationIndicatorPopup } NS_SWIFT_NAME(UIButton.Configuration.Indicator) API_AVAILABLE(ios(15.0));
typedef NS_ENUM(NSInteger, UIButtonConfigurationMacIdiomStyle) { UIButtonConfigurationMacIdiomStyleAutomatic, UIButtonConfigurationMacIdiomStyleBordered,
    UIButtonConfigurationMacIdiomStyleBorderless, UIButtonConfigurationMacIdiomStyleBorderlessTinted } NS_SWIFT_NAME(UIButton.Configuration.MacIdiomStyle) API_AVAILABLE(ios(15.0));
@interface UIButtonConfiguration (UIButtonConfigurationExtras)
@property (nonatomic, copy, nullable) UIConfigurationTextAttributesTransformer titleTextAttributesTransformer NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, nullable) UIConfigurationTextAttributesTransformer subtitleTextAttributesTransformer NS_REFINED_FOR_SWIFT;
@property (nonatomic) NSLineBreakMode titleLineBreakMode;       /* isim: titles are one line, truncated at the tail */
@property (nonatomic) NSLineBreakMode subtitleLineBreakMode;
/* the room kept for the image along its axis (a smaller image is centred in it) */
@property (nonatomic) CGFloat imageReservation;
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer imageColorTransformer NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, nullable) UIImageSymbolConfiguration *preferredSymbolConfigurationForImage;
- (void)setDefaultContentInsets;
@property (nonatomic) UIButtonConfigurationIndicator indicator;
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer indicatorColorTransformer NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer activityIndicatorColorTransformer NS_REFINED_FOR_SWIFT;
/* a selected toggle button looks tinted (filled when the style is tinted) */
@property (nonatomic) BOOL automaticallyUpdateForSelection;
@property (nonatomic) UIButtonConfigurationMacIdiomStyle macIdiomStyle;   /* Mac Catalyst: stored */
@end

/* segments: content and divider metrics (isim: stored), segment widths and offsets, actions per segment */
typedef NS_ENUM(NSInteger, UISegmentedControlSegment) { UISegmentedControlSegmentAny = 0, UISegmentedControlSegmentLeft = 1,
    UISegmentedControlSegmentCenter = 2, UISegmentedControlSegmentRight = 3, UISegmentedControlSegmentAlone = 4 } NS_SWIFT_NAME(UISegmentedControl.Segment);
@interface UISegmentedControl (UISegmentedControlExtras)
- (instancetype)initWithFrame:(CGRect)frame actions:(NSArray<UIAction *> *)actions API_AVAILABLE(ios(14.0));
- (void)insertSegmentWithAction:(UIAction *)action atIndex:(NSUInteger)segment animated:(BOOL)animated API_AVAILABLE(ios(14.0));
- (void)setAction:(UIAction *)action forSegmentAtIndex:(NSUInteger)segment API_AVAILABLE(ios(14.0));
- (nullable UIAction *)actionForSegmentAtIndex:(NSUInteger)segment API_AVAILABLE(ios(14.0));
- (NSInteger)segmentIndexForActionIdentifier:(UIActionIdentifier)actionIdentifier NS_SWIFT_NAME(segmentIndex(identifiedBy:)) API_AVAILABLE(ios(14.0));
/* 0: sized by the control (equal, or by content) */
- (CGFloat)widthForSegmentAtIndex:(NSUInteger)segment;
- (void)setContentOffset:(CGSize)offset forSegmentAtIndex:(NSUInteger)segment;
- (CGSize)contentOffsetForSegmentAtIndex:(NSUInteger)segment;
- (void)setContentPositionAdjustment:(UIOffset)adjustment forSegmentType:(UISegmentedControlSegment)leftCenterRightOrAlone barMetrics:(UIBarMetrics)barMetrics;
- (UIOffset)contentPositionAdjustmentForSegmentType:(UISegmentedControlSegment)leftCenterRightOrAlone barMetrics:(UIBarMetrics)barMetrics;
- (void)setDividerImage:(nullable UIImage *)dividerImage forLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState barMetrics:(UIBarMetrics)barMetrics;
- (nullable UIImage *)dividerImageForLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState barMetrics:(UIBarMetrics)barMetrics;
@end

/* custom stepper images: the − and + glyphs per state (drawn instead of isim's), the divider (stored) */
@interface UIStepper (UIStepperExtras)
- (void)setIncrementImage:(nullable UIImage *)image forState:(UIControlState)state;
- (nullable UIImage *)incrementImageForState:(UIControlState)state;
- (void)setDecrementImage:(nullable UIImage *)image forState:(UIControlState)state;
- (nullable UIImage *)decrementImageForState:(UIControlState)state;
- (void)setDividerImage:(nullable UIImage *)image forLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState;
- (nullable UIImage *)dividerImageForLeftSegmentState:(UIControlState)state rightSegmentState:(UIControlState)state;
@end

/* switch styles: iOS always slides (the checkbox is Mac Catalyst's) */
typedef NS_ENUM(NSInteger, UISwitchStyle) { UISwitchStyleAutomatic = 0, UISwitchStyleCheckbox, UISwitchStyleSliding } NS_SWIFT_NAME(UISwitch.Style) API_AVAILABLE(ios(14.0));
@interface UISwitch (UISwitchExtras)
@property (nonatomic) UISwitchStyle preferredStyle API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly) UISwitchStyle style API_AVAILABLE(ios(14.0));
@property (nullable, nonatomic, copy) NSString *title API_AVAILABLE(ios(14.0));      /* the checkbox's title (stored) */
/* no effect since iOS 7 (stored) */
@property (nullable, nonatomic, strong) UIImage *onImage;
@property (nullable, nonatomic, strong) UIImage *offImage;
@end

@interface UISlider (UISliderExtras)
@property (nonatomic) UIBehavioralStyle preferredBehavioralStyle API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) UIBehavioralStyle behavioralStyle API_AVAILABLE(ios(15.0));      /* iOS: pad */
@end

@interface UIProgressView (UIProgressViewExtras)
/* the progress follows the NSProgress's fraction completed */
@property (nullable, nonatomic, strong) NSProgress *observedProgress API_AVAILABLE(ios(9.0));
/* images for the filled part and the track (stretched; drawn instead of the tint colours) */
@property (nullable, nonatomic, strong) UIImage *progressImage;
@property (nullable, nonatomic, strong) UIImage *trackImage;
@end

/* page controls: indicator images, layout direction, the background platter, continuous scrubbing, and a progress
   (a timer that advances the pages; the current indicator stretches into a bar filling with the progress) */
typedef NS_ENUM(NSInteger, UIPageControlInteractionState) { UIPageControlInteractionStateNone = 0, UIPageControlInteractionStateDiscrete = 1,
    UIPageControlInteractionStateContinuous = 2 } NS_SWIFT_NAME(UIPageControl.InteractionState) API_AVAILABLE(ios(14.0));
typedef NS_ENUM(NSInteger, UIPageControlBackgroundStyle) { UIPageControlBackgroundStyleAutomatic = 0, UIPageControlBackgroundStyleProminent = 1,
    UIPageControlBackgroundStyleMinimal = 2 } NS_SWIFT_NAME(UIPageControl.BackgroundStyle) API_AVAILABLE(ios(14.0));
typedef NS_ENUM(NSInteger, UIPageControlDirection) { UIPageControlDirectionNatural = 0, UIPageControlDirectionLeftToRight = 1, UIPageControlDirectionRightToLeft = 2,
    UIPageControlDirectionTopToBottom = 3, UIPageControlDirectionBottomToTop = 4 } NS_SWIFT_NAME(UIPageControl.Direction) API_AVAILABLE(ios(16.0));
@class UIPageControlProgress, UIPageControlTimerProgress;
NS_SWIFT_UI_ACTOR
@protocol UIPageControlProgressDelegate <NSObject>
@optional
- (void)pageControlProgressVisibilityDidChange:(UIPageControlProgress *)progress;
- (float)pageControlProgress:(UIPageControlProgress *)progress initialProgressForPage:(NSInteger)page;
@end
NS_SWIFT_UI_ACTOR
@protocol UIPageControlTimerProgressDelegate <UIPageControlProgressDelegate>
@optional
- (void)pageControlTimerProgressDidChange:(UIPageControlTimerProgress *)progress;
- (BOOL)pageControlTimerProgress:(UIPageControlTimerProgress *)progress shouldAdvanceToPage:(NSInteger)page;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UIPageControlProgress : NSObject
@property (nonatomic, weak, nullable) id<UIPageControlProgressDelegate> delegate;
/* the current page's progress, 0 to 1 */
@property (nonatomic) float currentProgress;
@property (nonatomic, readonly, getter=isProgressVisible) BOOL progressVisible;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UIPageControlTimerProgress : UIPageControlProgress
- (instancetype)initWithPreferredDuration:(NSTimeInterval)preferredDuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, weak, nullable) id<UIPageControlTimerProgressDelegate> delegate;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic) NSTimeInterval preferredDuration;
/* after the last page, start again from the first (else the timer stops) */
@property (nonatomic) BOOL resetsToInitialPageAfterEnd;
- (void)resumeTimer;
- (void)pauseTimer;
- (void)setDuration:(NSTimeInterval)duration forPage:(NSInteger)page;
- (NSTimeInterval)durationForPage:(NSInteger)page;
@end
@interface UIPageControl (UIPageControlExtras)
@property (nonatomic) UIPageControlBackgroundStyle backgroundStyle API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly) UIPageControlInteractionState interactionState API_AVAILABLE(ios(14.0));
/* dragging along the control scrubs through the pages */
@property (nonatomic) BOOL allowsContinuousInteraction API_AVAILABLE(ios(14.0));
@property (nonatomic) UIPageControlDirection direction API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, strong) UIImage *preferredIndicatorImage API_AVAILABLE(ios(14.0));
- (nullable UIImage *)indicatorImageForPage:(NSInteger)page API_AVAILABLE(ios(14.0));
- (void)setIndicatorImage:(nullable UIImage *)image forPage:(NSInteger)page API_AVAILABLE(ios(14.0));
@property (nullable, nonatomic, strong) UIImage *preferredCurrentPageIndicatorImage API_AVAILABLE(ios(16.0));
- (nullable UIImage *)currentPageIndicatorImageForPage:(NSInteger)page API_AVAILABLE(ios(16.0));
- (void)setCurrentPageIndicatorImage:(nullable UIImage *)image forPage:(NSInteger)page API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, strong) UIPageControlProgress *progress API_AVAILABLE(ios(16.0));
@end
NS_ASSUME_NONNULL_END
