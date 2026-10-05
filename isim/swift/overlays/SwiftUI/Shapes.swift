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
public struct StrokeStyle: Equatable, Sendable {
    public var lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, dash: [CGFloat], dashPhase: CGFloat
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10, dash: [CGFloat] = [], dashPhase: CGFloat = 0) {
        self.lineWidth = lineWidth; self.lineCap = lineCap; self.lineJoin = lineJoin; self.miterLimit = miterLimit; self.dash = dash; self.dashPhase = dashPhase
    }
}
/// A shape with a trim range (from/to as fractions of its outline).
public struct _TrimmedShape: Shape, _ShapeInfo, _PrimitiveView {
    let kind: _ShapeKind, from: CGFloat, to: CGFloat
    var _kind: _ShapeKind { kind }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _StrokeNode(path: ctx.path, kind: kind, color: ctx.environment._foreground ?? .primary, lineWidth: 1, fill: true, trim: (from, to)) }
}
extension Shape {
    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: CGFloat = 1) -> some View {
        let kind = (self as? _ShapeInfo)?._kind ?? .rect
        let trim = (self as? _TrimmedShape).map { ($0.from, $0.to) } ?? (0, 1)
        return _modify { ctx, _ in _StrokeNode(path: ctx.path, kind: kind, color: _color(of: style, ctx.environment), lineWidth: lineWidth, fill: false, trim: trim) }
    }
    public func stroke<S: ShapeStyle>(_ style: S, style strokeStyle: StrokeStyle) -> some View {
        let kind = (self as? _ShapeInfo)?._kind ?? .rect
        let trim = (self as? _TrimmedShape).map { ($0.from, $0.to) } ?? (0, 1)
        return _modify { ctx, _ in _StrokeNode(path: ctx.path, kind: kind, color: _color(of: style, ctx.environment), lineWidth: strokeStyle.lineWidth, fill: false, trim: trim, cap: strokeStyle.lineCap) }
    }
    public func stroke(lineWidth: CGFloat = 1) -> some View {
        let kind = (self as? _ShapeInfo)?._kind ?? .rect
        let trim = (self as? _TrimmedShape).map { ($0.from, $0.to) } ?? (0, 1)
        return _modify { ctx, _ in _StrokeNode(path: ctx.path, kind: kind, color: ctx.environment._foreground ?? .primary, lineWidth: lineWidth, fill: false, trim: trim) }
    }
    public func stroke(style strokeStyle: StrokeStyle) -> some View { stroke(lineWidth: strokeStyle.lineWidth) }
    public func strokeBorder<S: ShapeStyle>(_ style: S, lineWidth: CGFloat = 1) -> some View { stroke(style, lineWidth: lineWidth) }
    public func strokeBorder(lineWidth: CGFloat = 1) -> some View { stroke(lineWidth: lineWidth) }
    public func trim(from: CGFloat = 0, to: CGFloat = 1) -> _TrimmedShape {
        _TrimmedShape(kind: (self as? _ShapeInfo)?._kind ?? .rect, from: from, to: to)
    }
    public func fill<S: ShapeStyle>(_ style: S) -> some View {
        let kind = (self as? _ShapeInfo)?._kind ?? .rect
        if let t = self as? _TrimmedShape {
            return AnyView(_modify { ctx, _ in _StrokeNode(path: ctx.path, kind: t.kind, color: _color(of: style, ctx.environment), lineWidth: 0, fill: true, trim: (t.from, t.to)) })
        }
        if let m = style as? Material { return AnyView(_modify { ctx, _ in _MaterialNode(path: ctx.path, kind: kind, material: m) }) }
        return AnyView(_modify { ctx, _ in _ShapeNode(path: ctx.path, kind: kind, color: _color(of: style, ctx.environment)) })
    }
}

