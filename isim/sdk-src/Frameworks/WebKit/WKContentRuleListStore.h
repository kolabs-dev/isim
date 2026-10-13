#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKContentRuleList;
@interface WKContentRuleListStore : NSObject
+ (instancetype)defaultStore;
+ (instancetype)storeWithURL:(NSURL *)url;
- (void)compileContentRuleListForIdentifier:(NSString *)identifier encodedContentRuleList:(NSString *)encodedContentRuleList
                          completionHandler:(void (^)(WKContentRuleList * _Nullable, NSError * _Nullable))completionHandler;
- (void)lookUpContentRuleListForIdentifier:(NSString *)identifier completionHandler:(void (^)(WKContentRuleList * _Nullable, NSError * _Nullable))completionHandler;
- (void)removeContentRuleListForIdentifier:(NSString *)identifier completionHandler:(void (^)(NSError * _Nullable))completionHandler;
- (void)getAvailableContentRuleListIdentifiers:(void (^)(NSArray<NSString *> * _Nullable))completionHandler;
@end
NS_ASSUME_NONNULL_END
