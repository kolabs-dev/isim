// isim DeviceActivity (adapted): schedules of device activity and the monitor extension.
//
// DeviceActivityCenter.startMonitoring keeps the app's activities in <isim data>/Library/isim/ScreenTime/Monitoring/
// <bundle id>.json. The home screen (system/SpringBoard/SBScreenTime.m) follows them on Screen Time's clock and runs the
// app's Device Activity Monitor extension (com.apple.deviceactivity.monitor-extension, its principal class a
// DeviceActivityMonitor subclass) as a helper process: at an interval's start and end, at the schedule's warning time
// before them, and when the usage an event counts reaches its threshold (or its warning). isim does not measure how
// long apps are used: `isim screentime usage APP MINUTES` records usage, and `isim screentime clock +MINUTES` moves
// Screen Time's clock (to reach an interval's end without waiting).
import Foundation
@_exported import ManagedSettings

public struct DeviceActivityName: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct DeviceActivitySchedule: Codable, Hashable, Sendable {
    public let intervalStart: DateComponents
    public let intervalEnd: DateComponents
    public let repeats: Bool
    public let warningTime: DateComponents?
    public init(intervalStart: DateComponents, intervalEnd: DateComponents, repeats: Bool, warningTime: DateComponents? = nil) {
        self.intervalStart = intervalStart; self.intervalEnd = intervalEnd; self.repeats = repeats; self.warningTime = warningTime
    }
    /// the interval in progress, else the next one (on Screen Time's clock)
    public var nextInterval: DateInterval? { _interval(at: _IsimScreenTime.now) }

    func _interval(at now: Date) -> DateInterval? {
        // daily intervals (the hour, minute and second of the components; a weekday or day is not followed): the one
        // in progress, else the next
        let cal = Calendar.current
        func at(_ c: DateComponents, _ day: Date) -> Date? {
            var d = cal.dateComponents([.year, .month, .day], from: day)
            d.hour = c.hour ?? 0; d.minute = c.minute ?? 0; d.second = c.second ?? 0
            return cal.date(from: d)
        }
        for offset in [-1, 0, 1, 2] {
            guard let day = cal.date(byAdding: .day, value: offset, to: now), let start = at(intervalStart, day), var end = at(intervalEnd, day) else { continue }
            if end <= start { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
            if end > now { return DateInterval(start: start, end: end) }
        }
        return nil
    }
}

public struct DeviceActivityEvent: Codable, Hashable, Sendable {
    public struct Name: RawRepresentable, Hashable, Codable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
    }
    public let applications: Set<ApplicationToken>
    public let categories: Set<ActivityCategoryToken>
    public let webDomains: Set<WebDomainToken>
    public let threshold: DateComponents
    @available(iOS 17.4, *)
    public var includesPastActivity: Bool { _includesPastActivity }
    let _includesPastActivity: Bool
    /// whether the event counts all activity (no apps, categories or web domains named)
    public var includesAllActivity: Bool { applications.isEmpty && categories.isEmpty && webDomains.isEmpty }
    public init(applications: Set<ApplicationToken> = [], categories: Set<ActivityCategoryToken> = [], webDomains: Set<WebDomainToken> = [],
                threshold: DateComponents) {
        self.applications = applications; self.categories = categories; self.webDomains = webDomains; self.threshold = threshold
        _includesPastActivity = false
    }
    @available(iOS 17.4, *)
    public init(applications: Set<ApplicationToken> = [], categories: Set<ActivityCategoryToken> = [], webDomains: Set<WebDomainToken> = [],
                threshold: DateComponents, includesPastActivity: Bool) {
        self.applications = applications; self.categories = categories; self.webDomains = webDomains; self.threshold = threshold
        _includesPastActivity = includesPastActivity
    }
    enum CodingKeys: String, CodingKey { case applications, categories, webDomains, threshold, _includesPastActivity = "includesPastActivity" }
}

public struct DeviceActivityCenter {
    public enum MonitoringError: Error, LocalizedError, Sendable {
        case excessiveActivities, intervalTooLong, intervalTooShort, invalidDateComponents, unauthorized
        public var errorDescription: String? {
            switch self {
            case .excessiveActivities: return "The app is monitoring too many activities."
            case .intervalTooLong: return "The schedule's interval is longer than a week."
            case .intervalTooShort: return "The schedule's interval is shorter than 15 minutes."
            case .invalidDateComponents: return "The schedule's date components do not name a time."
            case .unauthorized: return "The app is not authorized to use Screen Time."
            }
        }
        public var recoverySuggestion: String? {
            switch self {
            case .excessiveActivities: return "Stop monitoring an activity before starting another (20 at most)."
            case .intervalTooLong, .intervalTooShort: return "Use an interval of at least 15 minutes and at most a week."
            case .invalidDateComponents: return "Give the interval's start and end an hour, minute or weekday."
            case .unauthorized: return "Ask for authorization with AuthorizationCenter first."
            }
        }
    }
    struct _Activity: Codable { var schedule: DeviceActivitySchedule; var events: [String: DeviceActivityEvent]; var started: Double }
    static var _file: String { "Monitoring/\(_IsimScreenTime.appBundle).json" }
    static func _load() -> [String: _Activity] { _IsimScreenTime.readJSON([String: _Activity].self, _file) ?? [:] }
    static func _save(_ a: [String: _Activity]) { _IsimScreenTime.writeJSON(a, _file) }

