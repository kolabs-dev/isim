// isim SwiftUI: observable objects, more environment values, visual effects, GeometryReader,
// ScrollView/ScrollViewReader, LazyVGrid, overlay/offset/zIndex, gestures, button styles,
// UIViewRepresentable. Animations and transitions: see Animation.swift.
import UIKit
import Combine

// MARK: - Observable objects

/// Re-renders the graph when an object will change; one subscription per property position.
@MainActor func _observe<O: ObservableObject>(_ object: O, _ ctx: _Context, key: String) {
    let g = ctx.graph
    g.usedSubscriptions.insert(key)
    let id = ObjectIdentifier(object)
    if let s = g.subscriptions[key], s.id == id { return }
    let c = object.objectWillChange.sink { [weak g] _ in g?.invalidate() }
    g.subscriptions[key] = (id, AnyCancellable(c))
}

@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty, _DynamicProperty {
    @dynamicMemberLookup
    public struct Wrapper {
        let root: ObjectType
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let r = root
            return Binding(get: { r[keyPath: keyPath] }, set: { r[keyPath: keyPath] = $0 })
        }
    }
    public var wrappedValue: ObjectType
    public init(wrappedValue: ObjectType) { self.wrappedValue = wrappedValue }
    public init(initialValue: ObjectType) { wrappedValue = initialValue }
    public var projectedValue: Wrapper { Wrapper(root: wrappedValue) }
    func _install(_ ctx: _Context, label: String) { _observe(wrappedValue, ctx, key: ctx.path + "#" + label) }
}

@propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: DynamicProperty, _DynamicProperty {
    final class Box { let make: () -> ObjectType; var storage: _StateStorage<ObjectType>?; var temp: ObjectType?; init(_ m: @escaping () -> ObjectType) { make = m } }
    let box: Box
    public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) { box = Box(thunk) }
    public var wrappedValue: ObjectType {
        if let s = box.storage { return s.value }
        // read before the view was installed in the graph (SwiftUI warns about this): a temporary object
        if let t = box.temp { return t }
        let t = box.make(); box.temp = t; return t
    }
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { ObservedObject.Wrapper(root: wrappedValue) }
    func _install(_ ctx: _Context, label: String) {
        let key = ctx.path + "#" + label
        if let s = ctx.graph.storage[key] as? _StateStorage<ObjectType> { box.storage = s }
        else { let s = _StateStorage(box.temp ?? box.make()); ctx.graph.storage[key] = s; box.storage = s }
        box.temp = nil
        ctx.graph.usedKeys.insert(key)
        _observe(box.storage!.value, ctx, key: key)
    }
}

@propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty, _DynamicProperty {
    @dynamicMemberLookup
    public struct Wrapper {
        let root: ObjectType
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let r = root
            return Binding(get: { r[keyPath: keyPath] }, set: { r[keyPath: keyPath] = $0 })
        }
    }
    final class Box { var object: ObjectType? }
    let box = Box()
    public init() {}
    public var wrappedValue: ObjectType {
        guard let o = box.object else {
            fatalError("No ObservableObject of type \(ObjectType.self) found. A View.environmentObject(_:) for \(ObjectType.self) may be missing as an ancestor of this view.")
        }
        return o
    }
    public var projectedValue: Wrapper { Wrapper(root: wrappedValue) }
    func _install(_ ctx: _Context, label: String) {
        box.object = ctx.environment._objects[ObjectIdentifier(ObjectType.self)] as? ObjectType
        if let o = box.object { _observe(o, ctx, key: ctx.path + "#" + label) }
    }
}

struct _ObjectsKey: EnvironmentKey { static var defaultValue: [ObjectIdentifier: AnyObject] { [:] } }
extension EnvironmentValues {
    var _objects: [ObjectIdentifier: AnyObject] { get { self[_ObjectsKey.self] } set { self[_ObjectsKey.self] = newValue } }
}

extension View {
    public func environmentObject<T: ObservableObject>(_ object: T) -> some View {
        _env { $0._objects[ObjectIdentifier(T.self)] = object }
    }
    /// Calls action with each value the publisher emits (on the main thread).
    public func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View where P.Failure == Never {
        _modify { ctx, c in
            let g = ctx.graph, key = ctx.path + "#receive"
            g.usedSubscriptions.insert(key)
            let box: _ActionBox<P.Output>
            if let b = g.receiveActions[key] as? _ActionBox<P.Output> { box = b } else {
                box = _ActionBox<P.Output>()
                g.receiveActions[key] = box
                let sub = publisher.sink { v in
                    if Thread.isMainThread { MainActor.assumeIsolated { box.action?(v) } }
                    else { DispatchQueue.main.async { MainActor.assumeIsolated { box.action?(v) } } }
                }
                g.subscriptions[key] = (ObjectIdentifier(box), AnyCancellable(sub))
            }
            box.action = action
            return _resolve(c, ctx.child("rcv"))
        }
    }
}
final class _ActionBox<T> { var action: ((T) -> Void)? }

