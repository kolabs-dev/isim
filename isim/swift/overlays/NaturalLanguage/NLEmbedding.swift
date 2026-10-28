// isim NaturalLanguage (issue #378): gazetteers, word and sentence embeddings, contextual embeddings, NLModel.
// - NLGazetteer: label lookup (case- and diacritic-insensitive), with phrases of several words, and its data in isim's JSON
//   format. NLTagger applies the gazetteers set for a scheme; with .joinNames, a matched phrase is one token.
// - NLEmbedding: custom embeddings (write / init(contentsOf:): isim's JSON, or fastText's .vec text format) with
//   cosine-distance neighbours. The built-in word embeddings are passthrough to fastText vectors the host provides:
//   ISIM_WORD_VECTORS=<directory> with <language>.vec (or cc.<language>.300.vec / wiki.<language>.vec). The most
//   frequent ISIM_WORD_VECTORS_LIMIT words are read (default 100000). The sentence embedding is the mean of those
//   vectors. Without vectors, wordEmbedding(for:) and sentenceEmbedding(for:) return nil, like a device without the assets.
// - NLContextualEmbedding (adapted): one model per script over the same fastText vectors. Each token's vector is its
//   word vector mixed with its neighbours' (no transformer, so the vectors differ from Apple's). It has assets when the
//   host has vectors for one of its languages.
// - NLModel: Create ML's text classifiers and word taggers keep their parameters in undocumented data, so loading one
//   throws a clear error (blocked).
import Foundation
import CoreML

public typealias NLDistance = Double
@objc public enum NLDistanceType: Int, Sendable { case cosine = 0 }

// MARK: - NLGazetteer

open class NLGazetteer: NSObject, @unchecked Sendable {
    public let language: NLLanguage?
    let _labels: [String: [String]]
    var _lookup: [String: String] = [:]
    var _longest = 1

