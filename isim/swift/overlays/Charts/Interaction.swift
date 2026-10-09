// isim Charts: what reads or drives a laid-out chart — ChartProxy (positions <-> values in the plot area) for
// chartOverlay / chartBackground / chartGesture, selection (chartXSelection / chartYSelection / chartAngleSelection:
// the plot follows a finger), scrolling (chartScrollableAxes with a visible domain, scroll position, value-aligned or
// paging targets) and chartPlotStyle (the plot area as a view). Configuration reaches Chart through the environment.
import SwiftUI

// MARK: - ChartProxy

/// The laid-out chart: converts between data values and positions in the plot area (whose origin is
/// `plotFrame`'s origin), and selects values like the built-in selection gesture.
public struct ChartProxy {
    let plot: CGRect                     // in the chart's coordinate space (that of chartOverlay / chartBackground)
    let xs: _Scale, ys: _Scale
    let selection: _SelectionSetters
    let angleAt: ((CGPoint) -> Double?)?

    /// The plot area in the chart's coordinate space: `geometry[proxy.plotFrame!]` in an overlay's GeometryReader.
    public var plotFrame: Anchor<CGRect>? { Anchor(_isimValue: plot) }
    @available(iOS, deprecated: 17.0, renamed: "plotFrame")
    public var plotAreaFrame: Anchor<CGRect> { Anchor(_isimValue: plot) }
    /// The chart area around the plot (the whole chart on isim).
    public var plotContainerFrame: Anchor<CGRect>? { Anchor(_isimValue: plot) }
    public var plotSize: CGSize { plot.size }
    @available(iOS, deprecated: 17.0, renamed: "plotSize")
    public var plotAreaSize: CGSize { plot.size }

    public func position<P: Plottable>(forX value: P) -> CGFloat? { xs.pos(_PV.of(value)).map { $0 - plot.minX } }
    public func position<P: Plottable>(forY value: P) -> CGFloat? { ys.pos(_PV.of(value)).map { $0 - plot.minY } }
    public func position<X: Plottable, Y: Plottable>(for value: (x: X, y: Y)) -> CGPoint? {
        guard let x = position(forX: value.x), let y = position(forY: value.y) else { return nil }
        return CGPoint(x: x, y: y)
    }
    /// The extent of a value along x: a category's band, a single position for numbers and dates.
    public func positionRange<P: Plottable>(forX value: P) -> ClosedRange<CGFloat>? { range(xs, _PV.of(value), plot.minX) }
    public func positionRange<P: Plottable>(forY value: P) -> ClosedRange<CGFloat>? { range(ys, _PV.of(value), plot.minY) }
    func range(_ s: _Scale, _ v: _PV, _ origin: CGFloat) -> ClosedRange<CGFloat>? {
        guard let c = s.pos(v) else { return nil }
        let half = s.isBand ? abs(s.bandWidth) / 2 : 0
        return (c - half - origin)...(c + half - origin)
    }
    public func value<P: Plottable>(atX position: CGFloat, as type: P.Type = P.self) -> P? {
        xs.value(at: position + plot.minX).flatMap { _convert($0, to: P.self, depth: 0) }
    }
    public func value<P: Plottable>(atY position: CGFloat, as type: P.Type = P.self) -> P? {
        ys.value(at: position + plot.minY).flatMap { _convert($0, to: P.self, depth: 0) }
    }
    public func value<X: Plottable, Y: Plottable>(at position: CGPoint, as type: (X, Y).Type = (X, Y).self) -> (X, Y)? {
        guard let x: X = value(atX: position.x), let y: Y = value(atY: position.y) else { return nil }
        return (x, y)
    }
    /// The x domain shown (its first and last values).
    public func xDomain<P: Plottable>(dataType: P.Type = P.self) -> [P] { domainValues(xs) }
    public func yDomain<P: Plottable>(dataType: P.Type = P.self) -> [P] { domainValues(ys) }
    func domainValues<P: Plottable>(_ s: _Scale) -> [P] {
        switch s.kind {
        case .band(let c): return c.compactMap { _convert(.str($0), to: P.self, depth: 0) }
        case .linear(let a, let b): return [a, b].compactMap { _convert(.num($0), to: P.self, depth: 0) }
        case .date(let a, let b): return [a, b].compactMap { _convert(.date(Date(timeIntervalSinceReferenceDate: $0)), to: P.self, depth: 0) }
        }
    }

