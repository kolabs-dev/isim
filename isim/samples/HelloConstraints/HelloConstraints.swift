// Sample: Auto Layout extras on isim — Visual Format Language (spacing, sizes, metrics, priorities, alignment),
// keyboardLayoutGuide (a bar that rides on the keyboard), registerForTraitChanges (iOS 17), readableContentGuide
// (narrower than the margins on wide screens), a constraint animation (layoutIfNeeded in an animation block) and a
// scroll view that dismisses the keyboard when dragged (keyboardDismissMode .onDrag).
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

final class ConstraintsViewController: UIViewController, UIScrollViewDelegate {
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

        // readable content width: the margins on an iPhone in portrait, at most 672 pt (Large text) and centred when wider
        let readable = UIView(); readable.backgroundColor = .systemPurple; readable.accessibilityIdentifier = "readable"
        readable.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(readable)
        NSLayoutConstraint.activate([
            readable.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            readable.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            readable.topAnchor.constraint(equalTo: dark.bottomAnchor, constant: 12), readable.heightAnchor.constraint(equalToConstant: 12)])

        // a constraint animation: the bar's height changes inside UIView.animate and layoutIfNeeded animates it
        let grower = UIView(); grower.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.6, alpha: 1); grower.accessibilityIdentifier = "grower"
        grower.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grower)
        let height = grower.heightAnchor.constraint(equalToConstant: 10)
        NSLayoutConstraint.activate([height, grower.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                                     grower.widthAnchor.constraint(equalToConstant: 60), grower.topAnchor.constraint(equalTo: readable.bottomAnchor, constant: 12)])
        let grow = UIButton(type: .system, primaryAction: UIAction(title: "Grow") { [weak self] _ in
            height.constant = height.constant < 50 ? 90 : 10
            UIView.animate(withDuration: 1.5, animations: { self?.view.layoutIfNeeded() }) { _ in print("grow done height=\(Int(grower.frame.height))") }
        })
        grow.accessibilityIdentifier = "grow"
        grow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grow)
        NSLayoutConstraint.activate([grow.leadingAnchor.constraint(equalTo: grower.trailingAnchor, constant: 20), grow.topAnchor.constraint(equalTo: grower.topAnchor)])

        // a scroll view that dismisses the keyboard when it is dragged
        let scroll = UIScrollView(); scroll.backgroundColor = .secondarySystemBackground; scroll.accessibilityIdentifier = "scroll"
        scroll.keyboardDismissMode = .onDrag
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let inner = UITextField(); inner.borderStyle = .roundedRect; inner.placeholder = "In the scroll view"; inner.accessibilityIdentifier = "inner"
        inner.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(inner)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: grower.topAnchor, constant: 110), scroll.heightAnchor.constraint(equalToConstant: 200),
            inner.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            inner.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            inner.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -400)])
        scroll.delegate = self
        let interactive = UIButton(type: .system, primaryAction: UIAction(title: "Interactive") { _ in
            scroll.keyboardDismissMode = .interactive; print("dismiss mode interactive")
        })
        interactive.accessibilityIdentifier = "interactive"
        interactive.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(interactive)
        NSLayoutConstraint.activate([interactive.leadingAnchor.constraint(equalTo: grow.trailingAnchor, constant: 20), interactive.topAnchor.constraint(equalTo: grow.topAnchor)])
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in print("keyboard will hide") }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { print("drag ended") }
    func box(_ color: UIColor, _ id: String) -> UIView {
        let v = UIView(); v.backgroundColor = color; v.accessibilityIdentifier = id
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        return v
    }
}
