// isim HomeKit: scenes (action sets) and automations (triggers). A home hub runs them on iOS; isim runs them in the app
// while it runs (adapted): timer triggers at their fire date and recurrence, event triggers when a characteristic
// changes (characteristic and threshold events, with their predicate) and at calendar events. Significant time,
// location, presence and duration events are kept but never fire (isim has no people or sun to watch).
import Foundation
import CoreLocation

// MARK: - actions

@objc(HMAction)
open class HMAction: NSObject {
    var _id: String
    @objc override init() { _id = UUID().uuidString; super.init() }
    init(_id: String) { self._id = _id; super.init() }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }

    // for Objective-C's HMCharacteristicWriteAction (HomeKit.framework)
    @objc(_isim_setIdentifier:) func _isimSetIdentifier(_ id: String) { _id = id }
    @objc(_isim_updateTargetValue:characteristic:completionHandler:)
    func _isimUpdate(_ value: Any, characteristic: HMCharacteristic, completionHandler completion: @escaping (Error?) -> Void) {
        guard let r = characteristic._rec else { _hmReply { completion(_hmErr(.notFound)) }; return }
        if let e = _HMCharacteristics.validate(r, value) { _hmReply { completion(e) }; return }
        let v = _HMValue.from(value, format: r.format)!
        _HMAutomation.updateAction(_id) { $0.value = v }
        _hmReply { completion(nil) }
    }

    /// (characteristic, value) of a write action, Swift's or Objective-C's
    var _write: (HMCharacteristic, Any)? {
        if let w = self as? _HMWriteAction { return (w._characteristic, w._value) }
        guard let c = value(forKey: "characteristic") as? HMCharacteristic, let v = value(forKey: "targetValue") else { return nil }
        return (c, v)
    }
}

protocol _HMWriteAction: AnyObject {
    var _characteristic: HMCharacteristic { get }
    var _value: Any { get }
}

open class HMCharacteristicWriteAction<TargetValueType: NSCopying>: HMAction, _HMWriteAction {
    private var _target: TargetValueType
    private let _char: HMCharacteristic
    public init(characteristic: HMCharacteristic, targetValue: TargetValueType) {
        _char = characteristic
        _target = targetValue
        super.init()
    }
    init(_id: String, characteristic: HMCharacteristic, targetValue: TargetValueType) {
        _char = characteristic
        _target = targetValue
        super.init(_id: _id)
    }
    open var characteristic: HMCharacteristic { _char }
    open var targetValue: TargetValueType { _target }
    var _characteristic: HMCharacteristic { _char }
    var _value: Any { _target }

    open func updateTargetValue(_ targetValue: TargetValueType, completionHandler completion: @escaping (Error?) -> Void) {
        guard let r = _char._rec else { _hmReply { completion(_hmErr(.notFound)) }; return }
        if let e = _HMCharacteristics.validate(r, targetValue) { _hmReply { completion(e) }; return }
        _target = targetValue
        let v = _HMValue.from(targetValue, format: r.format)!
        _HMAutomation.updateAction(_id) { $0.value = v }
        _hmReply { completion(nil) }
    }
}

// MARK: - action sets

enum _HMActionSet {
    static func builtinName(_ type: String) -> String {
        switch type {
        case "HMActionSetTypeWakeUp": return "Good Morning"
        case "HMActionSetTypeSleep": return "Good Night"
        case "HMActionSetTypeHomeDeparture": return "Leave Home"
        case "HMActionSetTypeHomeArrival": return "Arrive Home"
        default: return type
        }
    }
}

@objc(HMActionSet)
open class HMActionSet: NSObject {
    let _id: String
    init(_id: String) { self._id = _id; super.init() }

    private var _where: (Int, Int)? {
        for (i, h) in _HMStore.shared.data.homes.enumerated() { if let s = h.actionSets.firstIndex(where: { $0.id == _id }) { return (i, s) } }
        return nil
    }
    var _rec: _HMActionSetRec? { _where.map { _HMStore.shared.data.homes[$0.0].actionSets[$0.1] } }

    @objc public var name: String { _rec?.name ?? "" }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    @objc public var actionSetType: String { _rec?.type ?? "HMActionSetTypeUserDefined" }
    @objc public var actions: Set<HMAction> { Set((_rec?.actions ?? []).compactMap { _HMAutomation.action($0) }) }
    @objc(isExecuting) public var isExecuting: Bool { _HMAutomation.executing.contains(_id) }
    @objc public var lastExecutionDate: Date? { _rec?.lastExecution }

