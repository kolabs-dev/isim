// isim SwiftUI: Canvas (immediate-mode drawing with GraphicsContext) and TimelineView.
// GraphicsContext draws straight into isim's host renderer: paths filled/stroked with colors, styles and
// gradients, text, images, transforms, opacity, clipping and layers. Filters run on a group of each drawing, one
// pass per filter in the order they were added (the host's colour matrix, blur and shadow); clipToLayer renders its
// content offscreen and masks later drawing with it; blend modes composite each drawing's group; symbols are the
// Canvas's `symbols` views (by tag), mounted hidden and drawn from their view hierarchy.
import UIKit
import isim_host

public enum ColorRenderingMode: Hashable, Sendable { case nonLinear, linear, extendedLinear }

public struct Canvas<Symbols: View>: View, _PrimitiveView {
    let renderer: (inout GraphicsContext, CGSize) -> Void
    let opaque: Bool
    let symbols: Symbols
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void, @ViewBuilder symbols: () -> Symbols) {
        self.renderer = renderer; self.opaque = opaque; self.symbols = symbols()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let syms = Symbols.self == EmptyView.self ? [] : _flatten([_resolve(symbols, ctx.child("sym"))])
        return _CanvasNode(path: ctx.path, renderer: renderer, env: ctx.environment, symbols: syms)
    }
}
extension Canvas where Symbols == EmptyView {
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        self.renderer = renderer; self.opaque = opaque; self.symbols = EmptyView()
    }
}

/// A Canvas; its children are the symbol views, each at its ideal size, mounted in a hidden view of the canvas.
final class _CanvasNode: _Node {
    let renderer: (inout GraphicsContext, CGSize) -> Void, env: EnvironmentValues
    init(path: String, renderer: @escaping (inout GraphicsContext, CGSize) -> Void, env: EnvironmentValues, symbols: [_Node] = []) {
        self.renderer = renderer; self.env = env; super.init(path: path, children: symbols)
        rowAction = nil
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 10, 1e6), height: min(p.height ?? 10, 1e6)) }
    override func place(_ rect: CGRect) {
        frame = rect
        for c in children { c.place(CGRect(origin: .zero, size: c.sizeThatFits(.unspecified))) }
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUICanvasView(frame: .zero) }
        v.renderer = renderer; v.env = env
        v.setNeedsDisplay()
        return v
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        guard let v = view as? _SUICanvasView else { return }
        for (i, c) in children.enumerated() { g.mount(c, in: v.symbolHost, order: i) }
        // the views just mounted are the last ones, in order (a leaving view is never brought to the front)
        let mounted = Array(v.symbolHost.subviews.suffix(children.count))
        var symbols: [AnyHashable: GraphicsContext._Symbol] = [:]
        if mounted.count == children.count {
            for (c, sv) in zip(children, mounted) {
                if let t = _tagged(c) { symbols[t] = GraphicsContext._Symbol(view: sv, size: c.frame.size) }
            }
        }
        v.symbols = symbols
    }
}
final class _SUICanvasView: UIView {
    var renderer: ((inout GraphicsContext, CGSize) -> Void)?
    var env = EnvironmentValues()
    var symbols: [AnyHashable: GraphicsContext._Symbol] = [:]
    /// the symbol views: never shown, drawn into the canvas by resolveSymbol / draw
    let symbolHost = _PassthroughView()
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false
        symbolHost.isHidden = true
        addSubview(symbolHost)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ rect: CGRect) {
        guard let renderer else { return }
        var ctx = GraphicsContext(environment: env, size: bounds.size)
        ctx.symbols = symbols
        isim_gfx_save()
        isim_gfx_clip_rounded(0, 0, bounds.width, bounds.height, 0)
        renderer(&ctx, bounds.size)
        isim_gfx_restore()
    }
}

/// Immediate-mode drawing into a Canvas. Copies are independent (transform, clip, opacity are per value).
public struct GraphicsContext {
    public var opacity: Double = 1
    public var blendMode: BlendMode = .normal
    public var environment: EnvironmentValues
    public var transform: CGAffineTransform = .identity
    var clips: [(Path, Bool)] = []                  // in canvas coordinates
    var filters: [Filter] = []                      // addFilter: applied to each drawing (a group through the host's effects)
    var masks: [_LayerMask] = []                    // clipToLayer: later drawing goes through their alpha
    var symbols: [AnyHashable: _Symbol] = [:]       // the Canvas's symbol views, by tag
    let size: CGSize
    init(environment: EnvironmentValues, size: CGSize) { self.environment = environment; self.size = size }

