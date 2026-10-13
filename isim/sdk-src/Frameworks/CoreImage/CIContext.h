#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
@class CIFilter;
typedef NSString *CIContextOption NS_TYPED_ENUM;
extern CIContextOption const kCIContextOutputColorSpace;
extern CIContextOption const kCIContextWorkingColorSpace;
extern CIContextOption const kCIContextWorkingFormat;
extern CIContextOption const kCIContextHighQualityDownsample;
extern CIContextOption const kCIContextOutputPremultiplied;
extern CIContextOption const kCIContextCacheIntermediates;
extern CIContextOption const kCIContextUseSoftwareRenderer;
extern CIContextOption const kCIContextPriorityRequestLow;
extern CIContextOption const kCIContextAllowLowPower;
extern CIContextOption const kCIContextName;
extern CIContextOption const kCIContextMemoryLimit;

/* isim: every context renders on the CPU (in parallel bands); a context made with a CGContext draws into it */
@interface CIContext : NSObject
+ (CIContext *)contextWithCGContext:(CGContextRef)cgctx options:(nullable NSDictionary<CIContextOption, id> *)options NS_SWIFT_NAME(init(cgContext:options:));
+ (CIContext *)contextWithOptions:(nullable NSDictionary<CIContextOption, id> *)options;
+ (CIContext *)context;
- (instancetype)initWithOptions:(nullable NSDictionary<CIContextOption, id> *)options;
- (instancetype)init;
@property (nullable, nonatomic, readonly) CGColorSpaceRef workingColorSpace;
@property (nonatomic, readonly) CIFormat workingFormat;
- (void)drawImage:(CIImage *)image inRect:(CGRect)inRect fromRect:(CGRect)fromRect NS_SWIFT_NAME(draw(_:in:from:));
- (void)drawImage:(CIImage *)image atPoint:(CGPoint)atPoint fromRect:(CGRect)fromRect;
- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)fromRect CF_RETURNS_RETAINED NS_SWIFT_NAME(createCGImage(_:from:));
- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)fromRect format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace
    CF_RETURNS_RETAINED NS_SWIFT_NAME(createCGImage(_:from:format:colorSpace:));
- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)fromRect format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace
    deferred:(BOOL)deferred CF_RETURNS_RETAINED NS_SWIFT_NAME(createCGImage(_:from:format:colorSpace:deferred:));
/* colorSpace nil: the bitmap gets the working space's values (no color matching) */
- (void)render:(CIImage *)image toBitmap:(void *)data rowBytes:(ptrdiff_t)rowBytes bounds:(CGRect)bounds format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace;
- (void)clearCaches;
- (void)reclaimResources;
- (CGSize)inputImageMaximumSize;
- (CGSize)outputImageMaximumSize;
@end

typedef NSString *CIImageRepresentationOption NS_TYPED_ENUM;
extern CIImageRepresentationOption const kCIImageRepresentationAVDepthData;
extern CIImageRepresentationOption const kCIImageRepresentationDepthImage;
extern CIImageRepresentationOption const kCIImageRepresentationDisparityImage;
extern CIImageRepresentationOption const kCIImageRepresentationAVPortraitEffectsMatte;
extern CIImageRepresentationOption const kCIImageRepresentationPortraitEffectsMatteImage;
extern CIImageRepresentationOption const kCIImageRepresentationAVSemanticSegmentationMattes;
extern CIImageRepresentationOption const kCIImageRepresentationSemanticSegmentationSkinMatteImage;
extern CIImageRepresentationOption const kCIImageRepresentationSemanticSegmentationHairMatteImage;
extern CIImageRepresentationOption const kCIImageRepresentationSemanticSegmentationTeethMatteImage;
extern CIImageRepresentationOption const kCIImageRepresentationSemanticSegmentationGlassesMatteImage;
extern CIImageRepresentationOption const kCIImageRepresentationSemanticSegmentationSkyMatteImage;
extern CIImageRepresentationOption const kCIImageRepresentationHDRImage;
extern CIImageRepresentationOption const kCIImageRepresentationHDRGainMapImage;

/* isim: PNG and JPEG through ImageIO; HEIF through isim's HEIF writer (the host's ffmpeg libx265; nil without it);
 * TIFF and OpenEXR (uncompressed) are written by Core Image itself */
