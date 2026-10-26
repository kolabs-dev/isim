#pragma once
/* a data-based preview extension's answer (issue #333): data of a content type, a PDF document, a drawing (a bitmap or
 * vector context) or a file. Adapted: isim turns it into a file its QLPreviewController shows (the data with its
 * type's filename extension, the PDF, a PNG of the drawing) and the title names the item. The UTType methods are
 * Objective-C only; Swift gets UTType versions from isim's QuickLook overlay. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#if !defined(__swift__)
#import <UniformTypeIdentifiers/UTType.h>
#endif
NS_ASSUME_NONNULL_BEGIN

@class PDFDocument;

API_AVAILABLE(ios(15.0))
@interface QLPreviewReplyAttachment : NSObject
@property (readonly) NSData *data;
#if !defined(__swift__)
@property (readonly) UTType *contentType;
- (instancetype)initWithData:(NSData *)data contentType:(UTType *)contentType;
#endif
/* isim: what the overlay's contentType and init(data:contentType:) use */
@property (readonly) NSString *_isimContentTypeIdentifier NS_SWIFT_NAME(_isimContentTypeIdentifier);
- (instancetype)initWithData:(NSData *)data isimContentTypeIdentifier:(NSString *)identifier NS_SWIFT_NAME(init(data:_isimContentTypeIdentifier:));
@end

API_AVAILABLE(ios(15.0))
@interface QLPreviewReply : NSObject
@property NSStringEncoding stringEncoding NS_REFINED_FOR_SWIFT;
@property (copy) NSDictionary<NSString *, QLPreviewReplyAttachment *> *attachments;
@property (copy) NSString *title;
- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (instancetype)initWithContextSize:(CGSize)contextSize isBitmap:(BOOL)isBitmap
                       drawingBlock:(BOOL (^)(CGContextRef context, QLPreviewReply *replyToUpdate, NSError **error))drawingBlock NS_REFINED_FOR_SWIFT;
- (instancetype)initForPDFWithPageSize:(CGSize)defaultPageSize
                 documentCreationBlock:(PDFDocument *_Nullable (^)(QLPreviewReply *replyToUpdate, NSError **error))documentCreationBlock NS_REFINED_FOR_SWIFT;
#if !defined(__swift__)
- (instancetype)initWithDataOfContentType:(UTType *)contentType contentSize:(CGSize)contentSize
                        dataCreationBlock:(NSData *_Nullable (^)(QLPreviewReply *replyToUpdate, NSError **error))dataCreationBlock;
#endif
/* isim: what the overlay's init(dataOfContentType:contentSize:createDataUsing:) calls */
- (instancetype)initWithIsimContentTypeIdentifier:(NSString *)identifier contentSize:(CGSize)contentSize
                                dataCreationBlock:(NSData *_Nullable (^)(QLPreviewReply *replyToUpdate, NSError **error))dataCreationBlock NS_REFINED_FOR_SWIFT;
@end

NS_ASSUME_NONNULL_END
