#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
/* an image whose pixels are kept (rendered on setImage:), for feedback effects such as painting */
@interface CIImageAccumulator : NSObject
+ (nullable instancetype)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format;
+ (nullable instancetype)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace;
- (nullable instancetype)initWithExtent:(CGRect)extent format:(CIFormat)format;
- (nullable instancetype)initWithExtent:(CGRect)extent format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace;
@property (readonly) CGRect extent;
@property (readonly) CIFormat format;
- (CIImage *)image;
- (void)setImage:(CIImage *)image;
- (void)setImage:(CIImage *)image dirtyRect:(CGRect)dirtyRect;
- (void)clear;
@end
NS_ASSUME_NONNULL_END
