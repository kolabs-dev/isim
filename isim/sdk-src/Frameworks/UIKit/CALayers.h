#pragma once
/* isim: Core Animation layer classes (QuartzCore in Apple's SDK). Self-authored. */
#import <UIKit/CAAnimation.h>
NS_ASSUME_NONNULL_BEGIN

/* ================= CAShapeLayer ================= */
typedef NSString *CAShapeLayerFillRule NS_TYPED_ENUM;
UIKIT_EXTERN CAShapeLayerFillRule const kCAFillRuleNonZero NS_SWIFT_NAME(CAShapeLayerFillRule.nonZero);
UIKIT_EXTERN CAShapeLayerFillRule const kCAFillRuleEvenOdd NS_SWIFT_NAME(CAShapeLayerFillRule.evenOdd);
typedef NSString *CAShapeLayerLineJoin NS_TYPED_ENUM;
UIKIT_EXTERN CAShapeLayerLineJoin const kCALineJoinMiter NS_SWIFT_NAME(CAShapeLayerLineJoin.miter);
UIKIT_EXTERN CAShapeLayerLineJoin const kCALineJoinRound NS_SWIFT_NAME(CAShapeLayerLineJoin.round);
UIKIT_EXTERN CAShapeLayerLineJoin const kCALineJoinBevel NS_SWIFT_NAME(CAShapeLayerLineJoin.bevel);
typedef NSString *CAShapeLayerLineCap NS_TYPED_ENUM;
UIKIT_EXTERN CAShapeLayerLineCap const kCALineCapButt NS_SWIFT_NAME(CAShapeLayerLineCap.butt);
UIKIT_EXTERN CAShapeLayerLineCap const kCALineCapRound NS_SWIFT_NAME(CAShapeLayerLineCap.round);
UIKIT_EXTERN CAShapeLayerLineCap const kCALineCapSquare NS_SWIFT_NAME(CAShapeLayerLineCap.square);

/* strokeStart/strokeEnd trim the stroke along the path's length; path animations interpolate paths with the
   same element structure (others switch half-way) */
@interface CAShapeLayer : CALayer
@property (nullable) CGPathRef path;
@property (nullable) CGColorRef fillColor, strokeColor;
@property (copy) CAShapeLayerFillRule fillRule;
@property CGFloat strokeStart, strokeEnd, lineWidth, miterLimit, lineDashPhase;
@property (copy) CAShapeLayerLineCap lineCap;
@property (copy) CAShapeLayerLineJoin lineJoin;
@property (nullable, copy) NSArray<NSNumber *> *lineDashPattern;
@end

/* ================= CAGradientLayer ================= */
typedef NSString *CAGradientLayerType NS_TYPED_ENUM;
UIKIT_EXTERN CAGradientLayerType const kCAGradientLayerAxial NS_SWIFT_NAME(CAGradientLayerType.axial);
UIKIT_EXTERN CAGradientLayerType const kCAGradientLayerRadial NS_SWIFT_NAME(CAGradientLayerType.radial);
UIKIT_EXTERN CAGradientLayerType const kCAGradientLayerConic NS_SWIFT_NAME(CAGradientLayerType.conic);
@interface CAGradientLayer : CALayer
@property (nullable, copy) NSArray *colors;                 /* CGColors */
@property (nullable, copy) NSArray<NSNumber *> *locations;
@property CGPoint startPoint, endPoint;                    /* unit coordinates of the layer */
@property (copy) CAGradientLayerType type;
@end

