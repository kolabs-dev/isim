// isim AVFoundation: the session's input and permission, AVAudioRecorder and writing AVAudioFiles (effects and the
// engine: AVAudioEngine.swift).
// Input: isim never opens the host microphone unless asked: ISIM_AUDIO_INPUT=<audio file> plays a file into the
// microphone in real time, ISIM_AUDIO_INPUT=mic records the host's default capture device; otherwise silence.
import isim_host

// MARK: - whole-buffer helpers (AVAudioPlayer's rate, file writing)

func _resample(_ x: [Float], by factor: Double) -> [Float] {
    // factor > 1 = faster / shorter (and higher pitched)
    guard factor > 0, !x.isEmpty else { return x }
    let n = max(1, Int(Double(x.count) / factor))
    var out = [Float](repeating: 0, count: n)
    for i in 0..<n {
        let p = Double(i) * factor, i0 = Int(p), t = Float(p - Double(i0))
        let a = x[min(i0, x.count - 1)], b = x[min(i0 + 1, x.count - 1)]
        out[i] = a + (b - a) * t
    }
    return out
}
/// Time stretch of a whole channel: output length = input length * stretch, pitch unchanged (AudioToolbox's WSOLA).
func _stretch(_ x: [Float], by stretch: Double, rate: Double) -> [Float] {
    guard stretch > 0, abs(stretch - 1) > 1e-4, !x.isEmpty else { return x }
    var pos = 0
    let st = _IsimStretcher()
    let out = st.render(Int(Double(x.count) * stretch), stretch: stretch, rate: rate) { k in
        let end = min(x.count, pos + k)
        var chunk = pos < end ? Array(x[pos..<end]) : []
        if chunk.count < k { chunk += [Float](repeating: 0, count: k - chunk.count) }
        pos += k
        return [chunk]
    }
    return out[0]
}

// MARK: - session permission (iOS 17 AVAudioApplication and AVAudioSession)

