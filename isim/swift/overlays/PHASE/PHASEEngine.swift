// isim PHASE: the engine, sound events and the renderer. The renderer runs on the audio thread (an AVAudioSourceNode's
// render block): it mixes every started sound event's voices to 48 kHz stereo, with gains, rates, fades and spatial
// panning evaluated once per block.
import Foundation
import AVFoundation
import simd
import QuartzCore

/// audio helpers: PCM to per-channel float arrays at 48 kHz
enum _PHASEDSP {
    static let rate = 48000.0
    static func resample(_ x: [Float], from r: Double) -> [Float] {
        guard r > 0, abs(r - rate) > 0.5, !x.isEmpty else { return x }
        let n = max(1, Int((Double(x.count) * rate / r).rounded()))
        let step = r / rate
        return (0..<n).map { i in
            let p = Double(i) * step, j = Int(p), f = Float(p - Double(j))
            return j + 1 < x.count ? x[j] * (1 - f) + x[j + 1] * f : x[min(j, x.count - 1)]
        }
    }
    static func normalized(_ ch: [[Float]], _ on: Bool) -> [[Float]] {
        guard on else { return ch }
        let peak = ch.flatMap { $0 }.reduce(Float(0)) { max($0, abs($1)) }
        return peak > 0 ? ch.map { $0.map { $0 / peak } } : ch
    }
    static func channels(_ b: AVAudioPCMBuffer, normalize: Bool) -> [[Float]] {
        let n = Int(b.frameLength), c = Int(b.format.channelCount)
        var out = [[Float]](repeating: [], count: c)
        if let f = b.floatChannelData {
            for i in 0..<c { out[i] = b.format.isInterleaved ? (0..<n).map { f[0][$0 * c + i] } : Array(UnsafeBufferPointer(start: f[i], count: n)) }
        } else if let s = b.int16ChannelData {
            for i in 0..<c { out[i] = (0..<n).map { Float(b.format.isInterleaved ? s[0][$0 * c + i] : s[i][$0]) / 32768 } }
        } else if let s = b.int32ChannelData {
            for i in 0..<c { out[i] = (0..<n).map { Float(b.format.isInterleaved ? s[0][$0 * c + i] : s[i][$0]) / 2147483648 } }
        }
        return normalized(out.map { resample($0, from: b.format.sampleRate) }, normalize)
    }
    static func channels(_ data: Data, format: AVAudioFormat, normalize: Bool) -> [[Float]]? {
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame) * (format.isInterleaved ? 1 : Int(format.channelCount))
        guard bytesPerFrame > 0, let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count / bytesPerFrame)) else { return nil }
        b.frameLength = b.frameCapacity
        let list = UnsafeMutableAudioBufferListPointer(b.mutableAudioBufferList)
        data.withUnsafeBytes { raw in
            var offset = 0
            for buf in list {
                guard let d = buf.mData else { continue }
                let n = min(Int(buf.mDataByteSize), raw.count - offset)
                if n > 0 { d.copyMemory(from: raw.baseAddress! + offset, byteCount: n) }
                offset += n
            }
        }
        return channels(b, normalize: normalize)
    }
}

// MARK: - sound events

/// an instance of a sound event asset: its voices, mixers, meta parameters and stream nodes
@objc(PHASESoundEvent) open class PHASESoundEvent: NSObject, @unchecked Sendable {
    @objc(PHASESoundEventPrepareHandlerReason) public enum PrepareHandlerReason: Int, Sendable { case failure = 0, prepared = 1, terminated = 2 }
    @objc(PHASESoundEventPrepareState) public enum PrepareState: Int, Sendable { case prepareNotStarted = 0, prepareInProgress = 1, prepared = 2 }
    @objc(PHASERenderingState) public enum RenderingState: Int, Sendable { case stopped = 0, started = 1, paused = 2 }
    @objc(PHASESoundEventStartHandlerReason) public enum StartHandlerReason: Int, Sendable { case failure = 0, finishedPlaying = 1, terminated = 2 }
    @objc(PHASESoundEventSeekHandlerReason) public enum SeekHandlerReason: Int, Sendable { case failure = 0, failureSeekAlreadyInProgress = 1, seekSuccessful = 2 }

