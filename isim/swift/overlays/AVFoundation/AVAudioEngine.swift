// isim AVFoundation: AVAudioEngine and its nodes — a pull render graph. Self-authored, iOS API names.
// Adapted:
// - The output node pulls the graph slice by slice: on isim's real-time render thread (AudioToolbox's
//   _IsimAudioOutput: 48 kHz stereo to the host mixer, paced in real time, silently when headless), or from the app
//   in manual rendering mode (renderOffline / manualRenderingBlock). Both run the same graph.
// - Mixers convert their inputs' sample rates (linear interpolation) and channel counts, and apply each input's
//   AVAudioMixing volume and pan. AVAudioEnvironmentNode spatializes mono inputs with distance attenuation (inverse,
//   linear, exponential) and equal-power panning by azimuth (no HRTF), obstruction/occlusion as attenuation, and a
//   reverb send.
// - Effects are Audio Units of AudioToolbox (isim's own DSP: AudioDSP.swift); their parameters can change while
//   audio plays. AVAudioUnit.audioUnit is the unit, so AudioUnitSetParameter works on them too.
// - Taps work on any node's output bus. Player-node completion handlers and taps run on the main queue in real time
//   (Apple: an internal thread), synchronously inside renderOffline in manual rendering.
import Foundation
import AudioToolbox
import isim_host

// MARK: - time

public struct AVAudioTime: Sendable {
    public var sampleTime: AVAudioFramePosition
    public var sampleRate: Double
    public init(sampleTime: AVAudioFramePosition, atRate rate: Double) { self.sampleTime = sampleTime; sampleRate = rate; _flags = 1 }
    var _hostTime: UInt64 = 0
    var _flags: UInt8 = 0                      // 1 sample time valid, 2 host time valid
    public init(hostTime: UInt64) { sampleTime = 0; sampleRate = 0; _hostTime = hostTime; _flags = 2 }
    public init(hostTime: UInt64, sampleTime: AVAudioFramePosition, atRate rate: Double) {
        self.sampleTime = sampleTime; sampleRate = rate; _hostTime = hostTime; _flags = 3
    }
    public init(audioTimeStamp ts: UnsafePointer<AudioTimeStamp>, sampleRate: Double) {
        let t = ts.pointee
        sampleTime = AVAudioFramePosition(t.mSampleTime); self.sampleRate = sampleRate; _hostTime = t.mHostTime
        _flags = (t.mFlags.contains(.sampleTimeValid) ? 1 : 0) | (t.mFlags.contains(.hostTimeValid) ? 2 : 0)
    }
    public var hostTime: UInt64 { _hostTime }
    public var isSampleTimeValid: Bool { _flags & 1 != 0 }
    public var isHostTimeValid: Bool { _flags & 2 != 0 }
    public var audioTimeStamp: AudioTimeStamp {
        var t = AudioTimeStamp()
        t.mSampleTime = Double(sampleTime); t.mHostTime = _hostTime; t.mRateScalar = 1
        if isSampleTimeValid { t.mFlags.insert(.sampleTimeValid) }
        if isHostTimeValid { t.mFlags.insert(.hostTimeValid) }
        return t
    }
    /// host times are nanoseconds of the uptime clock (mach_absolute_time)
    public static func hostTime(forSeconds seconds: TimeInterval) -> UInt64 { UInt64(max(0, seconds) * 1e9) }
    public static func seconds(forHostTime hostTime: UInt64) -> TimeInterval { Double(hostTime) / 1e9 }
    /// fills in the missing time (sample or host) from an anchor that has both
    public func extrapolateTime(fromAnchor anchor: AVAudioTime) -> AVAudioTime? {
        guard anchor.isSampleTimeValid, anchor.isHostTimeValid, anchor.sampleRate > 0 else { return nil }
        let rate = sampleRate > 0 ? sampleRate : anchor.sampleRate
        if isSampleTimeValid && !isHostTimeValid {
            let dt = Double(sampleTime) / rate - Double(anchor.sampleTime) / anchor.sampleRate
            return AVAudioTime(hostTime: UInt64(max(0, Double(anchor.hostTime) + dt * 1e9)), sampleTime: sampleTime, atRate: rate)
        }
        if isHostTimeValid && !isSampleTimeValid {
            let dt = (Double(hostTime) - Double(anchor.hostTime)) / 1e9
            return AVAudioTime(hostTime: hostTime, sampleTime: anchor.sampleTime + AVAudioFramePosition((dt * anchor.sampleRate).rounded()), atRate: anchor.sampleRate)
        }
        return self
    }
    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
}

// MARK: - 3D types and mixing protocols

public struct AVAudio3DPoint: Sendable, Equatable {
    public var x: Float, y: Float, z: Float
    public init() { x = 0; y = 0; z = 0 }
    public init(x: Float, y: Float, z: Float) { self.x = x; self.y = y; self.z = z }
}
public typealias AVAudio3DVector = AVAudio3DPoint
public func AVAudioMake3DPoint(_ x: Float, _ y: Float, _ z: Float) -> AVAudio3DPoint { AVAudio3DPoint(x: x, y: y, z: z) }
public func AVAudioMake3DVector(_ x: Float, _ y: Float, _ z: Float) -> AVAudio3DVector { AVAudio3DPoint(x: x, y: y, z: z) }
public struct AVAudio3DAngularOrientation: Sendable, Equatable {
    public var yaw: Float, pitch: Float, roll: Float
    public init() { yaw = 0; pitch = 0; roll = 0 }
    public init(yaw: Float, pitch: Float, roll: Float) { self.yaw = yaw; self.pitch = pitch; self.roll = roll }
}
public struct AVAudio3DVectorOrientation: Sendable, Equatable {
    public var forward: AVAudio3DVector, up: AVAudio3DVector
    public init() { forward = AVAudio3DPoint(x: 0, y: 0, z: -1); up = AVAudio3DPoint(x: 0, y: 1, z: 0) }
    public init(forward: AVAudio3DVector, up: AVAudio3DVector) { self.forward = forward; self.up = up }
}
public func AVAudioMake3DVectorOrientation(_ forward: AVAudio3DVector, _ up: AVAudio3DVector) -> AVAudio3DVectorOrientation {
    AVAudio3DVectorOrientation(forward: forward, up: up)
}
public func AVAudioMake3DAngularOrientation(_ yaw: Float, _ pitch: Float, _ roll: Float) -> AVAudio3DAngularOrientation {
    AVAudio3DAngularOrientation(yaw: yaw, pitch: pitch, roll: roll)
}
public enum AVAudio3DMixingRenderingAlgorithm: Int, Sendable {
    case equalPowerPanning = 0, sphericalHead = 1, HRTF = 2, soundField = 3, stereoPassThrough = 5, HRTFHQ = 6, auto = 7
}
public enum AVAudio3DMixingSourceMode: Int, Sendable { case spatializeIfMono = 0, bypass = 1, pointSource = 2, ambienceBed = 3 }
public enum AVAudio3DMixingPointSourceInHeadMode: Int, Sendable { case mono = 0, bypass = 1 }

public protocol AVAudioStereoMixing: NSObjectProtocol {
    var pan: Float { get set }
}
public protocol AVAudio3DMixing: NSObjectProtocol {
    var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get set }
    var sourceMode: AVAudio3DMixingSourceMode { get set }
    var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get set }
    var rate: Float { get set }
    var reverbBlend: Float { get set }
    var obstruction: Float { get set }
    var occlusion: Float { get set }
    var position: AVAudio3DPoint { get set }
}
public protocol AVAudioMixing: AVAudioStereoMixing, AVAudio3DMixing {
    var volume: Float { get set }
    func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination?
}

/// The mixing settings of one source node (shared by the node and its destinations).
final class _MixSettings {
    var volume: Float = 1, pan: Float = 0
    var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm = .equalPowerPanning
    var sourceMode: AVAudio3DMixingSourceMode = .spatializeIfMono
    var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode = .mono
    var rate: Float = 1, reverbBlend: Float = 0, obstruction: Float = 0, occlusion: Float = 0
    var position = AVAudio3DPoint()
}

func _mixSettings(_ n: AVAudioNode) -> _MixSettings? {
    (n as? AVAudioPlayerNode)?._mix ?? (n as? AVAudioMixerNode)?._mix ?? (n as? AVAudioInputNode)?._mix ?? (n as? AVAudioSourceNode)?._mix
        ?? (n as? AVAudioEnvironmentNode)?._mix
}

