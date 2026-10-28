// isim AudioToolbox: Music Sequences (MusicSequence, MusicTrack, MusicEventIterator) and Standard MIDI Files.
// Self-authored, iOS API names, C layouts (usr/include/_AudioToolboxTypes). Adapted:
// - events keep their C bytes (MIDINoteMessage, MIDIChannelMessage, MIDIMetaEvent, ...), ordered by time in beats;
// - the tempo track holds ExtendedTempo events (and the time and key signatures); seconds and beats convert through it
//   (120 BPM before the first tempo);
// - Standard MIDI Files (format 0 and 1; ticks per quarter note, or SMPTE divisions) are read and written: note on and
//   off pairs become MIDINoteMessages with durations, running status, system-exclusive data (MIDIRawData) and meta
//   events; with kMusicSequenceLoadSMF_ChannelsToTracks each channel gets its own track.
import Foundation
import CoreMIDI

public let kAudioToolboxErr_InvalidSequenceType: OSStatus = -10846
public let kAudioToolboxErr_TrackIndexError: OSStatus = -10859
public let kAudioToolboxErr_TrackNotFound: OSStatus = -10858
public let kAudioToolboxErr_EndOfTrack: OSStatus = -10857
public let kAudioToolboxErr_StartOfTrack: OSStatus = -10856
public let kAudioToolboxErr_IllegalTrackDestination: OSStatus = -10855
public let kAudioToolboxErr_NoSequence: OSStatus = -10854
public let kAudioToolboxErr_InvalidEventType: OSStatus = -10853
public let kAudioToolboxErr_InvalidPlayerState: OSStatus = -10852
public let kAudioToolboxErr_CannotDoInCurrentContext: OSStatus = -10863
public let kAudioToolboxError_NoTrackDestination: OSStatus = -66720

public let kSequenceTrackProperty_LoopInfo: UInt32 = 0
public let kSequenceTrackProperty_OffsetTime: UInt32 = 1
public let kSequenceTrackProperty_MuteStatus: UInt32 = 2
public let kSequenceTrackProperty_SoloStatus: UInt32 = 3
public let kSequenceTrackProperty_AutomatedParameters: UInt32 = 4
public let kSequenceTrackProperty_TrackLength: UInt32 = 5
public let kSequenceTrackProperty_TimeResolution: UInt32 = 6

/// One event of a track: its time in beats, type and C bytes.
public final class _MusicEvent: @unchecked Sendable {
    public var time: MusicTimeStamp
    public let type: MusicEventType
    public let bytes: UnsafeMutableRawPointer
    public let size: Int
    public init(time: MusicTimeStamp, type: MusicEventType, copying p: UnsafeRawPointer, size: Int) {
        self.time = time; self.type = type; self.size = max(size, 1)
        bytes = .allocate(byteCount: self.size, alignment: 8)
        bytes.copyMemory(from: p, byteCount: size)
        if type == kMusicEventType_AUPreset {          // the preset dictionary is retained
            let e = bytes.assumingMemoryBound(to: AUPresetEvent.self)
            _ = e.pointee.preset.retain()
        }
    }
    deinit {
        if type == kMusicEventType_AUPreset {
            let e = bytes.assumingMemoryBound(to: AUPresetEvent.self)
            e.pointee.preset.release()
        }
        bytes.deallocate()
    }
    public func copy(at t: MusicTimeStamp) -> _MusicEvent { _MusicEvent(time: t, type: type, copying: bytes, size: size) }

    public static func note(_ m: MIDINoteMessage, at t: MusicTimeStamp) -> _MusicEvent {
        withUnsafeBytes(of: m) { _MusicEvent(time: t, type: kMusicEventType_MIDINoteMessage, copying: $0.baseAddress!, size: $0.count) }
    }
    public static func channel(_ m: MIDIChannelMessage, at t: MusicTimeStamp) -> _MusicEvent {
        withUnsafeBytes(of: m) { _MusicEvent(time: t, type: kMusicEventType_MIDIChannelMessage, copying: $0.baseAddress!, size: $0.count) }
    }
    public static func tempo(_ bpm: Double, at t: MusicTimeStamp) -> _MusicEvent {
        withUnsafeBytes(of: ExtendedTempoEvent(bpm: bpm)) { _MusicEvent(time: t, type: kMusicEventType_ExtendedTempo, copying: $0.baseAddress!, size: $0.count) }
    }
    /// a variable-length event: a header of `header` bytes (its length field filled) and the data after it
    public static func variable(_ type: MusicEventType, header: [UInt8], data: [UInt8], at t: MusicTimeStamp) -> _MusicEvent {
        let bytes = header + data
        return bytes.withUnsafeBytes { _MusicEvent(time: t, type: type, copying: $0.baseAddress!, size: max(bytes.count, header.count + 1)) }
    }
    public static func meta(_ kind: UInt8, _ data: [UInt8], at t: MusicTimeStamp) -> _MusicEvent {
        let n = UInt32(data.count)
        return variable(kMusicEventType_Meta, header: [kind, 0, 0, 0, UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 24)], data: data, at: t)
    }
    public static func raw(_ data: [UInt8], at t: MusicTimeStamp) -> _MusicEvent {
        let n = UInt32(data.count)
        return variable(kMusicEventType_MIDIRawData, header: [UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 24)], data: data, at: t)
    }
    public static func user(_ data: [UInt8], at t: MusicTimeStamp) -> _MusicEvent {
        let n = UInt32(data.count)
        return variable(kMusicEventType_User, header: [UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 24)], data: data, at: t)
    }
    /// the bytes after a variable event's header
    public var variableData: [UInt8] {
        switch type {
        case kMusicEventType_Meta:
            let n = Int(bytes.load(fromByteOffset: 4, as: UInt32.self))
            return [UInt8](UnsafeRawBufferPointer(start: bytes + 8, count: min(n, size - 8)))
        case kMusicEventType_MIDIRawData, kMusicEventType_User:
            let n = Int(bytes.load(as: UInt32.self))
            return [UInt8](UnsafeRawBufferPointer(start: bytes + 4, count: min(n, size - 4)))
        default: return []
        }
    }
    public var metaType: UInt8 { bytes.load(as: UInt8.self) }
    public var noteMessage: MIDINoteMessage { bytes.load(as: MIDINoteMessage.self) }
    public var channelMessage: MIDIChannelMessage { bytes.load(as: MIDIChannelMessage.self) }
    public var tempo: Double { bytes.load(as: ExtendedTempoEvent.self).bpm }
}

