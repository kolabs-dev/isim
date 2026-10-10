// isim Foundation: Date.FormatStyle (.dateTime builders, .formatted(date:time:)), Date.ISO8601FormatStyle,
// Date.RelativeFormatStyle, Date.IntervalFormatStyle, Date.ComponentsFormatStyle, Date.ParseStrategy and
// Calendar/DateComponents/PersonNameComponents bridging. Patterns come from Foundation's DateFormatter
// (skeleton -> locale pattern), so output follows the device region like iOS.

// MARK: - Calendar <-> NSCalendar, DateComponents <-> NSDateComponents
extension Calendar: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSCalendar {
        let c = NSCalendar(calendarIdentifier: NSCalendar.Identifier(rawValue: identifier._icuName))!
        c.timeZone = timeZone; c.locale = locale; c.firstWeekday = firstWeekday; c.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        return c
    }
    public static func _forceBridgeFromObjectiveC(_ x: NSCalendar, result: inout Calendar?) {
        var c = Calendar(identifier: Calendar.Identifier(_icuName: x.calendarIdentifier.rawValue) ?? .gregorian)
        c.timeZone = x.timeZone; c.locale = x.locale; c.firstWeekday = Int(x.firstWeekday); c.minimumDaysInFirstWeek = Int(x.minimumDaysInFirstWeek)
        result = c
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSCalendar, result: inout Calendar?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSCalendar?) -> Calendar {
        var r: Calendar?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? .current
    }
}
extension DateComponents: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSDateComponents {
        let c = NSDateComponents()
        let u = Int.max   // NSDateComponentUndefined
        c.calendar = calendar; c.timeZone = timeZone
        c.era = era ?? u; c.year = year ?? u; c.month = month ?? u; c.day = day ?? u; c.hour = hour ?? u; c.minute = minute ?? u
        c.second = second ?? u; c.nanosecond = nanosecond ?? u; c.weekday = weekday ?? u; c.weekdayOrdinal = weekdayOrdinal ?? u
        c.quarter = quarter ?? u; c.weekOfMonth = weekOfMonth ?? u; c.weekOfYear = weekOfYear ?? u; c.yearForWeekOfYear = yearForWeekOfYear ?? u
        return c
    }
    public static func _forceBridgeFromObjectiveC(_ x: NSDateComponents, result: inout DateComponents?) {
        func v(_ i: Int) -> Int? { i == Int.max ? nil : i }
        var d = DateComponents(calendar: x.calendar, timeZone: x.timeZone, era: v(x.era), year: v(x.year), month: v(x.month), day: v(x.day),
                               hour: v(x.hour), minute: v(x.minute), second: v(x.second), nanosecond: v(x.nanosecond), weekday: v(x.weekday),
                               weekdayOrdinal: v(x.weekdayOrdinal), quarter: v(x.quarter), weekOfMonth: v(x.weekOfMonth), weekOfYear: v(x.weekOfYear),
                               yearForWeekOfYear: v(x.yearForWeekOfYear))
        d.calendar = x.calendar
        result = d
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSDateComponents, result: inout DateComponents?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSDateComponents?) -> DateComponents {
        var r: DateComponents?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? DateComponents()
    }
}

