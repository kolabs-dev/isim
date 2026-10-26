/* isim Metal: render pipelines (issue #329). Vertex descriptors, render pipeline and depth-stencil states, render pass
 * descriptors and render command encoders. A render pass records its load actions, its draws (each with the
 * encoder's state at that point) and its store actions into the command buffer; the draws run through isim's
 * rasterizer (MTLRaster.c) when the command buffer runs. Adapted: the vertex and fragment functions and the
 * rasterization run on the CPU. */
#import "MTLPrivate.h"
#include <string.h>

/* ---- vertex descriptors ---- */
@implementation MTLVertexBufferLayoutDescriptor
- (instancetype)init { if ((self = [super init])) { _stepFunction = MTLVertexStepFunctionPerVertex; _stepRate = 1; } return self; }
- (id)copyWithZone:(NSZone *)zone {
    MTLVertexBufferLayoutDescriptor *d = [[MTLVertexBufferLayoutDescriptor allocWithZone:zone] init];
    d.stride = _stride; d.stepFunction = _stepFunction; d.stepRate = _stepRate;
    return d;
}
@end
@implementation MTLVertexAttributeDescriptor
- (id)copyWithZone:(NSZone *)zone {
    MTLVertexAttributeDescriptor *d = [[MTLVertexAttributeDescriptor allocWithZone:zone] init];
    d.format = _format; d.offset = _offset; d.bufferIndex = _bufferIndex;
    return d;
}
@end

/* an array of descriptors created on first use (index -> descriptor) */
#define ISIM_DESCRIPTOR_ARRAY(Array, Element, Limit) \
@implementation Array { NSMutableDictionary<NSNumber *, Element *> *_items; } \
- (instancetype)init { if ((self = [super init])) _items = [NSMutableDictionary dictionary]; return self; } \
- (Element *)objectAtIndexedSubscript:(NSUInteger)i { \
    Element *e = _items[@(i)]; \
    if (!e && i < (Limit)) { e = [Element new]; _items[@(i)] = e; } \
    return e; \
} \
- (void)setObject:(Element *)e atIndexedSubscript:(NSUInteger)i { if (e) _items[@(i)] = [e copy]; else [_items removeObjectForKey:@(i)]; } \
- (Element *)isim_existing:(NSUInteger)i { return _items[@(i)]; } \
- (void)isim_copyTo:(Array *)other { for (NSNumber *k in _items) other->_items[k] = [_items[k] copy]; } \
@end

@interface MTLVertexBufferLayoutDescriptorArray ()
- (MTLVertexBufferLayoutDescriptor *)isim_existing:(NSUInteger)i;
- (void)isim_copyTo:(MTLVertexBufferLayoutDescriptorArray *)other;
@end
@interface MTLVertexAttributeDescriptorArray ()
- (MTLVertexAttributeDescriptor *)isim_existing:(NSUInteger)i;
- (void)isim_copyTo:(MTLVertexAttributeDescriptorArray *)other;
@end
ISIM_DESCRIPTOR_ARRAY(MTLVertexBufferLayoutDescriptorArray, MTLVertexBufferLayoutDescriptor, ISIM_MTL_MAX_ATTRIBUTES)
ISIM_DESCRIPTOR_ARRAY(MTLVertexAttributeDescriptorArray, MTLVertexAttributeDescriptor, ISIM_MTL_MAX_ATTRIBUTES)

@implementation MTLVertexDescriptor
+ (MTLVertexDescriptor *)vertexDescriptor { return [self new]; }
- (instancetype)init {
    if ((self = [super init])) { _layouts = [MTLVertexBufferLayoutDescriptorArray new]; _attributes = [MTLVertexAttributeDescriptorArray new]; }
    return self;
}
- (void)reset { _layouts = [MTLVertexBufferLayoutDescriptorArray new]; _attributes = [MTLVertexAttributeDescriptorArray new]; }
- (id)copyWithZone:(NSZone *)zone {
    MTLVertexDescriptor *d = [[MTLVertexDescriptor allocWithZone:zone] init];
    [_layouts isim_copyTo:d.layouts]; [_attributes isim_copyTo:d.attributes];
    return d;
}
@end

/* ---- render pipeline descriptors ---- */
@implementation MTLRenderPipelineColorAttachmentDescriptor
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _sourceRGBBlendFactor = _sourceAlphaBlendFactor = MTLBlendFactorOne;
    _destinationRGBBlendFactor = _destinationAlphaBlendFactor = MTLBlendFactorZero;
    _writeMask = MTLColorWriteMaskAll;
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPipelineColorAttachmentDescriptor *d = [[MTLRenderPipelineColorAttachmentDescriptor allocWithZone:zone] init];
    d.pixelFormat = _pixelFormat; d.blendingEnabled = _blendingEnabled; d.writeMask = _writeMask;
    d.sourceRGBBlendFactor = _sourceRGBBlendFactor; d.destinationRGBBlendFactor = _destinationRGBBlendFactor; d.rgbBlendOperation = _rgbBlendOperation;
    d.sourceAlphaBlendFactor = _sourceAlphaBlendFactor; d.destinationAlphaBlendFactor = _destinationAlphaBlendFactor; d.alphaBlendOperation = _alphaBlendOperation;
    return d;
}
@end
@interface MTLRenderPipelineColorAttachmentDescriptorArray ()
- (MTLRenderPipelineColorAttachmentDescriptor *)isim_existing:(NSUInteger)i;
- (void)isim_copyTo:(MTLRenderPipelineColorAttachmentDescriptorArray *)other;
@end
ISIM_DESCRIPTOR_ARRAY(MTLRenderPipelineColorAttachmentDescriptorArray, MTLRenderPipelineColorAttachmentDescriptor, ISIM_MTL_MAX_COLORS)

@implementation MTLRenderPipelineReflection
- (NSArray *)vertexArguments { return @[]; }
- (NSArray *)fragmentArguments { return @[]; }
- (NSArray *)vertexBindings { return @[]; }
- (NSArray *)fragmentBindings { return @[]; }
@end

