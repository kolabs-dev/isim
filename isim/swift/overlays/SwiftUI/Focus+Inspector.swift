// .inspector (a sheet in compact width, as on iPhone), focus helpers (focusable, defaultFocus, focusSection) and
// focused values (@FocusedValue, @FocusedBinding, .focusedValue, .focusedSceneValue).
// Focused values follow focus (FocusEngine.swift): a `.focusedValue` is seen while its view or one inside it has focus,
// a `.focusedSceneValue` while its scene is shown; the innermost value of a key wins.
import UIKit

// MARK: - inspector
// inspector, inspectorColumnWidth: Presentation+More.swift (iPad: a trailing column; iPhone: a sheet)

// MARK: - focus helpers
public struct FocusInteractions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let activate = FocusInteractions(rawValue: 1), edit = FocusInteractions(rawValue: 2)
    public static let automatic: FocusInteractions = [.activate, .edit]
}
extension View {
    /// sets the focus binding to `value` when the view first appears if nothing is focused yet
    public func defaultFocus<V: Hashable>(_ binding: FocusState<V?>.Binding, _ value: V, priority: DefaultFocusEvaluationPriority = .automatic) -> some View {
        onAppear { if binding.wrappedValue == nil { binding.wrappedValue = value } }
    }
}
public struct DefaultFocusEvaluationPriority: Sendable {
    public static let automatic = DefaultFocusEvaluationPriority(), userInitiated = DefaultFocusEvaluationPriority()
}

// MARK: - focused values
public protocol FocusedValueKey { associatedtype Value }
public struct FocusedValues {
    var values: [ObjectIdentifier: Any] = [:]
    public subscript<K: FocusedValueKey>(key: K.Type) -> K.Value? {
        get { values[ObjectIdentifier(key)] as? K.Value }
        set { values[ObjectIdentifier(key)] = newValue }
    }
}
@MainActor final class _FocusedStore {
    static let shared = _FocusedStore()
    /// the values the views set in their last render, per graph: where (node path), whether scene-wide
    struct Entry { let path: String; let key: ObjectIdentifier; let value: Any; let scene: Bool }
    var entries: [ObjectIdentifier: (graph: WeakGraph, list: [Entry])] = [:]
    var pending: [ObjectIdentifier: [Entry]] = [:]
    var current = FocusedValues(), fingerprint = ""
    var graphs: [WeakGraph] = []
    final class WeakGraph { weak var g: _Graph?; init(_ g: _Graph) { self.g = g } }
    var responderObserver: NSObjectProtocol?
    func note(_ g: _Graph) {
        if !graphs.contains(where: { $0.g === g }) { graphs.append(WeakGraph(g)) }
        // any first responder change (UIKit views inside representables too) moves focus
        if responderObserver == nil {
            responderObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimFirstResponderDidChange"), object: nil, queue: nil) { _ in _FocusEngine.changed() }
        }
    }
    func add(_ g: _Graph, _ e: Entry) {
        let id = ObjectIdentifier(g)
        if pending[id] == nil {
            pending[id] = []
            g.postRender.append { [weak g] in guard let g else { return }; self.publish(g) }
        }
        pending[id]!.append(e)
    }
    /// after a render: the graph's values replace its old ones
    func publish(_ g: _Graph) {
        let id = ObjectIdentifier(g)
        entries[id] = (WeakGraph(g), pending.removeValue(forKey: id) ?? [])
        recompute()
    }
    /// what @FocusedValue sees: for each key, the innermost value around the focused view, else a scene value
    func recompute() {
        entries = entries.filter { $0.value.graph.g != nil }
        var out = FocusedValues()
        let focusedGraph = _FocusEngine.focused()?._focusGraph, focusedPath = _FocusEngine.focused()?._focusPath
        var best: [ObjectIdentifier: Int] = [:]
        for (_, e) in entries {
            for x in e.list where x.scene { if best[x.key] == nil { out.values[x.key] = x.value } }
            guard let fp = focusedPath, e.graph.g === focusedGraph else { continue }
            for x in e.list where !x.scene && (fp == x.path || fp.hasPrefix(x.path + "/")) {
                if x.path.count >= (best[x.key] ?? -1) { best[x.key] = x.path.count; out.values[x.key] = x.value }
            }
        }
        let fp = out.values.map { k, v in "\(k.hashValue):\(v is _AnyBindingMarker ? "binding" : String(describing: v))" }.sorted().joined(separator: "|")
        current = out
        if fp != fingerprint { fingerprint = fp; for w in graphs { w.g?.invalidate() } }
    }
}
protocol _AnyBindingMarker {}
extension Binding: _AnyBindingMarker {}

extension View {
    /// A value @FocusedValue sees while this view, or one inside it, has focus.
    public func focusedValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View { _focused(keyPath, value, scene: false) }
    /// A value @FocusedValue sees while the scene is shown.
    public func focusedSceneValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View { _focused(keyPath, value, scene: true) }
    func _focused<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?, scene: Bool) -> some View {
        _modify { ctx, c in
            let st = _FocusedStore.shared
            st.note(ctx.graph)
            var probe = FocusedValues()
            probe[keyPath: keyPath] = value
            if let (k, v) = probe.values.first { st.add(ctx.graph, .init(path: ctx.path, key: k, value: v, scene: scene)) }
            return _resolve(c, ctx.child("fv"))
        }
    }
}

@propertyWrapper public struct FocusedValue<Value>: DynamicProperty {
    let keyPath: KeyPath<FocusedValues, Value?>
    public init(_ keyPath: KeyPath<FocusedValues, Value?>) { self.keyPath = keyPath }
    @MainActor public var wrappedValue: Value? { _FocusedStore.shared.current[keyPath: keyPath] }
}
@propertyWrapper public struct FocusedBinding<Value>: DynamicProperty {
    let keyPath: KeyPath<FocusedValues, Binding<Value>?>
    public init(_ keyPath: KeyPath<FocusedValues, Binding<Value>?>) { self.keyPath = keyPath }
    @MainActor public var wrappedValue: Value? {
        get { _FocusedStore.shared.current[keyPath: keyPath]?.wrappedValue }
        nonmutating set { if let v = newValue { _FocusedStore.shared.current[keyPath: keyPath]?.wrappedValue = v } }
    }
    @MainActor public var projectedValue: Binding<Value?> {
        Binding(get: { self.wrappedValue }, set: { self.wrappedValue = $0 })
    }
}
