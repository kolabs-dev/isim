// isim SwiftUI: shapes. A Shape is an outline (`path(in:)`) drawn by isim's renderer (Rendering.swift):
// filled or stroked with any ShapeStyle (colors, gradients, image paint, materials), trimmed, inset,
// transformed, type-erased. Plain filled rectangles, rounded rectangles, circles and capsules use
// a UIView with a background color and corner radius (cheap, and animatable by UIKit).
// Shape types declare their View conformance in extensions, so (like SwiftUI) their initializers and
// geometry are not main-actor isolated.
import UIKit

public protocol Shape: Sendable, Animatable, View {
    /// The outline of the shape in a rect (the frame the shape is laid out in).
    nonisolated func path(in rect: CGRect) -> Path
    nonisolated static var role: ShapeRole { get }
}
public enum ShapeRole: Hashable, Sendable { case fill, stroke, separator }
extension Shape {
    nonisolated public static var role: ShapeRole { .fill }
    /// A shape draws itself filled with the foreground style.
    public var body: _ShapeView<Self, ForegroundStyle> { _ShapeView(shape: self, style: ForegroundStyle()) }
}

/// A shape that can be inset (strokeBorder draws inside its frame).
public protocol InsettableShape: Shape {
    associatedtype InsetShape: InsettableShape
    nonisolated func inset(by amount: CGFloat) -> InsetShape
}

enum _ShapeKind { case rect, rounded(CGFloat), circle, capsule }
/// Built-in shapes that render as a view with a corner radius when filled with a color.
protocol _ShapeInfo { var _kind: _ShapeKind { get } }
/// Shapes whose inset outline is not just the outline of the inset rect (rounded corners shrink).
protocol _InsetPath { func _insetPath(in rect: CGRect, by amount: CGFloat) -> Path }

