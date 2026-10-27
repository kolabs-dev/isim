/* isim PDFKit: what its files share (not a public header) */
#pragma once
#import <PDFKit/PDFKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface PDFPage (IsimInternal)
- (instancetype)_initWithDocument:(CGPDFDocumentRef)doc index:(size_t)index;
- (nullable CGPDFDocumentRef)_source;
- (size_t)_sourceIndex;
- (CGSize)_displaySize:(PDFDisplayBox)box;
- (void)setDocument:(nullable PDFDocument *)document;
/* a rectangle per UTF-16 unit of `string` (a surrogate pair's two units share one); count: string.length */
- (nullable const CGRect *)_isim_unitRects;
/* the character under a point, else the nearest one (in reading order); NSNotFound without text */
- (NSUInteger)_isim_characterNearPoint:(CGPoint)point;
/* the line (between line breaks) around a character, without its break */
- (NSRange)_isim_lineRangeAt:(NSUInteger)index;
- (NSRange)_isim_wordRangeAt:(NSUInteger)index;
/* the annotations as read, or as changed; drawn in a page context (y-up, the page's coordinates) */
- (NSArray<PDFAnnotation *> *)_isim_annotations;
- (void)_isim_drawAnnotationsIn:(CGContextRef)ctx box:(PDFDisplayBox)box printing:(BOOL)printing;
@end

@interface PDFDocument (IsimInternal)
- (nullable PDFDestination *)_isim_destinationForObject:(CGPDFObjectRef)object;
- (nullable PDFAction *)_isim_actionForDictionary:(CGPDFDictionaryRef)dict;
@end

@interface PDFSelection (IsimInternal)
- (void)_isim_addRange:(NSRange)range onPage:(PDFPage *)page;
- (BOOL)_isim_isEmpty;
/* every character range, in document order: (page, range) */
- (void)_isim_enumerate:(void (^)(PDFPage *page, NSRange range, BOOL *stop))block;
- (NSArray<NSValue *> *)_isim_rectsForPage:(PDFPage *)page;
@end

@interface PDFAnnotation (IsimInternal)
- (nullable instancetype)_initWithIsimDictionary:(CGPDFDictionaryRef)dict page:(PDFPage *)page;
- (nullable CGPDFDictionaryRef)_isim_sourceDictionary;
- (BOOL)_isim_isModified;
/* the annotation's dictionary in PDF syntax, in the written page's space (transform); refs: page and annotation
 * placeholders "@P<n>@" (page n of the written document) and "@A<n>@" (annotation n of `all`) */
- (NSString *)_isim_pdfSourceWithTransform:(CGAffineTransform)t pages:(NSArray<PDFPage *> *)pages all:(NSArray<PDFAnnotation *> *)all;
@end

@interface PDFAction (IsimInternal)
- (nullable NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *page))transform;
@end

static inline BOOL isim_low_surrogate(unichar c) { return c >= 0xDC00 && c <= 0xDFFF; }
static inline BOOL isim_high_surrogate(unichar c) { return c >= 0xD800 && c <= 0xDBFF; }

/* PDF syntax */
NSString *isim_pdf_string_literal(NSString *s);
NSString *isim_pdf_name(NSString *s);
NSString *isim_pdf_number(CGFloat v);
UIColor *isim_pdf_color(CGPDFArrayRef a);
NSString *isim_pdf_color_array(UIColor *c);
NS_ASSUME_NONNULL_END
