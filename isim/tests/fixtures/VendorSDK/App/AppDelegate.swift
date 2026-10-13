// VendorSDK fixture: an app using a prebuilt dynamic XCFramework (Swift API from a .swiftinterface, Objective-C API
// from its headers, an open class subclassed across the library-evolution boundary).
import UIKit
import Vendor

final class AppWidget: VendorWidget {
    override func describe() -> String { "app " + super.describe() }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("VendorSDK: \(VendorSDK.greeting(for: "isim")) | \(VNDLegacy.name()) | \(AppWidget().describe())")
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
