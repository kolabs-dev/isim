#pragma once
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
NS_ASSUME_NONNULL_BEGIN
@class CIColor, CIFilter, UIImage;
typedef NSString *CIImageOption NS_TYPED_ENUM;
typedef int CIFormat;
extern CIFormat kCIFormatRGBA8, kCIFormatBGRA8, kCIFormatARGB8, kCIFormatRGBAf;
/* An image recipe in Core Image's space (y up, origin at the lower left of a CGImage's extent); rendered by CIContext. */
@interface CIImage : NSObject <NSCopying>
+ (CIImage *)imageWithCGImage:(CGImageRef)image;
+ (CIImage *)imageWithCGImage:(CGImageRef)image options:(nullable NSDictionary<CIImageOption, id> *)options;
+ (nullable CIImage *)imageWithData:(NSData *)data;
+ (nullable CIImage *)imageWithContentsOfURL:(NSURL *)url;
+ (CIImage *)imageWithColor:(CIColor *)color;
+ (CIImage *)emptyImage NS_SWIFT_NAME(empty());
+ (CIImage *)imageWithBitmapData:(NSData *)data bytesPerRow:(size_t)bytesPerRow size:(CGSize)size format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace;
- (instancetype)initWithCGImage:(CGImageRef)image;
- (instancetype)initWithCGImage:(CGImageRef)image options:(nullable NSDictionary<CIImageOption, id> *)options;
- (nullable instancetype)initWithData:(NSData *)data;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;
- (instancetype)initWithColor:(CIColor *)color;
- (instancetype)initWithBitmapData:(NSData *)data bytesPerRow:(size_t)bytesPerRow size:(CGSize)size format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace;
/* UIKit additions */
- (nullable instancetype)initWithImage:(UIImage *)image;
- (nullable instancetype)initWithImage:(UIImage *)image options:(nullable NSDictionary<CIImageOption, id> *)options;
@property (readonly) CGRect extent;
@property (nullable, readonly) CGImageRef CGImage;
@property (readonly) NSDictionary<NSString *, id> *properties;
@property (nullable, readonly) CGColorSpaceRef colorSpace;
@property (nullable, readonly) NSURL *url;
- (CIImage *)imageByApplyingTransform:(CGAffineTransform)matrix NS_SWIFT_NAME(transformed(by:));
- (CIImage *)imageByApplyingTransform:(CGAffineTransform)matrix highQualityDownsample:(BOOL)hq NS_SWIFT_NAME(transformed(by:highQualityDownsample:));
- (CIImage *)imageByApplyingOrientation:(int)orientation NS_SWIFT_NAME(oriented(forExifOrientation:));
- (CIImage *)imageByApplyingCGOrientation:(CGImagePropertyOrientation)orientation NS_SWIFT_NAME(oriented(_:));
- (CGAffineTransform)imageTransformForOrientation:(int)orientation NS_SWIFT_NAME(orientationTransform(forExifOrientation:));
- (CIImage *)imageByCroppingToRect:(CGRect)rect NS_SWIFT_NAME(cropped(to:));
- (CIImage *)imageByClampingToExtent NS_SWIFT_NAME(clampedToExtent());
- (CIImage *)imageByClampingToRect:(CGRect)rect NS_SWIFT_NAME(clamped(to:));
- (CIImage *)imageByCompositingOverImage:(CIImage *)dest NS_SWIFT_NAME(composited(over:));
- (CIImage *)imageByApplyingFilter:(NSString *)filterName withInputParameters:(nullable NSDictionary<NSString *, id> *)params NS_SWIFT_NAME(applyingFilter(_:parameters:));
- (CIImage *)imageByApplyingFilter:(NSString *)filterName NS_SWIFT_NAME(applyingFilter(_:));
- (CIImage *)imageByApplyingGaussianBlurWithSigma:(double)sigma NS_SWIFT_NAME(applyingGaussianBlur(sigma:));
- (CIImage *)imageBySettingAlphaOneInExtent:(CGRect)extent NS_SWIFT_NAME(settingAlphaOne(in:));
- (CIImage *)imageByPremultiplyingAlpha NS_SWIFT_NAME(premultiplyingAlpha());
- (CIImage *)imageByUnpremultiplyingAlpha NS_SWIFT_NAME(unpremultiplyingAlpha());
@end
NS_ASSUME_NONNULL_END
