// isim Foundation (issue #864): attributed format styles and the attributes of formatted values.
// - The attributes: dateField, numberFormat (numberPart, numberSymbol), measurement, byteCount, durationField,
//   personNameComponent, listItemDelimiter.
// - The attributed styles: IntegerFormatStyle / FloatingPointFormatStyle / Decimal.FormatStyle (and their percent and
//   currency forms) .attributed, ByteCountFormatStyle.Attributed, Measurement.AttributedStyle, Date.FormatStyle.Attributed,
//   Date.AttributedStyle, Date.VerbatimFormatStyle.
// - The rest of Date.FormatStyle's symbols: standalone month / quarter / weekday, cyclic year, year for week of year,
//   verbatim hours, `omitted`.
// Adapted: an attributed string has the same text as the plain style's output; its runs come from the pattern (dates:
// each field formatted on its own) or from the locale's symbols (numbers: digits, separators, sign, percent, currency).

// MARK: - the attributes

extension AttributeScopes.FoundationAttributes {
    public enum DateFieldAttribute: CodableAttributedStringKey, Sendable {
        public typealias Value = Field
        public static let name = "Foundation.DateFormatField"
        public enum Field: Hashable, Codable, Sendable {
            case era, year, relatedGregorianYear, quarter, month, weekOfYear, weekOfMonth, weekday, weekdayOrdinal, day, dayOfYear, amPM, hour, minute,
                 second, secondFraction, timeZone
        }
    }
    public struct NumberFormatAttributes: AttributeScope, Sendable {
        public let numberSymbol: SymbolAttribute
        public let numberPart: NumberPartAttribute
        public enum NumberPartAttribute: CodableAttributedStringKey, Sendable {
            public typealias Value = NumberPart
            public static let name = "Foundation.NumberFormatPart"
            public enum NumberPart: Int, Hashable, Codable, Sendable { case integer, fraction }
        }
        public enum SymbolAttribute: CodableAttributedStringKey, Sendable {
            public typealias Value = Symbol
            public static let name = "Foundation.NumberFormatSymbol"
            public enum Symbol: Int, Hashable, Codable, Sendable { case groupingSeparator, sign, decimalSeparator, currency, percent }
        }
    }
    public enum MeasurementAttribute: CodableAttributedStringKey, Sendable {
        public typealias Value = Component
        public static let name = "Foundation.MeasurementAttribute"
        public enum Component: Int, Hashable, Codable, Sendable { case value, unit }
    }
    public enum ByteCountAttribute: CodableAttributedStringKey, Sendable {
        public typealias Value = Component
        public static let name = "Foundation.ByteCountAttribute"
        public enum Unit: Hashable, Codable, Sendable { case byte, kb, mb, gb, tb, pb, eb, zb, yb }
        public enum Component: Hashable, Codable, Sendable { case value, spelledOutValue, unit(Unit), actualByteCount }
    }
    public enum DurationFieldAttribute: CodableAttributedStringKey, Sendable {
        public typealias Value = Field
        public static let name = "Foundation.DurationFieldAttribute"
        public enum Field: Int, Hashable, Codable, Sendable { case weeks, days, hours, minutes, seconds, milliseconds, microseconds, nanoseconds }
    }
    public enum PersonNameComponentAttribute: CodableAttributedStringKey, Sendable {
        public typealias Value = Component
        public static let name = "NSPersonNameComponentKey"
        public enum Component: Int, Hashable, Codable, Sendable { case givenName, familyName, middleName, namePrefix, nameSuffix, nickname, delimiter }
    }
    public enum ListItemDelimiterAttribute: CodableAttributedStringKey, Sendable {
        public typealias Value = Character
        public static let name = "NSListItemDelimiter"
    }
}
extension Character: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let c = s.first, s.count == 1 else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not one character")) }
        self = c
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(String(self)) }
}

// MARK: - numbers

typealias _NumberPart = AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute
typealias _NumberSymbol = AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute

/// The runs of a formatted number: digits as integer / fraction parts, the locale's separators, sign, percent and
/// currency symbols.
func _attributedNumber(_ text: String, locale: Locale, currency: Bool = false) -> AttributedString {
    let dec = Character(locale.decimalSeparator ?? "."), grp = locale.groupingSeparator.flatMap { $0.first } ?? ","
    let chars = Array(text)
    let firstDigit = chars.firstIndex { $0.isNumber }, lastDigit = chars.lastIndex { $0.isNumber }
    var out = AttributedString()
    var seenDecimal = false
    var run = "", runPart: _NumberPart.Value?, runSymbol: _NumberSymbol.Value?
    func flush() {
        guard !run.isEmpty else { return }
        var c = AttributeContainer()
        c[_NumberPart.self] = runPart; c[_NumberSymbol.self] = runSymbol
        out.append(AttributedString(run, attributes: c))
        run = ""
    }
    for (i, ch) in chars.enumerated() {
        var part: _NumberPart.Value? = nil, symbol: _NumberSymbol.Value? = nil
        let inNumber = firstDigit.map { i >= $0 } == true && lastDigit.map { i <= $0 } == true
        if ch.isNumber { part = seenDecimal ? .fraction : .integer }
        else if inNumber && ch == dec { symbol = .decimalSeparator; seenDecimal = true }
        else if inNumber && (ch == grp || (grp.isWhitespace && ch.isWhitespace)) { symbol = .groupingSeparator; part = .integer }
        else if ch == "-" || ch == "+" || ch == "\u{2212}" || ch == "(" || ch == ")" { symbol = .sign }
        else if ch == "%" || ch == "\u{066A}" { symbol = .percent }
        else if currency && !ch.isWhitespace && !ch.isNumber { symbol = .currency }
        if part != runPart || symbol != runSymbol { flush(); runPart = part; runSymbol = symbol }
        run.append(ch)
    }
    flush()
    return out
}

extension IntegerFormatStyle {
    /// The number as an attributed string (numberPart, numberSymbol).
    public struct Attributed: FormatStyle, Sendable {
        enum Style: Codable, Hashable, Sendable { case integer(IntegerFormatStyle), percent(IntegerFormatStyle.Percent), currency(IntegerFormatStyle.Currency) }
        var style: Style
        public func format(_ value: Value) -> AttributedString {
            switch style {
            case .integer(let s): return _attributedNumber(s.format(value), locale: s.locale)
            case .percent(let s): return _attributedNumber(s.format(value), locale: s.locale)
            case .currency(let s): return _attributedNumber(s.format(value), locale: s.locale, currency: true)
            }
        }
        public func locale(_ locale: Locale) -> Self {
            switch style {
            case .integer(let s): return .init(style: .integer(s.locale(locale)))
            case .percent(let s): return .init(style: .percent(s.locale(locale)))
            case .currency(let s): return .init(style: .currency(s.locale(locale)))
            }
        }
    }
    public var attributed: Attributed { Attributed(style: .integer(self)) }
}
extension IntegerFormatStyle.Percent {
    public typealias Configuration = NumberFormatStyleConfiguration
    public var attributed: IntegerFormatStyle<Value>.Attributed { .init(style: .percent(self)) }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self { var s = self; s.collection.decimalSeparatorStrategy = strategy; return s }
}
extension IntegerFormatStyle.Currency {
    public var attributed: IntegerFormatStyle<Value>.Attributed { .init(style: .currency(self)) }
    public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
}
extension FloatingPointFormatStyle {
    public struct Attributed: FormatStyle, Sendable {
        enum Style: Codable, Hashable, Sendable { case number(FloatingPointFormatStyle), percent(FloatingPointFormatStyle.Percent), currency(FloatingPointFormatStyle.Currency) }
        var style: Style
        public func format(_ value: Value) -> AttributedString {
            switch style {
            case .number(let s): return _attributedNumber(s.format(value), locale: s.locale)
            case .percent(let s): return _attributedNumber(s.format(value), locale: s.locale)
            case .currency(let s): return _attributedNumber(s.format(value), locale: s.locale, currency: true)
            }
        }
        public func locale(_ locale: Locale) -> Self {
            switch style {
            case .number(let s): return .init(style: .number(s.locale(locale)))
            case .percent(let s): return .init(style: .percent(s.locale(locale)))
            case .currency(let s): return .init(style: .currency(s.locale(locale)))
            }
        }
    }
    public var attributed: Attributed { Attributed(style: .number(self)) }
}
extension FloatingPointFormatStyle.Percent {
    public typealias Configuration = NumberFormatStyleConfiguration
    public var attributed: FloatingPointFormatStyle<Value>.Attributed { .init(style: .percent(self)) }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self { var s = self; s.collection.decimalSeparatorStrategy = strategy; return s }
}
extension FloatingPointFormatStyle.Currency {
    public var attributed: FloatingPointFormatStyle<Value>.Attributed { .init(style: .currency(self)) }
    public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
}
extension Decimal.FormatStyle {
    public struct Attributed: Foundation.FormatStyle, Sendable {
        enum Style: Codable, Hashable, Sendable { case number(Decimal.FormatStyle), percent(Decimal.FormatStyle.Percent), currency(Decimal.FormatStyle.Currency) }
        var style: Style
        public func format(_ value: Decimal) -> AttributedString {
            switch style {
            case .number(let s): return _attributedNumber(s.format(value), locale: s.locale)
            case .percent(let s): return _attributedNumber(s.format(value), locale: s.locale)
            case .currency(let s): return _attributedNumber(s.format(value), locale: s.locale, currency: true)
            }
        }
        public func locale(_ locale: Locale) -> Self {
            switch style {
            case .number(let s): return .init(style: .number(s.locale(locale)))
            case .percent(let s): return .init(style: .percent(s.locale(locale)))
            case .currency(let s): return .init(style: .currency(s.locale(locale)))
            }
        }
    }
    public var attributed: Attributed { Attributed(style: .number(self)) }
}
extension Decimal.FormatStyle.Percent { public var attributed: Decimal.FormatStyle.Attributed { .init(style: .percent(self)) } }
extension Decimal.FormatStyle.Currency { public var attributed: Decimal.FormatStyle.Attributed { .init(style: .currency(self)) } }

