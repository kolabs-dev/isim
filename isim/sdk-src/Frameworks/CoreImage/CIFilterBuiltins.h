#pragma once
/* isim: typed filter accessors (Swift: import CoreImage.CIFilterBuiltins; CIFilter.gaussianBlur() ...) for the
 * filters isim implements. */
#import <CoreImage/CIFilter.h>
#import <CoreImage/CIColor.h>
#import <CoreImage/CIVector.h>
NS_ASSUME_NONNULL_BEGIN
@protocol CIFilterProtocol
@property (readonly, nonatomic, nullable) CIImage *outputImage;
@end
@protocol CIGaussianBlur <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic) float radius;
@end
@protocol CIColorControls <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic) float saturation, brightness, contrast;
@end
@protocol CISepiaTone <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic) float intensity;
@end
@protocol CIPhotoEffect <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@end
@protocol CIColorInvert <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@end
@protocol CIColorMatrix <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic, retain) CIVector *RVector, *GVector, *BVector, *AVector, *biasVector;
@end
@protocol CIAffineTransform <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic) CGAffineTransform transform;
@end
@protocol CICompositeOperation <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic, retain, nullable) CIImage *backgroundImage;
@end
@protocol CIQRCodeGenerator <CIFilterProtocol>
@property (nonatomic, retain) NSData *message;
@property (nonatomic, copy) NSString *correctionLevel;
@end
@protocol CICheckerboardGenerator <CIFilterProtocol>
@property (nonatomic) CGPoint center;
@property (nonatomic, retain) CIColor *color0, *color1;
@property (nonatomic) float width, sharpness;
@end
@protocol CIConstantColorGenerator <CIFilterProtocol>
@property (nonatomic, retain) CIColor *color;
@end
@protocol CILinearGradient <CIFilterProtocol>
@property (nonatomic) CGPoint point0, point1;
@property (nonatomic, retain) CIColor *color0, *color1;
@end
@protocol CIVignette <CIFilterProtocol>
@property (nonatomic, retain, nullable) CIImage *inputImage;
@property (nonatomic) float radius, intensity;
@end
@interface CIFilter (Builtins)
+ (CIFilter<CIGaussianBlur> *)gaussianBlurFilter NS_SWIFT_NAME(gaussianBlur());
+ (CIFilter<CIColorControls> *)colorControlsFilter NS_SWIFT_NAME(colorControls());
+ (CIFilter<CISepiaTone> *)sepiaToneFilter NS_SWIFT_NAME(sepiaTone());
+ (CIFilter<CIPhotoEffect> *)photoEffectMonoFilter NS_SWIFT_NAME(photoEffectMono());
+ (CIFilter<CIPhotoEffect> *)photoEffectNoirFilter NS_SWIFT_NAME(photoEffectNoir());
+ (CIFilter<CIPhotoEffect> *)photoEffectChromeFilter NS_SWIFT_NAME(photoEffectChrome());
+ (CIFilter<CIPhotoEffect> *)photoEffectFadeFilter NS_SWIFT_NAME(photoEffectFade());
+ (CIFilter<CIPhotoEffect> *)photoEffectInstantFilter NS_SWIFT_NAME(photoEffectInstant());
+ (CIFilter<CIPhotoEffect> *)photoEffectProcessFilter NS_SWIFT_NAME(photoEffectProcess());
+ (CIFilter<CIPhotoEffect> *)photoEffectTonalFilter NS_SWIFT_NAME(photoEffectTonal());
+ (CIFilter<CIPhotoEffect> *)photoEffectTransferFilter NS_SWIFT_NAME(photoEffectTransfer());
+ (CIFilter<CIColorInvert> *)colorInvertFilter NS_SWIFT_NAME(colorInvert());
+ (CIFilter<CIColorMatrix> *)colorMatrixFilter NS_SWIFT_NAME(colorMatrix());
+ (CIFilter<CIAffineTransform> *)affineTransformFilter NS_SWIFT_NAME(affineTransform());
+ (CIFilter<CICompositeOperation> *)sourceOverCompositingFilter NS_SWIFT_NAME(sourceOverCompositing());
+ (CIFilter<CICompositeOperation> *)multiplyCompositingFilter NS_SWIFT_NAME(multiplyCompositing());
+ (CIFilter<CIQRCodeGenerator> *)QRCodeGenerator NS_SWIFT_NAME(qrCodeGenerator());
+ (CIFilter<CICheckerboardGenerator> *)checkerboardGeneratorFilter NS_SWIFT_NAME(checkerboardGenerator());
+ (CIFilter<CIConstantColorGenerator> *)constantColorGeneratorFilter NS_SWIFT_NAME(constantColorGenerator());
+ (CIFilter<CILinearGradient> *)linearGradientFilter NS_SWIFT_NAME(linearGradient());
+ (CIFilter<CIVignette> *)vignetteFilter NS_SWIFT_NAME(vignette());
@end
NS_ASSUME_NONNULL_END
