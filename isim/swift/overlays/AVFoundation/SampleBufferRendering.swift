// isim AVFoundation: rendering sample buffers an app produces itself — AVSampleBufferDisplayLayer (over
// AVSampleBufferVideoRenderer), AVSampleBufferAudioRenderer and AVSampleBufferRenderSynchronizer.
// Adapted: compressed video (H.264, HEVC) is decoded by the host's libavcodec (isim_vcodec_*), uncompressed frames are
// shown as they are; a frame appears when the controlling timebase reaches its presentation time (as soon as possible
// without one), drawn like AVPlayerLayer's. Audio (LPCM, or AAC through the host codec) is mixed to 48 kHz stereo and
// played through isim's audio output at the synchronizer's time (without pitch correction at rates other than 1).
import UIKit
import isim_host

public protocol AVQueuedSampleBufferRendering: NSObjectProtocol, Sendable {
    var timebase: CMTimebase { get }
    func enqueue(_ sampleBuffer: CMSampleBuffer)
    func flush()
    var isReadyForMoreMediaData: Bool { get }
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void)
    func stopRequestingMediaData()
    var hasSufficientMediaDataForReliablePlaybackStart: Bool { get }
}

@objc public enum AVQueuedSampleBufferRenderingStatus: Int, Sendable { case unknown = 0, rendering = 1, failed = 2 }

extension Notification.Name {
    public static let AVSampleBufferDisplayLayerFailedToDecode = Notification.Name("AVSampleBufferDisplayLayerFailedToDecodeNotification")
    public static let AVSampleBufferDisplayLayerRequiresFlushToResumeDecodingDidChange = Notification.Name("AVSampleBufferDisplayLayerRequiresFlushToResumeDecodingDidChangeNotification")
    public static let AVSampleBufferVideoRendererDidFailToDecode = Notification.Name("AVSampleBufferVideoRendererDidFailToDecodeNotification")
    public static let AVSampleBufferVideoRendererRequiresFlushToResumeDecodingDidChange = Notification.Name("AVSampleBufferVideoRendererRequiresFlushToResumeDecodingDidChangeNotification")
    public static let AVSampleBufferAudioRendererWasFlushedAutomatically = Notification.Name("AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification")
    public static let AVSampleBufferAudioRendererOutputConfigurationDidChange = Notification.Name("AVSampleBufferAudioRendererOutputConfigurationDidChangeNotification")
    public static let AVSampleBufferRenderSynchronizerRateDidChange = Notification.Name("AVSampleBufferRenderSynchronizerRateDidChangeNotification")
}
public let AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey = "AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey"
public let AVSampleBufferVideoRendererDidFailToDecodeNotificationErrorKey = "AVSampleBufferVideoRendererDidFailToDecodeNotificationErrorKey"
public let AVSampleBufferAudioRendererFlushTimeKey = "AVSampleBufferAudioRendererFlushTimeKey"

/// Asks for more data on the app's queue while a renderer is ready (one request at a time; checked every display frame).
final class _AVMediaRequester: @unchecked Sendable {
    let lock = NSLock()
    var queue: DispatchQueue?, block: (@Sendable () -> Void)?
    var inFlight = false
    func set(_ q: DispatchQueue?, _ b: (@Sendable () -> Void)?) { lock.lock(); queue = q; block = b; lock.unlock() }
    func pump(_ ready: Bool) {
        lock.lock()
        guard ready, !inFlight, let q = queue, let b = block else { lock.unlock(); return }
        inFlight = true
        lock.unlock()
        q.async { [self] in
            b()
            lock.lock(); inFlight = false; lock.unlock()
        }
    }
}

/// Ticks the video renderers once per display frame while any exists.
final class _AVRenderTicker: NSObject {
    nonisolated(unsafe) static let shared = _AVRenderTicker()
    struct Weak { weak var r: AVSampleBufferVideoRenderer? }
    var renderers: [ObjectIdentifier: Weak] = [:]
    var link: CADisplayLink?
    func add(_ r: AVSampleBufferVideoRenderer) {
        DispatchQueue.main.async { [self] in
            renderers[ObjectIdentifier(r)] = Weak(r: r)
            if link == nil {
                let l = CADisplayLink(target: self, selector: #selector(tick))
                l.add(to: RunLoop.main, forMode: .common)
                link = l
            }
        }
    }
    @objc func tick() {
        for (k, w) in renderers {
            guard let r = w.r else { renderers[k] = nil; continue }
            r._tick()
        }
        if renderers.isEmpty { link?.invalidate(); link = nil }
    }
}

// MARK: - video

/// A decoded or uncompressed frame waiting for its time.
struct _AVVideoFrame {
    let pts: Double
    let immediate: Bool
    let pixelBuffer: CVPixelBuffer?
    let bgra: [UInt8]?
    let width: Int, height: Int
}

@objc(AVSampleBufferVideoRenderer) open class AVSampleBufferVideoRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    let lock = NSRecursiveLock()
    var pending: [_AVVideoFrame] = []
    var decoder: OpaquePointer?
    var decoderFormat: CMFormatDescription?
    /// presentation times of samples in the decoder, sorted: decoded frames come out in presentation order
    var decoding: [(pts: Double, immediate: Bool, display: Bool)] = []
    var shown: _AVVideoFrame?
    var _status: AVQueuedSampleBufferRenderingStatus = .unknown
    var _error: Error?
    var _requiresFlush = false
    let requester = _AVMediaRequester()
    /// the timebase frames follow: the layer's control timebase or a synchronizer's (nil: as soon as possible)
    var control: CMTimebase?
    /// called on the main thread when the shown frame changes
    var onFrame: [() -> Void] = []
    /// the host image of the shown frame (main thread)
    var image: Int32 = 0
    var imageSize = (0, 0)

