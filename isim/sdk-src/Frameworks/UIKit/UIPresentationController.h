#pragma once
/* isim: presentation controllers (sheets with detents, popovers, custom), modal transition styles, custom and
   interactive view-controller transitions, transition coordinators. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewPropertyAnimator.h>
NS_ASSUME_NONNULL_BEGIN
@class UIPresentationController, UISheetPresentationController, UIPopoverPresentationController, UIBarButtonItem, UITraitCollection, UIColor;
@protocol UIViewControllerTransitioningDelegate, UIViewControllerTransitionCoordinator;

typedef NS_ENUM(NSInteger, UIModalTransitionStyle) {
    UIModalTransitionStyleCoverVertical = 0, UIModalTransitionStyleFlipHorizontal, UIModalTransitionStyleCrossDissolve, UIModalTransitionStylePartialCurl
};

/* ---- transitions ---- */
typedef NSString *UITransitionContextViewControllerKey NS_TYPED_ENUM;
typedef NSString *UITransitionContextViewKey NS_TYPED_ENUM;
UIKIT_EXTERN UITransitionContextViewControllerKey const UITransitionContextFromViewControllerKey NS_SWIFT_NAME(from);
UIKIT_EXTERN UITransitionContextViewControllerKey const UITransitionContextToViewControllerKey NS_SWIFT_NAME(to);
UIKIT_EXTERN UITransitionContextViewKey const UITransitionContextFromViewKey NS_SWIFT_NAME(from);
UIKIT_EXTERN UITransitionContextViewKey const UITransitionContextToViewKey NS_SWIFT_NAME(to);

NS_SWIFT_UI_ACTOR
@protocol UIViewControllerContextTransitioning <NSObject>
@property (nonatomic, readonly) UIView *containerView;
@property (nonatomic, readonly, getter=isAnimated) BOOL animated;
@property (nonatomic, readonly, getter=isInteractive) BOOL interactive;
@property (nonatomic, readonly) BOOL transitionWasCancelled;
@property (nonatomic, readonly) UIModalPresentationStyle presentationStyle;
- (void)updateInteractiveTransition:(CGFloat)percentComplete;
- (void)finishInteractiveTransition;
- (void)cancelInteractiveTransition;
- (void)pauseInteractiveTransition;
- (void)completeTransition:(BOOL)didComplete;
- (nullable __kindof UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)key;
- (nullable __kindof UIView *)viewForKey:(UITransitionContextViewKey)key;
@property (nonatomic, readonly) CGAffineTransform targetTransform;
- (CGRect)initialFrameForViewController:(UIViewController *)vc;
- (CGRect)finalFrameForViewController:(UIViewController *)vc;
@end

NS_SWIFT_UI_ACTOR
@protocol UIViewControllerAnimatedTransitioning <NSObject>
- (NSTimeInterval)transitionDuration:(nullable id<UIViewControllerContextTransitioning>)transitionContext NS_SWIFT_NAME(transitionDuration(using:));
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext NS_SWIFT_NAME(animateTransition(using:));
@optional
- (id<UIViewImplicitlyAnimating>)interruptibleAnimatorForTransition:(id<UIViewControllerContextTransitioning>)transitionContext NS_SWIFT_NAME(interruptibleAnimator(using:));
- (void)animationEnded:(BOOL)transitionCompleted;
@end

NS_SWIFT_UI_ACTOR
@protocol UIViewControllerInteractiveTransitioning <NSObject>
- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext;
@optional
@property (nonatomic, readonly) CGFloat completionSpeed;
@property (nonatomic, readonly) UIViewAnimationCurve completionCurve;
@property (nonatomic, readonly) BOOL wantsInteractiveStart;
@end

/* drives the animator's animations (UIView.animate inside animateTransition, or its interruptible animator) by percentage */
NS_SWIFT_UI_ACTOR
@interface UIPercentDrivenInteractiveTransition : NSObject <UIViewControllerInteractiveTransitioning>
@property (nonatomic, readonly) CGFloat duration;
@property (nonatomic, readonly) CGFloat percentComplete;
@property (nonatomic) CGFloat completionSpeed;
@property (nonatomic) UIViewAnimationCurve completionCurve;
@property (nullable, nonatomic, strong) id<UITimingCurveProvider> timingCurve;
@property (nonatomic) BOOL wantsInteractiveStart;
- (void)pauseInteractiveTransition;
- (void)updateInteractiveTransition:(CGFloat)percentComplete;
- (void)cancelInteractiveTransition;
- (void)finishInteractiveTransition;
@end

