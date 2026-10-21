#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: compiled by the web engine (WebKitGTK content filters) and applied to the web views of the controllers they are added to */
@interface WKContentRuleList : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@end
NS_ASSUME_NONNULL_END
