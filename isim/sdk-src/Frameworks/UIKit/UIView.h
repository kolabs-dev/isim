#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIGeometry.h>
#import <UIKit/UITraitCollection.h>
#include <CoreGraphics/CGAffineTransform.h>
NS_ASSUME_NONNULL_BEGIN
@class NSCoder, UIColor, CALayer, UIWindow, UILayoutGuide, NSLayoutConstraint, NSLayoutXAxisAnchor, NSLayoutYAxisAnchor, NSLayoutDimension, UIGestureRecognizer;

typedef NS_OPTIONS(NSUInteger, UIViewAutoresizing) {
    UIViewAutoresizingNone = 0, UIViewAutoresizingFlexibleLeftMargin = 1 << 0, UIViewAutoresizingFlexibleWidth = 1 << 1,
    UIViewAutoresizingFlexibleRightMargin = 1 << 2, UIViewAutoresizingFlexibleTopMargin = 1 << 3,
    UIViewAutoresizingFlexibleHeight = 1 << 4, UIViewAutoresizingFlexibleBottomMargin = 1 << 5
};
typedef NS_ENUM(NSInteger, UIUserInterfaceLayoutDirection) { UIUserInterfaceLayoutDirectionLeftToRight, UIUserInterfaceLayoutDirectionRightToLeft };
typedef NS_ENUM(NSInteger, UISemanticContentAttribute) {
    UISemanticContentAttributeUnspecified = 0, UISemanticContentAttributePlayback, UISemanticContentAttributeSpatial,
    UISemanticContentAttributeForceLeftToRight, UISemanticContentAttributeForceRightToLeft
};
typedef NS_ENUM(NSInteger, UIViewContentMode) {
    UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFit, UIViewContentModeScaleAspectFill, UIViewContentModeRedraw,
    UIViewContentModeCenter, UIViewContentModeTop, UIViewContentModeBottom, UIViewContentModeLeft, UIViewContentModeRight,
    UIViewContentModeTopLeft, UIViewContentModeTopRight, UIViewContentModeBottomLeft, UIViewContentModeBottomRight
};
typedef NS_OPTIONS(NSUInteger, UIViewAnimationOptions) {
    UIViewAnimationOptionLayoutSubviews = 1 << 0, UIViewAnimationOptionAllowUserInteraction = 1 << 1,
    UIViewAnimationOptionBeginFromCurrentState = 1 << 2, UIViewAnimationOptionRepeat = 1 << 3, UIViewAnimationOptionAutoreverse = 1 << 4,
    UIViewAnimationOptionOverrideInheritedDuration = 1 << 5, UIViewAnimationOptionOverrideInheritedCurve = 1 << 6,
    UIViewAnimationOptionAllowAnimatedContent = 1 << 7, UIViewAnimationOptionShowHideTransitionViews = 1 << 8,
    UIViewAnimationOptionOverrideInheritedOptions = 1 << 9, UIViewAnimationOptionCurveEaseInOut = 0 << 16,
    UIViewAnimationOptionCurveEaseIn = 1 << 16, UIViewAnimationOptionCurveEaseOut = 2 << 16, UIViewAnimationOptionCurveLinear = 3 << 16,
    UIViewAnimationOptionTransitionNone = 0 << 20, UIViewAnimationOptionTransitionFlipFromLeft = 1 << 20,
    UIViewAnimationOptionTransitionFlipFromRight = 2 << 20, UIViewAnimationOptionTransitionCurlUp = 3 << 20,
    UIViewAnimationOptionTransitionCurlDown = 4 << 20, UIViewAnimationOptionTransitionCrossDissolve = 5 << 20,
    UIViewAnimationOptionTransitionFlipFromTop = 6 << 20, UIViewAnimationOptionTransitionFlipFromBottom = 7 << 20,
    UIViewAnimationOptionPreferredFramesPerSecondDefault = 0 << 24, UIViewAnimationOptionPreferredFramesPerSecond60 = 3 << 24,
    UIViewAnimationOptionPreferredFramesPerSecond30 = 7 << 24,
    /* iOS 26: pending trait, property and layout updates are applied before the animations and, animated, after them */
    UIViewAnimationOptionFlushUpdates API_AVAILABLE(ios(26.0)) = 1 << 29,
};
typedef NS_ENUM(NSInteger, UILayoutConstraintAxis) { UILayoutConstraintAxisHorizontal = 0, UILayoutConstraintAxisVertical = 1 };
typedef float UILayoutPriority NS_TYPED_EXTENSIBLE_ENUM;
static const UILayoutPriority UILayoutPriorityRequired = 1000;
static const UILayoutPriority UILayoutPriorityDefaultHigh = 750;
static const UILayoutPriority UILayoutPriorityDefaultLow = 250;
static const UILayoutPriority UILayoutPriorityFittingSizeLevel = 50;
UIKIT_EXTERN const CGFloat UIViewNoIntrinsicMetric;
UIKIT_EXTERN const CGSize UILayoutFittingCompressedSize;
UIKIT_EXTERN const CGSize UILayoutFittingExpandedSize;