    weak var engine: PHASEEngine?
    let root: PHASESoundEventNodeDefinition
    let parameters: PHASEMixerParameters?
    @objc public let mixers: [String: PHASEMixer]
    @objc public let metaParameters: [String: PHASEMetaParameter]
    @objc public let pushStreamNodes: [String: PHASEPushStreamNode]
    @objc public let pullStreamNodes: [String: PHASEPullStreamNode]
    @objc open private(set) var prepareState: PrepareState = .prepareNotStarted
    @objc open internal(set) var renderingState: RenderingState = .stopped
    var _voices: [_PHASEVoice] = []
    var _onFinish: ((StartHandlerReason) -> Void)?
    var _startFrame: Int64 = 0

    @objc public convenience init(engine: PHASEEngine, assetIdentifier: String) throws { try self.init(engine: engine, assetIdentifier: assetIdentifier, mixerParameters: nil) }
    @objc public init(engine: PHASEEngine, assetIdentifier: String, mixerParameters: PHASEMixerParameters?) throws {
        guard let asset = engine.assetRegistry.asset(forIdentifier: assetIdentifier) as? PHASESoundEventNodeAsset else { throw PHASESoundEventError(.notFound) }
        self.engine = engine; root = asset.root; parameters = mixerParameters
        var mixers: [String: PHASEMixer] = [:], metas: [String: PHASEMetaParameter] = [:]
        var push: [String: PHASEPushStreamNode] = [:], pull: [String: PHASEPullStreamNode] = [:]
        let globals = engine.assetRegistry.globalMetaParameters
        func meta(_ d: PHASEMetaParameterDefinition?) -> PHASEMetaParameter? {
            guard let d else { return nil }
            if let m = metas[d.identifier] { return m }
            let m = globals[d.identifier] ?? d._instance()
            if let mapped = d as? PHASEMappedMetaParameterDefinition, let input = meta(mapped.inputMetaParameterDefinition) as? PHASENumberMetaParameter {
                (m as? PHASENumberMetaParameter)?._mapped = (input, mapped.envelope)
            }
            metas[d.identifier] = m
            return m
        }
        func visit(_ n: PHASESoundEventNodeDefinition) throws {
            if let g = n as? PHASEGeneratorNodeDefinition {
                let md = g.mixerDefinition
                if mixers[md.identifier] == nil { mixers[md.identifier] = PHASEMixer(md, meta: meta(md.gainMetaParameterDefinition)) }
                if md is PHASESpatialMixerDefinition, mixerParameters?.spatial[md.identifier] == nil { throw PHASESoundEventError(.apiMisuse) }
                if md is PHASEAmbientMixerDefinition, mixerParameters?.ambient[md.identifier] == nil { throw PHASESoundEventError(.apiMisuse) }
                if let s = md as? PHASESpatialMixerDefinition { for e in s.spatialPipeline.entries.values { _ = meta(e.sendLevelMetaParameterDefinition) } }
                let gain = meta(g.gainMetaParameterDefinition) as? PHASENumberMetaParameter, rate = meta(g.rateMetaParameterDefinition) as? PHASENumberMetaParameter
                if let p = g as? PHASEPushStreamNodeDefinition { push[p.identifier] = PHASEPushStreamNode(format: p.format, mixer: mixers[md.identifier]!, gain: gain, rate: rate) }
                if let p = g as? PHASEPullStreamNodeDefinition { pull[p.identifier] = PHASEPullStreamNode(format: p.format, mixer: mixers[md.identifier]!, gain: gain, rate: rate) }
            }
            if let s = n as? PHASESwitchNodeDefinition { _ = meta(s.switchMetaParameterDefinition) }
            if let b = n as? PHASEBlendNodeDefinition { _ = meta(b.blendParameterDefinition) }
            for c in n.children { try visit(c) }
        }
        try visit(root)
        self.mixers = mixers; metaParameters = metas; pushStreamNodes = push; pullStreamNodes = pull
    }

