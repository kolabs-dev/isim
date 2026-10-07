// isim Symbols (self-authored): the Swift API of Apple's Symbols framework, the symbol effects that UIKit
// (`UIImageView.addSymbolEffect`) plays. isim draws its own stand-in symbols, so the effects are adapted: they
// animate the whole image (scale, offset, rotation, opacity) instead of individual symbol layers; `byLayer`,
// `wholeSymbol` and the variable-colour layer modes are accepted and only change the timing.
// Each effect describes itself through `_isimDescription`, which UIKit reads.

/// What an effect does, for the player in isim's UIKit overlay (not Apple API).
public struct _IsimSymbolEffectDescription: Hashable, Sendable {
    public enum Kind: Int, Sendable { case appear, disappear, bounce, pulse, variableColor, scale, replace, automatic, wiggle, breathe, rotate, drawOn, drawOff }
    public var kind: Kind
    /// up = 1, down = -1, none = 0 (bounce, scale, appear/disappear, replace)
    public var direction: Int = 0
    /// wiggle / rotate angle in degrees (sign = direction), wiggle offset axis: 0 rotation, 1 horizontal, 2 vertical, 3 depth
    public var angle: Double = 0
    public var axis: Int = 0
    public var byLayer: Bool = false
    /// variable colour: iterative / reversing; breathe: pulse
    public var flags: Int = 0
    public init(kind: Kind) { self.kind = kind }
}

public protocol SymbolEffect: Hashable, Sendable {
    var _isimDescription: _IsimSymbolEffectDescription { get }
}
public protocol DiscreteSymbolEffect: SymbolEffect {}
public protocol IndefiniteSymbolEffect: SymbolEffect {}
public protocol TransitionSymbolEffect: SymbolEffect {}
public protocol ContentTransitionSymbolEffect: SymbolEffect {}

// MARK: - options

public struct SymbolEffectOptions: Hashable, Sendable {
    /// nil: the effect's own default (discrete: once, indefinite: forever)
    public var _isimRepeatCount: Int?
    public var _isimRepeatDelay: Double = 0
    public var _isimSpeed: Double = 1
    public init() {}

    public static var `default`: SymbolEffectOptions { SymbolEffectOptions() }
    public static var repeating: SymbolEffectOptions { SymbolEffectOptions().repeating }
    public static var nonRepeating: SymbolEffectOptions { SymbolEffectOptions().nonRepeating }
    public static func `repeat`(_ count: Int) -> SymbolEffectOptions { SymbolEffectOptions().repeat(count) }
    public static func speed(_ speed: Double) -> SymbolEffectOptions { SymbolEffectOptions().speed(speed) }
    @available(iOS 18.0, *)
    public static func `repeat`(_ behavior: RepeatBehavior) -> SymbolEffectOptions { SymbolEffectOptions().repeat(behavior) }

    public var repeating: SymbolEffectOptions { var o = self; o._isimRepeatCount = Int.max; return o }
    public var nonRepeating: SymbolEffectOptions { var o = self; o._isimRepeatCount = 1; return o }
    public func `repeat`(_ count: Int) -> SymbolEffectOptions { var o = self; o._isimRepeatCount = max(1, count); return o }
    public func speed(_ speed: Double) -> SymbolEffectOptions { var o = self; o._isimSpeed = speed > 0 ? speed : 1; return o }
    @available(iOS 18.0, *)
    public func `repeat`(_ behavior: RepeatBehavior) -> SymbolEffectOptions {
        var o = self; o._isimRepeatCount = behavior.count ?? Int.max; o._isimRepeatDelay = behavior.delay ?? 0; return o
    }

    @available(iOS 18.0, *)
    public struct RepeatBehavior: Hashable, Sendable {
        var count: Int?, delay: Double?
        public static var periodic: RepeatBehavior { RepeatBehavior(count: nil, delay: 0) }
        public static func periodic(_ count: Int? = nil, delay: Double? = nil) -> RepeatBehavior { RepeatBehavior(count: count, delay: delay) }
        public static func periodic(delay: Double?) -> RepeatBehavior { RepeatBehavior(count: nil, delay: delay) }
        public static var continuous: RepeatBehavior { RepeatBehavior(count: nil, delay: 0) }
    }
}