    public init(dictionary: [String: [String]], language: NLLanguage?) throws {
        _labels = dictionary; self.language = language
        super.init()
        for (label, terms) in dictionary.sorted(by: { $0.key < $1.key }) {
            for t in terms {
                let k = NLGazetteer._key(t)
                guard !k.isEmpty, _lookup[k] == nil else { continue }
                _lookup[k] = label
                _longest = max(_longest, k.split(separator: " ").count)
            }
        }
    }
    public convenience init(data: Data) throws {
        guard let doc = try? JSONDecoder().decode(_Doc.self, from: data), doc.format == "isim.gazetteer" else {
            throw NLGazetteer._error("the data is not a gazetteer written by NLGazetteer.write (isim cannot read Create ML gazetteers: Apple's model data is undocumented)")
        }
        try self.init(dictionary: doc.labels, language: doc.language.map { NLLanguage($0) })
    }
    public convenience init(contentsOf url: URL) throws {
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw NLGazetteer._error("isim could not read the gazetteer at \(url.path)") }
        try self.init(data: data)
    }
    /// the gazetteer's data (isim's JSON format)
    open var data: Data { (try? NLGazetteer._encode(_labels, language)) ?? Data() }
    open class func write(_ dictionary: [String: [String]], language: NLLanguage?, to url: URL) throws {
        try _encode(dictionary, language).write(to: url)
    }
    /// the label of a term (case- and diacritic-insensitive), or nil
    open func label(for string: String) -> String? { _lookup[NLGazetteer._key(string)] }

    struct _Doc: Codable { var format: String; var language: String?; var labels: [String: [String]] }
    static func _encode(_ labels: [String: [String]], _ language: NLLanguage?) throws -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        return try e.encode(_Doc(format: "isim.gazetteer", language: language?.rawValue, labels: labels))
    }
    static func _key(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    static func _error(_ msg: String) -> NSError {
        NSError(domain: "NLNaturalLanguageErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

extension NLTagger {
    /// words of a matched phrase share the gazetteer's label; returns (first segment, last segment, label) of each match
    static func _gazetteerMatches(_ s: String, _ segs: [(Range<String.Index>, NLTag)], _ gazetteers: [NLGazetteer]) -> [(Int, Int, String)] {
        guard !gazetteers.isEmpty else { return [] }
        let words = segs.indices.filter { segs[$0].1 == .word }
        let longest = gazetteers.map(\._longest).max() ?? 1
        var out: [(Int, Int, String)] = []
        var w = 0
        while w < words.count {
            var hit: (Int, String)?
            for n in stride(from: min(longest, words.count - w), through: 1, by: -1) {
                let text = String(s[segs[words[w]].0.lowerBound..<segs[words[w + n - 1]].0.upperBound])
                if let label = gazetteers.lazy.compactMap({ $0.label(for: text) }).first { hit = (n, label); break }
            }
            if let (n, label) = hit { out.append((words[w], words[w + n - 1], label)); w += n } else { w += 1 }
        }
        return out
    }
}

// MARK: - NLEmbedding

open class NLEmbedding: NSObject, @unchecked Sendable {
    public let dimension: Int
    public let language: NLLanguage?
    public let revision: Int
    let _words: [String]
    let _vectors: [[Double]]          // unit length, for cosine distance
    let _raw: [[Double]]
    let _index: [String: Int]
    let _sentence: NLEmbedding?       // a sentence embedding: the mean of this word embedding's vectors

    init(words: [String], vectors: [[Double]], language: NLLanguage?, revision: Int) {
        var w: [String] = [], raw: [[Double]] = [], idx: [String: Int] = [:]
        for (word, v) in zip(words, vectors) where idx[word] == nil { idx[word] = w.count; w.append(word); raw.append(v) }
        _words = w; _raw = raw; _index = idx
        _vectors = raw.map(NLEmbedding._unit)
        dimension = raw.first?.count ?? 0; self.language = language; self.revision = revision; _sentence = nil
        super.init()
    }
    init(sentencesOver words: NLEmbedding) {
        _words = []; _raw = []; _vectors = []; _index = [:]; _sentence = words
        dimension = words.dimension; language = words.language; revision = words.revision
        super.init()
    }
    /// a custom embedding written by write(_:language:revision:to:), or fastText vectors (.vec text)
    public convenience init(contentsOf url: URL) throws {
        guard let data = try? Data(contentsOf: url) else { throw NLGazetteer._error("isim could not read the embedding at \(url.path)") }
        if let doc = try? JSONDecoder().decode(_Doc.self, from: data), doc.format == "isim.embedding" {
            let keys = doc.vectors.keys.sorted()
            self.init(words: keys, vectors: keys.map { doc.vectors[$0]! }, language: doc.language.map { NLLanguage($0) }, revision: doc.revision)
        } else if let (w, v) = NLEmbedding._readVec(data, limit: Int.max), !w.isEmpty {
            self.init(words: w, vectors: v, language: nil, revision: 1)
        } else {
            throw NLGazetteer._error("\(url.lastPathComponent) is not an embedding written by NLEmbedding.write or fastText vectors (isim cannot read Create ML embeddings: Apple's model data is undocumented)")
        }
    }
    open class func write(_ dictionary: [String: [Double]], language: NLLanguage?, revision: Int, to url: URL) throws {
        guard let d = dictionary.first?.value.count, d > 0, dictionary.values.allSatisfy({ $0.count == d }) else {
            throw NLGazetteer._error("every vector of an embedding needs the same, nonzero dimension")
        }
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        try e.encode(_Doc(format: "isim.embedding", language: language?.rawValue, revision: revision, vectors: dictionary)).write(to: url)
    }
    struct _Doc: Codable { var format: String; var language: String?; var revision: Int; var vectors: [String: [Double]] }

    // MARK: built-in embeddings (the host's fastText vectors)
    open class func wordEmbedding(for language: NLLanguage) -> NLEmbedding? { _Vectors.embedding(language) }
    open class func wordEmbedding(for language: NLLanguage, revision: Int) -> NLEmbedding? { revision == 1 ? wordEmbedding(for: language) : nil }
    open class func sentenceEmbedding(for language: NLLanguage) -> NLEmbedding? { _Vectors.embedding(language).map { NLEmbedding(sentencesOver: $0) } }
    open class func sentenceEmbedding(for language: NLLanguage, revision: Int) -> NLEmbedding? { revision == 1 ? sentenceEmbedding(for: language) : nil }
    open class func currentRevision(for language: NLLanguage) -> Int { _Vectors.file(language) == nil ? 0 : 1 }
    open class func supportedRevisions(for language: NLLanguage) -> IndexSet { _Vectors.file(language) == nil ? [] : [1] }
    open class func currentSentenceEmbeddingRevision(for language: NLLanguage) -> Int { currentRevision(for: language) }
    open class func supportedSentenceEmbeddingRevisions(for language: NLLanguage) -> IndexSet { supportedRevisions(for: language) }

    // MARK: vectors and distances
    open var vocabularySize: Int { _words.count }
    open func contains(_ string: String) -> Bool { _rawVector(string) != nil }
    open func vector(for string: String) -> [Double]? { _rawVector(string) }
    func _rawVector(_ s: String) -> [Double]? {
        if let sw = _sentence {   // the mean of the known words' vectors
            let words = _NL.words(s, s.startIndex..<s.endIndex).compactMap { sw._rawVector(String(s[$0])) }
            guard !words.isEmpty else { return nil }
            return (0..<dimension).map { d in words.reduce(0) { $0 + $1[d] } / Double(words.count) }
        }
        if let i = _index[s] ?? _index[s.lowercased()] { return _raw[i] }
        return nil
    }
    open func distance(between firstString: String, and secondString: String, distanceType: NLDistanceType = .cosine) -> NLDistance {
        guard let a = _rawVector(firstString), let b = _rawVector(secondString) else { return 2 }
        return NLEmbedding._cosineDistance(NLEmbedding._unit(a), NLEmbedding._unit(b))
    }
    open func neighbors(for string: String, maximumCount: Int, distanceType: NLDistanceType = .cosine) -> [(String, NLDistance)] {
        guard let v = _rawVector(string) else { return [] }
        let own = _index[string] ?? _index[string.lowercased()]
        return _nearest(NLEmbedding._unit(v), maximumCount, excluding: own)
    }
    open func neighbors(for vector: [Double], maximumCount: Int, distanceType: NLDistanceType = .cosine) -> [(String, NLDistance)] {
        guard vector.count == dimension else { return [] }
        return _nearest(NLEmbedding._unit(vector), maximumCount, excluding: nil)
    }
    open func enumerateNeighbors(for string: String, maximumCount: Int, distanceType: NLDistanceType = .cosine, using block: (String, NLDistance) -> Bool) {
        for (w, d) in neighbors(for: string, maximumCount: maximumCount, distanceType: distanceType) where !block(w, d) { return }
    }
    open func enumerateNeighbors(for vector: [Double], maximumCount: Int, distanceType: NLDistanceType = .cosine, using block: (String, NLDistance) -> Bool) {
        for (w, d) in neighbors(for: vector, maximumCount: maximumCount, distanceType: distanceType) where !block(w, d) { return }
    }
    func _nearest(_ u: [Double], _ k: Int, excluding: Int?) -> [(String, NLDistance)] {
        guard k > 0 else { return [] }
        var best: [(Int, Double)] = []
        for (i, v) in _vectors.enumerated() where i != excluding {
            let d = NLEmbedding._cosineDistance(u, v)
            if best.count < k { best.append((i, d)); best.sort { $0.1 < $1.1 } }
            else if d < best[k - 1].1 { best[k - 1] = (i, d); best.sort { $0.1 < $1.1 } }
        }
        return best.map { (_words[$0.0], $0.1) }
    }
    static func _unit(_ v: [Double]) -> [Double] {
        let n = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return n > 0 ? v.map { $0 / n } : v
    }
    static func _cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0
        for i in 0..<min(a.count, b.count) { dot += a[i] * b[i] }
        return max(0, min(2, 1 - dot))
    }
    /// fastText's text format: an optional "count dimension" header, then "word v1 … vD" per line
    static func _readVec(_ data: Data, limit: Int) -> ([String], [[Double]])? {
        var words: [String] = [], vecs: [[Double]] = [], dim = 0
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: true).enumerated() {
            let f = line.split(separator: " ")
            if n == 0 && f.count == 2 && Int(f[0]) != nil && Int(f[1]) != nil { continue }
            guard f.count > 1 else { continue }
            let v = f.dropFirst().compactMap { Double($0) }
            guard v.count == f.count - 1 else { return nil }
            if dim == 0 { dim = v.count } else if v.count != dim { return nil }
            words.append(String(f[0])); vecs.append(v)
            if words.count >= limit { break }
        }
        return (words, vecs)
    }
}

/// the host's fastText vectors, loaded once per language
enum _Vectors {
    static let lock = NSLock()
    nonisolated(unsafe) static var cache: [String: NLEmbedding?] = [:]
    static func base(_ l: NLLanguage) -> String { String(l.rawValue.prefix { $0 != "-" && $0 != "_" }) }
    static func file(_ l: NLLanguage) -> URL? {
        guard let dir = ProcessInfo.processInfo.environment["ISIM_WORD_VECTORS"], !dir.isEmpty else { return nil }
        let code = base(l)
        for name in ["\(l.rawValue).vec", "\(code).vec", "cc.\(code).300.vec", "wiki.\(code).vec"] {
            let u = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if FileManager.default.isReadableFile(atPath: u.path) { return u }
        }
        return nil
    }
    static func embedding(_ l: NLLanguage) -> NLEmbedding? {
        lock.lock(); defer { lock.unlock() }
        if let e = cache[l.rawValue] { return e }
        var e: NLEmbedding?
        if let u = file(l), let h = try? FileHandle(forReadingFrom: u) {
            let limit = Int(ProcessInfo.processInfo.environment["ISIM_WORD_VECTORS_LIMIT"] ?? "") ?? 100_000
            // the first lines only: a line of 300 values is about 3 KB
            let data = h.readData(ofLength: min(limit, 1_000_000) * 4096); try? h.close()
            var trimmed = data
            if data.count == min(limit, 1_000_000) * 4096, let nl = data.lastIndex(of: 10) { trimmed = data[..<nl] }
            if let (w, v) = NLEmbedding._readVec(trimmed, limit: limit), !w.isEmpty {
                e = NLEmbedding(words: w, vectors: v, language: l, revision: 1)
            }
        }
        cache[l.rawValue] = e
        return e
    }
}

// MARK: - NLContextualEmbedding

public struct NLScript: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let undetermined = NLScript("Zyyy"), arabic = NLScript("Arab"), armenian = NLScript("Armn"), bengali = NLScript("Beng")
    public static let canadianAboriginalSyllabics = NLScript("Cans"), cherokee = NLScript("Cher"), cyrillic = NLScript("Cyrl")
    public static let devanagari = NLScript("Deva"), ethiopic = NLScript("Ethi"), georgian = NLScript("Geor"), greek = NLScript("Grek")
    public static let gujarati = NLScript("Gujr"), gurmukhi = NLScript("Guru"), hebrew = NLScript("Hebr"), japanese = NLScript("Jpan")
    public static let kannada = NLScript("Knda"), khmer = NLScript("Khmr"), korean = NLScript("Kore"), lao = NLScript("Laoo")
    public static let latin = NLScript("Latn"), malayalam = NLScript("Mlym"), mongolian = NLScript("Mong"), myanmar = NLScript("Mymr")
    public static let oriya = NLScript("Orya"), simplifiedChinese = NLScript("Hans"), sinhala = NLScript("Sinh"), tamil = NLScript("Taml")
    public static let telugu = NLScript("Telu"), thai = NLScript("Thai"), tibetan = NLScript("Tibt"), traditionalChinese = NLScript("Hant")
}