/// One connection of a source node to a mixer.
open class AVAudioMixingDestination: NSObject, AVAudioMixing {
    let settings: _MixSettings
    public let connectionPoint: AVAudioConnectionPoint
    init(_ s: _MixSettings, _ p: AVAudioConnectionPoint) { settings = s; connectionPoint = p }
    open var volume: Float { get { settings.volume } set { settings.volume = newValue } }
    open var pan: Float { get { settings.pan } set { settings.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { settings.renderingAlgorithm } set { settings.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { settings.sourceMode } set { settings.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { settings.pointSourceInHeadMode } set { settings.pointSourceInHeadMode = newValue } }
    open var rate: Float { get { settings.rate } set { settings.rate = max(0.5, min(2, newValue)) } }
    open var reverbBlend: Float { get { settings.reverbBlend } set { settings.reverbBlend = max(0, min(1, newValue)) } }
    open var obstruction: Float { get { settings.obstruction } set { settings.obstruction = max(-100, min(0, newValue)) } }
    open var occlusion: Float { get { settings.occlusion } set { settings.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { settings.position } set { settings.position = newValue } }
    open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? { nil }
}

open class AVAudioConnectionPoint: NSObject {
    open private(set) weak var node: AVAudioNode?
    public let bus: AVAudioNodeBus
    public init(node: AVAudioNode, bus: AVAudioNodeBus) { self.node = node; self.bus = bus }
}

// MARK: - nodes

/// Per render cycle state: fan-out nodes render once per cycle.
final class _Cycle {
    let frames: Int
    let sampleTime: Int64
    let rate: Double
    let offline: Bool
    var cache: [ObjectIdentifier: [[Float]]] = [:]
    var rendered = Set<ObjectIdentifier>()
    var completions: [() -> Void] = []
    init(frames: Int, sampleTime: Int64, rate: Double, offline: Bool) { self.frames = frames; self.sampleTime = sampleTime; self.rate = rate; self.offline = offline }
}

final class _Tap {
    let size: Int
    let format: AVAudioFormat?
    let block: AVAudioNodeTapBlock
    var pending: [[Float]] = []
    var start: Int64 = 0
    var produced: Int64 = 0
    init(size: Int, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock) { self.size = size; self.format = format; self.block = block }
}

open class AVAudioNode: NSObject {
    weak var engine: AVAudioEngine?
    var _tap: _Tap?
    var _lastRender: AVAudioTime?
    var _defaultFormat: AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)! }
    /// the format of a bus: the connection's format when one was given
    open func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        engine?._outputConnections(of: self, bus: bus).first?.format ?? _naturalOutputFormat
    }
    open func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        engine?._inputConnection(of: self, bus: bus)?.format ?? outputFormat(forBus: 0)
    }
    var _naturalOutputFormat: AVAudioFormat { _defaultFormat }
    open func reset() {}
    open var numberOfInputs: Int { 1 }
    open var numberOfOutputs: Int { 1 }
    open var lastRenderTime: AVAudioTime? { engine?.isRunning == true ? _lastRender : nil }
    open var latency: TimeInterval { 0 }
    open var outputPresentationLatency: TimeInterval { 0.01 }
    open func name(forInputBus bus: AVAudioNodeBus) -> String? { nil }
    open func name(forOutputBus bus: AVAudioNodeBus) -> String? { nil }

    /// the sample rate this node renders at
    func _rate() -> Double { outputFormat(forBus: 0).sampleRate }
    /// renders `n` frames of output bus 0 (deinterleaved, the node's channel count, at its rate)
    func _render(_ n: Int, _ c: _Cycle) -> [[Float]] { _IsimChannels.silence(Int(outputFormat(forBus: 0).channelCount), n) }
    /// what consumers call: renders (once per cycle for fan-out nodes) and feeds the tap
    func _pull(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let fanOut = (engine?._outputConnections(of: self, bus: 0).count ?? 0) > 1
        if fanOut, let x = c.cache[ObjectIdentifier(self)], x.first?.count == n { return x }
        let x = _render(n, c)
        c.rendered.insert(ObjectIdentifier(self))
        _lastRender = AVAudioTime(hostTime: AVAudioTime.now(), sampleTime: c.sampleTime, atRate: c.rate)
        if fanOut { c.cache[ObjectIdentifier(self)] = x }
        if let t = _tap { _feed(t, x, c) }
        return x
    }
    func _feed(_ t: _Tap, _ x: [[Float]], _ c: _Cycle) {
        let fmt = t.format ?? outputFormat(forBus: 0)
        let ch = Int(fmt.channelCount)
        let y = _IsimChannels.adapt(x, to: ch, frames: x.first?.count ?? 0)
        if t.pending.count != ch { t.pending = [[Float]](repeating: [], count: ch) }
        for k in 0..<ch { t.pending[k].append(contentsOf: y[k]) }
        while (t.pending.first?.count ?? 0) >= t.size {
            let b = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: fmt.sampleRate, channels: AVAudioChannelCount(ch))!,
                                     frameCapacity: AVAudioFrameCount(t.size))!
            for k in 0..<ch { t.pending[k].withUnsafeBufferPointer { b.channels[k].update(from: $0.baseAddress!, count: t.size) }; t.pending[k].removeFirst(t.size) }
            b.frameLength = AVAudioFrameCount(t.size)
            let when = AVAudioTime(hostTime: AVAudioTime.now(), sampleTime: t.produced, atRate: fmt.sampleRate)
            t.produced += Int64(t.size)
            let block = t.block
            if c.offline { block(b, when) } else { c.completions.append { block(b, when) } }
        }
    }
    /// the node feeding input `bus` (rendered at this node's rate)
    func _input(_ bus: AVAudioNodeBus, _ n: Int, _ c: _Cycle) -> [[Float]]? {
        guard let e = engine, let conn = e._inputConnection(of: self, bus: bus), let src = conn.src else { return nil }
        return src._pull(n, c)
    }
}

/// Sums its inputs (converting rate and channels) with each input's volume and pan.
open class AVAudioMixerNode: AVAudioNode, AVAudioMixing {
    let _mix = _MixSettings()
    var _resamplers: [Int: _IsimResampler] = [:]
    /// the mixer's own output gain
    open var outputVolume: Float = 1
    /// as an input of another mixer (AVAudioMixing)
    open var volume: Float { get { _mix.volume } set { _mix.volume = max(0, newValue) } }
    open var pan: Float { get { _mix.pan } set { _mix.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { _mix.renderingAlgorithm } set { _mix.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { _mix.sourceMode } set { _mix.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { _mix.pointSourceInHeadMode } set { _mix.pointSourceInHeadMode = newValue } }
    open var rate: Float { get { _mix.rate } set { _mix.rate = max(0.5, min(2, newValue)) } }
    open var reverbBlend: Float { get { _mix.reverbBlend } set { _mix.reverbBlend = max(0, min(1, newValue)) } }
    open var obstruction: Float { get { _mix.obstruction } set { _mix.obstruction = max(-100, min(0, newValue)) } }
    open var occlusion: Float { get { _mix.occlusion } set { _mix.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { _mix.position } set { _mix.position = newValue } }
    open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? {
        guard let e = engine, e._outputConnections(of: self, bus: 0).contains(where: { $0.dst === mixer && $0.dstBus == bus }) else { return nil }
        return AVAudioMixingDestination(_mix, AVAudioConnectionPoint(node: mixer, bus: bus))
    }
    open var nextAvailableInputBus: AVAudioNodeBus { engine?._nextInputBus(self) ?? 0 }
    open override var numberOfInputs: Int { max(1, nextAvailableInputBus) }
    override var _naturalOutputFormat: AVAudioFormat {
        if let e = engine, self === e.mainMixerNode {
            if let m = e._manual { return AVAudioFormat(standardFormatWithSampleRate: m.format.sampleRate, channels: m.format.channelCount)! }
            return e.outputNode.inputFormat(forBus: 0)
        }
        return _defaultFormat
    }
    open override func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        engine?._inputConnection(of: self, bus: bus)?.format ?? outputFormat(forBus: 0)
    }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let rate = _rate()
        var out = _IsimChannels.silence(Int(outputFormat(forBus: 0).channelCount), n)
        guard let e = engine else { return out }
        for conn in e._inputConnections(of: self) {
            guard let src = conn.src else { continue }
            let s = _mixSettings(src)
            let srcRate = src._rate() * Double(s?.rate ?? 1)
            let x: [[Float]]
            if abs(srcRate - rate) > 1e-6 {
                let rs = _resamplers[conn.dstBus] ?? _IsimResampler()
                _resamplers[conn.dstBus] = rs
                x = rs.render(n, step: srcRate / rate) { src._pull($0, c) }
            } else { x = src._pull(n, c) }
            _mixInput(x, s, into: &out, c)
        }
        if outputVolume != 1 { for k in 0..<out.count { for i in 0..<n { out[k][i] *= outputVolume } } }
        return out
    }
    func _mixInput(_ x: [[Float]], _ s: _MixSettings?, into out: inout [[Float]], _ c: _Cycle) {
        _IsimChannels.mix(x, into: &out, gain: s?.volume ?? 1, pan: s?.pan ?? 0)
    }
    open override func reset() { _resamplers = [:] }
}

open class AVAudioIONode: AVAudioNode {
    var _voiceProcessing = false
    open var presentationLatency: TimeInterval { 0.005 }
    open var isVoiceProcessingEnabled: Bool { _voiceProcessing }
    open func setVoiceProcessingEnabled(_ enabled: Bool) throws { _voiceProcessing = enabled }
    open var audioUnit: AudioUnit? { nil }
}

/// The speaker: 48 kHz stereo (the host mixer's format).
open class AVAudioOutputNode: AVAudioIONode {
    let _resampler = _IsimResampler()
    open override func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)! }
    open override func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        engine?._inputConnection(of: self, bus: bus)?.format ?? AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        guard let e = engine else { return _IsimChannels.silence(2, n) }
        let src: AVAudioNode = e._inputConnection(of: self, bus: 0)?.src ?? e.mainMixerNode
        let s = _mixSettings(src)
        var x = src._pull(n, c)
        let g = s?.volume ?? 1
        if g != 1 { for k in 0..<x.count { for i in 0..<x[k].count { x[k][i] *= g } } }
        return x
    }
}

public struct AVAudioPlayerNodeBufferOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let loops = AVAudioPlayerNodeBufferOptions(rawValue: 1)
    public static let interrupts = AVAudioPlayerNodeBufferOptions(rawValue: 2)
    public static let interruptsAtLoop = AVAudioPlayerNodeBufferOptions(rawValue: 4)
}
public enum AVAudioPlayerNodeCompletionCallbackType: Int, Sendable { case dataConsumed, dataRendered, dataPlayedBack }

/// Plays scheduled buffers and file segments one after another.
open class AVAudioPlayerNode: AVAudioNode, AVAudioMixing {
    let _mix = _MixSettings()
    open var volume: Float { get { _mix.volume } set { _mix.volume = max(0, newValue) } }
    open var pan: Float { get { _mix.pan } set { _mix.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { _mix.renderingAlgorithm } set { _mix.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { _mix.sourceMode } set { _mix.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { _mix.pointSourceInHeadMode } set { _mix.pointSourceInHeadMode = newValue } }
    open var rate: Float { get { _mix.rate } set { _mix.rate = max(0.5, min(2, newValue)) } }
    open var reverbBlend: Float { get { _mix.reverbBlend } set { _mix.reverbBlend = max(0, min(1, newValue)) } }
    open var obstruction: Float { get { _mix.obstruction } set { _mix.obstruction = max(-100, min(0, newValue)) } }
    open var occlusion: Float { get { _mix.occlusion } set { _mix.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { _mix.position } set { _mix.position = newValue } }
    open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? {
        guard let e = engine, e._outputConnections(of: self, bus: 0).contains(where: { $0.dst === mixer && $0.dstBus == bus }) else { return nil }
        return AVAudioMixingDestination(_mix, AVAudioConnectionPoint(node: mixer, bus: bus))
    }
    struct Item {
        let buffer: AVAudioPCMBuffer
        let start: Int, count: Int                 // frames of the buffer
        let options: AVAudioPlayerNodeBufferOptions
        let at: AVAudioTime?
        let callbackType: AVAudioPlayerNodeCompletionCallbackType
        let completion: ((AVAudioPlayerNodeCompletionCallbackType) -> Void)?
    }
    var queue: [Item] = []
    var current: Item?
    var pos = 0                                    // in the current item
    var _playing = false
    var _startAt: Int64?                           // output sample time play(at:) waits for
    var _playerFrames: Int64 = 0                   // frames rendered while playing
    var _formatHint: AVAudioFormat?
    open var isPlaying: Bool { _playing }

    override var _naturalOutputFormat: AVAudioFormat { _formatHint ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)! }

    func _schedule(_ item: Item) {
        engine?._lock.lock(); defer { engine?._lock.unlock() }
        if _formatHint == nil { _formatHint = item.buffer.format }
        if item.options.contains(.interrupts) {
            if let cur = current { _complete(cur, nil) }
            for q in queue { _complete(q, nil) }
            current = nil; pos = 0; queue = [item]
        } else if item.options.contains(.interruptsAtLoop) {
            for q in queue { _complete(q, nil) }
            queue = [item]
            if let cur = current, cur.options.contains(.loops) { _stopLooping = true }
        } else { queue.append(item) }
    }
    var _stopLooping = false
    func _complete(_ item: Item, _ c: _Cycle?) {
        guard let f = item.completion else { return }
        let t = item.callbackType
        if let c, c.offline { f(t) } else if let c { c.completions.append { f(t) } } else { DispatchQueue.main.async { f(t) } }
    }

    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime? = nil, options: AVAudioPlayerNodeBufferOptions = [], completionHandler: (() -> Void)? = nil) {
        _schedule(Item(buffer: buffer, start: 0, count: Int(buffer.frameLength), options: options, at: when, callbackType: .dataConsumed,
                       completion: completionHandler.map { f in { _ in f() } }))
    }
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, completionHandler: (() -> Void)? = nil) {
        scheduleBuffer(buffer, at: nil, options: [], completionHandler: completionHandler)
    }
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, options: AVAudioPlayerNodeBufferOptions = [],
                             completionCallbackType callbackType: AVAudioPlayerNodeCompletionCallbackType,
                             completionHandler: ((AVAudioPlayerNodeCompletionCallbackType) -> Void)? = nil) {
        _schedule(Item(buffer: buffer, start: 0, count: Int(buffer.frameLength), options: options, at: when, callbackType: callbackType, completion: completionHandler))
    }
    open func scheduleFile(_ file: AVAudioFile, at when: AVAudioTime?, completionHandler: (() -> Void)? = nil) {
        scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(max(0, file.length)), at: when, completionHandler: completionHandler)
    }
    open func scheduleFile(_ file: AVAudioFile, at when: AVAudioTime?, completionCallbackType callbackType: AVAudioPlayerNodeCompletionCallbackType,
                           completionHandler: ((AVAudioPlayerNodeCompletionCallbackType) -> Void)? = nil) {
        scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(max(0, file.length)), at: when, completionCallbackType: callbackType,
                        completionHandler: completionHandler)
    }
    open func scheduleSegment(_ file: AVAudioFile, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount, at when: AVAudioTime?,
                              completionHandler: (() -> Void)? = nil) {
        scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: when, completionCallbackType: .dataConsumed,
                        completionHandler: completionHandler.map { f in { _ in f() } })
    }
    open func scheduleSegment(_ file: AVAudioFile, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount, at when: AVAudioTime?,
                              completionCallbackType callbackType: AVAudioPlayerNodeCompletionCallbackType,
                              completionHandler: ((AVAudioPlayerNodeCompletionCallbackType) -> Void)? = nil) {
        let start = max(0, min(startingFrame, file.length)), count = max(0, min(AVAudioFramePosition(frameCount), file.length - start))
        guard count > 0, let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(count)) else {
            if let f = completionHandler { DispatchQueue.main.async { f(callbackType) } }
            return
        }
        let saved = file.framePosition
        file.framePosition = start
        try? file.read(into: b, frameCount: AVAudioFrameCount(count))
        file.framePosition = saved
        _schedule(Item(buffer: b, start: 0, count: Int(b.frameLength), options: [], at: when, callbackType: callbackType, completion: completionHandler))
    }
    @discardableResult
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime? = nil, options: AVAudioPlayerNodeBufferOptions = [],
                             completionCallbackType callbackType: AVAudioPlayerNodeCompletionCallbackType) async -> AVAudioPlayerNodeCompletionCallbackType {
        await withCheckedContinuation { k in scheduleBuffer(buffer, at: when, options: options, completionCallbackType: callbackType) { k.resume(returning: $0) } }
    }
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime? = nil, options: AVAudioPlayerNodeBufferOptions = []) async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in scheduleBuffer(buffer, at: when, options: options) { k.resume() } }
    }
    @discardableResult
    open func scheduleFile(_ file: AVAudioFile, at when: AVAudioTime?, completionCallbackType callbackType: AVAudioPlayerNodeCompletionCallbackType) async -> AVAudioPlayerNodeCompletionCallbackType {
        await withCheckedContinuation { k in scheduleFile(file, at: when, completionCallbackType: callbackType) { k.resume(returning: $0) } }
    }
    open func scheduleFile(_ file: AVAudioFile, at when: AVAudioTime?) async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in scheduleFile(file, at: when) { k.resume() } }
    }
    open func prepare(withFrameCount frameCount: AVAudioFrameCount) {}

    open func play() {
        guard let e = engine, e.isRunning else { NSLog("isim AVFoundation: player started while the engine is not running"); return }
        e._lock.lock(); _playing = true; _startAt = nil; e._lock.unlock()
    }
    open func play(at when: AVAudioTime?) {
        guard let when, let e = engine, e.isRunning else { play(); return }
        e._lock.lock(); defer { e._lock.unlock() }
        _playing = true
        let rate = e._outputRate
        if when.isSampleTimeValid {
            _startAt = AVAudioFramePosition(Double(when.sampleTime) * rate / (when.sampleRate > 0 ? when.sampleRate : rate))
        } else if when.isHostTimeValid {
            let dt = (Double(when.hostTime) - Double(AVAudioTime.now())) / 1e9
            _startAt = e._sampleTime + Int64(max(0, dt) * rate)
        }
    }
    open func pause() { engine?._lock.lock(); _playing = false; engine?._lock.unlock() }
    open func stop() {
        engine?._lock.lock()
        let pendingItems = (current.map { [$0] } ?? []) + queue
        _playing = false; queue = []; current = nil; pos = 0; _startAt = nil; _playerFrames = 0
        engine?._lock.unlock()
        for i in pendingItems { _complete(i, nil) }
    }
    open override func reset() { stop() }
    /// the player's own timeline (frames played since play(), stopped while paused)
    open func playerTime(forNodeTime nodeTime: AVAudioTime) -> AVAudioTime? {
        guard _playing || _playerFrames > 0, let last = _lastRender, nodeTime.isSampleTimeValid else { return nil }
        let rate = _rate()
        let since = _playing ? Double(nodeTime.sampleTime - last.sampleTime) / max(1, last.sampleRate) * rate : 0
        return AVAudioTime(sampleTime: _playerFrames + AVAudioFramePosition(since.rounded()), atRate: rate)
    }
    open func nodeTime(forPlayerTime playerTime: AVAudioTime) -> AVAudioTime? {
        guard let last = _lastRender, playerTime.isSampleTimeValid else { return nil }
        let rate = _rate()
        let d = Double(playerTime.sampleTime - _playerFrames) / rate * last.sampleRate
        return AVAudioTime(sampleTime: last.sampleTime + AVAudioFramePosition(d.rounded()), atRate: last.sampleRate)
    }

    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let ch = Int(current?.buffer.format.channelCount ?? queue.first?.buffer.format.channelCount ?? outputFormat(forBus: 0).channelCount)
        var out = _IsimChannels.silence(max(1, ch), n)
        guard _playing else { return out }
        var filled = 0
        if let s = _startAt {
            let wait = Int(max(0, Double(s - c.sampleTime) * _rate() / c.rate))
            if wait >= n { return out }
            filled = wait; _startAt = nil
        }
        _playerFrames += Int64(n - filled)
        while filled < n {
            if current == nil {
                guard !queue.isEmpty else { break }
                current = queue.removeFirst(); pos = 0
            }
            let item = current!
            let take = min(n - filled, item.count - pos)
            if take > 0 {
                for k in 0..<out.count {
                    let src = item.buffer.channels[min(k, item.buffer.channels.count - 1)] + item.start + pos
                    out[k].withUnsafeMutableBufferPointer { $0.baseAddress!.advanced(by: filled).update(from: src, count: take) }
                }
                filled += take; pos += take
            }
            if pos >= item.count {
                if item.options.contains(.loops) && !_stopLooping && item.count > 0 && (queue.isEmpty || !item.options.contains(.interruptsAtLoop)) {
                    pos = 0
                    continue
                }
                _stopLooping = false
                current = nil; pos = 0
                _complete(item, c)
            }
        }
        return out
    }
}

