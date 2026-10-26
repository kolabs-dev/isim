/* isim Metal: command queues, command buffers and encoders (issue #328). Encoders record work into their command
 * buffer: a compute dispatch takes the encoder's bindings at that point. A committed command buffer runs on its
 * queue's serial dispatch queue (in commit order), its dispatches on isim's worker threads (MTLDispatch.c), then
 * calls its completed handlers. Adapted: the CPU does the work; timestamps are the host's clock. */
#import "MTLPrivate.h"
#include <string.h>
#include <time.h>

static CFTimeInterval now_s(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }

@interface ISIMMTLCommandQueue : NSObject <MTLCommandQueue>
@property (nonatomic, readonly) dispatch_queue_t queue;
@end
@interface ISIMMTLCommandBuffer : NSObject <MTLCommandBuffer>
- (instancetype)initWithQueue:(ISIMMTLCommandQueue *)queue retained:(BOOL)retained;
- (void)addCommand:(void (^)(void))command;
- (void)encoderEnded;
@end

@implementation MTLCommandBufferDescriptor
- (instancetype)init { if ((self = [super init])) _retainedReferences = YES; return self; }
- (id)copyWithZone:(NSZone *)zone {
    MTLCommandBufferDescriptor *d = [[MTLCommandBufferDescriptor allocWithZone:zone] init];
    d.retainedReferences = _retainedReferences; d.errorOptions = _errorOptions;
    return d;
}
@end

/* ---- queues ---- */
@implementation ISIMMTLCommandQueue
@synthesize label;
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _queue = dispatch_queue_create("isim.metal.queue", DISPATCH_QUEUE_SERIAL);
    return self;
}
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (id<MTLCommandBuffer>)commandBuffer { return [[ISIMMTLCommandBuffer alloc] initWithQueue:self retained:YES]; }
- (id<MTLCommandBuffer>)commandBufferWithUnretainedReferences { return [[ISIMMTLCommandBuffer alloc] initWithQueue:self retained:NO]; }
- (id<MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor *)d {
    return [[ISIMMTLCommandBuffer alloc] initWithQueue:self retained:d.retainedReferences];
}
@end

@implementation ISIMMTLDevice (Queues)
- (id<MTLCommandQueue>)newCommandQueue { return [ISIMMTLCommandQueue new]; }
- (id<MTLCommandQueue>)newCommandQueueWithMaxCommandBufferCount:(NSUInteger)n { return [ISIMMTLCommandQueue new]; }
@end

/* ---- compute encoders ---- */
@interface ISIMMTLComputeCommandEncoder : NSObject <MTLComputeCommandEncoder>
- (instancetype)initWithCommandBuffer:(ISIMMTLCommandBuffer *)cb dispatchType:(MTLDispatchType)type;
@end