typedef NS_ENUM(NSInteger, UIViewTintAdjustmentMode) { UIViewTintAdjustmentModeAutomatic, UIViewTintAdjustmentModeNormal, UIViewTintAdjustmentModeDimmed };
NS_SWIFT_UI_ACTOR
@protocol UICoordinateSpace <NSObject>
- (CGPoint)convertPoint:(CGPoint)point toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace;
- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace;
- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace;
- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace;
@property (readonly, nonatomic) CGRect bounds;
@end
/* isim: a rect converted through its corners (UICoordinateSpace implementations) */
CGRect isim_ui_space_convert_rect(id<UICoordinateSpace> space, CGRect rect, id<UICoordinateSpace> other, BOOL to);

@interface UIView : UIResponder <NSCoding, UITraitEnvironment, UICoordinateSpace>
@property (class, nonatomic, readonly) Class layerClass;
- (instancetype)initWithFrame:(CGRect)frame NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic) NSInteger tag;
@property (nonatomic, readonly, strong) CALayer *layer;
@property (nonatomic) CGRect frame;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGPoint center;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic, readonly, nullable) UIView *superview;
@property (nonatomic, readonly, copy) NSArray<__kindof UIView *> *subviews;
@property (nonatomic, readonly, nullable) UIWindow *window;
- (void)removeFromSuperview;
- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index;
- (void)exchangeSubviewAtIndex:(NSInteger)index1 withSubviewAtIndex:(NSInteger)index2;
- (void)addSubview:(UIView *)view;
- (void)insertSubview:(UIView *)view belowSubview:(UIView *)siblingSubview;
- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)siblingSubview;
- (void)bringSubviewToFront:(UIView *)view NS_SWIFT_NAME(bringSubviewToFront(_:));
- (void)sendSubviewToBack:(UIView *)view NS_SWIFT_NAME(sendSubviewToBack(_:));
- (void)didAddSubview:(UIView *)subview;
- (void)willRemoveSubview:(UIView *)subview;
- (void)willMoveToSuperview:(nullable UIView *)newSuperview;
- (void)didMoveToSuperview;
- (void)willMoveToWindow:(nullable UIWindow *)newWindow;
- (void)didMoveToWindow;
- (BOOL)isDescendantOfView:(UIView *)view;
- (nullable __kindof UIView *)viewWithTag:(NSInteger)tag NS_SWIFT_NAME(viewWithTag(_:));
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
- (void)layoutSubviews;
@property (nonatomic) UIEdgeInsets layoutMargins;
@property (nonatomic) NSDirectionalEdgeInsets directionalLayoutMargins;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
- (void)safeAreaInsetsDidChange;
@property (nonatomic, readonly, strong) UILayoutGuide *layoutMarginsGuide;
@property (nonatomic, readonly, strong) UILayoutGuide *safeAreaLayoutGuide;
@property (nonatomic, readonly, strong) UILayoutGuide *readableContentGuide;
- (CGPoint)convertPoint:(CGPoint)point toView:(nullable UIView *)view;
- (CGPoint)convertPoint:(CGPoint)point fromView:(nullable UIView *)view;
- (CGRect)convertRect:(CGRect)rect toView:(nullable UIView *)view;
- (CGRect)convertRect:(CGRect)rect fromView:(nullable UIView *)view;
@property (nonatomic) BOOL autoresizesSubviews;
@property (nonatomic) UIViewAutoresizing autoresizingMask;
- (CGSize)sizeThatFits:(CGSize)size;
- (void)sizeToFit;
- (nullable UIView *)hitTest:(CGPoint)point withEvent:(nullable UIEvent *)event;
- (BOOL)pointInside:(CGPoint)point withEvent:(nullable UIEvent *)event;
@property (nonatomic, getter=isMultipleTouchEnabled) BOOL multipleTouchEnabled;
@property (nonatomic, getter=isExclusiveTouch) BOOL exclusiveTouch;
- (void)drawRect:(CGRect)rect;
- (void)setNeedsDisplay;
- (void)setNeedsDisplayInRect:(CGRect)rect;
@property (nonatomic) BOOL clipsToBounds;
@property (nonatomic, copy, nullable) UIColor *backgroundColor;
@property (nonatomic) CGFloat alpha;
@property (nonatomic, getter=isOpaque) BOOL opaque;
@property (nonatomic) BOOL clearsContextBeforeDrawing;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) UIViewContentMode contentMode;
@property (null_resettable, nonatomic, strong) UIColor *tintColor;
- (void)tintColorDidChange;
/* dimmed: tintColor reads as a desaturated gray (UIKit dims the views behind an alert); automatic follows the superview */
@property (nonatomic) UIViewTintAdjustmentMode tintAdjustmentMode;
@property (nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection;
/* iOS 17: traits this view and its subviews see on top of the inherited ones */
@property (nonatomic, readonly) id<UITraitOverrides> traitOverrides API_AVAILABLE(ios(17.0));
- (void)updateTraitsIfNeeded API_AVAILABLE(ios(17.0));
/* Auto Layout */
@property (nonatomic, readonly) NSArray<__kindof NSLayoutConstraint *> *constraints;
- (void)addConstraint:(NSLayoutConstraint *)constraint;
- (void)addConstraints:(NSArray<__kindof NSLayoutConstraint *> *)constraints;
- (void)removeConstraint:(NSLayoutConstraint *)constraint;
- (void)removeConstraints:(NSArray<__kindof NSLayoutConstraint *> *)constraints;
@property (nonatomic) BOOL translatesAutoresizingMaskIntoConstraints;
@property (nonatomic, readonly) CGSize intrinsicContentSize;
- (void)invalidateIntrinsicContentSize;
- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize;
- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority verticalFittingPriority:(UILayoutPriority)verticalFittingPriority;
- (UILayoutPriority)contentHuggingPriorityForAxis:(UILayoutConstraintAxis)axis;
- (void)setContentHuggingPriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis;
- (UILayoutPriority)contentCompressionResistancePriorityForAxis:(UILayoutConstraintAxis)axis;
- (void)setContentCompressionResistancePriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis;
- (void)setNeedsUpdateConstraints;
- (void)updateConstraintsIfNeeded;
- (void)updateConstraints NS_REQUIRES_SUPER;
- (void)addLayoutGuide:(UILayoutGuide *)layoutGuide;
- (void)removeLayoutGuide:(UILayoutGuide *)layoutGuide;
@property (nonatomic, readonly, copy) NSArray<__kindof UILayoutGuide *> *layoutGuides;
@property (nonatomic, readonly, strong) NSLayoutXAxisAnchor *leadingAnchor, *trailingAnchor, *leftAnchor, *rightAnchor, *centerXAnchor;
@property (nonatomic, readonly, strong) NSLayoutYAxisAnchor *topAnchor, *bottomAnchor, *centerYAnchor, *firstBaselineAnchor, *lastBaselineAnchor;
@property (nonatomic, readonly, strong) NSLayoutDimension *widthAnchor, *heightAnchor;
/* gestures */
@property (nullable, nonatomic, copy) NSArray<__kindof UIGestureRecognizer *> *gestureRecognizers;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
/* animation: frame/center/bounds, alpha, transform and backgroundColor animate (curves, springs, delay,
   repeat, autoreverse); transitions other than cross dissolve apply without the flip/curl effect */
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
+ (void)performWithoutAnimation:(void (NS_NOESCAPE ^)(void))actionsWithoutAnimation;
- (void)_isim_removeAllAnimations;      /* isim: stops this view's running animations (layer.removeAllAnimations) */
- (void)_isim_setVisualEffect:(nullable const double *)values;   /* isim: SwiftUI visual effects on the view and its subviews (32 values: colour matrix, blur, shadow, blend; see isim_host.h); NULL removes them */
+ (void)animateWithSpringDuration:(NSTimeInterval)duration bounce:(CGFloat)bounce initialSpringVelocity:(CGFloat)velocity delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion
    NS_SWIFT_NAME(animate(springDuration:bounce:initialSpringVelocity:delay:options:animations:completion:)) API_AVAILABLE(ios(17.0));
+ (void)transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options animations:(void (^ _Nullable)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
@property (class, nonatomic, getter=areAnimationsEnabled) BOOL animationsEnabled;
@property (class, nonatomic, readonly) NSTimeInterval inheritedAnimationDuration;
@end
/* snapshots: draws the view and its subviews into the current graphics context (UIGraphicsImageRenderer) */
@interface UIView (UIRightToLeft)
@property (nonatomic) UISemanticContentAttribute semanticContentAttribute;
@property (nonatomic, readonly) UIUserInterfaceLayoutDirection effectiveUserInterfaceLayoutDirection;
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute;
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)semanticContentAttribute
                                                               relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)layoutDirection;
