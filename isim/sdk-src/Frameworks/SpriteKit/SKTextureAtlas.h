#pragma once
/* isim SpriteKit: texture atlases (folders of images in the app bundle, .atlas / .spriteatlas). */
#import <SpriteKit/SKTexture.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SKTextureAtlas : NSObject
+ (instancetype)atlasNamed:(NSString *)name;
+ (instancetype)atlasWithDictionary:(NSDictionary<NSString *, id> *)properties;
- (SKTexture *)textureNamed:(NSString *)name;
@property (nonatomic, readonly) NSArray<NSString *> *textureNames;
+ (void)preloadTextureAtlases:(NSArray<SKTextureAtlas *> *)textureAtlases withCompletionHandler:(void (^)(void))completionHandler;
+ (void)preloadTextureAtlasesNamed:(NSArray<NSString *> *)atlasNames withCompletionHandler:(void (^)(NSError * _Nullable error, NSArray<SKTextureAtlas *> *foundAtlases))completionHandler;
- (void)preloadWithCompletionHandler:(void (^)(void))completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
