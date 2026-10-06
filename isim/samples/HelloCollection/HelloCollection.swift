// Sample: UICollectionView on isim — a flow-layout grid (UICollectionViewController, headers, selection, inserts and
// deletes), a compositional layout (orthogonal carousel, two-column grid, estimated headers, cell registrations,
// diffable data source) and a list layout (inset grouped, list cells, accessories, self-sizing rows).
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let flow = UICollectionViewFlowLayout()
        flow.itemSize = CGSize(width: 110, height: 80)
        flow.minimumInteritemSpacing = 8
        flow.minimumLineSpacing = 8
        flow.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        flow.headerReferenceSize = CGSize(width: 0, height: 36)
        let grid = UINavigationController(rootViewController: GridViewController(collectionViewLayout: flow))
        grid.tabBarItem = UITabBarItem(title: "Grid", image: UIImage(systemName: "square.grid.2x2"), tag: 0)
        let shelf = UINavigationController(rootViewController: ShelfViewController())
        shelf.tabBarItem = UITabBarItem(title: "Shelf", image: UIImage(systemName: "books.vertical"), tag: 1)
        let list = UINavigationController(rootViewController: ListViewController())
        list.tabBarItem = UITabBarItem(title: "List", image: UIImage(systemName: "list.bullet"), tag: 2)
        let tabs = UITabBarController()
        tabs.viewControllers = [grid, shelf, list]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: - Flow layout grid
final class TileCell: UICollectionViewCell {
    static var created = 0
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        TileCell.created += 1
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                                     label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)])
        let selected = UIView(); selected.backgroundColor = UIColor.black.withAlphaComponent(0.25); selected.layer.cornerRadius = 12
        selectedBackgroundView = selected
    }
    required init?(coder: NSCoder) { fatalError() }
}
final class HeaderView: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                                     label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)])
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class GridViewController: UICollectionViewController {
    var sections: [[Int]] = [Array(1...12), Array(13...60)]
    var nextNumber = 61
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Grid"
        collectionView.register(TileCell.self, forCellWithReuseIdentifier: "tile")
        collectionView.register(HeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.add() })
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Remove", primaryAction: UIAction { [weak self] _ in self?.removeSelected() })
        collectionView.allowsMultipleSelection = true
    }
    func add() {
        sections[0].insert(nextNumber, at: 0); nextNumber += 1
        collectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
        print("grid inserted, items \(collectionView.numberOfItems(inSection: 0))")
    }
    func removeSelected() {
        let paths = collectionView.indexPathsForSelectedItems ?? []
        for p in paths.sorted(by: >) { sections[p.section].remove(at: p.item) }
        collectionView.deleteItems(at: paths)
        print("grid removed \(paths.count), items \(collectionView.numberOfItems(inSection: 0))")
    }
    override func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { sections[section].count }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tile", for: indexPath) as! TileCell
        let n = sections[indexPath.section][indexPath.item]
        cell.label.text = "\(n)"
        cell.contentView.backgroundColor = [UIColor.systemBlue, .systemPink, .systemGreen, .systemOrange, .systemPurple][n % 5]
        cell.accessibilityIdentifier = "tile-\(n)"
        return cell
    }
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! HeaderView
        header.label.text = indexPath.section == 0 ? "Favorites" : "All tiles"
        return header
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("grid selected \(sections[indexPath.section][indexPath.item]), selected \(collectionView.indexPathsForSelectedItems?.count ?? 0)")
    }
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 700, !reported {
            reported = true
            print("grid cells created \(TileCell.created), visible \(collectionView.visibleCells.count)")
        }
    }
    var reported = false
}

// MARK: - Compositional layout with registrations + diffable data source
final class ShelfViewController: UIViewController {
    enum Section: Int { case featured, books }
    struct Book: Hashable { let id: Int; let title: String }
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Section, Book>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shelf"
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        view.addSubview(collectionView)

