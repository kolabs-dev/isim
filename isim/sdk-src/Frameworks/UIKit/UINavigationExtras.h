#pragma once
/* isim: bar item, bar button item, navigation bar, navigation item and navigation controller members from the
   documentation sweep (#9): legacy bar item images and metrics, customizable item groups, the back button display
   mode and back action, the title menu and renaming, document properties, hiding the bars on tap / swipe / keyboard /
   compact height. UINavigation.m. Categories (no ivars: the classes' sizes must not change for apps' subclasses). */
#import <UIKit/UINavigationController.h>
#import <UIKit/UIActivityViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UITapGestureRecognizer, UIPanGestureRecognizer, LPLinkMetadata;

/* the behaviour a control takes; on iOS always the iPad style (the Mac style is for Mac Catalyst) */
typedef NS_ENUM(NSUInteger, UIBehavioralStyle) { UIBehavioralStyleAutomatic = 0, UIBehavioralStylePad, UIBehavioralStyleMac } API_AVAILABLE(ios(15.0));
/* the size of a bar item in a Mac Catalyst NSToolbar (not used on iOS) */
/* legacy images for landscape iPhone bars and the large content viewer, and image insets (stored: isim's bars use
   the image, laid out by the bar) */
@interface UIBarItem (UIBarItemExtras)
@property (nullable, nonatomic, strong) UIImage *landscapeImagePhone;
@property (nonatomic) UIEdgeInsets landscapeImagePhoneInsets;
@property (nullable, nonatomic, strong) UIImage *largeContentSizeImage API_AVAILABLE(ios(11.0));
@property (nonatomic) UIEdgeInsets largeContentSizeImageInsets API_AVAILABLE(ios(11.0));
@property (nonatomic) UIEdgeInsets imageInsets;
@end

@interface UIBarButtonItem (UIPopoverPresentationControllerSourceItem) <UIPopoverPresentationControllerSourceItem>
@end
@interface UIBarButtonItem (UIBarButtonItemExtras)
/* a fixed space of the system width: under iOS 26 it splits the items around it into separate glass groups */
+ (instancetype)fixedSpaceItem NS_SWIFT_NAME(fixedSpace()) API_AVAILABLE(ios(14.0));
/* customizable groups of this one item (iOS 16): fixed groups always show; movable ones can be rearranged; optional
   ones can be removed (one left out of the default customization is not shown: isim has no customization UI) */
- (UIBarButtonItemGroup *)creatingFixedGroup API_AVAILABLE(ios(16.0));
- (UIBarButtonItemGroup *)creatingMovableGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier NS_SWIFT_NAME(creatingMovableGroup(customizationIdentifier:)) API_AVAILABLE(ios(16.0));
- (UIBarButtonItemGroup *)creatingOptionalGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier inDefaultCustomization:(BOOL)inDefaultCustomization
    NS_SWIFT_NAME(__creatingOptionalGroup(customizationIdentifier:isInDefaultCustomization:)) /* (overlay: defaults) */ API_AVAILABLE(ios(16.0));
/* the titles the item may show (UIKit sizes it for the widest; isim: stored) */
@property (nullable, nonatomic, copy) NSSet<NSString *> *possibleTitles;
/* legacy appearance metrics (stored) */
- (void)setBackButtonBackgroundImage:(nullable UIImage *)backgroundImage forState:(UIControlState)state barMetrics:(UIBarMetrics)barMetrics;
- (nullable UIImage *)backButtonBackgroundImageForState:(UIControlState)state barMetrics:(UIBarMetrics)barMetrics;
- (void)setBackButtonTitlePositionAdjustment:(UIOffset)adjustment forBarMetrics:(UIBarMetrics)barMetrics;
- (UIOffset)backButtonTitlePositionAdjustmentForBarMetrics:(UIBarMetrics)barMetrics;
- (void)setBackButtonBackgroundVerticalPositionAdjustment:(CGFloat)adjustment forBarMetrics:(UIBarMetrics)barMetrics;
- (CGFloat)backButtonBackgroundVerticalPositionAdjustmentForBarMetrics:(UIBarMetrics)barMetrics;
- (void)setBackgroundVerticalPositionAdjustment:(CGFloat)adjustment forBarMetrics:(UIBarMetrics)barMetrics;
- (CGFloat)backgroundVerticalPositionAdjustmentForBarMetrics:(UIBarMetrics)barMetrics;
- (void)setTitlePositionAdjustment:(UIOffset)adjustment forBarMetrics:(UIBarMetrics)barMetrics;
- (UIOffset)titlePositionAdjustmentForBarMetrics:(UIBarMetrics)barMetrics;
/* symbol effects when the image changes (stored), the element standing for the item in an overflow menu, and iOS 26
   padding removal (stored) */
