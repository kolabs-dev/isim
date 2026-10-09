// Sample: collection view layouts and lists on isim (UIKit) — outlines (NSDiffableDataSourceSectionSnapshot, outline
// disclosure, section snapshot handlers), list swipe actions, reordering (reorder accessory + reorderingHandlers),
// a custom UIContentConfiguration (updated for the selected state), compositional decoration items, a custom group,
// visibleItemsInvalidationHandler, a horizontally scrolling compositional layout, prefetching and a custom flow
// layout with decoration views.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: MenuViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class MenuViewController: UITableViewController {
    let demos: [(String, () -> UIViewController)] = [
        ("Outline", { OutlineViewController() }), ("Gallery", { GalleryViewController() }),
        ("Horizontal", { HorizontalViewController() }), ("Shelf", { ShelfViewController() }),
    ]
    override func viewDidLoad() { super.viewDidLoad(); title = "Layouts"; tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c") }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { demos.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        let content = c.defaultContentConfiguration(); content.text = demos[indexPath.row].0
        c.contentConfiguration = content
        c.accessibilityIdentifier = "demo-\(demos[indexPath.row].0.lowercased())"
        return c
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.pushViewController(demos[indexPath.row].1(), animated: false)
    }
}

// MARK: - a custom content configuration: a label in a colored pill (blue when selected)
struct BadgeConfiguration: UIContentConfiguration, Hashable {
    var text = ""
    var color = UIColor.systemGray
    func makeContentView() -> UIView & UIContentView { BadgeContentView(configuration: self) }
    func updated(for state: UIConfigurationState) -> BadgeConfiguration {
        var c = self
        if let cell = state as? UICellConfigurationState, cell.isSelected { c.color = .systemBlue; c.text = text.hasSuffix(" ✓") ? text : text + " ✓" }
        return c
    }
}
final class BadgeContentView: UIView, UIContentView {
    let pill = UIView(), label = UILabel()
    var configuration: UIContentConfiguration { didSet { apply() } }
    init(configuration: BadgeConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        pill.layer.cornerRadius = 14
        pill.translatesAutoresizingMaskIntoConstraints = false; label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        addSubview(pill); pill.addSubview(label)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), pill.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8), pill.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12), label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])
        apply()
    }
    required init?(coder: NSCoder) { fatalError() }
    func supports(_ configuration: UIContentConfiguration) -> Bool { configuration is BadgeConfiguration }
    func apply() {
        guard let c = configuration as? BadgeConfiguration else { return }
        label.text = c.text; pill.backgroundColor = c.color
        accessibilityIdentifier = "badge-\(c.text)"
        print("badge: \(c.text)")
    }
}

// MARK: - outline, swipe actions, reordering, custom content
enum Row: Hashable { case group(String), fruit(String), badge(String) }

