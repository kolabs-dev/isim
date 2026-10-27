// isim MetalFX (self-authored, Apple's interface): the spatial scaler. isim: an edge-adaptive upscale with sharpening
// after AMD FSR 1 (EASU, then RCAS), on the CPU, in order with the command buffer's other work.
#pragma once
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTLFXSpatialScalerColorProcessingMode) {
    MTLFXSpatialScalerColorProcessingModePerceptual = 0,
    MTLFXSpatialScalerColorProcessingModeLinear = 1,
    MTLFXSpatialScalerColorProcessingModeHDR = 2,
} API_AVAILABLE(ios(16.0));

@protocol MTLFXSpatialScaler;

API_AVAILABLE(ios(16.0))
@interface MTLFXSpatialScalerDescriptor : NSObject <NSCopying>
@property (readwrite, nonatomic) MTLPixelFormat colorTextureFormat;
@property (readwrite, nonatomic) MTLPixelFormat outputTextureFormat;
@property (readwrite, nonatomic) NSUInteger inputWidth;
@property (readwrite, nonatomic) NSUInteger inputHeight;
@property (readwrite, nonatomic) NSUInteger outputWidth;
@property (readwrite, nonatomic) NSUInteger outputHeight;
@property (readwrite, nonatomic) MTLFXSpatialScalerColorProcessingMode colorProcessingMode;
- (nullable id<MTLFXSpatialScaler>)newSpatialScalerWithDevice:(nonnull id<MTLDevice>)device NS_SWIFT_NAME(makeSpatialScaler(device:));
+ (BOOL)supportsDevice:(nonnull id<MTLDevice>)device;
@end

API_AVAILABLE(ios(16.0))
@protocol MTLFXSpatialScalerBase <NSObject>
@property (readonly, nonatomic) MTLTextureUsage colorTextureUsage;
@property (readonly, nonatomic) MTLTextureUsage outputTextureUsage;
@property (readwrite, nonatomic) NSUInteger inputContentWidth;
@property (readwrite, nonatomic) NSUInteger inputContentHeight;
@property (retain, nonatomic, nullable) id<MTLTexture> colorTexture;
@property (retain, nonatomic, nullable) id<MTLTexture> outputTexture;
@property (readonly, nonatomic) MTLPixelFormat colorTextureFormat;
@property (readonly, nonatomic) MTLPixelFormat outputTextureFormat;
@property (readonly, nonatomic) NSUInteger inputWidth;
@property (readonly, nonatomic) NSUInteger inputHeight;
@property (readonly, nonatomic) NSUInteger outputWidth;
@property (readonly, nonatomic) NSUInteger outputHeight;
@property (readonly, nonatomic) MTLFXSpatialScalerColorProcessingMode colorProcessingMode;
@property (retain, nonatomic, nullable) id<MTLFence> fence;
@end

API_AVAILABLE(ios(16.0))
@protocol MTLFXSpatialScaler <MTLFXSpatialScalerBase>
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer NS_SWIFT_NAME(encode(commandBuffer:));
@end

NS_ASSUME_NONNULL_END
