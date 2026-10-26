#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice, MTLCommandBuffer;
@class MTLCommandBufferDescriptor;
@protocol MTLCommandQueue <NSObject>
@property (nullable, copy, atomic) NSString *label;
@property (readonly) id<MTLDevice> device;
- (nullable id<MTLCommandBuffer>)commandBuffer NS_SWIFT_NAME(makeCommandBuffer());
- (nullable id<MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor *)descriptor NS_SWIFT_NAME(makeCommandBuffer(descriptor:));
- (nullable id<MTLCommandBuffer>)commandBufferWithUnretainedReferences NS_SWIFT_NAME(makeCommandBufferWithUnretainedReferences());
@end
NS_ASSUME_NONNULL_END
