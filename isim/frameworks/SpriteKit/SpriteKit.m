// isim SpriteKit for Objective-C: Apple's class factories (instancetype, so an Objective-C subclass gets its own class:
// [MyScene sceneWithSize:], [Hero spriteNodeWithImageNamed:]) over the overlay's initializers, and Apple's setters where
// the overlay's Bool properties are named isX (Swift's Objective-C setter is setIsX:).
#import <SpriteKit/SpriteKit.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes

@interface NSObject (ISIMSpriteKit)
- (void)setIsHidden:(BOOL)v;
- (void)setIsPaused:(BOOL)v;
- (void)setIsUserInteractionEnabled:(BOOL)v;
- (void)setIsAsynchronous:(BOOL)v;
- (void)setIsAntialiased:(BOOL)v;
- (void)setIsDynamic:(BOOL)v;
- (void)setIsResting:(BOOL)v;
- (void)setIsEnabled:(BOOL)v;
- (void)setIsExclusive:(BOOL)v;
- (void)setIsPositional:(BOOL)v;
- (id)initWithFileNamed:(NSString *)name;
- (id)initWithText:(NSString *)text;
- (id)initWithAttributedText:(NSAttributedString *)text;
- (id)initWithTexture:(SKTexture *)texture size:(CGSize)size;
- (id)initWithImageNamed:(NSString *)name normalMapped:(BOOL)normalMapped;
- (id)initWithPath:(CGPathRef)path;
- (id)initWithPath:(CGPathRef)path centered:(BOOL)centered;
- (id)initWithRect:(CGRect)rect;
- (id)initWithRect:(CGRect)rect cornerRadius:(CGFloat)r;
- (id)initWithRectOfSize:(CGSize)size;
- (id)initWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)r;
- (id)initWithCircleOfRadius:(CGFloat)r;
- (id)initWithEllipseInRect:(CGRect)rect;
- (id)initWithEllipseOfSize:(CGSize)size;
- (id)initWithPoints:(CGPoint *)points count:(NSInteger)count;
- (id)initWithSplinePoints:(CGPoint *)points count:(NSInteger)count;
- (id)initWithLowerLimit:(CGFloat)lower;
- (id)initWithUpperLimit:(CGFloat)upper;
- (id)initWithConstantValue:(CGFloat)v;
- (id)initWithValue:(CGFloat)v variance:(CGFloat)variance;
- (id)initWithFloat:(float)v;
- (id)initWithNamed:(NSString *)name;
@end

