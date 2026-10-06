#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
extern NSString *const kCIInputImageKey, *const kCIInputBackgroundImageKey, *const kCIInputRadiusKey, *const kCIInputIntensityKey,
    *const kCIInputSaturationKey, *const kCIInputBrightnessKey, *const kCIInputContrastKey, *const kCIInputCenterKey, *const kCIInputColorKey,
    *const kCIInputWidthKey, *const kCIInputSharpnessKey, *const kCIInputTransformKey, *const kCIInputAngleKey, *const kCIInputScaleKey,
    *const kCIOutputImageKey, *const kCIAttributeFilterName, *const kCIAttributeFilterDisplayName, *const kCIAttributeFilterCategories,
    *const kCICategoryBuiltIn, *const kCICategoryBlur, *const kCICategoryColorAdjustment, *const kCICategoryColorEffect,
    *const kCICategoryGenerator, *const kCICategoryGeometryAdjustment, *const kCICategoryCompositeOperation, *const kCICategoryStillImage;
/* A filter: inputs set by key (KVC), output computed as a recipe (nothing is rendered until a CIContext draws it). */
@interface CIFilter : NSObject <NSCopying>
+ (nullable CIFilter *)filterWithName:(NSString *)name;
+ (nullable CIFilter *)filterWithName:(NSString *)name withInputParameters:(nullable NSDictionary<NSString *, id> *)params NS_SWIFT_NAME(init(name:parameters:));
+ (nullable CIFilter *)filterWithName:(NSString *)name keysAndValues:(nullable id)key0, ... NS_REQUIRES_NIL_TERMINATION NS_SWIFT_UNAVAILABLE("use init(name:parameters:)");
+ (NSArray<NSString *> *)filterNamesInCategory:(nullable NSString *)category;
+ (NSArray<NSString *> *)filterNamesInCategories:(nullable NSArray<NSString *> *)categories;
+ (nullable NSString *)localizedNameForFilterName:(NSString *)filterName;
@property (readonly, nonatomic, nullable) CIImage *outputImage;
@property (nonatomic, copy) NSString *name;
@property (readonly, nonatomic) NSArray<NSString *> *inputKeys;
@property (readonly, nonatomic) NSArray<NSString *> *outputKeys;
@property (readonly, nonatomic) NSDictionary<NSString *, id> *attributes;
- (void)setDefaults;
@end
NS_ASSUME_NONNULL_END