public struct Rectangle: Sendable {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> _InsetShape<Rectangle> { _InsetShape(base: self, amount: amount) }
    var _kind: _ShapeKind { .rect }
}
extension Rectangle: InsettableShape, _ShapeInfo, _PrimitiveView {
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeView(shape: self, style: ForegroundStyle())._makeNode(ctx) }
}
public struct RoundedRectangle: Sendable {
    public var cornerSize: CGSize
    public var style: RoundedCornerStyle
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) { cornerSize = CGSize(width: cornerRadius, height: cornerRadius); self.style = style }
    public init(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) { self.cornerSize = cornerSize; self.style = style }
    public func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerSize: cornerSize, style: style) }
    func _insetPath(in rect: CGRect, by a: CGFloat) -> Path {
        Path(roundedRect: rect.insetBy(dx: a, dy: a), cornerSize: CGSize(width: max(0, cornerSize.width - a), height: max(0, cornerSize.height - a)), style: style)
    }
    public func inset(by amount: CGFloat) -> _InsetShape<RoundedRectangle> { _InsetShape(base: self, amount: amount) }
    public var animatableData: CGSize.AnimatableData { get { cornerSize.animatableData } set { cornerSize.animatableData = newValue } }
    var _kind: _ShapeKind { .rounded(cornerSize.width) }
}
extension RoundedRectangle: InsettableShape, _ShapeInfo, _InsetPath, _PrimitiveView {
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeView(shape: self, style: ForegroundStyle())._makeNode(ctx) }
}
public enum RoundedCornerStyle: Hashable, Sendable { case circular, continuous }
public struct Circle: Sendable {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        return Path(ellipseIn: CGRect(x: rect.midX - d / 2, y: rect.midY - d / 2, width: d, height: d))
    }
    public func inset(by amount: CGFloat) -> _InsetShape<Circle> { _InsetShape(base: self, amount: amount) }
    var _kind: _ShapeKind { .circle }
}
extension Circle: InsettableShape, _ShapeInfo, _PrimitiveView {
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeView(shape: self, style: ForegroundStyle())._makeNode(ctx) }
}
public struct Capsule: Sendable {
    public var style: RoundedCornerStyle
    public init(style: RoundedCornerStyle = .continuous) { self.style = style }
    public func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2, style: style) }
    public func inset(by amount: CGFloat) -> _InsetShape<Capsule> { _InsetShape(base: self, amount: amount) }
    var _kind: _ShapeKind { .capsule }
}
extension Capsule: InsettableShape, _ShapeInfo, _PrimitiveView {
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ShapeView(shape: self, style: ForegroundStyle())._makeNode(ctx) }
}
public struct Ellipse: Sendable {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(ellipseIn: rect) }
    public func inset(by amount: CGFloat) -> _InsetShape<Ellipse> { _InsetShape(base: self, amount: amount) }
}
extension Ellipse: InsettableShape {}
public struct UnevenRoundedRectangle: Sendable {
    public var cornerRadii: RectangleCornerRadii
    public var style: RoundedCornerStyle
    public init(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) { self.cornerRadii = cornerRadii; self.style = style }
    public init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) {
        cornerRadii = RectangleCornerRadii(topLeading: topLeadingRadius, bottomLeading: bottomLeadingRadius, bottomTrailing: bottomTrailingRadius, topTrailing: topTrailingRadius)
        self.style = style
    }
    public func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerRadii: cornerRadii, style: style) }
    func _insetPath(in rect: CGRect, by a: CGFloat) -> Path {
        let c = cornerRadii
        return Path(roundedRect: rect.insetBy(dx: a, dy: a), cornerRadii: RectangleCornerRadii(topLeading: max(0, c.topLeading - a), bottomLeading: max(0, c.bottomLeading - a),
                                                                                                   bottomTrailing: max(0, c.bottomTrailing - a), topTrailing: max(0, c.topTrailing - a)), style: style)
    }
    public func inset(by amount: CGFloat) -> _InsetShape<UnevenRoundedRectangle> { _InsetShape(base: self, amount: amount) }
    public var animatableData: RectangleCornerRadii.AnimatableData { get { cornerRadii.animatableData } set { cornerRadii.animatableData = newValue } }
}
extension UnevenRoundedRectangle: InsettableShape, _InsetPath {}
/// The shape of the containing container (widgets, …). isim has no container shapes: it is the rectangle of its frame.
public struct ContainerRelativeShape: Sendable {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> _InsetShape<ContainerRelativeShape> { _InsetShape(base: self, amount: amount) }
}
extension ContainerRelativeShape: InsettableShape {}

/// A shape inset by an amount on every edge.
public struct _InsetShape<Base: Shape>: Sendable {
    public var base: Base, amount: CGFloat
    public func path(in rect: CGRect) -> Path {
        if let b = base as? _InsetPath { return b._insetPath(in: rect, by: amount) }
        return base.path(in: rect.insetBy(dx: amount, dy: amount))
    }
    public func inset(by more: CGFloat) -> _InsetShape<Base> { _InsetShape(base: base, amount: amount + more) }
    public var animatableData: AnimatablePair<CGFloat, Base.AnimatableData> {
        get { AnimatablePair(amount, base.animatableData) }
        set { amount = newValue.first; base.animatableData = newValue.second }
    }
}
extension _InsetShape: InsettableShape {}

/// A type-erased shape.
public struct AnyShape: @unchecked Sendable {
    let make: @Sendable (CGRect) -> Path
    public init<S: Shape>(_ shape: S) {
        if let a = shape as? AnyShape { self = a; return }
        make = { r in shape.path(in: r) }
    }
    public func path(in rect: CGRect) -> Path { make(rect) }
    public func inset(by amount: CGFloat) -> AnyShape { AnyShape(_InsetShape(base: self, amount: amount)) }
}
extension AnyShape: InsettableShape {}

// MARK: - Shape modifiers that return shapes