// MARK: - PersonNameComponents (value type bridged to NSPersonNameComponents)
public struct PersonNameComponents: Hashable, Sendable, Codable, CustomStringConvertible {
    public var namePrefix: String?
    public var givenName: String?
    public var middleName: String?
    public var familyName: String?
    public var nameSuffix: String?
    public var nickname: String?
    public var phoneticRepresentation: PersonNameComponents? {
        get { _phonetic?.first }
        set { _phonetic = newValue.map { [$0] } }
    }
    var _phonetic: [PersonNameComponents]?
    public init() {}
    public init(namePrefix: String? = nil, givenName: String? = nil, middleName: String? = nil, familyName: String? = nil, nameSuffix: String? = nil,
                nickname: String? = nil, phoneticRepresentation: PersonNameComponents? = nil) {
        self.namePrefix = namePrefix; self.givenName = givenName; self.middleName = middleName; self.familyName = familyName
        self.nameSuffix = nameSuffix; self.nickname = nickname; self.phoneticRepresentation = phoneticRepresentation
    }
    public var description: String { PersonNameComponentsFormatter().string(from: self) }
    public func formatted() -> String { FormatStyle().format(self) }
    public func formatted<S: Foundation.FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == PersonNameComponents { style.format(self) }
    public struct FormatStyle: Foundation.FormatStyle, Sendable {
        public enum Style: Int, Codable, Hashable, Sendable { case short, medium, long, abbreviated }
        public var style: Style
        public var locale: Locale
        public init(style: Style = .medium, locale: Locale = .autoupdatingCurrent) { self.style = style; self.locale = locale }
        public func format(_ value: PersonNameComponents) -> String {
            let f = PersonNameComponentsFormatter()
            f.style = style == .short ? .short : style == .long ? .long : style == .abbreviated ? .abbreviated : .medium
            return f.string(from: value)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
}
extension PersonNameComponents: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSPersonNameComponents {
        let c = NSPersonNameComponents()
        c.namePrefix = namePrefix; c.givenName = givenName; c.middleName = middleName; c.familyName = familyName; c.nameSuffix = nameSuffix
        c.nickname = nickname; c.phoneticRepresentation = phoneticRepresentation
        return c
    }
    public static func _forceBridgeFromObjectiveC(_ x: NSPersonNameComponents, result: inout PersonNameComponents?) {
        var p = PersonNameComponents(namePrefix: x.namePrefix, givenName: x.givenName, middleName: x.middleName, familyName: x.familyName, nameSuffix: x.nameSuffix, nickname: x.nickname)
        p.phoneticRepresentation = x.phoneticRepresentation
        result = p
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSPersonNameComponents, result: inout PersonNameComponents?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSPersonNameComponents?) -> PersonNameComponents {
        var r: PersonNameComponents?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? PersonNameComponents()
    }
}
extension FormatStyle where Self == PersonNameComponents.FormatStyle {
    public static func name(style: PersonNameComponents.FormatStyle.Style) -> Self { .init(style: style) }
}

// MARK: - Date.FormatStyle
extension Date {
    public struct FormatStyle: Foundation.FormatStyle, Sendable {
        public var locale: Locale
        public var timeZone: TimeZone
        public var calendar: Calendar
        public var capitalizationContext: FormatStyleCapitalizationContext
        var symbols: [String: String] = [:]          // field letter -> skeleton run
        var dateStyle: DateStyle?
        var timeStyle: TimeStyle?

