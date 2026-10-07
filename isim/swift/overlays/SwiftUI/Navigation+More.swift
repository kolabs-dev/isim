// isim SwiftUI: more navigation — `navigationDestination(isPresented:)` / `(item:)`, NavigationSplitView (iPhone:
// collapses into a stack; selecting in a column's List pushes the next column; iPad: columns side by side with a
// sidebar button, columnVisibility, balanced / prominentDetail styles, column widths), toolbar visibility / background /
// colour scheme for the navigation bar and tab bar, and sheet detents (`presentationDetents`, drag indicator,
// background, corner radius): a sheet whose detents are not just `.large` is drawn by isim as a card of that height
// over a dimmed background (drag the grabber between detents or down to dismiss; tap outside to dismiss).
import UIKit

// MARK: - navigationDestination(isPresented:) / (item:)

struct _NavDestination { let isPresented: Bool; let view: AnyView; let pop: () -> Void }
extension View {
    public func navigationDestination<V: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> V) -> some View {
        let d = AnyView(destination())
        return _modify { ctx, c in
            ctx.nav?.destinations.append(_NavDestination(isPresented: isPresented.wrappedValue, view: d, pop: { isPresented.wrappedValue = false }))
            return _resolve(c, ctx.child("ndp"))
        }
    }
    public func navigationDestination<D: Hashable, C: View>(item: Binding<D?>, @ViewBuilder destination: @escaping (D) -> C) -> some View {
        _modify { ctx, c in
            if let v = item.wrappedValue {
                ctx.nav?.destinations.append(_NavDestination(isPresented: true, view: AnyView(destination(v)), pop: { item.wrappedValue = nil }))
            }
            return _resolve(c, ctx.child("ndi"))
        }
    }
}

// MARK: - NavigationSplitView

public struct NavigationSplitViewVisibility: Equatable, Sendable {
    let id: Int
    public static let automatic = Self(id: 0), all = Self(id: 1), doubleColumn = Self(id: 2), detailOnly = Self(id: 3)
}
public protocol NavigationSplitViewStyle {}
public struct AutomaticNavigationSplitViewStyle: NavigationSplitViewStyle { public init() {} }
public struct BalancedNavigationSplitViewStyle: NavigationSplitViewStyle { public init() {} }
public struct ProminentDetailNavigationSplitViewStyle: NavigationSplitViewStyle { public init() {} }
extension NavigationSplitViewStyle where Self == AutomaticNavigationSplitViewStyle { public static var automatic: Self { .init() } }
extension NavigationSplitViewStyle where Self == BalancedNavigationSplitViewStyle { public static var balanced: Self { .init() } }
extension NavigationSplitViewStyle where Self == ProminentDetailNavigationSplitViewStyle { public static var prominentDetail: Self { .init() } }
public enum NavigationSplitViewColumn: Hashable, Sendable { case sidebar, content, detail }

/// Per column of a regular-width split view: its width (navigationSplitViewColumnWidth).
@MainActor final class _SplitColumnConfig { var width: CGFloat? }
struct _SplitColumnKey: EnvironmentKey { static var defaultValue: _SplitColumnConfig? { nil } }
struct _SplitStyleKey: EnvironmentKey { static var defaultValue: Int { 0 } }
extension EnvironmentValues {
    var _splitColumn: _SplitColumnConfig? { get { self[_SplitColumnKey.self] } set { self[_SplitColumnKey.self] = newValue } }
    /// 0 automatic, 1 balanced, 2 prominentDetail
    var _splitStyle: Int { get { self[_SplitStyleKey.self] } set { self[_SplitStyleKey.self] = newValue } }
}
extension View {
    public func navigationSplitViewStyle<S: NavigationSplitViewStyle>(_ style: S) -> some View {
        let id = style is ProminentDetailNavigationSplitViewStyle ? 2 : style is BalancedNavigationSplitViewStyle ? 1 : 0
        return _env { $0._splitStyle = id }
    }
    public func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View {
        _modify { ctx, c in ctx.environment._splitColumn?.width = width; return _resolve(c, ctx.child("scw")) }
    }
    public func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View { navigationSplitViewColumnWidth(ideal) }
}

