// isim CoreMedia clocks and timebases (self-authored, iOS API names): CMClock (the host time clock, audio clocks),
// CMTimebase (a time that runs at a rate against a clock or another timebase, with timers) and the CMSync functions.
// The host time clock is the monotonic uptime clock (CLOCK_MONOTONIC, the same as CACurrentMediaTime and capture
// timestamps). Audio clocks follow it (adapted: isim's mixer has no drifting hardware clock).
@_exported import CoreVideo
import AudioToolbox

public typealias CMClockOrTimebase = AnyObject

/// A clock: time that advances on its own.
public final class CMClock: @unchecked Sendable, Hashable {
    public static func == (a: CMClock, b: CMClock) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    let _name: String
    init(_ name: String) { _name = name }
    /// the host time clock (seconds of uptime)
    public static let hostTimeClock = CMClock("host")
    public var time: CMTime { CMTime(value: Int64((ProcessInfo.processInfo.systemUptime * 1e9).rounded()), timescale: 1_000_000_000) }
    public func convertTime(_ time: CMTime, to other: CMClockOrTimebase) -> CMTime { CMSyncConvertTime(time, from: self, to: other) }
    public func mightDrift(relativeTo other: CMClock) -> Bool { false }
    public func invalidate() {}
}
public func CMClockGetHostTimeClock() -> CMClock { .hostTimeClock }
public func CMClockGetTime(_ clock: CMClock) -> CMTime { clock.time }
public func CMClockConvertHostTimeToSystemUnits(_ hostTime: CMTime) -> UInt64 { UInt64(max(0, hostTime.seconds) * 1e9) }
public func CMClockMakeHostTimeFromSystemUnits(_ hostTime: UInt64) -> CMTime { CMTime(value: Int64(hostTime), timescale: 1_000_000_000) }
public func CMClockMightDrift(_ clock: CMClock, _ otherClock: CMClock) -> Bool { false }
public func CMClockInvalidate(_ clock: CMClock) {}
@discardableResult
public func CMClockGetAnchorTime(_ clock: CMClock, clockTimeOut: UnsafeMutablePointer<CMTime>, referenceClockTimeOut: UnsafeMutablePointer<CMTime>) -> OSStatus {
    let t = clock.time; clockTimeOut.pointee = t; referenceClockTimeOut.pointee = t; return noErr
}
/// isim: an audio device clock follows the host time clock
@discardableResult
public func CMAudioClockCreate(allocator: CFAllocator?, clockOut: UnsafeMutablePointer<CMClock?>) -> OSStatus {
    clockOut.pointee = CMClock("audio"); return noErr
}
public let kCMTimebaseError_MissingRequiredParameter: OSStatus = -12748
public let kCMTimebaseError_InvalidParameter: OSStatus = -12749
public let kCMTimebaseError_TimerIntervalTooShort: OSStatus = -12751
public let kCMTimebaseNotification_EffectiveRateChanged = "CMTimebaseEffectiveRateChanged" as CFString
public let kCMTimebaseNotification_TimeJumped = "CMTimebaseTimeJumped" as CFString
public let kCMTimebaseNotificationKey_EventTime = "EventTime" as CFString
public let kCMTimebaseVeryLongCFTimeInterval: Double = 256.0 * 365.0 * 24.0 * 60.0 * 60.0
public let kCMTimebaseFarFutureCFAbsoluteTime: Double = kCMTimebaseVeryLongCFTimeInterval

