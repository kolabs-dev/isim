// Sample: scene, window, screen and app members from the documentation sweep (#9), each logged with "sx".
// - the scene delegate's supported orientations (iOS 26), the orientation lock, Mac geometry preferences (UISceneError)
// - the status bar manager, windowing behaviours, system protection, pointer lock, activation conditions
// - Shake to Undo (script `shake`), protected data (isim boot: `lock` / `unlock`), Settings URLs, default-app check
// - screen modes, EDR headroom, the fixed coordinate space, the window's aspect-fit safe area guide
// - an activation action (iPhone: its alternate runs), the window drag interaction
import UIKit
import UserNotifications

func log(_ s: String) { print("sx \(s)") }
func n(_ v: CGFloat) -> String { String(format: "%.0f", v) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) { log("protected data will become unavailable \(application.isProtectedDataAvailable)") }
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) { log("protected data available \(application.isProtectedDataAvailable)") }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: ws)
        window?.rootViewController = ExtrasViewController()
        window?.makeKeyAndVisible()
        log("connected notification response \(options.notificationResponse == nil ? "none" : "some")")
    }
    // iOS 26: replaces the Info.plist orientations (none here: portrait only) for this scene
    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask { .allButUpsideDown }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) { log("continue \(userActivity.activityType) \(userActivity.targetContentIdentifier ?? "-")") }
}

final class ExtrasViewController: UIViewController {
    var count = 0
    var locked = false
    var light = false
    override var canBecomeFirstResponder: Bool { true }
    @available(iOS 26.0, *) override var prefersInterfaceOrientationLocked: Bool { locked }
    override var preferredStatusBarStyle: UIStatusBarStyle { light ? .lightContent : .default }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let alternate = UIAction(title: "Open Here") { _ in log("alternate action") }
        let open = UIWindowScene.ActivationAction(alternate: alternate) { _ in
            UIWindowScene.ActivationConfiguration(userActivity: NSUserActivity(activityType: "dev.isim.doc"))
        }
        let button = UIButton(type: .system, primaryAction: open)
        button.frame = CGRect(x: 20, y: 120, width: 200, height: 44)
        button.accessibilityIdentifier = "open"
        view.addSubview(button)
        let pad = UIView(frame: CGRect(x: 20, y: 200, width: 300, height: 120))
        pad.backgroundColor = .systemGray5
        if #available(iOS 26.0, *) { pad.addInteraction(UIWindowSceneDragInteraction()) }
        view.addSubview(pad)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        guard let window = view.window, let scene = window.windowScene else { return }
        let app = UIApplication.shared
        log("urls \(UIApplication.openSettingsURLString) \(UIApplication.openNotificationSettingsURLString) can open \(app.canOpenURL(URL(string: UIApplication.openSettingsURLString)!))")
        log("protected \(app.isProtectedDataAvailable) shake to edit \(app.applicationSupportsShakeToEdit)")
        if #available(iOS 18.2, *) { log("default browser \((try? app.isDefault(.webBrowser)) ?? true)") }
        if #available(iOS 27.0, *) { log("reduced resources \(app.systemPrefersReducedResourceUsage)") }

        let bar = scene.statusBarManager!
        log("status bar hidden \(bar.isStatusBarHidden) height \(n(bar.statusBarFrame.height)) style \(bar.statusBarStyle.rawValue)")
        light = true
        setNeedsStatusBarAppearanceUpdate()
        log("status bar style now \(bar.statusBarStyle.rawValue)")
        if #available(iOS 18.0, *) {
            log("windowing closable \(scene.windowingBehaviors?.isClosable ?? false) protection \(scene.systemProtectionManager?.isUserAuthenticationEnabled ?? true) pointer lock \(scene.pointerLockState == nil ? "none" : "some")")
        }

        // activation conditions: content with this identifier goes to this scene
        scene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate = NSPredicate(format: "SELF == 'doc-1'")
        let activity = NSUserActivity(activityType: "dev.isim.doc")
        activity.targetContentIdentifier = "doc-1"
        let request = UISceneSessionActivationRequest()
        request.userActivity = activity
        app.activateSceneSession(for: request) { error in log("activation error \(error)") }

        // screens
        let screen = scene.screen
        let mode = screen.preferredMode!
        log("modes \(screen.availableModes.count) preferred \(n(mode.size.width))x\(n(mode.size.height)) ratio \(n(mode.pixelAspectRatio)) current same \(screen.currentMode == mode)")
        log("edr \(n(screen.currentEDRHeadroom)) \(n(screen.potentialEDRHeadroom)) overscan \(screen.overscanCompensationInsets == .zero) latency \(n(screen.calibratedLatency)) mirrored \(screen.mirrored == nil) reference \(screen.referenceDisplayModeStatus == .notSupported)")
        let fixed = screen.fixedCoordinateSpace
        log("fixed bounds \(n(fixed.bounds.width))x\(n(fixed.bounds.height))")

        // the window's aspect-fit guide (iOS 26)
        if #available(iOS 26.0, *) {
            let guide = window.safeAreaAspectFitLayoutGuide
            guide.aspectRatio = 1
            window.layoutIfNeeded()
            let g = guide.layoutFrame, safe = window.safeAreaLayoutGuide.layoutFrame
            log("aspect fit \(n(g.width))x\(n(g.height)) square \(abs(g.width - g.height) < 1) fits \(abs(g.width - safe.width) < 1 || abs(g.height - safe.height) < 1) centred \(abs(g.midY - safe.midY) < 1)")
        }

        // Mac geometry preferences fail on iOS, as a UISceneError
        scene.requestGeometryUpdate(.Mac(systemFrame: CGRect(x: 0, y: 0, width: 500, height: 500))) { error in
            if let e = error as? UISceneError { log("geometry error \(e.code == .geometryRequestUnsupported)") } else { log("geometry error other \(error)") }
        }

        // Shake to Undo: an undoable change on the window's undo manager
        undoManager?.setActionName("Move")
        undoManager?.registerUndo(withTarget: self) { vc in vc.count -= 1; log("undone count \(vc.count)") }
        undoManager?.setActionName("Move")
        count += 1
        log("ready can undo \(undoManager?.canUndo ?? false) \(undoManager?.undoActionName ?? "")")
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [self] _ in
            guard let scene = view.window?.windowScene else { return }
            let p = scene.screen.fixedCoordinateSpace.convert(CGPoint(x: 10, y: 20), from: scene.screen.coordinateSpace)
            log("rotated \(scene.interfaceOrientation.rawValue) \(n(size.width))x\(n(size.height)) fixed point \(n(p.x)),\(n(p.y))")
            if #available(iOS 26.0, *), !locked {
                locked = true
                setNeedsUpdateOfPrefersInterfaceOrientationLocked()
                log("orientation locked \(scene.effectiveGeometry.isInterfaceOrientationLocked)")
            }
        }
    }
}
