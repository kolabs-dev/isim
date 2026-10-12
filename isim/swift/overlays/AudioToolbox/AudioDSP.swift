// isim AudioToolbox: the real-time render machinery shared by Audio Units (AudioUnits.swift) and AVFoundation's
// AVAudioEngine. Self-authored, not iOS API: the public declarations start with `_Isim` and exist only so AVFoundation
// can use them.
// - _IsimAudioOutput: a render thread that pulls slices from a render closure and plays them through the host mixer
//   (an isim_audio_stream, 48 kHz stereo float), paced in real time; without an audio device (headless) it keeps the
//   same pace silently, so callbacks, taps and timing behave as with sound.
// - _IsimAudioInput: the simulated microphone (ISIM_AUDIO_INPUT, see host_capture.c) fanned out to every consumer.
// - Streaming DSP kernels (adapted, isim's own algorithms, not Apple's): Freeverb-style reverb, RBJ biquad
//   equalizer, delay line, soft-clip distortion, varispeed (resampling) and time/pitch (WSOLA time stretch +
//   resampling). Kernels keep their state between slices and read their parameters every slice, so parameter changes
//   take effect while audio plays.
import Foundation
import isim_host

// MARK: - real-time output

public final class _IsimAudioOutput: @unchecked Sendable {
    /// Renders `frames` frames (deinterleaved, any channel count: mono plays on both sides) at 48 kHz.
    public typealias Render = (_ frames: Int, _ sampleTime: Int64) -> [[Float]]
    public static let sampleRate = 48000.0
    let render: Render
    let lock = NSCondition()
    var running = false, threadRunning = false
    weak var thread: Thread?
    public private(set) var sampleTime: Int64 = 0
    /// frames per render slice (AVAudioSession's IO buffer duration: 10 ms by default)
    public var framesPerSlice = 480
    /// how far ahead of the clock audio is rendered
    public var lead = 0.03
    public init(render: @escaping Render) { self.render = render }
    public var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }

    public func start() {
        lock.lock(); defer { lock.unlock() }
        guard !running else { return }
        running = true
        while threadRunning { lock.wait() }                 // a previous loop is still finishing
        threadRunning = true
        Thread.detachNewThread { [self] in loop() }
    }
    /// Stops rendering (the sample time is kept, start() continues from it).
    public func stop() {
        lock.lock()
        running = false
        lock.broadcast()
        let own = Thread.current === thread
        while threadRunning && !own { lock.wait() }
        lock.unlock()
    }
    public func resetTime() { sampleTime = 0 }

    func loop() {
        thread = Thread.current
        let stream = isim_audio_stream_open(1)
        let rate = Self.sampleRate
        var t0 = Date().timeIntervalSince1970 - Double(sampleTime) / rate
        var rendered = sampleTime
        var inter: [Float] = []
        while true {
            lock.lock(); let go = running; lock.unlock()
            guard go else { break }
            let now = Date().timeIntervalSince1970
            if Double(rendered) / rate < now - t0 - 0.25 { t0 = now - Double(rendered) / rate }   // fell far behind: resync
            if Double(rendered) / rate > now - t0 + lead { Thread.sleep(forTimeInterval: 0.002); continue }
            let n = max(16, framesPerSlice)
            let x = render(n, rendered)
            rendered += Int64(n)
            sampleTime = rendered
            guard stream > 0, let l = x.first else { continue }
            let r = x.count > 1 ? x[1] : l
            if inter.count != n * 2 { inter = [Float](repeating: 0, count: n * 2) }
            for i in 0..<n { inter[2 * i] = i < l.count ? l[i] : 0; inter[2 * i + 1] = i < r.count ? r[i] : 0 }
            var done = 0
            while done < n {
                let w = inter.withUnsafeBufferPointer { isim_audio_stream_write(stream, $0.baseAddress! + 2 * done, n - done) }
                done += w
                if w == 0 { lock.lock(); let go = running; lock.unlock(); if !go { break }; Thread.sleep(forTimeInterval: 0.002) }
            }
        }
        if stream > 0 { isim_audio_stream_close(stream) }
        lock.lock(); threadRunning = false; lock.broadcast(); lock.unlock()
    }
}

// MARK: - simulated microphone

