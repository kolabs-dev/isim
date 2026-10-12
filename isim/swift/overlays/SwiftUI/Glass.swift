// isim SwiftUI: version-aware look and the iOS 26 Liquid Glass APIs.
// - The emulated iOS version (isim --os) picks the look: 17/18 the classic materials, 26+ Liquid Glass
//   (floating glass tab bar, glass back button and bar items, capsule bordered buttons).
// - glassEffect(_:in:), Glass (.regular/.clear/.identity, tint, interactive), GlassEffectContainer, the glass
//   button styles, glassEffectID / glassEffectTransition: adapted — drawn with isim's glass approximation (light
//   backdrop blur, lensing near the rim, translucent body, specular rim); a container draws its shapes as one
//   signed distance field, so near shapes blend and morph as they move, and inserted / removed shapes with a
//   glassEffectID grow out of / shrink into their neighbour (matchedGeometry) or fade (materialize).
// - iOS 26 bar/scroll APIs: scroll edge styles (nav/bottom bars), background extension; tab bar minimizing and the
//   bottom accessory are in TabView+More.swift.
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
    var unionKey: String?          // glassEffectUnion (GlassEffectContainer merges equal keys)
    var glassTint: UIColor? { didSet { setNeedsDisplay() } }
    var clear = false, shadow = true
    var pressed = false { didSet { if pressed != oldValue { setNeedsDisplay(); container?.setNeedsDisplay() } } }
    /// glassEffectID (namespace|id) and glassEffectTransition (0 matched geometry, 1 materialize, 2 identity)
    var morphID: String?, transition = 0
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    /// the GlassEffectContainer that draws this glass, merged with its neighbours
    var container: _SUIGlassContainerView? {
        var v = superview
        while let x = v { if let c = x as? _SUIGlassContainerView { return c }; v = x.superview }
        return nil
    }
    override func draw(_ rect: CGRect) {
        if container != nil { return }
        let pr = pressed ? _glassPressedInset(bounds) : bounds
        var t = [0.0, 0.0, 0.0, 0.0]
        if let c = glassTint { var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a); t = [Double(r), Double(g), Double(b), Double(a)] }
        var flags: Int32 = traitCollection.userInterfaceStyle == .dark ? 1 : 0
        if clear { flags |= 2 }; if !shadow { flags |= 4 }; if pressed { flags |= 8 }
        let r = min(radius + (pr.width - bounds.width) / 2, min(pr.width, pr.height) / 2)
        t.withUnsafeBufferPointer { p in isim_gfx_glass(Double(pr.minX), Double(pr.minY), Double(pr.width), Double(pr.height), Double(r), glassTint == nil ? nil : p.baseAddress, flags) }
    }
}
/// Interactive glass grows a little while touched (like UIKit's interactive UIGlassEffect).
func _glassPressedInset(_ r: CGRect) -> CGRect {
    let g = min(6, max(2, min(r.width, r.height) * 0.06))
    return r.insetBy(dx: -g, dy: -g)
}
/// Presses interactive glass while a touch is down; it never recognizes, so it takes nothing from the controls and
/// gestures under it.
final class _SUIGlassPressRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    weak var glass: _SUIGlassView?
    init(glass: _SUIGlassView) {
        self.glass = glass
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false; delaysTouchesBegan = false; delaysTouchesEnded = false
        delegate = self
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { glass?.pressed = true }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { glass?.pressed = false; state = .failed }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { glass?.pressed = false; state = .failed }
    override func reset() { glass?.pressed = false }
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
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
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _GlassNode(path: ctx.path, background: self)
        n.unionKey = ctx.environment._glassUnion; n.morphID = ctx.environment._glassID; n.transition = ctx.environment._glassTransition
        return n
    }
}
final class _GlassNode: _Node {
    let background: _GlassBackground
    var unionKey: String?, morphID: String?, transition = 0
    init(path: String, background: _GlassBackground) { self.background = background; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIGlassView(frame: .zero) }
        v.radius = background.kindRadius(frame.size); v.glassTint = background.tint; v.clear = background.clear
        v.unionKey = unionKey; v.morphID = morphID; v.transition = transition; v.isHidden = false
        v.setNeedsDisplay()
        if background.interactive {
            g.postRender.append { [weak v] in
                guard let v, let host = v.superview, !(host.gestureRecognizers ?? []).contains(where: { ($0 as? _SUIGlassPressRecognizer)?.glass === v }) else { return }
                host.addGestureRecognizer(_SUIGlassPressRecognizer(glass: v))
            }
        }
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
    /// Identifies a glass shape in a GlassEffectContainer: inserted or removed with an animation, it grows out of the
    /// shape with the same id (or the nearest one) and shrinks back into it.
    @available(iOS 26.0, *)
    public func glassEffectID<ID: Hashable & Sendable>(_ id: ID?, in namespace: Namespace.ID) -> some View {
        let key = id.map { "\(namespace.value)|\($0)" }
        return _env { $0._glassID = key }
    }
    /// How the glass shapes inside are inserted and removed in a GlassEffectContainer.
    @available(iOS 26.0, *)
    public func glassEffectTransition(_ transition: GlassEffectTransition) -> some View { _env { $0._glassTransition = transition.kind } }
    /// Glass shapes with the same union id in a GlassEffectContainer draw as one shape (their bounding capsule).
    @available(iOS 26.0, *)
    public func glassEffectUnion<ID: Hashable & Sendable>(id: ID?, namespace: Namespace.ID) -> some View {
        let key = id.map { "\(namespace.value)|\($0)" }
        return _env { $0._glassUnion = key }
    }
    /// iOS 26 scroll edge effect under the bars: `.soft` fades (default), `.hard` an opaque edge with a divider.
    @available(iOS 26.0, *)
    public func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View {
        let id = style?.id ?? 0
        return _modify { ctx, c in
            if edges.contains(.top) { ctx.nav?.edgeTop = id }
            if edges.contains(.bottom) { ctx.nav?.edgeBottom = id }
            return _resolve(c, ctx.child("sees"))
        }
    }
    /// iOS 26: no scroll edge effect on these edges.
    @available(iOS 26.0, *)
    public func scrollEdgeEffectHidden(_ hidden: Bool = true, for edges: Edge.Set = .all) -> some View {
        _modify { ctx, c in
            if hidden, edges.contains(.top) { ctx.nav?.edgeTop = 3 }
            if hidden, edges.contains(.bottom) { ctx.nav?.edgeBottom = 3 }
            return _resolve(c, ctx.child("seeh"))
        }
    }
    /// iOS 26: mirrored, blurred copies of the view fill the safe area next to it (under the status bar, beside it
    /// in landscape), so the content seems to continue under the system chrome (adapted).
    @available(iOS 26.0, *)
    public func backgroundExtensionEffect() -> some View {
        _modify { ctx, c in _BackgroundExtensionNode(path: ctx.path, child: _resolve(c, ctx.child("bee"))) }
    }
    @available(iOS 26.0, *)
    public func backgroundExtensionEffect(isEnabled: Bool) -> some View {
        _modify { ctx, c in isEnabled ? _BackgroundExtensionNode(path: ctx.path, child: _resolve(c, ctx.child("bee"))) : _resolve(c, ctx.child("bee")) }
    }
    /// iOS 27: the bottom toolbar slides away (the navigation bar fades) while the content scrolls down (`.onScrollDown`)
    /// or up (`.onScrollUp`).
    @available(iOS 27.0, *)
    public func toolbarMinimizationBehavior(_ behavior: ToolbarMinimizationBehavior, for bars: ToolbarPlacement...) -> some View {
        let id = behavior.id
        return _modify { ctx, c in
            if bars.isEmpty || bars.contains(where: { $0.id == 3 || $0.id == 0 }) { ctx.nav?.minimizeBottom = id }
            if bars.contains(where: { $0.id == 1 }) { ctx.nav?.minimizeTop = id }
            return _resolve(c, ctx.child("tmb"))
        }
    }
    /// iOS 27: the views with swipeActions inside keep one swipe open at a time (opening one closes the other).
    @available(iOS 27.0, *)
    public func swipeActionsContainer() -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#swipecontainer", g = ctx.graph
            let box = g.storage[key] as? _SwipeContainerBox ?? _SwipeContainerBox()
            g.storage[key] = box; g.usedKeys.insert(key)
            return _resolve(c, ctx.child("sac").with { $0._swipeContainer = box })
        }
    }
    /// iOS 27: the URLSession the AsyncImages inside load with (its configuration: headers, caching, protocols).
    @available(iOS 27.0, *)
    public func asyncImageURLSession(_ urlSession: URLSession) -> some View { _env { $0._asyncImageSession = urlSession } }
}

