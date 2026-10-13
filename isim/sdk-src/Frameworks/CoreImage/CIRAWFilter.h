#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIFilter.h>
NS_ASSUME_NONNULL_BEGIN
@class CIVector;
/* isim (adapted): RAW files are decoded by the host's LibRaw tools (dcraw_emu, from the libraw-bin package) into
 * linear sensor-white-balanced pixels; exposure, white balance (temperature / tint / chromaticity), boost, noise
 * reduction, sharpness, contrast, detail, moire and local tone mapping are isim's own processing of those pixels, not
 * Apple's RAW pipeline. Lens correction is not supported; the semantic mattes are nil (stub). Without the LibRaw tools
 * the filters cannot be created (nil). */
typedef NSString *CIRAWDecoderVersion NS_TYPED_ENUM;
extern CIRAWDecoderVersion const CIRAWDecoderVersionNone, CIRAWDecoderVersion8, CIRAWDecoderVersion8DNG, CIRAWDecoderVersion7,
    CIRAWDecoderVersion7DNG, CIRAWDecoderVersion6, CIRAWDecoderVersion6DNG;
API_AVAILABLE(ios(15.0))
@interface CIRAWFilter : CIFilter
@property (class, readonly) NSArray<NSString *> *supportedCameraModels;
+ (nullable instancetype)filterWithImageURL:(NSURL *)url;
+ (nullable instancetype)filterWithImageData:(NSData *)data identifierHint:(nullable NSString *)identifierHint;
@property (readonly) NSArray<CIRAWDecoderVersion> *supportedDecoderVersions;
@property (readonly) CGSize nativeSize;
@property (readonly) NSDictionary *properties;
@property CGImagePropertyOrientation orientation;
@property (getter=isDraftModeEnabled) BOOL draftModeEnabled;
@property (copy) CIRAWDecoderVersion decoderVersion;
@property float scaleFactor;
@property float exposure;
@property float baselineExposure;
@property float shadowBias;
@property float boostAmount;
@property float boostShadowAmount;
@property (readonly, getter=isHighlightRecoverySupported) BOOL highlightRecoverySupported;
@property (getter=isHighlightRecoveryEnabled) BOOL highlightRecoveryEnabled;
@property (getter=isGamutMappingEnabled) BOOL gamutMappingEnabled;
@property (readonly, getter=isLensCorrectionSupported) BOOL lensCorrectionSupported;
@property (getter=isLensCorrectionEnabled) BOOL lensCorrectionEnabled;
@property (readonly, getter=isLuminanceNoiseReductionSupported) BOOL luminanceNoiseReductionSupported;
@property float luminanceNoiseReductionAmount;
@property (readonly, getter=isColorNoiseReductionSupported) BOOL colorNoiseReductionSupported;
@property float colorNoiseReductionAmount;
@property (readonly, getter=isSharpnessSupported) BOOL sharpnessSupported;
@property float sharpnessAmount;
@property (readonly, getter=isContrastSupported) BOOL contrastSupported;
@property float contrastAmount;
@property (readonly, getter=isDetailSupported) BOOL detailSupported;
@property float detailAmount;
@property (readonly, getter=isMoireReductionSupported) BOOL moireReductionSupported;
@property float moireReductionAmount;
@property (readonly, getter=isLocalToneMapSupported) BOOL localToneMapSupported;
@property float localToneMapAmount;
@property float extendedDynamicRangeAmount;
@property CIVector *neutralChromaticity;
@property CGPoint neutralLocation;
@property float neutralTemperature;
@property float neutralTint;
@property (nullable, retain) CIFilter *linearSpaceFilter;
@property (readonly, nullable) CIImage *previewImage;
@property (readonly, nullable) CIImage *portraitEffectsMatte;
@property (readonly, nullable) CIImage *semanticSegmentationSkinMatte;
@property (readonly, nullable) CIImage *semanticSegmentationHairMatte;
@property (readonly, nullable) CIImage *semanticSegmentationGlassesMatte;
@property (readonly, nullable) CIImage *semanticSegmentationSkyMatte;
@property (readonly, nullable) CIImage *semanticSegmentationTeethMatte;
@end

