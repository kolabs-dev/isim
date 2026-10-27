/* isim Metal: the device, buffers, textures and samplers (issue #328). Adapted: the device is the CPU ("isim CPU"),
 * resources live in the process's memory in every storage mode, and textures are linear (rows of texels, mip levels
 * and slices one after another) in the layout kernels read (isim_metal_abi.h). */
#import "MTLPrivate.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

NSErrorDomain const MTLLibraryErrorDomain = @"MTLLibraryErrorDomain";
NSErrorDomain const MTLCommandBufferErrorDomain = @"MTLCommandBufferErrorDomain";

NSError *isim_mtl_error(NSErrorDomain domain, NSInteger code, NSString *message) {
    return [NSError errorWithDomain:domain code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

isim_mtl_format_info isim_mtl_format(MTLPixelFormat f) {
    switch (f) {
    case MTLPixelFormatA8Unorm: case MTLPixelFormatR8Unorm: case MTLPixelFormatR8Unorm_sRGB: case MTLPixelFormatR8Snorm:
    case MTLPixelFormatR8Uint: case MTLPixelFormatR8Sint: case MTLPixelFormatStencil8:
        return (isim_mtl_format_info){1, 1, 1};
    case MTLPixelFormatR16Unorm: case MTLPixelFormatR16Snorm: case MTLPixelFormatR16Uint: case MTLPixelFormatR16Sint: case MTLPixelFormatR16Float:
    case MTLPixelFormatRG8Unorm: case MTLPixelFormatRG8Unorm_sRGB: case MTLPixelFormatRG8Snorm: case MTLPixelFormatRG8Uint: case MTLPixelFormatRG8Sint:
    case MTLPixelFormatB5G6R5Unorm: case MTLPixelFormatA1BGR5Unorm: case MTLPixelFormatABGR4Unorm: case MTLPixelFormatBGR5A1Unorm:
    case MTLPixelFormatDepth16Unorm:
        return (isim_mtl_format_info){2, 1, 1};
    case MTLPixelFormatRG16Unorm: case MTLPixelFormatRG16Snorm: case MTLPixelFormatRG16Uint: case MTLPixelFormatRG16Sint: case MTLPixelFormatRG16Float:
    case MTLPixelFormatR32Uint: case MTLPixelFormatR32Sint: case MTLPixelFormatR32Float:
    case MTLPixelFormatRGBA8Unorm: case MTLPixelFormatRGBA8Unorm_sRGB: case MTLPixelFormatRGBA8Snorm: case MTLPixelFormatRGBA8Uint: case MTLPixelFormatRGBA8Sint:
    case MTLPixelFormatBGRA8Unorm: case MTLPixelFormatBGRA8Unorm_sRGB:
    case MTLPixelFormatRGB10A2Unorm: case MTLPixelFormatRGB10A2Uint: case MTLPixelFormatRG11B10Float: case MTLPixelFormatRGB9E5Float:
    case MTLPixelFormatBGR10A2Unorm: case MTLPixelFormatBGR10_XR: case MTLPixelFormatBGR10_XR_sRGB: case MTLPixelFormatDepth32Float:
    case MTLPixelFormatGBGR422: case MTLPixelFormatBGRG422:
        return (isim_mtl_format_info){4, 1, 1};
    case MTLPixelFormatRG32Uint: case MTLPixelFormatRG32Sint: case MTLPixelFormatRG32Float:
    case MTLPixelFormatRGBA16Unorm: case MTLPixelFormatRGBA16Snorm: case MTLPixelFormatRGBA16Uint: case MTLPixelFormatRGBA16Sint: case MTLPixelFormatRGBA16Float:
    case MTLPixelFormatBGRA10_XR: case MTLPixelFormatBGRA10_XR_sRGB: case MTLPixelFormatDepth32Float_Stencil8: case MTLPixelFormatX32_Stencil8:
        return (isim_mtl_format_info){8, 1, 1};
    case MTLPixelFormatRGBA32Uint: case MTLPixelFormatRGBA32Sint: case MTLPixelFormatRGBA32Float:
        return (isim_mtl_format_info){16, 1, 1};
    case MTLPixelFormatBC1_RGBA: case MTLPixelFormatBC1_RGBA_sRGB: case MTLPixelFormatBC4_RUnorm: case MTLPixelFormatBC4_RSnorm:
    case MTLPixelFormatETC2_RGB8: case MTLPixelFormatETC2_RGB8_sRGB: case MTLPixelFormatETC2_RGB8A1: case MTLPixelFormatETC2_RGB8A1_sRGB:
    case MTLPixelFormatEAC_R11Unorm: case MTLPixelFormatEAC_R11Snorm:
        return (isim_mtl_format_info){8, 4, 4};
    case MTLPixelFormatBC2_RGBA: case MTLPixelFormatBC2_RGBA_sRGB: case MTLPixelFormatBC3_RGBA: case MTLPixelFormatBC3_RGBA_sRGB:
    case MTLPixelFormatBC5_RGUnorm: case MTLPixelFormatBC5_RGSnorm: case MTLPixelFormatBC6H_RGBFloat: case MTLPixelFormatBC6H_RGBUfloat:
    case MTLPixelFormatBC7_RGBAUnorm: case MTLPixelFormatBC7_RGBAUnorm_sRGB: case MTLPixelFormatEAC_RG11Unorm: case MTLPixelFormatEAC_RG11Snorm:
    case MTLPixelFormatEAC_RGBA8: case MTLPixelFormatEAC_RGBA8_sRGB:
    case MTLPixelFormatASTC_4x4_sRGB: case MTLPixelFormatASTC_4x4_LDR: case MTLPixelFormatASTC_4x4_HDR:
        return (isim_mtl_format_info){16, 4, 4};
    case MTLPixelFormatASTC_8x8_sRGB: case MTLPixelFormatASTC_8x8_LDR: case MTLPixelFormatASTC_8x8_HDR:
        return (isim_mtl_format_info){16, 8, 8};
    default:
        return (isim_mtl_format_info){0, 1, 1};
    }
}

static NSUInteger allocated;   /* bytes of buffers and textures alive (currentAllocatedSize) */

/* ---- device ---- */
@implementation ISIMMTLDevice
+ (instancetype)shared {
    static ISIMMTLDevice *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [ISIMMTLDevice new]; });
    return d;
}
- (NSString *)name { return @"isim CPU"; }
- (uint64_t)registryID { return 0x15153; }
- (MTLSize)maxThreadsPerThreadgroup { return MTLSizeMake(1024, 1024, 1024); }
- (BOOL)hasUnifiedMemory { return YES; }
- (uint64_t)recommendedMaxWorkingSetSize {
    long pages = sysconf(_SC_PHYS_PAGES), size = sysconf(_SC_PAGESIZE);
    return pages > 0 && size > 0 ? (uint64_t)pages * (uint64_t)size / 2 : (1ull << 31);
}
- (NSUInteger)currentAllocatedSize { return __atomic_load_n(&allocated, __ATOMIC_RELAXED); }
- (NSUInteger)maxThreadgroupMemoryLength { return 32768; }
- (NSUInteger)maxArgumentBufferSamplerCount { return 16; }
- (NSUInteger)maxBufferLength { return (NSUInteger)1 << 32; }
- (BOOL)areProgrammableSamplePositionsSupported { return NO; }
- (BOOL)areRasterOrderGroupsSupported { return NO; }
- (BOOL)supportsDynamicLibraries { return NO; }
- (BOOL)supportsFunctionPointers { return NO; }
- (BOOL)supports32BitFloatFiltering { return YES; }
- (BOOL)supports32BitMSAA { return NO; }
- (BOOL)supportsBCTextureCompression { return NO; }
- (BOOL)supportsRaytracing { return NO; }
- (BOOL)supportsShaderBarycentricCoordinates { return NO; }
- (MTLReadWriteTextureTier)readWriteTextureSupport { return MTLReadWriteTextureTier2; }
- (MTLArgumentBuffersTier)argumentBuffersSupport { return MTLArgumentBuffersTier1; }
/* the families whose compute features isim has: non-uniform threadgroups, read-write textures, atomics */
- (BOOL)supportsFamily:(MTLGPUFamily)family {
    return (family >= MTLGPUFamilyApple1 && family <= MTLGPUFamilyApple4) || family == MTLGPUFamilyCommon1 || family == MTLGPUFamilyCommon2;
}
/* multisample textures hold one sample per pixel on isim: rendering to them is not antialiased (adapted) */
- (BOOL)supportsTextureSampleCount:(NSUInteger)n { return n == 1 || n == 2 || n == 4; }
- (NSUInteger)minimumLinearTextureAlignmentForPixelFormat:(MTLPixelFormat)f { return 16; }
- (NSUInteger)minimumTextureBufferAlignmentForPixelFormat:(MTLPixelFormat)f { return 16; }
@end

