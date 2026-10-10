// isim SwiftUI: animations, transitions and matched geometry.
// SwiftUI views render to UIKit views, so an animated update runs the view updates inside a UIKit
// animation (UIView.animate: frames, opacity, transforms and colors interpolate; springs, delay, repeat):
//  - withAnimation { ... } animates the next render; .animation(_:value:) animates its subtree when the value changes
//  - views inserted in an animated update play their transition (default .opacity); removed ones fade/move out
//  - matchedGeometryEffect: a view inserted with an id that was on screen moves from the old frame
// Animatable data (shape trims and paths, gradients, colors of shapes, custom Animatable views, modifiers and
// GeometryEffects) interpolates per frame during the same updates (Animatable.swift). Not animated: text content.
import UIKit

public struct Animation: Equatable, Sendable {
    enum Curve: Equatable, Sendable { case easeInOut, easeIn, easeOut, linear, spring(damping: Double) }
    var curve: Curve = .spring(damping: 1)
    var duration: Double = 0.55          // springs: time to settle
    var delayTime: Double = 0
    var speedFactor: Double = 1
    var repeats = 0                      // 0 once, -1 forever, n times
    var autoreverses = false

    public static let `default` = Animation()                                   // iOS 17: a smooth spring
    public static let easeInOut = Animation(curve: .easeInOut, duration: 0.35)
    public static let easeIn = Animation(curve: .easeIn, duration: 0.35)
    public static let easeOut = Animation(curve: .easeOut, duration: 0.35)
    public static let linear = Animation(curve: .linear, duration: 0.35)
    public static let spring = Animation.spring(response: 0.5, dampingFraction: 0.825)
    public static let interactiveSpring = Animation.interactiveSpring()

    public static func easeIn(duration: Double) -> Animation { Animation(curve: .easeIn, duration: duration) }
    public static func easeOut(duration: Double) -> Animation { Animation(curve: .easeOut, duration: duration) }
    public static func easeInOut(duration: Double) -> Animation { Animation(curve: .easeInOut, duration: duration) }
    public static func linear(duration: Double) -> Animation { Animation(curve: .linear, duration: duration) }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double = 0.35) -> Animation {
        Animation(curve: c0x < 0.2 ? .easeOut : c1x > 0.8 ? .easeIn : .easeInOut, duration: duration)
    }
    /// response ~ the spring's period; it settles in about response / damping (capped)
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation {
        let d = max(0.05, dampingFraction)
        return Animation(curve: .spring(damping: d), duration: min(3, max(0.15, response * (d >= 1 ? 1.25 : 1.1 / d))))
    }
    public static func spring(duration: Double = 0.5, bounce: Double = 0, blendDuration: Double = 0) -> Animation {
        spring(response: duration, dampingFraction: bounce >= 0 ? 1 - bounce : 1 / (1 - bounce))
    }
    public static func spring(_ spring: Spring, blendDuration: Double = 0) -> Animation { Animation.spring(response: spring.response, dampingFraction: spring.dampingRatio) }
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation {
        spring(response: response, dampingFraction: dampingFraction)
    }
    public static func interpolatingSpring(stiffness: Double, damping: Double, initialVelocity: Double = 0) -> Animation {
        let w = sqrt(max(1, stiffness)), zeta = damping / (2 * w)
        return spring(response: 2 * .pi / w, dampingFraction: zeta)
    }
    public static func interpolatingSpring(duration: Double = 0.5, bounce: Double = 0, initialVelocity: Double = 0) -> Animation { spring(duration: duration, bounce: bounce) }
    public static var bouncy: Animation { spring(duration: 0.5, bounce: 0.3) }
    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation { spring(duration: duration, bounce: 0.3 + extraBounce) }
    public static var snappy: Animation { spring(duration: 0.5, bounce: 0.15) }
    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation { spring(duration: duration, bounce: 0.15 + extraBounce) }
    public static var smooth: Animation { spring(duration: 0.5, bounce: 0) }
    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0) -> Animation { spring(duration: duration, bounce: extraBounce) }

    public func repeatForever(autoreverses: Bool = true) -> Animation { var a = self; a.repeats = -1; a.autoreverses = autoreverses; return a }
    public func repeatCount(_ n: Int, autoreverses: Bool = true) -> Animation { var a = self; a.repeats = n; a.autoreverses = autoreverses; return a }
    public func delay(_ d: Double) -> Animation { var a = self; a.delayTime += d; return a }
    public func speed(_ s: Double) -> Animation { var a = self; a.speedFactor *= max(0.01, s); return a }

    /// Runs `updates` as a UIKit animation with this timing.
    @MainActor func _run(_ updates: () -> Void, completion: (() -> Void)? = nil) {
        var opts: UIView.AnimationOptions = [.allowUserInteraction]
        // finite repeat counts run once (isim); forever repeats (and autoreverse) are supported
        if repeats < 0 { opts.insert(.repeat); if autoreverses { opts.insert(.autoreverse) } }
        switch curve {
        case .easeIn: opts.insert(.curveEaseIn)
        case .easeOut: opts.insert(.curveEaseOut)
        case .linear: opts.insert(.curveLinear)
        default: break
        }
        let d = duration / speedFactor, delay = delayTime / speedFactor
        withoutActuallyEscaping(updates) { body in
            if case .spring(let damping) = curve {
                UIView.animate(withDuration: d, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: 0, options: opts,
                               animations: body, completion: { _ in completion?() })
            } else {
                UIView.animate(withDuration: d, delay: delay, options: opts, animations: body, completion: { _ in completion?() })
            }
        }
    }
}

