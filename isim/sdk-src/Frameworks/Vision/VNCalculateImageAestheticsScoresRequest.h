#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(18.0))
@interface VNImageAestheticsScoresObservation : VNObservation
@property (readonly) BOOL isUtility;
@property (readonly) float overallScore;
@end
/* isim: a score from sharpness, exposure and colour; utility images are mostly flat, light and grey */
API_AVAILABLE(ios(18.0))
@interface VNCalculateImageAestheticsScoresRequest : VNImageBasedRequest
@property (readonly, copy, nullable) NSArray<VNImageAestheticsScoresObservation *> *results;
@end
static const NSUInteger VNCalculateImageAestheticsScoresRequestRevision1 = 1;
NS_ASSUME_NONNULL_END
#endif