/// A node whose audio comes from the app's render block.
public typealias AVAudioSourceNodeRenderBlock = (UnsafeMutablePointer<ObjCBool>, UnsafePointer<AudioTimeStamp>, AVAudioFrameCount, UnsafeMutablePointer<AudioBufferList>) -> OSStatus
open class AVAudioSourceNode: AVAudioNode, AVAudioMixing {
    let _mix = _MixSettings()
    open var volume: Float { get { _mix.volume } set { _mix.volume = max(0, newValue) } }
    open var pan: Float { get { _mix.pan } set { _mix.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { _mix.renderingAlgorithm } set { _mix.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { _mix.sourceMode } set { _mix.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { _mix.pointSourceInHeadMode } set { _mix.pointSourceInHeadMode = newValue } }
    open var rate: Float { get { _mix.rate } set { _mix.rate = max(0.5, min(2, newValue)) } }
    open var reverbBlend: Float { get { _mix.reverbBlend } set { _mix.reverbBlend = max(0, min(1, newValue)) } }
    open var obstruction: Float { get { _mix.obstruction } set { _mix.obstruction = max(-100, min(0, newValue)) } }
    open var occlusion: Float { get { _mix.occlusion } set { _mix.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { _mix.position } set { _mix.position = newValue } }
    open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? {
        guard let e = engine, e._outputConnections(of: self, bus: 0).contains(where: { $0.dst === mixer && $0.dstBus == bus }) else { return nil }
        return AVAudioMixingDestination(_mix, AVAudioConnectionPoint(node: mixer, bus: bus))
    }
    let block: AVAudioSourceNodeRenderBlock
    let format: AVAudioFormat?
    public init(renderBlock block: @escaping AVAudioSourceNodeRenderBlock) { self.block = block; format = nil }
    public init(format: AVAudioFormat, renderBlock block: @escaping AVAudioSourceNodeRenderBlock) { self.block = block; self.format = format }
    open override var numberOfInputs: Int { 0 }
    override var _naturalOutputFormat: AVAudioFormat { format ?? engine?.outputNode.outputFormat(forBus: 0) ?? _defaultFormat }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let f = outputFormat(forBus: 0)
        let ch = Int(f.channelCount)
        let list = AudioBufferList.allocate(maximumBuffers: ch)
        defer { for b in list { free(b.mData) }; free(list.unsafeMutablePointer) }
        for k in 0..<ch { list[k] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(n * 4), mData: calloc(n, 4)) }
        var silence = ObjCBool(false)
        var ts = AudioTimeStamp()
        ts.mSampleTime = Double(c.sampleTime) * f.sampleRate / c.rate; ts.mHostTime = AVAudioTime.now(); ts.mRateScalar = 1
        ts.mFlags = [.sampleTimeValid, .hostTimeValid]
        let st = block(&silence, &ts, AVAudioFrameCount(n), list.unsafeMutablePointer)
        guard st == 0, !silence.boolValue else { return _IsimChannels.silence(ch, n) }
        return (0..<ch).map { k in
            let p = list[k].mData!.assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: p, count: n))
        }
    }
}

/// A node that hands its input to the app's block (connected from the input node).
public typealias AVAudioSinkNodeReceiverBlock = (UnsafePointer<AudioTimeStamp>, AVAudioFrameCount, UnsafePointer<AudioBufferList>) -> OSStatus
open class AVAudioSinkNode: AVAudioNode {
    let block: AVAudioSinkNodeReceiverBlock
    public init(receiverBlock block: @escaping AVAudioSinkNodeReceiverBlock) { self.block = block }
    open override var numberOfOutputs: Int { 0 }
    func _consume(_ n: Int, _ c: _Cycle) {
        guard let x = _input(0, n, c) else { return }
        let ch = x.count
        let list = AudioBufferList.allocate(maximumBuffers: max(1, ch))
        defer { free(list.unsafeMutablePointer) }
        var copies = x
        var ts = AudioTimeStamp()
        ts.mSampleTime = Double(c.sampleTime); ts.mHostTime = AVAudioTime.now(); ts.mRateScalar = 1; ts.mFlags = [.sampleTimeValid, .hostTimeValid]
        func call(_ k: Int) {
            if k == ch { _ = block(&ts, AVAudioFrameCount(n), list.unsafePointer); return }
            copies[k].withUnsafeMutableBufferPointer { p in
                list[k] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(n * 4), mData: UnsafeMutableRawPointer(p.baseAddress))
                call(k + 1)
            }
        }
        call(0)
    }
}

