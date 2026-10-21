#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebView, WKNavigation, WKNavigationAction, WKNavigationResponse, WKWebpagePreferences, WKDownload;
typedef NS_ENUM(NSInteger, WKNavigationActionPolicy) { WKNavigationActionPolicyCancel, WKNavigationActionPolicyAllow, WKNavigationActionPolicyDownload };
typedef NS_ENUM(NSInteger, WKNavigationResponsePolicy) { WKNavigationResponsePolicyCancel, WKNavigationResponsePolicyAllow, WKNavigationResponsePolicyDownload };
@protocol WKNavigationDelegate <NSObject>
@optional
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction preferences:(WKWebpagePreferences *)preferences
        decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decisionHandler;
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
        decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler;
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error;
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error;
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView;
/* HTTP authentication (Basic, Digest, NTLM): a credential, default handling (the server's 401 page), or cancel */
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
        completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
/* a navigation the policy made a download (WKNavigationActionPolicyDownload / WKNavigationResponsePolicyDownload) */
- (void)webView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction didBecomeDownload:(WKDownload *)download;
- (void)webView:(WKWebView *)webView navigationResponse:(WKNavigationResponse *)navigationResponse didBecomeDownload:(WKDownload *)download;
@end
NS_ASSUME_NONNULL_END
