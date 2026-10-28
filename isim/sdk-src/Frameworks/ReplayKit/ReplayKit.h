#pragma once
/* isim ReplayKit for Objective-C: the classes are the ReplayKit Swift overlay's (ReplayKit.framework re-exports
   libswiftReplayKit.dylib): RPScreenRecorder records and captures the app's windows (isim's renderer, H.264 through
   isim's AVAssetWriter), RPPreviewViewController plays a recording and saves it to Photos, and broadcasting reports
   that no broadcast service is available (isim cannot install broadcast upload extensions). Swift uses the overlay;
   these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class RPPreviewViewController, RPScreenRecorder, RPBroadcastController, RPBroadcastActivityViewController, RPBroadcastConfiguration;

FOUNDATION_EXPORT NSString * const RPRecordingErrorDomain;
FOUNDATION_EXPORT NSString * const SCStreamErrorDomain;
typedef NS_ENUM(NSInteger, RPRecordingErrorCode) {
    RPRecordingErrorUnknown = -5800, RPRecordingErrorUserDeclined = -5801, RPRecordingErrorDisabled = -5802,
    RPRecordingErrorFailedToStart = -5803, RPRecordingErrorFailed = -5804, RPRecordingErrorInsufficientStorage = -5805,
    RPRecordingErrorInterrupted = -5806, RPRecordingErrorContentResize = -5807, RPRecordingErrorBroadcastInvalidSession = -5808,
    RPRecordingErrorSystemDormancy = -5809, RPRecordingErrorEntitlements = -5810, RPRecordingErrorActivePhoneCall = -5811,
    RPRecordingErrorFailedToSave = -5812, RPRecordingErrorCarPlay = -5813, RPRecordingErrorFailedApplicationConnectionInvalid = -5814,
    RPRecordingErrorFailedApplicationConnectionInterrupted = -5815, RPRecordingErrorFailedNoMatchingApplicationContext = -5816,
    RPRecordingErrorFailedMediaServicesFailure = -5817, RPRecordingErrorVideoMixingFailure = -5818, RPRecordingErrorBroadcastSetupFailed = -5819,
    RPRecordingErrorFailedToObtainURL = -5820, RPRecordingErrorFailedIncorrectTimeStamps = -5821, RPRecordingErrorFailedToProcessFirstSample = -5822,
    RPRecordingErrorFailedAssetWriterFailedToSave = -5823, RPRecordingErrorFailedNoAssetWriter = -5824,
    RPRecordingErrorFailedAssetWriterInWrongState = -5825, RPRecordingErrorFailedAssetWriterExportFailed = -5826,
    RPRecordingErrorFailedToRemoveFile = -5827, RPRecordingErrorFailedAssetWriterExportCanceled = -5828,
    RPRecordingErrorAttemptToStopNonRecording = -5829, RPRecordingErrorAttemptToStartInRecordingState = -5830,
    RPRecordingErrorPhotoFailure = -5831, RPRecordingErrorRecordingInvalidSession = -5832, RPRecordingErrorFailedToStartCaptureStack = -5833,
    RPRecordingErrorInvalidParameter = -5834, RPRecordingErrorFilePermissions = -5835, RPRecordingErrorExportClipToURLInProgress = -5836,
    RPRecordingErrorCodeSuccessful = 0,
};

typedef NS_ENUM(NSInteger, RPSampleBufferType) { RPSampleBufferTypeVideo = 1, RPSampleBufferTypeAudioApp, RPSampleBufferTypeAudioMic };
typedef NS_ENUM(NSInteger, RPCameraPosition) { RPCameraPositionFront = 1, RPCameraPositionBack };
typedef NS_ENUM(NSInteger, RPPreviewViewControllerMode) { RPPreviewViewControllerModePreview = 0, RPPreviewViewControllerModeShare = 1 };
FOUNDATION_EXPORT NSString * const RPVideoSampleOrientationKey;
FOUNDATION_EXPORT NSString * const RPApplicationInfoBundleIdentifierKey;

@protocol RPPreviewViewControllerDelegate <NSObject>
@optional
- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController;
- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet<NSString *> *)activityTypes;
@end

@interface RPPreviewViewController : UIViewController
@property (nonatomic, weak, nullable) id<RPPreviewViewControllerDelegate> previewControllerDelegate;
@property (nonatomic) RPPreviewViewControllerMode mode;
@end

@protocol RPScreenRecorderDelegate <NSObject>
@optional
- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithPreviewViewController:(nullable RPPreviewViewController *)previewViewController
                 error:(nullable NSError *)error;
- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithError:(NSError *)error
 previewViewController:(nullable RPPreviewViewController *)previewViewController API_DEPRECATED("", ios(9.0, 10.0));
- (void)screenRecorderDidChangeAvailability:(RPScreenRecorder *)screenRecorder;
@end

@interface RPScreenRecorder : NSObject
+ (RPScreenRecorder *)sharedRecorder;
- (void)startRecordingWithHandler:(nullable void (^)(NSError *_Nullable error))handler;
- (void)startRecordingWithMicrophoneEnabled:(BOOL)microphoneEnabled handler:(nullable void (^)(NSError *_Nullable error))handler
    API_DEPRECATED("Use microphoneEnabled property", ios(9.0, 10.0));
- (void)stopRecordingWithHandler:(nullable void (^)(RPPreviewViewController *_Nullable previewViewController, NSError *_Nullable error))handler;
- (void)stopRecordingWithOutputURL:(NSURL *)url completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)discardRecordingWithHandler:(void (^)(void))handler;
- (void)startCaptureWithHandler:(nullable void (^)(CMSampleBufferRef sampleBuffer, RPSampleBufferType bufferType, NSError *_Nullable error))captureHandler
              completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)stopCaptureWithHandler:(nullable void (^)(NSError *_Nullable error))handler;
- (void)startClipBufferingWithCompletionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)stopClipBufferingWithCompletionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)exportClipToURL:(NSURL *)url duration:(NSTimeInterval)duration completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
@property (nonatomic, weak, nullable) id<RPScreenRecorderDelegate> delegate;
@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, getter=isMicrophoneEnabled) BOOL microphoneEnabled;
@property (nonatomic, readonly, getter=isAvailable) BOOL available;
@property (nonatomic, getter=isCameraEnabled) BOOL cameraEnabled;
@property (nonatomic) RPCameraPosition cameraPosition;
@property (nonatomic, readonly, nullable) UIView *cameraPreviewView;
- (instancetype)init NS_UNAVAILABLE;
@end

@protocol RPBroadcastControllerDelegate <NSObject>
@optional
- (void)broadcastController:(RPBroadcastController *)broadcastController didFinishWithError:(nullable NSError *)error;
- (void)broadcastController:(RPBroadcastController *)broadcastController didUpdateServiceInfo:(NSDictionary<NSString *, NSObject<NSCoding> *> *)serviceInfo;
- (void)broadcastController:(RPBroadcastController *)broadcastController didUpdateBroadcastURL:(NSURL *)broadcastURL;
@end

@interface RPBroadcastController : NSObject
@property (nonatomic, readonly, getter=isBroadcasting) BOOL broadcasting;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) NSURL *broadcastURL;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSObject<NSCoding> *> *serviceInfo;
@property (nonatomic, weak, nullable) id<RPBroadcastControllerDelegate> delegate;
@property (nonatomic, readonly, nullable) NSString *broadcastExtensionBundleID;
- (void)startBroadcastWithHandler:(void (^)(NSError *_Nullable error))handler;
- (void)pauseBroadcast;
- (void)resumeBroadcast;
- (void)finishBroadcastWithHandler:(void (^)(NSError *_Nullable error))handler;
@end

@protocol RPBroadcastActivityViewControllerDelegate <NSObject>
- (void)broadcastActivityViewController:(RPBroadcastActivityViewController *)broadcastActivityViewController
       didFinishWithBroadcastController:(nullable RPBroadcastController *)broadcastController error:(nullable NSError *)error;
@end

@interface RPBroadcastActivityViewController : UIViewController
+ (void)loadBroadcastActivityViewControllerWithHandler:(void (^)(RPBroadcastActivityViewController *_Nullable broadcastActivityViewController,
                                                                 NSError *_Nullable error))handler;
+ (void)loadBroadcastActivityViewControllerWithPreferredExtension:(nullable NSString *)preferredExtension
    handler:(void (^)(RPBroadcastActivityViewController *_Nullable broadcastActivityViewController, NSError *_Nullable error))handler;
@property (nonatomic, weak, nullable) id<RPBroadcastActivityViewControllerDelegate> delegate;
@end

@interface RPSystemBroadcastPickerView : UIView
@property (nonatomic, strong, nullable) NSString *preferredExtension;
@property (nonatomic, assign) BOOL showsMicrophoneButton;
@end

@interface RPBroadcastConfiguration : NSObject <NSSecureCoding>
@property (nonatomic, assign) NSTimeInterval clipDuration;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSObject<NSSecureCoding> *> *videoCompressionProperties;
@end

@interface RPBroadcastHandler : NSObject
- (void)updateServiceInfo:(NSDictionary<NSString *, NSObject<NSCoding> *> *)serviceInfo;
- (void)updateBroadcastURL:(NSURL *)broadcastURL;
@end

@interface RPBroadcastSampleHandler : RPBroadcastHandler
- (void)broadcastStartedWithSetupInfo:(nullable NSDictionary<NSString *, NSObject *> *)setupInfo;
- (void)broadcastPaused;
- (void)broadcastResumed;
- (void)broadcastFinished;
- (void)broadcastAnnotatedWithApplicationInfo:(NSDictionary *)applicationInfo;
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType;
- (void)finishBroadcastWithError:(NSError *)error;
@end

@interface RPBroadcastMP4ClipHandler : RPBroadcastHandler
- (void)processMP4ClipWithURL:(nullable NSURL *)mp4ClipURL setupInfo:(nullable NSDictionary<NSString *, NSObject *> *)setupInfo finished:(BOOL)finished;
- (void)finishedProcessingMP4ClipWithUpdatedBroadcastConfiguration:(nullable RPBroadcastConfiguration *)broadcastConfiguration error:(nullable NSError *)error;
@end
NS_ASSUME_NONNULL_END
#endif
