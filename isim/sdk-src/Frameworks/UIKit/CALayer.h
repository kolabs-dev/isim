#pragma once
/* isim: minimal CALayer (Apple ships it in QuartzCore; isim keeps it in UIKit for now). */
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGColor.h>
NS_ASSUME_NONNULL_BEGIN
typedef NSString *CALayerCornerCurve NS_TYPED_ENUM;
UIKIT_EXTERN CALayerCornerCurve const kCACornerCurveCircular, kCACornerCurveContinuous;
typedef NSString *CALayerContentsFilter NS_TYPED_ENUM;
UIKIT_EXTERN CALayerContentsFilter const kCAFilterNearest, kCAFilterLinear, kCAFilterTrilinear;
@interface CALayer : NSObject
+ (instancetype)layer;
@property CGRect frame, bounds;
@property CGFloat cornerRadius, borderWidth;
@property (nullable) CGColorRef borderColor, backgroundColor, shadowColor;
@property float opacity, shadowOpacity;
@property CGFloat shadowRadius;
@property CGSize shadowOffset;
@property BOOL masksToBounds, hidden;
@property (copy) CALayerCornerCurve cornerCurve;
@property (copy) CALayerContentsFilter magnificationFilter, minificationFilter;   /* isim: nearest affects image drawing */
@property (nullable, weak, readonly) id delegate;
@property (nullable, readonly) CALayer *superlayer;
- (void)setNeedsDisplay;
- (void)setNeedsLayout;
/* isim (UIAnimation.m): a view's layer reports in-flight animation values (frame, opacity, corner radius, border, shadow) */
- (nullable instancetype)presentationLayer NS_SWIFT_NAME(presentation());
- (void)removeAllAnimations;
@end
NS_ASSUME_NONNULL_END