extension AVAudioSession {
    public enum RecordPermission: UInt, Sendable { case undetermined = 0x756E6474, denied = 0x64656E79, granted = 0x67726E74 }
    /// the microphone permission (the same answer as AVCaptureDevice.authorizationStatus(for: .audio))
    public var recordPermission: RecordPermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .undetermined
        }
    }
    /// the microphone privacy alert (NSMicrophoneUsageDescription; ISIM_MICROPHONE_PERMISSION=allow|deny answers it)
    public func requestRecordPermission(_ response: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in DispatchQueue.main.async { response(ok) } }
    }
    public var isInputAvailable: Bool { true }
    public var inputNumberOfChannels: Int { 1 }
    public var maximumInputNumberOfChannels: Int { 1 }
    public var preferredInputNumberOfChannels: Int { 1 }
    public func setPreferredInputNumberOfChannels(_ count: Int) throws {
        guard count == 1 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(AVAudioSession.ErrorCode.badParam.rawValue)) }
    }
    public var inputLatency: TimeInterval { 0.005 }
    public var outputLatency: TimeInterval { 0.01 }
    /// the render slice length of AVAudioEngine and I/O units (the preferred duration, 5...93 ms; 10 ms by default)
    public var ioBufferDuration: TimeInterval { _IsimSessionIO.ioBufferDuration }
    public var preferredIOBufferDuration: TimeInterval { _AVSessionPrefs.ioBuffer ?? 0 }
    /// isim's mixer runs at 48 kHz: the preferred rate is remembered but the hardware rate stays 48 kHz (iOS may
    /// also not honor it)
    public func setPreferredSampleRate(_ rate: Double) throws {
        guard rate >= 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(AVAudioSession.ErrorCode.badParam.rawValue)) }
        _AVSessionPrefs.sampleRate = rate
    }
    public func setPreferredIOBufferDuration(_ d: TimeInterval) throws {
        guard d >= 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(AVAudioSession.ErrorCode.badParam.rawValue)) }
        _AVSessionPrefs.ioBuffer = d
        _IsimSessionIO.ioBufferDuration = d == 0 ? 0.01 : (min(max(d, 0.005), 0.093) * 48000).rounded() / 48000
    }
    /// whether system alerts (an incoming call's banner, alarms) may interrupt the session: with `true`, isim's
    /// `audio interrupt begin alert` leaves it running
    public var prefersNoInterruptionsFromSystemAlerts: Bool { _AVSessionPrefs.noSystemAlertInterruptions }
    public func setPrefersNoInterruptionsFromSystemAlerts(_ inValue: Bool) throws { _AVSessionPrefs.noSystemAlertInterruptions = inValue }
    /// echo-cancelled input for the built-in microphone in the play-and-record category (adapted: the preference and
    /// availability follow iOS's rules; isim's input is not processed)
    @available(iOS 18.2, *)
    public var prefersEchoCancelledInput: Bool { _AVSessionPrefs.echoCancelledInput }
    @available(iOS 18.2, *)
    public func setPrefersEchoCancelledInput(_ value: Bool) throws { _AVSessionPrefs.echoCancelledInput = value }
    @available(iOS 18.2, *)
    public var isEchoCancelledInputAvailable: Bool {
        category == .playAndRecord && currentRoute.inputs.contains { $0.portType == .builtInMic }
    }
    @available(iOS 18.2, *)
    public var isEchoCancelledInputEnabled: Bool { _AVSessionPrefs.echoCancelledInput && isEchoCancelledInputAvailable }
    public var isInputGainSettable: Bool { true }
    public var inputGain: Float { _AVSessionPrefs.inputGain }
    public func setInputGain(_ gain: Float) throws { _AVSessionPrefs.inputGain = max(0, min(1, gain)); _IsimAudioInput.gain = _AVSessionPrefs.inputGain }
    public enum ErrorCode: Int, Error, Sendable {
        case none = 0, mediaServicesFailed = 0x6D73_7276, isBusy = 0x2161_6374, incompatibleCategory = 0x2163_6174, cannotInterruptOthers = 0x2169_6E74,
             missingEntitlement = 0x656E_743F, siriIsRecording = 0x7369_7269, cannotStartPlaying = 0x2170_6C61, cannotStartRecording = 0x2172_6563,
             badParam = -50, insufficientPriority = 0x2170_7269, resourceNotAvailable = 0x2172_6573, unspecified = 0x7768_6174,
             expiredSession = 0x2173_6573, sessionNotActive = 0x696E_6163
    }
}
enum _AVSessionPrefs {
    nonisolated(unsafe) static var sampleRate = 0.0
    nonisolated(unsafe) static var ioBuffer: TimeInterval?
    nonisolated(unsafe) static var inputGain: Float = 1
    nonisolated(unsafe) static var noSystemAlertInterruptions = false
    nonisolated(unsafe) static var echoCancelledInput = false
    /// the microphone prompt for AudioToolbox's input (installed by AVFoundation's entry points)
    static func installMicrophonePrompt() {
        guard _IsimAudioInput.requestPermission == nil else { return }
        _IsimAudioInput.requestPermission = { AVCaptureDevice.requestAccess(for: .audio) { _ in } }
    }
}
open class AVAudioApplication: NSObject {
    public enum recordPermission: Int, Sendable { case undetermined = 0x756E6474, denied = 0x64656E79, granted = 0x67726E74 }
    nonisolated(unsafe) static let _shared = AVAudioApplication()
    open class var shared: AVAudioApplication { _shared }
    open var recordPermission: AVAudioApplication.recordPermission {
        AVAudioApplication.recordPermission(rawValue: Int(AVAudioSession.shared.recordPermission.rawValue)) ?? .undetermined
    }
    /// muting silences the microphone for the app's input (AVAudioEngine, recorders, queues)
    open var isInputMuted = false
    open func setInputMuted(_ muted: Bool) throws {
        isInputMuted = muted
        _IsimAudioInput.muted = muted
        NotificationCenter.default.post(name: AVAudioApplication.inputMuteStateChangeNotification, object: self,
                                        userInfo: [AVAudioApplication.muteStateKey: muted])
    }
    public static let inputMuteStateChangeNotification = Notification.Name("AVAudioApplicationInputMuteStateChangeNotification")
    public static let muteStateKey = "AVAudioApplicationMuteStateKey"
    open class func requestRecordPermission(completionHandler response: @escaping (Bool) -> Void) { AVAudioSession.shared.requestRecordPermission(response) }
    @nonobjc open class func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { k in requestRecordPermission { k.resume(returning: $0) } }
    }
}

