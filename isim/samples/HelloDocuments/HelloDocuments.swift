// Sample: document pickers on isim — UIDocumentPickerViewController opening files (a copy into the Inbox, or in
// place with multiple selection), picking a folder, exporting (copy and move) and the legacy import mode, and a
// UIDocumentBrowserViewController with document creation. The app shares its Documents (UIFileSharingEnabled +
// LSSupportsOpeningDocumentsInPlace), so they appear as "Documents Demo" in On My iPhone.
import UIKit
import UniformTypeIdentifiers

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        seedDocuments()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = DocumentsViewController()
        window?.makeKeyAndVisible()
        return true
    }
    /// a few files in the app's Documents (written once)
    func seedDocuments() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let notes = docs.appendingPathComponent("Notes.txt")
        guard !FileManager.default.fileExists(atPath: notes.path) else { return }
        try? "Shopping: milk, bread".write(to: notes, atomically: true, encoding: .utf8)
        try? Data("{\"answer\": 42}".utf8).write(to: docs.appendingPathComponent("Data.json"))
        try? FileManager.default.createDirectory(at: docs.appendingPathComponent("Reports"), withIntermediateDirectories: true)
        try? "Q3: up".write(to: docs.appendingPathComponent("Reports/Q3.txt"), atomically: true, encoding: .utf8)
        let png = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { c in UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        try? png.write(to: docs.appendingPathComponent("Swatch.png"))
    }
}

final class DocumentsViewController: UIViewController, UIDocumentPickerDelegate {
    let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 6; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let actions: [(String, String, () -> Void)] = [
            ("Open text (copy)", "open-text", { [unowned self] in pick(UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: true)) }),
            ("Open images + text", "open-multi", { [unowned self] in
                let p = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .plainText])
                p.allowsMultipleSelection = true; p.shouldShowFileExtensions = true
                pick(p)
            }),
            ("Pick a folder", "open-folder", { [unowned self] in pick(UIDocumentPickerViewController(forOpeningContentTypes: [.folder])) }),
            ("Export a copy", "export-copy", { [unowned self] in pick(UIDocumentPickerViewController(forExporting: [makeFile("Export.txt")], asCopy: true)) }),
            ("Move a file", "export-move", { [unowned self] in pick(UIDocumentPickerViewController(forExporting: [makeFile("Moved.txt")], asCopy: false)) }),
            ("Import JSON (legacy)", "import-json", { [unowned self] in _ = perform(NSSelectorFromString("legacyImport")) }),   // (deprecated API, on purpose)
            ("Open in Reports", "open-reports", { [unowned self] in
                let p = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText])
                p.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Reports")
                pick(p)
            }),
            ("Document browser", "browser", { [unowned self] in
                let b = BrowserViewController(forOpening: [.plainText])
                b.modalPresentationStyle = .fullScreen
                present(b, animated: true)
            }),
        ]
        for (title, id, run) in actions {
            let b = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in run() })
            b.accessibilityIdentifier = id
            stack.addArrangedSubview(b)
        }
        status.numberOfLines = 0; status.accessibilityIdentifier = "status"
        stack.addArrangedSubview(status)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
    /// the pre-iOS 14 initializer with type identifiers and the Import mode
    @available(iOS, deprecated: 14.0) @objc func legacyImport() { pick(UIDocumentPickerViewController(documentTypes: ["public.json"], in: .import)) }
    func makeFile(_ name: String) -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? "made by the sample".write(to: u, atomically: true, encoding: .utf8)
        return u
    }
    func pick(_ p: UIDocumentPickerViewController) {
        p.delegate = self
        present(p, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        for u in urls {
            let place = u.path.contains("-Inbox/") ? "inbox" : u.path.hasPrefix(docs) ? "documents" : u.path.contains("/Files/") ? "on-my-iphone" : "elsewhere"
            var isDir: ObjCBool = false
            _ = FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir)
            let text = isDir.boolValue ? "(folder)" : (try? String(contentsOf: u, encoding: .utf8)).map { "\"\($0)\"" } ?? "(\((try? Data(contentsOf: u))?.count ?? 0) bytes)"
            print("picked \(u.lastPathComponent) in \(place) mode=\(controller.documentPickerMode.rawValue) \(text)")
        }
        status.text = urls.map(\.lastPathComponent).joined(separator: ", ")
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { print("picker cancelled") }
}

final class BrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        allowsDocumentCreation = true
        let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(close))
        done.accessibilityIdentifier = "browser-done"
        additionalTrailingNavigationBarButtonItems = [done]
    }
    @objc func close() { dismiss(animated: true) }
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        let template = FileManager.default.temporaryDirectory.appendingPathComponent("Untitled.txt")
        try? "new document".write(to: template, atomically: true, encoding: .utf8)
        importHandler(template, .move)
    }
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        print("browser created \(destinationURL.lastPathComponent) template gone=\(!FileManager.default.fileExists(atPath: sourceURL.path))")
    }
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        print("browser opened \(documentURLs.map(\.lastPathComponent)) \(documentURLs.first.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")")
    }
}
