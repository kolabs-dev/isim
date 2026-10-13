#pragma once
/* isim: UIViewController members from the documentation sweep (#9): viewIsAppearing, manual appearance forwarding and
   child transitions, the layout margins and extended layout, the content scroll view, the status bar and orientation
   lock children, action targets, unwind lookups. UIViewControllerExtras.m. Categories (no ivars: the class's size must
   not change for apps' subclasses). */
#import <UIKit/UIViewController.h>
#import <UIKit/UIGeometry.h>
#import <UIKit/UIButton.h>          /* NSDirectionalRectEdge */
NS_ASSUME_NONNULL_BEGIN
@class UIPresentationController, UISplitViewController, UIStoryboardUnwindSegueSource, UIScrollView;
UIKIT_EXTERN NSExceptionName const UIViewControllerHierarchyInconsistencyException NS_SWIFT_NAME(UIViewController.hierarchyInconsistencyException);
@interface UIViewController (UIViewControllerAppearance)
/* after the view is in the window with its size and traits, before the appearance animation */
- (void)viewIsAppearing:(BOOL)animated API_AVAILABLE(ios(13.0));
/* manual appearance forwarding for containers that return NO */
@property (nonatomic, readonly) BOOL shouldAutomaticallyForwardAppearanceMethods;
- (void)beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated;
- (void)endAppearanceTransition;
@end
@interface UIViewController (UIViewControllerExtras)
/* layout margins: the root view keeps at least the system minimum unless told otherwise */
@property (nonatomic) BOOL viewRespectsSystemMinimumLayoutMargins;
@property (nonatomic, readonly) NSDirectionalEdgeInsets systemMinimumLayoutMargins;
- (void)viewLayoutMarginsDidChange;
/* the edges the view extends under the bars (a navigation controller places a view without .top under its bar) */
@property (nonatomic) UIRectEdge edgesForExtendedLayout;
@property (nonatomic) BOOL extendedLayoutIncludesOpaqueBars;
/* the scroll view the bars follow at an edge (scroll edge appearance, minimization); nil: the first one found */
- (void)setContentScrollView:(nullable UIScrollView *)scrollView forEdge:(NSDirectionalRectEdge)edge API_AVAILABLE(ios(15.0));
- (nullable UIScrollView *)contentScrollViewForEdge:(NSDirectionalRectEdge)edge API_AVAILABLE(ios(15.0));
/* children that decide the status bar and the orientation lock */
@property (nonatomic, readonly, nullable) UIViewController *childViewControllerForStatusBarStyle NS_SWIFT_NAME(childForStatusBarStyle);
@property (nonatomic, readonly, nullable) UIViewController *childViewControllerForStatusBarHidden NS_SWIFT_NAME(childForStatusBarHidden);
@property (nonatomic, readonly, nullable) UIViewController *childViewControllerForInterfaceOrientationLock NS_SWIFT_NAME(childForInterfaceOrientationLock) API_AVAILABLE(ios(26.0));
/* a non-full-screen presented controller decides the status bar only if it captures it */
@property (nonatomic) BOOL modalPresentationCapturesStatusBarAppearance;
/* swaps two children's views (both must be children of the receiver) */
- (void)transitionFromViewController:(UIViewController *)fromViewController toViewController:(UIViewController *)toViewController
                            duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options
                          animations:(void (^_Nullable)(void))animations completion:(void (^_Nullable)(BOOL finished))completion;
/* the controller that handles an action: the receiver if it can, else up the parents and presenters */
- (nullable UIViewController *)targetViewControllerForAction:(SEL)action sender:(nullable id)sender;
@property (nonatomic, readonly, nullable) UIPresentationController *activePresentationController API_AVAILABLE(ios(16.0));
- (nullable UIViewController *)childViewControllerContainingSegueSource:(UIStoryboardUnwindSegueSource *)source NS_SWIFT_NAME(childContaining(_:));
- (nullable UIViewController *)separateSecondaryViewControllerForSplitViewController:(UISplitViewController *)splitViewController;
@property (nonatomic, readonly) BOOL disablesAutomaticKeyboardDismissal;
@property (nonatomic, readonly) BOOL performsActionsWhilePresentingModally API_AVAILABLE(ios(16.0));
/* stored (focus, signposts) */
@property (nonatomic) BOOL restoresFocusAfterTransition;
@property (nullable, nonatomic, copy) NSString *focusGroupIdentifier API_AVAILABLE(ios(15.0));
@property (nullable, nonatomic, copy) NSString *interactionActivityTrackingBaseName API_AVAILABLE(ios(16.0));
/* a child's Auto Layout fitting size changed */
- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(id)container;
@end
/* zoom transitions (iOS 18): the alignment rect and whether an interactive dismissal may begin */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UIZoomTransitionOptions.AlignmentRectContext)
@interface UIZoomTransitionAlignmentRectContext : NSObject
@property (nonatomic, readonly) UIView *sourceView;
@property (nonatomic, readonly) UIViewController *zoomedViewController;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UIZoomTransitionOptions.InteractionContext)
@interface UIZoomTransitionInteractionContext : NSObject
@property (nonatomic, readonly) CGPoint location;
@property (nonatomic, readonly) CGVector velocity;
@property (nonatomic, readonly) BOOL willBegin;
@end
@interface UIZoomTransitionOptions (UIViewControllerExtras)
@property (nonatomic, copy, nullable) CGRect (^alignmentRectProvider)(UIZoomTransitionAlignmentRectContext *context);
@property (nonatomic, copy, nullable) BOOL (^interactiveDismissShouldBegin)(UIZoomTransitionInteractionContext *context);
@end
NS_ASSUME_NONNULL_END
