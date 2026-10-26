// isim Charts: Chart3D (iOS 26) — 3D points, rules and rectangles (the 3D initializers of PointMark, RuleMark,
// RectangleMark) and surfaces of y = f(x, z) (SurfacePlot), drawn in a Canvas: the data cube is rotated by the pose
// (azimuth, inclination), projected orthographically or with perspective, and painted back to front (adapted: faces are
// shaded by a fixed light; metalness / roughness only change a sphere's highlight). Points can be 3D symbols (sphere,
// cube, cylinder, cone; sized and rotated); the axes show tick labels (chartXAxis / chartYAxis / chartZAxis: hidden, or
// AxisMarks values) and titles (chartX/Y/ZAxisLabel). chart3DPose(binding) makes it rotate with a drag; a tap selects
// the nearest point (chartXSelection / chartYSelection / chartZSelection).
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

// MARK: - Symbols and content modifiers

/// A shape for 3D point marks.
@available(iOS 26.0, *)
public protocol Chart3DSymbolShape {}
@available(iOS 26.0, *)
public struct BasicChart3DSymbolShape: Chart3DSymbolShape, Sendable {
    let kind: _Symbol3D
}
enum _Symbol3D: Sendable { case sphere, cube, cylinder, cone }
@available(iOS 26.0, *)
extension Chart3DSymbolShape where Self == BasicChart3DSymbolShape {
    public static var sphere: BasicChart3DSymbolShape { BasicChart3DSymbolShape(kind: .sphere) }
    public static var cube: BasicChart3DSymbolShape { BasicChart3DSymbolShape(kind: .cube) }
    public static var cylinder: BasicChart3DSymbolShape { BasicChart3DSymbolShape(kind: .cylinder) }
    public static var cone: BasicChart3DSymbolShape { BasicChart3DSymbolShape(kind: .cone) }
}

/// 3D content with modified items (symbol, size, rotation, style, material).
@available(iOS 26.0, *)
public struct _Chart3DModified<C: Chart3DContent>: Chart3DContent, _Chart3DPrimitive {
    let base: C
    let apply: (inout _Item3D) -> Void
    public var body: Never { fatalError() }
    func _items3D() -> [_Item3D] { _resolve3D(base).map { var it = $0; apply(&it); return it } }
}

@available(iOS 26.0, *)
extension Chart3DContent {
    /// The 3D shape of point marks.
    public func symbol<S: Chart3DSymbolShape>(_ symbol: S) -> some Chart3DContent {
        let k = (symbol as? BasicChart3DSymbolShape)?.kind ?? .sphere
        return _Chart3DModified(base: self) { $0.symbol = k }
    }
    /// The size of point marks' symbols (their diameter, points).
    @_disfavoredOverload
    public func symbolSize(_ size: CGFloat) -> some Chart3DContent { _Chart3DModified(base: self) { $0.size = size } }
    /// The rotation of point marks' symbols, about their centre.
    public func symbolRotation(_ rotation: Rotation3D) -> some Chart3DContent { _Chart3DModified(base: self) { $0.rotation = rotation } }
    @_disfavoredOverload
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some Chart3DContent {
        _Chart3DModified(base: self) { it in
            if case .surface(let f, _) = it.kind { it.kind = .surface(f, .shape(AnyShapeStyle(style))) } else { it.style = AnyShapeStyle(style) }
        }
    }
    @_disfavoredOverload
    public func foregroundStyle<S: Chart3DSurfaceStyle>(_ style: S) -> some Chart3DContent {
        let k = (style as? BasicChart3DSurfaceStyle)?.kind ?? .standard
        return _Chart3DModified(base: self) { it in if case .surface(let f, _) = it.kind { it.kind = .surface(f, k) } }
    }
    /// A style per series value (the chart's palette, or chartForegroundStyleScale).
    @_disfavoredOverload
    public func foregroundStyle<D: Plottable>(by value: PlottableValue<D>) -> some Chart3DContent {
        let key = value._pv.category
        return _Chart3DModified(base: self) { $0.styleKey = key }
    }
    /// How metallic the content looks (0 ... 1): a sharper, brighter highlight on spheres.
    public func metalness(_ metalness: Double) -> some Chart3DContent { _Chart3DModified(base: self) { $0.metalness = metalness } }
    /// How rough the content looks (0 ... 1): a wider, dimmer highlight on spheres.
    public func roughness(_ roughness: Double) -> some Chart3DContent { _Chart3DModified(base: self) { $0.roughness = roughness } }
}