    public init() {}
    /// the activities the app monitors
    public var activities: [DeviceActivityName] { Self._load().keys.sorted().map { DeviceActivityName($0) } }
    public func schedule(for activity: DeviceActivityName) -> DeviceActivitySchedule? { Self._load()[activity.rawValue]?.schedule }
    public func events(for activity: DeviceActivityName) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        Dictionary(uniqueKeysWithValues: (Self._load()[activity.rawValue]?.events ?? [:]).map { (DeviceActivityEvent.Name($0.key), $0.value) })
    }

    /// starts (or replaces) monitoring an activity: the monitor extension hears of its intervals and events
    public func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule,
                                events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]) throws {
        guard ["approved", "approvedWithDataAccess"].contains(_IsimScreenTime.authorization(_IsimScreenTime.appBundle) ?? "") else { throw MonitoringError.unauthorized }
        let named: (DateComponents) -> Bool = { $0.hour != nil || $0.minute != nil || $0.second != nil || $0.weekday != nil || $0.day != nil }
        guard named(schedule.intervalStart), named(schedule.intervalEnd), let i = schedule._interval(at: _IsimScreenTime.now) else {
            throw MonitoringError.invalidDateComponents
        }
        if i.duration < 15 * 60 { throw MonitoringError.intervalTooShort }
        if i.duration > 7 * 24 * 3600 { throw MonitoringError.intervalTooLong }
        var all = Self._load()
        if all[activity.rawValue] == nil && all.count >= 20 { throw MonitoringError.excessiveActivities }
        all[activity.rawValue] = _Activity(schedule: schedule, events: Dictionary(uniqueKeysWithValues: events.map { ($0.key.rawValue, $0.value) }),
                                           started: _IsimScreenTime.now.timeIntervalSince1970)
        Self._save(all)
        NSLog("isim DeviceActivity: monitoring %@ (%@ to %@, %ld event(s))", activity.rawValue, "\(i.start)", "\(i.end)", events.count)
    }
    /// stops monitoring the activities (all of them when none is named)
    public func stopMonitoring(_ activities: [DeviceActivityName] = []) {
        var all = Self._load()
        if activities.isEmpty { all = [:] } else { for a in activities { all[a.rawValue] = nil } }
        Self._save(all)
        NSLog("isim DeviceActivity: stopped monitoring %@", activities.isEmpty ? "every activity" : activities.map(\.rawValue).joined(separator: ", "))
    }
}

/// the principal class of a Device Activity Monitor extension: subclass it and override the callbacks
@objc(DeviceActivityMonitor)
open class DeviceActivityMonitor: NSObject {
    public override init() { super.init() }
    open func intervalDidStart(for activity: DeviceActivityName) {}
    open func intervalDidEnd(for activity: DeviceActivityName) {}
    open func intervalWillStartWarning(for activity: DeviceActivityName) {}
    open func intervalWillEndWarning(for activity: DeviceActivityName) {}
    open func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {}
    open func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {}
}

// MARK: - authorization of the Screen Time API (iOS 17)

@available(iOS 17.0, *)
@objc(DeviceActivityAuthorizing)
public protocol DeviceActivityAuthorizing {
    @objc static var isAuthorized: Bool { get }
    @objc static func isAuthorized(_ bundleIdentifier: String) -> Bool
}

@available(iOS 17.0, *)
@objc(DeviceActivityAuthorization)
open class DeviceActivityAuthorization: NSObject, DeviceActivityAuthorizing {
    public override init() { super.init() }
    /// whether this app is authorized
    @objc public static var isAuthorized: Bool { isAuthorized(_IsimScreenTime.appBundle) }
    @objc public static func isAuthorized(_ bundleIdentifier: String) -> Bool {
        ["approved", "approvedWithDataAccess"].contains(_IsimScreenTime.authorization(bundleIdentifier) ?? "")
    }
    /// the apps Screen Time authorized
    @objc public static var authorizedClientIdentifiers: [String] {
        (_IsimScreenTime.readJSON([String: String].self, "authorization.json") ?? [:]).filter { $0.value.hasPrefix("approved") }.keys.sorted()
    }
    /// whether a parent's settings override the apps' (isim's account has no parent)
    @objc public static var isOverridden: Bool { get { _overridden } set { _overridden = newValue } }
    nonisolated(unsafe) static var _overridden = false
    /// whether Screen Time shares across devices (isim has one device)
    @objc public static var sharingEnabled: Bool { false }
}

// MARK: - the monitor extension's process

/// a Device Activity Monitor extension's process (UIKit's NSExtensionMain for com.apple.deviceactivity.monitor-extension)
@_cdecl("isim_da_extension_main")
public func _isimDAExtensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    _IsimScreenTime.serve { reply in
        guard let req = _IsimScreenTime.extensionRequest, let m = _IsimScreenTime.principal(DeviceActivityMonitor.self) else { reply([:]); return }
        let activity = DeviceActivityName(req["activity"] as? String ?? "")
        let event = DeviceActivityEvent.Name(req["event"] as? String ?? "")
        switch req["callback"] as? String {
        case "intervalDidStart": m.intervalDidStart(for: activity)
        case "intervalDidEnd": m.intervalDidEnd(for: activity)
        case "intervalWillStartWarning": m.intervalWillStartWarning(for: activity)
        case "intervalWillEndWarning": m.intervalWillEndWarning(for: activity)
        case "eventDidReachThreshold": m.eventDidReachThreshold(event, activity: activity)
        case "eventWillReachThresholdWarning": m.eventWillReachThresholdWarning(event, activity: activity)
        default: break
        }
        // the extension may finish work on the main queue: answer once it has had a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { reply(["done": true]) }
    }
}
