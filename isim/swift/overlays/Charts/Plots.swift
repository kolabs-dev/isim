// isim Charts: vectorized plots (iOS 18) — one plot for a whole collection (BarPlot, LinePlot, AreaPlot, PointPlot,
// RulePlot, RectanglePlot, SectorPlot) with values projected by key paths (`.value("Name", \.name)`), function plots
// (LinePlot / AreaPlot of y = f(x), parametric LinePlot (x, y) = f(t)) sampled over the x domain, and the key-path
// modifiers (foregroundStyle(by:), symbol(by:), symbolSize(by:), opacity(by:)). They resolve into the same mark records
// as the per-element marks.
import SwiftUI

// MARK: - Projections and dimensions

/// A value of each data element, by key path: `.value("Price", \.price)`.
@available(iOS 18.0, *)
public struct PlottableProjection<Element, Value: Plottable> {
    let label: String
    let get: (Element) -> Value
    let unit: Calendar.Component?
    func pv(_ e: Element) -> _PV { _PV.of(get(e)) }
    @_disfavoredOverload
    public static func value<S: StringProtocol>(_ label: S, _ keyPath: KeyPath<Element, Value>) -> PlottableProjection<Element, Value> {
        PlottableProjection(label: String(label), get: { $0[keyPath: keyPath] }, unit: nil)
    }
    public static func value(_ label: LocalizedStringKey, _ keyPath: KeyPath<Element, Value>) -> PlottableProjection<Element, Value> {
        PlottableProjection(label: "", get: { $0[keyPath: keyPath] }, unit: nil)
    }
    public static func value(_ label: Text, _ keyPath: KeyPath<Element, Value>) -> PlottableProjection<Element, Value> {
        PlottableProjection(label: "", get: { $0[keyPath: keyPath] }, unit: nil)
    }
}
@available(iOS 18.0, *)
extension PlottableProjection where Value == Date {
    /// Dates binned to a calendar unit (bars span the unit).
    @_disfavoredOverload
    public static func value<S: StringProtocol>(_ label: S, _ keyPath: KeyPath<Element, Date>, unit: Calendar.Component,
                                                calendar: Calendar = .current) -> PlottableProjection<Element, Date> {
        PlottableProjection(label: String(label), get: { calendar.dateInterval(of: unit, for: $0[keyPath: keyPath])?.start ?? $0[keyPath: keyPath] }, unit: unit)
    }
    public static func value(_ label: LocalizedStringKey, _ keyPath: KeyPath<Element, Date>, unit: Calendar.Component,
                             calendar: Calendar = .current) -> PlottableProjection<Element, Date> {
        PlottableProjection(label: "", get: { calendar.dateInterval(of: unit, for: $0[keyPath: keyPath])?.start ?? $0[keyPath: keyPath] }, unit: unit)
    }
}

/// The width / height of a vectorized plot's marks: like MarkDimension, or per element by key path.
@available(iOS 18.0, *)
public struct MarkDimensions<Element>: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    let resolve: (Element) -> MarkDimension
    init(_ r: @escaping (Element) -> MarkDimension) { resolve = r }
    public static var automatic: MarkDimensions { MarkDimensions { _ in .automatic } }
    public static func fixed(_ v: CGFloat) -> MarkDimensions { MarkDimensions { _ in .fixed(v) } }
    public static func fixed(_ keyPath: KeyPath<Element, CGFloat>) -> MarkDimensions { MarkDimensions { .fixed($0[keyPath: keyPath]) } }
    public static func ratio(_ v: Double) -> MarkDimensions { MarkDimensions { _ in .ratio(v) } }
    public static func inset(_ v: CGFloat) -> MarkDimensions { MarkDimensions { _ in .inset(v) } }
    public init(floatLiteral value: Double) { resolve = { _ in .fixed(value) } }
    public init(integerLiteral value: Int) { resolve = { _ in .fixed(CGFloat(value)) } }
}

// MARK: - Vectorized content

@available(iOS 18.0, *)
public protocol VectorizedChartContent: ChartContent {
    associatedtype DataElement
}