@implementation ISIMMTLComputeCommandEncoder {
    __weak ISIMMTLCommandBuffer *_cb;
    MTLDispatchType _type;
    ISIMMTLComputePipelineState *_pipeline;
    id<MTLBuffer> _buffers[ISIM_MTL_MAX_BUFFERS];
    NSUInteger _offsets[ISIM_MTL_MAX_BUFFERS];
    NSData *_bytes[ISIM_MTL_MAX_BUFFERS];
    ISIMMTLTexture *_textures[ISIM_MTL_MAX_TEXTURES];
    ISIMMTLSamplerState *_samplers[ISIM_MTL_MAX_SAMPLERS];
    size_t _tgmem[ISIM_MTL_MAX_TGMEM];
}
@synthesize label;
- (instancetype)initWithCommandBuffer:(ISIMMTLCommandBuffer *)cb dispatchType:(MTLDispatchType)type {
    if ((self = [super init])) { _cb = cb; _type = type; }
    return self;
}
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (MTLDispatchType)dispatchType { return _type; }
- (void)setComputePipelineState:(id<MTLComputePipelineState>)state { _pipeline = (ISIMMTLComputePipelineState *)state; }
- (void)setBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)i {
    if (i >= ISIM_MTL_MAX_BUFFERS) return;
    _bytes[i] = [NSData dataWithBytes:bytes length:length]; _buffers[i] = nil; _offsets[i] = 0;
}
- (void)setBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)i {
    if (i >= ISIM_MTL_MAX_BUFFERS) return;
    _buffers[i] = buffer; _offsets[i] = offset; _bytes[i] = nil;
}
- (void)setBufferOffset:(NSUInteger)offset atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_BUFFERS) _offsets[i] = offset; }
- (void)setBuffers:(const id<MTLBuffer> __strong *)buffers offsets:(const NSUInteger *)offsets withRange:(NSRange)range {
    for (NSUInteger k = 0; k < range.length; k++) [self setBuffer:buffers[k] offset:offsets[k] atIndex:range.location + k];
}
- (void)setTexture:(id<MTLTexture>)t atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_TEXTURES) _textures[i] = (ISIMMTLTexture *)t; }
- (void)setTextures:(const id<MTLTexture> __strong *)textures withRange:(NSRange)range {
    for (NSUInteger k = 0; k < range.length; k++) [self setTexture:textures[k] atIndex:range.location + k];
}
- (void)setSamplerState:(id<MTLSamplerState>)s atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_SAMPLERS) _samplers[i] = (ISIMMTLSamplerState *)s; }
- (void)setSamplerStates:(const id<MTLSamplerState> __strong *)samplers withRange:(NSRange)range {
    for (NSUInteger k = 0; k < range.length; k++) [self setSamplerState:samplers[k] atIndex:range.location + k];
}
- (void)setThreadgroupMemoryLength:(NSUInteger)length atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_TGMEM) _tgmem[i] = length; }
- (void)setStageInRegion:(MTLRegion)region {}
- (void)useResource:(id<MTLResource>)resource usage:(MTLResourceUsage)usage {}
- (void)useResources:(const id<MTLResource> __strong *)resources count:(NSUInteger)count usage:(MTLResourceUsage)usage {}
- (void)memoryBarrierWithScope:(MTLBarrierScope)scope {}
- (void)memoryBarrierWithResources:(const id<MTLResource> __strong *)resources count:(NSUInteger)count {}

