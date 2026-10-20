// isim AVKit: AVPlayerViewController with iOS 17-style playback controls (play/pause, 10 s skip, scrubber,
// elapsed/remaining time, mute, close when presented, full screen when embedded, Picture in Picture, AirPlay,
// playback speed menu, auto-hiding), AVPictureInPictureController, AVRoutePickerView and SwiftUI VideoPlayer.
// Self-authored; the glyphs are isim's own drawings (no SF Symbols artwork).
// Picture in Picture (adapted): on a booted device the system (isim's shell) floats the video over everything —
// the app, the home screen, other apps — decoding it from the player's media itself while the app's player keeps
// the sound and the timeline; `isim run` (no system UI) floats it in a window over the app. AirPlay: the route
// picker of AVFoundation (simulated routes: the device, headphones when plugged in, an AirPlay speaker).
@_exported import AVFoundation
import UIKit
import SwiftUI
import isim_host

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
    @objc optional func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController)
    @objc optional func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController)
    @objc optional func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error)
    @objc optional func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool
    @objc optional func playerViewController(_ playerViewController: AVPlayerViewController,
                                             restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
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
    open var speeds: [AVPlaybackSpeed] = AVPlaybackSpeed.systemDefaultSpeeds { didSet { if isViewLoaded { _updateSpeedMenu() } } }
    open private(set) var selectedSpeed: AVPlaybackSpeed?
    open var isReadyForDisplay: Bool { isViewLoaded && _playerView.playerLayer.isReadyForDisplay }
    open var videoBounds: CGRect { isViewLoaded ? _playerView.playerLayer.videoRect : .zero }
    open private(set) var contentOverlayView: UIView?
    open var customOverlayViewController: UIViewController?
    open func selectSpeed(_ speed: AVPlaybackSpeed) {
        selectedSpeed = speed
        player?.defaultRate = speed.rate
        if player?.rate ?? 0 > 0 { player?.rate = speed.rate }
        if isViewLoaded { _updateSpeedMenu() }
    }

    let _playerView = _AVPlayerView()
    let _controls = UIView()
    let _play = _AVGlyphButton(.play)
    let _back = _AVGlyphButton(.skipBack)
    let _fwd = _AVGlyphButton(.skipForward)
    let _close = _AVGlyphButton(.close)
    let _mute = _AVGlyphButton(.speaker)
    let _scrubber = _AVScrubber(frame: .zero)
    let _pipButton = UIButton(type: .custom)
    let _airplay = UIButton(type: .custom)
    let _fullScreen = UIButton(type: .custom)
    let _speed = UIButton(type: .system)
    var _pip: AVPictureInPictureController?
    var _pipDelegate: _AVPlayerVCPiPDelegate?
    var _fullScreenChild: AVPlayerViewController?
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
        overrideUserInterfaceStyle = .dark                                  // the playback chrome is always dark on iOS
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
        for (b, id, label, symbol) in [(_pipButton, "avkit-pip", "Picture in Picture", "pip.enter"), (_airplay, "avkit-airplay", "AirPlay", "airplayvideo"),
                                       (_fullScreen, "avkit-fullscreen", "Full Screen", "arrow.up.left.and.arrow.down.right")] {
            b.accessibilityIdentifier = id; b.accessibilityLabel = label
            b.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
            b.tintColor = .white
            b.backgroundColor = UIColor(white: 0.1, alpha: 0.55)
            b.layer.cornerRadius = 17
            _controls.addSubview(b)
        }
        _pipButton.addTarget(self, action: #selector(_pipTapped), for: .touchUpInside)
        _airplay.addTarget(self, action: #selector(_airplayTapped), for: .touchUpInside)
        _fullScreen.addTarget(self, action: #selector(_fullScreenTapped), for: .touchUpInside)
        _speed.accessibilityIdentifier = "avkit-speed"; _speed.accessibilityLabel = "Playback Speed"
        _speed.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        _speed.tintColor = .white
        _speed.backgroundColor = UIColor(white: 0.1, alpha: 0.55)
        _speed.layer.cornerRadius = 12
        _speed.showsMenuAsPrimaryAction = true
        _controls.addSubview(_speed)
        _updateSpeedMenu()
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
        let presented = presentingViewController != nil
        _close.frame = CGRect(x: 16, y: top, width: 34, height: 34)
        _close.isHidden = !presented
        _fullScreen.frame = CGRect(x: 16, y: top, width: 34, height: 34)
        _fullScreen.isHidden = presented
        _pipButton.frame = CGRect(x: 16 + 42, y: top, width: 34, height: 34)
        _pipButton.isHidden = !allowsPictureInPicturePlayback || !AVPictureInPictureController.isPictureInPictureSupported()
        _mute.frame = CGRect(x: b.width - 50, y: top, width: 34, height: 34)
        _airplay.frame = CGRect(x: b.width - 50 - 42, y: top, width: 34, height: 34)
        let bottom = b.height - max(safe.bottom, 12) - 8
        _elapsed.frame = CGRect(x: 18, y: bottom - 18, width: 80, height: 18)
        _remaining.frame = CGRect(x: b.width - 98, y: bottom - 18, width: 80, height: 18)
        _scrubber.frame = CGRect(x: 18, y: bottom - 46, width: b.width - 36, height: 26)
        _speed.frame = CGRect(x: b.width - 18 - 52, y: bottom - 46 - 34, width: 52, height: 24)
        _speed.isHidden = speeds.isEmpty
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

    // MARK: playback speed, AirPlay, full screen, Picture in Picture
    func _updateSpeedMenu() {
        let current = selectedSpeed?.rate ?? 1
        _speed.setTitle(AVPlaybackSpeed(rate: current, localizedName: "").localizedNumericName, for: .normal)
        let actions = speeds.map { sp in
            UIAction(title: sp.localizedNumericName, state: sp.rate == current ? .on : .off) { [weak self] _ in
                MainActor.assumeIsolated { self?.selectSpeed(sp); NSLog("isim AVKit: playback speed %@", sp.localizedNumericName) }
            }
        }
        _speed.menu = UIMenu(title: "Playback Speed", children: actions)
    }
    @objc func _airplayTapped() { AVAudioSession._isimShowRoutePicker(from: _airplay) }
    @objc func _fullScreenTapped() {
        let full = AVPlayerViewController()
        full.player = player
        full.speeds = speeds
        if let s = selectedSpeed { full.selectSpeed(s) }
        full.modalPresentationStyle = .fullScreen
        full._fullScreenParent = self
        _fullScreenChild = full
        delegate?.playerViewController?(self, willBeginFullScreenPresentationWithAnimationCoordinator: NSObject())
        NSLog("isim AVKit: full screen")
        present(full, animated: true)
    }
    weak var _fullScreenParent: AVPlayerViewController?
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let parent = _fullScreenParent, presentingViewController == nil {
            parent.delegate?.playerViewController?(parent, willEndFullScreenPresentationWithAnimationCoordinator: NSObject())
            parent._fullScreenChild = nil
            _fullScreenParent = nil
        }
    }
    @objc func _pipTapped() {
        if _pip == nil {
            let pip = AVPictureInPictureController(playerLayer: _playerView.playerLayer)
            let d = _AVPlayerVCPiPDelegate(self)
            pip?.delegate = d
            _pip = pip; _pipDelegate = d
        }
        guard let pip = _pip else { return }
        if pip.isPictureInPictureActive { pip.stopPictureInPicture() } else { pip.startPictureInPicture() }
    }
}

/// AVPlayerViewController's own Picture in Picture: the controller is dismissed while the video floats, and comes
/// back through the delegate when the user returns to the app.
final class _AVPlayerVCPiPDelegate: NSObject, AVPictureInPictureControllerDelegate {
    weak var vc: AVPlayerViewController?
    var presenter: UIViewController?
    init(_ vc: AVPlayerViewController) { self.vc = vc }
    func pictureInPictureControllerWillStartPictureInPicture(_ c: AVPictureInPictureController) {
        guard let vc else { return }
        vc.delegate?.playerViewControllerWillStartPictureInPicture?(vc)
    }
    func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
        guard let vc else { return }
        // Like iOS, the player is already off screen when the delegate hears that Picture in Picture started.
        if vc.presentingViewController != nil, vc.delegate?.playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart?(vc) ?? true {
            presenter = vc.presentingViewController
            vc.dismiss(animated: true) { [weak vc] in
                if let vc { vc.delegate?.playerViewControllerDidStartPictureInPicture?(vc) }
            }
        } else {
            vc.delegate?.playerViewControllerDidStartPictureInPicture?(vc)
        }
    }
    func pictureInPictureController(_ c: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        guard let vc else { return }
        vc.delegate?.playerViewController?(vc, failedToStartPictureInPictureWithError: error)
    }
    func pictureInPictureControllerWillStopPictureInPicture(_ c: AVPictureInPictureController) {
        guard let vc else { return }
        vc.delegate?.playerViewControllerWillStopPictureInPicture?(vc)
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        guard let vc else { return }
        vc.delegate?.playerViewControllerDidStopPictureInPicture?(vc)
    }
    func pictureInPictureController(_ c: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler done: @escaping (Bool) -> Void) {
        guard let vc else { done(false); return }
        if let d = vc.delegate, d.responds(to: #selector(AVPlayerViewControllerDelegate.playerViewController(_:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:))) {
            d.playerViewController?(vc, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: done)
        } else if let p = presenter, vc.presentingViewController == nil {
            p.present(vc, animated: true) { done(true) }
        } else { done(true) }
        presenter = nil
    }
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

// MARK: - Picture in Picture

@objc public protocol AVPictureInPictureControllerDelegate: NSObjectProtocol {
    @objc optional func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController)
    @objc optional func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController)
    @objc optional func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error)
    @objc optional func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController)
    @objc optional func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController)
    @objc optional func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                   restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
}