@implementation MTLRenderPipelineDescriptor
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _colorAttachments = [MTLRenderPipelineColorAttachmentDescriptorArray new];
    _sampleCount = _rasterSampleCount = 1; _rasterizationEnabled = YES; _maxVertexAmplificationCount = 1;
    return self;
}
- (void)setSampleCount:(NSUInteger)n { _sampleCount = _rasterSampleCount = n; }
- (void)setRasterSampleCount:(NSUInteger)n { _sampleCount = _rasterSampleCount = n; }
- (void)reset {
    _label = nil; _vertexFunction = _fragmentFunction = nil; _vertexDescriptor = nil;
    _colorAttachments = [MTLRenderPipelineColorAttachmentDescriptorArray new];
    _sampleCount = _rasterSampleCount = 1; _rasterizationEnabled = YES; _alphaToCoverageEnabled = _alphaToOneEnabled = NO;
    _depthAttachmentPixelFormat = _stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    _inputPrimitiveTopology = MTLPrimitiveTopologyClassUnspecified;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPipelineDescriptor *d = [[MTLRenderPipelineDescriptor allocWithZone:zone] init];
    d.label = _label; d.vertexFunction = _vertexFunction; d.fragmentFunction = _fragmentFunction; d.vertexDescriptor = _vertexDescriptor;
    d.sampleCount = _sampleCount; d.alphaToCoverageEnabled = _alphaToCoverageEnabled; d.alphaToOneEnabled = _alphaToOneEnabled;
    d.rasterizationEnabled = _rasterizationEnabled; d.maxVertexAmplificationCount = _maxVertexAmplificationCount;
    d.depthAttachmentPixelFormat = _depthAttachmentPixelFormat; d.stencilAttachmentPixelFormat = _stencilAttachmentPixelFormat;
    d.inputPrimitiveTopology = _inputPrimitiveTopology; d.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
    [_colorAttachments isim_copyTo:d.colorAttachments];
    return d;
}
@end

/* ---- render pipeline states ---- */
@interface ISIMMTLRenderPipelineState : NSObject <MTLRenderPipelineState> {
@public
    isim_mtl_pipeline _p;
}
@end
@implementation ISIMMTLRenderPipelineState {
    NSString *_label;
    ISIMMTLFunction *_vertex, *_fragment;
    NSData *_vconst, *_fconst;
}
- (instancetype)initWithDescriptor:(MTLRenderPipelineDescriptor *)d error:(NSError **)error {
    if (!(self = [super init])) return nil;
    _label = [d.label copy];
    id<MTLFunction> vf = d.vertexFunction, ff = d.fragmentFunction;
    NSString *problem = nil;
    if (![(NSObject *)vf isKindOfClass:[ISIMMTLFunction class]] || vf.functionType != MTLFunctionTypeVertex || !((ISIMMTLFunction *)vf).entry->render)
        problem = @"the vertex function is not a vertex function of a library compiled by isim";
    else if (ff && (![(NSObject *)ff isKindOfClass:[ISIMMTLFunction class]] || ff.functionType != MTLFunctionTypeFragment || !((ISIMMTLFunction *)ff).entry->render))
        problem = @"the fragment function is not a fragment function of a library compiled by isim";
    if (problem) {
        if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorInternal, problem);
        return nil;
    }
    _vertex = (ISIMMTLFunction *)vf; _fragment = (ISIMMTLFunction *)ff;
    _p.vs = _vertex.entry->render;
    _p.vs_prepare = _vertex.prepare;
    _vconst = _vertex.constantData; _p.vs_constants = _vconst.bytes;
    if (_fragment) {
        _p.fs = _fragment.entry->render; _p.fs_prepare = _fragment.prepare;
        _fconst = _fragment.constantData; _p.fs_constants = _fconst.bytes;
        if (![self mapStage:error]) return nil;
    }
    MTLVertexDescriptor *vd = d.vertexDescriptor;
    for (NSUInteger i = 0; vd && i < ISIM_MTL_MAX_ATTRIBUTES; i++) {
        MTLVertexAttributeDescriptor *a = [vd.attributes isim_existing:i];
        if (a && a.format != MTLVertexFormatInvalid) {
            _p.attr_format[i] = (uint32_t)a.format; _p.attr_offset[i] = (uint32_t)a.offset; _p.attr_buffer[i] = (uint32_t)a.bufferIndex;
        }
        MTLVertexBufferLayoutDescriptor *l = [vd.layouts isim_existing:i];
        _p.layout_stride[i] = l ? (uint32_t)l.stride : 0;
        _p.layout_step[i] = l ? (uint32_t)l.stepFunction : MTLVertexStepFunctionPerVertex;
        _p.layout_rate[i] = l ? (uint32_t)l.stepRate : 1;
    }
    for (NSUInteger i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
        MTLRenderPipelineColorAttachmentDescriptor *c = [d.colorAttachments isim_existing:i];
        isim_mtl_blend *b = &_p.blend[i];
        if (!c) { b->write_mask = 0xf; b->src_rgb = b->src_a = 1; continue; }
        b->enabled = c.blendingEnabled; b->write_mask = (uint8_t)c.writeMask;
        b->src_rgb = (uint8_t)c.sourceRGBBlendFactor; b->dst_rgb = (uint8_t)c.destinationRGBBlendFactor; b->op_rgb = (uint8_t)c.rgbBlendOperation;
        b->src_a = (uint8_t)c.sourceAlphaBlendFactor; b->dst_a = (uint8_t)c.destinationAlphaBlendFactor; b->op_a = (uint8_t)c.alphaBlendOperation;
    }
    _p.rasterize = d.rasterizationEnabled;
    return self;
}
/* the fragment function's [[stage_in]] members from the vertex outputs, matched by [[user(name)]] or name */
- (BOOL)mapStage:(NSError **)error {
    const __isim_mtl_render *vs = _p.vs, *fs = _p.fs;
    if (!fs->stage_size) return YES;
    BOOL same = vs->stage_size == fs->stage_size && vs->stage_members == fs->stage_members;
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    uint32_t n = 0;
    for (uint32_t i = 0; i < fs->stage_members; i++) {
        const __isim_mtl_member *fm = &fs->members[i];
        if (fm->flags & ISIM_MTL_MEMBER_POSITION) { if (same && (i >= vs->stage_members || vs->members[i].offset != fm->offset)) same = NO; continue; }
        const __isim_mtl_member *vm = NULL;
        for (uint32_t k = 0; k < vs->stage_members; k++) if (!strcmp(vs->members[k].key, fm->key)) { vm = &vs->members[k]; break; }
        if (!vm) { [missing addObject:[@(fm->key) stringByReplacingOccurrencesOfString:@"user:" withString:@""]]; continue; }
        if (vm->offset != fm->offset || vm->size != fm->size) same = NO;
        if (n < sizeof _p.copies / sizeof _p.copies[0]) _p.copies[n++] = (isim_mtl_copy){vm->offset, fm->offset, MIN(vm->size, fm->size)};
    }
    if (missing.count) {
        if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorInternal,
            [NSString stringWithFormat:@"Fragment input(s) `%@` mismatching vertex shader output type(s) or not written by vertex shader",
                                       [missing componentsJoinedByString:@","]]);
        return NO;
    }
    _p.ncopies = same ? 0 : n;
    return YES;
}
- (NSString *)label { return _label; }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (NSUInteger)maxTotalThreadsPerThreadgroup { return 1024; }
- (BOOL)threadgroupSizeMatchesTileSize { return NO; }
- (NSUInteger)imageblockSampleLength { return 0; }
- (BOOL)supportIndirectCommandBuffers { return NO; }
- (MTLResourceID)gpuResourceID { return (MTLResourceID){(uint64_t)(uintptr_t)self}; }
@end

