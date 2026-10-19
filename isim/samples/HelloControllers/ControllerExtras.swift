// HelloControllers, -extras: view controller and container members from the documentation sweep (#9), each logged with "ctl".
// - a tab bar controller with seven tabs: the bar shows four and More (its list pushes the others); the tab bar
//   appearance's item appearances survive the copy
// - navigation: customizable item groups (fixed, optional left out, pinned), the generic back button, a back action,
//   the title menu with Rename (rename delegate), hiding the bars on tap, viewIsAppearing, @ViewLoading
// - split view: the collapsed layout environment, isShowing(_:), the inspector column (a sheet in compact width)
// - search: a token in the field (Delete removes it), the bookmark button, the scope bar on text entry
// - presentations: a popover with a source item and a custom background, a popover adapting to its adaptive sheet,
//   the share sheet from an activity items configuration, the document interaction options menu, the video editor
// - a container forwarding appearance by hand around transition(from:to:), the colour picker's eyedropper switch,
//   the font picker's language filter, a UIManagedDocument saved and reopened
import UIKit
import CoreData
import UniformTypeIdentifiers

fileprivate func log(_ s: String) { print("ctl \(s)") }

enum ControllerExtras {
    /// the page's root: a tab bar controller with seven tabs
    static func make(delegate: UITabBarControllerDelegate) -> UIViewController {
        let tabs = UITabBarController()
        let titles = ["Five", "Six", "Seven"]
        tabs.viewControllers = [UINavigationController(rootViewController: ItemsViewController()), SplitHost.make(),
                                UINavigationController(rootViewController: SearchViewController()),
                                UINavigationController(rootViewController: PresentViewController())]
            + titles.map { t in
                let vc: UIViewController = t == "Five" ? ContainerViewController() : t == "Seven" ? Browser.make() : NamedViewController(name: t)
                vc.tabBarItem = UITabBarItem(title: t, image: UIImage(systemName: "star"), tag: 0)
                return vc
            }
        tabs.delegate = delegate
        // the item appearance is copied with the bar's appearance
        let ap = UITabBarAppearance()
        ap.stackedLayoutAppearance.normal.iconColor = .systemPink
        ap.stackedLayoutAppearance.normal.badgeBackgroundColor = .systemGreen
        tabs.tabBar.standardAppearance = ap
        let kept = tabs.tabBar.standardAppearance.stackedLayoutAppearance
        log("tab appearance kept \(kept.normal.iconColor != nil && kept.normal.badgeBackgroundColor != nil) copied \(kept !== ap.stackedLayoutAppearance)")
        log("more items \(tabs.tabBar.items?.map { $0.title ?? "" }.joined(separator: ",") ?? "")")
        return tabs
    }
}

extension AppDelegate: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let i = tabBarController.selectedIndex
        log("selected \(viewController === tabBarController.moreNavigationController ? "more" : viewController.title ?? "?") index \(i == NSNotFound ? "none" : String(i))")
    }
}

final class NamedViewController: UIViewController {
    let name: String
    init(name: String) { self.name = name; super.init(nibName: nil, bundle: nil); title = name }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .systemBackground }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); log("\(name.lowercased()) appeared") }
}

// ---- navigation ----
final class ItemsViewController: UIViewController, UINavigationItemRenameDelegate {
    @ViewLoading var label: UILabel
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Items"
        view.backgroundColor = .systemBackground
        label = UILabel(frame: CGRect(x: 20, y: 200, width: 300, height: 30))
        label.text = "Items"
        view.addSubview(label)
        let detail = UIButton(type: .system)
        detail.setTitle("Detail", for: .normal)
        detail.accessibilityIdentifier = "detail"
        detail.frame = CGRect(x: 20, y: 260, width: 200, height: 44)
        detail.addAction(UIAction { [weak self] _ in self?.navigationController?.pushViewController(PushedViewController(), animated: true) }, for: .touchUpInside)
        view.addSubview(detail)
        // customizable groups: the optional group left out of the default customization is not shown
        let fixed = UIBarButtonItem(title: "Fix", style: .plain, target: nil, action: nil)
        fixed.accessibilityIdentifier = "fixed"
        let optional = UIBarButtonItem(title: "Opt", style: .plain, target: nil, action: nil)
        optional.accessibilityIdentifier = "optional"
        let pinned = UIBarButtonItem(title: "Pin", style: .plain, target: nil, action: nil)
        pinned.accessibilityIdentifier = "pinned"
        navigationItem.trailingItemGroups = [fixed.creatingFixedGroup(), optional.creatingOptionalGroup(customizationIdentifier: "opt", isInDefaultCustomization: false)]
        if #available(iOS 26.0, *) { navigationItem.pinnedTrailingGroup = pinned.creatingFixedGroup() }
        navigationItem.backButtonDisplayMode = .generic          // the back button to here reads "Back"
        navigationItem.renameDelegate = self
        navigationItem.titleMenuProvider = { suggested in
            UIMenu(children: suggested + [UIAction(title: "Duplicate") { _ in log("duplicate") }])
        }
        log("ready label \(label.text ?? "")")
    }
    override func viewIsAppearing(_ animated: Bool) { super.viewIsAppearing(animated); log("items is appearing \(view.window != nil)") }
    func navigationItem(_ navigationItem: UINavigationItem, didEndRenamingWith title: String) { log("renamed \(title) item \(navigationItem.title ?? "")") }
    func navigationItemShouldBeginRenaming(_ navigationItem: UINavigationItem) -> Bool { log("should rename"); return true }
}

