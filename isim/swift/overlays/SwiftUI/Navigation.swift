// isim SwiftUI: lists, forms, navigation and toolbars.
import UIKit

// MARK: - Section, Form, List

public struct Section<Parent: View, Content: View, Footer: View>: View, _PrimitiveView {
    let header: Parent?, content: Content, footer: Footer?
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let h = header.map { _resolve($0, ctx.child("header").with { $0._inList = false; $0.font = $0.font ?? .footnote; $0._foreground = $0._foreground ?? .secondary; $0._sectionHeader = true }) }
        let f = footer.map { _resolve($0, ctx.child("footer").with { $0._inList = false; $0.font = $0.font ?? .footnote; $0._foreground = $0._foreground ?? .secondary }) }
        let rows = _flatten([_resolve(content, ctx.child("rows"))])
        return _SectionNode(path: ctx.path, header: h, footer: f, rows: rows)
    }
}
extension Section where Parent == EmptyView, Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content) { header = nil; self.content = content(); footer = nil }
}
extension Section where Parent == Text, Footer == EmptyView {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { header = Text(titleKey); self.content = content(); footer = nil }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) { header = Text(title); self.content = content(); footer = nil }
}
extension Section {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) {
        self.header = header(); self.content = content(); self.footer = footer()
    }
}
extension Section where Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) { self.header = header(); self.content = content(); footer = nil }
}
extension Section where Parent == EmptyView {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) { header = nil; self.content = content(); self.footer = footer() }
}

final class _SectionNode: _Node {
    let header: _Node?, footer: _Node?, rows: [_Node]
    init(path: String, header: _Node?, footer: _Node?, rows: [_Node]) {
        self.header = header; self.footer = footer; self.rows = rows
        super.init(path: path, children: rows)
    }
}

public struct Form<Content: View>: View, _PrimitiveView {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _makeList(content, ctx) }
}
public struct List<SelectionValue: Hashable, Content: View>: View, _PrimitiveView {
    let content: Content
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _makeList(content, ctx) }
}
extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
}
extension View {
    public func listStyle<S>(_ style: S) -> some View { self }
    public func formStyle<S>(_ style: S) -> some View { self }
    public func listRowBackground<V: View>(_ view: V?) -> some View { self }
    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }
    public func listSectionSpacing(_ spacing: CGFloat) -> some View { self }
    public func scrollContentBackground(_ visibility: Visibility) -> some View { self }
    public func headerProminence(_ p: Prominence) -> some View { self }
}
public enum Visibility: Hashable, CaseIterable, Sendable { case automatic, visible, hidden }
public enum Prominence: Hashable, Sendable { case standard, increased }
public enum VerticalEdge: Int8, Sendable {
    case top, bottom
    public struct Set: OptionSet, Sendable { public let rawValue: Int8; public init(rawValue: Int8) { self.rawValue = rawValue }; public static let all = Set(rawValue: 3) }
}
public struct InsetGroupedListStyle { public init() {} }
public struct GroupedListStyle { public init() {} }
public struct PlainListStyle { public init() {} }

@MainActor func _makeList<C: View>(_ content: C, _ ctx: _Context) -> _Node {
    let inner = ctx.child("list").with { $0._inList = true }
    let nodes = _flatten([_resolve(content, inner)])
    // rows outside sections form implicit sections
    var sections: [_SectionNode] = []
    var loose: [_Node] = []
    func flush() { if !loose.isEmpty { sections.append(_SectionNode(path: ctx.path + "/implicit\(sections.count)", header: nil, footer: nil, rows: loose)); loose = [] } }
    for n in nodes { if let s = n as? _SectionNode { flush(); sections.append(s) } else { loose.append(n) } }
    flush()
    let level = ctx.nav
    level?.contentIsList = true
    return _ListNode(path: ctx.path, sections: sections, level: level, graph: ctx.graph)
}

extension EnvironmentValues {
    var _sectionHeader: Bool { get { self[_SectionHeaderKey.self] } set { self[_SectionHeaderKey.self] = newValue } }
}
struct _SectionHeaderKey: EnvironmentKey { static var defaultValue: Bool { false } }

