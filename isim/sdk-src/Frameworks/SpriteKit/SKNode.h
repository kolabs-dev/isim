#pragma once
/* isim SpriteKit: the node tree: transforms, children, actions, physics, constraints, hit testing and coordinate conversion. */
#import <SpriteKit/SKAction.h>
#import <SpriteKit/SKShader.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKScene, SKPhysicsBody, SKConstraint, SKReachConstraints, SKView;
@interface SKNode : UIResponder <NSCopying>
+ (instancetype)node;
+ (nullable instancetype)nodeWithFileNamed:(NSString *)filename;
- (instancetype)init;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
@property (nonatomic, readonly) CGRect frame;
- (CGRect)calculateAccumulatedFrame;
@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat zPosition;
@property (nonatomic) CGFloat zRotation;
@property (nonatomic) CGFloat xScale;
@property (nonatomic) CGFloat yScale;
@property (nonatomic) CGFloat speed;
@property (nonatomic) CGFloat alpha;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, readonly, nullable) SKNode *parent;
@property (nonatomic, readonly) NSArray<SKNode *> *children;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly, nullable) SKScene *scene;
@property (nonatomic, retain, nullable) SKPhysicsBody *physicsBody;
@property (nonatomic, retain, nullable) NSMutableDictionary *userData;
@property (nonatomic, copy, nullable) SKReachConstraints *reachConstraints;
@property (nonatomic, copy, nullable) NSArray<SKConstraint *> *constraints;
@property (nonatomic, copy) NSDictionary<NSString *, SKAttributeValue *> *attributeValues;
- (nullable SKAttributeValue *)valueForAttributeNamed:(NSString *)key;
- (void)setValue:(SKAttributeValue *)value forAttributeNamed:(NSString *)key;
- (void)setScale:(CGFloat)scale;
- (void)addChild:(SKNode *)node;
- (void)insertChild:(SKNode *)node atIndex:(NSInteger)index;
- (void)removeChildrenInArray:(NSArray<SKNode *> *)nodes;
- (void)removeAllChildren;
- (void)removeFromParent;
- (void)moveToParent:(SKNode *)parent;
- (nullable SKNode *)childNodeWithName:(NSString *)name;
- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void (NS_NOESCAPE ^)(SKNode *node, BOOL *stop))block;
- (NSArray<SKNode *> *)objectForKeyedSubscript:(NSString *)name;
- (BOOL)inParentHierarchy:(SKNode *)parent;
- (void)runAction:(SKAction *)action;
- (void)runAction:(SKAction *)action completion:(void (^)(void))block;
- (void)runAction:(SKAction *)action withKey:(NSString *)key;
- (BOOL)hasActions;
- (nullable SKAction *)actionForKey:(NSString *)key;
- (void)removeActionForKey:(NSString *)key;
- (void)removeAllActions;
- (BOOL)containsPoint:(CGPoint)p;
- (SKNode *)nodeAtPoint:(CGPoint)p;
- (NSArray<SKNode *> *)nodesAtPoint:(CGPoint)p;
- (CGPoint)convertPoint:(CGPoint)point fromNode:(SKNode *)node;
- (CGPoint)convertPoint:(CGPoint)point toNode:(SKNode *)node;
- (BOOL)isEqualToNode:(SKNode *)node;
@end
@interface UITouch (SKNodeTouches)
- (CGPoint)locationInNode:(SKNode *)node;
- (CGPoint)previousLocationInNode:(SKNode *)node;
@end
NS_ASSUME_NONNULL_END
#endif
