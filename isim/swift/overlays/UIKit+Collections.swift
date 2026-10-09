// isim UIKit overlay: content configurations and outlines (self-authored).
// UIContentConfiguration / UIContentView are Swift protocols here, as in Apple's UIKit: a custom configuration (a
// struct) makes its content view and is boxed for the ObjC cells, which install that view in their contentView and
// re-derive it with updated(for:) when the cell's state changes. NSDiffableDataSourceSectionSnapshot holds a section's
// outline (items with children, expanded or collapsed); the diffable data source shows its visible items.
import ObjectiveC

// MARK: - configuration states
public protocol UIConfigurationState {
    var traitCollection: UITraitCollection { get set }
}
public struct UIViewConfigurationState: UIConfigurationState, Hashable {
    public var traitCollection: UITraitCollection
    public var isDisabled = false, isHighlighted = false, isSelected = false, isFocused = false, isPinned = false
    public init(traitCollection: UITraitCollection) { self.traitCollection = traitCollection }
}
public struct UICellConfigurationState: UIConfigurationState, Hashable {
    public var traitCollection: UITraitCollection
    public var isDisabled = false, isHighlighted = false, isSelected = false, isFocused = false, isPinned = false
    public var isEditing = false, isSwiped = false, isExpanded = false, isReordering = false
    public init(traitCollection: UITraitCollection) { self.traitCollection = traitCollection }
    init(_isim d: [String: Any]) {
        traitCollection = d["traits"] as? UITraitCollection ?? UITraitCollection.current
        isSelected = d["selected"] as? Bool ?? false; isHighlighted = d["highlighted"] as? Bool ?? false
        isEditing = d["editing"] as? Bool ?? false; isSwiped = d["swiped"] as? Bool ?? false
        isExpanded = d["expanded"] as? Bool ?? false; isDisabled = d["disabled"] as? Bool ?? false
    }
}

// MARK: - content configurations
public protocol UIContentConfiguration {
    @MainActor func makeContentView() -> UIView & UIContentView
    func updated(for state: UIConfigurationState) -> Self
}
@MainActor public protocol UIContentView: NSObjectProtocol {
    var configuration: UIContentConfiguration { get set }
    func supports(_ configuration: UIContentConfiguration) -> Bool
}
extension UIContentView {
    public func supports(_ configuration: UIContentConfiguration) -> Bool { true }
}

/// a Swift configuration as the ObjC object the cells hold
@objc(_IsimContentConfigurationBox)
final class _IsimContentConfigurationBox: NSObject, @preconcurrency __UIContentConfiguration, NSCopying {
    let value: UIContentConfiguration
    init(_ value: UIContentConfiguration) { self.value = value }
    func copy(with zone: NSZone? = nil) -> Any { self }
    @MainActor @objc func makeContentView() -> UIView { value.makeContentView() }
    @MainActor @objc(_isimApplyTo:) func _isimApply(to view: UIView) -> Bool {
        guard let cv = view as? (UIView & UIContentView), type(of: cv.configuration) == type(of: value) || cv.supports(value), cv.supports(value) else { return false }
        cv.configuration = value
        return true
    }
    @objc(_isimUpdatedWithState:) func _isimUpdated(with state: [String: Any]) -> _IsimContentConfigurationBox {
        _IsimContentConfigurationBox(value.updated(for: UICellConfigurationState(_isim: state)))
    }
}
func _isimBox(_ c: UIContentConfiguration?) -> __UIContentConfiguration? {
    guard let c else { return nil }
    if let o = c as? __UIContentConfiguration { return o }           // ObjC configurations (UIListContentConfiguration)
    return _IsimContentConfigurationBox(c)
}
func _isimUnbox(_ o: __UIContentConfiguration?) -> UIContentConfiguration? {
    if let b = o as? _IsimContentConfigurationBox { return b.value }
    return o as? UIContentConfiguration
}

extension UIListContentConfiguration: UIContentConfiguration {
    public func makeContentView() -> UIView & UIContentView { UIListContentView(configuration: self) }
    public func updated(for state: UIConfigurationState) -> Self { self }
}
extension UIListContentView: UIContentView {
    public var configuration: UIContentConfiguration {
        get { __configuration }
        set { if let c = newValue as? UIListContentConfiguration { __configuration = c } }
    }
    public func supports(_ configuration: UIContentConfiguration) -> Bool { configuration is UIListContentConfiguration }
}