/* records a dispatch with the current bindings; grid: threads per grid (the edge threadgroups smaller) */
- (void)record:(MTLSize)groups size:(MTLSize)size grid:(MTLSize)grid indirect:(id<MTLBuffer>)indirect offset:(NSUInteger)indirectOffset {
    ISIMMTLComputePipelineState *pipeline = _pipeline;
    if (!pipeline) { NSLog(@"isim Metal: dispatch without a compute pipeline state"); return; }
    NSMutableArray *keep = [NSMutableArray arrayWithObject:pipeline];
    isim_mtl_dispatch *d = calloc(1, sizeof *d);
    d->fn = pipeline.function.entry;
    d->prepare = pipeline.function.prepare;
    NSData *constants = pipeline.function.constantData;
    if (constants) { [keep addObject:constants]; d->args.constant_value = isim_mtl_constant_value; d->args.constants = constants.bytes; }
    for (int i = 0; i < ISIM_MTL_MAX_BUFFERS; i++) {
        if (_bytes[i]) { [keep addObject:_bytes[i]]; d->args.buffers[i] = (void *)_bytes[i].bytes; }
        else if (_buffers[i]) { [keep addObject:_buffers[i]]; d->args.buffers[i] = (uint8_t *)_buffers[i].contents + _offsets[i]; }
    }
    for (int i = 0; i < ISIM_MTL_MAX_TEXTURES; i++) if (_textures[i]) { [keep addObject:_textures[i]]; d->args.textures[i] = &_textures[i]->_desc; }
    for (int i = 0; i < ISIM_MTL_MAX_SAMPLERS; i++) if (_samplers[i]) { [keep addObject:_samplers[i]]; d->args.samplers[i] = &_samplers[i]->_desc; }
    memcpy(d->tgmem_length, _tgmem, sizeof _tgmem);
    NSUInteger s3[3] = {MAX(size.width, (NSUInteger)1), MAX(size.height, (NSUInteger)1), MAX(size.depth, (NSUInteger)1)};
    NSUInteger g3[3] = {groups.width, groups.height, groups.depth}, t3[3] = {grid.width, grid.height, grid.depth};
    for (int i = 0; i < 3; i++) {
        d->group_size[i] = (uint32_t)s3[i]; d->groups[i] = (uint32_t)g3[i]; d->grid[i] = (uint32_t)t3[i];
        d->args.threads_per_threadgroup[i] = d->group_size[i];
    }
    NSUInteger total = s3[0] * s3[1] * s3[2];
    if (total > pipeline.maxTotalThreadsPerThreadgroup)
        NSLog(@"isim Metal: %lu threads per threadgroup is more than the pipeline's maximum (%lu)", (unsigned long)total, (unsigned long)pipeline.maxTotalThreadsPerThreadgroup);
    if (indirect) [keep addObject:indirect];
    [_cb addCommand:^{
        (void)keep;
        if (indirect) {
            const uint32_t *n = (const uint32_t *)((const uint8_t *)indirect.contents + indirectOffset);
            for (int i = 0; i < 3; i++) { d->groups[i] = n[i]; d->grid[i] = n[i] * d->group_size[i]; }
        }
        for (int i = 0; i < 3; i++) { d->args.threadgroups_per_grid[i] = d->groups[i]; d->args.threads_per_grid[i] = d->grid[i]; }
        isim_mtl_run(d);
        free(d);
    }];
}
- (void)dispatchThreadgroups:(MTLSize)groups threadsPerThreadgroup:(MTLSize)size {
    [self record:groups size:size grid:MTLSizeMake(groups.width * size.width, groups.height * size.height, groups.depth * size.depth) indirect:nil offset:0];
}
- (void)dispatchThreads:(MTLSize)grid threadsPerThreadgroup:(MTLSize)size {
    NSUInteger w = MAX(size.width, (NSUInteger)1), h = MAX(size.height, (NSUInteger)1), dp = MAX(size.depth, (NSUInteger)1);
    MTLSize groups = MTLSizeMake((grid.width + w - 1) / w, (grid.height + h - 1) / h, (grid.depth + dp - 1) / dp);
    [self record:groups size:size grid:grid indirect:nil offset:0];
}
- (void)dispatchThreadgroupsWithIndirectBuffer:(id<MTLBuffer>)buffer indirectBufferOffset:(NSUInteger)offset threadsPerThreadgroup:(MTLSize)size {
    [self record:MTLSizeMake(1, 1, 1) size:size grid:size indirect:buffer offset:offset];
}
- (void)endEncoding { [_cb encoderEnded]; }
- (void)insertDebugSignpost:(NSString *)string {}
- (void)pushDebugGroup:(NSString *)string {}
- (void)popDebugGroup {}
@end

/* ---- blit encoders ---- */
@interface ISIMMTLBlitCommandEncoder : NSObject <MTLBlitCommandEncoder>
- (instancetype)initWithCommandBuffer:(ISIMMTLCommandBuffer *)cb;
@end

/* one texel of an 8-bit or float format as four floats, and back (mipmap generation) */
static int texel_rw(MTLPixelFormat f, uint8_t *p, float c[4], int write) {
    switch (f) {
    case MTLPixelFormatRGBA8Unorm: case MTLPixelFormatBGRA8Unorm: case MTLPixelFormatRGBA8Unorm_sRGB: case MTLPixelFormatBGRA8Unorm_sRGB:
        for (int i = 0; i < 4; i++) { if (write) p[i] = (uint8_t)(c[i] * 255.0f + 0.5f); else c[i] = p[i] / 255.0f; }
        return 1;
    case MTLPixelFormatR8Unorm: case MTLPixelFormatA8Unorm:
        if (write) p[0] = (uint8_t)(c[0] * 255.0f + 0.5f); else c[0] = p[0] / 255.0f;
        return 1;
    case MTLPixelFormatRG8Unorm:
        for (int i = 0; i < 2; i++) { if (write) p[i] = (uint8_t)(c[i] * 255.0f + 0.5f); else c[i] = p[i] / 255.0f; }
        return 1;
    case MTLPixelFormatR32Float: case MTLPixelFormatRG32Float: case MTLPixelFormatRGBA32Float: {
        int n = f == MTLPixelFormatR32Float ? 1 : f == MTLPixelFormatRG32Float ? 2 : 4;
        if (write) memcpy(p, c, n * 4); else memcpy(c, p, n * 4);
        return 1;
    }
    case MTLPixelFormatRGBA16Float: case MTLPixelFormatR16Float: case MTLPixelFormatRG16Float: {
        int n = f == MTLPixelFormatR16Float ? 1 : f == MTLPixelFormatRG16Float ? 2 : 4;
        _Float16 *h = (_Float16 *)p;
        for (int i = 0; i < n; i++) { if (write) h[i] = (_Float16)c[i]; else c[i] = (float)h[i]; }
        return 1;
    }
    default: return 0;
    }
}

