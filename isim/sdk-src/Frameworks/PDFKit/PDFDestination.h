#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFPage;

/* a coordinate of a destination that the destination leaves unspecified (FLT_MAX) */
PDFKIT_EXTERN const CGFloat kPDFDestinationUnspecifiedValue PDFKIT_AVAILABLE(10_7, 11_0);

/* a point on a page, in page space (y-up), with a zoom */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFDestination : NSObject <NSCopying>
- (instancetype)initWithPage:(PDFPage *)page atPoint:(PDFPoint)point NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, weak, readonly, nullable) PDFPage *page;
@property (nonatomic, readonly) PDFPoint point;
@property (nonatomic) CGFloat zoom PDFKIT_AVAILABLE(10_7, 11_0);
/* reading order: the earlier page first, then the higher point, then the one further left */
- (NSComparisonResult)compare:(PDFDestination *)destination;
@end

NS_ASSUME_NONNULL_END