/// Inset-grouped list (UITableView .insetGrouped metrics), rendered in a UIScrollView.
final class _ListNode: _Node {
    let sections: [_SectionNode]
    weak var level: _NavLevel?
    weak var graph: _Graph?
    // layout results
    struct RowLayout { let node: _Node; let rect: CGRect; let contentRect: CGRect; let separatorLeading: CGFloat?; let section: Int }
    var rows: [RowLayout] = []
    var cards: [CGRect] = []
    var headers: [(_Node, CGRect)] = []
    var footers: [(_Node, CGRect)] = []
    var largeTitleRect: CGRect?
    var contentHeight: CGFloat = 0
    init(path: String, sections: [_SectionNode], level: _NavLevel?, graph: _Graph) {
        self.sections = sections; self.level = level; self.graph = graph
        super.init(path: path, children: [])
    }
    override var ignoresSafeArea: Bool { true }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
    static let margin: CGFloat = 20, rowInset: CGFloat = 20, minRow: CGFloat = 44
    override func place(_ rect: CGRect) {
        frame = rect
        rows = []; cards = []; headers = []; footers = []; largeTitleRect = nil
        let W = rect.width, cardX = _ListNode.margin, cardW = W - 2 * _ListNode.margin
        let rowContentW = cardW - 2 * _ListNode.rowInset
        var y: CGFloat = 0
        if let lv = level, lv.showsLargeTitle {
            largeTitleRect = CGRect(x: 20, y: 0, width: W - 40, height: 52)
            y = 52
        } else { y = 18 }
        for (si, sec) in sections.enumerated() {
            if si > 0 { y += sec.header == nil ? 35 : 22 } else if sec.header != nil { y += 4 }
            if let h = sec.header {
                let hs = h.sizeThatFits(_Proposal(width: cardW - 2 * _ListNode.rowInset, height: nil))
                let r = CGRect(x: cardX + _ListNode.rowInset, y: y, width: cardW - 2 * _ListNode.rowInset, height: hs.height)
                h.place(CGRect(x: r.minX, y: r.minY, width: min(hs.width, r.width), height: hs.height))
                headers.append((h, r)); y += hs.height + 7
            }
            let cardTop = y
            for row in sec.rows {
                let s = row.sizeThatFits(_Proposal(width: rowContentW - (row.rowAccessory != nil ? 20 : 0), height: nil))
                let h = max(_ListNode.minRow, s.height + 22)
                let rr = CGRect(x: cardX, y: y, width: cardW, height: h)
                let cr = CGRect(x: _ListNode.rowInset, y: (h - s.height) / 2, width: min(s.width, rowContentW), height: s.height)
                row.place(cr)
                rows.append(RowLayout(node: row, rect: rr, contentRect: cr, separatorLeading: _separatorLeading(row), section: si))
                y += h
            }
            cards.append(CGRect(x: cardX, y: cardTop, width: cardW, height: y - cardTop))
            if let f = sec.footer {
                y += 7
                let fs = f.sizeThatFits(_Proposal(width: cardW - 2 * _ListNode.rowInset, height: nil))
                let r = CGRect(x: cardX + _ListNode.rowInset, y: y, width: cardW - 2 * _ListNode.rowInset, height: fs.height)
                f.place(CGRect(x: r.minX, y: r.minY, width: min(fs.width, r.width), height: fs.height))
                footers.append((f, r)); y += fs.height
            }
        }
        contentHeight = y + 35
    }
    override func mountView(_ g: _Graph) -> UIView {
        let sv = g.view(viewKey) { _SUIListScroll(frame: .zero) }
        sv.backgroundColor = .systemGroupedBackground
        sv.level = level
        sv.contentSize = CGSize(width: frame.width, height: contentHeight)
        return sv
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        guard let sv = view as? _SUIListScroll else { return }
        if let lt = largeTitleRect, let title = level?.title {
            let l = g.view(path + "|largeTitle") { UILabel() }
            l.text = title; l.font = .systemFont(ofSize: 34, weight: .bold); l.textColor = .label
            if l.superview !== sv { sv.addSubview(l) }
            l.frame = lt
            sv.largeTitleBottom = lt.maxY
        } else { sv.largeTitleBottom = 0 }
        for (i, c) in cards.enumerated() {
            let card = g.view(path + "|card\(i)") { UIView() }
            card.backgroundColor = .secondarySystemGroupedBackground
            card.layer.cornerRadius = 10
            card.clipsToBounds = true
            card.isUserInteractionEnabled = true
            if card.superview !== sv { sv.addSubview(card) }
            card.frame = c
        }
        for (h, _) in headers { g.mount(h, in: sv, order: 0) }
        for (f, _) in footers { g.mount(f, in: sv, order: 0) }
        var previous: RowLayout?
        for (i, r) in rows.enumerated() {
            guard let card = g.views[path + "|card\(r.section)"] else { continue }
            let rowView = g.view(path + "|row\(i)|" + r.node.path) { _SUIRowControl(frame: .zero) }
            rowView.action = r.node.rowAction
            rowView.frame = CGRect(x: 0, y: r.rect.minY - cards[r.section].minY, width: r.rect.width, height: r.rect.height)
            if rowView.superview !== card { card.addSubview(rowView) }
            g.mount(r.node, in: rowView, order: 0)
            if let acc = r.node.rowAccessory {
                let iv = g.view(path + "|acc\(i)") { UIImageView() }
                iv.image = UIImage(systemName: acc, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
                iv.tintColor = .tertiaryLabel
                if iv.superview !== rowView { rowView.addSubview(iv) }
                let s = iv.image?.size ?? .zero
                iv.frame = CGRect(x: r.rect.width - 16 - s.width, y: (r.rect.height - s.height) / 2, width: s.width, height: s.height)
            }
            // separator above this row (between rows of the same section)
            if let p = previous, p.section == r.section {
                let sep = g.view(path + "|sep\(i)") { UIView() }
                sep.backgroundColor = .separator
                if sep.superview !== card { card.addSubview(sep) }
                let lead = r.separatorLeading ?? _ListNode.rowInset
                let hair = 1 / max(1, UIScreen.main.scale)
                sep.frame = CGRect(x: lead, y: r.rect.minY - cards[r.section].minY, width: r.rect.width - lead, height: hair)
            }
            previous = r
        }
        sv.scrollViewDidScroll(sv)
    }
}

/// Separator leading edge: rows that start with a Label align it with the title text.
@MainActor func _separatorLeading(_ n: _Node) -> CGFloat? {
    var node = n
    while true {
        if let s = node as? _StackNode, s.axis == .horizontal, let first = _flatten(s.children).first as? _FrameNode, first.width == 28 {
            return _ListNode.rowInset + 28 + s.spacing
        }
        if node.children.count == 1 { node = node.children[0] } else { return nil }
    }
}

/// A list row: highlights while pressed and runs the row action (Button / NavigationLink / Link rows).
final class _SUIRowControl: UIControl {
    var action: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }
    @objc func fire() { action?() }
    override var isHighlighted: Bool { didSet { backgroundColor = isHighlighted && action != nil ? .systemGray4 : nil } }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, self.point(inside: point, with: event) else { return nil }
        // interactive content (text fields, controls) inside the row gets the touch; otherwise the row does
        if let inner = super.hitTest(point, with: event), inner !== self, inner is UITextField || inner is UISwitch || (inner is UIControl && action == nil) { return inner }
        return action != nil ? self : super.hitTest(point, with: event)
    }
}

