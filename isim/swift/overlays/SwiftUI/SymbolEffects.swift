// isim SwiftUI: SF Symbol effects (iOS 17; wiggle / rotate / breathe iOS 18). Adapted: the effects animate the whole
// symbol view (scale, opacity, rotation) with UIKit view animations — isim's symbols have no layers to animate
// separately, so `.byLayer`, variable colour layers and replace's directions approximate the whole-symbol motion.
import UIKit

public protocol SymbolEffect: Sendable {}
public protocol IndefiniteSymbolEffect {}
public protocol DiscreteSymbolEffect {}
public protocol TransitionSymbolEffect {}
public protocol ContentTransitionSymbolEffect {}

/// The isim description of an effect: its motion and direction.
protocol _SymbolEffectKind { var _kind: Int { get } }

public struct BounceSymbolEffect: SymbolEffect, DiscreteSymbolEffect, _SymbolEffectKind {
    var isDown = false
    var _kind: Int { isDown ? 2 : 1 }
    public var up: BounceSymbolEffect { var e = self; e.isDown = false; return e }
    public var down: BounceSymbolEffect { var e = self; e.isDown = true; return e }
    public var byLayer: BounceSymbolEffect { self }
    public var wholeSymbol: BounceSymbolEffect { self }
}
public struct PulseSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 3 }
    public var byLayer: PulseSymbolEffect { self }
    public var wholeSymbol: PulseSymbolEffect { self }
}
public struct VariableColorSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 4 }
    public var iterative: VariableColorSymbolEffect { self }
    public var cumulative: VariableColorSymbolEffect { self }
    public var reversing: VariableColorSymbolEffect { self }
    public var nonReversing: VariableColorSymbolEffect { self }
    public var hideInactiveLayers: VariableColorSymbolEffect { self }
    public var dimInactiveLayers: VariableColorSymbolEffect { self }
}
public struct ScaleSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, _SymbolEffectKind {
    var isDown = false
    var _kind: Int { isDown ? 6 : 5 }
    public var up: ScaleSymbolEffect { var e = self; e.isDown = false; return e }
    public var down: ScaleSymbolEffect { var e = self; e.isDown = true; return e }
    public var byLayer: ScaleSymbolEffect { self }
    public var wholeSymbol: ScaleSymbolEffect { self }
}
public struct AppearSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 7 }
    public var up: AppearSymbolEffect { self }
    public var down: AppearSymbolEffect { self }
    public var byLayer: AppearSymbolEffect { self }
    public var wholeSymbol: AppearSymbolEffect { self }
}
public struct DisappearSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 8 }
    public var up: DisappearSymbolEffect { self }
    public var down: DisappearSymbolEffect { self }
    public var byLayer: DisappearSymbolEffect { self }
    public var wholeSymbol: DisappearSymbolEffect { self }
}
public struct ReplaceSymbolEffect: SymbolEffect, ContentTransitionSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 9 }
    public var downUp: ReplaceSymbolEffect { self }
    public var upUp: ReplaceSymbolEffect { self }
    public var offUp: ReplaceSymbolEffect { self }
    public var byLayer: ReplaceSymbolEffect { self }
    public var wholeSymbol: ReplaceSymbolEffect { self }
}
@available(iOS 18.0, *)
public struct WiggleSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 10 }
    public var left: WiggleSymbolEffect { self }
    public var right: WiggleSymbolEffect { self }
    public var up: WiggleSymbolEffect { self }
    public var down: WiggleSymbolEffect { self }
    public var forward: WiggleSymbolEffect { self }
    public var backward: WiggleSymbolEffect { self }
    public var clockwise: WiggleSymbolEffect { self }
    public var counterClockwise: WiggleSymbolEffect { self }
    public var byLayer: WiggleSymbolEffect { self }
    public var wholeSymbol: WiggleSymbolEffect { self }
}
@available(iOS 18.0, *)
public struct RotateSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect, _SymbolEffectKind {
    var ccw = false
    var _kind: Int { ccw ? 12 : 11 }
    public var clockwise: RotateSymbolEffect { var e = self; e.ccw = false; return e }
    public var counterClockwise: RotateSymbolEffect { var e = self; e.ccw = true; return e }
    public var byLayer: RotateSymbolEffect { self }
    public var wholeSymbol: RotateSymbolEffect { self }
}
@available(iOS 18.0, *)
public struct BreatheSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect, _SymbolEffectKind {
    var _kind: Int { 13 }
    public var plain: BreatheSymbolEffect { self }
    public var pulse: BreatheSymbolEffect { self }
    public var byLayer: BreatheSymbolEffect { self }
    public var wholeSymbol: BreatheSymbolEffect { self }
}
extension SymbolEffect where Self == BounceSymbolEffect { public static var bounce: BounceSymbolEffect { .init() } }
extension SymbolEffect where Self == PulseSymbolEffect { public static var pulse: PulseSymbolEffect { .init() } }
extension SymbolEffect where Self == VariableColorSymbolEffect { public static var variableColor: VariableColorSymbolEffect { .init() } }
extension SymbolEffect where Self == ScaleSymbolEffect { public static var scale: ScaleSymbolEffect { .init() } }
extension SymbolEffect where Self == AppearSymbolEffect { public static var appear: AppearSymbolEffect { .init() } }
extension SymbolEffect where Self == DisappearSymbolEffect { public static var disappear: DisappearSymbolEffect { .init() } }
extension SymbolEffect where Self == ReplaceSymbolEffect { public static var replace: ReplaceSymbolEffect { .init() } }
@available(iOS 18.0, *)
extension SymbolEffect where Self == WiggleSymbolEffect { public static var wiggle: WiggleSymbolEffect { .init() } }
@available(iOS 18.0, *)
extension SymbolEffect where Self == RotateSymbolEffect { public static var rotate: RotateSymbolEffect { .init() } }
@available(iOS 18.0, *)
extension SymbolEffect where Self == BreatheSymbolEffect { public static var breathe: BreatheSymbolEffect { .init() } }

