// Sample: appearance and traits on isim (UIKit) — the iOS 17 trait system (custom traits, traitOverrides,
// registerForTraitChanges, UITraitCollection(mutations:)), overrideUserInterfaceStyle propagation (children, presented
// controllers), dynamic colors and images (asset catalog Any/Dark/High Contrast, UIImageAsset), the accent color as
// the default tint, live appearance and contrast changes, materials and vibrancy per appearance, UIAppearance
// proxies for controls and bar items (per-state setters), memory warnings.
import UIKit

func hex(_ c: UIColor?) -> String {
    guard let c else { return "nil" }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
}
func styleName(_ s: UIUserInterfaceStyle) -> String { s == .dark ? "dark" : s == .light ? "light" : "unspecified" }

// MARK: - A custom trait (iOS 17)
enum Theme: Int { case plain, ocean, forest }
struct ThemeTrait: UITraitDefinition {
    static let defaultValue = Theme.plain
    static let affectsColorAppearance = true
    static let name = "Theme"
}
extension UITraitCollection { var theme: Theme { self[ThemeTrait.self] } }
extension UIMutableTraits { var theme: Theme { get { self[ThemeTrait.self] } set { self[ThemeTrait.self] = newValue } } }
/// a dynamic color that follows the custom trait (and the appearance)
let themeColor = UIColor { t in
    switch t.theme {
    case .ocean: return t.userInterfaceStyle == .dark ? UIColor(red: 0, green: 0.2, blue: 0.6, alpha: 1) : UIColor(red: 0, green: 0.4, blue: 1, alpha: 1)
    case .forest: return UIColor(red: 0, green: 0.6, blue: 0.2, alpha: 1)
    case .plain: return .systemGray
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // UIAppearance: plain and per-state setters, bar items, containment
        UISwitch.appearance().onTintColor = .systemPurple
        UIButton.appearance(whenContainedInInstancesOf: [ControlsView.self]).setTitleColor(.systemPink, for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.systemRed], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.systemBlue], for: .selected)
        UIProgressView.appearance().progressTintColor = .systemGreen
        UIBarButtonItem.appearance().tintColor = .systemTeal
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.systemIndigo], for: .normal)
        UILabel.appearance(whenContainedInInstancesOf: [ControlsView.self]).textColor = .systemBrown
        traitFacts()
        let nav = UINavigationController(rootViewController: AppearanceViewController())
        nav.isToolbarHidden = false
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) { print("memory warning: app delegate") }

    /// the trait collection API, printed once
    func traitFacts() {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        print("traits: style-only \(styleName(dark.userInterfaceStyle)), idiom \(dark.userInterfaceIdiom.rawValue), size class \(dark.horizontalSizeClass.rawValue)")
        let merged = UITraitCollection(traitsFrom: [dark, UITraitCollection(horizontalSizeClass: .compact), UITraitCollection(userInterfaceStyle: .light)])
        print("traits: merged \(styleName(merged.userInterfaceStyle)) h\(merged.horizontalSizeClass.rawValue)")
        let elevated = dark.modifyingTraits { $0.userInterfaceLevel = .elevated }
        print("traits: modified level \(elevated.userInterfaceLevel.rawValue) keeps \(styleName(elevated.userInterfaceStyle))")
        print("traits: contains \(elevated.containsTraits(in: dark)) / \(dark.containsTraits(in: elevated)), color differs \(dark.hasDifferentColorAppearance(comparedTo: UITraitCollection(userInterfaceStyle: .light)))")
        let custom = UITraitCollection { $0.theme = .ocean; $0.userInterfaceStyle = .dark }
        print("traits: custom \(custom.theme), default \(UITraitCollection().theme), color \(hex(themeColor.resolvedColor(with: custom)))")
        let hc = UITraitCollection(traitsFrom: [dark, UITraitCollection(accessibilityContrast: .high)])
        print("colors: systemBlue light \(hex(UIColor.systemBlue.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))) dark \(hex(UIColor.systemBlue.resolvedColor(with: dark))) dark+HC \(hex(UIColor.systemBlue.resolvedColor(with: hc)))")
        let brand = UIColor(named: "Brand")
        print("colors: Brand light \(hex(brand?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))) dark \(hex(brand?.resolvedColor(with: dark))) dark+HC \(hex(brand?.resolvedColor(with: hc))) light+HC \(hex(brand?.resolvedColor(with: UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: .light), UITraitCollection(accessibilityContrast: .high)]))))")
        dark.performAsCurrent { print("colors: performAsCurrent label \(hex(UIColor.label.resolvedColor(with: UITraitCollection.current)))") }
        // dynamic images: the asset catalog variant per traits, and an image asset with registered images
        if let badge = UIImage(named: "Badge") {
            let d = badge.imageAsset?.image(with: dark), l = badge.imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light))
            print("images: Badge asset \(badge.imageAsset != nil), light \(Int(l?.size.width ?? 0)) dark \(Int(d?.size.width ?? 0)), config dark \(Int(badge.withConfiguration(UIImage.Configuration(traitCollection: dark)).size.width))")
        }
        let asset = UIImageAsset()
        asset.register(solid(.red, 4), with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(solid(.blue, 6), with: UITraitCollection(userInterfaceStyle: .dark))
        print("images: registered light \(Int(asset.image(with: UITraitCollection(userInterfaceStyle: .light)).size.width)) dark \(Int(asset.image(with: dark).size.width))")
        print("traits: system color traits \(UITraitCollection.systemTraitsAffectingColorAppearance.count), accent \(hex(UIColor.tintColor))")
    }
}
func solid(_ c: UIColor, _ size: CGFloat) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in c.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size)) }
}

