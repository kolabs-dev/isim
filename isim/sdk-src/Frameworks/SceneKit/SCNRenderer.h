#pragma once
/* isim SceneKit: SCNRenderer (issue #330), drawing a scene into an app's Metal render pass or into an image, with
 * isim's Metal on the CPU. */
#import <SceneKit/SCNSceneRenderer.h>
#import <Metal/Metal.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SCNRenderer : NSObject <SCNSceneRenderer>
+ (instancetype)rendererWithDevice:(nullable id<MTLDevice>)device options:(nullable NSDictionary *)options;
@property (nonatomic, readonly) CFTimeInterval nextFrameTime;
- (void)updateAtTime:(CFTimeInterval)time;
- (void)renderAtTime:(CFTimeInterval)time viewport:(CGRect)viewport commandBuffer:(id<MTLCommandBuffer>)commandBuffer
      passDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor;
- (void)renderWithViewport:(CGRect)viewport commandBuffer:(id<MTLCommandBuffer>)commandBuffer passDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor;
- (UIImage *)snapshotAtTime:(CFTimeInterval)time withSize:(CGSize)size antialiasingMode:(SCNAntialiasingMode)antialiasingMode;
@end
NS_ASSUME_NONNULL_END
#endif
