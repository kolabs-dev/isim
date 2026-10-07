#pragma once
/* isim: Core Animation animations, transactions and layer classes (QuartzCore in Apple's SDK). Self-authored.
 * Animations are evaluated by isim each frame on the layer's clock; layer.presentation() reports in-flight
 * values. Standalone layers get implicit animations (0.25 s) when an animatable property changes; a view's
 * own layer does not (as on iOS). */
#import <UIKit/CALayer.h>
NS_ASSUME_NONNULL_BEGIN

/* ================= timing functions ================= */
typedef NSString *CAMediaTimingFunctionName NS_TYPED_ENUM;
UIKIT_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionLinear NS_SWIFT_NAME(CAMediaTimingFunctionName.linear);
UIKIT_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionEaseIn NS_SWIFT_NAME(CAMediaTimingFunctionName.easeIn);
UIKIT_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionEaseOut NS_SWIFT_NAME(CAMediaTimingFunctionName.easeOut);
UIKIT_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionEaseInEaseOut NS_SWIFT_NAME(CAMediaTimingFunctionName.easeInEaseOut);
UIKIT_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionDefault NS_SWIFT_NAME(CAMediaTimingFunctionName.default);

@interface CAMediaTimingFunction : NSObject <NSSecureCoding>
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name;
+ (instancetype)functionWithControlPoints:(float)c1x :(float)c1y :(float)c2x :(float)c2y NS_SWIFT_UNAVAILABLE("use init(controlPoints:_:_:_:)");
- (instancetype)initWithName:(CAMediaTimingFunctionName)name NS_SWIFT_NAME(init(name:));
- (instancetype)initWithControlPoints:(float)c1x :(float)c1y :(float)c2x :(float)c2y NS_SWIFT_NAME(init(__controlPoints:_:_:_:));
- (void)getControlPointAtIndex:(size_t)idx values:(float[_Nonnull 2])ptr;
/* isim: the eased fraction for an input fraction (0...1) */
- (float)_isim_solve:(float)t;
@end

/* ================= animations ================= */
@class CAAnimation;
@protocol CAAnimationDelegate <NSObject>
@optional
- (void)animationDidStart:(CAAnimation *)anim;
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag;
@end

@interface CAAnimation : NSObject <NSSecureCoding, NSCopying, CAMediaTiming, CAAction>
+ (instancetype)animation;
+ (nullable id)defaultValueForKey:(NSString *)key;
- (BOOL)shouldArchiveValueForKey:(NSString *)key;
@property (nullable, strong) CAMediaTimingFunction *timingFunction;
@property (nullable, strong) id<CAAnimationDelegate> delegate;      /* retained, as in Core Animation */
@property (getter=isRemovedOnCompletion) BOOL removedOnCompletion;
@property CFTimeInterval beginTime, duration, timeOffset, repeatDuration;
@property float speed, repeatCount;
@property BOOL autoreverses;
@property (copy) CAMediaTimingFillMode fillMode;
@property CAFrameRateRange preferredFrameRateRange;
@end

@class CAValueFunction;
@interface CAPropertyAnimation : CAAnimation
+ (instancetype)animationWithKeyPath:(nullable NSString *)path;
@property (nullable, copy) NSString *keyPath;
@property (getter=isAdditive) BOOL additive;
@property (getter=isCumulative) BOOL cumulative;
@property (nullable, strong) CAValueFunction *valueFunction;
@end

@interface CABasicAnimation : CAPropertyAnimation
@property (nullable, strong) id fromValue, toValue, byValue;
@end

typedef NSString *CAAnimationCalculationMode NS_TYPED_ENUM;
UIKIT_EXTERN CAAnimationCalculationMode const kCAAnimationLinear NS_SWIFT_NAME(CAAnimationCalculationMode.linear);
UIKIT_EXTERN CAAnimationCalculationMode const kCAAnimationDiscrete NS_SWIFT_NAME(CAAnimationCalculationMode.discrete);
UIKIT_EXTERN CAAnimationCalculationMode const kCAAnimationPaced NS_SWIFT_NAME(CAAnimationCalculationMode.paced);
UIKIT_EXTERN CAAnimationCalculationMode const kCAAnimationCubic NS_SWIFT_NAME(CAAnimationCalculationMode.cubic);
UIKIT_EXTERN CAAnimationCalculationMode const kCAAnimationCubicPaced NS_SWIFT_NAME(CAAnimationCalculationMode.cubicPaced);
typedef NSString *CAAnimationRotationMode NS_TYPED_ENUM;
UIKIT_EXTERN CAAnimationRotationMode const kCAAnimationRotateAuto NS_SWIFT_NAME(CAAnimationRotationMode.rotateAuto);
UIKIT_EXTERN CAAnimationRotationMode const kCAAnimationRotateAutoReverse NS_SWIFT_NAME(CAAnimationRotationMode.rotateAutoReverse);

@interface CAKeyframeAnimation : CAPropertyAnimation
@property (nullable, copy) NSArray *values;
@property (nullable) CGPathRef path;
@property (nullable, copy) NSArray<NSNumber *> *keyTimes;
@property (nullable, copy) NSArray<CAMediaTimingFunction *> *timingFunctions;
@property (copy) CAAnimationCalculationMode calculationMode;
@property (nullable, copy) NSArray<NSNumber *> *tensionValues, *continuityValues, *biasValues;
@property (nullable, copy) CAAnimationRotationMode rotationMode;
@end

