// Sample: a document-based app on isim (UIKit) — a UIDocument subclass for plain text (load(fromContents:ofType:),
// contents(forType:), undo through the document's undo manager, autosave), a UIDocumentViewController subclass as the
// root (documentDidOpen, navigationItemDidUpdate, undoRedoItemGroup), and the iOS 18 launch view: launchOptions
// title, iOS 27 subtitle, background, a secondary create action with a custom UIDocument.CreationIntent, and the
// browser's documentBrowser(_:didRequestDocumentCreationWithHandler:) reading activeDocumentCreationIntent. The
// Info.plist names TextDocument as the UIDocumentClass of public.plain-text.
import UIKit

func log(_ s: String) { print("hd \(s)") }

final class TextDocument: UIDocument {
    var text = ""
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else { throw CocoaError(.fileReadCorruptFile) }
        text = String(decoding: data, as: UTF8.self)
        log("loaded \(fileURL.lastPathComponent) type \(typeName ?? "-") \"\(text)\"")
    }
    override func contents(forType typeName: String) throws -> Any {
        log("saving \"\(text)\"")
        return Data(text.utf8)
    }
    /// an edit the undo manager can take back
    func setText(_ new: String) {
        let old = text
        text = new
        undoManager.registerUndo(withTarget: self) { $0.setText(old) }
    }
}

@available(iOS 18, *)
extension UIDocument.CreationIntent {
    static let template = UIDocument.CreationIntent("template")
}

final class EditorViewController: UIDocumentViewController, UITextViewDelegate {
    let textView = UITextView()
    var textDocument: TextDocument? { document as? TextDocument }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        textView.font = .systemFont(ofSize: 20)
        textView.delegate = self
        textView.accessibilityIdentifier = "editor"
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(textView)
        navigationItem.trailingItemGroups = [undoRedoItemGroup]
        if #available(iOS 18, *) {
            launchOptions.title = "Notes"
            if #available(iOS 27, *) { launchOptions.subtitle = "Plain text, saved as you type" }
            launchOptions.background.backgroundColor = .systemIndigo
            let template = LaunchOptions.createDocumentAction(withIntent: .template)
            template.title = "From Template"
            launchOptions.secondaryAction = template
            log("launch title \(launchOptions.title) primary \(launchOptions.primaryAction?.title ?? "-")")
        }
        NotificationCenter.default.addObserver(forName: UIDocument.stateChangedNotification, object: nil, queue: .main) { n in
            guard let d = n.object as? UIDocument else { return }
            log("state \(d.localizedName) closed \(d.documentState.contains(.closed))")
        }
        configure()
    }
    func configure() {
        guard let doc = textDocument, !doc.documentState.contains(.closed), isViewLoaded else { return }
        textView.text = doc.text
    }
    override func documentDidOpen() {
        log("documentDidOpen \(document?.localizedName ?? "-") title \(navigationItem.title ?? "-") class \(type(of: document!))")
        configure()
    }
    override func navigationItemDidUpdate() {
        log("navigationItemDidUpdate title \(navigationItem.title ?? "-")")
    }
    func textViewDidChange(_ tv: UITextView) {
        textDocument?.setText(tv.text)
    }

    // the launch view's create actions
    override func documentBrowser(_ controller: UIDocumentBrowserViewController,
                                  didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        var name = "Untitled", text = "Hello"
        if #available(iOS 18, *), controller.activeDocumentCreationIntent == .template { name = "Shopping"; text = "Milk, bread" }
        if #available(iOS 18, *) { log("create intent \(controller.activeDocumentCreationIntent?.rawValue ?? "-")") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).txt")
        try? Data(text.utf8).write(to: url)
        importHandler(url, .move)
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: EditorViewController())
        window?.makeKeyAndVisible()
        return true
    }
}
