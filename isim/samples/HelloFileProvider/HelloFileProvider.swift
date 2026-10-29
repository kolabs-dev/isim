// Sample: FileProvider (issue #408). "Cloud Notes" adds a domain of its replicated file provider extension
// (Extension/), which then shows in the document picker beside On My iPhone: the app opens a file from it (the
// extension fetches its contents), exports a file into it (the extension creates the item on its "server"), changes a
// file on the server and signals the extension (the domain syncs), gets an item's user-visible URL, downloads and
// evicts it, signs out (the picker shows the FileProviderUI extension's sign-in) and removes the domain. Its items'
// menus have the extension's Star action and the FileProviderUI extension's Share (Actions/). Every step is printed
// ("fp ...").
import UIKit
import FileProvider
import UniformTypeIdentifiers

func log(_ s: String) { print("fp \(s)"); fflush(stdout) }
let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("notes"), displayName: "Sample Notes")

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: NotesViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class NotesViewController: UIViewController, UIDocumentPickerDelegate {
    var manager: NSFileProviderManager? { NSFileProviderManager(for: domain) }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cloud Notes"
        view.backgroundColor = .systemBackground
        Server.seed()
        var y: CGFloat = 110
        for (id, t) in [("add", "Add Domain"), ("domains", "List Domains"), ("open", "Open a File"), ("export", "Export a Report"),
                        ("remote", "Change on the Server"), ("visible", "Download News"), ("evict", "Evict News"), ("signout", "Sign Out"),
                        ("remove", "Remove Domain")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 20, y: y, width: 280, height: 40)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 48
        }
        log("launched")
    }

    func tap(_ id: String) {
        switch id {
        case "add":
            NSFileProviderManager.add(domain) { e in log("added \(e.map { ($0 as NSError).code.description } ?? "ok")") }
        case "domains":
            NSFileProviderManager.getDomainsWithCompletionHandler { ds, _ in
                log("domains \(ds.map { "\($0.identifier.rawValue):\($0.displayName)" }.joined(separator: ","))")
            }
        case "open":
            let p = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            p.delegate = self
            present(p, animated: true)
        case "export":
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Report.txt")
            try? Data("written in the app".utf8).write(to: url)
            let p = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            p.delegate = self
            present(p, animated: true)
        case "remote":                                           // the server changes: a new file
            try? Data("news from the server".utf8).write(to: Server.files.appendingPathComponent("News.txt"))
            Server.record(NSFileProviderItemIdentifier("News.txt"))
            manager?.signalEnumerator(for: .workingSet) { e in log("signalled \(e == nil ? "ok" : "\(e!)")") }
        case "visible":
            guard let m = manager else { log("no manager"); return }
            m.getUserVisibleURL(for: NSFileProviderItemIdentifier("News.txt")) { url, e in
                guard let url else { log("visible failed \(String(describing: e))"); return }
                log("visible \(url.lastPathComponent) in \(url.deletingLastPathComponent().lastPathComponent)")
                m.requestDownloadForItem(withIdentifier: NSFileProviderItemIdentifier("News.txt")) { e in
                    log("downloaded \(url.lastPathComponent): \((try? String(contentsOf: url, encoding: .utf8)) ?? "-") \(e == nil ? "" : "\(e!)")")
                }
            }
        case "evict":
            manager?.evictItem(identifier: NSFileProviderItemIdentifier("News.txt")) { e in log("evicted \(e == nil ? "ok" : "\(e!)")") }
        case "signout":                                          // the next sync asks to sign in (the Actions extension)
            FileManager.default.createFile(atPath: Server.signedOutURL.path, contents: nil)
            log("signed out")
        case "remove":
            NSFileProviderManager.remove(domain) { e in log("removed \(e == nil ? "ok" : "\(e!)")") }
        default: break
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "-"
            log("picked \(url.lastPathComponent): \(text)")
        }
        // an export lands on the server too
        if let r = try? String(contentsOf: Server.files.appendingPathComponent("Report.txt"), encoding: .utf8) { log("server has Report.txt: \(r)") }
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { log("cancelled") }
}