/// The list's scroll view: keeps the focused field above the keyboard and reports scrolling
/// to the navigation bar (large title -> inline title).
final class _SUIListScroll: UIScrollView, UIScrollViewDelegate {
    var level: _NavLevel?
    var largeTitleBottom: CGFloat = 0
    var keyboardOverlap: CGFloat = 0
    private var observers: [NSObjectProtocol] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        alwaysBounceVertical = true
        let nc = NotificationCenter.default
        let token = nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
            let info = n.userInfo
            let value = info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
            let end: CGRect = value?.cgRectValue ?? CGRect.zero
            MainActor.assumeIsolated { self?.keyboardChanged(end) }
        })
        observers.append(token)
    }
    func keyboardChanged(_ end: CGRect) {
        guard let w = window else { return }
        let mine = convert(bounds, to: nil)
        let overlap = end.isEmpty || end.minY >= UIScreen.main.bounds.height ? 0 : max(0, mine.maxY + w.frame.minY - end.minY)
        keyboardOverlap = overlap
        var inset = contentInset; inset.bottom = overlap; contentInset = inset
        if overlap > 0, let field = firstResponderField(in: self) {
            let r = field.convert(field.bounds, to: self).insetBy(dx: 0, dy: -12)
            scrollRectToVisible(r, animated: false)
        }
        layoutIfNeeded()
    }
    func firstResponderField(in v: UIView) -> UIView? {
        if v.isFirstResponder { return v }
        for s in v.subviews { if let f = firstResponderField(in: s) { return f } }
        return nil
    }
    func scrollViewDidScroll(_ s: UIScrollView) {
        let offset = s.contentOffset.y + s.adjustedContentInset.top
        let past = largeTitleBottom > 0 ? offset > largeTitleBottom - 8 : offset > 1
        level?.scrolledPastTitle = past
        if let bar = level?.bar { bar.scrolled = past; bar.update() }
    }
}

