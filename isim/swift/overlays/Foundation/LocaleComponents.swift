// isim Foundation: Locale's typed preferences (region, currency, measurement system, hour cycle, first day of the
// week, collation, numbering system, subdivision, variant, time zone), Locale.Components and the lists of available
// identifiers and ISO codes, as Apple's Foundation. A locale's ICU keywords override its region's defaults
// ("en_US@hours=h23;fw=mon", or BCP 47 "en-US-u-hc-h23-fw-mon"); the defaults come from the host's ICU (CLDR) when
// it has one, else from isim's built-in tables (adapted).
import isim_host

extension Locale {
    public struct Currency: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        public var isISOCurrency: Bool { Locale.Currency._iso.contains(identifier.uppercased()) }
        public static var isoCurrencies: [Locale.Currency] { NSLocale.isoCurrencyCodes.map { Locale.Currency($0) } }
        public static let unknown = Locale.Currency("xxx")
        static let _iso: Set<String> = Set(NSLocale.isoCurrencyCodes)
    }

    public struct MeasurementSystem: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        public static let metric = MeasurementSystem("metric")
        public static let us = MeasurementSystem("ussystem")
        public static let uk = MeasurementSystem("uksystem")
        public static var measurementSystems: [MeasurementSystem] { [.metric, .us, .uk] }
    }

    public enum HourCycle: String, Codable, Hashable, Sendable {
        case zeroToEleven = "h11", oneToTwelve = "h12", zeroToTwentyThree = "h23", oneToTwentyFour = "h24"
    }

    public enum Weekday: String, Codable, Hashable, Sendable {
        case sunday = "sun", monday = "mon", tuesday = "tue", wednesday = "wed", thursday = "thu", friday = "fri", saturday = "sat"
        static let all: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        /// 1 = Sunday, like Calendar's weekday
        var _number: Int { Weekday.all.firstIndex(of: self)! + 1 }
    }

    public struct Collation: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        public static let standard = Collation("standard")
        public static let searchRules = Collation("search")
        public static var availableCollations: [Collation] { availableCollations(for: Locale.current.language) }
        /// the collations the language has (ICU's), standard first
        public static func availableCollations(for language: Locale.Language) -> [Collation] {
            let list = _isimCodes(4, language.minimalIdentifier.replacingOccurrences(of: "-", with: "_")) ?? ["standard", "search"]
            return list.map { Collation($0) }
        }
    }

    public struct NumberingSystem: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        public static let latn = NumberingSystem("latn")
    }

    public struct Subdivision: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        /// the whole region ("gbzzzz")
        public static func subdivision(for region: Locale.Region) -> Subdivision { Subdivision(region.identifier.lowercased() + "zzzz") }
    }

    public struct Variant: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        public static let posix = Variant("POSIX")
    }

    public struct Script: Hashable, Sendable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral identifier: String) { self.identifier = identifier }
        public var debugDescription: String { identifier }
        public var isISOScript: Bool { identifier.count == 4 && identifier.allSatisfy(\.isLetter) }
        public static let unknown = Script("Zzzz")
        public static let latin = Script("Latn")
        public static let cyrillic = Script("Cyrl")
        public static let arabic = Script("Arab")
        public static let hebrew = Script("Hebr")
        public static let greek = Script("Grek")
        public static let hanSimplified = Script("Hans")
        public static let hanTraditional = Script("Hant")
        public static let japanese = Script("Jpan")
        public static let korean = Script("Kore")
        public static let devanagari = Script("Deva")
        public static let thai = Script("Thai")
    }
}

