#pragma once
/* isim WebKit for Objective-C. The classes are the WebKit Swift overlay's (rendered by the host's WebKitGTK), under
   Apple's Objective-C names and selectors, so Objective-C apps and binary SDKs use them, subclass them and add
   categories. Swift code uses the overlay itself, so these declarations are hidden from Swift (headers of other
   frameworks that mention a WebKit class still parse: the classes are forward-declared). Not available from
   Objective-C yet: content rule lists' compilation results beyond identifiers, and the iOS 26 WebPage API (Swift only, as
   on iOS). */
#import <WebKit/WKFoundation.h>
#if !defined(__swift__)
#import <WebKit/WKError.h>
#import <WebKit/WKPreferences.h>
#import <WebKit/WKWebpagePreferences.h>
#import <WebKit/WKProcessPool.h>
#import <WebKit/WKContentWorld.h>
#import <WebKit/WKUserScript.h>
#import <WebKit/WKScriptMessage.h>
#import <WebKit/WKScriptMessageHandler.h>
#import <WebKit/WKScriptMessageHandlerWithReply.h>
#import <WebKit/WKContentRuleList.h>
#import <WebKit/WKContentRuleListStore.h>
#import <WebKit/WKUserContentController.h>
#import <WebKit/WKSecurityOrigin.h>
#import <WebKit/WKFrameInfo.h>
#import <WebKit/WKNavigation.h>
#import <WebKit/WKNavigationAction.h>
#import <WebKit/WKNavigationResponse.h>
#import <WebKit/WKWindowFeatures.h>
#import <WebKit/WKBackForwardListItem.h>
#import <WebKit/WKBackForwardList.h>
#import <WebKit/WKHTTPCookieStore.h>
#import <WebKit/WKWebsiteDataRecord.h>
#import <WebKit/WKWebsiteDataStore.h>
#import <WebKit/WKSnapshotConfiguration.h>
#import <WebKit/WKPDFConfiguration.h>
#import <WebKit/WKFindConfiguration.h>
#import <WebKit/WKFindResult.h>
#import <WebKit/WKContextMenuElementInfo.h>
#import <WebKit/WKURLSchemeTask.h>
#import <WebKit/WKURLSchemeHandler.h>
#import <WebKit/WKDownloadDelegate.h>
#import <WebKit/WKDownload.h>
#import <WebKit/WKWebViewConfiguration.h>
#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKUIDelegate.h>
#import <WebKit/WKWebView.h>
#endif