/// A shape with a trim range (from/to as fractions of its outline).
public struct _TrimmedShape<S: Shape>: Sendable {
    public var shape: S, startFraction: CGFloat, endFraction: CGFloat
    public func path(in rect: CGRect) -> Path { shape.path(in: rect).trimmedPath(from: startFraction, to: endFraction) }
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, S.AnimatableData> {
        get { AnimatablePair(AnimatablePair(startFraction, endFraction), shape.animatableData) }
        set { startFraction = newValue.first.first; endFraction = newValue.first.second; shape.animatableData = newValue.second }
    }
}
extension _TrimmedShape: Shape {}
/// A shape drawn as its outline (stroke(style:) / stroke(lineWidth:)): filling it strokes the base shape.
public struct _StrokedShape<S: Shape>: Sendable {
    public var shape: S, style: StrokeStyle
    public func path(in rect: CGRect) -> Path { shape.path(in: rect) }
    public var animatableData: AnimatablePair<S.AnimatableData, StrokeStyle.AnimatableData> {
        get { AnimatablePair(shape.animatableData, style.animatableData) }
        set { shape.animatableData = newValue.first; style.animatableData = newValue.second }
    }
}
extension _StrokedShape: Shape {}
protocol _StrokeInfo { var _strokeStyle: StrokeStyle { get }; func _basePath(in rect: CGRect) -> Path }
extension _StrokedShape: _StrokeInfo {
    var _strokeStyle: StrokeStyle { style }
    func _basePath(in rect: CGRect) -> Path { shape.path(in: rect) }
}
public struct OffsetShape<Content: Shape>: Sendable {
    public var shape: Content, offset: CGSize
    public init(shape: Content, offset: CGSize) { self.shape = shape; self.offset = offset }
    public func path(in rect: CGRect) -> Path { shape.path(in: rect).offsetBy(dx: offset.width, dy: offset.height) }
    public var animatableData: AnimatablePair<Content.AnimatableData, CGSize.AnimatableData> {
        get { AnimatablePair(shape.animatableData, offset.animatableData) }
        set { shape.animatableData = newValue.first; offset.animatableData = newValue.second }
    }
}
extension OffsetShape: Shape {}
extension OffsetShape: InsettableShape where Content: InsettableShape {
    public func inset(by amount: CGFloat) -> OffsetShape<Content.InsetShape> { OffsetShape<Content.InsetShape>(shape: shape.inset(by: amount), offset: offset) }
}
public struct RotatedShape<Content: Shape>: Sendable {
    public var shape: Content, angle: Angle, anchor: UnitPoint
    public init(shape: Content, angle: Angle, anchor: UnitPoint = .center) { self.shape = shape; self.angle = angle; self.anchor = anchor }
    public func path(in rect: CGRect) -> Path {
        let ax = rect.minX + anchor.x * rect.width, ay = rect.minY + anchor.y * rect.height
        let t = CGAffineTransform(translationX: -ax, y: -ay).concatenating(CGAffineTransform(rotationAngle: angle.radians)).concatenating(CGAffineTransform(translationX: ax, y: ay))
        return shape.path(in: rect).applying(t)
    }
    public var animatableData: AnimatablePair<Content.AnimatableData, AnimatablePair<Double, UnitPoint.AnimatableData>> {
        get { AnimatablePair(shape.animatableData, AnimatablePair(angle.radians, anchor.animatableData)) }
        set { shape.animatableData = newValue.first; angle.radians = newValue.second.first; anchor.animatableData = newValue.second.second }
    }
}
extension RotatedShape: Shape {}
extension RotatedShape: InsettableShape where Content: InsettableShape {
    public func inset(by amount: CGFloat) -> RotatedShape<Content.InsetShape> { RotatedShape<Content.InsetShape>(shape: shape.inset(by: amount), angle: angle, anchor: anchor) }
}
public struct ScaledShape<Content: Shape>: Sendable {
    public var shape: Content, scale: CGSize, anchor: UnitPoint
    public init(shape: Content, scale: CGSize, anchor: UnitPoint = .center) { self.shape = shape; self.scale = scale; self.anchor = anchor }
    public func path(in rect: CGRect) -> Path {
        let ax = rect.minX + anchor.x * rect.width, ay = rect.minY + anchor.y * rect.height
        let t = CGAffineTransform(translationX: -ax, y: -ay).concatenating(CGAffineTransform(scaleX: scale.width, y: scale.height)).concatenating(CGAffineTransform(translationX: ax, y: ay))
        return shape.path(in: rect).applying(t)
    }
    public var animatableData: AnimatablePair<Content.AnimatableData, AnimatablePair<CGSize.AnimatableData, UnitPoint.AnimatableData>> {
        get { AnimatablePair(shape.animatableData, AnimatablePair(scale.animatableData, anchor.animatableData)) }
        set { shape.animatableData = newValue.first; scale.animatableData = newValue.second.first; anchor.animatableData = newValue.second.second }
    }
}
extension ScaledShape: Shape {}
public struct TransformedShape<Content: Shape>: @unchecked Sendable {
    public var shape: Content, transform: CGAffineTransform
    public init(shape: Content, transform: CGAffineTransform) { self.shape = shape; self.transform = transform }
    public func path(in rect: CGRect) -> Path { shape.path(in: rect).applying(transform) }
}
extension TransformedShape: Shape {}
/// .size(width:height:): the shape drawn at a fixed size at the frame's origin.
public struct _SizedShape<S: Shape>: Sendable {
    public var shape: S, size: CGSize
    public func path(in rect: CGRect) -> Path { shape.path(in: CGRect(origin: rect.origin, size: size)) }
    public var animatableData: AnimatablePair<S.AnimatableData, CGSize.AnimatableData> {
        get { AnimatablePair(shape.animatableData, size.animatableData) }
        set { shape.animatableData = newValue.first; size.animatableData = newValue.second }
    }
}
extension _SizedShape: Shape {}

