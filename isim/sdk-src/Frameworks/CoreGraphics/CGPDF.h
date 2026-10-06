#pragma once
#include <CoreGraphics/CGContext.h>
#include <CoreGraphics/CGDataProvider.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* PDF writing: cairo's PDF surface (vector output; shadows become sharp, blurs are not kept).
 * PDF reading: the host's poppler-glib when it is installed (documents fail to open without it). */
typedef struct CGPDFDocument *CGPDFDocumentRef;
typedef struct CGPDFPage *CGPDFPageRef;
typedef CF_ENUM(int32_t, CGPDFBox) { kCGPDFMediaBox = 0, kCGPDFCropBox = 1, kCGPDFBleedBox = 2, kCGPDFTrimBox = 3, kCGPDFArtBox = 4 };
CG_EXTERN const CFStringRef kCGPDFContextMediaBox;
CG_EXTERN const CFStringRef kCGPDFContextTitle;
CG_EXTERN const CFStringRef kCGPDFContextAuthor;
CG_EXTERN const CFStringRef kCGPDFContextCreator;
CG_EXTERN CGContextRef _Nullable CGPDFContextCreate(CGDataConsumerRef _Nullable consumer, const CGRect *_Nullable mediaBox,
    CFDictionaryRef _Nullable auxiliaryInfo) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGContext.init(consumer:mediaBox:_:));
CG_EXTERN CGContextRef _Nullable CGPDFContextCreateWithURL(CFURLRef _Nullable url, const CGRect *_Nullable mediaBox,
    CFDictionaryRef _Nullable auxiliaryInfo) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGContext.init(_:mediaBox:_:));
CG_EXTERN void CGPDFContextBeginPage(CGContextRef _Nullable context, CFDictionaryRef _Nullable pageInfo) CG_SWIFT_NAME(CGContext.beginPDFPage(self:_:));
CG_EXTERN void CGPDFContextEndPage(CGContextRef _Nullable context) CG_SWIFT_NAME(CGContext.endPDFPage(self:));
CG_EXTERN void CGPDFContextClose(CGContextRef _Nullable context) CG_SWIFT_NAME(CGContext.closePDF(self:));
CG_EXTERN void CGContextBeginPage(CGContextRef _Nullable c, const CGRect *_Nullable mediaBox) CG_SWIFT_NAME(CGContext.beginPage(self:mediaBox:));
CG_EXTERN void CGContextEndPage(CGContextRef _Nullable c) CG_SWIFT_NAME(CGContext.endPage(self:));

CG_EXTERN CFTypeID CGPDFDocumentGetTypeID(void);
CG_EXTERN CGPDFDocumentRef _Nullable CGPDFDocumentCreateWithProvider(CGDataProviderRef _Nullable provider) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGPDFDocument.init(_:));
CG_EXTERN CGPDFDocumentRef _Nullable CGPDFDocumentCreateWithURL(CFURLRef _Nullable url) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGPDFDocument.init(_:));
CG_EXTERN CGPDFDocumentRef _Nullable CGPDFDocumentRetain(CGPDFDocumentRef _Nullable document);
CG_EXTERN void CGPDFDocumentRelease(CGPDFDocumentRef _Nullable document);
CG_EXTERN size_t CGPDFDocumentGetNumberOfPages(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.numberOfPages(self:));
/* pages are numbered from 1 */
CG_EXTERN CGPDFPageRef _Nullable CGPDFDocumentGetPage(CGPDFDocumentRef _Nullable document, size_t pageNumber) CG_SWIFT_NAME(CGPDFDocument.page(self:at:));
CG_EXTERN bool CGPDFDocumentIsEncrypted(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.isEncrypted(self:));
CG_EXTERN bool CGPDFDocumentIsUnlocked(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.isUnlocked(self:));
CG_EXTERN CFTypeID CGPDFPageGetTypeID(void);
CG_EXTERN CGPDFPageRef _Nullable CGPDFPageRetain(CGPDFPageRef _Nullable page);
CG_EXTERN void CGPDFPageRelease(CGPDFPageRef _Nullable page);
CG_EXTERN CGPDFDocumentRef _Nullable CGPDFPageGetDocument(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.document(self:));
CG_EXTERN size_t CGPDFPageGetPageNumber(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.pageNumber(self:));
CG_EXTERN CGRect CGPDFPageGetBoxRect(CGPDFPageRef _Nullable page, CGPDFBox box) CG_SWIFT_NAME(CGPDFPage.getBoxRect(self:_:));
CG_EXTERN int CGPDFPageGetRotationAngle(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.rotationAngle(self:));
CG_EXTERN CGAffineTransform CGPDFPageGetDrawingTransform(CGPDFPageRef _Nullable page, CGPDFBox box, CGRect rect, int rotate, bool preserveAspectRatio)
    CG_SWIFT_NAME(CGPDFPage.getDrawingTransform(self:_:rect:rotate:preserveAspectRatio:));
/* draws the page in its PDF space (y-up, origin at the media box's lower left) */
CG_EXTERN void CGContextDrawPDFPage(CGContextRef _Nullable c, CGPDFPageRef _Nullable page) CG_SWIFT_NAME(CGContext.drawPDFPage(self:_:));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
