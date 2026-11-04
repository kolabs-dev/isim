// isim AVFoundation for Objective-C: the C constants (the values the AVFoundation Swift overlay uses), and the methods
// that take or return a CMTime, which the overlay's classes cannot declare: they use the `_isim_` entry points of the
// overlay's ObjC.swift, which pass a CMTime as its four fields.
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
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

/* capture, compositions, export, readers, writers and video compositions (issue #707): the constants, and the members
   with a CMTime / CMTimeRange (passed as a pointer to the struct), CMVideoDimensions, CVPixelBufferRef or
   CMSampleBufferRef (the overlay's Swift objects), over the `_isim_` entry points of ObjCCapture.swift and
   ObjCComposition.swift. */
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInWideAngleCamera = @"AVCaptureDeviceTypeBuiltInWideAngleCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInUltraWideCamera = @"AVCaptureDeviceTypeBuiltInUltraWideCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInInnerUltraWideCamera = @"AVCaptureDeviceTypeBuiltInInnerUltraWideCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInOuterUltraWideCamera = @"AVCaptureDeviceTypeBuiltInOuterUltraWideCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInTelephotoCamera = @"AVCaptureDeviceTypeBuiltInTelephotoCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInDualCamera = @"AVCaptureDeviceTypeBuiltInDualCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInDualWideCamera = @"AVCaptureDeviceTypeBuiltInDualWideCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInTripleCamera = @"AVCaptureDeviceTypeBuiltInTripleCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInTrueDepthCamera = @"AVCaptureDeviceTypeBuiltInTrueDepthCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInLiDARDepthCamera = @"AVCaptureDeviceTypeBuiltInLiDARDepthCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeMicrophone = @"AVCaptureDeviceTypeMicrophone";
AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInMicrophone = @"AVCaptureDeviceTypeBuiltInMicrophone";
AVCaptureDeviceType const AVCaptureDeviceTypeContinuityCamera = @"AVCaptureDeviceTypeContinuityCamera";
AVCaptureDeviceType const AVCaptureDeviceTypeExternal = @"AVCaptureDeviceTypeExternal";
AVCaptureSessionPreset const AVCaptureSessionPresetPhoto = @"AVCaptureSessionPresetPhoto";
AVCaptureSessionPreset const AVCaptureSessionPresetHigh = @"AVCaptureSessionPresetHigh";
AVCaptureSessionPreset const AVCaptureSessionPresetMedium = @"AVCaptureSessionPresetMedium";
AVCaptureSessionPreset const AVCaptureSessionPresetLow = @"AVCaptureSessionPresetLow";
AVCaptureSessionPreset const AVCaptureSessionPreset1280x720 = @"AVCaptureSessionPreset1280x720";
AVCaptureSessionPreset const AVCaptureSessionPreset1920x1080 = @"AVCaptureSessionPreset1920x1080";
AVCaptureSessionPreset const AVCaptureSessionPreset3840x2160 = @"AVCaptureSessionPreset3840x2160";
AVCaptureSessionPreset const AVCaptureSessionPreset640x480 = @"AVCaptureSessionPreset640x480";
AVCaptureSessionPreset const AVCaptureSessionPreset352x288 = @"AVCaptureSessionPreset352x288";
AVCaptureSessionPreset const AVCaptureSessionPresetiFrame960x540 = @"AVCaptureSessionPresetiFrame960x540";
AVCaptureSessionPreset const AVCaptureSessionPresetiFrame1280x720 = @"AVCaptureSessionPresetiFrame1280x720";
AVCaptureSessionPreset const AVCaptureSessionPresetInputPriority = @"AVCaptureSessionPresetInputPriority";
AVVideoCodecType const AVVideoCodecTypeH264 = @"avc1";
AVVideoCodecType const AVVideoCodecTypeHEVC = @"hvc1";
AVVideoCodecType const AVVideoCodecTypeHEVCWithAlpha = @"muxa";
AVVideoCodecType const AVVideoCodecTypeJPEG = @"jpeg";
AVVideoCodecType const AVVideoCodecTypeAppleProRes422 = @"apcn";
AVVideoCodecType const AVVideoCodecTypeAppleProRes4444 = @"ap4h";
AVFileType const AVFileTypeQuickTimeMovie = @"com.apple.quicktime-movie";
AVFileType const AVFileTypeMPEG4 = @"public.mpeg-4";
AVFileType const AVFileTypeAppleM4V = @"com.apple.m4v-video";
AVFileType const AVFileTypeAppleM4A = @"com.apple.m4a-audio";
AVFileType const AVFileTypeWAVE = @"com.microsoft.waveform-audio";
AVFileType const AVFileTypeCoreAudioFormat = @"com.apple.coreaudio-format";
AVFileType const AVFileTypeAIFF = @"public.aiff-audio";
AVFileType const AVFileTypeAIFC = @"public.aifc-audio";
AVFileType const AVFileTypeMPEGLayer3 = @"public.mp3";
AVFileType const AVFileTypeAC3 = @"public.ac3-audio";
AVFileType const AVFileTypeHEIC = @"public.heic";
AVFileType const AVFileTypeJPEG = @"public.jpeg";
AVFileType const AVFileType3GPP = @"public.3gpp";
AVMetadataObjectType const AVMetadataObjectTypeQRCode = @"org.iso.QRCode";
AVMetadataObjectType const AVMetadataObjectTypeFace = @"face";
AVSemanticSegmentationMatteType const AVSemanticSegmentationMatteTypeHair = @"AVSemanticSegmentationMatteTypeHair";
AVSemanticSegmentationMatteType const AVSemanticSegmentationMatteTypeSkin = @"AVSemanticSegmentationMatteTypeSkin";
AVSemanticSegmentationMatteType const AVSemanticSegmentationMatteTypeTeeth = @"AVSemanticSegmentationMatteTypeTeeth";
AVSemanticSegmentationMatteType const AVSemanticSegmentationMatteTypeGlasses = @"AVSemanticSegmentationMatteTypeGlasses";
AVMediaType const AVMediaTypeDepthData = @"dpth";
AVMediaType const AVMediaTypeMetadataObject = @"mobj";
NSString * const AVVideoCodecKey = @"AVVideoCodecKey";
NSString * const AVVideoWidthKey = @"AVVideoWidthKey";
NSString * const AVVideoHeightKey = @"AVVideoHeightKey";
NSString * const AVVideoCompressionPropertiesKey = @"AVVideoCompressionPropertiesKey";
NSString * const AVVideoAverageBitRateKey = @"AVVideoAverageBitRateKey";
NSString * const AVVideoQualityKey = @"AVVideoQualityKey";
NSString * const AVVideoMaxKeyFrameIntervalKey = @"AVVideoMaxKeyFrameIntervalKey";
NSString * const AVVideoExpectedSourceFrameRateKey = @"AVVideoExpectedSourceFrameRateKey";
NSString * const AVVideoProfileLevelKey = @"AVVideoProfileLevelKey";
NSString * const AVVideoScalingModeKey = @"AVVideoScalingModeKey";
NSNotificationName const AVCaptureSessionDidStartRunningNotification = @"AVCaptureSessionDidStartRunningNotification";
NSNotificationName const AVCaptureSessionDidStopRunningNotification = @"AVCaptureSessionDidStopRunningNotification";
NSNotificationName const AVCaptureSessionWasInterruptedNotification = @"AVCaptureSessionWasInterruptedNotification";
NSNotificationName const AVCaptureSessionInterruptionEndedNotification = @"AVCaptureSessionInterruptionEndedNotification";
NSNotificationName const AVCaptureSessionRuntimeErrorNotification = @"AVCaptureSessionRuntimeErrorNotification";
NSNotificationName const AVCaptureDeviceWasConnectedNotification = @"AVCaptureDeviceWasConnectedNotification";
NSNotificationName const AVCaptureDeviceWasDisconnectedNotification = @"AVCaptureDeviceWasDisconnectedNotification";
NSNotificationName const AVCaptureDeviceSubjectAreaDidChangeNotification = @"AVCaptureDeviceSubjectAreaDidChangeNotification";
NSString * const AVAssetExportPresetPassthrough = @"AVAssetExportPresetPassthrough";
NSString * const AVAssetExportPresetLowQuality = @"AVAssetExportPresetLowQuality";
NSString * const AVAssetExportPresetMediumQuality = @"AVAssetExportPresetMediumQuality";
NSString * const AVAssetExportPresetHighestQuality = @"AVAssetExportPresetHighestQuality";
NSString * const AVAssetExportPresetHEVCHighestQuality = @"AVAssetExportPresetHEVCHighestQuality";
NSString * const AVAssetExportPreset640x480 = @"AVAssetExportPreset640x480";
NSString * const AVAssetExportPreset960x540 = @"AVAssetExportPreset960x540";
NSString * const AVAssetExportPreset1280x720 = @"AVAssetExportPreset1280x720";
NSString * const AVAssetExportPreset1920x1080 = @"AVAssetExportPreset1920x1080";
NSString * const AVAssetExportPreset3840x2160 = @"AVAssetExportPreset3840x2160";
NSString * const AVAssetExportPresetHEVC1920x1080 = @"AVAssetExportPresetHEVC1920x1080";
NSString * const AVAssetExportPresetHEVC3840x2160 = @"AVAssetExportPresetHEVC3840x2160";
NSString * const AVAssetExportPresetAppleM4A = @"AVAssetExportPresetAppleM4A";

