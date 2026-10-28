# Speech

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 94.0% of Apple's iOS API (423 of 450, exact) · **Rows:** 9: 4 ✅ 4 🟡 1 ❌ · **iOS:** 10.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [Speech](https://developer.apple.com/documentation/speech) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Passthrough** to whisper.cpp or Vosk when installed (`ISIM_WHISPER_MODEL`, `ISIM_VOSK_MODEL`); otherwise unavailable.
- **SpeechAnalyzer** (iOS 26) runs on the same engines: isim finalizes stretches of audio and hands each to the engine, so
  every result is final. Contextual strings and custom language models bias whisper.cpp through its prompt.
- **Swift only:** the Objective-C interface (`<Speech/Speech.h>`) is not there yet (#700).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Speech `SFSpeechRecognizer` (authorization, URL and buffer requests, tasks, transcriptions) | 🟡 | ≤17 | permission alert tested; recognition passthrough to whisper.cpp (`ISIM_WHISPER_MODEL`) or Vosk (`ISIM_VOSK_MODEL`) when installed, one final result; `contextualStrings` and `customizedLanguageModel` become whisper.cpp's prompt (tested with a stand-in whisper-cli: SpeechTest); otherwise `isAvailable` is false and tasks fail with a clear error (tested) |
| `SpeechAnalyzer`, `AnalyzerInput`, `AnalysisContext`, `SpeechModule`, `SpeechModuleResult`, `LocaleDependentSpeechModule` | ✅ | 26.0 | adapted: the analyzer converts input of any PCM format to 16 kHz mono and finalizes stretches of it (`finalize(through:)`, the end of input, or a pause once 6 s are buffered, at most 25 s), each handed to its modules in order; input sequences and audio files (`start`, `analyzeSequence`, the `init(inputSequence:…)` / `init(inputAudioFile:…)` initializers), the finish and cancel calls, `cancelAnalysis(before:)`, the volatile range (the audio not finalized yet) and its handler, `bestAvailableAudioFormat` (16 kHz mono 16-bit), `prepareToAnalyze`; out-of-order input throws `.audioDisordered`. Tested (SpeechTest: test_speech_analyzer) |
| `SpeechTranscriber`, `DictationTranscriber` (presets, options, content hints, results), `AttributeScopes.SpeechAttributes` | 🟡 | 26.0 | passthrough to the host's whisper.cpp (`ISIM_WHISPER_MODEL`) or Vosk (`ISIM_VOSK_MODEL`): one final result per engine segment, with `AttributedString` text and, with `.audioTimeRange`, a time range per word (spread evenly over the segment); `rangeOfAudioTimeRangeAttributes(intersecting:)`; contextual strings and `customizedLanguage(modelConfiguration:)` become whisper.cpp's prompt; `DictationTranscriber` drops punctuation unless `.punctuation` is set. Not done: volatile results (every result is final), alternatives, confidence, emoji and etiquette replacements. Without an engine `isAvailable` is false, `installedLocales` is empty and analysis throws `SFSpeechError.noModel` (tested: test_speech_analyzer_without_engine). Tested with a stand-in whisper-cli (SpeechTest) |
| `SpeechDetector` | ✅ | 26.0 | adapted: an energy-based voice-activity detector (20 ms frames; −30 / −40 / −50 dBFS for low / medium / high sensitivity; gaps under 300 ms bridged, bursts under 100 ms ignored); needs no engine. Tested (SpeechTest) |
| `AssetInventory`, `AssetInstallationRequest`, `SpeechModels` | 🟡 | 26.0 | adapted: isim cannot download Apple's models, so the host's engine is the model: status is `.installed` with an engine, `.supported` without one (then `downloadAndInstall()` throws `.noModel` naming whisper.cpp), `.unsupported` for other locales; locale reservations (at most 4, kept for the process); `endRetention()` does nothing. Tested (SpeechTest) |
| `AnalyzerInputConverter`, `AssetInputSequenceProvider`, `CaptureInputSequenceProvider`, `AnalyzerInput.bufferDuration` / `bufferFormat`, `Options(…ignoresResourceLimits:)` | ✅ | 27.0 | adapted: the converter mixes and resamples into the analyzer's format with isim's own code (the configuration handler gets an AVAudioConverter between the formats); assets are read with AVAssetReader as linear PCM; capture adds an AVCaptureAudioDataOutput to the session and starts it when the inputs are first read. Tested (SpeechTest, iOS 27) |
| `SFCustomLanguageModelData` (phrase counts, templates, pronunciations, builders), `SFSpeechLanguageModel`, `SFSpeechLanguageModel.Configuration`, `SFSpeechRecognitionRequest.customizedLanguageModel` | 🟡 | ≤17 | adapted: `export(to:)` writes isim's JSON (phrases with templates expanded, pronunciations), `prepareCustomLanguageModel` writes the model (phrases by weight) and the vocabulary (terms), and recognition with it puts the terms and leading phrases in whisper.cpp's prompt (Vosk ignores it). Phonemes are kept but not used. Tested (SpeechTest) |
| `SFSpeechError`, `SFSpeechError.Code` | ✅ | ≤17 | the iOS 17 codes keep Apple's raw values; the iOS 26/27 codes (`noModel`, `audioDisordered`, …) use isim's; `catch SFSpeechError.noModel` matches. Tested (SpeechTest) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `SFAcousticFeature`, `SFSpeechRecognitionMetadata`, `SFVoiceAnalytics` (3 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
27 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`SFAcousticFeature`](https://developer.apple.com/documentation/speech/sfacousticfeature)
- [`SFAcousticFeature`](https://developer.apple.com/documentation/speech/sfacousticfeature)
- [`var acousticFeatureValuePerFrame: [Double]`](https://developer.apple.com/documentation/speech/sfacousticfeature/acousticfeaturevalueperframe-5krkk)
- [`var acousticFeatureValuePerFrame: [Double]`](https://developer.apple.com/documentation/speech/sfacousticfeature/acousticfeaturevalueperframe-5krkk)
- [`var frameDuration: TimeInterval`](https://developer.apple.com/documentation/speech/sfacousticfeature/frameduration)
- [`var frameDuration: TimeInterval`](https://developer.apple.com/documentation/speech/sfacousticfeature/frameduration)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sfacousticfeature/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sfacousticfeature/init(coder:))
- [`SFSpeechRecognitionMetadata`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata)
- [`var averagePauseDuration: TimeInterval`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata/averagepauseduration)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata/init(coder:))
- [`var speakingRate: Double`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata/speakingrate)
- [`var speechDuration: TimeInterval`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata/speechduration)
- [`var speechStartTimestamp: TimeInterval`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata/speechstarttimestamp)
- [`var voiceAnalytics: SFVoiceAnalytics?`](https://developer.apple.com/documentation/speech/sfspeechrecognitionmetadata/voiceanalytics)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sfspeechrecognitionresult/init(coder:))
- [`var speechRecognitionMetadata: SFSpeechRecognitionMetadata?`](https://developer.apple.com/documentation/speech/sfspeechrecognitionresult/speechrecognitionmetadata)
- [`func speechRecognitionTask(SFSpeechRecognitionTask, didProcessAudioDuration: TimeInterval)`](https://developer.apple.com/documentation/speech/sfspeechrecognitiontaskdelegate/speechrecognitiontask(_:didprocessaudioduration:))
- [`func speechRecognitionTask(SFSpeechRecognitionTask, didProcessAudioDuration: TimeInterval)`](https://developer.apple.com/documentation/speech/sfspeechrecognitiontaskdelegate/speechrecognitiontask(_:didprocessaudioduration:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sftranscription/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sftranscriptionsegment/init(coder:))
- [`SFVoiceAnalytics`](https://developer.apple.com/documentation/speech/sfvoiceanalytics)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/speech/sfvoiceanalytics/init(coder:))
- [`var jitter: SFAcousticFeature`](https://developer.apple.com/documentation/speech/sfvoiceanalytics/jitter)
- [`var pitch: SFAcousticFeature`](https://developer.apple.com/documentation/speech/sfvoiceanalytics/pitch)
- [`var shimmer: SFAcousticFeature`](https://developer.apple.com/documentation/speech/sfvoiceanalytics/shimmer)
- [`var voicing: SFAcousticFeature`](https://developer.apple.com/documentation/speech/sfvoiceanalytics/voicing)

</details>
<!-- /generated:missing -->
