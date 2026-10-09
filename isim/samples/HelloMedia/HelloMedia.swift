// Sample: media editing and low-level audio on isim — AVMutableComposition (insert, remove, scale), AVAssetExportSession
// (completion handler and iOS 18 export(to:as:)), AVAssetReader (BGRA frames, 16-bit PCM), AVAssetWriter with a pixel
// buffer adaptor and an audio input, AVAudioPlayer rate/pan/metering, AVAudioSession interruptions and route changes
// (driven by the `audio` script command), and AudioToolbox: ExtAudioFile, AudioFile, AudioConverter, AudioQueue output
// and input. Media (made by the build with ffmpeg, buildlib/apps.py): red.mp4 (1 s red, 440 Hz), blue.mp4 (1 s blue, 880 Hz), tone.wav
// (1 s 1 kHz stereo, 44.1 kHz 16-bit).
import UIKit
import AVFoundation
import AudioToolbox

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MediaViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloMedia: %@", s) }
func f2(_ x: Double) -> String { String(format: "%.2f", x) }
func sec(_ v: Int64, _ s: Int32) -> CMTime { CMTime(value: v, timescale: s) }
let res = Bundle.main.bundleURL
let tmp = FileManager.default.temporaryDirectory
func fresh(_ name: String) -> URL { let u = tmp.appendingPathComponent(name); try? FileManager.default.removeItem(at: u); return u }
/// "red" / "green" / "blue" / "other" for a BGRA pixel
func colorName(b: UInt8, g: UInt8, r: UInt8) -> String {
    if r > 200 && g < 60 && b < 60 { return "red" }
    if g > 200 && r < 60 && b < 60 { return "green" }
    if b > 200 && r < 60 && g < 60 { return "blue" }
    return "other(\(r),\(g),\(b))"
}

