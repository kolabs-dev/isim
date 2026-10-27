/* isim MetalPerformanceShaders: kernels, images, N-dimensional arrays, and texels as floats (adapted: on the CPU) */
#import "mps_internal.h"

const MTLRegion MPSRectNoClip = { { 0, 0, 0 }, { NSUIntegerMax, NSUIntegerMax, NSUIntegerMax } };

BOOL MPSSupportsMTLDevice(id<MTLDevice> device) { return device != nil; }
id<MTLDevice> MPSGetPreferredDevice(NSUInteger options) { return MTLCreateSystemDefaultDevice(); }

/* ---------------- command buffers ---------------- */
@interface NSObject (ISIMMTLCommands)
- (void)addCommand:(void (^)(void))command;   /* isim's Metal command buffers (frameworks/Metal/MTLCommand.m) */
@end
void mps_enqueue(id<MTLCommandBuffer> cb, void (^block)(void)) {
    if ([(NSObject *)cb respondsToSelector:@selector(addCommand:)]) [(NSObject *)cb addCommand:block];
    else block();
}

/* ---------------- texels ---------------- */
static float srgb_to_linear(float c) { return c <= 0.04045f ? c / 12.92f : powf((c + 0.055f) / 1.055f, 2.4f); }
static float linear_to_srgb(float c) { return c <= 0.0031308f ? c * 12.92f : 1.055f * powf(c, 1 / 2.4f) - 0.055f; }
static float clamp01(float v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
static float clampm1(float v) { return v < -1 ? -1 : v > 1 ? 1 : v; }

typedef enum { K_UNORM8, K_SNORM8, K_UNORM16, K_SNORM16, K_HALF, K_FLOAT, K_UINT8, K_SINT8, K_UINT16, K_SINT16, K_UINT32, K_SINT32 } kind;
typedef struct { kind k; int n; int bgra; int srgb; int alpha_only; } fmt;
static BOOL fmt_of(MTLPixelFormat f, fmt *o) {
    fmt r = { K_UNORM8, 4, 0, 0, 0 };
    switch (f) {
    case MTLPixelFormatA8Unorm: r = (fmt){ K_UNORM8, 1, 0, 0, 1 }; break;
    case MTLPixelFormatR8Unorm: r = (fmt){ K_UNORM8, 1 }; break;
    case MTLPixelFormatR8Unorm_sRGB: r = (fmt){ K_UNORM8, 1, 0, 1 }; break;
    case MTLPixelFormatR8Snorm: r = (fmt){ K_SNORM8, 1 }; break;
    case MTLPixelFormatR8Uint: r = (fmt){ K_UINT8, 1 }; break;
    case MTLPixelFormatR8Sint: r = (fmt){ K_SINT8, 1 }; break;
    case MTLPixelFormatRG8Unorm: r = (fmt){ K_UNORM8, 2 }; break;
    case MTLPixelFormatRG8Snorm: r = (fmt){ K_SNORM8, 2 }; break;
    case MTLPixelFormatRGBA8Unorm: r = (fmt){ K_UNORM8, 4 }; break;
    case MTLPixelFormatRGBA8Unorm_sRGB: r = (fmt){ K_UNORM8, 4, 0, 1 }; break;
    case MTLPixelFormatRGBA8Snorm: r = (fmt){ K_SNORM8, 4 }; break;
    case MTLPixelFormatRGBA8Uint: r = (fmt){ K_UINT8, 4 }; break;
    case MTLPixelFormatBGRA8Unorm: r = (fmt){ K_UNORM8, 4, 1 }; break;
    case MTLPixelFormatBGRA8Unorm_sRGB: r = (fmt){ K_UNORM8, 4, 1, 1 }; break;
    case MTLPixelFormatR16Unorm: r = (fmt){ K_UNORM16, 1 }; break;
    case MTLPixelFormatR16Snorm: r = (fmt){ K_SNORM16, 1 }; break;
    case MTLPixelFormatR16Float: r = (fmt){ K_HALF, 1 }; break;
    case MTLPixelFormatR16Uint: r = (fmt){ K_UINT16, 1 }; break;
    case MTLPixelFormatR16Sint: r = (fmt){ K_SINT16, 1 }; break;
    case MTLPixelFormatRG16Unorm: r = (fmt){ K_UNORM16, 2 }; break;
    case MTLPixelFormatRG16Float: r = (fmt){ K_HALF, 2 }; break;
    case MTLPixelFormatRGBA16Unorm: r = (fmt){ K_UNORM16, 4 }; break;
    case MTLPixelFormatRGBA16Float: r = (fmt){ K_HALF, 4 }; break;
    case MTLPixelFormatR32Float: r = (fmt){ K_FLOAT, 1 }; break;
    case MTLPixelFormatR32Uint: r = (fmt){ K_UINT32, 1 }; break;
    case MTLPixelFormatR32Sint: r = (fmt){ K_SINT32, 1 }; break;
    case MTLPixelFormatRG32Float: r = (fmt){ K_FLOAT, 2 }; break;
    case MTLPixelFormatRGBA32Float: r = (fmt){ K_FLOAT, 4 }; break;
    default: return NO;
    }
    if (o) *o = r;
    return YES;
}
static size_t kind_size(kind k) {
    switch (k) {
    case K_UNORM8: case K_SNORM8: case K_UINT8: case K_SINT8: return 1;
    case K_UNORM16: case K_SNORM16: case K_HALF: case K_UINT16: case K_SINT16: return 2;
    default: return 4;
    }
}
BOOL mps_format_supported(MTLPixelFormat f) { return fmt_of(f, NULL); }
NSUInteger mps_format_channels(MTLPixelFormat f) { fmt r; return fmt_of(f, &r) ? (NSUInteger)r.n : 0; }
static float get_c(kind k, const uint8_t *p) {
    switch (k) {
    case K_UNORM8: return *p / 255.0f;
    case K_SNORM8: return clampm1(*(const int8_t *)p / 127.0f);
    case K_UNORM16: return *(const uint16_t *)p / 65535.0f;
    case K_SNORM16: return clampm1(*(const int16_t *)p / 32767.0f);
    case K_HALF: return (float)*(const _Float16 *)p;
    case K_FLOAT: return *(const float *)p;
    case K_UINT8: return *p;
    case K_SINT8: return *(const int8_t *)p;
    case K_UINT16: return *(const uint16_t *)p;
    case K_SINT16: return *(const int16_t *)p;
    case K_UINT32: return (float)*(const uint32_t *)p;
    case K_SINT32: return (float)*(const int32_t *)p;
    }
    return 0;
}
static void put_c(kind k, uint8_t *p, float v) {
    switch (k) {
    case K_UNORM8: *p = (uint8_t)lrintf(clamp01(v) * 255.0f); break;
    case K_SNORM8: *(int8_t *)p = (int8_t)lrintf(clampm1(v) * 127.0f); break;
    case K_UNORM16: *(uint16_t *)p = (uint16_t)lrintf(clamp01(v) * 65535.0f); break;
    case K_SNORM16: *(int16_t *)p = (int16_t)lrintf(clampm1(v) * 32767.0f); break;
    case K_HALF: *(_Float16 *)p = (_Float16)v; break;
    case K_FLOAT: *(float *)p = v; break;
    case K_UINT8: *p = (uint8_t)fminf(fmaxf(rintf(v), 0), 255); break;
    case K_SINT8: *(int8_t *)p = (int8_t)fminf(fmaxf(rintf(v), -128), 127); break;
    case K_UINT16: *(uint16_t *)p = (uint16_t)fminf(fmaxf(rintf(v), 0), 65535); break;
    case K_SINT16: *(int16_t *)p = (int16_t)fminf(fmaxf(rintf(v), -32768), 32767); break;
    case K_UINT32: *(uint32_t *)p = (uint32_t)fmax(fmin(rint(v), 4294967295.0), 0); break;
    case K_SINT32: *(int32_t *)p = (int32_t)fmax(fmin(rint(v), 2147483647.0), -2147483648.0); break;
    }
}
mps_img mps_alloc(NSUInteger w, NSUInteger h) {
    mps_img m = { calloc(w * h * 4 + 4, sizeof(float)), w, h, YES };
    return m;
}
void mps_free(mps_img *img) { free(img->px); img->px = NULL; }
mps_img mps_read(id<MTLTexture> t, NSUInteger slice) {
    fmt f;
    mps_img m = mps_alloc(t.width, t.height);
    if (!fmt_of(t.pixelFormat, &f)) { NSLog(@"isim MPS: pixel format %lu is not supported", (unsigned long)t.pixelFormat); return m; }
    m.alpha = f.n == 4 || f.alpha_only;
    size_t cs = kind_size(f.k), px = cs * (size_t)f.n, bpr = px * t.width;
    uint8_t *raw = malloc(bpr * t.height + 1);
    [t getBytes:raw bytesPerRow:bpr bytesPerImage:bpr * t.height fromRegion:MTLRegionMake2D(0, 0, t.width, t.height) mipmapLevel:0 slice:slice];
    for (NSUInteger i = 0; i < t.width * t.height; i++) {
        float c[4] = { 0, 0, 0, 1 };
        const uint8_t *p = raw + i * px;
        if (f.alpha_only) c[3] = get_c(f.k, p);
        else for (int k = 0; k < f.n; k++) c[k] = get_c(f.k, p + k * cs);
        if (f.bgra) { float b = c[0]; c[0] = c[2]; c[2] = b; }
        if (f.srgb) for (int k = 0; k < 3 && k < f.n; k++) c[k] = srgb_to_linear(c[k]);
        memcpy(m.px + i * 4, c, sizeof c);
    }
    free(raw);
    return m;
}
void mps_write(id<MTLTexture> t, NSUInteger slice, const mps_img *img, MTLRegion r) {
    fmt f;
    if (!fmt_of(t.pixelFormat, &f)) { NSLog(@"isim MPS: pixel format %lu is not supported", (unsigned long)t.pixelFormat); return; }
    if (!r.size.width || !r.size.height) return;
    size_t cs = kind_size(f.k), px = cs * (size_t)f.n, bpr = px * r.size.width;
    uint8_t *raw = malloc(bpr * r.size.height + 1);
    for (NSUInteger y = 0; y < r.size.height; y++)
        for (NSUInteger x = 0; x < r.size.width; x++) {
            const float *s = img->px + ((r.origin.y + y) * img->w + r.origin.x + x) * 4;
            float c[4] = { s[0], s[1], s[2], s[3] };
            if (f.srgb) for (int k = 0; k < 3; k++) c[k] = linear_to_srgb(clamp01(c[k]));
            if (f.bgra) { float b = c[0]; c[0] = c[2]; c[2] = b; }
            uint8_t *p = raw + y * bpr + x * px;
            if (f.alpha_only) put_c(f.k, p, c[3]);
            else for (int k = 0; k < f.n; k++) put_c(f.k, p + k * cs, c[k]);
        }
    [t replaceRegion:r mipmapLevel:0 slice:slice withBytes:raw bytesPerRow:bpr bytesPerImage:bpr * r.size.height];
    free(raw);
}
MTLRegion mps_clip(MTLRegion c, id<MTLTexture> dst) {
    NSUInteger x0 = MIN(c.origin.x, dst.width), y0 = MIN(c.origin.y, dst.height);
    NSUInteger w = c.size.width > dst.width - x0 ? dst.width - x0 : c.size.width, h = c.size.height > dst.height - y0 ? dst.height - y0 : c.size.height;
    return MTLRegionMake2D(x0, y0, w, h);
}
NSUInteger mps_slices(id<MTLTexture> t) {
    return t.textureType == MTLTextureType2DArray || t.textureType == MTLTextureType2DMultisampleArray ? MAX(t.arrayLength, (NSUInteger)1) : 1;
}

/* ---------------- data types ---------------- */
size_t mps_type_size(MPSDataType t) {
    if (t == MPSDataTypeBool) return 1;
    size_t bits = t & 0xffff;
    return bits >= 8 ? bits / 8 : 1;
}
double mps_load(MPSDataType t, const void *p, NSUInteger i) {
    switch ((uint32_t)t) {
    case MPSDataTypeFloat32: return ((const float *)p)[i];
    case MPSDataTypeFloat16: return (double)((const _Float16 *)p)[i];
    case MPSDataTypeBFloat16: { uint32_t b = (uint32_t)((const uint16_t *)p)[i] << 16; float f; memcpy(&f, &b, 4); return f; }
    case MPSDataTypeInt8: return ((const int8_t *)p)[i];
    case MPSDataTypeInt16: return ((const int16_t *)p)[i];
    case MPSDataTypeInt32: return ((const int32_t *)p)[i];
    case MPSDataTypeInt64: return (double)((const int64_t *)p)[i];
    case MPSDataTypeUInt8: case MPSDataTypeUnorm8: return t == MPSDataTypeUnorm8 ? ((const uint8_t *)p)[i] / 255.0 : ((const uint8_t *)p)[i];
    case MPSDataTypeUInt16: return ((const uint16_t *)p)[i];
    case MPSDataTypeUInt32: return ((const uint32_t *)p)[i];
    case MPSDataTypeUInt64: return (double)((const uint64_t *)p)[i];
    case MPSDataTypeBool: return ((const uint8_t *)p)[i] ? 1 : 0;
    default: return 0;
    }
}
void mps_store(MPSDataType t, void *p, NSUInteger i, double v) {
    switch ((uint32_t)t) {
    case MPSDataTypeFloat32: ((float *)p)[i] = (float)v; break;
    case MPSDataTypeFloat16: ((_Float16 *)p)[i] = (_Float16)v; break;
    case MPSDataTypeBFloat16: { float f = (float)v; uint32_t b; memcpy(&b, &f, 4); ((uint16_t *)p)[i] = (uint16_t)((b + 0x7fff + ((b >> 16) & 1)) >> 16); break; }
    case MPSDataTypeInt8: ((int8_t *)p)[i] = (int8_t)fmax(fmin(trunc(v), 127), -128); break;
    case MPSDataTypeInt16: ((int16_t *)p)[i] = (int16_t)fmax(fmin(trunc(v), 32767), -32768); break;
    case MPSDataTypeInt32: ((int32_t *)p)[i] = (int32_t)fmax(fmin(trunc(v), 2147483647.0), -2147483648.0); break;
    case MPSDataTypeInt64: ((int64_t *)p)[i] = (int64_t)v; break;
    case MPSDataTypeUInt8: ((uint8_t *)p)[i] = (uint8_t)fmax(fmin(trunc(v), 255), 0); break;
    case MPSDataTypeUnorm8: ((uint8_t *)p)[i] = (uint8_t)lrint(fmax(fmin(v, 1), 0) * 255); break;
    case MPSDataTypeUInt16: ((uint16_t *)p)[i] = (uint16_t)fmax(fmin(trunc(v), 65535), 0); break;
    case MPSDataTypeUInt32: ((uint32_t *)p)[i] = (uint32_t)fmax(fmin(trunc(v), 4294967295.0), 0); break;
    case MPSDataTypeUInt64: ((uint64_t *)p)[i] = (uint64_t)fmax(v, 0); break;
    case MPSDataTypeBool: ((uint8_t *)p)[i] = v != 0; break;
    default: break;
    }
}

/* ---------------- kernels ---------------- */
@implementation MPSKernel
@synthesize options = _options, device = _device, label = _label;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithDevice:(id<MTLDevice>)device { if ((self = [super init])) _device = device ?: MTLCreateSystemDefaultDevice(); return self; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithCoder:coder device:MTLCreateSystemDefaultDevice()]; }
- (instancetype)initWithCoder:(NSCoder *)coder device:(id<MTLDevice>)device {
    if ((self = [super init])) { _device = device; _label = [coder decodeObjectOfClass:[NSString class] forKey:@"label"]; _options = (MPSKernelOptions)[coder decodeIntegerForKey:@"options"]; }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:_label forKey:@"label"]; [coder encodeInteger:(NSInteger)_options forKey:@"options"]; }
