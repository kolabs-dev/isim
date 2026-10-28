// isim AudioToolbox: Core Audio Clock (CAClock*). Adapted: an internal clock on the host time (uptime nanoseconds):
// media seconds advance with the play rate while it runs, beats follow the tempo (or a tempo map), SMPTE times its
// format and offset, bars its meter track. External sync (MIDI clock, MTC) is not followed: CAClockParseMIDI accepts
// the messages but the clock stays on its own timebase.
import Foundation
import CoreMIDI

public let kCAClock_UnknownPropertyError: OSStatus = -66816
public let kCAClock_InvalidPropertySizeError: OSStatus = -66815
public let kCAClock_InvalidTimeFormatError: OSStatus = -66814
public let kCAClock_InvalidSyncModeError: OSStatus = -66813
public let kCAClock_InvalidSyncSourceError: OSStatus = -66812
public let kCAClock_InvalidTimebaseError: OSStatus = -66811
public let kCAClock_InvalidTimebaseSourceError: OSStatus = -66810
public let kCAClock_InvalidSMPTEFormatError: OSStatus = -66809
public let kCAClock_InvalidSMPTEOffsetError: OSStatus = -66808
public let kCAClock_InvalidUnitError: OSStatus = -66807
public let kCAClock_InvalidPlayRateError: OSStatus = -66806
public let kCAClock_CannotSetTimeError: OSStatus = -66805

final class _CAClock {
    var timebase: CAClockTimebase = .hostTime
    var syncMode: CAClockSyncMode = .internal
    var smpteFormat: CAClockSMPTEFormat = SMPTETimeType.type30.rawValue
    var smpteOffset: CAClockSeconds = 0
    var name = "CAClock"
    var running = false, armed = false
    var mediaAtStart: CAClockSeconds = 0          // media seconds when (re)started or set
    var hostAtStart: UInt64 = 0
    var startHost: UInt64 = 0
    var playRate: Float64 = 1
    var tempo: CAClockTempo = 120
    var tempoMap: [(beats: CAClockBeats, tempo: CAClockTempo)] = []
    var meter: (num: Int, den: Int) = (4, 4)
    var listeners: [(CAClockListenerProc, UnsafeMutableRawPointer)] = []
    static func from(_ r: CAClockRef) -> _CAClock { Unmanaged<_CAClock>.fromOpaque(UnsafeRawPointer(r)).takeUnretainedValue() }
    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

