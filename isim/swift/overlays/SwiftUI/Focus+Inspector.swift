// .inspector (a sheet in compact width, as on iPhone), focus helpers (focusable, defaultFocus, focusSection) and
// focused values (@FocusedValue, @FocusedBinding, .focusedValue, .focusedSceneValue).
// isim adaptation: there is no per-view focus chain for values, so focused values set anywhere on screen are
// visible to every @FocusedValue (like scene values); the last one resolved wins.
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
    public func focusable(_ isFocusable: Bool = true) -> some View { self }
    public func focusable(_ isFocusable: Bool = true, interactions: FocusInteractions) -> some View { self }
    public func focusSection() -> some View { self }
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
    var current = FocusedValues(), pending = FocusedValues(), fingerprint = ""
    var graphs: [WeakGraph] = []
    final class WeakGraph { weak var g: _Graph?; init(_ g: _Graph) { self.g = g } }
    func note(_ g: _Graph) { if !graphs.contains(where: { $0.g === g }) { graphs.append(WeakGraph(g)) } }
    /// after a render: publish what the views set; re-render readers when it changed
    func publish() {
        let fp = pending.values.map { k, v in "\(k.hashValue):\(v is _AnyBindingMarker ? "binding" : String(describing: v))" }.sorted().joined(separator: "|")
        current = pending
        pending = FocusedValues()
        if fp != fingerprint { fingerprint = fp; for w in graphs { w.g?.invalidate() } }
        scheduled = false
    }
    var scheduled = false
}
protocol _AnyBindingMarker {}
extension Binding: _AnyBindingMarker {}

extension View {
    public func focusedValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View {
        _modify { ctx, c in
            let st = _FocusedStore.shared
            st.note(ctx.graph)
            st.pending[keyPath: keyPath] = value
            if !st.scheduled { st.scheduled = true; ctx.graph.postRender.append { st.publish() } }
            return _resolve(c, ctx.child("fv"))
        }
    }
    public func focusedSceneValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View {
        focusedValue(keyPath, value)
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
