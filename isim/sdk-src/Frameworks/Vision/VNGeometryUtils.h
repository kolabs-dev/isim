#pragma once
#import <Vision/VNGeometry.h>
#import <simd/simd.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class VNContour;
API_AVAILABLE(ios(14.0))
@interface VNCircle : NSObject <NSCopying, NSSecureCoding>
@property (class, nonatomic, readonly) VNCircle *zeroCircle;
- (instancetype)initWithCenter:(VNPoint *)center radius:(double)radius;
- (instancetype)initWithCenter:(VNPoint *)center diameter:(double)diameter;
- (BOOL)containsPoint:(VNPoint *)point;
- (BOOL)containsPoint:(VNPoint *)point inCircumferentialRingOfWidth:(double)ringWidth;
@property (readonly, nonatomic, strong) VNPoint *center;
@property (readonly, nonatomic) double radius;
@property (readonly, nonatomic) double diameter;
@end
/* isim: the smallest enclosing circle (Welzl), the shoelace area and the perimeter, in normalized coordinates */
API_AVAILABLE(ios(14.0))
@interface VNGeometryUtils : NSObject
+ (nullable VNCircle *)boundingCircleForContour:(VNContour *)contour error:(NSError **)error;
+ (nullable VNCircle *)boundingCircleForPoints:(NSArray<VNPoint *> *)points error:(NSError **)error;
+ (nullable VNCircle *)boundingCircleForSIMDPoints:(simd_float2 const *)points pointCount:(NSInteger)pointCount error:(NSError **)error;
+ (BOOL)calculateArea:(double *)area forContour:(VNContour *)contour orientedArea:(BOOL)orientedArea error:(NSError **)error;
+ (BOOL)calculatePerimeter:(double *)perimeter forContour:(VNContour *)contour error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
#endif