/* ---- depth and stencil ---- */
@implementation MTLStencilDescriptor
- (instancetype)init {
    if ((self = [super init])) { _stencilCompareFunction = MTLCompareFunctionAlways; _readMask = _writeMask = 0xffffffff; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLStencilDescriptor *d = [[MTLStencilDescriptor allocWithZone:zone] init];
    d.stencilCompareFunction = _stencilCompareFunction; d.stencilFailureOperation = _stencilFailureOperation;
    d.depthFailureOperation = _depthFailureOperation; d.depthStencilPassOperation = _depthStencilPassOperation;
    d.readMask = _readMask; d.writeMask = _writeMask;
    return d;
}
- (BOOL)isim_isDefault {
    return _stencilCompareFunction == MTLCompareFunctionAlways && !_stencilFailureOperation && !_depthFailureOperation && !_depthStencilPassOperation;
}
@end
@implementation MTLDepthStencilDescriptor {
    MTLStencilDescriptor *_front, *_back;
}
- (instancetype)init { if ((self = [super init])) _depthCompareFunction = MTLCompareFunctionAlways; return self; }
- (MTLStencilDescriptor *)frontFaceStencil { if (!_front) _front = [MTLStencilDescriptor new]; return _front; }
- (MTLStencilDescriptor *)backFaceStencil { if (!_back) _back = [MTLStencilDescriptor new]; return _back; }
- (void)setFrontFaceStencil:(MTLStencilDescriptor *)s { _front = [s copy]; }
- (void)setBackFaceStencil:(MTLStencilDescriptor *)s { _back = [s copy]; }
- (id)copyWithZone:(NSZone *)zone {
    MTLDepthStencilDescriptor *d = [[MTLDepthStencilDescriptor allocWithZone:zone] init];
    d.depthCompareFunction = _depthCompareFunction; d.depthWriteEnabled = _depthWriteEnabled; d.label = _label;
    if (_front) d.frontFaceStencil = _front;
    if (_back) d.backFaceStencil = _back;
    return d;
}
@end
@interface ISIMMTLDepthStencilState : NSObject <MTLDepthStencilState> {
@public
    uint8_t _func, _write, _stencil;
    isim_mtl_stencil_face _faces[2];
}
@end
@implementation ISIMMTLDepthStencilState {
    NSString *_label;
}
static isim_mtl_stencil_face stencil_face(MTLStencilDescriptor *s) {
    return (isim_mtl_stencil_face){(uint8_t)s.stencilCompareFunction, (uint8_t)s.stencilFailureOperation, (uint8_t)s.depthFailureOperation,
                                   (uint8_t)s.depthStencilPassOperation, s.readMask, s.writeMask};
}
- (instancetype)initWithDescriptor:(MTLDepthStencilDescriptor *)d {
    if (!(self = [super init])) return nil;
    _label = [d.label copy];
    _func = (uint8_t)d.depthCompareFunction; _write = d.depthWriteEnabled;
    _faces[0] = stencil_face(d.frontFaceStencil); _faces[1] = stencil_face(d.backFaceStencil);
    _stencil = ![(id)d.frontFaceStencil isim_isDefault] || ![(id)d.backFaceStencil isim_isDefault] ||
               d.frontFaceStencil.writeMask != 0xffffffff || d.backFaceStencil.writeMask != 0xffffffff;
    return self;
}
- (NSString *)label { return _label; }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (MTLResourceID)gpuResourceID { return (MTLResourceID){(uint64_t)(uintptr_t)self}; }
@end

/* ---- render pass descriptors ---- */
@implementation MTLRenderPassAttachmentDescriptor
- (instancetype)init { if ((self = [super init])) _storeAction = MTLStoreActionStore; return self; }
- (void)isim_copyInto:(MTLRenderPassAttachmentDescriptor *)d {
    d.texture = _texture; d.level = _level; d.slice = _slice; d.depthPlane = _depthPlane;
    d.resolveTexture = _resolveTexture; d.resolveLevel = _resolveLevel; d.resolveSlice = _resolveSlice; d.resolveDepthPlane = _resolveDepthPlane;
    d.loadAction = _loadAction; d.storeAction = _storeAction; d.storeActionOptions = _storeActionOptions;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPassAttachmentDescriptor *d = [[[self class] allocWithZone:zone] init];
    [self isim_copyInto:d];
    return d;
}
@end
@implementation MTLRenderPassColorAttachmentDescriptor
- (instancetype)init { if ((self = [super init])) _clearColor = MTLClearColorMake(0, 0, 0, 1); return self; }
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPassColorAttachmentDescriptor *d = [super copyWithZone:zone];
    d.clearColor = _clearColor;
    return d;
}
@end
@implementation MTLRenderPassDepthAttachmentDescriptor
- (instancetype)init { if ((self = [super init])) _clearDepth = 1.0; return self; }
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPassDepthAttachmentDescriptor *d = [super copyWithZone:zone];
    d.clearDepth = _clearDepth; d.depthResolveFilter = _depthResolveFilter;
    return d;
}
@end
@implementation MTLRenderPassStencilAttachmentDescriptor
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPassStencilAttachmentDescriptor *d = [super copyWithZone:zone];
    d.clearStencil = _clearStencil; d.stencilResolveFilter = _stencilResolveFilter;
    return d;
}
@end
@interface MTLRenderPassColorAttachmentDescriptorArray ()
- (MTLRenderPassColorAttachmentDescriptor *)isim_existing:(NSUInteger)i;
- (void)isim_copyTo:(MTLRenderPassColorAttachmentDescriptorArray *)other;
@end
ISIM_DESCRIPTOR_ARRAY(MTLRenderPassColorAttachmentDescriptorArray, MTLRenderPassColorAttachmentDescriptor, ISIM_MTL_MAX_COLORS)