/// A resolved 3D item.
struct _Item3D {
    enum Kind { case point([_V3]), rule([_V3]), rect([_V3]), surface((Double, Double) -> Double, _SurfaceStyle) }
    var kind: Kind
    var style: AnyShapeStyle?, styleKey: String?, opacity = 1.0, size: CGFloat?
    var symbol: _Symbol3D?, rotation: Rotation3D?, metalness: Double?, roughness: Double?
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
struct _ChartZAxisVisKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct _ChartZAxisKey: EnvironmentKey { static var defaultValue: _AxisConfigBox? { nil } }
struct _ChartZLabelKey: EnvironmentKey { static var defaultValue: _ViewBox? { nil } }
struct _ZSelKey: EnvironmentKey { static var defaultValue: _SetterBox<_PV?>? { nil } }
struct _ZRangeSelKey: EnvironmentKey { static var defaultValue: _SetterBox<(_PV, _PV)?>? { nil } }
extension EnvironmentValues {
    var _chart3DPose: _PoseBox? { get { self[_Pose3DKey.self] } set { self[_Pose3DKey.self] = newValue } }
    var _chart3DPerspective: Bool { get { self[_Projection3DKey.self] } set { self[_Projection3DKey.self] = newValue } }
    var _chartZScale: _ChartDomain? { get { self[_ChartZScaleKey.self] } set { self[_ChartZScaleKey.self] = newValue } }
    var _chartZAxisVisibility: Visibility { get { self[_ChartZAxisVisKey.self] } set { self[_ChartZAxisVisKey.self] = newValue } }
    var _chartZAxis: _AxisConfigBox? { get { self[_ChartZAxisKey.self] } set { self[_ChartZAxisKey.self] = newValue } }
    var _chartZLabel: _ViewBox? { get { self[_ChartZLabelKey.self] } set { self[_ChartZLabelKey.self] = newValue } }
    var _chartZSelection: _SetterBox<_PV?>? { get { self[_ZSelKey.self] } set { self[_ZSelKey.self] = newValue } }
    var _chartZRangeSelection: _SetterBox<(_PV, _PV)?>? { get { self[_ZRangeSelKey.self] } set { self[_ZRangeSelKey.self] = newValue } }
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
    /// The z scale's range in points (isim: the data cube's depth is fixed; accepted).
    @available(iOS 26.0, *)
    public func chartZScale(range: ClosedRange<CGFloat>, type: ScaleType? = nil) -> some View { self }

