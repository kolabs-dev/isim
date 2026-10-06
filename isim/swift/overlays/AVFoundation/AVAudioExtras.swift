// isim AVFoundation: audio effects (AVAudioUnitReverb, AVAudioUnitEQ, AVAudioUnitTimePitch, AVAudioUnitVarispeed,
// AVAudioUnitDelay, AVAudioUnitDistortion), offline manual rendering, taps, the input node, AVAudioRecorder and
// writing AVAudioFiles. Self-authored DSP (adapted: simple Freeverb-style reverb, RBJ biquads, overlap-add time
// stretching — not Apple's algorithms).
// Effects are applied when a buffer starts playing (the player node -> effect -> ... chain built with connect),
// so parameter changes affect the next scheduled buffer, not one already playing.
// Input: isim never opens the host microphone unless asked: ISIM_AUDIO_INPUT=<audio file> plays a file into the
// microphone in real time, ISIM_AUDIO_INPUT=mic records the host's default capture device; otherwise silence.
import isim_host

// MARK: - effect units

open class AVAudioUnit: AVAudioNode {
    open var name: String { String(describing: type(of: self)) }
    open var manufacturerName: String { "isim" }
    open var version: Int { 1 }
}

open class AVAudioUnitEffect: AVAudioUnit {
    open var bypass = false
    /// Processes deinterleaved channels in place (may change their length); rate in Hz.
    func _process(_ ch: inout [[Float]], rate: Double) {}
    /// Extra seconds of output after the input ends (reverb/delay tails).
    var _tail: Double { 0 }
}

func _mix(_ dry: [Float], _ wet: [Float], _ wetDry: Float) -> [Float] {
    let w = min(max(wetDry, 0), 100) / 100
    var out = [Float](repeating: 0, count: max(dry.count, wet.count))
    for i in 0..<out.count { out[i] = (i < dry.count ? dry[i] : 0) * (1 - w) + (i < wet.count ? wet[i] : 0) * w }
    return out
}

public enum AVAudioUnitReverbPreset: Int, Sendable {
    case smallRoom = 0, mediumRoom, largeRoom, mediumHall, largeHall, plate, mediumChamber, largeChamber, cathedral, largeRoom2, mediumHall2, mediumHall3, largeHall2
}
/// Freeverb-style reverb (8 combs + 4 allpasses per channel).
open class AVAudioUnitReverb: AVAudioUnitEffect {
    open var wetDryMix: Float = 100
    var room: Float = 0.84, damp: Float = 0.2
    open func loadFactoryPreset(_ p: AVAudioUnitReverbPreset) {
        switch p {
        case .smallRoom: room = 0.70; damp = 0.5
        case .mediumRoom, .mediumChamber: room = 0.78; damp = 0.4
        case .largeRoom, .largeRoom2, .largeChamber: room = 0.84; damp = 0.3
        case .mediumHall, .mediumHall2, .mediumHall3, .plate: room = 0.88; damp = 0.25
        case .largeHall, .largeHall2: room = 0.92; damp = 0.2
        case .cathedral: room = 0.96; damp = 0.1
        }
    }
    override var _tail: Double { Double(room) * 4 }
    override func _process(_ ch: inout [[Float]], rate: Double) {
        guard !bypass else { return }
        let scale = rate / 44100
        let combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617], alls = [556, 441, 341, 225]
        for (ci, x) in ch.enumerated() {
            let spread = ci * 23
            let n = x.count
            var wet = [Float](repeating: 0, count: n)
            for d0 in combs {
                let d = max(1, Int(Double(d0 + spread) * scale))
                var buf = [Float](repeating: 0, count: d); var idx = 0; var store: Float = 0
                for i in 0..<n {
                    let y = buf[idx]
                    store = y * (1 - damp) + store * damp
                    buf[idx] = x[i] + store * room
                    idx += 1; if idx == d { idx = 0 }
                    wet[i] += y
                }
            }
            for d0 in alls {
                let d = max(1, Int(Double(d0 + spread) * scale))
                var buf = [Float](repeating: 0, count: d); var idx = 0
                for i in 0..<n {
                    let b = buf[idx], inp = wet[i]
                    wet[i] = -inp + b
                    buf[idx] = inp + b * 0.5
                    idx += 1; if idx == d { idx = 0 }
                }
            }
            for i in 0..<n { wet[i] *= 0.015 * 3 }
            ch[ci] = _mix(x, wet, wetDryMix)
        }
    }
}