// MARK: - settings keys and file writing

public let AVFormatIDKey = "AVFormatIDKey"
public let AVSampleRateKey = "AVSampleRateKey"
public let AVNumberOfChannelsKey = "AVNumberOfChannelsKey"
public let AVLinearPCMBitDepthKey = "AVLinearPCMBitDepthKey"
public let AVLinearPCMIsBigEndianKey = "AVLinearPCMIsBigEndianKey"
public let AVLinearPCMIsFloatKey = "AVLinearPCMIsFloatKey"
public let AVLinearPCMIsNonInterleaved = "AVLinearPCMIsNonInterleaved"
public let AVEncoderAudioQualityKey = "AVEncoderAudioQualityKey"
public let AVEncoderBitRateKey = "AVEncoderBitRateKey"
public let AVEncoderBitDepthHintKey = "AVEncoderBitDepthHintKey"
public let AVSampleRateConverterAudioQualityKey = "AVSampleRateConverterAudioQualityKey"
public let AVSampleRateConverterAlgorithmKey = "AVSampleRateConverterAlgorithmKey"
public let AVChannelLayoutKey = "AVChannelLayoutKey"
public enum AVAudioQuality: Int, Sendable { case min = 0, low = 0x20, medium = 0x40, high = 0x60, max = 0x7F }

