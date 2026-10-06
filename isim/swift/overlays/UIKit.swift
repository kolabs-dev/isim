// isim UIKit overlay (self-authored): what Swift apps need beyond the imported ObjC API.
@_exported import UIKit

extension UIApplicationDelegate {
  /// Entry point for `@main` app delegates (same contract as Apple's UIKit overlay).
  public static func main() {
    UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(self))
  }
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
