// isim AlarmKit (adapted): alarms and timers that go off in the system's alarm UI. AlarmManager keeps the app's alarms
// in the device data ($ISIM_DATA/Library/isim/Alarms/<bundle ID>.json) and tells the shell when each goes off
// (runtime/shell_alarms.inc): the shell keeps the time, so an alarm goes off whether or not the app runs, plays its
// sound in Silent Mode, and shows the alert (a banner while the device is in use, full screen on the Lock Screen)
// with the presentation's title, its secondary button and Stop. What the user does there comes back to the app: Stop
// runs the configuration's stopIntent and ends the alarm (a weekly alarm is scheduled again); the secondary button
// starts the post-alert countdown (`.countdown`, e.g. snooze or repeat) or runs the secondaryIntent (`.custom`).
// An answer the user gave while the app was not running reaches it the next time it uses AlarmManager (iOS launches
// the app in the background for its intent). Countdowns and paused timers are the app's Live Activity
// (ActivityKit, AlarmAttributes with AlarmPresentationState as its content state) when the app supports Live
// Activities, drawn by its widget extension's ActivityConfiguration like any Live Activity.
// Authorization: the first schedule (or requestAuthorization) asks with NSAlarmKitUsageDescription, remembered per
// app; ISIM_ALARMKIT_PERMISSION=allow|deny answers without the alert. `isim alarms list` shows the device's alarms.
// The intents themselves are kept while the app runs (an alarm scheduled by an earlier run stops without one).
// Same API as Apple's; Swift only, like Apple's.
import Foundation
import UIKit
import SwiftUI
import AppIntents
import ActivityKit
import isim_host

// MARK: - alarms

@available(iOS 26.0, *)
public protocol AlarmMetadata: Decodable, Encodable, Hashable, Sendable {}

@available(iOS 26.0, *)
public struct Alarm: Identifiable, Sendable, Codable {
    public typealias ID = UUID
    public var id: UUID
    public var schedule: Alarm.Schedule?
    public var countdownDuration: Alarm.CountdownDuration?
    public var state: Alarm.State

    public struct CountdownDuration: Codable, Equatable, Sendable {
        public var preAlert: TimeInterval?
        public var postAlert: TimeInterval?
        public init(preAlert: TimeInterval?, postAlert: TimeInterval?) { self.preAlert = preAlert; self.postAlert = postAlert }
    }
    public enum State: Codable, Hashable, Sendable { case scheduled, countdown, paused, alerting }
    public enum Schedule: Codable, Hashable, Sendable {
        case fixed(Date)
        case relative(Alarm.Schedule.Relative)
        public struct Relative: Codable, Hashable, Sendable {
            public var time: Alarm.Schedule.Relative.Time
            public var repeats: Alarm.Schedule.Relative.Recurrence
            public init(time: Alarm.Schedule.Relative.Time, repeats: Alarm.Schedule.Relative.Recurrence = .never) { self.time = time; self.repeats = repeats }
            public struct Time: Codable, Hashable, Sendable {
                public var hour: Int
                public var minute: Int
                public init(hour: Int, minute: Int) { self.hour = hour; self.minute = minute }
            }
            public enum Recurrence: Codable, Hashable, Sendable {
                case never
                case weekly([Locale.Weekday])
            }
        }
        /// the next time it goes off, after `after`
        func next(after: Date) -> Date? {
            switch self {
            case .fixed(let d): return d
            case .relative(let r):
                let cal = Calendar.current
                var c = DateComponents(); c.hour = r.time.hour; c.minute = r.time.minute; c.second = 0
                guard case .weekly(let days) = r.repeats, !days.isEmpty else {
                    return cal.nextDate(after: after, matching: c, matchingPolicy: .nextTime)
                }
                let order: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
                return days.compactMap { d -> Date? in
                    var k = c; k.weekday = (order.firstIndex(of: d) ?? 0) + 1
                    return cal.nextDate(after: after, matching: k, matchingPolicy: .nextTime)
                }.min()
            }
        }
        var repeating: Bool {
            if case .relative(let r) = self, case .weekly(let days) = r.repeats { return !days.isEmpty }
            return false
        }
    }
}

// MARK: - presentation

