// isim UIKit overlay (self-authored): what Swift apps need beyond the imported ObjC API.
@_exported import UIKit
@_exported import DeveloperToolsSupport

// MARK: - #Preview of UIKit views and view controllers (isim: compiles and type-checks; `isim preview` renders one)
@freestanding(declaration)
public macro Preview(_ name: String? = nil, traits: PreviewTrait<Preview.ViewTraits>..., @PreviewMacroBodyBuilder<UIView> body: @escaping @MainActor () -> UIView) =
    #externalMacro(module: "PreviewsMacros", type: "UIKitView")
@freestanding(declaration)
public macro Preview(_ name: String? = nil, traits: PreviewTrait<Preview.ViewTraits>..., @PreviewMacroBodyBuilder<UIViewController> body: @escaping @MainActor () -> UIViewController) =
    #externalMacro(module: "PreviewsMacros", type: "UIKitViewController")
extension Preview {
    public init(_isimUIView name: String?, traits: [PreviewTrait<ViewTraits>], @PreviewMacroBodyBuilder<UIView> body: @escaping @MainActor () -> UIView) {
        self.init(_isimName: name, traits: traits, content: body)
    }
    public init(_isimViewController name: String?, traits: [PreviewTrait<ViewTraits>], @PreviewMacroBodyBuilder<UIViewController> body: @escaping @MainActor () -> UIViewController) {
        self.init(_isimName: name, traits: traits, content: body)
    }
}

/// `isim preview`: the view controller showing a `#Preview` (its entry point, made by the macro, returns it retained;
/// as an address, 0 when the preview failed).
@MainActor public func _isimPreviewEntry(_ registry: any PreviewRegistry.Type) -> Int {
    do {
        let p = try registry.makePreview()
        NSLog("isim: preview %@ (%@:%ld)", p.name ?? "unnamed", registry.fileID, registry.line)
        return Int(bitPattern: Unmanaged.passRetained(_isimPreviewController(p)).toOpaque())
    } catch {
        NSLog("isim: preview failed: %@", "\(error)")
        return 0
    }
}
/// The preview's content in a view controller, laid out by its traits: the device (default), its size that fits or a
/// fixed size (centred on a grey canvas, like Xcode's).
@MainActor func _isimPreviewController(_ p: Preview) -> UIViewController {
    let content: UIViewController
    if let make = p._isimController, let vc = make() as? UIViewController { content = vc }
    else {
        let made = p._isimMakeContent()
        if let vc = made as? UIViewController { content = vc }
        else {
            content = UIViewController()
            if let v = made as? UIView { v.frame = content.view.bounds; v.autoresizingMask = [.flexibleWidth, .flexibleHeight]; content.view.addSubview(v) }
        }
    }
    var layout: PreviewTrait<Preview.ViewTraits>._Kind = .defaultLayout
    for t in p.traits.flatMap(\._isimFlattened) {
        switch t._kind { case .orientation, .modifier, .combined: continue; default: layout = t._kind }
    }
    guard layout != .defaultLayout else { return content }
    return _IsimPreviewCanvas(content: content, layout: layout)
}
/// A grey canvas with the content at its fitting size or a fixed size in the middle.
final class _IsimPreviewCanvas: UIViewController {
    let content: UIViewController, layout: PreviewTrait<Preview.ViewTraits>._Kind
    init(content: UIViewController, layout: PreviewTrait<Preview.ViewTraits>._Kind) { self.content = content; self.layout = layout; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5
        addChild(content)
        view.addSubview(content.view)
        content.view.accessibilityIdentifier = "preview-content"
        content.didMove(toParent: self)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds.inset(by: view.safeAreaInsets)
        var size: CGSize
        switch layout {
        case .fixedLayout(let w, let h): size = CGSize(width: w, height: h)
        default:
            size = content.view.systemLayoutSizeFitting(CGSize(width: b.width, height: 0))
            if size.width <= 0 || size.height <= 0 { size = content.preferredContentSize }
            if let h = content as? _IsimSizing { size = h._isimFittingSize(in: b.size) }
        }
        size = CGSize(width: min(size.width, b.width), height: min(size.height, b.height))
        content.view.frame = CGRect(x: b.midX - size.width / 2, y: b.midY - size.height / 2, width: size.width, height: size.height)
    }
}
/// A view controller that measures its content (SwiftUI's hosting controller).
@MainActor public protocol _IsimSizing { func _isimFittingSize(in size: CGSize) -> CGSize }

extension UIApplicationDelegate {
  /// Entry point for `@main` app delegates (same contract as Apple's UIKit overlay).
  public static func main() {
    UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(self))
  }
}

// MARK: - Apple's member names for the launch and open-URL option keys (the importer keeps the constants' "Key" suffix: .urlKey)
extension UIApplication.LaunchOptionsKey {
    public static var url: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsURLKey") }
    public static var sourceApplication: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsSourceApplicationKey") }
    public static var shortcutItem: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsShortcutItemKey") }
    public static var userActivityDictionary: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsUserActivityDictionaryKey") }
    public static var userActivityType: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsUserActivityTypeKey") }
    public static var remoteNotification: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsRemoteNotificationKey") }
    public static var location: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsLocationKey") }
    public static var eventAttribution: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsEventAttributionKey") }
    @available(iOS, introduced: 7.0, deprecated: 26.0, message: "Use UIScene state restoration")
    public static var bluetoothCentrals: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsBluetoothCentralsKey") }
    @available(iOS, introduced: 7.0, deprecated: 26.0, message: "Use UIScene state restoration")
    public static var bluetoothPeripherals: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsBluetoothPeripheralsKey") }
    @available(iOS, introduced: 5.0, deprecated: 26.0)
    public static var newsstandDownloads: UIApplication.LaunchOptionsKey { UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsNewsstandDownloadsKey") }
}
extension UIApplication.OpenURLOptionsKey {
    public static var sourceApplication: UIApplication.OpenURLOptionsKey { UIApplication.OpenURLOptionsKey(rawValue: "UIApplicationOpenURLOptionsSourceApplicationKey") }
    public static var openInPlace: UIApplication.OpenURLOptionsKey { UIApplication.OpenURLOptionsKey(rawValue: "UIApplicationOpenURLOptionsOpenInPlaceKey") }
    public static var eventAttribution: UIApplication.OpenURLOptionsKey { UIApplication.OpenURLOptionsKey(rawValue: "UIApplicationOpenURLOptionsEventAttributionKey") }
    @available(iOS, introduced: 9.0, deprecated: 26.0)
    public static var annotation: UIApplication.OpenURLOptionsKey { UIApplication.OpenURLOptionsKey(rawValue: "UIApplicationOpenURLOptionsAnnotationKey") }
}
extension UIApplication.OpenExternalURLOptionsKey {
    public static var universalLinksOnly: UIApplication.OpenExternalURLOptionsKey { UIApplication.OpenExternalURLOptionsKey(rawValue: "UIApplicationOpenURLOptionUniversalLinksOnly") }
    public static var eventAttribution: UIApplication.OpenExternalURLOptionsKey { UIApplication.OpenExternalURLOptionsKey(rawValue: "UIApplicationOpenExternalURLOptionsEventAttributionKey") }
}

// MARK: - Geometry conveniences (UIKit Swift overlay API)
extension UIEdgeInsets: Equatable {
    public static var zero: UIEdgeInsets { UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    public static func == (a: UIEdgeInsets, b: UIEdgeInsets) -> Bool { a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right }
}
// the string forms of Foundation's geometry (NSStringFromCGPoint / Size / Rect) under their UIKit Swift names
extension NSCoder {
    public static func string(for point: CGPoint) -> String { NSStringFromCGPoint(point) }
    public static func string(for size: CGSize) -> String { NSStringFromCGSize(size) }
    public static func string(for rect: CGRect) -> String { NSStringFromCGRect(rect) }
}
extension UIOffset: Equatable {
    public static var zero: UIOffset { UIOffset(horizontal: 0, vertical: 0) }
    public static func == (a: UIOffset, b: UIOffset) -> Bool { a.horizontal == b.horizontal && a.vertical == b.vertical }
}
extension NSDirectionalEdgeInsets: Equatable {
    public static var zero: NSDirectionalEdgeInsets { NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0) }
    public static func == (a: NSDirectionalEdgeInsets, b: NSDirectionalEdgeInsets) -> Bool { a.top == b.top && a.leading == b.leading && a.bottom == b.bottom && a.trailing == b.trailing }
}
extension CGRect {
    public func inset(by i: UIEdgeInsets) -> CGRect {
        CGRect(x: origin.x + i.left, y: origin.y + i.top, width: size.width - i.left - i.right, height: size.height - i.top - i.bottom)
    }
}

// MARK: - Menus (Swift conveniences from Apple's UIKit overlay)
extension UIAction {
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: UIAction.Identifier? = nil,
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        self.init(__title: title, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle,
                  attributes: attributes, state: state, handler: handler)
        self.subtitle = subtitle
    }
    // isim before 0.16 typed identifiers as String (kept for apps built then)
    @_disfavoredOverload @available(*, deprecated, message: "identifiers are UIAction.Identifier, as on iOS")
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: String? = nil,
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        self.init(title: title, subtitle: subtitle, image: image, identifier: identifier.map(UIAction.Identifier.init(rawValue:)),
                  discoverabilityTitle: discoverabilityTitle, attributes: attributes, state: state, handler: handler)
    }
}
extension UIMenu {
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: UIMenu.Identifier? = nil,
                            options: UIMenu.Options = [], children: [UIMenuElement] = []) {
        self.init(__title: title, image: image, identifier: identifier, options: options, children: children)
        self.subtitle = subtitle
    }
    // isim before 0.16 typed identifiers as String (kept for apps built then)
    @_disfavoredOverload @available(*, deprecated, message: "identifiers are UIMenu.Identifier, as on iOS")
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: String? = nil,
                            options: UIMenu.Options = [], children: [UIMenuElement] = []) {
        self.init(title: title, subtitle: subtitle, image: image, identifier: identifier.map(UIMenu.Identifier.init(rawValue:)), options: options, children: children)
    }
}
extension UICommand {
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, action: Selector, propertyList: Any? = nil,
                            alternates: [UICommandAlternate] = [], discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off) {
        self.init(__title: title, image: image, action: action, propertyList: propertyList, alternates: alternates)
        self.subtitle = subtitle
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }
}
extension UIKeyCommand {
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, action: Selector, input: String,
                            modifierFlags: UIKeyModifierFlags = [], propertyList: Any? = nil, alternates: [UICommandAlternate] = [],
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off) {
        self.init(__title: title, image: image, action: action, input: input, modifierFlags: modifierFlags, propertyList: propertyList, alternates: alternates)
        self.subtitle = subtitle
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }
}
extension UIMenuBuilder {
    @available(iOS 26.0, *)
    public func insertElements(_ insertedElements: [UIMenuElement], beforeCommand siblingAction: Selector, propertyList siblingPropertyList: Any? = nil) {
        __insertElements(insertedElements, beforeCommand: siblingAction, propertyList: siblingPropertyList)
    }
    @available(iOS 26.0, *)
    public func insertElements(_ insertedElements: [UIMenuElement], afterCommand siblingAction: Selector, propertyList siblingPropertyList: Any? = nil) {
        __insertElements(insertedElements, afterCommand: siblingAction, propertyList: siblingPropertyList)
    }
}
@available(iOS 26.0, *)
extension UIMainMenuSystem {
    public func setBuildConfiguration(_ configuration: UIMainMenuSystem.Configuration, buildHandler: ((any UIMenuBuilder) -> Void)? = nil) {
        __setBuildConfiguration(configuration, buildHandler: buildHandler)
    }
}