@end
@interface UIView (UISnapshotting)
- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates;
- (nullable UIView *)resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates withCapInsets:(UIEdgeInsets)capInsets;
@end
/* iOS 26: corner configurations. A radius is fixed, or concentric with the view's container (the superview's corner,
   or the screen's for a top-level view, minus the view's inset from it). isim (adapted): "uniform" corners share the
   smallest of their computed radii; corners are circular arcs (no continuous curve). */
API_AVAILABLE(ios(26.0)) NS_REFINED_FOR_SWIFT
@interface UICornerRadius : NSObject <NSCopying>
+ (instancetype)fixedRadius:(CGFloat)radius;
+ (instancetype)containerConcentricRadius;
+ (instancetype)containerConcentricRadiusWithMinimum:(CGFloat)minimum;
@end
API_AVAILABLE(ios(26.0)) NS_REFINED_FOR_SWIFT
@interface UICornerConfiguration : NSObject <NSCopying>
+ (instancetype)configurationWithRadius:(UICornerRadius *)radius;
+ (instancetype)configurationWithTopLeftRadius:(nullable UICornerRadius *)topLeftRadius topRightRadius:(nullable UICornerRadius *)topRightRadius
                              bottomLeftRadius:(nullable UICornerRadius *)bottomLeftRadius bottomRightRadius:(nullable UICornerRadius *)bottomRightRadius;
