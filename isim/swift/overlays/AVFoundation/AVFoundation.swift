// isim AVFoundation: AVAudioSession, AVAudioFile, AVAudioPCMBuffer, AVAudioFormat, AVAudioPlayer (this file);
// AVAudioEngine and its nodes (AVAudioEngine.swift); assets and video playback (AVAsset.swift, AVPlayer.swift); speech
// (AVSpeech.swift); recording, the session's input and AVAudioFile writing (AVAudioExtras.swift). Self-authored; sound goes
// to the host's mixer (libisim_host, SDL3 audio). Decodes linear-PCM CAF and WAV files itself; compressed formats
// and video are decoded by the host's ffmpeg (or GStreamer's gst-launch-1.0 for audio files); without them those
// fail to open like an unreadable file. Capture: Capture.swift; composition/export: AVComposition.swift.
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

@objc(AVAudioSession) open class AVAudioSession: NSObject {
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
        public static let videoChat = Mode(rawValue: "AVAudioSessionModeVideoChat")
        public static let videoRecording = Mode(rawValue: "AVAudioSessionModeVideoRecording")
        public static let measurement = Mode(rawValue: "AVAudioSessionModeMeasurement")
        public static let voicePrompt = Mode(rawValue: "AVAudioSessionModeVoicePrompt")
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
        /// a muted built-in microphone (an iPad's closed Smart Folio) doesn't interrupt the session
        public static let overrideMutedMicrophoneInterruption = CategoryOptions(rawValue: 128)
    }
    /// how the session's audio is routed relative to other apps (adapted: isim has one route, so the policy is kept and
    /// checked, not applied)
    public enum RouteSharingPolicy: UInt, Sendable {
        case `default` = 0, longFormAudio = 1, independent = 2, longFormVideo = 3
        @available(*, deprecated, renamed: "longFormAudio")
        public static var longForm: RouteSharingPolicy { .longFormAudio }
    }
    public struct SetActiveOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1)
    }
    nonisolated(unsafe) static let shared = AVAudioSession()
    /// isim: also starts listening for the `audio` script command (interruptions, route changes)
    @objc open class func sharedInstance() -> AVAudioSession {
        _AudioSessionEvents.start(); _AVSessionPrefs.installMicrophonePrompt(); _observeVolume()
        return shared
    }
    open private(set) var category: Category = .soloAmbient
    open private(set) var mode: Mode = .default
    open private(set) var categoryOptions: CategoryOptions = []
    @objc open var sampleRate: Double { 48000 }
    /// the device volume (isim's own: Control Center, MPVolumeView, `volume up|down`); key-value observable
    @objc open var outputVolume: Float { Float(isim_device_volume()) }
    nonisolated(unsafe) static var _volumeObserver: NSObjectProtocol?
    static func _observeVolume() {
        guard _volumeObserver == nil else { return }
        _volumeObserver = NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: nil) { n in
            guard let t = n.object as? String, t.hasPrefix("volume "), let v = Float(t.dropFirst(7)) else { return }
            shared.willChangeValue(forKey: "outputVolume")
            shared.didChangeValue(forKey: "outputVolume")
            NotificationCenter.default.post(name: Notification.Name("AVSystemController_SystemVolumeDidChangeNotification"), object: nil,
                                            userInfo: ["AVSystemController_AudioVolumeNotificationParameter": NSNumber(value: v),
                                                       "AVSystemController_AudioCategoryNotificationParameter": "Audio/Video"])
        }
    }
    @objc open var isOtherAudioPlaying: Bool { false }
    @objc open var secondaryAudioShouldBeSilencedHint: Bool { false }
    open func setCategory(_ category: Category) throws { self.category = category; _IsimBackgroundAudio.publish(category) }
    open func setCategory(_ category: Category, options: CategoryOptions = []) throws { self.category = category; categoryOptions = options; _IsimBackgroundAudio.publish(category) }
    open func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws { self.category = category; self.mode = mode; categoryOptions = options; _IsimBackgroundAudio.publish(category) }
    open func setMode(_ mode: Mode) throws { self.mode = mode }
    open private(set) var routeSharingPolicy: RouteSharingPolicy = .default
    /// the long-form policies are for the playback category only (iOS fails the call otherwise)
    open func setCategory(_ category: Category, mode: Mode, policy: RouteSharingPolicy, options: CategoryOptions = []) throws {
        if policy == .longFormAudio || policy == .longFormVideo, category != .playback {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(AVAudioSession.ErrorCode.badParam.rawValue))
        }
        try setCategory(category, mode: mode, options: options)
        routeSharingPolicy = policy
    }
    open func setActive(_ active: Bool, options: SetActiveOptions = []) throws {}
    public static let interruptionNotification = Notification.Name("AVAudioSessionInterruptionNotification")
    public static let routeChangeNotification = Notification.Name("AVAudioSessionRouteChangeNotification")
    public static let silenceSecondaryAudioHintNotification = Notification.Name("AVAudioSessionSilenceSecondaryAudioHintNotification")
}

