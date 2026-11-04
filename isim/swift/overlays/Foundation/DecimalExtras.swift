// isim Foundation (issue #860): Decimal's IEEE-style members, its parse strategy and the rest of its format styles'
// modifiers; the byte-count style and remaining initializers of Measurement.FormatStyle; more unit usages and
// UnitEnergy(forLocale:usage:). Adapted: parsing and formatting go through NumberFormatter / ICU like the other numbers.

// MARK: - Decimal as a number

extension Decimal {
    /// zero, subnormal (never for Decimal), normal or NaN (Decimal has no infinities)
    public var floatingPointClass: FloatingPointClassification {
        if isNaN { return .quietNaN }
        if isZero { return sign == .minus ? .negativeZero : .positiveZero }
        return sign == .minus ? .negativeNormal : .positiveNormal
    }
    /// Decimal's NaN never signals
    public var isSignaling: Bool { false }
    public init(signOf: Decimal, magnitudeOf: Decimal) {
        var m = magnitudeOf.magnitude
        if signOf.sign == .minus && !m.isZero { m.negate() }
        self = m
    }
    public func isEqual(to other: Decimal) -> Bool { !isNaN && !other.isNaN && self == other }
    public func isLess(than other: Decimal) -> Bool { !isNaN && !other.isNaN && self < other }
    public func isLessThanOrEqualTo(_ other: Decimal) -> Bool { !isNaN && !other.isNaN && self <= other }
    /// NaN sorts above every number
    public func isTotallyOrdered(belowOrEqualTo other: Decimal) -> Bool {
        if isNaN { return other.isNaN }
        if other.isNaN { return true }
        return self <= other
    }
}

// MARK: - parsing

extension Decimal {
    /// Parses text into a Decimal the way its format style shows it.
    public struct ParseStrategy<Format>: Foundation.ParseStrategy, Codable, Hashable
        where Format: Foundation.FormatStyle, Format: Hashable, Format: Codable, Format.FormatInput == Decimal {
        public var formatStyle: Format
        public var lenient: Bool
        public func parse(_ value: String) throws -> Format.FormatInput {
            guard let d = _isimParseDecimal(value, style: formatStyle) else { throw _parseError(value, "a decimal") }
            return d
        }
    }
    public init<S>(_ value: S.ParseInput, strategy: S) throws where S: Foundation.ParseStrategy, S.ParseOutput == Decimal {
        self = try strategy.parse(value)
    }
}
extension Decimal.ParseStrategy: Sendable where Format: Sendable {}
extension Decimal.ParseStrategy where Format == Decimal.FormatStyle {
    public init(format: Format, lenient: Bool = true) { formatStyle = format; self.lenient = lenient }
}
extension Decimal.ParseStrategy where Format == Decimal.FormatStyle.Percent {
    public init(format: Format, lenient: Bool = true) { formatStyle = format; self.lenient = lenient }
}
extension Decimal.ParseStrategy where Format == Decimal.FormatStyle.Currency {
    public init(format: Format, lenient: Bool = true) { formatStyle = format; self.lenient = lenient }
}

/// the decimal in `s` as `style` writes it: NumberFormatter's lenient parse in the style's locale, kept exact (its
/// digits go through Decimal(string:), not Double)
func _isimParseDecimal<S: FormatStyle>(_ s: String, style: S) -> Decimal? {
    /// exact for NSDecimalNumber; a double's shortest form otherwise (19.99, not 19.989999999999998)
    func dec(_ n: NSNumber) -> Decimal? { n is NSDecimalNumber ? Decimal(string: n.stringValue) : Decimal(string: "\(n.doubleValue)") }
    let mirror = Mirror(reflecting: style)
    let locale = mirror.children.first { $0.label == "locale" }?.value as? Locale ?? .current
    let f = NumberFormatter()
    f.locale = locale
    f.isLenient = true
    f.generatesDecimalNumbers = true
    let name = String(describing: S.self)
    var text = s.trimmingCharacters(in: .whitespaces)
    if name.contains("Percent") {
        f.numberStyle = .percent
        if let n = f.number(from: text) { return dec(n) }
        text = text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        f.numberStyle = .decimal
        return f.number(from: text).flatMap(dec).map { $0 / 100 }
    }
    if name.contains("Currency") {
        f.numberStyle = .currency
        if let code = mirror.children.first(where: { $0.label == "currencyCode" })?.value as? String { f.currencyCode = code }
        if let n = f.number(from: text) { return dec(n) }
        for sym in [f.currencySymbol ?? "", f.currencyCode ?? "", "$", "€", "£", "¥"] where !sym.isEmpty { text = text.replacingOccurrences(of: sym, with: "") }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " \u{A0}\u{202F}"))
    }
    f.numberStyle = .decimal
    return f.number(from: text).flatMap(dec)
}

