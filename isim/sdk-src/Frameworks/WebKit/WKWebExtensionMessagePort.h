#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
WK_EXTERN NSErrorDomain const WKWebExtensionMessagePortErrorDomain API_AVAILABLE(ios(18.4));
typedef NS_ERROR_ENUM(WKWebExtensionMessagePortErrorDomain, WKWebExtensionMessagePortError) {
    WKWebExtensionMessagePortErrorUnknown = 1, WKWebExtensionMessagePortErrorNotConnected, WKWebExtensionMessagePortErrorMessageInvalid,
} API_AVAILABLE(ios(18.4));
/* a native messaging connection between an extension (browser.runtime.connectNative) and the app */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionMessagePort : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, nullable) NSString *applicationIdentifier;
@property (nonatomic, copy, nullable) void (^messageHandler)(id _Nullable message, NSError * _Nullable error);
@property (nonatomic, copy, nullable) void (^disconnectHandler)(NSError * _Nullable error);
@property (nonatomic, readonly, getter=isDisconnected) BOOL disconnected;
- (void)sendMessage:(nullable id)message completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)disconnect;
- (void)disconnectWithError:(nullable NSError *)error;
@end
NS_ASSUME_NONNULL_END
