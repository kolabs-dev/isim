#pragma once
/* isim: UIViewPropertyAnimator (interruptible, scrubbable, reversible), timing parameters, keyframe animations and
   view-to-view transitions. Flip and curl transitions are drawn as 2D squash/stretch (no 3D perspective). */
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UICubicTimingParameters, UISpringTimingParameters;

typedef NS_ENUM(NSInteger, UIViewAnimationCurve) {
    UIViewAnimationCurveEaseInOut, UIViewAnimationCurveEaseIn, UIViewAnimationCurveEaseOut, UIViewAnimationCurveLinear
} NS_SWIFT_NAME(UIView.AnimationCurve);
typedef NS_ENUM(NSInteger, UIViewAnimatingState) { UIViewAnimatingStateInactive, UIViewAnimatingStateActive, UIViewAnimatingStateStopped };
typedef NS_ENUM(NSInteger, UIViewAnimatingPosition) { UIViewAnimatingPositionEnd, UIViewAnimatingPositionStart, UIViewAnimatingPositionCurrent };
typedef NS_ENUM(NSInteger, UITimingCurveType) { UITimingCurveTypeBuiltin, UITimingCurveTypeCubic, UITimingCurveTypeSpring, UITimingCurveTypeComposed };
typedef NS_OPTIONS(NSUInteger, UIViewKeyframeAnimationOptions) {
    UIViewKeyframeAnimationOptionLayoutSubviews = 1 << 0, UIViewKeyframeAnimationOptionAllowUserInteraction = 1 << 1,
    UIViewKeyframeAnimationOptionBeginFromCurrentState = 1 << 2, UIViewKeyframeAnimationOptionRepeat = 1 << 3,
    UIViewKeyframeAnimationOptionAutoreverse = 1 << 4, UIViewKeyframeAnimationOptionOverrideInheritedDuration = 1 << 5,
    UIViewKeyframeAnimationOptionOverrideInheritedOptions = 1 << 9,
    UIViewKeyframeAnimationOptionCalculationModeLinear = 0 << 10, UIViewKeyframeAnimationOptionCalculationModeDiscrete = 1 << 10,
    UIViewKeyframeAnimationOptionCalculationModePaced = 2 << 10, UIViewKeyframeAnimationOptionCalculationModeCubic = 3 << 10,
    UIViewKeyframeAnimationOptionCalculationModeCubicPaced = 4 << 10
} NS_SWIFT_NAME(UIView.KeyframeAnimationOptions);

NS_SWIFT_UI_ACTOR
@protocol UITimingCurveProvider <NSCoding, NSCopying>
@property (nonatomic, readonly) UITimingCurveType timingCurveType;
@property (nullable, nonatomic, readonly) UICubicTimingParameters *cubicTimingParameters;
@property (nullable, nonatomic, readonly) UISpringTimingParameters *springTimingParameters;
@end

NS_SWIFT_UI_ACTOR
@interface UICubicTimingParameters : NSObject <UITimingCurveProvider>
- (instancetype)init;
- (instancetype)initWithAnimationCurve:(UIViewAnimationCurve)curve;
- (instancetype)initWithControlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2;
@property (nonatomic, readonly) UIViewAnimationCurve animationCurve;
@property (nonatomic, readonly) CGPoint controlPoint1;
@property (nonatomic, readonly) CGPoint controlPoint2;
@end

NS_SWIFT_UI_ACTOR
@interface UISpringTimingParameters : NSObject <UITimingCurveProvider>
- (instancetype)init;
- (instancetype)initWithDampingRatio:(CGFloat)ratio initialVelocity:(CGVector)velocity;
- (instancetype)initWithDampingRatio:(CGFloat)ratio;
- (instancetype)initWithMass:(CGFloat)mass stiffness:(CGFloat)stiffness damping:(CGFloat)damping initialVelocity:(CGVector)velocity;
- (instancetype)initWithDuration:(NSTimeInterval)duration bounce:(CGFloat)bounce initialVelocity:(CGVector)velocity API_AVAILABLE(ios(17.0));
@property (nonatomic, readonly) CGVector initialVelocity;
@end

