// isim WebKit for Objective-C: the C constants of WebKit's headers. The classes are the WebKit Swift overlay's
// (libswiftWebKit.dylib, which WebKit.framework re-exports); see sdk-src/Frameworks/WebKit/WebKit.h.
#import <WebKit/WebKit.h>

NSString * const WKErrorDomain = @"WKErrorDomain";
NSString * const WKJavaScriptExceptionMessageErrorKey = @"WKJavaScriptExceptionMessage";
NSString * const WKJavaScriptExceptionLineNumberErrorKey = @"WKJavaScriptExceptionLineNumber";
NSString * const WKJavaScriptExceptionColumnNumberErrorKey = @"WKJavaScriptExceptionColumnNumber";
NSString * const WKJavaScriptExceptionSourceURLErrorKey = @"WKJavaScriptExceptionSourceURL";

NSString * const WKWebsiteDataTypeFetchCache = @"WKWebsiteDataTypeFetchCache";
NSString * const WKWebsiteDataTypeDiskCache = @"WKWebsiteDataTypeDiskCache";
NSString * const WKWebsiteDataTypeMemoryCache = @"WKWebsiteDataTypeMemoryCache";
NSString * const WKWebsiteDataTypeOfflineWebApplicationCache = @"WKWebsiteDataTypeOfflineWebApplicationCache";
NSString * const WKWebsiteDataTypeCookies = @"WKWebsiteDataTypeCookies";
NSString * const WKWebsiteDataTypeSessionStorage = @"WKWebsiteDataTypeSessionStorage";
NSString * const WKWebsiteDataTypeLocalStorage = @"WKWebsiteDataTypeLocalStorage";
NSString * const WKWebsiteDataTypeWebSQLDatabases = @"WKWebsiteDataTypeWebSQLDatabases";
NSString * const WKWebsiteDataTypeIndexedDBDatabases = @"WKWebsiteDataTypeIndexedDBDatabases";
NSString * const WKWebsiteDataTypeServiceWorkerRegistrations = @"WKWebsiteDataTypeServiceWorkerRegistrations";
NSString * const WKWebsiteDataTypeFileSystem = @"WKWebsiteDataTypeFileSystem";
NSString * const WKWebsiteDataTypeSearchFieldRecentSearches = @"WKWebsiteDataTypeSearchFieldRecentSearches";
NSString * const WKWebsiteDataTypeMediaKeys = @"WKWebsiteDataTypeMediaKeys";
NSString * const WKWebsiteDataTypeHashSalt = @"WKWebsiteDataTypeHashSalt";