// MARK: - More environment values

public enum ScenePhase: Comparable, Hashable, Sendable { case background, inactive, active }
public enum UserInterfaceSizeClass: Hashable, Sendable { case compact, regular }
public enum LayoutDirection: Hashable, CaseIterable, Sendable { case leftToRight, rightToLeft }

struct _ScenePhaseKey: EnvironmentKey { static var defaultValue: ScenePhase { .active } }
struct _HSizeClassKey: EnvironmentKey { static var defaultValue: UserInterfaceSizeClass? { .compact } }
struct _VSizeClassKey: EnvironmentKey { static var defaultValue: UserInterfaceSizeClass? { .regular } }
struct _LayoutDirectionKey: EnvironmentKey { static var defaultValue: LayoutDirection { .leftToRight } }
struct _DisplayScaleKey: EnvironmentKey { static var defaultValue: CGFloat { 2 } }
struct _ButtonStyleKey: EnvironmentKey { static var defaultValue: _AnyButtonStyle? { nil } }
struct _InterpolationKey: EnvironmentKey { static var defaultValue: Image.Interpolation? { nil } }

extension EnvironmentValues {
    public var scenePhase: ScenePhase { get { self[_ScenePhaseKey.self] } set { self[_ScenePhaseKey.self] = newValue } }
    public var horizontalSizeClass: UserInterfaceSizeClass? { get { self[_HSizeClassKey.self] } set { self[_HSizeClassKey.self] = newValue } }
    public var verticalSizeClass: UserInterfaceSizeClass? { get { self[_VSizeClassKey.self] } set { self[_VSizeClassKey.self] = newValue } }
    public var layoutDirection: LayoutDirection { get { self[_LayoutDirectionKey.self] } set { self[_LayoutDirectionKey.self] = newValue } }
    public var displayScale: CGFloat { get { self[_DisplayScaleKey.self] } set { self[_DisplayScaleKey.self] = newValue } }
    var _buttonStyle: _AnyButtonStyle? { get { self[_ButtonStyleKey.self] } set { self[_ButtonStyleKey.self] = newValue } }
}

/// Environment values that come from the device / app state, set by the graph at each render.
@MainActor func _systemEnvironment(_ env: inout EnvironmentValues, traits: UITraitCollection) {
    env.horizontalSizeClass = traits.horizontalSizeClass == .regular ? .regular : .compact
    env.verticalSizeClass = traits.verticalSizeClass == .compact ? .compact : .regular
    env.displayScale = UIScreen.main.scale
    switch UIApplication.shared.applicationState {
    case .active: env.scenePhase = .active
    case .inactive: env.scenePhase = .inactive
    default: env.scenePhase = .background
    }
    let lang = Bundle.main.preferredLocalizations.first ?? "en"
    env.layoutDirection = Locale.Language(identifier: lang).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
}

public struct UnitPoint: Hashable, Sendable {
    public var x: CGFloat, y: CGFloat
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
    public init() { x = 0; y = 0 }
    public static let zero = UnitPoint(x: 0, y: 0), center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0, y: 0.5), trailing = UnitPoint(x: 1, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0), bottom = UnitPoint(x: 0.5, y: 1)
    public static let topLeading = UnitPoint(x: 0, y: 0), topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1), bottomTrailing = UnitPoint(x: 1, y: 1)
}

public struct Angle: Hashable, Comparable, Sendable {
    public var radians: Double
    public var degrees: Double { get { radians * 180 / .pi } set { radians = newValue * .pi / 180 } }
    public init() { radians = 0 }
    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { radians = degrees * .pi / 180 }
    public static func radians(_ r: Double) -> Angle { Angle(radians: r) }
    public static func degrees(_ d: Double) -> Angle { Angle(degrees: d) }
    public static let zero = Angle()
    public static func < (a: Angle, b: Angle) -> Bool { a.radians < b.radians }
    public static func + (a: Angle, b: Angle) -> Angle { Angle(radians: a.radians + b.radians) }
    public static func - (a: Angle, b: Angle) -> Angle { Angle(radians: a.radians - b.radians) }
    public static prefix func - (a: Angle) -> Angle { Angle(radians: -a.radians) }
}

@propertyWrapper
public struct Namespace: DynamicProperty, Sendable {
    public struct ID: Hashable, Sendable { let value: Int }
    nonisolated(unsafe) static var next = 0
    let id: ID
    public init() { Namespace.next += 1; id = ID(value: Namespace.next) }
    public var wrappedValue: ID { id }
}

