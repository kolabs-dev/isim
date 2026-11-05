#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NSString *VNAnimalIdentifier NS_TYPED_ENUM;
VN_EXPORT VNAnimalIdentifier const VNAnimalIdentifierDog API_AVAILABLE(ios(13.0));
VN_EXPORT VNAnimalIdentifier const VNAnimalIdentifierCat API_AVAILABLE(ios(13.0));
API_AVAILABLE(ios(12.0))
@interface VNRecognizedObjectObservation : VNDetectedObjectObservation
@property (readonly, copy) NSArray<VNClassificationObservation *> *labels;
@end
/* isim: the image classifier (ISIM_CLASSIFY_MODEL and ISIM_CLASSIFY_LABELS) whose labels name a cat or a dog breed */
API_AVAILABLE(ios(13.0))
@interface VNRecognizeAnimalsRequest : VNImageBasedRequest
- (nullable NSArray<VNAnimalIdentifier> *)supportedIdentifiersAndReturnError:(NSError **)error API_AVAILABLE(ios(15.0));
@property (readonly, copy, nullable) NSArray<VNRecognizedObjectObservation *> *results;
@end
static const NSUInteger VNRecognizeAnimalsRequestRevision1 = 1;
static const NSUInteger VNRecognizeAnimalsRequestRevision2 = 2;
NS_ASSUME_NONNULL_END
#endif
