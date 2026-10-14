// isim AVFoundation for Objective-C: the C constants (the values the AVFoundation Swift overlay uses), and the methods
// that take or return a CMTime, which the overlay's classes cannot declare: they use the `_isim_` entry points of the
// overlay's ObjC.swift, which pass a CMTime as its four fields.
#import <AVFoundation/AVFoundation.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes

AVAudioSessionCategory const AVAudioSessionCategoryAmbient = @"AVAudioSessionCategoryAmbient";
AVAudioSessionCategory const AVAudioSessionCategorySoloAmbient = @"AVAudioSessionCategorySoloAmbient";
AVAudioSessionCategory const AVAudioSessionCategoryPlayback = @"AVAudioSessionCategoryPlayback";
AVAudioSessionCategory const AVAudioSessionCategoryRecord = @"AVAudioSessionCategoryRecord";
AVAudioSessionCategory const AVAudioSessionCategoryPlayAndRecord = @"AVAudioSessionCategoryPlayAndRecord";
AVAudioSessionCategory const AVAudioSessionCategoryMultiRoute = @"AVAudioSessionCategoryMultiRoute";
AVAudioSessionMode const AVAudioSessionModeDefault = @"AVAudioSessionModeDefault";
AVAudioSessionMode const AVAudioSessionModeGameChat = @"AVAudioSessionModeGameChat";
AVAudioSessionMode const AVAudioSessionModeMoviePlayback = @"AVAudioSessionModeMoviePlayback";
AVAudioSessionMode const AVAudioSessionModeSpokenAudio = @"AVAudioSessionModeSpokenAudio";
AVAudioSessionMode const AVAudioSessionModeVoiceChat = @"AVAudioSessionModeVoiceChat";
AVAudioSessionMode const AVAudioSessionModeVideoChat = @"AVAudioSessionModeVideoChat";
AVAudioSessionMode const AVAudioSessionModeVideoRecording = @"AVAudioSessionModeVideoRecording";
AVAudioSessionMode const AVAudioSessionModeMeasurement = @"AVAudioSessionModeMeasurement";
AVAudioSessionMode const AVAudioSessionModeVoicePrompt = @"AVAudioSessionModeVoicePrompt";
AVAudioSessionPort const AVAudioSessionPortBuiltInSpeaker = @"Speaker";
AVAudioSessionPort const AVAudioSessionPortBuiltInReceiver = @"Receiver";
AVAudioSessionPort const AVAudioSessionPortBuiltInMic = @"MicrophoneBuiltIn";
AVAudioSessionPort const AVAudioSessionPortHeadphones = @"Headphones";
AVAudioSessionPort const AVAudioSessionPortHeadsetMic = @"MicrophoneWired";
AVAudioSessionPort const AVAudioSessionPortBluetoothA2DP = @"BluetoothA2DPOutput";
AVAudioSessionPort const AVAudioSessionPortBluetoothHFP = @"BluetoothHFP";
AVAudioSessionPort const AVAudioSessionPortBluetoothLE = @"BluetoothLE";
AVAudioSessionPort const AVAudioSessionPortCarAudio = @"CarAudio";
AVAudioSessionPort const AVAudioSessionPortAirPlay = @"AirPlay";
AVAudioSessionPort const AVAudioSessionPortHDMI = @"HDMIOutput";
AVAudioSessionPort const AVAudioSessionPortUSBAudio = @"USBAudio";
AVAudioSessionPort const AVAudioSessionPortLineOut = @"LineOut";
AVAudioSessionPort const AVAudioSessionPortLineIn = @"LineIn";
NSNotificationName const AVAudioSessionInterruptionNotification = @"AVAudioSessionInterruptionNotification";
NSNotificationName const AVAudioSessionRouteChangeNotification = @"AVAudioSessionRouteChangeNotification";
NSNotificationName const AVAudioSessionMediaServicesWereResetNotification = @"AVAudioSessionMediaServicesWereResetNotification";
NSNotificationName const AVAudioSessionSilenceSecondaryAudioHintNotification = @"AVAudioSessionSilenceSecondaryAudioHintNotification";
NSString * const AVAudioSessionInterruptionTypeKey = @"AVAudioSessionInterruptionTypeKey";
NSString * const AVAudioSessionInterruptionOptionKey = @"AVAudioSessionInterruptionOptionKey";
NSString * const AVAudioSessionRouteChangeReasonKey = @"AVAudioSessionRouteChangeReasonKey";
NSString * const AVAudioSessionRouteChangePreviousRouteKey = @"AVAudioSessionRouteChangePreviousRouteKey";
AVMediaType const AVMediaTypeVideo = @"vide";
AVMediaType const AVMediaTypeAudio = @"soun";
AVMediaType const AVMediaTypeText = @"text";
AVLayerVideoGravity const AVLayerVideoGravityResizeAspect = @"AVLayerVideoGravityResizeAspect";
AVLayerVideoGravity const AVLayerVideoGravityResizeAspectFill = @"AVLayerVideoGravityResizeAspectFill";
AVLayerVideoGravity const AVLayerVideoGravityResize = @"AVLayerVideoGravityResize";
NSNotificationName const AVPlayerItemDidPlayToEndTimeNotification = @"AVPlayerItemDidPlayToEndTimeNotification";
NSNotificationName const AVPlayerItemFailedToPlayToEndTimeNotification = @"AVPlayerItemFailedToPlayToEndTimeNotification";
NSNotificationName const AVPlayerItemPlaybackStalledNotification = @"AVPlayerItemPlaybackStalledNotification";

