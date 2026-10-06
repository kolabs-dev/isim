#pragma once
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGContext.h>
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
UIKIT_EXTERN CGContextRef _Nullable UIGraphicsGetCurrentContext(void) __attribute__((cf_returns_not_retained));
UIKIT_EXTERN void UIRectFill(CGRect rect);
UIKIT_EXTERN void UIRectFrame(CGRect rect);
UIKIT_EXTERN void UIGraphicsPushContext(CGContextRef context);
UIKIT_EXTERN void UIGraphicsPopContext(void);
@class UIImage;
/* offscreen bitmap contexts (isim: drawn by the host's cairo into an image surface) */
UIKIT_EXTERN void UIGraphicsBeginImageContext(CGSize size);
UIKIT_EXTERN void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);
UIKIT_EXTERN UIImage *_Nullable UIGraphicsGetImageFromCurrentImageContext(void);
UIKIT_EXTERN void UIGraphicsEndImageContext(void);

typedef NS_ENUM(NSInteger, UIGraphicsImageRendererFormatRange) {
    UIGraphicsImageRendererFormatRangeUnspecified = -1, UIGraphicsImageRendererFormatRangeAutomatic = 0,
    UIGraphicsImageRendererFormatRangeExtended, UIGraphicsImageRendererFormatRangeStandard };
NS_SWIFT_UI_ACTOR
@interface UIGraphicsRendererFormat : NSObject <NSCopying>
+ (instancetype)defaultFormat;
+ (instancetype)preferredFormat;
@property (nonatomic, readonly) CGRect bounds;
@end
NS_SWIFT_UI_ACTOR
@interface UIGraphicsImageRendererFormat : UIGraphicsRendererFormat
@property (nonatomic) CGFloat scale;
@property (nonatomic) BOOL opaque;
@property (nonatomic) UIGraphicsImageRendererFormatRange preferredRange;
@end
NS_SWIFT_UI_ACTOR
@interface UIGraphicsRendererContext : NSObject
@property (nonatomic, readonly) CGContextRef CGContext;
@property (nonatomic, readonly) __kindof UIGraphicsRendererFormat *format;
- (void)fillRect:(CGRect)rect;
- (void)strokeRect:(CGRect)rect;
- (void)clipToRect:(CGRect)rect;
@end
NS_SWIFT_UI_ACTOR
@interface UIGraphicsImageRendererContext : UIGraphicsRendererContext
@property (nonatomic, readonly) UIImage *currentImage;
@end
typedef void (^UIGraphicsImageDrawingActions)(UIGraphicsImageRendererContext *rendererContext);
NS_SWIFT_UI_ACTOR
@interface UIGraphicsRenderer : NSObject
- (instancetype)initWithBounds:(CGRect)bounds;
- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsRendererFormat *)format;
@property (nonatomic, readonly) UIGraphicsRendererFormat *format;
@property (nonatomic, readonly) BOOL allowsImageOutput;
@end
NS_SWIFT_UI_ACTOR
@interface UIGraphicsImageRenderer : UIGraphicsRenderer
- (instancetype)initWithSize:(CGSize)size;
- (instancetype)initWithSize:(CGSize)size format:(UIGraphicsImageRendererFormat *)format;
- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsImageRendererFormat *)format;
- (UIImage *)imageWithActions:(NS_NOESCAPE UIGraphicsImageDrawingActions)actions;
- (NSData *)PNGDataWithActions:(NS_NOESCAPE UIGraphicsImageDrawingActions)actions;
- (NSData *)JPEGDataWithCompressionQuality:(CGFloat)compressionQuality actions:(NS_NOESCAPE UIGraphicsImageDrawingActions)actions;
@end
NS_ASSUME_NONNULL_END
