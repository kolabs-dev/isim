// isim SwiftUI: drawing shapes, gradients and paths with isim's host renderer (cairo, libisim_host):
// fills (nonzero / even-odd), strokes (width, caps, joins, miter limit, dashes), linear/radial/conic
// gradients, tiled images; path clipping for clipShape/mask with arbitrary shapes.
import UIKit
import isim_host

// MARK: - Paint

struct _Stop { var color: UIColor; var location: Double }
/// A shape style resolved for a rect, in that rect's coordinates.
enum _Paint {
    case color(UIColor)
    case linear([_Stop], CGPoint, CGPoint, extend: Int)
    case radial([_Stop], CGPoint, CGFloat, CGFloat, matrix: CGAffineTransform?, extend: Int)
    case conic([_Stop], CGPoint, Double, Double)
    case image(UIImage, origin: CGPoint, source: CGRect, scale: CGFloat)
}

/// Shape styles that paint more than a color (gradients, image paint).
protocol _PaintStyle {
    @MainActor func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint
}
/// Shape styles that animate (their numbers interpolate in animated updates).
protocol _AnimatableStyle {
    @MainActor func _vector() -> [Double]
    @MainActor func _with(_ v: [Double]) -> Self?
}
/// Shape styles used where only a color can be drawn (text, tints): their main color.
protocol _ColorFallback {
    @MainActor func _fallbackColor(_ env: EnvironmentValues) -> Color
}

/// The view's foreground style (`.foreground`): the style set with foregroundStyle, or the foreground color.
public struct ForegroundStyle: ShapeStyle, Sendable {
    public init() {}
}
extension ShapeStyle where Self == ForegroundStyle {
    public static var foreground: ForegroundStyle { ForegroundStyle() }
}
/// The background style (`.background`): the system background color.
public struct BackgroundStyle: ShapeStyle, Sendable {
    public init() {}
}
extension ShapeStyle where Self == BackgroundStyle {
    public static var background: BackgroundStyle { BackgroundStyle() }
}
extension BackgroundStyle: _ColorFallback {
    func _fallbackColor(_ env: EnvironmentValues) -> Color { Color("systemBackground") { .systemBackground } }
}

/// foregroundStyle(_:) with a non-color style keeps it here, with the color it stands for (so a later
/// foregroundColor(_:) further in wins).
final class _ForegroundPaintBox { let style: any ShapeStyle; let fallback: Color?; init(_ s: any ShapeStyle, _ f: Color?) { style = s; fallback = f } }
struct _ForegroundPaintKey: EnvironmentKey { static var defaultValue: _ForegroundPaintBox? { nil } }
extension EnvironmentValues {
    var _foregroundPaint: _ForegroundPaintBox? { get { self[_ForegroundPaintKey.self] } set { self[_ForegroundPaintKey.self] = newValue } }
}
/// For foregroundStyle(_:): records styles that are more than a color.
@MainActor func _recordForeground(_ style: any ShapeStyle, _ env: inout EnvironmentValues) {
    var s = style
    while let a = s as? AnyShapeStyle { s = a.base }
    env._foregroundPaint = s is _PaintStyle ? _ForegroundPaintBox(s, env._foreground) : nil
}
@MainActor func _foregroundStyle(_ env: EnvironmentValues) -> any ShapeStyle {
    if let b = env._foregroundPaint, b.fallback == env._foreground { return b.style }
    return env._foreground ?? .primary
}

@MainActor func _unwrapStyle(_ style: any ShapeStyle, _ env: EnvironmentValues) -> any ShapeStyle {
    var s = style
    for _ in 0..<8 {
        if let a = s as? AnyShapeStyle { s = a.base; continue }
        if s is ForegroundStyle { s = _foregroundStyle(env); continue }
        break
    }
    return s
}
@MainActor func _resolvePaint(_ style: any ShapeStyle, in rect: CGRect, _ env: EnvironmentValues) -> _Paint {
    let s = _unwrapStyle(style, env)
    if let p = s as? _PaintStyle { return p._paint(in: rect, env) }
    return .color(_color(of: s, env).uiColor)
}
/// The single color a style stands for (gradients: their first stop).
@MainActor func _styleColor(_ style: any ShapeStyle, _ env: EnvironmentValues) -> Color {
    let s = _unwrapStyle(style, env)
    if let f = s as? _ColorFallback { return f._fallbackColor(env) }
    return _color(of: s, env)
}

/// Resolved RGBA of a (possibly dynamic) color for the current appearance.
func _rgbaOf(_ c: UIColor) -> [Double] {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    let resolved = c.resolvedColor(with: UITraitCollection.current)
    if !resolved.getRed(&r, green: &g, blue: &b, alpha: &a) {
        var w: CGFloat = 0
        if resolved.getWhite(&w, alpha: &a) { r = w; g = w; b = w }
    }
    return [Double(r), Double(g), Double(b), Double(a)]
}

