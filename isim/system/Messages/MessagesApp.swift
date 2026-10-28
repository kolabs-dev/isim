// isim Messages (adapted): the host of the installed apps' iMessage apps and sticker packs. One conversation, with a
// simulated participant (Ana Lima): the transcript, the compose field and the + menu that lists the iMessage apps
// (Messages extensions, loaded into this process like iOS's Messages runs them) and the sticker packs. An app runs in
// the compact area under the compose field or expanded; what it inserts waits in the compose field until Send, what
// it sends goes at once; tapping a message bubble opens its app expanded with the message selected. Messages of one
// session replace the session's earlier bubbles (those show as their summary). The transcript is kept in the device
// data (Library/isim/Messages/conversation.json); `isim messages receive` puts a message from Ana into the inbox
// (inbox.json), which this app reads: an app's message of the active app reaches it as didReceive.
// iMessage itself (other people, SMS, the network) is not in isim.
import UIKit
import Messages
import ImageIO

func log(_ s: String) { NSLog("isim Messages: %@", s) }
func dataDir() -> String {
    if let d = getenv("ISIM_DATA"), d[0] != 0 { return String(cString: d) }
    return (String(cString: getenv("HOME")) as NSString).appendingPathComponent(".local/share/isim")
}
let storeDir: String = {
    let d = (dataDir() as NSString).appendingPathComponent("Library/isim/Messages")
    try? FileManager.default.createDirectory(atPath: (d as NSString).appendingPathComponent("Attachments"), withIntermediateDirectories: true)
    return d
}()
func storePath(_ name: String) -> String { (storeDir as NSString).appendingPathComponent(name) }

// MARK: - the conversation as the device keeps it

struct Entry: Codable {
    var id = UUID().uuidString
    var mine = true
    var kind = "text"                 /* text, sticker, attachment, message */
    var text: String?                 /* text; a sticker's description; an attachment's name */
    var file: String?                 /* a sticker's or attachment's copy; a message's layout image */
    var app: String?                  /* the iMessage app (its extension's bundle id) */
    var url: String?, session: String?, summary: String?, accessibility: String?
    var caption: String?, subcaption: String?, trailingCaption: String?, trailingSubcaption: String?
    var imageTitle: String?, imageSubtitle: String?, media: String?
    var live = false
    var date = Date().timeIntervalSince1970
}
struct Store: Codable {
    var local = UUID().uuidString, remote = UUID().uuidString
    var entries: [Entry] = []
}

// MARK: - the installed iMessage apps

struct MessagesApp {
    let bundle: String, name: String, path: String, icon: UIImage?
    let executable: String?, principal: String?, storyboard: String?
    let stickers: [(file: String, label: String)]          /* a sticker pack */
    var isStickerPack: Bool { executable == nil }
}
func appIcon(_ app: String, _ info: [String: Any]) -> UIImage? {
    for f in ((try? FileManager.default.contentsOfDirectory(atPath: app)) ?? []).sorted() where f.hasPrefix("AppIcon") && f.hasSuffix(".png") {
        if let i = UIImage(contentsOfFile: (app as NSString).appendingPathComponent(f)) { return i }
    }
    return UIImage(contentsOfFile: (app as NSString).appendingPathComponent("icon.png"))
}
func discoverApps() -> [MessagesApp] {
    let dir = getenv("ISIM_APPS").map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 } ?? (dataDir() as NSString).appendingPathComponent("Applications")
    var out: [MessagesApp] = []
    for a in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where a.hasSuffix(".app") {
        let app = (dir as NSString).appendingPathComponent(a)
        let appInfo = NSDictionary(contentsOfFile: (app as NSString).appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
        let appName = appInfo["CFBundleDisplayName"] as? String ?? appInfo["CFBundleName"] as? String ?? (a as NSString).deletingPathExtension
        let plugins = (app as NSString).appendingPathComponent("PlugIns")
        for x in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where x.hasSuffix(".appex") {
            let p = (plugins as NSString).appendingPathComponent(x)
            guard let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                  let ext = info["NSExtension"] as? [String: Any], ext["NSExtensionPointIdentifier"] as? String == "com.apple.message-payload-provider" else { continue }
            let bundle = info["CFBundleIdentifier"] as? String ?? (x as NSString).deletingPathExtension
            var stickers: [(String, String)] = [], icon = appIcon(app, appInfo)
            if let d = FileManager.default.contents(atPath: (p as NSString).appendingPathComponent("isim-stickers.json")),
               let index = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                for pack in index["packs"] as? [[String: Any]] ?? [] {
                    for s in pack["stickers"] as? [[String: Any]] ?? [] {
                        if let f = s["file"] as? String { stickers.append(((p as NSString).appendingPathComponent(f), s["accessibilityLabel"] as? String ?? s["name"] as? String ?? "Sticker")) }
                    }
                }
                if let i = index["icon"] as? String, let img = UIImage(contentsOfFile: (p as NSString).appendingPathComponent(i)) { icon = img }
            }
            let exe = (info["CFBundleExecutable"] as? String).map { (p as NSString).appendingPathComponent($0) }
            out.append(MessagesApp(bundle: bundle, name: info["CFBundleDisplayName"] as? String ?? appName, path: p, icon: icon, executable: exe,
                                   principal: ext["NSExtensionPrincipalClass"] as? String, storyboard: ext["NSExtensionMainStoryboard"] as? String,
                                   stickers: stickers))
        }
    }
    return out
}

