// Sample: managed asset packs (BackgroundAssets, iOS 26, issue #407). The packs are hosted by isim's stand-in for
// Apple's hosting (`isim bgassets pack add`); the managed downloader extension downloads the essential ones at install.
// The app reads a file of a local pack, downloads an on-demand pack with its status updates, checks for updates and
// removes a pack. Every step is printed ("bap ...").
import UIKit
import BackgroundAssets
import System

func log(_ s: String) { print("bap \(s)"); fflush(stdout) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 26.4, *) {
            window?.rootViewController = UINavigationController(rootViewController: PacksViewController())
        } else {
            window?.rootViewController = UIViewController()
            log("needs iOS 26.4")
        }
        window?.makeKeyAndVisible()
        return true
    }
}

@available(iOS 26.4, *)
func describe(_ s: AssetPack.Status) -> String {
    let names: [(AssetPack.Status, String)] = [(.downloadAvailable, "available"), (.downloading, "downloading"), (.downloaded, "downloaded"),
                                               (.upToDate, "upToDate"), (.outOfDate, "outOfDate"), (.obsolete, "obsolete"), (.updateAvailable, "updateAvailable")]
    return names.filter { s.contains($0.0) }.map(\.1).joined(separator: "+")
}

@available(iOS 26.4, *)
final class PacksViewController: UIViewController {
    let manager = AssetPackManager.shared
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Packs"
        view.backgroundColor = .systemBackground
        var y: CGFloat = 120
        for (id, t) in [("status", "Status"), ("read", "Read Level"), ("ensure", "Get Extras"), ("updates", "Check Updates"), ("remove", "Remove Extras")] {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.frame = CGRect(x: 20, y: y, width: 260, height: 40)
            b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in self?.tap(id) }, for: .primaryActionTriggered)
            view.addSubview(b)
            y += 50
        }
        Task {
            for await u in manager.statusUpdates(forAssetPackWithID: "extras") {
                switch u {
                case .began(let p): log("extras began v\(p.version)")
                case .downloading(_, let progress): if progress.completedUnitCount == progress.totalUnitCount { log("extras downloading \(Int(progress.fractionCompleted * 100))%") }
                case .finished(let p): log("extras finished v\(p.version)")
                case .failed(_, let e): log("extras failed \(e)")
                case .paused: log("extras paused")
                @unknown default: break
                }
            }
        }
        log("launched levels=\(manager.assetPackIsAvailableLocally(withID: "levels")) skipped=\(manager.assetPackIsAvailableLocally(withID: "skipped")) extras=\(manager.assetPackIsAvailableLocally(withID: "extras"))")
    }
    func tap(_ id: String) {
        Task {
            do {
                switch id {
                case "status":
                    var parts: [String] = []
                    for p in ["levels", "skipped", "extras"] { parts.append("\(p)=\(describe(await manager.localStatus(ofAssetPackWithID: p)))") }
                    log("status \(parts.joined(separator: " "))")
                case "read":
                    let d = try manager.contents(at: FilePath("levels/1.json"))
                    log("read \(String(decoding: d, as: UTF8.self))")
                    do { _ = try manager.url(for: FilePath("missing.txt")) } catch ManagedBackgroundAssetsError.fileNotFound(let p) { log("missing \(p.string)") }
                case "ensure":
                    let pack = try await manager.assetPack(withID: "extras")
                    try await manager.ensureLocalAvailability(of: pack, requireLatestVersion: true)
                    let fd = try manager.descriptor(for: FilePath("extras/bonus.txt"), searchingInAssetPackWithID: "extras")
                    var buf = [UInt8](repeating: 0, count: 64)
                    let n = try buf.withUnsafeMutableBytes { try fd.read(into: $0) }
                    try fd.close()
                    log("extras local bonus=\(String(decoding: buf.prefix(n), as: UTF8.self))")
                case "updates":
                    let (updating, removed) = try await manager.checkForUpdates()
                    log("updates updating=\(updating.sorted().joined(separator: ",")) removed=\(removed.sorted().joined(separator: ","))")
                case "remove":
                    try await manager.remove(assetPackWithID: "extras")
                    log("removed extras local=\(manager.assetPackIsAvailableLocally(withID: "extras"))")
                default: break
                }
            } catch { log("\(id) failed \(error)") }
        }
    }
}