    private func _change(_ completion: @escaping (Error?) -> Void, _ check: (_HMHomeRec, _HMActionSetRec) -> NSError?, _ body: (inout _HMActionSetRec) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard let (h, s) = _where else { _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return }
        let home = _HMStore.shared.data.homes[h]
        if let e = check(home, home.actionSets[s]) { _hmReply { completion(e) }; return }
        _HMStore.shared.modify { body(&$0.homes[h].actionSets[s]) }
        _HMStore.shared.save()
        _hmReply { completion(nil) }
    }

    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { h, _ in _hmNameError(name, taken: h.actionSets.filter { $0.id != self._id }.map(\.name)) }) { $0.name = name }
    }

    @objc(addAction:completionHandler:)
    open func addAction(_ action: HMAction, completionHandler completion: @escaping (Error?) -> Void) {
        guard let (c, value) = action._write, let r = c._rec else { _hmReply { completion(_hmErr(.invalidClass)) }; return }
        var rec: _HMActionRec?
        _change(completion, { h, set in
            guard h.accessories.contains(where: { $0.services.contains { $0.characteristics.contains { $0.id == c._id } } }) else {
                return _hmErr(.objectAssociatedToAnotherHome)
            }
            if set.actions.contains(where: { $0.id == action._id }) { return _hmErr(.alreadyExists) }
            if set.actions.contains(where: { $0.characteristic == c._id }) { return _hmErr(.actionInAnotherActionSet, "The action set already writes this characteristic.") }
            if let e = _HMCharacteristics.validate(r, value) { return e }
            rec = _HMActionRec(id: action._id, characteristic: c._id, value: _HMValue.from(value, format: r.format)!)
            return nil
        }) { if let rec { $0.actions.append(rec) } }
        _HMObjects.shared.register(action, action._id)
    }

    @objc(removeAction:completionHandler:)
    open func removeAction(_ action: HMAction, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { _, s in s.actions.contains { $0.id == action._id } ? nil : _hmErr(.notFound) }) { $0.actions.removeAll { $0.id == action._id } }
    }
}

// MARK: - triggers

@objc(HMTrigger)
open class HMTrigger: NSObject {
    var _record: _HMTriggerRec
    var _home: String?
    init(_record: _HMTriggerRec, home: String?) { self._record = _record; _home = home; super.init() }

    var _id: String { _record.id }
    /// the stored trigger once it is in a home, else the app's copy
    var _rec: _HMTriggerRec {
        if let h = _home, let t = _HMStore.shared.home(h)?.triggers.first(where: { $0.id == _id }) { return t }
        return _record
    }
    func _modify(_ body: (inout _HMTriggerRec) -> Void) {
        body(&_record)
        guard let h = _home else { return }
        _HMStore.shared.modify { d in
            guard let i = d.homes.firstIndex(where: { $0.id == h }), let t = d.homes[i].triggers.firstIndex(where: { $0.id == _id }) else { return }
            body(&d.homes[i].triggers[t])
        }
        _HMStore.shared.save()
    }
    /// a change of an added trigger (triggers not in a home cannot change: objectNotAssociatedToAnyHome)
    func _change(_ completion: @escaping (Error?) -> Void, _ check: () -> NSError? = { nil }, _ body: (inout _HMTriggerRec) -> Void) {
        if let e = _HMAccess.denied { _hmReply { completion(e) }; return }
        guard _home != nil else { _hmReply { completion(_hmErr(.objectNotAssociatedToAnyHome)) }; return }
        if let e = check() { _hmReply { completion(e) }; return }
        _modify(body)
        _hmReply { completion(nil) }
    }

    @objc public var name: String { _rec.name }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    @objc(isEnabled) public var isEnabled: Bool { _rec.enabled }
    @objc public var actionSets: [HMActionSet] { _rec.actionSets.map { _HMObjects.shared.actionSet($0) } }
    @available(iOS, introduced: 8.0, deprecated: 17.0)
    @objc public var lastFireDate: Date? { _rec.lastFire }

    @objc(updateName:completionHandler:)
    open func updateName(_ name: String, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { _hmNameError(name, taken: []) }) { $0.name = name }
    }
    @objc(addActionSet:completionHandler:)
    open func addActionSet(_ actionSet: HMActionSet, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, {
            guard let h = self._home, _HMStore.shared.home(h)?.actionSets.contains(where: { $0.id == actionSet._id }) == true else {
                return _hmErr(.objectAssociatedToAnotherHome)
            }
            return self._rec.actionSets.contains(actionSet._id) ? _hmErr(.alreadyExists) : nil
        }) { $0.actionSets.append(actionSet._id) }
    }
    @objc(removeActionSet:completionHandler:)
    open func removeActionSet(_ actionSet: HMActionSet, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { self._rec.actionSets.contains(actionSet._id) ? nil : _hmErr(.notFound) }) { $0.actionSets.removeAll { $0 == actionSet._id } }
    }
    @objc(enable:completionHandler:)
    open func enable(_ enable: Bool, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, {
            if enable, self._rec.actionSets.isEmpty { return _hmErr(.noActionsInActionSet, "The trigger has no action sets.") }
            if enable, self._rec.kind == "event", let h = self._home, _HMStore.shared.home(h)?.hub != true { return _hmErr(.noHomeHub) }
            return nil
        }) { $0.enabled = enable }
    }
}

func _hmComponents(_ c: DateComponents?) -> [String: Int]? {
    guard let c else { return nil }
    var d: [String: Int] = [:]
    if let v = c.year { d["year"] = v }; if let v = c.month { d["month"] = v }; if let v = c.day { d["day"] = v }
    if let v = c.weekday { d["weekday"] = v }; if let v = c.hour { d["hour"] = v }; if let v = c.minute { d["minute"] = v }
    if let v = c.second { d["second"] = v }; if let v = c.weekOfYear { d["weekOfYear"] = v }
    return d
}
func _hmComponents(_ d: [String: Int]?) -> DateComponents? {
    guard let d else { return nil }
    var c = DateComponents()
    c.year = d["year"]; c.month = d["month"]; c.day = d["day"]; c.weekday = d["weekday"]; c.hour = d["hour"]; c.minute = d["minute"]
    c.second = d["second"]; c.weekOfYear = d["weekOfYear"]
    return c
}

