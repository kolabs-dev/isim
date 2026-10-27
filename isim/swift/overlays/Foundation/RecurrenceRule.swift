// isim Foundation: Calendar.RecurrenceRule (iOS 18): repeating dates in the manner of RFC 5545's RRULE (frequency,
// interval, end, BYMONTH / BYWEEKNO / BYYEARDAY / BYMONTHDAY / BYDAY / BYHOUR / BYMINUTE / BYSECOND / BYSETPOS).
// Self-authored, iOS API names. Adapted: the dates are computed with isim's Calendar; a day that does not exist in a
// month (the 31st) follows the rule's matching policy.

extension Calendar {
    public struct RecurrenceRule: Codable, Hashable, Sendable {
        public enum Frequency: Int, Codable, Hashable, Sendable { case minutely = 1, hourly, daily, weekly, monthly, yearly }

        /// When the recurrence stops: never, after a date, or after a number of occurrences.
        public struct End: Codable, Hashable, Sendable, CustomStringConvertible {
            public private(set) var date: Date?
            public private(set) var occurrences: Int?
            public static var never: End { End(date: nil, occurrences: nil) }
            public static func afterDate(_ date: Date) -> End { End(date: date, occurrences: nil) }
            public static func afterOccurrences(_ count: Int) -> End { End(date: nil, occurrences: count) }
            public var description: String {
                if let date { return "afterDate(\(date))" }
                if let occurrences { return "afterOccurrences(\(occurrences))" }
                return "never"
            }
        }
        /// A month (1-based), or a leap month in calendars that have them.
        public struct Month: Codable, Hashable, Sendable, ExpressibleByIntegerLiteral {
            public var index: Int
            public var isLeap: Bool
            public init(_ index: Int, isLeap: Bool = false) { self.index = index; self.isLeap = isLeap }
            public init(integerLiteral value: Int) { self.init(value) }
        }
        /// A weekday, every one or the nth in the month (or year); negative n counts from the end.
        public enum Weekday: Codable, Hashable, Sendable {
            case every(Locale.Weekday)
            case nth(Int, Locale.Weekday)
        }

        public var calendar: Calendar
        public var frequency: Frequency
        public var interval: Int
        public var end: End
        public var matchingPolicy: Calendar.MatchingPolicy
        public var repeatedTimePolicy: Calendar.RepeatedTimePolicy
        public var months: [Month]
        public var daysOfTheYear: [Int]
        public var daysOfTheMonth: [Int]
        public var weeks: [Int]
        public var weekdays: [Weekday]
        public var hours: [Int]
        public var minutes: [Int]
        public var seconds: [Int]
        public var setPositions: [Int]

        public init(calendar: Calendar, frequency: Frequency, interval: Int = 1, end: End = .never,
                    matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first,
                    months: [Month] = [], daysOfTheYear: [Int] = [], daysOfTheMonth: [Int] = [], weeks: [Int] = [], weekdays: [Weekday] = [],
                    hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) {
            self.calendar = calendar; self.frequency = frequency; self.interval = max(1, interval); self.end = end
            self.matchingPolicy = matchingPolicy; self.repeatedTimePolicy = repeatedTimePolicy
            self.months = months; self.daysOfTheYear = daysOfTheYear; self.daysOfTheMonth = daysOfTheMonth; self.weeks = weeks
            self.weekdays = weekdays; self.hours = hours; self.minutes = minutes; self.seconds = seconds; self.setPositions = setPositions
        }

