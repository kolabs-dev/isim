// isim SwiftUI: more TabView.
// - TabSection (iOS 18): groups tabs; flat in the tab bar, headed groups in the iPad sidebar.
// - .tabViewStyle(.sidebarAdaptable) on iPad: a sidebar button by the top tab bar shows a sidebar with the sections
//   and tabs (the tab bar hides while it shows); iPhone: the tab bar. tabViewCustomization: the sidebar's Edit mode
//   hides tabs (a check circle) and moves them within their section (a handle), written to the binding.
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

/// What a person changed in an adaptable sidebar tab view (iOS 18): tabs hidden from the sidebar or the tab bar and the
/// order of the tabs in sections, by customization identifiers; Codable (e.g. in @AppStorage).
@available(iOS 18.0, *)
public struct TabViewCustomization: Equatable, Codable, Sendable {
    public struct TabCustomization: Equatable, Codable, Sendable {
        var sidebar: String? = nil, bar: String? = nil
        public var sidebarVisibility: Visibility { get { _visibility(sidebar) } set { sidebar = _code(newValue) } }
        public var tabBarVisibility: Visibility { get { _visibility(bar) } set { bar = _code(newValue) } }
    }
    public struct SectionCustomization: Equatable, Codable, Sendable {
        public var tabOrder: [String]?
        public mutating func resetTabOrder() { tabOrder = nil }
    }
    var tabs: [String: TabCustomization] = [:]
    var sections: [String: SectionCustomization] = [:]
    public init() {}
    public subscript(tab id: String) -> TabCustomization {
        get { tabs[id] ?? TabCustomization() }
        set { tabs[id] = newValue }
    }
    public subscript(section id: String) -> SectionCustomization {
        get { sections[id] ?? SectionCustomization() }
        set { sections[id] = newValue }
    }
    /// The order of a section's tabs (their customization identifiers), if a person changed it.
    public subscript(sectionID id: String) -> [String]? {
        get { sections[id]?.tabOrder }
        set { sections[id, default: SectionCustomization()].tabOrder = newValue }
    }
    public subscript(sidebarVisibility id: String) -> Visibility {
        get { self[tab: id].sidebarVisibility }
        set { self[tab: id].sidebarVisibility = newValue }
    }
    public mutating func resetVisibility() { tabs = [:] }
    public mutating func resetSectionOrder() { for k in sections.keys { sections[k]?.tabOrder = nil } }
    public mutating func resetSectionOrder(for id: String) { sections[id]?.tabOrder = nil }
}
private func _visibility(_ s: String?) -> Visibility { s == "visible" ? .visible : s == "hidden" ? .hidden : .automatic }
private func _code(_ v: Visibility) -> String? { v == .visible ? "visible" : v == .hidden ? "hidden" : nil }

