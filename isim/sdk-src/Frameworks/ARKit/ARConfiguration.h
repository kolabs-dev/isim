#pragma once
/* isim ARKit: the configurations. None is supported (isSupported is NO), as in Apple's Simulator: no camera tracking. */
#import <ARKit/ARReferenceImage.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, ARWorldAlignment) { ARWorldAlignmentGravity = 0, ARWorldAlignmentGravityAndHeading = 1, ARWorldAlignmentCamera = 2 };
typedef NS_OPTIONS(NSUInteger, ARFrameSemantics) {
    ARFrameSemanticNone = 0, ARFrameSemanticPersonSegmentation = 1 << 0, ARFrameSemanticPersonSegmentationWithDepth = (1 << 0) | (1 << 1),
    ARFrameSemanticBodyDetection = 1 << 2, ARFrameSemanticSceneDepth = 1 << 3, ARFrameSemanticSmoothedSceneDepth = 1 << 4
};
typedef NS_OPTIONS(NSUInteger, ARSceneReconstruction) {
    ARSceneReconstructionNone = 0, ARSceneReconstructionMesh = 1 << 0, ARSceneReconstructionMeshWithClassification = (1 << 0) | (1 << 1)
};
typedef NS_OPTIONS(NSUInteger, ARPlaneDetection) { ARPlaneDetectionNone = 0, ARPlaneDetectionHorizontal = 1 << 0, ARPlaneDetectionVertical = 1 << 1 };
typedef NS_ENUM(NSInteger, AREnvironmentTexturing) {
    AREnvironmentTexturingNone = 0, AREnvironmentTexturingManual = 1, AREnvironmentTexturingAutomatic = 2
};
@interface ARVideoFormat : NSObject <NSCopying>
@property (nonatomic, readonly) CGSize imageResolution;
@property (nonatomic, readonly) NSInteger framesPerSecond;
@property (nonatomic, readonly, getter=isVideoHDRSupported) BOOL videoHDRSupported;
@property (nonatomic, readonly, getter=isRecommendedForHighResolutionFrameCapturing) BOOL recommendedForHighResolutionFrameCapturing;
@end
@interface ARConfiguration : NSObject <NSCopying>
@property (class, nonatomic, readonly) BOOL isSupported;
@property (class, nonatomic, readonly) NSArray<ARVideoFormat *> *supportedVideoFormats;
+ (BOOL)supportsFrameSemantics:(ARFrameSemantics)frameSemantics;
@property (class, nonatomic, readonly, nullable) ARVideoFormat *recommendedVideoFormatFor4KResolution;
@property (class, nonatomic, readonly, nullable) ARVideoFormat *recommendedVideoFormatForHighResolutionFrameCapturing;
@property (nonatomic, strong) ARVideoFormat *videoFormat;
@property (nonatomic) ARWorldAlignment worldAlignment;
@property (nonatomic, getter=isLightEstimationEnabled) BOOL lightEstimationEnabled;
@property (nonatomic) BOOL providesAudioData;
@property (nonatomic) ARFrameSemantics frameSemantics;
@property (nonatomic) BOOL videoHDRAllowed;
@end
@class ARWorldMap;
@interface ARWorldTrackingConfiguration : ARConfiguration
+ (BOOL)supportsSceneReconstruction:(ARSceneReconstruction)sceneReconstruction;
@property (class, nonatomic, readonly) BOOL supportsUserFaceTracking;
@property (class, nonatomic, readonly) BOOL supportsAppClipCodeTracking;
@property (nonatomic) ARPlaneDetection planeDetection;
@property (nonatomic, copy, null_resettable) NSSet<ARReferenceImage *> *detectionImages;
@property (nonatomic, copy) NSSet<ARReferenceObject *> *detectionObjects;
@property (nonatomic) NSInteger maximumNumberOfTrackedImages;
@property (nonatomic) BOOL automaticImageScaleEstimationEnabled;
@property (nonatomic) AREnvironmentTexturing environmentTexturing;
@property (nonatomic) BOOL wantsHDREnvironmentTextures;
@property (nonatomic) ARSceneReconstruction sceneReconstruction;
@property (nonatomic, getter=isAutoFocusEnabled) BOOL autoFocusEnabled;
@property (nonatomic, getter=isCollaborationEnabled) BOOL collaborationEnabled;
@property (nonatomic, getter=userFaceTrackingEnabled) BOOL userFaceTrackingEnabled;
@property (nonatomic, getter=appClipCodeTrackingEnabled) BOOL appClipCodeTrackingEnabled;
@property (nonatomic, strong, nullable) ARWorldMap *initialWorldMap;
@end
@interface AROrientationTrackingConfiguration : ARConfiguration
@property (nonatomic, getter=isAutoFocusEnabled) BOOL autoFocusEnabled;
@end
@interface ARFaceTrackingConfiguration : ARConfiguration
@property (class, nonatomic, readonly) NSInteger supportedNumberOfTrackedFaces;
@property (class, nonatomic, readonly) BOOL supportsWorldTracking;
@property (nonatomic) NSInteger maximumNumberOfTrackedFaces;
@property (nonatomic, getter=isWorldTrackingEnabled) BOOL worldTrackingEnabled;
@end
@interface ARImageTrackingConfiguration : ARConfiguration
@property (nonatomic, copy) NSSet<ARReferenceImage *> *trackingImages;
@property (nonatomic) NSInteger maximumNumberOfTrackedImages;
@property (nonatomic, getter=isAutoFocusEnabled) BOOL autoFocusEnabled;
@end
@interface ARObjectScanningConfiguration : ARConfiguration
@property (nonatomic, getter=isAutoFocusEnabled) BOOL autoFocusEnabled;
@end
@interface ARBodyTrackingConfiguration : ARConfiguration
@property (nonatomic, copy, null_resettable) NSSet<ARReferenceImage *> *detectionImages;
@property (nonatomic) NSInteger maximumNumberOfTrackedImages;
@property (nonatomic) BOOL automaticSkeletonScaleEstimationEnabled;
@property (nonatomic, getter=isAutoFocusEnabled) BOOL autoFocusEnabled;
@property (nonatomic, strong, nullable) ARWorldMap *initialWorldMap;
@end
@interface ARPositionalTrackingConfiguration : ARConfiguration
@property (nonatomic, strong, nullable) ARWorldMap *initialWorldMap;
@end
@interface ARGeoTrackingConfiguration : ARConfiguration
+ (void)checkAvailabilityWithCompletionHandler:(void (^)(BOOL isAvailable, NSError * _Nullable error))completionHandler;
@property (nonatomic) NSInteger maximumNumberOfTrackedImages;
@end
NS_ASSUME_NONNULL_END
#endif