/// The host audio input (48 kHz stereo float, real time) handed to every subscriber: one poller (a main run loop
/// timer) reads what arrived and passes it on. Consumers on render threads buffer it in an _IsimInputFIFO.
public enum _IsimAudioInput {
    nonisolated(unsafe) static var subscribers: [ObjectIdentifier: ([Float]) -> Void] = [:]
    nonisolated(unsafe) static var timer: Timer?
    nonisolated(unsafe) public private(set) static var kind: Int32 = 0
    static let lock = NSLock()
    public static func subscribe(_ owner: AnyObject, _ f: @escaping ([Float]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        if subscribers.isEmpty {
            kind = isim_audio_input_start()
            let start = {
                timer = Timer._isimScheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in poll() }
            }
            if Thread.isMainThread { start() } else { DispatchQueue.main.async(execute: start) }
        }
        subscribers[ObjectIdentifier(owner)] = f
    }
    public static func unsubscribe(_ owner: AnyObject) {
        lock.lock(); defer { lock.unlock() }
        guard subscribers.removeValue(forKey: ObjectIdentifier(owner)) != nil else { return }
        if subscribers.isEmpty {
            let t = timer; timer = nil
            if Thread.isMainThread { t?.invalidate() } else { DispatchQueue.main.async { t?.invalidate() } }
            isim_audio_input_stop()
        }
    }
    /// isim: AVFoundation installs the microphone permission prompt here (AVCaptureDevice.requestAccess(for: .audio)).
    nonisolated(unsafe) public static var requestPermission: (() -> Void)?
    nonisolated(unsafe) static var requested = false
    /// AVAudioApplication's input mute and AVAudioSession's input gain
    nonisolated(unsafe) public static var muted = false
    nonisolated(unsafe) public static var gain: Float = 1
    nonisolated(unsafe) static var checked = 0.0, allowed = true
    /// Like iOS, the microphone records silence until the app may use it: the answer remembered for the app
    /// (AVCaptureDevice's), asked for the first time the input is used; without AVFoundation (no prompt) it is allowed.
    static func permitted() -> Bool {
        let now = Date().timeIntervalSince1970
        if now - checked < 0.25 { return allowed }
        checked = now
        let status = UserDefaults.standard.object(forKey: "_ISIMPrivacy.microphone") as? Int ?? 0   // AVAuthorizationStatus
        if status == 0, let ask = requestPermission {
            if !requested { requested = true; DispatchQueue.main.async(execute: ask) }
            allowed = false
        } else { allowed = status == 0 || status == 3 }
        return allowed
    }
    /// Hands what arrived to the subscribers now.
    public static func poll() {
        lock.lock()
        guard !subscribers.isEmpty else { lock.unlock(); return }
        var x = read()
        if !x.isEmpty && (!permitted() || muted) { x = [Float](repeating: 0, count: x.count) }
        else if gain != 1 { for i in 0..<x.count { x[i] *= gain } }
        let subs = Array(subscribers.values)
        lock.unlock()
        guard !x.isEmpty else { return }
        for f in subs { f(x) }
    }
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

/// A thread-safe queue of input frames (48 kHz, deinterleaved stereo) for consumers that render on another thread.
public final class _IsimInputFIFO: @unchecked Sendable {
    let lock = NSLock()
    var l: [Float] = [], r: [Float] = []
    public init() {}
    public func start() { _IsimAudioInput.subscribe(self) { [weak self] x in self?.push(x) } }
    public func stop() { _IsimAudioInput.unsubscribe(self); lock.lock(); l = []; r = []; lock.unlock() }
    func push(_ x: [Float]) {
        lock.lock(); defer { lock.unlock() }
        for i in Swift.stride(from: 0, to: x.count - 1, by: 2) { l.append(x[i]); r.append(x[i + 1]) }
        if l.count > 48000 { l.removeFirst(l.count - 48000); r.removeFirst(r.count - 48000) }   // keep 1 s at most
    }
    public var available: Int { lock.lock(); defer { lock.unlock() }; return l.count }
    var primed = false
    /// `n` frames. Input arrives in real time while renderers run a little ahead, so the queue first fills up with
    /// 50 ms (silence meanwhile) and keeps that latency; after an underrun it fills up again.
    public func pop(_ n: Int) -> [[Float]] {
        lock.lock(); defer { lock.unlock() }
        if !primed {
            guard l.count >= n + 2400 else { return _IsimChannels.silence(2, n) }
            primed = true
        }
        if l.count < n { primed = false }
        let k = min(n, l.count)
        var a = Array(l[0..<k]), b = Array(r[0..<k])
        l.removeFirst(k); r.removeFirst(k)
        if k < n { a += [Float](repeating: 0, count: n - k); b += [Float](repeating: 0, count: n - k) }
        return [a, b]
    }
}

// MARK: - channel helpers

public enum _IsimChannels {
    /// `x` with `count` channels: mono is copied, more channels are mixed down
    public static func adapt(_ x: [[Float]], to count: Int, frames n: Int) -> [[Float]] {
        guard count > 0 else { return [] }
        if x.isEmpty { return [[Float]](repeating: [Float](repeating: 0, count: n), count: count) }
        if x.count == count { return x }
        if count == 1 {
            var m = [Float](repeating: 0, count: n)
            let k = Float(x.count)
            for c in x { for i in 0..<min(n, c.count) { m[i] += c[i] / k } }
            return [m]
        }
        return (0..<count).map { x[min($0, x.count - 1)] }
    }
    public static func silence(_ channels: Int, _ n: Int) -> [[Float]] { [[Float]](repeating: [Float](repeating: 0, count: n), count: channels) }
    /// adds `src` (scaled) into `dst`, with a stereo pan (-1...1): constant power for mono sources, balance for stereo
    public static func mix(_ src: [[Float]], into dst: inout [[Float]], gain: Float, pan: Float = 0) {
        let n = dst.first?.count ?? 0
        if dst.count == 2 {
            let p = max(-1, min(1, pan))
            let gl: Float, gr: Float
            if src.count == 1 {
                let a = Double(p + 1) * Double.pi / 4
                gl = Float(cos(a)) * Float(2.0.squareRoot()) ; gr = Float(sin(a)) * Float(2.0.squareRoot())
            } else { gl = p > 0 ? 1 - p : 1; gr = p < 0 ? 1 + p : 1 }
            let l = src[0], r = src.count > 1 ? src[1] : src[0]
            let ml = gain * (src.count == 1 ? min(gl, 1) : gl), mr = gain * (src.count == 1 ? min(gr, 1) : gr)
            dst[0].withUnsafeMutableBufferPointer { d in for i in 0..<min(n, l.count) { d[i] += l[i] * ml } }
            dst[1].withUnsafeMutableBufferPointer { d in for i in 0..<min(n, r.count) { d[i] += r[i] * mr } }
            return
        }
        let s = adapt(src, to: dst.count, frames: n)
        for c in 0..<dst.count {
            dst[c].withUnsafeMutableBufferPointer { d in for i in 0..<min(n, s[c].count) { d[i] += s[c][i] * gain } }
        }
    }
}

// MARK: - kernels

/// A streaming processor: renders `n` frames, pulling the input it needs (frames -> deinterleaved channels).
public protocol _IsimDSPKernel: AnyObject {
    func render(_ n: Int, rate: Double, pull: (Int) -> [[Float]]) -> [[Float]]
    func reset()
    /// seconds of output after the input goes silent (reverb, delay)
    var tailTime: Double { get }
}

/// Kernels that turn n input frames into n output frames.
open class _IsimInPlaceKernel: _IsimDSPKernel {
    public var bypass = false
    public init() {}
    open func process(_ x: inout [[Float]], rate: Double) {}
    open func reset() {}
    open var tailTime: Double { 0 }
    public func render(_ n: Int, rate: Double, pull: (Int) -> [[Float]]) -> [[Float]] {
        var x = pull(n)
        if !bypass { process(&x, rate: rate) }
        return x
    }
}

func _wetDry(_ dry: Float, _ wet: Float, _ mix: Float) -> Float { dry * (1 - mix) + wet * mix }

/// Freeverb-style reverb: 8 lowpass-feedback combs and 4 allpasses per channel.
public final class _IsimReverbKernel: _IsimInPlaceKernel {
    /// 0...100 %
    public var wetDryMix: Float = 100
    /// comb feedback (0.7 small room ... 0.96 cathedral) and damping
    public var room: Float = 0.84, damp: Float = 0.2
    /// output gain, dB
    public var gain: Float = 0
    struct Line { var buf: [Float]; var idx = 0; var store: Float = 0 }
    var combs: [[Line]] = [], alls: [[Line]] = []
    var builtRate = 0.0
    public override func reset() { combs = []; alls = [] }
    public override var tailTime: Double { Double(room) * 4 }
    func build(_ channels: Int, _ rate: Double) {
        let scale = rate / 44100
        let c0 = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617], a0 = [556, 441, 341, 225]
        combs = (0..<channels).map { ci in c0.map { Line(buf: [Float](repeating: 0, count: max(1, Int(Double($0 + ci * 23) * scale)))) } }
        alls = (0..<channels).map { ci in a0.map { Line(buf: [Float](repeating: 0, count: max(1, Int(Double($0 + ci * 23) * scale)))) } }
        builtRate = rate
    }
    public override func process(_ x: inout [[Float]], rate: Double) {
        if combs.count != x.count || builtRate != rate { build(x.count, rate) }
        let mix = min(max(wetDryMix, 0), 100) / 100, g = Float(pow(10, Double(gain) / 20))
        let room = self.room, damp = self.damp
        for c in 0..<x.count {
            let n = x[c].count
            var wet = [Float](repeating: 0, count: n)
            for k in 0..<combs[c].count {
                var line = combs[c][k]
                let d = line.buf.count
                for i in 0..<n {
                    let y = line.buf[line.idx]
                    line.store = y * (1 - damp) + line.store * damp
                    line.buf[line.idx] = x[c][i] + line.store * room
                    line.idx += 1; if line.idx == d { line.idx = 0 }
                    wet[i] += y
                }
                combs[c][k] = line
            }
            for k in 0..<alls[c].count {
                var line = alls[c][k]
                let d = line.buf.count
                for i in 0..<n {
                    let b = line.buf[line.idx], inp = wet[i]
                    wet[i] = -inp + b
                    line.buf[line.idx] = inp + b * 0.5
                    line.idx += 1; if line.idx == d { line.idx = 0 }
                }
                alls[c][k] = line
            }
            for i in 0..<n { x[c][i] = _wetDry(x[c][i], wet[i] * 0.045, mix) * g }
        }
    }
}

