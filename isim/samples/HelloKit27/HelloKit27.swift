// Sample: small UIKit additions of iOS 27 (and two older APIs they sit next to).
// - menus: UIMenuElement.subtitle (a second line), preferredImageVisibility (.hidden drops the image),
//   highlightStateUpdateHandler; a context menu with UIContextMenuConfiguration.allowsTypeSelect (typing on a hardware
//   keyboard highlights a matching item, Return chooses it) and one without (the keys go to the text field)
// - UIWindowScene.displayLink(action:) and displayLink(target:selector:)
// - UIFont.Weight.symbolWeight() / UIImage.SymbolWeight.fontWeight() (iOS 13)
// - UIDragInteraction.liftBehavior (.extended: a longer lift delay) and allowsPointerDragBeforeLiftDelay (pointer drags
//   start on movement; script `pointerdrag`)
import UIKit
import UniformTypeIdentifiers

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = KitViewController()
        window?.makeKeyAndVisible()
        print("hk symbolWeight semibold \(UIFont.Weight.semibold.symbolWeight() == .semibold) 0.35 \(UIFont.Weight(0.35).symbolWeight().rawValue) bold font \(UIImage.SymbolWeight.bold.fontWeight() == .bold) unspecified \(UIImage.SymbolWeight.unspecified.fontWeight() == .regular)")
        return true
    }
}

final class Box: UIView {
    let label = UILabel()
    init(_ name: String, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color; layer.cornerRadius = 12
        label.text = name; label.textAlignment = .center; label.font = .systemFont(ofSize: 13, weight: .semibold)
        addSubview(label)
        accessibilityIdentifier = name
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); label.frame = bounds }
}

final class KitViewController: UIViewController, UIContextMenuInteractionDelegate, UIDragInteractionDelegate, UIDropInteractionDelegate {
    let menuButton = UIButton(type: .system)
    let typeBox = Box("menu-typeselect", color: .systemTeal), noTypeBox = Box("menu-notypeselect", color: .systemGray4)
    let field = UITextField()
    let dragDefault = Box("drag-default", color: .systemOrange), dragExtended = Box("drag-extended", color: .systemPink)
    let dragPointerLate = Box("drag-pointer-late", color: .systemPurple), target = Box("drop-target", color: .systemGreen)
    var frames = 0, targetFrames = 0
    var link: CADisplayLink?, link2: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        menuButton.setTitle("Menu", for: .normal)
        menuButton.accessibilityIdentifier = "menu-button"
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = UIMenu(children: elements())
        field.borderStyle = .roundedRect; field.placeholder = "Type"; field.accessibilityIdentifier = "field"
        field.addAction(UIAction { [weak self] _ in print("hk field \"\(self?.field.text ?? "")\"") }, for: .editingChanged)
        for v in [menuButton, typeBox, noTypeBox, field, dragDefault, dragExtended, dragPointerLate, target] as [UIView] { view.addSubview(v) }
        typeBox.addInteraction(UIContextMenuInteraction(delegate: self))
        noTypeBox.addInteraction(UIContextMenuInteraction(delegate: self))
        for (box, kind) in [(dragDefault, 0), (dragExtended, 1), (dragPointerLate, 2)] {
            let d = UIDragInteraction(delegate: self)
            if #available(iOS 27, *) {
                if kind == 1 { d.liftBehavior = .extended }
                if kind == 2 { d.allowsPointerDragBeforeLiftDelay = false }
            }
            box.addInteraction(d)
        }
        target.addInteraction(UIDropInteraction(delegate: self))
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top + 20, W = view.bounds.width
        menuButton.frame = CGRect(x: 20, y: top, width: 100, height: 44)
        typeBox.frame = CGRect(x: 20, y: top + 60, width: 150, height: 60)
        noTypeBox.frame = CGRect(x: W - 170, y: top + 60, width: 150, height: 60)
        field.frame = CGRect(x: 20, y: top + 140, width: W - 40, height: 40)
        dragDefault.frame = CGRect(x: 20, y: top + 220, width: 100, height: 80)
        dragExtended.frame = CGRect(x: (W - 100) / 2, y: top + 220, width: 100, height: 80)
        dragPointerLate.frame = CGRect(x: W - 120, y: top + 220, width: 100, height: 80)
        target.frame = CGRect(x: 20, y: top + 360, width: W - 40, height: 120)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let scene = view.window?.windowScene else { return }
        if #available(iOS 27, *) {
            link = scene.displayLink { [weak self] l in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.frames += 1
                    if self.frames == 10 { print("hk displayLink action 10 frames"); l.invalidate() }
                }
            }
            link?.add(to: .main, forMode: .common)
            link2 = scene.displayLink(target: self, selector: #selector(tick(_:)))
            link2?.add(to: .main, forMode: .common)
        } else {
            print("hk ios27 no")
        }
    }
    @objc func tick(_ l: CADisplayLink) {
        targetFrames += 1
        if targetFrames == 10 { print("hk displayLink target 10 frames"); l.invalidate() }
    }

    func elements() -> [UIMenuElement] {
        let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in print("hk chose Copy") }
        copy.subtitle = "To the clipboard"
        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in print("hk chose Share") }
        let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in print("hk chose Delete") }
        if #available(iOS 27, *) {
            share.preferredImageVisibility = .hidden
            for e in [copy, share, delete] { e.highlightStateUpdateHandler = { el, on in print("hk highlight \(el.title) \(on)") } }
        }
        return [copy, share, delete]
    }
    // context menus: type select on the first box, not on the second
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let c = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in UIMenu(children: self?.elements() ?? []) }
        if #available(iOS 27, *) { c.allowsTypeSelect = interaction.view === typeBox }
        return c
    }
    // drag and drop
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        let name = interaction.view?.accessibilityIdentifier ?? "?"
        print("hk drag began \(name)")
        let item = UIDragItem(itemProvider: NSItemProvider(object: name as NSString))
        item.localObject = name
        return [item]
    }
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool { true }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal { UIDropProposal(operation: .copy) }
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        print("hk dropped \(session.items.first?.localObject as? String ?? "?")")
    }
}
