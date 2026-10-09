// Sample: iOS 26 UIKit bar APIs (run with --os 26 or 27; earlier versions show the same tabs without them).
// - UINavigationItem subtitles: `subtitle` + `largeSubtitle` under a large title (Inbox), an inline title with an
//   attributed subtitle (Details), and a subtitle view.
// - UITabBarController: `tabBarMinimizeBehavior = .onScrollDown` (scroll the Inbox list down to shrink the tab bar to
//   the selected tab, tap it to expand), a `bottomAccessory` (UITabAccessory) whose content view follows the
//   `tabAccessoryEnvironment` trait (regular above the bar, inline beside the minimized bar), `contentLayoutGuide`.
// - UIButton.Configuration.symbolContentTransition: the Player tab's glass button replaces play.fill / pause.fill.
import UIKit
import Symbols

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let inbox = UINavigationController(rootViewController: InboxViewController())
        inbox.navigationBar.prefersLargeTitles = true
        inbox.tabBarItem = UITabBarItem(title: "Inbox", image: UIImage(systemName: "tray"), tag: 0)
        let player = UINavigationController(rootViewController: PlayerViewController())
        player.tabBarItem = UITabBarItem(title: "Player", image: UIImage(systemName: "play.circle"), tag: 1)
        let tabs = UITabBarController()
        tabs.viewControllers = [inbox, player]
        if #available(iOS 26, *) {
            tabs.tabBarMinimizeBehavior = .onScrollDown
            tabs.bottomAccessory = UITabAccessory(contentView: NowPlayingView())
            print("hmb ios26 yes minimize \(tabs.tabBarMinimizeBehavior == .onScrollDown)")
        } else {
            print("hmb ios26 no")
        }
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        if #available(iOS 26, *) {
            DispatchQueue.main.async {
                let f = tabs.contentLayoutGuide.layoutFrame
                print("hmb content guide \(Int(f.minX)) \(Int(f.minY)) \(Int(f.width)) \(Int(f.height))")
            }
        }
        return true
    }
}

/// The accessory's content: a "Now Playing" row; inline (beside the minimized tab bar) it shows only the title.
final class NowPlayingView: UIView {
    let title = UILabel(), detail = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        title.text = "Now Playing"; title.font = .systemFont(ofSize: 15, weight: .semibold)
        detail.text = "Track 1"; detail.font = .systemFont(ofSize: 15); detail.textColor = .secondaryLabel
        title.accessibilityIdentifier = "accessory-title"; detail.accessibilityIdentifier = "accessory-detail"
        addSubview(title); addSubview(detail)
        if #available(iOS 26, *) {
            registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (v: NowPlayingView, _: UITraitCollection) in v.environmentChanged() }
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    @available(iOS 26, *)
    func environmentChanged() {
        let env = traitCollection.tabAccessoryEnvironment
        print("hmb accessory environment \(env == .inline ? "inline" : env == .regular ? "regular" : "other")")
        detail.isHidden = env == .inline
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        title.frame = CGRect(x: 0, y: 0, width: 110, height: bounds.height)
        detail.frame = CGRect(x: 118, y: 0, width: max(0, bounds.width - 118), height: bounds.height)
    }
}

final class InboxViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inbox"
        if #available(iOS 26, *) {
            navigationItem.subtitle = "12 Unread"
            navigationItem.largeSubtitle = "Updated Just Now"
        }
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        tableView.accessibilityIdentifier = "inbox-list"
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        c.textLabel?.text = "Message \(indexPath.row + 1)"
        c.accessibilityIdentifier = "row-\(indexPath.row)"
        return c
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.pushViewController(DetailViewController(row: indexPath.row), animated: true)
    }
}

/// An inline title with an attributed subtitle, and a subtitle view in the large-title band.
final class DetailViewController: UIViewController {
    let row: Int
    init(row: Int) { self.row = row; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Message \(row + 1)"
        navigationItem.largeTitleDisplayMode = .never
        if #available(iOS 26, *) {
            var from = AttributedString("From Alice"); from.foregroundColor = UIColor.systemBlue
            navigationItem.attributedSubtitle = from
        }
        print("hmb detail \(row + 1)")
    }
}

final class PlayerViewController: UIViewController {
    var playing = false
    let button = UIButton(type: .system)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.6, alpha: 1)
        title = "Player"
        navigationItem.largeTitleDisplayMode = .never
        if #available(iOS 26, *) {
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
            dot.backgroundColor = .systemGreen; dot.layer.cornerRadius = 4; dot.accessibilityIdentifier = "live-dot"
            navigationItem.subtitleView = dot
        }
        button.configuration = configuration(image: "play.fill")
        button.accessibilityIdentifier = "play"
        button.addAction(UIAction { [weak self] _ in self?.toggle() }, for: .primaryActionTriggered)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([button.centerXAnchor.constraint(equalTo: view.centerXAnchor), button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                                     button.widthAnchor.constraint(equalToConstant: 88), button.heightAnchor.constraint(equalToConstant: 88)])
    }
    /// a glass button that replaces its symbol (iOS 26), else a filled one
    func configuration(image: String) -> UIButton.Configuration {
        var config: UIButton.Configuration
        if #available(iOS 26, *) {
            config = .glass()
            config.symbolContentTransition = UISymbolContentTransition(.replace.downUp)
        } else {
            config = .filled()
        }
        config.image = UIImage(systemName: image)
        return config
    }
    func toggle() {
        playing.toggle()
        button.configuration = configuration(image: playing ? "pause.fill" : "play.fill")
        if #available(iOS 26, *), let t = button.configuration?.symbolContentTransition {
            print("hmb player \(playing ? "playing" : "paused") transition \(t.contentTransition is ReplaceSymbolEffect)")
        } else {
            print("hmb player \(playing ? "playing" : "paused")")
        }
    }
}
