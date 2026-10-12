// isim SwiftUI: preferences (PreferenceKey, `.preference`, `.transformPreference`, `.onPreferenceChange`,
// anchor preferences with `.overlayPreferenceValue` / `.backgroundPreferenceValue` and `GeometryProxy[anchor]`),
// `.onGeometryChange` and `@ScaledMetric`.
// Preferences are collected from the laid-out node tree (so values set inside GeometryReaders count); changes are
// delivered after the render, like SwiftUI. Anchors resolve relative to the view that reads them (the overlay /
// background of the preference host).
import UIKit

public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Value { get }
    static func reduce(value: inout Value, nextValue: () -> Value)
}

final class _PreferenceNode: _WrapperNode {
    let key: ObjectIdentifier
    let value: (() -> Any)?                         // set: the value (children's values for the key are replaced)
    let transform: ((inout Any) -> Void)?           // transform: applied to the subtree's reduced value
    init(path: String, key: ObjectIdentifier, value: (() -> Any)?, transform: ((inout Any) -> Void)?, child: _Node) {
        self.key = key; self.value = value; self.transform = transform; super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override var transparent: Bool { false }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

/// The subtree's reduced value for K (nil: no view in it sets K).
@MainActor func _preference<K: PreferenceKey>(_ k: K.Type, in n: _Node) -> K.Value? {
    if let p = n as? _PreferenceNode, p.key == ObjectIdentifier(K.self) {
        if let v = p.value { return v() as? K.Value }
        var acc: Any = _preference(k, in: p.child) ?? K.defaultValue
        p.transform?(&acc)
        return acc as? K.Value
    }
    var kids = n.children
    if let b = n as? _BackgroundNode, let bg = b.background { kids = [bg] + kids }
    if let l = n as? _ListNode { kids = l.sections.flatMap { [$0.header].compactMap { $0 } + $0.rows } }
    var acc: K.Value? = nil
    for c in kids {
        guard let v = _preference(k, in: c) else { continue }
        if acc == nil { acc = K.defaultValue }
        K.reduce(value: &acc!, nextValue: { v })
    }
    return acc
}

extension View {
    public func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View {
        _modify { ctx, c in _PreferenceNode(path: ctx.path, key: ObjectIdentifier(K.self), value: { value }, transform: nil, child: _resolve(c, ctx.child("pref"))) }
    }
    public func transformPreference<K: PreferenceKey>(_ key: K.Type = K.self, _ callback: @escaping (inout K.Value) -> Void) -> some View {
        _modify { ctx, c in
            _PreferenceNode(path: ctx.path, key: ObjectIdentifier(K.self), value: nil, transform: { any in
                var v = any as? K.Value ?? K.defaultValue; callback(&v); any = v
            }, child: _resolve(c, ctx.child("tpref")))
        }
    }
    /// Called (after the render) when the subtree's value for the key changes, and for its first value.
    public func onPreferenceChange<K: PreferenceKey>(_ key: K.Type = K.self, perform action: @escaping (K.Value) -> Void) -> some View where K.Value: Equatable {
        _modify { ctx, c in
            _OnPreferenceNode<K>(path: ctx.path, graph: ctx.graph, action: action, child: _resolve(c, ctx.child("onpref")))
        }
    }
    public func anchorPreference<A, K: PreferenceKey>(key: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (Anchor<A>) -> K.Value) -> some View {
        _modify { ctx, c in
            let inner = _resolve(c, ctx.child("apref"))
            let n = _AnchorSourceNode(path: ctx.path, child: inner)
            return _PreferenceNode(path: ctx.path + "/anchor", key: ObjectIdentifier(K.self), value: { transform(Anchor(node: n, make: value.make)) }, transform: nil, child: n)
        }
    }
    public func transformAnchorPreference<A, K: PreferenceKey>(key: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (inout K.Value, Anchor<A>) -> Void) -> some View {
        _modify { ctx, c in
            let inner = _resolve(c, ctx.child("tapref"))
            let n = _AnchorSourceNode(path: ctx.path, child: inner)
            return _PreferenceNode(path: ctx.path + "/anchor", key: ObjectIdentifier(K.self), value: nil, transform: { any in
                var v = any as? K.Value ?? K.defaultValue; transform(&v, Anchor(node: n, make: value.make)); any = v
            }, child: n)
        }
    }
    public func overlayPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type = K.self, alignment: Alignment = .center, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View {
        _modify { ctx, c in
            _PreferenceHostNode<K>(path: ctx.path, ctx: ctx.child("prefhost"), background: false, alignment: alignment,
                                   make: { AnyView(transform($0)) }, child: _resolve(c, ctx.child("prefmain")))
        }
    }
    public func backgroundPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type = K.self, alignment: Alignment = .center, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View {
        _modify { ctx, c in
            _PreferenceHostNode<K>(path: ctx.path, ctx: ctx.child("prefhost"), background: true, alignment: alignment,
                                   make: { AnyView(transform($0)) }, child: _resolve(c, ctx.child("prefmain")))
        }
    }
}

final class _PrefValueBox<V>: _AnyStorage { var value: V; init(_ v: V) { value = v } }

final class _OnPreferenceNode<K: PreferenceKey>: _WrapperNode where K.Value: Equatable {
    weak var graph: _Graph?
    let action: (K.Value) -> Void
    init(path: String, graph: _Graph, action: @escaping (K.Value) -> Void, child: _Node) {
        self.graph = graph; self.action = action; super.init(path: path, child: child)
        graph.usedKeys.insert(path + "#prefchange")
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        child.place(CGRect(origin: .zero, size: rect.size))
        guard let g = graph else { return }
        let key = path + "#prefchange"
        let v = _preference(K.self, in: child) ?? K.defaultValue
        if let old = g.storage[key] as? _PrefValueBox<K.Value> {
            if old.value != v { old.value = v; let a = action; g.postRender.append { a(v) } }
        } else {
            g.storage[key] = _PrefValueBox(v)
            let a = action; g.postRender.append { a(v) }
        }
    }
}

// MARK: - Anchors

/// The view an anchor measures.
final class _AnchorSourceNode: _WrapperNode {
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

/// A view's geometry, resolved in the coordinate space of whoever reads it (`proxy[anchor]`).
public struct Anchor<Value> {
    let node: _Node?
    let make: (CGRect) -> Value
    public struct Source {
        let make: (CGRect) -> Value
    }
}
extension Anchor {
    /// isim: an anchor whose value is fixed (in the reader's coordinate space): Charts' ChartProxy.plotFrame.
    public init(_isimValue value: Value) { node = nil; make = { _ in value } }
}
extension Anchor: @unchecked Sendable {}
extension Anchor.Source: @unchecked Sendable {}
extension Anchor.Source where Value == CGRect {
    public static var bounds: Anchor<CGRect>.Source { .init(make: { $0 }) }
    public static func rect(_ r: CGRect) -> Anchor<CGRect>.Source { .init(make: { r.offsetBy(dx: $0.minX, dy: $0.minY) }) }
}
extension Anchor.Source where Value == CGPoint {
    public static func point(_ p: CGPoint) -> Anchor<CGPoint>.Source { .init(make: { CGPoint(x: $0.minX + p.x, y: $0.minY + p.y) }) }
    public static func unitPoint(_ u: UnitPoint) -> Anchor<CGPoint>.Source { .init(make: { CGPoint(x: $0.minX + $0.width * u.x, y: $0.minY + $0.height * u.y) }) }
    public static var topLeading: Anchor<CGPoint>.Source { unitPoint(.topLeading) }
    public static var top: Anchor<CGPoint>.Source { unitPoint(.top) }
    public static var topTrailing: Anchor<CGPoint>.Source { unitPoint(.topTrailing) }
    public static var leading: Anchor<CGPoint>.Source { unitPoint(.leading) }
    public static var center: Anchor<CGPoint>.Source { unitPoint(.center) }
    public static var trailing: Anchor<CGPoint>.Source { unitPoint(.trailing) }
    public static var bottomLeading: Anchor<CGPoint>.Source { unitPoint(.bottomLeading) }
    public static var bottom: Anchor<CGPoint>.Source { unitPoint(.bottom) }
    public static var bottomTrailing: Anchor<CGPoint>.Source { unitPoint(.bottomTrailing) }
}
/// Node frames relative to the preference host being laid out (innermost last).
@MainActor var _anchorFrames: [[ObjectIdentifier: CGRect]] = []
extension GeometryProxy {
    public subscript<T>(anchor: Anchor<T>) -> T {
        let r = MainActor.assumeIsolated { anchor.node.flatMap { n in _anchorFrames.last?[ObjectIdentifier(n)] } } ?? .zero
        return anchor.make(r)
    }
}

/// Lays out its content, then builds the overlay / background from the content's preference value.
final class _PreferenceHostNode<K: PreferenceKey>: _WrapperNode {
    let ctx: _Context, background: Bool, alignment: Alignment, make: (K.Value) -> AnyView
    var extra: _Node?
    init(path: String, ctx: _Context, background: Bool, alignment: Alignment, make: @escaping (K.Value) -> AnyView, child: _Node) {
        self.ctx = ctx; self.background = background; self.alignment = alignment; self.make = make
        super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        child.place(CGRect(origin: .zero, size: rect.size))
        // frames of every node under the content, relative to this view
        var frames: [ObjectIdentifier: CGRect] = [:]
        func walk(_ n: _Node, _ base: CGPoint) {
            let f = n.frame.offsetBy(dx: base.x, dy: base.y)
            frames[ObjectIdentifier(n)] = f
            let cb = n.transparent ? base : f.origin
            if let b = n as? _BackgroundNode, let bg = b.background { walk(bg, cb) }
            for c in n.children { walk(c, cb) }
        }
        walk(child, .zero)
        _anchorFrames.append(frames)
        defer { _anchorFrames.removeLast() }
        let value = _preference(K.self, in: child) ?? K.defaultValue
        let n = _resolve(make(value), ctx)
        extra = n
        children = [child, n]
        let s = n.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        n.place(_align(CGSize(width: min(s.width, rect.width), height: min(s.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), alignment))
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        if background, let e = extra { g.mount(e, in: view, order: 0) }
        g.mount(child, in: view, order: 1)
        if !background, let e = extra { g.mount(e, in: view, order: 2) }
    }
}

// MARK: - onGeometryChange

final class _GeometryChangeNode<T: Equatable>: _WrapperNode {
    weak var graph: _Graph?
    let transform: (GeometryProxy) -> T, action: (T, T) -> Void
    init(path: String, graph: _Graph, transform: @escaping (GeometryProxy) -> T, action: @escaping (T, T) -> Void, child: _Node) {
        self.graph = graph; self.transform = transform; self.action = action; super.init(path: path, child: child)
        graph.usedKeys.insert(path + "#geochange")
    }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        child.place(CGRect(origin: .zero, size: rect.size))
        guard let g = graph else { return }
        let key = path + "#geochange"
        let key2 = viewKey, local = CGRect(origin: .zero, size: rect.size)
        let v = transform(GeometryProxy(size: rect.size, safeAreaInsets: EdgeInsets(), globalFrame: rect,
                                        _space: { [weak g] s in g?.geometryFrame(key2, s, fallback: { if case .local = s { return local }; return rect }()) }))
        let a = action
        if let old = g.storage[key] as? _PrefValueBox<T> {
            if old.value != v { let o = old.value; old.value = v; g.postRender.append { a(o, v) } }
        } else {
            g.storage[key] = _PrefValueBox(v)
            g.postRender.append { a(v, v) }
        }
    }
}
extension View {
    /// Calls `action` with `transform(geometry)` when it changes (and once at first layout).
    public func onGeometryChange<T: Equatable>(for type: T.Type, of transform: @escaping (GeometryProxy) -> T, action: @escaping (T) -> Void) -> some View {
        onGeometryChange(for: type, of: transform) { (_: T, new: T) in action(new) }
    }
    public func onGeometryChange<T: Equatable>(for type: T.Type, of transform: @escaping (GeometryProxy) -> T, action: @escaping (T, T) -> Void) -> some View {
        _modify { ctx, c in _GeometryChangeNode(path: ctx.path, graph: ctx.graph, transform: transform, action: action, child: _resolve(c, ctx.child("geoc"))) }
    }
}

// MARK: - @ScaledMetric

/// A value scaled with the environment's dynamic type size (1x at `.large`), like iOS's body text style curve.
@propertyWrapper
public struct ScaledMetric<Value: BinaryFloatingPoint>: DynamicProperty, _DynamicProperty {
    final class Box { var factor = 1.0 }
    let base: Value, box = Box()
    public init(wrappedValue: Value, relativeTo textStyle: Font.TextStyle = .body) { base = wrappedValue }
    public init(wrappedValue: Value) { base = wrappedValue }
    public var wrappedValue: Value { base * Value(box.factor) }
    func _install(_ ctx: _Context, label: String) { box.factor = _dynamicTypeFactor(ctx.environment.dynamicTypeSize) }
}
func _dynamicTypeFactor(_ s: DynamicTypeSize) -> Double {
    switch s {
    case .xSmall: return 14.0 / 17
    case .small: return 15.0 / 17
    case .medium: return 16.0 / 17
    case .large: return 1
    case .xLarge: return 19.0 / 17
    case .xxLarge: return 21.0 / 17
    case .xxxLarge: return 23.0 / 17
    case .accessibility1: return 28.0 / 17
    case .accessibility2: return 33.0 / 17
    case .accessibility3: return 40.0 / 17
    case .accessibility4: return 47.0 / 17
    case .accessibility5: return 53.0 / 17
    }
}