@interface AVCaptureDevice (ISIMTime)
- (void)_isim_getTime:(NSInteger)which out:(void *)out;
- (void)_isim_setTime:(NSInteger)which value:(const void *)value;
- (void)_isim_setExposureBias:(float)bias completion:(nullable void (^)(const void *))handler;
- (void)_isim_setFocusLocked:(float)position completion:(nullable void (^)(const void *))handler;
@end
@implementation AVCaptureDevice (ISIMCMTime)
static CMTime device_time(AVCaptureDevice *d, NSInteger which) { CMTime t = kCMTimeInvalid; [d _isim_getTime:which out:&t]; return t; }
- (CMTime)activeVideoMinFrameDuration { return device_time(self, 0); }
- (CMTime)activeVideoMaxFrameDuration { return device_time(self, 1); }
- (CMTime)exposureDuration { return device_time(self, 2); }
- (CMTime)activeMaxExposureDuration { return device_time(self, 3); }
- (void)setActiveVideoMinFrameDuration:(CMTime)t { [self _isim_setTime:0 value:&t]; }
- (void)setActiveVideoMaxFrameDuration:(CMTime)t { [self _isim_setTime:1 value:&t]; }
- (void)setActiveMaxExposureDuration:(CMTime)t { [self _isim_setTime:3 value:&t]; }
- (void)setExposureTargetBias:(float)bias completionHandler:(void (^)(CMTime))handler {
    [self _isim_setExposureBias:bias completion:handler ? ^(const void *p) { handler(*(const CMTime *)p); } : nil];
}
- (void)setFocusModeLockedWithLensPosition:(float)position completionHandler:(void (^)(CMTime))handler {
    [self _isim_setFocusLocked:position completion:handler ? ^(const void *p) { handler(*(const CMTime *)p); } : nil];
}
@end
@interface AVCaptureDeviceFormat (ISIMDimensions)
- (int32_t)_isim_width;
- (int32_t)_isim_height;
@end
@implementation AVCaptureDeviceFormat (ISIMCMDimensions)
- (CMVideoDimensions)highResolutionStillImageDimensions { return (CMVideoDimensions){ [self _isim_width], [self _isim_height] }; }
@end
@interface AVCaptureFileOutput (ISIMTime)
- (void)_isim_recordedDuration:(void *)out;
- (void)_isim_maxRecordedDuration:(void *)out;
- (void)_isim_setMaxRecordedDuration:(const void *)value;
@end
@implementation AVCaptureFileOutput (ISIMCMTime)
- (CMTime)recordedDuration { CMTime t = kCMTimeInvalid; [self _isim_recordedDuration:&t]; return t; }
- (CMTime)maxRecordedDuration { CMTime t = kCMTimeInvalid; [self _isim_maxRecordedDuration:&t]; return t; }
- (void)setMaxRecordedDuration:(CMTime)t { [self _isim_setMaxRecordedDuration:&t]; }
@end
@interface NSObject (ISIMPhotoDimensions)
- (int32_t)_isim_maxPhotoWidth;
- (int32_t)_isim_maxPhotoHeight;
- (void)_isim_setMaxPhotoWidth:(int32_t)w height:(int32_t)h;
- (int32_t)_isim_photoWidth;
- (int32_t)_isim_photoHeight;
- (void)_isim_timestamp:(void *)out;
- (nullable void *)_isim_pixelBuffer;
- (nullable void *)_isim_previewPixelBuffer;
- (nullable void *)_isim_mattingImage;
@end
@implementation AVCapturePhotoSettings (ISIMCMDimensions)
- (CMVideoDimensions)maxPhotoDimensions { return (CMVideoDimensions){ [self _isim_maxPhotoWidth], [self _isim_maxPhotoHeight] }; }
- (void)setMaxPhotoDimensions:(CMVideoDimensions)d { [self _isim_setMaxPhotoWidth:d.width height:d.height]; }
@end
@implementation AVCapturePhotoOutput (ISIMCMDimensions)
- (CMVideoDimensions)maxPhotoDimensions { return (CMVideoDimensions){ [self _isim_maxPhotoWidth], [self _isim_maxPhotoHeight] }; }
- (void)setMaxPhotoDimensions:(CMVideoDimensions)d { [self _isim_setMaxPhotoWidth:d.width height:d.height]; }
@end
@implementation AVCaptureResolvedPhotoSettings (ISIMCMDimensions)
- (CMVideoDimensions)photoDimensions { return (CMVideoDimensions){ [self _isim_photoWidth], [self _isim_photoHeight] }; }
@end
@implementation AVCapturePhoto (ISIMCMTime)
- (CMTime)timestamp { CMTime t = kCMTimeInvalid; [self _isim_timestamp:&t]; return t; }
- (CVPixelBufferRef)pixelBuffer { return (CVPixelBufferRef)[self _isim_pixelBuffer]; }
- (CVPixelBufferRef)previewPixelBuffer { return (CVPixelBufferRef)[self _isim_previewPixelBuffer]; }
@end
@implementation AVPortraitEffectsMatte (ISIMPixelBuffer)
- (CVPixelBufferRef)mattingImage { return (CVPixelBufferRef)[self _isim_mattingImage]; }
@end
@implementation AVSemanticSegmentationMatte (ISIMPixelBuffer)
- (CVPixelBufferRef)mattingImage { return (CVPixelBufferRef)[self _isim_mattingImage]; }
@end

