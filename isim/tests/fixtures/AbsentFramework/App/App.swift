// isim build's message for iOS frameworks isim does not have (issue #211). Without conditions this builds: the
// imports are behind #if, as `#if canImport` code would be. USE_ARKIT imports ARKit (not in isim yet), USE_GLKIT
// GLKit (deprecated in iOS 12: out of isim's scope).
import UIKit
#if USE_ARKIT
import ARKit
#endif
#if USE_GLKIT
import GLKit
#endif
#if canImport(ARKit)
let hasARKit = true
#else
let hasARKit = false
#endif

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("absent: canImport(ARKit) \(hasARKit) objc \(AbsentObjC())")
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
