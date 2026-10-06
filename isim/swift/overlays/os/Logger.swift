// isim os: unified logging for Swift (Logger, OSLog, os_log, OSLogMessage interpolation with privacy) and
// signposts (accepted, not recorded). Self-authored, iOS API names.
//
// Messages go to stderr in the compact `log stream` style, so `isim run` shows them:
//   2026-10-05 12:00:00.123 Df MyApp[4242:1a2b] [com.example.app:network] Loaded 3 items for <private>
// Type codes: Df default/notice, I info, Db debug, E error, F fault.
// Privacy follows iOS: dynamic strings and objects are <private> unless marked .public; integers, floats and
// booleans are public by default. ISIM_LOG_PRIVATE=1 shows private values (like a debugger-attached run).
// ISIM_LOG_LEVEL=debug|info|default|error|fault hides messages below that level (default: debug, all shown).
@_exported import os
import Foundation

// MARK: - Types

public struct OSLogType: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public init(_ rawValue: UInt8) { self.rawValue = rawValue }
    public static let `default` = OSLogType(rawValue: 0x00)
    public static let info = OSLogType(rawValue: 0x01)
    public static let debug = OSLogType(rawValue: 0x02)
    public static let error = OSLogType(rawValue: 0x10)
    public static let fault = OSLogType(rawValue: 0x11)
    var code: String {
        switch rawValue { case 0x01: return "I "; case 0x02: return "Db"; case 0x10: return "E "; case 0x11: return "F "; default: return "Df" }
    }
    var rank: Int {
        switch rawValue { case 0x02: return 0; case 0x01: return 1; case 0x10: return 3; case 0x11: return 4; default: return 2 }
    }
}

public final class OSLog: NSObject, @unchecked Sendable {
    public struct Category: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let pointsOfInterest = Category(rawValue: "PointsOfInterest")
        public static let dynamicTracing = Category(rawValue: "DynamicTracing")
        public static let dynamicStackTracing = Category(rawValue: "DynamicStackTracing")
    }
    let subsystem: String, category: String, disabled: Bool
    init(subsystem: String, category: String, disabled: Bool) { self.subsystem = subsystem; self.category = category; self.disabled = disabled }
    public convenience init(subsystem: String, category: String) { self.init(subsystem: subsystem, category: category, disabled: false) }
    public convenience init(subsystem: String, category: Category) { self.init(subsystem: subsystem, category: category.rawValue, disabled: false) }
    public static let `default` = OSLog(subsystem: "", category: "", disabled: false)
    public static let disabled = OSLog(subsystem: "", category: "", disabled: true)
    public func isEnabled(type: OSLogType) -> Bool { !disabled && type.rank >= _OSLogOutput.minimumRank }
    public var signpostsEnabled: Bool { false }
}

// MARK: - Privacy and formatting options

public struct OSLogPrivacy: Equatable, Sendable {
    public enum Mask: Equatable, Sendable { case hash, none }
    enum Kind: Equatable { case auto, `public`, `private`, sensitive }
    let kind: Kind, mask: Mask
    public static var auto: OSLogPrivacy { OSLogPrivacy(kind: .auto, mask: .none) }
    public static var `public`: OSLogPrivacy { OSLogPrivacy(kind: .public, mask: .none) }
    public static var `private`: OSLogPrivacy { OSLogPrivacy(kind: .private, mask: .none) }
    public static var sensitive: OSLogPrivacy { OSLogPrivacy(kind: .sensitive, mask: .none) }
    public static func auto(mask: Mask) -> OSLogPrivacy { OSLogPrivacy(kind: .auto, mask: mask) }
    public static func `private`(mask: Mask) -> OSLogPrivacy { OSLogPrivacy(kind: .private, mask: mask) }
    public static func sensitive(mask: Mask) -> OSLogPrivacy { OSLogPrivacy(kind: .sensitive, mask: mask) }
}

