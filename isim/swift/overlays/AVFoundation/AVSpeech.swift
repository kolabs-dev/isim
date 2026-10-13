// isim AVFoundation: speech synthesis — AVSpeechSynthesizer, AVSpeechUtterance, AVSpeechSynthesisVoice,
// AVSpeechSynthesisMarker. Speech is synthesized by the host's libespeak-ng (passthrough engine, adapted voices:
// eSpeak's, not Apple's) and played by the audio mixer. espeak-ng reports where each word, sentence and SSML <mark>
// falls in the audio, so willSpeakRangeOfSpeechString and willSpeakMarker follow the speech. Utterances can be SSML
// (espeak-ng's SSML: prosody, break, say-as, mark, ...). Without the library the espeak-ng command renders the speech
// and words are spread over it in proportion to their length; without any TTS engine utterances still start and
// finish (silently, timed at ~175 words per minute) and a message is logged once. No Personal Voice (unsupported,
// like devices without it).
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
    /// isim's identifiers (isim.espeak.<language>), and Apple's voice identifiers (com.apple.voice.compact.en-US.Samantha,
    /// com.apple.ttsbundle.Samantha-compact, ...) mapped to the eSpeak voice of their language
    public convenience init?(identifier: String) {
        if let e = Self.table.first(where: { "isim.espeak.\($0.0)" == identifier }) { self.init(entry: e); return }
        if let e = Self.table.first(where: { identifier.contains($0.0) }) { self.init(entry: e); return }
        let names = ["Samantha": "en-US", "Alex": "en-US", "Daniel": "en-GB", "Karen": "en-AU", "Thomas": "fr-FR", "Anna": "de-DE",
                     "Monica": "es-ES", "Alice": "it-IT", "Luciana": "pt-BR", "Kyoko": "ja-JP", "Ting-Ting": "zh-CN", "Yuna": "ko-KR"]
        guard identifier.hasPrefix("com.apple."), let lang = names.first(where: { identifier.contains($0.key) })?.value,
              let e = Self.table.first(where: { $0.0 == lang }) else { return nil }
        self.init(entry: e)
    }
    public struct Traits: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let isNoveltyVoice = Traits(rawValue: 1)
        public static let isPersonalVoice = Traits(rawValue: 2)
    }
    open var voiceTraits: Traits { [] }
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
    public init(string: String) { speechString = string; _ssml = nil; attributedSpeechString = NSAttributedString(string: string) }
    public init(attributedString: NSAttributedString) {
        speechString = attributedString.string; _ssml = nil; attributedSpeechString = attributedString
    }
    /// SSML (spoken by espeak-ng's SSML support); nil when the markup is not an XML <speak> document
    public init?(ssmlRepresentation string: String) {
        guard let plain = _SSML.plain(string) else { return nil }
        speechString = plain.text; _ssml = string; attributedSpeechString = NSAttributedString(string: plain.text)
    }
    public let attributedSpeechString: NSAttributedString
    let _ssml: String?
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
    @objc optional func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance)
}

/// SSML -> its text, with each SSML character's UTF-16 offset in that text (for espeak-ng's positions).
enum _SSML {
    static func plain(_ ssml: String) -> (text: String, map: [Int])? {
        guard ssml.range(of: "<speak", options: .caseInsensitive) != nil else { return nil }
        var text = "", map: [Int] = [], utf16 = 0
        let chars = Array(ssml.unicodeScalars)
        var i = 0
        func emit(_ s: String) { text += s; utf16 += s.utf16.count }
        while i < chars.count {
            map.append(utf16)
            let c = chars[i]
            if c == "<" {
                var j = i
                while j < chars.count && chars[j] != ">" { j += 1; if j < chars.count { map.append(utf16) } }
                if j < chars.count {
                    let tag = String(String.UnicodeScalarView(chars[i...j])).lowercased()
                    if tag.hasPrefix("<break") || tag.hasPrefix("</p") || tag.hasPrefix("</s") { if !text.isEmpty && !text.hasSuffix(" ") { emit(" ") } }
                }
                i = j + 1
                continue
            }
            if c == "&", let semi = chars[i...].firstIndex(of: ";"), semi - i < 10 {
                let ent = String(String.UnicodeScalarView(chars[(i + 1)..<semi]))
                let value: String? = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"][ent]
                    ?? (ent.hasPrefix("#x") ? UInt32(ent.dropFirst(2), radix: 16) : ent.hasPrefix("#") ? UInt32(ent.dropFirst()) : nil)
                        .flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
                if let value {
                    for _ in (i + 1)...semi { map.append(utf16) }
                    emit(value); i = semi + 1; continue
                }
            }
            emit(String(Character(c)))
            i += 1
        }
        map.append(utf16)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lead = text.utf16.count - text.drop(while: { $0.isWhitespace }).utf16.count
        return (trimmed, map.map { max(0, min(trimmed.utf16.count, $0 - lead)) })
    }
}