        public init(date: DateStyle? = nil, time: TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent,
                    timeZone: TimeZone = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.locale = locale; self.timeZone = timeZone; self.calendar = calendar; self.capitalizationContext = capitalizationContext
            dateStyle = date; timeStyle = time
        }
        public struct DateStyle: Codable, Hashable, Sendable {
            let raw: Int
            public static let omitted = DateStyle(raw: 0), numeric = DateStyle(raw: 1), abbreviated = DateStyle(raw: 2), long = DateStyle(raw: 3), complete = DateStyle(raw: 4)
        }
        public struct TimeStyle: Codable, Hashable, Sendable {
            let raw: Int
            public static let omitted = TimeStyle(raw: 0), shortened = TimeStyle(raw: 1), standard = TimeStyle(raw: 2), complete = TimeStyle(raw: 3)
        }
        /// the skeleton (e.g. "yMMMdjmm") this style asks for
        var skeleton: String {
            var s = ""
            switch dateStyle?.raw ?? 0 {
            case 1: s += "yMd"
            case 2: s += "yMMMd"
            case 3: s += "yMMMMd"
            case 4: s += "yMMMMEEEEd"
            default: break
            }
            switch timeStyle?.raw ?? 0 {
            case 1: s += "jmm"
            case 2: s += "jmmss"
            case 3: s += "jmmssz"
            default: break
            }
            for key in ["G", "y", "Q", "M", "w", "d", "D", "E", "a", "j", "m", "s", "S", "z"] { if let v = symbols[key] { s += v } }
            if s.isEmpty { s = "yMdjmm" }
            return s
        }
        var pattern: String {
            let f = DateFormatter(); f.locale = locale; f.calendar = calendar
            f.setLocalizedDateFormatFromTemplate(skeleton)
            return f.dateFormat ?? skeleton
        }
        public func format(_ value: Date) -> String {
            let f = DateFormatter()
            f.locale = locale; f.timeZone = timeZone; f.calendar = calendar
            f.setLocalizedDateFormatFromTemplate(skeleton)
            var out = f.string(from: value)
            if capitalizationContext == .beginningOfSentence || capitalizationContext == .standalone || capitalizationContext == .listItem, let first = out.first {
                out = first.uppercased() + out.dropFirst()
            }
            return out
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        func adding(_ key: String, _ run: String) -> Self { var s = self; s.symbols[key] = run; return s }

        public func era(_ format: Symbol.Era = .abbreviated) -> Self { adding("G", format.run) }
        public func year(_ format: Symbol.Year = .defaultDigits) -> Self { adding("y", format.run) }
        public func quarter(_ format: Symbol.Quarter = .abbreviated) -> Self { adding("Q", format.run) }
        public func month(_ format: Symbol.Month = .abbreviated) -> Self { adding("M", format.run) }
        public func week(_ format: Symbol.Week = .defaultDigits) -> Self { adding("w", format.run) }
        public func day(_ format: Symbol.Day = .defaultDigits) -> Self { adding("d", format.run) }
        public func dayOfYear(_ format: Symbol.DayOfYear = .defaultDigits) -> Self { adding("D", format.run) }
        public func weekday(_ format: Symbol.Weekday = .abbreviated) -> Self { adding("E", format.run) }
        public func dayPeriod(_ format: Symbol.DayPeriod = .standard(.abbreviated)) -> Self { adding("a", format.run) }
        public func hour(_ format: Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self { adding("j", format.run) }
        public func minute(_ format: Symbol.Minute = .defaultDigits) -> Self { adding("m", format.run) }
        public func second(_ format: Symbol.Second = .defaultDigits) -> Self { adding("s", format.run) }
        public func secondFraction(_ format: Symbol.SecondFraction) -> Self { adding("S", format.run) }
        public func timeZone(_ format: Symbol.TimeZone = .specificName(.short)) -> Self { adding("z", format.run) }

        public enum Symbol {
            public struct Era: Codable, Hashable, Sendable { let run: String
                public static let abbreviated = Era(run: "G"), wide = Era(run: "GGGG"), narrow = Era(run: "GGGGG") }
            public struct Year: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = Year(run: "y"), twoDigits = Year(run: "yy"), extended = Year(run: "u")
                public static func padded(_ length: Int) -> Year { Year(run: String(repeating: "y", count: Swift.max(1, Swift.min(length, 10)))) }
                public static func extended(minimumLength: Int) -> Year { Year(run: String(repeating: "u", count: Swift.max(1, minimumLength))) }
                public static func relatedGregorian(minimumLength: Int = 1) -> Year { padded(minimumLength) } }
            public struct Quarter: Codable, Hashable, Sendable { let run: String
                public static let oneDigit = Quarter(run: "Q"), twoDigits = Quarter(run: "QQ"), abbreviated = Quarter(run: "QQQ"), wide = Quarter(run: "QQQQ"), narrow = Quarter(run: "QQQQQ") }
            public struct Month: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = Month(run: "M"), twoDigits = Month(run: "MM"), abbreviated = Month(run: "MMM"), wide = Month(run: "MMMM"), narrow = Month(run: "MMMMM") }
            public struct Week: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = Week(run: "w"), twoDigits = Week(run: "ww"), weekOfMonth = Week(run: "W") }
            public struct Day: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = Day(run: "d"), twoDigits = Day(run: "dd"), ordinalOfDayInMonth = Day(run: "F")
                public static func julianModified(minimumLength: Int = 1) -> Day { Day(run: "g") } }
            public struct DayOfYear: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = DayOfYear(run: "D"), twoDigits = DayOfYear(run: "DD"), threeDigits = DayOfYear(run: "DDD") }
            public struct Weekday: Codable, Hashable, Sendable { let run: String
                public static let abbreviated = Weekday(run: "EEE"), wide = Weekday(run: "EEEE"), narrow = Weekday(run: "EEEEE"), short = Weekday(run: "EEEEEE"), oneDigit = Weekday(run: "e"), twoDigits = Weekday(run: "ee") }
            public struct DayPeriod: Codable, Hashable, Sendable { let run: String
                public enum Width: Int, Codable, Hashable, Sendable { case abbreviated, wide, narrow }
                public static func standard(_ w: Width) -> DayPeriod { DayPeriod(run: "a") }
                public static func with12s(_ w: Width) -> DayPeriod { DayPeriod(run: "b") }
                public static func conversational(_ w: Width) -> DayPeriod { DayPeriod(run: "B") } }
            public struct Hour: Codable, Hashable, Sendable { let run: String
                public struct AMPMStyle: Codable, Hashable, Sendable { let shown: Bool
                    public static let omitted = AMPMStyle(shown: false), narrow = AMPMStyle(shown: true), abbreviated = AMPMStyle(shown: true), wide = AMPMStyle(shown: true) }
                public static func defaultDigits(amPM: AMPMStyle) -> Hour { Hour(run: amPM.shown ? "j" : "J") }
                public static func twoDigits(amPM: AMPMStyle) -> Hour { Hour(run: amPM.shown ? "jj" : "JJ") }
                public static func conversationalDefaultDigits(amPM: AMPMStyle) -> Hour { Hour(run: amPM.shown ? "j" : "J") }
                public static func conversationalTwoDigits(amPM: AMPMStyle) -> Hour { Hour(run: amPM.shown ? "jj" : "JJ") }
                public static var defaultDigitsNoAMPM: Hour { Hour(run: "J") }
                public static var twoDigitsNoAMPM: Hour { Hour(run: "JJ") } }
            public struct Minute: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = Minute(run: "m"), twoDigits = Minute(run: "mm") }
            public struct Second: Codable, Hashable, Sendable { let run: String
                public static let defaultDigits = Second(run: "s"), twoDigits = Second(run: "ss") }
            public struct SecondFraction: Codable, Hashable, Sendable { let run: String
                public static func fractional(_ n: Int) -> SecondFraction { SecondFraction(run: String(repeating: "S", count: Swift.max(1, n))) }
                public static func milliseconds(_ n: Int) -> SecondFraction { SecondFraction(run: "A") } }
            public struct TimeZone: Codable, Hashable, Sendable { let run: String
                public enum Width: Int, Codable, Hashable, Sendable { case short, long }
                public static func specificName(_ w: Width) -> TimeZone { TimeZone(run: w == .short ? "z" : "zzzz") }
                public static func genericName(_ w: Width) -> TimeZone { TimeZone(run: w == .short ? "v" : "vvvv") }
                public static func iso8601(_ w: Width) -> TimeZone { TimeZone(run: w == .short ? "Z" : "ZZZZZ") }
                public static func localizedGMT(_ w: Width) -> TimeZone { TimeZone(run: w == .short ? "O" : "OOOO") }
                public static func identifier(_ w: Width) -> TimeZone { TimeZone(run: "VV") }
                public static func exemplarLocation(_ w: Width) -> TimeZone { TimeZone(run: "VVV") }
                public static var genericLocation: TimeZone { TimeZone(run: "VVVV") } }
        }
    }
    public func formatted() -> String { FormatStyle(date: .numeric, time: .shortened).format(self) }
    public func formatted(date: FormatStyle.DateStyle, time: FormatStyle.TimeStyle) -> String { FormatStyle(date: date, time: time).format(self) }
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Date { format.format(self) }
    public init<T: Foundation.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Date { self = try strategy.parse(value) }
}
public struct FormatStyleCapitalizationContext: Codable, Hashable, Sendable {
    let raw: Int
    public static let unknown = Self(raw: 0), standalone = Self(raw: 1), listItem = Self(raw: 2), beginningOfSentence = Self(raw: 3), middleOfSentence = Self(raw: 4)
}
extension FormatStyle where Self == Date.FormatStyle {
    public static var dateTime: Self { Date.FormatStyle() }
}
extension Date.FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Date.ParseStrategy { Date.ParseStrategy(format: pattern, locale: locale, timeZone: timeZone, calendar: calendar) }
}