/// Playback of sample-buffer content in Picture in Picture: the app plays, pauses and skips its own renderers.
public protocol AVPictureInPictureSampleBufferPlaybackDelegate: NSObjectProtocol {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool)
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions)
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void)
    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool
}
extension AVPictureInPictureSampleBufferPlaybackDelegate {
    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }
}

open class AVPictureInPictureController: NSObject {
    /// isim: Picture in Picture floats AVPlayerLayer content (in the system window) or AVSampleBufferDisplayLayer content
    /// (in a window over the app: the system window plays URLs)
    public static func isPictureInPictureSupported() -> Bool { true }
    public final class ContentSource: NSObject {
        public let playerLayer: AVPlayerLayer?
        public let sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
        public private(set) weak var sampleBufferPlaybackDelegate: AVPictureInPictureSampleBufferPlaybackDelegate?
        public init(playerLayer: AVPlayerLayer) { self.playerLayer = playerLayer; sampleBufferDisplayLayer = nil }
        public init(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer, playbackDelegate: AVPictureInPictureSampleBufferPlaybackDelegate) {
            playerLayer = nil; self.sampleBufferDisplayLayer = sampleBufferDisplayLayer; sampleBufferPlaybackDelegate = playbackDelegate
        }
    }
    open class var pictureInPictureButtonStartImage: UIImage { UIImage(systemName: "pip.enter") ?? UIImage() }
    open class var pictureInPictureButtonStopImage: UIImage { UIImage(systemName: "pip.exit") ?? UIImage() }
    public let playerLayer: AVPlayerLayer
    open weak var delegate: AnyObject?
    open var contentSource: ContentSource?
    open var canStartPictureInPictureAutomaticallyFromInline = false { didSet { _watchBackground() } }
    open var requiresLinearPlayback = false
    @objc open private(set) var isPictureInPictureActive = false
    open var isPictureInPictureSuspended: Bool { false }
    /// the player has a video ready to float (sample-buffer content: the layer shows a frame)
    @objc open var isPictureInPicturePossible: Bool {
        if let l = contentSource?.sampleBufferDisplayLayer { return l.sampleBufferRenderer._isimImage != nil && contentSource?.sampleBufferPlaybackDelegate != nil }
        return playerLayer.player?._isimMedia != nil
    }
    public init?(playerLayer: AVPlayerLayer) { self.playerLayer = playerLayer; contentSource = ContentSource(playerLayer: playerLayer); super.init() }
    public init(contentSource: ContentSource) {
        self.contentSource = contentSource
        playerLayer = contentSource.playerLayer ?? AVPlayerLayer()
        super.init()
    }
    deinit { if let o = _eventObserver { NotificationCenter.default.removeObserver(o) }; if let o = _bgObserver { NotificationCenter.default.removeObserver(o) }; _timer?.invalidate() }

