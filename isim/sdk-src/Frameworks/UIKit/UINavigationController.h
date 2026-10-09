#pragma once
/* isim: UIBarButtonItem, UINavigationItem, UINavigationBar, UIToolbar, UITabBar(Item), bar appearances,
   UINavigationController and UITabBarController. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIColor, UIMenu, UIGestureRecognizer, UIFont, UIBlurEffect, UISearchController, UINavigationBarAppearance;

typedef NS_ENUM(NSInteger, UIBarButtonItemStyle) { UIBarButtonItemStylePlain, UIBarButtonItemStyleBordered, UIBarButtonItemStyleDone, UIBarButtonItemStyleProminent = 3 };
typedef NS_ENUM(NSInteger, UIBarButtonSystemItem) {
    UIBarButtonSystemItemDone, UIBarButtonSystemItemCancel, UIBarButtonSystemItemEdit, UIBarButtonSystemItemSave, UIBarButtonSystemItemAdd,
    UIBarButtonSystemItemFlexibleSpace, UIBarButtonSystemItemFixedSpace, UIBarButtonSystemItemCompose, UIBarButtonSystemItemReply,
    UIBarButtonSystemItemAction, UIBarButtonSystemItemOrganize, UIBarButtonSystemItemBookmarks, UIBarButtonSystemItemSearch,
    UIBarButtonSystemItemRefresh, UIBarButtonSystemItemStop, UIBarButtonSystemItemCamera, UIBarButtonSystemItemTrash,
    UIBarButtonSystemItemPlay, UIBarButtonSystemItemPause, UIBarButtonSystemItemRewind, UIBarButtonSystemItemFastForward,
    UIBarButtonSystemItemUndo, UIBarButtonSystemItemRedo, UIBarButtonSystemItemPageCurl, UIBarButtonSystemItemClose,
};
NS_SWIFT_UI_ACTOR
@interface UIBarItem : NSObject
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nonatomic) NSInteger tag;
@property (nullable, nonatomic, copy) NSString *accessibilityIdentifier;
@property (nullable, nonatomic, copy) NSString *accessibilityLabel;
/* title font / color per state (NSFontAttributeName, NSForegroundColorAttributeName); bar buttons and tab bar titles use them */
- (void)setTitleTextAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes forState:(UIControlState)state;
- (nullable NSDictionary<NSAttributedStringKey, id> *)titleTextAttributesForState:(UIControlState)state;
@end
NS_SWIFT_UI_ACTOR
@interface UIBarButtonItem : UIBarItem
- (instancetype)init;
- (instancetype)initWithImage:(nullable UIImage *)image style:(UIBarButtonItemStyle)style target:(nullable id)target action:(nullable SEL)action;
- (instancetype)initWithTitle:(nullable NSString *)title style:(UIBarButtonItemStyle)style target:(nullable id)target action:(nullable SEL)action;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem target:(nullable id)target action:(nullable SEL)action;
- (instancetype)initWithCustomView:(UIView *)customView;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem primaryAction:(nullable UIAction *)primaryAction;
- (instancetype)initWithPrimaryAction:(nullable UIAction *)primaryAction;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem menu:(nullable UIMenu *)menu;
- (instancetype)initWithTitle:(nullable NSString *)title menu:(nullable UIMenu *)menu;
- (instancetype)initWithImage:(nullable UIImage *)image menu:(nullable UIMenu *)menu;
- (instancetype)initWithTitle:(nullable NSString *)title image:(nullable UIImage *)image primaryAction:(nullable UIAction *)primaryAction menu:(nullable UIMenu *)menu
    NS_SWIFT_NAME(init(__title:image:primaryAction:menu:));
