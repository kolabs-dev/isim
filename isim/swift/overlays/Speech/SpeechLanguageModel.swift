// isim Speech: custom language models (SFCustomLanguageModelData, SFSpeechLanguageModel and its configuration) and
// SFSpeechError (issue #377).
// Adapted: Apple trains a model from the exported data on the device. isim's export is JSON: the phrases with their
// counts (templates expanded) and the custom pronunciations. prepareCustomLanguageModel writes the model: the phrases
// by weight and the terms, one per line. Recognition with the model (SFSpeechRecognitionRequest.customizedLanguageModel,
// DictationTranscriber's customizedLanguage hint) puts its leading phrases in whisper.cpp's prompt, which biases
// recognition toward them. Vosk ignores the prompt. Phonemes are not used.
import Foundation

// MARK: - errors

public struct SFSpeechError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, Hashable, Sendable {
        case internalServiceError = 1, audioReadFailed = 2, undefinedTemplateClassName = 7, malformedSupplementalModel = 8
        case timeout = 12, missingParameter = 13
        // iOS 26 (SpeechAnalyzer); isim's raw values
        case audioDisordered = 14, unexpectedAudioFormat = 15, noModel = 16, incompatibleAudioFormats = 17
        case assetLocaleNotAllocated = 18, tooManyAssetLocalesAllocated = 19, cannotAllocateUnsupportedLocale = 20
        case insufficientResources = 21, moduleOutputFailed = 22
        // iOS 27
        case cannotConfigureAudioSystem = 23
    }
    public static var errorDomain: String { SFSpeechErrorDomain }
    public let code: Code
    let _message: String?
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; _message = userInfo[NSLocalizedDescriptionKey] as? String }
    init(_ code: Code, _ message: String) { self.code = code; _message = message }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { _message.map { [NSLocalizedDescriptionKey: $0] } ?? [:] }
    public var localizedDescription: String { _message ?? "The operation couldn’t be completed. (\(SFSpeechErrorDomain) error \(code.rawValue).)" }
    public static func == (a: SFSpeechError, b: SFSpeechError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
    public static var internalServiceError: Code { .internalServiceError }
    public static var audioReadFailed: Code { .audioReadFailed }
    public static var undefinedTemplateClassName: Code { .undefinedTemplateClassName }
    public static var malformedSupplementalModel: Code { .malformedSupplementalModel }
    public static var timeout: Code { .timeout }
    public static var missingParameter: Code { .missingParameter }
    public static var audioDisordered: Code { .audioDisordered }
    public static var unexpectedAudioFormat: Code { .unexpectedAudioFormat }
    public static var noModel: Code { .noModel }
    public static var incompatibleAudioFormats: Code { .incompatibleAudioFormats }
    public static var assetLocaleNotAllocated: Code { .assetLocaleNotAllocated }
    public static var tooManyAssetLocalesAllocated: Code { .tooManyAssetLocalesAllocated }
    public static var cannotAllocateUnsupportedLocale: Code { .cannotAllocateUnsupportedLocale }
    public static var insufficientResources: Code { .insufficientResources }
    public static var moduleOutputFailed: Code { .moduleOutputFailed }
    public static var cannotConfigureAudioSystem: Code { .cannotConfigureAudioSystem }
}

/// `catch SFSpeechError.noModel`
public func ~= (code: SFSpeechError.Code, error: any Error) -> Bool {
    if let e = error as? SFSpeechError { return e.code == code }
    let n = error as NSError
    return n.domain == SFSpeechErrorDomain && n.code == code.rawValue
}

// MARK: - training data

public protocol DataInsertable {
    func insert(data: SFCustomLanguageModelData)
}
public protocol TemplateInsertable {
    func insert(generator: SFCustomLanguageModelData.TemplatePhraseCountGenerator)
}

public class SFCustomLanguageModelData: Hashable, Codable, @unchecked Sendable {
    public let locale: Locale
    public let identifier: String
    public let version: String
    var _phrases: [PhraseCount] = []
    var _generators: [PhraseCountGenerator] = []
    var _terms: [CustomPronunciation] = []

