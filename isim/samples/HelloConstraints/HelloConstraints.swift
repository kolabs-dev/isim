// Sample: Auto Layout extras on isim — Visual Format Language (spacing, sizes, metrics, priorities, alignment),
// keyboardLayoutGuide (a bar that rides on the keyboard), and registerForTraitChanges (iOS 17).
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ConstraintsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class ConstraintsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let a = box(.systemRed, "a"), b = box(.systemGreen, "b"), c = box(.systemBlue, "c")
        let views = ["a": a, "b": b, "c": c]
        var cs = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[a(60)]-[b(==a)]-gap-[c(>=40@750)]-|", options: [.alignAllTop, .alignAllBottom], metrics: ["gap": 30], views: views)
        cs += NSLayoutConstraint.constraints(withVisualFormat: "V:|-120-[a(44)]", options: [], metrics: nil, views: views)
        NSLayoutConstraint.activate(cs)
        print("vfl constraints \(cs.count)")

        let field = UITextField()
        field.borderStyle = .roundedRect; field.placeholder = "Type here"
        field.accessibilityIdentifier = "field"
        field.translatesAutoresizingMaskIntoConstraints = false
        let bar = UIView(); bar.backgroundColor = .systemOrange
        bar.accessibilityIdentifier = "bar"
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(field); view.addSubview(bar)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), field.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            field.topAnchor.constraint(equalTo: a.bottomAnchor, constant: 40),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor), bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44), bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)])

        let dark = UIButton(type: .system, primaryAction: UIAction(title: "Dark") { [weak self] _ in self?.view.overrideUserInterfaceStyle = .dark })
        dark.accessibilityIdentifier = "dark"
        dark.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dark)
        NSLayoutConstraint.activate([dark.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 20), dark.leadingAnchor.constraint(equalTo: field.leadingAnchor)])
        view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: UIView, previous: UITraitCollection) in
            print("style changed \(previous.userInterfaceStyle.rawValue) -> \(v.traitCollection.userInterfaceStyle.rawValue)")
        }
    }
    func box(_ color: UIColor, _ id: String) -> UIView {
        let v = UIView(); v.backgroundColor = color; v.accessibilityIdentifier = id
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        return v
    }
}
