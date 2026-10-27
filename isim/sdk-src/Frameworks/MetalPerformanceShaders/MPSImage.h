// isim MetalPerformanceShaders: images (feature channels in a texture: up to 4 in a 2-D texture, more in the slices of
// a 2-D array, 4 per slice) and their descriptors
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(10.0))
@interface MPSImageDescriptor : NSObject <NSCopying>
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@property (readwrite, nonatomic) NSUInteger featureChannels;
@property (readwrite, nonatomic) NSUInteger numberOfImages;
@property (readonly, nonatomic) MTLPixelFormat pixelFormat;
@property (readwrite, nonatomic) MPSImageFeatureChannelFormat channelFormat;
@property (readwrite, nonatomic) MTLCPUCacheMode cpuCacheMode;
@property (readwrite, nonatomic) MTLStorageMode storageMode;
@property (readwrite, nonatomic) MTLTextureUsage usage;
+ (__nonnull instancetype)imageDescriptorWithChannelFormat:(MPSImageFeatureChannelFormat)channelFormat width:(NSUInteger)width height:(NSUInteger)height
                                           featureChannels:(NSUInteger)featureChannels;
+ (__nonnull instancetype)imageDescriptorWithChannelFormat:(MPSImageFeatureChannelFormat)channelFormat width:(NSUInteger)width height:(NSUInteger)height
                                           featureChannels:(NSUInteger)featureChannels numberOfImages:(NSUInteger)numberOfImages
                                                     usage:(MTLTextureUsage)usage;
@end

@class MPSImage;
API_AVAILABLE(ios(11.0))
@protocol MPSImageAllocator <NSObject, NSSecureCoding>
- (MPSImage *__nonnull)imageForCommandBuffer:(__nonnull id<MTLCommandBuffer>)cmdBuf imageDescriptor:(MPSImageDescriptor *__nonnull)descriptor
                                      kernel:(MPSKernel *__nonnull)kernel;
@optional
- (NSArray<MPSImage *> *__nonnull)imageBatchForCommandBuffer:(__nonnull id<MTLCommandBuffer>)cmdBuf imageDescriptor:(MPSImageDescriptor *__nonnull)descriptor
                                                      kernel:(MPSKernel *__nonnull)kernel count:(NSUInteger)count;
@end

API_AVAILABLE(ios(10.0))
@interface MPSImage : NSObject
+ (nonnull id<MPSImageAllocator>)defaultAllocator API_AVAILABLE(ios(11.0));
@property (readonly, retain, nonatomic, nonnull) id<MTLDevice> device;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@property (readonly, nonatomic) NSUInteger featureChannels;
@property (readonly, nonatomic) NSUInteger numberOfImages;
@property (readonly, nonatomic) MTLTextureType textureType;
@property (readonly, nonatomic) MTLPixelFormat pixelFormat;
@property (readonly, nonatomic) NSUInteger precision;
@property (readonly, nonatomic) MTLTextureUsage usage;
@property (readonly, nonatomic) MPSImageFeatureChannelFormat featureChannelFormat API_AVAILABLE(ios(13.0));
@property (readonly, nonatomic) size_t pixelSize;
@property (readonly, nonnull, nonatomic) id<MTLTexture> texture;
@property (copy, atomic, nullable) NSString *label;
@property (readonly, retain, nonatomic, nullable) MPSImage *parent API_AVAILABLE(ios(11.3));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device imageDescriptor:(const MPSImageDescriptor *__nonnull)imageDescriptor;
- (nonnull instancetype)initWithParentImage:(MPSImage *__nonnull)parent sliceRange:(NSRange)sliceRange featureChannels:(NSUInteger)featureChannels
    API_AVAILABLE(ios(11.3));
- (nonnull instancetype)initWithTexture:(nonnull id<MTLTexture>)texture featureChannels:(NSUInteger)featureChannels;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (NSArray<MPSImage *> *__nonnull)batchRepresentationWithSubRange:(NSRange)subRange API_AVAILABLE(ios(13.0));
- (NSArray<MPSImage *> *__nonnull)batchRepresentation API_AVAILABLE(ios(13.0));
- (MPSImage *__nonnull)subImageWithFeatureChannelRange:(NSRange)range API_AVAILABLE(ios(13.0));
- (NSUInteger)resourceSize API_AVAILABLE(ios(11.3));
- (MPSPurgeableState)setPurgeableState:(MPSPurgeableState)state;
- (void)readBytes:(void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout bytesPerRow:(NSUInteger)bytesPerRow region:(MTLRegion)region
    featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(11.3));
- (void)readBytes:(void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout bytesPerRow:(NSUInteger)bytesPerRow
    bytesPerImage:(NSUInteger)bytesPerImage region:(MTLRegion)region featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo
       imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(12.0));
- (void)readBytes:(void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(11.3));
- (void)writeBytes:(const void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout bytesPerRow:(NSUInteger)bytesPerRow region:(MTLRegion)region
    featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(11.3));
- (void)writeBytes:(const void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout bytesPerRow:(NSUInteger)bytesPerRow
     bytesPerImage:(NSUInteger)bytesPerImage region:(MTLRegion)region featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo
        imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(12.0));
- (void)writeBytes:(const void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout bytesPerColumn:(NSUInteger)bytesPerColumn
       bytesPerRow:(NSUInteger)bytesPerRow bytesPerImage:(NSUInteger)bytesPerImage region:(MTLRegion)region
featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(13.0));
- (void)writeBytes:(const void *__nonnull)dataBytes dataLayout:(MPSDataLayout)dataLayout imageIndex:(NSUInteger)imageIndex API_AVAILABLE(ios(11.3));
- (void)synchronizeOnCommandBuffer:(__nonnull id<MTLCommandBuffer>)commandBuffer NS_SWIFT_NAME(synchronize(on:)) API_AVAILABLE(ios(11.3));
@end

/* isim: a temporary image is an ordinary image (memory is not shared between temporary images) */
API_AVAILABLE(ios(10.0))
@interface MPSTemporaryImage : MPSImage
+ (nonnull instancetype)temporaryImageWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                                        imageDescriptor:(const MPSImageDescriptor *__nonnull)imageDescriptor;
+ (nonnull instancetype)temporaryImageWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                                      textureDescriptor:(const MTLTextureDescriptor *__nonnull)textureDescriptor;
+ (nonnull instancetype)temporaryImageWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                                      textureDescriptor:(const MTLTextureDescriptor *__nonnull)textureDescriptor
                                        featureChannels:(NSUInteger)featureChannels API_AVAILABLE(ios(11.0));
+ (void)prefetchStorageWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                     imageDescriptorList:(NSArray<MPSImageDescriptor *> *__nonnull)descriptorList;
+ (nonnull id<MPSImageAllocator>)defaultAllocator API_AVAILABLE(ios(11.0));
@property (readwrite, nonatomic) NSUInteger readCount;
@end

NS_ASSUME_NONNULL_END