    public struct BlendMode: RawRepresentable, Equatable, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        public static let normal = BlendMode(rawValue: 0), multiply = BlendMode(rawValue: 1), screen = BlendMode(rawValue: 2), overlay = BlendMode(rawValue: 3)
        public static let darken = BlendMode(rawValue: 4), lighten = BlendMode(rawValue: 5), colorDodge = BlendMode(rawValue: 6), colorBurn = BlendMode(rawValue: 7)
        public static let softLight = BlendMode(rawValue: 8), hardLight = BlendMode(rawValue: 9), difference = BlendMode(rawValue: 10), exclusion = BlendMode(rawValue: 11)
        public static let hue = BlendMode(rawValue: 12), saturation = BlendMode(rawValue: 13), color = BlendMode(rawValue: 14), luminosity = BlendMode(rawValue: 15)
        public static let clear = BlendMode(rawValue: 16), copy = BlendMode(rawValue: 17), sourceIn = BlendMode(rawValue: 18), sourceOut = BlendMode(rawValue: 19)
        public static let sourceAtop = BlendMode(rawValue: 20), destinationOver = BlendMode(rawValue: 21), destinationIn = BlendMode(rawValue: 22), destinationOut = BlendMode(rawValue: 23)
        public static let destinationAtop = BlendMode(rawValue: 24), xor = BlendMode(rawValue: 25), plusDarker = BlendMode(rawValue: 26), plusLighter = BlendMode(rawValue: 27)
    }
    public struct ClipOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let inverse = ClipOptions(rawValue: 1)
    }
    public struct GradientOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let `repeat` = GradientOptions(rawValue: 1), mirror = GradientOptions(rawValue: 2), linearColor = GradientOptions(rawValue: 4)
        var extend: Int { contains(.mirror) ? 3 : contains(.repeat) ? 2 : 1 }
    }
    /// Filters applied to what is drawn after addFilter: each is one pass of isim's host effects (colour matrix, blur,
    /// shadow) on a group of the drawing, in the order they were added. alphaThreshold is two colour-matrix passes
    /// (a steep ramp at each end of the range, then the constant colour where both hold); projectionTransform
    /// transforms the drawing (its affine part). Shaders need Metal and are not provided.
    public struct Filter: @unchecked Sendable {
        let id: Int
        var values: [Double] = []
        var color: Color? = nil
        public static func blur(radius: CGFloat, options: BlurOptions = BlurOptions()) -> Filter { Filter(id: 1, values: [Double(radius), options.contains(.opaque) ? 1 : 0]) }
        public static func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0, blendMode: BlendMode = .normal, options: ShadowOptions = ShadowOptions()) -> Filter {
            Filter(id: 2, values: [Double(radius), Double(x), Double(y)], color: color)
        }
        public static func colorMultiply(_ color: Color) -> Filter { Filter(id: 3, color: color) }
        public static func grayscale(_ amount: Double) -> Filter { Filter(id: 4, values: [amount]) }
        public static func hueRotation(_ angle: Angle) -> Filter { Filter(id: 5, values: [angle.radians]) }
        public static func saturation(_ amount: Double) -> Filter { Filter(id: 6, values: [amount]) }
        public static func brightness(_ amount: Double) -> Filter { Filter(id: 7, values: [amount]) }
        public static func contrast(_ amount: Double) -> Filter { Filter(id: 8, values: [amount]) }
        public static func colorInvert(_ amount: Double = 1) -> Filter { Filter(id: 9, values: [amount]) }
        public static func alphaThreshold(min: Double, max: Double = 1, color: Color = Color.black) -> Filter { Filter(id: 10, values: [min, max], color: color) }
        /// the colour, with its alpha multiplied by each pixel's alpha
        public static func alphaMultiply(_ color: Color) -> Filter { Filter(id: 11, color: color) }
        public static func colorMatrix(_ matrix: ColorMatrix) -> Filter { Filter(id: 12, values: matrix._values) }
        /// isim applies the matrix to unpremultiplied components either way
        public static func colorMatrix(_ matrix: ColorMatrix, isPremultiplied: Bool) -> Filter { Filter(id: 12, values: matrix._values) }
        public static var luminanceToAlpha: Filter { Filter(id: 13) }
        public static func projectionTransform(_ matrix: ProjectionTransform) -> Filter {
            Filter(id: 14, values: [matrix.m11, matrix.m12, matrix.m21, matrix.m22, matrix.m31, matrix.m32].map { Double($0) })
        }
        /// the view effect it is (nil: not one of them)
        func _op(_ env: EnvironmentValues) -> _VFXOp? {
            switch id {
            case 1: return _VFXOp(values[1] != 0 ? .blurOpaque : .blur, [values[0]])
            case 2: return _VFXOp(.shadow, _rgba(color ?? .black, env) + values)
            case 3: return _VFXOp(.colorMultiply, _rgba(color ?? .white, env))
            case 4: return _VFXOp(.grayscale, values)
            case 5: return _VFXOp(.hueRotation, values)
            case 6: return _VFXOp(.saturation, values)
            case 7: return _VFXOp(.brightness, values)
            case 8: return _VFXOp(.contrast, values)
            case 13: return _VFXOp(.luminanceToAlpha)
            default: return nil
            }
        }
        /// the host passes (isim_gfx_pop_group_filtered values), first applied first
        @MainActor func _passes(_ env: EnvironmentValues) -> [[Double]] {
            switch id {
            case 9:                                   // a partial inversion: c' = c (1 - 2k) + k
                let k = Swift.min(1, Swift.max(0, values.first ?? 1))
                return [_matrixSpec([1 - 2 * k, 0, 0, 0, k,  0, 1 - 2 * k, 0, 0, k,  0, 0, 1 - 2 * k, 0, k,  0, 0, 0, 1, 0])]
            case 10:
                let c = _rgba(color ?? .black, env), lo = values[0], hi = values[1], k = 4096.0
                return [_matrixSpec([0, 0, 0, k, 1 - k * lo,  0, 0, 0, -k, k * hi + 1,  0, 0, 0, 0, 0,  0, 0, 0, 0, 1]),
                        _matrixSpec([0, 0, 0, 0, c[0],  0, 0, 0, 0, c[1],  0, 0, 0, 0, c[2],  c[3], c[3], 0, 0, -c[3]])]
            case 11:
                let c = _rgba(color ?? .black, env)
                return [_matrixSpec([0, 0, 0, 0, c[0],  0, 0, 0, 0, c[1],  0, 0, 0, 0, c[2],  0, 0, 0, c[3], 0])]
            case 12: return [_matrixSpec(values)]
            case 14: return []
            default: return _op(env).flatMap { _vfxSpec([$0]) }.map { [$0] } ?? []
            }
        }
        var _projection: CGAffineTransform? {
            id == 14 ? CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5]) : nil
        }
    }
    public struct BlurOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let opaque = BlurOptions(rawValue: 1), dithersResult = BlurOptions(rawValue: 2) }
    public struct ShadowOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let shadowAbove = ShadowOptions(rawValue: 1), shadowOnly = ShadowOptions(rawValue: 2), invertsAlpha = ShadowOptions(rawValue: 4), disablesGroup = ShadowOptions(rawValue: 8) }
    public mutating func addFilter(_ filter: Filter, options: FilterOptions = FilterOptions()) { filters.append(filter) }
    public struct FilterOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let linearColor = FilterOptions(rawValue: 1) }

    /// What paths are filled or stroked with.
    public struct Shading: @unchecked Sendable {
        enum Kind {
            case style(any ShapeStyle)
            case linear(Gradient, CGPoint, CGPoint, GradientOptions)
            case radial(Gradient, CGPoint, CGFloat, CGFloat, GradientOptions)
            case conic(Gradient, CGPoint, Angle, GradientOptions)
            case tiled(Image, CGPoint, CGRect, CGFloat)
        }
        let kind: Kind
        public static var foreground: Shading { Shading(kind: .style(ForegroundStyle())) }
        public static func color(_ color: Color) -> Shading { Shading(kind: .style(color)) }
        public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) -> Shading {
            Shading(kind: .style(Color(red: red, green: green, blue: blue, opacity: opacity)))
        }
        public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) -> Shading { Shading(kind: .style(Color(white: white, opacity: opacity))) }
        public static func style<S: ShapeStyle>(_ style: S) -> Shading { Shading(kind: .style(style)) }
        public static func linearGradient(_ gradient: Gradient, startPoint: CGPoint, endPoint: CGPoint, options: GradientOptions = GradientOptions()) -> Shading {
            Shading(kind: .linear(gradient, startPoint, endPoint, options))
        }
        public static func radialGradient(_ gradient: Gradient, center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, options: GradientOptions = GradientOptions()) -> Shading {
            Shading(kind: .radial(gradient, center, startRadius, endRadius, options))
        }
        public static func conicGradient(_ gradient: Gradient, center: CGPoint, angle: Angle = .zero, options: GradientOptions = GradientOptions()) -> Shading {
            Shading(kind: .conic(gradient, center, angle, options))
        }
        public static func tiledImage(_ image: Image, origin: CGPoint = .zero, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> Shading {
            Shading(kind: .tiled(image, origin, sourceRect, scale))
        }
    }

    // MARK: state
    public var clipBoundingRect: CGRect {
        var r = CGRect(origin: .zero, size: size)
        for (p, _) in clips { r = r.intersection(p.boundingRect) }
        return r.applying(transform.inverted())
    }
    public mutating func scaleBy(x: CGFloat, y: CGFloat) { transform = CGAffineTransform(scaleX: x, y: y).concatenating(transform) }
    public mutating func translateBy(x: CGFloat, y: CGFloat) { transform = CGAffineTransform(translationX: x, y: y).concatenating(transform) }
    public mutating func rotate(by angle: Angle) { transform = CGAffineTransform(rotationAngle: angle.radians).concatenating(transform) }
    public mutating func concatenate(_ matrix: CGAffineTransform) { transform = matrix.concatenating(transform) }
    public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: ClipOptions = ClipOptions()) {
        var p = path.applying(transform)
        var eo = style.isEOFilled
        if options.contains(.inverse) {
            var outer = Path(CGRect(x: -1e5, y: -1e5, width: 2e5, height: 2e5)); outer.addPath(p); p = outer; eo = true
        }
        clips.append((p, eo))
    }
    /// Later drawing shows only where `content` draws (its alpha times `opacity`; `.inverse`: where it does not).
    /// The content is drawn offscreen at the screen's scale, through this context's clips, transform and masks.
    public mutating func clipToLayer(opacity: Double = 1, options: ClipOptions = ClipOptions(), content: (inout GraphicsContext) throws -> Void) rethrows {
        let scale = MainActor.assumeIsolated { max(1, UIScreen.main.scale) }
        guard size.width >= 1, size.height >= 1, isim_gfx_offscreen_begin(size.width, size.height, scale, 0) != 0 else { return }
        var inner = self
        inner.opacity = 1; inner.blendMode = .normal
        isim_gfx_push_group()
        do { try content(&inner) } catch {
            isim_gfx_pop_group(0); isim_gfx_offscreen_end()
            throw error
        }
        let o = Swift.min(1, Swift.max(0, opacity))
        let alpha: [Double] = options.contains(.inverse) ? [0, 0, 0, -o, 1] : [0, 0, 0, o, 0]
        _matrixSpec([0, 0, 0, 0, 1,  0, 0, 0, 0, 1,  0, 0, 0, 0, 1] + alpha).withUnsafeBufferPointer {
            isim_gfx_pop_group_filtered($0.baseAddress, 1, 0, 0, size.width, size.height)
        }
        let hd = isim_gfx_offscreen_snapshot()
        isim_gfx_offscreen_end()
        if hd > 0 { masks.append(_LayerMask(handle: hd)) }
    }
    /// A clipToLayer mask: an image of the canvas's size whose alpha is the mask.
    final class _LayerMask {
        let handle: Int32
        init(handle: Int32) { self.handle = handle }
        deinit { isim_image_free(handle) }
    }

    // MARK: drawing
    /// Runs a drawing with this context's clips, transform and (optionally) a group for opacity.
    /// Groups, outermost first: the blend mode's, one per mask, one per filter pass; the drawing goes in the innermost.
    func _withState(_ body: () -> Void) {
        isim_gfx_save()
        for (p, eo) in clips { _hostPath(p); isim_path_set_fill_rule(eo ? 1 : 0); isim_gfx_clip_path() }
        isim_path_set_fill_rule(0)
        let passes = filters.isEmpty ? [] : MainActor.assumeIsolated { filters.flatMap { $0._passes(environment) } }
        let blend = _hostBlend(blendMode)
        var blendSpec: [Double]? = nil
        if blend != 0 { var v = [Double](repeating: 0, count: 32); v[21] = Double(blend); blendSpec = v }
        if blendSpec != nil { isim_gfx_push_group() }
        for _ in masks { isim_gfx_push_group() }
        for _ in passes { isim_gfx_push_group() }
        var t = transform
        for f in filters { if let p = f._projection { t = t.concatenating(p) } }
        isim_gfx_save()
        isim_gfx_concat(t.a, t.b, t.c, t.d, t.tx, t.ty)
        body()
        isim_path_begin()
        isim_gfx_restore()
        for spec in passes { spec.withUnsafeBufferPointer { isim_gfx_pop_group_filtered($0.baseAddress, 1, 0, 0, size.width, size.height) } }
        for m in masks.reversed() {
            isim_gfx_push_group()
            isim_image_draw(m.handle, 0, 0, size.width, size.height, nil, 1)
            isim_gfx_pop_group_masked(1)
        }
        if let blendSpec { blendSpec.withUnsafeBufferPointer { isim_gfx_pop_group_filtered($0.baseAddress, 1, 0, 0, size.width, size.height) } }
        isim_gfx_restore()
    }
    @MainActor func _paint(_ shading: Shading, bounds: CGRect) -> _Paint {
        switch shading.kind {
        case .style(let s): return _resolvePaint(s, in: bounds, environment)
        case .linear(let g, let a, let b, let o): return .linear(g._stops, a, b, extend: o.extend)
        case .radial(let g, let c, let r0, let r1, let o): return .radial(g._stops, c, r0, r1, matrix: nil, extend: o.extend)
        case .conic(let g, let c, let a, _): return .conic(g._stops, c, a.radians, a.radians + 2 * .pi)
        case .tiled(let img, let origin, let src, let scale):
            guard let u = _uiImage(img, environment) else { return .color(.clear) }
            return .image(u, origin: origin, source: src, scale: scale)
        }
    }
    public func fill(_ path: Path, with shading: Shading, style: FillStyle = FillStyle()) {
        MainActor.assumeIsolated {
            let paint = _paint(shading, bounds: path.boundingRect)
            _withState { _draw(_DrawOp(path: path, paint: paint, stroke: nil, eoFill: style.isEOFilled, alpha: opacity)) }
        }
    }
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {
        MainActor.assumeIsolated {
            let paint = _paint(shading, bounds: path.boundingRect)
            _withState { _draw(_DrawOp(path: path, paint: paint, stroke: style, eoFill: false, alpha: opacity)) }
        }
    }
    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) { stroke(path, with: shading, style: StrokeStyle(lineWidth: lineWidth)) }
    /// Draws into a transparency layer: everything drawn by `content` is composited with this context's opacity.
    public func drawLayer(content: (inout GraphicsContext) throws -> Void) rethrows {
        var inner = self
        inner.opacity = 1
        isim_gfx_save()
        isim_gfx_push_group()
        defer { isim_gfx_pop_group(opacity); isim_gfx_restore() }
        try content(&inner)
    }

    // MARK: text and images
    public struct ResolvedText {
        let string: String, size: CGFloat, weight: Double, mono: Bool, color: UIColor
        var image: UIImage? = nil           // Text(Image(...))
        public var shading: Shading = .foreground
        public func measure(in size: CGSize) -> CGSize {
            if let im = image { return CGSize(width: ceil(im.size.width), height: ceil(im.size.height)) }
            var w = 0.0, h = 0.0
            isim_text_measure(string, Double(self.size), weight, mono ? 1 : 0, size.width.isFinite ? Double(size.width) : 0, 0, &w, &h)
            return CGSize(width: ceil(w), height: ceil(h))
        }
        public func firstBaseline(in size: CGSize) -> CGFloat { self.size * 0.95 }
        public func lastBaseline(in size: CGSize) -> CGFloat { measure(in: size).height - self.size * 0.25 }
    }
    public struct ResolvedImage {
        let image: UIImage?
        public var size: CGSize { image?.size ?? .zero }
        public var baseline: CGFloat { size.height }
        public var shading: Shading?
    }
    public func resolve(_ text: Text) -> ResolvedText {
        MainActor.assumeIsolated {
            var f = text.font ?? environment.font ?? .body
            if let w = text.weight { f.weight = w }
            let color = text.color ?? _styleColor(ForegroundStyle(), environment)
            if let img = text._x.image {
                var e = environment; e.font = f; e._foreground = color
                var r = ResolvedText(string: "", size: f.size, weight: Double(f.weight.value), mono: false, color: color.uiColor)
                r.image = _uiImage(img, e)
                return r
            }
            return ResolvedText(string: text.string, size: f.size, weight: Double(f.weight.value), mono: f.design == .monospaced, color: color.uiColor)
        }
    }
    public func resolve(_ image: Image) -> ResolvedImage { MainActor.assumeIsolated { ResolvedImage(image: _uiImage(image, environment)) } }
    public func draw(_ text: ResolvedText, at point: CGPoint, anchor: UnitPoint = .center) {
        let s = text.measure(in: CGSize(width: CGFloat.infinity, height: .infinity))
        draw(text, in: CGRect(x: point.x - anchor.x * s.width, y: point.y - anchor.y * s.height, width: s.width + 1, height: s.height))
    }
    public func draw(_ text: ResolvedText, in rect: CGRect) {
        if let im = text.image { draw(ResolvedImage(image: im), in: CGRect(x: rect.minX, y: rect.minY, width: im.size.width, height: im.size.height)); return }
        var rgba = MainActor.assumeIsolated { _rgbaOf(text.color) }
        rgba[3] *= opacity
        _withState {
            rgba.withUnsafeBufferPointer { c in
                isim_text_draw(text.string, rect.minX, rect.minY, rect.width, Double(text.size), text.weight, text.mono ? 1 : 0, 0, 0, c.baseAddress)
            }
        }
    }
    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) { draw(resolve(text), at: point, anchor: anchor) }
    public func draw(_ text: Text, in rect: CGRect) { draw(resolve(text), in: rect) }
    public func draw(_ image: ResolvedImage, in rect: CGRect, style: FillStyle = FillStyle()) {
        guard let img = image.image else { return }
        _withState {
            if opacity < 1 { isim_gfx_push_group() }
            img.draw(in: rect)
            if opacity < 1 { isim_gfx_pop_group(opacity) }
        }
    }
    public func draw(_ image: ResolvedImage, at point: CGPoint, anchor: UnitPoint = .center) {
        let s = image.size
        draw(image, in: CGRect(x: point.x - anchor.x * s.width, y: point.y - anchor.y * s.height, width: s.width, height: s.height))
    }
    public func draw(_ image: Image, in rect: CGRect, style: FillStyle = FillStyle()) { draw(resolve(image), in: rect, style: style) }
    public func draw(_ image: Image, at point: CGPoint, anchor: UnitPoint = .center) { draw(resolve(image), at: point, anchor: anchor) }

    /// A view of the Canvas's `symbols`, by its tag: drawn from its view hierarchy at its ideal size (or `rect`).
    struct _Symbol { weak var view: UIView?; let size: CGSize }
    public struct ResolvedSymbol {
        let symbol: _Symbol?
        public var size: CGSize { symbol?.size ?? .zero }
    }
    public func resolveSymbol<ID: Hashable>(id: ID) -> ResolvedSymbol? { symbols[AnyHashable(id)].map { ResolvedSymbol(symbol: $0) } }
    public func draw(_ symbol: ResolvedSymbol, at point: CGPoint, anchor: UnitPoint = .center) {
        let s = symbol.size
        draw(symbol, in: CGRect(x: point.x - anchor.x * s.width, y: point.y - anchor.y * s.height, width: s.width, height: s.height))
    }
    public func draw(_ symbol: ResolvedSymbol, in rect: CGRect) {
        guard let v = symbol.symbol?.view, rect.width > 0, rect.height > 0 else { return }
        MainActor.assumeIsolated {
            _withState {
                if opacity < 1 { isim_gfx_push_group() }
                _ = v.drawHierarchy(in: rect, afterScreenUpdates: false)
                if opacity < 1 { isim_gfx_pop_group(opacity) }
            }
        }
    }
}

