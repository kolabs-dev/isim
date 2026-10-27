// HelloSoundAnalysis ("Sounds"): Sound Analysis. The built-in classifier's labels and window constraint; a sound made
// in the app (a second of near silence, then two seconds of a 440 Hz tone, 44.1 kHz stereo) analyzed as a stream
// (SNAudioStreamAnalyzer, buffer by buffer) and as a file (SNAudioFileAnalyzer, written with AVAudioFile, with and
// without a completion handler, cancelled); the errors (a window outside the classifier's range, a
// file that is not audio). The screen lists each window's top classification. Each step logs a "HelloSoundAnalysis:"
// line.
import UIKit
import AVFoundation
import SoundAnalysis

func log(_ s: String) { NSLog("HelloSoundAnalysis: %@", s) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 80, width: vc.view.bounds.width - 40, height: 500))
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        label.accessibilityIdentifier = "windows"
        vc.view.addSubview(label)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        DispatchQueue.global().async {
            let text = Demo.run()
            DispatchQueue.main.async { label.text = text; log("done") }
        }
        return true
    }
}

/// collects a request's results
final class Collector: NSObject, SNResultsObserving, @unchecked Sendable {
    let lock = NSLock()
    var windows: [(start: Double, duration: Double, top: String, confidence: Double)] = []
    var completed = false
    var failure: Error?
    func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let r = result as? SNClassificationResult, let top = r.classifications.first else { return }
        lock.lock(); windows.append((r.timeRange.start.seconds, r.timeRange.duration.seconds, top.identifier, top.confidence)); lock.unlock()
    }
    func request(_ request: any SNRequest, didFailWithError error: any Error) { lock.lock(); failure = error; lock.unlock() }
    func requestDidComplete(_ request: any SNRequest) { lock.lock(); completed = true; lock.unlock() }
    var tops: String { windows.map(\.top).joined(separator: ",") }
}

enum Demo {
    static let rate = 44100.0
    /// one second of near silence, then two of a 440 Hz tone (stereo)
    static func sound() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let frames = AVAudioFrameCount(rate * 3)
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        b.frameLength = frames
        for c in 0..<2 {
            let p = b.floatChannelData![c]
            for i in 0..<Int(frames) {
                let t = Double(i) / rate
                p[i] = t < 1 ? Float(0.001 * sin(2 * .pi * 50 * t)) : Float(0.5 * sin(2 * .pi * 440 * t))
            }
        }
        return b
    }
    static func describe(_ e: Error) -> String { let n = e as NSError; return "\(n.domain) \(n.code) \(n.localizedDescription)" }

    static func run() -> String {
        let request: SNClassifySoundRequest
        do { request = try SNClassifySoundRequest(classifierIdentifier: .version1) } catch {
            log("classifier unavailable: \(describe(error))")
            return "No sound classifier: \(error.localizedDescription)"
        }
        log("known \(request.knownClassifications) window \(request.windowDuration.seconds) overlap \(request.overlapFactor)")
        if case .durationRange(let r) = request.windowDurationConstraint {
            log("constraint range \(r.start.seconds) ... \(r.end.seconds)")
        }

        /* a stream, buffer by buffer (4096 frames) */
        let sound = sound()
        let stream = SNAudioStreamAnalyzer(format: sound.format)
        let streamed = Collector()
        do { try stream.add(request, withObserver: streamed) } catch { log("stream add error \(describe(error))") }
        var position: AVAudioFramePosition = 0
        let chunk = AVAudioPCMBuffer(pcmFormat: sound.format, frameCapacity: 4096)!
        while position < AVAudioFramePosition(sound.frameLength) {
            let n = min(4096, Int(sound.frameLength) - Int(position))
            chunk.frameLength = AVAudioFrameCount(n)
            for c in 0..<2 { memcpy(chunk.floatChannelData![c], sound.floatChannelData![c] + Int(position), n * 4) }
            stream.analyze(chunk, atAudioFramePosition: position)
            position += AVAudioFramePosition(n)
        }
        stream.completeAnalysis()
        let w = streamed.windows
        log("stream windows \(w.count) completed \(streamed.completed) tops \(streamed.tops)")
        if let first = w.first, let last = w.last {
            log(String(format: "stream first %.3f+%.3f %@ %.2f last %.3f %@ %.2f", first.start, first.duration, first.top, first.confidence,
                       last.start, last.top, last.confidence))
        }

        /* a file */
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sound.wav")
        do {
            let file = try AVAudioFile(forWriting: url, settings: sound.format.settings)
            try file.write(from: sound)
            file.close()
        } catch { log("write error \(describe(error))") }
        do {
            let files = try SNAudioFileAnalyzer(url: url)
            let r2 = try SNClassifySoundRequest(classifierIdentifier: .version1)
            r2.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 48000)
            r2.overlapFactor = 0
            let got = Collector()
            try files.add(r2, withObserver: got)
            files.analyze()
            log("file windows \(got.windows.count) completed \(got.completed) tops \(got.tops)")

            let again = Collector(), done = DispatchSemaphore(value: 0)
            files.removeAllRequests()
            try files.add(request, withObserver: again)
            nonisolated(unsafe) var reached = false
            files.analyze { ok in reached = ok; done.signal() }
            done.wait()
            log("async reached end \(reached) windows \(again.windows.count)")
            let cancelled = try SNAudioFileAnalyzer(url: url)
            try cancelled.add(request, withObserver: Collector())
            cancelled.cancelAnalysis()
            cancelled.analyze { ok in reached = ok; done.signal() }
            done.wait()
            log("cancelled reached end \(reached)")
        } catch { log("file error \(describe(error))") }

        /* the errors */
        let short = try! SNClassifySoundRequest(classifierIdentifier: .version1)
        short.windowDuration = CMTime(seconds: 0.2, preferredTimescale: 1000)
        do { try stream.add(short, withObserver: Collector()) } catch SNError.invalidFormat { log("short window invalidFormat") } catch { log("short window \(describe(error))") }
        let notAudio = FileManager.default.temporaryDirectory.appendingPathComponent("not-audio.wav")
        try? Data("not audio".utf8).write(to: notAudio)
        do { _ = try SNAudioFileAnalyzer(url: notAudio) } catch { log("not audio \(describe(error))") }

        return w.map { String(format: "%5.2f s  %@  %.2f", $0.start, $0.top, $0.confidence) }.joined(separator: "\n")
    }
}