final class OutlineViewController: UIViewController {
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<String, Row>!
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Outline"
        let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.trailingSwipeActionsConfigurationProvider = { [unowned self] ip in
            guard case .fruit(let name)? = dataSource.itemIdentifier(for: ip) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] _, _, done in
                var s = dataSource.snapshot(for: "Fruit"); s.delete([.fruit(name)])
                dataSource.apply(s, to: "Fruit")
                print("deleted \(name)")
                done(true)
            }
            return UISwipeActionsConfiguration(actions: [delete])
        }
        config.leadingSwipeActionsConfigurationProvider = { [unowned self] ip in
            guard case .fruit(let name)? = dataSource.itemIdentifier(for: ip) else { return nil }
            let pin = UIContextualAction(style: .normal, title: "Pin") { _, _, done in print("pinned \(name)"); done(true) }
            pin.backgroundColor = .systemOrange
            return UISwipeActionsConfiguration(actions: [pin])
        }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: config))
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.accessibilityIdentifier = "outline"
        view.addSubview(collectionView)
        let rowCell = UICollectionView.CellRegistration<UICollectionViewListCell, Row> { cell, _, row in
            switch row {
            case .group(let name):
                let c = cell.defaultContentConfiguration(); c.text = name; c.textProperties.font = .boldSystemFont(ofSize: 17)
                cell.contentConfiguration = c
                cell.accessories = [.outlineDisclosure()]
                cell.accessibilityIdentifier = "group-\(name)"
            case .fruit(let name):
                let c = cell.defaultContentConfiguration(); c.text = name
                cell.contentConfiguration = c
                cell.accessories = [.reorder()]
                cell.accessibilityIdentifier = "fruit-\(name)"
            case .badge(let text):
                cell.contentConfiguration = BadgeConfiguration(text: text, color: .systemGray)
                cell.accessories = []
                cell.configurationUpdateHandler = { _, state in print("update handler \(text) selected \(state.isSelected)") }
                cell.accessibilityIdentifier = "badgecell-\(text)"
            }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, ip, row in
            cv.dequeueConfiguredReusableCell(using: rowCell, for: ip, item: row)
        }
        dataSource.sectionSnapshotHandlers.willExpandItem = { row in print("will expand \(row)") }
        dataSource.sectionSnapshotHandlers.willCollapseItem = { row in print("will collapse \(row)") }
        dataSource.reorderingHandlers.canReorderItem = { row in if case .fruit = row { return true }; return false }
        dataSource.reorderingHandlers.didReorder = { t in
            let names = t.finalSnapshot.itemIdentifiers.compactMap { row -> String? in if case .fruit(let n) = row { return n }; return nil }
            print("reordered: \(names.joined(separator: ","))")
        }
        var sections = NSDiffableDataSourceSnapshot<String, Row>()
        sections.appendSections(["Fruit", "Badges"])
        dataSource.apply(sections, animatingDifferences: false)
        var fruit = NSDiffableDataSourceSectionSnapshot<Row>()
        fruit.append([.group("Citrus"), .group("Berries")])
        fruit.append([.fruit("Lemon"), .fruit("Orange"), .fruit("Lime")], to: .group("Citrus"))
        fruit.append([.fruit("Strawberry"), .fruit("Blueberry")], to: .group("Berries"))
        fruit.expand([.group("Citrus")])
        dataSource.apply(fruit, to: "Fruit", animatingDifferences: false)
        var badges = NSDiffableDataSourceSectionSnapshot<Row>()
        badges.append([.badge("New"), .badge("Sale")])
        dataSource.apply(badges, to: "Badges", animatingDifferences: false)
        print("outline: \(fruit.visibleItems.count) visible of \(fruit.items.count), level of Lemon \(fruit.level(of: .fruit("Lemon")))")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", primaryAction: UIAction { [unowned self] _ in
            collectionView.isEditing.toggle()
            print("editing \(collectionView.isEditing)")
        })
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "edit"
        Task { @MainActor in                                              // async apply (iOS 15)
            var s = dataSource.snapshot()
            s.reconfigureItems(s.itemIdentifiers(inSection: "Badges"))
            await dataSource.apply(s, animatingDifferences: false)
            print("async apply finished")
        }
    }
}

// MARK: - compositional: section background, carousel scaling, custom group; prefetching
final class SectionBackground: UICollectionReusableView {
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1); layer.cornerRadius = 12; accessibilityIdentifier = "section-background" }
    required init?(coder: NSCoder) { fatalError() }
}
final class GalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDataSourcePrefetching {
    var collectionView: UICollectionView!
    let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemTeal, .systemBlue, .systemIndigo, .systemPurple]
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gallery"
        view.backgroundColor = .systemBackground
        let layout = UICollectionViewCompositionalLayout { section, env in
            switch section {
            case 0:                                                     // a carousel whose items scale toward the center
                let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .absolute(200), heightDimension: .absolute(140)), subitems: [item])
                let s = NSCollectionLayoutSection(group: group)
                s.orthogonalScrollingBehavior = .continuous
                s.interGroupSpacing = 16
                s.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                s.visibleItemsInvalidationHandler = { items, offset, env in
                    let mid = env.container.contentSize.width / 2
                    var scales: [String] = []
                    for item in items.sorted(by: { $0.indexPath.item < $1.indexPath.item }) {
                        let d = abs(item.frame.midX - offset.x - mid)
                        let scale = max(0.7, 1 - d / mid * 0.3)
                        item.transform = CGAffineTransform(scaleX: scale, y: scale)
                        if item.indexPath.item < 3 { scales.append(String(format: "%.2f", scale)) }
                    }
                    print("carousel offset \(Int(offset.x)): scales \(scales.joined(separator: ","))")
                }
                return s
            default:                                                    // a custom (staggered) group on a section background
                let group = NSCollectionLayoutGroup.custom(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(150))) { env in
                    let w = (env.container.contentSize.width - 48) / 3
                    return (0..<3).map { NSCollectionLayoutGroupCustomItem(frame: CGRect(x: 16 + CGFloat($0) * (w + 8), y: CGFloat($0) * 20, width: w, height: 100)) }
                }
                let s = NSCollectionLayoutSection(group: group)
                s.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
                let bg = NSCollectionLayoutDecorationItem.background(elementKind: "background")
                bg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                s.decorationItems = [bg]
                return s
            }
        }
        layout.register(SectionBackground.self, forDecorationViewOfKind: "background")
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self
        view.addSubview(collectionView)
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { section == 0 ? 8 : 60 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath)
        c.backgroundColor = colors[indexPath.item % colors.count]
        c.layer.cornerRadius = 10
        c.accessibilityIdentifier = "tile-\(indexPath.section)-\(indexPath.item)"
        return c
    }
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        print("prefetch \(indexPaths.map { "\($0.section)-\($0.item)" }.joined(separator: ","))")
    }
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        print("cancel prefetch \(indexPaths.count)")
    }
}

