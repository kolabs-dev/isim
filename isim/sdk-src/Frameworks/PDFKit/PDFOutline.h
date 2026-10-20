#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFDocument, PDFDestination;

/* an item of a document's outline (bookmarks). isim: no `action` yet (PDFAction, issue #358); an item that only has a
 * GoTo action reports its destination */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFOutline : NSObject
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@property (nonatomic, weak, readonly, nullable) PDFDocument *document;
@property (nonatomic, weak, readonly, nullable) PDFOutline *parent PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, readonly) NSUInteger numberOfChildren;
@property (nonatomic, readonly) NSUInteger index PDFKIT_AVAILABLE(10_5, 11_0);
- (nullable PDFOutline *)childAtIndex:(NSUInteger)index;
- (void)insertChild:(PDFOutline *)child atIndex:(NSUInteger)index PDFKIT_AVAILABLE(10_5, 11_0);
- (void)removeFromParent PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic) BOOL isOpen PDFKIT_AVAILABLE(10_5, 11_0);
@property (nonatomic, strong, nullable) PDFDestination *destination;
@end

NS_ASSUME_NONNULL_END
