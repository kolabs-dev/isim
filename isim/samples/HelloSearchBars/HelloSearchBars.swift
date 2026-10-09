// Sample: where a UISearchController's bar goes (UINavigationItem.preferredSearchBarPlacement).
// Launch argument: stacked | integrated | button | centered | inline (default: integrated on iOS 26+, inline before).
// - iOS 26 iPhone: `.integrated` puts the field in the navigation controller's toolbar, at the toolbar's
//   `searchBarPlacementBarButtonItem` (between Compose and Add here); activating it lifts the field above the keyboard.
//   `.integratedButton`: a search button in the toolbar.
// - iPad (and `.inline` before iOS 26): a field in the navigation bar row, trailing (`.integrated`) or centred.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: FruitsViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class FruitsViewController: UITableViewController, UISearchResultsUpdating {
    let fruits = ["Apple", "Apricot", "Banana", "Blueberry", "Cherry", "Grape", "Lemon", "Lime", "Mango", "Orange", "Peach", "Pear", "Plum", "Raspberry", "Strawberry"]
    var shown: [String] = []
    let search = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Fruits"
        shown = fruits
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
        let mode = ProcessInfo.processInfo.arguments.dropFirst().first { ["stacked", "integrated", "button", "centered", "inline"].contains($0) }
        if #available(iOS 26, *) {
            switch mode ?? "integrated" {
            case "stacked": navigationItem.preferredSearchBarPlacement = .stacked
            case "button": navigationItem.preferredSearchBarPlacement = .integratedButton
            case "centered": navigationItem.preferredSearchBarPlacement = .integratedCentered
            case "inline": navigationItem.preferredSearchBarPlacement = .inline
            default: navigationItem.preferredSearchBarPlacement = .integrated
            }
            let compose = UIBarButtonItem(systemItem: .compose); compose.accessibilityIdentifier = "compose"
            let add = UIBarButtonItem(systemItem: .add); add.accessibilityIdentifier = "add"
            toolbarItems = [compose, navigationItem.searchBarPlacementBarButtonItem, add]
            print("hsb toolbar integration \(navigationItem.searchBarPlacementAllowsToolbarIntegration) external \(navigationItem.searchBarPlacementAllowsExternalIntegration)")
        } else {
            navigationItem.preferredSearchBarPlacement = mode == "stacked" ? .stacked : .inline
        }
        print("hsb placement preferred \(navigationItem.preferredSearchBarPlacement.rawValue) effective \(navigationItem.searchBarPlacement.rawValue)")
    }
    func updateSearchResults(for searchController: UISearchController) {
        let q = searchController.searchBar.text ?? ""
        shown = q.isEmpty ? fruits : fruits.filter { $0.localizedCaseInsensitiveContains(q) }
        print("hsb search \"\(q)\" \(shown.count) results active \(searchController.isActive)")
        tableView.reloadData()
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        c.textLabel?.text = shown[indexPath.row]
        c.accessibilityIdentifier = "fruit-\(shown[indexPath.row])"
        return c
    }
}
