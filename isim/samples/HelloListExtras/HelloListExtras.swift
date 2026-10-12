// Sample: table, collection view, layout, diffable and configuration members from the documentation sweep (#9),
// each logged with "lx".
// - Table: sections from the indexed collation, the Objective-C diffable data source (animated changes), header and
//   footer rects, rows in a rect, separators from the cell edges, editing transitions, an editing accessory view
// - Grid: a collection view controller with the standard reorder gesture (interactive movement), a flow layout
//   subclass with its own attributes class, update items and appearing attributes, badges anchored on items
// - Lists: accessories (insert, multiselect, pop-up menu), separator configurations, background configurations
//   (stroke, insets, shadow), attributed and transformed list content, list content view layout guides, the
//   Objective-C section snapshot (an outline)
import UIKit

func log(_ s: String) { print("lx \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tabs = UITabBarController()
        let table = UINavigationController(rootViewController: TableViewController())
        let grid = UINavigationController(rootViewController: GridViewController(collectionViewLayout: GridLayout()))
        let lists = ListsViewController()
        table.tabBarItem = UITabBarItem(title: "Table", image: UIImage(systemName: "list.bullet"), tag: 0)
        grid.tabBarItem = UITabBarItem(title: "Grid", image: UIImage(systemName: "square.grid.2x2"), tag: 1)
        lists.tabBarItem = UITabBarItem(title: "Lists", image: UIImage(systemName: "list.dash"), tag: 2)
        tabs.viewControllers = [table, grid, lists]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: - Table
final class NameCell: UITableViewCell {
    override func willTransition(to state: UITableViewCell.StateMask) { super.willTransition(to: state); if textLabel?.text == "Ada" { log("cell will transition \(state.rawValue)") } }
}
final class TableViewController: UITableViewController {
    var source: UITableViewDiffableDataSourceReference!
    let names = ["Zoe", "Ada", "Émile", "Bob", "Alan", "#hash", "Grace"]
    @objc final class Person: NSObject { @objc let name: String; init(_ n: String) { name = n } }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "People"
        tableView.register(NameCell.self, forCellReuseIdentifier: "c")
        tableView.separatorInsetReference = .fromCellEdges; tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        source = UITableViewDiffableDataSourceReference(tableView: tableView) { tv, ip, item in
            let c = tv.dequeueReusableCell(withIdentifier: "c", for: ip)
            c.textLabel?.text = (item as! Person).name
            if (item as! Person).name == "Ada" { let sw = UISwitch(); c.editingAccessoryView = sw; c.accessibilityIdentifier = "ada" }
            return c
        }
        // the collation sorts the people into A-Z and # sections
        let collation = UILocalizedIndexedCollation.current()
        let people = names.map(Person.init)
        let sorted = collation.sortedArray(from: people, collationStringSelector: #selector(getter: Person.name)) as! [Person]
        let snap = NSDiffableDataSourceSnapshotReference()
        for p in sorted {
            let title = collation.sectionTitles[collation.section(for: p, collationStringSelector: #selector(getter: Person.name))] as NSString
            if snap.indexOfSectionIdentifier(title) == NSNotFound { snap.appendSections(withIdentifiers: [title]) }
            snap.appendItems(withIdentifiers: [p], intoSectionWithIdentifier: title)
        }
        source.applySnapshot(snap, animatingDifferences: false)
        log("collation sections \(snap.sectionIdentifiers.map { $0 as! String }.joined(separator: ","))")
        navigationItem.rightBarButtonItem = editButtonItem
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Change", primaryAction: UIAction { [unowned self] _ in change() })
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "change"
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { source.sectionIdentifier(for: section) as? String }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let header = tableView.rectForHeader(inSection: 1), footer = tableView.rectForFooter(inSection: 1), sec = tableView.rect(forSection: 1)
        log("header at section top \(header.minY == sec.minY) footer at bottom \(footer.maxY == sec.maxY)")
        log("rows in top area \(tableView.indexPathsForRows(in: CGRect(x: 0, y: 0, width: 300, height: 120))?.count ?? 0)")
        log("translating \(tableView.presentationIndexPath(forDataSourceIndexPath: IndexPath(row: 0, section: 0)) == IndexPath(row: 0, section: 0))")
        if let ada = source.indexPath(forItemIdentifier: source.snapshot().itemIdentifiers.first { ($0 as! Person).name == "Ada" }!) { log("ada at \(ada.section)-\(ada.row)") }
    }
    /// moves Bob out and adds Ann: the rows animate in and out
    func change() {
        setEditing(true, animated: false)                  // the edit control (cell state transitions)
        let snap = source.snapshot()
        let bob = snap.itemIdentifiers.first { ($0 as! Person).name == "Bob" }!
        let ann = Person("Ann")
        snap.insertItems(withIdentifiers: [ann], beforeItemWithIdentifier: snap.itemIdentifiers.first { ($0 as! Person).name == "Ada" }!)
        snap.deleteItems(withIdentifiers: [bob])
        source.applySnapshot(snap, animatingDifferences: true) { log("snapshot applied \(self.source.snapshot().numberOfItems)") }
    }
}

// MARK: - Grid
final class GridAttributes: UICollectionViewLayoutAttributes {}
final class GridLayout: UICollectionViewFlowLayout {
    override class var layoutAttributesClass: AnyClass { GridAttributes.self }
    override init() { super.init(); itemSize = CGSize(width: 80, height: 80); sectionInsetReference = .fromLayoutMargins }
    required init?(coder: NSCoder) { fatalError() }
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        log("update items \(updateItems.map { "\($0.updateAction.rawValue)" }.joined(separator: ","))")
    }
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let a = layoutAttributesForItem(at: itemIndexPath)?.copy() as? UICollectionViewLayoutAttributes
        a?.alpha = 0; a?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        log("appearing \(itemIndexPath.item)")
        return a
    }
}
final class GridViewController: UICollectionViewController {
    var items = (1...8).map { "\($0)" }
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .systemBackground
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "g")
        title = "Grid"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", primaryAction: UIAction { [unowned self] _ in
            items.append("\(items.count + 1)"); collectionView.insertItems(at: [IndexPath(item: items.count - 1, section: 0)])
        })
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "add"
        log("standard gesture \(installsStandardGestureForInteractiveMovement)")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.layoutIfNeeded()
        let a = collectionView.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))
        log("attributes class \(a.map { String(describing: type(of: $0)) } ?? "-") x \(Int(a?.frame.minX ?? -1))")
    }
    override func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    override func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let c = cv.dequeueReusableCell(withReuseIdentifier: "g", for: ip)
        let content = UIListContentConfiguration.cell(); content.text = items[ip.item]
        c.contentConfiguration = content
        let bg = UIBackgroundConfiguration.listPlainCell(); bg.backgroundColor = .systemTeal; bg.cornerRadius = 10
        bg.strokeColor = .systemBlue; bg.strokeWidth = 2; bg.strokeOutset = 1
        c.backgroundConfiguration = bg
        c.accessibilityIdentifier = "grid-\(items[ip.item])"
        return c
    }
    override func collectionView(_ cv: UICollectionView, canMoveItemAt ip: IndexPath) -> Bool { true }
    override func collectionView(_ cv: UICollectionView, moveItemAt from: IndexPath, to: IndexPath) {
        let x = items.remove(at: from.item); items.insert(x, at: to.item)
        log("moved \(x) to \(to.item) order \(items.joined(separator: ","))")
    }
}