/// The microphone (isim: ISIM_AUDIO_INPUT, see AudioToolbox's _IsimAudioInput): 48 kHz mono; in manual rendering, the
/// input block given to setManualRenderingInputPCMFormat.
open class AVAudioInputNode: AVAudioIONode, AVAudioMixing {
    let _mix = _MixSettings()
    var fifo: _IsimInputFIFO?
    var _manualBlock: AVAudioIONodeInputBlock?
    var _manualFormat: AVAudioFormat?
    open var volume: Float { get { _mix.volume } set { _mix.volume = max(0, newValue) } }
    open var pan: Float { get { _mix.pan } set { _mix.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { _mix.renderingAlgorithm } set { _mix.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { _mix.sourceMode } set { _mix.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { _mix.pointSourceInHeadMode } set { _mix.pointSourceInHeadMode = newValue } }
    open var rate: Float { get { _mix.rate } set { _mix.rate = max(0.5, min(2, newValue)) } }
    open var reverbBlend: Float { get { _mix.reverbBlend } set { _mix.reverbBlend = max(0, min(1, newValue)) } }
    open var obstruction: Float { get { _mix.obstruction } set { _mix.obstruction = max(-100, min(0, newValue)) } }
    open var occlusion: Float { get { _mix.occlusion } set { _mix.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { _mix.position } set { _mix.position = newValue } }
    open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? {
        guard let e = engine, e._outputConnections(of: self, bus: 0).contains(where: { $0.dst === mixer && $0.dstBus == bus }) else { return nil }
        return AVAudioMixingDestination(_mix, AVAudioConnectionPoint(node: mixer, bus: bus))
    }
    open var isVoiceProcessingBypassed = false
    open var isVoiceProcessingAGCEnabled = true
    open var isVoiceProcessingInputMuted = false
    open override var numberOfInputs: Int { 0 }
    open override func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        _manualFormat ?? AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    }
    open override func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat { outputFormat(forBus: bus) }
    open func setManualRenderingInputPCMFormat(_ format: AVAudioFormat, inputBlock block: @escaping AVAudioIONodeInputBlock) -> Bool {
        guard engine?._manual != nil else { return false }
        _manualFormat = format; _manualBlock = block
        return true
    }
    func _startCapture() { if fifo == nil { let f = _IsimInputFIFO(); f.start(); fifo = f } }
    func _stopCapture() { fifo?.stop(); fifo = nil }
    var _inUse: Bool { _tap != nil || !(engine?._outputConnections(of: self, bus: 0).isEmpty ?? true) }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let ch = Int(outputFormat(forBus: 0).channelCount)
        if c.offline {
            guard let block = _manualBlock, let p = block(AVAudioFrameCount(n)) else { return _IsimChannels.silence(ch, n) }
            let f = outputFormat(forBus: 0)
            var d = AudioStreamBasicDescription(mSampleRate: f.sampleRate, mFormatID: kAudioFormatLinearPCM,
                                                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
                                                mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: UInt32(ch), mBitsPerChannel: 32, mReserved: 0)
            if f.commonFormat == .pcmFormatInt16 { d.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | (f.isInterleaved ? 0 : kAudioFormatFlagIsNonInterleaved); d.mBitsPerChannel = 16; d.mBytesPerFrame = f.isInterleaved ? UInt32(2 * ch) : 2; d.mBytesPerPacket = d.mBytesPerFrame }
            return _IsimChannels.adapt(_IsimPCM.read(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: p)), d, frames: n), to: ch, frames: n)
        }
        guard let fifo, !isVoiceProcessingInputMuted else { return _IsimChannels.silence(ch, n) }
        let x = fifo.pop(n)
        var m = [Float](repeating: 0, count: n)
        for i in 0..<n { m[i] = (x[0][i] + x[1][i]) * 0.5 }
        return _IsimChannels.adapt([m], to: ch, frames: n)
    }
}
public typealias AVAudioIONodeInputBlock = (AVAudioFrameCount) -> UnsafePointer<AudioBufferList>?

// MARK: - environment (3D)

public enum AVAudioEnvironmentDistanceAttenuationModel: Int, Sendable { case exponential = 1, inverse = 2, linear = 3 }
open class AVAudioEnvironmentDistanceAttenuationParameters: NSObject {
    open var distanceAttenuationModel: AVAudioEnvironmentDistanceAttenuationModel = .inverse
    open var referenceDistance: Float = 1
    open var maximumDistance: Float = 100000
    open var rolloffFactor: Float = 1
    func gain(_ d: Float) -> Float {
        let ref = max(0.001, referenceDistance), mx = max(ref, maximumDistance), dist = min(max(d, ref), mx)
        switch distanceAttenuationModel {
        case .inverse: return ref / (ref + rolloffFactor * (dist - ref))
        case .linear: return mx > ref ? max(0, 1 - rolloffFactor * (dist - ref) / (mx - ref)) : 1
        case .exponential: return Float(pow(Double(dist / ref), Double(-rolloffFactor)))
        }
    }
}
open class AVAudioEnvironmentReverbParameters: NSObject {
    open var enable = false
    /// dB
    open var level: Float = 0
    public let filterParameters = AVAudioUnitEQFilterParameters()
    var _preset: AVAudioUnitReverbPreset = .mediumHall
    open func loadFactoryReverbPreset(_ preset: AVAudioUnitReverbPreset) { _preset = preset }
}
public enum AVAudioEnvironmentOutputType: Int, Sendable { case auto = 0, headphones = 1, builtInSpeakers = 2, externalSpeakers = 3 }

/// Spatializes its inputs around a listener (adapted: equal-power panning by azimuth, distance attenuation).
open class AVAudioEnvironmentNode: AVAudioNode, AVAudioMixing {
    let _mix = _MixSettings()
    open var outputVolume: Float = 1
    open var outputType: AVAudioEnvironmentOutputType = .auto
    open var listenerPosition = AVAudio3DPoint()
    open var listenerAngularOrientation = AVAudio3DAngularOrientation()
    open var listenerVectorOrientation: AVAudio3DVectorOrientation {
        get {
            let y = Double(listenerAngularOrientation.yaw) * .pi / 180
            return AVAudio3DVectorOrientation(forward: AVAudio3DPoint(x: Float(sin(y)), y: 0, z: Float(-cos(y))), up: AVAudio3DPoint(x: 0, y: 1, z: 0))
        }
        set {
            let f = newValue.forward
            listenerAngularOrientation.yaw = Float(atan2(Double(f.x), Double(-f.z)) * 180 / .pi)
        }
    }
    public let distanceAttenuationParameters = AVAudioEnvironmentDistanceAttenuationParameters()
    public let reverbParameters = AVAudioEnvironmentReverbParameters()
    open var applicableRenderingAlgorithms: [NSNumber] { [NSNumber(value: 0), NSNumber(value: 1), NSNumber(value: 2), NSNumber(value: 5), NSNumber(value: 7)] }
    open var isListenerHeadTrackingEnabled = false
    open var nextAvailableInputBus: AVAudioNodeBus { engine?._nextInputBus(self) ?? 0 }
    let reverb = _IsimReverbKernel()
    var _resamplers: [Int: _IsimResampler] = [:]
    open var volume: Float { get { _mix.volume } set { _mix.volume = max(0, newValue) } }
    open var pan: Float { get { _mix.pan } set { _mix.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { _mix.renderingAlgorithm } set { _mix.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { _mix.sourceMode } set { _mix.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { _mix.pointSourceInHeadMode } set { _mix.pointSourceInHeadMode = newValue } }
    open var rate: Float { get { _mix.rate } set { _mix.rate = max(0.5, min(2, newValue)) } }
    open var reverbBlend: Float { get { _mix.reverbBlend } set { _mix.reverbBlend = max(0, min(1, newValue)) } }
    open var obstruction: Float { get { _mix.obstruction } set { _mix.obstruction = max(-100, min(0, newValue)) } }
    open var occlusion: Float { get { _mix.occlusion } set { _mix.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { _mix.position } set { _mix.position = newValue } }
    open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? { nil }
    open override var numberOfInputs: Int { max(1, nextAvailableInputBus) }

    /// gain and pan of a source at `p` (listener frame: -z ahead, +x right)
    func spatial(_ p: AVAudio3DPoint) -> (gain: Float, pan: Float) {
        var dx = Double(p.x - listenerPosition.x), dz = Double(p.z - listenerPosition.z)
        let dy = Double(p.y - listenerPosition.y)
        let yaw = Double(listenerAngularOrientation.yaw) * .pi / 180
        (dx, dz) = (dx * cos(yaw) + dz * sin(yaw), -dx * sin(yaw) + dz * cos(yaw))
        let d = (dx * dx + dy * dy + dz * dz).squareRoot()
        let az = d > 1e-6 ? atan2(dx, -dz) : 0
        return (distanceAttenuationParameters.gain(Float(d)), Float(sin(az)))
    }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let rate = _rate()
        var out = _IsimChannels.silence(Int(outputFormat(forBus: 0).channelCount), n)
        var send = _IsimChannels.silence(out.count, n)
        guard let e = engine else { return out }
        for conn in e._inputConnections(of: self) {
            guard let src = conn.src else { continue }
            let s = _mixSettings(src) ?? _MixSettings()
            let srcRate = src._rate() * Double(s.rate)
            var x: [[Float]]
            if abs(srcRate - rate) > 1e-6 {
                let rs = _resamplers[conn.dstBus] ?? _IsimResampler()
                _resamplers[conn.dstBus] = rs
                x = rs.render(n, step: srcRate / rate) { src._pull($0, c) }
            } else { x = src._pull(n, c) }
            let spatialize = s.sourceMode != .bypass && s.renderingAlgorithm != .stereoPassThrough && (x.count == 1 || s.sourceMode == .pointSource)
            if !spatialize { _IsimChannels.mix(x, into: &out, gain: s.volume, pan: s.pan); continue }
            let mono = _IsimChannels.adapt(x, to: 1, frames: n)
            let (g, p) = spatial(s.position)
            let direct = g * Float(pow(10, Double(s.obstruction + s.occlusion) / 20)) * s.volume
            _IsimChannels.mix(mono, into: &out, gain: direct, pan: p)
            if reverbParameters.enable && s.reverbBlend > 0 {
                _IsimChannels.mix(mono, into: &send, gain: g * Float(pow(10, Double(s.occlusion) / 20)) * s.volume * s.reverbBlend)
            }
        }
        if reverbParameters.enable {
            reverb.wetDryMix = 100
            reverb.room = 0.86
            reverb.gain = reverbParameters.level
            reverb.process(&send, rate: rate)
            for k in 0..<out.count { for i in 0..<n { out[k][i] += send[k][i] } }
        }
        if outputVolume != 1 { for k in 0..<out.count { for i in 0..<n { out[k][i] *= outputVolume } } }
        return out
    }
    open override func reset() { _resamplers = [:]; reverb.reset() }
}

// MARK: - Audio Unit nodes

open class AVAudioUnit: AVAudioNode {
    let _unit: _IsimAudioUnit?
    init(_unit u: _IsimAudioUnit?) { _unit = u; super.init() }
    public override init() { _unit = nil; super.init() }
    open var name: String { String(describing: type(of: self)) }
    open var manufacturerName: String { "Apple" }
    open var version: Int { 1 }
    /// the underlying Audio Unit (AudioUnitSetParameter and friends work on it)
    open var audioUnit: AudioUnit { _unit!.handle }
    open var audioComponentDescription: AudioComponentDescription {
        var d = AudioComponentDescription()
        if let u = _unit { d.componentType = u.type; d.componentSubType = u.subType; d.componentManufacturer = kAudioUnitManufacturer_Apple }
        return d
    }
    /// Apple's audio unit components (see AudioToolbox's AudioUnits.swift); others fail with kAudioUnitErr_FailedInitialization
    open class func instantiate(with audioComponentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = [],
                                completionHandler: @escaping (AVAudioUnit?, Error?) -> Void) {
        let d = audioComponentDescription
        let node: AVAudioUnit? = _IsimAudioUnit.make(type: d.componentType, subType: d.componentSubType).map {
            d.componentType == kAudioUnitType_Effect || d.componentType == kAudioUnitType_FormatConverter ? AVAudioUnitEffect(_unit: $0) : AVAudioUnit(_unit: $0)
        }
        DispatchQueue.main.async {
            completionHandler(node, node == nil ? NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization)) : nil)
        }
    }
    open class func instantiate(with audioComponentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) async throws -> AVAudioUnit {
        try await withCheckedThrowingContinuation { k in
            instantiate(with: audioComponentDescription, options: options) { u, e in if let u { k.resume(returning: u) } else { k.resume(throwing: e!) } }
        }
    }
    func _param(_ id: AudioUnitParameterID, _ element: AudioUnitElement = 0) -> Float { _unit?.parameter(id, element: element) ?? 0 }
    func _setParam(_ id: AudioUnitParameterID, _ v: Float, _ element: AudioUnitElement = 0) { _unit?.setParameter(id, v, element: element) }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let up: (Int) -> [[Float]] = { k in self._input(0, k, c) ?? _IsimChannels.silence(Int(self.inputFormat(forBus: 0).channelCount), k) }
        guard let u = _unit, let k = u.kernel else { return up(n) }
        u.applyParameters()
        return k.render(n, rate: _rate(), pull: up)
    }
    /// effects run at their input's rate
    override func _rate() -> Double {
        if let e = engine, let conn = e._inputConnection(of: self, bus: 0), let src = conn.src { return conn.format?.sampleRate ?? src._rate() }
        return outputFormat(forBus: 0).sampleRate
    }
    override var _naturalOutputFormat: AVAudioFormat {
        if let e = engine, let conn = e._inputConnection(of: self, bus: 0), let src = conn.src { return conn.format ?? src.outputFormat(forBus: conn.srcBus) }
        return _defaultFormat
    }
    open override func reset() { _unit?.kernel?.reset() }
}

