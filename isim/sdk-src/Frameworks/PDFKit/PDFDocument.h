#pragma once
#import <PDFKit/PDFKitPlatform.h>
#import <PDFKit/PDFPage.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFOutline;
@protocol PDFDocumentDelegate;

PDFKIT_EXTERN NSNotificationName const PDFDocumentDidUnlockNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFDocumentDidBeginWriteNotification PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN NSNotificationName const PDFDocumentDidEndWriteNotification PDFKIT_AVAILABLE(10_4, 11_0);

typedef NSString *PDFDocumentAttribute NS_TYPED_ENUM;
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentTitleAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentAuthorAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentSubjectAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentCreatorAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentProducerAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentCreationDateAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentModificationDateAttribute PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentAttribute const PDFDocumentKeywordsAttribute PDFKIT_AVAILABLE(10_4, 11_0);

typedef NSString *PDFDocumentWriteOption NS_TYPED_ENUM;
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentOwnerPasswordOption PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentUserPasswordOption PDFKIT_AVAILABLE(10_4, 11_0);
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentAccessPermissionsOption API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentBurnInAnnotationsOption API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentSaveTextFromOCROption API_AVAILABLE(macos(13.0), ios(16.0));
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentSaveImagesAsJPEGOption API_AVAILABLE(macos(14.0), ios(17.0));
PDFKIT_EXTERN PDFDocumentWriteOption const PDFDocumentOptimizeImagesForScreenOption API_AVAILABLE(macos(14.0), ios(17.0));

typedef NS_ENUM(NSInteger, PDFPrintScalingMode) { kPDFPrintPageScaleNone = 0, kPDFPrintPageScaleToFit = 1, kPDFPrintPageScaleDownToFit = 2 };

typedef NS_ENUM(NSInteger, PDFDocumentPermissions) {
    kPDFDocumentPermissionsNone = 0, kPDFDocumentPermissionsUser = 1, kPDFDocumentPermissionsOwner = 2
} PDFKIT_AVAILABLE(10_13, 11_0);

typedef NS_OPTIONS(NSUInteger, PDFAccessPermissions) {
    PDFAllowsLowQualityPrinting = (1 << 0), PDFAllowsHighQualityPrinting = (1 << 1), PDFAllowsDocumentChanges = (1 << 2),
    PDFAllowsDocumentAssembly = (1 << 3), PDFAllowsContentCopying = (1 << 4), PDFAllowsContentAccessibility = (1 << 5),
    PDFAllowsCommenting = (1 << 6), PDFAllowsFormFieldEntry = (1 << 7)
} PDFKIT_AVAILABLE(10_13, 11_0);

/* isim: writing redraws every page into a new PDF (vector content stays vector): a rotated page is written turned,
 * with rotation 0. The outline (page destinations) and the title, author, subject, creator and keywords are written;
 * the password and access-permission options are not (the file is written unencrypted). */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFDocument : NSObject <NSCopying>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, nullable) NSURL *documentURL;
@property (nonatomic, readonly, nullable) CGPDFDocumentRef documentRef PDFKIT_AVAILABLE(10_4, 11_0);
@property (nonatomic, copy, nullable) NSDictionary *documentAttributes;
@property (nonatomic, readonly) NSInteger majorVersion;
@property (nonatomic, readonly) NSInteger minorVersion;
@property (nonatomic, readonly) BOOL isEncrypted;
@property (nonatomic, readonly) BOOL isLocked;
- (BOOL)unlockWithPassword:(NSString *)password;
@property (nonatomic, readonly) BOOL allowsPrinting;
@property (nonatomic, readonly) BOOL allowsCopying;
@property (nonatomic, readonly) BOOL allowsDocumentChanges PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) BOOL allowsDocumentAssembly PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) BOOL allowsContentAccessibility PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) BOOL allowsCommenting PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) BOOL allowsFormFieldEntry PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) PDFAccessPermissions accessPermissions PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly) PDFDocumentPermissions permissionsStatus PDFKIT_AVAILABLE(10_13, 11_0);
@property (nonatomic, readonly, nullable) NSString *string;
@property (nonatomic, weak, nullable) id<PDFDocumentDelegate> delegate;
- (nullable NSData *)dataRepresentation;
- (nullable NSData *)dataRepresentationWithOptions:(NSDictionary *)options PDFKIT_AVAILABLE(10_6, 11_0);
- (BOOL)writeToFile:(NSString *)path;
- (BOOL)writeToFile:(NSString *)path withOptions:(nullable NSDictionary<PDFDocumentWriteOption, id> *)options;
- (BOOL)writeToURL:(NSURL *)url;
- (BOOL)writeToURL:(NSURL *)url withOptions:(nullable NSDictionary<PDFDocumentWriteOption, id> *)options;
@property (nonatomic, strong, nullable) PDFOutline *outlineRoot PDFKIT_AVAILABLE(10_4, 11_0);
@property (nonatomic, readonly) NSUInteger pageCount;
- (nullable PDFPage *)pageAtIndex:(NSUInteger)index;
- (NSUInteger)indexForPage:(PDFPage *)page;
- (void)insertPage:(PDFPage *)page atIndex:(NSUInteger)index;
- (void)removePageAtIndex:(NSUInteger)index;
- (void)exchangePageAtIndex:(NSUInteger)indexA withPageAtIndex:(NSUInteger)indexB;
@property (nonatomic, readonly) Class pageClass PDFKIT_AVAILABLE(10_4, 11_0);
@end

@protocol PDFDocumentDelegate <NSObject>
@optional
- (void)documentDidUnlock:(NSNotification *)notification;
- (void)documentDidBeginDocumentFind:(NSNotification *)notification;
- (void)documentDidEndDocumentFind:(NSNotification *)notification;
- (void)documentDidBeginPageFind:(NSNotification *)notification;
- (void)documentDidEndPageFind:(NSNotification *)notification;
- (void)documentDidFindMatch:(NSNotification *)notification;
- (Class)classForPage PDFKIT_AVAILABLE(10_6, 11_0);
- (Class)classForAnnotationType:(NSString *)annotationType PDFKIT_AVAILABLE(10_13, 11_0);
@end

NS_ASSUME_NONNULL_END
