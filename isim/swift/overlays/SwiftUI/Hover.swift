// isim SwiftUI: pointer hover — `onHover`, `onContinuousHover` (UIHoverGestureRecognizer: the iPad pointer or the host
// mouse without a button; script `hover X Y`) and `hoverEffect` (iPad pointer effects: UIPointerInteraction's
// highlight / lift, `.automatic` choosing like UIKit).
import UIKit

/// Where the pointer is over a view.
@frozen public enum HoverPhase: Equatable, Sendable {
    case active(CGPoint)
    case ended
}

nonisolated(unsafe) private var kHover: UInt8 = 0, kPointer: UInt8 = 0

/// The hover recognizer on a view and the latest handler.
final class _SUIHover: NSObject {
    var handler: (UIHoverGestureRecognizer) -> Void = { _ in }
    @objc func hovered(_ g: UIHoverGestureRecognizer) { handler(g) }
}
@MainActor func _installHover(_ v: UIView, _ handler: @escaping (UIHoverGestureRecognizer) -> Void) {
    if let h = objc_getAssociatedObject(v, &kHover) as? _SUIHover { h.handler = handler; return }
    let h = _SUIHover()
    h.handler = handler
    objc_setAssociatedObject(v, &kHover, h, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    let g = UIHoverGestureRecognizer(target: h, action: #selector(_SUIHover.hovered(_:)))
    v.addGestureRecognizer(g)
    v.isUserInteractionEnabled = true
}

/// iPad pointer effects for a view.
public struct HoverEffect: Sendable, Equatable {
    let kind: Int                          // 0 automatic, 1 highlight, 2 lift
    public static let automatic = HoverEffect(kind: 0)
    public static let highlight = HoverEffect(kind: 1)
    public static let lift = HoverEffect(kind: 2)
}
final class _SUIPointerEffects: NSObject, UIPointerInteractionDelegate {
    var effect = HoverEffect.automatic, enabled = true
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        guard enabled, let v = interaction.view else { return nil }
        let preview = UITargetedPreview(view: v)
        // automatic: small views highlight, large ones lift (like UIKit's)
        let lift = effect == .lift || (effect == .automatic && v.bounds.width * v.bounds.height > 120 * 120)
        return UIPointerStyle(effect: lift ? .lift(preview) : .highlight(preview))
    }
}
struct _HoverEffectDisabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues {
    var _hoverEffectDisabled: Bool { get { self[_HoverEffectDisabledKey.self] } set { self[_HoverEffectDisabledKey.self] = newValue } }
}

extension View {
    /// `action(true)` when the pointer enters the view, `action(false)` when it leaves.
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        _accessibility(deepest: false) { v in
            _installHover(v) { g in
                switch g.state {
                case .began: action(true)
                case .ended, .cancelled, .failed: action(false)
                default: break
                }
            }
        }
    }
    /// The pointer's location over the view (in `coordinateSpace`) while it moves, then `.ended` (iOS 17 form).
    public func onContinuousHover(coordinateSpace: some CoordinateSpaceProtocol = .local, perform action: @escaping (HoverPhase) -> Void) -> some View {
        onContinuousHover(coordinateSpace: coordinateSpace.coordinateSpace, perform: action)
    }
    /// The pointer's location over the view (in `coordinateSpace`) while it moves, then `.ended`.
    @_disfavoredOverload
    public func onContinuousHover(coordinateSpace: CoordinateSpace = .local, perform action: @escaping (HoverPhase) -> Void) -> some View {
        _accessibility(deepest: false) { v in
            _installHover(v) { g in
                switch g.state {
                case .began, .changed: action(.active(_livePoint(g.location(in: v), in: v, coordinateSpace)))
                case .ended, .cancelled, .failed: action(.ended)
                default: break
                }
            }
        }
    }
    /// The iPad pointer's effect over this view.
    public func hoverEffect(_ effect: HoverEffect = .automatic, isEnabled: Bool = true) -> some View {
        _modify { ctx, c in
            let disabled = ctx.environment._hoverEffectDisabled
            let n = _resolve(c, ctx.child("hover"))
            n.accessibilityApply.append { v in
                let d: _SUIPointerEffects
                if let old = objc_getAssociatedObject(v, &kPointer) as? _SUIPointerEffects { d = old }
                else {
                    d = _SUIPointerEffects()
                    objc_setAssociatedObject(v, &kPointer, d, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
                    v.addInteraction(UIPointerInteraction(delegate: d))
                }
                d.effect = effect; d.enabled = isEnabled && !disabled
            }
            return n
        }
    }
    /// Turns off the hover effects of this view and the views inside it.
    public func hoverEffectDisabled(_ disabled: Bool = true) -> some View { environment(\._hoverEffectDisabled, disabled) }
}
