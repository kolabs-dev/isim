#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKPreferences : NSObject
@property (nonatomic) CGFloat minimumFontSize;
@property (nonatomic) BOOL javaScriptCanOpenWindowsAutomatically;
@property (nonatomic, getter=isFraudulentWebsiteWarningEnabled) BOOL fraudulentWebsiteWarningEnabled;
@property (nonatomic, getter=isElementFullscreenEnabled) BOOL elementFullscreenEnabled;
@property (nonatomic, getter=isTextInteractionEnabled) BOOL textInteractionEnabled;
@property (nonatomic, getter=isSiteSpecificQuirksModeEnabled) BOOL siteSpecificQuirksModeEnabled;
@property (nonatomic) BOOL shouldPrintBackgrounds;
@property (nonatomic) BOOL javaScriptEnabled __attribute__((deprecated("use WKWebpagePreferences.allowsContentJavaScript")));
@end
NS_ASSUME_NONNULL_END
