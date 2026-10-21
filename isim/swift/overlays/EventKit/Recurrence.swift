// isim EventKit: recurrence (EKRecurrenceRule's days, months and set positions, expanded into occurrences for date-range
// queries), alarms (relative, absolute, location; display alarms fire while an app that uses EventKit runs, as the
// Calendar app's alert banner), structured locations and participants (read from the calendar database: apps cannot
// invite people). Adapted: proximity alarms are stored but never fire; isim has no Calendar daemon to fire alarms
// while no app that uses EventKit runs.
import UIKit
import ObjectiveC
import CoreLocation
import Contacts

// MARK: - Records in the calendar database

struct _EKPlace: Codable { var title: String?; var lat: Double?; var lon: Double?; var radius: Double? }
struct _EKAlarmRec: Codable {
    var offset: Double; var date: Double?; var type: Int?; var place: _EKPlace?; var proximity: Int?; var email: String?; var sound: String?
    init(offset: Double) { self.offset = offset }
    init(_ a: EKAlarm) {
        offset = a.relativeOffset; date = a.absoluteDate?.timeIntervalSince1970; type = a._type == .display ? nil : a._type.rawValue
        place = a.structuredLocation.map(_EKPlace.init); proximity = a.proximity == .none ? nil : a.proximity.rawValue
        email = a.emailAddress; sound = a.soundName
    }
}
struct _EKRuleRec: Codable {
    var freq: Int; var interval: Int
    var end: Double?; var count: Int?
    var days: [[Int]]?                    // [weekday (1 = Sunday), week number (0: every)]
    var monthDays: [Int]?; var months: [Int]?; var weeks: [Int]?; var yearDays: [Int]?; var positions: [Int]?; var firstDay: Int?
}
struct _EKPerson: Codable { var name: String?; var url: String; var status: Int?; var role: Int?; var type: Int?; var me: Bool? }

// MARK: - Types

@objc public enum EKWeekday: Int, Sendable { case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday }
@objc public enum EKAlarmProximity: Int, Sendable { case none = 0, enter, leave }
@objc public enum EKAlarmType: Int, Sendable { case display = 0, audio, procedure, email }
@objc public enum EKParticipantStatus: Int, Sendable { case unknown = 0, pending, accepted, declined, tentative, delegated, completed, inProcess }
@objc public enum EKParticipantRole: Int, Sendable { case unknown = 0, required, optional, chair, nonParticipant }
@objc public enum EKParticipantType: Int, Sendable { case unknown = 0, person, room, resource, group }

/// a day of the week in a recurrence rule, optionally its week in the month or year (2: the second; -1: the last)
@objc(EKRecurrenceDayOfWeek) open class EKRecurrenceDayOfWeek: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let dayOfTheWeek: EKWeekday
    public let weekNumber: Int
    public convenience init(_ dayOfTheWeek: EKWeekday) { self.init(dayOfTheWeek, weekNumber: 0) }
    public init(_ dayOfTheWeek: EKWeekday, weekNumber: Int) { self.dayOfTheWeek = dayOfTheWeek; self.weekNumber = weekNumber }
    public convenience init(dayOfTheWeek: EKWeekday, weekNumber: Int) { self.init(dayOfTheWeek, weekNumber: weekNumber) }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(dayOfTheWeek.rawValue, forKey: "dayOfTheWeek"); coder.encode(weekNumber, forKey: "weekNumber")
    }
    public required init?(coder: NSCoder) {
        dayOfTheWeek = EKWeekday(rawValue: coder.decodeInteger(forKey: "dayOfTheWeek")) ?? .sunday; weekNumber = coder.decodeInteger(forKey: "weekNumber")
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? EKRecurrenceDayOfWeek else { return false }
        return o.dayOfTheWeek == dayOfTheWeek && o.weekNumber == weekNumber
    }
    open override var hash: Int { dayOfTheWeek.rawValue * 100 + weekNumber }
    open override var description: String { (weekNumber == 0 ? "" : "\(weekNumber)") + ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"][dayOfTheWeek.rawValue] }
}

