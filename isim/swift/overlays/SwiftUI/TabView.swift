// isim SwiftUI: TabView — the iOS tab bar (material background, SF Symbol icons, titles, badges) or the
// page style (swipe between pages, page dots). Tabs are chosen by .tag / Tab(value:) (or by position).
// Every tab stays mounted (hidden when not selected), so scroll positions and text fields keep their state.
import UIKit

public protocol TabViewStyle {}
public struct DefaultTabViewStyle: TabViewStyle { public init() {} }
public struct PageTabViewStyle: TabViewStyle {
    public struct IndexDisplayMode: Sendable { let show: Bool; public static let automatic = IndexDisplayMode(show: true), always = IndexDisplayMode(show: true), never = IndexDisplayMode(show: false) }
    let mode: IndexDisplayMode
    public init(indexDisplayMode: IndexDisplayMode = .automatic) { mode = indexDisplayMode }
}
public struct SidebarAdaptableTabViewStyle: TabViewStyle { public init() {} }
public struct TabBarOnlyTabViewStyle: TabViewStyle { public init() {} }
extension TabViewStyle where Self == DefaultTabViewStyle { public static var automatic: DefaultTabViewStyle { .init() } }
extension TabViewStyle where Self == PageTabViewStyle {
    public static var page: PageTabViewStyle { .init() }
    public static func page(indexDisplayMode: PageTabViewStyle.IndexDisplayMode) -> PageTabViewStyle { .init(indexDisplayMode: indexDisplayMode) }
}
extension TabViewStyle where Self == SidebarAdaptableTabViewStyle { public static var sidebarAdaptable: SidebarAdaptableTabViewStyle { .init() } }
extension TabViewStyle where Self == TabBarOnlyTabViewStyle { public static var tabBarOnly: TabBarOnlyTabViewStyle { .init() } }

enum _TabStyle { case bar, page(showDots: Bool) }
struct _TabStyleKey: EnvironmentKey { static var defaultValue: _TabStyle { .bar } }
extension EnvironmentValues { var _tabStyle: _TabStyle { get { self[_TabStyleKey.self] } set { self[_TabStyleKey.self] = newValue } } }

extension View {
    public func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View {
        let k: _TabStyle = (style as? PageTabViewStyle).map { .page(showDots: $0.mode.show) } ?? .bar
        return _env { $0._tabStyle = k }
    }
    public func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> some View {
        let l = label()
        return _modify { ctx, c in
            let n = _resolve(c, ctx)
            n.tabItem = _resolve(l, ctx.child("tabItem"))
            return n
        }
    }
    public func badge(_ count: Int) -> some View {
        _modify { ctx, c in let n = _resolve(c, ctx); n.badge = count == 0 ? nil : "\(count)"; return n }
    }
    @_disfavoredOverload public func badge<S: StringProtocol>(_ label: S?) -> some View {
        _modify { ctx, c in let n = _resolve(c, ctx); n.badge = label.map { String($0) }; return n }
    }
    public func badge(_ label: Text?) -> some View {
        _modify { ctx, c in let n = _resolve(c, ctx); n.badge = label?.string; return n }
    }
    public func toolbarBackground(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
}
public struct ToolbarPlacement: Sendable {
    let id: Int
    public static let automatic = ToolbarPlacement(id: 0), navigationBar = ToolbarPlacement(id: 1), tabBar = ToolbarPlacement(id: 2), bottomBar = ToolbarPlacement(id: 3)
}

/// iOS 18 tabs: `Tab("Title", systemImage: "house", value: .home) { ... }`
public struct Tab<Value: Hashable, Content: View, Label: View>: View, _PrimitiveView {
    let value: Value?, content: Content, label: Label
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _resolve(content, ctx.child("c"))
        n.tabItem = _resolve(label, ctx.child("label"))
        if let value { n.tag = AnyHashable(value) }
        return n
    }
}
extension Tab where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.value = value; self.content = content(); label = SwiftUI.Label(titleKey, systemImage: systemImage)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
        self.value = value; self.content = content(); label = SwiftUI.Label(title, systemImage: systemImage)
    }
}
extension Tab where Value == Never, Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {
        value = nil; self.content = content(); label = SwiftUI.Label(titleKey, systemImage: systemImage)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) {
        value = nil; self.content = content(); label = SwiftUI.Label(title, systemImage: systemImage)
    }
}

