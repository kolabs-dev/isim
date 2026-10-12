// isim SwiftUI: Transaction — the animation of a state change and custom values (`TransactionKey`, `@Entry`) that
// travel with it: `withTransaction(_:_:)` / `withTransaction(_:_:_:)` (key path), `.transaction { }`,
// `.transaction(value:_:)`, `.transaction(_:body:)`; the transaction reaches the views evaluated for the change
// (and UIViewRepresentable contexts), and `.transaction` closures may change its animation for their content.
import UIKit

public protocol TransactionKey {
    associatedtype Value
    static var defaultValue: Value { get }
    /// whether two values are the same (the transaction compares changes with it); by default never
    static func _valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool
}
extension TransactionKey {
    public static func _valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool { false }
}
extension TransactionKey where Value: Equatable {
    public static func _valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool { lhs == rhs }
}

public struct Transaction: @unchecked Sendable {      /* custom values are stored as Any, like SwiftUI's */
    public var animation: Animation?
    public var disablesAnimations = false
    /// a change that is part of a continuous interaction (a drag), for which animations may be skipped
    public var isContinuous = false
    public var tracksVelocity = false
    public var scrollTargetAnchor: UnitPoint?
    var values: [ObjectIdentifier: Any] = [:]
    var completions: [() -> Void] = []
    public init() {}
    public init(animation: Animation?) { self.animation = animation }
    public subscript<K: TransactionKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
    /// Runs `completion` when this transaction's animations finish (iOS 17).
    public mutating func addAnimationCompletion(criteria: AnimationCompletionCriteria = .logicallyComplete, _ completion: @escaping () -> Void) {
        completions.append(completion)
    }
}
public struct AnimationCompletionCriteria: Hashable, Sendable {
    let id: Int
    public static let logicallyComplete = AnimationCompletionCriteria(id: 0), removed = AnimationCompletionCriteria(id: 1)
}

/// The transaction of the change being rendered (set at the root; `.transaction` modifiers change it below them).
struct _TransactionValuesKey: EnvironmentKey { static var defaultValue: Transaction { Transaction() } }
extension EnvironmentValues {
    /// the current transaction: its animation is the one in effect here (`.animation(_:value:)` included)
    var _transaction: Transaction {
        get { var t = self[_TransactionValuesKey.self]; t.animation = _transactionAnimation; return t }
        set { self[_TransactionValuesKey.self] = newValue; _transactionAnimation = newValue.disablesAnimations ? nil : newValue.animation }
    }
}
extension _AnimationContext {
    /// the transaction of the next render (withTransaction), taken with the animation
    static var pendingTransaction: Transaction?
}

@MainActor public func withTransaction<R>(_ t: Transaction, _ body: () throws -> R) rethrows -> R {
    let r = try body()
    _AnimationContext.pendingTransaction = t
    _AnimationContext.pendingStamp = Date().timeIntervalSinceReferenceDate
    if let a = t.animation, !t.disablesAnimations { _AnimationContext.pending = a } else { _AnimationContext.pending = nil }
    if !t.completions.isEmpty {
        let d = t.animation.map { ($0.duration + $0.delayTime) / $0.speedFactor } ?? 0
        let done = t.completions
        DispatchQueue.main.asyncAfter(deadline: .now() + d) { for c in done { c() } }
    }
    return r
}
/// A transaction with one value set (`withTransaction(\.isContinuous, true) { ... }`).
@MainActor public func withTransaction<R, V>(_ keyPath: WritableKeyPath<Transaction, V>, _ value: V, _ body: () throws -> R) rethrows -> R {
    var t = _AnimationContext.pendingTransaction ?? Transaction()
    if let a = _AnimationContext.pending { t.animation = a }
    t[keyPath: keyPath] = value
    return try withTransaction(t, body)
}

extension View {
    /// Changes the transaction of the changes rendered in this view (its animation, its values).
    public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View {
        _env { e in var t = e._transaction; transform(&t); e._transaction = t }
    }
    /// iOS 17: the transform applies only when `value` changed in this update.
    public func transaction<V: Equatable>(value: V, _ transform: @escaping (inout Transaction) -> Void) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#txv"
            ctx.graph.usedKeys.insert(key)
            let changed = (ctx.graph.storage[key] as? _AnimValueBox).map { !$0.equals(value) } ?? false
            ctx.graph.storage[key] = _AnimValueBox(value)
            return _resolve(c, ctx.child("txv").with { e in if changed { var t = e._transaction; transform(&t); e._transaction = t } })
        }
    }
    /// iOS 17: the transform applies to the views `body` makes from this content (the rest keeps the transaction).
    public func transaction<V: View>(_ transform: @escaping (inout Transaction) -> Void, @ViewBuilder body: (_TransactionScopedContent<Self>) -> V) -> some View {
        let scoped = body(_TransactionScopedContent(content: self, transform: transform))
        return _modify { ctx, _ in _resolve(scoped, ctx.child("txb")) }
    }
}
/// The content inside `.transaction(_:body:)`: evaluated with the changed transaction.
public struct _TransactionScopedContent<Content: View>: View, _PrimitiveView {
    let content: Content, transform: (inout Transaction) -> Void
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _resolve(content, ctx.child("txc").with { e in var t = e._transaction; transform(&t); e._transaction = t })
    }
}
