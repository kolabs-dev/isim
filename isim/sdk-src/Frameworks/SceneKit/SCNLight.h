#pragma once
/* isim SceneKit: lights (issue #330). Ambient, omni, directional and spot lights light the scene per pixel; IES, probe
 * and area lights and shadows are kept as settings but not drawn. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NSString *SCNLightType NS_TYPED_ENUM;
SCN_EXPORT SCNLightType const SCNLightTypeAmbient;
SCN_EXPORT SCNLightType const SCNLightTypeOmni;
SCN_EXPORT SCNLightType const SCNLightTypeDirectional;
SCN_EXPORT SCNLightType const SCNLightTypeSpot;
SCN_EXPORT SCNLightType const SCNLightTypeIES;
SCN_EXPORT SCNLightType const SCNLightTypeProbe;
SCN_EXPORT SCNLightType const SCNLightTypeArea;
@interface SCNLight : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)light;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy) SCNLightType type;
@property (nonatomic, retain) id color;
@property (nonatomic) CGFloat intensity, temperature;
@property (nonatomic) CGFloat attenuationStartDistance, attenuationEndDistance, attenuationFalloffExponent;
@property (nonatomic) CGFloat spotInnerAngle, spotOuterAngle;
@property (nonatomic) NSUInteger categoryBitMask;
@property (nonatomic) BOOL castsShadow;
@property (nonatomic, retain) id shadowColor;
@property (nonatomic) CGFloat shadowRadius, orthographicScale, zNear, zFar;
@end
NS_ASSUME_NONNULL_END
#endif
