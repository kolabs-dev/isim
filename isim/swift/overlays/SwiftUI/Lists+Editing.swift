// isim SwiftUI: list editing and row features — EditMode / `\.editMode` / EditButton, `onDelete`, `onMove`,
// `swipeActions` (leading / trailing, full swipe), `contextMenu` (long press -> menu), `.badge` on rows,
// `List(_:rowContent:)` / `List(selection:)` (single and multiple selection), `.refreshable` (pull to refresh, also on
// ScrollView), and the `isPresented` / `presentationMode` environment values.
// Rows are isim's own list rows (Navigation.swift's _ListNode): swipes slide the row over its action buttons; in edit
// mode rows get delete (minus) buttons, reorder handles and selection circles like UITableView's.
import UIKit

// MARK: - Edit mode

public enum EditMode: Hashable, Sendable {
    case inactive, transient, active
    public var isEditing: Bool { self != .inactive }
}
struct _EditModeKey: EnvironmentKey { static var defaultValue: Binding<EditMode>? { nil } }
extension EnvironmentValues {
    public var editMode: Binding<EditMode>? { get { self[_EditModeKey.self] } set { self[_EditModeKey.self] = newValue } }
}
/// Environment set up for each render's root (called by _Graph.render): the window's edit mode.
@MainActor func _rootEnvironment(_ env: inout EnvironmentValues, _ g: _Graph) {
    let key = "root#editmode"
    let st = (g.storage[key] as? _StateStorage<EditMode>) ?? { let s = _StateStorage(EditMode.inactive); g.storage[key] = s; return s }()
    g.usedKeys.insert(key)
    env.editMode = Binding(get: { st.value }, set: { [weak g] v in if st.value != v { st.value = v; g?.invalidate() } })
}

/// Toggles the environment's edit mode ("Edit" / "Done").
public struct EditButton: View {
    @Environment(\.editMode) var editMode
    public init() {}
    public var body: some View {
        let editing = editMode?.wrappedValue.isEditing == true
        Button(editing ? "Done" : "Edit") {
            withAnimation(.easeInOut(duration: 0.25)) { editMode?.wrappedValue = editing ? .inactive : .active }
        }
        .fontWeight(editing ? .semibold : nil)
    }
}

// MARK: - RenameButton

/// What a RenameButton does: focus a title field, or the app's own action (`.renameAction`).
public struct RenameAction {
    let action: () -> Void
    @MainActor public func callAsFunction() { action() }
}
struct _RenameKey: EnvironmentKey { static var defaultValue: RenameAction? { nil } }
extension EnvironmentValues {
    public var rename: RenameAction? { get { self[_RenameKey.self] } set { self[_RenameKey.self] = newValue } }
}
extension View {
    /// The action of RenameButtons inside (and of an editable navigation title).
    public func renameAction(_ action: @escaping () -> Void) -> some View { _env { $0.rename = RenameAction(action: action) } }
    /// RenameButtons inside focus this field.
    public func renameAction(_ isFocused: FocusState<Bool>.Binding) -> some View { _env { $0.rename = RenameAction { isFocused.wrappedValue = true } } }
}
/// "Rename" (a pencil): runs the environment's rename action; disabled without one.
public struct RenameButton<Label: View>: View {
    @Environment(\.rename) var rename
    let label: Label?
    public var body: some View {
        Button { rename?() } label: {
            if let label { label } else { SwiftUI.Label("Rename", systemImage: "pencil") }
        }
        .disabled(rename == nil)
    }
}
extension RenameButton where Label == SwiftUI.Label<Text, Image> {
    public init() { label = nil }
}

// MARK: - isPresented, presentationMode

struct _IsPresentedKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues {
    /// True inside presented content (sheets, covers) and pushed navigation destinations.
    public var isPresented: Bool { get { self[_IsPresentedKey.self] } set { self[_IsPresentedKey.self] = newValue } }
    public var presentationMode: Binding<PresentationMode> {
        let p = PresentationMode(isPresented: isPresented, dismissAction: dismiss)
        return Binding(get: { p }, set: { _ in })
    }
}
public struct PresentationMode {
    public private(set) var isPresented: Bool
    let dismissAction: DismissAction
    @MainActor public mutating func dismiss() { dismissAction() }
}

// MARK: - Row editing info

public struct _SwipeAction { let title: String; let image: UIImage?; let color: UIColor; let action: () -> Void }

