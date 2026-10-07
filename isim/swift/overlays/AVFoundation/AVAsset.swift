// isim AVFoundation: assets (AVAsset, AVURLAsset, AVAssetTrack, async property loading, AVAssetImageGenerator).
// Media is inspected by the host's ffprobe and thumbnails come from ffmpeg (host_media.c); local files and
// http(s) URLs. Composition, export, reader and writer: AVComposition.swift. No metadata.
import UIKit
import isim_host

public struct AVMediaType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let video = AVMediaType("vide")
    public static let audio = AVMediaType("soun")
    public static let text = AVMediaType("text")
    public static let closedCaption = AVMediaType("clcp")
    public static let subtitle = AVMediaType("sbtl")
    public static let timecode = AVMediaType("tmcd")
    public static let metadata = AVMediaType("meta")
    public static let muxed = AVMediaType("muxx")
}
public enum AVKeyValueStatus: Int, Sendable { case unknown = 0, loading, loaded, failed, cancelled }
public typealias CMPersistentTrackID = Int32

/// What ffprobe reported about a media URL.
final class _AVMediaInfo: @unchecked Sendable {
    let ok: Bool, duration: Double, width: Double, height: Double, fps: Double, hasVideo: Bool, hasAudio: Bool
    init(url: URL) {
        var i = isim_media_info()
        let path = url.isFileURL ? url.path : url.absoluteString
        ok = isim_media_probe(path, &i) != 0
        duration = i.duration; width = i.width; height = i.height; fps = i.fps
        hasVideo = i.has_video != 0; hasAudio = i.has_audio != 0
    }
}

public protocol AVAsynchronousKeyValueLoading {
    func statusOfValue(forKey key: String, error outError: UnsafeMutablePointer<NSError?>?) -> AVKeyValueStatus
    func loadValuesAsynchronously(forKeys keys: [String], completionHandler handler: (@Sendable () -> Void)?)
}

open class AVAsset: NSObject, AVAsynchronousKeyValueLoading, @unchecked Sendable {
    let _url: URL?
    private var _info: _AVMediaInfo?
    private let _lock = NSLock()
    init(_url: URL?) { self._url = _url }
    public convenience init(url URL: URL) { self.init(_url: URL) }
    /// The probed media (blocking the first time).
    var _media: _AVMediaInfo? {
        guard let u = _url else { return nil }
        _lock.lock(); defer { _lock.unlock() }
        if _info == nil { _info = _AVMediaInfo(url: u) }
        return _info
    }
    var _loaded: Bool { _lock.lock(); defer { _lock.unlock() }; return _info != nil }

    open var duration: CMTime {
        guard let m = _media, m.ok else { return .invalid }
        return m.duration > 0 ? CMTime(seconds: m.duration, preferredTimescale: 600) : .indefinite
    }
    open var tracks: [AVAssetTrack] {
        guard let m = _media, m.ok else { return [] }
        var t: [AVAssetTrack] = []
        let range = CMTimeRange(start: .zero, duration: duration)
        if m.hasVideo {
            t.append(AVAssetTrack(asset: self, id: 1, type: .video, size: CGSize(width: m.width, height: m.height), fps: Float(m.fps), range: range))
        }
        if m.hasAudio { t.append(AVAssetTrack(asset: self, id: Int32(t.count + 1), type: .audio, size: .zero, fps: 0, range: range)) }
        return t
    }
    open func tracks(withMediaType mediaType: AVMediaType) -> [AVAssetTrack] { tracks.filter { $0.mediaType == mediaType } }
    open func track(withTrackID id: CMPersistentTrackID) -> AVAssetTrack? { tracks.first { $0.trackID == id } }
    open func loadTracks(withMediaType mediaType: AVMediaType) async throws -> [AVAssetTrack] { try _check(); return tracks(withMediaType: mediaType) }
    open func loadTrack(withTrackID id: CMPersistentTrackID) async throws -> AVAssetTrack? { try _check(); return track(withTrackID: id) }
    open var isPlayable: Bool { _media?.ok ?? false }
    open var isReadable: Bool { _media?.ok ?? false }
    open var isExportable: Bool { _media?.ok ?? false }
    open var isComposable: Bool { _media?.ok ?? false }
    open var hasProtectedContent: Bool { false }
    open var providesPreciseDurationAndTiming: Bool { true }
    open var preferredRate: Float { 1 }
    open var preferredVolume: Float { 1 }
    open var preferredTransform: CGAffineTransform { .identity }
    open var naturalSize: CGSize { tracks(withMediaType: .video).first?.naturalSize ?? .zero }

    open func statusOfValue(forKey key: String, error outError: UnsafeMutablePointer<NSError?>?) -> AVKeyValueStatus {
        guard _loaded else { return .unknown }
        if _media?.ok == true { return .loaded }
        outError?.pointee = _avLoadError(self)
        return .failed
    }
    open func loadValuesAsynchronously(forKeys keys: [String], completionHandler handler: (@Sendable () -> Void)? = nil) {
        DispatchQueue.global().async { _ = self._media; handler?() }
    }
    open func cancelLoading() {}
    func _check() throws { if _media?.ok != true { throw _avLoadError(self) } }
    /// the media file and time within it that shows this asset's video at time t (compositions map their segments)
    func _videoSource(at t: Double) -> (URL, Double)? {
        guard let u = _url, isPlayable else { return nil }
        return (u, t)
    }
}

