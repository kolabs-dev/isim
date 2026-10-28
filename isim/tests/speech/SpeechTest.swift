// Speech, iOS 26/27 (SpeechTest.app, issue #377): SpeechAnalyzer with SpeechTranscriber, DictationTranscriber and
// SpeechDetector over files, input sequences and iOS 27's providers; AssetInventory; custom language models;
// SFSpeechError. test_speech.py runs it twice:
// - with a stand-in whisper-cli (fake-whisper-cli: one segment naming the language, then the prompt);
// - with no engine, where the transcribers are unavailable and analysis fails with SFSpeechError.noModel.
import Foundation
import AVFoundation
import Speech

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func near(_ a: Double, _ b: Double, _ tol: Double) -> Bool { abs(a - b) <= tol }

/// tone bursts standing in for speech: (start, end) seconds of a 220 Hz tone, silence elsewhere
func signal(_ bursts: [(Double, Double)], length: Double, rate: Double) -> [Float] {
    (0..<Int(length * rate)).map { i in
        let t = Double(i) / rate
        return bursts.contains { t >= $0.0 && t < $0.1 } ? Float(0.3 * sin(2 * .pi * 220 * t)) : 0
    }
}
func floatBuffer(_ x: [Float], rate: Double, channels: AVAudioChannelCount = 1) -> AVAudioPCMBuffer {
    let f = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
    let b = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: AVAudioFrameCount(x.count))!
    b.frameLength = AVAudioFrameCount(x.count)
    for c in 0..<Int(channels) { for i in 0..<x.count { b.floatChannelData![c][i] = x[i] } }
    return b
}
func int16Buffer(_ x: [Float]) -> AVAudioPCMBuffer {
    let f = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    let b = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: AVAudioFrameCount(x.count))!
    b.frameLength = AVAudioFrameCount(x.count)
    for i in 0..<x.count { b.int16ChannelData![0][i] = Int16(x[i] * 32767) }
    return b
}
/// a 3.5 s WAV file at 44.1 kHz: bursts at 0–1.5 s and 2–3 s
func wavFile() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("speech.wav")
    try? FileManager.default.removeItem(at: url)
    let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100,
                                                          AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16])
    try file.write(from: floatBuffer(signal([(0, 1.5), (2, 3)], length: 3.5, rate: 44100), rate: 44100))
    return url
}
func collect<S: AsyncSequence & Sendable>(_ s: S) -> Task<[S.Element], Error> where S.Element: Sendable {
    Task { var a: [S.Element] = []; for try await x in s { a.append(x) }; return a }
}
func text(_ s: AttributedString) -> String { String(s.characters) }