public struct TabView<SelectionValue: Hashable, Content: View>: View, _PrimitiveView {
    let selection: Binding<SelectionValue>?, content: Content
    public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) { self.selection = selection; self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let g = ctx.graph
        let style = ctx.environment._tabStyle
        // tab content sits above the tab bar: no bottom safe area inside
        let saved = g.safeArea
        if case .bar = style { g.safeArea.bottom = 0 }
        let children = _flatten([_resolve(content, ctx.child("tabs").with { $0._tabStyle = .bar })])
        g.safeArea = saved
        let tags = children.enumerated().map { i, c in _tagged(c) ?? AnyHashable(i) }
        let key = ctx.path + "#tab"
        g.usedKeys.insert(key)
        let stored = (g.storage[key] as? _StateStorage<AnyHashable>) ?? { let s = _StateStorage<AnyHashable>(tags.first ?? AnyHashable(0)); g.storage[key] = s; return s }()
        let current = selection.map { AnyHashable($0.wrappedValue) } ?? stored.value
        let index = tags.firstIndex(of: current) ?? 0
        let sel = selection
        let select: (Int) -> Void = { [weak g] i in
            guard i >= 0, i < tags.count else { return }
            if let sel { if let v = tags[i].base as? SelectionValue { sel.wrappedValue = v } }
            else { stored.value = tags[i]; g?.invalidate() }
        }
        let items = children.map { c -> _TabItemInfo in
            var x: _Node? = c, item: _Node?, badge: String?
            while let n = x { if item == nil { item = n.tabItem }; if badge == nil { badge = n.badge }; x = n.children.count == 1 ? n.children[0] : nil }
            return _TabItemInfo(title: item.map { _collectText($0).joined(separator: " ") } ?? "", image: item.flatMap { _firstImage($0) }, badge: badge)
        }
        let node = _TabViewNode(path: ctx.path, tabs: children, items: items, selected: index, select: select, style: style,
                                tint: (ctx.environment._tint ?? .accentColor).uiColor)
        node.safeTop = saved.top; node.safeBottom = saved.bottom
        return node
    }
}
extension TabView where SelectionValue == Int {
    public init(@ViewBuilder content: () -> Content) { selection = nil; self.content = content() }
}

struct _TabItemInfo { let title: String, image: UIImage?, badge: String? }

final class _TabViewNode: _Node {
    let tabs: [_Node], items: [_TabItemInfo], selected: Int, select: (Int) -> Void, style: _TabStyle, tint: UIColor
    var safeTop: CGFloat = 0, safeBottom: CGFloat = 0
    init(path: String, tabs: [_Node], items: [_TabItemInfo], selected: Int, select: @escaping (Int) -> Void, style: _TabStyle, tint: UIColor) {
        self.tabs = tabs; self.items = items; self.selected = selected; self.select = select; self.style = style; self.tint = tint
        super.init(path: path, children: tabs)
    }
    override var ignoresSafeArea: Bool { if case .bar = style { return true }; return false }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
    var barHeight: CGFloat { 49 + safeBottom }
    override func place(_ rect: CGRect) {
        frame = rect
        let area: CGRect
        if case .bar = style { area = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - barHeight) }
        else { area = CGRect(origin: .zero, size: rect.size) }
        for (i, t) in tabs.enumerated() {
            var r = area
            if case .page = style { r.origin.x = CGFloat(i - selected) * area.width }
            if case .bar = style, !t.ignoresSafeArea { r = CGRect(x: 0, y: safeTop, width: area.width, height: area.height - safeTop) }
            if t.ignoresSafeArea { t.place(r) }
            else {
                let s = t.sizeThatFits(_Proposal(width: r.width, height: r.height))
                t.place(CGRect(x: r.minX + (r.width - min(s.width, r.width)) / 2, y: r.minY + (r.height - min(s.height, r.height)) / 2,
                               width: min(s.width, r.width), height: min(s.height, r.height)))
            }
        }
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIPager(frame: .zero) }
        v.clipsToBounds = true
        v.node = self
        return v
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        let isPage: Bool = { if case .page = style { return true }; return false }()
        for (i, t) in tabs.enumerated() {
            let container = g.view(path + "|tab\(i)") { _PassthroughView() }
            if container.superview !== view { view.addSubview(container) }
            container.frame = view.bounds
            container.isHidden = !isPage && i != selected
            g.mount(t, in: container, order: 0)
        }
        if case .page(let dots) = style {
            let pc = g.view(path + "|dots") { UIPageControl() }
            if pc.superview !== view { view.addSubview(pc) } else { view.bringSubviewToFront(pc) }
            pc.numberOfPages = tabs.count; pc.currentPage = selected
            pc.isHidden = !dots || tabs.count < 2
            pc.currentPageIndicatorTintColor = .label; pc.pageIndicatorTintColor = .tertiaryLabel
            let s = pc.sizeThatFits(.zero)
            pc.frame = CGRect(x: (view.bounds.width - s.width) / 2, y: view.bounds.height - safeBottom - s.height - 8, width: s.width, height: s.height)
            pc.isUserInteractionEnabled = false
        } else {
            let bar = g.view(path + "|bar") { _SUITabBar(frame: .zero) }
            if bar.superview !== view { view.addSubview(bar) } else { view.bringSubviewToFront(bar) }
            bar.frame = CGRect(x: 0, y: view.bounds.height - barHeight, width: view.bounds.width, height: barHeight)
            bar.update(items: items, selected: selected, tint: tint, select: select)
        }
    }
}

