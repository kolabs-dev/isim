// isim AudioToolbox for C and Objective-C (sdk-src/Frameworks/AudioToolbox): the C functions of Audio Unit, Audio
// Queue, Audio File, Extended Audio File, Audio Converter, AUGraph and System Sound Services, forwarding to the Swift
// functions of the same names. The handles (AudioUnit, AudioQueueRef, AudioFileID, ...) are the C types of
// <_AudioToolboxTypes/AudioToolboxTypes.h> in both languages, so an object made in C is the one Swift code sees.
// C's Boolean is UInt8 here; run loop arguments only choose the main queue, as in the Swift functions.
import Foundation
import Dispatch

private func _bool(_ p: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<DarwinBoolean> {
    UnsafeMutableRawPointer(p).assumingMemoryBound(to: DarwinBoolean.self)
}

@_cdecl("AudioFileOpenURL")
public func _c_AudioFileOpenURL(_ inFileRef: CFURL, _ inPermissions: Int8, _ inFileTypeHint: AudioFileTypeID, _ outAudioFile: UnsafeMutablePointer<AudioFileID?>) -> OSStatus { AudioFileOpenURL(inFileRef, AudioFilePermissions(rawValue: inPermissions), inFileTypeHint, outAudioFile) }
@_cdecl("AudioFileCreateWithURL")
public func _c_AudioFileCreateWithURL(_ inFileRef: CFURL, _ inFileType: AudioFileTypeID, _ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inFlags: UInt32, _ outAudioFile: UnsafeMutablePointer<AudioFileID?>) -> OSStatus { AudioFileCreateWithURL(inFileRef, inFileType, inFormat, AudioFileFlags(rawValue: inFlags), outAudioFile) }
@_cdecl("AudioFileClose")
public func _c_AudioFileClose(_ inAudioFile: AudioFileID) -> OSStatus { AudioFileClose(inAudioFile) }
@_cdecl("AudioFileOptimize")
public func _c_AudioFileOptimize(_ inAudioFile: AudioFileID) -> OSStatus { AudioFileOptimize(inAudioFile) }
@_cdecl("AudioFileGetPropertyInfo")
public func _c_AudioFileGetPropertyInfo(_ inAudioFile: AudioFileID, _ inPropertyID: AudioFilePropertyID, _ outDataSize: UnsafeMutablePointer<UInt32>?, _ isWritable: UnsafeMutablePointer<UInt32>?) -> OSStatus { AudioFileGetPropertyInfo(inAudioFile, inPropertyID, outDataSize, isWritable) }
@_cdecl("AudioFileGetProperty")
public func _c_AudioFileGetProperty(_ inAudioFile: AudioFileID, _ inPropertyID: AudioFilePropertyID, _ ioDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus { AudioFileGetProperty(inAudioFile, inPropertyID, ioDataSize, outPropertyData) }
@_cdecl("AudioFileSetProperty")
public func _c_AudioFileSetProperty(_ inAudioFile: AudioFileID, _ inPropertyID: AudioFilePropertyID, _ inDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus { AudioFileSetProperty(inAudioFile, inPropertyID, inDataSize, inPropertyData) }
@_cdecl("AudioFileReadBytes")
public func _c_AudioFileReadBytes(_ inAudioFile: AudioFileID, _ inUseCache: UInt8, _ inStartingByte: Int64, _ ioNumBytes: UnsafeMutablePointer<UInt32>, _ outBuffer: UnsafeMutableRawPointer) -> OSStatus { AudioFileReadBytes(inAudioFile, inUseCache != 0, inStartingByte, ioNumBytes, outBuffer) }
@_cdecl("AudioFileReadPacketData")
public func _c_AudioFileReadPacketData(_ inAudioFile: AudioFileID, _ inUseCache: UInt8, _ ioNumBytes: UnsafeMutablePointer<UInt32>, _ outPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ inStartingPacket: Int64, _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ outBuffer: UnsafeMutableRawPointer?) -> OSStatus { AudioFileReadPacketData(inAudioFile, inUseCache != 0, ioNumBytes, outPacketDescriptions, inStartingPacket, ioNumPackets, outBuffer) }
@_cdecl("AudioFileReadPackets")
public func _c_AudioFileReadPackets(_ inAudioFile: AudioFileID, _ inUseCache: UInt8, _ outNumBytes: UnsafeMutablePointer<UInt32>, _ outPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ inStartingPacket: Int64, _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ outBuffer: UnsafeMutableRawPointer?) -> OSStatus { AudioFileReadPackets(inAudioFile, inUseCache != 0, outNumBytes, outPacketDescriptions, inStartingPacket, ioNumPackets, outBuffer) }
@_cdecl("AudioFileWriteBytes")
public func _c_AudioFileWriteBytes(_ inAudioFile: AudioFileID, _ inUseCache: UInt8, _ inStartingByte: Int64, _ ioNumBytes: UnsafeMutablePointer<UInt32>, _ inBuffer: UnsafeRawPointer) -> OSStatus { AudioFileWriteBytes(inAudioFile, inUseCache != 0, inStartingByte, ioNumBytes, inBuffer) }
@_cdecl("AudioFileWritePackets")
public func _c_AudioFileWritePackets(_ inAudioFile: AudioFileID, _ inUseCache: UInt8, _ inNumBytes: UInt32, _ inPacketDescriptions: UnsafePointer<AudioStreamPacketDescription>?, _ inStartingPacket: Int64, _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ inBuffer: UnsafeRawPointer) -> OSStatus { AudioFileWritePackets(inAudioFile, inUseCache != 0, inNumBytes, inPacketDescriptions, inStartingPacket, ioNumPackets, inBuffer) }
@_cdecl("ExtAudioFileOpenURL")
public func _c_ExtAudioFileOpenURL(_ inURL: CFURL, _ outExtAudioFile: UnsafeMutablePointer<ExtAudioFileRef?>) -> OSStatus { ExtAudioFileOpenURL(inURL, outExtAudioFile) }
@_cdecl("ExtAudioFileCreateWithURL")
public func _c_ExtAudioFileCreateWithURL(_ inURL: CFURL, _ inFileType: AudioFileTypeID, _ inStreamDesc: UnsafePointer<AudioStreamBasicDescription>, _ inChannelLayout: UnsafeRawPointer?, _ inFlags: UInt32, _ outExtAudioFile: UnsafeMutablePointer<ExtAudioFileRef?>) -> OSStatus { ExtAudioFileCreateWithURL(inURL, inFileType, inStreamDesc, inChannelLayout, inFlags, outExtAudioFile) }
@_cdecl("ExtAudioFileDispose")
public func _c_ExtAudioFileDispose(_ inExtAudioFile: ExtAudioFileRef) -> OSStatus { ExtAudioFileDispose(inExtAudioFile) }
@_cdecl("ExtAudioFileGetPropertyInfo")
public func _c_ExtAudioFileGetPropertyInfo(_ inExtAudioFile: ExtAudioFileRef, _ inPropertyID: ExtAudioFilePropertyID, _ outSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<UInt8>?) -> OSStatus { ExtAudioFileGetPropertyInfo(inExtAudioFile, inPropertyID, outSize, outWritable.map(_bool)) }
@_cdecl("ExtAudioFileGetProperty")
public func _c_ExtAudioFileGetProperty(_ inExtAudioFile: ExtAudioFileRef, _ inPropertyID: ExtAudioFilePropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus { ExtAudioFileGetProperty(inExtAudioFile, inPropertyID, ioPropertyDataSize, outPropertyData) }
@_cdecl("ExtAudioFileSetProperty")
public func _c_ExtAudioFileSetProperty(_ inExtAudioFile: ExtAudioFileRef, _ inPropertyID: ExtAudioFilePropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus { ExtAudioFileSetProperty(inExtAudioFile, inPropertyID, inPropertyDataSize, inPropertyData) }
@_cdecl("ExtAudioFileRead")
public func _c_ExtAudioFileRead(_ inExtAudioFile: ExtAudioFileRef, _ ioNumberFrames: UnsafeMutablePointer<UInt32>, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus { ExtAudioFileRead(inExtAudioFile, ioNumberFrames, ioData) }
@_cdecl("ExtAudioFileWrite")
public func _c_ExtAudioFileWrite(_ inExtAudioFile: ExtAudioFileRef, _ inNumberFrames: UInt32, _ ioData: UnsafePointer<AudioBufferList>) -> OSStatus { ExtAudioFileWrite(inExtAudioFile, inNumberFrames, ioData) }
@_cdecl("ExtAudioFileWriteAsync")
public func _c_ExtAudioFileWriteAsync(_ inExtAudioFile: ExtAudioFileRef, _ inNumberFrames: UInt32, _ ioData: UnsafePointer<AudioBufferList>?) -> OSStatus { ExtAudioFileWriteAsync(inExtAudioFile, inNumberFrames, ioData) }
@_cdecl("ExtAudioFileSeek")
public func _c_ExtAudioFileSeek(_ inExtAudioFile: ExtAudioFileRef, _ inFrameOffset: Int64) -> OSStatus { ExtAudioFileSeek(inExtAudioFile, inFrameOffset) }
@_cdecl("ExtAudioFileTell")
public func _c_ExtAudioFileTell(_ inExtAudioFile: ExtAudioFileRef, _ outFrameOffset: UnsafeMutablePointer<Int64>) -> OSStatus { ExtAudioFileTell(inExtAudioFile, outFrameOffset) }
@_cdecl("AudioConverterNew")
public func _c_AudioConverterNew(_ inSourceFormat: UnsafePointer<AudioStreamBasicDescription>, _ inDestinationFormat: UnsafePointer<AudioStreamBasicDescription>, _ outAudioConverter: UnsafeMutablePointer<AudioConverterRef?>) -> OSStatus { AudioConverterNew(inSourceFormat, inDestinationFormat, outAudioConverter) }
@_cdecl("AudioConverterDispose")
public func _c_AudioConverterDispose(_ inAudioConverter: AudioConverterRef) -> OSStatus { AudioConverterDispose(inAudioConverter) }
@_cdecl("AudioConverterReset")
public func _c_AudioConverterReset(_ inAudioConverter: AudioConverterRef) -> OSStatus { AudioConverterReset(inAudioConverter) }
@_cdecl("AudioConverterGetPropertyInfo")
public func _c_AudioConverterGetPropertyInfo(_ inAudioConverter: AudioConverterRef, _ inPropertyID: AudioConverterPropertyID, _ outSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<UInt8>?) -> OSStatus { AudioConverterGetPropertyInfo(inAudioConverter, inPropertyID, outSize, outWritable.map(_bool)) }
@_cdecl("AudioConverterGetProperty")
public func _c_AudioConverterGetProperty(_ inAudioConverter: AudioConverterRef, _ inPropertyID: AudioConverterPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus { AudioConverterGetProperty(inAudioConverter, inPropertyID, ioPropertyDataSize, outPropertyData) }
@_cdecl("AudioConverterSetProperty")
public func _c_AudioConverterSetProperty(_ inAudioConverter: AudioConverterRef, _ inPropertyID: AudioConverterPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus { AudioConverterSetProperty(inAudioConverter, inPropertyID, inPropertyDataSize, inPropertyData) }
@_cdecl("AudioConverterConvertBuffer")
public func _c_AudioConverterConvertBuffer(_ inAudioConverter: AudioConverterRef, _ inInputDataSize: UInt32, _ inInputData: UnsafeRawPointer, _ ioOutputDataSize: UnsafeMutablePointer<UInt32>, _ outOutputData: UnsafeMutableRawPointer) -> OSStatus { AudioConverterConvertBuffer(inAudioConverter, inInputDataSize, inInputData, ioOutputDataSize, outOutputData) }
@_cdecl("AudioConverterConvertComplexBuffer")
public func _c_AudioConverterConvertComplexBuffer(_ inAudioConverter: AudioConverterRef, _ inNumberPCMFrames: UInt32, _ inInputData: UnsafePointer<AudioBufferList>, _ outOutputData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus { AudioConverterConvertComplexBuffer(inAudioConverter, inNumberPCMFrames, inInputData, outOutputData) }
@_cdecl("AudioConverterFillComplexBuffer")
public func _c_AudioConverterFillComplexBuffer(_ inAudioConverter: AudioConverterRef, _ inInputDataProc: AudioConverterComplexInputDataProc, _ inInputDataProcUserData: UnsafeMutableRawPointer?, _ ioOutputDataPacketSize: UnsafeMutablePointer<UInt32>, _ outOutputData: UnsafeMutablePointer<AudioBufferList>, _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?) -> OSStatus { AudioConverterFillComplexBuffer(inAudioConverter, inInputDataProc, inInputDataProcUserData, ioOutputDataPacketSize, outOutputData, outPacketDescription) }
@_cdecl("AudioQueueNewOutput")
public func _c_AudioQueueNewOutput(_ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inCallbackProc: AudioQueueOutputCallback, _ inUserData: UnsafeMutableRawPointer?, _ inCallbackRunLoop: UnsafeRawPointer?, _ inCallbackRunLoopMode: CFString?, _ inFlags: UInt32, _ outAQ: UnsafeMutablePointer<AudioQueueRef?>) -> OSStatus { AudioQueueNewOutput(inFormat, inCallbackProc, inUserData, inCallbackRunLoop.map { _ in NSNull() }, inCallbackRunLoopMode, inFlags, outAQ) }
@_cdecl("AudioQueueNewInput")
public func _c_AudioQueueNewInput(_ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inCallbackProc: AudioQueueInputCallback, _ inUserData: UnsafeMutableRawPointer?, _ inCallbackRunLoop: UnsafeRawPointer?, _ inCallbackRunLoopMode: CFString?, _ inFlags: UInt32, _ outAQ: UnsafeMutablePointer<AudioQueueRef?>) -> OSStatus { AudioQueueNewInput(inFormat, inCallbackProc, inUserData, inCallbackRunLoop.map { _ in NSNull() }, inCallbackRunLoopMode, inFlags, outAQ) }
@_cdecl("AudioQueueAllocateBuffer")
public func _c_AudioQueueAllocateBuffer(_ inAQ: AudioQueueRef, _ inBufferByteSize: UInt32, _ outBuffer: UnsafeMutablePointer<AudioQueueBufferRef?>) -> OSStatus { AudioQueueAllocateBuffer(inAQ, inBufferByteSize, outBuffer) }
@_cdecl("AudioQueueAllocateBufferWithPacketDescriptions")
public func _c_AudioQueueAllocateBufferWithPacketDescriptions(_ inAQ: AudioQueueRef, _ inBufferByteSize: UInt32, _ inNumberPacketDescriptions: UInt32, _ outBuffer: UnsafeMutablePointer<AudioQueueBufferRef?>) -> OSStatus { AudioQueueAllocateBufferWithPacketDescriptions(inAQ, inBufferByteSize, inNumberPacketDescriptions, outBuffer) }
@_cdecl("AudioQueueFreeBuffer")
public func _c_AudioQueueFreeBuffer(_ inAQ: AudioQueueRef, _ inBuffer: AudioQueueBufferRef) -> OSStatus { AudioQueueFreeBuffer(inAQ, inBuffer) }
@_cdecl("AudioQueueEnqueueBuffer")
public func _c_AudioQueueEnqueueBuffer(_ inAQ: AudioQueueRef, _ inBuffer: AudioQueueBufferRef, _ inNumPacketDescs: UInt32, _ inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?) -> OSStatus { AudioQueueEnqueueBuffer(inAQ, inBuffer, inNumPacketDescs, inPacketDescs) }
@_cdecl("AudioQueuePrime")
public func _c_AudioQueuePrime(_ inAQ: AudioQueueRef, _ inNumberOfFramesToPrepare: UInt32, _ outNumberOfFramesPrepared: UnsafeMutablePointer<UInt32>?) -> OSStatus { AudioQueuePrime(inAQ, inNumberOfFramesToPrepare, outNumberOfFramesPrepared) }
@_cdecl("AudioQueueStart")
public func _c_AudioQueueStart(_ inAQ: AudioQueueRef, _ inStartTime: UnsafePointer<AudioTimeStamp>?) -> OSStatus { AudioQueueStart(inAQ, inStartTime) }
@_cdecl("AudioQueuePause")
public func _c_AudioQueuePause(_ inAQ: AudioQueueRef) -> OSStatus { AudioQueuePause(inAQ) }
@_cdecl("AudioQueueStop")
public func _c_AudioQueueStop(_ inAQ: AudioQueueRef, _ inImmediate: UInt8) -> OSStatus { AudioQueueStop(inAQ, inImmediate != 0) }
@_cdecl("AudioQueueFlush")
public func _c_AudioQueueFlush(_ inAQ: AudioQueueRef) -> OSStatus { AudioQueueFlush(inAQ) }
@_cdecl("AudioQueueReset")
public func _c_AudioQueueReset(_ inAQ: AudioQueueRef) -> OSStatus { AudioQueueReset(inAQ) }
@_cdecl("AudioQueueDispose")
public func _c_AudioQueueDispose(_ inAQ: AudioQueueRef, _ inImmediate: UInt8) -> OSStatus { AudioQueueDispose(inAQ, inImmediate != 0) }
@_cdecl("AudioQueueSetParameter")
public func _c_AudioQueueSetParameter(_ inAQ: AudioQueueRef, _ inParamID: AudioQueueParameterID, _ inValue: AudioQueueParameterValue) -> OSStatus { AudioQueueSetParameter(inAQ, inParamID, inValue) }
@_cdecl("AudioQueueGetParameter")
public func _c_AudioQueueGetParameter(_ inAQ: AudioQueueRef, _ inParamID: AudioQueueParameterID, _ outValue: UnsafeMutablePointer<AudioQueueParameterValue>) -> OSStatus { AudioQueueGetParameter(inAQ, inParamID, outValue) }
@_cdecl("AudioQueueGetProperty")
public func _c_AudioQueueGetProperty(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ outData: UnsafeMutableRawPointer, _ ioDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioQueueGetProperty(inAQ, inID, outData, ioDataSize) }
@_cdecl("AudioQueueGetPropertySize")
public func _c_AudioQueueGetPropertySize(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ outDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioQueueGetPropertySize(inAQ, inID, outDataSize) }
@_cdecl("AudioQueueSetProperty")
public func _c_AudioQueueSetProperty(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ inData: UnsafeRawPointer, _ inDataSize: UInt32) -> OSStatus { AudioQueueSetProperty(inAQ, inID, inData, inDataSize) }
@_cdecl("AudioQueueAddPropertyListener")
public func _c_AudioQueueAddPropertyListener(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ inProc: AudioQueuePropertyListenerProc, _ inUserData: UnsafeMutableRawPointer?) -> OSStatus { AudioQueueAddPropertyListener(inAQ, inID, inProc, inUserData) }
@_cdecl("AudioQueueRemovePropertyListener")
public func _c_AudioQueueRemovePropertyListener(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ inProc: AudioQueuePropertyListenerProc, _ inUserData: UnsafeMutableRawPointer?) -> OSStatus { AudioQueueRemovePropertyListener(inAQ, inID, inProc, inUserData) }
@_cdecl("AudioQueueGetCurrentTime")
public func _c_AudioQueueGetCurrentTime(_ inAQ: AudioQueueRef, _ inTimeline: OpaquePointer?, _ outTimeStamp: UnsafeMutablePointer<AudioTimeStamp>?, _ outTimelineDiscontinuity: UnsafeMutablePointer<UInt8>?) -> OSStatus { AudioQueueGetCurrentTime(inAQ, inTimeline, outTimeStamp, outTimelineDiscontinuity.map(_bool)) }
@_cdecl("AudioQueueProcessingTapNew")
public func _c_AudioQueueProcessingTapNew(_ inAQ: AudioQueueRef, _ inCallback: AudioQueueProcessingTapCallback, _ inClientData: UnsafeMutableRawPointer?, _ inFlags: AudioQueueProcessingTapFlags, _ outMaxFrames: UnsafeMutablePointer<UInt32>, _ outProcessingFormat: UnsafeMutablePointer<AudioStreamBasicDescription>, _ outAQTap: UnsafeMutablePointer<AudioQueueProcessingTapRef?>) -> OSStatus { AudioQueueProcessingTapNew(inAQ, inCallback, inClientData, inFlags, outMaxFrames, outProcessingFormat, outAQTap) }
@_cdecl("AudioQueueProcessingTapDispose")
public func _c_AudioQueueProcessingTapDispose(_ inAQTap: AudioQueueProcessingTapRef) -> OSStatus { AudioQueueProcessingTapDispose(inAQTap) }
@_cdecl("AudioQueueProcessingTapGetSourceAudio")
public func _c_AudioQueueProcessingTapGetSourceAudio(_ inAQTap: AudioQueueProcessingTapRef, _ inNumberFrames: UInt32, _ ioTimeStamp: UnsafeMutablePointer<AudioTimeStamp>, _ outFlags: UnsafeMutablePointer<AudioQueueProcessingTapFlags>, _ outNumberFrames: UnsafeMutablePointer<UInt32>, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus { AudioQueueProcessingTapGetSourceAudio(inAQTap, inNumberFrames, ioTimeStamp, outFlags, outNumberFrames, ioData) }
@_cdecl("AudioQueueProcessingTapGetQueueTime")
public func _c_AudioQueueProcessingTapGetQueueTime(_ inAQTap: AudioQueueProcessingTapRef, _ outQueueSampleTime: UnsafeMutablePointer<Float64>, _ outQueueFrameCount: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioQueueProcessingTapGetQueueTime(inAQTap, outQueueSampleTime, outQueueFrameCount) }
@_cdecl("AudioServicesCreateSystemSoundID")
public func _c_AudioServicesCreateSystemSoundID(_ inFileURL: CFURL, _ outSystemSoundID: UnsafeMutablePointer<SystemSoundID>) -> OSStatus { AudioServicesCreateSystemSoundID(inFileURL, outSystemSoundID) }
@_cdecl("AudioServicesDisposeSystemSoundID")
public func _c_AudioServicesDisposeSystemSoundID(_ inSystemSoundID: SystemSoundID) -> OSStatus { AudioServicesDisposeSystemSoundID(inSystemSoundID) }
@_cdecl("AudioServicesPlaySystemSound")
public func _c_AudioServicesPlaySystemSound(_ inSystemSoundID: SystemSoundID) { AudioServicesPlaySystemSound(inSystemSoundID) }
@_cdecl("AudioServicesPlayAlertSound")
public func _c_AudioServicesPlayAlertSound(_ inSystemSoundID: SystemSoundID) { AudioServicesPlayAlertSound(inSystemSoundID) }
@_cdecl("AudioServicesAddSystemSoundCompletion")
public func _c_AudioServicesAddSystemSoundCompletion(_ inSystemSoundID: SystemSoundID, _ inRunLoop: UnsafeRawPointer?, _ inRunLoopMode: UnsafeRawPointer?, _ inCompletionRoutine: AudioServicesSystemSoundCompletionProc, _ inClientData: UnsafeMutableRawPointer?) -> OSStatus { AudioServicesAddSystemSoundCompletion(inSystemSoundID, inRunLoop.map { _ in NSNull() }, inRunLoopMode.map { _ in NSNull() }, inCompletionRoutine, inClientData) }
@_cdecl("AudioServicesRemoveSystemSoundCompletion")
public func _c_AudioServicesRemoveSystemSoundCompletion(_ inSystemSoundID: SystemSoundID) { AudioServicesRemoveSystemSoundCompletion(inSystemSoundID) }
@_cdecl("AudioComponentFindNext")
public func _c_AudioComponentFindNext(_ inComponent: AudioComponent?, _ inDesc: UnsafePointer<AudioComponentDescription>) -> AudioComponent? { AudioComponentFindNext(inComponent, inDesc) }
@_cdecl("AudioComponentCount")
public func _c_AudioComponentCount(_ inDesc: UnsafePointer<AudioComponentDescription>) -> UInt32 { AudioComponentCount(inDesc) }
@_cdecl("AudioComponentGetDescription")
public func _c_AudioComponentGetDescription(_ inComponent: AudioComponent, _ outDesc: UnsafeMutablePointer<AudioComponentDescription>) -> OSStatus { AudioComponentGetDescription(inComponent, outDesc) }
@_cdecl("AudioComponentCopyName")
public func _c_AudioComponentCopyName(_ inComponent: AudioComponent, _ outName: UnsafeMutablePointer<Unmanaged<CFString>?>) -> OSStatus { AudioComponentCopyName(inComponent, outName) }
@_cdecl("AudioComponentGetVersion")
public func _c_AudioComponentGetVersion(_ inComponent: AudioComponent, _ outVersion: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioComponentGetVersion(inComponent, outVersion) }
@_cdecl("AudioComponentInstanceNew")
public func _c_AudioComponentInstanceNew(_ inComponent: AudioComponent, _ outInstance: UnsafeMutablePointer<AudioComponentInstance?>) -> OSStatus { AudioComponentInstanceNew(inComponent, outInstance) }
@_cdecl("AudioComponentInstanceDispose")
public func _c_AudioComponentInstanceDispose(_ inInstance: AudioComponentInstance) -> OSStatus { AudioComponentInstanceDispose(inInstance) }
@_cdecl("AudioComponentInstanceGetComponent")
public func _c_AudioComponentInstanceGetComponent(_ inInstance: AudioComponentInstance) -> AudioComponent { AudioComponentInstanceGetComponent(inInstance) }
@_cdecl("AudioUnitInitialize")
public func _c_AudioUnitInitialize(_ inUnit: AudioUnit) -> OSStatus { AudioUnitInitialize(inUnit) }
@_cdecl("AudioUnitUninitialize")
public func _c_AudioUnitUninitialize(_ inUnit: AudioUnit) -> OSStatus { AudioUnitUninitialize(inUnit) }
@_cdecl("AudioUnitReset")
public func _c_AudioUnitReset(_ inUnit: AudioUnit, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement) -> OSStatus { AudioUnitReset(inUnit, inScope, inElement) }
@_cdecl("AudioOutputUnitStart")
public func _c_AudioOutputUnitStart(_ ci: AudioUnit) -> OSStatus { AudioOutputUnitStart(ci) }
@_cdecl("AudioOutputUnitStop")
public func _c_AudioOutputUnitStop(_ ci: AudioUnit) -> OSStatus { AudioOutputUnitStop(ci) }
@_cdecl("AudioUnitRender")
public func _c_AudioUnitRender(_ inUnit: AudioUnit, _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ inTimeStamp: UnsafePointer<AudioTimeStamp>, _ inOutputBusNumber: UInt32, _ inNumberFrames: UInt32, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus { AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData) }
@_cdecl("AudioUnitProcess")
public func _c_AudioUnitProcess(_ inUnit: AudioUnit, _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ inTimeStamp: UnsafePointer<AudioTimeStamp>, _ inNumberFrames: UInt32, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus { AudioUnitProcess(inUnit, ioActionFlags, inTimeStamp, inNumberFrames, ioData) }
@_cdecl("AudioUnitAddRenderNotify")
public func _c_AudioUnitAddRenderNotify(_ inUnit: AudioUnit, _ inProc: AURenderCallback, _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus { AudioUnitAddRenderNotify(inUnit, inProc, inProcUserData) }
@_cdecl("AudioUnitRemoveRenderNotify")
public func _c_AudioUnitRemoveRenderNotify(_ inUnit: AudioUnit, _ inProc: AURenderCallback, _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus { AudioUnitRemoveRenderNotify(inUnit, inProc, inProcUserData) }
@_cdecl("AudioUnitGetParameter")
public func _c_AudioUnitGetParameter(_ inUnit: AudioUnit, _ inID: AudioUnitParameterID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement, _ outValue: UnsafeMutablePointer<AudioUnitParameterValue>) -> OSStatus { AudioUnitGetParameter(inUnit, inID, inScope, inElement, outValue) }
@_cdecl("AudioUnitSetParameter")
public func _c_AudioUnitSetParameter(_ inUnit: AudioUnit, _ inID: AudioUnitParameterID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement, _ inValue: AudioUnitParameterValue, _ inBufferOffsetInFrames: UInt32) -> OSStatus { AudioUnitSetParameter(inUnit, inID, inScope, inElement, inValue, inBufferOffsetInFrames) }
@_cdecl("AudioUnitGetPropertyInfo")
public func _c_AudioUnitGetPropertyInfo(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement, _ outDataSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<UInt8>?) -> OSStatus { AudioUnitGetPropertyInfo(inUnit, inID, inScope, inElement, outDataSize, outWritable.map(_bool)) }
@_cdecl("AudioUnitGetProperty")
public func _c_AudioUnitGetProperty(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement, _ outData: UnsafeMutableRawPointer, _ ioDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioUnitGetProperty(inUnit, inID, inScope, inElement, outData, ioDataSize) }
@_cdecl("AudioUnitSetProperty")
public func _c_AudioUnitSetProperty(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement, _ inData: UnsafeRawPointer?, _ inDataSize: UInt32) -> OSStatus { AudioUnitSetProperty(inUnit, inID, inScope, inElement, inData, inDataSize) }
@_cdecl("AudioUnitAddPropertyListener")
public func _c_AudioUnitAddPropertyListener(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inProc: AudioUnitPropertyListenerProc, _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus { AudioUnitAddPropertyListener(inUnit, inID, inProc, inProcUserData) }
@_cdecl("AudioUnitRemovePropertyListenerWithUserData")
public func _c_AudioUnitRemovePropertyListenerWithUserData(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inProc: AudioUnitPropertyListenerProc, _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus { AudioUnitRemovePropertyListenerWithUserData(inUnit, inID, inProc, inProcUserData) }
@_cdecl("NewAUGraph")
public func _c_NewAUGraph(_ outGraph: UnsafeMutablePointer<AUGraph?>) -> OSStatus { NewAUGraph(outGraph) }
@_cdecl("DisposeAUGraph")
public func _c_DisposeAUGraph(_ inGraph: AUGraph) -> OSStatus { DisposeAUGraph(inGraph) }
@_cdecl("AUGraphAddNode")
public func _c_AUGraphAddNode(_ inGraph: AUGraph, _ inDescription: UnsafePointer<AudioComponentDescription>, _ outNode: UnsafeMutablePointer<AUNode>) -> OSStatus { AUGraphAddNode(inGraph, inDescription, outNode) }
@_cdecl("AUGraphRemoveNode")
public func _c_AUGraphRemoveNode(_ inGraph: AUGraph, _ inNode: AUNode) -> OSStatus { AUGraphRemoveNode(inGraph, inNode) }
@_cdecl("AUGraphGetNodeCount")
public func _c_AUGraphGetNodeCount(_ inGraph: AUGraph, _ outNumberOfNodes: UnsafeMutablePointer<UInt32>) -> OSStatus { AUGraphGetNodeCount(inGraph, outNumberOfNodes) }
@_cdecl("AUGraphGetIndNode")
public func _c_AUGraphGetIndNode(_ inGraph: AUGraph, _ inIndex: UInt32, _ outNode: UnsafeMutablePointer<AUNode>) -> OSStatus { AUGraphGetIndNode(inGraph, inIndex, outNode) }
@_cdecl("AUGraphNodeInfo")
public func _c_AUGraphNodeInfo(_ inGraph: AUGraph, _ inNode: AUNode, _ outDescription: UnsafeMutablePointer<AudioComponentDescription>?, _ outAudioUnit: UnsafeMutablePointer<AudioUnit?>?) -> OSStatus { AUGraphNodeInfo(inGraph, inNode, outDescription, outAudioUnit) }
@_cdecl("AUGraphConnectNodeInput")
public func _c_AUGraphConnectNodeInput(_ inGraph: AUGraph, _ inSourceNode: AUNode, _ inSourceOutputNumber: UInt32, _ inDestNode: AUNode, _ inDestInputNumber: UInt32) -> OSStatus { AUGraphConnectNodeInput(inGraph, inSourceNode, inSourceOutputNumber, inDestNode, inDestInputNumber) }
@_cdecl("AUGraphDisconnectNodeInput")
public func _c_AUGraphDisconnectNodeInput(_ inGraph: AUGraph, _ inDestNode: AUNode, _ inDestInputNumber: UInt32) -> OSStatus { AUGraphDisconnectNodeInput(inGraph, inDestNode, inDestInputNumber) }
@_cdecl("AUGraphSetNodeInputCallback")
public func _c_AUGraphSetNodeInputCallback(_ inGraph: AUGraph, _ inDestNode: AUNode, _ inDestInputNumber: UInt32, _ inInputCallback: UnsafePointer<AURenderCallbackStruct>) -> OSStatus { AUGraphSetNodeInputCallback(inGraph, inDestNode, inDestInputNumber, inInputCallback) }
@_cdecl("AUGraphClearConnections")
public func _c_AUGraphClearConnections(_ inGraph: AUGraph) -> OSStatus { AUGraphClearConnections(inGraph) }
@_cdecl("AUGraphUpdate")
public func _c_AUGraphUpdate(_ inGraph: AUGraph, _ outIsUpdated: UnsafeMutablePointer<UInt8>?) -> OSStatus { AUGraphUpdate(inGraph, outIsUpdated.map(_bool)) }
@_cdecl("AUGraphOpen")
public func _c_AUGraphOpen(_ inGraph: AUGraph) -> OSStatus { AUGraphOpen(inGraph) }
@_cdecl("AUGraphClose")
public func _c_AUGraphClose(_ inGraph: AUGraph) -> OSStatus { AUGraphClose(inGraph) }
@_cdecl("AUGraphInitialize")
public func _c_AUGraphInitialize(_ inGraph: AUGraph) -> OSStatus { AUGraphInitialize(inGraph) }
@_cdecl("AUGraphUninitialize")
public func _c_AUGraphUninitialize(_ inGraph: AUGraph) -> OSStatus { AUGraphUninitialize(inGraph) }
@_cdecl("AUGraphStart")
public func _c_AUGraphStart(_ inGraph: AUGraph) -> OSStatus { AUGraphStart(inGraph) }
@_cdecl("AUGraphStop")
public func _c_AUGraphStop(_ inGraph: AUGraph) -> OSStatus { AUGraphStop(inGraph) }
@_cdecl("AUGraphIsOpen")
public func _c_AUGraphIsOpen(_ inGraph: AUGraph, _ outIsOpen: UnsafeMutablePointer<UInt8>) -> OSStatus { AUGraphIsOpen(inGraph, _bool(outIsOpen)) }
@_cdecl("AUGraphIsInitialized")
public func _c_AUGraphIsInitialized(_ inGraph: AUGraph, _ outIsInitialized: UnsafeMutablePointer<UInt8>) -> OSStatus { AUGraphIsInitialized(inGraph, _bool(outIsInitialized)) }
@_cdecl("AUGraphIsRunning")
public func _c_AUGraphIsRunning(_ inGraph: AUGraph, _ outIsRunning: UnsafeMutablePointer<UInt8>) -> OSStatus { AUGraphIsRunning(inGraph, _bool(outIsRunning)) }
@_cdecl("AUGraphGetCPULoad")
public func _c_AUGraphGetCPULoad(_ inGraph: AUGraph, _ outAverageCPULoad: UnsafeMutablePointer<Float32>) -> OSStatus { AUGraphGetCPULoad(inGraph, outAverageCPULoad) }
@_cdecl("AUGraphGetMaxCPULoad")
public func _c_AUGraphGetMaxCPULoad(_ inGraph: AUGraph, _ outMaxLoad: UnsafeMutablePointer<Float32>) -> OSStatus { AUGraphGetMaxCPULoad(inGraph, outMaxLoad) }
@_cdecl("AUGraphAddRenderNotify")
public func _c_AUGraphAddRenderNotify(_ inGraph: AUGraph, _ inCallback: AURenderCallback, _ inRefCon: UnsafeMutableRawPointer?) -> OSStatus { AUGraphAddRenderNotify(inGraph, inCallback, inRefCon) }
@_cdecl("AUGraphRemoveRenderNotify")
public func _c_AUGraphRemoveRenderNotify(_ inGraph: AUGraph, _ inCallback: AURenderCallback, _ inRefCon: UnsafeMutableRawPointer?) -> OSStatus { AUGraphRemoveRenderNotify(inGraph, inCallback, inRefCon) }

// MARK: - blocks and dispatch queues

/// The C caller's dispatch queue, retained for the audio queue's lifetime; callbacks are sent to it.
private final class _CQueue: @unchecked Sendable {
    let queue: dispatch_queue_t
    init(_ q: dispatch_queue_t) { queue = q; dispatch_retain(UnsafeMutableRawPointer(q)) }
    deinit { dispatch_release(UnsafeMutableRawPointer(queue)) }
    func async(_ work: @escaping @convention(block) () -> Void) { dispatch_async(queue, work) }
}
@_cdecl("AudioQueueNewOutputWithDispatchQueue")
public func _c_AudioQueueNewOutputWithDispatchQueue(_ outAQ: UnsafeMutablePointer<AudioQueueRef?>, _ inFormat: UnsafePointer<AudioStreamBasicDescription>,
                                                    _ inFlags: UInt32, _ inCallbackDispatchQueue: dispatch_queue_t,
                                                    _ inCallbackBlock: @escaping @convention(block) (AudioQueueRef, AudioQueueBufferRef) -> Void) -> OSStatus {
    let q = _CQueue(inCallbackDispatchQueue)
    let status = AudioQueueNewOutput(inFormat, { _, _, _ in }, nil, nil, nil, inFlags, outAQ)
    if status == noErr_, let aq = outAQ.pointee { _object(aq, _AudioQueue.self)?.out = { a, b in q.async { inCallbackBlock(a, b) } } }
    return status
}
@_cdecl("AudioQueueNewInputWithDispatchQueue")
public func _c_AudioQueueNewInputWithDispatchQueue(_ outAQ: UnsafeMutablePointer<AudioQueueRef?>, _ inFormat: UnsafePointer<AudioStreamBasicDescription>,
                                                   _ inFlags: UInt32, _ inCallbackDispatchQueue: dispatch_queue_t,
                                                   _ inCallbackBlock: @escaping @convention(block) (AudioQueueRef, AudioQueueBufferRef, UnsafePointer<AudioTimeStamp>, UInt32,
                                                                                                    UnsafePointer<AudioStreamPacketDescription>?) -> Void) -> OSStatus {
    let q = _CQueue(inCallbackDispatchQueue)
    let status = AudioQueueNewInput(inFormat, { _, _, _, _, _, _ in }, nil, nil, nil, inFlags, outAQ)
    if status == noErr_, let aq = outAQ.pointee {
        _object(aq, _AudioQueue.self)?.inp = { a, b, t, n, d in       // the time stamp and descriptions only live for the call
            let ts = t.pointee
            let descs = d.map { Array(UnsafeBufferPointer(start: $0, count: Int(n))) }
            q.async {
                var ts = ts
                if let descs { descs.withUnsafeBufferPointer { inCallbackBlock(a, b, &ts, n, $0.baseAddress) } } else { inCallbackBlock(a, b, &ts, n, nil) }
            }
        }
    }
    return status
}
@_cdecl("AudioServicesPlaySystemSoundWithCompletion")
public func _c_AudioServicesPlaySystemSoundWithCompletion(_ inSystemSoundID: SystemSoundID, _ inCompletionBlock: (@convention(block) () -> Void)?) {
    let block = inCompletionBlock.map { b in _SendableBlock(b) }
    AudioServicesPlaySystemSoundWithCompletion(inSystemSoundID, block.map { b in { @Sendable in b.call() } })
}
@_cdecl("AudioServicesPlayAlertSoundWithCompletion")
public func _c_AudioServicesPlayAlertSoundWithCompletion(_ inSystemSoundID: SystemSoundID, _ inCompletionBlock: (@convention(block) () -> Void)?) {
    let block = inCompletionBlock.map { b in _SendableBlock(b) }
    AudioServicesPlayAlertSoundWithCompletion(inSystemSoundID, block.map { b in { @Sendable in b.call() } })
}
private final class _SendableBlock: @unchecked Sendable {
    let block: () -> Void
    init(_ b: @escaping () -> Void) { block = b }
    func call() { block() }
}
@_cdecl("AudioComponentInstantiate")
public func _c_AudioComponentInstantiate(_ inComponent: AudioComponent, _ inOptions: UInt32,
                                         _ inCompletionHandler: @escaping @convention(block) (AudioComponentInstance?, OSStatus) -> Void) {
    AudioComponentInstantiate(inComponent, AudioComponentInstantiationOptions(rawValue: inOptions), inCompletionHandler)
}
