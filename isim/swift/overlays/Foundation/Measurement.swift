// isim Foundation: Measurement<UnitType> (value type over Foundation's NSUnit classes), unit conversion and
// arithmetic, Measurement.FormatStyle and MeasurementFormatter for Swift measurements.

public struct Measurement<UnitType: Unit>: Hashable, Comparable, CustomStringConvertible, CustomDebugStringConvertible, @unchecked Sendable {
    public let unit: UnitType
    public var value: Double
    public init(value: Double, unit: UnitType) { self.value = value; self.unit = unit }
    public var description: String { "\(value) \(unit.symbol)" }
    public var debugDescription: String { "\(value) \(unit.symbol)" }
    public func hash(into h: inout Hasher) {
        if let d = unit as? Dimension { h.combine(d.converter.baseUnitValue(fromValue: value)) } else { h.combine(value); h.combine(unit) }
    }
    public static func == (a: Measurement, b: Measurement) -> Bool {
        if a.unit == b.unit { return a.value == b.value }
        guard let da = a.unit as? Dimension, let db = b.unit as? Dimension, type(of: da) == type(of: db) || da.isKind(of: type(of: db)) || db.isKind(of: type(of: da)) else { return false }
        return da.converter.baseUnitValue(fromValue: a.value) == db.converter.baseUnitValue(fromValue: b.value)
    }
    public static func < (a: Measurement, b: Measurement) -> Bool {
        if a.unit == b.unit { return a.value < b.value }
        guard let da = a.unit as? Dimension, let db = b.unit as? Dimension else { return a.value < b.value }
        return da.converter.baseUnitValue(fromValue: a.value) < db.converter.baseUnitValue(fromValue: b.value)
    }
}
extension Measurement where UnitType: Dimension {
    public func converted(to otherUnit: UnitType) -> Measurement<UnitType> {
        if unit == otherUnit { return Measurement(value: value, unit: otherUnit) }
        let base = unit.converter.baseUnitValue(fromValue: value)
        return Measurement(value: otherUnit.converter.value(fromBaseUnitValue: base), unit: otherUnit)
    }
    public mutating func convert(to otherUnit: UnitType) { self = converted(to: otherUnit) }
    public static func + (a: Measurement, b: Measurement) -> Measurement {
        if a.unit == b.unit { return Measurement(value: a.value + b.value, unit: a.unit) }
        let base = type(of: a.unit).baseUnit()
        return Measurement(value: a.converted(to: base).value + b.converted(to: base).value, unit: base)
    }
    public static func - (a: Measurement, b: Measurement) -> Measurement {
        if a.unit == b.unit { return Measurement(value: a.value - b.value, unit: a.unit) }
        let base = type(of: a.unit).baseUnit()
        return Measurement(value: a.converted(to: base).value - b.converted(to: base).value, unit: base)
    }
}
extension Measurement {
    public static func * (m: Measurement, s: Double) -> Measurement { Measurement(value: m.value * s, unit: m.unit) }
    public static func * (s: Double, m: Measurement) -> Measurement { Measurement(value: m.value * s, unit: m.unit) }
    public static func / (m: Measurement, s: Double) -> Measurement { Measurement(value: m.value / s, unit: m.unit) }
    public static func / (s: Double, m: Measurement) -> Measurement { Measurement(value: s / m.value, unit: m.unit) }
    public static prefix func - (m: Measurement) -> Measurement { Measurement(value: -m.value, unit: m.unit) }
    public static func += (a: inout Measurement, b: Measurement) where UnitType: Dimension { a = a + b }
    public static func -= (a: inout Measurement, b: Measurement) where UnitType: Dimension { a = a - b }
}
extension Measurement: Codable {
    enum CodingKeys: String, CodingKey { case value, unit }
    enum UnitKeys: String, CodingKey { case symbol, converter }
    enum ConverterKeys: String, CodingKey { case coefficient, constant }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let value = try c.decode(Double.self, forKey: .value)
        let u = try c.nestedContainer(keyedBy: UnitKeys.self, forKey: .unit)
        let symbol = try u.decode(String.self, forKey: .symbol)
        if let dimType = UnitType.self as? Dimension.Type {
            // a known unit of that dimension with the same symbol, else a new one with the encoded converter
            let cv = try? u.nestedContainer(keyedBy: ConverterKeys.self, forKey: .converter)
            let coef = (try? cv?.decode(Double.self, forKey: .coefficient)) ?? 1
            let const = (try? cv?.decode(Double.self, forKey: .constant)) ?? 0
            let unit = dimType.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coef, constant: const))
            guard let typed = unit as? UnitType else { throw DecodingError.dataCorruptedError(forKey: .unit, in: c, debugDescription: "unit type mismatch") }
            self.init(value: value, unit: typed)
        } else {
            guard let typed = UnitType(symbol: symbol) as UnitType? else { throw DecodingError.dataCorruptedError(forKey: .unit, in: c, debugDescription: "bad unit") }
            self.init(value: value, unit: typed)
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(value, forKey: .value)
        var u = c.nestedContainer(keyedBy: UnitKeys.self, forKey: .unit)
        try u.encode(unit.symbol, forKey: .symbol)
        if let d = unit as? Dimension, let lin = d.converter as? UnitConverterLinear {
            var cv = u.nestedContainer(keyedBy: ConverterKeys.self, forKey: .converter)
            try cv.encode(lin.coefficient, forKey: .coefficient); try cv.encode(lin.constant, forKey: .constant)
        }
    }
}
extension Measurement: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSMeasurement { NSMeasurement(doubleValue: value, unit: unit) }
    public static func _forceBridgeFromObjectiveC(_ x: NSMeasurement, result: inout Measurement?) {
        result = (x.unit as? UnitType).map { Measurement(value: x.doubleValue, unit: $0) }
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSMeasurement, result: inout Measurement?) -> Bool {
        _forceBridgeFromObjectiveC(x, result: &result); return result != nil
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSMeasurement?) -> Measurement {
        var r: Measurement?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r!
    }
}
extension MeasurementFormatter {
    public func string<UnitType>(from measurement: Measurement<UnitType>) -> String { string(from: NSMeasurement(doubleValue: measurement.value, unit: measurement.unit)) }
}

