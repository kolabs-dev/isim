#pragma once
#import <UIKit/UIResponder.h>
#import <UIKit/UIView.h>
#import <UIKit/UIGestureRecognizer.h>
NS_ASSUME_NONNULL_BEGIN
@class UINavigationItem, UIStoryboard, NSBundle;
typedef NS_ENUM(NSInteger, UIStatusBarStyle) { UIStatusBarStyleDefault = 0, UIStatusBarStyleLightContent = 1, UIStatusBarStyleDarkContent = 3 };
typedef NS_ENUM(NSInteger, UIModalPresentationStyle) { UIModalPresentationFullScreen = 0, UIModalPresentationPageSheet, UIModalPresentationFormSheet, UIModalPresentationCurrentContext, UIModalPresentationCustom, UIModalPresentationOverFullScreen, UIModalPresentationOverCurrentContext, UIModalPresentationPopover, UIModalPresentationNone = -1, UIModalPresentationAutomatic = -2 };
@interface UIViewController : UIResponder <NSCoding, UITraitEnvironment>
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (null_resettable, nonatomic, strong) UIView *view;
- (void)loadView;
- (void)loadViewIfNeeded;
@property (nullable, nonatomic, readonly, strong) UIView *viewIfLoaded;
- (void)viewDidLoad;
@property (nonatomic, readonly, getter=isViewLoaded) BOOL viewLoaded;
@property (nullable, nonatomic, readonly, copy) NSString *nibName;
@property (nullable, nonatomic, readonly, strong) NSBundle *nibBundle;
@property (nullable, nonatomic, copy) NSString *title;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (void)updateViewConstraints;
- (void)didReceiveMemoryWarning;
@property (nullable, nonatomic, weak, readonly) UIViewController *parentViewController;
@property (nonatomic, readonly) NSArray<__kindof UIViewController *> *childViewControllers;
- (void)addChildViewController:(UIViewController *)childController;
- (void)removeFromParentViewController;
- (void)willMoveToParentViewController:(nullable UIViewController *)parent;
- (void)didMoveToParentViewController:(nullable UIViewController *)parent;
@property (nullable, nonatomic, readonly) UIViewController *presentedViewController;
@property (nullable, nonatomic, readonly) UIViewController *presentingViewController;
@property (nonatomic) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic, getter=isModalInPresentation) BOOL modalInPresentation;
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^ _Nullable)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^ _Nullable)(void))completion;
@property (nonatomic, readonly) UIStatusBarStyle preferredStatusBarStyle;
@property (nonatomic, readonly) BOOL prefersStatusBarHidden;
- (void)setNeedsStatusBarAppearanceUpdate;
@property (nonatomic, readonly) BOOL prefersHomeIndicatorAutoHidden;            /* isim: the home indicator fades 2 s after the last touch */
@property (nonatomic, readonly, nullable) UIViewController *childViewControllerForHomeIndicatorAutoHidden;
- (void)setNeedsUpdateOfHomeIndicatorAutoHidden;
@property (nonatomic, readonly) UIRectEdge preferredScreenEdgesDeferringSystemGestures;   /* isim: bottom: the home swipe needs a second swipe */
@property (nonatomic, readonly, nullable) UIViewController *childViewControllerForScreenEdgesDeferringSystemGestures;
- (void)setNeedsUpdateOfScreenEdgesDeferringSystemGestures;
@property (nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection;
@property (nonatomic, readonly, strong) UINavigationItem *navigationItem;
/* app extensions: the request of a Share/Action extension's view controller (isim hosts them in the host app's process) */
@property (nullable, nonatomic, readonly, strong) NSExtensionContext *extensionContext;
@property (nonatomic) UIEdgeInsets additionalSafeAreaInsets;
- (void)viewSafeAreaInsetsDidChange;
@end
NS_ASSUME_NONNULL_END