    var media: CAClockSeconds { running ? mediaAtStart + Double(Self.now() - hostAtStart) / 1e9 * playRate : mediaAtStart }
    func notify(_ m: CAClockMessage, _ param: UnsafeRawPointer? = nil) {
        for (proc, ud) in listeners { proc(ud, m, param ?? UnsafeRawPointer(bitPattern: 1)!) }
    }
    // beats and seconds through the tempo map (or the tempo)
    var tempos: [(CAClockBeats, CAClockTempo)] { tempoMap.isEmpty ? [(0, tempo)] : tempoMap.map { ($0.beats, $0.tempo) } }
    func seconds(forBeats b: CAClockBeats) -> CAClockSeconds {
        var s = 0.0
        let c = tempos
        for (i, (beat, bpm)) in c.enumerated() {
            let next = i + 1 < c.count ? c[i + 1].0 : .infinity
            if b <= next { return s + (b - beat) * 60 / bpm }
            s += (next - beat) * 60 / bpm
        }
        return s
    }
    func beats(forSeconds sec: CAClockSeconds) -> CAClockBeats {
        var s = 0.0
        let c = tempos
        for (i, (beat, bpm)) in c.enumerated() {
            let next = i + 1 < c.count ? c[i + 1].0 : .infinity
            let span = (next - beat) * 60 / bpm
            if sec <= s + span { return beat + (sec - s) * bpm / 60 }
            s += span
        }
        return 0
    }
    var fps: Double {
        switch SMPTETimeType(rawValue: smpteFormat) {
        case .type24: return 24
        case .type25: return 25
        case .type2997, .type2997Drop: return 29.97
        case .type60: return 60
        case .type5994, .type5994Drop: return 59.94
        case .type60Drop: return 60
        case .type50: return 50
        case .type2398: return 23.976
        default: return 30
        }
    }
    func smpte(_ seconds: CAClockSeconds, subframeDivisor: UInt16) -> SMPTETime {
        let s = max(0, seconds + smpteOffset)
        let frames = s * fps
        let whole = Int(frames)
        let nominal = Int(fps.rounded())
        var t = SMPTETime()
        t.mType = SMPTETimeType(rawValue: smpteFormat) ?? .type30
        t.mHours = Int16(whole / (3600 * nominal) % 24)
        t.mMinutes = Int16(whole / (60 * nominal) % 60)
        t.mSeconds = Int16(whole / nominal % 60)
        t.mFrames = Int16(whole % nominal)
        t.mSubframeDivisor = Int16(subframeDivisor)
        t.mSubframes = Int16((frames - Double(whole)) * Double(subframeDivisor))
        t.mFlags = .valid
        if running { t.mFlags.insert(.running) }
        return t
    }
    func seconds(_ t: SMPTETime) -> CAClockSeconds {
        let nominal = fps.rounded()
        let frames = (Double(t.mHours) * 3600 + Double(t.mMinutes) * 60 + Double(t.mSeconds)) * nominal + Double(t.mFrames)
            + (t.mSubframeDivisor > 0 ? Double(t.mSubframes) / Double(t.mSubframeDivisor) : 0)
        return frames / fps - smpteOffset
    }
    /// a time in another format: through media seconds
    func translate(_ t: CAClockTime, to f: CAClockTimeFormat) -> CAClockTime? {
        var sec: CAClockSeconds
        switch t.format {
        case .seconds: sec = t.time.seconds
        case .hostTime: sec = running ? mediaAtStart + (Double(t.time.hostTime) - Double(hostAtStart)) / 1e9 * playRate : mediaAtStart
        case .beats: sec = seconds(forBeats: t.time.beats)
        case .samples: sec = t.time.samples / 48000
        case .smpteTime: sec = seconds(t.time.smpte)
        case .smpteSeconds: sec = t.time.seconds - smpteOffset
        case .absoluteSeconds: sec = t.time.seconds
        default: return nil
        }
        var out = CAClockTime()
        out.format = f
        switch f {
        case .seconds, .absoluteSeconds: out.time.seconds = sec
        case .hostTime: out.time.hostTime = UInt64(max(0, Double(hostAtStart) + (sec - mediaAtStart) / playRate * 1e9))
        case .beats: out.time.beats = beats(forSeconds: sec)
        case .samples: out.time.samples = sec * 48000
        case .smpteTime: out.time.smpte = smpte(sec, subframeDivisor: 80)
        case .smpteSeconds: out.time.seconds = sec + smpteOffset
        default: return nil
        }
        return out
    }
}

