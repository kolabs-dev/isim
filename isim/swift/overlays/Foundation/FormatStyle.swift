// isim Foundation: FormatStyle / ParseStrategy (iOS 15+) for numbers, currency, percent, lists, byte counts and
// durations. Self-authored; the locale data and number engine are Foundation's NumberFormatter & friends
// (built-in CLDR subset), so `.formatted()` follows the device region like iOS.

// MARK: - protocols
public protocol FormatStyle<FormatInput, FormatOutput>: Decodable, Encodable, Hashable {
    associatedtype FormatInput
    associatedtype FormatOutput
    func format(_ value: FormatInput) -> FormatOutput
    func locale(_ locale: Locale) -> Self
}
extension FormatStyle {
    public func locale(_ locale: Locale) -> Self { self }
}
public protocol ParseStrategy<ParseInput, ParseOutput>: Decodable, Encodable, Hashable {
    associatedtype ParseInput
    associatedtype ParseOutput
    func parse(_ value: ParseInput) throws -> ParseOutput
}
public protocol ParseableFormatStyle: FormatStyle {
    associatedtype Strategy: ParseStrategy where Strategy.ParseInput == FormatOutput, Strategy.ParseOutput == FormatInput
    var parseStrategy: Strategy { get }
}

// Locale / TimeZone / Calendar are stored in format styles, which are Codable like Apple's
extension Locale: Codable {
    public init(from decoder: Decoder) throws { self.init(identifier: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(identifier) }
}
extension TimeZone: Codable {
    public init(from decoder: Decoder) throws {
        let id = try decoder.singleValueContainer().decode(String.self)
        self = TimeZone(identifier: id) ?? .gmt
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(identifier) }
}
extension Calendar: Codable {
    public init(from decoder: Decoder) throws { self.init(identifier: try decoder.singleValueContainer().decode(Identifier.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(identifier) }
}

/// Errors thrown by isim's parse strategies (Apple throws CocoaError(.formatting)).
func _parseError(_ s: String, _ what: String) -> NSError {
    NSError(domain: NSCocoaErrorDomain, code: 2048, userInfo: [NSLocalizedDescriptionKey: "Cannot parse \(s) as \(what)."])
}

// MARK: - number format configuration
public enum NumberFormatStyleConfiguration {
    public struct Grouping: Codable, Hashable, Sendable, CustomStringConvertible {
        let never: Bool
        public static var automatic: Grouping { Grouping(never: false) }
        public static var never: Grouping { Grouping(never: true) }
        public var description: String { never ? "never" : "automatic" }
    }
    public struct Precision: Codable, Hashable, Sendable {
        var minInt: Int?, maxInt: Int?, minFrac: Int?, maxFrac: Int?, minSig: Int?, maxSig: Int?
        public static func significantDigits<R: RangeExpression>(_ limits: R) -> Precision where R.Bound == Int {
            let r = limits.relative(to: 1..<1000)
            return Precision(minSig: r.lowerBound, maxSig: Swift.min(r.upperBound - 1, 999))
        }
        public static func significantDigits(_ digits: Int) -> Precision { Precision(minSig: digits, maxSig: digits) }
        public static func fractionLength<R: RangeExpression>(_ limits: R) -> Precision where R.Bound == Int {
            let r = limits.relative(to: 0..<1000)
            return Precision(minFrac: r.lowerBound, maxFrac: Swift.min(r.upperBound - 1, 999))
        }
        public static func fractionLength(_ length: Int) -> Precision { Precision(minFrac: length, maxFrac: length) }
        public static func integerLength<R: RangeExpression>(_ limits: R) -> Precision where R.Bound == Int {
            let r = limits.relative(to: 0..<1000)
            return Precision(minInt: r.lowerBound, maxInt: Swift.min(r.upperBound - 1, 999))
        }
        public static func integerLength(_ length: Int) -> Precision { Precision(minInt: length, maxInt: length) }
        public static func integerAndFractionLength<R1: RangeExpression, R2: RangeExpression>(integerLimits: R1, fractionLimits: R2) -> Precision where R1.Bound == Int, R2.Bound == Int {
            let i = integerLimits.relative(to: 0..<1000), f = fractionLimits.relative(to: 0..<1000)
            return Precision(minInt: i.lowerBound, maxInt: Swift.min(i.upperBound - 1, 999), minFrac: f.lowerBound, maxFrac: Swift.min(f.upperBound - 1, 999))
        }
        public static func integerAndFractionLength(integer: Int, fraction: Int) -> Precision { Precision(minInt: integer, maxInt: integer, minFrac: fraction, maxFrac: fraction) }
    }
    public struct SignDisplayStrategy: Codable, Hashable, Sendable {
        enum Kind: Int, Codable, Hashable { case automatic, never, always, alwaysIncludingZero }
        let kind: Kind
        public static var automatic: SignDisplayStrategy { .init(kind: .automatic) }
        public static var never: SignDisplayStrategy { .init(kind: .never) }
        public static func always(includingZero: Bool = false) -> SignDisplayStrategy { .init(kind: includingZero ? .alwaysIncludingZero : .always) }
    }
    public struct DecimalSeparatorDisplayStrategy: Codable, Hashable, Sendable {
        let always: Bool
        public static var automatic: DecimalSeparatorDisplayStrategy { .init(always: false) }
        public static var always: DecimalSeparatorDisplayStrategy { .init(always: true) }
    }
    public typealias RoundingRule = FloatingPointRoundingRule
    public struct Notation: Codable, Hashable, Sendable {
        enum Kind: Int, Codable, Hashable { case automatic, scientific, compactName }
        let kind: Kind
        public static var automatic: Notation { .init(kind: .automatic) }
        public static var scientific: Notation { .init(kind: .scientific) }
        public static var compactName: Notation { .init(kind: .compactName) }
    }
    /// The settings shared by every number style.
    struct Collection: Codable, Hashable, Sendable {
        var scale: Double?
        var precision: Precision?
        var group: Grouping?
        var signDisplayStrategy: SignDisplayStrategy?
        var decimalSeparatorStrategy: DecimalSeparatorDisplayStrategy?
        var rounding: RoundingRule?
        var roundingIncrement: Double?
        var notation: Notation?
    }
}
extension FloatingPointRoundingRule: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(Int.self) {
        case 0: self = .toNearestOrAwayFromZero
        case 1: self = .toNearestOrEven
        case 2: self = .up
        case 3: self = .down
        case 4: self = .towardZero
        default: self = .awayFromZero
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .toNearestOrAwayFromZero: try c.encode(0)
        case .toNearestOrEven: try c.encode(1)
        case .up: try c.encode(2)
        case .down: try c.encode(3)
        case .towardZero: try c.encode(4)
        default: try c.encode(5)
        }
    }
}
public enum CurrencyFormatStyleConfiguration {
    public typealias Grouping = NumberFormatStyleConfiguration.Grouping
    public typealias Precision = NumberFormatStyleConfiguration.Precision
    public typealias DecimalSeparatorDisplayStrategy = NumberFormatStyleConfiguration.DecimalSeparatorDisplayStrategy
    public typealias RoundingRule = NumberFormatStyleConfiguration.RoundingRule
    public struct SignDisplayStrategy: Codable, Hashable, Sendable {
        enum Kind: Int, Codable, Hashable { case automatic, never, always, alwaysIncludingZero, accounting, accountingAlways }
        let kind: Kind
        public static var automatic: SignDisplayStrategy { .init(kind: .automatic) }
        public static var never: SignDisplayStrategy { .init(kind: .never) }
        public static var accounting: SignDisplayStrategy { .init(kind: .accounting) }
        public static func always(showZero: Bool = false) -> SignDisplayStrategy { .init(kind: showZero ? .alwaysIncludingZero : .always) }
        public static func accountingAlways(showZero: Bool = false) -> SignDisplayStrategy { .init(kind: .accountingAlways) }
    }
    public struct Presentation: Codable, Hashable, Sendable {
        enum Kind: Int, Codable, Hashable { case narrow, standard, isoCode, fullName }
        let kind: Kind
        public static var narrow: Presentation { .init(kind: .narrow) }
        public static var standard: Presentation { .init(kind: .standard) }
        public static var isoCode: Presentation { .init(kind: .isoCode) }
        public static var fullName: Presentation { .init(kind: .fullName) }
    }
}

// MARK: - the shared number engine
enum _NumberKind: Codable, Hashable, Sendable { case number, percent, currency(code: String, presentation: Int) }

/// Formats an exact decimal string ("-1234.5", "1e-05") with the locale and configuration.
func _isimFormatNumber(_ decimal: String, kind: _NumberKind, locale: Locale, config c: NumberFormatStyleConfiguration.Collection,
                       isInteger: Bool, currencySign: CurrencyFormatStyleConfiguration.SignDisplayStrategy? = nil) -> String {
    var text = decimal
    var negative = text.hasPrefix("-")
    if negative { text.removeFirst() }
    var value = Double(text) ?? 0
    if let scale = c.scale, scale != 1 {
        let v = (Double(text) ?? 0) * scale
        text = "\(v)"; value = v
    }
    if case .percent = kind, !isInteger {
        // percent of a fraction: shift the decimal point exactly
        text = _shiftDecimal(text, by: 2); value *= 100
    }
    let f = NumberFormatter()
    f.locale = locale
    switch kind {
    case .number: f.numberStyle = .decimal
    case .percent: f.numberStyle = .percent; f.multiplier = NSNumber(value: 1)
    case .currency(let code, let presentation):
        f.currencyCode = code
        switch presentation {
        case 2: f.numberStyle = .currencyISOCode
        case 3: f.numberStyle = .currencyPlural
        default: f.numberStyle = .currency
        }
        if presentation == 0 { f.currencySymbol = _narrowCurrencySymbol(code, locale) }
        if let s = currencySign, s.kind == .accounting || s.kind == .accountingAlways { f.numberStyle = .currencyAccounting }
    }
    // default precision: integers exact, floating point up to 6 fraction digits (ICU default), currency per currency
    if case .number = kind { f.maximumFractionDigits = isInteger ? 0 : 6 }
    if case .percent = kind { f.maximumFractionDigits = isInteger ? 0 : 6 }
    if let p = c.precision {
        if let v = p.minSig { f.usesSignificantDigits = true; f.minimumSignificantDigits = v }
        if let v = p.maxSig { f.usesSignificantDigits = true; f.maximumSignificantDigits = v }
        if let v = p.maxFrac { f.maximumFractionDigits = v }
        if let v = p.minFrac { f.minimumFractionDigits = v }
        if let v = p.maxInt { f.maximumIntegerDigits = v }
        if let v = p.minInt { f.minimumIntegerDigits = v }
    }
    if let g = c.group { f.usesGroupingSeparator = !g.never }
    if let r = c.rounding {
        switch r {
        case .toNearestOrEven: f.roundingMode = .halfEven
        case .toNearestOrAwayFromZero: f.roundingMode = .halfUp
        case .up: f.roundingMode = .ceiling
        case .down: f.roundingMode = .floor
        case .towardZero: f.roundingMode = .down
        case .awayFromZero: f.roundingMode = .up
        @unknown default: f.roundingMode = .halfEven
        }
    }
    if let inc = c.roundingIncrement, inc > 0 { f.roundingIncrement = NSNumber(value: inc) }
    var compactSuffix = ""
    if let n = c.notation {
        switch n.kind {
        case .scientific: f.numberStyle = .scientific; if c.precision == nil { f.maximumFractionDigits = 16 }
        case .compactName:
            let (scaled, suffix, digits) = _compact(value, locale: locale)
            if !suffix.isEmpty || scaled != value {
                text = "\(scaled)"; compactSuffix = suffix
                if c.precision == nil { f.usesSignificantDigits = false; f.maximumFractionDigits = digits; f.minimumFractionDigits = 0 }
            } else if c.precision == nil {
                f.maximumFractionDigits = 0
            }
        case .automatic: break
        }
    }
    var out = f._isim_string(fromDecimalString: text)
    if !compactSuffix.isEmpty { out += compactSuffix }
    if c.decimalSeparatorStrategy?.always == true, !out.contains(f.decimalSeparator) {
        if let r = out.lastIndex(where: { $0.isNumber }) { out.insert(contentsOf: f.decimalSeparator, at: out.index(after: r)) }
    }
    // sign
    let isZero = (Double(text) ?? 0) == 0
    let kindSign: NumberFormatStyleConfiguration.SignDisplayStrategy.Kind? = c.signDisplayStrategy?.kind
    let curKind = currencySign?.kind
    let always = kindSign == .always || kindSign == .alwaysIncludingZero || curKind == .always || curKind == .alwaysIncludingZero || curKind == .accountingAlways
    let includeZero = kindSign == .alwaysIncludingZero || curKind == .alwaysIncludingZero
    if negative && isZero { negative = false }
    if negative {
        if kindSign == .never || curKind == .never { return out }
        if curKind == .accounting || curKind == .accountingAlways { return f._isim_string(fromDecimalString: "-" + text) + compactSuffix }
        return f._isim_string(fromDecimalString: "-" + text) + compactSuffix
    }
    if always && (!isZero || includeZero) {
        let pre: String = f.positivePrefix ?? ""
        if pre.isEmpty { return "+" + out }
        return pre + "+" + out.dropFirst(pre.count)
    }
    return out
}
func _shiftDecimal(_ s: String, by n: Int) -> String {
    // multiply a plain or exponent decimal string by 10^n exactly
    if let e = s.firstIndex(where: { $0 == "e" || $0 == "E" }) {
        let exp = Int(s[s.index(after: e)...]) ?? 0
        return String(s[..<e]) + "e" + String(exp + n)
    }
    return s + "e" + String(n)
}
func _narrowCurrencySymbol(_ code: String, _ locale: Locale) -> String {
    let narrow: [String: String] = ["USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "BRL": "R$", "CAD": "$", "AUD": "$", "INR": "₹",
                                    "MXN": "$", "CNY": "¥", "KRW": "₩", "CHF": "CHF", "NZD": "$", "HKD": "$", "SGD": "$", "ARS": "$", "CLP": "$", "COP": "$"]
    return narrow[code] ?? code
}
/// compact-name notation ("1.2K", "3 mi", "4,5 Mio.")
func _compact(_ v: Double, locale: Locale) -> (Double, String, Int) {
    let lang = locale.languageCode ?? "en"
    let a = Swift.abs(v)
    let table: [(Double, String)]
    switch lang {
    case "pt": table = [(1e12, " tri"), (1e9, " bi"), (1e6, " mi"), (1e3, " mil")]
    case "es": table = [(1e12, " B"), (1e9, " mil M"), (1e6, " M"), (1e3, " mil")]
    case "fr": table = [(1e12, "\u{A0}Bn"), (1e9, "\u{A0}Md"), (1e6, "\u{A0}M"), (1e3, "\u{A0}k")]
    case "de": table = [(1e12, "\u{A0}Bio."), (1e9, "\u{A0}Mrd."), (1e6, "\u{A0}Mio.")]
    case "it": table = [(1e12, "\u{A0}Bln"), (1e9, "\u{A0}Mrd"), (1e6, "\u{A0}Mln")]
    case "ja": table = [(1e12, "兆"), (1e8, "億"), (1e4, "万")]
    case "en": table = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
    default: table = _icuCompactTable(locale) ?? [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]   // other languages: ICU (CLDR)
    }
    for (scale, suffix) in table where a >= scale {
        var s = v / scale
        // round to 2 significant digits below 100, else to an integer
        let digits = Swift.abs(s) < 100 ? (Swift.abs(s) < 10 ? 1 : 0) : 0
        let p = pow(10.0, Double(digits))
        s = (s * p).rounded() / p
        if Swift.abs(s) >= 1000, scale != table.first!.0 { continue }
        return (s, suffix, digits)
    }
    return (v.rounded(), "", 0)
}

// MARK: - IntegerFormatStyle
public struct IntegerFormatStyle<Value: BinaryInteger>: FormatStyle, Sendable {
    public typealias Configuration = NumberFormatStyleConfiguration
    public var locale: Locale
    var collection = Configuration.Collection()
    public init(locale: Locale = .autoupdatingCurrent) { self.locale = locale }
    public func format(_ value: Value) -> String {
        _isimFormatNumber(String(value), kind: .number, locale: locale, config: collection, isInteger: true)
    }
    public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
    public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
    public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.collection.signDisplayStrategy = strategy; return s }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self { var s = self; s.collection.decimalSeparatorStrategy = strategy; return s }
    public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
        var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment.map(Double.init); return s
    }
    public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
    public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }

    public struct Percent: FormatStyle, Sendable {
        public var locale: Locale
        var collection = Configuration.Collection()
        public init(locale: Locale = .autoupdatingCurrent) { self.locale = locale }
        public func format(_ value: Value) -> String { _isimFormatNumber(String(value), kind: .percent, locale: locale, config: collection, isInteger: true) }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
        public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.collection.signDisplayStrategy = strategy; return s }
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self { var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment.map(Double.init); return s }
        public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
        public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
    }
    public struct Currency: FormatStyle, Sendable {
        public typealias Configuration = CurrencyFormatStyleConfiguration
        public var locale: Locale
        public let currencyCode: String
        var collection = NumberFormatStyleConfiguration.Collection()
        var presentation = Configuration.Presentation.standard
        var signStrategy: Configuration.SignDisplayStrategy?
        public init(code: String, locale: Locale = .autoupdatingCurrent) { currencyCode = code; self.locale = locale }
        public func format(_ value: Value) -> String {
            _isimFormatNumber(String(value), kind: .currency(code: currencyCode, presentation: presentation.kind.rawValue), locale: locale, config: collection, isInteger: false, currencySign: signStrategy)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
        public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.signStrategy = strategy; return s }
        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self { var s = self; s.collection.decimalSeparatorStrategy = strategy; return s }
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self { var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment.map(Double.init); return s }
        public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
        public func presentation(_ p: Configuration.Presentation) -> Self { var s = self; s.presentation = p; return s }
    }
}
extension IntegerFormatStyle: ParseableFormatStyle {
    public var parseStrategy: IntegerParseStrategy<Self> { IntegerParseStrategy(format: self, lenient: true) }
}
extension IntegerFormatStyle.Percent: ParseableFormatStyle {
    public var parseStrategy: IntegerParseStrategy<Self> { IntegerParseStrategy(format: self, lenient: true) }
}
extension IntegerFormatStyle.Currency: ParseableFormatStyle {
    public var parseStrategy: IntegerParseStrategy<Self> { IntegerParseStrategy(format: self, lenient: true) }
}
public struct IntegerParseStrategy<Format: FormatStyle>: ParseStrategy where Format.FormatInput: BinaryInteger, Format.FormatOutput == String {
    public var formatStyle: Format
    public var lenient: Bool
    public init(format: Format, lenient: Bool = true) { formatStyle = format; self.lenient = lenient }
    public func parse(_ value: String) throws -> Format.FormatInput {
        guard let d = _isimParseNumber(value, style: formatStyle), let v = Format.FormatInput(exactly: d.rounded(.towardZero)) else {
            throw _parseError(value, "an integer")
        }
        return v
    }
}
public struct FloatingPointParseStrategy<Format: FormatStyle>: ParseStrategy where Format.FormatInput: BinaryFloatingPoint, Format.FormatOutput == String {
    public var formatStyle: Format
    public var lenient: Bool
    public init(format: Format, lenient: Bool = true) { formatStyle = format; self.lenient = lenient }
    public func parse(_ value: String) throws -> Format.FormatInput {
        guard let d = _isimParseNumber(value, style: formatStyle) else { throw _parseError(value, "a number") }
        return Format.FormatInput(d)
    }
}
func _isimParseNumber<S: FormatStyle>(_ s: String, style: S) -> Double? {
    let mirror = Mirror(reflecting: style)
    let locale = mirror.children.first { $0.label == "locale" }?.value as? Locale ?? .current
    let f = NumberFormatter()
    f.locale = locale
    f.isLenient = true
    let name = String(describing: S.self)
    if name.contains("Percent") {
        f.numberStyle = .percent
        let isFloat = S.FormatInput.self is any BinaryFloatingPoint.Type || S.FormatInput.self == Decimal.self
        if let n = f.number(from: s) { return isFloat ? n.doubleValue : n.doubleValue * 100 }
        f.numberStyle = .decimal
        let stripped = s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return f.number(from: stripped).map { isFloat ? $0.doubleValue / 100 : $0.doubleValue }
    }
    if name.contains("Currency") {
        f.numberStyle = .currency
        if let code = mirror.children.first(where: { $0.label == "currencyCode" })?.value as? String { f.currencyCode = code }
        if let n = f.number(from: s) { return n.doubleValue }
        f.numberStyle = .decimal
        var t = s
        for sym in [f.currencySymbol ?? "", f.currencyCode ?? "", "$", "€", "£", "¥"] where !sym.isEmpty { t = t.replacingOccurrences(of: sym, with: "") }
        return f.number(from: t.trimmingCharacters(in: CharacterSet(charactersIn: " \u{A0}\u{202F}")))?.doubleValue
    }
    f.numberStyle = .decimal
    return f.number(from: s.trimmingCharacters(in: .whitespaces))?.doubleValue
}

