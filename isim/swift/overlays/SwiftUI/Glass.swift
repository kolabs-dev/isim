// isim SwiftUI: version-aware look and the iOS 26 Liquid Glass APIs.
// - The emulated iOS version (isim --os) picks the look: 17/18 the classic materials, 26+ Liquid Glass
//   (floating glass tab bar, glass back button and bar items, capsule bordered buttons).
// - glassEffect(_:in:), Glass (.regular/.clear/.identity, tint, interactive), GlassEffectContainer, the glass
//   button styles: adapted — drawn with isim's glass approximation (light backdrop blur, translucent body,
//   specular rim); containers do not merge or morph neighbouring shapes, glassEffectID is accepted (no morphing).
// - iOS 26 bar/scroll APIs isim has no behaviour for (tab bar minimizing, scroll edge styles, background extension,
//   bottom accessory) are stubs that keep apps compiling and running.
// - iOS 27 toolbar/tab additions (visibility priority, overflow menu, pinned trailing placement, minimization,
//   prominent tab role, swipe action containers, AsyncImage URL session): adapted or stubs, see each declaration.
import UIKit
import isim_host

/// The iOS major version isim emulates (17, 18, 26, 27).
@inline(__always) func _isimOSMajor() -> Int { Int(isim_os_version()) / 10000 }
/// iOS 26 and later draw the Liquid Glass look.
var _isimGlassLook: Bool { _isimOSMajor() >= 26 }
@MainActor var _isimPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

/// A view that draws Liquid Glass in its bounds (corner `radius`, optional tint).
final class _SUIGlassView: UIView {
    var radius: CGFloat = 0 { didSet { if radius != oldValue { setNeedsDisplay() } } }
    var glassTint: UIColor? { didSet { setNeedsDisplay() } }
    var clear = false, pressed = false, shadow = true
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ rect: CGRect) {
        var t = [0.0, 0.0, 0.0, 0.0]
        if let c = glassTint { var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a); t = [Double(r), Double(g), Double(b), Double(a)] }
        var flags: Int32 = traitCollection.userInterfaceStyle == .dark ? 1 : 0
        if clear { flags |= 2 }; if !shadow { flags |= 4 }; if pressed { flags |= 8 }
        let r = min(radius, min(bounds.width, bounds.height) / 2)
        t.withUnsafeBufferPointer { p in isim_gfx_glass(0, 0, Double(bounds.width), Double(bounds.height), Double(r), glassTint == nil ? nil : p.baseAddress, flags) }
    }
}
/// The scroll-edge fade iOS 26 bars use instead of an opaque material (top: fades downwards).
final class _SUIEdgeFadeView: UIView {
    var fromBottom = false
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ rect: CGRect) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor.systemBackground.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a)
        let n = 16
        for i in 0..<n {
            let t = (Double(i) + 0.5) / Double(n), alpha = 0.92 * (1 - t) * (1 - t)
            let h = Double(bounds.height) / Double(n)
            let y = fromBottom ? Double(bounds.height) - Double(i + 1) * h : Double(i) * h
            let c = [Double(r), Double(g), Double(b), alpha]
            c.withUnsafeBufferPointer { isim_gfx_fill_rounded(0, y, Double(bounds.width), h + 0.5, 0, $0.baseAddress) }
        }
    }
}

// MARK: - Glass

/// Liquid Glass material (iOS 26). isim: `regular` is a translucent glass, `clear` more transparent, `identity` none.
@available(iOS 26.0, *)
public struct Glass: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case regular, clear, identity }
    var kind: Kind
    var tintColor: Color?
    var isInteractive = false
    public static var regular: Glass { Glass(kind: .regular) }
    public static var clear: Glass { Glass(kind: .clear) }
    public static var identity: Glass { Glass(kind: .identity) }
    public func tint(_ color: Color?) -> Glass { var g = self; g.tintColor = color; return g }
    public func interactive(_ isEnabled: Bool = true) -> Glass { var g = self; g.isInteractive = isEnabled; return g }
    public static func == (a: Glass, b: Glass) -> Bool { a.kind == b.kind && a.isInteractive == b.isInteractive && (a.tintColor == nil) == (b.tintColor == nil) }
}
/// The shape glassEffect uses by default: a capsule.
@available(iOS 26.0, *)
public struct DefaultGlassEffectShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2) }
}

