// isim EventKit for Objective-C (sdk-src/Frameworks/EventKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors.
import Foundation

extension EKObject {
    @objc(hasChanges) var _objc_hasChanges: Bool { hasChanges }
    @objc(isNew) func _objc_isNew() -> Bool { isNew() }
    @objc(reset) func _objc_reset() { reset() }
    @objc(rollback) func _objc_rollback() { rollback() }
    @objc(refresh) func _objc_refresh() -> Bool { refresh() }
}

extension EKSource {
    @objc(sourceIdentifier) var _objc_sourceIdentifier: String { sourceIdentifier }
    @objc(sourceType) var _objc_sourceType: EKSourceType { sourceType }
    @objc(title) var _objc_title: String { title }
    @objc(calendarsForEntityType:) func _objc_calendars(_ t: EKEntityType) -> Set<EKCalendar> { calendars(for: t) }
}

extension EKCalendar {
    @objc(calendarForEntityType:eventStore:) class func _objc_calendar(_ t: EKEntityType, eventStore: EKEventStore) -> EKCalendar {
        EKCalendar(for: t, eventStore: eventStore)
    }
    @objc(calendarIdentifier) var _objc_calendarIdentifier: String { calendarIdentifier }
    @objc(title) var _objc_title: String { get { title } set { title = newValue } }
    @objc(type) var _objc_type: EKCalendarType { type }
    @objc(allowsContentModifications) var _objc_allowsContentModifications: Bool { allowsContentModifications }
    @objc(isSubscribed) var _objc_isSubscribed: Bool { isSubscribed }
    @objc(isImmutable) var _objc_isImmutable: Bool { isImmutable }
    @objc(source) var _objc_source: EKSource? { get { source } set { source = newValue } }
    @objc(allowedEntityTypes) var _objc_allowedEntityTypes: UInt { allowedEntityTypes.rawValue }
}

extension EKAlarm {
    @objc(alarmWithRelativeOffset:) class func _objc_alarm(_ offset: TimeInterval) -> EKAlarm { EKAlarm(relativeOffset: offset) }
    @objc(alarmWithAbsoluteDate:) class func _objc_alarm(_ date: Date) -> EKAlarm { EKAlarm(absoluteDate: date) }
    @objc(relativeOffset) var _objc_relativeOffset: TimeInterval { get { relativeOffset } set { relativeOffset = newValue } }
    @objc(absoluteDate) var _objc_absoluteDate: Date? { get { absoluteDate } set { absoluteDate = newValue } }
}

extension EKRecurrenceEnd {
    @objc(recurrenceEndWithEndDate:) class func _objc_end(_ date: Date) -> EKRecurrenceEnd { EKRecurrenceEnd(end: date) }
    @objc(recurrenceEndWithOccurrenceCount:) class func _objc_end(_ count: Int) -> EKRecurrenceEnd { EKRecurrenceEnd(occurrenceCount: count) }
    @objc(endDate) var _objc_endDate: Date? { endDate }
    @objc(occurrenceCount) var _objc_occurrenceCount: Int { occurrenceCount }
}

extension EKRecurrenceRule {
    @objc(initRecurrenceWithFrequency:interval:end:) convenience init(_objcFrequency f: EKRecurrenceFrequency, interval: Int, end: EKRecurrenceEnd?) {
        self.init(recurrenceWith: f, interval: interval, end: end)
    }
    @objc(frequency) var _objc_frequency: EKRecurrenceFrequency { frequency }
    @objc(interval) var _objc_interval: Int { interval }
    @objc(recurrenceEnd) var _objc_recurrenceEnd: EKRecurrenceEnd? { get { recurrenceEnd } set { recurrenceEnd = newValue } }
}