@implementation ISIMMTLBlitCommandEncoder {
    __weak ISIMMTLCommandBuffer *_cb;
}
@synthesize label;
- (instancetype)initWithCommandBuffer:(ISIMMTLCommandBuffer *)cb { if ((self = [super init])) _cb = cb; return self; }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (void)copyFromBuffer:(id<MTLBuffer>)src sourceOffset:(NSUInteger)so toBuffer:(id<MTLBuffer>)dst destinationOffset:(NSUInteger)dso size:(NSUInteger)size {
    [_cb addCommand:^{ memmove((uint8_t *)dst.contents + dso, (const uint8_t *)src.contents + so, size); }];
}
- (void)fillBuffer:(id<MTLBuffer>)buffer range:(NSRange)range value:(uint8_t)value {
    [_cb addCommand:^{ memset((uint8_t *)buffer.contents + range.location, value, range.length); }];
}
- (void)copyFromTexture:(id<MTLTexture>)src sourceSlice:(NSUInteger)ss sourceLevel:(NSUInteger)sl sourceOrigin:(MTLOrigin)so sourceSize:(MTLSize)size
              toTexture:(id<MTLTexture>)dst destinationSlice:(NSUInteger)ds destinationLevel:(NSUInteger)dl destinationOrigin:(MTLOrigin)dorig {
    [_cb addCommand:^{
        isim_mtl_format_info fi = isim_mtl_format(src.pixelFormat);
        NSUInteger bpr = (size.width + fi.block_w - 1) / fi.block_w * MAX(fi.bytes, 1u);
        NSUInteger rows = (size.height + fi.block_h - 1) / fi.block_h, bpi = bpr * rows;
        NSMutableData *tmp = [NSMutableData dataWithLength:bpi * MAX(size.depth, (NSUInteger)1)];
        [src getBytes:tmp.mutableBytes bytesPerRow:bpr bytesPerImage:bpi fromRegion:(MTLRegion){so, size} mipmapLevel:sl slice:ss];
        [dst replaceRegion:(MTLRegion){dorig, size} mipmapLevel:dl slice:ds withBytes:tmp.bytes bytesPerRow:bpr bytesPerImage:bpi];
    }];
}
- (void)copyFromTexture:(id<MTLTexture>)src toTexture:(id<MTLTexture>)dst {
    NSUInteger levels = MIN(src.mipmapLevelCount, dst.mipmapLevelCount), slices = MIN(src.arrayLength, dst.arrayLength);
    for (NSUInteger s = 0; s < slices; s++)
        for (NSUInteger l = 0; l < levels; l++) {
            MTLSize size = MTLSizeMake(MAX(src.width >> l, (NSUInteger)1), MAX(src.height >> l, (NSUInteger)1),
                                       src.textureType == MTLTextureType3D ? MAX(src.depth >> l, (NSUInteger)1) : 1);
            [self copyFromTexture:src sourceSlice:s sourceLevel:l sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:size
                        toTexture:dst destinationSlice:s destinationLevel:l destinationOrigin:MTLOriginMake(0, 0, 0)];
        }
}
- (void)copyFromBuffer:(id<MTLBuffer>)src sourceOffset:(NSUInteger)so sourceBytesPerRow:(NSUInteger)bpr sourceBytesPerImage:(NSUInteger)bpi
            sourceSize:(MTLSize)size toTexture:(id<MTLTexture>)dst destinationSlice:(NSUInteger)ds destinationLevel:(NSUInteger)dl
     destinationOrigin:(MTLOrigin)origin {
    [_cb addCommand:^{
        [dst replaceRegion:(MTLRegion){origin, size} mipmapLevel:dl slice:ds withBytes:(const uint8_t *)src.contents + so bytesPerRow:bpr
             bytesPerImage:bpi ? bpi : bpr * size.height];
    }];
}
- (void)copyFromTexture:(id<MTLTexture>)src sourceSlice:(NSUInteger)ss sourceLevel:(NSUInteger)sl sourceOrigin:(MTLOrigin)origin
             sourceSize:(MTLSize)size toBuffer:(id<MTLBuffer>)dst destinationOffset:(NSUInteger)dso
 destinationBytesPerRow:(NSUInteger)bpr destinationBytesPerImage:(NSUInteger)bpi {
    [_cb addCommand:^{
        [src getBytes:(uint8_t *)dst.contents + dso bytesPerRow:bpr bytesPerImage:bpi ? bpi : bpr * size.height
           fromRegion:(MTLRegion){origin, size} mipmapLevel:sl slice:ss];
    }];
}
/* box-filters each level from the one above (8-bit unorm and float formats) */
- (void)generateMipmapsForTexture:(id<MTLTexture>)texture {
    [_cb addCommand:^{
        ISIMMTLTexture *t = (ISIMMTLTexture *)texture;
        MTLPixelFormat f = texture.pixelFormat;
        NSUInteger px = isim_mtl_format(f).bytes;
        for (uint32_t l = 1; l < t->_desc.mip_levels; l++) {
            uint32_t sw = MAX(t->_desc.width >> (l - 1), 1u), sh = MAX(t->_desc.height >> (l - 1), 1u);
            uint32_t w = MAX(t->_desc.width >> l, 1u), h = MAX(t->_desc.height >> l, 1u);
            for (uint32_t s = 0; s < t->_desc.array_length; s++)
                for (uint32_t y = 0; y < h; y++)
                    for (uint32_t x = 0; x < w; x++) {
                        float acc[4] = {0}, c[4]; int n = 0;
                        for (uint32_t dy = 0; dy < 2; dy++)
                            for (uint32_t dx = 0; dx < 2; dx++) {
                                uint32_t xx = MIN(2 * x + dx, sw - 1), yy = MIN(2 * y + dy, sh - 1);
                                uint8_t *p = t->_desc.levels[l - 1] + (size_t)s * t->_desc.level_bpi[l - 1] + (size_t)yy * t->_desc.level_bpr[l - 1] + xx * px;
                                memset(c, 0, sizeof c);
                                if (!texel_rw(f, p, c, 0)) return;
                                for (int i = 0; i < 4; i++) acc[i] += c[i];
                                n++;
                            }
                        for (int i = 0; i < 4; i++) acc[i] /= n;
                        texel_rw(f, t->_desc.levels[l] + (size_t)s * t->_desc.level_bpi[l] + (size_t)y * t->_desc.level_bpr[l] + x * px, acc, 1);
                    }
        }
    }];
}
- (void)optimizeContentsForGPUAccess:(id<MTLTexture>)texture {}
- (void)optimizeContentsForCPUAccess:(id<MTLTexture>)texture {}
- (void)synchronizeResource:(id<MTLResource>)resource {}
- (void)endEncoding { [_cb encoderEnded]; }
- (void)insertDebugSignpost:(NSString *)string {}
- (void)pushDebugGroup:(NSString *)string {}
- (void)popDebugGroup {}
@end

