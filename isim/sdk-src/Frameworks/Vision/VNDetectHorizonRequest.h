#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim's CPU detector: the strongest straight edge between sky and ground */
API_AVAILABLE(ios(11.0))
@interface VNDetectHorizonRequest : VNImageBasedRequest
@property (readonly, nonatomic, copy, nullable) NSArray<VNHorizonObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