// MARK: - Date.ParseStrategy and Date.FormatString
extension Date {
    public struct ParseStrategy: Foundation.ParseStrategy, Sendable {
        public var formatString: String
        public var locale: Locale?
        public var timeZone: TimeZone
        public var calendar: Calendar
        public var isLenient: Bool
        init(format: String, locale: Locale?, timeZone: TimeZone, calendar: Calendar) {
            formatString = format; self.locale = locale; self.timeZone = timeZone; self.calendar = calendar; isLenient = true
        }
        public init(format: FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar = Calendar(identifier: .gregorian), isLenient: Bool = true, twoDigitStartDate: Date = Date(timeIntervalSince1970: 0)) {
            formatString = format.rawFormat; self.locale = locale; self.timeZone = timeZone; self.calendar = calendar; self.isLenient = isLenient
        }
        public func parse(_ value: String) throws -> Date {
            let f = DateFormatter()
            f.locale = locale ?? Locale(identifier: "en_US_POSIX"); f.timeZone = timeZone; f.dateFormat = formatString; f.isLenient = isLenient
            guard let d = f.date(from: value) else { throw _parseError(value, "a date") }
            return d
        }
    }
    /// A date pattern built with string interpolation: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)".
    public struct FormatString: Hashable, Sendable, ExpressibleByStringInterpolation {
        var rawFormat: String
        public init(stringLiteral value: String) { rawFormat = FormatString.quote(value) }
        public init(stringInterpolation: StringInterpolation) { rawFormat = stringInterpolation.format }
        static func quote(_ s: String) -> String {
            s.isEmpty ? "" : s.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) ? "'" + s.replacingOccurrences(of: "'", with: "''") + "'" : s
        }
        public struct StringInterpolation: StringInterpolationProtocol {
            var format = ""
            public init(literalCapacity: Int, interpolationCount: Int) {}
            public mutating func appendLiteral(_ literal: String) { format += FormatString.quote(literal) }
            public mutating func appendInterpolation(era: Date.FormatStyle.Symbol.Era) { format += era.run }
            public mutating func appendInterpolation(year: Date.FormatStyle.Symbol.Year) { format += year.run }
            public mutating func appendInterpolation(quarter: Date.FormatStyle.Symbol.Quarter) { format += quarter.run }
            public mutating func appendInterpolation(month: Date.FormatStyle.Symbol.Month) { format += month.run }
            public mutating func appendInterpolation(week: Date.FormatStyle.Symbol.Week) { format += week.run }
            public mutating func appendInterpolation(day: Date.FormatStyle.Symbol.Day) { format += day.run }
            public mutating func appendInterpolation(dayOfYear: Date.FormatStyle.Symbol.DayOfYear) { format += dayOfYear.run }
            public mutating func appendInterpolation(weekday: Date.FormatStyle.Symbol.Weekday) { format += weekday.run }
            public mutating func appendInterpolation(dayPeriod: Date.FormatStyle.Symbol.DayPeriod) { format += "a" }
            public mutating func appendInterpolation(hour: Date.FormatStyle.Symbol.Hour) { format += hour.run.hasPrefix("J") ? (hour.run.count == 2 ? "HH" : "H") : (hour.run.count == 2 ? "hh" : "h") }
            public mutating func appendInterpolation(minute: Date.FormatStyle.Symbol.Minute) { format += minute.run }
            public mutating func appendInterpolation(second: Date.FormatStyle.Symbol.Second) { format += second.run }
            public mutating func appendInterpolation(secondFraction: Date.FormatStyle.Symbol.SecondFraction) { format += secondFraction.run }
            public mutating func appendInterpolation(timeZone: Date.FormatStyle.Symbol.TimeZone) { format += timeZone.run }
        }
    }
}
extension ParseStrategy where Self == Date.ParseStrategy {
    public static func fixed(format: Date.FormatString, timeZone: TimeZone, locale: Locale? = nil) -> Self { Date.ParseStrategy(format: format, locale: locale, timeZone: timeZone) }
}

