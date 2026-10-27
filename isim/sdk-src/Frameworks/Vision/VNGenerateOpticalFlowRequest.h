#pragma once
#import <Vision/VNTargetedImageRequest.h>
#import <Vision/VNStatefulRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, VNGenerateOpticalFlowRequestComputationAccuracy) {
    VNGenerateOpticalFlowRequestComputationAccuracyLow = 0,
    VNGenerateOpticalFlowRequestComputationAccuracyMedium,
    VNGenerateOpticalFlowRequestComputationAccuracyHigh,
    VNGenerateOpticalFlowRequestComputationAccuracyVeryHigh,
} API_AVAILABLE(ios(14.0));
/* isim: dense pyramidal Lucas–Kanade; each pixel is the motion (dx, dy) in pixels of the output, rows top first, y
   down, of the targeted image's content to the handler's image; the longer side is 160, 256, 384 or 512 pixels */
API_AVAILABLE(ios(14.0))
@interface VNGenerateOpticalFlowRequest : VNTargetedImageRequest
@property (readwrite, nonatomic, assign) VNGenerateOpticalFlowRequestComputationAccuracy computationAccuracy;
@property (readwrite, nonatomic) OSType outputPixelFormat;
@property (readwrite, nonatomic) BOOL keepNetworkOutput API_AVAILABLE(ios(16.0));
@property (readonly, nonatomic, copy, nullable) NSArray<VNPixelBufferObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
