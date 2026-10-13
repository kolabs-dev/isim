#pragma once
#import <WebKit/WKFoundation.h>
@interface WKFindResult : NSObject
@property (nonatomic, readonly) BOOL matchFound;
- (instancetype)init NS_UNAVAILABLE;
@end
