// isim TipKit: tips, their rules and the datastore (adapted).
// Tips.configure opens the datastore: a property list in the app's container (Library/Application Support/TipKit/
// Tips.plist; datastoreLocation .groupContainer(identifier:) or .url(_:) put it elsewhere; a CloudKit container is
// accepted but nothing syncs). It keeps the parameters (@Parameter, unless .transient), the events' donations and each
// tip's state: first shown, display count, time on screen, invalidation. A tip is available when the datastore is
// configured, it is not invalidated, its rules (#Rule over parameters and events) hold, its options allow it
// (MaxDisplayCount, MaxDisplayDuration) and, for a tip not shown yet, the display frequency has passed since another tip
// first appeared (IgnoresDisplayFrequency skips that). The testing switches (showAllTipsForTesting, …) override it all.
// TipView, popoverTip and the UIKit views (Views.swift) show a tip while it is available and count its displays; closing
// it invalidates it (.tipClosed).
import Foundation
import SwiftUI
import Observation

// MARK: - the datastore

final class _TipStore: @unchecked Sendable {
    static let shared = _TipStore()
    static let changed = Notification.Name("_IsimTipKitChanged")
    let lock = NSRecursiveLock()
    var configured = false
    var file: URL?
    var frequency: TimeInterval = 0
    var frequencyName = "immediate"
    var data: [String: Any] = [:]
    var transient: [String: Data] = [:]
    var showAll = false, hideAll = false
    var showTypes: Set<String> = [], hideTypes: Set<String> = []
    var showing: [String: Date] = [:]                      /* tips on screen now, since */

    func sync<T>(_ f: () throws -> T) rethrows -> T { lock.lock(); defer { lock.unlock() }; return try f() }
    func save() {
        guard let f = file else { return }
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        (data as NSDictionary).write(toFile: f.path, atomically: true)
    }
    func changed() {
        save()
        NotificationCenter.default.post(name: _TipStore.changed, object: nil)
    }
    subscript(section: String) -> [String: Any] {
        get { data[section] as? [String: Any] ?? [:] }
        set { data[section] = newValue }
    }
    func tipState(_ id: String) -> [String: Any] { self["tips"][id] as? [String: Any] ?? [:] }
    func setTipState(_ id: String, _ s: [String: Any]) { var t = self["tips"]; t[id] = s; self["tips"] = t }

