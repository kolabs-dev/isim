#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
/* the API permissions a web extension asks for in its manifest */
typedef NSString *WKWebExtensionPermission NS_TYPED_EXTENSIBLE_ENUM API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionActiveTab API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionAlarms API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionClipboardWrite API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionContextMenus API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionCookies API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequest API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestFeedback API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestWithHostAccess API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionMenus API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionNativeMessaging API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionScripting API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionStorage API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionTabs API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionUnlimitedStorage API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionWebNavigation API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionPermission const WKWebExtensionPermissionWebRequest API_AVAILABLE(ios(18.4));
NS_ASSUME_NONNULL_END
