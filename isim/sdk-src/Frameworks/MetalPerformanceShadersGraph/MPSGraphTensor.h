// isim MetalPerformanceShadersGraph: tensors (symbolic values of a graph), the operations that make them, and tensor
// data (the values fed in and read out; isim keeps them in memory, row-major, the last dimension fastest)
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraphCore.h>

NS_ASSUME_NONNULL_BEGIN

@class MPSGraph, MPSGraphOperation;

API_AVAILABLE(ios(14.0))
@interface MPSGraphTensor : MPSGraphObject <NSCopying>
@property (readonly, nullable, copy, atomic) MPSShape *shape;
@property (readonly, atomic) MPSDataType dataType;
@property (readonly, nonnull, atomic) MPSGraphOperation *operation;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(14.0))
@interface MPSGraphOperation : MPSGraphObject <NSCopying>
@property (readonly, nonnull, atomic) NSArray<MPSGraphTensor *> *inputTensors;
@property (readonly, nonnull, atomic) NSArray<MPSGraphTensor *> *outputTensors;
@property (readonly, nonnull, atomic) NSArray<MPSGraphOperation *> *controlDependencies;
@property (readonly, nonnull, atomic) MPSGraph *graph;
@property (readonly, nonnull, atomic) NSString *name;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(14.0))
@interface MPSGraphTensorData : MPSGraphObject
@property (readonly, copy, nonatomic) MPSShape *shape;
@property (readonly, nonatomic) MPSDataType dataType;
@property (readonly, nonatomic) MPSGraphDevice *device;
- (instancetype)initWithDevice:(MPSGraphDevice *)device data:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)dataType;
- (instancetype)initWithMTLBuffer:(id<MTLBuffer>)buffer shape:(MPSShape *)shape dataType:(MPSDataType)dataType;
- (instancetype)initWithMTLBuffer:(id<MTLBuffer>)buffer shape:(MPSShape *)shape dataType:(MPSDataType)dataType rowBytes:(NSUInteger)rowBytes
    API_AVAILABLE(ios(15.0));
- (instancetype)initWithMPSMatrix:(MPSMatrix *)matrix;
- (instancetype)initWithMPSMatrix:(MPSMatrix *)matrix rank:(NSUInteger)matrixRank;
- (instancetype)initWithMPSVector:(MPSVector *)vector;
- (instancetype)initWithMPSVector:(MPSVector *)vector rank:(NSUInteger)rank;
- (instancetype)initWithMPSNDArray:(MPSNDArray *)ndarray;
- (instancetype)initWithMPSImageBatch:(NSArray<MPSImage *> *)imageBatch;
/* the values as an MPSNDArray (a copy) */
- (MPSNDArray *)mpsndarray;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