/// On iPhone (compact width) the columns are a navigation stack: the sidebar is the root; choosing a row of a List
/// with a selection binding in a column shows the next column. Back returns to the previous column.
/// On iPad (regular width) the columns sit side by side, each with its own navigation bar; the sidebar button in the
/// next column's bar shows or hides the sidebar (columnVisibility follows).
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View, _PrimitiveView {
    let sidebar: Sidebar, content: Content?, detail: Detail
    var visibility: Binding<NavigationSplitViewVisibility>? = nil
    var compactColumn: Binding<NavigationSplitViewColumn>? = nil
    public var body: Never { fatalError() }
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar(); self.content = content(); self.detail = detail()
    }
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar, content: content, detail: detail); visibility = columnVisibility
    }
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, preferredCompactColumn: Binding<NavigationSplitViewColumn>,
                @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar, content: content, detail: detail); visibility = columnVisibility; compactColumn = preferredCompactColumn
    }
    func _makeNode(_ ctx: _Context) -> _Node {
        let g = ctx.graph
        let width = g.hostView?.bounds.width ?? UIScreen.main.bounds.width
        if width >= 700 { return _regular(ctx, width: width) }
        let key = ctx.path + "#column"
        let start: Int = { guard let c = compactColumn?.wrappedValue else { return 0 }; return c == .detail ? (content == nil ? 1 : 2) : c == .content ? 1 : 0 }()
        let st = (g.storage[key] as? _StateStorage<Int>) ?? { let s = _StateStorage(start); g.storage[key] = s; return s }()
        g.usedKeys.insert(key)
        let cc = compactColumn, hasContent = content != nil
        let set: (Int) -> Void = { [weak g] v in
            if st.value != v { st.value = v; cc?.wrappedValue = v == 0 ? .sidebar : (v == 1 && hasContent) ? .content : .detail; g?.invalidate() }
        }
        let show = { (n: Int) in Binding<Bool>(get: { st.value >= n }, set: { if !$0 { set(n - 1) } }) }
        let stack: AnyView
        if let content {
            stack = AnyView(NavigationStack {
                sidebar.environment(\._splitAdvance, { set(1) })
                    .navigationDestination(isPresented: show(1)) {
                        content.environment(\._splitAdvance, { set(2) })
                            .navigationDestination(isPresented: show(2)) { detail }
                    }
            })
        } else {
            stack = AnyView(NavigationStack {
                sidebar.environment(\._splitAdvance, { set(1) })
                    .navigationDestination(isPresented: show(1)) { detail }
            })
        }
        return _resolve(stack, ctx.child("split"))
    }
    /// iPad: the columns side by side.
    func _regular(_ ctx: _Context, width: CGFloat) -> _Node {
        let g = ctx.graph, key = ctx.path + "#visibility"
        let three = content != nil
        let st = (g.storage[key] as? _StateStorage<NavigationSplitViewVisibility>) ?? { let s = _StateStorage(NavigationSplitViewVisibility.automatic); g.storage[key] = s; return s }()
        g.usedKeys.insert(key)
        let binding = visibility
        var vis = binding?.wrappedValue ?? st.value
        let style = ctx.environment._splitStyle
        if vis == .automatic { vis = !three ? .all : width >= 1100 ? .all : .doubleColumn }
        let setVis: (NavigationSplitViewVisibility) -> Void = { [weak g] v in
            if let b = binding { b.wrappedValue = v } else { st.value = v; g?.invalidate() }
        }
        let showSidebar = vis == .all || (!three && vis == .doubleColumn), showContent = three && vis != .detailOnly
        let toggle = AnyView(Button { setVis(showSidebar ? (three ? .doubleColumn : .detailOnly) : .all) } label: { Image(systemName: "sidebar.left") }
            .accessibilityIdentifier("isim-split-toggle"))
        func column(_ v: some View, _ name: String, toggle: Bool) -> (_Node, _SplitColumnConfig) {
            let cfg = _SplitColumnConfig()
            let wrapped = AnyView(NavigationStack { toggleWrap(AnyView(v), toggle) })
            let n = _resolve(wrapped, ctx.child(name).with { $0._splitColumn = cfg; $0._splitAdvance = nil })
            return (n, cfg)
        }
        func toggleWrap(_ v: AnyView, _ on: Bool) -> AnyView {
            on ? AnyView(v.toolbar { ToolbarItem(placement: .topBarLeading) { toggle } }) : v
        }
        let sb = column(sidebar, "sidebar", toggle: false)
        let firstAfterSidebar = three && showContent ? "content" : "detail"
        let ct = content.map { column($0, "content", toggle: firstAfterSidebar == "content") }
        let dt = column(detail, "detail", toggle: firstAfterSidebar == "detail")
        var cols: [_SplitNode.Column] = [.init(node: sb.0, width: sb.1.width ?? (three ? 260 : 320), visible: showSidebar, kind: 0)]
        if let ct { cols.append(.init(node: ct.0, width: ct.1.width ?? 320, visible: showContent, kind: 1)) }
        cols.append(.init(node: dt.0, width: nil, visible: true, kind: 2))
        return _SplitNode(path: ctx.path, columns: cols, overlaySidebar: style == 2)
    }
}
extension NavigationSplitView where Content == EmptyView {
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) { self.sidebar = sidebar(); self.content = nil; self.detail = detail() }
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar, detail: detail); visibility = columnVisibility
    }
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, preferredCompactColumn: Binding<NavigationSplitViewColumn>,
                @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar, detail: detail); visibility = columnVisibility; compactColumn = preferredCompactColumn
    }
}