public struct StrokeStyle: Hashable, Animatable, Sendable {
    public var lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, dash: [CGFloat], dashPhase: CGFloat
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10, dash: [CGFloat] = [], dashPhase: CGFloat = 0) {
        self.lineWidth = lineWidth; self.lineCap = lineCap; self.lineJoin = lineJoin; self.miterLimit = miterLimit; self.dash = dash; self.dashPhase = dashPhase
    }
    public static func == (a: StrokeStyle, b: StrokeStyle) -> Bool {
        a.lineWidth == b.lineWidth && a.lineCap == b.lineCap && a.lineJoin == b.lineJoin && a.miterLimit == b.miterLimit && a.dash == b.dash && a.dashPhase == b.dashPhase
    }
    public func hash(into h: inout Hasher) { h.combine(lineWidth); h.combine(lineCap.rawValue); h.combine(lineJoin.rawValue); h.combine(miterLimit); h.combine(dash); h.combine(dashPhase) }
    public var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(lineWidth, AnimatablePair(miterLimit, dashPhase)) }
        set { lineWidth = newValue.first; miterLimit = newValue.second.first; dashPhase = newValue.second.second }
    }
}

extension Shape {
    public func trim(from startFraction: CGFloat = 0, to endFraction: CGFloat = 1) -> _TrimmedShape<Self> {
        _TrimmedShape(shape: self, startFraction: startFraction, endFraction: endFraction)
    }
    public func offset(_ offset: CGSize) -> OffsetShape<Self> { OffsetShape(shape: self, offset: offset) }
    public func offset(_ offset: CGPoint) -> OffsetShape<Self> { OffsetShape(shape: self, offset: CGSize(width: offset.x, height: offset.y)) }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetShape<Self> { OffsetShape(shape: self, offset: CGSize(width: x, height: y)) }
    public func rotation(_ angle: Angle, anchor: UnitPoint = .center) -> RotatedShape<Self> { RotatedShape(shape: self, angle: angle, anchor: anchor) }
    public func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> ScaledShape<Self> { ScaledShape(shape: self, scale: CGSize(width: x, height: y), anchor: anchor) }
    public func scale(_ scale: CGFloat, anchor: UnitPoint = .center) -> ScaledShape<Self> { self.scale(x: scale, y: scale, anchor: anchor) }
    public func transform(_ transform: CGAffineTransform) -> TransformedShape<Self> { TransformedShape(shape: self, transform: transform) }
    public func size(_ size: CGSize) -> _SizedShape<Self> { _SizedShape(shape: self, size: size) }
    public func size(width: CGFloat, height: CGFloat) -> _SizedShape<Self> { _SizedShape(shape: self, size: CGSize(width: width, height: height)) }

