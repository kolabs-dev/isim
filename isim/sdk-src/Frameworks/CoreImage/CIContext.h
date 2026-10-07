#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
typedef NSString *CIContextOption NS_TYPED_ENUM;
extern CIContextOption const kCIContextUseSoftwareRenderer, kCIContextWorkingColorSpace, kCIContextOutputColorSpace, kCIContextCacheIntermediates;
/* isim: always a CPU renderer */
@interface CIContext : NSObject
+ (CIContext *)contextWithOptions:(nullable NSDictionary<CIContextOption, id> *)options;
+ (CIContext *)context;
+ (CIContext *)contextWithCGContext:(CGContextRef)cgctx options:(nullable NSDictionary<CIContextOption, id> *)options NS_SWIFT_NAME(init(cgContext:options:));
- (instancetype)initWithOptions:(nullable NSDictionary<CIContextOption, id> *)options;
- (instancetype)init;
- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)fromRect CF_RETURNS_RETAINED NS_SWIFT_NAME(createCGImage(_:from:));
- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)fromRect format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace
    CF_RETURNS_RETAINED NS_SWIFT_NAME(createCGImage(_:from:format:colorSpace:));
- (void)render:(CIImage *)image toBitmap:(void *)data rowBytes:(ptrdiff_t)rowBytes bounds:(CGRect)bounds format:(CIFormat)format colorSpace:(nullable CGColorSpaceRef)colorSpace;
- (void)drawImage:(CIImage *)image inRect:(CGRect)inRect fromRect:(CGRect)fromRect NS_SWIFT_NAME(draw(_:in:from:));
- (nullable NSData *)PNGRepresentationOfImage:(CIImage *)image format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace options:(NSDictionary *)options
    NS_SWIFT_NAME(pngRepresentation(of:format:colorSpace:options:));
- (nullable NSData *)JPEGRepresentationOfImage:(CIImage *)image colorSpace:(CGColorSpaceRef)colorSpace options:(NSDictionary *)options
    NS_SWIFT_NAME(jpegRepresentation(of:colorSpace:options:));
- (void)clearCaches;
@property (nullable, readonly) CGColorSpaceRef workingColorSpace;
@end
NS_ASSUME_NONNULL_END
