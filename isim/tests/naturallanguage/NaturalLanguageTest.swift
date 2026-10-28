// NaturalLanguage gazetteers and embeddings (NaturalLanguageTest.app, issue #378): NLGazetteer with NLTagger, custom
// NLEmbeddings, the built-in word / sentence embeddings over the host's fastText vectors, NLContextualEmbedding and
// NLModel. test_naturallanguage.py runs it with a tiny vector file (ISIM_WORD_VECTORS) and without one.
import Foundation
import NaturalLanguage

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func near(_ a: Double, _ b: Double, _ tol: Double = 1e-9) -> Bool { abs(a - b) <= tol }
let tmp = URL(fileURLWithPath: NSTemporaryDirectory())

@main enum NaturalLanguageTest {
    static func main() async {
        do {
            try gazetteers()
            try customEmbeddings()
            contextualModels()
            models()
            if NLEmbedding.wordEmbedding(for: .english) != nil { try await withVectors() } else { await withoutVectors() }
        } catch { failures += 1; print("FAIL  threw \(error)") }
        print("NaturalLanguageTest: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }

    static func gazetteers() throws {
        let places = ["PlaceName": ["Paris", "New York", "São Paulo"], "OrganizationName": ["Apple"]]
        let g = try NLGazetteer(dictionary: places, language: .english)
        check(g.label(for: "paris") == "PlaceName" && g.label(for: "SAO PAULO") == "PlaceName" && g.label(for: "new  york") == "PlaceName"
              && g.label(for: "London") == nil && g.language == .english, "NLGazetteer labels (case- and diacritic-insensitive)")
        let url = tmp.appendingPathComponent("places.gazetteer")
        try NLGazetteer.write(places, language: .english, to: url)
        let loaded = try NLGazetteer(contentsOf: url), copy = try NLGazetteer(data: g.data)
        check(loaded.label(for: "Apple") == "OrganizationName" && copy.label(for: "Paris") == "PlaceName" && loaded.language == .english,
              "NLGazetteer write, contentsOf, data")
        do { _ = try NLGazetteer(data: Data("not a gazetteer".utf8)); check(false, "foreign gazetteer data throws") }
        catch { check(true, "foreign gazetteer data throws") }

        let text = "I flew from New York to Paris with Apple."
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        tagger.setGazetteers([g], for: .nameType)
        let named = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames])
            .compactMap { t, r in t.map { "\(text[r])=\($0.rawValue)" } }
        print("names: \(named)")
        check(named == ["New York=PlaceName", "Paris=PlaceName", "Apple=OrganizationName"] && tagger.gazetteers(for: .nameType).count == 1,
              "NLTagger with a gazetteer: joined names")
        let unjoined = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation])
            .compactMap { t, r in t.map { _ in String(text[r]) } }
        check(unjoined == ["New", "York", "Paris", "Apple"], "without .joinNames each word of a phrase is tagged")
        tagger.setGazetteers([try NLGazetteer(dictionary: ["Brand": ["isim"]], language: nil)], for: .lexicalClass)
        tagger.string = "isim runs apps"
        let s = tagger.string!
        let classes = tagger.tags(in: s.startIndex..<s.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]).map { $0.0?.rawValue ?? "-" }
        check(classes.first == "Brand" && classes.count == 3 && tagger.gazetteers(for: .tokenType).isEmpty, "a gazetteer overrides lexical classes")
    }

    static func customEmbeddings() throws {
        let url = tmp.appendingPathComponent("animals.embedding")
        try NLEmbedding.write(["cat": [1, 0, 0], "dog": [0.9, 0.1, 0], "car": [0, 0, 1]], language: .english, revision: 2, to: url)
        let e = try NLEmbedding(contentsOf: url)
        check(e.dimension == 3 && e.vocabularySize == 3 && e.language == .english && e.revision == 2, "custom embedding: write and load")
        let n = e.neighbors(for: "cat", maximumCount: 2)
        check(n.map(\.0) == ["dog", "car"] && near(n[1].1, 1), "neighbors(for:) by cosine distance, the word itself excluded")
        check(e.vector(for: "dog") == [0.9, 0.1, 0] && e.contains("car") && !e.contains("cow"), "vector(for:), contains")
        check(e.distance(between: "cat", and: "dog") < 0.01 && near(e.distance(between: "cat", and: "car"), 1) && e.distance(between: "cat", and: "cow") == 2,
              "distance(between:and:)")
        check(e.neighbors(for: [0, 0.1, 1], maximumCount: 1).first?.0 == "car", "neighbors(for: vector)")
        var seen = 0
        e.enumerateNeighbors(for: "cat", maximumCount: 3) { _, _ in seen += 1; return false }
        check(seen == 1, "enumerateNeighbors stops")
        do { try NLEmbedding.write(["a": [1], "b": [1, 2]], language: nil, revision: 1, to: url); check(false, "mixed dimensions throw") }
        catch { check(true, "mixed dimensions throw") }
        let vec = tmp.appendingPathComponent("small.vec")
        try "2 2\nsun 1 0\nmoon 0.8 0.6\n".write(to: vec, atomically: true, encoding: .utf8)
        let fv = try NLEmbedding(contentsOf: vec)
        check(fv.dimension == 2 && fv.neighbors(for: "sun", maximumCount: 1).first?.0 == "moon", "fastText .vec files load as embeddings")
    }

    static func contextualModels() {
        let en = NLContextualEmbedding(language: .english)
        check(en?.scripts == [.latin] && en?.languages.contains(.french) == true && en?.maximumSequenceLength == 256, "NLContextualEmbedding(language:)")
        check(NLContextualEmbedding(language: NLLanguage("xx")) == nil && NLContextualEmbedding(script: .cyrillic)?.languages.first == .russian,
              "unsupported languages; init(script:)")
        let found = NLContextualEmbedding.contextualEmbeddings(forValues: [.scripts: [NLScript.cyrillic]])
        check(found.count == 1 && NLContextualEmbedding(modelIdentifier: found[0].modelIdentifier)?.scripts == [.cyrillic], "contextualEmbeddings(forValues:), modelIdentifier")
        check(NLScript.simplifiedChinese.rawValue == "Hans" && NLContextualEmbeddingKey.languages.rawValue == "Languages", "NLScript, NLContextualEmbeddingKey")
    }

    static func models() {
        do { _ = try NLModel(contentsOf: tmp.appendingPathComponent("Classifier.mlmodelc")); check(false, "NLModel(contentsOf:) throws") }
        catch { check(error.localizedDescription.contains("Create ML"), "NLModel(contentsOf:) throws") }
        check(NLModelConfiguration.supportedRevisions(for: .classifier).isEmpty && NLModel.ModelType.sequence.rawValue == 1, "NLModelConfiguration")
    }

    static func withVectors() async throws {
        print("vectors: available")
        let e = NLEmbedding.wordEmbedding(for: .english)!
        check(e.dimension == 4 && e.vocabularySize == 7 && e.language == .english, "wordEmbedding(for:) from the host's vectors")
        check(e.neighbors(for: "king", maximumCount: 1).first?.0 == "queen" && e.neighbors(for: "apple", maximumCount: 1).first?.0 == "banana",
              "word neighbours")
        check(NLEmbedding.currentRevision(for: .english) == 1 && NLEmbedding.supportedRevisions(for: .english) == IndexSet([1])
              && NLEmbedding.wordEmbedding(for: .english, revision: 2) == nil && NLEmbedding.wordEmbedding(for: .french) == nil, "revisions")
        let s = NLEmbedding.sentenceEmbedding(for: .english)!
        let v = s.vector(for: "King and queen!")!
        check(near(v[0], 0.875) && near(v[1], 0.85) && s.vocabularySize == 0, "sentenceEmbedding: the mean of the words' vectors")
        check(s.distance(between: "the king", and: "the queen") < s.distance(between: "the king", and: "a banana"), "sentence distances")

        let ce = NLContextualEmbedding(language: .english)!
        check(ce.hasAvailableAssets && ce.dimension == 4, "contextual embedding assets from the host's vectors")
        let result = try await ce.requestAssets()
        check(result == .available, "requestAssets")
        try ce.load()
        let text = "The king eats an apple"
        let r = try ce.embeddingResult(for: text, language: .english)
        check(r.sequenceLength == 5 && r.language == .english && r.string == text, "embeddingResult(for:language:)")
        let king = text.range(of: "king")!
        if let (kv, kr) = r.tokenVector(at: king.lowerBound) {
            // 60% king, 40% the mean of the, eats (unknown: zeros) and an (unknown)
            check(kr == king && near(kv[0], 0.6 * 0.9 + 0.4 * 0.1 / 3, 1e-9), "tokenVector(at:) mixes in the context")
        } else { check(false, "tokenVector(at:)") }
        var count = 0
        r.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { v, _ in count += v.count == 4 ? 1 : 0; return true }
        check(count == 5, "enumerateTokenVectors")
        ce.unload()
        do { _ = try ce.embeddingResult(for: text, language: nil); check(false, "unloaded embeddings throw") }
        catch { check(true, "unloaded embeddings throw") }
    }

    static func withoutVectors() async {
        print("vectors: none")
        check(NLEmbedding.wordEmbedding(for: .english) == nil && NLEmbedding.sentenceEmbedding(for: .english) == nil
              && NLEmbedding.supportedRevisions(for: .english).isEmpty, "no built-in embeddings without vectors")
        let ce = NLContextualEmbedding(language: .english)!
        let result = try? await ce.requestAssets()
        check(!ce.hasAvailableAssets && result == .notAvailable, "contextual embedding assets not available")
        do { try ce.load(); check(false, "load() throws without assets") }
        catch { check(error.localizedDescription.contains("ISIM_WORD_VECTORS"), "load() throws without assets") }
    }
}