/// The data and how each element becomes a mark (isim).
@available(iOS 18.0, *)
public struct _VectorizedCore<E> {
    var data: [E]
    var make: (E) -> _Mark?
    var mods: [(E, inout _Mark) -> Void] = []
    func marks() -> [_Mark] {
        data.compactMap { e in
            guard var m = make(e) else { return nil }
            for f in mods { f(e, &m) }
            return m
        }
    }
}
/// A vectorized plot isim resolves from its core.
@available(iOS 18.0, *)
public protocol _VectorizedPlot: VectorizedChartContent {
    var _core: _VectorizedCore<DataElement> { get set }
}
@available(iOS 18.0, *)
extension _VectorizedPlot {
    func _vmod(_ f: @escaping (DataElement, inout _Mark) -> Void) -> Self { var c = self; c._core.mods.append(f); return c }
    /// Colors each element's mark by a value (a series with the default palette or chartForegroundStyleScale).
    public func foregroundStyle<V: Plottable>(by value: PlottableProjection<DataElement, V>) -> Self { _vmod { $1.styleKey = value.pv($0).category } }
    /// Each element's style, by key path.
    public func foregroundStyle<S: ShapeStyle>(by keyPath: KeyPath<DataElement, S>) -> Self { _vmod { $1.style = AnyShapeStyle($0[keyPath: keyPath]) } }
    public func symbol<V: Plottable>(by value: PlottableProjection<DataElement, V>) -> Self { _vmod { $1.symbolKey = value.pv($0).category } }
    public func symbolSize<V: Plottable>(by value: PlottableProjection<DataElement, V>) -> Self { _vmod { $1.symbolSizeValue = value.pv($0).number ?? 0 } }
    public func symbolSize(by keyPath: KeyPath<DataElement, CGFloat>) -> Self { _vmod { $1.symbolSize = $0[keyPath: keyPath] } }
    public func opacity(by keyPath: KeyPath<DataElement, Double>) -> Self { _vmod { $1.opacity *= $0[keyPath: keyPath] } }
    public func position<V: Plottable>(by value: PlottableProjection<DataElement, V>) -> Self { _vmod { $1.positionKey = value.pv($0).category } }
}

// MARK: - Plots

@available(iOS 18.0, *)
public struct BarPlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>,
                                                                        width: MarkDimensions<Content> = .automatic, height: MarkDimensions<Content> = .automatic,
                                                                        stacking: MarkStackingMethod = .standard) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.bar); m.x = x.pv(e); m.y = y.pv(e); m.xUnit = x.unit; m.yUnit = y.unit
            m.width = width.resolve(e); m.height = height.resolve(e); m.stacking = stacking; return m
        }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, yStart: PlottableProjection<Content, Y>,
                                                                        yEnd: PlottableProjection<Content, Y>, width: MarkDimensions<Content> = .automatic) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.bar); m.x = x.pv(e); m.xUnit = x.unit; m.yStart = yStart.pv(e); m.yEnd = yEnd.pv(e); m.width = width.resolve(e); m.stacking = .unstacked; return m
        }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, xStart: PlottableProjection<Content, X>, xEnd: PlottableProjection<Content, X>,
                                                                        y: PlottableProjection<Content, Y>, height: MarkDimensions<Content> = .automatic) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.bar); m.xStart = xStart.pv(e); m.xEnd = xEnd.pv(e); m.y = y.pv(e); m.height = height.resolve(e); m.stacking = .unstacked; return m
        }
    }
}

@available(iOS 18.0, *)
public struct PointPlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>)
        where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.point); m.x = x.pv(e); m.y = y.pv(e); return m }
    }
}

@available(iOS 18.0, *)
public struct RulePlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, X: Plottable>(_ data: Data, x: PlottableProjection<Content, X>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.rule); m.x = x.pv(e); return m }
    }
    public init<Data: RandomAccessCollection, Y: Plottable>(_ data: Data, y: PlottableProjection<Content, Y>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.rule); m.y = y.pv(e); return m }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, yStart: PlottableProjection<Content, Y>,
                                                                        yEnd: PlottableProjection<Content, Y>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.rule); m.x = x.pv(e); m.yStart = yStart.pv(e); m.yEnd = yEnd.pv(e); return m }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, xStart: PlottableProjection<Content, X>, xEnd: PlottableProjection<Content, X>,
                                                                        y: PlottableProjection<Content, Y>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.rule); m.xStart = xStart.pv(e); m.xEnd = xEnd.pv(e); m.y = y.pv(e); return m }
    }
}