/// Synthesized speech for one utterance, with the times of its words and markers.
struct _Speech {
    struct Event { let kind: Int; let range: NSRange; let time: Double; let frame: Int; let name: String }
    var pcm: [Float]; var rate: Double; var synthesized: Bool
    var events: [Event] = []
    var duration: Double { rate > 0 ? Double(pcm.count) / rate : 0 }
    nonisolated(unsafe) static var warned = false
    static func make(_ u: AVSpeechUtterance) -> _Speech {
        var out: UnsafeMutablePointer<Float>? = nil
        var frames = 0, rate = 0.0
        let voice = (u.voice ?? AVSpeechSynthesisVoice(language: nil))?.espeak ?? "en-us"
        let source = u._ssml ?? u.speechString
        var evp: UnsafeMutablePointer<isim_tts_event>? = nil
        var nev: Int32 = 0
        if !source.isEmpty, isim_tts_render(source, u._ssml != nil ? 1 : 0, voice, u._wpm, u._pitch, 100, &out, &frames, &rate, &evp, &nev) != 0, let p = out {
            let pcm = Array(UnsafeBufferPointer(start: p, count: frames))
            isim_media_free(p)
            // espeak-ng positions count characters of the input: map them to UTF-16 ranges of speechString
            let map: [Int]
            if let ssml = u._ssml, let plain = _SSML.plain(ssml) { map = plain.map }
            else { var m: [Int] = [], o = 0; for c in source.unicodeScalars { m.append(o); o += c.utf16.count }; m.append(o); map = m }
            func offset(_ cp: Int) -> Int { map.isEmpty ? 0 : map[max(0, min(map.count - 1, cp))] }
            var events: [Event] = []
            for i in 0..<Int(nev) {
                guard let e = evp?[i] else { break }
                let start = offset(Int(e.text_pos)), end = offset(Int(e.text_pos + e.text_len))
                let name = withUnsafeBytes(of: e.name) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
                events.append(Event(kind: Int(e.kind), range: NSRange(location: start, length: max(0, end - start)), time: Double(e.frame) / rate,
                                    frame: e.frame, name: name))
            }
            isim_media_free(evp)
            return _Speech(pcm: pcm, rate: rate, synthesized: true, events: events)
        }
        if !u.speechString.isEmpty, u._ssml == nil, isim_tts_synthesize(u.speechString, voice, u._wpm, u._pitch, &out, &frames, &rate) != 0, let p = out {
            let pcm = Array(UnsafeBufferPointer(start: p, count: frames))
            isim_media_free(p)
            var s = _Speech(pcm: pcm, rate: rate, synthesized: true)
            s.events = approximate(u.speechString, s.duration, rate)
            return s
        }
        if !u.speechString.isEmpty && !warned {
            warned = true
            NSLog("isim AVSpeechSynthesizer: no text-to-speech engine on the host (install espeak-ng); utterances run silently")
        }
        let words = max(1, u.speechString.split(whereSeparator: { $0 == " " || $0 == "\n" }).count)
        let seconds = u.speechString.isEmpty ? 0 : Double(words) / u._wpm * 60
        var s = _Speech(pcm: [Float](repeating: 0, count: Int(seconds * 22050)), rate: 22050, synthesized: false)
        s.events = approximate(u.speechString, s.duration, 22050)
        return s
    }
    /// without engine events: each word starts at its share of the utterance, by UTF-16 offset
    static func approximate(_ s: String, _ duration: Double, _ rate: Double) -> [Event] {
        let total = max(1, Double((s as NSString).length))
        return words(s).map { r in
            let t = Double(r.location) / total * duration
            return Event(kind: 1, range: r, time: t, frame: Int(t * rate), name: "")
        }
    }
    /// UTF-16 ranges of the words.
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
    /// the iOS 17 markers of the speech (words, sentences, SSML marks, phonemes)
    func markers(_ u: AVSpeechUtterance) -> [AVSpeechSynthesisMarker] {
        events.compactMap { e in
            switch e.kind {
            case 1: return AVSpeechSynthesisMarker(markerType: .word, forTextRange: e.range, atByteSampleOffset: e.frame * 4)
            case 2: return AVSpeechSynthesisMarker(markerType: .sentence, forTextRange: e.range, atByteSampleOffset: e.frame * 4)
            case 3: return AVSpeechSynthesisMarker(bookmarkName: e.name, atByteSampleOffset: e.frame * 4)
            case 7: return AVSpeechSynthesisMarker(phonemeString: e.name, atByteSampleOffset: e.frame * 4)
            default: return nil
            }
        }
    }
}

