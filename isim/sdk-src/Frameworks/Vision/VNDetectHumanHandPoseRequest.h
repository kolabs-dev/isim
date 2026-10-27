#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNRecognizedPointsObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef VNRecognizedPointKey VNHumanHandPoseObservationJointName NS_TYPED_ENUM;
typedef VNRecognizedPointGroupKey VNHumanHandPoseObservationJointsGroupName NS_TYPED_ENUM;
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameWrist API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameThumbCMC API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameThumbMP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameThumbIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameThumbTip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameIndexMCP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameIndexPIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameIndexDIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameIndexTip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameMiddleMCP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameMiddlePIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameMiddleDIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameMiddleTip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameRingMCP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameRingPIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameRingDIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameRingTip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameLittleMCP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameLittlePIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameLittleDIP API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointName const VNHumanHandPoseObservationJointNameLittleTip API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointsGroupName const VNHumanHandPoseObservationJointsGroupNameThumb API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointsGroupName const VNHumanHandPoseObservationJointsGroupNameIndexFinger API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointsGroupName const VNHumanHandPoseObservationJointsGroupNameMiddleFinger API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointsGroupName const VNHumanHandPoseObservationJointsGroupNameRingFinger API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointsGroupName const VNHumanHandPoseObservationJointsGroupNameLittleFinger API_AVAILABLE(ios(14.0));
VN_EXPORT VNHumanHandPoseObservationJointsGroupName const VNHumanHandPoseObservationJointsGroupNameAll API_AVAILABLE(ios(14.0));
API_AVAILABLE(ios(14.0))
@interface VNHumanHandPoseObservation : VNRecognizedPointsObservation
@property (readonly) NSArray<VNHumanHandPoseObservationJointName> *availableJointNames;
@property (readonly) NSArray<VNHumanHandPoseObservationJointsGroupName> *availableJointsGroupNames;
- (nullable VNRecognizedPoint *)recognizedPointForJointName:(VNHumanHandPoseObservationJointName)jointName error:(NSError **)error;
- (nullable NSDictionary<VNHumanHandPoseObservationJointName, VNRecognizedPoint *> *)recognizedPointsForJointsGroupName:(VNHumanHandPoseObservationJointsGroupName)jointsGroupName error:(NSError **)error;
@property (readonly) VNChirality chirality API_AVAILABLE(ios(15.0));
@end
/* isim: MediaPipe's hand landmark model on the host (ISIM_HAND_POSE_MODEL), one hand; without it the request fails with VNErrorUnsupportedRequest */
API_AVAILABLE(ios(14.0))
@interface VNDetectHumanHandPoseRequest : VNImageBasedRequest
@property (readwrite) NSUInteger maximumHandCount;
- (nullable NSArray<VNHumanHandPoseObservationJointName> *)supportedJointNamesAndReturnError:(NSError **)error;
- (nullable NSArray<VNHumanHandPoseObservationJointsGroupName> *)supportedJointsGroupNamesAndReturnError:(NSError **)error;
@property (readonly, nonatomic, copy, nullable) NSArray<VNHumanHandPoseObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