extension Locale.Region: Codable {
    public init(from decoder: Decoder) throws { self.init(try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(identifier) }
}
extension Locale.Region {
    public var isISORegion: Bool { Locale.Region._iso.contains(identifier.uppercased()) }
    public static var isoRegions: [Locale.Region] { NSLocale.isoCountryCodes.map { Locale.Region($0) } }
    public static let unknown = Locale.Region("ZZ")
    static let _iso: Set<String> = Set(NSLocale.isoCountryCodes)
}
extension Locale.LanguageCode: Codable {
    public init(from decoder: Decoder) throws { self.init(try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(identifier) }
}

extension Locale.Language {
    public struct Components: Hashable, Sendable, Codable {
        public var languageCode: Locale.LanguageCode?
        public var script: Locale.Script?
        public var region: Locale.Region?
        public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
            self.languageCode = languageCode; self.script = script; self.region = region
        }
        public init(identifier: String) {
            let p = _LocaleID(identifier)
            self.init(languageCode: p.language.map { Locale.LanguageCode($0) }, script: p.script.map { Locale.Script($0) },
                      region: p.region.map { Locale.Region($0) })
        }
        public init(language: Locale.Language) { self.init(identifier: language.minimalIdentifier) }
        var _identifier: String { [languageCode?.identifier, script?.identifier, region?.identifier].compactMap { $0 }.joined(separator: "-") }
    }
    public init(components: Locale.Language.Components) { self.init(identifier: components._identifier) }
    public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
        self.init(components: Components(languageCode: languageCode, script: script, region: region))
    }
    public var components: Locale.Language.Components { Components(identifier: minimalIdentifier) }
    public var script: Locale.Script? { _LocaleID(minimalIdentifier).script.map { Locale.Script($0) } }
}

extension Locale {
    public struct Components: Hashable, Sendable, Codable {
        public var languageComponents: Locale.Language.Components
        public var calendar: Calendar.Identifier?
        public var collation: Locale.Collation?
        public var currency: Locale.Currency?
        public var numberingSystem: Locale.NumberingSystem?
        public var firstDayOfWeek: Locale.Weekday?
        public var hourCycle: Locale.HourCycle?
        public var measurementSystem: Locale.MeasurementSystem?
        /// the region whose preferences apply (the "rg" keyword), when they differ from the language's region
        public var region: Locale.Region?
        public var subdivision: Locale.Subdivision?
        public var timeZone: TimeZone?
        public var variant: Locale.Variant?

        public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil) {
            languageComponents = Locale.Language.Components(languageCode: languageCode, script: script, region: languageRegion)
        }
        public init(identifier: String) {
            let p = _LocaleID(identifier)
            languageComponents = Locale.Language.Components(languageCode: p.language.map { Locale.LanguageCode($0) },
                                                            script: p.script.map { Locale.Script($0) }, region: p.region.map { Locale.Region($0) })
            let k = p.keywords
            calendar = k["calendar"].flatMap { Calendar.Identifier(_icuName: $0) }
            collation = k["collation"].map { Locale.Collation($0) }
            currency = k["currency"].map { Locale.Currency($0.uppercased()) }
            numberingSystem = k["numbers"].map { Locale.NumberingSystem($0) }
            firstDayOfWeek = k["fw"].flatMap(Locale.Weekday.init(rawValue:))
            hourCycle = k["hours"].flatMap(Locale.HourCycle.init(rawValue:))
            measurementSystem = k["measure"].map { Locale.MeasurementSystem($0) }
            region = k["rg"].map { Locale.Region(String($0.prefix(2)).uppercased()) }
            subdivision = k["sd"].map { Locale.Subdivision($0) }
            timeZone = k["timezone"].flatMap(TimeZone.init(identifier:))
            variant = p.variant.map { Locale.Variant($0) }
        }
        public init(locale: Locale) { self.init(identifier: locale.identifier) }

