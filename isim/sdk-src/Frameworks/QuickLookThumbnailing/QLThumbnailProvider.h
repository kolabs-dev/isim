#pragma once
#import <Foundation/Foundation.h>
#import <QuickLookThumbnailing/QLFileThumbnailRequest.h>
#import <QuickLookThumbnailing/QLThumbnailReply.h>
NS_ASSUME_NONNULL_BEGIN

/* a Thumbnail extension's principal class subclasses it */
API_AVAILABLE(ios(13.0))
@interface QLThumbnailProvider : NSObject
- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply *_Nullable reply, NSError *_Nullable error))handler
    NS_SWIFT_NAME(provideThumbnail(for:_:));
@end

NS_ASSUME_NONNULL_END
