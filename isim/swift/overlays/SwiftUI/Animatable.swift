// isim SwiftUI: Animatable / VectorArithmetic and the interpolation of animatable data.
// A view (or shape, or modifier) conforming to Animatable whose animatableData changes in an animated
// update (withAnimation, .animation(_:value:), phaseAnimator) is re-evaluated every frame with the
// in-flight value until the animation ends, so custom shapes, trims, gradients, colors and custom
// Animatable views and modifiers interpolate. The timing matches isim UIKit's animation engine.
import UIKit

// MARK: - VectorArithmetic

public protocol VectorArithmetic: AdditiveArithmetic {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}
extension VectorArithmetic {
    public func scaled(by rhs: Double) -> Self { var v = self; v.scale(by: rhs); return v }
    public mutating func interpolate(towards other: Self, amount: Double) { self = self + (other - self).scaled(by: amount) }
    public func interpolated(towards other: Self, amount: Double) -> Self { var v = self; v.interpolate(towards: other, amount: amount); return v }
}
extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= rhs }
    public var magnitudeSquared: Double { self * self }
}
extension Float: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= Float(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}

extension Double: Animatable {}
extension Float: Animatable {}

public struct EmptyAnimatableData: VectorArithmetic, Sendable {
    public init() {}
    public static var zero: EmptyAnimatableData { EmptyAnimatableData() }
    public static func + (a: EmptyAnimatableData, b: EmptyAnimatableData) -> EmptyAnimatableData { a }
    public static func - (a: EmptyAnimatableData, b: EmptyAnimatableData) -> EmptyAnimatableData { a }
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { 0 }
    public static func == (a: EmptyAnimatableData, b: EmptyAnimatableData) -> Bool { true }
}

@frozen public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {
    public var first: First
    public var second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    public static var zero: AnimatablePair { AnimatablePair(.zero, .zero) }
    public static func + (a: AnimatablePair, b: AnimatablePair) -> AnimatablePair { AnimatablePair(a.first + b.first, a.second + b.second) }
    public static func - (a: AnimatablePair, b: AnimatablePair) -> AnimatablePair { AnimatablePair(a.first - b.first, a.second - b.second) }
    public mutating func scale(by rhs: Double) { first.scale(by: rhs); second.scale(by: rhs) }
    public var magnitudeSquared: Double { first.magnitudeSquared + second.magnitudeSquared }
    public static func == (a: AnimatablePair, b: AnimatablePair) -> Bool { a.first == b.first && a.second == b.second }
}
extension AnimatablePair: Sendable where First: Sendable, Second: Sendable {}

/// A variable-length vector (isim): colors and gradients animate as lists of numbers.
/// Vectors of different lengths do not interpolate (the change is applied at once).
public struct _AnimatableVector: VectorArithmetic, Sendable {
    public var values: [Double]
    public init(_ values: [Double] = []) { self.values = values }
    public static var zero: _AnimatableVector { _AnimatableVector() }
    static func zip(_ a: [Double], _ b: [Double], _ f: (Double, Double) -> Double) -> [Double] {
        if a.isEmpty { return b.map { f(0, $0) } }
        if b.isEmpty { return a.map { f($0, 0) } }
        return (0..<max(a.count, b.count)).map { f($0 < a.count ? a[$0] : 0, $0 < b.count ? b[$0] : 0) }
    }
    public static func + (a: _AnimatableVector, b: _AnimatableVector) -> _AnimatableVector { _AnimatableVector(zip(a.values, b.values, +)) }
    public static func - (a: _AnimatableVector, b: _AnimatableVector) -> _AnimatableVector { _AnimatableVector(zip(a.values, b.values, -)) }
    public mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }
    public var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}

// MARK: - Animatable

