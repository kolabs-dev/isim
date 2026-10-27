// isim MetalFX: the temporal scaler. isim: each frame's color is upscaled at its jitter offset and blended with the
// previous output, reprojected through the motion vectors and clamped to the current frame's neighborhood (on the CPU).
// Depth, exposure and the reactive mask are accepted but not used.
#pragma once
#import <MetalFX/MTLFXSpatialScaler.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTLFXTemporalScaler;

API_AVAILABLE(ios(16.0))
@interface MTLFXTemporalScalerDescriptor : NSObject <NSCopying>
@property (readwrite, nonatomic) MTLPixelFormat colorTextureFormat;
@property (readwrite, nonatomic) MTLPixelFormat depthTextureFormat;
@property (readwrite, nonatomic) MTLPixelFormat motionTextureFormat;
@property (readwrite, nonatomic) MTLPixelFormat outputTextureFormat;
@property (readwrite, nonatomic) NSUInteger inputWidth;
@property (readwrite, nonatomic) NSUInteger inputHeight;
@property (readwrite, nonatomic) NSUInteger outputWidth;
@property (readwrite, nonatomic) NSUInteger outputHeight;
@property (readwrite, nonatomic, getter=isAutoExposureEnabled) BOOL autoExposureEnabled;
@property (readwrite, nonatomic) BOOL requiresSynchronousInitialization;
@property (readwrite, nonatomic, getter=isInputContentPropertiesEnabled) BOOL inputContentPropertiesEnabled;
@property (readwrite, nonatomic) float inputContentMinScale;
@property (readwrite, nonatomic) float inputContentMaxScale;
@property (readwrite, nonatomic, getter=isReactiveMaskTextureEnabled) BOOL reactiveMaskTextureEnabled API_AVAILABLE(ios(18.0));
@property (readwrite, nonatomic) MTLPixelFormat reactiveMaskTextureFormat API_AVAILABLE(ios(18.0));
@property (readwrite, nonatomic, getter=isJitteredMotionVectorsEnabled) BOOL jitteredMotionVectorsEnabled API_AVAILABLE(ios(26.0));
@property (readwrite, nonatomic, getter=isOutputResolutionMotionVectorsEnabled) BOOL outputResolutionMotionVectorsEnabled API_AVAILABLE(ios(26.0));
- (nullable id<MTLFXTemporalScaler>)newTemporalScalerWithDevice:(nonnull id<MTLDevice>)device NS_SWIFT_NAME(makeTemporalScaler(device:));
+ (float)supportedInputContentMinScaleForDevice:(nonnull id<MTLDevice>)device NS_SWIFT_NAME(supportedInputContentMinScale(device:)) API_AVAILABLE(ios(17.0));
+ (float)supportedInputContentMaxScaleForDevice:(nonnull id<MTLDevice>)device NS_SWIFT_NAME(supportedInputContentMaxScale(device:)) API_AVAILABLE(ios(17.0));
+ (BOOL)supportsDevice:(nonnull id<MTLDevice>)device;
@end

API_AVAILABLE(ios(16.0))
@protocol MTLFXTemporalScalerBase <NSObject>
@property (readonly, nonatomic) MTLTextureUsage colorTextureUsage;
@property (readonly, nonatomic) MTLTextureUsage depthTextureUsage;
@property (readonly, nonatomic) MTLTextureUsage motionTextureUsage;
@property (readonly, nonatomic) MTLTextureUsage reactiveTextureUsage API_AVAILABLE(ios(18.0));
@property (readonly, nonatomic) MTLTextureUsage outputTextureUsage;
@property (readwrite, nonatomic) NSUInteger inputContentWidth;
@property (readwrite, nonatomic) NSUInteger inputContentHeight;
@property (retain, nonatomic, nullable) id<MTLTexture> colorTexture;
@property (readwrite, nonatomic) NSUInteger colorContentOffsetX API_AVAILABLE(ios(26.0));
@property (readwrite, nonatomic) NSUInteger colorContentOffsetY API_AVAILABLE(ios(26.0));
@property (retain, nonatomic, nullable) id<MTLTexture> depthTexture;
@property (readwrite, nonatomic) NSUInteger depthContentOffsetX API_AVAILABLE(ios(26.0));
@property (readwrite, nonatomic) NSUInteger depthContentOffsetY API_AVAILABLE(ios(26.0));
@property (retain, nonatomic, nullable) id<MTLTexture> motionTexture;
@property (readwrite, nonatomic) NSUInteger motionContentOffsetX API_AVAILABLE(ios(26.0));
@property (readwrite, nonatomic) NSUInteger motionContentOffsetY API_AVAILABLE(ios(26.0));
@property (retain, nonatomic, nullable) id<MTLTexture> outputTexture;
@property (readwrite, nonatomic) NSUInteger outputOffsetX API_AVAILABLE(ios(26.0));
@property (readwrite, nonatomic) NSUInteger outputOffsetY API_AVAILABLE(ios(26.0));
@property (retain, nonatomic, nullable) id<MTLTexture> exposureTexture;
@property (retain, nonatomic, nullable) id<MTLTexture> reactiveMaskTexture API_AVAILABLE(ios(18.0));
@property (readwrite, nonatomic) NSUInteger reactiveMaskContentOffsetX API_AVAILABLE(ios(26.0));
@property (readwrite, nonatomic) NSUInteger reactiveMaskContentOffsetY API_AVAILABLE(ios(26.0));
@property (readonly, nonatomic) MTLTextureUsage reactiveMaskTextureUsage API_AVAILABLE(ios(18.0));
@property (readwrite, nonatomic) float preExposure;
/* the jitter of the frame's samples, in input pixels */
@property (readwrite, nonatomic) float jitterOffsetX;
@property (readwrite, nonatomic) float jitterOffsetY;
/* scales the motion texture's vectors to input pixels; isim: a vector points from the pixel to where it was in the
   previous frame */
@property (readwrite, nonatomic) float motionVectorScaleX;
@property (readwrite, nonatomic) float motionVectorScaleY;
/* the next encode starts the history over */
@property (readwrite, nonatomic) BOOL reset;
@property (readwrite, nonatomic, getter=isDepthReversed) BOOL depthReversed;
@property (readonly, nonatomic) MTLPixelFormat colorTextureFormat;
@property (readonly, nonatomic) MTLPixelFormat depthTextureFormat;
@property (readonly, nonatomic) MTLPixelFormat motionTextureFormat;
@property (readonly, nonatomic) MTLPixelFormat reactiveMaskTextureFormat API_AVAILABLE(ios(18.0));
@property (readonly, nonatomic) MTLPixelFormat outputTextureFormat;
@property (readonly, nonatomic) NSUInteger inputWidth;
@property (readonly, nonatomic) NSUInteger inputHeight;
@property (readonly, nonatomic) NSUInteger outputWidth;
@property (readonly, nonatomic) NSUInteger outputHeight;
@property (readonly, nonatomic) float inputContentMinScale;
@property (readonly, nonatomic) float inputContentMaxScale;
@property (retain, nonatomic, nullable) id<MTLFence> fence;
@end

API_AVAILABLE(ios(16.0))
@protocol MTLFXTemporalScaler <MTLFXTemporalScalerBase>
- (void)encodeToCommandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer NS_SWIFT_NAME(encode(commandBuffer:));
@end

NS_ASSUME_NONNULL_END
