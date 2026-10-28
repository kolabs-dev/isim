// isim AVFoundation: composition and export (AVComposition, AVMutableComposition, AVMutableCompositionTrack,
// AVAssetExportSession, AVMutableVideoComposition render size), AVAssetReader (decoded video frames and PCM audio) and
// AVAssetWriter (+ input pixel buffer adaptor). Self-authored, iOS API names. All encoding and decoding is done by the
// host's ffmpeg in child processes (host_capture.c); without ffmpeg exports and writers fail with AVError.exportFailed.
// Adapted:
// - Compositions are edit lists of (source file, source range, destination time); exporting renders them with one
//   ffmpeg filter graph (trim + concat, black/silence for gaps). scaleTimeRange changes segment speed (setpts/atempo).
// - Presets map to x264/AAC settings ("Passthrough" stream-copies plain assets; compositions are always re-encoded).
// - HEVC is encoded with libx265 when the host's ffmpeg has it, else H.264. No ProRes, no video composition
//   instructions (layer transforms, opacity ramps), no audio mix ramps, no metadata items.
// - AVAssetReader reads local AVURLAssets; AVAssetWriter writes when finishWriting is called (frames are spooled to a
//   temporary file until then).
import UIKit
import isim_host

public struct AVFileType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let mov = AVFileType("com.apple.quicktime-movie")
    public static let mp4 = AVFileType("public.mpeg-4")
    public static let m4v = AVFileType("com.apple.m4v-video")
    public static let m4a = AVFileType("com.apple.m4a-audio")
    public static let wav = AVFileType("com.microsoft.waveform-audio")
    public static let caf = AVFileType("com.apple.coreaudio-format")
    public static let aiff = AVFileType("public.aiff-audio")
    public static let aifc = AVFileType("public.aifc-audio")
    public static let mp3 = AVFileType("public.mp3")
    public static let ac3 = AVFileType("public.ac3-audio")
    public static let heic = AVFileType("public.heic")
    public static let jpg = AVFileType("public.jpeg")
    public static let mobile3GPP = AVFileType("public.3gpp")
    /// ffmpeg muxer and whether the container takes video
    var _muxer: (String, Bool) {
        switch self {
        case .mov: return ("mov", true)
        case .mp4: return ("mp4", true)
        case .m4v: return ("ipod", true)
        case .mobile3GPP: return ("3gp", true)
        case .m4a: return ("ipod", false)
        case .wav: return ("wav", false)
        case .caf: return ("caf", false)
        case .aiff, .aifc: return ("aiff", false)
        case .mp3: return ("mp3", false)
        case .ac3: return ("ac3", false)
        default: return ("mp4", true)
        }
    }
    static func from(extension e: String) -> AVFileType {
        switch e.lowercased() { case "mov", "qt": return .mov; case "m4v": return .m4v; case "m4a": return .m4a; case "wav": return .wav
        case "caf": return .caf; case "aif", "aiff": return .aiff; case "mp3": return .mp3; case "3gp": return .mobile3GPP; default: return .mp4 }
    }
}

// MARK: video settings keys
public let AVVideoCodecKey = "AVVideoCodecKey"
public let AVVideoWidthKey = "AVVideoWidthKey"
public let AVVideoHeightKey = "AVVideoHeightKey"
public let AVVideoCompressionPropertiesKey = "AVVideoCompressionPropertiesKey"
public let AVVideoAverageBitRateKey = "AVVideoAverageBitRateKey"
public let AVVideoQualityKey = "AVVideoQualityKey"
public let AVVideoMaxKeyFrameIntervalKey = "AVVideoMaxKeyFrameIntervalKey"
public let AVVideoExpectedSourceFrameRateKey = "AVVideoExpectedSourceFrameRateKey"
public let AVVideoProfileLevelKey = "AVVideoProfileLevelKey"
public let AVVideoScalingModeKey = "AVVideoScalingModeKey"
public let AVVideoScalingModeResizeAspect = "AVVideoScalingModeResizeAspect"
public let AVVideoScalingModeResizeAspectFill = "AVVideoScalingModeResizeAspectFill"
public let AVVideoScalingModeResize = "AVVideoScalingModeResize"
public let AVVideoScalingModeFit = "AVVideoScalingModeFit"
public let AVVideoProfileLevelH264HighAutoLevel = "H264_High_AutoLevel"
public let AVVideoProfileLevelH264MainAutoLevel = "H264_Main_AutoLevel"
public let AVVideoProfileLevelH264BaselineAutoLevel = "H264_Baseline_AutoLevel"

func _num(_ d: [String: Any]?, _ k: String) -> Double? {
    guard let v = d?[k] else { return nil }
    if let n = v as? NSNumber { return n.doubleValue }
    if let x = v as? Double { return x }
    if let x = v as? Int { return Double(x) }
    if let x = v as? UInt32 { return Double(x) }
    if let x = v as? Float { return Double(x) }
    return nil
}

// MARK: - ffmpeg

/// An NSError in AVFoundationErrorDomain with a failure reason (isim's runtime does not bridge CustomNSError user info).
func _avNSError(_ code: AVError.Code, _ reason: String) -> NSError {
    NSError(domain: AVFoundationErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: AVError(code).errorDescription ?? "The operation could not be completed",
                                                                            NSLocalizedFailureReasonErrorKey: reason])
}

enum _FFmpeg {
    /// Runs ffmpeg with args; returns nil on success, else an NSError (AVError domain). progress: output seconds.
    static func run(_ args: [String], progress: UnsafeMutablePointer<Double>? = nil, cancel: UnsafeMutablePointer<Int32>? = nil) -> NSError? {
        let cs = args.map { strdup($0) }
        defer { cs.forEach { free($0) } }
        var err = [CChar](repeating: 0, count: 4096)
        let ptrs: [UnsafePointer<CChar>?] = cs.map { UnsafePointer($0) }
        let rc = ptrs.withUnsafeBufferPointer { isim_ffmpeg_run($0.baseAddress!, Int32(args.count), progress, cancel, &err, 4096) }
        if rc == 0 { return nil }
        let msg = String(cString: err).trimmingCharacters(in: .whitespacesAndNewlines)
        if rc == -2 { return NSError(domain: NSCocoaErrorDomain, code: 3072 /* NSUserCancelledError */, userInfo: [NSLocalizedDescriptionKey: "Cancelled"]) }
        let reason = rc == -1 ? "isim needs ffmpeg on the host to encode media" : "ffmpeg: " + (msg.isEmpty ? "exit status \(rc)" : String(msg.suffix(600)))
        NSLog("isim AVFoundation: %@", reason)
        return _avNSError(.exportFailed, reason)
    }
    /// libx265 present in the host's ffmpeg?
    nonisolated(unsafe) static var _hevc: Bool?
    static var hasHEVC: Bool {
        if let h = _hevc { return h }
        let tmp = NSTemporaryDirectory() + "isim-hevc-\(getpid()).mp4"
        let ok = run(["-y", "-f", "lavfi", "-i", "color=c=black:s=64x64:d=0.04", "-c:v", "libx265", "-frames:v", "1", tmp]) == nil
        try? FileManager.default.removeItem(atPath: tmp)
        _hevc = ok
        return ok
    }
    static func videoCodecArgs(_ codec: AVVideoCodecType?, bitrate: Double?) -> [String] {
        var a: [String]
        switch codec {
        case .some(.jpeg): a = ["-c:v", "mjpeg", "-q:v", "3"]
        case .some(.hevc), .some(.hevcWithAlpha):
            a = hasHEVC ? ["-c:v", "libx265", "-preset", "veryfast", "-tag:v", "hvc1"] : ["-c:v", "libx264", "-preset", "veryfast"]
        default: a = ["-c:v", "libx264", "-preset", "veryfast"]
        }
        if let b = bitrate, b > 0, codec != .jpeg { a += ["-b:v", String(Int(b))] }
        if codec != .jpeg { a += ["-pix_fmt", "yuv420p"] }
        return a
    }
    static func audioCodecArgs(_ settings: [String: Any]?, fileType: AVFileType) -> [String] {
        let id = _num(settings, AVFormatIDKey).map { AudioFormatID($0) }
        let lpcm = id == kAudioFormatLinearPCM || (id == nil && [.wav, .caf, .aiff, .aifc].contains(fileType))
        if lpcm {
            let bits = Int(_num(settings, AVLinearPCMBitDepthKey) ?? 16)
            let float = (settings?[AVLinearPCMIsFloatKey] as? Bool) ?? false
            let big = fileType == .aiff || ((settings?[AVLinearPCMIsBigEndianKey] as? Bool) ?? false)
            let c = float ? (bits == 64 ? "pcm_f64" : "pcm_f32") : bits == 8 ? "pcm_u8" : bits == 24 ? "pcm_s24" : bits == 32 ? "pcm_s32" : "pcm_s16"
            return ["-c:a", c + (bits == 8 && !float ? "" : big ? "be" : "le")]
        }
        if fileType == .mp3 { return ["-c:a", "libmp3lame"] }
        var a = ["-c:a", id == kAudioFormatAppleLossless ? "alac" : id == kAudioFormatFLAC ? "flac" : "aac"]
        if let b = _num(settings, AVEncoderBitRateKey), b > 0 { a += ["-b:a", String(Int(b))] }
        return a
    }
}
func _path(_ u: URL) -> String { u.isFileURL ? u.path : u.absoluteString }

// MARK: - composition

/// A segment of a composition track: `source` (file) range `sourceRange` placed at `target`, lasting `duration`
/// (different from sourceRange.duration when scaled).
public final class AVCompositionTrackSegment: NSObject, @unchecked Sendable {
    public let isEmpty: Bool
    let _url: URL?
    let _sourceRange: CMTimeRange
    var _target: CMTimeRange
    let _sourceTrackID: CMPersistentTrackID
    init(url: URL?, sourceRange: CMTimeRange, target: CMTimeRange, trackID: CMPersistentTrackID) {
        _url = url; _sourceRange = sourceRange; _target = target; _sourceTrackID = trackID; isEmpty = url == nil
    }
    public convenience init(timeRange: CMTimeRange) { self.init(url: nil, sourceRange: timeRange, target: timeRange, trackID: 0) }
    public var sourceURL: URL? { _url }
    public var sourceTrackID: CMPersistentTrackID { _sourceTrackID }
    public var timeMapping: CMTimeMapping { CMTimeMapping(source: _sourceRange, target: _target) }
}