public struct Spring: Hashable, Sendable {
    public var response: Double, dampingRatio: Double
    public init() { self.init(response: 0.5, dampingRatio: 1) }
    public init(response: Double = 0.5, dampingRatio: Double = 1) { self.response = response; self.dampingRatio = dampingRatio }
    public init(duration: Double = 0.5, bounce: Double = 0) { response = duration; dampingRatio = bounce >= 0 ? 1 - bounce : 1 / (1 - bounce) }
    public static var smooth: Spring { Spring(duration: 0.5, bounce: 0) }
    public static var snappy: Spring { Spring(duration: 0.5, bounce: 0.15) }
    public static var bouncy: Spring { Spring(duration: 0.5, bounce: 0.3) }
}

/// The animation of the current state change (withAnimation / withTransaction).
@MainActor enum _AnimationContext {
    static var pending: Animation?
    static var pendingStamp = 0.0
    static var pendingDisables = false
    /// the animation to apply to the render happening now (taken once)
    static func take() -> Animation? {
        defer { pending = nil }
        guard let a = pending, Date().timeIntervalSinceReferenceDate - pendingStamp < 1 else { return nil }
        return a
    }
    /// the transaction for the render happening now (withTransaction's, else one with the animation)
    static func takeTransaction(_ animation: Animation?) -> Transaction {
        defer { pendingTransaction = nil }
        var t = (Date().timeIntervalSinceReferenceDate - pendingStamp < 1 ? pendingTransaction : nil) ?? Transaction()
        t.animation = animation
        return t
    }
}

@MainActor public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    let r = try body()
    if let animation { _AnimationContext.pending = animation; _AnimationContext.pendingStamp = Date().timeIntervalSinceReferenceDate }
    return r
}
@MainActor public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result, completion: @escaping () -> Void) rethrows -> Result {
    let r = try withAnimation(animation, body)
    let d = animation.map { ($0.duration + $0.delayTime) / $0.speedFactor } ?? 0
    DispatchQueue.main.asyncAfter(deadline: .now() + d) { completion() }
    return r
}
// withTransaction: Transaction.swift

// MARK: - Transitions

public struct AnyTransition: Sendable {
    indirect enum Kind: Sendable {
        case identity, opacity, scale(CGFloat, UnitPoint), move(Edge), offset(CGSize), slide
        case combined(Kind, Kind), asymmetric(Kind, Kind)
    }
    let kind: Kind
    var animation: Animation?
    init(_ kind: Kind, animation: Animation? = nil) { self.kind = kind; self.animation = animation }
    public static let identity = AnyTransition(.identity)
    public static let opacity = AnyTransition(.opacity)
    public static let scale = AnyTransition(.scale(0, .center))
    public static let slide = AnyTransition(.slide)
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { AnyTransition(.scale(scale, anchor)) }
    public static func move(edge: Edge) -> AnyTransition { AnyTransition(.move(edge)) }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition { AnyTransition(.offset(CGSize(width: x, height: y))) }
    public static func offset(_ s: CGSize) -> AnyTransition { AnyTransition(.offset(s)) }
    public static func push(from edge: Edge) -> AnyTransition {
        let opposite: Edge = edge == .leading ? .trailing : edge == .trailing ? .leading : edge == .top ? .bottom : .top
        return AnyTransition(.asymmetric(.move(edge), .move(opposite)))
    }
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { AnyTransition(.asymmetric(insertion.kind, removal.kind)) }
    public func combined(with other: AnyTransition) -> AnyTransition { AnyTransition(.combined(kind, other.kind), animation: animation ?? other.animation) }
    public func animation(_ a: Animation?) -> AnyTransition { var t = self; t.animation = a; return t }

