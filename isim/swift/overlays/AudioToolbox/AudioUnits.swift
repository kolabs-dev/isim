// isim AudioToolbox: Audio Unit Services (AudioComponent*, AudioUnit*, AudioOutputUnitStart/Stop) and the
// Audio Processing Graph (AUGraph*). Self-authored, iOS API names, constants and C layouts (the structs are in
// usr/include/_AudioToolboxTypes); C-style functions over opaque handles, like the real framework.
// Adapted: isim's own units over the streaming kernels of AudioDSP.swift, not Apple's DSP:
// - I/O: RemoteIO and VoiceProcessingIO play bus 0 through the host mixer (48 kHz; other client rates are resampled)
//   on isim's render thread, paced in real time (silently when headless); bus 1 is the simulated microphone
//   (ISIM_AUDIO_INPUT) when input is enabled. GenericOutput is pulled by the app with AudioUnitRender (offline).
//   No voice processing (echo cancellation): VoiceProcessingIO is RemoteIO.
// - MultiChannelMixer (per-bus volume, pan, enable; output volume; metering), AUConverter (rate, channels, sample
//   format), Varispeed, NewTimePitch, Delay, Reverb2, NBandEQ, LowPass/HighPass/BandPass/LowShelf/HighShelf/
//   ParametricEQ filters, Distortion and PeakLimiter.
// No third-party (v3 extension) units, music devices (Sampler) or generators (AudioFilePlayer).
import Foundation
import isim_host

public typealias AudioUnitPropertyID = UInt32
public typealias AudioUnitScope = UInt32
public typealias AudioUnitElement = UInt32
public typealias AudioUnitParameterID = UInt32
public typealias AudioUnitParameterValue = Float32
public typealias AUParameterEventType = UInt32

public struct AudioComponentInstantiationOptions: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let loadOutOfProcess = AudioComponentInstantiationOptions(rawValue: 1)
    public static let loadInProcess = AudioComponentInstantiationOptions(rawValue: 2)
    public static let loadedRemotely = AudioComponentInstantiationOptions(rawValue: 1 << 31)
}

// component types and subtypes (four-char codes)
public let kAudioUnitManufacturer_Apple: UInt32 = 0x6170_706C          // 'appl'
public let kAudioUnitType_Output: UInt32 = 0x6175_6F75                 // 'auou'
public let kAudioUnitType_MusicDevice: UInt32 = 0x6175_6D75            // 'aumu'
public let kAudioUnitType_MusicEffect: UInt32 = 0x6175_6D66            // 'aumf'
public let kAudioUnitType_FormatConverter: UInt32 = 0x6175_6663        // 'aufc'
public let kAudioUnitType_Effect: UInt32 = 0x6175_6678                 // 'aufx'
public let kAudioUnitType_Mixer: UInt32 = 0x6175_6D78                  // 'aumx'
public let kAudioUnitType_Panner: UInt32 = 0x6175_706E                 // 'aupn'
public let kAudioUnitType_Generator: UInt32 = 0x6175_676E              // 'augn'
public let kAudioUnitType_OfflineEffect: UInt32 = 0x6175_6F6C          // 'auol'
public let kAudioUnitSubType_RemoteIO: UInt32 = 0x7269_6F63            // 'rioc'
public let kAudioUnitSubType_VoiceProcessingIO: UInt32 = 0x7670_696F   // 'vpio'
public let kAudioUnitSubType_GenericOutput: UInt32 = 0x6765_6E72       // 'genr'
public let kAudioUnitSubType_MultiChannelMixer: UInt32 = 0x6D63_6D78   // 'mcmx'
public let kAudioUnitSubType_AUConverter: UInt32 = 0x636F_6E76         // 'conv'
public let kAudioUnitSubType_Varispeed: UInt32 = 0x7661_7269           // 'vari'
public let kAudioUnitSubType_NewTimePitch: UInt32 = 0x6E75_7470        // 'nutp'
public let kAudioUnitSubType_Delay: UInt32 = 0x6465_6C79               // 'dely'
public let kAudioUnitSubType_Reverb2: UInt32 = 0x7276_6232             // 'rvb2'
public let kAudioUnitSubType_NBandEQ: UInt32 = 0x6E62_6571             // 'nbeq'
public let kAudioUnitSubType_LowPassFilter: UInt32 = 0x6C70_6173       // 'lpas'
public let kAudioUnitSubType_HighPassFilter: UInt32 = 0x6870_6173      // 'hpas'
public let kAudioUnitSubType_BandPassFilter: UInt32 = 0x6270_6173      // 'bpas'
public let kAudioUnitSubType_LowShelfFilter: UInt32 = 0x6C73_6866      // 'lshf'
public let kAudioUnitSubType_HighShelfFilter: UInt32 = 0x6873_6866     // 'hshf'
public let kAudioUnitSubType_ParametricEQ: UInt32 = 0x706D_6571        // 'pmeq'
public let kAudioUnitSubType_Distortion: UInt32 = 0x6469_7374          // 'dist'
public let kAudioUnitSubType_PeakLimiter: UInt32 = 0x6C6D_7472         // 'lmtr'

// scopes
public let kAudioUnitScope_Global: AudioUnitScope = 0
public let kAudioUnitScope_Input: AudioUnitScope = 1
public let kAudioUnitScope_Output: AudioUnitScope = 2
public let kAudioUnitScope_Group: AudioUnitScope = 3
public let kAudioUnitScope_Part: AudioUnitScope = 4

// properties
public let kAudioUnitProperty_ClassInfo: AudioUnitPropertyID = 0
public let kAudioUnitProperty_MakeConnection: AudioUnitPropertyID = 1
public let kAudioUnitProperty_SampleRate: AudioUnitPropertyID = 2
public let kAudioUnitProperty_ParameterList: AudioUnitPropertyID = 3
public let kAudioUnitProperty_ParameterInfo: AudioUnitPropertyID = 4
public let kAudioUnitProperty_StreamFormat: AudioUnitPropertyID = 8
public let kAudioUnitProperty_ElementCount: AudioUnitPropertyID = 11
public let kAudioUnitProperty_Latency: AudioUnitPropertyID = 12
public let kAudioUnitProperty_MaximumFramesPerSlice: AudioUnitPropertyID = 14
public let kAudioUnitProperty_TailTime: AudioUnitPropertyID = 20
public let kAudioUnitProperty_BypassEffect: AudioUnitPropertyID = 21
public let kAudioUnitProperty_LastRenderError: AudioUnitPropertyID = 22
public let kAudioUnitProperty_SetRenderCallback: AudioUnitPropertyID = 23
public let kAudioUnitProperty_ShouldAllocateBuffer: AudioUnitPropertyID = 51
public let kAudioUnitProperty_MeteringMode: AudioUnitPropertyID = 3007
public let kAudioOutputUnitProperty_CurrentDevice: AudioUnitPropertyID = 2000
public let kAudioOutputUnitProperty_IsRunning: AudioUnitPropertyID = 2001
public let kAudioOutputUnitProperty_EnableIO: AudioUnitPropertyID = 2003
public let kAudioOutputUnitProperty_SetInputCallback: AudioUnitPropertyID = 2005
public let kAUVoiceIOProperty_BypassVoiceProcessing: AudioUnitPropertyID = 2100
public let kAUVoiceIOProperty_VoiceProcessingEnableAGC: AudioUnitPropertyID = 2101
public let kAUVoiceIOProperty_MuteOutput: AudioUnitPropertyID = 2104
public let kAUNBandEQProperty_NumberOfBands: AudioUnitPropertyID = 2200
public let kAUNBandEQProperty_MaxNumberOfBands: AudioUnitPropertyID = 2201

