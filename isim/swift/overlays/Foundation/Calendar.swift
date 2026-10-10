// isim Foundation: Calendar and DateComponents (Gregorian; ISO 8601 week rules for .iso8601). Self-authored.
// Other calendar systems (Buddhist, Japanese, Hebrew, Islamic, Chinese, ...) are computed by the host's ICU
// (CalendarICU.swift); without ICU they fall back to Gregorian rules and log once.
import Darwin

public struct DateComponents: Hashable, Sendable, CustomStringConvertible {
    public var calendar: Calendar?
    public var timeZone: TimeZone?
    public var era: Int?
    public var year: Int?
    public var month: Int?
    public var day: Int?
    public var hour: Int?
    public var minute: Int?
    public var second: Int?
    public var nanosecond: Int?
    public var weekday: Int?
    public var weekdayOrdinal: Int?
    public var quarter: Int?
    public var weekOfMonth: Int?
    public var weekOfYear: Int?
    public var yearForWeekOfYear: Int?
    public var dayOfYear: Int?
    public var isLeapMonth: Bool?

    public init(calendar: Calendar? = nil, timeZone: TimeZone? = nil, era: Int? = nil, year: Int? = nil, month: Int? = nil,
                day: Int? = nil, hour: Int? = nil, minute: Int? = nil, second: Int? = nil, nanosecond: Int? = nil,
                weekday: Int? = nil, weekdayOrdinal: Int? = nil, quarter: Int? = nil, weekOfMonth: Int? = nil,
                weekOfYear: Int? = nil, yearForWeekOfYear: Int? = nil) {
        self.calendar = calendar; self.timeZone = timeZone; self.era = era; self.year = year; self.month = month
        self.day = day; self.hour = hour; self.minute = minute; self.second = second; self.nanosecond = nanosecond
        self.weekday = weekday; self.weekdayOrdinal = weekdayOrdinal; self.quarter = quarter; self.weekOfMonth = weekOfMonth
        self.weekOfYear = weekOfYear; self.yearForWeekOfYear = yearForWeekOfYear
    }

    public func value(for c: Calendar.Component) -> Int? {
        switch c {
        case .era: return era
        case .year: return year
        case .month: return month
        case .day: return day
        case .hour: return hour
        case .minute: return minute
        case .second: return second
        case .nanosecond: return nanosecond
        case .weekday: return weekday
        case .weekdayOrdinal: return weekdayOrdinal
        case .quarter: return quarter
        case .weekOfMonth: return weekOfMonth
        case .weekOfYear: return weekOfYear
        case .yearForWeekOfYear: return yearForWeekOfYear
        case .dayOfYear: return dayOfYear
        default: return nil
        }
    }
    public mutating func setValue(_ v: Int?, for c: Calendar.Component) {
        switch c {
        case .era: era = v
        case .year: year = v
        case .month: month = v
        case .day: day = v
        case .hour: hour = v
        case .minute: minute = v
        case .second: second = v
        case .nanosecond: nanosecond = v
        case .weekday: weekday = v
        case .weekdayOrdinal: weekdayOrdinal = v
        case .quarter: quarter = v
        case .weekOfMonth: weekOfMonth = v
        case .weekOfYear: weekOfYear = v
        case .yearForWeekOfYear: yearForWeekOfYear = v
        case .dayOfYear: dayOfYear = v
        default: break
        }
    }
    public var date: Date? { (calendar ?? Calendar.current).date(from: self) }
    public var isValidDate: Bool { date != nil }
    public var description: String {
        var parts: [String] = []
        for (n, v) in [("year", year), ("month", month), ("day", day), ("hour", hour), ("minute", minute), ("second", second), ("weekday", weekday)] {
            if let v { parts.append("\(n): \(v)") }
        }
        return parts.joined(separator: " ")
    }
}

