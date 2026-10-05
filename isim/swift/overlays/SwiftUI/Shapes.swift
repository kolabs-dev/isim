// isim SwiftUI: shapes (filled), clipShape, onOpenURL, image sizing.
import UIKit

public protocol Shape: View {}
enum _ShapeKind { case rect, rounded(CGFloat), circle, capsule }
protocol _ShapeInfo { var _kind: _ShapeKind { get } }

public struct Rectangle: Shape, _ShapeInfo, _PrimitiveView {
    public init() {}
    var _kind: _ShapeKind { .rect }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeNode(path: ctx.path, kind: _kind, color: ctx.environment._foreground ?? .primary) }
}
public struct RoundedRectangle: Shape, _ShapeInfo, _PrimitiveView {
    let cornerRadius: CGFloat
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) { self.cornerRadius = cornerRadius }
    var _kind: _ShapeKind { .rounded(cornerRadius) }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeNode(path: ctx.path, kind: _kind, color: ctx.environment._foreground ?? .primary) }
}
public enum RoundedCornerStyle: Sendable { case circular, continuous }
public struct Circle: Shape, _ShapeInfo, _PrimitiveView {
    public init() {}
    var _kind: _ShapeKind { .circle }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeNode(path: ctx.path, kind: _kind, color: ctx.environment._foreground ?? .primary) }
}
public struct Capsule: Shape, _ShapeInfo, _PrimitiveView {
    public init(style: RoundedCornerStyle = .continuous) {}
    var _kind: _ShapeKind { .capsule }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeNode(path: ctx.path, kind: _kind, color: ctx.environment._foreground ?? .primary) }
}
extension Shape {
    public func fill<S: ShapeStyle>(_ style: S) -> some View {
        let kind = (self as? _ShapeInfo)?._kind ?? .rect
        return _modify { ctx, _ in _ShapeNode(path: ctx.path, kind: kind, color: _color(of: style, ctx.environment)) }
    }
}

/// A filled shape: the proposed size, drawn as the view's background with a corner radius.
final class _ShapeNode: _Node {
    let kind: _ShapeKind, color: Color
    init(path: String, kind: _ShapeKind, color: Color) { self.kind = kind; self.color = color; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { UIView() }
        v.backgroundColor = color.uiColor
        v.isUserInteractionEnabled = false
        v.layer.cornerRadius = _radius(kind, frame.size)
        return v
    }
}
func _radius(_ k: _ShapeKind, _ s: CGSize) -> CGFloat {
    switch k {
    case .rect: return 0
    case .rounded(let r): return r
    case .circle, .capsule: return min(s.width, s.height) / 2
    }
}

final class _ClipNode: _WrapperNode {
    let kind: _ShapeKind
    init(path: String, kind: _ShapeKind, child: _Node) { self.kind = kind; super.init(path: path, child: child) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        v.clipsToBounds = true
        v.layer.cornerRadius = _radius(kind, frame.size)
        return v
    }
}

extension View {
    public func clipShape<S: Shape>(_ shape: S) -> some View {
        let kind = (shape as? _ShapeInfo)?._kind ?? .rect
        return _modify { ctx, c in _ClipNode(path: ctx.path, kind: kind, child: _resolve(c, ctx.child("clip"))) }
    }
    public func scaledToFit() -> some View { self }
    public func scaledToFill() -> some View { self }
    public func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode) -> some View { self }
    /// Called with URLs opened in this app (UIApplication openURL deliveries, launch URLs).
    public func onOpenURL(perform action: @escaping (URL) -> Void) -> some View {
        _modify { ctx, c in
            ctx.graph.registerURLHandler(ctx.path, action)
            return _resolve(c, ctx.child("url"))
        }
    }
}
public enum ContentMode: Hashable, CaseIterable, Sendable { case fit, fill }