extension EKCalendarItem {
    @objc(calendarItemIdentifier) var _objc_calendarItemIdentifier: String { calendarItemIdentifier }
    @objc(calendarItemExternalIdentifier) var _objc_calendarItemExternalIdentifier: String? { calendarItemExternalIdentifier }
    @objc(calendar) var _objc_calendar: EKCalendar? { get { calendar } set { calendar = newValue } }
    @objc(title) var _objc_title: String? { get { title } set { title = newValue } }
    @objc(location) var _objc_location: String? { get { location } set { location = newValue } }
    @objc(notes) var _objc_notes: String? { get { notes } set { notes = newValue } }
    @objc(URL) var _objc_url: URL? { get { url } set { url = newValue } }
    @objc(timeZone) var _objc_timeZone: TimeZone? { get { timeZone } set { timeZone = newValue } }
    @objc(hasNotes) var _objc_hasNotes: Bool { hasNotes }
    @objc(hasAlarms) var _objc_hasAlarms: Bool { hasAlarms }
    @objc(hasRecurrenceRules) var _objc_hasRecurrenceRules: Bool { hasRecurrenceRules }
    @objc(creationDate) var _objc_creationDate: Date? { creationDate }
    @objc(lastModifiedDate) var _objc_lastModifiedDate: Date? { lastModifiedDate }
    @objc(alarms) var _objc_alarms: [EKAlarm]? { get { alarms } set { alarms = newValue } }
    @objc(addAlarm:) func _objc_addAlarm(_ a: EKAlarm) { addAlarm(a) }
    @objc(removeAlarm:) func _objc_removeAlarm(_ a: EKAlarm) { removeAlarm(a) }
    @objc(recurrenceRules) var _objc_recurrenceRules: [EKRecurrenceRule]? { get { recurrenceRules } set { recurrenceRules = newValue } }
    @objc(addRecurrenceRule:) func _objc_addRecurrenceRule(_ r: EKRecurrenceRule) { addRecurrenceRule(r) }
    @objc(removeRecurrenceRule:) func _objc_removeRecurrenceRule(_ r: EKRecurrenceRule) { removeRecurrenceRule(r) }
}

extension EKEvent {
    @objc(eventWithEventStore:) class func _objc_event(_ store: EKEventStore) -> EKEvent { EKEvent(eventStore: store) }
    @objc(eventIdentifier) var _objc_eventIdentifier: String? { eventIdentifier }
    @objc(startDate) var _objc_startDate: Date? { get { startDate } set { startDate = newValue } }
    @objc(endDate) var _objc_endDate: Date? { get { endDate } set { endDate = newValue } }
    @objc(isAllDay) var _objc_isAllDay: Bool { get { isAllDay } set { isAllDay = newValue } }
    @objc(setAllDay:) func _objc_setAllDay(_ v: Bool) { isAllDay = v }
    @objc(availability) var _objc_availability: EKEventAvailability { get { availability } set { availability = newValue } }
    @objc(status) var _objc_status: EKEventStatus { status }
    @objc(isDetached) var _objc_isDetached: Bool { isDetached }
    @objc(occurrenceDate) var _objc_occurrenceDate: Date? { occurrenceDate }
    @objc(compareStartDateWithEvent:) func _objc_compare(_ other: EKEvent) -> ComparisonResult { compareStartDate(with: other) }
}

extension EKReminder {
    @objc(reminderWithEventStore:) class func _objc_reminder(_ store: EKEventStore) -> EKReminder { EKReminder(eventStore: store) }
    @objc(startDateComponents) var _objc_startDateComponents: DateComponents? { get { startDateComponents } set { startDateComponents = newValue } }
    @objc(dueDateComponents) var _objc_dueDateComponents: DateComponents? { get { dueDateComponents } set { dueDateComponents = newValue } }
    @objc(isCompleted) var _objc_isCompleted: Bool { get { isCompleted } set { isCompleted = newValue } }
    @objc(setCompleted:) func _objc_setCompleted(_ v: Bool) { isCompleted = v }
    @objc(completionDate) var _objc_completionDate: Date? { get { completionDate } set { completionDate = newValue } }
    @objc(priority) var _objc_priority: Int { get { priority } set { priority = newValue } }
}