    /// The "not present" state of a view for this transition (insertion start / removal end).
    @MainActor static func apply(_ k: Kind, insertion: Bool, to v: UIView, frame: CGRect, container: CGRect) -> CGRect {
        switch k {
        case .identity: return frame
        case .opacity: v.alpha = 0; return frame
        case .scale(let s, let a):
            let dx = (a.x - 0.5) * frame.width, dy = (a.y - 0.5) * frame.height
            let m = CGAffineTransform(translationX: -dx, y: -dy).concatenating(CGAffineTransform(scaleX: max(s, 0.001), y: max(s, 0.001))).concatenating(CGAffineTransform(translationX: dx, y: dy))
            v.transform = v.transform.concatenating(m)
            return frame
        case .move(let e):
            switch e {
            case .leading: return frame.offsetBy(dx: container.minX - frame.maxX, dy: 0)
            case .trailing: return frame.offsetBy(dx: container.maxX - frame.minX, dy: 0)
            case .top: return frame.offsetBy(dx: 0, dy: container.minY - frame.maxY)
            case .bottom: return frame.offsetBy(dx: 0, dy: container.maxY - frame.minY)
            }
        case .offset(let s): return frame.offsetBy(dx: s.width, dy: s.height)
        case .slide: return apply(.move(insertion ? .leading : .trailing), insertion: insertion, to: v, frame: frame, container: container)
        case .combined(let a, let b):
            let f = apply(a, insertion: insertion, to: v, frame: frame, container: container)
            return apply(b, insertion: insertion, to: v, frame: f, container: container)
        case .asymmetric(let i, let r): return apply(insertion ? i : r, insertion: insertion, to: v, frame: frame, container: container)
        }
    }
}

extension View {
    public func transition(_ t: AnyTransition) -> some View {
        _modify { ctx, c in _TransitionNode(path: ctx.path, transition: t, child: _resolve(c, ctx.child("tr"))) }
    }
    /// Animates the changes in this view when `value` changes (nil: changes in it are not animated).
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#animv"
            ctx.graph.usedKeys.insert(key)
            let box = ctx.graph.storage[key] as? _AnimValueBox
            let changed = box.map { !$0.equals(value) } ?? false
            ctx.graph.storage[key] = _AnimValueBox(value)
            let cctx = changed ? ctx.child("an").with { $0._transactionAnimation = animation } : ctx.child("an")
            return _AnimationScopeNode(path: ctx.path, animation: animation, active: changed, child: _resolve(c, cctx))
        }
    }
    /// Deprecated form: animates every change in this view.
    public func animation(_ animation: Animation?) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#anim0"
            ctx.graph.usedKeys.insert(key)
            let first = ctx.graph.storage[key] == nil
            ctx.graph.storage[key] = _AnimValueBox(0)
            let cctx = first ? ctx.child("an") : ctx.child("an").with { $0._transactionAnimation = animation }
            return _AnimationScopeNode(path: ctx.path, animation: animation, active: !first, child: _resolve(c, cctx))
        }
    }
    public func matchedGeometryEffect<ID: Hashable>(id: ID, in namespace: Namespace.ID, properties: MatchedGeometryProperties = .frame,
                                                    anchor: UnitPoint = .center, isSource: Bool = true) -> some View {
        _modify { ctx, c in _MatchedNode(path: ctx.path, matchKey: "\(namespace.value)/\(AnyHashable(id).hashValue)", child: _resolve(c, ctx.child("mg"))) }
    }
}

final class _AnimValueBox {
    let value: Any
    let equals: (Any) -> Bool
    init<V: Equatable>(_ v: V) { value = v; equals = { ($0 as? V) == v } }
}

final class _TransitionNode: _WrapperNode {
    let transition: AnyTransition
    init(path: String, transition: AnyTransition, child: _Node) { self.transition = transition; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        g.transitions[viewKey] = transition
        return v
    }
}

final class _AnimationScopeNode: _WrapperNode {
    let animation: Animation?, active: Bool
    init(path: String, animation: Animation?, active: Bool, child: _Node) { self.animation = animation; self.active = active; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        guard active else { super.mountChildren(g, in: view); return }
        if let a = animation { a._run { super.mountChildren(g, in: view) } }
        else { UIView.performWithoutAnimation { super.mountChildren(g, in: view) } }
    }
}

final class _MatchedNode: _WrapperNode {
    let matchKey: String
    init(path: String, matchKey: String, child: _Node) { self.matchKey = matchKey; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
}
