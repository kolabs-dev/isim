// isim Speech (self-authored, iOS API names): SFSpeechRecognizer, authorization, URL and audio-buffer recognition
// requests, tasks, results and transcriptions.
// Authorization is the shared privacy prompt ("Would Like to Access Speech Recognition", remembered per app;
// ISIM_SPEECH_PERMISSION=allow|deny answers it). Recognition runs on the host only when a speech-to-text engine is
// configured (adapted): whisper.cpp (`whisper-cli` + ISIM_WHISPER_MODEL=<ggml model>) or Vosk (`vosk-transcriber` +
// ISIM_VOSK_MODEL=<model dir>). Without one, SFSpeechRecognizer.isAvailable is false and tasks fail with a clear error
// (like a device with Siri and Dictation disabled). Results are delivered once, as final (no partial results).
import Foundation
import AVFoundation
import isim_host

@objc public enum SFSpeechRecognizerAuthorizationStatus: Int, Sendable { case notDetermined = 0, denied, restricted, authorized }
@objc public enum SFSpeechRecognitionTaskHint: Int, Sendable { case unspecified = 0, dictation, search, confirmation }
@objc public enum SFSpeechRecognitionTaskState: Int, Sendable { case starting = 0, running, finishing, canceling, completed }

public protocol SFSpeechRecognizerDelegate: NSObjectProtocol {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool)
}
extension SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {}
}
public protocol SFSpeechRecognitionTaskDelegate: NSObjectProtocol {
    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask)
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription)
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult)
    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask)
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask)
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool)
}
extension SFSpeechRecognitionTaskDelegate {
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {}
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {}
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {}
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {}
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {}
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {}
}

open class SFTranscriptionSegment: NSObject, @unchecked Sendable {
    public let substring: String
    public let substringRange: NSRange
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public let confidence: Float
    public var alternativeSubstrings: [String] { [] }
    init(substring: String, range: NSRange, timestamp: TimeInterval, duration: TimeInterval, confidence: Float) {
        self.substring = substring; substringRange = range; self.timestamp = timestamp; self.duration = duration; self.confidence = confidence
    }
}
open class SFTranscription: NSObject, @unchecked Sendable {
    public let formattedString: String
    public let segments: [SFTranscriptionSegment]
    init(formattedString: String, segments: [SFTranscriptionSegment]) { self.formattedString = formattedString; self.segments = segments }
}
open class SFSpeechRecognitionResult: NSObject, @unchecked Sendable {
    public let bestTranscription: SFTranscription
    public var transcriptions: [SFTranscription] { [bestTranscription] }
    public let isFinal: Bool
    init(best: SFTranscription, final: Bool) { bestTranscription = best; isFinal = final }
}

open class SFSpeechRecognitionRequest: NSObject, @unchecked Sendable {
    open var taskHint: SFSpeechRecognitionTaskHint = .unspecified
    open var shouldReportPartialResults = true
    open var contextualStrings: [String] = []
    open var requiresOnDeviceRecognition = false
    open var addsPunctuation = false
    func _pcm16k() -> [Float]? { nil }
}
open class SFSpeechURLRecognitionRequest: SFSpeechRecognitionRequest, @unchecked Sendable {
    public let url: URL
    public init(url URL: URL) { url = URL }
    override func _pcm16k() -> [Float]? {
        var out: UnsafeMutablePointer<Float>? = nil
        var frames = 0, ch: Int32 = 0, rate = 0.0
        guard isim_audio_decode_file(url.path, &out, &frames, &ch, &rate) != 0, let p = out else { return nil }
        defer { isim_audio_free(p) }
        return _SFResample.mono16k(UnsafeBufferPointer(start: p, count: frames * Int(ch)), channels: Int(ch), rate: rate)
    }
}
open class SFSpeechAudioBufferRecognitionRequest: SFSpeechRecognitionRequest, @unchecked Sendable {
    var _samples: [Float] = []
    var _ended = false
    var _onEnd: (() -> Void)?
    let _lock = NSLock()
    public override init() { super.init() }
    open var nativeAudioFormat: AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)! }
    open func append(_ audioPCMBuffer: AVAudioPCMBuffer) {
        guard let ch = audioPCMBuffer.floatChannelData else { return }
        let n = Int(audioPCMBuffer.frameLength), c = Int(audioPCMBuffer.format.channelCount)
        var mono = [Float](repeating: 0, count: n)
        for k in 0..<c { for i in 0..<n { mono[i] += ch[k][i] / Float(c) } }
        let r = _SFResample.mono16k(mono, rate: audioPCMBuffer.format.sampleRate)
        _lock.lock(); _samples += r; _lock.unlock()
    }
    open func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription, let b = sampleBuffer.dataBuffer else { return }
        let ch = Int(asbd.mChannelsPerFrame), bs = asbd._bytesPerSample, fb = asbd._frameBytes
        let n = fb > 0 ? b._bytes.count / fb : 0
        var mono = [Float](repeating: 0, count: n)
        b._bytes.withUnsafeBytes { raw in
            for i in 0..<n { for c in 0..<ch {
                let p = raw.baseAddress! + i * fb + c * bs
                let v: Float = asbd._isFloat ? p.loadUnaligned(as: Float.self) : bs == 2 ? Float(p.loadUnaligned(as: Int16.self)) / 32768 : Float(p.loadUnaligned(as: Int32.self)) / 2_147_483_648
                mono[i] += v / Float(ch)
            } }
        }
        let r = _SFResample.mono16k(mono, rate: asbd.mSampleRate)
        _lock.lock(); _samples += r; _lock.unlock()
    }
    open func endAudio() {
        _lock.lock(); _ended = true; let f = _onEnd; _onEnd = nil; _lock.unlock()
        f?()
    }
    override func _pcm16k() -> [Float]? { _lock.lock(); defer { _lock.unlock() }; return _samples }
}

