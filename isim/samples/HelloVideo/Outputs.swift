// HelloVideo, -outputs: media selection and player item outputs on isim — tracks.mp4 (made by the build) has the red /
// green / blue video, two soundtracks (English 440 Hz, French 880 Hz) and two subtitle tracks (English, Spanish);
// id3.ts is a 3 s soundtrack with timed ID3 tags at 0.5 s and 1.5 s.
// Logs (for the test): the audible and legible groups, the French soundtrack and Spanish subtitles selected, the
// legible output's cues, video output frames (their colour), the metadata output's groups, the access and error
// logs and the rate change reasons.
import UIKit
import AVFoundation

final class OutputsViewController: UIViewController, AVPlayerItemLegibleOutputPushDelegate, AVPlayerItemMetadataOutputPushDelegate,
                                    AVPlayerItemOutputPullDelegate {
    let tracks = Bundle.main.url(forResource: "tracks", withExtension: "mp4")!
    let id3 = Bundle.main.url(forResource: "id3", withExtension: "ts")!
    var player = AVPlayer()
    let playerLayer = AVPlayerLayer()
    let host = UIView()
    let legible = AVPlayerItemLegibleOutput()
    let video = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    let metadata = AVPlayerItemMetadataOutput(identifiers: nil)
    var id3Player = AVPlayer()
    var colors: [String] = []
    var link: CADisplayLink?
    var reasons: [String] = []
    var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Outputs"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41)
        view.addSubview(title)
        host.frame = CGRect(x: 41, y: 120, width: 320, height: 180)
        host.backgroundColor = .black
        host.accessibilityIdentifier = "video"
        view.addSubview(host)
        playerLayer.frame = host.layer.bounds
        host.layer.addSublayer(playerLayer)
        playerLayer.player = player

        observers.append(NotificationCenter.default.addObserver(forName: AVPlayer.rateDidChangeNotification, object: player, queue: .main) { [weak self] n in
            let r = (n.userInfo?[AVPlayer.rateDidChangeReasonKey] as? AVPlayer.RateDidChangeReason)?.rawValue ?? "none"
            self?.reasons.append(r.replacingOccurrences(of: "AVPlayerRateDidChangeReason", with: ""))
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVPlayerItem.newAccessLogEntryNotification, object: nil, queue: .main) { _ in
            log("access log entry")
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: nil, queue: .main) { n in
            let e = (n.object as? AVPlayerItem)?.errorLog()?.events.last
            log("error log domain \(e?.errorDomain ?? "-") code \(e?.errorStatusCode ?? 0) comment \(e?.errorComment != nil)")
        })
        Task { await start() }
    }

    func start() async {
        let asset = AVURLAsset(url: tracks)
        guard let audible = try? await asset.loadMediaSelectionGroup(for: .audible),
              let legibleGroup = try? await asset.loadMediaSelectionGroup(for: .legible) else { log("no selection groups"); return }
        let names = { (g: AVMediaSelectionGroup) in g.options.map { "\($0.displayName(with: Locale(identifier: "en_US")))/\($0.extendedLanguageTag ?? "-")" }.joined(separator: ",") }
        log("audible \(names(audible)) default \(audible.defaultOption?.extendedLanguageTag ?? "-") empty \(audible.allowsEmptySelection)")
        log("legible \(names(legibleGroup)) default \(legibleGroup.defaultOption?.extendedLanguageTag ?? "none") empty \(legibleGroup.allowsEmptySelection) characteristics \(asset.availableMediaCharacteristicsWithMediaSelectionOptions.count)")
        let item = AVPlayerItem(asset: asset)
        let french = AVMediaSelectionGroup.mediaSelectionOptions(from: audible.options, with: Locale(identifier: "fr_FR")).first!
        let spanish = AVMediaSelectionGroup.mediaSelectionOptions(from: legibleGroup.options, filteredAndSortedAccordingToPreferredLanguages: ["es"]).first!
        item.select(french, in: audible)
        item.select(spanish, in: legibleGroup)
        let sel = item.currentMediaSelection
        log("selected audio \(sel.selectedMediaOption(in: audible)?.extendedLanguageTag ?? "-") subtitles \(sel.selectedMediaOption(in: legibleGroup)?.extendedLanguageTag ?? "-") subtype \(spanish.mediaSubTypes.first?.uint32Value == 0x7478_3367)")
        legible.setDelegate(self, queue: .main)
        item.add(legible)
        video.setDelegate(self, queue: .main)
        video.requestNotificationOfMediaDataChange(withAdvanceInterval: 0.03)
        item.add(video)
        log("outputs \(item.outputs.count)")
        player.replaceCurrentItem(with: item)
        player.rate = -1                                      // reverse is not supported: the change fails
        player.play()
        link = CADisplayLink(target: self, selector: #selector(frame))
        link?.add(to: .main, forMode: .common)

        // timed ID3 metadata in MPEG-TS
        let tsItem = AVPlayerItem(url: id3)
        metadata.setDelegate(self, queue: .main)
        tsItem.add(metadata)
        id3Player.replaceCurrentItem(with: tsItem)
        id3Player.isMuted = true
        id3Player.play()

        // an item that cannot play gets an error log
        let broken = AVPlayer(playerItem: AVPlayerItem(url: URL(fileURLWithPath: "/nonexistent/clip.mp4")))
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in
            _ = broken
            let events = player.currentItem?.accessLog()?.events ?? []
            let e = events.last
            let ext = player.currentItem?.accessLog()?.extendedLogData().flatMap { String(data: $0, encoding: .utf8) } ?? ""
            log("access log events \(events.count) type \(e?.playbackType ?? "-") watched \(String(format: "%.1f", e?.durationWatched ?? 0)) uri \(e?.uri?.hasSuffix("tracks.mp4") == true) bytes \((e?.numberOfBytesTransferred ?? 0) > 0) bitrate \((e?.indicatedBitrate ?? 0) > 0) startup \((e?.startupTime ?? 0) > 0) extended \(ext.hasPrefix("#Version: 1.0"))")
            log("rate reasons \(reasons.joined(separator: ","))")
            log("frames \(colors.joined(separator: ","))")
            log("outputs done")
        }
    }

    @objc func frame() {
        let t = video.itemTime(forHostTime: CACurrentMediaTime())
        guard video.hasNewPixelBuffer(forItemTime: t), let pb = video.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), row = CVPixelBufferGetBytesPerRow(pb)
        let px = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self) + (h / 2) * row + (w / 2) * 4
        let (b, g, r) = (px[0], px[1], px[2])
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        let c = r > 200 && g < 60 ? "red" : g > 200 && r < 60 ? "green" : b > 200 && r < 60 ? "blue" : "other"
        if colors.last != c { colors.append(c) }
    }

    func legibleOutput(_ output: AVPlayerItemLegibleOutput, didOutputAttributedStrings strings: [NSAttributedString],
                       nativeSampleBuffers nativeSamples: [Any], forItemTime itemTime: CMTime) {
        log("legible \(String(format: "%.1f", itemTime.seconds)) [\(strings.map(\.string).joined(separator: "|"))]")
    }
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
        for g in groups {
            let items = g.items.map { "\($0.identifier?.rawValue ?? "-")=\($0.stringValue ?? "data")" }.joined(separator: ",")
            log("metadata \(String(format: "%.1f", g.timeRange.start.seconds)) \(items)")
        }
    }
    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) { log("video output media data will change") }
}
