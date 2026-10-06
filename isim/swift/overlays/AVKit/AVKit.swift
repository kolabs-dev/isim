// isim AVKit (subset): AVPlayerViewController with iOS 17-style playback controls (play/pause, 10 s skip,
// scrubber, elapsed/remaining time, mute, close when presented, auto-hiding), SwiftUI VideoPlayer, and stubs
// for picture in picture and AirPlay route picking (unsupported on isim). Self-authored; the glyphs are drawn
// with paths (no SF Symbols artwork).
@_exported import AVFoundation
import UIKit
import SwiftUI

// MARK: - glyphs

/// A control that draws one playback glyph in white (optionally on a dark round platter).
final class _AVGlyphButton: UIControl {
    enum Glyph { case play, pause, skipBack, skipForward, close, speaker, speakerMuted }
    var glyph: Glyph { didSet { setNeedsDisplay() } }
    var platter = false
    let caption = UILabel()
    init(_ g: Glyph) {
        glyph = g; super.init(frame: .zero); backgroundColor = .clear
        if g == .skipBack || g == .skipForward {
            caption.text = "10"; caption.textColor = .white; caption.textAlignment = .center
            caption.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            caption.isUserInteractionEnabled = false
            addSubview(caption)
        }
    }
    override func layoutSubviews() { super.layoutSubviews(); caption.frame = bounds.offsetBy(dx: 0, dy: 1) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let b = bounds
        if platter {
            UIColor(white: 0.1, alpha: 0.55).setFill()
            UIBezierPath(roundedRect: b, cornerRadius: min(b.width, b.height) / 2).fill()
        }
        UIColor.white.withAlphaComponent(isHighlighted ? 0.5 : 1).setFill()
        UIColor.white.withAlphaComponent(isHighlighted ? 0.5 : 1).setStroke()
        let s = min(b.width, b.height), cx = b.midX, cy = b.midY
        switch glyph {
        case .play:
            let p = UIBezierPath()
            let h = s * 0.62, w = h * 0.86
            p.move(to: CGPoint(x: cx - w * 0.38, y: cy - h / 2))
            p.addLine(to: CGPoint(x: cx + w * 0.62, y: cy))
            p.addLine(to: CGPoint(x: cx - w * 0.38, y: cy + h / 2))
            p.close(); p.fill()
        case .pause:
            let h = s * 0.58, w = s * 0.16, gap = s * 0.14
            UIBezierPath(roundedRect: CGRect(x: cx - gap / 2 - w, y: cy - h / 2, width: w, height: h), cornerRadius: w * 0.2).fill()
            UIBezierPath(roundedRect: CGRect(x: cx + gap / 2, y: cy - h / 2, width: w, height: h), cornerRadius: w * 0.2).fill()
        case .skipBack, .skipForward:
            let fwd = glyph == .skipForward, r = s * 0.38
            let ring = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: r, startAngle: fwd ? -.pi / 2 : -.pi / 2,
                                    endAngle: fwd ? 1.5 * .pi - 0.6 : -2.5 * .pi + 0.6, clockwise: fwd)
            ring.lineWidth = s * 0.07; ring.stroke()
            let tip = UIBezierPath(), ty = cy - r, tx = cx + (fwd ? -s * 0.02 : s * 0.02)
            tip.move(to: CGPoint(x: tx + (fwd ? s * 0.16 : -s * 0.16), y: ty))
            tip.addLine(to: CGPoint(x: tx, y: ty - s * 0.12))
            tip.addLine(to: CGPoint(x: tx, y: ty + s * 0.12))
            tip.close(); tip.fill()
        case .close:
            let p = UIBezierPath(), d = s * 0.18
            p.move(to: CGPoint(x: cx - d, y: cy - d)); p.addLine(to: CGPoint(x: cx + d, y: cy + d))
            p.move(to: CGPoint(x: cx + d, y: cy - d)); p.addLine(to: CGPoint(x: cx - d, y: cy + d))
            p.lineWidth = s * 0.08; p.stroke()
        case .speaker, .speakerMuted:
            let p = UIBezierPath(), u = s * 0.1
            p.move(to: CGPoint(x: cx - 3.2 * u, y: cy - 1.2 * u)); p.addLine(to: CGPoint(x: cx - 1.8 * u, y: cy - 1.2 * u))
            p.addLine(to: CGPoint(x: cx, y: cy - 3 * u)); p.addLine(to: CGPoint(x: cx, y: cy + 3 * u))
            p.addLine(to: CGPoint(x: cx - 1.8 * u, y: cy + 1.2 * u)); p.addLine(to: CGPoint(x: cx - 3.2 * u, y: cy + 1.2 * u)); p.close(); p.fill()
            let w = UIBezierPath()
            if glyph == .speaker {
                w.addArc(withCenter: CGPoint(x: cx, y: cy), radius: 1.6 * u, startAngle: -0.8, endAngle: 0.8, clockwise: true)
                w.move(to: CGPoint(x: cx + 2.8 * u * cos(-0.8), y: cy + 2.8 * u * sin(-0.8)))
                w.addArc(withCenter: CGPoint(x: cx, y: cy), radius: 2.8 * u, startAngle: -0.8, endAngle: 0.8, clockwise: true)
            } else {
                w.move(to: CGPoint(x: cx + 1.2 * u, y: cy - 1.4 * u)); w.addLine(to: CGPoint(x: cx + 3.6 * u, y: cy + 1.4 * u))
                w.move(to: CGPoint(x: cx + 3.6 * u, y: cy - 1.4 * u)); w.addLine(to: CGPoint(x: cx + 1.2 * u, y: cy + 1.4 * u))
            }
            w.lineWidth = u * 0.7; w.stroke()
        }
    }
    override var isHighlighted: Bool { didSet { setNeedsDisplay() } }
}

