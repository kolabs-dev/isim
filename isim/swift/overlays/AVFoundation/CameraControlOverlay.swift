// isim AVFoundation: the overlay iOS draws for the Camera Control over a capture session's preview (issue #711).
// Adapted. A light press shows the selected control in a capsule beside the button: its symbol, title and value, with
// a tick scale (sliders, the system zoom and exposure) or its choices (index pickers). A second light press lists all
// the controls' symbols to choose from. The capsule fades out a few seconds after the last press or swipe. Liquid Glass
// from iOS 26, a dark blur before. Its placement (along the right edge at the button's height in portrait, along the
// top edge in landscape) and its sizes are estimated from Apple's Human Interface Guidelines ("Camera Control") and
// WWDC24 session 10199, not measured. It is system UI: a window above the app that takes no touches; `dump` lists it
// (camera-control-overlay, its label the control and value; camera-control-N for each control while choosing).
import UIKit

@MainActor enum _CameraControlOverlay {
    static var window: UIWindow?
    static var view: _CameraControlOverlayView?
    static var fade: DispatchWorkItem?
    /// seconds the overlay stays after the last press or swipe
    static let visibleSeconds = 3.0

    /// shows the overlay for the current state of `_CameraControl`, or hides it when the controls are inactive
    static func update() {
        guard _CameraControl.active, !_CameraControl.enabled.isEmpty else { hide(); return }
        if window == nil {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: UIScreen.main.bounds)
            w.frame = UIScreen.main.bounds
            w.windowLevel = UIWindow.Level(rawValue: 2200)
            w.backgroundColor = .clear
            w.isUserInteractionEnabled = false              // the app keeps every touch
            let v = _CameraControlOverlayView(frame: .zero)
            w.addSubview(v)
            w.isHidden = false
            window = w; view = v
        }
        view?.show()
        fade?.cancel()
        let f = DispatchWorkItem { hide() }
        fade = f
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleSeconds, execute: f)
    }
    static func hide() {
        fade?.cancel(); fade = nil
        window?.isHidden = true
        window = nil; view = nil
    }
}

