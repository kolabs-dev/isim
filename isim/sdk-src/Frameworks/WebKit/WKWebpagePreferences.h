#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, WKContentMode) { WKContentModeRecommended, WKContentModeMobile, WKContentModeDesktop };
typedef NS_ENUM(NSInteger, WKWebpagePreferencesUpgradeToHTTPSPolicy) {
    WKWebpagePreferencesUpgradeToHTTPSPolicyKeepAsRequested, WKWebpagePreferencesUpgradeToHTTPSPolicyAutomaticFallbackToHTTP,
    WKWebpagePreferencesUpgradeToHTTPSPolicyUserMediatedFallbackToHTTP, WKWebpagePreferencesUpgradeToHTTPSPolicyErrorOnFailure,
} API_AVAILABLE(ios(18.2));
@interface WKWebpagePreferences : NSObject
@property (nonatomic) WKContentMode preferredContentMode;
@property (nonatomic) BOOL allowsContentJavaScript;
@property (nonatomic, getter=isLockdownModeEnabled) BOOL lockdownModeEnabled;
@property (nonatomic) WKWebpagePreferencesUpgradeToHTTPSPolicy preferredHTTPSNavigationPolicy API_AVAILABLE(ios(18.2));
@end
NS_ASSUME_NONNULL_END
