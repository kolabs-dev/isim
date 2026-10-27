// isim MetalPerformanceShadersGraph: matrix multiplication, reductions, normalization, activations, shapes, losses,
// gradients and optimizers. Axes may be negative (counted from the last).
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraph.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPSGraph (MatrixMultiplicationOps)
/* batched over the leading dimensions (broadcast); the last two are the matrices */
- (MPSGraphTensor *)matrixMultiplicationWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                                     name:(NSString *_Nullable)name NS_SWIFT_NAME(matrixMultiplication(primary:secondary:name:));
@end

@interface MPSGraph (ReductionOps)
- (MPSGraphTensor *)reductionSumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionSumWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *_Nullable)axes name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionMaximumWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *_Nullable)axes name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionMinimumWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *_Nullable)axes name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionProductWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionProductWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *_Nullable)axes name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reductionArgMaximumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)reductionArgMinimumWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)reductionAndWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *_Nullable)axes name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)reductionOrWithTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *_Nullable)axes name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
@end

@interface MPSGraph (NormalizationOps)
- (MPSGraphTensor *)meanOfTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *_Nullable)name;
- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *_Nullable)name;
- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)tensor meanTensor:(MPSGraphTensor *)meanTensor axes:(NSArray<NSNumber *> *)axes
                                name:(NSString *_Nullable)name;
/* (x - mean) / sqrt(variance + epsilon) * gamma + beta */
- (MPSGraphTensor *)normalizationWithTensor:(MPSGraphTensor *)tensor meanTensor:(MPSGraphTensor *)mean varianceTensor:(MPSGraphTensor *)variance
                                gammaTensor:(MPSGraphTensor *_Nullable)gamma betaTensor:(MPSGraphTensor *_Nullable)beta epsilon:(float)epsilon
                                       name:(NSString *_Nullable)name NS_SWIFT_NAME(normalize(_:mean:variance:gamma:beta:epsilon:name:));
@end

@interface MPSGraph (ActivationOps)
- (MPSGraphTensor *)reLUWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reLUGradientWithIncomingGradient:(MPSGraphTensor *)gradient sourceTensor:(MPSGraphTensor *)source name:(NSString *_Nullable)name;
- (MPSGraphTensor *)sigmoidWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)sigmoidGradientWithIncomingGradient:(MPSGraphTensor *)gradient sourceTensor:(MPSGraphTensor *)source name:(NSString *_Nullable)name;
- (MPSGraphTensor *)softMaxWithTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name;
- (MPSGraphTensor *)softMaxGradientWithIncomingGradient:(MPSGraphTensor *)gradient sourceTensor:(MPSGraphTensor *)source axis:(NSInteger)axis
                                                   name:(NSString *_Nullable)name;
- (MPSGraphTensor *)leakyReLUWithTensor:(MPSGraphTensor *)tensor alpha:(double)alpha name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)leakyReLUWithTensor:(MPSGraphTensor *)tensor alphaTensor:(MPSGraphTensor *)alphaTensor name:(NSString *_Nullable)name
    API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)leakyReLUGradientWithIncomingGradient:(MPSGraphTensor *)gradient sourceTensor:(MPSGraphTensor *)source
                                              alphaTensor:(MPSGraphTensor *)alphaTensor name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
@end

@interface MPSGraph (TensorShapeOps)
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor withShape:(MPSShape *)shape name:(NSString *_Nullable)name NS_SWIFT_NAME(reshape(_:shape:name:));
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)tensor withShapeTensor:(MPSGraphTensor *)shapeTensor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(reshape(_:shapeTensor:name:)) API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor dimension:(NSUInteger)dimensionIndex withDimension:(NSUInteger)dimensionIndex2
                               name:(NSString *_Nullable)name;
- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)tensor permutation:(NSArray<NSNumber *> *)permutation name:(NSString *_Nullable)name
    NS_SWIFT_NAME(transpose(_:permutation:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor dimension:(NSUInteger)dimensionIndex start:(NSInteger)start length:(NSInteger)length
                           name:(NSString *_Nullable)name;
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)tensor starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends
                        strides:(NSArray<NSNumber *> *)strides name:(NSString *_Nullable)name;
- (MPSGraphTensor *)concatTensor:(MPSGraphTensor *)tensor withTensor:(MPSGraphTensor *)tensor2 dimension:(NSInteger)dimensionIndex
                            name:(NSString *_Nullable)name NS_SWIFT_NAME(concatTensor(_:with:dimension:name:));
- (MPSGraphTensor *)concatTensors:(NSArray<MPSGraphTensor *> *)tensors dimension:(NSInteger)dimensionIndex name:(NSString *_Nullable)name
    NS_SWIFT_NAME(concatTensors(_:dimension:name:));
- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)tensor toShape:(MPSShape *)shape name:(NSString *_Nullable)name NS_SWIFT_NAME(broadcast(_:shape:name:));
- (MPSGraphTensor *)shapeOfTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name NS_SWIFT_NAME(shapeOf(_:name:));
- (MPSGraphTensor *)castTensor:(MPSGraphTensor *)tensor toType:(MPSDataType)type name:(NSString *)name NS_SWIFT_NAME(cast(_:to:name:));
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(expandDims(_:axis:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *_Nullable)name
    NS_SWIFT_NAME(expandDims(_:axes:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name NS_SWIFT_NAME(squeeze(_:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(squeeze(_:axis:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *_Nullable)name
    NS_SWIFT_NAME(squeeze(_:axes:name:)) API_AVAILABLE(ios(16.0));
- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)tensor axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(flatten2D(_:axis:name:)) API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)tensor withMultiplier:(MPSShape *)multiplier name:(NSString *_Nullable)name;
- (MPSGraphTensor *)padTensor:(MPSGraphTensor *)tensor withPaddingMode:(MPSGraphPaddingMode)paddingMode leftPadding:(MPSShape *)leftPadding
                 rightPadding:(MPSShape *)rightPadding constantValue:(double)constantValue name:(NSString *_Nullable)name
    NS_SWIFT_NAME(padTensor(_:with:leftPadding:rightPadding:constantValue:name:));
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor axes:(NSArray<NSNumber *> *)axes name:(NSString *_Nullable)name
    NS_SWIFT_NAME(reverse(_:axes:name:)) API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name NS_SWIFT_NAME(reverse(_:name:)) API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)stackTensors:(NSArray<MPSGraphTensor *> *)inputTensors axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(stack(_:axis:name:)) API_AVAILABLE(ios(15.4));
- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)tensor numSplits:(NSUInteger)numSplits axis:(NSInteger)axis name:(NSString *_Nullable)name
    NS_SWIFT_NAME(split(_:numSplits:axis:name:)) API_AVAILABLE(ios(15.4));
- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)tensor splitSizes:(NSArray<NSNumber *> *)splitSizes axis:(NSInteger)axis
                                      name:(NSString *_Nullable)name NS_SWIFT_NAME(split(_:splitSizes:axis:name:)) API_AVAILABLE(ios(15.4));
@end

typedef NS_ENUM(uint64_t, MPSGraphLossReductionType) {
    MPSGraphLossReductionTypeNone = 0,
    MPSGraphLossReductionTypeAxis = 0,
    MPSGraphLossReductionTypeSum = 1,
    MPSGraphLossReductionTypeMean = 2,
} API_AVAILABLE(ios(14.0));

@interface MPSGraph (LossOps)
/* -sum(labels * log(softmax(source))) along the axis, then reduced over the batch */
- (MPSGraphTensor *)softMaxCrossEntropyWithSourceTensor:(MPSGraphTensor *)sourceTensor labelsTensor:(MPSGraphTensor *)labelsTensor axis:(NSInteger)axis
                                          reductionType:(MPSGraphLossReductionType)reductionType name:(NSString *_Nullable)name
    NS_SWIFT_NAME(softMaxCrossEntropy(_:labels:axis:reuctionType:name:));
- (MPSGraphTensor *)softMaxCrossEntropyGradientWithIncomingGradientTensor:(MPSGraphTensor *)gradientTensor sourceTensor:(MPSGraphTensor *)sourceTensor
                                                             labelsTensor:(MPSGraphTensor *)labelsTensor axis:(NSInteger)axis
                                                            reductionType:(MPSGraphLossReductionType)reductionType name:(NSString *_Nullable)name;
@end

typedef NSDictionary<MPSGraphTensor *, MPSGraphTensor *> MPSGraphTensorDictionary;
@interface MPSGraph (GradientOps)
/* d(primaryTensor) / d(each tensor), built from the operations between them (reverse-mode, symbolic) */
- (MPSGraphTensorDictionary *)gradientForPrimaryTensor:(MPSGraphTensor *)primaryTensor withTensors:(NSArray<MPSGraphTensor *> *)tensors
                                                  name:(NSString *_Nullable)name NS_SWIFT_NAME(gradients(of:with:name:));
@end

@interface MPSGraph (OptimizerOps)
/* values - learningRate * gradient */
- (MPSGraphTensor *)stochasticGradientDescentWithLearningRateTensor:(MPSGraphTensor *)learningRateTensor valuesTensor:(MPSGraphTensor *)valuesTensor
                                                     gradientTensor:(MPSGraphTensor *)gradientTensor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(stochasticGradientDescent(learningRate:values:gradient:name:));
/* assigns values - learningRate * gradient to the variable */
- (MPSGraphOperation *)applyStochasticGradientDescentWithLearningRateTensor:(MPSGraphTensor *)learningRateTensor variable:(MPSGraphTensor *)variable
                                                             gradientTensor:(MPSGraphTensor *)gradientTensor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(applyStochasticGradientDescent(learningRate:variable:gradient:name:)) API_AVAILABLE(ios(14.0));
/* Adam: returns the new values, momentum and velocity */
- (NSArray<MPSGraphTensor *> *)adamWithLearningRateTensor:(MPSGraphTensor *)learningRateTensor beta1Tensor:(MPSGraphTensor *)beta1Tensor
                                              beta2Tensor:(MPSGraphTensor *)beta2Tensor epsilonTensor:(MPSGraphTensor *)epsilonTensor
                                         beta1PowerTensor:(MPSGraphTensor *)beta1PowerTensor beta2PowerTensor:(MPSGraphTensor *)beta2PowerTensor
                                             valuesTensor:(MPSGraphTensor *)valuesTensor momentumTensor:(MPSGraphTensor *)momentumTensor
                                           velocityTensor:(MPSGraphTensor *)velocityTensor gradientTensor:(MPSGraphTensor *)gradientTensor
                                                     name:(NSString *_Nullable)name
    NS_SWIFT_NAME(adam(learningRate:beta1:beta2:epsilon:beta1Power:beta2Power:values:momentum:velocity:gradient:name:)) API_AVAILABLE(ios(15.0));
@end

NS_ASSUME_NONNULL_END