// parameters
public let kMultiChannelMixerParam_Volume: AudioUnitParameterID = 0
public let kMultiChannelMixerParam_Enable: AudioUnitParameterID = 1
public let kMultiChannelMixerParam_Pan: AudioUnitParameterID = 2
public let kMultiChannelMixerParam_PreAveragePower: AudioUnitParameterID = 1000
public let kMultiChannelMixerParam_PrePeakHoldLevel: AudioUnitParameterID = 2000
public let kMultiChannelMixerParam_PostAveragePower: AudioUnitParameterID = 3000
public let kMultiChannelMixerParam_PostPeakHoldLevel: AudioUnitParameterID = 4000
public let kVarispeedParam_PlaybackRate: AudioUnitParameterID = 0
public let kVarispeedParam_PlaybackCents: AudioUnitParameterID = 1
public let kNewTimePitchParam_Rate: AudioUnitParameterID = 0
public let kNewTimePitchParam_Pitch: AudioUnitParameterID = 1
public let kNewTimePitchParam_Overlap: AudioUnitParameterID = 4
public let kNewTimePitchParam_EnablePeakLocking: AudioUnitParameterID = 6
public let kDelayParam_WetDryMix: AudioUnitParameterID = 0
public let kDelayParam_DelayTime: AudioUnitParameterID = 1
public let kDelayParam_Feedback: AudioUnitParameterID = 2
public let kDelayParam_LopassCutoff: AudioUnitParameterID = 3
public let kReverb2Param_DryWetMix: AudioUnitParameterID = 0
public let kReverb2Param_Gain: AudioUnitParameterID = 1
public let kReverb2Param_MinDelayTime: AudioUnitParameterID = 2
public let kReverb2Param_MaxDelayTime: AudioUnitParameterID = 3
public let kReverb2Param_DecayTimeAt0Hz: AudioUnitParameterID = 4
public let kReverb2Param_DecayTimeAtNyquist: AudioUnitParameterID = 5
public let kReverb2Param_RandomizeReflections: AudioUnitParameterID = 6
public let kAUNBandEQParam_GlobalGain: AudioUnitParameterID = 0
public let kAUNBandEQParam_BypassBand: AudioUnitParameterID = 1000
public let kAUNBandEQParam_FilterType: AudioUnitParameterID = 2000
public let kAUNBandEQParam_Frequency: AudioUnitParameterID = 3000
public let kAUNBandEQParam_Gain: AudioUnitParameterID = 4000
public let kAUNBandEQParam_Bandwidth: AudioUnitParameterID = 5000
public let kLowPassParam_CutoffFrequency: AudioUnitParameterID = 0
public let kLowPassParam_Resonance: AudioUnitParameterID = 1
public let kHipassParam_CutoffFrequency: AudioUnitParameterID = 0
public let kHipassParam_Resonance: AudioUnitParameterID = 1
public let kBandpassParam_CenterFrequency: AudioUnitParameterID = 0
public let kBandpassParam_Bandwidth: AudioUnitParameterID = 1
public let kHighShelfParam_CutOffFrequency: AudioUnitParameterID = 0
public let kHighShelfParam_Gain: AudioUnitParameterID = 1
public let kAULowShelfParam_CutoffFrequency: AudioUnitParameterID = 0
public let kAULowShelfParam_Gain: AudioUnitParameterID = 1
public let kParametricEQParam_CenterFreq: AudioUnitParameterID = 0
public let kParametricEQParam_Q: AudioUnitParameterID = 1
public let kParametricEQParam_Gain: AudioUnitParameterID = 2
public let kDistortionParam_SoftClipGain: AudioUnitParameterID = 14
public let kDistortionParam_FinalMix: AudioUnitParameterID = 15
public let kLimiterParam_AttackTime: AudioUnitParameterID = 0
public let kLimiterParam_DecayTime: AudioUnitParameterID = 1
public let kLimiterParam_PreGain: AudioUnitParameterID = 2

// errors
public let kAudioUnitErr_InvalidProperty: OSStatus = -10879
public let kAudioUnitErr_InvalidParameter: OSStatus = -10878
public let kAudioUnitErr_InvalidElement: OSStatus = -10877
public let kAudioUnitErr_NoConnection: OSStatus = -10876
public let kAudioUnitErr_FailedInitialization: OSStatus = -10875
public let kAudioUnitErr_TooManyFramesToProcess: OSStatus = -10874
public let kAudioUnitErr_InvalidFile: OSStatus = -10871
public let kAudioUnitErr_FormatNotSupported: OSStatus = -10868
public let kAudioUnitErr_Uninitialized: OSStatus = -10867
public let kAudioUnitErr_InvalidScope: OSStatus = -10866
public let kAudioUnitErr_PropertyNotWritable: OSStatus = -10865
public let kAudioUnitErr_CannotDoInCurrentContext: OSStatus = -10863
public let kAudioUnitErr_InvalidPropertyValue: OSStatus = -10851
public let kAudioUnitErr_PropertyNotInUse: OSStatus = -10850
public let kAudioUnitErr_Initialized: OSStatus = -10849
public let kAudioUnitErr_InvalidOfflineRender: OSStatus = -10848
public let kAudioUnitErr_Unauthorized: OSStatus = -10847
public let kAudioComponentErr_InstanceInvalidated: OSStatus = -66749
public let kAUGraphErr_NodeNotFound: OSStatus = -10860
public let kAUGraphErr_InvalidConnection: OSStatus = -10861
public let kAUGraphErr_OutputNodeErr: OSStatus = -10862
public let kAUGraphErr_CannotDoInCurrentContext: OSStatus = -10863
public let kAUGraphErr_InvalidAudioUnit: OSStatus = -10864

// MARK: - components

final class _AUComponent {
    let desc: AudioComponentDescription
    let name: String
    init(_ type: UInt32, _ sub: UInt32, _ name: String) {
        desc = AudioComponentDescription(componentType: type, componentSubType: sub, componentManufacturer: kAudioUnitManufacturer_Apple,
                                         componentFlags: 0, componentFlagsMask: 0)
        self.name = "Apple: " + name
    }
    lazy var handle: AudioComponent = AudioComponent(Unmanaged.passRetained(self).toOpaque())
    nonisolated(unsafe) static let all: [_AUComponent] = [
        _AUComponent(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, "AURemoteIO"),
        _AUComponent(kAudioUnitType_Output, kAudioUnitSubType_VoiceProcessingIO, "AUVoiceProcessor"),
        _AUComponent(kAudioUnitType_Output, kAudioUnitSubType_GenericOutput, "AUGenericOutput"),
        _AUComponent(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, "AUMultiChannelMixer"),
        _AUComponent(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, "AUConverter"),
        _AUComponent(kAudioUnitType_FormatConverter, kAudioUnitSubType_Varispeed, "AUVarispeed"),
        _AUComponent(kAudioUnitType_FormatConverter, kAudioUnitSubType_NewTimePitch, "AUNewTimePitch"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_Delay, "AUDelay"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_Reverb2, "AUReverb2"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_NBandEQ, "AUNBandEQ"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_LowPassFilter, "AULowpass"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_HighPassFilter, "AUHipass"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_BandPassFilter, "AUBandpass"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_LowShelfFilter, "AULowShelfFilter"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_HighShelfFilter, "AUHighShelfFilter"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_ParametricEQ, "AUParametricEQ"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_Distortion, "AUDistortion"),
        _AUComponent(kAudioUnitType_Effect, kAudioUnitSubType_PeakLimiter, "AUPeakLimiter"),
    ]
    func matches(_ d: AudioComponentDescription) -> Bool {
        (d.componentType == 0 || d.componentType == desc.componentType) && (d.componentSubType == 0 || d.componentSubType == desc.componentSubType)
            && (d.componentManufacturer == 0 || d.componentManufacturer == desc.componentManufacturer)
    }
}

public func AudioComponentFindNext(_ inComponent: AudioComponent?, _ inDesc: UnsafePointer<AudioComponentDescription>) -> AudioComponent? {
    var start = 0
    if let c = inComponent, let i = _AUComponent.all.firstIndex(where: { $0.handle == c }) { start = i + 1 }
    guard start < _AUComponent.all.count else { return nil }
    return _AUComponent.all[start...].first { $0.matches(inDesc.pointee) }?.handle
}
public func AudioComponentCount(_ inDesc: UnsafePointer<AudioComponentDescription>) -> UInt32 {
    UInt32(_AUComponent.all.filter { $0.matches(inDesc.pointee) }.count)
}
func _component(_ c: AudioComponent) -> _AUComponent? { _AUComponent.all.first { $0.handle == c } }
public func AudioComponentGetDescription(_ inComponent: AudioComponent, _ outDesc: UnsafeMutablePointer<AudioComponentDescription>) -> OSStatus {
    guard let c = _component(inComponent) else { return kAudio_ParamError }
    outDesc.pointee = c.desc
    return noErr_
}
public func AudioComponentCopyName(_ inComponent: AudioComponent, _ outName: UnsafeMutablePointer<Unmanaged<CFString>?>) -> OSStatus {
    guard let c = _component(inComponent) else { return kAudio_ParamError }
    outName.pointee = Unmanaged.passRetained(c.name as CFString)
    return noErr_
}
public func AudioComponentGetVersion(_ inComponent: AudioComponent, _ outVersion: UnsafeMutablePointer<UInt32>) -> OSStatus {
    outVersion.pointee = 0x0001_0000
    return noErr_
}
public func AudioComponentInstanceNew(_ inComponent: AudioComponent, _ outInstance: UnsafeMutablePointer<AudioComponentInstance?>) -> OSStatus {
    guard let c = _component(inComponent) else { return kAudio_ParamError }
    outInstance.pointee = _IsimAudioUnit(c).handle
    return noErr_
}
public func AudioComponentInstantiate(_ inComponent: AudioComponent, _ inOptions: AudioComponentInstantiationOptions,
                                      _ inCompletionHandler: @escaping (AudioComponentInstance?, OSStatus) -> Void) {
    var u: AudioComponentInstance? = nil
    let st = AudioComponentInstanceNew(inComponent, &u)
    DispatchQueue.main.async { inCompletionHandler(u, st) }
}
public func AudioComponentInstanceDispose(_ inInstance: AudioComponentInstance) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inInstance) else { return kAudio_ParamError }
    u.dispose()
    return noErr_
}
public func AudioComponentInstanceGetComponent(_ inInstance: AudioComponentInstance) -> AudioComponent {
    _IsimAudioUnit.from(inInstance)!.component.handle
}

