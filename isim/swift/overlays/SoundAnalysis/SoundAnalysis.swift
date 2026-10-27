// isim Sound Analysis (self-authored, Apple's API names): SNClassifySoundRequest, SNAudioStreamAnalyzer,
// SNAudioFileAnalyzer and their results, with Apple's Objective-C interface (headers in
// isim/sdk-src/Frameworks/SoundAnalysis over these classes).
// Apple's built-in classifier (SNClassifierIdentifier.version1) is a model in the OS. isim runs an ONNX audio
// classifier on the host with ONNX Runtime (runtime/host_sound.c): ISIM_SOUND_MODEL, YAMNet's ONNX export or any model
// that takes a 16 kHz mono waveform and gives class scores, with its labels (ISIM_SOUND_LABELS, else the class map CSV
// next to the model). Adapted: the labels are the model's (YAMNet's 521 AudioSet classes, written as Apple writes its
// identifiers: "Speech" -> speech, "Dog" -> dog), not Apple's 300. Audio is mixed to mono and resampled to 16 kHz;
// each window's scores are the model's frame scores averaged.
import Foundation
import AVFoundation
import CoreMedia
import CoreML
import isim_host

// MARK: - errors

public let SNErrorDomain = "com.apple.SoundAnalysis"

/// Sound Analysis's errors (domain SNErrorDomain).
public struct SNError: CustomNSError, Hashable, LocalizedError, @unchecked Sendable {
    public enum Code: Int, Sendable, Equatable {
        case unknownError = 1, operationFailed, invalidFormat, invalidModel, invalidFile
    }
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; errorUserInfo = userInfo }
    init(_ code: Code, _ message: String) { self.init(code, userInfo: [NSLocalizedDescriptionKey: message]) }
    public static var errorDomain: String { SNErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorDescription: String? { errorUserInfo[NSLocalizedDescriptionKey] as? String }
    public static var unknownError: Code { .unknownError }
    public static var operationFailed: Code { .operationFailed }
    public static var invalidFormat: Code { .invalidFormat }
    public static var invalidModel: Code { .invalidModel }
    public static var invalidFile: Code { .invalidFile }
    public static func == (a: SNError, b: SNError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
}
extension SNError.Code {
    /// `catch SNError.invalidModel`
    public static func ~= (match: SNError.Code, error: any Error) -> Bool {
        let e = error as NSError
        return e.domain == SNErrorDomain && e.code == match.rawValue
    }
}

// MARK: - requests, results, observers

/// A request an analyzer runs.
@objc(SNRequest) public protocol SNRequest: NSObjectProtocol {}
/// What a request produces.
@objc(SNResult) public protocol SNResult: NSObjectProtocol {}
/// Gets a request's results, its failure or its completion.
@objc(SNResultsObserving) public protocol SNResultsObserving: NSObjectProtocol {
    @objc(request:didProduceResult:) func request(_ request: any SNRequest, didProduce result: any SNResult)
    @objc(request:didFailWithError:) optional func request(_ request: any SNRequest, didFailWithError error: any Error)
    @objc(requestDidComplete:) optional func requestDidComplete(_ request: any SNRequest)
}

/// The built-in sound classifiers.
public struct SNClassifierIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let version1 = SNClassifierIdentifier(rawValue: "SNClassifierIdentifierVersion1")
}

/// The window durations a request accepts.
public enum SNTimeDurationConstraint: Sendable {
    case enumeratedDurations([CMTime])
    case durationRange(CMTimeRange)
}

/// The host's classifier: the ONNX model and its identifiers, loaded once
struct _SoundModel: @unchecked Sendable {
    let handle: Int32
    let identifiers: [String]

    static let shared: Result<_SoundModel, SNError> = {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["ISIM_SOUND_MODEL"], !path.isEmpty else {
            return .failure(SNError(.operationFailed, "sound classification on isim needs an ONNX audio classifier on the host (ISIM_SOUND_MODEL=yamnet.onnx)"))
        }
        guard FileManager.default.fileExists(atPath: path) else { return .failure(SNError(.invalidModel, "there is no sound model at \(path)")) }
        let h = isim_sound_model_open(path)
        guard h > 0 else { return .failure(SNError(.invalidModel, String(cString: isim_sound_error()))) }
        let labels = labelsFile(env["ISIM_SOUND_LABELS"], model: path).flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
        return .success(_SoundModel(handle: h, identifiers: labels.map(parseLabels) ?? []))
    }()

