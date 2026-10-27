// isim Foundation: automatic grammar agreement in Swift (Morphology, TermOfAddress, InflectionRule, InflectionConcept,
// the inflect / morphology / inflectionAlternative attributes, AttributedString.inflected(), LocalizationOptions).
// Self-authored, iOS API names; the values bridge to NSMorphology / NSTermOfAddress / NSInflectionRule, and the
// agreement itself is Inflection.m's (adapted: isim's rules for English, Spanish, French, Italian and Portuguese).

/// A word's grammatical properties: gender, number, part of speech, case...
public struct Morphology: Hashable, Sendable {
    public enum GrammaticalGender: Int, CaseIterable, Hashable, Sendable { case feminine = 1, masculine, neuter }
    public enum PartOfSpeech: Int, CaseIterable, Hashable, Sendable {
        case determiner = 1, pronoun, letter, adverb, particle, adjective, adposition, verb, noun, conjunction, numeral, interjection, preposition, abbreviation
    }
    public enum GrammaticalNumber: Int, CaseIterable, Hashable, Sendable { case singular = 1, zero, plural, pluralTwo, pluralFew, pluralMany }
    public enum GrammaticalCase: Int, CaseIterable, Hashable, Sendable {
        case nominative = 1, accusative, dative, genitive, prepositional, ablative, adessive, allative, elative, illative, essive, inessive, locative, translative
    }
    public enum GrammaticalPerson: Int, CaseIterable, Hashable, Sendable { case first = 1, second, third }
    public enum PronounType: Int, CaseIterable, Hashable, Sendable { case personal = 1, reflexive, possessive }
    public enum Determination: Int, CaseIterable, Hashable, Sendable { case independent = 1, dependent }
    public enum Definiteness: Int, CaseIterable, Hashable, Sendable { case indefinite = 1, definite }

    public var grammaticalGender: GrammaticalGender?
    public var partOfSpeech: PartOfSpeech?
    public var number: GrammaticalNumber?
    public var grammaticalCase: GrammaticalCase?
    public var grammaticalPerson: GrammaticalPerson?
    public var pronounType: PronounType?
    public var determination: Determination?
    public var definiteness: Definiteness?
    public init() {}
    public var isUnspecified: Bool { self == Morphology() }
    /// the user's morphology (the gender of their term of address: ISIM_TERM_OF_ADDRESS or the AppleTermOfAddress default)
    public static let user: Morphology = Morphology(NSMorphology.user)

    /// A pronoun and the morphology it agrees with, for a custom term of address.
    public struct Pronoun: Hashable, Sendable {
        public var pronoun: String
        public var morphology: Morphology
        public var dependentMorphology: Morphology?
        public init(pronoun: String, morphology: Morphology, dependentMorphology: Morphology? = nil) {
            self.pronoun = pronoun; self.morphology = morphology; self.dependentMorphology = dependentMorphology
        }
    }

