// isim AVFoundation: AVAudioSession, AVAudioEngine/AVAudioPlayerNode/AVAudioMixerNode, AVAudioFile, AVAudioPCMBuffer,
// AVAudioFormat, AVAudioPlayer (this file); assets and video playback (AVAsset.swift, AVPlayer.swift); speech
// (AVSpeech.swift); effects, offline rendering, input and recording (AVAudioExtras.swift). Self-authored; sound goes
// to the host's mixer (libisim_host, SDL3 audio). Decodes linear-PCM CAF and WAV files itself; compressed formats
// and video are decoded by the host's ffmpeg (or GStreamer's gst-launch-1.0 for audio files); without them those
// fail to open like an unreadable file. No capture devices (camera), composition/export or 3D audio.
@_exported import Foundation
@_exported import CoreMedia
@_exported import AudioToolbox
import isim_host

public typealias AVAudioFrameCount = UInt32
public typealias AVAudioFramePosition = Int64
public typealias AVAudioChannelCount = UInt32
public typealias AVAudioNodeBus = Int

public let AVFoundationErrorDomain = "AVFoundationErrorDomain"
func _avError(_ msg: String, code: Int = -11828) -> NSError {
    NSError(domain: NSOSStatusErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: msg])
}
public let NSOSStatusErrorDomain = "NSOSStatusErrorDomain"

// MARK: - Session

open class AVAudioSession: NSObject {
    public struct Category: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let ambient = Category(rawValue: "AVAudioSessionCategoryAmbient")
        public static let soloAmbient = Category(rawValue: "AVAudioSessionCategorySoloAmbient")
        public static let playback = Category(rawValue: "AVAudioSessionCategoryPlayback")
        public static let record = Category(rawValue: "AVAudioSessionCategoryRecord")
        public static let playAndRecord = Category(rawValue: "AVAudioSessionCategoryPlayAndRecord")
        public static let multiRoute = Category(rawValue: "AVAudioSessionCategoryMultiRoute")
    }
    public struct Mode: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let `default` = Mode(rawValue: "AVAudioSessionModeDefault")
        public static let gameChat = Mode(rawValue: "AVAudioSessionModeGameChat")
        public static let moviePlayback = Mode(rawValue: "AVAudioSessionModeMoviePlayback")
        public static let spokenAudio = Mode(rawValue: "AVAudioSessionModeSpokenAudio")
        public static let voiceChat = Mode(rawValue: "AVAudioSessionModeVoiceChat")
    }
    public struct CategoryOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mixWithOthers = CategoryOptions(rawValue: 1)
        public static let duckOthers = CategoryOptions(rawValue: 2)
        public static let allowBluetooth = CategoryOptions(rawValue: 4)
        public static let defaultToSpeaker = CategoryOptions(rawValue: 8)
        public static let interruptSpokenAudioAndMixWithOthers = CategoryOptions(rawValue: 17)
        public static let allowBluetoothA2DP = CategoryOptions(rawValue: 32)
        public static let allowAirPlay = CategoryOptions(rawValue: 64)
    }
    public struct SetActiveOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1)
    }
    nonisolated(unsafe) static let shared = AVAudioSession()
    open class func sharedInstance() -> AVAudioSession { shared }
    open private(set) var category: Category = .soloAmbient
    open private(set) var mode: Mode = .default
    open private(set) var categoryOptions: CategoryOptions = []
    open var sampleRate: Double { 48000 }
    open var outputVolume: Float { 1 }
    open var isOtherAudioPlaying: Bool { false }
    open var secondaryAudioShouldBeSilencedHint: Bool { false }
    open func setCategory(_ category: Category) throws { self.category = category }
    open func setCategory(_ category: Category, options: CategoryOptions = []) throws { self.category = category; categoryOptions = options }
    open func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws { self.category = category; self.mode = mode; categoryOptions = options }
    open func setMode(_ mode: Mode) throws { self.mode = mode }
    open func setActive(_ active: Bool, options: SetActiveOptions = []) throws {}
    public static let interruptionNotification = Notification.Name("AVAudioSessionInterruptionNotification")
    public static let routeChangeNotification = Notification.Name("AVAudioSessionRouteChangeNotification")
    public static let silenceSecondaryAudioHintNotification = Notification.Name("AVAudioSessionSilenceSecondaryAudioHintNotification")
}

