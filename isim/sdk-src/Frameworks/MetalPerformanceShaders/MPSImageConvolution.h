// isim MetalPerformanceShaders: convolutions, blurs, edge filters and the median
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>

NS_ASSUME_NONNULL_BEGIN

/* a general 2-D convolution; weights are row-major, kernelWidth x kernelHeight, both odd */
API_AVAILABLE(ios(9.0))
@interface MPSImageConvolution : MPSUnaryImageKernel
@property (readonly, nonatomic) NSUInteger kernelHeight;
@property (readonly, nonatomic) NSUInteger kernelWidth;
@property (readwrite, nonatomic) float bias API_AVAILABLE(ios(10.0));
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device kernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight
                               weights:(const float *__nonnull)kernelWeights NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(9.0))
@interface MPSImageLaplacian : MPSUnaryImageKernel
@property (readwrite, nonatomic) float bias;
@end

/* the mean of a kernelWidth x kernelHeight window (both odd) */
API_AVAILABLE(ios(9.0))
@interface MPSImageBox : MPSUnaryImageKernel
@property (readonly, nonatomic) NSUInteger kernelHeight;
@property (readonly, nonatomic) NSUInteger kernelWidth;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device kernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight
    NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@end

/* a tent (triangle) weighted window */
API_AVAILABLE(ios(9.0))
@interface MPSImageTent : MPSImageBox
@end

API_AVAILABLE(ios(9.0))
@interface MPSImageGaussianBlur : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device sigma:(float)sigma NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@property (readonly, nonatomic) float sigma;
@end

/* the gradient magnitude of the luminance (colorTransform: the weights of R, G, B; Rec. 601 by default) */
API_AVAILABLE(ios(9.0))
@interface MPSImageSobel : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device linearGrayColorTransform:(const float *__nonnull)transform NS_DESIGNATED_INITIALIZER;
@property (readonly, nonatomic, nonnull) const float *colorTransform;
@end

API_AVAILABLE(ios(9.0))
@interface MPSImageMedian : MPSUnaryImageKernel
@property (readonly, nonatomic) NSUInteger kernelDiameter;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device kernelDiameter:(NSUInteger)kernelDiameter NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
+ (NSUInteger)maxKernelDiameter;
+ (NSUInteger)minKernelDiameter;
@end

NS_ASSUME_NONNULL_END
