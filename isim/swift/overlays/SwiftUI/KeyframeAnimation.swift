// isim SwiftUI: phase animations (phaseAnimator / PhaseAnimator) and keyframe animations
// (keyframeAnimator / KeyframeAnimator / KeyframeTimeline with Linear, Spring, Cubic and Move keyframes).
// Phases animate like withAnimation (UIKit-animated frames/opacity/transforms plus animatable data);
// keyframes are evaluated every frame.
import UIKit

/// The view a phaseAnimator / keyframeAnimator modifies, passed to its content closure.
public struct PlaceholderContentView<Value>: View, _PrimitiveView {
    let make: @MainActor (_Context) -> _Node
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
}

// MARK: - Phase animations

final class _PhaseState {
    var index = 0, rendered = 0
    var running = false
    var scheduledFor = -1
    var generation = 0
    var trigger: _AnimValueBox?
}

@MainActor func _phaseNode<Phase: Equatable>(_ ctx: _Context, phases: [Phase], trigger: _AnimValueBox?, triggerChanged: (_AnimValueBox?) -> Bool,
                                            animation: @escaping (Phase) -> Animation?, content: (Phase, _Context) -> _Node) -> _Node {
    let key = ctx.path + "#phase"
    let g = ctx.graph
    g.usedKeys.insert(key)
    let st = (g.storage[key] as? _PhaseState) ?? { let s = _PhaseState(); g.storage[key] = s; return s }()
    guard !phases.isEmpty else { return _GroupNode(path: ctx.path, children: []) }
    if st.index >= phases.count { st.index = 0; st.rendered = 0 }
    if let trigger {
        if st.trigger != nil, triggerChanged(st.trigger), phases.count > 1 {     // a trigger change runs through the phases once
            st.running = true; st.index = 1; st.generation += 1; st.scheduledFor = -1
        }
        st.trigger = trigger
    } else {
        st.running = phases.count > 1
    }
    let changed = st.rendered != st.index
    st.rendered = st.index
    let phase = phases[st.index]
    let anim = changed ? animation(phase) : nil
    let cctx = changed ? ctx.child("ph").with { $0._transactionAnimation = anim } : ctx.child("ph")
    let node = _AnimationScopeNode(path: ctx.path, animation: anim, active: changed, child: content(phase, cctx))
    // advance to the next phase once this one's animation is done
    if st.running && st.scheduledFor != st.index {
        st.scheduledFor = st.index
        let wait = changed ? max(1.0 / 60, anim.map { ($0._totalDuration ?? $0.duration / $0.speedFactor) } ?? 0) : 1.0 / 60
        let gen = st.generation, count = phases.count, cycling = trigger == nil
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak st, weak g] in
            MainActor.assumeIsolated {
                guard let st, let g, st.generation == gen, st.running else { return }
                let next = st.index + 1
                if next < count { st.index = next }
                else { st.index = 0; if !cycling { st.running = false } }
                g.invalidate()
            }
        }
    }
    return node
}

extension View {
    /// Cycles through `phases` continuously, animating each change.
    public func phaseAnimator<Phase: Equatable, Content: View>(_ phases: some Sequence<Phase>,
                                                               @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> Content,
                                                               animation: @escaping (Phase) -> Animation? = { _ in .default }) -> some View {
        let list = Array(phases)
        return _modify { ctx, c in
            _phaseNode(ctx, phases: list, trigger: nil, triggerChanged: { _ in false }, animation: animation) { phase, cctx in
                let placeholder = PlaceholderContentView<Self>(make: { pctx in _resolve(c, pctx.child("content")) })
                return _resolve(content(placeholder, phase), cctx)
            }
        }
    }
    /// Runs through `phases` once each time `trigger` changes, then returns to the first phase.
    public func phaseAnimator<Phase: Equatable, Trigger: Equatable, Content: View>(_ phases: some Sequence<Phase>, trigger: Trigger,
                                                               @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> Content,
                                                               animation: @escaping (Phase) -> Animation? = { _ in .default }) -> some View {
        let list = Array(phases)
        return _modify { ctx, c in
            _phaseNode(ctx, phases: list, trigger: _AnimValueBox(trigger), triggerChanged: { old in !(old?.equals(trigger) ?? true) }, animation: animation) { phase, cctx in
                let placeholder = PlaceholderContentView<Self>(make: { pctx in _resolve(c, pctx.child("content")) })
                return _resolve(content(placeholder, phase), cctx)
            }
        }
    }
}

