#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, VNRequestTrackingLevel) {
    VNRequestTrackingLevelAccurate = 0,
    VNRequestTrackingLevelFast,
} API_AVAILABLE(ios(11.0));
/* isim: the object's patch in the previous frame found again by normalized cross-correlation (translation only); set
   inputObservation to the last result to go on, or to a new box to start again */
API_AVAILABLE(ios(11.0))
@interface VNTrackingRequest : VNImageBasedRequest
@property (readwrite, nonatomic, strong) VNDetectedObjectObservation *inputObservation;
@property (readwrite, nonatomic, assign) VNRequestTrackingLevel trackingLevel;
@property (readwrite, nonatomic, getter=isLastFrame) BOOL lastFrame;
- (NSUInteger)supportedNumberOfTrackersAndReturnError:(NSError **)error API_AVAILABLE(ios(17.0));
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