open class AVCompositionTrack: AVAssetTrack, @unchecked Sendable {
    var _segments: [AVCompositionTrackSegment] { get { _segmentList } set { _segmentList = newValue } }
    open var segments: [AVCompositionTrackSegment] { _segments }
    var _segmentList: [AVCompositionTrackSegment] = [] { didSet { _updateRange() } }
    func _updateRange() {
        let end = _segmentList.map { $0._target.end.seconds }.max() ?? 0
        _timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: end, preferredTimescale: 600))
    }
    open func segment(forTrackTime t: CMTime) -> AVCompositionTrackSegment? { _segments.first { $0._target.containsTime(t) } }
}

open class AVMutableCompositionTrack: AVCompositionTrack, @unchecked Sendable {
    var _transform = CGAffineTransform.identity
    var _volume: Float = 1
    open override var preferredTransform: CGAffineTransform { get { _transform } set { _transform = newValue } }
    open override var preferredVolume: Float { get { _volume } set { _volume = newValue } }
    open var naturalTimeScale: CMTimeScale = 600

    /// Inserts `timeRange` of `track` (from an AVURLAsset, or another composition) at `startTime`, shifting later segments.
    open func insertTimeRange(_ timeRange: CMTimeRange, of track: AVAssetTrack, at startTime: CMTime) throws {
        guard timeRange.duration.isNumeric, timeRange.duration.seconds > 0 else { return }
        let target = CMTimeRange(start: startTime.isNumeric ? startTime : timeRange.end, duration: timeRange.duration)
        var new: [AVCompositionTrackSegment] = []
        if let ct = track as? AVCompositionTrack {          // flatten a composition's segments
            for s in ct._segments {
                let r = s._target.intersection(timeRange)
                guard r.duration.seconds > 0 else { continue }
                let off = r.start.seconds - s._target.start.seconds
                let scale = s._sourceRange.duration.seconds / max(1e-9, s._target.duration.seconds)
                let src = CMTimeRange(start: CMTime(seconds: s._sourceRange.start.seconds + off * scale, preferredTimescale: 600),
                                      duration: CMTime(seconds: r.duration.seconds * scale, preferredTimescale: 600))
                let tgt = CMTimeRange(start: CMTime(seconds: target.start.seconds + r.start.seconds - timeRange.start.seconds, preferredTimescale: 600), duration: r.duration)
                new.append(AVCompositionTrackSegment(url: s._url, sourceRange: src, target: tgt, trackID: s._sourceTrackID))
            }
        } else {
            guard let url = track.asset?._url, track.asset?.isPlayable == true else {
                throw AVError(.invalidSourceMedia, reason: "the source track's asset is not a readable media file")
            }
            let avail = track.timeRange
            let r = timeRange.intersection(avail)
            guard r.duration.seconds > 0 else { throw AVError(.invalidSourceMedia, reason: "the time range is outside the source track") }
            new.append(AVCompositionTrackSegment(url: url, sourceRange: r, target: CMTimeRange(start: target.start, duration: r.duration), trackID: track.trackID))
            if _naturalSize == .zero { _naturalSize = track.naturalSize }
            if _nominalFrameRate == 0 { _nominalFrameRate = track.nominalFrameRate }
        }
        _shift(from: target.start.seconds, by: target.duration.seconds)
        _segments.append(contentsOf: new)
        _segments.sort { $0._target.start < $1._target.start }
    }
    open func insertTimeRanges(_ timeRanges: [NSValue], of tracks: [AVAssetTrack], at startTime: CMTime) throws {
        var t = startTime
        for (v, tr) in zip(timeRanges, tracks) { let r = v.timeRangeValue; try insertTimeRange(r, of: tr, at: t); t = t + r.duration }
    }
    open func insertEmptyTimeRange(_ timeRange: CMTimeRange) { _shift(from: timeRange.start.seconds, by: timeRange.duration.seconds) }
    /// Removes the range, closing the gap.
    open func removeTimeRange(_ timeRange: CMTimeRange) {
        let a = timeRange.start.seconds, b = timeRange.end.seconds, d = b - a
        var out: [AVCompositionTrackSegment] = []
        for s in _segments {
            let s0 = s._target.start.seconds, s1 = s._target.end.seconds
            let scale = s._sourceRange.duration.seconds / max(1e-9, s1 - s0)
            func piece(_ x0: Double, _ x1: Double, shift: Double) {
                guard x1 - x0 > 1e-6 else { return }
                let src = CMTimeRange(start: CMTime(seconds: s._sourceRange.start.seconds + (x0 - s0) * scale, preferredTimescale: 600),
                                      duration: CMTime(seconds: (x1 - x0) * scale, preferredTimescale: 600))
                out.append(AVCompositionTrackSegment(url: s._url, sourceRange: src,
                                                     target: CMTimeRange(start: CMTime(seconds: x0 - shift, preferredTimescale: 600), duration: CMTime(seconds: x1 - x0, preferredTimescale: 600)),
                                                     trackID: s._sourceTrackID))
            }
            piece(s0, min(s1, a), shift: 0)
            piece(max(s0, b), s1, shift: d)
        }
        _segments = out
    }
    /// Changes the duration of a range (speed change), moving later segments.
    open func scaleTimeRange(_ timeRange: CMTimeRange, toDuration duration: CMTime) {
        let a = timeRange.start.seconds, b = timeRange.end.seconds
        guard b > a, duration.seconds > 0 else { return }
        let f = duration.seconds / (b - a)
        var out: [AVCompositionTrackSegment] = []
        for s in _segments {
            let s0 = s._target.start.seconds, s1 = s._target.end.seconds
            let scale = s._sourceRange.duration.seconds / max(1e-9, s1 - s0)
            func map(_ x: Double) -> Double { x <= a ? x : x >= b ? x + (b - a) * (f - 1) : a + (x - a) * f }
            for (x0, x1) in [(s0, min(s1, a)), (max(s0, a), min(s1, b)), (max(s0, b), s1)] where x1 - x0 > 1e-6 {
                let src = CMTimeRange(start: CMTime(seconds: s._sourceRange.start.seconds + (x0 - s0) * scale, preferredTimescale: 600),
                                      duration: CMTime(seconds: (x1 - x0) * scale, preferredTimescale: 600))
                out.append(AVCompositionTrackSegment(url: s._url, sourceRange: src,
                                                     target: CMTimeRange(start: CMTime(seconds: map(x0), preferredTimescale: 600), duration: CMTime(seconds: map(x1) - map(x0), preferredTimescale: 600)),
                                                     trackID: s._sourceTrackID))
            }
        }
        _segments = out
    }
    func _shift(from t: Double, by d: Double) {
        guard d > 0 else { return }
        var out: [AVCompositionTrackSegment] = []
        for s in _segments {
            let s0 = s._target.start.seconds, s1 = s._target.end.seconds
            if s1 <= t + 1e-9 { out.append(s); continue }
            if s0 >= t - 1e-9 {
                s._target = CMTimeRange(start: CMTime(seconds: s0 + d, preferredTimescale: 600), duration: s._target.duration); out.append(s); continue
            }
            // split at t
            let scale = s._sourceRange.duration.seconds / max(1e-9, s1 - s0)
            let first = AVCompositionTrackSegment(url: s._url, sourceRange: CMTimeRange(start: s._sourceRange.start, duration: CMTime(seconds: (t - s0) * scale, preferredTimescale: 600)),
                                                  target: CMTimeRange(start: s._target.start, duration: CMTime(seconds: t - s0, preferredTimescale: 600)), trackID: s._sourceTrackID)
            let second = AVCompositionTrackSegment(url: s._url, sourceRange: CMTimeRange(start: CMTime(seconds: s._sourceRange.start.seconds + (t - s0) * scale, preferredTimescale: 600), duration: CMTime(seconds: (s1 - t) * scale, preferredTimescale: 600)),
                                                   target: CMTimeRange(start: CMTime(seconds: t + d, preferredTimescale: 600), duration: CMTime(seconds: s1 - t, preferredTimescale: 600)), trackID: s._sourceTrackID)
            out += [first, second]
        }
        _segments = out
    }
}

open class AVComposition: AVAsset, @unchecked Sendable {
    var _tracks: [AVMutableCompositionTrack] = []
    var _naturalSize: CGSize = .zero
    init() { super.init(_url: nil) }
    open override var tracks: [AVAssetTrack] { _tracks }
    open override var duration: CMTime { CMTime(seconds: _tracks.map { $0.timeRange.end.seconds }.max() ?? 0, preferredTimescale: 600) }
    open override var isPlayable: Bool { !_tracks.isEmpty }
    open override var isReadable: Bool { !_tracks.isEmpty }
    open override var isExportable: Bool { !_tracks.isEmpty }
    open override var isComposable: Bool { true }
    open override var naturalSize: CGSize { _naturalSize != .zero ? _naturalSize : (_tracks.first { $0.mediaType == .video }?.naturalSize ?? .zero) }
    override func _check() throws {}
    override func _videoSource(at t: Double) -> (URL, Double)? {
        guard let v = _tracks.first(where: { $0.mediaType == .video }),
              let s = v._segments.first(where: { t >= $0._target.start.seconds - 1e-6 && t < $0._target.end.seconds }), let u = s._url else { return nil }
        let scale = s._sourceRange.duration.seconds / max(1e-9, s._target.duration.seconds)
        return (u, s._sourceRange.start.seconds + (t - s._target.start.seconds) * scale)
    }
    open override func statusOfValue(forKey key: String, error outError: UnsafeMutablePointer<NSError?>?) -> AVKeyValueStatus { .loaded }
    open override func track(withTrackID id: CMPersistentTrackID) -> AVCompositionTrack? { _tracks.first { $0.trackID == id } }
}

