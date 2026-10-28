# SoundAnalysis

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (72 of 72, exact) · **Rows:** 6: 4 ✅ 1 🟡 1 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [SoundAnalysis](https://developer.apple.com/documentation/soundanalysis) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Approach:** isim's Swift overlay (`isim/swift/overlays/SoundAnalysis`) over an ONNX audio classifier, which the
  host's ONNX Runtime runs (`isim/runtime/host_sound.c`, loaded with dlopen only when an app classifies sounds).
  - `ISIM_SOUND_MODEL`: [YAMNet](https://github.com/tensorflow/models/tree/master/research/audioset/yamnet)'s ONNX
    export, or any model with its interface (a 16 kHz mono waveform in, class scores out).
  - `ISIM_SOUND_LABELS`: the labels, a class map CSV with a `display_name` column (YAMNet's) or one label per line;
    by default `<model>.csv`, `<model>.txt` or `yamnet_class_map.csv` next to the model.
  - `ISIM_ONNXRUNTIME`: the ONNX Runtime library, when it is not the host's `libonnxruntime` (for example the
    `onnxruntime` Python package's `capi/libonnxruntime.so.*`). See [SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md).
  - The audio is mixed to mono and resampled to 16 kHz (linear). Each window is classified on its own; its
    scores are the model's frame scores averaged.
  - Without a model, `SNClassifySoundRequest(classifierIdentifier:)` throws `SNError.operationFailed` and says why.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/SoundAnalysis` over the overlay's
  classes; `isim/frameworks/SoundAnalysis/SoundAnalysis.m` has the constants, `SNTimeDurationConstraint` and the
  `CMTime` properties.
- **Versus Apple's Simulator:**
  - The labels are the model's: YAMNet's 521 AudioSet classes, written as Apple writes its identifiers ("Speech" →
    `speech`, "Dog" → `dog`). Apple's classifier has its own 300 labels.
  - The confidences are the model's scores.
  - The window can be 0.975 s (one YAMNet patch, the default) to 15 s.
  - Core ML sound classifiers (`init(mlModel:)`) are not supported: isim's Core ML runs no neural networks.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SNClassifySoundRequest` (`init(classifierIdentifier:)` with `SNClassifierIdentifier.version1`, `knownClassifications`, `windowDuration`, `windowDurationConstraint`, `overlapFactor`) | 🟡 | ≤17 | adapted: the host's ONNX classifier and its labels (above); windows from 0.975 s to 15 s, overlap 0 ..< 1; tested (SoundAnalysisTest, HelloSoundAnalysis: test_soundanalysis, with a test model with YAMNet's interface; YAMNet itself is unverified, not on the test host) |
| `SNClassifySoundRequest(mlModel:)` | ❌ | ≤17 | stub: throws `SNError.invalidModel` (isim's Core ML cannot run sound classifiers) |
| `SNAudioStreamAnalyzer` (`init(format:)`, `add(_:withObserver:)`, `remove(_:)`, `removeAllRequests()`, `analyze(_:atAudioFramePosition:)`, `completeAnalysis()`) | ✅ | ≤17 | adapted: Float32, Int16 and Int32 buffers, any rate and channel count; buffers taken as contiguous; observers are called on the analyzer's queue; `completeAnalysis` classifies a last, padded window when a request has none yet; tested (SoundAnalysisTest, HelloSoundAnalysis) |
| `SNAudioFileAnalyzer` (`init(url:)`, `add`, `remove`, `analyze()`, `analyze(completionHandler:)`, `cancelAnalysis()`) | ✅ | ≤17 | adapted: the file through AVAudioFile; `invalidFile` for a file that is not audio; tested (SoundAnalysisTest, HelloSoundAnalysis: cancelled before the end, the handler gets false) |
| `SNClassificationResult` (`classifications`, `timeRange`, `classification(forIdentifier:)`), `SNClassification` (`identifier`, `confidence`), `SNResultsObserving`, `SNRequest`, `SNResult` | ✅ | ≤17 | adapted: every label, the most confident first; the time range in the input's sample rate; tested (SoundAnalysisTest) |
| `SNTimeDurationConstraint` (Swift enum; Objective-C class with `type`, `enumeratedDurations`, `durationRange`), `SNError` / `SNErrorDomain` / `SNErrorCode` | ✅ | ≤17 | adapted; tested (SoundAnalysisTest, HelloSoundAnalysis) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