@implementation MTLRenderPassDescriptor {
    MTLRenderPassDepthAttachmentDescriptor *_depth;
    MTLRenderPassStencilAttachmentDescriptor *_stencil;
}
+ (MTLRenderPassDescriptor *)renderPassDescriptor { return [self new]; }
- (instancetype)init {
    if ((self = [super init])) { _colorAttachments = [MTLRenderPassColorAttachmentDescriptorArray new]; _renderTargetArrayLength = 0; }
    return self;
}
- (MTLRenderPassDepthAttachmentDescriptor *)depthAttachment { if (!_depth) _depth = [MTLRenderPassDepthAttachmentDescriptor new]; return _depth; }
- (MTLRenderPassStencilAttachmentDescriptor *)stencilAttachment { if (!_stencil) _stencil = [MTLRenderPassStencilAttachmentDescriptor new]; return _stencil; }
- (void)setDepthAttachment:(MTLRenderPassDepthAttachmentDescriptor *)d { _depth = [d copy]; }
- (void)setStencilAttachment:(MTLRenderPassStencilAttachmentDescriptor *)s { _stencil = [s copy]; }
- (id)copyWithZone:(NSZone *)zone {
    MTLRenderPassDescriptor *d = [[MTLRenderPassDescriptor allocWithZone:zone] init];
    [_colorAttachments isim_copyTo:d.colorAttachments];
    if (_depth) d.depthAttachment = _depth;
    if (_stencil) d.stencilAttachment = _stencil;
    d.visibilityResultBuffer = _visibilityResultBuffer; d.renderTargetArrayLength = _renderTargetArrayLength;
    d.renderTargetWidth = _renderTargetWidth; d.renderTargetHeight = _renderTargetHeight; d.defaultRasterSampleCount = _defaultRasterSampleCount;
    d.tileWidth = _tileWidth; d.tileHeight = _tileHeight; d.imageblockSampleLength = _imageblockSampleLength; d.threadgroupMemoryLength = _threadgroupMemoryLength;
    return d;
}
- (MTLRenderPassDepthAttachmentDescriptor *)isim_depth { return _depth; }
- (MTLRenderPassStencilAttachmentDescriptor *)isim_stencil { return _stencil; }
@end

/* ---- the device ---- */
@implementation ISIMMTLDevice (Render)
- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)d options:(MTLPipelineOption)options
    reflection:(MTLRenderPipelineReflection **)reflection error:(NSError **)error {
    if (reflection) *reflection = (options & (MTLPipelineOptionArgumentInfo | MTLPipelineOptionBufferTypeInfo)) ? [MTLRenderPipelineReflection new] : nil;
    return [[ISIMMTLRenderPipelineState alloc] initWithDescriptor:d error:error];
}
- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)d error:(NSError **)error {
    return [self newRenderPipelineStateWithDescriptor:d options:MTLPipelineOptionNone reflection:NULL error:error];
}
- (void)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)d completionHandler:(MTLNewRenderPipelineStateCompletionHandler)handler {
    MTLRenderPipelineDescriptor *copy = [d copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil;
        id<MTLRenderPipelineState> s = [self newRenderPipelineStateWithDescriptor:copy error:&error];
        handler(s, error);
    });
}
- (void)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)d options:(MTLPipelineOption)options
    completionHandler:(MTLNewRenderPipelineStateWithReflectionCompletionHandler)handler {
    MTLRenderPipelineDescriptor *copy = [d copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil; MTLRenderPipelineReflection *r = nil;
        id<MTLRenderPipelineState> s = [self newRenderPipelineStateWithDescriptor:copy options:options reflection:&r error:&error];
        handler(s, r, error);
    });
}
- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor:(MTLDepthStencilDescriptor *)d {
    return [[ISIMMTLDepthStencilState alloc] initWithDescriptor:d];
}
@end

