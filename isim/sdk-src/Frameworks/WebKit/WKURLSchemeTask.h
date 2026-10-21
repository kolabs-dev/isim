#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
/* a request for a custom URL scheme the app serves: answer with a response, data, then didFinish (or an error) */
@protocol WKURLSchemeTask <NSObject>
@property (nonatomic, readonly, copy) NSURLRequest *request;
- (void)didReceiveResponse:(NSURLResponse *)response;
- (void)didReceiveData:(NSData *)data;
- (void)didFinish;
- (void)didFailWithError:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
