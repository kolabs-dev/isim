// isim OSLog: re-exports isim's os module (Logger, OSLog, signposts) and reads the log back (OSLogStore), adapted:
// isim's host keeps this process's log in memory (the last 50,000 messages and signposts from Swift Logger / os_log,
// C os_log, os_signpost and NSLog, as shown: private values redacted unless ISIM_LOG_PRIVATE=1). As on iOS, an app
// reads its own process's entries: OSLogStore(scope: .currentProcessIdentifier); the system scope and local() (macOS)
// throw. getEntries(with:at:matching:) enumerates from a position (a date, an interval before the end or since boot),
// forwards or in reverse, filtered by an NSPredicate over the entries' properties (subsystem, category,
// composedMessage, date, level, process, ...).
@_exported import os
import Foundation
import isim_host

public final class OSLogStore: NSObject, @unchecked Sendable {
    public enum Scope: Int, Sendable { case system = 0, currentProcessIdentifier = 1 }
    /// macOS only (the whole system's store)
    public static func local() throws -> OSLogStore {
        throw NSError(domain: "OSLogErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "OSLogStore.local() is not available on iOS"])
    }
    let scope: Scope
    init(_ scope: Scope) { self.scope = scope }
    public convenience init(scope: Scope) throws {
        guard scope == .currentProcessIdentifier else {
            throw NSError(domain: "OSLogErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "The system log store is not available to apps (use .currentProcessIdentifier)"])
        }
        self.init(scope)
    }

    // positions
    public func position(date: Date) -> OSLogPosition { OSLogPosition(.date(date)) }
    public func position(timeIntervalSinceEnd seconds: TimeInterval) -> OSLogPosition { OSLogPosition(.date(Date().addingTimeInterval(seconds))) }
    public func position(timeIntervalSinceLatestBoot seconds: TimeInterval) -> OSLogPosition {
        OSLogPosition(.date(Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime + seconds)))
    }

    /// the entries from a position (all of them by default), oldest first or (.reverse) newest first, matching a predicate
    public func getEntries(with options: OSLogEnumerator.Options = [], at position: OSLogPosition? = nil, matching predicate: NSPredicate? = nil) throws -> AnySequence<OSLogEntry> {
        AnySequence(_entries(options, position, predicate))
    }
    @objc(entriesEnumeratorWithOptions:position:predicate:error:)
    public func entriesEnumerator(options: OSLogEnumerator.Options = [], position: OSLogPosition? = nil, predicate: NSPredicate? = nil) throws -> OSLogEnumerator {
        OSLogEnumerator(_entries(options, position, predicate))
    }
    public func entriesEnumerator() throws -> OSLogEnumerator { OSLogEnumerator(_entries([], nil, nil)) }

    func _entries(_ options: OSLogEnumerator.Options, _ position: OSLogPosition?, _ predicate: NSPredicate?) -> [OSLogEntry] {
        var first = 0
        let end = isim_log_range(&first)
        var out: [OSLogEntry] = []
        out.reserveCapacity(end - first)
        let process = ProcessInfo.processInfo.processName, pid = ProcessInfo.processInfo.processIdentifier
        let sender = (Bundle.main.executablePath as NSString?)?.lastPathComponent ?? process
        for seq in first..<end {
            var date = 0.0
            var meta: [Int32] = [0, 0, 0]
            var ids: [UInt64] = [0, 0]
            var strs: [UnsafeMutablePointer<CChar>?] = [nil, nil, nil, nil, nil]
            let ok = meta.withUnsafeMutableBufferPointer { m in ids.withUnsafeMutableBufferPointer { i in
                strs.withUnsafeMutableBufferPointer { s in isim_log_get(seq, &date, m.baseAddress!, i.baseAddress!, s.baseAddress!) } } }
            guard ok != 0 else { continue }
            let text = strs.map { p -> String in defer { free(p) }; return p.map { String(cString: $0) } ?? "" }
            let when = Date(timeIntervalSince1970: date)
            if case .date(let d)? = position?.where {
                if options.contains(.reverse) ? when > d : when < d { continue }
            }
            let e: OSLogEntry
            if meta[0] == 1 {
                e = OSLogEntrySignpost(date: when, message: text[2], format: text[3], subsystem: text[0], category: text[1],
                                       type: meta[2], id: ids[0], name: text[4], tid: ids[1], process: process, pid: pid, sender: sender)
            } else {
                e = OSLogEntryLog(date: when, message: text[2], format: text[3], subsystem: text[0], category: text[1],
                                  type: UInt8(truncatingIfNeeded: meta[1]), tid: ids[1], process: process, pid: pid, sender: sender)
            }
            if let predicate, !predicate.evaluate(with: e) { continue }
            out.append(e)
        }
        return options.contains(.reverse) ? out.reversed() : out
    }
}

public final class OSLogPosition: NSObject, @unchecked Sendable {
    enum Where { case date(Date) }
    let `where`: Where
    init(_ w: Where) { self.where = w }
}

public final class OSLogEnumerator: NSEnumerator, @unchecked Sendable {
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let reverse = Options(rawValue: 1)
    }
    var items: [OSLogEntry], index = 0
    init(_ items: [OSLogEntry]) { self.items = items }
    public override func nextObject() -> Any? {
        guard index < items.count else { return nil }
        defer { index += 1 }
        return items[index]
    }
}