// MARK: - LabeledContent, Toggle

public struct LabeledContent<Label: View, Content: View>: View, _PrimitiveView {
    let label: Label, content: Content
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.label = label(); self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let l = _resolve(label, ctx.child("label"))
        let c = _resolve(content, ctx.child("content").with { $0._foreground = $0._foreground ?? .secondary })
        return _StackNode(path: ctx.path, axis: .horizontal, spacing: 8, alignment: .center,
                          children: [l, _SpacerNode(path: ctx.path + "/spacer", minLength: 8), c])
    }
}
extension LabeledContent where Label == Text, Content == Text {
    public init<S: StringProtocol>(_ titleKey: LocalizedStringKey, value: S) { self.label = Text(titleKey); self.content = Text(value) }
    @_disfavoredOverload public init<S1: StringProtocol, S2: StringProtocol>(_ title: S1, value: S2) { self.label = Text(title); self.content = Text(value) }
}

public struct Toggle<Label: View>: View, _PrimitiveView {
    let isOn: Binding<Bool>, label: Label
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) { self.isOn = isOn; self.label = label() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let l = _resolve(label, ctx.child("label"))
        let sw = _SwitchNode(path: ctx.path + "/switch", isOn: isOn, tint: ctx.environment._tint)
        return _StackNode(path: ctx.path, axis: .horizontal, spacing: 8, alignment: .center, children: [l, _SpacerNode(path: ctx.path + "/sp", minLength: 8), sw])
    }
}
extension Toggle where Label == Text {
    public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) { self.init(isOn: isOn) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) { self.init(isOn: isOn) { Text(title) } }
}
final class _SwitchNode: _Node {
    let isOn: Binding<Bool>, tint: Color?
    init(path: String, isOn: Binding<Bool>, tint: Color?) { self.isOn = isOn; self.tint = tint; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: 51, height: 31) }
    override func mountView(_ g: _Graph) -> UIView {
        let s = g.view(viewKey) { _SUISwitch(frame: .zero) }
        s.binding = isOn
        if s.isOn != isOn.wrappedValue { s.isOn = isOn.wrappedValue }
        if let t = tint { s.onTintColor = t.uiColor }
        return s
    }
}
final class _SUISwitch: UISwitch {
    var binding: Binding<Bool>?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(changed), for: .valueChanged) }
    @objc func changed() { binding?.wrappedValue = isOn }
}

// MARK: - Navigation

public enum NavigationBarItem {
    public enum TitleDisplayMode: Sendable { case automatic, inline, large }
}

/// Per navigation level: title, display mode, toolbar items (filled in while the level's content evaluates).
@MainActor final class _NavLevel {
    var title: String?
    var displayMode: NavigationBarItem.TitleDisplayMode = .automatic
    var toolbar: [(ToolbarItemPlacement, _Node)] = []
    var contentIsList = false
    var scrolledPastTitle = false
    let index: Int
    weak var bar: _SUINavBar?
    var registry: _NavRegistry?
    var pushValue: ((AnyHashable) -> Void)?
    let push: (AnyView) -> Void
    init(index: Int, push: @escaping (AnyView) -> Void) { self.index = index; self.push = push }
    var isLarge: Bool { displayMode == .large || (displayMode == .automatic && index == 0) }
    var showsLargeTitle: Bool { isLarge && title != nil }
}