/// Columns side by side (regular width): hidden columns are not shown; with prominentDetail the sidebar floats over
/// the detail instead of narrowing it.
final class _SplitNode: _Node {
    struct Column { let node: _Node; let width: CGFloat?; let visible: Bool; let kind: Int }
    let columns: [Column], overlaySidebar: Bool
    var frames: [CGRect] = []
    init(path: String, columns: [Column], overlaySidebar: Bool) {
        self.columns = columns; self.overlaySidebar = overlaySidebar
        super.init(path: path, children: columns.map(\.node))
    }
    override var ignoresSafeArea: Bool { true }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 700, 1e6), height: min(p.height ?? 700, 1e6)) }
    override func place(_ rect: CGRect) {
        frame = rect
        frames = []
        var x: CGFloat = 0
        for c in columns {
            if !c.visible { frames.append(CGRect(x: -(c.width ?? 320), y: 0, width: c.width ?? 320, height: rect.height)); continue }
            let floating = overlaySidebar && c.kind == 0
            let w = c.width ?? max(200, rect.width - x)
            let f = CGRect(x: x, y: 0, width: min(w, rect.width - x), height: rect.height)
            frames.append(f)
            if !floating { x = f.maxX }
        }
        for (c, f) in zip(columns, frames) { c.node.place(f) }
    }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        // a floating sidebar (prominentDetail) draws over the other columns
        let order = columns.indices.sorted { (overlaySidebar && columns[$0].kind == 0 ? 9 : $0) < (overlaySidebar && columns[$1].kind == 0 ? 9 : $1) }
        for i in order {
            let c = columns[i]
            let host = g.view(path + "|col\(i)") { _PassthroughView() }
            if host.superview !== view { view.addSubview(host) } else { view.bringSubviewToFront(host) }
            host.frame = view.bounds
            host.isHidden = !c.visible
            host.accessibilityIdentifier = ["isim-split-sidebar", "isim-split-content", "isim-split-detail"][c.kind]
            g.mount(c.node, in: host, order: 0)
            if c.visible, c.kind != 2 {
                let sep = g.view(path + "|sep\(i)") { UIView() }
                sep.backgroundColor = .separator
                if sep.superview !== view { view.addSubview(sep) } else { view.bringSubviewToFront(sep) }
                sep.frame = CGRect(x: frames[i].maxX - 0.5, y: 0, width: 0.5, height: view.bounds.height)
                if overlaySidebar && c.kind == 0 { host.layer.shadowColor = UIColor.black.cgColor; host.layer.shadowOpacity = 0.15; host.layer.shadowRadius = 10 }
            } else if let sep = g.views[path + "|sep\(i)"] { sep.removeFromSuperview(); g.views[path + "|sep\(i)"] = nil }
        }
    }
}

// MARK: - Toolbar visibility, background, colour scheme