/* isim: a copy is the same kernel object (a copy for another device switches its device) */
- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device {
    MPSKernel *k = [self copyWithZone:zone];
    if (device) k->_device = device;
    return k;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

/* ---------------- image descriptors and images ---------------- */
MTLPixelFormat mps_image_format(MPSImageFeatureChannelFormat f, NSUInteger channels) {
    int n = channels == 1 ? 1 : channels == 2 ? 2 : 4;
    switch (f) {
    case MPSImageFeatureChannelFormatUnorm8: return n == 1 ? MTLPixelFormatR8Unorm : n == 2 ? MTLPixelFormatRG8Unorm : MTLPixelFormatRGBA8Unorm;
    case MPSImageFeatureChannelFormatUnorm16: return n == 1 ? MTLPixelFormatR16Unorm : n == 2 ? MTLPixelFormatRG16Unorm : MTLPixelFormatRGBA16Unorm;
    case MPSImageFeatureChannelFormatFloat16: return n == 1 ? MTLPixelFormatR16Float : n == 2 ? MTLPixelFormatRG16Float : MTLPixelFormatRGBA16Float;
    case MPSImageFeatureChannelFormatFloat32: return n == 1 ? MTLPixelFormatR32Float : n == 2 ? MTLPixelFormatRG32Float : MTLPixelFormatRGBA32Float;
    default: return MTLPixelFormatInvalid;
    }
}
static MPSImageFeatureChannelFormat channel_format_of(MTLPixelFormat f) {
    switch (f) {
    case MTLPixelFormatR8Unorm: case MTLPixelFormatRG8Unorm: case MTLPixelFormatRGBA8Unorm: case MTLPixelFormatBGRA8Unorm:
    case MTLPixelFormatRGBA8Unorm_sRGB: case MTLPixelFormatBGRA8Unorm_sRGB: case MTLPixelFormatA8Unorm: return MPSImageFeatureChannelFormatUnorm8;
    case MTLPixelFormatR16Unorm: case MTLPixelFormatRG16Unorm: case MTLPixelFormatRGBA16Unorm: return MPSImageFeatureChannelFormatUnorm16;
    case MTLPixelFormatR16Float: case MTLPixelFormatRG16Float: case MTLPixelFormatRGBA16Float: return MPSImageFeatureChannelFormatFloat16;
    case MTLPixelFormatR32Float: case MTLPixelFormatRG32Float: case MTLPixelFormatRGBA32Float: return MPSImageFeatureChannelFormatFloat32;
    default: return MPSImageFeatureChannelFormatNone;
    }
}

@implementation MPSImageDescriptor
- (instancetype)init {
    if ((self = [super init])) {
        _channelFormat = MPSImageFeatureChannelFormatFloat16; _width = 1; _height = 1; _featureChannels = 1; _numberOfImages = 1;
        _usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite; _storageMode = MTLStorageModeShared;
    }
    return self;
}
+ (instancetype)imageDescriptorWithChannelFormat:(MPSImageFeatureChannelFormat)f width:(NSUInteger)w height:(NSUInteger)h featureChannels:(NSUInteger)c {
    return [self imageDescriptorWithChannelFormat:f width:w height:h featureChannels:c numberOfImages:1 usage:MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite];
}
+ (instancetype)imageDescriptorWithChannelFormat:(MPSImageFeatureChannelFormat)f width:(NSUInteger)w height:(NSUInteger)h featureChannels:(NSUInteger)c
                                  numberOfImages:(NSUInteger)n usage:(MTLTextureUsage)usage {
    MPSImageDescriptor *d = [[self alloc] init];
    d.channelFormat = f; d.width = w; d.height = h; d.featureChannels = c; d.numberOfImages = n; d.usage = usage;
    return d;
}
- (MTLPixelFormat)pixelFormat { return mps_image_format(_channelFormat, _featureChannels); }
- (id)copyWithZone:(NSZone *)zone {
    MPSImageDescriptor *d = [[MPSImageDescriptor alloc] init];
    d.channelFormat = _channelFormat; d.width = _width; d.height = _height; d.featureChannels = _featureChannels;
    d.numberOfImages = _numberOfImages; d.usage = _usage; d.storageMode = _storageMode; d.cpuCacheMode = _cpuCacheMode;
    return d;
}
@end

@interface _MPSDefaultImageAllocator : NSObject <MPSImageAllocator>
@property (nonatomic) BOOL temporary;
@end
@implementation _MPSDefaultImageAllocator
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (MPSImage *)imageForCommandBuffer:(id<MTLCommandBuffer>)cb imageDescriptor:(MPSImageDescriptor *)d kernel:(MPSKernel *)kernel {
    return _temporary ? [MPSTemporaryImage temporaryImageWithCommandBuffer:cb imageDescriptor:d] : [[MPSImage alloc] initWithDevice:cb.device imageDescriptor:d];
}
@end

@implementation MPSImage {
    id<MTLTexture> _texture;
    NSUInteger _featureChannels, _numberOfImages, _sliceStart;
    MPSImage *_parent;
}
@synthesize label = _label;
+ (id<MPSImageAllocator>)defaultAllocator { static _MPSDefaultImageAllocator *a; if (!a) a = [_MPSDefaultImageAllocator new]; return a; }
- (instancetype)initWithDevice:(id<MTLDevice>)device imageDescriptor:(const MPSImageDescriptor *)d {
    MTLTextureDescriptor *td = [MTLTextureDescriptor new];
    NSUInteger slices = (d.featureChannels + 3) / 4 * MAX(d.numberOfImages, (NSUInteger)1);
    td.pixelFormat = mps_image_format(d.channelFormat, d.featureChannels);
    td.width = MAX(d.width, (NSUInteger)1); td.height = MAX(d.height, (NSUInteger)1);
    td.textureType = slices > 1 ? MTLTextureType2DArray : MTLTextureType2D;
    td.arrayLength = slices;
    td.usage = d.usage; td.storageMode = MTLStorageModeShared;
    id<MTLTexture> t = [device ?: MTLCreateSystemDefaultDevice() newTextureWithDescriptor:td];
    if ((self = [super init])) { _texture = t; _featureChannels = d.featureChannels; _numberOfImages = MAX(d.numberOfImages, (NSUInteger)1); }
    return self;
}
- (instancetype)initWithTexture:(id<MTLTexture>)texture featureChannels:(NSUInteger)featureChannels {
    if ((self = [super init])) {
        _texture = texture; _featureChannels = featureChannels;
        _numberOfImages = MAX(mps_slices(texture) / MAX((featureChannels + 3) / 4, (NSUInteger)1), (NSUInteger)1);
    }
    return self;
}
- (instancetype)initWithParentImage:(MPSImage *)parent sliceRange:(NSRange)range featureChannels:(NSUInteger)featureChannels {
    if ((self = [super init])) {
        _parent = parent; _featureChannels = featureChannels; _numberOfImages = 1; _sliceStart = range.location;
        _texture = range.location == 0 && range.length >= mps_slices(parent.texture) ? parent.texture
                 : [parent.texture newTextureViewWithPixelFormat:parent.pixelFormat textureType:range.length > 1 ? MTLTextureType2DArray : MTLTextureType2D
                                                          levels:NSMakeRange(0, 1) slices:range];
    }
    return self;
}
- (id<MTLDevice>)device { return _texture.device; }
- (NSUInteger)width { return _texture.width; }
- (NSUInteger)height { return _texture.height; }
- (NSUInteger)featureChannels { return _featureChannels; }
- (NSUInteger)numberOfImages { return _numberOfImages; }
- (MTLTextureType)textureType { return _texture.textureType; }
- (MTLPixelFormat)pixelFormat { return _texture.pixelFormat; }
- (MTLTextureUsage)usage { return _texture.usage; }
- (id<MTLTexture>)texture { return _texture; }
- (MPSImage *)parent { return _parent; }
- (MPSImageFeatureChannelFormat)featureChannelFormat { return channel_format_of(_texture.pixelFormat); }
- (size_t)pixelSize {
    switch (self.featureChannelFormat) {
    case MPSImageFeatureChannelFormatUnorm8: return MIN(_featureChannels, (NSUInteger)4) == 3 ? 4 : mps_format_channels(_texture.pixelFormat);
    case MPSImageFeatureChannelFormatUnorm16: case MPSImageFeatureChannelFormatFloat16: return 2 * mps_format_channels(_texture.pixelFormat);
    default: return 4 * mps_format_channels(_texture.pixelFormat);
    }
}
- (NSUInteger)precision {
    switch (self.featureChannelFormat) {
    case MPSImageFeatureChannelFormatUnorm8: return 8;
    case MPSImageFeatureChannelFormatUnorm16: case MPSImageFeatureChannelFormatFloat16: return 16;
    default: return 32;
    }
}
- (NSUInteger)resourceSize { return self.pixelSize * self.width * self.height * mps_slices(_texture); }
- (MPSPurgeableState)setPurgeableState:(MPSPurgeableState)state { return MPSPurgeableStateNonVolatile; }
- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {}
- (NSArray<MPSImage *> *)batchRepresentation { return [self batchRepresentationWithSubRange:NSMakeRange(0, _numberOfImages)]; }
- (NSArray<MPSImage *> *)batchRepresentationWithSubRange:(NSRange)r {
    if (_numberOfImages <= 1) return @[ self ];
    NSUInteger per = (_featureChannels + 3) / 4;
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = r.location; i < NSMaxRange(r) && i < _numberOfImages; i++)
        [out addObject:[[MPSImage alloc] initWithParentImage:self sliceRange:NSMakeRange(i * per, per) featureChannels:_featureChannels]];
    return out;
}
- (MPSImage *)subImageWithFeatureChannelRange:(NSRange)range {
    NSUInteger first = range.location / 4, count = (range.length + 3) / 4;
    return [[MPSImage alloc] initWithParentImage:self sliceRange:NSMakeRange(first, count) featureChannels:range.length];
}
/* an element of the channel format in bytes: store v into p, or load it */
static void elem_rw(MPSImageFeatureChannelFormat f, uint8_t *p, float *v, BOOL write) {
    switch (f) {
    case MPSImageFeatureChannelFormatUnorm8: if (write) *p = (uint8_t)lrintf(clamp01(*v) * 255); else *v = *p / 255.0f; break;
    case MPSImageFeatureChannelFormatUnorm16: if (write) *(uint16_t *)p = (uint16_t)lrintf(clamp01(*v) * 65535); else *v = *(uint16_t *)p / 65535.0f; break;
    case MPSImageFeatureChannelFormatFloat16: if (write) *(_Float16 *)p = (_Float16)*v; else *v = (float)*(_Float16 *)p; break;
    default: if (write) *(float *)p = *v; else *v = *(float *)p; break;
    }
}
static size_t elem_size(MPSImageFeatureChannelFormat f) {
    return f == MPSImageFeatureChannelFormatUnorm8 ? 1 : f == MPSImageFeatureChannelFormatFloat32 ? 4 : 2;
}
/* copies channels [offset, offset + count) of image `index`, in the region, to or from bytes */
- (void)_rw:(void *)bytes layout:(MPSDataLayout)layout bpc:(NSUInteger)bpc bpr:(NSUInteger)bpr bpi:(NSUInteger)bpi region:(MTLRegion)r
     params:(MPSImageReadWriteParams)prm index:(NSUInteger)index write:(BOOL)write {
    MPSImageFeatureChannelFormat f = self.featureChannelFormat;
    size_t es = elem_size(f);
    NSUInteger per = (_featureChannels + 3) / 4, count = prm.numberOfFeatureChannelsToReadWrite;
    if (layout == MPSDataLayoutHeightxWidthxFeatureChannels) { if (!bpc) bpc = es * count; if (!bpr) bpr = bpc * r.size.width; }
    else { if (!bpc) bpc = es; if (!bpr) bpr = es * r.size.width; if (!bpi) bpi = bpr * r.size.height; }
    for (NSUInteger s = prm.featureChannelOffset / 4; s < per && s * 4 < prm.featureChannelOffset + count; s++) {
        NSUInteger slice = index * per + s;
        mps_img m = mps_read(_texture, slice);
        for (NSUInteger y = 0; y < r.size.height; y++)
            for (NSUInteger x = 0; x < r.size.width; x++)
                for (NSUInteger k = 0; k < 4; k++) {
                    NSUInteger ch = s * 4 + k;
                    if (ch < prm.featureChannelOffset || ch >= prm.featureChannelOffset + count || ch >= _featureChannels) continue;
                    NSUInteger c = ch - prm.featureChannelOffset;
                    uint8_t *p = layout == MPSDataLayoutHeightxWidthxFeatureChannels ? (uint8_t *)bytes + y * bpr + x * bpc + c * es
                                                                                       : (uint8_t *)bytes + c * bpi + y * bpr + x * bpc;
                    float *v = m.px + ((r.origin.y + y) * m.w + r.origin.x + x) * 4 + k;
                    elem_rw(f, p, v, !write);       /* writeBytes: bytes into the texture */
                }
        if (write) mps_write(_texture, slice, &m, MTLRegionMake2D(0, 0, m.w, m.h));
        mps_free(&m);
    }
}
- (void)readBytes:(void *)b dataLayout:(MPSDataLayout)l bytesPerRow:(NSUInteger)bpr region:(MTLRegion)r featureChannelInfo:(MPSImageReadWriteParams)p imageIndex:(NSUInteger)i {
    [self _rw:b layout:l bpc:0 bpr:bpr bpi:0 region:r params:p index:i write:NO];
}
- (void)readBytes:(void *)b dataLayout:(MPSDataLayout)l bytesPerRow:(NSUInteger)bpr bytesPerImage:(NSUInteger)bpi region:(MTLRegion)r
featureChannelInfo:(MPSImageReadWriteParams)p imageIndex:(NSUInteger)i {
    [self _rw:b layout:l bpc:0 bpr:bpr bpi:bpi region:r params:p index:i write:NO];
}
- (void)readBytes:(void *)b dataLayout:(MPSDataLayout)l imageIndex:(NSUInteger)i {
    [self _rw:b layout:l bpc:0 bpr:0 bpi:0 region:MTLRegionMake2D(0, 0, self.width, self.height)
       params:(MPSImageReadWriteParams){ 0, _featureChannels } index:i write:NO];
}
- (void)writeBytes:(const void *)b dataLayout:(MPSDataLayout)l bytesPerRow:(NSUInteger)bpr region:(MTLRegion)r featureChannelInfo:(MPSImageReadWriteParams)p imageIndex:(NSUInteger)i {
    [self _rw:(void *)b layout:l bpc:0 bpr:bpr bpi:0 region:r params:p index:i write:YES];
}
- (void)writeBytes:(const void *)b dataLayout:(MPSDataLayout)l bytesPerRow:(NSUInteger)bpr bytesPerImage:(NSUInteger)bpi region:(MTLRegion)r
featureChannelInfo:(MPSImageReadWriteParams)p imageIndex:(NSUInteger)i {
    [self _rw:(void *)b layout:l bpc:0 bpr:bpr bpi:bpi region:r params:p index:i write:YES];
}
- (void)writeBytes:(const void *)b dataLayout:(MPSDataLayout)l bytesPerColumn:(NSUInteger)bpc bytesPerRow:(NSUInteger)bpr bytesPerImage:(NSUInteger)bpi
            region:(MTLRegion)r featureChannelInfo:(MPSImageReadWriteParams)p imageIndex:(NSUInteger)i {
    [self _rw:(void *)b layout:l bpc:bpc bpr:bpr bpi:bpi region:r params:p index:i write:YES];
}
- (void)writeBytes:(const void *)b dataLayout:(MPSDataLayout)l imageIndex:(NSUInteger)i {
    [self _rw:(void *)b layout:l bpc:0 bpr:0 bpi:0 region:MTLRegionMake2D(0, 0, self.width, self.height)
       params:(MPSImageReadWriteParams){ 0, _featureChannels } index:i write:YES];
}
@end

