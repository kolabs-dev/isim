#pragma once
#import <Metal/MTLFence.h>
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLResource.h>
#import <Metal/MTLLibrary.h>
#import <Metal/MTLComputePipeline.h>
#import <Metal/MTLRenderPipeline.h>
#import <Metal/MTLDepthStencil.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLCommandQueue, MTLBuffer, MTLTexture, MTLSamplerState, MTLLibrary, MTLComputePipelineState, MTLFunction, MTLRenderPipelineState,
    MTLDepthStencilState;
@class MTLTextureDescriptor, MTLSamplerDescriptor, MTLCompileOptions, MTLComputePipelineDescriptor, MTLComputePipelineReflection;
typedef NS_ENUM(NSInteger, MTLGPUFamily) {
    MTLGPUFamilyApple1 = 1001, MTLGPUFamilyApple2 = 1002, MTLGPUFamilyApple3 = 1003, MTLGPUFamilyApple4 = 1004,
    MTLGPUFamilyApple5 = 1005, MTLGPUFamilyApple6 = 1006, MTLGPUFamilyApple7 = 1007, MTLGPUFamilyApple8 = 1008,
    MTLGPUFamilyApple9 = 1009, MTLGPUFamilyMac2 = 2002, MTLGPUFamilyCommon1 = 3001, MTLGPUFamilyCommon2 = 3002,
    MTLGPUFamilyCommon3 = 3003, MTLGPUFamilyMetal3 = 5001,
};
typedef NS_ENUM(NSUInteger, MTLReadWriteTextureTier) { MTLReadWriteTextureTierNone = 0, MTLReadWriteTextureTier1 = 1, MTLReadWriteTextureTier2 = 2 };
typedef NS_ENUM(NSUInteger, MTLArgumentBuffersTier) { MTLArgumentBuffersTier1 = 0, MTLArgumentBuffersTier2 = 1 };
typedef void (^MTLNewLibraryCompletionHandler)(id<MTLLibrary> _Nullable library, NSError * _Nullable error);
typedef void (^MTLNewComputePipelineStateCompletionHandler)(id<MTLComputePipelineState> _Nullable computePipelineState, NSError * _Nullable error);
typedef void (^MTLNewComputePipelineStateWithReflectionCompletionHandler)(id<MTLComputePipelineState> _Nullable computePipelineState,
                                                                          MTLComputePipelineReflection * _Nullable reflection, NSError * _Nullable error);
typedef void (^MTLNewRenderPipelineStateCompletionHandler)(id<MTLRenderPipelineState> _Nullable renderPipelineState, NSError * _Nullable error);
typedef void (^MTLNewRenderPipelineStateWithReflectionCompletionHandler)(id<MTLRenderPipelineState> _Nullable renderPipelineState,
                                                                         MTLRenderPipelineReflection * _Nullable reflection, NSError * _Nullable error);

/* the system's device: isim's CPU ("isim CPU"), with the memory of the host */
MTL_EXTERN id<MTLDevice> _Nullable MTLCreateSystemDefaultDevice(void) NS_RETURNS_RETAINED;

@protocol MTLDevice <NSObject>
@property (readonly) NSString *name;
@property (readonly) uint64_t registryID;
@property (readonly) MTLSize maxThreadsPerThreadgroup;
@property (readonly) BOOL hasUnifiedMemory;
@property (readonly) uint64_t recommendedMaxWorkingSetSize;
@property (readonly) NSUInteger currentAllocatedSize;
@property (readonly) NSUInteger maxThreadgroupMemoryLength;
@property (readonly) NSUInteger maxArgumentBufferSamplerCount;
@property (readonly) NSUInteger maxBufferLength;
@property (readonly, getter=areProgrammableSamplePositionsSupported) BOOL programmableSamplePositionsSupported;
@property (readonly, getter=areRasterOrderGroupsSupported) BOOL rasterOrderGroupsSupported;
@property (readonly) BOOL supportsDynamicLibraries;
@property (readonly) BOOL supportsFunctionPointers;
@property (readonly) BOOL supports32BitFloatFiltering;
@property (readonly) BOOL supports32BitMSAA;
@property (readonly) BOOL supportsBCTextureCompression;
@property (readonly) BOOL supportsRaytracing;
@property (readonly) BOOL supportsShaderBarycentricCoordinates;
@property (readonly) MTLReadWriteTextureTier readWriteTextureSupport;
@property (readonly) MTLArgumentBuffersTier argumentBuffersSupport;
- (BOOL)supportsFamily:(MTLGPUFamily)gpuFamily NS_SWIFT_NAME(supportsFamily(_:));
- (BOOL)supportsTextureSampleCount:(NSUInteger)sampleCount NS_SWIFT_NAME(supportsTextureSampleCount(_:));
- (NSUInteger)minimumLinearTextureAlignmentForPixelFormat:(MTLPixelFormat)format NS_SWIFT_NAME(minimumLinearTextureAlignment(for:));
- (NSUInteger)minimumTextureBufferAlignmentForPixelFormat:(MTLPixelFormat)format NS_SWIFT_NAME(minimumTextureBufferAlignment(for:));

