// Professional capture (issue #876, part 3): SMPTE timecode and the timecode generator (iOS 26), the broadcast video
// output with its ancillary data encoder (iOS 27), the external display configurator (iOS 26) and the spatial audio
// metadata sample generator (iOS 26).
//
// Adapted: isim's cameras have no genlock, timecode or SDI hardware. The generator offers the frame-count and
// real-time-clock sources (no external sources), advancing with the simulated camera's frames. The broadcast output
// takes the frames it would send (counted, nothing is sent), and the encoder keeps its RDD 18 items. The external
// display configurator is active only while an external screen is connected (isim has none). The spatial audio
// generator measures the loudness of the audio it is given.
import Foundation
import CoreMedia
import UIKit

// MARK: - timecode

/// A SMPTE timecode: hours, minutes, seconds and frames at a frame duration, with 32 user bits.
@available(iOS 26.0, *)
public struct AVCaptureTimecode: Equatable, @unchecked Sendable {
    /// where a timecode comes from
    @objc public enum SourceType: Int, Sendable { case frameCount = 0, realTimeClock = 1, external = 2 }
    /// a timecode source the generator can follow
    public final class Source: NSObject, @unchecked Sendable {
        public let displayName: String
        public let type: SourceType
        public let uuid: UUID
        init(_ name: String, _ type: SourceType, _ uuid: UUID) { displayName = name; self.type = type; self.uuid = uuid }
        public override func isEqual(_ o: Any?) -> Bool { (o as? Source)?.uuid == uuid }
        public override var hash: Int { uuid.hashValue }
    }
    public var hours: UInt8
    public var minutes: UInt8
    public var seconds: UInt8
    public var frames: UInt8
    public var userBits: UInt32
    public var frameDuration: CMTime
    public var sourceType: SourceType
    public init() { self.init(hours: 0, minutes: 0, seconds: 0, frames: 0, userBits: 0, frameDuration: CMTime(value: 1, timescale: 30), sourceType: .frameCount) }
    public init(hours: UInt8, minutes: UInt8, seconds: UInt8, frames: UInt8, userBits: UInt32, frameDuration: CMTime, sourceType: SourceType) {
        self.hours = hours; self.minutes = minutes; self.seconds = seconds; self.frames = frames
        self.userBits = userBits; self.frameDuration = frameDuration; self.sourceType = sourceType
    }
    /// frames per second (whole: 30 for 1/30 s and for 1001/30000 s)
    var _fps: Int { frameDuration.isNumeric && frameDuration.seconds > 0 ? max(1, Int((1 / frameDuration.seconds).rounded())) : 30 }
    var _frameNumber: Int64 { ((Int64(hours) * 60 + Int64(minutes)) * 60 + Int64(seconds)) * Int64(_fps) + Int64(frames) }
    init(frameNumber n: Int64, like t: AVCaptureTimecode) {
        let fps = Int64(t._fps), day = 24 * 3600 * fps
        let f = ((n % day) + day) % day
        self.init(hours: UInt8(f / (3600 * fps)), minutes: UInt8(f / (60 * fps) % 60), seconds: UInt8(f / fps % 60), frames: UInt8(f % fps),
                  userBits: t.userBits, frameDuration: t.frameDuration, sourceType: t.sourceType)
    }
    /// a timecode `frames` frames later (or earlier), wrapping at 24 hours
    public static func advanced(_ timecode: AVCaptureTimecode, by frames: Int64) -> AVCaptureTimecode {
        AVCaptureTimecode(frameNumber: timecode._frameNumber + frames, like: timecode)
    }
    /// A timed metadata sample buffer carrying the timecode (isim: a metadata sample of the hours, minutes, seconds,
    /// frames bytes and the big-endian user bits), timed at a presentation time for one frame or for a duration.
    public static func createMetadataSampleBuffer(from timecode: AVCaptureTimecode, associatedWithPresentationTimeStamp pts: CMTime) -> Unmanaged<CMSampleBuffer>? {
        _buffer(timecode, CMSampleTimingInfo(duration: timecode.frameDuration, presentationTimeStamp: pts, decodeTimeStamp: .invalid))
    }
    public static func createMetadataSampleBuffer(from timecode: AVCaptureTimecode, forDuration duration: CMTime) -> Unmanaged<CMSampleBuffer>? {
        _buffer(timecode, CMSampleTimingInfo(duration: duration, presentationTimeStamp: .zero, decodeTimeStamp: .invalid))
    }
    static func _buffer(_ t: AVCaptureTimecode, _ timing: CMSampleTimingInfo) -> Unmanaged<CMSampleBuffer>? {
        let u = t.userBits
        let bytes: [UInt8] = [t.hours, t.minutes, t.seconds, t.frames, UInt8(u >> 24), UInt8(u >> 16 & 0xFF), UInt8(u >> 8 & 0xFF), UInt8(u & 0xFF)]
        let b = CMSampleBuffer(_block: CMBlockBuffer(_bytes: bytes), format: _timecodeMetadataFormat, count: 1, timings: [timing], sizes: [bytes.count])
        return Unmanaged.passRetained(b)
    }
    static let _timecodeMetadataFormat = CMFormatDescription(_metadata: 0x6D65_6278)          // 'mebx'
    public static func == (a: Self, b: Self) -> Bool {
        a.hours == b.hours && a.minutes == b.minutes && a.seconds == b.seconds && a.frames == b.frames && a.userBits == b.userBits
            && a.frameDuration == b.frameDuration && a.sourceType == b.sourceType
    }
}