    /// the labels: ISIM_SOUND_LABELS, or a class map next to the model (<model>.csv, <model>.txt, yamnet_class_map.csv)
    static func labelsFile(_ given: String?, model: String) -> String? {
        if let given, !given.isEmpty { return given }
        let base = (model as NSString).deletingPathExtension, dir = (model as NSString).deletingLastPathComponent
        return [base + ".csv", base + ".txt", (dir as NSString).appendingPathComponent("yamnet_class_map.csv")]
            .first { FileManager.default.fileExists(atPath: $0) }
    }
    /// a CSV with a display_name column (YAMNet's class map), or one label per line
    static func parseLabels(_ text: String) -> [String] {
        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else { return [] }
        let columns = csv(header)
        if let i = columns.firstIndex(of: "display_name") {
            lines.removeFirst()
            return lines.map { let f = csv($0); return identifier(i < f.count ? f[i] : "") }
        }
        return lines.map { identifier($0) }
    }
    static func csv(_ line: String) -> [String] {
        var out: [String] = [], cur = "", quoted = false
        for ch in line {
            if ch == "\"" { quoted.toggle() } else if ch == "," && !quoted { out.append(cur); cur = "" } else { cur.append(ch) }
        }
        out.append(cur)
        return out.map { $0.trimmingCharacters(in: .whitespaces) }
    }
    /// Apple's style of identifier: "Speech" -> speech, "Dog barking" -> dog_barking, "Bicycle, tricycle" -> bicycle_tricycle
    static func identifier(_ name: String) -> String {
        var out = "", underscore = false
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber { if underscore && !out.isEmpty { out.append("_") }; out.append(ch); underscore = false }
            else { underscore = true }
        }
        return out
    }
    /// the scores of a 16 kHz mono window
    func classify(_ wave: [Float]) throws -> [Float] {
        var scores = [Float](repeating: 0, count: max(identifiers.count, 1024))
        let n = wave.withUnsafeBufferPointer { w in scores.withUnsafeMutableBufferPointer { isim_sound_model_run(handle, w.baseAddress!, Int32(w.count), $0.baseAddress!, Int32($0.count)) } }
        guard n >= 0 else { throw SNError(.operationFailed, String(cString: isim_sound_error())) }
        return Array(scores.prefix(Int(n)))
    }
}

let _snRate = 16000.0
/// YAMNet's patch: 0.975 s
let _snDefaultWindow = CMTime(value: 15600, timescale: 16000)

/// Classifies the sounds in each window of the audio.
@objc(SNClassifySoundRequest) open class SNClassifySoundRequest: NSObject, SNRequest, @unchecked Sendable {
    /// how much consecutive windows overlap, 0 ..< 1 (0.5: a result every half window)
    @objc open var overlapFactor: Double = 0.5
    open var windowDuration: CMTime = _snDefaultWindow
    let _model: _SoundModel

    /// the system's classifier (isim: the host's ONNX classifier, ISIM_SOUND_MODEL)
    public init(classifierIdentifier: SNClassifierIdentifier) throws {
        guard classifierIdentifier == .version1 else { throw SNError(.invalidModel, "unknown classifier \(classifierIdentifier.rawValue)") }
        switch _SoundModel.shared {
        case .success(let m): _model = m
        case .failure(let e): throw e
        }
        super.init()
    }
    /// a Core ML sound classifier: isim's Core ML runs no sound classifier models
    @objc(initWithMLModel:error:) public convenience init(mlModel: MLModel) throws {
        throw SNError(.invalidModel, "isim's Core ML cannot run sound classifier models (only GLM models run)")
    }
    @available(*, deprecated, renamed: "init(mlModel:)")
    public convenience init(MLModel mlModel: MLModel) throws { try self.init(mlModel: mlModel) }

    /// the labels the classifier can produce
    @objc open var knownClassifications: [String] { _model.identifiers }
    /// window durations from one YAMNet patch to 15 s (longer windows average more of the model's frames)
    open var windowDurationConstraint: SNTimeDurationConstraint {
        .durationRange(CMTimeRange(start: _snDefaultWindow, duration: CMTime(value: 15 * 16000 - 15600, timescale: 16000)))
    }

    var _windowSamples: Int { max(1, Int((windowDuration.seconds * _snRate).rounded())) }
    var _hopSamples: Int { max(1, Int((Double(_windowSamples) * (1 - min(max(overlapFactor, 0), 0.99))).rounded())) }
    func _validate() throws {
        let s = windowDuration.seconds
        guard s.isFinite, s >= 0.975 - 1e-6, s <= 15 + 1e-6 else {
            throw SNError(.invalidFormat, "the window duration \(s) s is outside the classifier's range (0.975 s to 15 s)")
        }
        guard overlapFactor >= 0, overlapFactor < 1 else { throw SNError(.invalidFormat, "the overlap factor must be in 0 ..< 1") }
    }
}

