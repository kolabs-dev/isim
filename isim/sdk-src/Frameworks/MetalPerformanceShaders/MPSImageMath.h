// isim MetalPerformanceShaders: per-pixel arithmetic, statistics, histograms, integral images and reductions
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>

NS_ASSUME_NONNULL_BEGIN

/* clamp(op(primaryScale * a, secondaryScale * b) + bias, minimumValue, maximumValue); a stride of 0 repeats the
   first pixel of that dimension (broadcasting a row, a column or one value) */
API_AVAILABLE(ios(11.0))
@interface MPSImageArithmetic : MPSBinaryImageKernel
@property (readwrite, nonatomic) float primaryScale;
@property (readwrite, nonatomic) float secondaryScale;
@property (readwrite, nonatomic) float bias;
@property (readwrite, nonatomic) MTLSize primaryStrideInPixels;
@property (readwrite, nonatomic) MTLSize secondaryStrideInPixels;
@property (readwrite, nonatomic) float minimumValue API_AVAILABLE(ios(12.0));
@property (readwrite, nonatomic) float maximumValue API_AVAILABLE(ios(12.0));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end

API_AVAILABLE(ios(11.0))
@interface MPSImageAdd : MPSImageArithmetic
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0))
@interface MPSImageSubtract : MPSImageArithmetic
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0))
@interface MPSImageMultiply : MPSImageArithmetic
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0))
@interface MPSImageDivide : MPSImageArithmetic
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end

/* statistics of the source's clipRectSource, per channel, written to the destination: the minimum at (0, 0) and the
   maximum at (1, 0); the mean at (0, 0); the mean at (0, 0) and the variance at (1, 0) */
API_AVAILABLE(ios(11.0))
@interface MPSImageStatisticsMinAndMax : MPSUnaryImageKernel
@property (readwrite, nonatomic) MTLRegion clipRectSource;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0))
@interface MPSImageStatisticsMeanAndVariance : MPSUnaryImageKernel
@property (readwrite, nonatomic) MTLRegion clipRectSource;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0))
@interface MPSImageStatisticsMean : MPSUnaryImageKernel
@property (readwrite, nonatomic) MTLRegion clipRectSource;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end

/* summed-area tables: each pixel is the sum of (the squares of) the pixels above and left of it, itself included */
API_AVAILABLE(ios(9.0))
@interface MPSImageIntegral : MPSUnaryImageKernel
@end
API_AVAILABLE(ios(9.0))
@interface MPSImageIntegralOfSquares : MPSUnaryImageKernel
@end

typedef struct {
    NSUInteger numberOfHistogramEntries;
    BOOL histogramForAlpha;
    vector_float4 minPixelValue;
    vector_float4 maxPixelValue;
} MPSImageHistogramInfo;

/* counts per channel into a buffer of uint32: numberOfHistogramEntries for R, then G, then B (then A) */
API_AVAILABLE(ios(9.0))
@interface MPSImageHistogram : MPSKernel
@property (readwrite, nonatomic) MTLRegion clipRectSource;
@property (readwrite, nonatomic) BOOL zeroHistogram;
@property (readwrite, nonatomic) vector_float4 minPixelThresholdValue API_AVAILABLE(ios(11.3));
@property (readonly, nonatomic) MPSImageHistogramInfo histogramInfo;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *__nonnull)histogramInfo
    NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceTexture:(nonnull id<MTLTexture>)source
                    histogram:(nonnull id<MTLBuffer>)histogram histogramOffset:(NSUInteger)histogramOffset
    NS_SWIFT_NAME(encode(to:sourceTexture:histogram:histogramOffset:));
- (size_t)histogramSizeForSourceFormat:(MTLPixelFormat)sourceFormat;
@end

/* equalizes with a histogram: encodeTransform builds the mapping, then encode applies it */
API_AVAILABLE(ios(9.0))
@interface MPSImageHistogramEqualization : MPSUnaryImageKernel
@property (readonly, nonatomic) MPSImageHistogramInfo histogramInfo;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *__nonnull)histogramInfo
    NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
- (void)encodeTransformToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer sourceTexture:(nonnull id<MTLTexture>)source
                             histogram:(nonnull id<MTLBuffer>)histogram histogramOffset:(NSUInteger)histogramOffset
    NS_SWIFT_NAME(encodeTransform(to:sourceTexture:histogram:histogramOffset:));
@end

/* reductions of each row to one pixel (written in column 0) or of each column (written in row 0) */
API_AVAILABLE(ios(11.0))
@interface MPSImageReduceUnary : MPSUnaryImageKernel
@property (readwrite, nonatomic) MTLRegion clipRectSource;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceRowMin : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceColumnMin : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceRowMax : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceColumnMax : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceRowMean : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceColumnMean : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceRowSum : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end
API_AVAILABLE(ios(11.0)) @interface MPSImageReduceColumnSum : MPSImageReduceUnary
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
