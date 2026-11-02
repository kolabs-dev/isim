// isim NaturalLanguage: the Objective-C interface (issue #701, <NaturalLanguage/NaturalLanguage.h>). The classes are
// exported under Apple's names; members whose Swift types do not bridge (Range<String.Index>, NLLanguage, NLTag, …) get
// Objective-C methods here that convert NSRange (UTF-16 offsets) and strings and call the Swift API.
import Foundation
import CoreML

extension String {
    /// the Swift range of an NSRange, clamped to the string (whole characters)
    func _nlRange(_ r: NSRange) -> Range<String.Index> {
        let ns = self as NSString, n = ns.length
        let lo = min(max(0, r.location), n), hi = min(n, lo + max(0, min(r.length, n - lo)))
        let a = lo < n ? ns.rangeOfComposedCharacterSequence(at: lo).location : n
        let b = hi < n && hi > a ? NSMaxRange(ns.rangeOfComposedCharacterSequence(at: hi - 1)) : max(hi, a)
        return Range(NSRange(location: a, length: b - a), in: self) ?? endIndex..<endIndex
    }
    /// the index of the character at a UTF-16 offset
    func _nlIndex(_ i: Int) -> String.Index {
        let ns = self as NSString
        guard i >= 0, i < ns.length else { return endIndex }
        return Range(ns.rangeOfComposedCharacterSequence(at: i), in: self)?.lowerBound ?? endIndex
    }
    func _nsRange(_ r: Range<String.Index>) -> NSRange { NSRange(r, in: self) }
}

private func _numbers(_ v: [Double]) -> [NSNumber] { v.map { NSNumber(value: $0) } }
private func _doubles(_ v: [NSNumber]) -> [Double] { v.map(\.doubleValue) }

// MARK: - NLTokenizer

extension NLTokenizer {
    @objc(setLanguage:) func _objcSetLanguage(_ language: String) { setLanguage(NLLanguage(language)) }
    @objc(tokenRangeAtIndex:) func _objcTokenRange(at index: Int) -> NSRange {
        guard let s = string, index >= 0, index < (s as NSString).length else { return NSRange(location: index, length: 0) }
        return s._nsRange(tokenRange(at: s._nlIndex(index)))
    }
    @objc(tokenRangeForRange:) func _objcTokenRange(for range: NSRange) -> NSRange {
        guard let s = string else { return range }
        return s._nsRange(tokenRange(for: s._nlRange(range)))
    }
    @objc(tokensForRange:) func _objcTokens(for range: NSRange) -> [NSValue] {
        guard let s = string else { return [] }
        return tokens(for: s._nlRange(range)).map { NSValue(range: s._nsRange($0)) }
    }
    @objc(enumerateTokensInRange:usingBlock:)
    func _objcEnumerateTokens(in range: NSRange, using block: (NSRange, UInt, UnsafeMutablePointer<ObjCBool>) -> Void) {
        guard let s = string else { return }
        var stop: ObjCBool = false
        enumerateTokens(in: s._nlRange(range)) { r, attributes in
            block(s._nsRange(r), attributes.rawValue, &stop)
            return !stop.boolValue
        }
    }
}

// MARK: - NLLanguageRecognizer

extension NLLanguageRecognizer {
    @objc(dominantLanguageForString:) class func _objcDominantLanguage(for string: String) -> String? { dominantLanguage(for: string)?.rawValue }
    @objc(dominantLanguage) var _objcDominantLanguage: String? { dominantLanguage?.rawValue }
    @objc(languageHypothesesWithMaximum:) func _objcLanguageHypotheses(withMaximum maximum: Int) -> [String: NSNumber] {
        Dictionary(uniqueKeysWithValues: languageHypotheses(withMaximum: maximum).map { ($0.key.rawValue, NSNumber(value: $0.value)) })
    }
    @objc(languageHints) var _objcLanguageHints: [String: NSNumber] {
        get { Dictionary(uniqueKeysWithValues: languageHints.map { ($0.key.rawValue, NSNumber(value: $0.value)) }) }
        set { languageHints = Dictionary(newValue.map { (NLLanguage($0.key), $0.value.doubleValue) }, uniquingKeysWith: { a, _ in a }) }
    }
    @objc(languageConstraints) var _objcLanguageConstraints: [String] {
        get { languageConstraints.map(\.rawValue) }
        set { languageConstraints = newValue.map { NLLanguage($0) } }
    }
}

// MARK: - NLTagger

