#pragma once
/* isim AVFoundation for Objective-C (issue #707): capture. The classes are the AVFoundation Swift overlay's (simulated
   cameras fed by isim's camera sources, see the overlay); Swift uses the overlay, these declarations are hidden from
   Swift. Delegates are called on the queue given (dispatch_queue_t), the sample buffers are the overlay's (see
   CMSampleBuffer.h). The Camera Control, depth output, synchronizer and system pressure: issue #811. The classes are not
   subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class AVCaptureSystemPressureState, AVCaptureSession, AVCaptureOutput, AVCaptureConnection, AVCaptureVideoPreviewLayer, AVCapturePhotoOutput, AVCapturePhoto,
    AVCaptureResolvedPhotoSettings, AVCaptureFileOutput, AVMetadataObject, AVDepthData, AVPortraitEffectsMatte, AVSemanticSegmentationMatte,
    AVCameraCalibrationData;
typedef NSString *AVCaptureDeviceType NS_TYPED_ENUM;
typedef NSString *AVCaptureSessionPreset NS_TYPED_ENUM;
typedef NSString *AVVideoCodecType NS_TYPED_ENUM;
typedef NSString *AVFileType NS_TYPED_ENUM;
typedef NSString *AVMetadataObjectType NS_TYPED_ENUM;
typedef NSString *AVSemanticSegmentationMatteType NS_TYPED_ENUM;
FOUNDATION_EXPORT AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInUltraWideCamera,
    AVCaptureDeviceTypeBuiltInTelephotoCamera, AVCaptureDeviceTypeBuiltInDualCamera, AVCaptureDeviceTypeBuiltInDualWideCamera,
    AVCaptureDeviceTypeBuiltInTripleCamera, AVCaptureDeviceTypeBuiltInTrueDepthCamera, AVCaptureDeviceTypeBuiltInLiDARDepthCamera,
    AVCaptureDeviceTypeMicrophone, AVCaptureDeviceTypeBuiltInMicrophone, AVCaptureDeviceTypeContinuityCamera, AVCaptureDeviceTypeExternal;
FOUNDATION_EXPORT AVCaptureSessionPreset const AVCaptureSessionPresetPhoto, AVCaptureSessionPresetHigh, AVCaptureSessionPresetMedium,
    AVCaptureSessionPresetLow, AVCaptureSessionPreset1280x720, AVCaptureSessionPreset1920x1080, AVCaptureSessionPreset3840x2160,
    AVCaptureSessionPreset640x480, AVCaptureSessionPreset352x288, AVCaptureSessionPresetiFrame960x540, AVCaptureSessionPresetiFrame1280x720,
    AVCaptureSessionPresetInputPriority;
FOUNDATION_EXPORT AVVideoCodecType const AVVideoCodecTypeH264, AVVideoCodecTypeHEVC, AVVideoCodecTypeHEVCWithAlpha, AVVideoCodecTypeJPEG,
    AVVideoCodecTypeAppleProRes422, AVVideoCodecTypeAppleProRes4444;
FOUNDATION_EXPORT AVFileType const AVFileTypeQuickTimeMovie, AVFileTypeMPEG4, AVFileTypeAppleM4V, AVFileTypeAppleM4A, AVFileTypeWAVE,
    AVFileTypeCoreAudioFormat, AVFileTypeAIFF, AVFileTypeAIFC, AVFileTypeMPEGLayer3, AVFileTypeAC3, AVFileTypeHEIC, AVFileTypeJPEG, AVFileType3GPP;
FOUNDATION_EXPORT AVMetadataObjectType const AVMetadataObjectTypeQRCode, AVMetadataObjectTypeFace;
FOUNDATION_EXPORT AVSemanticSegmentationMatteType const AVSemanticSegmentationMatteTypeHair, AVSemanticSegmentationMatteTypeSkin,
    AVSemanticSegmentationMatteTypeTeeth, AVSemanticSegmentationMatteTypeGlasses;
FOUNDATION_EXPORT AVMediaType const AVMediaTypeDepthData, AVMediaTypeMetadataObject;
FOUNDATION_EXPORT NSString * const AVVideoCodecKey, * const AVVideoWidthKey, * const AVVideoHeightKey, * const AVVideoCompressionPropertiesKey,
    * const AVVideoAverageBitRateKey, * const AVVideoQualityKey, * const AVVideoMaxKeyFrameIntervalKey, * const AVVideoExpectedSourceFrameRateKey,
    * const AVVideoProfileLevelKey, * const AVVideoScalingModeKey;
FOUNDATION_EXPORT NSNotificationName const AVCaptureSessionDidStartRunningNotification, AVCaptureSessionDidStopRunningNotification,
    AVCaptureSessionWasInterruptedNotification, AVCaptureSessionInterruptionEndedNotification, AVCaptureSessionRuntimeErrorNotification,
    AVCaptureDeviceWasConnectedNotification, AVCaptureDeviceWasDisconnectedNotification, AVCaptureDeviceSubjectAreaDidChangeNotification;

typedef NS_ENUM(NSInteger, AVAuthorizationStatus) { AVAuthorizationStatusNotDetermined = 0, AVAuthorizationStatusRestricted, AVAuthorizationStatusDenied, AVAuthorizationStatusAuthorized };
typedef NS_ENUM(NSInteger, AVCaptureDevicePosition) { AVCaptureDevicePositionUnspecified = 0, AVCaptureDevicePositionBack = 1, AVCaptureDevicePositionFront = 2 };
typedef NS_ENUM(NSInteger, AVCaptureFocusMode) { AVCaptureFocusModeLocked = 0, AVCaptureFocusModeAutoFocus, AVCaptureFocusModeContinuousAutoFocus };
typedef NS_ENUM(NSInteger, AVCaptureExposureMode) { AVCaptureExposureModeLocked = 0, AVCaptureExposureModeAutoExpose, AVCaptureExposureModeContinuousAutoExposure, AVCaptureExposureModeCustom };
typedef NS_ENUM(NSInteger, AVCaptureWhiteBalanceMode) { AVCaptureWhiteBalanceModeLocked = 0, AVCaptureWhiteBalanceModeAutoWhiteBalance, AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance };
typedef NS_ENUM(NSInteger, AVCaptureFlashMode) { AVCaptureFlashModeOff = 0, AVCaptureFlashModeOn, AVCaptureFlashModeAuto };
typedef NS_ENUM(NSInteger, AVCaptureTorchMode) { AVCaptureTorchModeOff = 0, AVCaptureTorchModeOn, AVCaptureTorchModeAuto };
typedef NS_ENUM(NSInteger, AVCaptureVideoOrientation) { AVCaptureVideoOrientationPortrait = 1, AVCaptureVideoOrientationPortraitUpsideDown, AVCaptureVideoOrientationLandscapeRight, AVCaptureVideoOrientationLandscapeLeft };
typedef NS_ENUM(NSInteger, AVCaptureVideoStabilizationMode) { AVCaptureVideoStabilizationModeOff = 0, AVCaptureVideoStabilizationModeStandard, AVCaptureVideoStabilizationModeCinematic, AVCaptureVideoStabilizationModeCinematicExtended };
typedef NS_ENUM(NSInteger, AVCapturePhotoQualityPrioritization) { AVCapturePhotoQualityPrioritizationSpeed = 1, AVCapturePhotoQualityPrioritizationBalanced, AVCapturePhotoQualityPrioritizationQuality };
typedef NS_ENUM(NSInteger, AVCapturePhotoOutputCaptureReadiness) {
    AVCapturePhotoOutputCaptureReadinessSessionNotRunning = 0, AVCapturePhotoOutputCaptureReadinessReady, AVCapturePhotoOutputCaptureReadinessNotReadyMomentarily,
    AVCapturePhotoOutputCaptureReadinessNotReadyWaitingForCapture, AVCapturePhotoOutputCaptureReadinessNotReadyWaitingForProcessing,
};

// MARK: devices
@interface AVCaptureDeviceFormat : NSObject
@property (nonatomic, readonly) AVMediaType mediaType;
@property (nonatomic, readonly) CMVideoDimensions highResolutionStillImageDimensions;   // AVFoundation.m
@property (nonatomic, readonly) CGFloat videoMaxZoomFactor;
@property (nonatomic, readonly) float videoFieldOfView;
@property (nonatomic, readonly) float minISO, maxISO;
@property (nonatomic, readonly, getter=isVideoHDRSupported) BOOL videoHDRSupported;
@property (nonatomic, readonly, getter=isMultiCamSupported) BOOL multiCamSupported;
@property (nonatomic, readonly) NSArray<AVCaptureDeviceFormat *> *supportedDepthDataFormats;
@end
@interface AVCaptureDevice : NSObject
+ (nullable AVCaptureDevice *)defaultDeviceWithMediaType:(AVMediaType)mediaType;
+ (nullable AVCaptureDevice *)defaultDeviceWithDeviceType:(AVCaptureDeviceType)deviceType mediaType:(nullable AVMediaType)mediaType position:(AVCaptureDevicePosition)position;
+ (nullable AVCaptureDevice *)deviceWithUniqueID:(NSString *)deviceUniqueID;
+ (AVAuthorizationStatus)authorizationStatusForMediaType:(AVMediaType)mediaType;
+ (void)requestAccessForMediaType:(AVMediaType)mediaType completionHandler:(void (^)(BOOL granted))handler;
@property (class, nonatomic, readonly, nullable) AVCaptureDevice *systemPreferredCamera;
@property (nonatomic, readonly) NSString *uniqueID, *modelID, *manufacturer, *localizedName;
@property (nonatomic, readonly) AVCaptureDevicePosition position;
@property (nonatomic, readonly) AVCaptureDeviceType deviceType;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly, getter=isVirtualDevice) BOOL virtualDevice;
@property (nonatomic, readonly) NSArray<AVCaptureDevice *> *constituentDevices;
- (BOOL)hasMediaType:(AVMediaType)mediaType;
- (BOOL)lockForConfiguration:(NSError * _Nullable * _Nullable)outError;
- (void)unlockForConfiguration;
@property (nonatomic, retain) AVCaptureDeviceFormat *activeFormat;
@property (nonatomic, readonly) NSArray<AVCaptureDeviceFormat *> *formats;
@property (nonatomic) CMTime activeVideoMinFrameDuration, activeVideoMaxFrameDuration;   // AVFoundation.m
@property (nonatomic, readonly) BOOL hasTorch, hasFlash;
@property (nonatomic, readonly, getter=isTorchAvailable) BOOL torchAvailable;
@property (nonatomic, readonly, getter=isTorchActive) BOOL torchActive;
@property (nonatomic, readonly) float torchLevel;
@property (nonatomic) AVCaptureTorchMode torchMode;
- (BOOL)isTorchModeSupported:(AVCaptureTorchMode)torchMode;
- (BOOL)setTorchModeOnWithLevel:(float)torchLevel error:(NSError * _Nullable * _Nullable)outError;
@property (nonatomic) AVCaptureFocusMode focusMode;
- (BOOL)isFocusModeSupported:(AVCaptureFocusMode)focusMode;
@property (nonatomic) AVCaptureExposureMode exposureMode;
- (BOOL)isExposureModeSupported:(AVCaptureExposureMode)exposureMode;
@property (nonatomic) AVCaptureWhiteBalanceMode whiteBalanceMode;
- (BOOL)isWhiteBalanceModeSupported:(AVCaptureWhiteBalanceMode)whiteBalanceMode;
@property (nonatomic) CGPoint focusPointOfInterest, exposurePointOfInterest;
@property (nonatomic, readonly, getter=isFocusPointOfInterestSupported) BOOL focusPointOfInterestSupported;
@property (nonatomic, readonly, getter=isExposurePointOfInterestSupported) BOOL exposurePointOfInterestSupported;
@property (nonatomic, getter=isSubjectAreaChangeMonitoringEnabled) BOOL subjectAreaChangeMonitoringEnabled;
@property (nonatomic, readonly, getter=isAdjustingFocus) BOOL adjustingFocus;
@property (nonatomic, readonly, getter=isAdjustingExposure) BOOL adjustingExposure;
@property (nonatomic, readonly, getter=isAdjustingWhiteBalance) BOOL adjustingWhiteBalance;
@property (nonatomic) CGFloat videoZoomFactor;
@property (nonatomic, readonly) CGFloat minAvailableVideoZoomFactor, maxAvailableVideoZoomFactor;
- (void)rampToVideoZoomFactor:(CGFloat)factor withRate:(float)rate;
- (void)cancelVideoZoomRamp;
@property (nonatomic, readonly, getter=isRampingVideoZoom) BOOL rampingVideoZoom;
@property (nonatomic, readonly) float lensAperture, ISO, lensPosition, exposureTargetBias, minExposureTargetBias, maxExposureTargetBias;
@property (nonatomic, readonly) CMTime exposureDuration;                                  // AVFoundation.m
@property (nonatomic) CMTime activeMaxExposureDuration;                                   // AVFoundation.m
- (void)setExposureTargetBias:(float)bias completionHandler:(nullable void (^)(CMTime syncTime))handler;   // AVFoundation.m
- (void)setFocusModeLockedWithLensPosition:(float)lensPosition completionHandler:(nullable void (^)(CMTime syncTime))handler;
@property (nonatomic, retain, nullable) AVCaptureDeviceFormat *activeDepthDataFormat;
@property (nonatomic, readonly) AVCaptureSystemPressureState *systemPressureState;   /* KVO-observable */
@end
@interface AVCaptureDeviceDiscoverySession : NSObject
+ (instancetype)discoverySessionWithDeviceTypes:(NSArray<AVCaptureDeviceType> *)deviceTypes mediaType:(nullable AVMediaType)mediaType
                                       position:(AVCaptureDevicePosition)position;
