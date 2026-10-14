// isim Foundation: TimeZone's daylight-saving queries and zone list, and Calendar's weekends, ordinality and date
// enumeration, as Apple's Foundation. Time zones come from the host's tz database (NSTimeZone); weekends from the
// host's ICU (CLDR weekData), else isim's table of the regions whose weekend is not Saturday and Sunday (adapted).
import isim_host

extension TimeZone {
    /// every zone of the host's tz database, as iOS lists its own
    public static var knownTimeZoneIdentifiers: [String] { NSTimeZone.knownTimeZoneNames }
    public func isDaylightSavingTime(for date: Date = Date()) -> Bool { _ns.isDaylightSavingTime(for: date) }
    public func daylightSavingTimeOffset(for date: Date = Date()) -> TimeInterval { _ns.daylightSavingTimeOffset(for: date) }
    public func nextDaylightSavingTimeTransition(after date: Date) -> Date? { _ns.nextDaylightSavingTimeTransition(after: date) }
    public var nextDaylightSavingTimeTransition: Date? { nextDaylightSavingTimeTransition(after: Date()) }
}

extension Calendar {
    /// the region's first weekday (1 = Sunday) without ICU: Monday, except where CLDR has Sunday (or Saturday)
    static func _defaultFirstWeekday(region: String?) -> Int {
        let sundayFirst: Set<String> = ["US", "CA", "JP", "BR", "MX", "PH", "IL", "ZA", "KR", "TW", "HK", "IN", "SA", "AU", "AR", "CO", "PE", "VE", "GT", "SV", "HN", "NI", "PA", "DO", "PR", "KE", "TH"]
        let saturdayFirst: Set<String> = ["AE", "AF", "BH", "DJ", "DZ", "EG", "IQ", "IR", "JO", "KW", "LY", "OM", "QA", "SD", "SY"]
        let r = region ?? "US"
        return sundayFirst.contains(r) ? 1 : saturdayFirst.contains(r) ? 7 : 2
    }

    /// the weekend days of the calendar's locale (1 = Sunday)
    var _weekendDays: Set<Int> {
        let locale = self.locale ?? .current
        let ident = locale.region.map { (locale.languageCode ?? "und") + "_" + $0.identifier } ?? locale.identifier
        var types = [Int32](repeating: 0, count: 7)
        if isim_icu_weekend(ident, &types) == 0 {
            let days = Set((1...7).filter { types[$0 - 1] != 0 })
            if !days.isEmpty { return days }
        }
        switch locale.region?.identifier ?? "" {
        case "BH", "DZ", "EG", "IQ", "IL", "JO", "KW", "LY", "OM", "QA", "SA", "SD", "SY", "YE": return [6, 7]
        case "AF": return [5, 6]
        case "IR": return [6]
        case "IN", "UG": return [1]
        default: return [1, 7]
        }
    }
    public func isDateInWeekend(_ date: Date) -> Bool { _weekendDays.contains(component(.weekday, from: date)) }
    /// the weekend containing a date (midnight to midnight), nil on a weekday
    public func dateIntervalOfWeekend(containing date: Date) -> DateInterval? {
        guard isDateInWeekend(date) else { return nil }
        var start = startOfDay(for: date), end = start
        while let prev = self.date(byAdding: .day, value: -1, to: start), isDateInWeekend(prev) { start = prev }
        while let next = self.date(byAdding: .day, value: 1, to: end), isDateInWeekend(next) { end = next }
        return self.date(byAdding: .day, value: 1, to: end).map { DateInterval(start: start, end: $0) }
    }
    public func dateIntervalOfWeekend(containing date: Date, start: inout Date, interval: inout TimeInterval) -> Bool {
        guard let w = dateIntervalOfWeekend(containing: date) else { return false }
        start = w.start; interval = w.duration
        return true
    }
    /// the next (or previous) weekend that does not contain the date
    public func nextWeekend(startingAfter date: Date, direction: SearchDirection = .forward) -> DateInterval? {
        let step = direction == .forward ? 1 : -1
        var day = startOfDay(for: date)
        if let current = dateIntervalOfWeekend(containing: date) { day = direction == .forward ? current.end : current.start.addingTimeInterval(-1) }
        for _ in 0..<14 {
            if isDateInWeekend(day) { return dateIntervalOfWeekend(containing: day) }
            guard let d = self.date(byAdding: .day, value: step, to: day) else { return nil }
            day = d
        }
        return nil
    }
    public func nextWeekend(startingAfter date: Date, start: inout Date, interval: inout TimeInterval, direction: SearchDirection = .forward) -> Bool {
        guard let w = nextWeekend(startingAfter: date, direction: direction) else { return false }
        start = w.start; interval = w.duration
        return true
    }

