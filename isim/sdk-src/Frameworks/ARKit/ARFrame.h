#pragma once
/* isim ARKit: frames, cameras, light estimates and raycasts. isim's sessions produce no frames (no camera tracking). */
#import <ARKit/ARAnchor.h>
#import <CoreVideo/CoreVideo.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, ARTrackingState) { ARTrackingStateNotAvailable = 0, ARTrackingStateLimited, ARTrackingStateNormal };
typedef NS_ENUM(NSInteger, ARTrackingStateReason) {
    ARTrackingStateReasonNone = 0, ARTrackingStateReasonInitializing, ARTrackingStateReasonExcessiveMotion, ARTrackingStateReasonInsufficientFeatures,
    ARTrackingStateReasonRelocalizing
};
typedef NS_ENUM(NSInteger, ARWorldMappingStatus) {
    ARWorldMappingStatusNotAvailable = 0, ARWorldMappingStatusLimited, ARWorldMappingStatusExtending, ARWorldMappingStatusMapped
};
typedef NS_ENUM(NSInteger, ARRaycastTarget) {
    ARRaycastTargetExistingPlaneGeometry = 0, ARRaycastTargetExistingPlaneInfinite = 1, ARRaycastTargetEstimatedPlane = 2
};
typedef NS_ENUM(NSInteger, ARRaycastTargetAlignment) {
    ARRaycastTargetAlignmentHorizontal = 0, ARRaycastTargetAlignmentVertical = 1, ARRaycastTargetAlignmentAny = 2
};
@interface ARCamera : NSObject <NSCopying>
@property (nonatomic, readonly) simd_float4x4 transform;
@property (nonatomic, readonly) simd_float3 eulerAngles;
@property (nonatomic, readonly) ARTrackingState trackingState;
@property (nonatomic, readonly) ARTrackingStateReason trackingStateReason;
@property (nonatomic, readonly) simd_float3x3 intrinsics;
@property (nonatomic, readonly) CGSize imageResolution;
@property (nonatomic, readonly) NSTimeInterval exposureDuration;
@property (nonatomic, readonly) float exposureOffset;
@property (nonatomic, readonly) simd_float4x4 projectionMatrix;
- (CGPoint)projectPoint:(simd_float3)point orientation:(UIInterfaceOrientation)orientation viewportSize:(CGSize)viewportSize;
- (simd_float4x4)projectionMatrixForOrientation:(UIInterfaceOrientation)orientation viewportSize:(CGSize)viewportSize zNear:(CGFloat)zNear zFar:(CGFloat)zFar;
- (simd_float4x4)viewMatrixForOrientation:(UIInterfaceOrientation)orientation;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface ARLightEstimate : NSObject
@property (nonatomic, readonly) CGFloat ambientIntensity;
@property (nonatomic, readonly) CGFloat ambientColorTemperature;
@end
@interface ARRaycastQuery : NSObject
- (instancetype)initWithOrigin:(simd_float3)origin direction:(simd_float3)direction allowingTarget:(ARRaycastTarget)target
                     alignment:(ARRaycastTargetAlignment)alignment;
@property (nonatomic, readonly) simd_float3 origin;
@property (nonatomic, readonly) simd_float3 direction;
@property (nonatomic, readonly) ARRaycastTarget target;
@property (nonatomic, readonly) ARRaycastTargetAlignment targetAlignment;
@end
@interface ARRaycastResult : NSObject
@property (nonatomic, readonly) simd_float4x4 worldTransform;
@property (nonatomic, readonly) ARRaycastTarget target;
@property (nonatomic, readonly) ARRaycastTargetAlignment targetAlignment;
@property (nonatomic, readonly, nullable) ARAnchor *anchor;
@end
@interface ARTrackedRaycast : NSObject
- (void)stopTracking;
@end
@interface ARFrame : NSObject <NSCopying>
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) CVPixelBufferRef capturedImage;
@property (nonatomic, readonly) ARCamera *camera;
@property (nonatomic, readonly) NSArray<ARAnchor *> *anchors;
@property (nonatomic, readonly, nullable) ARLightEstimate *lightEstimate;
@property (nonatomic, readonly, nullable) ARPointCloud *rawFeaturePoints;
@property (nonatomic, readonly) ARWorldMappingStatus worldMappingStatus;
@property (nonatomic, readonly) float cameraGrainIntensity;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *exifData;
- (ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point allowingTarget:(ARRaycastTarget)target alignment:(ARRaycastTargetAlignment)alignment;
- (CGAffineTransform)displayTransformForOrientation:(UIInterfaceOrientation)orientation viewportSize:(CGSize)viewportSize;
@end
NS_ASSUME_NONNULL_END
#endif