@property (nonatomic, readonly) NSArray<AVCaptureDevice *> *devices;
@end

// MARK: inputs, connections, sessions
@interface AVCaptureInputPort : NSObject
@property (nonatomic, readonly) AVMediaType mediaType;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end
@interface AVCaptureInput : NSObject
@property (nonatomic, readonly) NSArray<AVCaptureInputPort *> *ports;
@end
@interface AVCaptureDeviceInput : AVCaptureInput
+ (nullable instancetype)deviceInputWithDevice:(AVCaptureDevice *)device error:(NSError * _Nullable * _Nullable)outError;
- (nullable instancetype)initWithDevice:(AVCaptureDevice *)device error:(NSError * _Nullable * _Nullable)outError;
@property (nonatomic, readonly) AVCaptureDevice *device;
@end
@interface AVCaptureConnection : NSObject
@property (nonatomic, readonly) NSArray<AVCaptureInputPort *> *inputPorts;
@property (nonatomic, readonly, nullable) AVCaptureOutput *output;
@property (nonatomic, readonly, nullable) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, getter=isActive) BOOL active;
@property (nonatomic) AVCaptureVideoOrientation videoOrientation;
@property (nonatomic, readonly, getter=isVideoOrientationSupported) BOOL supportsVideoOrientation;
@property (nonatomic) CGFloat videoRotationAngle;
- (BOOL)isVideoRotationAngleSupported:(CGFloat)videoRotationAngle;
@property (nonatomic, getter=isVideoMirrored) BOOL videoMirrored;
@property (nonatomic, readonly, getter=isVideoMirroringSupported) BOOL supportsVideoMirroring;
@property (nonatomic) BOOL automaticallyAdjustsVideoMirroring;
@property (nonatomic) AVCaptureVideoStabilizationMode preferredVideoStabilizationMode;
@property (nonatomic, readonly, getter=isVideoStabilizationSupported) BOOL supportsVideoStabilization;
@end
@interface AVCaptureSession : NSObject
@property (nonatomic, copy) AVCaptureSessionPreset sessionPreset;
- (BOOL)canSetSessionPreset:(AVCaptureSessionPreset)preset;
@property (nonatomic, readonly) NSArray<__kindof AVCaptureInput *> *inputs;
@property (nonatomic, readonly) NSArray<__kindof AVCaptureOutput *> *outputs;
@property (nonatomic, readonly) NSArray<AVCaptureConnection *> *connections;
- (BOOL)canAddInput:(AVCaptureInput *)input;
- (void)addInput:(AVCaptureInput *)input;
- (void)removeInput:(AVCaptureInput *)input;
- (BOOL)canAddOutput:(AVCaptureOutput *)output;
- (void)addOutput:(AVCaptureOutput *)output;
- (void)removeOutput:(AVCaptureOutput *)output;
- (void)addInputWithNoConnections:(AVCaptureInput *)input;
- (void)addOutputWithNoConnections:(AVCaptureOutput *)output;
- (BOOL)canAddConnection:(AVCaptureConnection *)connection;
- (void)addConnection:(AVCaptureConnection *)connection;
- (void)removeConnection:(AVCaptureConnection *)connection;
- (void)beginConfiguration;
- (void)commitConfiguration;
- (void)startRunning;
- (void)stopRunning;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly, getter=isInterrupted) BOOL interrupted;
@property (nonatomic) BOOL automaticallyConfiguresApplicationAudioSession;
@property (nonatomic, readonly) float hardwareCost;
@end
@interface AVCaptureMultiCamSession : AVCaptureSession
@property (class, nonatomic, readonly, getter=isMultiCamSupported) BOOL multiCamSupported;
@property (nonatomic, readonly) float systemPressureCost;
@end
@interface AVCaptureVideoPreviewLayer : CALayer
+ (instancetype)layerWithSession:(AVCaptureSession *)session;
- (instancetype)initWithSession:(AVCaptureSession *)session;
@property (nonatomic, retain, nullable) AVCaptureSession *session;
@property (nonatomic, readonly, nullable) AVCaptureConnection *connection;
@property (nonatomic, copy) AVLayerVideoGravity videoGravity;
@property (nonatomic, readonly) BOOL isPreviewing;
- (CGPoint)captureDevicePointOfInterestForPoint:(CGPoint)pointInLayer;
- (CGPoint)pointForCaptureDevicePointOfInterest:(CGPoint)captureDevicePointOfInterest;
- (nullable AVMetadataObject *)transformedMetadataObjectForMetadataObject:(AVMetadataObject *)metadataObject;
@end

