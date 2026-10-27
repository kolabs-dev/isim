#pragma once
#import <PDFKit/PDFAction.h>
NS_ASSUME_NONNULL_BEGIN

PDFKIT_CLASS_AVAILABLE(10_5, 11_0)
@interface PDFActionResetForm : PDFAction <NSCopying>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@property (nonatomic, copy, nullable) NSArray<NSString *> *fields;
@property (nonatomic) BOOL fieldsIncludedAreCleared;
@end

NS_ASSUME_NONNULL_END
