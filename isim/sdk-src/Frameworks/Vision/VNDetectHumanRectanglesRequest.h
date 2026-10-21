#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: fails with VNErrorUnsupportedRequest (no host detector) */
API_AVAILABLE(ios(13.0))
@interface VNDetectHumanRectanglesRequest : VNImageBasedRequest
@property (readwrite, nonatomic, assign) BOOL upperBodyOnly API_AVAILABLE(ios(15.0));
@property (readonly, nonatomic, copy, nullable) NSArray<VNHumanObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