/// One classification: a label and how confident the classifier is (0 ... 1).
@objc(SNClassification) open class SNClassification: NSObject, @unchecked Sendable {
    @objc public let identifier: String
    @objc public let confidence: Double
    init(identifier: String, confidence: Double) { self.identifier = identifier; self.confidence = confidence }
    open override var description: String { "\(identifier): \(confidence)" }
}

/// The classifications of one window, the most confident first.
@objc(SNClassificationResult) open class SNClassificationResult: NSObject, SNResult, @unchecked Sendable {
    @objc public let classifications: [SNClassification]
    public let timeRange: CMTimeRange
    init(classifications: [SNClassification], timeRange: CMTimeRange) { self.classifications = classifications; self.timeRange = timeRange }
    @objc(classificationForIdentifier:) open func classification(forIdentifier identifier: String) -> SNClassification? {
        classifications.first { $0.identifier == identifier }
    }
}

// MARK: - analysis

/// one request's windows over the 16 kHz mono stream
final class _SNRun {
    let request: any SNRequest
    let observer: any SNResultsObserving
    var next = 0          // where the next window starts (16 kHz samples since the stream's start)
    var produced = 0
    var failed = false
    init(request: any SNRequest, observer: any SNResultsObserving) { self.request = request; self.observer = observer }
}

/// the analysis shared by the stream and file analyzers: input mixed to mono, resampled to 16 kHz, windowed per request
final class _SNAnalysis: @unchecked Sendable {
    let rate: Double
    var runs: [_SNRun] = []
    var wave: [Float] = []                 // the 16 kHz stream (from `origin`)
    var origin = 0                         // samples dropped from the front of `wave`
    var srcPos = 0.0                       // the resampler's position in input frames
    var last: Float = 0                    // the previous input frame (interpolation across buffers)
    var started: AVAudioFramePosition?
    init(rate: Double) { self.rate = rate }

    func add(_ request: any SNRequest, _ observer: any SNResultsObserving) throws {
        guard let r = request as? SNClassifySoundRequest else { throw SNError(.invalidModel, "isim analyzes SNClassifySoundRequest requests") }
        try r._validate()
        guard !runs.contains(where: { $0.request === request }) else { return }
        let run = _SNRun(request: request, observer: observer)
        run.next = origin + wave.count
        runs.append(run)
    }
    func remove(_ request: any SNRequest) { runs.removeAll { $0.request === request } }

