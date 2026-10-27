// isim MetalPerformanceShadersGraph: convolution, pooling, gather, one-hot, top-K, sorting, cumulative operations,
// random tensors and dropout
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraph.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14.0))
@interface MPSGraphConvolution2DOpDescriptor : MPSGraphObject <NSCopying>
@property (readwrite, nonatomic) NSUInteger strideInX;
@property (readwrite, nonatomic) NSUInteger strideInY;
@property (readwrite, nonatomic) NSUInteger dilationRateInX;
@property (readwrite, nonatomic) NSUInteger dilationRateInY;
@property (readwrite, nonatomic) NSUInteger paddingLeft;
@property (readwrite, nonatomic) NSUInteger paddingRight;
@property (readwrite, nonatomic) NSUInteger paddingTop;
@property (readwrite, nonatomic) NSUInteger paddingBottom;
@property (readwrite, nonatomic) MPSGraphPaddingStyle paddingStyle;
@property (readwrite, nonatomic) MPSGraphTensorNamedDataLayout dataLayout;
@property (readwrite, nonatomic) MPSGraphTensorNamedDataLayout weightsLayout;
@property (readwrite, nonatomic) NSUInteger groups;
+ (nullable instancetype)descriptorWithStrideInX:(NSUInteger)strideInX strideInY:(NSUInteger)strideInY dilationRateInX:(NSUInteger)dilationRateInX
                                 dilationRateInY:(NSUInteger)dilationRateInY groups:(NSUInteger)groups paddingLeft:(NSUInteger)paddingLeft
                                    paddingRight:(NSUInteger)paddingRight paddingTop:(NSUInteger)paddingTop paddingBottom:(NSUInteger)paddingBottom
                                    paddingStyle:(MPSGraphPaddingStyle)paddingStyle dataLayout:(MPSGraphTensorNamedDataLayout)dataLayout
                                   weightsLayout:(MPSGraphTensorNamedDataLayout)weightsLayout;
+ (nullable instancetype)descriptorWithStrideInX:(NSUInteger)strideInX strideInY:(NSUInteger)strideInY dilationRateInX:(NSUInteger)dilationRateInX
                                 dilationRateInY:(NSUInteger)dilationRateInY groups:(NSUInteger)groups paddingStyle:(MPSGraphPaddingStyle)paddingStyle
                                      dataLayout:(MPSGraphTensorNamedDataLayout)dataLayout weightsLayout:(MPSGraphTensorNamedDataLayout)weightsLayout;
- (void)setExplicitPaddingWithPaddingLeft:(NSUInteger)paddingLeft paddingRight:(NSUInteger)paddingRight paddingTop:(NSUInteger)paddingTop
                            paddingBottom:(NSUInteger)paddingBottom;
@end

API_AVAILABLE(ios(14.0))
@interface MPSGraphPooling2DOpDescriptor : MPSGraphObject <NSCopying>
@property (readwrite, nonatomic) NSUInteger kernelWidth;
@property (readwrite, nonatomic) NSUInteger kernelHeight;
@property (readwrite, nonatomic) NSUInteger strideInX;
@property (readwrite, nonatomic) NSUInteger strideInY;
@property (readwrite, nonatomic) NSUInteger dilationRateInX;
@property (readwrite, nonatomic) NSUInteger dilationRateInY;
@property (readwrite, nonatomic) NSUInteger paddingLeft;
@property (readwrite, nonatomic) NSUInteger paddingRight;
@property (readwrite, nonatomic) NSUInteger paddingTop;
@property (readwrite, nonatomic) NSUInteger paddingBottom;
@property (readwrite, nonatomic) MPSGraphPaddingStyle paddingStyle;
@property (readwrite, nonatomic) MPSGraphTensorNamedDataLayout dataLayout;
@property (readwrite, nonatomic) BOOL ceilMode API_AVAILABLE(ios(15.0));
@property (readwrite, nonatomic) BOOL includeZeroPadToAverage API_AVAILABLE(ios(15.0));
+ (nullable instancetype)descriptorWithKernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight strideInX:(NSUInteger)strideInX
                                         strideInY:(NSUInteger)strideInY paddingStyle:(MPSGraphPaddingStyle)paddingStyle
                                        dataLayout:(MPSGraphTensorNamedDataLayout)dataLayout;
+ (nullable instancetype)descriptorWithKernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight strideInX:(NSUInteger)strideInX
                                         strideInY:(NSUInteger)strideInY dilationRateInX:(NSUInteger)dilationRateInX
                                   dilationRateInY:(NSUInteger)dilationRateInY paddingLeft:(NSUInteger)paddingLeft paddingRight:(NSUInteger)paddingRight
                                        paddingTop:(NSUInteger)paddingTop paddingBottom:(NSUInteger)paddingBottom
                                      paddingStyle:(MPSGraphPaddingStyle)paddingStyle dataLayout:(MPSGraphTensorNamedDataLayout)dataLayout;
- (void)setExplicitPaddingWithPaddingLeft:(NSUInteger)paddingLeft paddingRight:(NSUInteger)paddingRight paddingTop:(NSUInteger)paddingTop
                            paddingBottom:(NSUInteger)paddingBottom;
@end

@interface MPSGraph (ConvolutionOps)
/* isim: NCHW or NHWC sources, OIHW or HWIO weights, groups */
- (MPSGraphTensor *)convolution2DWithSourceTensor:(MPSGraphTensor *)source weightsTensor:(MPSGraphTensor *)weights
                                       descriptor:(MPSGraphConvolution2DOpDescriptor *)descriptor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(convolution2D(_:weights:descriptor:name:));
