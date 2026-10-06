// HelloSystem: an app's integration with the system around it (UIKit, scene-based).
// Home-screen quick actions (static + dynamic), alternate app icons, URL schemes and universal links,
// NSUserActivity (Spotlight), scene state restoration, beginBackgroundTask and BackgroundTasks.
import UIKit
import BackgroundTasks
import Network
import CoreSpotlight
import UniformTypeIdentifiers

let refreshTaskID = "dev.isim.samples.HelloSystem.refresh"
let processingTaskID = "dev.isim.samples.HelloSystem.cleanup"

func log(_ s: String) { NSLog("HelloSystem: %@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let keys = (launchOptions ?? [:]).keys.map { $0.rawValue }.sorted()
        log("didFinishLaunching state=\(application.applicationState == .background ? "background" : "foreground") options=\(keys)")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            log("refresh task ran (\(type(of: task))) state=\(DispatchQueue.main.sync { UIApplication.shared.applicationState == .background ? "background" : "foreground" })")
            task.expirationHandler = { log("refresh task expired") }
            UserDefaults.standard.set((UserDefaults.standard.integer(forKey: "refreshes")) + 1, forKey: "refreshes")
            task.setTaskCompleted(success: true)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskID, using: DispatchQueue.main) { task in
            log("processing task ran (\(type(of: task)))")
            task.expirationHandler = { log("processing task expired"); task.setTaskCompleted(success: false) }
        }
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
    func applicationDidEnterBackground(_ application: UIApplication) {
        log("entered background, time remaining \(application.backgroundTimeRemaining > 1e9 ? "unlimited" : String(Int(application.backgroundTimeRemaining.rounded())))")
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let vc = ViewController()
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        log("scene connected shortcut=\(connectionOptions.shortcutItem?.type ?? "none") urls=\(connectionOptions.urlContexts.map { $0.url.absoluteString }) activities=\(connectionOptions.userActivities.map { $0.activityType })")
        if let restored = session.stateRestorationActivity, let count = restored.userInfo?["count"] as? Int {
            vc.count = count
            log("restored count \(count)")
        }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = vc
        window = w
        w.makeKeyAndVisible()
        if let item = connectionOptions.shortcutItem { vc.status = "Launched by “\(item.localizedTitle)”" }
        if let ctx = connectionOptions.urlContexts.first { vc.status = "Launched with \(ctx.url.absoluteString)" }
        if let a = connectionOptions.userActivities.first { vc.status = "Launched to continue \(a.activityType)" }
    }
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let n = (shortcutItem.userInfo?["n"] as? NSNumber)?.intValue ?? 0
        log("performAction \(shortcutItem.type) “\(shortcutItem.localizedTitle)” n=\(n)")
        vc.status = "Quick action: \(shortcutItem.localizedTitle)"
        completionHandler(true)
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for c in URLContexts { log("openURLContexts \(c.url.absoluteString)"); vc.status = "Opened \(c.url.absoluteString)" }
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == CSSearchableItemActionType, let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            log("continue spotlight item \(id)")
            vc.status = "Spotlight item \(id)"
            return
        }
        log("continue \(userActivity.activityType) \(userActivity.webpageURL?.absoluteString ?? (userActivity.title ?? ""))")
        vc.status = userActivity.activityType == NSUserActivityTypeBrowsingWeb ? "Universal link \(userActivity.webpageURL?.path ?? "")" : "Continued \(userActivity.title ?? userActivity.activityType)"
    }
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let a = NSUserActivity(activityType: "dev.isim.samples.HelloSystem.state")
        a.addUserInfoEntries(from: ["count": vc.count])
        return a
    }
    func sceneDidEnterBackground(_ scene: UIScene) { log("scene background") }
    func sceneWillEnterForeground(_ scene: UIScene) { log("scene foreground") }
}

/// logs appearance changes (Settings / Control Center Dark Mode)
class AppearanceProbe: UIView {
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        log("appearance \(traitCollection.userInterfaceStyle == .dark ? "dark" : "light")")
    }
}