/* ---- render command encoders ---- */
static isim_mtl_target target_of(ISIMMTLTexture *t, NSUInteger level, NSUInteger slice, NSUInteger plane) {
    isim_mtl_target r = {0};
    if (!t) return r;
    const __isim_mtl_texture *d = &t->_desc;
    if (level >= d->mip_levels) level = d->mip_levels - 1;
    NSUInteger layer = d->type == MTLTextureType3D ? plane : slice;
    r.base = d->levels[level] + (size_t)layer * d->level_bpi[level];
    r.bpr = d->level_bpr[level];
    r.width = MAX(d->width >> level, 1u); r.height = MAX(d->height >> level, 1u);
    r.format = d->format;
    return r;
}

@interface ISIMMTLRenderCommandEncoder : NSObject <MTLRenderCommandEncoder>
- (instancetype)initWithCommandBuffer:(ISIMMTLCommandBuffer *)cb descriptor:(MTLRenderPassDescriptor *)d;
@end

@implementation ISIMMTLRenderCommandEncoder {
    __weak ISIMMTLCommandBuffer *_cb;
    MTLRenderPassDescriptor *_pass;
    NSMutableArray *_keep;                     /* the pass's textures and buffers */
    isim_mtl_target _color[ISIM_MTL_MAX_COLORS], _depth, _stencil;
    uint32_t _width, _height;
    ISIMMTLRenderPipelineState *_pipeline;
    ISIMMTLDepthStencilState *_ds;
    id<MTLBuffer> _vbuf[ISIM_MTL_MAX_BUFFERS], _fbuf[ISIM_MTL_MAX_BUFFERS];
    NSUInteger _voff[ISIM_MTL_MAX_BUFFERS], _foff[ISIM_MTL_MAX_BUFFERS];
    NSData *_vbytes[ISIM_MTL_MAX_BUFFERS], *_fbytes[ISIM_MTL_MAX_BUFFERS];
    ISIMMTLTexture *_vtex[ISIM_MTL_MAX_TEXTURES], *_ftex[ISIM_MTL_MAX_TEXTURES];
    ISIMMTLSamplerState *_vsamp[ISIM_MTL_MAX_SAMPLERS], *_fsamp[ISIM_MTL_MAX_SAMPLERS];
    double _viewport[6];
    int32_t _scissor[4];
    uint8_t _cull, _winding, _fill, _clamp;
    float _bias, _slope, _biasClamp, _blendColor[4];
    uint32_t _ref[2];
    MTLVisibilityResultMode _visMode;
    NSUInteger _visOffset;
    BOOL _ended;
}
@synthesize label;
- (instancetype)initWithCommandBuffer:(ISIMMTLCommandBuffer *)cb descriptor:(MTLRenderPassDescriptor *)desc {
    if (!(self = [super init])) return nil;
    _cb = cb; _pass = [desc copy]; _keep = [NSMutableArray array];
    MTLRenderPassDescriptor *d = _pass;
    uint32_t w = UINT32_MAX, h = UINT32_MAX;
    for (NSUInteger i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
        MTLRenderPassColorAttachmentDescriptor *a = [d.colorAttachments isim_existing:i];
        if (!a.texture) continue;
        [_keep addObject:a.texture];
        _color[i] = target_of((ISIMMTLTexture *)a.texture, a.level, a.slice, a.depthPlane);
        w = MIN(w, _color[i].width); h = MIN(h, _color[i].height);
    }
    MTLRenderPassDepthAttachmentDescriptor *da = [(id)d isim_depth];
    MTLRenderPassStencilAttachmentDescriptor *sa = [(id)d isim_stencil];
    if (da.texture) {
        [_keep addObject:da.texture];
        _depth = target_of((ISIMMTLTexture *)da.texture, da.level, da.slice, da.depthPlane);
        w = MIN(w, _depth.width); h = MIN(h, _depth.height);
    }
    if (sa.texture) {
        [_keep addObject:sa.texture];
        _stencil = target_of((ISIMMTLTexture *)sa.texture, sa.level, sa.slice, sa.depthPlane);
        w = MIN(w, _stencil.width); h = MIN(h, _stencil.height);
    }
    if (w == UINT32_MAX) { w = (uint32_t)d.renderTargetWidth; h = (uint32_t)d.renderTargetHeight; }
    _width = w; _height = h;
    double vp[6] = {0, 0, w, h, 0, 1};
    memcpy(_viewport, vp, sizeof vp);
    _scissor[0] = _scissor[1] = 0; _scissor[2] = (int32_t)w; _scissor[3] = (int32_t)h;
    _blendColor[0] = _blendColor[1] = _blendColor[2] = _blendColor[3] = 0;
    if (d.visibilityResultBuffer) [_keep addObject:d.visibilityResultBuffer];
    /* load actions */
    struct { isim_mtl_target color[ISIM_MTL_MAX_COLORS]; float clear[ISIM_MTL_MAX_COLORS][4]; BOOL clears[ISIM_MTL_MAX_COLORS]; } L;
    memset(&L, 0, sizeof L);
    for (NSUInteger i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
        L.color[i] = _color[i];
        MTLRenderPassColorAttachmentDescriptor *a = [d.colorAttachments isim_existing:i];
        if (a.texture && a.loadAction == MTLLoadActionClear) {
            L.clears[i] = YES;
            MTLClearColor c = a.clearColor;
            L.clear[i][0] = (float)c.red; L.clear[i][1] = (float)c.green; L.clear[i][2] = (float)c.blue; L.clear[i][3] = (float)c.alpha;
        }
    }
    isim_mtl_target depth = _depth, stencil = _stencil;
    BOOL clearDepth = da.texture && da.loadAction == MTLLoadActionClear, clearStencil = sa.texture && sa.loadAction == MTLLoadActionClear;
    float z = (float)da.clearDepth;
    uint8_t s = (uint8_t)sa.clearStencil;
    NSArray *keep = [_keep copy];
    [cb addCommand:^{
        (void)keep;
        for (int i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
            if (!L.clears[i]) continue;
            uint8_t texel[16];
            uint32_t bpp = isim_mtl_bpp(L.color[i].format);
            isim_mtl_pack(L.color[i].format, texel, L.clear[i]);
            isim_mtl_fill(&L.color[i], texel, bpp);
        }
        if (clearDepth)
            for (uint32_t y = 0; y < depth.height; y++)
                for (uint32_t x = 0; x < depth.width; x++)
                    isim_mtl_depth_set(depth.format, depth.base + (size_t)y * depth.bpr + (size_t)x * isim_mtl_bpp(depth.format), z);
        if (clearStencil)
            for (uint32_t y = 0; y < stencil.height; y++)
                for (uint32_t x = 0; x < stencil.width; x++) {
                    uint8_t *p = isim_mtl_stencil_at(stencil.format, stencil.base + (size_t)y * stencil.bpr + (size_t)x * isim_mtl_bpp(stencil.format));
                    if (p) *p = s;
                }
    }];
    return self;
}
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (void)setRenderPipelineState:(id<MTLRenderPipelineState>)s { _pipeline = (ISIMMTLRenderPipelineState *)s; }

