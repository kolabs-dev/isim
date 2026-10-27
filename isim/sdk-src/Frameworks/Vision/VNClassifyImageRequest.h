#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: a classifier on the host (ISIM_CLASSIFY_MODEL, ONNX Runtime) with its labels (ISIM_CLASSIFY_LABELS, one per
   line); without them the request fails with VNErrorUnsupportedRequest */
API_AVAILABLE(ios(13.0))
@interface VNClassifyImageRequest : VNImageBasedRequest
+ (nullable NSArray<VNClassificationObservation *> *)knownClassificationsForRevision:(NSUInteger)requestRevision error:(NSError **)error;
- (nullable NSArray<NSString *> *)supportedIdentifiersAndReturnError:(NSError **)error API_AVAILABLE(ios(17.0));
@property (readonly, nonatomic, copy, nullable) NSArray<VNClassificationObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
