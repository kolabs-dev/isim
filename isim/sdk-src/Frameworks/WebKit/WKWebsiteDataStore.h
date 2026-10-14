#pragma once
#import <WebKit/WKWebsiteDataRecord.h>
NS_ASSUME_NONNULL_BEGIN
@class WKHTTPCookieStore;
@interface WKWebsiteDataStore : NSObject
+ (WKWebsiteDataStore *)defaultDataStore;
+ (WKWebsiteDataStore *)nonPersistentDataStore;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, getter=isPersistent) BOOL persistent;
+ (NSSet<NSString *> *)allWebsiteDataTypes;
- (void)fetchDataRecordsOfTypes:(NSSet<NSString *> *)dataTypes completionHandler:(void (^)(NSArray<WKWebsiteDataRecord *> *))completionHandler;
- (void)removeDataOfTypes:(NSSet<NSString *> *)dataTypes forDataRecords:(NSArray<WKWebsiteDataRecord *> *)dataRecords completionHandler:(void (^)(void))completionHandler;
- (void)removeDataOfTypes:(NSSet<NSString *> *)dataTypes modifiedSince:(NSDate *)date completionHandler:(void (^)(void))completionHandler;
@property (nonatomic, readonly) WKHTTPCookieStore *httpCookieStore;
@end
NS_ASSUME_NONNULL_END
