#pragma once
#import <PencilKit/PKStroke.h>
NS_ASSUME_NONNULL_BEGIN
/* the uniform type identifier of drawing data */
PENCILKIT_EXTERN CFStringRef const PKAppleDrawingTypeIdentifier API_AVAILABLE(ios(13.0));

/* a drawing: strokes in order. isim: dataRepresentation is isim's own format (a binary property list of the
 * strokes), not the data of an Apple device; initWithData:error: reads only that format. */
NS_SWIFT_NAME(PKDrawingReference) __attribute__((swift_bridge("PKDrawing"))) API_AVAILABLE(ios(13.0))
@interface PKDrawing : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithStrokes:(NSArray<PKStroke *> *)strokes API_AVAILABLE(ios(14.0));
- (nullable instancetype)initWithData:(NSData *)data error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (NSData *)dataRepresentation;
@property (nonatomic, readonly) NSArray<PKStroke *> *strokes API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) PKContentVersion requiredContentVersion API_AVAILABLE(ios(17.0));
- (UIImage *)imageFromRect:(CGRect)rect scale:(CGFloat)scale;
- (PKDrawing *)drawingByApplyingTransform:(CGAffineTransform)transform;
- (PKDrawing *)drawingByAppendingDrawing:(PKDrawing *)drawing;
- (PKDrawing *)drawingByAppendingStrokes:(NSArray<PKStroke *> *)strokes API_AVAILABLE(ios(14.0));
/* the drawing with the parts of its strokes under the stroke path (in its ink's width) erased */
- (PKDrawing *)drawingByErasingStrokePath:(PKStrokePath *)strokePath mask:(nullable UIBezierPath *)mask transform:(CGAffineTransform)transform
    NS_SWIFT_NAME(erasingStrokePath(_:mask:transform:)) API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
