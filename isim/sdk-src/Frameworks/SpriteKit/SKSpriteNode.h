#pragma once
/* isim SpriteKit: sprites: a texture or a color, with an anchor point, scaling, lighting and a shader. */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKWarpGeometry;
@interface SKSpriteNode : SKNode
+ (instancetype)spriteNodeWithTexture:(nullable SKTexture *)texture size:(CGSize)size;
+ (instancetype)spriteNodeWithTexture:(nullable SKTexture *)texture;
+ (instancetype)spriteNodeWithTexture:(nullable SKTexture *)texture normalMap:(nullable SKTexture *)normalMap;
+ (instancetype)spriteNodeWithImageNamed:(NSString *)name;
+ (instancetype)spriteNodeWithImageNamed:(NSString *)name normalMapped:(BOOL)generateNormalMap;
+ (instancetype)spriteNodeWithColor:(UIColor *)color size:(CGSize)size;
- (instancetype)initWithTexture:(nullable SKTexture *)texture color:(UIColor *)color size:(CGSize)size;
- (instancetype)initWithTexture:(nullable SKTexture *)texture;
- (instancetype)initWithImageNamed:(NSString *)name;
- (instancetype)initWithColor:(UIColor *)color size:(CGSize)size;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
@property (nonatomic, retain, nullable) SKTexture *texture;
@property (nonatomic, retain, nullable) SKTexture *normalTexture;
@property (nonatomic) uint32_t lightingBitMask;
@property (nonatomic) uint32_t shadowCastBitMask;
@property (nonatomic) uint32_t shadowedBitMask;
@property (nonatomic) CGRect centerRect;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic, retain) UIColor *color;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic) CGSize size;
- (void)scaleToSize:(CGSize)size;
@property (nonatomic, retain, nullable) SKShader *shader;
@property (nonatomic, copy, nullable) SKWarpGeometry *warpGeometry;
@property (nonatomic) NSInteger subdivisionLevels;
@end
NS_ASSUME_NONNULL_END
#endif