public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: AnimatableData { get set }
}
extension Animatable where AnimatableData == EmptyAnimatableData {
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
extension Animatable where Self: VectorArithmetic {
    public var animatableData: Self { get { self } set { self = newValue } }
}

/// Deprecated in iOS 17 but still common: a view modifier with animatable data.
public protocol AnimatableModifier: Animatable, ViewModifier {}
extension ModifiedContent: Animatable where Content: View, Modifier: ViewModifier & Animatable {
    public var animatableData: Modifier.AnimatableData { get { modifier.animatableData } set { modifier.animatableData = newValue } }
}

extension Angle: Animatable {
    public var animatableData: Double { get { radians } set { radians = newValue } }
}
extension CGPoint: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { AnimatablePair(x, y) } set { x = newValue.first; y = newValue.second } }
}
extension CGSize: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { AnimatablePair(width, height) } set { width = newValue.first; height = newValue.second } }
}
extension CGRect: Animatable {
    public var animatableData: AnimatablePair<CGPoint.AnimatableData, CGSize.AnimatableData> {
        get { AnimatablePair(origin.animatableData, size.animatableData) }
        set { origin.animatableData = newValue.first; size.animatableData = newValue.second }
    }
}
extension UnitPoint: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { AnimatablePair(x, y) } set { x = newValue.first; y = newValue.second } }
}
extension EdgeInsets: Animatable {
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(top, leading), AnimatablePair(bottom, trailing)) }
        set { top = newValue.first.first; leading = newValue.first.second; bottom = newValue.second.first; trailing = newValue.second.second }
    }
}

// MARK: - Timing (same curves as isim UIKit's engine)

extension Animation {
    /// Seconds until the animation ends (delay and speed included); nil when it repeats forever.
    var _totalDuration: Double? {
        if repeats < 0 { return nil }
        let cycle = duration * (autoreverses && repeats != 0 ? 2 : 1)
        return (delayTime + cycle) / speedFactor
    }
    static func _bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
        var t = x
        for _ in 0..<8 {
            let cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
            let fx = ((ax * t + bx) * t + cx) * t - x, d = (3 * ax * t + 2 * bx) * t + cx
            if abs(fx) < 1e-6 || abs(d) < 1e-6 { break }
            t -= fx / d
        }
        t = min(1, max(0, t))
        let cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
        return ((ay * t + by) * t + cy) * t
    }
    /// damped spring settling within `dur` (may overshoot 1)
    static func _spring(_ zetaIn: Double, _ dur: Double, _ t: Double, v0: Double = 0) -> Double {
        let zeta = max(0.01, zetaIn)
        if t >= dur { return 1 }
        if zeta < 1 {
            let w0 = 6.9 / (zeta * dur), wd = w0 * (1 - zeta * zeta).squareRoot()
            let e = Foundation.exp(-zeta * w0 * t)
            return 1 - e * (Foundation.cos(wd * t) + (zeta * w0 - v0 * w0) / wd * Foundation.sin(wd * t))
        }
        let w0 = 9.2 / dur, e = Foundation.exp(-w0 * t)
        return 1 - e * (1 + (w0 - v0 * w0) * t)
    }
    func _curve(_ x: Double, elapsed: Double) -> Double {
        switch curve {
        case .easeIn: return Animation._bezier(0.42, 0, 1, 1, x)
        case .easeOut: return Animation._bezier(0, 0, 0.58, 1, x)
        case .linear: return x
        case .easeInOut: return Animation._bezier(0.42, 0, 0.58, 1, x)
        case .spring(let d): return Animation._spring(d, duration, elapsed)
        }
    }
    /// Progress (0 -> 1, springs may overshoot) `t` seconds after the animation started, and whether it ended.
    func _progress(at t: Double) -> (Double, Bool) {
        if _animationsOff && repeats == 0 { return (1, true) }          // ISIM_ANIMATIONS=0 (tests)
        let el = t * speedFactor - delayTime
        if el < 0 { return (0, false) }
        let cycle = max(0.0001, duration)
        if repeats != 0 {
            let period = autoreverses ? 2 * cycle : cycle
            if repeats > 0, el >= period * Double(repeats) { return (autoreverses ? 0 : 1, true) }
            let ph = el.truncatingRemainder(dividingBy: period)
            let back = autoreverses && ph >= cycle
            let le = back ? ph - cycle : ph
            let p = _curve(le / cycle, elapsed: le)
            return (back ? 1 - p : p, false)
        }
        if el >= cycle { return (1, true) }
        return (_curve(el / cycle, elapsed: el), false)
    }
}

// MARK: - Per-frame ticking

