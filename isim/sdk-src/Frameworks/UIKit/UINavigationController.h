#pragma once
/* isim: UIBarButtonItem, UINavigationItem, UINavigationBar, UIToolbar, UITabBar(Item), bar appearances,
   UINavigationController and UITabBarController. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIColor, UIMenu, UIGestureRecognizer, UIFont, UIBlurEffect;

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
@property (nullable, nonatomic, strong) id searchController;
@property (nonatomic) BOOL hidesSearchBarWhenScrolling;
@property (nullable, nonatomic, copy) id standardAppearance;
@property (nullable, nonatomic, copy) id scrollEdgeAppearance;
@property (nullable, nonatomic, copy) id compactAppearance;
@end

/* appearances (iOS 13+) */
NS_SWIFT_UI_ACTOR
@interface UIBarAppearance : NSObject <NSCopying>
- (instancetype)init;
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
@property (nonatomic, copy) NSDictionary<NSString *, id> *titleTextAttributes;
@property (nonatomic, copy) NSDictionary<NSString *, id> *largeTitleTextAttributes;
@end
NS_SWIFT_UI_ACTOR
@interface UIToolbarAppearance : UIBarAppearance
@end
NS_SWIFT_UI_ACTOR
@interface UITabBarAppearance : UIBarAppearance
@end

NS_SWIFT_UI_ACTOR
@interface UINavigationBar : UIView
@property (nonatomic) BOOL prefersLargeTitles;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nullable, nonatomic, strong) UIColor *barTintColor;
@property (nonatomic) NSInteger barStyle;
@property (nullable, nonatomic, readonly, strong) UINavigationItem *topItem;
@property (nullable, nonatomic, readonly, strong) UINavigationItem *backItem;
@property (nullable, nonatomic, copy) NSArray<UINavigationItem *> *items;
- (void)setItems:(nullable NSArray<UINavigationItem *> *)items animated:(BOOL)animated;
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated;
- (nullable UINavigationItem *)popNavigationItemAnimated:(BOOL)animated;
@property (nonatomic, copy) UINavigationBarAppearance *standardAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *scrollEdgeAppearance;
@property (nullable, nonatomic, copy) UINavigationBarAppearance *compactAppearance;
@property (nullable, nonatomic, copy) NSDictionary<NSString *, id> *titleTextAttributes;
@property (nullable, nonatomic, copy) NSDictionary<NSString *, id> *largeTitleTextAttributes;
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

@class UITabBarController;
@protocol UITabBarControllerDelegate <NSObject>
@optional
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController;
@end
NS_SWIFT_UI_ACTOR
@interface UITabBarController : UIViewController <UITabBarDelegate>
@property (nullable, nonatomic, copy) NSArray<__kindof UIViewController *> *viewControllers;
- (void)setViewControllers:(nullable NSArray<__kindof UIViewController *> *)viewControllers animated:(BOOL)animated;
@property (nullable, nonatomic, assign) __kindof UIViewController *selectedViewController;
@property (nonatomic) NSUInteger selectedIndex;
@property (nonatomic, readonly) UITabBar *tabBar;
@property (nullable, nonatomic, weak) id<UITabBarControllerDelegate> delegate;
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