extension Color: _AnimatableStyle {
    func _vector() -> [Double] { _rgbaOf(uiColor) }
    func _with(_ v: [Double]) -> Color? { v.count == 4 ? Color(red: v[0], green: v[1], blue: v[2], opacity: v[3]) : nil }
}

// MARK: - Shape views

/// A shape filled or stroked with a style.
public struct _ShapeView<Content: Shape, Style: ShapeStyle>: View, _PrimitiveView, Animatable {
    public var shape: Content
    public var style: Style
    public var fillStyle: FillStyle
    public init(shape: Content, style: Style, fillStyle: FillStyle = FillStyle()) { self.shape = shape; self.style = style; self.fillStyle = fillStyle }
    public var body: Never { fatalError() }
    public var animatableData: AnimatablePair<Content.AnimatableData, _AnimatableVector> {
        get { AnimatablePair(shape.animatableData, _AnimatableVector(MainActor.assumeIsolated { (style as? _AnimatableStyle)?._vector() ?? [] })) }
        set {
            shape.animatableData = newValue.first
            let v = newValue.second.values
            if !v.isEmpty, let a = style as? _AnimatableStyle, let s = MainActor.assumeIsolated({ a._with(v) }) as? Style { style = s }
        }
    }
    func _makeNode(_ ctx: _Context) -> _Node {
        let env = ctx.environment
        var stroke: StrokeStyle?
        var makePath: (CGRect) -> Path = { [shape] r in shape.path(in: r) }
        if let s = shape as? _StrokeInfo { stroke = s._strokeStyle; makePath = { r in s._basePath(in: r) } }
        let resolved = _unwrapStyle(style, env)
        if let m = resolved as? Material {
            return _MaterialNode(path: ctx.path, kind: (shape as? _ShapeInfo)?._kind ?? .rect, material: m)
        }
        // plain color fills of built-in shapes: a view with a background color and corner radius
        if stroke == nil, !fillStyle.isEOFilled, let info = shape as? _ShapeInfo, !(resolved is _PaintStyle) {
            return _ShapeNode(path: ctx.path, kind: info._kind, color: _color(of: resolved, env))
        }
        let eo = fillStyle.isEOFilled
        // ContainerRelativeShape (or an inset one) inside a container shape: the path comes from where the view is
        if let cs = env._containerShape, let extra = _containerRelativeInset(shape) {
            let n = _PathNode(path: ctx.path, ops: { r in [_DrawOp(path: Path(r), paint: _resolvePaint(resolved, in: r, env), stroke: stroke, eoFill: eo)] })
            n.relative = { [weak g = ctx.graph] view, r in
                guard let g, let cv = g.views[cs.viewKey], let sup = view.superview else { return nil }
                let inContainer = sup.convert(view.frame, to: cv)
                return [_DrawOp(path: _concentricPath(cs, rect: inContainer, container: cv.bounds.size, extra: extra),
                                paint: _resolvePaint(resolved, in: r, env), stroke: stroke, eoFill: eo)]
            }
            return n
        }
        return _PathNode(path: ctx.path, ops: { r in [_DrawOp(path: makePath(r), paint: _resolvePaint(resolved, in: r, env), stroke: stroke, eoFill: eo)] })
    }
}
/// How far a ContainerRelativeShape is inset (nil: the shape is not one; strokes of one count too).
func _containerRelativeInset(_ s: Any) -> CGFloat? {
    if s is ContainerRelativeShape { return 0 }
    if let i = s as? _InsetShape<ContainerRelativeShape> { return i.amount }
    for c in Mirror(reflecting: s).children where c.label == "shape" { return _containerRelativeInset(c.value) }
    return nil
}

/// A background of `shape` painted with `style`, when that takes isim's renderer (gradients, image paint, or a
/// shape other than the built-in ones); nil when the caller's color/corner-radius view does it.
@MainActor func _styleBackgroundNode<S: Shape>(_ style: any ShapeStyle, shape: S, _ ctx: _Context, fillStyle: FillStyle = FillStyle()) -> _Node? {
    let env = ctx.environment
    let resolved = _unwrapStyle(style, env)
    if resolved is Material { return nil }
    guard resolved is _PaintStyle || !(shape is _ShapeInfo) || fillStyle.isEOFilled else { return nil }
    return _PathNode(path: ctx.path + "/bgs", ops: { r in [_DrawOp(path: shape.path(in: r), paint: _resolvePaint(resolved, in: r, env), stroke: nil, eoFill: fillStyle.isEOFilled)] })
}
/// The first shape inside a view value (mask { MyShape() }, mask { MyShape().fill() }).
func _innerAnyShape(_ v: Any) -> AnyShape? {
    if let s = v as? any Shape { return AnyShape(s) }
    for c in Mirror(reflecting: v).children { if let s = _innerAnyShape(c.value) { return s } }
    return nil
}