    /// the tip's status now (and an invalidation its options cause, which is kept)
    func status<T: Tip>(of tip: T) -> Tips.Status {
        sync {
            let id = tip.id, type = String(reflecting: T.self)
            var st = tipState(id)
            if let r = st["invalidated"] as? String, let reason = Tips.InvalidationReason(rawValue: r) { return .invalidated(reason) }
            if hideAll || hideTypes.contains(type) { return .pending }
            if showAll || showTypes.contains(type) { return .available }
            guard configured else { return .pending }
            var ignoresFrequency = false
            for o in tip.options {
                if let m = o as? Tips.MaxDisplayCount, (st["count"] as? Int ?? 0) >= m.count, showing[id] == nil {
                    st["invalidated"] = Tips.InvalidationReason.displayCountExceeded.rawValue; setTipState(id, st); changed()
                    NSLog("isim TipKit: %@ invalidated (displayCountExceeded)", id)
                    return .invalidated(.displayCountExceeded)
                }
                if let m = o as? Tips.MaxDisplayDuration, onScreen(id) >= m.duration {
                    st["invalidated"] = Tips.InvalidationReason.displayDurationExceeded.rawValue; setTipState(id, st); changed()
                    NSLog("isim TipKit: %@ invalidated (displayDurationExceeded)", id)
                    return .invalidated(.displayDurationExceeded)
                }
                if let i = o as? Tips.IgnoresDisplayFrequency, i.ignores { ignoresFrequency = true }
            }
            for r in tip.rules where !r.check() { return .pending }
            if st["first"] == nil, !ignoresFrequency, frequency > 0, data["lastShownID"] as? String != id,
               let last = data["lastShown"] as? Date, Date().timeIntervalSince(last) < frequency {
                return .pending                              /* another tip appeared too recently */
            }
            return .available
        }
    }
    /// a view is about to show the tip: whether it may, taking the display frequency's slot for a new tip (so two new
    /// tips checked at once do not both appear)
    func claim<T: Tip>(_ tip: T) -> Bool {
        sync {
            guard status(of: tip) == .available else { return false }
            if tipState(tip.id)["first"] == nil, frequency > 0, !tip.options.contains(where: { ($0 as? Tips.IgnoresDisplayFrequency)?.ignores == true }) {
                data["lastShown"] = Date(); data["lastShownID"] = tip.id
            }
            return true
        }
    }
    /// seconds on screen so far
    func onScreen(_ id: String) -> TimeInterval {
        (tipState(id)["duration"] as? Double ?? 0) + (showing[id].map { Date().timeIntervalSince($0) } ?? 0)
    }
    func appeared(_ id: String, ignoresFrequency: Bool) {
        sync {
            guard showing[id] == nil else { return }
            var st = tipState(id)
            if st["first"] == nil {                      /* a new tip: the display frequency counts from now */
                st["first"] = Date()
                if !ignoresFrequency { data["lastShown"] = Date(); data["lastShownID"] = id }
            }
            st["count"] = (st["count"] as? Int ?? 0) + 1
            setTipState(id, st)
            showing[id] = Date()
            NSLog("isim TipKit: %@ shown (%ld)", id, st["count"] as? Int ?? 0)
            save()
        }
    }
    func disappeared(_ id: String) {
        sync {
            guard let since = showing.removeValue(forKey: id) else { return }
            var st = tipState(id)
            st["duration"] = (st["duration"] as? Double ?? 0) + Date().timeIntervalSince(since)
            setTipState(id, st)
            save()
        }
    }
    func invalidate(_ id: String, _ reason: Tips.InvalidationReason) {
        sync {
            var st = tipState(id)
            guard st["invalidated"] == nil else { return }
            st["invalidated"] = reason.rawValue
            setTipState(id, st)
            NSLog("isim TipKit: %@ invalidated (%@)", id, reason.rawValue)
            changed()
        }
    }
}

// MARK: - Tips

public enum Tips {
    /// configures and loads the datastore (call once, at launch)
    public static func configure(_ configuration: [Tips.ConfigurationOption] = []) throws {
        let s = _TipStore.shared
        try s.sync {
            if s.configured { throw TipKitError.tipsDatastoreAlreadyConfigured }
            var location = ConfigurationOption.DatastoreLocation.applicationDefault
            for o in configuration {
                switch o.kind {
                case .location(let l): location = l
                case .frequency(let f): s.frequency = f.interval; s.frequencyName = f.name
                case .cloudKit: break
                }
            }
            s.file = location.url.appendingPathComponent("Tips.plist")
            s.data = (NSDictionary(contentsOfFile: s.file!.path) as? [String: Any]) ?? [:]
            s.configured = true
            NSLog("isim TipKit: configured (display frequency %@, %@)", s.frequencyName, s.file!.path)
        }
        NotificationCenter.default.post(name: _TipStore.changed, object: nil)
    }
    /// removes every parameter, donation and tip state (before configure)
    public static func resetDatastore() throws {
        let s = _TipStore.shared
        try s.sync {
            if s.configured { throw TipKitError.tipsDatastoreAlreadyConfigured }
            try? FileManager.default.removeItem(at: ConfigurationOption.DatastoreLocation.applicationDefault.url.appendingPathComponent("Tips.plist"))
            s.data = [:]; s.transient = [:]
            NSLog("isim TipKit: datastore reset")
        }
    }
    public static func showAllTipsForTesting() { _TipStore.shared.sync { _TipStore.shared.showAll = true; _TipStore.shared.hideAll = false }; _TipStore.shared.changed() }
    public static func hideAllTipsForTesting() { _TipStore.shared.sync { _TipStore.shared.hideAll = true; _TipStore.shared.showAll = false }; _TipStore.shared.changed() }
    public static func showTipsForTesting(_ tips: [any Tip.Type]) {
        _TipStore.shared.sync { _TipStore.shared.showTypes.formUnion(tips.map { String(reflecting: $0) }) }; _TipStore.shared.changed()
    }
    public static func hideTipsForTesting(_ tips: [any Tip.Type]) {
        _TipStore.shared.sync { _TipStore.shared.hideTypes.formUnion(tips.map { String(reflecting: $0) }) }; _TipStore.shared.changed()
    }