    public override init() {
        super.init()
        _AVRenderTicker.shared.add(self)
    }
    deinit {
        if let d = decoder { isim_vcodec_close(d) }
        let img = image
        if img != 0 { DispatchQueue.main.async { isim_image_free(img) } }
    }

    open var status: AVQueuedSampleBufferRenderingStatus { lock.lock(); defer { lock.unlock() }; return _status }
    open var error: Error? { lock.lock(); defer { lock.unlock() }; return _error }
    open var requiresFlushToResumeDecoding: Bool { lock.lock(); defer { lock.unlock() }; return _requiresFlush }
    open lazy var timebase: CMTimebase = CMTimebase(_isimProvider: { [weak self] in
        guard let self else { return (0, 0) }
        self.lock.lock(); let c = self.control, last = self.shown?.pts; self.lock.unlock()
        if let c { return (c.time.seconds, c.rate) }
        return (last ?? 0, 0)
    })
    open var isReadyForMoreMediaData: Bool { lock.lock(); defer { lock.unlock() }; return _status != .failed && pending.count + decoding.count < 8 }
    open var hasSufficientMediaDataForReliablePlaybackStart: Bool { lock.lock(); defer { lock.unlock() }; return !pending.isEmpty || shown != nil }

    open func enqueue(_ sampleBuffer: CMSampleBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard _status != .failed, !_requiresFlush else { return }
        _status = .rendering
        let attachments = sampleBuffer._sampleAttachments
        func flag(_ i: Int, _ key: CFString) -> Bool { i < attachments.count && (attachments[i][key as String] as? Bool) == true }
        if let px = sampleBuffer._imageBuffer {
            guard !flag(0, kCMSampleAttachmentKey_DoNotDisplay) else { return }
            insert(_AVVideoFrame(pts: sampleBuffer.presentationTimeStamp.seconds, immediate: flag(0, kCMSampleAttachmentKey_DisplayImmediately),
                                 pixelBuffer: px, bgra: nil, width: px._width, height: px._height))
            return
        }
        guard let format = sampleBuffer._format, let block = sampleBuffer._block, format.mediaType == kCMMediaType_Video else { return }
        let hevc = format.mediaSubType == kCMVideoCodecType_HEVC
        guard hevc || format.mediaSubType == kCMVideoCodecType_H264 else { fail(AVError(.decoderNotFound)); return }
        if decoder == nil || decoderFormat != format {
            if let d = decoder { drain(d); isim_vcodec_close(d) }
            decoder = isim_vcodec_open(hevc ? "hevc" : "h264")
            decoderFormat = format
            guard decoder != nil else { fail(AVError(.decoderNotFound)); return }
        }
        let config = format._atom(hevc ? "hvcC" : "avcC") ?? []
        let sets = hevc ? _H26x.hvccSets(config) : _H26x.avccSets(config)
        let lengthSize = hevc ? (config.count > 21 ? Int(config[21] & 3) + 1 : 4) : (config.count > 4 ? Int(config[4] & 3) + 1 : 4)
        let bytes = block._bytes
        for i in 0 ..< max(1, sampleBuffer._numSamples) {
            guard let range = sampleBuffer._sampleRange(i) else { continue }
            var unit: [UInt8] = []
            if _isimSampleIsSync(sampleBuffer, i) { for s in sets { unit += [0, 0, 0, 1] + s } }
            var p = range.lowerBound
            while p + lengthSize <= range.upperBound {                 // length-prefixed NAL units to start codes
                var n = 0
                for k in 0 ..< lengthSize { n = n << 8 | Int(bytes[p + k]) }
                p += lengthSize
                guard n > 0, p + n <= range.upperBound else { break }
                unit += [0, 0, 0, 1]
                unit += bytes[p ..< p + n]
                p += n
            }
            let timing = i < sampleBuffer._timings.count ? sampleBuffer._timings[i] : sampleBuffer._timing
            let pts = (timing.presentationTimeStamp.isNumeric ? timing.presentationTimeStamp : sampleBuffer.presentationTimeStamp).seconds
            decoding.append((pts, flag(i, kCMSampleAttachmentKey_DisplayImmediately), !flag(i, kCMSampleAttachmentKey_DoNotDisplay)))
            decoding.sort { $0.pts < $1.pts }
            let st = unit.withUnsafeBufferPointer { isim_vcodec_send(decoder, $0.baseAddress, Int32($0.count)) }
            if st < 0 { collect(); _ = unit.withUnsafeBufferPointer { isim_vcodec_send(decoder, $0.baseAddress, Int32($0.count)) } }
            collect()
        }
    }
    /// moves decoded frames from the decoder to the pending frames
    func collect() {
        var w: Int32 = 0, h: Int32 = 0
        while let d = decoder, isim_vcodec_receive(d, &w, &h) == 1 {
            var px = [UInt8](repeating: 0, count: Int(w) * Int(h) * 4)
            px.withUnsafeMutableBufferPointer { isim_vcodec_frame_bgra(d, $0.baseAddress!) }
            let t = decoding.isEmpty ? (pts: shown?.pts ?? 0, immediate: true, display: true) : decoding.removeFirst()
            if t.display { insert(_AVVideoFrame(pts: t.pts, immediate: t.immediate, pixelBuffer: nil, bgra: px, width: Int(w), height: Int(h))) }
        }
    }
    func drain(_ d: OpaquePointer) { _ = isim_vcodec_send(d, nil, 0); collect() }
    func insert(_ f: _AVVideoFrame) {
        if let i = pending.firstIndex(where: { !$0.immediate && $0.pts > f.pts }), !f.immediate { pending.insert(f, at: i) } else { pending.append(f) }
    }
    func fail(_ e: Error) {
        _status = .failed; _error = e
        NSLog("isim AVFoundation: sample buffer rendering failed: %@", "\(e)")
        let info: [String: Any] = [AVSampleBufferVideoRendererDidFailToDecodeNotificationErrorKey: e]
        DispatchQueue.main.async { NotificationCenter.default.post(name: .AVSampleBufferVideoRendererDidFailToDecode, object: self, userInfo: info) }
    }