enum _NavEntry { case view(AnyView), value(AnyHashable) }
final class _NavState: _AnyStorage { var stack: [_NavEntry] = [] }
/// navigationDestination(for:) builders, per stack (registered while the root level evaluates)
@MainActor final class _NavRegistry { var builders: [ObjectIdentifier: (Any) -> AnyView] = [:] }

public struct NavigationPath: Equatable {
    var elements: [AnyHashable] = []
    public init() {}
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable { self.elements = elements.map { AnyHashable($0) } }
    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }
    public mutating func append<V: Hashable>(_ value: V) { elements.append(AnyHashable(value)) }
    public mutating func removeLast(_ k: Int = 1) { elements.removeLast(k) }
}

public struct NavigationStack<Root: View>: View, _PrimitiveView {
    let root: Root
    let pathGet: (() -> [AnyHashable])?
    let pathSet: (([AnyHashable]) -> Void)?
    public init(@ViewBuilder root: () -> Root) { self.root = root(); pathGet = nil; pathSet = nil }
    public init<D: Hashable>(path: Binding<[D]>, @ViewBuilder root: () -> Root) {
        self.root = root()
        pathGet = { path.wrappedValue.map { AnyHashable($0) } }
        pathSet = { v in path.wrappedValue = v.compactMap { $0.base as? D } }
    }
    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {
        self.root = root()
        pathGet = { path.wrappedValue.elements }
        pathSet = { v in var p = NavigationPath(); p.elements = v; path.wrappedValue = p }
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let key = ctx.path + "#nav"
        let state = ctx.graph.storage[key] as? _NavState ?? _NavState()
        ctx.graph.storage[key] = state
        ctx.graph.usedKeys.insert(key)
        let g = ctx.graph
        let registry = _NavRegistry()
        // entries: values from the bound path (if any), then views pushed by NavigationLink(destination:)
        let pathSet = self.pathSet, pathGet = self.pathGet
        let bound = pathGet?() ?? []
        let hasPath = pathGet != nil
        let entries: [_NavEntry] = bound.map { .value($0) } + state.stack.filter { if case .view = $0 { return true }; return !hasPath }
        func push(_ e: _NavEntry) {
            if case .value(let v) = e, let set = pathSet, let get = pathGet { set(get() + [v]) }
            else { state.stack.append(e) }
            g.invalidate()
        }
        func popTo(_ count: Int) {           /* keep `count` entries */
            var remaining = count
            if let set = pathSet, let get = pathGet {
                let values = get()
                if remaining <= values.count { set(Array(values.prefix(remaining))); state.stack.removeAll { if case .view = $0 { return true }; return false } }
                else { remaining -= values.count; let views = state.stack; state.stack = Array(views.prefix(remaining)) }
            } else { state.stack = Array(state.stack.prefix(remaining)) }
            g.invalidate()
        }
        var levels: [_NavLevel] = []
        var nodes: [_Node] = []
        for i in 0...entries.count {
            let level = _NavLevel(index: i) { v in push(.view(v)) }
            level.registry = registry
            level.pushValue = { v in push(.value(v)) }
            if i > 0, let prev = levels.last, prev.displayMode == .large, level.displayMode == .automatic { level.displayMode = .large }
            let lctx = _Context(graph: g, path: ctx.path + "/L\(i)", environment: ctx.environment, nav: level)
            lctx.environment.dismiss = DismissAction { if i > 0 { popTo(i - 1) } }
            let node: _Node
            if i == 0 { node = _resolve(root, lctx) }
            else {
                switch entries[i - 1] {
                case .view(let v): node = _resolve(v, lctx)
                case .value(let v):
                    if let b = registry.builders[ObjectIdentifier(type(of: v.base))] { node = _resolve(b(v.base), lctx) }
                    else { print("isim SwiftUI: no navigationDestination for \(type(of: v.base))"); node = _resolve(EmptyView(), lctx) }
                }
            }
            levels.append(level); nodes.append(node)
        }
        let node = _NavStackNode(path: ctx.path, levels: levels, nodes: nodes, pop: { if !entries.isEmpty { popTo(entries.count - 1) } })
        node.safeTop = g.safeArea.top; node.safeBottom = g.safeArea.bottom
        return node
    }
}
extension View {
    public func navigationDestination<D: Hashable, C: View>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View {
        _modify { ctx, c in
            ctx.nav?.registry?.builders[ObjectIdentifier(D.self)] = { any in AnyView(destination(any as! D)) }
            return _resolve(c, ctx.child("nd"))
        }
    }
}
extension NavigationLink where Destination == Never {
    public init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) { self.label = label(); self.destination = nil; self.value = value.map { AnyHashable($0) } }
}
extension NavigationLink where Destination == Never, Label == Text {
    public init<P: Hashable>(_ titleKey: LocalizedStringKey, value: P?) { self.init(value: value) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol, P: Hashable>(_ title: S, value: P?) { self.init(value: value) { Text(title) } }
}
/// NavigationView: same as a NavigationStack on iPhone.
public struct NavigationView<Content: View>: View, _PrimitiveView {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { NavigationStack { content }._makeNode(ctx) }
}

final class _NavStackNode: _Node {
    let levels: [_NavLevel], nodes: [_Node], pop: () -> Void
    init(path: String, levels: [_NavLevel], nodes: [_Node], pop: @escaping () -> Void) {
        self.levels = levels; self.nodes = nodes; self.pop = pop
        super.init(path: path, children: [nodes.last!])
    }
    override var ignoresSafeArea: Bool { true }
    var top: _NavLevel { levels.last! }
    var barHeight: CGFloat { 44 }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
    var safeTop: CGFloat = 0, safeBottom: CGFloat = 0
    override func place(_ rect: CGRect) {
        frame = rect
        for (i, content) in nodes.enumerated() { placeLevel(content, levels[i], rect) }
        for (_, item) in self.top.toolbar {
            let s = item.sizeThatFits(_Proposal(width: 200, height: barHeight))
            item.place(CGRect(origin: .zero, size: s))
        }
    }
    func placeLevel(_ content: _Node, _ level: _NavLevel, _ rect: CGRect) {
        let top = safeTop + barHeight
        if content.ignoresSafeArea {
            content.place(CGRect(x: 0, y: top, width: rect.width, height: rect.height - top))
        } else {
            // non-list content: large title above it, the rest inside the safe area
            let titleH: CGFloat = level.showsLargeTitle ? 52 : 0
            let area = CGRect(x: 0, y: top + titleH, width: rect.width, height: rect.height - top - titleH - safeBottom)
            let s = content.sizeThatFits(_Proposal(width: area.width, height: area.height))
            content.place(CGRect(x: (area.width - min(s.width, area.width)) / 2, y: area.minY, width: min(s.width, area.width), height: min(s.height, area.height)))
        }
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        v.backgroundColor = .systemBackground
        return v
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        // every level stays mounted (scroll positions, text fields keep their state); only the top one shows
        for (i, node) in nodes.enumerated() {
            let container = g.view(path + "|level\(i)") { _PassthroughView() }
            if container.superview !== view { view.addSubview(container) } else { view.bringSubview(toFront: container) }
            container.frame = view.bounds
            container.isHidden = i != nodes.count - 1
            container.backgroundColor = levels[i].contentIsList ? .systemGroupedBackground : .systemBackground
            g.mount(node, in: container, order: 0)
        }
        let content = nodes.last!
        if !content.ignoresSafeArea, top.showsLargeTitle, let title = top.title {
            let l = g.view(path + "|largeTitle") { UILabel() }
            l.text = title; l.font = .systemFont(ofSize: 34, weight: .bold); l.textColor = .label
            if l.superview !== view { view.addSubview(l) }
            l.frame = CGRect(x: 20, y: safeTop + barHeight, width: view.bounds.width - 40, height: 52)
        }
        let bar = g.view(path + "|bar") { _SUINavBar(frame: .zero) }
        if bar.superview !== view { view.addSubview(bar) } else { view.bringSubview(toFront: bar) }
        bar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: safeTop + barHeight)
        bar.configure(level: top, previousTitle: levels.count > 1 ? levels[levels.count - 2].title : nil, safeTop: safeTop, pop: levels.count > 1 ? pop : nil)
        top.bar = bar
        if bar.levelIndex != top.index { bar.scrolled = false; bar.levelIndex = top.index }
        for (i, (placement, item)) in top.toolbar.enumerated() {
            let host = g.view(path + "|tb\(i)") { _PassthroughView() }
            if host.superview !== bar { bar.addSubview(host) }
            let s = item.frame.size
            let leading = placement == .topBarLeading || placement == .navigationBarLeading || placement == .cancellationAction
            host.frame = CGRect(x: leading ? (levels.count > 1 ? 110 : 16) : bar.bounds.width - 16 - s.width, y: safeTop + (barHeight - s.height) / 2, width: s.width, height: s.height)
            g.mount(item, in: host, order: 0)
            if let v = g.views[item.viewKey] { v.frame = CGRect(origin: .zero, size: s) }
        }
        bar.update()
    }
}

