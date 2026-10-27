// isim MetalPerformanceShadersGraph (self-authored, Apple's interface): the core types
#pragma once
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

#define MPS_GRAPH_EXPORT extern __attribute__((visibility("default")))

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14.0))
@interface MPSGraphObject : NSObject
@end

API_AVAILABLE(ios(14.0))
@interface MPSGraphType : MPSGraphObject <NSCopying>
@end

/* a tensor's shape (nil: unranked; -1: a dimension of unknown size) and data type */
API_AVAILABLE(ios(14.0))
@interface MPSGraphShapedType : MPSGraphType
@property (readwrite, nullable, copy, atomic) MPSShape *shape;
@property (readwrite, atomic) MPSDataType dataType;
- (instancetype)initWithShape:(MPSShape *_Nullable)shape dataType:(MPSDataType)dataType;
- (BOOL)isEqualTo:(MPSGraphShapedType *_Nullable)object;
@end

typedef NS_ENUM(uint64_t, MPSGraphTensorNamedDataLayout) {
    MPSGraphTensorNamedDataLayoutNCHW = 0,
    MPSGraphTensorNamedDataLayoutNHWC = 1,
    MPSGraphTensorNamedDataLayoutOIHW = 2,
    MPSGraphTensorNamedDataLayoutHWIO = 3,
    MPSGraphTensorNamedDataLayoutCHW = 4,
    MPSGraphTensorNamedDataLayoutHWC = 5,
    MPSGraphTensorNamedDataLayoutHW = 6,
    MPSGraphTensorNamedDataLayoutNCDHW API_AVAILABLE(ios(16.3)) = 7,
    MPSGraphTensorNamedDataLayoutNDHWC API_AVAILABLE(ios(16.3)) = 8,
    MPSGraphTensorNamedDataLayoutOIDHW API_AVAILABLE(ios(16.3)) = 9,
    MPSGraphTensorNamedDataLayoutDHWIO API_AVAILABLE(ios(16.3)) = 10,
} API_AVAILABLE(ios(14.0));

typedef NS_ENUM(uint64_t, MPSGraphPaddingStyle) {
    MPSGraphPaddingStyleExplicit = 0,
    MPSGraphPaddingStyleTF_VALID = 1,
    MPSGraphPaddingStyleTF_SAME = 2,
    MPSGraphPaddingStyleExplicitOffset API_AVAILABLE(ios(15.0)) = 3,
    MPSGraphPaddingStyleONNX_SAME_LOWER API_AVAILABLE(ios(16.0)) = 4,
} API_AVAILABLE(ios(14.0));

typedef NS_ENUM(int64_t, MPSGraphPaddingMode) {
    MPSGraphPaddingModeConstant = 0,
    MPSGraphPaddingModeReflect = 1,
    MPSGraphPaddingModeSymmetric = 2,
    MPSGraphPaddingModeClampToEdge API_AVAILABLE(ios(15.0)) = 3,
    MPSGraphPaddingModeZero API_AVAILABLE(ios(15.0)) = 4,
    MPSGraphPaddingModePeriodic API_AVAILABLE(ios(15.0)) = 5,
    MPSGraphPaddingModeAntiPeriodic API_AVAILABLE(ios(15.0)) = 6,
} API_AVAILABLE(ios(14.0));

typedef NS_ENUM(uint64_t, MPSGraphReductionMode) {
    MPSGraphReductionModeMin = 0,
    MPSGraphReductionModeMax = 1,
    MPSGraphReductionModeSum = 2,
    MPSGraphReductionModeProduct = 3,
    MPSGraphReductionModeArgumentMin = 4,
    MPSGraphReductionModeArgumentMax = 5,
} API_AVAILABLE(ios(15.0));

typedef NS_ENUM(uint32_t, MPSGraphDeviceType) {
    MPSGraphDeviceTypeMetal = 0,
} API_AVAILABLE(ios(14.0));

/* isim: the graph runs on the CPU; a Metal device names isim's CPU device */
API_AVAILABLE(ios(14.0))
@interface MPSGraphDevice : MPSGraphObject
@property (readonly, atomic) MPSGraphDeviceType type;
@property (readonly, atomic, nullable) id<MTLDevice> metalDevice;
+ (instancetype)deviceWithMTLDevice:(id<MTLDevice>)metalDevice;
@end

NS_ASSUME_NONNULL_END
