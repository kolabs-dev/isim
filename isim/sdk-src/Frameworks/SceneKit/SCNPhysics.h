#pragma once
/* isim SceneKit: physics (issue #330). isim's own rigid-body solver: gravity, forces, impulses, sphere and box contacts
 * with restitution and friction, masks and the contact delegate. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SCNNode, SCNGeometry, SCNPhysicsShape, SCNPhysicsContact, SCNPhysicsWorld;
typedef NS_ENUM(NSInteger, SCNPhysicsBodyType) { SCNPhysicsBodyTypeStatic = 0, SCNPhysicsBodyTypeDynamic = 1, SCNPhysicsBodyTypeKinematic = 2 };
typedef NS_OPTIONS(NSUInteger, SCNPhysicsCollisionCategory) {
    SCNPhysicsCollisionCategoryNone = 0, SCNPhysicsCollisionCategoryDefault = 1 << 0, SCNPhysicsCollisionCategoryStatic = 1 << 1,
    SCNPhysicsCollisionCategoryAll = ~0UL
};
typedef NSString *SCNPhysicsShapeOption NS_TYPED_ENUM;
SCN_EXPORT SCNPhysicsShapeOption const SCNPhysicsShapeTypeKey;
SCN_EXPORT SCNPhysicsShapeOption const SCNPhysicsShapeKeepAsCompoundKey;
SCN_EXPORT SCNPhysicsShapeOption const SCNPhysicsShapeScaleKey;
SCN_EXPORT SCNPhysicsShapeOption const SCNPhysicsShapeCollisionMarginKey;
typedef NSString *SCNPhysicsShapeType NS_TYPED_ENUM;
SCN_EXPORT SCNPhysicsShapeType const SCNPhysicsShapeTypeBoundingBox;
SCN_EXPORT SCNPhysicsShapeType const SCNPhysicsShapeTypeConvexHull;
SCN_EXPORT SCNPhysicsShapeType const SCNPhysicsShapeTypeConcavePolyhedron;

@interface SCNPhysicsShape : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)shapeWithGeometry:(SCNGeometry *)geometry options:(nullable NSDictionary<SCNPhysicsShapeOption, id> *)options;
+ (instancetype)shapeWithNode:(SCNNode *)node options:(nullable NSDictionary<SCNPhysicsShapeOption, id> *)options;
@property (nonatomic, readonly) id sourceObject;
@end

@interface SCNPhysicsBody : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)staticBody;
+ (instancetype)dynamicBody;
+ (instancetype)kinematicBody;
+ (instancetype)bodyWithType:(SCNPhysicsBodyType)type shape:(nullable SCNPhysicsShape *)shape;
@property (nonatomic) SCNPhysicsBodyType type;
@property (nonatomic, retain, nullable) SCNPhysicsShape *physicsShape;
@property (nonatomic) CGFloat mass, charge, friction, rollingFriction, restitution, damping, angularDamping;
@property (nonatomic, getter=isAffectedByGravity) BOOL affectedByGravity;
@property (nonatomic) BOOL allowsResting;
@property (nonatomic, readonly) BOOL isResting;
@property (nonatomic) NSUInteger categoryBitMask, collisionBitMask, contactTestBitMask;
@property (nonatomic) SCNVector3 velocity;
@property (nonatomic) SCNVector4 angularVelocity;
@property (nonatomic) SCNVector3 velocityFactor;
- (void)applyForce:(SCNVector3)direction impulse:(BOOL)impulse;
- (void)applyForce:(SCNVector3)direction atPosition:(SCNVector3)position impulse:(BOOL)impulse;
- (void)applyTorque:(SCNVector4)torque impulse:(BOOL)impulse;
- (void)clearAllForces;
- (void)resetTransform;
@end

@interface SCNPhysicsContact : NSObject
@property (nonatomic, readonly) SCNNode *nodeA, *nodeB;
@property (nonatomic, readonly) SCNVector3 contactPoint, contactNormal;
@property (nonatomic, readonly) CGFloat collisionImpulse, penetrationDistance, sweepTestFraction;
@end

@protocol SCNPhysicsContactDelegate <NSObject>
@optional
- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact;
- (void)physicsWorld:(SCNPhysicsWorld *)world didUpdateContact:(SCNPhysicsContact *)contact;
- (void)physicsWorld:(SCNPhysicsWorld *)world didEndContact:(SCNPhysicsContact *)contact;
@end

@interface SCNPhysicsWorld : NSObject <NSSecureCoding>
@property (nonatomic) SCNVector3 gravity;
@property (nonatomic) CGFloat speed;
@property (nonatomic) NSTimeInterval timeStep;
@property (nonatomic, weak, nullable) id<SCNPhysicsContactDelegate> contactDelegate;
- (void)updateCollisionPairs;
@end
NS_ASSUME_NONNULL_END
#endif
