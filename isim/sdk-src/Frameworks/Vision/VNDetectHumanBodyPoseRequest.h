#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNRecognizedPointsObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef VNRecognizedPointKey VNHumanBodyPoseObservationJointName NS_TYPED_ENUM;
typedef VNRecognizedPointGroupKey VNHumanBodyPoseObservationJointsGroupName NS_TYPED_ENUM;
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameNose API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftEye API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightEye API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftEar API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightEar API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftShoulder API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightShoulder API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameNeck API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftElbow API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightElbow API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftWrist API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightWrist API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftHip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightHip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRoot API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftKnee API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightKnee API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameLeftAnkle API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointName const VNHumanBodyPoseObservationJointNameRightAnkle API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameFace API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameTorso API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameLeftArm API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameRightArm API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameLeftLeg API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameRightLeg API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanBodyPoseObservationJointsGroupName const VNHumanBodyPoseObservationJointsGroupNameAll API_AVAILABLE(ios(14.0));
API_AVAILABLE(ios(14.0))
@interface VNHumanBodyPoseObservation : VNRecognizedPointsObservation
@property (readonly) NSArray<VNHumanBodyPoseObservationJointName> *availableJointNames;
@property (readonly) NSArray<VNHumanBodyPoseObservationJointsGroupName> *availableJointsGroupNames;
- (nullable VNRecognizedPoint *)recognizedPointForJointName:(VNHumanBodyPoseObservationJointName)jointName error:(NSError **)error;
- (nullable NSDictionary<VNHumanBodyPoseObservationJointName, VNRecognizedPoint *> *)recognizedPointsForJointsGroupName:(VNHumanBodyPoseObservationJointsGroupName)jointsGroupName error:(NSError **)error;
@end
/* isim: a MoveNet single-pose model on the host (ISIM_BODY_POSE_MODEL, ONNX Runtime); without it the request fails with VNErrorUnsupportedRequest */
API_AVAILABLE(ios(14.0))
@interface VNDetectHumanBodyPoseRequest : VNImageBasedRequest
- (nullable NSArray<VNHumanBodyPoseObservationJointName> *)supportedJointNamesAndReturnError:(NSError **)error;
- (nullable NSArray<VNHumanBodyPoseObservationJointsGroupName> *)supportedJointsGroupNamesAndReturnError:(NSError **)error;
@property (readonly, nonatomic, copy, nullable) NSArray<VNHumanBodyPoseObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