public struct NLContextualEmbeddingKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let languages = NLContextualEmbeddingKey("Languages"), scripts = NLContextualEmbeddingKey("Scripts")
    public static let revision = NLContextualEmbeddingKey("Revision")
}

open class NLContextualEmbedding: NSObject, @unchecked Sendable {
    @objc public enum AssetsResult: Int, Sendable { case available = 0, notAvailable = 1, error = 2 }

    /// isim's models: one per script, over the languages written in it
    static let models: [(NLScript, [NLLanguage])] = [
        (.latin, [.english, .french, .german, .spanish, .italian, .portuguese, .dutch, .swedish, .danish, .norwegian, .finnish, .polish,
                  .turkish, .romanian, .czech, .hungarian, .slovak, .croatian, .catalan, .indonesian, .malay, .vietnamese]),
        (.cyrillic, [.russian, .ukrainian, .bulgarian, .serbian, .kazakh]), (.simplifiedChinese, [.simplifiedChinese]),
        (.traditionalChinese, [.traditionalChinese]), (.japanese, [.japanese]), (.korean, [.korean]), (.arabic, [.arabic, .persian, .urdu]),
        (.hebrew, [.hebrew]), (.devanagari, [.hindi, .marathi]), (.greek, [.greek]), (.thai, [.thai]),
    ]
    public let modelIdentifier: String
    public let languages: [NLLanguage]
    public let scripts: [NLScript]
    public let revision: Int
    public let maximumSequenceLength = 256
    var _loaded: [NLLanguage: NLEmbedding] = [:]
    let _lock = NSLock()