extension View {
    public func defersSystemGestures(on edges: Edge.Set) -> some View { self }
    public func persistentSystemOverlays(_ visibility: Visibility) -> some View { self }
    public func statusBarHidden(_ hidden: Bool = true) -> some View {
        _modify { ctx, c in
            ctx.graph.postRender.append { UIApplication.shared._isim_setStatusBarHidden(hidden) }
            return _resolve(c, ctx.child("sb"))
        }
    }
    public func monospacedDigit() -> some View { self }
    public func sensoryFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View { self }
    public func contentTransition(_ t: ContentTransition) -> some View { self }
}
public struct MatchedGeometryProperties: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let position = MatchedGeometryProperties(rawValue: 1), size = MatchedGeometryProperties(rawValue: 2), frame = MatchedGeometryProperties(rawValue: 3)
}
public struct SensoryFeedback: Sendable {
    let id: Int
    public static let success = SensoryFeedback(id: 1), warning = SensoryFeedback(id: 2), error = SensoryFeedback(id: 3)
    public static let selection = SensoryFeedback(id: 4), impact = SensoryFeedback(id: 5)
}
public struct ContentTransition: Sendable {
    let id: Int
    public static let identity = ContentTransition(id: 0), opacity = ContentTransition(id: 1), interpolate = ContentTransition(id: 2)
    public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition(id: 3) }
}

// MARK: - Visual effects (transforms on the view)

/// Scale/rotation/offset/flip of a child, applied as a view transform (layout is unaffected, as in SwiftUI).
final class _EffectNode: _WrapperNode {
    var scale = CGSize(width: 1, height: 1), scaleAnchor = UnitPoint.center
    var rotation = 0.0, rotationAnchor = UnitPoint.center
    var hitTesting = true
    var zIndexValue = 0.0
    var shadow: (UIColor, CGFloat, CGFloat, CGFloat)?
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    var transform: CGAffineTransform {
        // transforms about an anchor, expressed about the view's center (UIKit's transform origin)
        let s = frame.size
        func about(_ a: UnitPoint, _ m: CGAffineTransform) -> CGAffineTransform {
            let dx = (a.x - 0.5) * s.width, dy = (a.y - 0.5) * s.height
            return CGAffineTransform(translationX: -dx, y: -dy).concatenating(m).concatenating(CGAffineTransform(translationX: dx, y: dy))
        }
        var t = CGAffineTransform.identity
        if scale != CGSize(width: 1, height: 1) { t = t.concatenating(about(scaleAnchor, CGAffineTransform(scaleX: scale.width, y: scale.height))) }
        if rotation != 0 { t = t.concatenating(about(rotationAnchor, CGAffineTransform(rotationAngle: rotation))) }
        return t
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        v.transform = transform
        v.isUserInteractionEnabled = hitTesting
        if let (c, r, x, y) = shadow {
            v.layer.shadowColor = c.cgColor; v.layer.shadowOpacity = 1; v.layer.shadowRadius = r; v.layer.shadowOffset = CGSize(width: x, height: y)
        }
        return v
    }
}

final class _OffsetNode: _WrapperNode {
    let dx: CGFloat, dy: CGFloat
    init(path: String, dx: CGFloat, dy: CGFloat, child: _Node) { self.dx = dx; self.dy = dy; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    // the offset moves this node's own view, so the content is drawn and hit-tested at the new position
    override func place(_ rect: CGRect) { frame = rect.offsetBy(dx: dx, dy: dy); child.place(CGRect(origin: .zero, size: rect.size)) }
}

extension View {
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some View { scaleEffect(x: s, y: s, anchor: anchor) }
    public func scaleEffect(_ s: CGSize, anchor: UnitPoint = .center) -> some View { scaleEffect(x: s.width, y: s.height, anchor: anchor) }
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some View {
        _modify { ctx, c in let e = _EffectNode(path: ctx.path, child: _resolve(c, ctx.child("fx"))); e.scale = CGSize(width: x, height: y); e.scaleAnchor = anchor; return e }
    }
    public func rotationEffect(_ a: Angle, anchor: UnitPoint = .center) -> some View {
        _modify { ctx, c in let e = _EffectNode(path: ctx.path, child: _resolve(c, ctx.child("fx"))); e.rotation = a.radians; e.rotationAnchor = anchor; return e }
    }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        _modify { ctx, c in _OffsetNode(path: ctx.path, dx: x, dy: y, child: _resolve(c, ctx.child("off"))) }
    }
    public func offset(_ s: CGSize) -> some View { offset(x: s.width, y: s.height) }
    public func allowsHitTesting(_ enabled: Bool) -> some View {
        _modify { ctx, c in let e = _EffectNode(path: ctx.path, child: _resolve(c, ctx.child("hit"))); e.hitTesting = enabled; return e }
    }
    public func zIndex(_ value: Double) -> some View {
        _modify { ctx, c in let e = _EffectNode(path: ctx.path, child: _resolve(c, ctx.child("z"))); e.zIndexValue = value; return e }
    }
    // shadow, blur and colour filters: VisualEffects.swift
    public func flipsForRightToLeftLayoutDirection(_ enabled: Bool) -> some View {
        _modify { ctx, c in
            let e = _EffectNode(path: ctx.path, child: _resolve(c, ctx.child("flip")))
            if enabled && ctx.environment.layoutDirection == .rightToLeft { e.scale = CGSize(width: -1, height: 1) }
            return e
        }
    }
}
public enum BlendMode: Sendable { case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver, destinationOut, plusDarker, plusLighter }

