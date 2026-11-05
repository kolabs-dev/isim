// isim Foundation (issue #864): the rest of the date and number format styles.
// - DiscreteFormatStyle (iOS 18): the next / previous input whose output differs, for Date.FormatStyle,
//   Date.VerbatimFormatStyle, Date.ComponentsFormatStyle, Date.RelativeFormatStyle, Date.AnchoredRelativeFormatStyle.
// - Date.AnchoredRelativeFormatStyle, the relative style's allowed fields, the interval style's time zone, the components
//   style's calendar.
// - The date and number styles as regex components (CustomConsumingRegexComponent).
// - DateComponents.ISO8601FormatStyle and .HTTPFormatStyle, DateComponents.isValidDate(in:), formatted(_:),
//   init(_:strategy:); Calendar minimumRange / maximumRange, date(_:matchesComponents:), dateInterval(of:start:interval:for:),
//   the dates(byAdding:…) / dates(byMatching:…) sequences; Date.compare(_:), description(with:).
// Adapted: discrete inputs are found by stepping through the field the output changes with, at the format's smallest
// unit; regex components parse the longest prefix the parse strategy accepts.
import _StringProcessing

// MARK: - DiscreteFormatStyle

/// A format style whose output changes only at some inputs: the next and previous ones where it changes.
public protocol DiscreteFormatStyle<FormatInput, FormatOutput>: FormatStyle {
    func discreteInput(before input: FormatInput) -> FormatInput?
    func discreteInput(after input: FormatInput) -> FormatInput?
    func input(before input: FormatInput) -> FormatInput?
    func input(after input: FormatInput) -> FormatInput?
}
extension DiscreteFormatStyle where FormatInput == Date {
    public func input(before input: Date) -> Date? { input.nextDown }
    public func input(after input: Date) -> Date? { input.nextUp }
}
extension DiscreteFormatStyle where FormatInput == Duration {
    public func input(before input: Duration) -> Duration? { input - .nanoseconds(1) }
    public func input(after input: Duration) -> Duration? { input + .nanoseconds(1) }
}
extension DiscreteFormatStyle where FormatInput: BinaryInteger {
    public func input(before input: FormatInput) -> FormatInput? { input - 1 }
    public func input(after input: FormatInput) -> FormatInput? { input + 1 }
}
extension DiscreteFormatStyle where FormatInput: BinaryFloatingPoint {
    public func input(before input: FormatInput) -> FormatInput? { input.nextDown }
    public func input(after input: FormatInput) -> FormatInput? { input.nextUp }
}
extension DiscreteFormatStyle where FormatInput == Range<Date> {
    public func input(before input: Range<Date>) -> Range<Date>? { input.lowerBound.nextDown..<input.upperBound }
    public func input(after input: Range<Date>) -> Range<Date>? { input.lowerBound.nextUp..<input.upperBound }
}
extension Date {
    var nextUp: Date { Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextUp) }
    var nextDown: Date { Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextDown) }
}
/// the first date after (or before) `date`, at `step` seconds' resolution, where `format` gives other text
func _discreteDate(_ date: Date, step: TimeInterval, forward: Bool, limit: Int = 200_000, _ format: (Date) -> String) -> Date? {
    let base = format(date)
    // the boundary at or after the next step: find a date with other output, then narrow it down
    var lo = date, hi = date
    var n = 0
    repeat {
        hi = hi.addingTimeInterval(forward ? step : -step)
        n += 1
        if n > limit { return nil }
    } while format(hi) == base
    // bisect between lo (same output) and hi (other output) to a millisecond
    for _ in 0..<60 {
        let mid = Date(timeIntervalSinceReferenceDate: (lo.timeIntervalSinceReferenceDate + hi.timeIntervalSinceReferenceDate) / 2)
        if format(mid) == base { lo = mid } else { hi = mid }
        if Swift.abs(hi.timeIntervalSince(lo)) < 0.0005 { break }
    }
    return hi
}
extension Date.FormatStyle: DiscreteFormatStyle {
    /// the smallest unit the pattern shows
    var _step: TimeInterval {
        let p = pattern
        if p.contains("S") { return 0.001 }
        if p.contains("s") { return 1 }
        if p.contains("m") { return 60 }
        if p.contains(where: { "hHkKjJ".contains($0) }) { return 3600 }
        return 86400
    }
    public func discreteInput(before input: Date) -> Date? { _discreteDate(input, step: _step, forward: false, format) }
    public func discreteInput(after input: Date) -> Date? { _discreteDate(input, step: _step, forward: true, format) }
}
extension Date.VerbatimFormatStyle: DiscreteFormatStyle {
    var _step: TimeInterval {
        let p = formatPattern
        if p.contains("S") { return 0.001 }
        if p.contains("s") { return 1 }
        if p.contains("m") { return 60 }
        if p.contains(where: { "hHkK".contains($0) }) { return 3600 }
        return 86400
    }
    public func discreteInput(before input: Date) -> Date? { _discreteDate(input, step: _step, forward: false, format) }
    public func discreteInput(after input: Date) -> Date? { _discreteDate(input, step: _step, forward: true, format) }
}
extension Date.RelativeFormatStyle: DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date? { _discreteDate(input, step: 1, forward: false, limit: 400 * 86400) { self.format($0) } }
    public func discreteInput(after input: Date) -> Date? { _discreteDate(input, step: 1, forward: true, limit: 400 * 86400) { self.format($0) } }
}
extension Date.ComponentsFormatStyle: DiscreteFormatStyle {
    public func discreteInput(before input: Range<Date>) -> Range<Date>? {
        _discreteDate(input.upperBound, step: 1, forward: false) { self.format(input.lowerBound..<Swift.max(input.lowerBound, $0)) }.map { input.lowerBound..<$0 }
    }
    public func discreteInput(after input: Range<Date>) -> Range<Date>? {
        _discreteDate(input.upperBound, step: 1, forward: true) { self.format(input.lowerBound..<$0) }.map { input.lowerBound..<$0 }
    }
    /// whether the range runs forward (its upper bound is not before its lower bound)
    public var isPositive: Bool { true }
    public func calendar(_ calendar: Calendar) -> Self { var s = self; s.calendar = calendar; return s }
}

