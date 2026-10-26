#pragma once
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLRenderPass.h>
#import <Metal/MTLRenderPipeline.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLRenderPipelineState, MTLBuffer, MTLTexture, MTLSamplerState, MTLDepthStencilState, MTLResource;
/* issue #329: draws record the encoder's state at that point; the command buffer runs them through isim's rasterizer */
typedef NS_ENUM(NSUInteger, MTLPrimitiveType) {
    MTLPrimitiveTypePoint = 0, MTLPrimitiveTypeLine = 1, MTLPrimitiveTypeLineStrip = 2, MTLPrimitiveTypeTriangle = 3, MTLPrimitiveTypeTriangleStrip = 4,
};
typedef NS_ENUM(NSUInteger, MTLIndexType) { MTLIndexTypeUInt16 NS_SWIFT_NAME(uint16) = 0, MTLIndexTypeUInt32 NS_SWIFT_NAME(uint32) = 1 };
typedef NS_ENUM(NSUInteger, MTLVisibilityResultMode) { MTLVisibilityResultModeDisabled = 0, MTLVisibilityResultModeBoolean = 1, MTLVisibilityResultModeCounting = 2 };
typedef NS_ENUM(NSUInteger, MTLCullMode) { MTLCullModeNone = 0, MTLCullModeFront = 1, MTLCullModeBack = 2 };
typedef NS_ENUM(NSUInteger, MTLWinding) { MTLWindingClockwise = 0, MTLWindingCounterClockwise = 1 };
typedef NS_ENUM(NSUInteger, MTLDepthClipMode) { MTLDepthClipModeClip = 0, MTLDepthClipModeClamp = 1 };
typedef NS_ENUM(NSUInteger, MTLTriangleFillMode) { MTLTriangleFillModeFill = 0, MTLTriangleFillModeLines = 1 };
typedef NS_OPTIONS(NSUInteger, MTLRenderStages) {
    MTLRenderStageVertex = (1UL << 0), MTLRenderStageFragment = (1UL << 1), MTLRenderStageTile = (1UL << 2),
    MTLRenderStageObject = (1UL << 3), MTLRenderStageMesh = (1UL << 4),
};
typedef struct { double originX, originY, width, height, znear, zfar; } MTLViewport;
typedef struct { NSUInteger x, y, width, height; } MTLScissorRect;
typedef struct { uint32_t vertexCount, instanceCount, vertexStart, baseInstance; } MTLDrawPrimitivesIndirectArguments;
typedef struct { uint32_t indexCount, instanceCount, indexStart; int32_t baseVertex; uint32_t baseInstance; } MTLDrawIndexedPrimitivesIndirectArguments;