/// A track: events by time, and how it plays.
public final class _MusicTrack: @unchecked Sendable {
    public weak var sequence: _MusicSequence?
    public var events: [_MusicEvent] = []
    public var loopInfo = MusicTrackLoopInfo(loopDuration: 0, numberOfLoops: 1)
    public var offsetTime: MusicTimeStamp = 0
    public var muted = false, soloed = false, automatedParameters = false
    public var length: MusicTimeStamp?                       // nil: the last event's end
    public var timeResolution: Int16 = 480
    public var destNode: AUNode = 0
    public var destEndpoint: MIDIEndpointRef = 0
    /// AVFoundation's destination (an AVAudioUnitMIDIInstrument): MIDI bytes at their sample offsets
    public var sink: (([UInt8]) -> Void)?
    public var handle: MusicTrack { MusicTrack(Unmanaged.passUnretained(self).toOpaque()) }
    public static func from(_ h: MusicTrack) -> _MusicTrack { Unmanaged<_MusicTrack>.fromOpaque(UnsafeRawPointer(h)).takeUnretainedValue() }

    public func insert(_ e: _MusicEvent) {
        // after the events at the same time (stable)
        var lo = 0, hi = events.count
        while lo < hi { let m = (lo + hi) / 2; if events[m].time <= e.time { lo = m + 1 } else { hi = m } }
        events.insert(e, at: lo)
    }
    /// the end of the last event (notes end after their durations)
    public var contentLength: MusicTimeStamp {
        events.reduce(0) { m, e in
            let end = e.type == kMusicEventType_MIDINoteMessage ? e.time + Double(e.noteMessage.duration)
                : e.type == kMusicEventType_ExtendedNote ? e.time + Double(e.bytes.load(fromByteOffset: 8, as: Float32.self)) : e.time
            return max(m, end)
        }
    }
    public var effectiveLength: MusicTimeStamp { length ?? contentLength }
    public func events(in r: Range<MusicTimeStamp>) -> [_MusicEvent] { events.filter { r.contains($0.time) } }
}

/// A sequence: the tempo track and the tracks.
public final class _MusicSequence: @unchecked Sendable {
    public var tracks: [_MusicTrack] = []
    public let tempoTrack = _MusicTrack()
    public var type: MusicSequenceType = .beats
    public var graph: AUGraph?
    public var ownsGraph = false
    public var endpoint: MIDIEndpointRef = 0
    public var userCallback: (MusicSequenceUserCallback, UnsafeMutableRawPointer?)?
    public var info: [String: Any] = [:]
    public var handle: MusicSequence { MusicSequence(Unmanaged.passUnretained(self).toOpaque()) }
    public init() { tempoTrack.sequence = self }
    public static func from(_ h: MusicSequence) -> _MusicSequence { Unmanaged<_MusicSequence>.fromOpaque(UnsafeRawPointer(h)).takeUnretainedValue() }

    public func newTrack() -> _MusicTrack {
        let t = _MusicTrack()
        t.sequence = self
        tracks.append(t)
        return t
    }

    // MARK: tempo map

    /// (beat, bpm) changes, from beat 0 (120 BPM until the first)
    var tempoChanges: [(beat: Double, bpm: Double)] {
        var c: [(Double, Double)] = [(0, 120)]
        for e in tempoTrack.events where e.type == kMusicEventType_ExtendedTempo && e.tempo > 0 {
            if e.time <= 0 { c[0].1 = e.tempo } else { c.append((e.time, e.tempo)) }
        }
        return c
    }
    public func seconds(forBeats b: MusicTimeStamp) -> Float64 {
        var s = 0.0
        let c = tempoChanges
        for (i, (beat, bpm)) in c.enumerated() {
            let next = i + 1 < c.count ? c[i + 1].beat : Double.infinity
            if b <= next { return s + (b - beat) * 60 / bpm }
            s += (next - beat) * 60 / bpm
        }
        return s
    }
    public func beats(forSeconds sec: Float64) -> MusicTimeStamp {
        var s = 0.0
        let c = tempoChanges
        for (i, (beat, bpm)) in c.enumerated() {
            let next = i + 1 < c.count ? c[i + 1].beat : Double.infinity
            let span = (next - beat) * 60 / bpm
            if sec <= s + span { return beat + (sec - s) * bpm / 60 }
            s += span
        }
        return 0
    }
    /// the time signature at a beat: (numerator, denominator)
    func timeSignature() -> (Int, Int) {
        guard let e = tempoTrack.events.first(where: { $0.type == kMusicEventType_Meta && $0.metaType == 0x58 }) else { return (4, 4) }
        let d = e.variableData
        return d.count >= 2 ? (Int(d[0]), 1 << Int(d[1])) : (4, 4)
    }
    public var length: MusicTimeStamp { tracks.map(\.effectiveLength).max() ?? 0 }

    // MARK: Standard MIDI Files

    enum FileError: Error { case invalid }

