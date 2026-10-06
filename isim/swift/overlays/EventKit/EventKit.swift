// isim EventKit (self-authored, iOS API names): the device calendar database ($ISIM_DATA/Library/Calendar/calendar.json,
// created on first use with the Simulator's default "Calendar" calendar and "Reminders" list), the iOS 17 access
// prompts (full access / write-only for events, full access for reminders; remembered per app), events, reminders,
// predicates and saving. Recurrence rules and alarms are stored but not expanded or fired (adapted).
// Automation: ISIM_CALENDAR_PERMISSION / ISIM_REMINDERS_PERMISSION = allow|writeonly|deny.
import UIKit

@objc public enum EKEntityType: UInt, Sendable { case event = 0, reminder = 1 }
public struct EKEntityMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let event = EKEntityMask(rawValue: 1), reminder = EKEntityMask(rawValue: 2)
}
@objc public enum EKAuthorizationStatus: Int, Sendable {
    case notDetermined = 0, restricted, denied, fullAccess, writeOnly
    @available(*, deprecated, renamed: "fullAccess") public static var authorized: EKAuthorizationStatus { .fullAccess }
}
@objc public enum EKSpan: Int, Sendable { case thisEvent = 0, futureEvents }
@objc public enum EKCalendarType: Int, Sendable { case local = 0, calDAV, exchange, subscription, birthday }
@objc public enum EKSourceType: Int, Sendable { case local = 0, exchange, calDAV, mobileMe, subscribed, birthdays }
@objc public enum EKEventAvailability: Int, Sendable { case notSupported = -1, busy = 0, free, tentative, unavailable }
@objc public enum EKEventStatus: Int, Sendable { case none = 0, confirmed, tentative, canceled }
@objc public enum EKRecurrenceFrequency: Int, Sendable { case daily = 0, weekly, monthly, yearly }
@objc public enum EKReminderPriority: UInt, Sendable { case none = 0, high = 1, medium = 5, low = 9 }

public let EKErrorDomain = "EKErrorDomain"
public struct EKError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case eventNotMutable = 0, noCalendar, noStartDate, noEndDate, datesInverted, internalFailure, calendarReadOnly
        case durationGreaterThanRecurrence, alarmGreaterThanRecurrence, startDateTooFarInFuture, startDateCollidesWithOtherOccurrence
        case objectBelongsToDifferentStore, invitesCannotBeMoved, invalidSpan, calendarHasNoSource, calendarSourceCannotBeModified
        case calendarIsImmutable, sourceDoesNotAllowCalendarAddDelete, recurringReminderRequiresDueDate, structuredLocationsNotSupported
        case reminderLocationsNotSupported, alarmProximityNotSupported, calendarDoesNotAllowEvents, calendarDoesNotAllowReminders
        case sourceDoesNotAllowReminders, sourceDoesNotAllowEvents, priorityIsInvalid, invalidEntityType, procedureAlarmsNotMutable
        case eventStoreNotAuthorized, osNotSupported, invalidInviteReplyCalendar, notificationsCollectionFlagNotSet
        case sourceMismatch, notificationCollectionMismatch, notificationSavedWithoutCollection, reminderAlarmContainsEmailOrUrl
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { EKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? {
        switch code {
        case .noCalendar: return "No calendar has been set."
        case .noStartDate: return "No start date has been set."
        case .noEndDate: return "No end date has been set."
        case .datesInverted: return "The start date must be before the end date."
        case .eventStoreNotAuthorized: return "Access to the event store is not authorized."
        default: return "EventKit error \(code.rawValue)"
        }
    }
}

extension Notification.Name { public static let EKEventStoreChanged = Notification.Name("EKEventStoreChangedNotification") }

// MARK: - Database

struct _EKCal: Codable { var id: String; var title: String; var type: UInt; var color: [Double]; var readOnly: Bool = false }
struct _EKItem: Codable {
    var id: String; var kind: UInt; var calendar: String; var title: String
    var start: Double?; var end: Double?; var allDay: Bool = false
    var location: String?; var notes: String?; var url: String?; var tz: String?
    var due: [Int?]?; var startComps: [Int?]?; var completed: Bool = false; var completedAt: Double?; var priority: Int = 0
    var alarms: [Double] = []; var rule: [Int]?               // [frequency, interval]
    var availability: Int = 0; var created: Double = 0; var modified: Double = 0; var app: String = ""
}
struct _EKDB: Codable { var calendars: [_EKCal] = []; var items: [_EKItem] = [] }