/// Color as JSON: its RGBA components (isim's colours resolve to a UIColor)
func _encodeColor(_ c: Color) -> [Double] {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if !c.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
        var w: CGFloat = 0
        if c.uiColor.getWhite(&w, alpha: &a) { r = w; g = w; b = w } else { a = 1 }
    }
    return [Double(r), Double(g), Double(b), Double(a)]
}
func _decodeColor(_ v: [Double]) -> Color {
    v.count >= 3 ? Color(red: v[0], green: v[1], blue: v[2], opacity: v.count > 3 ? v[3] : 1) : .accentColor
}

@available(iOS 26.0, *)
public struct AlarmButton: Codable, Sendable {
    public var text: LocalizedStringResource
    public var textColor: Color
    public var systemImageName: String
    public init(text: LocalizedStringResource, textColor: Color, systemImageName: String) {
        self.text = text; self.textColor = textColor; self.systemImageName = systemImageName
    }
    enum CodingKeys: String, CodingKey { case text, textColor, systemImageName }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = LocalizedStringResource(stringLiteral: try c.decode(String.self, forKey: .text))
        textColor = _decodeColor(try c.decode([Double].self, forKey: .textColor))
        systemImageName = try c.decode(String.self, forKey: .systemImageName)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(String(localized: text), forKey: .text)
        try c.encode(_encodeColor(textColor), forKey: .textColor)
        try c.encode(systemImageName, forKey: .systemImageName)
    }
}

/// a LocalizedStringResource as JSON: the string it resolves to
struct _LSR: Codable, Sendable {
    let value: LocalizedStringResource
    init(_ v: LocalizedStringResource) { value = v }
    init(from decoder: any Decoder) throws { value = LocalizedStringResource(stringLiteral: try decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(String(localized: value)) }
}

@available(iOS 26.0, *)
public struct AlarmPresentation: Codable, Sendable {
    public var alert: AlarmPresentation.Alert
    public var countdown: AlarmPresentation.Countdown?
    public var paused: AlarmPresentation.Paused?
    public init(alert: AlarmPresentation.Alert, countdown: AlarmPresentation.Countdown? = nil, paused: AlarmPresentation.Paused? = nil) {
        self.alert = alert; self.countdown = countdown; self.paused = paused
    }

    public struct Alert: Codable, Sendable {
        public var title: LocalizedStringResource
        public var stopButton: AlarmButton
        public var secondaryButton: AlarmButton?
        public var secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior?
        public enum SecondaryButtonBehavior: Codable, Hashable, Sendable { case countdown, custom }
        /// iOS 26.1: the system's own Stop
        @available(iOS 26.1, *)
        public init(title: LocalizedStringResource, secondaryButton: AlarmButton? = nil, secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = nil) {
            self.init(title, AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"), secondaryButton, secondaryButtonBehavior)
        }
        @available(iOS, introduced: 26.0, deprecated: 26.1, message: "the system shows its own Stop button")
        public init(title: LocalizedStringResource, stopButton: AlarmButton, secondaryButton: AlarmButton? = nil, secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = nil) {
            self.init(title, stopButton, secondaryButton, secondaryButtonBehavior)
        }
        init(_ title: LocalizedStringResource, _ stop: AlarmButton, _ secondary: AlarmButton?, _ behavior: SecondaryButtonBehavior?) {
            self.title = title; stopButton = stop; secondaryButton = secondary; secondaryButtonBehavior = behavior
        }
        enum CodingKeys: String, CodingKey { case title, stopButton, secondaryButton, secondaryButtonBehavior }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(_LSR.self, forKey: .title).value
            stopButton = try c.decode(AlarmButton.self, forKey: .stopButton)
            secondaryButton = try c.decodeIfPresent(AlarmButton.self, forKey: .secondaryButton)
            secondaryButtonBehavior = try c.decodeIfPresent(SecondaryButtonBehavior.self, forKey: .secondaryButtonBehavior)
        }
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(_LSR(title), forKey: .title)
            try c.encode(stopButton, forKey: .stopButton)
            try c.encodeIfPresent(secondaryButton, forKey: .secondaryButton)
            try c.encodeIfPresent(secondaryButtonBehavior, forKey: .secondaryButtonBehavior)
        }
    }
    public struct Countdown: Codable, Sendable {
        public var title: LocalizedStringResource
        public var pauseButton: AlarmButton?
        public init(title: LocalizedStringResource, pauseButton: AlarmButton? = nil) { self.title = title; self.pauseButton = pauseButton }
        enum CodingKeys: String, CodingKey { case title, pauseButton }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(_LSR.self, forKey: .title).value
            pauseButton = try c.decodeIfPresent(AlarmButton.self, forKey: .pauseButton)
        }
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(_LSR(title), forKey: .title)
            try c.encodeIfPresent(pauseButton, forKey: .pauseButton)
        }
    }
    public struct Paused: Codable, Sendable {
        public var title: LocalizedStringResource
        public var resumeButton: AlarmButton
        public init(title: LocalizedStringResource, resumeButton: AlarmButton) { self.title = title; self.resumeButton = resumeButton }
        enum CodingKeys: String, CodingKey { case title, resumeButton }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(_LSR.self, forKey: .title).value
            resumeButton = try c.decode(AlarmButton.self, forKey: .resumeButton)
        }
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(_LSR(title), forKey: .title)
            try c.encode(resumeButton, forKey: .resumeButton)
        }
    }
}