func _avLoadError(_ a: AVAsset) -> NSError {
    NSError(domain: AVFoundationErrorDomain, code: -11800,
            userInfo: [NSLocalizedDescriptionKey: "The operation could not be completed",
                       NSLocalizedFailureReasonErrorKey: "isim could not open \(a._url?.absoluteString ?? "the asset") (missing file, unsupported media, or no ffprobe/ffmpeg on the host)"])
}
public let NSLocalizedFailureReasonErrorKey = "NSLocalizedFailureReason"

open class AVURLAsset: AVAsset, @unchecked Sendable {
    public let url: URL
    public init(url URL: URL, options: [String: Any]? = nil) { url = URL; super.init(_url: URL) }
    public static func audiovisualTypes() -> [String] { ["public.mpeg-4", "com.apple.quicktime-movie", "public.mp3", "com.apple.m4a-audio", "com.apple.m4v-video"] }
    public static func audiovisualMIMETypes() -> [String] { ["video/mp4", "video/quicktime", "audio/mpeg", "audio/mp4"] }
    public static func isPlayableExtendedMIMEType(_ t: String) -> Bool { t.hasPrefix("video/") || t.hasPrefix("audio/") }
}

open class AVAssetTrack: NSObject, AVAsynchronousKeyValueLoading, @unchecked Sendable {
    public private(set) weak var asset: AVAsset?
    public let trackID: CMPersistentTrackID
    public let mediaType: AVMediaType
    var _naturalSize: CGSize
    var _nominalFrameRate: Float
    var _timeRange: CMTimeRange
    public final var naturalSize: CGSize { _naturalSize }
    public final var nominalFrameRate: Float { _nominalFrameRate }
    public final var timeRange: CMTimeRange { _timeRange }
    init(asset: AVAsset?, id: Int32, type: AVMediaType, size: CGSize, fps: Float, range: CMTimeRange) {
        self.asset = asset; trackID = id; mediaType = type; _naturalSize = size; _nominalFrameRate = fps; _timeRange = range
    }
    open var isPlayable: Bool { true }
    open var isEnabled: Bool { true }
    open var isDecodable: Bool { true }
    open var preferredTransform: CGAffineTransform { .identity }
    open var preferredVolume: Float { 1 }
    open var estimatedDataRate: Float { 0 }
    open var languageCode: String? { nil }
    open var minFrameDuration: CMTime { nominalFrameRate > 0 ? CMTime(value: 1, timescale: Int32(nominalFrameRate.rounded())) : .invalid }
    open func hasMediaCharacteristic(_ c: AVMediaCharacteristic) -> Bool {
        switch c { case .visual: return mediaType == .video; case .audible: return mediaType == .audio; default: return false }
    }
    open func statusOfValue(forKey key: String, error outError: UnsafeMutablePointer<NSError?>?) -> AVKeyValueStatus { .loaded }
    open func loadValuesAsynchronously(forKeys keys: [String], completionHandler handler: (@Sendable () -> Void)? = nil) { DispatchQueue.global().async { handler?() } }
}
public struct AVMediaCharacteristic: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let visual = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicVisual")
    public static let audible = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicAudible")
    public static let legible = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicLegible")
}

// MARK: - async loading (iOS 15+): try await asset.load(.duration, .tracks)