// MARK: - units

/// isim: one Audio Unit instance (also what AVAudioUnit nodes of AVAudioEngine are made of). Not iOS API.
public final class _IsimAudioUnit: @unchecked Sendable {
    let component: _AUComponent
    public var type: UInt32 { component.desc.componentType }
    public var subType: UInt32 { component.desc.componentSubType }
    public private(set) var handle: AudioUnit!
    /// the render lock shared by all units: topology changes wait for the render in progress
    static let renderLock = NSRecursiveLock()
    let paramLock = NSLock()
    var params: [UInt64: Float] = [:]
    var initialized = false
    var inFormats: [UInt32: AudioStreamBasicDescription] = [:], outFormats: [UInt32: AudioStreamBasicDescription] = [:]
    var callbacks: [UInt32: AURenderCallbackStruct] = [:]
    var connections: [UInt32: (unit: _IsimAudioUnit, bus: UInt32)] = [:]
    var inputBusCount: UInt32, outputBusCount: UInt32
    var maxFrames: UInt32 = 4096
    public var bypass = false
    var lastError: OSStatus = 0
    var notifies: [(AURenderCallback, UnsafeMutableRawPointer?)] = []
    var listeners: [(AudioUnitPropertyListenerProc, UnsafeMutableRawPointer?, AudioUnitPropertyID)] = []
    var metering = false
    var eqBands: UInt32 = 2
    // I/O units
    var inputEnabled = false, outputEnabled = true
    var inputCallback: AURenderCallbackStruct?
    var driver: _IsimAudioOutput?
    var fifo: _IsimInputFIFO?
    let micResampler = _IsimResampler(), outResampler = _IsimResampler(), convResampler = _IsimResampler()
    var sampleTime: Double = 0
    var micTime: Double = 0
    public let kernel: _IsimDSPKernel?
    var scratch: [UnsafeMutableRawPointer] = []

    init(_ c: _AUComponent) {
        component = c
        let io = c.desc.componentType == kAudioUnitType_Output && c.desc.componentSubType != kAudioUnitSubType_GenericOutput
        inputBusCount = c.desc.componentSubType == kAudioUnitSubType_MultiChannelMixer ? 8 : io ? 2 : 1
        outputBusCount = io ? 2 : 1
        switch c.desc.componentSubType {
        case kAudioUnitSubType_Reverb2: kernel = _IsimReverbKernel()
        case kAudioUnitSubType_NBandEQ, kAudioUnitSubType_LowPassFilter, kAudioUnitSubType_HighPassFilter, kAudioUnitSubType_BandPassFilter,
             kAudioUnitSubType_LowShelfFilter, kAudioUnitSubType_HighShelfFilter, kAudioUnitSubType_ParametricEQ: kernel = _IsimEQKernel(bands: 1)
        case kAudioUnitSubType_Delay: kernel = _IsimDelayKernel()
        case kAudioUnitSubType_Distortion: kernel = _IsimDistortionKernel()
        case kAudioUnitSubType_Varispeed: kernel = _IsimVarispeedKernel()
        case kAudioUnitSubType_NewTimePitch: kernel = _IsimTimePitchKernel()
        case kAudioUnitSubType_PeakLimiter: kernel = _IsimLimiterKernel()
        default: kernel = nil
        }
        handle = AudioUnit(Unmanaged.passRetained(self).toOpaque())
        let canonical = _pcmFormat(rate: io ? 48000 : 44100, channels: 2, bits: 32, float: true, nonInterleaved: true)
        for b in 0..<inputBusCount { inFormats[b] = canonical }
        for b in 0..<outputBusCount { outFormats[b] = canonical }
        if io { outFormats[1] = _pcmFormat(rate: 48000, channels: 1, bits: 32, float: true, nonInterleaved: true); inFormats[1] = outFormats[1] }
        defaults()
    }
    /// A unit of an Apple component (AVAudioEngine's effect nodes).
    public static func make(type: UInt32, subType: UInt32) -> _IsimAudioUnit? {
        _AUComponent.all.first { $0.desc.componentType == type && $0.desc.componentSubType == subType }.map { _IsimAudioUnit($0) }
    }
    static func from(_ u: AudioUnit?) -> _IsimAudioUnit? {
        guard let u else { return nil }
        return Unmanaged<_IsimAudioUnit>.fromOpaque(UnsafeRawPointer(u)).takeUnretainedValue()
    }
    func dispose() {
        stopIO()
        for p in scratch { free(p) }
        scratch = []
        Unmanaged.passUnretained(self).release()
    }
    var isIO: Bool { type == kAudioUnitType_Output && subType != kAudioUnitSubType_GenericOutput }

    // parameters
    static func key(_ id: AudioUnitParameterID, _ scope: AudioUnitScope, _ element: AudioUnitElement) -> UInt64 {
        UInt64(id) | UInt64(scope & 0xFF) << 32 | UInt64(element & 0xFF_FFFF) << 40
    }
    public func parameter(_ id: AudioUnitParameterID, scope: AudioUnitScope = 0, element: AudioUnitElement = 0) -> Float {
        paramLock.lock(); defer { paramLock.unlock() }
        return params[Self.key(id, scope, element)] ?? defaultValue(id, scope)
    }
    public func setParameter(_ id: AudioUnitParameterID, _ v: Float, scope: AudioUnitScope = 0, element: AudioUnitElement = 0) {
        paramLock.lock(); params[Self.key(id, scope, element)] = v; paramLock.unlock()
    }
    func defaultValue(_ id: AudioUnitParameterID, _ scope: AudioUnitScope) -> Float {
        switch (subType, id) {
        case (kAudioUnitSubType_MultiChannelMixer, kMultiChannelMixerParam_Volume), (kAudioUnitSubType_MultiChannelMixer, kMultiChannelMixerParam_Enable): return 1
        case (kAudioUnitSubType_MultiChannelMixer, _): return id >= 1000 ? -120 : 0
        case (kAudioUnitSubType_Varispeed, kVarispeedParam_PlaybackRate), (kAudioUnitSubType_NewTimePitch, kNewTimePitchParam_Rate): return 1
        case (kAudioUnitSubType_NewTimePitch, kNewTimePitchParam_Overlap): return 8
        case (kAudioUnitSubType_NewTimePitch, kNewTimePitchParam_EnablePeakLocking): return 1
        case (kAudioUnitSubType_Delay, kDelayParam_WetDryMix), (kAudioUnitSubType_Delay, kDelayParam_Feedback): return 50
        case (kAudioUnitSubType_Delay, kDelayParam_DelayTime): return 1
        case (kAudioUnitSubType_Delay, kDelayParam_LopassCutoff): return 15000
        case (kAudioUnitSubType_Reverb2, kReverb2Param_DryWetMix): return 100
        case (kAudioUnitSubType_Reverb2, kReverb2Param_MinDelayTime): return 0.008
        case (kAudioUnitSubType_Reverb2, kReverb2Param_MaxDelayTime): return 0.050
        case (kAudioUnitSubType_Reverb2, kReverb2Param_DecayTimeAt0Hz): return 1
        case (kAudioUnitSubType_Reverb2, kReverb2Param_DecayTimeAtNyquist): return 0.5
        case (kAudioUnitSubType_Reverb2, kReverb2Param_RandomizeReflections): return 1
        case (kAudioUnitSubType_NBandEQ, _):
            switch id / 1000 { case 1: return 1; case 3: return 1000; case 5: return 0.5; default: return 0 }
        case (kAudioUnitSubType_LowPassFilter, 0), (kAudioUnitSubType_HighPassFilter, 0): return 6900
        case (kAudioUnitSubType_BandPassFilter, 0): return 5000
        case (kAudioUnitSubType_BandPassFilter, 1): return 600
        case (kAudioUnitSubType_HighShelfFilter, 0): return 10000
        case (kAudioUnitSubType_LowShelfFilter, 0): return 80
        case (kAudioUnitSubType_ParametricEQ, 0): return 2000
        case (kAudioUnitSubType_ParametricEQ, 1): return 1
        case (kAudioUnitSubType_Distortion, kDistortionParam_SoftClipGain): return -6
        case (kAudioUnitSubType_Distortion, kDistortionParam_FinalMix): return 50
        case (kAudioUnitSubType_Distortion, _Distortion_Drive): return 8
        case (kAudioUnitSubType_PeakLimiter, kLimiterParam_AttackTime): return 0.012
        case (kAudioUnitSubType_PeakLimiter, kLimiterParam_DecayTime): return 0.024
        default: return 0
        }
    }
    func defaults() {}
    /// copies the parameters into the kernel (every render slice, so changes apply while playing)
    public func applyParameters() {
        guard let k = kernel else { return }
        func p(_ id: AudioUnitParameterID) -> Float { parameter(id) }
        (k as? _IsimInPlaceKernel)?.bypass = bypass
        switch subType {
        case kAudioUnitSubType_Reverb2:
            let r = k as! _IsimReverbKernel
            r.wetDryMix = p(kReverb2Param_DryWetMix); r.gain = p(kReverb2Param_Gain)
            let d0 = max(0.001, Double(p(kReverb2Param_DecayTimeAt0Hz))), dn = Double(p(kReverb2Param_DecayTimeAtNyquist))
            r.room = Float(min(0.97, max(0.5, 0.70 + 0.26 * log(d0 / 0.3) / log(8 / 0.3))))
            r.damp = Float(min(0.8, max(0.05, 0.5 * (1 - dn / d0) + 0.05)))
        case kAudioUnitSubType_NBandEQ:
            let e = k as! _IsimEQKernel
            e.globalGain = p(kAUNBandEQParam_GlobalGain)
            e.bands = (0..<Int(eqBands)).map { i in
                var b = _IsimEQBand()
                let u = UInt32(i)
                b.bypass = p(kAUNBandEQParam_BypassBand + u) != 0; b.type = Int(p(kAUNBandEQParam_FilterType + u))
                b.frequency = p(kAUNBandEQParam_Frequency + u); b.gain = p(kAUNBandEQParam_Gain + u); b.bandwidth = p(kAUNBandEQParam_Bandwidth + u)
                return b
            }
        case kAudioUnitSubType_LowPassFilter, kAudioUnitSubType_HighPassFilter, kAudioUnitSubType_BandPassFilter, kAudioUnitSubType_LowShelfFilter,
             kAudioUnitSubType_HighShelfFilter, kAudioUnitSubType_ParametricEQ:
            var b = _IsimEQBand(); b.bypass = false
            switch subType {
            case kAudioUnitSubType_LowPassFilter: b.type = 1; b.frequency = p(0)
            case kAudioUnitSubType_HighPassFilter: b.type = 2; b.frequency = p(0)
            case kAudioUnitSubType_BandPassFilter: b.type = 5; b.frequency = p(0); b.bandwidth = p(1) / 1200
            case kAudioUnitSubType_LowShelfFilter: b.type = 7; b.frequency = p(0); b.gain = p(1)
            case kAudioUnitSubType_HighShelfFilter: b.type = 8; b.frequency = p(0); b.gain = p(1)
            default:
                b.type = 0; b.frequency = p(0); b.gain = p(2)
                let q = Double(max(0.1, p(1)))
                b.bandwidth = Float(2 / log(2.0) * asinh(1 / (2 * q)))
            }
            (k as! _IsimEQKernel).bands = [b]
        case kAudioUnitSubType_Delay:
            let d = k as! _IsimDelayKernel
            d.wetDryMix = p(kDelayParam_WetDryMix); d.delayTime = Double(p(kDelayParam_DelayTime)); d.feedback = p(kDelayParam_Feedback)
            d.lowPassCutoff = p(kDelayParam_LopassCutoff)
        case kAudioUnitSubType_Distortion:
            let d = k as! _IsimDistortionKernel
            d.preGain = p(kDistortionParam_SoftClipGain); d.wetDryMix = p(kDistortionParam_FinalMix); d.drive = p(_Distortion_Drive)
        case kAudioUnitSubType_Varispeed:
            let v = k as! _IsimVarispeedKernel
            v.bypass = bypass
            let cents = parameter(kVarispeedParam_PlaybackCents)
            v.rate = cents != 0 ? Float(pow(2, Double(cents) / 1200)) : p(kVarispeedParam_PlaybackRate)
        case kAudioUnitSubType_NewTimePitch:
            let t = k as! _IsimTimePitchKernel
            t.bypass = bypass; t.rate = p(kNewTimePitchParam_Rate); t.pitch = p(kNewTimePitchParam_Pitch); t.overlap = p(kNewTimePitchParam_Overlap)
        case kAudioUnitSubType_PeakLimiter:
            let l = k as! _IsimLimiterKernel
            l.attack = Double(p(kLimiterParam_AttackTime)); l.decay = Double(p(kLimiterParam_DecayTime)); l.preGain = p(kLimiterParam_PreGain)
        default: break
        }
    }

