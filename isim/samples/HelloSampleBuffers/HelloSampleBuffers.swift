// Sample: rendering sample buffers an app produces itself, as streaming and video-call apps do.
// - An H.264 movie (written here with AVAssetWriter: one second red, one green, one blue) is read back compressed
//   with AVAssetReader and fed to an AVSampleBufferDisplayLayer through requestMediaDataWhenReady.
// - A 440 Hz tone goes to an AVSampleBufferAudioRenderer as LPCM sample buffers.
// - An AVSampleBufferRenderSynchronizer drives both, with periodic and boundary time observers; pausing it holds
//   the frame.
// - A second layer shows uncompressed CVPixelBuffers as soon as they are enqueued (DisplayImmediately).
// - The first layer can float in Picture in Picture (ContentSource(sampleBufferDisplayLayer:playbackDelegate:)).
// - VideoToolbox: three frames encoded with a VTCompressionSession and decoded back with a VTDecompressionSession.
// Every step logs a line the test reads.
import UIKit
import AVFoundation
import AVKit
import VideoToolbox

func log(_ s: String) { NSLog("HelloSampleBuffers: %@", s) }

final class LayerView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
}

/// a solid-colour BGRA pixel buffer
func pixelBuffer(_ c: (UInt8, UInt8, UInt8), _ w: Int = 160, _ h: Int = 120) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &pb)
    let b = pb!
    CVPixelBufferLockBaseAddress(b, [])
    let base = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(b)
    for y in 0 ..< h { for x in 0 ..< w { let p = base + y * bpr + x * 4; p[0] = c.2; p[1] = c.1; p[2] = c.0; p[3] = 255 } }
    CVPixelBufferUnlockBaseAddress(b, [])
    return b
}
/// the colour at a pixel buffer's centre, as a name
func colourName(_ b: CVPixelBuffer?) -> String {
    guard let b else { return "none" }
    CVPixelBufferLockBaseAddress(b, .readOnly); defer { CVPixelBufferUnlockBaseAddress(b, .readOnly) }
    let w = CVPixelBufferGetWidth(b), h = CVPixelBufferGetHeight(b), bpr = CVPixelBufferGetBytesPerRow(b)
    let p = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self) + (h / 2) * bpr + (w / 2) * 4
    let (r, g, bl) = (Int(p[2]), Int(p[1]), Int(p[0]))
    if r > 180 && g < 80 && bl < 80 { return "red" }
    if g > 180 && r < 80 && bl < 80 { return "green" }
    if bl > 180 && r < 80 && g < 80 { return "blue" }
    return "\(r),\(g),\(bl)"
}

final class Player: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate, @unchecked Sendable {
    let video: AVSampleBufferDisplayLayer
    let audio = AVSampleBufferAudioRenderer()
    let sync = AVSampleBufferRenderSynchronizer()
    let feed = DispatchQueue(label: "feed")
    var reader: AVAssetReader?, output: AVAssetReaderTrackOutput?
    var audioTime = 0.0
    var observers: [Any] = []
    var videoDone = false
    init(_ layer: AVSampleBufferDisplayLayer) { video = layer; super.init() }

