#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@protocol WKWebExtensionTab, WKWebExtensionWindow;
/* how an extension asks for a new tab (browser.tabs.create) */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionTabConfiguration : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, nullable, readonly, strong) id <WKWebExtensionWindow> window;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, nullable, readonly, strong) id <WKWebExtensionTab> parentTab;
@property (nonatomic, nullable, readonly, copy) NSURL *url;
@property (nonatomic, readonly) BOOL shouldBeActive;
@property (nonatomic, readonly) BOOL shouldAddToSelection;
@property (nonatomic, readonly) BOOL shouldBePinned;
@property (nonatomic, readonly) BOOL shouldBeMuted;
@property (nonatomic, readonly) BOOL shouldReaderModeBeActive;
@end
NS_ASSUME_NONNULL_END
