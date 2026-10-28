// isim Speech, iOS 26/27 (issue #377): SpeechAnalyzer and its modules (SpeechTranscriber, DictationTranscriber,
// SpeechDetector), AnalyzerInput, AnalysisContext, AssetInventory, SpeechModels, AttributedString's speech attributes,
// and iOS 27's input providers (AnalyzerInputConverter, AssetInputSequenceProvider, CaptureInputSequenceProvider).
// Transcription is passthrough to the host's speech-to-text engine (whisper.cpp or Vosk, see Speech.swift). The analyzer
// converts its input to 16 kHz mono and finalizes stretches of audio: at finalize(through:), at the end of input, or at
// a pause once several seconds are buffered (at most 25 s, whisper's window). Each stretch goes to the engine, so every
// result is final (no volatile results). Contextual strings and custom language models bias whisper.cpp through its
// prompt. SpeechDetector is adapted: an energy-based voice-activity detector. Without an engine, the transcribers'
// isAvailable is false, AssetInventory reports .supported, and analysis fails with SFSpeechError.noModel.
import Foundation
import AVFoundation
import isim_host

// MARK: - the engine and audio conversion

enum _SpeechEngine {
    static let rate = 16000.0
    static var available: Bool { isim_speech_available() != 0 }
    struct Segment { var start: Double; var end: Double; var text: String }
    /// the host's transcription of 16 kHz mono PCM: segments with times relative to its start (-1 when unknown), or nil
    static func transcribe(_ pcm: [Float], language: String, prompt: String?) async -> [Segment]? {
        guard !pcm.isEmpty else { return [] }
        return await withCheckedContinuation { (c: CheckedContinuation<[Segment]?, Never>) in
            DispatchQueue.global().async { c.resume(returning: transcribeNow(pcm, language: language, prompt: prompt)) }
        }
    }
    static func transcribeNow(_ pcm: [Float], language: String, prompt: String?) -> [Segment]? {
        let p = prompt.flatMap { $0.isEmpty ? nil : String($0.prefix(800)) }
        guard let raw = pcm.withUnsafeBufferPointer({ b in
            p.map { isim_speech_transcribe_prompt(b.baseAddress!, b.count, language, $0) } ?? isim_speech_transcribe_prompt(b.baseAddress!, b.count, language, nil)
        }) else { return nil }
        defer { isim_media_free(raw) }
        var out: [Segment] = []
        for line in String(cString: raw).split(separator: "\n") {
            let f = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard f.count == 3 else { continue }
            let text = f[2].trimmingCharacters(in: .whitespaces)
            // whisper.cpp's markers for non-speech ("[BLANK_AUDIO]", "(music)")
            if text.isEmpty || (text.hasPrefix("[") && text.hasSuffix("]")) || (text.hasPrefix("(") && text.hasSuffix(")")) { continue }
            out.append(Segment(start: Double(f[0]) ?? -1, end: Double(f[1]) ?? -1, text: text))
        }
        return out
    }
    /// the prompt that biases recognition: contextual strings, then a custom language model's phrases and terms
    static func prompt(_ strings: [String], model: SFSpeechLanguageModel.Configuration?) -> String? {
        var parts = strings.filter { !$0.isEmpty }
        if let model { parts += SFSpeechLanguageModel._promptPhrases(model) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

enum _SpeechAudio {
    /// the buffer's frames mixed to mono and resampled to 16 kHz
    static func mono16k(_ b: AVAudioPCMBuffer) -> [Float] {
        let n = Int(b.frameLength), ch = max(1, Int(b.format.channelCount)), inter = b.format.isInterleaved && ch > 1
        var mono = [Float](repeating: 0, count: n)
        func mix(_ get: (Int, Int) -> Float) { for i in 0..<n { var s: Float = 0; for c in 0..<ch { s += get(c, i) }; mono[i] = s / Float(ch) } }
        if let f = b.floatChannelData { mix { c, i in inter ? f[0][i * ch + c] : f[c][i] } }
        else if let f = b.int16ChannelData { mix { c, i in Float(inter ? f[0][i * ch + c] : f[c][i]) / 32768 } }
        else if let f = b.int32ChannelData { mix { c, i in Float(inter ? f[0][i * ch + c] : f[c][i]) / 2_147_483_648 } }
        return _SFResample.mono16k(mono, rate: b.format.sampleRate)
    }
    /// a PCM buffer of `format` (mono or not, Float32 / Int16 / Int32) holding 16 kHz mono samples resampled to its rate
    static func buffer(_ mono16k: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let r = format.sampleRate / _SpeechEngine.rate
        let n = r == 1 ? mono16k.count : Int(Double(mono16k.count) * r)
        guard n > 0, let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)) else { return nil }
        b.frameLength = AVAudioFrameCount(n)
        let ch = max(1, Int(format.channelCount)), inter = format.isInterleaved && ch > 1
        for i in 0..<n {
            let p = Double(i) / r, i0 = min(Int(p), mono16k.count - 1), i1 = min(i0 + 1, mono16k.count - 1), t = Float(p - Double(i0))
            let v = max(-1, min(1, mono16k[i0] + (mono16k[i1] - mono16k[i0]) * t))
            for c in 0..<ch {
                if let f = b.floatChannelData { if inter { f[0][i * ch + c] = v } else { f[c][i] = v } }
                else if let f = b.int16ChannelData { let s = Int16(v * 32767); if inter { f[0][i * ch + c] = s } else { f[c][i] = s } }
                else if let f = b.int32ChannelData { let s = Int32(Double(v) * 2_147_483_647); if inter { f[0][i * ch + c] = s } else { f[c][i] = s } }
            }
        }
        return b
    }
    /// linear PCM sample buffers (capture, asset readers) as Float32 buffers of their rate and channels
    static func buffer(_ sb: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let asbd = sb.formatDescription?.audioStreamBasicDescription, let data = sb.dataBuffer else { return nil }
        let ch = Int(max(1, asbd.mChannelsPerFrame)), bs = asbd._bytesPerSample, fb = asbd._frameBytes
        let n = fb > 0 ? data._bytes.count / fb : 0
        guard n > 0, let fmt = AVAudioFormat(standardFormatWithSampleRate: asbd.mSampleRate, channels: AVAudioChannelCount(ch)),
              let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n)), let out = b.floatChannelData else { return nil }
        b.frameLength = AVAudioFrameCount(n)
        data._bytes.withUnsafeBytes { raw in
            for i in 0..<n { for c in 0..<ch {
                let p = raw.baseAddress! + i * fb + c * bs
                out[c][i] = asbd._isFloat ? p.loadUnaligned(as: Float.self)
                    : bs == 2 ? Float(p.loadUnaligned(as: Int16.self)) / 32768 : Float(p.loadUnaligned(as: Int32.self)) / 2_147_483_648
            } }
        }
        return b
    }
    /// the format the analyzer works in: 16 kHz mono 16-bit PCM, like Apple's models
    static var analyzerFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: _SpeechEngine.rate, channels: 1, interleaved: true)!
    }
    static func seconds(_ t: CMTime) -> Double { t.seconds }
    static func time(_ s: Double) -> CMTime { CMTime(value: CMTimeValue((s * _SpeechEngine.rate).rounded()), timescale: CMTimeScale(_SpeechEngine.rate)) }
    static func range(_ a: Double, _ b: Double) -> CMTimeRange { CMTimeRange(start: time(a), end: time(max(a, b))) }
}

