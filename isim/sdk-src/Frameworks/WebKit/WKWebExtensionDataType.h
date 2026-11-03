#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
/* the kinds of data a web extension stores (browser.storage.local, .session, .sync) */
typedef NSString *WKWebExtensionDataType NS_TYPED_ENUM API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionDataType const WKWebExtensionDataTypeLocal API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionDataType const WKWebExtensionDataTypeSession API_AVAILABLE(ios(18.4));
WK_EXTERN WKWebExtensionDataType const WKWebExtensionDataTypeSynchronized API_AVAILABLE(ios(18.4));
NS_ASSUME_NONNULL_END