/// A timebase: time = anchor time + rate × (source time - anchor source time). Timers added to it fire when its time
/// reaches their next fire time.
public final class CMTimebase: @unchecked Sendable, Hashable {
    public static func == (a: CMTimebase, b: CMTimebase) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    public let sourceClock: CMClock?
    public let sourceTimebase: CMTimebase?
    let lock = NSLock()
    var _rate: Double = 0
    var _anchor = 0.0, _anchorSource = 0.0
    /// isim: a timebase that mirrors something else's time (AVPlayerItem.timebase)
    var _provider: (() -> (Double, Double))?
    struct _Timer { weak var timer: Timer?; var fire: Double }
    var _timers: [_Timer] = []
    public init(sourceClock: CMClock) { self.sourceClock = sourceClock; sourceTimebase = nil; _anchorSource = sourceClock.time.seconds }
    public init(sourceTimebase: CMTimebase) { self.sourceTimebase = sourceTimebase; sourceClock = nil; _anchorSource = sourceTimebase.time.seconds }
    @available(*, deprecated, renamed: "init(sourceClock:)") public convenience init(masterClock: CMClock) { self.init(sourceClock: masterClock) }
    /// isim: a read-only timebase whose (time, rate) come from `provider`
    public init(_isimProvider provider: @escaping () -> (Double, Double)) { sourceClock = .hostTimeClock; sourceTimebase = nil; _provider = provider }
    var _sourceSeconds: Double { sourceTimebase?.time.seconds ?? sourceClock?.time.seconds ?? ProcessInfo.processInfo.systemUptime }
    func _seconds() -> Double {
        if let p = _provider { return p().0 }
        lock.lock(); defer { lock.unlock() }
        return _anchor + _rate * (_sourceSeconds - _anchorSource)
    }
    public var time: CMTime { CMTime(seconds: _seconds(), preferredTimescale: 1_000_000_000) }
    public func time(preferredTimescale: CMTimeScale) -> CMTime { CMTime(seconds: _seconds(), preferredTimescale: preferredTimescale) }
    public var rate: Float64 { _provider?().1 ?? { lock.lock(); defer { lock.unlock() }; return _rate }() }
    public var effectiveRate: Float64 { rate * (sourceTimebase?.effectiveRate ?? 1) }
    public var sourceClockOrTimebase: CMClockOrTimebase? { sourceTimebase ?? sourceClock }
    public var ultimateSourceClock: CMClock { sourceTimebase?.ultimateSourceClock ?? sourceClock ?? .hostTimeClock }
    public func setTime(_ t: CMTime) {
        lock.lock(); _anchor = t.seconds; _anchorSource = _sourceSeconds; lock.unlock()
        _post(kCMTimebaseNotification_TimeJumped); _reschedule()
    }
    public func setRate(_ r: Float64) {
        lock.lock(); let now = _anchor + _rate * (_sourceSeconds - _anchorSource); _anchor = now; _anchorSource = _sourceSeconds; let changed = _rate != r; _rate = r; lock.unlock()
        if changed { _post(kCMTimebaseNotification_EffectiveRateChanged) }
        _reschedule()
    }
    public func setRateAndAnchorTime(rate r: Float64, anchorTime: CMTime, immediateSourceTime: CMTime) {
        lock.lock(); _rate = r; _anchor = anchorTime.seconds; _anchorSource = immediateSourceTime.seconds; lock.unlock()
        _post(kCMTimebaseNotification_EffectiveRateChanged); _post(kCMTimebaseNotification_TimeJumped); _reschedule()
    }
    public func setAnchorTime(_ anchorTime: CMTime, immediateSourceTime: CMTime) {
        lock.lock(); _anchor = anchorTime.seconds; _anchorSource = immediateSourceTime.seconds; lock.unlock()
        _post(kCMTimebaseNotification_TimeJumped); _reschedule()
    }
    public func addTimer(_ timer: Timer, runloop: RunLoop) {
        timer.fireDate = .distantFuture
        runloop.add(timer, forMode: .common)
        lock.lock(); _timers.removeAll { $0.timer == nil || $0.timer === timer }; _timers.append(_Timer(timer: timer, fire: .infinity)); lock.unlock()
    }
    public func removeTimer(_ timer: Timer) { lock.lock(); _timers.removeAll { $0.timer === timer }; lock.unlock(); timer.fireDate = .distantFuture }
    public func setTimerNextFireTime(_ timer: Timer, fireTime: CMTime) {
        lock.lock()
        for i in _timers.indices where _timers[i].timer === timer { _timers[i].fire = fireTime.isNumeric ? fireTime.seconds : .infinity }
        lock.unlock()
        _reschedule()
    }
    public func setTimerToFireImmediately(_ timer: Timer) { timer.fireDate = Date() }
    /// the host date when the timebase reaches each timer's fire time (never while stopped or running away from it)
    func _reschedule() {
        let now = _seconds(), r = rate
        lock.lock(); let timers = _timers; lock.unlock()
        for t in timers {
            guard let timer = t.timer else { continue }
            let delta = t.fire - now
            if !t.fire.isFinite || r == 0 || (delta > 0) != (r > 0) && delta != 0 { timer.fireDate = delta == 0 ? Date() : .distantFuture; continue }
            timer.fireDate = Date(timeIntervalSinceNow: max(0, delta / r))
        }
    }
    func _post(_ name: CFString) {
        NotificationCenter.default.post(name: Notification.Name(name as String), object: self,
                                        userInfo: [kCMTimebaseNotificationKey_EventTime as String: NSValue(time: time)])
    }
}

