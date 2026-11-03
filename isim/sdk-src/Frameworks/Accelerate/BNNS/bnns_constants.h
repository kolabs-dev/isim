#pragma once
/* isim Accelerate: BNNS's constants (Apple's bnns_constants.h) (issue #808), over isim's C implementation (frameworks/Accelerate/bnns*.c).
   Enumeration values and structure layouts are Apple's, so code built against Apple's SDK passes the same data. */
#include <stdint.h>
#define BNNS_ENUM(_name, _type, ...) typedef enum : _type { __VA_ARGS__ } _name
#if __has_feature(assume_nonnull)
#pragma clang assume_nonnull begin
#else
#define _Null_unspecified
#define _Nullable
#define _Nonnull
#endif
#ifdef __cplusplus
extern "C" {
#endif

BNNS_ENUM(BNNSDataType, uint32_t,

  BNNSDataTypeFloatBit          = 0x10000,
  BNNSDataTypeFloat16           = BNNSDataTypeFloatBit | 16,
  BNNSDataTypeFloat32           = BNNSDataTypeFloatBit | 32,
  BNNSDataTypeBFloat16          = BNNSDataTypeFloatBit | 0x8000 | 16,

  BNNSDataTypeIntBit            = 0x20000,
  BNNSDataTypeInt1              = BNNSDataTypeIntBit | 1,
  BNNSDataTypeInt2              = BNNSDataTypeIntBit | 2,
  BNNSDataTypeInt4              = BNNSDataTypeIntBit | 4,
  BNNSDataTypeInt8              = BNNSDataTypeIntBit | 8,
  BNNSDataTypeInt16             = BNNSDataTypeIntBit | 16,
  BNNSDataTypeInt32             = BNNSDataTypeIntBit | 32,
  BNNSDataTypeInt64             = BNNSDataTypeIntBit | 64,

  BNNSDataTypeUIntBit           = 0x40000,
  BNNSDataTypeUInt1             = BNNSDataTypeUIntBit | 1,
  BNNSDataTypeUInt2             = BNNSDataTypeUIntBit | 2,
  BNNSDataTypeUInt3             = BNNSDataTypeUIntBit | 3,
  BNNSDataTypeUInt4             = BNNSDataTypeUIntBit | 4,
  BNNSDataTypeUInt6             = BNNSDataTypeUIntBit | 6,
  BNNSDataTypeUInt8             = BNNSDataTypeUIntBit | 8,
  BNNSDataTypeUInt16            = BNNSDataTypeUIntBit | 16,
  BNNSDataTypeUInt32            = BNNSDataTypeUIntBit | 32,
  BNNSDataTypeUInt64            = BNNSDataTypeUIntBit | 64,

  BNNSDataTypeIndexedBit        = 0x80000,
  BNNSDataTypeIndexed1          = BNNSDataTypeIndexedBit | 1,
  BNNSDataTypeIndexed2          = BNNSDataTypeIndexedBit | 2,
  BNNSDataTypeIndexed4          = BNNSDataTypeIndexedBit | 4,
  BNNSDataTypeIndexed8          = BNNSDataTypeIndexedBit | 8,

  BNNSDataTypeMiscellaneousBit  = 0x100000,
  BNNSDataTypeBoolean           = BNNSDataTypeMiscellaneousBit | 8,
);

BNNS_ENUM(BNNSPoolingFunction, uint32_t,

  BNNSPoolingFunctionMax                         = 0,
  BNNSPoolingFunctionAverageCountIncludePadding  = 1,
  BNNSPoolingFunctionAverageCountExcludePadding  = 2,
  BNNSPoolingFunctionUnMax                       = 3,
  BNNSPoolingFunctionL2Norm                      = 4,

  BNNSPoolingFunctionAverage   = BNNSPoolingFunctionAverageCountIncludePadding,

);

BNNS_ENUM(BNNSActivationFunction, uint32_t,

  BNNSActivationFunctionIdentity                          =  0,
  BNNSActivationFunctionRectifiedLinear                   =  1,
  BNNSActivationFunctionLeakyRectifiedLinear              =  2,
  BNNSActivationFunctionSigmoid                           =  3,
  BNNSActivationFunctionTanh                              =  4,
  BNNSActivationFunctionScaledTanh                        =  5,
  BNNSActivationFunctionAbs                               =  6,
  BNNSActivationFunctionLinear                            =  7,
  BNNSActivationFunctionClamp                             =  8,
  BNNSActivationFunctionIntegerLinearSaturate             =  9,
  BNNSActivationFunctionIntegerLinearSaturatePerChannel   = 10,
  BNNSActivationFunctionSoftmax                           = 11,
  BNNSActivationFunctionGELUApproximation                 = 12,
  BNNSActivationFunctionGumbel                            = 13,
  BNNSActivationFunctionGumbelMax                         = 14,
  BNNSActivationFunctionHardSigmoid                       = 15,
  BNNSActivationFunctionSoftplus                          = 16,
  BNNSActivationFunctionSoftsign                          = 17,
  BNNSActivationFunctionELU                               = 18,
  BNNSActivationFunctionClampedLeakyRectifiedLinear       = 19,
  BNNSActivationFunctionLinearWithBias                    = 20,
  BNNSActivationFunctionLogSoftmax                        = 21,
  BNNSActivationFunctionLogSigmoid                        = 22,
  BNNSActivationFunctionSELU                              = 23,
  BNNSActivationFunctionCELU                              = 24,
  BNNSActivationFunctionHardShrink                        = 25,
  BNNSActivationFunctionSoftShrink                        = 26,
  BNNSActivationFunctionTanhShrink                        = 27,
  BNNSActivationFunctionThreshold                         = 28,
  BNNSActivationFunctionPReLUPerChannel                   = 29,
  BNNSActivationFunctionGELUApproximation2                = 30,
  BNNSActivationFunctionHardSwish                         = BNNSActivationFunctionGELUApproximation2,
  BNNSActivationFunctionSiLU                              = 31,
  BNNSActivationFunctionReLU6                             = 32,
  BNNSActivationFunctionErf                               = 33,
  BNNSActivationFunctionGELU                              = 34,
  BNNSActivationFunctionGELUApproximationSigmoid          = 35,

);

BNNS_ENUM(BNNSFlags, uint32_t,

          BNNSFlagsUseClientPtr   = 0x0001,
          );

BNNS_ENUM(BNNSLossFunction, uint32_t,

          BNNSLossFunctionSoftmaxCrossEntropy       =  1,
          BNNSLossFunctionSigmoidCrossEntropy       =  2,
          BNNSLossFunctionMeanSquareError           =  3,
          BNNSLossFunctionHuber                     =  4,
          BNNSLossFunctionYolo                      =  5,
          BNNSLossFunctionLog                       =  6,
          BNNSLossFunctionCosineDistance            =  7,
          BNNSLossFunctionHinge                     =  8,
          BNNSLossFunctionMeanAbsoluteError         =  9,
          BNNSLossFunctionCategoricalCrossEntropy   = 10,
          );

BNNS_ENUM(BNNSLossReductionFunction, uint32_t,

          BNNSLossReductionNone                = 0,
          BNNSLossReductionSum                 = 1,
          BNNSLossReductionWeightedMean        = 2,
          BNNSLossReductionMean                = 3,
          BNNSLossReductionNonZeroWeightMean   = 4,
          );

BNNS_ENUM(BNNSArithmeticFunction, uint32_t,

          BNNSArithmeticAdd                    =  0,
          BNNSArithmeticSubtract               =  1,
          BNNSArithmeticMultiply               =  2,
          BNNSArithmeticDivide                 =  3,
          BNNSArithmeticSquareRoot             =  4,
          BNNSArithmeticReciprocalSquareRoot   =  5,
          BNNSArithmeticCeil                   =  6,
          BNNSArithmeticFloor                  =  7,
          BNNSArithmeticRound                  =  8,
          BNNSArithmeticSin                    =  9,
          BNNSArithmeticCos                    = 10,
          BNNSArithmeticTan                    = 11,
          BNNSArithmeticAsin                   = 12,
          BNNSArithmeticAcos                   = 13,
          BNNSArithmeticAtan                   = 14,
          BNNSArithmeticSinh                   = 15,
          BNNSArithmeticCosh                   = 16,
          BNNSArithmeticTanh                   = 17,
          BNNSArithmeticAsinh                  = 18,
          BNNSArithmeticAcosh                  = 19,
          BNNSArithmeticAtanh                  = 20,
          BNNSArithmeticPow                    = 21,
          BNNSArithmeticExp                    = 22,
          BNNSArithmeticExp2                   = 23,
          BNNSArithmeticLog                    = 24,
          BNNSArithmeticLog2                   = 25,
          BNNSArithmeticMultiplyNoNaN          = 26,
          BNNSArithmeticDivideNoNaN            = 27,
          BNNSArithmeticMultiplyAdd            = 28,
          BNNSArithmeticMinimum                = 29,
          BNNSArithmeticMaximum                = 30,
          BNNSArithmeticSelect                 = 31,
          BNNSArithmeticAbs                    = 32,
          BNNSArithmeticSign                   = 33,
          BNNSArithmeticNegate                 = 34,
          BNNSArithmeticReciprocal             = 35,
          BNNSArithmeticSquare                 = 36,
          BNNSArithmeticFloorDivide            = 37,
          BNNSArithmeticTruncDivide            = 38,
          BNNSArithmeticTruncRemainder         = 39,
          BNNSArithmeticErf                    = 40,
          );

BNNS_ENUM(BNNSDescriptorType, uint32_t,

          BNNSConstant    = 0,
          BNNSSample      = 1,
          BNNSParameter   = 2
          );

BNNS_ENUM(BNNSOptimizerFunction, uint32_t,

          BNNSOptimizerFunctionSGDMomentum   = 1,
          BNNSOptimizerFunctionAdam          = 2,
          BNNSOptimizerFunctionRMSProp       = 3,
          BNNSOptimizerFunctionAdamW         = 4,
          BNNSOptimizerFunctionAdamAMSGrad   = 5,
          BNNSOptimizerFunctionAdamWAMSGrad  = 6,

          BNNSOptimizerFunctionSGDMomentumWithClipping   = 7,
          BNNSOptimizerFunctionAdamWithClipping          = 8,
          BNNSOptimizerFunctionRMSPropWithClipping       = 9,
          BNNSOptimizerFunctionAdamWWithClipping         = 10,
          BNNSOptimizerFunctionAdamAMSGradWithClipping   = 11,
          BNNSOptimizerFunctionAdamWAMSGradWithClipping  = 12,
          );

BNNS_ENUM(BNNSOptimizerRegularizationFunction, uint32_t,

          BNNSOptimizerRegularizationNone   = 0,
          BNNSOptimizerRegularizationL1     = 1,
          BNNSOptimizerRegularizationL2     = 2,

          );

BNNS_ENUM(BNNSOptimizerSGDMomentumVariant, uint32_t,

          BNNSSGDMomentumVariant0   = 0,
          BNNSSGDMomentumVariant1   = 1,
          BNNSSGDMomentumVariant2   = 2,

          );

BNNS_ENUM(BNNSOptimizerClippingFunction, uint32_t,

          BNNSOptimizerClippingNone          = 0,
          BNNSOptimizerClippingByValue       = 1,
          BNNSOptimizerClippingByNorm        = 2,
          BNNSOptimizerClippingByGlobalNorm  = 3,
          );

BNNS_ENUM(BNNSNormType, uint32_t,

          BNNSL2Norm         = 1,
);

BNNS_ENUM(BNNSFilterType, uint32_t,

          BNNSConvolution             = 0,
          BNNSFullyConnected          = 1,
          BNNSBatchNorm               = 2,
          BNNSInstanceNorm            = 3,
          BNNSLayerNorm               = 4,
          BNNSGroupNorm               = 5,
          BNNSTransposedConvolution   = 6,
          BNNSQuantization            = 7,
          BNNSArithmetic              = 8,
          );

BNNS_ENUM(BNNSReduceFunction, uint32_t,

          BNNSReduceFunctionMax           = 0,
          BNNSReduceFunctionMin           = 1,
          BNNSReduceFunctionArgMax        = 2,
          BNNSReduceFunctionArgMin        = 3,
          BNNSReduceFunctionMean          = 4,
          BNNSReduceFunctionMeanNonZero   = 5,
          BNNSReduceFunctionSum           = 6,
          BNNSReduceFunctionSumSquare     = 7,
          BNNSReduceFunctionSumLog        = 8,
          BNNSReduceFunctionL1Norm        = 9,
          BNNSReduceFunctionLogicalOr     = 10,
          BNNSReduceFunctionLogicalAnd    = 11,
          BNNSReduceFunctionL2Norm        = 12,
          BNNSReduceFunctionLogSumExp     = 13,
          BNNSReduceFunctionProduct       = 14,
          BNNSReduceFunctionNone          = 15,
          BNNSReduceFunctionLogSum        = 16,

          BNNSReduceFunctionAny            = BNNSReduceFunctionLogicalOr,
          BNNSReduceFunctionAll            = BNNSReduceFunctionLogicalAnd,
          );

BNNS_ENUM(BNNSLayerFlags, uint32_t,

          BNNSLayerFlagsLSTMBidirectional        = 0x0001,
          BNNSLayerFlagsLSTMDefaultActivations   = 0x0002,
          );

BNNS_ENUM(BNNSDataLayout, uint32_t,

  BNNSDataLayoutVector                          = 0x10000,
  BNNSDataLayout1DLastMajor                     = 0x18000,
  BNNSDataLayout1DFirstMajor                    = 0x18001,

  BNNSDataLayoutRowMajorMatrix                  = 0x20000,
  BNNSDataLayoutColumnMajorMatrix               = 0x20001,
  BNNSDataLayout2DLastMajor                     = 0x28000,
  BNNSDataLayout2DFirstMajor                    = 0x28001,
  BNNSDataLayoutFullyConnectedSparse            = 0x21001,

  BNNSDataLayoutImageCHW                        = 0x30000,
  BNNSDataLayoutSNE                             = 0x30001,
  BNNSDataLayoutNSE                             = 0x30002,
  BNNSDataLayoutMHA_DHK                         = 0x30003,
  BNNSDataLayout3DLastMajor                     = 0x38000,
  BNNSDataLayout3DFirstMajor                    = 0x38001,

  BNNSDataLayoutConvolutionWeightsOIHW          = 0x40000,
  BNNSDataLayoutConvolutionWeightsOIHrWr        = 0x40001,
  BNNSDataLayoutConvolutionWeightsIOHrWr        = 0x40002,
  BNNSDataLayoutConvolutionWeightsOIHW_Pack32   = 0x40010,
  BNNSDataLayout4DLastMajor                     = 0x48000,
  BNNSDataLayout4DFirstMajor                    = 0x48001,

  BNNSDataLayout5DLastMajor                     = 0x58000,
  BNNSDataLayout5DFirstMajor                    = 0x58001,

  BNNSDataLayout6DLastMajor                     = 0x68000,
  BNNSDataLayout6DFirstMajor                    = 0x68001,

  BNNSDataLayout7DLastMajor                     = 0x78000,
  BNNSDataLayout7DFirstMajor                    = 0x78001,

  BNNSDataLayout8DLastMajor                     = 0x88000,
  BNNSDataLayout8DFirstMajor                    = 0x88001,
);

BNNS_ENUM(BNNSInterpolationMethod, uint32_t,

          BNNSInterpolationMethodNearest   = 0,
          BNNSInterpolationMethodLinear    = 1,
          );

BNNS_ENUM(BNNSLinearSamplingMode, uint32_t,

          BNNSLinearSamplingDefault              = 0,
          BNNSLinearSamplingAlignCorners         = 1,
          BNNSLinearSamplingUnalignCorners       = 2,
          BNNSLinearSamplingStrictAlignCorners   = 3,
          BNNSLinearSamplingOffsetCorners        = 4,
          );

BNNS_ENUM(BNNSBoxCoordinateMode, uint32_t,

          BNNSCornersHeightFirst           = 0,
          BNNSCornersWidthFirst            = 1,
          BNNSCenterSizeHeightFirst        = 2,
          BNNSCenterSizeWidthFirst         = 3,
          );

BNNS_ENUM(BNNSPaddingMode, uint32_t,
    BNNSPaddingModeConstant    = 0,
    BNNSPaddingModeReflect     = 1,
    BNNSPaddingModeSymmetric   = 2,
);

BNNS_ENUM(BNNSRelationalOperator, uint32_t,
    BNNSRelationalOperatorEqual          =  0,
    BNNSRelationalOperatorLess           =  1,
    BNNSRelationalOperatorLessEqual      =  2,
    BNNSRelationalOperatorGreater        =  3,
    BNNSRelationalOperatorGreaterEqual   =  4,
    BNNSRelationalOperatorNotEqual       =  5,
    BNNSRelationalOperatorLogicalAND     =  6,
    BNNSRelationalOperatorLogicalOR      =  7,
    BNNSRelationalOperatorLogicalNOT     =  8,
    BNNSRelationalOperatorLogicalNAND    =  9,
    BNNSRelationalOperatorLogicalNOR     = 10,
    BNNSRelationalOperatorLogicalXOR     = 11,
);

BNNS_ENUM(BNNSPointerSpecifier, uint32_t,

          BNNSPointerSpecifierAlpha   = 0,
          BNNSPointerSpecifierBeta    = 1
          );

BNNS_ENUM(BNNSNDArrayFlags, uint32_t,

          BNNSNDArrayFlagBackpropSet           = 0,
          BNNSNDArrayFlagBackpropAccumulate    = 1,
          );

BNNS_ENUM(BNNSEmbeddingFlags, uint32_t,
          BNNSEmbeddingFlagScaleGradientByFrequency      = 1,
          );

BNNS_ENUM(BNNSQuantizerFunction, uint32_t,
          BNNSQuantizerFunctionQuantize                = 0,
          BNNSQuantizerFunctionDequantize              = 1
          );

BNNS_ENUM(BNNSRandomGeneratorMethod, uint32_t,
          BNNSRandomGeneratorMethodAES_CTR       = 0,
);

BNNS_ENUM(BNNSSparsityType, uint32_t,
          BNNSSparsityTypeUnstructured  = 0x0,
);

BNNS_ENUM(BNNSTargetSystem, uint32_t,
          BNNSTargetSystemGeneric       = 0,
);

BNNS_ENUM(BNNSShuffleType, uint32_t,
          BNNSShuffleTypePixelShuffleNCHW      = 0,
          BNNSShuffleTypePixelUnshuffleNCHW    = 1,
          BNNSShuffleTypeDepthToSpaceNCHW      = 2,
          BNNSShuffleTypeSpaceToDepthNCHW      = 3,
);


#undef BNNS_ENUM

#ifdef __cplusplus
}
#endif
#if __has_feature(assume_nonnull)
#pragma clang assume_nonnull end
#endif