// MARK: - Entries

@objc public protocol OSLogEntryFromProcess {
    var activityIdentifier: os_activity_id_t { get }
    var process: String { get }
    var processIdentifier: pid_t { get }
    var sender: String { get }
    var threadIdentifier: UInt64 { get }
}
@objc public protocol OSLogEntryWithPayload {
    var category: String { get }
    var components: [OSLogMessageComponent] { get }
    var formatString: String { get }
    var subsystem: String { get }
}
public typealias os_activity_id_t = UInt64

open class OSLogEntry: NSObject, @unchecked Sendable {
    @objc public enum StoreCategory: Int, Sendable {
        case undefined = 0, metadata, shortTerm, longTermAuto, longTerm1, longTerm3, longTerm7, longTerm14, longTerm30
    }
    @objc public let date: Date
    @objc public let composedMessage: String
    @objc public let storeCategory: StoreCategory
    init(date: Date, message: String, store: StoreCategory) { self.date = date; composedMessage = message; storeCategory = store }
    open override var description: String { composedMessage }
}

open class OSLogEntryLog: OSLogEntry, OSLogEntryFromProcess, OSLogEntryWithPayload, @unchecked Sendable {
    @objc public enum Level: Int, Sendable { case undefined = 0, debug, info, notice, error, fault }
    @objc public let level: Level
    @objc public let subsystem: String
    @objc public let category: String
    @objc public let formatString: String
    @objc public let activityIdentifier: os_activity_id_t = 0
    @objc public let process: String
    @objc public let processIdentifier: pid_t
    @objc public let sender: String
    @objc public let threadIdentifier: UInt64
    init(date: Date, message: String, format: String, subsystem: String, category: String, type: UInt8, tid: UInt64, process: String, pid: pid_t, sender: String) {
        switch type {
        case 0x01: level = .info
        case 0x02: level = .debug
        case 0x10: level = .error
        case 0x11: level = .fault
        default: level = .notice
        }
        self.subsystem = subsystem; self.category = category; formatString = format; threadIdentifier = tid
        self.process = process; processIdentifier = pid; self.sender = sender
        super.init(date: date, message: message, store: level == .debug ? .metadata : level == .info ? .shortTerm : .longTermAuto)
    }
    /// the message's pieces: each placeholder of the format with the text that stands for it in the message
    @objc public var components: [OSLogMessageComponent] { OSLogMessageComponent.split(format: formatString, message: composedMessage) }
    /// for predicates: "messageType" == "error" and the like, as on macOS's log tool
    @objc public var messageType: String { ["undefined", "debug", "info", "default", "error", "fault"][level.rawValue] }
}

open class OSLogEntrySignpost: OSLogEntry, OSLogEntryFromProcess, OSLogEntryWithPayload, @unchecked Sendable {
    @objc public enum SignpostType: Int, Sendable { case undefined = 0, intervalBegin, intervalEnd, event }
    @objc public let signpostIdentifier: UInt64
    @objc public let signpostName: String
    @objc public let signpostType: SignpostType
    @objc public let subsystem: String
    @objc public let category: String
    @objc public let formatString: String
    @objc public let activityIdentifier: os_activity_id_t = 0
    @objc public let process: String
    @objc public let processIdentifier: pid_t
    @objc public let sender: String
    @objc public let threadIdentifier: UInt64
    init(date: Date, message: String, format: String, subsystem: String, category: String, type: Int32, id: UInt64, name: String, tid: UInt64, process: String, pid: pid_t, sender: String) {
        signpostIdentifier = id; signpostName = name
        signpostType = type == 1 ? .intervalBegin : type == 2 ? .intervalEnd : .event
        self.subsystem = subsystem; self.category = category; formatString = format; threadIdentifier = tid
        self.process = process; processIdentifier = pid; self.sender = sender
        super.init(date: date, message: message, store: .longTermAuto)
    }
    @objc public var components: [OSLogMessageComponent] { OSLogMessageComponent.split(format: formatString, message: composedMessage) }
}