class ViewController: UIViewController {
    var count = 0 { didSet { countLabel?.text = "Count \(count)" } }
    var status = "Ready" { didSet { statusLabel?.text = status } }
    var statusLabel: UILabel?, countLabel: UILabel?
    var bgTask: UIBackgroundTaskIdentifier = .invalid

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let title = UILabel(); title.text = "System"; title.font = .systemFont(ofSize: 34, weight: .bold)
        let st = UILabel(); st.text = status; st.accessibilityIdentifier = "status"; st.numberOfLines = 2; st.textColor = .secondaryLabel
        let cl = UILabel(); cl.text = "Count \(count)"; cl.accessibilityIdentifier = "count"
        statusLabel = st; countLabel = cl
        view.addSubview(AppearanceProbe(frame: .zero))
        let stack = UIStackView(arrangedSubviews: [title, st, cl])
        stack.axis = .vertical; stack.spacing = 10; stack.alignment = .leading
        for (t, id, sel) in [("Count + 1", "bump", #selector(bump)), ("Add dynamic quick action", "addShortcut", #selector(addShortcut)),
                             ("Use dark icon", "altIcon", #selector(darkIcon)), ("Use default icon", "primaryIcon", #selector(primaryIcon)),
                             ("Begin background task", "bgTask", #selector(beginTask)), ("Schedule refresh + processing", "schedule", #selector(schedule)),
                             ("Index activity for Spotlight", "indexActivity", #selector(indexActivity)), ("Open hellosystem://self", "openURL", #selector(openSelf)),
                             ("Index items (CoreSpotlight)", "indexItems", #selector(indexItems))] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.titleLabel?.font = .systemFont(ofSize: 17)
            b.addTarget(self, action: sel, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])
        log("supportsAlternateIcons=\(UIApplication.shared.supportsAlternateIcons) alternateIconName=\(UIApplication.shared.alternateIconName ?? "nil") shortcutItems=\(UIApplication.shared.shortcutItems?.count ?? 0)")
    }
    let monitor = NWPathMonitor()
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        monitor.pathUpdateHandler = { p in log("network \(p.status == .satisfied ? "satisfied" : "unsatisfied")") }
        monitor.start(queue: .main)
    }
    @objc func bump() { count += 1; log("count \(count)") }
    @objc func addShortcut() {
        UIApplication.shared.shortcutItems = [UIApplicationShortcutItem(type: "dev.isim.samples.HelloSystem.favorites", localizedTitle: "Favorites",
                                                                        localizedSubtitle: "Dynamic", icon: UIApplicationShortcutIcon(systemImageName: "star.fill"),
                                                                        userInfo: ["n": 7 as NSNumber])]
        log("dynamic shortcut items \(UIApplication.shared.shortcutItems?.map { $0.type } ?? [])")
    }
    @objc func darkIcon() {
        UIApplication.shared.setAlternateIconName("DarkIcon") { error in
            log("setAlternateIconName DarkIcon error=\(error.map { "\($0)" } ?? "nil") now=\(UIApplication.shared.alternateIconName ?? "nil")")
        }
    }
    @objc func primaryIcon() {
        UIApplication.shared.setAlternateIconName(nil) { error in log("setAlternateIconName nil error=\(error.map { "\($0)" } ?? "nil")") }
        UIApplication.shared.setAlternateIconName("NoSuchIcon") { error in log("NoSuchIcon error=\((error as NSError?)?.code ?? 0)") }
    }
    @objc func beginTask() {
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "upload") { [weak self] in
            log("background task expired after \(Int(UIApplication.shared.backgroundTimeRemaining)) s left")
            if let t = self?.bgTask { UIApplication.shared.endBackgroundTask(t) }
            self?.bgTask = .invalid
        }
        log("began background task \(bgTask.rawValue)")
    }
    @objc func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        let p = BGProcessingTaskRequest(identifier: processingTaskID)
        p.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(r)
            try BGTaskScheduler.shared.submit(p)
        } catch { log("submit failed \(error)") }
        do { try BGTaskScheduler.shared.submit(BGAppRefreshTaskRequest(identifier: "not.permitted")) }
        catch let e as BGTaskScheduler.Error { log("unpermitted submit error code \(e.code.rawValue)") } catch {}
        BGTaskScheduler.shared.getPendingTaskRequests { reqs in log("pending \(reqs.map { $0.identifier }.sorted())") }
    }
    @objc func indexItems() {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = "Waffle recipe"
        attrs.contentDescription = "Crispy waffles in 20 minutes"
        attrs.keywords = ["breakfast", "waffles"]
        let gone = CSSearchableItemAttributeSet(contentType: .text); gone.title = "Old recipe"
        CSSearchableIndex.default().indexSearchableItems([CSSearchableItem(uniqueIdentifier: "recipe-waffles", domainIdentifier: "recipes", attributeSet: attrs),
                                                          CSSearchableItem(uniqueIdentifier: "recipe-old", domainIdentifier: "recipes.old", attributeSet: gone)]) { error in
            log("indexed items error=\(error.map { "\($0)" } ?? "nil")")
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["recipe-old"]) { _ in log("deleted old item") }
        }
    }
    @objc func indexActivity() {
        let a = NSUserActivity(activityType: "dev.isim.samples.HelloSystem.recipe")
        a.title = "Pancake recipe"
        a.userInfo = ["recipe": "pancakes"]
        a.keywords = ["breakfast", "pancakes"]
        a.isEligibleForSearch = true
        userActivity = a
        log("indexing activity")
    }
    @objc func openSelf() {
        let url = URL(string: "hellosystem://self?from=app")!
        log("canOpenURL \(UIApplication.shared.canOpenURL(url))")
        UIApplication.shared.open(url, options: [:]) { ok in log("open own scheme -> \(ok)") }
    }
}