@end

@interface MPSGraph (PoolingOps)
- (MPSGraphTensor *)maxPooling2DWithSourceTensor:(MPSGraphTensor *)source descriptor:(MPSGraphPooling2DOpDescriptor *)descriptor
                                            name:(NSString *_Nullable)name;
- (MPSGraphTensor *)avgPooling2DWithSourceTensor:(MPSGraphTensor *)source descriptor:(MPSGraphPooling2DOpDescriptor *)descriptor
                                            name:(NSString *_Nullable)name;
@end

@interface MPSGraph (GatherOps)
/* slices of updatesTensor along the axis at the indices */
- (MPSGraphTensor *)gatherWithUpdatesTensor:(MPSGraphTensor *)updatesTensor indicesTensor:(MPSGraphTensor *)indicesTensor axis:(NSUInteger)axis
                            batchDimensions:(NSUInteger)batchDimensions name:(NSString *_Nullable)name;
- (MPSGraphTensor *)gatherAlongAxis:(NSInteger)axis withUpdatesTensor:(MPSGraphTensor *)updatesTensor indicesTensor:(MPSGraphTensor *)indicesTensor
                               name:(NSString *_Nullable)name NS_SWIFT_NAME(gatherAlongAxis(_:updates:indices:name:)) API_AVAILABLE(ios(15.4));
@end

@interface MPSGraph (OneHotOps)
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indicesTensor depth:(NSUInteger)depth axis:(NSUInteger)axis dataType:(MPSDataType)dataType
                                    onValue:(double)onValue offValue:(double)offValue name:(NSString *_Nullable)name;
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indicesTensor depth:(NSUInteger)depth dataType:(MPSDataType)dataType
                                    onValue:(double)onValue offValue:(double)offValue name:(NSString *_Nullable)name;
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indicesTensor depth:(NSUInteger)depth axis:(NSUInteger)axis dataType:(MPSDataType)dataType
                                       name:(NSString *_Nullable)name;
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indicesTensor depth:(NSUInteger)depth dataType:(MPSDataType)dataType
                                       name:(NSString *_Nullable)name;
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indicesTensor depth:(NSUInteger)depth axis:(NSUInteger)axis name:(NSString *_Nullable)name;
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indicesTensor depth:(NSUInteger)depth name:(NSString *_Nullable)name;
@end

@interface MPSGraph (TopKOps)
/* the k largest values along the last axis, and their indices (int32) */
- (NSArray<MPSGraphTensor *> *)topKWithSourceTensor:(MPSGraphTensor *)source k:(NSUInteger)k name:(NSString *_Nullable)name
    NS_SWIFT_NAME(topK(_:k:name:)) API_AVAILABLE(ios(15.0));
- (NSArray<MPSGraphTensor *> *)topKWithSourceTensor:(MPSGraphTensor *)source axis:(NSInteger)axis k:(NSUInteger)k name:(NSString *_Nullable)name
    NS_SWIFT_NAME(topK(_:axis:k:name:)) API_AVAILABLE(ios(17.0));
@end

@interface MPSGraph (SortOps)
- (MPSGraphTensor *)sortWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis descending:(BOOL)descending name:(NSString *_Nullable)name
    NS_SWIFT_NAME(sort(_:axis:descending:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)sortWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(sort(_:axis:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)argSortWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis descending:(BOOL)descending name:(NSString *_Nullable)name
    NS_SWIFT_NAME(argSort(_:axis:descending:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)argSortWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(argSort(_:axis:name:)) API_AVAILABLE(ios(16.0));
@end

@interface MPSGraph (CumulativeOps)
- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse
                                       name:(NSString *_Nullable)name NS_SWIFT_NAME(cumulativeSum(_:axis:exclusive:reverse:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeSumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(cumulativeSum(_:axis:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse
                                           name:(NSString *_Nullable)name NS_SWIFT_NAME(cumulativeProduct(_:axis:exclusive:reverse:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeProductWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(cumulativeProduct(_:axis:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse
                                           name:(NSString *_Nullable)name NS_SWIFT_NAME(cumulativeMinimum(_:axis:exclusive:reverse:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(cumulativeMinimum(_:axis:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis exclusive:(BOOL)exclusive reverse:(BOOL)reverse
                                           name:(NSString *_Nullable)name NS_SWIFT_NAME(cumulativeMaximum(_:axis:exclusive:reverse:name:)) API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)cumulativeMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(cumulativeMaximum(_:axis:name:)) API_AVAILABLE(ios(15.4));
@end

@interface MPSGraph (RandomOps)
/* uniform in [0, 1); isim: a xorshift generator seeded per run (or by seed) */
- (MPSGraphTensor *)randomUniformTensorWithShape:(MPSShape *)shape name:(NSString *_Nullable)name API_AVAILABLE(ios(15.4));
- (MPSGraphTensor *)randomUniformTensorWithShape:(MPSShape *)shape seed:(NSUInteger)seed name:(NSString *_Nullable)name API_AVAILABLE(ios(15.4));
@end

@interface MPSGraph (DropoutOps)
/* each element zeroed with the probability rate, the others scaled by 1 / (1 - rate) */
- (MPSGraphTensor *)dropoutTensor:(MPSGraphTensor *)tensor rate:(double)rate name:(NSString *_Nullable)name
    NS_SWIFT_NAME(dropout(_:rate:name:)) API_AVAILABLE(ios(15.0));
@end

NS_ASSUME_NONNULL_END