// MARK: outputs
@interface AVCaptureOutput : NSObject
@property (nonatomic, readonly) NSArray<AVCaptureConnection *> *connections;
- (nullable AVCaptureConnection *)connectionWithMediaType:(AVMediaType)mediaType;
@end
@protocol AVCaptureVideoDataOutputSampleBufferDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
@end
@protocol AVCaptureAudioDataOutputSampleBufferDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
@end
@interface AVCaptureVideoDataOutput : AVCaptureOutput
- (void)setSampleBufferDelegate:(nullable id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(nullable dispatch_queue_t)sampleBufferCallbackQueue;
@property (nonatomic, readonly, nullable) id<AVCaptureVideoDataOutputSampleBufferDelegate> sampleBufferDelegate;
@property (nonatomic, readonly, nullable) dispatch_queue_t sampleBufferCallbackQueue;
@property (nonatomic, copy, null_resettable) NSDictionary<NSString *, id> *videoSettings;
@property (nonatomic) BOOL alwaysDiscardsLateVideoFrames;
@property (nonatomic, readonly) NSArray<NSNumber *> *availableVideoCVPixelFormatTypes;
- (nullable NSDictionary<NSString *, id> *)recommendedVideoSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType;
@end
@interface AVCaptureAudioDataOutput : AVCaptureOutput
- (void)setSampleBufferDelegate:(nullable id<AVCaptureAudioDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(nullable dispatch_queue_t)sampleBufferCallbackQueue;
@end
@interface AVMetadataObject : NSObject
@property (nonatomic, readonly) AVMetadataObjectType type;
@property (nonatomic, readonly) CGRect bounds;
@end
@interface AVMetadataMachineReadableCodeObject : AVMetadataObject
@property (nonatomic, readonly, nullable) NSString *stringValue;
@property (nonatomic, readonly) NSArray<NSDictionary *> *corners;
@end
@interface AVMetadataFaceObject : AVMetadataObject
@end
@protocol AVCaptureMetadataOutputObjectsDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection;
@end
@interface AVCaptureMetadataOutput : AVCaptureOutput
- (void)setMetadataObjectsDelegate:(nullable id<AVCaptureMetadataOutputObjectsDelegate>)objectsDelegate queue:(nullable dispatch_queue_t)objectsCallbackQueue;
@property (nonatomic, readonly) NSArray<AVMetadataObjectType> *availableMetadataObjectTypes;
@property (nonatomic, copy, null_resettable) NSArray<AVMetadataObjectType> *metadataObjectTypes;
@property (nonatomic) CGRect rectOfInterest;
@end
@protocol AVCaptureFileOutputRecordingDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections;
@required
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(nullable NSError *)error;
@end
@interface AVCaptureFileOutput : AVCaptureOutput
- (void)startRecordingToOutputFileURL:(NSURL *)outputFileURL recordingDelegate:(id<AVCaptureFileOutputRecordingDelegate>)delegate;
- (void)stopRecording;
@property (nonatomic, readonly, nullable) NSURL *outputFileURL;
@property (nonatomic, readonly) CMTime recordedDuration;                                   // AVFoundation.m
@property (nonatomic) CMTime maxRecordedDuration;                                          // AVFoundation.m
@property (nonatomic, readonly) int64_t recordedFileSize;
@property (nonatomic) int64_t maxRecordedFileSize;
@property (nonatomic, readonly, getter=isRecordingPaused) BOOL recordingPaused;
- (void)pauseRecording;
- (void)resumeRecording;
@end
@interface AVCaptureMovieFileOutput : AVCaptureFileOutput
@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, readonly) NSArray<AVVideoCodecType> *availableVideoCodecTypes;
- (NSDictionary<NSString *, id> *)outputSettingsForConnection:(AVCaptureConnection *)connection;
- (void)setOutputSettings:(nullable NSDictionary<NSString *, id> *)outputSettings forConnection:(AVCaptureConnection *)connection;
@end

// MARK: photos
@interface AVCapturePhotoSettings : NSObject
+ (instancetype)photoSettings;
+ (instancetype)photoSettingsWithFormat:(nullable NSDictionary<NSString *, id> *)format;
+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType;
+ (instancetype)photoSettingsFromPhotoSettings:(AVCapturePhotoSettings *)photoSettings;
@property (nonatomic, readonly) int64_t uniqueID;
@property (nonatomic, readonly, copy, nullable) NSDictionary<NSString *, id> *format;
@property (nonatomic, readonly) OSType rawPhotoPixelFormatType;
@property (nonatomic) AVCaptureFlashMode flashMode;
@property (nonatomic) AVCapturePhotoQualityPrioritization photoQualityPrioritization;
@property (nonatomic) CMVideoDimensions maxPhotoDimensions;                                // AVFoundation.m
@property (nonatomic, getter=isDepthDataDeliveryEnabled) BOOL depthDataDeliveryEnabled;
@property (nonatomic, getter=isPortraitEffectsMatteDeliveryEnabled) BOOL portraitEffectsMatteDeliveryEnabled;
@property (nonatomic, getter=isCameraCalibrationDataDeliveryEnabled) BOOL cameraCalibrationDataDeliveryEnabled;
@property (nonatomic, copy) NSArray<AVSemanticSegmentationMatteType> *enabledSemanticSegmentationMatteTypes;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *previewPhotoFormat;
@property (nonatomic, copy) NSDictionary<NSString *, id> *metadata;
@property (nonatomic, copy, nullable) NSURL *livePhotoMovieFileURL;
@property (nonatomic, getter=isShutterSoundSuppressionEnabled) BOOL shutterSoundSuppressionEnabled;
@end
@interface AVCaptureResolvedPhotoSettings : NSObject
@property (nonatomic, readonly) int64_t uniqueID;
@property (nonatomic, readonly) CMVideoDimensions photoDimensions;                         // AVFoundation.m
@property (nonatomic, readonly, getter=isFlashEnabled) BOOL flashEnabled;
@property (nonatomic, readonly) NSUInteger expectedPhotoCount;
@end
@interface AVCapturePhoto : NSObject
@property (nonatomic, readonly) CMTime timestamp;                                          // AVFoundation.m
@property (nonatomic, readonly) AVCaptureResolvedPhotoSettings *resolvedSettings;
@property (nonatomic, readonly, nullable) CVPixelBufferRef pixelBuffer;                    // AVFoundation.m
@property (nonatomic, readonly, nullable) CVPixelBufferRef previewPixelBuffer;
@property (nonatomic, readonly) NSInteger photoCount;
@property (nonatomic, readonly, getter=isRawPhoto) BOOL rawPhoto;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *metadata;
@property (nonatomic, readonly, nullable) AVDepthData *depthData;
@property (nonatomic, readonly, nullable) AVPortraitEffectsMatte *portraitEffectsMatte;
- (nullable AVSemanticSegmentationMatte *)semanticSegmentationMatteForType:(AVSemanticSegmentationMatteType)semanticSegmentationMatteType;
@property (nonatomic, readonly, nullable) AVCameraCalibrationData *cameraCalibrationData;
- (nullable NSData *)fileDataRepresentation;
- (nullable CGImageRef)CGImageRepresentation;
- (nullable CGImageRef)previewCGImageRepresentation;
@end
@protocol AVCapturePhotoCaptureDelegate <NSObject>
@optional
- (void)captureOutput:(AVCapturePhotoOutput *)output willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings;
- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings;
- (void)captureOutput:(AVCapturePhotoOutput *)output didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings;
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(nullable NSError *)error;
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                error:(nullable NSError *)error;
@end
@interface AVCapturePhotoOutput : AVCaptureOutput
- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate;
@property (nonatomic, readonly) NSArray<AVVideoCodecType> *availablePhotoCodecTypes;
@property (nonatomic, readonly) NSArray<NSNumber *> *availablePhotoPixelFormatTypes;
@property (nonatomic, readonly) NSArray<AVFileType> *availablePhotoFileTypes;
@property (nonatomic, readonly) NSArray<NSNumber *> *supportedFlashModes;
@property (nonatomic) AVCapturePhotoQualityPrioritization maxPhotoQualityPrioritization;
@property (nonatomic) CMVideoDimensions maxPhotoDimensions;                                // AVFoundation.m
@property (nonatomic, readonly, getter=isLivePhotoCaptureSupported) BOOL livePhotoCaptureSupported;
@property (nonatomic, getter=isLivePhotoCaptureEnabled) BOOL livePhotoCaptureEnabled;
@property (nonatomic, readonly, getter=isDepthDataDeliverySupported) BOOL depthDataDeliverySupported;
@property (nonatomic, getter=isDepthDataDeliveryEnabled) BOOL depthDataDeliveryEnabled;
@property (nonatomic, readonly, getter=isPortraitEffectsMatteDeliverySupported) BOOL portraitEffectsMatteDeliverySupported;
@property (nonatomic, getter=isPortraitEffectsMatteDeliveryEnabled) BOOL portraitEffectsMatteDeliveryEnabled;
@property (nonatomic, readonly, getter=isCameraCalibrationDataDeliverySupported) BOOL cameraCalibrationDataDeliverySupported;
@property (nonatomic, readonly) NSArray<AVSemanticSegmentationMatteType> *availableSemanticSegmentationMatteTypes;
@property (nonatomic, copy) NSArray<AVSemanticSegmentationMatteType> *enabledSemanticSegmentationMatteTypes;
@property (nonatomic, readonly) AVCapturePhotoOutputCaptureReadiness captureReadiness;
@property (nonatomic, readonly) NSUInteger maxBracketedCapturePhotoCount;
@property (nonatomic, getter=isZeroShutterLagEnabled) BOOL zeroShutterLagEnabled;
@end

// MARK: depth, mattes and calibration
typedef NS_ENUM(NSInteger, AVDepthDataAccuracy) { AVDepthDataAccuracyRelative = 0, AVDepthDataAccuracyAbsolute = 1 };
typedef NS_ENUM(NSInteger, AVDepthDataQuality) { AVDepthDataQualityLow = 0, AVDepthDataQualityHigh = 1 };
@interface AVDepthData : NSObject
+ (nullable instancetype)depthDataFromDictionaryRepresentation:(NSDictionary *)imageSourceAuxDataInfoDictionary error:(NSError * _Nullable * _Nullable)outError;
@property (nonatomic, readonly) CVPixelBufferRef depthDataMap;                              // AVFoundation.m
@property (nonatomic, readonly) OSType depthDataType;
@property (nonatomic, readonly) NSArray<NSNumber *> *availableDepthDataTypes;
@property (nonatomic, readonly, getter=isDepthDataFiltered) BOOL depthDataFiltered;
@property (nonatomic, readonly) AVDepthDataAccuracy depthDataAccuracy;
@property (nonatomic, readonly) AVDepthDataQuality depthDataQuality;
@property (nonatomic, readonly, nullable) AVCameraCalibrationData *cameraCalibrationData;
- (instancetype)depthDataByConvertingToDepthDataType:(OSType)depthDataType;
- (nullable instancetype)depthDataByReplacingDepthDataMapWithPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError * _Nullable * _Nullable)outError;   // AVFoundation.m
- (nullable NSDictionary *)dictionaryRepresentationForAuxiliaryDataType:(NSString * _Nullable * _Nullable)outAuxDataType;
@end
@interface AVPortraitEffectsMatte : NSObject
@property (nonatomic, readonly) CVPixelBufferRef mattingImage;                             // AVFoundation.m
@property (nonatomic, readonly) OSType pixelFormatType;
@end
@interface AVSemanticSegmentationMatte : NSObject
@property (nonatomic, readonly) AVSemanticSegmentationMatteType matteType;
@property (nonatomic, readonly) CVPixelBufferRef mattingImage;                             // AVFoundation.m
@property (nonatomic, readonly) OSType pixelFormatType;
@end
@interface AVCameraCalibrationData : NSObject
@property (nonatomic, readonly) float pixelSize;
@property (nonatomic, readonly) CGSize intrinsicMatrixReferenceDimensions;
@property (nonatomic, readonly) CGPoint lensDistortionCenter;
@property (nonatomic, readonly, nullable) NSData *lensDistortionLookupTable, *inverseLensDistortionLookupTable;
@end