    // selection, as the chart's own gesture does it (positions in the plot area)
    public func selectXValue(at position: CGFloat) { selection.x?(xs.value(at: position + plot.minX)) }
    public func selectYValue(at position: CGFloat) { selection.y?(ys.value(at: position + plot.minY)) }
    public func selectXRange(from start: CGFloat, to end: CGFloat) {
        guard let a = xs.value(at: start + plot.minX), let b = xs.value(at: end + plot.minX) else { return }
        selection.xRange?((a, b))
    }
    public func selectYRange(from start: CGFloat, to end: CGFloat) {
        guard let a = ys.value(at: start + plot.minY), let b = ys.value(at: end + plot.minY) else { return }
        selection.yRange?((a, b))
    }
    public func selectAngleValue(at position: CGPoint) {
        selection.angle?(angleAt?(CGPoint(x: position.x + plot.minX, y: position.y + plot.minY)))
    }
}

extension _Scale {
    /// The value at a screen position (the category whose band contains it, or the continuous value).
    func value(at p: CGFloat) -> _PV? {
        switch kind {
        case .band(let c):
            guard !c.isEmpty, end != start else { return nil }
            let i = Int(floor((p - start) / ((end - start) / CGFloat(c.count))))
            return .str(c[min(c.count - 1, max(0, i))])
        case .linear(let lo, let hi):
            return .num(end == start ? lo : lo + Double((p - start) / (end - start)) * (hi - lo))
        case .date(let lo, let hi):
            return .date(Date(timeIntervalSinceReferenceDate: end == start ? lo : lo + Double((p - start) / (end - start)) * (hi - lo)))
        }
    }
}

// MARK: - Selection

/// Setters of the selection bindings (nil clears).
struct _SelectionSetters {
    var x: ((_PV?) -> Void)?, y: ((_PV?) -> Void)?
    var xRange: (((_PV, _PV)?) -> Void)?, yRange: (((_PV, _PV)?) -> Void)?
    var angle: ((Double?) -> Void)?
    var any: Bool { x != nil || y != nil || xRange != nil || yRange != nil || angle != nil }
}
final class _SetterBox<T> { let set: (T) -> Void; init(_ s: @escaping (T) -> Void) { set = s } }
struct _XSelKey: EnvironmentKey { static var defaultValue: _SetterBox<_PV?>? { nil } }
struct _YSelKey: EnvironmentKey { static var defaultValue: _SetterBox<_PV?>? { nil } }
struct _XRangeSelKey: EnvironmentKey { static var defaultValue: _SetterBox<(_PV, _PV)?>? { nil } }
struct _YRangeSelKey: EnvironmentKey { static var defaultValue: _SetterBox<(_PV, _PV)?>? { nil } }
struct _AngleSelKey: EnvironmentKey { static var defaultValue: _SetterBox<Double?>? { nil } }

func _rangeOf<P: Plottable & Comparable>(_ r: (_PV, _PV)?, _ type: P.Type) -> ClosedRange<P>? {
    guard let r, let a = _convert(r.0, to: P.self, depth: 0), let b = _convert(r.1, to: P.self, depth: 0) else { return nil }
    return min(a, b)...max(a, b)
}

// MARK: - Scrolling

/// Where a scroll comes to rest.
public protocol ChartScrollTargetBehavior {}
extension PagingScrollTargetBehavior: ChartScrollTargetBehavior {}
public struct ValueAlignedChartScrollTargetBehavior: ChartScrollTargetBehavior {
    /// Major alignment: whole pages, multiples of a unit, or matching date components.
    public struct MajorValueAlignment {
        enum Kind { case page, unit(Double), matching(DateComponents) }
        let kind: Kind
        public static var page: MajorValueAlignment { MajorValueAlignment(kind: .page) }
        public static func unit<P: Plottable>(_ value: P) -> MajorValueAlignment { MajorValueAlignment(kind: .unit(_PV.of(value).number ?? 1)) }
        public static func matching(_ components: DateComponents) -> MajorValueAlignment { MajorValueAlignment(kind: .matching(components)) }
    }
    let unit: Double?, matching: DateComponents?, major: MajorValueAlignment?
}
extension ChartScrollTargetBehavior where Self == ValueAlignedChartScrollTargetBehavior {
    public static func valueAligned<P: Plottable>(unit: P, majorAlignment: ValueAlignedChartScrollTargetBehavior.MajorValueAlignment? = nil) -> ValueAlignedChartScrollTargetBehavior {
        ValueAlignedChartScrollTargetBehavior(unit: _PV.of(unit).number ?? 1, matching: nil, major: majorAlignment)
    }
    public static func valueAligned(matching: DateComponents, majorAlignment: ValueAlignedChartScrollTargetBehavior.MajorValueAlignment? = nil) -> ValueAlignedChartScrollTargetBehavior {
        ValueAlignedChartScrollTargetBehavior(unit: nil, matching: matching, major: majorAlignment)
    }
}

