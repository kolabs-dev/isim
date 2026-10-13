#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKBackForwardListItem : NSObject
@property (readonly, copy) NSURL *URL;
@property (nullable, readonly, copy) NSString *title;
@property (readonly, copy) NSURL *initialURL;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
