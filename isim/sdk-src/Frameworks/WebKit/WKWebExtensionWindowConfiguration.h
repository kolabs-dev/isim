#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionWindow.h>
NS_ASSUME_NONNULL_BEGIN
@protocol WKWebExtensionTab;
/* how an extension asks for a new window (browser.windows.create) */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionWindowConfiguration : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) WKWebExtensionWindowType windowType;
@property (nonatomic, readonly) WKWebExtensionWindowState windowState;
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly, copy) NSArray<NSURL *> *tabURLs;
@property (nonatomic, readonly, copy) NSArray<id <WKWebExtensionTab>> *tabs;
@property (nonatomic, readonly) BOOL shouldBeFocused;
@property (nonatomic, readonly) BOOL shouldBePrivate;
@end
NS_ASSUME_NONNULL_END