/// the content state of an alarm's Live Activity
@available(iOS 26.0, *)
public struct AlarmPresentationState: Codable, Hashable, Sendable {
    public var alarmID: Alarm.ID
    public var mode: AlarmPresentationState.Mode
    public init(alarmID: Alarm.ID, mode: AlarmPresentationState.Mode) { self.alarmID = alarmID; self.mode = mode }
    public enum Mode: Codable, Hashable, Sendable {
        case alert(AlarmPresentationState.Mode.Alert)
        case countdown(AlarmPresentationState.Mode.Countdown)
        case paused(AlarmPresentationState.Mode.Paused)
        public struct Alert: Codable, Hashable, Sendable {
            public var time: Alarm.Schedule.Relative.Time
            public init(time: Alarm.Schedule.Relative.Time) { self.time = time }
        }
        public struct Countdown: Codable, Hashable, Sendable {
            public var totalCountdownDuration: TimeInterval
            public var previouslyElapsedDuration: TimeInterval
            public var startDate: Date
            public var fireDate: Date
            public init(totalCountdownDuration: TimeInterval, previouslyElapsedDuration: TimeInterval, startDate: Date, fireDate: Date) {
                self.totalCountdownDuration = totalCountdownDuration; self.previouslyElapsedDuration = previouslyElapsedDuration
                self.startDate = startDate; self.fireDate = fireDate
            }
        }
        public struct Paused: Codable, Hashable, Sendable {
            public var totalCountdownDuration: TimeInterval
            public var previouslyElapsedDuration: TimeInterval
            public init(totalCountdownDuration: TimeInterval, previouslyElapsedDuration: TimeInterval) {
                self.totalCountdownDuration = totalCountdownDuration; self.previouslyElapsedDuration = previouslyElapsedDuration
            }
        }
    }
}

/// the attributes of an alarm's Live Activity: its presentation, the app's metadata, the tint
@available(iOS 26.0, *)
public struct AlarmAttributes<Metadata>: ActivityAttributes, Sendable where Metadata: AlarmMetadata {
    public typealias ContentState = AlarmPresentationState
    public var presentation: AlarmPresentation
    public var metadata: Metadata?
    public var tintColor: Color
    public init(presentation: AlarmPresentation, metadata: Metadata? = nil, tintColor: Color) {
        self.presentation = presentation; self.metadata = metadata; self.tintColor = tintColor
    }
    enum CodingKeys: String, CodingKey { case presentation, metadata, tintColor }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        presentation = try c.decode(AlarmPresentation.self, forKey: .presentation)
        metadata = try c.decodeIfPresent(Metadata.self, forKey: .metadata)
        tintColor = _decodeColor(try c.decode([Double].self, forKey: .tintColor))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(presentation, forKey: .presentation)
        try c.encodeIfPresent(metadata, forKey: .metadata)
        try c.encode(_encodeColor(tintColor), forKey: .tintColor)
    }
}

// MARK: - the manager

@available(iOS 26.0, *)
public final class AlarmManager: @unchecked Sendable {
    public static let shared = AlarmManager()
    init() { _Alarms.start() }

    public enum AuthorizationState: Codable, Hashable, Sendable { case notDetermined, denied, authorized }
    public enum AlarmError: Error, Hashable, Sendable { case maximumLimitReached }