/// `.toolbar(.hidden, for: .tabBar)` in the visible tab's content (or its top navigation level) hides the tab bar.
final class _TabBarVisibilityNode: _WrapperNode {
    let hidden: Bool
    init(path: String, hidden: Bool, child: _Node) { self.hidden = hidden; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override var ignoresSafeArea: Bool { child.ignoresSafeArea }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
@MainActor func _tabBarHidden(_ n: _Node) -> Bool {
    if let v = n as? _TabBarVisibilityNode, v.hidden { return true }
    return n.children.contains { _tabBarHidden($0) }
}
extension View {
    public func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View {
        _modify { ctx, c in
            let nav = bars.isEmpty || bars.contains { $0.id == 0 || $0.id == 1 }
            if nav { ctx.nav?.barHidden = visibility == .hidden }
            if bars.contains(where: { $0.id == 3 }) { ctx.nav?.bottomBarHidden = visibility == .hidden }
            let node = _resolve(c, ctx.child("tbv"))
            if bars.contains(where: { $0.id == 2 }) { return _TabBarVisibilityNode(path: ctx.path, hidden: visibility == .hidden, child: node) }
            return node
        }
    }
    public func toolbarBackground(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View {
        _modify { ctx, c in
            if bars.isEmpty || bars.contains(where: { $0.id <= 1 }) { ctx.nav?.barBackgroundVisibility = visibility }
            return _resolve(c, ctx.child("tbb"))
        }
    }
    public func toolbarBackground<S: ShapeStyle>(_ style: S, for bars: ToolbarPlacement...) -> some View {
        _modify { ctx, c in
            if bars.isEmpty || bars.contains(where: { $0.id <= 1 }) { ctx.nav?.barBackground = _color(of: style, ctx.environment) }
            if bars.contains(where: { $0.id == 3 }) { ctx.nav?.bottomBarBackground = _color(of: style, ctx.environment) }
            return _resolve(c, ctx.child("tbs"))
        }
    }
    public func toolbarColorScheme(_ scheme: ColorScheme?, for bars: ToolbarPlacement...) -> some View {
        _modify { ctx, c in
            if bars.isEmpty || bars.contains(where: { $0.id <= 1 }) { ctx.nav?.barScheme = scheme }
            return _resolve(c, ctx.child("tbc"))
        }
    }
    public func toolbarTitleDisplayMode(_ mode: ToolbarTitleDisplayMode) -> some View {
        navigationBarTitleDisplayMode(mode.id == 1 ? .inline : mode.id == 2 ? .large : .automatic)
    }
    public func navigationBarHidden(_ hidden: Bool) -> some View { toolbar(hidden ? .hidden : .automatic, for: .navigationBar) }
}
public struct ToolbarTitleDisplayMode: Sendable {
    let id: Int
    public static let automatic = Self(id: 0), inline = Self(id: 1), large = Self(id: 2), inlineLarge = Self(id: 2)
}
public struct ToolbarRole: Sendable {
    let id: Int
    public static let automatic = Self(id: 0), navigationStack = Self(id: 1), browser = Self(id: 2), editor = Self(id: 3)
}

// MARK: - Sheet detents

@MainActor final class _SheetConfig {
    var detents: Set<PresentationDetent>?
    var selection: Binding<PresentationDetent>?
    var indicator: Visibility = .automatic
    var background: Color?
    var cornerRadius: CGFloat?
    var dismissDisabled = false
    var custom = false
    // Presentation+More.swift: popover compact adaptation, presentationSizing, background interaction
    var compactAdaptation = 0
    var sizing = 0
    var backgroundInteraction = false
    var undimmedUpThrough: PresentationDetent?
}
struct _SheetConfigKey: EnvironmentKey { static var defaultValue: _SheetConfig? { nil } }
extension EnvironmentValues { var _sheetConfig: _SheetConfig? { get { self[_SheetConfigKey.self] } set { self[_SheetConfigKey.self] = newValue } } }

extension View {
    public func presentationDetents(_ detents: Set<PresentationDetent>) -> some View {
        _modify { ctx, c in ctx.environment._sheetConfig?.detents = detents; return _resolve(c, ctx.child("pd")) }
    }
    public func presentationDetents(_ detents: Set<PresentationDetent>, selection: Binding<PresentationDetent>) -> some View {
        _modify { ctx, c in
            ctx.environment._sheetConfig?.detents = detents; ctx.environment._sheetConfig?.selection = selection
            return _resolve(c, ctx.child("pd"))
        }
    }
    public func presentationDragIndicator(_ visibility: Visibility) -> some View {
        _modify { ctx, c in ctx.environment._sheetConfig?.indicator = visibility; return _resolve(c, ctx.child("pdi")) }
    }
    public func presentationCornerRadius(_ radius: CGFloat?) -> some View {
        _modify { ctx, c in ctx.environment._sheetConfig?.cornerRadius = radius; return _resolve(c, ctx.child("pcr")) }
    }
    public func presentationBackground<S: ShapeStyle>(_ style: S) -> some View {
        _modify { ctx, c in ctx.environment._sheetConfig?.background = _color(of: style, ctx.environment); return _resolve(c, ctx.child("pbg")) }
    }
    /// `.enabled`: no dimming; the views behind a detent sheet stay interactive (`.enabled(upThrough:)`: up to that detent).
    public func presentationBackgroundInteraction(_ interaction: PresentationBackgroundInteraction) -> some View {
        _modify { ctx, c in
            ctx.environment._sheetConfig?.backgroundInteraction = interaction.id == 1
            ctx.environment._sheetConfig?.undimmedUpThrough = interaction.upThrough
            return _resolve(c, ctx.child("pbi"))
        }
    }
    /// Stored (isim's sheets resize and scroll their content the same way).
    public func presentationContentInteraction(_ behavior: PresentationContentInteraction) -> some View { self }
    /// How a popover adapts on iPhone: `.popover` / `.none` keep the popover, `.sheet`, `.fullScreenCover`.
    public func presentationCompactAdaptation(_ adaptation: PresentationAdaptation) -> some View {
        _modify { ctx, c in ctx.environment._sheetConfig?.compactAdaptation = adaptation.id; return _resolve(c, ctx.child("pca")) }
    }
    public func presentationCompactAdaptation(horizontal: PresentationAdaptation, vertical: PresentationAdaptation) -> some View {
        presentationCompactAdaptation(horizontal)
    }
}
public struct PresentationBackgroundInteraction: Sendable {
    let id: Int
    var upThrough: PresentationDetent? = nil
    init(id: Int) { self.id = id }
    public static let automatic = Self(id: 0), enabled = Self(id: 1), disabled = Self(id: 2)
    public static func enabled(upThrough detent: PresentationDetent) -> Self { var i = Self(id: 1); i.upThrough = detent; return i }
}
public struct PresentationContentInteraction: Sendable { let id: Int; public static let automatic = Self(id: 0), resizes = Self(id: 1), scrolls = Self(id: 2) }
public struct PresentationAdaptation: Sendable { let id: Int; public static let automatic = Self(id: 0), none = Self(id: 1), popover = Self(id: 2), sheet = Self(id: 3), fullScreenCover = Self(id: 4) }

/// Renders the sheet content once off screen to learn its detents; sheets that are not just `.large` are
/// presented over the full screen with isim's own card (returns true).
@MainActor func _prepareDetentSheet(_ hc: _SUIPresentedHostingController, _ config: _SheetConfig, from presenter: UIView?,
                                    content: @escaping () -> AnyView, dismiss: @escaping () -> Void) -> Bool {
    guard let w = presenter?.window else { return false }
    hc.view.frame = w.bounds
    hc.view.setNeedsLayout(); hc.view.layoutIfNeeded()
    guard let d = config.detents, !d.isEmpty, d != [.large] else { return false }
    config.custom = true
    _ = UIApplication.shared._isim_firstResponder?.resignFirstResponder()      // the keyboard goes away, as for a sheet
    hc.modalPresentationStyle = .overFullScreen
    hc.view.backgroundColor = .clear
    hc.rootView = AnyView(_DetentSheet(config: config, content: content, dismiss: dismiss))
    return true
}

func _detentHeight(_ d: PresentationDetent, full: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) -> CGFloat {
    switch d.id {
    case "large": return full - safeTop - 10
    case "medium": return (full * 0.5).rounded()
    default:
        if d.id.hasPrefix("f"), let f = Double(d.id.dropFirst()) { return min(full - safeTop - 10, full * CGFloat(f)) }
        if d.id.hasPrefix("h"), let h = Double(d.id.dropFirst()) { return min(full - safeTop - 10, CGFloat(h) + safeBottom) }
        return full * 0.5
    }
}

/// The card: dimmed backdrop, grabber, the content at the detent's height.
struct _DetentSheet: View, _PrimitiveView {
    let config: _SheetConfig, content: () -> AnyView, dismiss: () -> Void
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let g = ctx.graph, key = ctx.path + "#detent"
        let st = (g.storage[key] as? _StateStorage<CGFloat?>) ?? { let s = _StateStorage<CGFloat?>(nil); g.storage[key] = s; return s }()
        let dragKey = ctx.path + "#detentdrag"
        let drag = (g.storage[dragKey] as? _StateStorage<CGFloat>) ?? { let s = _StateStorage<CGFloat>(0); g.storage[dragKey] = s; return s }()
        g.usedKeys.insert(key); g.usedKeys.insert(dragKey)
        let full = g.hostView?.bounds.height ?? UIScreen.main.bounds.height
        let safeTop = g.hostView?.window?.safeAreaInsets.top ?? g.safeArea.top
        let safeBottom = g.hostView?.window?.safeAreaInsets.bottom ?? g.safeArea.bottom
        let detents = Array(config.detents ?? [.large])
        let heights = detents.map { ($0, _detentHeight($0, full: full, safeTop: safeTop, safeBottom: safeBottom)) }.sorted { $0.1 < $1.1 }
        let selected = config.selection.flatMap { s in heights.first { $0.0 == s.wrappedValue }?.1 }
        let base = st.value ?? selected ?? heights.first?.1 ?? full * 0.5
        let h = max(0, base - drag.value)
        let cfg = config, close = dismiss
        let showGrabber = config.indicator == .visible || (config.indicator == .automatic && detents.count > 1)
        let redraw = { [weak g] in g?.invalidate() }
        let card = VStack(spacing: 0) {
            ZStack {
                Color.clear
                if showGrabber { Capsule().fill(Color("grabber") { .tertiaryLabel }).frame(width: 36, height: 5) }
            }
            .frame(height: 20)
            .overlay {
                _SheetGrabberArea(changed: { dy in drag.value = dy; redraw() }, ended: { dy in
                    let target = base - dy
                    drag.value = 0
                    if !cfg.dismissDisabled, target < (heights.first?.1 ?? 0) * 0.6 { redraw(); close(); return }
                    let best = heights.min { abs($0.1 - target) < abs($1.1 - target) }
                    st.value = best?.1
                    if let d = best?.0 { cfg.selection?.wrappedValue = d }
                    withAnimation(.easeOut(duration: 0.25)) { redraw() }
                })
            }
            .accessibilityIdentifier("sheet-grabber")
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: h)
        .background(config.background ?? Color("sheet-bg") { .systemBackground })
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius ?? 10))
        // .presentationBackgroundInteraction(.enabled): no dimming, touches outside the card reach the presenter
        let limit = config.undimmedUpThrough.map { d in _detentHeight(d, full: full, safeTop: safeTop, safeBottom: safeBottom) }
        let undimmed = config.backgroundInteraction && h <= (limit ?? .infinity) + 0.5
        (g.hostView as? _SUIHostView)?.passthrough = undimmed
        let page = ZStack(alignment: .bottom) {
            if undimmed { Color.clear }
            else { Color.black.opacity(0.25).onTapGesture { if !cfg.dismissDisabled { close() } }.accessibilityIdentifier("sheet-dim") }
            _ExactID(id: "sheet-card", content: card.contentShape(Rectangle()))
        }
        .ignoresSafeArea()
        return _resolve(page, ctx.child("detent"))
    }
}