// MARK: - TimelineView

public enum TimelineScheduleMode: Hashable, Sendable { case normal, lowFrequency }
public protocol TimelineSchedule {
    associatedtype Entries: Sequence where Entries.Element == Date
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries
}
/// isim: schedules that can answer "current entry" / "next entry" directly.
protocol _DirectSchedule {
    var _animated: Bool { get }
    func _entry(at now: Date, start: Date) -> (current: Date, next: Date?)
}

public struct AnimationTimelineSchedule: TimelineSchedule, _DirectSchedule, Sendable {
    let minimumInterval: Double?, paused: Bool
    public init(minimumInterval: Double? = nil, paused: Bool = false) { self.minimumInterval = minimumInterval; self.paused = paused }
    public func entries(from start: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var d = start; let step = minimumInterval ?? 1.0 / 60
        return AnyIterator { defer { d = d.addingTimeInterval(step) }; return d }
    }
    public typealias Entries = AnyIterator<Date>
    var _animated: Bool { !paused && (minimumInterval ?? 0) < 0.1 }
    func _entry(at now: Date, start: Date) -> (current: Date, next: Date?) {
        if paused { return (now, nil) }
        guard let m = minimumInterval, m > 0 else { return (now, now + 1.0 / 60) }
        let k = (now.timeIntervalSince(start) / m).rounded(.down)
        let cur = start + k * m
        return (cur, cur + m)
    }
}
public struct PeriodicTimelineSchedule: TimelineSchedule, _DirectSchedule, Sendable {
    let start: Date, interval: TimeInterval
    public init(from startDate: Date, by interval: TimeInterval) { start = startDate; self.interval = max(0.001, interval) }
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var d = start; let step = interval
        return AnyIterator { defer { d = d.addingTimeInterval(step) }; return d }
    }
    public typealias Entries = AnyIterator<Date>
    var _animated: Bool { false }
    func _entry(at now: Date, start _: Date) -> (current: Date, next: Date?) {
        if now < start { return (now, start) }
        let k = (now.timeIntervalSince(start) / interval).rounded(.down)
        let cur = start + k * interval
        return (cur, cur + interval)
    }
}
public struct EveryMinuteTimelineSchedule: TimelineSchedule, _DirectSchedule, Sendable {
    public init() {}
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var d = _minute(startDate)
        return AnyIterator { defer { d = d.addingTimeInterval(60) }; return d }
    }
    public typealias Entries = AnyIterator<Date>
    var _animated: Bool { false }
    func _entry(at now: Date, start: Date) -> (current: Date, next: Date?) { let m = _minute(now); return (m, m + 60) }
}
func _minute(_ d: Date) -> Date { Date(timeIntervalSinceReferenceDate: (d.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60) }
public struct ExplicitTimelineSchedule<Entries: Sequence>: TimelineSchedule where Entries.Element == Date {
    let dates: Entries
    public init(_ dates: Entries) { self.dates = dates }
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { dates }
}
extension TimelineSchedule where Self == AnimationTimelineSchedule {
    public static var animation: AnimationTimelineSchedule { AnimationTimelineSchedule() }
    public static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> AnimationTimelineSchedule { AnimationTimelineSchedule(minimumInterval: minimumInterval, paused: paused) }
}
extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    public static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule { PeriodicTimelineSchedule(from: startDate, by: interval) }
}
extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {
    public static var everyMinute: EveryMinuteTimelineSchedule { EveryMinuteTimelineSchedule() }
}
extension TimelineSchedule {
    public static func explicit<S: Sequence>(_ dates: S) -> ExplicitTimelineSchedule<S> where Self == ExplicitTimelineSchedule<S>, S.Element == Date { ExplicitTimelineSchedule(dates) }
}

