#pragma once
/* isim SceneKit: animations on nodes (Core Animation animations and SCNAnimation, on transform and opacity key paths)
 * and SCNTransaction (issue #330). isim keeps one copy of the scene graph: animations write the nodes themselves. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol SCNAnimation <NSObject>
@end
@interface CAAnimation (SCNAnimation) <SCNAnimation>
@end
@interface SCNAnimation : NSObject <SCNAnimation, NSCopying, NSSecureCoding>
+ (instancetype)animationWithCAAnimation:(CAAnimation *)caAnimation;
@property (nonatomic) NSTimeInterval duration, timeOffset, blendInDuration, blendOutDuration, startDelay;
@property (nonatomic, copy, nullable) NSString *keyPath;
@property (nonatomic) CGFloat repeatCount;
@property (nonatomic) BOOL autoreverses;
@property (nonatomic, getter=isRemovedOnCompletion) BOOL removedOnCompletion;
@property (nonatomic, getter=isAdditive) BOOL additive;
@property (nonatomic, getter=isCumulative) BOOL cumulative;
@end
@interface SCNAnimationPlayer : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)animationPlayerWithAnimation:(SCNAnimation *)animation;
@property (nonatomic, readonly) SCNAnimation *animation;
@property (nonatomic) CGFloat speed, blendFactor;
@property (nonatomic) BOOL paused;
- (void)play;
- (void)stop;
- (void)stopWithBlendOutDuration:(NSTimeInterval)duration;
@end
@protocol SCNAnimatable <NSObject>
- (void)addAnimation:(id<SCNAnimation>)animation forKey:(nullable NSString *)key;
- (void)addAnimationPlayer:(SCNAnimationPlayer *)player forKey:(nullable NSString *)key;
- (void)removeAllAnimations;
- (void)removeAllAnimationsWithBlendOutDuration:(CGFloat)duration;
- (void)removeAnimationForKey:(NSString *)key;
- (void)removeAnimationForKey:(NSString *)key blendOutDuration:(CGFloat)duration;
@property (readonly) NSArray<NSString *> *animationKeys;
- (nullable SCNAnimationPlayer *)animationPlayerForKey:(NSString *)key;
@end
@interface SCNTransaction : NSObject
+ (void)begin;
+ (void)commit;
+ (void)flush;
+ (void)lock;
+ (void)unlock;
@property (class, nonatomic) CFTimeInterval animationDuration;
@property (class, nonatomic, copy, nullable) CAMediaTimingFunction *animationTimingFunction;
@property (class, nonatomic) BOOL disableActions;
@property (class, nonatomic, copy, nullable) void (^completionBlock)(void);
+ (nullable id)valueForKey:(NSString *)key;
+ (void)setValue:(nullable id)value forKey:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
#endif