/// How customizable a tab is.
@available(iOS 18.0, *)
public struct TabCustomizationBehavior: Sendable, Equatable {
    let id: Int
    public static let automatic = TabCustomizationBehavior(id: 0), disabled = TabCustomizationBehavior(id: 1), reorderable = TabCustomizationBehavior(id: 2)
}
/// Where a tab of an adaptable sidebar tab view shows.
@available(iOS 18.0, *)
public struct AdaptableTabBarPlacement: Sendable, Hashable {
    let id: Int
    public static let automatic = AdaptableTabBarPlacement(id: 0), sidebar = AdaptableTabBarPlacement(id: 1), tabBar = AdaptableTabBarPlacement(id: 2)
}
struct _TabCustomizationKey: EnvironmentKey { static var defaultValue: Any? { nil } }      // a Binding<TabViewCustomization>
extension EnvironmentValues {
    var _tabCustomization: Any? { get { self[_TabCustomizationKey.self] } set { self[_TabCustomizationKey.self] = newValue } }
}
@available(iOS 18.0, *)
extension AppStorage where Value == TabViewCustomization {
    /// A tab view customization kept in user defaults (as JSON).
    public init(wrappedValue: Value = TabViewCustomization(), _ key: String, store: UserDefaults? = nil) {
        self.init(key, wrappedValue, store, read: { d, k in (d.object(forKey: k) as? Data).flatMap { try? JSONDecoder().decode(TabViewCustomization.self, from: $0) } },
                  write: { d, k, v in d.set(try? JSONEncoder().encode(v), forKey: k) })
    }
}
extension View {
    /// The customization a person makes to this adaptable sidebar tab view (iPad: the sidebar's Edit mode).
    @available(iOS 18.0, *)
    public func tabViewCustomization(_ customization: Binding<TabViewCustomization>?) -> some View { _env { $0._tabCustomization = customization } }
    /// The identifier a tab (or a TabSection) keeps its customization under.
    @available(iOS 18.0, *)
    public func customizationID(_ id: String) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("cid"))
            if n is _GroupNode { for t in n.children { t.tabSectionID = id } } else { n.tabCustomID = id }      // a TabSection: its tabs
            return n
        }
    }
    /// Whether the tab can be hidden and moved (automatic), only moved (reorderable) or neither (disabled).
    @available(iOS 18.0, *)
    public func customizationBehavior(_ behavior: TabCustomizationBehavior, for placements: AdaptableTabBarPlacement...) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("cbeh"))
            for t in (n is _GroupNode ? n.children : [n]) { t.tabBehavior = behavior.id }
            return n
        }
    }
    /// Whether the tab shows by default in the tab bar or the sidebar.
    @available(iOS 18.0, *)
    public func defaultVisibility(_ visibility: Visibility, for placements: AdaptableTabBarPlacement...) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("dvis"))
            let all = placements.isEmpty || placements.contains(.automatic)
            for t in (n is _GroupNode ? n.children : [n]) {
                if all || placements.contains(.tabBar) { t.tabDefaultHidden.bar = visibility == .hidden }
                if all || placements.contains(.sidebar) { t.tabDefaultHidden.sidebar = visibility == .hidden }
            }
            return n
        }
    }
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
    // Edit (with tabViewCustomization): check circles hide tabs, handles move them within their section
    let ekey = path + "#tabedit"
    g.usedKeys.insert(ekey)
    let est = (g.storage[ekey] as? _StateStorage<Bool>) ?? { let s = _StateStorage(false); g.storage[ekey] = s; return s }()
    sb.customizable = node.setHidden != nil
    sb.editing = est.value && sb.customizable
    sb.toggleEditing = { [weak g] in est.value.toggle(); g?.invalidate() }
    sb.setHidden = node.setHidden; sb.setOrder = node.setOrder
    if node.sidebarShown { sb.update(items: node.items, selected: node.selected, tint: node.tint, top: node.safeTop + 52, select: node.select) }
}

