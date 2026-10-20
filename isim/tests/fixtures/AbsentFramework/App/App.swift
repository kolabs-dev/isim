// isim build's message for iOS frameworks isim does not have (issue #211). Without conditions this builds: the
// imports are behind #if, as `#if canImport` code would be. USE_REALITYKIT imports RealityKit (not in isim yet), USE_GLKIT
// GLKit (deprecated in iOS 12: out of isim's scope).
import UIKit
#if USE_REALITYKIT
import RealityKit
#endif
#if USE_GLKIT
import GLKit
#endif
#if canImport(RealityKit)
let hasRealityKit = true
#else
let hasRealityKit = false
#endif

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("absent: canImport(RealityKit) \(hasRealityKit) objc \(AbsentObjC())")
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