/// The glass shape behind a view: corner radius from the built-in shape kinds (other shapes: their bounding capsule).
struct _GlassBackground: View, _PrimitiveView {
    let kindRadius: (CGSize) -> CGFloat
    let tint: UIColor?, clear: Bool, interactive: Bool
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _GlassNode(path: ctx.path, background: self) }
}
final class _GlassNode: _Node {
    let background: _GlassBackground
    init(path: String, background: _GlassBackground) { self.background = background; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIGlassView(frame: .zero) }
        v.radius = background.kindRadius(frame.size); v.glassTint = background.tint; v.clear = background.clear
        v.setNeedsDisplay()
        return v
    }
}
func _glassRadius<S: Shape>(_ shape: S) -> (CGSize) -> CGFloat {
    if let info = shape as? _ShapeInfo {
        switch info._kind {
        case .rect: return { _ in 0 }
        case .rounded(let r): return { _ in r }
        case .circle, .capsule: return { min($0.width, $0.height) / 2 }
        }
    }
    return { min($0.width, $0.height) / 2 }
}

extension View {
    /// Liquid Glass behind the view, in `shape` (adapted: isim's glass drawing; no lensing of the content behind).
    @available(iOS 26.0, *)
    public func glassEffect<S: Shape>(_ glass: Glass = .regular, in shape: S) -> some View {
        let identity = glass.kind == .identity
        let bg = _GlassBackground(kindRadius: _glassRadius(shape), tint: glass.tintColor?.uiColor, clear: glass.kind == .clear, interactive: glass.isInteractive)
        return _modify { ctx, c in
            if identity { return _resolve(c, ctx.child("g")) }
            return _BackgroundNode(path: ctx.path, color: nil, cornerRadius: 0, background: _resolve(bg, ctx.child("glass")), child: _resolve(c, ctx.child("g")))
        }
    }
    @available(iOS 26.0, *)
    public func glassEffect(_ glass: Glass = .regular) -> some View { glassEffect(glass, in: DefaultGlassEffectShape()) }
    /// Identifies a glass shape for morphing between containers (isim: accepted, no morphing).
    @available(iOS 26.0, *)
    public func glassEffectID<ID: Hashable & Sendable>(_ id: ID?, in namespace: Namespace.ID) -> some View { self }
    /// Merges glass shapes into one (isim: accepted, shapes stay separate).
    @available(iOS 26.0, *)
    public func glassEffectUnion<ID: Hashable & Sendable>(id: ID?, namespace: Namespace.ID) -> some View { self }
    /// iOS 26 tab bar minimizing on scroll (isim: stub, the tab bar stays expanded).
    @available(iOS 26.0, *)
    public func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View { self }
    /// iOS 26 scroll edge effect style (isim: stub, bars use their own edge fade).
    @available(iOS 26.0, *)
    public func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View { self }
    /// iOS 26: mirrored, blurred copies of the view under sidebars/inspectors (isim: stub, no such chrome).
    @available(iOS 26.0, *)
    public func backgroundExtensionEffect() -> some View { self }
    /// iOS 26: an accessory above the tab bar (isim: stub, not shown).
    @available(iOS 26.0, *)
    public func tabViewBottomAccessory<Content: View>(@ViewBuilder content: () -> Content) -> some View { self }
    /// iOS 27: toolbar minimization on scroll (isim: stub, toolbars stay expanded).
    @available(iOS 27.0, *)
    public func toolbarMinimizationBehavior(_ behavior: ToolbarMinimizationBehavior, for bars: ToolbarPlacement...) -> some View { self }
    /// iOS 27: coordinates custom swipe actions in a container (isim: stub; List rows keep their swipe actions).
    @available(iOS 27.0, *)
    public func swipeActionsContainer() -> some View { self }
    /// iOS 27: the URLSession AsyncImage loads with (isim: adapted — the image loads with the shared session;
    /// the session's cache configuration is not applied).
    @available(iOS 27.0, *)
    public func asyncImageURLSession(_ urlSession: URLSession) -> some View { self }
}

