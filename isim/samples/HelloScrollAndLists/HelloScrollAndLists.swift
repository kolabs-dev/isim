// Sample: scrolling and lists on isim (UIKit) — a paging scroll view, a zooming one whose zoomed view reports its
// scaled frame, an interactive collection view layout transition (grid to list), collection view reordering with the
// drop gap, navigation bar appearances (button, done and back appearances, back indicator, per-item and scroll-edge
// appearances) with a standalone bar and its delegate, and NSItemProvider registrations.
import UIKit
import UniformTypeIdentifiers
import CoreTransferable

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let nav = UINavigationController(rootViewController: MenuViewController())
        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = .systemOrange
        standard.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.boldSystemFont(ofSize: 20)]
        standard.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        standard.doneButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.yellow]
        standard.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        standard.setBackIndicatorImage(UIImage(systemName: "arrow.left"), transitionMaskImage: UIImage(systemName: "arrow.left"))
        nav.navigationBar.standardAppearance = standard
        nav.navigationBar.scrollEdgeAppearance = standard
        nav.navigationBar.tintColor = .white
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
}

func button(_ id: String, _ title: String, y: CGFloat, x: CGFloat = 16, in view: UIView, _ action: @escaping () -> Void) {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.frame = CGRect(x: x, y: y, width: 170, height: 36)
    b.contentHorizontalAlignment = .leading
    b.accessibilityIdentifier = id
    b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
    view.addSubview(b)
}

final class MenuViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scroll & Lists"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)
        let pages: [(String, () -> UIViewController)] = [("paging", { PagingViewController() }), ("layouts", { LayoutsViewController() }),
                                                         ("reorder", { ReorderViewController() }), ("bars", { BarsViewController() }),
                                                         ("providers", { ProvidersViewController() })]
        for (i, (name, make)) in pages.enumerated() {
            button(name, name.capitalized, y: 130 + CGFloat(i) * 44, in: view) { [unowned self] in navigationController?.pushViewController(make(), animated: true) }
        }
    }
}

// MARK: - paging and zooming

final class PagingViewController: UIViewController, UIScrollViewDelegate {
    let pager = UIScrollView(), zoomer = UIScrollView(), photo = UIView()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Paging"
        view.backgroundColor = .systemBackground
        let w = view.bounds.width
        pager.frame = CGRect(x: 0, y: 120, width: w, height: 200)
        pager.isPagingEnabled = true
        pager.contentSize = CGSize(width: w * 3, height: 200)
        pager.delegate = self
        pager.accessibilityIdentifier = "pager"
        for (i, c) in [UIColor.systemRed, .systemGreen, .systemBlue].enumerated() {
            let page = UIView(frame: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: 200))
            page.backgroundColor = c
            pager.addSubview(page)
        }
        view.addSubview(pager)
        zoomer.frame = CGRect(x: 40, y: 360, width: w - 80, height: 300)
        zoomer.minimumZoomScale = 1; zoomer.maximumZoomScale = 3
        zoomer.delegate = self
        zoomer.backgroundColor = .secondarySystemBackground
        zoomer.accessibilityIdentifier = "zoomer"
        photo.frame = CGRect(x: 0, y: 0, width: w - 80, height: 300)
        photo.backgroundColor = .systemTeal
        photo.accessibilityIdentifier = "photo"
        zoomer.addSubview(photo)
        zoomer.contentSize = photo.bounds.size
        view.addSubview(zoomer)
        button("zoom2", "Zoom 2×", y: 680, in: view) { [unowned self] in zoomer.setZoomScale(2, animated: false); report() }
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { scrollView === zoomer ? photo : nil }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) { report() }
    func report() {
        print(String(format: "zoomed frame %.0f x %.0f, scale %.1f, content %.0f x %.0f", photo.frame.width, photo.frame.height, zoomer.zoomScale,
                     zoomer.contentSize.width, zoomer.contentSize.height))
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView === pager { print("page \(Int(round(pager.contentOffset.x / pager.bounds.width)))") }
    }
}

// MARK: - interactive layout transition

final class LayoutsViewController: UIViewController, UICollectionViewDataSource {
    let grid = UICollectionViewFlowLayout(), list = UICollectionViewFlowLayout()
    var collection: UICollectionView!
    var transition: UICollectionViewTransitionLayout?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Layouts"
        view.backgroundColor = .systemBackground
        grid.itemSize = CGSize(width: 80, height: 80); grid.minimumInteritemSpacing = 10; grid.minimumLineSpacing = 10
        grid.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        list.itemSize = CGSize(width: view.bounds.width - 20, height: 44); list.minimumLineSpacing = 6
        list.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collection = UICollectionView(frame: CGRect(x: 0, y: 220, width: view.bounds.width, height: 500), collectionViewLayout: grid)
        collection.dataSource = self
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        collection.accessibilityIdentifier = "collection"
        view.addSubview(collection)
        button("start", "Start", y: 110, in: view) { [unowned self] in
            transition = collection.startInteractiveTransition(to: collection.collectionViewLayout === grid ? list : grid) { completed, finished in
                print("transition completed \(completed) finished \(finished)")
                self.report("after")
            }
        }
        button("half", "Progress 0.5", y: 110, x: 200, in: view) { [unowned self] in
            transition?.transitionProgress = 0.5; collection.layoutIfNeeded(); report("half")
        }
        button("finish", "Finish", y: 150, in: view) { [unowned self] in collection.finishInteractiveTransition() }
        button("cancel", "Cancel", y: 150, x: 200, in: view) { [unowned self] in collection.cancelInteractiveTransition() }
    }
    func report(_ when: String) {
        let f = collection.cellForItem(at: IndexPath(item: 1, section: 0))?.frame ?? .zero
        print(String(format: "%@: item 1 at %.0f,%.0f %.0f x %.0f", when, f.minX, f.minY, f.width, f.height))
    }
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 12 }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let c = cv.dequeueReusableCell(withReuseIdentifier: "c", for: ip)
        c.backgroundColor = UIColor(hue: CGFloat(ip.item) / 12, saturation: 0.6, brightness: 0.9, alpha: 1)
        c.accessibilityIdentifier = "item-\(ip.item)"
        return c
    }
}

