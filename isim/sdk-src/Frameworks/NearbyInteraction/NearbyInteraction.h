#pragma once
/* isim NearbyInteraction for Objective-C: the classes of the NearbyInteraction Swift overlay (the framework re-exports
   libswiftNearbyInteraction.dylib). Like Apple's Simulator there is no Ultra Wideband: no capabilities, no discovery
   token, and a session that runs is invalidated with NIErrorCodeUnsupportedPlatform. Swift uses the overlay; these
   declarations are hidden from Swift. Not from Objective-C yet: NINearbyObject's direction (a simd vector) and
   NISession's delegateQueue. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const NIErrorDomain;
typedef NS_ERROR_ENUM(NIErrorDomain, NIErrorCode) {
    NIErrorCodeUnsupportedPlatform = -5889,
    NIErrorCodeInvalidConfiguration = -5888,
    NIErrorCodeSessionFailed = -5887,
    NIErrorCodeResourceUsageTimeout = -5886,
    NIErrorCodeActiveSessionsLimitExceeded = -5885,
    NIErrorCodeUserDidNotAllow = -5884,
    NIErrorCodeInvalidARConfiguration = -5883,
    NIErrorCodeAccessoryPeerDeviceUnavailable = -5882,
    NIErrorCodeIncompatiblePeerDevice = -5881,
    NIErrorCodeActiveExtendedDistanceSessionsLimitExceeded = -5880,
};

typedef NS_ENUM(NSInteger, NINearbyObjectRemovalReason) {
    NINearbyObjectRemovalReasonTimeout = 0,
    NINearbyObjectRemovalReasonPeerEnded = 1,
};
typedef NS_ENUM(NSInteger, NINearbyObjectVerticalDirectionEstimate) {
    NINearbyObjectVerticalDirectionEstimateUnknown = 0,
    NINearbyObjectVerticalDirectionEstimateSame = 1,
    NINearbyObjectVerticalDirectionEstimateAbove = 2,
    NINearbyObjectVerticalDirectionEstimateBelow = 3,
    NINearbyObjectVerticalDirectionEstimateAboveOrBelow = 4,
};
FOUNDATION_EXPORT float const NINearbyObjectDistanceNotAvailable;

@protocol NIDeviceCapability <NSObject>
@property (nonatomic, readonly) BOOL supportsPreciseDistanceMeasurement;
@property (nonatomic, readonly) BOOL supportsDirectionMeasurement;
@property (nonatomic, readonly) BOOL supportsCameraAssistance;
@property (nonatomic, readonly) BOOL supportsExtendedDistanceMeasurement;
@end

@interface NIDiscoveryToken : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
@end

@interface NIConfiguration : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
@end
@interface NINearbyPeerConfiguration : NIConfiguration
- (instancetype)initWithPeerToken:(NIDiscoveryToken *)peerToken;
@property (nonatomic, readonly, copy) NIDiscoveryToken *peerDiscoveryToken;
@property (nonatomic, assign, getter=isCameraAssistanceEnabled) BOOL cameraAssistanceEnabled;
@property (nonatomic, assign, getter=isExtendedDistanceMeasurementEnabled) BOOL extendedDistanceMeasurementEnabled;
@end
@interface NINearbyAccessoryConfiguration : NIConfiguration
- (nullable instancetype)initWithData:(NSData *)data error:(NSError **)error;
@property (nonatomic, readonly, copy) NIDiscoveryToken *accessoryDiscoveryToken;
@end

@interface NINearbyObject : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly, copy) NIDiscoveryToken *discoveryToken;
@property (nonatomic, readonly) float distance;
@property (nonatomic, readonly) float horizontalAngle;
@property (nonatomic, readonly) NINearbyObjectVerticalDirectionEstimate verticalDirectionEstimate;
- (instancetype)init NS_UNAVAILABLE;
@end

@class NISession;
@protocol NISessionDelegate <NSObject>
@optional
- (void)session:(NISession *)session didUpdateNearbyObjects:(NSArray<NINearbyObject *> *)nearbyObjects;
- (void)session:(NISession *)session didRemoveNearbyObjects:(NSArray<NINearbyObject *> *)nearbyObjects withReason:(NINearbyObjectRemovalReason)reason;
- (void)sessionWasSuspended:(NISession *)session;
- (void)sessionSuspensionEnded:(NISession *)session;
- (void)session:(NISession *)session didInvalidateWithError:(NSError *)error;
- (void)session:(NISession *)session didGenerateShareableConfigurationData:(NSData *)shareableConfigurationData forObject:(NINearbyObject *)object;
@end

@interface NISession : NSObject
@property (class, readonly) BOOL isSupported API_DEPRECATED("Use deviceCapabilities", ios(14.0, 16.0));
@property (class, readonly) id<NIDeviceCapability> deviceCapabilities;
@property (nonatomic, weak, nullable) id<NISessionDelegate> delegate;
@property (nonatomic, readonly, copy, nullable) NIDiscoveryToken *discoveryToken;
@property (nonatomic, readonly, copy, nullable) NIConfiguration *configuration;
- (void)runWithConfiguration:(NIConfiguration *)configuration;
- (void)pause;
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
#endif
