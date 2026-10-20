#pragma once
#include <CoreGraphics/CGContext.h>
#include <CoreGraphics/CGDataProvider.h>
#include <CoreGraphics/CGPDFObject.h>
#include <CoreGraphics/CGPDFString.h>
#include <CoreGraphics/CGPDFArray.h>
#include <CoreGraphics/CGPDFDictionary.h>
#include <CoreGraphics/CGPDFStream.h>
#include <CoreGraphics/CGPDFOperatorTable.h>
#include <CoreGraphics/CGPDFContentStream.h>
#include <CoreGraphics/CGPDFScanner.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* PDF writing: cairo's PDF surface (vector output; shadows become sharp, blurs are not kept); links, destinations, the
 * outline and the document info through cairo's tags (passwords, PDF/A, PDF/X and linearization are not written).
 * PDF reading: the objects with isim's own parser (CGPDFObject.h...), pages rendered by the host's poppler-glib. */
typedef struct CGPDFDocument *CGPDFDocumentRef;
typedef struct CGPDFPage *CGPDFPageRef;
typedef CF_ENUM(int32_t, CGPDFBox) { kCGPDFMediaBox = 0, kCGPDFCropBox = 1, kCGPDFBleedBox = 2, kCGPDFTrimBox = 3, kCGPDFArtBox = 4 };
CG_EXTERN const CFStringRef kCGPDFContextMediaBox;
CG_EXTERN const CFStringRef kCGPDFContextTitle;
CG_EXTERN const CFStringRef kCGPDFContextAuthor;
CG_EXTERN const CFStringRef kCGPDFContextCreator;
CG_EXTERN const CFStringRef kCGPDFContextSubject;
CG_EXTERN const CFStringRef kCGPDFContextKeywords;
CG_EXTERN const CFStringRef kCGPDFContextOwnerPassword;
CG_EXTERN const CFStringRef kCGPDFContextUserPassword;
CG_EXTERN const CFStringRef kCGPDFContextEncryptionKeyLength;
CG_EXTERN const CFStringRef kCGPDFContextAllowsPrinting;
CG_EXTERN const CFStringRef kCGPDFContextAllowsCopying;
CG_EXTERN const CFStringRef kCGPDFContextAccessPermissions;
CG_EXTERN const CFStringRef kCGPDFContextOutputIntent;
CG_EXTERN const CFStringRef kCGPDFContextOutputIntents;
CG_EXTERN const CFStringRef kCGPDFContextCreateLinearizedPDF;
CG_EXTERN const CFStringRef kCGPDFContextCreatePDFA;
CG_EXTERN const CFStringRef kCGPDFContextCropBox;
CG_EXTERN const CFStringRef kCGPDFContextBleedBox;
CG_EXTERN const CFStringRef kCGPDFContextTrimBox;
CG_EXTERN const CFStringRef kCGPDFContextArtBox;
CG_EXTERN const CFStringRef kCGPDFXOutputIntentSubtype;
CG_EXTERN const CFStringRef kCGPDFXOutputConditionIdentifier;
CG_EXTERN const CFStringRef kCGPDFXOutputCondition;
CG_EXTERN const CFStringRef kCGPDFXRegistryName;
CG_EXTERN const CFStringRef kCGPDFXInfo;
CG_EXTERN const CFStringRef kCGPDFXDestinationOutputProfile;
/* outlines (CGPDFDocumentGetOutline, CGPDFContextSetOutline): Title, Children (an array of outlines), Destination
 * (a page number, or a destination name when writing) and DestinationRect (a CGRect dictionary) */
CG_EXTERN const CFStringRef kCGPDFOutlineTitle;
CG_EXTERN const CFStringRef kCGPDFOutlineChildren;
CG_EXTERN const CFStringRef kCGPDFOutlineDestination;
CG_EXTERN const CFStringRef kCGPDFOutlineDestinationRect;
typedef CF_OPTIONS(uint32_t, CGPDFAccessPermissions) {
    kCGPDFAllowsLowQualityPrinting = 1 << 0, kCGPDFAllowsHighQualityPrinting = 1 << 1, kCGPDFAllowsDocumentChanges = 1 << 2,
    kCGPDFAllowsDocumentAssembly = 1 << 3, kCGPDFAllowsContentCopying = 1 << 4, kCGPDFAllowsContentAccessibility = 1 << 5,
    kCGPDFAllowsCommenting = 1 << 6, kCGPDFAllowsFormFieldEntry = 1 << 7
};
CG_EXTERN CGContextRef _Nullable CGPDFContextCreate(CGDataConsumerRef _Nullable consumer, const CGRect *_Nullable mediaBox,
    CFDictionaryRef _Nullable auxiliaryInfo) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGContext.init(consumer:mediaBox:_:));
CG_EXTERN CGContextRef _Nullable CGPDFContextCreateWithURL(CFURLRef _Nullable url, const CGRect *_Nullable mediaBox,
    CFDictionaryRef _Nullable auxiliaryInfo) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGContext.init(_:mediaBox:_:));
