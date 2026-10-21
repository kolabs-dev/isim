#pragma once
#import <Vision/VNRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MLModel;
typedef NS_ENUM(NSUInteger, VNImageCropAndScaleOption) {
    VNImageCropAndScaleOptionCenterCrop = 0, VNImageCropAndScaleOptionScaleFit = 1, VNImageCropAndScaleOptionScaleFill = 2,
    VNImageCropAndScaleOptionScaleFitRotate90CCW = 0x100 + VNImageCropAndScaleOptionScaleFit,
    VNImageCropAndScaleOptionScaleFillRotate90CCW = 0x100 + VNImageCropAndScaleOptionScaleFill,
};
API_AVAILABLE(ios(11.0))
@interface VNCoreMLModel : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (nullable instancetype)modelForMLModel:(MLModel *)model error:(NSError **)error;
@property (readwrite, nonatomic, copy) NSString *inputImageFeatureName API_AVAILABLE(ios(13.0));
@end
/* isim: wraps the model, and fails with VNErrorUnsupportedRequest when performed (image models need Apple's runtime) */
API_AVAILABLE(ios(11.0))
@interface VNCoreMLRequest : VNImageBasedRequest
@property (readonly, nonatomic, nonnull) VNCoreMLModel *model;
@property (nonatomic) VNImageCropAndScaleOption imageCropAndScaleOption;
- (instancetype)initWithModel:(VNCoreMLModel *)model;
- (instancetype)initWithModel:(VNCoreMLModel *)model completionHandler:(nullable VNRequestCompletionHandler)completionHandler NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