@main enum SpeechTest {
    static func main() async {
        guard #available(iOS 26.0, *) else { print("SpeechTest: needs iOS 26"); exit(1) }
        do {
            if SpeechTranscriber.isAvailable { try await withEngine() } else { try await withoutEngine() }
            try await languageModels()
            errors()
        } catch { failures += 1; print("FAIL  threw \(error)") }
        print("SpeechTest: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }

    @available(iOS 26.0, *)
    static func withEngine() async throws {
        print("engine: available")
        // locales and assets
        let gb = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB"))
        let fr = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "fr"))
        let xx = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "xx-YY"))
        check(gb?.identifier == "en_GB" && fr?.identifier == "fr_FR" && xx == nil, "supportedLocale(equivalentTo:)")
        check(!SpeechTranscriber.installedLocales.isEmpty && DictationTranscriber.supportedLocales.count == SpeechTranscriber.supportedLocales.count,
              "installed and supported locales")
        let en = Locale(identifier: "en_US")
        let probe = SpeechTranscriber(locale: en, preset: .transcription)
        let status = await AssetInventory.status(forModules: [probe])
        let request = try await AssetInventory.assetInstallationRequest(supporting: [probe])
        check(status == .installed && request == nil, "AssetInventory: installed, no installation request")
        let unsupported = await AssetInventory.status(forModules: [SpeechTranscriber(locale: Locale(identifier: "xx_YY"), preset: .transcription)])
        check(unsupported == .unsupported && AssetInventory.Status.supported < .installed, "AssetInventory: unsupported locale, status order")
        let r1 = try await AssetInventory.reserve(locale: en), r2 = try await AssetInventory.reserve(locale: en)
        let reserved = AssetInventory.reservedLocales
        let released = await AssetInventory.release(reservedLocale: en)
        check(r1 && !r2 && reserved.map(\.identifier) == ["en_US"] && released && AssetInventory.reservedLocales.isEmpty, "reserve and release locales")
        let best = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [probe])
        check(best?.sampleRate == 16000 && best?.channelCount == 1 && probe.availableCompatibleAudioFormats.first?.sampleRate == 16000,
              "bestAvailableAudioFormat: 16 kHz mono")

        // a file: transcriber (time-indexed) and detector, with contextual strings
        let transcriber = SpeechTranscriber(locale: en, preset: .timeIndexedTranscriptionWithAlternatives)
        let detector = SpeechDetector(detectionOptions: .init(sensitivityLevel: .medium), reportResults: true)
        let analyzer = SpeechAnalyzer(modules: [transcriber, detector])
        let ctx = AnalysisContext()
        ctx.contextualStrings[.general] = ["isim", "SpeechAnalyzer"]
        try await analyzer.setContext(ctx)
        try await analyzer.prepareToAnalyze(in: best)
        let tr = collect(transcriber.results), dr = collect(detector.results)
        let file = try AVAudioFile(forReading: try wavFile())
        let end = try await analyzer.analyzeSequence(from: file)
        check(end.map { near($0.seconds, 3.5, 0.01) } ?? false, "analyzeSequence(from:) returns the end of the audio (\(end?.seconds ?? -1))")
        try await analyzer.finalizeAndFinish(through: end!)
        let results = try await tr.value
        let texts = results.map { text($0.text) }
        print("transcriber: \(texts)")
        check(texts.first == "Hello, isim world (en)." && results.allSatisfy(\.isFinal), "SpeechTranscriber: final results from the engine")
        check(texts.contains("prompt: isim, SpeechAnalyzer"), "contextual strings reach the engine's prompt")
        if let first = results.first {
            check(near(first.range.start.seconds, 0, 0.01) && near(first.range.end.seconds, 3.5, 0.01), "result time range")
            let ranges = first.text.runs.compactMap { $0.audioTimeRange }
            check(ranges.count == 4 && near(ranges[0].start.seconds, 0, 0.01) && near(ranges[3].end.seconds, 3.5, 0.01), "audioTimeRange attributes per word")
            let hit = first.text.rangeOfAudioTimeRangeAttributes(intersecting: CMTimeRange(start: CMTime(seconds: 1.0, preferredTimescale: 1000),
                                                                                           duration: CMTime(seconds: 0.2, preferredTimescale: 1000)))
            check(hit.map { String(first.text[$0].characters) } == "isim", "rangeOfAudioTimeRangeAttributes(intersecting:)")
        }
        let speech = try await dr.value
        let runs = speech.map { "\(String(format: "%.1f", $0.range.start.seconds))-\(String(format: "%.1f", $0.range.end.seconds)):\($0.speechDetected)" }
        print("detector: \(runs)")
        check(runs == ["0.0-1.5:true", "1.5-2.0:false", "2.0-3.0:true", "3.0-3.5:false"], "SpeechDetector: speech and silence")
        let volatile = await analyzer.volatileRange
        check(volatile == nil, "no volatile range once finished")
        do { _ = try await analyzer.analyzeSequence(from: file); check(false, "a finished analyzer refuses input") }
        catch { check(true, "a finished analyzer refuses input") }

        // an input sequence: dictation (no punctuation), finalized at a pause and at the end of input
        let dictation = DictationTranscriber(locale: Locale(identifier: "de_DE"), preset: .phrase)
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let changes = Counter()
        let live = SpeechAnalyzer(modules: [dictation])
        live.setVolatileRangeChangedHandler { _, _, _ in changes.add() }
        let dc = collect(dictation.results)
        try await live.start(inputSequence: stream)
        let audio = signal([(0, 7), (8, 11)], length: 11, rate: 16000)
        for k in Swift.stride(from: 0, to: audio.count, by: 1600) { input.yield(AnalyzerInput(buffer: int16Buffer(Array(audio[k..<min(k + 1600, audio.count)])))) }
        input.finish()
        try await live.finalizeAndFinishThroughEndOfInput()
        let dictated = try await dc.value
        print("dictation: \(dictated.map { "\(text($0.text)) @\(String(format: "%.1f", $0.range.start.seconds))" })")
        check(dictated.count == 2 && dictated.allSatisfy { text($0.text) == "hello isim world de" }, "DictationTranscriber: words without punctuation")
        check(dictated.count == 2 && near(dictated[1].range.start.seconds, 7.5, 0.5) && near(dictated[1].range.end.seconds, 11, 0.05),
              "audio is finalized at a pause, then at the end of input")
        check(changes.value > 0, "volatile range changed handler")

        // cancelling
        let cancelled = SpeechTranscriber(locale: en, preset: .transcription)
        let ca = SpeechAnalyzer(modules: [cancelled])
        let cr = collect(cancelled.results)
        let (s2, i2) = AsyncStream<AnalyzerInput>.makeStream()
        try await ca.start(inputSequence: s2)
        i2.yield(AnalyzerInput(buffer: int16Buffer(signal([(0, 1)], length: 1, rate: 16000))))
        await ca.cancelAndFinishNow()
        let none = try await cr.value
        check(none.isEmpty, "cancelAndFinishNow ends the results without any")

        // the convenience initializer with a file
        let ft = SpeechTranscriber(locale: Locale(identifier: "fr_FR"), preset: .transcription)
        let fresults = collect(ft.results)
        _ = try await SpeechAnalyzer(inputAudioFile: AVAudioFile(forReading: try wavFile()), modules: [ft], finishAfterFile: true)
        let ftexts = try await fresults.value.map { text($0.text) }
        check(ftexts == ["Hello, isim world (fr)."], "init(inputAudioFile:modules:finishAfterFile:)")

        if #available(iOS 27.0, *) { try await providers() }
        try await recognizer()
    }

    @available(iOS 27.0, *)
    static func providers() async throws {
        let t = SpeechTranscriber(locale: Locale(identifier: "en_US"), preset: .transcription)
        let converter = try await AnalyzerInputConverter.converter(compatibleWith: [t])
        let stereo = floatBuffer(signal([(0, 1)], length: 1, rate: 48000), rate: 48000, channels: 2)
        let converted = try converter.convert(stereo, at: AVAudioTime(sampleTime: 48000, atRate: 48000))
        check(converted.count == 1 && converted[0].bufferFormat.sampleRate == 16000 && converted[0].bufferFormat.channelCount == 1
              && converted[0].bufferFormat.commonFormat == .pcmFormatInt16 && near(converted[0].bufferDuration.seconds, 1, 0.01)
              && converted[0].bufferStartTime.map { near($0.seconds, 1, 0.001) } == true, "AnalyzerInputConverter: 16 kHz mono 16-bit")
        let asset = AVURLAsset(url: try wavFile())
        let provider = try await AssetInputSequenceProvider.provider(from: asset, compatibleWith: [t], priority: nil)
        var total = 0.0
        for try await i in provider.analyzerInputs { total += i.bufferDuration.seconds }
        check(near(total, 3.5, 0.05), "AssetInputSequenceProvider reads the asset's audio (\(total) s)")
        let analyzer = SpeechAnalyzer(modules: [t])
        let r = collect(t.results)
        let end = try await analyzer.analyzeSequence(provider.analyzerInputs)
        try await analyzer.finalizeAndFinish(through: end ?? .zero)
        let atexts = try await r.value.map { text($0.text) }
        check(atexts == ["Hello, isim world (en)."], "analysis of an asset provider's inputs")
        if let mic = AVCaptureDevice.default(for: .audio) {
            let capture = try await CaptureInputSequenceProvider.providerWithSession(from: mic, compatibleWith: [t], priority: nil)
            check(capture.captureSession.outputs.contains(capture.captureAudioDataOutput) && capture.captureSession.inputs.count == 1,
                  "CaptureInputSequenceProvider: a session with the microphone and an audio data output")
        }
        let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering, ignoresResourceLimits: true)
        check(options.ignoresResourceLimits && options.modelRetention == .lingering, "Options (iOS 27)")
    }

    /// SFSpeechRecognizer with contextual strings and a custom language model
    @available(iOS 26.0, *)
    static func recognizer() async throws {
        let status = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
        check(status == .authorized, "speech recognition authorized")
        let req = SFSpeechURLRecognitionRequest(url: try wavFile())
        req.contextualStrings = ["Liquid Glass"]
        req.customizedLanguageModel = try await preparedModel()
        let text = await withCheckedContinuation { (c: CheckedContinuation<String, Never>) in
            var done = false
            _ = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))!.recognitionTask(with: req) { r, e in
                guard !done, e != nil || r?.isFinal == true else { return }
                done = true
                c.resume(returning: r?.bestTranscription.formattedString ?? "error \(e!)")
            }
        }
        print("recognizer: \(text)")
        check(text.contains("prompt: Liquid Glass, isim, open the pod bay doors"), "SFSpeechRecognitionRequest: contextual strings, then the custom model")
    }

    static func preparedModel() async throws -> SFSpeechLanguageModel.Configuration {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        let data = SFCustomLanguageModelData(locale: Locale(identifier: "en_US"), identifier: "dev.isim.speech-test", version: "1.0") {
            SFCustomLanguageModelData.PhraseCount(phrase: "open the pod bay doors", count: 10)
            SFCustomLanguageModelData.PhraseCountsFromTemplates(classes: ["planet": ["Mars", "Venus"]]) {
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("fly to <planet>", count: 5)
            }
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "isim", phonemes: ["aI", "s", "I", "m"])
        }
        let asset = dir.appendingPathComponent("model.bin")
        try await data.export(to: asset)
        let config = SFSpeechLanguageModel.Configuration(languageModel: dir.appendingPathComponent("model.lm"), vocabulary: dir.appendingPathComponent("model.vocab"))
        try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: asset, configuration: config, ignoresCache: true)
        return config
    }

    static func languageModels() async throws {
        let config = try await preparedModel()
        let lm = try String(contentsOf: config.languageModel, encoding: .utf8), vocab = try String(contentsOf: config.vocabulary!, encoding: .utf8)
        check(lm == "open the pod bay doors\nfly to Mars\nfly to Venus\n" && vocab == "isim\n", "custom language model: phrases by weight, vocabulary")
        let done = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechLanguageModel.prepareCustomLanguageModel(for: URL(fileURLWithPath: "/nonexistent"), configuration: config) { e in
                c.resume(returning: (e as NSError?)?.domain == SFSpeechErrorDomain)
            }
        }
        check(done, "prepareCustomLanguageModel reports missing data")
        let g = SFCustomLanguageModelData.TemplatePhraseCountGenerator()
        g.insert(template: "call <nobody>", count: 1)
        do { for try await _ in g {}; check(false, "an undefined template class throws") }
        catch let e as SFSpeechError { check(e.code == .undefinedTemplateClassName, "an undefined template class throws") }
        if #available(iOS 26.0, *) {
            let hinted = DictationTranscriber(locale: Locale(identifier: "en_US"), contentHints: [.customizedLanguage(modelConfiguration: config)],
                                              transcriptionOptions: [.punctuation], reportingOptions: [], attributeOptions: [])
            check(hinted.contentHints.count == 1 && hinted.selectedLocales.map(\.identifier) == ["en_US"], "DictationTranscriber content hints")
            if SpeechTranscriber.isAvailable {
                let a = SpeechAnalyzer(modules: [hinted])
                let r = collect(hinted.results)
                let end = try await a.analyzeSequence(from: AVAudioFile(forReading: try wavFile()))
                try await a.finalizeAndFinish(through: end!)
                let texts = try await r.value.map { text($0.text) }
                check(texts == ["Hello, isim world (en).", "prompt: isim, open the pod bay doors, fly to Mars, fly to Venus"],
                      "customizedLanguage(modelConfiguration:) biases dictation")
            }
        }
    }

    @available(iOS 26.0, *)
    static func withoutEngine() async throws {
        print("engine: none")
        let en = Locale(identifier: "en_US")
        let t = SpeechTranscriber(locale: en, preset: .transcription)
        check(SpeechTranscriber.installedLocales.isEmpty && !SpeechTranscriber.supportedLocales.isEmpty, "no installed locales without an engine")
        let status = await AssetInventory.status(forModules: [t])
        check(status == .supported, "AssetInventory: supported, not installed")
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [t]) {
            do { try await request.downloadAndInstall(); check(false, "downloadAndInstall fails without an engine") }
            catch SFSpeechError.noModel { check(true, "downloadAndInstall fails without an engine") }
        } else { check(false, "an installation request") }
        let analyzer = SpeechAnalyzer(modules: [t])
        do { _ = try await analyzer.analyzeSequence(from: AVAudioFile(forReading: try wavFile())); check(false, "analysis throws noModel") }
        catch let e as SFSpeechError { check(e.code == .noModel && e.localizedDescription.contains("whisper.cpp"), "analysis throws noModel") }
        // the detector needs no engine
        let detector = SpeechDetector(detectionOptions: .init(sensitivityLevel: .high), reportResults: true)
        let ds = await AssetInventory.status(forModules: [detector])
        let a = SpeechAnalyzer(modules: [detector])
        let r = collect(detector.results)
        let end = try await a.analyzeSequence(from: AVAudioFile(forReading: try wavFile()))
        try await a.finalizeAndFinish(through: end!)
        let speech = try await r.value.filter(\.speechDetected).count
        check(ds == .installed && speech == 2, "SpeechDetector works without an engine")
    }

    static func errors() {
        let e = SFSpeechError(.audioDisordered)
        check(SFSpeechError.errorDomain == "SFSpeechErrorDomain" && (e as NSError).domain == SFSpeechErrorDomain && (e as NSError).code == e.code.rawValue,
              "SFSpeechError bridges to NSError")
        var matched = false
        do { throw SFSpeechError(.timeout) } catch SFSpeechError.timeout { matched = true } catch {}
        check(matched && SFSpeechError.Code(rawValue: 1) == .internalServiceError, "SFSpeechError codes and patterns")
    }
}

final class Counter: @unchecked Sendable {
    let lock = NSLock(); var value = 0
    func add() { lock.lock(); value += 1; lock.unlock() }
}