open class AVMutableComposition: AVComposition, @unchecked Sendable {
    public override init() { super.init() }
    public convenience init(urlAssetInitializationOptions: [String: Any]? = nil) { self.init() }
    open override var naturalSize: CGSize { get { super.naturalSize } set { _naturalSize = newValue } }
    open func addMutableTrack(withMediaType mediaType: AVMediaType, preferredTrackID: CMPersistentTrackID) -> AVMutableCompositionTrack? {
        guard mediaType == .video || mediaType == .audio else { return nil }
        var id = preferredTrackID
        if id == kCMPersistentTrackID_Invalid || _tracks.contains(where: { $0.trackID == id }) { id = (_tracks.map(\.trackID).max() ?? 0) + 1 }
        let t = AVMutableCompositionTrack(asset: nil, id: id, type: mediaType, size: .zero, fps: 0, range: .zero)
        _tracks.append(t)
        return t
    }
    open func removeTrack(_ track: AVCompositionTrack) { _tracks.removeAll { $0 === track } }
    open func mutableTrack(compatibleWith track: AVAssetTrack) -> AVMutableCompositionTrack? { _tracks.first { $0.mediaType == track.mediaType } }
    open override func track(withTrackID id: CMPersistentTrackID) -> AVMutableCompositionTrack? { _tracks.first { $0.trackID == id } }
    /// Inserts all tracks of `asset` in `timeRange` at `startTime` (adding composition tracks as needed).
    open func insertTimeRange(_ timeRange: CMTimeRange, of asset: AVAsset, at startTime: CMTime) throws {
        try asset._check()
        for src in asset.tracks where src.mediaType == .video || src.mediaType == .audio {
            let dst = _tracks.first { $0.mediaType == src.mediaType } ?? addMutableTrack(withMediaType: src.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid)!
            try dst.insertTimeRange(timeRange, of: src, at: startTime)
        }
        // tracks the asset lacks still move: keep later segments aligned
        for t in _tracks where !asset.tracks.contains(where: { $0.mediaType == t.mediaType }) { t._shift(from: startTime.seconds, by: timeRange.duration.seconds) }
    }
    open func insertEmptyTimeRange(_ timeRange: CMTimeRange) { _tracks.forEach { $0.insertEmptyTimeRange(timeRange) } }
    open func removeTimeRange(_ timeRange: CMTimeRange) { _tracks.forEach { $0.removeTimeRange(timeRange) } }
    open func scaleTimeRange(_ timeRange: CMTimeRange, toDuration duration: CMTime) { _tracks.forEach { $0.scaleTimeRange(timeRange, toDuration: duration) } }
}
public let kCMPersistentTrackID_Invalid: CMPersistentTrackID = 0

open class AVAudioMix: NSObject, @unchecked Sendable {}
open class AVMutableAudioMix: AVAudioMix, @unchecked Sendable {
    open var inputParameters: [AVAudioMixInputParameters] = []
}
open class AVAudioMixInputParameters: NSObject, @unchecked Sendable {
    open var trackID: CMPersistentTrackID = 0
    open var audioTimePitchAlgorithm: AVAudioTimePitchAlgorithm?
    /// volume changes in time order: a constant volume from `start`, or a ramp over [start, end]
    struct _Change { let start: Double; let end: Double; let from: Float; let to: Float }
    var _changes: [_Change] = []
    var _volume: Float { _changes.first?.from ?? 1 }
    /// the ramp (or constant volume) in effect at `time`
    open func getVolumeRamp(for time: CMTime, startVolume: UnsafeMutablePointer<Float>?, endVolume: UnsafeMutablePointer<Float>?,
                            timeRange: UnsafeMutablePointer<CMTimeRange>?) -> Bool {
        let t = time.seconds
        guard let c = _changes.last(where: { $0.start <= t }) else { return false }
        startVolume?.pointee = c.from; endVolume?.pointee = c.to
        timeRange?.pointee = CMTimeRange(start: CMTime(seconds: c.start, preferredTimescale: 600),
                                         duration: c.end.isFinite ? CMTime(seconds: c.end - c.start, preferredTimescale: 600) : .positiveInfinity)
        return true
    }
    /// an ffmpeg volume expression of t (seconds from the start of the output), nil for unity gain
    func _expression(offset: Double = 0) -> String? {
        let cs = _changes.sorted { $0.start < $1.start }
        guard !cs.isEmpty, !(cs.count == 1 && cs[0].from == 1 && cs[0].to == 1) else { return nil }
        func f(_ v: Double) -> String { String(format: "%.6f", v) }
        // change i holds from its start to the next change: its ramp, then its end volume; before the first: 1
        func region(_ c: _Change) -> String {
            guard c.end.isFinite, c.end > c.start else { return "\(c.to)" }
            return "if(lt(t,\(f(c.end - offset))),\(c.from)+(\(c.to - c.from))*(t-\(f(c.start - offset)))/\(f(c.end - c.start)),\(c.to))"
        }
        var e = region(cs[cs.count - 1])
        for i in stride(from: cs.count - 2, through: 0, by: -1) { e = "if(lt(t,\(f(cs[i + 1].start - offset))),\(region(cs[i])),\(e))" }
        e = "if(lt(t,\(f(cs[0].start - offset))),1,\(e))"
        return e
    }
    func _filter(offset: Double = 0) -> String? { _expression(offset: offset).map { "volume='\($0)':eval=frame" } }
}
open class AVMutableAudioMixInputParameters: AVAudioMixInputParameters, @unchecked Sendable {
    public convenience init(track: AVAssetTrack?) { self.init(); trackID = track?.trackID ?? 0 }
    open func setVolume(_ volume: Float, at time: CMTime) {
        let t = time.isNumeric ? time.seconds : 0
        _changes.removeAll { $0.start == t }
        _changes.append(_Change(start: t, end: .infinity, from: volume, to: volume))
    }
    open func setVolumeRamp(fromStartVolume startVolume: Float, toEndVolume endVolume: Float, timeRange: CMTimeRange) {
        let a = timeRange.start.isNumeric ? timeRange.start.seconds : 0
        let b = timeRange.end.isNumeric ? timeRange.end.seconds : a
        _changes.removeAll { $0.start == a }
        _changes.append(_Change(start: a, end: b, from: startVolume, to: endVolume))
    }
}
public struct AVAudioTimePitchAlgorithm: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let lowQualityZeroLatency = AVAudioTimePitchAlgorithm(rawValue: "LowQualityZeroLatency")
    public static let timeDomain = AVAudioTimePitchAlgorithm(rawValue: "TimeDomain")
    public static let spectral = AVAudioTimePitchAlgorithm(rawValue: "Spectral")
    public static let varispeed = AVAudioTimePitchAlgorithm(rawValue: "Varispeed")
}
extension AVAudioMix {
    func _params(_ trackID: CMPersistentTrackID) -> AVAudioMixInputParameters? {
        (self as? AVMutableAudioMix)?.inputParameters.first { $0.trackID == trackID } ?? (self as? AVMutableAudioMix)?.inputParameters.first { $0.trackID == 0 }
    }
}

// MARK: - export

public let AVAssetExportPresetPassthrough = "AVAssetExportPresetPassthrough"
public let AVAssetExportPresetLowQuality = "AVAssetExportPresetLowQuality"
public let AVAssetExportPresetMediumQuality = "AVAssetExportPresetMediumQuality"
public let AVAssetExportPresetHighestQuality = "AVAssetExportPresetHighestQuality"
public let AVAssetExportPresetHEVCHighestQuality = "AVAssetExportPresetHEVCHighestQuality"
public let AVAssetExportPreset640x480 = "AVAssetExportPreset640x480"
public let AVAssetExportPreset960x540 = "AVAssetExportPreset960x540"
public let AVAssetExportPreset1280x720 = "AVAssetExportPreset1280x720"
public let AVAssetExportPreset1920x1080 = "AVAssetExportPreset1920x1080"
public let AVAssetExportPreset3840x2160 = "AVAssetExportPreset3840x2160"
public let AVAssetExportPresetHEVC1920x1080 = "AVAssetExportPresetHEVC1920x1080"
public let AVAssetExportPresetHEVC3840x2160 = "AVAssetExportPresetHEVC3840x2160"
public let AVAssetExportPresetAppleM4A = "AVAssetExportPresetAppleM4A"

