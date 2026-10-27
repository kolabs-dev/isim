#pragma once
#import <Vision/VNStatefulRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, VNTrackOpticalFlowRequestComputationAccuracy) {
    VNTrackOpticalFlowRequestComputationAccuracyLow = 0,
    VNTrackOpticalFlowRequestComputationAccuracyMedium,
    VNTrackOpticalFlowRequestComputationAccuracyHigh,
    VNTrackOpticalFlowRequestComputationAccuracyVeryHigh,
} API_AVAILABLE(ios(17.0));
/* isim: the flow from the previous frame to this one (as VNGenerateOpticalFlowRequest); no result for the first frame */
API_AVAILABLE(ios(17.0))
@interface VNTrackOpticalFlowRequest : VNStatefulRequest
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readwrite, nonatomic, assign) VNTrackOpticalFlowRequestComputationAccuracy computationAccuracy;
@property (readwrite, nonatomic) OSType outputPixelFormat;
@property (readwrite, nonatomic) BOOL keepNetworkOutput;
@property (readonly, nonatomic, copy, nullable) NSArray<VNPixelBufferObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