MTL_EXTERN id<MTLDevice> MTLCreateSystemDefaultDevice(void) { return [ISIMMTLDevice shared]; }

/* ---- buffers ---- */
@implementation ISIMMTLBuffer {
    void *_bytes;
    NSUInteger _length;
    MTLResourceOptions _options;
    void (^_deallocator)(void *, NSUInteger);
    BOOL _owned;
}
@synthesize label;
- (instancetype)initWithLength:(NSUInteger)length options:(MTLResourceOptions)options bytes:(const void *)bytes {
    if (!(self = [super init])) return nil;
    _length = length; _options = options; _owned = YES;
    if (posix_memalign(&_bytes, 64, length ? length : 1) != 0) return nil;
    if (bytes) memcpy(_bytes, bytes, length); else memset(_bytes, 0, length);
    __atomic_add_fetch(&allocated, length, __ATOMIC_RELAXED);
    return self;
}
- (instancetype)initNoCopy:(void *)p length:(NSUInteger)length options:(MTLResourceOptions)options deallocator:(void (^)(void *, NSUInteger))d {
    if (!(self = [super init])) return nil;
    _bytes = p; _length = length; _options = options; _deallocator = [d copy];
    return self;
}
- (void)dealloc {
    if (_owned) { free(_bytes); __atomic_sub_fetch(&allocated, _length, __ATOMIC_RELAXED); }
    else if (_deallocator) _deallocator(_bytes, _length);
}
- (NSUInteger)length { return _length; }
- (void *)contents { return _bytes; }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (MTLCPUCacheMode)cpuCacheMode { return (MTLCPUCacheMode)(_options & 0xf); }
- (MTLStorageMode)storageMode { return (MTLStorageMode)((_options >> MTLResourceStorageModeShift) & 0xf); }
- (MTLHazardTrackingMode)hazardTrackingMode { return (MTLHazardTrackingMode)((_options >> MTLResourceHazardTrackingModeShift) & 0x3); }
- (MTLResourceOptions)resourceOptions { return _options; }
- (MTLPurgeableState)setPurgeableState:(MTLPurgeableState)state { return MTLPurgeableStateNonVolatile; }
- (id<MTLHeap>)heap { return nil; }
- (NSUInteger)heapOffset { return 0; }
- (NSUInteger)allocatedSize { return _length; }
- (void)makeAliasable {}
- (BOOL)isAliasable { return NO; }
- (uint64_t)gpuAddress { return (uint64_t)(uintptr_t)_bytes; }
- (void)addDebugMarker:(NSString *)marker range:(NSRange)range {}
- (void)removeAllDebugMarkers {}
- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)d offset:(NSUInteger)offset bytesPerRow:(NSUInteger)bpr {
    return [[ISIMMTLTexture alloc] initWithDescriptor:d buffer:self offset:offset bytesPerRow:bpr];
}
@end

