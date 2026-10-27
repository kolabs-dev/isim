#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
@class CIKernel;

/* attribute keys */
extern NSString *const kCIAttributeFilterName, *const kCIAttributeFilterDisplayName, *const kCIAttributeDescription,
    *const kCIAttributeFilterAvailable_Mac, *const kCIAttributeFilterAvailable_iOS, *const kCIAttributeReferenceDocumentation,
    *const kCIAttributeFilterCategories, *const kCIAttributeClass, *const kCIAttributeType, *const kCIAttributeMin, *const kCIAttributeMax,
    *const kCIAttributeSliderMin, *const kCIAttributeSliderMax, *const kCIAttributeDefault, *const kCIAttributeIdentity,
    *const kCIAttributeName, *const kCIAttributeDisplayName;
extern NSString *const kCIUIParameterSet, *const kCIUISetBasic, *const kCIUISetIntermediate, *const kCIUISetAdvanced, *const kCIUISetDevelopment;
/* attribute types */
extern NSString *const kCIAttributeTypeTime, *const kCIAttributeTypeScalar, *const kCIAttributeTypeDistance, *const kCIAttributeTypeAngle,
    *const kCIAttributeTypeBoolean, *const kCIAttributeTypeInteger, *const kCIAttributeTypeCount, *const kCIAttributeTypePosition,
    *const kCIAttributeTypeOffset, *const kCIAttributeTypePosition3, *const kCIAttributeTypeRectangle, *const kCIAttributeTypeOpaqueColor,
    *const kCIAttributeTypeColor, *const kCIAttributeTypeGradient, *const kCIAttributeTypeImage, *const kCIAttributeTypeTransform;
/* categories */
extern NSString *const kCICategoryDistortionEffect, *const kCICategoryGeometryAdjustment, *const kCICategoryCompositeOperation,
    *const kCICategoryHalftoneEffect, *const kCICategoryColorAdjustment, *const kCICategoryColorEffect, *const kCICategoryTransition,
    *const kCICategoryTileEffect, *const kCICategoryGenerator, *const kCICategoryReduction, *const kCICategoryGradient,
    *const kCICategoryStylize, *const kCICategorySharpen, *const kCICategoryBlur, *const kCICategoryVideo, *const kCICategoryStillImage,
    *const kCICategoryInterlaced, *const kCICategoryNonSquarePixels, *const kCICategoryHighDynamicRange, *const kCICategoryBuiltIn,
    *const kCICategoryFilterGenerator;
/* input and output keys */
extern NSString *const kCIOutputImageKey, *const kCIInputBackgroundImageKey, *const kCIInputImageKey, *const kCIInputDepthImageKey,
    *const kCIInputDisparityImageKey, *const kCIInputAmountKey, *const kCIInputTimeKey, *const kCIInputTransformKey, *const kCIInputScaleKey,
    *const kCIInputAspectRatioKey, *const kCIInputCenterKey, *const kCIInputRadiusKey, *const kCIInputAngleKey, *const kCIInputRefractionKey,
    *const kCIInputWidthKey, *const kCIInputSharpnessKey, *const kCIInputIntensityKey, *const kCIInputEVKey, *const kCIInputSaturationKey,
    *const kCIInputColorKey, *const kCIInputBrightnessKey, *const kCIInputContrastKey, *const kCIInputBiasKey, *const kCIInputWeightsKey,
    *const kCIInputGradientImageKey, *const kCIInputMaskImageKey, *const kCIInputMatteImageKey, *const kCIInputShadingImageKey,
    *const kCIInputTargetImageKey, *const kCIInputExtentKey, *const kCIInputVersionKey;
/* iOS 26 */
extern NSString *const kCIInputBacksideImageKey, *const kCIInputBiasVectorKey, *const kCIInputColor0Key, *const kCIInputColor1Key, *const kCIInputColorSpaceKey, *const kCIInputCountKey, *const kCIInputExtrapolateKey, *const kCIInputPaletteImageKey, *const kCIInputPerceptualKey, *const kCIInputPoint0Key, *const kCIInputPoint1Key, *const kCIInputRadius0Key, *const kCIInputRadius1Key, *const kCIInputThresholdKey API_AVAILABLE(ios(26.0));
/* options of -[CIFilter apply:arguments:options:] */
extern NSString *const kCIApplyOptionExtent, *const kCIApplyOptionDefinition, *const kCIApplyOptionUserInfo, *const kCIApplyOptionColorSpace;

/* A filter: inputs set by key (KVC), output computed as a recipe (nothing is rendered until a CIContext draws it).
 * Built-in filters are instances of private per-filter subclasses (like iOS); subclasses written by apps declare
 * their inputs as properties named input... and override outputImage. */
@interface CIFilter : NSObject <NSSecureCoding, NSCopying>
@property (readonly, nonatomic, nullable) CIImage *outputImage;
@property (nonatomic, copy) NSString *name;
@property (readonly, nonatomic) NSArray<NSString *> *inputKeys;
@property (readonly, nonatomic) NSArray<NSString *> *outputKeys;
@property (readonly, nonatomic) NSDictionary<NSString *, id> *attributes;
- (void)setDefaults;
- (nullable CIImage *)apply:(CIKernel *)k arguments:(nullable NSArray *)args options:(nullable NSDictionary<NSString *, id> *)dict;
- (nullable CIImage *)apply:(CIKernel *)k, ... NS_REQUIRES_NIL_TERMINATION NS_SWIFT_UNAVAILABLE("use apply(_:arguments:options:)");
@end

@protocol CIFilterConstructor
- (nullable CIFilter *)filterWithName:(NSString *)name;
@end

@interface CIFilter (CIFilterRegistry)
+ (nullable CIFilter *)filterWithName:(NSString *)name;
+ (nullable CIFilter *)filterWithName:(NSString *)name keysAndValues:(nullable id)key0, ... NS_REQUIRES_NIL_TERMINATION NS_SWIFT_UNAVAILABLE("use init(name:parameters:)");
+ (nullable CIFilter *)filterWithName:(NSString *)name withInputParameters:(nullable NSDictionary<NSString *, id> *)params NS_SWIFT_NAME(init(name:parameters:));
+ (NSArray<NSString *> *)filterNamesInCategory:(nullable NSString *)category;
+ (NSArray<NSString *> *)filterNamesInCategories:(nullable NSArray<NSString *> *)categories;
+ (void)registerFilterName:(NSString *)name constructor:(id<CIFilterConstructor>)anObject classAttributes:(NSDictionary<NSString *, id> *)attributes;
+ (nullable NSString *)localizedNameForFilterName:(NSString *)filterName;
+ (NSString *)localizedNameForCategory:(NSString *)category;
+ (nullable NSString *)localizedDescriptionForFilterName:(NSString *)filterName;
+ (nullable NSURL *)localizedReferenceDocumentationForFilterName:(NSString *)filterName;
@end

/* Filter arrays as XMP. isim (adapted): the filters and their inputs are written in isim's own XMP namespace
 * (http://isim.dev/ns/coreimage/1.0/), which isim reads back; Apple's packets (Camera Raw settings) are not parsed */
@interface CIFilter (CIFilterXMPSerialization)
+ (nullable NSData *)serializedXMPFromFilters:(NSArray<CIFilter *> *)filters inputImageExtent:(CGRect)extent;
+ (NSArray<CIFilter *> *)filterArrayFromSerializedXMP:(NSData *)xmpData inputImageExtent:(CGRect)extent error:(NSError **)outError;
@end
NS_ASSUME_NONNULL_END