/// Collects PCM and writes WAV/CAF (16/24/32-bit int or 32-bit float); other containers via the host's ffmpeg.
final class _AudioFileWriter {
    let url: URL, rate: Double, channelCount: Int, bits: Int, isFloat: Bool
    var data: [[Float]]
    var closed = false
    var frames: Int { data.first?.count ?? 0 }
    init(url: URL, settings: [String: Any]) throws {
        self.url = url
        func num(_ k: String) -> Double? { (settings[k] as? NSNumber)?.doubleValue ?? (settings[k] as? Double) ?? (settings[k] as? Int).map(Double.init) ?? (settings[k] as? UInt32).map(Double.init) }
        rate = num(AVSampleRateKey) ?? 44100
        channelCount = max(1, min(8, Int(num(AVNumberOfChannelsKey) ?? 1)))
        isFloat = (settings[AVLinearPCMIsFloatKey] as? Bool) ?? false
        bits = isFloat ? 32 : [8, 16, 24, 32].contains(Int(num(AVLinearPCMBitDepthKey) ?? 16)) ? Int(num(AVLinearPCMBitDepthKey) ?? 16) : 16
        data = [[Float]](repeating: [], count: channelCount)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw _avError("isim AVFoundation: cannot create \(url.path)", code: -54)
        }
    }
    func append(_ b: AVAudioPCMBuffer) {
        b._syncFromRaw()
        let n = Int(b.frameLength)
        let src = b.channels.map { Array(UnsafeBufferPointer(start: $0, count: n)) }
        let conv = b.format.sampleRate == rate ? src : src.map { _resample($0, by: b.format.sampleRate / rate) }
        for c in 0..<channelCount { data[c].append(contentsOf: conv.isEmpty ? [] : conv[min(c, conv.count - 1)]) }
    }
    func append(interleavedStereo48k x: [Float]) {
        var l = [Float](), r = [Float]()
        l.reserveCapacity(x.count / 2); r.reserveCapacity(x.count / 2)
        for i in Swift.stride(from: 0, to: x.count - 1, by: 2) { l.append(x[i]); r.append(x[i + 1]) }
        let chans = channelCount == 1 ? [zip(l, r).map { ($0 + $1) * 0.5 }] : [l, r]
        let conv = rate == 48000 ? chans : chans.map { _resample($0, by: 48000 / rate) }
        for c in 0..<channelCount { data[c].append(contentsOf: conv[min(c, conv.count - 1)]) }
    }
    func finish() throws {
        guard !closed else { return }
        closed = true
        let ext = url.pathExtension.lowercased()
        if ext == "wav" || ext == "wave" { try wav().write(to: url); return }
        if ext == "caf" { try caf().write(to: url); return }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("isim-rec-\(UUID().uuidString).wav")
        try wav().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try? FileManager.default.removeItem(at: url)
        guard isim_media_transcode(tmp.path, url.path) != 0 else {
            throw _avError("isim AVFoundation: cannot encode \(url.lastPathComponent) (needs ffmpeg on the host)", code: 1718449215)
        }
    }
    func samples(bigEndian: Bool) -> [UInt8] {
        var out = [UInt8](); out.reserveCapacity(frames * channelCount * bits / 8)
        for i in 0..<frames {
            for c in 0..<channelCount {
                let x = max(-1, min(1, data[c][i]))
                var v: UInt32
                switch (isFloat, bits) {
                case (true, _): v = x.bitPattern
                case (_, 8): out.append(UInt8(clamping: Int((x * 127).rounded()) + 128)); continue
                case (_, 24): v = UInt32(bitPattern: Int32((Double(x) * 8388607).rounded()))
                case (_, 32): v = UInt32(bitPattern: Int32(max(-2147483647, min(2147483647, (Double(x) * 2147483647).rounded()))))
                default: v = UInt32(bitPattern: Int32((x * 32767).rounded()))
                }
                let nb = bits / 8
                for k in 0..<nb { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(bigEndian ? nb - 1 - k : k)))) }
            }
        }
        return out
    }
    func wav() -> Data {
        let body = samples(bigEndian: false)
        var d = [UInt8]()
        func s(_ x: String) { d.append(contentsOf: Array(x.utf8)) }
        func u32(_ v: Int) { for k in 0..<4 { d.append(UInt8(truncatingIfNeeded: v >> (8 * k))) } }
        func u16(_ v: Int) { for k in 0..<2 { d.append(UInt8(truncatingIfNeeded: v >> (8 * k))) } }
        let blockAlign = channelCount * bits / 8
        s("RIFF"); u32(36 + body.count); s("WAVE"); s("fmt "); u32(16); u16(isFloat ? 3 : 1); u16(channelCount)
        u32(Int(rate)); u32(Int(rate) * blockAlign); u16(blockAlign); u16(bits); s("data"); u32(body.count)
        d.append(contentsOf: body)
        return Data(d)
    }
    func caf() -> Data {
        let body = samples(bigEndian: false)
        var d = [UInt8]()
        func s(_ x: String) { d.append(contentsOf: Array(x.utf8)) }
        func be(_ v: UInt64, _ n: Int) { for k in (0..<n).reversed() { d.append(UInt8(truncatingIfNeeded: v >> (8 * UInt64(k)))) } }
        s("caff"); be(1, 2); be(0, 2)
        s("desc"); be(32, 8)
        be(rate.bitPattern, 8); s("lpcm"); be(UInt64((isFloat ? 1 : 0) | 2), 4)                // little-endian flag
        be(UInt64(channelCount * bits / 8), 4); be(1, 4); be(UInt64(channelCount), 4); be(UInt64(bits), 4)
        s("data"); be(UInt64(body.count + 4), 8); be(0, 4)
        d.append(contentsOf: body)
        return Data(d)
    }
}

// MARK: - AVAudioRecorder

@objc(AVAudioRecorderDelegate) public protocol AVAudioRecorderDelegate: NSObjectProtocol {
    @objc optional func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool)
    @objc optional func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?)
}