/// iOS 17: a position in synthesized speech (byte offsets count 32-bit float mono samples).
open class AVSpeechSynthesisMarker: NSObject, @unchecked Sendable {
    public enum Mark: Int, Sendable { case phoneme = 0, word, sentence, paragraph, bookmark }
    open var mark: Mark
    open var byteSampleOffset: Int
    open var textRange: NSRange
    open var bookmarkName: String
    open var phoneme: String
    public init(markerType type: Mark, forTextRange range: NSRange, atByteSampleOffset byteOffset: Int) {
        mark = type; textRange = range; byteSampleOffset = byteOffset; bookmarkName = ""; phoneme = ""
    }
    public init(wordRange range: NSRange, atByteSampleOffset byteOffset: Int) { mark = .word; textRange = range; byteSampleOffset = byteOffset; bookmarkName = ""; phoneme = "" }
    public init(sentenceRange range: NSRange, atByteSampleOffset byteOffset: Int) { mark = .sentence; textRange = range; byteSampleOffset = byteOffset; bookmarkName = ""; phoneme = "" }
    public init(paragraphRange range: NSRange, atByteSampleOffset byteOffset: Int) { mark = .paragraph; textRange = range; byteSampleOffset = byteOffset; bookmarkName = ""; phoneme = "" }
    public init(bookmarkName mark: String, atByteSampleOffset byteOffset: Int) {
        self.mark = .bookmark; textRange = NSRange(location: NSNotFound, length: 0); byteSampleOffset = byteOffset; bookmarkName = mark; phoneme = ""
    }
    public init(phonemeString phoneme: String, atByteSampleOffset byteOffset: Int) {
        mark = .phoneme; textRange = NSRange(location: NSNotFound, length: 0); byteSampleOffset = byteOffset; bookmarkName = ""; self.phoneme = phoneme
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
    var events: [_Speech.Event] = []
    var markers: [AVSpeechSynthesisMarker] = []
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
        write(utterance, toBufferCallback: bufferCallback, toMarkerCallback: { _ in })
    }
    public typealias BufferCallback = (AVAudioBuffer) -> Void
    public typealias MarkerCallback = ([AVSpeechSynthesisMarker]) -> Void
    /// iOS 17: the buffers, and the markers (words, sentences, SSML marks) each buffer contains
    open func write(_ utterance: AVSpeechUtterance, toBufferCallback bufferCallback: @escaping BufferCallback,
                    toMarkerCallback markerCallback: @escaping MarkerCallback) {
        let s = _Speech.make(utterance)
        let format = AVAudioFormat(standardFormatWithSampleRate: s.rate, channels: 1)!
        let marks = s.markers(utterance)
        let chunk = 4096
        var i = 0
        while i < s.pcm.count {
            let n = min(chunk, s.pcm.count - i)
            let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
            s.pcm.withUnsafeBufferPointer { src in b.channels[0].update(from: src.baseAddress! + i, count: n) }
            b.frameLength = AVAudioFrameCount(n)
            let inside = marks.filter { $0.byteSampleOffset / 4 >= i && $0.byteSampleOffset / 4 < i + n }
            if !inside.isEmpty { markerCallback(inside) }
            bufferCallback(b)
            i += n
        }
        bufferCallback(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1)!)
    }
    // MARK: Personal Voice (iOS 17): not available on isim, like devices without it
    public enum PersonalVoiceAuthorizationStatus: UInt, Sendable { case notDetermined = 0, denied, unsupported, authorized }
    open class var personalVoiceAuthorizationStatus: PersonalVoiceAuthorizationStatus { .unsupported }
    open class func requestPersonalVoiceAuthorization(completionHandler handler: @escaping (PersonalVoiceAuthorizationStatus) -> Void) {
        DispatchQueue.main.async { handler(.unsupported) }
    }
    open class func requestPersonalVoiceAuthorization() async -> PersonalVoiceAuthorizationStatus { .unsupported }
    public static let availableVoicesDidChangeNotification = Notification.Name("AVSpeechSynthesisAvailableVoicesDidChangeNotification")

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
        events = s.events.filter { $0.kind == 1 || $0.kind == 2 || $0.kind == 3 }
        markers = s.markers(u)
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
        while nextWord < events.count, events[nextWord].time <= t {
            let e = events[nextWord]; nextWord += 1
            if e.kind == 1 { delegate?.speechSynthesizer?(self, willSpeakRangeOfSpeechString: e.range, utterance: u) }
            if let m = markers.first(where: { $0.byteSampleOffset == e.frame * 4 && ($0.mark == .bookmark ? e.kind == 3 : $0.textRange == e.range) }) {
                delegate?.speechSynthesizer?(self, willSpeak: m, utterance: u)
            }
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
