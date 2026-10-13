#pragma once
/* isim: tab bar, tab bar item, tab bar appearance, tab and tab bar controller members from the documentation sweep
   (#9): item appearances (icon and title colours, badges), item positioning, the More tab, compact tab identifiers,
   sidebar items and layout. UINavigation.m. Categories on the existing classes (no ivars). */
#import <UIKit/UINavigationController.h>
#import <UIKit/UITableView.h>
NS_ASSUME_NONNULL_BEGIN

/* ---- item appearances (iOS 13): per layout (stacked: iPhone portrait; inline: iPad; compact inline: iPhone
   landscape) and per state. isim draws the stacked appearance on iPhone and the inline one on iPad ---- */
typedef NS_ENUM(NSInteger, UITabBarItemAppearanceStyle) { UITabBarItemAppearanceStyleStacked, UITabBarItemAppearanceStyleInline,
    UITabBarItemAppearanceStyleCompactInline } NS_SWIFT_NAME(UITabBarItemAppearance.Style) API_AVAILABLE(ios(13.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UITabBarItemStateAppearance : NSObject
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *titleTextAttributes;
@property (nonatomic) UIOffset titlePositionAdjustment;
@property (nullable, nonatomic, copy) UIColor *iconColor;
@property (nonatomic) UIOffset badgePositionAdjustment;
@property (nullable, nonatomic, copy) UIColor *badgeBackgroundColor;
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *badgeTextAttributes;
@property (nonatomic) UIOffset badgeTitlePositionAdjustment;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UITabBarItemAppearance : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init;
- (instancetype)initWithStyle:(UITabBarItemAppearanceStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (void)configureWithDefaultForStyle:(UITabBarItemAppearanceStyle)style;
@property (nonatomic, readonly, strong) UITabBarItemStateAppearance *normal;
@property (nonatomic, readonly, strong) UITabBarItemStateAppearance *selected;
@property (nonatomic, readonly, strong) UITabBarItemStateAppearance *disabled;
@property (nonatomic, readonly, strong) UITabBarItemStateAppearance *focused;
@end

/* how the items of a regular-width (iPad) classic tab bar are spread: fill the bar, or centred at the item width and
   spacing (automatic: centred on iPad). isim draws iPad tab bars at the top (iOS 18+), where this does not apply */
typedef NS_ENUM(NSInteger, UITabBarItemPositioning) { UITabBarItemPositioningAutomatic, UITabBarItemPositioningFill,
    UITabBarItemPositioningCentered } NS_SWIFT_NAME(UITabBar.ItemPositioning) API_AVAILABLE(ios(7.0));

@interface UITabBarAppearance (UITabBarAppearanceExtras)
@property (nonatomic, copy) UITabBarItemAppearance *stackedLayoutAppearance;
@property (nonatomic, copy) UITabBarItemAppearance *inlineLayoutAppearance;
@property (nonatomic, copy) UITabBarItemAppearance *compactInlineLayoutAppearance;
@property (nonatomic) UITabBarItemPositioning stackedItemPositioning;
@property (nonatomic) CGFloat stackedItemSpacing;
@property (nonatomic) CGFloat stackedItemWidth;
/* the selected tab's background: a tinted rounded rectangle, or the image (classic bar) */
@property (nullable, nonatomic, copy) UIColor *selectionIndicatorTintColor;
@property (nullable, nonatomic, strong) UIImage *selectionIndicatorImage;
@end

@interface UITabBarItem (UITabBarItemExtras)
- (void)setBadgeTextAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)textAttributes forState:(UIControlState)state API_AVAILABLE(ios(10.0));
- (nullable NSDictionary<NSAttributedStringKey, id> *)badgeTextAttributesForState:(UIControlState)state API_AVAILABLE(ios(10.0));
@end

@interface UITabBar (UITabBarExtras)
@property (nonatomic) UITabBarItemPositioning itemPositioning API_AVAILABLE(ios(7.0));
@property (nonatomic) CGFloat itemSpacing API_AVAILABLE(ios(7.0));
@property (nonatomic) CGFloat itemWidth API_AVAILABLE(ios(7.0));
@property (nullable, nonatomic, strong) UIImage *selectionIndicatorImage;
/* customizing (the More tab's Edit sheet): isim has no customization sheet; the state is kept and the tab bar
   delegate's will/did begin and end customizing messages are sent */
- (void)beginCustomizingItems:(NSArray<UITabBarItem *> *)items;
- (BOOL)endCustomizingAnimated:(BOOL)animated;
@property (nonatomic, readonly, getter=isCustomizing) BOOL customizing;
@end
/* ---- tabs (iOS 18) ---- */
@interface UITab (UITabExtras)
/* hidden until the user adds it in customization (isim has no customization: such a tab is not shown) */
@property (nonatomic, getter=isHiddenByDefault) BOOL hiddenByDefault API_AVAILABLE(ios(18.0));
/* in the tab bar or the sidebar */
@property (nonatomic, readonly) BOOL hasVisiblePlacement API_AVAILABLE(ios(18.0));
@end
typedef NS_ENUM(NSInteger, UITabGroupSidebarAppearance) { UITabGroupSidebarAppearanceAutomatic = 0, UITabGroupSidebarAppearanceInline,
    UITabGroupSidebarAppearanceRootSection } NS_SWIFT_NAME(UITabGroup.SidebarAppearance) API_AVAILABLE(ios(18.0));
@interface UITabGroup (UITabGroupExtras)
/* the child selected when the group is first chosen */
@property (nullable, nonatomic, copy) NSString *defaultChildIdentifier API_AVAILABLE(ios(18.0));
@property (nonatomic) UITabGroupSidebarAppearance sidebarAppearance API_AVAILABLE(ios(18.0));
/* the children in display order (displayOrderIdentifiers first) */
@property (nonatomic, readonly) NSArray<UITab *> *displayOrder API_AVAILABLE(ios(18.0));
/* actions listed after the children in the sidebar */
@property (nonatomic, copy) NSArray<UIAction *> *sidebarActions API_AVAILABLE(ios(18.0));
@property (nonatomic, getter=isCollapsedByDefault) BOOL collapsedByDefault API_AVAILABLE(ios(18.0));   /* isim: stored */
@property (nonatomic, getter=isSidebarDestination) BOOL sidebarDestination API_AVAILABLE(ios(18.0));   /* the group itself can be selected */
@end

/* the sidebar's rows (iOS 18): the delegate may return its own item for a tab or an action; a list content
   configuration's text and image replace the tab's */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UITabSidebarItem.Request)
@interface UITabSidebarItemRequest : NSObject
@property (nullable, nonatomic, readonly) UITab *tab;
@property (nullable, nonatomic, readonly) UIAction *action;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UITabSidebarItem : NSObject <NSCopying>
+ (instancetype)itemFromRequest:(UITabSidebarItemRequest *)request NS_SWIFT_NAME(init(request:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, readonly) UITab *tab;
@property (nullable, nonatomic, readonly) UIAction *action;
@property (nullable, nonatomic, copy) id<UIContentConfiguration> contentConfiguration;
@property (nullable, nonatomic, copy) UIBackgroundConfiguration *backgroundConfiguration;
- (UIListContentConfiguration *)defaultContentConfiguration;
- (UIBackgroundConfiguration *)defaultBackgroundConfiguration;
- (void)setNeedsUpdateConfiguration;
@end
typedef NS_ENUM(NSInteger, UITabBarControllerSidebarLayout) { UITabBarControllerSidebarLayoutAutomatic = 0, UITabBarControllerSidebarLayoutOverlap,
    UITabBarControllerSidebarLayoutTile } NS_SWIFT_NAME(UITabBarController.Sidebar.Layout) API_AVAILABLE(ios(26.0));
@interface UITabBarControllerSidebar (UITabBarControllerSidebarExtras)
/* overlap: over the content; tile: beside it (isim's sidebar tiles) */
@property (nonatomic) UITabBarControllerSidebarLayout preferredLayout API_AVAILABLE(ios(26.0));
- (void)reconfigureItemForTab:(UITab *)tab;
/* content above / below the rows (list content configurations: their text) and a view at the bottom */
@property (nullable, nonatomic, copy) id<UIContentConfiguration> headerContentConfiguration;
@property (nullable, nonatomic, copy) id<UIContentConfiguration> footerContentConfiguration;
@property (nullable, nonatomic, strong) UIView *bottomBarView;
@end
@interface UITabBarController (UITabBarControllerExtras)
- (instancetype)initWithTabs:(NSArray<UITab *> *)tabs API_AVAILABLE(ios(18.0));
/* the tabs the compact (iPhone) tab bar shows, by identifier (nil: the top-level tabs) */
@property (nullable, nonatomic, copy) NSArray<NSString *> *compactTabIdentifiers API_AVAILABLE(ios(18.0));
@property (nullable, nonatomic, copy) NSString *customizationIdentifier API_AVAILABLE(ios(18.0));   /* isim: stored */
/* more than five view controllers on iPhone: the bar shows four and More, whose navigation controller lists the rest
   and pushes the one chosen (a navigation controller's stack is moved into it while it shows there) */
@property (nonatomic, readonly) UINavigationController *moreNavigationController;
@property (nullable, nonatomic, copy) NSArray<__kindof UIViewController *> *customizableViewControllers;   /* isim: no Edit sheet */
@end
NS_ASSUME_NONNULL_END