open class AVAssetExportSession: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, waiting, exporting, completed, failed, cancelled }
    public let asset: AVAsset
    public let presetName: String
    open var outputURL: URL?
    open var outputFileType: AVFileType?
    open var timeRange = CMTimeRange(start: .zero, duration: .positiveInfinity)
    open var shouldOptimizeForNetworkUse = false
    open var videoComposition: AVVideoComposition?
    open var audioMix: AVAudioMix?
    open var fileLengthLimit: Int64 = 0
    open var metadata: [Any]?
    open var canPerformMultiplePassesOverSourceMediaData = false
    open private(set) var status: Status = .unknown
    open private(set) var error: Error?
    var _progress = 0.0
    var _cancel: Int32 = 0
    open var progress: Float { status == .completed ? 1 : Float(min(1, max(0, _progress))) }

    public init?(asset: AVAsset, presetName: String) {
        guard AVAssetExportSession.allExportPresets().contains(presetName) else { return nil }
        self.asset = asset; self.presetName = presetName
    }
    open class func allExportPresets() -> [String] {
        [AVAssetExportPresetPassthrough, AVAssetExportPresetLowQuality, AVAssetExportPresetMediumQuality, AVAssetExportPresetHighestQuality,
         AVAssetExportPresetHEVCHighestQuality, AVAssetExportPreset640x480, AVAssetExportPreset960x540, AVAssetExportPreset1280x720,
         AVAssetExportPreset1920x1080, AVAssetExportPreset3840x2160, AVAssetExportPresetHEVC1920x1080, AVAssetExportPresetHEVC3840x2160,
         AVAssetExportPresetAppleM4A]
    }
    open class func exportPresets(compatibleWith asset: AVAsset) -> [String] {
        let video = !asset.tracks(withMediaType: .video).isEmpty
        return allExportPresets().filter { video || $0 == AVAssetExportPresetAppleM4A || $0 == AVAssetExportPresetPassthrough }
    }
    open class func determineCompatibility(ofExportPreset presetName: String, with asset: AVAsset, outputFileType: AVFileType?,
                                           completionHandler handler: @escaping @Sendable (Bool) -> Void) {
        let ok = exportPresets(compatibleWith: asset).contains(presetName)
        DispatchQueue.global().async { handler(ok) }
    }
    var _audioOnly: Bool { presetName == AVAssetExportPresetAppleM4A || asset.tracks(withMediaType: .video).isEmpty }
    open var supportedFileTypes: [AVFileType] {
        if presetName == AVAssetExportPresetAppleM4A { return [.m4a] }
        if _audioOnly { return [.m4a, .wav, .caf, .aiff, .mov] }
        return [.mov, .mp4, .m4v]
    }
    open func determineCompatibleFileTypes(completionHandler handler: @escaping @Sendable ([AVFileType]) -> Void) {
        let t = supportedFileTypes
        DispatchQueue.global().async { handler(t) }
    }
    open func estimateOutputFileLength(completionHandler handler: @escaping @Sendable (Int64, Error?) -> Void) {
        let d = asset.duration.seconds
        DispatchQueue.global().async { handler(Int64(max(0, d) * 250_000), nil) }
    }
    open func cancelExport() { _cancel = 1; if status == .waiting || status == .unknown { status = .cancelled } }

    open func exportAsynchronously(completionHandler handler: @escaping @Sendable () -> Void) {
        status = .waiting
        DispatchQueue.global().async {
            self._run()
            handler()
        }
    }
    /// iOS 16+ async form (deprecated in iOS 18 in favour of export(to:as:)).
    open func export() async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in exportAsynchronously { k.resume() } }
    }
    /// iOS 18 form: throws on failure.
    @available(iOS 18.0, *)
    open func export(to url: URL, as fileType: AVFileType, isolation: isolated (any Actor)? = #isolation) async throws {
        outputURL = url; outputFileType = fileType
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in exportAsynchronously { k.resume() } }
        if let e = error { throw e }
        if status == .cancelled { throw CancellationError() }
    }

    func _fail(_ e: Error) { error = e; status = .failed }
    /// isim: AVAssetReader renders compositions, audio mixes and video compositions losslessly (FFV1 video, float PCM,
    /// Matroska) into a temporary file it then decodes
    var _lossless = false
    var _wantVideo = true, _wantAudio = true
    var _audioTrackIDs: [CMPersistentTrackID]?
    /// the composition's video track to render (a compositor's source), else its first
    var _videoTrackID: CMPersistentTrackID?
    /// the compositor in use: an instance of the video composition's customVideoCompositorClass (made by the export,
    /// or handed over by AVAssetReaderVideoCompositionOutput / AVAssetImageGenerator)
    var _compositor: (any AVVideoCompositing)?
    open var customVideoCompositor: (any AVVideoCompositing)? { _compositor }
    func _run() {
        guard status != .cancelled else { return }
        guard let out = outputURL else { _fail(_avNSError(.exportFailed, "outputURL is not set")); return }
        guard let ft = outputFileType ?? (supportedFileTypes.first) else { _fail(_avNSError(.exportFailed, "outputFileType is not set")); return }
        guard _lossless || supportedFileTypes.contains(ft) else { _fail(_avNSError(.exportFailed, "the preset does not support \(ft.rawValue)")); return }
        if FileManager.default.fileExists(atPath: out.path) { _fail(_avNSError(.fileAlreadyExists, "the output file already exists")); return }
        status = .exporting
        let total = asset.duration.seconds
        let r0 = timeRange.start.isNumeric ? max(0, timeRange.start.seconds) : 0
        let r1 = timeRange.end.isNumeric ? min(total, timeRange.end.seconds) : total
        guard r1 > r0 else { _fail(_avNSError(.exportFailed, "the time range is empty")); return }
        let (mux, takesVideo) = _lossless ? ("matroska", true) : ft._muxer
        let video = takesVideo && !_audioOnly && _wantVideo
        var args = ["-y"]
        var maps: [String] = []
        // a video composition with instructions, a custom compositor, Core Image filtering or the Core Animation tool:
        // the frames are composed here (AVVideoComposition.swift) and read by ffmpeg as raw video
        var composed: _RawVideoSink?
        if video, let vc = videoComposition, vc._composites {
            guard let sink = _composeFrames(vc, from: r0, to: r1, size: _outputSize(asset.naturalSize)) else {
                if status == .exporting { status = _cancel != 0 ? .cancelled : .failed }
                return
            }
            composed = sink
        }
        let fr = videoComposition.map { $0.frameDuration.seconds > 0 ? 1 / $0.frameDuration.seconds : 30 } ?? 30
        if let comp = asset as? AVComposition {
            let (inputs, graph, vlabel, alabel) = _compositionGraph(comp, from: r0, to: r1, video: video && composed == nil, audio: _wantAudio, audioTrackIDs: _audioTrackIDs)
            args += inputs
            if let composed { maps += ["-map", "\(inputs.filter { $0 == "-i" }.count):v"]; args += composed.inputArgs(fps: fr) }
            if !graph.isEmpty { args += ["-filter_complex", graph] }
            if let v = vlabel { maps += ["-map", v] }
            if let a = alabel { maps += ["-map", a] }
            if maps.isEmpty { _fail(_avNSError(.exportFailed, "the composition has no media")); return }
            args += maps
        } else {
            guard let u = asset._url, asset.isPlayable else { _fail(_avLoadError(asset)); return }
            args += ["-ss", String(format: "%.6f", r0), "-t", String(format: "%.6f", r1 - r0), "-i", _path(u)]
            if let composed {
                args += composed.inputArgs(fps: fr)
                maps += ["-map", "1:v"]
            }
            if !video { args += ["-vn"] }
            if !_wantAudio { args += ["-an"] }
            var vf = [_scaleFilter()].compactMap { $0 }
            if let vc = videoComposition, vc.frameDuration.seconds > 0 { vf.append("fps=\(1 / vc.frameDuration.seconds)") }
            if !vf.isEmpty, video, composed == nil, presetName != AVAssetExportPresetPassthrough { args += ["-vf", vf.joined(separator: ",")] }
            // several audio tracks: each at its volume, mixed; one track: its volume curve
            let audioTracks = asset.tracks(withMediaType: .audio).filter { _audioTrackIDs == nil || _audioTrackIDs!.contains($0.trackID) }
            if _wantAudio, let mix = audioMix, presetName != AVAssetExportPresetPassthrough {
                if audioTracks.count > 1 {
                    let chains = audioTracks.enumerated().map { i, t in "[0:a:\(i)]\(mix._params(t.trackID)?._filter(offset: r0) ?? "anull")[m\(i)]" }
                    args += ["-filter_complex", chains.joined(separator: ";") + ";" + (0..<audioTracks.count).map { "[m\($0)]" }.joined()
                             + "amix=inputs=\(audioTracks.count):normalize=0:duration=longest[amixed]", "-map", "[amixed]"]
                    if video && composed == nil { args += ["-map", "0:v:0"] }
                } else if let f = audioTracks.first.flatMap({ mix._params($0.trackID)?._filter(offset: r0) }) { args += ["-af", f] }
            }
            if composed != nil && _wantAudio && !args.contains("[amixed]") { maps += ["-map", "0:a:0?"] }
            args += maps
        }
        if _lossless {
            if video { args += ["-c:v", "ffv1", "-pix_fmt", "bgra"] }
            args += ["-c:a", "pcm_f32le", "-ar", "48000"]
        } else if presetName == AVAssetExportPresetPassthrough && !(asset is AVComposition) && composed == nil {
            args += ["-c", "copy"]
        } else {
            if video { args += _FFmpeg.videoCodecArgs(presetName.contains("HEVC") ? .hevc : .h264, bitrate: _bitrate) }
            args += _FFmpeg.audioCodecArgs(nil, fileType: ft == .mov && _audioOnly ? .m4a : ft)
        }
        if shouldOptimizeForNetworkUse && (mux == "mp4" || mux == "mov" || mux == "ipod") { args += ["-movflags", "+faststart"] }
        if fileLengthLimit > 0 { args += ["-fs", String(fileLengthLimit)] }
        let items = (metadata ?? []).compactMap { $0 as? AVMetadataItem }
        if !items.isEmpty && !_lossless {
            args += _MetadataMap.arguments(items)
            if ["mov", "mp4", "ipod"].contains(mux) { args += ["-movflags", "use_metadata_tags"] }
        }
        args += ["-f", mux, _path(out)]
        let err = withUnsafeMutablePointer(to: &_progress) { p in withUnsafeMutablePointer(to: &_cancel) { c in _FFmpeg.run(args, progress: p, cancel: c) } }
        if _cancel != 0 { status = .cancelled; try? FileManager.default.removeItem(at: out); return }
        if let err { _fail(err); try? FileManager.default.removeItem(at: out); return }
        _progress = 1
        status = .completed
    }
    var _bitrate: Double? {
        switch presetName {
        case AVAssetExportPresetLowQuality: return 300_000
        case AVAssetExportPresetMediumQuality: return 1_000_000
        default: return nil
        }
    }
    var _maxSize: CGSize? {
        if let rs = videoComposition?.renderSize, rs.width > 0 { return rs }
        switch presetName {
        case AVAssetExportPreset640x480: return CGSize(width: 640, height: 480)
        case AVAssetExportPreset960x540: return CGSize(width: 960, height: 540)
        case AVAssetExportPreset1280x720: return CGSize(width: 1280, height: 720)
        case AVAssetExportPreset1920x1080, AVAssetExportPresetHEVC1920x1080: return CGSize(width: 1920, height: 1080)
        case AVAssetExportPreset3840x2160, AVAssetExportPresetHEVC3840x2160: return CGSize(width: 3840, height: 2160)
        case AVAssetExportPresetLowQuality: return CGSize(width: 224, height: 168)
        case AVAssetExportPresetMediumQuality: return CGSize(width: 480, height: 360)
        default: return nil
        }
    }
    /// output frame size: the source fitted inside the preset's size (never enlarged), even dimensions
    func _outputSize(_ src: CGSize) -> CGSize {
        var s = src
        if let videoComposition, videoComposition.renderSize.width > 0 { s = videoComposition.renderSize }
        else if let m = _maxSize, src.width > 0, src.height > 0 {
            let landscape = src.width >= src.height
            let box = landscape ? m : CGSize(width: m.height, height: m.width)
            let f = min(1, min(box.width / src.width, box.height / src.height))
            s = CGSize(width: src.width * f, height: src.height * f)
        }
        return CGSize(width: max(2, (s.width / 2).rounded() * 2), height: max(2, (s.height / 2).rounded() * 2))
    }
    func _scaleFilter() -> String? {
        let src = asset.naturalSize
        let o = _outputSize(src)
        return o == src ? nil : "scale=\(Int(o.width)):\(Int(o.height))"
    }

    /// ffmpeg inputs and a filter graph for the composition's segments within [r0, r1].
    func _compositionGraph(_ comp: AVComposition, from r0: Double, to r1: Double, video wantVideo: Bool, audio wantAudio: Bool = true,
                           audioTrackIDs: [CMPersistentTrackID]? = nil) -> ([String], String, String?, String?) {
        var inputs: [String] = [], chains: [String] = []
        var vlabel: String?, alabel: String?
        var n = 0
        let size = _outputSize(comp.naturalSize == .zero ? CGSize(width: 640, height: 360) : comp.naturalSize)
        let fps = Double(comp._tracks.first { $0.mediaType == .video }?.nominalFrameRate ?? 30).nonZero ?? 30
        let fr = videoComposition.map { $0.frameDuration.seconds > 0 ? 1 / $0.frameDuration.seconds : fps } ?? fps
        var jobs: [(AVMediaType, AVMutableCompositionTrack)] = []
        if wantVideo, let v = comp._tracks.first(where: { $0.mediaType == .video && !$0._segments.isEmpty && (_videoTrackID == nil || $0.trackID == _videoTrackID) }) { jobs.append((.video, v)) }
        if wantAudio { for a in comp._tracks where a.mediaType == .audio && !a._segments.isEmpty && (audioTrackIDs == nil || audioTrackIDs!.contains(a.trackID)) { jobs.append((.audio, a)) } }
        var audioOuts: [String] = []
        for (kind, track) in jobs {
            var parts: [String] = []
            var t = r0
            let segs = track._segments.filter { $0._target.end.seconds > r0 + 1e-6 && $0._target.start.seconds < r1 - 1e-6 }
            func gap(_ d: Double) {
                guard d > 1e-3 else { return }
                let l = "g\(n)"; n += 1
                if kind == .video { chains.append("color=c=black:s=\(Int(size.width))x\(Int(size.height)):r=\(fr):d=\(String(format: "%.6f", d)),format=yuv420p,setsar=1[\(l)]") }
                else { chains.append("anullsrc=r=48000:cl=stereo,atrim=duration=\(String(format: "%.6f", d)),aformat=sample_fmts=fltp:channel_layouts=stereo[\(l)]") }
                parts.append(l)
            }
            for s in segs {
                guard let u = s._url else { continue }
                let a = max(s._target.start.seconds, r0), b = min(s._target.end.seconds, r1)
                gap(a - t)
                let scale = s._sourceRange.duration.seconds / max(1e-9, s._target.duration.seconds)
                let ss = s._sourceRange.start.seconds + (a - s._target.start.seconds) * scale, dur = (b - a) * scale
                let idx = inputs.filter { $0 == "-i" }.count
                inputs += ["-ss", String(format: "%.6f", ss), "-t", String(format: "%.6f", dur), "-i", _path(u)]
                let l = "s\(n)"; n += 1
                let speed = 1 / scale        // > 1: slowed down (longer)
                if kind == .video {
                    chains.append("[\(idx):v]setpts=(PTS-STARTPTS)*\(speed),scale=\(Int(size.width)):\(Int(size.height)):force_original_aspect_ratio=decrease,pad=\(Int(size.width)):\(Int(size.height)):(ow-iw)/2:(oh-ih)/2,setsar=1,fps=\(fr),format=yuv420p[\(l)]")
                } else {
                    var tempo = ""
                    var f = scale                        // atempo factor (source seconds per output second), 0.5...2 per stage
                    while f > 2.0 { tempo += ",atempo=2.0"; f /= 2 }
                    while f < 0.5 { tempo += ",atempo=0.5"; f /= 0.5 }
                    if abs(f - 1) > 1e-4 { tempo += ",atempo=\(f)" }
                    chains.append("[\(idx):a]asetpts=PTS-STARTPTS,aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo\(tempo)[\(l)]")
                }
                parts.append(l)
                t = b
            }
            gap(r1 - t)
            guard !parts.isEmpty else { continue }
            let out = kind == .video ? "vout" : "aout\(audioOuts.count)"
            let volume = kind == .audio ? audioMix?._params(track.trackID)?._filter(offset: r0).map { "," + $0 } ?? "" : ""
            chains.append(parts.map { "[\($0)]" }.joined() + "concat=n=\(parts.count):v=\(kind == .video ? 1 : 0):a=\(kind == .audio ? 1 : 0)\(volume)[\(out)]")
            if kind == .video { vlabel = "[vout]" } else { audioOuts.append(out) }
        }
        if audioOuts.count == 1 { alabel = "[\(audioOuts[0])]" }
        else if audioOuts.count > 1 {                 // several audio tracks play together (unnormalized sum, like iOS)
            chains.append(audioOuts.map { "[\($0)]" }.joined() + "amix=inputs=\(audioOuts.count):normalize=0:duration=longest[amixed]")
            alabel = "[amixed]"
        }
        return (inputs, chains.joined(separator: ";"), vlabel, alabel)
    }
}
extension Double { var nonZero: Double? { self > 0 ? self : nil } }