// MARK: - Bar button items (Swift conveniences from Apple's UIKit overlay)
extension UIBarButtonItem {
    public convenience init(title: String? = nil, image: UIImage? = nil, primaryAction: UIAction? = nil, menu: UIMenu? = nil) {
        self.init(__title: title, image: image, primaryAction: primaryAction, menu: menu)
    }
    public convenience init(systemItem: UIBarButtonItem.SystemItem, primaryAction: UIAction? = nil, menu: UIMenu? = nil) {
        if let menu { self.init(barButtonSystemItem: systemItem, menu: menu) } else { self.init(barButtonSystemItem: systemItem, primaryAction: primaryAction) }
    }
}

// MARK: - Table views (Swift conveniences from Apple's UIKit overlay)
extension IndexPath {
    public init(row: Int, section: Int) { self.init(indexes: [section, row]) }
    public init(item: Int, section: Int) { self.init(indexes: [section, item]) }
    public var section: Int { get { self[0] } set { self[0] = newValue } }
    public var row: Int { get { self[1] } set { self[1] = newValue } }
    public var item: Int { get { self[1] } set { self[1] = newValue } }
}

// MARK: - Diffable data sources
/// A snapshot of sections and items, identified by Hashable values (UIKit's NSDiffableDataSourceSnapshot).
public struct NSDiffableDataSourceSnapshot<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable> {
    var _sections: [SectionIdentifierType] = []
    var _items: [SectionIdentifierType: [ItemIdentifierType]] = [:]
    var _reloaded: Set<ItemIdentifierType> = []
    var _reloadedSections: [SectionIdentifierType] = []
    public init() {}
    public var numberOfSections: Int { _sections.count }
    public var numberOfItems: Int { _sections.reduce(0) { $0 + (_items[$1]?.count ?? 0) } }
    public var sectionIdentifiers: [SectionIdentifierType] { _sections }
    public var itemIdentifiers: [ItemIdentifierType] { _sections.flatMap { _items[$0] ?? [] } }
    public var reloadedItemIdentifiers: [ItemIdentifierType] { Array(_reloaded) }
    public var reconfiguredItemIdentifiers: [ItemIdentifierType] { Array(_reloaded) }
    /// the sections reloadSections(_:) / reconfigureSections(_:) marked
    public var reloadedSectionIdentifiers: [SectionIdentifierType] { _reloadedSections }
    public func numberOfItems(inSection id: SectionIdentifierType) -> Int { _items[id]?.count ?? 0 }
    public func itemIdentifiers(inSection id: SectionIdentifierType) -> [ItemIdentifierType] { _items[id] ?? [] }
    public func sectionIdentifier(containingItem item: ItemIdentifierType) -> SectionIdentifierType? { _sections.first { _items[$0]?.contains(item) == true } }
    public func indexOfItem(_ item: ItemIdentifierType) -> Int? { itemIdentifiers.firstIndex(of: item) }
    public func indexOfSection(_ id: SectionIdentifierType) -> Int? { _sections.firstIndex(of: id) }

    public mutating func appendSections(_ ids: [SectionIdentifierType]) { for s in ids where _items[s] == nil { _sections.append(s); _items[s] = [] } }
    public mutating func insertSections(_ ids: [SectionIdentifierType], beforeSection before: SectionIdentifierType) {
        guard let i = _sections.firstIndex(of: before) else { fatalError("Invalid section identifier \(before)") }
        _sections.insert(contentsOf: ids, at: i); for s in ids { _items[s] = [] }
    }
    public mutating func insertSections(_ ids: [SectionIdentifierType], afterSection after: SectionIdentifierType) {
        guard let i = _sections.firstIndex(of: after) else { fatalError("Invalid section identifier \(after)") }
        _sections.insert(contentsOf: ids, at: i + 1); for s in ids { _items[s] = [] }
    }
    public mutating func deleteSections(_ ids: [SectionIdentifierType]) { for s in ids { _sections.removeAll { $0 == s }; _items[s] = nil } }
    public mutating func moveSection(_ id: SectionIdentifierType, beforeSection to: SectionIdentifierType) {
        _sections.removeAll { $0 == id }; _sections.insert(id, at: _sections.firstIndex(of: to)!)
    }
    public mutating func moveSection(_ id: SectionIdentifierType, afterSection to: SectionIdentifierType) {
        _sections.removeAll { $0 == id }; _sections.insert(id, at: _sections.firstIndex(of: to)! + 1)
    }
    public mutating func reloadSections(_ ids: [SectionIdentifierType]) {
        for s in ids { _reloaded.formUnion(_items[s] ?? []); if !_reloadedSections.contains(s) { _reloadedSections.append(s) } }
    }
    public mutating func reconfigureSections(_ ids: [SectionIdentifierType]) { reloadSections(ids) }

    public mutating func appendItems(_ items: [ItemIdentifierType], toSection id: SectionIdentifierType? = nil) {
        guard let s = id ?? _sections.last else { fatalError("There are currently no sections in the data source. Please add a section first.") }
        guard _items[s] != nil else { fatalError("Invalid section identifier \(s)") }
        _items[s]!.append(contentsOf: items)
    }
    public mutating func insertItems(_ items: [ItemIdentifierType], beforeItem before: ItemIdentifierType) {
        guard let s = sectionIdentifier(containingItem: before) else { fatalError("Invalid item identifier \(before)") }
        _items[s]!.insert(contentsOf: items, at: _items[s]!.firstIndex(of: before)!)
    }
    public mutating func insertItems(_ items: [ItemIdentifierType], afterItem after: ItemIdentifierType) {
        guard let s = sectionIdentifier(containingItem: after) else { fatalError("Invalid item identifier \(after)") }
        _items[s]!.insert(contentsOf: items, at: _items[s]!.firstIndex(of: after)! + 1)
    }
    public mutating func deleteItems(_ items: [ItemIdentifierType]) {
        let gone = Set(items)
        for s in _sections { _items[s]!.removeAll { gone.contains($0) } }
        _reloaded.subtract(gone)
    }
    public mutating func deleteAllItems() { _sections = []; _items = [:]; _reloaded = []; _reloadedSections = [] }
    public mutating func moveItem(_ item: ItemIdentifierType, beforeItem to: ItemIdentifierType) {
        deleteItems([item]); insertItems([item], beforeItem: to)
    }
    public mutating func moveItem(_ item: ItemIdentifierType, afterItem to: ItemIdentifierType) {
        deleteItems([item]); insertItems([item], afterItem: to)
    }
    public mutating func reloadItems(_ items: [ItemIdentifierType]) { _reloaded.formUnion(items) }
    public mutating func reconfigureItems(_ items: [ItemIdentifierType]) { _reloaded.formUnion(items) }

    func _item(at ip: IndexPath) -> ItemIdentifierType? {
        guard ip.section < _sections.count, let items = _items[_sections[ip.section]], ip.item < items.count else { return nil }
        return items[ip.item]
    }
    func _indexPath(of item: ItemIdentifierType) -> IndexPath? {
        for (si, s) in _sections.enumerated() { if let r = _items[s]?.firstIndex(of: item) { return IndexPath(item: r, section: si) } }
        return nil
    }
    /// Row-level changes from `old` to self when the sections are unchanged; nil means "reload everything".
    func _changes(from old: Self) -> (deletes: [IndexPath], inserts: [IndexPath], reloads: [IndexPath])? {
        guard old._sections == _sections else { return nil }
        var dels: [IndexPath] = [], ins: [IndexPath] = [], rel: [IndexPath] = []
        for (si, s) in _sections.enumerated() {
            let a = old._items[s] ?? [], b = _items[s] ?? []
            for change in b.difference(from: a) {
                switch change {
                case .remove(let o, _, _): dels.append(IndexPath(row: o, section: si))
                case .insert(let o, _, _): ins.append(IndexPath(row: o, section: si))
                }
            }
            for (r, item) in b.enumerated() where _reloaded.contains(item) && a.contains(item) { rel.append(IndexPath(row: r, section: si)) }
        }
        return (dels, ins, rel)
    }
}

/// A UITableView data source driven by snapshots; changes animate as row inserts and deletes.
@MainActor
open class UITableViewDiffableDataSource<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable>: NSObject, @preconcurrency UITableViewDataSource {
    public typealias CellProvider = (UITableView, IndexPath, ItemIdentifierType) -> UITableViewCell?
    weak var _tableView: UITableView?
    let _cellProvider: CellProvider
    var _snapshot = NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()
    open var defaultRowAnimation: UITableView.RowAnimation = .automatic

