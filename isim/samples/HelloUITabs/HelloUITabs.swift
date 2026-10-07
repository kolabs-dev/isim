// Sample: iOS 18 / 26 UIKit on isim — UITab / UITabGroup / UISearchTab with the iPad sidebar (UITabBarController.Mode
// .tabSidebar) and tab delegate callbacks, isTabBarHidden, UIBackgroundExtensionView under the sidebar, UIUpdateLink,
// iOS 26 bar button badges and scroll edge effects, automatic observation tracking in layoutSubviews and the iOS 26
// updateProperties (on iOS 18 only with UIObservationTrackingEnabled).
import UIKit
import Observation

func log(_ s: String) { print("HelloUITabs: \(s)") }

@Observable final class Model {
    var title = "Start"
    var count = 0
}
let model = Model()

/// reads the model while laying out (and in updateProperties on iOS 26): UIKit tracks those reads
final class ModelView: UIView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.frame = CGRect(x: 0, y: 0, width: 300, height: 30); label.accessibilityIdentifier = "modelLabel"
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.text = model.title
        log("layout: \(model.title)")
    }
    @available(iOS 26.0, *)
    override func updateProperties() {
        super.updateProperties()
        backgroundColor = model.count > 0 ? .systemGreen : .systemGray5
        log("properties: \(model.count)")
    }
}

final class HomeViewController: UIViewController {
    let scroll = UIScrollView()
    var frames = 0
    var link: AnyObject?
    var extensionView: UIView?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = .systemBackground
        // a background extension view: its content reaches under the sidebar (iPad)
        if #available(iOS 26.0, *) {
            let ext = UIBackgroundExtensionView(frame: CGRect(x: 0, y: 0, width: 400, height: 250))
            let blue = UIView(); blue.backgroundColor = .systemBlue
            ext.contentView = blue
            ext.accessibilityIdentifier = "extension"
            ext.autoresizingMask = [.flexibleWidth]
            extensionView = ext
        }
        scroll.frame = view.bounds; scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.contentSize = CGSize(width: 300, height: 2000)
        scroll.accessibilityIdentifier = "scroll"
        let red = UIView(frame: CGRect(x: 0, y: 0, width: 2000, height: 2000)); red.backgroundColor = .systemRed
        red.autoresizingMask = [.flexibleWidth]
        scroll.insertSubview(red, at: 0)
        view.addSubview(scroll)
        if let ext = extensionView { ext.frame = CGRect(x: 0, y: 600, width: view.bounds.width, height: 120); view.addSubview(ext) }
        let mv = ModelView(frame: CGRect(x: 20, y: 300, width: 300, height: 40)); mv.accessibilityIdentifier = "modelView"
        view.addSubview(mv)
        func button(_ t: String, _ id: String, _ y: CGFloat, _ a: @escaping () -> Void) {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.frame = CGRect(x: 20, y: y, width: 200, height: 40); b.backgroundColor = .systemBackground
            b.addAction(UIAction { _ in a() }, for: .primaryActionTriggered); view.addSubview(b)
        }
        button("Mutate", "mutate", 360) { model.title = "Changed"; model.count += 1; log("model mutated") }
        button("Hide bar", "hideBar", 410) { [unowned self] in
            if #available(iOS 18.0, *) { tabBarController?.setTabBarHidden(!(tabBarController?.isTabBarHidden ?? false), animated: false); log("tab bar hidden \(tabBarController?.isTabBarHidden ?? false)") }
        }
        button("Sidebar", "toggleSidebar", 460) { [unowned self] in
            if #available(iOS 18.0, *), let s = tabBarController?.sidebar { s.isHidden.toggle(); log("sidebar hidden \(s.isHidden)") }
        }
        button("Soft edge", "softEdge", 510) { [unowned self] in
            if #available(iOS 26.0, *) { scroll.topEdgeEffect.style = .soft; log("top edge effect \(scroll.topEdgeEffect.style)") }
        }
        if #available(iOS 26.0, *) {
            scroll.topEdgeEffect.style = .hard
            let mail = UIBarButtonItem(image: UIImage(systemName: "envelope"), style: .plain, target: nil, action: nil)
            mail.badge = .count(5); mail.accessibilityIdentifier = "mail"
            let bell = UIBarButtonItem(image: UIImage(systemName: "bell"), style: .plain, target: nil, action: nil)
            bell.badge = .indicator(); bell.accessibilityIdentifier = "bell"
            navigationItem.rightBarButtonItems = [mail, bell]
            log("badges \(mail.badge?.stringValue ?? "nil") / indicator \(bell.badge?.stringValue == nil)")
        }
        if #available(iOS 18.0, *) {
            let l = UIUpdateLink(view: view)
            l.addAction(to: .beforeCADisplayLinkDispatch) { [unowned self] link, info in
                frames += 1
                if frames == 20 { log("update link: 20 frames, model time \(info.modelTime > 0)"); link.isEnabled = false }
            }
            l.requiresContinuousUpdates = true
            l.isEnabled = true
            link = l
        }
    }
}
final class TitledViewController: UIViewController {
    init(_ title: String) { super.init(nibName: nil, bundle: nil); self.title = title }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let l = UILabel(frame: CGRect(x: 20, y: 200, width: 300, height: 30)); l.text = "Page \(title ?? "")"; l.accessibilityIdentifier = "page"
        view.addSubview(l)
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); log("showing \(title ?? "")") }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tabs = UITabBarController()
        tabs.delegate = self
        if #available(iOS 18.0, *) {
            let home = UITab(title: "Home", image: UIImage(systemName: "house"), identifier: "home") { _ in UINavigationController(rootViewController: HomeViewController()) }
            let inbox = UITab(title: "Inbox", image: UIImage(systemName: "tray"), identifier: "inbox") { _ in TitledViewController("Inbox") }
            inbox.badgeValue = "3"
            let albums = UITab(title: "Albums", image: UIImage(systemName: "square.stack"), identifier: "albums") { _ in TitledViewController("Albums") }
            let songs = UITab(title: "Songs", image: UIImage(systemName: "music.note"), identifier: "songs") { _ in TitledViewController("Songs") }
            let library = UITabGroup(title: "Library", image: UIImage(systemName: "books.vertical"), identifier: "library", children: [albums, songs], viewControllerProvider: nil)
            let search = UISearchTab { _ in TitledViewController("Search") }
            tabs.tabs = [home, inbox, library, search]
            tabs.mode = .tabSidebar
            log("tabs \(tabs.tabs.map { $0.identifier }), selected \(tabs.selectedTab?.identifier ?? "nil"), group parent \(songs.parent?.identifier ?? "nil"), lookup \(tabs.tab(forIdentifier: "songs")?.title ?? "nil")")
        } else {
            tabs.viewControllers = [UINavigationController(rootViewController: HomeViewController()), TitledViewController("Inbox")]
            log("classic tabs")
        }
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        if tab.identifier == "inbox" && model.count == 0 { log("refused \(tab.identifier)"); return false }
        return true
    }
    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
        log("selected \(selectedTab.identifier) (previous \(previousTab?.identifier ?? "nil"), parent \(selectedTab.parent?.identifier ?? "nil"))")
    }
}