    open func flush() { flush(removingDisplayedImage: false, completionHandler: nil) }
    open func flush(removingDisplayedImage: Bool, completionHandler: (@Sendable () -> Void)? = nil) {
        lock.lock()
        pending.removeAll(); decoding.removeAll()
        if let d = decoder { isim_vcodec_flush(d) }
        _requiresFlush = false
        if _status == .failed { _status = .unknown; _error = nil }
        if removingDisplayedImage { shown = nil }
        lock.unlock()
        DispatchQueue.main.async { [self] in
            if removingDisplayedImage { for f in onFrame { f() } }
            completionHandler?()
        }
    }
    open func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {
        requester.set(queue, block)
        requester.pump(isReadyForMoreMediaData)
    }
    open func stopRequestingMediaData() { requester.set(nil, nil) }
    /// the frame on screen, as a pixel buffer (iOS 17.4)
    open func copyDisplayedPixelBuffer() -> CVPixelBuffer? {
        lock.lock(); let f = shown; lock.unlock()
        guard let f else { return nil }
        if let p = f.pixelBuffer { return p }
        guard let px = f.bgra else { return nil }
        var out: CVPixelBuffer?
        CVPixelBufferCreate(nil, f.width, f.height, kCVPixelFormatType_32BGRA, nil, &out)
        guard let b = out else { return nil }
        CVPixelBufferLockBaseAddress(b, [])
        if let base = CVPixelBufferGetBaseAddress(b) {
            let bpr = CVPixelBufferGetBytesPerRow(b)
            px.withUnsafeBytes { src in for y in 0 ..< f.height { memcpy(base + y * bpr, src.baseAddress! + y * f.width * 4, f.width * 4) } }
        }
        CVPixelBufferUnlockBaseAddress(b, [])
        return b
    }
    open func expectMinimumUpcomingSampleBufferPresentationTime(_ minimumUpcomingPresentationTime: CMTime) {}
    open func expectMonotonicallyIncreasingUpcomingSampleBufferPresentationTimes() {}
    open func resetUpcomingSampleBufferPresentationTimeExpectations() {}

