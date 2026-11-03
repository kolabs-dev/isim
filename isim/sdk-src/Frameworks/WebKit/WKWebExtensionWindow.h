#pragma once
#import <WebKit/WKFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtensionContext;
@protocol WKWebExtensionTab;
typedef NS_ENUM(NSInteger, WKWebExtensionWindowType) {
    WKWebExtensionWindowTypeNormal, WKWebExtensionWindowTypePopup,
} API_AVAILABLE(ios(18.4));
typedef NS_ENUM(NSInteger, WKWebExtensionWindowState) {
    WKWebExtensionWindowStateNormal, WKWebExtensionWindowStateMinimized, WKWebExtensionWindowStateMaximized, WKWebExtensionWindowStateFullscreen,
} API_AVAILABLE(ios(18.4));
/* one of the app's browser windows, as web extensions see it (browser.windows) */
API_AVAILABLE(ios(18.4))
@protocol WKWebExtensionWindow <NSObject>
@optional
- (NSArray<id <WKWebExtensionTab>> *)tabsForWebExtensionContext:(WKWebExtensionContext *)context;
- (nullable id <WKWebExtensionTab>)activeTabForWebExtensionContext:(WKWebExtensionContext *)context;
- (WKWebExtensionWindowType)windowTypeForWebExtensionContext:(WKWebExtensionContext *)context;
- (WKWebExtensionWindowState)windowStateForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setWindowState:(WKWebExtensionWindowState)state forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (BOOL)isPrivateForWebExtensionContext:(WKWebExtensionContext *)context;
- (CGRect)screenFrameForWebExtensionContext:(WKWebExtensionContext *)context;
- (CGRect)frameForWebExtensionContext:(WKWebExtensionContext *)context;
- (void)setFrame:(CGRect)frame forWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)focusForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)closeForWebExtensionContext:(WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