@property (nonatomic, getter=isSymbolAnimationEnabled) BOOL symbolAnimationEnabled API_AVAILABLE(ios(17.0));
@property (nullable, nonatomic, copy) UIMenuElement *menuRepresentation API_AVAILABLE(ios(16.0));
@property (nonatomic, getter=isPaddingRemoved) BOOL paddingRemoved API_AVAILABLE(ios(26.0));
@end

@interface UIBarButtonItemGroup (UIBarButtonItemGroupExtras)
+ (UIBarButtonItemGroup *)fixedGroupWithRepresentativeItem:(nullable UIBarButtonItem *)representativeItem items:(NSArray<UIBarButtonItem *> *)items
    NS_SWIFT_NAME(__fixedGroup(representativeItem:items:)) /* (overlay: defaults) */ API_AVAILABLE(ios(16.0));
+ (UIBarButtonItemGroup *)movableGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier representativeItem:(nullable UIBarButtonItem *)representativeItem
    items:(NSArray<UIBarButtonItem *> *)items NS_SWIFT_NAME(__movableGroup(customizationIdentifier:representativeItem:items:)) /* (overlay: defaults) */ API_AVAILABLE(ios(16.0));
+ (UIBarButtonItemGroup *)optionalGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier inDefaultCustomization:(BOOL)inDefaultCustomization
    representativeItem:(nullable UIBarButtonItem *)representativeItem items:(NSArray<UIBarButtonItem *> *)items
    NS_SWIFT_NAME(__optionalGroup(customizationIdentifier:isInDefaultCustomization:representativeItem:items:)) /* (overlay: defaults) */ API_AVAILABLE(ios(16.0));
/* a group holding one fixed space (iOS 26: separates the glass groups around it) */
+ (UIBarButtonItemGroup *)groupWithFixedSpace NS_SWIFT_NAME(fixedSpace()) API_AVAILABLE(ios(26.0));
/* kept in the bar when it is short of room (isim shows every group) */
@property (nonatomic) BOOL alwaysAvailable API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, copy) UIMenuElement *menuRepresentation API_AVAILABLE(ios(16.0));
@end

@interface UINavigationBar (UINavigationBarExtras)
@property (nonatomic) UIBehavioralStyle preferredBehavioralStyle API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) UIBehavioralStyle behavioralStyle API_AVAILABLE(ios(16.0));      /* iOS: always pad */
@property (nonatomic, readonly) UINavigationBarNSToolbarSection currentNSToolbarSection API_AVAILABLE(ios(16.0));   /* iOS: none */
/* the inline title moves by the adjustment (compact metrics: iPhone landscape) */
- (void)setTitleVerticalPositionAdjustment:(CGFloat)adjustment forBarMetrics:(UIBarMetrics)barMetrics;
- (CGFloat)titleVerticalPositionAdjustmentForBarMetrics:(UIBarMetrics)barMetrics;
/* legacy background images: one replaces the appearance's background (an empty image: transparent) */
- (void)setBackgroundImage:(nullable UIImage *)backgroundImage forBarMetrics:(UIBarMetrics)barMetrics;
- (nullable UIImage *)backgroundImageForBarMetrics:(UIBarMetrics)barMetrics;
- (void)setBackgroundImage:(nullable UIImage *)backgroundImage forBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics;
- (nullable UIImage *)backgroundImageForBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics;
@end

@interface UINavigationBarAppearance (UINavigationBarAppearanceExtras)
/* iOS 26: the look of prominent-style buttons */
@property (nonatomic, copy) UIBarButtonItemAppearance *prominentButtonAppearance API_AVAILABLE(ios(26.0));
@end
@interface UIToolbarAppearance (UIToolbarAppearanceExtras)
@property (nonatomic, copy) UIBarButtonItemAppearance *prominentButtonAppearance API_AVAILABLE(ios(26.0));
@end

/* the document a navigation item stands for (iOS 16): the title menu's header (isim: the title and icon are not
   drawn in the menu; stored). LinkPresentation is not in isim's SDK, so metadata is for apps that bring their own */
NS_SWIFT_UI_ACTOR
@interface UIDocumentProperties : NSObject
- (instancetype)initWithMetadata:(LPLinkMetadata *)metadata NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, copy) LPLinkMetadata *metadata;
@property (nonatomic, copy, nullable) UIActivityViewController *(^activityViewControllerProvider)(void);
@property (nonatomic) BOOL wantsIconRepresentation;
@end