/// the longest prefix of `input[index...]` (up to whitespace runs inside numbers) that parses
func _isimConsumeDecimal<S: FormatStyle>(_ input: String, from index: String.Index, in bounds: Range<String.Index>, style: S)
    -> (upperBound: String.Index, output: Decimal)? {
    var end = bounds.upperBound
    while end > index {
        let piece = String(input[index..<end])
        if !piece.hasSuffix(" "), let d = _isimParseDecimal(piece, style: style) { return (end, d) }
        end = input.index(before: end)
    }
    return nil
}

extension Decimal.FormatStyle: ParseableFormatStyle, CustomConsumingRegexComponent {
    public var parseStrategy: Decimal.ParseStrategy<Decimal.FormatStyle> { Decimal.ParseStrategy(format: self, lenient: true) }
    public typealias RegexOutput = Decimal
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        _isimConsumeDecimal(input, from: index, in: bounds, style: self)
    }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
        var s = self; s.collection.decimalSeparatorStrategy = strategy; return s
    }
}
extension Decimal.FormatStyle.Percent: ParseableFormatStyle, CustomConsumingRegexComponent {
    public typealias Configuration = NumberFormatStyleConfiguration
    public var parseStrategy: Decimal.ParseStrategy<Decimal.FormatStyle.Percent> { Decimal.ParseStrategy(format: self, lenient: true) }
    public typealias RegexOutput = Decimal
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        _isimConsumeDecimal(input, from: index, in: bounds, style: self)
    }
    public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
    public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.collection.signDisplayStrategy = strategy; return s }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
        var s = self; s.collection.decimalSeparatorStrategy = strategy; return s
    }
    public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
        var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment.map(Double.init); return s
    }
    public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
    public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
}
extension Decimal.FormatStyle.Currency: ParseableFormatStyle, CustomConsumingRegexComponent {
    public var parseStrategy: Decimal.ParseStrategy<Decimal.FormatStyle.Currency> { Decimal.ParseStrategy(format: self, lenient: true) }
    public typealias RegexOutput = Decimal
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        _isimConsumeDecimal(input, from: index, in: bounds, style: self)
    }
    public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
        var s = self; s.collection.decimalSeparatorStrategy = strategy; return s
    }
    public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
    public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
}

// MARK: - measurements

extension Measurement.FormatStyle {
    public init(width: UnitWidth, locale: Locale = .autoupdatingCurrent, usage: MeasurementFormatUnitUsage<UnitType> = .general,
                hidesScaleName: Bool = false, numberFormatStyle: FloatingPointFormatStyle<Double>? = nil) {
        self.init(width: width, locale: locale, usage: usage, numberFormatStyle: numberFormatStyle)
        self.hidesScaleName = hidesScaleName
    }
}
extension Measurement.FormatStyle where UnitType == UnitInformationStorage {
    public struct ByteCount: Foundation.FormatStyle, Sendable {
        public typealias Style = ByteCountFormatStyle.Style
        public typealias Units = ByteCountFormatStyle.Units
        public var style: Style
        public var allowedUnits: Units
        public var spellsOutZero: Bool
        public var includesActualByteCount: Bool
        public var locale: Locale
        public init(style: Style, allowedUnits: Units, spellsOutZero: Bool, includesActualByteCount: Bool, locale: Locale) {
            self.style = style; self.allowedUnits = allowedUnits; self.spellsOutZero = spellsOutZero
            self.includesActualByteCount = includesActualByteCount; self.locale = locale
        }
        public func format(_ value: Measurement<UnitInformationStorage>) -> String {
            ByteCountFormatStyle(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero,
                                 includesActualByteCount: includesActualByteCount, locale: locale)
                .format(Int64(value.converted(to: .bytes).value.rounded()))
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
}
extension FormatStyle {
    public static func byteCount(style: Measurement<UnitInformationStorage>.FormatStyle.ByteCount.Style,
                                 allowedUnits: Measurement<UnitInformationStorage>.FormatStyle.ByteCount.Units = .all,
                                 spellsOutZero: Bool = true, includesActualByteCount: Bool = false) -> Self
        where Self == Measurement<UnitInformationStorage>.FormatStyle.ByteCount {
        .init(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount,
              locale: .autoupdatingCurrent)
    }
}
extension MeasurementFormatUnitUsage where UnitType == UnitPressure {
    /// air pressure in a weather report (hPa / inHg)
    public static var barometric: Self { .init(usage: "general") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitVolume {
    /// drinks and liquids (L / fl oz)
    public static var liquid: Self { .init(usage: "general") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitLength {
    /// how far one can see (km / mi)
    public static var visibility: Self { .init(usage: "general") }
}
extension UnitEnergy {
    /// The energy unit people in `locale` use for `usage` (kilocalories for food in the US, kilojoules in Australia…).
    public convenience init(forLocale locale: Locale, usage: MeasurementFormatUnitUsage<UnitEnergy> = .general) {
        let region = locale.region?.identifier ?? ""
        let base: UnitEnergy
        if usage == .food || usage == .workout {
            base = ["AU", "NZ"].contains(region) ? .kilojoules : .kilocalories
        } else {
            base = .joules
        }
        self.init(symbol: base.symbol, converter: base.converter)
    }
}
