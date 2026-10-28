#pragma once
/* isim SpriteKit: actions: moves, rotations, scales, fades, colors, textures, sequences and groups, sounds, physics, custom blocks. */
#import <SpriteKit/SKTexture.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKNode, SKWarpGeometry;
typedef NS_ENUM(NSInteger, SKActionTimingMode) {
    SKActionTimingLinear = 0, SKActionTimingEaseIn, SKActionTimingEaseOut, SKActionTimingEaseInEaseOut
};
typedef float (^SKActionTimingFunction)(float time);
@interface SKAction : NSObject
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) SKActionTimingMode timingMode;
@property (nonatomic, copy, nullable) SKActionTimingFunction timingFunction;
@property (nonatomic) CGFloat speed;
- (SKAction *)reversedAction;
+ (nullable SKAction *)actionNamed:(NSString *)name;
+ (nullable SKAction *)actionNamed:(NSString *)name duration:(NSTimeInterval)duration;
+ (nullable SKAction *)actionNamed:(NSString *)name fromURL:(NSURL *)url;
+ (nullable SKAction *)actionNamed:(NSString *)name fromURL:(NSURL *)url duration:(NSTimeInterval)duration;
+ (SKAction *)moveBy:(CGVector)delta duration:(NSTimeInterval)duration;
+ (SKAction *)moveByX:(CGFloat)deltaX y:(CGFloat)deltaY duration:(NSTimeInterval)duration;
+ (SKAction *)moveTo:(CGPoint)location duration:(NSTimeInterval)duration;
+ (SKAction *)moveToX:(CGFloat)x duration:(NSTimeInterval)duration;
+ (SKAction *)moveToY:(CGFloat)y duration:(NSTimeInterval)duration;
+ (SKAction *)rotateByAngle:(CGFloat)radians duration:(NSTimeInterval)duration;
+ (SKAction *)rotateToAngle:(CGFloat)radians duration:(NSTimeInterval)duration;
+ (SKAction *)rotateToAngle:(CGFloat)radians duration:(NSTimeInterval)duration shortestUnitArc:(BOOL)shortestUnitArc;
+ (SKAction *)resizeByWidth:(CGFloat)width height:(CGFloat)height duration:(NSTimeInterval)duration;
+ (SKAction *)resizeToWidth:(CGFloat)width height:(CGFloat)height duration:(NSTimeInterval)duration;
+ (SKAction *)scaleBy:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleXBy:(CGFloat)xScale y:(CGFloat)yScale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleTo:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleToSize:(CGSize)size duration:(NSTimeInterval)duration;
+ (SKAction *)scaleXTo:(CGFloat)xScale y:(CGFloat)yScale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleXTo:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleYTo:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)sequence:(NSArray<SKAction *> *)actions;
+ (SKAction *)group:(NSArray<SKAction *> *)actions;
+ (SKAction *)repeatAction:(SKAction *)action count:(NSUInteger)count;
+ (SKAction *)repeatActionForever:(SKAction *)action;
+ (SKAction *)fadeInWithDuration:(NSTimeInterval)duration;
+ (SKAction *)fadeOutWithDuration:(NSTimeInterval)duration;
+ (SKAction *)fadeAlphaBy:(CGFloat)factor duration:(NSTimeInterval)duration;
+ (SKAction *)fadeAlphaTo:(CGFloat)alpha duration:(NSTimeInterval)duration;
+ (SKAction *)hide;
+ (SKAction *)unhide;
+ (SKAction *)setTexture:(SKTexture *)texture;
+ (SKAction *)setTexture:(SKTexture *)texture resize:(BOOL)resize;
+ (SKAction *)setNormalTexture:(SKTexture *)texture;
+ (SKAction *)setNormalTexture:(SKTexture *)texture resize:(BOOL)resize;
+ (SKAction *)animateWithTextures:(NSArray<SKTexture *> *)textures timePerFrame:(NSTimeInterval)sec;
+ (SKAction *)animateWithTextures:(NSArray<SKTexture *> *)textures timePerFrame:(NSTimeInterval)sec resize:(BOOL)resize restore:(BOOL)restore;
+ (SKAction *)playSoundFileNamed:(NSString *)soundFile waitForCompletion:(BOOL)wait;
+ (SKAction *)colorizeWithColor:(UIColor *)color colorBlendFactor:(CGFloat)colorBlendFactor duration:(NSTimeInterval)duration;
+ (SKAction *)colorizeWithColorBlendFactor:(CGFloat)colorBlendFactor duration:(NSTimeInterval)duration;
+ (SKAction *)followPath:(CGPathRef)path duration:(NSTimeInterval)duration;
+ (SKAction *)followPath:(CGPathRef)path asOffset:(BOOL)offset orientToPath:(BOOL)orient duration:(NSTimeInterval)duration;
+ (SKAction *)followPath:(CGPathRef)path speed:(CGFloat)speed;
+ (SKAction *)followPath:(CGPathRef)path asOffset:(BOOL)offset orientToPath:(BOOL)orient speed:(CGFloat)speed;
+ (SKAction *)speedBy:(CGFloat)speed duration:(NSTimeInterval)duration;
+ (SKAction *)speedTo:(CGFloat)speed duration:(NSTimeInterval)duration;
+ (SKAction *)reachTo:(CGPoint)position rootNode:(SKNode *)root duration:(NSTimeInterval)duration;
+ (SKAction *)reachTo:(CGPoint)position rootNode:(SKNode *)root velocity:(CGFloat)velocity;
+ (SKAction *)reachToNode:(SKNode *)node rootNode:(SKNode *)root duration:(NSTimeInterval)sec;
+ (SKAction *)reachToNode:(SKNode *)node rootNode:(SKNode *)root velocity:(CGFloat)velocity;
+ (SKAction *)strengthTo:(float)strength duration:(NSTimeInterval)duration;
+ (SKAction *)strengthBy:(float)strength duration:(NSTimeInterval)duration;
+ (SKAction *)falloffTo:(float)falloff duration:(NSTimeInterval)duration;
+ (SKAction *)falloffBy:(float)falloff duration:(NSTimeInterval)duration;
+ (SKAction *)waitForDuration:(NSTimeInterval)duration;
+ (SKAction *)waitForDuration:(NSTimeInterval)duration withRange:(NSTimeInterval)durationRange;
+ (SKAction *)removeFromParent;
+ (SKAction *)runAction:(SKAction *)action onChildWithName:(NSString *)name;
+ (SKAction *)runBlock:(dispatch_block_t)block;
+ (SKAction *)customActionWithDuration:(NSTimeInterval)duration actionBlock:(void (^)(SKNode *node, CGFloat elapsedTime))block;
+ (SKAction *)play;
+ (SKAction *)pause;
+ (SKAction *)stop;
+ (SKAction *)changePlaybackRateTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changePlaybackRateBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeVolumeTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeVolumeBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)stereoPanTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)stereoPanBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeReverbTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeReverbBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeObstructionTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeObstructionBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeOcclusionTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeOcclusionBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeChargeTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeChargeBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeMassTo:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)changeMassBy:(float)v duration:(NSTimeInterval)duration;
+ (SKAction *)applyForce:(CGVector)force duration:(NSTimeInterval)duration;
+ (SKAction *)applyForce:(CGVector)force atPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (SKAction *)applyTorque:(CGFloat)torque duration:(NSTimeInterval)duration;
+ (SKAction *)applyImpulse:(CGVector)impulse duration:(NSTimeInterval)duration;
+ (SKAction *)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (SKAction *)applyAngularImpulse:(CGFloat)impulse duration:(NSTimeInterval)duration;
+ (nullable SKAction *)warpTo:(SKWarpGeometry *)warp duration:(NSTimeInterval)duration;
+ (nullable SKAction *)animateWithWarps:(NSArray<SKWarpGeometry *> *)warps times:(NSArray<NSNumber *> *)times;
+ (nullable SKAction *)animateWithWarps:(NSArray<SKWarpGeometry *> *)warps times:(NSArray<NSNumber *> *)times restore:(BOOL)restore;
@end
NS_ASSUME_NONNULL_END
#endif
