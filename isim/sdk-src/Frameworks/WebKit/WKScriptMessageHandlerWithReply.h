#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKUserContentController, WKScriptMessage;
@protocol WKScriptMessageHandlerWithReply <NSObject>
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
                 replyHandler:(void (^)(id _Nullable reply, NSString * _Nullable errorMessage))replyHandler;
@end
NS_ASSUME_NONNULL_END
