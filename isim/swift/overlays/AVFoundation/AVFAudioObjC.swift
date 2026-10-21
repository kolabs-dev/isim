// isim AVFAudio for Objective-C (sdk-src/Frameworks/AVFAudio, issue #553). The engine, node, format, buffer, converter,
// file, player and recorder classes are @objc(AVAudio…) and @objcMembers, with Apple's selectors where Swift's differ;
// the members below are internal Objective-C entry points, under Apple's selectors, for what uses Swift-only types: the
// enums and option sets (their raw values in Objective-C) and the AVAudio3D… structs, which AVFoundation.framework's
// categories (frameworks/AVFoundation/AVFoundation.m) pass through the `_isim_` NSArray entry points here.
import Foundation
import AudioToolbox

extension AVAudioFormat {
    @objc(initWithCommonFormat:sampleRate:channels:interleaved:)
    convenience init?(_objcCommonFormat f: UInt, sampleRate: Double, channels: AVAudioChannelCount, interleaved: Bool) {
        guard let c = AVAudioCommonFormat(rawValue: f) else { return nil }
        self.init(commonFormat: c, sampleRate: sampleRate, channels: channels, interleaved: interleaved)
    }
    @objc(initWithCommonFormat:sampleRate:interleaved:channelLayout:)
    convenience init(_objcCommonFormat f: UInt, sampleRate: Double, interleaved: Bool, channelLayout layout: AVAudioChannelLayout) {
        self.init(commonFormat: AVAudioCommonFormat(rawValue: f) ?? .otherFormat, sampleRate: sampleRate, interleaved: interleaved, channelLayout: layout)
    }
    @objc(commonFormat) var _objcCommonFormat: UInt { commonFormat.rawValue }
}

extension AVAudioFile {
    @objc(initForReading:commonFormat:interleaved:error:) convenience init(_objcForReading url: URL, commonFormat f: UInt, interleaved: Bool) throws {
        try self.init(forReading: url, commonFormat: AVAudioCommonFormat(rawValue: f) ?? .pcmFormatFloat32, interleaved: interleaved)
    }
    @objc(initForWriting:settings:commonFormat:interleaved:error:)
    convenience init(_objcForWriting url: URL, settings: [String: Any], commonFormat f: UInt, interleaved: Bool) throws {
        try self.init(forWriting: url, settings: settings, commonFormat: AVAudioCommonFormat(rawValue: f) ?? .pcmFormatFloat32, interleaved: interleaved)
    }
}

extension AVAudioConverter {
    @objc(primeMethod) var _objcPrimeMethod: Int {
        get { primeMethod.rawValue }
        set { primeMethod = AVAudioConverterPrimeMethod(rawValue: newValue) ?? .normal }
    }
    /// leading, trailing frames (AVAudioConverterPrimeInfo)
    @objc(_isim_primeInfo) var _isimPrimeInfo: [NSNumber] {
        get { [NSNumber(value: primeInfo.leadingFrames), NSNumber(value: primeInfo.trailingFrames)] }
        set { primeInfo = AVAudioConverterPrimeInfo(leadingFrames: newValue[0].uint32Value, trailingFrames: newValue[1].uint32Value) }
    }
    /// the block reports AVAudioConverterInputStatus and the method returns AVAudioConverterOutputStatus, as raw values
    @objc(convertToBuffer:error:withInputFromBlock:)
    func _objcConvert(to outputBuffer: AVAudioBuffer, error outError: NSErrorPointer,
                      withInputFrom block: @escaping (AVAudioPacketCount, UnsafeMutablePointer<Int>) -> AVAudioBuffer?) -> Int {
        convert(to: outputBuffer, error: outError) { n, status in
            var s = 0
            let b = block(n, &s)
            status.pointee = AVAudioConverterInputStatus(rawValue: s) ?? .endOfStream
            return b
        }.rawValue
    }
}

