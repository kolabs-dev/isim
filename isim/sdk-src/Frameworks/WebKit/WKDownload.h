#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKDownloadDelegate.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebView, WKFrameInfo;
/* a file the web view downloads (isim: the engine downloads it; resume data restarts it to the same destination) */
@interface WKDownload : NSObject <NSProgressReporting>
@property (nonatomic, readonly, nullable) NSURLRequest *originalRequest;
@property (nonatomic, readonly, weak) WKWebView *webView;
@property (nonatomic, weak) id<WKDownloadDelegate> delegate;
@property (nonatomic, readonly, getter=isUserInitiated) BOOL userInitiated;
@property (nonatomic, readonly) WKFrameInfo *originatingFrame;
- (void)cancel:(void (^ _Nullable)(NSData * _Nullable resumeData))completionHandler;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