+ (instancetype)fixedSpaceItemOfWidth:(CGFloat)width;
+ (instancetype)flexibleSpaceItem;
@property (nonatomic) UIBarButtonItemStyle style;
@property (nonatomic) CGFloat width;
@property (nullable, nonatomic, strong) UIView *customView;
@property (nullable, nonatomic) SEL action;
@property (nullable, nonatomic, weak) id target;
@property (nullable, nonatomic, copy) UIAction *primaryAction;
@property (nullable, nonatomic, copy) UIMenu *menu;
@property (nullable, nonatomic, strong) UIColor *tintColor;
@property (nonatomic, getter=isHidden) BOOL hidden;
@end
/* iOS 26: a badge on a bar button item (a count, a short string, or an indicator dot), drawn at its top trailing corner */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(UIBarButtonItem.Badge)
@interface UIBarButtonItemBadge : NSObject <NSCopying>
+ (instancetype)badgeWithCount:(NSUInteger)count NS_SWIFT_NAME(_isim_count(_:));
+ (instancetype)badgeWithString:(NSString *)string NS_SWIFT_NAME(_isim_string(_:));
+ (instancetype)indicatorBadge NS_SWIFT_NAME(_isim_indicator());
@property (nullable, nonatomic, copy) UIColor *backgroundColor;
@property (nullable, nonatomic, copy) UIColor *foregroundColor;
@property (nullable, nonatomic, copy) UIFont *font;
@property (nullable, nonatomic, readonly, copy) NSString *stringValue;
@end
@interface UIBarButtonItem (UIBarButtonItemBadge)
@property (nullable, nonatomic, copy) UIBarButtonItemBadge *badge API_AVAILABLE(ios(26.0));
/* iOS 26: neighbouring items share one glass capsule (default YES); hidesSharedBackground draws the item without glass */
@property (nonatomic) BOOL sharesBackground API_AVAILABLE(ios(26.0));
@property (nonatomic) BOOL hidesSharedBackground API_AVAILABLE(ios(26.0));
@end

/* where a navigation item's search controller shows its bar (iOS 16; integrated placements iOS 26). isim: stacked
   below the title; inline / integrated: on iPad (and before iOS 26) in the bar row, on iPhone under iOS 26 in the
   navigation controller's toolbar (searchBarPlacementAllowsToolbarIntegration) at searchBarPlacementBarButtonItem */
typedef NS_ENUM(NSInteger, UINavigationItemSearchBarPlacement) {
    UINavigationItemSearchBarPlacementAutomatic = 0,
    UINavigationItemSearchBarPlacementIntegrated API_AVAILABLE(ios(26.0)) = 1,
    UINavigationItemSearchBarPlacementInline = 1,
    UINavigationItemSearchBarPlacementStacked = 2,
    UINavigationItemSearchBarPlacementIntegratedButton API_AVAILABLE(ios(26.0)) = 3,
    UINavigationItemSearchBarPlacementIntegratedCentered API_AVAILABLE(ios(26.0)) = 4,
} NS_SWIFT_NAME(UINavigationItem.SearchBarPlacement) API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, UINavigationItemLargeTitleDisplayMode) {
    UINavigationItemLargeTitleDisplayModeAutomatic, UINavigationItemLargeTitleDisplayModeAlways, UINavigationItemLargeTitleDisplayModeNever, UINavigationItemLargeTitleDisplayModeInline };
