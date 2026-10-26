#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice, MTLFunction;
typedef NS_OPTIONS(NSUInteger, MTLPipelineOption) {
    MTLPipelineOptionNone = 0, MTLPipelineOptionArgumentInfo = 1, MTLPipelineOptionBindingInfo = 1, MTLPipelineOptionBufferTypeInfo = 2,
    MTLPipelineOptionFailOnBinaryArchiveMiss = 4,
};
/* reflection is not recorded on isim: arguments and bindings are empty */
@interface MTLComputePipelineReflection : NSObject
@property (readonly) NSArray *bindings;
@end
@interface MTLComputePipelineDescriptor : NSObject <NSCopying>
@property (nullable, copy, nonatomic) NSString *label;
@property (nullable, readwrite, nonatomic, strong) id<MTLFunction> computeFunction;
@property (readwrite, nonatomic) BOOL threadGroupSizeIsMultipleOfThreadExecutionWidth;
@property (readwrite, nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property (readwrite, nonatomic) BOOL supportIndirectCommandBuffers;
@property (readwrite, nonatomic) NSUInteger maxCallStackDepth;
- (void)reset;
@end
/* a kernel ready to dispatch: threadExecutionWidth is 1 (SIMD groups of one thread on the CPU) */
@protocol MTLComputePipelineState <NSObject>
@property (nullable, readonly) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) NSUInteger maxTotalThreadsPerThreadgroup;
@property (readonly) NSUInteger threadExecutionWidth;
@property (readonly) NSUInteger staticThreadgroupMemoryLength;
@property (readonly) BOOL supportIndirectCommandBuffers;
@property (readonly) MTLResourceID gpuResourceID;
- (NSUInteger)imageblockMemoryLengthForDimensions:(MTLSize)imageblockDimensions;
@end
NS_ASSUME_NONNULL_END