// MARK: - FloatingPointFormatStyle
public struct FloatingPointFormatStyle<Value: BinaryFloatingPoint>: FormatStyle, Sendable {
    public typealias Configuration = NumberFormatStyleConfiguration
    public var locale: Locale
    var collection = Configuration.Collection()
    public init(locale: Locale = .autoupdatingCurrent) { self.locale = locale }
    public func format(_ value: Value) -> String {
        let d = Double(value)
        if d.isNaN { return "NaN" }
        if d.isInfinite { return d < 0 ? "-∞" : "∞" }
        return _isimFormatNumber(_decimalString(d), kind: .number, locale: locale, config: collection, isInteger: false)
    }
    public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
    public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
    public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.collection.signDisplayStrategy = strategy; return s }
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self { var s = self; s.collection.decimalSeparatorStrategy = strategy; return s }
    public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
        var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment; return s
    }
    public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
    public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }

    public struct Percent: FormatStyle, Sendable {
        public var locale: Locale
        var collection = Configuration.Collection()
        public init(locale: Locale = .autoupdatingCurrent) { self.locale = locale }
        public func format(_ value: Value) -> String { _isimFormatNumber(_decimalString(Double(value)), kind: .percent, locale: locale, config: collection, isInteger: false) }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
        public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.collection.signDisplayStrategy = strategy; return s }
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self { var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment; return s }
        public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
        public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
    }
    public struct Currency: FormatStyle, Sendable {
        public typealias Configuration = CurrencyFormatStyleConfiguration
        public var locale: Locale
        public let currencyCode: String
        var collection = NumberFormatStyleConfiguration.Collection()
        var presentation = Configuration.Presentation.standard
        var signStrategy: Configuration.SignDisplayStrategy?
        public init(code: String, locale: Locale = .autoupdatingCurrent) { currencyCode = code; self.locale = locale }
        public func format(_ value: Value) -> String {
            _isimFormatNumber(_decimalString(Double(value)), kind: .currency(code: currencyCode, presentation: presentation.kind.rawValue), locale: locale, config: collection, isInteger: false, currencySign: signStrategy)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
        public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.signStrategy = strategy; return s }
        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self { var s = self; s.collection.decimalSeparatorStrategy = strategy; return s }
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self { var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment; return s }
        public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
        public func presentation(_ p: Configuration.Presentation) -> Self { var s = self; s.presentation = p; return s }
    }
}
func _decimalString(_ d: Double) -> String { d == 0 ? (d.sign == .minus ? "-0" : "0") : "\(d)" }
extension FloatingPointFormatStyle: ParseableFormatStyle {
    public var parseStrategy: FloatingPointParseStrategy<Self> { FloatingPointParseStrategy(format: self, lenient: true) }
}
extension FloatingPointFormatStyle.Percent: ParseableFormatStyle {
    public var parseStrategy: FloatingPointParseStrategy<Self> { FloatingPointParseStrategy(format: self, lenient: true) }
}
extension FloatingPointFormatStyle.Currency: ParseableFormatStyle {
    public var parseStrategy: FloatingPointParseStrategy<Self> { FloatingPointParseStrategy(format: self, lenient: true) }
}

