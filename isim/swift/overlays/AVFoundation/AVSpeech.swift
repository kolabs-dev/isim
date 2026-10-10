// isim AVFoundation: speech synthesis — AVSpeechSynthesizer, AVSpeechUtterance, AVSpeechSynthesisVoice.
// Speech is synthesized by the host's espeak-ng (or espeak) in a child process and played by the audio mixer
// (adapted: eSpeak voices, not Apple's). willSpeakRangeOfSpeechString is approximate: words are spread over the
// audio in proportion to their length. Without a TTS engine on the host, utterances still start and finish
// (silently, timed at ~175 words per minute) and a message is logged once.
import isim_host

public let AVSpeechUtteranceMinimumSpeechRate: Float = 0
public let AVSpeechUtteranceMaximumSpeechRate: Float = 1
public let AVSpeechUtteranceDefaultSpeechRate: Float = 0.5
public let AVSpeechSynthesisVoiceIdentifierAlex = "com.apple.speech.voice.Alex"

public enum AVSpeechBoundary: Int, Sendable { case immediate = 0, word }
public enum AVSpeechSynthesisVoiceQuality: Int, Sendable { case `default` = 1, enhanced, premium }
public enum AVSpeechSynthesisVoiceGender: Int, Sendable { case unspecified = 0, male, female }

open class AVSpeechSynthesisVoice: NSObject, @unchecked Sendable {
    /// BCP-47 language -> (espeak voice, English language name)
    static let table: [(String, String, String)] = [
        ("en-US", "en-us", "English (US)"), ("en-GB", "en-gb", "English (UK)"), ("en-AU", "en-us", "English (Australia)"),
        ("fr-FR", "fr-fr", "French"), ("fr-CA", "fr-fr", "French (Canada)"), ("de-DE", "de", "German"), ("es-ES", "es", "Spanish"),
        ("es-MX", "es-419", "Spanish (Mexico)"), ("it-IT", "it", "Italian"), ("pt-BR", "pt-br", "Portuguese (Brazil)"),
        ("pt-PT", "pt", "Portuguese (Portugal)"), ("nl-NL", "nl", "Dutch"), ("sv-SE", "sv", "Swedish"), ("da-DK", "da", "Danish"),
        ("nb-NO", "nb", "Norwegian"), ("fi-FI", "fi", "Finnish"), ("pl-PL", "pl", "Polish"), ("cs-CZ", "cs", "Czech"),
        ("ru-RU", "ru", "Russian"), ("uk-UA", "uk", "Ukrainian"), ("tr-TR", "tr", "Turkish"), ("el-GR", "el", "Greek"),
        ("ar-SA", "ar", "Arabic"), ("he-IL", "he", "Hebrew"), ("hi-IN", "hi", "Hindi"), ("ja-JP", "ja", "Japanese"),
        ("ko-KR", "ko", "Korean"), ("zh-CN", "cmn", "Chinese (China)"), ("zh-TW", "cmn", "Chinese (Taiwan)"), ("id-ID", "id", "Indonesian"),
        ("vi-VN", "vi", "Vietnamese"), ("th-TH", "th", "Thai"), ("ro-RO", "ro", "Romanian"), ("hu-HU", "hu", "Hungarian"),
    ]
    public let language: String
    public let identifier: String
    public let name: String
    public let quality: AVSpeechSynthesisVoiceQuality = .default
    public let gender: AVSpeechSynthesisVoiceGender = .unspecified
    open var audioFileSettings: [String: Any] { ["AVFormatIDKey": 0x6C70636D, "AVSampleRateKey": 22050.0, "AVNumberOfChannelsKey": 1] }
    let espeak: String
    init(entry e: (String, String, String)) {
        language = e.0; espeak = e.1; identifier = "isim.espeak.\(e.0)"; name = "eSpeak \(e.2)"
    }
    public convenience init?(language: String?) {
        let want = (language ?? AVSpeechSynthesisVoice.currentLanguageCode()).replacingOccurrences(of: "_", with: "-")
        let e = Self.table.first { $0.0.lowercased() == want.lowercased() }
            ?? Self.table.first { $0.0.lowercased().hasPrefix(String(want.lowercased().prefix(2))) }
        guard let e else { return nil }
        self.init(entry: e)
    }
    public convenience init?(identifier: String) {
        guard let e = Self.table.first(where: { "isim.espeak.\($0.0)" == identifier }) else { return nil }
        self.init(entry: e)
    }
    open class func speechVoices() -> [AVSpeechSynthesisVoice] { table.map { AVSpeechSynthesisVoice(entry: $0) } }
    open class func currentLanguageCode() -> String {
        let id = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        return id.isEmpty ? "en-US" : id
    }
}

