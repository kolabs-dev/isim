#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKSecurityOrigin, WKWebView;
@interface WKFrameInfo : NSObject
@property (nonatomic, readonly, getter=isMainFrame) BOOL mainFrame;
@property (nonatomic, readonly, copy) NSURLRequest *request;
@property (nonatomic, readonly) WKSecurityOrigin *securityOrigin;
@property (nullable, nonatomic, readonly, weak) WKWebView *webView;
@end
NS_ASSUME_NONNULL_END
