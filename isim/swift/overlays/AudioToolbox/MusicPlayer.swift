// isim AudioToolbox: Music Players (NewMusicPlayer and friends). Adapted: a player thread wakes every 2 ms, finds
// the events of each track between the last position and now (through the sequence's tempo map, scaled by the play
// rate, with track offsets, loops, mute and solo) and sends them to the track's destination:
// - an AVFoundation instrument (AVAudioSequencer's tracks), as MIDI bytes;
// - a MIDI endpoint, through a CoreMIDI output port;
// - an AUGraph node (MusicDeviceMIDIEvent, AudioUnitSetParameter), or the sequence's default graph (a MIDISynth into
//   RemoteIO) when the track has no destination.
// Notes send their note offs after their durations; user events call the sequence's user callback; stopping sends
// all notes off to every destination used.
import Foundation
import CoreMIDI

/// a destination's sender
struct _MusicSink {
    let send: ([UInt8]) -> Void
    let parameter: ((ParameterEvent) -> Void)?
}

public final class _MusicPlayer: @unchecked Sendable {
    public var sequence: _MusicSequence?
    public internal(set) var playing = false
    public var position: MusicTimeStamp = 0            // beats, when stopped
    var startBeat: MusicTimeStamp = 0, startHost: UInt64 = 0
    public var rate: Double = 1
    var lastBeat: MusicTimeStamp = 0
    var pendingOffs: [(beat: MusicTimeStamp, sink: Int, bytes: [UInt8])] = []
    var sinks: [_MusicSink] = []
    var sinkIndex: [ObjectIdentifier: Int] = [:]
    var thread: Thread?
    let lock = NSRecursiveLock()
    var generation = 0
    /// called (on the player thread) when every track has played to its end; AVMIDIPlayer's completion
    public var onEnd: (() -> Void)?
    public var stopsAtEnd = false
    public var handle: MusicPlayer { MusicPlayer(Unmanaged.passUnretained(self).toOpaque()) }
    public static func from(_ h: MusicPlayer) -> _MusicPlayer { Unmanaged<_MusicPlayer>.fromOpaque(UnsafeRawPointer(h)).takeUnretainedValue() }

    public init() {}
    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

    /// the current position in beats
    public var currentBeat: MusicTimeStamp {
        lock.lock(); defer { lock.unlock() }
        guard playing, let s = sequence else { return position }
        let elapsed = Double(Self.now() - startHost) / 1e9 * rate
        return s.beats(forSeconds: s.seconds(forBeats: startBeat) + elapsed)
    }
    public func hostTime(forBeats b: MusicTimeStamp) -> UInt64? {
        lock.lock(); defer { lock.unlock() }
        guard playing, let s = sequence else { return nil }
        let dt = (s.seconds(forBeats: b) - s.seconds(forBeats: startBeat)) / rate
        return UInt64(max(0, Double(startHost) + dt * 1e9))
    }
    public func beats(forHostTime h: UInt64) -> MusicTimeStamp? {
        lock.lock(); defer { lock.unlock() }
        guard playing, let s = sequence else { return nil }
        let dt = (Double(h) - Double(startHost)) / 1e9 * rate
        return s.beats(forSeconds: s.seconds(forBeats: startBeat) + dt)
    }

    // MARK: destinations

    nonisolated(unsafe) static var midiClient: MIDIClientRef = 0, midiPort: MIDIPortRef = 0

