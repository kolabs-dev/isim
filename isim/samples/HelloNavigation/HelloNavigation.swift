// Sample: UIKit containers on isim — UITabBarController (badge), UINavigationController with large titles
// over a scroll view, push/pop, bar button items (system, title, menu), toolbar items, hidesBottomBarWhenPushed.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let list = UINavigationController(rootViewController: ListViewController())
        list.navigationBar.prefersLargeTitles = true
        list.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "book"), tag: 0)
        let inbox = UINavigationController(rootViewController: InboxViewController())
        inbox.tabBarItem = UITabBarItem(title: "Inbox", image: UIImage(systemName: "envelope"), tag: 1)
        inbox.tabBarItem.badgeValue = "2"
        let tabs = UITabBarController()
        tabs.viewControllers = [list, inbox]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}

final class ListViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { _ in print("add tapped") })
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sort", menu: UIMenu(children: [
            UIAction(title: "Title") { _ in print("sort title") }, UIAction(title: "Date") { _ in print("sort date") }]))
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.accessibilityIdentifier = "list"
        view.addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
        for i in 1...30 {
            let b = UIButton(type: .system)
            b.setTitle("Book \(i)", for: .normal)
            b.contentHorizontalAlignment = .leading
            b.backgroundColor = .secondarySystemGroupedBackground
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            b.accessibilityIdentifier = "book-\(i)"
            b.addAction(UIAction { [weak self] _ in self?.navigationController?.pushViewController(DetailViewController(number: i), animated: true) }, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); print("list appears") }
}

final class DetailViewController: UIViewController {
    let number: Int
    init(number: Int) { self.number = number; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Book \(number)"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        let label = UILabel(); label.text = "Details of book \(number)"; label.accessibilityIdentifier = "detail"
        label.translatesAutoresizingMaskIntoConstraints = false
        let more = UIButton(type: .system); more.setTitle("Read", for: .normal); more.accessibilityIdentifier = "read"
        more.translatesAutoresizingMaskIntoConstraints = false
        more.addAction(UIAction { [weak self] _ in
            let reader = ReaderViewController(); reader.hidesBottomBarWhenPushed = true
            self?.navigationController?.pushViewController(reader, animated: true)
        }, for: .touchUpInside)
        view.addSubview(label); view.addSubview(more)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            more.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20), more.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
        toolbarItems = [UIBarButtonItem(systemItem: .trash, primaryAction: UIAction { _ in print("trash tapped") }), .flexibleSpace(),
                        UIBarButtonItem(title: "Favorite", primaryAction: UIAction { _ in print("favorite tapped") })]
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); navigationController?.setToolbarHidden(false, animated: animated); print("detail \(number) appears") }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); navigationController?.setToolbarHidden(true, animated: animated) }
    @objc func share() { print("share tapped") }
}

final class ReaderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reader"
        view.backgroundColor = .systemYellow
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); print("reader appeared, tab bar hidden: \(tabBarController?.tabBar.isHidden ?? false)") }
}

final class InboxViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inbox"
        view.backgroundColor = .systemBackground
        let l = UILabel(); l.text = "No messages"; l.accessibilityIdentifier = "inbox"
        l.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(l)
        NSLayoutConstraint.activate([l.centerXAnchor.constraint(equalTo: view.centerXAnchor), l.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); print("inbox appeared") }
}