public struct SymbolEffectOptions: Sendable {
    var repeats: Int? = 1               // nil: forever
    var speed = 1.0
    public static var `default`: SymbolEffectOptions { SymbolEffectOptions() }
    public static var repeating: SymbolEffectOptions { SymbolEffectOptions(repeats: nil) }
    public static var nonRepeating: SymbolEffectOptions { SymbolEffectOptions(repeats: 1) }
    public static func `repeat`(_ count: Int) -> SymbolEffectOptions { SymbolEffectOptions(repeats: max(1, count)) }
    public static func speed(_ speed: Double) -> SymbolEffectOptions { SymbolEffectOptions(speed: speed) }
    public var repeating: SymbolEffectOptions { var o = self; o.repeats = nil; return o }
    public var nonRepeating: SymbolEffectOptions { var o = self; o.repeats = 1; return o }
    public func `repeat`(_ count: Int) -> SymbolEffectOptions { var o = self; o.repeats = max(1, count); return o }
    public func speed(_ speed: Double) -> SymbolEffectOptions { var o = self; o.speed = speed; return o }
}
extension ContentTransition {
    /// A symbol replaced with an effect (adapted: the new symbol scales in, the old one out).
    public static func symbolEffect<T: ContentTransitionSymbolEffect & SymbolEffect>(_ effect: T, options: SymbolEffectOptions = .default) -> ContentTransition { .symbolEffect }
}

extension View {
    /// An effect that runs while `isActive` (pulse, variable colour, scale, appear / disappear, breathe, rotate, wiggle).
    public func symbolEffect<T: IndefiniteSymbolEffect & SymbolEffect>(_ effect: T, options: SymbolEffectOptions = .default, isActive: Bool = true) -> some View {
        let kind = (effect as? _SymbolEffectKind)?._kind ?? 0
        return _modify { ctx, c in
            let n = _SymbolEffectNode(path: ctx.path, kind: kind, options: options, child: _resolve(c, ctx.child("symfx")))
            n.active = isActive && !ctx.environment._symbolEffectsRemoved
            n.indefinite = true
            return n
        }
    }
    /// An effect played once (or `options` times) whenever `value` changes (bounce, pulse, wiggle, rotate, …).
    public func symbolEffect<T: DiscreteSymbolEffect & SymbolEffect, U: Equatable>(_ effect: T, options: SymbolEffectOptions = .default, value: U) -> some View {
        let kind = (effect as? _SymbolEffectKind)?._kind ?? 0
        return _modify { ctx, c in
            let key = ctx.path + "#symfx", g = ctx.graph
            g.usedChanges.insert(key)
            let changed = (g.changeValues[key] as? U).map { $0 != value } ?? false
            g.changeValues[key] = value
            let n = _SymbolEffectNode(path: ctx.path, kind: kind, options: options, child: _resolve(c, ctx.child("symfx")))
            n.trigger = changed && !ctx.environment._symbolEffectsRemoved
            return n
        }
    }
    public func symbolEffectsRemoved(_ isEnabled: Bool = true) -> some View { _env { $0._symbolEffectsRemoved = isEnabled } }
}
struct _SymbolEffectsRemovedKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues { var _symbolEffectsRemoved: Bool { get { self[_SymbolEffectsRemovedKey.self] } set { self[_SymbolEffectsRemovedKey.self] = newValue } } }

