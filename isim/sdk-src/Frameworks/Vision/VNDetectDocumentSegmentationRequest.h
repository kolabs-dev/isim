#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: the largest rectangle (VNDetectRectanglesRequest's detector) */
API_AVAILABLE(ios(15.0))
@interface VNDetectDocumentSegmentationRequest : VNImageBasedRequest
@property (readonly, copy, nullable) NSArray<VNRectangleObservation *> *results;
@end
static const NSUInteger VNDetectDocumentSegmentationRequestRevision1 = 1;
NS_ASSUME_NONNULL_END
#endif
