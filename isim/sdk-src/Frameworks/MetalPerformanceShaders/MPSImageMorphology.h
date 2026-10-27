// isim MetalPerformanceShaders: morphology (area max / min, dilate / erode)
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>

NS_ASSUME_NONNULL_BEGIN

/* the maximum of a kernelWidth x kernelHeight window (both odd) */
API_AVAILABLE(ios(9.0))
@interface MPSImageAreaMax : MPSUnaryImageKernel
@property (readonly, nonatomic) NSUInteger kernelHeight;
@property (readonly, nonatomic) NSUInteger kernelWidth;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device kernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight
    NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(9.0))
@interface MPSImageAreaMin : MPSImageAreaMax
@end

/* the maximum of the window's pixels minus the probe values (row-major, kernelWidth x kernelHeight) */
API_AVAILABLE(ios(9.0))
@interface MPSImageDilate : MPSUnaryImageKernel
@property (readonly, nonatomic) NSUInteger kernelHeight;
@property (readonly, nonatomic) NSUInteger kernelWidth;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device kernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight
                                values:(const float *__nonnull)values NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@end

/* the minimum of the window's pixels plus the probe values */
API_AVAILABLE(ios(9.0))
@interface MPSImageErode : MPSImageDilate
@end

NS_ASSUME_NONNULL_END
