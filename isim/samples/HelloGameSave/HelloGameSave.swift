// HelloGameSave: a game's progress synced between devices with GameSave (issue #393). The app opens its synced
// directory (the default iCloud container) and keeps progress.json there: "Level Up" writes it, "Upload" triggers the
// pending upload, "Close" and "Reopen" close the directory and open it again (syncing). When this device and another
// both changed the save, the directory is conflicted: the app shows both versions and keeps the one tapped. The
// `gamesave offline|online` script command takes the device off the network. Each step logs a "HelloGameSave:" line.
import UIKit
import Observation
import GameSave

private func log(_ s: String) { NSLog("HelloGameSave: %@", s) }

struct Progress: Codable { var level: Int }

private func describe(_ s: GameSaveSyncedDirectory.State) -> String {
    switch s {
    case .ready: return "ready"
    case .offline: return "offline"
    case .local: return "local"
    case .syncing: return "syncing"
    case .conflicted(let versions): return "conflicted \(versions.count)"
    case .error(let e): return "error \(e)"
    case .closed: return "closed"
    @unknown default: return "unknown"
    }
}

final class ViewController: UIViewController {
    var directory: GameSaveSyncedDirectory?
    var url: URL?
    var versions: [GameSaveSyncedDirectory.Version] = []
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 16, y: 80, width: view.bounds.width - 32, height: 60)
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        view.addSubview(label)
        let buttons: [(String, String, Selector)] = [
            ("Level Up", "levelup", #selector(levelUp)), ("Upload", "upload", #selector(upload)), ("Finish Syncing", "finish", #selector(finish)),
            ("Keep This Device's", "keep-local", #selector(keepLocal)), ("Keep iCloud's", "keep-icloud", #selector(keepCloud)),
            ("Close", "close", #selector(closeDirectory)), ("Reopen", "reopen", #selector(reopen)),
        ]
        let stack = UIStackView(arrangedSubviews: buttons.map { title, id, sel in
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 20)
            b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            return b
        })
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.frame = CGRect(x: 16, y: 160, width: view.bounds.width - 32, height: CGFloat(buttons.count) * 52)
        view.addSubview(stack)
        open()
    }

    func open() {
        let d = GameSaveSyncedDirectory.openDirectory(containerIdentifier: nil)
        directory = d
        observe(d)
    }

    /// follows the directory's state (Observation)
    func observe(_ d: GameSaveSyncedDirectory) {
        let state = withObservationTracking { d.state } onChange: {
            DispatchQueue.main.async { [weak self] in if let self, let d = self.directory { self.observe(d) } }
        }
        handle(state)
    }

    func handle(_ state: GameSaveSyncedDirectory.State) {
        log("state \(describe(state))")
        switch state {
        case .ready(let u), .offline(let u), .local(let u):
            url = u
            show("Level \(level(in: u))")
        case .conflicted(let vs):
            versions = vs
            for v in vs {
                log("version \(v.isLocal ? "local" : "iCloud") level \(level(in: v.url)) from \(v.localizedNameOfSavingComputer) dated \(v.modifiedDate.timeIntervalSince1970 > 0)")
            }
            show("Conflict: keep which?")
        case .closed:
            url = nil
            show("Closed")
        default:
            break
        }
    }

    func level(in dir: URL) -> Int {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent("progress.json")), let p = try? JSONDecoder().decode(Progress.self, from: d) else { return 0 }
        return p.level
    }
    func show(_ s: String) {
        label.text = s
        if s.hasPrefix("Level") { log(s.lowercased()) }
    }

    @objc func levelUp() {
        guard let u = url else { log("not open"); return }
        let p = Progress(level: level(in: u) + 1)
        try? JSONEncoder().encode(p).write(to: u.appendingPathComponent("progress.json"), options: .atomic)
        show("Level \(p.level)")
    }
    @objc func upload() {
        guard let d = directory else { return }
        Task { @MainActor in log("upload \(await d.triggerPendingUpload())") }
    }
    @objc func finish() {
        guard let d = directory, let w = view.window else { return }
        Task { @MainActor in await d.finishSyncing(statusDisplay: w); log("finished syncing") }
    }
    @objc func keepLocal() { if let v = versions.first(where: { $0.isLocal }) { directory?.resolveConflicts(with: v) } }
    @objc func keepCloud() { if let v = versions.first(where: { !$0.isLocal }) { directory?.resolveConflicts(with: v) } }
    @objc func closeDirectory() { directory?.close() }
    @objc func reopen() { directory?.close(); open() }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