// MARK: - Overlay

final class _OverlayNode: _WrapperNode {
    let overlay: _Node, alignment: Alignment
    init(path: String, child: _Node, overlay: _Node, alignment: Alignment) {
        self.overlay = overlay; self.alignment = alignment
        super.init(path: path, child: child)
        children.append(overlay)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        child.place(CGRect(origin: .zero, size: rect.size))
        let s = overlay.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        overlay.place(_align(CGSize(width: min(s.width, rect.width), height: min(s.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), alignment))
    }
    override func mountChildren(_ g: _Graph, in view: UIView) { g.mount(child, in: view, order: 0); g.mount(overlay, in: view, order: 1) }
}

extension View {
    public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View {
        let o = content()
        return _modify { ctx, c in _OverlayNode(path: ctx.path, child: _resolve(c, ctx.child("ov")), overlay: _resolve(o, ctx.child("ovc")), alignment: alignment) }
    }
    /// deprecated on Apple; disfavored so `overlay(Color.x)` picks the ShapeStyle variant, as on iOS
    @_disfavoredOverload public func overlay<V: View>(_ overlay: V, alignment: Alignment = .center) -> some View { self.overlay(alignment: alignment) { overlay } }
    public func overlay<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { overlay { Rectangle().fill(style) } }
    public func background<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View {
        let kind = (shape as? _ShapeInfo)?._kind ?? .rect
        return _modify { ctx, c in
            let bg: _Node = (style as? Material).map { _MaterialNode(path: ctx.path + "/bgs", kind: kind, material: $0) }
                ?? _styleBackgroundNode(style, shape: shape, ctx, fillStyle: fillStyle)
                ?? _ShapeNode(path: ctx.path + "/bgs", kind: kind, color: _color(of: style, ctx.environment))
            return _BackgroundNode(path: ctx.path, color: nil, cornerRadius: 0, background: bg, child: _resolve(c, ctx.child("b")))
        }
    }
    @_disfavoredOverload public func background<V: View>(_ v: V, alignment: Alignment = .center) -> some View { background(alignment: alignment) { v } }
    // mask: VisualEffects.swift
}
func _innerShape(_ v: Any) -> _ShapeKind? {
    if let s = v as? _ShapeInfo { return s._kind }
    let m = Mirror(reflecting: v)
    for c in m.children { if let k = _innerShape(c.value) { return k } }
    return nil
}
public struct FillStyle: Equatable, Sendable {
    public var isEOFilled: Bool, isAntialiased: Bool
    public init(eoFill: Bool = false, antialiased: Bool = true) { isEOFilled = eoFill; isAntialiased = antialiased }
}

// MARK: - GeometryReader

public struct GeometryProxy {
    public let size: CGSize
    public let safeAreaInsets: EdgeInsets
    let globalFrame: CGRect
    /// live frames from the view (visualEffect / scrollTransition); nil: computed from `globalFrame`
    var _space: ((CoordinateSpace) -> CGRect?)? = nil
    public func frame(in space: CoordinateSpace) -> CGRect {
        if let f = _space, let r = f(space) { return r }
        switch space { case .local: return CGRect(origin: .zero, size: size); default: return globalFrame }
    }
}
public enum CoordinateSpace: Hashable, Sendable {
    case global, local
    case named(AnyHashable)
}
extension View {
    public func coordinateSpace<T: Hashable>(name: T) -> some View { self }
}

public struct GeometryReader<Content: View>: View, _PrimitiveView {
    let content: (GeometryProxy) -> Content
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) { self.content = content }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let make = content
        return _GeometryNode(path: ctx.path, ctx: ctx.child("geo")) { proxy, cctx in _resolve(make(proxy), cctx) }
    }
}
/// Takes all proposed space; resolves its content when it is placed (the size is known then).
final class _GeometryNode: _Node {
    let ctx: _Context
    let build: (GeometryProxy, _Context) -> _Node
    init(path: String, ctx: _Context, build: @escaping (GeometryProxy, _Context) -> _Node) {
        self.ctx = ctx; self.build = build
        super.init(path: path, children: [])
    }
    override var transparent: Bool { false }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 10, 1e6), height: min(p.height ?? 10, 1e6)) }
    override func place(_ rect: CGRect) {
        frame = rect
        let proxy = GeometryProxy(size: rect.size, safeAreaInsets: EdgeInsets(), globalFrame: rect)
        let node = build(proxy, ctx)
        children = [node]
        // content is placed at the top-leading corner, like SwiftUI's GeometryReader
        let s = node.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        node.place(CGRect(x: 0, y: 0, width: min(s.width, rect.width), height: min(s.height, rect.height)))
    }
}