/// The scroll configuration of one axis.
struct _AxisScroll {
    var length: Double?                       // visible length (numbers, seconds, or categories)
    var position: (() -> _PV?)?, setPosition: ((_PV) -> Void)?
    var initial: _PV?
}
final class _ScrollBox {
    var axes: Axis.Set = []
    var x = _AxisScroll(), y = _AxisScroll()
    var target: (any ChartScrollTargetBehavior)?
    func copy() -> _ScrollBox { let b = _ScrollBox(); b.axes = axes; b.x = x; b.y = y; b.target = target; return b }
}
struct _ScrollKey: EnvironmentKey { static var defaultValue: _ScrollBox? { nil } }

// MARK: - Overlay, background, plot style, gesture

final class _ProxyViewBox { let alignment: Alignment; let make: (ChartProxy) -> AnyView; init(_ a: Alignment, _ m: @escaping (ChartProxy) -> AnyView) { alignment = a; make = m } }
struct _OverlayKey: EnvironmentKey { static var defaultValue: _ProxyViewBox? { nil } }
struct _BackgroundKey: EnvironmentKey { static var defaultValue: _ProxyViewBox? { nil } }
struct _GestureKey: EnvironmentKey { static var defaultValue: _ProxyViewBox? { nil } }
final class _PlotStyleBox { let make: (ChartPlotContent) -> AnyView; init(_ m: @escaping (ChartPlotContent) -> AnyView) { make = m } }
struct _PlotStyleKey: EnvironmentKey { static var defaultValue: _PlotStyleBox? { nil } }

/// The plot area, as chartPlotStyle's content: modifiers such as background, border or overlay decorate it.
public struct ChartPlotContent: View {
    public var body: some View { Color.clear }
}

extension EnvironmentValues {
    var _chartXSelection: _SetterBox<_PV?>? { get { self[_XSelKey.self] } set { self[_XSelKey.self] = newValue } }
    var _chartYSelection: _SetterBox<_PV?>? { get { self[_YSelKey.self] } set { self[_YSelKey.self] = newValue } }
    var _chartXRangeSelection: _SetterBox<(_PV, _PV)?>? { get { self[_XRangeSelKey.self] } set { self[_XRangeSelKey.self] = newValue } }
    var _chartYRangeSelection: _SetterBox<(_PV, _PV)?>? { get { self[_YRangeSelKey.self] } set { self[_YRangeSelKey.self] = newValue } }
    var _chartAngleSelection: _SetterBox<Double?>? { get { self[_AngleSelKey.self] } set { self[_AngleSelKey.self] = newValue } }
    var _chartScroll: _ScrollBox? { get { self[_ScrollKey.self] } set { self[_ScrollKey.self] = newValue } }
    var _chartOverlay: _ProxyViewBox? { get { self[_OverlayKey.self] } set { self[_OverlayKey.self] = newValue } }
    var _chartBackground: _ProxyViewBox? { get { self[_BackgroundKey.self] } set { self[_BackgroundKey.self] = newValue } }
    var _chartGesture: _ProxyViewBox? { get { self[_GestureKey.self] } set { self[_GestureKey.self] = newValue } }
    var _chartPlotStyle: _PlotStyleBox? { get { self[_PlotStyleKey.self] } set { self[_PlotStyleKey.self] = newValue } }
}