public struct PhaseAnimator<Phase: Equatable, Content: View>: View, _PrimitiveView {
    let phases: [Phase], content: (Phase) -> Content, animation: (Phase) -> Animation?, trigger: _AnimValueBox?, changed: (_AnimValueBox?) -> Bool
    public init(_ phases: some Sequence<Phase>, @ViewBuilder content: @escaping (Phase) -> Content, animation: @escaping (Phase) -> Animation? = { _ in .default }) {
        self.phases = Array(phases); self.content = content; self.animation = animation; trigger = nil; changed = { _ in false }
    }
    public init<Trigger: Equatable>(_ phases: some Sequence<Phase>, trigger: Trigger, @ViewBuilder content: @escaping (Phase) -> Content, animation: @escaping (Phase) -> Animation? = { _ in .default }) {
        self.phases = Array(phases); self.content = content; self.animation = animation
        self.trigger = _AnimValueBox(trigger); changed = { old in !(old?.equals(trigger) ?? true) }
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _phaseNode(ctx, phases: phases, trigger: trigger, triggerChanged: changed, animation: animation) { phase, cctx in _resolve(content(phase), cctx) }
    }
}

// MARK: - Keyframes

/// Timing curves for keyframes (and UnitCurve-based animations).
public struct UnitCurve: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case bezier(Double, Double, Double, Double), circularIn, circularOut, circularInOut }
    let kind: Kind
    public static let linear = UnitCurve(kind: .bezier(0, 0, 1, 1))
    public static let easeIn = UnitCurve(kind: .bezier(0.42, 0, 1, 1))
    public static let easeOut = UnitCurve(kind: .bezier(0, 0, 0.58, 1))
    public static let easeInOut = UnitCurve(kind: .bezier(0.42, 0, 0.58, 1))
    public static let circularEaseIn = UnitCurve(kind: .circularIn)
    public static let circularEaseOut = UnitCurve(kind: .circularOut)
    public static let circularEaseInOut = UnitCurve(kind: .circularInOut)
    public static func bezier(startControlPoint: UnitPoint, endControlPoint: UnitPoint) -> UnitCurve {
        UnitCurve(kind: .bezier(startControlPoint.x, startControlPoint.y, endControlPoint.x, endControlPoint.y))
    }
    /// The curve's Bézier control points (circular curves: their close cubic approximations, for UIKit's engine).
    var controlPoints: (CGPoint, CGPoint) {
        switch kind {
        case .bezier(let a, let b, let c, let d): return (CGPoint(x: a, y: b), CGPoint(x: c, y: d))
        case .circularIn: return (CGPoint(x: 0.55, y: 0), CGPoint(x: 1, y: 0.45))
        case .circularOut: return (CGPoint(x: 0, y: 0.55), CGPoint(x: 0.45, y: 1))
        case .circularInOut: return (CGPoint(x: 0.85, y: 0), CGPoint(x: 0.15, y: 1))
        }
    }
    /// The curve's slope at a progress.
    public func velocity(at progress: Double) -> Double {
        let h = 1e-4, x = min(1 - h, max(0, progress))
        return (value(at: x + h) - value(at: x)) / h
    }
    /// The curve run backwards in time.
    public var inverse: UnitCurve {
        let (a, b) = controlPoints
        return UnitCurve(kind: .bezier(1 - b.x, 1 - b.y, 1 - a.x, 1 - a.y))
    }
    public func value(at progress: Double) -> Double {
        let x = min(1, max(0, progress))
        switch kind {
        case .bezier(let a, let b, let c, let d): return a == 0 && b == 0 && c == 1 && d == 1 ? x : Animation._bezier(a, b, c, d, x)
        case .circularIn: return 1 - (1 - x * x).squareRoot()
        case .circularOut: return ((2 - x) * x).squareRoot()
        case .circularInOut: return x < 0.5 ? 0.5 * (1 - (1 - 4 * x * x).squareRoot()) : 0.5 * ((-(2 * x - 3) * (2 * x - 1)).squareRoot() + 1)
        }
    }
}

