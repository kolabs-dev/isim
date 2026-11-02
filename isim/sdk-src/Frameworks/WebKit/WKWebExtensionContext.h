#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionPermission.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtension, WKWebExtensionController, WKWebExtensionMatchPattern, WKWebViewConfiguration;
WK_EXTERN NSErrorDomain const WKWebExtensionContextErrorDomain API_AVAILABLE(ios(18.4));
typedef NS_ERROR_ENUM(WKWebExtensionContextErrorDomain, WKWebExtensionContextError) {
    WKWebExtensionContextErrorUnknown = 1, WKWebExtensionContextErrorAlreadyLoaded, WKWebExtensionContextErrorNotLoaded,
    WKWebExtensionContextErrorBaseURLAlreadyInUse, WKWebExtensionContextErrorNoBackgroundContent, WKWebExtensionContextErrorBackgroundContentFailedToLoad,
} API_AVAILABLE(ios(18.4));
typedef NS_ENUM(NSInteger, WKWebExtensionContextPermissionStatus) {
    WKWebExtensionContextPermissionStatusDeniedExplicitly = -3, WKWebExtensionContextPermissionStatusDeniedImplicitly = -2,
    WKWebExtensionContextPermissionStatusRequestedImplicitly = -1, WKWebExtensionContextPermissionStatusUnknown = 0,
    WKWebExtensionContextPermissionStatusRequestedExplicitly = 1, WKWebExtensionContextPermissionStatusGrantedImplicitly = 2,
    WKWebExtensionContextPermissionStatusGrantedExplicitly = 3,
} API_AVAILABLE(ios(18.4));
/* an extension as the app runs it: the permissions and sites the app granted */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionContext : NSObject
+ (instancetype)contextForExtension:(WKWebExtension *)extension;
- (instancetype)initForExtension:(WKWebExtension *)extension;
@property (nonatomic, readonly, strong) WKWebExtension *webExtension;
@property (nonatomic, nullable, readonly, weak) WKWebExtensionController *webExtensionController;
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, copy) NSURL *baseURL;
@property (nonatomic, copy) NSString *uniqueIdentifier;
@property (nonatomic, getter=isInspectable) BOOL inspectable;
@property (nonatomic, nullable, copy) NSString *inspectionName;
@property (nonatomic, nullable, copy) NSSet<NSString *> *unsupportedAPIs;
@property (nonatomic, nullable, readonly, copy) WKWebViewConfiguration *webViewConfiguration;
@property (nonatomic, nullable, readonly, copy) NSURL *optionsPageURL;
@property (nonatomic, nullable, readonly, copy) NSURL *overrideNewTabPageURL;
@property (nonatomic, copy) NSDictionary<WKWebExtensionPermission, NSDate *> *grantedPermissions;
@property (nonatomic, copy) NSDictionary<WKWebExtensionMatchPattern *, NSDate *> *grantedPermissionMatchPatterns;
@property (nonatomic, copy) NSDictionary<WKWebExtensionPermission, NSDate *> *deniedPermissions;
@property (nonatomic, copy) NSDictionary<WKWebExtensionMatchPattern *, NSDate *> *deniedPermissionMatchPatterns;
@property (nonatomic, readonly) BOOL hasRequestedOptionalAccessToAllHosts;
@property (nonatomic) BOOL hasAccessToPrivateData;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionPermission> *currentPermissions;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionMatchPattern *> *currentPermissionMatchPatterns;
@property (nonatomic, readonly) BOOL hasAccessToAllURLs;
@property (nonatomic, readonly) BOOL hasAccessToAllHosts;
@property (nonatomic, readonly) BOOL hasInjectedContent;
@property (nonatomic, readonly) BOOL hasContentModificationRules;
- (BOOL)hasPermission:(WKWebExtensionPermission)permission;
- (BOOL)hasAccessToURL:(NSURL *)url;
- (BOOL)hasInjectedContentForURL:(NSURL *)url;
- (WKWebExtensionContextPermissionStatus)permissionStatusForPermission:(WKWebExtensionPermission)permission;
- (WKWebExtensionContextPermissionStatus)permissionStatusForMatchPattern:(WKWebExtensionMatchPattern *)pattern;
- (WKWebExtensionContextPermissionStatus)permissionStatusForURL:(NSURL *)url;
- (void)setPermissionStatus:(WKWebExtensionContextPermissionStatus)status forPermission:(WKWebExtensionPermission)permission expirationDate:(nullable NSDate *)expirationDate;
- (void)setPermissionStatus:(WKWebExtensionContextPermissionStatus)status forMatchPattern:(WKWebExtensionMatchPattern *)pattern expirationDate:(nullable NSDate *)expirationDate;
- (void)setPermissionStatus:(WKWebExtensionContextPermissionStatus)status forURL:(NSURL *)url expirationDate:(nullable NSDate *)expirationDate;
@end
NS_ASSUME_NONNULL_END
