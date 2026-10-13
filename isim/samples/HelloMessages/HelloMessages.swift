// Sample: iOS 26 typed notification messages, each logged with "msg" so the test can check it.
// - UIKit messages: app active, window key, keyboard will show (frame, duration), text field change / end editing (reason),
//   table selection, Bold Text, the user's screenshot (script `takescreenshot`)
// - an app's own MainActorMessage (posted to Swift observers and to an old-style observer of its notification) and an
//   AsyncMessage read as an async sequence; removeObserver(_:) stops an observation
import UIKit

func log(_ s: String) { print("msg \(s)") }

final class Cart { var items = 0 }

@available(iOS 26.0, *)
struct CartChanged: NotificationCenter.MainActorMessage {
    typealias Subject = Cart
    static let name = Notification.Name("CartChanged")
    var count: Int
    static func makeNotification(_ m: CartChanged) -> Notification { Notification(name: name, object: nil, userInfo: ["count": m.count]) }
}
@available(iOS 26.0, *)
struct DownloadFinished: NotificationCenter.AsyncMessage {
    typealias Subject = Cart
    var file: String
}
@available(iOS 26.0, *)
extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<CartChanged> {
    static var cartChanged: Self { .init() }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MessagesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class MessagesViewController: UIViewController, UITableViewDataSource {
    let field = UITextField()
    let table = UITableView()
    let cart = Cart()
    var tokens: [Any] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        field.frame = CGRect(x: 20, y: 80, width: 300, height: 40)
        field.borderStyle = .roundedRect
        field.accessibilityIdentifier = "field"
        view.addSubview(field)
        table.frame = CGRect(x: 0, y: 140, width: view.bounds.width, height: 200)
        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        view.addSubview(table)
        guard #available(iOS 26.0, *) else { log("ready (no messages before iOS 26)"); return }
        observe()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        c.textLabel?.text = "Row \(indexPath.row)"
        c.accessibilityIdentifier = "row\(indexPath.row)"
        return c
    }

    @available(iOS 26.0, *)
    func observe() {
        let nc = NotificationCenter.default
        tokens.append(nc.addObserver(of: UIApplication.shared, for: .didBecomeActive) { _ in log("app active") })
        tokens.append(nc.addObserver(of: UIWindow.self, for: .didBecomeKey) { m in log("window key \(m.window === self.view.window)") })
        tokens.append(nc.addObserver(of: UIScreen.self, for: .keyboardWillShow) { m in
            log("keyboard will show height \(Int(m.endFrame.height)) duration \(m.animationDuration > 0) local \(m.isLocal)")
        })
        tokens.append(nc.addObserver(of: field, for: .textDidChange) { m in log("text \(m.textField.text ?? "")") })
        tokens.append(nc.addObserver(of: field, for: .textDidEndEditing) { m in log("end editing reason \(m.reason == .committed)") })
        tokens.append(nc.addObserver(of: table, for: .selectionDidChange) { m in
            log("selection \(m.tableView.indexPathForSelectedRow?.row ?? -1)")
            self.field.resignFirstResponder()
        })
        tokens.append(nc.addObserver(of: UIAccessibility.self, for: .boldTextStatusDidChange) { _ in log("bold text \(UIAccessibility.isBoldTextEnabled)") })
        tokens.append(nc.addObserver(of: UIApplication.self, for: .userDidTakeScreenshot) { _ in log("screenshot") })

        // the app's own messages
        let cartToken = nc.addObserver(of: cart, for: .cartChanged) { m in log("cart \(m.count)") }
        let old = nc.addObserver(forName: CartChanged.name, object: cart, queue: nil) { n in
            log("cart notification \(n.userInfo?["count"] as? Int ?? -1)")
        }
        nc.post(CartChanged(count: 2), subject: cart)
        nc.removeObserver(cartToken)
        nc.removeObserver(old)
        nc.post(CartChanged(count: 3), subject: cart)          // nobody observes it any more
        let stream = nc.messages(for: DownloadFinished.self)
        Task {
            for await m in stream { log("download \(m.file)"); break }
            log("ready")
        }
        Task { @MainActor in
            await Task.yield()
            nc.post(DownloadFinished(file: "a.zip"))
        }
    }
}