// MARK: - Date.ISO8601FormatStyle
extension Date {
    public struct ISO8601FormatStyle: Foundation.FormatStyle, ParseableFormatStyle, Foundation.ParseStrategy, Sendable {
        public enum DateSeparator: String, Codable, Hashable, Sendable { case dash = "-", omitted = "" }
        public enum TimeSeparator: String, Codable, Hashable, Sendable { case colon = ":", omitted = "" }
        public enum TimeZoneSeparator: String, Codable, Hashable, Sendable { case colon = ":", omitted = "" }
        public enum DateTimeSeparator: String, Codable, Hashable, Sendable { case space = " ", standard = "'T'" }
        public var timeZone: TimeZone
        public private(set) var dateSeparator: DateSeparator
        public private(set) var dateTimeSeparator: DateTimeSeparator
        public private(set) var timeSeparator: TimeSeparator
        public private(set) var timeZoneSeparator: TimeZoneSeparator
        public private(set) var includingFractionalSeconds: Bool
        var fields: Set<String> = []          // empty = full internet date time
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeSeparator: TimeSeparator = .colon,
                    timeZoneSeparator: TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            self.dateSeparator = dateSeparator; self.dateTimeSeparator = dateTimeSeparator; self.timeSeparator = timeSeparator
            self.timeZoneSeparator = timeZoneSeparator; self.includingFractionalSeconds = includingFractionalSeconds; self.timeZone = timeZone
        }
        var options: ISO8601DateFormatter.Options {
            var o: ISO8601DateFormatter.Options = []
            let f = fields.isEmpty ? ["year", "month", "day", "time", "timeZone"] : fields
            if f.contains("year") { o.insert(.withYear) }
            if f.contains("month") { o.insert(.withMonth) }
            if f.contains("weekOfYear") { o.insert(.withWeekOfYear) }
            if f.contains("day") { o.insert(.withDay) }
            if f.contains("time") { o.insert(.withTime) }
            if f.contains("timeZone") { o.insert(.withTimeZone) }
            if dateSeparator == .dash { o.insert(.withDashSeparatorInDate) }
            if timeSeparator == .colon { o.insert(.withColonSeparatorInTime) }
            if timeZoneSeparator == .colon { o.insert(.withColonSeparatorInTimeZone) }
            if dateTimeSeparator == .space { o.insert(.withSpaceBetweenDateAndTime) }
            if includingFractionalSeconds { o.insert(.withFractionalSeconds) }
            return o
        }
        public func format(_ value: Date) -> String {
            let f = ISO8601DateFormatter(); f.timeZone = timeZone; f.formatOptions = options
            return f.string(from: value)
        }
        public func parse(_ value: String) throws -> Date {
            let f = ISO8601DateFormatter(); f.timeZone = timeZone; f.formatOptions = options
            if let d = f.date(from: value) { return d }
            f.formatOptions.formSymmetricDifference(.withFractionalSeconds)
            guard let d = f.date(from: value) else { throw _parseError(value, "an ISO 8601 date") }
            return d
        }
        public var parseStrategy: Self { self }
        func with(_ field: String) -> Self { var s = self; s.fields.insert(field); return s }
        public func year() -> Self { with("year") }
        public func weekOfYear() -> Self { with("weekOfYear") }
        public func month() -> Self { with("month") }
        public func day() -> Self { with("day") }
        public func time(includingFractionalSeconds: Bool) -> Self { var s = with("time"); s.includingFractionalSeconds = includingFractionalSeconds; return s }
        public func timeZone(separator: TimeZoneSeparator) -> Self { var s = with("timeZone"); s.timeZoneSeparator = separator; return s }
        public func dateSeparator(_ separator: DateSeparator) -> Self { var s = self; s.dateSeparator = separator; return s }
        public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self { var s = self; s.dateTimeSeparator = separator; return s }
        public func timeSeparator(_ separator: TimeSeparator) -> Self { var s = self; s.timeSeparator = separator; return s }
        public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self { var s = self; s.timeZoneSeparator = separator; return s }
    }
    public func ISO8601Format(_ style: ISO8601FormatStyle = .init()) -> String { style.format(self) }
}
extension FormatStyle where Self == Date.ISO8601FormatStyle { public static var iso8601: Self { .init() } }
extension ParseStrategy where Self == Date.ISO8601FormatStyle { public static var iso8601: Self { .init() } }

