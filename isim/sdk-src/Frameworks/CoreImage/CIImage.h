#pragma once
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
NS_ASSUME_NONNULL_BEGIN
@class CIColor, CIFilter, CIFilterShape, UIImage;

/* isim: an image recipe in Core Image's space (y up, origin at the lower left of a CGImage's extent). Nothing is
 * computed until a CIContext renders it; isim renders on the CPU in the context's working space (extended linear
 * sRGB by default, as on iOS). */
typedef int CIFormat NS_TYPED_ENUM;
/* Swift names as on iOS (CIFormat.RGBAh, .Lf, ...) */
extern CIFormat kCIFormatARGB8 NS_SWIFT_NAME(CIFormat.ARGB8);
extern CIFormat kCIFormatBGRA8 NS_SWIFT_NAME(CIFormat.BGRA8);
extern CIFormat kCIFormatRGBA8 NS_SWIFT_NAME(CIFormat.RGBA8);
extern CIFormat kCIFormatABGR8 NS_SWIFT_NAME(CIFormat.ABGR8);
extern CIFormat kCIFormatRGBAh NS_SWIFT_NAME(CIFormat.RGBAh);
extern CIFormat kCIFormatRGBA16 NS_SWIFT_NAME(CIFormat.RGBA16);
extern CIFormat kCIFormatRGBAf NS_SWIFT_NAME(CIFormat.RGBAf);
extern CIFormat kCIFormatRGBX16 NS_SWIFT_NAME(CIFormat.RGBX16);
extern CIFormat kCIFormatRGBX8 NS_SWIFT_NAME(CIFormat.RGBX8);
extern CIFormat kCIFormatRGBXh NS_SWIFT_NAME(CIFormat.RGBXh);
extern CIFormat kCIFormatRGBXf NS_SWIFT_NAME(CIFormat.RGBXf);
extern CIFormat kCIFormatA8 NS_SWIFT_NAME(CIFormat.A8);
extern CIFormat kCIFormatA16 NS_SWIFT_NAME(CIFormat.A16);
extern CIFormat kCIFormatAh NS_SWIFT_NAME(CIFormat.Ah);
extern CIFormat kCIFormatAf NS_SWIFT_NAME(CIFormat.Af);
extern CIFormat kCIFormatR8 NS_SWIFT_NAME(CIFormat.R8);
extern CIFormat kCIFormatR16 NS_SWIFT_NAME(CIFormat.R16);
extern CIFormat kCIFormatRh NS_SWIFT_NAME(CIFormat.Rh);
extern CIFormat kCIFormatRf NS_SWIFT_NAME(CIFormat.Rf);
extern CIFormat kCIFormatRG8 NS_SWIFT_NAME(CIFormat.RG8);
extern CIFormat kCIFormatRG16 NS_SWIFT_NAME(CIFormat.RG16);
extern CIFormat kCIFormatRGh NS_SWIFT_NAME(CIFormat.RGh);
extern CIFormat kCIFormatRGf NS_SWIFT_NAME(CIFormat.RGf);
extern CIFormat kCIFormatL8 NS_SWIFT_NAME(CIFormat.L8);
extern CIFormat kCIFormatL16 NS_SWIFT_NAME(CIFormat.L16);
extern CIFormat kCIFormatLh NS_SWIFT_NAME(CIFormat.Lh);
extern CIFormat kCIFormatLf NS_SWIFT_NAME(CIFormat.Lf);
extern CIFormat kCIFormatLA8 NS_SWIFT_NAME(CIFormat.LA8);
extern CIFormat kCIFormatLA16 NS_SWIFT_NAME(CIFormat.LA16);
extern CIFormat kCIFormatLAh NS_SWIFT_NAME(CIFormat.LAh);
extern CIFormat kCIFormatLAf NS_SWIFT_NAME(CIFormat.LAf);