@available(iOS 18.0, *)
public struct RectanglePlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>,
                                                                        width: MarkDimensions<Content> = .automatic, height: MarkDimensions<Content> = .automatic)
        where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.rectangle); m.x = x.pv(e); m.y = y.pv(e); m.width = width.resolve(e); m.height = height.resolve(e); return m
        }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, xStart: PlottableProjection<Content, X>, xEnd: PlottableProjection<Content, X>,
                                                                        yStart: PlottableProjection<Content, Y>, yEnd: PlottableProjection<Content, Y>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.rectangle); m.xStart = xStart.pv(e); m.xEnd = xEnd.pv(e); m.yStart = yStart.pv(e); m.yEnd = yEnd.pv(e); return m
        }
    }
}

@available(iOS 18.0, *)
public struct SectorPlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, V: Plottable>(_ data: Data, angle: PlottableProjection<Content, V>, innerRadius: MarkDimensions<Content> = .automatic,
                                                          outerRadius: MarkDimensions<Content> = .automatic, angularInset: CGFloat? = nil) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.sector); m.angle = angle.pv(e).number ?? 0; m.innerRadius = innerRadius.resolve(e); m.outerRadius = outerRadius.resolve(e)
            m.angularInset = angularInset ?? 0; return m
        }
    }
}

/// The content of a LinePlot / AreaPlot of a function (no data elements).
@available(iOS 18.0, *)
public struct FunctionLinePlotContent {}
@available(iOS 18.0, *)
public struct FunctionAreaPlotContent {}

@available(iOS 18.0, *)
public struct LinePlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>)
        where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.line); m.x = x.pv(e); m.y = y.pv(e); return m }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable, S: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>,
                                                                                      series: PlottableProjection<Content, S>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.line); m.x = x.pv(e); m.y = y.pv(e); m.series = series.pv(e).category; return m }
    }
}
@available(iOS 18.0, *)
extension LinePlot where Content == FunctionLinePlotContent {
    init(_function f: _FunctionPlot.Kind, domain: ClosedRange<Double>?) {
        let id = "fn-" + UUID().uuidString
        _core = _VectorizedCore(data: [FunctionLinePlotContent()]) { _ in
            var m = _Mark(.line); m.series = id; m.function = _FunctionPlot(kind: f, domain: domain); return m
        }
    }
    /// y = f(x) over `domain`, or over the chart's x domain.
    @_disfavoredOverload
    public init<S1: StringProtocol, S2: StringProtocol>(x: S1, y: S2, domain: ClosedRange<Double>? = nil, function: @escaping (Double) -> Double) {
        self.init(_function: .y(function), domain: domain)
    }
    public init(x: LocalizedStringKey, y: LocalizedStringKey, domain: ClosedRange<Double>? = nil, function: @escaping (Double) -> Double) {
        self.init(_function: .y(function), domain: domain)
    }
    public init(x: Text, y: Text, domain: ClosedRange<Double>? = nil, function: @escaping (Double) -> Double) {
        self.init(_function: .y(function), domain: domain)
    }
    /// The parametric curve (x, y) = f(t) for t in `domain`.
    @_disfavoredOverload
    public init<S1: StringProtocol, S2: StringProtocol, S3: StringProtocol>(x: S1, y: S2, t: S3, domain: ClosedRange<Double>,
                                                                           function: @escaping (Double) -> (x: Double, y: Double)) {
        self.init(_function: .parametric(function), domain: domain)
    }
    public init(x: LocalizedStringKey, y: LocalizedStringKey, t: LocalizedStringKey, domain: ClosedRange<Double>,
                function: @escaping (Double) -> (x: Double, y: Double)) {
        self.init(_function: .parametric(function), domain: domain)
    }
    public init(x: Text, y: Text, t: Text, domain: ClosedRange<Double>, function: @escaping (Double) -> (x: Double, y: Double)) {
        self.init(_function: .parametric(function), domain: domain)
    }
}