/// Navigation bar: back button, title (inline, or shown when the large title scrolls away), toolbar items.
final class _SUINavBar: UIView {
    let titleLabel = UILabel()
    let back = _SUIControl(frame: .zero)
    let backLabel = UILabel()
    let backChevron = UIImageView()
    let hairline = UIView()
    var level: _NavLevel?
    var scrolled = false
    var levelIndex = -1
    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        hairline.backgroundColor = .separator
        addSubview(hairline)
        back.addSubview(backChevron); back.addSubview(backLabel)
        back.accessibilityIdentifier = "isim-nav-back"
        addSubview(back)
    }
    func configure(level: _NavLevel, previousTitle: String?, safeTop: CGFloat, pop: (() -> Void)?) {
        self.level = level
        titleLabel.text = level.title
        titleLabel.frame = CGRect(x: 100, y: safeTop, width: bounds.width - 200, height: 44)
        hairline.frame = CGRect(x: 0, y: bounds.height - 0.5, width: bounds.width, height: 0.5)
        back.isHidden = pop == nil
        back.action = pop
        let tint = _accentUIColor()
        backChevron.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        backChevron.tintColor = tint
        backLabel.text = previousTitle ?? "Back"
        backLabel.textColor = tint
        backLabel.font = .systemFont(ofSize: 17)
        let cs = backChevron.image?.size ?? CGSize(width: 12, height: 20)
        let ls = backLabel.sizeThatFits(CGSize(width: 120, height: 44))
        back.frame = CGRect(x: 8, y: safeTop, width: min(cs.width + 6 + ls.width, 140), height: 44)
        backChevron.frame = CGRect(x: 0, y: (44 - cs.height) / 2, width: cs.width, height: cs.height)
        backLabel.frame = CGRect(x: cs.width + 6, y: (44 - ls.height) / 2, width: min(ls.width, 140 - cs.width - 6), height: ls.height)
    }
    func update() {
        guard let l = level else { return }
        let inline = !l.isLarge || scrolled || !l.contentIsList && !l.showsLargeTitle
        titleLabel.alpha = inline ? 1 : 0
        let solid = scrolled
        backgroundColor = solid ? UIColor.systemBackground.withAlphaComponent(0.94) : (l.contentIsList ? .systemGroupedBackground : .systemBackground)
        hairline.isHidden = !solid
    }
}