        /// the ICU identifier: language_Script_REGION_VARIANT@keyword=value;... (keywords in alphabetical order)
        var _icuIdentifier: String {
            var base = [languageComponents.languageCode?.identifier ?? "", languageComponents.script?.identifier,
                        languageComponents.region?.identifier].compactMap { $0 }.joined(separator: "_")
            if let variant { base += (languageComponents.region == nil ? "__" : "_") + variant.identifier }
            var k: [(String, String)] = []
            if let calendar { k.append(("calendar", calendar._icuName)) }
            if let collation { k.append(("collation", collation.identifier)) }
            if let currency { k.append(("currency", currency.identifier.lowercased())) }
            if let firstDayOfWeek { k.append(("fw", firstDayOfWeek.rawValue)) }
            if let hourCycle { k.append(("hours", hourCycle.rawValue)) }
            if let measurementSystem { k.append(("measure", measurementSystem.identifier)) }
            if let numberingSystem { k.append(("numbers", numberingSystem.identifier)) }
            if let region { k.append(("rg", region.identifier.lowercased() + "zzzz")) }
            if let subdivision { k.append(("sd", subdivision.identifier)) }
            if let timeZone { k.append(("timezone", timeZone.identifier)) }
            return k.isEmpty ? base : base + "@" + k.map { "\($0.0)=\($0.1)" }.joined(separator: ";")
        }
    }

    public init(components: Locale.Components) { self.init(identifier: components._icuIdentifier) }
    public init(languageComponents: Locale.Language.Components) {
        self.init(identifier: languageComponents._identifier.replacingOccurrences(of: "-", with: "_"))
    }
    public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil) {
        self.init(components: Locale.Components(languageCode: languageCode, script: script, languageRegion: languageRegion))
    }

    var _id: _LocaleID { _LocaleID(identifier) }

    /// the region whose preferences the locale follows: the "rg" keyword, else the language's region
    public var region: Locale.Region? {
        if let rg = _id.keywords["rg"], rg.count >= 2 { return Locale.Region(String(rg.prefix(2)).uppercased()) }
        return regionCode.map { Locale.Region($0) }
    }
    public var currency: Locale.Currency? {
        if let c = _id.keywords["currency"] { return Locale.Currency(c.uppercased()) }
        if let rg = _id.keywords["rg"], rg.count >= 2 {
            return Locale(identifier: "und_" + rg.prefix(2).uppercased()).currencyCode.map { Locale.Currency($0) }
        }
        return currencyCode.map { Locale.Currency($0) }
    }
    /// metric, except the US, Liberia and Myanmar (US customary) and the UK (imperial), as CLDR
    public var measurementSystem: Locale.MeasurementSystem {
        if let m = _id.keywords["measure"] { return Locale.MeasurementSystem(m) }
        switch region?.identifier {
        case "US", "LR", "MM": return .us
        case "GB": return .uk
        default: return .metric
        }
    }
    /// the "hours" keyword, else the user's 24-Hour Time setting (the current locale) or the region's default
    public var hourCycle: Locale.HourCycle {
        if let h = _id.keywords["hours"].flatMap(Locale.HourCycle.init(rawValue:)) { return h }
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: self) ?? "h"
        var quoted = false
        for ch in pattern {
            if ch == "'" { quoted.toggle(); continue }
            if quoted { continue }
            switch ch {
            case "H": return .zeroToTwentyThree
            case "k": return .oneToTwentyFour
            case "K": return .zeroToEleven
            case "h": return .oneToTwelve
            default: continue
            }
        }
        return .oneToTwelve
    }
    /// the "fw" keyword, else the region's first day of the week (CLDR weekData)
    public var firstDayOfWeek: Locale.Weekday {
        if let w = _id.keywords["fw"].flatMap(Locale.Weekday.init(rawValue:)) { return w }
        var fw: Int32 = 0, md: Int32 = 0
        let ident = region.map { (languageCode ?? "und") + "_" + $0.identifier } ?? identifier
        if isim_icu_week_data(ident, &fw, &md) == 0, (1...7).contains(Int(fw)) { return Locale.Weekday.all[Int(fw) - 1] }
        return Locale.Weekday.all[Calendar._defaultFirstWeekday(region: region?.identifier) - 1]
    }
    public var collation: Locale.Collation { _id.keywords["collation"].map { Locale.Collation($0) } ?? .standard }
    /// the "numbers" keyword, else the digits the locale formats numbers with
    public var numberingSystem: Locale.NumberingSystem {
        if let n = _id.keywords["numbers"] { return Locale.NumberingSystem(n) }
        var buf = [CChar](repeating: 0, count: 64)
        let icu = isim_icu_number_format(identifier, 1 /* decimal */, nil, 0, &buf, Int32(buf.count)) > 0 ? String(cString: buf) : nil
        let f = NumberFormatter()
        f.locale = self
        guard let zero = (icu ?? f.string(from: 0))?.unicodeScalars.first?.value else { return .latn }
        switch zero {
        case 0x660: return "arab"
        case 0x6F0: return "arabext"
        case 0x966: return "deva"
        case 0x9E6: return "beng"
        case 0x1040: return "mymr"
        case 0xE50: return "thai"
        default: return .latn
        }
    }
    public var availableNumberingSystems: [Locale.NumberingSystem] {
        let own = Locale(identifier: Locale.Components(identifier: identifier).languageComponents._identifier).numberingSystem
        return own == .latn ? [.latn] : [own, .latn]
    }
    public var subdivision: Locale.Subdivision? { _id.keywords["sd"].map { Locale.Subdivision($0) } }
    public var variant: Locale.Variant? { _id.variant.map { Locale.Variant($0) } }
    /// the "timezone" keyword's zone
    public var timeZone: TimeZone? { _id.keywords["timezone"].flatMap(TimeZone.init(identifier:)) }

    public static var availableIdentifiers: [String] { NSLocale.availableLocaleIdentifiers }
    public static var isoRegionCodes: [String] { NSLocale.isoCountryCodes }
    public static var isoCurrencyCodes: [String] { NSLocale.isoCurrencyCodes }
    public static var commonISOCurrencyCodes: [String] { NSLocale.commonISOCurrencyCodes }
}

