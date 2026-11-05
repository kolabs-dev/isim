#pragma once
#import <Vision/VNStatefulRequest.h>
#import <Vision/VNRecognizedPointsObservation.h>
#import <simd/simd.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(17.0))
@interface VNPoint3D : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithPosition:(simd_float4x4)position;
@property (readonly) simd_float4x4 position;
@end
API_AVAILABLE(ios(17.0))
@interface VNRecognizedPoint3D : VNPoint3D
@property (readonly, copy) VNRecognizedPointKey identifier;
@end
typedef NSString *VNHumanBodyPose3DObservationJointName NS_TYPED_ENUM;
typedef NSString *VNHumanBodyPose3DObservationJointsGroupName NS_TYPED_ENUM;
API_AVAILABLE(ios(17.0))
@interface VNHumanBodyRecognizedPoint3D : VNRecognizedPoint3D
@property (readonly) simd_float4x4 localPosition;
@property (readonly, copy) VNHumanBodyPose3DObservationJointName parentJoint;
@end
API_AVAILABLE(ios(14.0))
@interface VNRecognizedPoints3DObservation : VNObservation
@property (readonly, copy) NSArray<VNRecognizedPointKey> *availableKeys;
@property (readonly, copy) NSArray<VNRecognizedPointGroupKey> *availableGroupKeys;
- (nullable VNRecognizedPoint3D *)recognizedPointForKey:(VNRecognizedPointKey)pointKey error:(NSError **)error;
- (nullable NSDictionary<VNRecognizedPointKey, VNRecognizedPoint3D *> *)recognizedPointsForGroupKey:(VNRecognizedPointGroupKey)groupKey error:(NSError **)error;
@end
typedef NS_ENUM(NSInteger, VNHumanBodyPose3DObservationHeightEstimation) {
    VNHumanBodyPose3DObservationHeightEstimationReference = 0,
    VNHumanBodyPose3DObservationHeightEstimationMeasured,
} API_AVAILABLE(ios(17.0));
/* isim: the 2D body pose (ISIM_BODY_POSE_MODEL) lifted onto a plane facing the camera, at the reference height 1.8 m */
API_AVAILABLE(ios(17.0))
@interface VNHumanBodyPose3DObservation : VNRecognizedPoints3DObservation
@property (readonly) VNHumanBodyPose3DObservationHeightEstimation heightEstimation;
@property (readonly) simd_float4x4 cameraOriginMatrix;
@property (readonly) float bodyHeight;
@property (readonly, copy) NSArray<VNHumanBodyPose3DObservationJointName> *availableJointNames;
@property (readonly, copy) NSArray<VNHumanBodyPose3DObservationJointsGroupName> *availableJointsGroupNames;
- (nullable NSDictionary<VNHumanBodyPose3DObservationJointName, VNHumanBodyRecognizedPoint3D *> *)recognizedPointsForJointsGroupName:(VNHumanBodyPose3DObservationJointsGroupName)jointsGroupName error:(NSError **)error;
- (nullable VNHumanBodyRecognizedPoint3D *)recognizedPointForJointName:(VNHumanBodyPose3DObservationJointName)jointName error:(NSError **)error;
- (nullable VNPoint *)pointInImageForJointName:(VNHumanBodyPose3DObservationJointName)jointName error:(NSError **)error;
- (nullable VNHumanBodyPose3DObservationJointName)parentJointNameForJointName:(VNHumanBodyPose3DObservationJointName)jointName;
- (BOOL)getCameraRelativePosition:(simd_float4x4 *)modelPositionOut forJointName:(VNHumanBodyPose3DObservationJointName)jointName error:(NSError **)error;
@end
API_AVAILABLE(ios(17.0))
@interface VNDetectHumanBodyPose3DRequest : VNStatefulRequest
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly, copy, nullable) NSArray<VNHumanBodyPose3DObservation *> *results;
@end
static const NSUInteger VNDetectHumanBodyPose3DRequestRevision1 = 1;
NS_ASSUME_NONNULL_END
#endif