enum _SFResample {
    static func mono16k(_ x: UnsafeBufferPointer<Float>, channels: Int, rate: Double) -> [Float] {
        let n = x.count / max(1, channels)
        var mono = [Float](repeating: 0, count: n)
        for i in 0..<n { for c in 0..<channels { mono[i] += x[i * channels + c] / Float(channels) } }
        return mono16k(mono, rate: rate)
    }
    static func mono16k(_ x: [Float], rate: Double) -> [Float] {
        guard rate > 0, rate != 16000, !x.isEmpty else { return x }
        let r = rate / 16000, n = Int(Double(x.count) / r)
        return (0..<n).map { i in
            let p = Double(i) * r, i0 = Int(p), t = Float(p - Double(i0))
            return x[min(i0, x.count - 1)] + (x[min(i0 + 1, x.count - 1)] - x[min(i0, x.count - 1)]) * t
        }
    }
}

public let SFSpeechErrorDomain = "SFSpeechErrorDomain"
@objc public enum SFSpeechErrorCode: Int, Sendable { case internalServiceError = 1, audioReadFailed = 2, undefinedTemplateClassName = 7, malformedSupplementalModel = 8 }
func _sfError(_ msg: String, code: Int = 1) -> NSError { NSError(domain: SFSpeechErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: msg]) }

open class SFSpeechRecognitionTask: NSObject, @unchecked Sendable {
    open private(set) var state: SFSpeechRecognitionTaskState = .starting
    open private(set) var isFinishing = false
    open private(set) var isCancelled = false
    open private(set) var error: Error?
    let _request: SFSpeechRecognitionRequest
    let _locale: Locale
    let _queue: OperationQueue
    let _handler: (SFSpeechRecognitionResult?, Error?) -> Void
    weak var _delegate: SFSpeechRecognitionTaskDelegate?
    init(request: SFSpeechRecognitionRequest, locale: Locale, queue: OperationQueue, delegate: SFSpeechRecognitionTaskDelegate?,
         handler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) {
        _request = request; _locale = locale; _queue = queue; _delegate = delegate; _handler = handler
        super.init()
    }
    open func finish() { isFinishing = true; (_request as? SFSpeechAudioBufferRecognitionRequest)?.endAudio() }
    open func cancel() {
        guard state != .completed else { return }
        isCancelled = true; state = .canceling
        _queue.addOperation { [self] in
            _delegate?.speechRecognitionTaskWasCancelled(self)
            state = .completed
        }
    }
    func _start() {
        state = .running
        if let b = _request as? SFSpeechAudioBufferRecognitionRequest {
            b._lock.lock()
            if b._ended { b._lock.unlock(); DispatchQueue.global().async { self._recognize() } }
            else { b._onEnd = { [weak self] in DispatchQueue.global().async { self?._recognize() } }; b._lock.unlock() }
        } else {
            DispatchQueue.global().async { self._recognize() }
        }
    }
    func _fail(_ e: Error) {
        _queue.addOperation { [self] in
            guard !isCancelled else { return }
            error = e; state = .completed
            _handler(nil, e)
            _delegate?.speechRecognitionTask(self, didFinishSuccessfully: false)
        }
    }
    func _recognize() {
        guard !isCancelled else { return }
        state = .finishing
        _queue.addOperation { [self] in _delegate?.speechRecognitionTaskFinishedReadingAudio(self) }
        guard let pcm = _request._pcm16k(), !pcm.isEmpty else { _fail(_sfError("isim could not read the audio for speech recognition", code: 2)); return }
        let lang = _locale.language.languageCode?.identifier ?? "en"
        guard let raw = pcm.withUnsafeBufferPointer({ isim_speech_transcribe($0.baseAddress!, $0.count, lang) }) else {
            _fail(_sfError("speech recognition failed: the host's speech-to-text engine did not run")); return
        }
        defer { isim_media_free(raw) }
        var text = "", segments: [SFTranscriptionSegment] = []
        for line in String(cString: raw).split(separator: "\n") {
            let f = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard f.count == 3 else { continue }
            let a = Double(f[0]) ?? -1, b = Double(f[1]) ?? -1
            let words = f[2].split(separator: " ").map(String.init)
            let step = a >= 0 && b > a && !words.isEmpty ? (b - a) / Double(words.count) : 0
            for (k, w) in words.enumerated() {
                if !text.isEmpty { text += " " }
                let loc = (text as NSString).length
                text += w
                segments.append(SFTranscriptionSegment(substring: w, range: NSRange(location: loc, length: (w as NSString).length),
                                                       timestamp: a >= 0 ? a + step * Double(k) : 0, duration: step, confidence: 0))
            }
        }
        let t = SFTranscription(formattedString: text, segments: segments)
        let result = SFSpeechRecognitionResult(best: t, final: true)
        _queue.addOperation { [self] in
            guard !isCancelled else { return }
            if !text.isEmpty { _delegate?.speechRecognitionDidDetectSpeech(self) }
            state = .completed
            _handler(result, nil)
            _delegate?.speechRecognitionTask(self, didFinishRecognition: result)
            _delegate?.speechRecognitionTask(self, didFinishSuccessfully: true)
        }
    }
}

