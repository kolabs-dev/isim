// Sample: an Xcode-style storyboard app on isim — Main.storyboard (tab bar, navigation controllers, table view
// controller with prototype cells, show/present/embed/manual/unwind segues, controls with outlets, actions, outlet
// collections, user defined runtime attributes, Auto Layout), LaunchScreen.storyboard, xibs (a view controller and a
// table cell), a Settings.bundle, and UIFontPickerViewController. Everything is compiled by `isim build`.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Settings.bundle defaults are not visible until registered (as on iOS)
        UserDefaults.standard.register(defaults: ["name_preference": "Guest", "enabled_preference": true, "theme_preference": "system"])
        Settings.log("launch")
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            Settings.log("foreground")
        }
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

enum Settings {
    static func log(_ when: String) {
        let d = UserDefaults.standard
        print("settings(\(when)): name=\(d.string(forKey: "name_preference") ?? "nil") enabled=\(d.bool(forKey: "enabled_preference")) "
              + "theme=\(d.string(forKey: "theme_preference") ?? "nil") volume=\(d.double(forKey: "volume_preference")) "
              + "advanced=\(d.bool(forKey: "advanced_preference"))")
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // UISceneStoryboardFile: the window and the storyboard's initial view controller already exist
        let root = window?.rootViewController
        print("scene: window from storyboard: \(window != nil), root=\(root.map { String(describing: type(of: $0)) } ?? "nil"), "
              + "storyboard=\(root?.storyboard != nil)")
    }
}
