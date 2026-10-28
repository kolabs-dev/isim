// The C functions of Music Player, Music Device, Audio File Stream and CAClock, forwarding to the Swift functions of
// the same names (MusicPlayer.h, MusicDevice.h, AudioFileStream.h, CAClock.h). C's Boolean is UInt8 here.
import Foundation
import CoreMIDI
private func _bool(_ p: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<DarwinBoolean> {
    UnsafeMutableRawPointer(p).assumingMemoryBound(to: DarwinBoolean.self)
}


@_cdecl("NewMusicSequence")
public func _c_NewMusicSequence(_ outSequence: UnsafeMutablePointer<MusicSequence?>) -> OSStatus { NewMusicSequence(outSequence) }
@_cdecl("DisposeMusicSequence")
public func _c_DisposeMusicSequence(_ inSequence: MusicSequence) -> OSStatus { DisposeMusicSequence(inSequence) }
@_cdecl("MusicSequenceNewTrack")
public func _c_MusicSequenceNewTrack(_ inSequence: MusicSequence, _ outTrack: UnsafeMutablePointer<MusicTrack?>) -> OSStatus { MusicSequenceNewTrack(inSequence, outTrack) }
@_cdecl("MusicSequenceDisposeTrack")
public func _c_MusicSequenceDisposeTrack(_ inSequence: MusicSequence, _ inTrack: MusicTrack) -> OSStatus { MusicSequenceDisposeTrack(inSequence, inTrack) }
@_cdecl("MusicSequenceGetTrackCount")
public func _c_MusicSequenceGetTrackCount(_ inSequence: MusicSequence, _ outNumberOfTracks: UnsafeMutablePointer<UInt32>) -> OSStatus { MusicSequenceGetTrackCount(inSequence, outNumberOfTracks) }
@_cdecl("MusicSequenceGetIndTrack")
public func _c_MusicSequenceGetIndTrack(_ inSequence: MusicSequence, _ inTrackIndex: UInt32, _ outTrack: UnsafeMutablePointer<MusicTrack?>) -> OSStatus { MusicSequenceGetIndTrack(inSequence, inTrackIndex, outTrack) }
@_cdecl("MusicSequenceGetTrackIndex")
public func _c_MusicSequenceGetTrackIndex(_ inSequence: MusicSequence, _ inTrack: MusicTrack, _ outTrackIndex: UnsafeMutablePointer<UInt32>) -> OSStatus { MusicSequenceGetTrackIndex(inSequence, inTrack, outTrackIndex) }
@_cdecl("MusicSequenceGetTempoTrack")
public func _c_MusicSequenceGetTempoTrack(_ inSequence: MusicSequence, _ outTrack: UnsafeMutablePointer<MusicTrack?>) -> OSStatus { MusicSequenceGetTempoTrack(inSequence, outTrack) }
@_cdecl("MusicSequenceSetAUGraph")
public func _c_MusicSequenceSetAUGraph(_ inSequence: MusicSequence, _ inGraph: AUGraph?) -> OSStatus { MusicSequenceSetAUGraph(inSequence, inGraph) }
@_cdecl("MusicSequenceGetAUGraph")
public func _c_MusicSequenceGetAUGraph(_ inSequence: MusicSequence, _ outGraph: UnsafeMutablePointer<AUGraph?>) -> OSStatus { MusicSequenceGetAUGraph(inSequence, outGraph) }
@_cdecl("MusicSequenceSetMIDIEndpoint")
public func _c_MusicSequenceSetMIDIEndpoint(_ inSequence: MusicSequence, _ inEndpoint: MIDIEndpointRef) -> OSStatus { MusicSequenceSetMIDIEndpoint(inSequence, inEndpoint) }
@_cdecl("MusicSequenceSetSequenceType")
public func _c_MusicSequenceSetSequenceType(_ inSequence: MusicSequence, _ inType: MusicSequenceType) -> OSStatus { MusicSequenceSetSequenceType(inSequence, inType) }
@_cdecl("MusicSequenceGetSequenceType")
public func _c_MusicSequenceGetSequenceType(_ inSequence: MusicSequence, _ outType: UnsafeMutablePointer<MusicSequenceType>) -> OSStatus { MusicSequenceGetSequenceType(inSequence, outType) }
@_cdecl("MusicSequenceFileLoad")
public func _c_MusicSequenceFileLoad(_ inSequence: MusicSequence, _ inFileRef: CFURL, _ inFileTypeHint: MusicSequenceFileTypeID, _ inFlags: MusicSequenceLoadFlags) -> OSStatus { MusicSequenceFileLoad(inSequence, inFileRef, inFileTypeHint, inFlags) }
@_cdecl("MusicSequenceFileLoadData")
public func _c_MusicSequenceFileLoadData(_ inSequence: MusicSequence, _ inData: CFData, _ inFileTypeHint: MusicSequenceFileTypeID, _ inFlags: MusicSequenceLoadFlags) -> OSStatus { MusicSequenceFileLoadData(inSequence, inData, inFileTypeHint, inFlags) }
@_cdecl("MusicSequenceFileCreate")
public func _c_MusicSequenceFileCreate(_ inSequence: MusicSequence, _ inFileRef: CFURL, _ inFileType: MusicSequenceFileTypeID, _ inFlags: MusicSequenceFileFlags, _ inResolution: Int16) -> OSStatus { MusicSequenceFileCreate(inSequence, inFileRef, inFileType, inFlags, inResolution) }
@_cdecl("MusicSequenceFileCreateData")
public func _c_MusicSequenceFileCreateData(_ inSequence: MusicSequence, _ inFileType: MusicSequenceFileTypeID, _ inFlags: MusicSequenceFileFlags, _ inResolution: Int16, _ outData: UnsafeMutablePointer<Unmanaged<CFData>?>) -> OSStatus { MusicSequenceFileCreateData(inSequence, inFileType, inFlags, inResolution, outData) }
@_cdecl("MusicSequenceReverse")
public func _c_MusicSequenceReverse(_ inSequence: MusicSequence) -> OSStatus { MusicSequenceReverse(inSequence) }
@_cdecl("MusicSequenceGetSecondsForBeats")
public func _c_MusicSequenceGetSecondsForBeats(_ inSequence: MusicSequence, _ inBeats: MusicTimeStamp, _ outSeconds: UnsafeMutablePointer<Float64>) -> OSStatus { MusicSequenceGetSecondsForBeats(inSequence, inBeats, outSeconds) }
@_cdecl("MusicSequenceGetBeatsForSeconds")
public func _c_MusicSequenceGetBeatsForSeconds(_ inSequence: MusicSequence, _ inSeconds: Float64, _ outBeats: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus { MusicSequenceGetBeatsForSeconds(inSequence, inSeconds, outBeats) }
@_cdecl("MusicSequenceSetUserCallback")
public func _c_MusicSequenceSetUserCallback(_ inSequence: MusicSequence, _ inCallback: MusicSequenceUserCallback?, _ inClientData: UnsafeMutableRawPointer?) -> OSStatus { MusicSequenceSetUserCallback(inSequence, inCallback, inClientData) }
@_cdecl("MusicSequenceBeatsToBarBeatTime")
public func _c_MusicSequenceBeatsToBarBeatTime(_ inSequence: MusicSequence, _ inBeats: MusicTimeStamp, _ inSubbeatDivisor: UInt32, _ outBarBeatTime: UnsafeMutablePointer<CABarBeatTime>) -> OSStatus { MusicSequenceBeatsToBarBeatTime(inSequence, inBeats, inSubbeatDivisor, outBarBeatTime) }
@_cdecl("MusicSequenceBarBeatTimeToBeats")
public func _c_MusicSequenceBarBeatTimeToBeats(_ inSequence: MusicSequence, _ inBarBeatTime: UnsafePointer<CABarBeatTime>, _ outBeats: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus { MusicSequenceBarBeatTimeToBeats(inSequence, inBarBeatTime, outBeats) }
@_cdecl("MusicSequenceGetInfoDictionary")
public func _c_MusicSequenceGetInfoDictionary(_ inSequence: MusicSequence) -> Unmanaged<CFDictionary> { Unmanaged.passRetained(MusicSequenceGetInfoDictionary(inSequence)) }
@_cdecl("MusicSequenceSetSMPTEResolution")
public func _c_MusicSequenceSetSMPTEResolution(_ fps: Int8, _ ticks: UInt8) -> Int16 { MusicSequenceSetSMPTEResolution(fps, ticks) }
@_cdecl("MusicSequenceGetSMPTEResolution")
public func _c_MusicSequenceGetSMPTEResolution(_ inRes: Int16, _ fps: UnsafeMutablePointer<Int8>, _ ticks: UnsafeMutablePointer<UInt8>) -> Void { MusicSequenceGetSMPTEResolution(inRes, fps, ticks) }
@_cdecl("MusicTrackGetSequence")
public func _c_MusicTrackGetSequence(_ inTrack: MusicTrack, _ outSequence: UnsafeMutablePointer<MusicSequence?>) -> OSStatus { MusicTrackGetSequence(inTrack, outSequence) }
@_cdecl("MusicTrackSetDestNode")
public func _c_MusicTrackSetDestNode(_ inTrack: MusicTrack, _ inNode: AUNode) -> OSStatus { MusicTrackSetDestNode(inTrack, inNode) }
@_cdecl("MusicTrackSetDestMIDIEndpoint")
public func _c_MusicTrackSetDestMIDIEndpoint(_ inTrack: MusicTrack, _ inEndpoint: MIDIEndpointRef) -> OSStatus { MusicTrackSetDestMIDIEndpoint(inTrack, inEndpoint) }
@_cdecl("MusicTrackGetDestNode")
public func _c_MusicTrackGetDestNode(_ inTrack: MusicTrack, _ outNode: UnsafeMutablePointer<AUNode>) -> OSStatus { MusicTrackGetDestNode(inTrack, outNode) }
@_cdecl("MusicTrackGetDestMIDIEndpoint")
public func _c_MusicTrackGetDestMIDIEndpoint(_ inTrack: MusicTrack, _ outEndpoint: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus { MusicTrackGetDestMIDIEndpoint(inTrack, outEndpoint) }
@_cdecl("MusicTrackSetProperty")
public func _c_MusicTrackSetProperty(_ inTrack: MusicTrack, _ inPropertyID: UInt32, _ inData: UnsafeMutableRawPointer, _ inLength: UInt32) -> OSStatus { MusicTrackSetProperty(inTrack, inPropertyID, inData, inLength) }
@_cdecl("MusicTrackGetProperty")
public func _c_MusicTrackGetProperty(_ inTrack: MusicTrack, _ inPropertyID: UInt32, _ outData: UnsafeMutableRawPointer, _ ioLength: UnsafeMutablePointer<UInt32>) -> OSStatus { MusicTrackGetProperty(inTrack, inPropertyID, outData, ioLength) }
@_cdecl("MusicTrackNewMIDINoteEvent")
public func _c_MusicTrackNewMIDINoteEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inMessage: UnsafePointer<MIDINoteMessage>) -> OSStatus { MusicTrackNewMIDINoteEvent(inTrack, inTimeStamp, inMessage) }
@_cdecl("MusicTrackNewMIDIChannelEvent")
public func _c_MusicTrackNewMIDIChannelEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inMessage: UnsafePointer<MIDIChannelMessage>) -> OSStatus { MusicTrackNewMIDIChannelEvent(inTrack, inTimeStamp, inMessage) }
@_cdecl("MusicTrackNewMIDIRawDataEvent")
public func _c_MusicTrackNewMIDIRawDataEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inRawData: UnsafePointer<MIDIRawData>) -> OSStatus { MusicTrackNewMIDIRawDataEvent(inTrack, inTimeStamp, inRawData) }
@_cdecl("MusicTrackNewExtendedNoteEvent")
public func _c_MusicTrackNewExtendedNoteEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inInfo: UnsafePointer<ExtendedNoteOnEvent>) -> OSStatus { MusicTrackNewExtendedNoteEvent(inTrack, inTimeStamp, inInfo) }
@_cdecl("MusicTrackNewParameterEvent")
public func _c_MusicTrackNewParameterEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inInfo: UnsafePointer<ParameterEvent>) -> OSStatus { MusicTrackNewParameterEvent(inTrack, inTimeStamp, inInfo) }
@_cdecl("MusicTrackNewExtendedTempoEvent")
public func _c_MusicTrackNewExtendedTempoEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inBPM: Float64) -> OSStatus { MusicTrackNewExtendedTempoEvent(inTrack, inTimeStamp, inBPM) }
@_cdecl("MusicTrackNewMetaEvent")
public func _c_MusicTrackNewMetaEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inMetaEvent: UnsafePointer<MIDIMetaEvent>) -> OSStatus { MusicTrackNewMetaEvent(inTrack, inTimeStamp, inMetaEvent) }
@_cdecl("MusicTrackNewUserEvent")
public func _c_MusicTrackNewUserEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inUserData: UnsafePointer<MusicEventUserData>) -> OSStatus { MusicTrackNewUserEvent(inTrack, inTimeStamp, inUserData) }
@_cdecl("MusicTrackNewAUPresetEvent")
public func _c_MusicTrackNewAUPresetEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inPresetEvent: UnsafePointer<AUPresetEvent>) -> OSStatus { MusicTrackNewAUPresetEvent(inTrack, inTimeStamp, inPresetEvent) }
@_cdecl("MusicTrackMoveEvents")
public func _c_MusicTrackMoveEvents(_ inTrack: MusicTrack, _ inStartTime: MusicTimeStamp, _ inEndTime: MusicTimeStamp, _ inMoveTime: MusicTimeStamp) -> OSStatus { MusicTrackMoveEvents(inTrack, inStartTime, inEndTime, inMoveTime) }
@_cdecl("MusicTrackClear")
public func _c_MusicTrackClear(_ inTrack: MusicTrack, _ inStartTime: MusicTimeStamp, _ inEndTime: MusicTimeStamp) -> OSStatus { MusicTrackClear(inTrack, inStartTime, inEndTime) }
@_cdecl("MusicTrackCut")
public func _c_MusicTrackCut(_ inTrack: MusicTrack, _ inStartTime: MusicTimeStamp, _ inEndTime: MusicTimeStamp) -> OSStatus { MusicTrackCut(inTrack, inStartTime, inEndTime) }
@_cdecl("MusicTrackCopyInsert")
public func _c_MusicTrackCopyInsert(_ inSourceTrack: MusicTrack, _ inSourceStartTime: MusicTimeStamp, _ inSourceEndTime: MusicTimeStamp, _ inDestTrack: MusicTrack, _ inDestInsertTime: MusicTimeStamp) -> OSStatus { MusicTrackCopyInsert(inSourceTrack, inSourceStartTime, inSourceEndTime, inDestTrack, inDestInsertTime) }
@_cdecl("MusicTrackMerge")
public func _c_MusicTrackMerge(_ inSourceTrack: MusicTrack, _ inSourceStartTime: MusicTimeStamp, _ inSourceEndTime: MusicTimeStamp, _ inDestTrack: MusicTrack, _ inDestInsertTime: MusicTimeStamp) -> OSStatus { MusicTrackMerge(inSourceTrack, inSourceStartTime, inSourceEndTime, inDestTrack, inDestInsertTime) }
@_cdecl("NewMusicEventIterator")
public func _c_NewMusicEventIterator(_ inTrack: MusicTrack, _ outIterator: UnsafeMutablePointer<MusicEventIterator?>) -> OSStatus { NewMusicEventIterator(inTrack, outIterator) }
@_cdecl("DisposeMusicEventIterator")
public func _c_DisposeMusicEventIterator(_ inIterator: MusicEventIterator) -> OSStatus { DisposeMusicEventIterator(inIterator) }
@_cdecl("MusicEventIteratorSeek")
public func _c_MusicEventIteratorSeek(_ inIterator: MusicEventIterator, _ inTimeStamp: MusicTimeStamp) -> OSStatus { MusicEventIteratorSeek(inIterator, inTimeStamp) }
@_cdecl("MusicEventIteratorNextEvent")
public func _c_MusicEventIteratorNextEvent(_ inIterator: MusicEventIterator) -> OSStatus { MusicEventIteratorNextEvent(inIterator) }
@_cdecl("MusicEventIteratorPreviousEvent")
public func _c_MusicEventIteratorPreviousEvent(_ inIterator: MusicEventIterator) -> OSStatus { MusicEventIteratorPreviousEvent(inIterator) }
@_cdecl("MusicEventIteratorGetEventInfo")
public func _c_MusicEventIteratorGetEventInfo(_ inIterator: MusicEventIterator, _ outTimeStamp: UnsafeMutablePointer<MusicTimeStamp>?, _ outEventType: UnsafeMutablePointer<MusicEventType>?, _ outEventData: UnsafeMutablePointer<UnsafeRawPointer?>?, _ outEventDataSize: UnsafeMutablePointer<UInt32>?) -> OSStatus { MusicEventIteratorGetEventInfo(inIterator, outTimeStamp, outEventType, outEventData, outEventDataSize) }
@_cdecl("MusicEventIteratorSetEventInfo")
public func _c_MusicEventIteratorSetEventInfo(_ inIterator: MusicEventIterator, _ inEventType: MusicEventType, _ inEventData: UnsafeRawPointer) -> OSStatus { MusicEventIteratorSetEventInfo(inIterator, inEventType, inEventData) }
@_cdecl("MusicEventIteratorSetEventTime")
public func _c_MusicEventIteratorSetEventTime(_ inIterator: MusicEventIterator, _ inTimeStamp: MusicTimeStamp) -> OSStatus { MusicEventIteratorSetEventTime(inIterator, inTimeStamp) }
@_cdecl("MusicEventIteratorDeleteEvent")
public func _c_MusicEventIteratorDeleteEvent(_ inIterator: MusicEventIterator) -> OSStatus { MusicEventIteratorDeleteEvent(inIterator) }
@_cdecl("MusicEventIteratorHasPreviousEvent")
public func _c_MusicEventIteratorHasPreviousEvent(_ inIterator: MusicEventIterator, _ outHasPrevEvent: UnsafeMutablePointer<UInt8>) -> OSStatus { MusicEventIteratorHasPreviousEvent(inIterator, _bool(outHasPrevEvent)) }
@_cdecl("MusicEventIteratorHasNextEvent")
public func _c_MusicEventIteratorHasNextEvent(_ inIterator: MusicEventIterator, _ outHasNextEvent: UnsafeMutablePointer<UInt8>) -> OSStatus { MusicEventIteratorHasNextEvent(inIterator, _bool(outHasNextEvent)) }
@_cdecl("MusicEventIteratorHasCurrentEvent")
public func _c_MusicEventIteratorHasCurrentEvent(_ inIterator: MusicEventIterator, _ outHasCurEvent: UnsafeMutablePointer<UInt8>) -> OSStatus { MusicEventIteratorHasCurrentEvent(inIterator, _bool(outHasCurEvent)) }
@_cdecl("NewMusicPlayer")
public func _c_NewMusicPlayer(_ outPlayer: UnsafeMutablePointer<MusicPlayer?>) -> OSStatus { NewMusicPlayer(outPlayer) }
@_cdecl("DisposeMusicPlayer")
public func _c_DisposeMusicPlayer(_ inPlayer: MusicPlayer) -> OSStatus { DisposeMusicPlayer(inPlayer) }
@_cdecl("MusicPlayerSetSequence")
public func _c_MusicPlayerSetSequence(_ inPlayer: MusicPlayer, _ inSequence: MusicSequence?) -> OSStatus { MusicPlayerSetSequence(inPlayer, inSequence) }
@_cdecl("MusicPlayerGetSequence")
public func _c_MusicPlayerGetSequence(_ inPlayer: MusicPlayer, _ outSequence: UnsafeMutablePointer<MusicSequence?>) -> OSStatus { MusicPlayerGetSequence(inPlayer, outSequence) }
@_cdecl("MusicPlayerSetTime")
public func _c_MusicPlayerSetTime(_ inPlayer: MusicPlayer, _ inTime: MusicTimeStamp) -> OSStatus { MusicPlayerSetTime(inPlayer, inTime) }
@_cdecl("MusicPlayerGetTime")
public func _c_MusicPlayerGetTime(_ inPlayer: MusicPlayer, _ outTime: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus { MusicPlayerGetTime(inPlayer, outTime) }
@_cdecl("MusicPlayerGetHostTimeForBeats")
public func _c_MusicPlayerGetHostTimeForBeats(_ inPlayer: MusicPlayer, _ inBeats: MusicTimeStamp, _ outHostTime: UnsafeMutablePointer<UInt64>) -> OSStatus { MusicPlayerGetHostTimeForBeats(inPlayer, inBeats, outHostTime) }
@_cdecl("MusicPlayerGetBeatsForHostTime")
public func _c_MusicPlayerGetBeatsForHostTime(_ inPlayer: MusicPlayer, _ inHostTime: UInt64, _ outBeats: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus { MusicPlayerGetBeatsForHostTime(inPlayer, inHostTime, outBeats) }
@_cdecl("MusicPlayerPreroll")
public func _c_MusicPlayerPreroll(_ inPlayer: MusicPlayer) -> OSStatus { MusicPlayerPreroll(inPlayer) }
@_cdecl("MusicPlayerStart")
public func _c_MusicPlayerStart(_ inPlayer: MusicPlayer) -> OSStatus { MusicPlayerStart(inPlayer) }
@_cdecl("MusicPlayerStop")
public func _c_MusicPlayerStop(_ inPlayer: MusicPlayer) -> OSStatus { MusicPlayerStop(inPlayer) }
@_cdecl("MusicPlayerIsPlaying")
public func _c_MusicPlayerIsPlaying(_ inPlayer: MusicPlayer, _ outIsPlaying: UnsafeMutablePointer<UInt8>) -> OSStatus { MusicPlayerIsPlaying(inPlayer, _bool(outIsPlaying)) }
@_cdecl("MusicPlayerSetPlayRateScalar")
public func _c_MusicPlayerSetPlayRateScalar(_ inPlayer: MusicPlayer, _ inScaleRate: Float64) -> OSStatus { MusicPlayerSetPlayRateScalar(inPlayer, inScaleRate) }
@_cdecl("MusicPlayerGetPlayRateScalar")
public func _c_MusicPlayerGetPlayRateScalar(_ inPlayer: MusicPlayer, _ outScaleRate: UnsafeMutablePointer<Float64>) -> OSStatus { MusicPlayerGetPlayRateScalar(inPlayer, outScaleRate) }
@_cdecl("CAClockNew")
public func _c_CAClockNew(_ inReservedFlags: UInt32, _ outCAClock: UnsafeMutablePointer<CAClockRef?>) -> OSStatus { CAClockNew(inReservedFlags, outCAClock) }
@_cdecl("CAClockDispose")
public func _c_CAClockDispose(_ inCAClock: CAClockRef) -> OSStatus { CAClockDispose(inCAClock) }
@_cdecl("CAClockGetPropertyInfo")
public func _c_CAClockGetPropertyInfo(_ inCAClock: CAClockRef, _ inPropertyID: CAClockPropertyID, _ outSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<UInt8>?) -> OSStatus { CAClockGetPropertyInfo(inCAClock, inPropertyID, outSize, outWritable.map(_bool)) }
@_cdecl("CAClockGetProperty")
public func _c_CAClockGetProperty(_ inCAClock: CAClockRef, _ inPropertyID: CAClockPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus { CAClockGetProperty(inCAClock, inPropertyID, ioPropertyDataSize, outPropertyData) }
@_cdecl("CAClockSetProperty")
public func _c_CAClockSetProperty(_ inCAClock: CAClockRef, _ inPropertyID: CAClockPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus { CAClockSetProperty(inCAClock, inPropertyID, inPropertyDataSize, inPropertyData) }
@_cdecl("CAClockAddListener")
public func _c_CAClockAddListener(_ inCAClock: CAClockRef, _ inListenerProc: CAClockListenerProc, _ inUserData: UnsafeMutableRawPointer) -> OSStatus { CAClockAddListener(inCAClock, inListenerProc, inUserData) }
@_cdecl("CAClockRemoveListener")
public func _c_CAClockRemoveListener(_ inCAClock: CAClockRef, _ inListenerProc: CAClockListenerProc, _ inUserData: UnsafeMutableRawPointer) -> OSStatus { CAClockRemoveListener(inCAClock, inListenerProc, inUserData) }
@_cdecl("CAClockSetCurrentTime")
public func _c_CAClockSetCurrentTime(_ inCAClock: CAClockRef, _ inTime: UnsafePointer<CAClockTime>) -> OSStatus { CAClockSetCurrentTime(inCAClock, inTime) }
@_cdecl("CAClockGetCurrentTime")
public func _c_CAClockGetCurrentTime(_ inCAClock: CAClockRef, _ inTimeFormat: CAClockTimeFormat, _ outTime: UnsafeMutablePointer<CAClockTime>) -> OSStatus { CAClockGetCurrentTime(inCAClock, inTimeFormat, outTime) }
@_cdecl("CAClockGetStartTime")
public func _c_CAClockGetStartTime(_ inCAClock: CAClockRef, _ inTimeFormat: CAClockTimeFormat, _ outTime: UnsafeMutablePointer<CAClockTime>) -> OSStatus { CAClockGetStartTime(inCAClock, inTimeFormat, outTime) }
@_cdecl("CAClockTranslateTime")
public func _c_CAClockTranslateTime(_ inCAClock: CAClockRef, _ inTime: UnsafePointer<CAClockTime>, _ inOutputTimeFormat: CAClockTimeFormat, _ outTime: UnsafeMutablePointer<CAClockTime>) -> OSStatus { CAClockTranslateTime(inCAClock, inTime, inOutputTimeFormat, outTime) }
@_cdecl("CAClockStart")
public func _c_CAClockStart(_ inCAClock: CAClockRef) -> OSStatus { CAClockStart(inCAClock) }
@_cdecl("CAClockStop")
public func _c_CAClockStop(_ inCAClock: CAClockRef) -> OSStatus { CAClockStop(inCAClock) }
@_cdecl("CAClockArm")
public func _c_CAClockArm(_ inCAClock: CAClockRef) -> OSStatus { CAClockArm(inCAClock) }
@_cdecl("CAClockDisarm")
public func _c_CAClockDisarm(_ inCAClock: CAClockRef) -> OSStatus { CAClockDisarm(inCAClock) }
@_cdecl("CAClockSetPlayRate")
public func _c_CAClockSetPlayRate(_ inCAClock: CAClockRef, _ inPlayRate: Float64) -> OSStatus { CAClockSetPlayRate(inCAClock, inPlayRate) }
@_cdecl("CAClockGetPlayRate")
public func _c_CAClockGetPlayRate(_ inCAClock: CAClockRef, _ outPlayRate: UnsafeMutablePointer<Float64>) -> OSStatus { CAClockGetPlayRate(inCAClock, outPlayRate) }
@_cdecl("CAClockGetCurrentTempo")
public func _c_CAClockGetCurrentTempo(_ inCAClock: CAClockRef, _ outTempo: UnsafeMutablePointer<CAClockTempo>, _ outTimestamp: UnsafeMutablePointer<CAClockTime>?) -> OSStatus { CAClockGetCurrentTempo(inCAClock, outTempo, outTimestamp) }
@_cdecl("CAClockSetCurrentTempo")
public func _c_CAClockSetCurrentTempo(_ inCAClock: CAClockRef, _ inTempo: CAClockTempo, _ inTimestamp: UnsafePointer<CAClockTime>?) -> OSStatus { CAClockSetCurrentTempo(inCAClock, inTempo, inTimestamp) }
@_cdecl("CAClockSecondsToSMPTETime")
public func _c_CAClockSecondsToSMPTETime(_ inCAClock: CAClockRef, _ inSeconds: CAClockSeconds, _ inSubframeDivisor: UInt16, _ outSMPTETime: UnsafeMutablePointer<SMPTETime>) -> OSStatus { CAClockSecondsToSMPTETime(inCAClock, inSeconds, inSubframeDivisor, outSMPTETime) }
@_cdecl("CAClockSMPTETimeToSeconds")
public func _c_CAClockSMPTETimeToSeconds(_ inCAClock: CAClockRef, _ inSMPTETime: UnsafePointer<SMPTETime>, _ outSeconds: UnsafeMutablePointer<CAClockSeconds>) -> OSStatus { CAClockSMPTETimeToSeconds(inCAClock, inSMPTETime, outSeconds) }
@_cdecl("CAClockBeatsToBarBeatTime")
public func _c_CAClockBeatsToBarBeatTime(_ inCAClock: CAClockRef, _ inBeats: CAClockBeats, _ inSubbeatDivisor: UInt16, _ outBarBeatTime: UnsafeMutablePointer<CABarBeatTime>) -> OSStatus { CAClockBeatsToBarBeatTime(inCAClock, inBeats, inSubbeatDivisor, outBarBeatTime) }
@_cdecl("CAClockBarBeatTimeToBeats")
public func _c_CAClockBarBeatTimeToBeats(_ inCAClock: CAClockRef, _ inBarBeatTime: UnsafePointer<CABarBeatTime>, _ outBeats: UnsafeMutablePointer<CAClockBeats>) -> OSStatus { CAClockBarBeatTimeToBeats(inCAClock, inBarBeatTime, outBeats) }
@_cdecl("CAClockParseMIDI")
public func _c_CAClockParseMIDI(_ inCAClock: CAClockRef, _ inMIDIPacketList: UnsafePointer<MIDIPacketList>) -> OSStatus { CAClockParseMIDI(inCAClock, inMIDIPacketList) }
@_cdecl("AudioFileStreamOpen")
public func _c_AudioFileStreamOpen(_ inClientData: UnsafeMutableRawPointer?, _ inPropertyListenerProc: AudioFileStream_PropertyListenerProc, _ inPacketsProc: AudioFileStream_PacketsProc, _ inFileTypeHint: AudioFileTypeID, _ outAudioFileStream: UnsafeMutablePointer<AudioFileStreamID?>) -> OSStatus { AudioFileStreamOpen(inClientData, inPropertyListenerProc, inPacketsProc, inFileTypeHint, outAudioFileStream) }
@_cdecl("AudioFileStreamParseBytes")
public func _c_AudioFileStreamParseBytes(_ inAudioFileStream: AudioFileStreamID, _ inDataByteSize: UInt32, _ inData: UnsafeRawPointer?, _ inFlags: AudioFileStreamParseFlags) -> OSStatus { AudioFileStreamParseBytes(inAudioFileStream, inDataByteSize, inData, inFlags) }
@_cdecl("AudioFileStreamSeek")
public func _c_AudioFileStreamSeek(_ inAudioFileStream: AudioFileStreamID, _ inPacketOffset: Int64, _ outDataByteOffset: UnsafeMutablePointer<Int64>, _ ioFlags: UnsafeMutablePointer<AudioFileStreamSeekFlags>) -> OSStatus { AudioFileStreamSeek(inAudioFileStream, inPacketOffset, outDataByteOffset, ioFlags) }
@_cdecl("AudioFileStreamGetPropertyInfo")
public func _c_AudioFileStreamGetPropertyInfo(_ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID, _ outPropertyDataSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<UInt8>?) -> OSStatus { AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, outPropertyDataSize, outWritable.map(_bool)) }
@_cdecl("AudioFileStreamGetProperty")
public func _c_AudioFileStreamGetProperty(_ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus { AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, ioPropertyDataSize, outPropertyData) }
@_cdecl("AudioFileStreamSetProperty")
public func _c_AudioFileStreamSetProperty(_ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus { AudioFileStreamSetProperty(inAudioFileStream, inPropertyID, inPropertyDataSize, inPropertyData) }
@_cdecl("AudioFileStreamClose")
public func _c_AudioFileStreamClose(_ inAudioFileStream: AudioFileStreamID) -> OSStatus { AudioFileStreamClose(inAudioFileStream) }
@_cdecl("MusicDeviceMIDIEvent")
public func _c_MusicDeviceMIDIEvent(_ inUnit: MusicDeviceComponent, _ inStatus: UInt32, _ inData1: UInt32, _ inData2: UInt32, _ inOffsetSampleFrame: UInt32) -> OSStatus { MusicDeviceMIDIEvent(inUnit, inStatus, inData1, inData2, inOffsetSampleFrame) }
@_cdecl("MusicDeviceSysEx")
public func _c_MusicDeviceSysEx(_ inUnit: MusicDeviceComponent, _ inData: UnsafePointer<UInt8>, _ inLength: UInt32) -> OSStatus { MusicDeviceSysEx(inUnit, inData, inLength) }
@_cdecl("MusicDeviceMIDIEventList")
public func _c_MusicDeviceMIDIEventList(_ inUnit: MusicDeviceComponent, _ inOffsetSampleFrame: UInt32, _ evtList: UnsafePointer<MIDIEventList>) -> OSStatus { MusicDeviceMIDIEventList(inUnit, inOffsetSampleFrame, evtList) }
@_cdecl("MusicDeviceStartNote")
public func _c_MusicDeviceStartNote(_ inUnit: MusicDeviceComponent, _ inInstrument: MusicDeviceInstrumentID, _ inGroupID: MusicDeviceGroupID, _ outNoteInstanceID: UnsafeMutablePointer<NoteInstanceID>, _ inOffsetSampleFrame: UInt32, _ inParams: UnsafePointer<MusicDeviceNoteParams>) -> OSStatus { MusicDeviceStartNote(inUnit, inInstrument, inGroupID, outNoteInstanceID, inOffsetSampleFrame, inParams) }
@_cdecl("MusicDeviceStopNote")
public func _c_MusicDeviceStopNote(_ inUnit: MusicDeviceComponent, _ inGroupID: MusicDeviceGroupID, _ inNoteInstanceID: NoteInstanceID, _ inOffsetSampleFrame: UInt32) -> OSStatus { MusicDeviceStopNote(inUnit, inGroupID, inNoteInstanceID, inOffsetSampleFrame) }
@_cdecl("CopyNameFromSoundBank")
public func _c_CopyNameFromSoundBank(_ inURL: CFURL, _ outName: UnsafeMutablePointer<Unmanaged<CFString>?>) -> OSStatus { CopyNameFromSoundBank(inURL, outName) }
@_cdecl("CopyInstrumentInfoFromSoundBank")
public func _c_CopyInstrumentInfoFromSoundBank(_ inURL: CFURL, _ outInstrumentInfo: UnsafeMutablePointer<Unmanaged<CFArray>?>) -> OSStatus { CopyInstrumentInfoFromSoundBank(inURL, outInstrumentInfo) }
