#pragma once
#import <Vision/VNTrackingRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(11.0))
@interface VNTrackObjectRequest : VNTrackingRequest
- (instancetype)initWithDetectedObjectObservation:(VNDetectedObjectObservation *)observation;
- (instancetype)initWithDetectedObjectObservation:(VNDetectedObjectObservation *)observation completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly, nonatomic, copy, nullable) NSArray<VNDetectedObjectObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
