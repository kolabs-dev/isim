#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: content rule lists are compiled and stored, not applied */
@interface WKContentRuleList : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@end
NS_ASSUME_NONNULL_END
