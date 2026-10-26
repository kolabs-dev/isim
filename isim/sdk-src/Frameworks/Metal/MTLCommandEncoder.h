#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice;
typedef NS_OPTIONS(NSUInteger, MTLResourceUsage) { MTLResourceUsageRead = 1, MTLResourceUsageWrite = 2, MTLResourceUsageSample = 4 };
typedef NS_OPTIONS(NSUInteger, MTLBarrierScope) { MTLBarrierScopeBuffers = 1, MTLBarrierScopeTextures = 2, MTLBarrierScopeRenderTargets = 4 };
typedef NS_OPTIONS(NSUInteger, MTLStages) {
    MTLStageVertex = 1, MTLStageFragment = 2, MTLStageTile = 4, MTLStageObject = 8, MTLStageMesh = 16,
    MTLStageResourceState = 1 << 26, MTLStageDispatch = 1 << 27, MTLStageBlit = 1 << 28, MTLStageAccelerationStructure = 1 << 29,
    MTLStageMachineLearning = 1 << 30, MTLStageAll = NSIntegerMax,
};
@protocol MTLCommandEncoder <NSObject>
@property (readonly) id<MTLDevice> device;
@property (nullable, copy, atomic) NSString *label;
- (void)endEncoding;
- (void)insertDebugSignpost:(NSString *)string;
- (void)pushDebugGroup:(NSString *)string;
- (void)popDebugGroup;
@end
NS_ASSUME_NONNULL_END
