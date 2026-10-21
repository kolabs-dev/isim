#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKDownload, WKWebViewConfiguration, WKBackForwardList, WKBackForwardListItem, WKNavigation, WKSnapshotConfiguration, WKPDFConfiguration,
       WKFindConfiguration, WKFindResult, WKFrameInfo, WKContentWorld;
@protocol WKNavigationDelegate, WKUIDelegate;
/* isim: the page is rendered by the host's WebKitGTK (see the Swift overlay's WKWebView.swift for what is adapted) */
@interface WKWebView : UIView
@property (nonatomic, readonly, copy) WKWebViewConfiguration *configuration;
@property (nullable, nonatomic, weak) id<WKNavigationDelegate> navigationDelegate;
@property (nullable, nonatomic, weak) id<WKUIDelegate> UIDelegate;
@property (nonatomic, readonly, strong) WKBackForwardList *backForwardList;
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (nullable WKNavigation *)loadRequest:(NSURLRequest *)request;
- (nullable WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL;
- (nullable WKNavigation *)loadHTMLString:(NSString *)string baseURL:(nullable NSURL *)baseURL;
- (nullable WKNavigation *)loadData:(NSData *)data MIMEType:(NSString *)MIMEType characterEncodingName:(NSString *)characterEncodingName baseURL:(NSURL *)baseURL;
- (WKNavigation *)loadSimulatedRequest:(NSURLRequest *)request response:(NSURLResponse *)response responseData:(NSData *)data;
- (WKNavigation *)loadSimulatedRequest:(NSURLRequest *)request responseHTMLString:(NSString *)string;
- (WKNavigation *)loadFileRequest:(NSURLRequest *)request allowingReadAccessToURL:(NSURL *)readAccessURL;
- (nullable WKNavigation *)goToBackForwardListItem:(WKBackForwardListItem *)item;
@property (nullable, nonatomic, readonly, copy) NSString *title;
@property (nullable, nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) double estimatedProgress;
@property (nonatomic, readonly) BOOL hasOnlySecureContent;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
- (nullable WKNavigation *)goBack;
- (nullable WKNavigation *)goForward;
- (nullable WKNavigation *)reload;
- (nullable WKNavigation *)reloadFromOrigin;
- (void)stopLoading;
- (void)closeAllMediaPresentationsWithCompletionHandler:(nullable void (^)(void))completionHandler;
- (void)pauseAllMediaPlayback:(nullable void (^)(void))completionHandler;
- (void)setAllMediaPlaybackSuspended:(BOOL)suspended completionHandler:(nullable void (^)(void))completionHandler;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;
- (void)evaluateJavaScript:(NSString *)javaScriptString inFrame:(nullable WKFrameInfo *)frame inContentWorld:(WKContentWorld *)contentWorld
         completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;
- (void)callAsyncJavaScript:(NSString *)functionBody arguments:(nullable NSDictionary<NSString *, id> *)arguments inFrame:(nullable WKFrameInfo *)frame
             inContentWorld:(WKContentWorld *)contentWorld completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;
- (void)takeSnapshotWithConfiguration:(nullable WKSnapshotConfiguration *)snapshotConfiguration
                    completionHandler:(void (^)(UIImage * _Nullable snapshotImage, NSError * _Nullable error))completionHandler;
- (void)createPDFWithConfiguration:(nullable WKPDFConfiguration *)pdfConfiguration completionHandler:(void (^)(NSData * _Nullable pdfDocumentData, NSError * _Nullable error))completionHandler;
- (void)createWebArchiveDataWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler;
- (void)findString:(NSString *)string withConfiguration:(nullable WKFindConfiguration *)configuration completionHandler:(void (^)(WKFindResult *result))completionHandler;
+ (BOOL)handlesURLScheme:(NSString *)urlScheme;
- (void)startDownloadUsingRequest:(NSURLRequest *)request completionHandler:(void (^)(WKDownload *download))completionHandler;
- (void)resumeDownloadFromResumeData:(NSData *)resumeData completionHandler:(void (^)(WKDownload *download))completionHandler;
@property (nonatomic) BOOL allowsBackForwardNavigationGestures;
@property (nullable, nonatomic, copy) NSString *customUserAgent;
@property (nonatomic) BOOL allowsLinkPreview;
@property (nonatomic, readonly, strong) UIScrollView *scrollView;
@property (nonatomic) CGFloat pageZoom;
@property (nullable, nonatomic, copy) NSString *mediaType;
@property (nullable, nonatomic, copy) id interactionState;
@property (nonatomic, getter=isInspectable) BOOL inspectable;
@property (nonatomic, getter=isFindInteractionEnabled) BOOL findInteractionEnabled;
@property (nullable, nonatomic, readonly) UIFindInteraction *findInteraction;
@property (nullable, nonatomic, readonly, copy) UIColor *themeColor;
@property (null_resettable, nonatomic, copy) UIColor *underPageBackgroundColor;
@end
NS_ASSUME_NONNULL_END
