#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLTypes.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice;
typedef NS_ENUM(NSUInteger, MTLCompareFunction) {
    MTLCompareFunctionNever = 0, MTLCompareFunctionLess = 1, MTLCompareFunctionEqual = 2, MTLCompareFunctionLessEqual = 3,
    MTLCompareFunctionGreater = 4, MTLCompareFunctionNotEqual = 5, MTLCompareFunctionGreaterEqual = 6, MTLCompareFunctionAlways = 7,
};
typedef NS_ENUM(NSUInteger, MTLStencilOperation) {
    MTLStencilOperationKeep = 0, MTLStencilOperationZero = 1, MTLStencilOperationReplace = 2, MTLStencilOperationIncrementClamp = 3,
    MTLStencilOperationDecrementClamp = 4, MTLStencilOperationInvert = 5, MTLStencilOperationIncrementWrap = 6, MTLStencilOperationDecrementWrap = 7,
};
/* issue #329: the depth and stencil tests of a render pass (MTLRenderCommandEncoder setDepthStencilState:) */
@interface MTLStencilDescriptor : NSObject <NSCopying>
@property (nonatomic) MTLCompareFunction stencilCompareFunction;
@property (nonatomic) MTLStencilOperation stencilFailureOperation;
@property (nonatomic) MTLStencilOperation depthFailureOperation;
@property (nonatomic) MTLStencilOperation depthStencilPassOperation;
@property (nonatomic) uint32_t readMask;
@property (nonatomic) uint32_t writeMask;
@end
@interface MTLDepthStencilDescriptor : NSObject <NSCopying>
@property (nonatomic) MTLCompareFunction depthCompareFunction;
@property (nonatomic, getter=isDepthWriteEnabled) BOOL depthWriteEnabled;
@property (copy, nonatomic, null_resettable) MTLStencilDescriptor *frontFaceStencil;
@property (copy, nonatomic, null_resettable) MTLStencilDescriptor *backFaceStencil;
@property (nullable, copy, nonatomic) NSString *label;
@end
@protocol MTLDepthStencilState <NSObject>
@property (nullable, readonly) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) MTLResourceID gpuResourceID;
@end
NS_ASSUME_NONNULL_END