/// Carries a row's edit features (delete, move, swipe actions, context menu) for the List.
final class _RowEditNode: _WrapperNode {
    var delete: (() -> Void)?
    var move: (index: Int, group: String, action: (IndexSet, Int) -> Void)?
    var leading: [_SwipeAction]?, trailing: [_SwipeAction]?
    var fullLeading = true, fullTrailing = true
    /// outside a List (iOS 27 swipe actions on any view): the node swipes itself
    var standalone = false
    var container: _SwipeContainerBox?
    override init(path: String, child: _Node) { super.init(path: path, child: child); tag = child.tag }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        guard standalone, (leading?.isEmpty == false || trailing?.isEmpty == false) else { return g.view(viewKey) { _PassthroughView() } }
        let v = g.view(viewKey + "|swipe") { _SUISwipeHost(frame: .zero) }
        v.leading = leading ?? []; v.trailing = trailing ?? []; v.fullLeading = fullLeading; v.fullTrailing = fullTrailing; v.container = container
        return v
    }
}
@MainActor func _rowEdit(_ n: _Node, path: String) -> _RowEditNode {
    if let e = n as? _RowEditNode { return e }
    return _RowEditNode(path: path, child: n)
}

/// Collection content with a data source (ForEach): onDelete / onMove apply to its rows.
public protocol DynamicViewContent: View {
    associatedtype Data: Collection
    var data: Data { get }
}
extension ForEach: DynamicViewContent where Content: View {}
public struct _EditableContent<Base: DynamicViewContent>: DynamicViewContent, _PrimitiveView {
    let base: Base
    var onDelete: ((IndexSet) -> Void)?
    var onMove: ((IndexSet, Int) -> Void)?
    public var data: Base.Data { base.data }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _resolve(base, ctx)
        let rows = n is _GroupNode ? n.children : [n]
        let edited = rows.enumerated().map { i, r -> _Node in
            let e = _rowEdit(r, path: r.path + "/edit")
            if let d = onDelete { e.delete = { d(IndexSet(integer: i)) } }
            if let m = onMove { e.move = (i, ctx.path, m) }
            return e
        }
        return _GroupNode(path: n.path, children: edited)
    }
}
extension DynamicViewContent {
    /// Swipe to delete (and the delete button in edit mode) for the rows of this ForEach in a List.
    public func onDelete(perform action: ((IndexSet) -> Void)?) -> _EditableContent<Self> { _EditableContent(base: self, onDelete: action, onMove: nil) }
    /// Reordering with the handles shown in edit mode; called with the source indices and the destination (before removal).
    public func onMove(perform action: ((IndexSet, Int) -> Void)?) -> _EditableContent<Self> { _EditableContent(base: self, onDelete: nil, onMove: action) }
    public func onInsert(of types: [Any], perform action: @escaping (Int, [Any]) -> Void) -> Self { self }
}
extension _EditableContent {
    public func onDelete(perform action: ((IndexSet) -> Void)?) -> _EditableContent<Base> { var c = self; c.onDelete = action; return c }
    public func onMove(perform action: ((IndexSet, Int) -> Void)?) -> _EditableContent<Base> { var c = self; c.onMove = action; return c }
}

/// Buttons inside swipeActions / contextMenu content.
@MainActor func _swipeActions(_ n: _Node) -> [_SwipeAction] {
    var out: [_SwipeAction] = []
    func walk(_ x: _Node) {
        if let b = x as? _ButtonNode {
            let color = b.role == .destructive ? UIColor.systemRed : (_firstTextColor(b) ?? .systemGray)
            out.append(_SwipeAction(title: _collectText(b).joined(separator: " "), image: _firstImage(b), color: color, action: b.action))
            return
        }
        for c in x.children { walk(c) }
    }
    walk(n)
    return out
}
@MainActor func _firstTextColor(_ n: _Node) -> UIColor? {
    if let t = n as? _TextNode { return t.color }
    if let r = n as? _RichTextNode { return r.runs.first?.color }
    for c in n.children { if let col = _firstTextColor(c) { return col } }
    return nil
}

extension View {
    public func swipeActions<T: View>(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T) -> some View {
        let actions = content()
        return _modify { ctx, c in
            let n = _resolve(c, ctx.child("swipe"))
            // buttons without their own tint are grey (iOS's default swipe action colour)
            let list = _swipeActions(_resolve(actions, ctx.child("swipe-actions").with { $0._inList = false; $0._tint = Color("swipe-default") { .systemGray } }))
            let e = _rowEdit(n, path: ctx.path + "/edit")
            if !ctx.environment._inList { e.standalone = true; e.container = ctx.environment._swipeContainer }      // any view (iOS 27)
            if edge == .leading { e.leading = (e.leading ?? []) + list; e.fullLeading = allowsFullSwipe }
            else { e.trailing = (e.trailing ?? []) + list; e.fullTrailing = allowsFullSwipe }
            return e
        }
    }
}