    /// main thread, every display frame: shows the newest frame that is due
    func _tick() {
        lock.lock()
        let now = control.map { $0.time.seconds }
        var due: _AVVideoFrame?
        while let f = pending.first, f.immediate || now == nil || f.pts <= now! + 0.001 { due = pending.removeFirst() }
        if let due { shown = due }
        lock.unlock()
        if let due {
            let px = due.bgra ?? due.pixelBuffer?._bgra() ?? []
            if px.count >= due.width * due.height * 4, due.width > 0 {
                if image == 0 || imageSize != (due.width, due.height) {
                    if image != 0 { isim_image_free(image) }
                    image = isim_image_create_bgra(Int32(due.width), Int32(due.height))
                    imageSize = (due.width, due.height)
                }
                px.withUnsafeBufferPointer { isim_image_update_bgra(image, $0.baseAddress, Int32(due.width), Int32(due.height)) }
            }
            for f in onFrame { f() }
        }
        requester.pump(isReadyForMoreMediaData)
    }
    /// isim (AVKit's Picture in Picture): `f` runs on the main thread when the shown frame changes
    public func _isimAddFrameObserver(_ f: @escaping () -> Void) { DispatchQueue.main.async { self.onFrame.append(f) } }
    /// isim: the shown frame's host image and size (AVKit's Picture in Picture draws it)
    public var _isimImage: (handle: Int32, width: Int, height: Int)? {
        lock.lock(); let has = shown != nil; lock.unlock()
        return has && image != 0 ? (image, imageSize.0, imageSize.1) : nil
    }
}

@objc(AVSampleBufferDisplayLayer) open class AVSampleBufferDisplayLayer: CALayer, AVQueuedSampleBufferRendering, @unchecked Sendable {
    public let sampleBufferRenderer = AVSampleBufferVideoRenderer()
    public override init() {
        super.init()
        sampleBufferRenderer.onFrame.append { [weak self] in self?.setNeedsDisplay() }
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        sampleBufferRenderer.onFrame.append { [weak self] in self?.setNeedsDisplay() }
    }
    public override init(layer: Any) { super.init(layer: layer) }
    open var videoGravity: AVLayerVideoGravity = .resizeAspect { didSet { setNeedsDisplay() } }
    /// the timebase frames follow; without one they show as soon as they are enqueued
    open var controlTimebase: CMTimebase? {
        get { sampleBufferRenderer.lock.lock(); defer { sampleBufferRenderer.lock.unlock() }; return sampleBufferRenderer.control }
        set { sampleBufferRenderer.lock.lock(); sampleBufferRenderer.control = newValue; sampleBufferRenderer.lock.unlock() }
    }
    open var timebase: CMTimebase { sampleBufferRenderer.timebase }
    open var status: AVQueuedSampleBufferRenderingStatus { sampleBufferRenderer.status }
    open var error: Error? { sampleBufferRenderer.error }
    open var requiresFlushToResumeDecoding: Bool { sampleBufferRenderer.requiresFlushToResumeDecoding }
    open var isReadyForMoreMediaData: Bool { sampleBufferRenderer.isReadyForMoreMediaData }
    open var hasSufficientMediaDataForReliablePlaybackStart: Bool { sampleBufferRenderer.hasSufficientMediaDataForReliablePlaybackStart }
    open var preventsCapture = false
    open var preventsDisplaySleepDuringVideoPlayback = true
    open var isOutputObscuredDueToInsufficientExternalProtection: Bool { false }
    open func enqueue(_ sampleBuffer: CMSampleBuffer) {
        let failed = sampleBufferRenderer.status == .failed
        sampleBufferRenderer.enqueue(sampleBuffer)
        if !failed, let e = sampleBufferRenderer.error, sampleBufferRenderer.status == .failed {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .AVSampleBufferDisplayLayerFailedToDecode, object: self,
                                                                      userInfo: [AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey: e]) }
        }
    }
    open func flush() { sampleBufferRenderer.flush() }
    open func flushAndRemoveImage() { sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil) }
    open func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {
        sampleBufferRenderer.requestMediaDataWhenReady(on: queue, using: block)
    }
    open func stopRequestingMediaData() { sampleBufferRenderer.stopRequestingMediaData() }
    /// isim (AVKit): while the layer's content plays in Picture in Picture, it shows iOS's placeholder
    public var _isimPictureInPicture = false { didSet { setNeedsDisplay() } }
    open override func draw(in ctx: CGContext) {
        if _isimPictureInPicture { _AVPictureInPicturePlaceholder.draw(in: ctx, bounds: bounds); return }
        let r = sampleBufferRenderer
        guard r.image != 0, r.shown != nil, r.imageSize.0 > 0 else { return }
        let b = bounds
        let rect = AVMakeRect(aspectRatio: CGSize(width: r.imageSize.0, height: r.imageSize.1), gravity: videoGravity, in: b)
        isim_gfx_save()
        isim_gfx_clip_rounded(b.minX, b.minY, b.width, b.height, 0)
        isim_image_draw(r.image, rect.minX, rect.minY, rect.width, rect.height, nil, 1)
        isim_gfx_restore()
    }
}

