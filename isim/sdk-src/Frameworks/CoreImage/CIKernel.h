#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: kernels are interpreted on the CPU. Sources in the Core Image Kernel Language (kernelWithString:,
 * kernelsWithString:) and Metal Core Image kernels (kernelsWithMetalString:error:, and kernelWithFunctionName:
 * fromMetalLibraryData: with a default.metallib built by isim, which holds the .metal sources) are parsed and run by
 * isim's kernel interpreter (a subset of each language: scalar and vector math, swizzles, control flow, the Core
 * Image and common math functions). */
typedef CGRect (^CIKernelROICallback)(int index, CGRect destRect);
@interface CIKernel : NSObject
+ (nullable NSArray<CIKernel *> *)kernelsWithString:(NSString *)string NS_SWIFT_NAME(kernels(withString:)) API_DEPRECATED("Core Image Kernel Language API deprecated", ios(8.0, 12.0));
+ (nullable NSArray<CIKernel *> *)kernelsWithMetalString:(NSString *)source error:(NSError **)error NS_SWIFT_NAME(kernels(withMetalString:)) API_AVAILABLE(ios(18.0));
+ (nullable instancetype)kernelWithString:(NSString *)string NS_SWIFT_NAME(init(source:)) API_DEPRECATED("Core Image Kernel Language API deprecated", ios(8.0, 12.0));
+ (nullable instancetype)kernelWithFunctionName:(NSString *)name fromMetalLibraryData:(NSData *)data error:(NSError **)error;
+ (nullable instancetype)kernelWithFunctionName:(NSString *)name fromMetalLibraryData:(NSData *)data outputPixelFormat:(CIFormat)format error:(NSError **)error;
+ (NSArray<NSString *> *)kernelNamesFromMetalLibraryData:(NSData *)data API_AVAILABLE(ios(17.0));
@property (atomic, readonly) NSString *name;
- (BOOL)setROISelector:(SEL)method;
- (nullable CIImage *)applyWithExtent:(CGRect)extent roiCallback:(CIKernelROICallback)callback arguments:(nullable NSArray<id> *)args
    NS_SWIFT_NAME(apply(extent:roiCallback:arguments:));
@end
@interface CIColorKernel : CIKernel
+ (nullable instancetype)kernelWithString:(NSString *)string NS_SWIFT_NAME(init(source:)) API_DEPRECATED("Core Image Kernel Language API deprecated", ios(8.0, 12.0));
- (nullable CIImage *)applyWithExtent:(CGRect)extent arguments:(nullable NSArray<id> *)args NS_SWIFT_NAME(apply(extent:arguments:));
@end
@interface CIWarpKernel : CIKernel
+ (nullable instancetype)kernelWithString:(NSString *)string NS_SWIFT_NAME(init(source:)) API_DEPRECATED("Core Image Kernel Language API deprecated", ios(8.0, 12.0));
- (nullable CIImage *)applyWithExtent:(CGRect)extent roiCallback:(CIKernelROICallback)callback inputImage:(CIImage *)image arguments:(nullable NSArray<id> *)args
    NS_SWIFT_NAME(apply(extent:roiCallback:image:arguments:));
@end
@interface CIBlendKernel : CIColorKernel
+ (nullable instancetype)kernelWithString:(NSString *)string NS_SWIFT_NAME(init(source:)) API_DEPRECATED("Core Image Kernel Language API deprecated", ios(8.0, 12.0));
- (nullable CIImage *)applyWithForeground:(CIImage *)foreground background:(CIImage *)background NS_SWIFT_NAME(apply(foreground:background:));
- (nullable CIImage *)applyWithForeground:(CIImage *)foreground background:(CIImage *)background colorSpace:(CGColorSpaceRef)colorSpace
    NS_SWIFT_NAME(apply(foreground:background:colorSpace:));
@property (class, strong, readonly) CIBlendKernel *componentAdd, *componentMultiply, *componentMin, *componentMax, *clear, *source,
    *destination, *sourceOver, *destinationOver, *sourceIn, *destinationIn, *sourceOut, *destinationOut, *sourceAtop, *destinationAtop,
    *exclusiveOr, *multiply, *screen, *overlay, *darken, *lighten, *colorDodge, *colorBurn, *hardLight, *softLight, *difference,
    *exclusion, *hue, *saturation, *color, *luminosity, *subtract, *divide, *linearBurn, *linearDodge, *vividLight, *linearLight,
    *pinLight, *hardMix, *darkerColor, *lighterColor;
@end
NS_ASSUME_NONNULL_END