/// The session category for UIKit's background execution (UIBackgroundModes audio + a playback category keep the app
/// playing in the background instead of being suspended): UIKit asks with the _IsimBackgroundQuery notification.
enum _IsimBackgroundAudio {
    nonisolated(unsafe) static var current = ""
    nonisolated(unsafe) static var registered = false
    static func publish(_ c: AVAudioSession.Category) {
        current = c.rawValue
        guard !registered else { return }
        registered = true
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimBackgroundQuery"), object: nil, queue: nil) { n in
            (n.object as? NSMutableDictionary)?.setObject(_IsimBackgroundAudio.current as NSString, forKey: "audioCategory" as NSString)
        }
    }
}

// MARK: - Formats and buffers

public enum AVAudioCommonFormat: UInt, Sendable { case otherFormat = 0, pcmFormatFloat32 = 1, pcmFormatFloat64 = 2, pcmFormatInt16 = 3, pcmFormatInt32 = 4 }

@objc(AVAudioFormat) open class AVAudioFormat: NSObject {
    @objc public let sampleRate: Double
    @objc public let channelCount: AVAudioChannelCount
    public let commonFormat: AVAudioCommonFormat
    @objc public let isInterleaved: Bool
    /// a stream description that is not one of the common PCM formats (compressed: AAC, ALAC, ...; or other PCM)
    var _other: AudioStreamBasicDescription?
    @objc var _layout: AVAudioChannelLayout?
    @objc(initStandardFormatWithSampleRate:channels:) public init?(standardFormatWithSampleRate rate: Double, channels: AVAudioChannelCount) {
        guard rate > 0, channels > 0 else { return nil }
        sampleRate = rate; channelCount = channels; commonFormat = .pcmFormatFloat32; isInterleaved = false
    }
    public init?(commonFormat: AVAudioCommonFormat, sampleRate: Double, channels: AVAudioChannelCount, interleaved: Bool) {
        guard sampleRate > 0, channels > 0 else { return nil }
        self.sampleRate = sampleRate; channelCount = channels; self.commonFormat = commonFormat; isInterleaved = interleaved
    }
    @objc(initStandardFormatWithSampleRate:channelLayout:) public init(standardFormatWithSampleRate rate: Double, channelLayout layout: AVAudioChannelLayout) {
        sampleRate = rate; channelCount = layout.channelCount; commonFormat = .pcmFormatFloat32; isInterleaved = false; _layout = layout
    }
    public init(commonFormat: AVAudioCommonFormat, sampleRate: Double, interleaved: Bool, channelLayout layout: AVAudioChannelLayout) {
        self.sampleRate = sampleRate; channelCount = layout.channelCount; self.commonFormat = commonFormat; isInterleaved = interleaved; _layout = layout
    }
    @objc init(_other asbd: AudioStreamBasicDescription, layout: AVAudioChannelLayout?) {
        sampleRate = asbd.mSampleRate; channelCount = asbd.mChannelsPerFrame; commonFormat = .otherFormat
        isInterleaved = !asbd._isNonInterleaved || asbd.mChannelsPerFrame <= 1; _other = asbd; _layout = layout
    }
    @objc open var isStandard: Bool { commonFormat == .pcmFormatFloat32 && !isInterleaved }
    @objc open var channelLayout: AVAudioChannelLayout? { _layout }
    /// the codec's magic cookie (an AAC esds or AudioSpecificConfig), for compressed formats
    @objc open var magicCookie: Data?
    @objc var _sd: UnsafeMutablePointer<AudioStreamBasicDescription>?
    deinit { _sd?.deallocate() }
    /// isim: linear PCM or compressed
    @objc var _isPCM: Bool { _other.map { $0._isPCM } ?? true }
    /// the stream description of this format
    @objc var _asbd: AudioStreamBasicDescription {
        if let o = _other { return o }
        let bits: UInt32 = commonFormat == .pcmFormatInt16 ? 16 : commonFormat == .pcmFormatFloat64 ? 64 : 32
        let isFloat = commonFormat == .pcmFormatFloat32 || commonFormat == .pcmFormatFloat64 || commonFormat == .otherFormat
        var flags = (isFloat ? kAudioFormatFlagIsFloat : kAudioFormatFlagIsSignedInteger) | kAudioFormatFlagIsPacked
        if !isInterleaved || channelCount == 1 { flags |= kAudioFormatFlagIsNonInterleaved }
        let frameBytes = bits / 8 * (isInterleaved && channelCount > 1 ? channelCount : 1)
        return AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: flags, mBytesPerPacket: frameBytes,
                                           mFramesPerPacket: 1, mBytesPerFrame: frameBytes, mChannelsPerFrame: channelCount, mBitsPerChannel: bits, mReserved: 0)
    }
    @objc open var streamDescription: UnsafePointer<AudioStreamBasicDescription> {
        if _sd == nil { _sd = .allocate(capacity: 1); _sd!.initialize(to: _asbd) }
        return UnsafePointer(_sd!)
    }
    /// Linear PCM (16/32-bit integer and 32/64-bit float are common formats, other PCM and compressed formats are
    /// `.otherFormat`). More than two channels need a layout, as on iOS.
    @objc public convenience init?(streamDescription asbd: UnsafePointer<AudioStreamBasicDescription>, channelLayout layout: AVAudioChannelLayout?) {
        let d = asbd.pointee
        guard d.mSampleRate > 0, d.mChannelsPerFrame > 0 else { return nil }
        if let layout, layout.channelCount != d.mChannelsPerFrame { return nil }
        if d.mChannelsPerFrame > 2 && layout == nil { return nil }
        let inter = d.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0 && d.mChannelsPerFrame > 1
        if d.mFormatID == kAudioFormatLinearPCM, !d._isBigEndian, d.mFormatFlags & kAudioFormatFlagIsPacked != 0 || d.mBitsPerChannel % 8 == 0 {
            let isFloat = d.mFormatFlags & kAudioFormatFlagIsFloat != 0
            let common: AVAudioCommonFormat? = isFloat ? (d.mBitsPerChannel == 64 ? .pcmFormatFloat64 : d.mBitsPerChannel == 32 ? .pcmFormatFloat32 : nil)
                : d.mBitsPerChannel == 16 ? .pcmFormatInt16 : d.mBitsPerChannel == 32 ? .pcmFormatInt32 : nil
            if let common {
                if let layout { self.init(commonFormat: common, sampleRate: d.mSampleRate, interleaved: inter, channelLayout: layout) }
                else { self.init(commonFormat: common, sampleRate: d.mSampleRate, channels: d.mChannelsPerFrame, interleaved: inter) }
                return
            }
        }
        self.init(_other: d, layout: layout)
    }
    @objc public convenience init?(streamDescription asbd: UnsafePointer<AudioStreamBasicDescription>) {
        self.init(streamDescription: asbd, channelLayout: nil)
    }
    public convenience init(cmAudioFormatDescription formatDescription: CMAudioFormatDescription) {
        var d = formatDescription.audioStreamBasicDescription ?? AudioStreamBasicDescription()
        if d.mSampleRate <= 0 { d.mSampleRate = 44100 }
        if d.mChannelsPerFrame == 0 { d.mChannelsPerFrame = 1 }
        let layout = d.mChannelsPerFrame > 2 ? AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | d.mChannelsPerFrame) : nil
        self.init(streamDescription: &d, channelLayout: layout)!
    }
    /// the CoreMedia description of this format (made on each call)
    open var formatDescription: CMAudioFormatDescription { CMFormatDescription(_audio: _asbd) }
    /// Linear PCM (the common formats) or a compressed format (AVFormatIDKey: AAC, ALAC, FLAC, Opus, ...).
    @objc public convenience init?(settings: [String: Any]) {
        func num(_ k: String) -> Double? { (settings[k] as? NSNumber)?.doubleValue ?? (settings[k] as? Double) ?? (settings[k] as? Int).map(Double.init)
            ?? (settings[k] as? UInt32).map(Double.init) }
        let rate = num(AVSampleRateKey) ?? 44100, ch = AVAudioChannelCount(num(AVNumberOfChannelsKey) ?? 2)
        let id = num(AVFormatIDKey).map { AudioFormatID($0) } ?? kAudioFormatLinearPCM
        let layout = (settings[AVChannelLayoutKey] as? Data).flatMap { d in
            d.withUnsafeBytes { b in b.count >= 12 ? AVAudioChannelLayout(layout: b.baseAddress!.assumingMemoryBound(to: AudioChannelLayout.self)) : nil }
        }
        if id != kAudioFormatLinearPCM {
            guard rate > 0, ch > 0 else { return nil }
            let frames: UInt32 = id == kAudioFormatMPEG4AAC ? 1024 : id == kAudioFormatAppleLossless ? 4096 : id == kAudioFormatMPEGLayer3 ? 1152
                : id == kAudioFormatOpus ? 960 : id == kAudioFormatAppleIMA4 ? 64 : id == kAudioFormatULaw || id == kAudioFormatALaw ? 1 : 0
            var d = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: id, mFormatFlags: 0, mBytesPerPacket: id == kAudioFormatULaw || id == kAudioFormatALaw ? ch : 0,
                                                mFramesPerPacket: frames, mBytesPerFrame: 0, mChannelsPerFrame: ch, mBitsPerChannel: 0, mReserved: 0)
            self.init(streamDescription: &d, channelLayout: layout ?? (ch > 2 ? AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | ch) : nil))
            return
        }
        let isFloat = (settings[AVLinearPCMIsFloatKey] as? Bool) ?? ((settings[AVLinearPCMIsFloatKey] as? NSNumber)?.boolValue ?? true)
        let bits = Int(num(AVLinearPCMBitDepthKey) ?? 32)
        let nonInter = (settings[AVLinearPCMIsNonInterleaved] as? Bool) ?? false
        let common: AVAudioCommonFormat = isFloat ? (bits == 64 ? .pcmFormatFloat64 : .pcmFormatFloat32) : bits == 16 ? .pcmFormatInt16 : .pcmFormatInt32
        if let layout, layout.channelCount == ch { self.init(commonFormat: common, sampleRate: rate, interleaved: !nonInter, channelLayout: layout); return }
        self.init(commonFormat: common, sampleRate: rate, channels: ch, interleaved: !nonInter)
    }
    @objc open var settings: [String: Any] {
        var s: [String: Any]
        if let o = _other, !o._isPCM {
            s = [AVFormatIDKey: o.mFormatID, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: Int(channelCount)]
        } else {
            let d = _asbd
            s = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: Int(channelCount),
                 AVLinearPCMBitDepthKey: Int(d.mBitsPerChannel), AVLinearPCMIsFloatKey: d._isFloat, AVLinearPCMIsBigEndianKey: d._isBigEndian,
                 AVLinearPCMIsNonInterleaved: !isInterleaved]
        }
        if let l = _layout { s[AVChannelLayoutKey] = l._data }
        return s
    }
    @objc open override func isEqual(_ o: Any?) -> Bool {
        guard let f = o as? AVAudioFormat else { return false }
        if _other != nil || f._other != nil { return _asbd == f._asbd && (_layout == nil || f._layout == nil || _layout == f._layout) }
        return f.sampleRate == sampleRate && f.channelCount == channelCount && f.commonFormat == commonFormat && f.isInterleaved == isInterleaved
            && (_layout == nil || f._layout == nil || _layout == f._layout)
    }
    @objc open override var hash: Int { sampleRate.hashValue ^ Int(channelCount) ^ Int(commonFormat.rawValue) << 8 }
    @objc open override var description: String {
        let d = _asbd
        return "<AVAudioFormat \(Int(channelCount)) ch, \(sampleRate) Hz, \(_isPCM ? (commonFormat == .otherFormat ? _PCMDescription(d) : "\(commonFormat)") : "'\(_fourCC(d.mFormatID))'")\(isInterleaved ? ", interleaved" : ", deinterleaved")>"
    }
}
func _fourCC(_ v: UInt32) -> String { String(decoding: [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)], as: UTF8.self) }
func _PCMDescription(_ d: AudioStreamBasicDescription) -> String { "\(d.mBitsPerChannel)-bit \(d._isFloat ? "float" : "integer")" }