// MARK: - Formats and buffers

public enum AVAudioCommonFormat: UInt, Sendable { case otherFormat = 0, pcmFormatFloat32 = 1, pcmFormatFloat64 = 2, pcmFormatInt16 = 3, pcmFormatInt32 = 4 }

open class AVAudioFormat: NSObject {
    public let sampleRate: Double
    public let channelCount: AVAudioChannelCount
    public let commonFormat: AVAudioCommonFormat
    public let isInterleaved: Bool
    public init?(standardFormatWithSampleRate rate: Double, channels: AVAudioChannelCount) {
        guard rate > 0, channels > 0 else { return nil }
        sampleRate = rate; channelCount = channels; commonFormat = .pcmFormatFloat32; isInterleaved = false
    }
    public init?(commonFormat: AVAudioCommonFormat, sampleRate: Double, channels: AVAudioChannelCount, interleaved: Bool) {
        guard sampleRate > 0, channels > 0 else { return nil }
        self.sampleRate = sampleRate; channelCount = channels; self.commonFormat = commonFormat; isInterleaved = interleaved
    }
    public var isStandard: Bool { commonFormat == .pcmFormatFloat32 && !isInterleaved }
    open override func isEqual(_ o: Any?) -> Bool {
        guard let f = o as? AVAudioFormat else { return false }
        return f.sampleRate == sampleRate && f.channelCount == channelCount && f.commonFormat == commonFormat && f.isInterleaved == isInterleaved
    }
}

open class AVAudioBuffer: NSObject {
    public let format: AVAudioFormat
    init(format: AVAudioFormat) { self.format = format }
}

/// Deinterleaved Float32 PCM.
open class AVAudioPCMBuffer: AVAudioBuffer {
    public let frameCapacity: AVAudioFrameCount
    open var frameLength: AVAudioFrameCount {
        didSet { if frameLength > frameCapacity { frameLength = frameCapacity }; invalidate() }
    }
    let channels: [UnsafeMutablePointer<Float>]
    let channelTable: UnsafeMutablePointer<UnsafeMutablePointer<Float>>
    var hostBuffer: Int32 = 0
    public init?(pcmFormat: AVAudioFormat, frameCapacity: AVAudioFrameCount) {
        guard frameCapacity > 0 else { return nil }
        self.frameCapacity = frameCapacity
        frameLength = 0
        let n = Int(pcmFormat.channelCount)
        channels = (0..<n).map { _ in
            let p = UnsafeMutablePointer<Float>.allocate(capacity: Int(frameCapacity))
            p.initialize(repeating: 0, count: Int(frameCapacity))
            return p
        }
        channelTable = UnsafeMutablePointer<UnsafeMutablePointer<Float>>.allocate(capacity: max(1, n))
        for (i, c) in channels.enumerated() { channelTable[i] = c }
        super.init(format: pcmFormat)
    }
    deinit {
        if hostBuffer > 0 { isim_audio_buffer_release(hostBuffer) }
        for c in channels { c.deallocate() }
        channelTable.deallocate()
    }
    open var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? { UnsafePointer(channelTable) }
    open var stride: Int { 1 }
    func invalidate() { if hostBuffer > 0 { isim_audio_buffer_release(hostBuffer); hostBuffer = 0 } }
    /// Uploads the samples to the host mixer once (interleaved).
    func host() -> Int32 {
        if hostBuffer > 0 { return hostBuffer }
        let frames = Int(frameLength), ch = channels.count
        guard frames > 0, ch > 0 else { return 0 }
        var inter = [Float](repeating: 0, count: frames * ch)
        for c in 0..<ch { let src = channels[c]; for i in 0..<frames { inter[i * ch + c] = src[i] } }
        hostBuffer = inter.withUnsafeBufferPointer { isim_audio_buffer_create($0.baseAddress, frames, Int32(ch), format.sampleRate) }
        return hostBuffer
    }
}

// MARK: - Files

