#pragma once
/* isim SpriteKit: physics: bodies, the world, contacts and joints (isim's own 2D rigid-body solver). */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKPhysicsContact, SKPhysicsJoint;
@interface SKPhysicsBody : NSObject
+ (SKPhysicsBody *)bodyWithCircleOfRadius:(CGFloat)r;
+ (SKPhysicsBody *)bodyWithCircleOfRadius:(CGFloat)r center:(CGPoint)center;
+ (SKPhysicsBody *)bodyWithRectangleOfSize:(CGSize)s;
+ (SKPhysicsBody *)bodyWithRectangleOfSize:(CGSize)s center:(CGPoint)center;
+ (SKPhysicsBody *)bodyWithPolygonFromPath:(CGPathRef)path;
+ (SKPhysicsBody *)bodyWithEdgeFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2;
+ (SKPhysicsBody *)bodyWithEdgeChainFromPath:(CGPathRef)path;
+ (SKPhysicsBody *)bodyWithEdgeLoopFromPath:(CGPathRef)path;
+ (SKPhysicsBody *)bodyWithEdgeLoopFromRect:(CGRect)rect;
+ (SKPhysicsBody *)bodyWithTexture:(SKTexture *)texture size:(CGSize)size;
+ (SKPhysicsBody *)bodyWithTexture:(SKTexture *)texture alphaThreshold:(float)alphaThreshold size:(CGSize)size;
+ (SKPhysicsBody *)bodyWithBodies:(NSArray<SKPhysicsBody *> *)bodies;
@property (nonatomic, getter=isDynamic) BOOL dynamic;
@property (nonatomic) BOOL usesPreciseCollisionDetection;
@property (nonatomic) BOOL allowsRotation;
@property (nonatomic) BOOL pinned;
@property (nonatomic, getter=isResting) BOOL resting;
@property (nonatomic) CGFloat friction;
@property (nonatomic) CGFloat charge;
@property (nonatomic) CGFloat restitution;
@property (nonatomic, assign) CGFloat linearDamping;
@property (nonatomic, assign) CGFloat angularDamping;
@property (nonatomic) CGFloat density;
@property (nonatomic) CGFloat mass;
@property (nonatomic, readonly) CGFloat area;
@property (nonatomic, assign) BOOL affectedByGravity;
@property (nonatomic, assign) uint32_t fieldBitMask;
@property (nonatomic, assign) uint32_t categoryBitMask;
@property (nonatomic, assign) uint32_t collisionBitMask;
@property (nonatomic, assign) uint32_t contactTestBitMask;
@property (nonatomic, readonly) NSArray<SKPhysicsJoint *> *joints;
@property (nonatomic, weak, readonly, nullable) SKNode *node;
@property (nonatomic) CGVector velocity;
@property (nonatomic) CGFloat angularVelocity;
- (void)applyForce:(CGVector)force;
- (void)applyForce:(CGVector)force atPoint:(CGPoint)point;
- (void)applyTorque:(CGFloat)torque;
- (void)applyImpulse:(CGVector)impulse;
- (void)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point;
- (void)applyAngularImpulse:(CGFloat)impulse;
- (NSArray<SKPhysicsBody *> *)allContactedBodies;
@end
@interface SKPhysicsContact : NSObject
@property (nonatomic, readonly) SKPhysicsBody *bodyA;
@property (nonatomic, readonly) SKPhysicsBody *bodyB;
@property (nonatomic, readonly) CGPoint contactPoint;
@property (nonatomic, readonly) CGVector contactNormal;
@property (nonatomic, readonly) CGFloat collisionImpulse;
@end
@protocol SKPhysicsContactDelegate <NSObject>
@optional
- (void)didBeginContact:(SKPhysicsContact *)contact;
- (void)didEndContact:(SKPhysicsContact *)contact;
@end
@interface SKPhysicsWorld : NSObject
@property (nonatomic) CGVector gravity;
@property (nonatomic) CGFloat speed;
@property (nonatomic, assign, nullable) id<SKPhysicsContactDelegate> contactDelegate;
- (void)addJoint:(SKPhysicsJoint *)joint;
- (void)removeJoint:(SKPhysicsJoint *)joint;
- (void)removeAllJoints;
- (nullable SKPhysicsBody *)bodyAtPoint:(CGPoint)point;
- (nullable SKPhysicsBody *)bodyInRect:(CGRect)rect;
- (nullable SKPhysicsBody *)bodyAlongRayStart:(CGPoint)start end:(CGPoint)end;
- (void)enumerateBodiesAtPoint:(CGPoint)point usingBlock:(void (NS_NOESCAPE ^)(SKPhysicsBody *body, BOOL *stop))block;
- (void)enumerateBodiesInRect:(CGRect)rect usingBlock:(void (NS_NOESCAPE ^)(SKPhysicsBody *body, BOOL *stop))block;
- (void)enumerateBodiesAlongRayStart:(CGPoint)start end:(CGPoint)end
                          usingBlock:(void (NS_NOESCAPE ^)(SKPhysicsBody *body, CGPoint point, CGVector normal, BOOL *stop))block;
@end
@interface SKPhysicsJoint : NSObject
@property (nonatomic, retain) SKPhysicsBody *bodyA;
@property (nonatomic, retain) SKPhysicsBody *bodyB;
@property (nonatomic, readonly) CGVector reactionForce;
@property (nonatomic, readonly) CGFloat reactionTorque;
@end
@interface SKPhysicsJointPin : SKPhysicsJoint
+ (SKPhysicsJointPin *)jointWithBodyA:(SKPhysicsBody *)bodyA bodyB:(SKPhysicsBody *)bodyB anchor:(CGPoint)anchor;
@property (nonatomic) BOOL shouldEnableLimits;
@property (nonatomic) CGFloat lowerAngleLimit;
@property (nonatomic) CGFloat upperAngleLimit;
@property (nonatomic) CGFloat frictionTorque;
@property (nonatomic) CGFloat rotationSpeed;
@end
@interface SKPhysicsJointSpring : SKPhysicsJoint
+ (SKPhysicsJointSpring *)jointWithBodyA:(SKPhysicsBody *)bodyA bodyB:(SKPhysicsBody *)bodyB anchorA:(CGPoint)anchorA anchorB:(CGPoint)anchorB;
@property (nonatomic) CGFloat damping;
@property (nonatomic) CGFloat frequency;
@end
@interface SKPhysicsJointFixed : SKPhysicsJoint
+ (SKPhysicsJointFixed *)jointWithBodyA:(SKPhysicsBody *)bodyA bodyB:(SKPhysicsBody *)bodyB anchor:(CGPoint)anchor;
@end
@interface SKPhysicsJointSliding : SKPhysicsJoint
+ (SKPhysicsJointSliding *)jointWithBodyA:(SKPhysicsBody *)bodyA bodyB:(SKPhysicsBody *)bodyB anchor:(CGPoint)anchor axis:(CGVector)axis;
@property (nonatomic) BOOL shouldEnableLimits;
@property (nonatomic) CGFloat lowerDistanceLimit;
@property (nonatomic) CGFloat upperDistanceLimit;
@end
@interface SKPhysicsJointLimit : SKPhysicsJoint
@property (nonatomic) CGFloat maxLength;
+ (SKPhysicsJointLimit *)jointWithBodyA:(SKPhysicsBody *)bodyA bodyB:(SKPhysicsBody *)bodyB anchorA:(CGPoint)anchorA anchorB:(CGPoint)anchorB;
@end
NS_ASSUME_NONNULL_END
#endif