NS_SWIFT_UI_ACTOR
@protocol UIViewControllerTransitioningDelegate <NSObject>
@optional
- (nullable id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
    NS_SWIFT_NAME(animationController(forPresented:presenting:source:));
- (nullable id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed NS_SWIFT_NAME(animationController(forDismissed:));
- (nullable id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator NS_SWIFT_NAME(interactionControllerForPresentation(using:));
- (nullable id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator NS_SWIFT_NAME(interactionControllerForDismissal(using:));
- (nullable UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(nullable UIViewController *)presenting sourceViewController:(UIViewController *)source
    NS_SWIFT_NAME(presentationController(forPresented:presenting:source:));
@end

NS_SWIFT_UI_ACTOR
@protocol UIViewControllerTransitionCoordinatorContext <NSObject>
@property (nonatomic, readonly, getter=isAnimated) BOOL animated;
@property (nonatomic, readonly) UIModalPresentationStyle presentationStyle;
@property (nonatomic, readonly, getter=isInteractive) BOOL interactive;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly) NSTimeInterval transitionDuration;
@property (nonatomic, readonly) UIView *containerView;
@property (nonatomic, readonly) BOOL initiallyInteractive;
@property (nonatomic, readonly) BOOL isInterruptible;
@property (nonatomic, readonly) CGFloat percentComplete;
@property (nonatomic, readonly) CGFloat completionVelocity;
@property (nonatomic, readonly) CGAffineTransform targetTransform;
- (nullable __kindof UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)key;
- (nullable __kindof UIView *)viewForKey:(UITransitionContextViewKey)key;
@end
NS_SWIFT_UI_ACTOR
@protocol UIViewControllerTransitionCoordinator <UIViewControllerTransitionCoordinatorContext>
- (BOOL)animateAlongsideTransition:(void (^ _Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))animation
                        completion:(void (^ _Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))completion;
- (BOOL)animateAlongsideTransitionInView:(nullable UIView *)view
                               animation:(void (^ _Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))animation
                              completion:(void (^ _Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))completion;
@end

/* ---- presentation controllers ---- */
NS_SWIFT_UI_ACTOR
@protocol UIAdaptivePresentationControllerDelegate <NSObject>
@optional
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller;
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection;
- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController;
- (void)presentationControllerWillDismiss:(UIPresentationController *)presentationController;
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController;
- (void)presentationControllerDidAttemptToDismiss:(UIPresentationController *)presentationController NS_SWIFT_NAME(presentationControllerDidAttemptToDismiss(_:));
@end

NS_SWIFT_UI_ACTOR
@interface UIPresentationController : NSObject <UITraitEnvironment>
- (instancetype)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(nullable UIViewController *)presentingViewController NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, strong, readonly) UIViewController *presentingViewController;
@property (nonatomic, strong, readonly) UIViewController *presentedViewController;
@property (nonatomic, readonly) UIModalPresentationStyle presentationStyle;
@property (nullable, nonatomic, readonly, strong) UIView *containerView;
@property (nullable, nonatomic, weak) id<UIAdaptivePresentationControllerDelegate> delegate;
- (UIModalPresentationStyle)adaptivePresentationStyle;
- (UIModalPresentationStyle)adaptivePresentationStyleForTraitCollection:(UITraitCollection *)traitCollection;
@property (nullable, nonatomic, readonly) UIView *presentedView;
@property (nonatomic, readonly) CGRect frameOfPresentedViewInContainerView;
@property (nonatomic, readonly) BOOL shouldPresentInFullscreen;
@property (nonatomic, readonly) BOOL shouldRemovePresentersView;
- (void)containerViewWillLayoutSubviews;
- (void)containerViewDidLayoutSubviews;
- (void)presentationTransitionWillBegin;
- (void)presentationTransitionDidEnd:(BOOL)completed;
- (void)dismissalTransitionWillBegin;
- (void)dismissalTransitionDidEnd:(BOOL)completed;
- (CGSize)sizeForChildContentContainer:(id)container withParentContainerSize:(CGSize)parentSize;
- (void)preferredContentSizeDidChangeForChildContentContainer:(id)container;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection;
@end

/* sheets */
typedef NSString *UISheetPresentationControllerDetentIdentifier NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UISheetPresentationController.Detent.Identifier);
UIKIT_EXTERN const UISheetPresentationControllerDetentIdentifier UISheetPresentationControllerDetentIdentifierMedium;
UIKIT_EXTERN const UISheetPresentationControllerDetentIdentifier UISheetPresentationControllerDetentIdentifierLarge;
UIKIT_EXTERN const CGFloat UISheetPresentationControllerAutomaticDimension NS_SWIFT_NAME(UISheetPresentationController.automaticDimension);
UIKIT_EXTERN const CGFloat UISheetPresentationControllerDetentInactive NS_SWIFT_NAME(UISheetPresentationController.Detent.inactive);

NS_SWIFT_UI_ACTOR
@protocol UISheetPresentationControllerDetentResolutionContext <NSObject>
@property (nonatomic, readonly) UITraitCollection *containerTraitCollection;
@property (nonatomic, readonly) CGFloat maximumDetentValue;
@end

NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UISheetPresentationController.Detent)
@interface UISheetPresentationControllerDetent : NSObject
+ (instancetype)mediumDetent NS_SWIFT_NAME(medium());
+ (instancetype)largeDetent NS_SWIFT_NAME(large());
+ (instancetype)customDetentWithIdentifier:(nullable UISheetPresentationControllerDetentIdentifier)identifier
                                  resolver:(CGFloat (^)(id<UISheetPresentationControllerDetentResolutionContext> context))resolver NS_SWIFT_NAME(custom(identifier:resolver:));
@property (nonatomic, readonly) UISheetPresentationControllerDetentIdentifier identifier;
- (CGFloat)resolvedValueInContext:(id<UISheetPresentationControllerDetentResolutionContext>)context NS_SWIFT_NAME(resolvedValue(in:));
@end

@class UISheetPresentationController;
NS_SWIFT_UI_ACTOR
@protocol UISheetPresentationControllerDelegate <UIAdaptivePresentationControllerDelegate>
@optional
- (void)sheetPresentationControllerDidChangeSelectedDetentIdentifier:(UISheetPresentationController *)sheetPresentationController;
@end

/* isim: iPhone sheets (detents, grabber, dimming above largestUndimmedDetentIdentifier, card stack at the large
   detent, drag between detents / to dismiss); on iPad (regular width) sheets stay centered cards without detents */
NS_SWIFT_UI_ACTOR
@interface UISheetPresentationController : UIPresentationController
@property (nullable, nonatomic, weak) id<UISheetPresentationControllerDelegate> delegate;
@property (nonatomic, copy) NSArray<UISheetPresentationControllerDetent *> *detents;
@property (nullable, nonatomic, copy) UISheetPresentationControllerDetentIdentifier selectedDetentIdentifier;
@property (nullable, nonatomic, copy) UISheetPresentationControllerDetentIdentifier largestUndimmedDetentIdentifier;
@property (nonatomic) BOOL prefersGrabberVisible;
@property (nonatomic) BOOL prefersScrollingExpandsWhenScrolledToEdge;
@property (nonatomic) BOOL prefersEdgeAttachedInCompactHeight;
@property (nonatomic) BOOL widthFollowsPreferredContentSizeWhenEdgeAttached;
@property (nonatomic) BOOL prefersPageSizing;
@property (nonatomic) CGFloat preferredCornerRadius;
@property (nullable, nonatomic, strong) UIView *sourceView;
- (void)animateChanges:(void (NS_NOESCAPE ^)(void))changes;
- (void)invalidateDetents;
@end

/* popovers */
typedef NS_OPTIONS(NSUInteger, UIPopoverArrowDirection) {
    UIPopoverArrowDirectionUp = 1UL << 0, UIPopoverArrowDirectionDown = 1UL << 1, UIPopoverArrowDirectionLeft = 1UL << 2,
    UIPopoverArrowDirectionRight = 1UL << 3,
    UIPopoverArrowDirectionAny = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown | UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight,
    UIPopoverArrowDirectionUnknown = NSUIntegerMax
};
NS_SWIFT_UI_ACTOR
@protocol UIPopoverPresentationControllerDelegate <UIAdaptivePresentationControllerDelegate>
@optional
- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController NS_SWIFT_NAME(prepareForPopoverPresentation(_:));
- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController;
- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController;
@end
/* isim: on iPhone a popover adapts to a sheet unless the delegate's adaptivePresentationStyle returns .none */
NS_SWIFT_UI_ACTOR
@interface UIPopoverPresentationController : UIPresentationController
@property (nullable, nonatomic, weak) id<UIPopoverPresentationControllerDelegate> delegate;
@property (nonatomic) UIPopoverArrowDirection permittedArrowDirections;
@property (nullable, nonatomic, strong) UIView *sourceView;
@property (nonatomic) CGRect sourceRect;
@property (nullable, nonatomic, strong) UIBarButtonItem *barButtonItem;
@property (nonatomic, readonly) UIPopoverArrowDirection arrowDirection;
@property (nullable, nonatomic, copy) NSArray<UIView *> *passthroughViews;
@property (nullable, nonatomic, copy) UIColor *backgroundColor;
@property (nonatomic) BOOL canOverlapSourceViewRect;
@end

@interface UIViewController (UIPresentation)
@property (nonatomic) UIModalTransitionStyle modalTransitionStyle;
@property (nullable, nonatomic, weak) id<UIViewControllerTransitioningDelegate> transitioningDelegate;
@property (nonatomic) BOOL definesPresentationContext;
@property (nonatomic) BOOL providesPresentationContextTransitionStyle;
@property (nullable, nonatomic, readonly) UIPresentationController *presentationController;
@property (nullable, nonatomic, readonly) UISheetPresentationController *sheetPresentationController;
@property (nullable, nonatomic, readonly) UIPopoverPresentationController *popoverPresentationController;
@property (nonatomic, readonly, getter=isBeingPresented) BOOL beingPresented;
@property (nonatomic, readonly, getter=isBeingDismissed) BOOL beingDismissed;
@property (nullable, nonatomic, readonly) id<UIViewControllerTransitionCoordinator> transitionCoordinator;
@property (nonatomic) CGSize preferredContentSize;
- (void)preferredContentSizeDidChangeForChildContentContainer:(id)container;
- (void)showViewController:(UIViewController *)vc sender:(nullable id)sender NS_SWIFT_NAME(show(_:sender:));
- (void)showDetailViewController:(UIViewController *)vc sender:(nullable id)sender;
@end
NS_ASSUME_NONNULL_END
