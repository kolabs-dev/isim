// isim UIKit overlay, input part (self-authored): Swift-only API shapes from Apple's UIKit overlay for pointers.

// MARK: - Pointer effects and shapes (enums in Swift, classes in Objective-C)
public enum UIPointerEffect {
    public typealias TintMode = __UIPointerEffectTintMode
    case automatic(UITargetedPreview)
    case highlight(UITargetedPreview)
    case lift(UITargetedPreview)
    case hover(UITargetedPreview, preferredTintMode: TintMode = .overlay, prefersShadow: Bool = false, prefersScaledContent: Bool = true)
    public var preview: UITargetedPreview {
        switch self { case .automatic(let p), .highlight(let p), .lift(let p), .hover(let p, _, _, _): return p }
    }
    var _objc: __UIPointerEffect {
        switch self {
        case .automatic(let p), .highlight(let p): return __UIPointerHighlightEffect(preview: p)
        case .lift(let p): return __UIPointerLiftEffect(preview: p)
        case .hover(let p, let tint, let shadow, let scaled):
            let e = __UIPointerHoverEffect(preview: p)
            e.preferredTintMode = tint; e.prefersShadow = shadow; e.prefersScaledContent = scaled
            return e
        }
    }
}
public enum UIPointerShape {
    public static let defaultCornerRadius: CGFloat = 8
    case path(UIBezierPath)
    case roundedRect(CGRect, radius: CGFloat = UIPointerShape.defaultCornerRadius)
    case verticalBeam(length: CGFloat)
    case horizontalBeam(length: CGFloat)
    var _objc: __UIPointerShape {
        switch self {
        case .path(let p): return __UIPointerShape(path: p)
        case .roundedRect(let r, let radius): return __UIPointerShape(roundedRect: r, cornerRadius: radius)
        case .verticalBeam(let l): return __UIPointerShape.beam(withPreferredLength: l, axis: .vertical)
        case .horizontalBeam(let l): return __UIPointerShape.beam(withPreferredLength: l, axis: .horizontal)
        }
    }
}
extension UIPointerStyle {
    public convenience init(effect: UIPointerEffect, shape: UIPointerShape? = nil) { self.init(__effect: effect._objc, shape: shape?._objc) }
    public convenience init(shape: UIPointerShape, constrainedAxes axes: UIAxis = []) { self.init(__shape: shape._objc, constrainedAxes: axes) }
}