/// The scrubber: a thin rounded track (white fill = elapsed) that follows touches anywhere on it.
final class _AVScrubber: UIControl {
    var value: Double = 0 { didSet { setNeedsDisplay() } }       // 0...1
    private(set) var isScrubbing = false
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let h: CGFloat = isScrubbing ? 12 : 7
        let track = CGRect(x: 0, y: bounds.midY - h / 2, width: bounds.width, height: h)
        UIColor(white: 1, alpha: 0.3).setFill()
        UIBezierPath(roundedRect: track, cornerRadius: h / 2).fill()
        UIColor.white.setFill()
        var fill = track; fill.size.width = max(h, track.width * CGFloat(min(1, max(0, value))))
        UIBezierPath(roundedRect: fill, cornerRadius: h / 2).fill()
    }
    func update(_ t: UITouch) {
        value = Double(min(1, max(0, t.location(in: self).x / max(1, bounds.width))))
        sendActions(for: .valueChanged)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        isScrubbing = true; sendActions(for: .editingDidBegin); update(t)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { if let t = touches.first { update(t) } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { update(t) }
        isScrubbing = false; setNeedsDisplay(); sendActions(for: .editingDidEnd)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { isScrubbing = false; setNeedsDisplay(); sendActions(for: .editingDidEnd) }
}

/// A view whose layer is the AVPlayerLayer.
final class _AVPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - AVPlayerViewController

@objc public protocol AVPlayerViewControllerDelegate: NSObjectProtocol {
    @objc optional func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: AnyObject)
    @objc optional func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: AnyObject)
    @objc optional func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController)
    @objc optional func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController)
}

open class AVPlayerViewController: UIViewController {
    open var player: AVPlayer? { didSet { if oldValue !== player { _rebind(old: oldValue) } } }
    open var showsPlaybackControls = true { didSet { if isViewLoaded { _controls.isHidden = !showsPlaybackControls } } }
    open var videoGravity: AVLayerVideoGravity = .resizeAspect { didSet { if isViewLoaded { _playerView.playerLayer.videoGravity = videoGravity } } }
    open weak var delegate: AVPlayerViewControllerDelegate?
    open var entersFullScreenWhenPlaybackBegins = false
    open var exitsFullScreenWhenPlaybackEnds = false
    open var allowsPictureInPicturePlayback = true
    open var canStartPictureInPictureAutomaticallyFromInline = false
    open var updatesNowPlayingInfoCenter = true
    open var requiresLinearPlayback = false
    open var showsTimecodes = false
    open var allowsVideoFrameAnalysis = false
    open var speeds: [AVPlaybackSpeed] = AVPlaybackSpeed.systemDefaultSpeeds
    open private(set) var selectedSpeed: AVPlaybackSpeed?
    open var isReadyForDisplay: Bool { isViewLoaded && _playerView.playerLayer.isReadyForDisplay }
    open var videoBounds: CGRect { isViewLoaded ? _playerView.playerLayer.videoRect : .zero }
    open private(set) var contentOverlayView: UIView?
    open var customOverlayViewController: UIViewController?
    open func selectSpeed(_ speed: AVPlaybackSpeed) { selectedSpeed = speed; if player?.rate ?? 0 > 0 { player?.rate = speed.rate } }

    let _playerView = _AVPlayerView()
    let _controls = UIView()
    let _play = _AVGlyphButton(.play)
    let _back = _AVGlyphButton(.skipBack)
    let _fwd = _AVGlyphButton(.skipForward)
    let _close = _AVGlyphButton(.close)
    let _mute = _AVGlyphButton(.speaker)
    let _scrubber = _AVScrubber(frame: .zero)
    let _elapsed = UILabel()
    let _remaining = UILabel()
    var _timeObserver: Any?
    var _statusObservation: NSKeyValueObservation?
    var _hideGeneration = 0
    var _controlsVisible = true