    init(_ m: NSMorphology) {
        grammaticalGender = GrammaticalGender(rawValue: m.grammaticalGender.rawValue)
        partOfSpeech = PartOfSpeech(rawValue: m.partOfSpeech.rawValue)
        number = GrammaticalNumber(rawValue: m.number.rawValue)
        grammaticalCase = GrammaticalCase(rawValue: m.grammaticalCase.rawValue)
        grammaticalPerson = GrammaticalPerson(rawValue: m.grammaticalPerson.rawValue)
        pronounType = PronounType(rawValue: m.pronounType.rawValue)
        determination = Determination(rawValue: m.determination.rawValue)
        definiteness = Definiteness(rawValue: m.definiteness.rawValue)
    }
    var _objc: NSMorphology {
        let m = NSMorphology()
        m.grammaticalGender = NSGrammaticalGender(rawValue: grammaticalGender?.rawValue ?? 0) ?? .notSet
        m.partOfSpeech = NSGrammaticalPartOfSpeech(rawValue: partOfSpeech?.rawValue ?? 0) ?? .notSet
        m.number = NSGrammaticalNumber(rawValue: number?.rawValue ?? 0) ?? .notSet
        m.grammaticalCase = NSGrammaticalCase(rawValue: grammaticalCase?.rawValue ?? 0) ?? .notSet
        m.grammaticalPerson = NSGrammaticalPerson(rawValue: grammaticalPerson?.rawValue ?? 0) ?? .notSet
        m.pronounType = NSGrammaticalPronounType(rawValue: pronounType?.rawValue ?? 0) ?? .notSet
        m.determination = NSGrammaticalDetermination(rawValue: determination?.rawValue ?? 0) ?? .notSet
        m.definiteness = NSGrammaticalDefiniteness(rawValue: definiteness?.rawValue ?? 0) ?? .notSet
        return m
    }
}
extension Morphology: Codable {
    /// Markdown's `morphology: { number: "plural", grammaticalGender: "feminine", partOfSpeech: "noun" }`
    enum CodingKeys: String, CodingKey { case grammaticalGender, partOfSpeech, number, grammaticalCase, grammaticalPerson, pronounType, determination, definiteness }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func named<E: CaseIterable & RawRepresentable>(_ k: CodingKeys, _: E.Type) throws -> E? {
            guard let s = try c.decodeIfPresent(String.self, forKey: k) else { return nil }
            return E.allCases.first { "\($0)" == s }
        }
        grammaticalGender = try named(.grammaticalGender, GrammaticalGender.self)
        partOfSpeech = try named(.partOfSpeech, PartOfSpeech.self)
        number = try named(.number, GrammaticalNumber.self)
        grammaticalCase = try named(.grammaticalCase, GrammaticalCase.self)
        grammaticalPerson = try named(.grammaticalPerson, GrammaticalPerson.self)
        pronounType = try named(.pronounType, PronounType.self)
        determination = try named(.determination, Determination.self)
        definiteness = try named(.definiteness, Definiteness.self)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(grammaticalGender.map { "\($0)" }, forKey: .grammaticalGender)
        try c.encodeIfPresent(partOfSpeech.map { "\($0)" }, forKey: .partOfSpeech)
        try c.encodeIfPresent(number.map { "\($0)" }, forKey: .number)
        try c.encodeIfPresent(grammaticalCase.map { "\($0)" }, forKey: .grammaticalCase)
        try c.encodeIfPresent(grammaticalPerson.map { "\($0)" }, forKey: .grammaticalPerson)
        try c.encodeIfPresent(pronounType.map { "\($0)" }, forKey: .pronounType)
        try c.encodeIfPresent(determination.map { "\($0)" }, forKey: .determination)
        try c.encodeIfPresent(definiteness.map { "\($0)" }, forKey: .definiteness)
    }
}
extension Morphology.Pronoun: Codable {}

/// How a person is addressed, which words that refer to them agree with.
public struct TermOfAddress: Hashable, Codable, Sendable {
    var _gender: Int
    public private(set) var language: Locale.Language?
    public private(set) var pronouns: [Morphology.Pronoun]
    enum CodingKeys: String, CodingKey { case _gender = "gender", _language = "language", pronouns }
    var _language: String? { language?.minimalIdentifier }
    init(gender: Int, language: Locale.Language? = nil, pronouns: [Morphology.Pronoun] = []) {
        _gender = gender; self.language = language; self.pronouns = pronouns
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _gender = try c.decodeIfPresent(Int.self, forKey: ._gender) ?? 0
        language = try c.decodeIfPresent(String.self, forKey: ._language).map { Locale.Language(identifier: $0) }
        pronouns = try c.decodeIfPresent([Morphology.Pronoun].self, forKey: .pronouns) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(_gender, forKey: ._gender)
        try c.encodeIfPresent(_language, forKey: ._language)
        try c.encode(pronouns, forKey: .pronouns)
    }
    public static let neutral = TermOfAddress(gender: Morphology.GrammaticalGender.neuter.rawValue)
    public static let feminine = TermOfAddress(gender: Morphology.GrammaticalGender.feminine.rawValue)
    public static let masculine = TermOfAddress(gender: Morphology.GrammaticalGender.masculine.rawValue)
    /// the user's (ISIM_TERM_OF_ADDRESS or the AppleTermOfAddress default)
    public static var currentUser: TermOfAddress { TermOfAddress(gender: NSTermOfAddress.currentUser._isimGender) }
    public static func localized(language: Locale.Language, pronouns: [Morphology.Pronoun]) -> TermOfAddress {
        TermOfAddress(gender: pronouns.compactMap { $0.morphology.grammaticalGender?.rawValue }.first ?? 0, language: language, pronouns: pronouns)
    }
}