/// Groups glass shapes so they can blend and morph (isim: adapted — the content draws as is, no blending).
@available(iOS 26.0, *)
public struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat?, content: Content
    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }
    public var body: some View { content }
}

@available(iOS 26.0, *)
public struct TabBarMinimizeBehavior: Hashable, Sendable {
    let id: Int
    public static let automatic = TabBarMinimizeBehavior(id: 0), never = TabBarMinimizeBehavior(id: 1)
    public static let onScrollDown = TabBarMinimizeBehavior(id: 2), onScrollUp = TabBarMinimizeBehavior(id: 3)
}
@available(iOS 26.0, *)
public struct ScrollEdgeEffectStyle: Hashable, Sendable {
    let id: Int
    public static let automatic = ScrollEdgeEffectStyle(id: 0), hard = ScrollEdgeEffectStyle(id: 1), soft = ScrollEdgeEffectStyle(id: 2)
}
@available(iOS 27.0, *)
public struct ToolbarMinimizationBehavior: Hashable, Sendable {
    let id: Int
    public static let automatic = ToolbarMinimizationBehavior(id: 0), never = ToolbarMinimizationBehavior(id: 1)
    public static let onScrollDown = ToolbarMinimizationBehavior(id: 2), onScrollUp = ToolbarMinimizationBehavior(id: 3)
}

// MARK: - Glass button styles (iOS 26)

/// `.buttonStyle(.glass)`: the label on an interactive glass capsule (adapted).
@available(iOS 26.0, *)
public struct GlassButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _GlassButtonBody(configuration: configuration, prominent: false) }
}
/// `.buttonStyle(.glassProminent)`: tinted glass with a white label (adapted).
@available(iOS 26.0, *)
public struct GlassProminentButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _GlassButtonBody(configuration: configuration, prominent: true) }
}
@available(iOS 26.0, *)
extension ButtonStyle where Self == GlassButtonStyle { public static var glass: GlassButtonStyle { GlassButtonStyle() } }
@available(iOS 26.0, *)
extension ButtonStyle where Self == GlassProminentButtonStyle { public static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() } }

@available(iOS 26.0, *)
struct _GlassButtonBody: View {
    let configuration: ButtonStyleConfiguration, prominent: Bool
    @Environment(\.controlSize) var size
    @Environment(\._tint) var tint
    var body: some View {
        let (h, v): (CGFloat, CGFloat) = size == .large || size == .extraLarge ? (20, 14) : size == .small || size == .mini ? (10, 6) : (16, 10)
        let accent: Color = configuration.role == .destructive ? .red : (tint ?? .accentColor)
        return configuration.label
            .foregroundStyle(prominent ? Color.white : (configuration.role == .destructive ? Color.red : Color.primary))
            .padding(.horizontal, h).padding(.vertical, v)
            .glassEffect(prominent ? Glass.regular.tint(accent).interactive() : Glass.regular.interactive(), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 1.04 : 1)
    }
}

// MARK: - Toolbars (iOS 26 / 27)

