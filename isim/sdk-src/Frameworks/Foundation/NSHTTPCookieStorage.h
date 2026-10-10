#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSHTTPCookie, NSURL, NSDate, NSString, NSArray<ObjectType>, NSSortDescriptor;
typedef NS_ENUM(NSUInteger, NSHTTPCookieAcceptPolicy) {
    NSHTTPCookieAcceptPolicyAlways, NSHTTPCookieAcceptPolicyNever, NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain,
};
FOUNDATION_EXPORT NSString *const NSHTTPCookieManagerAcceptPolicyChangedNotification;
FOUNDATION_EXPORT NSString *const NSHTTPCookieManagerCookiesChangedNotification;
ISIM_RUNTIME_VISIBLE
@interface NSHTTPCookieStorage : NSObject
@property (class, readonly, strong) NSHTTPCookieStorage *sharedHTTPCookieStorage;
+ (NSHTTPCookieStorage *)sharedCookieStorageForGroupContainerIdentifier:(NSString *)identifier;
@property (nullable, readonly, copy) NSArray<NSHTTPCookie *> *cookies;
- (void)setCookie:(NSHTTPCookie *)cookie;
- (void)deleteCookie:(NSHTTPCookie *)cookie;
- (void)removeCookiesSinceDate:(NSDate *)date;
- (nullable NSArray<NSHTTPCookie *> *)cookiesForURL:(NSURL *)URL;
- (void)setCookies:(NSArray<NSHTTPCookie *> *)cookies forURL:(nullable NSURL *)URL mainDocumentURL:(nullable NSURL *)mainDocumentURL;
@property NSHTTPCookieAcceptPolicy cookieAcceptPolicy;
- (NSArray<NSHTTPCookie *> *)sortedCookiesUsingDescriptors:(NSArray<NSSortDescriptor *> *)sortOrder;
@end
NS_ASSUME_NONNULL_END
#endif