/// Groups glass shapes so they blend: drawn together as one signed distance field, shapes closer than `spacing` flow
/// into one another (and morph as they move); shapes with the same glassEffectUnion id draw as one shape over their
/// bounding box (adapted: isim's glass, see the top of the file).
@available(iOS 26.0, *)
public struct GlassEffectContainer<Content: View>: View, _PrimitiveView {
    let spacing: CGFloat?, content: Content
    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }
    public var body: some View { content }
    func _makeNode(_ ctx: _Context) -> _Node {
        _GlassContainerNode(path: ctx.path, spacing: spacing ?? 0, child: _resolve(content, ctx.child("glassc").with { $0._glassUnion = nil }))
    }
}
struct _GlassUnionKey: EnvironmentKey { static var defaultValue: String? { nil } }
struct _GlassIDKey: EnvironmentKey { static var defaultValue: String? { nil } }
struct _GlassTransitionKey: EnvironmentKey { static var defaultValue: Int { 0 } }
extension EnvironmentValues {
    var _glassUnion: String? { get { self[_GlassUnionKey.self] } set { self[_GlassUnionKey.self] = newValue } }
    var _glassID: String? { get { self[_GlassIDKey.self] } set { self[_GlassIDKey.self] = newValue } }
    var _glassTransition: Int { get { self[_GlassTransitionKey.self] } set { self[_GlassTransitionKey.self] = newValue } }
}
/// How a glass shape is added to or removed from a GlassEffectContainer: `matchedGeometry` (the default) grows it out
/// of the shape with the same glassEffectID or the nearest one, `materialize` fades it in place, `identity` none.
@available(iOS 26.0, *)
public struct GlassEffectTransition: Sendable {
    let kind: Int
    public static var matchedGeometry: GlassEffectTransition { GlassEffectTransition(kind: 0) }
    public static var materialize: GlassEffectTransition { GlassEffectTransition(kind: 1) }
    public static var identity: GlassEffectTransition { GlassEffectTransition(kind: 2) }
}

