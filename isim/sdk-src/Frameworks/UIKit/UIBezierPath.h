#pragma once
#import <UIKit/UIGeometry.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: a CGMutablePath with line and fill settings; -fill / -stroke / -addClip replay it into the current context */
@interface UIBezierPath : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)bezierPath;
+ (instancetype)bezierPathWithRect:(CGRect)rect;
+ (instancetype)bezierPathWithOvalInRect:(CGRect)rect;
+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii;
+ (instancetype)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
+ (instancetype)bezierPathWithCGPath:(CGPathRef)CGPath;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

@property (nonatomic) CGPathRef CGPath;

- (void)moveToPoint:(CGPoint)point;
- (void)addLineToPoint:(CGPoint)point;
- (void)addCurveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2;
- (void)addQuadCurveToPoint:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint;
- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)closePath;
- (void)removeAllPoints;
- (void)appendPath:(UIBezierPath *)bezierPath;
- (UIBezierPath *)bezierPathByReversingPath;
- (void)applyTransform:(CGAffineTransform)transform;

@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGPoint currentPoint;
- (BOOL)containsPoint:(CGPoint)point;

@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGLineCap lineCapStyle;
@property (nonatomic) CGLineJoin lineJoinStyle;
@property (nonatomic) CGFloat miterLimit;
@property (nonatomic) CGFloat flatness;
@property (nonatomic) BOOL usesEvenOddFillRule;
- (void)setLineDash:(const CGFloat * _Nullable)pattern count:(NSInteger)count phase:(CGFloat)phase;
- (void)getLineDash:(CGFloat * _Nullable)pattern count:(NSInteger * _Nullable)count phase:(CGFloat * _Nullable)phase;

- (void)fill;
- (void)stroke;
- (void)fillWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)strokeWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)addClip;
@end
NS_ASSUME_NONNULL_END