public struct NavigationLink<Label: View, Destination: View>: View, _PrimitiveView {
    let label: Label, destination: Destination?
    var value: AnyHashable? = nil
    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) { self.destination = destination(); self.label = label() }
    public init(destination: Destination, @ViewBuilder label: () -> Label) { self.destination = destination; self.label = label() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let nav = ctx.nav, value = self.value
        let dest = destination.map { AnyView($0) }
        let push: ((AnyView) -> Void)? = { v in
            if let d = dest { nav?.push(d) } else if let val = value { nav?.pushValue?(val) }
            _ = v
        }
        let inList = ctx.environment._inList
        let labelNode = _resolve(label, ctx.child("label").with { if !inList { $0._foreground = $0._foreground ?? $0._tint ?? .accentColor } })
        let node = _ButtonNode(path: ctx.path, child: labelNode, action: { push?(AnyView(EmptyView())) }, inList: inList, enabled: ctx.environment.isEnabled)
        return inList ? _AccessoryNode(path: ctx.path + "/acc", child: node, accessory: "chevron.right") : node
    }
}
extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder destination: () -> Destination) { self.init(destination: destination) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder destination: () -> Destination) { self.init(destination: destination) { Text(title) } }
    public init(_ titleKey: LocalizedStringKey, destination: Destination) { self.init(destination: destination) { Text(titleKey) } }
}
final class _AccessoryNode: _WrapperNode {
    let accessory: String
    init(path: String, child: _Node, accessory: String) { self.accessory = accessory; super.init(path: path, child: child) }
    override var rowAccessory: String? { accessory }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

extension View {
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View { _navTitle { titleKey.resolved() } }
    @_disfavoredOverload public func navigationTitle<S: StringProtocol>(_ title: S) -> some View { let t = String(title); return _navTitle { t } }
    public func navigationTitle(_ title: Text) -> some View { _navTitle { title.string } }
    func _navTitle(_ title: @escaping () -> String) -> some View {
        _modify { ctx, c in
            if let lv = ctx.nav, lv.title == nil { lv.title = title() }
            return _resolve(c, ctx.child("nt"))
        }
    }
    public func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View {
        _modify { ctx, c in ctx.nav?.displayMode = mode; return _resolve(c, ctx.child("nm")) }
    }
    public func navigationBarBackButtonHidden(_ hidden: Bool = true) -> some View { self }
    public func toolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: () -> Content) -> some View {
        let items = content()._items
        return _modify { ctx, c in
            if let lv = ctx.nav {
                for (i, item) in items.enumerated() {
                    let ictx = _Context(graph: ctx.graph, path: ctx.path + "/toolbar\(i)", environment: ctx.environment, nav: nil)
                    lv.toolbar.append((item.placement, _resolve(item.view, ictx)))
                }
            }
            return _resolve(c, ctx.child("tb"))
        }
    }
    @_disfavoredOverload
    public func toolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let v = AnyView(content())
        return toolbar { ToolbarItem(placement: .automatic) { v } }
    }
}