// MARK: - Context menu

final class _ContextMenuNode: _WrapperNode {
    let build: () -> UIMenu
    var preview: (() -> UIView)?
    init(path: String, build: @escaping () -> UIMenu, child: _Node) { self.build = build; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIContextMenuHost(frame: .zero) }
        v.build = build; v.preview = preview
        return v
    }
}
/// Long press shows the menu (anchored to the view).
final class _SUIContextMenuHost: UIView {
    var build: (() -> UIMenu)?
    var preview: (() -> UIView)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        lp.minimumPressDuration = 0.5
        addGestureRecognizer(lp)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled, self.point(inside: point, with: event) else { return nil }
        return super.hitTest(point, with: event) ?? self
    }
    @objc func pressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let menu = build?() else { return }
        if let p = preview?() { _isim_present(menu, from: bounds, preview: p) } else { _isim_present(menu, from: bounds) }
    }
}
extension View {
    public func contextMenu<M: View>(@ViewBuilder menuItems: () -> M) -> some View {
        let items = menuItems()
        return _modify { ctx, c in
            let content = _resolve(items, ctx.child("ctxmenu-items").with { $0._inList = false })
            return _ContextMenuNode(path: ctx.path, build: { UIMenu(title: "", children: _menuElements(content)) }, child: _resolve(c, ctx.child("ctxmenu")))
        }
    }
    /// Long press: the preview (instead of the view) lifted over a dimmed screen, with the menu under it.
    public func contextMenu<M: View, P: View>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View {
        let items = menuItems(), pv = AnyView(preview())
        return _modify { ctx, c in
            let content = _resolve(items, ctx.child("ctxmenu-items").with { $0._inList = false })
            let n = _ContextMenuNode(path: ctx.path, build: { UIMenu(title: "", children: _menuElements(content)) }, child: _resolve(c, ctx.child("ctxmenu")))
            let env = ctx.environment
            n.preview = { _contextPreviewView(pv, env) }
            return n
        }
    }
}

// MARK: - Row info for the List

struct _RowInfo {
    var delete: (() -> Void)?
    var move: (index: Int, group: String, action: (IndexSet, Int) -> Void)?
    var leading: [_SwipeAction] = [], trailing: [_SwipeAction] = []
    var fullLeading = true, fullTrailing = true
    var contextMenu: (() -> UIMenu)?
    var contextPreview: (() -> UIView)?
    var badge: String?
    var tag: AnyHashable?
}
@MainActor func _rowInfo(_ row: _Node) -> _RowInfo {
    var info = _RowInfo()
    var x: _Node? = row
    while let n = x {
        if let e = n as? _RowEditNode {
            if info.delete == nil { info.delete = e.delete }
            if info.move == nil { info.move = e.move }
            if let l = e.leading { info.leading += l; info.fullLeading = e.fullLeading }
            if let t = e.trailing { info.trailing += t; info.fullTrailing = e.fullTrailing }
        }
        if let c = n as? _ContextMenuNode, info.contextMenu == nil { info.contextMenu = c.build; info.contextPreview = c.preview }
        if info.badge == nil { info.badge = n.badge }
        if info.tag == nil { info.tag = n.tag }
        x = n.children.count == 1 && !(n is _StackNode) ? n.children[0] : nil
    }
    if info.trailing.isEmpty, let d = info.delete {
        info.trailing = [_SwipeAction(title: "Delete", image: nil, color: .systemRed, action: d)]
    }
    return info
}

// MARK: - List selection, data initializers

