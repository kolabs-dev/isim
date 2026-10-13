#pragma once
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor;
/* A color with its color space (sRGB unless given); components outside 0...1 are kept (extended range). */
@interface CIColor : NSObject <NSSecureCoding, NSCopying>
+ (instancetype)colorWithCGColor:(CGColorRef)c;
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b;
+ (nullable instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a colorSpace:(CGColorSpaceRef)colorSpace;
+ (nullable instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b colorSpace:(CGColorSpaceRef)colorSpace;
+ (instancetype)colorWithString:(NSString *)representation;
- (instancetype)initWithCGColor:(CGColorRef)c NS_SWIFT_NAME(init(cgColor:));
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b;
- (nullable instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a colorSpace:(CGColorSpaceRef)colorSpace;
- (nullable instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b colorSpace:(CGColorSpaceRef)colorSpace;
/* UIKit additions */
- (instancetype)initWithColor:(UIColor *)color;
@property (readonly) size_t numberOfComponents;
@property (readonly) const CGFloat *components NS_RETURNS_INNER_POINTER;
@property (readonly) CGFloat alpha, red, green, blue;
@property (readonly) CGColorSpaceRef colorSpace;
@property (readonly) NSString *stringRepresentation;
@property (class, strong, readonly) CIColor *blackColor, *whiteColor, *grayColor, *redColor, *greenColor, *blueColor, *cyanColor, *magentaColor, *yellowColor, *clearColor;
@end
NS_ASSUME_NONNULL_END
