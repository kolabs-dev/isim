// isim Charts: Chart3D (iOS 26) — 3D points, rules and rectangles (the 3D initializers of PointMark, RuleMark,
// RectangleMark) and surfaces of y = f(x, z) (SurfacePlot), drawn in a Canvas: the data cube is rotated by the pose
// (azimuth, inclination), projected orthographically or with perspective, and painted back to front (adapted: no
// lighting model beyond a simple shade, no axis labels). chart3DPose(binding) makes it rotate with a drag.
@_exported import Spatial
import SwiftUI

// MARK: - Content

@available(iOS 26.0, *)
@MainActor @preconcurrency
public protocol Chart3DContent {
    /// (isim names it apart from ChartContent.Body: the 3D marks conform to both protocols)
    associatedtype _Body3D: Chart3DContent
    @Chart3DContentBuilder var body: _Body3D { get }
}
@available(iOS 26.0, *)
extension Never: Chart3DContent {}

/// 3D content isim resolves directly.
@MainActor protocol _Chart3DPrimitive { func _items3D() -> [_Item3D] }

@available(iOS 26.0, *)
@MainActor func _resolve3D<C: Chart3DContent>(_ c: C) -> [_Item3D] {
    if let p = c as? _Chart3DPrimitive { return p._items3D() }
    if let m = c as? _ChartPrimitive { return m._marks().compactMap(_Item3D.init(mark:)) }   // 3D marks and their modifiers
    if C._Body3D.self == Never.self { return [] }
    return _resolve3D(c.body)
}

@available(iOS 26.0, *)
@resultBuilder public struct Chart3DContentBuilder {
    public static func buildBlock() -> _Chart3DGroup { _Chart3DGroup(children: []) }
    public static func buildBlock<C: Chart3DContent>(_ content: C) -> C { content }
    public static func buildBlock<each C: Chart3DContent>(_ content: repeat each C) -> _Chart3DGroup {
        var list: [any Chart3DContent] = []
        repeat list.append(each content)
        return _Chart3DGroup(children: list)
    }
    public static func buildExpression<C: Chart3DContent>(_ content: C) -> C { content }
    public static func buildOptional<C: Chart3DContent>(_ content: C?) -> _Chart3DGroup { _Chart3DGroup(children: content.map { [$0] } ?? []) }
    public static func buildEither<C: Chart3DContent>(first: C) -> _Chart3DGroup { _Chart3DGroup(children: [first]) }
    public static func buildEither<C: Chart3DContent>(second: C) -> _Chart3DGroup { _Chart3DGroup(children: [second]) }
    public static func buildArray<C: Chart3DContent>(_ components: [C]) -> _Chart3DGroup { _Chart3DGroup(children: components) }
    public static func buildLimitedAvailability<C: Chart3DContent>(_ content: C) -> _Chart3DGroup { _Chart3DGroup(children: [content]) }
}
/// Several pieces of 3D content.
@available(iOS 26.0, *)
public struct _Chart3DGroup: Chart3DContent, _Chart3DPrimitive {
    let children: [any Chart3DContent]
    public var body: Never { fatalError() }
    func _items3D() -> [_Item3D] { children.flatMap { _resolveAny3D($0) } }
}
@available(iOS 26.0, *)
@MainActor func _resolveAny3D(_ c: any Chart3DContent) -> [_Item3D] { _resolve3D(c) }

// the 3D marks: PointMark / RuleMark / RectangleMark (and their modifiers) are 3D content too
@available(iOS 26.0, *) extension PointMark: Chart3DContent {}
@available(iOS 26.0, *) extension RuleMark: Chart3DContent {}
@available(iOS 26.0, *) extension RectangleMark: Chart3DContent {}
@available(iOS 26.0, *) extension _ChartModified: Chart3DContent where C: Chart3DContent {}

/// Ranges as plottable values (a 3D RuleMark spans one, a 3D RectangleMark two).
@available(iOS 26.0, *)
extension Range: Plottable where Bound: Plottable {
    public var primitivePlottable: Range<Bound> { self }
    public init?(primitivePlottable: Range<Bound>) { self = primitivePlottable }
}
@available(iOS 26.0, *)
extension ClosedRange: Plottable where Bound: Plottable {
    public var primitivePlottable: ClosedRange<Bound> { self }
    public init?(primitivePlottable: ClosedRange<Bound>) { self = primitivePlottable }
}