/* ---- texture descriptors ---- */
@implementation MTLTextureDescriptor
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _textureType = MTLTextureType2D; _pixelFormat = MTLPixelFormatRGBA8Unorm; _width = _height = _depth = 1;
    _mipmapLevelCount = 1; _sampleCount = 1; _arrayLength = 1; _usage = MTLTextureUsageShaderRead; _allowGPUOptimizedContents = YES;
    _swizzle = MTLTextureSwizzleChannelsDefault;
    return self;
}
+ (MTLTextureDescriptor *)texture2DDescriptorWithPixelFormat:(MTLPixelFormat)f width:(NSUInteger)w height:(NSUInteger)h mipmapped:(BOOL)m {
    MTLTextureDescriptor *d = [self new];
    d.pixelFormat = f; d.width = w; d.height = h;
    if (m) { NSUInteger n = 1, s = MAX(w, h); while (s > 1) { s >>= 1; n++; } d.mipmapLevelCount = n; }
    return d;
}
+ (MTLTextureDescriptor *)textureCubeDescriptorWithPixelFormat:(MTLPixelFormat)f size:(NSUInteger)size mipmapped:(BOOL)m {
    MTLTextureDescriptor *d = [self texture2DDescriptorWithPixelFormat:f width:size height:size mipmapped:m];
    d.textureType = MTLTextureTypeCube;
    return d;
}
+ (MTLTextureDescriptor *)textureBufferDescriptorWithPixelFormat:(MTLPixelFormat)f width:(NSUInteger)w resourceOptions:(MTLResourceOptions)o usage:(MTLTextureUsage)u {
    MTLTextureDescriptor *d = [self new];
    d.textureType = MTLTextureTypeTextureBuffer; d.pixelFormat = f; d.width = w; d.resourceOptions = o; d.usage = u;
    return d;
}
- (void)setResourceOptions:(MTLResourceOptions)o {
    _resourceOptions = o;
    _cpuCacheMode = (MTLCPUCacheMode)(o & 0xf);
    _storageMode = (MTLStorageMode)((o >> MTLResourceStorageModeShift) & 0xf);
    _hazardTrackingMode = (MTLHazardTrackingMode)((o >> MTLResourceHazardTrackingModeShift) & 0x3);
}
- (void)setStorageMode:(MTLStorageMode)m { _storageMode = m; _resourceOptions = (_resourceOptions & ~(0xfUL << MTLResourceStorageModeShift)) | (m << MTLResourceStorageModeShift); }
- (void)setCpuCacheMode:(MTLCPUCacheMode)m { _cpuCacheMode = m; _resourceOptions = (_resourceOptions & ~0xfUL) | m; }
- (id)copyWithZone:(NSZone *)zone {
    MTLTextureDescriptor *d = [[MTLTextureDescriptor allocWithZone:zone] init];
    d.textureType = _textureType; d.pixelFormat = _pixelFormat; d.width = _width; d.height = _height; d.depth = _depth;
    d.mipmapLevelCount = _mipmapLevelCount; d.sampleCount = _sampleCount; d.arrayLength = _arrayLength; d.resourceOptions = _resourceOptions;
    d.usage = _usage; d.allowGPUOptimizedContents = _allowGPUOptimizedContents; d.compressionType = _compressionType; d.swizzle = _swizzle;
    return d;
}
@end

