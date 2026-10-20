#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFView, PDFPage;

typedef NS_ENUM(NSInteger, PDFThumbnailLayoutMode) { PDFThumbnailLayoutModeVertical = 0, PDFThumbnailLayoutModeHorizontal = 1 }
    PDFKIT_AVAILABLE(NA, 11_0);

PDFKIT_EXTERN NSNotificationName const PDFThumbnailViewDocumentEditedNotification PDFKIT_AVAILABLE(10_4, 11_0);

/* a strip of page thumbnails of a PDFView's document: the current page is outlined, tapping one goes to it */
PDFKIT_CLASS_AVAILABLE(10_5, 11_0)
@interface PDFThumbnailView : PDFKitPlatformView <NSCoding>
@property (nonatomic, strong, nullable) PDFView *PDFView NS_SWIFT_NAME(pdfView);
@property (nonatomic, copy, nullable) PDFKitPlatformColor *backgroundColor;
@property (nonatomic) PDFSize thumbnailSize;
@property (nonatomic) NSUInteger maximumNumberOfColumns;
@property (nonatomic) BOOL allowsDragging;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, readonly, strong, nullable) NSArray<PDFPage *> *selectedPages;
@property (nonatomic) PDFThumbnailLayoutMode layoutMode PDFKIT_AVAILABLE(NA, 11_0);
@property (nonatomic) PDFEdgeInsets contentInset PDFKIT_AVAILABLE(NA, 11_0);
@end

NS_ASSUME_NONNULL_END