    public struct ConfigurationOption: Sendable {
        enum Kind: Sendable { case location(DatastoreLocation), frequency(DisplayFrequency), cloudKit(CloudKitContainer?) }
        let kind: Kind
        public static func datastoreLocation(_ location: DatastoreLocation) -> ConfigurationOption { ConfigurationOption(kind: .location(location)) }
        public static func displayFrequency(_ frequency: DisplayFrequency) -> ConfigurationOption { ConfigurationOption(kind: .frequency(frequency)) }
        /// accepted; isim syncs nothing to CloudKit
        public static func cloudKitContainer(_ container: CloudKitContainer?) -> ConfigurationOption { ConfigurationOption(kind: .cloudKit(container)) }

        public struct DatastoreLocation: Sendable {
            let url: URL
            public static var applicationDefault: DatastoreLocation {
                DatastoreLocation(url: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/TipKit"))
            }
            public static func url(_ url: URL) -> DatastoreLocation { DatastoreLocation(url: url) }
            /// the app group's container (the app needs the group in its entitlements)
            public static func groupContainer(identifier: String) throws -> DatastoreLocation {
                guard let c = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
                    throw TipKitError.missingGroupContainerEntitlements
                }
                return DatastoreLocation(url: c.appendingPathComponent("Library/Application Support/TipKit"))
            }
        }
        public struct DisplayFrequency: Sendable {
            let interval: TimeInterval, name: String
            public static var immediate: DisplayFrequency { DisplayFrequency(interval: 0, name: "immediate") }
            public static var hourly: DisplayFrequency { DisplayFrequency(interval: 3600, name: "hourly") }
            public static var daily: DisplayFrequency { DisplayFrequency(interval: 86_400, name: "daily") }
            public static var weekly: DisplayFrequency { DisplayFrequency(interval: 604_800, name: "weekly") }
            public static var monthly: DisplayFrequency { DisplayFrequency(interval: 2_592_000, name: "monthly") }
        }
        public struct CloudKitContainer: Sendable {
            let name: String?
            public static var automatic: CloudKitContainer { CloudKitContainer(name: nil) }
            public static func named(_ name: String) -> CloudKitContainer { CloudKitContainer(name: name) }
        }
    }

    public enum Status: Sendable, Equatable {
        case pending
        case available
        case invalidated(Tips.InvalidationReason)
    }
    public enum InvalidationReason: String, Sendable, Equatable {
        case actionPerformed, displayCountExceeded, displayDurationExceeded, tipClosed
    }

    /// a button in a tip (below its message)
    public struct Action: Identifiable, Sendable {
        public let id: String
        public let index: Int?
        nonisolated(unsafe) public let label: () -> Text
        nonisolated(unsafe) public let handler: () -> Void
        init(id: String, index: Int?, label: @escaping () -> Text, handler: @escaping () -> Void) { self.id = id; self.index = index; self.label = label; self.handler = handler }
        public init(id: String? = nil, perform handler: @escaping @Sendable () -> Void = {}, _ label: @escaping @Sendable () -> Text) {
            self.init(id: id ?? "", index: nil, label: label, handler: handler)
        }
        public init(id: String? = nil, title: some StringProtocol, perform handler: @escaping @Sendable () -> Void = {}) {
            let t = String(title)
            self.init(id: id ?? t, index: nil, label: { Text(t) }, handler: handler)
        }
        func at(_ i: Int) -> Action { Action(id: id.isEmpty ? String(i) : id, index: i, label: label, handler: handler) }
    }