        public static func minutely(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                                    repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheYear: [Int] = [],
                                    daysOfTheMonth: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [],
                                    setPositions: [Int] = []) -> RecurrenceRule {
            RecurrenceRule(calendar: calendar, frequency: .minutely, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy,
                           months: months, daysOfTheYear: daysOfTheYear, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes,
                           seconds: seconds, setPositions: setPositions)
        }
        public static func hourly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                                  repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheYear: [Int] = [],
                                  daysOfTheMonth: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [],
                                  setPositions: [Int] = []) -> RecurrenceRule {
            RecurrenceRule(calendar: calendar, frequency: .hourly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy,
                           months: months, daysOfTheYear: daysOfTheYear, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes,
                           seconds: seconds, setPositions: setPositions)
        }
        public static func daily(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                                 repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheMonth: [Int] = [],
                                 weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> RecurrenceRule {
            RecurrenceRule(calendar: calendar, frequency: .daily, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy,
                           months: months, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        public static func weekly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                                  repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], weekdays: [Weekday] = [], hours: [Int] = [],
                                  minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> RecurrenceRule {
            RecurrenceRule(calendar: calendar, frequency: .weekly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy,
                           months: months, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        public static func monthly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                                   repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheMonth: [Int] = [],
                                   weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> RecurrenceRule {
            RecurrenceRule(calendar: calendar, frequency: .monthly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy,
                           months: months, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        public static func yearly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                                  repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheYear: [Int] = [],
                                  daysOfTheMonth: [Int] = [], weeks: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [],
                                  seconds: [Int] = [], setPositions: [Int] = []) -> RecurrenceRule {
            RecurrenceRule(calendar: calendar, frequency: .yearly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy,
                           months: months, daysOfTheYear: daysOfTheYear, daysOfTheMonth: daysOfTheMonth, weeks: weeks, weekdays: weekdays, hours: hours,
                           minutes: minutes, seconds: seconds, setPositions: setPositions)
        }

        /// The dates the rule repeats `start` on (the start itself when it matches), in `range` when one is given.
        public func recurrences(of start: Date, in range: Range<Date>? = nil) -> some Sendable & Sequence<Date> {
            _Recurrences(rule: self, start: start, lower: range?.lowerBound, upper: range?.upperBound, upperIncluded: false)
        }
        public func recurrences(of start: Date, in range: ClosedRange<Date>) -> some Sendable & Sequence<Date> {
            _Recurrences(rule: self, start: start, lower: range.lowerBound, upper: range.upperBound, upperIncluded: true)
        }
        public func recurrences(of start: Date, in range: PartialRangeFrom<Date>) -> some Sendable & Sequence<Date> {
            _Recurrences(rule: self, start: start, lower: range.lowerBound, upper: nil, upperIncluded: false)
        }
        public func recurrences(of start: Date, in range: PartialRangeUpTo<Date>) -> some Sendable & Sequence<Date> {
            _Recurrences(rule: self, start: start, lower: nil, upper: range.upperBound, upperIncluded: false)
        }
        public func recurrences(of start: Date, in range: PartialRangeThrough<Date>) -> some Sendable & Sequence<Date> {
            _Recurrences(rule: self, start: start, lower: nil, upper: range.upperBound, upperIncluded: true)
        }
    }
}

struct _Recurrences: Sequence, Sendable {
    let rule: Calendar.RecurrenceRule
    let start: Date
    let lower: Date?, upper: Date?
    let upperIncluded: Bool

    func makeIterator() -> Iterator { Iterator(self) }

    struct Iterator: IteratorProtocol {
        let s: _Recurrences
        var period = 0                     /* how many intervals after the start's period */
        var pending: [Date] = []
        var emitted = 0                    /* occurrences so far (counted from the start, for afterOccurrences) */
        var done = false
        var empty = 0                      /* periods in a row without a candidate (an impossible rule ends) */
        init(_ s: _Recurrences) { self.s = s }

        mutating func next() -> Date? {
            while !done {
                if let d = pending.first {
                    pending.removeFirst()
                    if let n = s.rule.end.occurrences, emitted >= n { done = true; return nil }
                    if let e = s.rule.end.date, d > e { done = true; return nil }
                    if let u = s.upper, s.upperIncluded ? d > u : d >= u { done = true; return nil }
                    emitted += 1
                    if let l = s.lower, d < l { continue }
                    return d
                }
                let dates = candidates(period)
                period += 1
                if let anchor = periodStart(period - 1) {
                    if let e = s.rule.end.date, anchor > e, dates.isEmpty { done = true }
                    if let u = s.upper, anchor > u, dates.isEmpty { done = true }
                } else { done = true }
                if dates.isEmpty { empty += 1; if empty > 2000 { done = true } } else { empty = 0 }
                pending = dates.filter { $0 >= s.start }
            }
            return nil
        }

        var cal: Calendar { s.rule.calendar }
        var unit: Calendar.Component {
            switch s.rule.frequency {
            case .minutely: return .minute
            case .hourly: return .hour
            case .daily: return .day
            case .weekly: return .weekOfYear
            case .monthly: return .month
            case .yearly: return .year
            }
        }
        /// the start of the k-th period (the start's period moved by k intervals)
        func periodStart(_ k: Int) -> Date? {
            guard let first = cal.dateInterval(of: unit, for: s.start)?.start else { return nil }
            return cal.date(byAdding: unit, value: k * s.rule.interval, to: first)
        }

        /// the occurrences in the k-th period, in order, after BYSETPOS
        func candidates(_ k: Int) -> [Date] {
            guard let pStart = periodStart(k), let interval = cal.dateInterval(of: unit, for: pStart) else { return [] }
            let r = s.rule
            let startComps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: s.start)
            // the days of the period that match
            var days: [Date] = []
            if [.yearly, .monthly, .weekly].contains(r.frequency) {
                var d = cal.startOfDay(for: interval.start)
                while d < interval.end {
                    days.append(d)
                    guard let n = cal.date(byAdding: .day, value: 1, to: d) else { break }
                    d = n
                }
                let dayRules = !r.daysOfTheYear.isEmpty || !r.daysOfTheMonth.isEmpty || !r.weekdays.isEmpty || !r.weeks.isEmpty
                if !dayRules {             /* the start's day: its date in the year or month, its weekday in the week */
                    switch r.frequency {
                    case .yearly:
                        let months = r.months.isEmpty ? [startComps.month ?? 1] : r.months.map(\.index)
                        days = months.compactMap { dayIn(year: cal.component(.year, from: pStart), month: $0, day: startComps.day ?? 1) }
                    case .monthly:
                        let c = cal.dateComponents([.year, .month], from: pStart)
                        days = [dayIn(year: c.year ?? 1, month: c.month ?? 1, day: startComps.day ?? 1)].compactMap { $0 }
                    default:
                        days = days.filter { cal.component(.weekday, from: $0) == startComps.weekday }
                    }
                }
                days = days.filter { matches($0, dayRules: dayRules) }
            } else {
                let day = cal.startOfDay(for: interval.start)
                days = matches(day, dayRules: true) ? [day] : []
            }
            // the times of those days
            let hours = r.frequency.rawValue > Calendar.RecurrenceRule.Frequency.hourly.rawValue
                ? (r.hours.isEmpty ? [startComps.hour ?? 0] : r.hours) : [cal.component(.hour, from: interval.start)]
            let minutes = r.frequency.rawValue > Calendar.RecurrenceRule.Frequency.minutely.rawValue
                ? (r.minutes.isEmpty ? [startComps.minute ?? 0] : r.minutes) : [cal.component(.minute, from: interval.start)]
            let seconds = r.seconds.isEmpty ? [startComps.second ?? 0] : r.seconds
            var out: [Date] = []
            for day in days {
                for h in hours.sorted() where r.frequency.rawValue > 2 || r.hours.isEmpty || r.hours.contains(h) {
                    for m in minutes.sorted() where r.frequency != .minutely || r.minutes.isEmpty || r.minutes.contains(m) {
                        for sec in seconds.sorted() {
                            var c = cal.dateComponents([.year, .month, .day], from: day)
                            c.hour = h; c.minute = m; c.second = sec
                            if let d = cal.date(from: c), d >= interval.start, d < interval.end || r.frequency.rawValue >= 3 { out.append(d) }
                        }
                    }
                }
            }
            out = Array(Set(out)).sorted()
            if !r.setPositions.isEmpty {
                out = r.setPositions.compactMap { p in
                    let i = p > 0 ? p - 1 : out.count + p
                    return i >= 0 && i < out.count ? out[i] : nil
                }.sorted()
            }
            return out
        }

        /// a date in the month, with the matching policy for a day the month does not have (the 31st)
        func dayIn(year: Int, month: Int, day: Int) -> Date? {
            guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
                  let count = cal.range(of: .day, in: .month, for: first)?.count else { return nil }
            if day <= count { return cal.date(from: DateComponents(year: year, month: month, day: day)) }
            switch s.rule.matchingPolicy {
            case .strict: return nil
            case .previousTimePreservingSmallerComponents: return cal.date(from: DateComponents(year: year, month: month, day: count))
            default: return cal.date(byAdding: .month, value: 1, to: first)
            }
        }

        /// whether a day passes the rule's BYxxx filters
        func matches(_ day: Date, dayRules: Bool) -> Bool {
            let r = s.rule
            let c = cal.dateComponents([.month, .day, .weekday], from: day)
            if !r.months.isEmpty, !r.months.contains(where: { $0.index == c.month }) { return false }
            guard dayRules else { return true }
            if !r.weeks.isEmpty {
                let w = cal.component(.weekOfYear, from: day)
                let weeksInYear = cal.range(of: .weekOfYear, in: .yearForWeekOfYear, for: day)?.count ?? 52
                if !r.weeks.contains(where: { $0 > 0 ? $0 == w : weeksInYear + $0 + 1 == w }) { return false }
            }
            if !r.daysOfTheYear.isEmpty {
                let ord = cal.ordinality(of: .day, in: .year, for: day) ?? 0
                let count = cal.range(of: .day, in: .year, for: day)?.count ?? 365
                if !r.daysOfTheYear.contains(where: { $0 > 0 ? $0 == ord : count + $0 + 1 == ord }) { return false }
            }
            if !r.daysOfTheMonth.isEmpty {
                let count = cal.range(of: .day, in: .month, for: day)?.count ?? 31
                if !r.daysOfTheMonth.contains(where: { $0 > 0 ? $0 == c.day : count + $0 + 1 == c.day }) { return false }
            }
            if !r.weekdays.isEmpty {
                // the nth weekday counts in the month (monthly, or yearly with months) or the year
                let scope: Calendar.Component = r.frequency == .monthly || (r.frequency == .yearly && !r.months.isEmpty) ? .month : .year
                let ok = r.weekdays.contains { w in
                    switch w {
                    case .every(let wd): return wd._number == c.weekday
                    case .nth(let n, let wd):
                        guard wd._number == c.weekday, let span = cal.dateInterval(of: scope, for: day) else { return false }
                        let daysBefore = cal.dateComponents([.day], from: span.start, to: day).day ?? 0
                        let daysAfter = (cal.dateComponents([.day], from: day, to: span.end).day ?? 1) - 1
                        return n > 0 ? daysBefore / 7 + 1 == n : -(daysAfter / 7 + 1) == n
                    }
                }
                if !ok { return false }
            }
            return true
        }
    }
}
