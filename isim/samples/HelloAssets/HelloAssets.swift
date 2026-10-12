// Sample: AVAssetWriter / AVAssetReader in depth — frames written at uneven times keep them, metadata items, a
// pass-through copy of compressed samples (reader and writer with nil settings, H.264 parameter sets from the format
// description), compositions read through a track output, an audio mix with a volume ramp across two tracks, a video
// composition output, random access to time ranges, and CoreMedia timebases. Everything runs once at launch; the
// results are logged.
import UIKit
import AVFoundation

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = AssetsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloAssets: %@", s) }
func f2(_ v: Double) -> String { String(format: "%.2f", v) }
let tmp = FileManager.default.temporaryDirectory

final class AssetsViewController: UIViewController {
    let label = UILabel()
    var timebase: CMTimebase?
    var timer: Timer?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 20, y: 80, width: 360, height: 40); label.text = "Assets"; label.accessibilityIdentifier = "status"
        view.addSubview(label)
        DispatchQueue.global().async {
            do { try self.run() } catch { log("error \(error)") }
            DispatchQueue.main.async { self.timebases() }
        }
    }

    // MARK: writing at uneven times, with metadata
    func frame(_ i: Int, _ w: Int, _ h: Int) -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &pb)
        let b = pb!
        CVPixelBufferLockBaseAddress(b, [])
        let base = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(b)
        let colors: [(UInt8, UInt8, UInt8)] = [(0, 0, 255), (0, 255, 0), (255, 0, 0)]       // BGR: red, green, blue
        let c = colors[i % 3]
        for y in 0..<h { for x in 0..<w { let p = base + y * bpr + x * 4; p[0] = c.0; p[1] = c.1; p[2] = c.2; p[3] = 255 } }
        CVPixelBufferUnlockBaseAddress(b, [])
        return b
    }
    func writeUneven(_ url: URL, times: [Double]) throws {
        try? FileManager.default.removeItem(at: url)
        let w = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 120])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        w.add(input)
        let title = AVMutableMetadataItem(); title.identifier = .commonIdentifierTitle; title.value = "Uneven frames" as NSString
        let loc = AVMutableMetadataItem(); loc.identifier = .quickTimeMetadataLocationISO6709; loc.value = "+48.8584+002.2945/" as NSString
        w.metadata = [title, loc]
        w.startWriting(); w.startSession(atSourceTime: .zero)
        for (i, t) in times.enumerated() { adaptor.append(frame(i, 160, 120), withPresentationTime: CMTime(seconds: t, preferredTimescale: 600)) }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        w.finishWriting { done.signal() }
        done.wait()
        log("uneven written status=\(w.status == .completed ? "completed" : "\(w.status.rawValue) \(w.error.map { "\($0)" } ?? "")")")
    }
    /// presentation times of a file's video samples (pass-through reading)
    func sampleTimes(_ url: URL) throws -> ([Double], CMFormatDescription?) {
        let asset = AVURLAsset(url: url)
        let r = try AVAssetReader(asset: asset)
        let o = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video)[0], outputSettings: nil)
        r.add(o); r.startReading()
        var times: [Double] = [], format: CMFormatDescription?
        while let sb = o.copyNextSampleBuffer() { times.append(sb.presentationTimeStamp.seconds); format = sb.formatDescription }
        return (times.sorted(), format)
    }

    func run() throws {
        let uneven = tmp.appendingPathComponent("uneven.mov")
        let times = [0, 0.1, 0.3, 0.35, 0.8, 1.0]
        try writeUneven(uneven, times: times)
        let (got, format) = try sampleTimes(uneven)
        log("uneven times \(got.map(f2).joined(separator: ","))")
        let a = AVURLAsset(url: uneven)
        let title = AVMetadataItem.metadataItems(from: a.commonMetadata, filteredByIdentifier: .commonIdentifierTitle).first?.stringValue
            ?? a.commonMetadata.first { $0.commonKey == .commonKeyTitle }?.stringValue
        let location = a.metadata.first { $0.identifier == .quickTimeMetadataLocationISO6709 }?.stringValue
        log("metadata title=\(title ?? "none") location=\(location ?? "none")")

        // pass-through copy: compressed samples out of a reader into a writer
        if let f = format {
            var count = 0, nal: Int32 = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(f, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil,
                                                               parameterSetCountOut: &count, nalUnitHeaderLengthOut: &nal)
            let d = CMVideoFormatDescriptionGetDimensions(f)
            log("format codec=\(CMFormatDescriptionGetMediaSubType(f) == kCMVideoCodecType_H264 ? "avc1" : "other") \(d.width)x\(d.height) parameterSets=\(count) nal=\(nal)")
        }
        let copy = tmp.appendingPathComponent("copy.mp4")
        try? FileManager.default.removeItem(at: copy)
        let src = AVURLAsset(url: uneven)
        let reader = try AVAssetReader(asset: src)
        let out = AVAssetReaderTrackOutput(track: src.tracks(withMediaType: .video)[0], outputSettings: nil)
        reader.add(out)
        let writer = try AVAssetWriter(outputURL: copy, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
        writer.add(input)
        reader.startReading(); writer.startWriting(); writer.startSession(atSourceTime: .zero)
        var copied = 0, syncs = 0
        while let sb = out.copyNextSampleBuffer() {
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as NSArray?
            if (attachments?.firstObject as? NSDictionary)?[kCMSampleAttachmentKey_NotSync as String] == nil { syncs += 1 }
            if input.append(sb) { copied += 1 }
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        let (copyTimes, _) = try sampleTimes(copy)
        log("passthrough copied=\(copied) syncs=\(syncs) status=\(writer.status == .completed ? "completed" : "\(writer.error.map { "\($0)" } ?? "?")") times=\(copyTimes.map(f2).joined(separator: ","))")
        // the copy decodes: the colour of the frame shown at 0.32 s (the fourth frame, red)
        let dr = try AVAssetReader(asset: AVURLAsset(url: copy))
        let dout = AVAssetReaderTrackOutput(track: AVURLAsset(url: copy).tracks(withMediaType: .video)[0],
                                            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        dr.add(dout); dr.startReading()
        var decoded = 0
        while dout.copyNextSampleBuffer() != nil { decoded += 1 }
        log("copy decodes frames=\(decoded) duration=\(f2(AVURLAsset(url: copy).duration.seconds))")

        try compositions()
        try randomAccess(uneven)
        log("done")
    }

    // MARK: compositions, audio mix, video composition
    func tone(_ url: URL, _ freq: Double, _ seconds: Double) throws {
        try? FileManager.default.removeItem(at: url)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let f = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
        let n = AVAudioFrameCount(44100 * seconds)
        let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n)!
        b.frameLength = n
        for i in 0..<Int(n) { b.floatChannelData![0][i] = Float(0.4 * sin(2 * .pi * freq * Double(i) / 44100)) }
        try f.write(from: b)
    }
    func rms(_ s: [Float]) -> Double { s.isEmpty ? 0 : sqrt(s.reduce(0) { $0 + Double($1 * $1) } / Double(s.count)) }
    func compositions() throws {
        let t1 = tmp.appendingPathComponent("a.wav"), t2 = tmp.appendingPathComponent("b.wav")
        try tone(t1, 440, 2); try tone(t2, 660, 2)
        let comp = AVMutableComposition()
        let a1 = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let a2 = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let s1 = AVURLAsset(url: t1), s2 = AVURLAsset(url: t2)
        try a1.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)), of: s1.tracks(withMediaType: .audio)[0], at: .zero)
        try a2.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)), of: s2.tracks(withMediaType: .audio)[0], at: .zero)
        let mix = AVMutableAudioMix()
        let p1 = AVMutableAudioMixInputParameters(track: a1); p1.setVolume(0, at: .zero)                 // the 440 Hz track muted
        let p2 = AVMutableAudioMixInputParameters(track: a2)                                              // 660 Hz fades in over 2 s
        p2.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)))
        mix.inputParameters = [p1, p2]
        var sv: Float = 0, ev: Float = 0, tr = CMTimeRange()
        let found = p2.getVolumeRamp(for: CMTime(seconds: 1, preferredTimescale: 600), startVolume: &sv, endVolume: &ev, timeRange: &tr)
        log("ramp found=\(found) \(sv)->\(ev) over \(f2(tr.duration.seconds))")
        let r = try AVAssetReader(asset: comp)
        let o = AVAssetReaderAudioMixOutput(audioTracks: comp.tracks(withMediaType: .audio),
                                            audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32,
                                                            AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1])
        o.audioMix = mix
        r.add(o); r.startReading()
        var pcm: [Float] = []
        while let sb = o.copyNextSampleBuffer(), let block = sb.dataBuffer {
            block._bytes.withUnsafeBytes { pcm += $0.bindMemory(to: Float.self) }
        }
        let q = pcm.count / 4
        log("audio mix frames=\(pcm.count) start=\(f2(rms(Array(pcm[0..<min(q, pcm.count)])))) end=\(f2(rms(Array(pcm[(pcm.count - q)...])))) status=\(r.status == .completed ? "completed" : "\(r.status.rawValue)")")

        // a video composition output: rendered at its size and frame rate
        let uneven = AVURLAsset(url: tmp.appendingPathComponent("uneven.mov"))
        let vc = AVMutableVideoComposition(propertiesOf: uneven)
        vc.renderSize = CGSize(width: 80, height: 60); vc.frameDuration = CMTime(value: 1, timescale: 10)
        let vr = try AVAssetReader(asset: uneven)
        let vo = AVAssetReaderVideoCompositionOutput(videoTracks: uneven.tracks(withMediaType: .video), videoSettings: nil)
        vo.videoComposition = vc
        vr.add(vo); vr.startReading()
        var frames = 0, size = CGSize.zero
        while let sb = vo.copyNextSampleBuffer() { frames += 1; if let pb = sb.imageBuffer { size = CGSize(width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb)) } }
        log("video composition frames=\(frames) size=\(Int(size.width))x\(Int(size.height))")

        // a composition read through a track output: two copies of the clip back to back
        let vcomp = AVMutableComposition()
        let vt = vcomp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let full = CMTimeRange(start: .zero, duration: uneven.duration)
        try vt.insertTimeRange(full, of: uneven.tracks(withMediaType: .video)[0], at: .zero)
        try vt.insertTimeRange(full, of: uneven.tracks(withMediaType: .video)[0], at: uneven.duration)
        let cr = try AVAssetReader(asset: vcomp)
        let co = AVAssetReaderTrackOutput(track: vcomp.tracks(withMediaType: .video)[0], outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        cr.add(co); cr.startReading()
        var last = 0.0, cframes = 0
        while let sb = co.copyNextSampleBuffer() { cframes += 1; last = sb.presentationTimeStamp.seconds }
        log("composition read frames=\(cframes) last=\(f2(last)) duration=\(f2(vcomp.duration.seconds))")
    }

    // MARK: random access
    func randomAccess(_ url: URL) throws {
        let asset = AVURLAsset(url: url)
        let r = try AVAssetReader(asset: asset)
        let o = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video)[0], outputSettings: nil)
        o.supportsRandomAccess = true
        r.add(o)
        r.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 0.2, preferredTimescale: 600))
        r.startReading()
        var first: [Double] = []
        while let sb = o.copyNextSampleBuffer() { first.append(sb.presentationTimeStamp.seconds) }
        o.reset(forReadingTimeRanges: [NSValue(timeRange: CMTimeRange(start: CMTime(seconds: 0.8, preferredTimescale: 600), duration: CMTime(seconds: 0.5, preferredTimescale: 600)))])
        var second: [Double] = []
        while let sb = o.copyNextSampleBuffer() { second.append(sb.presentationTimeStamp.seconds) }
        o.markConfigurationAsFinal()
        log("random access first=\(first.map(f2).joined(separator: ",")) second=\(second.map(f2).joined(separator: ",")) status=\(r.status == .completed ? "completed" : "\(r.status.rawValue)")")
    }

    // MARK: timebases
    func timebases() {
        let tb = CMTimebase(sourceClock: .hostTimeClock)
        tb.setTime(.zero)
        tb.setRate(2)
        let started = CMClockGetTime(CMClockGetHostTimeClock()).seconds
        let t = Timer(timeInterval: 1000, repeats: false) { _ in
            let host = CMClockGetTime(CMClockGetHostTimeClock()).seconds - started
            log("timebase timer at \(f2(CMTimebaseGetTime(tb).seconds)) after \(f2(host)) s rate=\(CMTimebaseGetRate(tb))")
            let child = CMTimebase(sourceTimebase: tb); child.setTime(.zero); child.setRate(0.5)
            log("child effective rate=\(child.effectiveRate) sync=\(f2(CMSyncGetRelativeRate(child, relativeTo: CMClock.hostTimeClock)))")
            log("timebases done")
        }
        tb.addTimer(t, runloop: .main)
        tb.setTimerNextFireTime(t, fireTime: CMTime(seconds: 0.6, preferredTimescale: 600))
        timebase = tb; timer = t
    }
}
