// Sample: iOS 26 typed notification messages, each logged with "msg" so the test can check it.
// - UIKit messages: app active, window key, keyboard will show (frame, duration), text field change / end editing (reason),
//   table selection, Bold Text, the user's screenshot (script `takescreenshot`)
// - an app's own MainActorMessage (posted to Swift observers and to an old-style observer of its notification) and an
//   AsyncMessage read as an async sequence; removeObserver(_:) stops an observation
// - Foundation's messages: an undo group (UndoManager), a defaults change (UserDefaults, as an async sequence), a file
//   read in the background (FileHandle), a time zone change posted the old way
// - ProgressManager: a subprogress with properties and their summaries, a reporter assigned a share, an app's own
//   property, and the bridge to Progress both ways
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

/// an app's own progress property: pages rendered, added up over a manager and its children
@available(iOS 26.0, *)
extension ProgressManager.Properties {
    var pagesRendered: PagesRendered.Type { PagesRendered.self }
    enum PagesRendered: ProgressManager.Property {
        static var key: String { "dev.isim.samples.pagesRendered" }
        static var defaultValue: Double { 0 }
        static var defaultSummary: Double { 0 }
        static func reduce(into summary: inout Double, value: Double) { summary += value }
        static func merge(_ a: Double, _ b: Double) -> Double { a + b }
        static func finalSummary(_ parent: Double, _ child: Double) -> Double { parent + child }
    }
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
        foundationMessages(nc)
        progress()
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

    /// Foundation's own messages
    @available(iOS 26.0, *)
    func foundationMessages(_ nc: NotificationCenter) {
        let undo = UndoManager()
        tokens.append(undo)
        tokens.append(nc.addObserver(of: undo, for: .didCloseUndoGroup) { m in log("undo group closed discardable \(m.groupIsDiscardable)") })
        tokens.append(nc.addObserver(of: undo, for: .willUndoChange) { _ in log("undo will undo") })
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        undo.registerUndo(withTarget: cart) { $0.items = 0 }
        undo.endUndoGrouping()
        undo.undo()

        let defaults = UserDefaults.standard
        let changes = nc.messages(of: defaults, for: .didChange)
        Task {
            for await _ in changes { log("defaults changed"); break }
        }
        Task { @MainActor in
            await Task.yield()
            defaults.set(42, forKey: "messagesSample")
        }

        let path = NSTemporaryDirectory() + "messages.txt"
        try? Data("hello file".utf8).write(to: URL(fileURLWithPath: path))
        if let reader = FileHandle(forReadingAtPath: path) {
            tokens.append(reader)
            tokens.append(nc.addObserver(of: reader, for: .readCompletion) { m in
                if case .success(let data) = m.dataItem { log("file read \(String(decoding: data, as: UTF8.self))") }
            })
            reader.readInBackgroundAndNotify()
        }

        tokens.append(nc.addObserver(of: NSTimeZone.self, for: .systemTimeZoneDidChange) { m in
            log("time zone changed from \(m.previousTimeZone?.identifier ?? "nil")")
        })
        nc.post(name: .NSSystemTimeZoneDidChange, object: TimeZone(identifier: "Europe/Lisbon").map { $0 as NSTimeZone })
    }

    /// ProgressManager, ProgressReporter, properties, and the bridge to Progress
    @available(iOS 26.0, *)
    func progress() {
        let manager = ProgressManager(totalCount: 4)
        manager.totalFileCount = 1
        let child = manager.subprogress(assigningCount: 2).start(totalCount: 10)
        child.totalFileCount = 3
        child.completedByteCount = 512
        child.throughput = 100
        child.pagesRendered = 2.5
        child.complete(count: 5)
        let reporter = manager.reporter
        log("progress fraction \(reporter.fractionCompleted) files \(reporter.summary(of: \.totalFileCount)) bytes \(manager.summary(of: \.completedByteCount)) throughput \(manager.summary(of: \.throughput)) pages \(reporter.summary(of: \.pagesRendered))")
        child.complete(count: 5)
        log("progress child finished fraction \(manager.fractionCompleted) files \(manager.summary(of: \.totalFileCount)) throughput \(manager.summary(of: \.throughput)) completed \(manager.completedCount)")

        let other = ProgressManager(totalCount: 2)
        manager.assign(count: 1, to: other.reporter)
        other.complete(count: 1)
        log("progress reporter share fraction \(manager.fractionCompleted) child total \(other.reporter.totalCount ?? -1)")

        let legacy = Progress(totalUnitCount: 4)
        manager.assign(count: 1, to: legacy)
        legacy.completedUnitCount = 4
        log("progress legacy child fraction \(manager.fractionCompleted) finished \(manager.isFinished)")
        other.complete(count: 1)
        log("progress done fraction \(manager.fractionCompleted) finished \(manager.isFinished) reporter \(reporter.isFinished)")

        let parent = Progress(totalUnitCount: 10)
        let bridged = parent.subprogress(assigningCount: 4).start(totalCount: 2)
        bridged.complete(count: 1)
        log("progress bridged parent \(parent.fractionCompleted)")
        bridged.complete(count: 1)
        log("progress bridged parent finished share \(parent.fractionCompleted)")
    }
}