    public init(tableView: UITableView, cellProvider: @escaping CellProvider) {
        _tableView = tableView; _cellProvider = cellProvider
        super.init()
        tableView.dataSource = self
    }
    open func snapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> {
        var s = _snapshot; s._reloaded = []; return s
    }
    open func apply(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true,
                    completion: (() -> Void)? = nil) {
        let old = _snapshot
        _snapshot = snapshot; _snapshot._reloaded = []
        guard let tv = _tableView else { completion?(); return }
        if animatingDifferences, let ch = snapshot._changes(from: old) {
            tv.performBatchUpdates({
                tv.deleteRows(at: ch.deletes, with: defaultRowAnimation)
                tv.insertRows(at: ch.inserts, with: defaultRowAnimation)
            }, completion: { _ in completion?() })
            if !ch.reloads.isEmpty { tv.reloadRows(at: ch.reloads, with: .none) }
        } else {
            tv.reloadData(); completion?()
        }
    }
    open func applySnapshotUsingReloadData(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, completion: (() -> Void)? = nil) {
        apply(snapshot, animatingDifferences: false, completion: completion)
    }
    /// iOS 15: the async forms finish when the changes have been applied
    open func apply(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in apply(snapshot, animatingDifferences: animatingDifferences) { c.resume() } }
    }
    open func applySnapshotUsingReloadData(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in applySnapshotUsingReloadData(snapshot) { c.resume() } }
    }
    open func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? { _snapshot._item(at: indexPath) }
    open func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? { _snapshot._indexPath(of: itemIdentifier) }
    open func sectionIdentifier(for index: Int) -> SectionIdentifierType? { index < _snapshot._sections.count ? _snapshot._sections[index] : nil }
    open func index(for sectionIdentifier: SectionIdentifierType) -> Int? { _snapshot._sections.firstIndex(of: sectionIdentifier) }

    // UITableViewDataSource
    open func numberOfSections(in tableView: UITableView) -> Int { _snapshot.numberOfSections }
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        _snapshot.numberOfItems(inSection: _snapshot._sections[section])
    }
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = _snapshot._item(at: indexPath), let cell = _cellProvider(tableView, indexPath, item) else {
            fatalError("UITableViewDiffableDataSource cell provider returned nil for index path \(indexPath)")
        }
        return cell
    }
    open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }
    open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { nil }
    open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { false }
    open func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { false }
    open func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {}
    open func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {}
}

// MARK: - Collection views: registrations (Swift-only API in Apple's UIKit overlay)
extension UICollectionView {
    /// A cell class plus a configuration handler; dequeue with `dequeueConfiguredReusableCell(using:for:item:)`.
    public struct CellRegistration<Cell: UICollectionViewCell, Item> {
        public typealias Handler = (_ cell: Cell, _ indexPath: IndexPath, _ itemIdentifier: Item) -> Void
        let handler: Handler
        let reuseIdentifier = "isim.cell." + UUID().uuidString
        public init(handler: @escaping Handler) { self.handler = handler }
    }
    /// A supplementary view class plus a configuration handler for one element kind.
    public struct SupplementaryRegistration<Supplementary: UICollectionReusableView> {
        public typealias Handler = (_ supplementaryView: Supplementary, _ elementKind: String, _ indexPath: IndexPath) -> Void
        let elementKind: String
        let handler: Handler
        let reuseIdentifier = "isim.supplementary." + UUID().uuidString
        public init(elementKind: String, handler: @escaping Handler) { self.elementKind = elementKind; self.handler = handler }
    }
    public func dequeueConfiguredReusableCell<Cell, Item>(using registration: CellRegistration<Cell, Item>, for indexPath: IndexPath, item: Item?) -> Cell {
        register(Cell.self, forCellWithReuseIdentifier: registration.reuseIdentifier)
        let cell = dequeueReusableCell(withReuseIdentifier: registration.reuseIdentifier, for: indexPath) as! Cell
        if let item { registration.handler(cell, indexPath, item) }
        return cell
    }
    public func dequeueConfiguredReusableSupplementary<Supplementary>(using registration: SupplementaryRegistration<Supplementary>, for indexPath: IndexPath) -> Supplementary {
        register(Supplementary.self, forSupplementaryViewOfKind: registration.elementKind, withReuseIdentifier: registration.reuseIdentifier)
        let view = dequeueReusableSupplementaryView(ofKind: registration.elementKind, withReuseIdentifier: registration.reuseIdentifier, for: indexPath) as! Supplementary
        registration.handler(view, registration.elementKind, indexPath)
        return view
    }
}

// MARK: - List cell accessories (a struct in Swift, ObjC objects underneath)
public struct UICellAccessory {
    public typealias DisplayedState = __UICellAccessory.DisplayedState
    public enum LayoutDimension: Equatable { case standard, actual, custom(CGFloat) }
    /// Options shared by the accessory kinds (each kind reads the fields it has on iOS).
    public struct _Options {
        public var isHidden: Bool?
        public var reservedLayoutWidth: LayoutDimension?
        public var tintColor: UIColor?
        public var backgroundColor: UIColor?
        public var font: UIFont?
        public init(isHidden: Bool? = nil, reservedLayoutWidth: LayoutDimension? = nil, tintColor: UIColor? = nil, backgroundColor: UIColor? = nil, font: UIFont? = nil) {
            self.isHidden = isHidden; self.reservedLayoutWidth = reservedLayoutWidth; self.tintColor = tintColor; self.backgroundColor = backgroundColor; self.font = font
        }
        /// the reorder grip's line next to the content (isim: stored)
        public var showsVerticalSeparator: Bool = true
    }
    public typealias InsertOptions = _Options
    public typealias MultiselectOptions = _Options
    public typealias PopUpMenuOptions = _Options
    public typealias ActionHandler = () -> Void
    public typealias MenuSelectedElementDidChangeHandler = (UIMenu) -> Void
    /// what kind of accessory it is
    public enum AccessoryType: Hashable { case disclosureIndicator, outlineDisclosure, checkmark, delete, insert, reorder, multiselect, detail, popUpMenu, label, customView }
    public var accessoryType: AccessoryType {
        switch object {
        case is __UICellAccessoryDisclosureIndicator: return .disclosureIndicator
        case is __UICellAccessoryOutlineDisclosure: return .outlineDisclosure
        case is __UICellAccessoryCheckmark: return .checkmark
        case is __UICellAccessoryDelete: return .delete
        case is __UICellAccessoryInsert: return .insert
        case is __UICellAccessoryReorder: return .reorder
        case is __UICellAccessoryMultiselect: return .multiselect
        case is __UICellAccessoryDetail: return .detail
        case is __UICellAccessoryPopUpMenu: return .popUpMenu
        case is __UICellAccessoryLabel: return .label
        default: return .customView
        }
    }
    public var displayedState: DisplayedState { object.displayedState }
    public typealias DisclosureIndicatorOptions = _Options
    public typealias CheckmarkOptions = _Options
    public typealias DetailOptions = _Options
    public typealias DeleteOptions = _Options
    public typealias ReorderOptions = _Options
    public typealias OutlineDisclosureOptions = _Options
    public typealias LabelOptions = _Options
    public enum Placement { case leading(displayed: DisplayedState = .always), trailing(displayed: DisplayedState = .always) }
    public struct CustomViewConfiguration {
        public var customView: UIView
        public var placement: Placement
        public var isHidden: Bool?
        public var reservedLayoutWidth: LayoutDimension?
        public var tintColor: UIColor?
        public var maintainsFixedSize: Bool?
        public init(customView: UIView, placement: Placement, isHidden: Bool? = nil, reservedLayoutWidth: LayoutDimension? = nil,
                    tintColor: UIColor? = nil, maintainsFixedSize: Bool? = nil) {
            self.customView = customView; self.placement = placement; self.isHidden = isHidden; self.reservedLayoutWidth = reservedLayoutWidth
            self.tintColor = tintColor; self.maintainsFixedSize = maintainsFixedSize
        }
    }
    let object: __UICellAccessory

    static func make(_ o: __UICellAccessory, _ displayed: DisplayedState, _ options: _Options) -> UICellAccessory {
        o.displayedState = displayed
        o.isHidden = options.isHidden ?? false
        o.tintColor = options.tintColor
        return UICellAccessory(object: o)
    }
    public static func disclosureIndicator(displayed: DisplayedState = .always, options: DisclosureIndicatorOptions = .init()) -> UICellAccessory {
        make(__UICellAccessoryDisclosureIndicator(), displayed, options)
    }
    public static func checkmark(displayed: DisplayedState = .always, options: CheckmarkOptions = .init()) -> UICellAccessory {
        make(__UICellAccessoryCheckmark(), displayed, options)
    }
    public static func detail(displayed: DisplayedState = .always, options: DetailOptions = .init(), actionHandler: (() -> Void)? = nil) -> UICellAccessory {
        let o = __UICellAccessoryDetail(); o.actionHandler = actionHandler; return make(o, displayed, options)
    }
    public static func delete(displayed: DisplayedState = .whenEditing, options: DeleteOptions = .init(), actionHandler: (() -> Void)? = nil) -> UICellAccessory {
        let o = __UICellAccessoryDelete(); o.actionHandler = actionHandler; return make(o, displayed, options)
    }
    public static func reorder(displayed: DisplayedState = .whenEditing, options: ReorderOptions = .init()) -> UICellAccessory {
        make(__UICellAccessoryReorder(), displayed, options)
    }
    public static func outlineDisclosure(displayed: DisplayedState = .always, options: OutlineDisclosureOptions = .init(), actionHandler: (() -> Void)? = nil) -> UICellAccessory {
        let o = __UICellAccessoryOutlineDisclosure(); o.actionHandler = actionHandler; return make(o, displayed, options)
    }
    public static func insert(displayed: DisplayedState = .whenEditing, options: InsertOptions = .init(), actionHandler: ActionHandler? = nil) -> UICellAccessory {
        let o = __UICellAccessoryInsert(); o.actionHandler = actionHandler; o.backgroundColor = options.backgroundColor; return make(o, displayed, options)
    }
    public static func multiselect(displayed: DisplayedState = .whenEditing, options: MultiselectOptions = .init()) -> UICellAccessory {
        let o = __UICellAccessoryMultiselect(); o.backgroundColor = options.backgroundColor; return make(o, displayed, options)
    }
    /// the selected item of a menu, with up / down chevrons; a tap shows the menu, choosing an item selects it
    public static func popUpMenu(_ menu: UIMenu, displayed: DisplayedState = .always, options: PopUpMenuOptions = .init(),
                                 selectedElementDidChangeHandler: MenuSelectedElementDidChangeHandler? = nil) -> UICellAccessory {
        let o = __UICellAccessoryPopUpMenu(menu: menu); o.selectedElementDidChangeHandler = selectedElementDidChangeHandler; return make(o, displayed, options)
    }
    public static func label(text: String, displayed: DisplayedState = .always, options: LabelOptions = .init()) -> UICellAccessory {
        make(__UICellAccessoryLabel(text: text), displayed, options)
    }
    public static func customView(configuration c: CustomViewConfiguration) -> UICellAccessory {
        let displayed: DisplayedState, placement: Int
        switch c.placement { case .leading(let d): displayed = d; placement = 0; case .trailing(let d): displayed = d; placement = 1 }
        return make(__UICellAccessoryCustomView(customView: c.customView, placement: placement), displayed, _Options(isHidden: c.isHidden, tintColor: c.tintColor))
    }
}
extension UICollectionViewListCell {
    public var accessories: [UICellAccessory] {
        get { __accessories.map { UICellAccessory(object: $0) } }
        set { __accessories = newValue.map(\.object) }
    }
}

