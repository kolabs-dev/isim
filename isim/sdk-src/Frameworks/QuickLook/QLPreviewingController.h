#pragma once
/* Quick Look Preview extensions (com.apple.quicklook.preview, issue #333): a view controller conforming to
 * QLPreviewingController (view-based: preparePreviewOfFileAtURL:completionHandler:) or a QLPreviewProvider subclass
 * (data-based: providePreviewForFileRequest:completionHandler:). Adapted: QLPreviewController loads the extension into
 * the previewing app (iOS runs it in a process of its own) for the types its QLSupportedContentTypes list. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN

@class QLFilePreviewRequest, QLPreviewReply;

API_AVAILABLE(ios(11.0))
@protocol QLPreviewingController <NSObject>
@optional
- (void)preparePreviewOfSearchableItemWithIdentifier:(NSString *)identifier queryString:(nullable NSString *)queryString
                                   completionHandler:(void (^)(NSError *_Nullable error))handler
    NS_SWIFT_NAME(preparePreviewOfSearchableItem(identifier:queryString:completionHandler:));
- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError *_Nullable error))handler
    NS_SWIFT_NAME(preparePreviewOfFile(at:completionHandler:));
- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request completionHandler:(void (^)(QLPreviewReply *_Nullable reply, NSError *_Nullable error))handler
    API_AVAILABLE(ios(15.0)) NS_SWIFT_NAME(providePreview(for:completionHandler:));
@end

NS_ASSUME_NONNULL_END