// MARK: - relative and interval styles

extension Date.RelativeFormatStyle {
    /// the units a relative date may be given in
    public struct Field: Codable, Hashable, Sendable {
        let unit: Int
        public static let year = Field(unit: 0), month = Field(unit: 1), week = Field(unit: 2), day = Field(unit: 3), hour = Field(unit: 4),
                          minute = Field(unit: 5), second = Field(unit: 6)
    }
    public init(allowedFields: Set<Field>, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent,
                calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
        self.init(presentation: presentation, unitsStyle: unitsStyle, locale: locale, calendar: calendar, capitalizationContext: capitalizationContext)
        self.allowedFields = allowedFields
    }
    /// the fields the relative date may use (the largest that fits); all of them unless set
    public var allowedFields: Set<Field> {
        get { _relativeFields[self._key] ?? [.year, .month, .week, .day, .hour, .minute, .second] }
        set { _relativeFieldsLock.lock(); _relativeFields[self._key] = newValue; _relativeFieldsLock.unlock() }
    }
    var _key: String { "\(presentation.raw)-\(unitsStyle.raw)-\(locale.identifier)-\(calendar.identifier)-\(capitalizationContext.raw)" }
    /// the relative text from the allowed fields: the largest allowed unit the interval spans
    func _formatAllowed(_ dest: Date, relativeTo ref: Date) -> String {
        let fields = allowedFields
        if fields.count == 7 { return format(dest, relativeTo: ref) }
        let comps: [(Field, Calendar.Component)] = [(.year, .year), (.month, .month), (.week, .weekOfYear), (.day, .day), (.hour, .hour), (.minute, .minute), (.second, .second)]
        let allowed = comps.filter { fields.contains($0.0) }
        guard let smallest = allowed.last else { return format(dest, relativeTo: ref) }
        for (_, c) in allowed {
            let v = calendar.dateComponents([c], from: ref, to: dest).value(for: c) ?? 0
            if v != 0 || c == smallest.1 {
                let f = RelativeDateTimeFormatter()
                f.locale = locale; f.calendar = calendar
                f.dateTimeStyle = presentation == .named ? .named : .numeric
                f.unitsStyle = [RelativeDateTimeFormatter.UnitsStyle.full, .spellOut, .short, .abbreviated][unitsStyle.raw]
                var dc = DateComponents(); dc.setValue(v, for: c)
                return f.localizedString(from: dc)
            }
        }
        return format(dest, relativeTo: ref)
    }
}
nonisolated(unsafe) private var _relativeFields: [String: Set<Date.RelativeFormatStyle.Field>] = [:]
private let _relativeFieldsLock = NSLock()

