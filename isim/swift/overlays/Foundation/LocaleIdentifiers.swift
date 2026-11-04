// isim Foundation: Locale's identifier conversions (ICU, BCP 47, CLDR, Windows LCIDs), quotation delimiters, exemplar
// characters, collation / variant names, ISO language codes, the region hierarchy (UN M49 containment and categories),
// the numbering systems and Locale.Language's parents (issue #846). Passthrough to the host's ICU (isim_icu_locale,
// isim_icu_codes, isim_icu_display_name: host_icu.c); without ICU, adapted fallbacks (identifiers rewritten by rule,
// ASCII quotation marks, no region hierarchy).
import isim_host

/// one locale fact from the host's ICU (host_icu.c, isim_icu_locale's kinds), nil without ICU
func _isimICULocale(_ kind: Int32, _ arg: String) -> String? {
    var buf = [CChar](repeating: 0, count: 1 << 16)
    let n = isim_icu_locale(kind, arg, &buf, Int32(buf.count))
    return n >= 0 ? String(cString: buf) : nil
}
/// a list of codes from the host's ICU (isim_icu_codes' kinds), nil without ICU
func _isimICUCodes(_ kind: Int32, _ arg: String?) -> [String]? {
    var buf = [CChar](repeating: 0, count: 1 << 16)
    let n = isim_icu_codes(kind, arg, &buf, Int32(buf.count))
    guard n > 0 else { return n == 0 ? [] : nil }
    return String(cString: buf).split(separator: "\n").map(String.init)
}
func _isimICUDisplay(_ displayLocale: String, _ code: String, _ kind: Int32) -> String? {
    var buf = [CChar](repeating: 0, count: 1024)
    let n = isim_icu_display_name(displayLocale, code, kind, &buf, Int32(buf.count))
    return n > 0 ? String(cString: buf) : nil
}

// MARK: - identifiers

extension Locale {
    /// the kinds of locale identifier
    public enum IdentifierType: Sendable {
        /// ICU's ("en_US@calendar=japanese")
        case icu
        /// BCP 47's ("en-US-u-ca-japanese")
        case bcp47
        /// CLDR's: BCP 47 with underscores ("en_US_u_ca_japanese")
        case cldr
    }

    public func identifier(_ type: IdentifierType) -> String { Locale.identifier(type, from: identifier) }

    public static func identifier(_ type: IdentifierType, from string: String) -> String {
        let icu = _isimICULocale(1, string).flatMap { $0.isEmpty ? nil : $0 } ?? _isimICULocale(2, string) ?? string.replacingOccurrences(of: "-", with: "_")
        switch type {
        case .icu: return _isimICULocale(2, icu) ?? icu
        case .bcp47: return _isimICULocale(0, icu) ?? icu.replacingOccurrences(of: "_", with: "-")
        case .cldr: return (_isimICULocale(0, icu) ?? icu).replacingOccurrences(of: "-", with: "_")
        }
    }

    /// a language identifier in its canonical BCP 47 form ("zh_Hans" is "zh-Hans", "iw" is "he")
    public static func canonicalLanguageIdentifier(from string: String) -> String {
        let icu = _isimICULocale(2, string.replacingOccurrences(of: "-", with: "_")) ?? string
        return _isimICULocale(0, icu) ?? icu.replacingOccurrences(of: "_", with: "-")
    }

    /// "language_Script_REGION_VARIANT@key=value;...": the components' keys are kCFLocale's
    /// (kCFLocaleLanguageCodeKey "kCFLocaleLanguageCodeKey", ...) or keywords ("calendar")
    public static func identifier(fromComponents components: [String: String]) -> String {
        var id = components["kCFLocaleLanguageCodeKey"] ?? ""
        if let s = components["kCFLocaleScriptCodeKey"] { id += "_" + s }
        if let r = components["kCFLocaleCountryCodeKey"] { id += "_" + r }
        if let v = components["kCFLocaleVariantCodeKey"] { id += (components["kCFLocaleCountryCodeKey"] == nil ? "__" : "_") + v }
        let keywords = components.filter { !$0.key.hasPrefix("kCFLocale") }.sorted { $0.key < $1.key }
        if !keywords.isEmpty { id += "@" + keywords.map { "\($0.key)=\($0.value)" }.joined(separator: ";") }
        return id
    }