open class AVAudioUnitEffect: AVAudioUnit {
    public init(audioComponentDescription: AudioComponentDescription) {
        super.init(_unit: _IsimAudioUnit.make(type: audioComponentDescription.componentType, subType: audioComponentDescription.componentSubType))
    }
    override init(_unit u: _IsimAudioUnit?) { super.init(_unit: u) }
    public override init() { super.init() }
    open var bypass: Bool { get { _unit?.bypass ?? _bypass } set { _unit?.bypass = newValue; _bypass = newValue } }
    var _bypass = false
}

public enum AVAudioUnitReverbPreset: Int, Sendable {
    case smallRoom = 0, mediumRoom, largeRoom, mediumHall, largeHall, plate, mediumChamber, largeChamber, cathedral, largeRoom2, mediumHall2, mediumHall3, largeHall2
}
/// Reverb (AUReverb2; adapted: Freeverb-style).
open class AVAudioUnitReverb: AVAudioUnitEffect {
    public override init() { super.init(_unit: _IsimAudioUnit.make(type: kAudioUnitType_Effect, subType: kAudioUnitSubType_Reverb2)) }
    open var wetDryMix: Float { get { _param(kReverb2Param_DryWetMix) } set { _setParam(kReverb2Param_DryWetMix, max(0, min(100, newValue))) } }
    open func loadFactoryPreset(_ p: AVAudioUnitReverbPreset) {
        let decay: [Float] = [0.4, 0.8, 1.2, 1.8, 2.5, 1.6, 1.0, 1.5, 6.0, 1.4, 2.0, 2.2, 3.0]
        let d = decay[p.rawValue]
        _setParam(kReverb2Param_DecayTimeAt0Hz, d)
        _setParam(kReverb2Param_DecayTimeAtNyquist, d * (p == .plate ? 0.8 : p.rawValue <= 2 ? 0.4 : 0.6))
    }
}

public enum AVAudioUnitEQFilterType: Int, Sendable {
    case parametric = 0, lowPass, highPass, resonantLowPass, resonantHighPass, bandPass, bandStop, lowShelf, highShelf, resonantLowShelf, resonantHighShelf
}
open class AVAudioUnitEQFilterParameters: NSObject {
    weak var _owner: AVAudioUnitEQ?
    var _index: UInt32 = 0
    var _local = _IsimEQBand()
    public override init() {}
    init(index: Int) { _index = UInt32(index) }
    func _get(_ base: AudioUnitParameterID) -> Float? { _owner.map { $0._param(base + _index) } }
    func _set(_ base: AudioUnitParameterID, _ v: Float) { _owner?._setParam(base + _index, v) }
    open var filterType: AVAudioUnitEQFilterType {
        get { AVAudioUnitEQFilterType(rawValue: Int(_get(kAUNBandEQParam_FilterType) ?? Float(_local.type))) ?? .parametric }
        set { _local.type = newValue.rawValue; _set(kAUNBandEQParam_FilterType, Float(newValue.rawValue)) }
    }
    open var frequency: Float { get { _get(kAUNBandEQParam_Frequency) ?? _local.frequency } set { _local.frequency = newValue; _set(kAUNBandEQParam_Frequency, newValue) } }
    /// octaves
    open var bandwidth: Float { get { _get(kAUNBandEQParam_Bandwidth) ?? _local.bandwidth } set { _local.bandwidth = newValue; _set(kAUNBandEQParam_Bandwidth, newValue) } }
    /// dB
    open var gain: Float { get { _get(kAUNBandEQParam_Gain) ?? _local.gain } set { _local.gain = newValue; _set(kAUNBandEQParam_Gain, newValue) } }
    /// bands start bypassed, like AUNBandEQ
    open var bypass: Bool { get { (_get(kAUNBandEQParam_BypassBand) ?? (_local.bypass ? 1 : 0)) != 0 } set { _local.bypass = newValue; _set(kAUNBandEQParam_BypassBand, newValue ? 1 : 0) } }
}
/// N-band equalizer (AUNBandEQ; adapted: RBJ biquads).
open class AVAudioUnitEQ: AVAudioUnitEffect {
    public let bands: [AVAudioUnitEQFilterParameters]
    open var globalGain: Float { get { _param(kAUNBandEQParam_GlobalGain) } set { _setParam(kAUNBandEQParam_GlobalGain, newValue) } }
    public init(numberOfBands: Int) {
        let u = _IsimAudioUnit.make(type: kAudioUnitType_Effect, subType: kAudioUnitSubType_NBandEQ)!
        var n = UInt32(max(1, min(16, numberOfBands)))
        _ = AudioUnitSetProperty(u.handle, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &n, 4)
        bands = (0..<max(0, numberOfBands)).map { AVAudioUnitEQFilterParameters(index: $0) }
        super.init(_unit: u)
        for b in bands { b._owner = self }
    }
    public override convenience init() { self.init(numberOfBands: 1) }
}