/// a place with a title and, optionally, coordinates and a radius (for an event, or a location alarm)
@objc(EKStructuredLocation) open class EKStructuredLocation: EKObject, NSCopying, @unchecked Sendable {
    open var title: String?
    open var geoLocation: CLLocation?
    /// meters; 0 uses the system default
    open var radius: Double = 0
    public init(title: String) { self.title = title }
    init(_ p: _EKPlace) {
        title = p.title; radius = p.radius ?? 0
        if let a = p.lat, let o = p.lon { geoLocation = CLLocation(latitude: a, longitude: o) }
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { EKStructuredLocation(_EKPlace(self)) }
}
extension _EKPlace {
    init(_ l: EKStructuredLocation) {
        title = l.title; radius = l.radius == 0 ? nil : l.radius
        lat = l.geoLocation?.coordinate.latitude; lon = l.geoLocation?.coordinate.longitude
    }
}

/// a person (or room, resource, group) invited to an event
@objc(EKParticipant) open class EKParticipant: EKObject, NSCopying, @unchecked Sendable {
    let p: _EKPerson
    init(_ p: _EKPerson) { self.p = p }
    open var url: URL { URL(string: p.url) ?? URL(string: "mailto:unknown")! }
    open var name: String? { p.name }
    open var participantStatus: EKParticipantStatus { EKParticipantStatus(rawValue: p.status ?? 0) ?? .unknown }
    open var participantRole: EKParticipantRole { EKParticipantRole(rawValue: p.role ?? 0) ?? .unknown }
    open var participantType: EKParticipantType { EKParticipantType(rawValue: p.type ?? 0) ?? .unknown }
    open var isCurrentUser: Bool { p.me ?? false }
    /// finds the participant in Contacts by email address
    open var contactPredicate: NSPredicate {
        let mail = url.scheme == "mailto" ? String(p.url.dropFirst(7)) : p.url
        return CNContact.predicateForContacts(matchingEmailAddress: mail)
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override var description: String { "EKParticipant <\(p.url)> {name = \(p.name ?? "nil"); status = \(participantStatus.rawValue); role = \(participantRole.rawValue)}" }
}

// MARK: - Expanding recurrences

enum _EKRecurrence {
    static var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }

    /// the occurrence starts of a series starting at `start` (duration `d`) that overlap [a, b), without exceptions
    static func starts(_ start: Double, _ d: Double, _ r: _EKRuleRec, except ex: Set<Double> = [], from a: Double, to b: Double) -> [Double] {
        var out: [Double] = [], n = 0
        let c = cal, s = Date(timeIntervalSince1970: start)
        let time = c.dateComponents([.hour, .minute, .second], from: s)
        let interval = max(1, r.interval)
        for k in 0..<5000 {
            guard let cands = candidates(c, s, time, r, period: k * interval) else { break }
            for t in cands where t >= start {
                if let e = r.end, t > e { return out }
                if let cnt = r.count, n >= cnt { return out }
                n += 1
                if t >= b { return out }
                if t + max(d, 0.001) > a && !ex.contains(t) { out.append(t) }
            }
        }
        return out
    }