final class _SymbolEffectNode: _WrapperNode {
    let kind: Int, options: SymbolEffectOptions
    var active = false, indefinite = false, trigger = false
    init(path: String, kind: Int, options: SymbolEffectOptions, child: _Node) { self.kind = kind; self.options = options; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUISymbolEffectView(frame: .zero) }
        let k = kind, o = options, ind = indefinite, act = active, trig = trigger
        g.postRender.append { [weak v] in v?.update(kind: k, options: o, indefinite: ind, active: act, trigger: trig) }
        return v
    }
}
/// Runs the effect on itself (the symbol's container).
final class _SUISymbolEffectView: _PassthroughViewBase {
    private var running = -1
    func update(kind: Int, options: SymbolEffectOptions, indefinite: Bool, active: Bool, trigger: Bool) {
        if indefinite {
            if active && running == kind { return }
            stop()
            if active { running = kind; play(kind, options, forever: options.repeats == nil || [3, 4, 11, 12, 13].contains(kind) && options.repeats == 1, hold: true) }
            else if kind == 8 { alpha = 1 }
        } else if trigger {
            stop(); play(kind, options, forever: options.repeats == nil, hold: false)
        }
    }
    func stop() { _isim_removeAllAnimations(); transform = .identity; alpha = kind8Hidden ? 0 : 1; running = -1 }
    private var kind8Hidden = false
    func play(_ kind: Int, _ o: SymbolEffectOptions, forever: Bool, hold: Bool) {
        let d = 0.5 / max(0.1, o.speed), n = forever ? 0 : Float(o.repeats ?? 1)
        var opts: UIView.AnimationOptions = [.allowUserInteraction]
        func rep(_ autoreverse: Bool) { if forever || n > 1 { opts.insert(.repeat) }; if autoreverse { opts.insert(.autoreverse) } }
        kind8Hidden = false
        switch kind {
        case 1, 2:                                                   // bounce up / down: a quick squash and back
            UIView.animateKeyframes(withDuration: d * 0.8, delay: 0, options: forever ? [.repeat] : [], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.4) { self.transform = kind == 1 ? CGAffineTransform(scaleX: 1.22, y: 1.22) : CGAffineTransform(scaleX: 0.8, y: 0.8) }
                UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.6) { self.transform = .identity }
            }, completion: nil)
        case 3, 4:                                                   // pulse / variable colour: opacity
            rep(true)
            UIView.animate(withDuration: kind == 3 ? d * 1.6 : d, delay: 0, options: opts, animations: { self.alpha = kind == 3 ? 0.3 : 0.5 },
                           completion: { _ in if !forever && !hold { self.alpha = 1 } })
        case 5, 6:                                                   // scale up / down while active
            UIView.animate(withDuration: d * 0.6) { self.transform = kind == 5 ? CGAffineTransform(scaleX: 1.2, y: 1.2) : CGAffineTransform(scaleX: 0.8, y: 0.8) }
        case 7:                                                      // appear
            UIView.performWithoutAnimation { alpha = 0; transform = CGAffineTransform(scaleX: 0.5, y: 0.5) }
            UIView.animate(withDuration: d * 0.6) { self.alpha = 1; self.transform = .identity }
        case 8:                                                      // disappear (stays hidden while active)
            kind8Hidden = true
            UIView.animate(withDuration: d * 0.6) { self.alpha = 0; self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5) }
        case 10:                                                     // wiggle
            UIView.animateKeyframes(withDuration: d, delay: 0, options: forever ? [.repeat] : [], animations: {
                for (i, a) in [0.2, -0.2, 0.12, 0].enumerated() {
                    UIView.addKeyframe(withRelativeStartTime: Double(i) * 0.25, relativeDuration: 0.25) { self.transform = CGAffineTransform(rotationAngle: a) }
                }
            }, completion: nil)
        case 11, 12:                                                 // rotate a full turn
            let sign: CGFloat = kind == 11 ? 1 : -1
            UIView.animateKeyframes(withDuration: d * 2, delay: 0, options: forever ? [.repeat] : [], animations: {
                for i in 1...4 { UIView.addKeyframe(withRelativeStartTime: Double(i - 1) * 0.25, relativeDuration: 0.25) { self.transform = CGAffineTransform(rotationAngle: sign * CGFloat(i) * .pi / 2) } }
            }, completion: { _ in if !forever { self.transform = .identity } })
        case 13:                                                     // breathe
            rep(true)
            UIView.animate(withDuration: d * 2, delay: 0, options: opts, animations: { self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12) }, completion: nil)
        default: break
        }
    }
}
