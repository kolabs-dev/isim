// isim UIKit overlay (self-authored): what Swift apps need beyond the imported ObjC API.
@_exported import UIKit

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
}
extension UIApplication.OpenURLOptionsKey {
    public static var sourceApplication: UIApplication.OpenURLOptionsKey { UIApplication.OpenURLOptionsKey(rawValue: "UIApplicationOpenURLOptionsSourceApplicationKey") }
    public static var openInPlace: UIApplication.OpenURLOptionsKey { UIApplication.OpenURLOptionsKey(rawValue: "UIApplicationOpenURLOptionsOpenInPlaceKey") }
}
extension UIApplication.OpenExternalURLOptionsKey {
    public static var universalLinksOnly: UIApplication.OpenExternalURLOptionsKey { UIApplication.OpenExternalURLOptionsKey(rawValue: "UIApplicationOpenURLOptionUniversalLinksOnly") }
}

// MARK: - Geometry conveniences (UIKit Swift overlay API)
extension UIEdgeInsets: Equatable {
    public static var zero: UIEdgeInsets { UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    public static func == (a: UIEdgeInsets, b: UIEdgeInsets) -> Bool { a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right }
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
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: String? = nil,
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        self.init(__title: title, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle,
                  attributes: attributes, state: state, handler: handler)
        self.subtitle = subtitle
    }
}
extension UIMenu {
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: String? = nil,
                            options: UIMenu.Options = [], children: [UIMenuElement] = []) {
        self.init(__title: title, image: image, identifier: identifier, options: options, children: children)
        self.subtitle = subtitle
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
    public init() {}
    public var numberOfSections: Int { _sections.count }
    public var numberOfItems: Int { _sections.reduce(0) { $0 + (_items[$1]?.count ?? 0) } }
    public var sectionIdentifiers: [SectionIdentifierType] { _sections }
    public var itemIdentifiers: [ItemIdentifierType] { _sections.flatMap { _items[$0] ?? [] } }
    public var reloadedItemIdentifiers: [ItemIdentifierType] { Array(_reloaded) }
    public var reconfiguredItemIdentifiers: [ItemIdentifierType] { Array(_reloaded) }
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
    public mutating func reloadSections(_ ids: [SectionIdentifierType]) { for s in ids { _reloaded.formUnion(_items[s] ?? []) } }
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
    public mutating func deleteAllItems() { _sections = []; _items = [:]; _reloaded = [] }
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
open class UITableViewDiffableDataSource<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable>: NSObject, UITableViewDataSource {
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
    }
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
open class UICollectionViewDiffableDataSource<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable>: NSObject, UICollectionViewDataSource {
    public typealias CellProvider = (UICollectionView, IndexPath, ItemIdentifierType) -> UICollectionViewCell?
    public typealias SupplementaryViewProvider = (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    weak var _collectionView: UICollectionView?
    let _cellProvider: CellProvider
    var _snapshot = NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()
    open var supplementaryViewProvider: SupplementaryViewProvider?

    public init(collectionView: UICollectionView, cellProvider: @escaping CellProvider) {
        _collectionView = collectionView; _cellProvider = cellProvider
        super.init()
        collectionView.dataSource = self
    }
    open func snapshot() -> NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> { var s = _snapshot; s._reloaded = []; return s }
    open func apply(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true,
                    completion: (() -> Void)? = nil) {
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
    open func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? { _snapshot._item(at: indexPath) }
    open func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? { _snapshot._indexPath(of: itemIdentifier) }
    open func sectionIdentifier(for index: Int) -> SectionIdentifierType? { index < _snapshot._sections.count ? _snapshot._sections[index] : nil }
    open func index(for sectionIdentifier: SectionIdentifierType) -> Int? { _snapshot._sections.firstIndex(of: sectionIdentifier) }

    open func numberOfSections(in collectionView: UICollectionView) -> Int { _snapshot.numberOfSections }
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        _snapshot.numberOfItems(inSection: _snapshot._sections[section])
    }
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let item = _snapshot._item(at: indexPath), let cell = _cellProvider(collectionView, indexPath, item) else {
            fatalError("UICollectionViewDiffableDataSource cell provider returned nil for index path \(indexPath)")
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
    public convenience init(configuration: UIButton.Configuration) { self.init(configuration: configuration, primaryAction: nil) }
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
extension CGAffineTransform: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(cgAffineTransform: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CGAffineTransform?) { result = x.cgAffineTransformValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CGAffineTransform?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CGAffineTransform") else { return false }
        result = x.cgAffineTransformValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CGAffineTransform { s?.cgAffineTransformValue ?? .identity }
}
extension CGVector: _ObjectiveCBridgeable {
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
        __register(forTraitChanges: traits.map { $0 as! AnyClass }, withHandler: { env, previous in handler(env as! T, previous) })
    }
}
extension UIViewController {
    @usableFromInline @discardableResult
    internal func registerForTraitChanges<T: UITraitEnvironment>(_ traits: [any _UITraitDefinitionObjC.Type], handler: @escaping (T, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        __register(forTraitChanges: traits.map { $0 as! AnyClass }, withHandler: { env, previous in handler(env as! T, previous) })
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

// MARK: - Button configurations: attributed titles as AttributedString (Apple's Swift API)
extension UIButton.Configuration {
    public var attributedTitle: AttributedString? {
        get { __attributedTitle.map { AttributedString($0) } }
        set { __attributedTitle = newValue.map { NSAttributedString($0) } }
    }
    public var attributedSubtitle: AttributedString? {
        get { __attributedSubtitle.map { AttributedString($0) } }
        set { __attributedSubtitle = newValue.map { NSAttributedString($0) } }
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