typedef NSString *CIImageOption NS_TYPED_ENUM;
extern CIImageOption const kCIImageColorSpace;
extern CIImageOption const kCIImageToneMapHDRtoSDR;
extern CIImageOption const kCIImageExpandToHDR;
extern CIImageOption const kCIImageNearestSampling;
extern CIImageOption const kCIImageCacheImmediately;
extern CIImageOption const kCIImageProperties;
extern CIImageOption const kCIImageApplyOrientationProperty;
extern CIImageOption const kCIImageAuxiliaryDepth;
extern CIImageOption const kCIImageAuxiliaryDisparity;
extern CIImageOption const kCIImageAuxiliaryPortraitEffectsMatte;
extern CIImageOption const kCIImageAuxiliarySemanticSegmentationSkinMatte;
extern CIImageOption const kCIImageAuxiliarySemanticSegmentationHairMatte;
extern CIImageOption const kCIImageAuxiliarySemanticSegmentationTeethMatte;
extern CIImageOption const kCIImageAuxiliarySemanticSegmentationGlassesMatte;
extern CIImageOption const kCIImageAuxiliarySemanticSegmentationSkyMatte;
extern CIImageOption const kCIImageAuxiliaryHDRGainMap;
extern CIImageOption const kCIImageContentHeadroom API_AVAILABLE(ios(18.0));
extern CIImageOption const kCIImageContentAverageLightLevel API_AVAILABLE(ios(26.0));
extern CIImageOption const kCIImageApplyCleanAperture API_AVAILABLE(ios(26.0));
extern CIImageOption const kCIImageProviderTileSize;
extern CIImageOption const kCIImageProviderUserInfo;
/* iOS 26 HDR: the dynamic range an image is shown in (CISystemToneMap's preferredDynamicRange) */
typedef NSString *CIDynamicRangeOption NS_TYPED_ENUM API_AVAILABLE(ios(26.0));
extern CIDynamicRangeOption const kCIDynamicRangeStandard NS_SWIFT_NAME(CIDynamicRangeOption.standard) API_AVAILABLE(ios(26.0));
extern CIDynamicRangeOption const kCIDynamicRangeConstrainedHigh NS_SWIFT_NAME(CIDynamicRangeOption.constrainedHigh) API_AVAILABLE(ios(26.0));
extern CIDynamicRangeOption const kCIDynamicRangeHigh NS_SWIFT_NAME(CIDynamicRangeOption.high) API_AVAILABLE(ios(26.0));

@interface CIImage : NSObject <NSSecureCoding, NSCopying>
+ (CIImage *)imageWithCGImage:(CGImageRef)image;
+ (CIImage *)imageWithCGImage:(CGImageRef)image options:(nullable NSDictionary<CIImageOption, id> *)options;
+ (CIImage *)imageWithCGImageSource:(CGImageSourceRef)source index:(size_t)index options:(nullable NSDictionary<CIImageOption, id> *)dict;
+ (CIImage *)imageWithBitmapData:(NSData *)data bytesPerRow:(size_t)bytesPerRow size:(CGSize)size format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace;
+ (nullable CIImage *)imageWithContentsOfURL:(NSURL *)url;
+ (nullable CIImage *)imageWithContentsOfURL:(NSURL *)url options:(nullable NSDictionary<CIImageOption, id> *)options;
+ (nullable CIImage *)imageWithData:(NSData *)data;
+ (nullable CIImage *)imageWithData:(NSData *)data options:(nullable NSDictionary<CIImageOption, id> *)options;
+ (CIImage *)imageWithImageProvider:(id)p size:(size_t)width :(size_t)height format:(CIFormat)f colorSpace:(nullable CGColorSpaceRef)cs
    options:(nullable NSDictionary<CIImageOption, id> *)options;
+ (CIImage *)imageWithColor:(CIColor *)color;
+ (CIImage *)emptyImage NS_SWIFT_NAME(empty());
@property (class, strong, readonly) CIImage *blackImage NS_SWIFT_NAME(black);
@property (class, strong, readonly) CIImage *whiteImage NS_SWIFT_NAME(white);
@property (class, strong, readonly) CIImage *grayImage NS_SWIFT_NAME(gray);
@property (class, strong, readonly) CIImage *redImage NS_SWIFT_NAME(red);
@property (class, strong, readonly) CIImage *greenImage NS_SWIFT_NAME(green);
@property (class, strong, readonly) CIImage *blueImage NS_SWIFT_NAME(blue);
@property (class, strong, readonly) CIImage *cyanImage NS_SWIFT_NAME(cyan);
@property (class, strong, readonly) CIImage *magentaImage NS_SWIFT_NAME(magenta);
@property (class, strong, readonly) CIImage *yellowImage NS_SWIFT_NAME(yellow);
@property (class, strong, readonly) CIImage *clearImage NS_SWIFT_NAME(clear);