/// One band of the equalizer (AVAudioUnitEQFilterType raw values).
public struct _IsimEQBand: Sendable {
    public var type = 0, frequency: Float = 1000, bandwidth: Float = 0.5, gain: Float = 0, bypass = true
    public init() {}
}
/// N-band equalizer of RBJ biquads.
public final class _IsimEQKernel: _IsimInPlaceKernel {
    public var bands: [_IsimEQBand]
    public var globalGain: Float = 0
    var state: [[(Double, Double, Double, Double)]] = []      // [band][channel] x1 x2 y1 y2
    public init(bands: Int) { self.bands = [_IsimEQBand](repeating: _IsimEQBand(), count: max(0, bands)); super.init() }
    public override func reset() { state = [] }
    public override func process(_ x: inout [[Float]], rate: Double) {
        let bands = self.bands
        if state.count != bands.count || state.first?.count != x.count {
            state = [[(Double, Double, Double, Double)]](repeating: [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: x.count), count: bands.count)
        }
        for (bi, band) in bands.enumerated() where !band.bypass {
            let c = Self.coefficients(band, rate: rate)
            for k in 0..<x.count {
                var (x1, x2, y1, y2) = state[bi][k]
                x[k].withUnsafeMutableBufferPointer { b in
                    for i in 0..<b.count {
                        let xv = Double(b[i])
                        let y = c.0 * xv + c.1 * x1 + c.2 * x2 - c.3 * y1 - c.4 * y2
                        x2 = x1; x1 = xv; y2 = y1; y1 = y
                        b[i] = Float(y)
                    }
                }
                state[bi][k] = (x1, x2, y1, y2)
            }
        }
        if globalGain != 0 {
            let g = Float(pow(10, Double(globalGain) / 20))
            for k in 0..<x.count { x[k].withUnsafeMutableBufferPointer { b in for i in 0..<b.count { b[i] *= g } } }
        }
    }
    /// normalized (b0, b1, b2, a1, a2); `type` is AVAudioUnitEQFilterType's raw value
    public static func coefficients(_ p: _IsimEQBand, rate: Double) -> (Double, Double, Double, Double, Double) {
        let f = min(max(Double(p.frequency), 10), rate * 0.45)
        let w0 = 2 * Double.pi * f / rate, cw = cos(w0), sw = sin(w0)
        let bw = max(0.05, Double(p.bandwidth))
        let alphaBW = sw * sinh(log(2) / 2 * bw * w0 / sw)
        let alphaQ = sw / (2 * 0.707)
        let A = pow(10, Double(p.gain) / 40)
        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0
        switch p.type {
        case 0:                                                    // parametric
            b0 = 1 + alphaBW * A; b1 = -2 * cw; b2 = 1 - alphaBW * A; a0 = 1 + alphaBW / A; a1 = -2 * cw; a2 = 1 - alphaBW / A
        case 1, 3:                                                 // lowPass, resonantLowPass
            let al = p.type == 1 ? alphaQ : alphaBW
            b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2; a0 = 1 + al; a1 = -2 * cw; a2 = 1 - al
        case 2, 4:                                                 // highPass, resonantHighPass
            let al = p.type == 2 ? alphaQ : alphaBW
            b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2; a0 = 1 + al; a1 = -2 * cw; a2 = 1 - al
        case 5:                                                    // bandPass
            b0 = alphaBW; b1 = 0; b2 = -alphaBW; a0 = 1 + alphaBW; a1 = -2 * cw; a2 = 1 - alphaBW
        case 6:                                                    // bandStop
            b0 = 1; b1 = -2 * cw; b2 = 1; a0 = 1 + alphaBW; a1 = -2 * cw; a2 = 1 - alphaBW
        default:                                                   // shelves
            let low = p.type == 7 || p.type == 9
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

/// Feedback delay line with a low-pass in the loop.
public final class _IsimDelayKernel: _IsimInPlaceKernel {
    public var delayTime: Double = 1          // seconds (0...2)
    public var feedback: Float = 50           // -100...100 %
    public var lowPassCutoff: Float = 15000   // Hz
    public var wetDryMix: Float = 100         // %
    var lines: [[Float]] = [], idx = 0, z: [Float] = [], builtRate = 0.0
    public override func reset() { lines = [] }
    public override var tailTime: Double {
        let fb = Double(min(abs(feedback), 99)) / 100
        return fb > 0 ? min(10, delayTime * log(0.001) / log(fb)) : delayTime
    }
    public override func process(_ x: inout [[Float]], rate: Double) {
        let cap = Int(2 * rate) + 1
        if lines.count != x.count || builtRate != rate {
            lines = [[Float]](repeating: [Float](repeating: 0, count: cap), count: x.count); z = [Float](repeating: 0, count: x.count); idx = 0; builtRate = rate
        }
        let d = max(1, min(cap - 1, Int(min(max(delayTime, 0), 2) * rate)))
        let fb = Float(min(max(feedback, -100), 100)) / 100, mix = min(max(wetDryMix, 0), 100) / 100
        let lp = Float(exp(-2 * Double.pi * Double(min(max(lowPassCutoff, 10), Float(rate / 2))) / rate))
        let n = x.first?.count ?? 0
        var start = idx
        for c in 0..<x.count {
            var w = start, zc = z[c]
            lines[c].withUnsafeMutableBufferPointer { line in
                for i in 0..<n {
                    var r = w - d; if r < 0 { r += cap }
                    let y = line[r]
                    zc = y * (1 - lp) + zc * lp
                    line[w] = x[c][i] + zc * fb
                    w += 1; if w == cap { w = 0 }
                    x[c][i] = _wetDry(x[c][i], y, mix)
                }
            }
            z[c] = zc
            if c == x.count - 1 { start = w }
        }
        idx = start
    }
}

/// Soft-clipping overdrive.
public final class _IsimDistortionKernel: _IsimInPlaceKernel {
    public var preGain: Float = -6            // dB
    public var wetDryMix: Float = 50          // %
    public var drive: Float = 8
    public override func process(_ x: inout [[Float]], rate: Double) {
        let g = Float(pow(10, Double(preGain) / 20)) * drive, mix = min(max(wetDryMix, 0), 100) / 100
        for k in 0..<x.count { x[k].withUnsafeMutableBufferPointer { b in for i in 0..<b.count { b[i] = _wetDry(b[i], Float(tanh(Double(b[i] * g))), mix) } } }
    }
}

/// Streaming linear-interpolation resampler: each output frame advances `step` input frames. The channel count is
/// that of the input.
public final class _IsimResampler {
    var buf: [[Float]] = []
    var pos = 0.0                              // in buf
    public init() {}
    public func reset() { buf = []; pos = 0 }
    public func render(_ n: Int, step: Double, pull: (Int) -> [[Float]]) -> [[Float]] {
        let s = max(1e-3, step)
        let need = Int((pos + Double(n - 1) * s).rounded(.down)) + 2
        let have = buf.first?.count ?? 0
        if need > have || buf.isEmpty { _append(&buf, pull(max(1, need - have)), max(1, need - have)) }
        let channels = buf.count
        var out = _IsimChannels.silence(channels, n)
        for c in 0..<channels {
            buf[c].withUnsafeBufferPointer { b in
                out[c].withUnsafeMutableBufferPointer { o in
                    var p = pos
                    let last = b.count - 1
                    for i in 0..<n {
                        let i0 = min(Int(p), last), i1 = min(i0 + 1, last), t = Float(p - Double(i0))
                        o[i] = b[i0] + (b[i1] - b[i0]) * t
                        p += s
                    }
                }
            }
        }
        pos += Double(n) * s
        let drop = min(Int(pos), buf.first?.count ?? 0)
        if drop > 0 { for c in 0..<channels { buf[c].removeFirst(drop) }; pos -= Double(drop) }
        return out
    }
}

/// appends exactly `k` frames of `more` to `buf` (padding with silence; the first call sets the channel count)
func _append(_ buf: inout [[Float]], _ more: [[Float]], _ k: Int) {
    if buf.isEmpty { buf = [[Float]](repeating: [], count: max(1, more.count)) }
    let m = _IsimChannels.adapt(more, to: buf.count, frames: k)
    for c in 0..<buf.count {
        if m[c].count >= k { buf[c].append(contentsOf: m[c].prefix(k)) }
        else { buf[c].append(contentsOf: m[c]); buf[c].append(contentsOf: [Float](repeating: 0, count: k - m[c].count)) }
    }
}

/// Varispeed: playback rate by resampling (pitch follows the rate, like tape).
public final class _IsimVarispeedKernel: _IsimDSPKernel {
    public var rate: Float = 1                 // 0.25...4
    public var bypass = false
    let rs = _IsimResampler()
    public init() {}
    public func reset() { rs.reset() }
    public var tailTime: Double { 0 }
    public func render(_ n: Int, rate sr: Double, pull: (Int) -> [[Float]]) -> [[Float]] {
        let r = Double(min(max(rate, 0.25), 4))
        if bypass || r == 1 { if !rs.buf.isEmpty { rs.reset() }; return pull(n) }
        return rs.render(n, step: r, pull: pull)
    }
}

/// WSOLA time stretcher (output length = input length x stretch, pitch kept), streaming: Hann windows at 50 % overlap,
/// each taken where the input best continues the previous one (cross-correlation within a quarter window).
public final class _IsimStretcher {
    var input: [[Float]] = []                  // from inputBase
    var inputBase = 0
    var out: [[Float]] = [], norm: [Float] = []    // from outBase
    var outBase = 0
    var aPos = 0.0                             // nominal analysis position of the next frame (absolute input index)
    var lastPos = -1                           // where the previous frame was taken
    var sPos = 0                               // synthesis position of the next frame (absolute output index)
    var read = 0                               // absolute output index of the next frame handed out
    var window: [Float] = []
    public init() {}
    public func reset() { input = []; inputBase = 0; out = []; norm = []; outBase = 0; aPos = 0; lastPos = -1; sPos = 0; read = 0 }
    public func render(_ n: Int, stretch: Double, rate: Double, pull: (Int) -> [[Float]]) -> [[Float]] {
        let N = max(256, Int(rate * 0.02)) & ~1
        if window.count != N { reset(); window = (0..<N).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(N))) } }
        let hs = N / 2, tol = N / 4, ha = Double(hs) / max(0.01, stretch)
        // output is final up to sPos (later frames start there)
        while sPos < read + n {
            let a = Int(aPos.rounded())
            let needEnd = max(a + tol + N, lastPos + hs + hs) - inputBase
            let have = input.first?.count ?? 0
            if needEnd > have || input.isEmpty { _append(&input, pull(max(1, needEnd - have)), max(1, needEnd - have)) }
            let channels = input.count
            var p = max(a, inputBase)
            if lastPos >= 0 {
                // the candidate that best continues the previous frame (on the first channel, every other sample)
                let target = lastPos + hs - inputBase
                var best = -Double.infinity, bestPos = p
                input[0].withUnsafeBufferPointer { x in
                    for cand in max(inputBase, a - tol)...(a + tol) {
                        let c = cand - inputBase
                        var dot = 0.0, energy = 1e-9
                        var i = 0
                        while i < hs { let v = Double(x[c + i]); dot += v * Double(x[target + i]); energy += v * v; i += 2 }
                        let score = dot / energy.squareRoot()
                        if score > best { best = score; bestPos = cand }
                    }
                }
                p = bestPos
            }
            if out.count != channels { out = [[Float]](repeating: [Float](repeating: 0, count: norm.count), count: channels) }
            let outNeed = sPos + N - outBase
            if norm.count < outNeed {
                let k = outNeed - norm.count
                for c in 0..<channels { out[c].append(contentsOf: [Float](repeating: 0, count: k)) }
                norm.append(contentsOf: [Float](repeating: 0, count: k))
            }
            let ia = p - inputBase, so = sPos - outBase
            for c in 0..<channels {
                input[c].withUnsafeBufferPointer { src in
                    out[c].withUnsafeMutableBufferPointer { dst in
                        for i in 0..<N { dst[so + i] += src[ia + i] * window[i] }
                    }
                }
            }
            for i in 0..<N { norm[so + i] += window[i] }
            lastPos = p
            sPos += hs
            aPos += ha
            // input before both the next search window and the previous frame's continuation is not needed
            let keep = min(Int(aPos.rounded()) - tol, lastPos + hs)
            let drop = keep - inputBase
            let held = input.first?.count ?? 0
            if drop > held {                                 // fast rates skip input: read past it
                _ = pull(drop - held)
                for c in 0..<channels { input[c].removeAll(keepingCapacity: true) }
                inputBase += drop
            } else if drop > 4096 { for c in 0..<channels { input[c].removeFirst(drop) }; inputBase += drop }
        }
        let channels = out.count
        var res = _IsimChannels.silence(channels, n)
        let o = read - outBase
        for c in 0..<channels {
            for i in 0..<n { let w = norm[o + i]; res[c][i] = w > 1e-3 ? out[c][o + i] / w : 0 }
        }
        read += n
        let drop = read - outBase
        if drop > 4096 { for c in 0..<channels { out[c].removeFirst(drop) }; norm.removeFirst(drop); outBase += drop }
        return res
    }
}

