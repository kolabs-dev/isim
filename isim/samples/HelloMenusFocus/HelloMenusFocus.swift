// Sample: menus, commands and the focus system from the documentation sweep (#9), each logged with "mf".
// - Menus: the app's main menu (buildMenu(with:) adds a Tools menu with key commands, edits File and removes
//   Format; iOS 26: the main menu configuration), commands sent up the responder chain and validated, a pop-up menu
//   with a small-element palette, deferred elements (cached and uncached), an element that keeps the menu up,
//   wrapped titles, a key command with its shortcut, selected elements, an edit menu that follows its target,
//   the context menu's appearance, Scan Text
// - Focus (iPad keyboard navigation): tiles in a focus group with a prioritized one and a halo effect, a refused
//   focus update, a focus guide, a collection view whose selection follows focus, a text field, the focus debugger
import UIKit

func log(_ s: String) { print("mf \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if #available(iOS 26.0, *) {
            let config = UIMainMenuSystem.Configuration()
            config.findingConfiguration.style = .search
            config.sidebarPreference = .included
            UIMainMenuSystem.shared.setBuildConfiguration(config) { builder in
                log("build handler find \(builder.menu(for: .find)?.children.count ?? -1) sidebar \(builder.menu(for: .sidebar) != nil)")
            }
        }
        let tabs = UITabBarController()
        let menus = UINavigationController(rootViewController: MenusViewController())
        let focus = UINavigationController(rootViewController: FocusViewController())
        menus.tabBarItem = UITabBarItem(title: "Menus", image: UIImage(systemName: "filemenu.and.selection"), tag: 0)
        focus.tabBarItem = UITabBarItem(title: "Focus", image: UIImage(systemName: "keyboard"), tag: 1)
        tabs.viewControllers = [menus, focus]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
    // the main menu: a Tools menu after Edit, Export in File, no Format menu
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == UIMenuSystem.main else { return }
        let refresh = UIKeyCommand(title: "Refresh", image: UIImage(systemName: "arrow.clockwise"), action: #selector(MenusViewController.refresh(_:)),
                                   input: "r", modifierFlags: .command, discoverabilityTitle: "Refresh the list")
        refresh.repeatBehavior = .nonRepeatable
        let reset = UICommand(title: "Reset", action: #selector(MenusViewController.reset(_:)))
        let tools = UIMenu(title: "Tools", identifier: UIMenu.Identifier("dev.isim.tools"), children: [refresh, reset])
        builder.insertSibling(tools, afterMenu: .edit)
        builder.replaceChildren(ofMenu: .file) { $0 + [UIKeyCommand(title: "Export", action: #selector(MenusViewController.export(_:)), input: "e", modifierFlags: [.command, .shift])] }
        builder.remove(menu: .format)
        let copy = builder.command(for: #selector(UIResponderStandardEditActions.copy(_:)), propertyList: nil)
        log("build main edit \(builder.menu(for: .edit)?.title ?? "-") copy \(copy?.title ?? "-") tools \(builder.menu(for: UIMenu.Identifier("dev.isim.tools"))?.children.count ?? 0) format \(builder.menu(for: .format) == nil ? "removed" : "kept")")
    }
}

// MARK: - Menus
final class MenusViewController: UIViewController, UIEditMenuInteractionDelegate, UIContextMenuInteractionDelegate {
    let button = UIButton(type: .system)
    let field = UITextField()
    let editTarget = UIView()
    var editInteraction: UIEditMenuInteraction!
    var contextInteraction: UIContextMenuInteraction!
    var refreshes = 0, uncachedCalls = 0
    var flagged = false
    var sizeChoice = "Medium"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Menus"
        view.backgroundColor = .systemBackground
        button.setTitle("Actions", for: .normal)
        button.accessibilityIdentifier = "actions"
        button.showsMenuAsPrimaryAction = true
        button.menu = makeMenu()
        field.borderStyle = .roundedRect; field.placeholder = "Text"; field.accessibilityIdentifier = "field"
        editTarget.backgroundColor = .systemTeal; editTarget.accessibilityIdentifier = "edit-target"
        editInteraction = UIEditMenuInteraction(delegate: self)
        editTarget.addInteraction(editInteraction)
        let contextBox = UIView(); contextBox.backgroundColor = .systemOrange; contextBox.accessibilityIdentifier = "context-box"
        contextInteraction = UIContextMenuInteraction(delegate: self)
        contextBox.addInteraction(contextInteraction)
        let showEdit = UIButton(type: .system); showEdit.setTitle("Edit Menu", for: .normal); showEdit.accessibilityIdentifier = "show-edit"
        showEdit.addAction(UIAction { [weak self] _ in self?.showEditMenu() }, for: .touchUpInside)
        for (v, f) in [(button, CGRect(x: 20, y: 120, width: 120, height: 44)), (field, CGRect(x: 160, y: 120, width: 180, height: 36)),
                       (showEdit, CGRect(x: 20, y: 180, width: 120, height: 44)), (editTarget, CGRect(x: 20, y: 240, width: 100, height: 60)), (contextBox, CGRect(x: 160, y: 240, width: 100, height: 60))] as [(UIView, CGRect)] {
            v.frame = f; view.addSubview(v)
        }

        // identifiers, replacing children, selected elements
        let sizes = UIMenu(title: "Size", options: .singleSelection, children: ["Small", "Medium", "Large"].map { t in
            UIAction(title: t, identifier: UIAction.Identifier("size-\(t)"), state: t == "Medium" ? .on : .off) { _ in }
        })
        let replaced = sizes.replacingChildren([UIAction(title: "Only") { _ in }])
        log("identifiers paste \(UIAction.Identifier.paste.rawValue.isEmpty ? "-" : "set") menu \(UIMenu.Identifier.edit != UIMenu.Identifier.file) dynamic \(sizes.identifier.rawValue.hasPrefix("com.apple.menu.dynamic"))")
        log("selected \(sizes.selectedElements.map(\.title)) replaced \(replaced.children.map(\.title)) same id \(replaced.identifier == sizes.identifier)")
        let scan = UIAction.captureTextFromCamera(responder: field, identifier: nil)
        log("scan text \(scan.title) image \(scan.image != nil)")
        let alt = UICommandAlternate(title: "Refresh All", action: #selector(refresh(_:)), modifierFlags: .alternate)
        let cmd = UICommand(title: "Refresh", action: #selector(refresh(_:)), propertyList: UICommandTagShare, alternates: [alt])
        log("command alternates \(cmd.alternates.map(\.title)) share \((cmd.propertyList as? String) == UICommandTagShare)")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        log("menus ready")
    }
    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        let k = UIKeyCommand(title: "Flag", action: #selector(flag(_:)), input: "f", modifierFlags: [.command, .alternate])
        return [k]
    }

    func makeMenu() -> UIMenu {
        let edit = UIMenu(options: .displayInline, children: [
            UIAction(title: "Cut", image: UIImage(systemName: "scissors")) { _ in log("chose Cut") },
            UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in log("chose Copy") },
            UIAction(title: "Paste", image: UIImage(systemName: "doc.on.clipboard")) { _ in log("chose Paste") },
        ])
        edit.preferredElementSize = .small
        let cached = UIDeferredMenuElement { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion([UIAction(title: "Loaded A") { _ in log("chose Loaded A") }, UIAction(title: "Loaded B") { _ in }])
            }
        }
        let uncached = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return }
            self.uncachedCalls += 1
            log("uncached provider \(self.uncachedCalls)")
            completion([UIAction(title: "Fresh \(self.uncachedCalls)") { _ in }])
        }
        let keep = UIAction(title: "Flagged", image: UIImage(systemName: "flag"), attributes: .keepsMenuPresented, state: flagged ? .on : .off) { [weak self] a in
            guard let self else { return }
            self.flagged.toggle(); a.state = self.flagged ? .on : .off
            log("flag toggled \(self.flagged)")
        }
        let hi = UICommand(title: "Greet", image: UIImage(systemName: "hand.wave"), action: #selector(sayHi(_:)))
        let shortcut = UIKeyCommand(title: "Refresh", action: #selector(refresh(_:)), input: "r", modifierFlags: .command)
        let long = UIAction(title: "A rather long title that wraps onto a second line in the menu") { _ in }
        let menu = UIMenu(children: [edit, cached, uncached, keep, hi, shortcut, long])
        if #available(iOS 17.4, *) {
            let prefs = UIMenuDisplayPreferences(); prefs.maximumNumberOfTitleLines = 2
            menu.displayPreferences = prefs
        }
        return menu
    }

    @objc func sayHi(_ sender: UICommand) { log("greet from \(type(of: sender)) source \(sender.presentationSourceItem != nil)") }
    @objc func refresh(_ sender: UICommand) { refreshes += 1; log("refresh \(refreshes) from \(sender.title)") }
    @objc func reset(_ sender: UICommand) { log("reset") }
    @objc func export(_ sender: UICommand) { log("export") }
    @objc func flag(_ sender: UIKeyCommand) { log("flag command \(sender.title)") }
    override func validate(_ command: UICommand) {
        super.validate(command)
        if command.action == #selector(refresh(_:)) { command.title = refreshes > 0 ? "Refresh Again" : "Refresh" }
        if command.action == #selector(reset(_:)) { command.attributes = refreshes == 0 ? .disabled : [] }
    }

    // edit menu that follows its target
    func showEditMenu() {
        editInteraction.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: CGPoint(x: 50, y: 30)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.moveEditTarget() }      // the content moves under the menu
    }
    func moveEditTarget() {
        editTarget.frame.origin.y += 120
        editInteraction.updateVisibleMenuPosition(animated: false)
    }
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        UIMenu(children: [UIAction(title: "Inspect") { _ in log("inspect") }])
    }
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect { editTarget.bounds }

    // context menu appearance
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        log("context appearance before \(interaction.menuAppearance.rawValue)")
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in UIMenu(children: [UIAction(title: "Open") { _ in log("context open") }]) }
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        DispatchQueue.main.async { log("context appearance shown \(interaction.menuAppearance == .rich ? "rich" : "other")") }
    }
}

