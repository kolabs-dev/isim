// Sample: video on isim — AVURLAsset loading, AVPlayer + AVPlayerLayer (as a sublayer and as a view's layerClass),
// KVO / Combine on status and timeControlStatus, periodic and boundary time observers, seeking, rate,
// AVPlayerItemDidPlayToEndTime, AVQueuePlayer, AVPlayerLooper, AVAssetImageGenerator, CMTime, and AVKit's
// AVPlayerViewController (full screen) and SwiftUI VideoPlayer.
// clip.mp4 (made by the build with ffmpeg, buildlib/apps.py): 3 s, 320x180 — red for 1 s, then green, then blue — with a 440 Hz tone.
import UIKit
import AVFoundation
import AVKit
import Combine
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = VideoViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloVideo: %@", s) }

/// A view backed by an AVPlayerLayer (the layerClass pattern).
final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

final class VideoViewController: UIViewController {
    let clip = Bundle.main.url(forResource: "clip", withExtension: "mp4")!
    var player: AVPlayer!
    let playerLayer = AVPlayerLayer()
    let videoHost = UIView()
    let small = PlayerView()
    let statusLabel = UILabel()
    let timeLabel = UILabel()
    var observations: [NSKeyValueObservation] = []
    var cancellables = Set<AnyCancellable>()
    var timeObserver: Any?
    var queue: AVQueuePlayer?
    var looper: AVPlayerLooper?
    var loopPlayer: AVQueuePlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Video"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41)
        view.addSubview(title)

        // AVPlayerLayer added as a sublayer of a plain view
        videoHost.frame = CGRect(x: 41, y: 120, width: 320, height: 180)
        videoHost.backgroundColor = .black
        videoHost.accessibilityIdentifier = "video"
        view.addSubview(videoHost)
        playerLayer.frame = videoHost.layer.bounds
        playerLayer.videoGravity = .resizeAspect
        videoHost.layer.addSublayer(playerLayer)

        statusLabel.frame = CGRect(x: 20, y: 310, width: 362, height: 22); statusLabel.accessibilityIdentifier = "status"
        timeLabel.frame = CGRect(x: 20, y: 334, width: 362, height: 22); timeLabel.accessibilityIdentifier = "time"
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        view.addSubview(statusLabel); view.addSubview(timeLabel)