extension Date {
    /// A relative date ("in 2 hours") against a fixed anchor date rather than now.
    public struct AnchoredRelativeFormatStyle: Foundation.FormatStyle, DiscreteFormatStyle, Sendable {
        public typealias Field = Date.RelativeFormatStyle.Field
        public typealias Presentation = Date.RelativeFormatStyle.Presentation
        public typealias UnitsStyle = Date.RelativeFormatStyle.UnitsStyle
        public var anchor: Date
        public var allowedFields: Set<Field>
        public var presentation: Presentation
        public var unitsStyle: UnitsStyle
        public var locale: Locale
        public var calendar: Calendar
        public var capitalizationContext: FormatStyleCapitalizationContext
        public init(anchor: Date, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent,
                    calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.init(anchor: anchor, allowedFields: [.year, .month, .week, .day, .hour, .minute, .second], presentation: presentation, unitsStyle: unitsStyle,
                      locale: locale, calendar: calendar, capitalizationContext: capitalizationContext)
        }
        public init(anchor: Date, allowedFields: Set<Field>, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide,
                    locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.anchor = anchor; self.allowedFields = allowedFields; self.presentation = presentation; self.unitsStyle = unitsStyle
            self.locale = locale; self.calendar = calendar; self.capitalizationContext = capitalizationContext
        }
        var relative: Date.RelativeFormatStyle {
            Date.RelativeFormatStyle(allowedFields: allowedFields, presentation: presentation, unitsStyle: unitsStyle, locale: locale, calendar: calendar,
                                     capitalizationContext: capitalizationContext)
        }
        /// the date relative to the anchor
        public func format(_ input: Date) -> String {
            var out = relative._formatAllowed(input, relativeTo: anchor)
            if capitalizationContext == .beginningOfSentence || capitalizationContext == .standalone, let c = out.first { out = c.uppercased() + out.dropFirst() }
            return out
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public func discreteInput(before input: Date) -> Date? { _discreteDate(input, step: 1, forward: false, limit: 400 * 86400, format) }
        public func discreteInput(after input: Date) -> Date? { _discreteDate(input, step: 1, forward: true, limit: 400 * 86400, format) }
    }
}
extension Date.IntervalFormatStyle {
    public typealias Symbol = Date.FormatStyle.Symbol
    public func timeZone(_ format: Symbol.TimeZone = .specificName(.short)) -> Self { adding("z", format.run) }
}

// MARK: - regex components

/// the longest prefix of input[index..<bounds.upperBound] that `parse` accepts; with `exact`, a prefix that the parsed
/// value formats back to wins over a longer one (lenient parsers also accept text after the value)
func _consumeLongest<T>(_ input: String, from index: String.Index, in bounds: Range<String.Index>, upTo limit: String.Index? = nil,
                        exact: ((T) -> String)? = nil, _ parse: (String) throws -> T) -> (upperBound: String.Index, output: T)? {
    let top = limit.map { min($0, bounds.upperBound) } ?? bounds.upperBound
    var longest: (upperBound: String.Index, output: T)?
    var end = top
    while end > index {
        let candidate = String(input[index..<end])
        if let v = try? parse(candidate) {
            guard let exact else { return (end, v) }
            if exact(v) == candidate { return (end, v) }
            if longest == nil { longest = (end, v) }
        }
        end = input.index(before: end)
    }
    return longest
}
/// where the run of characters a number can be written with ends (digits, signs, separators, exponent, percent and the
/// currency's symbol); ordinary spaces end it
func _numberSpan(_ input: String, from index: String.Index, in bounds: Range<String.Index>, locale: Locale, currency: String? = nil) -> String.Index {
    var allowed = Set("0123456789+-\u{2212}.,'eE%\u{2030}\u{00A0}\u{202F}\u{066B}\u{066C}")
    allowed.formUnion(locale.decimalSeparator ?? ".")
    allowed.formUnion(locale.groupingSeparator ?? ",")
    if let currency {
        allowed.formUnion(currency)
        let f = NumberFormatter(); f.locale = locale; f.numberStyle = NumberFormatter.Style.currency; f.currencyCode = currency
        allowed.formUnion(f.currencySymbol ?? "")
    }
    var end = index
    while end < bounds.upperBound, input[end].isNumber || allowed.contains(input[end]) { end = input.index(after: end) }
    return end
}
extension Date.FormatStyle: CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        _consumeLongest(input, from: index, in: bounds, exact: { self.format($0) }) { try parseStrategy.parse($0) }
    }
    public func parse(_ value: String) throws -> Date { try parseStrategy.parse(value) }
}
extension Date.ISO8601FormatStyle: CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        _consumeLongest(input, from: index, in: bounds, exact: { self.format($0) }) { try parse($0) }
    }
}
extension Date.ParseStrategy: CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        _consumeLongest(input, from: index, in: bounds) { try parse($0) }
    }
    /// the pattern this strategy parses
    public var format: String { formatString }
    /// two-digit years are in the century starting here
    public var twoDigitStartDate: Date { Date(timeIntervalSince1970: 0) }
}
extension IntegerFormatStyle: CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        _consumeLongest(input, from: index, in: bounds, upTo: _numberSpan(input, from: index, in: bounds, locale: locale)) { try parseStrategy.parse($0) }
    }
}
extension IntegerFormatStyle.Percent: CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        _consumeLongest(input, from: index, in: bounds, upTo: _numberSpan(input, from: index, in: bounds, locale: locale)) { try parseStrategy.parse($0) }
    }
}
extension IntegerFormatStyle.Currency: CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        _consumeLongest(input, from: index, in: bounds, upTo: _numberSpan(input, from: index, in: bounds, locale: locale, currency: currencyCode)) { try parseStrategy.parse($0) }
    }
}
extension FloatingPointFormatStyle: CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        _consumeLongest(input, from: index, in: bounds, upTo: _numberSpan(input, from: index, in: bounds, locale: locale)) { try parseStrategy.parse($0) }
    }
}
extension FloatingPointFormatStyle.Percent: CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        _consumeLongest(input, from: index, in: bounds, upTo: _numberSpan(input, from: index, in: bounds, locale: locale)) { try parseStrategy.parse($0) }
    }
}
extension FloatingPointFormatStyle.Currency: CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        _consumeLongest(input, from: index, in: bounds, upTo: _numberSpan(input, from: index, in: bounds, locale: locale, currency: currencyCode)) { try parseStrategy.parse($0) }
    }
}

