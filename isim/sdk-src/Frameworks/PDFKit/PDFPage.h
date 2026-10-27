#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFDocument, PDFAnnotation, PDFSelection;

typedef NS_ENUM(NSInteger, PDFDisplayBox) {
    kPDFDisplayBoxMediaBox = 0, kPDFDisplayBoxCropBox = 1, kPDFDisplayBoxBleedBox = 2, kPDFDisplayBoxTrimBox = 3,
    kPDFDisplayBoxArtBox = 4
};

typedef NSString *PDFPageImageInitializationOption NS_TYPED_ENUM NS_SWIFT_NAME(PDFPage.ImageInitializationOption)
    API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFPageImageInitializationOption const PDFPageImageInitializationOptionMediaBox API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFPageImageInitializationOption const PDFPageImageInitializationOptionRotation API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFPageImageInitializationOption const PDFPageImageInitializationOptionUpscaleIfSmaller API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFPageImageInitializationOption const PDFPageImageInitializationOptionCompressionQuality API_AVAILABLE(macos(13.0), ios(16.0));

/* a page of a document, or a new one (blank, US Letter; or from an image). Its annotations are read from its /Annots
 * when first needed; drawing draws them after the content when displaysAnnotations is set */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFPage : NSObject <NSCopying>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithImage:(PDFKitPlatformImage *)image PDFKIT_AVAILABLE(10_4, 11_0);
- (nullable instancetype)initWithImage:(PDFKitPlatformImage *)image options:(NSDictionary<PDFPageImageInitializationOption, id> *)options
    API_AVAILABLE(macos(13.0), ios(16.0));
@property (nonatomic, weak, readonly, nullable) PDFDocument *document;
@property (nonatomic, readonly, nullable) CGPDFPageRef pageRef;
@property (nonatomic, readonly, nullable) NSString *label;
- (PDFRect)boundsForBox:(PDFDisplayBox)box;
- (void)setBounds:(PDFRect)bounds forBox:(PDFDisplayBox)box;
@property (nonatomic) NSInteger rotation;
@property (nonatomic) BOOL displaysAnnotations;
@property (nonatomic, readonly) NSArray<PDFAnnotation *> *annotations;
- (void)addAnnotation:(PDFAnnotation *)annotation;
- (void)removeAnnotation:(PDFAnnotation *)annotation;
- (nullable PDFAnnotation *)annotationAtPoint:(PDFPoint)point;
/* into the current UIKit context (UIGraphicsGetCurrentContext) */
- (void)drawWithBox:(PDFDisplayBox)box API_DEPRECATED_WITH_REPLACEMENT("drawWithBox:toContext:", macos(10.4, 10.12));
- (void)transformContextForBox:(PDFDisplayBox)box API_DEPRECATED_WITH_REPLACEMENT("transformContext:forBox:", macos(10.4, 10.12));
- (void)drawWithBox:(PDFDisplayBox)box toContext:(CGContextRef)context PDFKIT_AVAILABLE(10_12, 11_0);
- (void)transformContext:(CGContextRef)context forBox:(PDFDisplayBox)box PDFKIT_AVAILABLE(10_12, 11_0);
- (PDFKitPlatformImage *)thumbnailOfSize:(PDFSize)size forBox:(PDFDisplayBox)box PDFKIT_AVAILABLE(10_13, 11_0);
- (CGAffineTransform)transformForBox:(PDFDisplayBox)box PDFKIT_AVAILABLE(10_12, 11_0);
@property (nonatomic, readonly) NSUInteger numberOfCharacters;
@property (nonatomic, readonly, nullable) NSString *string;
@property (nonatomic, readonly, nullable) NSAttributedString *attributedString;
- (PDFRect)characterBoundsAtIndex:(NSInteger)index;
- (NSInteger)characterIndexAtPoint:(PDFPoint)point PDFKIT_AVAILABLE(10_7, 11_0);
- (nullable PDFSelection *)selectionForRect:(PDFRect)rect;
- (nullable PDFSelection *)selectionForWordAtPoint:(PDFPoint)point;
- (nullable PDFSelection *)selectionForLineAtPoint:(PDFPoint)point;
- (nullable PDFSelection *)selectionFromPoint:(PDFPoint)startPoint toPoint:(PDFPoint)endPoint;
- (nullable PDFSelection *)selectionForRange:(NSRange)range;
@property (nonatomic, readonly, nullable) NSData *dataRepresentation PDFKIT_AVAILABLE(10_4, 11_0);
@end

NS_ASSUME_NONNULL_END
