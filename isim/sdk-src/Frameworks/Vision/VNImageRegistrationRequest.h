#pragma once
#import <Vision/VNTargetedImageRequest.h>
#import <Vision/VNStatefulRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: the targeted image is the floating image, the handler's the reference; the shift by sum-of-squared-differences
   search on an image pyramid, the homography refined from it by Gauss–Newton */
API_AVAILABLE(ios(11.0))
@interface VNImageRegistrationRequest : VNTargetedImageRequest
@end
API_AVAILABLE(ios(11.0))
@interface VNTranslationalImageRegistrationRequest : VNImageRegistrationRequest
@property (readonly, nonatomic, copy, nullable) NSArray<VNImageTranslationAlignmentObservation *> *results;
@end
API_AVAILABLE(ios(11.0))
@interface VNHomographicImageRegistrationRequest : VNImageRegistrationRequest
@property (readonly, nonatomic, copy, nullable) NSArray<VNImageHomographicAlignmentObservation *> *results;
@end
/* the previous frame aligned onto this one; no result for the first frame */
API_AVAILABLE(ios(17.0))
@interface VNTrackTranslationalImageRegistrationRequest : VNStatefulRequest
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly, nonatomic, copy, nullable) NSArray<VNImageTranslationAlignmentObservation *> *results;
@end
API_AVAILABLE(ios(17.0))
@interface VNTrackHomographicImageRegistrationRequest : VNStatefulRequest
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly, nonatomic, copy, nullable) NSArray<VNImageHomographicAlignmentObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