public struct OSLogStringAlignment: Sendable {
    enum Side { case none, left, right }
    let side: Side, columns: @Sendable () -> Int
    public static var none: OSLogStringAlignment { OSLogStringAlignment(side: .none, columns: { 0 }) }
    public static func right(columns: @autoclosure @escaping @Sendable () -> Int) -> OSLogStringAlignment { OSLogStringAlignment(side: .right, columns: columns) }
    public static func left(columns: @autoclosure @escaping @Sendable () -> Int) -> OSLogStringAlignment { OSLogStringAlignment(side: .left, columns: columns) }
    func apply(_ s: String) -> String {
        let n = columns() - s.count
        guard n > 0 else { return s }
        switch side { case .none: return s; case .left: return s + String(repeating: " ", count: n); case .right: return String(repeating: " ", count: n) + s }
    }
}
public typealias OSLogIntegerAlignment = OSLogStringAlignment
public typealias OSLogFloatAlignment = OSLogStringAlignment

public struct OSLogIntegerFormatting: Sendable {
    enum Radix { case decimal, hex, octal }
    let radix: Radix, explicitPositiveSign: Bool, includePrefix: Bool, uppercase: Bool, minDigits: Int
    public static var decimal: OSLogIntegerFormatting { decimal(explicitPositiveSign: false, minDigits: 0) }
    public static func decimal(explicitPositiveSign: Bool = false, minDigits: @autoclosure @escaping () -> Int = 0) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: .decimal, explicitPositiveSign: explicitPositiveSign, includePrefix: false, uppercase: false, minDigits: minDigits())
    }
    public static var hex: OSLogIntegerFormatting { hex(explicitPositiveSign: false, includePrefix: false, uppercase: false, minDigits: 0) }
    public static func hex(explicitPositiveSign: Bool = false, includePrefix: Bool = false, uppercase: Bool = false, minDigits: @autoclosure @escaping () -> Int = 0) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: .hex, explicitPositiveSign: explicitPositiveSign, includePrefix: includePrefix, uppercase: uppercase, minDigits: minDigits())
    }
    public static var octal: OSLogIntegerFormatting { octal(explicitPositiveSign: false, includePrefix: false, uppercase: false, minDigits: 0) }
    public static func octal(explicitPositiveSign: Bool = false, includePrefix: Bool = false, uppercase: Bool = false, minDigits: @autoclosure @escaping () -> Int = 0) -> OSLogIntegerFormatting {
        OSLogIntegerFormatting(radix: .octal, explicitPositiveSign: explicitPositiveSign, includePrefix: includePrefix, uppercase: uppercase, minDigits: minDigits())
    }
    func format<T: BinaryInteger>(_ v: T) -> String {
        let radix = self.radix == .hex ? 16 : self.radix == .octal ? 8 : 10
        var digits = String(v.magnitude, radix: radix, uppercase: uppercase)
        if digits.count < minDigits { digits = String(repeating: "0", count: minDigits - digits.count) + digits }
        if includePrefix { digits = (radix == 16 ? "0x" : radix == 8 ? "0" : "") + digits }
        return (v < 0 ? "-" : explicitPositiveSign ? "+" : "") + digits
    }
}