/// One coordinate of a 3D mark: a value or a range.
enum _V3 { case at(Double), span(Double, Double)
    static func of(_ v: Any) -> _V3? {
        func num(_ x: Any) -> Double? { _PV.of(x).number }
        switch v {
        case let r as Range<Double>: return .span(r.lowerBound, r.upperBound)
        case let r as ClosedRange<Double>: return .span(r.lowerBound, r.upperBound)
        case let r as Range<Int>: return .span(Double(r.lowerBound), Double(r.upperBound))
        case let r as ClosedRange<Int>: return .span(Double(r.lowerBound), Double(r.upperBound))
        case let r as Range<Float>: return .span(Double(r.lowerBound), Double(r.upperBound))
        case let r as ClosedRange<Float>: return .span(Double(r.lowerBound), Double(r.upperBound))
        default: return num(v).map { .at($0) }
        }
    }
    var lo: Double { switch self { case .at(let v): return v; case .span(let a, _): return a } }
    var hi: Double { switch self { case .at(let v): return v; case .span(_, let b): return b } }
    var isSpan: Bool { if case .span = self { return true }; return false }
}

extension PointMark {
    /// A point in a 3D chart.
    @available(iOS 26.0, *)
    public init<X: Plottable, Y: Plottable, Z: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, z: PlottableValue<Z>) {
        mark.v3 = [_V3.of(x.value), _V3.of(y.value), _V3.of(z.value)].compactMap { $0 }
    }
}
extension RuleMark {
    /// A rule in a 3D chart: two coordinates are values, one is a range (`.value("x", -0.5..<0.5)`).
    @available(iOS 26.0, *)
    public init<X: Plottable, Y: Plottable, Z: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, z: PlottableValue<Z>) {
        mark.v3 = [_V3.of(x.value), _V3.of(y.value), _V3.of(z.value)].compactMap { $0 }
    }
}
extension RectangleMark {
    /// A rectangle in a 3D chart: one coordinate is a value, two are ranges.
    @available(iOS 26.0, *)
    public init<X: Plottable, Y: Plottable, Z: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, z: PlottableValue<Z>) {
        mark.v3 = [_V3.of(x.value), _V3.of(y.value), _V3.of(z.value)].compactMap { $0 }
    }
}

/// A surface for y = f(x, z) over the x and z domains.
@available(iOS 26.0, *)
public struct SurfacePlot: Chart3DContent, _Chart3DPrimitive {
    let function: (Double, Double) -> Double
    var style: _SurfaceStyle = .standard
    public var body: Never { fatalError() }
    func _items3D() -> [_Item3D] { [_Item3D(kind: .surface(function, style))] }
    @_disfavoredOverload
    public init<S1: StringProtocol, S2: StringProtocol, S3: StringProtocol>(x: S1, y: S2, z: S3, function: @escaping (Double, Double) -> Double) { self.function = function }
    public init(x: LocalizedStringKey, y: LocalizedStringKey, z: LocalizedStringKey, function: @escaping (Double, Double) -> Double) { self.function = function }
    public init(x: Text, y: Text, z: Text, function: @escaping (Double, Double) -> Double) { self.function = function }
    /// One style for the whole surface (shaded by its slope).
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> SurfacePlot { var c = self; c.style = .shape(AnyShapeStyle(style)); return c }
    /// heightBased / normalBased coloring.
    public func foregroundStyle<S: Chart3DSurfaceStyle>(_ style: S) -> SurfacePlot {
        var c = self; c.style = (style as? BasicChart3DSurfaceStyle)?.kind ?? .standard; return c
    }
}

enum _SurfaceStyle { case standard, heightBased, normalBased, shape(AnyShapeStyle) }
@available(iOS 26.0, *)
public protocol Chart3DSurfaceStyle {}
@available(iOS 26.0, *)
public struct BasicChart3DSurfaceStyle: Chart3DSurfaceStyle {
    let kind: _SurfaceStyle
}
@available(iOS 26.0, *)
extension Chart3DSurfaceStyle where Self == BasicChart3DSurfaceStyle {
    /// Colors by height (y), from blue (low) to red (high).
    public static var heightBased: BasicChart3DSurfaceStyle { BasicChart3DSurfaceStyle(kind: .heightBased) }
    /// Colors by the direction the surface faces.
    public static var normalBased: BasicChart3DSurfaceStyle { BasicChart3DSurfaceStyle(kind: .normalBased) }
}

