// isim SwiftUI: Canvas (immediate-mode drawing with GraphicsContext) and TimelineView.
// GraphicsContext draws straight into isim's host renderer: paths filled/stroked with colors, styles and
// gradients, text, images, transforms, opacity, clipping and layers. Filters, blend modes and symbols
// are not drawn (accepted and ignored / nil).
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
    func _makeNode(_ ctx: _Context) -> _Node { _CanvasNode(path: ctx.path, renderer: renderer, env: ctx.environment) }
}
extension Canvas where Symbols == EmptyView {
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        self.renderer = renderer; self.opaque = opaque; self.symbols = EmptyView()
    }
}

final class _CanvasNode: _Node {
    let renderer: (inout GraphicsContext, CGSize) -> Void, env: EnvironmentValues
    init(path: String, renderer: @escaping (inout GraphicsContext, CGSize) -> Void, env: EnvironmentValues) {
        self.renderer = renderer; self.env = env; super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 10, 1e6), height: min(p.height ?? 10, 1e6)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUICanvasView(frame: .zero) }
        v.renderer = renderer; v.env = env
        v.setNeedsDisplay()
        return v
    }
}
final class _SUICanvasView: UIView {
    var renderer: ((inout GraphicsContext, CGSize) -> Void)?
    var env = EnvironmentValues()
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func draw(_ rect: CGRect) {
        guard let renderer else { return }
        var ctx = GraphicsContext(environment: env, size: bounds.size)
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
    /// Filters are accepted and not applied on isim.
    public struct Filter: Sendable {
        let id: Int
        public static func blur(radius: CGFloat, options: BlurOptions = BlurOptions()) -> Filter { Filter(id: 1) }
        public static func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0, blendMode: BlendMode = .normal, options: ShadowOptions = ShadowOptions()) -> Filter { Filter(id: 2) }
        public static func colorMultiply(_ color: Color) -> Filter { Filter(id: 3) }
        public static func grayscale(_ amount: Double) -> Filter { Filter(id: 4) }
        public static func hueRotation(_ angle: Angle) -> Filter { Filter(id: 5) }
        public static func saturation(_ amount: Double) -> Filter { Filter(id: 6) }
        public static func brightness(_ amount: Double) -> Filter { Filter(id: 7) }
        public static func contrast(_ amount: Double) -> Filter { Filter(id: 8) }
        public static func colorInvert(_ amount: Double = 1) -> Filter { Filter(id: 9) }
        public static func alphaThreshold(min: Double, max: Double = 1, color: Color = Color.black) -> Filter { Filter(id: 10) }
    }
    public struct BlurOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let opaque = BlurOptions(rawValue: 1), dithersResult = BlurOptions(rawValue: 2) }
    public struct ShadowOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let shadowAbove = ShadowOptions(rawValue: 1), shadowOnly = ShadowOptions(rawValue: 2), invertsAlpha = ShadowOptions(rawValue: 4), disablesGroup = ShadowOptions(rawValue: 8) }
    public mutating func addFilter(_ filter: Filter, options: FilterOptions = FilterOptions()) {}
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
    public mutating func clipToLayer(opacity: Double = 1, options: ClipOptions = ClipOptions(), content: (inout GraphicsContext) throws -> Void) rethrows {}

    // MARK: drawing
    /// Runs a drawing with this context's clips, transform and (optionally) a group for opacity.
    func _withState(_ body: () -> Void) {
        isim_gfx_save()
        for (p, eo) in clips { _hostPath(p); isim_path_set_fill_rule(eo ? 1 : 0); isim_gfx_clip_path() }
        isim_path_set_fill_rule(0)
        let t = transform
        isim_gfx_concat(t.a, t.b, t.c, t.d, t.tx, t.ty)
        body()
        isim_path_begin()
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

    /// Canvas symbols are not rendered on isim.
    public struct ResolvedSymbol { public var size: CGSize { .zero } }
    public func resolveSymbol<ID: Hashable>(id: ID) -> ResolvedSymbol? { nil }
    public func draw(_ symbol: ResolvedSymbol, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func draw(_ symbol: ResolvedSymbol, in rect: CGRect) {}
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