extension DateComponents: Codable {
    enum CodingKeys: String, CodingKey { case era, year, month, day, hour, minute, second, nanosecond, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear, yearForWeekOfYear }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(era: try c.decodeIfPresent(Int.self, forKey: .era), year: try c.decodeIfPresent(Int.self, forKey: .year),
                  month: try c.decodeIfPresent(Int.self, forKey: .month), day: try c.decodeIfPresent(Int.self, forKey: .day),
                  hour: try c.decodeIfPresent(Int.self, forKey: .hour), minute: try c.decodeIfPresent(Int.self, forKey: .minute),
                  second: try c.decodeIfPresent(Int.self, forKey: .second), nanosecond: try c.decodeIfPresent(Int.self, forKey: .nanosecond),
                  weekday: try c.decodeIfPresent(Int.self, forKey: .weekday), weekdayOrdinal: try c.decodeIfPresent(Int.self, forKey: .weekdayOrdinal),
                  quarter: try c.decodeIfPresent(Int.self, forKey: .quarter), weekOfMonth: try c.decodeIfPresent(Int.self, forKey: .weekOfMonth),
                  weekOfYear: try c.decodeIfPresent(Int.self, forKey: .weekOfYear), yearForWeekOfYear: try c.decodeIfPresent(Int.self, forKey: .yearForWeekOfYear))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(era, forKey: .era); try c.encodeIfPresent(year, forKey: .year); try c.encodeIfPresent(month, forKey: .month)
        try c.encodeIfPresent(day, forKey: .day); try c.encodeIfPresent(hour, forKey: .hour); try c.encodeIfPresent(minute, forKey: .minute)
        try c.encodeIfPresent(second, forKey: .second); try c.encodeIfPresent(nanosecond, forKey: .nanosecond); try c.encodeIfPresent(weekday, forKey: .weekday)
        try c.encodeIfPresent(weekdayOrdinal, forKey: .weekdayOrdinal); try c.encodeIfPresent(quarter, forKey: .quarter)
        try c.encodeIfPresent(weekOfMonth, forKey: .weekOfMonth); try c.encodeIfPresent(weekOfYear, forKey: .weekOfYear)
        try c.encodeIfPresent(yearForWeekOfYear, forKey: .yearForWeekOfYear)
    }
}

public struct Calendar: Hashable, Sendable, CustomStringConvertible {
    public enum Identifier: String, Hashable, Sendable, Codable {
        case gregorian, buddhist, chinese, coptic, ethiopicAmeteMihret, ethiopicAmeteAlem, hebrew, iso8601, indian,
             islamic, islamicCivil, japanese, persian, republicOfChina, islamicTabular, islamicUmmAlQura
    }
    public enum Component: Hashable, Sendable {
        case era, year, month, day, hour, minute, second, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear,
             yearForWeekOfYear, nanosecond, calendar, timeZone, dayOfYear, isLeapMonth
    }
    public enum SearchDirection: Sendable { case forward, backward }
    public enum RepeatedTimePolicy: Sendable { case first, last }
    public enum MatchingPolicy: Sendable { case nextTime, nextTimePreservingSmallerComponents, previousTimePreservingSmallerComponents, strict }

    public let identifier: Identifier
    public var timeZone: TimeZone
    public var locale: Locale?
    public var firstWeekday: Int
    public var minimumDaysInFirstWeek: Int

    public init(identifier: Identifier) {
        self.identifier = identifier
        timeZone = .current
        locale = .current
        firstWeekday = identifier == .iso8601 ? 2 : Calendar.defaultFirstWeekday()
        minimumDaysInFirstWeek = identifier == .iso8601 ? 4 : 1
        if identifier != .gregorian && identifier != .iso8601 && !Calendar._icuAvailable {
            NSLog("isim Calendar: %@ calendar needs the host's ICU (libicu); using Gregorian rules", identifier.rawValue)
        }
    }
    /// the current locale's calendar ("th_TH@calendar=buddhist" -> Buddhist)
    public static var current: Calendar {
        Calendar(identifier: Calendar.Identifier(_icuName: NSLocale.__isim_current().calendarIdentifier) ?? .gregorian)
    }
    public static var autoupdatingCurrent: Calendar { current }
    static func defaultFirstWeekday() -> Int {
        // Monday in most regions; Sunday in the US, Canada, Japan, Brazil, Mexico, ... (CLDR weekData)
        let sundayFirst: Set<String> = ["US", "CA", "JP", "BR", "MX", "PH", "IL", "ZA", "KR", "TW", "HK", "IN", "SA", "AU", "AR", "CO", "PE", "VE", "GT", "SV", "HN", "NI", "PA", "DO", "PR", "KE", "TH"]
        return sundayFirst.contains(Locale.current.regionCode ?? "US") ? 1 : 2
    }
    public var description: String { "\(identifier) (\(timeZone.identifier))" }

