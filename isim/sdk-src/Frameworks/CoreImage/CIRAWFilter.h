#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIFilter.h>
NS_ASSUME_NONNULL_BEGIN
@class CIVector;
/* isim (adapted): RAW files are decoded by the host's LibRaw tools (dcraw_emu, from the libraw-bin package) into
 * linear sensor-white-balanced pixels; exposure, white balance (temperature / tint / chromaticity), boost, noise
 * reduction, sharpness, contrast, detail and local tone mapping are isim's own processing of those pixels, not
 * Apple's RAW pipeline. DNG files written by isim's camera (AVCapturePhotoOutput RAW) are decoded by isim itself. */
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
extern NSString *const kCIInputDecoderVersionKey, *const kCISupportedDecoderVersionsKey, *const kCIInputBoostKey,
    *const kCIInputNeutralChromaticityXKey, *const kCIInputNeutralChromaticityYKey, *const kCIInputNeutralTemperatureKey,
    *const kCIInputNeutralTintKey, *const kCIInputNeutralLocationKey, *const kCIInputScaleFactorKey, *const kCIInputAllowDraftModeKey,
    *const kCIInputIgnoreImageOrientationKey, *const kCIInputImageOrientationKey, *const kCIInputEnableSharpeningKey,
    *const kCIInputEnableChromaticNoiseTrackingKey, *const kCIInputNoiseReductionAmountKey, *const kCIInputMoireAmountKey,
    *const kCIInputEnableVendorLensCorrectionKey, *const kCIInputLuminanceNoiseReductionAmountKey,
    *const kCIInputColorNoiseReductionAmountKey, *const kCIInputNoiseReductionSharpnessAmountKey,
    *const kCIInputNoiseReductionContrastAmountKey, *const kCIInputNoiseReductionDetailAmountKey, *const kCIInputEnableEDRModeKey,
    *const kCIInputLocalToneMapAmountKey, *const kCIInputLinearSpaceFilter, *const kCIOutputNativeSizeKey,
    *const kCIActiveKeys, *const kCIInputBaselineExposureKey, *const kCIInputBoostShadowAmountKey;
@interface CIFilter (CIRAWFilter)
+ (nullable CIFilter *)filterWithImageURL:(NSURL *)url options:(NSDictionary *)options API_DEPRECATED_WITH_REPLACEMENT("CIRAWFilter", ios(10.0, 15.0));
+ (nullable CIFilter *)filterWithImageData:(NSData *)data options:(NSDictionary *)options API_DEPRECATED_WITH_REPLACEMENT("CIRAWFilter", ios(10.0, 15.0));
+ (NSArray<NSString *> *)supportedRawCameraModels API_DEPRECATED_WITH_REPLACEMENT("CIRAWFilter.supportedCameraModels", ios(10.0, 15.0));
@end
NS_ASSUME_NONNULL_END
