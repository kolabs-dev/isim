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
AVCoordinatedPlaybackSuspensionReason const AVCoordinatedPlaybackSuspensionReasonAudioSessionInterrupted = @"AVCoordinatedPlaybackSuspensionReasonAudioSessionInterrupted";
AVCoordinatedPlaybackSuspensionReason const AVCoordinatedPlaybackSuspensionReasonStallRecovery = @"AVCoordinatedPlaybackSuspensionReasonStallRecovery";
AVCoordinatedPlaybackSuspensionReason const AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial = @"AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial";
AVCoordinatedPlaybackSuspensionReason const AVCoordinatedPlaybackSuspensionReasonCoordinatedPlaybackNotPossible = @"AVCoordinatedPlaybackSuspensionReasonCoordinatedPlaybackNotPossible";
AVCoordinatedPlaybackSuspensionReason const AVCoordinatedPlaybackSuspensionReasonUserActionRequired = @"AVCoordinatedPlaybackSuspensionReasonUserActionRequired";
AVCoordinatedPlaybackSuspensionReason const AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime = @"AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime";
NSNotificationName const AVPlaybackCoordinatorOtherParticipantsDidChangeNotification = @"AVPlaybackCoordinatorOtherParticipantsDidChangeNotification";
NSNotificationName const AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification = @"AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification";

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

/* AVFAudio (issue #553): the constants, the class factories, Apple's setters where the overlay's Bool properties are
   named isX (Swift's Objective-C setter is setIsX:), and the AVAudio3D… and prime-info structs, which go through the
   overlay's `_isim_` NSArray entry points (AVFAudioObjC.swift). */
NSNotificationName const AVAudioEngineConfigurationChangeNotification = @"AVAudioEngineConfigurationChangeNotification";
NSString * const AVFormatIDKey = @"AVFormatIDKey";
NSString * const AVSampleRateKey = @"AVSampleRateKey";
NSString * const AVNumberOfChannelsKey = @"AVNumberOfChannelsKey";
NSString * const AVChannelLayoutKey = @"AVChannelLayoutKey";
NSString * const AVLinearPCMBitDepthKey = @"AVLinearPCMBitDepthKey";
NSString * const AVLinearPCMIsBigEndianKey = @"AVLinearPCMIsBigEndianKey";
NSString * const AVLinearPCMIsFloatKey = @"AVLinearPCMIsFloatKey";
NSString * const AVLinearPCMIsNonInterleaved = @"AVLinearPCMIsNonInterleaved";
NSString * const AVEncoderAudioQualityKey = @"AVEncoderAudioQualityKey";
NSString * const AVEncoderBitRateKey = @"AVEncoderBitRateKey";
NSString * const AVEncoderBitRatePerChannelKey = @"AVEncoderBitRatePerChannelKey";
NSString * const AVEncoderBitRateStrategyKey = @"AVEncoderBitRateStrategyKey";
NSString * const AVEncoderBitDepthHintKey = @"AVEncoderBitDepthHintKey";
NSString * const AVSampleRateConverterAlgorithmKey = @"AVSampleRateConverterAlgorithmKey";
NSString * const AVSampleRateConverterAudioQualityKey = @"AVSampleRateConverterAudioQualityKey";
NSString * const AVSampleRateConverterAlgorithm_Normal = @"AVSampleRateConverterAlgorithm_Normal";
NSString * const AVSampleRateConverterAlgorithm_Mastering = @"AVSampleRateConverterAlgorithm_Mastering";
NSString * const AVSampleRateConverterAlgorithm_MinimumPhase = @"AVSampleRateConverterAlgorithm_MinimumPhase";
NSString * const AVAudioBitRateStrategy_Constant = @"AVAudioBitRateStrategy_Constant";
NSString * const AVAudioBitRateStrategy_LongTermAverage = @"AVAudioBitRateStrategy_LongTermAverage";
NSString * const AVAudioBitRateStrategy_VariableConstrained = @"AVAudioBitRateStrategy_VariableConstrained";
NSString * const AVAudioBitRateStrategy_Variable = @"AVAudioBitRateStrategy_Variable";

static NSArray<NSNumber *> *point_parts(AVAudio3DPoint p) { return @[@(p.x), @(p.y), @(p.z)]; }
static AVAudio3DPoint point_of(NSArray<NSNumber *> *a, NSUInteger i) {
    return a.count >= i + 3 ? AVAudioMake3DPoint(a[i].floatValue, a[i + 1].floatValue, a[i + 2].floatValue) : AVAudioMake3DPoint(0, 0, 0);
}

