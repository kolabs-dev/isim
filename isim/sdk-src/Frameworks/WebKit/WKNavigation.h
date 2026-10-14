#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebpagePreferences.h>
@interface WKNavigation : NSObject
@property (nonatomic, readonly) WKContentMode effectiveContentMode;
@end
