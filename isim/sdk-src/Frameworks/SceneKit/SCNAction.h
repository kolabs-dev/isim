#pragma once
/* isim SceneKit: actions (issue #330), run on nodes each frame of the render loop. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SCNNode, SCNAction;
typedef NS_ENUM(NSInteger, SCNActionTimingMode) {
    SCNActionTimingModeLinear = 0, SCNActionTimingModeEaseIn = 1, SCNActionTimingModeEaseOut = 2, SCNActionTimingModeEaseInEaseOut = 3
};
@protocol SCNActionable <NSObject>
- (void)runAction:(SCNAction *)action;
- (void)runAction:(SCNAction *)action completionHandler:(nullable void (^)(void))block;
- (void)runAction:(SCNAction *)action forKey:(nullable NSString *)key;
- (void)runAction:(SCNAction *)action forKey:(nullable NSString *)key completionHandler:(nullable void (^)(void))block;
@property (nonatomic, readonly) BOOL hasActions;
- (nullable SCNAction *)actionForKey:(NSString *)key;
- (void)removeActionForKey:(NSString *)key;
- (void)removeAllActions;
@property (nonatomic, readonly) NSArray<NSString *> *actionKeys;
@end
@interface SCNAction : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) SCNActionTimingMode timingMode;
@property (nonatomic) CGFloat speed;
- (SCNAction *)reversedAction;
+ (SCNAction *)moveByX:(CGFloat)deltaX y:(CGFloat)deltaY z:(CGFloat)deltaZ duration:(NSTimeInterval)duration;
+ (SCNAction *)moveBy:(SCNVector3)delta duration:(NSTimeInterval)duration;
+ (SCNAction *)moveTo:(SCNVector3)location duration:(NSTimeInterval)duration;
+ (SCNAction *)rotateByX:(CGFloat)xAngle y:(CGFloat)yAngle z:(CGFloat)zAngle duration:(NSTimeInterval)duration;
+ (SCNAction *)rotateToX:(CGFloat)xAngle y:(CGFloat)yAngle z:(CGFloat)zAngle duration:(NSTimeInterval)duration;
+ (SCNAction *)rotateToX:(CGFloat)xAngle y:(CGFloat)yAngle z:(CGFloat)zAngle duration:(NSTimeInterval)duration shortestUnitArc:(BOOL)shortestUnitArc;
+ (SCNAction *)rotateByAngle:(CGFloat)angle aroundAxis:(SCNVector3)axis duration:(NSTimeInterval)duration;
+ (SCNAction *)rotateToAxisAngle:(SCNVector4)axisAngle duration:(NSTimeInterval)duration;
+ (SCNAction *)scaleBy:(CGFloat)scale duration:(NSTimeInterval)sec;
+ (SCNAction *)scaleTo:(CGFloat)scale duration:(NSTimeInterval)sec;
+ (SCNAction *)sequence:(NSArray<SCNAction *> *)actions;
+ (SCNAction *)group:(NSArray<SCNAction *> *)actions;
+ (SCNAction *)repeatAction:(SCNAction *)action count:(NSUInteger)count;
+ (SCNAction *)repeatActionForever:(SCNAction *)action;
+ (SCNAction *)fadeInWithDuration:(NSTimeInterval)sec;
+ (SCNAction *)fadeOutWithDuration:(NSTimeInterval)sec;
+ (SCNAction *)fadeOpacityBy:(CGFloat)factor duration:(NSTimeInterval)sec;
+ (SCNAction *)fadeOpacityTo:(CGFloat)opacity duration:(NSTimeInterval)sec;
+ (SCNAction *)hide;
+ (SCNAction *)unhide;
+ (SCNAction *)waitForDuration:(NSTimeInterval)sec;
+ (SCNAction *)waitForDuration:(NSTimeInterval)sec withRange:(NSTimeInterval)durationRange;
+ (SCNAction *)removeFromParentNode;
+ (SCNAction *)runBlock:(void (^)(SCNNode *node))block;
+ (SCNAction *)customActionWithDuration:(NSTimeInterval)seconds actionBlock:(void (^)(SCNNode *node, CGFloat elapsedTime))block;
@end
NS_ASSUME_NONNULL_END
#endif