/// List(selection:): which rows (by tag / ForEach id) are selected.
struct _ListSelection {
    let multi: Bool
    let isSelected: (AnyHashable) -> Bool
    let select: (AnyHashable) -> Void
}
struct _ListSelectionKey: EnvironmentKey { static var defaultValue: _ListSelection? { nil } }
struct _SplitAdvanceKey: EnvironmentKey { static var defaultValue: (() -> Void)? { nil } }
extension EnvironmentValues {
    var _listSelection: _ListSelection? { get { self[_ListSelectionKey.self] } set { self[_ListSelectionKey.self] = newValue } }
    /// NavigationSplitView (compact): selecting in a column shows the next one.
    var _splitAdvance: (() -> Void)? { get { self[_SplitAdvanceKey.self] } set { self[_SplitAdvanceKey.self] = newValue } }
}
extension List {
    public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {
        self.content = content()
        if let s = selection {
            _selection = _ListSelection(multi: false, isSelected: { s.wrappedValue.map(AnyHashable.init) == $0 },
                                        select: { if let v = $0.base as? SelectionValue { s.wrappedValue = v } })
        }
    }
    public init(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> Content) {
        self.content = content()
        if let s = selection {
            _selection = _ListSelection(multi: true, isSelected: { ($0.base as? SelectionValue).map { s.wrappedValue.contains($0) } ?? false },
                                        select: { if let v = $0.base as? SelectionValue { if s.wrappedValue.contains(v) { s.wrappedValue.remove(v) } else { s.wrappedValue.insert(v) } } })
        }
    }
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?,
                                                                               @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, ID, RowContent> {
        self.init(selection: selection) { ForEach(data, id: id, content: rowContent) }
    }
}
extension List where SelectionValue == Never {
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init { ForEach(data, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, ID, RowContent> {
        self.init { ForEach(data, id: id, content: rowContent) }
    }
    public init<RowContent: View>(_ data: Range<Int>, @ViewBuilder rowContent: @escaping (Int) -> RowContent) where Content == ForEach<Range<Int>, Int, RowContent> {
        self.init { ForEach(data, content: rowContent) }
    }
}

// MARK: - List extras (set by _makeList, used by _ListNode)

struct _ListExtras {
    var editing = false
    var selection: _ListSelection?
    var refresh: RefreshAction?
    var advance: (() -> Void)?
    var search: _SearchConfig?
}
@MainActor func _listExtras(_ ctx: _Context) -> _ListExtras {
    var x = _ListExtras()
    x.editing = ctx.environment.editMode?.wrappedValue.isEditing == true
    x.selection = ctx.environment._listSelection
    x.refresh = ctx.environment.refresh
    x.advance = ctx.environment._splitAdvance
    return x
}
/// Extra room a row's content gives up in edit mode: (leading for delete / selection controls, trailing for the reorder handle).
@MainActor func _rowEditInsets(_ row: _Node, _ x: _ListExtras) -> (CGFloat, CGFloat) {
    guard x.editing else { return (0, 0) }
    let info = _rowInfo(row)
    let lead: CGFloat = info.delete != nil || (x.selection?.multi == true && info.tag != nil) ? 38 : 0
    return (lead, info.move != nil ? 40 : 0)
}

/// Adds the row's extras: badge, edit controls, selection, swipe actions, context menu.
@MainActor func _configureListRow(_ row: _SUIRowControl, _ node: _Node, index: Int, rowHeight: CGFloat, list: _ListNode, _ g: _Graph) {
    guard let row = row as? _SUIListRow else { return }
    let x = list.extras
    let info = _rowInfo(node)
    row.list = list
    row.leadingActions = x.editing ? [] : info.leading
    row.trailingActions = x.editing ? [] : info.trailing
    row.fullLeading = info.fullLeading; row.fullTrailing = info.fullTrailing
    row.moveInfo = x.editing ? info.move : nil
    // selection: tapping selects; single selection highlights the row
    var selected = false
    if let sel = x.selection, let tag = info.tag, (row.action == nil || row.selectionAction) {
        selected = sel.isSelected(tag)
        let advance = x.advance
        if !(x.editing && !sel.multi) {
            row.action = { sel.select(tag); if !sel.multi { advance?() } }
            row.selectionAction = true
        }
    }
    if x.editing && x.selection == nil && !row.selectionAction { row.action = nil }          // no navigation while editing
    row.persistentHighlight = selected && x.selection?.multi == false && !x.editing
    row.backgroundColor = row.persistentHighlight ? .systemGray4 : nil
    // leading control in edit mode: delete (minus) or selection circle
    let leadKey = list.path + "|lead\(index)"
    if x.editing, info.delete != nil || (x.selection?.multi == true && info.tag != nil) {
        let c = g.view(leadKey) { _SUIControl(frame: .zero) }
        let iv = (c.subviews.first as? UIImageView) ?? { let i = UIImageView(); c.addSubview(i); return i }()
        if info.delete != nil {
            iv.image = UIImage(systemName: "minus.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
            iv.tintColor = .systemRed
            c.action = { [weak row] in row?.open(trailing: true, actions: [_SwipeAction(title: "Delete", image: nil, color: .systemRed, action: info.delete!)]) }
            c.accessibilityIdentifier = "row-delete-\(index)"
        } else {
            iv.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
            iv.tintColor = selected ? _accentUIColor() : .tertiaryLabel
            c.action = row.action
            c.accessibilityIdentifier = "row-select-\(index)"
        }
        if c.superview !== row { row.addSubview(c) }
        let s = iv.image?.size ?? CGSize(width: 22, height: 22)
        c.frame = CGRect(x: 14, y: (rowHeight - 30) / 2, width: 30, height: 30)
        iv.frame = CGRect(x: (30 - s.width) / 2, y: (30 - s.height) / 2, width: s.width, height: s.height)
    } else { g.views[leadKey]?.removeFromSuperview(); g.views[leadKey] = nil }
    // reorder handle
    let moveKey = list.path + "|move\(index)"
    if x.editing, info.move != nil {
        let h = g.view(moveKey) { _SUIMoveHandle(frame: .zero) }
        h.row = row
        h.accessibilityIdentifier = "row-move-\(index)"
        if h.superview !== row { row.addSubview(h) }
        h.frame = CGRect(x: row.bounds.width - 44, y: 0, width: 44, height: rowHeight)
    } else { g.views[moveKey]?.removeFromSuperview(); g.views[moveKey] = nil }
    // badge (trailing, before the accessory)
    let badgeKey = list.path + "|badge\(index)"
    if let b = info.badge, !x.editing {
        let l = g.view(badgeKey) { UILabel() }
        l.text = b; l.textColor = .secondaryLabel; l.font = .systemFont(ofSize: 17)
        if l.superview !== row { row.addSubview(l) }
        let s = l.sizeThatFits(CGSize(width: 200, height: 40))
        let right = row.bounds.width - (node.rowAccessory != nil ? 36 : 20)
        l.frame = CGRect(x: right - ceil(s.width), y: (rowHeight - s.height) / 2, width: ceil(s.width), height: s.height)
    } else { g.views[badgeKey]?.removeFromSuperview(); g.views[badgeKey] = nil }
    // long press menu on rows that are buttons / links (other rows use the context host inside them)
    row.contextMenu = row.action != nil ? info.contextMenu : nil
    row.contextPreview = row.action != nil ? info.contextPreview : nil
    row.contextIndex = index
}

// MARK: - The list row

/// A list row with swipe actions, a context menu and reordering (subclass of the plain row control).
final class _SUIListRow: _SUIRowControl {
    weak var list: _ListNode?
    var leadingActions: [_SwipeAction] = [], trailingActions: [_SwipeAction] = []
    var fullLeading = true, fullTrailing = true
    var moveInfo: (index: Int, group: String, action: (IndexSet, Int) -> Void)?
    var selectionAction = false, persistentHighlight = false
    var contextMenu: (() -> UIMenu)? { didSet { updateLongPress() } }
    var contextPreview: (() -> UIView)?
    var contextIndex = 0
    private var longPress: UILongPressGestureRecognizer?
    private let actionsView = UIView()
    private var offset: CGFloat = 0
    private var start: CGPoint?
    private var swiping = false
    private var openActions: [_SwipeAction] = []
    override var isHighlighted: Bool { didSet { if persistentHighlight { backgroundColor = .systemGray4 } } }
    func updateLongPress() {
        if contextMenu != nil, longPress == nil {
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:))); lp.minimumPressDuration = 0.5
            addGestureRecognizer(lp); longPress = lp
        }
        longPress?.isEnabled = contextMenu != nil
    }
    @objc func pressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let m = contextMenu?() else { return }
        isHighlighted = false
        if let p = contextPreview?() { _isim_present(m, from: bounds, preview: p) } else { _isim_present(m, from: bounds) }
    }
    var content: [UIView] { subviews.filter { $0 !== actionsView } }
    func setOffset(_ x: CGFloat) {
        offset = x
        for v in content { v.transform = CGAffineTransform(translationX: x, y: 0) }
    }
    /// Shows action buttons on one side (swipe, or the delete button in edit mode).
    func open(trailing: Bool, actions: [_SwipeAction]) {
        openActions = actions
        layoutActions(trailing: trailing)
        let w = actionsView.bounds.width
        UIView.animate(withDuration: 0.25) { self.setOffset(trailing ? -w : w) }
    }
    func close() {
        UIView.animate(withDuration: 0.25, animations: { self.setOffset(0) }, completion: { _ in if self.offset == 0 { self.actionsView.removeFromSuperview() } })
    }
    func layoutActions(trailing: Bool) {
        for s in actionsView.subviews { s.removeFromSuperview() }
        var x: CGFloat = 0
        for (i, a) in openActions.enumerated() {
            let b = _SUIControl(frame: .zero)
            b.backgroundColor = a.color
            b.accessibilityIdentifier = "swipe-\(a.title)"
            let l = UILabel(); l.text = a.title; l.textColor = .white; l.font = .systemFont(ofSize: 15, weight: .medium); l.textAlignment = .center
            let w = max(74, ceil(l.sizeThatFits(CGSize(width: 300, height: 40)).width) + 24)
            b.addSubview(l)
            if let img = a.image {
                let iv = UIImageView(image: img.withRenderingMode(.alwaysTemplate)); iv.tintColor = .white
                iv.frame = CGRect(x: (w - img.size.width) / 2, y: bounds.height / 2 - img.size.height - 1, width: img.size.width, height: img.size.height)
                b.addSubview(iv)
                l.frame = CGRect(x: 0, y: bounds.height / 2 + 1, width: w, height: 18)
            } else { l.frame = CGRect(x: 0, y: 0, width: w, height: bounds.height) }
            b.frame = CGRect(x: x, y: 0, width: w, height: bounds.height)
            let action = a.action
            b.action = { [weak self] in self?.setOffset(0); self?.actionsView.removeFromSuperview(); action() }
            actionsView.addSubview(b)
            x += w
            _ = i
        }
        actionsView.frame = CGRect(x: trailing ? bounds.width - x : 0, y: 0, width: x, height: bounds.height)
        if actionsView.superview !== self { insertSubview(actionsView, at: 0) }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        start = touches.first?.location(in: superview); swiping = false
        if offset != 0 { swiping = true; return }                 // a tap on an open row closes it
        super.touchesBegan(touches, with: event)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let s = start, let p = touches.first?.location(in: superview) else { return }
        let dx = p.x - s.x, dy = p.y - s.y
        if !swiping, abs(dx) > 10, abs(dx) > abs(dy), !(dx < 0 ? trailingActions : leadingActions).isEmpty {
            swiping = true
            super.touchesCancelled(touches, with: event)
            openActions = dx < 0 ? trailingActions : leadingActions
            layoutActions(trailing: dx < 0)
        }
        if swiping, !openActions.isEmpty {
            let max = actionsView.bounds.width
            let x = dx < 0 ? Swift.max(dx, -bounds.width) : Swift.min(dx, bounds.width)
            setOffset(abs(x) > max ? x : x)
            _ = max
            return
        }
        if !swiping { super.touchesMoved(touches, with: event) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { start = nil }
        guard swiping else { super.touchesEnded(touches, with: event); return }
        swiping = false
        if openActions.isEmpty || abs(offset) < 30 { close(); return }
        let trailing = offset < 0
        let full = trailing ? fullTrailing : fullLeading
        if full, abs(offset) > bounds.width * 0.6, let first = (trailing ? openActions.first : openActions.first) {
            setOffset(0); actionsView.removeFromSuperview(); first.action(); return
        }
        let w = actionsView.bounds.width
        UIView.animate(withDuration: 0.2) { self.setOffset(trailing ? -w : w) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        start = nil
        if swiping { swiping = false; if abs(offset) < 30 { close() } ; return }
        super.touchesCancelled(touches, with: event)
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if offset != 0, actionsView.superview === self, actionsView.frame.contains(point) { return actionsView.hitTest(convert(point, to: actionsView), with: event) }
        if offset != 0, self.point(inside: point, with: event) { return self }
        if let h = subviews.first(where: { ($0 is _SUIMoveHandle || ($0 is _SUIControl && $0.accessibilityIdentifier?.hasPrefix("row-") == true)) && $0.frame.contains(point) }) {
            return h.hitTest(convert(point, to: h), with: event) ?? h
        }
        return super.hitTest(point, with: event)
    }
    var hasSwipes: Bool { !leadingActions.isEmpty || !trailingActions.isEmpty }
}

/// Drag handle: moves its row, then calls onMove with the drop position among the rows of the same ForEach.
final class _SUIMoveHandle: UIView {
    weak var row: _SUIListRow?
    nonisolated(unsafe) static var active = false
    var startY: CGFloat = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        let iv = UIImageView(image: UIImage(systemName: "line.3.horizontal", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)))
        iv.tintColor = .tertiaryLabel
        addSubview(iv)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let iv = subviews.first as? UIImageView, let s = iv.image?.size { iv.frame = CGRect(x: (bounds.width - s.width) / 2, y: (bounds.height - s.height) / 2, width: s.width, height: s.height) }
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { self.point(inside: point, with: event) ? self : nil }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _SUIMoveHandle.active = true
        startY = touches.first?.location(in: row?.superview).y ?? 0
        if let r = row { r.superview?.bringSubviewToFront(r); r.layer.shadowOpacity = 0.2; r.layer.shadowRadius = 6 }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let r = row, let p = touches.first?.location(in: r.superview) else { return }
        r.transform = CGAffineTransform(translationX: 0, y: p.y - startY)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _SUIMoveHandle.active = false
        guard let r = row, let info = r.moveInfo, let card = r.superview else { return }
        let dy = (touches.first?.location(in: card).y ?? startY) - startY
        r.transform = .identity; r.layer.shadowOpacity = 0
        // rows of the same ForEach in this card, by position
        let siblings = card.subviews.compactMap { $0 as? _SUIListRow }.filter { $0.moveInfo?.group == info.group }.sorted { $0.frame.minY < $1.frame.minY }
        guard let from = siblings.firstIndex(where: { $0 === r }) else { return }
        let target = r.frame.midY + dy
        var to = siblings.filter { $0 !== r && $0.frame.midY < target }.count
        to = max(0, min(siblings.count - 1, to))
        guard to != from else { return }
        let fromIndex = info.index
        let toIndex = (siblings[to].moveInfo?.index ?? to)
        info.action(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        _SUIMoveHandle.active = false
        row?.transform = .identity; row?.layer.shadowOpacity = 0
    }
}