/// The page-style container: horizontal swipes move between pages.
final class _SUIPager: UIView {
    var node: _TabViewNode?
    var pan: UIPanGestureRecognizer?
    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if pan == nil { let p = UIPanGestureRecognizer(target: self, action: #selector(panned(_:))); addGestureRecognizer(p); pan = p }
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        if v === self, let n = node, case .page = n.style { return self }        // pages take swipes
        return v === self ? nil : v
    }
    @objc func panned(_ g: UIPanGestureRecognizer) {
        guard let n = node, case .page = n.style else { return }
        let dx = g.translation(in: self).x
        let pages = subviews.filter { !($0 is UIPageControl) }
        switch g.state {
        case .changed:
            UIView.performWithoutAnimation {
                for (i, p) in pages.enumerated() { p.frame.origin.x = CGFloat(i - n.selected) * bounds.width + dx }
            }
        case .ended, .cancelled:
            let vx = g.velocity(in: self).x
            var target = n.selected
            if dx < -bounds.width / 4 || vx < -500 { target += 1 } else if dx > bounds.width / 4 || vx > 500 { target -= 1 }
            target = max(0, min(n.tabs.count - 1, target))
            _AnimationContext.pending = .spring(response: 0.4, dampingFraction: 0.9)
            _AnimationContext.pendingStamp = Date().timeIntervalSinceReferenceDate
            if target != n.selected { n.select(target) }
            else { UIView.animate(withDuration: 0.3) { for (i, p) in pages.enumerated() { p.frame.origin.x = CGFloat(i - n.selected) * self.bounds.width } } }
        default: break
        }
    }
}
/// The iOS tab bar: material background, hairline, icon + title items, badges.
final class _SUITabBar: UIView {
    let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    let hairline = UIView()
    var buttons: [_SUITabButton] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backdrop)
        hairline.backgroundColor = .separator
        addSubview(hairline)
        accessibilityIdentifier = "isim-tabbar"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func update(items: [_TabItemInfo], selected: Int, tint: UIColor, select: @escaping (Int) -> Void) {
        backdrop.frame = bounds
        hairline.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        while buttons.count < items.count { let b = _SUITabButton(frame: .zero); addSubview(b); buttons.append(b) }
        while buttons.count > items.count { buttons.removeLast().removeFromSuperview() }
        let w = bounds.width / CGFloat(max(1, items.count))
        for (i, it) in items.enumerated() {
            let b = buttons[i]
            b.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: 49)
            b.configure(it, selected: i == selected, tint: tint)
            b.action = { select(i) }
            b.accessibilityIdentifier = "tab-" + (it.title.isEmpty ? "\(i)" : it.title)
        }
    }
}
final class _SUITabButton: UIControl {
    let icon = UIImageView(), title = UILabel(), badge = UILabel()
    var action: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.contentMode = .scaleAspectFit
        title.font = .systemFont(ofSize: 10, weight: .medium); title.textAlignment = .center
        badge.font = .systemFont(ofSize: 13, weight: .regular); badge.textColor = .white; badge.textAlignment = .center
        badge.backgroundColor = .systemRed; badge.clipsToBounds = true
        for v in [icon, title, badge] as [UIView] { v.isUserInteractionEnabled = false; addSubview(v) }
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func fire() { action?() }
    func configure(_ it: _TabItemInfo, selected: Bool, tint: UIColor) {
        let color = selected ? tint : UIColor.systemGray
        let w = bounds.width
        icon.image = it.image?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = color
        let s = icon.image?.size ?? .zero, k = 24 / max(1, max(s.width, s.height))      // symbols scale cleanly
        icon.frame = CGRect(x: (w - s.width * k) / 2, y: 7 + (25 - s.height * k) / 2, width: s.width * k, height: s.height * k)
        title.text = it.title; title.textColor = color
        title.frame = CGRect(x: 2, y: 33, width: w - 4, height: 13)
        badge.isHidden = it.badge == nil
        if let b = it.badge {
            badge.text = b
            let bw = max(18, badge.sizeThatFits(CGSize(width: 100, height: 18)).width + 10)
            badge.frame = CGRect(x: w / 2 + 6, y: 3, width: bw, height: 18)
            badge.layer.cornerRadius = 9
        }
    }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.5 : 1 } }
}
