#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLComputeCommandEncoder.h>
#import <Metal/MTLRenderCommandEncoder.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice, MTLCommandQueue, MTLComputeCommandEncoder, MTLBlitCommandEncoder, MTLCommandBuffer, MTLDrawable;
@class MTLComputePassDescriptor, MTLRenderPassDescriptor;
typedef NS_ENUM(NSUInteger, MTLCommandBufferStatus) {
    MTLCommandBufferStatusNotEnqueued = 0, MTLCommandBufferStatusEnqueued = 1, MTLCommandBufferStatusCommitted = 2,
    MTLCommandBufferStatusScheduled = 3, MTLCommandBufferStatusCompleted = 4, MTLCommandBufferStatusError = 5,
};
MTL_EXTERN NSErrorDomain const MTLCommandBufferErrorDomain;
#if !defined(__swift__)   /* Swift: the MTLCommandBufferError struct of the Metal overlay */
typedef MTL_ERROR_ENUM(NSUInteger, MTLCommandBufferError, MTLCommandBufferErrorDomain) {
    MTLCommandBufferErrorNone = 0, MTLCommandBufferErrorInternal = 1, MTLCommandBufferErrorTimeout = 2, MTLCommandBufferErrorPageFault = 3,
    MTLCommandBufferErrorNotPermitted = 7, MTLCommandBufferErrorOutOfMemory = 8, MTLCommandBufferErrorInvalidResource = 9,
    MTLCommandBufferErrorMemoryless = 10, MTLCommandBufferErrorStackOverflow = 12,
};
#endif
typedef NS_OPTIONS(NSUInteger, MTLCommandBufferErrorOption) { MTLCommandBufferErrorOptionNone = 0, MTLCommandBufferErrorOptionEncoderExecutionStatus = 1 };
typedef void (^MTLCommandBufferHandler)(id<MTLCommandBuffer>);
@interface MTLCommandBufferDescriptor : NSObject <NSCopying>
@property (readwrite, nonatomic) BOOL retainedReferences;
@property (readwrite, nonatomic) MTLCommandBufferErrorOption errorOptions;
@end
/* committed command buffers run in order, one at a time per queue, on a background thread */
@protocol MTLCommandBuffer <NSObject>
@property (readonly) id<MTLDevice> device;
@property (readonly) id<MTLCommandQueue> commandQueue;
@property (readonly) BOOL retainedReferences;
@property (readonly) MTLCommandBufferErrorOption errorOptions;
@property (nullable, copy, atomic) NSString *label;
@property (readonly) CFTimeInterval kernelStartTime;
@property (readonly) CFTimeInterval kernelEndTime;
@property (readonly) CFTimeInterval GPUStartTime;
@property (readonly) CFTimeInterval GPUEndTime;
@property (readonly) MTLCommandBufferStatus status;
@property (nullable, readonly) NSError *error;
- (void)enqueue;
- (void)commit;
- (void)addScheduledHandler:(MTLCommandBufferHandler)block;
- (void)addCompletedHandler:(MTLCommandBufferHandler)block;
- (void)waitUntilScheduled;
- (void)waitUntilCompleted;
/* the drawable is presented when the command buffer has completed (its rendering is done on the CPU) */
- (void)presentDrawable:(id<MTLDrawable>)drawable NS_SWIFT_NAME(present(_:));
- (void)presentDrawable:(id<MTLDrawable>)drawable atTime:(CFTimeInterval)presentationTime NS_SWIFT_NAME(present(_:atTime:));
- (void)presentDrawable:(id<MTLDrawable>)drawable afterMinimumDuration:(CFTimeInterval)duration NS_SWIFT_NAME(present(_:afterMinimumDuration:));
- (nullable id<MTLBlitCommandEncoder>)blitCommandEncoder NS_SWIFT_NAME(makeBlitCommandEncoder());
- (nullable id<MTLComputeCommandEncoder>)computeCommandEncoder NS_SWIFT_NAME(makeComputeCommandEncoder());
- (nullable id<MTLComputeCommandEncoder>)computeCommandEncoderWithDispatchType:(MTLDispatchType)dispatchType NS_SWIFT_NAME(makeComputeCommandEncoder(dispatchType:));
- (nullable id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor
    NS_SWIFT_NAME(makeRenderCommandEncoder(descriptor:));
- (void)pushDebugGroup:(NSString *)string;
- (void)popDebugGroup;
@end
NS_ASSUME_NONNULL_END
