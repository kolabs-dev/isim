#pragma once
#import <Vision/VNRequest.h>
#import <CoreMedia/CMTime.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: a request that keeps state between the frames a VNSequenceRequestHandler is given (in the request: perform it
   with one handler); every frame is analysed, whatever the spacing */
API_AVAILABLE(ios(14.0))
@interface VNStatefulRequest : VNImageBasedRequest
- (instancetype)initWithFrameAnalysisSpacing:(CMTime)frameAnalysisSpacing completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly) NSInteger minimumLatencyFrameCount;
@property (readonly) CMTime frameAnalysisSpacing;
@end
NS_ASSUME_NONNULL_END
#endif
