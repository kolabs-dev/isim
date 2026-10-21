#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKURLSchemeTask.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebView;
/* serves a custom URL scheme (WKWebViewConfiguration setURLSchemeHandler:forURLScheme:) */
@protocol WKURLSchemeHandler <NSObject>
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask;
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask;
@end
NS_ASSUME_NONNULL_END
