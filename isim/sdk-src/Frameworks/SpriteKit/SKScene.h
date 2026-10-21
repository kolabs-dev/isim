#pragma once
/* isim SpriteKit: scenes: the root node an SKView presents; subclass it and override update: and the other callbacks. */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKView, SKCameraNode, SKPhysicsWorld, AVAudioEngine;
typedef NS_ENUM(NSInteger, SKSceneScaleMode) {
    SKSceneScaleModeFill, SKSceneScaleModeAspectFill, SKSceneScaleModeAspectFit, SKSceneScaleModeResizeFill
};
@protocol SKSceneDelegate <NSObject>
@optional
- (void)update:(NSTimeInterval)currentTime forScene:(SKScene *)scene;
- (void)didEvaluateActionsForScene:(SKScene *)scene;
- (void)didSimulatePhysicsForScene:(SKScene *)scene;
- (void)didApplyConstraintsForScene:(SKScene *)scene;
- (void)didFinishUpdateForScene:(SKScene *)scene;
@end
@interface SKScene : SKNode
+ (instancetype)sceneWithSize:(CGSize)size;
- (instancetype)initWithSize:(CGSize)size;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
- (void)sceneDidLoad;
@property (nonatomic) CGSize size;
@property (nonatomic) SKSceneScaleMode scaleMode;
@property (nonatomic, weak, nullable) SKCameraNode *camera;
@property (nonatomic, weak, nullable) SKNode *listener;
@property (nonatomic, retain, readonly) AVAudioEngine *audioEngine;
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, weak, nullable) id<SKSceneDelegate> delegate;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic, readonly) SKPhysicsWorld *physicsWorld;
- (CGPoint)convertPointFromView:(CGPoint)point;
- (CGPoint)convertPointToView:(CGPoint)point;
@property (nonatomic, weak, readonly, nullable) SKView *view;
- (void)update:(NSTimeInterval)currentTime;
- (void)didEvaluateActions;
- (void)didSimulatePhysics;
- (void)didApplyConstraints;
- (void)didFinishUpdate;
- (void)didMoveToView:(SKView *)view;
- (void)willMoveFromView:(SKView *)view;
- (void)didChangeSize:(CGSize)oldSize;
@end
NS_ASSUME_NONNULL_END
#endif
