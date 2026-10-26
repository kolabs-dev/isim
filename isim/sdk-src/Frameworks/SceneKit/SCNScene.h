#pragma once
/* isim SceneKit: SCNScene (issue #330): a root node, a background, fog and a physics world. Scene files: Wavefront
 * .obj (with .mtl) and the .scn archives isim writes. */
#import <SceneKit/SCNNode.h>
#import <SceneKit/SCNMaterial.h>
#import <SceneKit/SCNPhysics.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SCNScene : NSObject <NSSecureCoding>
+ (instancetype)scene;
+ (nullable instancetype)sceneNamed:(NSString *)name;
+ (nullable instancetype)sceneNamed:(NSString *)name inDirectory:(nullable NSString *)directory options:(nullable NSDictionary<NSString *, id> *)options;
+ (nullable instancetype)sceneWithURL:(NSURL *)url options:(nullable NSDictionary<NSString *, id> *)options error:(NSError **)error;
@property (nonatomic, readonly) SCNNode *rootNode;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic) CGFloat fogStartDistance;
@property (nonatomic) CGFloat fogEndDistance;
@property (nonatomic) CGFloat fogDensityExponent;
@property (nonatomic, retain) id fogColor;
@property (nonatomic, readonly) SCNMaterialProperty *background;
@property (nonatomic, readonly) SCNMaterialProperty *lightingEnvironment;
@property (nonatomic, readonly) SCNPhysicsWorld *physicsWorld;
- (nullable id)attributeForKey:(NSString *)key;
- (void)setAttribute:(nullable id)attribute forKey:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
#endif