// MARK: - AVAssetReader

open class AVAssetReaderOutput: NSObject, @unchecked Sendable {
    open var mediaType: AVMediaType { .video }
    open var alwaysCopiesSampleData = true
    /// with random access, the output ends each time range (copyNextSampleBuffer returns nil) and reads the next ones
    /// given to reset(forReadingTimeRanges:) until markConfigurationAsFinal()
    open var supportsRandomAccess = false
    weak var _reader: AVAssetReader?
    var _ranges: [CMTimeRange] = []
    var _final = false
    var _stream: _ReaderStream?
    open func copyNextSampleBuffer() -> CMSampleBuffer? {
        guard var st = _stream, _reader?.status == .reading else { return nil }
        while true {
            if let sb = st.next() { return sb }
            st.close()
            guard let nxt = st.following?() else { break }      // the next of several time ranges, without a pause
            st = nxt
        }
        if supportsRandomAccess && !_final { _stream = nil; return nil }      // waits for reset(forReadingTimeRanges:)
        _stream = nil
        _reader?._outputEnded()
        return nil
    }
    open func reset(forReadingTimeRanges timeRanges: [NSValue]) {
        guard supportsRandomAccess, !_final, _reader?.status == .reading else {
            NSLog("isim AVFoundation: reset(forReadingTimeRanges:) needs supportsRandomAccess and a reading reader (iOS raises an exception)"); return
        }
        _ranges = timeRanges.map(\.timeRangeValue)
        _stream?.close()
        _stream = nil
        _nextRange()
    }
    open func markConfigurationAsFinal() {
        _final = true
        if _stream == nil && _ranges.isEmpty && _reader?.status == .reading { _reader?._outputEnded() }
    }
    /// opens the stream for the next queued time range
    @discardableResult func _nextRange() -> Bool {
        guard !_ranges.isEmpty else { return false }
        let r = _ranges.removeFirst()
        _stream = _open(r)
        if _stream == nil { return false }
        _stream?.following = _ranges.isEmpty ? nil : { [weak self] in self?._advance() }
        return true
    }
    func _advance() -> _ReaderStream? { _nextRange() ? _stream : nil }
    func _start(_ range: CMTimeRange) -> Bool {
        _ranges = [range]
        return _nextRange()
    }
    func _open(_ range: CMTimeRange) -> _ReaderStream? { nil }
    func _stop() { _stream?.close(); _stream = nil }
}

/// A source of sample buffers for one time range.
class _ReaderStream {
    var following: (() -> _ReaderStream?)?
    func next() -> CMSampleBuffer? { nil }
    func close() {}
}

/// Decoded frames / PCM of a media file's first video or audio stream (ffmpeg, host_capture.c).
final class _DecodedStream: _ReaderStream {
    let video: Bool
    var handle: Int32 = 0
    var frame = 0, w = 0, h = 0, fps = 30.0, start = 0.0
    var asbd = AudioStreamBasicDescription()
    var audioFrames = 0
    var downmix = false
    var pixelFormat: OSType = kCVPixelFormatType_32BGRA
    /// the frames' own presentation times (MP4 / QuickTime sources), else frames come at a constant rate
    var times: [Double]?
    init?(url: URL, video: Bool, range: CMTimeRange, settings: [String: Any]?, size: CGSize, fps: Double) {
        self.video = video
        super.init()
        start = range.start.isNumeric ? range.start.seconds : 0
        let dur = range.duration.isNumeric ? range.duration.seconds : 0
        if video {
            w = Int(size.width); h = Int(size.height); self.fps = fps > 0 ? fps : 30
            if let sw = _num(settings, AVVideoWidthKey), let sh = _num(settings, AVVideoHeightKey) { w = Int(sw); h = Int(sh) }
            if w <= 0 || h <= 0 { let m = _AVMediaInfo(url: url); w = Int(m.width); h = Int(m.height); if fps <= 0 { self.fps = m.fps > 0 ? m.fps : 30 } }
            if let d = try? Data(contentsOf: url, options: .alwaysMapped), let t = _MP4.read(d)?.first(where: { $0.isVideo }) {
                let ts = Double(t.timescale), end = range.end.isNumeric && range.duration.isNumeric ? range.end.seconds : .infinity
                let all = t.samples.map { Double($0.cts - t.editMediaTime) / ts }.sorted()
                times = all.filter { $0 >= start - 1e-6 && $0 < end }
            }
            let v = settings?[kCVPixelBufferPixelFormatTypeKey as String]
            pixelFormat = (v as? NSNumber).map { OSType(truncatingIfNeeded: $0.int64Value) } ?? (v as? UInt32) ?? (v as? Int).map { OSType(truncatingIfNeeded: $0) } ?? kCVPixelFormatType_32BGRA
            guard w > 0, h > 0 else { return nil }
            handle = isim_media_reader_open(_path(url), 0, start, dur, Int32(w), Int32(h), times != nil ? -1 : self.fps, 0)
        } else {
            let rate = _num(settings, AVSampleRateKey) ?? 44100, ch = Int(_num(settings, AVNumberOfChannelsKey) ?? 2)
            let bits = Int(_num(settings, AVLinearPCMBitDepthKey) ?? 16)
            let float = (settings?[AVLinearPCMIsFloatKey] as? Bool) ?? false
            let fb = UInt32(ch * (float ? 4 : bits / 8))
            asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: (float ? kAudioFormatFlagIsFloat : kAudioFormatFlagIsSignedInteger) | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: fb, mFramesPerPacket: 1, mBytesPerFrame: fb, mChannelsPerFrame: UInt32(ch),
                                               mBitsPerChannel: UInt32(float ? 32 : bits), mReserved: 0)
            // ffmpeg's stereo-to-mono downmix is -3 dB; decode stereo and average it here instead (like iOS)
            downmix = ch == 1
            handle = isim_media_reader_open(_path(url), 1, start, dur, 0, 0, rate, Int32(downmix ? 2 : ch))
        }
        if handle <= 0 { return nil }
    }
    override func close() { if handle > 0 { isim_media_reader_close(handle); handle = 0 } }
    override func next() -> CMSampleBuffer? {
        guard handle > 0 else { return nil }
        if video {
            let n = w * h * 4
            var px = [UInt8](repeating: 0, count: n)
            let got = px.withUnsafeMutableBytes { isim_media_reader_read(handle, $0.baseAddress!, n) }
            guard got == n else { return nil }
            guard let pb = px.withUnsafeBufferPointer({ _pixelBuffer(fromBGRA: $0.baseAddress!, width: w, height: h, format: pixelFormat) }) else { return nil }
            var t = start + Double(frame) / fps, d = 1 / fps
            if let ts = times, !ts.isEmpty {
                let i = min(frame, ts.count - 1)
                t = ts[i]; d = i + 1 < ts.count ? ts[i + 1] - ts[i] : (i > 0 ? ts[i] - ts[i - 1] : d)
            }
            frame += 1
            return CMSampleBuffer(_imageBuffer: pb, presentationTime: CMTime(seconds: t, preferredTimescale: 600), duration: CMTime(seconds: d, preferredTimescale: 600))
        }
        let ch = Int(asbd.mChannelsPerFrame), chunk = 4096, rch = downmix ? 2 : ch
        var f = [Float](repeating: 0, count: chunk * rch)
        let got = f.withUnsafeMutableBytes { isim_media_reader_read(handle, $0.baseAddress!, chunk * rch * 4) }
        let frames = got / (rch * 4)
        guard frames > 0 else { return nil }
        if downmix { f = (0..<frames).map { (f[2 * $0] + f[2 * $0 + 1]) / 2 } }
        var bytes: [UInt8]
        if asbd._isFloat { bytes = f.withUnsafeBytes { Array($0.prefix(frames * ch * 4)) } }
        else {
            let bps = Int(asbd.mBitsPerChannel) / 8
            bytes = [UInt8](repeating: 0, count: frames * ch * bps)
            for i in 0..<(frames * ch) {
                let x = Double(max(-1, min(1, f[i])))
                let v = Int32((x * Double(bps == 1 ? 127 : bps == 2 ? 32767 : bps == 3 ? 8_388_607 : 2_147_483_647)).rounded())
                for k in 0..<bps { bytes[i * bps + k] = UInt8(truncatingIfNeeded: (bps == 1 ? v + 128 : v) >> (8 * Int32(k))) }
            }
        }
        let t = CMTime(value: Int64(audioFrames), timescale: Int32(asbd.mSampleRate)) + CMTime(seconds: start, preferredTimescale: Int32(asbd.mSampleRate))
        audioFrames += frames
        return CMSampleBuffer(_audio: bytes, format: asbd, presentationTime: t)
    }
}

