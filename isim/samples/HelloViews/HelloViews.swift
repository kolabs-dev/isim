// Sample: UIKit views and controls on isim — context menus (UIContextMenuInteraction with a snapshot or a preview
// controller, table view row menus), button configurations (configurationUpdateHandler, attributed titles, activity
// indicator, image placement), tintAdjustmentMode (dimmed behind an alert), contentMode by pixels and custom input
// views (inputView / inputAccessoryView).
import UIKit

func log(_ s: String) { print("HelloViews: \(s)") }
func hex(_ c: UIColor?) -> String {
    guard let c else { return "nil" }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
}
func solid(_ c: UIColor, _ w: CGFloat, _ h: CGFloat) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in c.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h)) }
}

final class TintProbe: UIView {
    override func tintColorDidChange() { super.tintColorDidChange(); log("tint \(tintAdjustmentMode == .dimmed ? "dimmed" : "normal") \(hex(tintColor))") }
}
final class PreviewController: UIViewController {
    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .systemPurple; preferredContentSize = CGSize(width: 200, height: 150) }
}

final class ViewsController: UIViewController, UIContextMenuInteractionDelegate, UITableViewDataSource, UITableViewDelegate {
    let card = UIView(), photo = UIView(), probe = TintProbe()
    let table = UITableView(frame: .zero, style: .plain)
    let header = UIView()
    var statusStep = 0
    override var preferredStatusBarStyle: UIStatusBarStyle { statusStep >= 1 ? .lightContent : .default }
    override var prefersStatusBarHidden: Bool { statusStep >= 2 }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // context menus: a card (snapshot preview) and a photo (preview controller)
        card.frame = CGRect(x: 20, y: 70, width: 160, height: 60); card.backgroundColor = .systemTeal; card.layer.cornerRadius = 12
        card.accessibilityIdentifier = "card"; card.addInteraction(UIContextMenuInteraction(delegate: self))
        photo.frame = CGRect(x: 200, y: 70, width: 160, height: 60); photo.backgroundColor = .systemOrange
        photo.accessibilityIdentifier = "photo"; photo.addInteraction(UIContextMenuInteraction(delegate: self))
        // buttons with configurations
        var toggle = UIButton.Configuration.filled(); toggle.title = "Off"
        let toggleButton = UIButton(configuration: toggle)
        toggleButton.changesSelectionAsPrimaryAction = true
        toggleButton.configurationUpdateHandler = { b in
            var c = b.configuration; c?.title = b.isSelected ? "On" : "Off"; b.configuration = c
            log("update handler: selected \(b.isSelected)")
        }
        toggleButton.frame = CGRect(x: 20, y: 150, width: 100, height: 40); toggleButton.accessibilityIdentifier = "toggle"
        var busy = UIButton.Configuration.gray(); busy.title = "Saving"; busy.showsActivityIndicator = true; busy.imagePadding = 8
        let busyButton = UIButton(configuration: busy); busyButton.frame = CGRect(x: 130, y: 150, width: 130, height: 40); busyButton.accessibilityIdentifier = "busy"
        var fancy = UIButton.Configuration.plain()
        var title = AttributedString("Fancy"); title.foregroundColor = .systemRed; title.font = .boldSystemFont(ofSize: 22)
        fancy.attributedTitle = title
        let fancyButton = UIButton(configuration: fancy); fancyButton.frame = CGRect(x: 270, y: 150, width: 110, height: 40); fancyButton.accessibilityIdentifier = "fancy"
        var stacked = UIButton.Configuration.tinted(); stacked.title = "Top"; stacked.image = UIImage(systemName: "star.fill"); stacked.imagePlacement = .top; stacked.imagePadding = 4
        let stackedButton = UIButton(configuration: stacked); stackedButton.accessibilityIdentifier = "stacked"
        let ss = stackedButton.intrinsicContentSize, plainSize = UIButton(configuration: { var c = UIButton.Configuration.tinted(); c.title = "Top"; c.image = UIImage(systemName: "star.fill"); return c }()).intrinsicContentSize
        log("image placement top: taller \(ss.height > plainSize.height), narrower \(ss.width < plainSize.width)")
        stackedButton.frame = CGRect(x: 20, y: 200, width: ss.width, height: ss.height)
        // tint adjustment
        probe.frame = CGRect(x: 300, y: 200, width: 40, height: 40)
        let alertButton = UIButton(type: .system); alertButton.setTitle("Alert", for: .normal); alertButton.frame = CGRect(x: 150, y: 200, width: 100, height: 40)
        alertButton.accessibilityIdentifier = "alert"
        alertButton.addAction(UIAction { [unowned self] _ in
            let a = UIAlertController(title: "Dim", message: nil, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in log("alert dismissed") })
            present(a, animated: false)
        }, for: .primaryActionTriggered)
        // contentMode: a 20 x 20 red image (and a 40 x 20 one) in 60 x 60 image views
        let modes: [(UIView.ContentMode, String)] = [(.center, "center"), (.topLeft, "topLeft"), (.bottomRight, "bottomRight"), (.scaleToFill, "scaleToFill"), (.scaleAspectFit, "aspectFit")]
        for (i, (m, name)) in modes.enumerated() {
            let iv = UIImageView(image: m == .scaleAspectFit ? solid(.red, 40, 20) : solid(.red, 20, 20))
            iv.contentMode = m; iv.backgroundColor = .systemGray5
            iv.frame = CGRect(x: 20 + CGFloat(i) * 72, y: 280, width: 60, height: 60); iv.accessibilityIdentifier = "mode-\(name)"
            view.addSubview(iv)
        }
        // custom input view + accessory view
        let field = UITextField(frame: CGRect(x: 20, y: 360, width: 200, height: 36)); field.borderStyle = .roundedRect; field.accessibilityIdentifier = "field"
        let input = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 200), inputViewStyle: .keyboard)
        input.backgroundColor = .systemGreen; input.accessibilityIdentifier = "customInput"
        let accessory = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44)); accessory.accessibilityIdentifier = "accessory"
        accessory.items = [UIBarButtonItem(title: "Done", style: .done, target: field, action: #selector(UIResponder.resignFirstResponder))]
        field.inputView = input; field.inputAccessoryView = accessory
        // a table with row context menus
        table.frame = CGRect(x: 0, y: 420, width: view.bounds.width, height: 200); table.autoresizingMask = [.flexibleWidth]
        table.dataSource = self; table.delegate = self; table.accessibilityIdentifier = "table"
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        // system: status bar style / hiding, screen brightness, the idle timer
        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 60); header.autoresizingMask = [.flexibleWidth]
        func small(_ t: String, _ id: String, _ x: CGFloat, _ a: @escaping () -> Void) -> UIButton {
            let b = UIButton(type: .system); b.setTitle(t, for: .normal); b.accessibilityIdentifier = id
            b.frame = CGRect(x: x, y: 640, width: 110, height: 36); b.addAction(UIAction { _ in a() }, for: .primaryActionTriggered); return b
        }
        let status = small("Status", "status", 20) { [unowned self] in
            statusStep += 1; header.backgroundColor = .black
            setNeedsStatusBarAppearanceUpdate(); log("status bar step \(statusStep)")
        }
        let dim = small("Dim", "dim", 140) { UIScreen.main.brightness = 0.5 }
        let awake = small("Awake", "awake", 260) { UIApplication.shared.isIdleTimerDisabled = true; log("idle timer disabled \(UIApplication.shared.isIdleTimerDisabled)") }
        NotificationCenter.default.addObserver(forName: UIScreen.brightnessDidChangeNotification, object: nil, queue: nil) { _ in log("brightness \(UIScreen.main.brightness)") }
        for v in [header, card, photo, toggleButton, busyButton, fancyButton, stackedButton, probe, alertButton, field, table, status, dim, awake] as [UIView] { view.addSubview(v) }
    }

    // MARK: context menu interactions
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let which = interaction.view?.accessibilityIdentifier ?? "?"
        log("configuration for \(which) at \(Int(location.x)),\(Int(location.y))")
        if which == "photo" {
            return UIContextMenuConfiguration(identifier: "photo" as NSString, previewProvider: { PreviewController() }) { _ in
                UIMenu(children: [UIAction(title: "Save") { _ in log("action Save") }])
            }
        }
        return UIContextMenuConfiguration(identifier: "card" as NSString, previewProvider: nil) { _ in
            let share = UIMenu(title: "Share", children: [UIAction(title: "Mail") { _ in log("action Mail") }])
            return UIMenu(children: [UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in log("action Copy") }, share,
                                     UIAction(title: "Delete", attributes: .destructive) { _ in log("action Delete") }])
        }
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        log("will display \(configuration.identifier) preview controller \(animator?.previewViewController != nil)")
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        log("will end \(configuration.identifier)")
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { log("preview committed \(configuration.identifier)") }
    }

    // MARK: table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        c.textLabel?.text = "Row \(indexPath.row)"
        return c
    }
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [UIAction(title: "Pin") { _ in log("pinned row \(indexPath.row)") }])
        }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewsController()
        window?.makeKeyAndVisible()
        return true
    }
}
