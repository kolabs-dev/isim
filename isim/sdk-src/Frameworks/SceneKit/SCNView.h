#pragma once
/* isim SceneKit: SCNView (issue #330): it draws its scene into its CAMetalLayer with isim's Metal on the CPU; the render
 * loop runs at preferredFramesPerSecond, calls the delegate and redraws when the scene changes. */
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
@property (nonatomic, getter=isTemporalAntialiasingEnabled) BOOL temporalAntialiasingEnabled;
- (void)play:(nullable id)sender;
- (void)pause:(nullable id)sender;
- (void)stop:(nullable id)sender;
@end
NS_ASSUME_NONNULL_END
#endif