    public init(locale: Locale, identifier: String, version: String) { self.locale = locale; self.identifier = identifier; self.version = version }
    public convenience init(locale: Locale, identifier: String, version: String, @DataInsertableBuilder builder: () -> any DataInsertable) {
        self.init(locale: locale, identifier: identifier, version: version)
        builder().insert(data: self)
    }
    public func insert(phraseCount: PhraseCount) { _phrases.append(phraseCount) }
    public func insert(phraseCountGenerator: PhraseCountGenerator) { _generators.append(phraseCountGenerator) }
    public func insert(term: CustomPronunciation) { _terms.append(term) }
    /// isim: the X-SAMPA-style phonemes Apple lists for English (pronunciations are kept but not used for recognition)
    public static func supportedPhonemes(locale: Locale) -> [String] {
        ["@", "{", "A", "E", "I", "O", "U", "V", "aI", "aU", "eI", "i", "oU", "OI", "u", "3`", "@`", "b", "d", "dZ", "D", "f", "g", "h",
         "j", "k", "l", "m", "n", "N", "p", "r\\", "s", "S", "t", "tS", "T", "v", "w", "z", "Z"]
    }
    /// writes the training data (isim: JSON with the phrases, templates expanded, and the pronunciations)
    public func export(to path: URL) async throws {
        var phrases = _phrases
        for g in _generators { for try await p in g { phrases.append(p) } }
        let doc = _Export(locale: locale.identifier, identifier: identifier, version: version, phrases: phrases, pronunciations: _terms)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(doc).write(to: path)
    }
    struct _Export: Codable {
        var locale: String, identifier: String, version: String
        var phrases: [PhraseCount], pronunciations: [CustomPronunciation]
    }

