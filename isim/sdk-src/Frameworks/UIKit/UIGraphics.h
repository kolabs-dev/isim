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
/* PDF (isim: cairo's PDF surface; UIKit drawing goes to the page while the renderer's actions run). Printing: UIPrinting.h. */
UIKIT_EXTERN BOOL UIGraphicsBeginPDFContextToFile(NSString *path, CGRect bounds, NSDictionary *_Nullable documentInfo);
UIKIT_EXTERN void UIGraphicsBeginPDFContextToData(NSMutableData *data, CGRect bounds, NSDictionary *_Nullable documentInfo);
UIKIT_EXTERN void UIGraphicsEndPDFContext(void);
UIKIT_EXTERN void UIGraphicsBeginPDFPage(void);
UIKIT_EXTERN void UIGraphicsBeginPDFPageWithInfo(CGRect bounds, NSDictionary *_Nullable pageInfo);
UIKIT_EXTERN CGRect UIGraphicsGetPDFContextBounds(void);
UIKIT_EXTERN void UIGraphicsSetPDFContextURLForRect(NSURL *url, CGRect rect);
NS_SWIFT_UI_ACTOR
@interface UIGraphicsPDFRendererFormat : UIGraphicsRendererFormat
@property (nonatomic, copy) NSDictionary<NSString *, id> *documentInfo;
@end
NS_SWIFT_UI_ACTOR
@interface UIGraphicsPDFRendererContext : UIGraphicsRendererContext
@property (nonatomic, readonly) CGRect pdfContextBounds;
- (void)beginPage;
- (void)beginPageWithBounds:(CGRect)bounds pageInfo:(NSDictionary<NSString *, id> *)pageInfo NS_SWIFT_NAME(beginPage(withBounds:pageInfo:));
- (void)setURL:(NSURL *)url forRect:(CGRect)rect;
- (void)addDestinationWithName:(NSString *)name atPoint:(CGPoint)point;
- (void)setDestinationWithName:(NSString *)name forRect:(CGRect)rect;
@end
typedef void (^UIGraphicsPDFDrawingActions)(UIGraphicsPDFRendererContext *rendererContext);
NS_SWIFT_UI_ACTOR
@interface UIGraphicsPDFRenderer : UIGraphicsRenderer
- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsPDFRendererFormat *)format;
- (BOOL)writePDFToURL:(NSURL *)url withActions:(NS_NOESCAPE UIGraphicsPDFDrawingActions)actions error:(NSError **)error NS_SWIFT_NAME(writePDF(to:withActions:));
- (NSData *)PDFDataWithActions:(NS_NOESCAPE UIGraphicsPDFDrawingActions)actions NS_SWIFT_NAME(pdfData(actions:));
@end
NS_ASSUME_NONNULL_END
