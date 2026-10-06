// Sample: Core Animation on isim — standalone CALayer trees (shape, gradient, replicator, text, emitter layers),
// CABasicAnimation / CAKeyframeAnimation / CASpringAnimation / CAAnimationGroup with delegates, CATransaction
// (implicit animations, completion blocks, disableActions), CATransform3D perspective (a layer and a view),
// layer masks and view masks, blurred shadows, UIKit Dynamics (gravity + collision) and CoreHaptics.
// Buttons print what is happening (presentation values) so the UI test can check it.
import UIKit
import QuartzCore
import CoreHaptics

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = CoreAnimationViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func f2(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
func f0(_ v: CGFloat) -> String { String(format: "%.0f", Double(v)) }

final class AnimDelegate: NSObject, CAAnimationDelegate {
    let name: String
    init(_ name: String) { self.name = name }
    func animationDidStart(_ anim: CAAnimation) { print("\(name) didStart") }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) { print("\(name) didStop finished=\(flag)") }
}

final class CoreAnimationViewController: UIViewController, UIDynamicAnimatorDelegate {
    let stroke = CAShapeLayer()
    let dot = CALayer()
    let fade = CALayer()
    let emitter = CAEmitterLayer()
    let spinner = UIView(frame: CGRect(x: 330, y: 640, width: 50, height: 50))
    let ball = UIView(frame: CGRect(x: 180, y: 600, width: 40, height: 40))
    var animator: UIDynamicAnimator?
    var engine: CHHapticEngine?
    var player: CHHapticPatternPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let root = view.layer

        // stroke animation, paused half-way (layer.speed = 0 + timeOffset)
        let line = UIBezierPath(); line.move(to: CGPoint(x: 20, y: 100)); line.addLine(to: CGPoint(x: 380, y: 100))
        stroke.path = line.cgPath
        stroke.strokeColor = UIColor.red.cgColor
        stroke.fillColor = nil
        stroke.lineWidth = 10
        stroke.speed = 0
        root.addSublayer(stroke)
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0; draw.toValue = 1; draw.duration = 2
        draw.timingFunction = CAMediaTimingFunction(name: .linear)
        stroke.add(draw, forKey: "draw")
        stroke.timeOffset = 1.0

