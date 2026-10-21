#pragma once
/* isim SceneKit: SCNView. Stub: it draws its background colour only (no 3D renderer yet, #330); the render loop runs at
 * preferredFramesPerSecond while playing (or rendersContinuously) and calls the delegate. */
#import <SceneKit/SCNSceneRenderer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SCNView : UIView <SCNSceneRenderer>
- (instancetype)initWithFrame:(CGRect)frame options:(nullable NSDictionary<NSString *, id> *)options;
@property (nonatomic, retain, nullable) SCNScene *scene;
@property (nonatomic) BOOL allowsCameraControl;
@property (nonatomic) BOOL rendersContinuously;
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic) SCNAntialiasingMode antialiasingMode;
- (UIImage *)snapshot;
- (void)play:(nullable id)sender;
- (void)pause:(nullable id)sender;
- (void)stop:(nullable id)sender;
@end
NS_ASSUME_NONNULL_END
#endif