    /// Whether a 3D chart shows its z axis (tick labels and title).
    @available(iOS 26.0, *)
    public func chartZAxis(_ visibility: Visibility) -> some View { environment(\._chartZAxisVisibility, visibility) }
    /// The z axis' marks (their values; isim draws each as a tick label).
    @available(iOS 26.0, *)
    public func chartZAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> some View { environment(\._chartZAxis, _AxisConfigBox(_axisSpecs(content()))) }
    /// The z axis title, along the z edge of a 3D chart.
    @available(iOS 26.0, *)
    public func chartZAxisLabel<S: StringProtocol>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartZLabel, _ViewBox(AnyView(Text(String(label))), position, alignment, spacing))
    }
    @available(iOS 26.0, *)
    public func chartZAxisLabel(_ label: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartZLabel, _ViewBox(AnyView(Text(label)), position, alignment, spacing))
    }
    @available(iOS 26.0, *)
    public func chartZAxisLabel(_ label: Text, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartZLabel, _ViewBox(AnyView(label), position, alignment, spacing))
    }
    @available(iOS 26.0, *)
    public func chartZAxisLabel<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View {
        environment(\._chartZLabel, _ViewBox(AnyView(content()), position, alignment, spacing))
    }
    /// The z value of the point a tap selects in a 3D chart (nil: none near the tap).
    @available(iOS 26.0, *)
    public func chartZSelection<P: Plottable>(value: Binding<P?>) -> some View {
        environment(\._chartZSelection, _SetterBox { pv in value.wrappedValue = pv.flatMap { _convert($0, to: P.self, depth: 0) } })
    }
    /// The z range selected in a 3D chart (a tap: the selected point's value).
    @available(iOS 26.0, *)
    public func chartZSelection<P: Plottable & Comparable>(range: Binding<ClosedRange<P>?>) -> some View {
        environment(\._chartZRangeSelection, _SetterBox { r in range.wrappedValue = _rangeOf(r, P.self) })
    }
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
    @Environment(\._chartXAxisVisibility) var xVis
    @Environment(\._chartYAxisVisibility) var yVis
    @Environment(\._chartZAxisVisibility) var zVis
    @Environment(\._chartXAxis) var xAxis
    @Environment(\._chartYAxis) var yAxis
    @Environment(\._chartZAxis) var zAxis
    @Environment(\._chartXLabel) var xLabel
    @Environment(\._chartYLabel) var yLabel
    @Environment(\._chartZLabel) var zLabel
    @Environment(\._chartXSelection) var xSel
    @Environment(\._chartYSelection) var ySel
    @Environment(\._chartZSelection) var zSel
    @Environment(\._chartXRangeSelection) var xRangeSel
    @Environment(\._chartYRangeSelection) var yRangeSel
    @Environment(\._chartZRangeSelection) var zRangeSel
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
        var r = _Chart3DRenderer(items: items, domains: [xScale, yScale, zScale], azimuth: az, inclination: inc, perspective: perspective,
                                 styleScale: styleScale)
        r.visible = [xVis != .hidden, yVis != .hidden, zVis != .hidden]
        r.marks = [xAxis, yAxis, zAxis].map { $0?.specs.first?.values }
        let titles = [xLabel, yLabel, zLabel]
        let setter = pose?.set
        let start = $dragStart
        let selections = (xSel, ySel, zSel), ranges = (xRangeSel, yRangeSel, zRangeSel)
        let selects = xSel != nil || ySel != nil || zSel != nil || xRangeSel != nil || yRangeSel != nil || zRangeSel != nil
        return GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in r.draw(ctx, size) }
                ForEach(0..<3, id: \.self) { a in
                    if let t = titles[a], r.visible[a] {
                        t.view.font(.caption).foregroundStyle(.secondary).fixedSize().position(r.titlePosition(a, geo.size))
                    }
                }
            }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { loc in
                    guard selects else { return }
                    let hit = r.nearestPoint(loc, geo.size)
                    let v = hit.map { [_PV.num($0.0), _PV.num($0.1), _PV.num($0.2)] }
                    selections.0?.set(v?[0]); selections.1?.set(v?[1]); selections.2?.set(v?[2])
                    ranges.0?.set(v.map { ($0[0], $0[0]) }); ranges.1?.set(v.map { ($0[1], $0[1]) }); ranges.2?.set(v.map { ($0[2], $0[2]) })
                }
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
    var visible = [true, true, true]             // chartX/Y/ZAxis(.hidden): no tick labels or title
    var marks: [AxisMarkValues?] = [nil, nil, nil]
    init(items: [_Item3D], domains: [_ChartDomain?], azimuth: Double, inclination: Double, perspective: Bool, styleScale: _StyleScaleBox?) {
        self.items = items; self.domains = domains; self.azimuth = azimuth; self.inclination = inclination
        self.perspective = perspective; self.styleScale = styleScale
    }

    /// The edge each axis' labels sit on (unit cube coordinates, the axis' own coordinate varying).
    static func edge(_ a: Int, _ u: Double) -> (Double, Double, Double) {
        a == 0 ? (u, -0.5, 0.5) : a == 1 ? (-0.5, u, 0.5) : (0.5, -0.5, u)
    }
    func projector(_ size: CGSize) -> ((Double, Double, Double)) -> (CGPoint, Double) {
        let scale = Double(min(size.width, size.height)) / 1.9
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        return { q in
            let r = self.rotate(q)
            let f = self.perspective ? 2.6 / (2.6 - r.2) : 1
            return (CGPoint(x: cx + r.0 * scale * f, y: cy - r.1 * scale * f), r.2)
        }
    }
    /// Where an axis title goes: beyond the middle of its edge, away from the chart's centre.
    func titlePosition(_ a: Int, _ size: CGSize) -> CGPoint {
        let (p, _) = projector(size)(Self.edge(a, 0))
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let dx = Double(p.x) - cx, dy = Double(p.y) - cy, len = max(1, (dx * dx + dy * dy).squareRoot())
        return CGPoint(x: Double(p.x) + dx / len * 44, y: Double(p.y) + dy / len * 44)
    }
    /// The tick values of an axis: AxisMarks' explicit values or stride, else low, middle and high.
    func tickValues(_ a: Int, _ lo: Double, _ hi: Double) -> [Double] {
        switch marks[a]?.kind {
        case .explicit(let vs)?: return vs.compactMap { $0.number }.filter { $0 >= lo - 1e-9 && $0 <= hi + 1e-9 }
        case .stride(let step)? where step > 0:
            var out: [Double] = [], v = (lo / step).rounded(.up) * step
            while v <= hi + 1e-9 && out.count < 50 { out.append(v); v += step }
            return out
        case .automatic(let n?)? where n > 1: return (0..<n).map { lo + (hi - lo) * Double($0) / Double(n - 1) }
        default: return [lo, (lo + hi) / 2, hi]
        }
    }
    typealias V3 = (Double, Double, Double)
    /// A symbol's faces (corners and outward normal) around the origin, h its half size (unit cube units).
    static func solid(_ k: _Symbol3D, _ h: Double) -> [([V3], V3)] {
        switch k {
        case .sphere: return []
        case .cube:
            let c: [V3] = [(-h, -h, -h), (h, -h, -h), (h, h, -h), (-h, h, -h), (-h, -h, h), (h, -h, h), (h, h, h), (-h, h, h)]
            let faces: [([Int], V3)] = [([4, 5, 6, 7], (0, 0, 1)), ([1, 0, 3, 2], (0, 0, -1)), ([5, 1, 2, 6], (1, 0, 0)),
                                        ([0, 4, 7, 3], (-1, 0, 0)), ([7, 6, 2, 3], (0, 1, 0)), ([0, 1, 5, 4], (0, -1, 0))]
            return faces.map { (f, n) in (f.map { c[$0] }, n) }
        case .cylinder, .cone:
            let n = 14, cone = k == .cone
            let ring = (0..<n).map { i -> (Double, Double) in let t = Double(i) / Double(n) * 2 * .pi; return (cos(t) * h, sin(t) * h) }
            var out: [([V3], V3)] = []
            for i in 0..<n {
                let (a, b) = (ring[i], ring[(i + 1) % n])
                let mid = (Double(i) + 0.5) / Double(n) * 2 * .pi
                if cone {
                    let s = 1 / 5.0.squareRoot()          // the side's normal leans up (the cone is as tall as wide)
                    out.append(([(a.0, -h, a.1), (b.0, -h, b.1), (0, h, 0)], (cos(mid) * 2 * s, s, sin(mid) * 2 * s)))
                } else {
                    out.append(([(a.0, -h, a.1), (b.0, -h, b.1), (b.0, h, b.1), (a.0, h, a.1)], (cos(mid), 0, sin(mid))))
                }
            }
            out.append((ring.reversed().map { ($0.0, -h, $0.1) }, (0, -1, 0)))
            if !cone { out.append((ring.map { ($0.0, h, $0.1) }, (0, 1, 0))) }
            return out
        }
    }
    /// A vector turned by a symbol's rotation (Rodrigues' formula).
    static func turn(_ v: V3, _ r: Rotation3D?) -> V3 {
        guard let r, r.angle.radians != 0 else { return v }
        let (kx, ky, kz) = (r.axis.x, r.axis.y, r.axis.z), c = cos(r.angle.radians), s = sin(r.angle.radians)
        let dot = kx * v.0 + ky * v.1 + kz * v.2
        let cx = ky * v.2 - kz * v.1, cy = kz * v.0 - kx * v.2, cz = kx * v.1 - ky * v.0
        return (v.0 * c + cx * s + kx * dot * (1 - c), v.1 * c + cy * s + ky * dot * (1 - c), v.2 * c + cz * s + kz * dot * (1 - c))
    }
    /// The data values of the point mark drawn nearest to a location (within 30 points).
    func nearestPoint(_ loc: CGPoint, _ size: CGSize) -> (Double, Double, Double)? {
        let dom = axisDomains(), project = projector(size)
        func unit(_ v: Double, _ a: Int) -> Double { (v - dom[a].0) / (dom[a].1 - dom[a].0) - 0.5 }
        var best: (Double, (Double, Double, Double))? = nil
        for it in items { if case .point(let v) = it.kind {
            let (p, _) = project((unit(v[0].lo, 0), unit(v[1].lo, 1), unit(v[2].lo, 2)))
            let d = hypot(Double(p.x - loc.x), Double(p.y - loc.y))
            if d < 30 && d < (best?.0 ?? .infinity) { best = (d, (v[0].lo, v[1].lo, v[2].lo)) }
        } }
        return best?.1
    }

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

        enum Prim { case poly([CGPoint], AnyShapeStyle, Double, Double), line(CGPoint, CGPoint, AnyShapeStyle, CGFloat), ball(CGPoint, CGFloat, AnyShapeStyle, Double, Double) }
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
                let c = world(v[0].lo, v[1].lo, v[2].lo)
                let (p, d) = project(c)
                guard let sym = it.symbol, sym != .sphere else {
                    prims.append((d, .ball(p, it.size ?? 8, style(it), it.metalness ?? 0, it.roughness ?? 0.5)))
                    continue
                }
                // a solid: its faces in the data cube around the point, rotated, the ones facing the viewer shaded
                let h = Double(it.size ?? 12) / 2 / scale
                for (face, n) in Self.solid(sym, h) {
                    let rf = face.map { Self.turn($0, it.rotation) }, rn = rotate(Self.turn(n, it.rotation))
                    guard rn.2 > -1e-6 else { continue }
                    let pts = rf.map { project((c.0 + $0.0, c.1 + $0.1, c.2 + $0.2)) }
                    let light = max(0, rn.0 * -0.4 + rn.1 * 0.7 + rn.2 * 0.6) / 1.0296
                    prims.append((pts.map(\.1).reduce(0, +) / Double(pts.count) + 1e-4, .poly(pts.map(\.0), style(it), it.opacity, 0.5 * (1 - light))))
                }
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
        for a in 0..<3 where visible[a] {
            let (lo, hi) = dom[a]
            for v in tickValues(a, lo, hi) {
                let (p, _) = project(Self.edge(a, unit(v, a)))
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
            case .ball(let c, let d, let st, let metal, let rough):
                // a sphere: the colour, darker towards the lower right, and a highlight at the upper left (metal: smaller and
                // brighter, rough: wider and dimmer)
                let r = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
                ctx.fill(Path(ellipseIn: r), with: .style(st))
                if d >= 6 {
                    let hl = CGPoint(x: c.x - d * 0.18, y: c.y - d * 0.2)
                    ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.35)]), center: hl, startRadius: d * 0.2, endRadius: d * 0.75))
                    let spot = d * (0.42 - 0.22 * metal + 0.2 * rough)
                    ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [.white.opacity(0.75 + 0.25 * metal - 0.4 * rough), .clear]), center: hl, startRadius: 0, endRadius: spot))
                }
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