/// How a run of text inflects: to agree automatically, or to an explicit morphology.
public enum InflectionRule: Hashable, Sendable {
    case automatic
    case explicit(Morphology)
    public init(morphology: Morphology) { self = .explicit(morphology) }
    /// whether isim inflects text in `language` (English, Spanish, French, Italian, Portuguese)
    public static func canInflect(language: String) -> Bool { NSInflectionRule.canInflectLanguage(language) }
    public static var canInflectPreferredLocalization: Bool { NSInflectionRule.canInflectPreferredLocalization }
    var _objc: NSInflectionRule {
        switch self {
        case .automatic: return NSInflectionRule.automatic
        case .explicit(let m): return NSInflectionRuleExplicit(morphology: m._objc)
        }
    }
    init(_ r: NSInflectionRule) {
        if let e = r as? NSInflectionRuleExplicit { self = .explicit(Morphology(e.morphology)) } else { self = .automatic }
    }
}
extension InflectionRule: Codable {
    /// Markdown's `inflect: true`, or a morphology to inflect to (`inflect: { number: "plural" }`)
    public init(from decoder: Decoder) throws {
        if let b = try? decoder.singleValueContainer().decode(Bool.self) {
            guard b else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "inflect: false")) }
            self = .automatic
        } else {
            self = .explicit(try Morphology(from: decoder))
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .automatic: var c = encoder.singleValueContainer(); try c.encode(true)
        case .explicit(let m): try m.encode(to: encoder)
        }
    }
}

/// What a localized string's agreement refers to.
public enum InflectionConcept: Hashable, Sendable {
    case termsOfAddress([TermOfAddress])
    case localizedPhrase(String)
}

extension AttributeScopes.FoundationAttributes {
    /// `^[text](inflect: true)`: the run agrees (AttributedString.inflected())
    public enum InflectionRuleAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
        public typealias Value = InflectionRule
        public typealias ObjectiveCValue = NSInflectionRule
        public static let name = "NSInflect"
        public static let markdownName = "inflect"
        public static func objectiveCValue(for value: InflectionRule) throws -> NSInflectionRule { value._objc }
        public static func value(for object: NSInflectionRule) throws -> InflectionRule { InflectionRule(object) }
    }
    /// `^[text](morphology: {...})`: the run's grammatical properties
    public enum MorphologyAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
        public typealias Value = Morphology
        public typealias ObjectiveCValue = NSMorphology
        public static let name = "NSMorphology"
        public static let markdownName = "morphology"
        public static func objectiveCValue(for value: Morphology) throws -> NSMorphology { value._objc }
        public static func value(for object: NSMorphology) throws -> Morphology { Morphology(object) }
    }
    /// the text to show instead when the run cannot be inflected
    public enum InflectionAlternativeAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = AttributedString
        public static let name = "NSInflectionAlternative"
        public static let markdownName = "inflectionAlternative"
        public static func decodeMarkdown(from decoder: Decoder) throws -> AttributedString {
            AttributedString(try decoder.singleValueContainer().decode(String.self))
        }
    }
}