    /// reads a Standard MIDI File into the tracks (replacing them)
    public func readSMF(_ d: Data, flags: MusicSequenceLoadFlags) throws {
        let b = [UInt8](d)
        var o = 0
        func u16(_ p: Int) -> Int { Int(b[p]) << 8 | Int(b[p + 1]) }
        func u32(_ p: Int) -> Int { u16(p) << 16 | u16(p + 2) }
        guard b.count >= 14, b[0..<4].elementsEqual("MThd".utf8) else { throw FileError.invalid }
        let headerSize = u32(4)
        let format = u16(8), ntracks = u16(10), division = u16(12)
        // ticks per beat (SMPTE divisions as ticks per second at 120 BPM: two beats a second)
        let ticksPerBeat: Double = division & 0x8000 != 0
            ? Double(256 - (division >> 8)) * Double(division & 0xFF) / 2 : Double(max(1, division))
        o = 8 + headerSize
        tracks = []
        tempoTrack.events = []
        let channelsToTracks = flags.contains(.smf_ChannelsToTracks)
        var byChannel: [Int: _MusicTrack] = [:]
        for t in 0..<ntracks {
            guard o + 8 <= b.count, b[o..<o + 4].elementsEqual("MTrk".utf8) else { throw FileError.invalid }
            let n = u32(o + 4)
            let end = min(b.count, o + 8 + n)
            var p = o + 8
            o = end
            // format 1: the first track is the tempo track
            let isTempoTrack = format == 1 && t == 0
            let track = isTempoTrack ? tempoTrack : channelsToTracks ? nil : newTrack()
            var tick = 0, running: UInt8 = 0
            var open: [Int: [(tick: Int, velocity: UInt8)]] = [:]       // channel << 8 | key -> note ons
            func vlq() -> Int {
                var v = 0
                while p < end { let c = b[p]; p += 1; v = v << 7 | Int(c & 0x7F); if c & 0x80 == 0 { break } }
                return v
            }
            func target(_ ch: Int) -> _MusicTrack {
                if let track { return track }
                if let x = byChannel[ch] { return x }
                let x = newTrack(); byChannel[ch] = x; return x
            }
            var pendingNotes: [(track: _MusicTrack, event: _MusicEvent)] = []
            while p < end {
                tick += vlq()
                guard p < end else { break }
                var status = b[p]
                if status < 0x80 { status = running } else { p += 1 }
                let beat = Double(tick) / ticksPerBeat
                switch status {
                case 0xFF:
                    guard p < end else { break }
                    let kind = b[p]; p += 1
                    let len = vlq()
                    let data = [UInt8](b[p..<min(end, p + len)]); p += len
                    if kind == 0x2F { break }                                     // end of track: from the events
                    if kind == 0x51, data.count >= 3 {
                        let us = Int(data[0]) << 16 | Int(data[1]) << 8 | Int(data[2])
                        tempoTrack.insert(.tempo(60_000_000 / Double(max(1, us)), at: beat))
                    } else if [0x58, 0x59, 0x54].contains(kind) || isTempoTrack {
                        tempoTrack.insert(.meta(kind, data, at: beat))
                    } else {
                        (track ?? target(0)).insert(.meta(kind, data, at: beat))
                    }
                case 0xF0, 0xF7:
                    let len = vlq()
                    let data = (status == 0xF0 ? [0xF0] : []) + [UInt8](b[p..<min(end, p + len)]); p += len
                    (track ?? target(0)).insert(.raw(data, at: beat))
                default:
                    guard status >= 0x80 else { p += 1; continue }                 // data without status
                    running = status
                    let ch = Int(status & 0x0F), kind = status & 0xF0
                    let n2 = kind == 0xC0 || kind == 0xD0 ? 1 : 2
                    guard p + n2 <= end else { p = end; break }
                    let d1 = b[p], d2 = n2 == 2 ? b[p + 1] : 0
                    p += n2
                    let key = ch << 8 | Int(d1)
                    if kind == 0x90 && d2 > 0 {
                        open[key, default: []].append((tick, d2))
                    } else if kind == 0x80 || kind == 0x90 {
                        if var ons = open[key], !ons.isEmpty {
                            let on = ons.removeFirst()
                            open[key] = ons
                            let m = MIDINoteMessage(channel: UInt8(ch), note: d1, velocity: on.velocity, releaseVelocity: kind == 0x80 ? d2 : 0,
                                                    duration: Float32(Double(tick - on.tick) / ticksPerBeat))
                            pendingNotes.append((target(ch), .note(m, at: Double(on.tick) / ticksPerBeat)))
                        }
                    } else {
                        target(ch).insert(.channel(MIDIChannelMessage(status: status, data1: d1, data2: d2, reserved: 0), at: beat))
                    }
                }
            }
            // notes never turned off end at the track's end
            for (key, ons) in open {
                for on in ons {
                    let m = MIDINoteMessage(channel: UInt8(key >> 8), note: UInt8(key & 0xFF), velocity: on.velocity, releaseVelocity: 0,
                                            duration: Float32(Double(tick - on.tick) / ticksPerBeat))
                    pendingNotes.append((target(key >> 8), .note(m, at: Double(on.tick) / ticksPerBeat)))
                }
            }
            for (tr, e) in pendingNotes { tr.insert(e) }
            if let track, !isTempoTrack { track.timeResolution = Int16(clamping: Int(ticksPerBeat)) }
        }
        for tr in tracks { tr.timeResolution = Int16(clamping: Int(ticksPerBeat)) }
        tempoTrack.timeResolution = Int16(clamping: Int(ticksPerBeat))
    }