// MARK: - effects

public struct AppearSymbolEffect: TransitionSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .appear)
    public init() {}
    public var up: AppearSymbolEffect { var e = self; e._isimDescription.direction = 1; return e }
    public var down: AppearSymbolEffect { var e = self; e._isimDescription.direction = -1; return e }
    public var byLayer: AppearSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: AppearSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
public struct DisappearSymbolEffect: TransitionSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .disappear)
    public init() {}
    public var up: DisappearSymbolEffect { var e = self; e._isimDescription.direction = 1; return e }
    public var down: DisappearSymbolEffect { var e = self; e._isimDescription.direction = -1; return e }
    public var byLayer: DisappearSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: DisappearSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
public struct BounceSymbolEffect: DiscreteSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .bounce)
    public init() {}
    public var up: BounceSymbolEffect { var e = self; e._isimDescription.direction = 1; return e }
    public var down: BounceSymbolEffect { var e = self; e._isimDescription.direction = -1; return e }
    public var byLayer: BounceSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: BounceSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
public struct PulseSymbolEffect: DiscreteSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .pulse)
    public init() {}
    public var byLayer: PulseSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: PulseSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
public struct VariableColorSymbolEffect: DiscreteSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .variableColor)
    public init() {}
    public var iterative: VariableColorSymbolEffect { var e = self; e._isimDescription.flags |= 1; return e }
    public var cumulative: VariableColorSymbolEffect { var e = self; e._isimDescription.flags &= ~1; return e }
    public var reversing: VariableColorSymbolEffect { var e = self; e._isimDescription.flags |= 2; return e }
    public var nonReversing: VariableColorSymbolEffect { var e = self; e._isimDescription.flags &= ~2; return e }
    public var hideInactiveLayers: VariableColorSymbolEffect { var e = self; e._isimDescription.flags |= 4; return e }
    public var dimInactiveLayers: VariableColorSymbolEffect { var e = self; e._isimDescription.flags &= ~4; return e }
}
public struct ScaleSymbolEffect: IndefiniteSymbolEffect {
    public var _isimDescription = { var d = _IsimSymbolEffectDescription(kind: .scale); d.direction = 1; return d }()
    public init() {}
    public var up: ScaleSymbolEffect { var e = self; e._isimDescription.direction = 1; return e }
    public var down: ScaleSymbolEffect { var e = self; e._isimDescription.direction = -1; return e }
    public var byLayer: ScaleSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: ScaleSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
public struct ReplaceSymbolEffect: ContentTransitionSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .replace)
    public init() {}
    public var downUp: ReplaceSymbolEffect { var e = self; e._isimDescription.direction = -1; return e }
    public var upUp: ReplaceSymbolEffect { var e = self; e._isimDescription.direction = 1; return e }
    public var offUp: ReplaceSymbolEffect { var e = self; e._isimDescription.direction = 0; return e }
    public var byLayer: ReplaceSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: ReplaceSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
public struct AutomaticSymbolEffect: ContentTransitionSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .automatic)
    public init() {}
}
@available(iOS 18.0, *)
public struct WiggleSymbolEffect: DiscreteSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = { var d = _IsimSymbolEffectDescription(kind: .wiggle); d.angle = 1; return d }()
    public init() {}
    private func with(axis: Int, angle: Double) -> WiggleSymbolEffect { var e = self; e._isimDescription.axis = axis; e._isimDescription.angle = angle; return e }
    public var left: WiggleSymbolEffect { with(axis: 1, angle: -1) }
    public var right: WiggleSymbolEffect { with(axis: 1, angle: 1) }
    public var up: WiggleSymbolEffect { with(axis: 2, angle: -1) }
    public var down: WiggleSymbolEffect { with(axis: 2, angle: 1) }
    public var forward: WiggleSymbolEffect { with(axis: 3, angle: 1) }
    public var backward: WiggleSymbolEffect { with(axis: 3, angle: -1) }
    public var clockwise: WiggleSymbolEffect { with(axis: 0, angle: 1) }
    public var counterClockwise: WiggleSymbolEffect { with(axis: 0, angle: -1) }
    public func custom(angle: Double) -> WiggleSymbolEffect { with(axis: 0, angle: angle == 0 ? 1 : angle) }
    public var byLayer: WiggleSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: WiggleSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
