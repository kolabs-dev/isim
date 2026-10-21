#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, VNRequestFaceLandmarksConstellation) {
    VNRequestFaceLandmarksConstellationNotDefined = 0, VNRequestFaceLandmarksConstellation65Points, VNRequestFaceLandmarksConstellation76Points,
} API_AVAILABLE(ios(13.0));
API_AVAILABLE(ios(11.0))
@interface VNDetectFaceLandmarksRequest : VNImageBasedRequest
+ (BOOL)revision:(NSUInteger)requestRevision supportsConstellation:(VNRequestFaceLandmarksConstellation)constellation API_AVAILABLE(ios(13.0));
@property (readwrite, nonatomic, assign) VNRequestFaceLandmarksConstellation constellation API_AVAILABLE(ios(13.0));
@property (readwrite, nonatomic, copy, nullable) NSArray<VNFaceObservation *> *inputFaceObservations;
@property (readonly, nonatomic, copy, nullable) NSArray<VNFaceObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