// MARK: - Collection view diffable data source
@MainActor
open class UICollectionViewDiffableDataSource<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable>: NSObject, @preconcurrency UICollectionViewDataSource {
    public typealias CellProvider = (UICollectionView, IndexPath, ItemIdentifierType) -> UICollectionViewCell?
    public typealias SupplementaryViewProvider = (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    weak var _collectionView: UICollectionView?
    let _cellProvider: CellProvider
    var _snapshot = NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()
    var _sectionSnapshots: [SectionIdentifierType: NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>] = [:]
    open var supplementaryViewProvider: SupplementaryViewProvider?

    /// outline expansion: asked and told when the user expands or collapses a row (its outline disclosure)
    public struct SectionSnapshotHandlers<ItemType: Hashable> {
        public var shouldExpandItem: ((ItemType) -> Bool)?
        public var willExpandItem: ((ItemType) -> Void)?
        public var shouldCollapseItem: ((ItemType) -> Bool)?
        public var willCollapseItem: ((ItemType) -> Void)?
        public var snapshotForExpandingParent: ((ItemType, NSDiffableDataSourceSectionSnapshot<ItemType>) -> NSDiffableDataSourceSectionSnapshot<ItemType>)?
        public init() {}
    }
    open var sectionSnapshotHandlers = SectionSnapshotHandlers<ItemIdentifierType>()
    /// interactive reordering (the list's reorder accessory): allowed per item, then reported with the transaction
    public struct ReorderingHandlers {
        public var canReorderItem: ((ItemIdentifierType) -> Bool)?
        public var willReorder: ((NSDiffableDataSourceTransaction<SectionIdentifierType, ItemIdentifierType>) -> Void)?
        public var didReorder: ((NSDiffableDataSourceTransaction<SectionIdentifierType, ItemIdentifierType>) -> Void)?
        public init() {}
    }
    open var reorderingHandlers = ReorderingHandlers()

    public init(collectionView: UICollectionView, cellProvider: @escaping CellProvider) {
        _collectionView = collectionView; _cellProvider = cellProvider
        super.init()
        collectionView.dataSource = self
    }
    open func snapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> { var s = _snapshot; s._reloaded = []; return s }
    open func apply(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true,
                    completion: (() -> Void)? = nil) {
        // a full snapshot replaces the outlines whose sections now show other items
        for (sec, ss) in _sectionSnapshots where snapshot._items[sec] != ss.visibleItems { _sectionSnapshots[sec] = nil }
        _applyFull(snapshot, animatingDifferences: animatingDifferences, completion: completion)
    }
    func _applyFull(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool,
                    completion: (() -> Void)?) {
        let old = _snapshot
        _snapshot = snapshot; _snapshot._reloaded = []
        guard let cv = _collectionView else { completion?(); return }
        if animatingDifferences, let ch = snapshot._changes(from: old) {
            cv.performBatchUpdates({
                cv.deleteItems(at: ch.deletes)
                cv.insertItems(at: ch.inserts)
            }, completion: { _ in completion?() })
            if !ch.reloads.isEmpty { cv.reconfigureItems(at: ch.reloads) }
        } else {
            cv.reloadData(); completion?()
        }
    }
    open func applySnapshotUsingReloadData(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, completion: (() -> Void)? = nil) {
        apply(snapshot, animatingDifferences: false, completion: completion)
    }
    /// iOS 15: the async forms finish when the changes have been applied
    open func apply(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in apply(snapshot, animatingDifferences: animatingDifferences) { c.resume() } }
    }
    open func applySnapshotUsingReloadData(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in applySnapshotUsingReloadData(snapshot) { c.resume() } }
    }
    open func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? { _snapshot._item(at: indexPath) }
    open func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? { _snapshot._indexPath(of: itemIdentifier) }
    open func sectionIdentifier(for index: Int) -> SectionIdentifierType? { index < _snapshot._sections.count ? _snapshot._sections[index] : nil }
    open func index(for sectionIdentifier: SectionIdentifierType) -> Int? { _snapshot._sections.firstIndex(of: sectionIdentifier) }

    // MARK: section snapshots (outlines)
    /// shows the section's visible items (the roots and the children of expanded parents)
    open func apply(_ snapshot: NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>, to section: SectionIdentifierType,
                    animatingDifferences: Bool = true, completion: (() -> Void)? = nil) {
        var full = _snapshot
        if full._items[section] == nil { full.appendSections([section]) }
        full._items[section] = snapshot.visibleItems
        _applyKeeping(full, outline: (section, snapshot), animating: animatingDifferences, completion: completion)
    }
    open func apply(_ snapshot: NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>, to section: SectionIdentifierType, animatingDifferences: Bool = true) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in apply(snapshot, to: section, animatingDifferences: animatingDifferences) { c.resume() } }
    }
    open func snapshot(for section: SectionIdentifierType) -> NSDiffableDataSourceSectionSnapshot<ItemIdentifierType> {
        if let s = _sectionSnapshots[section] { return s }
        var s = NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>(); s.append(_snapshot.itemIdentifiers(inSection: section)); return s
    }
    func _applyKeeping(_ full: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, outline: (SectionIdentifierType, NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>)?,
                       animating: Bool, completion: (() -> Void)?) {
        if let (sec, ss) = outline { _sectionSnapshots[sec] = ss }
        _applyFull(full, animatingDifferences: animating, completion: completion)
    }
    /// where the row is in its section's outline: 0 a leaf (or no outline), 1 collapsed, 2 expanded
    @objc(_isim_outlineStateAt:) func _isimOutlineState(at ip: IndexPath) -> Int {
        guard let item = itemIdentifier(for: ip), let sec = sectionIdentifier(for: ip.section), let ss = _sectionSnapshots[sec],
              !(ss._children[item] ?? []).isEmpty else { return 0 }
        return ss.isExpanded(item) ? 2 : 1
    }
    /// the outline disclosure: expand or collapse the row (sectionSnapshotHandlers decide and hear about it)
    @objc(_isim_toggleOutlineAt:) func _isimToggleOutline(at ip: IndexPath) {
        guard let item = itemIdentifier(for: ip), let sec = sectionIdentifier(for: ip.section), var ss = _sectionSnapshots[sec] else { return }
        let h = sectionSnapshotHandlers
        if ss.isExpanded(item) {
            if h.shouldCollapseItem?(item) == false { return }
            h.willCollapseItem?(item)
            ss.collapse([item])
        } else {
            if h.shouldExpandItem?(item) == false { return }
            h.willExpandItem?(item)
            if let make = h.snapshotForExpandingParent { ss.replace(childrenOf: item, using: make(item, ss.snapshot(of: item))) }
            ss.expand([item])
        }
        apply(ss, to: sec, animatingDifferences: true)
    }

    // MARK: reordering (the reorder accessory)
    open func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        guard let can = reorderingHandlers.canReorderItem, let item = itemIdentifier(for: indexPath) else { return false }
        return can(item)
    }
    open func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard let item = itemIdentifier(for: sourceIndexPath), destinationIndexPath.section < _snapshot._sections.count else { return }
        let initial = _snapshot
        var final = _snapshot
        let fromSec = final._sections[sourceIndexPath.section], toSec = final._sections[destinationIndexPath.section]
        final._items[fromSec]!.remove(at: sourceIndexPath.item)
        final._items[toSec]!.insert(item, at: min(destinationIndexPath.item, final._items[toSec]!.count))
        var sections: [NSDiffableDataSourceSectionTransaction<SectionIdentifierType, ItemIdentifierType>] = []
        for sec in Set([fromSec, toSec]) {
            var a = NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>(), b = a
            a.append(initial.itemIdentifiers(inSection: sec)); b.append(final.itemIdentifiers(inSection: sec))
            sections.append(.init(sectionIdentifier: sec, initialSnapshot: a, finalSnapshot: b,
                                  difference: final.itemIdentifiers(inSection: sec).difference(from: initial.itemIdentifiers(inSection: sec))))
        }
        let t = NSDiffableDataSourceTransaction(initialSnapshot: initial, finalSnapshot: final,
                                                difference: final.itemIdentifiers.difference(from: initial.itemIdentifiers), sectionTransactions: sections)
        reorderingHandlers.willReorder?(t)
        _snapshot = final                                  // the list already shows the move
        for sec in Set([fromSec, toSec]) where _sectionSnapshots[sec] != nil {
            var ss = NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>(); ss.append(final.itemIdentifiers(inSection: sec)); _sectionSnapshots[sec] = ss
        }
        reorderingHandlers.didReorder?(t)
    }

    open func numberOfSections(in collectionView: UICollectionView) -> Int { _snapshot.numberOfSections }
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        _snapshot.numberOfItems(inSection: _snapshot._sections[section])
    }
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let item = _snapshot._item(at: indexPath), let cell = _cellProvider(collectionView, indexPath, item) else {
            fatalError("UICollectionViewDiffableDataSource cell provider returned nil for index path \(indexPath)")
        }
        if let list = cell as? UICollectionViewListCell, let sec = sectionIdentifier(for: indexPath.section), let ss = _sectionSnapshots[sec] {
            list.indentationLevel = ss.level(of: item)         // outline rows indent by their level
        }
        return cell
    }
    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let v = supplementaryViewProvider?(collectionView, kind, indexPath) else {
            fatalError("UICollectionViewDiffableDataSource: no supplementary view for \(kind) at \(indexPath) (set supplementaryViewProvider)")
        }
        return v
    }
}

