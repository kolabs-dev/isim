// isim MetalPerformanceShaders: thresholds of the luminance (the linear gray transform weights R, G, B; Rec. 601 by
// default). The destination has the luminance's one channel.
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>

NS_ASSUME_NONNULL_BEGIN

/* maximumValue where the luminance is above thresholdValue, else 0 */
API_AVAILABLE(ios(9.0))
@interface MPSImageThresholdBinary : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device thresholdValue:(float)thresholdValue maximumValue:(float)maximumValue
              linearGrayColorTransform:(nullable const float *)transform NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@property (readonly, nonatomic) float thresholdValue;
@property (readonly, nonatomic) float maximumValue;
@property (readonly, nonatomic, nonnull) const float *transform;
@end

/* 0 where the luminance is above thresholdValue, else maximumValue */
API_AVAILABLE(ios(9.0))
@interface MPSImageThresholdBinaryInverse : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device thresholdValue:(float)thresholdValue maximumValue:(float)maximumValue
              linearGrayColorTransform:(nullable const float *)transform NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@property (readonly, nonatomic) float thresholdValue;
@property (readonly, nonatomic) float maximumValue;
@property (readonly, nonatomic, nonnull) const float *transform;
@end

/* thresholdValue where the luminance is above it, else the luminance */
API_AVAILABLE(ios(9.0))
@interface MPSImageThresholdTruncate : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device thresholdValue:(float)thresholdValue
              linearGrayColorTransform:(nullable const float *)transform NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@property (readonly, nonatomic) float thresholdValue;
@property (readonly, nonatomic, nonnull) const float *transform;
@end

/* the luminance where it is above thresholdValue, else 0 */
API_AVAILABLE(ios(9.0))
@interface MPSImageThresholdToZero : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device thresholdValue:(float)thresholdValue
              linearGrayColorTransform:(nullable const float *)transform NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@property (readonly, nonatomic) float thresholdValue;
@property (readonly, nonatomic, nonnull) const float *transform;
@end

/* 0 where the luminance is above thresholdValue, else the luminance */
API_AVAILABLE(ios(9.0))
@interface MPSImageThresholdToZeroInverse : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device thresholdValue:(float)thresholdValue
              linearGrayColorTransform:(nullable const float *)transform NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_UNAVAILABLE;
@property (readonly, nonatomic) float thresholdValue;
@property (readonly, nonatomic, nonnull) const float *transform;
@end

NS_ASSUME_NONNULL_END