+ (instancetype)capsuleConfiguration;
+ (instancetype)capsuleConfigurationWithMaximumRadius:(CGFloat)maximumRadius;
+ (instancetype)configurationWithUniformRadius:(UICornerRadius *)radius;
+ (instancetype)configurationWithUniformLeftRadius:(UICornerRadius *)leftRadius uniformRightRadius:(UICornerRadius *)rightRadius;
+ (instancetype)configurationWithUniformTopRadius:(UICornerRadius *)topRadius uniformBottomRadius:(UICornerRadius *)bottomRadius;
+ (instancetype)configurationWithUniformBottomRadius:(UICornerRadius *)bottomRadius topLeftRadius:(nullable UICornerRadius *)topLeftRadius topRightRadius:(nullable UICornerRadius *)topRightRadius;
+ (instancetype)configurationWithUniformLeftRadius:(UICornerRadius *)leftRadius topRightRadius:(nullable UICornerRadius *)topRightRadius bottomRightRadius:(nullable UICornerRadius *)bottomRightRadius;
+ (instancetype)configurationWithUniformRightRadius:(UICornerRadius *)rightRadius topLeftRadius:(nullable UICornerRadius *)topLeftRadius bottomLeftRadius:(nullable UICornerRadius *)bottomLeftRadius;
+ (instancetype)configurationWithUniformTopRadius:(UICornerRadius *)topRadius bottomLeftRadius:(nullable UICornerRadius *)bottomLeftRadius bottomRightRadius:(nullable UICornerRadius *)bottomRightRadius;
@end
@interface UIView (UICornerConfiguration)
@property (nonatomic, copy) UICornerConfiguration *cornerConfiguration API_AVAILABLE(ios(26.0)) NS_REFINED_FOR_SWIFT;
- (CGFloat)effectiveRadiusForCorner:(UIRectCorner)corner API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(effectiveRadius(corner:));
@end
NS_ASSUME_NONNULL_END