    open override func loadView() {
        let v = UIView()
        v.backgroundColor = .black
        view = v
    }
    open override func viewDidLoad() {
        super.viewDidLoad()
        _playerView.backgroundColor = .black
        _playerView.playerLayer.videoGravity = videoGravity
        _playerView.accessibilityIdentifier = "avkit-video"
        view.addSubview(_playerView)
        let overlay = UIView()
        overlay.isUserInteractionEnabled = false
        contentOverlayView = overlay
        view.addSubview(overlay)
        view.addSubview(_controls)
        _controls.isHidden = !showsPlaybackControls
        for (b, id, label) in [(_play, "avkit-play", "Play"), (_back, "avkit-skip-back", "Skip Back 10 Seconds"), (_fwd, "avkit-skip-forward", "Skip Forward 10 Seconds"),
                               (_close, "avkit-close", "Close"), (_mute, "avkit-mute", "Mute")] {
            b.accessibilityIdentifier = id; b.accessibilityLabel = label
            _controls.addSubview(b)
        }
        _close.platter = true; _mute.platter = true
        _play.addTarget(self, action: #selector(_togglePlay), for: .touchUpInside)
        _back.addTarget(self, action: #selector(_skipBack), for: .touchUpInside)
        _fwd.addTarget(self, action: #selector(_skipForward), for: .touchUpInside)
        _close.addTarget(self, action: #selector(_closeTapped), for: .touchUpInside)
        _mute.addTarget(self, action: #selector(_muteTapped), for: .touchUpInside)
        _scrubber.accessibilityIdentifier = "avkit-scrubber"
        _scrubber.addTarget(self, action: #selector(_scrubbed), for: .valueChanged)
        _scrubber.addTarget(self, action: #selector(_scrubEnded), for: .editingDidEnd)
        _controls.addSubview(_scrubber)
        for (l, id, align) in [(_elapsed, "avkit-elapsed", NSTextAlignment.left), (_remaining, "avkit-remaining", NSTextAlignment.right)] {
            l.accessibilityIdentifier = id
            l.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            l.textColor = UIColor(white: 1, alpha: 0.85)
            l.textAlignment = align
            _controls.addSubview(l)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(_videoTapped))
        _playerView.addGestureRecognizer(tap)
        _rebind(old: nil)
    }
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds, safe = view.safeAreaInsets
        _playerView.frame = b
        contentOverlayView?.frame = videoBounds == .zero ? b : videoBounds
        _controls.frame = b
        let cy = b.midY
        _play.frame = CGRect(x: b.midX - 34, y: cy - 34, width: 68, height: 68)
        _back.frame = CGRect(x: b.midX - 34 - 96, y: cy - 24, width: 48, height: 48)
        _fwd.frame = CGRect(x: b.midX + 34 + 48, y: cy - 24, width: 48, height: 48)
        let top = max(safe.top, 8) + 6
        _close.frame = CGRect(x: 16, y: top, width: 34, height: 34)
        _close.isHidden = presentingViewController == nil
        _mute.frame = CGRect(x: b.width - 50, y: top, width: 34, height: 34)
        let bottom = b.height - max(safe.bottom, 12) - 8
        _elapsed.frame = CGRect(x: 18, y: bottom - 18, width: 80, height: 18)
        _remaining.frame = CGRect(x: b.width - 98, y: bottom - 18, width: 80, height: 18)
        _scrubber.frame = CGRect(x: 18, y: bottom - 46, width: b.width - 36, height: 26)
    }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _refresh()
    }

    func _rebind(old: AVPlayer?) {
        if let o = _timeObserver { old?.removeTimeObserver(o); _timeObserver = nil }
        _statusObservation = nil
        guard isViewLoaded else { return }
        _playerView.playerLayer.player = player
        if let p = player {
            _timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?._refresh() }
            }
            _statusObservation = p.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?._refresh(); self?._scheduleHide() }
            }
        }
        _refresh()
    }
    static func _format(_ s: Double, up: Bool = false) -> String {
        guard s.isFinite else { return "--:--" }
        let t = Int(max(0, s - (up ? 0.001 : 0)).rounded(up ? .up : .down))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
    func _refresh() {
        guard isViewLoaded else { return }
        let playing = (player?.rate ?? 0) != 0
        _play.glyph = playing ? .pause : .play
        _play.accessibilityLabel = playing ? "Pause" : "Play"
        _mute.glyph = player?.isMuted == true ? .speakerMuted : .speaker
        let t = player?.currentTime().seconds ?? 0
        let d = player?.currentItem?.duration.seconds ?? .nan
        _elapsed.text = Self._format(t)
        _remaining.text = d.isFinite ? "-" + Self._format(max(0, d - t), up: true) : "--:--"
        if !_scrubber.isScrubbing { _scrubber.value = d.isFinite && d > 0 ? t / d : 0 }
        contentOverlayView?.frame = videoBounds == .zero ? view.bounds : videoBounds
    }
    func _scheduleHide() {
        _hideGeneration += 1
        let g = _hideGeneration
        guard player?.timeControlStatus == .playing else { _setControls(true); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self._hideGeneration == g, self.player?.timeControlStatus == .playing, !self._scrubber.isScrubbing else { return }
            self._setControls(false)
        }
    }
    func _setControls(_ visible: Bool) {
        guard visible != _controlsVisible else { return }
        _controlsVisible = visible
        UIView.animate(withDuration: 0.25) { self._controls.alpha = visible ? 1 : 0 }
    }
    @objc func _videoTapped() {
        _setControls(!_controlsVisible)
        if _controlsVisible { _scheduleHide() }
    }
    @objc func _togglePlay() {
        guard let p = player else { return }
        if p.rate != 0 { p.pause() }
        else {
            if let d = p.currentItem?.duration.seconds, d.isFinite, p.currentTime().seconds >= d - 0.05 { p.seek(to: .zero) }
            p.play()
            if let s = selectedSpeed { p.rate = s.rate }
        }
        _refresh(); _scheduleHide()
    }
    func _skip(_ by: Double) {
        guard let p = player else { return }
        var t = p.currentTime().seconds + by
        if let d = p.currentItem?.duration.seconds, d.isFinite { t = min(t, d) }
        p.seek(to: CMTime(seconds: max(0, t), preferredTimescale: 600))
        _refresh(); _scheduleHide()
    }
    @objc func _skipBack() { _skip(-10) }
    @objc func _skipForward() { _skip(10) }
    @objc func _scrubbed() {
        guard let p = player, let d = p.currentItem?.duration.seconds, d.isFinite else { return }
        p.seek(to: CMTime(seconds: d * _scrubber.value, preferredTimescale: 600))
        _elapsed.text = Self._format(d * _scrubber.value)
        _remaining.text = "-" + Self._format(d * (1 - _scrubber.value), up: true)
    }
    @objc func _scrubEnded() { _refresh(); _scheduleHide() }
    @objc func _closeTapped() { player?.pause(); dismiss(animated: true) }
    @objc func _muteTapped() { player?.isMuted.toggle(); _refresh() }
}

public struct AVPlaybackSpeed: Hashable, Sendable {
    public let rate: Float
    public let localizedName: String
    public let localizedNumericName: String
    public init(rate: Float, localizedName: String) {
        self.rate = rate; self.localizedName = localizedName
        localizedNumericName = rate == rate.rounded() ? "\(Int(rate))×" : "\(rate)×"
    }
    public static let systemDefaultSpeeds = [0.5, 1, 1.25, 1.5, 2].map { AVPlaybackSpeed(rate: Float($0), localizedName: $0 == 1 ? "Normal" : "\($0)×") }
}

// MARK: - picture in picture, routes (not available on isim)

open class AVPictureInPictureController: NSObject {
    public static func isPictureInPictureSupported() -> Bool { false }
    public let playerLayer: AVPlayerLayer
    open weak var delegate: AnyObject?
    open var isPictureInPictureActive: Bool { false }
    open var isPictureInPicturePossible: Bool { false }
    open var canStartPictureInPictureAutomaticallyFromInline = false
    public init?(playerLayer: AVPlayerLayer) { self.playerLayer = playerLayer; super.init() }
    open func startPictureInPicture() { NSLog("isim AVKit: picture in picture is not available") }
    open func stopPictureInPicture() {}
}
open class AVRoutePickerView: UIView {
    open var activeTintColor: UIColor? = nil
    open var prioritizesVideoDevices = false
}

// MARK: - SwiftUI VideoPlayer

struct _AVPlayerVCView: UIViewControllerRepresentable {
    let player: AVPlayer?
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        return vc
    }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
    }
}

/// SwiftUI's video player: the AVPlayerViewController controls, with an optional overlay above the video
/// (isim: the overlay does not take touches, so the controls stay usable).
public struct VideoPlayer<VideoOverlay: View>: View {
    let player: AVPlayer?
    let overlay: VideoOverlay
    public init(player: AVPlayer?) where VideoOverlay == EmptyView { self.player = player; overlay = EmptyView() }
    public init(player: AVPlayer?, @ViewBuilder videoOverlay: () -> VideoOverlay) { self.player = player; overlay = videoOverlay() }
    public var body: some View {
        ZStack {
            _AVPlayerVCView(player: player)
            overlay.allowsHitTesting(false)
        }
    }
}