// MARK: - modules and results

@available(iOS 26.0, *)
public protocol SpeechModuleResult {
    var range: CMTimeRange { get }
    var resultsFinalizationTime: CMTime { get }
}
@available(iOS 26.0, *)
extension SpeechModuleResult {
    /// whether the result is final: the results are finalized through the end of its range
    public var isFinal: Bool { resultsFinalizationTime >= range.end }
}

@available(iOS 26.0, *)
public protocol SpeechModule: AnyObject, Sendable {
    associatedtype Result: SpeechModuleResult, Sendable
    associatedtype Results: AsyncSequence, Sendable where Results.Element == Result
    var results: Results { get }
    var availableCompatibleAudioFormats: [AVAudioFormat] { get }
}

@available(iOS 26.0, *)
public protocol LocaleDependentSpeechModule: SpeechModule {
    static var supportedLocales: [Locale] { get }
    static func supportedLocale(equivalentTo locale: Locale) async -> Locale?
    var selectedLocales: [Locale] { get }
}

/// what the analyzer drives: isim's own modules
@available(iOS 26.0, *)
protocol _SpeechModuleImpl: AnyObject {
    var _needsEngine: Bool { get }
    var _language: String? { get }
    /// a finalized stretch of 16 kHz mono audio starting at `start` seconds on the analysis timeline
    func _process(_ pcm: [Float], start: Double, context: AnalysisContext) async throws
    func _finish(_ error: Error?)
}

/// the locales isim's engines recognize (whisper.cpp's languages with their common regions)
enum _SpeechLocales {
    static let identifiers = ["en_US", "en_GB", "en_AU", "en_CA", "en_IN", "fr_FR", "fr_CA", "de_DE", "de_AT", "de_CH", "es_ES",
                              "es_MX", "es_US", "it_IT", "pt_BR", "pt_PT", "nl_NL", "sv_SE", "da_DK", "nb_NO", "fi_FI", "pl_PL",
                              "tr_TR", "ru_RU", "uk_UA", "ja_JP", "ko_KR", "zh_CN", "zh_TW", "zh_HK", "ar_SA", "he_IL", "hi_IN",
                              "ro_RO", "cs_CZ", "el_GR", "vi_VN", "th_TH", "id_ID", "ms_MY", "ca_ES", "hu_HU", "sk_SK", "hr_HR"]
    static var supported: [Locale] { identifiers.map { Locale(identifier: $0) } }
    static var installed: [Locale] { _SpeechEngine.available ? supported : [] }
    static func equivalent(_ l: Locale) -> Locale? {
        guard let lang = l.language.languageCode?.identifier else { return nil }
        let region = l.region?.identifier
        let same = identifiers.filter { $0.hasPrefix(lang + "_") }
        if let region, let m = same.first(where: { $0 == "\(lang)_\(region)" }) { return Locale(identifier: m) }
        return same.first.map { Locale(identifier: $0) }
    }
    static func language(_ l: Locale) -> String? { equivalent(l)?.language.languageCode?.identifier }
}

/// a module's results stream
final class _ResultChannel<R: Sendable>: @unchecked Sendable {
    let stream: AsyncThrowingStream<R, Error>
    let cont: AsyncThrowingStream<R, Error>.Continuation
    init() { (stream, cont) = AsyncThrowingStream<R, Error>.makeStream() }
}

/// a transcriber's results from the engine's segments: one result per segment, final through the end of the stretch
@available(iOS 26.0, *)
func _transcriptionResults(_ segs: [_SpeechEngine.Segment], start: Double, duration: Double, timeIndexed: Bool,
                           transform: (String) -> String) -> [(CMTimeRange, CMTime, AttributedString)] {
    let fin = _SpeechAudio.time(start + duration)
    var out: [(CMTimeRange, CMTime, AttributedString)] = []
    for (k, s) in segs.enumerated() {
        let text = transform(s.text)
        guard !text.isEmpty else { continue }
        // without times, the segments share the stretch evenly
        let a = s.start >= 0 ? s.start : duration * Double(k) / Double(segs.count)
        let b = s.start >= 0 && s.end > s.start ? min(s.end, duration) : duration * Double(k + 1) / Double(segs.count)
        var str = AttributedString()
        let words = text.split(separator: " ").map(String.init)
        let step = (b - a) / Double(max(1, words.count))
        for (i, w) in words.enumerated() {
            if i > 0 { str += AttributedString(" ") }
            var piece = AttributedString(w)
            if timeIndexed {
                piece[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] =
                    _SpeechAudio.range(start + a + step * Double(i), start + a + step * Double(i + 1))
            }
            str += piece
        }
        out.append((_SpeechAudio.range(start + a, start + max(a, b)), fin, str))
    }
    return out
}

