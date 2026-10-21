#pragma once
/* isim SpriteKit: tile maps, tile sets, groups, rules and definitions (with automapping). */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, SKTileDefinitionRotation) {
    SKTileDefinitionRotation0 = 0, SKTileDefinitionRotation90, SKTileDefinitionRotation180, SKTileDefinitionRotation270
};
@interface SKTileDefinition : NSObject
+ (instancetype)tileDefinitionWithTexture:(SKTexture *)texture;
+ (instancetype)tileDefinitionWithTexture:(SKTexture *)texture size:(CGSize)size;
+ (instancetype)tileDefinitionWithTexture:(SKTexture *)texture normalTexture:(SKTexture *)normalTexture size:(CGSize)size;
+ (instancetype)tileDefinitionWithTextures:(NSArray<SKTexture *> *)textures size:(CGSize)size timePerFrame:(CGFloat)timePerFrame;
+ (instancetype)tileDefinitionWithTextures:(NSArray<SKTexture *> *)textures normalTextures:(NSArray<SKTexture *> *)normalTextures size:(CGSize)size timePerFrame:(CGFloat)timePerFrame;
- (instancetype)initWithTexture:(SKTexture *)texture;
- (instancetype)initWithTexture:(SKTexture *)texture size:(CGSize)size;
- (instancetype)initWithTexture:(SKTexture *)texture normalTexture:(SKTexture *)normalTexture size:(CGSize)size;
- (instancetype)initWithTextures:(NSArray<SKTexture *> *)textures size:(CGSize)size timePerFrame:(CGFloat)timePerFrame;
- (instancetype)initWithTextures:(NSArray<SKTexture *> *)textures normalTextures:(NSArray<SKTexture *> *)normalTextures size:(CGSize)size timePerFrame:(CGFloat)timePerFrame;
@property (nonatomic, copy) NSArray<SKTexture *> *textures;
@property (nonatomic, copy) NSArray<SKTexture *> *normalTextures;
@property (nonatomic, retain, nullable) NSMutableDictionary *userData;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic) CGSize size;
@property (nonatomic) CGFloat timePerFrame;
@property (nonatomic) NSInteger placementWeight;
@property (nonatomic) SKTileDefinitionRotation rotation;
@property (nonatomic) BOOL flipVertically;
@property (nonatomic) BOOL flipHorizontally;
@end
typedef NS_ENUM(NSUInteger, SKTileSetType) { SKTileSetTypeGrid, SKTileSetTypeIsometric, SKTileSetTypeHexagonalFlat, SKTileSetTypeHexagonalPointy };
typedef NS_OPTIONS(NSUInteger, SKTileAdjacencyMask) {
    SKTileAdjacencyUp = 1 << 0, SKTileAdjacencyUpperRight = 1 << 1, SKTileAdjacencyRight = 1 << 2, SKTileAdjacencyLowerRight = 1 << 3,
    SKTileAdjacencyDown = 1 << 4, SKTileAdjacencyLowerLeft = 1 << 5, SKTileAdjacencyLeft = 1 << 6, SKTileAdjacencyUpperLeft = 1 << 7,
    SKTileAdjacencyAll = 0xFF
};
@interface SKTileGroupRule : NSObject
+ (instancetype)tileGroupRuleWithAdjacency:(SKTileAdjacencyMask)adjacency tileDefinitions:(NSArray<SKTileDefinition *> *)tileDefinitions;
@property (nonatomic) SKTileAdjacencyMask adjacency;
@property (nonatomic, copy) NSArray<SKTileDefinition *> *tileDefinitions;
@property (nonatomic, copy, nullable) NSString *name;
@end
@interface SKTileGroup : NSObject
+ (instancetype)tileGroupWithTileDefinition:(SKTileDefinition *)tileDefinition;
+ (instancetype)tileGroupWithRules:(NSArray<SKTileGroupRule *> *)rules;
+ (instancetype)emptyTileGroup;
- (instancetype)initWithTileDefinition:(SKTileDefinition *)tileDefinition;
- (instancetype)initWithRules:(NSArray<SKTileGroupRule *> *)rules;
@property (nonatomic, copy) NSArray<SKTileGroupRule *> *rules;
@property (nonatomic, copy, nullable) NSString *name;
@end
@interface SKTileSet : NSObject
+ (instancetype)tileSetWithTileGroups:(NSArray<SKTileGroup *> *)tileGroups;
+ (instancetype)tileSetWithTileGroups:(NSArray<SKTileGroup *> *)tileGroups tileSetType:(SKTileSetType)tileSetType;
+ (nullable instancetype)tileSetNamed:(NSString *)name;
- (instancetype)initWithTileGroups:(NSArray<SKTileGroup *> *)tileGroups;
@property (nonatomic, copy) NSArray<SKTileGroup *> *tileGroups;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic) SKTileSetType type;
@property (nonatomic, retain, nullable) SKTileGroup *defaultTileGroup;
@property (nonatomic) CGSize defaultTileSize;
@end
@interface SKTileMapNode : SKNode
+ (instancetype)tileMapNodeWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)columns rows:(NSUInteger)rows tileSize:(CGSize)tileSize;
+ (instancetype)tileMapNodeWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)columns rows:(NSUInteger)rows tileSize:(CGSize)tileSize fillWithTileGroup:(SKTileGroup *)tileGroup;
+ (instancetype)tileMapNodeWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)columns rows:(NSUInteger)rows tileSize:(CGSize)tileSize tileGroupLayout:(NSArray<SKTileGroup *> *)tileGroupLayout;
- (instancetype)initWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)columns rows:(NSUInteger)rows tileSize:(CGSize)tileSize;
- (instancetype)initWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)columns rows:(NSUInteger)rows tileSize:(CGSize)tileSize fillWithTileGroup:(SKTileGroup *)tileGroup;
- (instancetype)initWithTileSet:(SKTileSet *)tileSet columns:(NSUInteger)columns rows:(NSUInteger)rows tileSize:(CGSize)tileSize tileGroupLayout:(NSArray<SKTileGroup *> *)tileGroupLayout;
@property (nonatomic) NSUInteger numberOfColumns;
@property (nonatomic) NSUInteger numberOfRows;
@property (nonatomic) CGSize tileSize;
@property (nonatomic, readonly) CGSize mapSize;
@property (nonatomic) SKTileSet *tileSet;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic) UIColor *color;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic, retain, nullable) SKShader *shader;
@property (nonatomic) uint32_t lightingBitMask;
@property (nonatomic) BOOL enableAutomapping;
- (void)fillWithTileGroup:(nullable SKTileGroup *)tileGroup;
- (nullable SKTileDefinition *)tileDefinitionAtColumn:(NSUInteger)column row:(NSUInteger)row;
- (nullable SKTileGroup *)tileGroupAtColumn:(NSUInteger)column row:(NSUInteger)row;
- (void)setTileGroup:(nullable SKTileGroup *)tileGroup forColumn:(NSUInteger)column row:(NSUInteger)row;
- (void)setTileGroup:(SKTileGroup *)tileGroup andTileDefinition:(SKTileDefinition *)tileDefinition forColumn:(NSUInteger)column row:(NSUInteger)row;
- (NSUInteger)tileColumnIndexFromPosition:(CGPoint)position;
- (NSUInteger)tileRowIndexFromPosition:(CGPoint)position;
- (CGPoint)centerOfTileAtColumn:(NSUInteger)column row:(NSUInteger)row;
@end
NS_ASSUME_NONNULL_END
#endif