    /// the Windows locale code (LCID) of an identifier, nil when it has none
    public static func windowsLocaleCode(fromIdentifier identifier: String) -> Int? {
        _isimICULocale(8, identifier.replacingOccurrences(of: "-", with: "_")).flatMap { Int($0) }.flatMap { $0 == 0 ? nil : $0 }
    }
    public static func identifier(fromWindowsLocaleCode code: Int) -> String? {
        _isimICULocale(9, String(code)).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// the locales of the person's preferred languages, in order
    public static var preferredLocales: [Locale] { preferredLanguages.map { Locale(identifier: $0) } }

    // MARK: delimiters, exemplar characters, collation

    private func _delimiters() -> [String] {
        if let d = _isimICULocale(6, identifier)?.components(separatedBy: "\t"), d.count == 4 { return d }
        return ["\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}"]       // without ICU: English's
    }
    public var quotationBeginDelimiter: String? { _delimiters()[0] }
    public var quotationEndDelimiter: String? { _delimiters()[1] }
    public var alternateQuotationBeginDelimiter: String? { _delimiters()[2] }
    public var alternateQuotationEndDelimiter: String? { _delimiters()[3] }

    /// the characters the locale's language is written with (CLDR's standard exemplar set)
    public var exemplarCharacterSet: CharacterSet? {
        guard let ranges = _isimICULocale(7, identifier), !ranges.isEmpty else { return nil }
        var set = CharacterSet()
        for r in ranges.split(separator: "\n") {
            let p = r.split(separator: "-")
            guard p.count == 2, let a = UInt32(p[0], radix: 16), let b = UInt32(p[1], radix: 16),
                  let lo = Unicode.Scalar(a), let hi = Unicode.Scalar(b) else { continue }
            set.insert(charactersIn: lo...hi)
        }
        return set
    }

    /// the identifier the locale's collator uses (the locale, with its collation keyword)
    public var collatorIdentifier: String? { identifier.isEmpty ? nil : identifier }

    public func localizedString(forCollationIdentifier collationIdentifier: String) -> String? {
        _isimICUDisplay(identifier, collationIdentifier, 6)
    }
    public func localizedString(forCollatorIdentifier collatorIdentifier: String) -> String? {
        localizedString(forIdentifier: collatorIdentifier)
    }
    public func localizedString(forVariantCode variantCode: String) -> String? {
        _isimICUDisplay(identifier, variantCode.uppercased(), 7)
    }
}

// MARK: - language codes

extension Locale.LanguageCode {
    /// ISO 639-1 (two letters) or ISO 639-2 (three letters)
    public enum IdentifierType: Sendable {
        case alpha2
        case alpha3
    }
    /// the `und` code: the language has not been identified
    public static let unidentified = Locale.LanguageCode("und")
    /// the `mis` code: a language without a code
    public static let uncoded = Locale.LanguageCode("mis")
    /// the `mul` code: several languages
    public static let multiple = Locale.LanguageCode("mul")
    /// the `zxx` code: no linguistic content (images, symbols)
    public static let unavailable = Locale.LanguageCode("zxx")

    static let _iso2: [String] = _isimICUCodes(8, nil) ?? NSLocale.isoLanguageCodes_fallback
    static let _alpha3: [String: String] = {
        var m: [String: String] = [:]
        for c in _iso2 where c.count == 2 { if let a3 = _isimICULocale(10, c), !a3.isEmpty { m[c] = a3 } }
        return m
    }()

    public static var isoLanguageCodes: [Locale.LanguageCode] { _iso2.map { Locale.LanguageCode($0) } }
    public var isISOLanguage: Bool {
        let c = identifier.lowercased()
        return Locale.LanguageCode._iso2.contains(c) || Locale.LanguageCode._alpha3.values.contains(c)
    }
    public func identifier(_ type: IdentifierType) -> String? {
        let c = identifier.lowercased()
        switch type {
        case .alpha2:
            if c.count == 2 { return Locale.LanguageCode._iso2.contains(c) ? c : nil }
            return Locale.LanguageCode._alpha3.first { $0.value == c }?.key
        case .alpha3:
            if c.count == 3 { return c }
            return Locale.LanguageCode._alpha3[c]
        }
    }
}
extension NSLocale {
    /// the ISO 639-1 codes when the host has no ICU
    static let isoLanguageCodes_fallback = ["ar", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "he", "hi", "hr", "hu", "id",
                                           "it", "ja", "ko", "ms", "nb", "nl", "pl", "pt", "ro", "ru", "sk", "sv", "th", "tr", "uk",
                                           "vi", "zh"]
}

// MARK: - regions

extension Locale.Region {
    /// a region's kind in the UN M49 hierarchy
    public struct Category: Codable, Sendable, Hashable, CustomDebugStringConvertible {
        let _type: Int32                                   // ICU's URegionType
        init(_type: Int32) { self._type = _type }
        /// the world (001)
        public static let world = Category(_type: 2)
        /// a continent (002 Africa, 019 Americas, ...)
        public static let continent = Category(_type: 3)
        /// a subcontinent (015 Northern Africa, ...)
        public static let subcontinent = Category(_type: 4)
        /// a territory: a country or area with an ISO 3166 code
        public static let territory = Category(_type: 1)
        /// a grouping (EU, UN, ...)
        public static let grouping = Category(_type: 5)
        public var debugDescription: String {
            switch _type { case 2: return "world"; case 3: return "continent"; case 4: return "subcontinent"; case 1: return "territory"; default: return "grouping" }
        }
        public init(from decoder: Decoder) throws {
            switch try decoder.singleValueContainer().decode(String.self) {
            case "world": _type = 2
            case "continent": _type = 3
            case "subcontinent": _type = 4
            case "territory": _type = 1
            default: _type = 5
            }
        }
        public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(debugDescription) }
    }