#define BUFFER_SETTERS(Stage, buf, off, bytes) \
- (void)set##Stage##Bytes:(const void *)p length:(NSUInteger)n atIndex:(NSUInteger)i { \
    if (i < ISIM_MTL_MAX_BUFFERS) { bytes[i] = [NSData dataWithBytes:p length:n]; buf[i] = nil; off[i] = 0; } \
} \
- (void)set##Stage##Buffer:(id<MTLBuffer>)b offset:(NSUInteger)o atIndex:(NSUInteger)i { \
    if (i < ISIM_MTL_MAX_BUFFERS) { buf[i] = b; off[i] = o; bytes[i] = nil; } \
} \
- (void)set##Stage##BufferOffset:(NSUInteger)o atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_BUFFERS) off[i] = o; } \
- (void)set##Stage##Buffers:(const id<MTLBuffer> __strong *)b offsets:(const NSUInteger *)o withRange:(NSRange)r { \
    for (NSUInteger k = 0; k < r.length; k++) [self set##Stage##Buffer:b[k] offset:o[k] atIndex:r.location + k]; \
}
BUFFER_SETTERS(Vertex, _vbuf, _voff, _vbytes)
BUFFER_SETTERS(Fragment, _fbuf, _foff, _fbytes)
- (void)setVertexTexture:(id<MTLTexture>)t atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_TEXTURES) _vtex[i] = (ISIMMTLTexture *)t; }
- (void)setFragmentTexture:(id<MTLTexture>)t atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_TEXTURES) _ftex[i] = (ISIMMTLTexture *)t; }
- (void)setVertexTextures:(const id<MTLTexture> __strong *)t withRange:(NSRange)r { for (NSUInteger k = 0; k < r.length; k++) [self setVertexTexture:t[k] atIndex:r.location + k]; }
- (void)setFragmentTextures:(const id<MTLTexture> __strong *)t withRange:(NSRange)r { for (NSUInteger k = 0; k < r.length; k++) [self setFragmentTexture:t[k] atIndex:r.location + k]; }
- (void)setVertexSamplerState:(id<MTLSamplerState>)s atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_SAMPLERS) _vsamp[i] = (ISIMMTLSamplerState *)s; }
- (void)setFragmentSamplerState:(id<MTLSamplerState>)s atIndex:(NSUInteger)i { if (i < ISIM_MTL_MAX_SAMPLERS) _fsamp[i] = (ISIMMTLSamplerState *)s; }
- (void)setVertexSamplerStates:(const id<MTLSamplerState> __strong *)s withRange:(NSRange)r {
    for (NSUInteger k = 0; k < r.length; k++) [self setVertexSamplerState:s[k] atIndex:r.location + k];
}
- (void)setFragmentSamplerStates:(const id<MTLSamplerState> __strong *)s withRange:(NSRange)r {
    for (NSUInteger k = 0; k < r.length; k++) [self setFragmentSamplerState:s[k] atIndex:r.location + k];
}
- (void)setViewport:(MTLViewport)v {
    _viewport[0] = v.originX; _viewport[1] = v.originY; _viewport[2] = v.width; _viewport[3] = v.height; _viewport[4] = v.znear; _viewport[5] = v.zfar;
}
- (void)setViewports:(const MTLViewport *)v count:(NSUInteger)n { if (n) [self setViewport:v[0]]; }
- (void)setScissorRect:(MTLScissorRect)r { _scissor[0] = (int32_t)r.x; _scissor[1] = (int32_t)r.y; _scissor[2] = (int32_t)r.width; _scissor[3] = (int32_t)r.height; }
- (void)setScissorRects:(const MTLScissorRect *)r count:(NSUInteger)n { if (n) [self setScissorRect:r[0]]; }
- (void)setFrontFacingWinding:(MTLWinding)w { _winding = (uint8_t)w; }
- (void)setCullMode:(MTLCullMode)m { _cull = (uint8_t)m; }
- (void)setDepthClipMode:(MTLDepthClipMode)m { _clamp = (uint8_t)m; }
- (void)setDepthBias:(float)b slopeScale:(float)s clamp:(float)c { _bias = b; _slope = s; _biasClamp = c; }
- (void)setTriangleFillMode:(MTLTriangleFillMode)m { _fill = (uint8_t)m; }
- (void)setBlendColorRed:(float)r green:(float)g blue:(float)b alpha:(float)a { _blendColor[0] = r; _blendColor[1] = g; _blendColor[2] = b; _blendColor[3] = a; }
- (void)setDepthStencilState:(id<MTLDepthStencilState>)s { _ds = (ISIMMTLDepthStencilState *)s; }
- (void)setStencilReferenceValue:(uint32_t)v { _ref[0] = _ref[1] = v; }
- (void)setStencilFrontReferenceValue:(uint32_t)f backReferenceValue:(uint32_t)b { _ref[0] = f; _ref[1] = b; }
- (void)setVisibilityResultMode:(MTLVisibilityResultMode)m offset:(NSUInteger)o { _visMode = m; _visOffset = o; }
- (void)useResource:(id<MTLResource>)r usage:(MTLResourceUsage)u stages:(MTLRenderStages)s {}
- (void)useResources:(const id<MTLResource> __strong *)r count:(NSUInteger)n usage:(MTLResourceUsage)u stages:(MTLRenderStages)s {}
- (void)memoryBarrierWithScope:(MTLBarrierScope)scope afterStages:(MTLRenderStages)a beforeStages:(MTLRenderStages)b {}
- (void)textureBarrier {}