    /// mono floats of a buffer
    static func mono(_ b: AVAudioPCMBuffer) -> [Float] {
        let n = Int(b.frameLength), ch = Int(b.format.channelCount), stride = b.stride
        guard n > 0, ch > 0 else { return [] }
        var out = [Float](repeating: 0, count: n)
        func mix(_ sample: (Int, Int) -> Float) { for i in 0..<n { var s: Float = 0; for c in 0..<ch { s += sample(c, i) }; out[i] = s / Float(ch) } }
        if let f = b.floatChannelData {
            mix { c, i in stride > 1 ? f[0][i * stride + c] : f[c][i] }
        } else if let p = b.int16ChannelData {
            mix { c, i in Float(stride > 1 ? p[0][i * stride + c] : p[c][i]) / 32768 }
        } else if let p = b.int32ChannelData {
            mix { c, i in Float(stride > 1 ? p[0][i * stride + c] : p[c][i]) / 2147483648 }
        }
        return out
    }
    func append(_ buffer: AVAudioPCMBuffer, at position: AVAudioFramePosition) {
        if started == nil { started = position }
        let input = Self.mono(buffer)
        guard !input.isEmpty else { return }
        let step = rate / _snRate                 // input frames per output sample
        /* linear interpolation; srcPos counts from the start of this buffer, -1 ... 0 being the previous one's last frame */
        while srcPos < Double(input.count - 1) {
            let i = Int(srcPos.rounded(.down)), t = Float(srcPos - Double(i))
            let a = i < 0 ? last : input[i], b2 = input[i + 1]
            wave.append(a + (b2 - a) * t)
            srcPos += step
        }
        srcPos -= Double(input.count)
        last = input[input.count - 1]
        process(final: false)
    }
    /// runs every window that is complete (final: also a last, partial window of a request without results, padded)
    func process(final: Bool) {
        for run in runs where !run.failed {
            guard let r = run.request as? SNClassifySoundRequest else { continue }
            let w = r._windowSamples, hop = r._hopSamples
            while run.next - origin + w <= wave.count {
                window(run, r, from: run.next, count: w)
                run.next += hop
            }
            if final, run.produced == 0, run.next - origin < wave.count {
                window(run, r, from: run.next, count: w)
            }
        }
        /* drop what no request needs any more */
        let keep = runs.map(\.next).min() ?? (origin + wave.count)
        let drop = min(max(0, keep - origin), wave.count)
        if drop > 16000 { wave.removeFirst(drop); origin += drop }
    }
    func window(_ run: _SNRun, _ r: SNClassifySoundRequest, from start: Int, count: Int) {
        let lo = start - origin
        var samples = Array(wave[max(0, lo)..<min(wave.count, lo + count)])
        if samples.count < count { samples += [Float](repeating: 0, count: count - samples.count) }
        do {
            let scores = try r._model.classify(samples)
            let ids = r._model.identifiers
            let list = scores.enumerated().map { i, s in
                SNClassification(identifier: i < ids.count ? ids[i] : "class_\(i)", confidence: Double(min(max(s, 0), 1)))
            }.sorted { $0.confidence > $1.confidence }
            /* the window in the input's frames and timescale */
            let scale = CMTimeScale(rate.rounded())
            let first = (started ?? 0) + AVAudioFramePosition((Double(start) * rate / _snRate).rounded())
            let length = CMTimeValue((Double(count) * rate / _snRate).rounded())
            let range = CMTimeRange(start: CMTime(value: first, timescale: scale), duration: CMTime(value: length, timescale: scale))
            run.produced += 1
            run.observer.request(run.request, didProduce: SNClassificationResult(classifications: list, timeRange: range))
        } catch {
            run.failed = true
            run.observer.request?(run.request, didFailWithError: error)
        }
    }
    func complete() {
        process(final: true)
        for run in runs where !run.failed { run.observer.requestDidComplete?(run.request) }
    }
}

/// Analyzes audio as the app delivers it (the microphone, a stream): results arrive on the analyzer's own queue.
@objc(SNAudioStreamAnalyzer) open class SNAudioStreamAnalyzer: NSObject, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.apple.SoundAnalysis.stream")
    let analysis: _SNAnalysis
    @objc(initWithFormat:) public init(format: AVAudioFormat) { analysis = _SNAnalysis(rate: format.sampleRate); super.init() }
    @objc(addRequest:withObserver:error:) open func add(_ request: any SNRequest, withObserver observer: any SNResultsObserving) throws {
        try queue.sync { try analysis.add(request, observer) }
    }
    @objc(removeRequest:) open func remove(_ request: any SNRequest) { queue.sync { analysis.remove(request) } }
    @objc open func removeAllRequests() { queue.sync { analysis.runs.removeAll() } }
    /// analyzes the buffer's samples, which start at `atAudioFramePosition` in the stream (isim: contiguous buffers)
    @objc(analyzeAudioBuffer:atAudioFramePosition:) open func analyze(_ audioBuffer: AVAudioBuffer, atAudioFramePosition position: AVAudioFramePosition) {
        guard let pcm = audioBuffer as? AVAudioPCMBuffer, let copy = AVAudioPCMBuffer(pcmFormat: pcm.format, frameCapacity: max(1, pcm.frameLength)) else { return }
        _copy(pcm, into: copy)
        queue.async { self.analysis.append(copy, at: position) }
    }
    /// finishes the analysis: the last window, then each observer's requestDidComplete
    @objc open func completeAnalysis() { queue.sync { analysis.complete() } }
}

/// copies a buffer's samples (the caller may reuse its buffer once analyze returns)
func _copy(_ from: AVAudioPCMBuffer, into to: AVAudioPCMBuffer) {
    to.frameLength = from.frameLength
    let src = UnsafeMutableAudioBufferListPointer(from.mutableAudioBufferList), dst = UnsafeMutableAudioBufferListPointer(to.mutableAudioBufferList)
    for i in 0..<min(src.count, dst.count) {
        if let s = src[i].mData, let d = dst[i].mData { memcpy(d, s, Int(min(src[i].mDataByteSize, dst[i].mDataByteSize))) }
    }
}