/* ---- textures ---- */
@implementation ISIMMTLTexture {
    uint8_t *_storage;
    size_t _size;
    MTLTextureDescriptor *_d;
    id<MTLBuffer> _buffer;
    NSUInteger _bufferOffset, _bufferBytesPerRow;
    id<MTLTexture> _parent;
    NSUInteger _relativeLevel, _relativeSlice;
}
@synthesize label;
static NSUInteger slices_of(MTLTextureDescriptor *d) {
    NSUInteger s = MAX(d.arrayLength, (NSUInteger)1);
    return d.textureType == MTLTextureTypeCube || d.textureType == MTLTextureTypeCubeArray ? 6 * s : s;
}
- (void)layOut:(uint8_t *)base bytesPerRow:(NSUInteger)fixedBpr {
    isim_mtl_format_info fi = isim_mtl_format(_d.pixelFormat);
    NSUInteger slices = slices_of(_d);
    size_t off = 0;
    for (NSUInteger l = 0; l < _desc.mip_levels; l++) {
        NSUInteger w = MAX(_d.width >> l, (NSUInteger)1), h = MAX(_d.height >> l, (NSUInteger)1), dp = MAX(_d.depth >> l, (NSUInteger)1);
        NSUInteger bw = (w + fi.block_w - 1) / fi.block_w, bh = (h + fi.block_h - 1) / fi.block_h;
        NSUInteger bpr = fixedBpr && l == 0 ? fixedBpr : bw * (fi.bytes ? fi.bytes : 4);
        _desc.level_bpr[l] = (uint32_t)bpr;
        _desc.level_bpi[l] = (uint32_t)(bpr * bh);
        _desc.levels[l] = base ? base + off : NULL;
        off += (size_t)bpr * bh * (_d.textureType == MTLTextureType3D ? dp : slices);
    }
    _size = off;
}
- (instancetype)initWithDescriptor:(MTLTextureDescriptor *)d buffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset bytesPerRow:(NSUInteger)bpr {
    if (!(self = [super init])) return nil;
    if (!d.width || !d.height || !d.depth) return nil;
    _d = [d copy];
    _desc.type = (uint32_t)d.textureType; _desc.format = (uint32_t)d.pixelFormat;
    _desc.width = (uint32_t)d.width; _desc.height = (uint32_t)d.height; _desc.depth = (uint32_t)d.depth;
    _desc.array_length = (uint32_t)slices_of(d);
    _desc.mip_levels = (uint32_t)MIN(MAX(d.mipmapLevelCount, (NSUInteger)1), (NSUInteger)ISIM_MTL_MAX_LEVELS);
    if (buffer) {
        _buffer = buffer; _bufferOffset = offset; _bufferBytesPerRow = bpr; _desc.mip_levels = 1;
        [self layOut:(uint8_t *)buffer.contents + offset bytesPerRow:bpr];
    } else {
        [self layOut:NULL bytesPerRow:0];
        _storage = calloc(1, _size ? _size : 1);
        if (!_storage) return nil;
        [self layOut:_storage bytesPerRow:0];
        __atomic_add_fetch(&allocated, _size, __ATOMIC_RELAXED);
    }
    return self;
}
- (instancetype)initViewOf:(ISIMMTLTexture *)parent format:(MTLPixelFormat)f {
    if (!(self = [super init])) return nil;
    _parent = parent; _d = [parent->_d copy]; _d.pixelFormat = f;
    _desc = parent->_desc; _desc.format = (uint32_t)f; _size = parent->_size;
    return self;
}
/* a view of some mip levels and slices: it shares the parent's memory, from the first level and slice (issue #365) */
- (instancetype)initViewOf:(ISIMMTLTexture *)parent format:(MTLPixelFormat)f type:(MTLTextureType)type levels:(NSRange)levels slices:(NSRange)slices {
    if (!(self = [self initViewOf:parent format:f])) return nil;
    _d.textureType = type;
    _d.width = MAX(parent->_d.width >> levels.location, (NSUInteger)1); _d.height = MAX(parent->_d.height >> levels.location, (NSUInteger)1);
    _d.arrayLength = slices.length; _d.mipmapLevelCount = levels.length;
    _desc.type = (uint32_t)type; _desc.width = (uint32_t)_d.width; _desc.height = (uint32_t)_d.height;
    _desc.array_length = (uint32_t)slices.length; _desc.mip_levels = (uint32_t)levels.length;
    for (NSUInteger l = 0; l < ISIM_MTL_MAX_LEVELS; l++) {
        NSUInteger pl = levels.location + l;
        if (l >= levels.length || pl >= ISIM_MTL_MAX_LEVELS) { _desc.levels[l] = NULL; continue; }
        _desc.levels[l] = parent->_desc.levels[pl] ? parent->_desc.levels[pl] + slices.location * parent->_desc.level_bpi[pl] : NULL;
        _desc.level_bpr[l] = parent->_desc.level_bpr[pl]; _desc.level_bpi[l] = parent->_desc.level_bpi[pl];
    }
    _relativeLevel = levels.location; _relativeSlice = slices.location;
    return self;
}
- (void)dealloc { if (_storage) { free(_storage); __atomic_sub_fetch(&allocated, _size, __ATOMIC_RELAXED); } }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (id<MTLTexture>)rootResource { return _parent; }
- (id<MTLTexture>)parentTexture { return _parent; }
- (NSUInteger)parentRelativeLevel { return _relativeLevel; }
- (NSUInteger)parentRelativeSlice { return _relativeSlice; }
- (id<MTLBuffer>)buffer { return _buffer; }
- (NSUInteger)bufferOffset { return _bufferOffset; }
- (NSUInteger)bufferBytesPerRow { return _bufferBytesPerRow; }
- (MTLTextureType)textureType { return _d.textureType; }
- (MTLPixelFormat)pixelFormat { return _d.pixelFormat; }
- (NSUInteger)width { return _d.width; }
- (NSUInteger)height { return _d.height; }
- (NSUInteger)depth { return _d.depth; }
- (NSUInteger)mipmapLevelCount { return _desc.mip_levels; }
- (NSUInteger)sampleCount { return MAX(_d.sampleCount, (NSUInteger)1); }
- (NSUInteger)arrayLength { return MAX(_d.arrayLength, (NSUInteger)1); }
- (MTLTextureUsage)usage { return _d.usage; }
- (BOOL)isShareable { return NO; }
- (BOOL)isFramebufferOnly { return NO; }
- (BOOL)allowGPUOptimizedContents { return _d.allowGPUOptimizedContents; }
- (MTLTextureCompressionType)compressionType { return _d.compressionType; }
- (MTLTextureSwizzleChannels)swizzle { return _d.swizzle; }
- (MTLResourceID)gpuResourceID { return (MTLResourceID){(uint64_t)(uintptr_t)&_desc}; }
- (MTLCPUCacheMode)cpuCacheMode { return _d.cpuCacheMode; }
- (MTLStorageMode)storageMode { return _d.storageMode; }
- (MTLHazardTrackingMode)hazardTrackingMode { return _d.hazardTrackingMode; }
- (MTLResourceOptions)resourceOptions { return _d.resourceOptions; }
- (MTLPurgeableState)setPurgeableState:(MTLPurgeableState)state { return MTLPurgeableStateNonVolatile; }
- (id<MTLHeap>)heap { return nil; }
- (NSUInteger)heapOffset { return 0; }
- (NSUInteger)allocatedSize { return _size; }
- (void)makeAliasable {}
- (BOOL)isAliasable { return NO; }
/* copies a region between the texture and caller memory (rows of bytesPerRow, images of bytesPerImage) */
- (void)copyRegion:(MTLRegion)r level:(NSUInteger)level slice:(NSUInteger)slice bytes:(uint8_t *)bytes
       bytesPerRow:(NSUInteger)bpr bytesPerImage:(NSUInteger)bpi toTexture:(BOOL)in {
    if (level >= _desc.mip_levels || !_desc.levels[level]) return;
    isim_mtl_format_info fi = isim_mtl_format(_d.pixelFormat);
    NSUInteger px = fi.bytes ? fi.bytes : 4;
    NSUInteger x0 = r.origin.x / fi.block_w, y0 = r.origin.y / fi.block_h;
    NSUInteger w = (r.size.width + fi.block_w - 1) / fi.block_w, h = (r.size.height + fi.block_h - 1) / fi.block_h;
    NSUInteger planes = _d.textureType == MTLTextureType3D ? r.size.depth : 1;
    NSUInteger z0 = _d.textureType == MTLTextureType3D ? r.origin.z : slice;
    NSUInteger lw = MAX(_d.width >> level, (NSUInteger)1), lh = MAX(_d.height >> level, (NSUInteger)1);
    if (r.origin.x + r.size.width > lw || r.origin.y + r.size.height > lh) return;
    for (NSUInteger z = 0; z < planes; z++) {
        uint8_t *plane = _desc.levels[level] + (size_t)(z0 + z) * _desc.level_bpi[level];
        for (NSUInteger y = 0; y < h; y++) {
            uint8_t *t = plane + (size_t)(y0 + y) * _desc.level_bpr[level] + x0 * px;
            uint8_t *c = bytes + (size_t)z * bpi + (size_t)y * bpr;
            if (in) memcpy(t, c, w * px); else memcpy(c, t, w * px);
        }
    }
}
- (void)getBytes:(void *)p bytesPerRow:(NSUInteger)bpr bytesPerImage:(NSUInteger)bpi fromRegion:(MTLRegion)r mipmapLevel:(NSUInteger)l slice:(NSUInteger)s {
    [self copyRegion:r level:l slice:s bytes:p bytesPerRow:bpr bytesPerImage:bpi toTexture:NO];
}
- (void)replaceRegion:(MTLRegion)r mipmapLevel:(NSUInteger)l slice:(NSUInteger)s withBytes:(const void *)p bytesPerRow:(NSUInteger)bpr bytesPerImage:(NSUInteger)bpi {
    [self copyRegion:r level:l slice:s bytes:(uint8_t *)p bytesPerRow:bpr bytesPerImage:bpi toTexture:YES];
}
- (void)getBytes:(void *)p bytesPerRow:(NSUInteger)bpr fromRegion:(MTLRegion)r mipmapLevel:(NSUInteger)l {
    [self copyRegion:r level:l slice:0 bytes:p bytesPerRow:bpr bytesPerImage:bpr * r.size.height toTexture:NO];
}
- (void)replaceRegion:(MTLRegion)r mipmapLevel:(NSUInteger)l withBytes:(const void *)p bytesPerRow:(NSUInteger)bpr {
    [self copyRegion:r level:l slice:0 bytes:(uint8_t *)p bytesPerRow:bpr bytesPerImage:bpr * r.size.height toTexture:YES];
}
/* a view reads the same texels as another format of the same size */
- (id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)f {
    if (isim_mtl_format(f).bytes != isim_mtl_format(_d.pixelFormat).bytes) return nil;
    return [[ISIMMTLTexture alloc] initViewOf:self format:f];
}
- (id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)f textureType:(MTLTextureType)t levels:(NSRange)levels slices:(NSRange)slices {
    if (!levels.length || NSMaxRange(levels) > _desc.mip_levels || !slices.length || NSMaxRange(slices) > slices_of(_d)) return nil;
    return [[ISIMMTLTexture alloc] initViewOf:self format:f type:t levels:levels slices:slices];
}
@end