/* the stage's bindings as kernel-style arguments, keeping what they point to alive */
static void bind_stage(__isim_mtl_args *a, NSMutableArray *keep, __strong id<MTLBuffer> *buf, NSUInteger *off, __strong NSData **bytes,
                       __strong ISIMMTLTexture **tex, __strong ISIMMTLSamplerState **samp) {
    for (int i = 0; i < ISIM_MTL_MAX_BUFFERS; i++) {
        if (bytes[i]) { [keep addObject:bytes[i]]; a->buffers[i] = (void *)bytes[i].bytes; }
        else if (buf[i]) { [keep addObject:buf[i]]; a->buffers[i] = (uint8_t *)buf[i].contents + off[i]; }
    }
    for (int i = 0; i < ISIM_MTL_MAX_TEXTURES; i++) if (tex[i]) { [keep addObject:tex[i]]; a->textures[i] = &tex[i]->_desc; }
    for (int i = 0; i < ISIM_MTL_MAX_SAMPLERS; i++) if (samp[i]) { [keep addObject:samp[i]]; a->samplers[i] = &samp[i]->_desc; }
}

/* records a draw with the current state; resolve, if set, fills in what an indirect buffer holds when it runs */
- (void)recordDraw:(MTLPrimitiveType)type start:(NSUInteger)start count:(NSUInteger)count instances:(NSUInteger)instances baseInstance:(NSUInteger)baseInstance
         baseVertex:(NSInteger)baseVertex indexType:(MTLIndexType)indexType indexBuffer:(id<MTLBuffer>)ib indexOffset:(NSUInteger)ibOffset
            resolve:(void (^)(isim_mtl_draw *))resolve {
    ISIMMTLRenderPipelineState *pipeline = _pipeline;
    if (!pipeline) { NSLog(@"isim Metal: draw without a render pipeline state"); return; }
    NSMutableArray *keep = [NSMutableArray arrayWithObjects:pipeline, nil];
    [keep addObjectsFromArray:_keep];
    if (_ds) [keep addObject:_ds];
    if (ib) [keep addObject:ib];
    isim_mtl_draw *d = calloc(1, sizeof *d);
    d->p = &pipeline->_p;
    bind_stage(&d->vargs, keep, _vbuf, _voff, _vbytes, _vtex, _vsamp);
    bind_stage(&d->fargs, keep, _fbuf, _foff, _fbytes, _ftex, _fsamp);
    d->constant_value = isim_mtl_constant_value;
    memcpy(d->viewport, _viewport, sizeof _viewport);
    memcpy(d->scissor, _scissor, sizeof _scissor);
    d->cull = _cull; d->winding = _winding; d->fill = _fill; d->depth_clamp = _clamp;
    d->depth_bias = _bias; d->depth_slope = _slope; d->depth_bias_clamp = _biasClamp;
    memcpy(d->blend_color, _blendColor, sizeof _blendColor);
    if (_ds) {
        d->depth_func = _ds->_func; d->depth_write = _ds->_write; d->stencil_on = _ds->_stencil;
        d->stencil[0] = _ds->_faces[0]; d->stencil[1] = _ds->_faces[1];
    } else {
        d->depth_func = MTLCompareFunctionAlways;
    }
    d->stencil_ref[0] = _ref[0]; d->stencil_ref[1] = _ref[1];
    d->prim = (uint8_t)type;
    d->start = (uint32_t)start; d->count = (uint32_t)count; d->instances = (uint32_t)instances;
    d->base_instance = (uint32_t)baseInstance; d->base_vertex = (int32_t)baseVertex;
    if (ib) d->index_size = indexType == MTLIndexTypeUInt16 ? 2 : 4;
    memcpy(d->color, _color, sizeof _color);
    d->depth = _depth; d->stencil_t = _stencil;
    if (!d->stencil_t.base && _depth.base && isim_mtl_stencil_at(_depth.format, _depth.base)) d->stencil_t = _depth;
    d->width = _width; d->height = _height;
    id<MTLBuffer> vis = _visMode != MTLVisibilityResultModeDisabled ? _pass.visibilityResultBuffer : nil;
    NSUInteger visOffset = _visOffset;
    d->visibility_count = _visMode == MTLVisibilityResultModeCounting;
    [_cb addCommand:^{
        (void)keep;
        if (ib) d->indices = (const uint8_t *)ib.contents + ibOffset;
        if (vis) d->visibility = (uint64_t *)((uint8_t *)vis.contents + visOffset);
        if (resolve) resolve(d);
        if (d->indices || !ib) isim_mtl_draw_run(d);
        free(d);
    }];
}
- (void)drawPrimitives:(MTLPrimitiveType)t vertexStart:(NSUInteger)s vertexCount:(NSUInteger)n {
    [self recordDraw:t start:s count:n instances:1 baseInstance:0 baseVertex:0 indexType:0 indexBuffer:nil indexOffset:0 resolve:nil];
}
- (void)drawPrimitives:(MTLPrimitiveType)t vertexStart:(NSUInteger)s vertexCount:(NSUInteger)n instanceCount:(NSUInteger)i {
    [self recordDraw:t start:s count:n instances:i baseInstance:0 baseVertex:0 indexType:0 indexBuffer:nil indexOffset:0 resolve:nil];
}
- (void)drawPrimitives:(MTLPrimitiveType)t vertexStart:(NSUInteger)s vertexCount:(NSUInteger)n instanceCount:(NSUInteger)i baseInstance:(NSUInteger)b {
    [self recordDraw:t start:s count:n instances:i baseInstance:b baseVertex:0 indexType:0 indexBuffer:nil indexOffset:0 resolve:nil];
}
- (void)drawPrimitives:(MTLPrimitiveType)t indirectBuffer:(id<MTLBuffer>)buffer indirectBufferOffset:(NSUInteger)offset {
    [self recordDraw:t start:0 count:0 instances:0 baseInstance:0 baseVertex:0 indexType:0 indexBuffer:nil indexOffset:0 resolve:^(isim_mtl_draw *d) {
        MTLDrawPrimitivesIndirectArguments a;
        memcpy(&a, (const uint8_t *)buffer.contents + offset, sizeof a);
        d->start = a.vertexStart; d->count = a.vertexCount; d->instances = a.instanceCount; d->base_instance = a.baseInstance;
    }];
}
- (void)drawIndexedPrimitives:(MTLPrimitiveType)t indexCount:(NSUInteger)n indexType:(MTLIndexType)it indexBuffer:(id<MTLBuffer>)ib indexBufferOffset:(NSUInteger)o {
    [self recordDraw:t start:0 count:n instances:1 baseInstance:0 baseVertex:0 indexType:it indexBuffer:ib indexOffset:o resolve:nil];
}
- (void)drawIndexedPrimitives:(MTLPrimitiveType)t indexCount:(NSUInteger)n indexType:(MTLIndexType)it indexBuffer:(id<MTLBuffer>)ib
            indexBufferOffset:(NSUInteger)o instanceCount:(NSUInteger)i {
    [self recordDraw:t start:0 count:n instances:i baseInstance:0 baseVertex:0 indexType:it indexBuffer:ib indexOffset:o resolve:nil];
}
- (void)drawIndexedPrimitives:(MTLPrimitiveType)t indexCount:(NSUInteger)n indexType:(MTLIndexType)it indexBuffer:(id<MTLBuffer>)ib
            indexBufferOffset:(NSUInteger)o instanceCount:(NSUInteger)i baseVertex:(NSInteger)bv baseInstance:(NSUInteger)bi {
    [self recordDraw:t start:0 count:n instances:i baseInstance:bi baseVertex:bv indexType:it indexBuffer:ib indexOffset:o resolve:nil];
}
- (void)drawIndexedPrimitives:(MTLPrimitiveType)t indexType:(MTLIndexType)it indexBuffer:(id<MTLBuffer>)ib indexBufferOffset:(NSUInteger)o
               indirectBuffer:(id<MTLBuffer>)buffer indirectBufferOffset:(NSUInteger)offset {
    NSUInteger isize = it == MTLIndexTypeUInt16 ? 2 : 4;
    [self recordDraw:t start:0 count:0 instances:0 baseInstance:0 baseVertex:0 indexType:it indexBuffer:ib indexOffset:o resolve:^(isim_mtl_draw *d) {
        MTLDrawIndexedPrimitivesIndirectArguments a;
        memcpy(&a, (const uint8_t *)buffer.contents + offset, sizeof a);
        d->indices += a.indexStart * isize;
        d->count = a.indexCount; d->instances = a.instanceCount; d->base_vertex = a.baseVertex; d->base_instance = a.baseInstance;
    }];
}