CG_EXTERN void CGPDFContextBeginPage(CGContextRef _Nullable context, CFDictionaryRef _Nullable pageInfo) CG_SWIFT_NAME(CGContext.beginPDFPage(self:_:));
CG_EXTERN void CGPDFContextEndPage(CGContextRef _Nullable context) CG_SWIFT_NAME(CGContext.endPDFPage(self:));
CG_EXTERN void CGPDFContextClose(CGContextRef _Nullable context) CG_SWIFT_NAME(CGContext.closePDF(self:));
CG_EXTERN void CGContextBeginPage(CGContextRef _Nullable c, const CGRect *_Nullable mediaBox) CG_SWIFT_NAME(CGContext.beginPage(self:mediaBox:));
CG_EXTERN void CGContextEndPage(CGContextRef _Nullable c) CG_SWIFT_NAME(CGContext.endPage(self:));
/* a link to url over rect (default user space) on the current page */
CG_EXTERN void CGPDFContextSetURLForRect(CGContextRef _Nullable context, CFURLRef url, CGRect rect) CG_SWIFT_NAME(CGContext.setURL(self:_:for:));
/* a named destination at point of the current page, and a link to it over rect */
CG_EXTERN void CGPDFContextAddDestinationAtPoint(CGContextRef _Nullable context, CFStringRef name, CGPoint point) CG_SWIFT_NAME(CGContext.addDestination(self:_:at:));
CG_EXTERN void CGPDFContextSetDestinationForRect(CGContextRef _Nullable context, CFStringRef name, CGRect rect) CG_SWIFT_NAME(CGContext.setDestination(self:_:for:));
/* XMP metadata: not written by isim (cairo has no metadata stream) */
CG_EXTERN void CGPDFContextAddDocumentMetadata(CGContextRef _Nullable context, CFDataRef _Nullable metadata) CG_SWIFT_NAME(CGContext.addDocumentMetadata(self:_:));
CG_EXTERN void CGPDFContextSetOutline(CGContextRef context, CFDictionaryRef _Nullable outline);

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
CG_EXTERN bool CGPDFDocumentUnlockWithPassword(CGPDFDocumentRef _Nullable document, const char *password) CG_SWIFT_NAME(CGPDFDocument.unlockWithPassword(self:_:));
CG_EXTERN bool CGPDFDocumentAllowsPrinting(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.allowsPrinting(self:));
CG_EXTERN bool CGPDFDocumentAllowsCopying(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.allowsCopying(self:));
CG_EXTERN CGPDFAccessPermissions CGPDFDocumentGetAccessPermissions(CGPDFDocumentRef document) CG_SWIFT_NAME(getter:CGPDFDocument.accessPermissions(self:));
CG_EXTERN void CGPDFDocumentGetVersion(CGPDFDocumentRef _Nullable document, int *majorVersion, int *minorVersion)
    CG_SWIFT_NAME(CGPDFDocument.getVersion(self:majorVersion:minorVersion:));
CG_EXTERN CGPDFDictionaryRef _Nullable CGPDFDocumentGetCatalog(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.catalog(self:));
CG_EXTERN CGPDFDictionaryRef _Nullable CGPDFDocumentGetInfo(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.info(self:));
CG_EXTERN CGPDFArrayRef _Nullable CGPDFDocumentGetID(CGPDFDocumentRef _Nullable document) CG_SWIFT_NAME(getter:CGPDFDocument.fileIdentifier(self:));
CG_EXTERN CFDictionaryRef _Nullable CGPDFDocumentGetOutline(CGPDFDocumentRef document) CG_SWIFT_NAME(getter:CGPDFDocument.outline(self:));
CG_EXTERN CFTypeID CGPDFPageGetTypeID(void);
CG_EXTERN CGPDFPageRef _Nullable CGPDFPageRetain(CGPDFPageRef _Nullable page);
CG_EXTERN void CGPDFPageRelease(CGPDFPageRef _Nullable page);
CG_EXTERN CGPDFDocumentRef _Nullable CGPDFPageGetDocument(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.document(self:));
CG_EXTERN size_t CGPDFPageGetPageNumber(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.pageNumber(self:));
CG_EXTERN CGRect CGPDFPageGetBoxRect(CGPDFPageRef _Nullable page, CGPDFBox box) CG_SWIFT_NAME(CGPDFPage.getBoxRect(self:_:));
CG_EXTERN int CGPDFPageGetRotationAngle(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.rotationAngle(self:));
CG_EXTERN CGPDFDictionaryRef _Nullable CGPDFPageGetDictionary(CGPDFPageRef _Nullable page) CG_SWIFT_NAME(getter:CGPDFPage.dictionary(self:));
CG_EXTERN CGAffineTransform CGPDFPageGetDrawingTransform(CGPDFPageRef _Nullable page, CGPDFBox box, CGRect rect, int rotate, bool preserveAspectRatio)
    CG_SWIFT_NAME(CGPDFPage.getDrawingTransform(self:_:rect:rotate:preserveAspectRatio:));
/* draws the page in its PDF space (y-up, origin at the media box's lower left) */
CG_EXTERN void CGContextDrawPDFPage(CGContextRef _Nullable c, CGPDFPageRef _Nullable page) CG_SWIFT_NAME(CGContext.drawPDFPage(self:_:));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