/// a view whose traits are logged while it lays out (UITraitCollection.current is its traits there)
final class ProbeView: UIView {
    var name = ""
    override func layoutSubviews() {
        super.layoutSubviews()
        print("current in layout \(name): \(styleName(UITraitCollection.current.userInterfaceStyle)) theme \(UITraitCollection.current.theme)")
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        print("view \(name) traits \(styleName(previous?.userInterfaceStyle ?? .unspecified)) -> \(styleName(traitCollection.userInterfaceStyle))")
    }
}
final class ControlsView: UIView {}

/// a child controller under a dark parent (overrideUserInterfaceStyle propagation)
final class ChildViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "child"
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("child traits: \(styleName(traitCollection.userInterfaceStyle)), view \(styleName(view.traitCollection.userInterfaceStyle))")
    }
    override func didReceiveMemoryWarning() { print("memory warning: child controller") }
}
final class SheetViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "sheet"
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("presented traits: \(styleName(traitCollection.userInterfaceStyle))")
    }
}
final class DarkContainerViewController: UIViewController {
    let child = ChildViewController()
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }
}

final class AppearanceViewController: UIViewController {
    let autoSwatch = UIView(), darkHost = ProbeView(), darkSwatch = UIView(), themeSwatch = ProbeView()
    let badgeAuto = UIImageView(), badgeDark = UIImageView()
    let lightBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
    let darkBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    let accentButton = UIButton(type: .system)
    let container = DarkContainerViewController()
    var registrations = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Appearance"
        view.backgroundColor = .systemBackground
        // row 1 (y 120): the asset color following the app's appearance; one under a dark trait override
        autoSwatch.frame = CGRect(x: 20, y: 120, width: 80, height: 40)
        autoSwatch.backgroundColor = UIColor(named: "Brand")
        darkHost.name = "darkHost"
        darkHost.frame = CGRect(x: 110, y: 120, width: 80, height: 40)
        darkHost.traitOverrides.userInterfaceStyle = .dark
        darkSwatch.frame = darkHost.bounds
        darkSwatch.backgroundColor = UIColor(named: "Brand")
        darkHost.addSubview(darkSwatch)
        // the custom trait: set on this controller, read by a dynamic color below it
        themeSwatch.name = "theme"
        themeSwatch.frame = CGRect(x: 200, y: 120, width: 80, height: 40)
        themeSwatch.backgroundColor = themeColor
        traitOverrides[ThemeTrait.self] = .ocean
        // row 2 (y 180): a dark parent controller with a child (systemBackground follows)
        addChild(container)
        container.view.frame = CGRect(x: 20, y: 180, width: 120, height: 40)
        view.addSubview(container.view)
        container.didMove(toParent: self)
        // row 3 (y 240): the dynamic asset image, in the app's appearance and in a dark override
        badgeAuto.image = UIImage(named: "Badge"); badgeAuto.frame = CGRect(x: 20, y: 240, width: 40, height: 40)
        badgeDark.image = UIImage(named: "Badge"); badgeDark.frame = CGRect(x: 80, y: 240, width: 40, height: 40)
        badgeDark.overrideUserInterfaceStyle = .dark
        // row 4 (y 300): materials per appearance over a red stripe, a vibrant label inside the dark one
        let stripe = UIView(frame: CGRect(x: 20, y: 300, width: 260, height: 60))
        stripe.backgroundColor = .systemRed
        lightBlur.frame = CGRect(x: 20, y: 300, width: 120, height: 60)
        darkBlur.frame = CGRect(x: 160, y: 300, width: 120, height: 60)
        let vibrancy = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .systemMaterialDark), style: .label))
        vibrancy.frame = darkBlur.bounds
        let vibrant = UIView(frame: CGRect(x: 40, y: 15, width: 40, height: 30))
        vibrant.backgroundColor = .systemYellow                        // drawn in the vibrant color, not yellow
        vibrancy.contentView.addSubview(vibrant)
        darkBlur.contentView.addSubview(vibrancy)
        // row 5 (y 380): the accent color is the default tint
        accentButton.setTitle("Accent", for: .normal)
        accentButton.frame = CGRect(x: 20, y: 380, width: 100, height: 40)
        accentButton.accessibilityIdentifier = "accent"
        // row 6 (y 440): controls styled by appearance proxies
        let controls = ControlsView(frame: CGRect(x: 0, y: 440, width: 402, height: 160))
        let toggle = UISwitch(frame: CGRect(x: 20, y: 0, width: 51, height: 31)); toggle.isOn = true; toggle.accessibilityIdentifier = "toggle"
        let segments = UISegmentedControl(items: ["One", "Two"]); segments.frame = CGRect(x: 100, y: 0, width: 160, height: 32); segments.selectedSegmentIndex = 1
        let button = UIButton(type: .system); button.setTitle("Proxy", for: .normal); button.frame = CGRect(x: 20, y: 50, width: 100, height: 40)
        let progress = UIProgressView(progressViewStyle: .default); progress.frame = CGRect(x: 140, y: 68, width: 200, height: 4); progress.progress = 0.5
        let label = UILabel(frame: CGRect(x: 20, y: 100, width: 200, height: 30)); label.text = "Contained label"
        let ownLabel = UILabel(frame: CGRect(x: 220, y: 100, width: 160, height: 30)); ownLabel.text = "Own color"; ownLabel.textColor = .systemGreen
        for v in [toggle, segments, button, progress, label, ownLabel] as [UIView] { controls.addSubview(v) }
        let themeButton = UIButton(type: .system)
        themeButton.setTitle("Theme", for: .normal); themeButton.frame = CGRect(x: 140, y: 380, width: 100, height: 40)
        themeButton.accessibilityIdentifier = "theme"
        themeButton.addAction(UIAction { [unowned self] _ in
            traitOverrides[ThemeTrait.self] = .forest
            print("theme -> forest (overrides contain theme: \(traitOverrides.contains(ThemeTrait.self)))")
        }, for: .primaryActionTriggered)
        let present = UIButton(type: .system)
        present.setTitle("Present", for: .normal); present.frame = CGRect(x: 260, y: 380, width: 100, height: 40)
        present.accessibilityIdentifier = "present"
        present.addAction(UIAction { [unowned self] _ in
            let sheet = SheetViewController()
            sheet.modalPresentationStyle = .fullScreen
            container.child.present(sheet, animated: false)
        }, for: .primaryActionTriggered)
        for v in [autoSwatch, darkHost, themeSwatch, badgeAuto, badgeDark, stripe, lightBlur, darkBlur, accentButton, themeButton, present, controls] as [UIView] { view.addSubview(v) }
        toolbarItems = [UIBarButtonItem(title: "Tinted", style: .plain, target: nil, action: nil), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                        UIBarButtonItem(title: "Own", style: .plain, target: nil, action: nil).with { $0.tintColor = .systemOrange; $0.setTitleTextAttributes([.foregroundColor: UIColor.systemOrange], for: .normal) }]
        // trait change registrations (iOS 17): the appearance, and the custom trait
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: AppearanceViewController, previous: UITraitCollection) in
            vc.registrations += 1
            print("registration: style \(styleName(previous.userInterfaceStyle)) -> \(styleName(vc.traitCollection.userInterfaceStyle)), swatch \(hex(vc.autoSwatch.backgroundColor?.resolvedColor(with: vc.traitCollection)))")
        }
        registerForTraitChanges([ThemeTrait.self, UITraitAccessibilityContrast.self]) { (vc: AppearanceViewController, previous: UITraitCollection) in
            print("registration: theme \(previous.theme) -> \(vc.traitCollection.theme), contrast \(vc.traitCollection.accessibilityContrast.rawValue)")
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { _ in print("memory warning: notification") }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let controls = view.subviews.compactMap { $0 as? ControlsView }.first!
        let toggle = controls.subviews.compactMap { $0 as? UISwitch }.first!
        let segments = controls.subviews.compactMap { $0 as? UISegmentedControl }.first!
        let button = controls.subviews.compactMap { $0 as? UIButton }.first!
        let progress = controls.subviews.compactMap { $0 as? UIProgressView }.first!
        let labels = controls.subviews.compactMap { $0 as? UILabel }
        let items = toolbarItems ?? []
        print("proxies: switch \(hex(toggle.onTintColor)), button \(hex(button.titleColor(for: .normal))), segments \(hex(segments.titleTextAttributes(for: .normal)?[.foregroundColor] as? UIColor))/\(hex(segments.titleTextAttributes(for: .selected)?[.foregroundColor] as? UIColor)), progress \(hex(progress.progressTintColor))")
        print("proxies: label \(hex(labels[0].textColor)) own \(hex(labels[1].textColor)), bar item \(hex(items.first?.tintColor)) \(hex(items.first?.titleTextAttributes(for: .normal)?[.foregroundColor] as? UIColor)) own \(hex(items.last?.tintColor))")
        print("traits: root \(styleName(traitCollection.userInterfaceStyle)), dark host \(styleName(darkHost.traitCollection.userInterfaceStyle)), theme swatch \(themeSwatch.traitCollection.theme), accent tint \(hex(accentButton.tintColor))")
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        print("controller traits \(styleName(previous?.userInterfaceStyle ?? .unspecified)) -> \(styleName(traitCollection.userInterfaceStyle)) contrast \(traitCollection.accessibilityContrast.rawValue)")
    }
    override func didReceiveMemoryWarning() { print("memory warning: root controller") }
}

extension UIBarButtonItem {
    func with(_ f: (UIBarButtonItem) -> Void) -> UIBarButtonItem { f(self); return self }
}