    // MARK: rendering

    func format(_ scope: AudioUnitScope, _ bus: UInt32) -> AudioStreamBasicDescription {
        (scope == kAudioUnitScope_Input ? inFormats[bus] : outFormats[bus]) ?? _pcmFormat(rate: 44100, channels: 2, bits: 32, float: true, nonInterleaved: true)
    }
    /// The input of a bus: the connected unit's output, or the render callback's data (`n` frames, input format).
    func pullInput(_ bus: UInt32, _ n: Int, _ ts: AudioTimeStamp) -> [[Float]]? {
        let f = format(kAudioUnitScope_Input, bus)
        if let c = connections[bus] {
            var t = ts
            return c.unit.renderOutput(c.bus, n, &t)
        }
        guard let cb = callbacks[bus], let proc = cb.inputProc else { return nil }
        let list = _allocBufferList(f, n)
        defer { _freeBufferList(list) }
        var flags = AudioUnitRenderActionFlags(rawValue: 0), t = ts
        let st = proc(cb.inputProcRefCon ?? UnsafeMutableRawPointer(bitPattern: 1)!, &flags, &t, bus, UInt32(n), list.unsafeMutablePointer)
        if st != noErr_ { lastError = st; return _IsimChannels.silence(Int(f.mChannelsPerFrame), n) }
        if flags.contains(.unitRenderAction_OutputIsSilence) { return _IsimChannels.silence(Int(f.mChannelsPerFrame), n) }
        return _PCM.read(list, f, frames: n)
    }
    /// `n` frames of an output bus, deinterleaved floats in the bus's output format
    func renderOutput(_ bus: UInt32, _ n: Int, _ tsIn: inout AudioTimeStamp) -> [[Float]] {
        let ts = tsIn
        let out = format(kAudioUnitScope_Output, bus)
        let ch = Int(out.mChannelsPerFrame)
        if isIO && bus == 1 {                               // the microphone
            guard inputEnabled, let fifo else { return _IsimChannels.silence(ch, n) }
            let x = micResampler.render(n, step: 48000 / max(1, out.mSampleRate)) { fifo.pop($0) }
            return _IsimChannels.adapt(x, to: ch, frames: n)
        }
        switch subType {
        case kAudioUnitSubType_MultiChannelMixer:
            var mix = _IsimChannels.silence(ch, n)
            for b in 0..<inputBusCount {
                guard parameter(kMultiChannelMixerParam_Enable, scope: kAudioUnitScope_Input, element: b) != 0,
                      connections[b] != nil || callbacks[b] != nil, let x = pullInput(b, n, ts) else { continue }
                let vol = parameter(kMultiChannelMixerParam_Volume, scope: kAudioUnitScope_Input, element: b)
                if metering { meter(x, id: kMultiChannelMixerParam_PreAveragePower, element: b, scope: kAudioUnitScope_Input) }
                _IsimChannels.mix(x, into: &mix, gain: vol, pan: parameter(kMultiChannelMixerParam_Pan, scope: kAudioUnitScope_Input, element: b))
            }
            let ov = parameter(kMultiChannelMixerParam_Volume, scope: kAudioUnitScope_Output)
            if ov != 1 { for c in 0..<mix.count { for i in 0..<n { mix[c][i] *= ov } } }
            if metering { meter(mix, id: kMultiChannelMixerParam_PostAveragePower, element: 0, scope: kAudioUnitScope_Output) }
            return mix
        case kAudioUnitSubType_AUConverter:
            let inf = format(kAudioUnitScope_Input, 0)
            let step = inf.mSampleRate / max(1, out.mSampleRate)
            let x = convResampler.render(n, step: step) { k in self.pullInput(0, k, ts) ?? _IsimChannels.silence(Int(inf.mChannelsPerFrame), k) }
            return _IsimChannels.adapt(x, to: ch, frames: n)
        default:
            let inf = format(kAudioUnitScope_Input, 0)
            let pull: (Int) -> [[Float]] = { k in self.pullInput(0, k, ts) ?? _IsimChannels.silence(Int(inf.mChannelsPerFrame), k) }
            guard let k = kernel else { return _IsimChannels.adapt(pull(n), to: ch, frames: n) }
            applyParameters()
            return _IsimChannels.adapt(k.render(n, rate: out.mSampleRate, pull: pull), to: ch, frames: n)
        }
    }
    func meter(_ x: [[Float]], id: AudioUnitParameterID, element: UInt32, scope: AudioUnitScope) {
        var s: Float = 0, pk: Float = 0, cnt = 0
        for c in x { for v in c { s += v * v; pk = max(pk, abs(v)) }; cnt += c.count }
        let rms = cnt > 0 ? (s / Float(cnt)).squareRoot() : 0
        func db(_ v: Float) -> Float { v > 1e-6 ? max(-120, 20 * Float(log10(Double(v)))) : -120 }
        setParameter(id, db(rms), scope: scope, element: element)
        setParameter(id + 1000, db(pk), scope: scope, element: element)
    }
    /// AudioUnitRender: renders `n` frames of `bus` into the app's buffer list (allocating buffers it left nil)
    func render(_ flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ ts: UnsafePointer<AudioTimeStamp>, _ bus: UInt32, _ n: UInt32,
                _ io: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        guard bus < outputBusCount else { return kAudioUnitErr_InvalidElement }
        guard n <= max(maxFrames, 4096) else { return kAudioUnitErr_TooManyFramesToProcess }
        Self.renderLock.lock(); defer { Self.renderLock.unlock() }
        var t = ts.pointee
        let f = format(kAudioUnitScope_Output, bus)
        let list = UnsafeMutableAudioBufferListPointer(io)
        for i in 0..<list.count where list[i].mData == nil {
            let bytes = Int(n) * (f._isNonInterleaved ? f._bytesPerSample : f._frameBytes)
            let p = malloc(max(1, bytes))!
            scratch.append(p)
            if scratch.count > 64 { free(scratch.removeFirst()) }
            list[i].mData = p; list[i].mDataByteSize = UInt32(bytes)
        }
        var pre = AudioUnitRenderActionFlags.unitRenderAction_PreRender
        for (proc, ud) in notifies { _ = proc(ud ?? UnsafeMutableRawPointer(bitPattern: 1)!, &pre, &t, bus, n, io) }
        let x = renderOutput(bus, Int(n), &t)
        for i in 0..<list.count {
            let bytes = Int(n) * (f._isNonInterleaved ? f._bytesPerSample : f._frameBytes)
            if Int(list[i].mDataByteSize) < bytes || list[i].mDataByteSize == 0 { list[i].mDataByteSize = UInt32(bytes) }
        }
        _ = _PCM.fill(list, x, f, from: 0, count: Int(n))
        var post = AudioUnitRenderActionFlags.unitRenderAction_PostRender
        for (proc, ud) in notifies { _ = proc(ud ?? UnsafeMutableRawPointer(bitPattern: 1)!, &post, &t, bus, n, io) }
        flags?.pointee.remove(.unitRenderAction_OutputIsSilence)
        return noErr_
    }