    /// loops, streams: the event plays until stopped
    @objc open var isIndefinite: Bool {
        func indefinite(_ n: PHASESoundEventNodeDefinition) -> Bool {
            if let s = n as? PHASESamplerNodeDefinition { return s.playbackMode == .looping }
            if n is PHASEPushStreamNodeDefinition || n is PHASEPullStreamNodeDefinition { return true }
            return n.children.contains(where: indefinite)
        }
        return indefinite(root)
    }

    @objc(prepareWithCompletion:) open func prepare(completion: ((PrepareHandlerReason) -> Void)? = nil) {
        prepareState = .prepared
        DispatchQueue.main.async { completion?(.prepared) }
    }
    @objc(startWithCompletion:) open func start(completion: ((StartHandlerReason) -> Void)? = nil) { start(at: nil, completion: completion) }
    /// starts at an engine time (its sample time, in the engine's 48 kHz frames), or now
    @objc(startAtTime:completion:) open func start(at when: AVAudioTime?, completion: ((StartHandlerReason) -> Void)? = nil) {
        guard let engine, renderingState == .stopped, _voices.isEmpty else { DispatchQueue.main.async { completion?(.failure) }; return }
        prepareState = .prepared
        _onFinish = completion
        engine._start(self, at: when)
    }
    @objc open func pause() { engine?._lock.lock(); if renderingState == .started { renderingState = .paused }; engine?._lock.unlock() }
    @objc open func resume() { resume(at: nil) }
    @objc(resumeAtTime:) open func resume(at when: AVAudioTime?) {
        engine?._lock.lock()
        if renderingState == .paused { renderingState = .started; if let t = when, t.isSampleTimeValid { _startFrame = t.sampleTime } }
        engine?._lock.unlock()
    }
    @objc(seekToTime:completion:) open func seek(to time: Double, completion: ((SeekHandlerReason) -> Void)? = nil) {
        guard let engine else { completion?(.failure); return }
        engine._lock.lock()
        for v in _voices where v.sound != nil { v.pos = max(0, time) * _PHASEDSP.rate; v.done = false }
        engine._lock.unlock()
        DispatchQueue.main.async { completion?(.seekSuccessful) }
    }
    @objc(seekToTime:resumeAtEngineTime:completion:) open func seek(to time: Double, resumeAt: AVAudioTime, completion: ((SeekHandlerReason) -> Void)? = nil) {
        seek(to: time, completion: completion)
        resume(at: resumeAt)
    }
    @objc open func stopAndInvalidate() { engine?._finish(self, .terminated) }
}

/// one sound a started event plays (a sampler or a stream), with the weights of the switch and blend nodes above it
final class _PHASEVoice {
    let generator: PHASEGeneratorNodeDefinition
    let mixer: PHASEMixer
    var sound: [[Float]]?
    var looping = false
    var push: PHASEPushStreamNode?
    var pull: PHASEPullStreamNode?
    var pos: Double = 0
    var done = false
    var weights: [(PHASESoundEvent) -> Double] = []
    let gain: PHASENumberMetaParameter?
    let rate: PHASENumberMetaParameter?
    init(_ g: PHASEGeneratorNodeDefinition, _ m: PHASEMixer, gain: PHASENumberMetaParameter?, rate: PHASENumberMetaParameter?) {
        generator = g; mixer = m; self.gain = gain; self.rate = rate
    }
}

// MARK: - the engine

@objc(PHASEEngine) open class PHASEEngine: NSObject, @unchecked Sendable {
    @objc(PHASEUpdateMode) public enum UpdateMode: Int, Sendable { case automatic = 0, manual = 1 }
    @objc(PHASERenderingMode) public enum RenderingMode: Int, Sendable { case local = 0, client = 1 }