/// what a video layer shows while its content plays in Picture in Picture
enum _AVPictureInPicturePlaceholder {
    static func draw(in ctx: CGContext, bounds b: CGRect) {
        ctx.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor); ctx.fill(b)
        UIGraphicsPushContext(ctx)
        let s = min(48, b.height * 0.3)
        UIImage(systemName: "pip")?.withTintColor(UIColor(white: 0.55, alpha: 1)).draw(in: CGRect(x: b.midX - s / 2, y: b.midY - s * 0.9, width: s, height: s))
        let text = "This video is playing in Picture in Picture." as NSString
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor(white: 0.55, alpha: 1), .paragraphStyle: style]
        text.draw(in: CGRect(x: b.minX + 16, y: b.midY + s * 0.25, width: b.width - 32, height: 40), withAttributes: attrs)
        UIGraphicsPopContext()
    }
}

// MARK: - audio

/// 48 kHz stereo audio starting at a time
struct _AVAudioSegment { var start: Double; var samples: [Float] }

@objc(AVSampleBufferAudioRenderer) open class AVSampleBufferAudioRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    let lock = NSLock()
    var segments: [_AVAudioSegment] = []
    var _status: AVQueuedSampleBufferRenderingStatus = .unknown
    var _error: Error?
    let requester = _AVMediaRequester()
    weak var synchronizer: AVSampleBufferRenderSynchronizer?
    var output: _IsimAudioOutput?
    var nextTime = -1.0
    var codec: OpaquePointer?, codecFormat: CMFormatDescription?
    var poll: DispatchSourceTimer?
    static let rate = _IsimAudioOutput.sampleRate

    open var volume: Float = 1
    open var isMuted = false
    open var audioOutputDeviceUniqueID: String?
    open var audioTimePitchAlgorithm: AVAudioTimePitchAlgorithm = .timeDomain
    open var status: AVQueuedSampleBufferRenderingStatus { lock.lock(); defer { lock.unlock() }; return _status }
    open var error: Error? { lock.lock(); defer { lock.unlock() }; return _error }
    open lazy var timebase: CMTimebase = CMTimebase(_isimProvider: { [weak self] in
        guard let s = self?.synchronizer else { return (0, 0) }
        return (s.timebase.time.seconds, s.timebase.rate)
    })
    public override init() {
        super.init()
        // asks for data as the buffered audio plays out
        let t = DispatchSource.makeTimerSource(queue: .global())
        t.schedule(deadline: .now() + 0.05, repeating: 0.05)
        t.setEventHandler { [weak self] in guard let self else { return }; self.requester.pump(self.isReadyForMoreMediaData) }
        t.resume()
        poll = t
    }
    deinit { poll?.cancel(); output?.stop(); if let c = codec { isim_acodec_close(c) } }

    var now: Double { synchronizer?.timebase.time.seconds ?? 0 }
    /// seconds of audio buffered past the synchronizer's time
    var buffered: Double {
        let t = now
        return segments.last.map { max(0, $0.start + Double($0.samples.count / 2) / Self.rate - t) } ?? 0
    }
    open var isReadyForMoreMediaData: Bool { lock.lock(); defer { lock.unlock() }; return _status != .failed && buffered < 1 }
    open var hasSufficientMediaDataForReliablePlaybackStart: Bool { lock.lock(); defer { lock.unlock() }; return buffered > 0.2 }

    open func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard let format = sampleBuffer._format, format.mediaType == kCMMediaType_Audio, let block = sampleBuffer._block else { return }
        let asbd = format._asbd
        let pts = sampleBuffer.presentationTimeStamp.isNumeric ? sampleBuffer.presentationTimeStamp.seconds : (segments.last.map { $0.start + Double($0.samples.count / 2) / Self.rate } ?? 0)
        var pcm: [Float] = [], channels = Int(max(1, asbd.mChannelsPerFrame)), rate = asbd.mSampleRate
        if asbd._isPCM {
            pcm = Self.floats(block._bytes, asbd)
        } else if asbd.mFormatID == kAudioFormatMPEG4AAC {
            lock.lock()
            if codec == nil || codecFormat != format {
                if let c = codec { isim_acodec_close(c) }
                codec = isim_acodec_open(0, "aac", asbd.mSampleRate, Int32(channels), 0)
                codecFormat = format
            }
            let c = codec
            lock.unlock()
            guard let c else { lock.lock(); _status = .failed; _error = AVError(.decoderNotFound); lock.unlock(); return }
            let config = Self.aacConfig(format._cookie ?? [], rate: asbd.mSampleRate, channels: channels)
            for i in 0 ..< max(1, sampleBuffer._numSamples) {
                guard let r = sampleBuffer._sampleRange(i) else { continue }
                var packet = Array(block._bytes[r])
                if !(packet.count > 1 && packet[0] == 0xFF && packet[1] & 0xF0 == 0xF0) { packet = Self.adts(packet.count, config) + packet }
                _ = packet.withUnsafeBufferPointer { isim_acodec_send_packet(c, $0.baseAddress, Int32($0.count)) }
                var out = [Float](repeating: 0, count: 8192 * 2)
                var ch: Int32 = 0, rt: Double = 0
                while true {
                    let n = out.withUnsafeMutableBufferPointer { isim_acodec_receive_pcm(c, $0.baseAddress!, 4096, &ch, &rt) }
                    if n <= 0 { break }
                    channels = Int(max(1, ch)); rate = rt > 0 ? rt : rate
                    pcm += out[0 ..< Int(n) * channels]
                }
            }
        } else {
            lock.lock(); _status = .failed; _error = AVError(.decoderNotFound); lock.unlock()
            return
        }
        let stereo = Self.stereo48k(pcm, channels: channels, rate: rate)
        lock.lock()
        _status = .rendering
        // a new segment replaces what it overlaps (an app re-enqueueing after a seek)
        let end = pts + Double(stereo.count / 2) / Self.rate
        segments.removeAll { $0.start >= pts - 0.0005 && $0.start < end }
        segments.append(_AVAudioSegment(start: pts, samples: stereo))
        segments.sort { $0.start < $1.start }
        lock.unlock()
    }

    /// interleaved floats from LPCM bytes (any of isim's integer and float layouts)
    static func floats(_ b: [UInt8], _ f: AudioStreamBasicDescription) -> [Float] {
        let bits = Int(f.mBitsPerChannel), ch = Int(max(1, f.mChannelsPerFrame))
        let bytes = max(1, bits / 8), frames = b.count / (bytes * ch)
        var out = [Float](repeating: 0, count: frames * ch)
        b.withUnsafeBytes { raw in
            for i in 0 ..< frames * ch {
                // non-interleaved buffers hold one channel after another
                let src = f._isNonInterleaved ? ((i % ch) * frames + i / ch) * bytes : i * bytes
                let p = raw.baseAddress! + src
                if f._isFloat { out[i] = bits == 64 ? Float(p.loadUnaligned(as: Double.self)) : p.loadUnaligned(as: Float.self) }
                else if bits == 16 { out[i] = Float(p.loadUnaligned(as: Int16.self)) / 32768 }
                else if bits == 32 { out[i] = Float(p.loadUnaligned(as: Int32.self)) / 2147483648 }
                else if bits == 24 { let v = Int32(p.load(as: UInt8.self)) | Int32(p.load(fromByteOffset: 1, as: UInt8.self)) << 8 | Int32(Int8(bitPattern: p.load(fromByteOffset: 2, as: UInt8.self))) << 16; out[i] = Float(v) / 8388608 }
                else { out[i] = (Float(p.load(as: UInt8.self)) - 128) / 128 }
            }
        }
        return out
    }
    /// interleaved stereo at 48 kHz (mono on both sides, more channels: the first two), linear interpolation
    static func stereo48k(_ pcm: [Float], channels ch: Int, rate: Double) -> [Float] {
        let frames = pcm.count / max(1, ch)
        guard frames > 0, rate > 0 else { return [] }
        let n = Int((Double(frames) * Self.rate / rate).rounded())
        var out = [Float](repeating: 0, count: n * 2)
        for i in 0 ..< n {
            let x = Double(i) * rate / Self.rate, j = Int(x), t = Float(x - Double(j))
            let a = min(j, frames - 1), b = min(j + 1, frames - 1)
            for c in 0 ..< 2 {
                let k = min(c, ch - 1)
                out[2 * i + c] = pcm[a * ch + k] * (1 - t) + pcm[b * ch + k] * t
            }
        }
        return out
    }
    static func aacConfig(_ cookie: [UInt8], rate: Double, channels: Int) -> (object: Int, sfi: Int, channels: Int) {
        var bytes = cookie
        if cookie.first == 3 {                                  // an esds: its DecoderSpecificInfo
            var i = 0
            while i < cookie.count {
                let tag = cookie[i]; i += 1
                var len = 0
                while i < cookie.count { let b = cookie[i]; i += 1; len = len << 7 | Int(b & 0x7F); if b & 0x80 == 0 { break } }
                if tag == 5 { bytes = Array(cookie[i ..< min(cookie.count, i + len)]); break }
                if tag == 3 { i += 3 } else if tag == 4 { i += 13 } else { i += len }
            }
        }
        if bytes.count >= 2 { return (Int(bytes[0] >> 3), Int((bytes[0] & 7) << 1 | bytes[1] >> 7), Int((bytes[1] >> 3) & 0xF)) }
        let rates: [Double] = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
        return (2, rates.firstIndex(of: rate) ?? 4, channels)
    }
    static func adts(_ payload: Int, _ c: (object: Int, sfi: Int, channels: Int)) -> [UInt8] {
        let len = payload + 7, prof = max(0, c.object - 1) & 3
        return [0xFF, 0xF1, UInt8(prof << 6 | (c.sfi & 0xF) << 2 | (c.channels >> 2) & 1), UInt8((c.channels & 3) << 6 | (len >> 11) & 3),
                UInt8((len >> 3) & 0xFF), UInt8((len & 7) << 5 | 0x1F), 0xFC]
    }

    open func flush() {
        lock.lock(); segments.removeAll(); nextTime = -1
        if let c = codec { isim_acodec_close(c); codec = nil }
        if _status == .failed { _status = .unknown; _error = nil }
        lock.unlock()
    }
    /// drops the audio from `time` on (completion: true when the flush happened at that time)
    open func flush(fromSourceTime time: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
        lock.lock()
        let t = time.seconds
        segments = segments.compactMap { s in
            if s.start >= t { return nil }
            let keep = Int((t - s.start) * Self.rate) * 2
            return keep >= s.samples.count ? s : _AVAudioSegment(start: s.start, samples: Array(s.samples[0 ..< keep]))
        }
        let ok = now <= t
        lock.unlock()
        DispatchQueue.global().async { completionHandler(ok) }
    }
    open func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {
        requester.set(queue, block)
        requester.pump(isReadyForMoreMediaData)
    }
    open func stopRequestingMediaData() { requester.set(nil, nil) }

    /// joins a synchronizer: its audio plays from then on
    func _attach(_ s: AVSampleBufferRenderSynchronizer?) {
        lock.lock(); synchronizer = s; nextTime = -1; lock.unlock()
        output?.stop(); output = nil
        guard s != nil else { return }
        let o = _IsimAudioOutput { [weak self] frames, _ in self?._render(frames) ?? [[Float](repeating: 0, count: frames)] }
        output = o
        o.start()
    }
    /// the output's next `frames` at 48 kHz: what the segments hold at the synchronizer's time
    func _render(_ frames: Int) -> [[Float]] {
        var l = [Float](repeating: 0, count: frames), r = l
        lock.lock(); defer { lock.unlock() }
        guard let s = synchronizer else { return [l, r] }
        let rate = s.timebase.rate
        let ahead = now + (output?.lead ?? 0.03)
        if nextTime < 0 || abs(nextTime - ahead) > 0.06 { nextTime = ahead }      // started, seeked or drifted
        defer { nextTime += Double(frames) / Self.rate * rate }
        guard rate != 0, !isMuted, volume > 0 else { return [l, r] }
        let gain = volume
        for i in 0 ..< frames {
            let t = nextTime + Double(i) / Self.rate * rate
            guard let seg = segments.last(where: { $0.start <= t }) else { continue }
            let k = Int((t - seg.start) * Self.rate)
            guard k >= 0, 2 * k + 1 < seg.samples.count else { continue }
            l[i] = seg.samples[2 * k] * gain; r[i] = seg.samples[2 * k + 1] * gain
        }
        // what has played can go (keep a second for a backwards seek)
        segments.removeAll { $0.start + Double($0.samples.count / 2) / Self.rate < nextTime - 1 }
        return [l, r]
    }
}