    public static func == (a: SFCustomLanguageModelData, b: SFCustomLanguageModelData) -> Bool {
        a.locale == b.locale && a.identifier == b.identifier && a.version == b.version && a._phrases == b._phrases && a._terms == b._terms
            && a._generators == b._generators
    }
    public func hash(into h: inout Hasher) { h.combine(identifier); h.combine(version); h.combine(_phrases) }
    enum CodingKeys: String, CodingKey { case locale, identifier, version, phrases, generators, terms }
    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        locale = Locale(identifier: try c.decode(String.self, forKey: .locale))
        identifier = try c.decode(String.self, forKey: .identifier); version = try c.decode(String.self, forKey: .version)
        _phrases = try c.decodeIfPresent([PhraseCount].self, forKey: .phrases) ?? []
        _generators = try c.decodeIfPresent([TemplatePhraseCountGenerator].self, forKey: .generators) ?? []
        _terms = try c.decodeIfPresent([CustomPronunciation].self, forKey: .terms) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(locale.identifier, forKey: .locale); try c.encode(identifier, forKey: .identifier); try c.encode(version, forKey: .version)
        try c.encode(_phrases, forKey: .phrases); try c.encode(_generators.compactMap { $0 as? TemplatePhraseCountGenerator }, forKey: .generators)
        try c.encode(_terms, forKey: .terms)
    }

    public struct PhraseCount: Hashable, Codable, Sendable, DataInsertable {
        public let phrase: String
        public let count: Int
        public init(phrase: String, count: Int) { self.phrase = phrase; self.count = count }
        public func insert(data: SFCustomLanguageModelData) { data.insert(phraseCount: self) }
    }
    public struct CustomPronunciation: Hashable, Codable, Sendable, DataInsertable {
        public let grapheme: String
        public let phonemes: [String]
        public init(grapheme: String, phonemes: [String]) { self.grapheme = grapheme; self.phonemes = phonemes }
        public func insert(data: SFCustomLanguageModelData) { data.insert(term: self) }
    }

    /// phrases with counts, produced asynchronously
    public class PhraseCountGenerator: AsyncSequence, Hashable, Codable, @unchecked Sendable {
        public typealias Element = PhraseCount
        public class Iterator: AsyncIteratorProtocol {
            public typealias Element = PhraseCount
            init() {}
            public func next() async throws -> PhraseCount? { nil }
        }
        public init() {}
        public func makeAsyncIterator() -> Iterator { _iterator() }
        func _iterator() -> Iterator { Iterator() }
        var _key: [String] { [] }
        public static func == (a: PhraseCountGenerator, b: PhraseCountGenerator) -> Bool { a === b || (type(of: a) == type(of: b) && a._key == b._key) }
        public func hash(into h: inout Hasher) { h.combine(_key) }
        public required init(from decoder: Decoder) throws {}
        public func encode(to encoder: Encoder) throws {}
    }

    /// templates whose `<class>` placeholders expand to every combination of the classes' values
    public class TemplatePhraseCountGenerator: PhraseCountGenerator, @unchecked Sendable {
        public struct Template: Hashable, Codable, Sendable, TemplateInsertable {
            public let body: String
            public let count: Int
            public init(_ body: String, count: Int) { self.body = body; self.count = count }
            public func insert(generator: TemplatePhraseCountGenerator) { generator.insert(template: body, count: count) }
        }
        var _templates: [Template] = []
        var _classes: [String: [String]] = [:]
        public override init() { super.init() }
        public func define(className: String, values: [String]) { _classes[className] = values }
        public func insert(template: String, count: Int) { _templates.append(Template(template, count: count)) }
        public override func makeAsyncIterator() -> PhraseCountGenerator.Iterator { Iterator(templates: _templates, templateClasses: _classes) }
        override var _key: [String] { _templates.map { "\($0.body)#\($0.count)" } + _classes.keys.sorted().map { "\($0)=\(_classes[$0]!)" } }
        enum CodingKeys: String, CodingKey { case templates, classes }
        public required init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            _templates = try c.decode([Template].self, forKey: .templates); _classes = try c.decode([String: [String]].self, forKey: .classes)
            super.init()
        }
        public override func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(_templates, forKey: .templates); try c.encode(_classes, forKey: .classes)
        }

        public class Iterator: PhraseCountGenerator.Iterator {
            var pending: [PhraseCount]?
            let templates: [Template], classes: [String: [String]]
            public init(templates: [Template], templateClasses: [String: [String]]) { self.templates = templates; classes = templateClasses }
            public override func next() async throws -> PhraseCount? {
                if pending == nil { pending = try expand().reversed() }
                return pending?.popLast()
            }
            func expand() throws -> [PhraseCount] {
                var out: [PhraseCount] = []
                for t in templates {
                    var texts = [""]
                    var rest = Substring(t.body)
                    while let open = rest.firstIndex(of: "<"), let close = rest[open...].firstIndex(of: ">") {
                        let lit = String(rest[..<open]), name = String(rest[rest.index(after: open)..<close])
                        guard let values = classes[name] else {
                            throw SFSpeechError(.undefinedTemplateClassName, "the template “\(t.body)” uses the undefined class <\(name)>")
                        }
                        texts = texts.flatMap { pre in values.map { pre + lit + $0 } }
                        rest = rest[rest.index(after: close)...]
                    }
                    out += texts.map { PhraseCount(phrase: $0 + rest, count: t.count) }
                }
                return out
            }
        }
    }

    /// templates (or compound templates) with the classes their placeholders use
    public struct PhraseCountsFromTemplates: DataInsertable {
        let classes: [String: [String]]
        let content: any TemplateInsertable
        public init(classes: [String: [String]], @TemplateInsertableBuilder builder: () -> any TemplateInsertable) {
            self.classes = classes; content = builder()
        }
        public func insert(data: SFCustomLanguageModelData) {
            let g = TemplatePhraseCountGenerator()
            for (k, v) in classes { g.define(className: k, values: v) }
            content.insert(generator: g)
            data.insert(phraseCountGenerator: g)
        }
    }
    public struct CompoundTemplate: TemplateInsertable {
        let components: [any TemplateInsertable]
        public init(_ components: [any TemplateInsertable]) { self.components = components }
        public func insert(generator: TemplatePhraseCountGenerator) { for c in components { c.insert(generator: generator) } }
    }

    struct _DataList: DataInsertable {
        let items: [any DataInsertable]
        func insert(data: SFCustomLanguageModelData) { for i in items { i.insert(data: data) } }
    }
    struct _TemplateList: TemplateInsertable {
        let items: [any TemplateInsertable]
        func insert(generator: TemplatePhraseCountGenerator) { for i in items { i.insert(generator: generator) } }
    }
    @resultBuilder public struct DataInsertableBuilder {
        public static func buildBlock(_ components: any DataInsertable...) -> any DataInsertable { _DataList(items: components) }
        public static func buildArray(_ components: [any DataInsertable]) -> any DataInsertable { _DataList(items: components) }
        public static func buildEither(first component: any DataInsertable) -> any DataInsertable { component }
        public static func buildEither(second component: any DataInsertable) -> any DataInsertable { component }
        public static func buildOptional(_ component: (any DataInsertable)?) -> any DataInsertable { _DataList(items: component.map { [$0] } ?? []) }
    }
    @resultBuilder public struct TemplateInsertableBuilder {
        public static func buildBlock(_ components: any TemplateInsertable...) -> any TemplateInsertable { _TemplateList(items: components) }
        public static func buildArray(_ components: [any TemplateInsertable]) -> any TemplateInsertable { _TemplateList(items: components) }
        public static func buildEither(first component: any TemplateInsertable) -> any TemplateInsertable { component }
        public static func buildEither(second component: any TemplateInsertable) -> any TemplateInsertable { component }
        public static func buildOptional(_ component: (any TemplateInsertable)?) -> any TemplateInsertable { _TemplateList(items: component.map { [$0] } ?? []) }
    }
}

