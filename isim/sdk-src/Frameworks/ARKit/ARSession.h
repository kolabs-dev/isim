#pragma once
/* isim ARKit: ARSession. Running a configuration fails with ARErrorCodeUnsupportedConfiguration (the delegate's and the
 * session's views' session:didFailWithError:), as in Apple's Simulator, and no frames arrive. */
#import <ARKit/ARConfiguration.h>
#import <ARKit/ARFrame.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class ARSession;
typedef NS_OPTIONS(NSUInteger, ARSessionRunOptions) {
    ARSessionRunOptionResetTracking = 1 << 0, ARSessionRunOptionRemoveExistingAnchors = 1 << 1,
    ARSessionRunOptionStopTrackedRaycasts = 1 << 2, ARSessionRunOptionResetSceneReconstruction = 1 << 3
};
@protocol ARSessionObserver <NSObject>
@optional
- (void)session:(ARSession *)session didFailWithError:(NSError *)error;
- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera;
- (void)sessionWasInterrupted:(ARSession *)session;
- (void)sessionInterruptionEnded:(ARSession *)session;
- (BOOL)sessionShouldAttemptRelocalization:(ARSession *)session;
@end
@protocol ARSessionDelegate <ARSessionObserver>
@optional
- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame;
- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor *> *)anchors;
- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor *> *)anchors;
- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<__kindof ARAnchor *> *)anchors;
@end
@protocol ARSessionProviding <NSObject>
@property (nonatomic, readonly) ARSession *session;
@end
@interface ARSession : NSObject
@property (nonatomic, readonly) NSUUID *identifier;
@property (nonatomic, weak, nullable) id<ARSessionDelegate> delegate;
@property (nonatomic, readonly, nullable) ARFrame *currentFrame;
@property (nonatomic, readonly, nullable) ARConfiguration *configuration;
- (void)runWithConfiguration:(ARConfiguration *)configuration;
- (void)runWithConfiguration:(ARConfiguration *)configuration options:(ARSessionRunOptions)options;
- (void)pause;
- (void)addAnchor:(ARAnchor *)anchor;
- (void)removeAnchor:(ARAnchor *)anchor;
- (void)setWorldOrigin:(simd_float4x4)relativeTransform;
- (void)getCurrentWorldMapWithCompletionHandler:(void (^)(ARWorldMap * _Nullable worldMap, NSError * _Nullable error))completionHandler;
- (void)createReferenceObjectWithTransform:(simd_float4x4)transform center:(simd_float3)center extent:(simd_float3)extent
                         completionHandler:(void (^)(ARReferenceObject * _Nullable referenceObject, NSError * _Nullable error))completionHandler;
- (void)captureHighResolutionFrameWithCompletion:(void (^)(ARFrame * _Nullable frame, NSError * _Nullable error))completion;
- (NSArray<ARRaycastResult *> *)raycast:(ARRaycastQuery *)query;
- (nullable ARTrackedRaycast *)trackedRaycast:(ARRaycastQuery *)query updateHandler:(void (^)(NSArray<ARRaycastResult *> *results))updateHandler;
@end
NS_ASSUME_NONNULL_END
#endif
