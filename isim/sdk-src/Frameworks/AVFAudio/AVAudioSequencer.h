#pragma once
/* isim AVFAudio: AVAudioSequencer and AVMusicTrack (AVMIDI.swift, over isim's Music Player, issue #389). */
#import <AVFAudio/AVAudioEngine.h>
#import <AVFAudio/AVAudioUnit.h>
#import <AVFAudio/AVMusicEvents.h>
#import <CoreMIDI/CoreMIDI.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef struct _AVBeatRange { AVMusicTimeStamp start; AVMusicTimeStamp length; } AVBeatRange;
static inline AVBeatRange AVMakeBeatRange(AVMusicTimeStamp startBeat, AVMusicTimeStamp lengthInBeats) {
    AVBeatRange r = {startBeat, lengthInBeats};
    return r;
}
#define AVMusicTimeStampEndOfTrack ((double)1.0e9)
typedef NSString *AVAudioSequencerInfoDictionaryKey NS_TYPED_ENUM;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyAlbum;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyApproximateDurationInSeconds;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyArtist;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyChannelLayout;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyComments;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyComposer;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyCopyright;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyEncodingApplication;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyGenre;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyISRC;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyKeySignature;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyLyricist;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyNominalBitRate;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyRecordedDate;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeySourceBitDepth;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeySourceEncoder;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeySubTitle;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTempo;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTimeSignature;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTitle;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyTrackNumber;
extern AVAudioSequencerInfoDictionaryKey const AVAudioSequencerInfoDictionaryKeyYear;
typedef NS_OPTIONS(NSUInteger, AVMusicSequenceLoadOptions) {
    AVMusicSequenceLoadSMF_PreserveTracks = 0,
    AVMusicSequenceLoadSMF_ChannelsToTracks = (1UL << 0),
};
typedef NS_ENUM(NSInteger, AVMusicTrackLoopCount) { AVMusicTrackLoopCountForever = -1 };
@class AVMusicTrack;
typedef void (^AVAudioSequencerUserCallback)(AVMusicTrack *track, NSData *userData, AVMusicTimeStamp timeStamp);
typedef void (^AVMusicEventEnumerationBlock)(AVMusicEvent *event, AVMusicTimeStamp *timeStamp, BOOL *removeEvent);

@interface AVAudioSequencer : NSObject
- (instancetype)init;
- (instancetype)initWithAudioEngine:(AVAudioEngine *)engine;
- (BOOL)loadFromURL:(NSURL *)fileURL options:(AVMusicSequenceLoadOptions)options error:(NSError **)outError;
- (BOOL)loadFromData:(NSData *)data options:(AVMusicSequenceLoadOptions)options error:(NSError **)outError;
- (BOOL)writeToURL:(NSURL *)fileURL SMPTEResolution:(NSInteger)resolution replaceExisting:(BOOL)replace error:(NSError **)outError;
- (NSData *)dataWithSMPTEResolution:(NSInteger)SMPTEResolution error:(NSError **)outError;
- (NSTimeInterval)secondsForBeats:(AVMusicTimeStamp)beats;
- (AVMusicTimeStamp)beatsForSeconds:(NSTimeInterval)seconds;
- (UInt64)hostTimeForBeats:(AVMusicTimeStamp)inBeats error:(NSError **)outError;
- (AVMusicTimeStamp)beatsForHostTime:(UInt64)inHostTime error:(NSError **)outError;
- (AVMusicTrack *)createAndAppendTrack;
- (BOOL)removeTrack:(AVMusicTrack *)track;
- (void)reverseEvents;
- (void)setUserCallback:(nullable AVAudioSequencerUserCallback)userCallback;
- (void)prepareToPlay;
- (BOOL)startAndReturnError:(NSError **)outError;
- (void)stop;
@property (nonatomic, readonly) NSArray<AVMusicTrack *> *tracks;
@property (nonatomic, readonly) AVMusicTrack *tempoTrack;
@property (nonatomic, readonly) NSDictionary<AVAudioSequencerInfoDictionaryKey, id> *userInfo;
@property (nonatomic) NSTimeInterval currentPositionInSeconds;
@property (nonatomic) NSTimeInterval currentPositionInBeats;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic) float rate;
@end

@interface AVMusicTrack : NSObject
@property (nonatomic, retain, nullable) AVAudioUnit *destinationAudioUnit;
@property (nonatomic) MIDIEndpointRef destinationMIDIEndpoint;
@property (nonatomic) AVBeatRange loopRange;
@property (nonatomic, getter=isLoopingEnabled) BOOL loopingEnabled;
@property (nonatomic) NSInteger numberOfLoops;
@property (nonatomic) AVMusicTimeStamp offsetTime;
@property (nonatomic, getter=isMuted) BOOL muted;
@property (nonatomic, getter=isSoloed) BOOL soloed;
@property (nonatomic) AVMusicTimeStamp lengthInBeats;
@property (nonatomic) NSTimeInterval lengthInSeconds;
@property (nonatomic, readonly) NSUInteger timeResolution;
@property (nonatomic) BOOL usesAutomatedParameters;
- (void)addEvent:(AVMusicEvent *)event atBeat:(AVMusicTimeStamp)beat;
- (void)moveEventsInRange:(AVBeatRange)range byAmount:(AVMusicTimeStamp)beatAmount;
- (void)clearEventsInRange:(AVBeatRange)range;
- (void)cutEventsInRange:(AVBeatRange)range;
- (void)copyEventsInRange:(AVBeatRange)range fromTrack:(AVMusicTrack *)sourceTrack insertAtBeat:(AVMusicTimeStamp)insertStartBeat;
- (void)copyAndMergeEventsInRange:(AVBeatRange)range fromTrack:(AVMusicTrack *)sourceTrack mergeAtBeat:(AVMusicTimeStamp)mergeStartBeat;
- (void)enumerateEventsInRange:(AVBeatRange)range usingBlock:(AVMusicEventEnumerationBlock)block;
@end
NS_ASSUME_NONNULL_END
#endif