    var _d: AVPictureInPictureControllerDelegate? { delegate as? AVPictureInPictureControllerDelegate }
    var _eventObserver: NSObjectProtocol?
    var _bgObserver: NSObjectProtocol?
    var _timer: Timer?
    var _sent = (time: 0.0, rate: Float(0), at: 0.0)
    var _window: _PiPWindow?
    var _shell: Bool { isim_shell_present() != 0 }

    open func startPictureInPicture() {
        guard !isPictureInPictureActive else { return }
        if let layer = contentSource?.sampleBufferDisplayLayer {
            guard isPictureInPicturePossible else {
                let e = NSError(domain: "AVKitErrorDomain", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Picture in Picture is not possible: the layer shows no video"])
                _d?.pictureInPictureController?(self, failedToStartPictureInPictureWithError: e)
                return
            }
            _d?.pictureInPictureControllerWillStartPictureInPicture?(self)
            let w = _PiPWindow(sampleBufferLayer: layer, owner: self)
            w.show()
            _window = w
            if let d = contentSource?.sampleBufferPlaybackDelegate {
                let px = w.bounds.size, scale = UIScreen.main.scale
                d.pictureInPictureController(self, didTransitionToRenderSize: CMVideoDimensions(width: Int32(px.width * scale), height: Int32(px.height * scale)))
            }
            layer._isimPictureInPicture = true
            _began()
            return
        }
        guard let player = playerLayer.player, let media = player._isimMedia else {
            let e = NSError(domain: "AVKitErrorDomain", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Picture in Picture is not possible: the player has no video"])
            _d?.pictureInPictureController?(self, failedToStartPictureInPictureWithError: e)
            return
        }
        _d?.pictureInPictureControllerWillStartPictureInPicture?(self)
        if _shell {
            let title = (player.currentItem?.asset as? AVURLAsset)?.url.deletingPathExtension().lastPathComponent ?? ""
            let t = player.currentTime().seconds
            isim_shell_request(40, "pip-start", media.url + "\u{1f}" + title,
                               String(format: "%.3f %.3f %.0f %.0f %.3f", t.isFinite ? t : 0, player.rate, media.width, media.height, media.fps))
            _sent = (t.isFinite ? t : 0, player.rate, isim_time())
            _timer = Timer._isimScheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?._sync() } }
        } else {
            let w = _PiPWindow(player: player, owner: self)
            w.show()
            _window = w
        }
        playerLayer._isimPictureInPicture = true
        _began()
    }
    func _began() {
        _eventObserver = NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { [weak self] n in
            guard let t = n.object as? String, t.hasPrefix("pip ") else { return }
            MainActor.assumeIsolated { self?._event(String(t.dropFirst(4))) }
        }
        willChangeValue(forKey: "isPictureInPictureActive"); isPictureInPictureActive = true; didChangeValue(forKey: "isPictureInPictureActive")
        NSLog("isim AVKit: Picture in Picture started")
        DispatchQueue.main.async { self._d?.pictureInPictureControllerDidStartPictureInPicture?(self) }
    }
    open func stopPictureInPicture() { _stop(restore: false) }
    /// the app's sample-buffer playback changed (playing, paused, its time range): the controls follow
    open func invalidatePlaybackState() { MainActor.assumeIsolated { _sync(force: true); _window?.refresh() } }
    /// keeps the system's floating video in step with the app's player (play, pause, seek, rate)
    @MainActor func _sync(force: Bool = false) {
        guard _shell, isPictureInPictureActive, let p = playerLayer.player else { return }
        let t = p.currentTime().seconds, r = p.rate
        let predicted = _sent.time + (isim_time() - _sent.at) * Double(_sent.rate)
        guard force || r != _sent.rate || abs(t - predicted) > 0.3 else { return }
        _sent = (t.isFinite ? t : 0, r, isim_time())
        isim_shell_request(40, "pip-update", "", String(format: "%.3f %.3f", _sent.time, r))
    }
    @MainActor func _event(_ e: String) {
        guard isPictureInPictureActive else { return }
        if let d = contentSource?.sampleBufferPlaybackDelegate, contentSource?.sampleBufferDisplayLayer != nil {
            NSLog("isim AVKit: Picture in Picture %@", e)
            if e == "play" || e == "pause" { d.pictureInPictureController(self, setPlaying: e == "play") }
            else if e.hasPrefix("skip "), let s = Double(e.dropFirst(5)) {
                d.pictureInPictureController(self, skipByInterval: CMTime(seconds: s, preferredTimescale: 600)) {}
            } else if e == "close" { d.pictureInPictureController(self, setPlaying: false); _stop(restore: false) }
            else if e == "restore" { _stop(restore: true) }
            _window?.refresh()
            return
        }
        guard let p = playerLayer.player else { return }
        NSLog("isim AVKit: Picture in Picture %@", e)
        if e == "play" { p.play() }
        else if e == "pause" { p.pause() }
        else if e.hasPrefix("skip "), let d = Double(e.dropFirst(5)) {
            var t = p.currentTime().seconds + d
            if let dur = p.currentItem?.duration.seconds, dur.isFinite { t = min(t, dur) }
            p.seek(to: CMTime(seconds: max(0, t), preferredTimescale: 600))
        } else if e == "close" { p.pause(); _stop(restore: false) }
        else if e == "restore" { _stop(restore: true) }
        _window?.refresh()
        _sync(force: true)
    }
    func _stop(restore: Bool) {
        guard isPictureInPictureActive else { return }
        let finish = { [self] in
            _d?.pictureInPictureControllerWillStopPictureInPicture?(self)
            if _shell { isim_shell_request(40, "pip-stop", "", "") }
            _timer?.invalidate(); _timer = nil
            _window?.close(); _window = nil
            if let o = _eventObserver { NotificationCenter.default.removeObserver(o); _eventObserver = nil }
            playerLayer._isimPictureInPicture = false
            contentSource?.sampleBufferDisplayLayer?._isimPictureInPicture = false
            willChangeValue(forKey: "isPictureInPictureActive"); isPictureInPictureActive = false; didChangeValue(forKey: "isPictureInPictureActive")
            NSLog("isim AVKit: Picture in Picture stopped%@", restore ? " (restored)" : "")
            _d?.pictureInPictureControllerDidStopPictureInPicture?(self)
        }
        if restore, let d = _d, d.responds(to: #selector(AVPictureInPictureControllerDelegate.pictureInPictureController(_:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:))) {
            d.pictureInPictureController?(self, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: { _ in DispatchQueue.main.async(execute: finish) })
        } else { finish() }
    }
    /// canStartPictureInPictureAutomaticallyFromInline: a playing video floats when the app goes to the background
    func _watchBackground() {
        guard canStartPictureInPictureAutomaticallyFromInline, _bgObserver == nil else { return }
        _bgObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isPictureInPictureActive, self.canStartPictureInPictureAutomaticallyFromInline,
                      (self.playerLayer.player?.rate ?? 0) > 0, UIApplication.shared.applicationState == .active else { return }
                NSLog("isim AVKit: Picture in Picture starts automatically")
                self.startPictureInPicture()
            }
        }
    }
}

