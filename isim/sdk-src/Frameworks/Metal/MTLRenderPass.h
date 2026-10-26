#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLTexture, MTLBuffer;
/* issue #329: a render pass's attachments: what they are cleared to, and whether they are kept or resolved */
typedef NS_ENUM(NSUInteger, MTLLoadAction) { MTLLoadActionDontCare = 0, MTLLoadActionLoad = 1, MTLLoadActionClear = 2 };
typedef NS_ENUM(NSUInteger, MTLStoreAction) {
    MTLStoreActionDontCare = 0, MTLStoreActionStore = 1, MTLStoreActionMultisampleResolve = 2, MTLStoreActionStoreAndMultisampleResolve = 3,
    MTLStoreActionUnknown = 4, MTLStoreActionCustomSampleDepthStore = 5,
};
typedef NS_OPTIONS(NSUInteger, MTLStoreActionOptions) {
    MTLStoreActionOptionNone NS_SWIFT_NAME(none) = 0, MTLStoreActionOptionCustomSamplePositions = 1,
};
typedef NS_ENUM(NSUInteger, MTLMultisampleDepthResolveFilter) {
    MTLMultisampleDepthResolveFilterSample0 = 0, MTLMultisampleDepthResolveFilterMin = 1, MTLMultisampleDepthResolveFilterMax = 2,
};
typedef NS_ENUM(NSUInteger, MTLMultisampleStencilResolveFilter) {
    MTLMultisampleStencilResolveFilterSample0 = 0, MTLMultisampleStencilResolveFilterDepthResolvedSample = 1,
};
typedef struct { double red, green, blue, alpha; } MTLClearColor;
MTL_INLINE MTLClearColor MTLClearColorMake(double red, double green, double blue, double alpha) {
    MTLClearColor c = {red, green, blue, alpha}; return c;
}

@interface MTLRenderPassAttachmentDescriptor : NSObject <NSCopying>
@property (nullable, nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic) NSUInteger level;
@property (nonatomic) NSUInteger slice;
@property (nonatomic) NSUInteger depthPlane;
@property (nullable, nonatomic, strong) id<MTLTexture> resolveTexture;
@property (nonatomic) NSUInteger resolveLevel;
@property (nonatomic) NSUInteger resolveSlice;
@property (nonatomic) NSUInteger resolveDepthPlane;
@property (nonatomic) MTLLoadAction loadAction;
@property (nonatomic) MTLStoreAction storeAction;
@property (nonatomic) MTLStoreActionOptions storeActionOptions;
@end
@interface MTLRenderPassColorAttachmentDescriptor : MTLRenderPassAttachmentDescriptor
@property (nonatomic) MTLClearColor clearColor;
@end
@interface MTLRenderPassDepthAttachmentDescriptor : MTLRenderPassAttachmentDescriptor
@property (nonatomic) double clearDepth;
@property (nonatomic) MTLMultisampleDepthResolveFilter depthResolveFilter;
@end
@interface MTLRenderPassStencilAttachmentDescriptor : MTLRenderPassAttachmentDescriptor
@property (nonatomic) uint32_t clearStencil;
@property (nonatomic) MTLMultisampleStencilResolveFilter stencilResolveFilter;
@end
@interface MTLRenderPassColorAttachmentDescriptorArray : NSObject
- (MTLRenderPassColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex;
- (void)setObject:(nullable MTLRenderPassColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex;
@end
@interface MTLRenderPassDescriptor : NSObject <NSCopying>
+ (MTLRenderPassDescriptor *)renderPassDescriptor NS_SWIFT_UNAVAILABLE("use MTLRenderPassDescriptor()");
@property (readonly) MTLRenderPassColorAttachmentDescriptorArray *colorAttachments;
@property (copy, nonatomic, null_resettable) MTLRenderPassDepthAttachmentDescriptor *depthAttachment;
@property (copy, nonatomic, null_resettable) MTLRenderPassStencilAttachmentDescriptor *stencilAttachment;
@property (nullable, strong, nonatomic) id<MTLBuffer> visibilityResultBuffer;
@property (nonatomic) NSUInteger renderTargetArrayLength;
@property (nonatomic) NSUInteger imageblockSampleLength;
@property (nonatomic) NSUInteger threadgroupMemoryLength;
@property (nonatomic) NSUInteger tileWidth;
@property (nonatomic) NSUInteger tileHeight;
@property (nonatomic) NSUInteger defaultRasterSampleCount;
@property (nonatomic) NSUInteger renderTargetWidth;
@property (nonatomic) NSUInteger renderTargetHeight;
@end
NS_ASSUME_NONNULL_END