/// A resolved 3D item.
struct _Item3D {
    enum Kind { case point([_V3]), rule([_V3]), rect([_V3]), surface((Double, Double) -> Double, _SurfaceStyle) }
    var kind: Kind
    var style: AnyShapeStyle?, styleKey: String?, opacity = 1.0, size: CGFloat?
    init(kind: Kind) { self.kind = kind }
    init?(mark m: _Mark) {
        guard let v = m.v3, v.count == 3 else { return nil }
        switch m.kind {
        case .point: kind = .point(v)
        case .rule: kind = .rule(v)
        case .rectangle: kind = .rect(v)
        default: return nil
        }
        style = m.style; styleKey = m.styleKey; opacity = m.opacity; size = m.symbolSize.map { $0.squareRoot() * 1.13 }
    }
}

// MARK: - Pose and projection

@available(iOS 26.0, *)
public struct Chart3DPose: Hashable, Sendable {
    public var azimuth: Angle2D
    public var inclination: Angle2D
    public init(azimuth: Angle2D, inclination: Angle2D) { self.azimuth = azimuth; self.inclination = inclination }
    public static var `default`: Chart3DPose { Chart3DPose(azimuth: .degrees(30), inclination: .degrees(20)) }
    public static var front: Chart3DPose { Chart3DPose(azimuth: .degrees(0), inclination: .degrees(0)) }
    public static var back: Chart3DPose { Chart3DPose(azimuth: .degrees(180), inclination: .degrees(0)) }
    public static var left: Chart3DPose { Chart3DPose(azimuth: .degrees(-90), inclination: .degrees(0)) }
    public static var right: Chart3DPose { Chart3DPose(azimuth: .degrees(90), inclination: .degrees(0)) }
    public static var top: Chart3DPose { Chart3DPose(azimuth: .degrees(0), inclination: .degrees(90)) }
    public static var bottom: Chart3DPose { Chart3DPose(azimuth: .degrees(0), inclination: .degrees(-90)) }
}
@available(iOS 26.0, *)
public struct Chart3DCameraProjection: Hashable, Sendable {
    let perspective: Bool
    public static var automatic: Chart3DCameraProjection { Chart3DCameraProjection(perspective: false) }
    public static var orthographic: Chart3DCameraProjection { Chart3DCameraProjection(perspective: false) }
    public static var perspective: Chart3DCameraProjection { Chart3DCameraProjection(perspective: true) }
}

final class _PoseBox { let get: () -> (Double, Double); let set: ((Double, Double) -> Void)?
    init(_ g: @escaping () -> (Double, Double), _ s: ((Double, Double) -> Void)?) { get = g; set = s } }
struct _Pose3DKey: EnvironmentKey { static var defaultValue: _PoseBox? { nil } }
struct _Projection3DKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _ChartZScaleKey: EnvironmentKey { static var defaultValue: _ChartDomain? { nil } }
extension EnvironmentValues {
    var _chart3DPose: _PoseBox? { get { self[_Pose3DKey.self] } set { self[_Pose3DKey.self] = newValue } }
    var _chart3DPerspective: Bool { get { self[_Projection3DKey.self] } set { self[_Projection3DKey.self] = newValue } }
    var _chartZScale: _ChartDomain? { get { self[_ChartZScaleKey.self] } set { self[_ChartZScaleKey.self] = newValue } }
}

extension View {
    /// The pose of a 3D chart; with a binding, dragging rotates it.
    @available(iOS 26.0, *)
    public func chart3DPose(_ pose: Binding<Chart3DPose>) -> some View {
        environment(\._chart3DPose, _PoseBox({ (pose.wrappedValue.azimuth.radians, pose.wrappedValue.inclination.radians) },
                                             { pose.wrappedValue = Chart3DPose(azimuth: .radians($0), inclination: .radians($1)) }))
    }
    @available(iOS 26.0, *)
    public func chart3DPose(_ pose: Chart3DPose) -> some View {
        environment(\._chart3DPose, _PoseBox({ (pose.azimuth.radians, pose.inclination.radians) }, nil))
    }
    @available(iOS 26.0, *)
    public func chart3DCameraProjection(_ projection: Chart3DCameraProjection) -> some View { environment(\._chart3DPerspective, projection.perspective) }
    /// The z domain of a 3D chart.
    @available(iOS 26.0, *)
    public func chartZScale<D: ScaleDomain>(domain: D, type: ScaleType? = nil) -> some View { environment(\._chartZScale, domain._chartDomain) }
    @available(iOS 26.0, *)
    public func chartZScale<D: ScaleDomain>(domain: D, range: ClosedRange<CGFloat>, type: ScaleType? = nil) -> some View { environment(\._chartZScale, domain._chartDomain) }
}