public struct OSLogFloatFormatting: Sendable {
    enum Style { case fixed, hex, exponential, hybrid }
    let style: Style, precision: Int?, explicitPositiveSign: Bool, uppercase: Bool
    public static var fixed: OSLogFloatFormatting { OSLogFloatFormatting(style: .fixed, precision: nil, explicitPositiveSign: false, uppercase: false) }
    public static func fixed(precision: @autoclosure @escaping () -> Int, explicitPositiveSign: Bool = false, uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(style: .fixed, precision: precision(), explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }
    public static func fixed(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(style: .fixed, precision: nil, explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }
    public static var hex: OSLogFloatFormatting { OSLogFloatFormatting(style: .hex, precision: nil, explicitPositiveSign: false, uppercase: false) }
    public static var exponential: OSLogFloatFormatting { OSLogFloatFormatting(style: .exponential, precision: nil, explicitPositiveSign: false, uppercase: false) }
    public static func exponential(precision: @autoclosure @escaping () -> Int, explicitPositiveSign: Bool = false, uppercase: Bool = false) -> OSLogFloatFormatting {
        OSLogFloatFormatting(style: .exponential, precision: precision(), explicitPositiveSign: explicitPositiveSign, uppercase: uppercase)
    }
    public static var hybrid: OSLogFloatFormatting { OSLogFloatFormatting(style: .hybrid, precision: nil, explicitPositiveSign: false, uppercase: false) }
    func format(_ v: Double) -> String {
        let p = precision.map { ".\($0)" } ?? ""
        let spec: String
        switch style {
        case .fixed: spec = "%\(explicitPositiveSign ? "+" : "")\(p)\(uppercase ? "F" : "f")"
        case .hex: spec = "%\(explicitPositiveSign ? "+" : "")\(uppercase ? "A" : "a")"
        case .exponential: spec = "%\(explicitPositiveSign ? "+" : "")\(p)\(uppercase ? "E" : "e")"
        case .hybrid: spec = "%\(explicitPositiveSign ? "+" : "")\(p)\(uppercase ? "G" : "g")"
        }
        return String(format: spec, v)
    }
}

public enum OSLogBoolFormat: Sendable { case truth, answer }
public enum OSLogPointerFormat: Sendable { case none, ipv4Address, ipv6Address, sockaddr }
public enum OSLogInt32ExtendedFormat: Sendable { case ipv4Address, secondsSince1970, darwinErrno, darwinMode, darwinSignal, bitrate, bitrateIEC, byteCount, byteCountIEC, truncatedBitrate, truncatedBitrateIEC, truncatedByteCount, truncatedByteCountIEC }

// MARK: - OSLogMessage

public struct OSLogInterpolation: StringInterpolationProtocol {
    enum Piece { case literal(String), value(() -> String, OSLogPrivacy, Bool) }   // render, privacy, public by default
    var pieces: [Piece] = []
    public init(literalCapacity: Int, interpolationCount: Int) { pieces.reserveCapacity(interpolationCount * 2 + 1) }
    public mutating func appendLiteral(_ literal: String) { pieces.append(.literal(literal)) }

    public mutating func appendInterpolation(_ argumentString: @autoclosure @escaping () -> String, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ align.apply(argumentString()) }, privacy, false))
    }
    public mutating func appendInterpolation<T: CustomStringConvertible>(_ value: @autoclosure @escaping () -> T, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ align.apply(value().description) }, privacy, false))
    }
    public mutating func appendInterpolation(_ argumentObject: @autoclosure @escaping () -> NSObject, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ argumentObject().description }, privacy, false))
    }
    public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Any.Type, align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ align.apply(String(describing: value())) }, privacy, false))
    }
    public mutating func appendInterpolation(_ error: @autoclosure @escaping () -> any Error, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ String(describing: error()) }, privacy, false))
    }
    mutating func int<T: BinaryInteger>(_ n: @escaping () -> T, _ format: OSLogIntegerFormatting, _ align: OSLogStringAlignment, _ privacy: OSLogPrivacy) {
        pieces.append(.value({ align.apply(format.format(n())) }, privacy, true))
    }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Int, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Int8, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Int16, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Int32, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Int64, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> UInt, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> UInt8, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> UInt16, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> UInt32, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> UInt64, format: OSLogIntegerFormatting = .decimal, align: OSLogIntegerAlignment = .none, privacy: OSLogPrivacy = .auto) { int(number, format, align, privacy) }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Double, format: OSLogFloatFormatting = .fixed, align: OSLogFloatAlignment = .none, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ align.apply(format.format(number())) }, privacy, true))
    }
    public mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Float, format: OSLogFloatFormatting = .fixed, align: OSLogFloatAlignment = .none, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ align.apply(format.format(Double(number()))) }, privacy, true))
    }
    public mutating func appendInterpolation(_ boolean: @autoclosure @escaping () -> Bool, format: OSLogBoolFormat = .truth, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ format == .truth ? (boolean() ? "true" : "false") : (boolean() ? "YES" : "NO") }, privacy, true))
    }
    public mutating func appendInterpolation(_ pointer: @autoclosure @escaping () -> UnsafeRawPointer, format: OSLogPointerFormat = .none, privacy: OSLogPrivacy = .auto) {
        pieces.append(.value({ "0x" + String(UInt(bitPattern: pointer()), radix: 16) }, privacy, true))
    }
}

