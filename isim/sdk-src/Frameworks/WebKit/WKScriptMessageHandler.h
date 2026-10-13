#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKUserContentController, WKScriptMessage;
@protocol WKScriptMessageHandler <NSObject>
@required
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;
@end
NS_ASSUME_NONNULL_END
