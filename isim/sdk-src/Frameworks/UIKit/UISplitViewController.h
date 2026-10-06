#pragma once
/* isim: UISplitViewController (collapsed into one navigation stack in compact width — every iPhone; side-by-side
   columns in regular width) and UIPageViewController (scroll style with paging; page curl is shown as scroll). */
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UISplitViewController, UIPageViewController, UIBarButtonItem, UIGestureRecognizer;

typedef NS_ENUM(NSInteger, UISplitViewControllerStyle) {
    UISplitViewControllerStyleUnspecified, UISplitViewControllerStyleDoubleColumn, UISplitViewControllerStyleTripleColumn
} NS_SWIFT_NAME(UISplitViewController.Style);
typedef NS_ENUM(NSInteger, UISplitViewControllerColumn) {
    UISplitViewControllerColumnPrimary, UISplitViewControllerColumnSupplementary, UISplitViewControllerColumnSecondary, UISplitViewControllerColumnCompact
} NS_SWIFT_NAME(UISplitViewController.Column);
typedef NS_ENUM(NSInteger, UISplitViewControllerDisplayMode) {
    UISplitViewControllerDisplayModeAutomatic, UISplitViewControllerDisplayModeSecondaryOnly, UISplitViewControllerDisplayModeOneBesideSecondary,
    UISplitViewControllerDisplayModeOneOverSecondary, UISplitViewControllerDisplayModeTwoBesideSecondary, UISplitViewControllerDisplayModeTwoOverSecondary,
    UISplitViewControllerDisplayModeTwoDisplaceSecondary
} NS_SWIFT_NAME(UISplitViewController.DisplayMode);
typedef NS_ENUM(NSInteger, UISplitViewControllerSplitBehavior) {
    UISplitViewControllerSplitBehaviorAutomatic, UISplitViewControllerSplitBehaviorTile, UISplitViewControllerSplitBehaviorOverlay, UISplitViewControllerSplitBehaviorDisplace
} NS_SWIFT_NAME(UISplitViewController.SplitBehavior);

NS_SWIFT_UI_ACTOR
@protocol UISplitViewControllerDelegate <NSObject>
@optional
- (UISplitViewControllerColumn)splitViewController:(UISplitViewController *)svc topColumnForCollapsingToProposedTopColumn:(UISplitViewControllerColumn)proposedTopColumn;
- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
    NS_SWIFT_NAME(splitViewController(_:collapseSecondary:onto:));
- (BOOL)splitViewController:(UISplitViewController *)splitViewController showViewController:(UIViewController *)vc sender:(nullable id)sender NS_SWIFT_NAME(splitViewController(_:show:sender:));
- (BOOL)splitViewController:(UISplitViewController *)splitViewController showDetailViewController:(UIViewController *)vc sender:(nullable id)sender NS_SWIFT_NAME(splitViewController(_:showDetail:sender:));
- (void)splitViewControllerDidCollapse:(UISplitViewController *)svc;
- (void)splitViewController:(UISplitViewController *)svc willShowColumn:(UISplitViewControllerColumn)column;
- (void)splitViewController:(UISplitViewController *)svc willHideColumn:(UISplitViewControllerColumn)column;
@end

NS_SWIFT_UI_ACTOR
@interface UISplitViewController : UIViewController
- (instancetype)initWithStyle:(UISplitViewControllerStyle)style;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil;
@property (nonatomic, readonly) UISplitViewControllerStyle style;
@property (nullable, nonatomic, weak) id<UISplitViewControllerDelegate> delegate;
@property (nonatomic, copy) NSArray<__kindof UIViewController *> *viewControllers;
- (void)setViewController:(nullable UIViewController *)vc forColumn:(UISplitViewControllerColumn)column;
- (nullable __kindof UIViewController *)viewControllerForColumn:(UISplitViewControllerColumn)column;
- (void)showColumn:(UISplitViewControllerColumn)column;
- (void)hideColumn:(UISplitViewControllerColumn)column;
@property (nonatomic, readonly, getter=isCollapsed) BOOL collapsed;
@property (nonatomic) UISplitViewControllerDisplayMode preferredDisplayMode;
@property (nonatomic, readonly) UISplitViewControllerDisplayMode displayMode;
@property (nonatomic) UISplitViewControllerSplitBehavior preferredSplitBehavior;
@property (nonatomic) BOOL presentsWithGesture;
@property (nonatomic) BOOL showsSecondaryOnlyButton;
@property (nonatomic) CGFloat preferredPrimaryColumnWidthFraction;
@property (nonatomic) CGFloat preferredPrimaryColumnWidth;
@property (nonatomic) CGFloat minimumPrimaryColumnWidth;
@property (nonatomic) CGFloat maximumPrimaryColumnWidth;
@property (nonatomic, readonly) CGFloat primaryColumnWidth;
@property (nonatomic, readonly) UIBarButtonItem *displayModeButtonItem;
@end