/// The compressed samples of a track as stored in the file (MP4.swift): pass-through reading.
final class _PassthroughStream: _ReaderStream {
    let data: Data
    let track: _MP4Track
    let format: CMFormatDescription
    var index: Int
    let end: Int64?
    init?(url: URL, mediaType: AVMediaType, ordinal: Int, range: CMTimeRange) {
        guard let (d, tracks) = _MP4.open(url) else { return nil }
        let same = tracks.filter { mediaType == .video ? $0.isVideo : $0.isAudio }
        guard ordinal < same.count else { return nil }
        let t = same[ordinal]
        data = d; track = t
        var atoms: [String: Any] = [:]
        for (k, v) in t.atoms { atoms[k] = v }
        if t.isVideo {
            format = CMFormatDescription(_codec: t.codec, width: t.width, height: t.height,
                                         extensions: [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: atoms])
        } else {
            let id: AudioFormatID = t.codec == _MP4.fourcc("mp4a") ? kAudioFormatMPEG4AAC : t.codec
            var asbd = AudioStreamBasicDescription()
            asbd.mFormatID = id; asbd.mSampleRate = t.sampleRate; asbd.mChannelsPerFrame = UInt32(t.channels)
            asbd.mFramesPerPacket = id == kAudioFormatMPEG4AAC ? 1024 : 0
            format = CMFormatDescription(_audio: asbd)
            format._extensions = [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: atoms]
            if let esds = t.atoms["esds"] { format._cookie = Array(esds) }
        }
        let ts = Double(t.timescale)
        let s0 = range.start.isNumeric ? Int64(range.start.seconds * ts) : 0
        end = range.end.isNumeric && range.duration.isNumeric ? Int64(range.end.seconds * ts) : nil
        // from the last sync sample at or before the start (a decoder needs it)
        var i = t.samples.firstIndex { $0.cts - t.editMediaTime + $0.duration > s0 } ?? t.samples.count
        while i > 0 && i < t.samples.count && !t.samples[i].sync { i -= 1 }
        index = i
        super.init()
    }
    override func next() -> CMSampleBuffer? {
        guard index < track.samples.count else { return nil }
        let smp = track.samples[index]
        let pts = smp.cts - track.editMediaTime
        if let e = end, pts >= e { return nil }
        index += 1
        let ts = track.timescale
        let bytes = Array(data[(data.startIndex + smp.offset)..<(data.startIndex + smp.offset + smp.size)])
        let timing = CMSampleTimingInfo(duration: CMTime(value: smp.duration, timescale: ts), presentationTimeStamp: CMTime(value: pts, timescale: ts),
                                        decodeTimeStamp: CMTime(value: smp.dts - track.editMediaTime, timescale: ts))
        let sb = CMSampleBuffer(_block: CMBlockBuffer(_bytes: bytes), format: format, count: 1, timings: [timing], sizes: [smp.size])
        if !smp.sync {
            let a = NSMutableDictionary(); a.setObject(true, forKey: kCMSampleAttachmentKey_NotSync as String as NSString); a.setObject(true, forKey: kCMSampleAttachmentKey_DependsOnOthers as String as NSString)
            sb._sampleAttachments = [a]
        }
        return sb
    }
}

/// Decoded (or, with nil output settings, stored compressed) samples of one track: video as CVPixelBuffers (32BGRA or
/// 420 per outputSettings), audio as linear PCM. Composition tracks are rendered first.
open class AVAssetReaderTrackOutput: AVAssetReaderOutput, @unchecked Sendable {
    public let track: AVAssetTrack
    public let outputSettings: [String: Any]?
    open override var mediaType: AVMediaType { track.mediaType }
    open var audioTimePitchAlgorithm: AVAudioTimePitchAlgorithm?
    public init(track: AVAssetTrack, outputSettings: [String: Any]?) { self.track = track; self.outputSettings = outputSettings }
    override func _open(_ range: CMTimeRange) -> _ReaderStream? {
        guard let asset = track.asset ?? _reader?.asset else { return nil }
        if outputSettings == nil && !(asset is AVComposition) {
            guard let u = asset._url else { return nil }
            let ordinal = asset.tracks(withMediaType: track.mediaType).firstIndex { $0.trackID == track.trackID } ?? 0
            return _PassthroughStream(url: u, mediaType: track.mediaType, ordinal: ordinal, range: range)
        }
        let video = track.mediaType == .video
        guard let u = asset is AVComposition ? _reader?._render(video: video, audioTrackIDs: video ? nil : [track.trackID], audioMix: nil, videoComposition: nil)
                                             : asset._url else { return nil }
        return _DecodedStream(url: u, video: video, range: range, settings: outputSettings ?? [:], size: track.naturalSize == .zero ? asset.naturalSize : track.naturalSize,
                              fps: Double(track.nominalFrameRate))
    }
}

/// The asset's audio tracks mixed (at the audio mix's volumes and ramps) as linear PCM.
open class AVAssetReaderAudioMixOutput: AVAssetReaderOutput, @unchecked Sendable {
    public let audioTracks: [AVAssetTrack]
    public let audioSettings: [String: Any]?
    open var audioMix: AVAudioMix?
    open var audioTimePitchAlgorithm: AVAudioTimePitchAlgorithm?
    open override var mediaType: AVMediaType { .audio }
    public init(audioTracks: [AVAssetTrack], audioSettings: [String: Any]?) { self.audioTracks = audioTracks; self.audioSettings = audioSettings }
    override func _open(_ range: CMTimeRange) -> _ReaderStream? {
        guard let u = _reader?._render(video: false, audioTrackIDs: audioTracks.map(\.trackID), audioMix: audioMix, videoComposition: nil) else { return nil }
        return _DecodedStream(url: u, video: false, range: range, settings: audioSettings ?? [:], size: .zero, fps: 0)
    }
}

/// The asset's video as the video composition renders it (render size, frame duration).
open class AVAssetReaderVideoCompositionOutput: AVAssetReaderOutput, @unchecked Sendable {
    public let videoTracks: [AVAssetTrack]
    public let videoSettings: [String: Any]?
    open var videoComposition: AVVideoComposition?
    var _compositor: (any AVVideoCompositing)?
    /// the instance of the video composition's customVideoCompositorClass, made when reading starts
    open var customVideoCompositor: (any AVVideoCompositing)? { _compositor }
    open override var mediaType: AVMediaType { .video }
    public init(videoTracks: [AVAssetTrack], videoSettings: [String: Any]?) { self.videoTracks = videoTracks; self.videoSettings = videoSettings }
    override func _open(_ range: CMTimeRange) -> _ReaderStream? {
        if _compositor == nil, let k = videoComposition?.customVideoCompositorClass { _compositor = _avMakeCompositor(k) }
        guard let asset = _reader?.asset,
              let u = _reader?._render(video: true, audioTrackIDs: [], audioMix: nil, videoComposition: videoComposition, compositor: _compositor) else { return nil }
        let size = videoComposition.map { $0.renderSize.width > 0 ? $0.renderSize : asset.naturalSize } ?? asset.naturalSize
        let fps = videoComposition.map { $0.frameDuration.seconds > 0 ? 1 / $0.frameDuration.seconds : 30 } ?? Double(videoTracks.first?.nominalFrameRate ?? 30)
        return _DecodedStream(url: u, video: true, range: range, settings: videoSettings ?? [:], size: size, fps: fps)
    }
}

