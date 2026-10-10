// Sample: corner curves on isim (UIKit / Core Animation) — CALayer.cornerCurve .circular (the default) next to
// .continuous (Apple's "squircle" corners, which ease into the straight edges), on standalone layers and on views,
// with masksToBounds and a border; and a capsule, which stays circular whatever the curve (and keeps its own colour
// when drawn after the views).
import UIKit

func log(_ s: String) { print("hco \(s)") }

final class ViewController: UIViewController {
    override func viewDidLoad() {
        view.backgroundColor = .white
        func square(_ curve: CALayerCornerCurve, x: CGFloat, y: CGFloat) -> CALayer {
            let l = CALayer()
            l.frame = CGRect(x: x, y: y, width: 160, height: 160)
            l.backgroundColor = UIColor.systemBlue.cgColor
            l.cornerRadius = 40
            l.cornerCurve = curve
            view.layer.addSublayer(l)
            return l
        }
        let circular = square(.circular, x: 20, y: 120)
        let continuous = square(.continuous, x: 210, y: 120)
        // views: a clipped red view with a border
        for (i, curve) in [CALayerCornerCurve.circular, .continuous].enumerated() {
            let v = UIView(frame: CGRect(x: 20 + CGFloat(i) * 190, y: 310, width: 160, height: 160))
            v.backgroundColor = .systemRed
            v.layer.cornerRadius = 40
            v.layer.cornerCurve = curve
            v.layer.borderWidth = 4
            v.layer.borderColor = UIColor.black.cgColor
            v.clipsToBounds = true
            v.accessibilityIdentifier = "view-\(curve.rawValue)"
            view.addSubview(v)
        }
        let capsule = CALayer()
        capsule.frame = CGRect(x: 20, y: 500, width: 350, height: 60)
        capsule.backgroundColor = UIColor.systemGreen.cgColor
        capsule.cornerRadius = 30
        capsule.cornerCurve = .continuous
        view.layer.addSublayer(capsule)
        log("curves \(circular.cornerCurve.rawValue) \(continuous.cornerCurve.rawValue) default \(CALayer().cornerCurve.rawValue)")
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