// MARK: - Focus
final class Tile: UIView {
    var locked = false
    override var canBecomeFocused: Bool { true }
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        if locked && context.nextFocusedView === self { log("tile \(accessibilityIdentifier ?? "") refused focus"); return false }
        return true
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if context.nextFocusedView === self {
            coordinator.addCoordinatedFocusingAnimations({ _ in self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05) }, completion: nil)
        } else if context.previouslyFocusedView === self {
            coordinator.addCoordinatedUnfocusingAnimations({ _ in self.transform = .identity }, completion: nil)
        }
    }
}
final class FocusViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var tiles: [Tile] = []
    var grid: UICollectionView!
    let field = UITextField()
    var updates = 0
    var preferTile: Tile?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Focus"
        view.backgroundColor = .systemBackground
        for (i, name) in ["one", "two", "three", "locked"].enumerated() {
            let t = Tile(frame: CGRect(x: 20 + CGFloat(i) * 90, y: 120, width: 76, height: 60))
            t.backgroundColor = .systemIndigo; t.layer.cornerRadius = 12
            t.accessibilityIdentifier = "tile-\(name)"
            t.focusGroupIdentifier = "dev.isim.tiles"
            t.locked = name == "locked"
            if name == "two" { t.focusGroupPriority = .prioritized }
            t.focusEffect = UIFocusHaloEffect(roundedRect: t.bounds, cornerRadius: 12, curve: .continuous)
            view.addSubview(t); tiles.append(t)
        }
        let layout = UICollectionViewFlowLayout(); layout.itemSize = CGSize(width: 70, height: 50); layout.minimumInteritemSpacing = 10
        grid = UICollectionView(frame: CGRect(x: 20, y: 220, width: 360, height: 60), collectionViewLayout: layout)
        grid.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        grid.dataSource = self; grid.delegate = self
        grid.allowsFocus = true; grid.selectionFollowsFocus = true
        grid.accessibilityIdentifier = "grid"
        view.addSubview(grid)
        field.frame = CGRect(x: 20, y: 300, width: 200, height: 36); field.borderStyle = .roundedRect; field.accessibilityIdentifier = "focus-field"
        view.addSubview(field)
        // a guide under the tiles: moving down from them lands on "one"
        let guide = UIFocusGuide()
        view.addLayoutGuide(guide)
        guide.preferredFocusEnvironments = [tiles[0]]
        NSLayoutConstraint.activate([guide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), guide.widthAnchor.constraint(equalToConstant: 360),
                                     guide.topAnchor.constraint(equalTo: view.topAnchor, constant: 190), guide.heightAnchor.constraint(equalToConstant: 20)])
        NotificationCenter.default.addObserver(forName: UIFocusSystem.didUpdateNotification, object: nil, queue: nil) { [weak self] n in
            guard let self else { return }
            self.updates += 1
            let ctx = n.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext
            let ip = (ctx as? UICollectionViewFocusUpdateContext)?.nextFocusedIndexPath.map { "\($0.item)" } ?? "-"
            log("did update \(self.updates) to \(ctx?.nextFocusedView?.accessibilityIdentifier ?? "?") heading \(ctx?.focusHeading.rawValue ?? 0) item \(ip) coordinator \(n.userInfo?[UIFocusSystem.animationCoordinatorUserInfoKey] != nil)")
        }
        NotificationCenter.default.addObserver(forName: UIFocusSystem.movementDidFailNotification, object: nil, queue: nil) { n in
            let ctx = n.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext
            log("movement failed heading \(ctx?.focusHeading.rawValue ?? 0)")
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let system = UIFocusSystem.focusSystem(for: view)
        log("focus system \(system != nil) priority \(UIFocusGroupPriority.prioritized.rawValue > UIFocusGroupPriority.previouslyFocused.rawValue)")
        guard system != nil else { return }
        log("debugger \(UIFocusDebugger.checkFocusability(for: tiles[0]).description.contains("is focusable"))")
        log("debugger hidden \(UIFocusDebugger.checkFocusability(for: UIView()).description.contains("not focusable"))")
        log("debugger groups \(UIFocusDebugger.focusGroups(for: view).description.split(separator: "\n").first ?? "")")
        log("debugger simulate \(UIFocusDebugger.simulateFocusUpdateRequest(from: self).description.contains("tile-two"))")
        // programmatic focus waits for the keyboard
        preferTile = tiles[0]
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        log("focused after request \(system?.focusedItem != nil)")
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { preferTile.map { [$0] } ?? [] }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 4 }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let c = cv.dequeueReusableCell(withReuseIdentifier: "c", for: ip)
        c.backgroundColor = .systemMint; c.layer.cornerRadius = 8
        c.accessibilityIdentifier = "cell-\(ip.item)"
        return c
    }
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) { log("selected item \(ip.item)") }
    func collectionView(_ cv: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        log("grid focus \(context.previouslyFocusedIndexPath?.item ?? -1) -> \(context.nextFocusedIndexPath?.item ?? -1)")
    }
}
