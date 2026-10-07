// HelloShare: Share and Action extensions on isim (UIKit, Swift).
// The app shares text + a link, or an image, with UIActivityViewController; its Share extension (ShareNote.appex, an
// SLComposeServiceViewController) and Action extension (Uppercase.appex, a custom view controller that returns items)
// are listed when their NSExtensionActivationRule accepts the items. Other installed apps' extensions show up too.
import UIKit

func log(_ s: String) { NSLog("HelloShare: %@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

class ViewController: UIViewController {
    let result = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Share"; title.font = .boldSystemFont(ofSize: 32)
        result.text = "Nothing shared"; result.accessibilityIdentifier = "result"; result.numberOfLines = 3
        let stack = UIStackView(arrangedSubviews: [title, result,
            button("Share Text", "shareText") { [weak self] in self?.share(["Shared note text", URL(string: "https://example.com/article")!]) },
            button("Share Image", "shareImage") { [weak self] in
                let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { ctx in UIColor.systemGreen.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40)) }
                self?.share([image])
            }])
        stack.axis = .vertical; stack.spacing = 14; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }
    func button(_ t: String, _ id: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system, primaryAction: UIAction(title: t) { _ in action() })
        b.accessibilityIdentifier = id
        b.titleLabel?.font = .systemFont(ofSize: 20)
        return b
    }
    func share(_ items: [Any]) {
        let avc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        avc.completionWithItemsHandler = { [weak self] type, completed, returned, error in
            let texts = (returned ?? []).compactMap { ($0 as? NSExtensionItem)?.attributedContentText?.string }
            log("share finished type=\(type?.rawValue ?? "nil") completed=\(completed) returned=\(texts) error=\((error as NSError?)?.code ?? 0)")
            self?.result.text = completed ? (texts.first ?? "Shared with \(type?.rawValue.components(separatedBy: ".").last ?? "")") : "Cancelled"
        }
        present(avc, animated: true)
    }
}