    func writeMovie() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rgb.mp4")
        try? FileManager.default.removeItem(at: url)
        let w = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 120])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        w.add(input)
        w.startWriting(); w.startSession(atSourceTime: .zero)
        let colours: [(UInt8, UInt8, UInt8)] = [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
        for i in 0 ..< 30 { adaptor.append(pixelBuffer(colours[i / 10]), withPresentationTime: CMTime(value: Int64(i), timescale: 10)) }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        w.finishWriting { done.signal() }
        done.wait()
        return url
    }

    func start() throws {
        let asset = AVURLAsset(url: try writeMovie())
        let r = try AVAssetReader(asset: asset)
        let o = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video)[0], outputSettings: nil)   // compressed samples
        r.add(o); r.startReading()
        reader = r; output = o
        sync.addRenderer(video)
        sync.addRenderer(audio)
        log("renderers \(sync.renderers.count) video timebase follows \(video.timebase.rate == 0)")

        // the first second of video and audio before the clock starts
        var first = 0
        while video.isReadyForMoreMediaData, first < 4, let sb = o.copyNextSampleBuffer() {
            if first == 0 { log("compressed \(CMFormatDescriptionGetMediaSubType(CMSampleBufferGetFormatDescription(sb)!) == kCMVideoCodecType_H264) image \(CMSampleBufferGetImageBuffer(sb) != nil)") }
            video.enqueue(sb); first += 1
        }
        enqueueTone(seconds: 0.5)
        log("status \(video.status == .rendering ? "rendering" : "\(video.status.rawValue)") audio \(audio.status == .rendering ? "rendering" : "\(audio.status.rawValue)")")

        video.requestMediaDataWhenReady(on: feed) { [self] in
            while video.isReadyForMoreMediaData {
                guard let sb = output?.copyNextSampleBuffer() else {
                    video.stopRequestingMediaData()
                    if !videoDone { videoDone = true; log("video all enqueued") }
                    return
                }
                video.enqueue(sb)
            }
        }
        audio.requestMediaDataWhenReady(on: feed) { [self] in
            while audio.isReadyForMoreMediaData && audioTime < 3 { enqueueTone(seconds: 0.1) }
            if audioTime >= 3 { audio.stopRequestingMediaData() }
        }
        let periodic = sync.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 2), queue: .main) { [self] t in
            if t.seconds > 0.2 { log(String(format: "periodic %.1f shows %@", t.seconds, colourName(video.sampleBufferRenderer.copyDisplayedPixelBuffer()))) }
        }
        let boundary = sync.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTime(value: 3, timescale: 2))], queue: .main) { [self] in
            log(String(format: "boundary at %.1f", sync.currentTime().seconds))
        }
        observers = [periodic, boundary]
        sync.setRate(1, time: .zero)
        log("rate \(sync.rate)")
    }

    /// LPCM: a 440 Hz tone, mono float at 44.1 kHz
    func enqueueTone(seconds: Double) {
        let rate = 44100.0, frames = Int(seconds * rate)
        var asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagsNativeFloatPacked,
                                               mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var format: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
        let start = Int(audioTime * rate)
        var samples = (0 ..< frames).map { Float(0.5 * sin(2 * Double.pi * 440 * Double(start + $0) / rate)) }
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: frames * 4, blockAllocator: nil, customBlockSource: nil,
                                           offsetToData: 0, dataLength: frames * 4, flags: 0, blockBufferOut: &block)
        samples.withUnsafeMutableBytes { _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: frames * 4) }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(rate)), presentationTimeStamp: CMTime(seconds: audioTime, preferredTimescale: Int32(rate)),
                                        decodeTimeStamp: .invalid)
        var size = 4
        var sb: CMSampleBuffer?
        CMSampleBufferCreate(allocator: nil, dataBuffer: block, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: format,
                             sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sb)
        if let sb { audio.enqueue(sb) }
        audioTime += seconds
    }

    // MARK: Picture in Picture
    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {
        sync.rate = playing ? 1 : 0
        log("pip setPlaying \(playing)")
    }
    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: CMTime(value: 3, timescale: 1))
    }
    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { sync.rate == 0 }
    func pictureInPictureController(_ c: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        log("pip render size \(newRenderSize.width > 0 && newRenderSize.height > 0)")
    }
    func pictureInPictureController(_ c: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion: @escaping () -> Void) {
        log("pip skip \(Int(skipInterval.seconds))"); completion()
    }
}

