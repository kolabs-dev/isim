#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKNavigationResponse : NSObject
@property (nonatomic, readonly, getter=isForMainFrame) BOOL forMainFrame;
@property (nonatomic, readonly, copy) NSURLResponse *response;
@property (nonatomic, readonly) BOOL canShowMIMEType;
@end
NS_ASSUME_NONNULL_END
