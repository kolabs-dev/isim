#pragma once
/* isim SDK (self-authored): feature override sessions (iOS 18.2): an entitled app turns accessibility features on or off
 * while a session runs; isim's VoiceOver, and the grayscale and invert colors settings apps read, follow them. */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const AXFeatureOverrideSessionErrorDomain API_AVAILABLE(ios(18.2));
typedef NS_ERROR_ENUM(AXFeatureOverrideSessionErrorDomain, AXFeatureOverrideSessionError) {
    AXFeatureOverrideSessionErrorUndefined = 0,
    AXFeatureOverrideSessionErrorAppNotEntitled = 1,
    AXFeatureOverrideSessionErrorOverrideIsAlreadyActive = 2,
    AXFeatureOverrideSessionErrorOverrideNotFoundForUUID = 3,
} API_AVAILABLE(ios(18.2));

typedef NS_OPTIONS(NSUInteger, AXFeatureOverrideSessionOptions) {
    AXFeatureOverrideSessionOptionVoiceOver = 1 << 0,
    AXFeatureOverrideSessionOptionZoom = 1 << 1,
    AXFeatureOverrideSessionOptionGrayscale = 1 << 2,
    AXFeatureOverrideSessionOptionInvertColors = 1 << 3,
    AXFeatureOverrideSessionOptionVoiceControl = 1 << 4,
} NS_SWIFT_NAME(AXFeatureOverrideSession.Options) API_AVAILABLE(ios(18.2));

API_AVAILABLE(ios(18.2))
@interface AXFeatureOverrideSession : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.2))
@interface AXFeatureOverrideSessionManager : NSObject
@property (class, nonatomic, readonly, strong) AXFeatureOverrideSessionManager *sharedInstance;
- (nullable AXFeatureOverrideSession *)beginOverrideSessionEnablingOptions:(AXFeatureOverrideSessionOptions)enableOptions
                                                          disablingOptions:(AXFeatureOverrideSessionOptions)disableOptions
                                                                     error:(NSError **)error NS_SWIFT_NAME(beginOverrideSession(enabling:disabling:));
- (BOOL)endOverrideSession:(AXFeatureOverrideSession *)session error:(NSError **)error NS_SWIFT_NAME(end(_:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
