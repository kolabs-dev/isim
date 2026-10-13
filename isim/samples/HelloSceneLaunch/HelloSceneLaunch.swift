// Sample: how a scene comes and goes (#188), each logged with "sl".
// - destructionConditions (iOS 26): HELLO_DESTROY=dismiss destroys the scene when the app goes home (the next
//   foreground connects a new one); HELLO_DESTROY=system makes the next launch discard the session
// - the window scene's focusSystem
// - connection options other frameworks add: appIntent (AppIntents), nfcEvent (CoreNFC), credentialSessionEvent
//   (SecureElementCredential), marketplaceDisplayOption (MarketplaceKit), shouldHandleActiveWorkoutRecovery
// - an app intent directed to the scene (UISceneAppIntent, AppIntentSceneDelegate)
// - applicationShouldRequestHealthAuthorization(_:) and HKHealthStore.handleAuthorizationForExtension
// - app entities annotated on views (appEntityIdentifier, appEntityUIElementProvider)
import UIKit
import AppIntents
import CoreNFC
import SecureElementCredential
import MarketplaceKit
import HealthKit

func log(_ s: String) { print("sl \(s)") }

struct NoteEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static let defaultQuery = NoteQuery()
    let id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}
struct NoteQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [NoteEntity] { identifiers.map(NoteEntity.init) }
}

struct OpenNoteIntent: AppIntent, UISceneAppIntent {
    static let title: LocalizedStringResource = "Open Note"
    static let openAppWhenRun = true
    @MainActor func performNavigation(forScene scene: UIScene) { log("navigation for scene") }
    @MainActor func perform() async throws -> some IntentResult {
        log("intent performed scene \(uiScene != nil) content \(contentIdentifier)")
        return .result()
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = HKHealthStore()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        log("discarded \(sceneSessions.count)")
    }
    func applicationShouldRequestHealthAuthorization(_ application: UIApplication) {
        log("health authorization requested")
        store.handleAuthorizationForExtension { ok, _ in
            let steps = HKQuantityType(.stepCount)
            Task { @MainActor in log("health handled \(ok) asked \(self.store.authorizationStatus(for: steps) != .notDetermined)") }
        }
    }
}

nonisolated(unsafe) var connections = 0

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, AppIntentSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        connections += 1
        let w = UIWindow(windowScene: ws)
        let vc = UIViewController(); vc.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 120, width: 300, height: 40)); label.text = "Connection \(connections)"
        vc.view.addSubview(label)
        label.accessibilityIdentifier = "note"
        label.appEntityIdentifier = EntityIdentifier(for: NoteEntity(id: "n1"))
        let list = UIView(frame: CGRect(x: 20, y: 180, width: 300, height: 80)); list.accessibilityIdentifier = "notes"
        list.appEntityUIElementProvider = { v, _ in
            [AppEntityUIElement(NoteEntity(id: "n2"), bounds: CGRect(x: 0, y: 0, width: 300, height: 40), state: .selected),
             AppEntityUIElement(identifier: EntityIdentifier(for: NoteEntity.self, identifier: "n3"), bounds: CGRect(x: 0, y: 40, width: 300, height: 40))]
        }
        vc.view.addSubview(list)
        w.rootViewController = vc
        w.makeKeyAndVisible()
        window = w
        if #available(iOS 26.0, *) {
            switch ProcessInfo.processInfo.environment["HELLO_DESTROY"] {
            case "dismiss": scene.destructionConditions = [.userInitiatedDismissal]
            case "system": scene.destructionConditions = [.systemDisconnection]
            default: break
            }
        }
        var conditions = 0
        if #available(iOS 26.0, *) { conditions = scene.destructionConditions.count }
        log("connected \(connections) conditions \(conditions) restored \(session.stateRestorationActivity != nil)")
        log("focus system \(ws.focusSystem != nil)")
        if #available(iOS 17.4, *) {
            if let e = options.nfcEvent { log("nfc \(e)") }
            if let e = options.credentialSessionEvent { log("credential \(e)") }
            if let o = options.marketplaceDisplayOption {
                if case .productPage(let item, let version) = o { log("marketplace product \(item) \(version.map(String.init) ?? "-")") }
                if case .searchResults(let q) = o { log("marketplace search \(q)") }
                if case .authentication(let a) = o { log("marketplace auth \(a)") }
            }
        }
        if #available(iOS 26.0, *), options.shouldHandleActiveWorkoutRecovery { log("workout recovery") }
        if let i = options.appIntent { log("launch intent \(type(of: i))") }
        log("ready")
    }
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let a = NSUserActivity(activityType: "dev.isim.samples.note"); a.title = "note"; return a
    }
    func sceneDidDisconnect(_ scene: UIScene) { log("disconnected") }
    func sceneDidEnterBackground(_ scene: UIScene) { log("background") }
    func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent) {
        log("scene will perform \(type(of: appIntent))")
    }
}