enum _EKStore {
    static var path: String { (_Privacy.deviceDir("Library/Calendar") as NSString).appendingPathComponent("calendar.json") }
    static func load() -> _EKDB {
        if let d = _Privacy.readJSON(_EKDB.self, path) { return d }
        let d = _EKDB(calendars: [
            _EKCal(id: "isim-calendar-default", title: "Calendar", type: 0, color: [0.94, 0.22, 0.22]),
            _EKCal(id: "isim-reminders-default", title: "Reminders", type: 1, color: [0.0, 0.48, 1.0]),
        ])
        save(d)
        return d
    }
    static func save(_ d: _EKDB) { _Privacy.writeJSON(d, path) }
}

enum _EKAuth {
    static func key(_ t: EKEntityType) -> String { t == .event ? "calendar" : "reminders" }
    static func status(_ t: EKEntityType) -> EKAuthorizationStatus { _Privacy.stored(key(t)).flatMap { EKAuthorizationStatus(rawValue: $0) } ?? .notDetermined }
    static func canRead(_ t: EKEntityType) -> Bool { status(t) == .fullAccess }
    static func canWrite(_ t: EKEntityType) -> Bool { status(t) == .fullAccess || status(t) == .writeOnly }
}

// MARK: - Objects

open class EKObject: NSObject, @unchecked Sendable {
    open var hasChanges: Bool { true }
    open func isNew() -> Bool { true }
    open func reset() {}
    open func rollback() {}
    open func refresh() -> Bool { true }
}
open class EKSource: EKObject, @unchecked Sendable {
    open var sourceIdentifier: String { "isim-local" }
    open var sourceType: EKSourceType { .local }
    open var title: String { "Default" }
    open var isDelegate: Bool { false }
    open func calendars(for entityType: EKEntityType) -> Set<EKCalendar> {
        Set(_EKStore.load().calendars.filter { $0.type == entityType.rawValue }.map { EKCalendar($0) })
    }
}

open class EKCalendar: EKObject, @unchecked Sendable {
    var c: _EKCal
    init(_ c: _EKCal) { self.c = c }
    public init(for entityType: EKEntityType, eventStore: EKEventStore) {
        c = _EKCal(id: UUID().uuidString, title: "", type: entityType.rawValue, color: [0.6, 0.3, 0.9])
    }
    @available(*, deprecated) public convenience init(eventStore: EKEventStore) { self.init(for: .event, eventStore: eventStore) }
    open var calendarIdentifier: String { c.id }
    open var title: String { get { c.title } set { c.title = newValue } }
    open var type: EKCalendarType { .local }
    open var allowsContentModifications: Bool { !c.readOnly }
    open var isSubscribed: Bool { false }
    open var isImmutable: Bool { false }
    open var source: EKSource! { get { EKSource() } set {} }
    open var allowedEntityTypes: EKEntityMask { c.type == 0 ? .event : .reminder }
    open var cgColor: CGColor! {
        get { UIColor(red: c.color[0], green: c.color[1], blue: c.color[2], alpha: 1).cgColor }
        set { if let n = newValue { var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; if UIColor(cgColor: n).getRed(&r, green: &g, blue: &b, alpha: &a) { c.color = [Double(r), Double(g), Double(b)] } } }
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? EKCalendar)?.c.id == c.id }
    open override var hash: Int { c.id.hashValue }
}

open class EKAlarm: EKObject, NSCopying, @unchecked Sendable {
    open var relativeOffset: TimeInterval
    open var absoluteDate: Date?
    public init(relativeOffset offset: TimeInterval) { relativeOffset = offset }
    public init(absoluteDate date: Date) { relativeOffset = 0; absoluteDate = date }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}
open class EKRecurrenceEnd: NSObject, NSCopying, @unchecked Sendable {
    public let endDate: Date?, occurrenceCount: Int
    public init(end endDate: Date) { self.endDate = endDate; occurrenceCount = 0 }
    public init(occurrenceCount: Int) { endDate = nil; self.occurrenceCount = occurrenceCount }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}
open class EKRecurrenceRule: EKObject, NSCopying, @unchecked Sendable {
    public let frequency: EKRecurrenceFrequency
    public let interval: Int
    open var recurrenceEnd: EKRecurrenceEnd?
    public init(recurrenceWith type: EKRecurrenceFrequency, interval: Int, end: EKRecurrenceEnd?) { frequency = type; self.interval = interval; recurrenceEnd = end }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}