public struct _Keyframe<Value: Animatable> {
    enum Kind { case linear(UnitCurve), spring(Spring), cubic, move }
    let to: Value, duration: Double, kind: Kind
}
public protocol KeyframeTrackContent<Value> {
    associatedtype Value: Animatable
    var _keyframes: [_Keyframe<Value>] { get }
}
public struct LinearKeyframe<Value: Animatable>: KeyframeTrackContent {
    public let _keyframes: [_Keyframe<Value>]
    public init(_ to: Value, duration: TimeInterval, timingCurve: UnitCurve = .linear) { _keyframes = [_Keyframe(to: to, duration: max(0, duration), kind: .linear(timingCurve))] }
}
public struct SpringKeyframe<Value: Animatable>: KeyframeTrackContent {
    public let _keyframes: [_Keyframe<Value>]
    public init(_ to: Value, duration: TimeInterval? = nil, spring: Spring = Spring(), startVelocity: Value? = nil) {
        let settle = Animation.spring(response: spring.response, dampingFraction: spring.dampingRatio).duration
        _keyframes = [_Keyframe(to: to, duration: max(0, duration ?? settle), kind: .spring(spring))]
    }
}
/// Cubic keyframes form a smooth (Catmull-Rom) curve through the keyframe values.
public struct CubicKeyframe<Value: Animatable>: KeyframeTrackContent {
    public let _keyframes: [_Keyframe<Value>]
    public init(_ to: Value, duration: TimeInterval, startVelocity: Value? = nil, endVelocity: Value? = nil) { _keyframes = [_Keyframe(to: to, duration: max(0, duration), kind: .cubic)] }
}
public struct MoveKeyframe<Value: Animatable>: KeyframeTrackContent {
    public let _keyframes: [_Keyframe<Value>]
    public init(_ to: Value) { _keyframes = [_Keyframe(to: to, duration: 0, kind: .move)] }
}
public struct _KeyframeList<Value: Animatable>: KeyframeTrackContent {
    public let _keyframes: [_Keyframe<Value>]
}
@resultBuilder public struct KeyframeTrackContentBuilder<Value: Animatable> {
    public static func buildExpression<K: KeyframeTrackContent>(_ k: K) -> _KeyframeList<Value> where K.Value == Value { _KeyframeList(_keyframes: k._keyframes) }
    public static func buildBlock(_ parts: _KeyframeList<Value>...) -> _KeyframeList<Value> { _KeyframeList(_keyframes: parts.flatMap(\._keyframes)) }
    public static func buildArray(_ parts: [_KeyframeList<Value>]) -> _KeyframeList<Value> { _KeyframeList(_keyframes: parts.flatMap(\._keyframes)) }
    public static func buildOptional(_ p: _KeyframeList<Value>?) -> _KeyframeList<Value> { p ?? _KeyframeList(_keyframes: []) }
    public static func buildEither(first p: _KeyframeList<Value>) -> _KeyframeList<Value> { p }
    public static func buildEither(second p: _KeyframeList<Value>) -> _KeyframeList<Value> { p }
}

/// Value at time t of one track of keyframes starting from `initial`.
func _trackValue<V: Animatable>(_ frames: [_Keyframe<V>], initial: V, at t: Double) -> V {
    var prev = initial, start = 0.0
    for (i, f) in frames.enumerated() {
        let end = start + f.duration
        if t < end, f.duration > 0 {
            let p = (t - start) / f.duration
            var v = f.to
            let a = prev.animatableData, b = f.to.animatableData
            switch f.kind {
            case .move: return f.to
            case .linear(let c): v.animatableData = a + (b - a).scaled(by: c.value(at: p))
            case .spring(let s):
                let pr = Animation._spring(s.dampingRatio, f.duration, t - start)
                v.animatableData = a + (b - a).scaled(by: pr)
            case .cubic:
                // Catmull-Rom tangents from the neighbouring keyframe values
                let before = i > 0 ? (i > 1 ? frames[i - 2].to.animatableData : initial.animatableData) : a
                let after = i + 1 < frames.count ? frames[i + 1].to.animatableData : b
                let m0 = (b - before).scaled(by: 0.5), m1 = (after - a).scaled(by: 0.5)
                let p2 = p * p, p3 = p2 * p
                v.animatableData = a.scaled(by: 2 * p3 - 3 * p2 + 1) + m0.scaled(by: p3 - 2 * p2 + p) + b.scaled(by: -2 * p3 + 3 * p2) + m1.scaled(by: p3 - p2)
            }
            return v
        }
        prev = f.to
        start = end
    }
    return prev
}