@available(iOS 26.0, *)
public protocol AVCaptureTimecodeGeneratorDelegate: NSObjectProtocol {
    func timecodeGenerator(_ generator: AVCaptureTimecodeGenerator, didReceiveUpdate timecode: AVCaptureTimecode, from source: AVCaptureTimecode.Source)
    func timecodeGenerator(_ generator: AVCaptureTimecodeGenerator, didUpdateAvailableSources sources: [AVCaptureTimecode.Source])
    func timecodeGenerator(_ generator: AVCaptureTimecodeGenerator, transitionedTo synchronizationStatus: AVCaptureTimecodeGenerator.SynchronizationStatus,
                           for source: AVCaptureTimecode.Source)
}
@available(iOS 26.0, *)
extension AVCaptureTimecodeGeneratorDelegate {
    public func timecodeGenerator(_ generator: AVCaptureTimecodeGenerator, didUpdateAvailableSources sources: [AVCaptureTimecode.Source]) {}
    public func timecodeGenerator(_ generator: AVCaptureTimecodeGenerator, transitionedTo synchronizationStatus: AVCaptureTimecodeGenerator.SynchronizationStatus,
                                  for source: AVCaptureTimecode.Source) {}
}

/// Generates timecode for the frames of a session's camera (add it to the session like an output). The frame-count
/// source counts frames from 00:00:00:00; the real-time-clock source follows the time of day.
@available(iOS 26.0, *)
@objc(AVCaptureTimecodeGenerator) open class AVCaptureTimecodeGenerator: AVCaptureOutput, @unchecked Sendable {
    @objc public enum SynchronizationStatus: Int, Sendable {
        case unknown = 0, sourceSelected, synchronizing, synchronized, timedOut, sourceUnavailable, sourceUnsupported, notRequired
    }
    static let _frameCount = AVCaptureTimecode.Source("Frame Count", .frameCount, UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    static let _clock = AVCaptureTimecode.Source("Real-Time Clock", .realTimeClock, UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    public class var frameCountSource: AVCaptureTimecode.Source { _frameCount }
    public class var realTimeClockSource: AVCaptureTimecode.Source { _clock }
    public override init() { super.init() }
    open var availableSources: [AVCaptureTimecode.Source] { [Self._frameCount, Self._clock] }
    open private(set) var currentSource: AVCaptureTimecode.Source = AVCaptureTimecodeGenerator._frameCount
    open private(set) weak var delegate: (any AVCaptureTimecodeGeneratorDelegate)?
    open private(set) var delegateCallbackQueue: DispatchQueue?
    open var synchronizationTimeout: TimeInterval = 5
    open var timecodeAlignmentOffset: TimeInterval = 0
    open var timecodeFrameDuration = CMTime(value: 1, timescale: 30)
    var _frames: Int64 = 0
    let _lock = NSLock()
    open func setDelegate(_ delegate: (any AVCaptureTimecodeGeneratorDelegate)?, queue: DispatchQueue?) {
        self.delegate = delegate; delegateCallbackQueue = delegate == nil ? nil : queue
        let d = delegate, sources = availableSources
        (queue ?? .main).async { d?.timecodeGenerator(self, didUpdateAvailableSources: sources) }
    }
    /// switches to a source: the built-in ones need no synchronization; any other is not available on isim
    open func startSynchronization(source: AVCaptureTimecode.Source) {
        let d = delegate, q = delegateCallbackQueue ?? .main
        guard availableSources.contains(source) else {
            q.async { d?.timecodeGenerator(self, transitionedTo: .sourceUnavailable, for: source) }
            return
        }
        _lock.lock(); currentSource = source; _frames = 0; _lock.unlock()
        q.async {
            d?.timecodeGenerator(self, transitionedTo: .sourceSelected, for: source)
            d?.timecodeGenerator(self, transitionedTo: .notRequired, for: source)
        }
    }
    /// the timecode of the next frame from the current source
    open func generateInitialTimecode() -> AVCaptureTimecode {
        _lock.lock(); defer { _lock.unlock() }
        return _timecode(at: Date())
    }
    func _timecode(at date: Date) -> AVCaptureTimecode {
        var base = AVCaptureTimecode(); base.frameDuration = timecodeFrameDuration; base.sourceType = currentSource.type
        if currentSource.type == .realTimeClock {
            let c = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date.addingTimeInterval(timecodeAlignmentOffset))
            let n = (Int64(c.hour ?? 0) * 3600 + Int64(c.minute ?? 0) * 60 + Int64(c.second ?? 0)) * Int64(base._fps)
                + Int64(Double(c.nanosecond ?? 0) / 1e9 * Double(base._fps))
            return AVCaptureTimecode(frameNumber: n, like: base)
        }
        return AVCaptureTimecode(frameNumber: _frames, like: base)
    }
    override func _frame(_ f: _Frame, connection: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        _lock.lock()
        let t = _timecode(at: Date()), source = currentSource
        _frames += 1
        _lock.unlock()
        let d = delegate
        (delegateCallbackQueue ?? .main).async { d?.timecodeGenerator(self, didReceiveUpdate: t, from: source) }
        return nil
    }
}

// MARK: - broadcast output and ancillary data (iOS 27)

@available(iOS 27.0, *)
public struct AVCaptureAncillaryDataUserKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let rdd18InstanceUID = Self(rawValue: "AVCaptureAncillaryDataUserKeyRDD18InstanceUID")
    public static let rdd18UDAMSetVersion = Self(rawValue: "AVCaptureAncillaryDataUserKeyRDD18UDAMSetVersion")
    public static let rdd18UserItems = Self(rawValue: "AVCaptureAncillaryDataUserKeyRDD18UserItems")
}