@available(iOS 18.0, *)
public struct BreatheSymbolEffect: DiscreteSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .breathe)
    public init() {}
    public var plain: BreatheSymbolEffect { var e = self; e._isimDescription.flags = 0; return e }
    public var pulse: BreatheSymbolEffect { var e = self; e._isimDescription.flags = 1; return e }
    public var byLayer: BreatheSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: BreatheSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
@available(iOS 18.0, *)
public struct RotateSymbolEffect: DiscreteSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = { var d = _IsimSymbolEffectDescription(kind: .rotate); d.angle = 1; return d }()
    public init() {}
    public var clockwise: RotateSymbolEffect { var e = self; e._isimDescription.angle = 1; return e }
    public var counterClockwise: RotateSymbolEffect { var e = self; e._isimDescription.angle = -1; return e }
    public var byLayer: RotateSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: RotateSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
}
@available(iOS 26.0, *)
public struct DrawOnSymbolEffect: TransitionSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .drawOn)
    public init() {}
    public var byLayer: DrawOnSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: DrawOnSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
    public var individually: DrawOnSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
}
@available(iOS 26.0, *)
public struct DrawOffSymbolEffect: TransitionSymbolEffect, IndefiniteSymbolEffect {
    public var _isimDescription = _IsimSymbolEffectDescription(kind: .drawOff)
    public init() {}
    public var byLayer: DrawOffSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var wholeSymbol: DrawOffSymbolEffect { var e = self; e._isimDescription.byLayer = false; return e }
    public var individually: DrawOffSymbolEffect { var e = self; e._isimDescription.byLayer = true; return e }
    public var reversed: DrawOffSymbolEffect { var e = self; e._isimDescription.flags = 1; return e }
    public var nonReversed: DrawOffSymbolEffect { var e = self; e._isimDescription.flags = 0; return e }
}

// MARK: - the static spellings (`.bounce`, `.pulse.byLayer`, …)

extension SymbolEffect where Self == AppearSymbolEffect { public static var appear: AppearSymbolEffect { AppearSymbolEffect() } }
extension SymbolEffect where Self == DisappearSymbolEffect { public static var disappear: DisappearSymbolEffect { DisappearSymbolEffect() } }
extension SymbolEffect where Self == BounceSymbolEffect { public static var bounce: BounceSymbolEffect { BounceSymbolEffect() } }
extension SymbolEffect where Self == PulseSymbolEffect { public static var pulse: PulseSymbolEffect { PulseSymbolEffect() } }
extension SymbolEffect where Self == VariableColorSymbolEffect { public static var variableColor: VariableColorSymbolEffect { VariableColorSymbolEffect() } }
extension SymbolEffect where Self == ScaleSymbolEffect { public static var scale: ScaleSymbolEffect { ScaleSymbolEffect() } }
extension SymbolEffect where Self == ReplaceSymbolEffect { public static var replace: ReplaceSymbolEffect { ReplaceSymbolEffect() } }
extension SymbolEffect where Self == AutomaticSymbolEffect { public static var automatic: AutomaticSymbolEffect { AutomaticSymbolEffect() } }
@available(iOS 18.0, *)
extension SymbolEffect where Self == WiggleSymbolEffect { public static var wiggle: WiggleSymbolEffect { WiggleSymbolEffect() } }
@available(iOS 18.0, *)
extension SymbolEffect where Self == BreatheSymbolEffect { public static var breathe: BreatheSymbolEffect { BreatheSymbolEffect() } }
@available(iOS 18.0, *)
extension SymbolEffect where Self == RotateSymbolEffect { public static var rotate: RotateSymbolEffect { RotateSymbolEffect() } }
@available(iOS 26.0, *)
extension SymbolEffect where Self == DrawOnSymbolEffect { public static var drawOn: DrawOnSymbolEffect { DrawOnSymbolEffect() } }
@available(iOS 26.0, *)
extension SymbolEffect where Self == DrawOffSymbolEffect { public static var drawOff: DrawOffSymbolEffect { DrawOffSymbolEffect() } }
