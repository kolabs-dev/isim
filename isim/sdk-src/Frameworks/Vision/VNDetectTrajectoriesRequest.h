#pragma once
#import <Vision/VNStatefulRequest.h>
#import <Vision/VNObservation.h>
#import <Vision/VNGeometry.h>
#import <simd/simd.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: moving blobs found by differencing a sequence handler's frames, their centres fitted with a parabola */
API_AVAILABLE(ios(14.0))
@interface VNTrajectoryObservation : VNObservation
@property (readonly, copy) NSArray<VNPoint *> *detectedPoints;
@property (readonly, copy) NSArray<VNPoint *> *projectedPoints;
@property (readonly) simd_float3 equationCoefficients;
@property (readonly) CGFloat movingAverageRadius API_AVAILABLE(ios(15.0));
@end
API_AVAILABLE(ios(14.0))
@interface VNDetectTrajectoriesRequest : VNStatefulRequest
- (instancetype)initWithFrameAnalysisSpacing:(CMTime)frameAnalysisSpacing trajectoryLength:(NSInteger)trajectoryLength
                           completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@property (readonly) NSInteger trajectoryLength;
@property (readwrite) float objectMinimumNormalizedRadius;
@property (readwrite) float objectMaximumNormalizedRadius;
@property (readwrite) CMTime targetFrameTime API_AVAILABLE(ios(15.0));
@property (readonly, copy, nullable) NSArray<VNTrajectoryObservation *> *results;
@end
static const NSUInteger VNDetectTrajectoriesRequestRevision1 = 1;
NS_ASSUME_NONNULL_END
#endif