/// After layout, merges the glass shapes inside it that touch (within `spacing`) or share a union id.
final class _GlassContainerNode: _WrapperNode {
    let spacing: CGFloat
    init(path: String, spacing: CGFloat, child: _Node) { self.spacing = spacing; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIGlassContainerView(frame: .zero) }
        v.spacing = spacing
        g.postRender.append { [weak v] in v?.merge() }
        return v
    }
}
final class _SUIGlassContainerView: _PassthroughViewBase {
    var spacing: CGFloat = 0
    /// markers of the merged groups (shapes within `spacing`, or with one union id), for view dumps
    private var markers: [UIView] = []
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    /// the glass views inside (not inside a nested container)
    func glassViews(_ v: UIView, _ out: inout [_SUIGlassView]) {
        for s in v.subviews where !s.isHidden {
            if let gl = s as? _SUIGlassView { out.append(gl); continue }
            if s is _SUIGlassContainerView { continue }
            glassViews(s, &out)
        }
    }
    /// After each update: the merged groups as marker views (isim-glass-union-N, the group's bounding box).
    func merge() {
        var gs: [_SUIGlassView] = []
        glassViews(self, &gs)
        for m in markers { m.removeFromSuperview() }
        markers = []
        let frames = gs.map { $0.convert($0.bounds, to: self) }
        var cluster = Array(0..<gs.count)
        func root(_ i: Int) -> Int { var i = i; while cluster[i] != i { i = cluster[i] }; return i }
        for i in gs.indices { for j in gs.indices where j > i {
            let near = frames[i].insetBy(dx: -spacing / 2 - 0.5, dy: -spacing / 2 - 0.5).intersects(frames[j].insetBy(dx: -spacing / 2 - 0.5, dy: -spacing / 2 - 0.5))
            let same = gs[i].unionKey != nil && gs[i].unionKey == gs[j].unionKey
            if near || same { cluster[root(j)] = root(i) }
        } }
        var groups: [Int: [Int]] = [:]
        for i in gs.indices { groups[root(i), default: []].append(i) }
        for (k, members) in groups.sorted(by: { $0.key < $1.key }) where members.count > 1 {
            let m = UIView(frame: members.map { frames[$0] }.reduce(frames[members[0]]) { $0.union($1) })
            m.isUserInteractionEnabled = false; m.backgroundColor = .clear
            m.accessibilityIdentifier = "isim-glass-union-\(k)"
            insertSubview(m, at: 0)
            markers.append(m)
        }
        setNeedsDisplay()
    }
    struct Shape { var rect: CGRect, radius: CGFloat, tint: UIColor?, pressed: Bool, alpha: CGFloat }
    /// The frame (in this view) and alpha a glass view is drawn with now, and as its model ends up.
    func presented(_ v: UIView) -> (now: CGRect, alpha: CGFloat, model: CGRect, modelAlpha: CGFloat) {
        var a: CGFloat = 1, r = v._isim_presentedFrame(&a, radius: nil), model = v.frame, ma = v.isHidden ? 0 : v.alpha
        var p = v.superview
        while let x = p, x !== self {
            var pa: CGFloat = 1
            let pf = x._isim_presentedFrame(&pa, radius: nil)
            a *= pa; ma *= x.isHidden ? 0 : x.alpha
            r = r.offsetBy(dx: pf.minX - x.bounds.minX, dy: pf.minY - x.bounds.minY)
            model = model.offsetBy(dx: x.frame.minX - x.bounds.minX, dy: x.frame.minY - x.bounds.minY)
            p = x.superview
        }
        return (r.offsetBy(dx: -bounds.minX, dy: -bounds.minY), a, model.offsetBy(dx: -bounds.minX, dy: -bounds.minY), ma)
    }
    override func draw(_ rect: CGRect) {
        var gs: [_SUIGlassView] = []
        glassViews(self, &gs)
        guard !gs.isEmpty else { return }
        let items = gs.map { presented($0) }
        // a shape fading in or out (inserted or removed with an animation) is in transition
        let fading = items.map { $0.modelAlpha > 0.01 ? $0.alpha < $0.modelAlpha - 0.01 : $0.alpha > 0.01 }
        var shapes: [Shape] = [], faded: [Shape] = []
        var unions: [String: Int] = [:]
        for (i, g) in gs.enumerated() {
            let it = items[i]
            var r = it.now, alpha = min(1, it.alpha)
            if fading[i] {
                let f = it.modelAlpha > 0.01 ? min(1, it.alpha / it.modelAlpha) : it.alpha
                switch g.transition {
                case 0 where g.morphID != nil:
                    // matched geometry: from / into the shape with the same id, else the nearest steady one
                    var target: CGRect?
                    if let j = gs.indices.first(where: { $0 != i && gs[$0].morphID == g.morphID }) { target = items[j].model }
                    else {
                        let c = CGPoint(x: it.model.midX, y: it.model.midY)
                        target = gs.indices.filter { $0 != i && !fading[$0] && items[$0].alpha > 0.01 }
                            .min { hypot(items[$0].now.midX - c.x, items[$0].now.midY - c.y) < hypot(items[$1].now.midX - c.x, items[$1].now.midY - c.y) }
                            .map { items[$0].now }
                    }
                    let t = target ?? CGRect(x: it.model.midX, y: it.model.midY, width: 0, height: 0)
                    let m = it.model
                    r = CGRect(x: t.minX + (m.minX - t.minX) * f, y: t.minY + (m.minY - t.minY) * f,
                               width: t.width + (m.width - t.width) * f, height: t.height + (m.height - t.height) * f)
                    alpha = f > 0.001 || target != nil ? 1 : 0
                case 2: alpha = it.alpha > 0.01 ? 1 : 0                   // identity: no transition of the glass
                default: alpha = f                                          // materialize: fades in place
                }
            }
            guard alpha > 0.01, r.width > 0, r.height > 0 else { continue }
            if g.pressed { r = _glassPressedInset(r) }
            let radius = min(g.radius * (r.width / max(1, it.model.width)), min(r.width, r.height) / 2)
            var sh = Shape(rect: r, radius: radius, tint: g.glassTint, pressed: g.pressed, alpha: alpha)
            if let k = g.unionKey, alpha >= 0.99 {                          // glassEffectUnion: one shape over the box
                if let j = unions[k] {
                    let box = shapes[j].rect.union(r)
                    shapes[j].rect = box; shapes[j].radius = min(max(shapes[j].radius, radius), min(box.width, box.height) / 2)
                    continue
                }
                unions[k] = shapes.count
            }
            if alpha < 0.99 { sh.alpha = alpha; faded.append(sh) } else { shapes.append(sh) }
        }
        var flags: Int32 = traitCollection.userInterfaceStyle == .dark ? 1 : 0
        if gs.contains(where: { $0.clear }) { flags |= 2 }
        func draw(_ list: [Shape]) {
            var geo: [Double] = [], tints: [Double] = [], pressed: [Int32] = []
            for s in list {
                geo += [Double(s.rect.minX), Double(s.rect.minY), Double(s.rect.width), Double(s.rect.height), Double(s.radius)]
                var c: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
                s.tint?.resolvedColor(with: traitCollection).getRed(&c.0, green: &c.1, blue: &c.2, alpha: &c.3)
                tints += [Double(c.0), Double(c.1), Double(c.2), Double(c.3)]
                pressed.append(s.pressed ? 1 : 0)
            }
            isim_gfx_glass_shapes(Int32(list.count), geo, tints, pressed, Double(spacing), flags)
        }
        if !shapes.isEmpty { draw(shapes) }
        for s in faded { isim_gfx_push_group(); draw([s]); isim_gfx_pop_group(Double(s.alpha)) }
    }
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
    public var _items: [_ToolbarEntry] { [_ToolbarEntry(placement: placement, view: AnyView(Color.clear.frame(width: flexible ? 0 : 8, height: 1)), spacer: flexible ? 0 : 8)] }
}
@available(iOS 26.0, *)
public struct SpacerSizing: Hashable, Sendable {
    let id: Int
    public static let fixed = SpacerSizing(id: 0), flexible = SpacerSizing(id: 1)
}
/// iOS 27: how readily a toolbar item moves to the overflow menu when the bar runs out of room (lowest first).
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
    public func visibilityPriority(_ priority: ToolbarItemVisibilityPriority) -> _ToolbarList {
        _ToolbarList(_items: _items.map { var e = $0; e.priority = priority.value; return e })
    }
}
/// iOS 27: secondary actions in the toolbar's overflow ("More") menu, with the items that did not fit.
@available(iOS 27.0, *)
public struct ToolbarOverflowMenu<Content: View>: ToolbarContent {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var _items: [_ToolbarEntry] {
        [_ToolbarEntry(placement: ToolbarItemPlacement(id: 11), view: AnyView(content))]
    }
}
@available(iOS 27.0, *)
extension ToolbarItemPlacement {
    /// iOS 27: the trailing edge of the top bar, kept in place (never moved to the overflow menu).
    public static var topBarPinnedTrailing: ToolbarItemPlacement { ToolbarItemPlacement(id: 10) }
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

/// How a pushed or presented view transitions (isim: adapted — slide, zoom from a matchedTransitionSource, cross-fade;
/// NavigationTransitions.swift).
@available(iOS 18.0, *)
public protocol NavigationTransition {}
@available(iOS 18.0, *)
public struct AutomaticNavigationTransition: NavigationTransition { }
@available(iOS 18.0, *)
public struct ZoomNavigationTransition: NavigationTransition { var key: AnyHashable? }
@available(iOS 27.0, *)
public struct CrossFadeNavigationTransition: NavigationTransition { }
@available(iOS 18.0, *)
extension NavigationTransition where Self == AutomaticNavigationTransition { public static var automatic: AutomaticNavigationTransition { AutomaticNavigationTransition() } }
@available(iOS 18.0, *)
extension NavigationTransition where Self == ZoomNavigationTransition {
    public static func zoom<ID: Hashable>(sourceID: ID, in namespace: Namespace.ID) -> ZoomNavigationTransition {
        ZoomNavigationTransition(key: _ZoomSources.key(AnyHashable(sourceID), namespace))
    }
}
@available(iOS 27.0, *)
extension NavigationTransition where Self == CrossFadeNavigationTransition { public static var crossFade: CrossFadeNavigationTransition { CrossFadeNavigationTransition() } }
// navigationTransition(_:) and matchedTransitionSource(id:in:): NavigationTransitions.swift

/// backgroundExtensionEffect: blurred mirror images of the view in the safe-area gaps between it and the screen edges.
final class _BackgroundExtensionNode: _WrapperNode {
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIBackgroundExtensionView(frame: .zero) }
        g.postRender.append { [weak v] in v?.extend() }
        return v
    }
}
final class _SUIBackgroundExtensionView: _PassthroughViewBase {
    private var copies: [UIView] = []
    private var observer: NSObjectProtocol?
    override init(frame: CGRect) {
        super.init(frame: frame)
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimScrollViewDidScroll"), object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
            MainActor.assumeIsolated { if let self, let sv = n.object as? UIView, self.isDescendant(of: sv) { self.extend() } }
        })
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    override func removeFromSuperview() { for c in copies { c.removeFromSuperview() }; copies = []; super.removeFromSuperview() }
    /// The copies go behind the app's content (in the root view), outside any clipping scroll view.
    func extend() {
        for c in copies { c.removeFromSuperview() }
        copies = []
        guard let w = window, let content = subviews.first(where: { !$0.isHidden }), bounds.width > 0, bounds.height > 0 else { return }
        var up: UIView? = self
        while let x = up { if x.isHidden || x.alpha < 0.01 { return }; up = x.superview }     // not on screen (another tab)
        var root: UIView = self
        while let s = root.superview, !(s is UIWindow) { root = s }
        let f = convert(bounds, to: nil), safe = w.bounds.inset(by: w.safeAreaInsets)
        // edges at the safe area: top (status bar), bottom (home indicator), leading / trailing (landscape)
        var gaps: [(CGRect, Bool)] = []          // window rect of the gap, vertical mirror
        if f.minY <= safe.minY + 1, f.minY > 0.5, f.maxY > 0 { gaps.append((CGRect(x: f.minX, y: 0, width: f.width, height: f.minY), true)) }
        if f.maxY >= safe.maxY - 1, f.maxY < w.bounds.maxY - 0.5, f.minY < w.bounds.maxY { gaps.append((CGRect(x: f.minX, y: f.maxY, width: f.width, height: w.bounds.maxY - f.maxY), true)) }
        if f.minX <= safe.minX + 1, f.minX > 0.5 { gaps.append((CGRect(x: 0, y: f.minY, width: f.minX, height: f.height), false)) }
        if f.maxX >= safe.maxX - 1, f.maxX < w.bounds.maxX - 0.5 { gaps.append((CGRect(x: f.maxX, y: f.minY, width: w.bounds.maxX - f.maxX, height: f.height), false)) }
        guard !gaps.isEmpty, let snap = content.snapshotView(afterScreenUpdates: false) as? UIImageView, let img = snap.image else { return }
        for (gap, vertical) in gaps {
            let clip = UIView(frame: root.convert(gap, from: nil)); clip.clipsToBounds = true; clip.isUserInteractionEnabled = false
            let iv = UIImageView(image: img)
            // the content mirrored about the shared edge
            let before = vertical ? gap.minY < f.minY : gap.minX < f.minX
            iv.frame = CGRect(x: vertical ? 0 : (before ? gap.width - f.width : 0), y: vertical ? (before ? gap.height - f.height : 0) : 0, width: f.width, height: f.height)
            iv.transform = vertical ? CGAffineTransform(scaleX: 1, y: -1) : CGAffineTransform(scaleX: -1, y: 1)
            clip.addSubview(iv)
            var spec = [Double](repeating: 0, count: 32)
            spec[0] = 1; spec[6] = 1; spec[12] = 1; spec[18] = 1; spec[20] = 12
            spec.withUnsafeBufferPointer { clip._isim_setVisualEffect($0.baseAddress) }
            clip.accessibilityIdentifier = "isim-background-extension"
            root.insertSubview(clip, at: 0)
            copies.append(clip)
        }
    }
}