// MARK: - date components

extension DateComponents {
    /// Date components as ISO 8601 ("2026-10-06T11:04:05Z"), with the fields the style asks for.
    public struct ISO8601FormatStyle: Foundation.FormatStyle, ParseableFormatStyle, Foundation.ParseStrategy, Sendable {
        public typealias DateSeparator = Date.ISO8601FormatStyle.DateSeparator
        public typealias TimeSeparator = Date.ISO8601FormatStyle.TimeSeparator
        public typealias TimeZoneSeparator = Date.ISO8601FormatStyle.TimeZoneSeparator
        public typealias DateTimeSeparator = Date.ISO8601FormatStyle.DateTimeSeparator
        public var dateSeparator: DateSeparator
        public var dateTimeSeparator: DateTimeSeparator
        public var timeSeparator: TimeSeparator
        public var timeZoneSeparator: TimeZoneSeparator
        public var includingFractionalSeconds: Bool
        public var timeZone: TimeZone
        var fields: Set<String> = []
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeSeparator: TimeSeparator = .colon,
                    timeZoneSeparator: TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            self.dateSeparator = dateSeparator; self.dateTimeSeparator = dateTimeSeparator; self.timeSeparator = timeSeparator
            self.timeZoneSeparator = timeZoneSeparator; self.includingFractionalSeconds = includingFractionalSeconds; self.timeZone = timeZone
        }
        var dateStyle: Date.ISO8601FormatStyle {
            var s = Date.ISO8601FormatStyle(dateSeparator: dateSeparator, dateTimeSeparator: dateTimeSeparator, timeSeparator: timeSeparator,
                                            timeZoneSeparator: timeZoneSeparator, includingFractionalSeconds: includingFractionalSeconds, timeZone: timeZone)
            if !fields.isEmpty {
                if fields.contains("year") { s = s.year() }
                if fields.contains("month") { s = s.month() }
                if fields.contains("weekOfYear") { s = s.weekOfYear() }
                if fields.contains("day") { s = s.day() }
                if fields.contains("time") { s = s.time(includingFractionalSeconds: includingFractionalSeconds) }
                if fields.contains("timeZone") { s = s.timeZone(separator: timeZoneSeparator) }
            }
            return s
        }
        var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = timeZone; return c }
        public func format(_ value: DateComponents) -> String {
            var c = value; c.calendar = c.calendar ?? calendar; c.timeZone = c.timeZone ?? timeZone
            guard let d = calendar.date(from: c) else { return "" }
            return dateStyle.format(d)
        }
        public func parse(_ value: String) throws -> DateComponents {
            let d = try dateStyle.parse(value)
            return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond, .timeZone], from: d)
        }
        public var parseStrategy: Self { self }
        func with(_ f: String) -> Self { var s = self; s.fields.insert(f); return s }
        public func year() -> Self { with("year") }
        public func month() -> Self { with("month") }
        public func weekOfYear() -> Self { with("weekOfYear") }
        public func day() -> Self { with("day") }
        public func time(includingFractionalSeconds: Bool) -> Self { var s = with("time"); s.includingFractionalSeconds = includingFractionalSeconds; return s }
        public func timeZone(separator: TimeZoneSeparator) -> Self { var s = with("timeZone"); s.timeZoneSeparator = separator; return s }
        public func dateSeparator(_ separator: DateSeparator) -> Self { var s = self; s.dateSeparator = separator; return s }
        public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self { var s = self; s.dateTimeSeparator = separator; return s }
        public func timeSeparator(_ separator: TimeSeparator) -> Self { var s = self; s.timeSeparator = separator; return s }
        public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self { var s = self; s.timeZoneSeparator = separator; return s }
    }
    /// Date components as an HTTP date (RFC 9110's IMF-fixdate), in GMT.
    public struct HTTPFormatStyle: Foundation.FormatStyle, ParseableFormatStyle, Foundation.ParseStrategy, Sendable {
        public init() {}
        public func format(_ value: DateComponents) -> String {
            var cal = Calendar(identifier: .gregorian); cal.timeZone = value.timeZone ?? TimeZone(identifier: "GMT")!
            guard let d = cal.date(from: value) else { return "" }
            return Date.HTTPFormatStyle().format(d)
        }
        public func parse(_ value: String) throws -> DateComponents {
            let d = try Date.HTTPFormatStyle().parse(value)
            var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "GMT")!
            return cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday, .timeZone], from: d)
        }
        public var parseStrategy: Self { self }
    }
    /// whether the components make a real date in the calendar (no 31 April)
    public func isValidDate(in calendar: Calendar) -> Bool {
        var c = self; c.calendar = calendar
        guard let d = calendar.date(from: c) else { return false }
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
        for (v, b) in [(year, back.year), (month, back.month), (day, back.day), (hour, back.hour), (minute, back.minute), (second, back.second)] {
            if let v, v != b { return false }
        }
        return true
    }
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == DateComponents { format.format(self) }
    public init<T: Foundation.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == DateComponents { self = try strategy.parse(value) }
    @_disfavoredOverload
    public init<T: Foundation.ParseStrategy, Value: StringProtocol>(_ value: Value, strategy: T) throws where T.ParseOutput == DateComponents, T.ParseInput == String {
        self = try strategy.parse(String(value))
    }
}
extension FormatStyle where Self == DateComponents.ISO8601FormatStyle { public static var iso8601: Self { .init() } }
extension ParseStrategy where Self == DateComponents.ISO8601FormatStyle { public static var iso8601: Self { .init() } }
extension FormatStyle where Self == DateComponents.HTTPFormatStyle { public static var http: Self { .init() } }
extension ParseStrategy where Self == DateComponents.HTTPFormatStyle { public static var http: Self { .init() } }

