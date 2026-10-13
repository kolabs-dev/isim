#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
WK_EXTERN NSString * const WKWebsiteDataTypeFetchCache;
WK_EXTERN NSString * const WKWebsiteDataTypeDiskCache;
WK_EXTERN NSString * const WKWebsiteDataTypeMemoryCache;
WK_EXTERN NSString * const WKWebsiteDataTypeOfflineWebApplicationCache;
WK_EXTERN NSString * const WKWebsiteDataTypeCookies;
WK_EXTERN NSString * const WKWebsiteDataTypeSessionStorage;
WK_EXTERN NSString * const WKWebsiteDataTypeLocalStorage;
WK_EXTERN NSString * const WKWebsiteDataTypeWebSQLDatabases;
WK_EXTERN NSString * const WKWebsiteDataTypeIndexedDBDatabases;
WK_EXTERN NSString * const WKWebsiteDataTypeServiceWorkerRegistrations;
WK_EXTERN NSString * const WKWebsiteDataTypeFileSystem;
WK_EXTERN NSString * const WKWebsiteDataTypeSearchFieldRecentSearches;
WK_EXTERN NSString * const WKWebsiteDataTypeMediaKeys;
WK_EXTERN NSString * const WKWebsiteDataTypeHashSalt;
@interface WKWebsiteDataRecord : NSObject
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy) NSSet<NSString *> *dataTypes;
@end
NS_ASSUME_NONNULL_END