@interface NSObject (ISIMTimeRange)
- (void)_isim_timeRange:(void *)out;
- (void)_isim_setTimeRange:(const void *)value;
- (void)_isim_insertEmptyTimeRange:(const void *)range;
- (void)_isim_removeTimeRange:(const void *)range;
- (void)_isim_scaleTimeRange:(const void *)range toDuration:(const void *)duration;
@end
static CMTimeRange range_of(id o) { CMTimeRange r = kCMTimeRangeInvalid; [o _isim_timeRange:&r]; return r; }
@implementation AVAssetTrack (ISIMCMTimeRange)
- (CMTimeRange)timeRange { return range_of(self); }
@end
@interface AVMutableCompositionTrack (ISIMTime)
- (BOOL)_isim_insertTimeRange:(const void *)range ofTrack:(AVAssetTrack *)track atTime:(const void *)at error:(NSError **)error;
@end
@implementation AVMutableCompositionTrack (ISIMCMTime)
- (BOOL)insertTimeRange:(CMTimeRange)r ofTrack:(AVAssetTrack *)track atTime:(CMTime)at error:(NSError **)error {
    return [self _isim_insertTimeRange:&r ofTrack:track atTime:&at error:error];
}
- (void)insertEmptyTimeRange:(CMTimeRange)r { [self _isim_insertEmptyTimeRange:&r]; }
- (void)removeTimeRange:(CMTimeRange)r { [self _isim_removeTimeRange:&r]; }
- (void)scaleTimeRange:(CMTimeRange)r toDuration:(CMTime)d { [self _isim_scaleTimeRange:&r toDuration:&d]; }
@end
@interface AVMutableComposition (ISIMTime)
- (BOOL)_isim_insertTimeRange:(const void *)range ofAsset:(AVAsset *)asset atTime:(const void *)at error:(NSError **)error;
@end
@implementation AVMutableComposition (ISIMCMTime)
- (BOOL)insertTimeRange:(CMTimeRange)r ofAsset:(AVAsset *)asset atTime:(CMTime)at error:(NSError **)error {
    return [self _isim_insertTimeRange:&r ofAsset:asset atTime:&at error:error];
}
- (void)insertEmptyTimeRange:(CMTimeRange)r { [self _isim_insertEmptyTimeRange:&r]; }
- (void)removeTimeRange:(CMTimeRange)r { [self _isim_removeTimeRange:&r]; }
- (void)scaleTimeRange:(CMTimeRange)r toDuration:(CMTime)d { [self _isim_scaleTimeRange:&r toDuration:&d]; }
@end
@interface AVMutableAudioMixInputParameters (ISIMTime)
- (void)_isim_setVolume:(float)volume atTime:(const void *)at;
- (void)_isim_setVolumeRampFromStartVolume:(float)a toEndVolume:(float)b timeRange:(const void *)range;
@end
@implementation AVMutableAudioMixInputParameters (ISIMCMTime)
- (void)setVolume:(float)v atTime:(CMTime)t { [self _isim_setVolume:v atTime:&t]; }
- (void)setVolumeRampFromStartVolume:(float)a toEndVolume:(float)b timeRange:(CMTimeRange)r {
    [self _isim_setVolumeRampFromStartVolume:a toEndVolume:b timeRange:&r];
}
@end
@interface AVMutableVideoCompositionLayerInstruction (ISIMTime)
- (void)_isim_setTransform:(CGAffineTransform)t atTime:(const void *)at;
- (void)_isim_setOpacity:(float)o atTime:(const void *)at;
- (void)_isim_setTransformRampFromStart:(CGAffineTransform)a toEnd:(CGAffineTransform)b timeRange:(const void *)range;
- (void)_isim_setOpacityRampFromStart:(float)a toEnd:(float)b timeRange:(const void *)range;
- (void)_isim_setCropRectangle:(CGRect)r atTime:(const void *)at;
@end
@implementation AVMutableVideoCompositionLayerInstruction (ISIMCMTime)
- (void)setTransform:(CGAffineTransform)x atTime:(CMTime)t { [self _isim_setTransform:x atTime:&t]; }
- (void)setOpacity:(float)o atTime:(CMTime)t { [self _isim_setOpacity:o atTime:&t]; }
- (void)setTransformRampFromStartTransform:(CGAffineTransform)a toEndTransform:(CGAffineTransform)b timeRange:(CMTimeRange)r {
    [self _isim_setTransformRampFromStart:a toEnd:b timeRange:&r];
}
- (void)setOpacityRampFromStartOpacity:(float)a toEndOpacity:(float)b timeRange:(CMTimeRange)r { [self _isim_setOpacityRampFromStart:a toEnd:b timeRange:&r]; }
- (void)setCropRectangle:(CGRect)c atTime:(CMTime)t { [self _isim_setCropRectangle:c atTime:&t]; }
@end
@implementation AVVideoCompositionInstruction (ISIMCMTimeRange)
- (CMTimeRange)timeRange { return range_of(self); }
@end
@implementation AVMutableVideoCompositionInstruction (ISIMCMTimeRange)
- (void)setTimeRange:(CMTimeRange)r { [self _isim_setTimeRange:&r]; }
@end
@interface AVVideoComposition (ISIMTime)
- (void)_isim_frameDuration:(void *)out;
@end
@interface AVMutableVideoComposition (ISIMTime)
- (void)_isim_setFrameDuration:(const void *)value;
@end
@implementation AVVideoComposition (ISIMCMTime)
- (CMTime)frameDuration { CMTime t = kCMTimeInvalid; [self _isim_frameDuration:&t]; return t; }
@end
@implementation AVMutableVideoComposition (ISIMCMTime)
- (void)setFrameDuration:(CMTime)t { [self _isim_setFrameDuration:&t]; }
@end
@interface AVVideoCompositionRenderContext (ISIMPixelBuffer)
- (nullable void *)_isim_newPixelBuffer;
@end
@implementation AVVideoCompositionRenderContext (ISIMCVPixelBuffer)
- (CVPixelBufferRef)newPixelBuffer { return (CVPixelBufferRef)[self _isim_newPixelBuffer]; }
@end
@interface AVAsynchronousVideoCompositionRequest (ISIMTime)
- (void)_isim_compositionTime:(void *)out;
- (nullable void *)_isim_sourceFrameByTrackID:(CMPersistentTrackID)trackID;
- (void)_isim_finishWithComposedVideoFrame:(void *)frame;
@end
@implementation AVAsynchronousVideoCompositionRequest (ISIMCMTime)
- (CMTime)compositionTime { CMTime t = kCMTimeInvalid; [self _isim_compositionTime:&t]; return t; }
- (CVPixelBufferRef)sourceFrameByTrackID:(CMPersistentTrackID)trackID { return (CVPixelBufferRef)[self _isim_sourceFrameByTrackID:trackID]; }
- (void)finishWithComposedVideoFrame:(CVPixelBufferRef)frame { [self _isim_finishWithComposedVideoFrame:(void *)frame]; }
@end
@implementation AVAssetExportSession (ISIMCMTimeRange)
- (CMTimeRange)timeRange { return range_of(self); }
- (void)setTimeRange:(CMTimeRange)r { [self _isim_setTimeRange:&r]; }
@end
@implementation AVAssetReader (ISIMCMTimeRange)
- (CMTimeRange)timeRange { return range_of(self); }
- (void)setTimeRange:(CMTimeRange)r { [self _isim_setTimeRange:&r]; }
@end
@interface AVAssetReaderOutput (ISIMSampleBuffer)
- (nullable void *)_isim_copyNextSampleBuffer;
@end
@implementation AVAssetReaderOutput (ISIMCMSampleBuffer)
- (CMSampleBufferRef)copyNextSampleBuffer { return (CMSampleBufferRef)[self _isim_copyNextSampleBuffer]; }
@end
@interface AVAssetWriterInput (ISIMSampleBuffer)
- (BOOL)_isim_appendSampleBuffer:(void *)buffer;
@end
@implementation AVAssetWriterInput (ISIMCMSampleBuffer)
- (BOOL)appendSampleBuffer:(CMSampleBufferRef)buffer { return [self _isim_appendSampleBuffer:(void *)buffer]; }
@end
@interface AVAssetWriterInputPixelBufferAdaptor (ISIMTime)
- (BOOL)_isim_appendPixelBuffer:(void *)buffer withPresentationTime:(const void *)time;
@end
@implementation AVAssetWriterInputPixelBufferAdaptor (ISIMCMTime)
- (BOOL)appendPixelBuffer:(CVPixelBufferRef)buffer withPresentationTime:(CMTime)t { return [self _isim_appendPixelBuffer:(void *)buffer withPresentationTime:&t]; }
@end
@interface AVAssetWriter (ISIMTime)
- (void)_isim_startSessionAtSourceTime:(const void *)time;
- (void)_isim_endSessionAtSourceTime:(const void *)time;
@end
@implementation AVAssetWriter (ISIMCMTime)
- (void)startSessionAtSourceTime:(CMTime)t { [self _isim_startSessionAtSourceTime:&t]; }
- (void)endSessionAtSourceTime:(CMTime)t { [self _isim_endSessionAtSourceTime:&t]; }
@end

