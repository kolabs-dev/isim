#pragma once
/* isim SpriteKit: the other node classes: camera, crop, effect, light, audio, video, field, reference and transform nodes, and regions. */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CIFilter, AVAudioNode, AVPlayer;
@interface SKCameraNode : SKNode
- (BOOL)containsNode:(SKNode *)node;
- (NSSet<SKNode *> *)containedNodeSet;
@end
@interface SKCropNode : SKNode
@property (nonatomic, retain, nullable) SKNode *maskNode;
@end
@interface SKEffectNode : SKNode
@property (nonatomic, retain, nullable) CIFilter *filter;
@property (nonatomic) BOOL shouldCenterFilter;
@property (nonatomic) BOOL shouldEnableEffects;
@property (nonatomic) BOOL shouldRasterize;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic, retain, nullable) SKShader *shader;
@end
@interface SKLightNode : SKNode
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) UIColor *lightColor;
@property (nonatomic) UIColor *ambientColor;
@property (nonatomic) UIColor *shadowColor;
@property (nonatomic) CGFloat falloff;
@property (nonatomic) uint32_t categoryBitMask;
@end
@interface SKAudioNode : SKNode
- (instancetype)initWithAVAudioNode:(nullable AVAudioNode *)node;
- (instancetype)initWithFileNamed:(NSString *)name;
- (instancetype)initWithURL:(NSURL *)url;
@property (nonatomic, retain, nullable) AVAudioNode *avAudioNode;
@property (nonatomic) BOOL autoplayLooped;
@property (nonatomic, getter=isPositional) BOOL positional;
@end
@interface SKVideoNode : SKNode
+ (SKVideoNode *)videoNodeWithAVPlayer:(AVPlayer *)player;
+ (SKVideoNode *)videoNodeWithFileNamed:(NSString *)videoFile;
+ (SKVideoNode *)videoNodeWithURL:(NSURL *)videoURL;
- (instancetype)initWithAVPlayer:(AVPlayer *)player;
- (instancetype)initWithFileNamed:(NSString *)videoFile;
- (instancetype)initWithURL:(NSURL *)url;
- (void)play;
- (void)pause;
@property (nonatomic) CGSize size;
@property (nonatomic) CGPoint anchorPoint;
@end
@interface SKRegion : NSObject
+ (instancetype)infiniteRegion;
- (instancetype)initWithRadius:(float)radius;
- (instancetype)initWithSize:(CGSize)size;
- (instancetype)initWithPath:(CGPathRef)path;
- (instancetype)inverseRegion;
- (instancetype)regionByUnionWithRegion:(SKRegion *)region;
- (instancetype)regionByDifferenceFromRegion:(SKRegion *)region;
- (instancetype)regionByIntersectionWithRegion:(SKRegion *)region;
- (BOOL)containsPoint:(CGPoint)point;
@property (nonatomic, readonly, nullable) CGPathRef path;
@end
@interface SKFieldNode : SKNode
@property (nonatomic, retain, nullable) SKRegion *region;
@property (nonatomic) float strength;
@property (nonatomic) float falloff;
@property (nonatomic) float minimumRadius;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isExclusive) BOOL exclusive;
@property (nonatomic) uint32_t categoryBitMask;
@property (nonatomic, retain, nullable) SKTexture *texture;
@property (nonatomic) float smoothness;
@property (nonatomic) float animationSpeed;
+ (SKFieldNode *)dragField;
+ (SKFieldNode *)vortexField;
+ (SKFieldNode *)radialGravityField;
+ (SKFieldNode *)velocityFieldWithTexture:(SKTexture *)velocityTexture;
+ (SKFieldNode *)noiseFieldWithSmoothness:(CGFloat)smoothness animationSpeed:(CGFloat)speed;
+ (SKFieldNode *)turbulenceFieldWithSmoothness:(CGFloat)smoothness animationSpeed:(CGFloat)speed;
+ (SKFieldNode *)springField;
+ (SKFieldNode *)electricField;
+ (SKFieldNode *)magneticField;
@end
@interface SKReferenceNode : SKNode
+ (instancetype)referenceNodeWithFileNamed:(NSString *)fileName;
+ (instancetype)referenceNodeWithURL:(NSURL *)referenceURL;
- (instancetype)initWithFileNamed:(nullable NSString *)fileName;
- (instancetype)initWithURL:(nullable NSURL *)url;
- (void)didLoadReferenceNode:(nullable SKNode *)node;
- (void)resolveReferenceNode;
@end
@interface SKTransformNode : SKNode
@property (nonatomic) CGFloat xRotation;
@property (nonatomic) CGFloat yRotation;
@end
@interface SKWarpGeometry : NSObject <NSCopying>
@end
@interface SKWarpGeometryGrid : SKWarpGeometry
+ (instancetype)grid;
@property (nonatomic, readonly) NSInteger numberOfColumns;
@property (nonatomic, readonly) NSInteger numberOfRows;
@property (nonatomic, readonly) NSInteger vertexCount;
@end
NS_ASSUME_NONNULL_END
#endif
