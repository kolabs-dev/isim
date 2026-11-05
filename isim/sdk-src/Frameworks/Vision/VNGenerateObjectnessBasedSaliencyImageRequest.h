#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: the same frequency-tuned map as VNGenerateAttentionBasedSaliencyImageRequest */
API_AVAILABLE(ios(13.0))
@interface VNGenerateObjectnessBasedSaliencyImageRequest : VNImageBasedRequest
@property (readonly, copy, nullable) NSArray<VNSaliencyImageObservation *> *results;
@end
static const NSUInteger VNGenerateObjectnessBasedSaliencyImageRequestRevision1 = 1;
static const NSUInteger VNGenerateObjectnessBasedSaliencyImageRequestRevision2 = 2;
NS_ASSUME_NONNULL_END
#endif
