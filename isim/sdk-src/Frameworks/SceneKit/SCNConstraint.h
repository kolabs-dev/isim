#pragma once
/* isim SceneKit: constraints (issue #330), applied to nodes' transforms each frame before drawing. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SCNNode;
typedef NS_OPTIONS(NSUInteger, SCNBillboardAxis) {
    SCNBillboardAxisX = 1 << 0, SCNBillboardAxisY = 1 << 1, SCNBillboardAxisZ = 1 << 2, SCNBillboardAxisAll = 7
};
@interface SCNConstraint : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) CGFloat influenceFactor;
@property (nonatomic, getter=isIncremental) BOOL incremental;
@end
@interface SCNLookAtConstraint : SCNConstraint
+ (instancetype)lookAtConstraintWithTarget:(nullable SCNNode *)target;
@property (nonatomic, retain, nullable) SCNNode *target;
@property (nonatomic, getter=isGimbalLockEnabled) BOOL gimbalLockEnabled;
@end
@interface SCNBillboardConstraint : SCNConstraint
+ (instancetype)billboardConstraint;
@property (nonatomic) SCNBillboardAxis freeAxes;
@end
@interface SCNDistanceConstraint : SCNConstraint
+ (instancetype)distanceConstraintWithTarget:(nullable SCNNode *)target;
@property (nonatomic, retain, nullable) SCNNode *target;
@property (nonatomic) CGFloat minimumDistance, maximumDistance;
@end
@interface SCNReplicatorConstraint : SCNConstraint
+ (instancetype)replicatorConstraintWithTarget:(nullable SCNNode *)target;
@property (nonatomic, retain, nullable) SCNNode *target;
@property (nonatomic) BOOL replicatesOrientation, replicatesPosition, replicatesScale;
@end
NS_ASSUME_NONNULL_END
#endif
