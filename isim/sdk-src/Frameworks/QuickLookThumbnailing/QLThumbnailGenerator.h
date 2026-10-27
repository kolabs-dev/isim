#pragma once
#import <Foundation/Foundation.h>
#import <QuickLookThumbnailing/QLThumbnailRepresentation.h>
#if !defined(__swift__)
#import <UniformTypeIdentifiers/UTType.h>
#endif
NS_ASSUME_NONNULL_BEGIN
@class QLThumbnailGenerationRequest;   /* QLThumbnailGenerationRequest.h (declared after the generator, whose Request it is) */

/* makes thumbnails (asynchronously, on a queue of its own; the handlers are called there) */
API_AVAILABLE(ios(13.0))
@interface QLThumbnailGenerator : NSObject
@property (class, readonly) QLThumbnailGenerator *sharedGenerator;
- (void)generateBestRepresentationForRequest:(QLThumbnailGenerationRequest *)request
                           completionHandler:(void (^)(QLThumbnailRepresentation *_Nullable thumbnail, NSError *_Nullable error))completionHandler
    NS_SWIFT_NAME(generateBestRepresentation(for:completion:));
- (void)generateRepresentationsForRequest:(QLThumbnailGenerationRequest *)request
                            updateHandler:(void (^_Nullable)(QLThumbnailRepresentation *_Nullable thumbnail, QLThumbnailRepresentationType type,
                                                             NSError *_Nullable error))updateHandler
    NS_SWIFT_NAME(generateRepresentations(for:update:));
- (void)cancelRequest:(QLThumbnailGenerationRequest *)request;
- (void)saveBestRepresentationForRequest:(QLThumbnailGenerationRequest *)request toFileAtURL:(NSURL *)fileURL
                         withContentType:(NSString *)contentType completionHandler:(void (^)(NSError *_Nullable error))completionHandler
    NS_SWIFT_NAME(saveBestRepresentation(for:to:contentType:completion:));
#if !defined(__swift__)
- (void)saveBestRepresentationForRequest:(QLThumbnailGenerationRequest *)request toFileAtURL:(NSURL *)fileURL asContentType:(UTType *)contentType
                       completionHandler:(void (^)(NSError *_Nullable error))completionHandler API_AVAILABLE(ios(14.0));
#endif
@end

NS_ASSUME_NONNULL_END