/// The iPad tab sidebar: section headers and tab rows (icon + title); the selected row highlighted. With
/// tabViewCustomization, Edit shows a check circle per tab (hide / show) and a handle that moves it in its section.
final class _SUITabSidebar: UIView {
    var rows: [UIView] = []
    var customizable = false, editing = false
    var toggleEditing: (() -> Void)?
    var setHidden: ((String, Bool) -> Void)?
    var setOrder: ((String, [String]) -> Void)?
    /// a row being moved: its section's rows (customization IDs, in order) and where the row is now
    private var drag: (section: String, ids: [String], rows: [UIView], index: Int, startY: CGFloat)?
    private var lastSignature = ""
    /// each tab row's section and customization ID
    private var rowTab: [ObjectIdentifier: (section: String, id: String)] = [:]
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .secondarySystemBackground; accessibilityIdentifier = "isim-tab-sidebar" }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func update(items: [_TabItemInfo], selected: Int, tint: UIColor, top: CGFloat, select: @escaping (Int) -> Void) {
        // unchanged: keep the rows (a row being dragged stays the one under the finger)
        let signature = "\(items.map { "\($0.title)|\($0.section ?? "")|\($0.hiddenSidebar)|\($0.behavior)" })|\(selected)|\(editing)|\(customizable)|\(bounds.width)|\(top)"
        if signature == lastSignature && drag == nil { return }
        if drag != nil { return }
        lastSignature = signature
        for r in rows { r.removeFromSuperview() }
        rows = []; rowTab = [:]
        if customizable {
            let edit = UIButton(type: .system)
            edit.setTitle(editing ? "Done" : "Edit", for: .normal)
            edit.titleLabel?.font = .systemFont(ofSize: 17, weight: editing ? .semibold : .regular)
            edit.tintColor = tint
            edit.frame = CGRect(x: bounds.width - 76, y: top - 44, width: 64, height: 36)
            edit.accessibilityIdentifier = "sidebar-edit"
            let toggle = toggleEditing
            edit.addAction(UIAction { _ in toggle?() }, for: .touchUpInside)
            addSubview(edit); rows.append(edit)
        }
        var y = top, section: String? = nil
        for (i, it) in items.enumerated() {
            if it.hiddenSidebar && !editing { continue }              // hidden by the person (Edit shows it unchecked)
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
            if editing, let id = it.customID {
                row.action = nil
                // the check circle: shown / hidden (not for tabs whose customization is disabled or only reorderable)
                if it.behavior == 0 {
                    let check = _SUIControl(frame: CGRect(x: row.bounds.width - 76, y: 7, width: 30, height: 30))
                    let img = UIImageView(image: UIImage(systemName: it.hiddenSidebar ? "circle" : "checkmark.circle.fill"))
                    img.tintColor = it.hiddenSidebar ? .tertiaryLabel : tint
                    img.frame = CGRect(x: 4, y: 4, width: 22, height: 22)
                    check.addSubview(img)
                    check.accessibilityIdentifier = "sidebar-check-" + it.title
                    let hide = setHidden, hidden = it.hiddenSidebar
                    check.action = { hide?(id, !hidden) }
                    row.addSubview(check)
                }
                if it.behavior != 1, let sid = it.sectionID {
                    // the handle: drag it up or down to move the tab in its section
                    let handle = UIControl(frame: CGRect(x: row.bounds.width - 38, y: 0, width: 30, height: 44))   // (a control: it takes its touches)
                    let lines = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
                    lines.tintColor = .tertiaryLabel
                    lines.frame = handle.bounds; lines.contentMode = .center
                    handle.addSubview(lines)
                    handle.accessibilityIdentifier = "sidebar-handle-" + it.title
                    handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(moved(_:))))
                    rowTab[ObjectIdentifier(handle)] = (sid, id)
                    row.addSubview(handle)
                }
            }
            if let sid = it.sectionID { rowTab[ObjectIdentifier(row)] = (sid, it.customID ?? "") }
            y += 46
        }
    }
    @objc func moved(_ g: UIPanGestureRecognizer) {
        guard let handle = g.view, let info = rowTab[ObjectIdentifier(handle)], let row = handle.superview else { return }
        let sid = info.section
        if drag == nil && (g.state == .began || g.state == .changed) {
            let sectionRows = rows.filter { rowTab[ObjectIdentifier($0)]?.section == sid }      // (rows only: handles are not in `rows`)
            let ids = sectionRows.compactMap { rowTab[ObjectIdentifier($0)]?.id }
            guard let idx = sectionRows.firstIndex(of: row) else { return }
            drag = (sid, ids, sectionRows, idx, row.frame.minY)
            bringSubviewToFront(row)
        }
        switch g.state {
        case .began: break
        case .changed:
            guard var d = drag else { return }
            let ty = g.translation(in: self).y
            row.transform = CGAffineTransform(translationX: 0, y: ty)
            // past half a neighbour's height: swap places with it
            let slot = Int(((d.startY + ty) - d.rows[0].frame.minY) / 46 + 0.5)
            let target = max(0, min(d.rows.count - 1, slot))
            if target != d.index {
                let id = d.ids.remove(at: d.index); d.ids.insert(id, at: target)
                let r = d.rows.remove(at: d.index); d.rows.insert(r, at: target)
                d.index = target
                UIView.animate(withDuration: 0.2) {
                    for (k, other) in d.rows.enumerated() where other !== row { other.frame.origin.y = d.rows[0].frame.minY + CGFloat(k) * 46 }
                }
                drag = d
            }
        default:
            guard let d = drag else { return }
            drag = nil
            row.transform = .identity
            print("isim: tab order \(d.section): \(d.ids.joined(separator: ","))")
            setOrder?(d.section, d.ids)
        }
    }
}

