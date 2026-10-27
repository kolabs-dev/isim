// isim StateReporting (iOS 27, adapted): an app reports which state each of its domains is in (a screen, a mode, a
// workload) with a StateReporter; MetricKit's MetricManager attributes its measurements to those states (the
// MetricReport's state entries) for the domains it enables. isim keeps the transitions in the process: the reporter
// hands each one to MetricKit and logs it ("isim state: <domain> -> <state>").
// Self-authored, iOS API names. @ReportableMetadata (isim's StateReportingMacros plugin) gives a struct its
// metadataDictionary from its stored properties.
import Foundation
import os

@available(iOS 27.0, *)
/// A metadata value a state carries: a date, a floating-point number, an integer or a string.
public enum ReportableMetadataValue: Hashable, Sendable {
    case date(Date)
    case floatingPoint(Double)
    case integer(Int128)
    case string(String)

    public init(_ value: Int) { self = .integer(Int128(value)) }
    public init(_ value: Int8) { self = .integer(Int128(value)) }
    public init(_ value: Int16) { self = .integer(Int128(value)) }
    public init(_ value: Int32) { self = .integer(Int128(value)) }
    public init(_ value: Int64) { self = .integer(Int128(value)) }
    public init(_ value: UInt) { self = .integer(Int128(value)) }
    public init(_ value: UInt8) { self = .integer(Int128(value)) }
    public init(_ value: UInt16) { self = .integer(Int128(value)) }
    public init(_ value: UInt32) { self = .integer(Int128(value)) }
    public init(_ value: UInt64) { self = .integer(Int128(value)) }
    /// true is 1, false 0
    public init(_ value: Bool) { self = .integer(value ? 1 : 0) }
    public init(_ value: Double) { self = .floatingPoint(value) }
    public init(_ value: Float) { self = .floatingPoint(Double(value)) }
    // init(_: CGFloat) is init(_: Double): CGFloat is Double on isim
    public init(_ value: Date) { self = .date(value) }
    public init(_ value: String) { self = .string(value) }
}

@available(iOS 27.0, *)
/// Metadata a state reports: its values by key. @ReportableMetadata writes metadataDictionary from a struct's stored
/// properties.
public protocol ReportableMetadata: Sendable {
    var metadataDictionary: [String: ReportableMetadataValue] { get }
}

@available(iOS 27.0, *)
/// Makes a struct ReportableMetadata: metadataDictionary holds its stored properties (by name, or the key given with
/// @ReportableMetadataKey; @ReportableMetadataIgnored leaves one out; a nil optional is left out).
@attached(member, names: named(metadataDictionary))
@attached(extension, conformances: ReportableMetadata)
public macro ReportableMetadata() = #externalMacro(module: "StateReportingMacros", type: "ReportableMetadataMacro")
/// The key a property's value has in metadataDictionary (its name by default).
@available(iOS 27.0, *)
@attached(peer)
public macro ReportableMetadataKey(_ key: String) = #externalMacro(module: "StateReportingMacros", type: "ReportableMetadataMarkerMacro")
/// Leaves a property out of metadataDictionary.
@available(iOS 27.0, *)
@attached(peer)
public macro ReportableMetadataIgnored() = #externalMacro(module: "StateReportingMacros", type: "ReportableMetadataMarkerMacro")

@available(iOS 27.0, *)
/// Reports the states of one domain: each transition starts a new state (nil: none) with its stable metadata;
/// volatile metadata can change while the state lasts.
public final class StateReporter<StableMetadata: ReportableMetadata, VolatileMetadata: ReportableMetadata>: @unchecked Sendable {
    public let domain: String
    private let lock = NSLock()
    private var state: String?
    private var stable: StableMetadata?
    private var volatile: VolatileMetadata?

    init(domain: String) { self.domain = domain }

    /// The reporter for a domain (reverse-DNS, like "com.example.app.screen").
    public static func reporter(for domain: String, stableMetadata: StableMetadata.Type, volatileMetadata: VolatileMetadata.Type)
        -> StateReporter<StableMetadata, VolatileMetadata> {
        StateReporter(domain: domain)
    }

    public func reportTransition(to state: String?, stableMetadata: StableMetadata?, volatileMetadata: VolatileMetadata?) {
        lock.lock(); self.state = state; stable = stableMetadata; volatile = volatileMetadata; lock.unlock()
        _ISIMStateLog.post(_ISIMStateTransition(domain: domain, state: state, stableMetadata: stableMetadata?.metadataDictionary ?? [:],
                                                volatileMetadata: volatileMetadata?.metadataDictionary ?? [:], date: Date()))
    }

    public func reportVolatileMetadataUpdate(_ volatileMetadata: VolatileMetadata?) {
        lock.lock(); volatile = volatileMetadata; let s = state; let st = stable; lock.unlock()
        _ISIMStateLog.post(_ISIMStateTransition(domain: domain, state: s, stableMetadata: st?.metadataDictionary ?? [:],
                                                volatileMetadata: volatileMetadata?.metadataDictionary ?? [:], date: Date(), isUpdate: true))
    }
}

// MARK: - isim: the transitions MetricKit reads

@available(iOS 27.0, *)
/// A state transition (or a volatile metadata update) as MetricKit receives it.
public struct _ISIMStateTransition: Sendable {
    public let domain: String
    public let state: String?
    public let stableMetadata: [String: ReportableMetadataValue]
    public let volatileMetadata: [String: ReportableMetadataValue]
    public let date: Date
    public var isUpdate = false
}

@available(iOS 27.0, *)
public enum _ISIMStateLog {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var observers: [@Sendable (_ISIMStateTransition) -> Void] = []
    private static let log = OSLog(subsystem: "com.apple.statereporting", category: "transitions")

    /// MetricKit's hook: called for every transition from now on, on the reporting thread
    public static func observe(_ body: @escaping @Sendable (_ISIMStateTransition) -> Void) {
        lock.lock(); observers.append(body); lock.unlock()
    }
    static func post(_ t: _ISIMStateTransition) {
        if !t.isUpdate {
            print("isim state: \(t.domain) -> \(t.state ?? "none")")
            os_log("%{public}@ -> %{public}@", log: log, type: .info, t.domain, t.state ?? "none")
        }
        lock.lock(); let obs = observers; lock.unlock()
        for o in obs { o(t) }
    }
}
