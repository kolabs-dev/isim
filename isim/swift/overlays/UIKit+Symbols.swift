// isim UIKit overlay: symbol effects on image views (iOS 17; wiggle / breathe / rotate iOS 18; draw on / off iOS 26).
// Adapted: isim's symbols are stand-in drawings without layers, so an effect animates the whole image view
// (scale, offset, rotation, opacity) on top of its own transform and alpha, frame by frame from a display link.
// Indefinite effects run (or hold their state: scale, disappear) until removed; discrete ones run once (or the
// options' repeat count) and call their completion.
import Symbols   // not re-exported: SwiftUI (which re-exports UIKit) has its own symbol effect types; name Symbols types with `import Symbols`

@available(iOS 17.0, *)
public struct UISymbolEffectCompletionContext {
    public let isFinished: Bool
    public weak var sender: AnyObject?
    public let effect: (any SymbolEffect)?
    public let contentTransition: (any ContentTransitionSymbolEffect)?
}
@available(iOS 17.0, *)
public typealias UISymbolEffectCompletion = (UISymbolEffectCompletionContext) -> Void

private var isimSymbolPlayerKey: UInt8 = 0

final class _IsimSymbolEffectPlayer: NSObject {
    struct Running {
        var effect: any SymbolEffect
        var d: _IsimSymbolEffectDescription
        var start: Double
        var count: Int                // cycles to run (Int.max: until removed)
        var delay: Double             // pause between cycles
        var speed: Double
        var holds: Bool               // a state effect (scale, disappear, draw off): eases in, holds, eases out
        var removingAt: Double?       // a holding effect being removed
        var completion: ((Bool) -> Void)?
    }
    weak var view: UIView?
    var running: [Running] = []
    var baseTransform = CGAffineTransform.identity, baseAlpha: CGFloat = 1
    var link: CADisplayLink?
    var replaceStart: Double?, replaceImage: UIImage?, replaceDone: ((Bool) -> Void)?, replaceDir = 0

    init(view: UIView) { self.view = view }

    static func player(for v: UIView) -> _IsimSymbolEffectPlayer {
        if let p = objc_getAssociatedObject(v, &isimSymbolPlayerKey) as? _IsimSymbolEffectPlayer { return p }
        let p = _IsimSymbolEffectPlayer(view: v)
        objc_setAssociatedObject(v, &isimSymbolPlayerKey, p, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
        return p
    }
    static func now() -> Double { CACurrentMediaTime() }

    /// one cycle's length in seconds at speed 1
    static func period(_ k: _IsimSymbolEffectDescription.Kind) -> Double {
        switch k {
        case .bounce: return 0.5
        case .pulse: return 1.0
        case .variableColor: return 1.2
        case .wiggle: return 0.8
        case .breathe: return 1.6
        case .rotate: return 1.0
        default: return 0.3
        }
    }

    var active: Bool { !running.isEmpty || replaceStart != nil }

    func begin() {
        guard let v = view else { return }
        if !active { baseTransform = v.transform; baseAlpha = v.alpha }
    }
    func startLink() {
        if link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
            l.add(to: RunLoop.main, forMode: RunLoop.Mode.common.rawValue)
            link = l
        }
        tick(nil)
    }

    func add(_ effect: any SymbolEffect, options: SymbolEffectOptions, indefinite: Bool, animated: Bool, completion: ((Bool) -> Void)?) {
        let d = effect._isimDescription
        begin()
        // appearing undoes a disappearance (and the other way round): the opposite state effect eases out
        let opposite: [_IsimSymbolEffectDescription.Kind] = (d.kind == .appear || d.kind == .drawOn) ? [.disappear, .drawOff] : (d.kind == .disappear || d.kind == .drawOff) ? [.appear, .drawOn] : []
        if !opposite.isEmpty { remove(where: { opposite.contains($0.kind) }, animated: animated) }
        running.removeAll { $0.d.kind == d.kind && $0.holds }          // the same state effect again replaces it
        let holds = indefinite && [.scale, .disappear, .drawOff].contains(d.kind)
        let appearOnly = d.kind == .appear || d.kind == .drawOn
        var count = options._isimRepeatCount ?? (indefinite ? Int.max : 1)
        if holds || appearOnly { count = 1 }
        if !animated && !holds {                                         // nothing to show without animation
            completion?(true); if running.isEmpty { finishIfIdle() }; return
        }
        let start = animated ? Self.now() : Self.now() - 10
        running.append(Running(effect: effect, d: d, start: start, count: count, delay: options._isimRepeatDelay,
                               speed: options._isimSpeed, holds: holds, removingAt: nil, completion: completion))
        startLink()
    }

