// Sample: BackgroundAssets (issue #407). The downloader extension (Downloader/) fetches the app's assets at install
// into the app group; the app lists them, downloads one more in the foreground and schedules another with
// BADownloadManager (its delegate moves the files), sees duplicate and essential downloads refused, and takes the
// manager's exclusive control. With -server URL it uses the asset server (server.py). Every step is printed ("ba ...").
import UIKit
import BackgroundAssets

let group = "group.dev.isim.samples.hellobackgroundassets"
func log(_ s: String) { print("ba \(s)"); fflush(stdout) }
var server: String {
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-server"), i + 1 < a.count { return a[i + 1] }
    return "http://localhost:8460"
}
var assets: URL { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)!.appendingPathComponent("Assets") }

final class Downloads: NSObject, BADownloadManagerDelegate {
    func downloadDidBegin(_ download: BADownload) { log("began \(download.identifier)") }
    func download(_ download: BADownload, didWriteBytes bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite totalExpectedBytes: Int64) {
        if totalBytesWritten == totalExpectedBytes { log("wrote \(download.identifier) \(totalBytesWritten)") }
    }
    func download(_ download: BADownload, finishedWithFileURL fileURL: URL) {
        try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        let dst = assets.appendingPathComponent(download.identifier + ".bin")
        try? FileManager.default.removeItem(at: dst)
        let moved = (try? FileManager.default.moveItem(at: fileURL, to: dst)) != nil
        log("finished \(download.identifier) moved=\(moved) size=\((try? Data(contentsOf: dst))?.count ?? 0)")
    }
    func download(_ download: BADownload, failedWithError error: any Error) { log("failed \(download.identifier) \((error as NSError).code)") }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: AssetsViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class AssetsViewController: UIViewController {
    let delegate = Downloads()
    func download(_ id: String) -> BAURLDownload {
        BAURLDownload(identifier: id, request: URLRequest(url: URL(string: "\(server)/files/\(id).bin")!), fileSize: id == "bonus" ? 2048 : 1024,
                      applicationGroupIdentifier: group)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Assets"
        view.backgroundColor = .systemBackground
        BADownloadManager.shared.delegate = delegate
        var y: CGFloat = 120
        for (id, t) in [("files", "List Assets"), ("foreground", "Download Bonus"), ("schedule", "Schedule Extra"),
                        ("essential", "Essential From App"), ("exclusive", "Exclusive Control")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 20, y: y, width: 260, height: 40)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 50
        }
        log("launched")
    }
    func tap(_ id: String) {
        do {
            switch id {
            case "files":
                let names = ((try? FileManager.default.contentsOfDirectory(atPath: assets.path)) ?? []).sorted()
                log("files \(names.joined(separator: ","))")
            case "foreground":
                try BADownloadManager.shared.startForegroundDownload(download("bonus"))
            case "schedule":
                let d = download("extra")
                try BADownloadManager.shared.scheduleDownload(d)
                log("current \(try BADownloadManager.shared.fetchCurrentDownloads().map(\.identifier).joined(separator: ","))")
                do { try BADownloadManager.shared.scheduleDownload(download("extra")) } catch let e as NSError { log("again refused \(e.domain)/\(e.code)") }
            case "essential":
                let d = BAURLDownload(identifier: "boot", request: URLRequest(url: URL(string: "\(server)/files/intro.bin")!), essential: true,
                                      fileSize: 4096, applicationGroupIdentifier: group, priority: .max)
                do { try BADownloadManager.shared.scheduleDownload(d) } catch let e as NSError { log("essential refused \(e.domain)/\(e.code)") }
            case "exclusive":
                Task {
                    let n = try await BADownloadManager.shared.withExclusiveControl { 42 }
                    log("exclusive \(n)")
                }
            default: break
            }
        } catch { log("\(id) failed \(error)") }
    }
}