@objc(AVAudioRecorder) open class AVAudioRecorder: NSObject {
    @objc public let url: URL
    @objc public let settings: [String: Any]
    @objc public let format: AVAudioFormat
    @objc open weak var delegate: AVAudioRecorderDelegate?
    @objc open var isMeteringEnabled = false
    @objc open private(set) var isRecording = false
    var writer: _AudioFileWriter
    @objc var captured = 0                       // 48 kHz frames
    var limit: Double?
    @objc var last: [Float] = []                 // recent samples for metering
    @objc var avgDB: Float = -160, peakDB: Float = -160
    @objc var subscribed = false

    @objc(initWithURL:settings:error:) public init(url: URL, settings: [String: Any]) throws {
        _AVSessionPrefs.installMicrophonePrompt()
        self.url = url; self.settings = settings
        writer = try _AudioFileWriter(url: url, settings: settings)
        format = AVAudioFormat(standardFormatWithSampleRate: writer.rate, channels: AVAudioChannelCount(writer.channelCount))!
    }
    @objc(initWithURL:format:error:) public convenience init(url: URL, format: AVAudioFormat) throws {
        try self.init(url: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: Int(format.channelCount)])
    }
    deinit { if subscribed { _IsimAudioInput.unsubscribe(self) } }

    @objc open var currentTime: TimeInterval { Double(captured) / 48000 }
    @objc open var deviceCurrentTime: TimeInterval { isim_time() }
    @objc @discardableResult open func prepareToRecord() -> Bool { true }
    @objc @discardableResult open func record() -> Bool {
        guard !isRecording else { return true }
        if writer.closed, let w = try? _AudioFileWriter(url: url, settings: settings) { writer = w; captured = 0 }
        if subscribed { _IsimAudioInput.poll() }      // (resuming) drop nothing, just catch up
        isRecording = true
        if !subscribed { subscribed = true; _IsimAudioInput.subscribe(self) { [weak self] x in self?.received(x) } }
        return true
    }
    @objc @discardableResult open func record(atTime time: TimeInterval) -> Bool { record() }
    @objc @discardableResult open func record(forDuration duration: TimeInterval) -> Bool { limit = duration; return record() }
    @objc @discardableResult open func record(atTime time: TimeInterval, forDuration duration: TimeInterval) -> Bool { record(forDuration: duration) }
    @objc open func pause() {
        guard isRecording else { return }
        _IsimAudioInput.poll()
        isRecording = false
    }
    @objc open func stop() {
        if isRecording { _IsimAudioInput.poll() }
        isRecording = false
        if subscribed { _IsimAudioInput.unsubscribe(self); subscribed = false }
        var ok = true
        do { try writer.finish() } catch {
            ok = false
            delegate?.audioRecorderEncodeErrorDidOccur?(self, error: error)
        }
        let flag = ok
        DispatchQueue.main.async { self.delegate?.audioRecorderDidFinishRecording?(self, successfully: flag) }
    }
    @objc @discardableResult open func deleteRecording() -> Bool {
        guard !isRecording else { return false }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }
    @objc func received(_ chunk: [Float]) {
        guard isRecording else { return }
        var x = chunk
        if let l = limit {
            let room = max(0, Int(l * 48000) - captured)
            if x.count / 2 > room { x = Array(x[0..<(room * 2)]) }
        }
        captured += x.count / 2
        writer.append(interleavedStereo48k: x)
        if isMeteringEnabled { last = Array((last + x).suffix(4096)) }
        if let l = limit, Double(captured) >= l * 48000 { limit = nil; stop() }
    }
    @objc open func updateMeters() {
        guard !last.isEmpty else { avgDB = -160; peakDB = -160; return }
        var sum: Float = 0, peak: Float = 0
        for v in last { sum += v * v; peak = max(peak, abs(v)) }
        let rms = (sum / Float(last.count)).squareRoot()
        avgDB = rms > 0 ? max(-160, 20 * Float(log10(Double(rms)))) : -160
        peakDB = peak > 0 ? max(-160, 20 * Float(log10(Double(peak)))) : -160
    }
    @objc open func averagePower(forChannel channelNumber: Int) -> Float { avgDB }
    @objc open func peakPower(forChannel channelNumber: Int) -> Float { peakDB }
}