struct _DrawOp {
    var path: Path
    var paint: _Paint
    var stroke: StrokeStyle?
    var eoFill = false
    var alpha = 1.0
}

/// A node drawn with draw operations computed for its frame (shapes, gradients).
final class _PathNode: _Node {
    let ops: (CGRect) -> [_DrawOp]
    /// ops that depend on where the view is (ContainerRelativeShape): computed once it is in place
    var relative: (@MainActor (UIView, CGRect) -> [_DrawOp]?)?
    init(path: String, ops: @escaping (CGRect) -> [_DrawOp]) { self.ops = ops; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 10, height: p.height ?? 10) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIPathView(frame: .zero) }
        let local = CGRect(origin: .zero, size: frame.size)
        v.ops = ops(local)
        if let rel = relative { g.postRender.append { [weak v] in if let v, let o = rel(v, local) { v.ops = o; v.setNeedsDisplay() } } }
        v.setNeedsDisplay()
        return v
    }
}
final class _SUIPathView: UIView {
    var ops: [_DrawOp] = []
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ rect: CGRect) { for op in ops { _draw(op) } }
}

// MARK: - Host drawing

/// Makes `p` the host's current path.
func _hostPath(_ p: Path) {
    isim_path_begin()
    var last = CGPoint.zero, start = CGPoint.zero, open = false
    for e in p.elements {
        switch e {
        case .move(let a): isim_path_move(a.x, a.y); last = a; start = a; open = true
        case .line(let a):
            if !open { isim_path_move(last.x, last.y); open = true }
            isim_path_line(a.x, a.y); last = a
        case .quadCurve(let a, let c):
            if !open { isim_path_move(last.x, last.y); open = true }
            isim_path_curve(last.x + 2 / 3 * (c.x - last.x), last.y + 2 / 3 * (c.y - last.y), a.x + 2 / 3 * (c.x - a.x), a.y + 2 / 3 * (c.y - a.y), a.x, a.y)
            last = a
        case .curve(let a, let c1, let c2):
            if !open { isim_path_move(last.x, last.y); open = true }
            isim_path_curve(c1.x, c1.y, c2.x, c2.y, a.x, a.y); last = a
        case .closeSubpath: if open { isim_path_close() }; last = start; open = false
        }
    }
}
func _setStrokeStyle(_ s: StrokeStyle) {
    let dash = s.dash.map { Double($0) }
    dash.withUnsafeBufferPointer { d in
        isim_path_set_line_style(Int32(s.lineCap.rawValue), Int32(s.lineJoin.rawValue), s.miterLimit, d.baseAddress, Int32(dash.count), s.dashPhase)
    }
}
/// Draws one operation in the current graphics state.
func _draw(_ op: _DrawOp) {
    if op.path.isEmpty { return }
    isim_gfx_save()
    _hostPath(op.path)
    isim_path_set_fill_rule(op.eoFill ? 1 : 0)
    if let s = op.stroke { _setStrokeStyle(s) }
    _paintCurrentPath(op.paint, mode: op.stroke == nil ? 0 : 1, lineWidth: op.stroke?.lineWidth ?? 0, alpha: op.alpha, bounds: op.path.boundingRect)
    isim_path_begin()
    isim_gfx_restore()
}
/// Paints the host's current path: mode 0 fill, 1 stroke, 2 the whole clip area.
func _paintCurrentPath(_ paint: _Paint, mode: Int, lineWidth: CGFloat, alpha: Double, bounds: CGRect) {
    func stops(_ s: [_Stop]) -> ([Double], [Double]) {
        var locs: [Double] = [], rgba: [Double] = []
        var lastLoc = 0.0
        for (i, st) in s.enumerated() {
            let l = max(lastLoc, min(1, max(0, st.location.isNaN ? Double(i) / Double(max(1, s.count - 1)) : st.location)))
            locs.append(l); lastLoc = l
            var c = _rgbaOf(st.color); c[3] *= alpha
            rgba += c
        }
        return (locs, rgba)
    }
    func gradient(_ kind: Int32, _ geom: [Double], _ s: [_Stop], extend: Int32, matrix: CGAffineTransform?) {
        let (locs, rgba) = stops(s)
        let m: [Double]? = matrix.map { [$0.a, $0.b, $0.c, $0.d, $0.tx, $0.ty] }
        geom.withUnsafeBufferPointer { g in locs.withUnsafeBufferPointer { l in rgba.withUnsafeBufferPointer { c in
            if let m {
                m.withUnsafeBufferPointer { mp in isim_path_gradient(Int32(mode), kind, g.baseAddress, Int32(locs.count), l.baseAddress, c.baseAddress, extend, lineWidth, mp.baseAddress) }
            } else {
                isim_path_gradient(Int32(mode), kind, g.baseAddress, Int32(locs.count), l.baseAddress, c.baseAddress, extend, lineWidth, nil)
            }
        } } }
    }
    switch paint {
    case .color(let c):
        var rgba = _rgbaOf(c); rgba[3] *= alpha
        if rgba[3] <= 0 { return }
        rgba.withUnsafeBufferPointer { p in
            switch mode {
            case 1: isim_path_stroke(lineWidth, p.baseAddress)
            case 2: isim_gfx_save(); isim_gfx_fill_rounded(-1e5, -1e5, 2e5, 2e5, 0, p.baseAddress); isim_gfx_restore()
            default: isim_path_fill(p.baseAddress)
            }
        }
    case .linear(let s, let a, let b, let ext): gradient(0, [a.x, a.y, b.x, b.y], s, extend: Int32(ext), matrix: nil)
    case .radial(let s, let c, let r0, let r1, let m, let ext): gradient(1, [c.x, c.y, r0, c.x, c.y, r1], s, extend: Int32(ext), matrix: m)
    case .conic(let s, let c, let a0, let a1): gradient(2, [c.x, c.y, a0, a1], s, extend: 1, matrix: nil)
    case .image(let img, let origin, let source, let scale):
        // tiles of the image (or of its source rect, in unit coordinates) clipped to the path; strokes are not drawn
        let size = img.size
        guard mode != 1, size.width > 0, size.height > 0 else { return }
        let tile = CGSize(width: size.width * source.width * scale, height: size.height * source.height * scale)
        guard tile.width >= 1, tile.height >= 1 else { return }
        isim_gfx_save()
        if mode == 0 { isim_gfx_clip_path() }
        if alpha < 1 { isim_gfx_push_group() }
        let x0 = origin.x + ((bounds.minX - origin.x) / tile.width).rounded(.down) * tile.width
        let y0 = origin.y + ((bounds.minY - origin.y) / tile.height).rounded(.down) * tile.height
        var y = y0, n = 0
        while y < bounds.maxY && n < 4000 {
            var x = x0
            while x < bounds.maxX && n < 4000 {
                let full = CGRect(x: x - source.minX * size.width * scale, y: y - source.minY * size.height * scale, width: size.width * scale, height: size.height * scale)
                isim_gfx_save(); isim_gfx_clip_rounded(x, y, tile.width, tile.height, 0)
                img.draw(in: full)
                isim_gfx_restore()
                x += tile.width; n += 1
            }
            y += tile.height
        }
        if alpha < 1 { isim_gfx_pop_group(alpha) }
        isim_gfx_restore()
    }
}