// MARK: - calendars and dates

extension Calendar {
    /// the smallest range a component takes in any date of the calendar
    public func minimumRange(of component: Component) -> Range<Int>? {
        switch component {
        case .month: return 1..<13
        case .day: return 1..<29
        case .hour: return 0..<24
        case .minute, .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal: return 1..<5
        case .weekOfMonth: return 1..<5
        case .weekOfYear: return 1..<53
        case .quarter: return 1..<5
        case .era: return identifier == .gregorian || identifier == .iso8601 ? 0..<2 : 0..<1
        case .year: return 1..<140743
        case .nanosecond: return 0..<1_000_000_000
        default: return nil
        }
    }
    /// the largest range a component takes in any date of the calendar
    public func maximumRange(of component: Component) -> Range<Int>? {
        switch component {
        case .day: return 1..<32
        case .weekdayOrdinal: return 1..<6
        case .weekOfMonth: return 1..<7
        case .weekOfYear: return 1..<54
        default: return minimumRange(of: component)
        }
    }
    /// whether the date has every value the components give
    public func date(_ date: Date, matchesComponents components: DateComponents) -> Bool {
        let all: [Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth,
                                .weekOfYear, .yearForWeekOfYear]
        let have = dateComponents(Set(all), from: date)
        for c in all { if let v = components.value(for: c), v != have.value(for: c) { return false } }
        return true
    }
    /// the start and length of the unit containing the date
    public func dateInterval(of component: Component, start: inout Date, interval: inout TimeInterval, for date: Date) -> Bool {
        guard let i = dateInterval(of: component, for: date) else { return false }
        start = i.start; interval = i.duration
        return true
    }
    /// the dates `components` apart, starting at `start`, up to the range's end
    public func dates(byAdding components: DateComponents, startingAt start: Date, in range: Range<Date>? = nil,
                      wrappingComponents: Bool = false) -> some Sequence<Date> & Sendable {
        let cal = self
        return _CalendarDates(next: { i in
            var c = DateComponents()
            for comp: Component in [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekOfYear, .weekOfMonth, .weekday] {
                if let v = components.value(for: comp) { c.setValue(v * i, for: comp) }
            }
            return cal.date(byAdding: c, to: start, wrappingComponents: wrappingComponents)
        }, range: range)
    }
    public func dates(byAdding component: Component, value: Int = 1, startingAt start: Date, in range: Range<Date>? = nil,
                      wrappingComponents: Bool = false) -> some Sequence<Date> & Sendable {
        var c = DateComponents(); c.setValue(value, for: component)
        return dates(byAdding: c, startingAt: start, in: range, wrappingComponents: wrappingComponents)
    }
    /// the dates after (or before) `start` matching the components
    public func dates(byMatching components: DateComponents, startingAt start: Date, in range: Range<Date>? = nil, matchingPolicy: MatchingPolicy = .nextTime,
                      repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward) -> some Sequence<Date> & Sendable {
        let cal = self
        return _CalendarMatches(cal: cal, comps: components, start: start, range: range, policy: matchingPolicy, repeated: repeatedTimePolicy, direction: direction)
    }
}
struct _CalendarDates: Sequence, IteratorProtocol, Sendable {
    let step: @Sendable (Int) -> Date?
    let range: Range<Date>?
    var i = 0
    init(next: @escaping @Sendable (Int) -> Date?, range: Range<Date>?) { step = next; self.range = range }
    mutating func next() -> Date? {
        defer { i += 1 }
        guard let d = step(i) else { return nil }
        if let range, !range.contains(d) { return nil }
        return d
    }
}
struct _CalendarMatches: Sequence, IteratorProtocol, Sendable {
    let cal: Calendar, comps: DateComponents
    var current: Date
    let range: Range<Date>?, policy: Calendar.MatchingPolicy, repeated: Calendar.RepeatedTimePolicy, direction: Calendar.SearchDirection
    var first = true
    init(cal: Calendar, comps: DateComponents, start: Date, range: Range<Date>?, policy: Calendar.MatchingPolicy, repeated: Calendar.RepeatedTimePolicy,
         direction: Calendar.SearchDirection) {
        self.cal = cal; self.comps = comps; current = start; self.range = range; self.policy = policy; self.repeated = repeated; self.direction = direction
    }
    mutating func next() -> Date? {
        // the start itself when it matches, then each next match
        if first, cal.date(current, matchesComponents: comps) { first = false; return within(current) }
        first = false
        guard let d = cal.nextDate(after: current, matching: comps, matchingPolicy: policy, repeatedTimePolicy: repeated, direction: direction) else { return nil }
        current = d
        return within(d)
    }
    func within(_ d: Date) -> Date? { if let range, !range.contains(d) { return nil }; return d }
}
extension Date {
    public func compare(_ other: Date) -> ComparisonResult { self < other ? .orderedAscending : self > other ? .orderedDescending : .orderedSame }
    /// the date in the locale's full date and time ("Tuesday, October 6, 2026 at 11:04:05 AM Coordinated Universal Time")
    public func description(with locale: Locale?) -> String {
        let f = DateFormatter()
        f.locale = locale ?? Locale(identifier: "en_US_POSIX")
        f.dateStyle = .full; f.timeStyle = .full
        return f.string(from: self)
    }
}