    func sink(for t: _MusicTrack) -> Int? {
        if let i = sinkIndex[ObjectIdentifier(t)] { return i }
        guard let s = sequence else { return nil }
        var made: _MusicSink?
        if let f = t.sink {
            made = _MusicSink(send: f, parameter: nil)
        } else if t.destEndpoint != 0 {
            if Self.midiPort == 0 {
                MIDIClientCreate("Music Player" as CFString, nil, nil, &Self.midiClient)
                MIDIOutputPortCreate(Self.midiClient, "Music Player" as CFString, &Self.midiPort)
            }
            let ep = t.destEndpoint
            made = _MusicSink(send: { bytes in
                let list = MIDIPacketList.Builder(byteSize: 64 + bytes.count)
                list.append(timestamp: 0, data: bytes)
                list.withUnsafePointer { _ = MIDISend(Self.midiPort, ep, $0) }
            }, parameter: nil)
        } else {
            var node = t.destNode
            if node == 0 {
                // no destination: the sequence's graph (made if needed) and its first music device
                var g: AUGraph?
                _ = MusicSequenceGetAUGraph(s.handle, &g)
                node = t.destNode
                if node == 0, let g { node = _firstMusicDevice(g) }
            }
            var unit: AudioUnit?
            if let g = s.graph, node != 0, AUGraphNodeInfo(g, node, nil, &unit) == noErr_, let unit {
                made = _MusicSink(send: { bytes in
                    if bytes.first == 0xF0 { bytes.withUnsafeBufferPointer { _ = MusicDeviceSysEx(unit, $0.baseAddress!, UInt32(bytes.count)) } }
                    else { _ = MusicDeviceMIDIEvent(unit, UInt32(bytes[0]), UInt32(bytes.count > 1 ? bytes[1] : 0), UInt32(bytes.count > 2 ? bytes[2] : 0), 0) }
                }, parameter: { p in _ = AudioUnitSetParameter(unit, p.parameterID, p.scope, p.element, p.value, 0) })
            }
        }
        guard let made else { return nil }
        sinks.append(made)
        sinkIndex[ObjectIdentifier(t)] = sinks.count - 1
        return sinks.count - 1
    }

    // MARK: playing

