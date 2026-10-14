#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKHTTPCookieStore;
@protocol WKHTTPCookieStoreObserver <NSObject>
@optional
- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore;
@end
@interface WKHTTPCookieStore : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (void)getAllCookies:(void (^)(NSArray<NSHTTPCookie *> *))completionHandler;
- (void)setCookie:(NSHTTPCookie *)cookie completionHandler:(nullable void (^)(void))completionHandler;
- (void)deleteCookie:(NSHTTPCookie *)cookie completionHandler:(nullable void (^)(void))completionHandler;
- (void)addObserver:(id<WKHTTPCookieStoreObserver>)observer;
- (void)removeObserver:(id<WKHTTPCookieStoreObserver>)observer;
@end
NS_ASSUME_NONNULL_END
