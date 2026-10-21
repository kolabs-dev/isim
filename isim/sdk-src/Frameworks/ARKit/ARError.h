#pragma once
/* isim ARKit: ARErrorDomain and ARErrorCode (the overlay's ARError bridges to NSError in this domain). */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define ARKIT_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define ARKIT_EXTERN extern __attribute__((visibility("default")))
#endif
ARKIT_EXTERN NSString * const ARErrorDomain;
typedef NS_ERROR_ENUM(ARErrorDomain, ARErrorCode) {
    ARErrorCodeUnsupportedConfiguration = 100, ARErrorCodeSensorUnavailable = 101, ARErrorCodeSensorFailed = 102,
    ARErrorCodeCameraUnauthorized = 103, ARErrorCodeMicrophoneUnauthorized = 104, ARErrorCodeLocationUnauthorized = 105,
    ARErrorCodeHighResolutionFrameCaptureInProgress = 106, ARErrorCodeHighResolutionFrameCaptureFailed = 107,
    ARErrorCodeWorldTrackingFailed = 200, ARErrorCodeGeoTrackingNotAvailableAtLocation = 201, ARErrorCodeGeoTrackingFailed = 202,
    ARErrorCodeInvalidReferenceImage = 300, ARErrorCodeInvalidReferenceObject = 301, ARErrorCodeInvalidWorldMap = 302,
    ARErrorCodeInvalidConfiguration = 303, ARErrorCodeInvalidCollaborationData = 304, ARErrorCodeInsufficientFeatures = 400,
    ARErrorCodeObjectMergeFailed = 401, ARErrorCodeFileIOFailed = 500, ARErrorCodeRequestFailed = 501
};
NS_ASSUME_NONNULL_END
#endif