/// Puts SMPTE RDD 18 camera metadata into a broadcast output's ancillary data (isim: kept, not transmitted)
@available(iOS 27.0, *)
@objc(AVCaptureAncillaryDataEncoder) open class AVCaptureAncillaryDataEncoder: NSObject, @unchecked Sendable {
    /// the space RDD 18 user items have in a frame's ancillary data packet
    static let capacity = 255
    open var isEnabled = true
    var _items: [UInt16: Data] = [:]
    var _instance: (UUID, NSNumber)?
    override init() { super.init() }
    open var currentUserDefinedAncillaryData: [AVCaptureAncillaryDataUserKey: Any] {
        var d: [AVCaptureAncillaryDataUserKey: Any] = [.rdd18UserItems: Dictionary(uniqueKeysWithValues: _items.map { (NSNumber(value: $0.key), $0.value) })]
        if let (uid, version) = _instance { d[.rdd18InstanceUID] = uid; d[.rdd18UDAMSetVersion] = version }
        return d
    }
    /// each item takes its bytes plus 3 (tag and length)
    open var userDefinedAncillaryDataSizeRemaining: Int16 { Int16(Self.capacity - _items.values.reduce(0) { $0 + $1.count + 3 }) }
    open func setRDD18AncillaryData(_ data: Data, forTag tag: UInt16) throws {
        let others = _items.filter { $0.key != tag }.values.reduce(0) { $0 + $1.count + 3 }
        guard others + data.count + 3 <= Self.capacity else { throw AVError(.operationNotAllowed, reason: "the RDD 18 user data does not fit in the ancillary data packet") }
        _items[tag] = data
    }
    open func setRDD18AncillaryDataString(_ string: String, forTag tag: UInt16) throws { try setRDD18AncillaryData(Data(string.utf8), forTag: tag) }
    open func removeRDD18AncillaryData(forTag tag: UInt16) { _items[tag] = nil }
    open func setUserInstanceUID(_ uid: UUID, forUserUDAMVersion version: NSNumber) { _instance = (uid, version) }
}

