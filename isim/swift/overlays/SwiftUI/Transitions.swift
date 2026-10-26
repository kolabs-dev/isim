// isim SwiftUI: the Transition protocol (iOS 17): TransitionPhase, TransitionProperties, the built-in transition types
// (OpacityTransition, ScaleTransition, MoveTransition, OffsetTransition, PushTransition, SlideTransition,
// IdentityTransition, AsymmetricTransition, BlurReplaceTransition), custom transitions and
// AnyTransition.modifier(active:identity:).
// Adapted: isim plays insertions and removals with UIKit's engine (Graph.mount / unmountGone animate a view from or to
// its "not present" state). A custom transition's body, or a modifier transition's active modifier, is resolved over a
// placeholder once, and the opacity, scale, rotation, offset and blur it applies to the placeholder become that state.
// Other modifiers in a custom transition's body are applied at the identity phase only.
import UIKit

/// Where a view is in its transition.
public enum TransitionPhase: Hashable, Sendable {
    case willAppear, identity, didDisappear
    public var isIdentity: Bool { self == .identity }
    /// -1 before appearing, 0 while shown, 1 after disappearing.
    public var value: Double {
        switch self {
        case .willAppear: return -1
        case .identity: return 0
        case .didDisappear: return 1
        }
    }
}

/// What a transition does: whether it moves the view (Reduce Motion replaces those with a fade).
public struct TransitionProperties: Sendable {
    public var hasMotion: Bool
    public init(hasMotion: Bool = true) { self.hasMotion = hasMotion }
}

/// A transition: the view in each phase.
public protocol Transition {
    associatedtype Body: View
    typealias Content = PlaceholderContentView<Self>
    @ViewBuilder @MainActor func body(content: Content, phase: TransitionPhase) -> Body
    static var properties: TransitionProperties { get }
}

extension Transition {
    public static var properties: TransitionProperties { TransitionProperties() }
    /// The transition's body for `content` in `phase`.
    @MainActor public func apply<V: View>(content: V, phase: TransitionPhase) -> some View {
        body(content: PlaceholderContentView<Self>(make: { _resolve(content, $0) }), phase: phase)
    }
    /// The transition with its own animation.
    public func animation(_ animation: Animation?) -> some Transition { _AnimatedTransition(base: self, animation: animation) }
    /// Both transitions together.
    public func combined<T: Transition>(with other: T) -> some Transition { _CombinedTransition(first: self, second: other) }
}

/// Transitions isim plays with its own kinds (and the wrappers over them).
protocol _KindTransition {
    @MainActor func _any(_ ctx: _Context) -> AnyTransition
}

extension Transition {
    /// The transition as isim plays it: a built-in kind, or the states read off its body.
    @MainActor func _anyTransition(_ ctx: _Context) -> AnyTransition {
        if let k = self as? _KindTransition { return k._any(ctx) }
        let appear = _transitionEffect(body(content: _probeContent(), phase: .willAppear), ctx)
        let disappear = _transitionEffect(body(content: _probeContent(), phase: .didDisappear), ctx)
        return AnyTransition(.asymmetric(.effect(appear), .effect(disappear)))
    }
    @MainActor func _probeContent() -> PlaceholderContentView<Self> { PlaceholderContentView(make: { _TransitionProbeNode(path: $0.path, children: []) }) }
}

struct _AnimatedTransition<Base: Transition>: Transition, _KindTransition {
    let base: Base, animation: Animation?
    func body(content: Content, phase: TransitionPhase) -> some View { base.apply(content: content, phase: phase) }
    func _any(_ ctx: _Context) -> AnyTransition { base._anyTransition(ctx).animation(animation) }
}
struct _CombinedTransition<A: Transition, B: Transition>: Transition, _KindTransition {
    let first: A, second: B
    func body(content: Content, phase: TransitionPhase) -> some View { second.apply(content: first.apply(content: content, phase: phase), phase: phase) }
    func _any(_ ctx: _Context) -> AnyTransition { first._anyTransition(ctx).combined(with: second._anyTransition(ctx)) }
}

// MARK: - Built-in transitions

