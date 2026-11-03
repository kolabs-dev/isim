#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionPermission.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtensionController, WKWebExtensionContext, WKWebExtensionAction, WKWebExtensionMatchPattern, WKWebExtensionMessagePort;
@class WKWebExtensionTabConfiguration, WKWebExtensionWindowConfiguration;
@protocol WKWebExtensionTab, WKWebExtensionWindow;
/* the app's answers for its extensions: windows, new tabs and windows, permission prompts, popups, native messaging */
API_AVAILABLE(ios(18.4))
@protocol WKWebExtensionControllerDelegate <NSObject>
@optional
- (NSArray<id <WKWebExtensionWindow>> *)webExtensionController:(WKWebExtensionController *)controller openWindowsForExtensionContext:(WKWebExtensionContext *)extensionContext;
- (nullable id <WKWebExtensionWindow>)webExtensionController:(WKWebExtensionController *)controller focusedWindowForExtensionContext:(WKWebExtensionContext *)extensionContext;
- (void)webExtensionController:(WKWebExtensionController *)controller openNewWindowUsingConfiguration:(WKWebExtensionWindowConfiguration *)configuration forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(id <WKWebExtensionWindow> _Nullable newWindow, NSError * _Nullable error))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller openNewTabUsingConfiguration:(WKWebExtensionTabConfiguration *)configuration forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(id <WKWebExtensionTab> _Nullable newTab, NSError * _Nullable error))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller openOptionsPageForExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller promptForPermissions:(NSSet<WKWebExtensionPermission> *)permissions inTab:(nullable id <WKWebExtensionTab>)tab forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSSet<WKWebExtensionPermission> *allowedPermissions, NSDate * _Nullable expirationDate))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller promptForPermissionToAccessURLs:(NSSet<NSURL *> *)urls inTab:(nullable id <WKWebExtensionTab>)tab forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSSet<NSURL *> *allowedURLs, NSDate * _Nullable expirationDate))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller promptForPermissionMatchPatterns:(NSSet<WKWebExtensionMatchPattern *> *)matchPatterns inTab:(nullable id <WKWebExtensionTab>)tab forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSSet<WKWebExtensionMatchPattern *> *allowedMatchPatterns, NSDate * _Nullable expirationDate))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller didUpdateAction:(WKWebExtensionAction *)action forExtensionContext:(WKWebExtensionContext *)context;
- (void)webExtensionController:(WKWebExtensionController *)controller presentPopupForAction:(WKWebExtensionAction *)action forExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller sendMessage:(id)message toApplicationWithIdentifier:(nullable NSString *)applicationIdentifier forExtensionContext:(WKWebExtensionContext *)extensionContext replyHandler:(void (^)(id _Nullable replyMessage, NSError * _Nullable error))replyHandler;
- (void)webExtensionController:(WKWebExtensionController *)controller connectUsingMessagePort:(WKWebExtensionMessagePort *)port forExtensionContext:(WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