final class PushedViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Detail"
        view.backgroundColor = .secondarySystemBackground
        navigationItem.backAction = UIAction { [weak self] _ in
            log("back action")
            self?.navigationController?.popViewController(animated: true)
        }
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); navigationController?.hidesBarsOnTap = true }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); navigationController?.hidesBarsOnTap = false; navigationController?.setNavigationBarHidden(false, animated: false) }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log("detail appeared tap recognizer \(navigationController?.barHideOnTapGestureRecognizer.isEnabled == true)")
    }
}

// ---- split view ----
enum SplitHost {
    static func make() -> UIViewController {
        let split = UISplitViewController(style: .doubleColumn)
        split.setViewController(NamedViewController(name: "Primary"), for: .primary)
        split.setViewController(SecondaryViewController(), for: .secondary)
        if #available(iOS 26.0, *) {
            split.setViewController(NamedViewController(name: "Inspector"), for: .inspector)
            split.preferredInspectorColumnWidth = 280
            split.minimumSecondaryColumnWidth = 300
        }
        split.tabBarItem = UITabBarItem(title: "Split", image: UIImage(systemName: "sidebar.left"), tag: 0)
        return split
    }
}
final class SecondaryViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Secondary"
        view.backgroundColor = .systemBackground
        let b = UIButton(type: .system)
        b.setTitle("Inspector", for: .normal)
        b.accessibilityIdentifier = "inspector"
        b.frame = CGRect(x: 20, y: 200, width: 200, height: 44)
        b.addAction(UIAction { [weak self] _ in if #available(iOS 26.0, *) { self?.splitViewController?.show(.inspector) } }, for: .touchUpInside)
        view.addSubview(b)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let s = splitViewController else { return }
        var inspector = false
        if #available(iOS 26.0, *) { inspector = s.isShowing(.inspector) }
        log("split collapsed \(s.isCollapsed) environment \(traitCollection.splitViewControllerLayoutEnvironment == .collapsed ? "collapsed" : "expanded") showing secondary \(s.isShowing(.secondary)) primary \(s.isShowing(.primary)) inspector \(inspector)")
    }
}

// ---- search ----
final class SearchViewController: UIViewController, UISearchBarDelegate, UISearchResultsUpdating {
    let search = UISearchController(searchResultsController: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"
        view.backgroundColor = .systemBackground
        search.searchResultsUpdater = self
        search.searchBar.delegate = self
        search.searchBar.showsBookmarkButton = true
        search.searchBar.scopeButtonTitles = ["All", "Mine"]
        search.scopeBarActivation = .onTextEntry
        search.searchBar.searchTextField.insertToken(UISearchToken(icon: UIImage(systemName: "swift"), text: "Swift"), at: 0)
        search.searchBar.searchTextField.tokenBackgroundColor = .systemOrange
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.preferredSearchBarPlacement = .stacked
        log("search tokens \(search.searchBar.searchTextField.tokens.count)")
    }
    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) { log("bookmark") }
    func updateSearchResults(for searchController: UISearchController) {
        let f = searchController.searchBar.searchTextField
        log("search text '\(f.text ?? "")' tokens \(f.tokens.count) scope \(searchController.searchBar.showsScopeBar)")
    }
}