/// iOS 26: a gap between toolbar items (isim: adapted — a fixed 8 pt space, or a flexible one).
@available(iOS 26.0, *)
public struct ToolbarSpacer: ToolbarContent {
    let flexible: Bool, placement: ToolbarItemPlacement
    public init(_ sizing: SpacerSizing = .flexible, placement: ToolbarItemPlacement = .automatic) { flexible = sizing == .flexible; self.placement = placement }
    public var _items: [_ToolbarEntry] { [_ToolbarEntry(placement: placement, view: AnyView(Color.clear.frame(width: flexible ? 0 : 8, height: 1)))] }
}
@available(iOS 26.0, *)
public struct SpacerSizing: Hashable, Sendable {
    let id: Int
    public static let fixed = SpacerSizing(id: 0), flexible = SpacerSizing(id: 1)
}
/// iOS 27: how readily a toolbar item moves to the overflow menu (isim: stored only — isim's bars do not overflow).
@available(iOS 27.0, *)
public struct ToolbarItemVisibilityPriority: Hashable, Sendable {
    let value: Int
    public static let automatic = ToolbarItemVisibilityPriority(value: 0)
    public static let low = ToolbarItemVisibilityPriority(value: -100)
    public static let high = ToolbarItemVisibilityPriority(value: 100)
    public init(lowerThan other: ToolbarItemVisibilityPriority) { value = other.value - 1 }
    public init(higherThan other: ToolbarItemVisibilityPriority) { value = other.value + 1 }
    init(value: Int) { self.value = value }
}
@available(iOS 27.0, *)
extension ToolbarContent {
    public func visibilityPriority(_ priority: ToolbarItemVisibilityPriority) -> _ToolbarList { _ToolbarList(_items: _items) }
}
/// iOS 27: secondary actions in the toolbar's overflow ("More") menu (isim: adapted — a trailing ellipsis Menu).
@available(iOS 27.0, *)
public struct ToolbarOverflowMenu<Content: View>: ToolbarContent {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var _items: [_ToolbarEntry] {
        let c = content
        return [_ToolbarEntry(placement: .topBarTrailing, view: AnyView(Menu { c } label: { Image(systemName: "ellipsis") }))]
    }
}
@available(iOS 27.0, *)
extension ToolbarItemPlacement {
    /// iOS 27: the trailing edge of the top bar, kept in place while other items move (isim: = topBarTrailing).
    public static var topBarPinnedTrailing: ToolbarItemPlacement { .topBarTrailing }
}

// MARK: - Tab roles (iOS 18, 27)

/// A tab's role. iOS 18 `search`; iOS 27 `prominent`. With the iOS 26+ look both sit apart at the trailing end of
/// the tab bar on their own glass circle (adapted); with iOS 18 they are ordinary tabs.
@available(iOS 18.0, *)
public struct TabRole: Hashable, Sendable {
    let id: Int
    public static var search: TabRole { TabRole(id: 1) }
    @available(iOS 27.0, *)
    public static var prominent: TabRole { TabRole(id: 2) }
}
@available(iOS 18.0, *)
extension Tab where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {
        self.init(titleKey, systemImage: systemImage, value: value, content: content); _role = role?.id ?? 0
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {
        self.init(title, systemImage: systemImage, value: value, content: content); _role = role?.id ?? 0
    }
}
@available(iOS 18.0, *)
extension Tab where Value == Never, Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, role: TabRole?, @ViewBuilder content: () -> Content) {
        self.init(titleKey, systemImage: systemImage, content: content); _role = role?.id ?? 0
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, role: TabRole?, @ViewBuilder content: () -> Content) {
        self.init(title, systemImage: systemImage, content: content); _role = role?.id ?? 0
    }
}

// MARK: - Navigation transitions (iOS 18; crossFade iOS 27)

/// How a pushed or presented view transitions (isim: adapted — the default push/sheet animation is used).
@available(iOS 18.0, *)
public protocol NavigationTransition {}
@available(iOS 18.0, *)
public struct AutomaticNavigationTransition: NavigationTransition { }
@available(iOS 18.0, *)
public struct ZoomNavigationTransition: NavigationTransition { }
@available(iOS 27.0, *)
public struct CrossFadeNavigationTransition: NavigationTransition { }
@available(iOS 18.0, *)
extension NavigationTransition where Self == AutomaticNavigationTransition { public static var automatic: AutomaticNavigationTransition { AutomaticNavigationTransition() } }
@available(iOS 18.0, *)
extension NavigationTransition where Self == ZoomNavigationTransition {
    public static func zoom<ID: Hashable>(sourceID: ID, in namespace: Namespace.ID) -> ZoomNavigationTransition { ZoomNavigationTransition() }
}
@available(iOS 27.0, *)
extension NavigationTransition where Self == CrossFadeNavigationTransition { public static var crossFade: CrossFadeNavigationTransition { CrossFadeNavigationTransition() } }
extension View {
    @available(iOS 18.0, *)
    public func navigationTransition<T: NavigationTransition>(_ style: T) -> some View { self }
    @available(iOS 18.0, *)
    public func matchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View { self }
}
