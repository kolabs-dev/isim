#pragma once
/* isim ARKit: ARSCNView (SceneKit's SCNView, which draws nothing yet, #330: the view shows black; no camera feed on isim)
 * and ARSKView (SpriteKit over black; declared once SpriteKit has Objective-C headers, #618). Their delegates get the
 * session's events. */
#import <ARKit/ARSession.h>
#import <SceneKit/SceneKit.h>
#if __has_include(<SpriteKit/SpriteKit.h>)
#import <SpriteKit/SpriteKit.h>
#endif
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol ARSCNViewDelegate <SCNSceneRendererDelegate, ARSessionObserver>
@optional
- (nullable SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor;
- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
- (void)renderer:(id<SCNSceneRenderer>)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
- (void)renderer:(id<SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
@end
@interface ARSCNView : SCNView <ARSessionProviding>
@property (nonatomic, weak, nullable) id<ARSCNViewDelegate> delegate;
@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) SCNScene *scene;
@property (nonatomic) BOOL automaticallyUpdatesLighting;
@property (nonatomic) BOOL rendersCameraGrain;
@property (nonatomic) BOOL rendersMotionBlur;
- (nullable ARAnchor *)anchorForNode:(SCNNode *)node;
- (nullable SCNNode *)nodeForAnchor:(ARAnchor *)anchor;
- (nullable ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point allowingTarget:(ARRaycastTarget)target alignment:(ARRaycastTargetAlignment)alignment;
@end
#if __has_include(<SpriteKit/SpriteKit.h>)
@class ARSKView;
@protocol ARSKViewDelegate <SKViewDelegate, ARSessionObserver>
@optional
- (nullable SKNode *)view:(ARSKView *)view nodeForAnchor:(ARAnchor *)anchor;
- (void)view:(ARSKView *)view didAddNode:(SKNode *)node forAnchor:(ARAnchor *)anchor;
- (void)view:(ARSKView *)view willUpdateNode:(SKNode *)node forAnchor:(ARAnchor *)anchor;
- (void)view:(ARSKView *)view didUpdateNode:(SKNode *)node forAnchor:(ARAnchor *)anchor;
- (void)view:(ARSKView *)view didRemoveNode:(SKNode *)node forAnchor:(ARAnchor *)anchor;
@end
@interface ARSKView : SKView <ARSessionProviding>
@property (nonatomic, weak, nullable) id<ARSKViewDelegate> delegate;
@property (nonatomic, strong) ARSession *session;
- (nullable ARAnchor *)anchorForNode:(SKNode *)node;
- (nullable SKNode *)nodeForAnchor:(ARAnchor *)anchor;
@end
#endif
typedef NS_ENUM(NSInteger, ARCoachingGoal) {
    ARCoachingGoalTracking = 0, ARCoachingGoalHorizontalPlane, ARCoachingGoalVerticalPlane, ARCoachingGoalAnyPlane, ARCoachingGoalGeoTracking
};
@class ARCoachingOverlayView;
@protocol ARCoachingOverlayViewDelegate <NSObject>
@optional
- (void)coachingOverlayViewDidRequestSessionReset:(ARCoachingOverlayView *)coachingOverlayView;
- (void)coachingOverlayViewWillActivate:(ARCoachingOverlayView *)coachingOverlayView;
- (void)coachingOverlayViewDidDeactivate:(ARCoachingOverlayView *)coachingOverlayView;
@end
@interface ARCoachingOverlayView : UIView
@property (nonatomic, weak, nullable) id<ARCoachingOverlayViewDelegate> delegate;
@property (nonatomic, strong, nullable) ARSession *session;
@property (nonatomic) ARCoachingGoal goal;
@property (nonatomic) BOOL activatesAutomatically;
@property (nonatomic, readonly) BOOL isActive;
- (void)setActive:(BOOL)active animated:(BOOL)animated;
@end
NS_ASSUME_NONNULL_END
#endif