open class SFSpeechRecognizer: NSObject, @unchecked Sendable {
    public let locale: Locale
    open weak var delegate: SFSpeechRecognizerDelegate?
    open var queue: OperationQueue = .main
    open var defaultTaskHint: SFSpeechRecognitionTaskHint = .unspecified
    open var supportsOnDeviceRecognition: Bool { isAvailable }
    static let languages: Set<String> = ["en", "fr", "de", "es", "it", "pt", "nl", "sv", "da", "nb", "fi", "pl", "tr", "ru", "uk", "ja", "ko", "zh", "ar", "he", "hi", "ro", "cs", "el", "vi", "th", "id", "ms", "ca", "hu", "sk", "hr"]
    public convenience override init() { self.init(locale: Locale.current)! }
    public init?(locale: Locale) {
        guard let l = locale.language.languageCode?.identifier, SFSpeechRecognizer.languages.contains(l) else { return nil }
        self.locale = locale
        super.init()
    }
    open class func supportedLocales() -> Set<Locale> { Set(languages.map { Locale(identifier: $0) }) }
    /// isim: true when the host has a speech-to-text engine configured (whisper.cpp or Vosk)
    open var isAvailable: Bool { isim_speech_available() != 0 }

    // MARK: authorization
    open class func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        _Privacy.stored("speech").flatMap { SFSpeechRecognizerAuthorizationStatus(rawValue: $0) } ?? .notDetermined
    }
    open class func requestAuthorization(_ handler: @escaping @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        let s = authorizationStatus()
        if s != .notDetermined { _Privacy.reply { handler(s) }; return }
        guard let purpose = _Privacy.usage("NSSpeechRecognitionUsageDescription", "Speech") else { _Privacy.reply { handler(.denied) }; return }
        _Privacy.onMain {
            func answer(_ ok: Bool) {
                let st: SFSpeechRecognizerAuthorizationStatus = ok ? .authorized : .denied
                _Privacy.store("speech", st.rawValue)
                NSLog("isim Speech: speech recognition %@ for %@", ok ? "allowed" : "denied", _Privacy.appName)
                _Privacy.reply { handler(st) }
            }
            if let sc = _Privacy.scripted("SPEECH") { answer(!(sc == "deny" || sc == "denied" || sc == "no" || sc == "0")); return }
            _Privacy.alert("“\(_Privacy.appName)” Would Like to Access Speech Recognition", purpose,
                           [("Don’t Allow", .default), (_Privacy.osMajor >= 17 ? "Allow" : "OK", .default)]) { answer($0 == 1) }
        }
    }

    // MARK: tasks
    open func recognitionTask(with request: SFSpeechRecognitionRequest, resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask {
        _task(request, nil, resultHandler)
    }
    open func recognitionTask(with request: SFSpeechRecognitionRequest, delegate: SFSpeechRecognitionTaskDelegate) -> SFSpeechRecognitionTask {
        _task(request, delegate) { _, _ in }
    }
    func _task(_ request: SFSpeechRecognitionRequest, _ delegate: SFSpeechRecognitionTaskDelegate?, _ handler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SFSpeechRecognitionTask {
        let t = SFSpeechRecognitionTask(request: request, locale: locale, queue: queue, delegate: delegate, handler: handler)
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            t._fail(_sfError("speech recognition is not authorized for this app (SFSpeechRecognizer.requestAuthorization)", code: 1700))
        } else if !isAvailable {
            NSLog("isim Speech: no speech-to-text engine on the host (install whisper.cpp and set ISIM_WHISPER_MODEL, or Vosk and ISIM_VOSK_MODEL)")
            t._fail(_sfError("speech recognition is not available on this host: isim needs whisper.cpp (whisper-cli with ISIM_WHISPER_MODEL) or Vosk (vosk-transcriber with ISIM_VOSK_MODEL)", code: 1101))
        } else {
            t._start()
        }
        return t
    }
}