/// Rate change by resampling, pitch follows (AUVarispeed).
open class AVAudioUnitVarispeed: AVAudioUnitEffect {
    public override init() { super.init(_unit: _IsimAudioUnit.make(type: kAudioUnitType_FormatConverter, subType: kAudioUnitSubType_Varispeed)) }
    open var rate: Float { get { _param(kVarispeedParam_PlaybackRate) } set { _setParam(kVarispeedParam_PlaybackRate, max(0.25, min(4, newValue))) } }
}
/// Rate without pitch change and pitch without rate change (AUNewTimePitch; adapted: WSOLA time stretch + resampling).
open class AVAudioUnitTimePitch: AVAudioUnitEffect {
    public override init() { super.init(_unit: _IsimAudioUnit.make(type: kAudioUnitType_FormatConverter, subType: kAudioUnitSubType_NewTimePitch)) }
    open var rate: Float { get { _param(kNewTimePitchParam_Rate) } set { _setParam(kNewTimePitchParam_Rate, max(1.0 / 32, min(32, newValue))) } }
    /// cents
    open var pitch: Float { get { _param(kNewTimePitchParam_Pitch) } set { _setParam(kNewTimePitchParam_Pitch, max(-2400, min(2400, newValue))) } }
    open var overlap: Float { get { _param(kNewTimePitchParam_Overlap) } set { _setParam(kNewTimePitchParam_Overlap, max(3, min(32, newValue))) } }
}
open class AVAudioUnitDelay: AVAudioUnitEffect {
    public override init() {
        super.init(_unit: _IsimAudioUnit.make(type: kAudioUnitType_Effect, subType: kAudioUnitSubType_Delay))
        wetDryMix = 100
    }
    open var delayTime: TimeInterval { get { TimeInterval(_param(kDelayParam_DelayTime)) } set { _setParam(kDelayParam_DelayTime, Float(max(0, min(2, newValue)))) } }
    open var feedback: Float { get { _param(kDelayParam_Feedback) } set { _setParam(kDelayParam_Feedback, max(-100, min(100, newValue))) } }
    open var lowPassCutoff: Float { get { _param(kDelayParam_LopassCutoff) } set { _setParam(kDelayParam_LopassCutoff, max(10, newValue)) } }
    open var wetDryMix: Float { get { _param(kDelayParam_WetDryMix) } set { _setParam(kDelayParam_WetDryMix, max(0, min(100, newValue))) } }
}
public enum AVAudioUnitDistortionPreset: Int, Sendable {
    case drumsBitBrush = 0, drumsBufferBeats, drumsLoFi, multiBrokenSpeaker, multiCellphoneConcert, multiDecimated1, multiDecimated2,
         multiDecimated3, multiDecimated4, multiDistortedFunk, multiDistortedCubed, multiDistortedSquared, multiEcho1, multiEcho2,
         multiEchoTight1, multiEchoTight2, multiEverythingIsBroken, speechAlienChatter, speechCosmicInterference, speechGoldenPi,
         speechRadioTower, speechWaves
}
/// Soft-clipping overdrive (every preset maps to a drive amount).
open class AVAudioUnitDistortion: AVAudioUnitEffect {
    public override init() { super.init(_unit: _IsimAudioUnit.make(type: kAudioUnitType_Effect, subType: kAudioUnitSubType_Distortion)) }
    open var preGain: Float { get { _param(kDistortionParam_SoftClipGain) } set { _setParam(kDistortionParam_SoftClipGain, max(-80, min(20, newValue))) } }
    open var wetDryMix: Float { get { _param(kDistortionParam_FinalMix) } set { _setParam(kDistortionParam_FinalMix, max(0, min(100, newValue))) } }
    open func loadFactoryPreset(_ p: AVAudioUnitDistortionPreset) { _setParam(0x7FFF_0001, 4 + Float(p.rawValue % 6) * 4) }
}

// MARK: - engine

struct _Conn {
    weak var src: AVAudioNode?
    let srcBus: AVAudioNodeBus
    weak var dst: AVAudioNode?
    let dstBus: AVAudioNodeBus
    let format: AVAudioFormat?
}

open class AVAudioEngine: NSObject {
    public let outputNode = AVAudioOutputNode()
    var _mainMixer: AVAudioMixerNode?
    var nodes: [AVAudioNode] = []
    var _conns: [_Conn] = []
    var _manual: _ManualRendering?
    var _inputNode: AVAudioInputNode?
    let _lock = NSRecursiveLock()
    var _driver: _IsimAudioOutput?
    var _sampleTime: Int64 = 0
    var _outputRate: Double { _manual?.format.sampleRate ?? 48000 }
    public static let configurationChangeNotification = Notification.Name("AVAudioEngineConfigurationChangeNotification")
    /// accessing the main mixer connects it to the output node (like iOS)
    public final var mainMixerNode: AVAudioMixerNode {
        _lock.lock(); defer { _lock.unlock() }
        if let m = _mainMixer { return m }
        let m = AVAudioMixerNode()
        m.engine = self
        _mainMixer = m
        if _inputConnection(of: outputNode, bus: 0) == nil { _conns.append(_Conn(src: m, srcBus: 0, dst: outputNode, dstBus: 0, format: nil)) }
        return m
    }
    /// The microphone (isim: ISIM_AUDIO_INPUT).
    open var inputNode: AVAudioInputNode {
        if let n = _inputNode { return n }
        let n = AVAudioInputNode(); n.engine = self; _inputNode = n
        return n
    }
    open private(set) var isRunning = false
    open var isAutoShutdownEnabled = false
    public override init() {
        super.init()
        outputNode.engine = self
        _AVSessionPrefs.installMicrophonePrompt()
    }
    open var attachedNodes: Set<AVAudioNode> {
        var s = Set(nodes)
        s.insert(outputNode); s.insert(mainMixerNode)
        if let i = _inputNode { s.insert(i) }
        return s
    }
    open func attach(_ node: AVAudioNode) {
        _lock.lock(); defer { _lock.unlock() }
        node.engine = self
        if !nodes.contains(node) { nodes.append(node) }
    }
    open func detach(_ node: AVAudioNode) {
        (node as? AVAudioPlayerNode)?.stop()
        _lock.lock(); defer { _lock.unlock() }
        _conns.removeAll { $0.src === node || $0.dst === node }
        nodes.removeAll { $0 === node }
    }
    func _owned(_ n: AVAudioNode) {
        if n.engine !== self { n.engine = self }
        if n !== outputNode && n !== _mainMixer && n !== _inputNode && !nodes.contains(n) { nodes.append(n) }
    }
    open func connect(_ a: AVAudioNode, to b: AVAudioNode, format: AVAudioFormat?) {
        let bus = (b is AVAudioMixerNode || b is AVAudioEnvironmentNode) ? _nextInputBus(b) : 0
        connect(a, to: b, fromBus: 0, toBus: bus, format: format)
    }
    open func connect(_ a: AVAudioNode, to b: AVAudioNode, fromBus: AVAudioNodeBus, toBus: AVAudioNodeBus, format: AVAudioFormat?) {
        _lock.lock(); defer { _lock.unlock() }
        if a === _mainMixer || b === _mainMixer { _ = mainMixerNode }
        _owned(a); _owned(b)
        _conns.removeAll { ($0.src === a && $0.srcBus == fromBus) || ($0.dst === b && $0.dstBus == toBus) || $0.src == nil || $0.dst == nil }
        _conns.append(_Conn(src: a, srcBus: fromBus, dst: b, dstBus: toBus, format: format))
    }
    open func connect(_ sourceNode: AVAudioNode, to destNodes: [AVAudioConnectionPoint], fromBus sourceBus: AVAudioNodeBus, format: AVAudioFormat?) {
        _lock.lock(); defer { _lock.unlock() }
        _owned(sourceNode)
        _conns.removeAll { $0.src === sourceNode && $0.srcBus == sourceBus }
        for p in destNodes {
            guard let d = p.node else { continue }
            _owned(d)
            _conns.removeAll { $0.dst === d && $0.dstBus == p.bus }
            _conns.append(_Conn(src: sourceNode, srcBus: sourceBus, dst: d, dstBus: p.bus, format: format))
        }
    }
    open func disconnectNodeOutput(_ node: AVAudioNode) { _lock.lock(); _conns.removeAll { $0.src === node }; _lock.unlock() }
    open func disconnectNodeOutput(_ node: AVAudioNode, bus: AVAudioNodeBus) { _lock.lock(); _conns.removeAll { $0.src === node && $0.srcBus == bus }; _lock.unlock() }
    open func disconnectNodeInput(_ node: AVAudioNode) { _lock.lock(); _conns.removeAll { $0.dst === node }; _lock.unlock() }
    open func disconnectNodeInput(_ node: AVAudioNode, bus: AVAudioNodeBus) { _lock.lock(); _conns.removeAll { $0.dst === node && $0.dstBus == bus }; _lock.unlock() }
    open func outputConnectionPoints(for node: AVAudioNode, outputBus bus: AVAudioNodeBus) -> [AVAudioConnectionPoint] {
        _outputConnections(of: node, bus: bus).compactMap { c in c.dst.map { AVAudioConnectionPoint(node: $0, bus: c.dstBus) } }
    }
    open func inputConnectionPoint(for node: AVAudioNode, inputBus bus: AVAudioNodeBus) -> AVAudioConnectionPoint? {
        _inputConnection(of: node, bus: bus).flatMap { c in c.src.map { AVAudioConnectionPoint(node: $0, bus: c.srcBus) } }
    }
    func _outputConnections(of n: AVAudioNode, bus: AVAudioNodeBus) -> [_Conn] {
        _lock.lock(); defer { _lock.unlock() }
        return _conns.filter { $0.src === n && $0.srcBus == bus && $0.dst != nil }
    }
    func _inputConnection(of n: AVAudioNode, bus: AVAudioNodeBus) -> _Conn? {
        _lock.lock(); defer { _lock.unlock() }
        return _conns.first { $0.dst === n && $0.dstBus == bus && $0.src != nil }
    }
    func _inputConnections(of n: AVAudioNode) -> [_Conn] {
        _lock.lock(); defer { _lock.unlock() }
        return _conns.filter { $0.dst === n && $0.src != nil }.sorted { $0.dstBus < $1.dstBus }
    }
    func _nextInputBus(_ n: AVAudioNode) -> AVAudioNodeBus {
        _lock.lock(); defer { _lock.unlock() }
        let used = Set(_conns.filter { $0.dst === n }.map { $0.dstBus })
        var b = 0
        while used.contains(b) { b += 1 }
        return b
    }