public enum AVAudioUnitEQFilterType: Int, Sendable {
    case parametric = 0, lowPass, highPass, resonantLowPass, resonantHighPass, bandPass, bandStop, lowShelf, highShelf, resonantLowShelf, resonantHighShelf
}
open class AVAudioUnitEQFilterParameters: NSObject {
    open var filterType: AVAudioUnitEQFilterType = .parametric
    open var frequency: Float = 1000
    open var bandwidth: Float = 0.5      // octaves
    open var gain: Float = 0             // dB
    open var bypass = true               // like AUNBandEQ: bands start bypassed
}
/// N-band equalizer of RBJ biquad filters.
open class AVAudioUnitEQ: AVAudioUnitEffect {
    public let bands: [AVAudioUnitEQFilterParameters]
    open var globalGain: Float = 0
    public init(numberOfBands: Int) { bands = (0..<max(0, numberOfBands)).map { _ in AVAudioUnitEQFilterParameters() }; super.init() }
    public override convenience init() { self.init(numberOfBands: 1) }
    override func _process(_ ch: inout [[Float]], rate: Double) {
        guard !bypass else { return }
        for band in bands where !band.bypass {
            let c = Self.coefficients(band, rate: rate)
            for k in 0..<ch.count {
                var x1: Double = 0, x2: Double = 0, y1: Double = 0, y2: Double = 0
                ch[k].withUnsafeMutableBufferPointer { b in
                    for i in 0..<b.count {
                        let x = Double(b[i])
                        let y = c.0 * x + c.1 * x1 + c.2 * x2 - c.3 * y1 - c.4 * y2
                        x2 = x1; x1 = x; y2 = y1; y1 = y
                        b[i] = Float(y)
                    }
                }
            }
        }
        if globalGain != 0 {
            let g = Float(pow(10, Double(globalGain) / 20))
            for k in 0..<ch.count { for i in 0..<ch[k].count { ch[k][i] *= g } }
        }
    }
    /// normalized (b0, b1, b2, a1, a2)
    static func coefficients(_ p: AVAudioUnitEQFilterParameters, rate: Double) -> (Double, Double, Double, Double, Double) {
        let f = min(max(Double(p.frequency), 10), rate * 0.45)
        let w0 = 2 * Double.pi * f / rate, cw = cos(w0), sw = sin(w0)
        let bw = max(0.05, Double(p.bandwidth))
        let alphaBW = sw * sinh(log(2) / 2 * bw * w0 / sw)
        let alphaQ = sw / (2 * 0.707)
        let A = pow(10, Double(p.gain) / 40)
        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0
        switch p.filterType {
        case .parametric:
            b0 = 1 + alphaBW * A; b1 = -2 * cw; b2 = 1 - alphaBW * A; a0 = 1 + alphaBW / A; a1 = -2 * cw; a2 = 1 - alphaBW / A
        case .lowPass, .resonantLowPass:
            let al = p.filterType == .lowPass ? alphaQ : alphaBW
            b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2; a0 = 1 + al; a1 = -2 * cw; a2 = 1 - al
        case .highPass, .resonantHighPass:
            let al = p.filterType == .highPass ? alphaQ : alphaBW
            b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2; a0 = 1 + al; a1 = -2 * cw; a2 = 1 - al
        case .bandPass:
            b0 = alphaBW; b1 = 0; b2 = -alphaBW; a0 = 1 + alphaBW; a1 = -2 * cw; a2 = 1 - alphaBW
        case .bandStop:
            b0 = 1; b1 = -2 * cw; b2 = 1; a0 = 1 + alphaBW; a1 = -2 * cw; a2 = 1 - alphaBW
        case .lowShelf, .resonantLowShelf, .highShelf, .resonantHighShelf:
            let low = p.filterType == .lowShelf || p.filterType == .resonantLowShelf
            let al = sw / 2 * sqrt(2), sq = 2 * sqrt(A) * al
            if low {
                b0 = A * ((A + 1) - (A - 1) * cw + sq); b1 = 2 * A * ((A - 1) - (A + 1) * cw); b2 = A * ((A + 1) - (A - 1) * cw - sq)
                a0 = (A + 1) + (A - 1) * cw + sq; a1 = -2 * ((A - 1) + (A + 1) * cw); a2 = (A + 1) + (A - 1) * cw - sq
            } else {
                b0 = A * ((A + 1) + (A - 1) * cw + sq); b1 = -2 * A * ((A - 1) + (A + 1) * cw); b2 = A * ((A + 1) + (A - 1) * cw - sq)
                a0 = (A + 1) - (A - 1) * cw + sq; a1 = 2 * ((A - 1) - (A + 1) * cw); a2 = (A + 1) - (A - 1) * cw - sq
            }
        }
        return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    }
}

