import UIKit

/// Static cells from Main.storyboard (dataMode="static"): outlets into the cells, an action from a cell's switch,
/// selection segues from cells, and overrides that change the static content and call super.
final class LibraryViewController: UITableViewController {
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var notifySwitch: UISwitch!
    @IBOutlet weak var tallCell: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        let info = Bundle.main.infoDictionary ?? [:]
        versionLabel.text = "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        let sections = numberOfSections(in: tableView)
        let rows = (0..<sections).map { super.tableView(tableView, numberOfRowsInSection: $0) }
        print("library: viewDidLoad sections=\(sections) storyboard rows=\(rows) switch=\(notifySwitch.isOn) "
              + "tall=\(tallCell != nil) dataSource=\(tableView.dataSource === self) axLabel=\(notifySwitch.accessibilityLabel ?? "nil") "
              + "header0=\(super.tableView(tableView, titleForHeaderInSection: 0) ?? "nil") "
              + "footer0=\(super.tableView(tableView, titleForFooterInSection: 0) ?? "nil") "
              + "cell=\(super.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)).textLabel?.text ?? "nil")")
    }

    // the last row of the first section ("Hidden by numberOfRowsInSection") is left out
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let n = super.tableView(tableView, numberOfRowsInSection: section)
        return section == 0 ? n - 1 : n
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        return cell === tallCell ? 88 : super.tableView(tableView, heightForRowAt: indexPath)
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let title = super.tableView(tableView, titleForHeaderInSection: section)
        return section == 1 ? title.map { "\($0) (3)" } : title
    }

    @IBAction func notifyChanged(_ sender: UISwitch) { print("library: notifications \(sender.isOn)") }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("library: shouldPerformSegue \(identifier) sender=\((sender as? UITableViewCell)?.accessibilityIdentifier ?? "nil")")
        return true
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("library: prepare \(segue.identifier ?? "nil") -> \(type(of: segue.destination)) "
              + "storyboard=\(segue.destination.storyboard.map { String(describing: $0).components(separatedBy: " ").last ?? "?" } ?? "nil")")
    }
}

/// Prototype cell of the collection view controller scene.
final class ColorCell: UICollectionViewCell {
    @IBOutlet weak var nameLabel: UILabel!
}

/// A UICollectionViewController scene: the collection view, flow layout and prototype cell come from the storyboard,
/// the data source is code.
final class GalleryViewController: UICollectionViewController {
    let colors: [(String, UIColor)] = [("Red", .systemRed), ("Orange", .systemOrange), ("Yellow", .systemYellow),
                                       ("Green", .systemGreen), ("Teal", .systemTeal), ("Blue", .systemBlue),
                                       ("Indigo", .systemIndigo), ("Purple", .systemPurple), ("Pink", .systemPink)]

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = collectionViewLayout as? UICollectionViewFlowLayout
        print("gallery: viewDidLoad layout=\(layout.map { "\(Int($0.itemSize.width))x\(Int($0.itemSize.height)) spacing=\(Int($0.minimumLineSpacing)) inset=\(Int($0.sectionInset.left))" } ?? "nil") "
              + "dataSource=\(collectionView.dataSource === self) title=\(title ?? "nil")")
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { colors.count }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
        cell.nameLabel.text = colors[indexPath.item].0
        cell.contentView.backgroundColor = colors[indexPath.item].1
        cell.contentView.layer.cornerRadius = 16
        cell.accessibilityIdentifier = "color-\(indexPath.item)"
        return cell
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("gallery: selected \(colors[indexPath.item].0)")
    }
}

/// A UIPageViewController scene (scroll transition, horizontal); its pages are instantiated from the storyboard by
/// identifier.
final class PagesViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    let titles = ["First page", "Second page", "Third page"]

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        setViewControllers([page(0)], direction: .forward, animated: false)
        print("pages: viewDidLoad style=\(transitionStyle == .scroll ? "scroll" : "pageCurl") "
              + "orientation=\(navigationOrientation == .horizontal ? "horizontal" : "vertical")")
    }
    func page(_ i: Int) -> PageContentViewController {
        let vc = storyboard!.instantiateViewController(withIdentifier: "Page") as! PageContentViewController
        vc.index = i
        vc.text = titles[i]
        return vc
    }
    func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
        let i = (vc as! PageContentViewController).index
        return i > 0 ? page(i - 1) : nil
    }
    func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
        let i = (vc as! PageContentViewController).index
        return i + 1 < titles.count ? page(i + 1) : nil
    }
    func presentationCount(for pageViewController: UIPageViewController) -> Int { titles.count }
    func presentationIndex(for pageViewController: UIPageViewController) -> Int { 0 }
    func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        let i = (pvc.viewControllers?.first as? PageContentViewController)?.index ?? -1
        print("pages: now page \(i + 1) completed=\(completed)")
    }
}

final class PageContentViewController: UIViewController {
    @IBOutlet weak var pageLabel: UILabel!
    var index = 0
    var text = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        pageLabel.text = text
        view.backgroundColor = [UIColor.systemIndigo, .systemTeal, .systemOrange][index % 3]
    }
}