extension AVAudioUnit {
    @objc(instantiateWithComponentDescription:options:completionHandler:)
    class func _objcInstantiate(_ d: AudioComponentDescription, options: UInt32, completionHandler: @escaping (AVAudioUnit?, Error?) -> Void) {
        instantiate(with: d, options: AudioComponentInstantiationOptions(rawValue: options), completionHandler: completionHandler)
    }
}

extension AVAudioPlayerNode {
    @objc(scheduleBuffer:atTime:options:completionHandler:)
    func _objcScheduleBuffer(_ b: AVAudioPCMBuffer, at when: AVAudioTime?, options: UInt, completionHandler: (() -> Void)?) {
        scheduleBuffer(b, at: when, options: AVAudioPlayerNodeBufferOptions(rawValue: options), completionHandler: completionHandler)
    }
    @objc(scheduleBuffer:completionCallbackType:completionHandler:)
    func _objcScheduleBuffer(_ b: AVAudioPCMBuffer, completionCallbackType t: Int, completionHandler: ((Int) -> Void)?) {
        scheduleBuffer(b, at: nil, options: [], completionCallbackType: _callbackType(t), completionHandler: completionHandler.map { f in { f($0.rawValue) } })
    }
    @objc(scheduleBuffer:atTime:options:completionCallbackType:completionHandler:)
    func _objcScheduleBuffer(_ b: AVAudioPCMBuffer, at when: AVAudioTime?, options: UInt, completionCallbackType t: Int, completionHandler: ((Int) -> Void)?) {
        scheduleBuffer(b, at: when, options: AVAudioPlayerNodeBufferOptions(rawValue: options), completionCallbackType: _callbackType(t),
                       completionHandler: completionHandler.map { f in { f($0.rawValue) } })
    }
    @objc(scheduleFile:atTime:completionCallbackType:completionHandler:)
    func _objcScheduleFile(_ file: AVAudioFile, at when: AVAudioTime?, completionCallbackType t: Int, completionHandler: ((Int) -> Void)?) {
        scheduleFile(file, at: when, completionCallbackType: _callbackType(t), completionHandler: completionHandler.map { f in { f($0.rawValue) } })
    }
    @objc(scheduleSegment:startingFrame:frameCount:atTime:completionCallbackType:completionHandler:)
    func _objcScheduleSegment(_ file: AVAudioFile, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount, at when: AVAudioTime?,
                              completionCallbackType t: Int, completionHandler: ((Int) -> Void)?) {
        scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: when, completionCallbackType: _callbackType(t),
                        completionHandler: completionHandler.map { f in { f($0.rawValue) } })
    }
    private func _callbackType(_ t: Int) -> AVAudioPlayerNodeCompletionCallbackType { AVAudioPlayerNodeCompletionCallbackType(rawValue: t) ?? .dataConsumed }
}

extension AVAudioEngine {
    @objc(enableManualRenderingMode:format:maximumFrameCount:error:)
    func _objcEnableManualRenderingMode(_ mode: Int, format: AVAudioFormat, maximumFrameCount: AVAudioFrameCount) throws {
        try enableManualRenderingMode(AVAudioEngineManualRenderingMode(rawValue: mode) ?? .offline, format: format, maximumFrameCount: maximumFrameCount)
    }
    @objc(manualRenderingMode) var _objcManualRenderingMode: Int { manualRenderingMode.rawValue }
    /// returns AVAudioEngineManualRenderingStatus's raw value (error, with the error set, when it throws)
    @objc(renderOffline:toBuffer:error:) func _objcRenderOffline(_ n: AVAudioFrameCount, to buffer: AVAudioPCMBuffer, error: NSErrorPointer) -> Int {
        do { return try renderOffline(n, to: buffer).rawValue } catch let e as AVAudioEngineManualRenderingError {
            error?.pointee = NSError(domain: NSOSStatusErrorDomain, code: e.rawValue)
        } catch let e { error?.pointee = e as NSError }
        return AVAudioEngineManualRenderingStatus.error.rawValue
    }
    @objc(manualRenderingBlock)
    var _objcManualRenderingBlock: @convention(block) (AVAudioFrameCount, UnsafeMutablePointer<AudioBufferList>, UnsafeMutablePointer<OSStatus>?) -> Int {
        let b = manualRenderingBlock
        return { b($0, $1, $2).rawValue }
    }
}

