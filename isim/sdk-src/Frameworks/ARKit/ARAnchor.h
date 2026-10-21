#pragma once
/* isim ARKit: anchors (they hold their data; no tracking produces them on isim, as in the Simulator). */
#import <ARKit/ARReferenceImage.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol ARAnchorCopying <NSCopying>
- (instancetype)initWithAnchor:(ARAnchor *)anchor;
@end
@protocol ARTrackable <NSObject>
@property (nonatomic, readonly) BOOL isTracked;
@end
@interface ARAnchor : NSObject <ARAnchorCopying, NSSecureCoding>
@property (nonatomic, readonly) NSUUID *identifier;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nullable) NSUUID *sessionIdentifier;
@property (nonatomic, readonly) simd_float4x4 transform;
- (instancetype)initWithTransform:(simd_float4x4)transform;
- (instancetype)initWithName:(NSString *)name transform:(simd_float4x4)transform;
- (instancetype)init NS_UNAVAILABLE;
@end
typedef NS_ENUM(NSInteger, ARPlaneAnchorAlignment) { ARPlaneAnchorAlignmentHorizontal = 0, ARPlaneAnchorAlignmentVertical = 1 };
typedef NS_ENUM(NSInteger, ARPlaneClassification) {
    ARPlaneClassificationNone = 0, ARPlaneClassificationWall, ARPlaneClassificationFloor, ARPlaneClassificationCeiling, ARPlaneClassificationTable,
    ARPlaneClassificationSeat, ARPlaneClassificationWindow, ARPlaneClassificationDoor
};
@interface ARPlaneExtent : NSObject <NSSecureCoding>
@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) float height;
@property (nonatomic, readonly) float rotationOnYAxis;
@end
@interface ARPlaneGeometry : NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSUInteger vertexCount;
@property (nonatomic, readonly) NSUInteger triangleCount;
@end
@interface ARPlaneAnchor : ARAnchor
@property (class, nonatomic, readonly, getter=isClassificationSupported) BOOL classificationSupported;
@property (nonatomic, readonly) ARPlaneAnchorAlignment alignment;
@property (nonatomic, readonly) simd_float3 center;
@property (nonatomic, readonly) ARPlaneExtent *planeExtent;
@property (nonatomic, readonly) ARPlaneGeometry *geometry;
@property (nonatomic, readonly) ARPlaneClassification classification;
@end
@interface ARImageAnchor : ARAnchor <ARTrackable>
@property (nonatomic, readonly) ARReferenceImage *referenceImage;
@property (nonatomic, readonly) CGFloat estimatedScaleFactor;
@end
@class ARReferenceObject;
@interface ARObjectAnchor : ARAnchor
@property (nonatomic, readonly) ARReferenceObject *referenceObject;
@end
typedef NSString *ARBlendShapeLocation NS_TYPED_ENUM;
@interface ARFaceAnchor : ARAnchor <ARTrackable>
@property (nonatomic, readonly) NSDictionary<ARBlendShapeLocation, NSNumber *> *blendShapes;
@property (nonatomic, readonly) simd_float4x4 leftEyeTransform;
@property (nonatomic, readonly) simd_float4x4 rightEyeTransform;
@property (nonatomic, readonly) simd_float3 lookAtPoint;
@end
@interface AREnvironmentProbeAnchor : ARAnchor
- (instancetype)initWithTransform:(simd_float4x4)transform extent:(simd_float3)extent;
- (instancetype)initWithName:(NSString *)name transform:(simd_float4x4)transform extent:(simd_float3)extent;
@property (nonatomic, readonly) simd_float3 extent;
@property (nonatomic, readonly, nullable) id environmentTexture;
@end
NS_ASSUME_NONNULL_END
#endif