static CMTime time_of(NSArray<NSNumber *> *p) {
    if (p.count < 4) return kCMTimeInvalid;
    return (CMTime){ p[0].longLongValue, p[1].intValue, p[2].unsignedIntValue, p[3].longLongValue };
}

@interface AVAsset (ISIMTime)
- (NSArray<NSNumber *> *)_isim_duration;
@end
@interface AVPlayerItem (ISIMTime)
- (NSArray<NSNumber *> *)_isim_duration;
- (NSArray<NSNumber *> *)_isim_currentTime;
- (void)_isim_seekValue:(int64_t)v timescale:(int32_t)ts flags:(uint32_t)f epoch:(int64_t)e completionHandler:(void (^)(BOOL))done;
@end
@interface AVPlayer (ISIMTime)
- (NSArray<NSNumber *> *)_isim_currentTime;
- (void)_isim_seekValue:(int64_t)v timescale:(int32_t)ts flags:(uint32_t)f epoch:(int64_t)e completionHandler:(void (^)(BOOL))done;
- (id)_isim_addPeriodicTimeObserverValue:(int64_t)v timescale:(int32_t)ts usingBlock:(void (^)(NSArray<NSNumber *> *))block;
- (id)_isim_addBoundaryTimeObserverForTimes:(NSArray<NSValue *> *)times usingBlock:(void (^)(void))block;
@end

@implementation AVAsset (ISIMCMTime)
- (CMTime)duration { return time_of([self _isim_duration]); }
@end
@implementation AVPlayerItem (ISIMCMTime)
- (CMTime)duration { return time_of([self _isim_duration]); }
- (CMTime)currentTime { return time_of([self _isim_currentTime]); }
- (void)seekToTime:(CMTime)t completionHandler:(void (^)(BOOL))done {
    [self _isim_seekValue:t.value timescale:t.timescale flags:t.flags epoch:t.epoch completionHandler:done];
}
@end
@implementation AVPlayer (ISIMCMTime)
- (CMTime)currentTime { return time_of([self _isim_currentTime]); }
- (void)seekToTime:(CMTime)t { [self seekToTime:t completionHandler:^(BOOL finished) {}]; }
- (void)seekToTime:(CMTime)t completionHandler:(void (^)(BOOL))done {
    [self _isim_seekValue:t.value timescale:t.timescale flags:t.flags epoch:t.epoch completionHandler:done];
}
/* the overlay's observers call back on the main queue; another queue gets the call from there */
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval queue:(dispatch_queue_t)queue usingBlock:(void (^)(CMTime))block {
    dispatch_queue_t q = queue && queue != dispatch_get_main_queue() ? queue : nil;
    return [self _isim_addPeriodicTimeObserverValue:interval.value timescale:interval.timescale usingBlock:^(NSArray<NSNumber *> *parts) {
        CMTime t = time_of(parts);
        if (q) dispatch_async(q, ^{ block(t); }); else block(t);
    }];
}
- (id)addBoundaryTimeObserverForTimes:(NSArray<NSValue *> *)times queue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block {
    dispatch_queue_t q = queue && queue != dispatch_get_main_queue() ? queue : nil;
    return [self _isim_addBoundaryTimeObserverForTimes:times usingBlock:^{ if (q) dispatch_async(q, block); else block(); }];
}
@end
