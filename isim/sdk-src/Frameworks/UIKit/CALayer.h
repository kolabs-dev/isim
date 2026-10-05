#pragma once
/* isim: minimal CALayer (Apple ships it in QuartzCore; isim keeps it in UIKit for now). */
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGColor.h>
NS_ASSUME_NONNULL_BEGIN
typedef NSString *CALayerCornerCurve NS_TYPED_ENUM;
UIKIT_EXTERN CALayerCornerCurve const kCACornerCurveCircular, kCACornerCurveContinuous;
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
@property (nullable, weak, readonly) id delegate;
@property (nullable, readonly) CALayer *superlayer;
- (void)setNeedsDisplay;
- (void)setNeedsLayout;
@end
NS_ASSUME_NONNULL_END
