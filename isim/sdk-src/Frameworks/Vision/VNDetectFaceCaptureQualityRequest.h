#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: fails with VNErrorUnsupportedRequest (it needs Apple's models) */
API_AVAILABLE(ios(13.0))
@interface VNDetectFaceCaptureQualityRequest : VNImageBasedRequest
@property (readwrite, nonatomic, copy, nullable) NSArray<VNFaceObservation *> *inputFaceObservations;
@property (readonly, nonatomic, copy, nullable) NSArray<VNFaceObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