/* the pre-iOS 15 RAW API (CIFilter with option keys) */
typedef NSString *CIRAWFilterOption NS_TYPED_ENUM;
extern CIRAWFilterOption const kCIInputDecoderVersionKey NS_SWIFT_NAME(CIRAWFilterOption.decoderVersion);
extern CIRAWFilterOption const kCISupportedDecoderVersionsKey NS_SWIFT_NAME(CIRAWFilterOption.supportedDecoderVersions);
extern CIRAWFilterOption const kCIInputBoostKey NS_SWIFT_NAME(CIRAWFilterOption.boost);
extern CIRAWFilterOption const kCIInputNeutralChromaticityXKey NS_SWIFT_NAME(CIRAWFilterOption.neutralChromaticityX);
extern CIRAWFilterOption const kCIInputNeutralChromaticityYKey NS_SWIFT_NAME(CIRAWFilterOption.neutralChromaticityY);
extern CIRAWFilterOption const kCIInputNeutralTemperatureKey NS_SWIFT_NAME(CIRAWFilterOption.neutralTemperature);
extern CIRAWFilterOption const kCIInputNeutralTintKey NS_SWIFT_NAME(CIRAWFilterOption.neutralTint);
extern CIRAWFilterOption const kCIInputNeutralLocationKey NS_SWIFT_NAME(CIRAWFilterOption.neutralLocation);
extern CIRAWFilterOption const kCIInputScaleFactorKey NS_SWIFT_NAME(CIRAWFilterOption.scaleFactor);
extern CIRAWFilterOption const kCIInputAllowDraftModeKey NS_SWIFT_NAME(CIRAWFilterOption.allowDraftMode);
extern CIRAWFilterOption const kCIInputIgnoreImageOrientationKey NS_SWIFT_NAME(CIRAWFilterOption.ignoreImageOrientation);
extern CIRAWFilterOption const kCIInputImageOrientationKey NS_SWIFT_NAME(CIRAWFilterOption.imageOrientation);
extern CIRAWFilterOption const kCIInputEnableSharpeningKey NS_SWIFT_NAME(CIRAWFilterOption.enableSharpening);
extern CIRAWFilterOption const kCIInputEnableChromaticNoiseTrackingKey NS_SWIFT_NAME(CIRAWFilterOption.enableChromaticNoiseTracking);
extern CIRAWFilterOption const kCIInputNoiseReductionAmountKey NS_SWIFT_NAME(CIRAWFilterOption.noiseReductionAmount);
extern CIRAWFilterOption const kCIInputMoireAmountKey NS_SWIFT_NAME(CIRAWFilterOption.moireAmount);
extern CIRAWFilterOption const kCIInputEnableVendorLensCorrectionKey NS_SWIFT_NAME(CIRAWFilterOption.enableVendorLensCorrection);
extern CIRAWFilterOption const kCIInputLuminanceNoiseReductionAmountKey NS_SWIFT_NAME(CIRAWFilterOption.luminanceNoiseReductionAmount);
extern CIRAWFilterOption const kCIInputColorNoiseReductionAmountKey NS_SWIFT_NAME(CIRAWFilterOption.colorNoiseReductionAmount);
extern CIRAWFilterOption const kCIInputNoiseReductionSharpnessAmountKey NS_SWIFT_NAME(CIRAWFilterOption.noiseReductionSharpnessAmount);
extern CIRAWFilterOption const kCIInputNoiseReductionContrastAmountKey NS_SWIFT_NAME(CIRAWFilterOption.noiseReductionContrastAmount);
extern CIRAWFilterOption const kCIInputNoiseReductionDetailAmountKey NS_SWIFT_NAME(CIRAWFilterOption.noiseReductionDetailAmount);
extern CIRAWFilterOption const kCIInputEnableEDRModeKey NS_SWIFT_NAME(CIRAWFilterOption.enableEDRMode);
extern CIRAWFilterOption const kCIInputLocalToneMapAmountKey NS_SWIFT_NAME(CIRAWFilterOption.localToneMapAmount);
extern CIRAWFilterOption const kCIInputLinearSpaceFilter NS_SWIFT_NAME(CIRAWFilterOption.linearSpaceFilter);
extern CIRAWFilterOption const kCIOutputNativeSizeKey NS_SWIFT_NAME(CIRAWFilterOption.outputNativeSize);
extern CIRAWFilterOption const kCIActiveKeys NS_SWIFT_NAME(CIRAWFilterOption.activeKeys);
extern CIRAWFilterOption const kCIInputBaselineExposureKey NS_SWIFT_NAME(CIRAWFilterOption.baselineExposure);
extern CIRAWFilterOption const kCIInputBoostShadowAmountKey NS_SWIFT_NAME(CIRAWFilterOption.boostShadowAmount);
@interface CIFilter (CIRAWFilter)
+ (nullable CIFilter *)filterWithImageURL:(NSURL *)url options:(NSDictionary<CIRAWFilterOption, id> *)options API_DEPRECATED_WITH_REPLACEMENT("CIRAWFilter", ios(10.0, 15.0));
+ (nullable CIFilter *)filterWithImageData:(NSData *)data options:(NSDictionary<CIRAWFilterOption, id> *)options API_DEPRECATED_WITH_REPLACEMENT("CIRAWFilter", ios(10.0, 15.0));
+ (NSArray<NSString *> *)supportedRawCameraModels API_DEPRECATED_WITH_REPLACEMENT("CIRAWFilter.supportedCameraModels", ios(10.0, 15.0));
@end
NS_ASSUME_NONNULL_END