    init(_ script: NLScript, _ languages: [NLLanguage]) {
        modelIdentifier = "com.apple.isim.contextual-embedding.\(script.rawValue).fasttext"; self.languages = languages
        scripts = [script]; revision = 1
    }
    public convenience init?(language: NLLanguage) {
        guard let m = NLContextualEmbedding.models.first(where: { $0.1.contains(language) || $0.1.map(\.rawValue).contains(_Vectors.base(language)) }) else { return nil }
        self.init(m.0, m.1)
    }
    public convenience init?(script: NLScript) {
        guard let m = NLContextualEmbedding.models.first(where: { $0.0 == script }) else { return nil }
        self.init(m.0, m.1)
    }
    public convenience init?(modelIdentifier: String) {
        guard let m = NLContextualEmbedding.models.first(where: { "com.apple.isim.contextual-embedding.\($0.0.rawValue).fasttext" == modelIdentifier }) else { return nil }
        self.init(m.0, m.1)
    }
    open class func contextualEmbeddings(forValues values: [NLContextualEmbeddingKey: Any]) -> [NLContextualEmbedding] {
        let langs = (values[.languages] as? [NLLanguage]) ?? (values[.languages] as? [String])?.map { NLLanguage($0) }
        let scripts = (values[.scripts] as? [NLScript]) ?? (values[.scripts] as? [String])?.map { NLScript($0) }
        let rev = values[.revision] as? Int
        return models.filter { m in
            (langs.map { $0.contains { m.1.contains($0) } } ?? true) && (scripts.map { $0.contains(m.0) } ?? true) && (rev.map { $0 == 1 } ?? true)
        }.map { NLContextualEmbedding($0.0, $0.1) }
    }
    /// the vectors' dimension (isim: the host's fastText vectors; 300 when there are none)
    open var dimension: Int { languages.lazy.compactMap { _Vectors.embedding($0)?.dimension }.first ?? 300 }
    /// isim: true when the host has fastText vectors (ISIM_WORD_VECTORS) for one of its languages
    open var hasAvailableAssets: Bool { languages.contains { _Vectors.file($0) != nil } }
    open func requestAssets(completionHandler: @escaping @Sendable (AssetsResult, Error?) -> Void) {
        let ok = hasAvailableAssets
        DispatchQueue.global().async { completionHandler(ok ? .available : .notAvailable, nil) }
    }
    open func requestAssets() async throws -> AssetsResult { hasAvailableAssets ? .available : .notAvailable }
    open func load() throws {
        let found = languages.compactMap { l in _Vectors.embedding(l).map { (l, $0) } }
        guard !found.isEmpty else {
            throw NLGazetteer._error("the contextual embedding's assets are not available: isim needs fastText vectors (ISIM_WORD_VECTORS=<directory> with <language>.vec)")
        }
        _lock.lock(); _loaded = Dictionary(found, uniquingKeysWith: { a, _ in a }); _lock.unlock()
    }
    open func unload() { _lock.lock(); _loaded = [:]; _lock.unlock() }
    open func embeddingResult(for string: String, language: NLLanguage?) throws -> NLContextualEmbeddingResult {
        _lock.lock(); let loaded = _loaded; _lock.unlock()
        guard !loaded.isEmpty else { throw NLGazetteer._error("load() the contextual embedding before using it") }
        let lang = language.flatMap { l in loaded.keys.first { $0 == l || $0.rawValue == _Vectors.base(l) } }
            ?? NLLanguageRecognizer.dominantLanguage(for: string).flatMap { l in loaded.keys.first { $0 == l } }
            ?? loaded.keys.sorted { $0.rawValue < $1.rawValue }.first!
        let words = Array(_NL.words(string, string.startIndex..<string.endIndex).prefix(maximumSequenceLength))
        let emb = loaded[lang]!, d = emb.dimension
        let base = words.map { emb._rawVector(String(string[$0])) ?? [Double](repeating: 0, count: d) }
        // each token: 60% its own vector, 40% the mean of up to two tokens either side
        var mixed: [[Double]] = []
        for i in base.indices {
            let lo = Swift.max(0, i - 2), hi = Swift.min(base.count - 1, i + 2)
            let ctx = (lo...hi).filter { $0 != i }
            if ctx.isEmpty { mixed.append(base[i]); continue }
            var v = [Double](repeating: 0, count: d)
            for k in 0..<d {
                var sum = 0.0
                for j in ctx { sum += base[j][k] }
                v[k] = 0.6 * base[i][k] + 0.4 * sum / Double(ctx.count)
            }
            mixed.append(v)
        }
        return NLContextualEmbeddingResult(string: string, language: lang, tokens: words, vectors: mixed)
    }
}