@available(iOS 26.0, *)
public final class SpeechTranscriber: LocaleDependentSpeechModule, _SpeechModuleImpl, @unchecked Sendable {
    public enum TranscriptionOption: Hashable, Sendable { case etiquetteReplacements }
    public enum ReportingOption: Hashable, Sendable { case volatileResults, alternativeTranscriptions, fastResults }
    public enum ResultAttributeOption: Hashable, Sendable { case audioTimeRange, transcriptionConfidence }
    public struct Preset: Sendable {
        public var transcriptionOptions: Set<TranscriptionOption>
        public var reportingOptions: Set<ReportingOption>
        public var attributeOptions: Set<ResultAttributeOption>
        public init(transcriptionOptions: Set<TranscriptionOption>, reportingOptions: Set<ReportingOption>, attributeOptions: Set<ResultAttributeOption>) {
            self.transcriptionOptions = transcriptionOptions; self.reportingOptions = reportingOptions; self.attributeOptions = attributeOptions
        }
        public static let transcription = Preset(transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        public static let transcriptionWithAlternatives = Preset(transcriptionOptions: [], reportingOptions: [.alternativeTranscriptions], attributeOptions: [])
        public static let timeIndexedTranscriptionWithAlternatives = Preset(transcriptionOptions: [], reportingOptions: [.alternativeTranscriptions], attributeOptions: [.audioTimeRange])
        public static let progressiveTranscription = Preset(transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        public static let timeIndexedProgressiveTranscription = Preset(transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [.audioTimeRange])
    }
    public struct Result: SpeechModuleResult, Sendable, CustomStringConvertible {
        public var range: CMTimeRange
        public var resultsFinalizationTime: CMTime
        public var text: AttributedString
        public let alternatives: [AttributedString]
        public var description: String { String(text.characters) }
    }

    let locale: Locale
    public let transcriptionOptions: Set<TranscriptionOption>
    public let reportingOptions: Set<ReportingOption>
    public let attributeOptions: Set<ResultAttributeOption>
    let _channel = _ResultChannel<Result>()

    public convenience init(locale: Locale, preset: Preset) {
        self.init(locale: locale, transcriptionOptions: preset.transcriptionOptions, reportingOptions: preset.reportingOptions, attributeOptions: preset.attributeOptions)
    }
    public init(locale: Locale, transcriptionOptions: Set<TranscriptionOption>, reportingOptions: Set<ReportingOption>, attributeOptions: Set<ResultAttributeOption>) {
        self.locale = locale; self.transcriptionOptions = transcriptionOptions; self.reportingOptions = reportingOptions; self.attributeOptions = attributeOptions
    }

    /// isim: true when the host has a speech-to-text engine (whisper.cpp or Vosk)
    public static var isAvailable: Bool { _SpeechEngine.available }
    public static var supportedLocales: [Locale] { _SpeechLocales.supported }
    public static var installedLocales: [Locale] { _SpeechLocales.installed }
    public static func supportedLocale(equivalentTo locale: Locale) async -> Locale? { _SpeechLocales.equivalent(locale) }
    public var selectedLocales: [Locale] { _SpeechLocales.equivalent(locale).map { [$0] } ?? [] }
    public var availableCompatibleAudioFormats: [AVAudioFormat] { [_SpeechAudio.analyzerFormat] }
    public var results: some Sendable & AsyncSequence<Result, any Error> { _channel.stream }

    var _needsEngine: Bool { true }
    var _language: String? { _SpeechLocales.language(locale) }
    func _process(_ pcm: [Float], start: Double, context: AnalysisContext) async throws {
        guard let lang = _language else { throw SFSpeechError(.cannotAllocateUnsupportedLocale, "\(locale.identifier) is not a supported locale") }
        guard let segs = await _SpeechEngine.transcribe(pcm, language: lang, prompt: _SpeechEngine.prompt(context._allStrings, model: nil)) else {
            throw SFSpeechError(.moduleOutputFailed, "speech recognition failed: the host's speech-to-text engine did not run")
        }
        for (r, fin, text) in _transcriptionResults(segs, start: start, duration: Double(pcm.count) / _SpeechEngine.rate,
                                                    timeIndexed: attributeOptions.contains(.audioTimeRange), transform: { $0 }) {
            _channel.cont.yield(Result(range: r, resultsFinalizationTime: fin, text: text, alternatives: []))
        }
    }
    func _finish(_ error: Error?) { _channel.cont.finish(throwing: error) }
}

@available(iOS 26.0, *)
public final class DictationTranscriber: LocaleDependentSpeechModule, _SpeechModuleImpl, @unchecked Sendable {
    public struct ContentHint: Hashable, Sendable {
        let _kind: String
        let _model: SFSpeechLanguageModel.Configuration?
        public static let shortForm = ContentHint(_kind: "shortForm", _model: nil)
        public static let farField = ContentHint(_kind: "farField", _model: nil)
        public static let atypicalSpeech = ContentHint(_kind: "atypicalSpeech", _model: nil)
        /// biases recognition toward a custom language model (isim: its phrases become whisper.cpp's prompt)
        public static func customizedLanguage(modelConfiguration: SFSpeechLanguageModel.Configuration) -> ContentHint {
            ContentHint(_kind: "customizedLanguage", _model: modelConfiguration)
        }
    }
    public enum TranscriptionOption: Hashable, Sendable { case punctuation, emoji, etiquetteReplacements }
    public enum ReportingOption: Hashable, Sendable { case volatileResults, alternativeTranscriptions, frequentFinalization }
    public enum ResultAttributeOption: Hashable, Sendable { case audioTimeRange, transcriptionConfidence }
    public struct Preset: Sendable {
        public var contentHints: Set<ContentHint>
        public var transcriptionOptions: Set<TranscriptionOption>
        public var reportingOptions: Set<ReportingOption>
        public var attributeOptions: Set<ResultAttributeOption>
        public init(contentHints: Set<ContentHint>, transcriptionOptions: Set<TranscriptionOption>, reportingOptions: Set<ReportingOption>,
                    attributeOptions: Set<ResultAttributeOption>) {
            self.contentHints = contentHints; self.transcriptionOptions = transcriptionOptions
            self.reportingOptions = reportingOptions; self.attributeOptions = attributeOptions
        }
        public static let phrase = Preset(contentHints: [.shortForm], transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        public static let shortDictation = Preset(contentHints: [.shortForm], transcriptionOptions: [.punctuation], reportingOptions: [], attributeOptions: [])
        public static let progressiveShortDictation = Preset(contentHints: [.shortForm], transcriptionOptions: [.punctuation], reportingOptions: [.volatileResults], attributeOptions: [])
        public static let longDictation = Preset(contentHints: [], transcriptionOptions: [.punctuation], reportingOptions: [], attributeOptions: [])
        public static let progressiveLongDictation = Preset(contentHints: [], transcriptionOptions: [.punctuation], reportingOptions: [.volatileResults], attributeOptions: [])
        public static let timeIndexedLongDictation = Preset(contentHints: [], transcriptionOptions: [.punctuation], reportingOptions: [], attributeOptions: [.audioTimeRange])
    }
    public struct Result: SpeechModuleResult, Sendable, CustomStringConvertible {
        public var range: CMTimeRange
        public var resultsFinalizationTime: CMTime
        public var text: AttributedString
        public let alternatives: [AttributedString]
        public var description: String { String(text.characters) }
    }

    let locale: Locale
    public let contentHints: Set<ContentHint>
    public let transcriptionOptions: Set<TranscriptionOption>
    public let reportingOptions: Set<ReportingOption>
    public let attributeOptions: Set<ResultAttributeOption>
    let _channel = _ResultChannel<Result>()