@discardableResult
public func CMTimebaseCreateWithSourceClock(allocator: CFAllocator?, sourceClock: CMClock, timebaseOut: UnsafeMutablePointer<CMTimebase?>) -> OSStatus {
    timebaseOut.pointee = CMTimebase(sourceClock: sourceClock); return noErr
}
@available(*, deprecated, renamed: "CMTimebaseCreateWithSourceClock")
@discardableResult
public func CMTimebaseCreateWithMasterClock(allocator: CFAllocator?, masterClock: CMClock, timebaseOut: UnsafeMutablePointer<CMTimebase?>) -> OSStatus {
    timebaseOut.pointee = CMTimebase(sourceClock: masterClock); return noErr
}
@discardableResult
public func CMTimebaseCreateWithSourceTimebase(allocator: CFAllocator?, sourceTimebase: CMTimebase, timebaseOut: UnsafeMutablePointer<CMTimebase?>) -> OSStatus {
    timebaseOut.pointee = CMTimebase(sourceTimebase: sourceTimebase); return noErr
}
public func CMTimebaseGetTime(_ timebase: CMTimebase) -> CMTime { timebase.time }
public func CMTimebaseGetTimeWithTimeScale(_ timebase: CMTimebase, timeScale: CMTimeScale, roundingMethod: CMTimeRoundingMethod) -> CMTime { timebase.time(preferredTimescale: timeScale) }
@discardableResult public func CMTimebaseSetTime(_ timebase: CMTimebase, time: CMTime) -> OSStatus { timebase.setTime(time); return noErr }
public func CMTimebaseGetRate(_ timebase: CMTimebase) -> Float64 { timebase.rate }
public func CMTimebaseGetEffectiveRate(_ timebase: CMTimebase) -> Float64 { timebase.effectiveRate }
@discardableResult public func CMTimebaseSetRate(_ timebase: CMTimebase, rate: Float64) -> OSStatus { timebase.setRate(rate); return noErr }
@discardableResult
public func CMTimebaseSetRateAndAnchorTime(_ timebase: CMTimebase, rate: Float64, anchorTime: CMTime, immediateSourceTime: CMTime) -> OSStatus {
    timebase.setRateAndAnchorTime(rate: rate, anchorTime: anchorTime, immediateSourceTime: immediateSourceTime); return noErr
}
@discardableResult
public func CMTimebaseSetAnchorTime(_ timebase: CMTimebase, timebaseTime: CMTime, immediateSourceTime: CMTime) -> OSStatus {
    timebase.setAnchorTime(timebaseTime, immediateSourceTime: immediateSourceTime); return noErr
}
public func CMTimebaseCopySourceClock(_ timebase: CMTimebase) -> CMClock? { timebase.sourceClock }
public func CMTimebaseCopySourceTimebase(_ timebase: CMTimebase) -> CMTimebase? { timebase.sourceTimebase }
public func CMTimebaseCopyUltimateSourceClock(_ timebase: CMTimebase) -> CMClock { timebase.ultimateSourceClock }
@discardableResult public func CMTimebaseAddTimer(_ timebase: CMTimebase, timer: Timer, runloop: RunLoop) -> OSStatus { timebase.addTimer(timer, runloop: runloop); return noErr }
@discardableResult public func CMTimebaseRemoveTimer(_ timebase: CMTimebase, timer: Timer) -> OSStatus { timebase.removeTimer(timer); return noErr }
@discardableResult
public func CMTimebaseSetTimerNextFireTime(_ timebase: CMTimebase, timer: Timer, fireTime: CMTime, flags: UInt32) -> OSStatus {
    timebase.setTimerNextFireTime(timer, fireTime: fireTime); return noErr
}
@discardableResult public func CMTimebaseSetTimerToFireImmediately(_ timebase: CMTimebase, timer: Timer) -> OSStatus { timebase.setTimerToFireImmediately(timer); return noErr }

// MARK: - CMSync

func _syncSeconds(_ x: CMClockOrTimebase) -> Double {
    if let c = x as? CMClock { return c.time.seconds }
    if let t = x as? CMTimebase { return t._seconds() }
    return ProcessInfo.processInfo.systemUptime
}
func _syncRate(_ x: CMClockOrTimebase) -> Double { (x as? CMTimebase)?.effectiveRate ?? 1 }
public func CMSyncGetTime(_ clockOrTimebase: CMClockOrTimebase) -> CMTime { CMTime(seconds: _syncSeconds(clockOrTimebase), preferredTimescale: 1_000_000_000) }
/// a time of one clock or timebase in another's terms (through the host time clock both run on)
public func CMSyncConvertTime(_ time: CMTime, from fromClockOrTimebase: CMClockOrTimebase, to toClockOrTimebase: CMClockOrTimebase) -> CMTime {
    let fr = _syncRate(fromClockOrTimebase), tr = _syncRate(toClockOrTimebase)
    let fnow = _syncSeconds(fromClockOrTimebase), tnow = _syncSeconds(toClockOrTimebase)
    let host = fr != 0 ? (time.seconds - fnow) / fr : 0           // host seconds from now
    return CMTime(seconds: tnow + host * tr, preferredTimescale: max(time.timescale, 600))
}
public func CMSyncGetRelativeRate(_ ofClockOrTimebase: CMClockOrTimebase, relativeTo: CMClockOrTimebase) -> Float64 {
    let r = _syncRate(relativeTo)
    return r != 0 ? _syncRate(ofClockOrTimebase) / r : 0
}
public func CMSyncMightDrift(_ a: CMClockOrTimebase, _ b: CMClockOrTimebase) -> Bool { false }