func _resample(_ x: [Float], by factor: Double) -> [Float] {
    // factor > 1 = faster / shorter (and higher pitched)
    guard factor > 0, !x.isEmpty else { return x }
    let n = max(1, Int(Double(x.count) / factor))
    var out = [Float](repeating: 0, count: n)
    for i in 0..<n {
        let p = Double(i) * factor, i0 = Int(p), t = Float(p - Double(i0))
        let a = x[min(i0, x.count - 1)], b = x[min(i0 + 1, x.count - 1)]
        out[i] = a + (b - a) * t
    }
    return out
}
/// Overlap-add time stretch: output length = input length * stretch, pitch unchanged.
func _stretch(_ x: [Float], by stretch: Double, window n: Int) -> [Float] {
    guard stretch > 0, abs(stretch - 1) > 1e-4, x.count > n else { return x }
    let hs = n / 4, ha = max(1, Double(hs) / stretch)
    let outCount = Int(Double(x.count) * stretch)
    var out = [Float](repeating: 0, count: outCount + n), norm = [Float](repeating: 0, count: outCount + n)
    let win = (0..<n).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(n))) }
    var k = 0
    while true {
        let a = Int(Double(k) * ha), s = k * hs
        if a + n > x.count || s >= outCount { break }
        for i in 0..<n { out[s + i] += x[a + i] * win[i]; norm[s + i] += win[i] }
        k += 1
    }
    for i in 0..<outCount where norm[i] > 1e-3 { out[i] /= norm[i] }
    return Array(out[0..<outCount])
}

/// Changes playback rate without changing pitch, and pitch (cents) without changing rate.
open class AVAudioUnitTimePitch: AVAudioUnitEffect {
    open var rate: Float = 1
    open var pitch: Float = 0
    open var overlap: Float = 8
    override func _process(_ ch: inout [[Float]], rate sr: Double) {
        guard !bypass, rate != 1 || pitch != 0 else { return }
        let r = Double(min(max(rate, 1.0 / 32), 32)), p = pow(2, Double(min(max(pitch, -2400), 2400)) / 1200)
        let win = Int(sr * 0.046)
        for k in 0..<ch.count {
            let shifted = p != 1 ? _resample(ch[k], by: p) : ch[k]
            ch[k] = _stretch(shifted, by: p / r, window: win)
        }
    }
}
/// Rate change by resampling (pitch follows the rate, like a tape).
open class AVAudioUnitVarispeed: AVAudioUnitEffect {
    open var rate: Float = 1
    override func _process(_ ch: inout [[Float]], rate sr: Double) {
        guard !bypass, rate != 1 else { return }
        for k in 0..<ch.count { ch[k] = _resample(ch[k], by: Double(min(max(rate, 0.25), 4))) }
    }
}
open class AVAudioUnitDelay: AVAudioUnitEffect {
    open var delayTime: TimeInterval = 1
    open var feedback: Float = 50
    open var lowPassCutoff: Float = 15000
    open var wetDryMix: Float = 100
    override var _tail: Double {
        let fb = Double(min(max(abs(feedback), 0), 99)) / 100
        return fb > 0 ? min(10, delayTime * log(0.001) / log(fb)) : delayTime
    }
    override func _process(_ ch: inout [[Float]], rate sr: Double) {
        guard !bypass else { return }
        let d = max(1, Int(min(max(delayTime, 0), 2) * sr)), fb = Float(min(max(feedback, -100), 100)) / 100
        let lp = Float(exp(-2 * Double.pi * Double(min(max(lowPassCutoff, 10), Float(sr / 2))) / sr))
        for k in 0..<ch.count {
            let x = ch[k]
            var wet = [Float](repeating: 0, count: x.count)
            var line = [Float](repeating: 0, count: d); var idx = 0; var z: Float = 0
            for i in 0..<x.count {
                let y = line[idx]
                z = y * (1 - lp) + z * lp
                line[idx] = x[i] + z * fb
                idx += 1; if idx == d { idx = 0 }
                wet[i] = y
            }
            ch[k] = _mix(x, wet, wetDryMix)
        }
    }
}
public enum AVAudioUnitDistortionPreset: Int, Sendable {
    case drumsBitBrush = 0, drumsBufferBeats, drumsLoFi, multiBrokenSpeaker, multiCellphoneConcert, multiDecimated1, multiDecimated2,
         multiDecimated3, multiDecimated4, multiDistortedFunk, multiDistortedCubed, multiDistortedSquared, multiEcho1, multiEcho2,
         multiEchoTight1, multiEchoTight2, multiEverythingIsBroken, speechAlienChatter, speechCosmicInterference, speechGoldenPi,
         speechRadioTower, speechWaves
}
/// Soft-clipping overdrive (every preset maps to a drive amount).
open class AVAudioUnitDistortion: AVAudioUnitEffect {
    open var preGain: Float = -6
    open var wetDryMix: Float = 50
    var drive: Float = 8
    open func loadFactoryPreset(_ p: AVAudioUnitDistortionPreset) { drive = 4 + Float(p.rawValue % 6) * 4 }
    override func _process(_ ch: inout [[Float]], rate sr: Double) {
        guard !bypass else { return }
        let g = Float(pow(10, Double(preGain) / 20)) * drive
        for k in 0..<ch.count { let x = ch[k]; ch[k] = _mix(x, x.map { Float(tanh(Double($0 * g))) }, wetDryMix) }
    }
}