        var x: CGFloat = 20, y: CGFloat = 370
        for (t, id, sel) in [("Play", "play", #selector(play)), ("Pause", "pause", #selector(pause)), ("Seek 2s", "seek", #selector(seek)),
                             ("2x", "rate", #selector(fast)), ("Queue", "queue", #selector(runQueue)), ("Loop", "loop", #selector(runLooper)),
                             ("Full Screen", "fullscreen", #selector(fullScreen)), ("SwiftUI", "swiftui", #selector(swiftUI))] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            b.frame = CGRect(x: x, y: y, width: 110, height: 40)
            view.addSubview(b)
            x += 122; if x > 300 { x = 20; y += 48 }
        }
        // a second, small player view sharing the same player (layerClass pattern)
        small.frame = CGRect(x: 281, y: 620, width: 96, height: 54)
        small.backgroundColor = .darkGray
        small.accessibilityIdentifier = "small-video"
        view.addSubview(small)

        CMTimeChecks()
        Task { await loadAsset() }
        setUpPlayer()
    }

    func CMTimeChecks() {
        let a = CMTime(value: 1, timescale: 2), b = CMTime(seconds: 0.25, preferredTimescale: 600)
        let sum = a + b
        let range = CMTimeRange(start: .zero, duration: CMTime(value: 3, timescale: 1))
        log("cmtime sum=\(sum.seconds) compare=\(CMTimeCompare(a, b)) contains=\(range.containsTime(CMTime(value: 2, timescale: 1))) end=\(range.end.seconds) invalid=\(CMTime.invalid.isValid)")
    }

    func loadAsset() async {
        let asset = AVURLAsset(url: clip)
        do {
            let (duration, tracks) = try await asset.load(.duration, .tracks)
            let video = try await asset.loadTracks(withMediaType: .video).first
            let size = try await video?.load(.naturalSize) ?? .zero
            let fps = try await video?.load(.nominalFrameRate) ?? 0
            log("asset duration=\(String(format: "%.2f", duration.seconds)) tracks=\(tracks.count) size=\(Int(size.width))x\(Int(size.height)) fps=\(Int(fps)) audio=\(asset.tracks(withMediaType: .audio).count)")
            let gen = AVAssetImageGenerator(asset: asset)
            let img = try gen.copyCGImage(at: CMTime(value: 3, timescale: 2), actualTime: nil)
            log("thumbnail \(img.width)x\(img.height)")
        } catch { log("asset error \(error)") }
        let missing = AVURLAsset(url: URL(fileURLWithPath: "/nonexistent/missing.mp4"))
        do { _ = try await missing.load(.duration); log("missing asset loaded?!") } catch { log("missing asset fails") }
    }

    func setUpPlayer() {
        let item = AVPlayerItem(url: clip)
        player = AVPlayer(playerItem: item)
        playerLayer.player = player
        small.playerLayer.player = player
        small.playerLayer.videoGravity = .resizeAspectFill
        observations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
            log("item status \(item.status == .readyToPlay ? "readyToPlay" : item.status == .failed ? "failed" : "unknown") duration=\(String(format: "%.2f", item.duration.seconds)) size=\(Int(item.presentationSize.width))x\(Int(item.presentationSize.height))")
            self?.statusLabel.text = item.status == .readyToPlay ? "Ready" : "Not ready"
        })
        player.publisher(for: \.timeControlStatus).sink { s in
            log("timeControlStatus \(s == .playing ? "playing" : s == .paused ? "paused" : "waiting")")
        }.store(in: &cancellables)
        observations.append(playerLayer.observe(\.isReadyForDisplay, options: [.new]) { l, _ in log("layer readyForDisplay \(l.isReadyForDisplay)") })
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 2), queue: .main) { [weak self] t in
            self?.timeLabel.text = String(format: "%.1f s", t.seconds)
        }
        _ = player.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTime(value: 1, timescale: 1))], queue: .main) { [weak self] in
            log("boundary 1s at \(String(format: "%.2f", self?.player.currentTime().seconds ?? -1))")
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] n in
            guard let self, let item = n.object as? AVPlayerItem else { return }
            if item === self.player.currentItem { log("did play to end t=\(String(format: "%.2f", self.player.currentTime().seconds)) rate=\(self.player.rate)") }
        }
    }

    @objc func play() { player.play(); log("play") }
    @objc func pause() { player.pause(); log("pause at \(String(format: "%.1f", player.currentTime().seconds))") }
    @objc func seek() {
        player.seek(to: CMTime(value: 2, timescale: 1)) { [weak self] done in
            log("seek finished \(done) t=\(String(format: "%.2f", self?.player.currentTime().seconds ?? -1))")
        }
    }
    @objc func fast() { player.rate = 2; log("rate \(player.rate)") }

    @objc func runQueue() {
        let q = AVQueuePlayer(items: [AVPlayerItem(url: clip), AVPlayerItem(url: clip)])
        q.isMuted = true
        queue = q
        let items = q.items()
        var ends = 0
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { n in
            guard items.contains(where: { $0 === n.object as AnyObject }) else { return }
            ends += 1
            DispatchQueue.main.async { log("queue item ended (\(ends)); now playing \(q.items().count) item(s)") }
        }
        q.rate = 3
        log("queue started with \(q.items().count) items")
    }
    @objc func runLooper() {
        let q = AVQueuePlayer()
        q.isMuted = true
        let template = AVPlayerItem(url: clip)
        looper = AVPlayerLooper(player: q, templateItem: template, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 2)))
        loopPlayer = q
        q.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in log("looper loopCount=\(self?.looper?.loopCount ?? -1) status=\(self?.looper?.status == .ready ? "ready" : "other")") }
    }
    @objc func fullScreen() {
        player.pause()
        let vc = AVPlayerViewController()
        vc.player = player
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: false) { log("presented AVPlayerViewController") }
    }
    @objc func swiftUI() {
        player.pause()
        let p = AVPlayer(url: clip)
        let host = UIHostingController(rootView: SwiftUIPlayer(player: p))
        host.modalPresentationStyle = .fullScreen
        present(host, animated: false)
    }
}

struct SwiftUIPlayer: View {
    let player: AVPlayer
    var body: some View {
        VideoPlayer(player: player) {
            VStack { Text("SwiftUI VideoPlayer").foregroundColor(.white).padding(.top, 80); Spacer() }
        }
        .ignoresSafeArea()
        .onAppear { player.play(); log("SwiftUI VideoPlayer appeared") }
    }
}
