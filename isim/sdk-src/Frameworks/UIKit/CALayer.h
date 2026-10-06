#pragma once
/* isim: minimal CALayer (Apple ships it in QuartzCore; isim keeps it in UIKit for now). */
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGContext.h>
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
/* layer tree (isim: sublayers draw above their layer's view content and below its subviews; no 3D, no
   implicit animations). A view's own layer reports the view's frame and bounds. */
@property (nullable, copy) NSArray<CALayer *> *sublayers;
@property (nullable, copy) NSString *name;
- (void)addSublayer:(CALayer *)layer;
- (void)insertSublayer:(CALayer *)layer atIndex:(unsigned)idx;
- (void)insertSublayer:(CALayer *)layer below:(nullable CALayer *)sibling;
- (void)insertSublayer:(CALayer *)layer above:(nullable CALayer *)sibling;
- (void)replaceSublayer:(CALayer *)oldLayer with:(CALayer *)newLayer;
- (void)removeFromSuperlayer;
- (void)layoutSublayers;
- (void)layoutIfNeeded;
- (void)displayIfNeeded;
/* isim: called on every frame the layer is drawn, in the layer's coordinates */
- (void)drawInContext:(CGContextRef)ctx;
/* isim (UIAnimation.m): a view's layer reports in-flight animation values (frame, opacity, corner radius, border, shadow) */
- (nullable instancetype)presentationLayer NS_SWIFT_NAME(presentation());
- (void)removeAllAnimations;
@end
NS_ASSUME_NONNULL_END