// MARK: - ScrollView & ScrollViewReader

public struct ScrollView<Content: View>: View, _PrimitiveView {
    let axes: Axis.Set, showsIndicators: Bool, content: Content
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.axes = axes; self.showsIndicators = showsIndicators; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        // content margins and scroll behaviours: Scroll+Paging.swift
        _makeScrollNode(axes: axes, indicators: showsIndicators, ctx) { _resolve(content, $0) }
    }
}
final class _ScrollNode: _WrapperNode {
    let axes: Axis.Set, indicators: Bool
    var contentSize = CGSize.zero
    init(path: String, axes: Axis.Set, indicators: Bool, child: _Node) { self.axes = axes; self.indicators = indicators; super.init(path: path, child: child) }
    func contentProposal(_ p: _Proposal) -> _Proposal {
        _Proposal(width: axes.contains(.horizontal) ? nil : p.width, height: axes.contains(.vertical) ? nil : p.height)
    }
    var options = _ScrollOptions()
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        _containerSizes.append(CGSize(width: min(p.width ?? 1e6, 1e6), height: min(p.height ?? 1e6, 1e6)))
        defer { _containerSizes.removeLast() }
        let c = child.sizeThatFits(contentProposal(p))
        // like SwiftUI: a scroll view takes the proposed space (content narrower than it is centered)
        return CGSize(width: min(p.width ?? c.width, 1e6), height: min(p.height ?? c.height, 1e6))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        _containerSizes.append(rect.size)
        defer { _containerSizes.removeLast() }
        var s = child.sizeThatFits(contentProposal(_Proposal(width: rect.width, height: rect.height)))
        if !axes.contains(.horizontal) { s.width = rect.width }
        if !axes.contains(.vertical) { s.height = rect.height }
        s.width = max(s.width, axes.contains(.horizontal) ? 0 : rect.width)
        contentSize = s
        child.place(CGRect(origin: .zero, size: s))
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIScrollView(frame: .zero) }
        v.showsVerticalScrollIndicator = indicators
        v.showsHorizontalScrollIndicator = indicators
        v.alwaysBounceVertical = axes.contains(.vertical)
        v.alwaysBounceHorizontal = axes.contains(.horizontal)
        if v.contentSize != contentSize { v.contentSize = contentSize }
        _applyScrollOptions(self, v, g)
        return v
    }
}
final class _SUIScrollView: UIScrollView {
    var behavior: _ScrollBehavior?           // paging / view-aligned snapping, scroll position (Scroll+Paging.swift)
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; contentInsetAdjustmentBehavior = .never }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

public struct ScrollViewProxy {
    weak var graph: _Graph?
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {
        MainActor.assumeIsolated {
            guard let v = graph?.idViews["\(id)"] else { NSLog("isim SwiftUI: scrollTo(%@): no view with that id", "\(id)"); return }
            var s: UIView? = v.superview
            while let x = s, !(x is UIScrollView) { s = x.superview }
            guard let sv = s as? UIScrollView else { return }
            let r = v.convert(v.bounds, to: sv)
            let a = anchor ?? .center
            var off = sv.contentOffset
            let maxY = max(0, sv.contentSize.height - sv.bounds.height), maxX = max(0, sv.contentSize.width - sv.bounds.width)
            if sv.contentSize.height > sv.bounds.height {
                off.y = min(maxY, max(0, r.minY + r.height * a.y - sv.bounds.height * a.y))
            }
            if sv.contentSize.width > sv.bounds.width {
                off.x = min(maxX, max(0, r.minX + r.width * a.x - sv.bounds.width * a.x))
            }
            sv.contentOffset = off
        }
    }
}
public struct ScrollViewReader<Content: View>: View, _PrimitiveView {
    let content: (ScrollViewProxy) -> Content
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) { self.content = content }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _resolve(content(ScrollViewProxy(graph: ctx.graph)), ctx.child("reader")) }
}
extension View {
    // scrollIndicators, scrollDisabled, scrollBounceBehavior: Scroll+Paging.swift
}
public struct ScrollIndicatorVisibility: Sendable { let id: Int; public static let automatic = Self(id: 0), visible = Self(id: 1), hidden = Self(id: 2), never = Self(id: 3) }
public struct ScrollBounceBehavior: Sendable { let id: Int; public static let automatic = Self(id: 0), always = Self(id: 1), basedOnSize = Self(id: 2) }

