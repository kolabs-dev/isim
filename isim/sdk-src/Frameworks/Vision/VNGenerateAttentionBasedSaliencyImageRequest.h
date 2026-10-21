#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: frequency-tuned saliency with a centre prior (a 68x68 float map) */
API_AVAILABLE(ios(13.0))
@interface VNGenerateAttentionBasedSaliencyImageRequest : VNImageBasedRequest
@property (readonly, nonatomic, copy, nullable) NSArray<VNSaliencyImageObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