// MARK: - engine graph: effects, offline rendering, taps

extension AVAudioEngine {
    /// The effect units downstream of a node, in order (player -> effect -> effect -> mixer).
    func _effectChain(from node: AVAudioNode) -> [AVAudioUnitEffect] {
        var out: [AVAudioUnitEffect] = [], seen = Set<ObjectIdentifier>()
        var n: AVAudioNode? = _outputs[ObjectIdentifier(node)]
        while let cur = n, !seen.contains(ObjectIdentifier(cur)) {
            seen.insert(ObjectIdentifier(cur))
            if let e = cur as? AVAudioUnitEffect { out.append(e) }
            n = _outputs[ObjectIdentifier(cur)]
        }
        return out
    }
    /// The buffer run through its effect chain (nil when there are no effects).
    func _applyEffects(_ b: AVAudioPCMBuffer, from node: AVAudioNode) -> AVAudioPCMBuffer? {
        let chain = _effectChain(from: node)
        guard !chain.isEmpty else { return nil }
        let rate = b.format.sampleRate, n = Int(b.frameLength)
        let tail = chain.reduce(0.0) { $0 + $1._tail }
        var ch = b.channels.map { p -> [Float] in
            var a = Array(UnsafeBufferPointer(start: p, count: n))
            a.append(contentsOf: [Float](repeating: 0, count: Int(tail * rate)))
            return a
        }
        for e in chain { e._process(&ch, rate: rate) }
        let frames = ch.map { $0.count }.max() ?? 0
        guard frames > 0, let out = AVAudioPCMBuffer(pcmFormat: b.format, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        for (k, dst) in out.channels.enumerated() {
            let src = ch[min(k, ch.count - 1)]
            src.withUnsafeBufferPointer { dst.update(from: $0.baseAddress!, count: src.count) }
            if src.count < frames { (dst + src.count).update(repeating: 0, count: frames - src.count) }
        }
        out.frameLength = AVAudioFrameCount(frames)
        return out
    }
}

public enum AVAudioEngineManualRenderingMode: Int, Sendable { case offline = 0, realtime }
public enum AVAudioEngineManualRenderingStatus: Int, Sendable { case error = -1, success = 0, insufficientDataFromInputNode = 1, cannotDoInCurrentContext = 2 }
public enum AVAudioEngineManualRenderingError: Int, Error, Sendable { case invalidMode = -80800, initialized = -80801, notRunning = -80802 }

final class _ManualRendering {
    let mode: AVAudioEngineManualRenderingMode, format: AVAudioFormat, maxFrames: AVAudioFrameCount
    var sampleTime: AVAudioFramePosition = 0
    init(mode: AVAudioEngineManualRenderingMode, format: AVAudioFormat, maxFrames: AVAudioFrameCount) { self.mode = mode; self.format = format; self.maxFrames = maxFrames }
}

extension AVAudioEngine {
    /// Offline rendering: the engine renders into buffers instead of the speaker (player nodes, effects, mixer volume).
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

