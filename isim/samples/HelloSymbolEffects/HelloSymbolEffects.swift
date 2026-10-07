// Sample: SF Symbols effects on UIImageView (iOS 17: scale, disappear / appear, bounce, pulse, variable colour,
// replace content transitions; iOS 18: wiggle, rotate, breathe, periodic repeats; iOS 26: draw off / on).
// Each button starts an effect; the log reports completions and the image view's state.
import UIKit

func log(_ s: String) { print("HelloSymbolEffects: \(s)") }

final class EffectsViewController: UIViewController {
    func symbol(_ name: String, _ color: UIColor, _ x: CGFloat, _ id: String) -> UIImageView {
        let iv = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 50)))
        iv.tintColor = color; iv.contentMode = .center
        iv.frame = CGRect(x: x, y: 120, width: 100, height: 100); iv.accessibilityIdentifier = id
        view.addSubview(iv)
        return iv
    }
    var buttonY: CGFloat = 260
    func button(_ title: String, _ action: @escaping () -> Void) {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal); b.accessibilityIdentifier = title
        b.frame = CGRect(x: 20 + (buttonY >= 620 ? 190 : 0), y: buttonY >= 620 ? buttonY - 360 : buttonY, width: 170, height: 36)
        b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        view.addSubview(b); buttonY += 45
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let heart = symbol("heart.fill", .systemRed, 20, "heart")
        let star = symbol("star.fill", .systemBlue, 150, "star")
        let bell = symbol("bell.fill", .systemGreen, 280, "bell")
        func state(_ name: String, _ v: UIView) { log("\(name): transform identity \(v.transform.isIdentity), alpha \(String(format: "%.2f", v.alpha))") }

        button("scaleUp") { heart.addSymbolEffect(.scale.up) }
        button("scaleOff") { heart.removeSymbolEffect(ofType: .scale, completion: { c in log("scale removed \(c.isFinished)"); state("heart", heart) }) }
        button("hide") { star.addSymbolEffect(.disappear.down, completion: { c in log("disappeared \(c.isFinished)") }) }
        button("show") { star.addSymbolEffect(.appear, completion: { c in log("appeared \(c.isFinished)"); state("star", star) }) }
        button("bounce") {
            bell.addSymbolEffect(.bounce.up, options: .repeat(2)) { c in log("bounce finished \(c.isFinished)"); state("bell", bell) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { state("bouncing bell", bell) }
        }
        button("pulse") {
            heart.addSymbolEffect(.pulse) { c in log("pulse ended \(c.isFinished)") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                log("pulsing alpha below 1 \(heart.alpha < 0.99)")
                heart.removeSymbolEffect(ofType: .pulse) { c in log("pulse removed \(c.isFinished)"); state("heart", heart) }
            }
        }
        button("variable") {
            bell.addSymbolEffect(.variableColor.iterative.reversing, options: .nonRepeating) { c in log("variable color finished \(c.isFinished)") }
        }
        button("replace") {
            star.setSymbolImage(UIImage(systemName: "moon.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 50))!, contentTransition: .replace.downUp) { c in
                log("replaced \(c.isFinished), transition \(c.contentTransition != nil), image moon \(star.image?.description.contains("moon") ?? false)")
            }
        }
        button("wiggle") {
            if #available(iOS 18.0, *) {
                bell.addSymbolEffect(.wiggle.clockwise) { c in log("wiggle finished \(c.isFinished)") }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { state("wiggling bell", bell) }
            } else { log("wiggle unavailable") }
        }
        button("rotate") {
            if #available(iOS 18.0, *) {
                bell.addSymbolEffect(.rotate, options: .repeat(.continuous)) { c in log("rotate ended \(c.isFinished)") }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    state("rotating bell", bell)
                    bell.removeSymbolEffect(ofType: .rotate) { c in log("rotate removed \(c.isFinished)"); state("bell", bell) }
                }
            } else { log("rotate unavailable") }
        }
        button("breathe") {
            if #available(iOS 18.0, *) {
                heart.addSymbolEffect(.breathe.pulse, options: .repeat(.periodic(1, delay: 0.1))) { c in log("breathe finished \(c.isFinished)") }
            } else { log("breathe unavailable") }
        }
        button("drawOff") {
            if #available(iOS 26.0, *) {
                star.addSymbolEffect(.drawOff) { c in log("drawn off \(c.isFinished)") }
            } else { log("draw off unavailable") }
        }
        button("drawOn") {
            if #available(iOS 26.0, *) {
                star.addSymbolEffect(.drawOn) { c in log("drawn on \(c.isFinished)"); state("star", star) }
            } else { log("draw on unavailable") }
        }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = EffectsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
