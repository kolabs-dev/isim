#pragma once
#import <PDFKit/PDFAction.h>
NS_ASSUME_NONNULL_BEGIN
@class PDFDestination;

PDFKIT_CLASS_AVAILABLE(10_5, 11_0)
@interface PDFActionGoTo : PDFAction <NSCopying>
- (instancetype)initWithDestination:(PDFDestination *)destination;
@property (nonatomic, strong) PDFDestination *destination;
@end

NS_ASSUME_NONNULL_END