/// Records the view for an explicit .id(...) (ScrollViewReader looks views up by id).
final class _IDNode: _WrapperNode {
    let idTag: String
    init(path: String, tag: String, child: _Node) { self.idTag = tag; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView { let v = g.view(viewKey) { _PassthroughView() }; g.idViews[idTag] = v; return v }
}

// MARK: - Grids

public struct GridItem: Sendable {
    public enum Size: Sendable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
        case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
    }
    public var size: Size
    public var spacing: CGFloat?
    public var alignment: Alignment?
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {
        self.size = size; self.spacing = spacing; self.alignment = alignment
    }
}

public struct LazyVGrid<Content: View>: View, _PrimitiveView {
    let columns: [GridItem], alignment: HorizontalAlignment, spacing: CGFloat?, content: Content
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.columns = columns; self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _GridNode(path: ctx.path, columns: columns, spacing: spacing ?? 8, child: _resolve(content, ctx.child("grid"))) }
}
public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1), sectionFooters = PinnedScrollableViews(rawValue: 2)
}
public struct LazyVStack<Content: View>: View, _PrimitiveView {
    let alignment: HorizontalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { VStack(alignment: alignment, spacing: spacing) { content }._makeNode(ctx) }
}
public struct LazyHStack<Content: View>: View, _PrimitiveView {
    let alignment: VerticalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { HStack(alignment: alignment, spacing: spacing) { content }._makeNode(ctx) }
}

final class _GridNode: _Node {
    let columns: [GridItem], spacing: CGFloat
    init(path: String, columns: [GridItem], spacing: CGFloat, child: _Node) { self.columns = columns; self.spacing = spacing; super.init(path: path, children: [child]) }
    var items: [_Node] { _flatten(children) }
    func columnWidths(_ width: CGFloat) -> [CGFloat] {
        // adaptive: as many columns as fit; fixed: their size; flexible: share the rest
        var cols: [(GridItem.Size, CGFloat)] = []
        for c in columns {
            if case .adaptive(let mn, _) = c.size {
                let gap = c.spacing ?? spacing
                let n = max(1, Int((width + gap) / (mn + gap)))
                for _ in 0..<n { cols.append((.flexible(minimum: mn), gap)) }
            } else { cols.append((c.size, c.spacing ?? spacing)) }
        }
        let gaps = cols.dropLast().reduce(0) { $0 + $1.1 }
        var fixed: CGFloat = 0, flex = 0
        for (s, _) in cols { if case .fixed(let w) = s { fixed += w } else { flex += 1 } }
        let share = flex > 0 ? max(0, (width - gaps - fixed) / CGFloat(flex)) : 0
        return cols.map { s, _ in
            switch s {
            case .fixed(let w): return w
            case .flexible(let mn, let mx), .adaptive(let mn, let mx): return min(max(share, mn), mx)
            }
        }
    }
    var gaps: [CGFloat] { columns.map { $0.spacing ?? spacing } }
    func layout(_ width: CGFloat) -> (widths: [CGFloat], rows: [CGFloat]) {
        let widths = columnWidths(width)
        let n = max(1, widths.count)
        var rows: [CGFloat] = []
        for (i, it) in items.enumerated() {
            if i % n == 0 { rows.append(0) }
            let s = it.sizeThatFits(_Proposal(width: widths[i % n], height: nil))
            rows[rows.count - 1] = max(rows[rows.count - 1], s.height)
        }
        return (widths, rows)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let w = min(p.width ?? 320, 1e6)
        let (widths, rows) = layout(w)
        let totalW = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        return CGSize(width: max(w, totalW), height: rows.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let (widths, rows) = layout(rect.width)
        let n = max(1, widths.count)
        let colGap = spacing
        let totalW = widths.reduce(0, +) + colGap * CGFloat(max(0, n - 1))
        let x0 = max(0, (rect.width - totalW) / 2)
        var y: CGFloat = 0
        for (i, it) in items.enumerated() {
            let r = i / n, c = i % n
            if c == 0 && r > 0 { y += rows[r - 1] + spacing }
            let x = x0 + widths[..<c].reduce(0, +) + colGap * CGFloat(c)
            let s = it.sizeThatFits(_Proposal(width: widths[c], height: rows[r]))
            it.place(_align(CGSize(width: min(s.width, widths[c]), height: min(s.height, rows[r])), in: CGRect(x: x, y: y, width: widths[c], height: rows[r]), .center))
        }
    }
    override func mountChildren(_ g: _Graph, in view: UIView) { for (i, c) in items.enumerated() { g.mount(c, in: view, order: i) } }
}

// ProgressView: see Controls+More.swift

// MARK: - Gestures: Gestures.swift

// MARK: - Button styles

public struct ButtonStyleConfiguration {
    public struct Label: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public let role: ButtonRole?
    public let label: Label
    public let isPressed: Bool
}
public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
struct _AnyButtonStyle {
    let make: @MainActor (ButtonStyleConfiguration) -> any View
}
extension View {
    public func buttonStyle<S: ButtonStyle>(_ style: S) -> some View {
        _env { $0._buttonStyle = _AnyButtonStyle(make: { style.makeBody(configuration: $0) }) }
    }
}
public struct PlainButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.25 : 1) }
}
public struct BorderlessButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.25 : 1) }
}
public struct DefaultButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.25 : 1) }
}
public struct BorderedButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _BorderedButtonBody(configuration: configuration, prominent: false) }
}
public struct BorderedProminentButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _BorderedButtonBody(configuration: configuration, prominent: true) }
}
extension ButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { PlainButtonStyle() } }
extension ButtonStyle where Self == BorderlessButtonStyle { public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() } }
extension ButtonStyle where Self == DefaultButtonStyle { public static var automatic: DefaultButtonStyle { DefaultButtonStyle() } }
extension ButtonStyle where Self == BorderedButtonStyle { public static var bordered: BorderedButtonStyle { BorderedButtonStyle() } }
extension ButtonStyle where Self == BorderedProminentButtonStyle { public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() } }

