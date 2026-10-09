// Sample: iOS 27 scenes on isim (UIKit, scene-based, iPad with multiple windows) — a scene accessory for an external
// display (registerSceneAccessory(.externalNonInteractive(sceneConfiguration:userInfo:)), isAvailable observed in
// updateProperties, isEnabled, the accessory scene's sceneAccessoryUserInfo), the manifest's external display
// configuration before iOS 27, UIScreen.screens and its notifications, UIWindowScene.closureConfirmation (a custom
// cancel action, the default Close), and extendStateRestoration / completeStateRestoration around an asynchronous
// restore (the launch screen stays up meanwhile).
import UIKit

func log(_ s: String) { print("hs27 \(s)") }
extension Notification.Name { static let scoreChanged = Notification.Name("hs27.score") }
var score = 0 { didSet { NotificationCenter.default.post(name: .scoreChanged, object: nil) } }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if #available(iOS 27, *) { log("ios27 yes") } else { log("ios27 no") }
        NotificationCenter.default.addObserver(forName: UIScreen.didConnectNotification, object: nil, queue: nil) { note in
            let s = note.object as? UIScreen
            log("screen connected \(Int(s?.bounds.width ?? 0))x\(Int(s?.bounds.height ?? 0)) scale \(Int(s?.scale ?? 0)), screens \(UIScreen.screens.count)")
        }
        NotificationCenter.default.addObserver(forName: UIScreen.didDisconnectNotification, object: nil, queue: nil) { _ in
            log("screen disconnected, screens \(UIScreen.screens.count)")
        }
        return true
    }
    func application(_ application: UIApplication, didDiscardSceneSessions sessions: Set<UISceneSession>) {
        log("discarded \(sessions.count) session(s)")
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let n = UIApplication.shared.openSessions.filter { $0.role == .windowApplication }.count
        log("window \(n) connected")
        let w = UIWindow(windowScene: ws)
        w.rootViewController = UINavigationController(rootViewController: MatchViewController(window: n))
        window = w
        w.makeKeyAndVisible()
        if #available(iOS 27, *) {
            let keep = UIAlertAction(title: "Keep Playing", style: .cancel) { _ in log("window \(n) kept") }
            ws.closureConfirmation = UISceneClosureConfirmation(title: "Close Match \(n)?", message: "The score is kept on the other windows.", actions: [keep])
        }
        if n == 1 {
            // restoring takes a moment (data loaded asynchronously): the launch screen stays until it completes
            scene.extendStateRestoration()
            log("restoration extended")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                score = 2
                log("restoration completed score \(score)")
                scene.completeStateRestoration()
            }
        }
    }
    func sceneDidDisconnect(_ scene: UIScene) { log("window disconnected") }
}

/// the scene on the external display: from the accessory (iOS 27) or the manifest's configuration
final class BoardSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        var match = "Display Board"
        if #available(iOS 27, *), let info = options.sceneAccessoryUserInfo as? [String: String], let m = info["match"] { match = m }
        let role = session.role == .windowExternalDisplayNonInteractive ? "external non-interactive" : session.role.rawValue
        log("board connected \(match) (\(session.configuration.name ?? "-")), role \(role), screen \(Int(ws.screen.bounds.width))x\(Int(ws.screen.bounds.height)), main \(ws.screen == UIScreen.main)")
        let w = UIWindow(windowScene: ws)
        w.rootViewController = BoardViewController(match: match)
        window = w
        w.makeKeyAndVisible()
        let mainKey = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.contains { $0.session.role == .windowApplication && $0.keyWindow != nil }
        log("board window \(Int(w.frame.width))x\(Int(w.frame.height)) key \(w.isKeyWindow), the device keeps its key window \(mainKey)")
    }
    func sceneDidBecomeActive(_ scene: UIScene) { log("board active") }
    func sceneDidDisconnect(_ scene: UIScene) { log("board disconnected") }
}

final class BoardViewController: UIViewController {
    let match: String
    let label = UILabel()
    init(match: String) { self.match = match; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        view.backgroundColor = .systemYellow
        label.font = .systemFont(ofSize: 96, weight: .heavy)
        label.textAlignment = .center
        label.accessibilityIdentifier = "board-score"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        update()
        NotificationCenter.default.addObserver(forName: .scoreChanged, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.update() } }
    }
    func update() { label.text = "\(match) \(score):0" }
}

final class MatchViewController: UIViewController {
    let number: Int
    let status = UILabel(), scoreLabel = UILabel()
    var registration: AnyObject?
    init(window: Int) { number = window; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        title = "Match \(number)"
        view.backgroundColor = .systemBackground
        status.accessibilityIdentifier = "accessory-status"
        scoreLabel.accessibilityIdentifier = "score"
        scoreLabel.font = .systemFont(ofSize: 48, weight: .bold)
        let goal = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Goal") { _ in score += 1; log("goal score \(score)") })
        goal.accessibilityIdentifier = "goal"
        let open = UIButton(configuration: .bordered(), primaryAction: UIAction(title: "New Window") { _ in
            UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest()) { e in log("new window error \(e.localizedDescription)") }
        })
        open.accessibilityIdentifier = "new-window"
        let display = UISwitch(frame: .zero, primaryAction: UIAction { [weak self] a in
            guard #available(iOS 27, *), let r = self?.registration as? UISceneAccessoryRegistration, let sw = a.sender as? UISwitch else { return }
            r.isEnabled = sw.isOn
            log("accessory enabled \(r.isEnabled)")
        })
        display.isOn = true
        display.accessibilityIdentifier = "accessory-enabled"
        let stack = UIStackView(arrangedSubviews: [scoreLabel, goal, open, status, display])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: view.centerXAnchor), stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        NotificationCenter.default.addObserver(forName: .scoreChanged, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.showScore() } }
        showScore()
        status.text = "External display: unavailable"

        if #available(iOS 27, *), number == 1 {
            let config = UISceneConfiguration(name: "Scoreboard", sessionRole: .windowExternalDisplayNonInteractive)
            config.delegateClass = BoardSceneDelegate.self
            registration = registerSceneAccessory(.externalNonInteractive(sceneConfiguration: config, userInfo: ["match": "Final"]))
        }
    }
    func showScore() { scoreLabel.text = "\(score):0" }

    @available(iOS 26, *)
    override func updateProperties() {
        super.updateProperties()
        guard #available(iOS 27, *), let r = registration as? UISceneAccessoryRegistration else { return }
        status.text = "External display: \(r.isAvailable ? "available" : "unavailable")"
        log("accessory available \(r.isAvailable) enabled \(r.isEnabled)")
    }
}