open class AVAssetReader: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, reading, completed, failed, cancelled }
    public let asset: AVAsset
    open private(set) var outputs: [AVAssetReaderOutput] = []
    open private(set) var status: Status = .unknown
    open private(set) var error: Error?
    open var timeRange = CMTimeRange(start: .zero, duration: .positiveInfinity)
    var _ended = 0
    var _renders: [String: URL] = [:]
    public init(asset: AVAsset) throws {
        self.asset = asset
        super.init()
        if !(asset is AVComposition) { try asset._check() }
    }
    deinit { for u in _renders.values { try? FileManager.default.removeItem(at: u) } }
    open func canAdd(_ output: AVAssetReaderOutput) -> Bool { status == .unknown && !outputs.contains(output) }
    open func add(_ output: AVAssetReaderOutput) { if canAdd(output) { outputs.append(output); output._reader = self } }
    @discardableResult open func startReading() -> Bool {
        guard status == .unknown else { return false }
        status = .reading
        for o in outputs where !o._start(timeRange) {
            outputs.forEach { $0._stop() }
            status = .failed
            if error == nil { error = _avNSError(.decoderNotFound, "isim needs ffmpeg on the host to decode media") }
            return false
        }
        return true
    }
    open func cancelReading() { outputs.forEach { $0._stop() }; if status == .reading { status = .cancelled } }
    func _outputEnded() {
        _ended += 1
        if _ended >= outputs.count, status == .reading { status = .completed; outputs.forEach { $0._stop() } }
    }
    /// the asset rendered losslessly for decoding: a composition, an audio mix or a video composition (cached)
    func _render(video: Bool, audioTrackIDs: [CMPersistentTrackID]?, audioMix: AVAudioMix?, videoComposition: AVVideoComposition?,
                 compositor: (any AVVideoCompositing)? = nil) -> URL? {
        let key = "\(video) \(audioTrackIDs.map { $0.map(String.init).joined(separator: ",") } ?? "all") \(audioMix.map { "\(ObjectIdentifier($0))" } ?? "") \(videoComposition.map { "\(ObjectIdentifier($0))" } ?? "")"
        if let u = _renders[key] { return u }
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-reader-\(UUID().uuidString).mkv")
        s.outputURL = out; s.outputFileType = .mov
        s._lossless = true; s._wantVideo = video; s._wantAudio = audioTrackIDs.map { !$0.isEmpty } ?? true; s._audioTrackIDs = audioTrackIDs
        s.audioMix = audioMix; s.videoComposition = videoComposition; s._compositor = compositor
        s._run()
        guard s.status == .completed else { error = s.error ?? _avNSError(.decodeFailed, "the asset could not be rendered"); return nil }
        _renders[key] = out
        return out
    }
}

// MARK: - AVAssetWriter

/// Spools BGRA frames to a temporary file; `finish` encodes them with ffmpeg (used by AVAssetWriter and AVCaptureMovieFileOutput).
final class _RawVideoSink: @unchecked Sendable {
    let width: Int, height: Int
    let path = NSTemporaryDirectory() + "isim-video-\(UUID().uuidString).bgra"
    let handle: FileHandle?
    var times: [Double] = []
    let lock = NSLock()
    init(width: Int, height: Int) {
        self.width = width; self.height = height
        FileManager.default.createFile(atPath: path, contents: nil)
        handle = FileHandle(forWritingAtPath: path)
    }
    deinit { try? handle?.close(); try? FileManager.default.removeItem(atPath: path) }
    func append(_ px: UnsafePointer<UInt8>, time: Double) {
        lock.lock(); defer { lock.unlock() }
        handle?.write(Data(bytes: px, count: width * height * 4))
        times.append(time)
    }
    var fps: Double {
        guard times.count > 1, let a = times.first, let b = times.last, b > a else { return 30 }
        return Double(times.count - 1) / (b - a)
    }
    /// ffmpeg input arguments for the spooled frames
    func inputArgs(fps f: Double? = nil) -> [String] {
        try? handle?.synchronize()
        return ["-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(width)x\(height)", "-r", String(format: "%.4f", f ?? fps), "-i", path]
    }
    func finish(to url: URL, fileType: AVFileType, fps f: Double) -> Error? {
        try? FileManager.default.removeItem(at: url)
        return _FFmpeg.run(["-y"] + inputArgs(fps: f) + _FFmpeg.videoCodecArgs(.h264, bitrate: nil) + ["-f", fileType._muxer.0, _path(url)])
    }
}

open class AVAssetWriterInput: NSObject, @unchecked Sendable {
    public let mediaType: AVMediaType
    public let outputSettings: [String: Any]?
    public let sourceFormatHint: CMFormatDescription?
    open var expectsMediaDataInRealTime = false
    open var transform = CGAffineTransform.identity
    open var mediaTimeScale: CMTimeScale = 0
    open var performsMultiPassEncodingIfSupported = false
    open var naturalSize: CGSize = .zero
    open var languageCode: String?
    weak var _writer: AVAssetWriter?
    var _finished = false
    var _video: _RawVideoSink?
    var _audio: Data?
    var _audioASBD: AudioStreamBasicDescription?
    var _firstTime: CMTime?
    /// pass-through: compressed samples (payload, presentation, decode time, duration, sync) and their format
    var _compressed: [(Data, CMTime, CMTime, CMTime, Bool)] = []
    var _compressedFormat: CMFormatDescription?
    public init(mediaType: AVMediaType, outputSettings: [String: Any]?, sourceFormatHint: CMFormatDescription?) {
        self.mediaType = mediaType; self.outputSettings = outputSettings; self.sourceFormatHint = sourceFormatHint
    }
    public convenience init(mediaType: AVMediaType, outputSettings: [String: Any]?) { self.init(mediaType: mediaType, outputSettings: outputSettings, sourceFormatHint: nil) }
    open var isReadyForMoreMediaData: Bool { _writer?.status == .writing && !_finished }
    open func markAsFinished() { _finished = true }
    @discardableResult open func append(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard isReadyForMoreMediaData else { return false }
        if let pb = sampleBuffer.imageBuffer { return _appendPixels(pb, sampleBuffer.presentationTimeStamp) }
        if let f = sampleBuffer.formatDescription, let block = sampleBuffer.dataBuffer,
           f.mediaType == kCMMediaType_Video || (f.mediaType == kCMMediaType_Audio && !f._asbd._isPCM) {
            // compressed samples: written as they are (pass-through), whatever the output settings say (adapted)
            if _compressedFormat == nil { _compressedFormat = f; _firstTime = sampleBuffer.presentationTimeStamp }
            let timings = sampleBuffer._timings.isEmpty ? [sampleBuffer._timing] : sampleBuffer._timings
            for i in 0..<max(1, sampleBuffer.numSamples) {
                guard let r = sampleBuffer._sampleRange(i) else { break }
                let t = i < timings.count ? timings[i] : timings.last!
                var pts = t.presentationTimeStamp, dur = t.duration
                if timings.count == 1 && sampleBuffer.numSamples > 1, t.duration.isNumeric {    // one entry for all: consecutive samples
                    dur = t.duration
                    pts = t.presentationTimeStamp + CMTimeMultiply(t.duration, multiplier: Int32(i))
                }
                let dts = t.decodeTimeStamp.isNumeric ? (timings.count == 1 && i > 0 ? pts : t.decodeTimeStamp) : pts
                _compressed.append((Data(block._bytes[r]), pts, dts, dur, _isimSampleIsSync(sampleBuffer, i)))
            }
            return true
        }
        guard mediaType == .audio, let asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription, let block = sampleBuffer.dataBuffer else { return false }
        if _audioASBD == nil { _audioASBD = asbd; _audio = Data(); _firstTime = sampleBuffer.presentationTimeStamp }
        _audio?.append(contentsOf: block._bytes)
        return true
    }
    func _appendPixels(_ pb: CVPixelBuffer, _ t: CMTime) -> Bool {
        guard mediaType == .video else { return false }
        if _video == nil {
            let w = Int(_num(outputSettings, AVVideoWidthKey) ?? Double(pb._width)), h = Int(_num(outputSettings, AVVideoHeightKey) ?? Double(pb._height))
            guard w == pb._width, h == pb._height else {
                NSLog("isim AVFoundation: AVAssetWriterInput frames must match AVVideoWidthKey/AVVideoHeightKey (%dx%d), got %dx%d", w, h, pb._width, pb._height)
                return false
            }
            _video = _RawVideoSink(width: w, height: h)
            _firstTime = t
        }
        guard let v = _video, pb._width == v.width, pb._height == v.height else { return false }
        let px = pb._bgra()
        px.withUnsafeBufferPointer { v.append($0.baseAddress!, time: t.seconds) }
        return true
    }
    open func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {
        queue.async { [weak self] in
            while let s = self, !s._finished, s._writer?.status == .writing { block() }
        }
    }
    open func canAddTrackAssociation(withTrackOf input: AVAssetWriterInput, type: String) -> Bool { false }
    open func addTrackAssociation(withTrackOf input: AVAssetWriterInput, type: String) {}
}

open class AVAssetWriterInputPixelBufferAdaptor: NSObject, @unchecked Sendable {
    public let assetWriterInput: AVAssetWriterInput
    public let sourcePixelBufferAttributes: [String: Any]?
    public init(assetWriterInput input: AVAssetWriterInput, sourcePixelBufferAttributes: [String: Any]?) {
        assetWriterInput = input; self.sourcePixelBufferAttributes = sourcePixelBufferAttributes
    }
    /// available after startWriting(), like iOS
    open var pixelBufferPool: CVPixelBufferPool? {
        guard assetWriterInput._writer?.status == .writing else { return nil }
        let a = sourcePixelBufferAttributes
        let w = Int(_num(a, kCVPixelBufferWidthKey as String) ?? _num(assetWriterInput.outputSettings, AVVideoWidthKey) ?? 0)
        let h = Int(_num(a, kCVPixelBufferHeightKey as String) ?? _num(assetWriterInput.outputSettings, AVVideoHeightKey) ?? 0)
        guard w > 0, h > 0 else { return nil }
        let f = _num(a, kCVPixelBufferPixelFormatTypeKey as String).map { OSType($0) } ?? kCVPixelFormatType_32BGRA
        return _CVPixelBufferPoolMake(width: w, height: h, format: f)
    }
    @discardableResult open func append(_ pixelBuffer: CVPixelBuffer, withPresentationTime t: CMTime) -> Bool {
        guard assetWriterInput.isReadyForMoreMediaData else { return false }
        return assetWriterInput._appendPixels(pixelBuffer, t)
    }
}