    // MARK: options

    public struct IgnoresDisplayFrequency: TipOption { let ignores: Bool; public init(_ ignoresDisplayFrequency: Bool) { ignores = ignoresDisplayFrequency } }
    public struct MaxDisplayCount: TipOption { let count: Int; public init(_ maxDisplayCount: Int) { count = maxDisplayCount } }
    public struct MaxDisplayDuration: TipOption { let duration: TimeInterval; public init(_ maxDisplayDuration: TimeInterval) { duration = maxDisplayDuration } }

    // MARK: parameters

    public struct ParameterOption: Sendable, Equatable {
        let raw: Int
        /// kept in memory only: back to the default at each launch
        public static var transient: ParameterOption { ParameterOption(raw: 1) }
    }
    /// a value the tip's rules read (@Parameter static var isLoggedIn = false makes its `$isLoggedIn`)
    public struct Parameter<Value: Codable & Sendable>: Sendable {
        let key: String
        let defaultValue: Value
        let transient: Bool
        public init(_ tip: Any.Type, _ name: String, _ defaultValue: Value, _ options: [ParameterOption] = []) {
            key = String(reflecting: tip) + "." + name
            self.defaultValue = defaultValue
            transient = options.contains(.transient)
        }
        public var wrappedValue: Value {
            get {
                let s = _TipStore.shared
                let d: Data? = s.sync { transient ? s.transient[key] : s["parameters"][key] as? Data }
                return d.flatMap { try? JSONDecoder().decode([Value].self, from: $0).first } ?? defaultValue
            }
            nonmutating set {
                let s = _TipStore.shared
                guard let d = try? JSONEncoder().encode([newValue]) else { return }
                s.sync { if transient { s.transient[key] = d } else { var p = s["parameters"]; p[key] = d; s["parameters"] = p } }
                NSLog("isim TipKit: parameter %@ = %@", key, "\(newValue)")
                s.changed()
            }
        }
    }

    // MARK: events

