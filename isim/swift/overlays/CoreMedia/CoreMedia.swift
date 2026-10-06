// isim CoreMedia (subset): CMTime, CMTimeRange and their functions, NSValue(time:). Self-authored, pure Swift.
// No sample buffers, format descriptions or clocks.
@_exported import Foundation
import ObjectiveC

public typealias CMTimeValue = Int64
public typealias CMTimeScale = Int32
public typealias CMTimeEpoch = Int64

public struct CMTimeFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let valid = CMTimeFlags(rawValue: 1)
    public static let hasBeenRounded = CMTimeFlags(rawValue: 2)
    public static let positiveInfinity = CMTimeFlags(rawValue: 4)
    public static let negativeInfinity = CMTimeFlags(rawValue: 8)
    public static let indefinite = CMTimeFlags(rawValue: 16)
    public static let impliedValueFlagsMask: CMTimeFlags = [.positiveInfinity, .negativeInfinity, .indefinite]
}

public enum CMTimeRoundingMethod: UInt32, Sendable {
    case roundHalfAwayFromZero = 1, roundTowardZero = 2, roundAwayFromZero = 3, quickTime = 4, roundTowardPositiveInfinity = 5, roundTowardNegativeInfinity = 6
    public static let `default` = CMTimeRoundingMethod.roundHalfAwayFromZero
}

public let kCMTimeMaxTimescale: Int32 = 0x7fffffff

public struct CMTime: Sendable, Hashable, Comparable, CustomStringConvertible {
    public var value: CMTimeValue
    public var timescale: CMTimeScale
    public var flags: CMTimeFlags
    public var epoch: CMTimeEpoch
    public init() { value = 0; timescale = 0; flags = []; epoch = 0 }
    public init(value: CMTimeValue, timescale: CMTimeScale, flags: CMTimeFlags, epoch: CMTimeEpoch) {
        self.value = value; self.timescale = timescale; self.flags = flags; self.epoch = epoch
    }
    public init(value: CMTimeValue, timescale: CMTimeScale) {
        self.init(value: value, timescale: timescale, flags: timescale > 0 ? .valid : [], epoch: 0)
    }
    public init(seconds: Double, preferredTimescale: CMTimeScale) {
        if seconds.isNaN || preferredTimescale <= 0 { self = .invalid; return }
        if seconds.isInfinite { self = seconds > 0 ? .positiveInfinity : .negativeInfinity; return }
        let v = (seconds * Double(preferredTimescale)).rounded()
        self.init(value: CMTimeValue(v), timescale: preferredTimescale)
        if v / Double(preferredTimescale) != seconds { flags.insert(.hasBeenRounded) }
    }

    public static let zero = CMTime(value: 0, timescale: 1)
    public static let invalid = CMTime()
    public static let indefinite = CMTime(value: 0, timescale: 0, flags: [.valid, .indefinite], epoch: 0)
    public static let positiveInfinity = CMTime(value: 0, timescale: 0, flags: [.valid, .positiveInfinity], epoch: 0)
    public static let negativeInfinity = CMTime(value: 0, timescale: 0, flags: [.valid, .negativeInfinity], epoch: 0)

    public var isValid: Bool { flags.contains(.valid) }
    public var isIndefinite: Bool { isValid && flags.contains(.indefinite) }
    public var isPositiveInfinity: Bool { isValid && flags.contains(.positiveInfinity) }
    public var isNegativeInfinity: Bool { isValid && flags.contains(.negativeInfinity) }
    public var isNumeric: Bool { isValid && flags.intersection(.impliedValueFlagsMask).isEmpty }
    public var hasBeenRounded: Bool { flags.contains(.hasBeenRounded) }
    public var seconds: Double {
        if isPositiveInfinity { return .infinity }
        if isNegativeInfinity { return -.infinity }
        guard isNumeric, timescale != 0 else { return .nan }
        return Double(value) / Double(timescale)
    }
    public func convertScale(_ newTimescale: Int32, method: CMTimeRoundingMethod) -> CMTime { CMTimeConvertScale(self, timescale: newTimescale, method: method) }