    public func renderOffline(_ numberOfFrames: AVAudioFrameCount, to buffer: AVAudioPCMBuffer) throws -> AVAudioEngineManualRenderingStatus {
        guard let m = _manual else { throw AVAudioEngineManualRenderingError.invalidMode }
        guard isRunning else { throw AVAudioEngineManualRenderingError.notRunning }
        let n = Int(min(numberOfFrames, buffer.frameCapacity, m.maxFrames))
        let rate = m.format.sampleRate, chans = buffer.channels.count
        var mix = [[Float]](repeating: [Float](repeating: 0, count: n), count: chans)
        for case let p as AVAudioPlayerNode in nodes where p.isPlaying {
            let vol = Float(p.effectiveVolume)
            let src = p._pull(n, rate: rate)
            for c in 0..<chans {
                let s = src[min(c, src.count - 1)]
                for i in 0..<min(n, s.count) { mix[c][i] += s[i] * vol }
            }
        }
        for c in 0..<chans { mix[c].withUnsafeBufferPointer { buffer.channels[c].update(from: $0.baseAddress!, count: n) } }
        buffer.frameLength = AVAudioFrameCount(n)
        _deliverTap(mainMixerNode, buffer, AVAudioTime(sampleTime: m.sampleTime, atRate: rate))
        m.sampleTime += AVAudioFramePosition(n)
        return .success
    }
}

extension AVAudioPlayerNode {
    /// Offline: the next n frames of the scheduled buffers (after effects, resampled to `rate`).
    func _pull(_ n: Int, rate: Double) -> [[Float]] {
        var out: [[Float]] = [[]]
        var filled = 0
        while filled < n {
            if _offItem == nil {
                guard !queue.isEmpty else { break }
                let item = queue.removeFirst()
                let b = engine?._applyEffects(item.buffer, from: self) ?? item.buffer
                let frames = Int(b.frameLength), r = b.format.sampleRate
                _offPCM = b.channels.map { p in
                    let a = Array(UnsafeBufferPointer(start: p, count: frames))
                    return r == rate ? a : _resample(a, by: r / rate)
                }
                _offItem = item; _offPos = 0
                if out.count < _offPCM.count { out = [[Float]](repeating: [Float](repeating: 0, count: filled), count: _offPCM.count) }
            }
            let len = _offPCM.first?.count ?? 0
            let take = min(n - filled, len - _offPos)
            for c in 0..<out.count {
                let src = _offPCM[min(c, _offPCM.count - 1)]
                out[c].append(contentsOf: src[_offPos..<(_offPos + max(0, take))])
            }
            filled += max(0, take); _offPos += max(0, take)
            if _offPos >= len {
                let item = _offItem
                if item?.options.contains(.loops) == true && len > 0 { _offPos = 0; continue }
                _offItem = nil; _offPCM = []
                item?.completion?()
            }
        }
        for c in 0..<out.count where out[c].count < n { out[c].append(contentsOf: [Float](repeating: 0, count: n - out[c].count)) }
        return out
    }
}

// taps (main mixer in offline rendering, input node in real time)
public typealias AVAudioNodeTapBlock = (AVAudioPCMBuffer, AVAudioTime) -> Void
enum _Taps { nonisolated(unsafe) static var blocks: [ObjectIdentifier: (AVAudioFrameCount, AVAudioNodeTapBlock)] = [:] }
extension AVAudioNode {
    public func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block tapBlock: @escaping AVAudioNodeTapBlock) {
        _Taps.blocks[ObjectIdentifier(self)] = (max(64, bufferSize), tapBlock)
        if let input = self as? AVAudioInputNode { input._startCapture() }
        else if !(self is AVAudioMixerNode) || engine?._manual == nil {
            NSLog("isim AVFoundation: taps deliver audio only on the input node, and on the main mixer during offline rendering")
        }
    }
    public func removeTap(onBus bus: AVAudioNodeBus) {
        _Taps.blocks[ObjectIdentifier(self)] = nil
        (self as? AVAudioInputNode)?._stopCapture()
    }
}
extension AVAudioEngine {
    func _deliverTap(_ node: AVAudioNode, _ b: AVAudioPCMBuffer, _ t: AVAudioTime) {
        if let (_, block) = _Taps.blocks[ObjectIdentifier(node)] { block(b, t) }
    }
}

// MARK: - input

/// Host audio input shared by the input node and recorders (48 kHz stereo float, real time): one poller hands
/// every chunk to all subscribers.
enum _AudioInput {
    nonisolated(unsafe) static var subscribers: [ObjectIdentifier: ([Float]) -> Void] = [:]
    nonisolated(unsafe) static var timer: Timer?
    nonisolated(unsafe) static var kind: Int32 = 0
    static func subscribe(_ owner: AnyObject, _ f: @escaping ([Float]) -> Void) {
        if subscribers.isEmpty {
            kind = isim_audio_input_start()
            timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in poll() }
        }
        subscribers[ObjectIdentifier(owner)] = f
    }
    static func unsubscribe(_ owner: AnyObject) {
        guard subscribers.removeValue(forKey: ObjectIdentifier(owner)) != nil else { return }
        if subscribers.isEmpty { timer?.invalidate(); timer = nil; isim_audio_input_stop() }
    }
    static func poll() {
        let x = read()
        guard !x.isEmpty else { return }
        for f in Array(subscribers.values) { f(x) }
    }
    /// what has arrived since the last read (interleaved stereo)
    static func read() -> [Float] {
        var out: [Float] = []
        var chunk = [Float](repeating: 0, count: 4096 * 2)
        while true {
            let n = chunk.withUnsafeMutableBufferPointer { isim_audio_input_read($0.baseAddress, 4096) }
            if n <= 0 { break }
            out.append(contentsOf: chunk[0..<(n * 2)])
            if n < 4096 { break }
        }
        return out
    }
}