/// The list scroll view lets horizontal drags on swipeable rows and reorder drags through to the rows.
@MainActor func _listShouldBeginPan(_ s: UIScrollView, _ g: UIGestureRecognizer) -> Bool {
    if _SUIMoveHandle.active { return false }
    guard let p = g as? UIPanGestureRecognizer else { return true }
    let t = p.translation(in: s)
    if abs(t.x) > abs(t.y) {
        let loc = p.location(in: s)
        if let hit = s.hitTest(loc, with: nil) {
            var v: UIView? = hit
            while let x = v, !(x is _SUIListRow) { v = x.superview }
            if let row = v as? _SUIListRow, row.hasSwipes { return false }
        }
    }
    return true
}

// MARK: - Refreshable

public struct RefreshAction: Sendable {
    let action: @Sendable () async -> Void
    public func callAsFunction() async { await action() }
}
struct _RefreshKey: EnvironmentKey { static var defaultValue: RefreshAction? { nil } }
extension EnvironmentValues {
    public var refresh: RefreshAction? { get { self[_RefreshKey.self] } set { self[_RefreshKey.self] = newValue } }
}
extension View {
    /// Pull to refresh on the List / ScrollView inside: drag the top of the content down and release.
    public func refreshable(@_inheritActorContext action: @escaping @Sendable () async -> Void) -> some View {
        _env { $0.refresh = RefreshAction(action: action) }
    }
}
/// Spinner above the content; a drag released 60 pt past the top starts the refresh and keeps the spinner shown
/// until the action finishes.
final class _RefreshDriver {
    var action: RefreshAction?
    let spinner = UIActivityIndicatorView(style: .medium)
    var refreshing = false
    weak var scroll: UIScrollView?
    func attach(_ s: UIScrollView, _ a: RefreshAction?) {
        action = a; scroll = s
        if a == nil { spinner.removeFromSuperview(); return }
        if spinner.superview !== s { s.addSubview(spinner) }
        spinner.frame = CGRect(x: (s.bounds.width - 20) / 2, y: -40, width: 20, height: 20)
        spinner.accessibilityIdentifier = "refresh-spinner"
        if !refreshing { spinner.alpha = 0 }
    }
    func scrolled(_ s: UIScrollView) {
        guard action != nil, !refreshing else { return }
        spinner.alpha = min(1, max(0, -(s.contentOffset.y) / 60))
    }
    func endDragging(_ s: UIScrollView) {
        guard let a = action, !refreshing, s.contentOffset.y < -60 else { return }
        refreshing = true
        spinner.alpha = 1; spinner.startAnimating()
        var inset = s.contentInset; inset.top += 50; s.contentInset = inset
        Task { @MainActor [weak self, weak s] in
            await a()
            guard let self, let s else { return }
            self.refreshing = false
            self.spinner.stopAnimating(); self.spinner.alpha = 0
            var i = s.contentInset; i.top = max(0, i.top - 50); s.contentInset = i
            s.setContentOffset(CGPoint(x: s.contentOffset.x, y: 0), animated: true)
        }
    }
}

