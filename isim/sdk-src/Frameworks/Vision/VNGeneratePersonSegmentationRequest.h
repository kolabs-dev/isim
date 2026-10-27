#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, VNGeneratePersonSegmentationRequestQualityLevel) {
    VNGeneratePersonSegmentationRequestQualityLevelAccurate = 0,
    VNGeneratePersonSegmentationRequestQualityLevelBalanced,
    VNGeneratePersonSegmentationRequestQualityLevelFast,
} API_AVAILABLE(ios(15.0));
/* isim: a person segmentation model on the host (ISIM_PERSON_SEGMENTATION_MODEL, e.g. MediaPipe's selfie
   segmentation, ONNX Runtime); without it the request fails with VNErrorUnsupportedRequest */
API_AVAILABLE(ios(15.0))
@interface VNGeneratePersonSegmentationRequest : VNImageBasedRequest
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readwrite, nonatomic) VNGeneratePersonSegmentationRequestQualityLevel qualityLevel;
@property (readwrite, nonatomic) OSType outputPixelFormat;
- (nullable NSArray<NSNumber *> *)supportedOutputPixelFormatsAndReturnError:(NSError **)error;
@property (readonly, nonatomic, copy, nullable) NSArray<VNPixelBufferObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