// MARK: system pressure (iOS 11)
typedef NSString *AVCaptureSystemPressureLevel NS_TYPED_ENUM;
FOUNDATION_EXPORT AVCaptureSystemPressureLevel const AVCaptureSystemPressureLevelNominal, AVCaptureSystemPressureLevelFair,
    AVCaptureSystemPressureLevelSerious, AVCaptureSystemPressureLevelCritical, AVCaptureSystemPressureLevelShutdown;
typedef NS_OPTIONS(NSUInteger, AVCaptureSystemPressureFactors) {
    AVCaptureSystemPressureFactorNone = 0, AVCaptureSystemPressureFactorSystemTemperature = 1 << 0, AVCaptureSystemPressureFactorPeakPower = 1 << 1,
    AVCaptureSystemPressureFactorDepthModuleTemperature = 1 << 2, AVCaptureSystemPressureFactorCameraTemperature = 1 << 3,
    AVCaptureSystemPressureFactorBatteryStress API_AVAILABLE(ios(27.0)) = 1 << 4,
};
@interface AVCaptureSystemPressureState : NSObject
@property (nonatomic, readonly) AVCaptureSystemPressureLevel level;
@property (nonatomic, readonly) AVCaptureSystemPressureFactors factors;
@end

// MARK: the Camera Control (iOS 18)
API_AVAILABLE(ios(18.0))
@interface AVCaptureControl : NSObject
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaptureSlider : AVCaptureControl
- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle symbolName:(NSString *)symbolName minValue:(float)minValue maxValue:(float)maxValue;
- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle symbolName:(NSString *)symbolName minValue:(float)minValue maxValue:(float)maxValue step:(float)step;
- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle symbolName:(NSString *)symbolName values:(NSArray<NSNumber *> *)values;
@property (nonatomic) float value;
@property (nonatomic, readonly) NSString *localizedTitle;
@property (nonatomic, readonly) NSString *symbolName;
@property (nonatomic, copy) NSArray<NSNumber *> *prominentValues;
@property (nonatomic, copy, nullable) NSString *localizedValueFormat;
@property (nonatomic, copy, nullable) NSString *accessibilityIdentifier;
- (void)setActionQueue:(dispatch_queue_t)actionQueue action:(void (^)(float newValue))action;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaptureIndexPicker : AVCaptureControl
- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle symbolName:(NSString *)symbolName numberOfIndexes:(NSInteger)numberOfIndexes;
- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle symbolName:(NSString *)symbolName numberOfIndexes:(NSInteger)numberOfIndexes
                localizedTitleTransform:(NSString * (^)(NSInteger index))localizedTitleTransform;
- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle symbolName:(NSString *)symbolName localizedIndexTitles:(NSArray<NSString *> *)localizedIndexTitles;
@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic, readonly) NSString *localizedTitle;
@property (nonatomic, readonly) NSString *symbolName;
@property (nonatomic, readonly) NSInteger numberOfIndexes;
@property (nonatomic, readonly) NSArray<NSString *> *localizedIndexTitles;
@property (nonatomic, copy, nullable) NSString *accessibilityIdentifier;
- (void)setActionQueue:(dispatch_queue_t)actionQueue action:(void (^)(NSInteger selectedIndex))action;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaptureSystemZoomSlider : AVCaptureControl
- (instancetype)initWithDevice:(AVCaptureDevice *)device;
- (instancetype)initWithDevice:(AVCaptureDevice *)device action:(void (^)(CGFloat videoZoomFactor))action;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaptureSystemExposureBiasSlider : AVCaptureControl
- (instancetype)initWithDevice:(AVCaptureDevice *)device;
- (instancetype)initWithDevice:(AVCaptureDevice *)device action:(void (^)(float exposureTargetBias))action;
@end
API_AVAILABLE(ios(18.0))
@protocol AVCaptureSessionControlsDelegate <NSObject>
- (void)sessionControlsDidBecomeActive:(AVCaptureSession *)session;
- (void)sessionControlsWillEnterFullscreenAppearance:(AVCaptureSession *)session;
- (void)sessionControlsWillExitFullscreenAppearance:(AVCaptureSession *)session;
- (void)sessionControlsDidBecomeInactive:(AVCaptureSession *)session;
@end
@interface AVCaptureSession (AVCaptureSessionControls)
@property (nonatomic, readonly) BOOL supportsControls API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly) NSInteger maxControlsCount API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly) NSArray<__kindof AVCaptureControl *> *controls API_AVAILABLE(ios(18.0));
- (BOOL)canAddControl:(AVCaptureControl *)control API_AVAILABLE(ios(18.0));
- (void)addControl:(AVCaptureControl *)control API_AVAILABLE(ios(18.0));
- (void)removeControl:(AVCaptureControl *)control API_AVAILABLE(ios(18.0));
- (void)setControlsDelegate:(nullable id<AVCaptureSessionControlsDelegate>)controlsDelegate queue:(nullable dispatch_queue_t)controlsDelegateCallbackQueue API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly, nullable) id<AVCaptureSessionControlsDelegate> controlsDelegate API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly, nullable) dispatch_queue_t controlsDelegateCallbackQueue API_AVAILABLE(ios(18.0));
@end