final class MediaViewController: UIViewController {
    var thumbs: [UIImageView] = []
    let status = UILabel()
    var player: AVAudioPlayer?
    var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Media"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41); view.addSubview(title)
        for i in 0..<4 {
            let v = UIImageView(frame: CGRect(x: 20 + 95 * i, y: 130, width: 80, height: 45))
            v.backgroundColor = .lightGray; v.accessibilityIdentifier = "thumb\(i)"; v.contentMode = .scaleToFill
            view.addSubview(v); thumbs.append(v)
        }
        status.frame = CGRect(x: 20, y: 190, width: 362, height: 22); status.accessibilityIdentifier = "status"
        view.addSubview(status)
        startPlayer()
        DispatchQueue.global().async {
            self.audioToolbox()
            self.editing()
        }
    }

    // MARK: AVAudioPlayer + AVAudioSession
    func startPlayer() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
        log("route \(session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ","))")
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] n in
            guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber, let type = AVAudioSession.InterruptionType(rawValue: raw.uintValue) else { return }
            if type == .began {
                log("interruption began, player playing=\(self?.player?.isPlaying ?? false)")
                self?.status.text = "Interrupted"
            } else {
                let opts = AVAudioSession.InterruptionOptions(rawValue: (n.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0)
                let resumed = opts.contains(.shouldResume) ? (self?.player?.play() ?? false) : false
                log("interruption ended shouldResume=\(opts.contains(.shouldResume)) resumed=\(resumed) playing=\(self?.player?.isPlaying ?? false)")
                self?.status.text = "Playing"
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { n in
            let reason = (n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue ?? 0
            let prev = (n.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?.outputs.first?.portType.rawValue ?? "?"
            log("route change reason=\(reason) output=\(session.currentRoute.outputs.first?.portType.rawValue ?? "?") previous=\(prev)")
        })
        do {
            let p = try AVAudioPlayer(contentsOf: res.appendingPathComponent("tone.wav"))
            player = p
            log("player channels=\(p.numberOfChannels) duration=\(f2(p.duration))")
            p.enableRate = true
            p.rate = 2
            p.pan = -1
            p.isMeteringEnabled = true
            p.numberOfLoops = -1
            let ok = p.play()
            // the rate is measured against a silent rate-1 player of the same file: both positions advance with the audio
            // mixer's clock, so their ratio is the rate however late the main thread or the mixer runs (the wall clock is not)
            let ref = try AVAudioPlayer(contentsOf: res.appendingPathComponent("tone.wav"))
            ref.volume = 0
            ref.numberOfLoops = -1
            ref.play()
            RateProbe(p, ref) { measured in
                ref.stop()
                p.updateMeters()
                log("player played=\(ok) rate=\(p.rate) pan=\(p.pan) position rate=\(measured.map(f2) ?? "none")")
                log("meter avg \(String(format: "%.1f", p.averagePower(forChannel: 0))) peak \(String(format: "%.1f", p.peakPower(forChannel: 0)))")
            }.schedule()
        } catch { log("player error \(error)") }
    }

    // MARK: composition, export, reader, writer
    func export(_ asset: AVAsset, preset: String, to url: URL, type: AVFileType) -> AVAssetExportSession? {
        guard let s = AVAssetExportSession(asset: asset, presetName: preset) else { log("no export session for \(preset)"); return nil }
        s.outputURL = url; s.outputFileType = type
        let sem = DispatchSemaphore(value: 0)
        s.exportAsynchronously { sem.signal() }
        sem.wait()
        return s
    }
    func show(_ asset: AVAsset, at t: Double, in i: Int) -> String {
        let g = AVAssetImageGenerator(asset: asset)
        guard let img = try? g.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else { return "none" }
        DispatchQueue.main.async { self.thumbs[i].image = UIImage(cgImage: img) }
        return "\(img.width)x\(img.height)"
    }
    func editing() {
        let red = AVURLAsset(url: res.appendingPathComponent("red.mp4")), blue = AVURLAsset(url: res.appendingPathComponent("blue.mp4"))
        let one = CMTimeRange(start: .zero, duration: sec(1, 1))
        do {
            // red 0-1, then red's first half inserted at 1 s, blue after it: red 0-1.5, blue 1.5-2.5
            let comp = AVMutableComposition()
            try comp.insertTimeRange(one, of: red, at: .zero)
            try comp.insertTimeRange(one, of: blue, at: sec(1, 1))
            try comp.insertTimeRange(CMTimeRange(start: .zero, duration: sec(1, 2)), of: red, at: sec(1, 1))
            let vt = comp.tracks(withMediaType: .video).first as? AVCompositionTrack
            log("composition duration=\(f2(comp.duration.seconds)) tracks=\(comp.tracks.count) segments=\(vt?.segments.count ?? 0)")
            let cut = AVMutableComposition()
            try cut.insertTimeRange(one, of: red, at: .zero)
            try cut.insertTimeRange(one, of: blue, at: sec(1, 1))
            cut.removeTimeRange(CMTimeRange(start: sec(1, 2), duration: sec(1, 1)))
            log("removeTimeRange duration=\(f2(cut.duration.seconds))")

            let out = fresh("edit.mp4")
            if let s = export(comp, preset: AVAssetExportPresetHighestQuality, to: out, type: .mp4) {
                log("export status=\(s.status == .completed ? "completed" : "\(s.status.rawValue) \(s.error.map { "\($0)" } ?? "")") progress=\(f2(Double(s.progress)))")
            }
            let edited = AVURLAsset(url: out)
            log("exported duration=\(f2(edited.duration.seconds)) video=\(edited.tracks(withMediaType: .video).count) audio=\(edited.tracks(withMediaType: .audio).count)")
            log("thumbs \(show(edited, at: 0.5, in: 0)) \(show(edited, at: 1.25, in: 1)) \(show(edited, at: 2.0, in: 2))")

            // speed change: 1 s of red stretched to 2 s, exported with the iOS 18 async API
            let slow = AVMutableComposition()
            try slow.insertTimeRange(one, of: red, at: .zero)
            slow.scaleTimeRange(one, toDuration: sec(2, 1))
            let slowURL = fresh("slow.mov")
            let sem = DispatchSemaphore(value: 0)
            if #available(iOS 18.0, *) {
                Task.detached {
                    do {
                        try await AVAssetExportSession(asset: slow, presetName: AVAssetExportPreset640x480)!.export(to: slowURL, as: .mov)
                        log("scaled export duration=\(f2(AVURLAsset(url: slowURL).duration.seconds))")
                    } catch { log("scaled export error \(error)") }
                    sem.signal()
                }
                sem.wait()
            } else {
                _ = export(slow, preset: AVAssetExportPreset640x480, to: slowURL, type: .mov)
                log("scaled export duration=\(f2(AVURLAsset(url: slowURL).duration.seconds))")
            }

            // audio only (AppleM4A preset) and a failing export (missing output URL)
            let m4a = fresh("sound.m4a")
            if let s = export(red, preset: AVAssetExportPresetAppleM4A, to: m4a, type: .m4a) {
                let a = AVURLAsset(url: m4a)
                log("m4a export status=\(s.status.rawValue) video=\(a.tracks(withMediaType: .video).count) audio=\(a.tracks(withMediaType: .audio).count) duration=\(f2(a.duration.seconds))")
            }
            if let bad = AVAssetExportSession(asset: red, presetName: AVAssetExportPresetPassthrough) {
                let sem2 = DispatchSemaphore(value: 0)
                bad.exportAsynchronously { sem2.signal() }
                sem2.wait()
                log("export without outputURL status=\(bad.status == .failed ? "failed" : "\(bad.status.rawValue)") error=\(bad.error.map { "\($0)" } ?? "nil")")
            }

            // reader: BGRA frames of the edit, 16-bit PCM of the tone
            let reader = try AVAssetReader(asset: edited)
            let vout = AVAssetReaderTrackOutput(track: edited.tracks(withMediaType: .video)[0], outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            reader.add(vout)
            reader.startReading()
            var frames = 0, colors: [String] = []
            while let sb = vout.copyNextSampleBuffer() {
                if frames % 25 == 12, let pb = CMSampleBufferGetImageBuffer(sb) {
                    _ = CVPixelBufferLockBaseAddress(pb, .readOnly)
                    let p = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
                    let o = (CVPixelBufferGetHeight(pb) / 2) * CVPixelBufferGetBytesPerRow(pb) + (CVPixelBufferGetWidth(pb) / 2) * 4
                    colors.append(colorName(b: p[o], g: p[o + 1], r: p[o + 2]))
                    _ = CVPixelBufferUnlockBaseAddress(pb, .readOnly)
                }
                frames += 1
            }
            log("reader frames=\(frames) status=\(reader.status == .completed ? "completed" : "\(reader.status.rawValue)") colors=\(colors.joined(separator: ","))")

            let tone = AVURLAsset(url: res.appendingPathComponent("tone.wav"))
            let ar = try AVAssetReader(asset: tone)
            let aout = AVAssetReaderTrackOutput(track: tone.tracks(withMediaType: .audio)[0], outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100,
                                                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false])
            ar.add(aout); ar.startReading()
            var samples = 0, peak: Int16 = 0
            var audioBuffers: [CMSampleBuffer] = []
            while let sb = aout.copyNextSampleBuffer() {
                audioBuffers.append(sb)
                samples += CMSampleBufferGetNumSamples(sb)
                if let bb = CMSampleBufferGetDataBuffer(sb) {
                    var data = [Int16](repeating: 0, count: CMBlockBufferGetDataLength(bb) / 2)
                    _ = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
                    peak = max(peak, data.map { $0 == .min ? .max : abs($0) }.max() ?? 0)
                }
            }
            log("audio reader samples=\(samples) peak=\(f2(Double(peak) / 32768))")

            // writer: 30 green 64x64 frames at 30 fps plus the tone's samples, H.264 + AAC in a .mov
            let mov = fresh("green.mov")
            let writer = try AVAssetWriter(outputURL: mov, fileType: .mov)
            let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264.rawValue, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
            let ain = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                                                                                                     kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64])
            writer.add(vin); writer.add(ain)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            var appended = 0
            for i in 0..<30 {
                var pb: CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let pb else { break }
                _ = CVPixelBufferLockBaseAddress(pb, [])
                let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(pb)
                for y in 0..<64 { for x in 0..<64 { let o = y * bpr + x * 4; base[o] = 0; base[o + 1] = 255; base[o + 2] = 0; base[o + 3] = 255 } }
                _ = CVPixelBufferUnlockBaseAddress(pb, [])
                if adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i), timescale: 30)) { appended += 1 }
            }
            for sb in audioBuffers { ain.append(sb) }
            vin.markAsFinished(); ain.markAsFinished()
            let sem3 = DispatchSemaphore(value: 0)
            writer.finishWriting { sem3.signal() }
            sem3.wait()
            let g = AVURLAsset(url: mov)
            let size = g.tracks(withMediaType: .video).first?.naturalSize ?? .zero
            log("writer status=\(writer.status == .completed ? "completed" : "\(writer.status.rawValue) \(writer.error.map { "\($0)" } ?? "")") frames=\(appended) duration=\(f2(g.duration.seconds)) size=\(Int(size.width))x\(Int(size.height)) audio=\(g.tracks(withMediaType: .audio).count)")
            log("writer thumb \(show(g, at: 0.5, in: 3))")
        } catch { log("editing error \(error)") }
        DispatchQueue.main.async { self.status.text = "Done"; log("editing done") }
    }

    // MARK: AudioToolbox
    func audioToolbox() {
        let wav = res.appendingPathComponent("tone.wav") as CFURL
        var ext: ExtAudioFileRef?
        guard ExtAudioFileOpenURL(wav, &ext) == noErr, let ext else { log("ExtAudioFileOpenURL failed"); return }
        var fileFormat = AudioStreamBasicDescription(), size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        _ = ExtAudioFileGetProperty(ext, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat)
        var length: Int64 = 0; size = 8
        _ = ExtAudioFileGetProperty(ext, kExtAudioFileProperty_FileLengthFrames, &size, &length)
        log("extaudiofile \(Int(fileFormat.mSampleRate)) Hz \(fileFormat.mChannelsPerFrame) ch \(fileFormat.mBitsPerChannel)-bit frames=\(length)")
        // client format: 48 kHz mono float
        var client = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                                 mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        _ = ExtAudioFileSetProperty(ext, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &client)
        var all: [Float] = []
        var chunk = [Float](repeating: 0, count: 4096)
        while true {
            var n: UInt32 = 4096
            let got: UInt32 = chunk.withUnsafeMutableBytes { raw in
                var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(raw.count), mData: raw.baseAddress))
                _ = ExtAudioFileRead(ext, &n, &list)
                return n
            }
            if got == 0 { break }
            all += chunk[0..<Int(got)]
        }
        ExtAudioFileDispose(ext)
        log("extaudiofile read \(all.count) frames at 48000 Hz mono, peak \(f2(Double(all.map(abs).max() ?? 0)))")

        // write a 16-bit 48 kHz mono CAF with ExtAudioFile, read its properties back with AudioFile
        let caf = fresh("tone.caf")
        var fmt16 = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var wext: ExtAudioFileRef?
        if ExtAudioFileCreateWithURL(caf as CFURL, kAudioFileCAFType, &fmt16, nil, AudioFileFlags.eraseFile.rawValue, &wext) == noErr, let wext {
            _ = ExtAudioFileSetProperty(wext, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &client)
            var copy = all
            let count = UInt32(copy.count)
            copy.withUnsafeMutableBytes { raw in
                var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(raw.count), mData: raw.baseAddress))
                _ = ExtAudioFileWrite(wext, count, &list)
            }
            ExtAudioFileDispose(wext)
        }
        var af: AudioFileID?
        if AudioFileOpenURL(caf as CFURL, .readPermission, kAudioFileCAFType, &af) == noErr, let af {
            var packets: UInt64 = 0, desc = AudioStreamBasicDescription(), dur = 0.0
            var s1 = UInt32(8), s2 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size), s3 = UInt32(8)
            _ = AudioFileGetProperty(af, kAudioFilePropertyAudioDataPacketCount, &s1, &packets)
            _ = AudioFileGetProperty(af, kAudioFilePropertyDataFormat, &s2, &desc)
            _ = AudioFileGetProperty(af, kAudioFilePropertyEstimatedDuration, &s3, &dur)
            var bytes = UInt32(8), first = [Int16](repeating: 0, count: 4)
            _ = first.withUnsafeMutableBytes { AudioFileReadBytes(af, false, 24, &bytes, $0.baseAddress!) }
            log("audiofile caf packets=\(packets) \(desc.mBitsPerChannel)-bit \(Int(desc.mSampleRate)) Hz duration=\(f2(dur)) firstBytes=\(bytes)")
            AudioFileClose(af)
        } else { log("AudioFileOpenURL failed") }

        // converter: 16-bit stereo 44.1 kHz -> float mono 22.05 kHz, pulling input through a C callback
        final class Feed { var data: [Int16]; var pos = 0; init(_ d: [Int16]) { data = d } }
        var src16 = [Int16](repeating: 0, count: 44100 * 2)
        for i in 0..<44100 { let v = Int16(16384 * sin(2 * Double.pi * 1000 * Double(i) / 44100)); src16[2 * i] = v; src16[2 * i + 1] = v }
        let feed = Feed(src16)
        var inFmt = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
        var outFmt = AudioStreamBasicDescription(mSampleRate: 22050, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                                 mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var conv: AudioConverterRef?
        var aac = AudioStreamBasicDescription(); aac.mFormatID = kAudioFormatMPEG4AAC; aac.mSampleRate = 44100; aac.mChannelsPerFrame = 2
        var bad: AudioConverterRef?
        log("converter to AAC status=\(AudioConverterNew(&inFmt, &aac, &bad) == kAudioConverterErr_FormatNotSupported ? "fmt?" : "other")")
        if AudioConverterNew(&inFmt, &outFmt, &conv) == noErr, let conv {
            var out = [Float](repeating: 0, count: 30000)
            let ud = Unmanaged.passUnretained(feed).toOpaque()
            var produced = 0
            while produced < out.count {
                var n = UInt32(min(4096, out.count - produced))
                let st: OSStatus = out.withUnsafeMutableBytes { raw in
                    var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: n * 4, mData: raw.baseAddress! + produced * 4))
                    return AudioConverterFillComplexBuffer(conv, { _, ioPackets, ioData, _, user in
                        let f = Unmanaged<Feed>.fromOpaque(user!).takeUnretainedValue()
                        let n = min(Int(ioPackets.pointee), (f.data.count / 2) - f.pos)
                        ioPackets.pointee = UInt32(max(0, n))
                        if n <= 0 { return 0 }
                        ioData.pointee.mNumberBuffers = 1
                        ioData.pointee.mBuffers.mNumberChannels = 2
                        ioData.pointee.mBuffers.mDataByteSize = UInt32(n * 4)
                        ioData.pointee.mBuffers.mData = f.data.withUnsafeMutableBytes { $0.baseAddress! + f.pos * 4 }
                        f.pos += n
                        return 0
                    }, ud, &n, &list, nil)
                }
                if n == 0 || st != noErr { break }
                produced += Int(n)
            }
            AudioConverterDispose(conv)
            log("converter out=\(produced) peak=\(f2(Double(out[0..<produced].map(abs).max() ?? 0)))")
        }

        // queue output: 0.1 s float buffers refilled from the callback (volume 0 keeps the tap clean)
        final class QState { var callbacks = 0; var phase = 0.0 }
        let qs = QState()
        var qfmt = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var queue: AudioQueueRef?
        let fill: AudioQueueOutputCallback = { user, q, buf in
            let s = Unmanaged<QState>.fromOpaque(user!).takeUnretainedValue()
            s.callbacks += 1
            let n = Int(buf.pointee.mAudioDataBytesCapacity) / 4
            let p = buf.pointee.mAudioData.assumingMemoryBound(to: Float.self)
            for i in 0..<n { p[i] = Float(0.3 * sin(s.phase)); s.phase += 2 * Double.pi * 440 / 48000 }
            buf.pointee.mAudioDataByteSize = UInt32(n * 4)
            _ = AudioQueueEnqueueBuffer(q, buf, 0, nil)
        }
        if AudioQueueNewOutput(&qfmt, fill, Unmanaged.passUnretained(qs).toOpaque(), nil, nil, 0, &queue) == noErr, let queue {
            _ = AudioQueueSetParameter(queue, kAudioQueueParam_Volume, 0)
            for _ in 0..<3 {
                var b: AudioQueueBufferRef?
                _ = AudioQueueAllocateBuffer(queue, 4800 * 4, &b)
                if let b { fill(Unmanaged.passUnretained(qs).toOpaque(), queue, b); qs.callbacks -= 1 }
            }
            let t0 = Date()
            _ = AudioQueueStart(queue, nil)
            // until 0.5 s have played (by the queue's own clock, which a loaded machine runs late): the test compares
            // the callbacks with the time played, and the time played with the time taken
            var ts = AudioTimeStamp()
            repeat {
                Thread.sleep(forTimeInterval: 0.05)
                _ = AudioQueueGetCurrentTime(queue, nil, &ts, nil)
            } while ts.mSampleTime < 0.5 * 48000 && Date().timeIntervalSince(t0) < 10
            var running: UInt32 = 0, rs = UInt32(4)
            _ = AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &running, &rs)
            _ = AudioQueueStop(queue, true)
            log("queue output callbacks=\(qs.callbacks) played=\(f2(ts.mSampleTime / 48000)) s in \(f2(Date().timeIntervalSince(t0))) s running=\(running)")
            _ = AudioQueueDispose(queue, true)
        }

        // queue input: 16 kHz mono 16-bit from the simulated microphone (ISIM_AUDIO_INPUT)
        final class IState { var frames = 0; var peak: Int16 = 0 }
        let ist = IState()
        var ifmt = AudioStreamBasicDescription(mSampleRate: 16000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var iq: AudioQueueRef?
        let got: AudioQueueInputCallback = { user, q, buf, _, packets, _ in
            let s = Unmanaged<IState>.fromOpaque(user!).takeUnretainedValue()
            let p = buf.pointee.mAudioData.assumingMemoryBound(to: Int16.self)
            for i in 0..<Int(packets) { s.peak = max(s.peak, p[i] == .min ? .max : abs(p[i])) }
            s.frames += Int(packets)
            _ = AudioQueueEnqueueBuffer(q, buf, 0, nil)
        }
        if AudioQueueNewInput(&ifmt, got, Unmanaged.passUnretained(ist).toOpaque(), nil, nil, 0, &iq) == noErr, let iq {
            for _ in 0..<3 { var b: AudioQueueBufferRef?; _ = AudioQueueAllocateBuffer(iq, 1600 * 2, &b); if let b { _ = AudioQueueEnqueueBuffer(iq, b, 0, nil) } }
            _ = AudioQueueStart(iq, nil)
            let t0 = Date()                              // until 5 buffers (0.5 s) came in, not a fixed time
            repeat { Thread.sleep(forTimeInterval: 0.05) } while ist.frames < 8000 && Date().timeIntervalSince(t0) < 10
            _ = AudioQueueStop(iq, true)
            log("queue input frames=\(ist.frames) peak=\(f2(Double(ist.peak) / 32768))")
            _ = AudioQueueDispose(iq, true)
        }
    }
}

