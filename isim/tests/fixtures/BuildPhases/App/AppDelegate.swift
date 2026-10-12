// BuildPhases fixture: Generated.swift does not exist in the source tree; the "Generate Constants" script phase
// (before Compile Sources) writes it into $(DERIVED_FILE_DIR) from Config/flavors.txt and the files of
// Config/codegen-inputs.xcfilelist, and it is compiled with this file.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let info = Bundle.main.path(forResource: "build-info", ofType: "txt") != nil ? "yes" : "no"
        print("BuildPhases: \(Generated.greeting) | \(Generated.flavors) | \(Generated.configuration) | build-info \(info)")
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }
}