@available(iOS 18.0, *)
public struct AreaPlot<Content>: _VectorizedPlot, _ChartPrimitive {
    public typealias DataElement = Content
    public var _core: _VectorizedCore<Content>
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _core.marks() }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>,
                                                                        stacking: MarkStackingMethod = .standard) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in var m = _Mark(.area); m.x = x.pv(e); m.y = y.pv(e); m.stacking = stacking; return m }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable, S: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, y: PlottableProjection<Content, Y>,
                                                                                      series: PlottableProjection<Content, S>, stacking: MarkStackingMethod = .standard)
        where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.area); m.x = x.pv(e); m.y = y.pv(e); m.series = series.pv(e).category; m.stacking = stacking; return m
        }
    }
    public init<Data: RandomAccessCollection, X: Plottable, Y: Plottable>(_ data: Data, x: PlottableProjection<Content, X>, yStart: PlottableProjection<Content, Y>,
                                                                        yEnd: PlottableProjection<Content, Y>) where Data.Element == Content {
        _core = _VectorizedCore(data: Array(data)) { e in
            var m = _Mark(.area); m.x = x.pv(e); m.yStart = yStart.pv(e); m.yEnd = yEnd.pv(e); m.stacking = .unstacked; return m
        }
    }
}
@available(iOS 18.0, *)
extension AreaPlot where Content == FunctionAreaPlotContent {
    init(_function f: _FunctionPlot.Kind, domain: ClosedRange<Double>?) {
        let id = "fn-" + UUID().uuidString
        _core = _VectorizedCore(data: [FunctionAreaPlotContent()]) { _ in
            var m = _Mark(.area); m.series = id; m.stacking = .unstacked; m.function = _FunctionPlot(kind: f, domain: domain); return m
        }
    }
    /// The area between y = f(x) and zero.
    @_disfavoredOverload
    public init<S1: StringProtocol, S2: StringProtocol>(x: S1, y: S2, domain: ClosedRange<Double>? = nil, function: @escaping (Double) -> Double) {
        self.init(_function: .y(function), domain: domain)
    }
    public init(x: LocalizedStringKey, y: LocalizedStringKey, domain: ClosedRange<Double>? = nil, function: @escaping (Double) -> Double) {
        self.init(_function: .y(function), domain: domain)
    }
    /// The area between two functions of x.
    @_disfavoredOverload
    public init<S1: StringProtocol, S2: StringProtocol, S3: StringProtocol>(x: S1, yStart: S2, yEnd: S3, domain: ClosedRange<Double>? = nil,
                                                                           function: @escaping (Double) -> (yStart: Double, yEnd: Double)) {
        self.init(_function: .range(function), domain: domain)
    }
    public init(x: LocalizedStringKey, yStart: LocalizedStringKey, yEnd: LocalizedStringKey, domain: ClosedRange<Double>? = nil,
                function: @escaping (Double) -> (yStart: Double, yEnd: Double)) {
        self.init(_function: .range(function), domain: domain)
    }
}

// MARK: - Function sampling

/// A function plot, sampled when the chart knows its x domain.
struct _FunctionPlot {
    enum Kind { case y((Double) -> Double), range((Double) -> (yStart: Double, yEnd: Double)), parametric((Double) -> (x: Double, y: Double)) }
    let kind: Kind
    let domain: ClosedRange<Double>?
}

/// Replaces function plots by sampled marks: over the plot's own domain, else chartXScale's range, else the x
/// extent of the other marks (0...1 without any). Non-finite values leave gaps out.
func _expandFunctions(_ marks: [_Mark], xDomain: _ChartDomain?) -> [_Mark] {
    guard marks.contains(where: { $0.function != nil }) else { return marks }
    var chartRange: ClosedRange<Double>?
    if case .range(let a, let b)? = xDomain?.kind, let l = a.number, let u = b.number, u > l { chartRange = l...u }
    let xs = marks.filter { $0.function == nil }.flatMap { [$0.x, $0.xStart, $0.xEnd].compactMap { $0?.number } }
    let dataRange = xs.min().flatMap { lo in xs.max().map { lo...max($0, lo + 1e-9) } }
    var out: [_Mark] = []
    for m in marks {
        guard let f = m.function else { out.append(m); continue }
        let samples = 240
        switch f.kind {
        case .parametric(let fn):
            let d = f.domain ?? 0...1
            for i in 0...samples {
                let t = d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / Double(samples)
                let p = fn(t)
                guard p.x.isFinite, p.y.isFinite else { continue }
                var n = m; n.function = nil; n.x = .num(p.x); n.y = .num(p.y); out.append(n)
            }
        case .y(let fn):
            let d = f.domain ?? chartRange ?? dataRange ?? 0...1
            for i in 0...samples {
                let x = d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / Double(samples), y = fn(x)
                guard y.isFinite else { continue }
                var n = m; n.function = nil; n.x = .num(x); n.y = .num(y); out.append(n)
            }
        case .range(let fn):
            let d = f.domain ?? chartRange ?? dataRange ?? 0...1
            for i in 0...samples {
                let x = d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / Double(samples), r = fn(x)
                guard r.yStart.isFinite, r.yEnd.isFinite else { continue }
                var n = m; n.function = nil; n.x = .num(x); n.yStart = .num(r.yStart); n.yEnd = .num(r.yEnd); out.append(n)
            }
        }
    }
    return out
}

