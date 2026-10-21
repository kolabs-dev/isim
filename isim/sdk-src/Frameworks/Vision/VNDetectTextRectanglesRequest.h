#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim's CPU detector: words and their characters, without reading them */
API_AVAILABLE(ios(11.0))
@interface VNDetectTextRectanglesRequest : VNImageBasedRequest
@property (readwrite, nonatomic, assign) BOOL reportCharacterBoxes;
@property (readonly, nonatomic, copy, nullable) NSArray<VNTextObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