/* issue #811: system pressure levels, depth data, the synchronized data, and the depth delegate's CMTime call */
AVCaptureSystemPressureLevel const AVCaptureSystemPressureLevelNominal = @"nominal";
AVCaptureSystemPressureLevel const AVCaptureSystemPressureLevelFair = @"fair";
AVCaptureSystemPressureLevel const AVCaptureSystemPressureLevelSerious = @"serious";
AVCaptureSystemPressureLevel const AVCaptureSystemPressureLevelCritical = @"critical";
AVCaptureSystemPressureLevel const AVCaptureSystemPressureLevelShutdown = @"shutdown";

/* the overlay's depth delegate adapter calls an Objective-C delegate through this (a CMTime goes by value) */
__attribute__((visibility("default")))
void isim_av_call_depth(id target, SEL sel, id output, id data, const CMTime *t, id connection, NSInteger reason, int dropped) {
    if (dropped) ((void (*)(id, SEL, id, id, CMTime, id, NSInteger))objc_msgSend)(target, sel, output, data, *t, connection, reason);
    else ((void (*)(id, SEL, id, id, CMTime, id))objc_msgSend)(target, sel, output, data, *t, connection);
}

@interface AVDepthData (ISIMPixelBuffer)
- (void *)_isim_depthDataMap;
- (nullable AVDepthData *)_isim_depthDataByReplacingDepthDataMap:(void *)map error:(NSError **)error;
@end
@implementation AVDepthData (ISIMCVPixelBuffer)
- (CVPixelBufferRef)depthDataMap { return (CVPixelBufferRef)[self _isim_depthDataMap]; }
- (instancetype)depthDataByReplacingDepthDataMapWithPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error {
    return [self _isim_depthDataByReplacingDepthDataMap:(void *)pixelBuffer error:error];
}
@end
@interface AVCaptureSynchronizedData (ISIMTime)
- (void)_isim_timestamp:(void *)out;
@end
@implementation AVCaptureSynchronizedData (ISIMCMTime)
- (CMTime)timestamp { CMTime t = kCMTimeInvalid; [self _isim_timestamp:&t]; return t; }
@end
@interface AVCaptureSynchronizedSampleBufferData (ISIMSampleBuffer)
- (void *)_isim_sampleBuffer;
@end
@implementation AVCaptureSynchronizedSampleBufferData (ISIMCMSampleBuffer)
- (CMSampleBufferRef)sampleBuffer { return (CMSampleBufferRef)[self _isim_sampleBuffer]; }
@end
@interface AVCaptureSynchronizedDataCollection (ISIMOutputs)
- (NSArray<AVCaptureOutput *> *)_isim_outputs;
@end
@implementation AVCaptureSynchronizedDataCollection (ISIMFastEnumeration)
/* enumerates the outputs that have data, in the synchronizer's order */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    static char key;
    NSArray *outputs = objc_getAssociatedObject(self, &key);          /* kept, so the enumeration's pointers stay valid */
    if (!outputs) { outputs = [self _isim_outputs]; objc_setAssociatedObject(self, &key, outputs, OBJC_ASSOCIATION_RETAIN); }
    return [outputs countByEnumeratingWithState:state objects:buffer count:len];
}
@end
