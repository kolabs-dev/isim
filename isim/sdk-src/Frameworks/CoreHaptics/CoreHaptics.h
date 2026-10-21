#pragma once
/* isim CoreHaptics for Objective-C: the classes are the CoreHaptics Swift overlay's (CoreHaptics.framework re-exports
   libswiftCoreHaptics.dylib): patterns, events and parameter curves; the engine plays audio events through isim's audio
   output and reports haptics as unsupported, like the Simulator (no Taptic Engine; a game controller's engine rumbles).
   Swift uses the overlay; these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define CH_EXPORT extern "C"
#else
#define CH_EXPORT extern
#endif
CH_EXPORT NSString * const CHHapticErrorDomain API_AVAILABLE(ios(13.0));
typedef NS_ENUM(NSInteger, CHHapticErrorCode) {
    CHHapticErrorCodeEngineNotRunning = -4805, CHHapticErrorCodeOperationNotPermitted = -4806, CHHapticErrorCodeEngineStartTimeout = -4808,
    CHHapticErrorCodeNotSupported = -4809, CHHapticErrorCodeServerInitFailed = -4810, CHHapticErrorCodeServerInterrupted = -4811,
    CHHapticErrorCodeInvalidPatternPlayer = -4812, CHHapticErrorCodeInvalidPatternData = -4813, CHHapticErrorCodeInvalidPatternDictionary = -4814,
    CHHapticErrorCodeInvalidAudioSession = -4815, CHHapticErrorCodeInvalidEngineParameter = -4816, CHHapticErrorCodeInvalidParameterType = -4820,
    CHHapticErrorCodeInvalidEventType = -4821, CHHapticErrorCodeInvalidEventTime = -4822, CHHapticErrorCodeInvalidEventDuration = -4823,
    CHHapticErrorCodeInvalidAudioResource = -4824, CHHapticErrorCodeResourceNotAvailable = -4825, CHHapticErrorCodeBadEventEntry = -4830,
    CHHapticErrorCodeBadParameterEntry = -4831, CHHapticErrorCodeInvalidTime = -4840, CHHapticErrorCodeFileNotFound = -4851,
    CHHapticErrorCodeInsufficientPower = -4897, CHHapticErrorCodeUnknownError = -4898, CHHapticErrorCodeMemoryError = -4899,
} API_AVAILABLE(ios(13.0));
static const NSTimeInterval CHHapticTimeImmediate = 0.0;
typedef NSUInteger CHHapticAudioResourceID;
typedef NSString *CHHapticEventParameterID NS_TYPED_ENUM;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDHapticIntensity;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDHapticSharpness;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDAttackTime;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDDecayTime;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDReleaseTime;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDSustained;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDAudioVolume;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDAudioPitch;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDAudioPan;
CH_EXPORT CHHapticEventParameterID const CHHapticEventParameterIDAudioBrightness;
typedef NSString *CHHapticDynamicParameterID NS_TYPED_ENUM;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticIntensityControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticSharpnessControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticAttackTimeControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticDecayTimeControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticReleaseTimeControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioVolumeControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioPanControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioBrightnessControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioPitchControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioAttackTimeControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioDecayTimeControl;
CH_EXPORT CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioReleaseTimeControl;
typedef NSString *CHHapticEventType NS_TYPED_ENUM;
CH_EXPORT CHHapticEventType const CHHapticEventTypeHapticTransient;
CH_EXPORT CHHapticEventType const CHHapticEventTypeHapticContinuous;
CH_EXPORT CHHapticEventType const CHHapticEventTypeAudioContinuous;
CH_EXPORT CHHapticEventType const CHHapticEventTypeAudioCustom;
typedef NSString *CHHapticPatternKey NS_TYPED_ENUM;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyVersion;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyPattern;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyEvent;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyEventType;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyTime;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyEventDuration;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyEventWaveformPath;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyEventParameters;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyEventWaveformUseVolumeEnvelope;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyParameter;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyParameterID;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyParameterValue;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyParameterCurve;
CH_EXPORT CHHapticPatternKey const CHHapticPatternKeyParameterCurveControlPoints;
typedef NSString *CHHapticAudioResourceKey NS_TYPED_ENUM;
CH_EXPORT CHHapticAudioResourceKey const CHHapticAudioResourceKeyUseVolumeEnvelope;
CH_EXPORT CHHapticAudioResourceKey const CHHapticAudioResourceKeyLoopEnabled;

API_AVAILABLE(ios(13.0))
@interface CHHapticEventParameter : NSObject
@property (readonly) CHHapticEventParameterID parameterID;
@property (readwrite) float value;
- (instancetype)initWithParameterID:(CHHapticEventParameterID)parameterID value:(float)value;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(13.0))
@interface CHHapticDynamicParameter : NSObject
@property (readonly) CHHapticDynamicParameterID parameterID;
@property (readwrite) float value;
@property (readwrite) NSTimeInterval relativeTime;
- (instancetype)initWithParameterID:(CHHapticDynamicParameterID)parameterID value:(float)value relativeTime:(NSTimeInterval)time;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(13.0))
@interface CHHapticParameterCurveControlPoint : NSObject
@property (readwrite) NSTimeInterval relativeTime;
@property (readwrite) float value;
- (instancetype)initWithRelativeTime:(NSTimeInterval)time value:(float)value;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(13.0))
@interface CHHapticParameterCurve : NSObject
@property (readonly) CHHapticDynamicParameterID parameterID;
@property (readwrite) NSTimeInterval relativeTime;
@property (readonly) NSArray<CHHapticParameterCurveControlPoint *> *controlPoints;
- (instancetype)initWithParameterID:(CHHapticDynamicParameterID)parameterID controlPoints:(NSArray<CHHapticParameterCurveControlPoint *> *)controlPoints relativeTime:(NSTimeInterval)relativeTime;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(13.0))
@interface CHHapticEvent : NSObject
@property (readwrite) CHHapticEventType type;
@property (readonly) NSArray<CHHapticEventParameter *> *eventParameters;
@property (readwrite) NSTimeInterval relativeTime;
@property (readwrite) NSTimeInterval duration;
- (instancetype)initWithEventType:(CHHapticEventType)type parameters:(NSArray<CHHapticEventParameter *> *)eventParams relativeTime:(NSTimeInterval)time;
- (instancetype)initWithEventType:(CHHapticEventType)type parameters:(NSArray<CHHapticEventParameter *> *)eventParams relativeTime:(NSTimeInterval)time duration:(NSTimeInterval)duration;
- (instancetype)initWithAudioResourceID:(CHHapticAudioResourceID)resID parameters:(NSArray<CHHapticEventParameter *> *)eventParams relativeTime:(NSTimeInterval)time;
- (instancetype)initWithAudioResourceID:(CHHapticAudioResourceID)resID parameters:(NSArray<CHHapticEventParameter *> *)eventParams relativeTime:(NSTimeInterval)time duration:(NSTimeInterval)duration;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(13.0))
@interface CHHapticPattern : NSObject
@property (readonly) NSTimeInterval duration;
- (nullable instancetype)initWithEvents:(NSArray<CHHapticEvent *> *)events parameters:(NSArray<CHHapticDynamicParameter *> *)parameters error:(NSError **)outError;
- (nullable instancetype)initWithEvents:(NSArray<CHHapticEvent *> *)events parameterCurves:(NSArray<CHHapticParameterCurve *> *)parameterCurves error:(NSError **)outError;
- (nullable instancetype)initWithDictionary:(NSDictionary<CHHapticPatternKey, id> *)patternDict error:(NSError **)outError;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)ahapURL error:(NSError **)outError API_AVAILABLE(ios(16.0));
- (nullable NSDictionary<CHHapticPatternKey, id> *)exportDictionaryAndReturnError:(NSError **)outError API_AVAILABLE(ios(17.0));
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(13.0))
@protocol CHHapticParameterAttributes <NSObject>
@property (readonly) float minValue;
@property (readonly) float maxValue;
@property (readonly) float defaultValue;
@end
/* isim: no haptics (supportsHaptics is NO, like the Simulator), audio supported */
API_AVAILABLE(ios(13.0))
@protocol CHHapticDeviceCapability <NSObject>
@property (readonly) BOOL supportsHaptics;
@property (readonly) BOOL supportsAudio;
- (nullable id<CHHapticParameterAttributes>)attributesForEventParameter:(CHHapticEventParameterID)inParameter eventType:(CHHapticEventType)type error:(NSError **)outError;
- (nullable id<CHHapticParameterAttributes>)attributesForDynamicParameter:(CHHapticDynamicParameterID)inParameter error:(NSError **)outError;
@end
API_AVAILABLE(ios(13.0))
@protocol CHHapticPatternPlayer <NSObject>
- (BOOL)startAtTime:(NSTimeInterval)time error:(NSError **)outError;
- (BOOL)stopAtTime:(NSTimeInterval)time error:(NSError **)outError;
- (BOOL)sendParameters:(NSArray<CHHapticDynamicParameter *> *)parameters atTime:(NSTimeInterval)time error:(NSError **)outError;
- (BOOL)scheduleParameterCurve:(CHHapticParameterCurve *)parameterCurve atTime:(NSTimeInterval)time error:(NSError **)outError;
- (BOOL)cancelAndReturnError:(NSError **)outError;
@property (readwrite) BOOL isMuted;
@end
typedef void (^CHHapticAdvancedPatternPlayerCompletionHandler)(NSError * _Nullable error);
API_AVAILABLE(ios(13.0))
@protocol CHHapticAdvancedPatternPlayer <CHHapticPatternPlayer>
- (BOOL)pauseAtTime:(NSTimeInterval)time error:(NSError **)outError;
- (BOOL)resumeAtTime:(NSTimeInterval)time error:(NSError **)outError;
- (BOOL)seekToOffset:(NSTimeInterval)offsetTime error:(NSError **)outError;
@property (readwrite) BOOL loopEnabled;
@property (readwrite) NSTimeInterval loopEnd;
@property (readwrite) float playbackRate;
@property (readwrite, nullable) CHHapticAdvancedPatternPlayerCompletionHandler completionHandler;
@end
typedef NS_ENUM(NSInteger, CHHapticEngineFinishedAction) {
    CHHapticEngineFinishedActionStopEngine = 1, CHHapticEngineFinishedActionLeaveEngineRunning = 2,
} API_AVAILABLE(ios(13.0));
typedef NS_ENUM(NSInteger, CHHapticEngineStoppedReason) {
    CHHapticEngineStoppedReasonAudioSessionInterrupt = 1, CHHapticEngineStoppedReasonApplicationSuspended = 2,
    CHHapticEngineStoppedReasonIdleTimeout = 3, CHHapticEngineStoppedReasonNotifyWhenFinished = 4, CHHapticEngineStoppedReasonEngineDestroyed = 5,
    CHHapticEngineStoppedReasonGameControllerDisconnect = 6, CHHapticEngineStoppedReasonSystemError = -1,
} API_AVAILABLE(ios(13.0));
typedef void (^CHHapticCompletionHandler)(NSError * _Nullable error);
typedef CHHapticEngineFinishedAction (^CHHapticEngineFinishedHandler)(NSError * _Nullable error);
typedef void (^CHHapticEngineStoppedHandler)(CHHapticEngineStoppedReason stoppedReason);
typedef void (^CHHapticEngineResetHandler)(void);
API_AVAILABLE(ios(13.0))
@interface CHHapticEngine : NSObject
+ (id<CHHapticDeviceCapability>)capabilitiesForHardware;
@property (readonly) NSTimeInterval currentTime;
@property (nonatomic, copy) CHHapticEngineStoppedHandler stoppedHandler;
@property (nonatomic, copy) CHHapticEngineResetHandler resetHandler;
@property (nonatomic, readwrite) BOOL playsHapticsOnly;
@property (nonatomic, readwrite) BOOL playsAudioOnly API_AVAILABLE(ios(16.0));
@property (nonatomic, readwrite) BOOL isMutedForAudio;
@property (nonatomic, readwrite) BOOL isMutedForHaptics;
@property (nonatomic, readwrite, getter=isAutoShutdownEnabled) BOOL autoShutdownEnabled;
- (nullable instancetype)initAndReturnError:(NSError **)error;
- (nullable instancetype)initWithAudioSession:(nullable id)audioSession error:(NSError **)error;
- (void)startWithCompletionHandler:(nullable CHHapticCompletionHandler)completionHandler;
- (BOOL)startAndReturnError:(NSError **)outError;
- (void)stopWithCompletionHandler:(nullable CHHapticCompletionHandler)completionHandler;
- (void)notifyWhenPlayersFinished:(CHHapticEngineFinishedHandler)finishedHandler;
- (nullable id<CHHapticPatternPlayer>)createPlayerWithPattern:(CHHapticPattern *)pattern error:(NSError **)outError;
- (nullable id<CHHapticAdvancedPatternPlayer>)createAdvancedPlayerWithPattern:(CHHapticPattern *)pattern error:(NSError **)outError;
- (CHHapticAudioResourceID)registerAudioResource:(NSURL *)resourceURL options:(NSDictionary *)options error:(NSError **)outError;
- (BOOL)unregisterAudioResource:(CHHapticAudioResourceID)resourceID error:(NSError **)outError;
- (BOOL)playPatternFromURL:(NSURL *)fileURL error:(NSError **)outError;
- (BOOL)playPatternFromData:(NSData *)data error:(NSError **)outError;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
