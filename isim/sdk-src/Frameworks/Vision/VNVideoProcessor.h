#pragma once
#import <Vision/VNRequest.h>
#import <CoreMedia/CMTimeRange.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(14.0))
@interface VNVideoProcessorCadence : NSObject <NSCopying>
@end
API_AVAILABLE(ios(14.0))
@interface VNVideoProcessorFrameRateCadence : VNVideoProcessorCadence
- (instancetype)initWithFrameRate:(NSInteger)frameRate;
@property (readonly) NSInteger frameRate;
@end
API_AVAILABLE(ios(14.0))
@interface VNVideoProcessorTimeIntervalCadence : VNVideoProcessorCadence
- (instancetype)initWithTimeInterval:(CFTimeInterval)timeInterval;
@property (readonly) CFTimeInterval timeInterval;
@end
API_AVAILABLE(ios(14.0))
@interface VNVideoProcessorRequestProcessingOptions : NSObject <NSCopying>
@property (readwrite, strong, nullable) VNVideoProcessorCadence *cadence;
@end
/* isim: the video's frames (AVAssetImageGenerator) at each request's cadence, through one sequence handler */
API_AVAILABLE(ios(14.0))
@interface VNVideoProcessor : NSObject
- (instancetype)initWithURL:(NSURL *)videoURL;
- (BOOL)addRequest:(VNRequest *)request processingOptions:(VNVideoProcessorRequestProcessingOptions *)processingOptions error:(NSError **)error;
- (BOOL)removeRequest:(VNRequest *)request error:(NSError **)error;
- (BOOL)analyzeTimeRange:(CMTimeRange)timeRange error:(NSError **)error;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
#endif