/* ================= CATextLayer ================= */
typedef NSString *CATextLayerTruncationMode NS_TYPED_ENUM;
UIKIT_EXTERN CATextLayerTruncationMode const kCATruncationNone NS_SWIFT_NAME(CATextLayerTruncationMode.none);
UIKIT_EXTERN CATextLayerTruncationMode const kCATruncationStart NS_SWIFT_NAME(CATextLayerTruncationMode.start);
UIKIT_EXTERN CATextLayerTruncationMode const kCATruncationEnd NS_SWIFT_NAME(CATextLayerTruncationMode.end);
UIKIT_EXTERN CATextLayerTruncationMode const kCATruncationMiddle NS_SWIFT_NAME(CATextLayerTruncationMode.middle);
typedef NSString *CATextLayerAlignmentMode NS_TYPED_ENUM;
UIKIT_EXTERN CATextLayerAlignmentMode const kCAAlignmentNatural NS_SWIFT_NAME(CATextLayerAlignmentMode.natural);
UIKIT_EXTERN CATextLayerAlignmentMode const kCAAlignmentLeft NS_SWIFT_NAME(CATextLayerAlignmentMode.left);
UIKIT_EXTERN CATextLayerAlignmentMode const kCAAlignmentRight NS_SWIFT_NAME(CATextLayerAlignmentMode.right);
UIKIT_EXTERN CATextLayerAlignmentMode const kCAAlignmentCenter NS_SWIFT_NAME(CATextLayerAlignmentMode.center);
UIKIT_EXTERN CATextLayerAlignmentMode const kCAAlignmentJustified NS_SWIFT_NAME(CATextLayerAlignmentMode.justified);
/* string: NSString or NSAttributedString; font: UIFont, CTFont, font name or CGFont (name) */
@interface CATextLayer : CALayer
@property (nullable, copy) id string;
@property (nullable) CFTypeRef font;
@property CGFloat fontSize;
@property (nullable) CGColorRef foregroundColor;
@property (getter=isWrapped) BOOL wrapped;
@property (copy) CATextLayerTruncationMode truncationMode;
@property (copy) CATextLayerAlignmentMode alignmentMode;
@property BOOL allowsFontSubpixelQuantization;
@end

/* ================= CAReplicatorLayer ================= */
/* draws its sublayers instanceCount times, each copy transformed/delayed/tinted from the previous one */
@interface CAReplicatorLayer : CALayer
@property NSInteger instanceCount;
@property BOOL preservesDepth;
@property CFTimeInterval instanceDelay;
@property CATransform3D instanceTransform;
@property (nullable) CGColorRef instanceColor;
@property float instanceRedOffset, instanceGreenOffset, instanceBlueOffset, instanceAlphaOffset;
@end

/* ================= CATransformLayer / CAScrollLayer ================= */
@interface CATransformLayer : CALayer   /* isim: renders like a plain layer (no shared 3D space) */
@end
typedef NSString *CAScrollLayerScrollMode NS_TYPED_ENUM;
UIKIT_EXTERN CAScrollLayerScrollMode const kCAScrollNone NS_SWIFT_NAME(CAScrollLayerScrollMode.none);
UIKIT_EXTERN CAScrollLayerScrollMode const kCAScrollVertically NS_SWIFT_NAME(CAScrollLayerScrollMode.vertically);
UIKIT_EXTERN CAScrollLayerScrollMode const kCAScrollHorizontally NS_SWIFT_NAME(CAScrollLayerScrollMode.horizontally);
UIKIT_EXTERN CAScrollLayerScrollMode const kCAScrollBoth NS_SWIFT_NAME(CAScrollLayerScrollMode.both);
@interface CAScrollLayer : CALayer
- (void)scrollToPoint:(CGPoint)p NS_SWIFT_NAME(scroll(to:));
- (void)scrollToRect:(CGRect)r NS_SWIFT_NAME(scroll(to:));
@property (copy) CAScrollLayerScrollMode scrollMode;
@end

