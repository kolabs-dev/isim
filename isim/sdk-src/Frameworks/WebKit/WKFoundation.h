#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#define WK_EXTERN extern __attribute__((visibility("default")))
#define WK_SWIFT_UI_ACTOR
#if defined(__swift__)
/* Swift uses the WebKit overlay; other frameworks' headers that mention these classes still parse */
@class WKWebView, WKWebViewConfiguration, WKPreferences, WKWebpagePreferences, WKProcessPool, WKUserContentController, WKUserScript,
       WKScriptMessage, WKContentWorld, WKNavigation, WKNavigationAction, WKNavigationResponse, WKFrameInfo, WKSecurityOrigin,
       WKWindowFeatures, WKBackForwardList, WKBackForwardListItem, WKWebsiteDataStore, WKWebsiteDataRecord, WKHTTPCookieStore,
       WKSnapshotConfiguration, WKPDFConfiguration, WKFindConfiguration, WKFindResult, WKContentRuleList, WKContentRuleListStore,
       WKContextMenuElementInfo;
@protocol WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply, WKHTTPCookieStoreObserver;
#endif