extension UICollectionViewCell {
    public var contentConfiguration: UIContentConfiguration? {
        get { _isimUnbox(__contentConfiguration) }
        set { __contentConfiguration = _isimBox(newValue) }
    }
    /// the cell's state, as content configurations see it
    public var configurationState: UICellConfigurationState {
        var s = UICellConfigurationState(traitCollection: traitCollection)
        s.isSelected = isSelected; s.isHighlighted = isHighlighted; s.isDisabled = !isUserInteractionEnabled
        s.isExpanded = (value(forKey: "_isim_expandedState") as? Bool) ?? false
        s.isSwiped = (value(forKey: "_isim_swipedState") as? Bool) ?? false
        return s
    }
}
nonisolated(unsafe) private var isimUpdateHandlerKey: UInt8 = 0
extension UICollectionViewCell {
    public typealias ConfigurationUpdateHandler = (_ cell: UICollectionViewCell, _ state: UICellConfigurationState) -> Void
    /// runs before the next layout whenever the cell's state changes (selection, highlight, editing, …)
    public var configurationUpdateHandler: ConfigurationUpdateHandler? {
        get { (objc_getAssociatedObject(self, &isimUpdateHandlerKey) as? _IsimHandlerBox)?.handler }
        set { objc_setAssociatedObject(self, &isimUpdateHandlerKey, newValue.map(_IsimHandlerBox.init), objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)); setNeedsUpdateConfiguration() }
    }
    @objc func _isimRunConfigurationUpdate() { configurationUpdateHandler?(self, configurationState) }
}
final class _IsimHandlerBox: NSObject {
    let handler: UICollectionViewCell.ConfigurationUpdateHandler
    init(_ h: @escaping UICollectionViewCell.ConfigurationUpdateHandler) { handler = h }
}
extension UITableViewCell {
    public var contentConfiguration: UIContentConfiguration? {
        get { _isimUnbox(__contentConfiguration) }
        set { __contentConfiguration = _isimBox(newValue) }
    }
    public var configurationState: UICellConfigurationState {
        var s = UICellConfigurationState(traitCollection: traitCollection)
        s.isSelected = isSelected; s.isHighlighted = isHighlighted; s.isEditing = isEditing; s.isDisabled = !isUserInteractionEnabled
        return s
    }
}
extension UITableViewHeaderFooterView {
    public var contentConfiguration: UIContentConfiguration? {
        get { _isimUnbox(__contentConfiguration) }
        set { __contentConfiguration = _isimBox(newValue) }
    }
}

// MARK: - section snapshots (outlines)
/// One section's items as an outline: root items, children per parent, and which parents are expanded.
public struct NSDiffableDataSourceSectionSnapshot<ItemIdentifierType: Hashable> {
    var _roots: [ItemIdentifierType] = []
    var _children: [ItemIdentifierType: [ItemIdentifierType]] = [:]
    var _parent: [ItemIdentifierType: ItemIdentifierType] = [:]
    var _expanded: Set<ItemIdentifierType> = []
    public init() {}

    func _childrenOf(_ p: ItemIdentifierType?) -> [ItemIdentifierType] { p.map { _children[$0] ?? [] } ?? _roots }
    mutating func _setChildren(_ c: [ItemIdentifierType], of p: ItemIdentifierType?) { if let p { _children[p] = c.isEmpty ? nil : c } else { _roots = c } }
    func _walk(_ items: [ItemIdentifierType], visibleOnly: Bool, into out: inout [ItemIdentifierType]) {
        for i in items {
            out.append(i)
            if !visibleOnly || _expanded.contains(i) { _walk(_children[i] ?? [], visibleOnly: visibleOnly, into: &out) }
        }
    }
    /// every item, depth first
    public var items: [ItemIdentifierType] { var o: [ItemIdentifierType] = []; _walk(_roots, visibleOnly: false, into: &o); return o }
    public var rootItems: [ItemIdentifierType] { _roots }
    /// the items shown: the roots and the children of expanded parents
    public var visibleItems: [ItemIdentifierType] { var o: [ItemIdentifierType] = []; _walk(_roots, visibleOnly: true, into: &o); return o }
    public func contains(_ item: ItemIdentifierType) -> Bool { _roots.contains(item) || _parent[item] != nil }
    public func parent(of child: ItemIdentifierType) -> ItemIdentifierType? { _parent[child] }
    public func level(of item: ItemIdentifierType) -> Int { var l = 0, i = item; while let p = _parent[i] { l += 1; i = p }; return l }
    public func index(of item: ItemIdentifierType) -> Int? { items.firstIndex(of: item) }
    public func isExpanded(_ item: ItemIdentifierType) -> Bool { _expanded.contains(item) }
    public func isVisible(_ item: ItemIdentifierType) -> Bool {
        guard contains(item) else { return false }
        var i = item; while let p = _parent[i] { if !_expanded.contains(p) { return false }; i = p }
        return true
    }
    public var visualDescription: String {
        items.map { String(repeating: "  ", count: level(of: $0)) + "- \($0)" + (_children[$0] != nil ? (_expanded.contains($0) ? " (expanded)" : " (collapsed)") : "") }.joined(separator: "\n")
    }

