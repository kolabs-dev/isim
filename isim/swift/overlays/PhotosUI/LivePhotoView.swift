// isim PhotosUI: PHLivePhotoView (issue #372). Shows a Live Photo's still; touching and holding (its playback gesture)
// or startPlayback plays the paired movie through AVPlayer over it, then returns to the still. A hint plays the first
// second. The LIVE badge (livePhotoBadgeImage) is drawn like iOS's: concentric rings and LIVE.
import UIKit
import AVFoundation
@_spi(isim) import Photos

@objc public enum PHLivePhotoViewPlaybackStyle: Int, Sendable { case undefined = 0, full = 1, hint = 2 }

public struct PHLivePhotoBadgeOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    /// a badge drawn over photo content (with a shadow)
    public static let overContent = PHLivePhotoBadgeOptions(rawValue: 1 << 0)
    /// the badge struck through: Live is off
    public static let liveOff = PHLivePhotoBadgeOptions(rawValue: 1 << 1)
}

@objc(PHLivePhotoViewDelegate) public protocol PHLivePhotoViewDelegate: NSObjectProtocol {
    @objc(livePhotoView:canBeginPlaybackWithStyle:)
    optional func livePhotoView(_ livePhotoView: PHLivePhotoView, canBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) -> Bool
    @objc(livePhotoView:willBeginPlaybackWithStyle:)
    optional func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle)
    @objc(livePhotoView:didEndPlaybackWithStyle:)
    optional func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle)
    @objc(livePhotoView:extraMinimumTouchDurationForTouch:withStyle:)
    optional func livePhotoView(_ livePhotoView: PHLivePhotoView, extraMinimumTouchDurationFor touch: UITouch,
                                with playbackStyle: PHLivePhotoViewPlaybackStyle) -> TimeInterval
}

@objc(PHLivePhotoView) open class PHLivePhotoView: UIView {
    private let still = UIImageView()
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playing: PHLivePhotoViewPlaybackStyle = .undefined
    private var endObserver: Any?
    private var hintTimer: Timer?

    @objc open var livePhoto: PHLivePhoto? {
        didSet {
            stopPlayback()
            still.image = livePhoto?._image
            invalidateIntrinsicContentSize()
        }
    }
    @objc open weak var delegate: PHLivePhotoViewDelegate?
    /// touching and holding plays the Live Photo
    @objc public private(set) lazy var playbackGestureRecognizer: UIGestureRecognizer = {
        let g = UILongPressGestureRecognizer(target: self, action: #selector(_held(_:)))
        g.minimumPressDuration = 0.15
        return g
    }()
    @objc(isMuted) open var isMuted = false { didSet { player?.isMuted = isMuted } }
    @objc open var audioVolume: Float = 1 { didSet { player?.volume = audioVolume } }
    /// the part of the Live Photo shown, in unit coordinates
    @objc open var contentsRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) {
        didSet { still.layer.contentsRect = contentsRect; playerLayer?.contentsRect = contentsRect }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    private func setUp() {
        clipsToBounds = true
        still.frame = bounds
        still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        still.contentMode = .scaleAspectFit
        addSubview(still)
        addGestureRecognizer(playbackGestureRecognizer)
    }
    open override var contentMode: UIView.ContentMode {
        didSet { still.contentMode = contentMode; playerLayer?.videoGravity = contentMode == .scaleAspectFill ? .resizeAspectFill : .resizeAspect }
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    open override var intrinsicContentSize: CGSize { livePhoto.map { CGSize(width: $0.size.width / UIScreen.main.scale, height: $0.size.height / UIScreen.main.scale) } ?? .zero }

    @objc func _held(_ g: UILongPressGestureRecognizer) {
        if g.state == .began { startPlayback(with: .full) }
    }

    /// Plays the paired movie over the still: all of it (.full) or its first second (.hint).
    @objc(startPlaybackWithStyle:) open func startPlayback(with playbackStyle: PHLivePhotoViewPlaybackStyle) {
        guard let livePhoto, playbackStyle != .undefined, playing == .undefined else { return }
        if delegate?.livePhotoView?(self, canBeginPlaybackWith: playbackStyle) == false { return }
        let p = AVPlayer(url: livePhoto._videoURL)
        p.isMuted = isMuted; p.volume = audioVolume
        let l = AVPlayerLayer(player: p)
        l.frame = bounds
        l.videoGravity = contentMode == .scaleAspectFill ? .resizeAspectFill : .resizeAspect
        l.contentsRect = contentsRect
        layer.addSublayer(l)
        player = p; playerLayer = l; playing = playbackStyle
        delegate?.livePhotoView?(self, willBeginPlaybackWith: playbackStyle)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?._finish() }
        }
        if playbackStyle == .hint {
            hintTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?._finish() } }
        }
        p.play()
    }
    @objc open func stopPlayback() { _finish() }
    @objc(stopPlaybackAnimated:) open func stopPlayback(animated: Bool) { _finish() }

    private func _finish() {
        guard playing != .undefined else { return }
        let style = playing
        playing = .undefined
        hintTimer?.invalidate(); hintTimer = nil
        if let o = endObserver { NotificationCenter.default.removeObserver(o); endObserver = nil }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil; playerLayer = nil
        delegate?.livePhotoView?(self, didEndPlaybackWith: style)
    }

    /// The LIVE badge: three concentric rings (a dotted outer one) and LIVE, struck through when off.
    @nonobjc open class func livePhotoBadgeImage(options badgeOptions: PHLivePhotoBadgeOptions = []) -> UIImage {
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let text = "LIVE" as NSString
        let tw = text.size(withAttributes: [.font: font, .kern: 0.6]).width
        let size = CGSize(width: ceil(6 + 16 + 4 + tw + 7), height: 22)
        let over = badgeOptions.contains(.overContent)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = ctx.cgContext
            if over {   // a dark translucent pill under the badge on photos
                UIColor(white: 0, alpha: 0.35).setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2).fill()
            }
            let color: UIColor = over ? .white : .label
            color.setStroke(); color.setFill()
            let c = CGPoint(x: 6 + 8, y: size.height / 2)
            g.fillEllipse(in: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4))
            g.setLineWidth(1.3)
            g.strokeEllipse(in: CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9))
            // the outer ring: dots
            for i in 0..<16 {
                let a = CGFloat(i) / 16 * 2 * .pi
                g.fillEllipse(in: CGRect(x: c.x + cos(a) * 7.5 - 0.7, y: c.y + sin(a) * 7.5 - 0.7, width: 1.4, height: 1.4))
            }
            text.draw(at: CGPoint(x: 6 + 16 + 4, y: (size.height - font.lineHeight) / 2),
                      withAttributes: [.font: font, .foregroundColor: color, .kern: 0.6])
            if badgeOptions.contains(.liveOff) {
                g.setLineWidth(1.5)
                g.move(to: CGPoint(x: c.x - 8, y: c.y + 8)); g.addLine(to: CGPoint(x: c.x + 8, y: c.y - 8)); g.strokePath()
            }
        }
    }
    @objc(livePhotoBadgeImageWithOptions:) class func _objcLivePhotoBadgeImage(options: UInt) -> UIImage {
        livePhotoBadgeImage(options: PHLivePhotoBadgeOptions(rawValue: options))
    }
}
