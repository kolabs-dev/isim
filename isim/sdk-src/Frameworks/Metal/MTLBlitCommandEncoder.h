#pragma once
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLTypes.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLBuffer, MTLTexture, MTLResource;
typedef NS_OPTIONS(NSUInteger, MTLBlitOption) {
    MTLBlitOptionNone = 0, MTLBlitOptionDepthFromDepthStencil = 1, MTLBlitOptionStencilFromDepthStencil = 2, MTLBlitOptionRowLinearPVRTC = 4,
};
/* copies and fills, done in order with the command buffer's other work */
@protocol MTLBlitCommandEncoder <MTLCommandEncoder>
- (void)copyFromBuffer:(id<MTLBuffer>)sourceBuffer sourceOffset:(NSUInteger)sourceOffset toBuffer:(id<MTLBuffer>)destinationBuffer
     destinationOffset:(NSUInteger)destinationOffset size:(NSUInteger)size
    NS_SWIFT_NAME(copy(from:sourceOffset:to:destinationOffset:size:));
- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel
           sourceOrigin:(MTLOrigin)sourceOrigin sourceSize:(MTLSize)sourceSize toTexture:(id<MTLTexture>)destinationTexture
       destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel destinationOrigin:(MTLOrigin)destinationOrigin
    NS_SWIFT_NAME(copy(from:sourceSlice:sourceLevel:sourceOrigin:sourceSize:to:destinationSlice:destinationLevel:destinationOrigin:));
- (void)copyFromBuffer:(id<MTLBuffer>)sourceBuffer sourceOffset:(NSUInteger)sourceOffset sourceBytesPerRow:(NSUInteger)sourceBytesPerRow
   sourceBytesPerImage:(NSUInteger)sourceBytesPerImage sourceSize:(MTLSize)sourceSize toTexture:(id<MTLTexture>)destinationTexture
      destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel destinationOrigin:(MTLOrigin)destinationOrigin
    NS_SWIFT_NAME(copy(from:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:to:destinationSlice:destinationLevel:destinationOrigin:));
- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel
           sourceOrigin:(MTLOrigin)sourceOrigin sourceSize:(MTLSize)sourceSize toBuffer:(id<MTLBuffer>)destinationBuffer
      destinationOffset:(NSUInteger)destinationOffset destinationBytesPerRow:(NSUInteger)destinationBytesPerRow
    destinationBytesPerImage:(NSUInteger)destinationBytesPerImage
    NS_SWIFT_NAME(copy(from:sourceSlice:sourceLevel:sourceOrigin:sourceSize:to:destinationOffset:destinationBytesPerRow:destinationBytesPerImage:));
- (void)copyFromTexture:(id<MTLTexture>)sourceTexture toTexture:(id<MTLTexture>)destinationTexture NS_SWIFT_NAME(copy(from:to:));
- (void)fillBuffer:(id<MTLBuffer>)buffer range:(NSRange)range value:(uint8_t)value NS_SWIFT_NAME(__fill(_:range:value:));
- (void)generateMipmapsForTexture:(id<MTLTexture>)texture NS_SWIFT_NAME(generateMipmaps(for:));
- (void)optimizeContentsForGPUAccess:(id<MTLTexture>)texture NS_SWIFT_NAME(optimizeContentsForGPUAccess(texture:));
- (void)optimizeContentsForCPUAccess:(id<MTLTexture>)texture NS_SWIFT_NAME(optimizeContentsForCPUAccess(texture:));
- (void)synchronizeResource:(id<MTLResource>)resource NS_SWIFT_NAME(synchronize(resource:));
@end
NS_ASSUME_NONNULL_END
