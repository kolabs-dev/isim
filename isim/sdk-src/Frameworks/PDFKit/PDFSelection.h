#pragma once
#import <PDFKit/PDFKitPlatform.h>
#import <PDFKit/PDFPage.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFDocument;

typedef NS_ENUM(NSUInteger, PDFSelectionGranularity) {
    PDFSelectionGranularityCharacter = 0, PDFSelectionGranularityWord = 1, PDFSelectionGranularityLine = 2
} API_AVAILABLE(macos(15.0), ios(18.0));

/* text on one or more pages of a document: ranges of each page's characters (PDFPage.string). isim: drawing fills the
 * characters' rectangles (the active selection in the system's selection blue, others in their color or yellow) */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFSelection : NSObject <NSCopying>
- (instancetype)initWithDocument:(PDFDocument *)document NS_DESIGNATED_INITIALIZER PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, readonly) NSArray<PDFPage *> *pages;
@property (nonatomic, copy, nullable) PDFKitPlatformColor *color;
@property (nonatomic, readonly, nullable) NSString *string;
@property (nonatomic, readonly, nullable) NSAttributedString *attributedString;
- (PDFRect)boundsForPage:(PDFPage *)page;
- (NSUInteger)numberOfTextRangesOnPage:(PDFPage *)page PDFKIT_AVAILABLE(10_7, 11_0);
- (NSRange)rangeAtIndex:(NSUInteger)index onPage:(PDFPage *)page PDFKIT_AVAILABLE(10_7, 11_0);
- (NSArray<PDFSelection *> *)selectionsByLine PDFKIT_AVAILABLE(10_5, 11_0);
- (void)addSelection:(PDFSelection *)selection;
- (void)addSelections:(NSArray<PDFSelection *> *)selections PDFKIT_AVAILABLE(10_5, 11_0);
- (void)extendSelectionAtEnd:(NSInteger)succeed;
- (void)extendSelectionAtStart:(NSInteger)precede PDFKIT_AVAILABLE(10_5, 11_0);
- (void)extendSelectionForLineBoundaries PDFKIT_AVAILABLE(10_13, 11_0);
- (void)drawForPage:(PDFPage *)page active:(BOOL)active;
- (void)drawForPage:(PDFPage *)page withBox:(PDFDisplayBox)box active:(BOOL)active PDFKIT_AVAILABLE(10_5, 11_0);
@end

NS_ASSUME_NONNULL_END