// MARK: - Decimal.FormatStyle
extension Decimal {
    public struct FormatStyle: Foundation.FormatStyle, Sendable {
        public typealias Configuration = NumberFormatStyleConfiguration
        public var locale: Locale
        var collection = Configuration.Collection()
        public init(locale: Locale = .autoupdatingCurrent) { self.locale = locale }
        public func format(_ value: Decimal) -> String { _isimFormatNumber(value.description, kind: .number, locale: locale, config: collection, isInteger: false) }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
        public func grouping(_ group: Configuration.Grouping) -> Self { var s = self; s.collection.group = group; return s }
        public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.collection.signDisplayStrategy = strategy; return s }
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self { var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment.map(Double.init); return s }
        public func scale(_ multiplicand: Double) -> Self { var s = self; s.collection.scale = multiplicand; return s }
        public func notation(_ notation: Configuration.Notation) -> Self { var s = self; s.collection.notation = notation; return s }
        public struct Percent: Foundation.FormatStyle, Sendable {
            public var locale: Locale
            var collection = Configuration.Collection()
            public init(locale: Locale = .autoupdatingCurrent) { self.locale = locale }
            public func format(_ value: Decimal) -> String { _isimFormatNumber(value.description, kind: .percent, locale: locale, config: collection, isInteger: false) }
            public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
            public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
        }
        public struct Currency: Foundation.FormatStyle, Sendable {
            public typealias Configuration = CurrencyFormatStyleConfiguration
            public var locale: Locale
            public let currencyCode: String
            var collection = NumberFormatStyleConfiguration.Collection()
            var presentation = Configuration.Presentation.standard
            var signStrategy: Configuration.SignDisplayStrategy?
            public init(code: String, locale: Locale = .autoupdatingCurrent) { currencyCode = code; self.locale = locale }
            public func format(_ value: Decimal) -> String {
                _isimFormatNumber(value.description, kind: .currency(code: currencyCode, presentation: presentation.kind.rawValue), locale: locale, config: collection, isInteger: false, currencySign: signStrategy)
            }
            public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
            public func precision(_ p: Configuration.Precision) -> Self { var s = self; s.collection.precision = p; return s }
            public func sign(strategy: Configuration.SignDisplayStrategy) -> Self { var s = self; s.signStrategy = strategy; return s }
            public func presentation(_ p: Configuration.Presentation) -> Self { var s = self; s.presentation = p; return s }
            public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self { var s = self; s.collection.rounding = rule; s.collection.roundingIncrement = increment.map(Double.init); return s }
        }
    }
    public func formatted() -> String { FormatStyle().format(self) }
    public func formatted<S: Foundation.FormatStyle>(_ format: S) -> S.FormatOutput where S.FormatInput == Decimal { format.format(self) }
    public init(_ value: String, format: Decimal.FormatStyle, lenient: Bool = true) throws {
        let f = NumberFormatter(); f.locale = format.locale; f.numberStyle = .decimal; f.isLenient = true
        guard let n = f.number(from: value), let d = Decimal(string: n.stringValue) else { throw _parseError(value, "a decimal") }
        self = d
    }
}