public struct IdentityTransition: Transition, _KindTransition {
    public init() {}
    public func body(content: Content, phase: TransitionPhase) -> some View { content }
    public static var properties: TransitionProperties { TransitionProperties(hasMotion: false) }
    func _any(_ ctx: _Context) -> AnyTransition { .identity }
}
public struct OpacityTransition: Transition, _KindTransition {
    public init() {}
    public func body(content: Content, phase: TransitionPhase) -> some View { content.opacity(phase.isIdentity ? 1 : 0) }
    public static var properties: TransitionProperties { TransitionProperties(hasMotion: false) }
    func _any(_ ctx: _Context) -> AnyTransition { .opacity }
}
public struct ScaleTransition: Transition, _KindTransition {
    public var scale: Double
    public var anchor: UnitPoint
    public init(_ scale: Double, anchor: UnitPoint = .center) { self.scale = scale; self.anchor = anchor }
    public func body(content: Content, phase: TransitionPhase) -> some View { content.scaleEffect(phase.isIdentity ? 1 : scale, anchor: anchor) }
    func _any(_ ctx: _Context) -> AnyTransition { .scale(scale: scale, anchor: anchor) }
}
public struct MoveTransition: Transition, _KindTransition {
    public var edge: Edge
    public init(edge: Edge) { self.edge = edge }
    public func body(content: Content, phase: TransitionPhase) -> some View { content }       // (moved by its container's size: _any)
    func _any(_ ctx: _Context) -> AnyTransition { .move(edge: edge) }
}
public struct OffsetTransition: Transition, _KindTransition {
    public var offset: CGSize
    public init(_ offset: CGSize) { self.offset = offset }
    public func body(content: Content, phase: TransitionPhase) -> some View { content.offset(phase.isIdentity ? .zero : offset) }
    func _any(_ ctx: _Context) -> AnyTransition { .offset(offset) }
}
public struct PushTransition: Transition, _KindTransition {
    public var edge: Edge
    public init(edge: Edge) { self.edge = edge }
    public func body(content: Content, phase: TransitionPhase) -> some View { content.opacity(phase.isIdentity ? 1 : 0) }
    func _any(_ ctx: _Context) -> AnyTransition { .push(from: edge) }
}
public struct SlideTransition: Transition, _KindTransition {
    public init() {}
    public func body(content: Content, phase: TransitionPhase) -> some View { content }
    func _any(_ ctx: _Context) -> AnyTransition { .slide }
}
public struct AsymmetricTransition<Insertion: Transition, Removal: Transition>: Transition, _KindTransition {
    public var insertion: Insertion
    public var removal: Removal
    public init(insertion: Insertion, removal: Removal) { self.insertion = insertion; self.removal = removal }
    public func body(content: Content, phase: TransitionPhase) -> some View {
        Group {
            if phase == .didDisappear { removal.apply(content: content, phase: phase) } else { insertion.apply(content: content, phase: phase) }
        }
    }
    func _any(_ ctx: _Context) -> AnyTransition { .asymmetric(insertion: insertion._anyTransition(ctx), removal: removal._anyTransition(ctx)) }
}

/// Blurs, scales and fades the view in and out.
public struct BlurReplaceTransition: Transition, _KindTransition {
    /// How the view scales: down as it leaves and up as it arrives (`downUp`), or up both times (`upUp`).
    public struct Configuration: Equatable, Sendable {
        let removalScale: Double
        public static let downUp = Configuration(removalScale: 0.8)
        public static let upUp = Configuration(removalScale: 1.2)
    }
    public var configuration: Configuration
    public init(configuration: Configuration) { self.configuration = configuration }
    static let blur = 10.0, insertionScale = 0.8
    public func body(content: Content, phase: TransitionPhase) -> some View {
        let s = phase == .identity ? 1 : phase == .willAppear ? Self.insertionScale : configuration.removalScale
        return content.blur(radius: phase.isIdentity ? 0 : Self.blur).scaleEffect(s).opacity(phase.isIdentity ? 1 : 0)
    }
    func _any(_ ctx: _Context) -> AnyTransition {
        var appear = _TransitionEffect(), disappear = _TransitionEffect()
        appear.alpha = 0; appear.blur = Self.blur; appear.scale = CGSize(width: Self.insertionScale, height: Self.insertionScale)
        disappear.alpha = 0; disappear.blur = Self.blur; disappear.scale = CGSize(width: configuration.removalScale, height: configuration.removalScale)
        return AnyTransition(.asymmetric(.effect(appear), .effect(disappear)))
    }
}

