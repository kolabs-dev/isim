#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKPreferences, WKProcessPool, WKUserContentController, WKWebpagePreferences, WKWebsiteDataStore;
typedef NS_ENUM(NSInteger, WKSelectionGranularity) { WKSelectionGranularityDynamic, WKSelectionGranularityCharacter };
typedef NS_OPTIONS(NSUInteger, WKDataDetectorTypes) {
    WKDataDetectorTypeNone = 0, WKDataDetectorTypePhoneNumber = 1 << 0, WKDataDetectorTypeLink = 1 << 1, WKDataDetectorTypeAddress = 1 << 2,
    WKDataDetectorTypeCalendarEvent = 1 << 3, WKDataDetectorTypeTrackingNumber = 1 << 4, WKDataDetectorTypeFlightNumber = 1 << 5,
    WKDataDetectorTypeLookupSuggestion = 1 << 6, WKDataDetectorTypeAll = NSUIntegerMax,
};
typedef NS_OPTIONS(NSUInteger, WKAudiovisualMediaTypes) {
    WKAudiovisualMediaTypeNone = 0, WKAudiovisualMediaTypeAudio = 1 << 0, WKAudiovisualMediaTypeVideo = 1 << 1, WKAudiovisualMediaTypeAll = NSUIntegerMax,
};
typedef NS_ENUM(NSInteger, WKUserInterfaceDirectionPolicy) { WKUserInterfaceDirectionPolicyContent, WKUserInterfaceDirectionPolicySystem };
@interface WKWebViewConfiguration : NSObject <NSCopying>
@property (nonatomic, strong) WKProcessPool *processPool;
@property (nonatomic, strong) WKPreferences *preferences;
@property (nonatomic, strong) WKUserContentController *userContentController;
@property (nonatomic, strong) WKWebsiteDataStore *websiteDataStore;
@property (nonatomic, null_resettable, copy) WKWebpagePreferences *defaultWebpagePreferences;
@property (nullable, nonatomic, copy) NSString *applicationNameForUserAgent;
@property (nonatomic) BOOL allowsInlineMediaPlayback;
@property (nonatomic) BOOL allowsAirPlayForMediaPlayback;
@property (nonatomic) BOOL allowsPictureInPictureMediaPlayback;
@property (nonatomic) WKAudiovisualMediaTypes mediaTypesRequiringUserActionForPlayback;
@property (nonatomic) WKDataDetectorTypes dataDetectorTypes;
@property (nonatomic) BOOL ignoresViewportScaleLimits;
@property (nonatomic) BOOL suppressesIncrementalRendering;
@property (nonatomic) WKSelectionGranularity selectionGranularity;
@property (nonatomic) WKUserInterfaceDirectionPolicy userInterfaceDirectionPolicy;
@property (nonatomic) BOOL limitsNavigationsToAppBoundDomains;
@property (nonatomic) BOOL upgradeKnownHostsToHTTPS;
@property (nonatomic) BOOL allowsInlinePredictions;
@end
NS_ASSUME_NONNULL_END