public struct OSLogMessage: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
    public typealias StringInterpolation = OSLogInterpolation
    let interpolation: OSLogInterpolation
    public init(stringInterpolation: OSLogInterpolation) { interpolation = stringInterpolation }
    public init(stringLiteral value: String) { var i = OSLogInterpolation(literalCapacity: value.count, interpolationCount: 0); i.appendLiteral(value); interpolation = i }

    func render() -> String {
        var out = ""
        for p in interpolation.pieces {
            switch p {
            case .literal(let s): out += s
            case .value(let f, let privacy, let scalar): out += _OSLogOutput.redact(f(), privacy: privacy, publicByDefault: scalar)
            }
        }
        return out
    }
}

// MARK: - Output

enum _OSLogOutput {
    static let showPrivate: Bool = { getenv("ISIM_LOG_PRIVATE").map { String(cString: $0) == "1" } ?? false }()
    static let minimumRank: Int = {
        switch getenv("ISIM_LOG_LEVEL").map({ String(cString: $0).lowercased() }) ?? "" {
        case "info": return 1
        case "default", "notice": return 2
        case "error": return 3
        case "fault": return 4
        default: return 0
        }
    }()
    static let lock = NSLock()
    static let process: String = {
        let a = CommandLine.arguments.first ?? "app"
        return String(a.split(separator: "/").last ?? Substring(a))
    }()

    static func redact(_ value: String, privacy: OSLogPrivacy, publicByDefault: Bool) -> String {
        let isPublic: Bool
        switch privacy.kind {
        case .public: isPublic = true
        case .auto: isPublic = publicByDefault
        case .private, .sensitive: isPublic = false
        }
        if isPublic || (showPrivate && privacy.kind != .sensitive) { return value }
        if privacy.mask == .hash {
            var h: UInt64 = 0xcbf29ce484222325                    // FNV-1a, shown base64 like iOS's salted hash
            for b in value.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            var bytes = [UInt8](); for i in 0..<8 { bytes.append(UInt8((h >> (8 * UInt64(i))) & 0xff)) }
            return "<mask.hash: '\(Data(bytes).base64EncodedString())'>"
        }
        return "<private>"
    }

    static func emit(_ log: OSLog, _ type: OSLogType, _ message: @autoclosure () -> String) {
        guard log.isEnabled(type: type) else { return }
        let now = Date().timeIntervalSince1970
        var t = time_t(now), tm = tm()
        localtime_r(&t, &tm)
        var buf = [CChar](repeating: 0, count: 32)
        strftime(&buf, 32, "%Y-%m-%d %H:%M:%S", &tm)
        let stamp = String(cString: buf) + String(format: ".%03d", Int((now - now.rounded(.down)) * 1000))
        let scope = log.subsystem.isEmpty && log.category.isEmpty ? "" : " [\(log.subsystem):\(log.category)]"
        let tid = String(UInt(bitPattern: Int(bitPattern: UnsafeRawPointer(pthread_self()))) & 0xffffff, radix: 16)
        let line = "\(stamp) \(type.code) \(process)[\(getpid()):\(tid)]\(scope) \(message())\n"
        lock.lock()
        var bytes = Array(line.utf8)
        bytes.withUnsafeMutableBytes { var p = $0.baseAddress!, n = $0.count; while n > 0 { let w = write(2, p, n); if w <= 0 { break }; p += w; n -= w } }
        lock.unlock()
    }
}

// MARK: - Logger

public struct Logger: @unchecked Sendable {
    public let logObject: OSLog
    public init(subsystem: String, category: String) { logObject = OSLog(subsystem: subsystem, category: category) }
    public init(_ logObj: OSLog) { logObject = logObj }
    public init() { logObject = .default }

    public func log(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .default, message.render()) }
    public func log(level: OSLogType, _ message: OSLogMessage) { _OSLogOutput.emit(logObject, level, message.render()) }
    public func trace(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .debug, message.render()) }
    public func debug(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .debug, message.render()) }
    public func info(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .info, message.render()) }
    public func notice(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .default, message.render()) }
    public func warning(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .error, message.render()) }
    public func error(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .error, message.render()) }
    public func critical(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .fault, message.render()) }
    public func fault(_ message: OSLogMessage) { _OSLogOutput.emit(logObject, .fault, message.render()) }
}

// MARK: - os_log