@interface NSObject (ISIMAVFAudio)
- (void)setIsMeteringEnabled:(BOOL)v;
- (void)setIsAutoShutdownEnabled:(BOOL)v;
- (void)setIsListenerHeadTrackingEnabled:(BOOL)v;
- (void)setIsVoiceProcessingBypassed:(BOOL)v;
- (void)setIsVoiceProcessingAGCEnabled:(BOOL)v;
- (void)setIsVoiceProcessingInputMuted:(BOOL)v;
- (NSArray<NSNumber *> *)_isim_position;
- (void)set_isim_position:(NSArray<NSNumber *> *)p;
- (NSArray<NSNumber *> *)_isim_listenerPosition;
- (void)set_isim_listenerPosition:(NSArray<NSNumber *> *)p;
- (NSArray<NSNumber *> *)_isim_listenerAngularOrientation;
- (void)set_isim_listenerAngularOrientation:(NSArray<NSNumber *> *)p;
- (NSArray<NSNumber *> *)_isim_listenerVectorOrientation;
- (void)set_isim_listenerVectorOrientation:(NSArray<NSNumber *> *)p;
- (NSArray<NSNumber *> *)_isim_primeInfo;
- (void)set_isim_primeInfo:(NSArray<NSNumber *> *)p;
@end

@implementation AVAudioChannelLayout (ISIMFactories)
+ (instancetype)layoutWithLayoutTag:(AudioChannelLayoutTag)layoutTag { return [[self alloc] initWithLayoutTag:layoutTag]; }
+ (instancetype)layoutWithLayout:(const AudioChannelLayout *)layout { return [[self alloc] initWithLayout:layout]; }
@end
@implementation AVAudioTime (ISIMFactories)
+ (instancetype)timeWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(double)sampleRate {
    return [[self alloc] initWithAudioTimeStamp:ts sampleRate:sampleRate];
}
+ (instancetype)timeWithHostTime:(uint64_t)hostTime { return [[self alloc] initWithHostTime:hostTime]; }
+ (instancetype)timeWithSampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate {
    return [[self alloc] initWithSampleTime:sampleTime atRate:sampleRate];
}
+ (instancetype)timeWithHostTime:(uint64_t)hostTime sampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate {
    return [[self alloc] initWithHostTime:hostTime sampleTime:sampleTime atRate:sampleRate];
}
@end

@implementation AVAudioConverter (ISIMStructs)
- (AVAudioConverterPrimeInfo)primeInfo {
    NSArray<NSNumber *> *a = [self _isim_primeInfo];
    return (AVAudioConverterPrimeInfo){ a[0].unsignedIntValue, a[1].unsignedIntValue };
}
- (void)setPrimeInfo:(AVAudioConverterPrimeInfo)p { [self set_isim_primeInfo:@[@(p.leadingFrames), @(p.trailingFrames)]]; }
@end
@implementation AVAudioPlayer (ISIMSetters)
- (void)setMeteringEnabled:(BOOL)v { [self setIsMeteringEnabled:v]; }
@end
@implementation AVAudioRecorder (ISIMSetters)
- (void)setMeteringEnabled:(BOOL)v { [self setIsMeteringEnabled:v]; }
@end
@implementation AVAudioEngine (ISIMSetters)
- (void)setAutoShutdownEnabled:(BOOL)v { [self setIsAutoShutdownEnabled:v]; }
@end
@implementation AVAudioInputNode (ISIMSetters)
- (void)setVoiceProcessingBypassed:(BOOL)v { [self setIsVoiceProcessingBypassed:v]; }
- (void)setVoiceProcessingAGCEnabled:(BOOL)v { [self setIsVoiceProcessingAGCEnabled:v]; }
- (void)setVoiceProcessingInputMuted:(BOOL)v { [self setIsVoiceProcessingInputMuted:v]; }
@end
@implementation AVAudioEnvironmentNode (ISIMStructs)
- (void)setListenerHeadTrackingEnabled:(BOOL)v { [self setIsListenerHeadTrackingEnabled:v]; }
- (AVAudio3DPoint)listenerPosition { return point_of([self _isim_listenerPosition], 0); }
- (void)setListenerPosition:(AVAudio3DPoint)p { [self set_isim_listenerPosition:point_parts(p)]; }
- (AVAudio3DAngularOrientation)listenerAngularOrientation {
    NSArray<NSNumber *> *a = [self _isim_listenerAngularOrientation];
    return AVAudioMake3DAngularOrientation(a[0].floatValue, a[1].floatValue, a[2].floatValue);
}
- (void)setListenerAngularOrientation:(AVAudio3DAngularOrientation)o {
    [self set_isim_listenerAngularOrientation:@[@(o.yaw), @(o.pitch), @(o.roll)]];
}
- (AVAudio3DVectorOrientation)listenerVectorOrientation {
    NSArray<NSNumber *> *a = [self _isim_listenerVectorOrientation];
    return AVAudioMake3DVectorOrientation(point_of(a, 0), point_of(a, 3));
}
- (void)setListenerVectorOrientation:(AVAudio3DVectorOrientation)o {
    [self set_isim_listenerVectorOrientation:[point_parts(o.forward) arrayByAddingObjectsFromArray:point_parts(o.up)]];
}
@end