@implementation SKNode (ISIMSpriteKit)
+ (instancetype)node { return [[self alloc] init]; }
+ (instancetype)nodeWithFileNamed:(NSString *)filename { return [[self alloc] initWithFileNamed:filename]; }
- (void)setHidden:(BOOL)v { [self setIsHidden:v]; }
- (void)setPaused:(BOOL)v { [self setIsPaused:v]; }
- (void)setUserInteractionEnabled:(BOOL)v { [self setIsUserInteractionEnabled:v]; }
@end
@implementation SKSpriteNode (ISIMSpriteKit)
+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture size:(CGSize)size { return [[self alloc] initWithTexture:texture size:size]; }
+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture { return [[self alloc] initWithTexture:texture]; }
+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture normalMap:(SKTexture *)normalMap {
    SKSpriteNode *s = [[self alloc] initWithTexture:texture];
    s.normalTexture = normalMap;
    return s;
}
+ (instancetype)spriteNodeWithImageNamed:(NSString *)name { return [[self alloc] initWithImageNamed:name]; }
+ (instancetype)spriteNodeWithImageNamed:(NSString *)name normalMapped:(BOOL)normalMapped { return [[self alloc] initWithImageNamed:name normalMapped:normalMapped]; }
+ (instancetype)spriteNodeWithColor:(UIColor *)color size:(CGSize)size { return [[self alloc] initWithColor:color size:size]; }
@end
@implementation SKLabelNode (ISIMSpriteKit)
+ (instancetype)labelNodeWithText:(NSString *)text { return [[self alloc] initWithText:text]; }
+ (instancetype)labelNodeWithAttributedText:(NSAttributedString *)text { return [[self alloc] initWithAttributedText:text]; }
+ (instancetype)labelNodeWithFontNamed:(NSString *)fontName { return [[self alloc] initWithFontNamed:fontName]; }
@end
@implementation SKShapeNode (ISIMSpriteKit)
+ (instancetype)shapeNodeWithPath:(CGPathRef)path { return [[self alloc] initWithPath:path]; }
+ (instancetype)shapeNodeWithPath:(CGPathRef)path centered:(BOOL)centered { return [[self alloc] initWithPath:path centered:centered]; }
+ (instancetype)shapeNodeWithRect:(CGRect)rect { return [[self alloc] initWithRect:rect]; }
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size { return [[self alloc] initWithRectOfSize:size]; }
+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)r { return [[self alloc] initWithRect:rect cornerRadius:r]; }
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)r { return [[self alloc] initWithRectOfSize:size cornerRadius:r]; }
+ (instancetype)shapeNodeWithCircleOfRadius:(CGFloat)r { return [[self alloc] initWithCircleOfRadius:r]; }
+ (instancetype)shapeNodeWithEllipseInRect:(CGRect)rect { return [[self alloc] initWithEllipseInRect:rect]; }
+ (instancetype)shapeNodeWithEllipseOfSize:(CGSize)size { return [[self alloc] initWithEllipseOfSize:size]; }
+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)n { return [[self alloc] initWithPoints:points count:(NSInteger)n]; }
+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)n { return [[self alloc] initWithSplinePoints:points count:(NSInteger)n]; }
- (void)setAntialiased:(BOOL)v { [self setIsAntialiased:v]; }
@end
@implementation SKScene (ISIMSpriteKit)
+ (instancetype)sceneWithSize:(CGSize)size { return [[self alloc] initWithSize:size]; }
@end
@implementation SKView (ISIMSpriteKit)
- (void)setPaused:(BOOL)v { [self setIsPaused:v]; }
- (void)setAsynchronous:(BOOL)v { [self setIsAsynchronous:v]; }
@end
@implementation SKPhysicsBody (ISIMSpriteKit)
- (void)setDynamic:(BOOL)v { [self setIsDynamic:v]; }
- (void)setResting:(BOOL)v { [self setIsResting:v]; }
@end
@implementation SKFieldNode (ISIMSpriteKit)
- (void)setEnabled:(BOOL)v { [self setIsEnabled:v]; }
- (void)setExclusive:(BOOL)v { [self setIsExclusive:v]; }
@end
@implementation SKLightNode (ISIMSpriteKit)
- (void)setEnabled:(BOOL)v { [self setIsEnabled:v]; }
@end
@implementation SKAudioNode (ISIMSpriteKit)
- (void)setPositional:(BOOL)v { [self setIsPositional:v]; }
@end
@implementation SKVideoNode (ISIMSpriteKit)
+ (SKVideoNode *)videoNodeWithAVPlayer:(AVPlayer *)player { return [[self alloc] initWithAVPlayer:player]; }
+ (SKVideoNode *)videoNodeWithFileNamed:(NSString *)file { return [[self alloc] initWithFileNamed:file]; }
+ (SKVideoNode *)videoNodeWithURL:(NSURL *)url { return [[self alloc] initWithURL:url]; }
@end
@implementation SKReferenceNode (ISIMSpriteKit)
+ (instancetype)referenceNodeWithFileNamed:(NSString *)fileName { return [[self alloc] initWithFileNamed:fileName]; }
+ (instancetype)referenceNodeWithURL:(NSURL *)url { return [[self alloc] initWithURL:url]; }
@end
@implementation SKRange (ISIMSpriteKit)
+ (instancetype)rangeWithLowerLimit:(CGFloat)lower upperLimit:(CGFloat)upper { return [[self alloc] initWithLowerLimit:lower upperLimit:upper]; }
+ (instancetype)rangeWithLowerLimit:(CGFloat)lower { return [[self alloc] initWithLowerLimit:lower]; }
+ (instancetype)rangeWithUpperLimit:(CGFloat)upper { return [[self alloc] initWithUpperLimit:upper]; }
+ (instancetype)rangeWithConstantValue:(CGFloat)v { return [[self alloc] initWithConstantValue:v]; }
+ (instancetype)rangeWithValue:(CGFloat)v variance:(CGFloat)variance { return [[self alloc] initWithValue:v variance:variance]; }
@end
@implementation SKUniform (ISIMSpriteKit)
+ (instancetype)uniformWithName:(NSString *)name { return [[self alloc] initWithName:name]; }
+ (instancetype)uniformWithName:(NSString *)name texture:(SKTexture *)texture { return [[self alloc] initWithName:name texture:texture]; }
+ (instancetype)uniformWithName:(NSString *)name float:(float)value { return [[self alloc] initWithName:name float:value]; }
@end
@implementation SKAttributeValue (ISIMSpriteKit)
+ (instancetype)valueWithFloat:(float)value { return [[self alloc] initWithFloat:value]; }
@end
@implementation SKShader (ISIMSpriteKit)
+ (instancetype)shader { return [[self alloc] init]; }
+ (instancetype)shaderWithSource:(NSString *)source { return [[self alloc] initWithSource:source]; }
+ (instancetype)shaderWithSource:(NSString *)source uniforms:(NSArray<SKUniform *> *)uniforms { return [[self alloc] initWithSource:source uniforms:uniforms]; }
+ (instancetype)shaderWithFileNamed:(NSString *)name { return [[self alloc] initWithFileNamed:name]; }
@end
@implementation SKTileDefinition (ISIMSpriteKit)
+ (instancetype)tileDefinitionWithTexture:(SKTexture *)texture { return [[self alloc] initWithTexture:texture]; }
+ (instancetype)tileDefinitionWithTexture:(SKTexture *)texture size:(CGSize)size { return [[self alloc] initWithTexture:texture size:size]; }
+ (instancetype)tileDefinitionWithTexture:(SKTexture *)texture normalTexture:(SKTexture *)normal size:(CGSize)size {
    return [[self alloc] initWithTexture:texture normalTexture:normal size:size];
}
+ (instancetype)tileDefinitionWithTextures:(NSArray<SKTexture *> *)textures size:(CGSize)size timePerFrame:(CGFloat)t {
    return [[self alloc] initWithTextures:textures size:size timePerFrame:t];
}
+ (instancetype)tileDefinitionWithTextures:(NSArray<SKTexture *> *)textures normalTextures:(NSArray<SKTexture *> *)normals size:(CGSize)size timePerFrame:(CGFloat)t {
    return [[self alloc] initWithTextures:textures normalTextures:normals size:size timePerFrame:t];
}
@end
@implementation SKTileGroup (ISIMSpriteKit)
+ (instancetype)tileGroupWithTileDefinition:(SKTileDefinition *)d { return [[self alloc] initWithTileDefinition:d]; }
+ (instancetype)tileGroupWithRules:(NSArray<SKTileGroupRule *> *)rules { return [[self alloc] initWithRules:rules]; }
@end
@implementation SKTileSet (ISIMSpriteKit)
+ (instancetype)tileSetWithTileGroups:(NSArray<SKTileGroup *> *)groups { return [[self alloc] initWithTileGroups:groups]; }
+ (instancetype)tileSetNamed:(NSString *)name { return [[self alloc] initWithNamed:name]; }
@end
@implementation SKTileMapNode (ISIMSpriteKit)
+ (instancetype)tileMapNodeWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)c rows:(NSUInteger)r tileSize:(CGSize)size {
    return [[self alloc] initWithTileSet:tileSet columns:c rows:r tileSize:size];
}
+ (instancetype)tileMapNodeWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)c rows:(NSUInteger)r tileSize:(CGSize)size fillWithTileGroup:(SKTileGroup *)g {
    return [[self alloc] initWithTileSet:tileSet columns:c rows:r tileSize:size fillWithTileGroup:g];
}
+ (instancetype)tileMapNodeWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)c rows:(NSUInteger)r tileSize:(CGSize)size tileGroupLayout:(NSArray<SKTileGroup *> *)layout {
    return [[self alloc] initWithTileSet:tileSet columns:c rows:r tileSize:size tileGroupLayout:layout];
}
@end
