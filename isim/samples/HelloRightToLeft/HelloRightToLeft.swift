// Sample: right-to-left layout on isim — the app's layout direction (from its Arabic localization, Xcode's
// right-to-left pseudolanguage or ISIM_LAYOUT_DIRECTION), leading / trailing constraints, a stack view, natural text
// alignment, directional margins, a navigation bar with a back button, table cells with accessories, an image that
// flips (imageFlippedForRightToLeftLayoutDirection), and a playback row that stays left to right.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController(rootViewController: ListViewController(style: .insetGrouped))
        nav.pushViewController(DetailViewController(), animated: false)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
}

final class ListViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("title", comment: "")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: indexPath.row == 1 ? .value1 : .default, reuseIdentifier: nil)
        c.textLabel?.text = ["Inbox", "Storage", "Done"][indexPath.row]
        c.detailTextLabel?.text = indexPath.row == 1 ? "12 GB" : nil
        c.accessoryType = indexPath.row == 2 ? .checkmark : .disclosureIndicator
        c.accessibilityIdentifier = "row\(indexPath.row)"
        return c
    }
}

final class DetailViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Detail"
        view.backgroundColor = .systemBackground
        let rtl = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        print("direction app=\(rtl ? "rtl" : "ltr") view=\(view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? "rtl" : "ltr") " +
              "trait=\(traitCollection.layoutDirection == .rightToLeft ? "rtl" : "ltr") localization=\(Bundle.main.preferredLocalizations.first ?? "?") " +
              "title=\(NSLocalizedString("title", comment: ""))")

        let first = box(.systemRed, "first"), second = box(.systemGreen, "second")
        let stack = UIStackView(arrangedSubviews: [box(.systemBlue, "s1"), box(.systemOrange, "s2"), box(.systemPurple, "s3")])
        stack.spacing = 8; stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.accessibilityIdentifier = "stack"
        let label = UILabel(); label.text = NSLocalizedString("name", comment: ""); label.accessibilityIdentifier = "label"
        label.backgroundColor = .secondarySystemBackground
        let field = UITextField(); field.borderStyle = .roundedRect; field.text = "abc"; field.accessibilityIdentifier = "field"
        let arrow = UIImageView(image: UIImage(systemName: "arrow.right")?.imageFlippedForRightToLeftLayoutDirection())
        arrow.accessibilityIdentifier = "arrow"; arrow.tintColor = .systemRed
        let player = UIStackView(arrangedSubviews: [box(.systemGray, "rewind"), box(.systemGray2, "play")])
        player.spacing = 8; player.distribution = .fillEqually
        player.semanticContentAttribute = .playback                       // media controls keep their order
        player.accessibilityIdentifier = "player"
        for v in [label, field, arrow, player] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        view.addSubview(stack)
        let g = view.safeAreaLayoutGuide, m = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            first.leadingAnchor.constraint(equalTo: m.leadingAnchor), first.topAnchor.constraint(equalTo: g.topAnchor, constant: 20),
            first.widthAnchor.constraint(equalToConstant: 60), first.heightAnchor.constraint(equalToConstant: 40),
            second.leadingAnchor.constraint(equalTo: first.trailingAnchor, constant: 10), second.topAnchor.constraint(equalTo: first.topAnchor),
            second.widthAnchor.constraint(equalToConstant: 60), second.heightAnchor.constraint(equalToConstant: 40),
            stack.leadingAnchor.constraint(equalTo: m.leadingAnchor), stack.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            stack.topAnchor.constraint(equalTo: first.bottomAnchor, constant: 20), stack.heightAnchor.constraint(equalToConstant: 40),
            label.leadingAnchor.constraint(equalTo: m.leadingAnchor), label.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            label.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            field.leadingAnchor.constraint(equalTo: m.leadingAnchor), field.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            arrow.leadingAnchor.constraint(equalTo: m.leadingAnchor), arrow.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 20),
            arrow.widthAnchor.constraint(equalToConstant: 40), arrow.heightAnchor.constraint(equalToConstant: 40),
            player.leadingAnchor.constraint(equalTo: m.leadingAnchor), player.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            player.topAnchor.constraint(equalTo: arrow.bottomAnchor, constant: 20), player.heightAnchor.constraint(equalToConstant: 40),
        ])
        let margins = view.directionalLayoutMargins
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: margins.top, leading: 30, bottom: margins.bottom, trailing: 10)
        print("margins left=\(Int(view.layoutMargins.left)) right=\(Int(view.layoutMargins.right))")
    }
    func box(_ c: UIColor, _ id: String) -> UIView {
        let v = UIView(); v.backgroundColor = c; v.accessibilityIdentifier = id
        v.translatesAutoresizingMaskIntoConstraints = false
        if !["s1", "s2", "s3", "rewind", "play"].contains(id) { view.addSubview(v) }
        return v
    }
}