// MARK: - Rotation
extension UIWindowScene.GeometryPreferences {
    /// `UIWindowScene.GeometryPreferences.iOS(interfaceOrientations:)` (the importer cannot nest this class two levels deep)
    public typealias iOS = UIWindowSceneGeometryPreferencesIOS
    /// Mac preferences (requesting them on iOS fails with UISceneError.geometryRequestUnsupported)
    public typealias Mac = UIWindowSceneGeometryPreferencesMac
}
/// the scene errors as a Swift error type (`catch let e as UISceneError`, `e.code == .multipleScenesNotSupported`)
public struct UISceneError: CustomNSError, Hashable, _ObjectiveCBridgeableError {
    public typealias Code = UISceneErrorCode
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == UISceneErrorDomain, let c = Code(rawValue: e.code) else { return nil }
        self.init(c)
    }
    public static var errorDomain: String { UISceneErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var multipleScenesNotSupported: Code { .multipleScenesNotSupported }
    public static var requestDenied: Code { .requestDenied }
    public static var geometryRequestUnsupported: Code { .geometryRequestUnsupported }
    public static var geometryRequestDenied: Code { .geometryRequestDenied }
}
extension UIApplication {
    /// errors of `isDefault(_:)`
    @available(iOS 18.2, *)
    public struct CategoryDefaultError: CustomNSError, Hashable, _ObjectiveCBridgeableError {
        public typealias Code = UIApplicationCategoryDefaultErrorCode
        public let code: Code
        public init(_ code: Code) { self.code = code }
        public init?(_bridgedNSError e: __shared NSError) {
            guard e.domain == UIApplicationCategoryDefaultErrorDomain, let c = Code(rawValue: e.code) else { return nil }
            self.init(c)
        }
        public static var errorDomain: String { UIApplicationCategoryDefaultErrorDomain }
        public var errorCode: Int { code.rawValue }
        public static var rateLimited: Code { .rateLimited }
        public nonisolated static let statusLastProvidedDateErrorKey: String = UIApplicationCategoryDefaultStatusLastProvidedDateErrorKey
        public nonisolated static let retryAvailableDateErrorKey: String = UIApplicationCategoryDefaultRetryAvailabilityDateErrorKey
    }
    /// whether the app is the default one of the category (Objective-C: -defaultStatusForCategory:error:)
    @available(iOS 18.2, *)
    public func isDefault(_ category: UIApplication.Category) throws -> Bool {
        var error: NSError?
        let status = __defaultStatus(for: category, error: &error)
        if status == .unavailable { throw error ?? NSError(domain: UIApplicationCategoryDefaultErrorDomain, code: 0) }
        return status == .isDefault
    }
}
@available(iOS 17.0, *)
extension UIWindowScene.ActivationAction {
    /// the identifier and the alternate action are optional (Apple's defaults)
    public convenience init(alternate: UIAction? = nil, configuration: @escaping UIWindowScene.ActivationAction.ConfigurationProvider) {
        self.init(identifier: nil, alternate: alternate, configuration: configuration)
    }
    public convenience init(alternate: UIAction? = nil, configuration: @escaping UIWindowScene.ActivationAction.ConfigurationProvider, errorHandler: ((any Error) -> Void)?) {
        self.init(identifier: nil, alternate: alternate, configuration: configuration, errorHandler: errorHandler)
    }
}
/// where a new window scene appears (iPadOS 17): prominent takes the screen, standard goes beside the others
@available(iOS 17.0, *)
public protocol UIWindowScenePlacement: Hashable {}
@available(iOS 17.0, *)
public struct UIWindowSceneStandardPlacement: UIWindowScenePlacement { public init() {} }
@available(iOS 17.0, *)
public struct UIWindowSceneProminentPlacement: UIWindowScenePlacement { public init() {} }
@available(iOS 17.0, *)
extension UIWindowScenePlacement where Self == UIWindowSceneStandardPlacement { public static var standard: Self { .init() } }
@available(iOS 17.0, *)
extension UIWindowScenePlacement where Self == UIWindowSceneProminentPlacement { public static var prominent: Self { .init() } }
@available(iOS 17.0, *)
extension UIWindowScene.ActivationRequestOptions {
    /// isim: the placement is the presentation style (prominent: the whole screen; standard: side by side)
    public var placement: (any UIWindowScenePlacement)? {
        get {
            switch preferredPresentationStyle {
            case .prominent: return UIWindowSceneProminentPlacement()
            case .standard: return UIWindowSceneStandardPlacement()
            default: return nil
            }
        }
        set {
            preferredPresentationStyle = newValue is UIWindowSceneProminentPlacement ? .prominent : newValue is UIWindowSceneStandardPlacement ? .standard : .automatic
        }
    }
}
extension UIDeviceOrientation {
    public var isPortrait: Bool { self == .portrait || self == .portraitUpsideDown }
    public var isLandscape: Bool { self == .landscapeLeft || self == .landscapeRight }
    public var isFlat: Bool { self == .faceUp || self == .faceDown }
    public var isValidInterfaceOrientation: Bool { isPortrait || isLandscape }
}
extension UIInterfaceOrientation {
    public var isPortrait: Bool { self == .portrait || self == .portraitUpsideDown }
    public var isLandscape: Bool { self == .landscapeLeft || self == .landscapeRight }
}

// MARK: - Buttons (Swift default arguments from Apple's UIKit overlay)
extension UIButton {
    public convenience init(configuration: UIButton.Configuration, primaryAction: UIAction? = nil) {
        self.init(__configuration: configuration._bridgeToObjectiveC(), primaryAction: primaryAction)
    }
    /// the button's configuration (a value: change it and set it back, or change it in place)
    public var configuration: UIButton.Configuration? {
        get { __configuration.map { UIButton.Configuration(_o: $0.copy() as! __UIButtonConfiguration) } }
        set { __configuration = newValue?._bridgeToObjectiveC() }
    }
    /// init(type: .system, primaryAction:): Apple's default button type
    public convenience init(primaryAction: UIAction?) { self.init(type: .system, primaryAction: primaryAction) }
}

// MARK: - Page view controllers (options: nil by default, as in Apple's SDK)
extension UIPageViewController {
    public convenience init(transitionStyle style: UIPageViewController.TransitionStyle, navigationOrientation: UIPageViewController.NavigationOrientation) {
        self.init(transitionStyle: style, navigationOrientation: navigationOrientation, options: nil)
    }
}