- (instancetype)initWithCGImage:(CGImageRef)image;
- (instancetype)initWithCGImage:(CGImageRef)image options:(nullable NSDictionary<CIImageOption, id> *)options;
- (instancetype)initWithCGImageSource:(CGImageSourceRef)source index:(size_t)index options:(nullable NSDictionary<CIImageOption, id> *)dict;
- (nullable instancetype)initWithData:(NSData *)data;
- (nullable instancetype)initWithData:(NSData *)data options:(nullable NSDictionary<CIImageOption, id> *)options;
- (instancetype)initWithBitmapData:(NSData *)data bytesPerRow:(size_t)bytesPerRow size:(CGSize)size format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url options:(nullable NSDictionary<CIImageOption, id> *)options;
- (instancetype)initWithImageProvider:(id)p size:(size_t)width :(size_t)height format:(CIFormat)f colorSpace:(nullable CGColorSpaceRef)cs
    options:(nullable NSDictionary<CIImageOption, id> *)options;
- (instancetype)initWithColor:(CIColor *)color;
/* UIKit additions */
- (nullable instancetype)initWithImage:(UIImage *)image;
- (nullable instancetype)initWithImage:(UIImage *)image options:(nullable NSDictionary<CIImageOption, id> *)options;

- (CIImage *)imageByApplyingTransform:(CGAffineTransform)matrix NS_SWIFT_NAME(transformed(by:));
- (CIImage *)imageByApplyingTransform:(CGAffineTransform)matrix highQualityDownsample:(BOOL)highQualityDownsample NS_SWIFT_NAME(transformed(by:highQualityDownsample:));
- (CIImage *)imageByApplyingOrientation:(int)orientation NS_SWIFT_NAME(oriented(forExifOrientation:));
- (CIImage *)imageByApplyingCGOrientation:(CGImagePropertyOrientation)orientation NS_SWIFT_NAME(oriented(_:));
- (CGAffineTransform)imageTransformForOrientation:(int)orientation NS_SWIFT_NAME(orientationTransform(forExifOrientation:));
- (CGAffineTransform)imageTransformForCGOrientation:(CGImagePropertyOrientation)orientation NS_SWIFT_NAME(orientationTransform(for:));
- (CIImage *)imageByCompositingOverImage:(CIImage *)dest NS_SWIFT_NAME(composited(over:));
- (CIImage *)imageByCroppingToRect:(CGRect)rect NS_SWIFT_NAME(cropped(to:));
- (CIImage *)imageByClampingToExtent NS_SWIFT_NAME(clampedToExtent());
- (CIImage *)imageByClampingToRect:(CGRect)rect NS_SWIFT_NAME(clamped(to:));
- (CIImage *)imageByApplyingFilter:(NSString *)filterName withInputParameters:(nullable NSDictionary<NSString *, id> *)params NS_SWIFT_NAME(applyingFilter(_:parameters:));
- (CIImage *)imageByApplyingFilter:(NSString *)filterName NS_SWIFT_NAME(applyingFilter(_:));
- (nullable CIImage *)imageByColorMatchingColorSpaceToWorkingSpace:(CGColorSpaceRef)colorSpace NS_SWIFT_NAME(matchedToWorkingSpace(from:));
- (nullable CIImage *)imageByColorMatchingWorkingSpaceToColorSpace:(CGColorSpaceRef)colorSpace NS_SWIFT_NAME(matchedFromWorkingSpace(to:));
- (CIImage *)imageByPremultiplyingAlpha NS_SWIFT_NAME(premultiplyingAlpha());
- (CIImage *)imageByUnpremultiplyingAlpha NS_SWIFT_NAME(unpremultiplyingAlpha());
- (CIImage *)imageBySettingAlphaOneInExtent:(CGRect)extent NS_SWIFT_NAME(settingAlphaOne(in:));
- (CIImage *)imageByApplyingGaussianBlurWithSigma:(double)sigma NS_SWIFT_NAME(applyingGaussianBlur(sigma:));
- (CIImage *)imageBySettingProperties:(NSDictionary *)properties NS_SWIFT_NAME(settingProperties(_:));
- (CIImage *)imageBySamplingLinear NS_SWIFT_NAME(samplingLinear());
- (CIImage *)imageBySamplingNearest NS_SWIFT_NAME(samplingNearest());
- (CIImage *)imageByInsertingIntermediate NS_SWIFT_NAME(insertingIntermediate());
- (CIImage *)imageByInsertingIntermediate:(BOOL)cache NS_SWIFT_NAME(insertingIntermediate(cache:));
- (CIImage *)imageByInsertingTiledIntermediate NS_SWIFT_NAME(insertingTiledIntermediate()) API_AVAILABLE(ios(26.0));
/* Lab (L 0...100, a and b about -128...127) and back: CIConvertRGBtoLab / CIConvertLabToRGB */
- (CIImage *)imageByConvertingWorkingSpaceToLab NS_SWIFT_NAME(convertingWorkingSpaceToLab()) API_AVAILABLE(ios(16.0));
- (CIImage *)imageByConvertingLabToWorkingSpace NS_SWIFT_NAME(convertingLabToWorkingSpace()) API_AVAILABLE(ios(16.0));
/* iOS 26 HDR metadata: the headroom (peak / SDR white) and the average light level the image is tagged with */
- (CIImage *)imageBySettingContentHeadroom:(float)headroom NS_SWIFT_NAME(settingContentHeadroom(_:)) API_AVAILABLE(ios(26.0));
- (CIImage *)imageBySettingContentAverageLightLevel:(float)average NS_SWIFT_NAME(settingContentAverageLightLevel(_:)) API_AVAILABLE(ios(26.0));
- (CIImage *)imageByApplyingGainMap:(CIImage *)gainmap NS_SWIFT_NAME(applyingGainMap(_:)) API_AVAILABLE(ios(18.0));
- (CIImage *)imageByApplyingGainMap:(CIImage *)gainmap headroom:(float)headroom NS_SWIFT_NAME(applyingGainMap(_:headroom:)) API_AVAILABLE(ios(18.0));
- (CGRect)regionOfInterestForImage:(CIImage *)image inRect:(CGRect)rect;

