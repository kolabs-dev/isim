#pragma once
/* a view that draws with Metal: at preferredFramesPerSecond, or when enableSetNeedsDisplay is set, on setNeedsDisplay */
#if !defined(__swift__)
#import <MetalKit/MTKDefines.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
NS_ASSUME_NONNULL_BEGIN
@class MTKView;
@protocol MTKViewDelegate <NSObject>
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size;
- (void)drawInMTKView:(MTKView *)view;
@end
@interface MTKView : UIView
- (instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, weak, nullable) id<MTKViewDelegate> delegate;
@property (nonatomic, retain, nullable) id<MTLDevice> device;
@property (nonatomic, readonly, nullable) id<MTLDevice> preferredDevice;
@property (nonatomic) BOOL framebufferOnly;
@property (nonatomic) BOOL presentsWithTransaction;
@property (nonatomic) MTLPixelFormat colorPixelFormat;
@property (nonatomic) MTLPixelFormat depthStencilPixelFormat;
@property (nonatomic) MTLTextureUsage depthStencilAttachmentTextureUsage;
@property (nonatomic) MTLTextureUsage multisampleColorAttachmentTextureUsage;
@property (nonatomic) MTLStorageMode depthStencilStorageMode;
/* adapted: multisampled attachments hold one sample per pixel on isim (not antialiased) */
@property (nonatomic) NSUInteger sampleCount;
@property (nonatomic) MTLClearColor clearColor;
@property (nonatomic) double clearDepth;
@property (nonatomic) uint32_t clearStencil;
@property (nonatomic, readonly, nullable) id<MTLTexture> depthStencilTexture;
@property (nonatomic, readonly, nullable) id<MTLTexture> multisampleColorTexture;
- (void)releaseDrawables;
@property (nonatomic, readonly, nullable) MTLRenderPassDescriptor *currentRenderPassDescriptor;
@property (nonatomic, readonly, nullable) id<CAMetalDrawable> currentDrawable;
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic) BOOL enableSetNeedsDisplay;
@property (nonatomic) BOOL autoResizeDrawable;
@property (nonatomic) CGSize drawableSize;
@property (nonatomic, readonly) CGSize preferredDrawableSize;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic, nullable) CGColorSpaceRef colorspace;
- (void)draw;
@end
NS_ASSUME_NONNULL_END
#endif