/* ---- command buffers ---- */
@implementation ISIMMTLCommandBuffer {
    ISIMMTLCommandQueue *_queue;
    BOOL _retained;
    NSMutableArray<void (^)(void)> *_commands;
    NSMutableArray<MTLCommandBufferHandler> *_scheduled, *_completed;
    NSCondition *_cond;
    MTLCommandBufferStatus _status;
    CFTimeInterval _start, _end;
}
@synthesize label;
- (instancetype)initWithQueue:(ISIMMTLCommandQueue *)queue retained:(BOOL)retained {
    if (!(self = [super init])) return nil;
    _queue = queue; _retained = retained;
    _commands = [NSMutableArray array]; _scheduled = [NSMutableArray array]; _completed = [NSMutableArray array];
    _cond = [NSCondition new];
    return self;
}
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (id<MTLCommandQueue>)commandQueue { return _queue; }
- (BOOL)retainedReferences { return _retained; }
- (MTLCommandBufferErrorOption)errorOptions { return MTLCommandBufferErrorOptionNone; }
- (CFTimeInterval)kernelStartTime { return _start; }
- (CFTimeInterval)kernelEndTime { return _end; }
- (CFTimeInterval)GPUStartTime { return _start; }
- (CFTimeInterval)GPUEndTime { return _end; }
- (NSError *)error { return nil; }
- (MTLCommandBufferStatus)status { [_cond lock]; MTLCommandBufferStatus s = _status; [_cond unlock]; return s; }
- (void)setStatus:(MTLCommandBufferStatus)s { [_cond lock]; _status = s; [_cond broadcast]; [_cond unlock]; }
- (void)addCommand:(void (^)(void))command {
    if (_status >= MTLCommandBufferStatusCommitted) { NSLog(@"isim Metal: encoding into a committed command buffer"); return; }
    [_commands addObject:[command copy]];
}
- (void)encoderEnded {}
- (void)enqueue { if (_status == MTLCommandBufferStatusNotEnqueued) [self setStatus:MTLCommandBufferStatusEnqueued]; }
- (void)addScheduledHandler:(MTLCommandBufferHandler)block { [_cond lock]; [_scheduled addObject:[block copy]]; [_cond unlock]; }
- (void)addCompletedHandler:(MTLCommandBufferHandler)block { [_cond lock]; [_completed addObject:[block copy]]; [_cond unlock]; }
- (void)commit {
    if (self.status >= MTLCommandBufferStatusCommitted) return;
    [self setStatus:MTLCommandBufferStatusCommitted];
    NSArray *commands = [_commands copy];
    [_commands removeAllObjects];
    dispatch_async(_queue.queue, ^{
        [self setStatus:MTLCommandBufferStatusScheduled];
        [self->_cond lock]; NSArray *scheduled = [self->_scheduled copy]; [self->_cond unlock];
        for (MTLCommandBufferHandler h in scheduled) h(self);
        self->_start = now_s();
        for (void (^c)(void) in commands) @autoreleasepool { c(); }
        self->_end = now_s();
        [self setStatus:MTLCommandBufferStatusCompleted];
        [self->_cond lock]; NSArray *completed = [self->_completed copy]; [self->_cond unlock];
        for (MTLCommandBufferHandler h in completed) h(self);
    });
}
- (void)waitUntilScheduled { [_cond lock]; while (_status < MTLCommandBufferStatusScheduled) [_cond wait]; [_cond unlock]; }
- (void)waitUntilCompleted {
    if (self.status < MTLCommandBufferStatusCommitted) return;
    [_cond lock]; while (_status < MTLCommandBufferStatusCompleted) [_cond wait]; [_cond unlock];
}
- (void)presentDrawable:(id<MTLDrawable>)drawable { [self addScheduledHandler:^(id<MTLCommandBuffer> cb) { [drawable present]; }]; }
- (void)presentDrawable:(id<MTLDrawable>)drawable atTime:(CFTimeInterval)t { [self addScheduledHandler:^(id<MTLCommandBuffer> cb) { [drawable presentAtTime:t]; }]; }
- (id<MTLComputeCommandEncoder>)computeCommandEncoder { return [self computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial]; }
- (id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType:(MTLDispatchType)type {
    return [[ISIMMTLComputeCommandEncoder alloc] initWithCommandBuffer:self dispatchType:type];
}
- (id<MTLBlitCommandEncoder>)blitCommandEncoder { return [[ISIMMTLBlitCommandEncoder alloc] initWithCommandBuffer:self]; }
- (void)pushDebugGroup:(NSString *)string {}
- (void)popDebugGroup {}
@end