@property (readonly) CGRect extent;
@property (readonly) NSDictionary<NSString *, id> *properties;
@property (readonly) CIFilterShape *definition;
@property (nullable, readonly) NSURL *url;
@property (nullable, readonly) CGColorSpaceRef colorSpace;
@property (nullable, readonly) CGImageRef CGImage;
@property (readonly, getter=isOpaque) BOOL opaque API_AVAILABLE(ios(17.0));
@property (readonly) CGFloat contentHeadroom API_AVAILABLE(ios(18.0));
@property (readonly) float contentAverageLightLevel API_AVAILABLE(ios(26.0));
@end

/* auto adjustment (CIImage+AutoAdjustment). isim (adapted): enhance (CIVibrance, CIToneCurve, CIHighlightShadowAdjust)
 * from image statistics, crop and level (CIStraightenFilter) from the image's dominant lines; red-eye correction
 * filters are not returned (isim's face detector finds no eye landmarks precise enough) */
typedef NSString *CIImageAutoAdjustmentOption NS_TYPED_ENUM;
extern CIImageAutoAdjustmentOption const kCIImageAutoAdjustEnhance NS_SWIFT_NAME(CIImageAutoAdjustmentOption.enhance);
extern CIImageAutoAdjustmentOption const kCIImageAutoAdjustRedEye NS_SWIFT_NAME(CIImageAutoAdjustmentOption.redEye);
extern CIImageAutoAdjustmentOption const kCIImageAutoAdjustFeatures NS_SWIFT_NAME(CIImageAutoAdjustmentOption.features);
extern CIImageAutoAdjustmentOption const kCIImageAutoAdjustCrop NS_SWIFT_NAME(CIImageAutoAdjustmentOption.crop);
extern CIImageAutoAdjustmentOption const kCIImageAutoAdjustLevel NS_SWIFT_NAME(CIImageAutoAdjustmentOption.level);
@interface CIImage (AutoAdjustment)
- (NSArray<CIFilter *> *)autoAdjustmentFilters;
- (NSArray<CIFilter *> *)autoAdjustmentFiltersWithOptions:(nullable NSDictionary<CIImageAutoAdjustmentOption, id> *)options;
@end

/* image providers: the provider's bytes are asked for once, when the image is first rendered (options: kCIImageProviderTileSize,
   kCIImageProviderUserInfo) */
@protocol CIImageProvider
- (void)provideImageData:(void *)data bytesPerRow:(size_t)rowbytes origin:(size_t)x :(size_t)y size:(size_t)width :(size_t)height
    userInfo:(nullable id)info;
@end
NS_ASSUME_NONNULL_END