@available(iOS 27.0, *)
public protocol AVCaptureBroadcastVideoOutputDelegate: NSObjectProtocol {
    func broadcastVideoOutput(_ output: AVCaptureBroadcastVideoOutput, didDropVideoFrameWithPresentationTimeStamp presentationTimeStamp: CMTime,
                              from connection: AVCaptureConnection)
}

/// Sends the camera's frames to a broadcast (SDI) output with a fixed latency. isim has no such output: the frames
/// are taken and counted (`_isimFramesSent`), and none are dropped.
@available(iOS 27.0, *)
@objc(AVCaptureBroadcastVideoOutput) open class AVCaptureBroadcastVideoOutput: AVCaptureOutput, @unchecked Sendable {
    @objc public enum DroppedFrameReplacementPolicy: Int, Sendable { case repeatPreviousFrame = 0, blackFrame = 1 }
    public override init() { super.init() }
    open class var maxSupportedBufferedFrameCount: Int { 8 }
    open var videoSettings: [String: Any]?
    open var droppedFrameReplacementPolicy: DroppedFrameReplacementPolicy = .repeatPreviousFrame
    open var maxBufferedFrameCount = 2 { didSet { maxBufferedFrameCount = max(1, min(Self.maxSupportedBufferedFrameCount, maxBufferedFrameCount)) } }
    open private(set) weak var delegate: (any AVCaptureBroadcastVideoOutputDelegate)?
    open private(set) var delegateCallbackQueue: DispatchQueue?
    public let ancillaryDataEncoder = AVCaptureAncillaryDataEncoder()
    var _buffered = 0, _sent = 0
    let _lock = NSLock()
    open func setDelegate(_ delegate: (any AVCaptureBroadcastVideoOutputDelegate)?, queue: DispatchQueue?) {
        self.delegate = delegate; delegateCallbackQueue = delegate == nil ? nil : queue
    }
    /// empties the frame buffer (the next frames start a new latency)
    open func resetFrameBuffer() { _lock.lock(); _buffered = 0; _lock.unlock() }
    public var _isimFramesSent: Int { _lock.lock(); defer { _lock.unlock() }; return _sent }
    override func _frame(_ f: _Frame, connection: AVCaptureConnection, feed: _CameraFeed, synchronized: Bool) -> AVCaptureSynchronizedData? {
        guard connection._carries(.video) else { return nil }
        _lock.lock()
        if _buffered < maxBufferedFrameCount { _buffered += 1 } else { _sent += 1 }
        _lock.unlock()
        return nil
    }
}

// MARK: - external display (iOS 26)