    public struct AlarmConfiguration<Metadata> where Metadata: AlarmMetadata {
        let countdownDuration: Alarm.CountdownDuration?
        let schedule: Alarm.Schedule?
        let attributes: AlarmAttributes<Metadata>
        let appEntityIdentifier: EntityIdentifier?
        let stopIntent: (any LiveActivityIntent)?
        let secondaryIntent: (any LiveActivityIntent)?
        let sound: AlertConfiguration.AlertSound
        public init(countdownDuration: Alarm.CountdownDuration? = nil, schedule: Alarm.Schedule? = nil, attributes: AlarmAttributes<Metadata>,
                    stopIntent: (any LiveActivityIntent)? = nil, secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) {
            self.init(countdownDuration, schedule, attributes, nil, stopIntent, secondaryIntent, sound)
        }
        @available(iOS 27.0, *)
        public init(countdownDuration: Alarm.CountdownDuration? = nil, schedule: Alarm.Schedule? = nil, attributes: AlarmAttributes<Metadata>, appEntityIdentifier: EntityIdentifier? = nil,
                    stopIntent: (any LiveActivityIntent)? = nil, secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) {
            self.init(countdownDuration, schedule, attributes, appEntityIdentifier, stopIntent, secondaryIntent, sound)
        }
        init(_ countdown: Alarm.CountdownDuration?, _ schedule: Alarm.Schedule?, _ attributes: AlarmAttributes<Metadata>, _ entity: EntityIdentifier?,
             _ stop: (any LiveActivityIntent)?, _ secondary: (any LiveActivityIntent)?, _ sound: AlertConfiguration.AlertSound) {
            countdownDuration = countdown; self.schedule = schedule; self.attributes = attributes; appEntityIdentifier = entity
            stopIntent = stop; secondaryIntent = secondary; self.sound = sound
        }
        /// an alarm: goes off at the schedule
        public static func alarm(schedule: Alarm.Schedule? = nil, attributes: AlarmAttributes<Metadata>, stopIntent: (any LiveActivityIntent)? = nil,
                                 secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) -> AlarmConfiguration<Metadata> {
            AlarmConfiguration(nil, schedule, attributes, nil, stopIntent, secondaryIntent, sound)
        }
        @available(iOS 27.0, *)
        public static func alarm(schedule: Alarm.Schedule? = nil, attributes: AlarmAttributes<Metadata>, appEntityIdentifier: EntityIdentifier? = nil, stopIntent: (any LiveActivityIntent)? = nil,
                                 secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) -> AlarmConfiguration<Metadata> {
            AlarmConfiguration(nil, schedule, attributes, appEntityIdentifier, stopIntent, secondaryIntent, sound)
        }
        /// a timer: counts down `duration`, then goes off
        public static func timer(duration: TimeInterval, attributes: AlarmAttributes<Metadata>, stopIntent: (any LiveActivityIntent)? = nil,
                                 secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) -> AlarmConfiguration<Metadata> {
            AlarmConfiguration(Alarm.CountdownDuration(preAlert: duration, postAlert: nil), nil, attributes, nil, stopIntent, secondaryIntent, sound)
        }
        @available(iOS 27.0, *)
        public static func timer(duration: TimeInterval, attributes: AlarmAttributes<Metadata>, appEntityIdentifier: EntityIdentifier? = nil, stopIntent: (any LiveActivityIntent)? = nil,
                                 secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) -> AlarmConfiguration<Metadata> {
            AlarmConfiguration(Alarm.CountdownDuration(preAlert: duration, postAlert: nil), nil, attributes, appEntityIdentifier, stopIntent, secondaryIntent, sound)
        }
    }

    public struct AlarmUpdates: AsyncSequence {
        public typealias Element = [Alarm]
        public typealias Failure = Never
        let stream: AsyncStream<[Alarm]>
        public struct Iterator: AsyncIteratorProtocol {
            public typealias Element = [Alarm]
            public typealias Failure = Never
            var base: AsyncStream<[Alarm]>.Iterator
            public mutating func next() async -> AlarmManager.AlarmUpdates.Element? { await base.next() }
        }
        public func makeAsyncIterator() -> AlarmManager.AlarmUpdates.Iterator { Iterator(base: stream.makeAsyncIterator()) }
    }
    public struct AlarmAuthorizationStateUpdates: AsyncSequence {
        public typealias Element = AlarmManager.AuthorizationState
        public typealias Failure = Never
        let stream: AsyncStream<AuthorizationState>
        public struct Iterator: AsyncIteratorProtocol {
            public typealias Element = AlarmManager.AuthorizationState
            public typealias Failure = Never
            var base: AsyncStream<AuthorizationState>.Iterator
            public mutating func next() async -> AlarmManager.AuthorizationState? { await base.next() }
        }
        public func makeAsyncIterator() -> AlarmManager.AlarmAuthorizationStateUpdates.Iterator { Iterator(base: stream.makeAsyncIterator()) }
    }

