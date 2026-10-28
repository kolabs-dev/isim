# NaturalLanguage

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 95.2% of Apple's iOS API (278 of 292, exact) · **Rows:** 6: 1 ✅ 4 🟡 1 ❌ · **iOS:** 12.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [NaturalLanguage](https://developer.apple.com/documentation/naturallanguage) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Adapted:** rule-based tokenizer, language recognizer and tagger, with no Apple statistical models.
- **Passthrough** to fastText word vectors on the host (`ISIM_WORD_VECTORS`) for the built-in and contextual embeddings;
  gazetteers and custom embeddings are isim's own. NLModel is blocked (Create ML's model data is undocumented).
- **Swift only:** the Objective-C interface (`<NaturalLanguage/NaturalLanguage.h>`) is not there yet (#701).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| NaturalLanguage `NLTokenizer`, `NLLanguageRecognizer` | 🟡 | ≤17 | adapted: rule-based (Unicode classes, abbreviations; scripts + stop words for 14 Latin-script languages); tested on 6 languages; no Apple statistical models |
| NaturalLanguage `NLTagger` | 🟡 | ≤17 | adapted: tokenType, language, script; lexicalClass from a small English lexicon and suffix rules; sentimentScore from a word list; tested; nameType and lemma give no tags unless a gazetteer is set for the scheme |
| `NLGazetteer`, `NLTagger.setGazetteers(_:for:)` / `gazetteers(for:)` | ✅ | ≤17 | adapted: labels by case-, diacritic- and width-insensitive lookup, phrases of several words included; a tagger's gazetteers label the words they list ahead of the scheme's own tags (any scheme: nameType, lexicalClass, …), and with `.joinNames` a matched phrase is one token; `write` / `data` / `init(data:)` / `init(contentsOf:)` use isim's JSON format (Create ML gazetteer models are undocumented and throw). Tested (NaturalLanguageTest: test_naturallanguage_with_vectors) |
| `NLEmbedding` (custom embeddings, neighbours, distances, word and sentence embeddings) | 🟡 | ≤17 | adapted: `write` / `init(contentsOf:)` use isim's JSON format or fastText's `.vec` text; cosine distances (2 for unknown words) and neighbours. The built-in embeddings are passthrough to fastText vectors on the host (`ISIM_WORD_VECTORS=<dir>` with `<language>.vec`, the first `ISIM_WORD_VECTORS_LIMIT` words, default 100000); the sentence embedding is the mean of its words' vectors; revision 1. Without vectors `wordEmbedding(for:)` / `sentenceEmbedding(for:)` return nil (tested: test_naturallanguage_without_vectors). Tested (NaturalLanguageTest) |
| `NLContextualEmbedding`, `NLContextualEmbeddingResult`, `NLContextualEmbeddingKey`, `NLScript` | 🟡 | ≤17 | adapted: one model per script (Latin, Cyrillic, Chinese, Japanese, Korean, Arabic, Hebrew, Devanagari, Greek, Thai) over the host's fastText vectors; each word's vector is mixed with its neighbours' (60% its own, 40% the mean of two tokens either side), so the vectors are not a transformer's and do not match Apple's; assets are available when the host has vectors for one of its languages, otherwise `load()` throws naming `ISIM_WORD_VECTORS`. Tested (NaturalLanguageTest) |
| `NLModel`, `NLModelConfiguration` | ❌ | ≤17 | blocked: Create ML's text classifiers and word taggers keep their parameters in Apple's undocumented model data, so `init(contentsOf:)` and `init(mlModel:)` throw a clear error (tested) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
14 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`convenience init(contentsOfURL: URL) throws`](https://developer.apple.com/documentation/naturallanguage/nlembedding/init(contentsofurl:))
- [`convenience init(contentsOfURL: URL) throws`](https://developer.apple.com/documentation/naturallanguage/nlgazetteer/init(contentsofurl:)-13iyg)
- [`init(contentsOfURL: URL) throws`](https://developer.apple.com/documentation/naturallanguage/nlgazetteer/init(contentsofurl:)-3inpk)
- [`convenience init(contentsOfURL: URL) throws`](https://developer.apple.com/documentation/naturallanguage/nlmodel/init(contentsofurl:))
- [`NLTagger.AssetsResult`](https://developer.apple.com/documentation/naturallanguage/nltagger/assetsresult)
- [`case available`](https://developer.apple.com/documentation/naturallanguage/nltagger/assetsresult/available)
- [`case error`](https://developer.apple.com/documentation/naturallanguage/nltagger/assetsresult/error)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/naturallanguage/nltagger/assetsresult/init(rawvalue:))
- [`case notAvailable`](https://developer.apple.com/documentation/naturallanguage/nltagger/assetsresult/notavailable)
- [`func models(forTagScheme: NLTagScheme) -> [NLModel]`](https://developer.apple.com/documentation/naturallanguage/nltagger/models(fortagscheme:))
- [`class func requestAssets(for: NLLanguage, tagScheme: NLTagScheme, completionHandler: (NLTagger.AssetsResult, (any Error)?) -> Void)`](https://developer.apple.com/documentation/naturallanguage/nltagger/requestassets(for:tagscheme:completionhandler:))
- [`func setModels([NLModel], forTagScheme: NLTagScheme)`](https://developer.apple.com/documentation/naturallanguage/nltagger/setmodels(_:fortagscheme:))
- [`func setOrthography(NSOrthography, range: Range<String.Index>)`](https://developer.apple.com/documentation/naturallanguage/nltagger/setorthography(_:range:))
- [`func tokenRange(for: Range<String.Index>, unit: NLTokenUnit) -> Range<String.Index>`](https://developer.apple.com/documentation/naturallanguage/nltagger/tokenrange(for:unit:))

</details>
<!-- /generated:missing -->