NS_SWIFT_UI_ACTOR
@protocol UIViewAnimating <NSObject>
@property (nonatomic, readonly) UIViewAnimatingState state;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, getter=isReversed) BOOL reversed;
@property (nonatomic) CGFloat fractionComplete;
- (void)startAnimation;
- (void)startAnimationAfterDelay:(NSTimeInterval)delay;
- (void)pauseAnimation;
- (void)stopAnimation:(BOOL)withoutFinishing;
- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)finalPosition;
@end

NS_SWIFT_UI_ACTOR
@protocol UIViewImplicitlyAnimating <UIViewAnimating>
@optional
- (void)addAnimations:(void (^)(void))animation delayFactor:(CGFloat)delayFactor;
- (void)addAnimations:(void (^)(void))animation;
- (void)addCompletion:(void (^)(UIViewAnimatingPosition finalPosition))completion;
- (void)continueAnimationWithTimingParameters:(nullable id<UITimingCurveProvider>)parameters durationFactor:(CGFloat)durationFactor;
@end

/* isim: continueAnimation keeps the original curve (only the duration factor applies); scrubsLinearly is stored */
NS_SWIFT_UI_ACTOR
@interface UIViewPropertyAnimator : NSObject <UIViewImplicitlyAnimating, NSCopying>
@property (nonatomic, copy, readonly) id<UITimingCurveProvider> timingParameters;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval delay;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, getter=isManualHitTestingEnabled) BOOL manualHitTestingEnabled;
@property (nonatomic, getter=isInterruptible) BOOL interruptible;
@property (nonatomic) BOOL scrubsLinearly;
@property (nonatomic) BOOL pausesOnCompletion;
- (instancetype)initWithDuration:(NSTimeInterval)duration timingParameters:(id<UITimingCurveProvider>)parameters NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve animations:(void (^ _Nullable)(void))animations;
- (instancetype)initWithDuration:(NSTimeInterval)duration controlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2 animations:(void (^ _Nullable)(void))animations;
- (instancetype)initWithDuration:(NSTimeInterval)duration dampingRatio:(CGFloat)ratio animations:(void (^ _Nullable)(void))animations;
+ (instancetype)runningPropertyAnimatorWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options
                                          animations:(void (^)(void))animations completion:(void (^ _Nullable)(UIViewAnimatingPosition finalPosition))completion;
@property (nonatomic, readonly) UIViewAnimatingState state;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, getter=isReversed) BOOL reversed;
@property (nonatomic) CGFloat fractionComplete;
- (void)startAnimation;
- (void)startAnimationAfterDelay:(NSTimeInterval)delay;
- (void)pauseAnimation;
- (void)stopAnimation:(BOOL)withoutFinishing;
- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)finalPosition;
- (void)addAnimations:(void (^)(void))animation delayFactor:(CGFloat)delayFactor;
- (void)addAnimations:(void (^)(void))animation;
- (void)addCompletion:(void (^)(UIViewAnimatingPosition finalPosition))completion;
- (void)continueAnimationWithTimingParameters:(nullable id<UITimingCurveProvider>)parameters durationFactor:(CGFloat)durationFactor;
@end

@interface UIView (UIViewKeyframeAnimations)
+ (void)animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)options
                          animations:(void (^)(void))animations completion:(void (^ _Nullable)(BOOL finished))completion;
+ (void)addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations;
/* replaces fromView with toView in its superview (or hides/shows them with .showHideTransitionViews) */
+ (void)transitionFromView:(UIView *)fromView toView:(UIView *)toView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options
                completion:(void (^ _Nullable)(BOOL finished))completion;
@end
NS_ASSUME_NONNULL_END