// MARK: - .formatted() on numbers
extension BinaryInteger {
    public func formatted() -> String { IntegerFormatStyle<Self>().format(self) }
    public func formatted<S: FormatStyle>(_ format: S) -> S.FormatOutput where Self == S.FormatInput { format.format(self) }
    public init<S: ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput == Self { self = try strategy.parse(value) }
    public init(_ value: String, format: IntegerFormatStyle<Self>, lenient: Bool = true) throws { self = try format.parseStrategy.parse(value) }
    public init(_ value: String, format: IntegerFormatStyle<Self>.Percent, lenient: Bool = true) throws { self = try format.parseStrategy.parse(value) }
    public init(_ value: String, format: IntegerFormatStyle<Self>.Currency, lenient: Bool = true) throws { self = try format.parseStrategy.parse(value) }
}
extension BinaryFloatingPoint {
    public func formatted() -> String { FloatingPointFormatStyle<Self>().format(self) }
    public func formatted<S: FormatStyle>(_ format: S) -> S.FormatOutput where Self == S.FormatInput { format.format(self) }
    public init<S: ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput == Self { self = try strategy.parse(value) }
    public init(_ value: String, format: FloatingPointFormatStyle<Self>, lenient: Bool = true) throws { self = try format.parseStrategy.parse(value) }
    public init(_ value: String, format: FloatingPointFormatStyle<Self>.Percent, lenient: Bool = true) throws { self = try format.parseStrategy.parse(value) }
    public init(_ value: String, format: FloatingPointFormatStyle<Self>.Currency, lenient: Bool = true) throws { self = try format.parseStrategy.parse(value) }
}