// MARK: - Date.RelativeFormatStyle
extension Date {
    public struct RelativeFormatStyle: Foundation.FormatStyle, Sendable {
        public struct UnitsStyle: Codable, Hashable, Sendable {
            let raw: Int
            public static let wide = UnitsStyle(raw: 0), spellOut = UnitsStyle(raw: 1), abbreviated = UnitsStyle(raw: 2), narrow = UnitsStyle(raw: 3)
        }
        public struct Presentation: Codable, Hashable, Sendable {
            let raw: Int
            public static let numeric = Presentation(raw: 0), named = Presentation(raw: 1)
        }
        public var presentation: Presentation
        public var unitsStyle: UnitsStyle
        public var capitalizationContext: FormatStyleCapitalizationContext
        public var locale: Locale
        public var calendar: Calendar
        public init(presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent,
                    calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.presentation = presentation; self.unitsStyle = unitsStyle; self.locale = locale; self.calendar = calendar; self.capitalizationContext = capitalizationContext
        }
        public func format(_ destDate: Date) -> String { format(destDate, relativeTo: Date()) }
        func format(_ destDate: Date, relativeTo ref: Date) -> String {
            let f = RelativeDateTimeFormatter()
            f.locale = locale
            f.calendar = calendar
            f.dateTimeStyle = presentation == .named ? .named : .numeric
            f.unitsStyle = [RelativeDateTimeFormatter.UnitsStyle.full, .spellOut, .short, .abbreviated][unitsStyle.raw]
            var out = f.localizedString(for: destDate, relativeTo: ref)
            if capitalizationContext == .beginningOfSentence || capitalizationContext == .standalone, let c = out.first { out = c.uppercased() + out.dropFirst() }
            return out
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
    public func formatted(_ style: RelativeFormatStyle) -> String { style.format(self) }
}
extension FormatStyle where Self == Date.RelativeFormatStyle {
    public static func relative(presentation: Date.RelativeFormatStyle.Presentation, unitsStyle: Date.RelativeFormatStyle.UnitsStyle = .wide) -> Self {
        .init(presentation: presentation, unitsStyle: unitsStyle)
    }
}

// MARK: - date ranges
extension Date {
    public struct IntervalFormatStyle: Foundation.FormatStyle, Sendable {
        public typealias DateStyle = Date.FormatStyle.DateStyle
        public typealias TimeStyle = Date.FormatStyle.TimeStyle
        public var locale: Locale
        public var timeZone: TimeZone
        public var calendar: Calendar
        var dateStyle: DateStyle?
        var timeStyle: TimeStyle?
        var symbols: [String: String] = [:]
        public init(date: DateStyle? = nil, time: TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) {
            dateStyle = date; timeStyle = time; self.locale = locale; self.calendar = calendar; self.timeZone = timeZone
        }
        public func format(_ v: Range<Date>) -> String {
            let f = DateIntervalFormatter()
            f.locale = locale; f.timeZone = timeZone
            if !symbols.isEmpty || (dateStyle == nil && timeStyle == nil) {
                var sk = ""
                for key in ["y", "M", "d", "E", "j", "m", "s"] { if let s = symbols[key] { sk += s } }
                f.dateTemplate = sk.isEmpty ? "yMdjmm" : sk
            } else {
                let ds = dateStyle?.raw ?? 0, ts = timeStyle?.raw ?? 0
                f.dateStyle = DateIntervalFormatter.Style(rawValue: UInt(ds == 0 ? 0 : ds == 1 ? 1 : ds == 2 ? 2 : ds == 3 ? 3 : 4)) ?? .none
                f.timeStyle = DateIntervalFormatter.Style(rawValue: UInt(ts == 0 ? 0 : ts == 1 ? 1 : ts == 2 ? 2 : 3)) ?? .none
            }
            return f.string(from: v.lowerBound, to: v.upperBound)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        func adding(_ k: String, _ r: String) -> Self { var s = self; s.symbols[k] = r; return s }
        public func year() -> Self { adding("y", "y") }
        public func month(_ format: Date.FormatStyle.Symbol.Month = .abbreviated) -> Self { adding("M", format.run) }
        public func day() -> Self { adding("d", "d") }
        public func weekday(_ format: Date.FormatStyle.Symbol.Weekday = .abbreviated) -> Self { adding("E", format.run) }
        public func hour(_ format: Date.FormatStyle.Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self { adding("j", format.run) }
        public func minute() -> Self { adding("m", "mm") }
        public func second() -> Self { adding("s", "ss") }
    }
    public struct ComponentsFormatStyle: Foundation.FormatStyle, Sendable {
        public struct Style: Codable, Hashable, Sendable {
            let raw: Int
            public static let wide = Style(raw: 0), abbreviated = Style(raw: 1), condensedAbbreviated = Style(raw: 2), narrow = Style(raw: 3), spellOut = Style(raw: 4)
        }
        public struct Field: Codable, Hashable, Sendable {
            let index: Int
            public static let year = Field(index: 0), month = Field(index: 1), week = Field(index: 2), day = Field(index: 3), hour = Field(index: 4), minute = Field(index: 5), second = Field(index: 6)
        }
        public var style: Style
        public var locale: Locale
        public var calendar: Calendar
        public var fields: Set<Field>?
        public init(style: Style, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, fields: Set<Field>? = nil) {
            self.style = style; self.locale = locale; self.calendar = calendar; self.fields = fields
        }
        public func format(_ v: Range<Date>) -> String {
            let f = DateComponentsFormatter()
            var cal = calendar; cal.locale = locale
            f.calendar = cal
            f.unitsStyle = [DateComponentsFormatter.UnitsStyle.full, .short, .abbreviated, .abbreviated, .spellOut][style.raw]
            if let fields {
                var u: NSCalendar.Unit = []
                let all: [NSCalendar.Unit] = [.year, .month, .weekOfMonth, .day, .hour, .minute, .second]
                for fld in fields { u.insert(all[fld.index]) }
                f.allowedUnits = u
            }
            return f.string(from: v.lowerBound, to: v.upperBound) ?? ""
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
}
extension Range where Bound == Date {
    public func formatted() -> String { Date.IntervalFormatStyle(date: .numeric, time: .shortened).format(self) }
    public func formatted(date: Date.IntervalFormatStyle.DateStyle, time: Date.IntervalFormatStyle.TimeStyle) -> String { Date.IntervalFormatStyle(date: date, time: time).format(self) }
    public func formatted<S: FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == Range<Date> { style.format(self) }
}
extension FormatStyle where Self == Date.IntervalFormatStyle { public static var interval: Self { .init() } }
extension FormatStyle where Self == Date.ComponentsFormatStyle {
    public static func components(style: Date.ComponentsFormatStyle.Style, fields: Set<Date.ComponentsFormatStyle.Field>? = nil) -> Self { .init(style: style, fields: fields) }
}
extension DateInterval {
    public func formatted() -> String { (start..<end).formatted() }
}