open class AVAudioIONode: AVAudioNode {
    open var presentationLatency: TimeInterval { 0 }
    open var isVoiceProcessingEnabled: Bool { false }
    open func setVoiceProcessingEnabled(_ enabled: Bool) throws {}
}
/// The microphone: 48 kHz mono. Taps receive buffers as input arrives.
open class AVAudioInputNode: AVAudioIONode {
    var capturing = false
    var pending: [Float] = []
    var sampleTime: AVAudioFramePosition = 0
    open var volume: Float = 1
    open override func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)! }
    func _startCapture() {
        guard !capturing else { return }
        capturing = true
        _AudioInput.subscribe(self) { [weak self] x in self?._received(x) }
    }
    func _stopCapture() {
        guard capturing else { return }
        capturing = false
        _AudioInput.unsubscribe(self)
        pending = []
    }
    func _received(_ inter: [Float]) {
        guard engine?.isRunning == true, let (size, block) = _Taps.blocks[ObjectIdentifier(self)] else { return }
        for i in Swift.stride(from: 0, to: inter.count - 1, by: 2) { pending.append((inter[i] + inter[i + 1]) * 0.5 * volume) }
        let fmt = outputFormat(forBus: 0)
        while pending.count >= Int(size) {
            let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: size)!
            pending.withUnsafeBufferPointer { b.channels[0].update(from: $0.baseAddress!, count: Int(size)) }
            b.frameLength = size
            pending.removeFirst(Int(size))
            block(b, AVAudioTime(sampleTime: sampleTime, atRate: 48000))
            sampleTime += AVAudioFramePosition(size)
        }
    }
}

// MARK: - session permission (iOS 17 AVAudioApplication and AVAudioSession)

extension AVAudioSession {
    public enum RecordPermission: UInt, Sendable { case undetermined = 0x756E6474, denied = 0x64656E79, granted = 0x67726E74 }
    /// isim: always granted (input is a file or silence unless ISIM_AUDIO_INPUT=mic).
    public var recordPermission: RecordPermission { .granted }
    public func requestRecordPermission(_ response: @escaping (Bool) -> Void) { DispatchQueue.main.async { response(true) } }
    public var isInputAvailable: Bool { true }
    public var inputNumberOfChannels: Int { 1 }
    public var inputLatency: TimeInterval { 0.005 }
    public var outputLatency: TimeInterval { 0.01 }
    public var ioBufferDuration: TimeInterval { 0.01 }
    public func setPreferredSampleRate(_ rate: Double) throws {}
    public func setPreferredIOBufferDuration(_ d: TimeInterval) throws {}
}
open class AVAudioApplication: NSObject {
    public enum recordPermission: Int, Sendable { case undetermined = 0, denied, granted }
    nonisolated(unsafe) static let _shared = AVAudioApplication()
    open class var shared: AVAudioApplication { _shared }
    open var recordPermission: AVAudioApplication.recordPermission { .granted }
    open var isInputMuted = false
    open func setInputMuted(_ muted: Bool) throws { isInputMuted = muted }
    open class func requestRecordPermission(completionHandler response: @escaping (Bool) -> Void) { DispatchQueue.main.async { response(true) } }
    open class func requestRecordPermission() async -> Bool { true }
}

// MARK: - settings keys and file writing

public let AVFormatIDKey = "AVFormatIDKey"
public let AVSampleRateKey = "AVSampleRateKey"
public let AVNumberOfChannelsKey = "AVNumberOfChannelsKey"
public let AVLinearPCMBitDepthKey = "AVLinearPCMBitDepthKey"
public let AVLinearPCMIsBigEndianKey = "AVLinearPCMIsBigEndianKey"
public let AVLinearPCMIsFloatKey = "AVLinearPCMIsFloatKey"
public let AVLinearPCMIsNonInterleaved = "AVLinearPCMIsNonInterleaved"
public let AVEncoderAudioQualityKey = "AVEncoderAudioQualityKey"
public let AVEncoderBitRateKey = "AVEncoderBitRateKey"
public let AVEncoderBitDepthHintKey = "AVEncoderBitDepthHintKey"
public let AVSampleRateConverterAudioQualityKey = "AVSampleRateConverterAudioQualityKey"
public enum AVAudioQuality: Int, Sendable { case min = 0, low = 0x20, medium = 0x40, high = 0x60, max = 0x7F }

