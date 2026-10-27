#pragma once
#import <PencilKit/PKStrokePoint.h>
#import <PencilKit/PKFloatRange.h>
NS_ASSUME_NONNULL_BEGIN
/* a point of a Bézier path being converted to a stroke path (initWithBezierPath:creationDate:pointProvider:) */
NS_SWIFT_NAME(PKConvertedBezierPointReference) __attribute__((swift_bridge("PKStrokePath.ConvertedBezierPoint"))) API_AVAILABLE(ios(26.0))
@interface PKConvertedBezierPoint : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) NSInteger pointCount;
@property (nonatomic, readonly) CGPoint location;
@property (nonatomic, readonly) NSInteger bezierSegmentIndex;
@end

/* isim: the curve passes through the control points (a Catmull-Rom spline): parametric value i is control point i,
 * values between are interpolated along the curve (location) and linearly (size, opacity, force, angles, time) */
NS_SWIFT_NAME(PKStrokePathReference) __attribute__((swift_bridge("PKStrokePath"))) API_AVAILABLE(ios(14.0))
@interface PKStrokePath : NSObject <NSCopying>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithControlPoints:(NSArray<PKStrokePoint *> *)controlPoints creationDate:(NSDate *)creationDate NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithControlPoints:(NSArray<PKStrokePoint *> *)controlPoints creationDate:(NSDate *)creationDate strokePathID:(NSUUID *)strokePathID
    API_AVAILABLE(ios(26.0));
- (instancetype)initWithBezierPath:(CGPathRef)bezierPath creationDate:(NSDate *)creationDate
                     pointProvider:(PKStrokePoint *(NS_NOESCAPE ^)(PKConvertedBezierPoint *point))pointProvider API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSDate *creationDate;
@property (nonatomic, readonly) NSUUID *strokePathID API_AVAILABLE(ios(26.0));
/* the curve through the interpolated points */
@property (nonatomic, readonly) CGPathRef bezierRepresentation API_AVAILABLE(ios(26.0));
- (PKStrokePoint *)pointAtIndex:(NSUInteger)i;
- (PKStrokePoint *)objectAtIndexedSubscript:(NSUInteger)i;
- (CGPoint)interpolatedLocationAt:(CGFloat)parametricValue;
- (PKStrokePoint *)interpolatedPointAt:(CGFloat)parametricValue;
- (void)enumerateInterpolatedPointsInRange:(PKFloatRange *)range strideByDistance:(CGFloat)distance
                                usingBlock:(void (NS_NOESCAPE ^)(PKStrokePoint *point, BOOL *stop))block;
- (void)enumerateInterpolatedPointsInRange:(PKFloatRange *)range strideByTime:(NSTimeInterval)time
                                usingBlock:(void (NS_NOESCAPE ^)(PKStrokePoint *point, BOOL *stop))block;
- (void)enumerateInterpolatedPointsInRange:(PKFloatRange *)range strideByParametricStep:(CGFloat)step
                                usingBlock:(void (NS_NOESCAPE ^)(PKStrokePoint *point, BOOL *stop))block;
- (CGFloat)parametricValue:(CGFloat)parametricValue offsetByDistance:(CGFloat)distance;
- (CGFloat)parametricValue:(CGFloat)parametricValue offsetByTime:(NSTimeInterval)timeStep;
/* the part of the path between two parametric values */
- (PKStrokePath *)subpathWithRange:(PKFloatRange *)range NS_SWIFT_NAME(subpath(with:)) API_AVAILABLE(ios(14.0));
@end
NS_ASSUME_NONNULL_END
