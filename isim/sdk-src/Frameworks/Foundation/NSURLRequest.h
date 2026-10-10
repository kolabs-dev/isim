#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSString, NSData, NSDictionary<KeyType, ObjectType>;
typedef NS_ENUM(NSUInteger, NSURLRequestCachePolicy) {
    NSURLRequestUseProtocolCachePolicy = 0, NSURLRequestReloadIgnoringLocalCacheData = 1, NSURLRequestReloadIgnoringLocalAndRemoteCacheData = 4,
    NSURLRequestReloadIgnoringCacheData = NSURLRequestReloadIgnoringLocalCacheData, NSURLRequestReturnCacheDataElseLoad = 2,
    NSURLRequestReturnCacheDataDontLoad = 3, NSURLRequestReloadRevalidatingCacheData = 5,
};
typedef NS_ENUM(NSUInteger, NSURLRequestNetworkServiceType) {
    NSURLNetworkServiceTypeDefault = 0, NSURLNetworkServiceTypeVoIP = 1, NSURLNetworkServiceTypeVideo = 2, NSURLNetworkServiceTypeBackground = 3,
    NSURLNetworkServiceTypeVoice = 4, NSURLNetworkServiceTypeResponsiveData = 6, NSURLNetworkServiceTypeAVStreaming = 8,
    NSURLNetworkServiceTypeResponsiveAV = 9, NSURLNetworkServiceTypeCallSignaling = 11,
};
ISIM_RUNTIME_VISIBLE
@interface NSURLRequest : NSObject <NSCopying, NSMutableCopying>
+ (instancetype)requestWithURL:(NSURL *)URL;
+ (instancetype)requestWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval;
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval;
@property (class, readonly) BOOL supportsSecureCoding;
@property (nullable, readonly, copy) NSURL *URL;
@property (readonly) NSURLRequestCachePolicy cachePolicy;
@property (readonly) NSTimeInterval timeoutInterval;
@property (nullable, readonly, copy) NSURL *mainDocumentURL;
@property (readonly) NSURLRequestNetworkServiceType networkServiceType;
@property (readonly) BOOL allowsCellularAccess;
@property (readonly) BOOL allowsExpensiveNetworkAccess;
@property (readonly) BOOL allowsConstrainedNetworkAccess;
@property (readonly) BOOL assumesHTTP3Capable;
@property (nullable, readonly, copy) NSString *HTTPMethod;
@property (nullable, readonly, copy) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;
- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field;
@property (nullable, readonly, copy) NSData *HTTPBody;
@property (readonly) BOOL HTTPShouldHandleCookies;
@property (readonly) BOOL HTTPShouldUsePipelining;
@end

ISIM_RUNTIME_VISIBLE
@interface NSMutableURLRequest : NSURLRequest
@property (nullable, copy) NSURL *URL;
@property NSURLRequestCachePolicy cachePolicy;
@property NSTimeInterval timeoutInterval;
@property (nullable, copy) NSURL *mainDocumentURL;
@property NSURLRequestNetworkServiceType networkServiceType;
@property BOOL allowsCellularAccess;
@property BOOL allowsExpensiveNetworkAccess;
@property BOOL allowsConstrainedNetworkAccess;
@property BOOL assumesHTTP3Capable;
@property (copy) NSString *HTTPMethod;
@property (nullable, copy) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(NSString *)field;
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field;
@property (nullable, copy) NSData *HTTPBody;
@property BOOL HTTPShouldHandleCookies;
@property BOOL HTTPShouldUsePipelining;
@end
NS_ASSUME_NONNULL_END
#endif
