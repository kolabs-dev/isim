#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKDownload;
typedef NS_ENUM(NSInteger, WKDownloadRedirectPolicy) { WKDownloadRedirectPolicyCancel, WKDownloadRedirectPolicyAllow };
@protocol WKDownloadDelegate <NSObject>
/* where to save the file (nil cancels the download) */
- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response suggestedFilename:(NSString *)suggestedFilename
        completionHandler:(void (^)(NSURL * _Nullable destination))completionHandler;
@optional
- (void)download:(WKDownload *)download willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
        decisionHandler:(void (^)(WKDownloadRedirectPolicy))decisionHandler;
- (void)download:(WKDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
        completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)downloadDidFinish:(WKDownload *)download;
- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(nullable NSData *)resumeData;
@end
NS_ASSUME_NONNULL_END