/* AVAudio3DMixing's position on each class that adopts AVAudioMixing */
#define ISIM_MIXING_POSITION(C) \
    @implementation C (ISIMPosition) \
    - (AVAudio3DPoint)position { return point_of([self _isim_position], 0); } \
    - (void)setPosition:(AVAudio3DPoint)p { [self set_isim_position:point_parts(p)]; } \
    @end
ISIM_MIXING_POSITION(AVAudioMixingDestination)
ISIM_MIXING_POSITION(AVAudioMixerNode)
ISIM_MIXING_POSITION(AVAudioPlayerNode)
ISIM_MIXING_POSITION(AVAudioSourceNode)
ISIM_MIXING_POSITION(AVAudioInputNode)
ISIM_MIXING_POSITION(AVAudioEnvironmentNode)
ISIM_MIXING_POSITION(AVAudioUnitGenerator)
ISIM_MIXING_POSITION(AVAudioUnitMIDIInstrument)

/* AVAudioSequencer and AVMusicTrack (issue #389): the info dictionary keys (the values AVMIDI.swift uses) and the
 * methods that take an AVBeatRange, through the overlay's `_isim_` entry points (start and length) */
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyAlbum = @"album";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyApproximateDurationInSeconds = @"approximate duration in seconds";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyArtist = @"artist";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyChannelLayout = @"channel layout";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyComments = @"comments";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyComposer = @"composer";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyCopyright = @"copyright";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyEncodingApplication = @"encoding application";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyGenre = @"genre";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyISRC = @"ISRC";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyKeySignature = @"key signature";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyLyricist = @"lyricist";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyNominalBitRate = @"nominal bit rate";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyRecordedDate = @"recorded date";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeySourceBitDepth = @"source bit depth";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeySourceEncoder = @"source encoder";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeySubTitle = @"subtitle";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTempo = @"tempo";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTimeSignature = @"time signature";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTitle = @"title";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTrackNumber = @"track number";
AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyYear = @"year";
const MusicDeviceInstrumentID AVExtendedNoteOnEventDefaultInstrument = 0;