    let _lock = NSRecursiveLock()
    let updateMode: UpdateMode
    @objc public let assetRegistry = PHASEAssetRegistry()
    @objc public let rootObject = PHASEObject(_root: nil)
    @objc open var defaultReverbPreset: PHASEReverbPreset = .none
    @objc open var defaultMedium = PHASEMedium(_preset: .air)
    @objc open var outputSpatializationMode: PHASESpatializationMode = .automatic
    @objc open var unitsPerMeter: Double = 1 { didSet { if unitsPerMeter <= 0 { unitsPerMeter = 1 } } }
    @objc open var unitsPerSecond: Double = 1 { didSet { if unitsPerSecond <= 0 { unitsPerSecond = 1 } } }
    @objc open private(set) var renderingState: PHASESoundEvent.RenderingState = .stopped
    @objc open private(set) var lastRenderTime: AVAudioTime?
    var _groups: [String: PHASEGroup] = [:]
    var _duckers: [PHASEDucker] = []
    var _events: [PHASESoundEvent] = []
    weak var _activePreset: PHASEGroupPreset?
    /// the transforms the renderer uses: refreshed every block (automatic) or by update() (manual)
    var _applied: [ObjectIdentifier: simd_float4x4] = [:]
    var _frame: Int64 = 0
    var _audio: AVAudioEngine?
    var _node: AVAudioSourceNode?

    @objc public convenience init(updateMode: UpdateMode) { self.init(updateMode: updateMode, renderingMode: .local) }
    /// client rendering (an app that renders PHASE itself) is like local on isim
    @objc public init(updateMode: UpdateMode, renderingMode: RenderingMode) {
        self.updateMode = updateMode
        super.init()
        rootObject._engine = self
    }

    @objc open var groups: [String: PHASEGroup] { _lock.lock(); defer { _lock.unlock() }; return _groups }
    @objc open var duckers: [PHASEDucker] { _lock.lock(); defer { _lock.unlock() }; return _duckers }
    @objc open var soundEvents: [PHASESoundEvent] { _lock.lock(); defer { _lock.unlock() }; return _events }
    @objc open var activeGroupPreset: PHASEGroupPreset? { _activePreset }