/// The parts of an ICU ("en_Latn_US_POSIX@calendar=buddhist;hours=h23") or BCP 47 ("en-Latn-US-u-ca-buddhist-hc-h23")
/// locale identifier; BCP 47 extension keys become their ICU names.
struct _LocaleID {
    var language: String?, script: String?, region: String?, variant: String?
    var keywords: [String: String] = [:]
    static let bcp47Keys = ["ca": "calendar", "co": "collation", "cu": "currency", "nu": "numbers", "hc": "hours",
                            "ms": "measure", "tz": "timezone", "fw": "fw", "rg": "rg", "sd": "sd"]
    static let bcp47Values = ["imperial": "uksystem", "ussystem": "ussystem", "metric": "metric", "gregory": "gregorian"]
    init(_ identifier: String) {
        var base = identifier
        if let at = identifier.firstIndex(of: "@") {
            base = String(identifier[..<at])
            for kv in identifier[identifier.index(after: at)...].split(separator: ";") {
                let p = kv.split(separator: "=", maxSplits: 1).map(String.init)
                if p.count == 2 { keywords[_LocaleID.bcp47Keys[p[0].lowercased()] ?? p[0].lowercased()] = p[1] }
            }
        }
        var parts = base.split(whereSeparator: { $0 == "_" || $0 == "-" }).map(String.init)
        if let u = parts.firstIndex(where: { $0.lowercased() == "u" }) {
            var i = u + 1
            while i < parts.count {
                let key = parts[i].lowercased()
                var values: [String] = []
                i += 1
                while i < parts.count, parts[i].count > 2 { values.append(parts[i]); i += 1 }
                let v = values.joined(separator: "-")
                keywords[_LocaleID.bcp47Keys[key] ?? key] = _LocaleID.bcp47Values[v] ?? v
            }
            parts.removeSubrange(u...)
        }
        if let first = parts.first, !first.isEmpty, first.allSatisfy(\.isLetter), first.count <= 3 { language = first.lowercased(); parts.removeFirst() }
        else if base.hasPrefix("_") { parts = base.split(separator: "_", omittingEmptySubsequences: false).dropFirst().map(String.init) }
        if let s = parts.first, s.count == 4, s.allSatisfy(\.isLetter) { script = s.prefix(1).uppercased() + s.dropFirst().lowercased(); parts.removeFirst() }
        if let r = parts.first, (r.count == 2 && r.allSatisfy(\.isLetter)) || (r.count == 3 && r.allSatisfy(\.isNumber)) {
            region = r.uppercased(); parts.removeFirst()
        } else if let r = parts.first, r.isEmpty { parts.removeFirst() }
        let rest = parts.filter { !$0.isEmpty }
        if !rest.isEmpty { variant = rest.joined(separator: "_").uppercased() }
    }
}

/// a list of codes from the host's ICU (isim_icu_codes), nil without ICU
func _isimCodes(_ kind: Int32, _ locale: String?) -> [String]? {
    var buf = [CChar](repeating: 0, count: 1 << 16)
    let n = isim_icu_codes(kind, locale, &buf, Int32(buf.count))
    guard n > 0 else { return nil }
    return String(cString: buf).split(separator: "\n").map(String.init)
}