open class AVAssetWriter: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, writing, completed, failed, cancelled }
    public let outputURL: URL
    public let outputFileType: AVFileType
    open private(set) var inputs: [AVAssetWriterInput] = []
    open private(set) var status: Status = .unknown
    open private(set) var error: Error?
    open var shouldOptimizeForNetworkUse = false
    open var movieTimeScale: CMTimeScale = 0
    open var metadata: [Any] = []
    var _sessionStart: CMTime = .invalid
    var _sessionEnd: CMTime = .invalid
    public init(outputURL: URL, fileType: AVFileType) throws {
        self.outputURL = outputURL; outputFileType = fileType
        super.init()
        if FileManager.default.fileExists(atPath: outputURL.path) { throw AVError(.fileAlreadyExists) }
    }
    public convenience init(url: URL, fileType: AVFileType) throws { try self.init(outputURL: url, fileType: fileType) }
    open var availableMediaTypes: [AVMediaType] { outputFileType._muxer.1 ? [.video, .audio] : [.audio] }
    open func canAdd(_ input: AVAssetWriterInput) -> Bool { status == .unknown && availableMediaTypes.contains(input.mediaType) && !inputs.contains(input) }
    open func add(_ input: AVAssetWriterInput) { if canAdd(input) { inputs.append(input); input._writer = self } }
    open func canApply(outputSettings: [String: Any]?, forMediaType mediaType: AVMediaType) -> Bool { availableMediaTypes.contains(mediaType) }
    @discardableResult open func startWriting() -> Bool {
        guard status == .unknown, !inputs.isEmpty else { return false }
        status = .writing; return true
    }
    open func startSession(atSourceTime t: CMTime) { _sessionStart = t }
    open func endSession(atSourceTime t: CMTime) { _sessionEnd = t }
    open func cancelWriting() { status = .cancelled; try? FileManager.default.removeItem(at: outputURL) }
    open func finishWriting(completionHandler handler: @escaping @Sendable () -> Void) {
        guard status == .writing else { DispatchQueue.global().async { handler() }; return }
        inputs.forEach { $0._finished = true }
        DispatchQueue.global().async {
            self._encode()
            handler()
        }
    }
    open func finishWriting() async { await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in finishWriting { k.resume() } } }
    @available(*, deprecated) open func finishWriting() -> Bool { inputs.forEach { $0._finished = true }; _encode(); return status == .completed }

    func _encode() {
        let start = _sessionStart.isNumeric ? _sessionStart.seconds : 0
        let items = metadata.compactMap { $0 as? AVMetadataItem }
        let (muxer, _) = outputFileType._muxer
        let movie = ["mov", "mp4", "ipod", "3gp"].contains(muxer)
        let v = inputs.first { $0.mediaType == .video && $0._video != nil }
        let a = inputs.first { $0.mediaType == .audio && $0._audio?.isEmpty == false }
        let pass = inputs.filter { !$0._compressed.isEmpty }
        // frames appended at uneven times keep them: encoded at a constant rate, then given their times again
        let vfr: Bool = {
            guard let times = v?._video?.times, times.count > 2 else { return false }
            let d = zip(times.dropFirst(), times).map { $0 - $1 }
            guard let mn = d.min(), let mx = d.max() else { return false }
            return mx - mn > 0.002
        }()
        let remux = movie && (!pass.isEmpty || vfr)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-writer-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: tmp) }
        if v != nil || a != nil {
            var args = ["-y"]
            var n = 0
            var pcmPath: String?
            if let v, let sink = v._video {
                let lead = remux ? 0 : max(0, (v._firstTime?.seconds ?? start) - start)
                if lead > 0.001 { args += ["-itsoffset", String(format: "%.6f", lead)] }
                args += sink.inputArgs(); n += 1
            }
            if let a, let asbd = a._audioASBD, let data = a._audio {
                let p = NSTemporaryDirectory() + "isim-audio-\(UUID().uuidString).pcm"
                FileManager.default.createFile(atPath: p, contents: data)
                pcmPath = p
                let bits = Int(asbd.mBitsPerChannel)
                let fmt = asbd._isFloat ? (bits == 64 ? "f64" : "f32") : (bits == 8 ? "u8" : "s\(bits)")
                let lead = max(0, (a._firstTime?.seconds ?? start) - start)
                if lead > 0.001 { args += ["-itsoffset", String(format: "%.6f", lead)] }
                args += ["-f", fmt + (bits == 8 && !asbd._isFloat ? "" : asbd._isBigEndian ? "be" : "le"), "-ar", String(Int(asbd.mSampleRate)), "-ac", String(asbd.mChannelsPerFrame), "-i", p]
                n += 1
            }
            defer { if let pcmPath { try? FileManager.default.removeItem(atPath: pcmPath) } }
            for i in 0..<n { args += ["-map", "\(i)"] }
            if let v {
                let codec = (v.outputSettings?[AVVideoCodecKey] as? String).map(AVVideoCodecType.init(rawValue:)) ?? (v.outputSettings?[AVVideoCodecKey] as? AVVideoCodecType)
                let br = _num(v.outputSettings?[AVVideoCompressionPropertiesKey] as? [String: Any], AVVideoAverageBitRateKey)
                args += _FFmpeg.videoCodecArgs(codec, bitrate: br)
                if remux { args += ["-bf", "0"] }                // frames keep their order, so they can get their own times
            }
            if let a { args += _FFmpeg.audioCodecArgs(a.outputSettings, fileType: remux ? .mov : outputFileType) }
            if _sessionEnd.isNumeric && !remux { args += ["-t", String(format: "%.6f", _sessionEnd.seconds - start)] }
            if !remux {
                if shouldOptimizeForNetworkUse { args += ["-movflags", "+faststart"] }
                if !items.isEmpty { args += _MetadataMap.arguments(items); if movie { args += ["-movflags", "use_metadata_tags"] } }
            }
            args += ["-f", remux ? "mov" : muxer, _path(remux ? tmp : outputURL)]
            if let e = _FFmpeg.run(args) { status = .failed; error = e; try? FileManager.default.removeItem(at: outputURL); return }
        } else if pass.isEmpty {
            status = .failed; error = _avNSError(.noDataCaptured, "no samples were appended"); return
        }
        guard remux else { status = .completed; return }
        // our own muxer: encoded tracks with their real times, and pass-through samples as they came
        var tracks: [_MP4.OutTrack] = []
        if v != nil || a != nil {
            guard let d = try? Data(contentsOf: tmp), let enc = _MP4.read(d) else { status = .failed; error = _avNSError(.exportFailed, "the encoded media could not be read"); return }
            for t in enc {
                var o = _MP4.OutTrack(handler: t.handler, codec: t.codec, width: t.width, height: t.height, sampleRate: t.sampleRate, channels: t.channels,
                                      atoms: t.atoms.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }, timescale: t.timescale)
                o.editMediaTime = t.editMediaTime > 0 ? t.editMediaTime : nil
                let times = t.isVideo ? (v?._video?.times ?? []) : []
                let ts = Double(t.timescale)
                let first = times.first ?? 0
                for (i, smp) in t.samples.enumerated() {
                    let payload = d.subdata(in: (d.startIndex + smp.offset)..<(d.startIndex + smp.offset + smp.size))
                    if t.isVideo && i < times.count {
                        let pts = Int64(((times[i] - first) * ts).rounded())
                        let next = i + 1 < times.count ? Int64(((times[i + 1] - first) * ts).rounded()) : pts + max(1, smp.duration)
                        o.samples.append((payload, pts, pts, max(1, next - pts), smp.sync))
                    } else { o.samples.append((payload, smp.dts, smp.cts, smp.duration, smp.sync)) }
                }
                tracks.append(o)
            }
        }
        for input in pass {
            guard let f = input._compressedFormat else { continue }
            let video = f.mediaType == kCMMediaType_Video
            let ts: Int32 = input.mediaTimeScale > 0 ? input.mediaTimeScale : video ? 90000 : Int32(max(1, f._asbd.mSampleRate))
            var atoms: [(String, Data)] = []
            if let ext = f._extensions[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] as? [String: Any] {
                for (k, val) in ext.sorted(by: { $0.key < $1.key }) { if let dv = val as? Data { atoms.append((k, dv)) } else if let bv = val as? [UInt8] { atoms.append((k, Data(bv))) } }
            }
            if !video, !atoms.contains(where: { $0.0 == "esds" }), let c = f._cookie { atoms.append(("esds", Data(c))) }
            let codec: FourCharCode = video ? f.mediaSubType : f._asbd.mFormatID == kAudioFormatMPEG4AAC ? _MP4.fourcc("mp4a") : f._asbd.mFormatID
            var o = _MP4.OutTrack(handler: video ? "vide" : "soun", codec: codec, width: Int(f.dimensions.width), height: Int(f.dimensions.height),
                                  sampleRate: f._asbd.mSampleRate, channels: Int(f._asbd.mChannelsPerFrame), atoms: atoms, timescale: ts)
            func units(_ t: CMTime) -> Int64 { Int64(((t.seconds - start) * Double(ts)).rounded()) }
            let minDTS = input._compressed.map { units($0.2) }.min() ?? 0
            let shift = minDTS < 0 ? -minDTS : 0              // decode times before the session start: the edit list skips them
            for smp in input._compressed {
                let dur = smp.3.isNumeric ? max(1, Int64((smp.3.seconds * Double(ts)).rounded())) : 1
                o.samples.append((smp.0, units(smp.2) + shift, units(smp.1) + shift, dur, smp.4))
            }
            if shift > 0 { o.editMediaTime = shift }
            tracks.append(o)
        }
        do {
            try _MP4.write(tracks, to: outputURL, quickTime: muxer == "mov")
        } catch { status = .failed; self.error = _avNSError(.exportFailed, "\(error)"); return }
        if shouldOptimizeForNetworkUse || !items.isEmpty {
            let fin = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-writer-\(UUID().uuidString).\(outputURL.pathExtension.isEmpty ? "mov" : outputURL.pathExtension)")
            var args = ["-y", "-i", _path(outputURL), "-map", "0", "-c", "copy"] + _MetadataMap.arguments(items)
            args += ["-movflags", (shouldOptimizeForNetworkUse ? "+faststart" : "") + (items.isEmpty ? "" : "+use_metadata_tags"), "-f", muxer, _path(fin)]
            if let e = _FFmpeg.run(args) { status = .failed; error = e; return }
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.moveItem(at: fin, to: outputURL)
        }
        status = .completed
    }
}