@objc(HMTimerTrigger)
open class HMTimerTrigger: HMTrigger {
    @objc(initWithName:fireDate:recurrence:)
    public init(name: String, fireDate: Date, recurrence: DateComponents?) {
        super.init(_record: Self._make(name, fireDate, nil, recurrence), home: nil)
    }
    @available(iOS, introduced: 8.0, deprecated: 16.4, message: "Use init(name:fireDate:recurrence:)")
    @objc(initWithName:fireDate:timeZone:recurrence:recurrenceCalendar:)
    public init(name: String, fireDate: Date, timeZone: TimeZone?, recurrence: DateComponents?, recurrenceCalendar: Calendar?) {
        super.init(_record: Self._make(name, fireDate, timeZone, recurrence), home: nil)
    }
    static func _make(_ name: String, _ fireDate: Date, _ timeZone: TimeZone?, _ recurrence: DateComponents?) -> _HMTriggerRec {
        _HMTriggerRec(id: UUID().uuidString, name: name, kind: "timer", enabled: false, actionSets: [],
                      fireDate: Date(timeIntervalSince1970: (fireDate.timeIntervalSince1970 / 60).rounded(.down) * 60),
                      recurrence: _hmComponents(recurrence), timeZone: timeZone?.identifier)
    }
    init(_rec: _HMTriggerRec, home: String?) { super.init(_record: _rec, home: home) }

    @objc public var fireDate: Date { _rec.fireDate ?? Date.distantFuture }
    @available(iOS, introduced: 8.0, deprecated: 16.4)
    @objc public var timeZone: TimeZone? { _rec.timeZone.flatMap { TimeZone(identifier: $0) } }
    @objc public var recurrence: DateComponents? { _hmComponents(_rec.recurrence) }
    @available(iOS, introduced: 8.0, deprecated: 16.4)
    @objc public var recurrenceCalendar: Calendar? { Calendar.current }

    @objc(updateFireDate:completionHandler:)
    open func updateFireDate(_ fireDate: Date, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { fireDate < Date() && self.recurrence == nil ? _hmErr(.fireDateInPast) : nil }) {
            $0.fireDate = Date(timeIntervalSince1970: (fireDate.timeIntervalSince1970 / 60).rounded(.down) * 60)
            $0.lastFire = nil
        }
    }
    @available(iOS, introduced: 8.0, deprecated: 16.4)
    @objc(updateTimeZone:completionHandler:)
    open func updateTimeZone(_ timeZone: TimeZone?, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion) { $0.timeZone = timeZone?.identifier }
    }
    @objc(updateRecurrence:completionHandler:)
    open func updateRecurrence(_ recurrence: DateComponents?, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, {
            guard let r = recurrence else { return nil }
            let minutes = (r.minute ?? 0) + (r.hour ?? 0) * 60
            if minutes > 0 && minutes < 5 && r.day == nil && r.weekOfYear == nil { return _hmErr(.recurrenceTooSmall) }
            return nil
        }) { $0.recurrence = _hmComponents(recurrence) }
    }
}

@objc(HMEventTrigger)
open class HMEventTrigger: HMTrigger {
    @objc(initWithName:events:predicate:)
    public convenience init(name: String, events: [HMEvent], predicate: NSPredicate?) {
        self.init(name: name, events: events, endEvents: nil, recurrences: nil, predicate: predicate)
    }
    public convenience init(name: String, events: [HMEvent], end endEvents: [HMEvent]?, recurrences: [DateComponents]?, predicate: NSPredicate?) {
        self.init(name: name, events: events, endEvents: endEvents, recurrences: recurrences, predicate: predicate)
    }
    @objc(initWithName:events:endEvents:recurrences:predicate:)
    public init(name: String, events: [HMEvent], endEvents: [HMEvent]?, recurrences: [DateComponents]?, predicate: NSPredicate?) {
        for e in events + (endEvents ?? []) { _HMObjects.shared.register(e, e._id) }
        super.init(_record: _HMTriggerRec(id: UUID().uuidString, name: name, kind: "event", enabled: false, actionSets: [],
                                          events: events.map(\._record), endEvents: endEvents?.map(\._record),
                                          recurrences: recurrences?.compactMap { _hmComponents($0) }, predicate: predicate?.predicateFormat,
                                          executeOnce: false), home: nil)
    }
    init(_rec: _HMTriggerRec, home: String?) { super.init(_record: _rec, home: home) }

    @objc public var events: [HMEvent] { (_rec.events ?? []).map { _HMAutomation.event($0) } }
    @objc public var endEvents: [HMEvent] { (_rec.endEvents ?? []).map { _HMAutomation.event($0) } }
    @objc public var predicate: NSPredicate? { _rec.predicate.flatMap { _HMAutomation.predicate($0) } }
    @objc public var recurrences: [DateComponents]? { _rec.recurrences?.compactMap { _hmComponents($0) } }
    @objc public var executeOnce: Bool { _rec.executeOnce == true }
    @objc public var triggerActivationState: HMEventTriggerActivationState {
        guard _rec.enabled else { return .disabled }
        guard let h = _home, _HMStore.shared.home(h)?.hub == true else { return .disabledNoHomeHub }
        return .enabled
    }