@protocol MTLRenderCommandEncoder <MTLCommandEncoder>
- (void)setRenderPipelineState:(id<MTLRenderPipelineState>)pipelineState NS_SWIFT_NAME(setRenderPipelineState(_:));
- (void)setVertexBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index NS_SWIFT_NAME(setVertexBytes(_:length:index:));
- (void)setVertexBuffer:(nullable id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index NS_SWIFT_NAME(setVertexBuffer(_:offset:index:));
- (void)setVertexBufferOffset:(NSUInteger)offset atIndex:(NSUInteger)index NS_SWIFT_NAME(setVertexBufferOffset(_:index:));
- (void)setVertexBuffers:(const id<MTLBuffer> _Nullable [_Nonnull])buffers offsets:(const NSUInteger [_Nonnull])offsets withRange:(NSRange)range
    NS_SWIFT_NAME(__setVertexBuffers(_:offsets:with:));
- (void)setVertexTexture:(nullable id<MTLTexture>)texture atIndex:(NSUInteger)index NS_SWIFT_NAME(setVertexTexture(_:index:));
- (void)setVertexTextures:(const id<MTLTexture> _Nullable [_Nonnull])textures withRange:(NSRange)range NS_SWIFT_NAME(__setVertexTextures(_:with:));
- (void)setVertexSamplerState:(nullable id<MTLSamplerState>)sampler atIndex:(NSUInteger)index NS_SWIFT_NAME(setVertexSamplerState(_:index:));
- (void)setVertexSamplerStates:(const id<MTLSamplerState> _Nullable [_Nonnull])samplers withRange:(NSRange)range
    NS_SWIFT_NAME(__setVertexSamplerStates(_:with:));
- (void)setFragmentBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index NS_SWIFT_NAME(setFragmentBytes(_:length:index:));
- (void)setFragmentBuffer:(nullable id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index NS_SWIFT_NAME(setFragmentBuffer(_:offset:index:));
- (void)setFragmentBufferOffset:(NSUInteger)offset atIndex:(NSUInteger)index NS_SWIFT_NAME(setFragmentBufferOffset(_:index:));
- (void)setFragmentBuffers:(const id<MTLBuffer> _Nullable [_Nonnull])buffers offsets:(const NSUInteger [_Nonnull])offsets withRange:(NSRange)range
    NS_SWIFT_NAME(__setFragmentBuffers(_:offsets:with:));
- (void)setFragmentTexture:(nullable id<MTLTexture>)texture atIndex:(NSUInteger)index NS_SWIFT_NAME(setFragmentTexture(_:index:));
- (void)setFragmentTextures:(const id<MTLTexture> _Nullable [_Nonnull])textures withRange:(NSRange)range NS_SWIFT_NAME(__setFragmentTextures(_:with:));
- (void)setFragmentSamplerState:(nullable id<MTLSamplerState>)sampler atIndex:(NSUInteger)index NS_SWIFT_NAME(setFragmentSamplerState(_:index:));
- (void)setFragmentSamplerStates:(const id<MTLSamplerState> _Nullable [_Nonnull])samplers withRange:(NSRange)range
    NS_SWIFT_NAME(__setFragmentSamplerStates(_:with:));
- (void)setViewport:(MTLViewport)viewport NS_SWIFT_NAME(setViewport(_:));
- (void)setViewports:(const MTLViewport [_Nonnull])viewports count:(NSUInteger)count NS_SWIFT_NAME(__setViewports(_:count:));
- (void)setScissorRect:(MTLScissorRect)rect NS_SWIFT_NAME(setScissorRect(_:));
- (void)setScissorRects:(const MTLScissorRect [_Nonnull])scissorRects count:(NSUInteger)count NS_SWIFT_NAME(__setScissorRects(_:count:));
- (void)setFrontFacingWinding:(MTLWinding)frontFacingWinding NS_SWIFT_NAME(setFrontFacing(_:));
- (void)setCullMode:(MTLCullMode)cullMode NS_SWIFT_NAME(setCullMode(_:));
- (void)setDepthClipMode:(MTLDepthClipMode)depthClipMode NS_SWIFT_NAME(setDepthClipMode(_:));
- (void)setDepthBias:(float)depthBias slopeScale:(float)slopeScale clamp:(float)clamp NS_SWIFT_NAME(setDepthBias(_:slopeScale:clamp:));
- (void)setTriangleFillMode:(MTLTriangleFillMode)fillMode NS_SWIFT_NAME(setTriangleFillMode(_:));
- (void)setBlendColorRed:(float)red green:(float)green blue:(float)blue alpha:(float)alpha NS_SWIFT_NAME(setBlendColor(red:green:blue:alpha:));
- (void)setDepthStencilState:(nullable id<MTLDepthStencilState>)depthStencilState NS_SWIFT_NAME(setDepthStencilState(_:));
- (void)setStencilReferenceValue:(uint32_t)referenceValue NS_SWIFT_NAME(setStencilReferenceValue(_:));
- (void)setStencilFrontReferenceValue:(uint32_t)frontReferenceValue backReferenceValue:(uint32_t)backReferenceValue
    NS_SWIFT_NAME(setStencilReferenceValues(front:back:));
- (void)setVisibilityResultMode:(MTLVisibilityResultMode)mode offset:(NSUInteger)offset NS_SWIFT_NAME(setVisibilityResultMode(_:offset:));

- (void)drawPrimitives:(MTLPrimitiveType)primitiveType vertexStart:(NSUInteger)vertexStart vertexCount:(NSUInteger)vertexCount
    NS_SWIFT_NAME(drawPrimitives(type:vertexStart:vertexCount:));
- (void)drawPrimitives:(MTLPrimitiveType)primitiveType vertexStart:(NSUInteger)vertexStart vertexCount:(NSUInteger)vertexCount
         instanceCount:(NSUInteger)instanceCount NS_SWIFT_NAME(drawPrimitives(type:vertexStart:vertexCount:instanceCount:));
- (void)drawPrimitives:(MTLPrimitiveType)primitiveType vertexStart:(NSUInteger)vertexStart vertexCount:(NSUInteger)vertexCount
         instanceCount:(NSUInteger)instanceCount baseInstance:(NSUInteger)baseInstance
    NS_SWIFT_NAME(drawPrimitives(type:vertexStart:vertexCount:instanceCount:baseInstance:));
- (void)drawPrimitives:(MTLPrimitiveType)primitiveType indirectBuffer:(id<MTLBuffer>)indirectBuffer indirectBufferOffset:(NSUInteger)indirectBufferOffset
    NS_SWIFT_NAME(drawPrimitives(type:indirectBuffer:indirectBufferOffset:));
- (void)drawIndexedPrimitives:(MTLPrimitiveType)primitiveType indexCount:(NSUInteger)indexCount indexType:(MTLIndexType)indexType
                  indexBuffer:(id<MTLBuffer>)indexBuffer indexBufferOffset:(NSUInteger)indexBufferOffset
    NS_SWIFT_NAME(drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:));
- (void)drawIndexedPrimitives:(MTLPrimitiveType)primitiveType indexCount:(NSUInteger)indexCount indexType:(MTLIndexType)indexType
                  indexBuffer:(id<MTLBuffer>)indexBuffer indexBufferOffset:(NSUInteger)indexBufferOffset instanceCount:(NSUInteger)instanceCount
    NS_SWIFT_NAME(drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:));