    // MARK: I/O units

    func startIO() -> OSStatus {
        guard isIO else { return type == kAudioUnitType_Output ? noErr_ : kAudioUnitErr_InvalidProperty }
        Self.renderLock.lock(); defer { Self.renderLock.unlock() }
        if driver != nil { return noErr_ }
        if inputEnabled { let f = _IsimInputFIFO(); f.start(); fifo = f }
        let d = _IsimAudioOutput { [weak self] n, t in self?.ioRender(n, t) ?? [] }
        let session = _IsimSessionIO.ioBufferDuration
        d.framesPerSlice = max(64, min(4096, Int((session * 48000).rounded())))
        driver = d
        d.start()
        notify(kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0)
        return noErr_
    }
    func stopIO() {
        Self.renderLock.lock()
        let d = driver; driver = nil
        Self.renderLock.unlock()
        d?.stop()
        fifo?.stop(); fifo = nil
        if d != nil { notify(kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0) }
    }
    func ioRender(_ n: Int, _ time: Int64) -> [[Float]] {
        Self.renderLock.lock(); defer { Self.renderLock.unlock() }
        var ts = AudioTimeStamp()
        ts.mSampleTime = Double(time); ts.mHostTime = DispatchTime.now().uptimeNanoseconds; ts.mRateScalar = 1
        ts.mFlags = [.sampleTimeValid, .hostTimeValid, .rateScalarValid]
        if inputEnabled, let cb = inputCallback, let proc = cb.inputProc {
            let rate = format(kAudioUnitScope_Output, 1).mSampleRate
            let frames = Int((Double(n) * rate / 48000).rounded())
            var flags = AudioUnitRenderActionFlags(rawValue: 0)
            var t = ts; t.mSampleTime = micTime
            micTime += Double(frames)
            _ = proc(cb.inputProcRefCon ?? UnsafeMutableRawPointer(bitPattern: 1)!, &flags, &t, 1, UInt32(frames), nil)
        }
        guard outputEnabled else { return [] }
        let f = format(kAudioUnitScope_Input, 0)
        let step = f.mSampleRate / 48000
        var pre = AudioUnitRenderActionFlags.unitRenderAction_PreRender
        let ch = Int(f.mChannelsPerFrame)
        let list = _allocBufferList(f, Int((Double(n) * step).rounded(.up)) + 2)
        defer { _freeBufferList(list) }
        for (proc, ud) in notifies { _ = proc(ud ?? UnsafeMutableRawPointer(bitPattern: 1)!, &pre, &ts, 0, UInt32(n), list.unsafeMutablePointer) }
        let x = outResampler.render(n, step: step) { k in
            var t = ts; t.mSampleTime = self.sampleTime
            self.sampleTime += Double(k)
            return self.pullInput(0, k, t) ?? _IsimChannels.silence(ch, k)
        }
        if !notifies.isEmpty {
            var post = AudioUnitRenderActionFlags.unitRenderAction_PostRender
            let m = min(n, Int(list[0].mDataByteSize) / max(1, f._isNonInterleaved ? f._bytesPerSample : f._frameBytes))
            _ = _PCM.fill(list, x, f, from: 0, count: m)
            for (proc, ud) in notifies { _ = proc(ud ?? UnsafeMutableRawPointer(bitPattern: 1)!, &post, &ts, 0, UInt32(m), list.unsafeMutablePointer) }
        }
        if parameter(_VoiceIO_Mute) != 0 { return _IsimChannels.silence(2, n) }
        return x
    }
    func notify(_ id: AudioUnitPropertyID, _ scope: AudioUnitScope, _ element: AudioUnitElement) {
        for (proc, ud, pid) in listeners where pid == id { proc(ud, handle, id, scope, element) }
    }
}

let _Distortion_Drive: AudioUnitParameterID = 0x7FFF_0001     // isim: the drive of AVAudioUnitDistortion's presets
let _VoiceIO_Mute: AudioUnitParameterID = 0x7FFF_0002

/// isim: AVAudioSession's preferred IO buffer duration, read by I/O units and AVAudioEngine (set by AVFoundation).
public enum _IsimSessionIO {
    nonisolated(unsafe) public static var ioBufferDuration = 0.01
}

/// A buffer list with buffers for `n` frames of `f` (free with _freeBufferList).
func _allocBufferList(_ f: AudioStreamBasicDescription, _ n: Int) -> UnsafeMutableAudioBufferListPointer {
    let count = f._isNonInterleaved ? Int(max(1, f.mChannelsPerFrame)) : 1
    let list = AudioBufferList.allocate(maximumBuffers: count)
    let bytes = n * (f._isNonInterleaved ? f._bytesPerSample : f._frameBytes)
    for i in 0..<count {
        list[i] = AudioBuffer(mNumberChannels: f._isNonInterleaved ? 1 : f.mChannelsPerFrame, mDataByteSize: UInt32(bytes), mData: calloc(1, max(1, bytes)))
    }
    return list
}
func _freeBufferList(_ list: UnsafeMutableAudioBufferListPointer) {
    for b in list { free(b.mData) }
    free(list.unsafeMutablePointer)
}

/// Brick-wall-ish peak limiter: an envelope follower keeps peaks under -0.1 dBFS.
public final class _IsimLimiterKernel: _IsimInPlaceKernel {
    public var attack = 0.012, decay = 0.024
    public var preGain: Float = 0
    var gain: Float = 1
    public override func process(_ x: inout [[Float]], rate: Double) {
        let n = x.first?.count ?? 0
        let pg = Float(pow(10, Double(preGain) / 20)), ceiling: Float = 0.989
        let ga = Float(exp(-1 / (max(0.0005, attack) * rate))), gr = Float(exp(-1 / (max(0.001, decay) * rate)))
        for i in 0..<n {
            var peak: Float = 0
            for c in 0..<x.count { x[c][i] *= pg; peak = max(peak, abs(x[c][i])) }
            let target: Float = peak * gain > ceiling ? ceiling / max(peak, 1e-9) : 1
            gain = target < gain ? target + (gain - target) * ga : target + (gain - target) * gr
            if peak * gain > 1 { gain = 1 / peak }            // never clip
            for c in 0..<x.count { x[c][i] *= gain }
        }
    }
}

// MARK: - unit functions