@implementation MPSTemporaryImage
+ (id<MPSImageAllocator>)defaultAllocator { static _MPSDefaultImageAllocator *a; if (!a) { a = [_MPSDefaultImageAllocator new]; a.temporary = YES; } return a; }
+ (instancetype)temporaryImageWithCommandBuffer:(id<MTLCommandBuffer>)cb imageDescriptor:(const MPSImageDescriptor *)d {
    MPSTemporaryImage *t = [[self alloc] initWithDevice:cb.device imageDescriptor:d];
    t.readCount = 1;
    return t;
}
+ (instancetype)temporaryImageWithCommandBuffer:(id<MTLCommandBuffer>)cb textureDescriptor:(const MTLTextureDescriptor *)td {
    NSUInteger channels = mps_format_channels(td.pixelFormat);
    return [self temporaryImageWithCommandBuffer:cb textureDescriptor:td featureChannels:channels ? channels : 4];
}
+ (instancetype)temporaryImageWithCommandBuffer:(id<MTLCommandBuffer>)cb textureDescriptor:(const MTLTextureDescriptor *)td featureChannels:(NSUInteger)c {
    MPSTemporaryImage *t = [[self alloc] initWithTexture:[cb.device newTextureWithDescriptor:(MTLTextureDescriptor *)td] featureChannels:c];
    t.readCount = 1;
    return t;
}
+ (void)prefetchStorageWithCommandBuffer:(id<MTLCommandBuffer>)cb imageDescriptorList:(NSArray<MPSImageDescriptor *> *)list {}
@end

