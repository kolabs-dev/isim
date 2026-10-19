// Sample: UIKit animation on isim — UIViewPropertyAnimator (start, pause, scrub, reverse, stop, springs),
// keyframe animations, layer property animations (corner radius, border), UIView.transition(with:) flips and
// UIView.transition(from:to:) cross dissolves. Buttons print what the animation is doing (presentation values).
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: AnimationsViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

func r(_ v: CGFloat) -> String { String(format: "%.0f", Double(v)) }

final class AnimationsViewController: UIViewController {
    let box = UIView(frame: CGRect(x: 40, y: 130, width: 100, height: 100))
    let card = UILabel(frame: CGRect(x: 40, y: 260, width: 140, height: 90))
    let front = UILabel(frame: CGRect(x: 220, y: 260, width: 140, height: 90))
    let back = UILabel(frame: CGRect(x: 220, y: 260, width: 140, height: 90))
    var animator: UIViewPropertyAnimator?
    var right = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Animations"
        view.backgroundColor = .systemBackground
        box.backgroundColor = .systemBlue
        box.accessibilityIdentifier = "box"
        view.addSubview(box)
        for (l, text, color) in [(card, "Front", UIColor.systemOrange), (front, "A", UIColor.systemGreen), (back, "B", UIColor.systemPurple)] {
            l.text = text
            l.textAlignment = .center
            l.textColor = .white
            l.font = .boldSystemFont(ofSize: 28)
            l.backgroundColor = color
            l.layer.cornerRadius = 12
            l.clipsToBounds = true
            view.addSubview(l)
        }
        card.accessibilityIdentifier = "card"
        front.accessibilityIdentifier = "viewA"
        back.accessibilityIdentifier = "viewB"
        back.isHidden = true

        let buttons: [(String, Selector)] = [("Animator", #selector(startAnimator)), ("Pause", #selector(pause)), ("Scrub", #selector(scrub)),
                                             ("Reverse", #selector(reverse)), ("Stop", #selector(stop)), ("Report", #selector(report)),
                                             ("Spring", #selector(spring)), ("Keyframes", #selector(keyframes)), ("Round", #selector(round)),
                                             ("Flip", #selector(flip)), ("Swap", #selector(swap)), ("Cubic", #selector(cubic))]
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        for row in stride(from: 0, to: buttons.count, by: 3) {
            let h = UIStackView()
            h.axis = .horizontal
            h.distribution = .fillEqually
            h.spacing = 8
            for (title, sel) in buttons[row..<min(row + 3, buttons.count)] {
                var config = UIButton.Configuration.gray()
                config.title = title
                let b = UIButton(configuration: config)
                b.accessibilityIdentifier = "btn-\(title)"
                b.addTarget(self, action: sel, for: .touchUpInside)
                h.addArrangedSubview(b)
            }
            grid.addArrangedSubview(h)
        }
        view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    // 2 s linear move across the screen with a corner radius change, interruptible
    @objc func startAnimator() {
        right.toggle()
        let target: CGFloat = right ? 240 : 40, radius: CGFloat = right ? 50 : 0
        let a = UIViewPropertyAnimator(duration: 2, curve: .linear) { [box] in
            box.frame.origin.x = target
            box.layer.cornerRadius = radius
        }
        a.addCompletion { [weak self] pos in
            guard let self else { return }
            print("animator finished at \(pos == .end ? "end" : pos == .start ? "start" : "current"), model x=\(r(self.box.frame.origin.x)) radius=\(r(self.box.layer.cornerRadius))")
        }
        a.startAnimation()
        animator = a
        print("animator started to x=\(r(target)), running \(a.isRunning)")
    }
    @objc func pause() {
        guard let a = animator else { return }
        a.pauseAnimation()
        print("paused: state \(a.state == .active ? "active" : "other"), running \(a.isRunning), fraction>0 \(a.fractionComplete > 0.05 && a.fractionComplete < 0.6)")
    }
    @objc func scrub() {
        guard let a = animator else { return }
        a.fractionComplete = 0.5
        report()
    }
    @objc func reverse() {
        guard let a = animator else { return }
        a.isReversed = true
        a.startAnimation()
        print("reversed, running \(a.isRunning)")
        right.toggle()
    }
    @objc func stop() {
        guard let a = animator else { return }
        a.stopAnimation(false)
        print("stopped: state \(a.state == .stopped ? "stopped" : "other"), model x between \(box.frame.origin.x > 45 && box.frame.origin.x < 235)")
        a.finishAnimation(at: .current)
    }
    @objc func report() {
        let p = box.layer.presentation() ?? box.layer
        print("presentation x=\(r(p.frame.origin.x)) y=\(r(p.frame.origin.y)) radius=\(r(p.cornerRadius)) border=\(r(p.borderWidth)) card width=\(r((card.layer.presentation() ?? card.layer).frame.width))")
    }
    @objc func spring() {
        let a = UIViewPropertyAnimator(duration: 0.8, dampingRatio: 0.5) { [box] in box.frame.origin.y = box.frame.origin.y == 130 ? 160 : 130 }
        a.addCompletion { [box] _ in print("spring done y=\(r(box.frame.origin.y))") }
        a.startAnimation()
    }
    @objc func cubic() {
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.6, delay: 0.2, options: [.curveEaseOut], animations: { [box] in
            box.alpha = box.alpha < 1 ? 1 : 0.5
        }, completion: { [box] pos in print("running animator done alpha=\(box.alpha) at \(pos == .end ? "end" : "other")") })
    }
    // x moves in the first half, y in the second half (linear calculation, curveLinear overall)
    @objc func keyframes() {
        let x0 = box.frame.origin.x
        UIView.animateKeyframes(withDuration: 1.2, delay: 0, options: [UIView.KeyframeAnimationOptions(rawValue: UIView.AnimationOptions.curveLinear.rawValue)], animations: { [box] in
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) { box.frame.origin.x = x0 + 100 }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) { box.frame.origin.y = 330 }
        }, completion: { [box] done in print("keyframes done \(done) x=\(r(box.frame.origin.x)) y=\(r(box.frame.origin.y))") })
    }
    @objc func round() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear], animations: { [box] in
            box.layer.cornerRadius = 40
            box.layer.borderWidth = 8
            box.layer.borderColor = UIColor.systemYellow.cgColor
        }, completion: { [box] _ in print("round done radius=\(r(box.layer.cornerRadius)) border=\(r(box.layer.borderWidth))") })
    }
    @objc func flip() {
        UIView.transition(with: card, duration: 0.8, options: [.transitionFlipFromLeft], animations: { [card] in
            card.text = card.text == "Front" ? "Back" : "Front"
            card.backgroundColor = card.text == "Back" ? .systemTeal : .systemOrange
        }, completion: { [card] _ in print("flip done: \(card.text ?? "")") })
    }
    @objc func swap() {
        let (from, to) = front.isHidden ? (back, front) : (front, back)
        UIView.transition(from: from, to: to, duration: 0.6, options: [.transitionCrossDissolve, .showHideTransitionViews]) { [front, back] _ in
            print("swap done: A hidden \(front.isHidden), B hidden \(back.isHidden), alphas \(front.alpha) \(back.alpha)")
        }
    }
}