    // MARK: core conversions
    func offset(_ d: Date) -> Int { timeZone.secondsFromGMT(for: d) }
    /// local wall-clock seconds since 1970 for a date
    func local(_ d: Date) -> Double { d.timeIntervalSince1970 + Double(offset(d)) }
    /// date for local wall-clock seconds (resolving DST gaps/overlaps to the first match)
    func dateFromLocal(_ l: Double) -> Date {
        var guess = Date(timeIntervalSince1970: l - Double(offset(Date(timeIntervalSince1970: l))))
        for _ in 0..<2 { guess = Date(timeIntervalSince1970: l - Double(offset(guess))) }
        return guess
    }
    struct Fields { var y, m, d, hh, mm, ss, ns, wd, doy: Int }
    func fields(_ date: Date) -> Fields {
        let l = local(date)
        let secs = floor(l)
        let days = Int(floor(secs / 86400))
        let rem = Int(secs - Double(days) * 86400)
        let (y, m, d) = _civil(fromDays: days)
        let wd = ((days % 7) + 7 + 4) % 7 + 1           // 1970-01-01 was a Thursday; 1 = Sunday
        let doy = days - _days(fromCivil: y, 1, 1) + 1
        return Fields(y: y, m: m, d: d, hh: rem / 3600, mm: rem / 60 % 60, ss: rem % 60, ns: Int(((l - secs) * 1e9).rounded()), wd: wd, doy: doy)
    }
    static func daysIn(_ y: Int, _ m: Int) -> Int {
        let dm = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
        return m == 2 && leap ? 29 : dm[(m - 1 + 1200) % 12]
    }

    // week numbering
    func weekOfYear(_ f: Fields) -> (week: Int, year: Int) {
        func firstWeekStart(_ y: Int) -> Int {     // day number (since 1970) where week 1 of year y starts
            let jan1 = _days(fromCivil: y, 1, 1)
            let wdJan1 = ((jan1 % 7) + 7 + 4) % 7 + 1
            let back = (wdJan1 - firstWeekday + 7) % 7      // days from week start to Jan 1
            let start = jan1 - back
            return 7 - back >= minimumDaysInFirstWeek ? start : start + 7
        }
        let day = _days(fromCivil: f.y, f.m, f.d)
        var y = f.y
        if day < firstWeekStart(y) { y -= 1 } else if day >= firstWeekStart(y + 1) { y += 1 }
        return ((day - firstWeekStart(y)) / 7 + 1, y)
    }

