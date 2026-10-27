// isim MetalPerformanceShaders: matrix kernels (adapted: isim's Accelerate BLAS and LAPACK, on the CPU)
#pragma once
#import <MetalPerformanceShaders/MPSMatrix.h>
#import <MetalPerformanceShaders/MPSNeuralNetworkTypes.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(11.0))
@interface MPSMatrixUnaryKernel : MPSKernel
@property (readwrite, nonatomic) MTLOrigin sourceMatrixOrigin;
@property (readwrite, nonatomic) MTLOrigin resultMatrixOrigin;
@property (readwrite, nonatomic) NSUInteger batchStart;
@property (readwrite, nonatomic) NSUInteger batchSize;
@end

API_AVAILABLE(ios(11.0))
@interface MPSMatrixBinaryKernel : MPSKernel
@property (readwrite, nonatomic) MTLOrigin primarySourceMatrixOrigin;
@property (readwrite, nonatomic) MTLOrigin secondarySourceMatrixOrigin;
@property (readwrite, nonatomic) MTLOrigin resultMatrixOrigin;
@property (readwrite, nonatomic) NSUInteger batchStart;
@property (readwrite, nonatomic) NSUInteger batchSize;
@end

/* C = alpha * op(A) * op(B) + beta * C (float32 and float16) */
API_AVAILABLE(ios(10.0))
@interface MPSMatrixMultiplication : MPSKernel
@property (readwrite, nonatomic) MTLOrigin resultMatrixOrigin;
@property (readwrite, nonatomic) MTLOrigin leftMatrixOrigin;
@property (readwrite, nonatomic) MTLOrigin rightMatrixOrigin;
@property (readwrite, nonatomic) NSUInteger batchStart API_AVAILABLE(ios(11.0));
@property (readwrite, nonatomic) NSUInteger batchSize API_AVAILABLE(ios(11.0));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device transposeLeft:(BOOL)transposeLeft transposeRight:(BOOL)transposeRight
                            resultRows:(NSUInteger)resultRows resultColumns:(NSUInteger)resultColumns interiorColumns:(NSUInteger)interiorColumns
                                 alpha:(double)alpha beta:(double)beta NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device resultRows:(NSUInteger)resultRows resultColumns:(NSUInteger)resultColumns
                       interiorColumns:(NSUInteger)interiorColumns API_AVAILABLE(ios(11.0));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer leftMatrix:(MPSMatrix *__nonnull)leftMatrix
                  rightMatrix:(MPSMatrix *__nonnull)rightMatrix resultMatrix:(MPSMatrix *__nonnull)resultMatrix
    NS_SWIFT_NAME(encode(commandBuffer:leftMatrix:rightMatrix:resultMatrix:));
@end

/* y = alpha * op(A) * x + beta * y */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixVectorMultiplication : MPSMatrixBinaryKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device transpose:(BOOL)transpose rows:(NSUInteger)rows columns:(NSUInteger)columns
                                 alpha:(double)alpha beta:(double)beta NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device rows:(NSUInteger)rows columns:(NSUInteger)columns;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer inputMatrix:(MPSMatrix *__nonnull)inputMatrix
                  inputVector:(MPSVector *__nonnull)inputVector resultVector:(MPSVector *__nonnull)resultVector
    NS_SWIFT_NAME(encode(commandBuffer:inputMatrix:inputVector:resultVector:));
@end

/* the sum of count matrices, each scaled, plus an offset and a bias, through a neuron */
API_AVAILABLE(ios(11.3))
@interface MPSMatrixSum : MPSKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device count:(NSUInteger)count rows:(NSUInteger)rows columns:(NSUInteger)columns
                             transpose:(BOOL)transpose NS_DESIGNATED_INITIALIZER;
@property (readonly, nonatomic) NSUInteger rows;
@property (readonly, nonatomic) NSUInteger columns;
@property (readonly, nonatomic) NSUInteger count;
@property (readonly, nonatomic) BOOL transpose;
@property (readwrite, nonatomic) MTLOrigin resultMatrixOrigin API_AVAILABLE(ios(12.0));
- (void)setNeuronType:(MPSCNNNeuronType)neuronType parameterA:(float)parameterA parameterB:(float)parameterB parameterC:(float)parameterC;
- (MPSCNNNeuronType)neuronType;
- (float)neuronParameterA;
- (float)neuronParameterB;
- (float)neuronParameterC;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)buffer sourceMatrices:(NSArray<MPSMatrix *> *__nonnull)sourceMatrices
                 resultMatrix:(MPSMatrix *__nonnull)resultMatrix scaleVector:(MPSVector *__nullable)scaleVector
                 offsetVector:(MPSVector *__nullable)offsetVector biasVector:(MPSVector *__nullable)biasVector startIndex:(NSUInteger)startIndex
    NS_SWIFT_NAME(encode(to:sourceMatrices:resultMatrix:scale:offsetVector:biasVector:start:));
@end

/* the softmax of each row (or its logarithm) */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixSoftMax : MPSMatrixUnaryKernel
@property (readwrite, nonatomic) NSUInteger sourceRows;
@property (readwrite, nonatomic) NSUInteger sourceColumns;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer inputMatrix:(MPSMatrix *__nonnull)inputMatrix
                 resultMatrix:(MPSMatrix *__nonnull)resultMatrix NS_SWIFT_NAME(encode(commandBuffer:inputMatrix:resultMatrix:));
@end
API_AVAILABLE(ios(11.0))
@interface MPSMatrixLogSoftMax : MPSMatrixSoftMax
@end