/// Analyzes an audio file.
@objc(SNAudioFileAnalyzer) open class SNAudioFileAnalyzer: NSObject, @unchecked Sendable {
    let file: AVAudioFile
    let analysis: _SNAnalysis
    let lock = NSLock()
    var cancelled = false
    @objc(initWithURL:error:) public init(url: URL) throws {
        do { file = try AVAudioFile(forReading: url) } catch {
            throw SNError(.invalidFile, userInfo: [NSLocalizedDescriptionKey: "the audio file \(url.lastPathComponent) cannot be read", NSUnderlyingErrorKey: error])
        }
        analysis = _SNAnalysis(rate: file.processingFormat.sampleRate)
        super.init()
    }
    @available(*, deprecated, renamed: "init(url:)")
    public convenience init(URL url: URL) throws { try self.init(url: url) }
    @objc(addRequest:withObserver:error:) open func add(_ request: any SNRequest, withObserver observer: any SNResultsObserving) throws {
        lock.lock(); defer { lock.unlock() }
        try analysis.add(request, observer)
    }
    @objc(removeRequest:) open func remove(_ request: any SNRequest) { lock.lock(); analysis.remove(request); lock.unlock() }
    @objc open func removeAllRequests() { lock.lock(); analysis.runs.removeAll(); lock.unlock() }
    /// analyzes the whole file, then returns
    @objc open func analyze() { _ = run() }
    /// analyzes the file in the background; the handler gets false when the analysis was cancelled
    @objc(analyzeWithCompletionHandler:) open func analyze(completionHandler: @escaping @Sendable (Bool) -> Void) {
        DispatchQueue.global().async { completionHandler(self.run()) }
    }
    @objc open func cancelAnalysis() { lock.lock(); cancelled = true; lock.unlock() }
    func run() -> Bool {
        lock.lock(); defer { lock.unlock() }
        file.framePosition = 0
        let chunk: AVAudioFrameCount = 8192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { return false }
        var position: AVAudioFramePosition = 0
        while position < file.length {
            if cancelled { return false }
            do { try file.read(into: buffer, frameCount: chunk) } catch {
                for r in analysis.runs { r.observer.request?(r.request, didFailWithError: SNError(.invalidFile, "the audio file cannot be read: \(error.localizedDescription)")) }
                return false
            }
            if buffer.frameLength == 0 { break }
            analysis.append(buffer, at: position)
            position += AVAudioFramePosition(buffer.frameLength)
        }
        if cancelled { return false }
        analysis.complete()
        return true
    }
}

// MARK: - Objective-C: CMTime values travel as NSNumbers (the .m makes them CMTime and CMTimeRange)

extension SNClassifySoundRequest {
    @objc(_isim_windowDuration) var _objcWindowDuration: [NSNumber] {
        get { [NSNumber(value: windowDuration.value), NSNumber(value: windowDuration.timescale), NSNumber(value: windowDuration.flags.rawValue), NSNumber(value: windowDuration.epoch)] }
        set { if newValue.count >= 4 { windowDuration = CMTime(value: newValue[0].int64Value, timescale: newValue[1].int32Value, flags: CMTimeFlags(rawValue: newValue[2].uint32Value), epoch: newValue[3].int64Value) } }
    }
    /// the constraint: type (1 enumerated, 2 range), then the durations' or the range's CMTime fields
    @objc(_isim_windowDurationConstraint) var _objcWindowDurationConstraint: [NSNumber] {
        func t(_ c: CMTime) -> [NSNumber] { [NSNumber(value: c.value), NSNumber(value: c.timescale), NSNumber(value: c.flags.rawValue), NSNumber(value: c.epoch)] }
        switch windowDurationConstraint {
        case .enumeratedDurations(let d): return [1] + d.flatMap(t)
        case .durationRange(let r): return [2] + t(r.start) + t(r.duration)
        }
    }
}
extension SNClassificationResult {
    @objc(_isim_timeRange) var _objcTimeRange: [NSNumber] {
        let s = timeRange.start, d = timeRange.duration
        return [NSNumber(value: s.value), NSNumber(value: s.timescale), NSNumber(value: s.flags.rawValue), NSNumber(value: s.epoch),
                NSNumber(value: d.value), NSNumber(value: d.timescale), NSNumber(value: d.flags.rawValue), NSNumber(value: d.epoch)]
    }
}
extension SNClassifySoundRequest {
    /// Objective-C's initWithClassifierIdentifier:error: (the identifier is a string there)
    @objc(initWithClassifierIdentifier:error:) public convenience init(_objcClassifierIdentifier identifier: String) throws {
        try self.init(classifierIdentifier: SNClassifierIdentifier(rawValue: identifier))
    }
}