/// Re-renders a graph every frame while something in it animates outside UIKit's engine
/// (animatable data, keyframes, TimelineView(.animation)).
@MainActor final class _FrameTicker {
    static var tickers: [ObjectIdentifier: _FrameTicker] = [:]
    weak var graph: _Graph?
    var timer: Timer?
    var requested = false               // a render since the last tick still animates
    var awaitedRender: Int?             // the graph's render count when the ticker asked for a frame
    static func request(_ g: _Graph) {
        let id = ObjectIdentifier(g)
        let t = tickers[id] ?? { let t = _FrameTicker(); t.graph = g; tickers[id] = t; return t }()
        t.requested = true
        if t.timer == nil {
            t.timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak t] _ in MainActor.assumeIsolated { t?.tick() } }
        }
    }
    func tick() {
        guard let g = graph else { stop(); _FrameTicker.tickers = _FrameTicker.tickers.filter { $0.value.graph != nil }; return }
        // the frame asked for has not rendered yet (a busy main thread): wait for it rather than judge by time, or
        // a late timer would end an animation that is still running
        if let n = awaitedRender, g.renderCount == n { return }
        // a render ran without requesting another frame: every animation has ended
        guard requested else { stop(); return }
        requested = false
        awaitedRender = g.renderCount
        g.invalidate()
    }
    func stop() { timer?.invalidate(); timer = nil; requested = false; awaitedRender = nil }
}

// MARK: - Interpolation of animatable data during evaluation

/// The animation of the update being evaluated (withAnimation, or an enclosing .animation(_:value:) whose value
/// changed); `_animationDisabled` when an enclosing .animation(nil, value:) changed.
struct _TransactionAnimationKey: EnvironmentKey { static var defaultValue: Animation? { nil } }
extension EnvironmentValues {
    var _transactionAnimation: Animation? { get { self[_TransactionAnimationKey.self] } set { self[_TransactionAnimationKey.self] = newValue } }
}

final class _AnimatableState<D: VectorArithmetic> {
    var target: D, from: D, current: D
    var start = 0.0
    var animation: Animation?
    init(_ v: D) { target = v; from = v; current = v }
}

/// Called for every view evaluated: returns the view with in-flight animatable data while it animates.
@MainActor func _animatableHook(_ view: any View, _ ctx: _Context) -> any View {
    guard let a = view as? any Animatable else { return view }
    return (_interpolate(a, ctx) as? any View) ?? view
}

@MainActor func _interpolate<A: Animatable>(_ a: A, _ ctx: _Context) -> A {
    if A.AnimatableData.self == EmptyAnimatableData.self { return a }
    let key = ctx.path + "#animatable"
    let g = ctx.graph
    g.usedKeys.insert(key)
    let value = a.animatableData
    guard let st = g.storage[key] as? _AnimatableState<A.AnimatableData> else {
        g.storage[key] = _AnimatableState(value)
        return a
    }
    let now = Date().timeIntervalSinceReferenceDate
    if value != st.target {
        if let anim = ctx.environment._transactionAnimation, _sameShape(st.current, value) {
            st.from = st.current; st.target = value; st.start = now; st.animation = anim
        } else {
            st.target = value; st.from = value; st.current = value; st.animation = nil
            return a
        }
    }
    guard let anim = st.animation else { return a }
    let (p, done) = anim._progress(at: now - st.start)
    if done {
        st.animation = nil; st.current = st.target
        return a
    }
    st.current = st.from + (st.target - st.from).scaled(by: p)
    _FrameTicker.request(g)
    var b = a
    b.animatableData = st.current
    return b
}

/// Variable-length vectors (gradients with a different number of stops) jump instead of interpolating.
func _sameShape<D: VectorArithmetic>(_ a: D, _ b: D) -> Bool {
    func lengths(_ v: Any) -> [Int] {
        if let x = v as? _AnimatableVector { return [x.values.count] }
        var out: [Int] = []
        for c in Mirror(reflecting: v).children where c.value is any VectorArithmetic { out += lengths(c.value) }
        return out
    }
    return lengths(a) == lengths(b)
}

/// ISIM_ANIMATIONS=0 makes animations finish at once (UI tests).
let _animationsOff: Bool = ProcessInfo.processInfo.environment["ISIM_ANIMATIONS"] == "0"
