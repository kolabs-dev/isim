# Translation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (68 of 68, exact) · **Rows:** 7: 3 ✅ 4 🟡 · **iOS:** 17.4+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [Translation](https://developer.apple.com/documentation/translation) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Approach:** passthrough to a LibreTranslate-compatible server on the host (`isim/swift/overlays/Translation`).
  - Set `ISIM_TRANSLATE_URL` to the server; `ISIM_TRANSLATE_API_KEY` if it wants a key ([SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)).
    [LibreTranslate](https://github.com/LibreTranslate/LibreTranslate) translates offline with Argos Translate's
    models.
  - The server's `/languages` are the installed pairs, fetched once per app. `/translate` translates (a batch in one
    request) and `/detect` identifies the language of a session or a check without a source language.
  - A session or a sheet without a target translates into the user's first preferred language.
  - Without a server no pair is supported: `LanguageAvailability` says `.unsupported`, and requests throw
    `unsupportedLanguagePairing` with the reason (`failureReason`).
  - Languages are not downloaded: a pair is installed when the server has it, else unsupported (never `.supported`).
- **Objective-C / C interface:** Swift only (as on iOS).
- **Versus Apple's Simulator:**
  - The translations are the host engine's, not Apple's models; both strategies use the same engine.
  - Attributed strings are translated as plain text: the translation has no attributes.
  - The translation sheet shows the text, its translation, Replace and Copy; it opens at full height, and has no
    language picker, Favorites or "Open in Translate".

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `TranslationSession` (`sourceLanguage`, `targetLanguage`, `translate(_:)` for `String` and `AttributedString`, `translations(from:)`, `translate(batch:)`, `prepareTranslation()`), `Request`, `Response`, `BatchResponse` | 🟡 | 18.0 | passthrough to the host server; client identifiers come back in the responses; `prepareTranslation` checks the pair (nothing to download); tested (HelloTranslation, test_translation, against a scripted server) |
| `TranslationSession.Configuration` (`source`, `target`, `version`, `invalidate()`), `View.translationTask(_:action:)`, `translationTask(source:target:action:)` | ✅ | 18.0 | adapted: the task runs when the view appears and whenever the configuration changes; tested (HelloTranslation: `invalidate()` runs it again) |
| `TranslationSession(installedSource:target:)`, `isReady`, `canRequestDownloads`, `cancel()` | ✅ | 26.0 | adapted: ready when the server has the pair; sessions from a view's task can request downloads, the others cannot; after `cancel()` requests throw `alreadyCancelled`; tested (HelloTranslation) |
| `TranslationSession.Strategy` (`highFidelity`, `lowLatency`), `preferredStrategy`, `init(installedSource:target:preferredStrategy:)`, `Configuration(source:target:preferredStrategy:)`, `translationTask(source:target:preferredStrategy:action:)`, `LanguageAvailability(preferredStrategy:)` | 🟡 | 26.4 | adapted: recorded; the host engine has one model for both |
| `LanguageAvailability` (`supportedLanguages`, `status(from:to:)`, `status(for:to:)`, `Status`) | 🟡 | 18.0 | passthrough: the server's languages; a pair it has is `.installed`, any other `.unsupported` (no downloads); `status(for:to:)` detects the text's language; tested (HelloTranslation, with and without a server) |
| `TranslationError` (`nothingToTranslate`, `unableToIdentifyLanguage`, `internalError`, `alreadyCancelled`, `notInstalled`, `unsupportedSourceLanguage`, `unsupportedTargetLanguage`, `unsupportedLanguagePairing`, `errorDescription`, `failureReason`, `~=`) | ✅ | 18.0 | adapted: server failures are `internalError` with the server's message as the reason; tested (HelloTranslation) |
| `View.translationPresentation(isPresented:text:attachmentAnchor:arrowEdge:replacementAction:)` | 🟡 | 17.4 | adapted: a sheet (a popover on iPad) with the text and its language, the translation into the user's language, Replace with Translation (with a replacement action) and Copy Translation; "Translation Unavailable" and the reason without a server; tested (HelloTranslation: replace; without a server, every iOS version) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
