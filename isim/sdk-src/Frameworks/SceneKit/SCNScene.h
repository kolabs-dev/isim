#pragma once
/* isim SceneKit: SCNScene (scene files do not load yet: the 3D renderer is #330). */
#import <SceneKit/SCNNode.h>
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
- (nullable id)attributeForKey:(NSString *)key;
- (void)setAttribute:(nullable id)attribute forKey:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
#endif