/* ---------------- N-dimensional arrays ---------------- */
#define MPS_MAX_DIMS 16
@implementation MPSNDArrayDescriptor {
@public
    NSUInteger _dims[MPS_MAX_DIMS];
    MPSDimensionSlice _slices[MPS_MAX_DIMS];
    uint8_t _order[MPS_MAX_DIMS];
}
- (instancetype)_init { if ((self = [super init])) for (int i = 0; i < MPS_MAX_DIMS; i++) { _dims[i] = 1; _slices[i] = (MPSDimensionSlice){ 0, 1 }; _order[i] = (uint8_t)i; } return self; }
+ (instancetype)descriptorWithDataType:(MPSDataType)t dimensionCount:(NSUInteger)n dimensionSizes:(NSUInteger *)sizes {
    MPSNDArrayDescriptor *d = [[self alloc] _init];
    d.dataType = t;
    [d reshapeWithDimensionCount:n dimensionSizes:sizes];
    return d;
}
+ (instancetype)descriptorWithDataType:(MPSDataType)t shape:(MPSShape *)shape {
    NSUInteger sizes[MPS_MAX_DIMS], n = MIN(shape.count, (NSUInteger)MPS_MAX_DIMS);
    for (NSUInteger i = 0; i < n; i++) sizes[i] = shape[n - 1 - i].unsignedIntegerValue;   /* outermost first -> dimension 0 innermost */
    return [self descriptorWithDataType:t dimensionCount:MAX(n, (NSUInteger)1) dimensionSizes:n ? sizes : (NSUInteger[]){ 1 }];
}
- (void)reshapeWithDimensionCount:(NSUInteger)n dimensionSizes:(NSUInteger *)sizes {
    _numberOfDimensions = MIN(n, (NSUInteger)MPS_MAX_DIMS);
    for (NSUInteger i = 0; i < MPS_MAX_DIMS; i++) {
        _dims[i] = i < _numberOfDimensions ? sizes[i] : 1;
        _slices[i] = (MPSDimensionSlice){ 0, _dims[i] }; _order[i] = (uint8_t)i;
    }
}
- (void)reshapeWithShape:(MPSShape *)shape {
    NSUInteger sizes[MPS_MAX_DIMS], n = MIN(shape.count, (NSUInteger)MPS_MAX_DIMS);
    for (NSUInteger i = 0; i < n; i++) sizes[i] = shape[n - 1 - i].unsignedIntegerValue;
    [self reshapeWithDimensionCount:n dimensionSizes:sizes];
}
- (MPSShape *)getShape {
    NSMutableArray *s = [NSMutableArray array];
    for (NSUInteger i = _numberOfDimensions; i-- > 0;) [s addObject:@([self lengthOfDimension:i])];
    return s;
}
- (NSUInteger)lengthOfDimension:(NSUInteger)i { return i < MPS_MAX_DIMS ? _slices[_order[i]].length : 1; }
- (MPSDimensionSlice)sliceRangeForDimension:(NSUInteger)i { return i < MPS_MAX_DIMS ? _slices[_order[i]] : (MPSDimensionSlice){ 0, 1 }; }
- (void)sliceDimension:(NSUInteger)i withSubrange:(MPSDimensionSlice)r { if (i < MPS_MAX_DIMS) _slices[_order[i]] = r; }
- (void)transposeDimension:(NSUInteger)a withDimension:(NSUInteger)b {
    if (a < MPS_MAX_DIMS && b < MPS_MAX_DIMS) { uint8_t t = _order[a]; _order[a] = _order[b]; _order[b] = t; }
}
- (vector_uchar16)dimensionOrder { vector_uchar16 v; for (int i = 0; i < 16; i++) v[i] = _order[i]; return v; }
@end