// MARK: - Core Animation (QuartzCore names live in isim's UIKit; import QuartzCore re-exports them)
extension CATransform3D: Equatable {
    public static func == (a: CATransform3D, b: CATransform3D) -> Bool { CATransform3DEqualToTransform(a, b) }
}
extension CATransform3D: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(caTransform3D: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CATransform3D?) { result = x.caTransform3DValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CATransform3D?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CATransform3D") else { return false }
        result = x.caTransform3DValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CATransform3D { s?.caTransform3DValue ?? CATransform3DIdentity }
}
extension CGAffineTransform: @retroactive _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(cgAffineTransform: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CGAffineTransform?) { result = x.cgAffineTransformValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CGAffineTransform?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CGAffineTransform") else { return false }
        result = x.cgAffineTransformValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CGAffineTransform { s?.cgAffineTransformValue ?? .identity }
}
extension CGVector: @retroactive _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(cgVector: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CGVector?) { result = x.cgVectorValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CGVector?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CGVector") else { return false }
        result = x.cgVectorValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CGVector { s?.cgVectorValue ?? CGVector(dx: 0, dy: 0) }
}
extension CAMediaTimingFunction {
    /// Apple's Swift spelling: CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1).
    public convenience init(controlPoints c1x: Float, _ c1y: Float, _ c2x: Float, _ c2y: Float) {
        self.init(__controlPoints: c1x, c1y, c2x, c2y)
    }
}
// MARK: - Trait change registration (iOS 17): see UIKit+Traits.swift. These are the entry points of isim 0.7 and
// earlier (traits were the Objective-C protocol, now _UITraitDefinitionObjC), kept for apps built with them.
extension UIView {
    @usableFromInline @discardableResult
    internal func registerForTraitChanges<T: UITraitEnvironment>(_ traits: [any _UITraitDefinitionObjC.Type], handler: @escaping (T, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        __register(forTraitChanges: traits.map { $0 as AnyClass }, withHandler: { env, previous in handler(env as! T, previous) })
    }
}
extension UIViewController {
    @usableFromInline @discardableResult
    internal func registerForTraitChanges<T: UITraitEnvironment>(_ traits: [any _UITraitDefinitionObjC.Type], handler: @escaping (T, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        __register(forTraitChanges: traits.map { $0 as AnyClass }, withHandler: { env, previous in handler(env as! T, previous) })
    }
}

// MARK: - Storyboards (UIKit Swift overlay API): creator blocks get the coder so `init?(coder:)` can take extra arguments
extension UIStoryboard {
    public func instantiateInitialViewController<ViewController: UIViewController>(creator: ((NSCoder) -> ViewController?)? = nil) -> ViewController? {
        guard let creator else { return __instantiateInitialViewController(creator: nil) as? ViewController }
        return __instantiateInitialViewController(creator: { creator($0) }) as? ViewController
    }
    public func instantiateViewController<ViewController: UIViewController>(identifier: String, creator: ((NSCoder) -> ViewController?)? = nil) -> ViewController {
        let vc: UIViewController
        if let creator { vc = __instantiateViewController(withIdentifier: identifier, creator: { creator($0) }) }
        else { vc = __instantiateViewController(withIdentifier: identifier, creator: nil) }
        guard let typed = vc as? ViewController else { fatalError("Storyboard view controller '\(identifier)' is not a \(ViewController.self)") }
        return typed
    }
}

// MARK: - iOS 26 bar button item badges (Apple's Swift spelling)
@available(iOS 26.0, *)
extension UIBarButtonItem.Badge {
    public static func count(_ count: Int) -> UIBarButtonItem.Badge { _isim_count(count) }
    public static func string(_ string: String) -> UIBarButtonItem.Badge { _isim_string(string) }
    public static func indicator() -> UIBarButtonItem.Badge { _isim_indicator() }
}

// MARK: - iOS 26 navigation item titles and subtitles as AttributedString (Apple's Swift API)
@available(iOS 26.0, *)
extension UINavigationItem {
    public var attributedTitle: AttributedString? {
        get { __attributedTitle.map { AttributedString($0) } }
        set { __attributedTitle = newValue.map { NSAttributedString($0) } }
    }
    public var attributedSubtitle: AttributedString? {
        get { __attributedSubtitle.map { AttributedString($0) } }
        set { __attributedSubtitle = newValue.map { NSAttributedString($0) } }
    }
    public var largeAttributedSubtitle: AttributedString? {
        get { __largeAttributedSubtitle.map { AttributedString($0) } }
        set { __largeAttributedSubtitle = newValue.map { NSAttributedString($0) } }
    }
}

// MARK: - The UIKit attribute scope for AttributedString (NSAttributedString keys: NSColor, NSFont, ...)
extension AttributeScopes {
    public var uiKit: UIKitAttributes.Type { UIKitAttributes.self }
    public struct UIKitAttributes: AttributeScope {
        public let foregroundColor: ForegroundColorAttribute
        public let backgroundColor: BackgroundColorAttribute
        public let font: FontAttribute
        public let kern: KernAttribute
        public let baselineOffset: BaselineOffsetAttribute
        public let paragraphStyle: ParagraphStyleAttribute
        public let foundation: AttributeScopes.FoundationAttributes
        public enum ForegroundColorAttribute: AttributedStringKey { public typealias Value = UIColor; public static let name = "NSColor" }
        public enum BackgroundColorAttribute: AttributedStringKey { public typealias Value = UIColor; public static let name = "NSBackgroundColor" }
        public enum FontAttribute: AttributedStringKey { public typealias Value = UIFont; public static let name = "NSFont" }
        public enum KernAttribute: AttributedStringKey { public typealias Value = CGFloat; public static let name = "NSKern" }
        public enum BaselineOffsetAttribute: AttributedStringKey { public typealias Value = CGFloat; public static let name = "NSBaselineOffset" }
        public enum ParagraphStyleAttribute: AttributedStringKey { public typealias Value = NSParagraphStyle; public static let name = "NSParagraphStyle" }
    }
}
extension AttributeDynamicLookup {
    /// disfavoured: in SwiftUI code `.foregroundColor` / `.font` mean SwiftUI's attributes
    @_disfavoredOverload
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.UIKitAttributes, T>) -> T { self[T.self] }
}

// MARK: - iOS 18 preferred transitions (Apple's Swift spelling)
@available(iOS 18.0, *)
extension UIViewController.Transition {
    public typealias ZoomOptions = UIZoomTransitionOptions
    public typealias ZoomSourceViewProviderContext = UIZoomTransitionSourceViewProviderContext
    public static func zoom(options: ZoomOptions? = nil, sourceViewProvider: @escaping (ZoomSourceViewProviderContext) -> UIView?) -> UIViewController.Transition {
        __zoom(with: options, sourceViewProvider: sourceViewProvider)
    }
}

// MARK: - iOS 27 bars: bar minimization as a value type, visibility priorities relative to others (Apple's Swift API)
@available(iOS 27.0, *)
public struct UIBarMinimization: Hashable, Sendable {
    public var minimizationBehavior: UIBarMinimizationBehavior = .automatic
    public var restorationBehavior: UIBarMinimizationRestorationBehavior = .automatic
    public var safeAreaAdjustment: UIBarMinimizationSafeAreaAdjustment = .automatic
    public init() {}
}
@available(iOS 27.0, *)
extension UINavigationItem {
    public var navigationBarMinimization: UIBarMinimization {
        get {
            let o = __navigationBarMinimization
            var m = UIBarMinimization()
            m.minimizationBehavior = o.minimizationBehavior; m.restorationBehavior = o.restorationBehavior; m.safeAreaAdjustment = o.safeAreaAdjustment
            return m
        }
        set {
            let o = _UIBarMinimizationObjC()
            o.minimizationBehavior = newValue.minimizationBehavior; o.restorationBehavior = newValue.restorationBehavior; o.safeAreaAdjustment = newValue.safeAreaAdjustment
            __navigationBarMinimization = o
        }
    }
}
@available(iOS 27.0, *)
extension UIBarButtonItemVisibilityPriority {
    public init(higherThan other: UIBarButtonItemVisibilityPriority) { self.init(rawValue: other.rawValue + 1) }
    public init(lowerThan other: UIBarButtonItemVisibilityPriority) { self.init(rawValue: other.rawValue - 1) }
}
@available(iOS 18.0, *)
extension UITabBarController.Sidebar {
    public typealias Delegate = UITabBarControllerSidebarDelegate
    public typealias Animating = UITabBarControllerSidebarAnimating
}
// MARK: - iOS 27 scene display links with a closure (Apple's Swift API)
private final class _IsimDisplayLinkAction: NSObject {
    let action: @Sendable (CADisplayLink) -> Void
    init(_ action: @escaping @Sendable (CADisplayLink) -> Void) { self.action = action }
    @objc func fire(_ link: CADisplayLink) { action(link) }
}
@available(iOS 27.0, *)
extension UIWindowScene {
    public func displayLink(action: @escaping @Sendable (CADisplayLink) -> Void) -> CADisplayLink? {
        let target = _IsimDisplayLinkAction(action)
        return displayLink(target: target, selector: #selector(_IsimDisplayLinkAction.fire(_:)))   // (the link retains it)
    }
}

// MARK: - UIViewController.ViewLoading and the content scroll view for all edges
extension UIViewController {
    /// A property loaded with the view: reading or writing it loads the view first (`@ViewLoading var label: UILabel`).
    @propertyWrapper
    public struct ViewLoading<Value> {
        private var stored: Value?
        public init() { stored = nil }
        @available(*, unavailable, message: "@ViewLoading is only available on UIViewController properties")
        public var wrappedValue: Value {
            get { fatalError() }
            set { fatalError() }
        }
        @MainActor public static subscript<T: UIViewController>(
            _enclosingInstance instance: T,
            wrapped wrappedKeyPath: ReferenceWritableKeyPath<T, Value>,
            storage storageKeyPath: ReferenceWritableKeyPath<T, ViewLoading<Value>>
        ) -> Value {
            get {
                instance.loadViewIfNeeded()
                guard let v = instance[keyPath: storageKeyPath].stored else {
                    fatalError("@ViewLoading property read before it was set while loading the view")
                }
                return v
            }
            set {
                instance.loadViewIfNeeded()
                instance[keyPath: storageKeyPath].stored = newValue
            }
        }
    }
    /// the scroll view the bars follow at every edge
    @available(iOS 15.0, *)
    public func setContentScrollView(_ scrollView: UIScrollView?) { setContentScrollView(scrollView, for: .all) }
}

// Customizable bar button item groups (iOS 16): the defaults of Apple's Swift signatures
@available(iOS 16.0, *)
extension UIBarButtonItem {
    public func creatingOptionalGroup(customizationIdentifier: String, isInDefaultCustomization: Bool = true) -> UIBarButtonItemGroup {
        __creatingOptionalGroup(customizationIdentifier: customizationIdentifier, isInDefaultCustomization: isInDefaultCustomization)
    }
}
@available(iOS 16.0, *)
extension UIBarButtonItemGroup {
    public class func fixedGroup(representativeItem: UIBarButtonItem? = nil, items: [UIBarButtonItem]) -> UIBarButtonItemGroup {
        __fixedGroup(representativeItem: representativeItem, items: items)
    }
    public class func movableGroup(customizationIdentifier: String, representativeItem: UIBarButtonItem? = nil, items: [UIBarButtonItem]) -> UIBarButtonItemGroup {
        __movableGroup(customizationIdentifier: customizationIdentifier, representativeItem: representativeItem, items: items)
    }
    public class func optionalGroup(customizationIdentifier: String, isInDefaultCustomization: Bool = true, representativeItem: UIBarButtonItem? = nil,
                                    items: [UIBarButtonItem]) -> UIBarButtonItemGroup {
        __optionalGroup(customizationIdentifier: customizationIdentifier, isInDefaultCustomization: isInDefaultCustomization,
                        representativeItem: representativeItem, items: items)
    }
}

// UIFontPickerViewController.Configuration.languageFilter (iOS 18): the families whose languages match
@available(iOS 18.0, *)
extension UIFontPickerViewController.Configuration {
    public var languageFilter: Predicate<[String]>? {
        get { __isimLanguageFilterValue as? Predicate<[String]> }
        set {
            __isimLanguageFilterValue = newValue
            __isimLanguageFilter = newValue.map { p in { languages in (try? p.evaluate(languages)) ?? false } }
        }
    }
}

/// the document browser's errors as a Swift error type (`catch let e as UIDocumentBrowserError`)
public struct UIDocumentBrowserError: CustomNSError, Hashable, _ObjectiveCBridgeableError {
    public typealias Code = UIDocumentBrowserErrorCode
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == UIDocumentBrowserErrorDomain, let c = Code(rawValue: e.code) else { return nil }
        self.init(c)
    }
    public static var errorDomain: String { UIDocumentBrowserErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var generic: Code { .generic }
    public static var noLocationAvailable: Code { .noLocationAvailable }
}

// MARK: - UIView.Invalidating: a property whose change invalidates an aspect of its view (iOS 15)
/// An aspect of a view that a change makes invalid (`.layout`, `.display`, `.constraints`, `.intrinsicContentSize`,
/// `.configuration`).
public protocol UIViewInvalidating {
    @MainActor func invalidate(view: UIView)
}
extension UIView {
    public enum Invalidations {
        public struct Layout: UIViewInvalidating { public init() {}; @MainActor public func invalidate(view: UIView) { view.setNeedsLayout() } }
        public struct Display: UIViewInvalidating { public init() {}; @MainActor public func invalidate(view: UIView) { view.setNeedsDisplay() } }
        public struct Constraints: UIViewInvalidating { public init() {}; @MainActor public func invalidate(view: UIView) { view.setNeedsUpdateConstraints() } }
        public struct IntrinsicContentSize: UIViewInvalidating { public init() {}; @MainActor public func invalidate(view: UIView) { view.invalidateIntrinsicContentSize() } }
        /// cells, buttons and other views with configurations update them
        public struct Configuration: UIViewInvalidating {
            public init() {}
            @MainActor public func invalidate(view: UIView) {
                let sel = NSSelectorFromString("setNeedsUpdateConfiguration")
                if view.responds(to: sel) { _ = view.perform(sel) }
            }
        }
        /// iOS 26: the view's updateProperties runs before the next layout
        @available(iOS 26.0, *)
        public struct Properties: UIViewInvalidating { public init() {}; @MainActor public func invalidate(view: UIView) { view.setNeedsUpdateProperties() } }
        public struct Tuple<Invalidation1: UIViewInvalidating, Invalidation2: UIViewInvalidating>: UIViewInvalidating {
            let first: Invalidation1, second: Invalidation2
            public init(_ first: Invalidation1, _ second: Invalidation2) { self.first = first; self.second = second }
            @MainActor public func invalidate(view: UIView) { first.invalidate(view: view); second.invalidate(view: view) }
        }
    }
    /// `@UIView.Invalidating(.layout, .display) var spacing: CGFloat = 8`: setting a different value invalidates them
    @propertyWrapper
    public struct Invalidating<Value: Equatable, InvalidationType: UIViewInvalidating> {
        private var value: Value
        private let invalidation: InvalidationType
        public init(wrappedValue: Value, _ invalidation: InvalidationType) { value = wrappedValue; self.invalidation = invalidation }
        public init<I1, I2>(wrappedValue: Value, _ i1: I1, _ i2: I2) where InvalidationType == Invalidations.Tuple<I1, I2> {
            self.init(wrappedValue: wrappedValue, Invalidations.Tuple(i1, i2))
        }
        public init<I1, I2, I3>(wrappedValue: Value, _ i1: I1, _ i2: I2, _ i3: I3) where InvalidationType == Invalidations.Tuple<Invalidations.Tuple<I1, I2>, I3> {
            self.init(wrappedValue: wrappedValue, Invalidations.Tuple(Invalidations.Tuple(i1, i2), i3))
        }
        public init<I1, I2, I3, I4>(wrappedValue: Value, _ i1: I1, _ i2: I2, _ i3: I3, _ i4: I4)
            where InvalidationType == Invalidations.Tuple<Invalidations.Tuple<Invalidations.Tuple<I1, I2>, I3>, I4> {
            self.init(wrappedValue: wrappedValue, Invalidations.Tuple(Invalidations.Tuple(Invalidations.Tuple(i1, i2), i3), i4))
        }
        @available(*, unavailable, message: "@Invalidating is only available on UIView properties")
        public var wrappedValue: Value {
            get { fatalError() }
            set { fatalError() }
        }
        @MainActor public static subscript<T: UIView>(
            _enclosingInstance view: T,
            wrapped wrappedKeyPath: ReferenceWritableKeyPath<T, Value>,
            storage storageKeyPath: ReferenceWritableKeyPath<T, Invalidating<Value, InvalidationType>>
        ) -> Value {
            get { view[keyPath: storageKeyPath].value }
            set {
                let old = view[keyPath: storageKeyPath].value
                view[keyPath: storageKeyPath].value = newValue
                if old != newValue { view[keyPath: storageKeyPath].invalidation.invalidate(view: view) }
            }
        }
    }
}
extension UIViewInvalidating where Self == UIView.Invalidations.Layout { public static var layout: Self { .init() } }
extension UIViewInvalidating where Self == UIView.Invalidations.Display { public static var display: Self { .init() } }
extension UIViewInvalidating where Self == UIView.Invalidations.Constraints { public static var constraints: Self { .init() } }
extension UIViewInvalidating where Self == UIView.Invalidations.IntrinsicContentSize { public static var intrinsicContentSize: Self { .init() } }
extension UIViewInvalidating where Self == UIView.Invalidations.Configuration { public static var configuration: Self { .init() } }
@available(iOS 26.0, *)
extension UIViewInvalidating where Self == UIView.Invalidations.Properties { public static var properties: Self { .init() } }

// MARK: - Configuration transformers (Apple's Swift value types over the Objective-C blocks)
@available(iOS 15.0, *)
public struct UIConfigurationTextAttributesTransformer {
    public let transform: (AttributeContainer) -> AttributeContainer
    public init(_ transform: @escaping (AttributeContainer) -> AttributeContainer) { self.transform = transform }
    public func callAsFunction(_ input: AttributeContainer) -> AttributeContainer { transform(input) }
    init(_isim block: @escaping __UIConfigurationTextAttributesTransformer) {
        transform = { c in AttributeContainer(block(_isimTextAttributes(c))) }
    }
    var _isimBlock: __UIConfigurationTextAttributesTransformer {
        let t = transform
        return { d in _isimTextAttributes(t(AttributeContainer(d))) }
    }
}
private func _isimTextAttributes(_ c: AttributeContainer) -> [NSAttributedString.Key: Any] {
    let s = NSAttributedString(AttributedString(" ", attributes: c))
    return s.attributes(at: 0, effectiveRange: nil)
}
@available(iOS 14.0, *)
public struct UIConfigurationColorTransformer {
    public let transform: (UIColor) -> UIColor
    public init(_ transform: @escaping (UIColor) -> UIColor) { self.transform = transform }
    public func callAsFunction(_ input: UIColor) -> UIColor { transform(input) }
    public static let grayscale = UIConfigurationColorTransformer(__UIConfigurationColorTransformerGrayscale)
    public static let preferredTint = UIConfigurationColorTransformer(__UIConfigurationColorTransformerPreferredTint)
    public static let monochromeTint = UIConfigurationColorTransformer(__UIConfigurationColorTransformerMonochromeTint)
}
// MARK: - Control event handlers (Apple's Swift signature)
extension UIControl {
    @available(iOS 14.0, *)
    public func enumerateEventHandlers(_ iterator: (_ actionHandler: UIAction?, _ targetAction: (Any?, Selector)?, _ controlEvents: UIControl.Event, _ stop: inout Bool) -> Void) {
        withoutActuallyEscaping(iterator) { it in
            __enumerateEventHandlers { action, target, sel, events, stop in
                var s = false
                it(action, sel.map { (target, $0) }, events, &s)
                if s { stop.pointee = true }
            }
        }
    }
}

// MARK: - Calendar view decorations (Apple's Swift spellings, with their default arguments)
@available(iOS 16.0, *)
extension UICalendarView.Decoration {
    public class func `default`(color: UIColor? = nil, size: UICalendarView.DecorationSize = .medium) -> Self { __default(color: color, size: size) }
    public class func image(_ image: UIImage?, color: UIColor? = nil, size: UICalendarView.DecorationSize = .medium) -> Self { __image(image, color: color, size: size) }
}


// MARK: - Configuration colour transformers and states (Apple's Swift spellings)
extension UIListContentConfiguration.TextProperties {
    public var colorTransformer: UIConfigurationColorTransformer? {
        get { __colorTransformer.map { UIConfigurationColorTransformer($0) } }
        set { __colorTransformer = newValue.map { t in { t($0) } } }
    }
}
extension UIListContentConfiguration.ImageProperties {
    public var tintColorTransformer: UIConfigurationColorTransformer? {
        get { __tintColorTransformer.map { UIConfigurationColorTransformer($0) } }
        set { __tintColorTransformer = newValue.map { t in { t($0) } } }
    }
    @available(iOS 18.0, *)
    public var strokeColorTransformer: UIConfigurationColorTransformer? {
        get { __strokeColorTransformer.map { UIConfigurationColorTransformer($0) } }
        set { __strokeColorTransformer = newValue.map { t in { t($0) } } }
    }
}
extension UIBackgroundConfiguration {
    public var backgroundColorTransformer: UIConfigurationColorTransformer? {
        get { __backgroundColorTransformer.map { UIConfigurationColorTransformer($0) } }
        set { __backgroundColorTransformer = newValue.map { t in { t($0) } } }
    }
    public var strokeColorTransformer: UIConfigurationColorTransformer? {
        get { __strokeColorTransformer.map { UIConfigurationColorTransformer($0) } }
        set { __strokeColorTransformer = newValue.map { t in { t($0) } } }
    }
}
extension UIContentUnavailableConfiguration {
    public typealias ButtonProperties = UIContentUnavailableButtonProperties
    public typealias TextProperties = UIContentUnavailableTextProperties
    public typealias ImageProperties = UIContentUnavailableImageProperties
}
/// a key for an app's own values in a configuration state (`state[key]`)
public struct UIConfigurationStateCustomKey: Hashable, RawRepresentable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

// MARK: - UITextView multiple selection (iOS 26; isim keeps one range)
@available(iOS 26.0, *)
extension UITextView {
    public var selectedRanges: [NSRange] {
        get { __selectedRanges.map { $0.rangeValue } }
        set { __selectedRanges = newValue.map { NSValue(range: $0) } }
    }
}

// MARK: - Text highlights (iOS 18): the style and colour scheme values (nested in NSAttributedString's types)
@available(iOS 18.0, *)
extension NSAttributedString.TextHighlightStyle {
    public static var `default`: Self { Self(rawValue: "NSTextHighlightStyleDefault") }
}
@available(iOS 18.0, *)
extension NSAttributedString.TextHighlightColorScheme {
    public static var `default`: Self { Self(rawValue: "NSTextHighlightColorSchemeDefault") }
    public static var purple: Self { Self(rawValue: "NSTextHighlightColorSchemePurple") }
    public static var pink: Self { Self(rawValue: "NSTextHighlightColorSchemePink") }
    public static var orange: Self { Self(rawValue: "NSTextHighlightColorSchemeOrange") }
    public static var mint: Self { Self(rawValue: "NSTextHighlightColorSchemeMint") }
    public static var blue: Self { Self(rawValue: "NSTextHighlightColorSchemeBlue") }
}

// MARK: - Find (iOS 16): the searchable protocol and its aggregator under their Swift names (isim: the Objective-C
// protocols; document identifiers are Any?, not a generic DocumentIdentifier)
@available(iOS 16.0, *)
public typealias UITextSearching = __UITextSearching
@available(iOS 16.0, *)
public typealias UITextSearchAggregator = __UITextSearchAggregator

// MARK: - UIButton.Configuration: a value type, as on iOS (issue #487)
// The Objective-C UIButtonConfiguration (__UIButtonConfiguration in Swift) holds the values the button renders; the
// struct keeps one as copy-on-write storage and bridges to it (UIButton.configuration, init(configuration:), ...).
extension UIButton {
    @MainActor @preconcurrency
    public struct Configuration: Hashable {
        public typealias CornerStyle = __UIButtonConfiguration.CornerStyle
        public typealias Size = __UIButtonConfiguration.Size
        public typealias TitleAlignment = __UIButtonConfiguration.TitleAlignment
        public typealias Indicator = __UIButtonConfiguration.Indicator
        public typealias MacIdiomStyle = __UIButtonConfiguration.MacIdiomStyle
        var _o: __UIButtonConfiguration
        init(_o: __UIButtonConfiguration) { self._o = _o }
        /// the storage, copied first when another configuration value shares it
        mutating func _mutable() -> __UIButtonConfiguration {
            if !isKnownUniquelyReferenced(&_o) { _o = _o.copy() as! __UIButtonConfiguration }
            return _o
        }

