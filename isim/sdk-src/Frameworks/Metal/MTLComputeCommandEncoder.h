#pragma once
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLTypes.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLComputePipelineState, MTLBuffer, MTLTexture, MTLSamplerState, MTLResource;
typedef NS_ENUM(NSUInteger, MTLDispatchType) { MTLDispatchTypeSerial = 0, MTLDispatchTypeConcurrent = 1 };
typedef struct { uint32_t threadgroupsPerGrid[3]; } MTLDispatchThreadgroupsIndirectArguments;
/* each dispatch records the encoder's bindings at that point; the command buffer runs it on isim's worker threads */
@protocol MTLComputeCommandEncoder <MTLCommandEncoder>
@property (readonly) MTLDispatchType dispatchType;
- (void)setComputePipelineState:(id<MTLComputePipelineState>)state;
- (void)setBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index NS_SWIFT_NAME(setBytes(_:length:index:));
- (void)setBuffer:(nullable id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index NS_SWIFT_NAME(setBuffer(_:offset:index:));
- (void)setBufferOffset:(NSUInteger)offset atIndex:(NSUInteger)index NS_SWIFT_NAME(setBufferOffset(_:index:));
- (void)setBuffers:(const id<MTLBuffer> _Nullable [_Nonnull])buffers offsets:(const NSUInteger [_Nonnull])offsets withRange:(NSRange)range
    NS_SWIFT_NAME(__setBuffers(_:offsets:with:));
- (void)setTexture:(nullable id<MTLTexture>)texture atIndex:(NSUInteger)index NS_SWIFT_NAME(setTexture(_:index:));
- (void)setTextures:(const id<MTLTexture> _Nullable [_Nonnull])textures withRange:(NSRange)range NS_SWIFT_NAME(__setTextures(_:with:));
- (void)setSamplerState:(nullable id<MTLSamplerState>)sampler atIndex:(NSUInteger)index NS_SWIFT_NAME(setSamplerState(_:index:));
- (void)setSamplerStates:(const id<MTLSamplerState> _Nullable [_Nonnull])samplers withRange:(NSRange)range NS_SWIFT_NAME(__setSamplerStates(_:with:));
- (void)setThreadgroupMemoryLength:(NSUInteger)length atIndex:(NSUInteger)index NS_SWIFT_NAME(setThreadgroupMemoryLength(_:index:));
- (void)setStageInRegion:(MTLRegion)region;
- (void)dispatchThreadgroups:(MTLSize)threadgroupsPerGrid threadsPerThreadgroup:(MTLSize)threadsPerThreadgroup;
- (void)dispatchThreadgroupsWithIndirectBuffer:(id<MTLBuffer>)indirectBuffer indirectBufferOffset:(NSUInteger)indirectBufferOffset
                         threadsPerThreadgroup:(MTLSize)threadsPerThreadgroup
    NS_SWIFT_NAME(dispatchThreadgroups(indirectBuffer:indirectBufferOffset:threadsPerThreadgroup:));
- (void)dispatchThreads:(MTLSize)threadsPerGrid threadsPerThreadgroup:(MTLSize)threadsPerThreadgroup;
- (void)useResource:(id<MTLResource>)resource usage:(MTLResourceUsage)usage NS_SWIFT_NAME(useResource(_:usage:));
- (void)useResources:(const id<MTLResource> _Nonnull [_Nonnull])resources count:(NSUInteger)count usage:(MTLResourceUsage)usage
    NS_SWIFT_NAME(__use(_:count:usage:));
- (void)memoryBarrierWithScope:(MTLBarrierScope)scope NS_SWIFT_NAME(memoryBarrier(scope:));
- (void)memoryBarrierWithResources:(const id<MTLResource> _Nonnull [_Nonnull])resources count:(NSUInteger)count
    NS_SWIFT_NAME(__memoryBarrier(resources:count:));
@end
NS_ASSUME_NONNULL_END