    /// the starts in one period (a day, week, month or year after the first), sorted, after set positions
    static func candidates(_ c: Calendar, _ s: Date, _ time: DateComponents, _ r: _EKRuleRec, period: Int) -> [Double]? {
        let fraction = s.timeIntervalSince1970 - s.timeIntervalSince1970.rounded(.down)     // keep the start's sub-second part
        func at(_ day: Date) -> Double? {
            c.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day).map { $0.timeIntervalSince1970 + fraction }
        }
        let startDay = c.startOfDay(for: s)
        var days: [Date] = []
        switch EKRecurrenceFrequency(rawValue: r.freq) ?? .daily {
        case .daily:
            guard let d = c.date(byAdding: .day, value: period, to: startDay) else { return nil }
            days = [d]
        case .weekly:
            let first = r.firstDay.flatMap { $0 > 0 ? $0 : nil } ?? c.firstWeekday
            let wd = c.component(.weekday, from: startDay)
            guard let weekStart = c.date(byAdding: .day, value: -((wd - first + 7) % 7) + 7 * period, to: startDay) else { return nil }
            let want = r.days.map { $0.map { $0[0] } } ?? [wd]
            days = (0..<7).compactMap { c.date(byAdding: .day, value: $0, to: weekStart) }.filter { want.contains(c.component(.weekday, from: $0)) }
        case .monthly:
            guard let m = c.date(byAdding: .month, value: period, to: c.date(from: c.dateComponents([.year, .month], from: startDay))!) else { return nil }
            days = daysInMonth(c, m, r, defaultDay: c.component(.day, from: startDay))
        case .yearly:
            let y = c.component(.year, from: startDay) + period
            if let yd = r.yearDays {
                let jan1 = c.date(from: DateComponents(year: y, month: 1, day: 1))!
                let len = c.range(of: .day, in: .year, for: jan1)?.count ?? 365
                days = yd.compactMap { c.date(byAdding: .day, value: ($0 > 0 ? $0 : len + $0 + 1) - 1, to: jan1) }
            } else {
                let months = r.months ?? [c.component(.month, from: startDay)]
                for mo in months {
                    guard let m = c.date(from: DateComponents(year: y, month: mo, day: 1)) else { continue }
                    days += daysInMonth(c, m, r, defaultDay: c.component(.day, from: startDay))
                }
            }
            if let wk = r.weeks { days = days.filter { wk.contains(c.component(.weekOfYear, from: $0)) } }
        }
        // a daily rule with BYDAY or BYMONTH limits which days count
        if r.freq == EKRecurrenceFrequency.daily.rawValue {
            if let want = r.days?.map({ $0[0] }) { days = days.filter { want.contains(c.component(.weekday, from: $0)) } }
            if let ms = r.months { days = days.filter { ms.contains(c.component(.month, from: $0)) } }
        }
        var times = days.compactMap(at).sorted()
        if let pos = r.positions, !times.isEmpty {
            times = pos.compactMap { p in p > 0 ? (p <= times.count ? times[p - 1] : nil) : (-p <= times.count ? times[times.count + p] : nil) }.sorted()
        }
        return times
    }

    /// the days of month `m` a monthly (or yearly) rule picks: days of the month, weekdays (the nth), or `defaultDay`
    static func daysInMonth(_ c: Calendar, _ m: Date, _ r: _EKRuleRec, defaultDay: Int) -> [Date] {
        let len = c.range(of: .day, in: .month, for: m)?.count ?? 30
        func day(_ n: Int) -> Date? { n >= 1 && n <= len ? c.date(byAdding: .day, value: n - 1, to: m) : nil }
        if let md = r.monthDays { return md.compactMap { day($0 > 0 ? $0 : len + $0 + 1) } }
        if let wds = r.days {
            var out: [Date] = []
            for w in wds {
                let all = (1...len).compactMap(day).filter { c.component(.weekday, from: $0) == w[0] }
                let n = w.count > 1 ? w[1] : 0
                if n == 0 { out += all } else if n > 0, n <= all.count { out.append(all[n - 1]) } else if n < 0, -n <= all.count { out.append(all[all.count + n]) }
            }
            return out.sorted()
        }
        return day(defaultDay).map { [$0] } ?? []
    }