extension EKEventStore {
    @objc(authorizationStatusForEntityType:) class func _objc_status(_ t: EKEntityType) -> EKAuthorizationStatus { authorizationStatus(for: t) }
    @objc(eventStoreIdentifier) var _objc_eventStoreIdentifier: String { eventStoreIdentifier }
    @objc(requestFullAccessToEventsWithCompletion:)
    func _objc_requestFullAccessToEvents(_ completion: @escaping @convention(block) (Bool, NSError?) -> Void) {
        requestFullAccessToEvents { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(requestWriteOnlyAccessToEventsWithCompletion:)
    func _objc_requestWriteOnlyAccessToEvents(_ completion: @escaping @convention(block) (Bool, NSError?) -> Void) {
        requestWriteOnlyAccessToEvents { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(requestFullAccessToRemindersWithCompletion:)
    func _objc_requestFullAccessToReminders(_ completion: @escaping @convention(block) (Bool, NSError?) -> Void) {
        requestFullAccessToReminders { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @available(iOS, deprecated: 17.0, message: "Use requestFullAccessToEvents or requestFullAccessToReminders")   // as Apple's
    @objc(requestAccessToEntityType:completion:)
    func _objc_requestAccess(_ t: EKEntityType, completion: @escaping @convention(block) (Bool, NSError?) -> Void) {
        requestAccess(to: t) { ok, e in completion(ok, e.map { $0 as NSError }) }
    }
    @objc(sources) var _objc_sources: [EKSource] { sources }
    @objc(calendarsForEntityType:) func _objc_calendars(_ t: EKEntityType) -> [EKCalendar] { calendars(for: t) }
    @objc(defaultCalendarForNewEvents) var _objc_defaultCalendarForNewEvents: EKCalendar? { defaultCalendarForNewEvents }
    @objc(defaultCalendarForNewReminders) func _objc_defaultCalendarForNewReminders() -> EKCalendar? { defaultCalendarForNewReminders() }
    @objc(calendarWithIdentifier:) func _objc_calendar(_ id: String) -> EKCalendar? { calendar(withIdentifier: id) }
    @objc(saveCalendar:commit:error:) func _objc_saveCalendar(_ c: EKCalendar, commit: Bool) throws { try saveCalendar(c, commit: commit) }
    @objc(removeCalendar:commit:error:) func _objc_removeCalendar(_ c: EKCalendar, commit: Bool) throws { try removeCalendar(c, commit: commit) }
    @objc(saveEvent:span:error:) func _objc_save(_ e: EKEvent, span: EKSpan) throws { try save(e, span: span) }
    @objc(saveEvent:span:commit:error:) func _objc_save(_ e: EKEvent, span: EKSpan, commit: Bool) throws { try save(e, span: span, commit: commit) }
    @objc(removeEvent:span:error:) func _objc_remove(_ e: EKEvent, span: EKSpan) throws { try remove(e, span: span) }
    @objc(removeEvent:span:commit:error:) func _objc_remove(_ e: EKEvent, span: EKSpan, commit: Bool) throws { try remove(e, span: span, commit: commit) }
    @objc(saveReminder:commit:error:) func _objc_save(_ r: EKReminder, commit: Bool) throws { try save(r, commit: commit) }
    @objc(removeReminder:commit:error:) func _objc_remove(_ r: EKReminder, commit: Bool) throws { try remove(r, commit: commit) }
    @objc(commit:) func _objc_commit() throws { try commit() }
    @objc(reset) func _objc_reset() { reset() }
    @objc(refreshSourcesIfNecessary) func _objc_refreshSources() { refreshSourcesIfNecessary() }
    @objc(calendarItemWithIdentifier:) func _objc_calendarItem(_ id: String) -> EKCalendarItem? { calendarItem(withIdentifier: id) }
    @objc(eventWithIdentifier:) func _objc_event(_ id: String) -> EKEvent? { event(withIdentifier: id) }
    @objc(predicateForEventsWithStartDate:endDate:calendars:)
    func _objc_predicateForEvents(_ start: Date, endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        predicateForEvents(withStart: start, end: endDate, calendars: calendars)
    }
    @objc(eventsMatchingPredicate:) func _objc_events(_ p: NSPredicate) -> [EKEvent] { events(matching: p) }
    @objc(enumerateEventsMatchingPredicate:usingBlock:)
    func _objc_enumerateEvents(_ p: NSPredicate, usingBlock block: (EKEvent, UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateEvents(matching: p, using: block)
    }
    @objc(predicateForRemindersInCalendars:) func _objc_predicateForReminders(_ c: [EKCalendar]?) -> NSPredicate { predicateForReminders(in: c) }
    @objc(predicateForIncompleteRemindersWithDueDateStarting:ending:calendars:)
    func _objc_incomplete(_ start: Date?, ending: Date?, calendars: [EKCalendar]?) -> NSPredicate {
        predicateForIncompleteReminders(withDueDateStarting: start, ending: ending, calendars: calendars)
    }
    @objc(predicateForCompletedRemindersWithCompletionDateStarting:ending:calendars:)
    func _objc_completed(_ start: Date?, ending: Date?, calendars: [EKCalendar]?) -> NSPredicate {
        predicateForCompletedReminders(withCompletionDateStarting: start, ending: ending, calendars: calendars)
    }
    @objc(fetchRemindersMatchingPredicate:completion:)
    func _objc_fetchReminders(_ p: NSPredicate, completion: @escaping @convention(block) ([EKReminder]?) -> Void) -> Any {
        fetchReminders(matching: p) { completion($0) }
    }
    @objc(cancelFetchRequest:) func _objc_cancelFetch(_ id: Any) { cancelFetchRequest(id) }
}
