/* isim Metal: what the framework's files share (frameworks/Metal) */
#pragma once
#pragma clang diagnostic ignored "-Wnullability-completeness"   /* internal declarations */
/* ISIMMTLDevice implements MTLDevice in categories across MTLDevice.m, MTLLibrary.m and MTLCommand.m */
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
#import <Metal/Metal.h>

#include "MTLDispatch.h"
#include "MTLRaster.h"

/* pixel formats: bytes per pixel, or per block for the compressed ones */
typedef struct { uint32_t bytes, block_w, block_h; } isim_mtl_format_info;
isim_mtl_format_info isim_mtl_format(MTLPixelFormat f);

@interface ISIMMTLDevice : NSObject <MTLDevice>
+ (instancetype)shared;
@end
@interface ISIMMTLBuffer : NSObject <MTLBuffer>
@end
@interface ISIMMTLTexture : NSObject <MTLTexture> {
@public
    __isim_mtl_texture _desc;
}
@end
@interface ISIMMTLSamplerState : NSObject <MTLSamplerState> {
@public
    __isim_mtl_sampler _desc;
}
@end
@interface ISIMMTLFunction : NSObject <MTLFunction>
@property (nonatomic, readonly) const __isim_mtl_function *entry;
@property (nonatomic, readonly) void (*prepare)(const __isim_mtl_args *);
@property (nonatomic, readonly, nullable) NSData *constantData;     /* the values set for this function (isim_mtl_constant_value) */
@end
@interface ISIMMTLComputePipelineState : NSObject <MTLComputePipelineState>
@property (nonatomic, readonly) ISIMMTLFunction *function;
@end
@interface MTLFunctionConstantValues ()
- (NSData *)isim_values;     /* { uint32 index, uint32 size, 16 bytes } records */
@end
int isim_mtl_constant_value(const void *ctx, uint32_t index, void *out, uint32_t size);
NSError *isim_mtl_error(NSErrorDomain domain, NSInteger code, NSString *message);
@interface ISIMMTLBuffer ()
- (instancetype)initWithLength:(NSUInteger)length options:(MTLResourceOptions)options bytes:(nullable const void *)bytes;
- (instancetype)initNoCopy:(void *)p length:(NSUInteger)length options:(MTLResourceOptions)options deallocator:(nullable void (^)(void *, NSUInteger))d;
@end
@interface ISIMMTLTexture ()
- (nullable instancetype)initWithDescriptor:(MTLTextureDescriptor *)d buffer:(nullable id<MTLBuffer>)buffer offset:(NSUInteger)offset bytesPerRow:(NSUInteger)bpr;
- (instancetype)initViewOf:(ISIMMTLTexture *)parent format:(MTLPixelFormat)f;
@end
@interface ISIMMTLSamplerState ()
- (instancetype)initWithDescriptor:(MTLSamplerDescriptor *)d;
@end
/* MTLDevice's methods, by file: resources (MTLDevice.m), libraries and pipelines (MTLLibrary.m), queues (MTLCommand.m) */
@interface ISIMMTLDevice (Resources)
@end
@interface ISIMMTLDevice (Libraries)
@end
@interface ISIMMTLDevice (Queues)
@end
@interface ISIMMTLComputePipelineState ()
- (instancetype)initWithFunction:(ISIMMTLFunction *)f descriptor:(MTLComputePipelineDescriptor *)d;
@end
@interface MTLFunctionConstantValues ()
- (NSData *)isim_valuesWithNames:(NSDictionary<NSString *, MTLFunctionConstant *> *)constants;
@end
/* command buffers record the encoders' work as blocks, run in order when committed (MTLCommand.m) */
@interface ISIMMTLCommandBuffer : NSObject <MTLCommandBuffer>
- (void)addCommand:(void (^)(void))command;
- (void)encoderEnded;
@end
/* render passes and pipelines (MTLRender.m, issue #329) */
id<MTLRenderCommandEncoder> isim_mtl_render_encoder(ISIMMTLCommandBuffer *cb, MTLRenderPassDescriptor *d);
@interface ISIMMTLDevice (Render)
@end
