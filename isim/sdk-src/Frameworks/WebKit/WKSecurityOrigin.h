#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKSecurityOrigin : NSObject
@property (nonatomic, readonly, copy) NSString *protocol;
@property (nonatomic, readonly, copy) NSString *host;
@property (nonatomic, readonly) NSInteger port;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