open class EKCalendarItem: EKObject, @unchecked Sendable {
    var i: _EKItem
    init(_ i: _EKItem) { self.i = i }
    open var calendarItemIdentifier: String { i.id }
    open var calendarItemExternalIdentifier: String! { i.id }
    open var calendar: EKCalendar! {
        get { _EKStore.load().calendars.first { $0.id == i.calendar }.map { EKCalendar($0) } }
        set { i.calendar = newValue?.calendarIdentifier ?? "" }
    }
    open var title: String! { get { i.title } set { i.title = newValue ?? "" } }
    open var location: String? { get { i.location } set { i.location = newValue } }
    open var notes: String? { get { i.notes } set { i.notes = newValue } }
    open var url: URL? { get { i.url.flatMap(URL.init(string:)) } set { i.url = newValue?.absoluteString } }
    open var timeZone: TimeZone? { get { i.tz.flatMap(TimeZone.init(identifier:)) } set { i.tz = newValue?.identifier } }
    open var hasNotes: Bool { !(i.notes ?? "").isEmpty }
    open var hasAlarms: Bool { !i.alarms.isEmpty }
    open var hasRecurrenceRules: Bool { i.rule != nil }
    open var creationDate: Date? { i.created > 0 ? Date(timeIntervalSince1970: i.created) : nil }
    open var lastModifiedDate: Date? { i.modified > 0 ? Date(timeIntervalSince1970: i.modified) : nil }
    open var alarms: [EKAlarm]? {
        get { i.alarms.isEmpty ? nil : i.alarms.map { EKAlarm(relativeOffset: $0) } }
        set { i.alarms = (newValue ?? []).map(\.relativeOffset) }
    }
    open func addAlarm(_ alarm: EKAlarm) { i.alarms.append(alarm.relativeOffset) }
    open func removeAlarm(_ alarm: EKAlarm) { i.alarms.removeAll { $0 == alarm.relativeOffset } }
    open var recurrenceRules: [EKRecurrenceRule]? {
        get { i.rule.map { [EKRecurrenceRule(recurrenceWith: EKRecurrenceFrequency(rawValue: $0[0]) ?? .daily, interval: $0[1], end: nil)] } }
        set { i.rule = newValue?.first.map { [$0.frequency.rawValue, $0.interval] } }
    }
    open func addRecurrenceRule(_ rule: EKRecurrenceRule) { i.rule = [rule.frequency.rawValue, rule.interval] }
    open func removeRecurrenceRule(_ rule: EKRecurrenceRule) { i.rule = nil }
}

open class EKEvent: EKCalendarItem, @unchecked Sendable {
    public init(eventStore: EKEventStore) { super.init(_EKItem(id: UUID().uuidString, kind: 0, calendar: "", title: "")) }
    override init(_ i: _EKItem) { super.init(i) }
    open var eventIdentifier: String! { i.id }
    open var startDate: Date! { get { i.start.map(Date.init(timeIntervalSince1970:)) } set { i.start = newValue?.timeIntervalSince1970 } }
    open var endDate: Date! { get { i.end.map(Date.init(timeIntervalSince1970:)) } set { i.end = newValue?.timeIntervalSince1970 } }
    open var isAllDay: Bool { get { i.allDay } set { i.allDay = newValue } }
    open var availability: EKEventAvailability { get { EKEventAvailability(rawValue: i.availability) ?? .busy } set { i.availability = newValue.rawValue } }
    open var status: EKEventStatus { .none }
    open var isDetached: Bool { false }
    open var occurrenceDate: Date! { startDate }
    open var organizer: AnyObject? { nil }
    open var birthdayContactIdentifier: String? { nil }
    open func compareStartDate(with other: EKEvent) -> ComparisonResult {
        startDate < other.startDate ? .orderedAscending : startDate > other.startDate ? .orderedDescending : .orderedSame
    }
    open override var description: String { "EKEvent <\(i.id)> {title = \(i.title); startDate = \(startDate.map { "\($0)" } ?? "nil")}" }
}

