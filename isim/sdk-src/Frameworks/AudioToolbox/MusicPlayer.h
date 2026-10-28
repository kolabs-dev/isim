#pragma once
/* isim AudioToolbox for C: Music Player and Music Sequence (Apple's MusicPlayer.h): sequences, tracks, events and their iterators, and the
 * player, over isim's Swift implementation (swift/overlays/AudioToolbox/MusicSequence.swift, MusicPlayer.swift). */
#include <AudioToolbox/AUGraph.h>
#include <CoreMIDI/CoreMIDI.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
enum {
    kAudioToolboxErr_InvalidSequenceType = -10846,
    kAudioToolboxErr_TrackIndexError = -10859,
    kAudioToolboxErr_TrackNotFound = -10858,
    kAudioToolboxErr_EndOfTrack = -10857,
    kAudioToolboxErr_StartOfTrack = -10856,
    kAudioToolboxErr_IllegalTrackDestination = -10855,
    kAudioToolboxErr_NoSequence = -10854,
    kAudioToolboxErr_InvalidEventType = -10853,
    kAudioToolboxErr_InvalidPlayerState = -10852,
    kAudioToolboxErr_CannotDoInCurrentContext = -10863,
    kAudioToolboxError_NoTrackDestination = -66720,
    kSequenceTrackProperty_LoopInfo = 0,
    kSequenceTrackProperty_OffsetTime = 1,
    kSequenceTrackProperty_MuteStatus = 2,
    kSequenceTrackProperty_SoloStatus = 3,
    kSequenceTrackProperty_AutomatedParameters = 4,
    kSequenceTrackProperty_TrackLength = 5,
    kSequenceTrackProperty_TimeResolution = 6,   /* / One event of a track: its time in beats, type and C bytes. */
};
AT_EXPORT OSStatus NewMusicSequence(MusicSequence _Nullable *_Nonnull outSequence);
AT_EXPORT OSStatus DisposeMusicSequence(MusicSequence inSequence);
AT_EXPORT OSStatus MusicSequenceNewTrack(MusicSequence inSequence, MusicTrack _Nullable *_Nonnull outTrack);
AT_EXPORT OSStatus MusicSequenceDisposeTrack(MusicSequence inSequence, MusicTrack inTrack);
AT_EXPORT OSStatus MusicSequenceGetTrackCount(MusicSequence inSequence, UInt32 *outNumberOfTracks);
AT_EXPORT OSStatus MusicSequenceGetIndTrack(MusicSequence inSequence, UInt32 inTrackIndex, MusicTrack _Nullable *_Nonnull outTrack);
AT_EXPORT OSStatus MusicSequenceGetTrackIndex(MusicSequence inSequence, MusicTrack inTrack, UInt32 *outTrackIndex);
AT_EXPORT OSStatus MusicSequenceGetTempoTrack(MusicSequence inSequence, MusicTrack _Nullable *_Nonnull outTrack);
AT_EXPORT OSStatus MusicSequenceSetAUGraph(MusicSequence inSequence, AUGraph _Nullable inGraph);
AT_EXPORT OSStatus MusicSequenceGetAUGraph(MusicSequence inSequence, AUGraph _Nullable *outGraph);
AT_EXPORT OSStatus MusicSequenceSetMIDIEndpoint(MusicSequence inSequence, MIDIEndpointRef inEndpoint);
AT_EXPORT OSStatus MusicSequenceSetSequenceType(MusicSequence inSequence, MusicSequenceType inType);
AT_EXPORT OSStatus MusicSequenceGetSequenceType(MusicSequence inSequence, MusicSequenceType *outType);
AT_EXPORT OSStatus MusicSequenceFileLoad(MusicSequence inSequence, CFURLRef inFileRef, MusicSequenceFileTypeID inFileTypeHint, MusicSequenceLoadFlags inFlags);
AT_EXPORT OSStatus MusicSequenceFileLoadData(MusicSequence inSequence, CFDataRef inData, MusicSequenceFileTypeID inFileTypeHint, MusicSequenceLoadFlags inFlags);
AT_EXPORT OSStatus MusicSequenceFileCreate(MusicSequence inSequence, CFURLRef inFileRef, MusicSequenceFileTypeID inFileType, MusicSequenceFileFlags inFlags, SInt16 inResolution);
AT_EXPORT OSStatus MusicSequenceFileCreateData(MusicSequence inSequence, MusicSequenceFileTypeID inFileType, MusicSequenceFileFlags inFlags, SInt16 inResolution, CFDataRef _Nullable *outData);
AT_EXPORT OSStatus MusicSequenceReverse(MusicSequence inSequence);
AT_EXPORT OSStatus MusicSequenceGetSecondsForBeats(MusicSequence inSequence, MusicTimeStamp inBeats, Float64 *outSeconds);
AT_EXPORT OSStatus MusicSequenceGetBeatsForSeconds(MusicSequence inSequence, Float64 inSeconds, MusicTimeStamp *outBeats);
AT_EXPORT OSStatus MusicSequenceSetUserCallback(MusicSequence inSequence, MusicSequenceUserCallback _Nullable inCallback, void * _Nullable inClientData);
AT_EXPORT OSStatus MusicSequenceBeatsToBarBeatTime(MusicSequence inSequence, MusicTimeStamp inBeats, UInt32 inSubbeatDivisor, CABarBeatTime *outBarBeatTime);
AT_EXPORT OSStatus MusicSequenceBarBeatTimeToBeats(MusicSequence inSequence, const CABarBeatTime *inBarBeatTime, MusicTimeStamp *outBeats);
AT_EXPORT CFDictionaryRef MusicSequenceGetInfoDictionary(MusicSequence inSequence) CF_RETURNS_RETAINED;
AT_EXPORT SInt16 MusicSequenceSetSMPTEResolution(SInt8 fps, UInt8 ticks);
AT_EXPORT void MusicSequenceGetSMPTEResolution(SInt16 inRes, SInt8 *fps, UInt8 *ticks);
AT_EXPORT OSStatus MusicTrackGetSequence(MusicTrack inTrack, MusicSequence _Nullable *_Nonnull outSequence);
AT_EXPORT OSStatus MusicTrackSetDestNode(MusicTrack inTrack, AUNode inNode);
AT_EXPORT OSStatus MusicTrackSetDestMIDIEndpoint(MusicTrack inTrack, MIDIEndpointRef inEndpoint);
AT_EXPORT OSStatus MusicTrackGetDestNode(MusicTrack inTrack, AUNode *outNode);
AT_EXPORT OSStatus MusicTrackGetDestMIDIEndpoint(MusicTrack inTrack, MIDIEndpointRef *outEndpoint);
AT_EXPORT OSStatus MusicTrackSetProperty(MusicTrack inTrack, UInt32 inPropertyID, void *inData, UInt32 inLength);
AT_EXPORT OSStatus MusicTrackGetProperty(MusicTrack inTrack, UInt32 inPropertyID, void *outData, UInt32 *ioLength);
AT_EXPORT OSStatus MusicTrackNewMIDINoteEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const MIDINoteMessage *inMessage);
AT_EXPORT OSStatus MusicTrackNewMIDIChannelEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const MIDIChannelMessage *inMessage);
AT_EXPORT OSStatus MusicTrackNewMIDIRawDataEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const MIDIRawData *inRawData);
AT_EXPORT OSStatus MusicTrackNewExtendedNoteEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const ExtendedNoteOnEvent *inInfo);
AT_EXPORT OSStatus MusicTrackNewParameterEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const ParameterEvent *inInfo);
AT_EXPORT OSStatus MusicTrackNewExtendedTempoEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, Float64 inBPM);
AT_EXPORT OSStatus MusicTrackNewMetaEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const MIDIMetaEvent *inMetaEvent);
AT_EXPORT OSStatus MusicTrackNewUserEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const MusicEventUserData *inUserData);
AT_EXPORT OSStatus MusicTrackNewAUPresetEvent(MusicTrack inTrack, MusicTimeStamp inTimeStamp, const AUPresetEvent *inPresetEvent);
AT_EXPORT OSStatus MusicTrackMoveEvents(MusicTrack inTrack, MusicTimeStamp inStartTime, MusicTimeStamp inEndTime, MusicTimeStamp inMoveTime);
AT_EXPORT OSStatus MusicTrackClear(MusicTrack inTrack, MusicTimeStamp inStartTime, MusicTimeStamp inEndTime);
AT_EXPORT OSStatus MusicTrackCut(MusicTrack inTrack, MusicTimeStamp inStartTime, MusicTimeStamp inEndTime);
AT_EXPORT OSStatus MusicTrackCopyInsert(MusicTrack inSourceTrack, MusicTimeStamp inSourceStartTime, MusicTimeStamp inSourceEndTime, MusicTrack inDestTrack, MusicTimeStamp inDestInsertTime);
AT_EXPORT OSStatus MusicTrackMerge(MusicTrack inSourceTrack, MusicTimeStamp inSourceStartTime, MusicTimeStamp inSourceEndTime, MusicTrack inDestTrack, MusicTimeStamp inDestInsertTime);
AT_EXPORT OSStatus NewMusicEventIterator(MusicTrack inTrack, MusicEventIterator _Nullable *_Nonnull outIterator);
AT_EXPORT OSStatus DisposeMusicEventIterator(MusicEventIterator inIterator);
AT_EXPORT OSStatus MusicEventIteratorSeek(MusicEventIterator inIterator, MusicTimeStamp inTimeStamp);
AT_EXPORT OSStatus MusicEventIteratorNextEvent(MusicEventIterator inIterator);
AT_EXPORT OSStatus MusicEventIteratorPreviousEvent(MusicEventIterator inIterator);
AT_EXPORT OSStatus MusicEventIteratorGetEventInfo(MusicEventIterator inIterator, MusicTimeStamp * _Nullable outTimeStamp, MusicEventType * _Nullable outEventType, const void * _Nullable * _Nullable outEventData, UInt32 * _Nullable outEventDataSize);
AT_EXPORT OSStatus MusicEventIteratorSetEventInfo(MusicEventIterator inIterator, MusicEventType inEventType, const void *inEventData);
AT_EXPORT OSStatus MusicEventIteratorSetEventTime(MusicEventIterator inIterator, MusicTimeStamp inTimeStamp);
AT_EXPORT OSStatus MusicEventIteratorDeleteEvent(MusicEventIterator inIterator);
AT_EXPORT OSStatus MusicEventIteratorHasPreviousEvent(MusicEventIterator inIterator, Boolean *outHasPrevEvent);
AT_EXPORT OSStatus MusicEventIteratorHasNextEvent(MusicEventIterator inIterator, Boolean *outHasNextEvent);
AT_EXPORT OSStatus MusicEventIteratorHasCurrentEvent(MusicEventIterator inIterator, Boolean *outHasCurEvent);
AT_EXPORT OSStatus NewMusicPlayer(MusicPlayer _Nullable *_Nonnull outPlayer);
AT_EXPORT OSStatus DisposeMusicPlayer(MusicPlayer inPlayer);
AT_EXPORT OSStatus MusicPlayerSetSequence(MusicPlayer inPlayer, MusicSequence _Nullable inSequence);
AT_EXPORT OSStatus MusicPlayerGetSequence(MusicPlayer inPlayer, MusicSequence _Nullable *_Nonnull outSequence);
AT_EXPORT OSStatus MusicPlayerSetTime(MusicPlayer inPlayer, MusicTimeStamp inTime);
AT_EXPORT OSStatus MusicPlayerGetTime(MusicPlayer inPlayer, MusicTimeStamp *outTime);
AT_EXPORT OSStatus MusicPlayerGetHostTimeForBeats(MusicPlayer inPlayer, MusicTimeStamp inBeats, UInt64 *outHostTime);
AT_EXPORT OSStatus MusicPlayerGetBeatsForHostTime(MusicPlayer inPlayer, UInt64 inHostTime, MusicTimeStamp *outBeats);
AT_EXPORT OSStatus MusicPlayerPreroll(MusicPlayer inPlayer);
AT_EXPORT OSStatus MusicPlayerStart(MusicPlayer inPlayer);
AT_EXPORT OSStatus MusicPlayerStop(MusicPlayer inPlayer);
AT_EXPORT OSStatus MusicPlayerIsPlaying(MusicPlayer inPlayer, Boolean *outIsPlaying);
AT_EXPORT OSStatus MusicPlayerSetPlayRateScalar(MusicPlayer inPlayer, Float64 inScaleRate);
AT_EXPORT OSStatus MusicPlayerGetPlayRateScalar(MusicPlayer inPlayer, Float64 *outScaleRate);
#pragma clang assume_nonnull end
__END_DECLS
#endif
