#pragma once
#import <WebKit/WKFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
@class WKSnapshotConfiguration, WKWebView, WKWebExtensionContext, WKWebExtensionTabConfiguration, UIImage;
@protocol WKWebExtensionWindow;
/* what changed in a tab (-[WKWebExtensionContext didChangeTabProperties:forTab:]) */
typedef NS_OPTIONS(NSUInteger, WKWebExtensionTabChangedProperties) {
    WKWebExtensionTabChangedPropertiesNone = 0,
    WKWebExtensionTabChangedPropertiesLoading = 1 << 1,
    WKWebExtensionTabChangedPropertiesMuted = 1 << 2,
    WKWebExtensionTabChangedPropertiesPinned = 1 << 3,
    WKWebExtensionTabChangedPropertiesPlayingAudio = 1 << 4,
    WKWebExtensionTabChangedPropertiesReaderMode = 1 << 5,
    WKWebExtensionTabChangedPropertiesSize = 1 << 6,
    WKWebExtensionTabChangedPropertiesTitle = 1 << 7,
    WKWebExtensionTabChangedPropertiesURL = 1 << 8,
    WKWebExtensionTabChangedPropertiesZoomFactor = 1 << 9,
} API_AVAILABLE(ios(18.4));
/* one of the app's browser tabs, as web extensions see it (browser.tabs) */
API_AVAILABLE(ios(18.4))
@protocol WKWebExtensionTab <NSObject>
@optional
- (nullable id <WKWebExtensionWindow>)windowForWebExtensionContext:(WKWebExtensionContext *)context;
- (NSUInteger)indexInWindowForWebExtensionContext:(WKWebExtensionContext *)context;
- (nullable id <WKWebExtensionTab>)parentTabForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setParentTab:(nullable id <WKWebExtensionTab>)parentTab forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (nullable WKWebView *)webViewForWebExtensionContext:(WKWebExtensionContext *)context;
- (nullable NSString *)titleForWebExtensionContext:(WKWebExtensionContext *)context;
- (BOOL)isPinnedForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setPinned:(BOOL)pinned forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (BOOL)isReaderModeAvailableForWebExtensionContext:(WKWebExtensionContext *)context;
- (BOOL)isReaderModeActiveForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setReaderModeActive:(BOOL)active forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (BOOL)isPlayingAudioForWebExtensionContext:(WKWebExtensionContext *)context;
- (BOOL)isMutedForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setMuted:(BOOL)muted forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (CGSize)sizeForWebExtensionContext:(WKWebExtensionContext *)context;
- (double)zoomFactorForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setZoomFactor:(double)zoomFactor forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (nullable NSURL *)urlForWebExtensionContext:(WKWebExtensionContext *)context;
- (nullable NSURL *)pendingURLForWebExtensionContext:(WKWebExtensionContext *)context;
- (BOOL)isLoadingCompleteForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)detectWebpageLocaleForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSLocale * _Nullable locale, NSError * _Nullable error))completionHandler;
- (void)takeSnapshotUsingConfiguration:(WKSnapshotConfiguration *)configuration forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completionHandler;
- (void)loadURL:(NSURL *)url forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)reloadFromOrigin:(BOOL)fromOrigin forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)goBackForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)goForwardForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)activateForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (BOOL)isSelectedForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setSelected:(BOOL)selected forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)duplicateUsingConfiguration:(WKWebExtensionTabConfiguration *)configuration forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(id <WKWebExtensionTab> _Nullable duplicatedTab, NSError * _Nullable error))completionHandler;
- (void)closeForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (BOOL)shouldGrantPermissionsOnUserGestureForWebExtensionContext:(WKWebExtensionContext *)context;
- (BOOL)shouldBypassPermissionsForWebExtensionContext:(WKWebExtensionContext *)context;
@end
NS_ASSUME_NONNULL_END