/// a sticker pack's browser (the stickers of its isim-stickers.json index)
final class PackController: MSStickerBrowserViewController {
    var stickers: [MSSticker] = []
    override func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int { stickers.count }
    override func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker { stickers[index] }
}

/// notes touches in the app's area: iOS lets an iMessage app send only right after the user touched it
final class TouchRecorder: UIGestureRecognizer {
    var last = Date.distantPast
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { last = Date(); state = .failed }
}

// MARK: - the app

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ConversationController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class ConversationController: UIViewController, _IsimMessagesHost, UITextFieldDelegate {
    var store = Store()
    let transcript = UIScrollView()
    let bar = UIView(), plus = UIButton(type: .system), fieldBox = UIView(), field = UITextField(), send = UIButton(type: .system)
    let staged = UIStackView()
    var stagedItems: [(item: _IsimMessagesItem, view: UIView)] = []
    let menu = UIView()
    let area = UIView(), areaHeader = UIView(), areaTitle = UILabel(), expand = UIButton(type: .system), close = UIButton(type: .system)
    let recorder = TouchRecorder()
    var apps: [MessagesApp] = []
    var running: [String: UIViewController] = [:]           /* the apps loaded in this run, by bundle id */
    var active: (app: MessagesApp, vc: UIViewController)?
    var activeConversation: MSConversation?                 /* (a sticker pack has no controller to hold it) */
    var style: MSMessagesAppPresentationStyle = .compact
    var sessions: [String: MSSession] = [:]
    var bubbles: [UIView] = []

    var local: UUID { UUID(uuidString: store.local)! }
    var remote: UUID { UUID(uuidString: store.remote)! }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if let d = FileManager.default.contents(atPath: storePath("conversation.json")), let s = try? JSONDecoder().decode(Store.self, from: d) { store = s }
        save()
        navigationItem.titleView = contactTitle()
        apps = discoverApps()
        log("\(apps.count) iMessage apps: \(apps.map(\.bundle).joined(separator: ", "))")

        transcript.alwaysBounceVertical = true
        transcript.accessibilityIdentifier = "messages-transcript"
        view.addSubview(transcript)

        plus.setImage(UIImage(systemName: "plus"), for: .normal)
        plus.tintColor = .secondaryLabel
        plus.backgroundColor = .secondarySystemFill
        plus.layer.cornerRadius = 17
        plus.accessibilityIdentifier = "messages-plus"
        plus.accessibilityLabel = "Apps"
        plus.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        fieldBox.layer.borderColor = UIColor.separator.cgColor
        fieldBox.layer.borderWidth = 1
        fieldBox.layer.cornerRadius = 18
        staged.axis = .horizontal
        staged.spacing = 6
        fieldBox.addSubview(staged)
        field.placeholder = "iMessage"
        field.font = .systemFont(ofSize: 17)
        field.accessibilityIdentifier = "messages-field"
        field.delegate = self
        field.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        fieldBox.addSubview(field)
        send.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        send.tintColor = .systemBlue
        send.accessibilityIdentifier = "messages-send"
        send.accessibilityLabel = "Send"
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        send.isHidden = true
        fieldBox.addSubview(send)
        [plus, fieldBox].forEach { bar.addSubview($0) }
        bar.backgroundColor = .systemBackground
        view.addSubview(bar)

        area.backgroundColor = .secondarySystemBackground
        area.isHidden = true
        area.addGestureRecognizer(recorder)
        recorder.cancelsTouchesInView = false
        areaHeader.backgroundColor = .secondarySystemBackground
        areaTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        areaTitle.textColor = .secondaryLabel
        expand.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        expand.accessibilityIdentifier = "messages-expand"
        expand.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.accessibilityIdentifier = "messages-close-app"
        close.accessibilityLabel = "Close"
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        [areaTitle, expand, close].forEach { areaHeader.addSubview($0) }
        area.addSubview(areaHeader)
        view.addSubview(area)

        buildMenu()
        reloadTranscript()
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.readInbox() } }
    }

    func contactTitle() -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        let avatar = UILabel(frame: CGRect(x: 44, y: 0, width: 30, height: 30))
        avatar.text = "AL"; avatar.textAlignment = .center; avatar.font = .systemFont(ofSize: 13, weight: .semibold); avatar.textColor = .white
        avatar.backgroundColor = .systemGray; avatar.layer.cornerRadius = 15; avatar.clipsToBounds = true
        let name = UILabel(frame: CGRect(x: 0, y: 30, width: 120, height: 14))
        name.text = "Ana Lima"; name.textAlignment = .center; name.font = .systemFont(ofSize: 11)
        v.addSubview(avatar); v.addSubview(name)
        v.accessibilityIdentifier = "messages-contact"
        return v
    }

    // MARK: layout
    var areaHeight: CGFloat { style == .expanded ? view.bounds.height - view.safeAreaInsets.top : 300 + view.safeAreaInsets.bottom }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width, safe = view.safeAreaInsets
        let open = active != nil
        let areaH = open ? areaHeight : 0
        area.frame = CGRect(x: 0, y: view.bounds.height - areaH, width: W, height: areaH)
        areaHeader.frame = CGRect(x: 0, y: 0, width: W, height: 40)
        areaTitle.frame = CGRect(x: 16, y: 0, width: W - 120, height: 40)
        expand.frame = CGRect(x: W - 88, y: 0, width: 36, height: 40)
        close.frame = CGRect(x: W - 48, y: 0, width: 36, height: 40)
        if let vc = active?.vc { vc.view.frame = CGRect(x: 0, y: 40, width: W, height: areaH - 40 - (style == .expanded ? safe.bottom : 0)) }
        let stagedH: CGFloat = stagedItems.isEmpty ? 0 : 76
        let barH = 36 + stagedH + 12
        let barBottom = open ? area.frame.minY : view.bounds.height - safe.bottom
        bar.frame = CGRect(x: 0, y: barBottom - barH, width: W, height: barH)
        plus.frame = CGRect(x: 10, y: barH - 6 - 34, width: 34, height: 34)
        fieldBox.frame = CGRect(x: 52, y: 6, width: W - 62, height: barH - 12)
        staged.frame = CGRect(x: 8, y: 6, width: fieldBox.bounds.width - 16, height: stagedH > 0 ? 64 : 0)
        field.frame = CGRect(x: 12, y: fieldBox.bounds.height - 36, width: fieldBox.bounds.width - 52, height: 36)
        send.frame = CGRect(x: fieldBox.bounds.width - 36, y: fieldBox.bounds.height - 34, width: 32, height: 32)
        transcript.frame = CGRect(x: 0, y: 0, width: W, height: bar.frame.minY)
        menu.frame = CGRect(x: 12, y: bar.frame.minY - CGFloat(menuRows) * 52 - 16, width: min(W - 24, 300), height: CGFloat(menuRows) * 52 + 8)
        layoutTranscript()
    }

    // MARK: the + menu
    var menuRows: Int { max(1, apps.count) }
    func buildMenu() {
        menu.backgroundColor = .secondarySystemBackground
        menu.layer.cornerRadius = 22
        menu.layer.shadowOpacity = 0.15
        menu.layer.shadowRadius = 12
        menu.isHidden = true
        for (i, a) in apps.enumerated() {
            let row = UIButton(type: .system)
            row.frame = CGRect(x: 4, y: 4 + CGFloat(i) * 52, width: 292, height: 52)
            row.setTitle("   " + a.name, for: .normal)
            row.setTitleColor(.label, for: .normal)
            row.contentHorizontalAlignment = .left
            row.titleLabel?.font = .systemFont(ofSize: 17)
            if let icon = a.icon { row.setImage(icon.withRenderingMode(.alwaysOriginal).resized(32), for: .normal) }
            row.accessibilityIdentifier = "messages-app-\(a.bundle)"
            row.addAction(UIAction { [weak self] _ in self?.open(a, style: .compact, selected: nil) }, for: .primaryActionTriggered)
            menu.addSubview(row)
        }
        if apps.isEmpty {
            let l = UILabel(frame: CGRect(x: 16, y: 4, width: 268, height: 52))
            l.text = "No iMessage apps"; l.textColor = .secondaryLabel
            menu.addSubview(l)
        }
        view.addSubview(menu)
    }
    @objc func toggleMenu() {
        menu.isHidden.toggle()
        view.bringSubviewToFront(menu)
        log(menu.isHidden ? "closed the app menu" : "opened the app menu")
    }

    // MARK: running an app
    func controller(for a: MessagesApp) -> UIViewController? {
        if let vc = running[a.bundle] { return vc }
        let vc: UIViewController
        if a.isStickerPack {
            let p = PackController(stickerSize: .regular)
            p.stickers = a.stickers.compactMap { try? MSSticker(contentsOfFileURL: URL(fileURLWithPath: $0.file), localizedDescription: $0.label) }
            vc = p
        } else {
            guard let exe = a.executable, dlopen(exe, RTLD_NOW) != nil else {
                log("cannot load \(a.bundle): \(String(cString: dlerror()))"); return nil
            }
            if let reg = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_bundle_register_extension") {
                unsafeBitCast(reg, to: (@convention(c) (NSString) -> Void).self)(a.path as NSString)
            }
            if let name = a.principal, let cls = NSClassFromString(name) as? UIViewController.Type {
                vc = cls.init(nibName: nil, bundle: Bundle(path: a.path))
            } else if let sb = a.storyboard, let v = UIStoryboard(name: sb, bundle: Bundle(path: a.path)).instantiateInitialViewController() {
                vc = v
            } else {
                log("\(a.bundle): no view controller (NSExtensionPrincipalClass \(a.principal ?? "-"))"); return nil
            }
        }
        (vc as? MSMessagesAppViewController)?._isimHost = self
        running[a.bundle] = vc
        return vc
    }
    func conversation(selected: MSMessage?) -> MSConversation { MSConversation(_isimHost: self, local: local, remote: [remote], selected: selected) }

    func open(_ a: MessagesApp, style newStyle: MSMessagesAppPresentationStyle, selected: MSMessage?) {
        menu.isHidden = true
        field.resignFirstResponder()
        if let cur = active, cur.app.bundle == a.bundle {          /* already active: select / restyle */
            if let m = selected, let ms = cur.vc as? MSMessagesAppViewController, let c = ms.activeConversation {
                c.selected = m
                ms.willSelect(m, conversation: c); ms.didSelect(m, conversation: c)
                log("selected a message of \(a.bundle)")
            }
            setStyle(newStyle)
            return
        }
        if active != nil { closeActive() }
        guard let vc = controller(for: a) else { return }
        style = newStyle
        let c = conversation(selected: selected)
        let ms = vc as? MSMessagesAppViewController
        ms?._isimSet(conversation: c); ms?._isimSet(style: newStyle)
        if let ms { ms.willBecomeActive(with: c) }
        addChild(vc)
        area.addSubview(vc.view)
        vc.didMove(toParent: self)
        active = (a, vc)
        activeConversation = c
        _MSActive.conversation = c
        areaTitle.text = a.name.uppercased()
        area.isHidden = false
        view.setNeedsLayout(); view.layoutIfNeeded()
        ms?.didBecomeActive(with: c)
        updateHeader()
        log("opened \(a.bundle) (\(newStyle == .expanded ? "expanded" : "compact"))")
    }
    func setStyle(_ s: MSMessagesAppPresentationStyle) {
        guard let cur = active, s != style else { return }
        let ms = cur.vc as? MSMessagesAppViewController
        ms?.willTransition(to: s)
        style = s
        ms?._isimSet(style: s)
        if s == .expanded { view.bringSubviewToFront(area) }
        UIView.animate(withDuration: 0.25) { self.view.setNeedsLayout(); self.view.layoutIfNeeded() }
        ms?.didTransition(to: s)
        updateHeader()
        log("\(cur.app.bundle) is \(s == .expanded ? "expanded" : "compact")")
    }
    func updateHeader() {
        expand.setImage(UIImage(systemName: style == .expanded ? "chevron.down" : "chevron.up"), for: .normal)
        expand.accessibilityIdentifier = style == .expanded ? "messages-collapse" : "messages-expand"
    }
    func closeActive() {
        guard let cur = active else { return }
        let ms = cur.vc as? MSMessagesAppViewController
        if let ms, let c = ms.activeConversation { ms.willResignActive(with: c) }
        cur.vc.willMove(toParent: nil)
        cur.vc.view.removeFromSuperview()
        cur.vc.removeFromParent()
        active = nil
        area.isHidden = true
        if let ms, let c = ms.activeConversation { ms.didResignActive(with: c); ms._isimSet(conversation: nil) }
        _MSActive.conversation = nil
        activeConversation = nil
        style = .compact
        view.setNeedsLayout()
        log("closed \(cur.app.bundle)")
    }
    @objc func expandTapped() { setStyle(style == .expanded ? .compact : .expanded) }
    @objc func closeTapped() { closeActive() }

    // MARK: _IsimMessagesHost
    func _isimPut(_ item: _IsimMessagesItem, stage: Bool, from conversation: MSConversation) -> (any Error)? {
        if !Thread.isMainThread { return DispatchQueue.main.sync { _isimPut(item, stage: stage, from: conversation) } }
        let app = (conversation._isimController.flatMap { c in running.first { $0.value === c }?.key }) ?? active?.app.bundle
        if stage {
            stageItem(item, app: app)
            return nil
        }
        guard let cur = active, cur.vc === conversation._isimController || conversation._isimController == nil else {
            log("send refused: the app is not visible")
            return NSError(domain: MSMessagesErrorDomain, code: MSMessageErrorCode.sendWhileNotVisible.rawValue)
        }
        guard Date().timeIntervalSince(recorder.last) < 5 else {
            log("send refused: no recent interaction with the app")
            return NSError(domain: MSMessagesErrorDomain, code: MSMessageErrorCode.sendWithoutRecentInteraction.rawValue)
        }
        deliver(item, app: app)
        return nil
    }
    func _isimRequestStyle(_ style: MSMessagesAppPresentationStyle, for controller: MSMessagesAppViewController) {
        guard active?.vc === controller else { return }
        setStyle(style)
    }
    func _isimDismiss(_ controller: MSMessagesAppViewController) { if active?.vc === controller { closeActive() } }
    func _isimTintChanged(_ controller: MSMessagesAppViewController) { reloadTranscript() }

    // MARK: composing
    func stageItem(_ item: _IsimMessagesItem, app: String?) {
        if case .text(let t) = item {                         /* text goes into the field */
            field.text = (field.text ?? "") + t
            fieldChanged()
            log("inserted text")
            return
        }
        let chip = UIView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        chip.backgroundColor = .tertiarySystemFill
        chip.layer.cornerRadius = 10
        chip.clipsToBounds = true
        chip.widthAnchor.constraint(equalToConstant: 64).isActive = true
        let image = UIImageView(frame: chip.bounds.insetBy(dx: 4, dy: 4))
        image.contentMode = .scaleAspectFit
        let label = UILabel(frame: chip.bounds.insetBy(dx: 4, dy: 4))
        label.font = .systemFont(ofSize: 10); label.numberOfLines = 3; label.textAlignment = .center
        switch item {
        case .sticker(let s): image.image = UIImage(contentsOfFile: s.imageFileURL.path); chip.accessibilityLabel = s.localizedDescription
        case .attachment(let u, let name): image.image = UIImage(contentsOfFile: u.path); label.text = image.image == nil ? (name ?? u.lastPathComponent) : nil
        case .message(let m):
            m._isimApp = app
            let t = m.layout as? MSMessageTemplateLayout ?? (m.layout as? MSMessageLiveLayout)?.alternateLayout
            image.image = t?.image; label.text = image.image == nil ? (t?.caption ?? m.summaryText ?? "Message") : nil
        case .text: break
        }
        chip.addSubview(image); chip.addSubview(label)
        let x = UIButton(type: .system)
        x.frame = CGRect(x: 44, y: 0, width: 20, height: 20)
        x.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        x.tintColor = .secondaryLabel
        chip.addSubview(x)
        stagedItems.append((item, chip))
        staged.addArrangedSubview(chip)
        renumberStaged()
        x.addAction(UIAction { [weak self, weak chip] _ in if let chip { self?.unstage(chip) } }, for: .primaryActionTriggered)
        fieldChanged()
        view.setNeedsLayout()
        log("inserted \(describe(item)) into the compose field")
    }
    func renumberStaged() {
        for (i, s) in stagedItems.enumerated() {
            s.view.accessibilityIdentifier = "messages-staged-\(i)"
            (s.view.subviews.last as? UIButton)?.accessibilityIdentifier = "messages-staged-remove-\(i)"
        }
    }
    func unstage(_ chip: UIView) {
        guard let i = stagedItems.firstIndex(where: { $0.view === chip }) else { return }
        let (item, _) = stagedItems.remove(at: i)
        chip.removeFromSuperview()
        renumberStaged()
        if case .message(let m) = item, let ms = running[m._isimApp ?? ""] as? MSMessagesAppViewController, let c = ms.activeConversation {
            ms.didCancelSending(m, conversation: c)
        }
        log("removed \(describe(item)) from the compose field")
        fieldChanged()
        view.setNeedsLayout()
    }
    @objc func fieldChanged() { send.isHidden = (field.text ?? "").isEmpty && stagedItems.isEmpty }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { sendTapped(); return false }
    @objc func sendTapped() {
        for (item, chip) in stagedItems {
            chip.removeFromSuperview()
            if case .message(let m) = item, let ms = running[m._isimApp ?? ""] as? MSMessagesAppViewController, let c = ms.activeConversation {
                ms.didStartSending(m, conversation: c)
            }
            deliver(item, app: nil)
        }
        stagedItems = []
        if let t = field.text, !t.isEmpty { deliver(.text(t), app: nil); field.text = "" }
        fieldChanged()
        view.setNeedsLayout()
    }
    func describe(_ item: _IsimMessagesItem) -> String {
        switch item {
        case .text: return "text"
        case .sticker(let s): return "the sticker \(s.localizedDescription)"
        case .attachment(let u, _): return "the attachment \(u.lastPathComponent)"
        case .message(let m): return "a message (\((m.layout as? MSMessageTemplateLayout)?.caption ?? m.summaryText ?? "-"))"
        }
    }
    func copyIn(_ path: String) -> String {
        let dst = storePath("Attachments/\(UUID().uuidString)-\((path as NSString).lastPathComponent)")
        try? FileManager.default.copyItem(atPath: path, toPath: dst)
        return dst
    }
    /// the message is sent: into the transcript and the device data
    func deliver(_ item: _IsimMessagesItem, app: String?) {
        var e = Entry()
        switch item {
        case .text(let t): e.kind = "text"; e.text = t
        case .sticker(let s): e.kind = "sticker"; e.text = s.localizedDescription; e.file = copyIn(s.imageFileURL.path)
        case .attachment(let u, let name): e.kind = "attachment"; e.text = name ?? u.lastPathComponent; e.file = copyIn(u.path)
        case .message(let m):
            e.kind = "message"; e.app = m._isimApp ?? app
            e.url = m.url?.absoluteString; e.summary = m.summaryText; e.accessibility = m.accessibilityLabel
            e.session = m.session?._isimID.uuidString
            if let s = m.session { sessions[s._isimID.uuidString] = s }
            e.live = m.layout is MSMessageLiveLayout
            if let t = m.layout as? MSMessageTemplateLayout ?? (m.layout as? MSMessageLiveLayout)?.alternateLayout {
                e.caption = t.caption; e.subcaption = t.subcaption; e.trailingCaption = t.trailingCaption; e.trailingSubcaption = t.trailingSubcaption
                e.imageTitle = t.imageTitle; e.imageSubtitle = t.imageSubtitle
                if let img = t.image, let png = img.pngData() {
                    let p = storePath("Attachments/\(e.id).png")
                    FileManager.default.createFile(atPath: p, contents: png)
                    e.file = p
                }
                if let media = t.mediaFileURL { e.media = copyIn(media.path) }
            }
            m._sender = local; m._pending = false
        }
        store.entries.append(e)
        save()
        reloadTranscript()
        log("sent \(e.kind)\(e.app.map { " from \($0)" } ?? ""): \(summary(e))")
    }
    func summary(_ e: Entry) -> String {
        switch e.kind {
        case "message": return [e.caption, e.subcaption, e.url].compactMap { $0 }.joined(separator: " | ")
        default: return e.text ?? ""
        }
    }
    func save() {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(store) { FileManager.default.createFile(atPath: storePath("conversation.json"), contents: d) }
    }

    // MARK: incoming (isim messages receive)
    func readInbox() {
        let p = storePath("inbox.json")
        guard let d = FileManager.default.contents(atPath: p), let incoming = try? JSONDecoder().decode([Entry].self, from: d), !incoming.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: p)
        for var e in incoming {
            e.mine = false
            store.entries.append(e)
            log("received \(e.kind)\(e.app.map { " from \($0)" } ?? "") from Ana: \(summary(e))")
            if e.kind == "message", let cur = active, cur.app.bundle == e.app, let ms = cur.vc as? MSMessagesAppViewController, let c = ms.activeConversation {
                ms.didReceive(message(e), conversation: c)
            }
        }
        save()
        reloadTranscript()
    }
    /// an entry as the MSMessage the app sees
    func message(_ e: Entry) -> MSMessage {
        let m: MSMessage
        if let s = e.session, let id = UUID(uuidString: s) {
            let session = sessions[s] ?? MSSession(_isimID: id)
            sessions[s] = session
            m = MSMessage(session: session)
        } else { m = MSMessage() }
        let t = MSMessageTemplateLayout()
        t.caption = e.caption; t.subcaption = e.subcaption; t.trailingCaption = e.trailingCaption; t.trailingSubcaption = e.trailingSubcaption
        t.imageTitle = e.imageTitle; t.imageSubtitle = e.imageSubtitle
        t.image = e.file.flatMap { UIImage(contentsOfFile: $0) }
        t.mediaFileURL = e.media.map { URL(fileURLWithPath: $0) }
        m.layout = e.live ? MSMessageLiveLayout(alternateLayout: t) : t
        m.url = e.url.flatMap { URL(string: $0) }
        m.summaryText = e.summary; m.accessibilityLabel = e.accessibility
        m._sender = e.mine ? local : remote; m._pending = false; m._isimApp = e.app
        return m
    }

    // MARK: the transcript
    func reloadTranscript() {
        bubbles.forEach { $0.removeFromSuperview() }
        bubbles = []
        /* a session's latest message is its bubble; the earlier ones show as their summary */
        var latest: [String: Int] = [:]
        for (i, e) in store.entries.enumerated() { if let s = e.session { latest[s] = i } }
        for (i, e) in store.entries.enumerated() {
            let v: UIView
            if let s = e.session, latest[s] != i {
                let l = UILabel()
                l.text = "\(e.mine ? "You" : "Ana"): \(e.summary ?? e.caption ?? "Message")"
                l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabel; l.textAlignment = e.mine ? .right : .left
                v = l
            } else {
                v = bubble(e)
            }
            v.accessibilityIdentifier = "messages-bubble-\(i)"
            v.tag = i
            transcript.addSubview(v)
            bubbles.append(v)
        }
        view.setNeedsLayout()
    }
    func bubble(_ e: Entry) -> UIView {
        let maxW = view.bounds.width * 0.72
        switch e.kind {
        case "sticker":
            let i = UIImageView(image: e.file.flatMap { UIImage(contentsOfFile: $0) })
            i.contentMode = .scaleAspectFit
            i.frame.size = CGSize(width: 120, height: 120)
            i.accessibilityLabel = e.text
            i.isAccessibilityElement = true
            return i
        case "message":
            let card = UIView(frame: CGRect(x: 0, y: 0, width: min(maxW, 250), height: 0))
            card.layer.cornerRadius = 18
            card.clipsToBounds = true
            card.backgroundColor = .secondarySystemFill
            var y: CGFloat = 0
            if let img = (e.file ?? e.media).flatMap({ UIImage(contentsOfFile: $0) }) {
                let iv = UIImageView(image: img)
                iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
                iv.frame = CGRect(x: 0, y: 0, width: card.bounds.width, height: 150)
                card.addSubview(iv)
                for (k, t) in [e.imageTitle, e.imageSubtitle].enumerated() {
                    guard let t else { continue }
                    let l = UILabel(frame: CGRect(x: 10, y: 150 - CGFloat(44 - k * 20), width: card.bounds.width - 20, height: 20))
                    l.text = t; l.textColor = .white; l.font = .systemFont(ofSize: k == 0 ? 15 : 12, weight: k == 0 ? .semibold : .regular)
                    l.layer.shadowOpacity = 0.6; l.layer.shadowRadius = 2; l.layer.shadowOffset = .zero
                    card.addSubview(l)
                }
                y = 150
            }
            for (t, trailing, bold) in [(e.caption, e.trailingCaption, true), (e.subcaption, e.trailingSubcaption, false)] where t != nil || trailing != nil {
                let l = UILabel(frame: CGRect(x: 12, y: y + 6, width: card.bounds.width - 24, height: 20))
                l.text = t; l.font = .systemFont(ofSize: bold ? 15 : 13, weight: bold ? .semibold : .regular); l.textColor = bold ? .label : .secondaryLabel
                card.addSubview(l)
                if let trailing {
                    let r = UILabel(frame: l.frame); r.text = trailing; r.textAlignment = .right; r.font = l.font; r.textColor = .secondaryLabel
                    card.addSubview(r)
                }
                y += 24
            }
            card.frame.size.height = y + (y > 0 ? 8 : 40)
            card.accessibilityLabel = e.accessibility ?? e.caption ?? e.summary
            card.isAccessibilityElement = true
            card.isUserInteractionEnabled = true
            let idx = store.entries.firstIndex { $0.id == e.id } ?? 0
            card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bubbleTapped(_:))))
            card.tag = idx
            return card
        default:
            let l = PaddedLabel()
            l.text = e.kind == "attachment" ? "📎 " + (e.text ?? "") : e.text
            l.numberOfLines = 0
            l.font = .systemFont(ofSize: 17)
            l.textColor = e.mine ? .white : .label
            l.backgroundColor = e.mine ? .systemBlue : .secondarySystemFill
            l.layer.cornerRadius = 18
            l.clipsToBounds = true
            let size = l.sizeThatFits(CGSize(width: maxW, height: .greatestFiniteMagnitude))
            l.frame.size = CGSize(width: min(maxW, size.width), height: size.height)
            return l
        }
    }
    func layoutTranscript() {
        let W = view.bounds.width
        var y: CGFloat = 12
        for v in bubbles {
            let e = store.entries[v.tag]
            if v is UILabel && !(v is PaddedLabel) { v.frame = CGRect(x: 16, y: y, width: W - 32, height: 16) }
            else { v.frame.origin = CGPoint(x: e.mine ? W - 12 - v.frame.width : 12, y: y) }
            y = v.frame.maxY + 8
        }
        transcript.contentSize = CGSize(width: W, height: y)
        let over = y - transcript.bounds.height
        if over > 0 { transcript.contentOffset = CGPoint(x: 0, y: over) }
    }
    @objc func bubbleTapped(_ g: UITapGestureRecognizer) {
        guard let v = g.view, v.tag < store.entries.count else { return }
        let e = store.entries[v.tag]
        guard let bundle = e.app, let a = apps.first(where: { $0.bundle == bundle }) else { log("no iMessage app for this message"); return }
        log("tapped a message of \(bundle)")
        open(a, style: .expanded, selected: message(e))
    }
}

final class PaddedLabel: UILabel {
    let inset = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = super.sizeThatFits(CGSize(width: size.width - inset.left - inset.right, height: size.height))
        return CGSize(width: s.width + inset.left + inset.right, height: s.height + inset.top + inset.bottom)
    }
}

extension UIImage {
    func resized(_ side: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: side * 0.22).addClip()
            draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}