        public static func plain() -> Configuration { Configuration(_o: .plain()) }
        public static func tinted() -> Configuration { Configuration(_o: .tinted()) }
        public static func gray() -> Configuration { Configuration(_o: .gray()) }
        public static func filled() -> Configuration { Configuration(_o: .filled()) }
        public static func borderless() -> Configuration { Configuration(_o: .borderless()) }
        public static func bordered() -> Configuration { Configuration(_o: .bordered()) }
        public static func borderedTinted() -> Configuration { Configuration(_o: .borderedTinted()) }
        public static func borderedProminent() -> Configuration { Configuration(_o: .borderedProminent()) }
        @available(iOS 26.0, *) public static func glass() -> Configuration { Configuration(_o: .glass()) }
        @available(iOS 26.0, *) public static func prominentGlass() -> Configuration { Configuration(_o: .prominentGlass()) }
        @available(iOS 26.0, *) public static func clearGlass() -> Configuration { Configuration(_o: .clearGlass()) }
        @available(iOS 26.0, *) public static func prominentClearGlass() -> Configuration { Configuration(_o: .prominentClearGlass()) }

        public var title: String? { get { _o.title } set { _mutable().title = newValue } }
        public var subtitle: String? { get { _o.subtitle } set { _mutable().subtitle = newValue } }
        public var image: UIImage? { get { _o.image } set { _mutable().image = newValue } }
        public var baseForegroundColor: UIColor? { get { _o.baseForegroundColor } set { _mutable().baseForegroundColor = newValue } }
        public var baseBackgroundColor: UIColor? { get { _o.baseBackgroundColor } set { _mutable().baseBackgroundColor = newValue } }
        public var cornerStyle: CornerStyle { get { _o.cornerStyle } set { _mutable().cornerStyle = newValue } }
        public var buttonSize: Size { get { _o.buttonSize } set { _mutable().buttonSize = newValue } }
        public var contentInsets: NSDirectionalEdgeInsets { get { _o.contentInsets } set { _mutable().contentInsets = newValue } }
        public var imagePadding: CGFloat { get { _o.imagePadding } set { _mutable().imagePadding = newValue } }
        public var imageReservation: CGFloat { get { _o.imageReservation } set { _mutable().imageReservation = newValue } }
        public var titlePadding: CGFloat { get { _o.titlePadding } set { _mutable().titlePadding = newValue } }
        public var imagePlacement: NSDirectionalRectEdge { get { _o.imagePlacement } set { _mutable().imagePlacement = newValue } }
        public var titleAlignment: TitleAlignment { get { _o.titleAlignment } set { _mutable().titleAlignment = newValue } }
        public var showsActivityIndicator: Bool { get { _o.showsActivityIndicator } set { _mutable().showsActivityIndicator = newValue } }
        public var automaticallyUpdateForSelection: Bool { get { _o.automaticallyUpdateForSelection } set { _mutable().automaticallyUpdateForSelection = newValue } }
        public var titleLineBreakMode: NSLineBreakMode { get { _o.titleLineBreakMode } set { _mutable().titleLineBreakMode = newValue } }
        public var subtitleLineBreakMode: NSLineBreakMode { get { _o.subtitleLineBreakMode } set { _mutable().subtitleLineBreakMode = newValue } }
        public var indicator: Indicator { get { _o.indicator } set { _mutable().indicator = newValue } }
        public var macIdiomStyle: MacIdiomStyle { get { _o.macIdiomStyle } set { _mutable().macIdiomStyle = newValue } }
        public var preferredSymbolConfigurationForImage: UIImage.SymbolConfiguration? { get { _o.preferredSymbolConfigurationForImage } set { _mutable().preferredSymbolConfigurationForImage = newValue } }
        @available(iOS 26.0, *)
        public var symbolContentTransition: UISymbolContentTransition? { get { _o.symbolContentTransition } set { _mutable().symbolContentTransition = newValue } }
        public var attributedTitle: AttributedString? {
            get { _o.__attributedTitle.map { AttributedString($0) } }
            set { _mutable().__attributedTitle = newValue.map { NSAttributedString($0) } }
        }
        public var attributedSubtitle: AttributedString? {
            get { _o.__attributedSubtitle.map { AttributedString($0) } }
            set { _mutable().__attributedSubtitle = newValue.map { NSAttributedString($0) } }
        }
        public var titleTextAttributesTransformer: UIConfigurationTextAttributesTransformer? {
            get { _o.__titleTextAttributesTransformer.map { UIConfigurationTextAttributesTransformer(_isim: $0) } }
            set { _mutable().__titleTextAttributesTransformer = newValue?._isimBlock }
        }
        public var subtitleTextAttributesTransformer: UIConfigurationTextAttributesTransformer? {
            get { _o.__subtitleTextAttributesTransformer.map { UIConfigurationTextAttributesTransformer(_isim: $0) } }
            set { _mutable().__subtitleTextAttributesTransformer = newValue?._isimBlock }
        }
        public var imageColorTransformer: UIConfigurationColorTransformer? {
            get { _o.__imageColorTransformer.map { UIConfigurationColorTransformer($0) } }
            set { _mutable().__imageColorTransformer = newValue.map { t in { t($0) } } }
        }
        public var indicatorColorTransformer: UIConfigurationColorTransformer? {
            get { _o.__indicatorColorTransformer.map { UIConfigurationColorTransformer($0) } }
            set { _mutable().__indicatorColorTransformer = newValue.map { t in { t($0) } } }
        }
        public var activityIndicatorColorTransformer: UIConfigurationColorTransformer? {
            get { _o.__activityIndicatorColorTransformer.map { UIConfigurationColorTransformer($0) } }
            set { _mutable().__activityIndicatorColorTransformer = newValue.map { t in { t($0) } } }
        }
        /// the content insets for the configuration's style and size
        public mutating func setDefaultContentInsets() { _mutable().setDefaultContentInsets() }

