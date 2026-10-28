#pragma once
/* isim SpriteKit: textures: images, sub-rectangles, pixel data, noise and normal maps. */
#import <SpriteKit/SpriteKitBase.h>
#import <CoreImage/CoreImage.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SKTextureFilteringMode) { SKTextureFilteringNearest = 0, SKTextureFilteringLinear };
@interface SKTexture : NSObject
+ (instancetype)textureWithImageNamed:(NSString *)name;
+ (instancetype)textureWithImage:(UIImage *)image;
+ (instancetype)textureWithCGImage:(CGImageRef)image;
+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size flipped:(BOOL)flipped;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size rowLength:(unsigned int)rowLength alignment:(unsigned int)alignment;
+ (instancetype)textureNoiseWithSmoothness:(CGFloat)smoothness size:(CGSize)size grayscale:(BOOL)grayscale;
+ (instancetype)textureVectorNoiseWithSmoothness:(CGFloat)smoothness size:(CGSize)size;
- (instancetype)textureByApplyingCIFilter:(CIFilter *)filter;
- (instancetype)textureByGeneratingNormalMap;
- (instancetype)textureByGeneratingNormalMapWithSmoothness:(CGFloat)smoothness contrast:(CGFloat)contrast;
- (CGRect)textureRect;
- (CGSize)size;
@property (nonatomic) SKTextureFilteringMode filteringMode;
@property (nonatomic) BOOL usesMipmaps;
- (CGImageRef)CGImage CF_RETURNS_NOT_RETAINED;
+ (void)preloadTextures:(NSArray<SKTexture *> *)textures withCompletionHandler:(void (^)(void))completionHandler;
- (void)preloadWithCompletionHandler:(void (^)(void))completionHandler;
@end
@interface SKMutableTexture : SKTexture
+ (instancetype)mutableTextureWithSize:(CGSize)size;
- (instancetype)initWithSize:(CGSize)size;
- (instancetype)initWithSize:(CGSize)size pixelFormat:(int)format;
- (void)modifyPixelDataWithBlock:(void (^)(void * _Nullable pixelData, size_t lengthInBytes))block;
@end
NS_ASSUME_NONNULL_END
#endif