    /// writes the tempo track and the tracks as a format 1 Standard MIDI File
    public func writeSMF(resolution: Int16) -> Data {
        let ppq = resolution > 0 ? Int(resolution) : 480
        var out = Data("MThd".utf8)
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        func vlq(_ v: Int) -> [UInt8] {
            var v = max(0, v), s: [UInt8] = [UInt8(v & 0x7F)]
            v >>= 7
            while v > 0 { s.insert(UInt8(v & 0x7F) | 0x80, at: 0); v >>= 7 }
            return s
        }
        out.append(contentsOf: be32(6) + [0, 1] + [UInt8((tracks.count + 1) >> 8), UInt8((tracks.count + 1) & 0xFF)] + [UInt8(ppq >> 8), UInt8(ppq & 0xFF)])
        for track in [tempoTrack] + tracks {
            // (tick, order, bytes): note offs before note ons at the same tick
            var items: [(tick: Int, order: Int, bytes: [UInt8])] = []
            for e in track.events {
                let tick = Int((e.time * Double(ppq)).rounded())
                switch e.type {
                case kMusicEventType_MIDINoteMessage:
                    let m = e.noteMessage
                    let off = Int(((e.time + Double(m.duration)) * Double(ppq)).rounded())
                    items.append((tick, 1, [0x90 | (m.channel & 0x0F), m.note & 0x7F, max(1, m.velocity & 0x7F)]))
                    items.append((off, 0, [0x80 | (m.channel & 0x0F), m.note & 0x7F, m.releaseVelocity & 0x7F]))
                case kMusicEventType_MIDIChannelMessage:
                    let m = e.channelMessage
                    let two = m.status & 0xF0 == 0xC0 || m.status & 0xF0 == 0xD0
                    items.append((tick, 1, two ? [m.status, m.data1] : [m.status, m.data1, m.data2]))
                case kMusicEventType_ExtendedTempo:
                    let us = Int(60_000_000 / max(1, e.tempo))
                    items.append((tick, 1, [0xFF, 0x51, 3, UInt8(us >> 16 & 0xFF), UInt8(us >> 8 & 0xFF), UInt8(us & 0xFF)]))
                case kMusicEventType_Meta:
                    let d = e.variableData
                    items.append((tick, 1, [0xFF, e.metaType] + vlq(d.count) + d))
                case kMusicEventType_MIDIRawData:
                    var d = e.variableData
                    if d.first == 0xF0 { d.removeFirst(); items.append((tick, 1, [0xF0] + vlq(d.count) + d)) }
                    else { items.append((tick, 1, [0xF7] + vlq(d.count) + d)) }
                default: break
                }
            }
            items.sort { ($0.tick, $0.order) < ($1.tick, $1.order) }
            var body: [UInt8] = []
            var last = 0
            for it in items { body += vlq(it.tick - last) + it.bytes; last = it.tick }
            let endTick = max(last, Int((track.effectiveLength * Double(ppq)).rounded()))
            body += vlq(endTick - last) + [0xFF, 0x2F, 0]
            out.append(contentsOf: Array("MTrk".utf8) + be32(body.count) + body)
        }
        return out
    }
}

// MARK: - the Music Sequence API

nonisolated(unsafe) var _sequences: [ObjectIdentifier: _MusicSequence] = [:]
let _sequenceLock = NSLock()

