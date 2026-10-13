#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKUserScript, WKContentWorld, WKContentRuleList;
@protocol WKScriptMessageHandler, WKScriptMessageHandlerWithReply;
@interface WKUserContentController : NSObject
@property (nonatomic, readonly, copy) NSArray<WKUserScript *> *userScripts;
- (void)addUserScript:(WKUserScript *)userScript;
- (void)removeAllUserScripts;
- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler name:(NSString *)name;
- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler contentWorld:(WKContentWorld *)world name:(NSString *)name;
- (void)addScriptMessageHandlerWithReply:(id<WKScriptMessageHandlerWithReply>)scriptMessageHandlerWithReply contentWorld:(WKContentWorld *)contentWorld name:(NSString *)name;
- (void)removeScriptMessageHandlerForName:(NSString *)name;
- (void)removeScriptMessageHandlerForName:(NSString *)name contentWorld:(WKContentWorld *)contentWorld;
- (void)removeAllScriptMessageHandlersFromContentWorld:(WKContentWorld *)contentWorld;
- (void)removeAllScriptMessageHandlers;
- (void)addContentRuleList:(WKContentRuleList *)contentRuleList;
- (void)removeContentRuleList:(WKContentRuleList *)contentRuleList;
- (void)removeAllContentRuleLists;
@end
NS_ASSUME_NONNULL_END