    func remove(where match: (_IsimSymbolEffectDescription) -> Bool, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        let t = Self.now()
        var easing = false, stopped: [((Bool) -> Void)?] = []
        running = running.compactMap { r in
            guard match(r.d), r.removingAt == nil else { return r }
            if r.holds && animated {                                      // eases back out, then completes
                var r = r; r.removingAt = t; easing = true
                if let c = completion { let own = r.completion; r.completion = { f in own?(f); c(f) } }
                return r
            }
            stopped.append(r.completion); return nil
        }
        if active { tick(nil) } else { finishIfIdle() }                  // back to the view's own transform first
        for c in stopped { c?(false) }                                    // the stopped effect did not finish
        if !easing { completion?(true) }
    }

    func replace(with image: UIImage?, effect: any SymbolEffect, options: SymbolEffectOptions, completion: ((Bool) -> Void)?) {
        guard let iv = view as? UIImageView else { completion?(true); return }
        begin()
        replaceDone?(false)
        replaceImage = image; replaceDone = completion; replaceDir = effect._isimDescription.direction
        replaceStart = Self.now()
        _ = options
        _ = iv
        startLink()
    }

    private static func ease(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }

    @objc func tick(_ l: CADisplayLink?) {
        guard let v = view else { link?.invalidate(); link = nil; return }
        let t = Self.now()
        var scale = 1.0, angle = 0.0, tx = 0.0, ty = 0.0, alpha = 1.0
        var finished: [((Bool) -> Void)?] = []
        var keep: [Running] = []
        for var r in running {
            let el = (t - r.start) * r.speed
            if r.holds {
                let h: Double
                if let rm = r.removingAt {
                    let back = (t - rm) * r.speed / 0.3
                    if back >= 1 { finished.append(r.completion); continue }
                    h = 1 - Self.ease(back)
                } else {
                    h = Self.ease(el / 0.3)
                    if el >= 0.3, r.d.kind != .scale, r.completion != nil { finished.append(r.completion); r.completion = nil }   // a disappearance completes once hidden
                }
                switch r.d.kind {
                case .scale: scale *= 1 + (r.d.direction < 0 ? -0.2 : 0.25) * h
                case .disappear, .drawOff:
                    alpha *= 1 - h; scale *= 1 - 0.4 * h; ty += Double(-r.d.direction) * 6 * h
                default: break
                }
                keep.append(r); continue
            }
            if r.d.kind == .appear || r.d.kind == .drawOn {               // grows in from small and transparent
                let u = el / 0.3
                if u >= 1 { finished.append(r.completion); continue }
                let h = Self.ease(u); alpha *= h; scale *= 0.6 + 0.4 * h; ty += Double(r.d.direction) * 6 * (1 - h)
                keep.append(r); continue
            }
            let P = Self.period(r.d.kind)
            let cycle = P + r.delay
            let n = Int(el / cycle)
            if r.count == 0 || (r.count != Int.max && n >= r.count) { finished.append(r.completion); continue }
            let inCycle = el - Double(n) * cycle
            if inCycle > P { keep.append(r); continue }                   // the pause between repeats
            let u = inCycle / P, s = sin(Double.pi * u)
            switch r.d.kind {
            case .bounce: scale *= r.d.direction < 0 ? 1 - 0.15 * s : 1 + 0.2 * s; ty += Double(-max(r.d.direction, 0)) * 4 * s
            case .pulse: alpha *= 1 - 0.6 * s
            case .variableColor: alpha *= 1 - (r.d.flags & 4 != 0 ? 0.8 : 0.5) * s
            case .breathe: scale *= 1 + 0.08 * s; if r.d.flags & 1 != 0 { alpha *= 1 - 0.3 * s }
            case .rotate: angle += r.d.angle * 2 * Double.pi * Self.ease(u)
            case .wiggle:
                let w = sin(4 * Double.pi * u) * (1 - u)
                switch r.d.axis {
                case 1: tx += 6 * r.d.angle * w
                case 2: ty += 6 * r.d.angle * w
                case 3: scale *= 1 + 0.08 * r.d.angle * w
                default: angle += (abs(r.d.angle) == 1 ? 15 : r.d.angle) * Double.pi / 180 * (r.d.angle < 0 && abs(r.d.angle) == 1 ? -1 : 1) * w
                }
            default: break
            }
            keep.append(r)
        }
        running = keep
        if let rs = replaceStart, let iv = v as? UIImageView {             // replace: shrink the old symbol away, grow the new one
            let u = (t - rs) / 0.4
            if u >= 1 { replaceStart = nil; if let img = replaceImage { iv.image = img }; replaceImage = nil; let d = replaceDone; replaceDone = nil; finished.append(d) }
            else if u < 0.5 { let h = Self.ease(u * 2); scale *= 1 - 0.4 * h; alpha *= 1 - h; ty += Double(replaceDir) * -4 * h }
            else {
                if let img = replaceImage { iv.image = img; replaceImage = nil }
                let h = Self.ease((u - 0.5) * 2); scale *= 0.6 + 0.4 * h; alpha *= h; ty += Double(replaceDir) * 4 * (1 - h)
            }
        }
        var m = CGAffineTransform(translationX: CGFloat(tx), y: CGFloat(ty))
        m = m.rotated(by: CGFloat(angle)).scaledBy(x: CGFloat(scale), y: CGFloat(scale))
        v.transform = baseTransform.concatenating(m)
        v.alpha = baseAlpha * CGFloat(alpha)
        finishIfIdle()
        for f in finished { f?(true) }
    }