extension AttributedString {
    /// Options of AttributedString(localized:options:): whether to inflect, and the concepts agreement refers to.
    public struct LocalizationOptions: Sendable {
        public var inflect: Bool = true
        public var concepts: [InflectionConcept]?
        public var applyReplacementIndexAttribute: Bool = false
        nonisolated(unsafe) public var replacements: [any CVarArg]?
        public init() {}
        public static func termsOfAddressConcept(_ terms: [TermOfAddress]) -> LocalizationOptions {
            var o = LocalizationOptions(); o.concepts = [.termsOfAddress(terms)]; return o
        }
        public static func localizedPhraseConcept(_ phrase: String) -> LocalizationOptions {
            var o = LocalizationOptions(); o.concepts = [.localizedPhrase(phrase)]; return o
        }
    }

    public init(localized key: String.LocalizationValue, options: LocalizationOptions, table: String? = nil, bundle: Bundle? = nil,
                locale: Locale? = nil, comment: StaticString? = nil) {
        let s = String(localized: key, table: table, bundle: bundle, locale: locale ?? .current, comment: comment)
        self = AttributedString._localized(s, options: options, locale: locale ?? .current)
    }
    public init(localized resource: LocalizedStringResource, options: LocalizationOptions) {
        self = AttributedString._localized(String(localized: resource), options: options, locale: resource.locale)
    }
    static func _localized(_ s: String, options: LocalizationOptions, locale: Locale) -> AttributedString {
        let a = (try? AttributedString(markdown: s, options: .init(allowsExtendedAttributes: true, interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
        guard options.inflect else { return a }
        var user: TermOfAddress? = nil
        for case .termsOfAddress(let terms) in options.concepts ?? [] { user = terms.first }
        return a.inflected(locale: locale, userTermOfAddress: user ?? .currentUser, inflectionConcepts: options.concepts ?? [])
    }

    /// The runs marked to inflect, made to agree in the app's preferred localization with the user's term of address.
    public func inflected() -> AttributedString {
        let pref = Bundle.main.preferredLocalizations.first
        let lang = pref.map { InflectionRule.canInflect(language: $0) } == true ? pref! : Locale.current.identifier
        return inflected(locale: Locale(identifier: lang), userTermOfAddress: .currentUser, inflectionConcepts: [])
    }
    /// The runs marked to inflect, made to agree: in number with the numeral each holds (or its morphology), in gender
    /// with its morphology or `userTermOfAddress`.
    public func inflected(locale: Locale, userTermOfAddress: TermOfAddress?, inflectionConcepts: [InflectionConcept]) -> AttributedString {
        let lang = locale.language.languageCode?.identifier ?? "en"
        var userGender = userTermOfAddress?._gender ?? 0
        if userGender == Morphology.GrammaticalGender.neuter.rawValue { userGender = 0 }
        var out = self
        typealias Rule = AttributeScopes.FoundationAttributes.InflectionRuleAttribute
        typealias Morph = AttributeScopes.FoundationAttributes.MorphologyAttribute
        let marked = runs.compactMap { run -> (Range<AttributedString.Index>, InflectionRule, Morphology?)? in
            guard let rule = run.attributes[Rule.self] else { return nil }
            return (run.range, rule, run.attributes[Morph.self])
        }
        // runs split by other attributes are joined back into the phrase they mark
        var phrases: [(Range<AttributedString.Index>, InflectionRule, Morphology?)] = []
        for m in marked {
            if let last = phrases.last, last.0.upperBound == m.0.lowerBound, last.1 == m.1 { phrases[phrases.count - 1].0 = last.0.lowerBound..<m.0.upperBound }
            else { phrases.append(m) }
        }
        for (range, rule, morph) in phrases.reversed() {
            var m = morph ?? Morphology()
            if case .explicit(let e) = rule { m = e }
            let text = String(out[range].characters)
            let gender = m.grammaticalGender?.rawValue ?? userGender
            let inflected = NSMorphology._isim_inflectString(text, language: lang, number: m.number?.rawValue ?? 0, gender: gender,
                                                             partOfSpeech: m.partOfSpeech?.rawValue ?? 0)
            var attrs = out[range].runs.first?.attributes ?? AttributeContainer()
            attrs[Rule.self] = nil
            attrs[Morph.self] = nil
            out.replaceSubrange(range, with: AttributedString(inflected, attributes: attrs))
        }
        return out
    }
}