// MARK: - Lists
final class ListsViewController: UIViewController {
    var collectionView: UICollectionView!
    var source: UICollectionViewDiffableDataSourceReference!
    let contentView = UIListContentView(configuration: .cell())
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let sep = UIListSeparatorConfiguration(listAppearance: .insetGrouped); sep.color = .systemRed; sep.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: 60, bottom: 0, trailing: 0)
        config.separatorConfiguration = sep
        config.itemSeparatorHandler = { ip, s in
            if ip.item == 1 { s.bottomSeparatorVisibility = .hidden }
            return s
        }
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 560), collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth]
        view.addSubview(collectionView)
        let menu = UIMenu(options: .singleSelection, children: ["Low", "High"].map { t in UIAction(title: t, state: t == "Low" ? .on : .off) { _ in } })
        let cellReg = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, ip, item in
            let content = UIListContentConfiguration.cell()
            switch item {
            case "Priority": content.text = item; cell.accessories = [.popUpMenu(menu) { m in log("popup now \(m.children.first { ($0 as? UIAction)?.state == .on }?.title ?? "-")") }]
            case "Attributed":
                content.attributedText = NSAttributedString(string: "Attributed", attributes: [.foregroundColor: UIColor.systemPurple])
                content.secondaryAttributedText = NSAttributedString(string: "secondary", attributes: [.foregroundColor: UIColor.systemOrange])
            case "loud": content.text = item; content.textProperties.transform = .uppercase; content.textProperties.colorTransformer = .grayscale
            default: content.text = item
            }
            cell.contentConfiguration = content
            if item != "Priority" { cell.accessories = [.insert(displayed: .always) { log("insert \(item)") }, .multiselect(displayed: .always)] }
            cell.accessibilityIdentifier = "row-\(item)"
        }
        let headerReg = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { header, _, _ in
            let c = UIListContentConfiguration.prominentInsetGroupedHeader(); c.text = "Prominent"; header.contentConfiguration = c
        }
        source = UICollectionViewDiffableDataSourceReference(collectionView: collectionView) { cv, ip, item in
            let name = item as! String
            return cv.dequeueConfiguredReusableCell(using: cellReg, for: ip, item: name)
        }
        source.supplementaryViewProvider = { cv, kind, ip in cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: ip) }
        // an outline in one section: Fruit (expanded) with two children
        let outline = NSDiffableDataSourceSectionSnapshotReference()
        outline.appendItems(["Priority", "Attributed", "loud", "Fruit"])
        outline.appendItems(["Apple", "Pear"], intoParentItem: "Fruit")
        outline.expandItems(["Fruit"])
        source.applySnapshot(outline, toSection: "main", animatingDifferences: false)
        log("outline visible \(outline.visibleItems.count) level \(outline.level(ofItem: "Pear")) parent \(outline.parent(ofChildItem: "Pear") as? String ?? "-") expanded \(outline.expandedItems().count)")
        let sub = outline.ofParentItem("Fruit")
        log("children snapshot \(sub.items.map { $0 as! String }.joined(separator: ","))")
        // a list content view on its own, with its layout guides
        let c = UIListContentConfiguration.subtitleCell(); c.text = "Guide"; c.secondaryText = "secondary"; c.image = UIImage(systemName: "star")
        contentView.configuration = c
        contentView.frame = CGRect(x: 0, y: 580, width: view.bounds.width, height: 60)
        view.addSubview(contentView)
        if #available(iOS 18.0, *) {
            let shadow = UIBackgroundConfiguration.listCell(); shadow.shadowProperties.opacity = 0.3; shadow.backgroundInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
            log("background copy keeps \(((shadow.copy() as! UIBackgroundConfiguration).shadowProperties.opacity) == 0.3)")
        }
    }
    // badges: supplementary items anchored at the items' top trailing corner, half outside
    lazy var badges: UICollectionView = {
        let badge = NSCollectionLayoutSupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(20), heightDimension: .absolute(20)),
                                                        elementKind: "badge", containerAnchor: NSCollectionLayoutAnchor(edges: [.top, .trailing], fractionalOffset: CGPoint(x: 0.5, y: -0.5)))
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(60), heightDimension: .absolute(60)), supplementaryItems: [badge])
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(60)), subitems: [item])
        group.interItemSpacing = .fixed(20)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12)
        section.orthogonalScrollingProperties.bounce = .never
        let cv = UICollectionView(frame: CGRect(x: 0, y: 660, width: view.bounds.width, height: 90), collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        cv.backgroundColor = .clear
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "b")
        cv.register(UICollectionReusableView.self, forSupplementaryViewOfKind: "badge", withReuseIdentifier: "badge")
        cv.dataSource = badgeSource
        return cv
    }()
    let badgeSource = BadgeSource()
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if badges.superview == nil { view.addSubview(badges); badges.layoutIfNeeded() }
        let item = badges.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame ?? .zero
        let b = badges.layoutAttributesForSupplementaryElement(ofKind: "badge", at: IndexPath(item: 0, section: 0))?.frame ?? .zero
        log("badge centre on corner \(b.midX == item.maxX && b.midY == item.minY) visible \(badges.indexPathsForVisibleSupplementaryElements(ofKind: "badge").count)")
        contentView.layoutIfNeeded()
        let t = contentView.textLayoutGuide?.layoutFrame ?? .zero, i = contentView.imageLayoutGuide?.layoutFrame ?? .zero
        log("guides text after image \(t.minX > i.maxX) secondary \(contentView.secondaryTextLayoutGuide != nil)")
    }
}

final class BadgeSource: NSObject, UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { 3 }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let c = cv.dequeueReusableCell(withReuseIdentifier: "b", for: ip); c.backgroundColor = .systemIndigo; c.layer.cornerRadius = 12; return c
    }
    func collectionView(_ cv: UICollectionView, viewForSupplementaryElementOfKind kind: String, at ip: IndexPath) -> UICollectionReusableView {
        let v = cv.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "badge", for: ip); v.backgroundColor = .systemRed; v.layer.cornerRadius = 10; return v
    }
}