    public var description: String {
        if !isValid { return "CMTime(invalid)" }
        if isIndefinite { return "CMTime(indefinite)" }
        if isPositiveInfinity { return "CMTime(+infinity)" }
        if isNegativeInfinity { return "CMTime(-infinity)" }
        return "CMTime(\(value)/\(timescale) = \(seconds))"
    }
    public static func == (a: CMTime, b: CMTime) -> Bool { CMTimeCompare(a, b) == 0 }
    public func hash(into h: inout Hasher) { if isNumeric { h.combine(seconds) } else { h.combine(flags.rawValue) } }
    public static func < (a: CMTime, b: CMTime) -> Bool { CMTimeCompare(a, b) < 0 }
    public static func + (a: CMTime, b: CMTime) -> CMTime { CMTimeAdd(a, b) }
    public static func - (a: CMTime, b: CMTime) -> CMTime { CMTimeSubtract(a, b) }
    public static func += (a: inout CMTime, b: CMTime) { a = CMTimeAdd(a, b) }
    public static func -= (a: inout CMTime, b: CMTime) { a = CMTimeSubtract(a, b) }
    public static func * (a: CMTime, m: Int32) -> CMTime { CMTimeMultiply(a, multiplier: m) }
    public static func * (a: CMTime, m: Double) -> CMTime { CMTimeMultiplyByFloat64(a, multiplier: m) }
    public static prefix func - (a: CMTime) -> CMTime { CMTimeSubtract(.zero, a) }
}

/// Exact rational arithmetic where it fits, otherwise via seconds at the larger timescale.
private func _combine(_ a: CMTime, _ b: CMTime, _ sign: Int64) -> CMTime {
    if !a.isValid || !b.isValid { return .invalid }
    if a.isIndefinite || b.isIndefinite { return .indefinite }
    let ainf = a.isPositiveInfinity ? 1 : a.isNegativeInfinity ? -1 : 0
    let binf = (b.isPositiveInfinity ? 1 : b.isNegativeInfinity ? -1 : 0) * Int(sign)
    if ainf != 0 || binf != 0 {
        if ainf != 0 && binf != 0 && ainf != binf { return .invalid }
        return (ainf != 0 ? ainf : binf) > 0 ? .positiveInfinity : .negativeInfinity
    }
    if a.timescale == b.timescale { return CMTime(value: a.value + sign * b.value, timescale: a.timescale) }
    let (l, o) = Int64(a.timescale).multipliedReportingOverflow(by: Int64(b.timescale) / Int64(_gcd(Int64(a.timescale), Int64(b.timescale))))
    if !o, l <= Int64(kCMTimeMaxTimescale) {
        let av = a.value * (l / Int64(a.timescale)), bv = b.value * (l / Int64(b.timescale))
        return CMTime(value: av + sign * bv, timescale: Int32(l))
    }
    let ts = max(a.timescale, b.timescale)
    return CMTime(seconds: a.seconds + Double(sign) * b.seconds, preferredTimescale: ts)
}
private func _gcd(_ a: Int64, _ b: Int64) -> Int64 { var a = abs(a), b = abs(b); while b != 0 { (a, b) = (b, a % b) }; return max(a, 1) }

