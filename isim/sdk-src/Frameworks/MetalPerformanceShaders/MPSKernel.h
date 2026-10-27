// isim MetalPerformanceShaders: the kernel base classes. isim: kernels run on the CPU, in order with the other work
// of the command buffer they are encoded into.
#pragma once
#import <MetalPerformanceShaders/MPSCoreTypes.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(9.0))
@interface MPSKernel : NSObject <NSCopying, NSSecureCoding>
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder device:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(11.0));
- (nonnull instancetype)copyWithZone:(nullable NSZone *)zone device:(nullable id<MTLDevice>)device;
@property (readwrite, nonatomic) MPSKernelOptions options;
@property (readonly, retain, nonatomic, nonnull) id<MTLDevice> device;
@property (copy, atomic, nullable) NSString *label;
@end

/* a copy of a texture to run a kernel in place */
typedef id<MTLTexture> _Nonnull (^MPSCopyAllocator)(MPSKernel *_Nonnull filter, __nonnull id<MTLCommandBuffer> commandBuffer,
                                                       __nonnull id<MTLTexture> sourceTexture);

@class MPSImage;

/* a kernel from one image to another: destination pixel (x, y) reads the source at (x + offset.x, y + offset.y) */
API_AVAILABLE(ios(9.0))
@interface MPSUnaryImageKernel : MPSKernel
@property (readwrite, nonatomic) MPSOffset offset;
@property (readwrite, nonatomic) MTLRegion clipRect;
@property (readwrite, nonatomic) MPSImageEdgeMode edgeMode;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder device:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(11.0));
- (BOOL)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer inPlaceTexture:(__nonnull id<MTLTexture> *__nonnull)texture
        fallbackCopyAllocator:(nullable MPSCopyAllocator)copyAllocator NS_SWIFT_NAME(encode(commandBuffer:inPlaceTexture:fallbackCopyAllocator:));
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceTexture:(nonnull id<MTLTexture>)sourceTexture
           destinationTexture:(nonnull id<MTLTexture>)destinationTexture NS_SWIFT_NAME(encode(commandBuffer:sourceTexture:destinationTexture:));
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceImage:(nonnull MPSImage *)sourceImage
             destinationImage:(nonnull MPSImage *)destinationImage NS_SWIFT_NAME(encode(commandBuffer:sourceImage:destinationImage:)) API_AVAILABLE(ios(11.0));
- (MPSRegion)sourceRegionForDestinationSize:(MTLSize)destinationSize NS_SWIFT_NAME(sourceRegion(destinationSize:));
@end

/* a kernel from two images to one */
API_AVAILABLE(ios(9.0))
@interface MPSBinaryImageKernel : MPSKernel
@property (readwrite, nonatomic) MPSOffset primaryOffset;
@property (readwrite, nonatomic) MPSOffset secondaryOffset;
@property (readwrite, nonatomic) MPSImageEdgeMode primaryEdgeMode;
@property (readwrite, nonatomic) MPSImageEdgeMode secondaryEdgeMode;
@property (readwrite, nonatomic) MTLRegion clipRect;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder device:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(11.0));
- (BOOL)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer primaryTexture:(nonnull id<MTLTexture>)primaryTexture
      inPlaceSecondaryTexture:(__nonnull id<MTLTexture> *__nonnull)inPlaceSecondaryTexture fallbackCopyAllocator:(nullable MPSCopyAllocator)copyAllocator
    NS_SWIFT_NAME(encode(commandBuffer:primaryTexture:inPlaceSecondaryTexture:fallbackCopyAllocator:));
- (BOOL)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer inPlacePrimaryTexture:(__nonnull id<MTLTexture> *__nonnull)inPlacePrimaryTexture
             secondaryTexture:(nonnull id<MTLTexture>)secondaryTexture fallbackCopyAllocator:(nullable MPSCopyAllocator)copyAllocator
    NS_SWIFT_NAME(encode(commandBuffer:inPlacePrimaryTexture:secondaryTexture:fallbackCopyAllocator:));
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer primaryTexture:(nonnull id<MTLTexture>)primaryTexture
             secondaryTexture:(nonnull id<MTLTexture>)secondaryTexture destinationTexture:(nonnull id<MTLTexture>)destinationTexture
    NS_SWIFT_NAME(encode(commandBuffer:primaryTexture:secondaryTexture:destinationTexture:));
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer primaryImage:(MPSImage *__nonnull)primaryImage
               secondaryImage:(MPSImage *__nonnull)secondaryImage destinationImage:(MPSImage *__nonnull)destinationImage
    NS_SWIFT_NAME(encode(commandBuffer:primaryImage:secondaryImage:destinationImage:)) API_AVAILABLE(ios(11.0));
- (MPSRegion)primarySourceRegionForDestinationSize:(MTLSize)destinationSize;
- (MPSRegion)secondarySourceRegionForDestinationSize:(MTLSize)destinationSize;
@end

NS_ASSUME_NONNULL_END
