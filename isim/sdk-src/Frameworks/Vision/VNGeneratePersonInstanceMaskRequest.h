#pragma once
#import <Vision/VNGenerateForegroundInstanceMaskRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: the person mask's separate regions (ISIM_PERSON_SEGMENTATION_MODEL) */
API_AVAILABLE(ios(17.0))
@interface VNGeneratePersonInstanceMaskRequest : VNImageBasedRequest
@property (readonly, copy, nullable) NSArray<VNInstanceMaskObservation *> *results;
@end
static const NSUInteger VNGeneratePersonInstanceMaskRequestRevision1 = 1;
NS_ASSUME_NONNULL_END
#endif
