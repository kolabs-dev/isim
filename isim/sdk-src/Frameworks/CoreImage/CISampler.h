#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
@class CIFilterShape;
extern NSString *const kCISamplerAffineMatrix, *const kCISamplerWrapMode, *const kCISamplerFilterMode, *const kCISamplerWrapBlack,
    *const kCISamplerWrapClamp, *const kCISamplerFilterNearest, *const kCISamplerFilterLinear, *const kCISamplerColorSpace;
@interface CISampler : NSObject <NSCopying>
+ (instancetype)samplerWithImage:(CIImage *)im;
+ (instancetype)samplerWithImage:(CIImage *)im keysAndValues:(id)key0, ... NS_REQUIRES_NIL_TERMINATION NS_SWIFT_UNAVAILABLE("use init(image:options:)");
+ (instancetype)samplerWithImage:(CIImage *)im options:(nullable NSDictionary *)dict;
- (instancetype)initWithImage:(CIImage *)im;
- (instancetype)initWithImage:(CIImage *)im keysAndValues:(id)key0, ... NS_REQUIRES_NIL_TERMINATION NS_SWIFT_UNAVAILABLE("use init(image:options:)");
- (instancetype)initWithImage:(CIImage *)im options:(nullable NSDictionary *)dict;
@property (readonly) CIFilterShape *definition;
@property (readonly) CGRect extent;
@end
NS_ASSUME_NONNULL_END
