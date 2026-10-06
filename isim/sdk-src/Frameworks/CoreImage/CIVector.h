#pragma once
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
@interface CIVector : NSObject <NSCopying>
+ (instancetype)vectorWithValues:(const CGFloat *)values count:(size_t)count;
+ (instancetype)vectorWithX:(CGFloat)x;
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y;
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z;
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w;
+ (instancetype)vectorWithCGPoint:(CGPoint)p;
+ (instancetype)vectorWithCGRect:(CGRect)r;
+ (instancetype)vectorWithCGAffineTransform:(CGAffineTransform)t;
- (instancetype)initWithValues:(const CGFloat *)values count:(size_t)count;
- (instancetype)initWithX:(CGFloat)x;
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y;
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z;
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w;
- (instancetype)initWithCGPoint:(CGPoint)p NS_SWIFT_NAME(init(cgPoint:));
- (instancetype)initWithCGRect:(CGRect)r NS_SWIFT_NAME(init(cgRect:));
- (instancetype)initWithCGAffineTransform:(CGAffineTransform)t NS_SWIFT_NAME(init(cgAffineTransform:));
- (CGFloat)valueAtIndex:(size_t)index NS_SWIFT_NAME(value(at:));
@property (readonly) size_t count;
@property (readonly) CGFloat X, Y, Z, W;
@property (readonly) CGPoint CGPointValue;
@property (readonly) CGRect CGRectValue;
@property (readonly) CGAffineTransform CGAffineTransformValue;
@property (readonly) NSString *stringRepresentation;
@end
NS_ASSUME_NONNULL_END