    public func start() -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        guard let s = sequence else { return kAudioToolboxErr_NoSequence }
        if playing { return noErr_ }
        // the default graph plays (an AUGraph the app made is started by the app)
        if s.ownsGraph, let g = s.graph { var running = DarwinBoolean(false); _ = AUGraphIsRunning(g, &running); if !running.boolValue { _ = AUGraphStart(g) } }
        sinks = []; sinkIndex = [:]; pendingOffs = []
        startBeat = position; lastBeat = position
        startHost = Self.now()
        playing = true
        generation += 1
        let gen = generation
        let th = Thread { [weak self] in
            while let self, self.tick(gen) { usleep(2000) }
        }
        th.name = "com.apple.musicplayer"
        th.qualityOfService = .userInteractive
        thread = th
        th.start()
        return noErr_
    }
    public func stop() {
        lock.lock(); defer { lock.unlock() }
        guard playing else { return }
        position = currentBeat
        playing = false
        generation += 1
        flushNotes()
    }
    func flushNotes() {
        for off in pendingOffs where off.sink < sinks.count { sinks[off.sink].send(off.bytes) }
        pendingOffs = []
        for s in sinks { for ch in 0..<16 { s.send([0xB0 | UInt8(ch), 123, 0]); s.send([0xB0 | UInt8(ch), 120, 0]) } }
    }

    /// one wake of the player thread; false when it should end
    func tick(_ gen: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard playing, gen == generation, let s = sequence else { return false }
        let now = currentBeat
        guard now > lastBeat else { return true }
        let window = lastBeat..<now
        // note offs due
        let due = pendingOffs.filter { $0.beat < now }
        pendingOffs.removeAll { $0.beat < now }
        for off in due where off.sink < sinks.count { sinks[off.sink].send(off.bytes) }
        let anySolo = s.tracks.contains { $0.soloed }
        for t in s.tracks where !t.muted && (!anySolo || t.soloed) {
            for (e, at) in occurrences(t, in: window) { play(e, at: at, track: t, sequence: s) }
        }
        // tempo track: user events there too
        for (e, at) in occurrences(s.tempoTrack, in: window) where e.type == kMusicEventType_User { play(e, at: at, track: s.tempoTrack, sequence: s) }
        lastBeat = now
        if stopsAtEnd, pendingOffs.isEmpty, now >= s.length {
            playing = false
            position = s.length
            generation += 1
            let end = onEnd
            DispatchQueue.global().async { end?() }
            return false
        }
        return true
    }

    /// a track's events in a window of sequence beats (offset and looped), with the beat each plays at
    func occurrences(_ t: _MusicTrack, in w: Range<MusicTimeStamp>) -> [(_MusicEvent, MusicTimeStamp)] {
        let a = w.lowerBound - t.offsetTime, b = w.upperBound - t.offsetTime
        guard b > 0 else { return [] }
        let loop = t.loopInfo.loopDuration
        if loop <= 0 {
            return t.events(in: max(0, a)..<b).map { ($0, $0.time + t.offsetTime) }
        }
        var out: [(_MusicEvent, MusicTimeStamp)] = []
        let loops = t.loopInfo.numberOfLoops                      // 0: forever
        var k = max(0, Int(floor(a / loop)))
        while Double(k) * loop < b {
            if loops > 0 && k >= Int(loops) { break }
            let base = Double(k) * loop
            for e in t.events(in: max(0, a - base)..<min(loop, b - base)) { out.append((e, e.time + base + t.offsetTime)) }
            k += 1
        }
        return out
    }

    func play(_ e: _MusicEvent, at beat: MusicTimeStamp, track t: _MusicTrack, sequence s: _MusicSequence) {
        switch e.type {
        case kMusicEventType_User:
            if let (cb, data) = s.userCallback {
                let ud = e.bytes.assumingMemoryBound(to: MusicEventUserData.self)
                cb(data, s.handle, t.handle, e.time, ud, lastBeat, beat)
            }
            return
        case kMusicEventType_Meta, kMusicEventType_ExtendedTempo, kMusicEventType_AUPreset: return
        default: break
        }
        guard let si = sink(for: t) else { return }
        let sk = sinks[si]
        switch e.type {
        case kMusicEventType_MIDINoteMessage:
            let m = e.noteMessage
            let ch = m.channel & 0x0F
            sk.send([0x90 | ch, m.note & 0x7F, max(1, m.velocity & 0x7F)])
            pendingOffs.append((beat + Double(m.duration), si, [0x80 | ch, m.note & 0x7F, m.releaseVelocity & 0x7F]))
        case kMusicEventType_MIDIChannelMessage:
            let m = e.channelMessage
            let two = m.status & 0xF0 == 0xC0 || m.status & 0xF0 == 0xD0
            sk.send(two ? [m.status, m.data1 & 0x7F] : [m.status, m.data1 & 0x7F, m.data2 & 0x7F])
        case kMusicEventType_MIDIRawData:
            let d = e.variableData
            if !d.isEmpty { sk.send(d) }
        case kMusicEventType_ExtendedNote:
            let n = e.bytes.load(as: ExtendedNoteOnEvent.self)
            let ch = UInt8(n.groupID & 0x0F), key = UInt8(max(0, min(127, Int(n.extendedParams.mPitch.rounded()))))
            sk.send([0x90 | ch, key, UInt8(max(1, min(127, Int(n.extendedParams.mVelocity))))])
            pendingOffs.append((beat + Double(n.duration), si, [0x80 | ch, key, 0]))
        case kMusicEventType_Parameter:
            sk.parameter?(e.bytes.load(as: ParameterEvent.self))
        default: break
        }
    }
}

/// the first music device node of a graph
public func _firstMusicDevice(_ g: AUGraph) -> AUNode {
    var count: UInt32 = 0
    _ = AUGraphGetNodeCount(g, &count)
    for i in 0..<count {
        var node = AUNode()
        var d = AudioComponentDescription()
        if AUGraphGetIndNode(g, i, &node) == noErr_, AUGraphNodeInfo(g, node, &d, nil) == noErr_, d.componentType == kAudioUnitType_MusicDevice { return node }
    }
    return 0
}

