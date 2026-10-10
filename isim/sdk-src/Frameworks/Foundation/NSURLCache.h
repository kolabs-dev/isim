#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURLResponse, NSURLRequest, NSData, NSDate, NSString, NSURL, NSDictionary;
typedef NS_ENUM(NSUInteger, NSURLCacheStoragePolicy) { NSURLCacheStorageAllowed, NSURLCacheStorageAllowedInMemoryOnly, NSURLCacheStorageNotAllowed };
ISIM_RUNTIME_VISIBLE
@interface NSCachedURLResponse : NSObject
- (instancetype)initWithResponse:(NSURLResponse *)response data:(NSData *)data;
- (instancetype)initWithResponse:(NSURLResponse *)response data:(NSData *)data userInfo:(nullable NSDictionary *)userInfo storagePolicy:(NSURLCacheStoragePolicy)storagePolicy;
@property (readonly, copy) NSURLResponse *response;
@property (readonly, copy) NSData *data;
@property (nullable, readonly, copy) NSDictionary *userInfo;
@property (readonly) NSURLCacheStoragePolicy storagePolicy;
@end

ISIM_RUNTIME_VISIBLE
@interface NSURLCache : NSObject
@property (class, strong) NSURLCache *sharedURLCache;
- (instancetype)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(nullable NSString *)path;
- (instancetype)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity directoryURL:(nullable NSURL *)directoryURL;
- (nullable NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request;
- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request;
- (void)removeCachedResponseForRequest:(NSURLRequest *)request;
- (void)removeAllCachedResponses;
- (void)removeCachedResponsesSinceDate:(NSDate *)date;
@property NSUInteger memoryCapacity;
@property NSUInteger diskCapacity;
@property (readonly) NSUInteger currentMemoryUsage;
@property (readonly) NSUInteger currentDiskUsage;
@end
NS_ASSUME_NONNULL_END
#endif
