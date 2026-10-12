#pragma once
/* isim: UIView members from the documentation sweep (#9): the update constraints pass, layout margins that preserve
   the superview's or ignore the safe area, alignment rects, baseline views, ambiguity checks, content size category
   limits, system animations and repeated animations. UIViewExtras.m (with hooks in UIView.m). Categories (no
   ivars: the class's size must not change for apps' subclasses). */
#import <UIKit/UIView.h>
#import <UIKit/UIContentSizeCategory.h>
NS_ASSUME_NONNULL_BEGIN
@class NSLayoutConstraint;

/* the focus engine's group priorities (iOS 15; isim has no focus engine: stored) */
typedef NSInteger UIFocusGroupPriority NS_TYPED_EXTENSIBLE_ENUM API_AVAILABLE(ios(15.0));
static const UIFocusGroupPriority UIFocusGroupPriorityIgnored = 0;
static const UIFocusGroupPriority UIFocusGroupPriorityPreviouslyFocused = 1000;
static const UIFocusGroupPriority UIFocusGroupPriorityPrioritized = 2000;
static const UIFocusGroupPriority UIFocusGroupPriorityCurrentlyFocused = NSIntegerMax;

/* the legacy (begin/commit) transitions' kinds */
typedef NS_ENUM(NSInteger, UIViewAnimationTransition) { UIViewAnimationTransitionNone, UIViewAnimationTransitionFlipFromLeft,
    UIViewAnimationTransitionFlipFromRight, UIViewAnimationTransitionCurlUp, UIViewAnimationTransitionCurlDown } NS_SWIFT_NAME(UIView.AnimationTransition);
/* system animations: delete shrinks and fades the views, then removes them from their superviews */
typedef NS_ENUM(NSUInteger, UISystemAnimation) { UISystemAnimationDelete } NS_SWIFT_NAME(UIView.SystemAnimation);

@interface UIView (UIViewExtras)
/* layout margins: preserving the superview's keeps at least the part of its margins this view overlaps; insetting
   from the safe area (default YES) keeps the margins guide inside the safe area */
@property (nonatomic) BOOL preservesSuperviewLayoutMargins;
@property (nonatomic) BOOL insetsLayoutMarginsFromSafeArea API_AVAILABLE(ios(11.0));
- (void)layoutMarginsDidChange;
/* alignment rects: Auto Layout positions the frame inset by alignmentRectInsets */
- (CGRect)alignmentRectForFrame:(CGRect)frame;
- (CGRect)frameForAlignmentRect:(CGRect)alignmentRect;
@property (nonatomic, readonly) UIEdgeInsets alignmentRectInsets;
/* the views whose text gives the first / last baseline (default: the view itself) */
@property (nonatomic, readonly, strong) UIView *viewForFirstBaselineLayout NS_SWIFT_NAME(forFirstBaselineLayout);
@property (nonatomic, readonly, strong) UIView *viewForLastBaselineLayout NS_SWIFT_NAME(forLastBaselineLayout);
/* the update constraints pass: before a layout the views that asked for it (setNeedsUpdateConstraints, or on
   entering a window a class that overrides updateConstraints or requires constraint-based layout) get
   updateConstraints (a view controller's root view: the controller's updateViewConstraints), subviews first */
- (BOOL)needsUpdateConstraints;
@property (class, nonatomic, readonly) BOOL requiresConstraintBasedLayout;
- (NSArray<NSLayoutConstraint *> *)constraintsAffectingLayoutForAxis:(UILayoutConstraintAxis)axis;
/* isim's solver never leaves a layout ambiguous (a weak pull keeps under-constrained views put): NO */
@property (nonatomic, readonly) BOOL hasAmbiguousLayout;
- (void)exerciseAmbiguityInLayout;
/* focus: views are not focusable (isim has no focus engine); the group priority is stored */
@property (nonatomic, readonly) BOOL canBecomeFocused;
@property (nonatomic) UIFocusGroupPriority focusGroupPriority API_AVAILABLE(ios(15.0));
/* the Dynamic Type range the view and its subviews see (the trait collection's category is clamped) */
@property (nullable, nonatomic, copy) UIContentSizeCategory minimumContentSizeCategory API_AVAILABLE(ios(15.0));
@property (nullable, nonatomic, copy) UIContentSizeCategory maximumContentSizeCategory API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) NSString *appliedContentSizeCategoryLimitsDescription API_AVAILABLE(ios(15.0));
/* Smart Invert leaves the view as it is (isim draws no inverted colours: stored) */
@property (nonatomic) BOOL accessibilityIgnoresInvertColors API_AVAILABLE(ios(11.0));
/* system animations (delete: the views shrink, fade and leave their superviews), and animations repeated inside an
   animation block */
+ (void)performSystemAnimation:(UISystemAnimation)animation onViews:(NSArray<UIView *> *)views options:(UIViewAnimationOptions)options
                    animations:(void (^ _Nullable)(void))parallelAnimations completion:(void (^ _Nullable)(BOOL finished))completion
    NS_SWIFT_NAME(perform(_:on:options:animations:completion:));
+ (void)modifyAnimationsWithRepeatCount:(CGFloat)count autoreverses:(BOOL)autoreverses animations:(void (NS_NOESCAPE ^)(void))animations API_AVAILABLE(ios(13.0));
@end
NS_ASSUME_NONNULL_END