public func NewMusicPlayer(_ outPlayer: UnsafeMutablePointer<MusicPlayer?>) -> OSStatus {
    outPlayer.pointee = MusicPlayer(Unmanaged.passRetained(_MusicPlayer()).toOpaque())
    return noErr_
}
public func DisposeMusicPlayer(_ inPlayer: MusicPlayer) -> OSStatus {
    let p = _MusicPlayer.from(inPlayer)
    p.stop()
    Unmanaged<_MusicPlayer>.fromOpaque(UnsafeRawPointer(inPlayer)).release()
    return noErr_
}
public func MusicPlayerSetSequence(_ inPlayer: MusicPlayer, _ inSequence: MusicSequence?) -> OSStatus {
    let p = _MusicPlayer.from(inPlayer)
    p.stop()
    p.lock.lock(); p.sequence = inSequence.map { _MusicSequence.from($0) }; p.position = 0; p.lock.unlock()
    return noErr_
}
public func MusicPlayerGetSequence(_ inPlayer: MusicPlayer, _ outSequence: UnsafeMutablePointer<MusicSequence?>) -> OSStatus {
    guard let s = _MusicPlayer.from(inPlayer).sequence else { return kAudioToolboxErr_NoSequence }
    outSequence.pointee = s.handle
    return noErr_
}
public func MusicPlayerSetTime(_ inPlayer: MusicPlayer, _ inTime: MusicTimeStamp) -> OSStatus {
    let p = _MusicPlayer.from(inPlayer)
    p.lock.lock(); defer { p.lock.unlock() }
    let wasPlaying = p.playing
    if wasPlaying { p.stop() }
    p.position = max(0, inTime)
    if wasPlaying { return p.start() }
    return noErr_
}
public func MusicPlayerGetTime(_ inPlayer: MusicPlayer, _ outTime: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus {
    let p = _MusicPlayer.from(inPlayer)
    guard p.sequence != nil else { return kAudioToolboxErr_NoSequence }
    outTime.pointee = p.currentBeat
    return noErr_
}
public func MusicPlayerGetHostTimeForBeats(_ inPlayer: MusicPlayer, _ inBeats: MusicTimeStamp, _ outHostTime: UnsafeMutablePointer<UInt64>) -> OSStatus {
    guard let h = _MusicPlayer.from(inPlayer).hostTime(forBeats: inBeats) else { return kAudioToolboxErr_InvalidPlayerState }
    outHostTime.pointee = h
    return noErr_
}
public func MusicPlayerGetBeatsForHostTime(_ inPlayer: MusicPlayer, _ inHostTime: UInt64, _ outBeats: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus {
    guard let b = _MusicPlayer.from(inPlayer).beats(forHostTime: inHostTime) else { return kAudioToolboxErr_InvalidPlayerState }
    outBeats.pointee = b
    return noErr_
}
public func MusicPlayerPreroll(_ inPlayer: MusicPlayer) -> OSStatus {
    _MusicPlayer.from(inPlayer).sequence == nil ? kAudioToolboxErr_NoSequence : noErr_
}
public func MusicPlayerStart(_ inPlayer: MusicPlayer) -> OSStatus { _MusicPlayer.from(inPlayer).start() }
public func MusicPlayerStop(_ inPlayer: MusicPlayer) -> OSStatus {
    _MusicPlayer.from(inPlayer).stop()
    return noErr_
}
public func MusicPlayerIsPlaying(_ inPlayer: MusicPlayer, _ outIsPlaying: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    outIsPlaying.pointee = DarwinBoolean(_MusicPlayer.from(inPlayer).playing)
    return noErr_
}
public func MusicPlayerSetPlayRateScalar(_ inPlayer: MusicPlayer, _ inScaleRate: Float64) -> OSStatus {
    guard inScaleRate > 0 else { return kAudio_ParamError }
    let p = _MusicPlayer.from(inPlayer)
    p.lock.lock(); defer { p.lock.unlock() }
    if p.playing { let b = p.currentBeat; p.startBeat = b; p.startHost = _MusicPlayer.now() }
    p.rate = inScaleRate
    return noErr_
}
public func MusicPlayerGetPlayRateScalar(_ inPlayer: MusicPlayer, _ outScaleRate: UnsafeMutablePointer<Float64>) -> OSStatus {
    outScaleRate.pointee = _MusicPlayer.from(inPlayer).rate
    return noErr_
}
