#pragma once
/* isim SpriteKit: particle emitters and keyframe sequences. */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SKInterpolationMode) { SKInterpolationModeLinear = 1, SKInterpolationModeSpline = 2, SKInterpolationModeStep = 3 };
typedef NS_ENUM(NSInteger, SKRepeatMode) { SKRepeatModeClamp = 1, SKRepeatModeLoop = 2 };
@interface SKKeyframeSequence : NSObject
- (instancetype)initWithKeyframeValues:(NSArray *)values times:(NSArray<NSNumber *> *)times;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
- (NSUInteger)count;
- (void)addKeyframeValue:(id)value time:(CGFloat)time;
- (void)removeLastKeyframe;
- (void)removeKeyframeAtIndex:(NSUInteger)index;
- (void)setKeyframeValue:(id)value forIndex:(NSUInteger)index;
- (void)setKeyframeTime:(CGFloat)time forIndex:(NSUInteger)index;
- (void)setKeyframeValue:(id)value time:(CGFloat)time forIndex:(NSUInteger)index;
- (id)getKeyframeValueForIndex:(NSUInteger)index;
- (CGFloat)getKeyframeTimeForIndex:(NSUInteger)index;
- (nullable id)sampleAtTime:(CGFloat)time;
@property (nonatomic) SKInterpolationMode interpolationMode;
@property (nonatomic) SKRepeatMode repeatMode;
@end
typedef NS_ENUM(NSUInteger, SKParticleRenderOrder) {
    SKParticleRenderOrderOldestLast = 0, SKParticleRenderOrderOldestFirst, SKParticleRenderOrderDontCare
};
@interface SKEmitterNode : SKNode
- (void)advanceSimulationTime:(NSTimeInterval)sec;
- (void)resetSimulation;
@property (nonatomic, retain, nullable) SKTexture *particleTexture;
@property (nonatomic) SKBlendMode particleBlendMode;
@property (nonatomic, retain) UIColor *particleColor;
@property (nonatomic) CGFloat particleColorRedRange, particleColorGreenRange, particleColorBlueRange, particleColorAlphaRange;
@property (nonatomic) CGFloat particleColorRedSpeed, particleColorGreenSpeed, particleColorBlueSpeed, particleColorAlphaSpeed;
@property (nonatomic, retain, nullable) SKKeyframeSequence *particleColorSequence;
@property (nonatomic) CGFloat particleColorBlendFactor, particleColorBlendFactorRange, particleColorBlendFactorSpeed;
@property (nonatomic, retain, nullable) SKKeyframeSequence *particleColorBlendFactorSequence;
@property (nonatomic) CGPoint particlePosition;
@property (nonatomic) CGVector particlePositionRange;
@property (nonatomic) CGFloat particleSpeed, particleSpeedRange, emissionAngle, emissionAngleRange, xAcceleration, yAcceleration;
@property (nonatomic) CGFloat particleBirthRate;
@property (nonatomic) NSUInteger numParticlesToEmit;
@property (nonatomic) CGFloat particleLifetime, particleLifetimeRange;
@property (nonatomic) CGFloat particleRotation, particleRotationRange, particleRotationSpeed;
@property (nonatomic) CGSize particleSize;
@property (nonatomic) CGFloat particleScale, particleScaleRange, particleScaleSpeed;
@property (nonatomic, retain, nullable) SKKeyframeSequence *particleScaleSequence;
@property (nonatomic) CGFloat particleAlpha, particleAlphaRange, particleAlphaSpeed;
@property (nonatomic, retain, nullable) SKKeyframeSequence *particleAlphaSequence;
@property (nonatomic, copy, nullable) SKAction *particleAction;
@property (nonatomic) uint32_t fieldBitMask;
@property (nonatomic, weak, nullable) SKNode *targetNode;
@property (nonatomic, retain, nullable) SKShader *shader;
@property (nonatomic) CGFloat particleZPosition, particleZPositionRange, particleZPositionSpeed;
@property (nonatomic) SKParticleRenderOrder particleRenderOrder;
@end
NS_ASSUME_NONNULL_END
#endif