public class AVAnyAsyncProperty: @unchecked Sendable {
    let key: String
    init(key: String) { self.key = key }
}
public class AVPartialAsyncProperty<Root>: AVAnyAsyncProperty, @unchecked Sendable {}
public final class AVAsyncProperty<Root, Value>: AVPartialAsyncProperty<Root>, @unchecked Sendable {
    let get: (Root) throws -> Value
    init(_ key: String, _ get: @escaping (Root) throws -> Value) { self.get = get; super.init(key: key) }
}
extension AVPartialAsyncProperty where Root: AVAsset {
    public static var duration: AVAsyncProperty<Root, CMTime> { AVAsyncProperty("duration") { try $0._check(); return $0.duration } }
    public static var tracks: AVAsyncProperty<Root, [AVAssetTrack]> { AVAsyncProperty("tracks") { try $0._check(); return $0.tracks } }
    public static var isPlayable: AVAsyncProperty<Root, Bool> { AVAsyncProperty("playable") { $0.isPlayable } }
    public static var isReadable: AVAsyncProperty<Root, Bool> { AVAsyncProperty("readable") { $0.isReadable } }
    public static var isExportable: AVAsyncProperty<Root, Bool> { AVAsyncProperty("exportable") { $0.isExportable } }
    public static var hasProtectedContent: AVAsyncProperty<Root, Bool> { AVAsyncProperty("hasProtectedContent") { $0.hasProtectedContent } }
    public static var preferredRate: AVAsyncProperty<Root, Float> { AVAsyncProperty("preferredRate") { $0.preferredRate } }
    public static var preferredVolume: AVAsyncProperty<Root, Float> { AVAsyncProperty("preferredVolume") { $0.preferredVolume } }
    public static var preferredTransform: AVAsyncProperty<Root, CGAffineTransform> { AVAsyncProperty("preferredTransform") { $0.preferredTransform } }
}
extension AVPartialAsyncProperty where Root: AVAssetTrack {
    public static var naturalSize: AVAsyncProperty<Root, CGSize> { AVAsyncProperty("naturalSize") { $0.naturalSize } }
    public static var nominalFrameRate: AVAsyncProperty<Root, Float> { AVAsyncProperty("nominalFrameRate") { $0.nominalFrameRate } }
    public static var timeRange: AVAsyncProperty<Root, CMTimeRange> { AVAsyncProperty("timeRange") { $0.timeRange } }
    public static var preferredTransform: AVAsyncProperty<Root, CGAffineTransform> { AVAsyncProperty("preferredTransform") { $0.preferredTransform } }
    public static var mediaType: AVAsyncProperty<Root, AVMediaType> { AVAsyncProperty("mediaType") { $0.mediaType } }
    public static var isPlayable: AVAsyncProperty<Root, Bool> { AVAsyncProperty("playable") { $0.isPlayable } }
}
extension AVAsynchronousKeyValueLoading {
    // isim: probing runs in the calling task (blocking it briefly for local files)
    public func load<T>(_ p: AVAsyncProperty<Self, T>) async throws -> T { try p.get(self) }
    public func load<A, B>(_ a: AVAsyncProperty<Self, A>, _ b: AVAsyncProperty<Self, B>) async throws -> (A, B) { (try a.get(self), try b.get(self)) }
    public func load<A, B, C>(_ a: AVAsyncProperty<Self, A>, _ b: AVAsyncProperty<Self, B>, _ c: AVAsyncProperty<Self, C>) async throws -> (A, B, C) {
        (try a.get(self), try b.get(self), try c.get(self))
    }
    public func load<A, B, C, D>(_ a: AVAsyncProperty<Self, A>, _ b: AVAsyncProperty<Self, B>, _ c: AVAsyncProperty<Self, C>, _ d: AVAsyncProperty<Self, D>) async throws -> (A, B, C, D) {
        (try a.get(self), try b.get(self), try c.get(self), try d.get(self))
    }
}

// MARK: - AVAssetImageGenerator (thumbnails)

open class AVAssetImageGenerator: NSObject, @unchecked Sendable {
    public let asset: AVAsset
    open var appliesPreferredTrackTransform = false
    open var maximumSize: CGSize = .zero
    open var requestedTimeToleranceBefore: CMTime = .positiveInfinity
    open var requestedTimeToleranceAfter: CMTime = .positiveInfinity
    public enum Result: Int, Sendable { case succeeded = 0, failed, cancelled }
    public typealias CompletionHandler = @Sendable (CMTime, CGImage?, CMTime, Result, Error?) -> Void
    public init(asset: AVAsset) { self.asset = asset }

    open func copyCGImage(at requestedTime: CMTime, actualTime: UnsafeMutablePointer<CMTime>?) throws -> CGImage {
        let t = max(0, requestedTime.isNumeric ? requestedTime.seconds : 0)
        guard let (u, st) = asset._videoSource(at: t), asset.tracks(withMediaType: .video).count > 0 else { throw _avLoadError(asset) }
        let side = max(maximumSize.width, maximumSize.height)
        var out: UnsafeMutableRawPointer? = nil
        var len = 0
        guard isim_media_thumbnail_png(u.isFileURL ? u.path : u.absoluteString, st, Double(side), &out, &len) != 0, let p = out else { throw _avLoadError(asset) }
        var w = 0.0, h = 0.0
        let handle = isim_image_load_data(p, UInt(len), &w, &h)
        isim_media_free(p)
        guard handle > 0, let img = isim_cg_image_create(handle, CGRect(x: 0, y: 0, width: w, height: h), nil) else { throw _avLoadError(asset) }
        actualTime?.pointee = CMTime(seconds: t, preferredTimescale: 600)
        return img
    }
    open func image(at time: CMTime) async throws -> (image: CGImage, actualTime: CMTime) {
        var actual = CMTime.zero
        let img = try copyCGImage(at: time, actualTime: &actual)
        return (img, actual)
    }
    open func generateCGImagesAsynchronously(forTimes requestedTimes: [NSValue], completionHandler handler: @escaping CompletionHandler) {
        DispatchQueue.global().async {
            for v in requestedTimes {
                let t = v.timeValue
                var actual = CMTime.zero
                do { let img = try self.copyCGImage(at: t, actualTime: &actual); handler(t, img, actual, .succeeded, nil) }
                catch { handler(t, nil, .zero, .failed, error) }
            }
        }
    }
    open func cancelAllCGImageGeneration() {}
}