/// printf-style os_log (format specifiers may carry {public}/{private}/{sensitive} like on iOS)
public func os_log(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, type: OSLogType = .default, _ args: CVarArg...) {
    _OSLogOutput.emit(log, type, _formatOSLog(message.description, args))
}
public func os_log(_ type: OSLogType, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, _ message: StaticString, _ args: CVarArg...) {
    _OSLogOutput.emit(log, type, _formatOSLog(message.description, args))
}
public func os_log(_ type: OSLogType, dso: UnsafeRawPointer = #dsohandle, log: OSLog = .default, _ message: OSLogMessage) {
    _OSLogOutput.emit(log, type, message.render())
}
public func os_log(_ message: OSLogMessage, dso: UnsafeRawPointer = #dsohandle, log: OSLog = .default) {
    _OSLogOutput.emit(log, .default, message.render())
}

func _formatOSLog(_ format: String, _ args: [CVarArg]) -> String {
    var out = "", i = format.startIndex, argIndex = 0
    let conversions: Set<Character> = ["d", "i", "u", "o", "x", "X", "f", "F", "e", "E", "g", "G", "a", "A", "c", "s", "S", "p", "@", "C", "D", "U", "O"]
    while i < format.endIndex {
        let c = format[i]
        guard c == "%" else { out.append(c); i = format.index(after: i); continue }
        var j = format.index(after: i)
        if j < format.endIndex, format[j] == "%" { out += "%"; i = format.index(after: j); continue }
        var privacy = OSLogPrivacy.auto, decoration = ""
        if j < format.endIndex, format[j] == "{" {
            guard let close = format[j...].firstIndex(of: "}") else { out += String(format[i...]); break }
            let mods = format[format.index(after: j)..<close].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for m in mods {
                if m == "public" { privacy = .public } else if m == "private" { privacy = .private } else if m == "sensitive" { privacy = .sensitive }
                else { decoration = m }
            }
            j = format.index(after: close)
        }
        var spec = "%"
        while j < format.endIndex, !conversions.contains(format[j]) { spec.append(format[j]); j = format.index(after: j) }
        guard j < format.endIndex else { out += String(format[i...]); break }
        let conv = format[j]
        spec.append(conv)
        i = format.index(after: j)
        guard argIndex < args.count else { out += "<decode: missing data>"; continue }
        let arg = args[argIndex]; argIndex += 1
        var text: String
        if decoration.lowercased() == "bool" { text = (arg as? Int ?? 0) != 0 ? "true" : "false"; if decoration == "BOOL" { text = text == "true" ? "YES" : "NO" } }
        else { text = String(format: spec, arg) }
        let scalar = !(conv == "@" || conv == "s" || conv == "S")
        out += _OSLogOutput.redact(text, privacy: privacy, publicByDefault: scalar)
    }
    return out
}

// MARK: - Signposts (accepted, not recorded)