/// How fast a player's position runs relative to a rate-1 player's, over 0.1-0.45 s of the reference's playback. Both
/// positions wrap at the file's duration; over less than half of it the two differences are unambiguous at rate 2.
final class RateProbe {
    let p: AVAudioPlayer, ref: AVAudioPlayer, done: (Double?) -> Void
    var start: (ref: Double, p: Double)?
    var left = 250                                   // samples (every 20 ms) before giving up
    init(_ p: AVAudioPlayer, _ ref: AVAudioPlayer, _ done: @escaping (Double?) -> Void) { self.p = p; self.ref = ref; self.done = done }
    func schedule() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { self.sample() } }
    /// both positions, read with no mixing step in between
    func positions() -> (ref: Double, p: Double)? {
        for _ in 0..<20 {
            let r = ref.currentTime, q = p.currentTime
            if ref.currentTime == r { return (r, q) }
        }
        return nil
    }
    func wrapped(_ x: Double) -> Double { let d = ref.duration; return x - (x / d).rounded(.down) * d }
    func sample() {
        left -= 1
        guard left > 0 else { done(nil); return }
        guard let a = start, let b = positions() else { start = positions(); schedule(); return }
        let dr = wrapped(b.ref - a.ref)
        if dr < 0.1 { schedule(); return }
        if dr > 0.45 { start = b; schedule(); return }   // sampled too late to tell the wraps apart: again from here
        done(wrapped(b.p - a.p) / dr)
    }
}
