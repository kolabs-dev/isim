// Sample: the pasteboard on isim (UIKit) — reading another app's content asks first (Paste from Other Apps), a user
// paste (Ctrl+V, the edit menu, UIPasteControl) does not; pattern detection without reading; item providers,
// setObjects, expiring items, item sets and data, the changed notification's types.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = PasteboardViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class PasteboardViewController: UIViewController, UITextFieldDelegate {
    let field = UITextField()
    let pasteControl: UIPasteControl = {
        let c = UIPasteControl.Configuration()
        c.displayMode = .iconAndLabel
        c.cornerStyle = .capsule
        return UIPasteControl(configuration: c)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(frame: CGRect(x: 20, y: 70, width: 300, height: 30))
        title.text = "Pasteboard"; title.font = .boldSystemFont(ofSize: 28)
        field.frame = CGRect(x: 20, y: 120, width: 300, height: 40)
        field.borderStyle = .roundedRect
        field.placeholder = "Ctrl+V here"
        field.accessibilityIdentifier = "field"
        field.addAction(UIAction { [unowned self] _ in print("field: \(field.text ?? "")") }, for: .editingChanged)
        pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        pasteControl.frame = CGRect(x: 20, y: 180, width: 120, height: 44)
        pasteControl.target = self
        pasteControl.accessibilityIdentifier = "pasteControl"
        view.addSubview(title); view.addSubview(field); view.addSubview(pasteControl)
        let buttons: [(String, () -> Void)] = [
            ("read", { [unowned self] in read() }),
            ("detect", { [unowned self] in detect() }),
            ("copy", { UIPasteboard.general.string = "Hello from Paste" }),
            ("extras", { [unowned self] in extras() }),
        ]
        for (i, (name, action)) in buttons.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(name.capitalized, for: .normal)
            b.frame = CGRect(x: 20 + CGFloat(i % 2) * 150, y: 250 + CGFloat(i / 2) * 50, width: 130, height: 40)
            b.accessibilityIdentifier = name
            b.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
            view.addSubview(b)
        }
        NotificationCenter.default.addObserver(forName: UIPasteboard.changedNotification, object: nil, queue: .main) { n in
            let added = (n.userInfo?[UIPasteboard.changedTypesAddedUserInfoKey] as? [String]) ?? []
            print("changed: added \(added.sorted())")
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let pb = UIPasteboard.general
        // checks that never ask: has*, types, the item count, the change count
        print("ready: hasStrings \(pb.hasStrings), types \((pb.types(forItemSet: nil) ?? []).flatMap { $0 }), items \(pb.numberOfItems), paste control enabled \(pasteControl.isEnabled)")
    }

    /// a programmatic read: another app's content asks first
    func read() {
        let s = UIPasteboard.general.string
        print("read: \(s ?? "nil")")
    }
    /// what the content looks like, without reading it (no prompt)
    func detect() {
        let pb = UIPasteboard.general
        pb.detectPatterns(for: [.probableWebURL, .probableWebSearch, .number, .link, .emailAddress]) { result in
            let names = ((try? result.get()) ?? []).map { $0.rawValue.components(separatedBy: ".").last ?? "" }.sorted()
            print("patterns: \(names.joined(separator: ","))")
        }
        pb.detectValues(for: [.probableWebURL, .number]) { result in
            let values = ((try? result.get()) ?? [:]).map { "\($0.key.rawValue.components(separatedBy: ".").last ?? "")=\($0.value)" }.sorted()
            print("values: \(values.joined(separator: ","))")
        }
    }
    /// this app's own content: item providers, setObjects, item sets, data, expiration (never asks)
    func extras() {
        let pb = UIPasteboard.general
        pb.setObjects(["first" as NSString, "second" as NSString])
        print("objects: \(pb.numberOfItems) items, strings \(pb.strings ?? []), providers \(pb.itemProviders.map { $0.registeredTypeIdentifiers.first ?? "" })")
        pb.setItems([["public.utf8-plain-text": "a"], ["public.png": UIImage(systemName: "star")!.pngData()!], ["com.example.custom": Data([1, 2, 3])]], options: [:])
        let set = pb.itemSet(withPasteboardTypes: ["com.example.custom"]).map { Array($0) } ?? []
        print("item sets: types \(pb.types(forItemSet: nil)?.map { $0.first ?? "" } ?? []), custom at \(set), data \(pb.data(forPasteboardType: "com.example.custom", inItemSet: IndexSet(integer: 2))?.first?.count ?? -1) bytes, image \(pb.hasImages)")
        pb.setItems([["public.utf8-plain-text": "soon gone"]], options: [.expirationDate: Date().addingTimeInterval(1), .localOnly: true])
        print("expiring: \(pb.string ?? "nil")")
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            print("after expiry: hasStrings \(UIPasteboard.general.hasStrings), string \(UIPasteboard.general.string ?? "nil")")
        }
    }

    // the paste control's target: it accepts strings
    override func paste(itemProviders: [NSItemProvider]) {
        for p in itemProviders where p.canLoadObject(ofClass: NSString.self) {
            _ = p.loadObject(ofClass: NSString.self) { s, _ in
                let text = (s as? NSString).map { $0 as String } ?? "nil"
                DispatchQueue.main.async { print("paste control: \(text)") }
            }
        }
    }
}
