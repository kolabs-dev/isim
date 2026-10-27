// isim MetalPerformanceShaders: N-dimensional arrays. Dimension 0 is the fastest-moving (innermost); an MPSShape lists
// the dimensions outermost first.
#pragma once
#import <MetalPerformanceShaders/MPSCoreTypes.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface MPSNDArrayDescriptor : NSObject
@property (readwrite, nonatomic) MPSDataType dataType;
@property (readwrite, nonatomic) NSUInteger numberOfDimensions;
@property (readwrite, nonatomic) BOOL preferPackedRows API_AVAILABLE(ios(15.0));
- (NSUInteger)lengthOfDimension:(NSUInteger)dimensionIndex;
- (MPSDimensionSlice)sliceRangeForDimension:(NSUInteger)dimensionIndex;
- (void)sliceDimension:(NSUInteger)dimensionIndex withSubrange:(MPSDimensionSlice)subRange;
- (void)transposeDimension:(NSUInteger)dimensionIndex withDimension:(NSUInteger)dimensionIndex2;
- (vector_uchar16)dimensionOrder;
- (void)reshapeWithDimensionCount:(NSUInteger)numberOfDimensions dimensionSizes:(NSUInteger *__nonnull)dimensionSizes API_AVAILABLE(ios(15.0));
- (void)reshapeWithShape:(MPSShape *__nonnull)shape API_AVAILABLE(ios(15.0));
- (MPSShape *__nonnull)getShape API_AVAILABLE(ios(16.0));
+ (__nonnull instancetype)descriptorWithDataType:(MPSDataType)dataType dimensionCount:(NSUInteger)numberOfDimensions
                                  dimensionSizes:(NSUInteger *__nonnull)dimensionSizes;
+ (__nonnull instancetype)descriptorWithDataType:(MPSDataType)dataType shape:(MPSShape *__nonnull)shape;
- (nonnull instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(13.0))
@interface MPSNDArray : NSObject
@property (copy, atomic, nullable) NSString *label;
@property (readonly, nonatomic) MPSDataType dataType;
@property (readonly, nonatomic) size_t dataTypeSize;
@property (readonly, nonatomic) NSUInteger numberOfDimensions;
@property (readonly, retain, nonatomic, nonnull) id<MTLDevice> device;
@property (readonly, retain, nonatomic, nullable) MPSNDArray *parent;
- (NSUInteger)lengthOfDimension:(NSUInteger)dimensionIndex;
- (MPSNDArrayDescriptor *__nonnull)descriptor;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device descriptor:(MPSNDArrayDescriptor *__nonnull)descriptor NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device scalar:(double)value;
- (nonnull instancetype)initWithBuffer:(nonnull id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(MPSNDArrayDescriptor *__nonnull)descriptor
    API_AVAILABLE(ios(16.0));
- (nonnull instancetype)init NS_UNAVAILABLE;
- (NSUInteger)resourceSize;
/* copies the elements out / in; strideBytes per dimension (dimension 0 first) or NULL for packed */
- (void)readBytes:(void *__nonnull)buffer strideBytes:(NSInteger *__nullable)strideBytesPerDimension;
- (void)writeBytes:(void *__nonnull)buffer strideBytes:(NSInteger *__nullable)strideBytesPerDimension;
- (void)exportDataWithCommandBuffer:(nonnull id<MTLCommandBuffer>)cmdBuf toBuffer:(nonnull id<MTLBuffer>)buffer
                destinationDataType:(MPSDataType)destinationDataType offset:(NSUInteger)offset
                         rowStrides:(NSInteger *__nullable)rowStrides API_AVAILABLE(ios(15.0));
- (void)importDataWithCommandBuffer:(nonnull id<MTLCommandBuffer>)cmdBuf fromBuffer:(nonnull id<MTLBuffer>)buffer
                     sourceDataType:(MPSDataType)sourceDataType offset:(NSUInteger)offset
                         rowStrides:(NSInteger *__nullable)rowStrides API_AVAILABLE(ios(15.0));
- (void)synchronizeOnCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer;
- (nullable id<MTLBuffer>)userBuffer API_AVAILABLE(ios(17.0));
@end

API_AVAILABLE(ios(13.0))
@interface MPSTemporaryNDArray : MPSNDArray
+ (nonnull instancetype)temporaryNDArrayWithCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                                               descriptor:(MPSNDArrayDescriptor *__nonnull)descriptor;
@property (readwrite, nonatomic) NSUInteger readCount;
@end

NS_ASSUME_NONNULL_END