// MARK: - Toolbar content

public struct ToolbarItemPlacement: Equatable, Sendable {
    let id: Int
    public static let automatic = ToolbarItemPlacement(id: 0), principal = ToolbarItemPlacement(id: 1)
    public static let topBarLeading = ToolbarItemPlacement(id: 2), topBarTrailing = ToolbarItemPlacement(id: 3)
    public static let navigationBarLeading = ToolbarItemPlacement(id: 2), navigationBarTrailing = ToolbarItemPlacement(id: 3)
    public static let primaryAction = ToolbarItemPlacement(id: 3), confirmationAction = ToolbarItemPlacement(id: 3)
    public static let cancellationAction = ToolbarItemPlacement(id: 2), destructiveAction = ToolbarItemPlacement(id: 3)
    public static let bottomBar = ToolbarItemPlacement(id: 5), keyboard = ToolbarItemPlacement(id: 6), status = ToolbarItemPlacement(id: 5)
}
public struct _ToolbarEntry { let placement: ToolbarItemPlacement; let view: AnyView }
public protocol ToolbarContent { var _items: [_ToolbarEntry] { get } }
public struct ToolbarItem<ID, Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement, content: Content
    public var _items: [_ToolbarEntry] { [_ToolbarEntry(placement: placement, view: AnyView(content))] }
}
extension ToolbarItem where ID == () {
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) { self.placement = placement; self.content = content() }
}
public struct ToolbarItemGroup<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement, content: Content
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) { self.placement = placement; self.content = content() }
    public var _items: [_ToolbarEntry] { [_ToolbarEntry(placement: placement, view: AnyView(HStack(spacing: 16) { content }))] }
}
public struct _ToolbarList: ToolbarContent { public let _items: [_ToolbarEntry] }
@resultBuilder
public struct ToolbarContentBuilder {
    public static func buildExpression<C: ToolbarContent>(_ c: C) -> _ToolbarList { _ToolbarList(_items: c._items) }
    public static func buildBlock(_ parts: _ToolbarList...) -> _ToolbarList { _ToolbarList(_items: parts.flatMap { $0._items }) }
    public static func buildOptional(_ c: _ToolbarList?) -> _ToolbarList { c ?? _ToolbarList(_items: []) }
    public static func buildEither(first c: _ToolbarList) -> _ToolbarList { c }
    public static func buildEither(second c: _ToolbarList) -> _ToolbarList { c }
    public static func buildLimitedAvailability(_ c: _ToolbarList) -> _ToolbarList { c }
}