extension NLTagger {
    @objc(initWithTagSchemes:) convenience init(_objcTagSchemes tagSchemes: [String]) { self.init(tagSchemes: tagSchemes.map { NLTagScheme($0) }) }
    @objc(tagSchemes) var _objcTagSchemes: [String] { tagSchemes.map(\.rawValue) }
    @objc(availableTagSchemesForUnit:language:) class func _objcAvailableTagSchemes(for unit: NLTokenUnit, language: String) -> [String] {
        availableTagSchemes(for: unit, language: NLLanguage(language)).map(\.rawValue)
    }
    @objc(tokenRangeAtIndex:unit:) func _objcTokenRange(at index: Int, unit: NLTokenUnit) -> NSRange {
        guard let s = string, index >= 0, index < (s as NSString).length else { return NSRange(location: index, length: 0) }
        return s._nsRange(tokenRange(at: s._nlIndex(index), unit: unit))
    }
    @objc(tokenRangeForRange:unit:) func _objcTokenRange(for range: NSRange, unit: NLTokenUnit) -> NSRange {
        guard let s = string else { return range }
        return s._nsRange(tokenRange(for: s._nlRange(range), unit: unit))
    }
    @objc(dominantLanguage) var _objcDominantLanguage: String? { dominantLanguage?.rawValue }
    @objc(enumerateTagsInRange:unit:scheme:options:usingBlock:)
    func _objcEnumerateTags(in range: NSRange, unit: NLTokenUnit, scheme: String, options: UInt,
                            using block: (String?, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void) {
        guard let s = string else { return }
        var stop: ObjCBool = false
        enumerateTags(in: s._nlRange(range), unit: unit, scheme: NLTagScheme(scheme), options: Options(rawValue: options)) { tag, r in
            block(tag?.rawValue, s._nsRange(r), &stop)
            return !stop.boolValue
        }
    }
    @objc(tagAtIndex:unit:scheme:tokenRange:)
    func _objcTag(at index: Int, unit: NLTokenUnit, scheme: String, tokenRange: UnsafeMutablePointer<NSRange>?) -> String? {
        guard let s = string, index >= 0, index < (s as NSString).length else { tokenRange?.pointee = NSRange(location: index, length: 0); return nil }
        let (tag, r) = tag(at: s._nlIndex(index), unit: unit, scheme: NLTagScheme(scheme))
        tokenRange?.pointee = s._nsRange(r)
        return tag?.rawValue
    }
    @objc(tagsInRange:unit:scheme:options:tokenRanges:)
    func _objcTags(in range: NSRange, unit: NLTokenUnit, scheme: String, options: UInt,
                   tokenRanges: AutoreleasingUnsafeMutablePointer<NSArray?>?) -> [String] {
        guard let s = string else { tokenRanges?.pointee = [] as NSArray; return [] }
        // Apple's array holds a tag per range; tokens without a tag are left out of both
        let found = tags(in: s._nlRange(range), unit: unit, scheme: NLTagScheme(scheme), options: Options(rawValue: options))
            .compactMap { t, r in t.map { ($0.rawValue, NSValue(range: s._nsRange(r))) } }
        tokenRanges?.pointee = found.map(\.1) as NSArray
        return found.map(\.0)
    }
    @objc(tagHypothesesAtIndex:unit:scheme:maximumCount:tokenRange:)
    func _objcTagHypotheses(at index: Int, unit: NLTokenUnit, scheme: String, maximumCount: Int,
                            tokenRange: UnsafeMutablePointer<NSRange>?) -> [String: NSNumber] {
        guard let s = string, index >= 0, index < (s as NSString).length else { tokenRange?.pointee = NSRange(location: index, length: 0); return [:] }
        let (h, r) = tagHypotheses(at: s._nlIndex(index), unit: unit, scheme: NLTagScheme(scheme), maximumCount: maximumCount)
        tokenRange?.pointee = s._nsRange(r)
        return h.mapValues { NSNumber(value: $0) }
    }
    @objc(setLanguage:range:) func _objcSetLanguage(_ language: String, range: NSRange) {
        let s = string ?? ""
        setLanguage(NLLanguage(language), range: s._nlRange(range))
    }
    @objc(setModels:forTagScheme:) func _objcSetModels(_ models: [NLModel], forTagScheme tagScheme: String) { setModels(models, forTagScheme: NLTagScheme(tagScheme)) }
    @objc(modelsForTagScheme:) func _objcModels(forTagScheme tagScheme: String) -> [NLModel] { models(forTagScheme: NLTagScheme(tagScheme)) }
    @objc(setGazetteers:forTagScheme:) func _objcSetGazetteers(_ gazetteers: [NLGazetteer], forTagScheme tagScheme: String) {
        setGazetteers(gazetteers, for: NLTagScheme(tagScheme))
    }
    @objc(gazetteersForTagScheme:) func _objcGazetteers(forTagScheme tagScheme: String) -> [NLGazetteer] { gazetteers(for: NLTagScheme(tagScheme)) }
}

// MARK: - NLGazetteer

extension NLGazetteer {
    @objc(gazetteerWithContentsOfURL:error:) class func _objcGazetteer(contentsOf url: URL) throws -> NLGazetteer { try NLGazetteer(contentsOf: url) }
    @objc(initWithDictionary:language:error:) convenience init(_objcDictionary dictionary: [String: [String]], language: String?) throws {
        try self.init(dictionary: dictionary, language: language.map { NLLanguage($0) })
    }
    @objc(language) var _objcLanguage: String? { language?.rawValue }
    @objc(writeGazetteerForDictionary:language:toURL:error:)
    class func _objcWrite(_ dictionary: [String: [String]], language: String?, to url: URL) throws {
        try write(dictionary, language: language.map { NLLanguage($0) }, to: url)
    }
}

// MARK: - NLEmbedding

extension NLEmbedding {
    @objc(wordEmbeddingForLanguage:) class func _objcWordEmbedding(for language: String) -> NLEmbedding? { wordEmbedding(for: NLLanguage(language)) }
    @objc(wordEmbeddingForLanguage:revision:) class func _objcWordEmbedding(for language: String, revision: Int) -> NLEmbedding? {
        wordEmbedding(for: NLLanguage(language), revision: revision)
    }
    @objc(sentenceEmbeddingForLanguage:) class func _objcSentenceEmbedding(for language: String) -> NLEmbedding? { sentenceEmbedding(for: NLLanguage(language)) }
    @objc(sentenceEmbeddingForLanguage:revision:) class func _objcSentenceEmbedding(for language: String, revision: Int) -> NLEmbedding? {
        sentenceEmbedding(for: NLLanguage(language), revision: revision)
    }
    @objc(embeddingWithContentsOfURL:error:) class func _objcEmbedding(contentsOf url: URL) throws -> NLEmbedding { try NLEmbedding(contentsOf: url) }
    @objc(language) var _objcLanguage: String? { language?.rawValue }
    @objc(supportedRevisionsForLanguage:) class func _objcSupportedRevisions(for language: String) -> IndexSet { supportedRevisions(for: NLLanguage(language)) }
    @objc(currentRevisionForLanguage:) class func _objcCurrentRevision(for language: String) -> Int { currentRevision(for: NLLanguage(language)) }
    @objc(supportedSentenceEmbeddingRevisionsForLanguage:) class func _objcSupportedSentenceEmbeddingRevisions(for language: String) -> IndexSet {
        supportedSentenceEmbeddingRevisions(for: NLLanguage(language))
    }
    @objc(currentSentenceEmbeddingRevisionForLanguage:) class func _objcCurrentSentenceEmbeddingRevision(for language: String) -> Int {
        currentSentenceEmbeddingRevision(for: NLLanguage(language))
    }
    @objc(writeEmbeddingForDictionary:language:revision:toURL:error:)
    class func _objcWrite(_ dictionary: [String: [NSNumber]], language: String?, revision: Int, to url: URL) throws {
        try write(dictionary.mapValues(_doubles), language: language.map { NLLanguage($0) }, revision: revision, to: url)
    }
    @objc(vectorForString:) func _objcVector(for string: String) -> [NSNumber]? { vector(for: string).map(_numbers) }
    @objc(getVector:forString:) func _objcGetVector(_ out: UnsafeMutablePointer<Float>, for string: String) -> Bool {
        guard let v = vector(for: string) else { return false }
        for (i, x) in v.enumerated() { out[i] = Float(x) }
        return true
    }
    private static func _enumerate(_ found: [(String, NLDistance)], _ block: (String, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for (w, d) in found { block(w, d, &stop); if stop.boolValue { return } }
    }
    @objc(enumerateNeighborsForString:maximumCount:distanceType:usingBlock:)
    func _objcEnumerateNeighbors(for string: String, maximumCount: Int, distanceType: NLDistanceType,
                                 using block: (String, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        NLEmbedding._enumerate(neighbors(for: string, maximumCount: maximumCount, distanceType: distanceType), block)
    }
    @objc(enumerateNeighborsForString:maximumCount:maximumDistance:distanceType:usingBlock:)
    func _objcEnumerateNeighbors(for string: String, maximumCount: Int, maximumDistance: Double, distanceType: NLDistanceType,
                                 using block: (String, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        NLEmbedding._enumerate(neighbors(for: string, maximumCount: maximumCount, maximumDistance: maximumDistance, distanceType: distanceType), block)
    }
    @objc(enumerateNeighborsForVector:maximumCount:distanceType:usingBlock:)
    func _objcEnumerateNeighbors(forVector vector: [NSNumber], maximumCount: Int, distanceType: NLDistanceType,
                                 using block: (String, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        NLEmbedding._enumerate(neighbors(for: _doubles(vector), maximumCount: maximumCount, distanceType: distanceType), block)
    }
    @objc(enumerateNeighborsForVector:maximumCount:maximumDistance:distanceType:usingBlock:)
    func _objcEnumerateNeighbors(forVector vector: [NSNumber], maximumCount: Int, maximumDistance: Double, distanceType: NLDistanceType,
                                 using block: (String, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        NLEmbedding._enumerate(neighbors(for: _doubles(vector), maximumCount: maximumCount, maximumDistance: maximumDistance, distanceType: distanceType), block)
    }
    @objc(neighborsForString:maximumCount:distanceType:)
    func _objcNeighbors(for string: String, maximumCount: Int, distanceType: NLDistanceType) -> [String]? {
        contains(string) ? neighbors(for: string, maximumCount: maximumCount, distanceType: distanceType).map(\.0) : nil
    }
    @objc(neighborsForString:maximumCount:maximumDistance:distanceType:)
    func _objcNeighbors(for string: String, maximumCount: Int, maximumDistance: Double, distanceType: NLDistanceType) -> [String]? {
        contains(string) ? neighbors(for: string, maximumCount: maximumCount, maximumDistance: maximumDistance, distanceType: distanceType).map(\.0) : nil
    }
    @objc(neighborsForVector:maximumCount:distanceType:)
    func _objcNeighbors(forVector vector: [NSNumber], maximumCount: Int, distanceType: NLDistanceType) -> [String]? {
        vector.count == dimension ? neighbors(for: _doubles(vector), maximumCount: maximumCount, distanceType: distanceType).map(\.0) : nil
    }
    @objc(neighborsForVector:maximumCount:maximumDistance:distanceType:)
    func _objcNeighbors(forVector vector: [NSNumber], maximumCount: Int, maximumDistance: Double, distanceType: NLDistanceType) -> [String]? {
        vector.count == dimension
            ? neighbors(for: _doubles(vector), maximumCount: maximumCount, maximumDistance: maximumDistance, distanceType: distanceType).map(\.0) : nil
    }
}

// MARK: - NLContextualEmbedding

extension NLContextualEmbedding {
    @objc(contextualEmbeddingWithModelIdentifier:) class func _objcContextualEmbedding(modelIdentifier: String) -> NLContextualEmbedding? {
        NLContextualEmbedding(modelIdentifier: modelIdentifier)
    }
    @objc(contextualEmbeddingWithLanguage:) class func _objcContextualEmbedding(language: String) -> NLContextualEmbedding? {
        NLContextualEmbedding(language: NLLanguage(language))
    }
    @objc(contextualEmbeddingWithScript:) class func _objcContextualEmbedding(script: String) -> NLContextualEmbedding? {
        NLContextualEmbedding(script: NLScript(script))
    }
    @objc(contextualEmbeddingsForValues:) class func _objcContextualEmbeddings(forValues values: [String: Any]) -> [NLContextualEmbedding] {
        contextualEmbeddings(forValues: Dictionary(values.map { (NLContextualEmbeddingKey($0.key), $0.value) }, uniquingKeysWith: { a, _ in a }))
    }
    @objc(languages) var _objcLanguages: [String] { languages.map(\.rawValue) }
    @objc(scripts) var _objcScripts: [String] { scripts.map(\.rawValue) }
    @objc(embeddingResultForString:language:error:)
    func _objcEmbeddingResult(for string: String, language: String?) throws -> NLContextualEmbeddingResult {
        try embeddingResult(for: string, language: language.map { NLLanguage($0) })
    }
}

extension NLContextualEmbeddingResult {
    @objc(language) var _objcLanguage: String { language.rawValue }
    @objc(enumerateTokenVectorsInRange:usingBlock:)
    func _objcEnumerateTokenVectors(in range: NSRange, using block: ([NSNumber], NSRange, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        enumerateTokenVectors(in: string._nlRange(range)) { v, r in
            block(_numbers(v), string._nsRange(r), &stop)
            return !stop.boolValue
        }
    }
    @objc(tokenVectorAtIndex:tokenRange:) func _objcTokenVector(at index: Int, tokenRange: UnsafeMutablePointer<NSRange>?) -> [NSNumber]? {
        guard index >= 0, index < (string as NSString).length, let (v, r) = tokenVector(at: string._nlIndex(index)) else { return nil }
        tokenRange?.pointee = string._nsRange(r)
        return _numbers(v)
    }
}

// MARK: - NLModel

extension NLModel {
    @objc(modelWithContentsOfURL:error:) class func _objcModel(contentsOf url: URL) throws -> NLModel { try NLModel(contentsOf: url) }
    @objc(modelWithMLModel:error:) class func _objcModel(mlModel: MLModel) throws -> NLModel { try NLModel(mlModel: mlModel) }
}

extension NLModelConfiguration {
    @objc(language) var _objcLanguage: String? { language?.rawValue }
}