// ---- presentations ----
final class ArrowBackground: UIPopoverBackgroundView {
    override class func arrowBase() -> CGFloat { 20 }
    override class func arrowHeight() -> CGFloat { 10 }
    override class func contentViewInsets() -> UIEdgeInsets { UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4) }
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .systemYellow
        log("popover background arrow \(arrowDirection == .up ? "up" : arrowDirection == .down ? "down" : "side")")
    }
}
final class CloseViewController: UIViewController {
    let name: String
    init(_ name: String) { self.name = name; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        preferredContentSize = CGSize(width: 240, height: 160)
        let b = UIButton(type: .system)
        b.setTitle("Close", for: .normal)
        b.accessibilityIdentifier = "close-\(name)"
        b.frame = CGRect(x: 20, y: 20, width: 120, height: 44)
        b.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside)
        view.addSubview(b)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log("\(name) shown height \(Int(view.frame.height)) screen \(Int(UIScreen.main.bounds.height))")
    }
}

final class PresentViewController: UIViewController, UIPopoverPresentationControllerDelegate, UIDocumentInteractionControllerDelegate,
                                   UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
    var buttons: [String: UIButton] = [:]
    var docs: UIDocumentInteractionController?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Present"
        view.backgroundColor = .systemBackground
        var y: CGFloat = 140
        for name in ["popover", "adaptive", "share", "options", "video"] {
            let b = UIButton(type: .system)
            b.setTitle(name.capitalized, for: .normal)
            b.accessibilityIdentifier = name
            b.frame = CGRect(x: 20, y: y, width: 200, height: 44)
            b.addAction(UIAction { [weak self] _ in self?.run(name) }, for: .touchUpInside)
            view.addSubview(b)
            buttons[name] = b
            y += 54
        }
        // the colour picker's iOS 26 switches and the font picker's language filter
        let picker = UIColorPickerViewController()
        if #available(iOS 26.0, *) {
            picker.supportsEyedropper = false
            picker.maximumLinearExposure = 2
            log("eyedropper \(picker.supportsEyedropper) exposure \(Int(picker.maximumLinearExposure))")
        }
        if #available(iOS 18.0, *) {
            let config = UIFontPickerViewController.Configuration()
            config.languageFilter = #Predicate<[String]> { $0.contains("ja") }
            log("language filter \(config.languageFilter != nil) copy \(UIFontPickerViewController(configuration: config).configuration.languageFilter != nil)")
        }
        managedDocument()
    }
    func run(_ name: String) {
        switch name {
        case "popover":                 // a real popover (the delegate keeps it one) with a custom background
            let vc = CloseViewController("popover")
            vc.modalPresentationStyle = .popover
            vc.popoverPresentationController?.sourceItem = buttons["popover"]
            vc.popoverPresentationController?.popoverBackgroundViewClass = ArrowBackground.self
            vc.popoverPresentationController?.delegate = self
            present(vc, animated: false)
        case "adaptive":                // on iPhone the popover becomes its adaptive sheet (medium detent)
            let vc = CloseViewController("adaptive")
            vc.modalPresentationStyle = .popover
            vc.popoverPresentationController?.sourceItem = buttons["adaptive"]
            vc.popoverPresentationController?.adaptiveSheetPresentationController.detents = [.medium()]
            present(vc, animated: false)
        case "share":
            let config = UIActivityItemsConfiguration(objects: ["Shared text" as NSString])
            config.metadataProvider = { key in key == .title ? "Config Title" : nil }
            present(UIActivityViewController(activityItemsConfiguration: config), animated: false)
        case "options":
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("notes.txt")
            try? "Notes".write(to: url, atomically: true, encoding: .utf8)
            let d = UIDocumentInteractionController(url: url)
            d.delegate = self
            docs = d
            log("doc uti \(d.uti ?? "") name \(d.name ?? "") icons \(d.icons.count)")
            _ = d.presentOptionsMenu(from: buttons["options"]!.frame, in: view, animated: false)
        case "video":
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("clip.mov").path
            FileManager.default.createFile(atPath: path, contents: Data(repeating: 1, count: 64))
            log("can edit \(UIVideoEditorController.canEditVideo(atPath: path)) missing \(UIVideoEditorController.canEditVideo(atPath: "/nope.mov"))")
            let editor = UIVideoEditorController()
            editor.videoPath = path
            editor.delegate = self
            present(editor, animated: false)
        default: break
        }
    }
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }
    func documentInteractionControllerWillPresentOptionsMenu(_ controller: UIDocumentInteractionController) { log("doc will present options") }
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) { log("doc dismissed options") }
    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        log("video saved \((editedVideoPath as NSString).pathExtension) exists \(FileManager.default.fileExists(atPath: editedVideoPath))")
        editor.dismiss(animated: false)
    }

    // a managed document with a model made in code: create and save, reopen, fetch
    final class Doc: UIManagedDocument {
        static let model: NSManagedObjectModel = {
            let e = NSEntityDescription(); e.name = "Note"; e.managedObjectClassName = "NSManagedObject"
            let a = NSAttributeDescription(); a.name = "text"; a.attributeType = .stringAttributeType
            e.properties = [a]
            let m = NSManagedObjectModel(); m.entities = [e]
            return m
        }()
        override var managedObjectModel: NSManagedObjectModel { Doc.model }
    }
    func managedDocument() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Notes-\(UUID().uuidString).notes")
        let doc = Doc(fileURL: url)
        let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: doc.managedObjectContext)
        note.setValue("hello", forKey: "text")
        doc.save(to: url, for: .forCreating) { ok in
            doc.close { _ in
                let again = Doc(fileURL: url)
                again.open { opened in
                    let count = (try? again.managedObjectContext.count(for: NSFetchRequest<NSManagedObject>(entityName: "Note"))) ?? -1
                    log("managed document saved \(ok) opened \(opened) count \(count) store \(FileManager.default.fileExists(atPath: url.appendingPathComponent("StoreContent/persistentStore").path))")
                }
            }
        }
    }
}

