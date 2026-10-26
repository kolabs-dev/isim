#pragma once
#import <Metal/MTLResource.h>
NS_ASSUME_NONNULL_BEGIN
@class MTLTextureDescriptor;
@protocol MTLTexture;
/* CPU memory: contents() is the storage kernels read and write, in every storage mode */
@protocol MTLBuffer <MTLResource>
@property (readonly) NSUInteger length;
- (void *)contents NS_RETURNS_INNER_POINTER;
- (nullable id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor offset:(NSUInteger)offset bytesPerRow:(NSUInteger)bytesPerRow
    NS_SWIFT_NAME(makeTexture(descriptor:offset:bytesPerRow:));
- (void)addDebugMarker:(NSString *)marker range:(NSRange)range NS_SWIFT_NAME(__addDebugMarker(_:range:));
- (void)removeAllDebugMarkers;
@property (readonly) uint64_t gpuAddress;
@end
NS_ASSUME_NONNULL_END