// MARK: - synchronizer

@objc(AVSampleBufferRenderSynchronizer) open class AVSampleBufferRenderSynchronizer: NSObject, @unchecked Sendable {
    public let timebase = CMTimebase(sourceClock: .hostTimeClock)
    let lock = NSLock()
    var _renderers: [AVQueuedSampleBufferRendering] = []
    var observers: [_AVSyncObserver] = []
    open var delaysRateChangeUntilHasSufficientMediaData = true
    public override init() { super.init() }

    open var rate: Float {
        get { Float(timebase.rate) }
        set { setRate(newValue, time: .invalid) }
    }
    open var renderers: [AVQueuedSampleBufferRendering] { lock.lock(); defer { lock.unlock() }; return _renderers }
    open func currentTime() -> CMTime { timebase.time }
    /// time .invalid keeps the current time
    open func setRate(_ rate: Float, time: CMTime) {
        if time.isValid { timebase.setTime(time) }
        let changed = Float(timebase.rate) != rate
        timebase.setRate(Double(rate))
        if changed { DispatchQueue.main.async { NotificationCenter.default.post(name: .AVSampleBufferRenderSynchronizerRateDidChange, object: self) } }
        _wakeObservers()
    }
    open func setRate(_ rate: Float, time: CMTime, atHostTime hostTime: CMTime) {
        let delay = hostTime.isValid ? hostTime.seconds - CMClock.hostTimeClock.time.seconds : 0
        if delay > 0 {
            if time.isValid { timebase.setTime(time) }
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in setRate(rate, time: .invalid) }
        } else { setRate(rate, time: time) }
    }
    open func addRenderer(_ renderer: AVQueuedSampleBufferRendering) {
        lock.lock(); _renderers.append(renderer); lock.unlock()
        if let a = renderer as? AVSampleBufferAudioRenderer { a._attach(self) }
        if let v = (renderer as? AVSampleBufferDisplayLayer)?.sampleBufferRenderer ?? renderer as? AVSampleBufferVideoRenderer {
            v.lock.lock(); v.control = timebase; v.lock.unlock()
        }
    }
    /// stops the renderer at `time` (now when invalid)
    open func removeRenderer(_ renderer: AVQueuedSampleBufferRendering, at time: CMTime, completionHandler: (@Sendable (Bool) -> Void)? = nil) {
        let delay = time.isValid && timebase.rate > 0 ? max(0, (time.seconds - timebase.time.seconds) / timebase.rate) : 0
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            lock.lock(); _renderers.removeAll { $0 === renderer }; lock.unlock()
            if let a = renderer as? AVSampleBufferAudioRenderer { a._attach(nil) }
            if let v = (renderer as? AVSampleBufferDisplayLayer)?.sampleBufferRenderer ?? renderer as? AVSampleBufferVideoRenderer {
                v.lock.lock(); if v.control === timebase { v.control = nil }; v.lock.unlock()
            }
            completionHandler?(true)
        }
    }
    open func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping @Sendable (CMTime) -> Void) -> Any {
        let o = _AVSyncObserver(self, queue: queue ?? .main, periodic: max(0.01, interval.seconds), boundaries: [], block: block)
        lock.lock(); observers.append(o); lock.unlock()
        return o
    }
    open func addBoundaryTimeObserver(forTimes times: [NSValue], queue: DispatchQueue?, using block: @escaping @Sendable () -> Void) -> Any {
        let o = _AVSyncObserver(self, queue: queue ?? .main, periodic: 0, boundaries: times.map { $0.timeValue.seconds }.sorted()) { _ in block() }
        lock.lock(); observers.append(o); lock.unlock()
        return o
    }
    open func removeTimeObserver(_ observer: Any) {
        guard let o = observer as? _AVSyncObserver else { return }
        o.cancel()
        lock.lock(); observers.removeAll { $0 === o }; lock.unlock()
    }
    func _wakeObservers() { lock.lock(); let os = observers; lock.unlock(); for o in os { o.wake() } }
}

