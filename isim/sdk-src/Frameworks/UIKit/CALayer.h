#pragma once
/* isim: Core Animation layers (Apple ships them in QuartzCore; isim keeps them in UIKit, and the QuartzCore
 * Swift module re-exports them). Self-authored, API-compatible names.
 *
 * A view's own layer reports the view's geometry (frame, bounds, position = center, transform); standalone
 * layers keep their own (bounds, position, anchorPoint, zPosition, 3D transform, sublayerTransform). isim
 * renders the layer tree every frame with cairo: affine transforms directly, perspective (m34 / non-affine)
 * transforms by rendering the layer offscreen and warping it onto its projected quad. */
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGContext.h>
#include <CoreGraphics/CGPath.h>
#include <CoreGraphics/CGImage.h>
NS_ASSUME_NONNULL_BEGIN

/* ================= CATransform3D ================= */
typedef struct CATransform3D {
    CGFloat m11, m12, m13, m14;
    CGFloat m21, m22, m23, m24;
    CGFloat m31, m32, m33, m34;
    CGFloat m41, m42, m43, m44;
} CATransform3D;
UIKIT_EXTERN const CATransform3D CATransform3DIdentity;
UIKIT_EXTERN bool CATransform3DIsIdentity(CATransform3D t);
UIKIT_EXTERN bool CATransform3DEqualToTransform(CATransform3D a, CATransform3D b);
UIKIT_EXTERN CATransform3D CATransform3DMakeTranslation(CGFloat tx, CGFloat ty, CGFloat tz);
UIKIT_EXTERN CATransform3D CATransform3DMakeScale(CGFloat sx, CGFloat sy, CGFloat sz);
UIKIT_EXTERN CATransform3D CATransform3DMakeRotation(CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
UIKIT_EXTERN CATransform3D CATransform3DTranslate(CATransform3D t, CGFloat tx, CGFloat ty, CGFloat tz);
UIKIT_EXTERN CATransform3D CATransform3DScale(CATransform3D t, CGFloat sx, CGFloat sy, CGFloat sz);
UIKIT_EXTERN CATransform3D CATransform3DRotate(CATransform3D t, CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
UIKIT_EXTERN CATransform3D CATransform3DConcat(CATransform3D a, CATransform3D b);
UIKIT_EXTERN CATransform3D CATransform3DInvert(CATransform3D t);
UIKIT_EXTERN CATransform3D CATransform3DMakeAffineTransform(CGAffineTransform m);
UIKIT_EXTERN bool CATransform3DIsAffine(CATransform3D t);
UIKIT_EXTERN CGAffineTransform CATransform3DGetAffineTransform(CATransform3D t);

@interface NSValue (CATransform3DAdditions)
+ (NSValue *)valueWithCATransform3D:(CATransform3D)t;
@property (readonly) CATransform3D CATransform3DValue;
@end
@interface NSValue (IsimUIGeometryAdditions)
+ (NSValue *)valueWithCGAffineTransform:(CGAffineTransform)transform;
+ (NSValue *)valueWithCGVector:(CGVector)vector;
@property (nonatomic, readonly) CGAffineTransform CGAffineTransformValue;
@property (nonatomic, readonly) CGVector CGVectorValue;
@end

typedef double CFTimeInterval;
UIKIT_EXTERN CFTimeInterval CACurrentMediaTime(void);   /* seconds on the host monotonic clock (the animation clock) */

/* ================= timing ================= */
typedef NSString *CAMediaTimingFillMode NS_TYPED_ENUM;
UIKIT_EXTERN CAMediaTimingFillMode const kCAFillModeForwards NS_SWIFT_NAME(CAMediaTimingFillMode.forwards);
UIKIT_EXTERN CAMediaTimingFillMode const kCAFillModeBackwards NS_SWIFT_NAME(CAMediaTimingFillMode.backwards);
UIKIT_EXTERN CAMediaTimingFillMode const kCAFillModeBoth NS_SWIFT_NAME(CAMediaTimingFillMode.both);
UIKIT_EXTERN CAMediaTimingFillMode const kCAFillModeRemoved NS_SWIFT_NAME(CAMediaTimingFillMode.removed);

@protocol CAMediaTiming
@property CFTimeInterval beginTime;
@property CFTimeInterval duration;
@property float speed;
@property CFTimeInterval timeOffset;
@property float repeatCount;
@property CFTimeInterval repeatDuration;
@property BOOL autoreverses;
@property (copy) CAMediaTimingFillMode fillMode;
@end

@protocol CAAction
- (void)runActionForKey:(NSString *)event object:(id)anObject arguments:(nullable NSDictionary *)dict;
@end
@interface NSNull (CAActionAdditions) <CAAction>
@end

/* ================= CALayer ================= */
typedef NSString *CALayerCornerCurve NS_TYPED_ENUM;
UIKIT_EXTERN CALayerCornerCurve const kCACornerCurveCircular NS_SWIFT_NAME(CALayerCornerCurve.circular);
UIKIT_EXTERN CALayerCornerCurve const kCACornerCurveContinuous NS_SWIFT_NAME(CALayerCornerCurve.continuous);
typedef NSString *CALayerContentsFilter NS_TYPED_ENUM;
UIKIT_EXTERN CALayerContentsFilter const kCAFilterNearest, kCAFilterLinear, kCAFilterTrilinear;
typedef NSString *CALayerContentsGravity NS_TYPED_ENUM;
UIKIT_EXTERN CALayerContentsGravity const kCAGravityCenter NS_SWIFT_NAME(CALayerContentsGravity.center);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityTop NS_SWIFT_NAME(CALayerContentsGravity.top);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityBottom NS_SWIFT_NAME(CALayerContentsGravity.bottom);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityLeft NS_SWIFT_NAME(CALayerContentsGravity.left);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityRight NS_SWIFT_NAME(CALayerContentsGravity.right);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityTopLeft NS_SWIFT_NAME(CALayerContentsGravity.topLeft);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityTopRight NS_SWIFT_NAME(CALayerContentsGravity.topRight);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityBottomLeft NS_SWIFT_NAME(CALayerContentsGravity.bottomLeft);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityBottomRight NS_SWIFT_NAME(CALayerContentsGravity.bottomRight);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityResize NS_SWIFT_NAME(CALayerContentsGravity.resize);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityResizeAspect NS_SWIFT_NAME(CALayerContentsGravity.resizeAspect);
UIKIT_EXTERN CALayerContentsGravity const kCAGravityResizeAspectFill NS_SWIFT_NAME(CALayerContentsGravity.resizeAspectFill);
typedef NSString *CALayerContentsFormat NS_TYPED_ENUM;
UIKIT_EXTERN CALayerContentsFormat const kCAContentsFormatRGBA8Uint NS_SWIFT_NAME(CALayerContentsFormat.RGBA8Uint);

typedef NS_OPTIONS(NSUInteger, CACornerMask) {
    kCALayerMinXMinYCorner NS_SWIFT_NAME(layerMinXMinYCorner) = 1U << 0,
    kCALayerMaxXMinYCorner NS_SWIFT_NAME(layerMaxXMinYCorner) = 1U << 1,
    kCALayerMinXMaxYCorner NS_SWIFT_NAME(layerMinXMaxYCorner) = 1U << 2,
    kCALayerMaxXMaxYCorner NS_SWIFT_NAME(layerMaxXMaxYCorner) = 1U << 3,
};
typedef NS_OPTIONS(unsigned int, CAEdgeAntialiasingMask) {
    kCALayerLeftEdge NS_SWIFT_NAME(layerLeftEdge) = 1U << 0, kCALayerRightEdge NS_SWIFT_NAME(layerRightEdge) = 1U << 1,
    kCALayerBottomEdge NS_SWIFT_NAME(layerBottomEdge) = 1U << 2, kCALayerTopEdge NS_SWIFT_NAME(layerTopEdge) = 1U << 3,
};
typedef NS_OPTIONS(unsigned int, CAAutoresizingMask) {
    kCALayerNotSizable NS_SWIFT_NAME(layerNotSizable) = 0, kCALayerMinXMargin NS_SWIFT_NAME(layerMinXMargin) = 1U << 0,
    kCALayerWidthSizable NS_SWIFT_NAME(layerWidthSizable) = 1U << 1, kCALayerMaxXMargin NS_SWIFT_NAME(layerMaxXMargin) = 1U << 2,
    kCALayerMinYMargin NS_SWIFT_NAME(layerMinYMargin) = 1U << 3, kCALayerHeightSizable NS_SWIFT_NAME(layerHeightSizable) = 1U << 4,
    kCALayerMaxYMargin NS_SWIFT_NAME(layerMaxYMargin) = 1U << 5,
};

@class CAAnimation, CALayer;
@protocol CALayerDelegate <NSObject>
@optional
- (void)displayLayer:(CALayer *)layer;
- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;
- (void)layerWillDraw:(CALayer *)layer;
- (void)layoutSublayersOfLayer:(CALayer *)layer;
- (nullable id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event;
@end

/* isim: NSCoding methods are declared but CALayer does not adopt NSSecureCoding, so Swift subclasses need no
   required init(coder:) (they may still declare one) */
@interface CALayer : NSObject <NSSecureCoding, CAMediaTiming>
+ (instancetype)layer;
- (instancetype)init;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;
@property (class, readonly) BOOL supportsSecureCoding;
/* the copy Core Animation makes for presentation layers; subclasses copy their own properties */
- (instancetype)initWithLayer:(id)layer;
- (nullable instancetype)presentationLayer NS_SWIFT_NAME(presentation());
- (instancetype)modelLayer NS_SWIFT_NAME(model());

/* geometry */
@property CGRect frame, bounds;
@property CGPoint position, anchorPoint;
@property CGFloat zPosition, anchorPointZ;
@property CATransform3D transform, sublayerTransform;
- (CGAffineTransform)affineTransform;
- (void)setAffineTransform:(CGAffineTransform)m;
@property (getter=isGeometryFlipped) BOOL geometryFlipped;
@property (getter=isDoubleSided) BOOL doubleSided;
- (CGSize)preferredFrameSize;
- (CGPoint)convertPoint:(CGPoint)p fromLayer:(nullable CALayer *)l;
- (CGPoint)convertPoint:(CGPoint)p toLayer:(nullable CALayer *)l;
- (CGRect)convertRect:(CGRect)r fromLayer:(nullable CALayer *)l;
- (CGRect)convertRect:(CGRect)r toLayer:(nullable CALayer *)l;
- (CFTimeInterval)convertTime:(CFTimeInterval)t fromLayer:(nullable CALayer *)l;
- (CFTimeInterval)convertTime:(CFTimeInterval)t toLayer:(nullable CALayer *)l;
- (nullable CALayer *)hitTest:(CGPoint)p;
- (BOOL)containsPoint:(CGPoint)p;

/* appearance */
@property CGFloat cornerRadius, borderWidth;
@property CACornerMask maskedCorners;
@property (nullable) CGColorRef borderColor, backgroundColor, shadowColor;
@property float opacity, shadowOpacity;
@property CGFloat shadowRadius;
@property CGSize shadowOffset;
@property (nullable) CGPathRef shadowPath;
@property BOOL masksToBounds;
@property (getter=isHidden) BOOL hidden;
@property (getter=isOpaque) BOOL opaque;
@property (copy) CALayerCornerCurve cornerCurve;
@property (copy) CALayerContentsFilter magnificationFilter, minificationFilter;   /* isim: nearest affects image drawing */
@property float minificationFilterBias;
@property (nullable, strong) CALayer *mask;
@property BOOL allowsGroupOpacity, allowsEdgeAntialiasing, shouldRasterize, drawsAsynchronously, needsDisplayOnBoundsChange;
@property CGFloat rasterizationScale;
@property CAEdgeAntialiasingMask edgeAntialiasingMask;
@property CAAutoresizingMask autoresizingMask;
@property (nullable, strong) id compositingFilter;                 /* isim: stored, not applied */
@property (nullable, copy) NSArray *filters, *backgroundFilters;   /* isim: stored, not applied */
@property (copy) CALayerContentsFormat contentsFormat;
@property BOOL wantsExtendedDynamicRangeContent;

/* contents: a CGImage (or UIImage), drawn with contentsGravity/contentsRect/contentsScale/contentsCenter */
@property (nullable, strong) id contents;
@property CGRect contentsRect, contentsCenter;
@property (copy) CALayerContentsGravity contentsGravity;
@property CGFloat contentsScale;

@property (nullable, weak) id<CALayerDelegate> delegate;
@property (nullable, readonly) CALayer *superlayer;
@property (nullable, copy) NSString *name;
@property (nullable, copy) NSDictionary<NSString *, id<CAAction>> *actions;
@property (nullable, copy) NSDictionary *style;

/* CAMediaTiming of the layer itself (layer.speed = 0 + timeOffset pauses its animations) */
@property CFTimeInterval beginTime, duration, timeOffset, repeatDuration;
@property float speed, repeatCount;
@property BOOL autoreverses;
@property (copy) CAMediaTimingFillMode fillMode;

/* layer tree */
@property (nullable, copy) NSArray<__kindof CALayer *> *sublayers;
- (void)addSublayer:(CALayer *)layer;
- (void)insertSublayer:(CALayer *)layer atIndex:(unsigned)idx;
- (void)insertSublayer:(CALayer *)layer below:(nullable CALayer *)sibling;
- (void)insertSublayer:(CALayer *)layer above:(nullable CALayer *)sibling;
- (void)replaceSublayer:(CALayer *)oldLayer with:(CALayer *)newLayer;
- (void)removeFromSuperlayer;

/* display & layout (isim: content is redrawn every frame; display/layout run when flagged) */
- (void)setNeedsDisplay;
- (void)setNeedsDisplayInRect:(CGRect)r;
- (BOOL)needsDisplay;
- (void)displayIfNeeded;
- (void)display;
- (void)drawInContext:(CGContextRef)ctx;
- (void)renderInContext:(CGContextRef)ctx;
- (void)setNeedsLayout;
- (BOOL)needsLayout;
- (void)layoutIfNeeded;
- (void)layoutSublayers;
+ (BOOL)needsDisplayForKey:(NSString *)key;

/* animations */
- (void)addAnimation:(CAAnimation *)anim forKey:(nullable NSString *)key;
- (void)removeAllAnimations;
- (void)removeAnimationForKey:(NSString *)key;
- (nullable NSArray<NSString *> *)animationKeys;
- (nullable __kindof CAAnimation *)animationForKey:(NSString *)key;
+ (nullable id)defaultValueForKey:(NSString *)key;
+ (nullable id<CAAction>)defaultActionForKey:(NSString *)event;
- (nullable id<CAAction>)actionForKey:(NSString *)event;
- (BOOL)shouldArchiveValueForKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
