// Sample: UITableView on isim — a plain table (UITableViewController, sticky headers, subtitle cells, self-sizing rows,
// cell reuse, swipe to delete, custom swipe actions, edit mode, inserts), an inset-grouped settings table
// (value cells, checkmarks, disclosure, detail button, footers) and a diffable data source.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let produce = UINavigationController(rootViewController: ProduceViewController(style: .plain))
        produce.tabBarItem = UITabBarItem(title: "Produce", image: UIImage(systemName: "list.bullet"), tag: 0)
        let settings = UINavigationController(rootViewController: SettingsViewController(style: .insetGrouped))
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 1)
        let diffable = UINavigationController(rootViewController: DiffableViewController())
        diffable.tabBarItem = UITabBarItem(title: "Diffable", image: UIImage(systemName: "square.stack"), tag: 2)
        let tabs = UITabBarController()
        tabs.viewControllers = [produce, settings, diffable]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}

final class ProduceCell: UITableViewCell {
    static var created = 0
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        ProduceCell.created += 1
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class ProduceViewController: UITableViewController, UITableViewDataSourcePrefetching {
    var sections: [(String, [String])] = [
        ("Fruits", (1...30).map { "Fruit \($0)" }),
        ("Vegetables", (1...20).map { "Vegetable \($0)" }),
    ]
    let note = "A long note that wraps over several lines to show that rows size themselves to their content when the row height is automatic."
    var added = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Produce"
        tableView.register(ProduceCell.self, forCellReuseIdentifier: "produce")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "note")
        navigationItem.rightBarButtonItem = editButtonItem
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.addFruit() })
        sections[0].1.insert(note, at: 1)
        tableView.prefetchDataSource = self
        tableView.sectionIndexColor = .systemPurple
    }
    // section index and prefetching
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? { [UITableView.indexSearch, "F", "V"] }
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        let section = max(0, index - 1)
        DispatchQueue.main.async {
            let top = tableView.contentOffset.y + tableView.adjustedContentInset.top
            print("index \(title): section \(section) at the top \(abs(top - tableView.rect(forSection: section).minY) < 1 || top >= tableView.contentSize.height + tableView.adjustedContentInset.bottom - tableView.bounds.height - 1)")
        }
        return section
    }
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        print("prefetch \(indexPaths.count) rows from \(indexPaths[0].section)/\(indexPaths[0].row)")
    }
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) { print("cancel prefetch \(indexPaths.count) rows") }
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 0 else { return nil }
        let name = sections[0].1[indexPath.row]
        let pin = UIContextualAction(style: .normal, title: "Pin") { _, _, done in print("pinned \(name)"); done(true) }
        pin.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [pin])
    }
    func addFruit() {
        added += 1
        sections[0].1.insert("New fruit \(added)", at: 0)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
        print("inserted New fruit \(added), rows \(tableView.numberOfRows(inSection: 0))")
    }
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        print("editing \(editing) table \(tableView.isEditing)")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].1.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].0 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let name = sections[indexPath.section].1[indexPath.row]
        if name == note {
            let cell = tableView.dequeueReusableCell(withIdentifier: "note", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = name
            content.textProperties.numberOfLines = 0
            cell.contentConfiguration = content
            cell.accessibilityIdentifier = "row-note"
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "produce", for: indexPath)
        cell.textLabel?.text = name
        cell.detailTextLabel?.text = indexPath.section == 0 ? "sweet" : "savory"
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "row-" + name.replacingOccurrences(of: " ", with: "")
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("selected \(sections[indexPath.section].1[indexPath.row])")
        tableView.deselectRow(at: indexPath, animated: true)
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let name = sections[indexPath.section].1.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        print("deleted \(name), rows \(tableView.numberOfRows(inSection: indexPath.section))")
    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }          // fruits: the default Delete action
        let name = sections[1].1[indexPath.row]
        let flag = UIContextualAction(style: .normal, title: "Flag") { _, _, done in print("flagged \(name)"); done(true) }
        flag.backgroundColor = .systemOrange
        let delete = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            self?.tableView(tableView, commit: .delete, forRowAt: indexPath); done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, flag])
    }
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 1500, !reportedReuse {
            reportedReuse = true
            print("cells created \(ProduceCell.created), visible \(tableView.visibleCells.count)")
        }
    }
    var reportedReuse = false
}

final class SettingsViewController: UITableViewController {
    var sound = "Chime"
    let sounds = ["Chime", "Bell", "Glass"]
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 2 : sounds.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? "Account" : "Sound" }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { section == 1 ? "Played for new messages." : nil }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        if indexPath.section == 0 {
            var content = UIListContentConfiguration.valueCell()
            content.text = indexPath.row == 0 ? "Name" : "Plan"
            content.secondaryText = indexPath.row == 0 ? "Ada" : "Pro"
            content.image = UIImage(systemName: indexPath.row == 0 ? "person.crop.circle" : "star")
            cell.contentConfiguration = content
            cell.accessoryType = indexPath.row == 0 ? .disclosureIndicator : .detailButton
            cell.accessibilityIdentifier = indexPath.row == 0 ? "set-name" : "set-plan"
        } else {
            cell.textLabel?.text = sounds[indexPath.row]
            cell.accessoryType = sounds[indexPath.row] == sound ? .checkmark : .none
            cell.accessibilityIdentifier = "sound-" + sounds[indexPath.row]
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { print("open \(indexPath.row == 0 ? "name" : "plan")"); return }
        sound = sounds[indexPath.row]
        tableView.reloadData()
        let checked = (0..<sounds.count).filter { tableView.cellForRow(at: IndexPath(row: $0, section: 1))?.accessoryType == .checkmark }
        print("sound \(sound), checked rows \(checked)")
    }
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        print("detail button row \(indexPath.row)")
    }
}

final class DiffableViewController: UIViewController {
    enum Section { case main }
    var tableView: UITableView!
    var dataSource: UITableViewDiffableDataSource<Section, Int>!
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Diffable"
        tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "n")
        view.addSubview(tableView)
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { tv, ip, n in
            let cell = tv.dequeueReusableCell(withIdentifier: "n", for: ip)
            var content = cell.defaultContentConfiguration()
            content.text = "Number \(n)"
            cell.contentConfiguration = content
            cell.accessibilityIdentifier = "num-\(n)"
            return cell
        }
        var snap = NSDiffableDataSourceSnapshot<Section, Int>()
        snap.appendSections([.main])
        snap.appendItems(Array(1...8))
        dataSource.apply(snap, animatingDifferences: false)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Odd", primaryAction: UIAction { [weak self] _ in self?.removeEvens() })
    }
    func removeEvens() {
        var snap = dataSource.snapshot()
        snap.deleteItems(snap.itemIdentifiers.filter { $0 % 2 == 0 })
        snap.insertItems([100], beforeItem: 1)
        dataSource.apply(snap) { [weak self] in
            guard let self else { return }
            let shown = (0..<self.tableView.numberOfRows(inSection: 0)).compactMap { self.dataSource.itemIdentifier(for: IndexPath(row: $0, section: 0)) }
            print("diffable rows \(shown)")
        }
    }
}
