// Sample: ReplayKit on isim. A red screen with a moving square is recorded and checked; the steps run on launch and
// log their results:
// - availability, a recording written with stopRecording(withOutput:) (its duration and the colour of a frame),
//   the camera preview while recording;
// - capture: video sample buffers and microphone buffers (startCapture);
// - clip buffering: the last second exported with exportClip(to:duration:);
// - the broadcast sheet and the system broadcast picker (no broadcast services on isim);
// - last, a recording stopped with stopRecording(handler:): its preview is presented until Save or Cancel is tapped.
// Launch with -deny-test to only try a recording (the consent alert answered by ISIM_REPLAYKIT_PERMISSION).
import UIKit
import AVFoundation
import ReplayKit

private func log(_ s: String) { NSLog("HelloReplayKit: %@", s) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ReplayViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class ReplayViewController: UIViewController, RPPreviewViewControllerDelegate, RPBroadcastActivityViewControllerDelegate {
    let recorder = RPScreenRecorder.shared()
    let square = UIView(frame: CGRect(x: 40, y: 300, width: 60, height: 60))
    var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        square.backgroundColor = .white
        view.addSubview(square)
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 20, y: 120, width: 44, height: 44))
        picker.preferredExtension = "com.example.broadcast"
        view.addSubview(picker)
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
    }
    @objc func step() { square.frame.origin.x = 40 + CGFloat(Int(CACurrentMediaTime() * 120) % 240) }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Task { @MainActor in await run() }
    }

    func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9)) }

    @MainActor func run() async {
        log("available=\(recorder.isAvailable) recording=\(recorder.isRecording)")
        if ProcessInfo.processInfo.arguments.contains("-deny-test") {
            recorder.startRecording { e in
                let ns = e as NSError?
                log("start error domain=\(ns?.domain ?? "-") code=\(ns?.code ?? 0)")
                log("done")
            }
            return
        }
        // a recording to a file, with the camera preview
        let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("recording.mp4")
        recorder.isCameraEnabled = true
        do {
            try await recorder.startRecording()
            log("recording started isRecording=\(recorder.isRecording) camera=\(recorder.cameraPreviewView != nil)")
            if let preview = recorder.cameraPreviewView { preview.frame.origin = CGPoint(x: 260, y: 600); view.addSubview(preview) }
            await wait(1.5)
            recorder.cameraPreviewView?.removeFromSuperview()
            try await recorder.stopRecording(withOutput: out)
            let asset = AVURLAsset(url: out)
            let generator = AVAssetImageGenerator(asset: asset)
            let image = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
            log("output duration=\(String(format: "%.1f", asset.duration.seconds)) size=\(image.width)x\(image.height) colour=\(colour(image))")
        } catch { log("recording error \(error)") }
        recorder.isCameraEnabled = false
        let again = await withCheckedContinuation { k in recorder.stopRecording(withOutput: out) { k.resume(returning: $0 as NSError?) } }
        log("stop when not recording code=\(again?.code ?? 0)")

        // capture: sample buffers, with the microphone
        var video = 0, mic = 0, size = ""
        let lock = NSLock()
        recorder.isMicrophoneEnabled = true
        do {
            try await recorder.startCapture { sb, type, _ in
                lock.lock(); defer { lock.unlock() }
                if type == .video {
                    video += 1
                    if let b = sb.imageBuffer { size = "\(CVPixelBufferGetWidth(b))x\(CVPixelBufferGetHeight(b))" }
                } else if type == .audioMic { mic += 1 }
            }
            await wait(1)
            try await recorder.stopCapture()
            lock.lock(); log("capture video=\(video > 5) mic=\(mic > 0) size=\(size)"); lock.unlock()
        } catch { log("capture error \(error)") }
        recorder.isMicrophoneEnabled = false

        // clip buffering
        do {
            try await recorder.startClipBuffering()
            await wait(2)
            let clip = FileManager.default.temporaryDirectory.appendingPathComponent("clip.mp4")
            try await recorder.exportClip(to: clip, duration: 1)
            log("clip duration=\(String(format: "%.1f", AVURLAsset(url: clip).duration.seconds))")
            try await recorder.stopClipBuffering()
        } catch { log("clip error \(error)") }

        // broadcasting: no services
        RPBroadcastActivityViewController.load(handler: { vc, error in
            guard let vc else { log("broadcast sheet error \(String(describing: error))"); return }
            vc.delegate = self
            self.present(vc, animated: true)
            log("broadcast sheet shown")
        })
    }

    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController, didFinishWith broadcastController: RPBroadcastController?, error: Error?) {
        log("broadcast finished controller=\(broadcastController != nil) code=\((error as NSError?)?.code ?? 0)")
        broadcastActivityViewController.dismiss(animated: true) { Task { @MainActor in await self.previewStep() } }
    }

    /// a recording shown in the preview sheet
    @MainActor func previewStep() async {
        do {
            try await recorder.startRecording()
            await wait(1)
            let preview = try await recorder.stopRecording()
            preview.previewControllerDelegate = self
            await present(preview, animated: true)
            log("preview presented")
        } catch { log("preview error \(error)") }
    }
    func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
        log("preview activities \(activityTypes.sorted().joined(separator: ","))")
    }
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true) { log("done") }
    }

    func colour(_ image: CGImage) -> String {
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // a point well inside the red background (the square moves along y = 300...360)
        ctx.draw(image, in: CGRect(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) * 0.8, width: CGFloat(image.width), height: CGFloat(image.height)))
        return px[0] > 180 && px[1] < 80 && px[2] < 80 ? "red" : "rgb(\(px[0]),\(px[1]),\(px[2]))"
    }
}
