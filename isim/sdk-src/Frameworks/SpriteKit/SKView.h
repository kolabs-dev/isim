#pragma once
/* isim SpriteKit: the view that presents scenes and runs the frame loop (CADisplayLink-paced, drawn with isim's 2D renderer). */
#import <SpriteKit/SKScene.h>
#import <SpriteKit/SKTransition.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SKView;
/* Declared for apps and ARSKViewDelegate; isim's frame loop does not consult it yet. */
@protocol SKViewDelegate <NSObject>
@optional
- (BOOL)view:(SKView *)view shouldRenderAtTime:(NSTimeInterval)time;
@end
@interface SKView : UIView
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic) BOOL showsFPS;
@property (nonatomic) BOOL showsDrawCount;
@property (nonatomic) BOOL showsNodeCount;
@property (nonatomic) BOOL showsQuadCount;
@property (nonatomic) BOOL showsPhysics;
@property (nonatomic) BOOL showsFields;
@property (nonatomic, getter=isAsynchronous) BOOL asynchronous;
@property (nonatomic) BOOL allowsTransparency;
@property (nonatomic) BOOL ignoresSiblingOrder;
@property (nonatomic) BOOL shouldCullNonVisibleNodes;
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic) BOOL disableDepthStencilBuffer;
@property (nonatomic, weak, nullable) id<SKViewDelegate> delegate;
- (void)presentScene:(nullable SKScene *)scene;
- (void)presentScene:(SKScene *)scene transition:(SKTransition *)transition;
@property (nonatomic, readonly, nullable) SKScene *scene;
- (nullable SKTexture *)textureFromNode:(SKNode *)node;
- (nullable SKTexture *)textureFromNode:(SKNode *)node crop:(CGRect)crop;
- (CGPoint)convertPoint:(CGPoint)point toScene:(SKScene *)scene;
- (CGPoint)convertPoint:(CGPoint)point fromScene:(SKScene *)scene;
@end
NS_ASSUME_NONNULL_END
#endif