/// Decoded PCM of an audio file (Float32, deinterleaved per channel).
struct _DecodedAudio { var rate: Double; var channels: [[Float]] }

enum _AudioDecoder {
    static func decode(_ url: URL) throws -> _DecodedAudio {
        do { return try decodePCM(url) } catch let pcmError {
            // not linear PCM: let the host decode it (AAC, ALAC, MP3, FLAC, Ogg, ...)
            var out: UnsafeMutablePointer<Float>? = nil
            var frames = 0, channels: Int32 = 0, rate = 0.0
            guard isim_audio_decode_file(url.path, &out, &frames, &channels, &rate) != 0, let pcm = out else { throw pcmError }
            defer { isim_audio_free(pcm) }
            let ch = Int(channels)
            var deinter = [[Float]](repeating: [Float](repeating: 0, count: frames), count: ch)
            for c in 0..<ch { deinter[c].withUnsafeMutableBufferPointer { d in for i in 0..<frames { d[i] = pcm[i * ch + c] } } }
            return _DecodedAudio(rate: rate, channels: deinter)
        }
    }
    static func decodePCM(_ url: URL) throws -> _DecodedAudio {
        let data = try Data(contentsOf: url)
        let b = [UInt8](data)
        func be32(_ o: Int) -> UInt32 { UInt32(b[o]) << 24 | UInt32(b[o + 1]) << 16 | UInt32(b[o + 2]) << 8 | UInt32(b[o + 3]) }
        func le32(_ o: Int) -> UInt32 { UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24 }
        func le16(_ o: Int) -> UInt16 { UInt16(b[o]) | UInt16(b[o + 1]) << 8 }
        if b.count >= 8, b[0] == 0x63, b[1] == 0x61, b[2] == 0x66, b[3] == 0x66 {          // "caff"
            var o = 8
            var rate = 0.0, fmt: UInt32 = 0, flags: UInt32 = 0, bytesPerFrame: UInt32 = 0, chans: UInt32 = 0, bits: UInt32 = 0
            while o + 12 <= b.count {
                let type = String(decoding: b[o..<o + 4], as: UTF8.self)
                let size = Int(UInt64(be32(o + 4)) << 32 | UInt64(be32(o + 8)))
                let body = o + 12
                if type == "desc" {
                    rate = Double(bitPattern: UInt64(be32(body)) << 32 | UInt64(be32(body + 4)))
                    // AudioStreamBasicDescription: rate(8) formatID flags bytesPerPacket framesPerPacket channels bits
                    fmt = be32(body + 8); flags = be32(body + 12); bytesPerFrame = be32(body + 16)
                    chans = be32(body + 24); bits = be32(body + 28)
                } else if type == "data" {
                    guard fmt == 0x6C70636D else {                         // 'lpcm'
                        throw _avError("isim AVFoundation: \(url.lastPathComponent): only linear PCM CAF files can be decoded on isim")
                    }
                    let start = body + 4                                    // edit count
                    let end = size == -1 || size < 0 ? b.count : min(b.count, body + size)
                    let littleEndian = flags & 2 != 0, isFloat = flags & 1 != 0
                    return try pcm(b, start, end, rate, Int(chans), Int(bits), Int(bytesPerFrame), littleEndian, isFloat, url)
                }
                guard size >= 0 else { break }
                o = body + size
            }
            throw _avError("isim AVFoundation: \(url.lastPathComponent): malformed CAF file")
        }
        if b.count >= 12, String(decoding: b[0..<4], as: UTF8.self) == "RIFF", String(decoding: b[8..<12], as: UTF8.self) == "WAVE" {
            var o = 12
            var rate = 0.0, chans = 0, bits = 0, fmtTag = 0
            while o + 8 <= b.count {
                let id = String(decoding: b[o..<o + 4], as: UTF8.self)
                let size = Int(le32(o + 4))
                if id == "fmt " {
                    fmtTag = Int(le16(o + 8)); chans = Int(le16(o + 10)); rate = Double(le32(o + 12)); bits = Int(le16(o + 22))
                } else if id == "data" {
                    guard fmtTag == 1 || fmtTag == 3 || fmtTag == 0xFFFE else {
                        throw _avError("isim AVFoundation: \(url.lastPathComponent): only PCM WAV files can be decoded on isim")
                    }
                    return try pcm(b, o + 8, min(b.count, o + 8 + size), rate, chans, bits, chans * bits / 8, true, fmtTag == 3, url)
                }
                o += 8 + size + (size & 1)
            }
            throw _avError("isim AVFoundation: \(url.lastPathComponent): malformed WAV file")
        }
        throw _avError("isim AVFoundation: \(url.lastPathComponent): this audio format (\(url.pathExtension)) cannot be decoded on isim (PCM CAF/WAV; compressed formats need the host's ffmpeg or GStreamer)")
    }