public func AudioUnitInitialize(_ inUnit: AudioUnit) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    u.initialized = true
    return noErr_
}
public func AudioUnitUninitialize(_ inUnit: AudioUnit) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    u.initialized = false
    return noErr_
}
public func AudioUnitReset(_ inUnit: AudioUnit, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    u.kernel?.reset(); u.convResampler.reset(); u.outResampler.reset(); u.micResampler.reset()
    return noErr_
}
public func AudioOutputUnitStart(_ ci: AudioUnit) -> OSStatus {
    guard let u = _IsimAudioUnit.from(ci) else { return kAudio_ParamError }
    guard u.type == kAudioUnitType_Output else { return kAudioUnitErr_InvalidProperty }
    return u.startIO()
}
public func AudioOutputUnitStop(_ ci: AudioUnit) -> OSStatus {
    guard let u = _IsimAudioUnit.from(ci) else { return kAudio_ParamError }
    u.stopIO()
    return noErr_
}
public func AudioUnitRender(_ inUnit: AudioUnit, _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
                            _ inOutputBusNumber: UInt32, _ inNumberFrames: UInt32, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    return u.render(ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData)
}
/// In-place processing (effects): ioData is the input and receives the output.
public func AudioUnitProcess(_ inUnit: AudioUnit, _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
                             _ inNumberFrames: UInt32, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    guard let k = u.kernel else { return kAudioUnitErr_CannotDoInCurrentContext }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    let f = u.format(kAudioUnitScope_Input, 0)
    let list = UnsafeMutableAudioBufferListPointer(ioData)
    let n = Int(inNumberFrames)
    var x: [[Float]]? = _PCM.read(list, f, frames: n)
    u.applyParameters()
    let y = k.render(n, rate: f.mSampleRate) { m in
        if let v = x { x = nil; return v.map { Array($0.prefix(m)) + [Float](repeating: 0, count: max(0, m - $0.count)) } }
        return _IsimChannels.silence(Int(f.mChannelsPerFrame), m)
    }
    _ = _PCM.fill(list, y, u.format(kAudioUnitScope_Output, 0), from: 0, count: n)
    return noErr_
}
public func AudioUnitAddRenderNotify(_ inUnit: AudioUnit, _ inProc: AURenderCallback, _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); u.notifies.append((inProc, inProcUserData)); _IsimAudioUnit.renderLock.unlock()
    return noErr_
}
public func AudioUnitRemoveRenderNotify(_ inUnit: AudioUnit, _ inProc: AURenderCallback, _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock()
    u.notifies.removeAll { unsafeBitCast($0.0, to: UnsafeRawPointer.self) == unsafeBitCast(inProc, to: UnsafeRawPointer.self) && $0.1 == inProcUserData }
    _IsimAudioUnit.renderLock.unlock()
    return noErr_
}
public func AudioUnitGetParameter(_ inUnit: AudioUnit, _ inID: AudioUnitParameterID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement,
                                  _ outValue: UnsafeMutablePointer<AudioUnitParameterValue>) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    guard u.knows(inID, inScope, inElement) else { return kAudioUnitErr_InvalidParameter }
    outValue.pointee = u.parameter(inID, scope: inScope, element: inElement)
    return noErr_
}
public func AudioUnitSetParameter(_ inUnit: AudioUnit, _ inID: AudioUnitParameterID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement,
                                  _ inValue: AudioUnitParameterValue, _ inBufferOffsetInFrames: UInt32) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    guard u.knows(inID, inScope, inElement) else { return kAudioUnitErr_InvalidParameter }
    u.setParameter(inID, inValue, scope: inScope, element: inElement)
    return noErr_
}

extension _IsimAudioUnit {
    /// the parameter IDs of the unit (global scope unless noted)
    var parameterIDs: [AudioUnitParameterID] {
        switch subType {
        case kAudioUnitSubType_MultiChannelMixer: return [0, 1, 2]
        case kAudioUnitSubType_Varispeed: return [0, 1]
        case kAudioUnitSubType_NewTimePitch: return [0, 1, 4, 6]
        case kAudioUnitSubType_Delay: return [0, 1, 2, 3]
        case kAudioUnitSubType_Reverb2: return [0, 1, 2, 3, 4, 5, 6]
        case kAudioUnitSubType_NBandEQ: return [0] + (0..<eqBands).flatMap { b in [1000, 2000, 3000, 4000, 5000].map { $0 + b } }
        case kAudioUnitSubType_LowPassFilter, kAudioUnitSubType_HighPassFilter, kAudioUnitSubType_BandPassFilter,
             kAudioUnitSubType_LowShelfFilter, kAudioUnitSubType_HighShelfFilter: return [0, 1]
        case kAudioUnitSubType_ParametricEQ, kAudioUnitSubType_PeakLimiter: return [0, 1, 2]
        case kAudioUnitSubType_Distortion: return [14, 15]
        case kAudioUnitSubType_RemoteIO, kAudioUnitSubType_VoiceProcessingIO: return []
        default: return []
        }
    }
    func knows(_ id: AudioUnitParameterID, _ scope: AudioUnitScope, _ element: AudioUnitElement) -> Bool {
        if id >= 0x7FFF_0000 { return true }
        if subType == kAudioUnitSubType_MultiChannelMixer {
            if id >= 1000 && id < 5000 { return true }                      // meters (read only)
            return id <= 2 && (scope == kAudioUnitScope_Input ? element < inputBusCount : true)
        }
        return parameterIDs.contains(id)
    }
}

func _auPut<T>(_ v: T, _ size: UnsafeMutablePointer<UInt32>?, _ out: UnsafeMutableRawPointer?) -> OSStatus {
    guard let out else { size?.pointee = UInt32(MemoryLayout<T>.size); return noErr_ }
    if let s = size, Int(s.pointee) < MemoryLayout<T>.size { return kAudioUnitErr_InvalidPropertyValue }
    out.assumingMemoryBound(to: T.self).pointee = v
    size?.pointee = UInt32(MemoryLayout<T>.size)
    return noErr_
}

public func AudioUnitGetPropertyInfo(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement,
                                     _ outDataSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    var size: UInt32 = 0
    let st = u.getProperty(inID, inScope, inElement, nil, &size)
    guard st == noErr_ else { return st }
    outDataSize?.pointee = size
    outWritable?.pointee = DarwinBoolean(![kAudioUnitProperty_LastRenderError, kAudioOutputUnitProperty_IsRunning, kAudioUnitProperty_TailTime,
                                            kAudioUnitProperty_Latency, kAudioUnitProperty_ParameterList].contains(inID))
    return noErr_
}
public func AudioUnitGetProperty(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement,
                                 _ outData: UnsafeMutableRawPointer, _ ioDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    return u.getProperty(inID, inScope, inElement, outData, ioDataSize)
}
public func AudioUnitSetProperty(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inScope: AudioUnitScope, _ inElement: AudioUnitElement,
                                 _ inData: UnsafeRawPointer?, _ inDataSize: UInt32) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    let st = u.setProperty(inID, inScope, inElement, inData, inDataSize)
    if st == noErr_ { u.notify(inID, inScope, inElement) }
    return st
}
public func AudioUnitAddPropertyListener(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inProc: AudioUnitPropertyListenerProc,
                                         _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    u.listeners.append((inProc, inProcUserData, inID))
    return noErr_
}
public func AudioUnitRemovePropertyListenerWithUserData(_ inUnit: AudioUnit, _ inID: AudioUnitPropertyID, _ inProc: AudioUnitPropertyListenerProc,
                                                        _ inProcUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let u = _IsimAudioUnit.from(inUnit) else { return kAudio_ParamError }
    u.listeners.removeAll { $0.2 == inID && $0.1 == inProcUserData && unsafeBitCast($0.0, to: UnsafeRawPointer.self) == unsafeBitCast(inProc, to: UnsafeRawPointer.self) }
    return noErr_
}

