// isim SwiftUI: more TabView.
// - TabSection (iOS 18): groups tabs; flat in the tab bar, headed groups in the iPad sidebar.
// - .tabViewStyle(.sidebarAdaptable) on iPad: a sidebar button by the top tab bar shows a sidebar with the sections
//   and tabs (the tab bar hides while it shows); iPhone: the tab bar. tabViewCustomization is accepted (stored only).
// - iOS 26 tabViewBottomAccessory: a glass capsule above the floating tab bar (inline beside it when minimized);
//   tabBarMinimizeBehavior(.onScrollDown / .onScrollUp): scrolling the selected tab shrinks the bar to the selected
//   tab's circle. Adapted to isim's glass drawing; the iOS 18 look has no accessory or minimizing (like iOS 18).
import UIKit

struct _TabAccessoryKey: EnvironmentKey { static var defaultValue: AnyView? { nil } }
struct _TabMinimizeKey: EnvironmentKey { static var defaultValue: Int { 0 } }
struct _TabSidebarKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _TabAccessoryPlacementKey: EnvironmentKey { static var defaultValue: Int { 0 } }
extension EnvironmentValues {
    var _tabAccessory: AnyView? { get { self[_TabAccessoryKey.self] } set { self[_TabAccessoryKey.self] = newValue } }
    var _tabMinimize: Int { get { self[_TabMinimizeKey.self] } set { self[_TabMinimizeKey.self] = newValue } }
    var _tabSidebarAdaptable: Bool { get { self[_TabSidebarKey.self] } set { self[_TabSidebarKey.self] = newValue } }
    var _tabAccessoryPlacement: Int { get { self[_TabAccessoryPlacementKey.self] } set { self[_TabAccessoryPlacementKey.self] = newValue } }
    /// iOS 26: where the bottom accessory currently is (`.expanded` above the tab bar, `.inline` beside a minimized one).
    @available(iOS 26.0, *)
    public var tabViewBottomAccessoryPlacement: TabViewBottomAccessoryPlacement? {
        get { _tabAccessoryPlacement == 1 ? .expanded : _tabAccessoryPlacement == 2 ? .inline : nil }
        set { _tabAccessoryPlacement = newValue == .expanded ? 1 : newValue == .inline ? 2 : 0 }
    }
}
@available(iOS 26.0, *)
public enum TabViewBottomAccessoryPlacement: Hashable, Sendable { case expanded, inline }

/// A group of tabs (iOS 18): in the tab bar the tabs are listed in order; the iPad sidebar heads them with the title.
@available(iOS 18.0, *)
public struct TabSection<Header: View, Content: View, Footer: View>: View, _PrimitiveView {
    let title: String?, content: Content
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let tabs = _flatten([_resolve(content, ctx.child("tabs"))])
        for t in tabs where t.tabSection == nil { t.tabSection = title ?? "" }
        return _GroupNode(path: ctx.path, children: tabs)
    }
}
@available(iOS 18.0, *)
extension TabSection where Header == Text, Footer == EmptyView {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { title = titleKey.resolved(); self.content = content() }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) { self.title = String(title); self.content = content() }
}
@available(iOS 18.0, *)
extension TabSection where Header == EmptyView, Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content) { title = nil; self.content = content() }
}

/// Tab bar / sidebar customization (iOS 18). isim: stored only — tabs cannot be reordered or hidden by the user.
@available(iOS 18.0, *)
public struct TabViewCustomization: Equatable, Codable, Sendable {
    public init() {}
}
extension View {
    @available(iOS 18.0, *)
    public func tabViewCustomization(_ customization: Binding<TabViewCustomization>?) -> some View { self }
    @available(iOS 18.0, *)
    public func customizationID(_ id: String) -> some View { self }
    /// iOS 26: an accessory above the tab bar (a glass capsule; beside the bar when it is minimized).
    @available(iOS 26.0, *)
    public func tabViewBottomAccessory<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let v = AnyView(content())
        return _env { $0._tabAccessory = v }
    }
    /// iOS 26: the tab bar shrinks to the selected tab while the selected tab's content scrolls.
    @available(iOS 26.0, *)
    public func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View {
        let id = behavior.id
        return _env { $0._tabMinimize = id }
    }
}

/// Reads the TabView extras from the environment and its state (called by TabView._makeNode).
@MainActor func _tabExtras(_ node: _TabViewNode, _ ctx: _Context) {
    let g = ctx.graph, env = ctx.environment
    let mkey = ctx.path + "#tabmin", skey = ctx.path + "#tabsidebar"
    let mst = (g.storage[mkey] as? _StateStorage<Bool>) ?? { let s = _StateStorage(false); g.storage[mkey] = s; return s }()
    let sst = (g.storage[skey] as? _StateStorage<Bool>) ?? { let s = _StateStorage(false); g.storage[skey] = s; return s }()
    g.usedKeys.insert(mkey); g.usedKeys.insert(skey)
    let glass = _isimOSMajor() >= 26
    node.minimizeBehavior = glass ? env._tabMinimize : 0
    node.minimized = node.minimizeBehavior >= 2 && mst.value
    node.setMinimized = { [weak g] v in
        guard mst.value != v else { return }
        mst.value = v
        _AnimationContext.pending = .easeInOut(duration: 0.3); _AnimationContext.pendingStamp = Date().timeIntervalSinceReferenceDate
        g?.invalidate()
    }
    node.sidebarAdaptable = env._tabSidebarAdaptable && _isimPad
    node.sidebarShown = sst.value
    node.toggleSidebar = { [weak g] in sst.value.toggle(); g?.invalidate() }
    if glass, let acc = env._tabAccessory, case .bar = node.style {
        node.accessory = _resolve(acc, ctx.child("accessory").with { $0._tabAccessoryPlacement = node.minimized ? 2 : 1 })
    }
}