// MARK: - Ideal size (for other isim modules)

extension View {
    /// isim: the size a view takes along a dimension its parent leaves open (scroll views, fixedSize),
    /// like an ideal size. Used by Charts.
    public func _isimIdealSize(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        _modify { ctx, c in _IdealSizeNode(path: ctx.path, width: width, height: height, child: _resolve(c, ctx.child("ideal"))) }
    }
}
final class _IdealSizeNode: _WrapperNode {
    let width: CGFloat?, height: CGFloat?
    init(path: String, width: CGFloat?, height: CGFloat?, child: _Node) { self.width = width; self.height = height; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(_Proposal(width: p.width ?? width, height: p.height ?? height)) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

// MARK: - Clipping to a path (clipShape / mask with any shape)

final class _PathClipNode: _WrapperNode {
    let shape: AnyShape, eoFill: Bool
    init(path: String, shape: AnyShape, eoFill: Bool, child: _Node) { self.shape = shape; self.eoFill = eoFill; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIPathClipView(frame: .zero) }
        v.clipPath = shape.path(in: CGRect(origin: .zero, size: frame.size))
        v.eoFill = eoFill
        v.clipsToBounds = true           // isim UIKit saves/restores the graphics state around a clipping view's content
        return v
    }
}
final class _SUIPathClipView: UIView {
    var clipPath = Path(), eoFill = false
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard clipPath.contains(point, eoFill: eoFill) else { return nil }
        let v = super.hitTest(point, with: event)
        return v === self ? nil : v
    }
    /// isim UIKit draws a view's own content right after clipping to its bounds, before its subviews.
    @objc(_isim_drawContent) func _isimDrawContent() {
        _hostPath(clipPath)
        isim_path_set_fill_rule(eoFill ? 1 : 0)
        isim_gfx_clip_path()
        isim_path_set_fill_rule(0)
    }
}
