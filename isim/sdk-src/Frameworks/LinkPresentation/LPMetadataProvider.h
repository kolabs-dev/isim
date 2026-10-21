#pragma once
#import <Foundation/Foundation.h>
#if !defined(__swift__)
@class LPLinkMetadata;
NS_ASSUME_NONNULL_BEGIN
/* one fetch per provider; the completion handler runs on a background queue */
API_AVAILABLE(ios(13.0))
@interface LPMetadataProvider : NSObject
- (void)startFetchingMetadataForURL:(NSURL *)URL
                  completionHandler:(void (^)(LPLinkMetadata * _Nullable metadata, NSError * _Nullable error))completionHandler;
- (void)startFetchingMetadataForRequest:(NSURLRequest *)request
                      completionHandler:(void (^)(LPLinkMetadata * _Nullable metadata, NSError * _Nullable error))completionHandler
    API_AVAILABLE(ios(15.0));
- (void)cancel;
@property (nonatomic) BOOL shouldFetchSubresources;
@property (nonatomic) NSTimeInterval timeout;
@end
NS_ASSUME_NONNULL_END

#endif