@interface CASpringAnimation : CABasicAnimation
- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce;
@property CGFloat mass, stiffness, damping, initialVelocity;
@property BOOL allowsOverdamping;
@property (readonly) CFTimeInterval settlingDuration;
@property (readonly) CFTimeInterval perceptualDuration;
@property (readonly) CGFloat bounce;
@end

@interface CAAnimationGroup : CAAnimation
@property (nullable, copy) NSArray<CAAnimation *> *animations;
@end

UIKIT_EXTERN NSString *const kCATransition;     /* the key transitions are added under */
typedef NSString *CATransitionType NS_TYPED_ENUM;
UIKIT_EXTERN CATransitionType const kCATransitionFade NS_SWIFT_NAME(CATransitionType.fade);
UIKIT_EXTERN CATransitionType const kCATransitionMoveIn NS_SWIFT_NAME(CATransitionType.moveIn);
UIKIT_EXTERN CATransitionType const kCATransitionPush NS_SWIFT_NAME(CATransitionType.push);
UIKIT_EXTERN CATransitionType const kCATransitionReveal NS_SWIFT_NAME(CATransitionType.reveal);
typedef NSString *CATransitionSubtype NS_TYPED_ENUM;
UIKIT_EXTERN CATransitionSubtype const kCATransitionFromRight NS_SWIFT_NAME(CATransitionSubtype.fromRight);
UIKIT_EXTERN CATransitionSubtype const kCATransitionFromLeft NS_SWIFT_NAME(CATransitionSubtype.fromLeft);
UIKIT_EXTERN CATransitionSubtype const kCATransitionFromTop NS_SWIFT_NAME(CATransitionSubtype.fromTop);
UIKIT_EXTERN CATransitionSubtype const kCATransitionFromBottom NS_SWIFT_NAME(CATransitionSubtype.fromBottom);

/* isim: the layer's previous rendering (a snapshot taken when the transition is added) fades / slides out
   while its new state comes in */
@interface CATransition : CAAnimation
@property (copy) CATransitionType type;
@property (nullable, copy) CATransitionSubtype subtype;
@property float startProgress, endProgress;
@end

typedef NSString *CAValueFunctionName NS_TYPED_ENUM;
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionRotateX NS_SWIFT_NAME(CAValueFunctionName.rotateX);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionRotateY NS_SWIFT_NAME(CAValueFunctionName.rotateY);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionRotateZ NS_SWIFT_NAME(CAValueFunctionName.rotateZ);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionScale NS_SWIFT_NAME(CAValueFunctionName.scale);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionScaleX NS_SWIFT_NAME(CAValueFunctionName.scaleX);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionScaleY NS_SWIFT_NAME(CAValueFunctionName.scaleY);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionScaleZ NS_SWIFT_NAME(CAValueFunctionName.scaleZ);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionTranslate NS_SWIFT_NAME(CAValueFunctionName.translate);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionTranslateX NS_SWIFT_NAME(CAValueFunctionName.translateX);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionTranslateY NS_SWIFT_NAME(CAValueFunctionName.translateY);
UIKIT_EXTERN CAValueFunctionName const kCAValueFunctionTranslateZ NS_SWIFT_NAME(CAValueFunctionName.translateZ);
@interface CAValueFunction : NSObject <NSSecureCoding>
+ (nullable instancetype)functionWithName:(CAValueFunctionName)name;
@property (readonly) CAValueFunctionName name;
@end

/* ================= transactions ================= */
UIKIT_EXTERN NSString *const kCATransactionAnimationDuration, *const kCATransactionDisableActions,
                      *const kCATransactionAnimationTimingFunction, *const kCATransactionCompletionBlock;
@interface CATransaction : NSObject
+ (void)begin;
+ (void)commit;
+ (void)flush;
+ (void)lock;
+ (void)unlock;
+ (CFTimeInterval)animationDuration;
+ (void)setAnimationDuration:(CFTimeInterval)dur;
+ (nullable CAMediaTimingFunction *)animationTimingFunction;
+ (void)setAnimationTimingFunction:(nullable CAMediaTimingFunction *)function;
+ (BOOL)disableActions;
+ (void)setDisableActions:(BOOL)flag;
+ (nullable void (^)(void))completionBlock;
+ (void)setCompletionBlock:(nullable void (^)(void))block;
+ (nullable id)valueForKey:(NSString *)key;
+ (void)setValue:(nullable id)anObject forKey:(NSString *)key;
@end

/* ================= UIView ================= */
@interface UIView (IsimCoreAnimation)
/* a 3D transform about the view's center (perspective is drawn by warping the rendered view) */
@property (nonatomic) CATransform3D transform3D;
/* the view whose alpha masks this view (its frame is in this view's coordinates) */
@property (nullable, nonatomic, strong) UIView *maskView NS_SWIFT_NAME(mask);
@end
NS_ASSUME_NONNULL_END
