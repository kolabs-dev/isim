// Sample: scenes and multiple windows on isim (UIKit, scene-based) — requestSceneSessionActivation with a user
// activity and activation options (split view, prominent), iOS 17 activateSceneSession(for:), size restrictions,
// destruction requests and discarded sessions, scene lifecycle notifications, didUpdateCoordinateSpace (split view
// and rotation), per-scene traits, UIScene.open, session userInfo / state restoration across launches, and UIDevice
// (battery, identifierForVendor).
import UIKit

let detailType = "dev.isim.samples.HelloWindows.detail"
func log(_ s: String) { print("HelloWindows: \(s)") }
func sizeClass(_ c: UIUserInterfaceSizeClass) -> String { c == .compact ? "compact" : c == .regular ? "regular" : "unspecified" }
func orientation(_ o: UIInterfaceOrientation) -> String { o.isLandscape ? "landscape" : "portrait" }
func shortID(_ s: UISceneSession) -> String { s.userInfo?["name"] as? String ?? "?" }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log("supportsMultipleScenes \(application.supportsMultipleScenes)")
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        log("battery \(d.batteryLevel) state \(d.batteryState.rawValue), vendor \(d.identifierForVendor?.uuidString ?? "nil"), proximity \(d.proximityState)")
        let names: [(Notification.Name, String)] = [(UIScene.willConnectNotification, "willConnect"), (UIScene.didActivateNotification, "didActivate"),
            (UIScene.willDeactivateNotification, "willDeactivate"), (UIScene.didEnterBackgroundNotification, "didEnterBackground"),
            (UIScene.willEnterForegroundNotification, "willEnterForeground"), (UIScene.didDisconnectNotification, "didDisconnect")]
        for (n, label) in names {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: nil) { note in
                if let s = note.object as? UIScene { log("notification \(label) \(shortID(s.session))") }
            }
        }
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let detail = options.userActivities.contains { $0.activityType == detailType } || session.configuration.name == "Detail"
        let c = UISceneConfiguration(name: detail ? "Detail" : "Default Configuration", sessionRole: session.role)
        c.delegateClass = detail ? DetailSceneDelegate.self : SceneDelegate.self
        return c
    }
    func application(_ application: UIApplication, didDiscardSceneSessions sessions: Set<UISceneSession>) {
        log("discarded \(sessions.count) session(s)")
    }
}

/// shared by the scene delegates: lifecycle and geometry logging
class BaseSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func sceneDidBecomeActive(_ scene: UIScene) { log("\(shortID(scene.session)) active") }
    func sceneWillResignActive(_ scene: UIScene) { log("\(shortID(scene.session)) resign active") }
    func sceneDidEnterBackground(_ scene: UIScene) { log("\(shortID(scene.session)) background") }
    func sceneWillEnterForeground(_ scene: UIScene) { log("\(shortID(scene.session)) foreground") }
    func sceneDidDisconnect(_ scene: UIScene) { log("\(shortID(scene.session)) disconnected") }
    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        let b = windowScene.coordinateSpace.bounds
        log("\(shortID(windowScene.session)) geometry \(Int(previousCoordinateSpace.bounds.width)) -> \(Int(b.width)) x \(Int(b.height)), \(orientation(previousInterfaceOrientation)) -> \(orientation(windowScene.interfaceOrientation)), size class \(sizeClass(previousTraitCollection.horizontalSizeClass)) -> \(sizeClass(windowScene.traitCollection.horizontalSizeClass)), frame x \(Int(windowScene.effectiveGeometry.systemFrame.minX))")
    }
}

final class SceneDelegate: BaseSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        if session.userInfo?["name"] == nil { session.userInfo = ["name": "main\(UIApplication.shared.openSessions.count)"] }
        log("\(shortID(session)) connected (\(session.configuration.name ?? "-")), restored \(session.stateRestorationActivity?.userInfo?["count"] as? Int ?? 0)")
        let w = UIWindow(windowScene: ws)
        w.rootViewController = MainViewController(count: session.stateRestorationActivity?.userInfo?["count"] as? Int ?? 0)
        window = w
        w.makeKeyAndVisible()
    }
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let a = NSUserActivity(activityType: "dev.isim.samples.HelloWindows.main")
        a.userInfo = ["count": (window?.rootViewController as? MainViewController)?.count ?? 0]
        return a
    }
}
final class DetailSceneDelegate: BaseSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let item = (options.userActivities.first?.userInfo?["item"] as? Int) ?? (session.stateRestorationActivity?.userInfo?["item"] as? Int) ?? 0
        if session.userInfo?["name"] == nil { session.userInfo = ["name": "detail\(item)", "item": item] }
        ws.sizeRestrictions?.minimumSize = CGSize(width: 500, height: 400)
        ws.title = "Detail \(item)"
        log("\(shortID(session)) connected (\(session.configuration.name ?? "-")) for \(options.userActivities.first?.activityType ?? "restoration"), item \(item), size restrictions \(ws.sizeRestrictions.map { "\(Int($0.minimumSize.width))" } ?? "nil")")
        let w = UIWindow(windowScene: ws)
        w.rootViewController = DetailViewController(item: item)
        window = w
        w.makeKeyAndVisible()
    }
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let a = NSUserActivity(activityType: detailType)
        a.userInfo = ["item": scene.session.userInfo?["item"] as? Int ?? 0]
        return a
    }
}