@interface CIContext (ImageRepresentation)
- (nullable NSData *)TIFFRepresentationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options NS_SWIFT_NAME(tiffRepresentation(of:format:colorSpace:options:));
- (nullable NSData *)JPEGRepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options NS_SWIFT_NAME(jpegRepresentation(of:colorSpace:options:));
- (nullable NSData *)HEIFRepresentationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options NS_SWIFT_NAME(heifRepresentation(of:format:colorSpace:options:));
- (nullable NSData *)HEIF10RepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options error:(NSError **)errorPtr NS_SWIFT_NAME(heif10Representation(of:colorSpace:options:));
- (nullable NSData *)PNGRepresentationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options NS_SWIFT_NAME(pngRepresentation(of:format:colorSpace:options:));
- (nullable NSData *)OpenEXRRepresentationOfImage:(CIImage *)image options:(NSDictionary<CIImageRepresentationOption, id> *)options
    error:(NSError **)errorPtr NS_SWIFT_NAME(openEXRRepresentation(of:options:));
- (BOOL)writeTIFFRepresentationOfImage:(CIImage *)image toURL:(NSURL *)url format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options error:(NSError **)errorPtr NS_SWIFT_NAME(writeTIFFRepresentation(of:to:format:colorSpace:options:));
- (BOOL)writePNGRepresentationOfImage:(CIImage *)image toURL:(NSURL *)url format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options error:(NSError **)errorPtr NS_SWIFT_NAME(writePNGRepresentation(of:to:format:colorSpace:options:));
- (BOOL)writeJPEGRepresentationOfImage:(CIImage *)image toURL:(NSURL *)url colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options error:(NSError **)errorPtr NS_SWIFT_NAME(writeJPEGRepresentation(of:to:colorSpace:options:));
- (BOOL)writeHEIFRepresentationOfImage:(CIImage *)image toURL:(NSURL *)url format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options error:(NSError **)errorPtr NS_SWIFT_NAME(writeHEIFRepresentation(of:to:format:colorSpace:options:));
- (BOOL)writeHEIF10RepresentationOfImage:(CIImage *)image toURL:(NSURL *)url colorSpace:(CGColorSpaceRef)colorSpace
    options:(NSDictionary<CIImageRepresentationOption, id> *)options error:(NSError **)errorPtr NS_SWIFT_NAME(writeHEIF10Representation(of:to:colorSpace:options:));
- (BOOL)writeOpenEXRRepresentationOfImage:(CIImage *)image toURL:(NSURL *)url options:(NSDictionary<CIImageRepresentationOption, id> *)options
    error:(NSError **)errorPtr NS_SWIFT_NAME(writeOpenEXRRepresentation(of:to:options:));
@end

/* Portrait depth effect: the filter is CIDepthBlurEffect, set up from the image's auxiliary disparity and matte */
@interface CIContext (CIDepthBlurEffect)
- (nullable CIFilter *)depthBlurEffectFilterForImageURL:(NSURL *)url options:(nullable NSDictionary *)options;
- (nullable CIFilter *)depthBlurEffectFilterForImageData:(NSData *)data options:(nullable NSDictionary *)options;
- (nullable CIFilter *)depthBlurEffectFilterForImage:(CIImage *)image disparityImage:(CIImage *)disparityImage
    portraitEffectsMatte:(nullable CIImage *)portraitEffectsMatte orientation:(CGImagePropertyOrientation)orientation options:(nullable NSDictionary *)options;
- (nullable CIFilter *)depthBlurEffectFilterForImage:(CIImage *)image disparityImage:(CIImage *)disparityImage
    portraitEffectsMatte:(nullable CIImage *)portraitEffectsMatte hairSemanticSegmentation:(nullable CIImage *)hairSemanticSegmentation
    orientation:(CGImagePropertyOrientation)orientation options:(nullable NSDictionary *)options;
- (nullable CIFilter *)depthBlurEffectFilterForImage:(CIImage *)image disparityImage:(CIImage *)disparityImage
    portraitEffectsMatte:(nullable CIImage *)portraitEffectsMatte hairSemanticSegmentation:(nullable CIImage *)hairSemanticSegmentation
    glassesMatte:(nullable CIImage *)glassesMatte gainMap:(nullable CIImage *)gainMap orientation:(CGImagePropertyOrientation)orientation
    options:(nullable NSDictionary *)options;
@end
NS_ASSUME_NONNULL_END