/// `isim run` (no system UI): the floating video in a window over the app, with the system's controls.
final class _PiPWindow: UIWindow {
    let player: AVPlayer?
    weak var sampleLayer: AVSampleBufferDisplayLayer?
    weak var owner: AVPictureInPictureController?
    let video: UIView
    let controls = UIView()
    var buttons: [String: UIButton] = [:]
    var corner = 3
    convenience init(player: AVPlayer, owner: AVPictureInPictureController) {
        let v = _AVPlayerView()
        v.playerLayer.player = player
        self.init(player: player, sampleLayer: nil, video: v, owner: owner)
    }
    convenience init(sampleBufferLayer layer: AVSampleBufferDisplayLayer, owner: AVPictureInPictureController) {
        self.init(player: nil, sampleLayer: layer, video: _PiPSampleView(layer.sampleBufferRenderer), owner: owner)
    }
    init(player: AVPlayer?, sampleLayer: AVSampleBufferDisplayLayer?, video: UIView, owner: AVPictureInPictureController) {
        self.player = player; self.sampleLayer = sampleLayer; self.video = video; self.owner = owner
        super.init(frame: .zero)
        windowLevel = UIWindow.Level(rawValue: 2000)
        backgroundColor = .clear
        let root = UIViewController()
        root.view.backgroundColor = .black
        root.view.layer.cornerRadius = 12
        root.view.clipsToBounds = true
        root.view.accessibilityIdentifier = "pip-window"
        rootViewController = root
        video.frame = root.view.bounds; video.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.view.addSubview(video)
        controls.frame = root.view.bounds; controls.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controls.backgroundColor = UIColor(white: 0, alpha: 0.35); controls.isHidden = true
        root.view.addSubview(controls)
        for (id, symbol) in [("pip-close", "xmark"), ("pip-restore", "pip.exit"), ("pip-skip-back", "gobackward.15"), ("pip-play", "pause.fill"), ("pip-skip-forward", "goforward.15")] {
            let b = UIButton(type: .custom)
            b.setImage(UIImage(systemName: symbol), for: .normal); b.tintColor = .white
            b.accessibilityIdentifier = id
            b.addTarget(self, action: #selector(pressed(_:)), for: .touchUpInside)
            controls.addSubview(b); buttons[id] = b
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        root.view.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        root.view.addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError() }
    var size: CGSize {
        let screen = UIScreen.main.bounds
        let w = min(screen.width * 0.62, 260)
        let h: CGFloat
        if let info = player?._isimMedia { h = w * info.height / max(1, info.width) }
        else if let img = sampleLayer?.sampleBufferRenderer._isimImage { h = w * CGFloat(img.height) / CGFloat(max(1, img.width)) }
        else { h = w * 9 / 16 }
        return CGSize(width: w, height: h)
    }
    func place() {
        let screen = UIScreen.main.bounds, s = size
        let insets = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
        let x = corner & 1 != 0 ? screen.width - 10 - s.width : 10
        let y = corner & 2 != 0 ? screen.height - max(insets.bottom, 10) - 10 - s.height : max(insets.top, 20) + 6
        frame = CGRect(x: x, y: y, width: s.width, height: s.height)
        let b = bounds, c = CGPoint(x: b.midX, y: b.midY)
        buttons["pip-close"]?.frame = CGRect(x: 4, y: 4, width: 36, height: 36)
        buttons["pip-restore"]?.frame = CGRect(x: b.width - 40, y: 4, width: 36, height: 36)
        buttons["pip-play"]?.frame = CGRect(x: c.x - 22, y: c.y - 22, width: 44, height: 44)
        buttons["pip-skip-back"]?.frame = CGRect(x: c.x - 78, y: c.y - 20, width: 40, height: 40)
        buttons["pip-skip-forward"]?.frame = CGRect(x: c.x + 38, y: c.y - 20, width: 40, height: 40)
    }
    func show() { place(); isHidden = false; refresh() }
    func close() { isHidden = true; (video as? _AVPlayerView)?.playerLayer.player = nil }
    /// the content plays: the player's rate, or what the sample-buffer delegate says
    var playing: Bool {
        if let p = player { return p.rate > 0 }
        guard let o = owner, let d = o.contentSource?.sampleBufferPlaybackDelegate else { return false }
        return !d.pictureInPictureControllerIsPlaybackPaused(o)
    }
    func refresh() { buttons["pip-play"]?.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal) }
    @objc func toggleControls() { controls.isHidden.toggle(); refresh() }
    @objc func pressed(_ b: UIButton) {
        let id = b.accessibilityIdentifier ?? ""
        let e = id == "pip-close" ? "close" : id == "pip-restore" ? "restore" : id == "pip-play" ? (playing ? "pause" : "play")
            : id == "pip-skip-back" ? "skip -15" : "skip 15"
        owner?._event(e)
    }
    @objc func dragged(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: nil)
        if g.state == .changed { transform = CGAffineTransform(translationX: t.x, y: t.y) }
        if g.state == .ended || g.state == .cancelled {
            let c = CGPoint(x: frame.midX, y: frame.midY), screen = UIScreen.main.bounds
            transform = .identity
            corner = (c.x > screen.midX ? 1 : 0) | (c.y > screen.midY ? 2 : 0)
            UIView.animate(withDuration: 0.25) { self.place() }
        }
    }
}