// MARK: - UIViewRepresentable

@MainActor public protocol UIViewRepresentable: View where Body == Never {
    associatedtype UIViewType: UIView
    associatedtype Coordinator = Void
    func makeUIView(context: Context) -> UIViewType
    func updateUIView(_ uiView: UIViewType, context: Context)
    static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator)
    func makeCoordinator() -> Coordinator
    /// iOS 16: the representable's own size for a proposal; nil = the default sizing
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIViewType, context: Context) -> CGSize?
    typealias Context = UIViewRepresentableContext<Self>
}
extension UIViewRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Coordinator { () }
}
extension UIViewRepresentable {
    public static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator) {}
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIViewType, context: Context) -> CGSize? { nil }
    public var body: Never { fatalError("UIViewRepresentable has no body") }
}
public struct UIViewRepresentableContext<Representable: UIViewRepresentable> {
    public let coordinator: Representable.Coordinator
    public var environment: EnvironmentValues
    public var transaction = Transaction()
}
public struct Transaction: Sendable {
    public var animation: Animation?
    public var disablesAnimations = false
    public init() {}
    public init(animation: Animation?) { self.animation = animation }
}

final class _RepresentableState<R: UIViewRepresentable>: _AnyStorage {
    let view: R.UIViewType
    let coordinator: R.Coordinator
    init(view: R.UIViewType, coordinator: R.Coordinator) { self.view = view; self.coordinator = coordinator }
}
final class _RepresentableNode<R: UIViewRepresentable>: _Node {
    let rep: R, env: EnvironmentValues, key: String
    unowned let graph: _Graph
    init(path: String, rep: R, env: EnvironmentValues, graph: _Graph) {
        self.rep = rep; self.env = env; self.graph = graph; key = path + "#uiview"
        super.init(path: path, children: [])
    }
    var state: _RepresentableState<R> {
        graph.usedKeys.insert(key)
        if let s = graph.storage[key] as? _RepresentableState<R> { return s }
        let coord = rep.makeCoordinator()
        let v = rep.makeUIView(context: UIViewRepresentableContext(coordinator: coord, environment: env))
        let s = _RepresentableState<R>(view: v, coordinator: coord)
        graph.storage[key] = s
        return s
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let s0 = state
        if let own = rep.sizeThatFits(ProposedViewSize(width: p.width, height: p.height), uiView: s0.view,
                                      context: UIViewRepresentableContext(coordinator: s0.coordinator, environment: env)) { return own }
        // like SwiftUI: the proposed size; views with an intrinsic size use it where nothing is proposed
        let v = s0.view
        let i = v.intrinsicContentSize
        return CGSize(width: p.width.map { min($0, 1e6) } ?? (i.width > 0 ? i.width : 10),
                      height: p.height.map { min($0, 1e6) } ?? (i.height > 0 ? i.height : 10))
    }
    override func mountView(_ g: _Graph) -> UIView {
        let s = state
        g.mountedKeys.insert(viewKey)
        if g.views[viewKey] !== s.view { g.views[viewKey]?.removeFromSuperview(); g.views[viewKey] = s.view }
        rep.updateUIView(s.view, context: UIViewRepresentableContext(coordinator: s.coordinator, environment: env))
        return s.view
    }
}