open class EKReminder: EKCalendarItem, @unchecked Sendable {
    public init(eventStore: EKEventStore) { super.init(_EKItem(id: UUID().uuidString, kind: 1, calendar: "", title: "")) }
    override init(_ i: _EKItem) { super.init(i) }
    static func comps(_ c: DateComponents?) -> [Int?]? { c.map { [$0.year, $0.month, $0.day, $0.hour, $0.minute] } }
    static func comps(_ a: [Int?]?) -> DateComponents? {
        guard let a, a.count == 5 else { return nil }
        var c = DateComponents(); c.year = a[0]; c.month = a[1]; c.day = a[2]; c.hour = a[3]; c.minute = a[4]; return c
    }
    open var startDateComponents: DateComponents? { get { Self.comps(i.startComps) } set { i.startComps = Self.comps(newValue) } }
    open var dueDateComponents: DateComponents? { get { Self.comps(i.due) } set { i.due = Self.comps(newValue) } }
    open var isCompleted: Bool {
        get { i.completed }
        set { i.completed = newValue; i.completedAt = newValue ? Date().timeIntervalSince1970 : nil }
    }
    open var completionDate: Date? {
        get { i.completedAt.map(Date.init(timeIntervalSince1970:)) }
        set { i.completedAt = newValue?.timeIntervalSince1970; i.completed = newValue != nil }
    }
    open var priority: Int { get { i.priority } set { i.priority = newValue } }
    var dueDate: Date? { dueDateComponents.flatMap { Calendar.current.date(from: $0) } }
}

// MARK: - Store