    /// the app's alarms: every change (the current ones first)
    public var alarmUpdates: some AsyncSequence<Array<Alarm>, Never> { AlarmUpdates(stream: _Alarms.alarmStreams.stream(initial: _Alarms.list())) }
    /// the app's alarms that have not ended
    public var alarms: [Alarm] { get throws { _Alarms.list() } }
    public var authorizationState: AlarmManager.AuthorizationState { _Alarms.authorization }
    public var authorizationUpdates: some AsyncSequence<AlarmManager.AuthorizationState, Never> {
        AlarmAuthorizationStateUpdates(stream: _Alarms.authStreams.stream(initial: _Alarms.authorization))
    }
    /// asks the user (once) to let the app schedule alarms and timers
    public func requestAuthorization() async throws -> AlarmManager.AuthorizationState { await _Alarms.requestAuthorization() }

    /// schedules an alarm (asks for authorization first when the user has not answered yet)
    public func schedule<Metadata>(id: Alarm.ID, configuration: AlarmManager.AlarmConfiguration<Metadata>) async throws -> Alarm where Metadata: AlarmMetadata {
        var auth = _Alarms.authorization
        if auth == .notDetermined { auth = await _Alarms.requestAuthorization() }
        guard auth == .authorized else { throw _AlarmKitError("the user has not allowed this app to schedule alarms and timers") }
        return try _Alarms.schedule(id: id, configuration)
    }
    /// cancels an alarm in any state: it is removed
    public func cancel(id: Alarm.ID) throws { try _Alarms.change(id, "cancel") }
    /// stops an alerting alarm (a repeating one is scheduled again)
    public func stop(id: Alarm.ID) throws { try _Alarms.change(id, "stop") }
    /// starts the alarm's post-alert countdown (an alerting alarm: snooze or repeat)
    public func countdown(id: Alarm.ID) throws { try _Alarms.change(id, "countdown") }
    /// pauses a counting-down alarm
    public func pause(id: Alarm.ID) throws { try _Alarms.change(id, "pause") }
    /// resumes a paused alarm
    public func resume(id: Alarm.ID) throws { try _Alarms.change(id, "resume") }
}

struct _AlarmKitError: LocalizedError, CustomStringConvertible {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
    var description: String { message }
}

// MARK: - the engine

/// One alarm as the device keeps it.
@available(iOS 26.0, *)
struct _AlarmRecord: Codable {
    var alarm: Alarm
    var fire: Double = 0                   /* when it goes off next (seconds since 1970); 0 while paused or alerting */
    var total: Double = 0                  /* the countdown: its length, what elapsed before a pause, when it (re)started */
    var elapsed: Double = 0
    var start: Double = 0
    var title = "", stop = "Stop", secondary = "", symbol = "", behavior = "", sound = "", kind = "alarm", app = ""
    var tint: [Double] = []
    var type = "", attributes = ""         /* the Live Activity's attributes type and JSON */
    var activity = ""                      /* the Live Activity's id */
}

@available(iOS 26.0, *)
enum _Alarms {
    static let lock = NSRecursiveLock()
    nonisolated(unsafe) static var records: [_AlarmRecord] = []
    nonisolated(unsafe) static var started = false
    nonisolated(unsafe) static var intents: [UUID: (stop: (any LiveActivityIntent)?, secondary: (any LiveActivityIntent)?)] = [:]
    /// the Live Activity of each alarm this run scheduled: given the content state to show, or nil to end it
    nonisolated(unsafe) static var activities: [UUID: (AlarmPresentationState?) -> Void] = [:]
    nonisolated(unsafe) static var timer: DispatchSourceTimer?
    static let alarmStreams = _Broadcast<[Alarm]>()
    static let authStreams = _Broadcast<AlarmManager.AuthorizationState>()
    static let limit = 64

