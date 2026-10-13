#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, WKContentMode) { WKContentModeRecommended, WKContentModeMobile, WKContentModeDesktop };
typedef NS_ENUM(NSInteger, WKWebpagePreferencesUpgradeToHTTPSPolicy) {
    WKWebpagePreferencesUpgradeToHTTPSPolicyKeepAsRequested, WKWebpagePreferencesUpgradeToHTTPSPolicyAutomaticFallbackToHTTP,
    WKWebpagePreferencesUpgradeToHTTPSPolicyUserMediatedFallbackToHTTP, WKWebpagePreferencesUpgradeToHTTPSPolicyErrorOnFailure,
};
@interface WKWebpagePreferences : NSObject
@property (nonatomic) WKContentMode preferredContentMode;
@property (nonatomic) BOOL allowsContentJavaScript;
@property (nonatomic, getter=isLockdownModeEnabled) BOOL lockdownModeEnabled;
@property (nonatomic) WKWebpagePreferencesUpgradeToHTTPSPolicy preferredHTTPSNavigationPolicy;
@end
NS_ASSUME_NONNULL_END