/// the capsule: the selected control, or (choosing) every control's symbol
final class _CameraControlOverlayView: UIView {
    let platter: UIVisualEffectView
    let content = _CameraControlContent(frame: .zero)        /* above the material */
    override init(frame: CGRect) {
        if #available(iOS 26, *) {                        /* dark-tinted glass: white text over a bright preview too */
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = UIColor.black.withAlphaComponent(0.45)
            platter = UIVisualEffectView(effect: glass)
        } else { platter = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark)) }
        super.init(frame: frame)
        backgroundColor = .clear
        platter.clipsToBounds = true
        addSubview(platter)
        content.owner = self
        addSubview(content)
        isAccessibilityElement = true
        accessibilityIdentifier = "camera-control-overlay"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    /// what `dump` shows for the overlay
    @objc(_isim_dumpText) func _isimDumpText() -> String { accessibilityLabel ?? "" }

    var landscape: Bool { UIScreen.main.bounds.width > UIScreen.main.bounds.height }

    func show() {
        let b = UIScreen.main.bounds
        let cs = _CameraControl.enabled
        let choosing = _CameraControl.choosing
        let long: CGFloat = choosing ? CGFloat(cs.count) * 48 + 16 : 264, short: CGFloat = 76
        if landscape { frame = CGRect(x: (b.width - long) / 2, y: 12, width: long, height: short) }
        else { frame = CGRect(x: b.width - short - 8, y: min(b.height - long - 40, max(60, b.height * 0.65 - long / 2)), width: short, height: long) }
        platter.frame = bounds
        platter.layer.cornerRadius = short / 2
        content.frame = bounds
        // one element per control while choosing, so agents can read the row
        subviews.filter { $0 !== platter && $0 !== content }.forEach { $0.removeFromSuperview() }
        let sel = min(_CameraControl.selected, max(0, cs.count - 1))
        if choosing {
            for (i, c) in cs.enumerated() {
                let e = _CameraControlChoice(frame: slot(i))
                e.isAccessibilityElement = true
                e.accessibilityIdentifier = "camera-control-\(i)"
                e.accessibilityLabel = c._title + (i == sel ? ", selected" : "")
                addSubview(e)
            }
            accessibilityLabel = "Camera Control: " + cs.map(\._title).joined(separator: ", ")
        } else if cs.indices.contains(sel) {
            accessibilityLabel = "\(cs[sel]._title) \(cs[sel]._display)"
        }
        content.setNeedsDisplay()
    }
    /// the square of control `i` in the choosing row (along the capsule)
    func slot(_ i: Int) -> CGRect {
        landscape ? CGRect(x: 8 + CGFloat(i) * 48 + 2, y: (bounds.height - 44) / 2, width: 44, height: 44)
                  : CGRect(x: (bounds.width - 44) / 2, y: 8 + CGFloat(i) * 48 + 2, width: 44, height: 44)
    }

    func drawContent() {
        let cs = _CameraControl.enabled
        guard !cs.isEmpty else { return }
        let sel = min(_CameraControl.selected, cs.count - 1)
        let yellow = UIColor(red: 1, green: 0.84, blue: 0.04, alpha: 1)       // the Camera app's selection colour
        if _CameraControl.choosing {
            for (i, c) in cs.enumerated() {
                let r = slot(i)
                if i == sel { UIColor.white.withAlphaComponent(0.25).setFill(); UIBezierPath(ovalIn: r).fill() }
                symbol(c._symbol, in: r.insetBy(dx: 10, dy: 10), color: i == sel ? yellow : .white)
            }
            return
        }
        let c = cs[sel]
        let head = landscape ? CGRect(x: 14, y: 0, width: 70, height: bounds.height) : CGRect(x: 0, y: 12, width: bounds.width, height: 74)
        symbol(c._symbol, in: CGRect(x: head.midX - 11, y: head.minY + (landscape ? 10 : 0), width: 22, height: 22), color: yellow)
        text(c._title, at: CGPoint(x: head.midX, y: head.minY + (landscape ? 36 : 26)), size: 10, weight: .medium, color: .white.withAlphaComponent(0.8))
        text(c._display, at: CGPoint(x: head.midX, y: head.minY + (landscape ? 50 : 42)), size: 15, weight: .semibold, color: .white)
        // the scale: ticks along the capsule with the value marked, or the picker's choices
        let track = landscape ? CGRect(x: 92, y: 14, width: bounds.width - 106, height: bounds.height - 28)
                              : CGRect(x: 14, y: 96, width: bounds.width - 28, height: bounds.height - 110)
        if let choices = c._choices {
            let cur = choices.firstIndex(of: c._display) ?? 0
            let n = max(1, choices.count)
            for (i, t) in choices.enumerated() {
                let f = (CGFloat(i) + 0.5) / CGFloat(n)
                let p = landscape ? CGPoint(x: track.minX + f * track.width, y: track.midY) : CGPoint(x: track.midX, y: track.maxY - f * track.height)
                text(t, at: p, size: i == cur ? 12 : 11, weight: i == cur ? .bold : .regular, color: i == cur ? yellow : .white.withAlphaComponent(0.75))
            }
        } else if let f = c._fraction {
            let ticks = 21
            for i in 0..<ticks {
                let k = CGFloat(i) / CGFloat(ticks - 1), major = i % 5 == 0
                let len: CGFloat = major ? 14 : 8
                let path = UIBezierPath()
                if landscape { let x = track.minX + k * track.width; path.move(to: CGPoint(x: x, y: track.midY - len / 2)); path.addLine(to: CGPoint(x: x, y: track.midY + len / 2)) }
                else { let y = track.maxY - k * track.height; path.move(to: CGPoint(x: track.midX - len / 2, y: y)); path.addLine(to: CGPoint(x: track.midX + len / 2, y: y)) }
                path.lineWidth = major ? 1.5 : 1
                UIColor.white.withAlphaComponent(major ? 0.9 : 0.55).setStroke(); path.stroke()
            }
            let v = CGFloat(min(1, max(0, f)))
            let marker = UIBezierPath()
            if landscape { let x = track.minX + v * track.width; marker.move(to: CGPoint(x: x, y: track.minY)); marker.addLine(to: CGPoint(x: x, y: track.maxY)) }
            else { let y = track.maxY - v * track.height; marker.move(to: CGPoint(x: track.minX, y: y)); marker.addLine(to: CGPoint(x: track.maxX, y: y)) }
            marker.lineWidth = 2.5; yellow.setStroke(); marker.stroke()
        }
    }
    func symbol(_ name: String, in r: CGRect, color: UIColor) {
        guard let img = UIImage(systemName: name)?.withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        img.draw(in: r)
    }
    func text(_ s: String, at center: CGPoint, size: CGFloat, weight: UIFont.Weight, color: UIColor) {
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
        let sz = (s as NSString).size(withAttributes: a)
        (s as NSString).draw(at: CGPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2), withAttributes: a)
    }
}

/// one control's square in the choosing row (for `dump` and accessibility; the overlay view draws it)
final class _CameraControlChoice: UIView {
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    @objc(_isim_dumpText) func _isimDumpText() -> String { accessibilityLabel ?? "" }
}

/// draws the overlay's symbols, text and scale over its material
final class _CameraControlContent: UIView {
    weak var owner: _CameraControlOverlayView?
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func draw(_ rect: CGRect) { owner?.drawContent() }
}
