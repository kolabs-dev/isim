#pragma once
#import <UIKit/UIGeometry.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: path is replayed into the current drawing context on -fill / -stroke. */
@interface UIBezierPath : NSObject <NSCopying>
+ (instancetype)bezierPath;
+ (instancetype)bezierPathWithRect:(CGRect)rect;
+ (instancetype)bezierPathWithOvalInRect:(CGRect)rect;
+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)moveToPoint:(CGPoint)point;
- (void)addLineToPoint:(CGPoint)point;
- (void)addCurveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2;
- (void)addQuadCurveToPoint:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint;
- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)closePath;
- (void)removeAllPoints;
- (void)appendPath:(UIBezierPath *)bezierPath;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@property (nonatomic, readonly) CGRect bounds;
- (void)fill;
- (void)stroke;
/* the path as a CGPath (shape layers, shadow paths) */
+ (instancetype)bezierPathWithCGPath:(CGPathRef)CGPath;
@property (nonatomic) CGPathRef CGPath;
@end
NS_ASSUME_NONNULL_END
