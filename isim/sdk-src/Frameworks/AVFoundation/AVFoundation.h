#pragma once
/* isim AVFoundation for Objective-C: the classes are the AVFoundation Swift overlay's (AVFoundation.framework re-exports
   libswiftAVFoundation.dylib): the audio session, assets, players, player items and the player layer (media decoded
   by the host's FFmpeg; see the overlay). Swift uses the overlay; these declarations are hidden from Swift. AVFAudio's
   classes (the engine, formats, buffers, audio players and recorders) are in <AVFAudio/AVFAudio.h>, imported at the end.
   Not available from Objective-C yet: capture, editing and export, readers and writers. The classes are not
   subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class AVAssetTrack, AVPlayerItem;
typedef NSString *AVAudioSessionCategory NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *AVAudioSessionMode NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *AVAudioSessionPort NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *AVMediaType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *AVLayerVideoGravity NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT AVAudioSessionCategory const AVAudioSessionCategoryAmbient, AVAudioSessionCategorySoloAmbient, AVAudioSessionCategoryPlayback,
    AVAudioSessionCategoryRecord, AVAudioSessionCategoryPlayAndRecord, AVAudioSessionCategoryMultiRoute;
FOUNDATION_EXPORT AVAudioSessionMode const AVAudioSessionModeDefault, AVAudioSessionModeGameChat, AVAudioSessionModeMoviePlayback,
    AVAudioSessionModeSpokenAudio, AVAudioSessionModeVoiceChat, AVAudioSessionModeVideoChat, AVAudioSessionModeVideoRecording,
    AVAudioSessionModeMeasurement, AVAudioSessionModeVoicePrompt;
FOUNDATION_EXPORT AVAudioSessionPort const AVAudioSessionPortBuiltInSpeaker, AVAudioSessionPortBuiltInReceiver, AVAudioSessionPortBuiltInMic,
    AVAudioSessionPortHeadphones, AVAudioSessionPortHeadsetMic, AVAudioSessionPortBluetoothA2DP, AVAudioSessionPortBluetoothHFP,
    AVAudioSessionPortBluetoothLE, AVAudioSessionPortCarAudio, AVAudioSessionPortAirPlay, AVAudioSessionPortHDMI, AVAudioSessionPortUSBAudio,
    AVAudioSessionPortLineOut, AVAudioSessionPortLineIn;
FOUNDATION_EXPORT NSNotificationName const AVAudioSessionInterruptionNotification, AVAudioSessionRouteChangeNotification,
    AVAudioSessionMediaServicesWereResetNotification, AVAudioSessionSilenceSecondaryAudioHintNotification;
FOUNDATION_EXPORT NSString * const AVAudioSessionInterruptionTypeKey, * const AVAudioSessionInterruptionOptionKey,
    * const AVAudioSessionRouteChangeReasonKey, * const AVAudioSessionRouteChangePreviousRouteKey;
FOUNDATION_EXPORT AVMediaType const AVMediaTypeVideo, AVMediaTypeAudio, AVMediaTypeText;
FOUNDATION_EXPORT AVLayerVideoGravity const AVLayerVideoGravityResizeAspect, AVLayerVideoGravityResizeAspectFill, AVLayerVideoGravityResize;
FOUNDATION_EXPORT NSNotificationName const AVPlayerItemDidPlayToEndTimeNotification, AVPlayerItemFailedToPlayToEndTimeNotification,
    AVPlayerItemPlaybackStalledNotification;
typedef NS_OPTIONS(NSUInteger, AVAudioSessionCategoryOptions) {
    AVAudioSessionCategoryOptionMixWithOthers = 0x1, AVAudioSessionCategoryOptionDuckOthers = 0x2, AVAudioSessionCategoryOptionAllowBluetooth = 0x4,
    AVAudioSessionCategoryOptionDefaultToSpeaker = 0x8, AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers = 0x11,
    AVAudioSessionCategoryOptionAllowBluetoothA2DP = 0x20, AVAudioSessionCategoryOptionAllowAirPlay = 0x40,
    AVAudioSessionCategoryOptionOverrideMutedMicrophoneInterruption = 0x80,
};
typedef NS_ENUM(NSUInteger, AVAudioSessionRouteSharingPolicy) {
    AVAudioSessionRouteSharingPolicyDefault = 0, AVAudioSessionRouteSharingPolicyLongFormAudio = 1,
    AVAudioSessionRouteSharingPolicyLongForm __attribute__((deprecated("use AVAudioSessionRouteSharingPolicyLongFormAudio"))) = 1,
    AVAudioSessionRouteSharingPolicyIndependent = 2, AVAudioSessionRouteSharingPolicyLongFormVideo = 3,
};
typedef NS_OPTIONS(NSUInteger, AVAudioSessionSetActiveOptions) { AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation = 1 };

@interface AVAudioSessionPortDescription : NSObject
@property (readonly, nonatomic) AVAudioSessionPort portType;
@property (readonly, nonatomic) NSString *portName;
@property (readonly, nonatomic) NSString *UID;
@end
@interface AVAudioSessionRouteDescription : NSObject
@property (readonly, nonatomic) NSArray<AVAudioSessionPortDescription *> *inputs;
@property (readonly, nonatomic) NSArray<AVAudioSessionPortDescription *> *outputs;
@end
@interface AVAudioSession : NSObject
+ (AVAudioSession *)sharedInstance;
@property (readonly) AVAudioSessionCategory category;
@property (readonly) AVAudioSessionMode mode;
@property (readonly) AVAudioSessionCategoryOptions categoryOptions;
- (BOOL)setCategory:(AVAudioSessionCategory)category error:(NSError **)outError;
- (BOOL)setCategory:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError;
- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError;
- (BOOL)setMode:(AVAudioSessionMode)mode error:(NSError **)outError;
- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode routeSharingPolicy:(AVAudioSessionRouteSharingPolicy)policy
            options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError;
@property (readonly) AVAudioSessionRouteSharingPolicy routeSharingPolicy;
@property (readonly) BOOL prefersNoInterruptionsFromSystemAlerts;
- (BOOL)setPrefersNoInterruptionsFromSystemAlerts:(BOOL)inValue error:(NSError **)outError;
@property (readonly) BOOL prefersEchoCancelledInput API_AVAILABLE(ios(18.2));
- (BOOL)setPrefersEchoCancelledInput:(BOOL)value error:(NSError **)error API_AVAILABLE(ios(18.2));
@property (readonly, getter=isEchoCancelledInputEnabled) BOOL echoCancelledInputEnabled API_AVAILABLE(ios(18.2));
@property (readonly, getter=isEchoCancelledInputAvailable) BOOL echoCancelledInputAvailable API_AVAILABLE(ios(18.2));
- (BOOL)setActive:(BOOL)active error:(NSError **)outError;
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError;
@property (readonly) float outputVolume;
@property (readonly) double sampleRate;
@property (readonly) NSInteger outputNumberOfChannels;
@property (readonly, getter=isOtherAudioPlaying) BOOL otherAudioPlaying;
@property (readonly) BOOL secondaryAudioShouldBeSilencedHint;
@property (readonly) AVAudioSessionRouteDescription *currentRoute;
@end

typedef NS_ENUM(NSInteger, AVKeyValueStatus) { AVKeyValueStatusUnknown, AVKeyValueStatusLoading, AVKeyValueStatusLoaded, AVKeyValueStatusFailed, AVKeyValueStatusCancelled };
@interface AVAsset : NSObject
+ (instancetype)assetWithURL:(NSURL *)URL;
@property (nonatomic, readonly) CMTime duration;
@property (nonatomic, readonly) NSArray<AVAssetTrack *> *tracks;
- (NSArray<AVAssetTrack *> *)tracksWithMediaType:(AVMediaType)mediaType;
@property (nonatomic, readonly, getter=isPlayable) BOOL playable;
- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys completionHandler:(nullable void (^)(void))handler;
- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError * _Nullable * _Nullable)outError;
@end
@interface AVURLAsset : AVAsset
+ (instancetype)URLAssetWithURL:(NSURL *)URL options:(nullable NSDictionary<NSString *, id> *)options;
- (instancetype)initWithURL:(NSURL *)URL options:(nullable NSDictionary<NSString *, id> *)options;
@property (nonatomic, readonly, copy) NSURL *URL;
@end
@interface AVAssetTrack : NSObject
@property (nonatomic, readonly) AVMediaType mediaType;
@property (nonatomic, readonly) CGSize naturalSize;
@property (nonatomic, readonly) float nominalFrameRate;
@property (nonatomic, readonly) float estimatedDataRate;
@end

typedef NS_ENUM(NSInteger, AVPlayerItemStatus) { AVPlayerItemStatusUnknown, AVPlayerItemStatusReadyToPlay, AVPlayerItemStatusFailed };
@interface AVPlayerItem : NSObject
+ (instancetype)playerItemWithURL:(NSURL *)URL;
+ (instancetype)playerItemWithAsset:(AVAsset *)asset;
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithAsset:(AVAsset *)asset;
- (instancetype)initWithAsset:(AVAsset *)asset automaticallyLoadedAssetKeys:(nullable NSArray<NSString *> *)automaticallyLoadedAssetKeys;
@property (nonatomic, readonly) AVPlayerItemStatus status;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly) AVAsset *asset;
@property (nonatomic, readonly) CMTime duration;
@property (nonatomic, readonly) CGSize presentationSize;
- (CMTime)currentTime;
- (void)seekToTime:(CMTime)time completionHandler:(nullable void (^)(BOOL finished))completionHandler;
- (void)cancelPendingSeeks;
@property (nonatomic, readonly) NSArray<NSValue *> *loadedTimeRanges;
@property (nonatomic, readonly) NSArray<NSValue *> *seekableTimeRanges;
@property (nonatomic, readonly, getter=isPlaybackLikelyToKeepUp) BOOL playbackLikelyToKeepUp;
@property (nonatomic, readonly, getter=isPlaybackBufferFull) BOOL playbackBufferFull;
@property (nonatomic, readonly, getter=isPlaybackBufferEmpty) BOOL playbackBufferEmpty;
@property (nonatomic) NSTimeInterval preferredForwardBufferDuration;
@property (nonatomic) double preferredPeakBitRate;
@property (nonatomic) BOOL canUseNetworkResourcesForLiveStreamingWhilePaused;
@end

typedef NS_ENUM(NSInteger, AVPlayerStatus) { AVPlayerStatusUnknown, AVPlayerStatusReadyToPlay, AVPlayerStatusFailed };
typedef NS_ENUM(NSInteger, AVPlayerTimeControlStatus) { AVPlayerTimeControlStatusPaused, AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate, AVPlayerTimeControlStatusPlaying };
typedef NS_ENUM(NSInteger, AVPlayerActionAtItemEnd) { AVPlayerActionAtItemEndAdvance, AVPlayerActionAtItemEndPause, AVPlayerActionAtItemEndNone };
@interface AVPlayer : NSObject
+ (instancetype)playerWithURL:(NSURL *)URL;
+ (instancetype)playerWithPlayerItem:(nullable AVPlayerItem *)item;
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithPlayerItem:(nullable AVPlayerItem *)item;
@property (nonatomic, readonly) AVPlayerStatus status;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic) float rate;
@property (nonatomic) float defaultRate;
- (void)play;
- (void)pause;
- (void)playImmediatelyAtRate:(float)rate;
@property (nonatomic, readonly) AVPlayerTimeControlStatus timeControlStatus;
@property (nonatomic, readonly, nullable) AVPlayerItem *currentItem;
- (void)replaceCurrentItemWithPlayerItem:(nullable AVPlayerItem *)item;
@property (nonatomic) AVPlayerActionAtItemEnd actionAtItemEnd;
- (CMTime)currentTime;
- (void)seekToTime:(CMTime)time;
- (void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler;
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval queue:(nullable dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))block;
- (id)addBoundaryTimeObserverForTimes:(NSArray<NSValue *> *)times queue:(nullable dispatch_queue_t)queue usingBlock:(void (^)(void))block;
- (void)removeTimeObserver:(id)observer;
@property (nonatomic) float volume;
@property (nonatomic, getter=isMuted) BOOL muted;
@property (nonatomic) BOOL automaticallyWaitsToMinimizeStalling;
@property (nonatomic) BOOL preventsDisplaySleepDuringVideoPlayback;
@property (nonatomic) BOOL allowsExternalPlayback;
@property (nonatomic, readonly, getter=isExternalPlaybackActive) BOOL externalPlaybackActive;
@end
@interface AVQueuePlayer : AVPlayer
@end
@interface AVPlayerLayer : CALayer
+ (AVPlayerLayer *)playerLayerWithPlayer:(nullable AVPlayer *)player;
@property (nonatomic, retain, nullable) AVPlayer *player;
@property (copy) AVLayerVideoGravity videoGravity;
@property (nonatomic, readonly, getter=isReadyForDisplay) BOOL readyForDisplay;
@property (nonatomic, readonly) CGRect videoRect;
@end
NS_ASSUME_NONNULL_END
#import <AVFAudio/AVFAudio.h>
#else
@class AVAudioSession, AVAsset, AVURLAsset, AVPlayer, AVPlayerItem, AVPlayerLayer;
#endif