/// the floating window's video for sample-buffer content: the display layer's current frame
final class _PiPSampleView: UIView {
    let renderer: AVSampleBufferVideoRenderer
    init(_ r: AVSampleBufferVideoRenderer) {
        renderer = r
        super.init(frame: .zero)
        backgroundColor = .black
        accessibilityIdentifier = "pip-video"
        r._isimAddFrameObserver { [weak self] in self?.setNeedsDisplay() }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        guard let img = renderer._isimImage else { return }
        let r = AVMakeRect(aspectRatio: CGSize(width: img.width, height: img.height), insideRect: bounds)
        isim_image_draw(img.handle, r.minX, r.minY, r.width, r.height, nil, 1)
    }
}

// MARK: - AirPlay route picker

@objc public protocol AVRoutePickerViewDelegate: NSObjectProtocol {
    @objc optional func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView)
    @objc optional func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView)
}
/// The AirPlay button: tapping it presents the audio route picker (AVFoundation's simulated routes).
open class AVRoutePickerView: UIView {
    open var activeTintColor: UIColor? = nil { didSet { refresh() } }
    open var prioritizesVideoDevices = false { didSet { refresh() } }
    open weak var delegate: AVRoutePickerViewDelegate?
    let button = UIButton(type: .custom)
    var observer: NSObjectProtocol?
    public override init(frame: CGRect) { super.init(frame: frame); setup() }
    public required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    func setup() {
        button.accessibilityIdentifier = "avkit-route-picker"
        button.accessibilityLabel = "AirPlay"
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(button)
        observer = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    func refresh() {
        button.setImage(UIImage(systemName: prioritizesVideoDevices ? "airplayvideo" : "airplayaudio"), for: .normal)
        let airplay = AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .airPlay }
        button.tintColor = airplay ? (activeTintColor ?? tintColor) : tintColor
    }
    open override func tintColorDidChange() { super.tintColorDidChange(); refresh() }
    open override func layoutSubviews() { super.layoutSubviews(); button.frame = bounds }
    open override var intrinsicContentSize: CGSize { CGSize(width: 30, height: 30) }
    @objc func tapped() {
        delegate?.routePickerViewWillBeginPresentingRoutes?(self)
        AVAudioSession._isimShowRoutePicker(from: self) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { self.refresh(); self.delegate?.routePickerViewDidEndPresentingRoutes?(self) }
        }
    }
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
