#pragma once
#import <Vision/VNDefines.h>
#import <CoreGraphics/CoreGraphics.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class VNRequest, VNObservation;
typedef void (^VNRequestCompletionHandler)(VNRequest *request, NSError * _Nullable error);
API_AVAILABLE(ios(11.0))
@interface VNRequest : NSObject
- (instancetype)init;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler NS_DESIGNATED_INITIALIZER;
@property (readwrite, nonatomic) BOOL preferBackgroundProcessing;
@property (readwrite, nonatomic) BOOL usesCPUOnly API_DEPRECATED("use setComputeDevice:forComputeStage:", ios(11.0, 17.0));
@property (readonly, nonatomic, copy, nullable) NSArray<VNObservation *> *results;
@property (readonly, nonatomic, copy, nullable) VNRequestCompletionHandler completionHandler;
@property (readwrite, nonatomic, assign) NSUInteger revision;
@property (class, readonly, nonatomic, copy) NSIndexSet *supportedRevisions;
@property (class, readonly, nonatomic) NSUInteger defaultRevision;
@property (class, readonly, nonatomic) NSUInteger currentRevision;
- (void)cancel;
@end
API_AVAILABLE(ios(11.0))
@interface VNImageBasedRequest : VNRequest
/* normalized, lower-left origin; results are relative to it */
@property (readwrite, nonatomic, assign) CGRect regionOfInterest;
@end
NS_ASSUME_NONNULL_END
#endif
