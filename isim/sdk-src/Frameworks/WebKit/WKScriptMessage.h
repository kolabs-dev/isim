#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebView, WKFrameInfo, WKContentWorld;
@interface WKScriptMessage : NSObject
@property (nonatomic, readonly, copy) id body;
@property (nullable, nonatomic, readonly, weak) WKWebView *webView;
@property (nonatomic, readonly, copy) WKFrameInfo *frameInfo;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) WKContentWorld *world;
@end
NS_ASSUME_NONNULL_END
