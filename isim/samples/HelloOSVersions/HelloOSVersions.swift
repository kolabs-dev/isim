// Sample: one app on every iOS version isim emulates (isim run ... --os 17|18|26|27).
// - reports UIDevice.systemVersion, ProcessInfo.operatingSystemVersion(String), isOperatingSystemAtLeast
// - `#available` / `if #available` (Swift) and `@available` (Objective-C, HelloOSVersionsObjC.m) for iOS 18, 26, 27
// - version-gated APIs: iOS 18 stdlib (Int128) and SwiftUI Tab/TabRole, iOS 26 UIGlassEffect, UIButton glass
//   configurations, SwiftUI glassEffect / .glass button style, iOS 27 SwiftUI toolbar visibility priority
// - the look: a UITabBarController (opaque bottom bar on 17/18, floating glass capsule on 26/27), an alert, a menu.
// Launch argument `swiftui` shows the SwiftUI version (TabView, glass effects) instead of the UIKit one.
import UIKit
import SwiftUI

@_silgen_name("hov_objc_available") func objcAvailable(_ major: Int32) -> Int32

func report() {
    let pi = ProcessInfo.processInfo, v = pi.operatingSystemVersion
    print("hov version \(UIDevice.current.systemVersion) process \(v.majorVersion).\(v.minorVersion).\(v.patchVersion) string \(pi.operatingSystemVersionString)")
    let at = { (m: Int) in pi.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: m, minorVersion: 0, patchVersion: 0)) }
    print("hov atLeast 17=\(at(17)) 18=\(at(18)) 26=\(at(26)) 27=\(at(27))")
    var s18 = false, s26 = false, s27 = false
    if #available(iOS 18, *) { s18 = true }
    if #available(iOS 26, *) { s26 = true }
    if #available(iOS 27.0, *) { s27 = true }
    print("hov swift available 18=\(s18) 26=\(s26) 27=\(s27)")
    if #unavailable(iOS 26) { print("hov swift unavailable 26=true") } else { print("hov swift unavailable 26=false") }
    print("hov objc available 18=\(objcAvailable(18)) 26=\(objcAvailable(26)) 27=\(objcAvailable(27))")
    // a SwiftStdlib 6.0 (iOS 18) API, behind its availability check like on a real device
    if #available(iOS 18, *) {
        let big = Int128(Int64.max) * 4 + 3
        print("hov stdlib18 Int128 \(big)")
    } else {
        print("hov stdlib18 fallback \(Int64.max / 2)")
    }
    // stdlib work that the stdlib itself gates on SwiftStdlib 5.x/6.x internally
    let text = "Café 🇧🇷 naïve ﬁ"
    print("hov stdlib strings \(text.count) \(text.unicodeScalars.count) \(text.utf8.count) \(text.lowercased()) \(String(text.reversed()))")
    print("hov stdlib collections \(Array(1...10).reduce(0, +)) \(Set([3, 1, 2]).sorted()) \([1: "a", 2: "b"].sorted { $0.key < $1.key }.map(\.value).joined())")
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        report()
        window = UIWindow(frame: UIScreen.main.bounds)
        if ProcessInfo.processInfo.arguments.contains("swiftui") {
            window?.rootViewController = UIHostingController(rootView: SwiftUIDemo())
        } else {
            let home = UINavigationController(rootViewController: HomeViewController())
            home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
            let other = UINavigationController(rootViewController: PlainViewController(name: "Library"))
            other.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "book"), tag: 1)
            let third = UINavigationController(rootViewController: PlainViewController(name: "Settings"))
            third.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
            let tabs = UITabBarController()
            tabs.viewControllers = [home, other, third]
            window?.rootViewController = tabs
        }
        window?.makeKeyAndVisible()
        return true
    }
}

/// A full-screen teal background, so screenshots show what the bars cover.
let backdrop = UIColor(red: 0.0, green: 0.6, blue: 0.6, alpha: 1)

