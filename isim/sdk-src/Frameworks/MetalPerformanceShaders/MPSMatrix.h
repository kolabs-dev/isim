// isim MetalPerformanceShaders: matrices and vectors in Metal buffers (row-major; batches of matrices matrixBytes apart)
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(10.0))
@interface MPSMatrixDescriptor : NSObject
@property (readwrite, nonatomic) NSUInteger rows;
@property (readwrite, nonatomic) NSUInteger columns;
@property (readonly, nonatomic) NSUInteger matrices API_AVAILABLE(ios(11.0));
@property (readwrite, nonatomic) MPSDataType dataType;
@property (readwrite, nonatomic) NSUInteger rowBytes;
@property (readonly, nonatomic) NSUInteger matrixBytes API_AVAILABLE(ios(11.0));
+ (__nonnull instancetype)matrixDescriptorWithDimensions:(NSUInteger)rows columns:(NSUInteger)columns rowBytes:(NSUInteger)rowBytes
                                                dataType:(MPSDataType)dataType API_DEPRECATED_WITH_REPLACEMENT("matrixDescriptorWithRows:columns:rowBytes:dataType:", ios(10.0, 11.0));
+ (__nonnull instancetype)matrixDescriptorWithRows:(NSUInteger)rows columns:(NSUInteger)columns rowBytes:(NSUInteger)rowBytes
                                          dataType:(MPSDataType)dataType API_AVAILABLE(ios(11.0));
+ (__nonnull instancetype)matrixDescriptorWithRows:(NSUInteger)rows columns:(NSUInteger)columns matrices:(NSUInteger)matrices
                                          rowBytes:(NSUInteger)rowBytes matrixBytes:(NSUInteger)matrixBytes
                                          dataType:(MPSDataType)dataType API_AVAILABLE(ios(11.0));
+ (size_t)rowBytesFromColumns:(NSUInteger)columns dataType:(MPSDataType)dataType
    API_DEPRECATED_WITH_REPLACEMENT("rowBytesForColumns:dataType:", ios(10.0, 11.0));
+ (size_t)rowBytesForColumns:(NSUInteger)columns dataType:(MPSDataType)dataType API_AVAILABLE(ios(11.0));
@end

API_AVAILABLE(ios(11.0))
@interface MPSVectorDescriptor : NSObject
@property (readwrite, nonatomic) NSUInteger length;
@property (readonly, nonatomic) NSUInteger vectors;
@property (readwrite, nonatomic) MPSDataType dataType;
@property (readonly, nonatomic) NSUInteger vectorBytes;
+ (__nonnull instancetype)vectorDescriptorWithLength:(NSUInteger)length dataType:(MPSDataType)dataType;
+ (__nonnull instancetype)vectorDescriptorWithLength:(NSUInteger)length vectors:(NSUInteger)vectors vectorBytes:(NSUInteger)vectorBytes
                                            dataType:(MPSDataType)dataType;
+ (size_t)vectorBytesForLength:(NSUInteger)length dataType:(MPSDataType)dataType;
@end

API_AVAILABLE(ios(10.0))
@interface MPSMatrix : NSObject
@property (readonly, retain, nonatomic, nonnull) id<MTLDevice> device;
@property (readonly, nonatomic) NSUInteger rows;
@property (readonly, nonatomic) NSUInteger columns;
@property (readonly, nonatomic) NSUInteger matrices API_AVAILABLE(ios(11.0));
@property (readonly, nonatomic) MPSDataType dataType;
@property (readonly, nonatomic) NSUInteger rowBytes;
@property (readonly, nonatomic) NSUInteger matrixBytes API_AVAILABLE(ios(11.0));
@property (readonly, nonatomic) NSUInteger offset API_AVAILABLE(ios(13.0));
@property (readonly, nonnull, nonatomic) id<MTLBuffer> data;
- (nonnull instancetype)initWithBuffer:(nonnull id<MTLBuffer>)buffer descriptor:(nonnull MPSMatrixDescriptor *)descriptor;
- (nonnull instancetype)initWithBuffer:(nonnull id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(nonnull MPSMatrixDescriptor *)descriptor
    API_AVAILABLE(ios(13.0));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device descriptor:(nonnull MPSMatrixDescriptor *)descriptor API_AVAILABLE(ios(11.0));
- (nonnull instancetype)init NS_UNAVAILABLE;
- (void)synchronizeOnCommandBuffer:(__nonnull id<MTLCommandBuffer>)commandBuffer API_AVAILABLE(ios(11.0));
- (NSUInteger)resourceSize API_AVAILABLE(ios(11.3));
@end

API_AVAILABLE(ios(11.0))
@interface MPSVector : NSObject
@property (readonly, retain, nonatomic, nonnull) id<MTLDevice> device;
@property (readonly, nonatomic) NSUInteger length;
@property (readonly, nonatomic) NSUInteger vectors;
@property (readonly, nonatomic) MPSDataType dataType;
@property (readonly, nonatomic) NSUInteger vectorBytes;
@property (readonly, nonatomic) NSUInteger offset API_AVAILABLE(ios(13.0));
@property (readonly, nonnull, nonatomic) id<MTLBuffer> data;
- (nonnull instancetype)initWithBuffer:(nonnull id<MTLBuffer>)buffer descriptor:(nonnull MPSVectorDescriptor *)descriptor;
- (nonnull instancetype)initWithBuffer:(nonnull id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(nonnull MPSVectorDescriptor *)descriptor
    API_AVAILABLE(ios(13.0));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device descriptor:(nonnull MPSVectorDescriptor *)descriptor;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (void)synchronizeOnCommandBuffer:(__nonnull id<MTLCommandBuffer>)commandBuffer;
- (NSUInteger)resourceSize API_AVAILABLE(ios(11.3));
@end

/* isim: temporary matrices and vectors are ordinary ones */
API_AVAILABLE(ios(11.0))
@interface MPSTemporaryMatrix : MPSMatrix
+ (nonnull instancetype)temporaryMatrixWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                                        matrixDescriptor:(nonnull MPSMatrixDescriptor *)matrixDescriptor;
+ (void)prefetchStorageWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                    matrixDescriptorList:(NSArray<MPSMatrixDescriptor *> *__nonnull)descriptorList;
@property (readwrite, nonatomic) NSUInteger readCount;
@end
API_AVAILABLE(ios(11.0))
@interface MPSTemporaryVector : MPSVector
+ (nonnull instancetype)temporaryVectorWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                                              descriptor:(nonnull MPSVectorDescriptor *)descriptor;
+ (void)prefetchStorageWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                          descriptorList:(NSArray<MPSVectorDescriptor *> *__nonnull)descriptorList;
@property (readwrite, nonatomic) NSUInteger readCount;
@end

NS_ASSUME_NONNULL_END