    /// starts rendering: 48 kHz stereo through isim's AVAudioEngine
    @objc(startAndReturnError:) open func start() throws {
        _lock.lock(); defer { _lock.unlock() }
        if renderingState == .started { return }
        if _audio == nil {
            let e = AVAudioEngine()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: _PHASEDSP.rate, channels: 2) else { throw PHASEError(.initializeFailed) }
            let node = AVAudioSourceNode(format: format) { [weak self] silence, time, frames, list in
                self?._render(Int(frames), list, silence) ?? noErr
            }
            e.attach(node)
            e.connect(node, to: e.mainMixerNode, format: format)
            _audio = e; _node = node
        }
        do { try _audio!.start() } catch { throw PHASEError(.initializeFailed) }
        _snapshot()
        renderingState = .started
        NSLog("isim PHASE: engine started (%@ updates)", updateMode == .manual ? "manual" : "automatic")
    }
    @objc open func pause() { _lock.lock(); if renderingState == .started { _audio?.pause(); renderingState = .paused }; _lock.unlock() }
    @objc open func stop() {
        _lock.lock()
        _audio?.stop(); renderingState = .stopped
        let events = _events
        _lock.unlock()
        for e in events { _finish(e, .terminated) }
    }
    /// manual update mode: the scene changes made since the last update take effect now
    @objc open func update() { _lock.lock(); _snapshot(); _lock.unlock() }

    func _snapshot() {
        var t: [ObjectIdentifier: simd_float4x4] = [:]
        func walk(_ o: PHASEObject) { t[ObjectIdentifier(o)] = o._world; o.children.forEach(walk) }
        walk(rootObject)
        _applied = t
    }
    /// an object's world transform as the renderer sees it (objects outside the tree are at their own transform)
    func _worldNow(_ o: PHASEObject) -> simd_float4x4 { _applied[ObjectIdentifier(o)] ?? o._world }

    // MARK: event lifecycle

    func _start(_ e: PHASESoundEvent, at when: AVAudioTime?) {
        var voices: [_PHASEVoice] = []
        func build(_ n: PHASESoundEventNodeDefinition, _ weights: [(PHASESoundEvent) -> Double]) {
            switch n {
            case let s as PHASESamplerNodeDefinition:
                guard let sound = assetRegistry.asset(forIdentifier: s.assetIdentifier) as? PHASESoundAsset else { return }
                let v = _PHASEVoice(s, e.mixers[s.mixerDefinition.identifier]!, gain: s.gainMetaParameterDefinition.flatMap { e.metaParameters[$0.identifier] as? PHASENumberMetaParameter },
                                    rate: s.rateMetaParameterDefinition.flatMap { e.metaParameters[$0.identifier] as? PHASENumberMetaParameter })
                v.sound = sound._channels; v.looping = s.playbackMode == .looping; v.weights = weights
                voices.append(v)
            case let p as PHASEPushStreamNodeDefinition:
                guard let node = e.pushStreamNodes[p.identifier] else { return }
                let v = _PHASEVoice(p, node.mixer, gain: node.gainMetaParameter, rate: node.rateMetaParameter); v.push = node; v.weights = weights
                voices.append(v)
            case let p as PHASEPullStreamNodeDefinition:
                guard let node = e.pullStreamNodes[p.identifier] else { return }
                let v = _PHASEVoice(p, node.mixer, gain: node.gainMetaParameter, rate: node.rateMetaParameter); v.pull = node; v.weights = weights
                voices.append(v)
            case let s as PHASESwitchNodeDefinition:
                let id = s.switchMetaParameterDefinition.identifier
                for (child, value) in zip(s.children, s.values) {
                    build(child, weights + [{ ev in (ev.metaParameters[id] as? PHASEStringMetaParameter)?._string == value ? 1 : 0 }])
                }
            case let r as PHASERandomNodeDefinition:
                if let i = r._pick() { build(r.children[i], weights) }
            case let b as PHASEBlendNodeDefinition:
                for (child, env) in zip(b.children, b.envelopes) {
                    if let p = b.blendParameterDefinition {
                        let id = p.identifier
                        build(child, weights + [{ ev in env.evaluate(x: (ev.metaParameters[id] as? PHASENumberMetaParameter)?._number ?? 0) }])
                    } else if let d = b.spatialMixerDefinitionForDistance {
                        let id = d.identifier
                        build(child, weights + [{ [weak self] ev in
                            guard let self, let (src, lis) = ev.parameters?.spatial[id] else { return 1 }
                            return env.evaluate(x: self._geometry(src, lis).distance)
                        }])
                    }
                }
            default:
                for c in n.children { build(c, weights) }
            }
        }
        _lock.lock()
        build(e.root, [])
        e._voices = voices
        e._startFrame = when.flatMap { $0.isSampleTimeValid ? $0.sampleTime : nil } ?? _frame
        e.renderingState = .started
        _events.append(e)
        _lock.unlock()
    }
    func _finish(_ e: PHASESoundEvent, _ reason: PHASESoundEvent.StartHandlerReason) {
        _lock.lock()
        guard let i = _events.firstIndex(where: { $0 === e }) else { _lock.unlock(); return }
        _events.remove(at: i)
        e.renderingState = .stopped
        e._voices = []
        let done = e._onFinish; e._onFinish = nil
        _lock.unlock()
        DispatchQueue.main.async { done?(reason) }
    }

    // MARK: rendering

    /// the source as the listener hears it: distance in meters, the listener-space direction, the angles off the
    /// source's and the listener's forward axes
    func _geometry(_ s: PHASESource, _ l: PHASEListener) -> (distance: Double, direction: simd_float3, sourceAngle: Double, listenerAngle: Double) {
        let sw = _worldNow(s), lw = _worldNow(l)
        let sp = simd_float3(sw.columns.3.x, sw.columns.3.y, sw.columns.3.z), lp = simd_float3(lw.columns.3.x, lw.columns.3.y, lw.columns.3.z)
        let local = lw.inverse * simd_float4(sp, 1)
        let dir = simd_float3(local.x, local.y, local.z)
        let len = simd_length(dir)
        let unit = len > 1e-6 ? dir / len : simd_float3(0, 0, -1)
        let forward = PHASEObject.forward
        let listenerAngle = Double(acos(max(-1, min(1, simd_dot(unit, forward)))))
        // the source's forward axis in the world against the direction from the source to the listener
        let sf = simd_normalize(simd_float3(sw.columns.2.x, sw.columns.2.y, sw.columns.2.z) * -1)
        let toListener = simd_length(lp - sp) > 1e-6 ? simd_normalize(lp - sp) : sf
        let sourceAngle = Double(acos(max(-1, min(1, simd_dot(sf, toListener)))))
        return (Double(len) / unitsPerMeter, unit, sourceAngle, listenerAngle)
    }

    /// per-channel gains of a voice's mixer (left, right), or nil when it is culled
    func _pan(_ v: _PHASEVoice, _ e: PHASESoundEvent, channels: Int) -> (Float, Float, culled: Bool) {
        let md = v.mixer.definition
        var g = v.mixer.gain * md.gain * ((v.mixer.gainMetaParameter as? PHASENumberMetaParameter)?._number ?? 1)
        switch md {
        case let s as PHASESpatialMixerDefinition:
            guard let (src, lis) = e.parameters?.spatial[md.identifier] else { return (0, 0, true) }
            let geo = _geometry(src, lis)
            let dist = s.distanceModelParameters?._total(geo.distance) ?? 1
            if let f = s.distanceModelParameters?.fadeOutParameters, geo.distance >= f.cullDistance { return (0, 0, true) }
            g *= dist * src.gain * lis.gain
            g *= s.sourceDirectivityModelParameters?._gain(geo.sourceAngle) ?? 1
            g *= s.listenerDirectivityModelParameters?._gain(geo.listenerAngle) ?? 1
            if let direct = s.spatialPipeline.entries[.directPathTransmission] {
                g *= direct.sendLevelMetaParameterDefinition.flatMap { (e.metaParameters[$0.identifier] as? PHASENumberMetaParameter)?._number } ?? direct.sendLevel
            } else { g = 0 }
            // equal-power panning by the direction's x (right of the listener)
            let x = Double(max(-1, min(1, geo.direction.x)))
            let a = (x + 1) * .pi / 4
            return (Float(g * cos(a)), Float(g * sin(a)), false)
        case is PHASEAmbientMixerDefinition:
            if let lis = e.parameters?.ambient[md.identifier] { g *= lis.gain }
            fallthrough
        default:
            // channel and ambient mixers: mono to the centre (equal power), stereo as it is
            let k = channels == 1 ? Float(g * sqrt(0.5)) : Float(g)
            return (k, k, false)
        }
    }

    func _render(_ frames: Int, _ list: UnsafeMutablePointer<AudioBufferList>, _ silence: UnsafeMutablePointer<ObjCBool>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(list)
        let outL = abl[0].mData!.assumingMemoryBound(to: Float.self)
        let outR = abl.count > 1 ? abl[1].mData!.assumingMemoryBound(to: Float.self) : outL
        for i in 0..<frames { outL[i] = 0; outR[i] = 0 }
        var finished: [PHASESoundEvent] = []
        _lock.lock()
        if updateMode == .automatic { _snapshot() }
        let now = _frame
        let anySolo = _groups.values.contains { $0.isSoloed }
        for d in _duckers where d.isActive {
            let playing = _events.contains { $0.renderingState == .started && $0._voices.contains { v in !v.done && v.generator.group.map { d.sourceGroups.contains($0) } ?? false } }
            d._set(playing)
        }
        for e in _events where e.renderingState == .started {
            let offset = max(0, Int(e._startFrame - now))
            guard offset < frames else { continue }
            for v in e._voices where !v.done {
                let weight = v.weights.reduce(1.0) { $0 * $1(e) }
                var group = (gain: 1.0, rate: 1.0)
                if let gr = v.generator.group {
                    group = gr._now
                    if gr.isMuted || (anySolo && !gr.isSoloed) { group.gain = 0 }
                    for d in _duckers where d.isActive && d.targetGroups.contains(gr) { group.gain *= d._now }
                }
                let channels = v.sound?.count ?? Int(v.push?.format.channelCount ?? v.pull?.format.channelCount ?? 1)
                let (pl, pr, culled) = _pan(v, e, channels: channels)
                if culled && v.generator is PHASESamplerNodeDefinition && (v.generator as! PHASESamplerNodeDefinition).cullOption == .terminate && !v.looping {
                    v.done = true; continue
                }
                let k = Float(weight * group.gain * v.generator._calibrationGain * (v.gain?._number ?? 1))
                let l = pl * k, r = pr * k
                if let sound = v.sound {
                    let step = max(0.01, v.generator.rate * group.rate * (v.rate?._number ?? 1))
                    let n = sound[0].count
                    let left = sound[0], right = sound.count > 1 ? sound[1] : sound[0]
                    for i in offset..<frames {
                        var j = Int(v.pos)
                        if j >= n { if v.looping && n > 0 { v.pos -= Double(n); j = Int(v.pos) } else { v.done = true; break } }
                        outL[i] += left[j] * l; outR[i] += right[j] * r
                        v.pos += step
                    }
                } else if let p = v.push {
                    p._lock.lock()
                    var i = offset
                    while i < frames, let item = p._queue.first {
                        if let at = item.at, at > now + Int64(i) { i = min(frames, Int(at - now)); continue }
                        let left = item.channels[0], right = item.channels.count > 1 ? item.channels[1] : left
                        while i < frames && p._pos < left.count {
                            outL[i] += left[p._pos] * l; outR[i] += right[p._pos] * r
                            p._pos += 1; i += 1
                        }
                        if p._pos >= left.count {
                            p._pos = 0
                            if !item.options.contains(.loops) {
                                p._queue.removeFirst()
                                if let done = item.done { DispatchQueue.main.async { done(.dataRendered) } }
                            }
                        }
                    }
                    p._lock.unlock()
                } else if let p = v.pull {
                    let handler = p.renderHandler
                    let ch = Int(p.format.channelCount)
                    let n = frames - offset
                    let tmp = AudioBufferList.allocate(maximumBuffers: ch)
                    var store = [[Float]](repeating: [Float](repeating: 0, count: n), count: ch)
                    var quiet: ObjCBool = false
                    var ts = AudioTimeStamp(); ts.mSampleTime = Double(now + Int64(offset)); ts.mFlags = .sampleTimeValid
                    store.withUnsafeMutableBufferPointer { bufs in
                        for c in 0..<ch {
                            bufs[c].withUnsafeMutableBufferPointer { b in
                                tmp[c] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(n * 4), mData: UnsafeMutableRawPointer(b.baseAddress))
                            }
                        }
                        _ = handler(&quiet, &ts, AVAudioFrameCount(n), tmp.unsafeMutablePointer)
                        if !quiet.boolValue {
                            for c in 0..<ch {
                                let src = tmp[c].mData!.assumingMemoryBound(to: Float.self)
                                for i in 0..<n {
                                    if c == 0 || ch == 1 { outL[offset + i] += src[i] * l }
                                    if c == 1 || ch == 1 { outR[offset + i] += src[i] * r }
                                }
                            }
                        }
                    }
                    tmp.unsafeMutablePointer.deallocate()
                }
            }
            if e._voices.allSatisfy({ $0.done }) { finished.append(e) }
        }
        _frame += Int64(frames)
        lastRenderTime = AVAudioTime(sampleTime: _frame, atRate: _PHASEDSP.rate)
        _lock.unlock()
        for e in finished { _finish(e, .finishedPlaying) }
        silence.pointee = false
        return noErr
    }
}