/// The sheet's drag area: follows the finger in window coordinates (the card resizes under it while dragging).
struct _SheetGrabberArea: View, _PrimitiveView {
    let changed: (CGFloat) -> Void, ended: (CGFloat) -> Void
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _SheetGrabberNode(path: ctx.path, changed: changed, ended: ended) }
}
final class _SheetGrabberNode: _Node {
    let changed: (CGFloat) -> Void, ended: (CGFloat) -> Void
    init(path: String, changed: @escaping (CGFloat) -> Void, ended: @escaping (CGFloat) -> Void) {
        self.changed = changed; self.ended = ended; super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 10, 1e6), height: min(p.height ?? 10, 1e6)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUISheetGrabber(frame: .zero) }
        v.changed = changed; v.ended = ended
        return v
    }
}
final class _SUISheetGrabber: UIView {
    var changed: ((CGFloat) -> Void)?, ended: ((CGFloat) -> Void)?
    var startY: CGFloat?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { startY = touches.first?.location(in: nil).y }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let s = startY, let y = touches.first?.location(in: nil).y else { return }
        changed?(y - s)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let s = startY, let y = touches.first?.location(in: nil).y else { return }
        startY = nil
        ended?(y - s)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { if startY != nil { startY = nil; ended?(0) } }
}

/// Puts an accessibility identifier on the view itself (`.accessibilityIdentifier` gives it to the first control inside).
struct _ExactID<Content: View>: View, _PrimitiveView {
    let id: String, content: Content
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { let n = _resolve(content, ctx); n.accessibilityIdentifier = id; return n }
}
