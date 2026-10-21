#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNTypes.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim's CPU detector: quadrilaterals among the image's edges */
API_AVAILABLE(ios(11.0))
@interface VNDetectRectanglesRequest : VNImageBasedRequest
@property (readwrite, nonatomic, assign) VNAspectRatio minimumAspectRatio;
@property (readwrite, nonatomic, assign) VNAspectRatio maximumAspectRatio;
@property (readwrite, nonatomic, assign) VNDegrees quadratureTolerance;
@property (readwrite, nonatomic, assign) float minimumSize;
@property (readwrite, nonatomic, assign) VNConfidence minimumConfidence;
@property (readwrite, nonatomic, assign) NSUInteger maximumObservations;
@property (readonly, nonatomic, copy, nullable) NSArray<VNRectangleObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