open class AVSpeechUtterance: NSObject, @unchecked Sendable {
    public let speechString: String
    open var voice: AVSpeechSynthesisVoice?
    open var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    open var pitchMultiplier: Float = 1
    open var volume: Float = 1
    open var preUtteranceDelay: TimeInterval = 0
    open var postUtteranceDelay: TimeInterval = 0
    open var prefersAssistiveTechnologySettings = false
    public init(string: String) { speechString = string }
    /// espeak words per minute for the AVSpeech rate (0.5 = normal speaking rate)
    var _wpm: Double {
        let r = Double(min(max(rate, 0), 1))
        return r <= 0.5 ? 80 + (175 - 80) * r / 0.5 : 175 + (450 - 175) * (r - 0.5) / 0.5
    }
    var _pitch: Double {
        let m = Double(min(max(pitchMultiplier, 0.5), 2))
        return m >= 1 ? 50 + (m - 1) * 49 : 50 * (m - 0.5) / 0.5
    }
}

@objc public protocol AVSpeechSynthesizerDelegate: NSObjectProtocol {
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance)
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance)
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance)
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance)
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance)
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance)
}

/// Synthesized speech for one utterance.
struct _Speech {
    var pcm: [Float]; var rate: Double; var synthesized: Bool
    var duration: Double { rate > 0 ? Double(pcm.count) / rate : 0 }
    nonisolated(unsafe) static var warned = false
    static func make(_ u: AVSpeechUtterance) -> _Speech {
        var out: UnsafeMutablePointer<Float>? = nil
        var frames = 0, rate = 0.0
        let voice = (u.voice ?? AVSpeechSynthesisVoice(language: nil))?.espeak ?? "en-us"
        if !u.speechString.isEmpty, isim_tts_synthesize(u.speechString, voice, u._wpm, u._pitch, &out, &frames, &rate) != 0, let p = out {
            let pcm = Array(UnsafeBufferPointer(start: p, count: frames))
            isim_media_free(p)
            return _Speech(pcm: pcm, rate: rate, synthesized: true)
        }
        if !u.speechString.isEmpty && !warned {
            warned = true
            NSLog("isim AVSpeechSynthesizer: no text-to-speech engine on the host (install espeak-ng); utterances run silently")
        }
        let words = max(1, u.speechString.split(whereSeparator: { $0 == " " || $0 == "\n" }).count)
        let seconds = u.speechString.isEmpty ? 0 : Double(words) / u._wpm * 60
        return _Speech(pcm: [Float](repeating: 0, count: Int(seconds * 22050)), rate: 22050, synthesized: false)
    }
    /// UTF-16 ranges of the words, for willSpeakRangeOfSpeechString.
    static func words(_ s: String) -> [NSRange] {
        var out: [NSRange] = []
        var start = -1, i = 0
        for c in s.utf16 {
            let space = c == 32 || c == 10 || c == 9 || c == 13
            if space { if start >= 0 { out.append(NSRange(location: start, length: i - start)); start = -1 } }
            else if start < 0 { start = i }
            i += 1
        }
        if start >= 0 { out.append(NSRange(location: start, length: i - start)) }
        return out
    }
}

open class AVSpeechSynthesizer: NSObject, @unchecked Sendable {
    open weak var delegate: AVSpeechSynthesizerDelegate?
    open private(set) var isSpeaking = false
    open private(set) var isPaused = false
    open var usesApplicationAudioSession = true
    open var mixToTelephonyUplink = false
    public override init() { super.init() }

    var queue: [AVSpeechUtterance] = []
    var current: AVSpeechUtterance?
    var generation = 0
    var voice = 0
    var buffer: Int32 = 0
    var words: [NSRange] = []
    var wordTimes: [Double] = []
    var nextWord = 0
    var duration = 0.0
    var played = 0.0             // seconds played before the current run
    var runStart = 0.0
    var timer: Timer?