// MARK: - reordering with the drop gap

final class ReorderViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    var items = (0..<9).map { "Tile \($0)" }
    var collection: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reorder"
        view.backgroundColor = .systemBackground
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 110, height: 110); layout.minimumInteritemSpacing = 10; layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        collection = UICollectionView(frame: CGRect(x: 0, y: 110, width: view.bounds.width, height: 600), collectionViewLayout: layout)
        collection.dataSource = self; collection.dragDelegate = self; collection.dropDelegate = self
        collection.dragInteractionEnabled = true
        collection.register(TileCell.self, forCellWithReuseIdentifier: "t")
        view.addSubview(collection)
    }
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { items.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let c = cv.dequeueReusableCell(withReuseIdentifier: "t", for: ip) as! TileCell
        c.label.text = items[ip.item]
        c.accessibilityIdentifier = items[ip.item].replacingOccurrences(of: " ", with: "-").lowercased()
        return c
    }
    func collectionView(_ cv: UICollectionView, moveItemAt s: IndexPath, to d: IndexPath) {
        let it = items.remove(at: s.item); items.insert(it, at: d.item)
        print("order: \(items.joined(separator: ","))")
    }
    func collectionView(_ cv: UICollectionView, itemsForBeginning session: UIDragSession, at ip: IndexPath) -> [UIDragItem] {
        [UIDragItem(itemProvider: NSItemProvider(object: items[ip.item] as NSString))]
    }
    func collectionView(_ cv: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath ip: IndexPath?) -> UICollectionViewDropProposal {
        UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    func collectionView(_ cv: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {}
}
final class TileCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemIndigo
        label.textColor = .white; label.textAlignment = .center
        label.frame = contentView.bounds; label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - bars

final class BarsViewController: UIViewController, UINavigationBarDelegate {
    let bar = UINavigationBar()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bars"
        view.backgroundColor = .systemBackground
        let mine = UINavigationBarAppearance()                         // this item's own look while it is on top
        mine.configureWithOpaqueBackground()
        mine.backgroundColor = .systemPurple
        mine.titleTextAttributes = [.foregroundColor: UIColor.white]
        mine.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = mine
        navigationItem.scrollEdgeAppearance = mine
        // a standalone bar with its own stack of items
        bar.frame = CGRect(x: 0, y: 300, width: view.bounds.width, height: 44)
        bar.delegate = self
        bar.accessibilityIdentifier = "standalone"
        bar.items = [UINavigationItem(title: "First")]
        view.addSubview(bar)
        button("push-item", "Push item", y: 380, in: view) { [unowned self] in bar.pushItem(UINavigationItem(title: "Second"), animated: true) }
    }
    func navigationBar(_ navigationBar: UINavigationBar, didPush item: UINavigationItem) { print("bar pushed \(item.title ?? "")") }
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool { print("bar should pop \(item.title ?? "")"); return true }
    func navigationBar(_ navigationBar: UINavigationBar, didPop item: UINavigationItem) { print("bar popped \(item.title ?? "")") }
}

// MARK: - item providers

struct Note: Transferable, Codable {
    var text: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .plainText, exporting: { Data($0.text.utf8) }, importing: { Note(text: String(decoding: $0, as: UTF8.self)) })
    }
}

final class ProvidersViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Providers"
        view.backgroundColor = .systemBackground
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hello.txt")
        try? Data("file contents".utf8).write(to: file)
        let a = NSItemProvider()
        a.registerFileRepresentation(forTypeIdentifier: UTType.plainText.identifier, fileOptions: [.openInPlace], visibility: .all) { done in
            done(file, true, nil); return nil
        }
        a.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.plainText.identifier) { url, inPlace, _ in
            print("in place: \(url?.lastPathComponent ?? "nil") \(inPlace)")
        }
        a.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { d, _ in print("file data: \(d.map { String(decoding: $0, as: UTF8.self) } ?? "nil")") }
        let b = NSItemProvider()
        b.registerItem(forTypeIdentifier: UTType.url.identifier) { completion, _, _ in completion(URL(string: "https://isim.dev")! as NSURL, nil) }
        b.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in print("item: \((item as? URL)?.absoluteString ?? "nil")") }
        let c = NSItemProvider()
        c.registerObject(ofClass: NSString.self, visibility: .all) { done in done("lazy string" as NSString, nil); return nil }
        _ = c.loadObject(ofClass: NSString.self) { obj, _ in print("object: \((obj as? NSString).map { $0 as String } ?? "nil")") }
        let d = NSItemProvider()
        d.register(Note(text: "a transferable note"))
        d.loadTransferable(type: Note.self) { result in
            if case .success(let n) = result { print("transferable: \(n.text)") } else { print("transferable failed") }
        }
        d.preferredPresentationSize = CGSize(width: 120, height: 80)
        d.previewImageHandler = { completion, _, _ in completion(UIImage(systemName: "star"), nil) }
        d.loadPreviewImage(options: nil) { image, _ in print("preview: \(image is UIImage) size \(Int(d.preferredPresentationSize.width))") }
    }
}
