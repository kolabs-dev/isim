#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#import <Vision/VNCoreMLRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: a feature model on the host (ISIM_FEATUREPRINT_MODEL, ONNX Runtime), else isim's own print (a 16 x 16 grid of
   the image's colours and edges, 1,024 floats of unit length) */
API_AVAILABLE(ios(13.0))
@interface VNGenerateImageFeaturePrintRequest : VNImageBasedRequest
@property (readwrite, nonatomic) VNImageCropAndScaleOption imageCropAndScaleOption;
@property (readonly, nonatomic, copy, nullable) NSArray<VNFeaturePrintObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