/// Time and pitch: rate changes speed with the pitch kept, pitch (cents) changes pitch with the speed kept.
public final class _IsimTimePitchKernel: _IsimDSPKernel {
    public var rate: Float = 1                 // 1/32...32
    public var pitch: Float = 0                // cents, -2400...2400
    public var overlap: Float = 8
    public var bypass = false
    let stretcher = _IsimStretcher(), rs = _IsimResampler()
    public init() {}
    public func reset() { stretcher.reset(); rs.reset() }
    public var tailTime: Double { 0 }
    public func render(_ n: Int, rate sr: Double, pull: (Int) -> [[Float]]) -> [[Float]] {
        let r = Double(min(max(rate, 1.0 / 32), 32)), p = pow(2, Double(min(max(pitch, -2400), 2400)) / 1200)
        if bypass || (r == 1 && p == 1) {
            if stretcher.read > 0 { reset() }
            return pull(n)
        }
        // stretch by p/r, then resample by p: length / r, pitch x p
        if p == 1 { return stretcher.render(n, stretch: 1 / r, rate: sr, pull: pull) }
        return rs.render(n, step: p) { m in self.stretcher.render(m, stretch: p / r, rate: sr, pull: pull) }
    }
}

// MARK: - buffer lists

/// isim: AudioToolbox's linear-PCM conversion for AVFoundation (buffer list <-> deinterleaved floats).
public enum _IsimPCM {
    public static func read(_ list: UnsafeMutableAudioBufferListPointer, _ d: AudioStreamBasicDescription, frames: Int) -> [[Float]] {
        _PCM.read(list, d, frames: frames)
    }
    @discardableResult
    public static func fill(_ list: UnsafeMutableAudioBufferListPointer, _ chans: [[Float]], _ d: AudioStreamBasicDescription, frames: Int) -> Int {
        _PCM.fill(list, chans, d, from: 0, count: frames)
    }
}