// MARK: - byte counts and measurements

typealias _ByteCountAttr = AttributeScopes.FoundationAttributes.ByteCountAttribute
/// the runs of a formatted byte count: the value (or "Zero KB"'s spelled-out word), the unit, the actual count in
/// parentheses
func _attributedByteCount(_ text: String, locale: Locale) -> AttributedString {
    var out = AttributedString()
    var main = Substring(text), actual: Substring?
    if let open = text.firstIndex(of: "("), text.hasSuffix(")") { main = text[..<open]; actual = text[open...] }
    let units: [(String, _ByteCountAttr.Unit)] = [("bytes", .byte), ("byte", .byte), ("KB", .kb), ("kB", .kb), ("MB", .mb), ("GB", .gb), ("TB", .tb),
                                                   ("PB", .pb), ("EB", .eb), ("ZB", .zb), ("YB", .yb)]
    let trimmed = main.trimmingCharacters(in: .whitespaces)
    let unitMatch = units.first { trimmed.hasSuffix($0.0) } ?? units.first { trimmed.hasPrefix($0.0) }
    if let (name, unit) = unitMatch, let r = main.range(of: name, options: trimmed.hasSuffix(name) ? .backwards : []) {
        let before = main[..<r.lowerBound], after = main[r.upperBound...]
        let value = before.trimmingCharacters(in: .whitespaces)
        let spelled = !value.contains { $0.isNumber }
        var v = spelled ? AttributedString(value) : _attributedNumber(value, locale: locale)
        v[_ByteCountAttr.self] = spelled ? .spelledOutValue : .value
        // the space between value and unit belongs to neither
        let lead = before.prefix { $0.isWhitespace }, gap = before.reversed().prefix { $0.isWhitespace }
        out.append(AttributedString(String(lead)))
        out.append(v)
        out.append(AttributedString(String(gap)))
        var u = AttributedString(name); u[_ByteCountAttr.self] = .unit(unit)
        out.append(u)
        out.append(AttributedString(String(after)))
    } else {
        out.append(AttributedString(String(main)))
    }
    if let actual {
        var a = AttributedString(String(actual)); a[_ByteCountAttr.self] = .actualByteCount
        out.append(a)
    }
    return out
}
extension ByteCountFormatStyle {
    public struct Attributed: FormatStyle, Sendable {
        public var style: ByteCountFormatStyle.Style
        public var allowedUnits: ByteCountFormatStyle.Units
        public var spellsOutZero: Bool
        public var includesActualByteCount: Bool
        public var locale: Locale
        var plain: ByteCountFormatStyle {
            ByteCountFormatStyle(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount, locale: locale)
        }
        public func format(_ value: Int64) -> AttributedString { _attributedByteCount(plain.format(value), locale: locale) }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
    public var attributed: Attributed {
        Attributed(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount, locale: locale)
    }
}

typealias _MeasurementAttr = AttributeScopes.FoundationAttributes.MeasurementAttribute
extension Measurement where UnitType: Dimension {
    /// A measurement as an attributed string: the value (with its number attributes) and the unit.
    @dynamicMemberLookup
    public struct AttributedStyle: Foundation.FormatStyle, @unchecked Sendable {
        var innerStyle: Measurement<UnitType>.FormatStyle
        public subscript<T>(dynamicMember key: KeyPath<Measurement<UnitType>.FormatStyle, T>) -> T { innerStyle[keyPath: key] }
        public subscript<T>(dynamicMember key: WritableKeyPath<Measurement<UnitType>.FormatStyle, T>) -> T {
            get { innerStyle[keyPath: key] }
            set { innerStyle[keyPath: key] = newValue }
        }
        public func format(_ m: Measurement<UnitType>) -> AttributedString {
            let text = innerStyle.format(m)
            // the number is the run of digits (and the separators between them) in the text
            let chars = Array(text)
            guard let first = chars.firstIndex(where: { $0.isNumber }), let last = chars.lastIndex(where: { $0.isNumber }) else { return AttributedString(text) }
            var start = first
            if start > 0, chars[start - 1] == "-" || chars[start - 1] == "\u{2212}" { start -= 1 }
            var out = AttributedString()
            func unit(_ s: ArraySlice<Character>) {
                let str = String(s)
                guard !str.isEmpty else { return }
                let t = str.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { out.append(AttributedString(str)); return }
                // spaces next to the value belong to neither
                let lead = str.prefix { $0.isWhitespace }, trail = String(str.reversed().prefix { $0.isWhitespace }.reversed())
                out.append(AttributedString(String(lead)))
                var u = AttributedString(t); u[_MeasurementAttr.self] = .unit
                out.append(u)
                out.append(AttributedString(trail))
            }
            unit(chars[..<start])
            var v = _attributedNumber(String(chars[start...last]), locale: innerStyle.locale)
            v[_MeasurementAttr.self] = .value
            out.append(v)
            unit(chars[(last + 1)...])
            return out
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.innerStyle = innerStyle.locale(locale); return s }
    }
}
extension Measurement.FormatStyle {
    public var attributed: Measurement<UnitType>.AttributedStyle { .init(innerStyle: self) }
}
extension Measurement.AttributedStyle where UnitType == UnitInformationStorage {
    /// Byte counts of information-storage measurements, attributed.
    public struct ByteCount: Foundation.FormatStyle, Sendable {
        public typealias Style = ByteCountFormatStyle.Style
        public typealias Units = ByteCountFormatStyle.Units
        public var style: Style
        public var allowedUnits: Units
        public var spellsOutZero: Bool
        public var includesActualByteCount: Bool
        public var locale: Locale
        public init(style: Style, allowedUnits: Units, spellsOutZero: Bool, includesActualByteCount: Bool, locale: Locale) {
            self.style = style; self.allowedUnits = allowedUnits; self.spellsOutZero = spellsOutZero; self.includesActualByteCount = includesActualByteCount
            self.locale = locale
        }
        public func format(_ value: Measurement<UnitInformationStorage>) -> AttributedString {
            let bytes = Int64(value.converted(to: .bytes).value.rounded())
            return ByteCountFormatStyle(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount,
                                        locale: locale).attributed.format(bytes)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
}
extension Measurement.FormatStyle.ByteCount where UnitType == UnitInformationStorage {
    public var attributed: Measurement<UnitInformationStorage>.AttributedStyle.ByteCount {
        .init(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount, locale: locale)
    }
}

// MARK: - dates

typealias _DateField = AttributeScopes.FoundationAttributes.DateFieldAttribute.Field
/// The runs of a date formatted with an ICU pattern: each field (a run of one pattern letter) formatted on its own, the
/// quoted and other literal text between them.
func _attributedDate(_ date: Date, pattern: String, locale: Locale, timeZone: TimeZone, calendar: Calendar) -> AttributedString {
    let f = DateFormatter()
    f.locale = locale; f.timeZone = timeZone; f.calendar = calendar
    func field(_ c: Character) -> _DateField? {
        switch c {
        case "G": return .era
        case "y", "u", "U", "Y": return .year
        case "r": return .relatedGregorianYear
        case "Q", "q": return .quarter
        case "M", "L": return .month
        case "w": return .weekOfYear
        case "W": return .weekOfMonth
        case "d": return .day
        case "D": return .dayOfYear
        case "F": return .weekdayOrdinal
        case "E", "e", "c": return .weekday
        case "a", "b", "B": return .amPM
        case "h", "H", "k", "K": return .hour
        case "m": return .minute
        case "s": return .second
        case "S", "A": return .secondFraction
        case "z", "Z", "O", "v", "V", "X", "x": return .timeZone
        default: return nil
        }
    }
    var out = AttributedString()
    let p = Array(pattern)
    var i = 0, literal = ""
    func flushLiteral() { if !literal.isEmpty { out.append(AttributedString(literal)); literal = "" } }
    while i < p.count {
        let c = p[i]
        if c == "'" {
            // quoted text; '' is a quote
            if i + 1 < p.count, p[i + 1] == "'" { literal.append("'"); i += 2; continue }
            i += 1
            while i < p.count {
                if p[i] == "'" { if i + 1 < p.count, p[i + 1] == "'" { literal.append("'"); i += 2; continue }; i += 1; break }
                literal.append(p[i]); i += 1
            }
            continue
        }
        if c.isLetter, c.isASCII {
            var j = i
            while j < p.count, p[j] == c { j += 1 }
            flushLiteral()
            f.dateFormat = String(p[i..<j])
            var a = AttributedString(f.string(from: date))
            if let fld = field(c) { a[AttributeScopes.FoundationAttributes.DateFieldAttribute.self] = fld }
            out.append(a)
            i = j
            continue
        }
        literal.append(c); i += 1
    }
    flushLiteral()
    return out
}
extension Date.FormatStyle {
    /// The date as an attributed string (dateField).
    @dynamicMemberLookup
    public struct Attributed: Foundation.FormatStyle, Sendable {
        var base: Date.FormatStyle
        public subscript<T>(dynamicMember key: KeyPath<Date.FormatStyle, T>) -> T { base[keyPath: key] }
        public subscript<T>(dynamicMember key: WritableKeyPath<Date.FormatStyle, T>) -> T {
            get { base[keyPath: key] }
            set { base[keyPath: key] = newValue }
        }
        public func format(_ value: Date) -> AttributedString {
            var a = _attributedDate(value, pattern: base.pattern, locale: base.locale, timeZone: base.timeZone, calendar: base.calendar)
            let plain = base.format(value)
            // capitalization, as the plain style applies it
            if let first = plain.first, let r = a.characters.indices.first, a.characters[r] != first {
                a.replaceSubrange(r..<a.characters.index(after: r), with: AttributedString(String(first), attributes: a.runs.first!.attributes))
            }
            return a
        }
        public func locale(_ locale: Locale) -> Self { .init(base: base.locale(locale)) }
        public func era(_ format: Symbol.Era = .abbreviated) -> Self { .init(base: base.era(format)) }
        public func year(_ format: Symbol.Year = .defaultDigits) -> Self { .init(base: base.year(format)) }
        public func quarter(_ format: Symbol.Quarter = .abbreviated) -> Self { .init(base: base.quarter(format)) }
        public func month(_ format: Symbol.Month = .abbreviated) -> Self { .init(base: base.month(format)) }
        public func week(_ format: Symbol.Week = .defaultDigits) -> Self { .init(base: base.week(format)) }
        public func day(_ format: Symbol.Day = .defaultDigits) -> Self { .init(base: base.day(format)) }
        public func dayOfYear(_ format: Symbol.DayOfYear = .defaultDigits) -> Self { .init(base: base.dayOfYear(format)) }
        public func weekday(_ format: Symbol.Weekday = .abbreviated) -> Self { .init(base: base.weekday(format)) }
        public func hour(_ format: Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self { .init(base: base.hour(format)) }
        public func minute(_ format: Symbol.Minute = .defaultDigits) -> Self { .init(base: base.minute(format)) }
        public func second(_ format: Symbol.Second = .defaultDigits) -> Self { .init(base: base.second(format)) }
        public func secondFraction(_ format: Symbol.SecondFraction) -> Self { .init(base: base.secondFraction(format)) }
        public func timeZone(_ format: Symbol.TimeZone = .specificName(.short)) -> Self { .init(base: base.timeZone(format)) }
    }
    public var attributedStyle: Attributed { Attributed(base: self) }
    public var attributed: Date.AttributedStyle { Date.AttributedStyle(style: .formatStyle(self)) }
}
extension Date {
    /// A date format style's attributed output (Date.FormatStyle.attributed, Date.VerbatimFormatStyle.attributed).
    public struct AttributedStyle: Foundation.FormatStyle, Sendable {
        enum Style: Codable, Hashable, Sendable { case formatStyle(Date.FormatStyle), verbatimFormatStyle(Date.VerbatimFormatStyle) }
        var style: Style
        public func format(_ value: Date) -> AttributedString {
            switch style {
            case .formatStyle(let s): return s.attributedStyle.format(value)
            case .verbatimFormatStyle(let s): return s.attributedStyle.format(value)
            }
        }
        public func locale(_ locale: Locale) -> Self {
            switch style {
            case .formatStyle(let s): return .init(style: .formatStyle(s.locale(locale)))
            case .verbatimFormatStyle(let s): return .init(style: .verbatimFormatStyle(s.locale(locale)))
            }
        }
    }
    /// A date in a fixed pattern (a Date.FormatString), with no localized reordering.
    public struct VerbatimFormatStyle: Foundation.FormatStyle, Sendable {
        var formatPattern: String
        public var timeZone: TimeZone
        public var calendar: Calendar
        /// nil: the fields' default (English, POSIX) names and digits
        public var locale: Locale?
        public init(format: FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar) {
            formatPattern = format.rawFormat; self.locale = locale; self.timeZone = timeZone; self.calendar = calendar
        }
        var effectiveLocale: Locale { locale ?? Locale(identifier: "en_US_POSIX") }
        public func format(_ value: Date) -> String {
            let f = DateFormatter()
            f.locale = effectiveLocale; f.timeZone = timeZone; f.calendar = calendar; f.dateFormat = formatPattern
            return f.string(from: value)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public var parseStrategy: Date.ParseStrategy { Date.ParseStrategy(format: formatPattern, locale: effectiveLocale, timeZone: timeZone, calendar: calendar) }
        @dynamicMemberLookup
        public struct Attributed: Foundation.FormatStyle, Sendable {
            var base: VerbatimFormatStyle
            public subscript<T>(dynamicMember key: KeyPath<VerbatimFormatStyle, T>) -> T { base[keyPath: key] }
            public subscript<T>(dynamicMember key: WritableKeyPath<VerbatimFormatStyle, T>) -> T {
                get { base[keyPath: key] }
                set { base[keyPath: key] = newValue }
            }
            public func format(_ value: Date) -> AttributedString {
                _attributedDate(value, pattern: base.formatPattern, locale: base.effectiveLocale, timeZone: base.timeZone, calendar: base.calendar)
            }
            public func locale(_ locale: Locale) -> Self { .init(base: base.locale(locale)) }
        }
        public var attributedStyle: Attributed { Attributed(base: self) }
        public var attributed: AttributedStyle { AttributedStyle(style: .verbatimFormatStyle(self)) }
    }
}
extension Date.VerbatimFormatStyle: ParseableFormatStyle {}
extension FormatStyle where Self == Date.VerbatimFormatStyle {
    public static func verbatim(_ format: Date.FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar) -> Self {
        .init(format: format, locale: locale, timeZone: timeZone, calendar: calendar)
    }
}

// MARK: - the rest of Date.FormatStyle's symbols

extension Date.FormatStyle.Symbol {
    public struct StandaloneMonth: Codable, Hashable, Sendable { let run: String
        public static let defaultDigits = StandaloneMonth(run: "L"), twoDigits = StandaloneMonth(run: "LL"), abbreviated = StandaloneMonth(run: "LLL"),
                          wide = StandaloneMonth(run: "LLLL"), narrow = StandaloneMonth(run: "LLLLL") }
    public struct StandaloneQuarter: Codable, Hashable, Sendable { let run: String
        public static let oneDigit = StandaloneQuarter(run: "q"), twoDigits = StandaloneQuarter(run: "qq"), abbreviated = StandaloneQuarter(run: "qqq"),
                          wide = StandaloneQuarter(run: "qqqq"), narrow = StandaloneQuarter(run: "qqqqq") }
    public struct StandaloneWeekday: Codable, Hashable, Sendable { let run: String
        public static let oneDigit = StandaloneWeekday(run: "c"), abbreviated = StandaloneWeekday(run: "ccc"), wide = StandaloneWeekday(run: "cccc"),
                          narrow = StandaloneWeekday(run: "ccccc"), short = StandaloneWeekday(run: "cccccc") }
    /// the year of the Chinese and Hindu sexagenary cycle (ICU's "U")
    public struct CyclicYear: Codable, Hashable, Sendable { let run: String
        public static let abbreviated = CyclicYear(run: "U"), wide = CyclicYear(run: "UUUU"), narrow = CyclicYear(run: "UUUUU")
        public static let omitted = CyclicYear(run: "") }
    public struct YearForWeekOfYear: Codable, Hashable, Sendable { let run: String
        public static let defaultDigits = YearForWeekOfYear(run: "Y"), twoDigits = YearForWeekOfYear(run: "YY")
        public static func padded(_ length: Int) -> YearForWeekOfYear { YearForWeekOfYear(run: String(repeating: "Y", count: Swift.max(1, Swift.min(length, 10)))) }
        public static let omitted = YearForWeekOfYear(run: "") }
    /// an hour in a given clock (12 or 24) and cycle (from 0 or 1), whatever the locale prefers
    public struct VerbatimHour: Codable, Hashable, Sendable { let run: String
        public struct Clock: Codable, Hashable, Sendable { let twelve: Bool
            public static let twentyFourHour = Clock(twelve: false), twelveHour = Clock(twelve: true) }
        public struct HourCycle: Codable, Hashable, Sendable { let zero: Bool
            public static let zeroBased = HourCycle(zero: true), oneBased = HourCycle(zero: false) }
        static func letter(_ c: Clock, _ h: HourCycle) -> String { c.twelve ? (h.zero ? "K" : "h") : (h.zero ? "H" : "k") }
        public static func defaultDigits(clock: Clock, hourCycle: HourCycle) -> VerbatimHour { VerbatimHour(run: letter(clock, hourCycle)) }
        public static func twoDigits(clock: Clock, hourCycle: HourCycle) -> VerbatimHour { VerbatimHour(run: letter(clock, hourCycle) + letter(clock, hourCycle)) }
    }
}
// `omitted`: a symbol that leaves its field out of the format
extension Date.FormatStyle.Symbol.Era { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Year { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Quarter { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Month { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Week { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Day { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.DayOfYear { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Weekday { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.DayPeriod { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Hour { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Minute { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.Second { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.SecondFraction { public static let omitted = Self(run: "") }
extension Date.FormatStyle.Symbol.TimeZone { public static let omitted = Self(run: "") }

extension Date.FormatString.StringInterpolation {
    public mutating func appendInterpolation(standaloneMonth: Date.FormatStyle.Symbol.StandaloneMonth) { format += standaloneMonth.run }
    public mutating func appendInterpolation(standaloneQuarter: Date.FormatStyle.Symbol.StandaloneQuarter) { format += standaloneQuarter.run }
    public mutating func appendInterpolation(standaloneWeekday: Date.FormatStyle.Symbol.StandaloneWeekday) { format += standaloneWeekday.run }
    public mutating func appendInterpolation(cyclicYear: Date.FormatStyle.Symbol.CyclicYear) { format += cyclicYear.run }
    public mutating func appendInterpolation(yearForWeekOfYear: Date.FormatStyle.Symbol.YearForWeekOfYear) { format += yearForWeekOfYear.run }
    public mutating func appendInterpolation(verbatimHour: Date.FormatStyle.Symbol.VerbatimHour) { format += verbatimHour.run }
}

// MARK: - formatters, calendars and time zones

extension Calendar {
    /// the quarters' names standing alone ("1st quarter"), as ICU gives them for the calendar's locale
    public var standaloneQuarterSymbols: [String] { let f = DateFormatter(); f.locale = locale ?? .current; return f.standaloneQuarterSymbols }
    public var shortStandaloneQuarterSymbols: [String] { let f = DateFormatter(); f.locale = locale ?? .current; return f.shortStandaloneQuarterSymbols }
}
extension TimeZone {
    public enum NameStyle: Int, Sendable {
        case standard = 0, shortStandard, daylightSaving, shortDaylightSaving, generic, shortGeneric
    }
    /// the time zone's name in a style and locale (DateFormatter's z / zzzz / v / vvvv names)
    public func localizedName(for style: NameStyle, locale: Locale?) -> String? {
        let f = DateFormatter()
        f.locale = locale ?? .current
        f.timeZone = self
        let pattern = ["zzzz", "z", "zzzz", "z", "vvvv", "v"][style.rawValue]
        // the standard / daylight names: a date in January and one in July (whichever is not daylight saving time)
        let jan = Date(timeIntervalSince1970: 1_704_067_200), jul = Date(timeIntervalSince1970: 1_719_792_000)
        let standardDate = isDaylightSavingTime(for: jan) ? jul : jan, daylightDate = isDaylightSavingTime(for: jan) ? jan : jul
        f.dateFormat = pattern
        switch style {
        case .standard, .shortStandard, .generic, .shortGeneric: return f.string(from: standardDate)
        case .daylightSaving, .shortDaylightSaving: return f.string(from: daylightDate)
        }
    }
    /// the abbreviations TimeZone(abbreviation:) knows, as on iOS
    public static var abbreviationDictionary: [String: String] {
        get { _tzAbbreviations }
        set { _tzAbbreviations = newValue }
    }
    /// the tz database release isim's time zones come from: the host's (its tzdata.zi), as iOS reports its own
    public static var timeZoneDataVersion: String {
        if let s = try? String(contentsOfFile: "/usr/share/zoneinfo/tzdata.zi", encoding: .utf8), let line = s.split(separator: "\n").first,
           line.hasPrefix("# version ") { return String(line.dropFirst(10)) }
        return "2024a"
    }
    /// a time zone from an abbreviation ("PST", "CET"), as abbreviationDictionary maps it
    public init?(abbreviation: String) {
        if let id = TimeZone.abbreviationDictionary[abbreviation], let tz = TimeZone(identifier: id) { self = tz; return }
        guard let ns = NSTimeZone(abbreviation: abbreviation) else { return nil }
        self = ns as TimeZone
    }
}
nonisolated(unsafe) private var _tzAbbreviations: [String: String] = [
    "ADT": "America/Halifax", "AKDT": "America/Juneau", "AKST": "America/Juneau", "ART": "America/Argentina/Buenos_Aires", "AST": "America/Halifax",
    "BDT": "Asia/Dhaka", "BRST": "America/Sao_Paulo", "BRT": "America/Sao_Paulo", "BST": "Europe/London", "CAT": "Africa/Harare",
    "CDT": "America/Chicago", "CEST": "Europe/Paris", "CET": "Europe/Paris", "CLST": "America/Santiago", "CLT": "America/Santiago",
    "COT": "America/Bogota", "CST": "America/Chicago", "EAT": "Africa/Addis_Ababa", "EDT": "America/New_York", "EEST": "Europe/Athens",
    "EET": "Europe/Athens", "EST": "America/New_York", "GMT": "GMT", "GST": "Asia/Dubai", "HKT": "Asia/Hong_Kong", "HST": "Pacific/Honolulu",
    "ICT": "Asia/Bangkok", "IRST": "Asia/Tehran", "IST": "Asia/Kolkata", "JST": "Asia/Tokyo", "KST": "Asia/Seoul", "MDT": "America/Denver",
    "MSD": "Europe/Moscow", "MSK": "Europe/Moscow", "MST": "America/Phoenix", "NZDT": "Pacific/Auckland", "NZST": "Pacific/Auckland",
    "PDT": "America/Los_Angeles", "PET": "America/Lima", "PHT": "Asia/Manila", "PKT": "Asia/Karachi", "PST": "America/Los_Angeles",
    "SGT": "Asia/Singapore", "UTC": "UTC", "WAT": "Africa/Lagos", "WEST": "Europe/Lisbon", "WET": "Europe/Lisbon", "WIT": "Asia/Jakarta",
]