// MARK: depth data output and synchronizer
typedef NS_ENUM(NSInteger, AVCaptureOutputDataDroppedReason) {
    AVCaptureOutputDataDroppedReasonNone = 0, AVCaptureOutputDataDroppedReasonLateData = 1, AVCaptureOutputDataDroppedReasonOutOfBuffers = 2,
    AVCaptureOutputDataDroppedReasonDiscontinuity = 3,
};
@class AVCaptureDepthDataOutput, AVCaptureDataOutputSynchronizer, AVCaptureSynchronizedDataCollection;
@protocol AVCaptureDepthDataOutputDelegate <NSObject>
@optional
- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output didOutputDepthData:(AVDepthData *)depthData timestamp:(CMTime)timestamp
             connection:(AVCaptureConnection *)connection;
- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output didDropDepthData:(AVDepthData *)depthData timestamp:(CMTime)timestamp
             connection:(AVCaptureConnection *)connection reason:(AVCaptureOutputDataDroppedReason)reason;
@end
@interface AVCaptureDepthDataOutput : AVCaptureOutput
- (void)setDelegate:(nullable id<AVCaptureDepthDataOutputDelegate>)delegate callbackQueue:(nullable dispatch_queue_t)callbackQueue;
@property (nonatomic, readonly, nullable) id<AVCaptureDepthDataOutputDelegate> delegate;
@property (nonatomic, readonly, nullable) dispatch_queue_t delegateCallbackQueue;
@property (nonatomic) BOOL alwaysDiscardsLateDepthData;
@property (nonatomic, getter=isFilteringEnabled) BOOL filteringEnabled;
@end
@interface AVCaptureSynchronizedData : NSObject
@property (nonatomic, readonly) CMTime timestamp;                                          // AVFoundation.m
@end
@interface AVCaptureSynchronizedSampleBufferData : AVCaptureSynchronizedData
@property (nonatomic, readonly) CMSampleBufferRef sampleBuffer;                            // AVFoundation.m
@property (nonatomic, readonly) BOOL sampleBufferWasDropped;
@property (nonatomic, readonly) AVCaptureOutputDataDroppedReason droppedReason;
@end
@interface AVCaptureSynchronizedDepthData : AVCaptureSynchronizedData
@property (nonatomic, readonly) AVDepthData *depthData;
@property (nonatomic, readonly) BOOL depthDataWasDropped;
@property (nonatomic, readonly) AVCaptureOutputDataDroppedReason droppedReason;
@end
@interface AVCaptureSynchronizedMetadataObjectData : AVCaptureSynchronizedData
@property (nonatomic, readonly) NSArray<AVMetadataObject *> *metadataObjects;
@end
@interface AVCaptureSynchronizedDataCollection : NSObject <NSFastEnumeration>
- (nullable AVCaptureSynchronizedData *)synchronizedDataForCaptureOutput:(AVCaptureOutput *)captureOutput;
- (nullable AVCaptureSynchronizedData *)objectForKeyedSubscript:(AVCaptureOutput *)key;
@property (nonatomic, readonly) NSUInteger count;
@end
@protocol AVCaptureDataOutputSynchronizerDelegate <NSObject>
@required
- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)synchronizedDataCollection;
@end
@interface AVCaptureDataOutputSynchronizer : NSObject
- (instancetype)initWithDataOutputs:(NSArray<AVCaptureOutput *> *)dataOutputs;
@property (nonatomic, readonly) NSArray<AVCaptureOutput *> *dataOutputs;
- (void)setDelegate:(nullable id<AVCaptureDataOutputSynchronizerDelegate>)delegate queue:(nullable dispatch_queue_t)delegateCallbackQueue;
@property (nonatomic, readonly, nullable) id<AVCaptureDataOutputSynchronizerDelegate> delegate;
@property (nonatomic, readonly, nullable) dispatch_queue_t delegateCallbackQueue;
@end
NS_ASSUME_NONNULL_END
#endif