NS_SWIFT_UI_ACTOR
@interface UINavigationItem : NSObject
- (instancetype)initWithTitle:(NSString *)title;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *prompt;
@property (nullable, nonatomic, strong) UIView *titleView;
@property (nullable, nonatomic, strong) UIBarButtonItem *backBarButtonItem;
@property (nullable, nonatomic, copy) NSString *backButtonTitle;
@property (nonatomic) BOOL hidesBackButton;
@property (nullable, nonatomic, copy) NSArray<UIBarButtonItem *> *leftBarButtonItems;
@property (nullable, nonatomic, copy) NSArray<UIBarButtonItem *> *rightBarButtonItems;
@property (nullable, nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nullable, nonatomic, strong) UIBarButtonItem *rightBarButtonItem;
- (void)setLeftBarButtonItem:(nullable UIBarButtonItem *)item animated:(BOOL)animated;
- (void)setRightBarButtonItem:(nullable UIBarButtonItem *)item animated:(BOOL)animated;
- (void)setLeftBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)items animated:(BOOL)animated;
- (void)setRightBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)items animated:(BOOL)animated;
@property (nonatomic) BOOL leftItemsSupplementBackButton;
@property (nonatomic) UINavigationItemLargeTitleDisplayMode largeTitleDisplayMode;
@property (nullable, nonatomic, strong) UISearchController *searchController;
@property (nonatomic) BOOL hidesSearchBarWhenScrolling;
@property (nonatomic) UINavigationItemSearchBarPlacement preferredSearchBarPlacement API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) UINavigationItemSearchBarPlacement searchBarPlacement API_AVAILABLE(ios(16.0));
@property (nonatomic) BOOL searchBarPlacementAllowsToolbarIntegration API_AVAILABLE(ios(26.0));    /* default YES */
@property (nonatomic) BOOL searchBarPlacementAllowsExternalIntegration API_AVAILABLE(ios(26.0));   /* default NO; isim: stored */
@property (nonatomic, readonly, strong) UIBarButtonItem *searchBarPlacementBarButtonItem API_AVAILABLE(ios(26.0));
/* per-item appearances override the bar's while the item is on top */
@property (nullable, nonatomic, copy) UINavigationBarAppearance *standardAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *scrollEdgeAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *compactAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *compactScrollEdgeAppearance;
@end

/* appearances (iOS 13+) */
NS_SWIFT_UI_ACTOR
@interface UIBarButtonItemStateAppearance : NSObject
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *titleTextAttributes;
@property (nonatomic) UIOffset titlePositionAdjustment;
@property (nullable, nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic) UIOffset backgroundImagePositionAdjustment;
@end
NS_SWIFT_UI_ACTOR
@interface UIBarButtonItemAppearance : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init;
- (instancetype)initWithStyle:(UIBarButtonItemStyle)style;
- (void)configureWithDefaultForStyle:(UIBarButtonItemStyle)style;
@property (nonatomic, readonly, strong) UIBarButtonItemStateAppearance *normal;
@property (nonatomic, readonly, strong) UIBarButtonItemStateAppearance *highlighted;
@property (nonatomic, readonly, strong) UIBarButtonItemStateAppearance *disabled;
@property (nonatomic, readonly, strong) UIBarButtonItemStateAppearance *focused;
@end
NS_SWIFT_UI_ACTOR
@interface UIBarAppearance : NSObject <NSCopying>
- (instancetype)init;
- (instancetype)initWithIdiom:(UIUserInterfaceIdiom)idiom;
- (instancetype)initWithBarAppearance:(UIBarAppearance *)barAppearance;
@property (nonatomic, readonly) UIUserInterfaceIdiom idiom;
@property (nonatomic) UIViewContentMode backgroundImageContentMode;
@property (nullable, nonatomic, strong) UIImage *shadowImage;
- (void)configureWithDefaultBackground;
- (void)configureWithOpaqueBackground;
- (void)configureWithTransparentBackground;
@property (nullable, nonatomic, copy) UIBlurEffect *backgroundEffect;
@property (nullable, nonatomic, copy) UIColor *backgroundColor;
@property (nullable, nonatomic, strong) UIImage *backgroundImage;
@property (nullable, nonatomic, copy) UIColor *shadowColor;
@end
NS_SWIFT_UI_ACTOR
@interface UINavigationBarAppearance : UIBarAppearance
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *titleTextAttributes;
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *largeTitleTextAttributes;
@property (nonatomic) UIOffset titlePositionAdjustment;
@property (nonatomic, copy) UIBarButtonItemAppearance *buttonAppearance;
@property (nonatomic, copy) UIBarButtonItemAppearance *doneButtonAppearance;
@property (nonatomic, copy) UIBarButtonItemAppearance *backButtonAppearance;
@property (nonatomic, readonly, strong) UIImage *backIndicatorImage;
@property (nonatomic, readonly, strong) UIImage *backIndicatorTransitionMaskImage;
- (void)setBackIndicatorImage:(nullable UIImage *)backIndicatorImage transitionMaskImage:(nullable UIImage *)backIndicatorTransitionMaskImage;
@end
NS_SWIFT_UI_ACTOR
@interface UIToolbarAppearance : UIBarAppearance
@end
NS_SWIFT_UI_ACTOR
@interface UITabBarAppearance : UIBarAppearance
@end

