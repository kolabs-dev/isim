#pragma once
#import <Metal/MTLResource.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLPixelFormat.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLBuffer;
typedef NS_ENUM(NSUInteger, MTLTextureType) {
    MTLTextureType1D = 0, MTLTextureType1DArray = 1, MTLTextureType2D = 2, MTLTextureType2DArray = 3,
    MTLTextureType2DMultisample = 4, MTLTextureTypeCube = 5, MTLTextureTypeCubeArray = 6, MTLTextureType3D = 7,
    MTLTextureType2DMultisampleArray = 8, MTLTextureTypeTextureBuffer = 9,
};
typedef NS_ENUM(uint8_t, MTLTextureSwizzle) {
    MTLTextureSwizzleZero = 0, MTLTextureSwizzleOne = 1, MTLTextureSwizzleRed = 2, MTLTextureSwizzleGreen = 3,
    MTLTextureSwizzleBlue = 4, MTLTextureSwizzleAlpha = 5,
};
typedef struct { MTLTextureSwizzle red, green, blue, alpha; } MTLTextureSwizzleChannels;
MTL_INLINE MTLTextureSwizzleChannels MTLTextureSwizzleChannelsMake(MTLTextureSwizzle r, MTLTextureSwizzle g, MTLTextureSwizzle b, MTLTextureSwizzle a) {
    MTLTextureSwizzleChannels c = {r, g, b, a}; return c;
}
#define MTLTextureSwizzleChannelsDefault (MTLTextureSwizzleChannelsMake(MTLTextureSwizzleRed, MTLTextureSwizzleGreen, MTLTextureSwizzleBlue, MTLTextureSwizzleAlpha))
typedef NS_OPTIONS(NSUInteger, MTLTextureUsage) {
    MTLTextureUsageUnknown NS_SWIFT_NAME(unknown) = 0, MTLTextureUsageShaderRead = 1, MTLTextureUsageShaderWrite = 2, MTLTextureUsageRenderTarget = 4,
    MTLTextureUsagePixelFormatView = 0x10, MTLTextureUsageShaderAtomic = 0x20,
};
typedef NS_ENUM(NSInteger, MTLTextureCompressionType) { MTLTextureCompressionTypeLossless = 0, MTLTextureCompressionTypeLossy = 1 };

@interface MTLTextureDescriptor : NSObject <NSCopying>
+ (MTLTextureDescriptor *)texture2DDescriptorWithPixelFormat:(MTLPixelFormat)pixelFormat width:(NSUInteger)width height:(NSUInteger)height mipmapped:(BOOL)mipmapped
    NS_SWIFT_NAME(texture2DDescriptor(pixelFormat:width:height:mipmapped:));
+ (MTLTextureDescriptor *)textureCubeDescriptorWithPixelFormat:(MTLPixelFormat)pixelFormat size:(NSUInteger)size mipmapped:(BOOL)mipmapped
    NS_SWIFT_NAME(textureCubeDescriptor(pixelFormat:size:mipmapped:));
+ (MTLTextureDescriptor *)textureBufferDescriptorWithPixelFormat:(MTLPixelFormat)pixelFormat width:(NSUInteger)width
    resourceOptions:(MTLResourceOptions)resourceOptions usage:(MTLTextureUsage)usage
    NS_SWIFT_NAME(textureBufferDescriptor(with:width:resourceOptions:usage:));
@property (readwrite, nonatomic) MTLTextureType textureType;
@property (readwrite, nonatomic) MTLPixelFormat pixelFormat;
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@property (readwrite, nonatomic) NSUInteger depth;
@property (readwrite, nonatomic) NSUInteger mipmapLevelCount;
@property (readwrite, nonatomic) NSUInteger sampleCount;
@property (readwrite, nonatomic) NSUInteger arrayLength;
@property (readwrite, nonatomic) MTLResourceOptions resourceOptions;
@property (readwrite, nonatomic) MTLCPUCacheMode cpuCacheMode;
@property (readwrite, nonatomic) MTLStorageMode storageMode;
@property (readwrite, nonatomic) MTLHazardTrackingMode hazardTrackingMode;
@property (readwrite, nonatomic) MTLTextureUsage usage;
@property (readwrite, nonatomic) BOOL allowGPUOptimizedContents;
@property (readwrite, nonatomic) MTLTextureCompressionType compressionType;
@property (readwrite, nonatomic) MTLTextureSwizzleChannels swizzle;
@end

/* the storage is CPU memory: replace(region:...) and getBytes copy into and out of it */
@protocol MTLTexture <MTLResource>
@property (nullable, readonly) id<MTLTexture> rootResource;
@property (nullable, readonly) id<MTLTexture> parentTexture;
@property (readonly) NSUInteger parentRelativeLevel;
@property (readonly) NSUInteger parentRelativeSlice;
@property (nullable, readonly) id<MTLBuffer> buffer;
@property (readonly) NSUInteger bufferOffset;
@property (readonly) NSUInteger bufferBytesPerRow;
@property (readonly) MTLTextureType textureType;
@property (readonly) MTLPixelFormat pixelFormat;
@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;
@property (readonly) NSUInteger depth;
@property (readonly) NSUInteger mipmapLevelCount;
@property (readonly) NSUInteger sampleCount;
@property (readonly) NSUInteger arrayLength;
@property (readonly) MTLTextureUsage usage;
@property (readonly, getter=isShareable) BOOL shareable;
@property (readonly, getter=isFramebufferOnly) BOOL framebufferOnly;
@property (readonly) BOOL allowGPUOptimizedContents;
@property (readonly) MTLTextureCompressionType compressionType;
@property (readonly) MTLTextureSwizzleChannels swizzle;
@property (readonly) MTLResourceID gpuResourceID;
- (void)getBytes:(void *)pixelBytes bytesPerRow:(NSUInteger)bytesPerRow bytesPerImage:(NSUInteger)bytesPerImage
      fromRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level slice:(NSUInteger)slice
    NS_SWIFT_NAME(getBytes(_:bytesPerRow:bytesPerImage:from:mipmapLevel:slice:));
- (void)replaceRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level slice:(NSUInteger)slice withBytes:(const void *)pixelBytes
          bytesPerRow:(NSUInteger)bytesPerRow bytesPerImage:(NSUInteger)bytesPerImage
    NS_SWIFT_NAME(replace(region:mipmapLevel:slice:withBytes:bytesPerRow:bytesPerImage:));
- (void)getBytes:(void *)pixelBytes bytesPerRow:(NSUInteger)bytesPerRow fromRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level
    NS_SWIFT_NAME(getBytes(_:bytesPerRow:from:mipmapLevel:));
- (void)replaceRegion:(MTLRegion)region mipmapLevel:(NSUInteger)level withBytes:(const void *)pixelBytes bytesPerRow:(NSUInteger)bytesPerRow
    NS_SWIFT_NAME(replace(region:mipmapLevel:withBytes:bytesPerRow:));
- (nullable id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)pixelFormat NS_SWIFT_NAME(makeTextureView(pixelFormat:));
- (nullable id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)pixelFormat textureType:(MTLTextureType)textureType
    levels:(NSRange)levelRange slices:(NSRange)sliceRange NS_SWIFT_NAME(__makeTextureView(pixelFormat:textureType:levels:slices:));
@end
NS_ASSUME_NONNULL_END