/// Materials: a backdrop blur with the material's tint (UIVisualEffectView), light/dark aware.
public struct Material: ShapeStyle, Sendable {
    let style: UIBlurEffect.Style
    public static let ultraThin = Material(style: .systemUltraThinMaterial)
    public static let thin = Material(style: .systemThinMaterial)
    public static let regular = Material(style: .systemMaterial)
    public static let thick = Material(style: .systemThickMaterial)
    public static let ultraThick = Material(style: .systemThickMaterial)
    public static let bar = Material(style: .systemChromeMaterial)
}
extension ShapeStyle where Self == Material {
    public static var ultraThinMaterial: Material { .ultraThin }
    public static var thinMaterial: Material { .thin }
    public static var regularMaterial: Material { .regular }
    public static var thickMaterial: Material { .thick }
    public static var ultraThickMaterial: Material { .ultraThick }
    public static var bar: Material { .bar }
}
final class _MaterialNode: _Node {
    let kind: _ShapeKind, material: Material
    init(path: String, kind: _ShapeKind, material: Material) { self.kind = kind; self.material = material; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { UIVisualEffectView(effect: nil) }
        if (v.effect as? UIBlurEffect)?._isim_style != material.style { v.effect = UIBlurEffect(style: material.style) }
        v.isUserInteractionEnabled = false
        v.layer.cornerRadius = _radius(kind, frame.size)
        return v
    }
}

/// A stroked (or trimmed) shape outline, drawn with Core Graphics.
final class _StrokeNode: _Node {
    let kind: _ShapeKind, color: Color, lineWidth: CGFloat, fill: Bool, trim: (CGFloat, CGFloat), cap: CGLineCap
    init(path: String, kind: _ShapeKind, color: Color, lineWidth: CGFloat, fill: Bool, trim: (CGFloat, CGFloat), cap: CGLineCap = .butt) {
        self.kind = kind; self.color = color; self.lineWidth = lineWidth; self.fill = fill; self.trim = trim; self.cap = cap
        super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIShapeView(frame: .zero) }
        v.kind = kind; v.color = color.uiColor; v.lineWidth = lineWidth; v.fillShape = fill; v.trim = trim
        v.setNeedsDisplay()
        return v
    }
}
final class _SUIShapeView: UIView {
    var kind: _ShapeKind = .rect, color: UIColor = .label, lineWidth: CGFloat = 1, fillShape = false, trim: (CGFloat, CGFloat) = (0, 1)
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), trim.1 > trim.0 else { return }
        let r = bounds.insetBy(dx: fillShape ? 0 : lineWidth / 2, dy: fillShape ? 0 : lineWidth / 2)
        let path = CGMutablePath()
        let full = trim.0 <= 0 && trim.1 >= 1
        switch kind {
        case .circle where !full, .capsule where !full && abs(r.width - r.height) < 0.5:
            // SwiftUI circles start at 3 o'clock and go clockwise (in y-down coordinates)
            let c = CGPoint(x: r.midX, y: r.midY), rad = min(r.width, r.height) / 2
            path.addArc(center: c, radius: rad, startAngle: 2 * .pi * trim.0, endAngle: 2 * .pi * trim.1, clockwise: false)
        case .circle: path.addEllipse(in: CGRect(x: r.midX - min(r.width, r.height) / 2, y: r.midY - min(r.width, r.height) / 2, width: min(r.width, r.height), height: min(r.width, r.height)))
        case .capsule: let k = min(r.width, r.height) / 2; path.addRoundedRect(in: r, cornerWidth: k, cornerHeight: k)
        case .rounded(let k): let kk = min(k, min(r.width, r.height) / 2); path.addRoundedRect(in: r, cornerWidth: kk, cornerHeight: kk)
        case .rect: path.addRect(r)
        }
        ctx.addPath(path)
        if fillShape { ctx.setFillColor(color.cgColor); ctx.fillPath() }
        else { ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(lineWidth); ctx.strokePath() }
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
    public func scaledToFit() -> some View { aspectRatio(nil, contentMode: .fit) }
    public func scaledToFill() -> some View { aspectRatio(nil, contentMode: .fill) }
    public func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode) -> some View {
        _modify { ctx, c in _AspectNode(path: ctx.path, ratio: ratio, fill: contentMode == .fill, child: _resolve(c, ctx.child("ar"))) }
    }
    public func aspectRatio(_ size: CGSize, contentMode: ContentMode) -> some View { aspectRatio(size.width / size.height, contentMode: contentMode) }
    /// Called with URLs opened in this app (UIApplication openURL deliveries, launch URLs).
    public func onOpenURL(perform action: @escaping (URL) -> Void) -> some View {
        _modify { ctx, c in
            ctx.graph.registerURLHandler(ctx.path, action)
            return _resolve(c, ctx.child("url"))
        }
    }
}
public enum ContentMode: Hashable, CaseIterable, Sendable { case fit, fill }