/* store actions: multisample attachments are resolved by copying (they hold one sample per pixel) */
- (void)endEncoding {
    if (_ended) return;
    _ended = YES;
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSUInteger i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
        MTLRenderPassColorAttachmentDescriptor *a = [_pass.colorAttachments isim_existing:i];
        if (a.texture && a.resolveTexture && (a.storeAction == MTLStoreActionMultisampleResolve || a.storeAction == MTLStoreActionStoreAndMultisampleResolve))
            [pairs addObject:a];
    }
    MTLRenderPassDepthAttachmentDescriptor *da = [(id)_pass isim_depth];
    if (da.texture && da.resolveTexture && (da.storeAction == MTLStoreActionMultisampleResolve || da.storeAction == MTLStoreActionStoreAndMultisampleResolve))
        [pairs addObject:da];
    if (pairs.count)
        [_cb addCommand:^{
            for (MTLRenderPassAttachmentDescriptor *a in pairs) {
                isim_mtl_target s = target_of((ISIMMTLTexture *)a.texture, a.level, a.slice, a.depthPlane);
                isim_mtl_target t = target_of((ISIMMTLTexture *)a.resolveTexture, a.resolveLevel, a.resolveSlice, a.resolveDepthPlane);
                uint32_t w = MIN(s.width, t.width), h = MIN(s.height, t.height), bs = isim_mtl_bpp(s.format), bt = isim_mtl_bpp(t.format);
                for (uint32_t y = 0; y < h; y++)
                    for (uint32_t x = 0; x < w; x++) {
                        if (s.format == t.format) { memcpy(t.base + (size_t)y * t.bpr + (size_t)x * bt, s.base + (size_t)y * s.bpr + (size_t)x * bs, bs); continue; }
                        float c[4];
                        isim_mtl_unpack(s.format, s.base + (size_t)y * s.bpr + (size_t)x * bs, c);
                        isim_mtl_pack(t.format, t.base + (size_t)y * t.bpr + (size_t)x * bt, c);
                    }
            }
        }];
    [_cb encoderEnded];
}
- (void)insertDebugSignpost:(NSString *)string {}
- (void)pushDebugGroup:(NSString *)string {}
- (void)popDebugGroup {}
@end

id<MTLRenderCommandEncoder> isim_mtl_render_encoder(ISIMMTLCommandBuffer *cb, MTLRenderPassDescriptor *d) {
    return [[ISIMMTLRenderCommandEncoder alloc] initWithCommandBuffer:cb descriptor:d];
}
