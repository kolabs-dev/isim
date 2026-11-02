#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
WK_EXTERN NSErrorDomain const WKWebExtensionMatchPatternErrorDomain API_AVAILABLE(ios(18.4));
typedef NS_ERROR_ENUM(WKWebExtensionMatchPatternErrorDomain, WKWebExtensionMatchPatternError) {
    WKWebExtensionMatchPatternErrorUnknown = 1, WKWebExtensionMatchPatternErrorInvalidScheme, WKWebExtensionMatchPatternErrorInvalidHost,
    WKWebExtensionMatchPatternErrorInvalidPath,
} API_AVAILABLE(ios(18.4));
typedef NS_OPTIONS(NSUInteger, WKWebExtensionMatchPatternOptions) {
    WKWebExtensionMatchPatternOptionsNone = 0, WKWebExtensionMatchPatternOptionsIgnoreSchemes = 1 << 0,
    WKWebExtensionMatchPatternOptionsIgnorePaths = 1 << 1, WKWebExtensionMatchPatternOptionsMatchBidirectionally = 1 << 2,
} API_AVAILABLE(ios(18.4));
/* a web extension match pattern (<all_urls>, scheme://host/path with * wildcards) */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionMatchPattern : NSObject <NSSecureCoding, NSCopying>
+ (void)registerCustomURLScheme:(NSString *)urlScheme;
+ (instancetype)allURLsMatchPattern NS_SWIFT_NAME(allURLs());
+ (instancetype)allHostsAndSchemesMatchPattern NS_SWIFT_NAME(allHostsAndSchemes());
- (nullable instancetype)initWithString:(NSString *)string error:(NSError **)error;
- (nullable instancetype)initWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path error:(NSError **)error;
@property (nonatomic, readonly, copy) NSString *string;
@property (nonatomic, nullable, readonly, copy) NSString *scheme;
@property (nonatomic, nullable, readonly, copy) NSString *host;
@property (nonatomic, nullable, readonly, copy) NSString *path;
@property (nonatomic, readonly) BOOL matchesAllURLs;
@property (nonatomic, readonly) BOOL matchesAllHosts;
- (BOOL)matchesURL:(nullable NSURL *)url;
- (BOOL)matchesURL:(nullable NSURL *)url options:(WKWebExtensionMatchPatternOptions)options;
- (BOOL)matchesPattern:(nullable WKWebExtensionMatchPattern *)pattern;
- (BOOL)matchesPattern:(nullable WKWebExtensionMatchPattern *)pattern options:(WKWebExtensionMatchPatternOptions)options;
@end
NS_ASSUME_NONNULL_END