    static func pcm(_ b: [UInt8], _ start: Int, _ end: Int, _ rate: Double, _ chans: Int, _ bits: Int, _ frameBytes: Int,
                    _ little: Bool, _ isFloat: Bool, _ url: URL) throws -> _DecodedAudio {
        guard chans > 0, rate > 0, frameBytes > 0, [8, 16, 24, 32].contains(bits) else {
            throw _avError("isim AVFoundation: \(url.lastPathComponent): unsupported PCM layout (\(bits)-bit, \(chans) channels)")
        }
        let frames = (end - start) / frameBytes
        let sb = bits / 8
        var out = [[Float]](repeating: [Float](repeating: 0, count: frames), count: chans)
        for f in 0..<frames {
            for c in 0..<chans {
                let o = start + f * frameBytes + c * sb
                var v: UInt32 = 0
                for k in 0..<sb { v |= UInt32(b[o + (little ? k : sb - 1 - k)]) << (8 * UInt32(k)) }
                let x: Float
                if isFloat && bits == 32 { x = Float(bitPattern: v) }
                else if bits == 8 { x = (Float(v) - 128) / 128 }
                else {
                    let shift = UInt32(32 - bits)
                    x = Float(Int32(bitPattern: v << shift) >> Int32(shift)) / Float(1 << (bits - 1))
                }
                out[c][f] = x
            }
        }
        return _DecodedAudio(rate: rate, channels: out)
    }
}

open class AVAudioFile: NSObject {
    public let url: URL
    public let fileFormat: AVAudioFormat
    public let processingFormat: AVAudioFormat
    open var length: AVAudioFramePosition { _writer.map { AVAudioFramePosition($0.frames) } ?? AVAudioFramePosition(decoded.channels.first?.count ?? 0) }
    open var framePosition: AVAudioFramePosition = 0
    let decoded: _DecodedAudio
    var _writer: _AudioFileWriter?      // files opened for writing (AVAudioExtras.swift)
    public init(forReading url: URL) throws {
        self.url = url
        decoded = try _AudioDecoder.decode(url)
        let ch = AVAudioChannelCount(decoded.channels.count)
        fileFormat = AVAudioFormat(standardFormatWithSampleRate: decoded.rate, channels: ch)!
        processingFormat = fileFormat
    }
    /// Writing: PCM WAV/CAF directly; other extensions (m4a, aac, mp3, flac, aiff) are encoded by the host's ffmpeg
    /// when the file is closed.
    public init(forWriting url: URL, settings: [String: Any]) throws {
        self.url = url
        let w = try _AudioFileWriter(url: url, settings: settings)
        _writer = w
        decoded = _DecodedAudio(rate: w.rate, channels: [])
        fileFormat = AVAudioFormat(standardFormatWithSampleRate: w.rate, channels: AVAudioChannelCount(w.channelCount))!
        processingFormat = fileFormat
    }
    public convenience init(forWriting url: URL, settings: [String: Any], commonFormat: AVAudioCommonFormat, interleaved: Bool) throws {
        try self.init(forWriting: url, settings: settings)
    }
    open func write(from buffer: AVAudioPCMBuffer) throws {
        guard let w = _writer else { throw _avError("isim AVFoundation: \(url.lastPathComponent) is not open for writing") }
        w.append(buffer)
        framePosition = AVAudioFramePosition(w.frames)
    }
    open var isOpen: Bool { _writer.map { !$0.closed } ?? true }
    open func close() { try? _writer?.finish() }
    deinit { try? _writer?.finish() }
    public convenience init(forReading url: URL, commonFormat: AVAudioCommonFormat, interleaved: Bool) throws { try self.init(forReading: url) }
    open func read(into buffer: AVAudioPCMBuffer) throws { try read(into: buffer, frameCount: buffer.frameCapacity) }
    open func read(into buffer: AVAudioPCMBuffer, frameCount: AVAudioFrameCount) throws {
        let n = Int(min(AVAudioFramePosition(min(frameCount, buffer.frameCapacity)), length - framePosition))
        guard n >= 0 else { return }
        let start = Int(framePosition)
        for (c, dst) in buffer.channels.enumerated() {
            let src = decoded.channels[min(c, decoded.channels.count - 1)]
            src.withUnsafeBufferPointer { s in dst.update(from: s.baseAddress! + start, count: n) }
        }
        buffer.frameLength = AVAudioFrameCount(n)
        framePosition += AVAudioFramePosition(n)
    }
}

