#pragma once
#import <UIKit/UIResponder.h>
#import <UIKit/UIView.h>
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
@property (nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection;
@property (nonatomic, readonly, strong) UINavigationItem *navigationItem;
@end
@interface UINavigationItem : NSObject
@property (nullable, nonatomic, copy) NSString *title;
@end
NS_ASSUME_NONNULL_END