/* ---- fences: isim's queues run their command buffers in order, so a fence has nothing to wait for ---- */
@interface ISIMMTLFence : NSObject <MTLFence>
@end
@implementation ISIMMTLFence
@synthesize label;
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
@end
@implementation ISIMMTLDevice (Fences)
- (id<MTLFence>)newFence { return [ISIMMTLFence new]; }
@end

/* ---- samplers ---- */
@implementation MTLSamplerDescriptor
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _maxAnisotropy = 1; _normalizedCoordinates = YES; _lodMaxClamp = 3.402823466e+38f;
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLSamplerDescriptor *d = [[MTLSamplerDescriptor allocWithZone:zone] init];
    d.minFilter = _minFilter; d.magFilter = _magFilter; d.mipFilter = _mipFilter; d.maxAnisotropy = _maxAnisotropy;
    d.sAddressMode = _sAddressMode; d.tAddressMode = _tAddressMode; d.rAddressMode = _rAddressMode; d.borderColor = _borderColor;
    d.normalizedCoordinates = _normalizedCoordinates; d.lodMinClamp = _lodMinClamp; d.lodMaxClamp = _lodMaxClamp;
    d.lodAverage = _lodAverage; d.compareFunction = _compareFunction; d.supportArgumentBuffers = _supportArgumentBuffers; d.label = _label;
    return d;
}
@end

