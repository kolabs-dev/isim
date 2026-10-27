#pragma once
/* isim Foundation (self-authored, Apple's declarations and values): NSURLConnection, the URL loading API before
   NSURLSession. Adapted: a connection runs an NSURLSession task (the same protocols, cookies, cache and authentication)
   and calls its delegate on the run loops it is scheduled on (by default the run loop that started it, default mode) or on
   its delegate queue. NSURLConnectionDownloadDelegate (Newsstand) downloads to a temporary file. Objective-C only, like
   isim's other URL loading headers (the URL classes are Swift overlay classes; this header is hidden from Swift). */
#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLResponse.h>
#import <Foundation/NSURLCache.h>
#import <Foundation/NSURLAuthenticationChallenge.h>
#import <Foundation/NSURLProtectionSpace.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSStream.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSError, NSData;

@interface NSURLConnection : NSObject
- (nullable instancetype)initWithRequest:(NSURLRequest *)request delegate:(nullable id)delegate startImmediately:(BOOL)startImmediately;
- (nullable instancetype)initWithRequest:(NSURLRequest *)request delegate:(nullable id)delegate;
+ (nullable NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(nullable id)delegate;
@property (readonly, copy) NSURLRequest *originalRequest;
@property (readonly, copy) NSURLRequest *currentRequest;
- (void)start;
- (void)cancel;
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode;
- (void)setDelegateQueue:(nullable NSOperationQueue *)queue;
+ (BOOL)canHandleRequest:(NSURLRequest *)request;
@end

@protocol NSURLConnectionDelegate <NSObject>
@optional
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace;
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
@end

@protocol NSURLConnectionDataDelegate <NSURLConnectionDelegate>
@optional
- (nullable NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request
                     redirectResponse:(nullable NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (nullable NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request;
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten
    totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite;
- (nullable NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
@end

@protocol NSURLConnectionDownloadDelegate <NSURLConnectionDelegate>
@optional
- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten
    expectedTotalBytes:(long long)expectedTotalBytes;
- (void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten
                    expectedTotalBytes:(long long)expectedTotalBytes;
@required
- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *)destinationURL;
@end

@interface NSURLConnection (NSURLConnectionSynchronousLoading)
+ (nullable NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse *_Nullable *_Nullable)response
                                      error:(NSError **)error;
@end
@interface NSURLConnection (NSURLConnectionQueuedLoading)
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue
              completionHandler:(void (^)(NSURLResponse *_Nullable response, NSData *_Nullable data, NSError *_Nullable connectionError))handler;
@end

NS_ASSUME_NONNULL_END
#endif