/// The context menu preview: the SwiftUI content hosted at its ideal size (at most the screen's width minus margins).
@MainActor func _contextPreviewView(_ content: AnyView, _ env: EnvironmentValues) -> UIView {
    let hc = UIHostingController(rootView: AnyView(_PresentedContent(environment: env, dismiss: {}, content: content)))
    let w = UIScreen.main.bounds.width - 32
    var s = hc.sizeThatFits(in: CGSize(width: w, height: UIScreen.main.bounds.height * 0.5))
    s.width = min(max(s.width, 60), w); s.height = min(max(s.height, 40), UIScreen.main.bounds.height * 0.5)
    hc.view.frame = CGRect(origin: .zero, size: s)
    hc.view.backgroundColor = .systemBackground
    _contextPreviewControllers.append(hc)                 // kept alive while the preview shows
    if _contextPreviewControllers.count > 4 { _contextPreviewControllers.removeFirst() }
    return hc.view
}
@MainActor var _contextPreviewControllers: [UIViewController] = []

// MARK: - Swipe actions on any view (iOS 27)

/// swipeActionsContainer(): one open swipe at a time among the views inside.
final class _SwipeContainerBox: _AnyStorage { weak var open: _SUISwipeHost? }
struct _SwipeContainerKey: EnvironmentKey { static var defaultValue: _SwipeContainerBox? { nil } }
extension EnvironmentValues { var _swipeContainer: _SwipeContainerBox? { get { self[_SwipeContainerKey.self] } set { self[_SwipeContainerKey.self] = newValue } } }

