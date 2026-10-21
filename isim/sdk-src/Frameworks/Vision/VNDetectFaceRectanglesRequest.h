#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* Core Image's face detector (the host's OpenCV Haar cascades) */
API_AVAILABLE(ios(11.0))
@interface VNDetectFaceRectanglesRequest : VNImageBasedRequest
@property (readonly, nonatomic, copy, nullable) NSArray<VNFaceObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
