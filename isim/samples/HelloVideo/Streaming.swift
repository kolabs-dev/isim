// HelloVideo, -streaming [-hls URL]: media that does not come from a file. AVAssetResourceLoader serves clip.mp4
// for a custom URL scheme (isim-sample://) from the app's bundle, in the ranges isim asks for; a scheme whose loader
// declines fails the item; and an HLS stream plays from the URL after -hls (the test serves one on localhost).
// Each player's frames are read with AVPlayerItemVideoOutput to log their colours.
import UIKit
import AVFoundation

final class BundleLoader: NSObject, AVAssetResourceLoaderDelegate {
    let data: Data
    var requests = 0, infoRequests = 0, ranges: [String] = []
    init(_ url: URL) { data = try! Data(contentsOf: url) }
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        requests += 1
        if let info = loadingRequest.contentInformationRequest {
            infoRequests += 1
            info.contentType = "public.mpeg-4"
            info.contentLength = Int64(data.count)
            info.isByteRangeAccessSupported = true
        }
        if let d = loadingRequest.dataRequest {
            let start = Int(d.requestedOffset)
            let end = d.requestsAllDataToEndOfResource ? data.count : min(data.count, start + d.requestedLength)
            if ranges.count < 3 { ranges.append("\(start)-\(end)") }
            // answer later, in two parts, as a network loader would
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [data] in
                let mid = start + (end - start) / 2
                d.respond(with: data.subdata(in: start..<mid))
                d.respond(with: data.subdata(in: mid..<end))
                loadingRequest.finishLoading()
            }
        }
        return true
    }
}
final class DecliningLoader: NSObject, AVAssetResourceLoaderDelegate {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool { false }
}

/// Logs the colours of a player's frames as they change.
final class FrameWatcher {
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
    var colors: [String] = []
    func poll() {
        let t = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: t), let pb = output.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), row = CVPixelBufferGetBytesPerRow(pb)
        let px = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self) + (h / 2) * row + (w / 2) * 4
        let (b, g, r) = (px[0], px[1], px[2])
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        let c = r > 200 && g < 60 ? "red" : g > 200 && r < 60 ? "green" : b > 200 && r < 60 ? "blue" : "other"
        if colors.last != c { colors.append(c) }
    }
}

final class StreamingViewController: UIViewController {
    let loader = BundleLoader(Bundle.main.url(forResource: "clip", withExtension: "mp4")!)
    let decliner = DecliningLoader()
    var players: [(String, AVPlayer, FrameWatcher)] = []
    var observations: [NSKeyValueObservation] = []
    var link: CADisplayLink?
    var deniedPlayer: AVPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Streaming"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41)
        view.addSubview(title)

        let custom = AVURLAsset(url: URL(string: "isim-sample://media/clip.mp4")!)
        custom.resourceLoader.setDelegate(loader, queue: .main)
        add("loader", AVPlayerItem(asset: custom), y: 120)
        let denied = AVURLAsset(url: URL(string: "isim-denied://media/clip.mp4")!)
        denied.resourceLoader.setDelegate(decliner, queue: DispatchQueue(label: "decliner"))
        let deniedItem = AVPlayerItem(asset: denied)
        observations.append(deniedItem.observe(\.status) { item, _ in
            guard item.status == .failed else { return }
            let e = item.error as NSError?
            log("declined status failed domain \(e?.domain ?? "-") code \(e?.code ?? 0)")
        })
        deniedPlayer = AVPlayer(playerItem: deniedItem)
        if let i = CommandLine.arguments.firstIndex(of: "-hls"), i + 1 < CommandLine.arguments.count, let url = URL(string: CommandLine.arguments[i + 1]) {
            add("hls", AVPlayerItem(url: url), y: 330)
        }
        link = CADisplayLink(target: self, selector: #selector(frame))
        link?.add(to: .main, forMode: .common)
    }

    func add(_ name: String, _ item: AVPlayerItem, y: CGFloat) {
        let player = AVPlayer(playerItem: item), watcher = FrameWatcher()
        item.add(watcher.output)
        let host = UIView(frame: CGRect(x: 41, y: y, width: 320, height: 180))
        host.backgroundColor = .black
        host.accessibilityIdentifier = name
        view.addSubview(host)
        let layer = AVPlayerLayer(player: player)
        layer.frame = host.bounds
        host.layer.addSublayer(layer)
        players.append((name, player, watcher))
        observations.append(item.observe(\.status) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                var extra = ""
                if name == "loader" {
                    extra = " requests \(self.loader.requests) info \(self.loader.infoRequests) ranges \(self.loader.ranges.joined(separator: ","))"
                }
                log("\(name) ready duration \(String(format: "%.2f", item.duration.seconds)) size \(Int(item.presentationSize.width))x\(Int(item.presentationSize.height))\(extra)")
                player.play()
                NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { _ in
                    let e = item.accessLog()?.events.last
                    log("\(name) ended frames \(watcher.colors.joined(separator: ",")) type \(e?.playbackType ?? "-") uri \(e?.uri ?? "-")")
                }
            case .failed: log("\(name) failed \((item.error as NSError?)?.localizedFailureReason ?? "")")
            default: break
            }
        })
    }
    @objc func frame() { for (_, _, w) in players { w.poll() } }
}
