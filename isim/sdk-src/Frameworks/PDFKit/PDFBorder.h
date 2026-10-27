#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PDFBorderStyle) {
    kPDFBorderStyleSolid = 0, kPDFBorderStyleDashed = 1, kPDFBorderStyleBeveled = 2, kPDFBorderStyleInset = 3,
    kPDFBorderStyleUnderline = 4
};

typedef NSString *const PDFBorderKey NS_STRING_ENUM;
PDFKIT_EXTERN PDFBorderKey PDFBorderKeyLineWidth PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFBorderKey PDFBorderKeyStyle PDFKIT_AVAILABLE(10_13, 11_0);
PDFKIT_EXTERN PDFBorderKey PDFBorderKeyDashPattern PDFKIT_AVAILABLE(10_13, 11_0);

/* an annotation's border: its style, width and dash pattern (/BS, or /Border) */
PDFKIT_CLASS_AVAILABLE(10_4, 11_0)
@interface PDFBorder : NSObject <NSCopying, NSCoding>
@property (nonatomic) PDFBorderStyle style;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray *dashPattern;
@property (nonatomic, readonly, copy) NSDictionary *borderKeyValues PDFKIT_AVAILABLE(10_13, 11_0);
- (void)drawInRect:(PDFRect)rect;
@end

NS_ASSUME_NONNULL_END