/// Collects PCM and writes WAV/CAF (16/24/32-bit int or 32-bit float); other containers via the host's ffmpeg.
final class _AudioFileWriter {
    let url: URL, rate: Double, channelCount: Int, bits: Int, isFloat: Bool
    var data: [[Float]]
    var closed = false
    var frames: Int { data.first?.count ?? 0 }
    init(url: URL, settings: [String: Any]) throws {
        self.url = url
        func num(_ k: String) -> Double? { (settings[k] as? NSNumber)?.doubleValue ?? (settings[k] as? Double) ?? (settings[k] as? Int).map(Double.init) ?? (settings[k] as? UInt32).map(Double.init) }
        rate = num(AVSampleRateKey) ?? 44100
        channelCount = max(1, min(8, Int(num(AVNumberOfChannelsKey) ?? 1)))
        isFloat = (settings[AVLinearPCMIsFloatKey] as? Bool) ?? false
        bits = isFloat ? 32 : [8, 16, 24, 32].contains(Int(num(AVLinearPCMBitDepthKey) ?? 16)) ? Int(num(AVLinearPCMBitDepthKey) ?? 16) : 16
        data = [[Float]](repeating: [], count: channelCount)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw _avError("isim AVFoundation: cannot create \(url.path)", code: -54)
        }
    }
    func append(_ b: AVAudioPCMBuffer) {
        let n = Int(b.frameLength)
        let src = b.channels.map { Array(UnsafeBufferPointer(start: $0, count: n)) }
        let conv = b.format.sampleRate == rate ? src : src.map { _resample($0, by: b.format.sampleRate / rate) }
        for c in 0..<channelCount { data[c].append(contentsOf: conv.isEmpty ? [] : conv[min(c, conv.count - 1)]) }
    }
    func append(interleavedStereo48k x: [Float]) {
        var l = [Float](), r = [Float]()
        l.reserveCapacity(x.count / 2); r.reserveCapacity(x.count / 2)
        for i in Swift.stride(from: 0, to: x.count - 1, by: 2) { l.append(x[i]); r.append(x[i + 1]) }
        let chans = channelCount == 1 ? [zip(l, r).map { ($0 + $1) * 0.5 }] : [l, r]
        let conv = rate == 48000 ? chans : chans.map { _resample($0, by: 48000 / rate) }
        for c in 0..<channelCount { data[c].append(contentsOf: conv[min(c, conv.count - 1)]) }
    }
    func finish() throws {
        guard !closed else { return }
        closed = true
        let ext = url.pathExtension.lowercased()
        if ext == "wav" || ext == "wave" { try wav().write(to: url); return }
        if ext == "caf" { try caf().write(to: url); return }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("isim-rec-\(UUID().uuidString).wav")
        try wav().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try? FileManager.default.removeItem(at: url)
        guard isim_media_transcode(tmp.path, url.path) != 0 else {
            throw _avError("isim AVFoundation: cannot encode \(url.lastPathComponent) (needs ffmpeg on the host)", code: 1718449215)
        }
    }
    func samples(bigEndian: Bool) -> [UInt8] {
        var out = [UInt8](); out.reserveCapacity(frames * channelCount * bits / 8)
        for i in 0..<frames {
            for c in 0..<channelCount {
                let x = max(-1, min(1, data[c][i]))
                var v: UInt32
                switch (isFloat, bits) {
                case (true, _): v = x.bitPattern
                case (_, 8): out.append(UInt8(clamping: Int((x * 127).rounded()) + 128)); continue
                case (_, 24): v = UInt32(bitPattern: Int32((Double(x) * 8388607).rounded()))
                case (_, 32): v = UInt32(bitPattern: Int32(max(-2147483647, min(2147483647, (Double(x) * 2147483647).rounded()))))
                default: v = UInt32(bitPattern: Int32((x * 32767).rounded()))
                }
                let nb = bits / 8
                for k in 0..<nb { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(bigEndian ? nb - 1 - k : k)))) }
            }
        }
        return out
    }
    func wav() -> Data {
        let body = samples(bigEndian: false)
        var d = [UInt8]()
        func s(_ x: String) { d.append(contentsOf: Array(x.utf8)) }
        func u32(_ v: Int) { for k in 0..<4 { d.append(UInt8(truncatingIfNeeded: v >> (8 * k))) } }
        func u16(_ v: Int) { for k in 0..<2 { d.append(UInt8(truncatingIfNeeded: v >> (8 * k))) } }
        let blockAlign = channelCount * bits / 8
        s("RIFF"); u32(36 + body.count); s("WAVE"); s("fmt "); u32(16); u16(isFloat ? 3 : 1); u16(channelCount)
        u32(Int(rate)); u32(Int(rate) * blockAlign); u16(blockAlign); u16(bits); s("data"); u32(body.count)
        d.append(contentsOf: body)
        return Data(d)
    }
    func caf() -> Data {
        let body = samples(bigEndian: false)
        var d = [UInt8]()
        func s(_ x: String) { d.append(contentsOf: Array(x.utf8)) }
        func be(_ v: UInt64, _ n: Int) { for k in (0..<n).reversed() { d.append(UInt8(truncatingIfNeeded: v >> (8 * UInt64(k)))) } }
        s("caff"); be(1, 2); be(0, 2)
        s("desc"); be(32, 8)
        be(rate.bitPattern, 8); s("lpcm"); be(UInt64((isFloat ? 1 : 0) | 2), 4)                // little-endian flag
        be(UInt64(channelCount * bits / 8), 4); be(1, 4); be(UInt64(channelCount), 4); be(UInt64(bits), 4)
        s("data"); be(UInt64(body.count + 4), 8); be(0, 4)
        d.append(contentsOf: body)
        return Data(d)
    }
}