@interface UIViewController (UISplitViewController)
@property (nullable, nonatomic, readonly, strong) UISplitViewController *splitViewController;
@end

/* ---- page view controller ---- */
typedef NS_ENUM(NSInteger, UIPageViewControllerNavigationDirection) {
    UIPageViewControllerNavigationDirectionForward, UIPageViewControllerNavigationDirectionReverse
} NS_SWIFT_NAME(UIPageViewController.NavigationDirection);
typedef NS_ENUM(NSInteger, UIPageViewControllerNavigationOrientation) {
    UIPageViewControllerNavigationOrientationHorizontal = 0, UIPageViewControllerNavigationOrientationVertical = 1
} NS_SWIFT_NAME(UIPageViewController.NavigationOrientation);
typedef NS_ENUM(NSInteger, UIPageViewControllerSpineLocation) {
    UIPageViewControllerSpineLocationNone = 0, UIPageViewControllerSpineLocationMin = 1, UIPageViewControllerSpineLocationMid = 2, UIPageViewControllerSpineLocationMax = 3
} NS_SWIFT_NAME(UIPageViewController.SpineLocation);
typedef NS_ENUM(NSInteger, UIPageViewControllerTransitionStyle) {
    UIPageViewControllerTransitionStylePageCurl = 0, UIPageViewControllerTransitionStyleScroll = 1
} NS_SWIFT_NAME(UIPageViewController.TransitionStyle);
typedef NSString *UIPageViewControllerOptionsKey NS_TYPED_ENUM NS_SWIFT_NAME(UIPageViewController.OptionsKey);
UIKIT_EXTERN UIPageViewControllerOptionsKey const UIPageViewControllerOptionSpineLocationKey NS_SWIFT_NAME(spineLocation);
UIKIT_EXTERN UIPageViewControllerOptionsKey const UIPageViewControllerOptionInterPageSpacingKey NS_SWIFT_NAME(interPageSpacing);

NS_SWIFT_UI_ACTOR
@protocol UIPageViewControllerDataSource <NSObject>
@required
- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController;
- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController;
@optional
- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController;
- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController;
@end

NS_SWIFT_UI_ACTOR
@protocol UIPageViewControllerDelegate <NSObject>
@optional
- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers;
- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed;
@end

NS_SWIFT_UI_ACTOR
@interface UIPageViewController : UIViewController
- (instancetype)initWithTransitionStyle:(UIPageViewControllerTransitionStyle)style navigationOrientation:(UIPageViewControllerNavigationOrientation)navigationOrientation
                                options:(nullable NSDictionary<UIPageViewControllerOptionsKey, id> *)options;
@property (nullable, nonatomic, weak) id<UIPageViewControllerDelegate> delegate;
@property (nullable, nonatomic, weak) id<UIPageViewControllerDataSource> dataSource;
@property (nonatomic, readonly) UIPageViewControllerTransitionStyle transitionStyle;
@property (nonatomic, readonly) UIPageViewControllerNavigationOrientation navigationOrientation;
@property (nonatomic, readonly) UIPageViewControllerSpineLocation spineLocation;
@property (nonatomic, getter=isDoubleSided) BOOL doubleSided;
@property (nonatomic, readonly) NSArray<__kindof UIGestureRecognizer *> *gestureRecognizers;
@property (nullable, nonatomic, readonly) NSArray<__kindof UIViewController *> *viewControllers;
- (void)setViewControllers:(nullable NSArray<UIViewController *> *)viewControllers direction:(UIPageViewControllerNavigationDirection)direction
                  animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL finished))completion;
@end
NS_ASSUME_NONNULL_END