extension Transition where Self == IdentityTransition { public static var identity: IdentityTransition { IdentityTransition() } }
extension Transition where Self == OpacityTransition { public static var opacity: OpacityTransition { OpacityTransition() } }
extension Transition where Self == ScaleTransition {
    public static var scale: ScaleTransition { ScaleTransition(0) }
    public static func scale(_ scale: Double, anchor: UnitPoint = .center) -> ScaleTransition { ScaleTransition(scale, anchor: anchor) }
}
extension Transition where Self == MoveTransition { public static func move(edge: Edge) -> MoveTransition { MoveTransition(edge: edge) } }
extension Transition where Self == OffsetTransition {
    public static func offset(_ offset: CGSize) -> OffsetTransition { OffsetTransition(offset) }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetTransition { OffsetTransition(CGSize(width: x, height: y)) }
}
extension Transition where Self == PushTransition { public static func push(from edge: Edge) -> PushTransition { PushTransition(edge: edge) } }
extension Transition where Self == SlideTransition { public static var slide: SlideTransition { SlideTransition() } }
extension Transition where Self == BlurReplaceTransition {
    public static var blurReplace: BlurReplaceTransition { BlurReplaceTransition(configuration: .downUp) }
    public static func blurReplace(_ configuration: BlurReplaceTransition.Configuration = .downUp) -> BlurReplaceTransition {
        BlurReplaceTransition(configuration: configuration)
    }
}
extension Transition {
    public static func asymmetric<I: Transition, R: Transition>(insertion: I, removal: R) -> Self where Self == AsymmetricTransition<I, R> {
        AsymmetricTransition(insertion: insertion, removal: removal)
    }
}

// MARK: - AnyTransition over transitions and modifiers

/// A view's "not present" state, read off a transition's body.
struct _TransitionEffect: Sendable {
    var alpha = 1.0
    var scale = CGSize(width: 1, height: 1), scaleAnchor = UnitPoint.center
    var rotation = 0.0, rotationAnchor = UnitPoint.center
    var offset = CGSize.zero
    var blur = 0.0
}

/// A transition resolved when its view is: a custom Transition or a modifier pair.
final class _LazyTransition: @unchecked Sendable {
    let resolve: @MainActor (_Context) -> AnyTransition
    init(_ resolve: @escaping @MainActor (_Context) -> AnyTransition) { self.resolve = resolve }
}

/// The placeholder a transition's body wraps.
final class _TransitionProbeNode: _Node {}

/// The opacity, scale, rotation, offset and blur `view` applies to the placeholder inside it.
@MainActor func _transitionEffect(_ view: some View, _ ctx: _Context) -> _TransitionEffect {
    let n = _resolve(view, ctx.child("trprobe"))
    return _probeEffect(n) ?? _TransitionEffect()
}
@MainActor private func _probeEffect(_ n: _Node) -> _TransitionEffect? {
    if n is _TransitionProbeNode { return _TransitionEffect() }
    for c in n.children {
        guard var e = _probeEffect(c) else { continue }
        if let p = n as? _ViewPropsNode { e.alpha *= p.hidden ? 0 : Double(p.alpha) }
        if let x = n as? _EffectNode {
            if x.scale != CGSize(width: 1, height: 1) { e.scale.width *= x.scale.width; e.scale.height *= x.scale.height; e.scaleAnchor = x.scaleAnchor }
            if x.rotation != 0 { e.rotation += x.rotation; e.rotationAnchor = x.rotationAnchor }
        }
        if let o = n as? _OffsetNode { e.offset.width += o.dx; e.offset.height += o.dy }
        if let v = n as? _VFXNode, let s = v.spec, s.count > 20 { e.blur += s[20] }
        return e
    }
    return nil
}

