#pragma once
/* isim SpriteKit: custom fragment shaders (isim: the source is kept; SpriteKit draws without it), uniforms and attributes. */
#import <SpriteKit/SKTexture.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SKUniformType) {
    SKUniformTypeNone, SKUniformTypeFloat, SKUniformTypeFloatVector2, SKUniformTypeFloatVector3, SKUniformTypeFloatVector4,
    SKUniformTypeFloatMatrix2, SKUniformTypeFloatMatrix3, SKUniformTypeFloatMatrix4, SKUniformTypeTexture
};
@interface SKUniform : NSObject
+ (instancetype)uniformWithName:(NSString *)name;
+ (instancetype)uniformWithName:(NSString *)name texture:(nullable SKTexture *)texture;
+ (instancetype)uniformWithName:(NSString *)name float:(float)value;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name texture:(nullable SKTexture *)texture;
- (instancetype)initWithName:(NSString *)name float:(float)value;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SKUniformType uniformType;
@property (nonatomic, strong, nullable) SKTexture *textureValue;
@property (nonatomic) float floatValue;
@end
typedef NS_ENUM(NSInteger, SKAttributeType) {
    SKAttributeTypeNone, SKAttributeTypeFloat, SKAttributeTypeVectorFloat2, SKAttributeTypeVectorFloat3, SKAttributeTypeVectorFloat4,
    SKAttributeTypeHalfFloat, SKAttributeTypeVectorHalfFloat2, SKAttributeTypeVectorHalfFloat3, SKAttributeTypeVectorHalfFloat4
};
@interface SKAttribute : NSObject
+ (instancetype)attributeWithName:(NSString *)name type:(SKAttributeType)type;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SKAttributeType type;
@end
@interface SKAttributeValue : NSObject
+ (instancetype)valueWithFloat:(float)value;
@property (nonatomic) float floatValue;
@end
@interface SKShader : NSObject
+ (instancetype)shader;
+ (instancetype)shaderWithSource:(NSString *)source;
+ (instancetype)shaderWithSource:(NSString *)source uniforms:(NSArray<SKUniform *> *)uniforms;
+ (instancetype)shaderWithFileNamed:(NSString *)name;
- (instancetype)initWithSource:(NSString *)source;
- (instancetype)initWithSource:(NSString *)source uniforms:(NSArray<SKUniform *> *)uniforms;
@property (nonatomic, copy, nullable) NSString *source;
@property (nonatomic, copy) NSArray<SKUniform *> *uniforms;
@property (nonatomic, copy) NSArray<SKAttribute *> *attributes;
- (void)addUniform:(SKUniform *)uniform;
- (nullable SKUniform *)uniformNamed:(NSString *)name;
- (void)removeUniformNamed:(NSString *)name;
@end
NS_ASSUME_NONNULL_END
#endif