extension _IsimAudioUnit {
    func validElement(_ scope: AudioUnitScope, _ e: AudioUnitElement) -> Bool {
        switch scope {
        case kAudioUnitScope_Global: return e == 0
        case kAudioUnitScope_Input: return e < inputBusCount
        case kAudioUnitScope_Output: return e < outputBusCount
        default: return false
        }
    }
    func getProperty(_ id: AudioUnitPropertyID, _ scope: AudioUnitScope, _ e: AudioUnitElement, _ out: UnsafeMutableRawPointer?,
                     _ size: UnsafeMutablePointer<UInt32>?) -> OSStatus {
        switch id {
        case kAudioUnitProperty_StreamFormat:
            guard scope != kAudioUnitScope_Global || e == 0, validElement(scope == kAudioUnitScope_Global ? kAudioUnitScope_Output : scope, e) else {
                return kAudioUnitErr_InvalidElement
            }
            return _auPut(format(scope == kAudioUnitScope_Input ? kAudioUnitScope_Input : kAudioUnitScope_Output, e), size, out)
        case kAudioUnitProperty_SampleRate:
            return _auPut(format(scope == kAudioUnitScope_Input ? kAudioUnitScope_Input : kAudioUnitScope_Output, e).mSampleRate, size, out)
        case kAudioUnitProperty_ElementCount:
            return _auPut(scope == kAudioUnitScope_Input ? inputBusCount : scope == kAudioUnitScope_Output ? outputBusCount : UInt32(1), size, out)
        case kAudioUnitProperty_MaximumFramesPerSlice: return _auPut(maxFrames, size, out)
        case kAudioUnitProperty_Latency: return _auPut(Float64(0), size, out)
        case kAudioUnitProperty_TailTime: return _auPut(Float64(kernel?.tailTime ?? 0), size, out)
        case kAudioUnitProperty_BypassEffect: return _auPut(UInt32(bypass ? 1 : 0), size, out)
        case kAudioUnitProperty_LastRenderError: return _auPut(lastError, size, out)
        case kAudioUnitProperty_ShouldAllocateBuffer: return _auPut(UInt32(1), size, out)
        case kAudioUnitProperty_MeteringMode: return _auPut(UInt32(metering ? 1 : 0), size, out)
        case kAudioUnitProperty_SetRenderCallback:
            guard let cb = callbacks[e] else { return kAudioUnitErr_PropertyNotInUse }
            return _auPut(cb, size, out)
        case kAudioUnitProperty_MakeConnection:
            guard let c = connections[e] else { return kAudioUnitErr_PropertyNotInUse }
            return _auPut(AudioUnitConnection(sourceAudioUnit: c.unit.handle, sourceOutputNumber: c.bus, destInputNumber: e), size, out)
        case kAudioUnitProperty_ParameterList:
            let ids = parameterIDs
            guard let out else { size?.pointee = UInt32(ids.count * 4); return noErr_ }
            let n = min(ids.count, Int(size?.pointee ?? 0) / 4)
            for i in 0..<n { out.storeBytes(of: ids[i], toByteOffset: 4 * i, as: UInt32.self) }
            size?.pointee = UInt32(n * 4)
            return noErr_
        case kAudioOutputUnitProperty_IsRunning:
            guard type == kAudioUnitType_Output else { return kAudioUnitErr_InvalidProperty }
            return _auPut(UInt32(driver != nil ? 1 : 0), size, out)
        case kAudioOutputUnitProperty_EnableIO:
            guard isIO else { return kAudioUnitErr_InvalidProperty }
            return _auPut(UInt32((e == 1 ? inputEnabled : outputEnabled) ? 1 : 0), size, out)
        case kAudioOutputUnitProperty_SetInputCallback:
            guard isIO, let cb = inputCallback else { return kAudioUnitErr_PropertyNotInUse }
            return _auPut(cb, size, out)
        case kAUNBandEQProperty_NumberOfBands:
            guard subType == kAudioUnitSubType_NBandEQ else { return kAudioUnitErr_InvalidProperty }
            return _auPut(eqBands, size, out)
        case kAUNBandEQProperty_MaxNumberOfBands:
            guard subType == kAudioUnitSubType_NBandEQ else { return kAudioUnitErr_InvalidProperty }
            return _auPut(UInt32(16), size, out)
        case kAUVoiceIOProperty_BypassVoiceProcessing, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAUVoiceIOProperty_MuteOutput:
            guard subType == kAudioUnitSubType_VoiceProcessingIO else { return kAudioUnitErr_InvalidProperty }
            return _auPut(UInt32(id == kAUVoiceIOProperty_MuteOutput ? (parameter(_VoiceIO_Mute) != 0 ? 1 : 0) : 0), size, out)
        default: return kAudioUnitErr_InvalidProperty
        }
    }
    func setProperty(_ id: AudioUnitPropertyID, _ scope: AudioUnitScope, _ e: AudioUnitElement, _ data: UnsafeRawPointer?, _ size: UInt32) -> OSStatus {
        func value<T>(_ t: T.Type) -> T? {
            guard let data, Int(size) >= MemoryLayout<T>.size else { return nil }
            return data.loadUnaligned(as: T.self)
        }
        switch id {
        case kAudioUnitProperty_StreamFormat:
            guard let f = value(AudioStreamBasicDescription.self) else { return kAudioUnitErr_InvalidPropertyValue }
            guard _PCM.valid(f) else { return kAudioUnitErr_FormatNotSupported }
            if scope == kAudioUnitScope_Input { guard e < inputBusCount else { return kAudioUnitErr_InvalidElement }; inFormats[e] = f }
            else { guard e < outputBusCount else { return kAudioUnitErr_InvalidElement }; outFormats[e] = f }
            // effects and mixers run at one rate: keep the other side's rate in step (like Apple's units do)
            if subType != kAudioUnitSubType_AUConverter && !isIO && type != kAudioUnitType_Output {
                for k in inFormats.keys { inFormats[k]!.mSampleRate = f.mSampleRate }
                for k in outFormats.keys { outFormats[k]!.mSampleRate = f.mSampleRate }
            }
            return noErr_
        case kAudioUnitProperty_SampleRate:
            guard let r = value(Float64.self), r > 0 else { return kAudioUnitErr_InvalidPropertyValue }
            if scope == kAudioUnitScope_Input { inFormats[e]?.mSampleRate = r } else { outFormats[e]?.mSampleRate = r }
            return noErr_
        case kAudioUnitProperty_ElementCount:
            guard let n = value(UInt32.self) else { return kAudioUnitErr_InvalidPropertyValue }
            guard subType == kAudioUnitSubType_MultiChannelMixer, scope == kAudioUnitScope_Input else { return kAudioUnitErr_PropertyNotWritable }
            let f = format(kAudioUnitScope_Input, 0)
            for b in inputBusCount..<max(inputBusCount, n) { inFormats[b] = f }
            inputBusCount = n
            return noErr_
        case kAudioUnitProperty_MaximumFramesPerSlice:
            guard let n = value(UInt32.self) else { return kAudioUnitErr_InvalidPropertyValue }
            maxFrames = n
            return noErr_
        case kAudioUnitProperty_BypassEffect:
            guard let v = value(UInt32.self) else { return kAudioUnitErr_InvalidPropertyValue }
            bypass = v != 0
            return noErr_
        case kAudioUnitProperty_ShouldAllocateBuffer: return noErr_
        case kAudioUnitProperty_MeteringMode:
            guard let v = value(UInt32.self) else { return kAudioUnitErr_InvalidPropertyValue }
            metering = v != 0
            return noErr_
        case kAudioUnitProperty_SetRenderCallback:
            guard scope == kAudioUnitScope_Input || scope == kAudioUnitScope_Global, e < inputBusCount else { return kAudioUnitErr_InvalidElement }
            guard let cb = value(AURenderCallbackStruct.self) else { callbacks[e] = nil; return noErr_ }
            if cb.inputProc == nil { callbacks[e] = nil } else { callbacks[e] = cb; connections[e] = nil }
            return noErr_
        case kAudioUnitProperty_MakeConnection:
            guard let c = value(AudioUnitConnection.self) else { return kAudioUnitErr_InvalidPropertyValue }
            guard c.destInputNumber < inputBusCount else { return kAudioUnitErr_InvalidElement }
            if let src = _IsimAudioUnit.from(c.sourceAudioUnit) {
                connections[c.destInputNumber] = (src, c.sourceOutputNumber); callbacks[c.destInputNumber] = nil
            } else { connections[c.destInputNumber] = nil }
            return noErr_
        case kAudioOutputUnitProperty_EnableIO:
            guard isIO else { return kAudioUnitErr_InvalidProperty }
            guard let v = value(UInt32.self) else { return kAudioUnitErr_InvalidPropertyValue }
            guard driver == nil else { return kAudioUnitErr_Initialized }
            if e == 1 { inputEnabled = v != 0 } else { outputEnabled = v != 0 }
            return noErr_
        case kAudioOutputUnitProperty_SetInputCallback:
            guard isIO else { return kAudioUnitErr_InvalidProperty }
            guard let cb = value(AURenderCallbackStruct.self) else { inputCallback = nil; return noErr_ }
            inputCallback = cb.inputProc == nil ? nil : cb
            return noErr_
        case kAUNBandEQProperty_NumberOfBands:
            guard subType == kAudioUnitSubType_NBandEQ, let n = value(UInt32.self), n >= 1, n <= 16 else { return kAudioUnitErr_InvalidPropertyValue }
            guard !initialized else { return kAudioUnitErr_Initialized }
            eqBands = n
            return noErr_
        case kAUVoiceIOProperty_BypassVoiceProcessing, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAUVoiceIOProperty_MuteOutput:
            guard subType == kAudioUnitSubType_VoiceProcessingIO, let v = value(UInt32.self) else { return kAudioUnitErr_InvalidProperty }
            if id == kAUVoiceIOProperty_MuteOutput { setParameter(_VoiceIO_Mute, v != 0 ? 1 : 0) }
            return noErr_
        case kAudioOutputUnitProperty_CurrentDevice, kAudioUnitProperty_ClassInfo: return noErr_
        default: return kAudioUnitErr_InvalidProperty
        }
    }
}

// MARK: - AUGraph

