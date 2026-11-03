#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionPermission.h>
#import <WebKit/WKWebExtensionTab.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtension, WKWebExtensionController, WKWebExtensionMatchPattern, WKWebViewConfiguration, WKWebExtensionAction, WKWebExtensionCommand;
@class UIKeyCommand, UIMenuElement;
@protocol WKWebExtensionWindow;
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
WK_EXTERN NSNotificationName const WKWebExtensionContextErrorsDidUpdateNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextPermissionsWereGrantedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextPermissionsWereDeniedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextGrantedPermissionsWereRemovedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextDeniedPermissionsWereRemovedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextPermissionMatchPatternsWereGrantedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextPermissionMatchPatternsWereDeniedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextGrantedPermissionMatchPatternsWereRemovedNotification API_AVAILABLE(ios(18.4));
WK_EXTERN NSNotificationName const WKWebExtensionContextDeniedPermissionMatchPatternsWereRemovedNotification API_AVAILABLE(ios(18.4));
typedef NSString *WKWebExtensionContextNotificationUserInfoKey NS_TYPED_EXTENSIBLE_ENUM API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionContextNotificationUserInfoKey const WKWebExtensionContextNotificationUserInfoKeyPermissions API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionContextNotificationUserInfoKey const WKWebExtensionContextNotificationUserInfoKeyMatchPatterns API_AVAILABLE(ios(18.4));
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
/* issue #791: tabs and windows, actions, commands, background content, user gestures */
- (BOOL)hasPermission:(WKWebExtensionPermission)permission inTab:(nullable id <WKWebExtensionTab>)tab;
- (BOOL)hasAccessToURL:(NSURL *)url inTab:(nullable id <WKWebExtensionTab>)tab;
- (WKWebExtensionContextPermissionStatus)permissionStatusForPermission:(WKWebExtensionPermission)permission inTab:(nullable id <WKWebExtensionTab>)tab;
- (WKWebExtensionContextPermissionStatus)permissionStatusForURL:(NSURL *)url inTab:(nullable id <WKWebExtensionTab>)tab;
- (WKWebExtensionContextPermissionStatus)permissionStatusForMatchPattern:(WKWebExtensionMatchPattern *)pattern inTab:(nullable id <WKWebExtensionTab>)tab;
- (void)loadBackgroundContentWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (nullable WKWebExtensionAction *)actionForTab:(nullable id <WKWebExtensionTab>)tab;
- (void)performActionForTab:(nullable id <WKWebExtensionTab>)tab;
@property (nonatomic, readonly, copy) NSArray<WKWebExtensionCommand *> *commands;
- (void)performCommand:(WKWebExtensionCommand *)command;
- (BOOL)performCommandForKeyCommand:(UIKeyCommand *)keyCommand;
- (NSArray<UIMenuElement *> *)menuItemsForTab:(id <WKWebExtensionTab>)tab;
- (void)userGesturePerformedInTab:(id <WKWebExtensionTab>)tab;
- (BOOL)hasActiveUserGestureInTab:(id <WKWebExtensionTab>)tab;
- (void)clearUserGestureInTab:(id <WKWebExtensionTab>)tab;
@property (nonatomic, readonly, copy) NSArray<id <WKWebExtensionWindow>> *openWindows;
@property (nonatomic, readonly, weak, nullable) id <WKWebExtensionWindow> focusedWindow;
@property (nonatomic, readonly, copy) NSSet<id <WKWebExtensionTab>> *openTabs;
- (void)didOpenWindow:(id <WKWebExtensionWindow>)newWindow;
- (void)didCloseWindow:(id <WKWebExtensionWindow>)closedWindow;
- (void)didFocusWindow:(nullable id <WKWebExtensionWindow>)focusedWindow;
- (void)didOpenTab:(id <WKWebExtensionTab>)newTab;
- (void)didCloseTab:(id <WKWebExtensionTab>)closedTab windowIsClosing:(BOOL)windowIsClosing;
- (void)didActivateTab:(id <WKWebExtensionTab>)activatedTab previousActiveTab:(nullable id <WKWebExtensionTab>)previousTab;
- (void)didSelectTabs:(NSArray<id <WKWebExtensionTab>> *)selectedTabs;
- (void)didDeselectTabs:(NSArray<id <WKWebExtensionTab>> *)deselectedTabs;
- (void)didMoveTab:(id <WKWebExtensionTab>)movedTab fromIndex:(NSUInteger)index inWindow:(nullable id <WKWebExtensionWindow>)oldWindow;
- (void)didReplaceTab:(id <WKWebExtensionTab>)oldTab withTab:(id <WKWebExtensionTab>)newTab;
- (void)didChangeTabProperties:(WKWebExtensionTabChangedProperties)properties forTab:(id <WKWebExtensionTab>)changedTab;
@end
NS_ASSUME_NONNULL_END