// MARK: - Engine

public struct AVAudioTime: Sendable {
    public var sampleTime: AVAudioFramePosition
    public var sampleRate: Double
    public init(sampleTime: AVAudioFramePosition, atRate rate: Double) { self.sampleTime = sampleTime; sampleRate = rate }
}

open class AVAudioNode: NSObject {
    weak var engine: AVAudioEngine?
    open func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)! }
    open func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat { outputFormat(forBus: bus) }
    open func reset() {}
}

open class AVAudioMixerNode: AVAudioNode {
    open var outputVolume: Float = 1 { didSet { engine?.volumesChanged() } }
    open var volume: Float = 1 { didSet { engine?.volumesChanged() } }
    open var pan: Float = 0
}
open class AVAudioOutputNode: AVAudioNode {}

public struct AVAudioPlayerNodeBufferOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let loops = AVAudioPlayerNodeBufferOptions(rawValue: 1)
    public static let interrupts = AVAudioPlayerNodeBufferOptions(rawValue: 2)
    public static let interruptsAtLoop = AVAudioPlayerNodeBufferOptions(rawValue: 4)
}
public enum AVAudioPlayerNodeCompletionCallbackType: Int, Sendable { case dataConsumed, dataRendered, dataPlayedBack }

/// Plays scheduled buffers one after another; each runs as a voice in the host mixer.
open class AVAudioPlayerNode: AVAudioNode {
    struct Item { let buffer: AVAudioPCMBuffer; let options: AVAudioPlayerNodeBufferOptions; let completion: (() -> Void)? }
    // offline (manual rendering) state: the processed current item, pulled by AVAudioEngine.renderOffline
    var _offItem: Item?
    var _offPCM: [[Float]] = []
    var _offPos = 0
    var queue: [Item] = []
    var voice = 0
    var current: Item?
    var generation = 0
    open private(set) var isPlaying = false
    open var volume: Float = 1 { didSet { applyVolume() } }
    open var pan: Float = 0
    var effectiveVolume: Double { Double(volume) * Double(engine?.mainMixerNode.outputVolume ?? 1) * Double(engine?.mainMixerNode.volume ?? 1) }

    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime? = nil, options: AVAudioPlayerNodeBufferOptions = [], completionHandler: (() -> Void)? = nil) {
        let item = Item(buffer: buffer, options: options, completion: completionHandler)
        if options.contains(.interrupts) || options.contains(.interruptsAtLoop) {
            stopVoice(); queue = [item]
        } else {
            queue.append(item)
        }
        if isPlaying && voice == 0 { startNext() }
    }
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, completionHandler: (() -> Void)? = nil) {
        scheduleBuffer(buffer, at: nil, options: [], completionHandler: completionHandler)
    }
    open func scheduleFile(_ file: AVAudioFile, at when: AVAudioTime?, completionHandler: (() -> Void)? = nil) {
        guard let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(max(1, file.length))) else { return }
        file.framePosition = 0
        try? file.read(into: b)
        scheduleBuffer(b, at: when, options: [], completionHandler: completionHandler)
    }
    open func play() {
        guard engine?.isRunning ?? false else { NSLog("isim AVFoundation: player started while the engine is not running"); return }
        if isPlaying, voice != 0 { isim_audio_pause(voice, 0); return }
        isPlaying = true
        if voice == 0 { startNext() } else { isim_audio_pause(voice, 0) }
    }
    open func play(at when: AVAudioTime?) { play() }
    open func pause() { isPlaying = false; if voice != 0 { isim_audio_pause(voice, 1) } }
    open func stop() { isPlaying = false; stopVoice(); queue = []; _offItem = nil; _offPCM = []; _offPos = 0 }
    open override func reset() { stop() }
    func stopVoice() { if voice != 0 { isim_audio_stop(voice); voice = 0 }; current = nil; generation += 1 }
    func applyVolume() { if voice != 0 { isim_audio_set_volume(voice, effectiveVolume) } }

    func startNext() {
        guard isPlaying, !queue.isEmpty else { voice = 0; return }
        if engine?._manual != nil { return }          // renderOffline pulls the queue
        let item = queue.removeFirst()
        current = item
        let loops = item.options.contains(.loops)
        let processed = engine?._applyEffects(item.buffer, from: self) ?? item.buffer   // effect nodes downstream
        let hb = processed.host()
        voice = hb > 0 ? isim_audio_play(hb, effectiveVolume, loops ? -1 : 0) : 0
        generation += 1
        guard !loops else { return }
        let gen = generation
        let seconds = Double(processed.frameLength) / processed.format.sampleRate
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.voice = 0
            self.current = nil
            item.completion?()
            self.startNext()
        }
    }
}

