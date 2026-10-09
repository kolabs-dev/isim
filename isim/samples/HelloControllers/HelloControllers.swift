// Sample: view controllers on isim (UIKit) — a triple-column UISplitViewController (tile / overlay / displace display
// modes, the sidebar button, the edge swipe, collapsing and expanding when an iPhone Pro Max turns), a search
// controller with a results controller and search suggestions plus a standalone one, and the share sheet's Save Image
// and Print.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let split = UISplitViewController(style: .tripleColumn)
        split.delegate = self
        split.setViewController(LibraryViewController(), for: .primary)
        split.setViewController(MessagesViewController(folder: "Inbox"), for: .supplementary)
        split.setViewController(UINavigationController(rootViewController: DetailViewController(title: "Welcome")), for: .secondary)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = split
        window?.makeKeyAndVisible()
        print("split collapsed \(split.isCollapsed) mode \(split.displayMode.rawValue)")
        return true
    }
    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) { print("will change to mode \(displayMode.rawValue)") }
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        .primary                                                        // collapsed: start at the library
    }
    func splitViewControllerDidCollapse(_ svc: UISplitViewController) { print("did collapse") }
    func splitViewControllerDidExpand(_ svc: UISplitViewController) { print("did expand") }
}

/// pages keep their content inside the safe area's leading edge (landscape iPhones)
class Page: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for v in view.subviews where v.tag == 1 { v.frame.origin.x = view.safeAreaInsets.left + 16 }
    }
}

func button(_ id: String, _ title: String, y: CGFloat, in view: UIView, _ action: @escaping () -> Void) {
    let b = UIButton(type: .system)
    b.tag = 1
    b.setTitle(title, for: .normal)
    b.frame = CGRect(x: 16, y: y, width: 260, height: 36)
    b.contentHorizontalAlignment = .leading
    b.accessibilityIdentifier = id
    b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
    view.addSubview(b)
}

final class LibraryViewController: Page {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        view.backgroundColor = .secondarySystemBackground
        view.accessibilityIdentifier = "library"
        for (i, folder) in ["Inbox", "Archive"].enumerated() {
            button("folder-\(folder)", folder, y: 120 + CGFloat(i) * 44, in: view) { [unowned self] in
                splitViewController?.setViewController(MessagesViewController(folder: folder), for: .supplementary)
                splitViewController?.show(.supplementary)
                print("folder \(folder)")
            }
        }
    }
}

final class MessagesViewController: Page {
    let folder: String
    init(folder: String) { self.folder = folder; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = folder
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "messages"
        for n in 1...2 {
            button("message-\(n)", "\(folder) message \(n)", y: 120 + CGFloat(n - 1) * 44, in: view) { [unowned self] in
                splitViewController?.showDetailViewController(UINavigationController(rootViewController: DetailViewController(title: "Message \(n)")), sender: self)
            }
        }
    }
}

final class DetailViewController: Page, UISearchResultsUpdating, UISearchControllerDelegate {
    init(title: String) { super.init(nibName: nil, bundle: nil); self.title = title }
    required init?(coder: NSCoder) { fatalError() }
    let standalone = UISearchController(searchResultsController: ResultsViewController(tag: "standalone"))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "detail"
        let label = UILabel(frame: CGRect(x: 16, y: 110, width: 300, height: 30))
        label.text = title
        label.accessibilityIdentifier = "detail-title"
        label.tag = 1
        view.addSubview(label)
        let behaviors: [(String, UISplitViewController.SplitBehavior)] = [("tile", .tile), ("overlay", .overlay), ("displace", .displace)]
        for (i, (name, behavior)) in behaviors.enumerated() {
            button(name, "Behavior: \(name)", y: 150 + CGFloat(i) * 40, in: view) { [unowned self] in
                splitViewController?.preferredSplitBehavior = behavior
                print("behavior \(name): mode \(splitViewController?.displayMode.rawValue ?? -1)")
            }
        }
        button("share", "Share", y: 280, in: view) { [unowned self] in share() }
        // the navigation item's search: a results controller and suggestions
        let search = UISearchController(searchResultsController: ResultsViewController(tag: "results"))
        search.searchResultsUpdater = self
        search.delegate = self
        search.searchBar.accessibilityIdentifier = "search-bar"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        // a standalone search controller whose bar lives in the content
        standalone.searchResultsUpdater = self
        standalone.hidesNavigationBarDuringPresentation = false
        standalone.searchBar.frame = CGRect(x: 0, y: 330, width: view.bounds.width, height: 52)
        standalone.searchBar.autoresizingMask = .flexibleWidth
        standalone.searchBar.accessibilityIdentifier = "standalone-bar"
        standalone.searchBar.placeholder = "Standalone search"
        view.addSubview(standalone.searchBar)
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            print("detail \(title ?? "") size class \(traitCollection.horizontalSizeClass == .regular ? "regular" : "compact")")
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("detail \(title ?? "") appeared, mode \(splitViewController?.displayMode.rawValue ?? -1)")
    }

    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text ?? ""
        let which = searchController === standalone ? "standalone" : "results"
        (searchController.searchResultsController as? ResultsViewController)?.show("\(which): \(text)")
        if searchController !== standalone {
            searchController.searchSuggestions = text.hasPrefix("ap") ? [UISearchSuggestionItem(localizedSuggestion: "apple"), UISearchSuggestionItem(localizedSuggestion: "apricot", localizedDescription: "fruit")] : []
        }
        print("search \(which) \"\(text)\"")
    }
    func updateSearchResults(for searchController: UISearchController, selecting searchSuggestion: UISearchSuggestion) {
        print("suggestion selected: \(searchSuggestion.localizedSuggestion ?? "")")
        searchController.searchBar.text = searchSuggestion.localizedSuggestion
        searchController.searchSuggestions = []
        (searchController.searchResultsController as? ResultsViewController)?.show("picked: \(searchSuggestion.localizedSuggestion ?? "")")
    }
    func didPresentSearchController(_ searchController: UISearchController) { print("search presented") }
    func didDismissSearchController(_ searchController: UISearchController) { print("search dismissed") }

    func share() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
        let sheet = UIActivityViewController(activityItems: [image, "A teal square"], applicationActivities: nil)
        sheet.completionWithItemsHandler = { type, completed, _, _ in print("share finished: \(type?.rawValue ?? "nil") \(completed)") }
        present(sheet, animated: true)
    }
}

final class ResultsViewController: UIViewController {
    let tag: String
    let label = UILabel()
    init(tag: String) { self.tag = tag; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 16, y: 120, width: 300, height: 30)
        label.accessibilityIdentifier = "\(tag)-label"
        view.addSubview(label)
    }
    func show(_ s: String) { loadViewIfNeeded(); label.text = s }
}