@class UINavigationBar;
/* a standalone bar's delegate (a navigation controller's bar answers these itself) */
NS_SWIFT_UI_ACTOR
@protocol UINavigationBarDelegate <NSObject>
@optional
- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPushItem:(UINavigationItem *)item;
- (void)navigationBar:(UINavigationBar *)navigationBar didPushItem:(UINavigationItem *)item;
- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item;
- (void)navigationBar:(UINavigationBar *)navigationBar didPopItem:(UINavigationItem *)item;
@end

NS_SWIFT_UI_ACTOR
@interface UINavigationBar : UIView
@property (nullable, nonatomic, weak) id<UINavigationBarDelegate> delegate;
@property (nonatomic) BOOL prefersLargeTitles;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nullable, nonatomic, strong) UIColor *barTintColor;
@property (nonatomic) NSInteger barStyle;
@property (nullable, nonatomic, readonly, strong) UINavigationItem *topItem;
@property (nullable, nonatomic, readonly, strong) UINavigationItem *backItem;
@property (nullable, nonatomic, copy) NSArray<UINavigationItem *> *items;
- (void)setItems:(nullable NSArray<UINavigationItem *> *)items animated:(BOOL)animated;
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated NS_SWIFT_NAME(pushItem(_:animated:));
- (nullable UINavigationItem *)popNavigationItemAnimated:(BOOL)animated NS_SWIFT_NAME(popItem(animated:));
@property (nonatomic, copy) UINavigationBarAppearance *standardAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *scrollEdgeAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *compactAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *compactScrollEdgeAppearance;
@property (nullable, nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *titleTextAttributes;
@property (nullable, nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *largeTitleTextAttributes;
@end

NS_SWIFT_UI_ACTOR
@interface UIToolbar : UIView
@property (nullable, nonatomic, copy) NSArray<UIBarButtonItem *> *items;
- (void)setItems:(nullable NSArray<UIBarButtonItem *> *)items animated:(BOOL)animated;
@property (nullable, nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nonatomic, copy) UIToolbarAppearance *standardAppearance;
@end

typedef NS_ENUM(NSInteger, UITabBarSystemItem) {
    UITabBarSystemItemMore, UITabBarSystemItemFavorites, UITabBarSystemItemFeatured, UITabBarSystemItemTopRated, UITabBarSystemItemRecents,
    UITabBarSystemItemContacts, UITabBarSystemItemHistory, UITabBarSystemItemBookmarks, UITabBarSystemItemSearch, UITabBarSystemItemDownloads,
    UITabBarSystemItemMostRecent, UITabBarSystemItemMostViewed,
};
NS_SWIFT_UI_ACTOR
@interface UITabBarItem : UIBarItem
- (instancetype)init;
- (instancetype)initWithTitle:(nullable NSString *)title image:(nullable UIImage *)image tag:(NSInteger)tag;
- (instancetype)initWithTitle:(nullable NSString *)title image:(nullable UIImage *)image selectedImage:(nullable UIImage *)selectedImage;
- (instancetype)initWithTabBarSystemItem:(UITabBarSystemItem)systemItem tag:(NSInteger)tag;
@property (nullable, nonatomic, strong) UIImage *selectedImage;
@property (nullable, nonatomic, copy) NSString *badgeValue;
@property (nullable, nonatomic, copy) UIColor *badgeColor;
@end
@class UITabBar;
@protocol UITabBarDelegate <NSObject>
@optional
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;
@end
NS_SWIFT_UI_ACTOR
@interface UITabBar : UIView
@property (nullable, nonatomic, weak) id<UITabBarDelegate> delegate;
@property (nullable, nonatomic, copy) NSArray<UITabBarItem *> *items;
@property (nullable, nonatomic, weak) UITabBarItem *selectedItem;
- (void)setItems:(nullable NSArray<UITabBarItem *> *)items animated:(BOOL)animated;
@property (nullable, nonatomic, strong) UIColor *barTintColor;
@property (nullable, nonatomic, strong) UIColor *unselectedItemTintColor;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nonatomic, copy) UITabBarAppearance *standardAppearance;
@property (nullable, nonatomic, copy) UITabBarAppearance *scrollEdgeAppearance;
@end

typedef NS_ENUM(NSInteger, UINavigationControllerOperation) { UINavigationControllerOperationNone, UINavigationControllerOperationPush, UINavigationControllerOperationPop };
@class UINavigationController;
@protocol UINavigationControllerDelegate <NSObject>
@optional
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController;   /* UIInterfaceOrientationMask */
@end
NS_SWIFT_UI_ACTOR
@interface UINavigationController : UIViewController
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;
- (instancetype)initWithNavigationBarClass:(nullable Class)navigationBarClass toolbarClass:(nullable Class)toolbarClass;
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (nullable UIViewController *)popViewControllerAnimated:(BOOL)animated;
- (nullable NSArray<__kindof UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (nullable NSArray<__kindof UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated;
@property (nullable, nonatomic, readonly, strong) UIViewController *topViewController;
@property (nullable, nonatomic, readonly, strong) UIViewController *visibleViewController;
@property (nonatomic, copy) NSArray<__kindof UIViewController *> *viewControllers;
- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers animated:(BOOL)animated;
@property (nonatomic, getter=isNavigationBarHidden) BOOL navigationBarHidden;
- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated;
@property (nonatomic, readonly) UINavigationBar *navigationBar;
@property (nonatomic, getter=isToolbarHidden) BOOL toolbarHidden;
- (void)setToolbarHidden:(BOOL)hidden animated:(BOOL)animated;
@property (null_resettable, nonatomic, readonly) UIToolbar *toolbar;
@property (nullable, nonatomic, weak) id<UINavigationControllerDelegate> delegate;
@property (nullable, nonatomic, readonly) UIGestureRecognizer *interactivePopGestureRecognizer;
@property (nonatomic) BOOL hidesBarsOnSwipe;
@end

@class UITabBarController, UITabGroup;
/* ---- iOS 18 tabs: UITab, UISearchTab, UITabGroup ---- */
typedef NS_ENUM(NSInteger, UITabPlacement) { UITabPlacementAutomatic = 0, UITabPlacementDefault = 1, UITabPlacementOptional = 2,
    UITabPlacementMovable = 3, UITabPlacementPinned = 4, UITabPlacementFixed = 5, UITabPlacementSidebarOnly = 6 } NS_SWIFT_NAME(UITab.Placement) API_AVAILABLE(ios(18.0));
/* isim (adapted): a tab's provider makes its view controller when the tabs are set; a group in the tab bar shows
   its own controller, else its selected (or first) child inside its managing navigation controller */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UITab : NSObject
- (instancetype)initWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(NSString *)identifier
       viewControllerProvider:(nullable UIViewController * (^)(__kindof UITab *tab))viewControllerProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) UIImage *image;
@property (nullable, nonatomic, copy) NSString *subtitle;
@property (nullable, nonatomic, copy) NSString *badgeValue;
@property (nonatomic) UITabPlacement preferredPlacement;
@property (nullable, nonatomic, strong) id userInfo;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) BOOL allowsHiding;
@property (nullable, nonatomic, readonly, weak) UITabGroup *parent;
@property (nullable, nonatomic, readonly, weak) UITabGroup *managingTabGroup;
@property (nullable, nonatomic, readonly, weak) UITabBarController *tabBarController;
@property (nullable, nonatomic, readonly) UIViewController *viewController;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UISearchTab : UITab
- (instancetype)initWithViewControllerProvider:(nullable UIViewController * (^)(__kindof UITab *tab))viewControllerProvider;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UITabGroup : UITab
- (instancetype)initWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(NSString *)identifier children:(NSArray<UITab *> *)children
       viewControllerProvider:(nullable UIViewController * (^)(__kindof UITab *tab))viewControllerProvider;
@property (nonatomic, copy) NSArray<UITab *> *children;
@property (nullable, nonatomic, strong) UITab *selectedChild;
@property (nonatomic) BOOL allowsReordering;
@property (nonatomic, copy) NSArray<NSString *> *displayOrderIdentifiers;
@property (nullable, nonatomic, readonly, strong) UINavigationController *managingNavigationController;
- (nullable UITab *)tabForIdentifier:(NSString *)identifier;
@end
typedef NS_ENUM(NSInteger, UITabBarControllerMode) { UITabBarControllerModeAutomatic = 0, UITabBarControllerModeTabBar = 1,
    UITabBarControllerModeTabSidebar = 2 } NS_SWIFT_NAME(UITabBarController.Mode) API_AVAILABLE(ios(18.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UITabBarController.Sidebar)
@interface UITabBarControllerSidebar : NSObject
@property (nonatomic, getter=isHidden) BOOL hidden;
@end

@protocol UITabBarControllerDelegate <NSObject>
@optional
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController;
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectTab:(UITab *)tab NS_SWIFT_NAME(tabBarController(_:shouldSelectTab:)) API_AVAILABLE(ios(18.0));
- (void)tabBarController:(UITabBarController *)tabBarController didSelectTab:(UITab *)selectedTab previousTab:(nullable UITab *)previousTab NS_SWIFT_NAME(tabBarController(_:didSelectTab:previousTab:)) API_AVAILABLE(ios(18.0));
@end
NS_SWIFT_UI_ACTOR
@interface UITabBarController : UIViewController <UITabBarDelegate>
@property (nullable, nonatomic, copy) NSArray<__kindof UIViewController *> *viewControllers;
- (void)setViewControllers:(nullable NSArray<__kindof UIViewController *> *)viewControllers animated:(BOOL)animated;
@property (nullable, nonatomic, assign) __kindof UIViewController *selectedViewController;
@property (nonatomic) NSUInteger selectedIndex;
@property (nonatomic, readonly) UITabBar *tabBar;
@property (nullable, nonatomic, weak) id<UITabBarControllerDelegate> delegate;
/* iOS 18 */
@property (nonatomic, copy) NSArray<UITab *> *tabs API_AVAILABLE(ios(18.0));
- (void)setTabs:(NSArray<UITab *> *)tabs animated:(BOOL)animated API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, strong) UITab *selectedTab API_AVAILABLE(ios(18.0));
- (nullable UITab *)tabForIdentifier:(NSString *)identifier API_AVAILABLE(ios(18.0));
@property (nonatomic) UITabBarControllerMode mode API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly) UITabBarControllerSidebar *sidebar API_AVAILABLE(ios(18.0));
@property (nonatomic, getter=isTabBarHidden) BOOL tabBarHidden API_AVAILABLE(ios(18.0));
- (void)setTabBarHidden:(BOOL)hidden animated:(BOOL)animated API_AVAILABLE(ios(18.0));
@end

@interface UIViewController (UIContainers)
@property (nullable, nonatomic, readonly, strong) UINavigationController *navigationController;
@property (nullable, nonatomic, readonly, strong) UITabBarController *tabBarController;
@property (nullable, nonatomic, strong) NSArray<UIBarButtonItem *> *toolbarItems;
- (void)setToolbarItems:(nullable NSArray<UIBarButtonItem *> *)toolbarItems animated:(BOOL)animated;
@property (null_resettable, nonatomic, strong) UITabBarItem *tabBarItem;
@property (nonatomic) BOOL hidesBottomBarWhenPushed;
@property (nonatomic, getter=isEditing) BOOL editing;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
@property (nonatomic, readonly) UIBarButtonItem *editButtonItem;
@property (nonatomic, readonly, getter=isMovingToParentViewController) BOOL movingToParentViewController;
@property (nonatomic, readonly, getter=isMovingFromParentViewController) BOOL movingFromParentViewController;
@end
NS_ASSUME_NONNULL_END