        // axial gradient
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: 20, y: 130, width: 360, height: 40)
        gradient.colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5); gradient.endPoint = CGPoint(x: 1, y: 0.5)
        root.addSublayer(gradient)

        // replicator: 5 green squares 60 pt apart
        let rep = CAReplicatorLayer()
        rep.frame = CGRect(x: 20, y: 190, width: 360, height: 30)
        let square = CALayer()
        square.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        square.backgroundColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 1).cgColor
        rep.addSublayer(square)
        rep.instanceCount = 5
        rep.instanceTransform = CATransform3DMakeTranslation(60, 0, 0)
        root.addSublayer(rep)

        // a card layer rotated about y with perspective: drawn as a trapezoid
        let card = CALayer()
        card.bounds = CGRect(x: 0, y: 0, width: 160, height: 120)
        card.position = CGPoint(x: 110, y: 300)
        card.backgroundColor = UIColor.orange.cgColor
        var t = CATransform3DIdentity
        t.m34 = -1.0 / 400
        card.transform = CATransform3DRotate(t, .pi * 55 / 180, 0, 1, 0)
        root.addSublayer(card)
        // the same with a view's transform3D
        let v3 = UIView(frame: CGRect(x: 250, y: 250, width: 120, height: 100))
        v3.backgroundColor = .blue
        v3.accessibilityIdentifier = "card3d"
        v3.transform3D = CATransform3DRotate(t, -.pi * 55 / 180, 0, 1, 0)
        view.addSubview(v3)

        // layer mask: a red square through a circle
        let masked = UIView(frame: CGRect(x: 20, y: 380, width: 100, height: 100))
        masked.backgroundColor = .red
        let circle = CAShapeLayer()
        circle.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 100, height: 100)).cgPath
        masked.layer.mask = circle
        view.addSubview(masked)
        // view mask: only the left half of a green view
        let halfShown = UIView(frame: CGRect(x: 140, y: 380, width: 100, height: 100))
        halfShown.backgroundColor = UIColor(red: 0, green: 0.7, blue: 0, alpha: 1)
        let maskView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 100))
        maskView.backgroundColor = .black
        halfShown.mask = maskView
        view.addSubview(halfShown)
        // blurred shadow under a white card
        let shadowed = CALayer()
        shadowed.frame = CGRect(x: 270, y: 390, width: 100, height: 70)
        shadowed.backgroundColor = UIColor.white.cgColor
        shadowed.shadowColor = UIColor.black.cgColor
        shadowed.shadowOpacity = 0.8
        shadowed.shadowRadius = 8
        shadowed.shadowOffset = CGSize(width: 0, height: 8)
        root.addSublayer(shadowed)

        // text layer
        let text = CATextLayer()
        text.frame = CGRect(x: 20, y: 490, width: 260, height: 30)
        text.string = "Core Animation"
        text.fontSize = 22
        text.foregroundColor = UIColor.darkGray.cgColor
        text.contentsScale = 3
        root.addSublayer(text)

        // keyframe animation on a paused layer, reported at chosen times
        dot.frame = CGRect(x: 30, y: 510, width: 20, height: 20)
        dot.backgroundColor = UIColor.purple.cgColor
        dot.speed = 0
        root.addSublayer(dot)
        let kf = CAKeyframeAnimation(keyPath: "position")
        kf.values = [CGPoint(x: 40, y: 520), CGPoint(x: 200, y: 520), CGPoint(x: 200, y: 600)]
        kf.keyTimes = [0, 0.25, 1]
        kf.duration = 2
        kf.fillMode = .forwards
        kf.isRemovedOnCompletion = false
        dot.add(kf, forKey: "path")

        // implicit animations / transactions
        fade.frame = CGRect(x: 300, y: 520, width: 60, height: 60)
        fade.backgroundColor = UIColor.purple.cgColor
        root.addSublayer(fade)

        // emitter
        let img = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.white.setFill(); ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let cell = CAEmitterCell()
        cell.contents = img.cgImage
        cell.birthRate = 40; cell.lifetime = 1.5; cell.velocity = 60; cell.emissionRange = .pi * 2
        cell.color = UIColor.orange.cgColor; cell.contentsScale = img.scale
        emitter.emitterPosition = CGPoint(x: 60, y: 600)
        emitter.emitterShape = .point
        emitter.emitterCells = [cell]
        root.addSublayer(emitter)

        spinner.backgroundColor = .systemTeal
        spinner.accessibilityIdentifier = "spinner"
        view.addSubview(spinner)
        ball.backgroundColor = .systemPink
        ball.layer.cornerRadius = 8
        ball.accessibilityIdentifier = "ball"
        view.addSubview(ball)
        let floor = UIView(frame: CGRect(x: 120, y: 780, width: 160, height: 2))
        floor.backgroundColor = .gray
        view.addSubview(floor)

        let buttons: [(String, Selector)] = [("Report", #selector(report)), ("Tx", #selector(transaction)), ("Anim", #selector(animate)),
                                             ("Drop", #selector(drop)), ("Haptic", #selector(haptics))]
        for (i, (name, sel)) in buttons.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(name, for: .normal)
            b.frame = CGRect(x: 10 + CGFloat(i) * 78, y: 795, width: 74, height: 36)
            b.accessibilityIdentifier = "btn-\(name)"
            b.addTarget(self, action: sel, for: .touchUpInside)
            view.addSubview(b)
        }
    }

    @objc func report() {
        let s = stroke.presentation()?.strokeEnd ?? -1
        print("stroke presentation strokeEnd=\(f2(s)) model=\(f2(stroke.strokeEnd))")
        for time in [0.25, 0.5, 1.25, 2.5] {
            dot.timeOffset = time
            let p = dot.presentation()?.position ?? .zero
            print("keyframe t=\(time) x=\(f0(p.x)) y=\(f0(p.y))")
        }
        print("keyframe keys=\(dot.animationKeys() ?? []) model x=\(f0(dot.position.x))")
        print("emitter particles>0 \(emitter._isim_particleCount > 0)")
        let m = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        let inv = CATransform3DInvert(m)
        print("transform3D concat identity \(CATransform3DIsIdentity(CATransform3DConcat(m, inv))) affine \(CATransform3DIsAffine(m))")
    }

    @objc func transaction() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.6)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        CATransaction.setCompletionBlock { [fade] in
            print("transaction complete opacity=\(f2(CGFloat(fade.opacity))) presentation=\(f2(CGFloat(fade.presentation()?.opacity ?? -1)))")
        }
        fade.opacity = 0.2
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [fade] in
            let o = CGFloat(fade.presentation()?.opacity ?? -1)
            print("implicit mid opacity between \(o > 0.3 && o < 0.95) (\(f2(o)))")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.cornerRadius = 20
        CATransaction.commit()
        print("disableActions radius=\(f0(fade.presentation()?.cornerRadius ?? -1)) cornerRadius animated=\((fade.animationKeys() ?? []).contains("cornerRadius"))")
    }

    @objc func animate() {
        // a view's own layer: no implicit animation, explicit CA animations render
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0; spin.toValue = CGFloat.pi; spin.duration = 1
        spin.delegate = AnimDelegate("spin")
        spinner.layer.add(spin, forKey: "spin")
        let spring = CASpringAnimation(keyPath: "position.y")
        spring.fromValue = 420; spring.toValue = 520
        spring.damping = 12; spring.stiffness = 200
        spring.delegate = AnimDelegate("spring")
        print("spring settlingDuration>0.3 \(spring.settlingDuration > 0.3)")
        fade.add(spring, forKey: "spring")
        let group = CAAnimationGroup()
        let a1 = CABasicAnimation(keyPath: "opacity"); a1.fromValue = 1; a1.toValue = 0.5
        let a2 = CABasicAnimation(keyPath: "bounds.size.width"); a2.toValue = 40
        group.animations = [a1, a2]; group.duration = 0.8
        group.delegate = AnimDelegate("group")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let r = spinner.layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat ?? -1
            print("spin mid rotation between \(r > 0.8 && r < 2.4) model=\(f2(spinner.layer.value(forKeyPath: "transform.rotation.z") as? CGFloat ?? -1))")
        }
        fade.add(group, forKey: "group")
    }

    @objc func drop() {
        let a = UIDynamicAnimator(referenceView: view)
        a.delegate = self
        let gravity = UIGravityBehavior(items: [ball])
        let collision = UICollisionBehavior(items: [ball])
        collision.addBoundary(withIdentifier: "floor" as NSString, from: CGPoint(x: 0, y: 780), to: CGPoint(x: 402, y: 780))
        collision.translatesReferenceBoundsIntoBoundary = true
        let props = UIDynamicItemBehavior(items: [ball])
        props.elasticity = 0.3
        a.addBehavior(gravity); a.addBehavior(collision); a.addBehavior(props)
        animator = a
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in print("dynamics falling y>600 \(ball.frame.minY > 600) running=\(animator?.isRunning ?? false)") }
    }
    func dynamicAnimatorDidPause(_ animator: UIDynamicAnimator) {
        print("dynamics rest maxY=\(f0(ball.frame.maxY)) x=\(f0(ball.frame.minX))")
    }

    @objc func haptics() {
        let caps = CHHapticEngine.capabilitiesForHardware()
        print("haptics supportsHaptics=\(caps.supportsHaptics)")
        do {
            let e = try CHHapticEngine()
            try e.start()
            let tap = CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)], relativeTime: 0)
            let buzz = CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)], relativeTime: 0.1, duration: 0.3)
            let pattern = try CHHapticPattern(events: [tap, buzz], parameters: [])
            print("haptics pattern duration=\(f2(pattern.duration))")
            let p = try e.makePlayer(with: pattern)
            try p.start(atTime: CHHapticTimeImmediate)
            DispatchQueue.main.async { e.notifyWhenPlayersFinished { _ in print("haptics players finished"); return .stopEngine } }
            engine = e; player = p
        } catch { print("haptics error \(error)") }
    }
}