    /// the rule as RFC 5545 text, for descriptions
    static func rrule(_ r: _EKRuleRec) -> String {
        var p = ["FREQ=" + ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"][max(0, min(3, r.freq))], "INTERVAL=\(r.interval)"]
        if let d = r.days { p.append("BYDAY=" + d.map { ($0.count > 1 && $0[1] != 0 ? "\($0[1])" : "") + ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"][max(1, min(7, $0[0]))] }.joined(separator: ",")) }
        if let m = r.monthDays { p.append("BYMONTHDAY=" + m.map(String.init).joined(separator: ",")) }
        if let m = r.months { p.append("BYMONTH=" + m.map(String.init).joined(separator: ",")) }
        if let m = r.positions { p.append("BYSETPOS=" + m.map(String.init).joined(separator: ",")) }
        if let n = r.count { p.append("COUNT=\(n)") }
        if let e = r.end {
            let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(identifier: "UTC")
            p.append("UNTIL=" + f.string(from: Date(timeIntervalSince1970: e)))
        }
        return p.joined(separator: ";")
    }

    /// how many occurrences come before `t` (to shorten a counted series that is split)
    static func countBefore(_ start: Double, _ r: _EKRuleRec, _ t: Double) -> Int { starts(start, 0, r, from: -Double.greatestFiniteMagnitude, to: t).count }
}

/// the date range of a predicateForEvents predicate, so events(matching:) can expand recurring events into it
final class _EKRange { let a: Double, b: Double; init(_ a: Double, _ b: Double) { self.a = a; self.b = b } }
nonisolated(unsafe) var _ekRangeKey: UInt8 = 0

// MARK: - Alarms

/// fires the display alarms of events and reminders as their time comes, while an app that uses EventKit runs
@MainActor enum _EKAlarms {
    static var timer: Timer?
    static var last = Date().timeIntervalSince1970
    static func start() {
        guard timer == nil else { return }
        last = Date().timeIntervalSince1970
        let t = Timer(timeInterval: 0.5, repeats: true) { _ in MainActor.assumeIsolated { tick() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    static func tick() {
        let now = Date().timeIntervalSince1970
        defer { last = now }
        guard now > last else { return }
        let db = _EKStore.load()
        for it in db.items {
            let probe = EKCalendarItem(it)
            for al in probe.alarmRecords where al.proximity == nil || al.proximity == 0 {
                if al.type == EKAlarmType.email.rawValue || al.type == EKAlarmType.procedure.rawValue { continue }
                if let at = al.date {
                    if at > last && at <= now { fire(it, at) }
                    continue
                }
                if it.kind == 0, let s = it.start, let e = it.end {
                    // occurrences whose alarm time (start + offset) falls in (last, now]
                    let rules = probe.ruleRecords
                    let starts = rules.first.map { _EKRecurrence.starts(s, 0, $0, except: Set(it.exdates ?? []), from: last - al.offset, to: now - al.offset + 0.001) }
                        ?? (s + al.offset > last && s + al.offset <= now ? [s] : [])
                    for o in starts where o + al.offset > last && o + al.offset <= now { fire(it, o, o + (e - s)) }
                } else if it.kind == 1, let due = EKReminder.comps(it.due).flatMap({ _EKRecurrence.cal.date(from: $0) })?.timeIntervalSince1970,
                          !it.completed, due + al.offset > last, due + al.offset <= now {
                    fire(it, due)
                }
            }
        }
    }
    static func fire(_ it: _EKItem, _ start: Double, _ end: Double? = nil) {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
        let s = Date(timeIntervalSince1970: start)
        var body = end.map { "\(f.string(from: s)) – \(f.string(from: Date(timeIntervalSince1970: $0)))" } ?? f.string(from: s)
        if it.kind == 0, it.allDay { body = "All-day" }
        if let l = it.location, !l.isEmpty { body += "\n" + l }
        let reminder = it.kind == 1
        NSLog("isim EventKit: alarm “%@” %@ (%@)", it.title, reminder ? "reminder" : "event", f.string(from: s))
        _EKAlarmBanner.show(title: it.title.isEmpty ? (reminder ? "Reminder" : "New Event") : it.title, body: reminder ? "Reminders" : body, reminder: reminder)
    }
}

/// the Calendar (or Reminders) alert banner: slides in at the top, a tap or a swipe up dismisses it, gone after 5 s
@MainActor enum _EKAlarmBanner {
    final class Window: UIWindow {
        override func hitTest(_ p: CGPoint, with e: UIEvent?) -> UIView? {
            let v = super.hitTest(p, with: e)
            return v === self || v === rootViewController?.view ? nil : v
        }
    }
    static var window: UIWindow?
    static var gen = 0
    static func icon(reminder: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 38, height: 38)).image { _ in
            UIColor.white.setFill(); UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 38, height: 38), cornerRadius: 9).fill()
            if reminder {
                for (k, col) in [UIColor.systemBlue, .systemRed, .systemOrange].enumerated() {
                    col.setFill(); UIBezierPath(ovalIn: CGRect(x: 7, y: 7 + CGFloat(k) * 9, width: 6, height: 6)).fill()
                    UIColor.systemGray4.setFill(); UIRectFill(CGRect(x: 16, y: 9 + CGFloat(k) * 9, width: 15, height: 1.5))
                }
                return
            }
            let now = Date(), c = _EKRecurrence.cal
            let wd = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][c.component(.weekday, from: now)]
            let top = NSAttributedString(string: wd, attributes: [.font: UIFont.systemFont(ofSize: 7, weight: .semibold), .foregroundColor: UIColor.systemRed])
            top.draw(at: CGPoint(x: (38 - top.size().width) / 2, y: 4))
            let day = NSAttributedString(string: "\(c.component(.day, from: now))", attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .light), .foregroundColor: UIColor.black])
            day.draw(at: CGPoint(x: (38 - day.size().width) / 2, y: 11))
        }
    }
    static func show(title: String, body: String, reminder: Bool) {
        window?.rootViewController?.view.subviews.forEach { $0.removeFromSuperview() }
        window?.isHidden = true
        let screen = UIScreen.main.bounds
        let w = Window(frame: screen)
        w.windowLevel = UIWindow.Level(rawValue: 2100)
        w.backgroundColor = .clear
        let root = UIViewController(); root.view.backgroundColor = .clear
        w.rootViewController = root
        let width = min(screen.width - 16, 400), x = (screen.width - width) / 2, textX: CGFloat = 60, textW = width - textX - 14
        let t = UILabel(), b = UILabel(), when = UILabel()
        t.text = title; t.font = .systemFont(ofSize: 15, weight: .semibold); t.textColor = .label
        b.text = body; b.numberOfLines = 3; b.font = .systemFont(ofSize: 15); b.textColor = .label
        when.text = "now"; when.font = .systemFont(ofSize: 13); when.textColor = .secondaryLabel; when.textAlignment = .right
        let bs = b.sizeThatFits(CGSize(width: textW, height: 400))
        let height = max(68, 14 + 20 + ceil(bs.height) + 14)
        let card = UIView(frame: CGRect(x: x, y: -height - 12, width: width, height: height))
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 22
        card.accessibilityIdentifier = "isim-calendar-alarm"
        let iv = UIImageView(frame: CGRect(x: 12, y: (height - 38) / 2, width: 38, height: 38))
        iv.image = icon(reminder: reminder); iv.layer.cornerRadius = 9; iv.clipsToBounds = true
        iv.layer.borderColor = UIColor.systemGray5.cgColor; iv.layer.borderWidth = 0.5
        t.frame = CGRect(x: textX, y: 13, width: textW - 40, height: 20)
        when.frame = CGRect(x: width - 54, y: 13, width: 40, height: 18)
        b.frame = CGRect(x: textX, y: 34, width: textW, height: ceil(bs.height))
        for v in [iv, t, when, b] as [UIView] { v.isUserInteractionEnabled = false; card.addSubview(v) }
        let tap = _EKBannerTarget()
        card.addGestureRecognizer(UITapGestureRecognizer(target: tap, action: #selector(_EKBannerTarget.hide)))
        card.addGestureRecognizer(UISwipeGestureRecognizer(target: tap, action: #selector(_EKBannerTarget.hide)))
        objc_setAssociatedObject(card, &_ekRangeKey, tap, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        root.view.addSubview(card)
        w.isHidden = false
        window = w
        gen += 1
        let g = gen
        let top = max(w.safeAreaInsets.top, 20) + 2
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: []) {
            card.frame = CGRect(x: x, y: top, width: width, height: height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { if g == gen { hide() } }
    }
    static func hide() {
        guard let w = window, let card = w.rootViewController?.view.subviews.first else { return }
        window = nil
        UIView.animate(withDuration: 0.3, animations: { card.frame.origin.y = -card.frame.height - 12 }) { _ in card.removeFromSuperview(); w.isHidden = true }
    }
}
final class _EKBannerTarget: NSObject {
    @objc func hide() { MainActor.assumeIsolated { _EKAlarmBanner.hide() } }
}