    /// the position of the date's `smaller` unit within its `larger` unit, from 1 (the 3rd day of the month: 3)
    public func ordinality(of smaller: Component, in larger: Component, for date: Date) -> Int? {
        let c = dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfMonth, .weekOfYear], from: date)
        guard let y = c.year, let m = c.month, let d = c.day, let h = c.hour, let mi = c.minute, let s = c.second, let wd = c.weekday else { return nil }
        let dayInWeek = (wd - firstWeekday + 7) % 7 + 1
        func dayInYear() -> Int? {
            guard let jan1 = self.date(from: DateComponents(year: y, month: 1, day: 1)) else { return nil }
            return dateComponents([.day], from: jan1, to: startOfDay(for: date)).day.map { $0 + 1 }
        }
        func week(in unitStart: Date?) -> Int? {
            guard let unitStart, let w0 = dateInterval(of: .weekOfYear, for: unitStart)?.start,
                  let w = dateInterval(of: .weekOfYear, for: date)?.start else { return nil }
            return (dateComponents([.day], from: w0, to: w).day ?? 0) / 7 + 1
        }
        func dayOrdinal(in unit: Component) -> Int? {
            switch unit {
            case .month: return d
            case .year: return dayInYear()
            case .weekOfMonth, .weekOfYear: return dayInWeek
            case .quarter:
                guard let q = self.date(from: DateComponents(year: y, month: (m - 1) / 3 * 3 + 1, day: 1)) else { return nil }
                return dateComponents([.day], from: q, to: startOfDay(for: date)).day.map { $0 + 1 }
            default: return nil
            }
        }
        switch (smaller, larger) {
        case (.second, .minute): return s + 1
        case (.second, .hour): return mi * 60 + s + 1
        case (.second, .day): return (h * 60 + mi) * 60 + s + 1
        case (.minute, .hour): return mi + 1
        case (.minute, .day): return h * 60 + mi + 1
        case (.hour, .day): return h + 1
        case (.hour, .month), (.hour, .year), (.hour, .weekOfMonth), (.hour, .weekOfYear), (.hour, .quarter):
            return dayOrdinal(in: larger).map { ($0 - 1) * 24 + h + 1 }
        case (.day, _), (.weekday, .month), (.weekday, .year), (.weekday, .weekOfMonth), (.weekday, .weekOfYear), (.weekday, .quarter):
            return dayOrdinal(in: larger)
        case (.weekdayOrdinal, .month): return c.weekdayOrdinal
        case (.weekOfMonth, .month): return c.weekOfMonth
        case (.weekOfYear, .yearForWeekOfYear): return c.weekOfYear
        case (.weekOfYear, .year), (.weekOfMonth, .year): return week(in: self.date(from: DateComponents(year: y, month: 1, day: 1)))
        case (.weekOfYear, .month): return week(in: self.date(from: DateComponents(year: y, month: m, day: 1)))
        case (.month, .year): return m
        case (.month, .quarter): return (m - 1) % 3 + 1
        case (.quarter, .year): return (m - 1) / 3 + 1
        case (.year, .era): return y
        default: return nil
        }
    }

    /// calls `block` with each date matching `components` (by nextDate(after:matching:...)) until it sets `stop`
    public func enumerateDates(startingAfter start: Date, matching components: DateComponents, matchingPolicy: MatchingPolicy,
                               repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward,
                               using block: (_ result: Date?, _ exactMatch: Bool, _ stop: inout Bool) -> Void) {
        var current = start, stop = false
        while !stop {
            guard let next = nextDate(after: current, matching: components, matchingPolicy: matchingPolicy,
                                      repeatedTimePolicy: repeatedTimePolicy, direction: direction) else {
                block(nil, false, &stop)
                return
            }
            block(next, true, &stop)
            current = next
        }
    }
}