public struct OSSignpostID: Equatable, Hashable, Comparable, Sendable {
    public let rawValue: UInt64
    public init(_ value: UInt64) { rawValue = value }
    public init(log: OSLog) { rawValue = _signpostCounter.next() }
    public init(log: OSLog, object: AnyObject) { rawValue = UInt64(UInt(bitPattern: ObjectIdentifier(object).hashValue)) }
    public static let exclusive = OSSignpostID(0xEEEEB0B5B2B2EEEE)
    public static let invalid = OSSignpostID(~0)
    public static let null = OSSignpostID(0)
    public static func < (a: OSSignpostID, b: OSSignpostID) -> Bool { a.rawValue < b.rawValue }
}
final class _SignpostCounter: @unchecked Sendable {
    let lock = NSLock(); var value: UInt64 = 1
    func next() -> UInt64 { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}
let _signpostCounter = _SignpostCounter()

public struct OSSignpostType: Equatable, RawRepresentable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let event = OSSignpostType(rawValue: 0)
    public static let begin = OSSignpostType(rawValue: 1)
    public static let end = OSSignpostType(rawValue: 2)
}
public func os_signpost(_ type: OSSignpostType, dso: UnsafeRawPointer = #dsohandle, log: OSLog, name: StaticString, signpostID: OSSignpostID = .exclusive) {}
public func os_signpost(_ type: OSSignpostType, dso: UnsafeRawPointer = #dsohandle, log: OSLog, name: StaticString, signpostID: OSSignpostID = .exclusive, _ format: StaticString, _ arguments: CVarArg...) {}

public struct OSSignpostIntervalState: Sendable {
    public let signpostID: OSSignpostID
    public static func beginState(id: OSSignpostID) -> OSSignpostIntervalState { OSSignpostIntervalState(signpostID: id) }
}
public struct OSSignposter: @unchecked Sendable {
    public let logHandle: OSLog
    public init(subsystem: String, category: String) { logHandle = OSLog(subsystem: subsystem, category: category) }
    public init(subsystem: String, category: OSLog.Category) { logHandle = OSLog(subsystem: subsystem, category: category) }
    public init(logger: Logger) { logHandle = logger.logObject }
    public init(logHandle: OSLog) { self.logHandle = logHandle }
    public init() { logHandle = .default }
    public static let disabled = OSSignposter(logHandle: .disabled)
    public var isEnabled: Bool { false }
    public func makeSignpostID() -> OSSignpostID { OSSignpostID(log: logHandle) }
    public func makeSignpostID(from object: AnyObject) -> OSSignpostID { OSSignpostID(log: logHandle, object: object) }
    public func emitEvent(_ name: StaticString, id: OSSignpostID = .exclusive) {}
    public func emitEvent(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: OSLogMessage) {}
    public func beginInterval(_ name: StaticString, id: OSSignpostID = .exclusive) -> OSSignpostIntervalState { .beginState(id: id) }
    public func beginInterval(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: OSLogMessage) -> OSSignpostIntervalState { .beginState(id: id) }
    public func beginAnimationInterval(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: OSLogMessage) -> OSSignpostIntervalState { .beginState(id: id) }
    public func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState) {}
    public func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState, _ message: OSLogMessage) {}
    public func withIntervalSignpost<T>(_ name: StaticString, id: OSSignpostID = .exclusive, around task: () throws -> T) rethrows -> T { try task() }
    public func withIntervalSignpost<T>(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: OSLogMessage, around task: () throws -> T) rethrows -> T { try task() }
}

// MARK: - Locks

/// iOS 16's OSAllocatedUnfairLock (an os_unfair_lock on the heap guarding a value)
public struct OSAllocatedUnfairLock<State>: @unchecked Sendable {
    final class Storage { var lock = os_unfair_lock(); var state: State; init(_ s: State) { state = s } }
    let storage: Storage
    public init(initialState: State) { storage = Storage(initialState) }
    public init(uncheckedState initialState: State) { storage = Storage(initialState) }
    public func withLock<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
        os_unfair_lock_lock(&storage.lock); defer { os_unfair_lock_unlock(&storage.lock) }
        return try body(&storage.state)
    }
    public func withLockUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R {
        os_unfair_lock_lock(&storage.lock); defer { os_unfair_lock_unlock(&storage.lock) }
        return try body(&storage.state)
    }
    public func withLockIfAvailable<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R? {
        guard os_unfair_lock_trylock(&storage.lock) else { return nil }
        defer { os_unfair_lock_unlock(&storage.lock) }
        return try body(&storage.state)
    }
    public func lock() { os_unfair_lock_lock(&storage.lock) }
    public func unlock() { os_unfair_lock_unlock(&storage.lock) }
    public func lockIfAvailable() -> Bool { os_unfair_lock_trylock(&storage.lock) }
    public enum Ownership: Hashable, Sendable { case owner, notOwner }
    public func precondition(_ condition: Ownership) {
        if condition == .owner { os_unfair_lock_assert_owner(&storage.lock) } else { os_unfair_lock_assert_not_owner(&storage.lock) }
    }
}
extension OSAllocatedUnfairLock where State == () {
    public init() { storage = Storage(()) }
    public func withLock<R>(_ body: @Sendable () throws -> R) rethrows -> R {
        os_unfair_lock_lock(&storage.lock); defer { os_unfair_lock_unlock(&storage.lock) }
        return try body()
    }
    public func withLockUnchecked<R>(_ body: () throws -> R) rethrows -> R {
        os_unfair_lock_lock(&storage.lock); defer { os_unfair_lock_unlock(&storage.lock) }
        return try body()
    }
}
