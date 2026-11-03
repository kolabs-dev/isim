#pragma once
#import <WebKit/WKFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
@class WKWebExtensionContext, WKWebView, UIImage, UIMenuElement, UIViewController;
@protocol WKWebExtensionTab;
/* an extension's toolbar button, for all tabs or one tab (browser.action) */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionAction : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, weak) WKWebExtensionContext *webExtensionContext;
@property (nonatomic, readonly, nullable, weak) id <WKWebExtensionTab> associatedTab;
- (nullable UIImage *)iconForSize:(CGSize)size;
@property (nonatomic, readonly, copy) NSString *label;
@property (nonatomic, readonly, copy) NSString *badgeText;
@property (nonatomic) BOOL hasUnreadBadgeText;
@property (nonatomic, nullable, copy) NSString *inspectionName;
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, copy) NSArray<UIMenuElement *> *menuItems;
@property (nonatomic, readonly) BOOL presentsPopup;
@property (nonatomic, readonly, nullable) UIViewController *popupViewController;
@property (nonatomic, readonly, nullable) WKWebView *popupWebView;
- (void)closePopup;
@end
NS_ASSUME_NONNULL_END