/// One track of a keyframe animation, applied to the animated value.
public struct _KeyframeTrackFn<Root> {
    let duration: Double
    let apply: (inout Root, Double) -> Void
}
public protocol Keyframes<Value> {
    associatedtype Value
    var _tracks: [_KeyframeTrackFn<Value>] { get }
}
public struct KeyframeTrack<Root, TrackValue: Animatable, Content: KeyframeTrackContent>: Keyframes where Content.Value == TrackValue {
    public typealias Value = Root
    public let _tracks: [_KeyframeTrackFn<Root>]
    public init(_ keyPath: WritableKeyPath<Root, TrackValue>, @KeyframeTrackContentBuilder<TrackValue> content: () -> Content) {
        let frames = content()._keyframes
        let d = frames.reduce(0) { $0 + $1.duration }
        _tracks = [_KeyframeTrackFn(duration: d, apply: { root, t in root[keyPath: keyPath] = _trackValue(frames, initial: root[keyPath: keyPath], at: t) })]
    }
    public init(@KeyframeTrackContentBuilder<Root> content: () -> Content) where Root == TrackValue {
        let frames = content()._keyframes
        let d = frames.reduce(0) { $0 + $1.duration }
        _tracks = [_KeyframeTrackFn(duration: d, apply: { root, t in root = _trackValue(frames, initial: root, at: t) })]
    }
}
public struct _KeyframeTracks<Value>: Keyframes {
    public let _tracks: [_KeyframeTrackFn<Value>]
}
@resultBuilder public struct KeyframesBuilder<Value> {
    public static func buildExpression<K: Keyframes>(_ k: K) -> _KeyframeTracks<Value> where K.Value == Value { _KeyframeTracks(_tracks: k._tracks) }
    public static func buildExpression<K: KeyframeTrackContent>(_ k: K) -> _KeyframeTracks<Value> where K.Value == Value {
        let frames = k._keyframes, d = frames.reduce(0) { $0 + $1.duration }
        return _KeyframeTracks(_tracks: [_KeyframeTrackFn(duration: d, apply: { root, t in root = _trackValue(frames, initial: root, at: t) })])
    }
    public static func buildBlock(_ parts: _KeyframeTracks<Value>...) -> _KeyframeTracks<Value> { _KeyframeTracks(_tracks: parts.flatMap(\._tracks)) }
    public static func buildArray(_ parts: [_KeyframeTracks<Value>]) -> _KeyframeTracks<Value> { _KeyframeTracks(_tracks: parts.flatMap(\._tracks)) }
    public static func buildOptional(_ p: _KeyframeTracks<Value>?) -> _KeyframeTracks<Value> { p ?? _KeyframeTracks(_tracks: []) }
    public static func buildEither(first p: _KeyframeTracks<Value>) -> _KeyframeTracks<Value> { p }
    public static func buildEither(second p: _KeyframeTracks<Value>) -> _KeyframeTracks<Value> { p }
}

/// Keyframes evaluated at any time (also what keyframeAnimator plays).
public struct KeyframeTimeline<Value> {
    let initial: Value, tracks: [_KeyframeTrackFn<Value>]
    public init<K: Keyframes>(initialValue: Value, @KeyframesBuilder<Value> content: () -> K) where K.Value == Value {
        initial = initialValue; tracks = content()._tracks
    }
    init(initial: Value, tracks: [_KeyframeTrackFn<Value>]) { self.initial = initial; self.tracks = tracks }
    public var duration: TimeInterval { tracks.map(\.duration).max() ?? 0 }
    public func value(time: Double) -> Value {
        var v = initial
        for t in tracks { t.apply(&v, max(0, time)) }
        return v
    }
    public func value(progress: Double) -> Value { value(time: progress * duration) }
}

final class _KeyframeState { var start: Double?; var trigger: _AnimValueBox? }