// static members: `.number`, `.percent`, `.currency(code:)` for each numeric type (Apple declares them per type)
extension FormatStyle where Self == IntegerFormatStyle<Int> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int8> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int16> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int32> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int64> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<UInt> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<UInt8> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<UInt16> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<UInt32> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<UInt64> { public static var number: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int>.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int64>.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int32>.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<UInt>.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == IntegerFormatStyle<Int>.Currency { public static func currency(code: String) -> Self { .init(code: code) } }
extension FormatStyle where Self == IntegerFormatStyle<Int64>.Currency { public static func currency(code: String) -> Self { .init(code: code) } }
extension FormatStyle where Self == IntegerFormatStyle<Int32>.Currency { public static func currency(code: String) -> Self { .init(code: code) } }
extension FormatStyle where Self == FloatingPointFormatStyle<Double> { public static var number: Self { .init() } }
extension FormatStyle where Self == FloatingPointFormatStyle<Float> { public static var number: Self { .init() } }
extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == FloatingPointFormatStyle<Float>.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Currency { public static func currency(code: String) -> Self { .init(code: code) } }
extension FormatStyle where Self == FloatingPointFormatStyle<Float>.Currency { public static func currency(code: String) -> Self { .init(code: code) } }
extension FormatStyle where Self == Decimal.FormatStyle { public static var number: Self { .init() } }
extension FormatStyle where Self == Decimal.FormatStyle.Percent { public static var percent: Self { .init() } }
extension FormatStyle where Self == Decimal.FormatStyle.Currency { public static func currency(code: String) -> Self { .init(code: code) } }
extension ParseStrategy where Self == IntegerParseStrategy<IntegerFormatStyle<Int>> { public static var number: Self { IntegerFormatStyle<Int>().parseStrategy } }
extension ParseStrategy where Self == FloatingPointParseStrategy<FloatingPointFormatStyle<Double>> { public static var number: Self { FloatingPointFormatStyle<Double>().parseStrategy } }

// MARK: - lists
public struct StringStyle: FormatStyle, Sendable {
    public init() {}
    public func format(_ value: String) -> String { value }
}
public struct ListFormatStyle<Style: FormatStyle, Base: Sequence>: FormatStyle where Style.FormatInput == Base.Element, Style.FormatOutput == String {
    public enum Width: Int, Codable, Hashable, Sendable { case standard, short, narrow }
    public enum ListType: Int, Codable, Hashable, Sendable { case and, or }
    public var width: Width
    public var listType: ListType
    public var locale: Locale
    var memberStyle: Style
    public init(memberStyle: Style) { self.memberStyle = memberStyle; width = .standard; listType = .and; locale = .autoupdatingCurrent }
    public func format(_ value: Base) -> String {
        let items = value.map { memberStyle.format($0) }
        return ListFormatter._isim_join(items, locale: locale, orList: listType == .or, width: width.rawValue)
    }
    public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    enum CodingKeys: String, CodingKey { case width, listType, locale, memberStyle }
}
extension ListFormatStyle: Sendable where Style: Sendable {}
extension FormatStyle {
    public static func list<MemberStyle: FormatStyle, Base: Sequence>(memberStyle: MemberStyle, type: Self.ListType, width: Self.Width = .standard) -> Self
        where Self == ListFormatStyle<MemberStyle, Base> {
        var s = ListFormatStyle<MemberStyle, Base>(memberStyle: memberStyle); s.listType = type; s.width = width; return s
    }
    public static func list<Base: Sequence>(type: Self.ListType, width: Self.Width = .standard) -> Self
        where Self == ListFormatStyle<StringStyle, Base>, Base.Element == String {
        var s = ListFormatStyle<StringStyle, Base>(memberStyle: StringStyle()); s.listType = type; s.width = width; return s
    }
}
extension Sequence {
    public func formatted<S: FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == Self { style.format(self) }
}
extension Sequence where Element == String {
    public func formatted() -> String { ListFormatStyle<StringStyle, Self>(memberStyle: StringStyle()).format(self) }
}

// MARK: - byte counts
public struct ByteCountFormatStyle: FormatStyle, Sendable {
    public enum Style: Int, Codable, Hashable, Sendable { case file, memory, decimal, binary }
    public struct Units: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let bytes = Units(rawValue: 1 << 0), kb = Units(rawValue: 1 << 1), mb = Units(rawValue: 1 << 2), gb = Units(rawValue: 1 << 3)
        public static let tb = Units(rawValue: 1 << 4), pb = Units(rawValue: 1 << 5), eb = Units(rawValue: 1 << 6), zb = Units(rawValue: 1 << 7)
        public static let ybOrHigher = Units(rawValue: 0xFF << 8)
        public static let all = Units(rawValue: 0xFFFF)
        public static let `default`: Units = []
    }
    public var style: Style
    public var allowedUnits: Units
    public var spellsOutZero: Bool
    public var includesActualByteCount: Bool
    public var locale: Locale
    public init(style: Style = .file, allowedUnits: Units = .all, spellsOutZero: Bool = true, includesActualByteCount: Bool = false, locale: Locale = .autoupdatingCurrent) {
        self.style = style; self.allowedUnits = allowedUnits; self.spellsOutZero = spellsOutZero; self.includesActualByteCount = includesActualByteCount; self.locale = locale
    }
    public func format(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = ByteCountFormatter.CountStyle(rawValue: style.rawValue) ?? .file
        f.allowedUnits = ByteCountFormatter.Units(rawValue: UInt(allowedUnits.rawValue))
        f.allowsNonnumericFormatting = spellsOutZero
        f.includesActualByteCount = includesActualByteCount
        return f._isim_string(value, locale: locale, lowercaseK: true)
    }
    public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
}
extension FormatStyle where Self == ByteCountFormatStyle {
    public static func byteCount(style: ByteCountFormatStyle.Style, allowedUnits: ByteCountFormatStyle.Units = .all, spellsOutZero: Bool = true, includesActualByteCount: Bool = false) -> Self {
        ByteCountFormatStyle(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount)
    }
}