final class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "OS \(UIDevice.current.systemVersion)"
        view.backgroundColor = backdrop
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: [
            UIAction(title: "First") { _ in print("hov menu first") }, UIAction(title: "Second") { _ in print("hov menu second") }]))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "more"
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 16; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: view.centerXAnchor), stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40)])
        let label = UILabel(); label.text = "iOS \(UIDevice.current.systemVersion)"; label.font = .systemFont(ofSize: 28, weight: .bold); label.textColor = .white
        label.accessibilityIdentifier = "version"
        stack.addArrangedSubview(label)
        // iOS 26: a glass button; earlier: a filled one (like an app that adopts Liquid Glass when available)
        let button: UIButton
        if #available(iOS 26, *) {
            button = UIButton(configuration: .prominentGlass(), primaryAction: UIAction(title: "Show Alert") { [weak self] _ in self?.alert() })
            print("hov api button glass")
        } else {
            button = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Show Alert") { [weak self] _ in self?.alert() })
            print("hov api button filled")
        }
        button.accessibilityIdentifier = "show-alert"
        stack.addArrangedSubview(button)
        // iOS 26: a UIGlassEffect platter
        if #available(iOS 26, *) {
            let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            glass.layer.cornerRadius = 24
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.widthAnchor.constraint(equalToConstant: 220).isActive = true
            glass.heightAnchor.constraint(equalToConstant: 64).isActive = true
            glass.accessibilityIdentifier = "glass-platter"
            stack.addArrangedSubview(glass)
            print("hov api UIGlassEffect yes")
        } else {
            print("hov api UIGlassEffect no")
        }
        let toggle = UISwitch(); toggle.isOn = true; toggle.accessibilityIdentifier = "switch"
        stack.addArrangedSubview(toggle)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let s = (view.viewWithTag(0)?.subviews.compactMap { $0 as? UIStackView }.first?.arrangedSubviews.last as? UISwitch)?.bounds.size ?? .zero
        print("hov switch size \(Int(s.width))x\(Int(s.height))")
        if let tb = tabBarController?.tabBar { print("hov tabbar frame \(Int(tb.frame.minX)) \(Int(tb.frame.minY)) \(Int(tb.frame.width)) \(Int(tb.frame.height))") }
    }
    func alert() {
        let a = UIAlertController(title: "Liquid Glass?", message: "This alert follows the emulated iOS version.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in print("hov alert cancel") })
        let ok = UIAlertAction(title: "OK", style: .default) { _ in print("hov alert ok") }
        a.addAction(ok); a.preferredAction = ok
        present(a, animated: true)
    }
}

final class PlainViewController: UIViewController {
    let name: String
    init(name: String) { self.name = name; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); title = name; view.backgroundColor = backdrop }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); print("hov tab \(name) appeared") }
}

// MARK: - SwiftUI

struct SwiftUIDemo: View {
    @State var selection = 0
    var body: some View {
        if #available(iOS 18, *) {
            TabView(selection: $selection) {
                Tab("Home", systemImage: "house", value: 0) { GlassDemo() }
                Tab("Library", systemImage: "book", value: 1) { Color(red: 0, green: 0.6, blue: 0.6).ignoresSafeArea() }
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) { Text("Search").accessibilityIdentifier("search-tab") }
            }
            .onAppear { print("hov swiftui Tab api yes") }
        } else {
            TabView(selection: $selection) {
                GlassDemo().tabItem { Label("Home", systemImage: "house") }.tag(0)
                Color(red: 0, green: 0.6, blue: 0.6).ignoresSafeArea().tabItem { Label("Library", systemImage: "book") }.tag(1)
            }
            .onAppear { print("hov swiftui Tab api no") }
        }
    }
}
struct GlassDemo: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0, green: 0.6, blue: 0.6).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("iOS \(UIDevice.current.systemVersion)").font(.largeTitle.bold()).foregroundStyle(.white)
                    if #available(iOS 26, *) {
                        GlassEffectContainer {
                            Text("Glass").font(.title2).padding(.horizontal, 30).padding(.vertical, 14)
                                .glassEffect(.regular, in: Capsule())
                                .accessibilityIdentifier("glass-text")
                        }
                        Button("Glass Button") { print("hov swiftui glass button") }
                            .buttonStyle(.glass).accessibilityIdentifier("glass-button")
                            .onAppear { print("hov swiftui glass api yes") }
                    } else {
                        Text("No glass").font(.title2).padding().background(.thinMaterial, in: Capsule())
                            .onAppear { print("hov swiftui glass api no") }
                    }
                    Button("Bordered") { print("hov swiftui bordered") }.buttonStyle(.borderedProminent).accessibilityIdentifier("bordered")
                }
            }
            .navigationTitle("Glass")
            .toolbar {
                if #available(iOS 27, *) {
                    ToolbarItem(placement: .topBarTrailing) { Button("Pin") { print("hov swiftui pin") } }.visibilityPriority(.high)
                } else {
                    ToolbarItem(placement: .topBarTrailing) { Button("Pin") { print("hov swiftui pin") } }
                }
            }
        }
    }
}