open class NLContextualEmbeddingResult: NSObject, @unchecked Sendable {
    public let string: String
    public let language: NLLanguage
    let _tokens: [Range<String.Index>]
    let _vectors: [[Double]]
    init(string: String, language: NLLanguage, tokens: [Range<String.Index>], vectors: [[Double]]) {
        self.string = string; self.language = language; _tokens = tokens; _vectors = vectors
    }
    open var sequenceLength: Int { _tokens.count }
    open func enumerateTokenVectors(in range: Range<String.Index>, using block: ([Double], Range<String.Index>) -> Bool) {
        for (t, v) in zip(_tokens, _vectors) where t.overlaps(range) { if !block(v, t) { return } }
    }
    open func tokenVector(at index: String.Index) -> ([Double], Range<String.Index>)? {
        zip(_tokens, _vectors).first { $0.0.contains(index) }.map { ($0.1, $0.0) }
    }
}

// MARK: - NLModel

open class NLModelConfiguration: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public internal(set) var type: NLModel.ModelType = .classifier
    public internal(set) var language: NLLanguage?
    public internal(set) var revision: Int = 1
    public override init() { super.init() }
    open class func supportedRevisions(for type: NLModel.ModelType) -> IndexSet { [] }
    open class func currentRevision(for type: NLModel.ModelType) -> Int { 0 }
    public func copy(with zone: NSZone? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {
        coder.encode(type.rawValue, forKey: "type"); coder.encode(language?.rawValue, forKey: "language"); coder.encode(revision, forKey: "revision")
    }
    public required init?(coder: NSCoder) {
        type = NLModel.ModelType(rawValue: coder.decodeInteger(forKey: "type")) ?? .classifier
        language = (coder.decodeObject(forKey: "language") as? String).map { NLLanguage($0) }
        revision = coder.decodeInteger(forKey: "revision")
    }
}