open class AVAudioEngine: NSObject {
    public let mainMixerNode = AVAudioMixerNode()
    public let outputNode = AVAudioOutputNode()
    var nodes: [AVAudioNode] = []
    var _outputs: [ObjectIdentifier: AVAudioNode] = [:]     // node -> the node its output is connected to
    var _manual: _ManualRendering?
    var _inputNode: AVAudioInputNode?
    /// The microphone (isim: ISIM_AUDIO_INPUT, see AVAudioExtras.swift).
    open var inputNode: AVAudioInputNode {
        if let n = _inputNode { return n }
        let n = AVAudioInputNode(); n.engine = self; _inputNode = n
        return n
    }
    open private(set) var isRunning = false
    public override init() {
        super.init()
        mainMixerNode.engine = self
        outputNode.engine = self
    }
    open var attachedNodes: Set<AVAudioNode> { Set(nodes) }
    open func attach(_ node: AVAudioNode) { node.engine = self; if !nodes.contains(node) { nodes.append(node) } }
    open func detach(_ node: AVAudioNode) { (node as? AVAudioPlayerNode)?.stop(); nodes.removeAll { $0 === node } }
    open func connect(_ a: AVAudioNode, to b: AVAudioNode, format: AVAudioFormat?) { _outputs[ObjectIdentifier(a)] = b }
    open func connect(_ a: AVAudioNode, to b: AVAudioNode, fromBus: AVAudioNodeBus, toBus: AVAudioNodeBus, format: AVAudioFormat?) { _outputs[ObjectIdentifier(a)] = b }
    open func disconnectNodeOutput(_ node: AVAudioNode) { _outputs[ObjectIdentifier(node)] = nil }
    open func disconnectNodeOutput(_ node: AVAudioNode, bus: AVAudioNodeBus) { _outputs[ObjectIdentifier(node)] = nil }
    open func prepare() {}
    open func start() throws {
        _ = isim_audio_available()     // opens the device (or reports that sound is unavailable)
        isRunning = true
    }
    open func pause() { isRunning = false; for case let p as AVAudioPlayerNode in nodes { p.pause() } }
    open func stop() { isRunning = false; for case let p as AVAudioPlayerNode in nodes { p.stop() }; _inputNode?._stopCapture() }
    open func reset() { for n in nodes { n.reset() } }
    func volumesChanged() { for case let p as AVAudioPlayerNode in nodes { p.applyVolume() } }
}

// MARK: - AVAudioPlayer

@objc public protocol AVAudioPlayerDelegate: NSObjectProtocol {
    @objc optional func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    @objc optional func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?)
}