/* the K largest values of each row and their column indices (uint32) */
API_AVAILABLE(ios(11.3))
@interface MPSMatrixFindTopK : MPSMatrixUnaryKernel
@property (readwrite, nonatomic) NSUInteger sourceRows;
@property (readwrite, nonatomic) NSUInteger sourceColumns;
@property (readwrite, nonatomic) NSUInteger indexOffset;
@property (readwrite, nonatomic) NSUInteger numberOfTopKValues;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device numberOfTopKValues:(NSUInteger)numberOfTopKValues NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer inputMatrix:(MPSMatrix *__nonnull)inputMatrix
            resultIndexMatrix:(MPSMatrix *__nonnull)resultIndexMatrix resultValueMatrix:(MPSMatrix *__nonnull)resultValueMatrix
    NS_SWIFT_NAME(encode(commandBuffer:inputMatrix:resultIndexMatrix:resultValueMatrix:));
@end

/* a neuron of alpha * x + bias, row by row */
API_AVAILABLE(ios(11.3))
@interface MPSMatrixNeuron : MPSMatrixUnaryKernel
@property (readwrite, nonatomic) NSUInteger sourceNumberOfFeatureVectors;
@property (readwrite, nonatomic) NSUInteger sourceInputFeatureChannels;
@property (readwrite, nonatomic) double alpha;
- (void)setNeuronType:(MPSCNNNeuronType)neuronType parameterA:(float)parameterA parameterB:(float)parameterB parameterC:(float)parameterC;
- (MPSCNNNeuronType)neuronType;
- (float)neuronParameterA;
- (float)neuronParameterB;
- (float)neuronParameterC;
- (void)setNeuronToPReLUWithParametersA:(NSData *__nonnull)A;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer inputMatrix:(MPSMatrix *__nonnull)inputMatrix
                   biasVector:(MPSVector *__nullable)biasVector resultMatrix:(MPSMatrix *__nonnull)resultMatrix
    NS_SWIFT_NAME(encode(commandBuffer:inputMatrix:biasVector:resultMatrix:));
@end

typedef NS_ENUM(int, MPSMatrixDecompositionStatus) {
    MPSMatrixDecompositionStatusSuccess = 0,
    MPSMatrixDecompositionStatusFailure = -1,
    MPSMatrixDecompositionStatusSingular = -2,
    MPSMatrixDecompositionStatusNonPositiveDefinite = -3,
} API_AVAILABLE(ios(11.0));

/* P * A = L * U with partial pivoting (pivot indices: uint32) */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixDecompositionLU : MPSMatrixUnaryKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device rows:(NSUInteger)rows columns:(NSUInteger)columns NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceMatrix:(MPSMatrix *__nonnull)sourceMatrix
                 resultMatrix:(MPSMatrix *__nonnull)resultMatrix pivotIndices:(MPSMatrix *__nonnull)pivotIndices
                       status:(__nullable id<MTLBuffer>)status NS_SWIFT_NAME(encode(commandBuffer:sourceMatrix:resultMatrix:pivotIndices:info:));
@end

/* A = L * L^T (lower) or U^T * U */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixDecompositionCholesky : MPSMatrixUnaryKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device lower:(BOOL)lower order:(NSUInteger)order NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceMatrix:(MPSMatrix *__nonnull)sourceMatrix
                 resultMatrix:(MPSMatrix *__nonnull)resultMatrix status:(__nullable id<MTLBuffer>)status
    NS_SWIFT_NAME(encode(commandBuffer:sourceMatrix:resultMatrix:status:));
@end

/* solves op(A) * X = alpha * B (left) or X * op(A) = alpha * B (right), A triangular */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixSolveTriangular : MPSMatrixBinaryKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device right:(BOOL)right upper:(BOOL)upper transpose:(BOOL)transpose unit:(BOOL)unit
                                 order:(NSUInteger)order numberOfRightHandSides:(NSUInteger)numberOfRightHandSides alpha:(double)alpha
    NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceMatrix:(MPSMatrix *__nonnull)sourceMatrix
          rightHandSideMatrix:(MPSMatrix *__nonnull)rightHandSideMatrix solutionMatrix:(MPSMatrix *__nonnull)solutionMatrix
    NS_SWIFT_NAME(encode(commandBuffer:sourceMatrix:rightHandSideMatrix:solutionMatrix:));
@end

/* solves op(A) * X = B with A's LU factors and pivots (from MPSMatrixDecompositionLU) */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixSolveLU : MPSMatrixBinaryKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device transpose:(BOOL)transpose order:(NSUInteger)order
                numberOfRightHandSides:(NSUInteger)numberOfRightHandSides NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceMatrix:(MPSMatrix *__nonnull)sourceMatrix
          rightHandSideMatrix:(MPSMatrix *__nonnull)rightHandSideMatrix pivotIndices:(MPSMatrix *__nonnull)pivotIndices
               solutionMatrix:(MPSMatrix *__nonnull)solutionMatrix
    NS_SWIFT_NAME(encode(commandBuffer:sourceMatrix:rightHandSideMatrix:pivotIndices:solutionMatrix:));
@end

/* solves A * X = B with A's Cholesky factor (from MPSMatrixDecompositionCholesky) */
API_AVAILABLE(ios(11.0))
@interface MPSMatrixSolveCholesky : MPSMatrixBinaryKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device upper:(BOOL)upper order:(NSUInteger)order
                numberOfRightHandSides:(NSUInteger)numberOfRightHandSides NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceMatrix:(MPSMatrix *__nonnull)sourceMatrix
          rightHandSideMatrix:(MPSMatrix *__nonnull)rightHandSideMatrix solutionMatrix:(MPSMatrix *__nonnull)solutionMatrix
    NS_SWIFT_NAME(encode(commandBuffer:sourceMatrix:rightHandSideMatrix:solutionMatrix:));
@end

NS_ASSUME_NONNULL_END
