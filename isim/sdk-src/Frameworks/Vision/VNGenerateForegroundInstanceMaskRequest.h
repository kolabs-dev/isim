#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#import <Vision/VNRequestHandler.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(17.0))
@interface VNInstanceMaskObservation : VNObservation
@property (readonly) CVPixelBufferRef instanceMask;
@property (readonly, copy) NSIndexSet *allInstances;
- (nullable CVPixelBufferRef)generateMaskForInstances:(NSIndexSet *)instances error:(NSError **)error;
- (nullable CVPixelBufferRef)generateMaskedImageOfInstances:(NSIndexSet *)instances fromRequestHandler:(VNImageRequestHandler *)requestHandler
                                     croppedToInstancesExtent:(BOOL)cropResult error:(NSError **)error;
- (nullable CVPixelBufferRef)generateScaledMaskForImageForInstances:(NSIndexSet *)instances fromRequestHandler:(VNImageRequestHandler *)requestHandler
                                                              error:(NSError **)error;
@end
/* isim: the saliency map's salient regions as instances */
API_AVAILABLE(ios(17.0))
@interface VNGenerateForegroundInstanceMaskRequest : VNImageBasedRequest
@property (readonly, copy, nullable) NSArray<VNInstanceMaskObservation *> *results;
@end
static const NSUInteger VNGenerateForegroundInstanceMaskRequestRevision1 = 1;
NS_ASSUME_NONNULL_END
#endif
