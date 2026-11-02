#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionPermission.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtensionMatchPattern;
WK_EXTERN NSErrorDomain const WKWebExtensionErrorDomain API_AVAILABLE(ios(18.4));
typedef NS_ERROR_ENUM(WKWebExtensionErrorDomain, WKWebExtensionError) {
    WKWebExtensionErrorUnknown = 1, WKWebExtensionErrorResourceNotFound, WKWebExtensionErrorInvalidResourceCodeSignature,
    WKWebExtensionErrorInvalidManifest, WKWebExtensionErrorUnsupportedManifestVersion, WKWebExtensionErrorInvalidManifestEntry,
    WKWebExtensionErrorInvalidDeclarativeNetRequestEntry, WKWebExtensionErrorInvalidBackgroundPersistence, WKWebExtensionErrorInvalidArchive,
} API_AVAILABLE(ios(18.4));
/* a web extension: its manifest.json and resources (isim: content scripts only; see the Swift overlay's WebExtension.swift) */
API_AVAILABLE(ios(18.4))
@interface WKWebExtension : NSObject
+ (void)extensionWithAppExtensionBundle:(NSBundle *)appExtensionBundle completionHandler:(void (^)(WKWebExtension * _Nullable extension, NSError * _Nullable error))completionHandler;
+ (void)extensionWithResourceBaseURL:(NSURL *)resourceBaseURL completionHandler:(void (^)(WKWebExtension * _Nullable extension, NSError * _Nullable error))completionHandler;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *manifest;
@property (nonatomic, readonly) double manifestVersion;
- (BOOL)supportsManifestVersion:(double)manifestVersion;
@property (nonatomic, nullable, readonly, copy) NSLocale *defaultLocale;
@property (nonatomic, nullable, readonly, copy) NSString *displayName;
@property (nonatomic, nullable, readonly, copy) NSString *displayShortName;
@property (nonatomic, nullable, readonly, copy) NSString *displayVersion;
@property (nonatomic, nullable, readonly, copy) NSString *displayDescription;
@property (nonatomic, nullable, readonly, copy) NSString *displayActionLabel;
@property (nonatomic, nullable, readonly, copy) NSString *version;
- (nullable UIImage *)iconForSize:(CGSize)size;
- (nullable UIImage *)actionIconForSize:(CGSize)size;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *requestedPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *optionalPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *requestedPermissionMatchPatterns;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *optionalPermissionMatchPatterns;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *allRequestedMatchPatterns;
@property (nonatomic, readonly) BOOL hasBackgroundContent;
@property (nonatomic, readonly) BOOL hasPersistentBackgroundContent;
@property (nonatomic, readonly) BOOL hasInjectedContent;
@property (nonatomic, readonly) BOOL hasOptionsPage;
@property (nonatomic, readonly) BOOL hasOverrideNewTabPage;
@property (nonatomic, readonly) BOOL hasCommands;
@property (nonatomic, readonly) BOOL hasContentModificationRules;
@end
NS_ASSUME_NONNULL_END
