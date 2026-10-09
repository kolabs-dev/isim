// Sample: transitions and gestures on isim (UIKit) — UIView.transition(with:) flips (3D, perspective), curls and
// cross dissolve; modal flip horizontal and partial curl; failure requirements decided by the delegate and by a
// recognizer subclass; layer shadow and color animations.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MotionViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// a pan that waits for a double tap on the same view to fail (shouldRequireFailure(of:) override)
final class PatientPan: UIPanGestureRecognizer {
    weak var mustFail: UIGestureRecognizer?
    override func shouldRequireFailure(of other: UIGestureRecognizer) -> Bool { other === mustFail }
}

final class MotionViewController: UIViewController, UIGestureRecognizerDelegate {
    let card = UIView(), cardLabel = UILabel()
    let shadowBox = UIView()
    let pad = UIView()
    var side = 0
    var swipe: UISwipeGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // the card that transitions: red front, blue back
        card.frame = CGRect(x: 60, y: 110, width: 280, height: 200)
        card.backgroundColor = .systemRed
        card.accessibilityIdentifier = "card"
        cardLabel.frame = CGRect(x: 0, y: 80, width: 280, height: 40); cardLabel.textAlignment = .center
        cardLabel.text = "Front"; cardLabel.font = .boldSystemFont(ofSize: 28); cardLabel.textColor = .white
        card.addSubview(cardLabel)
        view.addSubview(card)
        let kinds: [(String, UIView.AnimationOptions)] = [("flip", .transitionFlipFromLeft), ("flipTop", .transitionFlipFromTop),
                                                           ("curlUp", .transitionCurlUp), ("curlDown", .transitionCurlDown), ("dissolve", .transitionCrossDissolve)]
        for (i, (name, option)) in kinds.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(name, for: .normal)
            b.frame = CGRect(x: 10 + CGFloat(i % 3) * 125, y: 320 + CGFloat(i / 3) * 40, width: 120, height: 36)
            b.accessibilityIdentifier = name
            b.addAction(UIAction { [unowned self] _ in
                UIView.transition(with: card, duration: 1.2, options: option, animations: { [unowned self] in
                    side ^= 1
                    card.backgroundColor = side == 1 ? .systemBlue : .systemRed
                    cardLabel.text = side == 1 ? "Back" : "Front"
                }, completion: { _ in print("transition \(name) done: \(self.cardLabel.text ?? "")") })
            }, for: .primaryActionTriggered)
            view.addSubview(b)
        }
        // modal transition styles
        for (i, (name, style)) in [("modalFlip", UIModalTransitionStyle.flipHorizontal), ("modalCurl", .partialCurl)].enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(name, for: .normal)
            b.frame = CGRect(x: 10 + CGFloat(i) * 125, y: 410, width: 120, height: 36)
            b.accessibilityIdentifier = name
            b.addAction(UIAction { [unowned self] _ in
                let vc = SettingsViewController()
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = style
                present(vc, animated: true) { print("presented \(name)") }
            }, for: .primaryActionTriggered)
            view.addSubview(b)
        }
        // gestures: a pad with a double tap, a swipe and two pans waiting on them
        pad.frame = CGRect(x: 20, y: 460, width: 360, height: 150)
        pad.backgroundColor = .systemGray5
        pad.accessibilityIdentifier = "pad"
        view.addSubview(pad)
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        double.numberOfTapsRequired = 2
        swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped))
        swipe.direction = .right
        let pan = PatientPan(target: self, action: #selector(panned(_:)))
        pan.mustFail = double
        pan.delegate = self                                          // the delegate also makes it wait for the swipe
        for g in [double, swipe!, pan] as [UIGestureRecognizer] { pad.addGestureRecognizer(g) }
        // layer animations: shadow and border color
        shadowBox.frame = CGRect(x: 140, y: 640, width: 120, height: 80)
        shadowBox.backgroundColor = .systemBackground
        shadowBox.layer.shadowColor = UIColor.black.cgColor
        shadowBox.layer.shadowOpacity = 0; shadowBox.layer.shadowRadius = 0
        shadowBox.layer.borderWidth = 4; shadowBox.layer.borderColor = UIColor.systemRed.cgColor
        shadowBox.accessibilityIdentifier = "shadowBox"
        view.addSubview(shadowBox)
        let lift = UIButton(type: .system)
        lift.setTitle("lift", for: .normal); lift.frame = CGRect(x: 10, y: 660, width: 100, height: 36); lift.accessibilityIdentifier = "lift"
        lift.addAction(UIAction { [unowned self] _ in
            UIView.animate(withDuration: 1.0, animations: { [unowned self] in
                shadowBox.layer.shadowOpacity = 0.8; shadowBox.layer.shadowRadius = 20; shadowBox.layer.shadowOffset = CGSize(width: 0, height: 12)
                shadowBox.layer.borderColor = UIColor.systemBlue.cgColor
            }, completion: { [unowned self] _ in print("lift done: opacity \(shadowBox.layer.shadowOpacity) radius \(shadowBox.layer.shadowRadius)") })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [unowned self] in
                if let p = shadowBox.layer.presentation() { print(String(format: "lift mid: opacity %.2f radius %.1f offset %.1f", p.shadowOpacity, p.shadowRadius, p.shadowOffset.height)) }
            }
        }, for: .primaryActionTriggered)
        view.addSubview(lift)
    }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool { g is PatientPan && other === swipe }
    @objc func doubleTapped() { print("double tap") }
    @objc func swiped() { print("swipe right") }
    @objc func panned(_ g: UIPanGestureRecognizer) {
        if g.state == .began { print("pan began") }
        if g.state == .ended { print("pan ended \(Int(g.translation(in: pad).y))") }
    }
}

final class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemTeal
        view.accessibilityIdentifier = "settings"
        let close = UIButton(type: .system)
        close.setTitle("Done", for: .normal)
        close.frame = CGRect(x: 20, y: view.bounds.height - 160, width: 100, height: 44)
        close.accessibilityIdentifier = "done"
        close.addAction(UIAction { [unowned self] _ in dismiss(animated: true) { print("dismissed") } }, for: .primaryActionTriggered)
        view.addSubview(close)
    }
}