    @available(iOS, introduced: 9.0, deprecated: 11.0)
    @objc(addEvent:completionHandler:)
    open func addEvent(_ event: HMEvent, completionHandler completion: @escaping (Error?) -> Void) {
        _HMObjects.shared.register(event, event._id)
        _change(completion) { $0.events = ($0.events ?? []) + [event._record] }
    }
    @available(iOS, introduced: 9.0, deprecated: 11.0)
    @objc(removeEvent:completionHandler:)
    open func removeEvent(_ event: HMEvent, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion, { (self._rec.events ?? []).contains { $0.id == event._id } ? nil : _hmErr(.notFound) }) { $0.events?.removeAll { $0.id == event._id } }
    }
    @objc(updateEvents:completionHandler:)
    open func updateEvents(_ events: [HMEvent], completionHandler completion: @escaping (Error?) -> Void) {
        for e in events { _HMObjects.shared.register(e, e._id) }
        _change(completion) { $0.events = events.map(\._record) }
    }
    @objc(updateEndEvents:completionHandler:)
    open func updateEndEvents(_ endEvents: [HMEvent], completionHandler completion: @escaping (Error?) -> Void) {
        for e in endEvents { _HMObjects.shared.register(e, e._id) }
        _change(completion) { $0.endEvents = endEvents.map(\._record) }
    }
    @objc(updatePredicate:completionHandler:)
    open func updatePredicate(_ predicate: NSPredicate?, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion) { $0.predicate = predicate?.predicateFormat }
    }
    @objc(updateRecurrences:completionHandler:)
    open func updateRecurrences(_ recurrences: [DateComponents]?, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion) { $0.recurrences = recurrences?.compactMap { _hmComponents($0) } }
    }
    @objc(updateExecuteOnce:completionHandler:)
    open func updateExecuteOnce(_ executeOnce: Bool, completionHandler completion: @escaping (Error?) -> Void) {
        _change(completion) { $0.executeOnce = executeOnce }
    }

    // the predicates (isim's key paths, which _HMAutomation evaluates when the trigger fires)
    static func _minutes(_ c: DateComponents) -> Int { (c.hour ?? 0) * 100 + (c.minute ?? 0) }
    static func _significant(_ e: HMSignificantTimeEvent) -> String {
        let m = (e.offset?.hour ?? 0) * 60 + (e.offset?.minute ?? 0)
        return "isim" + (e.significantEvent.rawValue == "sunrise" ? "Sunrise" : "Sunset") + (m < 0 ? "M\(-m)" : "P\(m)")
    }
    @objc(predicateForEvaluatingTriggerOccurringBeforeSignificantEvent:)
    open class func predicateForEvaluatingTriggerOccurring(beforeSignificantEvent significantEvent: HMSignificantTimeEvent) -> NSPredicate {
        NSPredicate(format: "isimNow < \(_significant(significantEvent))")
    }
    @objc(predicateForEvaluatingTriggerOccurringAfterSignificantEvent:)
    open class func predicateForEvaluatingTriggerOccurring(afterSignificantEvent significantEvent: HMSignificantTimeEvent) -> NSPredicate {
        NSPredicate(format: "isimNow > \(_significant(significantEvent))")
    }
    @objc(predicateForEvaluatingTriggerOccurringBetweenSignificantEvent:secondSignificantEvent:)
    open class func predicate(forEvaluatingTriggerOccurringBetweenSignificantEvent firstSignificantEvent: HMSignificantTimeEvent,
                              secondSignificantEvent: HMSignificantTimeEvent) -> NSPredicate {
        NSPredicate(format: "isimNow > \(_significant(firstSignificantEvent)) AND isimNow < \(_significant(secondSignificantEvent))")
    }
    @available(iOS, introduced: 9.0, deprecated: 11.0)
    @objc(predicateForEvaluatingTriggerOccurringBeforeSignificantEvent:applyingOffset:)
    open class func predicateForEvaluatingTrigger(occurringBefore significantEvent: String, applyingOffset offset: DateComponents?) -> NSPredicate {
        predicateForEvaluatingTriggerOccurring(beforeSignificantEvent: HMSignificantTimeEvent(significantEvent: HMSignificantEvent(rawValue: significantEvent), offset: offset))
    }
    @available(iOS, introduced: 9.0, deprecated: 11.0)
    @objc(predicateForEvaluatingTriggerOccurringAfterSignificantEvent:applyingOffset:)
    open class func predicateForEvaluatingTrigger(occurringAfter significantEvent: String, applyingOffset offset: DateComponents?) -> NSPredicate {
        predicateForEvaluatingTriggerOccurring(afterSignificantEvent: HMSignificantTimeEvent(significantEvent: HMSignificantEvent(rawValue: significantEvent), offset: offset))
    }
    @objc(predicateForEvaluatingTriggerOccurringBeforeDateWithComponents:)
    open class func predicateForEvaluatingTrigger(occurringBefore dateComponents: DateComponents) -> NSPredicate {
        NSPredicate(format: "isimNow < \(_minutes(dateComponents))")
    }
    @objc(predicateForEvaluatingTriggerOccurringOnDateWithComponents:)
    open class func predicateForEvaluatingTrigger(occurringOn dateComponents: DateComponents) -> NSPredicate {
        NSPredicate(format: "isimNow == \(_minutes(dateComponents))")
    }
    @objc(predicateForEvaluatingTriggerOccurringAfterDateWithComponents:)
    open class func predicateForEvaluatingTrigger(occurringAfter dateComponents: DateComponents) -> NSPredicate {
        NSPredicate(format: "isimNow > \(_minutes(dateComponents))")
    }
    @objc(predicateForEvaluatingTriggerOccurringBetweenDateWithComponents:secondDateWithComponents:)
    open class func predicateForEvaluatingTriggerOccurringBetweenDate(with firstDateComponents: DateComponents,
                                                                      secondDateWith secondDateComponents: DateComponents) -> NSPredicate {
        NSPredicate(format: "isimNow > \(_minutes(firstDateComponents)) AND isimNow < \(_minutes(secondDateComponents))")
    }
    @objc(predicateForEvaluatingTriggerWithCharacteristic:relatedBy:toValue:)
    open class func predicateForEvaluatingTrigger(_ characteristic: HMCharacteristic, relatedBy operatorType: NSComparisonPredicate.Operator,
                                                  toValue value: Any) -> NSPredicate {
        NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: _HMAutomation.key(characteristic._id)),
                              rightExpression: NSExpression(forConstantValue: value), modifier: .direct, type: operatorType, options: [])
    }
    @objc(predicateForEvaluatingTriggerWithPresence:)
    open class func predicateForEvaluatingTrigger(withPresence presenceEvent: HMPresenceEvent) -> NSPredicate {
        NSPredicate(format: "isimPresence\(presenceEvent.presenceEventType.rawValue)x\(presenceEvent.presenceUserType.rawValue) == 1")
    }
}