public func CMTimeMake(value: Int64, timescale: Int32) -> CMTime { CMTime(value: value, timescale: timescale) }
public func CMTimeMakeWithSeconds(_ seconds: Float64, preferredTimescale: Int32) -> CMTime { CMTime(seconds: seconds, preferredTimescale: preferredTimescale) }
public func CMTimeMakeWithEpoch(value: Int64, timescale: Int32, epoch: Int64) -> CMTime { CMTime(value: value, timescale: timescale, flags: .valid, epoch: epoch) }
public func CMTimeGetSeconds(_ t: CMTime) -> Float64 { t.seconds }
public func CMTimeAdd(_ a: CMTime, _ b: CMTime) -> CMTime { _combine(a, b, 1) }
public func CMTimeSubtract(_ a: CMTime, _ b: CMTime) -> CMTime { _combine(a, b, -1) }
public func CMTimeMultiply(_ t: CMTime, multiplier: Int32) -> CMTime {
    guard t.isNumeric else { return t }
    return CMTime(value: t.value * Int64(multiplier), timescale: t.timescale)
}
public func CMTimeMultiplyByFloat64(_ t: CMTime, multiplier: Float64) -> CMTime {
    guard t.isNumeric else { return t }
    return CMTime(seconds: t.seconds * multiplier, preferredTimescale: t.timescale)
}
public func CMTimeMultiplyByRatio(_ t: CMTime, multiplier: Int32, divisor: Int32) -> CMTime {
    guard t.isNumeric, divisor != 0 else { return .invalid }
    return CMTime(seconds: t.seconds * Double(multiplier) / Double(divisor), preferredTimescale: t.timescale)
}
/// -1, 0 or 1. Invalid times sort before everything; indefinite after numeric times.
public func CMTimeCompare(_ a: CMTime, _ b: CMTime) -> Int32 {
    func rank(_ t: CMTime) -> Int { !t.isValid ? 0 : t.isNegativeInfinity ? 1 : t.isNumeric ? 2 : t.isPositiveInfinity ? 3 : 4 }
    let ra = rank(a), rb = rank(b)
    if ra != rb { return ra < rb ? -1 : 1 }
    guard ra == 2 else { return 0 }
    if a.timescale == b.timescale { return a.value < b.value ? -1 : a.value > b.value ? 1 : 0 }
    let l = a.value.multipliedFullWidth(by: Int64(b.timescale)), r = b.value.multipliedFullWidth(by: Int64(a.timescale))
    return (l.high, l.low) < (r.high, r.low) ? -1 : (l.high, l.low) > (r.high, r.low) ? 1 : 0
}
public func CMTimeMinimum(_ a: CMTime, _ b: CMTime) -> CMTime { CMTimeCompare(a, b) <= 0 ? a : b }
public func CMTimeMaximum(_ a: CMTime, _ b: CMTime) -> CMTime { CMTimeCompare(a, b) >= 0 ? a : b }
public func CMTimeAbsoluteValue(_ t: CMTime) -> CMTime { t.isNumeric && t.value < 0 ? CMTime(value: -t.value, timescale: t.timescale) : t }
public func CMTimeConvertScale(_ t: CMTime, timescale: Int32, method: CMTimeRoundingMethod) -> CMTime {
    guard t.isNumeric, timescale > 0 else { return t }
    let x = Double(t.value) * Double(timescale) / Double(t.timescale)
    let r: Double
    switch method {
    case .roundTowardZero: r = x.rounded(.towardZero)
    case .roundAwayFromZero: r = x.rounded(.awayFromZero)
    case .roundTowardPositiveInfinity: r = x.rounded(.up)
    case .roundTowardNegativeInfinity: r = x.rounded(.down)
    default: r = x.rounded(.toNearestOrAwayFromZero)
    }
    var out = CMTime(value: CMTimeValue(r), timescale: timescale)
    if r != x { out.flags.insert(.hasBeenRounded) }
    return out
}
public func CMTimeShow(_ t: CMTime) { print("{\(t.value)/\(t.timescale) = \(t.seconds)}") }
public func CMTimeCopyDescription(allocator: Any?, time: CMTime) -> String { time.description }

// MARK: - CMTimeRange