final class MainViewController: UIViewController {
    var count: Int
    init(count: Int) { self.count = count; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    func button(_ title: String, _ id: String, _ y: CGFloat, _ action: @escaping () -> Void) {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal); b.accessibilityIdentifier = id
        b.frame = CGRect(x: 20, y: y, width: 220, height: 44)
        b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        view.addSubview(b)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 60, width: 240, height: 30)); label.text = "Main"; label.accessibilityIdentifier = "mainTitle"
        view.addSubview(label)
        button("Open detail", "openDetail", 100) { [unowned self] in
            let a = NSUserActivity(activityType: detailType); a.userInfo = ["item": 7]
            let o = UIScene.ActivationRequestOptions(); o.requestingScene = view.window?.windowScene
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: a, options: o) { e in
                log("open detail failed: \((e as NSError).domain) \((e as NSError).code)")
            }
        }
        button("Open prominent", "openProminent", 150) {
            let r = UISceneSessionActivationRequest(role: .windowApplication)
            let o = UIWindowScene.ActivationRequestOptions(); o.preferredPresentationStyle = .prominent
            r.options = o
            UIApplication.shared.activateSceneSession(for: r) { e in log("prominent failed: \((e as NSError).code)") }
        }
        button("Count", "count", 200) { [unowned self] in count += 1; log("count \(count)") }
        button("Show all", "showAll", 250) {
            let main = UIApplication.shared.openSessions.first { ($0.userInfo?["name"] as? String) == "main1" }
            UIApplication.shared.requestSceneSessionActivation(main, userActivity: nil, options: nil) { e in log("activation failed: \(e)") }
        }
        button("Show detail", "showDetail", 450) {
            let detail = UIApplication.shared.openSessions.first { ($0.userInfo?["name"] as? String)?.hasPrefix("detail") == true }
            UIApplication.shared.requestSceneSessionActivation(detail, userActivity: nil, options: nil) { e in log("activation failed: \(e)") }
        }
        button("Open URL", "openURL", 300) { [unowned self] in
            view.window?.windowScene?.open(URL(string: "isimwindows-unknown://x")!, options: nil) { ok in log("scene open url \(ok)") }
        }
        button("Landscape", "landscape", 350) { [unowned self] in
            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { e in log("geometry error \(e)") }
        }
        button("Sessions", "sessions", 400) {
            let app = UIApplication.shared
            let names = app.openSessions.map { shortID($0) }.sorted()
            let states = app.connectedScenes.map { "\(shortID($0.session))=\($0.activationState.rawValue)" }.sorted()
            log("open sessions \(names), scenes \(states)")
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let ws = view.window?.windowScene {
            log("\(shortID(ws.session)) window \(Int(view.window!.frame.minX)) \(Int(view.window!.frame.width)), size class \(sizeClass(traitCollection.horizontalSizeClass))")
        }
    }
}
final class DetailViewController: UIViewController {
    let item: Int
    init(item: Int) { self.item = item; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemYellow
        let label = UILabel(frame: CGRect(x: 20, y: 60, width: 240, height: 30)); label.text = "Detail \(item)"; label.accessibilityIdentifier = "detailTitle"
        view.addSubview(label)
        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal); close.accessibilityIdentifier = "closeDetail"
        close.frame = CGRect(x: 20, y: 100, width: 200, height: 44)
        close.addAction(UIAction { [unowned self] _ in
            guard let session = view.window?.windowScene?.session else { return }
            let o = UIWindowSceneDestructionRequestOptions(); o.windowDismissalAnimation = .commit
            UIApplication.shared.requestSceneSessionDestruction(session, options: o) { e in log("destroy failed \(e)") }
        }, for: .primaryActionTriggered)
        view.addSubview(close)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log("detail window \(Int(view.window!.frame.minX)) \(Int(view.window!.frame.width)), size class \(sizeClass(traitCollection.horizontalSizeClass))")
    }
}
