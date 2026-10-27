#pragma once
#import <PDFKit/PDFAction.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PDFActionNamedName) {
    kPDFActionNamedNone = 0, kPDFActionNamedNextPage = 1, kPDFActionNamedPreviousPage = 2, kPDFActionNamedFirstPage = 3,
    kPDFActionNamedLastPage = 4, kPDFActionNamedGoBack = 5, kPDFActionNamedGoForward = 6, kPDFActionNamedGoToPage = 7,
    kPDFActionNamedFind = 8, kPDFActionNamedPrint = 9, kPDFActionNamedZoomIn = 10, kPDFActionNamedZoomOut = 11
} PDFKIT_AVAILABLE(10_5, 11_0);

PDFKIT_CLASS_AVAILABLE(10_5, 11_0)
@interface PDFActionNamed : PDFAction <NSCopying>
- (instancetype)initWithName:(PDFActionNamedName)name;
@property (nonatomic) PDFActionNamedName name;
@end

NS_ASSUME_NONNULL_END