        // Hashable: by the values the configuration shows (the closures and transformers compare by presence)
        nonisolated var _key: [AnyHashable?] {
            nonisolated(unsafe) var key: [AnyHashable?] = []
            MainActor.assumeIsolated { key =  {
                [title, subtitle, image, baseForegroundColor, baseBackgroundColor, cornerStyle.rawValue, buttonSize.rawValue,
                 contentInsets.top, contentInsets.leading, contentInsets.bottom, contentInsets.trailing, imagePadding,
                 imageReservation, titlePadding, imagePlacement.rawValue, titleAlignment.rawValue, showsActivityIndicator,
                 automaticallyUpdateForSelection, indicator.rawValue, preferredSymbolConfigurationForImage,
                 _o.__attributedTitle, _o.__attributedSubtitle, _o.__titleTextAttributesTransformer != nil,
                 _o.__imageColorTransformer != nil] }()
            }
            return key
        }
        nonisolated public static func == (a: Configuration, b: Configuration) -> Bool { a._o === b._o || a._key == b._key }
        nonisolated public func hash(into h: inout Hasher) { h.combine(_key) }
    }
}
extension UIButton.Configuration: _ObjectiveCBridgeable {
    public typealias _ObjectiveCType = __UIButtonConfiguration
    nonisolated public func _bridgeToObjectiveC() -> __UIButtonConfiguration { MainActor.assumeIsolated { _o.copy() as! __UIButtonConfiguration } }
    nonisolated public static func _forceBridgeFromObjectiveC(_ o: __UIButtonConfiguration, result: inout UIButton.Configuration?) {
        result = MainActor.assumeIsolated { UIButton.Configuration(_o: o.copy() as! __UIButtonConfiguration) }
    }
    nonisolated public static func _conditionallyBridgeFromObjectiveC(_ o: __UIButtonConfiguration, result: inout UIButton.Configuration?) -> Bool {
        _forceBridgeFromObjectiveC(o, result: &result); return true
    }
    nonisolated public static func _unconditionallyBridgeFromObjectiveC(_ o: __UIButtonConfiguration?) -> UIButton.Configuration {
        MainActor.assumeIsolated { UIButton.Configuration(_o: (o ?? .plain()).copy() as! __UIButtonConfiguration) }
    }
}
extension UIContentUnavailableConfiguration {
    /// the primary button's configuration (a value, as on iOS; plain() until set)
    public var button: UIButton.Configuration {
        get { UIButton.Configuration(_o: (__button ?? .plain()).copy() as! __UIButtonConfiguration) }
        set { __button = newValue._bridgeToObjectiveC() }
    }
    public var secondaryButton: UIButton.Configuration {
        get { UIButton.Configuration(_o: (__secondaryButton ?? .plain()).copy() as! __UIButtonConfiguration) }
        set { __secondaryButton = newValue._bridgeToObjectiveC() }
    }
}

@available(iOS 17.0, *)
extension UIApplication {
    /// Activates a scene session without an error handler (Apple's default `errorHandler: nil`).
    public func activateSceneSession(for request: UISceneSessionActivationRequest) { activateSceneSession(for: request, errorHandler: nil) }
}
// MARK: - CAFrameRateRange (QuartzCore's Swift API)
@available(iOS 15.0, *)
extension CAFrameRateRange {
    /// A range with no preferred rate (`preferred` nil) leaves the choice inside it to the system.
    public init(minimum: Float, maximum: Float, preferred: Float? = nil) {
        self = __CAFrameRateRangeMake(minimum, maximum, preferred ?? 0)
    }
}