// ---- the document browser: custom actions (a document's menu, bar buttons while selecting), renaming ----
enum Browser {
    static func make() -> UIViewController {
        let b = UIDocumentBrowserViewController(forOpening: [.plainText])
        b.allowsPickingMultipleItems = true
        let tag = UIDocumentBrowserAction(identifier: "tag", localizedTitle: "Tag", availability: [.menu, .navigationBar]) { urls in
            log("action tag \(urls.map(\.lastPathComponent).joined(separator: ","))")
        }
        tag.supportedContentTypes = ["public.plain-text"]
        b.customActions = [tag]
        let src = FileManager.default.temporaryDirectory.appendingPathComponent("draft.txt")
        try? "Draft".write(to: src, atomically: true, encoding: .utf8)
        b.revealDocument(at: src, importIfNeeded: true) { url, _ in
            guard let url else { return }
            b.renameDocument(at: url, proposedName: "Letter") { final, error in
                log("renamed document \(final?.lastPathComponent ?? "-") error \(error != nil) transition \(b.transitionController(forDocumentAt: final ?? url).transitionDuration(using: nil))")
            }
        }
        return b
    }
}

// ---- a container that forwards appearance itself ----
final class ContainerViewController: UIViewController {
    let a = Child("a"), b = Child("b")
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
    override var childForStatusBarStyle: UIViewController? { children.last }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Five"
        view.backgroundColor = .systemBackground
        addChild(a); a.view.frame = CGRect(x: 0, y: 120, width: view.bounds.width, height: 200); view.addSubview(a.view); a.didMove(toParent: self)
        let swap = UIButton(type: .system)
        swap.setTitle("Swap", for: .normal)
        swap.accessibilityIdentifier = "swap"
        swap.frame = CGRect(x: 20, y: 340, width: 200, height: 44)
        swap.addAction(UIAction { [weak self] _ in self?.swapChildren() }, for: .touchUpInside)
        view.addSubview(swap)
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); a.beginAppearanceTransition(true, animated: animated) }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); a.endAppearanceTransition(); log("five appeared") }
    func swapChildren() {
        a.willMove(toParent: nil)
        addChild(b)
        b.view.frame = a.view.frame
        a.beginAppearanceTransition(false, animated: false)        // (this container forwards appearance itself)
        b.beginAppearanceTransition(true, animated: false)
        transition(from: a, to: b, duration: 0, options: [], animations: nil) { [self] done in
            a.endAppearanceTransition()
            b.endAppearanceTransition()
            a.removeFromParent()
            b.didMove(toParent: self)
            log("swapped \(done) status bar child b \(childForStatusBarStyle === b)")
        }
    }
    final class Child: UIViewController {
        let name: String
        init(_ name: String) { self.name = name; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); log("child \(name) will appear") }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); log("child \(name) appeared") }
        override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); log("child \(name) disappeared") }
    }
}