    public struct EmptyDonation: Codable, Sendable, Hashable { public init() {} }
    public struct DonationTimeRange: Sendable, Equatable {
        let seconds: TimeInterval
        public static var minute: DonationTimeRange { .minutes(1) }
        public static var hour: DonationTimeRange { .hours(1) }
        public static var day: DonationTimeRange { .days(1) }
        public static var week: DonationTimeRange { .weeks(1) }
        public static func minutes(_ n: Int) -> DonationTimeRange { DonationTimeRange(seconds: Double(n) * 60) }
        public static func hours(_ n: Int) -> DonationTimeRange { DonationTimeRange(seconds: Double(n) * 3600) }
        public static func days(_ n: Int) -> DonationTimeRange { DonationTimeRange(seconds: Double(n) * 86_400) }
        public static func weeks(_ n: Int) -> DonationTimeRange { DonationTimeRange(seconds: Double(n) * 604_800) }
    }
    public struct DonationLimit: Sendable {
        public let maximumCount: Int
        public let maximumAge: DonationTimeRange?
        public init(maximumCount: Int, maximumAge: DonationTimeRange?) { self.maximumCount = maximumCount; self.maximumAge = maximumAge }
        static var standard: DonationLimit { DonationLimit(maximumCount: 1000, maximumAge: nil) }
    }
    /// something the user does that rules count (`#Rule(Self.didOpen) { $0.donations.count >= 3 }`)
    public struct Event<DonationInfo: Codable & Sendable>: Sendable {
        public let id: String
        let limit: DonationLimit
        public init(id: String, donationLimit: DonationLimit) { self.id = id; limit = donationLimit }
        @dynamicMemberLookup
        public struct Donation: Sendable, _IsimTipDonation {
            public let date: Date
            let info: DonationInfo
            public subscript<Value>(dynamicMember keyPath: KeyPath<DonationInfo, Value>) -> Value { info[keyPath: keyPath] }
        }
        /// the donations kept (the newest last)
        public var donations: [Donation] {
            let s = _TipStore.shared
            let list = s.sync { s["events"][id] as? [[String: Any]] ?? [] }
            return list.compactMap { e in
                guard let date = e["date"] as? Date, let d = e["info"] as? Data, let info = try? JSONDecoder().decode([DonationInfo].self, from: d).first else { return nil }
                return Donation(date: date, info: info)
            }
        }
        func record(_ info: DonationInfo) {
            let s = _TipStore.shared
            guard let d = try? JSONEncoder().encode([info]) else { return }
            let n: Int = s.sync {
                var list = s["events"][id] as? [[String: Any]] ?? []
                list.append(["date": Date(), "info": d])
                if let age = limit.maximumAge { list = list.filter { Date().timeIntervalSince($0["date"] as? Date ?? Date()) <= age.seconds } }
                if list.count > limit.maximumCount { list.removeFirst(list.count - limit.maximumCount) }
                var ev = s["events"]; ev[id] = list; s["events"] = ev
                return list.count
            }
            NSLog("isim TipKit: event %@ donated (%ld)", id, n)
            s.changed()
        }
        public func donate(_ donation: DonationInfo) async { record(donation) }
        @available(iOS 18.0, *)
        public func sendDonation(_ donation: DonationInfo, _ completion: (@Sendable () -> Void)? = nil) {
            record(donation); completion?()
        }
        public func deleteDonations() async throws {
            let s = _TipStore.shared
            s.sync { var ev = s["events"]; ev[id] = nil; s["events"] = ev }
            s.changed()
        }
    }

    // MARK: rules

    /// a condition for showing a tip (#Rule)
    public struct Rule: @unchecked Sendable {
        let check: () -> Bool
        public init<Value>(_isimInput parameter: Parameter<Value>, _ predicate: @escaping (Value) -> Bool) { check = { predicate(parameter.wrappedValue) } }
        public init<D>(_isimInput event: Event<D>, _ predicate: @escaping (Event<D>) -> Bool) { check = { predicate(event) } }
        public enum CompoundOperation: Sendable { case conjunction, disjunction }
    }
    @resultBuilder public struct RuleBuilder {
        public static func buildExpression(_ r: Rule) -> [Rule] { [r] }
        public static func buildExpression(_ r: [Rule]) -> [Rule] { r }
        public static func buildBlock(_ parts: [Rule]...) -> [Rule] { parts.flatMap { $0 } }
        public static func buildOptional(_ r: [Rule]?) -> [Rule] { r ?? [] }
        public static func buildEither(first r: [Rule]) -> [Rule] { r }
        public static func buildEither(second r: [Rule]) -> [Rule] { r }
        public static func buildArray(_ r: [[Rule]]) -> [Rule] { r.flatMap { $0 } }
    }
    @resultBuilder public struct OptionsBuilder {
        public static func buildExpression(_ o: any TipOption) -> [any TipOption] { [o] }
        public static func buildExpression(_ o: [any TipOption]) -> [any TipOption] { o }
        public static func buildBlock(_ parts: [any TipOption]...) -> [any TipOption] { parts.flatMap { $0 } }
        public static func buildOptional(_ o: [any TipOption]?) -> [any TipOption] { o ?? [] }
        public static func buildEither(first o: [any TipOption]) -> [any TipOption] { o }
        public static func buildEither(second o: [any TipOption]) -> [any TipOption] { o }
    }
    @resultBuilder public struct ActionBuilder {
        public static func buildExpression(_ a: Action) -> [Action] { [a] }
        public static func buildExpression(_ a: [Action]) -> [Action] { a }
        public static func buildBlock(_ parts: [Action]...) -> [Action] { parts.flatMap { $0 } }
        public static func buildOptional(_ a: [Action]?) -> [Action] { a ?? [] }
        public static func buildEither(first a: [Action]) -> [Action] { a }
        public static func buildEither(second a: [Action]) -> [Action] { a }
    }
}
extension Tips.Event where DonationInfo == Tips.EmptyDonation {
    public init(id: String) { self.init(id: id, donationLimit: .standard) }
    public func donate() async { record(Tips.EmptyDonation()) }
    @available(iOS 18.0, *)
    public func sendDonation(_ completion: (@Sendable () -> Void)? = nil) { record(Tips.EmptyDonation()); completion?() }
}
extension Tips.Event {
    public init(id: String) { self.init(id: id, donationLimit: .standard) }
}
public protocol _IsimTipDonation { var date: Date { get } }
extension Array where Element: _IsimTipDonation {
    /// the donations made within the range before now
    public func donatedWithin(_ range: Tips.DonationTimeRange) -> [Element] {
        let since = Date().addingTimeInterval(-range.seconds)
        return filter { $0.date >= since }
    }
}

