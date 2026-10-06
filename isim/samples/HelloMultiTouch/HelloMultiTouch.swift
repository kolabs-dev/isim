// Sample: two fingers on isim — pinch, rotation and two-finger pan recognizers on one card (recognized together),
// a multi-touch view that sees both UITouches, UIScrollView pinch zooming with double-tap zoom, hover with
// UIHoverGestureRecognizer and (on iPad) pointer effects. On the host: Option-drag pinches/rotates, Option+Shift-drag
// pans with two fingers; mouse motion without a button hovers.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MultiTouchViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// Logs the touches it gets: with isMultipleTouchEnabled it sees the second finger too.
final class TouchPad: UIView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchpad began \(touches.count) touch, \(event?.allTouches?.count ?? 0) down")
        backgroundColor = (event?.allTouches?.count ?? 0) > 1 ? .systemPurple.withAlphaComponent(0.4) : .systemPurple.withAlphaComponent(0.2)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchpad ended \(touches.count) touch, \(event?.allTouches?.count ?? 0) in event")
    }
}

/// A checkerboard to zoom into.
final class Checkerboard: UIView {
    override func draw(_ rect: CGRect) {
        let s: CGFloat = 20
        for row in 0..<Int(bounds.height / s) + 1 {
            for col in 0..<Int(bounds.width / s) + 1 where (row + col) % 2 == 0 {
                UIColor.systemTeal.setFill()
                UIBezierPath(rect: CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)).fill()
            }
        }
    }
}

final class MultiTouchViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UIPointerInteractionDelegate {
    let status = UILabel(), stage = UIView(), card = UIView(), pad = TouchPad(), scroll = UIScrollView(), board = Checkerboard()
    let hover = UIView(), pointerButton = UIButton(type: .system)
    var scale: CGFloat = 1, angle: CGFloat = 0, offset = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width - 40
        status.text = "Two fingers: Option-drag"
        status.font = .systemFont(ofSize: 17, weight: .semibold)
        status.accessibilityIdentifier = "status"
        status.frame = CGRect(x: 20, y: 66, width: w, height: 30)
        view.addSubview(status)

        stage.frame = CGRect(x: 20, y: 100, width: w, height: 290)
        stage.backgroundColor = .secondarySystemBackground
        stage.layer.cornerRadius = 16
        stage.clipsToBounds = true
        stage.accessibilityIdentifier = "stage"
        view.addSubview(stage)
        card.frame = CGRect(x: w / 2 - 80, y: 150 - 80, width: 160, height: 160)
        card.backgroundColor = .systemOrange
        card.layer.cornerRadius = 20
        card.accessibilityIdentifier = "card"
        stage.addSubview(card)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.minimumNumberOfTouches = 2
        for g in [pinch, rotate, pan] as [UIGestureRecognizer] { g.delegate = self; stage.addGestureRecognizer(g) }

        pad.frame = CGRect(x: 20, y: 400, width: w, height: 100)
        pad.isMultipleTouchEnabled = true
        pad.backgroundColor = .systemPurple.withAlphaComponent(0.2)
        pad.layer.cornerRadius = 16
        pad.accessibilityIdentifier = "touchpad"
        view.addSubview(pad)

        scroll.frame = CGRect(x: 20, y: 510, width: w, height: 220)
        scroll.delegate = self
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.layer.cornerRadius = 16
        scroll.backgroundColor = .systemGray6
        scroll.accessibilityIdentifier = "zoom"
        board.frame = CGRect(x: 0, y: 0, width: w, height: 220)
        board.backgroundColor = .clear
        board.accessibilityIdentifier = "board"
        scroll.addSubview(board)
        scroll.contentSize = board.bounds.size
        view.addSubview(scroll)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        hover.frame = CGRect(x: 20, y: 740, width: w / 2 - 6, height: 60)
        hover.backgroundColor = .systemGreen.withAlphaComponent(0.2)
        hover.layer.cornerRadius = 12
        hover.accessibilityIdentifier = "hover"
        hover.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hovered(_:))))
        view.addSubview(hover)

        pointerButton.setTitle("Pointer", for: .normal)
        pointerButton.frame = CGRect(x: 20 + w / 2 + 6, y: 740, width: w / 2 - 6, height: 60)
        pointerButton.accessibilityIdentifier = "pointer-button"
        pointerButton.addInteraction(UIPointerInteraction(delegate: self))
        view.addSubview(pointerButton)
    }

    // MARK: two-finger gestures on the card (all three at once)
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    func applyTransform() {
        card.transform = CGAffineTransform(translationX: offset.x, y: offset.y).rotated(by: angle).scaledBy(x: scale, y: scale)
    }
    @objc func pinched(_ g: UIPinchGestureRecognizer) {
        if g.state == .began { print("pinch began with \(g.numberOfTouches) touches") }
        scale *= g.scale; g.scale = 1; applyTransform()
        if g.state == .ended { report(String(format: "pinch ended scale %.2f", scale)) }
    }
    @objc func rotated(_ g: UIRotationGestureRecognizer) {
        angle += g.rotation; g.rotation = 0; applyTransform()
        if g.state == .ended { report(String(format: "rotation ended %.0f degrees", angle * 180 / .pi)) }
    }
    @objc func panned(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: stage)
        offset.x += t.x; offset.y += t.y; g.setTranslation(.zero, in: stage); applyTransform()
        if g.state == .ended { report(String(format: "two-finger pan ended at %.0f,%.0f", offset.x, offset.y)) }
    }

    // MARK: zooming
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { board }
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) { print("zoom began") }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        report(String(format: "zoom ended scale %.2f, content %.0f x %.0f", scale, scrollView.contentSize.width, scrollView.contentSize.height))
    }
    @objc func doubleTapped(_ g: UITapGestureRecognizer) {
        if scroll.zoomScale > 1.01 { scroll.setZoomScale(1, animated: true); return }
        let p = g.location(in: board)
        scroll.zoom(to: CGRect(x: p.x - 45, y: p.y - 27, width: 90, height: 55), animated: true)
    }

    // MARK: hover and pointer
    @objc func hovered(_ g: UIHoverGestureRecognizer) {
        switch g.state {
        case .began: hover.backgroundColor = .systemGreen.withAlphaComponent(0.6); print("hover began")
        case .changed: let p = g.location(in: hover); print(String(format: "hover at %.0f,%.0f", p.x, p.y))
        case .ended: hover.backgroundColor = .systemGreen.withAlphaComponent(0.2); print("hover ended")
        default: break
        }
    }
    func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        print("pointer region requested")
        return defaultRegion
    }
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        guard let v = interaction.view else { return nil }
        return UIPointerStyle(effect: .highlight(UITargetedPreview(view: v)))
    }
    func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        print("pointer entered button")
    }

    func report(_ s: String) { status.text = s; print(s) }
}
