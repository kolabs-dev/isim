#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFDocument, PDFDestination, PDFAction;

/* an item of a document's outline (bookmarks): a destination, or an action (a GoTo action also gives the
 * destination) */
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
@property (nonatomic, strong, nullable) PDFAction *action PDFKIT_AVAILABLE(10_5, 11_0);
@end

NS_ASSUME_NONNULL_END
