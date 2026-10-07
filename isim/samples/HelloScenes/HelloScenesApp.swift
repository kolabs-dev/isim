// HelloScenes: SwiftUI app-level APIs — several scenes in App.body, @UIApplicationDelegateAdaptor (with its own
// scene delegate class), @SceneStorage restored across launches, .userActivity / .onContinueUserActivity
// (Spotlight), .backgroundTask(.appRefresh) and openWindow / dismissWindow.
import SwiftUI
import BackgroundTasks

func log(_ s: String) { NSLog("HelloScenes: %@", s) }
let refreshID = "dev.isim.samples.HelloScenes.refresh"
let activityType = "dev.isim.samples.HelloScenes.recipe"

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        log("adaptor didFinishLaunching (\(application.applicationState == .background ? "background" : "foreground"))")
        return true
    }
    func applicationDidEnterBackground(_ application: UIApplication) { log("adaptor didEnterBackground") }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: session.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        log("scene delegate quick action \(shortcutItem.type)")
        completionHandler(true)
    }
}

@main
struct HelloScenesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .backgroundTask(.appRefresh(refreshID)) {
            log("SwiftUI background refresh ran")
        }
        WindowGroup(id: "detail") {
            DetailView()
        }
    }
}

struct ContentView: View {
    @SceneStorage("count") var count = 0
    @State var status = "Ready"
    @Environment(\.openWindow) var openWindow
    @Environment(\.supportsMultipleWindows) var multi
    var body: some View {
        NavigationStack {
            List {
                Text("Count \(count)").accessibilityIdentifier("count")
                Text(status).accessibilityIdentifier("status")
                Button("Count + 1") { count += 1 }.accessibilityIdentifier("bump")
                Button("Schedule refresh") {
                    do { try BGTaskScheduler.shared.submit(BGAppRefreshTaskRequest(identifier: refreshID)); log("scheduled refresh") }
                    catch { log("schedule failed \(error)") }
                }.accessibilityIdentifier("schedule")
                Button("Open detail window") { log("supportsMultipleWindows \(multi)"); openWindow(id: "detail") }.accessibilityIdentifier("openDetail")
            }
            .navigationTitle("Scenes")
        }
        .userActivity(activityType) { a in
            a.title = "Scenes recipe"
            a.isEligibleForSearch = true
            a.userInfo = ["recipe": "pancakes"]
        }
        .onContinueUserActivity(activityType) { a in
            log("continued \(a.title ?? "") \(a.userInfo?["recipe"] as? String ?? "")")
            status = "Continued \(a.title ?? "")"
        }
    }
}

struct DetailView: View {
    @Environment(\.dismissWindow) var dismissWindow
    var body: some View {
        VStack(spacing: 20) {
            Text("Detail window").font(.largeTitle).accessibilityIdentifier("detailTitle")
            Button("Close") { dismissWindow() }.accessibilityIdentifier("closeDetail")
        }
    }
}