// MARK: - Measurement.FormatStyle
public struct MeasurementFormatUnitUsage<UnitType: Dimension>: Codable, Hashable, Sendable {
    let usage: String
    public static var general: Self { .init(usage: "general") }
    public static var asProvided: Self { .init(usage: "asProvided") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitLength {
    public static var person: Self { .init(usage: "person") }
    public static var personHeight: Self { .init(usage: "person") }
    public static var road: Self { .init(usage: "general") }
    public static var focalLength: Self { .init(usage: "asProvided") }
    public static var rainfall: Self { .init(usage: "general") }
    public static var snowfall: Self { .init(usage: "general") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitTemperature {
    public static var weather: Self { .init(usage: "general") }
    public static var person: Self { .init(usage: "general") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitMass {
    public static var personWeight: Self { .init(usage: "general") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitSpeed {
    public static var wind: Self { .init(usage: "general") }
}
extension MeasurementFormatUnitUsage where UnitType == UnitEnergy {
    public static var food: Self { .init(usage: "asProvided") }
    public static var workout: Self { .init(usage: "asProvided") }
}
extension Measurement where UnitType: Dimension {
    public struct FormatStyle: Foundation.FormatStyle, @unchecked Sendable {
        public struct UnitWidth: Codable, Hashable, Sendable {
            let raw: Int
            public static var wide: UnitWidth { .init(raw: 2) }
            public static var abbreviated: UnitWidth { .init(raw: 1) }
            public static var narrow: UnitWidth { .init(raw: 0) }
        }
        public var width: UnitWidth
        public var locale: Locale
        public var usage: MeasurementFormatUnitUsage<UnitType>?
        public var numberFormatStyle: FloatingPointFormatStyle<Double>?
        public var hidesScaleName: Bool = false
        public init(width: UnitWidth, locale: Locale = .autoupdatingCurrent, usage: MeasurementFormatUnitUsage<UnitType> = .general, numberFormatStyle: FloatingPointFormatStyle<Double>? = nil) {
            self.width = width; self.locale = locale; self.usage = usage; self.numberFormatStyle = numberFormatStyle
        }
        public func format(_ m: Measurement<UnitType>) -> String {
            let ns = NSMeasurement(doubleValue: m.value, unit: m.unit)._isim_measurementInPreferredUnit(for: locale, usage: usage?.usage ?? "general")
            let v = ns.doubleValue
            let number: String
            if let nfs = numberFormatStyle { number = nfs.locale(locale).format(v) }
            else { number = FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(0...2)).format(v) }
            return MeasurementFormatter._isim_formatNumber(number, value: v, unit: ns.unit, width: width.raw, locale: locale)
        }
        public func locale(_ locale: Locale) -> Self { var s = self; s.locale = locale; return s }
    }
    public func formatted() -> String { FormatStyle(width: .abbreviated).format(self) }
    public func formatted<S: Foundation.FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == Measurement<UnitType> { style.format(self) }
}
extension FormatStyle {
    public static func measurement<UnitType: Dimension>(width: Measurement<UnitType>.FormatStyle.UnitWidth, usage: MeasurementFormatUnitUsage<UnitType> = .general,
                                                        numberFormatStyle: FloatingPointFormatStyle<Double>? = nil) -> Self where Self == Measurement<UnitType>.FormatStyle {
        Measurement<UnitType>.FormatStyle(width: width, usage: usage, numberFormatStyle: numberFormatStyle)
    }
}