/// VideoToolbox: red, green and blue encoded to H.264 and decoded back
func videoToolboxRoundTrip() {
    var encoder: VTCompressionSession?
    var samples: [CMSampleBuffer] = []
    VTCompressionSessionCreate(allocator: nil, width: 64, height: 48, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil,
                               compressedDataAllocator: nil, outputCallback: nil, refcon: nil, compressionSessionOut: &encoder)
    guard let e = encoder else { log("videotoolbox: no encoder"); return }
    let colours: [(UInt8, UInt8, UInt8)] = [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
    for (i, c) in colours.enumerated() {
        VTCompressionSessionEncodeFrame(e, imageBuffer: pixelBuffer(c, 64, 48), presentationTimeStamp: CMTime(value: Int64(i), timescale: 10),
                                        duration: CMTime(value: 1, timescale: 10), frameProperties: nil, infoFlagsOut: nil) { status, _, sb in
            if status == noErr, let sb { samples.append(sb) }
        }
    }
    VTCompressionSessionCompleteFrames(e, untilPresentationTimeStamp: .invalid)
    VTCompressionSessionInvalidate(e)
    guard let format = samples.first.flatMap({ CMSampleBufferGetFormatDescription($0) }) else { log("videotoolbox: nothing encoded"); return }
    var decoder: VTDecompressionSession?
    VTDecompressionSessionCreate(allocator: nil, formatDescription: format, decoderSpecification: nil,
                                 imageBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] as CFDictionary,
                                 outputCallback: nil, decompressionSessionOut: &decoder)
    var names: [String] = []
    for sb in samples {
        VTDecompressionSessionDecodeFrame(decoder!, sampleBuffer: sb, flags: [], infoFlagsOut: nil) { status, _, image, _, _ in
            names.append(status == noErr ? colourName(image) : "error \(status)")
        }
    }
    VTDecompressionSessionInvalidate(decoder!)
    log("videotoolbox encoded \(samples.count) decoded \(names.joined(separator: " "))")
}

final class ViewController: UIViewController, AVPictureInPictureControllerDelegate {
    let top = LayerView(), bottom = LayerView()
    var player: Player!
    var pip: AVPictureInPictureController?
    let status = UILabel()
    var colour = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width - 40
        top.frame = CGRect(x: 20, y: 100, width: w, height: w * 0.75)
        top.accessibilityIdentifier = "video"
        top.displayLayer.videoGravity = .resizeAspect
        bottom.frame = CGRect(x: 20, y: top.frame.maxY + 20, width: w / 2, height: w * 0.375)
        bottom.accessibilityIdentifier = "frames"
        status.frame = CGRect(x: 20, y: 60, width: w, height: 30)
        status.accessibilityIdentifier = "status"
        status.text = "Sample buffers"
        let pause = UIButton(type: .system, primaryAction: UIAction(title: "Pause") { [unowned self] _ in
            player.sync.rate = player.sync.rate == 0 ? 1 : 0
            log(String(format: "rate %.0f at %.1f", player.sync.rate, player.sync.currentTime().seconds))
        })
        pause.accessibilityIdentifier = "pause"
        pause.frame = CGRect(x: 20 + w / 2 + 20, y: bottom.frame.minY, width: w / 2 - 20, height: 44)
        let pipButton = UIButton(type: .system, primaryAction: UIAction(title: "Picture in Picture") { [unowned self] _ in startPiP() })
        pipButton.accessibilityIdentifier = "pip"
        pipButton.frame = CGRect(x: 20 + w / 2 + 20, y: bottom.frame.minY + 50, width: w / 2 - 20, height: 44)
        [status, top, bottom, pause, pipButton].forEach(view.addSubview)

        videoToolboxRoundTrip()
        player = Player(top.displayLayer)
        do { try player.start() } catch { log("start failed \(error)") }
        // uncompressed frames, shown as soon as they are enqueued
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let c: [(UInt8, UInt8, UInt8)] = [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
            var sb: CMSampleBuffer?, format: CMVideoFormatDescription?
            let px = pixelBuffer(c[colour % 3], 80, 60)
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: px, formatDescriptionOut: &format)
            var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMTime(value: Int64(colour), timescale: 1), decodeTimeStamp: .invalid)
            CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: px, formatDescription: format!, sampleTiming: &timing, sampleBufferOut: &sb)
            if let sb, let a = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) as? [NSMutableDictionary], let d = a.first {
                d[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true
            }
            if let sb { bottom.displayLayer.enqueue(sb) }
            colour += 1
            if colour == 3 { log("uncompressed enqueued 3 status \(bottom.displayLayer.status == .rendering ? "rendering" : "?")") }
        }
    }

    func startPiP() {
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: top.displayLayer, playbackDelegate: player)
        let c = AVPictureInPictureController(contentSource: source)
        c.delegate = self
        pip = c
        log("pip possible \(c.isPictureInPicturePossible)")
        c.startPictureInPicture()
    }
    func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) { log("pip started active \(c.isPictureInPictureActive)") }
    func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) { log("pip stopped") }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