// MARK: - Scroll windows

/// The visible window of a scrollable axis.
struct _ScrollWindow {
    let lo: Double, hi: Double            // the full domain (category axes: 0 ... count)
    let isBand: Bool, isDate: Bool
    let cats: [String]
    let length: Double
    let position: Double                  // the leading value shown (clamped)
    let axis: _AxisScroll

    init?(kind: _Scale.Kind, axis: _AxisScroll, live: Double?) {
        guard let len = axis.length, len > 0 else { return nil }
        self.axis = axis
        switch kind {
        case .band(let c): lo = 0; hi = Double(c.count); isBand = true; isDate = false; cats = c
        case .linear(let a, let b): lo = a; hi = b; isBand = false; isDate = false; cats = []
        case .date(let a, let b): lo = a; hi = b; isBand = false; isDate = true; cats = []
        }
        length = len
        var p = live
        if p == nil, let pv = axis.position?() ?? axis.initial {
            if isBand { p = cats.firstIndex(of: pv.category).map(Double.init) } else { p = pv.number }
        }
        let start = p ?? lo
        position = min(max(start, lo), max(lo, hi - len))
    }
    /// The scale kind of the window (numbers and dates; category axes keep all categories, see scale()).
    var windowKind: _Scale.Kind? {
        if isBand { return nil }
        return isDate ? .date(position, position + length) : .linear(position, position + length)
    }
    /// Category axes: every category keeps its band; the bands are offset so the window fills the plot.
    func scale(_ kind: _Scale.Kind, _ start: CGFloat, _ end: CGFloat) -> _Scale? {
        guard isBand else { return nil }
        let band = (end - start) / CGFloat(length)
        let s = start - CGFloat(position) * band
        return _Scale(kind: kind, start: s, end: s + band * CGFloat(cats.count))
    }
    func unitsPerPoint(_ extent: CGFloat) -> Double { extent > 0 ? length / Double(extent) : 0 }
    func clamp(_ p: Double) -> Double { min(max(p, lo), max(lo, hi - length)) }
    /// Writes a position to the scroll position binding (category axes: the category at the leading edge).
    func publish(_ p: Double) {
        guard let set = axis.setPosition else { return }
        if isBand { if !cats.isEmpty { set(.str(cats[min(cats.count - 1, max(0, Int(p.rounded())))])) } }
        else { set(isDate ? .date(Date(timeIntervalSinceReferenceDate: p)) : .num(p)) }
    }
    /// Where a scroll comes to rest: paging (whole windows), value-aligned (units or matching dates), categories.
    func snap(_ p: Double, _ target: (any ChartScrollTargetBehavior)?) -> Double {
        if target is PagingScrollTargetBehavior { return clamp(lo + ((p - lo) / length).rounded() * length) }
        if let v = target as? ValueAlignedChartScrollTargetBehavior {
            if let u = v.unit, u > 0 { return clamp((p / u).rounded() * u) }
            if let comps = v.matching, isDate {
                let cal = Calendar.current, d = Date(timeIntervalSinceReferenceDate: p)
                let next = cal.nextDate(after: d.addingTimeInterval(-1), matching: comps, matchingPolicy: .nextTime)
                let prev = cal.nextDate(after: d, matching: comps, matchingPolicy: .nextTime, direction: .backward)
                let best = [next, prev].compactMap { $0 }.min { abs($0.timeIntervalSince(d)) < abs($1.timeIntervalSince(d)) }
                return clamp(best?.timeIntervalSinceReferenceDate ?? p)
            }
        }
        return isBand ? clamp(p.rounded()) : p
    }
}
