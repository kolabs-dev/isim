// Sample: gestures and hardware input on isim — single tap that waits for a double tap to fail (require(toFail:)),
// swipes, a screen-edge pan, a custom UIGestureRecognizer subclass, UIKeyCommand shortcuts, pressesBegan and shake.
import UIKit
import UIKit.UIGestureRecognizerSubclass

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GesturesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

/// Recognizes a press that stays within 30 pt of where it started for the whole touch: began on touch down,
/// changed on each move, ended on lift; fails if the finger wanders.
final class StayStillGestureRecognizer: UIGestureRecognizer {
    private var origin = CGPoint.zero
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        origin = touches.first!.location(in: view)
        state = .began
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let p = touches.first!.location(in: view)
        state = hypot(p.x - origin.x, p.y - origin.y) > 30 ? .failed : .changed
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .ended }
    override func reset() { origin = .zero }
}

final class GesturesViewController: UIViewController {
    let pad = UIView(), still = UIView(), panel = UIView(), status = UILabel()
    var moves = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.text = "Try the gestures"
        status.font = .systemFont(ofSize: 17, weight: .semibold)
        status.accessibilityIdentifier = "status"
        status.frame = CGRect(x: 20, y: 70, width: 362, height: 30)
        view.addSubview(status)

        pad.frame = CGRect(x: 20, y: 120, width: 362, height: 260)
        pad.backgroundColor = .systemBlue.withAlphaComponent(0.15)
        pad.layer.cornerRadius = 16
        pad.accessibilityIdentifier = "pad"
        view.addSubview(pad)
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        double.numberOfTapsRequired = 2
        let single = UITapGestureRecognizer(target: self, action: #selector(singleTap))
        single.require(toFail: double)
        let left = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
        left.direction = .left
        let right = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
        right.direction = .right
        [double, single, left, right].forEach(pad.addGestureRecognizer)

        still.frame = CGRect(x: 20, y: 400, width: 362, height: 120)
        still.backgroundColor = .systemGreen.withAlphaComponent(0.2)
        still.layer.cornerRadius = 16
        still.accessibilityIdentifier = "still"
        view.addSubview(still)
        still.addGestureRecognizer(StayStillGestureRecognizer(target: self, action: #selector(stayStill(_:))))

        panel.frame = CGRect(x: -260, y: 540, width: 260, height: 200)
        panel.backgroundColor = .systemOrange
        panel.layer.cornerRadius = 16
        panel.accessibilityIdentifier = "panel"
        view.addSubview(panel)
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgePan(_:)))
        edge.edges = .left
        view.addGestureRecognizer(edge)
    }

    @objc func singleTap() { report("single tap") }
    @objc func doubleTap() { report("double tap") }
    @objc func swiped(_ g: UISwipeGestureRecognizer) { report(g.direction == .left ? "swipe left" : "swipe right") }
    @objc func stayStill(_ g: StayStillGestureRecognizer) {
        switch g.state {
        case .began: moves = 0; print("still began")
        case .changed: moves += 1
        case .ended: report("still ended after \(moves) moves")
        default: break
        }
    }
    @objc func edgePan(_ g: UIScreenEdgePanGestureRecognizer) {
        let x = min(0, -260 + g.translation(in: view).x)
        panel.frame.origin.x = x
        if g.state == .ended { UIView.animate(withDuration: 0.25) { self.panel.frame.origin.x = x > -130 ? 0 : -260 }; report("edge pan ended, panel \(x > -130 ? "open" : "closed")") }
        else if g.state == .began { print("edge pan began") }
    }

    // MARK: hardware keyboard
    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(reload)),
         UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(arrowUp))]
    }
    @objc func reload() { report("command R") }
    @objc func arrowUp() { report("arrow up") }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let key = presses.first?.key { print("pressed \(key.charactersIgnoringModifiers) code \(key.keyCode.rawValue)") }
        super.pressesBegan(presses, with: event)
    }

    // MARK: shake
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) { if motion == .motionShake { print("shake began") } }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) { if motion == .motionShake { report("shake ended") } }

    func report(_ s: String) { status.text = s; print(s) }
}