public struct CMTimeRange: Sendable, Hashable, CustomStringConvertible {
    public var start: CMTime
    public var duration: CMTime
    public init() { start = .invalid; duration = .invalid }
    public init(start: CMTime, duration: CMTime) { self.start = start; self.duration = duration }
    public init(start: CMTime, end: CMTime) { self.start = start; duration = end - start }
    public static let zero = CMTimeRange(start: .zero, duration: .zero)
    public static let invalid = CMTimeRange()
    public var end: CMTime { start + duration }
    public var isValid: Bool { start.isValid && duration.isValid && !duration.isNegativeInfinity && (!duration.isNumeric || duration.value >= 0) }
    public var isIndefinite: Bool { isValid && (start.isIndefinite || duration.isIndefinite) }
    public var isEmpty: Bool { isValid && duration == .zero }
    public func containsTime(_ t: CMTime) -> Bool { isValid && t >= start && t < end }
    public func containsTimeRange(_ r: CMTimeRange) -> Bool { isValid && r.isValid && r.start >= start && r.end <= end }
    public func intersection(_ o: CMTimeRange) -> CMTimeRange {
        let s = CMTimeMaximum(start, o.start), e = CMTimeMinimum(end, o.end)
        return e > s ? CMTimeRange(start: s, end: e) : CMTimeRange(start: s, duration: .zero)
    }
    public func union(_ o: CMTimeRange) -> CMTimeRange { CMTimeRange(start: CMTimeMinimum(start, o.start), end: CMTimeMaximum(end, o.end)) }
    public var description: String { "CMTimeRange(start: \(start), duration: \(duration))" }
}
public func CMTimeRangeMake(start: CMTime, duration: CMTime) -> CMTimeRange { CMTimeRange(start: start, duration: duration) }
public func CMTimeRangeFromTimeToTime(start: CMTime, end: CMTime) -> CMTimeRange { CMTimeRange(start: start, end: end) }
public func CMTimeRangeGetEnd(_ r: CMTimeRange) -> CMTime { r.end }
public func CMTimeRangeContainsTime(_ r: CMTimeRange, time: CMTime) -> Bool { r.containsTime(time) }
public func CMTimeRangeGetIntersection(_ r: CMTimeRange, otherRange: CMTimeRange) -> CMTimeRange { r.intersection(otherRange) }
public func CMTimeRangeGetUnion(_ r: CMTimeRange, otherRange: CMTimeRange) -> CMTimeRange { r.union(otherRange) }
public func CMTimeRangeEqual(_ a: CMTimeRange, _ b: CMTimeRange) -> Bool { a == b }
public func CMTimeClampToRange(_ t: CMTime, range: CMTimeRange) -> CMTime { CMTimeMinimum(CMTimeMaximum(t, range.start), range.end) }

public struct CMTimeMapping: Sendable, Hashable {
    public var source: CMTimeRange
    public var target: CMTimeRange
    public init(source: CMTimeRange, target: CMTimeRange) { self.source = source; self.target = target }
}

// MARK: - NSValue boxing (AVFoundation boundary times)

private final class _CMTimeBox: NSObject { let time: CMTime; let range: CMTimeRange?; init(_ t: CMTime, _ r: CMTimeRange?) { time = t; range = r } }
nonisolated(unsafe) private var _cmTimeKey: UInt8 = 0
extension NSValue {
    public convenience init(time: CMTime) {
        self.init()
        objc_setAssociatedObject(self, &_cmTimeKey, _CMTimeBox(time, nil), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    public convenience init(timeRange: CMTimeRange) {
        self.init()
        objc_setAssociatedObject(self, &_cmTimeKey, _CMTimeBox(timeRange.start, timeRange), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    public var timeValue: CMTime { (objc_getAssociatedObject(self, &_cmTimeKey) as? _CMTimeBox)?.time ?? .invalid }
    public var timeRangeValue: CMTimeRange { (objc_getAssociatedObject(self, &_cmTimeKey) as? _CMTimeBox)?.range ?? .invalid }
}