// MARK: - events

@objc(HMEvent)
open class HMEvent: NSObject {
    var _record: _HMEventRec
    var _id: String { _record.id }
    @objc override init() { _record = _HMEventRec(id: UUID().uuidString, kind: "event"); super.init() }
    init(_record: _HMEventRec) { self._record = _record; super.init() }
    @objc public var uniqueIdentifier: UUID { UUID(uuidString: _id) ?? UUID() }
    // for Objective-C's HMCharacteristicEvent (HomeKit.framework)
    @objc(_isim_setCharacteristic:triggerValue:identifier:)
    func _isimSetCharacteristic(_ c: HMCharacteristic, _ value: Any?, _ id: String?) {
        _record.kind = "characteristic"
        _record.characteristic = c._id
        _record.value = value.flatMap { _HMValue.from($0, format: c._rec?.format ?? "") }
        if let id { _record.id = id }
        _HMAutomation.updateEvent(_record)
    }
    /// every kind of event works in isim's homes (some need a home hub on iOS: the seeded home has one)
    @objc(isSupportedForHome:) open class func isSupported(for home: HMHome) -> Bool { true }
}

@objc(HMTimeEvent)
open class HMTimeEvent: HMEvent {}

@objc(HMCalendarEvent)
open class HMCalendarEvent: HMTimeEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMCalendarEvent(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutableCalendarEvent(_record: _record) }
    @objc(initWithFireDateComponents:) public init(fireDateComponents: DateComponents) {
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "calendar", components: _hmComponents(fireDateComponents)))
    }
    public convenience init(fire fireDateComponents: DateComponents) { self.init(fireDateComponents: fireDateComponents) }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    @objc public var fireDateComponents: DateComponents { _hmComponents(_record.components) ?? DateComponents() }
}
@objc(HMMutableCalendarEvent)
open class HMMutableCalendarEvent: HMCalendarEvent {
    @objc public override var fireDateComponents: DateComponents {
        get { super.fireDateComponents }
        set { _record.components = _hmComponents(newValue) }
    }
}

@objc(HMSignificantTimeEvent)
open class HMSignificantTimeEvent: HMTimeEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMSignificantTimeEvent(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutableSignificantTimeEvent(_record: _record) }
    @objc(initWithSignificantEvent:offset:) public init(significantEvent: HMSignificantEvent, offset: DateComponents?) {
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "significant", significant: significantEvent.rawValue, offset: _hmComponents(offset)))
    }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    @objc public var significantEvent: HMSignificantEvent { HMSignificantEvent(rawValue: _record.significant ?? "sunrise") }
    @objc public var offset: DateComponents? { _hmComponents(_record.offset) }
}
@objc(HMMutableSignificantTimeEvent)
open class HMMutableSignificantTimeEvent: HMSignificantTimeEvent {
    @objc public override var significantEvent: HMSignificantEvent {
        get { super.significantEvent }
        set { _record.significant = newValue.rawValue }
    }
    @objc public override var offset: DateComponents? {
        get { super.offset }
        set { _record.offset = _hmComponents(newValue) }
    }
}

@objc(HMDurationEvent)
open class HMDurationEvent: HMTimeEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMDurationEvent(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutableDurationEvent(_record: _record) }
    @objc(initWithDuration:) public init(duration: TimeInterval) {
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "duration", duration: duration))
    }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    @objc public var duration: TimeInterval { _record.duration ?? 0 }
}
@objc(HMMutableDurationEvent)
open class HMMutableDurationEvent: HMDurationEvent {
    @objc public override var duration: TimeInterval {
        get { super.duration }
        set { _record.duration = newValue }
    }
}