- (nullable id<MTLCommandQueue>)newCommandQueue NS_SWIFT_NAME(makeCommandQueue());
- (nullable id<MTLFence>)newFence NS_SWIFT_NAME(makeFence()) API_AVAILABLE(ios(10.0));
- (nullable id<MTLCommandQueue>)newCommandQueueWithMaxCommandBufferCount:(NSUInteger)maxCommandBufferCount NS_SWIFT_NAME(makeCommandQueue(maxCommandBufferCount:));

- (nullable id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options NS_SWIFT_NAME(makeBuffer(length:options:));
- (nullable id<MTLBuffer>)newBufferWithBytes:(const void *)pointer length:(NSUInteger)length options:(MTLResourceOptions)options
    NS_SWIFT_NAME(makeBuffer(bytes:length:options:));
- (nullable id<MTLBuffer>)newBufferWithBytesNoCopy:(void *)pointer length:(NSUInteger)length options:(MTLResourceOptions)options
                                       deallocator:(void (^ _Nullable)(void *pointer, NSUInteger length))deallocator
    NS_SWIFT_NAME(makeBuffer(bytesNoCopy:length:options:deallocator:));
- (nullable id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor NS_SWIFT_NAME(makeTexture(descriptor:));
- (nullable id<MTLSamplerState>)newSamplerStateWithDescriptor:(MTLSamplerDescriptor *)descriptor NS_SWIFT_NAME(makeSamplerState(descriptor:));

/* libraries: default.metallib from isim build (with its compiled kernels next to it), or Metal Shading Language source
 * compiled at run time with isim's toolchain (isim metal-compile; a compile error when clang is not installed) */
- (nullable id<MTLLibrary>)newDefaultLibrary NS_SWIFT_NAME(makeDefaultLibrary());
- (nullable id<MTLLibrary>)newDefaultLibraryWithBundle:(NSBundle *)bundle error:(NSError **)error NS_SWIFT_NAME(makeDefaultLibrary(bundle:));
- (nullable id<MTLLibrary>)newLibraryWithURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NAME(makeLibrary(URL:));
- (nullable id<MTLLibrary>)newLibraryWithData:(dispatch_data_t)data error:(NSError **)error NS_SWIFT_NAME(makeLibrary(data:));
- (nullable id<MTLLibrary>)newLibraryWithSource:(NSString *)source options:(nullable MTLCompileOptions *)options error:(NSError **)error
    NS_SWIFT_NAME(makeLibrary(source:options:));
- (void)newLibraryWithSource:(NSString *)source options:(nullable MTLCompileOptions *)options completionHandler:(MTLNewLibraryCompletionHandler)completionHandler
    NS_SWIFT_NAME(makeLibrary(source:options:completionHandler:));

- (nullable id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction error:(NSError **)error
    NS_SWIFT_NAME(makeComputePipelineState(function:));
- (nullable id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction options:(MTLPipelineOption)options
    reflection:(MTLComputePipelineReflection * _Nullable __autoreleasing * _Nullable)reflection error:(NSError **)error
    NS_SWIFT_NAME(makeComputePipelineState(function:options:reflection:));
- (nullable id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor:(MTLComputePipelineDescriptor *)descriptor options:(MTLPipelineOption)options
    reflection:(MTLComputePipelineReflection * _Nullable __autoreleasing * _Nullable)reflection error:(NSError **)error
    NS_SWIFT_NAME(makeComputePipelineState(descriptor:options:reflection:));
- (void)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction completionHandler:(MTLNewComputePipelineStateCompletionHandler)completionHandler
    NS_SWIFT_NAME(makeComputePipelineState(function:completionHandler:));
- (void)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction options:(MTLPipelineOption)options
    completionHandler:(MTLNewComputePipelineStateWithReflectionCompletionHandler)completionHandler
    NS_SWIFT_NAME(makeComputePipelineState(function:options:completionHandler:));

/* render pipelines (issue #329): vertex and fragment functions of isim-compiled libraries, drawn by isim's rasterizer */
- (nullable id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error
    NS_SWIFT_NAME(makeRenderPipelineState(descriptor:));
- (nullable id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor options:(MTLPipelineOption)options
    reflection:(MTLRenderPipelineReflection * _Nullable __autoreleasing * _Nullable)reflection error:(NSError **)error
    NS_SWIFT_NAME(makeRenderPipelineState(descriptor:options:reflection:));
- (void)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor completionHandler:(MTLNewRenderPipelineStateCompletionHandler)completionHandler
    NS_SWIFT_NAME(makeRenderPipelineState(descriptor:completionHandler:));
- (void)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor options:(MTLPipelineOption)options
    completionHandler:(MTLNewRenderPipelineStateWithReflectionCompletionHandler)completionHandler
    NS_SWIFT_NAME(makeRenderPipelineState(descriptor:options:completionHandler:));
- (nullable id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor:(MTLDepthStencilDescriptor *)descriptor
    NS_SWIFT_NAME(makeDepthStencilState(descriptor:));
@end
NS_ASSUME_NONNULL_END