/// A buffer of audio in an AVAudioFormat: PCM (AVAudioPCMBuffer) or compressed packets (AVAudioCompressedBuffer).
@objc(AVAudioBuffer) open class AVAudioBuffer: NSObject, NSCopying, NSMutableCopying {
    @objc public let format: AVAudioFormat
    @objc init(format: AVAudioFormat) { self.format = format }
    /// the buffer's data as a buffer list (sizes follow the valid data)
    @objc open var audioBufferList: UnsafePointer<AudioBufferList> { UnsafePointer(mutableAudioBufferList) }
    @objc open var mutableAudioBufferList: UnsafeMutablePointer<AudioBufferList> { fatalError("AVAudioBuffer is abstract") }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
    @objc open func mutableCopy(with zone: NSZone? = nil) -> Any { self }
}

/// PCM samples in the buffer's format. The common Float32 deinterleaved format (`isStandard`, what the engine renders)
/// is stored per channel and read by floatChannelData; Int16 / Int32 / Float64 and interleaved formats have their own
/// storage in that layout (int16ChannelData, int32ChannelData, `stride`), converted to floats where isim's engine
/// and files read them.
@objc(AVAudioPCMBuffer) open class AVAudioPCMBuffer: AVAudioBuffer {
    @objc public let frameCapacity: AVAudioFrameCount
    @objc open var frameLength: AVAudioFrameCount {
        didSet { if frameLength > frameCapacity { frameLength = frameCapacity }; invalidate() }
    }
    /// the float view of the samples (the storage itself for standard formats)
    let channels: [UnsafeMutablePointer<Float>]
    @objc let channelTable: UnsafeMutablePointer<UnsafeMutablePointer<Float>>
    /// the samples in the format's own layout, for non-standard formats: one buffer per channel, or one interleaved
    let _raw: [UnsafeMutableRawPointer]
    @objc let _rawTable: UnsafeMutablePointer<UnsafeMutableRawPointer>
    @objc var hostBuffer: Int32 = 0
    @objc(initWithPCMFormat:frameCapacity:) public init?(pcmFormat: AVAudioFormat, frameCapacity: AVAudioFrameCount) {
        guard frameCapacity > 0, pcmFormat._isPCM else { return nil }
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
        if pcmFormat.isStandard {
            _raw = channels.map { UnsafeMutableRawPointer($0) }
        } else {
            let d = pcmFormat._asbd
            let buffers = d._isNonInterleaved || n == 1 ? n : 1
            let bytes = Int(frameCapacity) * d._bytesPerSample * (buffers == 1 ? n : 1)
            _raw = (0..<buffers).map { _ in calloc(1, max(1, bytes))! }
        }
        _rawTable = UnsafeMutablePointer<UnsafeMutableRawPointer>.allocate(capacity: max(1, _raw.count))
        for (i, r) in _raw.enumerated() { _rawTable[i] = r }
        super.init(format: pcmFormat)
    }
    /// iOS 15: a buffer over memory the caller owns; isim copies the samples in (deallocator runs right away)
    @objc(initWithPCMFormat:bufferListNoCopy:deallocator:) public convenience init?(pcmFormat: AVAudioFormat, bufferListNoCopy: UnsafePointer<AudioBufferList>,
                             deallocator: ((UnsafePointer<AudioBufferList>) -> Void)? = nil) {
        let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferListNoCopy))
        let d = pcmFormat._asbd
        let perBuffer = d._isNonInterleaved || d.mChannelsPerFrame == 1 ? d._bytesPerSample : d._frameBytes
        let frames = list.count > 0 && perBuffer > 0 ? Int(list[0].mDataByteSize) / perBuffer : 0
        self.init(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(max(1, frames)))
        for (i, b) in list.enumerated() where i < _raw.count { if let src = b.mData { _raw[i].copyMemory(from: src, byteCount: min(Int(b.mDataByteSize), perBuffer * frames)) } }
        frameLength = AVAudioFrameCount(frames)
        _syncFromRaw()
        deallocator?(bufferListNoCopy)
    }
    deinit {
        if hostBuffer > 0 { isim_audio_buffer_release(hostBuffer) }
        if !format.isStandard { for r in _raw { free(r) } }
        for c in channels { c.deallocate() }
        channelTable.deallocate()
        _rawTable.deallocate()
        if let l = _abl { free(l.unsafeMutablePointer) }
    }
    /// Float32 samples: one pointer per channel (deinterleaved), or one interleaved pointer; nil for other formats.
    @objc open var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? {
        guard format.commonFormat == .pcmFormatFloat32 else { return nil }
        return format.isStandard ? UnsafePointer(channelTable) : UnsafeRawPointer(_rawTable).assumingMemoryBound(to: UnsafeMutablePointer<Float>.self)
    }
    @objc open var int16ChannelData: UnsafePointer<UnsafeMutablePointer<Int16>>? {
        format.commonFormat == .pcmFormatInt16 ? UnsafeRawPointer(_rawTable).assumingMemoryBound(to: UnsafeMutablePointer<Int16>.self) : nil
    }
    @objc open var int32ChannelData: UnsafePointer<UnsafeMutablePointer<Int32>>? {
        format.commonFormat == .pcmFormatInt32 ? UnsafeRawPointer(_rawTable).assumingMemoryBound(to: UnsafeMutablePointer<Int32>.self) : nil
    }
    var _abl: UnsafeMutableAudioBufferListPointer?
    /// the samples in the format's layout (sizes follow frameLength)
    @objc open override var mutableAudioBufferList: UnsafeMutablePointer<AudioBufferList> {
        let d = format._asbd
        let inter = _raw.count == 1 && channels.count > 1
        if _abl == nil {
            let l = AudioBufferList.allocate(maximumBuffers: max(1, _raw.count))
            for (i, r) in _raw.enumerated() { l[i] = AudioBuffer(mNumberChannels: inter ? UInt32(channels.count) : 1, mDataByteSize: 0, mData: r) }
            _abl = l
        }
        let l = _abl!
        let bytes = UInt32(inter ? d._frameBytes : d._bytesPerSample)
        for i in 0..<_raw.count { l[i].mDataByteSize = frameLength * bytes; l[i].mData = _raw[i] }
        return l.unsafeMutablePointer
    }
    /// samples between one frame's and the next one's in a channel (the channel count when interleaved)
    @objc open var stride: Int { _raw.count == 1 && channels.count > 1 ? channels.count : 1 }
    @objc open override func copy(with zone: NSZone? = nil) -> Any {
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        let n = Int(frameCapacity)
        for (i, c) in channels.enumerated() { b.channels[i].update(from: c, count: n) }
        if !format.isStandard {
            let d = format._asbd
            let bytes = n * d._bytesPerSample * (_raw.count == 1 ? channels.count : 1)
            for (i, r) in _raw.enumerated() { b._raw[i].copyMemory(from: r, byteCount: bytes) }
        }
        b.frameLength = frameLength
        return b
    }
    @objc open override func mutableCopy(with zone: NSZone? = nil) -> Any { copy(with: zone) }
    /// isim: the float view from the format's storage (after code wrote int16ChannelData, ...), for non-standard formats
    @objc func _syncFromRaw() {
        guard !format.isStandard else { return }
        let x = _IsimPCM.read(UnsafeMutableAudioBufferListPointer(mutableAudioBufferList), format._asbd, frames: Int(frameLength))
        for (c, dst) in channels.enumerated() where c < x.count { x[c].withUnsafeBufferPointer { dst.update(from: $0.baseAddress!, count: min($0.count, Int(frameCapacity))) } }
    }
    /// isim: the format's storage from the float view (after isim's code wrote floats), for non-standard formats
    @objc func _syncToRaw() {
        guard !format.isStandard else { return }
        let x = channels.map { Array(UnsafeBufferPointer(start: $0, count: Int(frameLength))) }
        _IsimPCM.fill(UnsafeMutableAudioBufferListPointer(mutableAudioBufferList), x, format._asbd, frames: Int(frameLength))
    }
    @objc func invalidate() { if hostBuffer > 0 { isim_audio_buffer_release(hostBuffer); hostBuffer = 0 } }
    /// Uploads the samples to the host mixer once (interleaved).
    @objc func host() -> Int32 {
        if hostBuffer > 0 { return hostBuffer }
        _syncFromRaw()
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

@objc(AVAudioFile) open class AVAudioFile: NSObject {
    @objc public let url: URL
    @objc public let fileFormat: AVAudioFormat
    @objc public let processingFormat: AVAudioFormat
    @objc open var length: AVAudioFramePosition { _writer.map { AVAudioFramePosition($0.frames) } ?? AVAudioFramePosition(decoded.channels.first?.count ?? 0) }
    @objc open var framePosition: AVAudioFramePosition = 0
    let decoded: _DecodedAudio
    var _writer: _AudioFileWriter?      // files opened for writing (AVAudioExtras.swift)
    @objc public init(forReading url: URL) throws {
        self.url = url
        decoded = try _AudioDecoder.decode(url)
        let ch = AVAudioChannelCount(decoded.channels.count)
        fileFormat = AVAudioFormat(standardFormatWithSampleRate: decoded.rate, channels: ch)!
        processingFormat = fileFormat
    }
    /// Writing: PCM WAV/CAF directly; other extensions (m4a, aac, mp3, flac, aiff) are encoded by the host's ffmpeg
    /// when the file is closed.
    @objc public init(forWriting url: URL, settings: [String: Any]) throws {
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
    @objc(writeFromBuffer:error:) open func write(from buffer: AVAudioPCMBuffer) throws {
        guard let w = _writer else { throw _avError("isim AVFoundation: \(url.lastPathComponent) is not open for writing") }
        w.append(buffer)
        framePosition = AVAudioFramePosition(w.frames)
    }
    @objc open var isOpen: Bool { _writer.map { !$0.closed } ?? true }
    @objc open func close() { try? _writer?.finish() }
    deinit { try? _writer?.finish() }
    public convenience init(forReading url: URL, commonFormat: AVAudioCommonFormat, interleaved: Bool) throws { try self.init(forReading: url) }
    @objc(readIntoBuffer:error:) open func read(into buffer: AVAudioPCMBuffer) throws { try read(into: buffer, frameCount: buffer.frameCapacity) }
    @objc(readIntoBuffer:frameCount:error:) open func read(into buffer: AVAudioPCMBuffer, frameCount: AVAudioFrameCount) throws {
        let n = Int(min(AVAudioFramePosition(min(frameCount, buffer.frameCapacity)), length - framePosition))
        guard n >= 0 else { return }
        let start = Int(framePosition)
        for (c, dst) in buffer.channels.enumerated() {
            let src = decoded.channels[min(c, decoded.channels.count - 1)]
            src.withUnsafeBufferPointer { s in dst.update(from: s.baseAddress! + start, count: n) }
        }
        buffer.frameLength = AVAudioFrameCount(n)
        buffer._syncToRaw()                                  // a buffer in another format (Int16, interleaved) gets the samples too
        framePosition += AVAudioFramePosition(n)
    }
}

// MARK: - AVAudioPlayer

@objc(AVAudioPlayerDelegate) public protocol AVAudioPlayerDelegate: NSObjectProtocol {
    @objc optional func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    @objc optional func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?)
}

@objc(AVAudioPlayer) open class AVAudioPlayer: NSObject {
    @objc public let url: URL?
    @objc public let data: Data?
    @objc let buffer: Int32
    @objc let sampleRate: Double
    @objc let frames: Int
    @objc let _pcm: [[Float]]              // decoded samples (metering, rate changes)
    @objc var _rateBuffer: Int32 = 0       // time-stretched copy for the current rate
    @objc var _rateOf: Float = 1
    @objc var voice = 0
    var pausedAt: Double?
    @objc var startOffset = 0.0
    @objc var generation = 0
    @objc var _voiceRate: Float = 1        // rate of the buffer the voice plays (positions scale by it)
    @objc weak open var delegate: AVAudioPlayerDelegate?
    @objc open var numberOfLoops = 0
    @objc open var volume: Float = 1 { didSet { if voice != 0 { isim_audio_set_volume(voice, Double(volume)) } } }
    @objc open func setVolume(_ volume: Float, fadeDuration duration: TimeInterval) { self.volume = volume }
    /// set before prepareToPlay()/play() to allow rate changes (like iOS)
    @objc open var enableRate = false
    /// 0.5...2.0; with enableRate, playback speed changes and pitch is kept (adapted: WSOLA time stretch)
    @objc open var rate: Float = 1 { didSet { rate = min(2, max(0.5, rate)); _rateChanged() } }
    /// -1 (left) ... 1 (right)
    @objc open var pan: Float = 0 { didSet { pan = min(1, max(-1, pan)); if voice != 0 { isim_audio_set_pan(voice, Double(pan)) } } }
    @objc open var isMeteringEnabled = false
    @objc var _avg: [Float] = [], _peak: [Float] = []
    @objc open var settings: [String: Any] { [AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: _pcm.count, AVFormatIDKey: kAudioFormatLinearPCM] }
    @objc open var format: AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(max(1, _pcm.count)))! }
    @objc open var deviceCurrentTime: TimeInterval { isim_time() }

    @objc(initWithContentsOfURL:error:) public init(contentsOf url: URL) throws {
        let d = try _AudioDecoder.decode(url)
        self.url = url; data = nil
        sampleRate = d.rate; frames = d.channels.first?.count ?? 0; _pcm = d.channels
        buffer = _AVPlayerUpload.upload(d)
        super.init()
        _AudioSessionEvents.register(self)
    }
    @objc(initWithContentsOfURL:fileTypeHint:error:) public convenience init(contentsOf url: URL, fileTypeHint: String?) throws { try self.init(contentsOf: url) }
    @objc public init(data: Data) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("isim-avplayer-\(UUID().uuidString)")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let d = try _AudioDecoder.decode(tmp)
        url = nil; self.data = data
        sampleRate = d.rate; frames = d.channels.first?.count ?? 0; _pcm = d.channels
        buffer = _AVPlayerUpload.upload(d)
        super.init()
        _AudioSessionEvents.register(self)
    }
    @objc public convenience init(data: Data, fileTypeHint: String?) throws { try self.init(data: data) }
    deinit {
        if voice != 0 { isim_audio_stop(voice) }
        if buffer > 0 { isim_audio_buffer_release(buffer) }
        if _rateBuffer > 0 { isim_audio_buffer_release(_rateBuffer) }
    }

    @objc open var duration: TimeInterval { sampleRate > 0 ? Double(frames) / sampleRate : 0 }
    @objc open var isPlaying: Bool { voice != 0 && isim_audio_is_playing(voice) != 0 }
    @objc open var numberOfChannels: Int { _pcm.count }
    /// position in the file (seconds), whatever the rate
    @objc open var currentTime: TimeInterval {
        get { if let p = pausedAt { return p }; return voice != 0 ? isim_audio_position(voice) * Double(_voiceRate) : startOffset }
        set {
            if voice != 0 { isim_audio_seek(voice, newValue / Double(_voiceRate)) }
            if pausedAt != nil { pausedAt = newValue } else if voice == 0 { startOffset = newValue }
        }
    }
    @objc var _effectiveRate: Float { enableRate ? rate : 1 }
    /// the host buffer for a rate (time-stretched once per rate)
    @objc func _buffer(for r: Float) -> Int32 {
        if r == 1 { return buffer }
        if _rateBuffer > 0 && _rateOf == r { return _rateBuffer }
        if _rateBuffer > 0 { isim_audio_buffer_release(_rateBuffer); _rateBuffer = 0 }
        let stretched = _pcm.map { _stretch($0, by: 1 / Double(r), rate: sampleRate) }
        _rateBuffer = _AVPlayerUpload.upload(_DecodedAudio(rate: sampleRate, channels: stretched))
        _rateOf = r
        return _rateBuffer
    }
    @objc func _rateChanged() {
        guard enableRate, voice != 0, _effectiveRate != _voiceRate else { return }
        let pos = currentTime, wasPaused = pausedAt != nil
        isim_audio_stop(voice); voice = 0
        _startVoice(at: pos)
        if wasPaused, voice != 0 { isim_audio_pause(voice, 1) } else { watch() }
    }
    @objc func _startVoice(at pos: Double) {
        let r = _effectiveRate
        let b = _buffer(for: r)
        voice = b > 0 ? isim_audio_play(b, Double(volume), Int32(numberOfLoops)) : 0
        _voiceRate = r
        if voice != 0 {
            if pan != 0 { isim_audio_set_pan(voice, Double(pan)) }
            if pos > 0 { isim_audio_seek(voice, pos / Double(r)) }
        }
    }
    @objc @discardableResult open func prepareToPlay() -> Bool { buffer > 0 }
    @objc @discardableResult open func play() -> Bool {
        guard buffer > 0 else { return false }
        if voice != 0, pausedAt != nil { isim_audio_pause(voice, 0); pausedAt = nil; watch(); return true }
        if isPlaying { return true }
        _startVoice(at: startOffset)
        startOffset = 0
        watch()
        return voice != 0
    }
    @objc @discardableResult open func play(atTime time: TimeInterval) -> Bool {
        let delay = time - deviceCurrentTime
        guard delay > 0.001 else { return play() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in _ = self?.play() }
        return buffer > 0
    }
    @objc open func pause() { guard voice != 0 else { return }; pausedAt = currentTime; isim_audio_pause(voice, 1); generation += 1 }
    @objc open func stop() {
        // like AVAudioPlayer: stop keeps the position; play() resumes from currentTime
        if voice != 0 { startOffset = currentTime; isim_audio_stop(voice); voice = 0 }
        pausedAt = nil; generation += 1
    }
    /// Metering: RMS and peak (dBFS, after volume) of the ~50 ms of audio at the playback position.
    @objc open func updateMeters() {
        guard isMeteringEnabled else { return }
        let n = max(1, Int(sampleRate * 0.05))
        let end = isPlaying ? Int(currentTime * sampleRate) : 0
        let start = max(0, end - n)
        _avg = []; _peak = []
        for ch in _pcm {
            var sum: Float = 0, pk: Float = 0
            let hi = min(ch.count, max(start, end))
            if hi > start { for i in start..<hi { let x = ch[i] * volume; sum += x * x; pk = max(pk, abs(x)) } }
            let rms = hi > start ? (sum / Float(hi - start)).squareRoot() : 0
            func db(_ x: Float) -> Float { x > 1e-8 ? max(-160, 20 * Float(log10(Double(x)))) : -160 }
            _avg.append(db(rms)); _peak.append(db(pk))
        }
    }
    @objc open func averagePower(forChannel c: Int) -> Float { c >= 0 && c < _avg.count ? _avg[c] : -160 }
    @objc open func peakPower(forChannel c: Int) -> Float { c >= 0 && c < _peak.count ? _peak[c] : -160 }

    /// Reports the end of playback to the delegate.
    @objc func watch() {
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