public struct TimelineViewDefaultContext {
    public enum Cadence: Comparable, Sendable { case live, seconds, minutes }
    public let date: Date
    public let cadence: Cadence
    public func invalidateTimelineContent() {}
}

/// Re-evaluates its content at the dates of a schedule (every frame for `.animation`).
public struct TimelineView<Schedule: TimelineSchedule, Content: View>: View, _PrimitiveView {
    public typealias Context = TimelineViewDefaultContext
    let schedule: Schedule
    let content: (Context) -> Content
    public init(_ schedule: Schedule, @ViewBuilder content: @escaping (Context) -> Content) { self.schedule = schedule; self.content = content }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let key = ctx.path + "#timeline"
        let g = ctx.graph
        g.usedKeys.insert(key)
        let box = (g.storage[key] as? _TimelineBox) ?? { let b = _TimelineBox(); g.storage[key] = b; return b }()
        let now = Date()
        var current = now, next: Date?, cadence = Context.Cadence.seconds
        if let d = schedule as? _DirectSchedule {
            (current, next) = d._entry(at: now, start: box.start)
            cadence = d._animated ? .live : schedule is EveryMinuteTimelineSchedule ? .minutes : .seconds
            if d._animated { _FrameTicker.request(g); next = nil }
        } else {
            var n = 0
            current = box.start
            for d in schedule.entries(from: box.start, mode: .normal) {
                n += 1
                if d > now { next = d; break }
                current = d
                if n > 100_000 { break }
            }
        }
        box.schedule(next, graph: g)
        return _resolve(content(Context(date: current, cadence: cadence)), ctx.child("tl"))
    }
}
final class _TimelineBox {
    let start = Date()
    var timer: Timer?
    var fireDate: Date?
    @MainActor func schedule(_ date: Date?, graph: _Graph) {
        if date == fireDate, timer != nil { return }
        timer?.invalidate(); timer = nil; fireDate = date
        guard let date else { return }
        timer = Timer._isimScheduledTimer(withTimeInterval: max(0.001, date.timeIntervalSinceNow), repeats: false) { [weak self, weak graph] _ in
            MainActor.assumeIsolated { guard let self, self.timer != nil else { return }; self.timer = nil; self.fireDate = nil; graph?.invalidate() }
        }
    }
    deinit { timer?.invalidate() }
}

