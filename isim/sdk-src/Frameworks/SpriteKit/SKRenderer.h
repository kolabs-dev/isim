#pragma once
/* isim SpriteKit: a scene drawn into an app's Metal render pass (isim's 2D renderer draws it, then a step on the
 * command buffer blends it over the first color attachment: bgra8 or rgba8). */
#import <SpriteKit/SKScene.h>
#import <Metal/Metal.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SKRenderer : NSObject
+ (SKRenderer *)rendererWithDevice:(id<MTLDevice>)device;
@property (nonatomic, nullable) SKScene *scene;
@property (nonatomic) BOOL ignoresSiblingOrder;
@property (nonatomic) BOOL shouldCullNonVisibleNodes;
@property (nonatomic) BOOL showsDrawCount;
@property (nonatomic) BOOL showsNodeCount;
@property (nonatomic) BOOL showsQuadCount;
@property (nonatomic) BOOL showsPhysics;
@property (nonatomic) BOOL showsFields;
- (void)updateAtTime:(NSTimeInterval)currentTime;
- (void)renderWithViewport:(CGRect)viewport commandBuffer:(id<MTLCommandBuffer>)commandBuffer renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor;
- (void)renderWithViewport:(CGRect)viewport renderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor commandQueue:(id<MTLCommandQueue>)commandQueue;
@end
NS_ASSUME_NONNULL_END
#endif