/// Blocked: Create ML's text classifiers and word taggers keep their parameters in undocumented data.
open class NLModel: NSObject, @unchecked Sendable {
    @objc public enum ModelType: Int, Sendable { case classifier = 0, sequence = 1 }
    public let configuration = NLModelConfiguration()
    public init(contentsOf url: URL) throws {
        throw NLModel._error("isim cannot run Create ML text models (\(url.lastPathComponent)): their parameters are in Apple's undocumented model data")
    }
    public convenience init(mlModel: MLModel) throws {
        let kind = mlModel._isimModelKind ?? "unknown"
        guard kind == "textClassifier" || kind == "wordTagger" else {
            throw NLModel._error("the Core ML model is not a Natural Language model (it is a \(kind) model)")
        }
        throw NLModel._error("isim cannot run Create ML text models (a \(kind)): their parameters are in Apple's undocumented model data")
    }
    open func predictedLabel(for string: String) -> String? { nil }
    open func predictedLabels(forTokens tokens: [String]) -> [String] { [] }
    open func predictedLabelHypotheses(for string: String, maximumCount: Int) -> [String: Double] { [:] }
    open func predictedLabelHypotheses(forTokens tokens: [String], maximumCount: Int) -> [[String: Double]] { [] }
    static func _error(_ msg: String) -> NSError {
        NSLog("isim NaturalLanguage: %@", msg)
        return NSError(domain: "NLNaturalLanguageErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