extension AVAudioEnvironmentNode {
    @objc(outputType) var _objcOutputType: Int {
        get { outputType.rawValue }
        set { outputType = AVAudioEnvironmentOutputType(rawValue: newValue) ?? .auto }
    }
    /// x, y, z
    @objc(_isim_listenerPosition) var _isimListenerPosition: [NSNumber] {
        get { _isimPoint(listenerPosition) }
        set { listenerPosition = _isimPoint(newValue) }
    }
    /// yaw, pitch, roll
    @objc(_isim_listenerAngularOrientation) var _isimListenerAngularOrientation: [NSNumber] {
        get { let o = listenerAngularOrientation; return [NSNumber(value: o.yaw), NSNumber(value: o.pitch), NSNumber(value: o.roll)] }
        set { listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: newValue[0].floatValue, pitch: newValue[1].floatValue, roll: newValue[2].floatValue) }
    }
    /// forward x, y, z, up x, y, z
    @objc(_isim_listenerVectorOrientation) var _isimListenerVectorOrientation: [NSNumber] {
        get { let o = listenerVectorOrientation; return _isimPoint(o.forward) + _isimPoint(o.up) }
        set { listenerVectorOrientation = AVAudio3DVectorOrientation(forward: _isimPoint(newValue), up: _isimPoint(Array(newValue.dropFirst(3)))) }
    }
}
extension AVAudioEnvironmentDistanceAttenuationParameters {
    @objc(distanceAttenuationModel) var _objcDistanceAttenuationModel: Int {
        get { distanceAttenuationModel.rawValue }
        set { distanceAttenuationModel = AVAudioEnvironmentDistanceAttenuationModel(rawValue: newValue) ?? .inverse }
    }
}
extension AVAudioEnvironmentReverbParameters {
    @objc(loadFactoryReverbPreset:) func _objcLoadFactoryReverbPreset(_ p: Int) { AVAudioUnitReverbPreset(rawValue: p).map(loadFactoryReverbPreset) }
}
extension AVAudioUnitReverb {
    @objc(loadFactoryPreset:) func _objcLoadFactoryPreset(_ p: Int) { AVAudioUnitReverbPreset(rawValue: p).map(loadFactoryPreset) }
}
extension AVAudioUnitDistortion {
    @objc(loadFactoryPreset:) func _objcLoadFactoryPreset(_ p: Int) { AVAudioUnitDistortionPreset(rawValue: p).map(loadFactoryPreset) }
}
extension AVAudioUnitEQFilterParameters {
    @objc(filterType) var _objcFilterType: Int {
        get { filterType.rawValue }
        set { filterType = AVAudioUnitEQFilterType(rawValue: newValue) ?? .parametric }
    }
}

func _isimPoint(_ p: AVAudio3DPoint) -> [NSNumber] { [NSNumber(value: p.x), NSNumber(value: p.y), NSNumber(value: p.z)] }
func _isimPoint(_ a: [NSNumber]) -> AVAudio3DPoint { AVAudio3DPoint(x: a[0].floatValue, y: a[1].floatValue, z: a[2].floatValue) }

// AVAudio3DMixing's enums (as raw values) and position (x, y, z), on each class that adopts AVAudioMixing
extension AVAudioMixingDestination {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
extension AVAudioMixerNode {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
extension AVAudioPlayerNode {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
extension AVAudioSourceNode {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
extension AVAudioInputNode {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
extension AVAudioEnvironmentNode {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
extension AVAudioUnitGenerator {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