        let card = UICollectionView.CellRegistration<UICollectionViewCell, Book> { cell, _, book in
            var content = UIListContentConfiguration.cell()
            content.text = book.title
            content.textProperties.color = .white
            content.textProperties.font = .systemFont(ofSize: 20, weight: .bold)
            cell.contentConfiguration = content
            cell.contentView.backgroundColor = book.id % 2 == 0 ? .systemIndigo : .systemTeal
            cell.contentView.layer.cornerRadius = 14
            cell.accessibilityIdentifier = "featured-\(book.id)"
        }
        let cover = UICollectionView.CellRegistration<UICollectionViewCell, Book> { cell, _, book in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = book.title
            content.secondaryText = "Book \(book.id)"
            cell.contentConfiguration = content
            cell.contentView.backgroundColor = .secondarySystemBackground
            cell.contentView.layer.cornerRadius = 10
            cell.accessibilityIdentifier = "book-\(book.id)"
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, indexPath in
            var content = UIListContentConfiguration.plainHeader()
            content.text = indexPath.section == 0 ? "Featured" : "All books"
            view.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, book in
            cv.dequeueConfiguredReusableCell(using: indexPath.section == 0 ? card : cover, for: indexPath, item: book)
        }
        dataSource.supplementaryViewProvider = { cv, _, indexPath in cv.dequeueConfiguredReusableSupplementary(using: header, for: indexPath) }

        var snap = NSDiffableDataSourceSnapshot<Section, Book>()
        snap.appendSections([.featured, .books])
        snap.appendItems((1...6).map { Book(id: $0, title: "Featured \($0)") }, toSection: .featured)
        snap.appendItems((101...120).map { Book(id: $0, title: "Title \($0 - 100)") }, toSection: .books)
        dataSource.apply(snap, animatingDifferences: false)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Trim", primaryAction: UIAction { [weak self] _ in self?.trim() })
    }
    func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { section, env in
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(30)),
                elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            if section == 0 {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.8), heightDimension: .absolute(150)), subitems: [item])
                let s = NSCollectionLayoutSection(group: group)
                s.orthogonalScrollingBehavior = .groupPaging
                s.interGroupSpacing = 12
                s.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)
                s.boundarySupplementaryItems = [header]
                return s
            }
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(90)), subitems: [item])
            let s = NSCollectionLayoutSection(group: group)
            s.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12)
            s.boundarySupplementaryItems = [header]
            return s
        }
    }
    func trim() {
        var snap = dataSource.snapshot()
        let books = snap.itemIdentifiers(inSection: .books)
        snap.deleteItems(books.filter { $0.id % 3 == 0 })
        dataSource.apply(snap) { [weak self] in
            guard let self else { return }
            print("shelf books \(self.collectionView.numberOfItems(inSection: 1)), first \(self.dataSource.itemIdentifier(for: IndexPath(item: 2, section: 1))?.title ?? "-")")
        }
    }
}
extension ShelfViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("shelf selected \(dataSource.itemIdentifier(for: indexPath)?.title ?? "?")")
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - List layout
final class ListViewController: UIViewController {
    struct Row: Hashable { let name: String; let detail: String?; var done: Bool }
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<String, String>!
    var rows: [String: Row] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "List"
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: config))
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        view.addSubview(collectionView)

        for (n, d) in [("Milk", "2 litres"), ("Bread", nil), ("Coffee", "Whole beans, medium roast — the long note wraps to show self-sizing list rows in a collection view"), ("Apples", "6"), ("Rice", nil)] {
            rows[n] = Row(name: n, detail: d, done: n == "Bread")
        }
        let cellReg = UICollectionView.CellRegistration<UICollectionViewListCell, String> { [weak self] cell, _, name in
            guard let row = self?.rows[name] else { return }
            var content = cell.defaultContentConfiguration()
            content.text = row.name
            content.secondaryText = row.detail
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
            cell.accessories = row.done ? [.checkmark()] : [.label(text: "todo"), .disclosureIndicator()]
            cell.accessibilityIdentifier = "row-\(name)"
        }
        let headerReg = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = indexPath.section == 0 ? "GROCERIES" : "PANTRY"
            view.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, ip, name in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: ip, item: name)
        }
        dataSource.supplementaryViewProvider = { cv, _, ip in cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: ip) }
        var snap = NSDiffableDataSourceSnapshot<String, String>()
        snap.appendSections(["groceries", "pantry"])
        snap.appendItems(["Milk", "Bread", "Coffee"], toSection: "groceries")
        snap.appendItems(["Apples", "Rice"], toSection: "pantry")
        dataSource.apply(snap, animatingDifferences: false)
    }
}
extension ListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let name = dataSource.itemIdentifier(for: indexPath) else { return }
        rows[name]?.done.toggle()
        var snap = dataSource.snapshot()
        snap.reconfigureItems([name])
        dataSource.apply(snap)
        collectionView.deselectItem(at: indexPath, animated: true)
        let cell = collectionView.cellForItem(at: indexPath) as? UICollectionViewListCell
        print("list toggled \(name) done \(rows[name]!.done), accessories \(cell?.accessories.count ?? -1)")
    }
}