@implementation MPSNDArray {
    MPSNDArrayDescriptor *_desc;
    NSMutableData *_data;          /* packed, dimension 0 innermost */
    id<MTLBuffer> _buffer; NSUInteger _offset;
    id<MTLDevice> _device;
}
@synthesize label = _label;
- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSNDArrayDescriptor *)d {
    if ((self = [super init])) {
        _device = device; _desc = [MPSNDArrayDescriptor descriptorWithDataType:d.dataType dimensionCount:d.numberOfDimensions
                                                                dimensionSizes:(NSUInteger[MPS_MAX_DIMS]){ 0 }];
        NSUInteger sizes[MPS_MAX_DIMS];
        for (NSUInteger i = 0; i < d.numberOfDimensions; i++) sizes[i] = [d lengthOfDimension:i];
        [_desc reshapeWithDimensionCount:d.numberOfDimensions dimensionSizes:sizes];
        _data = [NSMutableData dataWithLength:self.count * mps_type_size(d.dataType)];
    }
    return self;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device scalar:(double)value {
    NSUInteger one = 1;
    self = [self initWithDevice:device descriptor:[MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 dimensionCount:1 dimensionSizes:&one]];
    mps_store(MPSDataTypeFloat32, _data.mutableBytes, 0, value);
    return self;
}
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(MPSNDArrayDescriptor *)d {
    if ((self = [self initWithDevice:buffer.device descriptor:d])) { _buffer = buffer; _offset = offset; _data = nil; }
    return self;
}
- (NSUInteger)count { NSUInteger n = 1; for (NSUInteger i = 0; i < _desc.numberOfDimensions; i++) n *= [_desc lengthOfDimension:i]; return n; }
- (void *)_isim_bytes { return _buffer ? (uint8_t *)_buffer.contents + _offset : _data.mutableBytes; }
- (MPSDataType)dataType { return _desc.dataType; }
- (size_t)dataTypeSize { return mps_type_size(_desc.dataType); }
- (NSUInteger)numberOfDimensions { return _desc.numberOfDimensions; }
- (id<MTLDevice>)device { return _device; }
- (MPSNDArray *)parent { return nil; }
- (NSUInteger)lengthOfDimension:(NSUInteger)i { return [_desc lengthOfDimension:i]; }
- (MPSNDArrayDescriptor *)descriptor {
    NSUInteger sizes[MPS_MAX_DIMS];
    for (NSUInteger i = 0; i < _desc.numberOfDimensions; i++) sizes[i] = [_desc lengthOfDimension:i];
    return [MPSNDArrayDescriptor descriptorWithDataType:_desc.dataType dimensionCount:_desc.numberOfDimensions dimensionSizes:sizes];
}
- (NSUInteger)resourceSize { return self.count * self.dataTypeSize; }
- (id<MTLBuffer>)userBuffer { return _buffer; }
- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)cb {}
/* copies between the packed array and strided bytes (strides per dimension, dimension 0 first) */
- (void)_copy:(void *)buffer strides:(NSInteger *)strides write:(BOOL)write {
    NSUInteger n = _desc.numberOfDimensions, es = self.dataTypeSize, total = self.count, idx[MPS_MAX_DIMS] = { 0 };
    NSInteger st[MPS_MAX_DIMS];
    NSInteger acc = (NSInteger)es;
    for (NSUInteger i = 0; i < n; i++) { st[i] = strides ? strides[i] : acc; acc *= (NSInteger)[_desc lengthOfDimension:i]; }
    uint8_t *mine = [self _isim_bytes];
    for (NSUInteger e = 0; e < total; e++) {
        NSInteger off = 0;
        for (NSUInteger i = 0; i < n; i++) off += (NSInteger)idx[i] * st[i];
        if (write) memcpy(mine + e * es, (uint8_t *)buffer + off, es); else memcpy((uint8_t *)buffer + off, mine + e * es, es);
        for (NSUInteger i = 0; i < n; i++) { if (++idx[i] < [_desc lengthOfDimension:i]) break; idx[i] = 0; }
    }
}
- (void)readBytes:(void *)buffer strideBytes:(NSInteger *)strides { [self _copy:buffer strides:strides write:NO]; }
- (void)writeBytes:(void *)buffer strideBytes:(NSInteger *)strides { [self _copy:buffer strides:strides write:YES]; }
- (void)exportDataWithCommandBuffer:(id<MTLCommandBuffer>)cb toBuffer:(id<MTLBuffer>)buffer destinationDataType:(MPSDataType)t offset:(NSUInteger)offset
                         rowStrides:(NSInteger *)rowStrides {
    mps_enqueue(cb, ^{
        const void *src = [self _isim_bytes];
        for (NSUInteger i = 0; i < self.count; i++) mps_store(t, (uint8_t *)buffer.contents + offset, i, mps_load(self.dataType, src, i));
    });
}
- (void)importDataWithCommandBuffer:(id<MTLCommandBuffer>)cb fromBuffer:(id<MTLBuffer>)buffer sourceDataType:(MPSDataType)t offset:(NSUInteger)offset
                         rowStrides:(NSInteger *)rowStrides {
    mps_enqueue(cb, ^{
        void *dst = [self _isim_bytes];
        for (NSUInteger i = 0; i < self.count; i++) mps_store(self.dataType, dst, i, mps_load(t, (const uint8_t *)buffer.contents + offset, i));
    });
}
@end

@implementation MPSTemporaryNDArray
+ (instancetype)temporaryNDArrayWithCommandBuffer:(id<MTLCommandBuffer>)cb descriptor:(MPSNDArrayDescriptor *)d {
    MPSTemporaryNDArray *a = [[self alloc] initWithDevice:cb.device descriptor:d];
    a.readCount = 1;
    return a;
}
@end
