#pragma once
/* isim SceneKit: materials and their properties (issue #330). Lighting is per pixel in linear colour; normal,
 * displacement, reflective, clear coat and self-illumination maps are kept but not drawn. */
#import <SceneKit/SceneKitTypes.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SCNWrapMode) { SCNWrapModeClamp = 1, SCNWrapModeRepeat = 2, SCNWrapModeClampToBorder = 3, SCNWrapModeMirror = 4 };
typedef NS_ENUM(NSInteger, SCNFilterMode) { SCNFilterModeNone = 0, SCNFilterModeNearest = 1, SCNFilterModeLinear = 2 };
typedef NS_ENUM(NSInteger, SCNTransparencyMode) {
    SCNTransparencyModeAOne = 0, SCNTransparencyModeRGBZero = 1, SCNTransparencyModeSingleLayer = 2, SCNTransparencyModeDualLayer = 3,
    SCNTransparencyModeDefault = SCNTransparencyModeAOne
};
typedef NS_ENUM(NSInteger, SCNCullMode) { SCNCullModeBack = 0, SCNCullModeFront = 1 };
typedef NS_ENUM(NSUInteger, SCNFillMode) { SCNFillModeFill = 0, SCNFillModeLines = 1 };
typedef NS_ENUM(NSInteger, SCNBlendMode) {
    SCNBlendModeAlpha = 0, SCNBlendModeAdd = 1, SCNBlendModeSubtract = 2, SCNBlendModeMultiply = 3, SCNBlendModeScreen = 4,
    SCNBlendModeReplace = 5, SCNBlendModeMax = 6
};
typedef NSString *SCNLightingModel NS_TYPED_ENUM;
SCN_EXPORT SCNLightingModel const SCNLightingModelPhong;
SCN_EXPORT SCNLightingModel const SCNLightingModelBlinn;
SCN_EXPORT SCNLightingModel const SCNLightingModelLambert;
SCN_EXPORT SCNLightingModel const SCNLightingModelConstant;
SCN_EXPORT SCNLightingModel const SCNLightingModelPhysicallyBased;
SCN_EXPORT SCNLightingModel const SCNLightingModelShadowOnly;

@interface SCNMaterialProperty : NSObject <NSSecureCoding>
+ (instancetype)materialPropertyWithContents:(id)contents;
@property (nonatomic, retain, nullable) id contents;
@property (nonatomic) CGFloat intensity;
@property (nonatomic) SCNMatrix4 contentsTransform;
@property (nonatomic) SCNWrapMode wrapS, wrapT;
@property (nonatomic) SCNFilterMode minificationFilter, magnificationFilter, mipFilter;
@property (nonatomic) NSInteger mappingChannel;
@property (nonatomic) CGFloat maxAnisotropy;
@property (nonatomic, retain, nullable) id borderColor;
@end

@interface SCNMaterial : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)material;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly) SCNMaterialProperty *diffuse, *ambient, *specular, *emission, *transparent, *reflective, *multiply,
    *normal, *displacement, *ambientOcclusion, *selfIllumination, *metalness, *roughness, *clearCoat, *clearCoatRoughness, *clearCoatNormal;
@property (nonatomic) CGFloat shininess, fresnelExponent, transparency;
@property (nonatomic) SCNTransparencyMode transparencyMode;
@property (nonatomic, copy) SCNLightingModel lightingModelName;
@property (nonatomic, getter=isLitPerPixel) BOOL litPerPixel;
@property (nonatomic, getter=isDoubleSided) BOOL doubleSided;
@property (nonatomic) SCNFillMode fillMode;
@property (nonatomic) SCNCullMode cullMode;
@property (nonatomic) BOOL locksAmbientWithDiffuse, writesToDepthBuffer, readsFromDepthBuffer;
@property (nonatomic) SCNBlendMode blendMode;
@end
NS_ASSUME_NONNULL_END
#endif
