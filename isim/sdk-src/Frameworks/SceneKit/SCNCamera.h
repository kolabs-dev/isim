#pragma once
/* isim SceneKit: cameras (issue #330). Post effects (HDR, bloom, depth of field, motion blur) are kept but not drawn. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SCNCameraProjectionDirection) { SCNCameraProjectionDirectionVertical = 0, SCNCameraProjectionDirectionHorizontal = 1 };
@interface SCNCamera : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)camera;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic) CGFloat fieldOfView, focalLength, sensorHeight;
@property (nonatomic) SCNCameraProjectionDirection projectionDirection;
@property (nonatomic) double zNear, zFar, orthographicScale;
@property (nonatomic) BOOL automaticallyAdjustsZRange, usesOrthographicProjection;
@property (nonatomic) SCNMatrix4 projectionTransform;
@property (nonatomic) NSUInteger categoryBitMask;
@property (nonatomic) BOOL wantsHDR, wantsDepthOfField;
@property (nonatomic) CGFloat bloomIntensity, focusDistance, fStop, motionBlurIntensity;
@end
NS_ASSUME_NONNULL_END
#endif
