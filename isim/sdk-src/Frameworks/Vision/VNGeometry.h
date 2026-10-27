#pragma once
#import <Vision/VNTypes.h>
#import <CoreGraphics/CoreGraphics.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class VNVector;
API_AVAILABLE(ios(14.0))
@interface VNPoint : NSObject <NSCopying, NSSecureCoding>
+ (VNPoint *)zeroPoint;
+ (instancetype)pointByApplyingVector:(VNVector *)vector toPoint:(VNPoint *)point;
+ (CGFloat)distanceBetweenPoint:(VNPoint *)point1 point:(VNPoint *)point2;
- (instancetype)initWithX:(double)x y:(double)y NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithLocation:(CGPoint)location;
- (double)distanceToPoint:(VNPoint *)point;
@property (readonly, nonatomic, assign) double x;
@property (readonly, nonatomic, assign) double y;
@property (readonly, nonatomic, assign) CGPoint location;
@end
API_AVAILABLE(ios(14.0))
@interface VNDetectedPoint : VNPoint
@property (readonly, nonatomic, assign) VNConfidence confidence;
@end
API_AVAILABLE(ios(14.0))
@interface VNVector : NSObject <NSCopying, NSSecureCoding>
+ (VNVector *)zeroVector;
+ (VNVector *)unitVectorForVector:(VNVector *)vector;
+ (VNVector *)vectorByMultiplyingVector:(VNVector *)vector byScalar:(double)scalar;
+ (VNVector *)vectorByAddingVector:(VNVector *)v1 toVector:(VNVector *)v2;
+ (VNVector *)vectorBySubtractingVector:(VNVector *)v1 fromVector:(VNVector *)v2;
+ (double)dotProductOfVector:(VNVector *)v1 vector:(VNVector *)v2;
- (instancetype)initWithXComponent:(double)x yComponent:(double)y NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithR:(double)r theta:(double)theta;
- (instancetype)initWithVectorHead:(VNPoint *)head tail:(VNPoint *)tail;
@property (readonly, nonatomic, assign) double x;
@property (readonly, nonatomic, assign) double y;
@property (readonly, nonatomic, assign) double r;
@property (readonly, nonatomic, assign) double theta;
@property (readonly, nonatomic, assign) double length;
@property (readonly, nonatomic, assign) double squaredLength;
@end
NS_ASSUME_NONNULL_END
#endif