@MainActor public protocol UIViewControllerRepresentable: View where Body == Never {
    associatedtype UIViewControllerType: UIViewController
    associatedtype Coordinator = Void
    func makeUIViewController(context: Context) -> UIViewControllerType
    func updateUIViewController(_ vc: UIViewControllerType, context: Context)
    func makeCoordinator() -> Coordinator
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIViewControllerType, context: Context) -> CGSize?
    typealias Context = UIViewControllerRepresentableContext<Self>
}
extension UIViewControllerRepresentable where Coordinator == Void { public func makeCoordinator() -> Coordinator { () } }
extension UIViewControllerRepresentable {
    public var body: Never { fatalError("UIViewControllerRepresentable has no body") }
    public func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIViewControllerType, context: Context) -> CGSize? { nil }
}
public struct UIViewControllerRepresentableContext<Representable: UIViewControllerRepresentable> {
    public let coordinator: Representable.Coordinator
    public var environment: EnvironmentValues
}
final class _VCRepresentableNode<R: UIViewControllerRepresentable>: _Node {
    let rep: R, env: EnvironmentValues, key: String
    unowned let graph: _Graph
    init(path: String, rep: R, env: EnvironmentValues, graph: _Graph) { self.rep = rep; self.env = env; self.graph = graph; key = path + "#uivc"; super.init(path: path, children: []) }
    final class State: _AnyStorage { let vc: R.UIViewControllerType; let coord: R.Coordinator; init(_ v: R.UIViewControllerType, _ c: R.Coordinator) { vc = v; coord = c } }
    var state: State {
        graph.usedKeys.insert(key)
        if let s = graph.storage[key] as? State { return s }
        let c = rep.makeCoordinator()
        let s = State(rep.makeUIViewController(context: UIViewControllerRepresentableContext(coordinator: c, environment: env)), c)
        graph.storage[key] = s
        return s
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let s = state
        if let own = rep.sizeThatFits(ProposedViewSize(width: p.width, height: p.height), uiViewController: s.vc,
                                      context: UIViewControllerRepresentableContext(coordinator: s.coord, environment: env)) { return own }
        return CGSize(width: min(p.width ?? 10, 1e6), height: min(p.height ?? 10, 1e6))
    }
    override func mountView(_ g: _Graph) -> UIView {
        let s = state
        g.mountedKeys.insert(viewKey)
        if g.views[viewKey] !== s.vc.view { g.views[viewKey]?.removeFromSuperview(); g.views[viewKey] = s.vc.view }
        rep.updateUIViewController(s.vc, context: UIViewControllerRepresentableContext(coordinator: s.coord, environment: env))
        return s.vc.view
    }
}

// MARK: - Image interpolation, aspect ratio

extension Image {
    public enum Interpolation: Hashable, Sendable { case none, low, medium, high }
    public func interpolation(_ i: Interpolation) -> Image { var c = self; c.interpolationMode = i; return c }
    public func antialiased(_ on: Bool) -> Image { self }
}

/// Fits or fills the child's ideal aspect ratio into the proposal (aspectRatio/scaledToFit/scaledToFill).
final class _AspectNode: _WrapperNode {
    let ratio: CGFloat?, fill: Bool
    init(path: String, ratio: CGFloat?, fill: Bool, child: _Node) { self.ratio = ratio; self.fill = fill; super.init(path: path, child: child) }
    func aspect() -> CGFloat? {
        if let r = ratio { return r }
        let s = child.sizeThatFits(.unspecified)
        return s.width > 0 && s.height > 0 ? s.width / s.height : nil
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        guard let r = aspect() else { return child.sizeThatFits(p) }
        let ideal = child.sizeThatFits(.unspecified)
        let pw = p.width.map { min($0, 1e6) }, ph = p.height.map { min($0, 1e6) }
        switch (pw, ph) {
        case let (w?, h?):
            if fill { return w / h > r ? CGSize(width: w, height: w / r) : CGSize(width: h * r, height: h) }
            return w / h > r ? CGSize(width: h * r, height: h) : CGSize(width: w, height: w / r)
        case let (w?, nil): return CGSize(width: w, height: w / r)
        case let (nil, h?): return CGSize(width: h * r, height: h)
        default: return ideal
        }
    }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
