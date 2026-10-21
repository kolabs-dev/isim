#pragma once
/* isim SpriteKit: shapes: paths stroked and filled (lines, rectangles, circles, ellipses, splines). */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface SKShapeNode : SKNode
+ (instancetype)shapeNodeWithPath:(CGPathRef)path;
+ (instancetype)shapeNodeWithPath:(CGPathRef)path centered:(BOOL)centered;
+ (instancetype)shapeNodeWithRect:(CGRect)rect;
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size;
+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)shapeNodeWithCircleOfRadius:(CGFloat)radius;
+ (instancetype)shapeNodeWithEllipseInRect:(CGRect)rect;
+ (instancetype)shapeNodeWithEllipseOfSize:(CGSize)size;
+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints;
+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)numPoints;
@property (nonatomic, nullable) CGPathRef path;
@property (nonatomic, retain) UIColor *strokeColor;
@property (nonatomic, retain) UIColor *fillColor;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic, getter=isAntialiased) BOOL antialiased;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGFloat glowWidth;
@property (nonatomic) CGLineCap lineCap;
@property (nonatomic) CGLineJoin lineJoin;
@property (nonatomic) CGFloat miterLimit;
@property (nonatomic, readonly) CGFloat lineLength;
@property (nonatomic, retain, nullable) SKTexture *fillTexture;
@property (nonatomic, retain, nullable) SKShader *fillShader;
@property (nonatomic, retain, nullable) SKTexture *strokeTexture;
@property (nonatomic, retain, nullable) SKShader *strokeShader;
@end
NS_ASSUME_NONNULL_END
#endif