public func CAClockNew(_ inReservedFlags: UInt32, _ outCAClock: UnsafeMutablePointer<CAClockRef?>) -> OSStatus {
    outCAClock.pointee = CAClockRef(Unmanaged.passRetained(_CAClock()).toOpaque())
    return noErr_
}
public func CAClockDispose(_ inCAClock: CAClockRef) -> OSStatus {
    Unmanaged<_CAClock>.fromOpaque(UnsafeRawPointer(inCAClock)).release()
    return noErr_
}
public func CAClockGetPropertyInfo(_ inCAClock: CAClockRef, _ inPropertyID: CAClockPropertyID, _ outSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    let size: Int
    switch inPropertyID {
    case .internalTimebase, .syncMode, .smpteFormat, .sendMIDISPP: size = 4
    case .smpteOffset, .mtcFreewheelTime: size = 8
    case .name, .timebaseSource, .syncSource: size = MemoryLayout<UnsafeRawPointer>.size
    case .tempoMap: size = _CAClock.from(inCAClock).tempoMap.count * 16
    case .meterTrack: size = 16
    case .midiClockDestinations, .mtcDestinations: size = 0
    default: return kCAClock_UnknownPropertyError
    }
    outSize?.pointee = UInt32(size)
    outWritable?.pointee = true
    return noErr_
}
public func CAClockGetProperty(_ inCAClock: CAClockRef, _ inPropertyID: CAClockPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    func put<T>(_ v: T) -> OSStatus {
        guard ioPropertyDataSize.pointee >= UInt32(MemoryLayout<T>.size) else { return kCAClock_InvalidPropertySizeError }
        outPropertyData.storeBytes(of: v, as: T.self)
        ioPropertyDataSize.pointee = UInt32(MemoryLayout<T>.size)
        return noErr_
    }
    switch inPropertyID {
    case .internalTimebase: return put(c.timebase.rawValue)
    case .syncMode: return put(c.syncMode.rawValue)
    case .smpteFormat: return put(c.smpteFormat)
    case .smpteOffset: return put(c.smpteOffset)
    case .name: return put(Unmanaged.passRetained(c.name as CFString))
    case .sendMIDISPP: return put(UInt32(0))
    case .mtcFreewheelTime: return put(Float64(0))
    case .tempoMap:
        let n = min(c.tempoMap.count, Int(ioPropertyDataSize.pointee) / 16)
        for i in 0..<n { outPropertyData.storeBytes(of: c.tempoMap[i].beats, toByteOffset: 16 * i, as: Float64.self); outPropertyData.storeBytes(of: c.tempoMap[i].tempo, toByteOffset: 16 * i + 8, as: Float64.self) }
        ioPropertyDataSize.pointee = UInt32(16 * n)
        return noErr_
    default: return kCAClock_UnknownPropertyError
    }
}
public func CAClockSetProperty(_ inCAClock: CAClockRef, _ inPropertyID: CAClockPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    switch inPropertyID {
    case .internalTimebase:
        guard let t = CAClockTimebase(rawValue: inPropertyData.load(as: UInt32.self)) else { return kCAClock_InvalidTimebaseError }
        c.timebase = t
    case .syncMode:
        guard let m = CAClockSyncMode(rawValue: inPropertyData.load(as: UInt32.self)) else { return kCAClock_InvalidSyncModeError }
        c.syncMode = m
    case .smpteFormat:
        let f = inPropertyData.load(as: UInt32.self)
        guard f <= 11 else { return kCAClock_InvalidSMPTEFormatError }
        c.smpteFormat = f
    case .smpteOffset: c.smpteOffset = inPropertyData.load(as: CAClockSeconds.self)
    case .name: c.name = Unmanaged<CFString>.fromOpaque(inPropertyData.load(as: UnsafeRawPointer.self)).takeUnretainedValue() as String
    case .tempoMap:
        c.tempoMap = (0..<Int(inPropertyDataSize) / 16).map { (inPropertyData.load(fromByteOffset: 16 * $0, as: Float64.self), inPropertyData.load(fromByteOffset: 16 * $0 + 8, as: Float64.self)) }
    case .meterTrack:
        if inPropertyDataSize >= 16 { c.meter = (Int(inPropertyData.load(fromByteOffset: 8, as: UInt16.self)), Int(inPropertyData.load(fromByteOffset: 10, as: UInt16.self))) }
    case .timebaseSource, .syncSource, .midiClockDestinations, .mtcDestinations, .mtcFreewheelTime, .sendMIDISPP: break
    default: return kCAClock_UnknownPropertyError
    }
    c.notify(.propertyChanged, withUnsafeBytes(of: inPropertyID.rawValue) { $0.baseAddress })
    return noErr_
}
public func CAClockAddListener(_ inCAClock: CAClockRef, _ inListenerProc: CAClockListenerProc, _ inUserData: UnsafeMutableRawPointer) -> OSStatus {
    _CAClock.from(inCAClock).listeners.append((inListenerProc, inUserData))
    return noErr_
}
public func CAClockRemoveListener(_ inCAClock: CAClockRef, _ inListenerProc: CAClockListenerProc, _ inUserData: UnsafeMutableRawPointer) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    if let i = c.listeners.firstIndex(where: { unsafeBitCast($0.0, to: UnsafeRawPointer.self) == unsafeBitCast(inListenerProc, to: UnsafeRawPointer.self) && $0.1 == inUserData }) {
        c.listeners.remove(at: i)
    }
    return noErr_
}
public func CAClockSetCurrentTime(_ inCAClock: CAClockRef, _ inTime: UnsafePointer<CAClockTime>) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    guard !c.running else { return kCAClock_CannotSetTimeError }
    guard let t = c.translate(inTime.pointee, to: .seconds) else { return kCAClock_InvalidTimeFormatError }
    c.mediaAtStart = t.time.seconds
    c.notify(.startTimeSet)
    return noErr_
}
public func CAClockGetCurrentTime(_ inCAClock: CAClockRef, _ inTimeFormat: CAClockTimeFormat, _ outTime: UnsafeMutablePointer<CAClockTime>) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    var now = CAClockTime()
    now.format = .seconds; now.time.seconds = c.media
    if inTimeFormat == .hostTime { now.format = .hostTime; now.time.hostTime = _CAClock.now(); outTime.pointee = now; return noErr_ }
    guard let t = c.translate(now, to: inTimeFormat) else { return kCAClock_InvalidTimeFormatError }
    outTime.pointee = t
    return noErr_
}
public func CAClockGetStartTime(_ inCAClock: CAClockRef, _ inTimeFormat: CAClockTimeFormat, _ outTime: UnsafeMutablePointer<CAClockTime>) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    var start = CAClockTime()
    start.format = .seconds; start.time.seconds = c.running ? c.mediaAtStart : c.mediaAtStart
    if inTimeFormat == .hostTime { start.format = .hostTime; start.time.hostTime = c.startHost; outTime.pointee = start; return noErr_ }
    guard let t = c.translate(start, to: inTimeFormat) else { return kCAClock_InvalidTimeFormatError }
    outTime.pointee = t
    return noErr_
}
public func CAClockTranslateTime(_ inCAClock: CAClockRef, _ inTime: UnsafePointer<CAClockTime>, _ inOutputTimeFormat: CAClockTimeFormat, _ outTime: UnsafeMutablePointer<CAClockTime>) -> OSStatus {
    guard let t = _CAClock.from(inCAClock).translate(inTime.pointee, to: inOutputTimeFormat) else { return kCAClock_InvalidTimeFormatError }
    outTime.pointee = t
    return noErr_
}
public func CAClockStart(_ inCAClock: CAClockRef) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    guard !c.running else { return noErr_ }
    c.hostAtStart = _CAClock.now(); c.startHost = c.hostAtStart
    c.running = true
    c.notify(.started)
    return noErr_
}
public func CAClockStop(_ inCAClock: CAClockRef) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    guard c.running else { return noErr_ }
    c.mediaAtStart = c.media
    c.running = false
    c.notify(.stopped)
    return noErr_
}
public func CAClockArm(_ inCAClock: CAClockRef) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    c.armed = true
    c.notify(.armed)
    return noErr_
}
public func CAClockDisarm(_ inCAClock: CAClockRef) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    c.armed = false
    c.notify(.disarmed)
    return noErr_
}
public func CAClockSetPlayRate(_ inCAClock: CAClockRef, _ inPlayRate: Float64) -> OSStatus {
    guard inPlayRate > 0 else { return kCAClock_InvalidPlayRateError }
    let c = _CAClock.from(inCAClock)
    if c.running { c.mediaAtStart = c.media; c.hostAtStart = _CAClock.now() }
    c.playRate = inPlayRate
    return noErr_
}
public func CAClockGetPlayRate(_ inCAClock: CAClockRef, _ outPlayRate: UnsafeMutablePointer<Float64>) -> OSStatus {
    outPlayRate.pointee = _CAClock.from(inCAClock).playRate
    return noErr_
}
public func CAClockGetCurrentTempo(_ inCAClock: CAClockRef, _ outTempo: UnsafeMutablePointer<CAClockTempo>, _ outTimestamp: UnsafeMutablePointer<CAClockTime>?) -> OSStatus {
    let c = _CAClock.from(inCAClock)
    let beat = c.beats(forSeconds: c.media)
    outTempo.pointee = c.tempos.last { $0.0 <= beat }?.1 ?? c.tempo
    if let outTimestamp { var t = CAClockTime(); t.format = .beats; t.time.beats = beat; outTimestamp.pointee = t }
    return noErr_
}
public func CAClockSetCurrentTempo(_ inCAClock: CAClockRef, _ inTempo: CAClockTempo, _ inTimestamp: UnsafePointer<CAClockTime>?) -> OSStatus {
    guard inTempo > 0 else { return kAudio_ParamError }
    let c = _CAClock.from(inCAClock)
    if let ts = inTimestamp, let b = c.translate(ts.pointee, to: .beats)?.time.beats, b > 0 {
        if c.tempoMap.isEmpty { c.tempoMap = [(0, c.tempo)] }
        c.tempoMap.removeAll { $0.beats >= b }
        c.tempoMap.append((b, inTempo))
    } else { c.tempo = inTempo; c.tempoMap = [] }
    return noErr_
}
public func CAClockSecondsToSMPTETime(_ inCAClock: CAClockRef, _ inSeconds: CAClockSeconds, _ inSubframeDivisor: UInt16, _ outSMPTETime: UnsafeMutablePointer<SMPTETime>) -> OSStatus {
    outSMPTETime.pointee = _CAClock.from(inCAClock).smpte(inSeconds, subframeDivisor: inSubframeDivisor)
    return noErr_
}
public func CAClockSMPTETimeToSeconds(_ inCAClock: CAClockRef, _ inSMPTETime: UnsafePointer<SMPTETime>, _ outSeconds: UnsafeMutablePointer<CAClockSeconds>) -> OSStatus {
    outSeconds.pointee = _CAClock.from(inCAClock).seconds(inSMPTETime.pointee)
    return noErr_
}
public func CAClockBeatsToBarBeatTime(_ inCAClock: CAClockRef, _ inBeats: CAClockBeats, _ inSubbeatDivisor: UInt16, _ outBarBeatTime: UnsafeMutablePointer<CABarBeatTime>) -> OSStatus {
    let (num, den) = _CAClock.from(inCAClock).meter
    let beatLength = 4.0 / Double(max(1, den)), beatsInBar = Double(num) * beatLength
    let bar = Int(floor(inBeats / beatsInBar)), inBar = inBeats - Double(bar) * beatsInBar
    let beat = Int(floor(inBar / beatLength))
    let sub = (inBar - Double(beat) * beatLength) / beatLength * Double(max(1, inSubbeatDivisor))
    outBarBeatTime.pointee = CABarBeatTime(bar: Int32(bar + 1), beat: UInt16(beat + 1), subbeat: UInt16(sub.rounded(.down)), subbeatDivisor: inSubbeatDivisor, reserved: 0)
    return noErr_
}
public func CAClockBarBeatTimeToBeats(_ inCAClock: CAClockRef, _ inBarBeatTime: UnsafePointer<CABarBeatTime>, _ outBeats: UnsafeMutablePointer<CAClockBeats>) -> OSStatus {
    let (num, den) = _CAClock.from(inCAClock).meter
    let t = inBarBeatTime.pointee, beatLength = 4.0 / Double(max(1, den))
    outBeats.pointee = Double(Int(t.bar) - 1) * Double(num) * beatLength + Double(Int(t.beat) - 1) * beatLength
        + (t.subbeatDivisor > 0 ? Double(t.subbeat) / Double(t.subbeatDivisor) * beatLength : 0)
    return noErr_
}
public func CAClockParseMIDI(_ inCAClock: CAClockRef, _ inMIDIPacketList: UnsafePointer<MIDIPacketList>) -> OSStatus { noErr_ }