    open func speak(_ utterance: AVSpeechUtterance) {
        queue.append(utterance)
        isSpeaking = true
        if current == nil { startNext() }
    }
    @discardableResult open func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        guard isSpeaking else { return false }
        let u = current
        queue.removeAll()
        finishCurrent()
        isSpeaking = false; isPaused = false
        if let u { delegate?.speechSynthesizer?(self, didCancel: u) }
        return true
    }
    @discardableResult open func pauseSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        guard let u = current, !isPaused else { return false }
        isPaused = true
        played += isim_time() - runStart
        if voice != 0 { isim_audio_pause(voice, 1) }
        timer?.invalidate(); timer = nil
        delegate?.speechSynthesizer?(self, didPause: u)
        return true
    }
    @discardableResult open func continueSpeaking() -> Bool {
        guard let u = current, isPaused else { return false }
        isPaused = false
        runStart = isim_time()
        if voice != 0 { isim_audio_pause(voice, 0) }
        startTimer()
        delegate?.speechSynthesizer?(self, didContinue: u)
        return true
    }
    /// Renders an utterance to PCM buffers (Float32 mono); a final empty buffer marks the end.
    open func write(_ utterance: AVSpeechUtterance, toBufferCallback bufferCallback: @escaping (AVAudioBuffer) -> Void) {
        let s = _Speech.make(utterance)
        let format = AVAudioFormat(standardFormatWithSampleRate: s.rate, channels: 1)!
        let chunk = 4096
        var i = 0
        while i < s.pcm.count {
            let n = min(chunk, s.pcm.count - i)
            let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
            s.pcm.withUnsafeBufferPointer { src in b.channels[0].update(from: src.baseAddress! + i, count: n) }
            b.frameLength = AVAudioFrameCount(n)
            bufferCallback(b)
            i += n
        }
        bufferCallback(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1)!)
    }

    func startNext() {
        guard !queue.isEmpty else { current = nil; isSpeaking = false; return }
        let u = queue.removeFirst()
        current = u
        generation += 1
        let gen = generation
        DispatchQueue.global().async {
            let speech = _Speech.make(u)
            DispatchQueue.main.asyncAfter(deadline: .now() + u.preUtteranceDelay) { [weak self] in
                guard let self, self.generation == gen else { return }
                self.begin(u, speech)
            }
        }
    }
    func begin(_ u: AVSpeechUtterance, _ s: _Speech) {
        duration = s.duration
        words = _Speech.words(u.speechString)
        // each word starts at its share of the utterance, by UTF-16 offset
        let total = max(1, Double((u.speechString as NSString).length))
        wordTimes = words.map { Double($0.location) / total * s.duration }
        nextWord = 0
        played = 0; runStart = isim_time()
        if s.synthesized, !s.pcm.isEmpty {
            buffer = s.pcm.withUnsafeBufferPointer { isim_audio_buffer_create($0.baseAddress, $0.count, 1, s.rate) }
            if buffer > 0 { voice = isim_audio_play(buffer, Double(min(max(u.volume, 0), 1)), 0) }
        }
        delegate?.speechSynthesizer?(self, didStart: u)
        if isPaused { played = 0; if voice != 0 { isim_audio_pause(voice, 1) } } else { startTimer() }
        tick()
    }
    func startTimer() {
        timer?.invalidate()
        timer = Timer._isimScheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in self?.tick() }
    }
    func tick() {
        guard let u = current, !isPaused else { return }
        let t = played + (isim_time() - runStart)
        while nextWord < words.count, wordTimes[nextWord] <= t {
            let r = words[nextWord]; nextWord += 1
            delegate?.speechSynthesizer?(self, willSpeakRangeOfSpeechString: r, utterance: u)
        }
        guard t >= duration else { return }
        finishCurrent()
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + u.postUtteranceDelay) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.delegate?.speechSynthesizer?(self, didFinish: u)
            self.startNext()
        }
    }
    func finishCurrent() {
        timer?.invalidate(); timer = nil
        if voice != 0 { isim_audio_stop(voice); voice = 0 }
        if buffer > 0 { isim_audio_buffer_release(buffer); buffer = 0 }
        if queue.isEmpty { current = nil }
        generation += 1
    }
}
