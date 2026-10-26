#pragma once
/* isim SceneKit: the renderer protocol (SCNView and SCNRenderer adopt it) and the renderer delegate. */
#import <SceneKit/SCNScene.h>
#import <SceneKit/SCNHitTest.h>
#import <Metal/Metal.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, SCNAntialiasingMode) {
    SCNAntialiasingModeNone = 0, SCNAntialiasingModeMultisampling2X = 1, SCNAntialiasingModeMultisampling4X = 2
};
@protocol SCNSceneRendererDelegate;
@protocol SCNSceneRenderer <NSObject>
@property (nonatomic, retain, nullable) SCNScene *scene;
@property (nonatomic) NSTimeInterval sceneTime;
@property (nonatomic, weak, nullable) id<SCNSceneRendererDelegate> delegate;
@property (nonatomic, getter=isPlaying) BOOL playing;
@property (nonatomic) BOOL loops;
@property (nonatomic, retain, nullable) SCNNode *pointOfView;
@property (nonatomic) BOOL autoenablesDefaultLighting;
@property (nonatomic, getter=isJitteringEnabled) BOOL jitteringEnabled;
@property (nonatomic) BOOL showsStatistics;
- (BOOL)isNodeInsideFrustum:(SCNNode *)node withPointOfView:(SCNNode *)pointOfView;
- (NSArray<SCNNode *> *)nodesInsideFrustumWithPointOfView:(SCNNode *)pointOfView;
- (SCNVector3)projectPoint:(SCNVector3)point;
- (SCNVector3)unprojectPoint:(SCNVector3)point;
- (NSArray<SCNHitTestResult *> *)hitTest:(CGPoint)point options:(nullable NSDictionary<SCNHitTestOption, id> *)options;
@property (nonatomic, readonly, nullable) id<MTLDevice> device;
@property (nonatomic, readonly, nullable) id<MTLCommandQueue> commandQueue;
@property (nonatomic, readonly, nullable) id<MTLRenderCommandEncoder> currentRenderCommandEncoder;
@property (nonatomic, readonly) MTLRenderPassDescriptor *currentRenderPassDescriptor;
@property (nonatomic, readonly) CGRect currentViewport;
@property (nonatomic) NSTimeInterval currentTime;
@end
@protocol SCNSceneRendererDelegate <NSObject>
@optional
- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time;
- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyAnimationsAtTime:(NSTimeInterval)time;
- (void)renderer:(id<SCNSceneRenderer>)renderer didSimulatePhysicsAtTime:(NSTimeInterval)time;
- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval)time;
- (void)renderer:(id<SCNSceneRenderer>)renderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
- (void)renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
@end
NS_ASSUME_NONNULL_END
#endif
