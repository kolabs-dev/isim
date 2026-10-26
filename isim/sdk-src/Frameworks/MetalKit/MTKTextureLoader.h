#pragma once
/* textures from images (PNG, JPEG and the formats UIImage reads; asset catalog images by name). Not in isim: KTX and
 * PVR files, MDLTexture */
#if !defined(__swift__)
#import <MetalKit/MTKDefines.h>
#import <Metal/Metal.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
MTK_EXTERN NSString * const MTKTextureLoaderErrorDomain;
MTK_EXTERN NSString * const MTKTextureLoaderErrorKey;
typedef NSString *MTKTextureLoaderOption NS_STRING_ENUM;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionAllocateMipmaps;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionGenerateMipmaps;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionSRGB;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionTextureUsage;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionTextureCPUCacheMode;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionTextureStorageMode;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionCubeLayout;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionOrigin;
MTK_EXTERN MTKTextureLoaderOption const MTKTextureLoaderOptionLoadAsArray;
typedef NSString *MTKTextureLoaderOrigin NS_STRING_ENUM;
MTK_EXTERN MTKTextureLoaderOrigin const MTKTextureLoaderOriginTopLeft;
MTK_EXTERN MTKTextureLoaderOrigin const MTKTextureLoaderOriginBottomLeft;
MTK_EXTERN MTKTextureLoaderOrigin const MTKTextureLoaderOriginFlippedVertically;
typedef NSString *MTKTextureLoaderCubeLayout NS_STRING_ENUM;
MTK_EXTERN MTKTextureLoaderCubeLayout const MTKTextureLoaderCubeLayoutVertical;
typedef void (^MTKTextureLoaderCallback)(id<MTLTexture> _Nullable texture, NSError * _Nullable error);
@interface MTKTextureLoader : NSObject
@property (nonatomic, readonly) id<MTLDevice> device;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (nullable id<MTLTexture>)newTextureWithContentsOfURL:(NSURL *)URL options:(nullable NSDictionary<MTKTextureLoaderOption, id> *)options error:(NSError **)error;
- (nullable id<MTLTexture>)newTextureWithData:(NSData *)data options:(nullable NSDictionary<MTKTextureLoaderOption, id> *)options error:(NSError **)error;
- (nullable id<MTLTexture>)newTextureWithCGImage:(CGImageRef)cgImage options:(nullable NSDictionary<MTKTextureLoaderOption, id> *)options error:(NSError **)error;
- (nullable id<MTLTexture>)newTextureWithName:(NSString *)name scaleFactor:(CGFloat)scaleFactor bundle:(nullable NSBundle *)bundle
                                      options:(nullable NSDictionary<MTKTextureLoaderOption, id> *)options error:(NSError **)error;
- (void)newTextureWithContentsOfURL:(NSURL *)URL options:(nullable NSDictionary<MTKTextureLoaderOption, id> *)options completionHandler:(MTKTextureLoaderCallback)completionHandler;
- (void)newTextureWithCGImage:(CGImageRef)cgImage options:(nullable NSDictionary<MTKTextureLoaderOption, id> *)options completionHandler:(MTKTextureLoaderCallback)completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