/// A view with swipe actions outside a List: a horizontal drag slides it and reveals the action buttons.
final class _SUISwipeHost: _PassthroughViewBase, UIGestureRecognizerDelegate {
    var leading: [_SwipeAction] = [], trailing: [_SwipeAction] = []
    var fullLeading = true, fullTrailing = true
    weak var container: _SwipeContainerBox?
    private let actionsView = UIView()
    private var offset: CGFloat = 0, start: CGFloat = 0, side = 0
    private var pan: UIPanGestureRecognizer?
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        let p = UIPanGestureRecognizer(target: self, action: #selector(panned(_:))); p.delegate = self
        addGestureRecognizer(p); pan = p
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard g === pan, let p = pan else { return true }
        let v = p.velocity(in: self)
        return abs(v.x) > abs(v.y)
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, self.point(inside: point, with: event) else { return nil }
        return super.hitTest(point, with: event) ?? self                  // the whole view takes the drag
    }
    var content: [UIView] { subviews.filter { $0 !== actionsView } }
    var actions: [_SwipeAction] { side < 0 ? trailing : leading }
    func setOffset(_ x: CGFloat) {
        offset = x
        for v in content { v.transform = CGAffineTransform(translationX: x, y: 0) }
        let w = abs(x)
        actionsView.frame = side < 0 ? CGRect(x: bounds.width - w, y: 0, width: w, height: bounds.height) : CGRect(x: 0, y: 0, width: w, height: bounds.height)
        var bx: CGFloat = 0
        let widths = actionsView.subviews.map { $0.bounds.width }, total = max(1, widths.reduce(0, +))
        for (i, b) in actionsView.subviews.enumerated() {          // the buttons share the revealed width
            let bw = widths[i] / total * w
            b.frame = CGRect(x: bx, y: 0, width: bw, height: bounds.height); bx += bw
            b.subviews.first?.frame = b.bounds
        }
    }
    func buildActions() {
        for s in actionsView.subviews { s.removeFromSuperview() }
        for a in actions {
            let b = _SUIControl(frame: .zero)
            b.backgroundColor = a.color
            b.accessibilityIdentifier = "swipe-\(a.title)"
            let l = UILabel(); l.text = a.title; l.textColor = .white; l.font = .systemFont(ofSize: 15, weight: .medium); l.textAlignment = .center
            b.addSubview(l)
            b.bounds.size.width = max(74, ceil(l.sizeThatFits(CGSize(width: 300, height: 40)).width) + 24)
            let action = a.action
            b.action = { [weak self] in self?.close(); action() }
            actionsView.addSubview(b)
        }
        if actionsView.superview !== self { addSubview(actionsView) } else { bringSubviewToFront(actionsView) }
    }
    var actionsWidth: CGFloat { actionsView.subviews.reduce(0) { $0 + $1.bounds.width } }
    @objc func panned(_ g: UIPanGestureRecognizer) {
        let dx = g.translation(in: self).x
        switch g.state {
        case .began:
            start = offset
            if offset == 0 { side = g.velocity(in: self).x < 0 ? -1 : 1; buildActions() }
            if let c = container, c.open !== self { c.open?.close() }
        case .changed:
            var x = start + dx
            if side < 0 { x = trailing.isEmpty ? 0 : min(0, x) } else { x = leading.isEmpty ? 0 : max(0, x) }
            UIView.performWithoutAnimation { setOffset(x) }
        case .ended, .cancelled:
            let w = actionsWidth, full = side < 0 ? fullTrailing : fullLeading
            if full, let first = (side < 0 ? trailing.first : leading.first), abs(offset) > bounds.width * 0.6 { close(); first.action() }
            else if abs(offset) > w / 2 { UIView.animate(withDuration: 0.25) { self.setOffset(CGFloat(self.side) * w) }; container?.open = self }
            else { close() }
        default: break
        }
    }
    func close() {
        UIView.animate(withDuration: 0.25, animations: { self.setOffset(0) }, completion: { _ in if self.offset == 0 { self.actionsView.removeFromSuperview() } })
        if container?.open === self { container?.open = nil }
    }
}