/* ================= CAEmitterLayer ================= */
typedef NSString *CAEmitterLayerEmitterShape NS_TYPED_ENUM;
UIKIT_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerPoint NS_SWIFT_NAME(CAEmitterLayerEmitterShape.point);
UIKIT_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerLine NS_SWIFT_NAME(CAEmitterLayerEmitterShape.line);
UIKIT_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerRectangle NS_SWIFT_NAME(CAEmitterLayerEmitterShape.rectangle);
UIKIT_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerCuboid NS_SWIFT_NAME(CAEmitterLayerEmitterShape.cuboid);
UIKIT_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerCircle NS_SWIFT_NAME(CAEmitterLayerEmitterShape.circle);
UIKIT_EXTERN CAEmitterLayerEmitterShape const kCAEmitterLayerSphere NS_SWIFT_NAME(CAEmitterLayerEmitterShape.sphere);
typedef NSString *CAEmitterLayerEmitterMode NS_TYPED_ENUM;
UIKIT_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerPoints NS_SWIFT_NAME(CAEmitterLayerEmitterMode.points);
UIKIT_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerOutline NS_SWIFT_NAME(CAEmitterLayerEmitterMode.outline);
UIKIT_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerSurface NS_SWIFT_NAME(CAEmitterLayerEmitterMode.surface);
UIKIT_EXTERN CAEmitterLayerEmitterMode const kCAEmitterLayerVolume NS_SWIFT_NAME(CAEmitterLayerEmitterMode.volume);
typedef NSString *CAEmitterLayerRenderMode NS_TYPED_ENUM;
UIKIT_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerUnordered NS_SWIFT_NAME(CAEmitterLayerRenderMode.unordered);
UIKIT_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerOldestFirst NS_SWIFT_NAME(CAEmitterLayerRenderMode.oldestFirst);
UIKIT_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerOldestLast NS_SWIFT_NAME(CAEmitterLayerRenderMode.oldestLast);
UIKIT_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerBackToFront NS_SWIFT_NAME(CAEmitterLayerRenderMode.backToFront);
UIKIT_EXTERN CAEmitterLayerRenderMode const kCAEmitterLayerAdditive NS_SWIFT_NAME(CAEmitterLayerRenderMode.additive);

@interface CAEmitterCell : NSObject <NSSecureCoding, CAMediaTiming>
+ (instancetype)emitterCell;
@property (nullable, copy) NSString *name;
@property (getter=isEnabled) BOOL enabled;
@property float birthRate, lifetime, lifetimeRange;
@property CGFloat emissionLatitude, emissionLongitude, emissionRange;
@property CGFloat velocity, velocityRange, xAcceleration, yAcceleration, zAcceleration;
@property CGFloat scale, scaleRange, scaleSpeed, spin, spinRange;
@property (nullable) CGColorRef color;
@property float redRange, greenRange, blueRange, alphaRange, redSpeed, greenSpeed, blueSpeed, alphaSpeed;
@property (nullable, strong) id contents;
@property CGRect contentsRect;
@property CGFloat contentsScale;
@property (copy) CALayerContentsFilter minificationFilter, magnificationFilter;
@property float minificationFilterBias;
@property (nullable, copy) NSArray<CAEmitterCell *> *emitterCells;   /* isim: stored, not emitted */
@property (nullable, copy) NSDictionary *style;
@property CFTimeInterval beginTime, duration, timeOffset, repeatDuration;
@property float speed, repeatCount;
@property BOOL autoreverses;
@property (copy) CAMediaTimingFillMode fillMode;
@end

/* isim: a simple 2D particle simulation (point/line/rectangle/circle shapes; velocity, acceleration, spin,
   scale and colour speeds; additive rendering) stepped each frame */
@interface CAEmitterLayer : CALayer
@property (nullable, copy) NSArray<CAEmitterCell *> *emitterCells;
@property float birthRate, lifetime, velocity, scale, spin;
@property CGPoint emitterPosition;
@property CGFloat emitterZPosition, emitterDepth;
@property CGSize emitterSize;
@property (copy) CAEmitterLayerEmitterShape emitterShape;
@property (copy) CAEmitterLayerEmitterMode emitterMode;
@property (copy) CAEmitterLayerRenderMode renderMode;
@property BOOL preservesDepth;
@property unsigned int seed;
/* isim: number of live particles (for tests) */
@property (readonly) NSInteger _isim_particleCount;
@end
NS_ASSUME_NONNULL_END