- (void)drawIndexedPrimitives:(MTLPrimitiveType)primitiveType indexCount:(NSUInteger)indexCount indexType:(MTLIndexType)indexType
                  indexBuffer:(id<MTLBuffer>)indexBuffer indexBufferOffset:(NSUInteger)indexBufferOffset instanceCount:(NSUInteger)instanceCount
                   baseVertex:(NSInteger)baseVertex baseInstance:(NSUInteger)baseInstance
    NS_SWIFT_NAME(drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:));
- (void)drawIndexedPrimitives:(MTLPrimitiveType)primitiveType indexType:(MTLIndexType)indexType indexBuffer:(id<MTLBuffer>)indexBuffer
            indexBufferOffset:(NSUInteger)indexBufferOffset indirectBuffer:(id<MTLBuffer>)indirectBuffer indirectBufferOffset:(NSUInteger)indirectBufferOffset
    NS_SWIFT_NAME(drawIndexedPrimitives(type:indexType:indexBuffer:indexBufferOffset:indirectBuffer:indirectBufferOffset:));

- (void)useResource:(id<MTLResource>)resource usage:(MTLResourceUsage)usage stages:(MTLRenderStages)stages NS_SWIFT_NAME(useResource(_:usage:stages:));
- (void)useResources:(const id<MTLResource> _Nonnull [_Nonnull])resources count:(NSUInteger)count usage:(MTLResourceUsage)usage
              stages:(MTLRenderStages)stages NS_SWIFT_NAME(__use(_:count:usage:stages:));
- (void)memoryBarrierWithScope:(MTLBarrierScope)scope afterStages:(MTLRenderStages)after beforeStages:(MTLRenderStages)before
    NS_SWIFT_NAME(memoryBarrier(scope:after:before:));
- (void)textureBarrier;
@end
NS_ASSUME_NONNULL_END