/// activities and boundaries are never recorded on isim (no os_activity); the classes exist for type checks
open class OSLogEntryActivity: OSLogEntry, @unchecked Sendable {
    @objc public let parentActivityIdentifier: os_activity_id_t = 0
}
open class OSLogEntryBoundary: OSLogEntry, @unchecked Sendable {}

open class OSLogMessageComponent: NSObject, @unchecked Sendable {
    @objc public enum ArgumentCategory: Int, Sendable { case undefined = 0, data, double, signed, string, unsigned }
    @objc public let formatSubstring: String
    @objc public let placeholder: String
    @objc public let argumentCategory: ArgumentCategory
    let text: String?
    init(formatSubstring: String, placeholder: String, category: ArgumentCategory, text: String?) {
        self.formatSubstring = formatSubstring; self.placeholder = placeholder; argumentCategory = category; self.text = text
    }
    @objc public var argumentStringValue: String? { argumentCategory == .undefined ? nil : text }
    @objc public var argumentDoubleValue: Double { text.flatMap(Double.init) ?? 0 }
    @objc public var argumentInt64Value: Int64 { text.flatMap { Int64($0) } ?? 0 }
    @objc public var argumentUInt64Value: UInt64 { text.flatMap { UInt64($0) } ?? 0 }
    @objc public var argumentNumberValue: NSNumber? {
        switch argumentCategory {
        case .double: return NSNumber(value: argumentDoubleValue)
        case .signed: return NSNumber(value: argumentInt64Value)
        case .unsigned: return NSNumber(value: argumentUInt64Value)
        default: return nil
        }
    }
    @objc public var argumentDataValue: Data? { argumentCategory == .data ? text.map { Data($0.utf8) } : nil }

    /// the format's literal pieces and placeholders, with each placeholder's text found in the message between the
    /// literals around it
    static func split(format: String, message: String) -> [OSLogMessageComponent] {
        var pieces: [(literal: String, placeholder: String)] = []          // literal before each placeholder
        var lit = "", i = format.startIndex
        let convs: Set<Character> = ["d", "i", "u", "o", "x", "X", "f", "F", "e", "E", "g", "G", "a", "A", "c", "s", "S", "p", "@", "C", "D", "U", "O"]
        while i < format.endIndex {
            let c = format[i]
            if c == "%" {
                let n = format.index(after: i)
                if n < format.endIndex, format[n] == "%" { lit.append("%"); i = format.index(after: n); continue }
                var j = n
                if j < format.endIndex, format[j] == "{", let close = format[j...].firstIndex(of: "}") { j = format.index(after: close) }
                while j < format.endIndex, !convs.contains(format[j]) { j = format.index(after: j) }
                if j < format.endIndex { j = format.index(after: j) }
                pieces.append((lit, String(format[i..<j]))); lit = ""; i = j
            } else { lit.append(c); i = format.index(after: i) }
        }
        var out: [OSLogMessageComponent] = []
        var rest = Substring(message)
        for (k, p) in pieces.enumerated() {
            if rest.hasPrefix(p.literal) { rest = rest.dropFirst(p.literal.count) }
            let next = k + 1 < pieces.count ? pieces[k + 1].literal : lit
            var value: Substring
            if next.isEmpty { value = k + 1 < pieces.count ? "" : rest; rest = rest.dropFirst(value.count) }
            else if let r = rest.range(of: next) { value = rest[..<r.lowerBound]; rest = rest[r.lowerBound...] }
            else { value = rest; rest = "" }
            let conv = p.placeholder.last ?? "@"
            let cat: ArgumentCategory = "dic".contains(conv) ? .signed : "uoxX".contains(conv) ? .unsigned
                : "fFeEgGaA".contains(conv) ? .double : .string
            out.append(OSLogMessageComponent(formatSubstring: p.literal, placeholder: p.placeholder, category: cat, text: String(value)))
        }
        if !lit.isEmpty { out.append(OSLogMessageComponent(formatSubstring: lit, placeholder: "", category: .undefined, text: nil)) }
        return out
    }
}
