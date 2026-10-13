#pragma once
/* isim: hover styles (iOS 17) and shapes. A view's hoverStyle gives it the system pointer effect on iPad (the
   pointer exists there only): highlight (a platter behind the view, the pointer morphs into it), lift (the view
   scales up with a shadow) or automatic (highlight). Shapes resolve against a view's bounds into paths.
   UIHoverStyle.m. Swift: UIShape and the UIHoverEffect
   structs in the overlay. */
#import <UIKit/UIView.h>
#import <UIKit/UIBezierPath.h>
NS_ASSUME_NONNULL_BEGIN
@class UIShape, UIResolvedShape, UIShapeResolutionContext;

API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(_UIShapeProviderObjC)
@protocol UIShapeProvider <NSObject>
- (UIResolvedShape *)resolvedShapeInContext:(UIShapeResolutionContext *)context;
@end
/* what a shape resolves against: the content's shape (a view's bounds) */
API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(__UIShapeResolutionContext)
@interface UIShapeResolutionContext : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) UIResolvedShape *contentShape;
@end
API_AVAILABLE(ios(17.0))
@interface UIResolvedShape : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) UIShape *shape NS_REFINED_FOR_SWIFT;
@property (nonatomic, readonly) CGRect boundingRect;
@property (nonatomic, readonly, copy) UIBezierPath *path;
- (UIResolvedShape *)shapeByApplyingInset:(CGFloat)inset NS_SWIFT_NAME(inset(by:));
- (UIResolvedShape *)shapeByApplyingInsets:(UIEdgeInsets)insets NS_SWIFT_NAME(inset(by:));
@end
API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(__UIShape)
@interface UIShape : NSObject <NSCopying>
@property (class, nonatomic, readonly) UIShape *rectShape;
@property (class, nonatomic, readonly) UIShape *capsuleShape;
@property (class, nonatomic, readonly) UIShape *circleShape;
+ (instancetype)rectShapeWithCornerRadius:(CGFloat)cornerRadius;
+ (instancetype)rectShapeWithCornerRadius:(CGFloat)cornerRadius cornerCurve:(UICornerCurve)cornerCurve;
+ (instancetype)rectShapeWithCornerRadius:(CGFloat)cornerRadius cornerCurve:(UICornerCurve)cornerCurve maskedCorners:(UIRectCorner)maskedCorners;
+ (instancetype)fixedRectShapeWithRect:(CGRect)rect;
+ (instancetype)fixedRectShapeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)fixedRectShapeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius cornerCurve:(UICornerCurve)cornerCurve maskedCorners:(UIRectCorner)maskedCorners;
+ (instancetype)shapeWithBezierPath:(UIBezierPath *)path;
+ (instancetype)shapeWithProvider:(id<UIShapeProvider>)provider;
- (instancetype)init NS_UNAVAILABLE;
- (UIShape *)shapeByApplyingInset:(CGFloat)inset NS_SWIFT_NAME(__applyingInset(_:));
- (UIShape *)shapeByApplyingInsets:(UIEdgeInsets)insets NS_SWIFT_NAME(__applyingInsets(_:));
- (UIResolvedShape *)resolvedShapeInContext:(UIShapeResolutionContext *)context;
/* isim: the shape resolved in a rect (the content's bounds) */
- (UIResolvedShape *)_isimResolvedInRect:(CGRect)rect NS_SWIFT_NAME(__isimResolved(in:));
@end

API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(_UIHoverEffectObjC)
@protocol UIHoverEffect <NSObject, NSCopying>
@end
API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(__UIHoverAutomaticEffect)
@interface UIHoverAutomaticEffect : NSObject <UIHoverEffect>
+ (instancetype)effect;
@end
API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(__UIHoverHighlightEffect)
@interface UIHoverHighlightEffect : NSObject <UIHoverEffect>
+ (instancetype)effect;
@end
API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(__UIHoverLiftEffect)
@interface UIHoverLiftEffect : NSObject <UIHoverEffect>
+ (instancetype)effect;
@end
API_AVAILABLE(ios(17.0)) NS_SWIFT_UI_ACTOR
@interface UIHoverStyle : NSObject <NSCopying>
+ (instancetype)styleWithEffect:(id<UIHoverEffect>)effect shape:(nullable UIShape *)shape NS_REFINED_FOR_SWIFT;
+ (instancetype)styleWithShape:(nullable UIShape *)shape NS_REFINED_FOR_SWIFT;
+ (instancetype)automaticStyle;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, copy) id<UIHoverEffect> effect NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, nullable) UIShape *shape NS_REFINED_FOR_SWIFT;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end
@interface UIView (UIHoverStyle)
@property (nonatomic, copy, nullable) UIHoverStyle *hoverStyle API_AVAILABLE(ios(17.0));
@end

NS_ASSUME_NONNULL_END
