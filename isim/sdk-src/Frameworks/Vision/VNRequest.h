#pragma once
#import <Vision/VNDefines.h>
#import <CoreGraphics/CoreGraphics.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class VNRequest, VNObservation;
typedef void (^VNRequestCompletionHandler)(VNRequest *request, NSError * _Nullable error);
API_AVAILABLE(ios(11.0))
@interface VNRequest : NSObject
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler NS_DESIGNATED_INITIALIZER;
@property (readwrite, nonatomic) BOOL preferBackgroundProcessing;
@property (readwrite, nonatomic) BOOL usesCPUOnly API_DEPRECATED("use setComputeDevice:forComputeStage:", ios(11.0, 17.0));
@property (readonly, nonatomic, copy, nullable) NSArray<VNObservation *> *results;
@property (readonly, nonatomic, copy, nullable) VNRequestCompletionHandler completionHandler;
@property (readwrite, nonatomic, assign) NSUInteger revision;
@property (class, readonly, nonatomic, copy) NSIndexSet *supportedRevisions;
@property (class, readonly, nonatomic) NSUInteger defaultRevision;
@property (class, readonly, nonatomic) NSUInteger currentRevision;
- (void)cancel;
@end
/* the stages of a request's work, for choosing a compute device (isim runs every request on the CPU) */
typedef NSString *VNComputeStage NS_TYPED_ENUM;
VN_EXPORT VNComputeStage const VNComputeStageMain API_AVAILABLE(ios(17.0));
VN_EXPORT VNComputeStage const VNComputeStagePostProcessing API_AVAILABLE(ios(17.0));
typedef void (^VNRequestProgressHandler)(VNRequest *request, double fractionCompleted, NSError * _Nullable error);
API_AVAILABLE(ios(13.0))
@protocol VNRequestProgressProviding <NSObject>
@property (readwrite, nonatomic, copy) VNRequestProgressHandler progressHandler;
@property (readonly, nonatomic) BOOL indeterminate;
@end
API_AVAILABLE(ios(12.0))
@protocol VNRequestRevisionProviding
@property (readonly, nonatomic, assign) NSUInteger requestRevision;
@end
static const NSUInteger VNRequestRevisionUnspecified = 0;
static const NSUInteger VNClassifyImageRequestRevision1 = 1;
static const NSUInteger VNClassifyImageRequestRevision2 = 2;
static const NSUInteger VNCoreMLRequestRevision1 = 1;
static const NSUInteger VNDetectAnimalBodyPoseRequestRevision1 = 1;
static const NSUInteger VNDetectBarcodesRequestRevision2 = 2;
static const NSUInteger VNDetectBarcodesRequestRevision3 = 3;
static const NSUInteger VNDetectBarcodesRequestRevision4 = 4;
static const NSUInteger VNDetectContourRequestRevision1 = 1;
static const NSUInteger VNDetectFaceCaptureQualityRequestRevision1 = 1;
static const NSUInteger VNDetectFaceCaptureQualityRequestRevision2 = 2;
static const NSUInteger VNDetectFaceCaptureQualityRequestRevision3 = 3;
static const NSUInteger VNDetectFaceLandmarksRequestRevision2 = 2;
static const NSUInteger VNDetectFaceLandmarksRequestRevision3 = 3;
static const NSUInteger VNDetectFaceRectanglesRequestRevision2 = 2;
static const NSUInteger VNDetectFaceRectanglesRequestRevision3 = 3;
static const NSUInteger VNDetectHorizonRequestRevision1 = 1;
static const NSUInteger VNDetectHumanBodyPoseRequestRevision1 = 1;
static const NSUInteger VNDetectHumanHandPoseRequestRevision1 = 1;
static const NSUInteger VNDetectHumanRectanglesRequestRevision1 = 1;
static const NSUInteger VNDetectHumanRectanglesRequestRevision2 = 2;
static const NSUInteger VNDetectRectanglesRequestRevision1 = 1;
static const NSUInteger VNDetectTextRectanglesRequestRevision1 = 1;
static const NSUInteger VNGenerateAttentionBasedSaliencyImageRequestRevision1 = 1;
static const NSUInteger VNGenerateAttentionBasedSaliencyImageRequestRevision2 = 2;
static const NSUInteger VNGenerateImageFeaturePrintRequestRevision1 = 1;
static const NSUInteger VNGenerateImageFeaturePrintRequestRevision2 = 2;
static const NSUInteger VNGenerateOpticalFlowRequestRevision1 = 1;
static const NSUInteger VNGenerateOpticalFlowRequestRevision2 = 2;
static const NSUInteger VNGeneratePersonSegmentationRequestRevision1 = 1;
static const NSUInteger VNHomographicImageRegistrationRequestRevision1 = 1;
static const NSUInteger VNRecognizeTextRequestRevision1 = 1;
static const NSUInteger VNRecognizeTextRequestRevision2 = 2;
static const NSUInteger VNRecognizeTextRequestRevision3 = 3;
static const NSUInteger VNTrackHomographicImageRegistrationRequestRevision1 = 1;
static const NSUInteger VNTrackObjectRequestRevision1 = 1;
static const NSUInteger VNTrackObjectRequestRevision2 = 2;
static const NSUInteger VNTrackOpticalFlowRequestRevision1 = 1;
static const NSUInteger VNTrackRectangleRequestRevision1 = 1;
static const NSUInteger VNTrackTranslationalImageRegistrationRequestRevision1 = 1;
static const NSUInteger VNTranslationalImageRegistrationRequestRevision1 = 1;
API_AVAILABLE(ios(11.0))
@interface VNImageBasedRequest : VNRequest
/* normalized, lower-left origin; results are relative to it */
@property (readwrite, nonatomic, assign) CGRect regionOfInterest;
@end
NS_ASSUME_NONNULL_END
#endif