    func finishIfIdle() {
        guard !active, let v = view else { return }
        link?.invalidate(); link = nil
        v.transform = baseTransform; v.alpha = baseAlpha
    }
}

@available(iOS 17.0, *)
extension UIImageView {
    private func _isimContext(_ finished: Bool, _ effect: (any SymbolEffect)?, _ transition: (any ContentTransitionSymbolEffect)? = nil) -> UISymbolEffectCompletionContext {
        UISymbolEffectCompletionContext(isFinished: finished, sender: self, effect: effect, contentTransition: transition)
    }
    private func _isimAdd(_ effect: any SymbolEffect, _ options: SymbolEffectOptions, indefinite: Bool, _ animated: Bool, _ completion: UISymbolEffectCompletion?) {
        let done: ((Bool) -> Void)? = completion.map { c in { [weak self] f in c(UISymbolEffectCompletionContext(isFinished: f, sender: self, effect: effect, contentTransition: nil)) } }
        _IsimSymbolEffectPlayer.player(for: self).add(effect, options: options, indefinite: indefinite, animated: animated, completion: done)
    }

    public func addSymbolEffect(_ effect: some DiscreteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimAdd(effect, options, indefinite: false, animated, completion)
    }
    public func addSymbolEffect(_ effect: some IndefiniteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimAdd(effect, options, indefinite: true, animated, completion)
    }
    public func addSymbolEffect(_ effect: some DiscreteSymbolEffect & IndefiniteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        // adapted: pulse, variable colour, breathe and rotate run until removed; bounce and wiggle (indefinite only
        // since iOS 18) play once unless the options repeat them
        let k = effect._isimDescription.kind
        _isimAdd(effect, options, indefinite: !(k == .bounce || k == .wiggle), animated, completion)
    }
    public func addSymbolEffect(_ effect: some TransitionSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimAdd(effect, options, indefinite: true, animated, completion)
    }
    public func addSymbolEffect(_ effect: some TransitionSymbolEffect & IndefiniteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimAdd(effect, options, indefinite: true, animated, completion)
    }

    private func _isimRemove(_ effect: any SymbolEffect, _ animated: Bool, _ completion: UISymbolEffectCompletion?) {
        let kind = effect._isimDescription.kind
        let done: ((Bool) -> Void)? = completion.map { c in { [weak self] f in c(UISymbolEffectCompletionContext(isFinished: f, sender: self, effect: effect, contentTransition: nil)) } }
        _IsimSymbolEffectPlayer.player(for: self).remove(where: { $0.kind == kind }, animated: animated, completion: done)
    }
    public func removeSymbolEffect(ofType effect: some IndefiniteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimRemove(effect, animated, completion)
    }
    public func removeSymbolEffect(ofType effect: some DiscreteSymbolEffect & IndefiniteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimRemove(effect, animated, completion)
    }
    public func removeSymbolEffect(ofType effect: some TransitionSymbolEffect & IndefiniteSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        _isimRemove(effect, animated, completion)
    }
    public func removeAllSymbolEffects(options: SymbolEffectOptions = .default, animated: Bool = true) {
        _IsimSymbolEffectPlayer.player(for: self).remove(where: { _ in true }, animated: animated)
    }

    public func setSymbolImage(_ image: UIImage, contentTransition: some ContentTransitionSymbolEffect & SymbolEffect, options: SymbolEffectOptions = .default, completion: UISymbolEffectCompletion? = nil) {
        let done: ((Bool) -> Void)? = completion.map { c in { [weak self] f in c(UISymbolEffectCompletionContext(isFinished: f, sender: self, effect: nil, contentTransition: contentTransition)) } }
        _IsimSymbolEffectPlayer.player(for: self).replace(with: image, effect: contentTransition, options: options, completion: done)
    }
}
