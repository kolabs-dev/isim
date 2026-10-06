// Sample: rotation on isim — Info.plist supported orientations, UIDevice orientation notifications,
// viewWillTransition(to:with:) with a coordinator, size classes, safe areas on the sides in landscape,
// a view controller that locks to portrait, and UIWindowScene.requestGeometryUpdate.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: RotationViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class RotationViewController: UIViewController {
    let info = UILabel(), bar = UIView()
    var portraitOnly = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Rotation"
        view.backgroundColor = .systemBackground
        info.numberOfLines = 0
        info.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        info.translatesAutoresizingMaskIntoConstraints = false
        info.accessibilityIdentifier = "info"
        bar.backgroundColor = .systemTeal
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.accessibilityIdentifier = "bar"
        let force = UIButton(type: .system, primaryAction: UIAction(title: "Force landscape") { [weak self] _ in
            self?.view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { e in print("geometry error \(e.localizedDescription)") }
        })
        force.accessibilityIdentifier = "force"
        let lock = UIButton(type: .system, primaryAction: UIAction(title: "Lock portrait") { [weak self] _ in
            self?.portraitOnly = true
            self?.setNeedsUpdateOfSupportedInterfaceOrientations()
        })
        lock.accessibilityIdentifier = "lock"
        let stack = UIStackView(arrangedSubviews: [info, force, lock])
        stack.axis = .vertical; stack.spacing = 12; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar); view.addSubview(stack)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: g.leadingAnchor), bar.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: g.bottomAnchor), bar.heightAnchor.constraint(equalToConstant: 30),
            stack.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16), stack.topAnchor.constraint(equalTo: g.topAnchor, constant: 16)])
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            print("device orientation \(UIDevice.current.orientation.rawValue)")
        }
        refresh()
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { portraitOnly ? .portrait : .allButUpsideDown }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        print("will transition to \(Int(size.width))x\(Int(size.height))")
        coordinator.animate(alongsideTransition: { _ in }, completion: { [weak self] _ in
            guard let self else { return }
            self.refresh()
            print("transitioned: view \(Int(self.view.bounds.width))x\(Int(self.view.bounds.height)), safe left \(Int(self.view.safeAreaInsets.left)) bottom \(Int(self.view.safeAreaInsets.bottom)), scene \(self.view.window?.windowScene?.interfaceOrientation.rawValue ?? -1)")
        })
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        print("traits h=\(traitCollection.horizontalSizeClass.rawValue) v=\(traitCollection.verticalSizeClass.rawValue)")
    }
    func refresh() {
        let s = UIScreen.main.bounds.size
        info.text = "screen \(Int(s.width))x\(Int(s.height))\nlandscape \(s.width > s.height)"
    }
}
