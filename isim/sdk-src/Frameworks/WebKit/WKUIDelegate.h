#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebView, WKWebViewConfiguration, WKNavigationAction, WKWindowFeatures, WKFrameInfo, WKContextMenuElementInfo, WKSecurityOrigin, WKOpenPanelParameters;
typedef NS_ENUM(NSInteger, WKMediaCaptureType) { WKMediaCaptureTypeCamera, WKMediaCaptureTypeMicrophone, WKMediaCaptureTypeCameraAndMicrophone };
typedef NS_ENUM(NSInteger, WKPermissionDecision) { WKPermissionDecisionPrompt, WKPermissionDecisionGrant, WKPermissionDecisionDeny };
@protocol WKUIDelegate <NSObject>
@optional
- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
            forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures;
- (void)webViewDidClose:(WKWebView *)webView;
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame
        completionHandler:(void (^)(void))completionHandler;
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame
        completionHandler:(void (^)(BOOL result))completionHandler;
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText
        initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler;
- (void)webView:(WKWebView *)webView contextMenuConfigurationForElement:(WKContextMenuElementInfo *)elementInfo
        completionHandler:(void (^)(UIContextMenuConfiguration * _Nullable configuration))completionHandler;
- (void)webView:(WKWebView *)webView contextMenuWillPresentForElement:(WKContextMenuElementInfo *)elementInfo;
- (void)webView:(WKWebView *)webView contextMenuForElement:(WKContextMenuElementInfo *)elementInfo
        willCommitWithAnimator:(id<UIContextMenuInteractionCommitAnimating>)animator;
- (void)webView:(WKWebView *)webView contextMenuDidEndForElement:(WKContextMenuElementInfo *)elementInfo;
/* getUserMedia: grant, deny, or prompt (iOS's alert); isim's engine has WebKit's mock camera and microphone */
- (void)webView:(WKWebView *)webView requestMediaCapturePermissionForOrigin:(WKSecurityOrigin *)origin initiatedByFrame:(WKFrameInfo *)frame
            type:(WKMediaCaptureType)type decisionHandler:(void (^)(WKPermissionDecision decision))decisionHandler;
/* <input type=file>: the files to give the page, or nil (without this method: iOS's menu of photo, camera and file pickers) */
- (void)webView:(WKWebView *)webView runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters initiatedByFrame:(WKFrameInfo *)frame
        completionHandler:(void (^)(NSArray<NSURL *> * _Nullable URLs))completionHandler API_AVAILABLE(ios(18.4));
@end
NS_ASSUME_NONNULL_END