    open func prepare() { _ = mainMixerNode }
    open func start() throws {
        _ = mainMixerNode
        _lock.lock()
        isRunning = true
        let manual = _manual != nil
        _lock.unlock()
        if manual { return }
        if let i = _inputNode, i._inUse { i._startCapture() }
        if _driver == nil {
            let d = _IsimAudioOutput { [weak self] n, t in self?._renderRealtime(n, t) ?? [] }
            d.framesPerSlice = max(64, min(4096, Int((_IsimSessionIO.ioBufferDuration * 48000).rounded())))
            _driver = d
        }
        _driver?.start()
    }
    open func pause() {
        _driver?.stop()
        _lock.lock(); isRunning = false; _lock.unlock()
        for case let p as AVAudioPlayerNode in nodes { p.pause() }
    }
    open func stop() {
        _driver?.stop()
        _lock.lock(); isRunning = false; _lock.unlock()
        for case let p as AVAudioPlayerNode in nodes { p.stop() }
        _inputNode?._stopCapture()
    }
    open func reset() { _lock.lock(); defer { _lock.unlock() }; for n in nodes { n.reset() }; _mainMixer?.reset() }
    func volumesChanged() {}

    /// one real-time slice: the output node's input at 48 kHz stereo, plus nodes rendered for their taps and sinks
    func _renderRealtime(_ n: Int, _ t: Int64) -> [[Float]] {
        let c = _Cycle(frames: n, sampleTime: t, rate: 48000, offline: false)
        _lock.lock()
        _sampleTime = t
        let x = _IsimChannels.adapt(outputNode._pull(n, c), to: 2, frames: n)
        _renderSideNodes(n, c)
        _lock.unlock()
        if !c.completions.isEmpty {
            let done = c.completions
            DispatchQueue.main.async { for f in done { f() } }
        }
        return x
    }
    /// nodes outside the output path that still render: tapped or connected input, sinks
    func _renderSideNodes(_ n: Int, _ c: _Cycle) {
        for case let s as AVAudioSinkNode in nodes { s._consume(n, c) }
        if let i = _inputNode, i._tap != nil, !c.rendered.contains(ObjectIdentifier(i)) {
            _ = i._pull(Int((Double(n) * i._rate() / c.rate).rounded()), c)
        }
    }
}

// MARK: - manual rendering

public enum AVAudioEngineManualRenderingMode: Int, Sendable { case offline = 0, realtime }
public enum AVAudioEngineManualRenderingStatus: Int, Sendable { case error = -1, success = 0, insufficientDataFromInputNode = 1, cannotDoInCurrentContext = 2 }
public enum AVAudioEngineManualRenderingError: Int, Error, Sendable { case invalidMode = -80800, initialized = -80801, notRunning = -80802 }
public typealias AVAudioEngineManualRenderingBlock = (AVAudioFrameCount, UnsafeMutablePointer<AudioBufferList>, UnsafeMutablePointer<OSStatus>?) -> AVAudioEngineManualRenderingStatus

final class _ManualRendering {
    let mode: AVAudioEngineManualRenderingMode, format: AVAudioFormat, maxFrames: AVAudioFrameCount
    var sampleTime: AVAudioFramePosition = 0
    init(mode: AVAudioEngineManualRenderingMode, format: AVAudioFormat, maxFrames: AVAudioFrameCount) { self.mode = mode; self.format = format; self.maxFrames = maxFrames }
}

extension AVAudioEngine {
    /// Manual rendering: the app pulls the graph into its buffers instead of the speaker.
    public func enableManualRenderingMode(_ mode: AVAudioEngineManualRenderingMode, format pcmFormat: AVAudioFormat, maximumFrameCount: AVAudioFrameCount) throws {
        if isRunning { throw AVAudioEngineManualRenderingError.initialized }
        _manual = _ManualRendering(mode: mode, format: pcmFormat, maxFrames: maximumFrameCount)
    }
    public func disableManualRenderingMode() { _manual = nil }
    public var isInManualRenderingMode: Bool { _manual != nil }
    public var manualRenderingMode: AVAudioEngineManualRenderingMode { _manual?.mode ?? .offline }
    public var manualRenderingFormat: AVAudioFormat { _manual?.format ?? AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)! }
    public var manualRenderingMaximumFrameCount: AVAudioFrameCount { _manual?.maxFrames ?? 0 }
    public var manualRenderingSampleTime: AVAudioFramePosition { _manual?.sampleTime ?? 0 }

    /// renders `n` frames of the graph (the main mixer's output) at the manual rendering format
    func _renderManual(_ n: Int) -> [[Float]]? {
        guard let m = _manual else { return nil }
        let c = _Cycle(frames: n, sampleTime: m.sampleTime, rate: m.format.sampleRate, offline: true)
        _lock.lock(); defer { _lock.unlock() }
        _sampleTime = m.sampleTime
        let x = _IsimChannels.adapt(outputNode._pull(n, c), to: Int(m.format.channelCount), frames: n)
        _renderSideNodes(n, c)
        m.sampleTime += AVAudioFramePosition(n)
        return x
    }
    public func renderOffline(_ numberOfFrames: AVAudioFrameCount, to buffer: AVAudioPCMBuffer) throws -> AVAudioEngineManualRenderingStatus {
        guard let m = _manual else { throw AVAudioEngineManualRenderingError.invalidMode }
        guard isRunning else { throw AVAudioEngineManualRenderingError.notRunning }
        let n = Int(min(numberOfFrames, buffer.frameCapacity, m.maxFrames))
        guard let x = _renderManual(n) else { return .error }
        for k in 0..<buffer.channels.count {
            let s = x[min(k, x.count - 1)]
            s.withUnsafeBufferPointer { buffer.channels[k].update(from: $0.baseAddress!, count: n) }
        }
        buffer.frameLength = AVAudioFrameCount(n)
        return .success
    }
    /// the block form of renderOffline (any linear PCM buffer list in the manual rendering format)
    public var manualRenderingBlock: AVAudioEngineManualRenderingBlock {
        { [weak self] frames, list, err in
            guard let self, let m = self._manual else { err?.pointee = -80800; return .error }
            guard self.isRunning else { err?.pointee = -80802; return .error }
            let n = Int(min(frames, m.maxFrames))
            guard let x = self._renderManual(n) else { return .error }
            _IsimPCM.fill(UnsafeMutableAudioBufferListPointer(list), x, m.format._asbd, frames: n)
            err?.pointee = 0
            return .success
        }
    }
}

// MARK: - taps

public typealias AVAudioNodeTapBlock = (AVAudioPCMBuffer, AVAudioTime) -> Void
extension AVAudioNode {
    /// Every `bufferSize` frames of the bus's output (isim: on the main queue in real time).
    public func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block tapBlock: @escaping AVAudioNodeTapBlock) {
        engine?._lock.lock()
        _tap = _Tap(size: Int(max(64, bufferSize)), format: format, block: tapBlock)
        engine?._lock.unlock()
        if let input = self as? AVAudioInputNode, engine?.isRunning == true, engine?._manual == nil { input._startCapture() }
    }
    public func removeTap(onBus bus: AVAudioNodeBus) {
        engine?._lock.lock()
        _tap = nil
        engine?._lock.unlock()
        if let input = self as? AVAudioInputNode, !input._inUse { input._stopCapture() }
    }
}