    public convenience init(locale: Locale, preset: Preset) {
        self.init(locale: locale, contentHints: preset.contentHints, transcriptionOptions: preset.transcriptionOptions,
                  reportingOptions: preset.reportingOptions, attributeOptions: preset.attributeOptions)
    }
    public init(locale: Locale, contentHints: Set<ContentHint>, transcriptionOptions: Set<TranscriptionOption>,
                reportingOptions: Set<ReportingOption>, attributeOptions: Set<ResultAttributeOption>) {
        self.locale = locale; self.contentHints = contentHints; self.transcriptionOptions = transcriptionOptions
        self.reportingOptions = reportingOptions; self.attributeOptions = attributeOptions
    }

    public static var supportedLocales: [Locale] { _SpeechLocales.supported }
    public static var installedLocales: [Locale] { _SpeechLocales.installed }
    public static func supportedLocale(equivalentTo locale: Locale) async -> Locale? { _SpeechLocales.equivalent(locale) }
    public var selectedLocales: [Locale] { _SpeechLocales.equivalent(locale).map { [$0] } ?? [] }
    public var availableCompatibleAudioFormats: [AVAudioFormat] { [_SpeechAudio.analyzerFormat] }
    public var results: some Sendable & AsyncSequence<Result, any Error> { _channel.stream }

    var _needsEngine: Bool { true }
    var _language: String? { _SpeechLocales.language(locale) }
    /// without .punctuation, dictation gives words only
    func _text(_ s: String) -> String {
        guard !transcriptionOptions.contains(.punctuation) else { return s }
        let kept = s.unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) || $0 == "'" || $0 == "’" || $0 == "-" }
        return String(String.UnicodeScalarView(kept)).split(separator: " ").joined(separator: " ").lowercased()
    }
    func _process(_ pcm: [Float], start: Double, context: AnalysisContext) async throws {
        guard let lang = _language else { throw SFSpeechError(.cannotAllocateUnsupportedLocale, "\(locale.identifier) is not a supported locale") }
        let model = contentHints.compactMap(\._model).first
        guard let segs = await _SpeechEngine.transcribe(pcm, language: lang, prompt: _SpeechEngine.prompt(context._allStrings, model: model)) else {
            throw SFSpeechError(.moduleOutputFailed, "speech recognition failed: the host's speech-to-text engine did not run")
        }
        for (r, fin, text) in _transcriptionResults(segs, start: start, duration: Double(pcm.count) / _SpeechEngine.rate,
                                                    timeIndexed: attributeOptions.contains(.audioTimeRange), transform: _text) {
            _channel.cont.yield(Result(range: r, resultsFinalizationTime: fin, text: text, alternatives: []))
        }
    }
    func _finish(_ error: Error?) { _channel.cont.finish(throwing: error) }
}

/// Voice activity (adapted): 20 ms frames whose level is above a threshold set by the sensitivity count as speech;
/// short gaps are bridged and very short bursts ignored.
@available(iOS 26.0, *)
public final class SpeechDetector: SpeechModule, _SpeechModuleImpl, @unchecked Sendable {
    public enum SensitivityLevel: Hashable, Sendable { case low, medium, high }
    public struct DetectionOptions: Sendable {
        public let sensitivityLevel: SensitivityLevel
        public init(sensitivityLevel: SensitivityLevel) { self.sensitivityLevel = sensitivityLevel }
    }
    public struct Result: SpeechModuleResult, Sendable {
        public var range: CMTimeRange
        public var resultsFinalizationTime: CMTime
        public let speechDetected: Bool
    }
    let options: DetectionOptions
    let reportResults: Bool
    let _channel = _ResultChannel<Result>()
    public init(detectionOptions: DetectionOptions, reportResults: Bool) { options = detectionOptions; self.reportResults = reportResults }
    public convenience init() { self.init(detectionOptions: DetectionOptions(sensitivityLevel: .medium), reportResults: false) }
    public var availableCompatibleAudioFormats: [AVAudioFormat] { [_SpeechAudio.analyzerFormat] }
    public var results: some Sendable & AsyncSequence<Result, any Error> { _channel.stream }

    var _needsEngine: Bool { false }
    var _language: String? { nil }
    /// speech / non-speech runs of a stretch (seconds from its start)
    static func runs(_ pcm: [Float], sensitivity: SensitivityLevel) -> [(Double, Double, Bool)] {
        let frame = 320, dbfs: Float = sensitivity == .high ? -50 : sensitivity == .low ? -30 : -40
        let thresh = pow(10, dbfs / 20)
        var flags: [Bool] = stride(from: 0, to: pcm.count, by: frame).map { i in
            let e = pcm[i..<min(i + frame, pcm.count)]
            return (e.reduce(0) { $0 + $1 * $1 } / Float(max(1, e.count))).squareRoot() > thresh
        }
        func fill(_ value: Bool, maxLen: Int) {   // runs of !value shorter than maxLen between value frames become value
            var i = 0
            while i < flags.count {
                guard flags[i] != value else { i += 1; continue }
                var j = i; while j < flags.count && flags[j] != value { j += 1 }
                if i > 0 && j < flags.count && j - i < maxLen { for k in i..<j { flags[k] = value } }
                i = j
            }
        }
        fill(true, maxLen: 15)    // gaps under 300 ms
        fill(false, maxLen: 5)    // bursts under 100 ms
        var out: [(Double, Double, Bool)] = []
        var i = 0
        while i < flags.count {
            var j = i; while j < flags.count && flags[j] == flags[i] { j += 1 }
            out.append((Double(i * frame) / _SpeechEngine.rate, Double(min(j * frame, pcm.count)) / _SpeechEngine.rate, flags[i]))
            i = j
        }
        return out
    }
    func _process(_ pcm: [Float], start: Double, context: AnalysisContext) async throws {
        guard reportResults else { return }
        let fin = _SpeechAudio.time(start + Double(pcm.count) / _SpeechEngine.rate)
        for (a, b, speech) in SpeechDetector.runs(pcm, sensitivity: options.sensitivityLevel) {
            _channel.cont.yield(Result(range: _SpeechAudio.range(start + a, start + b), resultsFinalizationTime: fin, speechDetected: speech))
        }
    }
    func _finish(_ error: Error?) { _channel.cont.finish(throwing: error) }
}

// MARK: - attributes

@available(iOS 26.0, *)
extension AttributeScopes {
    public var speech: SpeechAttributes.Type { SpeechAttributes.self }
    public struct SpeechAttributes: AttributeScope {
        public let audioTimeRange: TimeRangeAttribute
        public let transcriptionConfidence: ConfidenceAttribute
        /// the stretch of audio a run of transcribed text came from
        public struct TimeRangeAttribute: AttributedStringKey, Sendable {
            public typealias Value = CMTimeRange
            public static let name = "SFSpeechAudioTimeRange"
        }
        /// how confident the recognizer was in a run (isim: whisper.cpp and Vosk report none)
        public struct ConfidenceAttribute: AttributedStringKey, Sendable {
            public typealias Value = Double
            public static let name = "SFSpeechTranscriptionConfidence"
        }
    }
}
@available(iOS 26.0, *)
extension AttributeDynamicLookup {
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.SpeechAttributes, T>) -> T { self[T.self] }
}
@available(iOS 26.0, *)
extension AttributedString {
    /// the text whose audio time ranges intersect `timeRange`, from the first such run to the last
    public func rangeOfAudioTimeRangeAttributes(intersecting timeRange: CMTimeRange) -> Range<AttributedString.Index>? {
        var lo: AttributedString.Index?, hi: AttributedString.Index?
        for run in runs {
            guard let r = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] else { continue }
            if r.start < timeRange.end && timeRange.start < r.end {
                if lo == nil { lo = run.range.lowerBound }
                hi = run.range.upperBound
            }
        }
        guard let lo, let hi else { return nil }
        return lo..<hi
    }
}

