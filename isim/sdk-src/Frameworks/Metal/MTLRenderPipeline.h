#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLComputePipeline.h>
#import <Metal/MTLVertexDescriptor.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice, MTLFunction;
/* issue #329: render pipelines. Vertex and fragment functions run on the CPU (tools/mslc.py), and isim's rasterizer
 * (frameworks/Metal/MTLRaster.c) draws their triangles, lines and points into the render pass's textures. */
typedef NS_ENUM(NSUInteger, MTLBlendFactor) {
    MTLBlendFactorZero = 0, MTLBlendFactorOne = 1, MTLBlendFactorSourceColor = 2, MTLBlendFactorOneMinusSourceColor = 3,
    MTLBlendFactorSourceAlpha = 4, MTLBlendFactorOneMinusSourceAlpha = 5, MTLBlendFactorDestinationColor = 6,
    MTLBlendFactorOneMinusDestinationColor = 7, MTLBlendFactorDestinationAlpha = 8, MTLBlendFactorOneMinusDestinationAlpha = 9,
    MTLBlendFactorSourceAlphaSaturated = 10, MTLBlendFactorBlendColor = 11, MTLBlendFactorOneMinusBlendColor = 12,
    MTLBlendFactorBlendAlpha = 13, MTLBlendFactorOneMinusBlendAlpha = 14, MTLBlendFactorSource1Color = 15,
    MTLBlendFactorOneMinusSource1Color = 16, MTLBlendFactorSource1Alpha = 17, MTLBlendFactorOneMinusSource1Alpha = 18,
};
typedef NS_ENUM(NSUInteger, MTLBlendOperation) {
    MTLBlendOperationAdd = 0, MTLBlendOperationSubtract = 1, MTLBlendOperationReverseSubtract = 2, MTLBlendOperationMin = 3, MTLBlendOperationMax = 4,
};
typedef NS_OPTIONS(NSUInteger, MTLColorWriteMask) {
    MTLColorWriteMaskNone NS_SWIFT_NAME(none) = 0, MTLColorWriteMaskRed = 0x1 << 3, MTLColorWriteMaskGreen = 0x1 << 2,
    MTLColorWriteMaskBlue = 0x1 << 1, MTLColorWriteMaskAlpha = 0x1 << 0, MTLColorWriteMaskAll = 0xf,
};
typedef NS_ENUM(NSUInteger, MTLPrimitiveTopologyClass) {
    MTLPrimitiveTopologyClassUnspecified = 0, MTLPrimitiveTopologyClassPoint = 1, MTLPrimitiveTopologyClassLine = 2, MTLPrimitiveTopologyClassTriangle = 3,
};

@interface MTLRenderPipelineColorAttachmentDescriptor : NSObject <NSCopying>
@property (nonatomic) MTLPixelFormat pixelFormat;
@property (nonatomic, getter=isBlendingEnabled) BOOL blendingEnabled;
@property (nonatomic) MTLBlendFactor sourceRGBBlendFactor;
@property (nonatomic) MTLBlendFactor destinationRGBBlendFactor;
@property (nonatomic) MTLBlendOperation rgbBlendOperation;
@property (nonatomic) MTLBlendFactor sourceAlphaBlendFactor;
@property (nonatomic) MTLBlendFactor destinationAlphaBlendFactor;
@property (nonatomic) MTLBlendOperation alphaBlendOperation;
@property (nonatomic) MTLColorWriteMask writeMask;
@end
@interface MTLRenderPipelineColorAttachmentDescriptorArray : NSObject
- (MTLRenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex;
- (void)setObject:(nullable MTLRenderPipelineColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex;
@end
/* reflection is not recorded on isim: the argument lists are empty */
@interface MTLRenderPipelineReflection : NSObject
@property (nullable, readonly) NSArray *vertexArguments;
@property (nullable, readonly) NSArray *fragmentArguments;
@property (readonly) NSArray *vertexBindings;
@property (readonly) NSArray *fragmentBindings;
@end
@interface MTLRenderPipelineDescriptor : NSObject <NSCopying>
@property (nullable, copy, nonatomic) NSString *label;
@property (nullable, readwrite, nonatomic, strong) id<MTLFunction> vertexFunction;
@property (nullable, readwrite, nonatomic, strong) id<MTLFunction> fragmentFunction;
@property (nullable, copy, nonatomic) MTLVertexDescriptor *vertexDescriptor;
@property (readwrite, nonatomic) NSUInteger sampleCount;
@property (readwrite, nonatomic) NSUInteger rasterSampleCount;
@property (readwrite, nonatomic, getter=isAlphaToCoverageEnabled) BOOL alphaToCoverageEnabled;
@property (readwrite, nonatomic, getter=isAlphaToOneEnabled) BOOL alphaToOneEnabled;
@property (readwrite, nonatomic, getter=isRasterizationEnabled) BOOL rasterizationEnabled;
@property (readwrite, nonatomic) NSUInteger maxVertexAmplificationCount;
@property (readonly) MTLRenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (nonatomic) MTLPixelFormat depthAttachmentPixelFormat;
@property (nonatomic) MTLPixelFormat stencilAttachmentPixelFormat;
@property (readwrite, nonatomic) MTLPrimitiveTopologyClass inputPrimitiveTopology;
@property (readwrite, nonatomic) BOOL supportIndirectCommandBuffers;
- (void)reset;
@end
@protocol MTLRenderPipelineState <NSObject>
@property (nullable, readonly) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) NSUInteger maxTotalThreadsPerThreadgroup;
@property (readonly) BOOL threadgroupSizeMatchesTileSize;
@property (readonly) NSUInteger imageblockSampleLength;
@property (readonly) BOOL supportIndirectCommandBuffers;
@property (readonly) MTLResourceID gpuResourceID;
@end
NS_ASSUME_NONNULL_END