// MARK: - a horizontally scrolling compositional layout
final class HorizontalViewController: UIViewController, UICollectionViewDataSource {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Horizontal"
        view.backgroundColor = .systemBackground
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.5)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .absolute(150), heightDimension: .absolute(300)), subitems: [item, item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .absolute(60), heightDimension: .fractionalHeight(1)),
                                                                 elementKind: "label", alignment: .leading)
        section.boundarySupplementaryItems = [header]
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        config.interSectionSpacing = 30
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: config)
        let cv = UICollectionView(frame: CGRect(x: 0, y: 120, width: view.bounds.width, height: 320), collectionViewLayout: layout)
        cv.accessibilityIdentifier = "horizontal"
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        cv.register(UICollectionReusableView.self, forSupplementaryViewOfKind: "label", withReuseIdentifier: "l")
        cv.dataSource = self
        view.addSubview(cv)
        DispatchQueue.main.async { print("horizontal content \(Int(cv.contentSize.width))x\(Int(cv.contentSize.height))") }
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 6 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath)
        c.backgroundColor = indexPath.section == 0 ? .systemGreen : .systemPurple
        c.accessibilityIdentifier = "h-\(indexPath.section)-\(indexPath.item)"
        return c
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "l", for: indexPath)
        v.backgroundColor = .systemGray4
        v.accessibilityIdentifier = "label-\(indexPath.section)"
        return v
    }
}

// MARK: - a custom flow layout with decoration views (a shelf under each row)
final class ShelfView: UICollectionReusableView {
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .brown; accessibilityIdentifier = "shelf" }
    required init?(coder: NSCoder) { fatalError() }
}
final class ShelfLayout: UICollectionViewFlowLayout {
    override init() { super.init(); itemSize = CGSize(width: 100, height: 120); minimumLineSpacing = 30; sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20); register(ShelfView.self, forDecorationViewOfKind: "shelf") }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var out = super.layoutAttributesForElements(in: rect) ?? []
        var rows: [CGFloat: Int] = [:]
        for a in out where a.representedElementCategory == .cell { rows[a.frame.maxY] = a.indexPath.item }
        for (i, y) in rows.keys.sorted().enumerated() {
            let shelf = UICollectionViewLayoutAttributes(forDecorationViewOfKind: "shelf", with: IndexPath(item: i, section: 0))
            shelf.frame = CGRect(x: 0, y: y + 2, width: collectionViewContentSize.width, height: 12)
            out.append(shelf)
        }
        return out
    }
}
final class ShelfViewController: UIViewController, UICollectionViewDataSource {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shelf"
        let cv = UICollectionView(frame: view.bounds, collectionViewLayout: ShelfLayout())
        cv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        cv.dataSource = self
        view.addSubview(cv)
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 9 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath)
        c.backgroundColor = .systemTeal
        return c
    }
}