/// The accessory capsule and the iPad sidebar (called by _TabViewNode.mountChildren after the tab bar).
@MainActor func _mountTabExtras(_ node: _TabViewNode, _ g: _Graph, _ view: UIView, _ bar: _SUITabBar) {
    let path = node.path, W = view.bounds.width
    if let acc = node.accessory, !node.barHidden {
        let mode = _tabBarMode()
        let inset: CGFloat = W > 600 ? (W - 560) / 2 : 21
        var frame: CGRect
        if mode == 1 {
            let barTop = bar.frame.minY
            frame = node.minimized ? CGRect(x: inset + 62 + 10, y: barTop + 7, width: W - 2 * inset - 62 - 10 - (node.items.contains { $0.role != 0 } ? 72 : 0), height: 48)
                                   : CGRect(x: inset, y: barTop - 8 - 48, width: W - 2 * inset, height: 48)
        } else {
            frame = CGRect(x: inset, y: (mode >= 2 ? view.bounds.height - node.safeBottom - 56 : bar.frame.minY - 56), width: W - 2 * inset, height: 48)
        }
        let gl = g.view(path + "|accglass") { _SUIGlassView(frame: .zero) }
        if gl.superview !== view { view.addSubview(gl) } else { view.bringSubviewToFront(gl) }
        gl.frame = frame; gl.radius = 24
        gl.accessibilityIdentifier = "isim-tab-accessory"
        let host = g.view(path + "|acchost") { _PassthroughView() }
        if host.superview !== view { view.addSubview(host) } else { view.bringSubviewToFront(host) }
        host.frame = frame.insetBy(dx: 16, dy: 0)
        let s = acc.sizeThatFits(_Proposal(width: host.bounds.width, height: 48))
        acc.place(CGRect(x: 0, y: (48 - min(s.height, 48)) / 2, width: min(s.width, host.bounds.width), height: min(s.height, 48)))
        g.mount(acc, in: host, order: 0)
    }
    // iPad sidebarAdaptable: the sidebar button and the sidebar
    guard node.sidebarAdaptable, _tabBarMode() >= 2 else { return }
    let btn = g.view(path + "|sidebarbtn") { _SUIControl(frame: .zero) }
    if btn.superview !== view { view.addSubview(btn) } else { view.bringSubviewToFront(btn) }
    let icon = g.view(path + "|sidebaricon") { UIImageView() }
    if icon.superview !== btn { btn.addSubview(icon) }
    icon.image = UIImage(systemName: "sidebar.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
    icon.tintColor = node.tint
    btn.frame = CGRect(x: 16, y: node.safeTop + 3, width: 44, height: 44)
    let isz = icon.image?.size ?? CGSize(width: 22, height: 18)
    icon.frame = CGRect(x: (44 - isz.width) / 2, y: (44 - isz.height) / 2, width: isz.width, height: isz.height)
    btn.accessibilityIdentifier = "isim-tab-sidebar-toggle"
    btn.action = node.toggleSidebar
    let sb = g.view(path + "|sidebar") { _SUITabSidebar(frame: .zero) }
    if sb.superview !== view { view.addSubview(sb) } else { view.bringSubviewToFront(sb) }
    view.bringSubviewToFront(btn)
    sb.isHidden = !node.sidebarShown
    sb.frame = CGRect(x: 0, y: 0, width: node.sidebarWidth, height: view.bounds.height)
    if node.sidebarShown { sb.update(items: node.items, selected: node.selected, tint: node.tint, top: node.safeTop + 52, select: node.select) }
}

/// The iPad tab sidebar: section headers and tab rows (icon + title); the selected row highlighted.
final class _SUITabSidebar: UIView {
    var rows: [UIView] = []
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .secondarySystemBackground; accessibilityIdentifier = "isim-tab-sidebar" }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func update(items: [_TabItemInfo], selected: Int, tint: UIColor, top: CGFloat, select: @escaping (Int) -> Void) {
        for r in rows { r.removeFromSuperview() }
        rows = []
        var y = top, section: String? = nil
        for (i, it) in items.enumerated() {
            if let s = it.section, s != section, !s.isEmpty {
                let h = UILabel(); h.text = s; h.font = .systemFont(ofSize: 15, weight: .semibold); h.textColor = .secondaryLabel
                h.frame = CGRect(x: 20, y: y + 10, width: bounds.width - 40, height: 22); addSubview(h); rows.append(h); y += 36
            }
            section = it.section
            let row = _SUIControl(frame: CGRect(x: 10, y: y, width: bounds.width - 20, height: 44))
            row.backgroundColor = i == selected ? tint.withAlphaComponent(0.18) : .clear
            row.layer.cornerRadius = 10
            let iv = UIImageView(image: it.image?.withRenderingMode(.alwaysTemplate)); iv.tintColor = tint
            let s = iv.image?.size ?? .zero, k = 20 / max(1, max(s.width, s.height))
            iv.frame = CGRect(x: 12 + (24 - s.width * k) / 2, y: (44 - s.height * k) / 2, width: s.width * k, height: s.height * k)
            let l = UILabel(); l.text = it.title; l.font = .systemFont(ofSize: 17, weight: i == selected ? .semibold : .regular); l.textColor = .label
            l.frame = CGRect(x: 48, y: 0, width: row.bounds.width - 56, height: 44)
            row.addSubview(iv); row.addSubview(l)
            row.accessibilityIdentifier = "sidebar-" + (it.title.isEmpty ? "\(i)" : it.title)
            row.action = { select(i) }
            addSubview(row); rows.append(row)
            y += 46
        }
    }
}