// MARK: - prepared models

open class SFSpeechLanguageModel: NSObject, @unchecked Sendable {
    @objc(SFSpeechLanguageModelConfiguration)
    public class Configuration: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
        public let languageModel: URL
        public let vocabulary: URL?
        let _weight: NSNumber?
        @available(iOS 26.0, *)
        public var weight: NSNumber? { _weight }
        public convenience init(languageModel: URL) { self.init(languageModel: languageModel, vocabulary: nil, _weight: nil) }
        public convenience init(languageModel: URL, vocabulary: URL?) { self.init(languageModel: languageModel, vocabulary: vocabulary, _weight: nil) }
        @available(iOS 26.0, *)
        public convenience init(languageModel: URL, vocabulary: URL?, weight: NSNumber?) { self.init(languageModel: languageModel, vocabulary: vocabulary, _weight: weight) }
        init(languageModel: URL, vocabulary: URL?, _weight: NSNumber?) { self.languageModel = languageModel; self.vocabulary = vocabulary; self._weight = _weight }
        public func copy(with zone: NSZone? = nil) -> Any { self }
        public static var supportsSecureCoding: Bool { true }
        public func encode(with coder: NSCoder) {
            coder.encode(languageModel as NSURL, forKey: "languageModel")
            if let vocabulary { coder.encode(vocabulary as NSURL, forKey: "vocabulary") }
            if let _weight { coder.encode(_weight, forKey: "weight") }
        }
        public required init?(coder: NSCoder) {
            guard let lm = coder.decodeObject(of: NSURL.self, forKey: "languageModel") else { return nil }
            languageModel = lm as URL
            vocabulary = coder.decodeObject(of: NSURL.self, forKey: "vocabulary") as URL?
            _weight = coder.decodeObject(of: NSNumber.self, forKey: "weight")
        }
        public override func isEqual(_ object: Any?) -> Bool {
            guard let o = object as? Configuration else { return false }
            return o.languageModel == languageModel && o.vocabulary == vocabulary && o._weight == _weight
        }
        public override var hash: Int { languageModel.hashValue }
    }

    open class func prepareCustomLanguageModel(for asset: URL, configuration: Configuration, completion: @escaping @Sendable (Error?) -> Void) {
        prepareCustomLanguageModel(for: asset, configuration: configuration, ignoresCache: false, completion: completion)
    }
    open class func prepareCustomLanguageModel(for asset: URL, configuration: Configuration, ignoresCache: Bool, completion: @escaping @Sendable (Error?) -> Void) {
        DispatchQueue.global().async { completion(_prepare(asset, configuration, ignoresCache: ignoresCache)) }
    }
    open class func prepareCustomLanguageModel(for asset: URL, configuration: Configuration) async throws {
        try await prepareCustomLanguageModel(for: asset, configuration: configuration, ignoresCache: false)
    }
    open class func prepareCustomLanguageModel(for asset: URL, configuration: Configuration, ignoresCache: Bool) async throws {
        if let e = await Task.detached(operation: { _prepare(asset, configuration, ignoresCache: ignoresCache) }).value { throw e }
    }
    @available(iOS, introduced: 17.0, deprecated: 26.0)
    open class func prepareCustomLanguageModel(for asset: URL, clientIdentifier: String, configuration: Configuration, completion: @escaping @Sendable (Error?) -> Void) {
        prepareCustomLanguageModel(for: asset, configuration: configuration, ignoresCache: false, completion: completion)
    }
    @available(iOS, introduced: 17.0, deprecated: 26.0)
    open class func prepareCustomLanguageModel(for asset: URL, clientIdentifier: String, configuration: Configuration, ignoresCache: Bool, completion: @escaping @Sendable (Error?) -> Void) {
        prepareCustomLanguageModel(for: asset, configuration: configuration, ignoresCache: ignoresCache, completion: completion)
    }

    /// reads exported training data and writes the model (phrases by weight) and the vocabulary (terms)
    static func _prepare(_ asset: URL, _ config: Configuration, ignoresCache: Bool) -> Error? {
        let fm = FileManager.default
        if !ignoresCache, fm.fileExists(atPath: config.languageModel.path),
           let a = try? fm.attributesOfItem(atPath: asset.path)[.modificationDate] as? Date,
           let m = try? fm.attributesOfItem(atPath: config.languageModel.path)[.modificationDate] as? Date, m >= a { return nil }
        guard let data = try? Data(contentsOf: asset) else {
            return SFSpeechError(.missingParameter, "isim could not read the custom language model data at \(asset.path)")
        }
        guard let doc = try? JSONDecoder().decode(SFCustomLanguageModelData._Export.self, from: data) else {
            return SFSpeechError(.malformedSupplementalModel, "\(asset.lastPathComponent) is not language model data exported by SFCustomLanguageModelData")
        }
        var weights: [String: Int] = [:]
        for p in doc.phrases { weights[p.phrase, default: 0] += p.count }
        let phrases = weights.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
        do {
            try (phrases.joined(separator: "\n") + "\n").write(to: config.languageModel, atomically: true, encoding: .utf8)
            if let v = config.vocabulary {
                try (doc.pronunciations.map(\.grapheme).joined(separator: "\n") + "\n").write(to: v, atomically: true, encoding: .utf8)
            }
        } catch { return SFSpeechError(.internalServiceError, "isim could not write the language model: \(error.localizedDescription)") }
        return nil
    }
    /// the vocabulary's terms, then the most frequent phrases (what fits whisper.cpp's prompt)
    static func _promptPhrases(_ config: Configuration) -> [String] {
        func lines(_ u: URL?) -> [String] {
            guard let u, let s = try? String(contentsOf: u, encoding: .utf8) else { return [] }
            return s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        var out: [String] = [], len = 0
        for p in lines(config.vocabulary) + lines(config.languageModel) where !out.contains(p) {
            len += p.count + 2
            if len > 600 { break }
            out.append(p)
        }
        return out
    }
}