// MARK: - Chart3D

@available(iOS 26.0, *)
@MainActor @preconcurrency
public struct Chart3D<Content: Chart3DContent>: View {
    let content: Content
    @Environment(\._chartXScale) var xScale
    @Environment(\._chartYScale) var yScale
    @Environment(\._chartZScale) var zScale
    @Environment(\._chart3DPose) var pose
    @Environment(\._chart3DPerspective) var perspective
    @Environment(\._chartStyleScale) var styleScale
    @State private var dragStart: (Double, Double)? = nil

    public init(@Chart3DContentBuilder content: () -> Content) { self.content = content() }
    public init<Data: RandomAccessCollection, C: Chart3DContent>(_ data: Data, @Chart3DContentBuilder content: (Data.Element) -> C)
        where Content == _Chart3DGroup, Data.Element: Identifiable {
        self.content = _Chart3DGroup(children: data.map(content))
    }
    public init<Data: RandomAccessCollection, ID: Hashable, C: Chart3DContent>(_ data: Data, id: KeyPath<Data.Element, ID>,
                                                                             @Chart3DContentBuilder content: (Data.Element) -> C) where Content == _Chart3DGroup {
        self.content = _Chart3DGroup(children: data.map(content))
    }

    public var body: some View {
        let items = _resolve3D(content)
        let (az, inc) = pose?.get() ?? (Chart3DPose.default.azimuth.radians, Chart3DPose.default.inclination.radians)
        let r = _Chart3DRenderer(items: items, domains: [xScale, yScale, zScale], azimuth: az, inclination: inc, perspective: perspective,
                                 styleScale: styleScale)
        let setter = pose?.set
        let start = $dragStart
        return GeometryReader { geo in
            Canvas { ctx, size in r.draw(ctx, size) }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { v in
                    guard let set = setter else { return }
                    let s = start.wrappedValue ?? (az, inc)
                    if start.wrappedValue == nil { start.wrappedValue = s }
                    let na = s.0 + Double(v.translation.width) * .pi / 360
                    let ni = min(.pi / 2, max(-.pi / 2, s.1 + Double(v.translation.height) * .pi / 360))
                    set(na, ni)
                }.onEnded { _ in start.wrappedValue = nil })
        }._isimIdealSize(height: 300)
    }
}

struct _Chart3DRenderer {
    let items: [_Item3D]
    let domains: [_ChartDomain?]                 // x, y, z
    let azimuth: Double, inclination: Double
    let perspective: Bool
    let styleScale: _StyleScaleBox?

    /// The domain of each axis: chartX/Y/ZScale ranges, else the data's extent (surfaces: -1...1 for x and z, their
    /// sampled heights for y).
    func axisDomains() -> [(Double, Double)] {
        var out: [(Double, Double)] = []
        for a in 0..<3 {
            if case .range(let l, let u)? = domains[a]?.kind, let lo = l.number, let hi = u.number, hi > lo { out.append((lo, hi)); continue }
            var vals: [Double] = []
            for it in items {
                switch it.kind {
                case .point(let v), .rule(let v), .rect(let v): vals += [v[a].lo, v[a].hi]
                case .surface: break
                }
            }
            if vals.isEmpty { out.append((-1, 1)) } else {
                let lo = vals.min()!, hi = vals.max()!
                out.append(hi > lo ? (lo, hi) : (lo - 1, hi + 1))
            }
        }
        // y of surfaces: sampled over x and z (unless the y scale is given)
        if case .range? = domains[1]?.kind {} else {
            var ys: [Double] = []
            for it in items { if case .surface(let f, _) = it.kind {
                for i in 0...12 { for j in 0...12 {
                    let x = out[0].0 + (out[0].1 - out[0].0) * Double(i) / 12, z = out[2].0 + (out[2].1 - out[2].0) * Double(j) / 12
                    let y = f(x, z); if y.isFinite { ys.append(y) }
                } }
            } }
            if !ys.isEmpty {
                let pts = items.contains { if case .surface = $0.kind { return false }; return true }
                var lo = ys.min()!, hi = ys.max()!
                if pts { lo = min(lo, out[1].0); hi = max(hi, out[1].1) }
                out[1] = hi > lo ? (lo, hi) : (lo - 1, hi + 1)
            }
        }
        return out
    }