final class _AUGraph {
    struct Node { let id: AUNode; let component: _AUComponent; var unit: _IsimAudioUnit? }
    var nodes: [Node] = []
    var next: AUNode = 1
    var connections: [(src: AUNode, srcOut: UInt32, dst: AUNode, dstIn: UInt32)] = []
    var callbacks: [(dst: AUNode, dstIn: UInt32, cb: AURenderCallbackStruct)] = []
    var isOpen = false, isInitialized = false, running = false
    var notifies: [(AURenderCallback, UnsafeMutableRawPointer?)] = []
    func node(_ id: AUNode) -> Node? { nodes.first { $0.id == id } }
    var output: Node? { nodes.first { $0.component.desc.componentType == kAudioUnitType_Output } }
    /// applies the connections and callbacks to the units
    func apply() {
        for n in nodes {
            guard let u = n.unit else { continue }
            for b in 0..<u.inputBusCount where n.component.desc.componentType != kAudioUnitType_Output || b == 0 {
                u.connections[b] = nil; u.callbacks[b] = nil
            }
        }
        for c in connections {
            guard let s = node(c.src)?.unit, let d = node(c.dst)?.unit else { continue }
            d.connections[c.dstIn] = (s, c.srcOut)
        }
        for c in callbacks { node(c.dst)?.unit?.callbacks[c.dstIn] = c.cb }
        if let o = output?.unit { o.notifies = notifies }
    }
}
func _graph(_ g: AUGraph?) -> _AUGraph? { _object(g, _AUGraph.self) }

public func NewAUGraph(_ outGraph: UnsafeMutablePointer<AUGraph?>) -> OSStatus {
    outGraph.pointee = _handle(_AUGraph())
    return noErr_
}
public func DisposeAUGraph(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _ = AUGraphStop(inGraph)
    for n in g.nodes { n.unit?.dispose() }
    g.nodes = []
    _release(inGraph)
    return noErr_
}
public func AUGraphAddNode(_ inGraph: AUGraph, _ inDescription: UnsafePointer<AudioComponentDescription>, _ outNode: UnsafeMutablePointer<AUNode>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard let c = _AUComponent.all.first(where: { $0.matches(inDescription.pointee) }) else { return kAUGraphErr_InvalidAudioUnit }
    let id = g.next; g.next += 1
    g.nodes.append(.init(id: id, component: c, unit: g.isOpen ? _IsimAudioUnit(c) : nil))
    outNode.pointee = id
    return noErr_
}
public func AUGraphRemoveNode(_ inGraph: AUGraph, _ inNode: AUNode) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard let i = g.nodes.firstIndex(where: { $0.id == inNode }) else { return kAUGraphErr_NodeNotFound }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.nodes[i].unit?.dispose()
    g.nodes.remove(at: i)
    g.connections.removeAll { $0.src == inNode || $0.dst == inNode }
    g.callbacks.removeAll { $0.dst == inNode }
    g.apply()
    return noErr_
}
public func AUGraphGetNodeCount(_ inGraph: AUGraph, _ outNumberOfNodes: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    outNumberOfNodes.pointee = UInt32(g.nodes.count)
    return noErr_
}
public func AUGraphGetIndNode(_ inGraph: AUGraph, _ inIndex: UInt32, _ outNode: UnsafeMutablePointer<AUNode>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard Int(inIndex) < g.nodes.count else { return kAUGraphErr_NodeNotFound }
    outNode.pointee = g.nodes[Int(inIndex)].id
    return noErr_
}
public func AUGraphNodeInfo(_ inGraph: AUGraph, _ inNode: AUNode, _ outDescription: UnsafeMutablePointer<AudioComponentDescription>?,
                            _ outAudioUnit: UnsafeMutablePointer<AudioUnit?>?) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard let n = g.node(inNode) else { return kAUGraphErr_NodeNotFound }
    outDescription?.pointee = n.component.desc
    if let outAudioUnit {
        guard let u = n.unit else { return kAUGraphErr_InvalidAudioUnit }       // AUGraphOpen first
        outAudioUnit.pointee = u.handle
    }
    return noErr_
}
public func AUGraphConnectNodeInput(_ inGraph: AUGraph, _ inSourceNode: AUNode, _ inSourceOutputNumber: UInt32, _ inDestNode: AUNode,
                                    _ inDestInputNumber: UInt32) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard g.node(inSourceNode) != nil, g.node(inDestNode) != nil else { return kAUGraphErr_NodeNotFound }
    guard inSourceNode != inDestNode else { return kAUGraphErr_InvalidConnection }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.connections.removeAll { $0.dst == inDestNode && $0.dstIn == inDestInputNumber }
    g.callbacks.removeAll { $0.dst == inDestNode && $0.dstIn == inDestInputNumber }
    g.connections.append((inSourceNode, inSourceOutputNumber, inDestNode, inDestInputNumber))
    if g.isOpen { g.apply() }
    return noErr_
}
public func AUGraphDisconnectNodeInput(_ inGraph: AUGraph, _ inDestNode: AUNode, _ inDestInputNumber: UInt32) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.connections.removeAll { $0.dst == inDestNode && $0.dstIn == inDestInputNumber }
    g.callbacks.removeAll { $0.dst == inDestNode && $0.dstIn == inDestInputNumber }
    if g.isOpen { g.apply() }
    return noErr_
}
public func AUGraphSetNodeInputCallback(_ inGraph: AUGraph, _ inDestNode: AUNode, _ inDestInputNumber: UInt32,
                                        _ inInputCallback: UnsafePointer<AURenderCallbackStruct>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard g.node(inDestNode) != nil else { return kAUGraphErr_NodeNotFound }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.connections.removeAll { $0.dst == inDestNode && $0.dstIn == inDestInputNumber }
    g.callbacks.removeAll { $0.dst == inDestNode && $0.dstIn == inDestInputNumber }
    g.callbacks.append((inDestNode, inDestInputNumber, inInputCallback.pointee))
    if g.isOpen { g.apply() }
    return noErr_
}
public func AUGraphClearConnections(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.connections = []; g.callbacks = []
    if g.isOpen { g.apply() }
    return noErr_
}
public func AUGraphUpdate(_ inGraph: AUGraph, _ outIsUpdated: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    if g.isOpen { g.apply() }
    outIsUpdated?.pointee = true
    return noErr_
}
public func AUGraphOpen(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard !g.isOpen else { return noErr_ }
    for i in g.nodes.indices where g.nodes[i].unit == nil { g.nodes[i].unit = _IsimAudioUnit(g.nodes[i].component) }
    g.isOpen = true
    g.apply()
    return noErr_
}
public func AUGraphClose(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _ = AUGraphStop(inGraph)
    for i in g.nodes.indices { g.nodes[i].unit?.dispose(); g.nodes[i].unit = nil }
    g.isOpen = false; g.isInitialized = false
    return noErr_
}
public func AUGraphInitialize(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    if !g.isOpen { _ = AUGraphOpen(inGraph) }
    guard g.output != nil else { return kAUGraphErr_OutputNodeErr }
    for n in g.nodes { n.unit?.initialized = true }
    g.isInitialized = true
    return noErr_
}
public func AUGraphUninitialize(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    for n in g.nodes { n.unit?.initialized = false }
    g.isInitialized = false
    return noErr_
}
public func AUGraphStart(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard g.isInitialized, let o = g.output?.unit else { return kAUGraphErr_CannotDoInCurrentContext }
    let st = o.startIO()
    g.running = st == noErr_
    return st
}
public func AUGraphStop(_ inGraph: AUGraph) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    g.output?.unit?.stopIO()
    g.running = false
    return noErr_
}
public func AUGraphIsOpen(_ inGraph: AUGraph, _ outIsOpen: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    outIsOpen.pointee = DarwinBoolean(g.isOpen); return noErr_
}
public func AUGraphIsInitialized(_ inGraph: AUGraph, _ outIsInitialized: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    outIsInitialized.pointee = DarwinBoolean(g.isInitialized); return noErr_
}
public func AUGraphIsRunning(_ inGraph: AUGraph, _ outIsRunning: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    outIsRunning.pointee = DarwinBoolean(g.running); return noErr_
}
public func AUGraphGetCPULoad(_ inGraph: AUGraph, _ outAverageCPULoad: UnsafeMutablePointer<Float32>) -> OSStatus {
    outAverageCPULoad.pointee = 0; return noErr_
}
public func AUGraphGetMaxCPULoad(_ inGraph: AUGraph, _ outMaxLoad: UnsafeMutablePointer<Float32>) -> OSStatus {
    outMaxLoad.pointee = 0; return noErr_
}
public func AUGraphAddRenderNotify(_ inGraph: AUGraph, _ inCallback: AURenderCallback, _ inRefCon: UnsafeMutableRawPointer?) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.notifies.append((inCallback, inRefCon))
    if g.isOpen { g.apply() }
    return noErr_
}
public func AUGraphRemoveRenderNotify(_ inGraph: AUGraph, _ inCallback: AURenderCallback, _ inRefCon: UnsafeMutableRawPointer?) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    _IsimAudioUnit.renderLock.lock(); defer { _IsimAudioUnit.renderLock.unlock() }
    g.notifies.removeAll { unsafeBitCast($0.0, to: UnsafeRawPointer.self) == unsafeBitCast(inCallback, to: UnsafeRawPointer.self) && $0.1 == inRefCon }
    if g.isOpen { g.apply() }
    return noErr_
}
