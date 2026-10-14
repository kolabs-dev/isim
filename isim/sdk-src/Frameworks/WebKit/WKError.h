#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
WK_EXTERN NSString * const WKErrorDomain;
WK_EXTERN NSString * const WKJavaScriptExceptionMessageErrorKey;
WK_EXTERN NSString * const WKJavaScriptExceptionLineNumberErrorKey;
WK_EXTERN NSString * const WKJavaScriptExceptionColumnNumberErrorKey;
WK_EXTERN NSString * const WKJavaScriptExceptionSourceURLErrorKey;
typedef NS_ENUM(NSInteger, WKErrorCode) {
    WKErrorUnknown = 1, WKErrorWebContentProcessTerminated, WKErrorWebViewInvalidated, WKErrorJavaScriptExceptionOccurred,
    WKErrorJavaScriptResultTypeIsUnsupported, WKErrorContentRuleListStoreCompileFailed, WKErrorContentRuleListStoreLookUpFailed,
    WKErrorContentRuleListStoreRemoveFailed, WKErrorContentRuleListStoreVersionMismatch, WKErrorAttributedStringContentFailedToLoad,
    WKErrorAttributedStringContentLoadTimedOut, WKErrorJavaScriptInvalidFrameTarget, WKErrorNavigationAppBoundDomain,
    WKErrorJavaScriptAppBoundDomain, WKErrorDuplicateCredential, WKErrorMalformedCredential, WKErrorCredentialNotFound,
};
NS_ASSUME_NONNULL_END
