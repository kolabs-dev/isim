// Sample: view controller-based state restoration on isim (UIKit, an app without scenes) — restoration identifiers,
// a restoration class (DetailViewController), the app delegate creating a controller (AboutViewController), an
// existing controller found by its path (the list), a navigation stack and a presented controller rebuilt, a table
// view's selection (UIDataSourceModelAssociation) and offset, an object registered for restoration, the app
// delegate's own state; and background fetch (UIBackgroundModes fetch, minimum interval).
import UIKit

final class AppSettings: NSObject, UIStateRestoring {
    static let shared = AppSettings()
    var visits = 0
    func encodeRestorableState(with coder: NSCoder) { coder.encode(visits, forKey: "visits") }
    func decodeRestorableState(with coder: NSCoder) {
        visits = coder.decodeInteger(forKey: "visits")
        print("settings decoded visits \(visits)")
    }
    func applicationFinishedRestoringState() { print("settings finished restoring") }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // the window and its root exist before restoration (it runs between will- and didFinishLaunching)
        let list = ListViewController()
        list.restorationIdentifier = "list"
        let nav = UINavigationController(rootViewController: list)
        nav.restorationIdentifier = "nav"
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        UIApplication.registerObject(forStateRestoration: AppSettings.shared, restorationIdentifier: "settings")
        print("willFinishLaunching")
        return true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        window?.makeKeyAndVisible()
        let nav = window?.rootViewController as? UINavigationController
        print("didFinishLaunching: stack \(nav?.viewControllers.compactMap { $0.restorationIdentifier } ?? []), presented \(nav?.presentedViewController?.restorationIdentifier ?? "none")")
        return true
    }
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool { true }
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        let version = coder.decodeObject(of: NSString.self, forKey: UIApplication.stateRestorationBundleVersionKey) ?? "?"
        print("should restore: saved by version \(version), secure \(coder.requiresSecureCoding)")
        return true
    }
    func application(_ application: UIApplication, willEncodeRestorableStateWith coder: NSCoder) {
        coder.encode("from the app delegate" as NSString, forKey: "note")
    }
    func application(_ application: UIApplication, didDecodeRestorableStateWith coder: NSCoder) {
        print("app delegate decoded: \(coder.decodeObject(of: NSString.self, forKey: "note") ?? "nil")")
    }
    func application(_ application: UIApplication, viewControllerWithRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard identifierComponents.last == "about" else { return nil }
        print("app delegate creates \(identifierComponents.joined(separator: "/"))")
        let about = AboutViewController()
        about.restorationIdentifier = "about"
        return about
    }
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("performFetch: state \(application.applicationState == .background ? "background" : "foreground")")
        completionHandler(.newData)
    }
}

/// a bar item presenting About (restored by the app delegate)
@MainActor func aboutItem(_ vc: UIViewController) -> UIBarButtonItem {
    let item = UIBarButtonItem(title: "About", primaryAction: UIAction { [unowned vc] _ in
        let about = AboutViewController()
        about.restorationIdentifier = "about"
        vc.present(about, animated: true)
    })
    item.accessibilityIdentifier = "about"
    return item
}

/// found by its path on restore (it already exists under the navigation controller)
final class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDataSourceModelAssociation {
    let table = UITableView(frame: .zero, style: .plain)
    let items = (1...40).map { "Item \($0)" }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Restoration"
        table.frame = view.bounds
        table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        table.dataSource = self; table.delegate = self
        table.restorationIdentifier = "table"
        table.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        view.addSubview(table)
        navigationItem.rightBarButtonItem = aboutItem(self)
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        c.textLabel?.text = items[indexPath.row]
        c.accessibilityIdentifier = "row-\(indexPath.row + 1)"
        return c
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        AppSettings.shared.visits += 1
        print("selected \(items[indexPath.row])")
        navigationController?.pushViewController(DetailViewController(item: items[indexPath.row]), animated: true)
    }
    func modelIdentifierForElement(at idx: IndexPath, in view: UIView) -> String? { items[idx.row] }
    func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> IndexPath? {
        items.firstIndex(of: identifier).map { IndexPath(row: $0, section: 0) }
    }
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        print("list encoded: selected \(table.indexPathForSelectedRow?.row ?? -1), offset \(Int(table.contentOffset.y))")
    }
    override func applicationFinishedRestoringState() {
        print("list finished restoring: selected \(table.indexPathForSelectedRow.map { items[$0.row] } ?? "none"), offset \(Int(table.contentOffset.y))")
    }
}

/// created by its restoration class from what it saved
final class DetailViewController: UIViewController, UIViewControllerRestoration {
    let item: String
    var count = 0
    let label = UILabel()
    init(item: String) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        restorationIdentifier = "detail"
        restorationClass = DetailViewController.self
    }
    required init?(coder: NSCoder) { fatalError() }
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard let item = coder.decodeObject(of: NSString.self, forKey: "item") else { return nil }
        print("restoration class creates \(identifierComponents.joined(separator: "/")) for \(item)")
        return DetailViewController(item: item as String)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = item
        navigationItem.rightBarButtonItem = aboutItem(self)
        label.frame = CGRect(x: 20, y: 140, width: 300, height: 40)
        label.accessibilityIdentifier = "detail-label"
        let plus = UIButton(type: .system)
        plus.setTitle("Increment", for: .normal)
        plus.frame = CGRect(x: 20, y: 200, width: 140, height: 44)
        plus.accessibilityIdentifier = "increment"
        plus.addAction(UIAction { [unowned self] _ in count += 1; update() }, for: .primaryActionTriggered)
        view.addSubview(label); view.addSubview(plus)
        update()
    }
    func update() { label.text = "\(item) · count \(count)" }
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(item as NSString, forKey: "item")
        coder.encode(count, forKey: "count")
        print("detail encoded \(item) count \(count)")
    }
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        count = coder.decodeInteger(forKey: "count")
        print("detail decoded count \(count)")
        if isViewLoaded { update() }
    }
}

/// presented; created by the app delegate on restore
final class AboutViewController: UIViewController {
    var opened = Date()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemYellow
        let l = UILabel(frame: CGRect(x: 20, y: 40, width: 300, height: 40))
        l.text = "About"; l.accessibilityIdentifier = "about-label"
        view.addSubview(l)
    }
    override func encodeRestorableState(with coder: NSCoder) { coder.encode(opened as NSDate, forKey: "opened") }
    override func decodeRestorableState(with coder: NSCoder) {
        if let d = coder.decodeObject(of: NSDate.self, forKey: "opened") { opened = d as Date }
        print("about decoded (opened earlier: \(opened < Date()))")
    }
}
