// RemotePackages fixture: Greet (remote, resolved from git tags or Package.resolved) -> Base (remote) + Vendor
// (remote binary target, downloaded and checksum-verified).
import Greet
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("RemotePackages: \(Greeting.line())")
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