    public func fill<S: ShapeStyle>(_ content: S, style: FillStyle = FillStyle()) -> _ShapeView<Self, S> { _ShapeView(shape: self, style: content, fillStyle: style) }
    public func fill(style: FillStyle = FillStyle()) -> _ShapeView<Self, ForegroundStyle> { _ShapeView(shape: self, style: ForegroundStyle(), fillStyle: style) }
    public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> _ShapeView<_StrokedShape<Self>, S> {
        _ShapeView(shape: _StrokedShape(shape: self, style: style), style: content)
    }
    public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> _ShapeView<_StrokedShape<Self>, S> {
        stroke(content, style: StrokeStyle(lineWidth: lineWidth))
    }
    public func stroke(style: StrokeStyle) -> _StrokedShape<Self> { _StrokedShape(shape: self, style: style) }
    public func stroke(lineWidth: CGFloat = 1) -> _StrokedShape<Self> { _StrokedShape(shape: self, style: StrokeStyle(lineWidth: lineWidth)) }
}
extension InsettableShape {
    public func strokeBorder<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> _ShapeView<_StrokedShape<InsetShape>, S> {
        inset(by: style.lineWidth / 2).stroke(content, style: style)
    }
    public func strokeBorder(style: StrokeStyle, antialiased: Bool = true) -> _ShapeView<_StrokedShape<InsetShape>, ForegroundStyle> {
        inset(by: style.lineWidth / 2).stroke(ForegroundStyle(), style: style)
    }
    public func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> _ShapeView<_StrokedShape<InsetShape>, S> {
        strokeBorder(content, style: StrokeStyle(lineWidth: lineWidth))
    }
    public func strokeBorder(lineWidth: CGFloat = 1, antialiased: Bool = true) -> _ShapeView<_StrokedShape<InsetShape>, ForegroundStyle> {
        strokeBorder(style: StrokeStyle(lineWidth: lineWidth))
    }
}
/// iOS 17: a filled shape can also be stroked (fill(_:).stroke(_:)).
extension _ShapeView {
    public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> some View {
        overlay { shape.stroke(content, style: style) }
    }
    public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> some View {
        stroke(content, style: StrokeStyle(lineWidth: lineWidth))
    }
}
extension _ShapeView where Content: InsettableShape {
    public func strokeBorder<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> some View {
        overlay { shape.strokeBorder(content, style: style) }
    }
    public func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> some View {
        strokeBorder(content, style: StrokeStyle(lineWidth: lineWidth))
    }
}

// MARK: - Materials

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

/// A filled built-in shape: the proposed size, drawn as the view's background with a corner radius.
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
    case .rounded(let r): return min(r, min(s.width, s.height) / 2)
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
    /// Clips to the shape: built-in shapes as a rounded clip of the view, other shapes to their path.
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View {
        _modify { ctx, c in
            if let info = shape as? _ShapeInfo { return _ClipNode(path: ctx.path, kind: info._kind, child: _resolve(c, ctx.child("clip"))) }
            return _PathClipNode(path: ctx.path, shape: AnyShape(shape), eoFill: style.isEOFilled, child: _resolve(c, ctx.child("clip")))
        }
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
