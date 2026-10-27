#pragma once
#import <PDFKit/PDFAction.h>
NS_ASSUME_NONNULL_BEGIN

PDFKIT_CLASS_AVAILABLE(10_5, 11_0)
@interface PDFActionRemoteGoTo : PDFAction <NSCopying>
- (instancetype)initWithPageIndex:(NSUInteger)pageIndex atPoint:(PDFPoint)point fileURL:(NSURL *)url;
@property (nonatomic) NSUInteger pageIndex;
@property (nonatomic) PDFPoint point;
@property (nonatomic, copy) NSURL *URL;
@end

NS_ASSUME_NONNULL_END