/// A 4x5 colour matrix for GraphicsContext's colorMatrix filter: rows red, green, blue, alpha; columns the source's
/// red, green, blue, alpha and a bias.
public struct ColorMatrix: Equatable, Sendable {
    public var r1: Float = 1, r2: Float = 0, r3: Float = 0, r4: Float = 0, r5: Float = 0
    public var g1: Float = 0, g2: Float = 1, g3: Float = 0, g4: Float = 0, g5: Float = 0
    public var b1: Float = 0, b2: Float = 0, b3: Float = 1, b4: Float = 0, b5: Float = 0
    public var a1: Float = 0, a2: Float = 0, a3: Float = 0, a4: Float = 1, a5: Float = 0
    public init() {}
    var _values: [Double] { [r1, r2, r3, r4, r5, g1, g2, g3, g4, g5, b1, b2, b3, b4, b5, a1, a2, a3, a4, a5].map { Double($0) } }
}

/// One colour-matrix pass for isim_gfx_pop_group_filtered (20 values, rows R G B A).
func _matrixSpec(_ m: [Double]) -> [Double] {
    var v = [Double](repeating: 0, count: 32)
    for i in 0..<20 { v[i] = m[i] }
    v[29] = 1
    return v
}

/// The host's blend index (isim_gfx_pop_group_filtered) of a GraphicsContext blend mode; 0 (drawn normally) for
/// clear, copy, sourceIn, sourceOut, destinationIn, destinationAtop and xor, which the host does not composite.
func _hostBlend(_ m: GraphicsContext.BlendMode) -> Int {
    switch m.rawValue {
    case 0...15: return Int(m.rawValue)
    case 20: return 16          // sourceAtop
    case 21: return 17          // destinationOver
    case 23: return 18          // destinationOut
    case 26: return 19          // plusDarker
    case 27: return 20          // plusLighter
    default: return 0
    }
}