// MARK: - Duration
extension Duration {
    var _seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
    public struct TimeFormatStyle: FormatStyle, Sendable {
        public struct Pattern: Codable, Hashable, Sendable {
            enum Kind: Int, Codable, Hashable { case hourMinute, hourMinuteSecond, minuteSecond }
            let kind: Kind
            var padHour = 1, padMinute = 1
            var fractional = 0
            var roundSeconds: FloatingPointRoundingRule = .toNearestOrEven
            public static var hourMinute: Pattern { .init(kind: .hourMinute) }
            public static var hourMinuteSecond: Pattern { .init(kind: .hourMinuteSecond) }
            public static var minuteSecond: Pattern { .init(kind: .minuteSecond) }
            public static func hourMinute(padHourToLength: Int, roundSeconds: FloatingPointRoundingRule = .toNearestOrEven) -> Pattern { .init(kind: .hourMinute, padHour: padHourToLength, roundSeconds: roundSeconds) }
            public static func hourMinuteSecond(padHourToLength: Int, fractionalSecondsLength: Int = 0, roundFractionalSeconds: FloatingPointRoundingRule = .toNearestOrEven) -> Pattern {
                .init(kind: .hourMinuteSecond, padHour: padHourToLength, fractional: fractionalSecondsLength, roundSeconds: roundFractionalSeconds)
            }
            public static func minuteSecond(padMinuteToLength: Int, fractionalSecondsLength: Int = 0, roundFractionalSeconds: FloatingPointRoundingRule = .toNearestOrEven) -> Pattern {
                .init(kind: .minuteSecond, padMinute: padMinuteToLength, fractional: fractionalSecondsLength, roundSeconds: roundFractionalSeconds)
            }
        }
        public var pattern: Pattern
        public var locale: Locale
        public init(pattern: Pattern, locale: Locale = .autoupdatingCurrent) { self.pattern = pattern; self.locale = locale }
        public func format(_ value: Duration) -> String {
            var t = value._seconds
            let neg = t < 0; t = Swift.abs(t)
            let frac = pattern.fractional
            let p = pow(10.0, Double(frac))
            func pad(_ v: Int, _ n: Int) -> String { let s = String(v); return s.count >= n ? s : String(repeating: "0", count: n - s.count) + s }
            let dec = locale.decimalSeparator ?? "."
            var out: String
            switch pattern.kind {
            case .hourMinute:
                let mins = (t / 60).rounded(pattern.roundSeconds)
                out = "\(pad(Int(mins) / 60, pattern.padHour)):\(pad(Int(mins) % 60, 2))"
            case .hourMinuteSecond, .minuteSecond:
                let total = (t * p).rounded(pattern.roundSeconds) / p
                let whole = Int(total)
                let fracDigits = frac > 0 ? dec + pad(Int(((total - Double(whole)) * p).rounded()), frac) : ""
                if pattern.kind == .hourMinuteSecond {
                    out = "\(pad(whole / 3600, pattern.padHour)):\(pad(whole / 60 % 60, 2)):\(pad(whole % 60, 2))\(fracDigits)"
                } else {
                    out = "\(pad(whole / 60, pattern.padMinute)):\(pad(whole % 60, 2))\(fracDigits)"
                }
            }
            return neg ? "-" + out : out
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
    public struct UnitsFormatStyle: FormatStyle, Sendable {
        public struct Unit: Codable, Hashable, Sendable {
            let index: Int     // 0 weeks, 1 days, 2 hours, 3 minutes, 4 seconds, 5 ms, 6 µs, 7 ns
            public static var weeks: Unit { .init(index: 0) }
            public static var days: Unit { .init(index: 1) }
            public static var hours: Unit { .init(index: 2) }
            public static var minutes: Unit { .init(index: 3) }
            public static var seconds: Unit { .init(index: 4) }
            public static var milliseconds: Unit { .init(index: 5) }
            public static var microseconds: Unit { .init(index: 6) }
            public static var nanoseconds: Unit { .init(index: 7) }
        }
        public struct UnitWidth: Codable, Hashable, Sendable {
            let kind: Int
            public static var wide: UnitWidth { .init(kind: 0) }
            public static var abbreviated: UnitWidth { .init(kind: 1) }
            public static var condensedAbbreviated: UnitWidth { .init(kind: 2) }
            public static var narrow: UnitWidth { .init(kind: 3) }
        }
        public struct ZeroValueUnitsDisplayStrategy: Codable, Hashable, Sendable {
            let show: Int?
            public static var hide: Self { .init(show: nil) }
            public static func show(length: Int) -> Self { .init(show: length) }
        }
        public struct FractionalPartDisplayStrategy: Codable, Hashable, Sendable {
            let length: Int
            public static var hide: Self { .init(length: 0) }
            public static func show(length: Int, rounded rule: FloatingPointRoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self { .init(length: length) }
        }
        public var allowedUnits: Set<Unit>
        public var unitWidth: UnitWidth
        public var maximumUnitCount: Int?
        public var zeroValueUnitsDisplay: ZeroValueUnitsDisplayStrategy
        public var fractionalPartDisplay: FractionalPartDisplayStrategy
        public var locale: Locale
        public init(allowedUnits: Set<Unit>, width: UnitWidth, maximumUnitCount: Int? = nil, zeroValueUnits: ZeroValueUnitsDisplayStrategy = .hide,
                    valueLength: Int? = nil, fractionalPart: FractionalPartDisplayStrategy = .hide) {
            self.allowedUnits = allowedUnits; unitWidth = width; self.maximumUnitCount = maximumUnitCount
            zeroValueUnitsDisplay = zeroValueUnits; fractionalPartDisplay = fractionalPart; locale = .autoupdatingCurrent
        }
        public func format(_ value: Duration) -> String {
            let secondsPer: [Double] = [604800, 86400, 3600, 60, 1, 1e-3, 1e-6, 1e-9]
            var rem = Swift.abs(value._seconds)
            let units = allowedUnits.map(\.index).sorted()
            guard !units.isEmpty else { return "" }
            var parts: [(Int, Double)] = []
            for (k, u) in units.enumerated() {
                let last = k == units.count - 1
                var v = rem / secondsPer[u]
                if last {
                    let p = pow(10.0, Double(fractionalPartDisplay.length))
                    v = (v * p).rounded() / p
                } else { v = (v + 1e-9).rounded(.down) }
                rem -= v * secondsPer[u]
                parts.append((u, v))
            }
            var shown = parts.filter { zeroValueUnitsDisplay.show != nil || $0.1 != 0 }
            if shown.isEmpty { shown = [parts.last!] }
            if let m = maximumUnitCount { shown = Array(shown.prefix(m)) }
            let lang = locale.languageCode ?? "en"
            let strings = shown.map { _durationUnit(value: $0.1, unit: $0.0, width: unitWidth.kind, lang: lang, locale: locale) }
            var joined: String
            switch unitWidth.kind {
            case 3, 2: joined = strings.joined(separator: " ")
            default: joined = strings.joined(separator: lang == "ja" ? " " : ", ")
            }
            if !_durationTableLanguages.contains(lang), strings.count > 1,
               let l = _icuList(locale, strings, type: 2, width: unitWidth.kind == 0 ? 0 : unitWidth.kind == 1 ? 1 : 2) { joined = l }
            return value._seconds < 0 ? "-" + joined : joined
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
    public func formatted() -> String { TimeFormatStyle(pattern: .hourMinuteSecond).format(self) }
    public func formatted<S: FormatStyle>(_ v: S) -> S.FormatOutput where S.FormatInput == Duration { v.format(self) }
}
let _durationTableLanguages: Set<String> = ["en", "pt", "es", "fr", "de"]
func _durationUnit(value: Double, unit: Int, width: Int, lang: String, locale: Locale) -> String {
    let n = NumberFormatter(); n.locale = locale; n.numberStyle = .decimal; n.maximumFractionDigits = 6
    let num = n.string(from: NSNumber(value: value)) ?? "\(value)"
    if !_durationTableLanguages.contains(lang) {   // other languages: ICU's unit names (CLDR)
        let ids = ["duration-week", "duration-day", "duration-hour", "duration-minute", "duration-second", "duration-millisecond", "duration-microsecond", "duration-nanosecond"]
        if let p = _icuUnitPhrase(locale, unit: ids[unit], value: value, number: num, width: width == 0 ? 2 : width == 1 ? 1 : 0) { return p }
    }
    let one = value == 1
    let en: [(String, String, String, String)] = [("week", "weeks", "wk", "w"), ("day", "days", "day", "d"), ("hour", "hours", "hr", "h"), ("minute", "minutes", "min", "m"),
                                                  ("second", "seconds", "sec", "s"), ("millisecond", "milliseconds", "ms", "ms"), ("microsecond", "microseconds", "μs", "μs"), ("nanosecond", "nanoseconds", "ns", "ns")]
    let pt: [(String, String, String, String)] = [("semana", "semanas", "sem.", "sem."), ("dia", "dias", "dia", "d"), ("hora", "horas", "h", "h"), ("minuto", "minutos", "min", "min"),
                                                  ("segundo", "segundos", "s", "s"), ("milissegundo", "milissegundos", "ms", "ms"), ("microssegundo", "microssegundos", "μs", "μs"), ("nanossegundo", "nanossegundos", "ns", "ns")]
    let es: [(String, String, String, String)] = [("semana", "semanas", "sem.", "sem."), ("día", "días", "d", "d"), ("hora", "horas", "h", "h"), ("minuto", "minutos", "min", "min"),
                                                  ("segundo", "segundos", "s", "s"), ("milisegundo", "milisegundos", "ms", "ms"), ("microsegundo", "microsegundos", "μs", "μs"), ("nanosegundo", "nanosegundos", "ns", "ns")]
    let fr: [(String, String, String, String)] = [("semaine", "semaines", "sem.", "sem."), ("jour", "jours", "j", "j"), ("heure", "heures", "h", "h"), ("minute", "minutes", "min", "min"),
                                                  ("seconde", "secondes", "s", "s"), ("milliseconde", "millisecondes", "ms", "ms"), ("microseconde", "microsecondes", "μs", "μs"), ("nanoseconde", "nanosecondes", "ns", "ns")]
    let de: [(String, String, String, String)] = [("Woche", "Wochen", "Wo.", "W"), ("Tag", "Tage", "Tg.", "T"), ("Stunde", "Stunden", "Std.", "h"), ("Minute", "Minuten", "Min.", "m"),
                                                  ("Sekunde", "Sekunden", "Sek.", "s"), ("Millisekunde", "Millisekunden", "ms", "ms"), ("Mikrosekunde", "Mikrosekunden", "μs", "μs"), ("Nanosekunde", "Nanosekunden", "ns", "ns")]
    let table = ["pt": pt, "es": es, "fr": fr, "de": de][lang] ?? en
    let (w1, wn, ab, nar) = table[unit]
    let singular = lang == "fr" || lang == "pt" ? value < 2 : one
    switch width {
    case 0: return "\(num) \(singular ? w1 : wn)"
    case 1: return lang == "en" && unit == 1 && !one ? "\(num) days" : "\(num) \(ab)"
    case 2: return "\(num)\(ab)"
    default: return "\(num)\(nar)"
    }
}
extension FormatStyle where Self == Duration.TimeFormatStyle {
    public static func time(pattern: Duration.TimeFormatStyle.Pattern) -> Self { .init(pattern: pattern) }
}
extension FormatStyle where Self == Duration.UnitsFormatStyle {
    public static func units(allowed units: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds], width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated,
                             maximumUnitCount: Int? = nil, zeroValueUnits: Duration.UnitsFormatStyle.ZeroValueUnitsDisplayStrategy = .hide,
                             valueLength: Int? = nil, fractionalPart: Duration.UnitsFormatStyle.FractionalPartDisplayStrategy = .hide) -> Self {
        .init(allowedUnits: units, width: width, maximumUnitCount: maximumUnitCount, zeroValueUnits: zeroValueUnits, valueLength: valueLength, fractionalPart: fractionalPart)
    }
}