open class EKEventStore: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    public init(sources: [EKSource]) { super.init() }
    open var eventStoreIdentifier: String { "isim-event-store" }

    open class func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus { _EKAuth.status(entityType) }

    func request(_ type: EKEntityType, writeOnly: Bool, _ done: @escaping (Bool, Error?) -> Void) {
        let s = _EKAuth.status(type)
        func reply(_ s: EKAuthorizationStatus) {
            let ok = s == .fullAccess || (writeOnly && s == .writeOnly)
            _Privacy.reply { done(ok, nil) }
        }
        if s == .fullAccess || s == .denied || s == .restricted || (s == .writeOnly && writeOnly) { reply(s); return }
        let key = type == .reminder ? "NSRemindersFullAccessUsageDescription" : writeOnly ? "NSCalendarsWriteOnlyAccessUsageDescription" : "NSCalendarsFullAccessUsageDescription"
        guard let purpose = _Privacy.usage(key, "EventKit") else { reply(s); return }
        _Privacy.onMain {
            func answer(_ n: EKAuthorizationStatus) {
                _Privacy.store(_EKAuth.key(type), n.rawValue)
                NSLog("isim EventKit: %@ access %@ for %@", type == .event ? "calendar" : "reminders",
                      n == .fullAccess ? "full" : n == .writeOnly ? "write-only" : "denied", _Privacy.appName)
                reply(n)
            }
            if let sc = _Privacy.scripted(type == .event ? "CALENDAR" : "REMINDERS") {
                switch sc {
                case "deny", "denied", "no", "0": answer(.denied)
                case "writeonly", "write-only": answer(writeOnly || type == .reminder ? (type == .event ? .writeOnly : .fullAccess) : .denied)
                default: answer(writeOnly && type == .event ? .writeOnly : .fullAccess)
                }
                return
            }
            let app = _Privacy.appName
            if type == .reminder {
                _Privacy.alert("“\(app)” Would Like Full Access to Your Reminders", purpose, [("Don’t Allow", .default), ("Allow Full Access", .default)]) { answer($0 == 1 ? .fullAccess : .denied) }
            } else if writeOnly {
                _Privacy.alert("“\(app)” Would Like to Add Events to Your Calendar", purpose, [("Don’t Allow", .default), ("Allow", .default)]) { answer($0 == 1 ? .writeOnly : .denied) }
            } else {
                _Privacy.alert("“\(app)” Would Like Full Access to Your Calendar", purpose, [("Don’t Allow", .default), ("Allow Full Access", .default)]) { answer($0 == 1 ? .fullAccess : .denied) }
            }
        }
    }
    public typealias EKEventStoreRequestAccessCompletionHandler = (Bool, Error?) -> Void
    open func requestFullAccessToEvents(completion: @escaping EKEventStoreRequestAccessCompletionHandler) { request(.event, writeOnly: false, completion) }
    open func requestWriteOnlyAccessToEvents(completion: @escaping EKEventStoreRequestAccessCompletionHandler) { request(.event, writeOnly: true, completion) }
    open func requestFullAccessToReminders(completion: @escaping EKEventStoreRequestAccessCompletionHandler) { request(.reminder, writeOnly: false, completion) }
    @available(*, deprecated, message: "Use requestFullAccessToEvents or requestFullAccessToReminders")
    open func requestAccess(to entityType: EKEntityType, completion: @escaping EKEventStoreRequestAccessCompletionHandler) { request(entityType, writeOnly: false, completion) }
    private func awaitAccess(_ t: EKEntityType, _ w: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Bool, Error>) in request(t, writeOnly: w) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    open func requestFullAccessToEvents() async throws -> Bool { try await awaitAccess(.event, false) }
    open func requestWriteOnlyAccessToEvents() async throws -> Bool { try await awaitAccess(.event, true) }
    open func requestFullAccessToReminders() async throws -> Bool { try await awaitAccess(.reminder, false) }
    open func requestAccess(to entityType: EKEntityType) async throws -> Bool { try await awaitAccess(entityType, false) }

    // MARK: calendars
    open var sources: [EKSource] { [EKSource()] }
    open func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        guard _EKAuth.canRead(entityType) else { return [] }
        return _EKStore.load().calendars.filter { $0.type == entityType.rawValue }.map { EKCalendar($0) }
    }
    open var defaultCalendarForNewEvents: EKCalendar? {
        guard _EKAuth.canWrite(.event) else { return nil }
        return _EKStore.load().calendars.first { $0.id == "isim-calendar-default" }.map { EKCalendar($0) }
    }
    open func defaultCalendarForNewReminders() -> EKCalendar? {
        guard _EKAuth.canWrite(.reminder) else { return nil }
        return _EKStore.load().calendars.first { $0.id == "isim-reminders-default" }.map { EKCalendar($0) }
    }
    open func calendar(withIdentifier identifier: String) -> EKCalendar? {
        guard _EKAuth.canRead(.event) || _EKAuth.canRead(.reminder) else { return nil }
        return _EKStore.load().calendars.first { $0.id == identifier }.map { EKCalendar($0) }
    }
    open func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        let t = EKEntityType(rawValue: calendar.c.type) ?? .event
        guard _EKAuth.canRead(t) else { throw EKError(.eventStoreNotAuthorized) }
        var db = _EKStore.load()
        if let i = db.calendars.firstIndex(where: { $0.id == calendar.c.id }) { db.calendars[i] = calendar.c } else { db.calendars.append(calendar.c) }
        _EKStore.save(db); changed()
    }
    open func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        let t = EKEntityType(rawValue: calendar.c.type) ?? .event
        guard _EKAuth.canRead(t) else { throw EKError(.eventStoreNotAuthorized) }
        var db = _EKStore.load()
        db.calendars.removeAll { $0.id == calendar.c.id }; db.items.removeAll { $0.calendar == calendar.c.id }
        _EKStore.save(db); changed()
    }

    // MARK: items
    func changed() { DispatchQueue.main.async { NotificationCenter.default.post(name: .EKEventStoreChanged, object: self) } }
    func put(_ item: EKCalendarItem, _ type: EKEntityType) throws {
        guard _EKAuth.canWrite(type) else { throw EKError(.eventStoreNotAuthorized) }
        if let e = item as? EKEvent {
            guard e.i.start != nil else { throw EKError(.noStartDate) }
            guard e.i.end != nil else { throw EKError(.noEndDate) }
            if e.i.end! < e.i.start! { throw EKError(.datesInverted) }
        }
        var db = _EKStore.load()
        if item.i.calendar.isEmpty || !db.calendars.contains(where: { $0.id == item.i.calendar }) { throw EKError(.noCalendar) }
        if db.calendars.first(where: { $0.id == item.i.calendar })?.type != type.rawValue {
            throw EKError(type == .event ? .calendarDoesNotAllowEvents : .calendarDoesNotAllowReminders)
        }
        var it = item.i
        let now = Date().timeIntervalSince1970
        if it.created == 0 { it.created = now }
        it.modified = now; it.app = _Privacy.bundleID
        item.i = it
        if let k = db.items.firstIndex(where: { $0.id == it.id }) { db.items[k] = it } else { db.items.append(it) }
        _EKStore.save(db); changed()
    }
    func drop(_ item: EKCalendarItem, _ type: EKEntityType) throws {
        guard _EKAuth.canRead(type) else { throw EKError(.eventStoreNotAuthorized) }
        var db = _EKStore.load()
        db.items.removeAll { $0.id == item.i.id }
        _EKStore.save(db); changed()
    }
    open func save(_ event: EKEvent, span: EKSpan) throws { try put(event, .event) }
    open func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws { try put(event, .event) }
    open func remove(_ event: EKEvent, span: EKSpan) throws { try drop(event, .event) }
    open func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws { try drop(event, .event) }
    open func save(_ reminder: EKReminder, commit: Bool) throws { try put(reminder, .reminder) }
    open func remove(_ reminder: EKReminder, commit: Bool) throws { try drop(reminder, .reminder) }
    open func commit() throws {}
    open func reset() {}
    open func refreshSourcesIfNecessary() {}

    open func calendarItem(withIdentifier identifier: String) -> EKCalendarItem? {
        guard let i = _EKStore.load().items.first(where: { $0.id == identifier }), _EKAuth.canRead(EKEntityType(rawValue: i.kind) ?? .event) else { return nil }
        return i.kind == 0 ? EKEvent(i) : EKReminder(i)
    }
    open func event(withIdentifier identifier: String) -> EKEvent? { calendarItem(withIdentifier: identifier) as? EKEvent }

    // MARK: predicates
    open func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        let ids = calendars.map { Set($0.map(\.calendarIdentifier)) }
        let a = startDate.timeIntervalSince1970, b = endDate.timeIntervalSince1970
        return NSPredicate { obj, _ in
            guard let e = obj as? EKEvent, let s = e.i.start, let en = e.i.end else { return false }
            return s < b && en > a && (ids?.contains(e.i.calendar) ?? true)
        }
    }
    open func events(matching predicate: NSPredicate) -> [EKEvent] {
        guard _EKAuth.canRead(.event) else { return [] }
        return _EKStore.load().items.filter { $0.kind == 0 }.map { EKEvent($0) }.filter { predicate.evaluate(with: $0) }
            .sorted { ($0.i.start ?? 0) < ($1.i.start ?? 0) }
    }
    open func enumerateEvents(matching predicate: NSPredicate, using block: (EKEvent, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        for e in events(matching: predicate) { block(e, &stop); if stop.boolValue { break } }
    }
    open func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        let ids = calendars.map { Set($0.map(\.calendarIdentifier)) }
        return NSPredicate { obj, _ in guard let r = obj as? EKReminder else { return false }; return ids?.contains(r.i.calendar) ?? true }
    }
    open func predicateForIncompleteReminders(withDueDateStarting startDate: Date?, ending endDate: Date?, calendars: [EKCalendar]?) -> NSPredicate {
        let base = predicateForReminders(in: calendars)
        return NSPredicate { obj, _ in
            guard let r = obj as? EKReminder, base.evaluate(with: r), !r.isCompleted else { return false }
            if startDate == nil && endDate == nil { return true }
            guard let d = r.dueDate else { return false }
            return (startDate.map { d >= $0 } ?? true) && (endDate.map { d < $0 } ?? true)
        }
    }
    open func predicateForCompletedReminders(withCompletionDateStarting startDate: Date?, ending endDate: Date?, calendars: [EKCalendar]?) -> NSPredicate {
        let base = predicateForReminders(in: calendars)
        return NSPredicate { obj, _ in
            guard let r = obj as? EKReminder, base.evaluate(with: r), r.isCompleted else { return false }
            guard let d = r.completionDate else { return startDate == nil && endDate == nil }
            return (startDate.map { d >= $0 } ?? true) && (endDate.map { d < $0 } ?? true)
        }
    }
    @discardableResult
    open func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        let ok = _EKAuth.canRead(.reminder)
        let list = ok ? _EKStore.load().items.filter { $0.kind == 1 }.map { EKReminder($0) }.filter { predicate.evaluate(with: $0) } : []
        _Privacy.reply { completion(ok ? list : nil) }
        return NSObject()
    }
    open func cancelFetchRequest(_ fetchIdentifier: Any) {}
}

// used by isim's EventKitUI: the edit controller runs outside the app's calendar permission (iOS 17+)
extension EKEventStore {
    @_spi(isim) public func _isimSaveWithoutAccess(_ event: EKEvent) throws {
        var db = _EKStore.load()
        if event.i.calendar.isEmpty { event.i.calendar = "isim-calendar-default" }
        let now = Date().timeIntervalSince1970
        if event.i.created == 0 { event.i.created = now }
        event.i.modified = now; event.i.app = _Privacy.bundleID
        if let k = db.items.firstIndex(where: { $0.id == event.i.id }) { db.items[k] = event.i } else { db.items.append(event.i) }
        _EKStore.save(db); changed()
    }
}
