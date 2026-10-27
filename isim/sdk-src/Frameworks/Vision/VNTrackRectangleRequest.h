#pragma once
#import <Vision/VNTrackingRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: the rectangle's corners move with its box */
API_AVAILABLE(ios(11.0))
@interface VNTrackRectangleRequest : VNTrackingRequest
- (instancetype)initWithRectangleObservation:(VNRectangleObservation *)observation;
- (instancetype)initWithRectangleObservation:(VNRectangleObservation *)observation completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly, nonatomic, copy, nullable) NSArray<VNRectangleObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