@interface AVMusicTrack (ISIMBeatRanges)
- (NSArray<NSNumber *> *)_isim_loopRange;
- (void)set_isim_loopRange:(NSArray<NSNumber *> *)r;
- (void)_isim_moveEventsFrom:(double)start length:(double)length byAmount:(double)amount;
- (void)_isim_clearEventsFrom:(double)start length:(double)length;
- (void)_isim_cutEventsFrom:(double)start length:(double)length;
- (void)_isim_copyEventsFrom:(double)start length:(double)length fromTrack:(AVMusicTrack *)t insertAtBeat:(double)at;
- (void)_isim_copyAndMergeEventsFrom:(double)start length:(double)length fromTrack:(AVMusicTrack *)t mergeAtBeat:(double)at;
- (void)_isim_enumerateEventsFrom:(double)start length:(double)length usingBlock:(AVMusicEventEnumerationBlock)block;
@end
@implementation AVMusicTrack (ISIMBeatRangeMethods)
- (AVBeatRange)loopRange {
    NSArray<NSNumber *> *a = [self _isim_loopRange];
    return AVMakeBeatRange(a[0].doubleValue, a[1].doubleValue);
}
- (void)setLoopRange:(AVBeatRange)r { [self set_isim_loopRange:@[@(r.start), @(r.length)]]; }
- (void)moveEventsInRange:(AVBeatRange)r byAmount:(AVMusicTimeStamp)amount { [self _isim_moveEventsFrom:r.start length:r.length byAmount:amount]; }
- (void)clearEventsInRange:(AVBeatRange)r { [self _isim_clearEventsFrom:r.start length:r.length]; }
- (void)cutEventsInRange:(AVBeatRange)r { [self _isim_cutEventsFrom:r.start length:r.length]; }
- (void)copyEventsInRange:(AVBeatRange)r fromTrack:(AVMusicTrack *)t insertAtBeat:(AVMusicTimeStamp)at {
    [self _isim_copyEventsFrom:r.start length:r.length fromTrack:t insertAtBeat:at];
}
- (void)copyAndMergeEventsInRange:(AVBeatRange)r fromTrack:(AVMusicTrack *)t mergeAtBeat:(AVMusicTimeStamp)at {
    [self _isim_copyAndMergeEventsFrom:r.start length:r.length fromTrack:t mergeAtBeat:at];
}
- (void)enumerateEventsInRange:(AVBeatRange)r usingBlock:(AVMusicEventEnumerationBlock)block {
    [self _isim_enumerateEventsFrom:r.start length:r.length usingBlock:block];
}
@end

// coordinated playback (issue #392)
@interface AVCoordinatedPlaybackSuspension (ISIMTime)
- (void)_isim_endProposingNewTimeValue:(int64_t)v timescale:(int32_t)ts flags:(uint32_t)f epoch:(int64_t)e;
@end
@implementation AVCoordinatedPlaybackSuspension (ISIMCMTime)
- (void)endProposingNewTime:(CMTime)t { [self _isim_endProposingNewTimeValue:t.value timescale:t.timescale flags:t.flags epoch:t.epoch]; }
@end
@interface AVPlaybackCoordinator (ISIMTime)
- (NSArray<NSNumber *> *)_isim_expectedItemTimeAtHostTimeValue:(int64_t)v timescale:(int32_t)ts flags:(uint32_t)f epoch:(int64_t)e;
@end
@implementation AVPlaybackCoordinator (ISIMCMTime)
- (CMTime)expectedItemTimeAtHostTime:(CMTime)t {
    return time_of([self _isim_expectedItemTimeAtHostTimeValue:t.value timescale:t.timescale flags:t.flags epoch:t.epoch]);
}
@end
@interface AVDelegatingPlaybackCoordinatorPlayCommand (ISIMTime)
- (NSArray<NSNumber *> *)_isim_itemTime;
- (NSArray<NSNumber *> *)_isim_hostClockTime;
@end
@implementation AVDelegatingPlaybackCoordinatorPlayCommand (ISIMCMTime)
- (CMTime)itemTime { return time_of([self _isim_itemTime]); }
- (CMTime)hostClockTime { return time_of([self _isim_hostClockTime]); }
@end
@interface AVDelegatingPlaybackCoordinatorSeekCommand (ISIMTime)
- (NSArray<NSNumber *> *)_isim_itemTime;
@end
@implementation AVDelegatingPlaybackCoordinatorSeekCommand (ISIMCMTime)
- (CMTime)itemTime { return time_of([self _isim_itemTime]); }
@end
@interface AVDelegatingPlaybackCoordinator (ISIMTime)
- (void)_isim_coordinateSeekToTimeValue:(int64_t)v timescale:(int32_t)ts flags:(uint32_t)f epoch:(int64_t)e options:(NSUInteger)options;
- (void)_isim_transitionToItemWithIdentifier:(NSString *)item timebase:(const void *)timebase;
@end
@implementation AVDelegatingPlaybackCoordinator (ISIMCMTime)
- (void)coordinateSeekToTime:(CMTime)t options:(AVDelegatingPlaybackCoordinatorSeekOptions)options {
    [self _isim_coordinateSeekToTimeValue:t.value timescale:t.timescale flags:t.flags epoch:t.epoch options:options];
}
- (void)transitionToItemWithIdentifier:(NSString *)item proposingInitialTimingBasedOnTimebase:(CMTimebaseRef)timebase {
    [self _isim_transitionToItemWithIdentifier:item timebase:timebase];
}
@end
