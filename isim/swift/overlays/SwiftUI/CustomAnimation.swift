// isim SwiftUI: custom animations (iOS 17): CustomAnimation, AnimationContext, AnimationState, Animation(_:) and the
// CustomAnimation members of Animation (animate / velocity / shouldMerge / base / logicallyComplete(after:)).
// Adapted: isim animates SwiftUI changes with UIKit's engine (UIView animations: frames, opacity, transforms, colours),
// so a CustomAnimation runs as a timing curve: its animate(value:time:context:) is sampled for a unit value until it
// returns nil (that time is the duration), and every animated property follows those samples. Per-value state
// (AnimationContext.state) works within the sampling; shouldMerge and velocity are offered to the animation but isim
// does not retarget running animations with them.
import UIKit

/// The type of a custom animation: the value at a time, nil once it is done.
public protocol CustomAnimation: Hashable, Sendable {
    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V?
    func velocity<V: VectorArithmetic>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V?
    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool
}
extension CustomAnimation {
    public func velocity<V: VectorArithmetic>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V? { nil }
    public func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool { false }
}

/// A key for a custom animation's state.
public protocol AnimationStateKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

/// A custom animation's state, by key.
public struct AnimationState<Value: VectorArithmetic> {
    var storage: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: AnimationStateKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

/// What a custom animation sees as it runs: its state, whether it is logically complete, the environment.
public struct AnimationContext<Value: VectorArithmetic> {
    public var state: AnimationState<Value>
    public var isLogicallyComplete: Bool
    public var environment: EnvironmentValues { _environment }
    var _environment: EnvironmentValues
    init(state: AnimationState<Value> = AnimationState(), isLogicallyComplete: Bool = false, environment: EnvironmentValues = EnvironmentValues()) {
        self.state = state; self.isLogicallyComplete = isLogicallyComplete; _environment = environment
    }
    /// The same context with another value type's state.
    public func withState<T: VectorArithmetic>(_ state: AnimationState<T>) -> AnimationContext<T> {
        AnimationContext<T>(state: state, isLogicallyComplete: isLogicallyComplete, environment: _environment)
    }
}

/// A custom animation, type-erased and compared by value (Animation stays Equatable).
struct _AnyCustomAnimation: Equatable, @unchecked Sendable {
    let base: any CustomAnimation
    let key: AnyHashable
    init<A: CustomAnimation>(_ a: A) { base = a; key = AnyHashable(a) }
    static func == (a: _AnyCustomAnimation, b: _AnyCustomAnimation) -> Bool { a.key == b.key }
}

/// An Animation's own timing as a custom animation (Animation.base for isim's built-in curves).
struct _BuiltinAnimation: CustomAnimation {
    let animation: Animation
    static func == (a: _BuiltinAnimation, b: _BuiltinAnimation) -> Bool { a.animation == b.animation }
    func hash(into h: inout Hasher) { h.combine(animation.duration); h.combine(animation.delayTime); h.combine(animation.speedFactor) }
    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard let p = animation._unitProgress(at: time) else { return nil }
        var v = value; v.scale(by: p); return v
    }
    func velocity<V: VectorArithmetic>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V? {
        let h = 1e-3
        guard let a = animation._unitProgress(at: time), let b = animation._unitProgress(at: time + h) else { return nil }
        var v = value; v.scale(by: (b - a) / h); return v
    }
    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool {
        if case .spring = animation.curve { return true }
        return false
    }
}

extension Animation {
    /// An animation of a custom type.
    public init<A: CustomAnimation>(_ base: A) {
        self.init()
        if let b = base as? _BuiltinAnimation { self = b.animation; return }
        _custom = _AnyCustomAnimation(base)
        // sample its progress for a unit value until it is done (at most 10 s; 120 samples a second)
        var ctx = AnimationContext<Double>()
        var samples: [Double] = [], t = 0.0
        let step = 1.0 / 120
        while t <= 10, let v = base.animate(value: 1.0, time: t, context: &ctx) { samples.append(v); t += step }
        if samples.count < 2 { samples = [0, 1] }
        if let last = samples.last, abs(last - 1) > 1e-6 { samples.append(1) }     // it ends at the value
        curve = .sampled(samples)
        duration = max(step, Double(samples.count - 1) * step)
    }
    /// The animation's own type: a CustomAnimation (isim's built-in curves are exposed as one).
    public var base: any CustomAnimation { _custom?.base ?? _BuiltinAnimation(animation: self) }

    public func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        if let c = _custom?.base { return Self._animate(c, value: value, time: time, context: &context) }
        return _BuiltinAnimation(animation: self).animate(value: value, time: time, context: &context)
    }
    public func velocity<V: VectorArithmetic>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V? {
        if let c = _custom?.base { return Self._velocity(c, value: value, time: time, context: context) }
        return _BuiltinAnimation(animation: self).velocity(value: value, time: time, context: context)
    }
    public func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool {
        if let c = _custom?.base { return Self._merge(c, previous: previous, value: value, time: time, context: &context) }
        return _BuiltinAnimation(animation: self).shouldMerge(previous: previous, value: value, time: time, context: &context)
    }
    static func _animate<A: CustomAnimation, V: VectorArithmetic>(_ a: A, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        a.animate(value: value, time: time, context: &context)
    }
    static func _velocity<A: CustomAnimation, V: VectorArithmetic>(_ a: A, value: V, time: TimeInterval, context: AnimationContext<V>) -> V? {
        a.velocity(value: value, time: time, context: context)
    }
    static func _merge<A: CustomAnimation, V: VectorArithmetic>(_ a: A, previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool {
        a.shouldMerge(previous: previous, value: value, time: time, context: &context)
    }
    /// The animation, logically complete after `duration` (isim: completion callbacks still wait for its end).
    public func logicallyComplete(after duration: TimeInterval) -> Animation { self }

    /// Progress (0 → 1, springs may overshoot) at `time` seconds, nil once done (Animatable.swift's curves).
    func _unitProgress(at time: TimeInterval) -> Double? {
        let (p, done) = _progress(at: time)
        return done ? nil : p
    }
}

extension Binding {
    /// A binding whose changes animate.
    public func animation(_ animation: Animation? = .default) -> Binding<Value> {
        Binding(get: { self.wrappedValue }, set: { v in MainActor.assumeIsolated { withAnimation(animation) { self.wrappedValue = v } } })
    }
}
