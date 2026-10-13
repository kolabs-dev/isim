// Hover styles (iOS 17), Swift refinements: UIShape (a value type over the Objective-C shape), UIShapeProvider, and
// the UIHoverEffect structs. See UIHoverStyle.m.
import ObjectiveC

/// a shape that resolves against the content it is used with (a view's bounds)
@available(iOS 17.0, *)
public struct UIShape: Equatable, @unchecked Sendable {
    let objc: __UIShape
    init(_ o: __UIShape) { objc = o }
    public static var rect: UIShape { UIShape(__UIShape.rect) }
    public static var capsule: UIShape { UIShape(__UIShape.capsule) }
    public static var circle: UIShape { UIShape(__UIShape.circle) }
    public static func rect(cornerRadius: CGFloat = 0, cornerCurve: UICornerCurve = .automatic, maskedCorners: UIRectCorner = .allCorners) -> UIShape {
        UIShape(__UIShape.rectShape(withCornerRadius: cornerRadius, cornerCurve: cornerCurve, maskedCorners: maskedCorners))
    }
    public static func fixedRect(_ rect: CGRect, cornerRadius: CGFloat = 0, cornerCurve: UICornerCurve = .automatic, maskedCorners: UIRectCorner = .allCorners) -> UIShape {
        UIShape(__UIShape.fixedRectShape(with: rect, cornerRadius: cornerRadius, cornerCurve: cornerCurve, maskedCorners: maskedCorners))
    }
    public static func path(_ path: UIBezierPath) -> UIShape { UIShape(__UIShape(bezierPath: path)) }
    public init(provider: some UIShapeProvider) { objc = __UIShape(provider: _IsimShapeProviderBox(provider)) }
    public func inset(by inset: CGFloat) -> UIShape { UIShape(objc.__applyingInset(inset)) }
    public func inset(by insets: UIEdgeInsets) -> UIShape { UIShape(objc.__applyingInsets(insets)) }
    public func resolve(in context: ResolutionContext) -> UIResolvedShape { objc.__isimResolved(in: context.contentShape.boundingRect) }
    public static func == (a: UIShape, b: UIShape) -> Bool { a.objc.isEqual(b.objc) }
    /// what a shape resolves against
    public struct ResolutionContext {
        public let contentShape: UIResolvedShape
        init(_ o: __UIShapeResolutionContext) { contentShape = o.contentShape }
    }
}
@available(iOS 17.0, *)
extension UIResolvedShape {
    public var shape: UIShape { UIShape(__shape) }
}
/// a custom shape: resolves itself against the content (and compares to others of its kind)
@available(iOS 17.0, *)
public protocol UIShapeProvider: Equatable {
    func resolve(in context: UIShape.ResolutionContext) -> UIResolvedShape
}
@available(iOS 17.0, *)
final class _IsimShapeProviderBox: NSObject, _UIShapeProviderObjC {
    let resolveBlock: (UIShape.ResolutionContext) -> UIResolvedShape
    let equals: (Any) -> Bool
    let value: Any
    init<P: UIShapeProvider>(_ p: P) { value = p; resolveBlock = { p.resolve(in: $0) }; equals = { ($0 as? P) == p } }
    func resolvedShape(in context: __UIShapeResolutionContext) -> UIResolvedShape { resolveBlock(UIShape.ResolutionContext(context)) }
    override func isEqual(_ object: Any?) -> Bool { (object as? _IsimShapeProviderBox).map { equals($0.value) } ?? false }
    override var hash: Int { 0 }
}

/// a hover effect: automatic, highlight or lift
@available(iOS 17.0, *)
public protocol UIHoverEffect: Sendable {}
@available(iOS 17.0, *) public struct UIHoverAutomaticEffect: UIHoverEffect, Equatable { public init() {} }
@available(iOS 17.0, *) public struct UIHoverHighlightEffect: UIHoverEffect, Equatable { public init() {} }
@available(iOS 17.0, *) public struct UIHoverLiftEffect: UIHoverEffect, Equatable { public init() {} }
@available(iOS 17.0, *) extension UIHoverEffect where Self == UIHoverAutomaticEffect { public static var automatic: Self { Self() } }
@available(iOS 17.0, *) extension UIHoverEffect where Self == UIHoverHighlightEffect { public static var highlight: Self { Self() } }
@available(iOS 17.0, *) extension UIHoverEffect where Self == UIHoverLiftEffect { public static var lift: Self { Self() } }
@available(iOS 17.0, *)
func _isimHoverEffectObjC(_ e: any UIHoverEffect) -> any _UIHoverEffectObjC {
    switch e {
    case is UIHoverHighlightEffect: return __UIHoverHighlightEffect()
    case is UIHoverLiftEffect: return __UIHoverLiftEffect()
    default: return __UIHoverAutomaticEffect()
    }
}
@available(iOS 17.0, *)
extension UIHoverStyle {
    public convenience init(effect: some UIHoverEffect = .automatic, shape: UIShape? = nil) {
        self.init(__effect: _isimHoverEffectObjC(effect), shape: shape?.objc)
    }
    public convenience init(shape: UIShape?) { self.init(__shape: shape?.objc) }
    public var effect: any UIHoverEffect {
        get {
            switch __effect {
            case is __UIHoverHighlightEffect: return UIHoverHighlightEffect()
            case is __UIHoverLiftEffect: return UIHoverLiftEffect()
            default: return UIHoverAutomaticEffect()
            }
        }
        set { __effect = _isimHoverEffectObjC(newValue) }
    }
    public var shape: UIShape? {
        get { __shape.map(UIShape.init) }
        set { __shape = newValue?.objc }
    }
}