open class HMCharacteristicEvent<TriggerValueType: NSCopying>: HMEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMCharacteristicEvent<TriggerValueType>(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutableCharacteristicEvent<TriggerValueType>(_record: _record) }
    public init(characteristic: HMCharacteristic, triggerValue: TriggerValueType?) {
        let format = characteristic._rec?.format ?? ""
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "characteristic", characteristic: characteristic._id,
                                        value: triggerValue.flatMap { _HMValue.from($0, format: format) }))
    }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    open var characteristic: HMCharacteristic { _HMObjects.shared.characteristic(_record.characteristic ?? "") }
    open var triggerValue: TriggerValueType? { _record.value?.object as? TriggerValueType }
    @available(iOS, introduced: 9.0, deprecated: 11.0)
    open func updateTriggerValue(_ triggerValue: TriggerValueType?, completionHandler completion: @escaping (Error?) -> Void) {
        _record.value = triggerValue.flatMap { _HMValue.from($0, format: characteristic._rec?.format ?? "") }
        _HMAutomation.updateEvent(_record)
        _hmReply { completion(nil) }
    }
}
open class HMMutableCharacteristicEvent<TriggerValueType: NSCopying>: HMCharacteristicEvent<TriggerValueType> {
    open override var characteristic: HMCharacteristic {
        get { super.characteristic }
        set { _record.characteristic = newValue._id }
    }
    open override var triggerValue: TriggerValueType? {
        get { super.triggerValue }
        set { _record.value = newValue.flatMap { _HMValue.from($0, format: characteristic._rec?.format ?? "") } }
    }
}

@objc(HMNumberRange)
open class HMNumberRange: NSObject {
    let _min: NSNumber?, _max: NSNumber?
    init(_min: NSNumber?, _max: NSNumber?) { self._min = _min; self._max = _max; super.init() }
    @objc(numberRangeWithMinValue:maxValue:) public class func _make(minValue: NSNumber, maxValue: NSNumber) -> HMNumberRange { HMNumberRange(_min: minValue, _max: maxValue) }
    @objc(numberRangeWithMinValue:) public class func _make(minValue: NSNumber) -> HMNumberRange { HMNumberRange(_min: minValue, _max: nil) }
    @objc(numberRangeWithMaxValue:) public class func _make(maxValue: NSNumber) -> HMNumberRange { HMNumberRange(_min: nil, _max: maxValue) }
    public convenience init(minValue: NSNumber, maxValue: NSNumber) { self.init(_min: minValue, _max: maxValue) }
    public convenience init(minValue: NSNumber) { self.init(_min: minValue, _max: nil) }
    public convenience init(maxValue: NSNumber) { self.init(_min: nil, _max: maxValue) }
    @objc public var minValue: NSNumber? { _min }
    @objc public var maxValue: NSNumber? { _max }
}

@objc(HMCharacteristicThresholdRangeEvent)
open class HMCharacteristicThresholdRangeEvent: HMEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMCharacteristicThresholdRangeEvent(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutableCharacteristicThresholdRangeEvent(_record: _record) }
    @objc(initWithCharacteristic:thresholdRange:) public init(characteristic: HMCharacteristic, thresholdRange: HMNumberRange) {
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "threshold", characteristic: characteristic._id,
                                        min: thresholdRange.minValue?.doubleValue, max: thresholdRange.maxValue?.doubleValue))
    }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    @objc public var characteristic: HMCharacteristic { _HMObjects.shared.characteristic(_record.characteristic ?? "") }
    @objc public var thresholdRange: HMNumberRange { HMNumberRange(_min: _record.min.map { NSNumber(value: $0) }, _max: _record.max.map { NSNumber(value: $0) }) }
}
@objc(HMMutableCharacteristicThresholdRangeEvent)
open class HMMutableCharacteristicThresholdRangeEvent: HMCharacteristicThresholdRangeEvent {
    @objc public override var characteristic: HMCharacteristic {
        get { super.characteristic }
        set { _record.characteristic = newValue._id }
    }
    @objc public override var thresholdRange: HMNumberRange {
        get { super.thresholdRange }
        set { _record.min = newValue.minValue?.doubleValue; _record.max = newValue.maxValue?.doubleValue }
    }
}

@objc(HMLocationEvent)
open class HMLocationEvent: HMEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMLocationEvent(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutableLocationEvent(_record: _record) }
    @objc(initWithRegion:) public init(region: CLRegion) {
        let c = (region as? CLCircularRegion)
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "location", latitude: c?.center.latitude, longitude: c?.center.longitude,
                                        radius: c?.radius, regionID: region.identifier))
    }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    @objc public var region: CLRegion? {
        guard let lat = _record.latitude, let lon = _record.longitude else { return nil }
        return CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: _record.radius ?? 100,
                                identifier: _record.regionID ?? "")
    }
    @available(iOS, introduced: 9.0, deprecated: 11.0)
    @objc(updateRegion:completionHandler:)
    open func updateRegion(_ region: CLRegion, completionHandler completion: @escaping (Error?) -> Void) {
        let c = region as? CLCircularRegion
        _record.latitude = c?.center.latitude; _record.longitude = c?.center.longitude; _record.radius = c?.radius; _record.regionID = region.identifier
        _HMAutomation.updateEvent(_record)
        _hmReply { completion(nil) }
    }
}
@objc(HMMutableLocationEvent)
open class HMMutableLocationEvent: HMLocationEvent {
    @objc public override var region: CLRegion? {
        get { super.region }
        set {
            let c = newValue as? CLCircularRegion
            _record.latitude = c?.center.latitude; _record.longitude = c?.center.longitude; _record.radius = c?.radius; _record.regionID = newValue?.identifier
        }
    }
}

