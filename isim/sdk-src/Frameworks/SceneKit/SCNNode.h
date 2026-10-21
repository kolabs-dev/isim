#pragma once
/* isim SceneKit: SCNNode, the scene graph's node (its transform is kept as translation, orientation and scale). */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SCNNode : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)node;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly, nullable) SCNNode *parentNode;
@property (nonatomic, readonly) NSArray<SCNNode *> *childNodes;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) CGFloat opacity;
@property (nonatomic) NSInteger renderingOrder;
@property (nonatomic) BOOL castsShadow;
@property (nonatomic) NSUInteger categoryBitMask;
@property (nonatomic, readonly) SCNNode *presentationNode;
@property (nonatomic) SCNVector3 position;
@property (nonatomic) SCNVector3 worldPosition;
@property (nonatomic) SCNVector3 scale;
@property (nonatomic) SCNVector3 eulerAngles;
@property (nonatomic) SCNQuaternion orientation;
@property (nonatomic) SCNVector4 rotation;
@property (nonatomic) SCNMatrix4 transform;
@property (nonatomic, readonly) SCNMatrix4 worldTransform;
- (void)setWorldTransform:(SCNMatrix4)worldTransform;
@property (nonatomic) simd_float3 simdPosition;
@property (nonatomic) simd_float3 simdWorldPosition;
@property (nonatomic) simd_float3 simdScale;
@property (nonatomic) simd_float3 simdEulerAngles;
@property (nonatomic) simd_float4x4 simdTransform;
@property (nonatomic) simd_float4x4 simdWorldTransform;
- (SCNVector3)convertPosition:(SCNVector3)position toNode:(nullable SCNNode *)node;
- (SCNVector3)convertPosition:(SCNVector3)position fromNode:(nullable SCNNode *)node;
- (void)addChildNode:(SCNNode *)child;
- (void)insertChildNode:(SCNNode *)child atIndex:(NSUInteger)index;
- (void)removeFromParentNode;
- (void)replaceChildNode:(SCNNode *)oldChild with:(SCNNode *)newChild;
- (nullable SCNNode *)childNodeWithName:(NSString *)name recursively:(BOOL)recursively;
- (NSArray<SCNNode *> *)childNodesPassingTest:(NS_NOESCAPE BOOL (^)(SCNNode *child, BOOL *stop))predicate;
- (void)enumerateChildNodesUsingBlock:(NS_NOESCAPE void (^)(SCNNode *child, BOOL *stop))block;
- (void)enumerateHierarchyUsingBlock:(NS_NOESCAPE void (^)(SCNNode *node, BOOL *stop))block;
- (instancetype)clone;
- (instancetype)flattenedClone;
@end
NS_ASSUME_NONNULL_END
#endif
