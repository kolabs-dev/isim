// Sample: Apple Pencil, the iPad pointer and UIKit Dynamics on isim — a canvas that draws Pencil strokes (touch type,
// force, altitude), a UIPencilInteraction (double-tap and squeeze switch tools), a hovering Pencil (zOffset), views
// whose pointer becomes a custom shape (rounded rect, beam with arrow accessories), a text field (the I-beam), and a
// box dropped off-centre onto a ledge so that it spins as it falls.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = PencilViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// draws what the Pencil writes; fingers are ignored (like an app that prefers Pencil-only drawing)
final class Canvas: UIView {
    var strokes: [[CGPoint]] = []
    var eraser = false
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        guard t.type == .pencil else { print("canvas: finger ignored"); return }
        print(String(format: "canvas: pencil began force %.2f of %.2f altitude %.2f azimuth %.2f", t.force, t.maximumPossibleForce, t.altitudeAngle, t.azimuthAngle(in: self)))
        strokes.append([t.location(in: self)])
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, t.type == .pencil, !strokes.isEmpty else { return }
        strokes[strokes.count - 1].append(t.location(in: self)); setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, t.type == .pencil else { return }
        print("canvas: stroke of \(strokes.last?.count ?? 0) points (\(eraser ? "eraser" : "pen"))")
    }
    override func draw(_ rect: CGRect) {
        (eraser ? UIColor.systemPink : UIColor.label).setStroke()
        for s in strokes where s.count > 1 {
            let p = UIBezierPath(); p.lineWidth = 4; p.lineCapStyle = .round
            p.move(to: s[0]); s.dropFirst().forEach { p.addLine(to: $0) }; p.stroke()
        }
    }
}

final class PencilViewController: UIViewController, UIPencilInteractionDelegate, UIPointerInteractionDelegate {
    let canvas = Canvas()
    let tool = UILabel()
    let shaped = UIView(), beam = UIView()
    var animator: UIDynamicAnimator!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        canvas.frame = CGRect(x: 20, y: 60, width: 500, height: 300)
        canvas.backgroundColor = .secondarySystemBackground
        canvas.accessibilityIdentifier = "canvas"
        view.addSubview(canvas)
        tool.frame = CGRect(x: 540, y: 60, width: 260, height: 30)
        tool.text = "Tool: pen"
        tool.accessibilityIdentifier = "tool"
        view.addSubview(tool)
        let pencil = UIPencilInteraction(delegate: self)
        view.addInteraction(pencil)
        print("pencil preferred tap action \(UIPencilInteraction.preferredTapAction.rawValue), only drawing \(UIPencilInteraction.prefersPencilOnlyDrawing)")
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(hovered(_:)))
        canvas.addGestureRecognizer(hover)

        // pointer shapes
        shaped.frame = CGRect(x: 540, y: 120, width: 200, height: 80)
        shaped.backgroundColor = .systemTeal; shaped.layer.cornerRadius = 12
        shaped.accessibilityIdentifier = "shaped"
        shaped.addInteraction(UIPointerInteraction(delegate: self))
        view.addSubview(shaped)
        beam.frame = CGRect(x: 540, y: 220, width: 200, height: 80)
        beam.backgroundColor = .systemYellow
        beam.accessibilityIdentifier = "beam"
        beam.addInteraction(UIPointerInteraction(delegate: self))
        view.addSubview(beam)
        let field = UITextField(frame: CGRect(x: 540, y: 320, width: 240, height: 40))
        field.borderStyle = .roundedRect; field.placeholder = "Text"; field.font = .systemFont(ofSize: 24)
        field.accessibilityIdentifier = "field"
        view.addSubview(field)

        // dynamics: a box falls onto a ledge with one corner first and spins
        let arena = UIView(frame: CGRect(x: 20, y: 400, width: 500, height: 400))
        arena.backgroundColor = .tertiarySystemBackground
        arena.accessibilityIdentifier = "arena"
        view.addSubview(arena)
        let box = UIView(frame: CGRect(x: 150, y: 20, width: 80, height: 50))
        box.backgroundColor = .systemOrange
        box.accessibilityIdentifier = "box"
        arena.addSubview(box)
        let ledge = UIView(frame: CGRect(x: 0, y: 220, width: 180, height: 6))
        ledge.backgroundColor = .systemGray
        arena.addSubview(ledge)
        animator = UIDynamicAnimator(referenceView: arena)
        let collision = UICollisionBehavior(items: [box])
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.addBoundary(withIdentifier: "ledge" as NSString, from: CGPoint(x: 0, y: 220), to: CGPoint(x: 180, y: 220))
        let props = UIDynamicItemBehavior(items: [box]); props.elasticity = 0.2; props.friction = 0.5
        let drop = UIButton(type: .system)
        drop.setTitle("Drop", for: .normal); drop.frame = CGRect(x: 540, y: 400, width: 100, height: 40)
        drop.accessibilityIdentifier = "drop"
        drop.addAction(UIAction { [unowned self] _ in
            animator.addBehavior(UIGravityBehavior(items: [box])); animator.addBehavior(collision); animator.addBehavior(props)
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
                let angle = atan2(box.transform.b, box.transform.a)
                if abs(angle) > 0.3 { print(String(format: "box turned %.2f rad", angle)); t.invalidate() }
            }
        }, for: .primaryActionTriggered)
        view.addSubview(drop)
    }

    @objc func hovered(_ g: UIHoverGestureRecognizer) {
        if g.state == .began || g.state == .changed { print(String(format: "hover z %.2f", g.zOffset)) }
    }
    // Apple Pencil double-tap and squeeze (iOS 17.5 API)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        canvas.eraser.toggle()
        tool.text = canvas.eraser ? "Tool: eraser" : "Tool: pen"
        print("pencil double-tap: \(tool.text!) (hovering \(tap.hoverPose != nil))")
    }
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        print("pencil squeeze phase \(squeeze.phase.rawValue)")
    }
    // pointer: a rounded rect around the teal view; a horizontal beam with arrows over the yellow one
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        guard let v = interaction.view else { return nil }
        if v === shaped { return UIPointerStyle(effect: .lift(UITargetedPreview(view: v)), shape: .roundedRect(v.bounds.insetBy(dx: -6, dy: -6), radius: 18)) }
        let style = UIPointerStyle(shape: .horizontalBeam(length: 60), constrainedAxes: .vertical)
        style.accessories = [.arrow(.left), .arrow(.right)]
        return style
    }
}