// MARK: - input and context

@available(iOS 26.0, *)
public struct AnalyzerInput: @unchecked Sendable {
    let _buffer: AVAudioPCMBuffer
    public let bufferStartTime: CMTime?
    public init(buffer: AVAudioPCMBuffer) { self.init(buffer: buffer, bufferStartTime: nil) }
    public init(buffer: AVAudioPCMBuffer, bufferStartTime: CMTime?) { _buffer = buffer; self.bufferStartTime = bufferStartTime }
    @available(iOS, introduced: 26.0, deprecated: 27.0)
    public var buffer: AVAudioPCMBuffer { _buffer }
    @available(iOS 27.0, *)
    public var bufferDuration: CMTime { CMTime(value: CMTimeValue(_buffer.frameLength), timescale: CMTimeScale(_buffer.format.sampleRate.rounded())) }
    @available(iOS 27.0, *)
    public var bufferFormat: AVAudioFormat { _buffer.format }
}

@available(iOS 26.0, *)
public final class AnalysisContext: @unchecked Sendable {
    public struct ContextualStringsTag: RawRepresentable, Hashable, Sendable {
        public typealias RawValue = String
        public let rawValue: String
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let general = ContextualStringsTag("general")
    }
    public struct UserDataTag: RawRepresentable, Hashable, Sendable {
        public typealias RawValue = String
        public let rawValue: String
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public init(rawValue: String) { self.rawValue = rawValue }
    }
    let _lock = NSLock()
    var _strings: [ContextualStringsTag: [String]] = [:]
    var _userData: [UserDataTag: any Sendable] = [:]
    public init() {}
    /// words and phrases likely to be spoken (isim: they become whisper.cpp's prompt)
    public var contextualStrings: [ContextualStringsTag: [String]] {
        get { _lock.lock(); defer { _lock.unlock() }; return _strings }
        set { _lock.lock(); _strings = newValue; _lock.unlock() }
    }
    public var userData: [UserDataTag: any Sendable] {
        get { _lock.lock(); defer { _lock.unlock() }; return _userData }
        set { _lock.lock(); _userData = newValue; _lock.unlock() }
    }
    var _allStrings: [String] {
        let s = contextualStrings
        return (s[.general] ?? []) + s.filter { $0.key != .general }.sorted { $0.key.rawValue < $1.key.rawValue }.flatMap(\.value)
    }
}

// MARK: - the analyzer