/// #Rule(Self.$parameter) { $0 == true }: a rule over a parameter's value
@freestanding(expression)
public macro Rule<Value>(_ input: Tips.Parameter<Value>, _ predicate: @escaping (Value) -> Bool) -> Tips.Rule = #externalMacro(module: "TipKitMacros", type: "RuleMacro")
/// #Rule(Self.event) { $0.donations.count >= 3 }: a rule over an event's donations
@freestanding(expression)
public macro Rule<D>(_ input: Tips.Event<D>, _ predicate: @escaping (Tips.Event<D>) -> Bool) -> Tips.Rule = #externalMacro(module: "TipKitMacros", type: "RuleMacro")
/// @Parameter static var isLoggedIn: Bool = false: a value rules read, kept in the datastore
@attached(accessor) @attached(peer, names: prefixed(`$`))
public macro Parameter(_ options: Tips.ParameterOption...) = #externalMacro(module: "TipKitMacros", type: "ParameterMacro")

public struct TipKitError: Error, CustomStringConvertible, Sendable, Equatable {
    public let description: String
    public static let tipsDatastoreAlreadyConfigured = TipKitError(description: "The tips datastore was already configured.")
    public static let missingGroupContainerEntitlements = TipKitError(description: "The app is missing the app group container entitlement.")
    public static let invalidPredicateValueType = TipKitError(description: "The rule's value type is not supported.")
}

/// an option of a tip (MaxDisplayCount, MaxDisplayDuration, IgnoresDisplayFrequency)
public protocol TipOption: Sendable {}

// MARK: - Tip

public protocol Tip: Identifiable, Sendable {
    var id: String { get }
    var title: Text { get }
    var message: Text? { get }
    var image: Image? { get }
    @Tips.RuleBuilder var rules: [Self.Rule] { get }
    @Tips.OptionsBuilder var options: [any TipOption] { get }
    @Tips.ActionBuilder var actions: [Self.Action] { get }
}
extension Tip {
    public typealias Rule = Tips.Rule
    public typealias Event = Tips.Event
    public typealias Action = Tips.Action
    public typealias Option = TipOption
    public typealias Status = Tips.Status
    public typealias InvalidationReason = Tips.InvalidationReason
    public typealias IgnoresDisplayFrequency = Tips.IgnoresDisplayFrequency
    public typealias MaxDisplayCount = Tips.MaxDisplayCount
    public typealias MaxDisplayDuration = Tips.MaxDisplayDuration

    public var id: String { String(describing: Self.self) }
    public var message: Text? { nil }
    public var image: Image? { nil }
    public var rules: [Rule] { [] }
    public var options: [any TipOption] { [] }
    public var actions: [Action] { [] }