    /// Data -> the unit cube (-0.5 ... 0.5) -> rotated (x right, y up, z towards the viewer).
    func rotate(_ p: (Double, Double, Double)) -> (Double, Double, Double) {
        let (ca, sa, ci, si) = (cos(azimuth), sin(azimuth), cos(inclination), sin(inclination))
        let x1 = p.0 * ca - p.2 * sa, z1 = p.0 * sa + p.2 * ca           // around y (azimuth)
        let y2 = p.1 * ci - z1 * si, z2 = p.1 * si + z1 * ci              // around x (inclination)
        return (x1, y2, z2)
    }

    func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let dom = axisDomains()
        func unit(_ v: Double, _ a: Int) -> Double { (v - dom[a].0) / (dom[a].1 - dom[a].0) - 0.5 }
        let scale = Double(min(size.width, size.height)) / 1.9
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        func project(_ q: (Double, Double, Double)) -> (CGPoint, Double) {
            let r = rotate(q)
            let f = perspective ? 2.6 / (2.6 - r.2) : 1
            return (CGPoint(x: cx + r.0 * scale * f, y: cy - r.1 * scale * f), r.2)
        }
        func world(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) { (unit(x, 0), unit(y, 1), unit(z, 2)) }

        enum Prim { case poly([CGPoint], AnyShapeStyle, Double, Double), line(CGPoint, CGPoint, AnyShapeStyle, CGFloat), dot(CGPoint, CGFloat, AnyShapeStyle) }
        var prims: [(depth: Double, prim: Prim)] = []
        let edge = AnyShapeStyle(Color.gray.opacity(0.45))
        // the data cube's edges
        let corners = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5), (-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)]
        for (a, b) in [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)] {
            let (pa, da) = project(corners[a]), (pb, db) = project(corners[b])
            prims.append((min(da, db) - 1, .line(pa, pb, edge, 0.5)))
        }
        var keys: [String] = []
        for it in items { if let k = it.styleKey, !keys.contains(k) { keys.append(k) } }
        func style(_ it: _Item3D) -> AnyShapeStyle {
            if let s = it.style { return s }
            if let k = it.styleKey, let i = keys.firstIndex(of: k) {
                if let sc = styleScale, let ks = sc.keys, let j = ks.firstIndex(of: k), j < sc.styles.count { return sc.styles[j] }
                return AnyShapeStyle(_chartPalette[i % _chartPalette.count])
            }
            return AnyShapeStyle(Color.accentColor)
        }
        for it in items {
            switch it.kind {
            case .point(let v):
                let (p, d) = project(world(v[0].lo, v[1].lo, v[2].lo))
                prims.append((d, .dot(p, it.size ?? 8, style(it))))
            case .rule(let v):
                let (a, da) = project(world(v[0].lo, v[1].lo, v[2].lo)), (b, db) = project(world(v[0].hi, v[1].hi, v[2].hi))
                prims.append(((da + db) / 2, .line(a, b, style(it), 2)))
            case .rect(let v):
                // one fixed coordinate, two ranges: the four corners in that plane
                let spans = (0..<3).filter { v[$0].isSpan }
                guard spans.count == 2 else { continue }
                let (s0, s1) = (spans[0], spans[1])
                var pts: [CGPoint] = [], depth = 0.0
                for (u, w) in [(0, 0), (1, 0), (1, 1), (0, 1)] {
                    var c = [v[0].lo, v[1].lo, v[2].lo]
                    c[s0] = u == 0 ? v[s0].lo : v[s0].hi; c[s1] = w == 0 ? v[s1].lo : v[s1].hi
                    let (p, d) = project(world(c[0], c[1], c[2])); pts.append(p); depth += d / 4
                }
                prims.append((depth, .poly(pts, style(it), it.opacity, 0)))
            case .surface(let f, let sstyle):
                let n = 28
                var grid = [[(Double, Double, Double)?]](repeating: [(Double, Double, Double)?](repeating: nil, count: n + 1), count: n + 1)
                for i in 0...n { for j in 0...n {
                    let x = dom[0].0 + (dom[0].1 - dom[0].0) * Double(i) / Double(n), z = dom[2].0 + (dom[2].1 - dom[2].0) * Double(j) / Double(n)
                    let y = f(x, z)
                    if y.isFinite { grid[i][j] = world(x, min(max(y, dom[1].0), dom[1].1), z) }
                } }
                for i in 0..<n { for j in 0..<n {
                    guard let a = grid[i][j], let b = grid[i + 1][j], let c = grid[i + 1][j + 1], let d = grid[i][j + 1] else { continue }
                    let q = [a, b, c, d].map(project)
                    // the quad's normal (data cube space) for shading and normalBased colors
                    let u = (c.0 - a.0, c.1 - a.1, c.2 - a.2), w = (d.0 - b.0, d.1 - b.1, d.2 - b.2)
                    var nx = u.1 * w.2 - u.2 * w.1, ny = u.2 * w.0 - u.0 * w.2, nz = u.0 * w.1 - u.1 * w.0
                    let len = (nx * nx + ny * ny + nz * nz).squareRoot()
                    if len > 0 { nx /= len; ny /= len; nz /= len }
                    if ny < 0 { nx = -nx; ny = -ny; nz = -nz }
                    let shade = 0.35 * (1 - abs(ny))                              // flat faces light, steep ones darker
                    let h = ((a.1 + b.1 + c.1 + d.1) / 4) + 0.5                    // 0 ... 1
                    let st: AnyShapeStyle
                    switch sstyle {
                    case .heightBased: st = AnyShapeStyle(Color(hue: 0.66 * (1 - min(1, max(0, h))), saturation: 0.85, brightness: 0.95))
                    case .normalBased: st = AnyShapeStyle(Color(red: (nx + 1) / 2, green: (ny + 1) / 2, blue: (nz + 1) / 2))
                    case .shape(let s): st = s
                    case .standard: st = AnyShapeStyle(Color.accentColor)
                    }
                    prims.append((q.map(\.1).reduce(0, +) / 4, .poly(q.map(\.0), st, 1, sstyle.isColorMap ? 0 : shade)))
                } }
            }
        }
        // tick labels: low, middle and high value of each axis along three front edges, pushed outwards
        var labels: [(String, CGPoint)] = []
        let edges: [(Int, (Double) -> (Double, Double, Double))] = [(0, { (unit($0, 0), -0.5, 0.5) }), (1, { (-0.5, unit($0, 1), 0.5) }), (2, { (0.5, -0.5, unit($0, 2)) })]
        for (a, at) in edges {
            let (lo, hi) = dom[a]
            for v in [lo, (lo + hi) / 2, hi] {
                let (p, _) = project(at(v))
                let dx = Double(p.x) - cx, dy = Double(p.y) - cy, len = max(1, (dx * dx + dy * dy).squareRoot())
                labels.append((_ChartFormat.number3D(v, step: (hi - lo) / 2), CGPoint(x: Double(p.x) + dx / len * 12, y: Double(p.y) + dy / len * 12)))
            }
        }
        // back to front
        for (_, p) in prims.sorted(by: { $0.depth < $1.depth }) {
            switch p {
            case .poly(let pts, let st, let op, let shade):
                var path = Path(); path.addLines(pts); path.closeSubpath()
                var c = ctx; c.opacity = op
                c.fill(path, with: .style(st))
                if shade > 0 { c.fill(path, with: .color(.black.opacity(shade))) }
                if op >= 1 {                    // close the hairline seams between neighbouring quads
                    c.stroke(path, with: .style(st), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
                    if shade > 0 { c.stroke(path, with: .color(.black.opacity(shade)), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round)) }
                }
            case .line(let a, let b, let st, let w):
                var path = Path(); path.move(to: a); path.addLine(to: b)
                ctx.stroke(path, with: .style(st), style: StrokeStyle(lineWidth: w, lineCap: .round))
            case .dot(let c, let d, let st):
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)), with: .style(st))
            }
        }
        for (s, p) in labels { ctx.draw(ctx.resolve(Text(s).font(.system(size: 9)).foregroundColor(.gray)), at: p) }
    }
}

extension _ChartFormat {
    nonisolated static func number3D(_ v: Double, step: Double) -> String {
        if abs(v) < 1e-9 { return "0" }
        if step >= 1 && v == v.rounded() { return String(Int(v)) }
        var s = String(format: "%.2f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s
    }
}

extension _SurfaceStyle {
    var isColorMap: Bool { switch self { case .heightBased, .normalBased: return true; default: return false } }
}