@available(iOS 26.0, *)
public final actor SpeechAnalyzer {
    public struct Options: Sendable {
        public enum ModelRetention: Hashable, Sendable { case whileInUse, lingering, processLifetime }
        public let priority: TaskPriority
        public let modelRetention: ModelRetention
        let _ignoresResourceLimits: Bool
        @available(iOS 27.0, *)
        public var ignoresResourceLimits: Bool { _ignoresResourceLimits }
        public init(priority: TaskPriority, modelRetention: ModelRetention) {
            self.priority = priority; self.modelRetention = modelRetention; _ignoresResourceLimits = false
        }
        @available(iOS 27.0, *)
        public init(priority: TaskPriority, modelRetention: ModelRetention, ignoresResourceLimits: Bool) {
            self.priority = priority; self.modelRetention = modelRetention; _ignoresResourceLimits = ignoresResourceLimits
        }
    }

    public private(set) var modules: [any SpeechModule]
    public private(set) var context: AnalysisContext
    public private(set) var volatileRange: CMTimeRange?
    let _options: Options?
    var _volatileHandler: ((CMTimeRange, Bool, Bool) -> Void)?
    var _pcm: [Float] = []             // audio not finalized yet (16 kHz mono)
    var _pcmStart = 0.0                // its start on the analysis timeline (seconds)
    var _sawInput = false
    var _input: Task<Void, Never>?     // reading a started input sequence
    var _chain: Task<Void, Never>?     // stretches being processed, in order
    var _error: Error?
    var _finished = false

    var _inputEnd: Double { _pcmStart + Double(_pcm.count) / _SpeechEngine.rate }
    var _impls: [_SpeechModuleImpl] { modules.compactMap { $0 as? _SpeechModuleImpl } }

    public init(modules: [any SpeechModule], options: Options? = nil) {
        self.modules = modules; _options = options; context = AnalysisContext()
    }
    public init<InputSequence: AsyncSequence & Sendable>(inputSequence: InputSequence, modules: [any SpeechModule], options: Options? = nil,
                                                         analysisContext: AnalysisContext = .init(),
                                                         volatileRangeChangedHandler: sending ((CMTimeRange, Bool, Bool) -> Void)? = nil)
        where InputSequence.Element == AnalyzerInput {
        self.modules = modules; _options = options; context = analysisContext; _volatileHandler = volatileRangeChangedHandler
        Task { try? await self.start(inputSequence: inputSequence) }
    }
    public init(inputAudioFile: AVAudioFile, modules: [any SpeechModule], options: Options? = nil, analysisContext: AnalysisContext = .init(),
                finishAfterFile: Bool = false, volatileRangeChangedHandler: sending ((CMTimeRange, Bool, Bool) -> Void)? = nil) async throws {
        self.modules = modules; _options = options; context = analysisContext; _volatileHandler = volatileRangeChangedHandler
        try await start(inputAudioFile: inputAudioFile, finishAfterFile: finishAfterFile)
    }

    // MARK: setup
    public func setModules(_ newModules: [any SpeechModule]) async throws {
        try _checkOpen()
        let kept = Set(newModules.map { ObjectIdentifier($0) })
        for m in modules where !kept.contains(ObjectIdentifier(m)) { (m as? _SpeechModuleImpl)?._finish(nil) }
        modules = newModules
        try _checkEngine()
    }
    public func setContext(_ newContext: AnalysisContext) async throws { try _checkOpen(); context = newContext }
    nonisolated public func setVolatileRangeChangedHandler(_ handler: sending ((CMTimeRange, Bool, Bool) -> Void)?) {
        let h = _UncheckedBox(handler)
        Task { await self._setHandler(h.value) }
    }
    func _setHandler(_ h: ((CMTimeRange, Bool, Bool) -> Void)?) { _volatileHandler = h }

    public static func bestAvailableAudioFormat(compatibleWith modules: [any SpeechModule]) async -> AVAudioFormat? {
        await bestAvailableAudioFormat(compatibleWith: modules, considering: nil)
    }
    /// isim: every module works in 16 kHz mono; a considered format of that rate and channel count is kept
    public static func bestAvailableAudioFormat(compatibleWith modules: [any SpeechModule], considering naturalFormat: AVAudioFormat?) async -> AVAudioFormat? {
        if let f = naturalFormat, f.sampleRate == _SpeechEngine.rate, f.channelCount == 1 { return f }
        return modules.isEmpty ? nil : _SpeechAudio.analyzerFormat
    }
    public func prepareToAnalyze(in audioFormat: AVAudioFormat?) async throws {
        try await prepareToAnalyze(in: audioFormat, withProgressReadyHandler: nil)
    }
    public func prepareToAnalyze(in audioFormat: AVAudioFormat?, withProgressReadyHandler handler: sending ((Progress) -> Void)?) async throws {
        try _checkOpen(); try _checkEngine()
        let p = Progress(totalUnitCount: 1); p.completedUnitCount = 1
        handler?(p)
    }

    // MARK: input
    public func start<InputSequence: AsyncSequence & Sendable>(inputSequence: InputSequence) async throws where InputSequence.Element == AnalyzerInput {
        try _checkOpen(); try _checkEngine()
        _input?.cancel()
        _input = Task {
            do { for try await i in inputSequence { try Task.checkCancellation(); try await self._append(i) } }
            catch is CancellationError {}
            catch { self._fail(error) }
        }
    }
    public func start(inputAudioFile: AVAudioFile, finishAfterFile: Bool = false) async throws {
        try _checkOpen(); try _checkEngine()
        let inputs = try SpeechAnalyzer._read(inputAudioFile)
        _input?.cancel()
        _input = Task {
            do {
                for i in inputs { try await self._append(i) }
                if finishAfterFile { try await self._finalizeAndFinish(through: nil) }
            } catch { self._fail(error) }
        }
    }
    /// analyzes the sequence until it ends; returns the time of the end of its audio
    public func analyzeSequence<InputSequence: AsyncSequence & Sendable>(_ inputSequence: InputSequence) async throws -> CMTime? where InputSequence.Element == AnalyzerInput {
        try _checkOpen(); try _checkEngine()
        for try await i in inputSequence { try await _append(i) }
        if let e = _error { throw e }
        return _sawInput ? _SpeechAudio.time(_inputEnd) : nil
    }
    public func analyzeSequence(from audioFile: AVAudioFile) async throws -> CMTime? {
        try _checkOpen(); try _checkEngine()
        for i in try SpeechAnalyzer._read(audioFile) { try await _append(i) }
        if let e = _error { throw e }
        return _sawInput ? _SpeechAudio.time(_inputEnd) : nil
    }
    static func _read(_ file: AVAudioFile) throws -> [AnalyzerInput] {
        var out: [AnalyzerInput] = []
        let fmt = file.processingFormat, chunk: AVAudioFrameCount = 16384
        var pos = file.framePosition
        while file.framePosition < file.length {
            guard let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: chunk) else { break }
            do { try file.read(into: b, frameCount: chunk) }
            catch { throw SFSpeechError(.audioReadFailed, "isim could not read \(file.url.lastPathComponent): \(error.localizedDescription)") }
            if b.frameLength == 0 { break }
            out.append(AnalyzerInput(buffer: b, bufferStartTime: CMTime(value: pos, timescale: CMTimeScale(fmt.sampleRate.rounded()))))
            pos += AVAudioFramePosition(b.frameLength)
        }
        return out
    }
    func _append(_ input: AnalyzerInput) async throws {
        if let e = _error { throw e }
        guard !_finished else { return }
        var mono = _SpeechAudio.mono16k(input._buffer)
        if let t = input.bufferStartTime, t.isValid {
            let s = t.seconds
            if !_sawInput && _pcm.isEmpty { _pcmStart = s }
            else if s < _inputEnd - 0.01 {
                throw SFSpeechError(.audioDisordered, "audio at \(s) s comes before audio already analyzed (\(_inputEnd) s)")
            } else if s > _inputEnd + 0.001 {
                _pcm += [Float](repeating: 0, count: min(Int((s - _inputEnd) * _SpeechEngine.rate), 60 * 16000))   // a gap: silence
            }
        }
        _sawInput = true
        if let skip = _cancelBefore, skip > _pcmStart {
            let n = min(Int((skip - _pcmStart) * _SpeechEngine.rate), _pcm.count + mono.count)
            let fromPcm = min(n, _pcm.count)
            _pcm.removeFirst(fromPcm); mono.removeFirst(min(n - fromPcm, mono.count)); _pcmStart += Double(n) / _SpeechEngine.rate
        }
        _pcm += mono
        _autoFinalize()
        _updateVolatile()
    }
    var _cancelBefore: Double?
    /// stops analysis of audio before `time`: it is dropped without results
    nonisolated public func cancelAnalysis(before time: CMTime) {
        Task { await self._cancel(before: time.seconds) }
    }
    func _cancel(before t: Double) {
        _cancelBefore = max(_cancelBefore ?? 0, t)
        guard t > _pcmStart else { return }
        let n = min(Int((t - _pcmStart) * _SpeechEngine.rate), _pcm.count)
        _pcm.removeFirst(n); _pcmStart += Double(n) / _SpeechEngine.rate
        _updateVolatile()
    }

    // MARK: finalizing
    /// once several seconds are buffered, the audio up to the last pause is finalized (at most 25 s of it)
    func _autoFinalize() {
        let rate = Int(_SpeechEngine.rate), frame = 320
        guard _pcm.count >= 6 * rate else { return }
        let window = min(_pcm.count, 25 * rate)
        var best = -1, bestE = Float.infinity, lastQuiet = -1
        for i in Swift.stride(from: 3 * rate, to: window - frame, by: frame) {
            let e = _pcm[i..<i + frame].reduce(0) { $0 + $1 * $1 } / Float(frame)
            if e < 1e-4 { lastQuiet = i + frame / 2 }
            if e < bestE { bestE = e; best = i + frame / 2 }
        }
        let cut = lastQuiet > 0 ? lastQuiet : _pcm.count >= 25 * rate ? best : -1
        guard cut > 0 else { return }
        _enqueue(cut)
    }
    /// hands the first n samples to the modules (in order, after the stretches before them)
    @discardableResult func _enqueue(_ n: Int) -> Task<Void, Never> {
        let chunk = Array(_pcm.prefix(n)), start = _pcmStart
        _pcm.removeFirst(min(n, _pcm.count)); _pcmStart += Double(chunk.count) / _SpeechEngine.rate
        let prev = _chain, impls = _impls, ctx = context
        let t = Task {
            await prev?.value
            guard self._error == nil, !chunk.isEmpty else { return }
            do { for m in impls { try await m._process(chunk, start: start, context: ctx) } }
            catch { self._fail(error) }
        }
        _chain = t
        _updateVolatile()
        return t
    }
    func _finalize(through t: Double?) async throws {
        let end = min(t ?? _inputEnd, _inputEnd)
        let n = max(0, Int(((end - _pcmStart) * _SpeechEngine.rate).rounded()))
        await _enqueue(min(n, _pcm.count)).value
        if let e = _error { throw e }
    }
    public func finalize(through time: CMTime?) async throws {
        try _checkOpen()
        try await _finalize(through: time.map(\.seconds))
    }
    func _finalizeAndFinish(through t: Double?) async throws {
        do { try await _finalize(through: t) } catch { _finish(error); throw error }
        _finish(nil)
    }
    public func finalizeAndFinish(through time: CMTime) async throws {
        try _checkOpen()
        _input?.cancel()
        try await _finalizeAndFinish(through: time.seconds)
    }
    public func finalizeAndFinishThroughEndOfInput() async throws {
        try _checkOpen()
        await _input?.value
        try await _finalizeAndFinish(through: nil)
    }
    /// finishes once the input reaches `time` (or ends), after finalizing the audio before it
    public func finish(after time: CMTime) async throws {
        try _checkOpen()
        let t = time.seconds
        while _inputEnd < t, let i = _input, _error == nil {
            if await _inputDone(i) { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        _input?.cancel()
        try await _finalizeAndFinish(through: t)
    }
    func _inputDone(_ t: Task<Void, Never>) async -> Bool {
        await withTaskGroup(of: Bool.self) { g in
            g.addTask { await t.value; return true }
            g.addTask { try? await Task.sleep(nanoseconds: 1_000_000); return false }
            let r = await g.next() ?? false
            g.cancelAll()
            return r
        }
    }
    public func cancelAndFinishNow() async {
        _input?.cancel()
        _pcm.removeAll()
        _chain?.cancel()
        _finish(nil)
    }

    // MARK: state
    func _checkOpen() throws {
        if let e = _error { throw e }
        if _finished { throw SFSpeechError(.internalServiceError, "the analyzer has finished; create a new SpeechAnalyzer") }
    }
    func _checkEngine() throws {
        guard _impls.contains(where: \._needsEngine), !_SpeechEngine.available else { return }
        NSLog("isim Speech: no speech-to-text engine on the host (install whisper.cpp and set ISIM_WHISPER_MODEL, or Vosk and ISIM_VOSK_MODEL)")
        throw SFSpeechError(.noModel, "speech transcription is not available on this host: isim needs whisper.cpp (whisper-cli with ISIM_WHISPER_MODEL) or Vosk (vosk-transcriber with ISIM_VOSK_MODEL)")
    }
    func _fail(_ e: Error) {
        guard _error == nil, !_finished else { return }
        _error = e
        _input?.cancel()
        _finish(e)
    }
    func _finish(_ e: Error?) {
        guard !_finished else { return }
        _finished = true
        for m in _impls { m._finish(e) }
        volatileRange = nil
    }
    func _updateVolatile() {
        let new: CMTimeRange? = _pcm.isEmpty ? nil : _SpeechAudio.range(_pcmStart, _inputEnd)
        guard new != volatileRange else { return }
        let old = volatileRange
        volatileRange = new
        if let h = _volatileHandler, let r = new ?? old.map({ CMTimeRange(start: $0.end, duration: .zero) }) {
            h(r, old?.start != new?.start, old?.end != new?.end)
        }
    }
}

struct _UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

// MARK: - assets

@available(iOS 26.0, *)
public final class AssetInventory: Sendable {
    public enum Status: Comparable, Hashable, Sendable { case unsupported, supported, downloading, installed }
    static let _lock = NSLock()
    nonisolated(unsafe) static var _reserved: [Locale] = []
    /// isim: how many locales an app may reserve at once
    public static var maximumReservedLocales: Int { 4 }
    public static var reservedLocales: [Locale] { _lock.lock(); defer { _lock.unlock() }; return _reserved }
    public static func reserve(locale: Locale) async throws -> Bool {
        guard let l = _SpeechLocales.equivalent(locale) else {
            throw SFSpeechError(.cannotAllocateUnsupportedLocale, "\(locale.identifier) is not a supported locale")
        }
        _lock.lock(); defer { _lock.unlock() }
        if _reserved.contains(l) { return false }
        guard _reserved.count < maximumReservedLocales else {
            throw SFSpeechError(.tooManyAssetLocalesAllocated, "an app can reserve at most \(maximumReservedLocales) locales")
        }
        _reserved.append(l)
        return true
    }
    public static func release(reservedLocale locale: Locale) async -> Bool {
        guard let l = _SpeechLocales.equivalent(locale) else { return false }
        _lock.lock(); defer { _lock.unlock() }
        guard let i = _reserved.firstIndex(of: l) else { return false }
        _reserved.remove(at: i)
        return true
    }
    /// isim: installed when the host has a speech-to-text engine; supported (not downloadable) otherwise
    public static func status(forModules modules: [any SpeechModule]) async -> Status {
        let impls = modules.compactMap { $0 as? _SpeechModuleImpl }
        if impls.contains(where: { $0._needsEngine && $0._language == nil }) { return .unsupported }
        return !impls.contains(where: \._needsEngine) || _SpeechEngine.available ? .installed : .supported
    }
    public static func assetInstallationRequest(supporting modules: [any SpeechModule]) async throws -> AssetInstallationRequest? {
        switch await status(forModules: modules) {
        case .installed: return nil
        case .unsupported: throw SFSpeechError(.cannotAllocateUnsupportedLocale, "a module's locale is not supported")
        default: return AssetInstallationRequest()
        }
    }
}

@available(iOS 26.0, *)
public final class AssetInstallationRequest: NSObject, ProgressReporting, @unchecked Sendable {
    public let progress = Progress(totalUnitCount: 1)
    /// isim cannot download Apple's models: the host's engine is the model
    public func downloadAndInstall() async throws {
        if _SpeechEngine.available { progress.completedUnitCount = 1; return }
        NSLog("isim Speech: speech models are not downloadable on isim; install whisper.cpp and set ISIM_WHISPER_MODEL, or Vosk and ISIM_VOSK_MODEL")
        throw SFSpeechError(.noModel, "isim cannot download speech models: install whisper.cpp (whisper-cli) and set ISIM_WHISPER_MODEL to a ggml model, or Vosk (vosk-transcriber) and ISIM_VOSK_MODEL")
    }
}

@available(iOS 26.0, *)
public enum SpeechModels {
    /// isim: the host's engine runs per request, so nothing is retained
    public static func endRetention() async {}
}

// MARK: - iOS 27 input providers

/// Converts audio of any format into analyzer input of the analyzer's format (adapted: isim's own mixing and resampling;
/// the configuration handler sees an AVAudioConverter between the two formats).
@available(iOS 27.0, *)
public final class AnalyzerInputConverter: @unchecked Sendable {
    let format: AVAudioFormat
    public static func converter(compatibleWith modules: [any SpeechModule]) async throws -> AnalyzerInputConverter {
        AnalyzerInputConverter(analyzerFormat: _SpeechAudio.analyzerFormat, configurationHandler: nil)
    }
    let _configure: ((AVAudioConverter) -> Void)?
    var _configured = false
    public init(analyzerFormat: AVAudioFormat, configurationHandler: ((AVAudioConverter) -> Void)?) {
        format = analyzerFormat; _configure = configurationHandler
    }
    public func convert(_ buffer: AVAudioBuffer, at time: AVAudioTime?) throws -> [AnalyzerInput] {
        guard let pcm = buffer as? AVAudioPCMBuffer else {
            throw SFSpeechError(.unexpectedAudioFormat, "isim converts linear PCM buffers only")
        }
        if !_configured, let c = _configure, let conv = AVAudioConverter(from: pcm.format, to: format) { c(conv) }
        _configured = true
        guard let out = _SpeechAudio.buffer(_SpeechAudio.mono16k(pcm), format: format) else { return [] }
        let start = time.flatMap { $0.isSampleTimeValid ? CMTime(value: $0.sampleTime, timescale: CMTimeScale($0.sampleRate.rounded())) : nil }
        return [AnalyzerInput(buffer: out, bufferStartTime: start)]
    }
    public func flush() throws -> [AnalyzerInput] { [] }
}

@available(iOS 27.0, *)
public final class AssetInputSequenceProvider: @unchecked Sendable {
    let asset: AVAsset, track: AVAssetTrack, format: AVAudioFormat
    public static func provider(from asset: AVAsset, compatibleWith modules: [any SpeechModule], priority: TaskPriority?) async throws -> AssetInputSequenceProvider {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw SFSpeechError(.audioReadFailed, "the asset has no audio track")
        }
        return try await provider(from: asset, track: track, compatibleWith: modules, priority: priority)
    }
    public static func provider(from asset: AVAsset, track: AVAssetTrack, compatibleWith modules: [any SpeechModule], priority: TaskPriority?) async throws -> AssetInputSequenceProvider {
        AssetInputSequenceProvider(asset: asset, track: track, analyzerFormat: _SpeechAudio.analyzerFormat, priority: priority)
    }
    public init(asset: AVAsset, track: AVAssetTrack, analyzerFormat: AVAudioFormat, priority: TaskPriority?) {
        self.asset = asset; self.track = track; format = analyzerFormat
    }
    /// the track's audio, read with AVAssetReader and converted to the analyzer's format
    public var analyzerInputs: some Sendable & AsyncSequence<AnalyzerInput, any Error> {
        let (stream, cont) = AsyncThrowingStream<AnalyzerInput, Error>.makeStream()
        let box = _UncheckedBox((asset, track, format))
        DispatchQueue.global().async {
            let (asset, track, format) = box.value
            do {
                let reader = try AVAssetReader(asset: asset)
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true,
                                                                                    AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false])
                reader.add(output)
                guard reader.startReading() else { throw reader.error ?? SFSpeechError(.audioReadFailed, "isim could not read the asset's audio") }
                while let sb = output.copyNextSampleBuffer() {
                    guard let b = _SpeechAudio.buffer(sb), let out = _SpeechAudio.buffer(_SpeechAudio.mono16k(b), format: format) else { continue }
                    cont.yield(AnalyzerInput(buffer: out, bufferStartTime: sb.presentationTimeStamp))
                }
                if reader.status == .failed { throw reader.error ?? SFSpeechError(.audioReadFailed, "reading the asset failed") }
                cont.finish()
            } catch { cont.finish(throwing: error) }
        }
        return stream
    }
}