    // MARK: API
    public func dateComponents(_ components: Set<Component>, from date: Date) -> DateComponents {
        if _usesICU { return _icuComponents(components, from: date) }
        let f = fields(date)
        var c = DateComponents()
        if components.contains(.calendar) { c.calendar = self }
        if components.contains(.timeZone) { c.timeZone = timeZone }
        if components.contains(.era) { c.era = f.y > 0 ? 1 : 0 }
        if components.contains(.year) { c.year = f.y }
        if components.contains(.month) { c.month = f.m }
        if components.contains(.day) { c.day = f.d }
        if components.contains(.hour) { c.hour = f.hh }
        if components.contains(.minute) { c.minute = f.mm }
        if components.contains(.second) { c.second = f.ss }
        if components.contains(.nanosecond) { c.nanosecond = f.ns }
        if components.contains(.weekday) { c.weekday = f.wd }
        if components.contains(.weekdayOrdinal) { c.weekdayOrdinal = (f.d - 1) / 7 + 1 }
        if components.contains(.quarter) { c.quarter = (f.m - 1) / 3 + 1 }
        if components.contains(.dayOfYear) { c.dayOfYear = f.doy }
        if components.contains(.weekOfYear) || components.contains(.yearForWeekOfYear) {
            let w = weekOfYear(f)
            if components.contains(.weekOfYear) { c.weekOfYear = w.week }
            if components.contains(.yearForWeekOfYear) { c.yearForWeekOfYear = w.year }
        }
        if components.contains(.weekOfMonth) {
            let firstWd = ((_days(fromCivil: f.y, f.m, 1) % 7) + 7 + 4) % 7 + 1
            let lead = (firstWd - firstWeekday + 7) % 7
            c.weekOfMonth = (f.d - 1 + lead) / 7 + (7 - lead >= minimumDaysInFirstWeek ? 1 : 0)
        }
        if components.contains(.isLeapMonth) { c.isLeapMonth = false }
        return c
    }
    public func dateComponents(in timeZone: TimeZone, from date: Date) -> DateComponents {
        var cal = self; cal.timeZone = timeZone
        var c = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear], from: date)
        c.calendar = cal; c.timeZone = timeZone
        return c
    }
    public func component(_ c: Component, from date: Date) -> Int { dateComponents([c], from: date).value(for: c) ?? 0 }

    public func date(from c: DateComponents) -> Date? {
        if _usesICU { return _icuDate(from: c) }
        var cal = self
        if let tz = c.timeZone { cal.timeZone = tz }
        var y = c.year ?? 1, m = c.month ?? 1, d = c.day ?? 1
        if let yw = c.yearForWeekOfYear, let w = c.weekOfYear {
            // the given weekday (default: first day of the week) of week w of year yw
            let jan1 = _days(fromCivil: yw, 1, 1)
            let wdJan1 = ((jan1 % 7) + 7 + 4) % 7 + 1
            let back = (wdJan1 - firstWeekday + 7) % 7
            var start = jan1 - back
            if 7 - back < minimumDaysInFirstWeek { start += 7 }
            let wd = c.weekday ?? firstWeekday
            let day = start + (w - 1) * 7 + (wd - firstWeekday + 7) % 7
            (y, m, d) = _civil(fromDays: day)
        } else if let doy = c.dayOfYear, c.month == nil {
            (y, m, d) = _civil(fromDays: _days(fromCivil: y, 1, 1) + doy - 1)
        }
        // normalize month overflow
        y += Int(floor(Double(m - 1) / 12)); m = ((m - 1) % 12 + 12) % 12 + 1
        let days = _days(fromCivil: y, m, 1) + d - 1
        let secs = Double(days) * 86400 + Double(c.hour ?? 0) * 3600 + Double(c.minute ?? 0) * 60 + Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1e9
        return cal.dateFromLocal(secs)
    }

    public func startOfDay(for date: Date) -> Date {
        if _usesICU { return _icuStartOfDay(date) }
        let f = fields(date)
        return dateFromLocal(Double(_days(fromCivil: f.y, f.m, f.d)) * 86400)
    }

    public func date(byAdding component: Component, value: Int, to date: Date, wrappingComponents: Bool = false) -> Date? {
        var c = DateComponents(); c.setValue(value, for: component)
        return self.date(byAdding: c, to: date, wrappingComponents: wrappingComponents)
    }
    public func date(byAdding comps: DateComponents, to date: Date, wrappingComponents: Bool = false) -> Date? {
        if _usesICU { return _icuAdding(comps, to: date, wrapping: wrappingComponents) }
        var f = fields(date)
        // calendar units: years/months clamp the day (Jan 31 + 1 month = Feb 28/29)
        let addMonths = (comps.year ?? 0) * 12 + (comps.month ?? 0) + (comps.quarter ?? 0) * 3
        if addMonths != 0 {
            let total = f.y * 12 + (f.m - 1) + addMonths
            f.y = Int(floor(Double(total) / 12)); f.m = total - f.y * 12 + 1
            f.d = min(f.d, Calendar.daysIn(f.y, f.m))
        }
        var days = _days(fromCivil: f.y, f.m, f.d) + (comps.day ?? 0) + (comps.weekOfYear ?? 0) * 7 + (comps.weekOfMonth ?? 0) * 7 + (comps.weekday ?? 0)
        if comps.weekdayOrdinal != nil { days += (comps.weekdayOrdinal ?? 0) * 7 }
        let local = Double(days) * 86400 + Double(f.hh * 3600 + f.mm * 60 + f.ss) + Double(f.ns) / 1e9
        var result = dateFromLocal(local)
        // clock units are absolute time
        let clock = Double(comps.hour ?? 0) * 3600 + Double(comps.minute ?? 0) * 60 + Double(comps.second ?? 0) + Double(comps.nanosecond ?? 0) / 1e9
        result = result.addingTimeInterval(clock)
        return result
    }

    public func dateComponents(_ components: Set<Component>, from start: Date, to end: Date) -> DateComponents {
        var c = DateComponents()
        var cursor = start
        let forward = end >= start
        func step(_ comp: Component, _ unit: (Int) -> Date?) {
            guard components.contains(comp) else { return }
            // largest n with unit(n) not passing end
            var lo = 0, hi = 1
            while let d = unit(forward ? hi : -hi), forward ? d <= end : d >= end { lo = hi; hi *= 2; if hi > 1 << 40 { break } }
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                if let d = unit(forward ? mid : -mid), forward ? d <= end : d >= end { lo = mid } else { hi = mid }
            }
            let n = forward ? lo : -lo
            c.setValue(n, for: comp)
            cursor = unit(n) ?? cursor
        }
        step(.era) { _ in nil }
        step(.year) { [cursor] in self.date(byAdding: .year, value: $0, to: cursor) }
        step(.quarter) { [cursor] in self.date(byAdding: .month, value: $0 * 3, to: cursor) }
        step(.month) { [cursor] in self.date(byAdding: .month, value: $0, to: cursor) }
        step(.weekOfYear) { [cursor] in self.date(byAdding: .day, value: $0 * 7, to: cursor) }
        step(.weekOfMonth) { [cursor] in self.date(byAdding: .day, value: $0 * 7, to: cursor) }
        step(.day) { [cursor] in self.date(byAdding: .day, value: $0, to: cursor) }
        let rest = end.timeIntervalSince(cursor)
        var r = rest
        if components.contains(.hour) { let h = Int(r / 3600); c.hour = h; r -= Double(h) * 3600 }
        if components.contains(.minute) { let m = Int(r / 60); c.minute = m; r -= Double(m) * 60 }
        if components.contains(.second) { let s = Int(r); c.second = s; r -= Double(s) }
        if components.contains(.nanosecond) { c.nanosecond = Int((r * 1e9).rounded()) }
        if components.contains(.era) && c.era == nil { c.era = 0 }
        return c
    }
    public func dateComponents(_ components: Set<Component>, from start: DateComponents, to end: DateComponents) -> DateComponents {
        guard let a = date(from: start), let b = date(from: end) else { return DateComponents() }
        return dateComponents(components, from: a, to: b)
    }

    public func isDate(_ a: Date, inSameDayAs b: Date) -> Bool { startOfDay(for: a) == startOfDay(for: b) }
    public func isDateInToday(_ d: Date) -> Bool { isDate(d, inSameDayAs: Date()) }
    public func isDateInYesterday(_ d: Date) -> Bool { date(byAdding: .day, value: -1, to: Date()).map { isDate(d, inSameDayAs: $0) } ?? false }
    public func isDateInTomorrow(_ d: Date) -> Bool { date(byAdding: .day, value: 1, to: Date()).map { isDate(d, inSameDayAs: $0) } ?? false }
    public func isDateInWeekend(_ d: Date) -> Bool { let w = component(.weekday, from: d); return w == 1 || w == 7 }
    public func isDate(_ a: Date, equalTo b: Date, toGranularity c: Component) -> Bool { compare(a, to: b, toGranularity: c) == .orderedSame }
    public func compare(_ a: Date, to b: Date, toGranularity c: Component) -> ComparisonResult {
        let order: [Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond]
        let comps: Set<Component>
        switch c {
        case .weekOfYear, .weekOfMonth:
            let x = dateComponents([.yearForWeekOfYear, .weekOfYear], from: a), y = dateComponents([.yearForWeekOfYear, .weekOfYear], from: b)
            let k1 = (x.yearForWeekOfYear ?? 0, x.weekOfYear ?? 0), k2 = (y.yearForWeekOfYear ?? 0, y.weekOfYear ?? 0)
            return k1 < k2 ? .orderedAscending : k1 > k2 ? .orderedDescending : .orderedSame
        default:
            comps = Set(order.prefix(through: order.firstIndex(of: c) ?? order.count - 1))
        }
        let x = dateComponents(comps, from: a), y = dateComponents(comps, from: b)
        for k in order where comps.contains(k) {
            let p = x.value(for: k) ?? 0, q = y.value(for: k) ?? 0
            if p < q { return .orderedAscending }
            if p > q { return .orderedDescending }
        }
        return .orderedSame
    }
    public func date(bySettingHour h: Int, minute: Int, second: Int, of date: Date, matchingPolicy: MatchingPolicy = .nextTime,
                     repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward) -> Date? {
        if _usesICU {
            var c = _icuComponents([.era, .year, .month, .day, .isLeapMonth], from: date)
            c.hour = h; c.minute = minute; c.second = second
            return _icuDate(from: c)
        }
        let f = fields(date)
        return dateFromLocal(Double(_days(fromCivil: f.y, f.m, f.d)) * 86400 + Double(h * 3600 + minute * 60 + second))
    }
    public func date(bySetting c: Component, value: Int, of date: Date) -> Date? {
        var comps = dateComponents(_usesICU ? [.era, .year, .month, .day, .isLeapMonth, .hour, .minute, .second, .nanosecond] : [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        comps.setValue(value, for: c)
        return self.date(from: comps)
    }
    public func range(of smaller: Component, in larger: Component, for date: Date) -> Range<Int>? {
        if _usesICU { return _icuRange(of: smaller, in: larger, for: date) }
        let f = fields(date)
        switch (smaller, larger) {
        case (.day, .month): return 1..<(Calendar.daysIn(f.y, f.m) + 1)
        case (.day, .year): return 1..<(Calendar.daysIn(f.y, 2) == 29 ? 367 : 366)
        case (.month, .year): return 1..<13
        case (.hour, .day): return 0..<24
        case (.minute, .hour): return 0..<60
        case (.second, .minute): return 0..<60
        case (.weekday, .weekOfYear), (.weekday, .weekOfMonth): return 1..<8
        default: return nil
        }
    }
    public func dateInterval(of c: Component, for date: Date) -> DateInterval? {
        if _usesICU { return _icuInterval(of: c, for: date) }
        let f = fields(date)
        let start: Date, end: Date
        switch c {
        case .day: start = startOfDay(for: date); end = self.date(byAdding: .day, value: 1, to: start)!
        case .month: start = dateFromLocal(Double(_days(fromCivil: f.y, f.m, 1)) * 86400); end = self.date(byAdding: .month, value: 1, to: start)!
        case .year: start = dateFromLocal(Double(_days(fromCivil: f.y, 1, 1)) * 86400); end = self.date(byAdding: .year, value: 1, to: start)!
        case .weekOfYear, .weekOfMonth:
            let back = (f.wd - firstWeekday + 7) % 7
            start = dateFromLocal(Double(_days(fromCivil: f.y, f.m, f.d) - back) * 86400); end = self.date(byAdding: .day, value: 7, to: start)!
        case .hour:
            start = dateFromLocal(Double(_days(fromCivil: f.y, f.m, f.d)) * 86400 + Double(f.hh * 3600)); end = start.addingTimeInterval(3600)
        default: return nil
        }
        return DateInterval(start: start, end: end)
    }
    public func nextDate(after date: Date, matching comps: DateComponents, matchingPolicy: MatchingPolicy,
                         repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward) -> Date? {
        // walk day by day (bounded) and pick the first matching wall-clock time
        let sign = direction == .forward ? 1 : -1
        for n in 0..<(366 * 8) {
            guard let day = self.date(byAdding: .day, value: n * sign, to: startOfDay(for: date)) else { return nil }
            let f = dateComponents([.year, .month, .day, .weekday], from: day)
            if let m = comps.month, m != f.month { continue }
            if let d = comps.day, d != f.day { continue }
            if let w = comps.weekday, w != f.weekday { continue }
            if let y = comps.year, y != f.year { continue }
            guard let t = self.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: day) else { continue }
            if direction == .forward ? t > date : t < date { return t }
        }
        return nil
    }
    // symbols in the calendar's locale (and calendar system: Hebrew months, Japanese eras, ...)
    var _symbolFormatter: DateFormatter { let f = DateFormatter(); f.locale = locale ?? .current; f.calendar = self; return f }
    public var eraSymbols: [String] { _symbolFormatter.eraSymbols }
    public var longEraSymbols: [String] { _symbolFormatter.longEraSymbols }
    public var monthSymbols: [String] { _symbolFormatter.monthSymbols }
    public var shortMonthSymbols: [String] { _symbolFormatter.shortMonthSymbols }
    public var veryShortMonthSymbols: [String] { _symbolFormatter.veryShortMonthSymbols }
    public var standaloneMonthSymbols: [String] { _symbolFormatter.standaloneMonthSymbols }
    public var shortStandaloneMonthSymbols: [String] { _symbolFormatter.shortStandaloneMonthSymbols }
    public var veryShortStandaloneMonthSymbols: [String] { _symbolFormatter.veryShortStandaloneMonthSymbols }
    public var weekdaySymbols: [String] { _symbolFormatter.weekdaySymbols }
    public var shortWeekdaySymbols: [String] { _symbolFormatter.shortWeekdaySymbols }
    public var veryShortWeekdaySymbols: [String] { _symbolFormatter.veryShortWeekdaySymbols }
    public var standaloneWeekdaySymbols: [String] { _symbolFormatter.standaloneWeekdaySymbols }
    public var shortStandaloneWeekdaySymbols: [String] { _symbolFormatter.shortStandaloneWeekdaySymbols }
    public var veryShortStandaloneWeekdaySymbols: [String] { _symbolFormatter.veryShortStandaloneWeekdaySymbols }
    public var quarterSymbols: [String] { _symbolFormatter.quarterSymbols }
    public var shortQuarterSymbols: [String] { _symbolFormatter.shortQuarterSymbols }
    public var amSymbol: String { _symbolFormatter.amSymbol }
    public var pmSymbol: String { _symbolFormatter.pmSymbol }
}

public struct DateInterval: Hashable, Comparable, Sendable, Codable {
    public var start: Date
    public var duration: TimeInterval
    public var end: Date { start.addingTimeInterval(duration) }
    public init() { start = Date(); duration = 0 }
    public init(start: Date, end: Date) { self.start = start; duration = end.timeIntervalSince(start) }
    public init(start: Date, duration: TimeInterval) { self.start = start; self.duration = duration }
    public func contains(_ d: Date) -> Bool { d >= start && d <= end }
    public func intersects(_ o: DateInterval) -> Bool { start <= o.end && o.start <= end }
    public static func < (a: DateInterval, b: DateInterval) -> Bool { a.start < b.start || (a.start == b.start && a.duration < b.duration) }
}

extension Date: Codable {
    public init(from decoder: Decoder) throws { self.init(timeIntervalSinceReferenceDate: try decoder.singleValueContainer().decode(Double.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(timeIntervalSinceReferenceDate) }
}
