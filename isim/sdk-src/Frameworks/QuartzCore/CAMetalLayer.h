#pragma once
/* isim QuartzCore: CAMetalLayer and its drawables (issue #329). Adapted: a drawable's texture is rendered on the CPU by
 * isim's Metal, and presenting it copies the pixels into the layer's contents. The classes are the Metal Swift
 * overlay's (Metal/CAMetalLayer.swift), which QuartzCore.framework re-exports; these declarations are for Objective-C. */
#if !defined(__swift__)
#import <QuartzCore/CALayer.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLDrawable.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice, MTLTexture;
@class CAMetalLayer;
@protocol CAMetalDrawable <MTLDrawable>
@property (readonly) id<MTLTexture> texture;
@property (readonly) CAMetalLayer *layer;
@end
@interface CAMetalLayer : CALayer
@property (nullable, retain) id<MTLDevice> device;
@property (nullable, readonly) id<MTLDevice> preferredDevice;
/* MTLPixelFormatBGRA8Unorm (the default), its sRGB form, RGBA8Unorm, RGBA16Float or BGR10A2Unorm */
@property MTLPixelFormat pixelFormat;
@property BOOL framebufferOnly;
/* the drawables' size in pixels; zero: the layer's bounds times its contentsScale */
@property CGSize drawableSize;
/* nil when every drawable is in use for a second (allowsNextDrawableTimeout) */
- (nullable id<CAMetalDrawable>)nextDrawable;
@property NSUInteger maximumDrawableCount;
@property BOOL presentsWithTransaction;
@property (nullable) CGColorSpaceRef colorspace;
@property BOOL allowsNextDrawableTimeout;
@end
NS_ASSUME_NONNULL_END
#endif
