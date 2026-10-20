#pragma once
#import <Foundation/NSObject.h>
/* isim: URL protocols. NSURLProtocol is an Objective-C class of Foundation, so Objective-C apps subclass it as on iOS;
   Swift's URLProtocol (the overlay) is its subclass with the Swift-typed API. URLSession (the overlay) asks every
   protocol class through the runtime, so subclasses of either work. */
NS_ASSUME_NONNULL_BEGIN
#if defined(__swift__)
/* what the overlay builds URLProtocol on (requests and clients are Swift types there) */
NS_SWIFT_NAME(_URLProtocolBase)
@interface NSURLProtocol : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIsimRequest:(id)request cachedResponse:(nullable id)cachedResponse client:(nullable id)client
    NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(_isimRequest:cachedResponse:client:));
- (void)startLoading;
- (void)stopLoading;
+ (BOOL)registerClass:(Class)protocolClass;
+ (void)unregisterClass:(Class)protocolClass;
@end
#else
NS_ASSUME_NONNULL_END
#import <Foundation/NSURLAuthenticationChallenge.h>
#import <Foundation/NSURLCache.h>
NS_ASSUME_NONNULL_BEGIN
@class NSURLRequest, NSMutableURLRequest, NSURLResponse, NSCachedURLResponse, NSURLSessionTask, NSError, NSData, NSString, NSURLProtocol;

@protocol NSURLProtocolClient <NSObject>
- (void)URLProtocol:(NSURLProtocol *)protocol wasRedirectedToRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse;
- (void)URLProtocol:(NSURLProtocol *)protocol cachedResponseIsValid:(NSCachedURLResponse *)cachedResponse;
- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveResponse:(NSURLResponse *)response cacheStoragePolicy:(NSURLCacheStoragePolicy)policy;
- (void)URLProtocol:(NSURLProtocol *)protocol didLoadData:(NSData *)data;
- (void)URLProtocolDidFinishLoading:(NSURLProtocol *)protocol;
- (void)URLProtocol:(NSURLProtocol *)protocol didFailWithError:(NSError *)error;
- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)URLProtocol:(NSURLProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
@end

@interface NSURLProtocol : NSObject
- (instancetype)initWithRequest:(NSURLRequest *)request cachedResponse:(nullable NSCachedURLResponse *)cachedResponse
                         client:(nullable id<NSURLProtocolClient>)client NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithTask:(NSURLSessionTask *)task cachedResponse:(nullable NSCachedURLResponse *)cachedResponse
                      client:(nullable id<NSURLProtocolClient>)client;
@property (nullable, readonly, retain) id<NSURLProtocolClient> client;
@property (readonly, copy) NSURLRequest *request;
@property (nullable, readonly, copy) NSCachedURLResponse *cachedResponse;
@property (nullable, readonly, copy) NSURLSessionTask *task;
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
+ (BOOL)canInitWithTask:(NSURLSessionTask *)task;
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b;
- (void)startLoading;
- (void)stopLoading;
+ (nullable id)propertyForKey:(NSString *)key inRequest:(NSURLRequest *)request;
+ (void)setProperty:(id)value forKey:(NSString *)key inRequest:(NSMutableURLRequest *)request;
+ (void)removePropertyForKey:(NSString *)key inRequest:(NSMutableURLRequest *)request;
+ (BOOL)registerClass:(Class)protocolClass;
+ (void)unregisterClass:(Class)protocolClass;
@end
#endif
/* isim, for URLSession (the overlay): the registered classes (the latest first), and a protocol class asked through the runtime */
FOUNDATION_EXPORT NSArray *isim_url_protocol_registered(void) NS_SWIFT_NAME(_isimURLProtocolRegistered());
FOUNDATION_EXPORT BOOL isim_url_protocol_can_init(Class cls, id task) NS_SWIFT_NAME(_isimURLProtocolCanInit(_:_:));
FOUNDATION_EXPORT id isim_url_protocol_canonical(Class cls, id request) NS_SWIFT_NAME(_isimURLProtocolCanonical(_:_:));
FOUNDATION_EXPORT NSURLProtocol *isim_url_protocol_create(Class cls, id task, id _Nullable cachedResponse, id client)
    NS_RETURNS_RETAINED NS_SWIFT_NAME(_isimURLProtocolCreate(_:_:_:_:));
NS_ASSUME_NONNULL_END