public func NewMusicSequence(_ outSequence: UnsafeMutablePointer<MusicSequence?>) -> OSStatus {
    let s = _MusicSequence()
    _sequenceLock.lock(); _sequences[ObjectIdentifier(s)] = s; _sequenceLock.unlock()
    outSequence.pointee = s.handle
    return noErr_
}
public func DisposeMusicSequence(_ inSequence: MusicSequence) -> OSStatus {
    let s = _MusicSequence.from(inSequence)
    _sequenceLock.lock(); defer { _sequenceLock.unlock() }
    guard _sequences.removeValue(forKey: ObjectIdentifier(s)) != nil else { return kAudioToolboxErr_NoSequence }
    if s.ownsGraph, let g = s.graph { _ = AUGraphStop(g); _ = DisposeAUGraph(g) }
    return noErr_
}
public func MusicSequenceNewTrack(_ inSequence: MusicSequence, _ outTrack: UnsafeMutablePointer<MusicTrack?>) -> OSStatus {
    outTrack.pointee = _MusicSequence.from(inSequence).newTrack().handle
    return noErr_
}
public func MusicSequenceDisposeTrack(_ inSequence: MusicSequence, _ inTrack: MusicTrack) -> OSStatus {
    let s = _MusicSequence.from(inSequence), t = _MusicTrack.from(inTrack)
    guard let i = s.tracks.firstIndex(where: { $0 === t }) else { return kAudioToolboxErr_TrackNotFound }
    s.tracks.remove(at: i)
    return noErr_
}
public func MusicSequenceGetTrackCount(_ inSequence: MusicSequence, _ outNumberOfTracks: UnsafeMutablePointer<UInt32>) -> OSStatus {
    outNumberOfTracks.pointee = UInt32(_MusicSequence.from(inSequence).tracks.count)
    return noErr_
}
public func MusicSequenceGetIndTrack(_ inSequence: MusicSequence, _ inTrackIndex: UInt32, _ outTrack: UnsafeMutablePointer<MusicTrack?>) -> OSStatus {
    let s = _MusicSequence.from(inSequence)
    guard Int(inTrackIndex) < s.tracks.count else { return kAudioToolboxErr_TrackIndexError }
    outTrack.pointee = s.tracks[Int(inTrackIndex)].handle
    return noErr_
}
public func MusicSequenceGetTrackIndex(_ inSequence: MusicSequence, _ inTrack: MusicTrack, _ outTrackIndex: UnsafeMutablePointer<UInt32>) -> OSStatus {
    let s = _MusicSequence.from(inSequence), t = _MusicTrack.from(inTrack)
    guard let i = s.tracks.firstIndex(where: { $0 === t }) else { return kAudioToolboxErr_TrackNotFound }
    outTrackIndex.pointee = UInt32(i)
    return noErr_
}
public func MusicSequenceGetTempoTrack(_ inSequence: MusicSequence, _ outTrack: UnsafeMutablePointer<MusicTrack?>) -> OSStatus {
    outTrack.pointee = _MusicSequence.from(inSequence).tempoTrack.handle
    return noErr_
}
public func MusicSequenceSetAUGraph(_ inSequence: MusicSequence, _ inGraph: AUGraph?) -> OSStatus {
    let s = _MusicSequence.from(inSequence)
    s.graph = inGraph; s.ownsGraph = false
    return noErr_
}
/// the sequence's graph; one is made when it has none: a MIDISynth into RemoteIO, every track's destination
public func MusicSequenceGetAUGraph(_ inSequence: MusicSequence, _ outGraph: UnsafeMutablePointer<AUGraph?>) -> OSStatus {
    let s = _MusicSequence.from(inSequence)
    if s.graph == nil {
        var g: AUGraph?
        guard NewAUGraph(&g) == noErr_, let graph = g else { return kAudioToolboxErr_CannotDoInCurrentContext }
        var synthDesc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: kAudioUnitSubType_MIDISynth,
                                                  componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var outDesc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO,
                                                componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var synth = AUNode(), out = AUNode()
        _ = AUGraphAddNode(graph, &synthDesc, &synth)
        _ = AUGraphAddNode(graph, &outDesc, &out)
        _ = AUGraphOpen(graph)
        _ = AUGraphConnectNodeInput(graph, synth, 0, out, 0)
        _ = AUGraphInitialize(graph)
        s.graph = graph; s.ownsGraph = true
        for t in s.tracks where t.destNode == 0 && t.destEndpoint == 0 { t.destNode = synth }
    }
    outGraph.pointee = s.graph
    return noErr_
}
public func MusicSequenceSetMIDIEndpoint(_ inSequence: MusicSequence, _ inEndpoint: MIDIEndpointRef) -> OSStatus {
    let s = _MusicSequence.from(inSequence)
    s.endpoint = inEndpoint
    for t in s.tracks { t.destEndpoint = inEndpoint; t.destNode = 0 }
    return noErr_
}
public func MusicSequenceSetSequenceType(_ inSequence: MusicSequence, _ inType: MusicSequenceType) -> OSStatus {
    guard inType == .beats || inType == .seconds || inType == .samples else { return kAudioToolboxErr_InvalidSequenceType }
    let s = _MusicSequence.from(inSequence)
    // seconds: a tempo of 60 BPM, so a beat is a second
    if inType == .seconds { s.tempoTrack.events.removeAll { $0.type == kMusicEventType_ExtendedTempo }; s.tempoTrack.insert(.tempo(60, at: 0)) }
    s.type = inType
    return noErr_
}
public func MusicSequenceGetSequenceType(_ inSequence: MusicSequence, _ outType: UnsafeMutablePointer<MusicSequenceType>) -> OSStatus {
    outType.pointee = _MusicSequence.from(inSequence).type
    return noErr_
}
public func MusicSequenceFileLoad(_ inSequence: MusicSequence, _ inFileRef: CFURL, _ inFileTypeHint: MusicSequenceFileTypeID, _ inFlags: MusicSequenceLoadFlags) -> OSStatus {
    guard let d = try? Data(contentsOf: inFileRef as URL) else { return -43 }       // fnfErr
    return MusicSequenceFileLoadData(inSequence, d as CFData, inFileTypeHint, inFlags)
}
public func MusicSequenceFileLoadData(_ inSequence: MusicSequence, _ inData: CFData, _ inFileTypeHint: MusicSequenceFileTypeID, _ inFlags: MusicSequenceLoadFlags) -> OSStatus {
    if inFileTypeHint == .iMelodyType { return kAudioToolboxErr_InvalidSequenceType }
    do { try _MusicSequence.from(inSequence).readSMF(inData as Data, flags: inFlags) } catch { return kAudioFileInvalidFileError }
    return noErr_
}
public func MusicSequenceFileCreate(_ inSequence: MusicSequence, _ inFileRef: CFURL, _ inFileType: MusicSequenceFileTypeID, _ inFlags: MusicSequenceFileFlags, _ inResolution: Int16) -> OSStatus {
    guard inFileType == .midiType || inFileType == .anyType else { return kAudioToolboxErr_InvalidSequenceType }
    let url = inFileRef as URL
    if FileManager.default.fileExists(atPath: url.path) && !inFlags.contains(.eraseFile) { return -48 }    // dupFNErr
    do { try _MusicSequence.from(inSequence).writeSMF(resolution: inResolution).write(to: url) } catch { return -61 }   // wrPermErr
    return noErr_
}
public func MusicSequenceFileCreateData(_ inSequence: MusicSequence, _ inFileType: MusicSequenceFileTypeID, _ inFlags: MusicSequenceFileFlags, _ inResolution: Int16, _ outData: UnsafeMutablePointer<Unmanaged<CFData>?>) -> OSStatus {
    guard inFileType == .midiType || inFileType == .anyType else { return kAudioToolboxErr_InvalidSequenceType }
    outData.pointee = Unmanaged.passRetained(_MusicSequence.from(inSequence).writeSMF(resolution: inResolution) as CFData)
    return noErr_
}
public func MusicSequenceReverse(_ inSequence: MusicSequence) -> OSStatus {
    let s = _MusicSequence.from(inSequence)
    let len = s.length
    for t in s.tracks {
        let old = t.events
        t.events = []
        for e in old {
            let dur = e.type == kMusicEventType_MIDINoteMessage ? Double(e.noteMessage.duration) : 0
            t.insert(e.copy(at: max(0, len - e.time - dur)))
        }
    }
    return noErr_
}
public func MusicSequenceGetSecondsForBeats(_ inSequence: MusicSequence, _ inBeats: MusicTimeStamp, _ outSeconds: UnsafeMutablePointer<Float64>) -> OSStatus {
    outSeconds.pointee = _MusicSequence.from(inSequence).seconds(forBeats: inBeats)
    return noErr_
}
public func MusicSequenceGetBeatsForSeconds(_ inSequence: MusicSequence, _ inSeconds: Float64, _ outBeats: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus {
    outBeats.pointee = _MusicSequence.from(inSequence).beats(forSeconds: inSeconds)
    return noErr_
}
public func MusicSequenceSetUserCallback(_ inSequence: MusicSequence, _ inCallback: MusicSequenceUserCallback?, _ inClientData: UnsafeMutableRawPointer?) -> OSStatus {
    _MusicSequence.from(inSequence).userCallback = inCallback.map { ($0, inClientData) }
    return noErr_
}
public func MusicSequenceBeatsToBarBeatTime(_ inSequence: MusicSequence, _ inBeats: MusicTimeStamp, _ inSubbeatDivisor: UInt32, _ outBarBeatTime: UnsafeMutablePointer<CABarBeatTime>) -> OSStatus {
    let (num, den) = _MusicSequence.from(inSequence).timeSignature()
    let beatLength = 4.0 / Double(den)                      // a quarter note is one beat
    let beatsInBar = Double(num) * beatLength
    let bar = Int(floor(inBeats / beatsInBar))
    let inBar = inBeats - Double(bar) * beatsInBar
    let beat = Int(floor(inBar / beatLength))
    let sub = (inBar - Double(beat) * beatLength) / beatLength * Double(max(1, inSubbeatDivisor))
    outBarBeatTime.pointee = CABarBeatTime(bar: Int32(bar + 1), beat: UInt16(beat + 1), subbeat: UInt16(sub.rounded(.down)),
                                           subbeatDivisor: UInt16(inSubbeatDivisor), reserved: 0)
    return noErr_
}
public func MusicSequenceBarBeatTimeToBeats(_ inSequence: MusicSequence, _ inBarBeatTime: UnsafePointer<CABarBeatTime>, _ outBeats: UnsafeMutablePointer<MusicTimeStamp>) -> OSStatus {
    let (num, den) = _MusicSequence.from(inSequence).timeSignature()
    let t = inBarBeatTime.pointee
    let beatLength = 4.0 / Double(den)
    outBeats.pointee = Double(Int(t.bar) - 1) * Double(num) * beatLength + Double(Int(t.beat) - 1) * beatLength
        + (t.subbeatDivisor > 0 ? Double(t.subbeat) / Double(t.subbeatDivisor) * beatLength : 0)
    return noErr_
}
public func MusicSequenceGetInfoDictionary(_ inSequence: MusicSequence) -> CFDictionary {
    let s = _MusicSequence.from(inSequence)
    var d = s.info
    d["approximate duration in seconds"] = s.seconds(forBeats: s.length)
    // the track names, copyright and tempo
    if let name = s.tracks.first?.events.first(where: { $0.type == kMusicEventType_Meta && $0.metaType == 0x03 }) {
        d["title"] = String(bytes: name.variableData, encoding: .utf8)
    }
    if let c = (s.tempoTrack.events + s.tracks.flatMap(\.events)).first(where: { $0.type == kMusicEventType_Meta && $0.metaType == 0x02 }) {
        d["copyright"] = String(bytes: c.variableData, encoding: .utf8)
    }
    d["tempo"] = s.tempoChanges.first?.bpm
    let (num, den) = s.timeSignature()
    d["time signature"] = "\(num)/\(den)"
    return d as CFDictionary
}
public func MusicSequenceSetSMPTEResolution(_ fps: Int8, _ ticks: UInt8) -> Int16 { Int16(bitPattern: UInt16(UInt8(bitPattern: fps)) << 8 | UInt16(ticks)) | Int16(bitPattern: 0x8000) }
public func MusicSequenceGetSMPTEResolution(_ inRes: Int16, _ fps: UnsafeMutablePointer<Int8>, _ ticks: UnsafeMutablePointer<UInt8>) {
    fps.pointee = Int8(bitPattern: UInt8(UInt16(bitPattern: inRes) >> 8))
    ticks.pointee = UInt8(UInt16(bitPattern: inRes) & 0xFF)
}

// MARK: tracks

public func MusicTrackGetSequence(_ inTrack: MusicTrack, _ outSequence: UnsafeMutablePointer<MusicSequence?>) -> OSStatus {
    guard let s = _MusicTrack.from(inTrack).sequence else { return kAudioToolboxErr_NoSequence }
    outSequence.pointee = s.handle
    return noErr_
}
public func MusicTrackSetDestNode(_ inTrack: MusicTrack, _ inNode: AUNode) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    guard t.sequence?.graph != nil else { return kAudioToolboxErr_IllegalTrackDestination }
    t.destNode = inNode; t.destEndpoint = 0
    return noErr_
}
public func MusicTrackSetDestMIDIEndpoint(_ inTrack: MusicTrack, _ inEndpoint: MIDIEndpointRef) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    t.destEndpoint = inEndpoint; t.destNode = 0
    return noErr_
}
public func MusicTrackGetDestNode(_ inTrack: MusicTrack, _ outNode: UnsafeMutablePointer<AUNode>) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    guard t.destNode != 0 else { return kAudioToolboxErr_IllegalTrackDestination }
    outNode.pointee = t.destNode
    return noErr_
}
public func MusicTrackGetDestMIDIEndpoint(_ inTrack: MusicTrack, _ outEndpoint: UnsafeMutablePointer<MIDIEndpointRef>) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    guard t.destEndpoint != 0 else { return kAudioToolboxErr_IllegalTrackDestination }
    outEndpoint.pointee = t.destEndpoint
    return noErr_
}
public func MusicTrackSetProperty(_ inTrack: MusicTrack, _ inPropertyID: UInt32, _ inData: UnsafeMutableRawPointer, _ inLength: UInt32) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    switch inPropertyID {
    case kSequenceTrackProperty_LoopInfo:
        guard inLength >= UInt32(MemoryLayout<MusicTrackLoopInfo>.size) else { return kAudioUnitErr_InvalidPropertyValue }
        t.loopInfo = inData.load(as: MusicTrackLoopInfo.self)
    case kSequenceTrackProperty_OffsetTime: t.offsetTime = inData.load(as: MusicTimeStamp.self)
    case kSequenceTrackProperty_MuteStatus: t.muted = inData.load(as: UInt8.self) != 0
    case kSequenceTrackProperty_SoloStatus: t.soloed = inData.load(as: UInt8.self) != 0
    case kSequenceTrackProperty_AutomatedParameters: t.automatedParameters = inData.load(as: UInt32.self) != 0
    case kSequenceTrackProperty_TrackLength: t.length = inData.load(as: MusicTimeStamp.self)
    case kSequenceTrackProperty_TimeResolution: return kAudioUnitErr_PropertyNotWritable
    default: return kAudioUnitErr_InvalidProperty
    }
    return noErr_
}
public func MusicTrackGetProperty(_ inTrack: MusicTrack, _ inPropertyID: UInt32, _ outData: UnsafeMutableRawPointer, _ ioLength: UnsafeMutablePointer<UInt32>) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    func put<T>(_ v: T) -> OSStatus {
        guard ioLength.pointee >= UInt32(MemoryLayout<T>.size) else { return kAudioUnitErr_InvalidPropertyValue }
        outData.storeBytes(of: v, as: T.self)
        ioLength.pointee = UInt32(MemoryLayout<T>.size)
        return noErr_
    }
    switch inPropertyID {
    case kSequenceTrackProperty_LoopInfo: return put(t.loopInfo)
    case kSequenceTrackProperty_OffsetTime: return put(t.offsetTime)
    case kSequenceTrackProperty_MuteStatus: return put(UInt8(t.muted ? 1 : 0))
    case kSequenceTrackProperty_SoloStatus: return put(UInt8(t.soloed ? 1 : 0))
    case kSequenceTrackProperty_AutomatedParameters: return put(UInt32(t.automatedParameters ? 1 : 0))
    case kSequenceTrackProperty_TrackLength: return put(t.effectiveLength)
    case kSequenceTrackProperty_TimeResolution: return put(t.timeResolution)
    default: return kAudioUnitErr_InvalidProperty
    }
}
private func add(_ inTrack: MusicTrack, _ e: _MusicEvent) -> OSStatus {
    _MusicTrack.from(inTrack).insert(e)
    return noErr_
}
public func MusicTrackNewMIDINoteEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inMessage: UnsafePointer<MIDINoteMessage>) -> OSStatus {
    add(inTrack, .note(inMessage.pointee, at: inTimeStamp))
}
public func MusicTrackNewMIDIChannelEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inMessage: UnsafePointer<MIDIChannelMessage>) -> OSStatus {
    guard inMessage.pointee.status >= 0x80 && inMessage.pointee.status < 0xF0 else { return kAudioToolboxErr_InvalidEventType }
    return add(inTrack, .channel(inMessage.pointee, at: inTimeStamp))
}
public func MusicTrackNewMIDIRawDataEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inRawData: UnsafePointer<MIDIRawData>) -> OSStatus {
    let n = Int(inRawData.pointee.length)
    let data = [UInt8](UnsafeRawBufferPointer(start: UnsafeRawPointer(inRawData) + 4, count: n))
    return add(inTrack, .raw(data, at: inTimeStamp))
}
public func MusicTrackNewExtendedNoteEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inInfo: UnsafePointer<ExtendedNoteOnEvent>) -> OSStatus {
    // the note parameters' controls follow the struct
    let controls = Int(max(2, inInfo.pointee.extendedParams.argCount)) - 2
    let size = MemoryLayout<ExtendedNoteOnEvent>.size + max(0, controls - 1) * MemoryLayout<NoteParamsControlValue>.size
    return add(inTrack, _MusicEvent(time: inTimeStamp, type: kMusicEventType_ExtendedNote, copying: inInfo, size: size))
}
public func MusicTrackNewParameterEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inInfo: UnsafePointer<ParameterEvent>) -> OSStatus {
    add(inTrack, _MusicEvent(time: inTimeStamp, type: kMusicEventType_Parameter, copying: inInfo, size: MemoryLayout<ParameterEvent>.size))
}
public func MusicTrackNewExtendedTempoEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inBPM: Float64) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    guard t.sequence?.tempoTrack === t else { return kAudioToolboxErr_InvalidEventType }       // tempo events belong in the tempo track
    guard inBPM > 0 else { return kAudio_ParamError }
    return add(inTrack, .tempo(inBPM, at: inTimeStamp))
}
public func MusicTrackNewMetaEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inMetaEvent: UnsafePointer<MIDIMetaEvent>) -> OSStatus {
    let n = Int(inMetaEvent.pointee.dataLength)
    let data = [UInt8](UnsafeRawBufferPointer(start: UnsafeRawPointer(inMetaEvent) + 8, count: n))
    return add(inTrack, .meta(inMetaEvent.pointee.metaEventType, data, at: inTimeStamp))
}
public func MusicTrackNewUserEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inUserData: UnsafePointer<MusicEventUserData>) -> OSStatus {
    let n = Int(inUserData.pointee.length)
    let data = [UInt8](UnsafeRawBufferPointer(start: UnsafeRawPointer(inUserData) + 4, count: n))
    return add(inTrack, .user(data, at: inTimeStamp))
}
public func MusicTrackNewAUPresetEvent(_ inTrack: MusicTrack, _ inTimeStamp: MusicTimeStamp, _ inPresetEvent: UnsafePointer<AUPresetEvent>) -> OSStatus {
    add(inTrack, _MusicEvent(time: inTimeStamp, type: kMusicEventType_AUPreset, copying: inPresetEvent, size: MemoryLayout<AUPresetEvent>.size))
}
public func MusicTrackMoveEvents(_ inTrack: MusicTrack, _ inStartTime: MusicTimeStamp, _ inEndTime: MusicTimeStamp, _ inMoveTime: MusicTimeStamp) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    let moving = t.events.filter { $0.time >= inStartTime && $0.time < inEndTime }
    t.events.removeAll { $0.time >= inStartTime && $0.time < inEndTime }
    for e in moving { e.time = max(0, e.time + inMoveTime); t.insert(e) }
    return noErr_
}
public func MusicTrackClear(_ inTrack: MusicTrack, _ inStartTime: MusicTimeStamp, _ inEndTime: MusicTimeStamp) -> OSStatus {
    _MusicTrack.from(inTrack).events.removeAll { $0.time >= inStartTime && $0.time < inEndTime }
    return noErr_
}
public func MusicTrackCut(_ inTrack: MusicTrack, _ inStartTime: MusicTimeStamp, _ inEndTime: MusicTimeStamp) -> OSStatus {
    let t = _MusicTrack.from(inTrack)
    t.events.removeAll { $0.time >= inStartTime && $0.time < inEndTime }
    for e in t.events where e.time >= inEndTime { e.time -= inEndTime - inStartTime }
    return noErr_
}
public func MusicTrackCopyInsert(_ inSourceTrack: MusicTrack, _ inSourceStartTime: MusicTimeStamp, _ inSourceEndTime: MusicTimeStamp, _ inDestTrack: MusicTrack, _ inDestInsertTime: MusicTimeStamp) -> OSStatus {
    let src = _MusicTrack.from(inSourceTrack), dst = _MusicTrack.from(inDestTrack)
    let span = inSourceEndTime - inSourceStartTime
    let copies = src.events(in: inSourceStartTime..<inSourceEndTime).map { $0.copy(at: $0.time - inSourceStartTime + inDestInsertTime) }
    for e in dst.events where e.time >= inDestInsertTime { e.time += span }        // the rest moves later
    for e in copies { dst.insert(e) }
    return noErr_
}
public func MusicTrackMerge(_ inSourceTrack: MusicTrack, _ inSourceStartTime: MusicTimeStamp, _ inSourceEndTime: MusicTimeStamp, _ inDestTrack: MusicTrack, _ inDestInsertTime: MusicTimeStamp) -> OSStatus {
    let src = _MusicTrack.from(inSourceTrack), dst = _MusicTrack.from(inDestTrack)
    for e in src.events(in: inSourceStartTime..<inSourceEndTime) { dst.insert(e.copy(at: e.time - inSourceStartTime + inDestInsertTime)) }
    return noErr_
}

