#pragma once
/* isim SceneKit: the built-in shapes (issue #330), with Apple's dimensions, segment counts and elements. Chamfers and
 * corner radii are kept but not rounded. */
#import <SceneKit/SCNGeometry.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SCNPlane : SCNGeometry
+ (instancetype)planeWithWidth:(CGFloat)width height:(CGFloat)height;
@property (nonatomic) CGFloat width, height, cornerRadius;
@property (nonatomic) NSInteger widthSegmentCount, heightSegmentCount, cornerSegmentCount;
@end
@interface SCNBox : SCNGeometry
+ (instancetype)boxWithWidth:(CGFloat)width height:(CGFloat)height length:(CGFloat)length chamferRadius:(CGFloat)chamferRadius;
@property (nonatomic) CGFloat width, height, length, chamferRadius;
@property (nonatomic) NSInteger widthSegmentCount, heightSegmentCount, lengthSegmentCount, chamferSegmentCount;
@end
@interface SCNPyramid : SCNGeometry
+ (instancetype)pyramidWithWidth:(CGFloat)width height:(CGFloat)height length:(CGFloat)length;
@property (nonatomic) CGFloat width, height, length;
@property (nonatomic) NSInteger widthSegmentCount, heightSegmentCount, lengthSegmentCount;
@end
@interface SCNSphere : SCNGeometry
+ (instancetype)sphereWithRadius:(CGFloat)radius;
@property (nonatomic) CGFloat radius;
@property (nonatomic, getter=isGeodesic) BOOL geodesic;
@property (nonatomic) NSInteger segmentCount;
@end
@interface SCNCylinder : SCNGeometry
+ (instancetype)cylinderWithRadius:(CGFloat)radius height:(CGFloat)height;
@property (nonatomic) CGFloat radius, height;
@property (nonatomic) NSInteger radialSegmentCount, heightSegmentCount;
@end
@interface SCNCone : SCNGeometry
+ (instancetype)coneWithTopRadius:(CGFloat)topRadius bottomRadius:(CGFloat)bottomRadius height:(CGFloat)height;
@property (nonatomic) CGFloat topRadius, bottomRadius, height;
@property (nonatomic) NSInteger radialSegmentCount, heightSegmentCount;
@end
@interface SCNTube : SCNGeometry
+ (instancetype)tubeWithInnerRadius:(CGFloat)innerRadius outerRadius:(CGFloat)outerRadius height:(CGFloat)height;
@property (nonatomic) CGFloat innerRadius, outerRadius, height;
@property (nonatomic) NSInteger radialSegmentCount, heightSegmentCount;
@end
@interface SCNCapsule : SCNGeometry
+ (instancetype)capsuleWithCapRadius:(CGFloat)capRadius height:(CGFloat)height;
@property (nonatomic) CGFloat capRadius, height;
@property (nonatomic) NSInteger radialSegmentCount, heightSegmentCount, capSegmentCount;
@end
@interface SCNTorus : SCNGeometry
+ (instancetype)torusWithRingRadius:(CGFloat)ringRadius pipeRadius:(CGFloat)pipeRadius;
@property (nonatomic) CGFloat ringRadius, pipeRadius;
@property (nonatomic) NSInteger ringSegmentCount, pipeSegmentCount;
@end
@interface SCNFloor : SCNGeometry
+ (instancetype)floor;
@property (nonatomic) CGFloat reflectivity, reflectionFalloffStart, reflectionFalloffEnd, width, length;
@property (nonatomic) NSUInteger reflectionCategoryBitMask;
@end
NS_ASSUME_NONNULL_END
#endif
