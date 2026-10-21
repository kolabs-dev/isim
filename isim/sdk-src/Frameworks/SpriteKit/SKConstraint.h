#pragma once
/* isim SpriteKit: constraints, ranges and inverse kinematics limits. */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SKRange : NSObject
- (instancetype)initWithLowerLimit:(CGFloat)lower upperLimit:(CGFloat)upper;
+ (instancetype)rangeWithLowerLimit:(CGFloat)lower upperLimit:(CGFloat)upper;
+ (instancetype)rangeWithLowerLimit:(CGFloat)lower;
+ (instancetype)rangeWithUpperLimit:(CGFloat)upper;
+ (instancetype)rangeWithConstantValue:(CGFloat)value;
+ (instancetype)rangeWithValue:(CGFloat)value variance:(CGFloat)variance;
+ (instancetype)rangeWithNoLimits;
@property (nonatomic) CGFloat lowerLimit;
@property (nonatomic) CGFloat upperLimit;
@end
@interface SKConstraint : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic, retain, nullable) SKNode *referenceNode;
+ (instancetype)positionX:(SKRange *)range;
+ (instancetype)positionY:(SKRange *)range;
+ (instancetype)positionX:(SKRange *)xRange Y:(SKRange *)yRange;
+ (instancetype)distance:(SKRange *)range toNode:(SKNode *)node;
+ (instancetype)distance:(SKRange *)range toPoint:(CGPoint)point;
+ (instancetype)distance:(SKRange *)range toPoint:(CGPoint)point inNode:(SKNode *)node;
+ (instancetype)zRotation:(SKRange *)zRange;
+ (instancetype)orientToNode:(SKNode *)node offset:(SKRange *)radians;
+ (instancetype)orientToPoint:(CGPoint)point offset:(SKRange *)radians;
+ (instancetype)orientToPoint:(CGPoint)point inNode:(SKNode *)node offset:(SKRange *)radians;
+ (instancetype)scaleX:(SKRange *)range;
+ (instancetype)scaleY:(SKRange *)range;
+ (instancetype)scaleX:(SKRange *)xRange scaleY:(SKRange *)yRange;
@end
@interface SKReachConstraints : NSObject
- (instancetype)initWithLowerAngleLimit:(CGFloat)lowerAngleLimit upperAngleLimit:(CGFloat)upperAngleLimit;
@property (nonatomic, assign) CGFloat lowerAngleLimit;
@property (nonatomic, assign) CGFloat upperAngleLimit;
@end
NS_ASSUME_NONNULL_END
#endif