@objc(HMPresenceEvent)
open class HMPresenceEvent: HMEvent, NSCopying, NSMutableCopying {
    open func copy(with zone: NSZone? = nil) -> Any { HMPresenceEvent(_record: _record) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { HMMutablePresenceEvent(_record: _record) }
    @objc(initWithPresenceEventType:presenceUserType:) public init(presenceEventType: HMPresenceEventType, presenceUserType: HMPresenceEventUserType) {
        super.init(_record: _HMEventRec(id: UUID().uuidString, kind: "presence", presenceType: presenceEventType.rawValue, presenceUser: presenceUserType.rawValue))
    }
    override init(_record: _HMEventRec) { super.init(_record: _record) }
    @objc public var presenceEventType: HMPresenceEventType { HMPresenceEventType(rawValue: _record.presenceType ?? 1) ?? .everyEntry }
    @objc public var presenceUserType: HMPresenceEventUserType { HMPresenceEventUserType(rawValue: _record.presenceUser ?? 1) ?? .currentUser }
}
@objc(HMMutablePresenceEvent)
open class HMMutablePresenceEvent: HMPresenceEvent {
    @objc public override var presenceEventType: HMPresenceEventType {
        get { super.presenceEventType }
        set { _record.presenceType = newValue.rawValue }
    }
    @objc public override var presenceUserType: HMPresenceEventUserType {
        get { super.presenceUserType }
        set { _record.presenceUser = newValue.rawValue }
    }
}

// MARK: - running them

/// the value a predicate's isim key paths read when a trigger fires
final class _HMPredicateContext: NSObject {
    override func value(forUndefinedKey key: String) -> Any? {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        if key == "isimNow" { return (now.hour ?? 0) * 100 + (now.minute ?? 0) }
        if key.hasPrefix("isimSunrise") || key.hasPrefix("isimSunset") {
            // isim's sun: rises at 6:30 and sets at 19:30
            let base = key.hasPrefix("isimSunrise") ? 6 * 60 + 30 : 19 * 60 + 30
            let rest = key.dropFirst(key.hasPrefix("isimSunrise") ? 11 : 10)
            let off = (Int(rest.dropFirst()) ?? 0) * (rest.first == "M" ? -1 : 1)
            let m = base + off
            return (m / 60) * 100 + m % 60
        }
        if key.hasPrefix("isimPresence") { return 1 }        // the simulated owner is at home
        if key.hasPrefix("isimC"), let v = _HMAutomation.valueFor(key: key) { return v }
        return nil
    }
}

enum _HMAutomation {
    nonisolated(unsafe) static var executing = Set<String>()

    static func key(_ characteristic: String) -> String { "isimC" + characteristic.replacingOccurrences(of: "-", with: "") }
    static func valueFor(key: String) -> Any? {
        let wanted = String(key.dropFirst(5))
        for h in _HMStore.shared.data.homes {
            for a in h.accessories { for s in a.services { for c in s.characteristics where c.id.replacingOccurrences(of: "-", with: "") == wanted { return c.value?.object } } }
        }
        return nil
    }
    static func predicate(_ format: String) -> NSPredicate? {
        // NSPredicate(format:) raises on a format it cannot parse: only isim's own (and simple) formats are stored
        NSPredicate(format: format)
    }

    // the objects for stored records
    static func trigger(_ rec: _HMTriggerRec) -> HMTrigger {
        let home = _HMStore.shared.data.homes.first { $0.triggers.contains { $0.id == rec.id } }?.id
        return _HMObjects.shared.object(rec.id) {
            rec.kind == "timer" ? HMTimerTrigger(_rec: rec, home: home) as HMTrigger : HMEventTrigger(_rec: rec, home: home)
        }
    }
    static func event(_ rec: _HMEventRec) -> HMEvent {
        _HMObjects.shared.object(rec.id) { () -> HMEvent in
            switch rec.kind {
            case "characteristic":
                // an Objective-C app gets Objective-C's HMCharacteristicEvent (HomeKit.framework), a Swift app Swift's
                if let cls = NSClassFromString("HMCharacteristicEvent") as? NSObject.Type,
                   let made = cls.perform(NSSelectorFromString("_isim_eventWithCharacteristic:valueAndIdentifier:"),
                                          with: _HMObjects.shared.characteristic(rec.characteristic ?? ""),
                                          with: [rec.value?.object ?? NSNull(), rec.id])?.takeUnretainedValue() as? HMEvent { return made }
                return HMCharacteristicEvent<NSCopying>(_record: rec)
            case "threshold": return HMCharacteristicThresholdRangeEvent(_record: rec)
            case "calendar": return HMCalendarEvent(_record: rec)
            case "significant": return HMSignificantTimeEvent(_record: rec)
            case "duration": return HMDurationEvent(_record: rec)
            case "presence": return HMPresenceEvent(_record: rec)
            case "location": return HMLocationEvent(_record: rec)
            default: return HMEvent(_record: rec)
            }
        }
    }
    static func action(_ rec: _HMActionRec) -> HMAction? {
        if let a = _HMObjects.shared.existing(rec.id, HMAction.self) { return a }
        let c = _HMObjects.shared.characteristic(rec.characteristic)
        // an Objective-C app gets Objective-C's HMCharacteristicWriteAction (HomeKit.framework's), a Swift app Swift's
        if let cls = NSClassFromString("HMCharacteristicWriteAction") as? NSObject.Type,
           let made = cls.perform(NSSelectorFromString("_isim_actionWithCharacteristic:valueAndIdentifier:"), with: c, with: [rec.value.object, rec.id])?
               .takeUnretainedValue() as? HMAction {
            _HMObjects.shared.register(made, rec.id)
            return made
        }
        return _HMObjects.shared.object(rec.id) {
            HMCharacteristicWriteAction<NSCopying>(_id: rec.id, characteristic: c, targetValue: rec.value.object as! NSCopying) as HMAction
        }
    }