// MARK: event iterators

public final class _MusicEventIterator {
    let track: _MusicTrack
    var index = 0
    init(_ t: _MusicTrack) { track = t }
    var handle: MusicEventIterator { MusicEventIterator(Unmanaged.passUnretained(self).toOpaque()) }
    public static func from(_ h: MusicEventIterator) -> _MusicEventIterator { Unmanaged<_MusicEventIterator>.fromOpaque(UnsafeRawPointer(h)).takeUnretainedValue() }
}
public func NewMusicEventIterator(_ inTrack: MusicTrack, _ outIterator: UnsafeMutablePointer<MusicEventIterator?>) -> OSStatus {
    let it = _MusicEventIterator(_MusicTrack.from(inTrack))
    outIterator.pointee = MusicEventIterator(Unmanaged.passRetained(it).toOpaque())
    return noErr_
}
public func DisposeMusicEventIterator(_ inIterator: MusicEventIterator) -> OSStatus {
    Unmanaged<_MusicEventIterator>.fromOpaque(UnsafeRawPointer(inIterator)).release()
    return noErr_
}
public func MusicEventIteratorSeek(_ inIterator: MusicEventIterator, _ inTimeStamp: MusicTimeStamp) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    it.index = it.track.events.firstIndex { $0.time >= inTimeStamp } ?? it.track.events.count
    return noErr_
}
public func MusicEventIteratorNextEvent(_ inIterator: MusicEventIterator) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    guard it.index < it.track.events.count else { return kAudioToolboxErr_EndOfTrack }
    it.index += 1
    return noErr_
}
public func MusicEventIteratorPreviousEvent(_ inIterator: MusicEventIterator) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    guard it.index > 0 else { return kAudioToolboxErr_StartOfTrack }
    it.index -= 1
    return noErr_
}
public func MusicEventIteratorGetEventInfo(_ inIterator: MusicEventIterator, _ outTimeStamp: UnsafeMutablePointer<MusicTimeStamp>?, _ outEventType: UnsafeMutablePointer<MusicEventType>?, _ outEventData: UnsafeMutablePointer<UnsafeRawPointer?>?, _ outEventDataSize: UnsafeMutablePointer<UInt32>?) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    guard it.index < it.track.events.count else { return kAudioToolboxErr_EndOfTrack }
    let e = it.track.events[it.index]
    outTimeStamp?.pointee = e.time
    outEventType?.pointee = e.type
    outEventData?.pointee = UnsafeRawPointer(e.bytes)
    outEventDataSize?.pointee = UInt32(e.size)
    return noErr_
}
public func MusicEventIteratorSetEventInfo(_ inIterator: MusicEventIterator, _ inEventType: MusicEventType, _ inEventData: UnsafeRawPointer) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    guard it.index < it.track.events.count else { return kAudioToolboxErr_EndOfTrack }
    let old = it.track.events[it.index]
    guard inEventType == old.type else { return kAudioToolboxErr_InvalidEventType }
    old.bytes.copyMemory(from: inEventData, byteCount: min(old.size, inEventType == kMusicEventType_MIDINoteMessage ? MemoryLayout<MIDINoteMessage>.size : old.size))
    return noErr_
}
public func MusicEventIteratorSetEventTime(_ inIterator: MusicEventIterator, _ inTimeStamp: MusicTimeStamp) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    guard it.index < it.track.events.count else { return kAudioToolboxErr_EndOfTrack }
    let e = it.track.events.remove(at: it.index)
    e.time = inTimeStamp
    it.track.insert(e)
    it.index = it.track.events.firstIndex { $0 === e } ?? 0
    return noErr_
}
public func MusicEventIteratorDeleteEvent(_ inIterator: MusicEventIterator) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    guard it.index < it.track.events.count else { return kAudioToolboxErr_EndOfTrack }
    it.track.events.remove(at: it.index)
    return noErr_
}
public func MusicEventIteratorHasPreviousEvent(_ inIterator: MusicEventIterator, _ outHasPrevEvent: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    outHasPrevEvent.pointee = DarwinBoolean(_MusicEventIterator.from(inIterator).index > 0)
    return noErr_
}
public func MusicEventIteratorHasNextEvent(_ inIterator: MusicEventIterator, _ outHasNextEvent: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    outHasNextEvent.pointee = DarwinBoolean(it.index + 1 < it.track.events.count)
    return noErr_
}
public func MusicEventIteratorHasCurrentEvent(_ inIterator: MusicEventIterator, _ outHasCurEvent: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    let it = _MusicEventIterator.from(inIterator)
    outHasCurEvent.pointee = DarwinBoolean(it.index < it.track.events.count)
    return noErr_
}
