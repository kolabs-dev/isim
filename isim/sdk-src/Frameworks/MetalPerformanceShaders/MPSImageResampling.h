// isim MetalPerformanceShaders: scaling, conversion and transposition
#pragma once
#import <MetalPerformanceShaders/MPSKernel.h>
#import <CoreGraphics/CoreGraphics.h>

/* CoreGraphics' color conversion (isim's CoreGraphics does not create them yet; the same declaration as Apple's) */
typedef const struct CGColorConversionInfo *CGColorConversionInfoRef;

NS_ASSUME_NONNULL_BEGIN

/* resizes the source to the destination (or by scaleTransform: dest = source * scale + translate) */
API_AVAILABLE(ios(11.0))
@interface MPSImageScale : MPSUnaryImageKernel
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@property (readwrite, nonatomic, nullable) const MPSScaleTransform *scaleTransform;
@end

/* Lanczos (a = 3) resampling */
API_AVAILABLE(ios(9.0))
@interface MPSImageLanczosScale : MPSImageScale
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end

API_AVAILABLE(ios(11.0))
@interface MPSImageBilinearScale : MPSImageScale
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
@end

/* converts between pixel formats and alpha types (isim: the color spaces of the conversion info are not applied) */
API_AVAILABLE(ios(10.0))
@interface MPSImageConversion : MPSUnaryImageKernel
@property (readonly, nonatomic) MPSAlphaType sourceAlpha;
@property (readonly, nonatomic) MPSAlphaType destinationAlpha;
- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device srcAlpha:(MPSAlphaType)srcAlpha destAlpha:(MPSAlphaType)destAlpha
                       backgroundColor:(nullable CGFloat *)backgroundColor conversionInfo:(nullable CGColorConversionInfoRef)conversionInfo
    NS_DESIGNATED_INITIALIZER;
@end

/* rows become columns */
API_AVAILABLE(ios(9.0))
@interface MPSImageTranspose : MPSUnaryImageKernel
@end

NS_ASSUME_NONNULL_END