@implementation ISIMMTLSamplerState {
    NSString *_label;
}
- (instancetype)initWithDescriptor:(MTLSamplerDescriptor *)d {
    if (!(self = [super init])) return nil;
    _desc.min_filter = (uint8_t)d.minFilter; _desc.mag_filter = (uint8_t)d.magFilter; _desc.mip_filter = (uint8_t)d.mipFilter;
    _desc.s_address = (uint8_t)d.sAddressMode; _desc.t_address = (uint8_t)d.tAddressMode; _desc.r_address = (uint8_t)d.rAddressMode;
    _desc.normalized = d.normalizedCoordinates; _desc.border = (uint8_t)d.borderColor;
    _desc.lod_min = d.lodMinClamp; _desc.lod_max = d.lodMaxClamp; _desc.compare = (uint8_t)(d.compareFunction + 1);
    _label = [d.label copy];
    return self;
}
- (NSString *)label { return _label; }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (MTLResourceID)gpuResourceID { return (MTLResourceID){(uint64_t)(uintptr_t)&_desc}; }
@end

@implementation ISIMMTLDevice (Resources)
- (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options {
    return [[ISIMMTLBuffer alloc] initWithLength:length options:options bytes:NULL];
}
- (id<MTLBuffer>)newBufferWithBytes:(const void *)p length:(NSUInteger)length options:(MTLResourceOptions)options {
    return [[ISIMMTLBuffer alloc] initWithLength:length options:options bytes:p];
}
- (id<MTLBuffer>)newBufferWithBytesNoCopy:(void *)p length:(NSUInteger)length options:(MTLResourceOptions)options
                              deallocator:(void (^)(void *, NSUInteger))deallocator {
    return [[ISIMMTLBuffer alloc] initNoCopy:p length:length options:options deallocator:deallocator];
}
- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)d {
    if (d.pixelFormat == MTLPixelFormatInvalid || d.sampleCount > 4) return nil;
    return [[ISIMMTLTexture alloc] initWithDescriptor:d buffer:nil offset:0 bytesPerRow:0];
}
- (id<MTLSamplerState>)newSamplerStateWithDescriptor:(MTLSamplerDescriptor *)d {
    return [[ISIMMTLSamplerState alloc] initWithDescriptor:d];
}
@end