typedef NS_ENUM(NSInteger, UINavigationItemBackButtonDisplayMode) {
    UINavigationItemBackButtonDisplayModeDefault = 0,    /* the previous title, "Back" when it does not fit */
    UINavigationItemBackButtonDisplayModeGeneric = 1,    /* "Back" */
    UINavigationItemBackButtonDisplayModeMinimal = 2,    /* the chevron alone */
} NS_SWIFT_NAME(UINavigationItem.BackButtonDisplayMode) API_AVAILABLE(ios(14.0));
/* iOS 27.2 (beta) title alignment values */
@protocol UINavigationItemRenameDelegate;
@interface UINavigationItem (UINavigationItemExtras)
/* how the back button to the previous item reads (the previous item's mode, else this item's) */
@property (nonatomic) UINavigationItemBackButtonDisplayMode backButtonDisplayMode API_AVAILABLE(ios(14.0));
- (void)setHidesBackButton:(BOOL)hidesBackButton animated:(BOOL)animated;
/* the back button runs this action instead of popping (its title, when set, is the button's) */
@property (nullable, nonatomic, copy) UIAction *backAction API_AVAILABLE(ios(16.0));
/* a trailing group kept at the trailing edge, after the trailing groups */
@property (nullable, nonatomic, strong) UIBarButtonItemGroup *pinnedTrailingGroup API_AVAILABLE(ios(26.0));
/* the key customizations are saved under (isim has no customization UI: stored) */
@property (nullable, nonatomic, copy) NSString *customizationIdentifier API_AVAILABLE(ios(16.0));
/* the overflow (•••) button a popover from its menu points at; nil while there is none (iOS 16) */
@property (nullable, nonatomic, readonly) id<UIPopoverPresentationControllerSourceItem> overflowPresentationSource API_AVAILABLE(ios(16.0));
/* the title menu (iOS 16): a chevron after the title; tapping the title shows the provider's menu, built from the
   suggested actions (Rename when there is a rename delegate) */
@property (nullable, nonatomic, copy) UIMenu *_Nullable (^titleMenuProvider)(NSArray<UIMenuElement *> *suggestedActions) API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, strong) UIDocumentProperties *documentProperties API_AVAILABLE(ios(16.0));
/* renaming the title in place (the Rename action): a field over the title; Return ends it */
@property (nullable, nonatomic, weak) id<UINavigationItemRenameDelegate> renameDelegate API_AVAILABLE(ios(16.0));
@end

NS_SWIFT_UI_ACTOR
@protocol UINavigationItemRenameDelegate <NSObject>
- (void)navigationItem:(UINavigationItem *)navigationItem didEndRenamingWithTitle:(NSString *)title NS_SWIFT_NAME(navigationItem(_:didEndRenamingWith:));
@optional
- (BOOL)navigationItemShouldBeginRenaming:(UINavigationItem *)navigationItem;
- (NSString *)navigationItem:(UINavigationItem *)navigationItem willBeginRenamingWithSuggestedTitle:(NSString *)title selectedRange:(inout NSRange *)selectedRange
    NS_SWIFT_NAME(navigationItem(_:willBeginRenamingWith:selectedRange:));
- (BOOL)navigationItem:(UINavigationItem *)navigationItem shouldEndRenamingWithTitle:(NSString *)title NS_SWIFT_NAME(navigationItem(_:shouldEndRenamingWith:));
@end

UIKIT_EXTERN const CGFloat UINavigationControllerHideShowBarDuration NS_SWIFT_NAME(UINavigationController.hideShowBarDuration);
@interface UINavigationController (UINavigationControllerExtras)
/* iOS 26: the pop gesture anywhere in the content (isim: the same pan as interactivePopGestureRecognizer) */
@property (nullable, nonatomic, readonly) UIGestureRecognizer *interactiveContentPopGestureRecognizer API_AVAILABLE(ios(26.0));
/* hiding the navigation bar and toolbar: a tap in the content toggles them; a swipe up hides and a swipe down shows
   them; the keyboard hides them; compact height (iPhone landscape) hides them and regular height shows them */
@property (nonatomic) BOOL hidesBarsOnTap;
@property (nonatomic) BOOL hidesBarsWhenKeyboardAppears;
@property (nonatomic) BOOL hidesBarsWhenVerticallyCompact;
@property (nonatomic, readonly, assign) UITapGestureRecognizer *barHideOnTapGestureRecognizer;
@property (nonatomic, readonly, strong) UIPanGestureRecognizer *barHideOnSwipeGestureRecognizer;
@end
NS_ASSUME_NONNULL_END
