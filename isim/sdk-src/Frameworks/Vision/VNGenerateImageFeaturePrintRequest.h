#pragma once
#import <Vision/VNRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: fails with VNErrorUnsupportedRequest (it needs Apple's models) */
API_AVAILABLE(ios(13.0))
@interface VNGenerateImageFeaturePrintRequest : VNImageBasedRequest
@end
NS_ASSUME_NONNULL_END
#endif