/// a time observer: periodic ones fire every interval of synchronizer time while it runs (and when the rate changes),
/// boundary ones when the time passes one of theirs
final class _AVSyncObserver: NSObject, @unchecked Sendable {
    weak var sync: AVSampleBufferRenderSynchronizer?
    let queue: DispatchQueue, periodic: Double, boundaries: [Double], block: @Sendable (CMTime) -> Void
    var timer: DispatchSourceTimer?
    var last: Double
    init(_ s: AVSampleBufferRenderSynchronizer, queue: DispatchQueue, periodic: Double, boundaries: [Double], block: @escaping @Sendable (CMTime) -> Void) {
        sync = s; self.queue = queue; self.periodic = periodic; self.boundaries = boundaries; self.block = block
        last = s.timebase.time.seconds
        super.init()
        let t = DispatchSource.makeTimerSource(queue: .global())
        t.schedule(deadline: .now() + 0.01, repeating: 0.01)
        t.setEventHandler { [weak self] in self?.check() }
        t.resume()
        timer = t
        if periodic > 0 { fire(last) }
    }
    func cancel() { timer?.cancel(); timer = nil }
    func wake() { if periodic > 0, let s = sync { let t = s.timebase.time.seconds; last = t; fire(t) } }
    func fire(_ t: Double) { let b = block; queue.async { b(CMTime(seconds: t, preferredTimescale: 600)) } }
    func check() {
        guard let s = sync else { cancel(); return }
        let t = s.timebase.time.seconds
        if periodic > 0 {
            if s.timebase.rate != 0, abs(t - last) >= periodic { last = t; fire(t) }
        } else {
            let lo = min(last, t), hi = max(last, t)
            if boundaries.contains(where: { $0 > lo && $0 <= hi }) { fire(t) }
            last = t
        }
    }
}