    static var file: String { (_Privacy.deviceDir("Library/isim/Alarms") as NSString).appendingPathComponent(_Privacy.bundleID + ".json") }
    static func start() {
        lock.lock(); defer { lock.unlock() }
        guard !started else { return }
        started = true
        records = _Privacy.readJSON([_AlarmRecord].self, file) ?? []
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { n in
            guard let t = n.object as? String, t.hasPrefix("alarm-action ") else { return }
            let p = t.dropFirst(13).split(separator: " ").map(String.init)
            if p.count == 2, let id = UUID(uuidString: p[1]) { systemAction(p[0], id) }
        }
        /* the shell keeps the time; tell it again (it may have restarted; an answer the user gave meanwhile comes back) */
        for r in records { tell(r) }
        DispatchQueue.main.async { tick() }
    }
    static func save() { _Privacy.writeJSON(records, file) }
    static func list() -> [Alarm] { lock.lock(); defer { lock.unlock() }; return records.map(\.alarm) }
    static func changed() {
        save()
        let all = records.map(\.alarm)
        alarmStreams.yield(all)
        ensureTimer()
    }

    // MARK: authorization
    static var authorization: AlarmManager.AuthorizationState {
        switch _Privacy.stored("alarmkit") { case 1: return .authorized; case 0: return .denied; default: return .notDetermined }
    }
    static func requestAuthorization() async -> AlarmManager.AuthorizationState {
        if authorization != .notDetermined { return authorization }
        return await withCheckedContinuation { (k: CheckedContinuation<AlarmManager.AuthorizationState, Never>) in
            func answer(_ ok: Bool) {
                _Privacy.store("alarmkit", ok ? 1 : 0)
                NSLog("isim AlarmKit: alarms and timers %@ for %@", ok ? "allowed" : "denied", _Privacy.appName)
                authStreams.yield(authorization)
                k.resume(returning: authorization)
            }
            guard let purpose = _Privacy.usage("NSAlarmKitUsageDescription", "AlarmKit") else { answer(false); return }
            if let s = _Privacy.scripted("ALARMKIT") { answer(!(s == "deny" || s == "denied" || s == "no" || s == "0")); return }
            _Privacy.onMain {
                _Privacy.alert("“\(_Privacy.appName)” Would Like to Schedule Alarms and Timers", purpose,
                               [("Don’t Allow", .default), ("Allow", .default)]) { answer($0 == 1) }
            }
        }
    }

