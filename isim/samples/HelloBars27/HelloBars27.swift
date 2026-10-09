// Sample: iOS 27 UIKit bars and tabs.
// - UINavigationItem.navigationBarMinimization: the list's bar minimizes while scrolling down and comes back only at
//   the top (.atScrollEdge); the safe area follows (.enabled)
// - UIBarButtonItem.visibilityPriority: five trailing items; when they do not fit, the low-priority ones move to the
//   overflow (ellipsis) menu first
// - UITabBarController.prominentTabIdentifier (a UISearchTab with automaticallyActivatesSearch is prominent until
//   "Make Inbox Prominent" names another tab), performBatchUpdates(_:), the sidebar's isAvailable / preferredPlacement /
//   delegate (iPad, launch argument `sidebar`)
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 18, *) {
            window?.rootViewController = TabsController()
        } else {                                                    // no UITab before iOS 18: classic tabs
            let tabs = UITabBarController()
            let home = UINavigationController(rootViewController: ListViewController())
            home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
            let library = UINavigationController(rootViewController: PlainViewController("Library"))
            library.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "book"), tag: 1)
            tabs.viewControllers = [home, library]
            window?.rootViewController = tabs
        }
        window?.makeKeyAndVisible()
        return true
    }
}

@available(iOS 18, *)
final class TabsController: UITabBarController, UITabBarController.Sidebar.Delegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        let home = UITab(title: "Home", image: UIImage(systemName: "house"), identifier: "home") { _ in UINavigationController(rootViewController: ListViewController()) }
        let library = UITab(title: "Library", image: UIImage(systemName: "book"), identifier: "library") { _ in UINavigationController(rootViewController: PlainViewController("Library")) }
        let inbox = UITab(title: "Inbox", image: UIImage(systemName: "tray"), identifier: "inbox") { _ in UINavigationController(rootViewController: PlainViewController("Inbox")) }
        let search = UISearchTab { _ in UINavigationController(rootViewController: SearchViewController()) }
        search.automaticallyActivatesSearch = true
        tabs = [home, library, inbox, search]
        if #available(iOS 27, *) {
            sidebar.delegate = self
            sidebar.preferredPlacement = .tabBar
            print("hb27 sidebar available \(sidebar.isAvailable) placement \(sidebar.preferredPlacement == .tabBar)")
        }
        if ProcessInfo.processInfo.arguments.contains("sidebar") { mode = .tabSidebar }
    }
    func tabBarController(_ tabBarController: UITabBarController, sidebarAvailabilityDidChange sidebar: UITabBarController.Sidebar) {
        if #available(iOS 27, *) { print("hb27 sidebar availability changed \(sidebar.isAvailable)") }
    }
    func tabBarController(_ tabBarController: UITabBarController, sidebarVisibilityWillChange sidebar: UITabBarController.Sidebar, animator: any UITabBarController.Sidebar.Animating) {
        print("hb27 sidebar visibility will change hidden \(sidebar.isHidden)")
        animator.addCompletion { print("hb27 sidebar visibility changed hidden \(sidebar.isHidden)") }
    }
}

final class ListViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        if #available(iOS 27, *) {
            var m = UIBarMinimization()
            m.minimizationBehavior = .onScrollDown
            m.restorationBehavior = .atScrollEdge
            m.safeAreaAdjustment = .enabled
            navigationItem.navigationBarMinimization = m
            print("hb27 minimization \(navigationItem.navigationBarMinimization == m)")
        } else {
            print("hb27 ios27 no")
        }
        // five trailing items (Edit is the trailingmost); Archive and Flag are low priority, Share high
        func item(_ name: String, _ symbol: String) -> UIBarButtonItem {
            let i = UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: UIAction { _ in print("hb27 item \(name)") })
            i.accessibilityIdentifier = "item-\(name)"; i.accessibilityLabel = name
            return i
        }
        let edit = item("Edit", "pencil"), share = item("Share", "square.and.arrow.up"), archive = item("Archive", "archivebox")
        let flag = item("Flag", "flag"), pin = item("Pin", "pin")
        if #available(iOS 27, *) {
            archive.visibilityPriority = .low
            flag.visibilityPriority = UIBarButtonItemVisibilityPriority(lowerThan: .standard)
            share.visibilityPriority = .high
            print("hb27 priorities low<flag<standard<high \(UIBarButtonItemVisibilityPriority.low.rawValue < flag.visibilityPriority.rawValue && flag.visibilityPriority.rawValue < UIBarButtonItemVisibilityPriority.standard.rawValue && UIBarButtonItemVisibilityPriority.standard.rawValue < UIBarButtonItemVisibilityPriority.high.rawValue)")
        }
        navigationItem.rightBarButtonItems = [edit, share, archive, flag, pin]
        let prominent = UIBarButtonItem(image: UIImage(systemName: "star"), primaryAction: UIAction { [weak self] _ in self?.makeProminent() })
        prominent.accessibilityIdentifier = "make-prominent"
        let batch = UIBarButtonItem(image: UIImage(systemName: "square.stack"), primaryAction: UIAction { [weak self] _ in self?.batch() })
        batch.accessibilityIdentifier = "batch"
        let sidebar = UIBarButtonItem(image: UIImage(systemName: "sidebar.left"), primaryAction: UIAction { [weak self] _ in
            if #available(iOS 18, *), let s = self?.tabBarController?.sidebar { s.isHidden.toggle() } })
        sidebar.accessibilityIdentifier = "toggle-sidebar"
        navigationItem.leftBarButtonItems = [prominent, batch, sidebar]
    }
    func makeProminent() {
        if #available(iOS 27, *) { tabBarController?.setProminentTabIdentifier("inbox", animated: true); print("hb27 prominent inbox") }
    }
    func batch() {
        guard let tbc = tabBarController else { return }
        if #available(iOS 27, *) {
            tbc.performBatchUpdates {
                tbc.tab(forIdentifier: "library")?.title = "Books"
                tbc.tab(forIdentifier: "inbox")?.badgeValue = "3"
            }
            print("hb27 batch done")
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        c.textLabel?.text = "Row \(indexPath.row + 1)"
        return c
    }
}

final class PlainViewController: UIViewController {
    let name: String
    init(_ name: String) { self.name = name; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); title = name; view.backgroundColor = .systemBackground }
}

final class SearchViewController: UIViewController, UISearchControllerDelegate {
    let search = UISearchController(searchResultsController: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"; view.backgroundColor = .systemBackground
        search.delegate = self
        navigationItem.searchController = search
    }
    func didPresentSearchController(_ searchController: UISearchController) { print("hb27 search activated") }
}