open class AVAudioPlayer: NSObject {
    public let url: URL?
    public let data: Data?
    let buffer: Int32
    let sampleRate: Double
    let frames: Int
    var voice = 0
    var pausedAt: Double?
    var startOffset = 0.0
    var generation = 0
    weak open var delegate: AVAudioPlayerDelegate?
    open var numberOfLoops = 0
    open var volume: Float = 1 { didSet { if voice != 0 { isim_audio_set_volume(voice, Double(volume)) } } }
    open var enableRate = false
    open var rate: Float = 1
    open var pan: Float = 0
    open var isMeteringEnabled = false

    public init(contentsOf url: URL) throws {
        let d = try _AudioDecoder.decode(url)
        self.url = url; data = nil
        sampleRate = d.rate; frames = d.channels.first?.count ?? 0
        buffer = _AVPlayerUpload.upload(d)
        super.init()
    }
    public convenience init(contentsOf url: URL, fileTypeHint: String?) throws { try self.init(contentsOf: url) }
    public init(data: Data) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("isim-avplayer-\(UUID().uuidString)")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let d = try _AudioDecoder.decode(tmp)
        url = nil; self.data = data
        sampleRate = d.rate; frames = d.channels.first?.count ?? 0
        buffer = _AVPlayerUpload.upload(d)
        super.init()
    }
    deinit { if voice != 0 { isim_audio_stop(voice) }; if buffer > 0 { isim_audio_buffer_release(buffer) } }

    open var duration: TimeInterval { sampleRate > 0 ? Double(frames) / sampleRate : 0 }
    open var isPlaying: Bool { voice != 0 && isim_audio_is_playing(voice) != 0 }
    open var numberOfChannels: Int { 1 }
    open var currentTime: TimeInterval {
        get { if let p = pausedAt { return p }; return voice != 0 ? isim_audio_position(voice) : startOffset }
        set {
            if voice != 0 { isim_audio_seek(voice, newValue) }
            if pausedAt != nil { pausedAt = newValue } else if voice == 0 { startOffset = newValue }
        }
    }
    @discardableResult open func prepareToPlay() -> Bool { buffer > 0 }
    @discardableResult open func play() -> Bool {
        guard buffer > 0 else { return false }
        if voice != 0, pausedAt != nil { isim_audio_pause(voice, 0); pausedAt = nil; watch(); return true }
        if isPlaying { return true }
        voice = isim_audio_play(buffer, Double(volume), Int32(numberOfLoops))
        if startOffset > 0 { isim_audio_seek(voice, startOffset); startOffset = 0 }
        watch()
        return voice != 0
    }
    @discardableResult open func play(atTime time: TimeInterval) -> Bool { play() }
    open func pause() { guard voice != 0 else { return }; pausedAt = isim_audio_position(voice); isim_audio_pause(voice, 1); generation += 1 }
    open func stop() {
        // like AVAudioPlayer: stop keeps the position; play() resumes from currentTime
        if voice != 0 { startOffset = isim_audio_position(voice); isim_audio_stop(voice); voice = 0 }
        pausedAt = nil; generation += 1
    }
    open func updateMeters() {}
    open func averagePower(forChannel c: Int) -> Float { -160 }
    open func peakPower(forChannel c: Int) -> Float { -160 }

    /// Reports the end of playback to the delegate.
    func watch() {
        generation += 1
        let gen = generation
        func poll() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self, self.generation == gen, self.voice != 0 else { return }
                if isim_audio_is_playing(self.voice) == 0 && self.pausedAt == nil {
                    self.voice = 0; self.startOffset = 0
                    self.delegate?.audioPlayerDidFinishPlaying?(self, successfully: true)
                } else { poll() }
            }
        }
        poll()
    }
}

enum _AVPlayerUpload {
    static func upload(_ d: _DecodedAudio) -> Int32 {
        let ch = d.channels.count, frames = d.channels.first?.count ?? 0
        guard ch > 0, frames > 0 else { return 0 }
        var inter = [Float](repeating: 0, count: frames * ch)
        for c in 0..<ch { for i in 0..<frames { inter[i * ch + c] = d.channels[c][i] } }
        return inter.withUnsafeBufferPointer { isim_audio_buffer_create($0.baseAddress, frames, Int32(ch), d.rate) }
    }
}