extension AnyTransition {
    /// A transition of a Transition type.
    public init<T: Transition>(_ transition: T) {
        if let k = transition as? _ReadyKind { self = k.ready; return }
        self.init(.lazy(_LazyTransition { transition._anyTransition($0) }))
    }
    /// A transition from `active` (the view not present) to `identity`.
    public static func modifier<E: ViewModifier>(active: E, identity: E) -> AnyTransition {
        AnyTransition(.lazy(_LazyTransition { ctx in
            let probe = PlaceholderContentView<Void>(make: { _TransitionProbeNode(path: $0.path, children: []) })
            var a = _transitionEffect(probe.modifier(active), ctx)
            let i = _transitionEffect(probe.modifier(identity), ctx)
            // (relative to the identity state, which the view keeps)
            a.alpha = i.alpha > 0 ? a.alpha / i.alpha : a.alpha
            a.offset.width -= i.offset.width; a.offset.height -= i.offset.height
            a.rotation -= i.rotation; a.blur = max(0, a.blur - i.blur)
            if i.scale.width != 0 && i.scale.height != 0 { a.scale = CGSize(width: a.scale.width / i.scale.width, height: a.scale.height / i.scale.height) }
            return AnyTransition(.effect(a))
        }))
    }
    /// The transition with its custom parts resolved for the view at `ctx`.
    @MainActor func _resolved(_ ctx: _Context) -> AnyTransition {
        var lazyAnimation: Animation?
        func r(_ k: Kind) -> Kind {
            switch k {
            case .lazy(let l):
                let t = l.resolve(ctx)
                if lazyAnimation == nil { lazyAnimation = t.animation }
                return r(t.kind)
            case .combined(let a, let b): return .combined(r(a), r(b))
            case .asymmetric(let a, let b): return .asymmetric(r(a), r(b))
            default: return k
            }
        }
        let k = r(kind)
        return AnyTransition(k, animation: animation ?? lazyAnimation)
    }
}

/// Built-in transitions that need no view to resolve.
protocol _ReadyKind { var ready: AnyTransition { get } }
extension IdentityTransition: _ReadyKind { var ready: AnyTransition { .identity } }
extension OpacityTransition: _ReadyKind { var ready: AnyTransition { .opacity } }
extension ScaleTransition: _ReadyKind { var ready: AnyTransition { .scale(scale: scale, anchor: anchor) } }
extension MoveTransition: _ReadyKind { var ready: AnyTransition { .move(edge: edge) } }
extension OffsetTransition: _ReadyKind { var ready: AnyTransition { .offset(offset) } }
extension PushTransition: _ReadyKind { var ready: AnyTransition { .push(from: edge) } }
extension SlideTransition: _ReadyKind { var ready: AnyTransition { .slide } }

extension View {
    /// Inserts and removes the view with a Transition.
    public func transition<T: Transition>(_ t: T) -> some View {
        _modify { ctx, c in
            let any = t._anyTransition(ctx.child("trt"))
            // a custom transition's body applies at the identity phase (its other modifiers stay on the view)
            let content: any View = t is _KindTransition ? c : t.apply(content: c, phase: .identity)
            return _TransitionNode(path: ctx.path, transition: any, child: _resolve(content, ctx.child("tr")))
        }
    }
}

// MARK: - Blur over a transition

/// Animates a view's blur from `from` to `to` over `duration` (UIKit does not animate isim's visual effects).
@MainActor func _animateTransitionBlur(_ v: UIView, from: Double, to: Double, duration: Double) {
    let spec = { (r: Double) -> [Double]? in r <= 0.01 ? nil : _vfxSpec([_VFXOp(.blur, [r])]) }
    _setVFX(v, spec(from))
    guard duration > 0 else { _setVFX(v, spec(to)); return }
    let start = CACurrentMediaTime()
    Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { timer in
        MainActor.assumeIsolated {
            let x = min(1, (CACurrentMediaTime() - start) / duration)
            let e = Animation._bezier(0.42, 0, 0.58, 1, x)
            _setVFX(v, spec(from + (to - from) * e))
            if x >= 1 { timer.invalidate() }
        }
    }
}