    private var _info: [String]? {
        guard let s = _isimICULocale(5, identifier.uppercased()) else { return nil }
        let f = s.components(separatedBy: "\t")
        return f.count == 4 ? f : nil
    }
    private static func _region(_ code: String?) -> Locale.Region? { code.flatMap { $0.isEmpty ? nil : Locale.Region($0) } }

    /// the region's category; nil for an unknown code
    public var category: Category? {
        guard let t = _info.flatMap({ Int32($0[0]) }), (1...5).contains(t) else { return nil }
        return Category(_type: t)
    }
    /// the region directly containing it (Western Europe for France)
    public var containingRegion: Locale.Region? { Locale.Region._region(_info?[1]) }
    /// the continent containing it (Europe for France)
    public var continent: Locale.Region? { Locale.Region._region(_info?[2]) }
    /// the subcontinent containing it (Western Europe for France)
    public var subcontinent: Locale.Region? { Locale.Region._region(_info?[3]) }
    /// the regions it directly contains
    public var subRegions: [Locale.Region] { (_isimICUCodes(7, identifier.uppercased()) ?? []).map { Locale.Region($0) } }
    /// the regions of a category it contains, at any depth
    public func subRegions(ofCategory category: Category) -> [Locale.Region] {
        (_isimICUCodes(7, "\(identifier.uppercased())\t\(category._type)") ?? []).map { Locale.Region($0) }
    }
    /// every region of a category
    public static func isoRegions(ofCategory category: Category) -> [Locale.Region] {
        (_isimICUCodes(6, String(category._type)) ?? []).map { Locale.Region($0) }
    }
}

// MARK: - languages, numbering systems

extension Locale.Language {
    /// the language one level up: the identifier without its last subtag ("en-GB" is "en"); nil for a bare language
    public var parent: Locale.Language? {
        let parts = minimalIdentifier.split(separator: "-")
        return parts.count > 1 ? Locale.Language(identifier: parts.dropLast().joined(separator: "-")) : nil
    }
    private var _maximal: String {
        _isimICULocale(3, minimalIdentifier.replacingOccurrences(of: "-", with: "_")) ?? minimalIdentifier
    }
    /// whether both identify the same language once the likely script and region are filled in ("zh-TW" and "zh-Hant-TW")
    public func isEquivalent(to language: Locale.Language) -> Bool {
        _maximal.lowercased() == language._maximal.lowercased()
    }
    /// whether both descend from the same language and script ("en-US" and "en-GB")
    public func hasCommonParent(with language: Locale.Language) -> Bool {
        func base(_ l: Locale.Language) -> String { l._maximal.split(separator: "_").prefix(2).joined(separator: "_").lowercased() }
        return base(self) == base(language)
    }
    /// the languages the system is localized in (adapted: iOS's interface languages)
    public static var systemLanguages: [Locale.Language] {
        ["ar", "ca", "cs", "da", "de", "el", "en", "en-AU", "en-GB", "en-IN", "es", "es-419", "fi", "fr", "fr-CA", "he", "hi", "hr",
         "hu", "id", "it", "ja", "ko", "ms", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk", "vi",
         "zh-Hans", "zh-Hant", "zh-HK"].map { Locale.Language(identifier: $0) }
    }
}

extension Locale.NumberingSystem {
    /// the numbering systems the host's ICU knows (latn, arab, deva, ...)
    public static var availableNumberingSystems: [Locale.NumberingSystem] {
        (_isimICUCodes(5, nil) ?? ["latn"]).map { Locale.NumberingSystem($0) }
    }
}