@MainActor func _keyframeNode<Value>(_ ctx: _Context, initial: Value, repeating: Bool, trigger: _AnimValueBox?, triggerChanged: (_AnimValueBox?) -> Bool,
                                     tracks: (Value) -> [_KeyframeTrackFn<Value>], content: (Value, _Context) -> _Node) -> _Node {
    let key = ctx.path + "#keyframes"
    let g = ctx.graph
    g.usedKeys.insert(key)
    let st = (g.storage[key] as? _KeyframeState) ?? { let s = _KeyframeState(); g.storage[key] = s; return s }()
    let now = Date().timeIntervalSinceReferenceDate
    let timeline = KeyframeTimeline(initial: initial, tracks: tracks(initial))
    var value = initial
    if let trigger {
        if st.trigger != nil, triggerChanged(st.trigger) { st.start = now }
        st.trigger = trigger
        if let s = st.start {
            if now - s >= timeline.duration { st.start = nil }
            else { value = timeline.value(time: now - s); _FrameTicker.request(g) }
        }
    } else if repeating || st.start == nil || now - st.start! < timeline.duration {
        if st.start == nil { st.start = now }
        var t = now - st.start!
        if repeating, timeline.duration > 0 { t = t.truncatingRemainder(dividingBy: timeline.duration) }
        value = timeline.value(time: t)
        if repeating || t < timeline.duration { _FrameTicker.request(g) }
    } else {
        value = timeline.value(time: timeline.duration)
    }
    return content(value, ctx.child("kf"))
}

extension View {
    /// Plays the keyframes over and over (repeating) or once, from when the view appears.
    public func keyframeAnimator<Value, Content: View, K: Keyframes>(initialValue: Value, repeating: Bool = true,
                                                                    @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> Content,
                                                                    @KeyframesBuilder<Value> keyframes: @escaping (Value) -> K) -> some View where K.Value == Value {
        _modify { ctx, c in
            _keyframeNode(ctx, initial: initialValue, repeating: repeating, trigger: nil, triggerChanged: { _ in false }, tracks: { keyframes($0)._tracks }) { v, cctx in
                _resolve(content(PlaceholderContentView<Self>(make: { pctx in _resolve(c, pctx.child("content")) }), v), cctx)
            }
        }
    }
    /// Plays the keyframes once each time `trigger` changes; shows `initialValue` otherwise.
    public func keyframeAnimator<Value, Trigger: Equatable, Content: View, K: Keyframes>(initialValue: Value, trigger: Trigger,
                                                                    @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> Content,
                                                                    @KeyframesBuilder<Value> keyframes: @escaping (Value) -> K) -> some View where K.Value == Value {
        _modify { ctx, c in
            _keyframeNode(ctx, initial: initialValue, repeating: false, trigger: _AnimValueBox(trigger), triggerChanged: { old in !(old?.equals(trigger) ?? true) },
                          tracks: { keyframes($0)._tracks }) { v, cctx in
                _resolve(content(PlaceholderContentView<Self>(make: { pctx in _resolve(c, pctx.child("content")) }), v), cctx)
            }
        }
    }
}

public struct KeyframeAnimator<Value, KeyframePath: Keyframes, Content: View>: View, _PrimitiveView where KeyframePath.Value == Value {
    let initial: Value, repeating: Bool, trigger: _AnimValueBox?, changed: (_AnimValueBox?) -> Bool
    let content: (Value) -> Content, keyframes: (Value) -> KeyframePath
    public init(initialValue: Value, repeating: Bool = true, @ViewBuilder content: @escaping (Value) -> Content, @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath) {
        initial = initialValue; self.repeating = repeating; trigger = nil; changed = { _ in false }; self.content = content; self.keyframes = keyframes
    }
    public init<Trigger: Equatable>(initialValue: Value, trigger: Trigger, @ViewBuilder content: @escaping (Value) -> Content, @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath) {
        initial = initialValue; repeating = false; self.trigger = _AnimValueBox(trigger); changed = { old in !(old?.equals(trigger) ?? true) }
        self.content = content; self.keyframes = keyframes
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _keyframeNode(ctx, initial: initial, repeating: repeating, trigger: trigger, triggerChanged: changed, tracks: { keyframes($0)._tracks }) { v, cctx in _resolve(content(v), cctx) }
    }
}