    public mutating func append(_ items: [ItemIdentifierType], to parent: ItemIdentifierType? = nil) {
        if let parent, !contains(parent) { fatalError("Invalid parent item identifier \(parent)") }
        _setChildren(_childrenOf(parent) + items, of: parent)
        if let parent { for i in items { _parent[i] = parent } }
    }
    public mutating func insert(_ items: [ItemIdentifierType], before item: ItemIdentifierType) {
        let p = _parent[item]; var c = _childrenOf(p)
        guard let at = c.firstIndex(of: item) else { fatalError("Invalid item identifier \(item)") }
        c.insert(contentsOf: items, at: at); _setChildren(c, of: p)
        if let p { for i in items { _parent[i] = p } }
    }
    public mutating func insert(_ items: [ItemIdentifierType], after item: ItemIdentifierType) {
        let p = _parent[item]; var c = _childrenOf(p)
        guard let at = c.firstIndex(of: item) else { fatalError("Invalid item identifier \(item)") }
        c.insert(contentsOf: items, at: at + 1); _setChildren(c, of: p)
        if let p { for i in items { _parent[i] = p } }
    }
    public mutating func append(_ snapshot: Self, to parent: ItemIdentifierType? = nil) {
        append(snapshot._roots, to: parent)
        for (p, c) in snapshot._children { _children[p] = c; for i in c { _parent[i] = p } }
        _expanded.formUnion(snapshot._expanded)
    }
    public mutating func insert(_ snapshot: Self, before item: ItemIdentifierType) {
        insert(snapshot._roots, before: item)
        for (p, c) in snapshot._children { _children[p] = c; for i in c { _parent[i] = p } }
        _expanded.formUnion(snapshot._expanded)
    }
    public mutating func insert(_ snapshot: Self, after item: ItemIdentifierType) {
        insert(snapshot._roots, after: item)
        for (p, c) in snapshot._children { _children[p] = c; for i in c { _parent[i] = p } }
        _expanded.formUnion(snapshot._expanded)
    }
    /// removes the items and their descendants
    public mutating func delete(_ items: [ItemIdentifierType]) {
        for item in items where contains(item) {
            var gone: [ItemIdentifierType] = []; _walk([item], visibleOnly: false, into: &gone)
            let p = _parent[item]
            _setChildren(_childrenOf(p).filter { $0 != item }, of: p)
            for g in gone { _children[g] = nil; _parent[g] = nil; _expanded.remove(g) }
        }
    }
    public mutating func deleteAll() { self = Self() }
    public mutating func expand(_ items: [ItemIdentifierType]) { _expanded.formUnion(items.filter(contains)) }
    public mutating func collapse(_ items: [ItemIdentifierType]) { _expanded.subtract(items) }
    public mutating func replace(childrenOf parent: ItemIdentifierType, using snapshot: Self) {
        for c in _children[parent] ?? [] { delete([c]) }
        append(snapshot, to: parent)
    }
    public func snapshot(of parent: ItemIdentifierType, includingParent: Bool = false) -> Self {
        var s = Self()
        if includingParent { s.append([parent]) }
        func copy(_ p: ItemIdentifierType, into: ItemIdentifierType?) {
            let kids = _children[p] ?? []
            s.append(kids, to: into)
            for k in kids { copy(k, into: k) }
        }
        copy(parent, into: includingParent ? parent : nil)
        s._expanded = _expanded.filter { s.contains($0) }
        return s
    }
}

/// a reorder made in the list: the snapshots before and after, and the change
public struct NSDiffableDataSourceTransaction<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable> {
    public let initialSnapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>
    public let finalSnapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>
    public let difference: CollectionDifference<ItemIdentifierType>
    public let sectionTransactions: [NSDiffableDataSourceSectionTransaction<SectionIdentifierType, ItemIdentifierType>]
}
public struct NSDiffableDataSourceSectionTransaction<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable> {
    public let sectionIdentifier: SectionIdentifierType
    public let initialSnapshot: NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>
    public let finalSnapshot: NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>
    public let difference: CollectionDifference<ItemIdentifierType>
}