@available(iOS 27.0, *)
public final class CaptureInputSequenceProvider: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    public let captureSession: AVCaptureSession
    public let captureAudioDataOutput: AVCaptureAudioDataOutput
    let format: AVAudioFormat
    let _channel = _ResultChannel<AnalyzerInput>()
    let _queue = DispatchQueue(label: "isim.speech.capture")
    /// a new capture session with the device's audio (started when the inputs are first read, if not running)
    public static func providerWithSession(from device: AVCaptureDevice, compatibleWith modules: [any SpeechModule], priority: TaskPriority?) async throws -> CaptureInputSequenceProvider {
        let s = AVCaptureSession()
        return try await provider(from: device, in: s, compatibleWith: modules, priority: priority)
    }
    public static func provider(from device: AVCaptureDevice, in session: AVCaptureSession, compatibleWith modules: [any SpeechModule], priority: TaskPriority?) async throws -> CaptureInputSequenceProvider {
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        return try CaptureInputSequenceProvider(session: session, analyzerFormat: _SpeechAudio.analyzerFormat, priority: priority)
    }
    public init(session: AVCaptureSession, analyzerFormat: AVAudioFormat, priority: TaskPriority?) throws {
        captureSession = session; format = analyzerFormat
        captureAudioDataOutput = AVCaptureAudioDataOutput()
        super.init()
        session.beginConfiguration()
        guard session.canAddOutput(captureAudioDataOutput) else {
            session.commitConfiguration()
            throw SFSpeechError(.cannotConfigureAudioSystem, "the capture session cannot take an audio data output")
        }
        session.addOutput(captureAudioDataOutput)
        session.commitConfiguration()
        captureAudioDataOutput.setSampleBufferDelegate(self, queue: _queue)
    }
    public var analyzerInputs: some Sendable & AsyncSequence<AnalyzerInput, any Error> {
        if !captureSession.isRunning { let s = captureSession; DispatchQueue.global().async { s.startRunning() } }
        return _channel.stream
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let b = _SpeechAudio.buffer(sampleBuffer), let out = _SpeechAudio.buffer(_SpeechAudio.mono16k(b), format: format) else { return }
        _channel.cont.yield(AnalyzerInput(buffer: out, bufferStartTime: sampleBuffer.presentationTimeStamp))
    }
}