extension View {
    /// A view over the chart, with a proxy to convert positions and values.
    public func chartOverlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: @escaping (ChartProxy) -> V) -> some View {
        environment(\._chartOverlay, _ProxyViewBox(alignment) { AnyView(content($0)) })
    }
    /// A view behind the chart, with a proxy to convert positions and values.
    public func chartBackground<V: View>(alignment: Alignment = .center, @ViewBuilder content: @escaping (ChartProxy) -> V) -> some View {
        environment(\._chartBackground, _ProxyViewBox(alignment) { AnyView(content($0)) })
    }
    /// The plot area as a view (background, border, overlay ...). Size changes of the plot area are not applied on isim.
    public func chartPlotStyle<V: View>(@ViewBuilder content: @escaping (ChartPlotContent) -> V) -> some View {
        environment(\._chartPlotStyle, _PlotStyleBox { AnyView(content($0)) })
    }
    /// A gesture on the plot area instead of the built-in selection gesture (use the proxy's select... functions).
    public func chartGesture<G: Gesture>(_ gesture: @escaping (ChartProxy) -> G) -> some View {
        environment(\._chartGesture, _ProxyViewBox(.center) { AnyView(Color.clear.contentShape(Rectangle()).gesture(gesture($0))) })
    }

    // selection: set while a finger is on the plot, nil when it lifts
    public func chartXSelection<P: Plottable>(value: Binding<P?>) -> some View {
        environment(\._chartXSelection, _SetterBox { pv in value.wrappedValue = pv.flatMap { _convert($0, to: P.self, depth: 0) } })
    }
    public func chartYSelection<P: Plottable>(value: Binding<P?>) -> some View {
        environment(\._chartYSelection, _SetterBox { pv in value.wrappedValue = pv.flatMap { _convert($0, to: P.self, depth: 0) } })
    }
    /// A range selected by dragging across the plot (it stays when the finger lifts).
    public func chartXSelection<P: Plottable & Comparable>(range: Binding<ClosedRange<P>?>) -> some View {
        environment(\._chartXRangeSelection, _SetterBox { r in range.wrappedValue = _rangeOf(r, P.self) })
    }
    public func chartYSelection<P: Plottable & Comparable>(range: Binding<ClosedRange<P>?>) -> some View {
        environment(\._chartYRangeSelection, _SetterBox { r in range.wrappedValue = _rangeOf(r, P.self) })
    }
    /// The value whose pie / donut sector is under the finger (as a cumulative value from 12 o'clock).
    public func chartAngleSelection<P: Plottable>(value: Binding<P?>) -> some View {
        environment(\._chartAngleSelection, _SetterBox { a in value.wrappedValue = a.flatMap { _convert(.num($0), to: P.self, depth: 0) } })
    }

    // scrolling
    public func chartScrollableAxes(_ axes: Axis.Set) -> some View {
        transformEnvironment(\._chartScroll) { b in let n = (b ?? _ScrollBox()).copy(); n.axes = axes; b = n }
    }
    /// How much of the x domain the plot shows (a length in data units: numbers, seconds, or a count of categories).
    public func chartXVisibleDomain<P: Plottable>(length: P) -> some View {
        let len = _PV.of(length).number ?? 1
        return transformEnvironment(\._chartScroll) { b in let n = (b ?? _ScrollBox()).copy(); n.x.length = len; b = n }
    }
    public func chartYVisibleDomain<P: Plottable>(length: P) -> some View {
        let len = _PV.of(length).number ?? 1
        return transformEnvironment(\._chartScroll) { b in let n = (b ?? _ScrollBox()).copy(); n.y.length = len; b = n }
    }
    /// The x value at the leading edge of the plot, read and written as the chart scrolls.
    public func chartScrollPosition<P: Plottable>(x: Binding<P>) -> some View {
        transformEnvironment(\._chartScroll) { b in
            let n = (b ?? _ScrollBox()).copy()
            n.x.position = { _PV.of(x.wrappedValue) }
            n.x.setPosition = { pv in if let v = _convert(pv, to: P.self, depth: 0) { x.wrappedValue = v } }
            b = n
        }
    }
    public func chartScrollPosition<P: Plottable>(y: Binding<P>) -> some View {
        transformEnvironment(\._chartScroll) { b in
            let n = (b ?? _ScrollBox()).copy()
            n.y.position = { _PV.of(y.wrappedValue) }
            n.y.setPosition = { pv in if let v = _convert(pv, to: P.self, depth: 0) { y.wrappedValue = v } }
            b = n
        }
    }
    public func chartScrollPosition<P: Plottable>(initialX: P) -> some View {
        let pv = _PV.of(initialX)
        return transformEnvironment(\._chartScroll) { b in let n = (b ?? _ScrollBox()).copy(); n.x.initial = pv; b = n }
    }
    public func chartScrollPosition<P: Plottable>(initialY: P) -> some View {
        let pv = _PV.of(initialY)
        return transformEnvironment(\._chartScroll) { b in let n = (b ?? _ScrollBox()).copy(); n.y.initial = pv; b = n }
    }
    public func chartScrollTargetBehavior(_ behavior: some ChartScrollTargetBehavior) -> some View {
        transformEnvironment(\._chartScroll) { b in let n = (b ?? _ScrollBox()).copy(); n.target = behavior; b = n }
    }
}
