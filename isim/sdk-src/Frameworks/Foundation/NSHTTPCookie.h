#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSString, NSDate, NSNumber, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>;
typedef NSString *NSHTTPCookiePropertyKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *NSHTTPCookieStringPolicy NS_TYPED_ENUM;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieName;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieValue;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieOriginURL;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieVersion;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieDomain;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookiePath;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieSecure;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieExpires;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieComment;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieCommentURL;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieDiscard;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieMaximumAge;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookiePort;
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieSameSitePolicy;
FOUNDATION_EXPORT NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteLax;
FOUNDATION_EXPORT NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteStrict;
ISIM_RUNTIME_VISIBLE
@interface NSHTTPCookie : NSObject
- (nullable instancetype)initWithProperties:(NSDictionary<NSHTTPCookiePropertyKey, id> *)properties;
+ (nullable NSHTTPCookie *)cookieWithProperties:(NSDictionary<NSHTTPCookiePropertyKey, id> *)properties;
+ (NSDictionary<NSString *, NSString *> *)requestHeaderFieldsWithCookies:(NSArray<NSHTTPCookie *> *)cookies;
+ (NSArray<NSHTTPCookie *> *)cookiesWithResponseHeaderFields:(NSDictionary<NSString *, NSString *> *)headerFields forURL:(NSURL *)URL;
@property (nullable, readonly, copy) NSDictionary<NSHTTPCookiePropertyKey, id> *properties;
@property (readonly) NSUInteger version;
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *value;
@property (nullable, readonly, copy) NSDate *expiresDate;
@property (readonly, getter=isSessionOnly) BOOL sessionOnly;
@property (readonly, copy) NSString *domain;
@property (readonly, copy) NSString *path;
@property (readonly, getter=isSecure) BOOL secure;
@property (readonly, getter=isHTTPOnly) BOOL HTTPOnly;
@property (nullable, readonly, copy) NSString *comment;
@property (nullable, readonly, copy) NSURL *commentURL;
@property (nullable, readonly, copy) NSArray<NSNumber *> *portList;
@property (nullable, readonly, copy) NSHTTPCookieStringPolicy sameSitePolicy;
@end
NS_ASSUME_NONNULL_END
#endif