@available(iOS 26.0, *)
@objc(AVCaptureExternalDisplayConfiguration) open class AVCaptureExternalDisplayConfiguration: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open var shouldMatchFrameRate = true
    open var bypassColorSpaceConversion = false
    open var preferredResolution = CMVideoDimensions(width: 0, height: 0)
}
/// Shows a camera's preview on an external display at the camera's frame rate and resolution. isim has no external
/// displays: the configurator stays inactive.
@available(iOS 26.0, *)
@objc(AVCaptureExternalDisplayConfigurator) open class AVCaptureExternalDisplayConfigurator: NSObject, @unchecked Sendable {
    open class var isMatchingFrameRateSupported: Bool { true }
    open class var isBypassingColorSpaceConversionSupported: Bool { false }
    open class var isPreferredResolutionSupported: Bool { true }
    public private(set) weak var device: AVCaptureDevice?
    public private(set) weak var previewLayer: CALayer?
    let _configuration: AVCaptureExternalDisplayConfiguration
    var _stopped = false
    public init(device: AVCaptureDevice, previewLayer: CALayer, configuration: AVCaptureExternalDisplayConfiguration) {
        self.device = device; self.previewLayer = previewLayer; _configuration = configuration
        super.init()
    }
    /// active while an external screen is connected and the configurator has not been stopped
    @objc open dynamic var isActive: Bool { !_stopped && UIScreen.screens.count > 1 }
    open var activeExternalDisplayFrameRate: Double {
        guard isActive, _configuration.shouldMatchFrameRate, let d = device else { return 0 }
        return 1 / d.activeVideoMinFrameDuration.seconds
    }
    open func stop() { willChangeValue(forKey: "isActive"); _stopped = true; didChangeValue(forKey: "isActive") }
}

// MARK: - spatial audio metadata (iOS 26)

/// Analyzes the audio of a recording to make the timed metadata a spatial (Audio Mix) track needs. isim measures the
/// loudness of the samples it is given: the metadata sample holds the peak and RMS levels (Float32, linear).
@available(iOS 26.0, *)
@objc(AVCaptureSpatialAudioMetadataSampleGenerator) open class AVCaptureSpatialAudioMetadataSampleGenerator: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    var _peak: Float = 0, _sumSquares: Double = 0, _count = 0
    var _start: CMTime = .invalid, _end: CMTime = .invalid
    open var timedMetadataSampleBufferFormatDescription: CMFormatDescription { _format }
    let _format = CMFormatDescription(_metadata: 0x6D65_6278)                               // 'mebx'
    /// adds a buffer of 16-bit or Float32 PCM to the analysis
    open func analyzeAudioSample(_ sbuf: CMSampleBuffer) -> OSStatus {
        guard let asbd = sbuf._format?.audioStreamBasicDescription, let bytes = sbuf._block?._bytes else { return -12731 }  // kCMSampleBufferError_RequiredParameterMissing
        let float = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        bytes.withUnsafeBytes { raw in
            if float { for v in raw.bindMemory(to: Float.self) { _add(v) } }
            else { for v in raw.bindMemory(to: Int16.self) { _add(Float(v) / 32768) } }
        }
        let t = sbuf._timing
        if !_start.isValid { _start = t.presentationTimeStamp }
        _end = t.presentationTimeStamp + (t.duration.isNumeric ? t.duration : CMTime(value: CMTimeValue(sbuf._numSamples), timescale: CMTimeScale(max(1, asbd.mSampleRate))))
        return noErr
    }
    func _add(_ v: Float) { _peak = max(_peak, abs(v)); _sumSquares += Double(v * v); _count += 1 }
    /// the metadata sample for everything analyzed since the last reset, then a reset
    open func newTimedMetadataSampleBufferAndResetAnalyzer() -> Unmanaged<CMSampleBuffer>? {
        guard _count > 0 else { return nil }
        var levels: [Float] = [_peak, Float((_sumSquares / Double(_count)).squareRoot())]
        let bytes = levels.withUnsafeMutableBytes { Array($0) }
        let timing = CMSampleTimingInfo(duration: _end - _start, presentationTimeStamp: _start, decodeTimeStamp: .invalid)
        let b = CMSampleBuffer(_block: CMBlockBuffer(_bytes: bytes), format: _format, count: 1, timings: [timing], sizes: [bytes.count])
        resetAnalyzer()
        return Unmanaged.passRetained(b)
    }
    open func resetAnalyzer() { _peak = 0; _sumSquares = 0; _count = 0; _start = .invalid; _end = .invalid }
}