    // MARK: scheduling
    static func schedule<M: AlarmMetadata>(id: UUID, _ c: AlarmManager.AlarmConfiguration<M>) throws -> Alarm {
        lock.lock(); defer { lock.unlock() }
        let replacing = records.firstIndex { $0.alarm.id == id }
        if replacing == nil && records.count >= limit { throw AlarmManager.AlarmError.maximumLimitReached }
        if let i = replacing { end(i, remove: true) }
        guard c.schedule != nil || c.countdownDuration?.preAlert != nil else {
            throw _AlarmKitError("an alarm needs a schedule or a countdown duration with a pre-alert")
        }
        var r = _AlarmRecord(alarm: Alarm(id: id, schedule: c.schedule, countdownDuration: c.countdownDuration, state: .scheduled))
        let a = c.attributes, alert = a.presentation.alert
        r.title = String(localized: alert.title)
        r.stop = String(localized: alert.stopButton.text)
        if let s = alert.secondaryButton {
            r.secondary = String(localized: s.text); r.symbol = s.systemImageName
            r.behavior = alert.secondaryButtonBehavior == .countdown ? "countdown" : "custom"
        }
        r.tint = _encodeColor(a.tintColor)
        r.sound = soundPath(c.sound)
        r.kind = c.schedule == nil ? "timer" : "alarm"
        r.app = _Privacy.appName
        r.type = String(describing: AlarmAttributes<M>.self)
        r.attributes = (try? JSONEncoder().encode(a)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        intents[id] = (c.stopIntent, c.secondaryIntent)
        activities[id] = liveActivity(a)
        let now = Date()
        if let s = c.schedule {
            r.fire = (s.next(after: now) ?? now).timeIntervalSince1970
        } else {
            countdown(&r, c.countdownDuration?.preAlert ?? 0)
        }
        records.append(r)
        NSLog("isim AlarmKit: scheduled %@ %@ (%@)", r.kind, r.title, id.uuidString)
        apply(records.count - 1)
        return r.alarm
    }
    static func soundPath(_ s: AlertConfiguration.AlertSound) -> String {
        guard case .named(let name) = s, !name.isEmpty else { return "" }
        if let p = Bundle.main.path(forResource: name, ofType: nil) { return p }
        let lib = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? ""
        let p = ((lib as NSString).appendingPathComponent("Sounds") as NSString).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: p) ? p : ""
    }
    static func countdown(_ r: inout _AlarmRecord, _ length: TimeInterval) {
        let now = Date().timeIntervalSince1970
        r.alarm.state = .countdown
        r.total = length; r.elapsed = 0; r.start = now; r.fire = now + length
    }
    /// the record changed: tell the shell, the Live Activity and the app's observers
    static func apply(_ i: Int) {
        let r = records[i]
        tell(r)
        if let la = activities[r.alarm.id] { la(presentationState(r)) }
        changed()
    }
    static func presentationState(_ r: _AlarmRecord) -> AlarmPresentationState? {
        let id = r.alarm.id
        switch r.alarm.state {
        case .scheduled: return nil
        case .countdown:
            return AlarmPresentationState(alarmID: id, mode: .countdown(.init(totalCountdownDuration: r.total, previouslyElapsedDuration: r.elapsed,
                                                                                startDate: Date(timeIntervalSince1970: r.start), fireDate: Date(timeIntervalSince1970: r.fire))))
        case .paused:
            return AlarmPresentationState(alarmID: id, mode: .paused(.init(totalCountdownDuration: r.total, previouslyElapsedDuration: r.elapsed)))
        case .alerting:
            let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
            return AlarmPresentationState(alarmID: id, mode: .alert(.init(time: .init(hour: c.hour ?? 0, minute: c.minute ?? 0))))
        }
    }
    /// alarm-set while it is to go off, alarm-clear while it is not (paused; alerting: the shell shows it)
    static func tell(_ r: _AlarmRecord) {
        let id = r.alarm.id.uuidString
        switch r.alarm.state {
        case .scheduled, .countdown:
            let clean = { (s: String) in s.replacingOccurrences(of: "\u{1f}", with: " ").replacingOccurrences(of: "\n", with: " ") }
            let tint = r.tint.prefix(3).map { String(format: "%.3f", $0) }.joined(separator: ",")
            let f = [clean(r.title), clean(r.stop), clean(r.secondary), r.symbol, clean(r.app), tint, r.sound, r.kind].joined(separator: "\u{1f}")
            isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "alarm-set", id, String(format: "%.3f ", r.fire) + f)
        case .paused:
            isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "alarm-clear", id, "")
        case .alerting:
            break
        }
    }
    static func end(_ i: Int, remove: Bool) {
        let r = records[i]
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "alarm-clear", r.alarm.id.uuidString, "")
        if let la = activities[r.alarm.id] { la(nil) }
        if remove { records.remove(at: i); intents[r.alarm.id] = nil; activities[r.alarm.id] = nil }
    }
    /// stopped: a repeating alarm is scheduled again; any other alarm ends
    static func finish(_ i: Int) {
        var r = records[i]
        if let s = r.alarm.schedule, s.repeating, let next = s.next(after: Date().addingTimeInterval(1)) {
            if let la = activities[r.alarm.id] { la(nil) }
            r.alarm.state = .scheduled; r.fire = next.timeIntervalSince1970; r.total = 0; r.elapsed = 0
            records[i] = r
            NSLog("isim AlarmKit: %@ scheduled again for %@", r.title, "\(next)")
            apply(i)
        } else {
            end(i, remove: true)
            changed()
        }
    }

    static func change(_ id: UUID, _ verb: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard let i = records.firstIndex(where: { $0.alarm.id == id }) else { throw _AlarmKitError("no alarm \(id.uuidString)") }
        var r = records[i]
        let now = Date().timeIntervalSince1970
        switch verb {
        case "cancel":
            NSLog("isim AlarmKit: cancelled %@", r.title)
            end(i, remove: true); changed(); return
        case "stop":
            NSLog("isim AlarmKit: stopped %@", r.title)
            isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "alarm-clear", id.uuidString, "")
            finish(i); return
        case "countdown":
            guard r.alarm.state == .alerting || r.alarm.state == .scheduled else { throw _AlarmKitError("\(r.title) is \(r.alarm.state)") }
            let length = r.alarm.state == .alerting ? r.alarm.countdownDuration?.postAlert : r.alarm.countdownDuration?.preAlert
            guard let l = length else { throw _AlarmKitError("\(r.title) has no \(r.alarm.state == .alerting ? "post" : "pre")-alert duration") }
            if r.alarm.state == .alerting { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "alarm-clear", id.uuidString, "") }
            countdown(&r, l)
        case "pause":
            guard r.alarm.state == .countdown else { throw _AlarmKitError("\(r.title) is not counting down") }
            r.elapsed += now - r.start; r.fire = 0; r.alarm.state = .paused
        case "resume":
            guard r.alarm.state == .paused else { throw _AlarmKitError("\(r.title) is not paused") }
            r.start = now; r.fire = now + max(0, r.total - r.elapsed); r.alarm.state = .countdown
        default: return
        }
        records[i] = r
        NSLog("isim AlarmKit: %@ is %@", r.title, "\(r.alarm.state)")
        apply(i)
    }

    /// "alarm-action alert|stop|secondary UUID": the shell's alert
    static func systemAction(_ what: String, _ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard let i = records.firstIndex(where: { $0.alarm.id == id }) else { return }
        var r = records[i]
        switch what {
        case "alert":
            r.alarm.state = .alerting; r.fire = 0
            records[i] = r
            NSLog("isim AlarmKit: %@ is alerting", r.title)
            if let la = activities[id] { la(presentationState(r)) }
            changed()
        case "stop":
            NSLog("isim AlarmKit: the user stopped %@", r.title)
            run(intents[id]?.stop)
            finish(i)
        case "secondary":
            NSLog("isim AlarmKit: the user chose %@ on %@", r.secondary, r.title)
            if r.behavior == "countdown", let l = r.alarm.countdownDuration?.postAlert {
                countdown(&r, l)
                records[i] = r
                apply(i)
            } else {
                run(intents[id]?.secondary)
                finish(i)
            }
        default: break
        }
    }
    static func run(_ intent: (any LiveActivityIntent)?) {
        guard let intent else { return }
        Task { @MainActor in await _isimPerform(intent) }
    }

    /// countdowns that start before a scheduled alarm (a pre-alert), and alarms the shell did not report
    static func tick() {
        lock.lock(); defer { lock.unlock() }
        let now = Date().timeIntervalSince1970
        for i in records.indices {
            let r = records[i]
            if r.alarm.state == .scheduled, r.alarm.schedule != nil, let pre = r.alarm.countdownDuration?.preAlert, r.fire - pre <= now, r.fire > now {
                var c = r
                c.alarm.state = .countdown; c.total = pre; c.elapsed = 0; c.start = r.fire - pre
                records[i] = c
                NSLog("isim AlarmKit: %@ is counting down", r.title)
                apply(i)
            }
        }
    }
    static func ensureTimer() {
        guard timer == nil, records.contains(where: { $0.alarm.schedule != nil && $0.alarm.countdownDuration?.preAlert != nil }) else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 0.5, repeating: 0.5)
        t.setEventHandler { tick() }
        t.resume(); timer = t
    }

    /// the alarm's Live Activity, when the app supports Live Activities: started by the first countdown
    static func liveActivity<M: AlarmMetadata>(_ attributes: AlarmAttributes<M>) -> (AlarmPresentationState?) -> Void {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return { _ in } }
        nonisolated(unsafe) var activity: Activity<AlarmAttributes<M>>?
        return { state in
            guard let state else {
                if let a = activity { activity = nil; Task { await a.end(nil, dismissalPolicy: .immediate) } }
                return
            }
            if let a = activity { Task { await a.update(ActivityContent(state: state, staleDate: nil)) }; return }
            if case .alert = state.mode { return }
            activity = try? Activity<AlarmAttributes<M>>.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        }
    }
}

/// the continuations of one async sequence
final class _Broadcast<T: Sendable>: @unchecked Sendable {
    var all: [UUID: AsyncStream<T>.Continuation] = [:]
    let lock = NSLock()
    func stream(initial: T? = nil) -> AsyncStream<T> {
        let k = UUID()
        var cont: AsyncStream<T>.Continuation!
        let s = AsyncStream<T> { cont = $0 }
        lock.lock(); all[k] = cont; lock.unlock()
        cont.onTermination = { _ in self.lock.lock(); self.all[k] = nil; self.lock.unlock() }
        if let v = initial { cont.yield(v) }
        return s
    }
    func yield(_ v: T) { lock.lock(); let cs = Array(all.values); lock.unlock(); for c in cs { c.yield(v) } }
}