    public var status: Status { _TipStore.shared.status(of: self) }
    public var shouldDisplay: Bool { status == .available }
    /// the status now, then each time it changes
    public var statusUpdates: AsyncStream<Status> {
        let tip = self
        return AsyncStream { cont in
            var last = tip.status
            cont.yield(last)
            let o = NotificationCenter.default.addObserver(forName: _TipStore.changed, object: nil, queue: nil) { _ in
                let now = tip.status
                if now != last { last = now; cont.yield(now) }
            }
            nonisolated(unsafe) let token = o
            cont.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }
    public var shouldDisplayUpdates: AsyncMapSequence<AsyncStream<Status>, Bool> { statusUpdates.map { $0 == .available } }
    public func invalidate(reason: InvalidationReason) { _TipStore.shared.invalidate(id, reason) }
    /// makes an invalidated tip eligible again (its display count and time start over)
    public func resetEligibility() async {
        let s = _TipStore.shared
        s.sync { s.setTipState(id, [:]) }
        NSLog("isim TipKit: %@ eligible again", id)
        s.changed()
    }
}

/// a type-erased tip
public struct AnyTip: Tip {
    let base: any Tip
    public init(_ tip: any Tip) { base = (tip as? AnyTip)?.base ?? tip }
    public var id: String { base.id }
    public var title: Text { base.title }
    public var message: Text? { base.message }
    public var image: Image? { base.image }
    public var rules: [Rule] { base.rules }
    public var options: [any TipOption] { base.options }
    public var actions: [Action] { base.actions }
    public var status: Tips.Status { _tipStatus(base) }
}
func _tipStatus(_ t: any Tip) -> Tips.Status { _openStatus(t) }
func _tipClaim(_ t: any Tip) -> Bool { _openClaim(t) }
private func _openClaim<T: Tip>(_ t: T) -> Bool { (t as? AnyTip).map { _tipClaim($0.base) } ?? _TipStore.shared.claim(t) }
private func _openStatus<T: Tip>(_ t: T) -> Tips.Status { (t as? AnyTip).map { _tipStatus($0.base) } ?? _TipStore.shared.status(of: t) }

/// tips shown one at a time (iOS 18)
@available(iOS 18.0, *)
@Observable
public final class TipGroup: @unchecked Sendable {
    public enum Priority: Sendable { case firstAvailable, ordered }
    @ObservationIgnored let priority: Priority
    @ObservationIgnored let tips: [any Tip]
    var tick = 0
    @ObservationIgnored var observer: NSObjectProtocol?
    public init(_ priority: Priority = .firstAvailable, @TipGroup.Builder _ tips: () -> [any Tip]) {
        self.priority = priority; self.tips = tips()
        observer = NotificationCenter.default.addObserver(forName: _TipStore.changed, object: nil, queue: .main) { [weak self] _ in self?.tick += 1 }
    }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    /// the tip to show now: the first available one, or (ordered) the first not invalidated, when it is available
    public var currentTip: (any Tip)? {
        _ = tick
        for t in tips {
            let s = _tipStatus(t)
            if case .invalidated = s { continue }
            if s == .available { return t }
            if priority == .ordered { return nil }
        }
        return nil
    }
    public var currentTipUpdates: some AsyncSequence<any Tip, Never> {
        let group = self
        return AsyncStream<any Tip> { cont in
            var lastID = group.currentTip?.id
            if let t = group.currentTip { cont.yield(t) }
            let o = NotificationCenter.default.addObserver(forName: _TipStore.changed, object: nil, queue: nil) { _ in
                let t = group.currentTip
                if t?.id != lastID { lastID = t?.id; if let t { cont.yield(t) } }
            }
            nonisolated(unsafe) let token = o
            cont.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }
    @resultBuilder public struct Builder {
        public static func buildExpression(_ t: any Tip) -> [any Tip] { [t] }
        public static func buildBlock(_ parts: [any Tip]...) -> [any Tip] { parts.flatMap { $0 } }
    }
}