// MARK: - AVAudioRecorder

@objc public protocol AVAudioRecorderDelegate: NSObjectProtocol {
    @objc optional func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool)
    @objc optional func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?)
}

open class AVAudioRecorder: NSObject {
    public let url: URL
    public let settings: [String: Any]
    public let format: AVAudioFormat
    open weak var delegate: AVAudioRecorderDelegate?
    open var isMeteringEnabled = false
    open private(set) var isRecording = false
    var writer: _AudioFileWriter
    var captured = 0                       // 48 kHz frames
    var limit: Double?
    var last: [Float] = []                 // recent samples for metering
    var avgDB: Float = -160, peakDB: Float = -160
    var subscribed = false

    public init(url: URL, settings: [String: Any]) throws {
        self.url = url; self.settings = settings
        writer = try _AudioFileWriter(url: url, settings: settings)
        format = AVAudioFormat(standardFormatWithSampleRate: writer.rate, channels: AVAudioChannelCount(writer.channelCount))!
    }
    public convenience init(url: URL, format: AVAudioFormat) throws {
        try self.init(url: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: Int(format.channelCount)])
    }
    deinit { if subscribed { _AudioInput.unsubscribe(self) } }

    open var currentTime: TimeInterval { Double(captured) / 48000 }
    open var deviceCurrentTime: TimeInterval { isim_time() }
    @discardableResult open func prepareToRecord() -> Bool { true }
    @discardableResult open func record() -> Bool {
        guard !isRecording else { return true }
        if writer.closed, let w = try? _AudioFileWriter(url: url, settings: settings) { writer = w; captured = 0 }
        if subscribed { _AudioInput.poll() }      // (resuming) drop nothing, just catch up
        isRecording = true
        if !subscribed { subscribed = true; _AudioInput.subscribe(self) { [weak self] x in self?.received(x) } }
        return true
    }
    @discardableResult open func record(atTime time: TimeInterval) -> Bool { record() }
    @discardableResult open func record(forDuration duration: TimeInterval) -> Bool { limit = duration; return record() }
    @discardableResult open func record(atTime time: TimeInterval, forDuration duration: TimeInterval) -> Bool { record(forDuration: duration) }
    open func pause() {
        guard isRecording else { return }
        _AudioInput.poll()
        isRecording = false
    }
    open func stop() {
        if isRecording { _AudioInput.poll() }
        isRecording = false
        if subscribed { _AudioInput.unsubscribe(self); subscribed = false }
        var ok = true
        do { try writer.finish() } catch {
            ok = false
            delegate?.audioRecorderEncodeErrorDidOccur?(self, error: error)
        }
        let flag = ok
        DispatchQueue.main.async { self.delegate?.audioRecorderDidFinishRecording?(self, successfully: flag) }
    }
    @discardableResult open func deleteRecording() -> Bool {
        guard !isRecording else { return false }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }
    func received(_ chunk: [Float]) {
        guard isRecording else { return }
        var x = chunk
        if let l = limit {
            let room = max(0, Int(l * 48000) - captured)
            if x.count / 2 > room { x = Array(x[0..<(room * 2)]) }
        }
        captured += x.count / 2
        writer.append(interleavedStereo48k: x)
        if isMeteringEnabled { last = Array((last + x).suffix(4096)) }
        if let l = limit, Double(captured) >= l * 48000 { limit = nil; stop() }
    }
    open func updateMeters() {
        guard !last.isEmpty else { avgDB = -160; peakDB = -160; return }
        var sum: Float = 0, peak: Float = 0
        for v in last { sum += v * v; peak = max(peak, abs(v)) }
        let rms = (sum / Float(last.count)).squareRoot()
        avgDB = rms > 0 ? max(-160, 20 * Float(log10(Double(rms)))) : -160
        peakDB = peak > 0 ? max(-160, 20 * Float(log10(Double(peak)))) : -160
    }
    open func averagePower(forChannel channelNumber: Int) -> Float { avgDB }
    open func peakPower(forChannel channelNumber: Int) -> Float { peakDB }
}
