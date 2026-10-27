#pragma once
#import <PDFKit/PDFKitPlatform.h>
NS_ASSUME_NONNULL_BEGIN

/* what happens when a link annotation or an outline item is activated (PDFView.performAction:) */
PDFKIT_CLASS_AVAILABLE(10_5, 11_0)
@interface PDFAction : NSObject <NSCopying>
@property (nonatomic, readonly) NSString *type;
@end

NS_ASSUME_NONNULL_END
