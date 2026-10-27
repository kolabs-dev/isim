#pragma once
#import <PencilKit/PKTool.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, PKEraserType) {
    PKEraserTypeVector,             /* removes whole strokes */
    PKEraserTypeBitmap,             /* removes the parts of strokes under it */
    PKEraserTypeFixedWidthBitmap API_AVAILABLE(ios(16.4)),
} NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(13.0));

NS_SWIFT_NAME(PKEraserToolReference) __attribute__((swift_bridge("PKEraserTool"))) API_AVAILABLE(ios(13.0))
@interface PKEraserTool : PKTool
- (instancetype)initWithEraserType:(PKEraserType)eraserType;
- (instancetype)initWithEraserType:(PKEraserType)eraserType width:(CGFloat)width NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(16.4));
@property (nonatomic, readonly) PKEraserType eraserType;
@property (nonatomic, readonly) CGFloat width API_AVAILABLE(ios(16.4));
+ (CGFloat)defaultWidthForEraserType:(PKEraserType)eraserType API_AVAILABLE(ios(16.4));
+ (CGFloat)minimumWidthForEraserType:(PKEraserType)eraserType API_AVAILABLE(ios(16.4));
+ (CGFloat)maximumWidthForEraserType:(PKEraserType)eraserType API_AVAILABLE(ios(16.4));
@end
NS_ASSUME_NONNULL_END
