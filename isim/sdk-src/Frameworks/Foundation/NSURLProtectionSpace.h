#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSData, NSArray<ObjectType>;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceHTTP;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceHTTPS;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceFTP;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceHTTPProxy;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceHTTPSProxy;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceFTPProxy;
FOUNDATION_EXPORT NSString *const NSURLProtectionSpaceSOCKSProxy;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodDefault;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodHTTPBasic;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodHTTPDigest;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodHTMLForm;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodNTLM;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodNegotiate;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodClientCertificate;
FOUNDATION_EXPORT NSString *const NSURLAuthenticationMethodServerTrust;
ISIM_RUNTIME_VISIBLE
@interface NSURLProtectionSpace : NSObject
- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port protocol:(nullable NSString *)protocol realm:(nullable NSString *)realm
        authenticationMethod:(nullable NSString *)authenticationMethod;
@property (nullable, readonly, copy) NSString *realm;
@property (readonly) BOOL receivesCredentialSecurely;
@property (readonly, copy) NSString *host;
@property (readonly) NSInteger port;
@property (nullable, readonly, copy) NSString *proxyType;
@property (nullable, readonly, copy) NSString *protocol;
@property (readonly, copy) NSString *authenticationMethod;
@property (nullable, readonly, copy) NSArray<NSData *> *distinguishedNames;
@end
NS_ASSUME_NONNULL_END
#endif