    static func updateAction(_ id: String, _ body: (inout _HMActionRec) -> Void) {
        _HMStore.shared.modify { d in
            for h in d.homes.indices { for s in d.homes[h].actionSets.indices { for a in d.homes[h].actionSets[s].actions.indices where d.homes[h].actionSets[s].actions[a].id == id {
                body(&d.homes[h].actionSets[s].actions[a])
            } } }
        }
        _HMStore.shared.save()
    }
    static func updateEvent(_ rec: _HMEventRec) {
        _HMStore.shared.modify { d in
            for h in d.homes.indices { for t in d.homes[h].triggers.indices {
                if let i = d.homes[h].triggers[t].events?.firstIndex(where: { $0.id == rec.id }) { d.homes[h].triggers[t].events![i] = rec }
                if let i = d.homes[h].triggers[t].endEvents?.firstIndex(where: { $0.id == rec.id }) { d.homes[h].triggers[t].endEvents![i] = rec }
            } }
        }
        _HMStore.shared.save()
    }

    /// runs an action set: writes each action's value; nil or the first error
    @discardableResult
    static func execute(_ setID: String, in homeID: String) -> NSError? {
        guard let home = _HMStore.shared.home(homeID), let set = home.actionSets.first(where: { $0.id == setID }) else { return _hmErr(.notFound) }
        executing.insert(setID)
        defer { executing.remove(setID) }
        var failed: NSError?
        for a in set.actions {
            guard let (acc, _, _) = _HMStore.shared.characteristicPath(a.characteristic), let rec = _HMStore.shared.accessory(acc) else { continue }
            if !(rec.reachable ?? true) { failed = failed ?? _hmErr(.actionSetExecutionPartialSuccess); continue }
            _HMStore.shared.setValue(a.characteristic, a.value)
        }
        _HMStore.shared.modify { d in
            if let h = d.homes.firstIndex(where: { $0.id == homeID }), let s = d.homes[h].actionSets.firstIndex(where: { $0.id == setID }) {
                d.homes[h].actionSets[s].lastExecution = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
            }
        }
        _HMStore.shared.save()
        NSLog("isim HomeKit: ran %@ (%d actions)", set.name, set.actions.count)
        return failed
    }

    private static func fire(_ t: _HMTriggerRec, in homeID: String, _ why: String) {
        if let p = t.predicate, let pred = predicate(p), !pred.evaluate(with: _HMPredicateContext()) { return }
        NSLog("isim HomeKit: trigger %@ fired (%@)", t.name, why)
        for s in t.actionSets { execute(s, in: homeID) }
        _HMStore.shared.modify { d in
            guard let h = d.homes.firstIndex(where: { $0.id == homeID }), let i = d.homes[h].triggers.firstIndex(where: { $0.id == t.id }) else { return }
            d.homes[h].triggers[i].lastFire = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
            if t.executeOnce == true { d.homes[h].triggers[i].enabled = false }
        }
        _HMStore.shared.save()
    }

    /// timer triggers whose fire date passed, calendar events of this minute
    static func fireTimers() {
        let now = Date()
        for home in _HMStore.shared.data.homes {
            for t in home.triggers where t.enabled {
                if t.kind == "timer", var due = t.fireDate, due <= now, (t.lastFire ?? .distantPast) < due {
                    // a recurring trigger moves on to its next fire date
                    if let r = _hmComponents(t.recurrence) {
                        var next = due
                        while next <= now, let n = Calendar.current.date(byAdding: r, to: next), n > next { next = n }
                        let tid = t.id
                        _HMStore.shared.modify { d in
                            if let h = d.homes.firstIndex(where: { $0.id == home.id }), let i = d.homes[h].triggers.firstIndex(where: { $0.id == tid }) {
                                d.homes[h].triggers[i].fireDate = next
                            }
                        }
                        due = now
                    }
                    fire(t, in: home.id, "timer")
                }
                if t.kind == "event", home.hub == true {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: now)
                    for e in t.events ?? [] where e.kind == "calendar" {
                        guard let want = e.components, want["hour"] == c.hour, want["minute"] ?? 0 == c.minute else { continue }
                        if let last = t.lastFire, now.timeIntervalSince(last) < 61 { continue }
                        fire(t, in: home.id, "calendar")
                    }
                }
            }
        }
    }

    /// event triggers that watch a characteristic
    static func characteristicChanged(_ id: String, _ value: _HMValue?) {
        guard let value, let home = _HMStore.shared.data.homes.first(where: { $0.accessories.contains { $0.services.contains { $0.characteristics.contains { $0.id == id } } } }),
              home.hub == true else { return }
        for t in home.triggers where t.enabled && t.kind == "event" {
            let hit = (t.events ?? []).contains { e in
                guard e.characteristic == id else { return false }
                if e.kind == "characteristic" { return e.value == nil || e.value == value || e.value?.number == value.number }
                if e.kind == "threshold", let n = value.number { return (e.min.map { n >= $0 } ?? true) && (e.max.map { n <= $0 } ?? true) }
                return false
            }
            if hit { DispatchQueue.main.async { fire(t, in: home.id, "characteristic") } }
        }
    }
}
