// isim Charts: the Chart view — scales (category bands, linear numbers, dates; nice automatic domains that
// include zero), stacking/grouping of bars and areas, line interpolation, pies/donuts, axes with grid lines,
// ticks and labels, a legend for foregroundStyle(by:) series, and annotations. The plot is drawn in a Canvas;
// axis labels, the legend and annotations are SwiftUI views placed over it.
import SwiftUI

public struct Chart<Content: ChartContent>: View {
    let content: Content
    @Environment(\._chartXAxisVisibility) var xVisibility
    @Environment(\._chartYAxisVisibility) var yVisibility
    @Environment(\._chartXAxis) var xAxis
    @Environment(\._chartYAxis) var yAxis
    @Environment(\._chartXScale) var xScale
    @Environment(\._chartYScale) var yScale
    @Environment(\._chartStyleScale) var styleScale
    @Environment(\._chartLegend) var legend
    @Environment(\._chartXLabel) var xLabel
    @Environment(\._chartYLabel) var yLabel
    @Environment(\._chartSymbolScale) var symbolScale
    @Environment(\._chartSymbolSizeScale) var symbolSizeScale
    @Environment(\._chartXSelection) var xSelection
    @Environment(\._chartYSelection) var ySelection
    @Environment(\._chartXRangeSelection) var xRangeSelection
    @Environment(\._chartYRangeSelection) var yRangeSelection
    @Environment(\._chartAngleSelection) var angleSelection
    @Environment(\._chartScroll) var scroll
    @Environment(\._chartOverlay) var overlay
    @Environment(\._chartBackground) var background
    @Environment(\._chartGesture) var chartGesture
    @Environment(\._chartPlotStyle) var plotStyle
    /// live scroll positions (data units along x / y; category indexes on category axes) while no binding is given
    @State private var scrollX: Double? = nil
    @State private var scrollY: Double? = nil

    public init(@ChartContentBuilder content: () -> Content) { self.content = content() }
    public init<Data: RandomAccessCollection, ID: Hashable, C: ChartContent>(_ data: Data, id: KeyPath<Data.Element, ID>,
                                                                           @ChartContentBuilder content: @escaping (Data.Element) -> C) where Content == ForEach<Data, ID, C> {
        self.content = ForEach(data, id: id, content: content)
    }
    public init<Data: RandomAccessCollection, C: ChartContent>(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> C)
        where Content == ForEach<Data, Data.Element.ID, C>, Data.Element: Identifiable {
        self.content = ForEach(data, content: content)
    }

    public var body: some View {
        var cfg = _ChartConfig(xVisibility: xVisibility, yVisibility: yVisibility, xAxis: xAxis?.specs, yAxis: yAxis?.specs, xDomain: xScale, yDomain: yScale,
                               styleScale: styleScale, legend: legend, xLabel: xLabel, yLabel: yLabel)
        cfg.symbolScale = symbolScale; cfg.symbolSizeScale = symbolSizeScale
        cfg.selection = _SelectionSetters(x: xSelection?.set, y: ySelection?.set, xRange: xRangeSelection?.set, yRange: yRangeSelection?.set,
                                          angle: angleSelection?.set)
        cfg.scroll = scroll; cfg.overlay = overlay; cfg.background = background; cfg.gesture = chartGesture; cfg.plotStyle = plotStyle
        cfg.scrollX = scrollX; cfg.scrollY = scrollY
        let sx = $scrollX, sy = $scrollY
        cfg.setScroll = { x, y in sx.wrappedValue = x; sy.wrappedValue = y }
        let marks = _resolveMarks(content)
        // fills the space it is offered; where a height is left open (scroll views) it is 200 pt tall
        let all = _expandFunctions(marks, xDomain: xScale)
        return GeometryReader { geo in _ChartRenderer(marks: all, cfg: cfg, size: geo.size).view() }._isimIdealSize(height: 200)
    }
}

struct _ChartConfig {
    var xVisibility: Visibility, yVisibility: Visibility
    var xAxis: [_AxisMarksSpec]?, yAxis: [_AxisMarksSpec]?
    var xDomain: _ChartDomain?, yDomain: _ChartDomain?
    var styleScale: _StyleScaleBox?, legend: _LegendBox?
    var xLabel: _ViewBox?, yLabel: _ViewBox?
    var symbolScale: _SymbolScaleBox? = nil, symbolSizeScale: _SymbolSizeScaleBox? = nil
    var selection = _SelectionSetters()
    var scroll: _ScrollBox? = nil
    var overlay: _ProxyViewBox? = nil, background: _ProxyViewBox? = nil, gesture: _ProxyViewBox? = nil
    var plotStyle: _PlotStyleBox? = nil
    var scrollX: Double? = nil, scrollY: Double? = nil
    var setScroll: (Double?, Double?) -> Void = { _, _ in }
}

/// What is layered with the plot: views behind and over it, the plot style, the gesture layer, clipping.
struct _ChartLayers {
    var plot: CGRect = .zero
    var clip = false
    var background: AnyView?, plotStyle: AnyView?, gesture: AnyView?, overlay: AnyView?
    var backgroundAlignment = Alignment.center, overlayAlignment = Alignment.center
}

// MARK: - Formatting and measuring

@MainActor enum _ChartFormat {
    static let labelFont = UIFont.systemFont(ofSize: 11)
    static let legendFont = UIFont.systemFont(ofSize: 12)
    static let measurer = UILabel()
    static func size(_ s: String, _ font: UIFont) -> CGSize {
        measurer.font = font; measurer.text = s; measurer.numberOfLines = 1
        let r = measurer.sizeThatFits(CGSize(width: 10000, height: 1000))
        return CGSize(width: ceil(r.width), height: ceil(r.height))
    }
    static func number(_ v: Double, step: Double) -> String {
        if abs(v) < 1e-9 { return "0" }
        if step >= 1 || v == v.rounded() && abs(v) < 1e15 {
            if abs(v) >= 10000, v == v.rounded() {
                // thousands separators like Swift Charts' default number format
                let n = Int(v), s = String(abs(n))
                var out = ""
                for (i, ch) in s.reversed().enumerated() { if i > 0 && i % 3 == 0 { out.append(",") }; out.append(ch) }
                return (n < 0 ? "-" : "") + String(out.reversed())
            }
            return String(Int(v.rounded()))
        }
        let digits = max(1, min(6, Int((-log10(step)).rounded(.up))))
        var s = String(format: "%.\(digits)f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s
    }
    nonisolated static func date(_ d: Date, span: Double) -> String {
        let f = DateFormatter()
        f.dateFormat = span < 2 * 86400 ? "HH:mm" : span > 400 * 86400 ? "yyyy" : span > 80 * 86400 ? "MMM" : "MMM d"
        return f.string(from: d)
    }
}

/// Swift Charts' default categorical palette.
let _chartPalette: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .brown, .pink, .indigo]

// MARK: - Scales

struct _Scale {
    enum Kind { case band([String]), linear(Double, Double), date(Double, Double) }
    var kind: Kind
    var start: CGFloat, end: CGFloat               // screen positions of the domain's first and last value
    var isBand: Bool { if case .band = kind { return true }; return false }
    var categories: [String] { if case .band(let c) = kind { return c }; return [] }
    var bandWidth: CGFloat {
        if case .band(let c) = kind { return abs(end - start) / CGFloat(max(1, c.count)) }
        return 0
    }
    var domain: (Double, Double) {
        switch kind { case .linear(let a, let b), .date(let a, let b): return (a, b); case .band: return (0, 1) }
    }
    func pos(_ v: _PV?) -> CGFloat? {
        guard let v else { return nil }
        switch kind {
        case .band(let cats):
            guard let i = cats.firstIndex(of: v.category) else { return nil }
            let b = (end - start) / CGFloat(max(1, cats.count))
            return start + b * (CGFloat(i) + 0.5)
        case .linear(let lo, let hi), .date(let lo, let hi):
            guard let n = v.number else { return nil }
            return pos(n, lo, hi)
        }
    }
    func pos(_ n: Double) -> CGFloat {
        let (lo, hi) = domain
        return pos(n, lo, hi)
    }
    private func pos(_ n: Double, _ lo: Double, _ hi: Double) -> CGFloat {
        hi == lo ? (start + end) / 2 : start + CGFloat((n - lo) / (hi - lo)) * (end - start)
    }
}

/// Nice tick values covering lo...hi (about `count` of them).
func _niceStep(_ span: Double, _ count: Int) -> Double {
    let raw = max(span, 1e-12) / Double(max(1, count))
    let e = floor(log10(raw)), f = raw / pow(10, e)
    let nf: Double = f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10
    return nf * pow(10, e)
}
func _ticks(_ lo: Double, _ hi: Double, step: Double) -> [Double] {
    guard step > 0, hi >= lo else { return [] }
    var out: [Double] = []
    var v = (lo / step).rounded(.up) * step
    while v <= hi + step * 1e-9 && out.count < 200 { out.append(abs(v) < step * 1e-9 ? 0 : v); v += step }
    return out
}
func _unitLength(_ u: Calendar.Component?) -> Double? {
    switch u {
    case .some(.second): return 1
    case .some(.minute): return 60
    case .some(.hour): return 3600
    case .some(.day), .some(.weekday): return 86400
    case .some(.weekOfYear), .some(.weekOfMonth): return 7 * 86400
    case .some(.month): return 30.44 * 86400
    case .some(.quarter): return 91.31 * 86400
    case .some(.year): return 365.25 * 86400
    default: return nil
    }
}

// MARK: - Renderer

struct _ChartDraw { var path: Path; var style: AnyShapeStyle; var stroke: StrokeStyle?; var opacity: Double }
struct _PlacedView { var view: AnyView; var rect: CGRect; var alignment: Alignment }

@MainActor struct _ChartRenderer {
    let marks: [_Mark]
    let cfg: _ChartConfig
    let size: CGSize

    /// The style of each series key (foregroundStyle(by:)), in order of appearance.
    func seriesStyles() -> [(String, AnyShapeStyle)] {
        var keys: [String] = []
        for m in marks { if let k = m.styleKey, !keys.contains(k) { keys.append(k) } }
        return keys.enumerated().map { i, k in
            if let s = cfg.styleScale {
                if let ks = s.keys, let j = ks.firstIndex(of: k), j < s.styles.count { return (k, s.styles[j]) }
                if s.keys == nil, !s.styles.isEmpty { return (k, s.styles[i % s.styles.count]) }
            }
            return (k, AnyShapeStyle(_chartPalette[i % _chartPalette.count]))
        }
    }

    func view() -> AnyView {
        let series = seriesStyles()
        func style(_ m: _Mark) -> AnyShapeStyle {
            if let s = m.style { return s }
            if let k = m.styleKey, let s = series.first(where: { $0.0 == k }) { return s.1 }
            return AnyShapeStyle(Color.accentColor)
        }
        var draws: [_ChartDraw] = []
        var placed: [_PlacedView] = []
        let W = max(1, size.width), H = max(1, size.height)

        // legend (bottom by default)
        let legendVisible = !series.isEmpty && cfg.legend?.visibility != .hidden
        let legendTop = cfg.legend?.position == .top
        var legendItems: [(String, AnyShapeStyle, CGSize)] = []
        var legendRows = 0, legendH: CGFloat = 0
        if legendVisible {
            if cfg.legend?.content != nil { legendRows = 1; legendH = 24 }
            else {
                legendItems = series.map { ($0.0, $0.1, _ChartFormat.size($0.0, _ChartFormat.legendFont)) }
                var x: CGFloat = 0; legendRows = 1
                for it in legendItems { let w = 12 + it.2.width + 12; if x + w > W && x > 0 { legendRows += 1; x = 0 }; x += w }
                legendH = CGFloat(legendRows) * 18 + 8
            }
        }

        // pies and donuts
        if !marks.isEmpty && marks.allSatisfy({ $0.kind == .sector }) {
            let plot = CGRect(x: 0, y: legendTop ? legendH : 0, width: W, height: H - legendH)
            draws += pie(plot, style)
            placeLegend(&placed, legendItems, top: legendTop ? 0 : H - legendH + 8, width: W)
            if let c = cfg.legend?.content { placed.append(_PlacedView(view: c, rect: CGRect(x: 0, y: legendTop ? 0 : H - legendH, width: W, height: legendH), alignment: .leading)) }
            let unit = _Scale(kind: .linear(0, 1), start: plot.minX, end: plot.maxX), vunit = _Scale(kind: .linear(0, 1), start: plot.maxY, end: plot.minY)
            let proxy = ChartProxy(plot: plot, xs: unit, ys: vunit, selection: cfg.selection, angleAt: { pieValue(at: $0, plot) })
            return compose(draws, placed, layers(plot, proxy, scrolling: false))
        }

        // which axis carries the values of bars and areas
        func isCat(_ v: _PV?) -> Bool { if case .str? = v { return true }; return false }
        let xCategorical = marks.contains { isCat($0.x) || isCat($0.xStart) || isCat($0.xEnd) } || cfg.xDomain.map { if case .values(let v) = $0.kind { return v.contains { isCat($0) } }; return false } ?? false
        let yCategorical = marks.contains { isCat($0.y) || isCat($0.yStart) || isCat($0.yEnd) } || cfg.yDomain.map { if case .values(let v) = $0.kind { return v.contains { isCat($0) } }; return false } ?? false
        func horizontal(_ m: _Mark) -> Bool {
            if m.xStart != nil && m.xEnd != nil && m.yStart == nil { return true }
            if m.yStart != nil && m.yEnd != nil { return false }
            return yCategorical && !xCategorical
        }
        // stacking: value extents of bars and areas along their value axis
        var lo = [Double?](repeating: nil, count: marks.count), hi = [Double?](repeating: nil, count: marks.count)
        var pos: [String: Double] = [:], neg: [String: Double] = [:], total: [String: Double] = [:]
        func baseKey(_ m: _Mark, _ h: Bool) -> String { ((h ? m.y : m.x)?.category ?? "") + "|" + (m.positionKey ?? "") + "|" + (m.kind == .area ? "area" : "bar") }
        for (i, m) in marks.enumerated() where m.kind == .bar || m.kind == .area {
            let h = horizontal(m)
            let start = h ? m.xStart : m.yStart, end = h ? m.xEnd : m.yEnd
            if let s = start?.number, let e = end?.number { lo[i] = s; hi[i] = e; continue }
            guard let v = (h ? m.x : m.y)?.number else { continue }
            if m.stacking == .unstacked { lo[i] = min(0, v); hi[i] = max(0, v); continue }
            let k = baseKey(m, h)
            total[k, default: 0] += abs(v)
            if v >= 0 { let b = pos[k, default: 0]; lo[i] = b; hi[i] = b + v; pos[k] = b + v }
            else { let b = neg[k, default: 0]; hi[i] = b; lo[i] = b + v; neg[k] = b + v }
        }
        for (i, m) in marks.enumerated() where (m.kind == .bar || m.kind == .area) && (m.stacking == .normalized || m.stacking == .center) {
            let k = baseKey(m, horizontal(m))
            guard let t = total[k], t > 0, let l = lo[i], let u = hi[i] else { continue }
            if m.stacking == .normalized { lo[i] = l / t; hi[i] = u / t } else { lo[i] = l - t / 2; hi[i] = u - t / 2 }
        }

        // domains
        func values(_ isX: Bool) -> ([Double], Bool, Bool) {         // numbers, all dates, includes value marks (bars/areas/rules)
            var out: [Double] = [], dates = true, any = false, valueMarks = false
            for (i, m) in marks.enumerated() {
                let h = horizontal(m)
                let isValueAxis = (m.kind == .bar || m.kind == .area) && (isX == h)
                if isValueAxis, let l = lo[i], let u = hi[i] { out += [l, u]; valueMarks = true; dates = false; any = true; continue }
                for v in isX ? [m.x, m.xStart, m.xEnd] : [m.y, m.yStart, m.yEnd] {
                    guard let v, let n = v.number else { continue }
                    any = true
                    if case .date = v {} else { dates = false }
                    out.append(n)
                    if let u = _unitLength(isX ? m.xUnit : m.yUnit), m.kind == .bar || m.kind == .rectangle { out.append(n + u) }
                }
                if m.kind == .rule || m.kind == .bar || m.kind == .area { valueMarks = true }
            }
            return (out, dates && any, valueMarks)
        }
        func numericScale(_ isX: Bool, _ dom: _ChartDomain?, desired: Int) -> (_Scale.Kind, Double) {
            let (vals, isDate, _) = values(isX)
            var includesZero = !isDate
            if case .automatic(let z, _)? = dom?.kind, let z { includesZero = z }
            if case .range(let a, let b)? = dom?.kind, let l = a.number, let u = b.number {
                return (isDate ? .date(l, u) : .linear(l, u), _niceStep(u - l, desired))
            }
            var l = vals.min() ?? 0, u = vals.max() ?? 1
            if includesZero { l = min(l, 0); u = max(u, 0) }
            if u - l < 1e-9 { l -= 1; u += 1 }
            if isDate { return (.date(l, u), 0) }
            let step = _niceStep(u - l, desired)
            return (.linear((l / step).rounded(.down) * step, (u / step).rounded(.up) * step), step)
        }
        func categories(_ isX: Bool, _ dom: _ChartDomain?) -> [String] {
            if case .values(let v)? = dom?.kind { return v.map(\.category) }
            var out: [String] = []
            for m in marks { for v in isX ? [m.x, m.xStart, m.xEnd] : [m.y, m.yStart, m.yEnd] { if let v, !out.contains(v.category) { out.append(v.category) } } }
            return out
        }
        let xDesired = cfg.xAxis?.compactMap { if case .automatic(let n) = $0.values.kind { return n }; return nil }.first ?? 5
        let yDesired = cfg.yAxis?.compactMap { if case .automatic(let n) = $0.values.kind { return n }; return nil }.first ?? 5
        var (xKind, xStep): (_Scale.Kind, Double) = xCategorical ? (.band(categories(true, cfg.xDomain)), 0) : numericScale(true, cfg.xDomain, desired: xDesired)
        var (yKind, yStep): (_Scale.Kind, Double) = yCategorical ? (.band(categories(false, cfg.yDomain)), 0) : numericScale(false, cfg.yDomain, desired: yDesired)

        // scrolling: the plot shows a window of the visible length; positions are data units (category indexes)
        let sc = cfg.scroll
        let xScroll = sc.flatMap { $0.axes.contains(.horizontal) ? _ScrollWindow(kind: xKind, axis: $0.x, live: cfg.scrollX) : nil }
        let yScroll = sc.flatMap { $0.axes.contains(.vertical) ? _ScrollWindow(kind: yKind, axis: $0.y, live: cfg.scrollY) : nil }
        if let w = xScroll, let k = w.windowKind { xKind = k; xStep = _niceStep(w.length, xDesired) }
        if let w = yScroll, let k = w.windowKind { yKind = k; yStep = _niceStep(w.length, yDesired) }

        // axis tick values and labels
        let xHidden = cfg.xVisibility == .hidden || (cfg.xAxis?.isEmpty ?? false)
        let yHidden = cfg.yVisibility == .hidden || (cfg.yAxis?.isEmpty ?? false)
        func tickValues(_ kind: _Scale.Kind, _ step: Double, _ spec: _AxisMarksSpec?) -> [_PV] {
            switch kind {
            case .band(let c):
                if case .explicit(let v)? = spec?.values.kind { return v }
                return c.map { _PV.str($0) }
            case .linear(let l, let u):
                switch spec?.values.kind {
                case .explicit(let v)?: return v
                case .stride(let s)?: return _ticks(l, u, step: s).map { .num($0) }
                case .automatic(let n?)?: return _ticks(l, u, step: _niceStep(u - l, n)).map { .num($0) }
                default: return _ticks(l, u, step: step).map { .num($0) }
                }
            case .date(let l, let u):
                if case .explicit(let v)? = spec?.values.kind { return v }
                var unit: Calendar.Component = .day, count = 1
                let span = u - l
                if case .dateStride(let c, let n)? = spec?.values.kind { unit = c; count = max(1, n) }
                else if span < 6 * 3600 { unit = .hour; count = 1 }
                else if span < 3 * 86400 { unit = .hour; count = 6 }
                else if span < 16 * 86400 { unit = .day; count = max(1, Int((span / 86400 / 6).rounded(.up))) }
                else if span < 120 * 86400 { unit = .weekOfYear; count = 1 }
                else if span < 800 * 86400 { unit = .month; count = span < 400 * 86400 ? 1 : 3 }
                else { unit = .year; count = 1 }
                let cal = Calendar.current
                var d = cal.dateInterval(of: unit == .weekOfYear ? .weekOfYear : unit, for: Date(timeIntervalSinceReferenceDate: l))?.start ?? Date(timeIntervalSinceReferenceDate: l)
                var out: [_PV] = []
                while d.timeIntervalSinceReferenceDate <= u + 1 && out.count < 100 {
                    if d.timeIntervalSinceReferenceDate >= l - 1 { out.append(.date(d)) }
                    guard let n = cal.date(byAdding: unit, value: count, to: d), n > d else { break }
                    d = n
                }
                return out
            }
        }
        func label(_ v: _PV, _ kind: _Scale.Kind, _ step: Double) -> String {
            switch (v, kind) {
            case (.num(let n), _): return _ChartFormat.number(n, step: step > 0 ? step : 1)
            case (.date(let d), .date(let l, let u)): return _ChartFormat.date(d, span: u - l)
            default: return v.category
            }
        }
        let xSpec = cfg.xAxis?.first { $0.position != .automatic } ?? cfg.xAxis?.first
        let ySpec = cfg.yAxis?.first { $0.position != .automatic } ?? cfg.yAxis?.first
        // every AxisMarks of an axis contributes its values, each with its grid line, tick and label
        func axisMarks(_ specs: [_AxisMarksSpec]?, _ kind: _Scale.Kind, _ step: Double) -> ([_PV], [_AxisPartList]) {
            guard let specs else {
                let t = tickValues(kind, step, nil)
                return (t, t.map { _ in _AxisPartList(parts: [.grid(nil), .label(nil, nil)]) })
            }
            var values: [_PV] = [], parts: [_AxisPartList] = []
            for spec in specs {
                let t = tickValues(kind, step, spec)
                for (i, v) in t.enumerated() {
                    values.append(v)
                    parts.append((spec.content(AxisValue(index: i, count: t.count, pv: v)) as? _AxisPartProvider)?._parts ?? _AxisPartList())
                }
            }
            return (values, parts)
        }
        let (xTicks, xParts) = xHidden ? ([], []) : axisMarks(cfg.xAxis, xKind, xStep)
        let (yTicks, yParts) = yHidden ? ([], []) : axisMarks(cfg.yAxis, yKind, yStep)
        let yLabels = yTicks.map { label($0, yKind, yStep) }
        // label widths: measured for value labels; custom label views get room for a few more characters
        let yLabelW = zip(yLabels, yParts).compactMap { (s, ps) -> CGFloat? in
            for p in ps.parts { if case .label(let custom, _) = p { return _ChartFormat.size(s, _ChartFormat.labelFont).width + (custom != nil ? 16 : 0) } }
            return nil
        }.max() ?? 0
        let yLeading = ySpec?.position == .leading
        let xTop = xSpec?.position == .top
        let hasXLabels = xParts.contains { $0.parts.contains { if case .label = $0 { return true }; return false } }
        let xLabelH: CGFloat = hasXLabels ? 18 : 0
        let yLabelGap: CGFloat = yLabelW > 0 ? yLabelW + 6 : 0
        // axis titles: x below (or .top), y above (or beside the plot, vertical, with .leading / .trailing)
        let xTitleTop = cfg.xLabel?.position == .top
        let yTitleSide: Int = cfg.yLabel?.position == .leading ? -1 : cfg.yLabel?.position == .trailing ? 1 : 0
        let xTitleH: CGFloat = cfg.xLabel != nil ? 16 + (cfg.xLabel?.spacing ?? 2) : 0
        let yTitleH: CGFloat = cfg.yLabel != nil && yTitleSide == 0 ? 16 + (cfg.yLabel?.spacing ?? 2) : 0
        let yTitleW: CGFloat = cfg.yLabel != nil && yTitleSide != 0 ? 16 + (cfg.yLabel?.spacing ?? 2) : 0
        let leftPad = (yLeading ? yLabelGap : 0) + (yTitleSide < 0 ? yTitleW : 0)
        let rightPad = (yLeading ? 0 : yLabelGap) + (yTitleSide > 0 ? yTitleW : 0)
        let topPad: CGFloat = (yLabelW > 0 ? 7 : 1) + yTitleH + (xTop ? xLabelH : 0) + (legendTop ? legendH : 0) + (xTitleTop ? xTitleH : 0)
        let plot = CGRect(x: leftPad, y: topPad, width: max(1, W - leftPad - rightPad),
                          height: max(1, H - topPad - (xTop ? 0 : xLabelH) - (xTitleTop ? 0 : xTitleH) - (legendTop ? 0 : legendH) - (yLabelW > 0 && !hasXLabels ? 6 : 0)))
        let xs = xScroll?.scale(xKind, plot.minX, plot.maxX) ?? _Scale(kind: xKind, start: plot.minX, end: plot.maxX)
        let ys: _Scale
        if case .band = yKind { ys = yScroll?.scale(yKind, plot.minY, plot.maxY) ?? _Scale(kind: yKind, start: plot.minY, end: plot.maxY) }
        else {
            var reversed = false
            if case .automatic(_, let r?)? = cfg.yDomain?.kind { reversed = r }
            ys = reversed ? _Scale(kind: yKind, start: plot.minY, end: plot.maxY) : _Scale(kind: yKind, start: plot.maxY, end: plot.minY)
        }
        func inPlotX(_ x: CGFloat) -> Bool { x >= plot.minX - 0.5 && x <= plot.maxX + 0.5 }
        func inPlotY(_ y: CGFloat) -> Bool { y >= plot.minY - 0.5 && y <= plot.maxY + 0.5 }

        // grid lines, ticks and labels
        let grid = AnyShapeStyle(Color.gray.opacity(0.35))
        for (i, v) in yTicks.enumerated() {
            guard let y = ys.pos(v), inPlotY(y) else { continue }
            let ps = yParts[i]
            for p in ps.parts {
                switch p {
                case .grid(let s):
                    draws.append(_ChartDraw(path: Path { $0.move(to: CGPoint(x: plot.minX, y: y)); $0.addLine(to: CGPoint(x: plot.maxX, y: y)) },
                                            style: ps.style ?? grid, stroke: s ?? StrokeStyle(lineWidth: 0.5), opacity: 1))
                case .tick(let len, let s):
                    let x0 = yLeading ? plot.minX - len : plot.maxX
                    draws.append(_ChartDraw(path: Path { $0.move(to: CGPoint(x: x0, y: y)); $0.addLine(to: CGPoint(x: x0 + len, y: y)) },
                                            style: ps.style ?? grid, stroke: s ?? StrokeStyle(lineWidth: 0.5), opacity: 1))
                case .label(let custom, _):
                    let text = custom.map { AnyView($0.font(ps.font ?? .system(size: 11)).foregroundStyle(ps.style ?? AnyShapeStyle(HierarchicalShapeStyle.secondary)).fixedSize()) }
                        ?? AnyView(Text(yLabels[i]).font(ps.font ?? .system(size: 11)).foregroundStyle(ps.style ?? AnyShapeStyle(HierarchicalShapeStyle.secondary)))
                    let r = yLeading ? CGRect(x: plot.minX - yLabelGap, y: y - 8, width: yLabelW, height: 16) : CGRect(x: plot.maxX + 6, y: y - 8, width: max(yLabelW, 1), height: 16)
                    placed.append(_PlacedView(view: text, rect: r, alignment: yLeading ? .trailing : .leading))
                }
            }
        }
        let band = xs.bandWidth
        var lastLabelMaxX = -CGFloat.infinity
        for (i, v) in xTicks.enumerated() {
            guard let x = xs.pos(v), inPlotX(x) else { continue }
            let ps = xParts[i]
            for p in ps.parts {
                switch p {
                case .grid(let s):
                    if xs.isBand && cfg.xAxis == nil { continue }      // category axes: no vertical grid lines by default
                    draws.append(_ChartDraw(path: Path { $0.move(to: CGPoint(x: x, y: plot.minY)); $0.addLine(to: CGPoint(x: x, y: plot.maxY)) },
                                            style: ps.style ?? grid, stroke: s ?? StrokeStyle(lineWidth: 0.5), opacity: 1))
                case .tick(let len, let s):
                    let y0 = xTop ? plot.minY - len : plot.maxY
                    draws.append(_ChartDraw(path: Path { $0.move(to: CGPoint(x: x, y: y0)); $0.addLine(to: CGPoint(x: x, y: y0 + len)) },
                                            style: ps.style ?? grid, stroke: s ?? StrokeStyle(lineWidth: 0.5), opacity: 1))
                case .label(let custom, _):
                    let s = label(v, xKind, xStep)
                    let tw = _ChartFormat.size(s, _ChartFormat.labelFont).width
                    let w = xs.isBand ? max(band, tw + 4) : tw + 8
                    let r = CGRect(x: x - w / 2, y: xTop ? plot.minY - xLabelH : plot.maxY + 3, width: w, height: 15)
                    if custom == nil && x - tw / 2 < lastLabelMaxX + 4 { continue }           // overlapping labels are skipped
                    lastLabelMaxX = x + tw / 2
                    let text = custom.map { AnyView($0.font(ps.font ?? .system(size: 11)).foregroundStyle(ps.style ?? AnyShapeStyle(HierarchicalShapeStyle.secondary)).fixedSize()) }
                        ?? AnyView(Text(s).font(ps.font ?? .system(size: 11)).foregroundStyle(ps.style ?? AnyShapeStyle(HierarchicalShapeStyle.secondary)))
                    placed.append(_PlacedView(view: text, rect: r, alignment: .center))
                }
            }
        }
        func titleView(_ b: _ViewBox) -> AnyView { AnyView(b.view.font(.system(size: 11)).foregroundStyle(.secondary).fixedSize()) }
        if let t = cfg.xLabel {
            let sp = t.spacing ?? 2
            let y = xTitleTop ? plot.minY - (xTop ? xLabelH : 0) - 16 - sp : plot.maxY + (xTop ? 0 : xLabelH) + sp
            let a: Alignment = t.alignment.map { $0.horizontal == .leading ? .leading : $0.horizontal == .trailing ? .trailing : .center } ?? .center
            placed.append(_PlacedView(view: titleView(t), rect: CGRect(x: plot.minX, y: y, width: plot.width, height: 16), alignment: a))
        }
        if let t = cfg.yLabel {
            let sp = t.spacing ?? 2
            if yTitleSide == 0 {
                let a: Alignment = t.alignment.map { $0.horizontal == .leading ? .leading : $0.horizontal == .trailing ? .trailing : .center } ?? (yLeading ? .leading : .trailing)
                placed.append(_PlacedView(view: titleView(t), rect: CGRect(x: 0, y: plot.minY - (yLabelW > 0 ? 7 : 1) - 16 - sp + 2, width: W, height: 16), alignment: a))
            } else {
                // vertical text beside the plot, outside the value labels; alignment runs along the axis (top = leading)
                let x = yTitleSide < 0 ? plot.minX - (yLeading ? yLabelGap : 0) - sp - 16 : plot.maxX + (yLeading ? 0 : yLabelGap) + sp
                let a: Alignment = t.alignment.map { $0.vertical == .top ? .leading : $0.vertical == .bottom ? .trailing : .center } ?? .center
                let v = AnyView(t.view.font(.system(size: 11)).foregroundStyle(.secondary).fixedSize().frame(width: plot.height, height: 16, alignment: a)
                                    .rotationEffect(.degrees(-90)))
                placed.append(_PlacedView(view: v, rect: CGRect(x: x + 8 - plot.height / 2, y: plot.midY - 8, width: plot.height, height: 16), alignment: .center))
            }
        }

        // marks
        var drawnSeries: Set<String> = []
        var groups: [String: [String]] = [:]                    // position(by:) groups per base category
        for m in marks { if let pk = m.positionKey { let k = (horizontal(m) ? m.y : m.x)?.category ?? ""; if !(groups[k]?.contains(pk) ?? false) { groups[k, default: []].append(pk) } } }
        for (i, m) in marks.enumerated() {
            let st = style(m)
            switch m.kind {
            case .bar, .rectangle:
                guard let r = rect(m, i, horizontal(m), xs, ys, lo, hi, groups) else { continue }
                draws.append(_ChartDraw(path: m.cornerRadius > 0 ? Path(roundedRect: r, cornerRadius: m.cornerRadius) : Path(r), style: st, stroke: nil, opacity: m.opacity))
                for a in m.annotations { placed.append(annotation(a, r)) }
            case .line, .area:
                let key = (m.kind == .line ? "L|" : "A|") + (m.series ?? m.styleKey ?? "")
                if drawnSeries.contains(key) { continue }
                drawnSeries.insert(key)
                let members = marks.indices.filter { j in marks[j].kind == m.kind && (marks[j].series ?? marks[j].styleKey ?? "") == (m.series ?? m.styleKey ?? "") }
                let pts: [CGPoint] = members.compactMap { j in
                    let n = marks[j]
                    guard let x = xs.pos(n.x) else { return nil }
                    if n.kind == .area, let u = hi[j] { return CGPoint(x: x, y: ys.pos(u)) }
                    guard let y = ys.pos(n.y) else { return nil }
                    return CGPoint(x: x, y: y)
                }
                guard !pts.isEmpty else { continue }
                if m.kind == .line {
                    draws.append(_ChartDraw(path: _curve(pts, m.interpolation), style: st, stroke: m.lineStyle ?? StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round), opacity: m.opacity))
                    for j in members where marks[j].symbol != nil || marks[j].symbolKey != nil || marks[j].symbolPath != nil || marks[j].symbolView != nil {
                        guard let x = xs.pos(marks[j].x), let y = ys.pos(marks[j].y) else { continue }
                        if let v = marks[j].symbolView {
                            if inPlotX(x) && inPlotY(y) { placed.append(_PlacedView(view: AnyView(v.fixedSize()), rect: CGRect(x: x - 50, y: y - 50, width: 100, height: 100), alignment: .center)) }
                        } else { draws.append(symbol(marks[j], CGPoint(x: x, y: y), st)) }
                    }
                } else {
                    let base: [CGPoint] = members.compactMap { j in
                        guard let x = xs.pos(marks[j].x) else { return nil }
                        return CGPoint(x: x, y: ys.pos(lo[j] ?? 0))
                    }
                    draws.append(_ChartDraw(path: _area(pts, base, m.interpolation), style: st, stroke: nil, opacity: m.opacity))
                }
                for j in members { for a in marks[j].annotations { if let x = xs.pos(marks[j].x), let y = ys.pos(marks[j].y) { placed.append(annotation(a, CGRect(x: x - 4, y: y - 4, width: 8, height: 8))) } } }
            case .point:
                guard let x = xs.pos(m.x), let y = ys.pos(m.y) else { continue }
                if let v = m.symbolView {
                    if inPlotX(x) && inPlotY(y) { placed.append(_PlacedView(view: AnyView(v.fixedSize()), rect: CGRect(x: x - 50, y: y - 50, width: 100, height: 100), alignment: .center)) }
                } else { draws.append(symbol(m, CGPoint(x: x, y: y), st)) }
                let s = symbolSide(m)
                for a in m.annotations { placed.append(annotation(a, CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))) }
            case .rule:
                var p = Path()
                if let y = ys.pos(m.y), m.x == nil {
                    p.move(to: CGPoint(x: xs.pos(m.xStart) ?? plot.minX, y: y)); p.addLine(to: CGPoint(x: xs.pos(m.xEnd) ?? plot.maxX, y: y))
                } else if let x = xs.pos(m.x) {
                    p.move(to: CGPoint(x: x, y: ys.pos(m.yStart) ?? plot.maxY)); p.addLine(to: CGPoint(x: x, y: ys.pos(m.yEnd) ?? plot.minY))
                } else { continue }
                draws.append(_ChartDraw(path: p, style: st, stroke: m.lineStyle ?? StrokeStyle(lineWidth: 1), opacity: m.opacity))
                for a in m.annotations { placed.append(annotation(a, p.boundingRect)) }
            case .sector: continue
            }
        }
        placeLegend(&placed, legendItems, top: legendTop ? 0 : H - legendH + 6, width: W)
        if let c = cfg.legend?.content, legendVisible { placed.append(_PlacedView(view: c, rect: CGRect(x: 0, y: legendTop ? 0 : H - legendH, width: W, height: legendH), alignment: .leading)) }
        let proxy = ChartProxy(plot: plot, xs: xs, ys: ys, selection: cfg.selection, angleAt: nil)
        var lay = layers(plot, proxy, scrolling: xScroll != nil || yScroll != nil)
        if (xScroll != nil || yScroll != nil) && cfg.gesture == nil {
            lay.gesture = scrollLayer(plot, xs, ys, xScroll, yScroll, proxy)
        }
        // marks of a scrolled-away window are clipped; labels outside the plot were skipped above
        return compose(draws, placed, lay)
    }

    /// Background, plot style, gesture and overlay layers.
    func layers(_ plot: CGRect, _ proxy: ChartProxy, scrolling: Bool) -> _ChartLayers {
        var l = _ChartLayers(plot: plot, clip: scrolling)
        if let b = cfg.background { l.background = b.make(proxy); l.backgroundAlignment = b.alignment }
        if let o = cfg.overlay { l.overlay = o.make(proxy); l.overlayAlignment = o.alignment }
        if let p = cfg.plotStyle { l.plotStyle = p.make(ChartPlotContent()) }
        if let g = cfg.gesture { l.gesture = g.make(proxy) }
        else if cfg.selection.any { l.gesture = selectionLayer(plot, proxy) }
        return l
    }

    /// The built-in selection gesture: the value under the finger while it is down (nil when it lifts); dragging
    /// sideways (or up and down) selects a range.
    func selectionLayer(_ plot: CGRect, _ proxy: ChartProxy) -> AnyView {
        let sel = cfg.selection
        return AnyView(Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { v in
            let p = v.location, s = v.startLocation
            sel.x.map { _ in proxy.selectXValue(at: p.x) }
            sel.y.map { _ in proxy.selectYValue(at: p.y) }
            if sel.angle != nil { proxy.selectAngleValue(at: p) }
            if sel.xRange != nil, abs(p.x - s.x) > 4 { proxy.selectXRange(from: s.x, to: p.x) }
            if sel.yRange != nil, abs(p.y - s.y) > 4 { proxy.selectYRange(from: s.y, to: p.y) }
        }.onEnded { _ in
            sel.x?(nil); sel.y?(nil); sel.angle?(nil)
        }))
    }

    /// Dragging scrolls the windowed axes (taps still select); the position snaps to the target behavior at the end.
    func scrollLayer(_ plot: CGRect, _ xs: _Scale, _ ys: _Scale, _ wx: _ScrollWindow?, _ wy: _ScrollWindow?, _ proxy: ChartProxy) -> AnyView {
        let sel = cfg.selection, set = cfg.setScroll, target = cfg.scroll?.target
        let xPerPt = wx.map { $0.unitsPerPoint(plot.width) } ?? 0, yPerPt = wy.map { $0.unitsPerPoint(plot.height) } ?? 0
        let x0 = wx?.position, y0 = wy?.position
        return AnyView(Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { v in
            let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
            if abs(dx) < 6 && abs(dy) < 6 {
                if sel.x != nil { proxy.selectXValue(at: v.location.x) }
                if sel.y != nil { proxy.selectYValue(at: v.location.y) }
                return
            }
            let nx = wx.map { $0.clamp(x0! - Double(dx) * xPerPt) }, ny = wy.map { $0.clamp(y0! + ($0.isBand ? -1 : 1) * Double(dy) * yPerPt) }
            set(nx, ny)
            if let w = wx, let n = nx { w.publish(n) }
            if let w = wy, let n = ny { w.publish(n) }
        }.onEnded { v in
            sel.x?(nil); sel.y?(nil)
            let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
            guard abs(dx) >= 6 || abs(dy) >= 6 else { return }
            let nx = wx.map { $0.snap($0.clamp(x0! - Double(dx) * xPerPt), target) }, ny = wy.map { $0.snap($0.clamp(y0! + ($0.isBand ? -1 : 1) * Double(dy) * yPerPt), target) }
            set(nx, ny)
            if let w = wx, let n = nx { w.publish(n) }
            if let w = wy, let n = ny { w.publish(n) }
        }))
    }

    /// The cumulative pie value at a point (angle from 12 o'clock, clockwise, as a share of the total).
    func pieValue(at p: CGPoint, _ plot: CGRect) -> Double? {
        let total = marks.reduce(0) { $0 + max(0, $1.angle ?? 0) }
        guard total > 0 else { return nil }
        var a = atan2(Double(p.y - plot.midY), Double(p.x - plot.midX)) + Double.pi / 2
        if a < 0 { a += 2 * Double.pi }
        return a / (2 * Double.pi) * total
    }

    /// The rectangle of a bar or rectangle mark.
    func rect(_ m: _Mark, _ i: Int, _ h: Bool, _ xs: _Scale, _ ys: _Scale, _ lo: [Double?], _ hi: [Double?], _ groups: [String: [String]]) -> CGRect? {
        let base = h ? ys : xs, value = h ? xs : ys
        var center: CGFloat, thickness: CGFloat
        // along the base axis: a category band, a binned date, or a number
        let bv = h ? m.y : m.x, bs = h ? m.yStart : m.xStart, be = h ? m.yEnd : m.xEnd
        if m.kind == .bar || bs == nil {
            guard let c = base.pos(bv) ?? base.pos(bs) else { return nil }
            center = c
            let unit = _unitLength(h ? m.yUnit : m.xUnit)
            let auto: CGFloat
            if base.isBand { auto = base.bandWidth * (m.kind == .rectangle ? 1 : 0.6) }
            else if let u = unit, let n = bv?.number { center = (base.pos(n) + base.pos(n + u)) / 2; auto = abs(base.pos(n + u) - base.pos(n)) * 0.8 }
            else {
                // numbers along the base: 60% of the closest spacing between the marks' values on screen
                let ps = Set(marks.compactMap { n -> CGFloat? in n.kind == m.kind ? base.pos((h ? n.y : n.x)?.number ?? .nan) : nil }.filter { $0.isFinite }).sorted()
                let gap = zip(ps, ps.dropFirst()).map { $1 - $0 }.filter { $0 > 0.5 }.min()
                auto = m.kind == .rectangle ? 20 : max(4, (gap ?? abs(base.end - base.start) / CGFloat(max(1, marks.count))) * 0.6)
            }
            thickness = (h ? m.height : m.width).resolve(base.isBand ? base.bandWidth : auto / 0.6, auto: auto)
            if let pk = m.positionKey, let g = groups[bv?.category ?? ""], let gi = g.firstIndex(of: pk), g.count > 1 {
                let slot = thickness / CGFloat(g.count)
                center = center - thickness / 2 + slot * (CGFloat(gi) + 0.5)
                thickness = slot
            }
        } else {
            guard let a = base.pos(bs), let b = base.pos(be) else { return nil }
            center = (a + b) / 2; thickness = abs(b - a)
        }
        // along the value axis
        var a: CGFloat, b: CGFloat
        if m.kind == .bar, let l = lo[i], let u = hi[i] { a = value.pos(l); b = value.pos(u) }
        else if let s = value.pos(h ? m.xStart : m.yStart), let e = value.pos(h ? m.xEnd : m.yEnd) { a = s; b = e }
        else if let v = value.pos(h ? m.x : m.y) {
            let t = (h ? m.width : m.height).resolve(value.isBand ? value.bandWidth : 20, auto: value.isBand ? value.bandWidth : 20)
            a = v - t / 2; b = v + t / 2
        } else { return nil }
        let r = h ? CGRect(x: min(a, b), y: center - thickness / 2, width: abs(b - a), height: thickness)
                  : CGRect(x: center - thickness / 2, y: min(a, b), width: thickness, height: abs(b - a))
        return r
    }

    /// The side of a mark's symbol: symbolSize (an area in square points), symbolSize(by:) through the size scale,
    /// or 8 pt.
    func symbolSide(_ m: _Mark) -> CGFloat {
        if let v = m.symbolSizeValue {
            let vals = marks.compactMap(\.symbolSizeValue)
            let (lo, hi) = cfg.symbolSizeScale?.domain ?? (vals.min() ?? 0, vals.max() ?? 1)
            let (a, b) = cfg.symbolSizeScale?.range ?? (20, 200)
            let t = hi > lo ? min(1, max(0, (v - lo) / (hi - lo))) : 0.5
            return max(2, CGFloat(a + t * (b - a)).squareRoot() * 1.13)
        }
        return m.symbolSize.map { max(2, $0.squareRoot() * 1.13) } ?? 8
    }
    func symbol(_ m: _Mark, _ c: CGPoint, _ st: AnyShapeStyle) -> _ChartDraw {
        let d = symbolSide(m)
        let r = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
        if let p = m.symbolPath { return _ChartDraw(path: p(r), style: st, stroke: nil, opacity: m.opacity) }
        var shape = m.symbol ?? .circle
        if m.symbol == nil, let k = m.symbolKey {
            var keys: [String] = []
            for n in marks { if let s = n.symbolKey, !keys.contains(s) { keys.append(s) } }
            let i = keys.firstIndex(of: k) ?? 0
            if let sc = cfg.symbolScale, !sc.shapes.isEmpty {
                if let ks = sc.keys { if let j = ks.firstIndex(of: k), j < sc.shapes.count { return _ChartDraw(path: sc.shapes[j](r), style: st, stroke: nil, opacity: m.opacity) } }
                else { return _ChartDraw(path: sc.shapes[i % sc.shapes.count](r), style: st, stroke: nil, opacity: m.opacity) }
            }
            let all: [BasicChartSymbolShape] = [.circle, .square, .triangle, .diamond, .pentagon, .plus, .cross, .asterisk]
            shape = all[i % all.count]
        }
        return _ChartDraw(path: shape.path(in: r), style: st, stroke: nil, opacity: m.opacity)
    }

    /// Pie / donut slices, from 12 o'clock clockwise.
    func pie(_ plot: CGRect, _ style: (_Mark) -> AnyShapeStyle) -> [_ChartDraw] {
        let total = marks.reduce(0) { $0 + max(0, $1.angle ?? 0) }
        guard total > 0 else { return [] }
        let c = CGPoint(x: plot.midX, y: plot.midY)
        let maxR = min(plot.width, plot.height) / 2
        var a = -Double.pi / 2
        var out: [_ChartDraw] = []
        for m in marks {
            let sweep = 2 * Double.pi * max(0, m.angle ?? 0) / total
            defer { a += sweep }
            guard sweep > 0 else { continue }
            let outer = m.outerRadius.resolve(maxR, auto: maxR)
            let inner = m.innerRadius.resolve(outer, auto: 0)
            let inset = outer > 0 ? Double(m.angularInset) / Double(outer) / 2 : 0
            let a0 = a + inset, a1 = a + sweep - inset
            guard a1 > a0 else { continue }
            var p = Path()
            p.addArc(center: c, radius: outer, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            if inner > 0 { p.addArc(center: c, radius: inner, startAngle: .radians(a1), endAngle: .radians(a0), clockwise: true) }
            else { p.addLine(to: c) }
            p.closeSubpath()
            out.append(_ChartDraw(path: p, style: style(m), stroke: nil, opacity: m.opacity))
        }
        return out
    }

    func placeLegend(_ placed: inout [_PlacedView], _ items: [(String, AnyShapeStyle, CGSize)], top: CGFloat, width: CGFloat) {
        var x: CGFloat = 0, y = top
        for (name, style, s) in items {
            let w = 12 + s.width + 12
            if x + w > width && x > 0 { x = 0; y += 18 }
            placed.append(_PlacedView(view: AnyView(Circle().fill(style)), rect: CGRect(x: x, y: y + 4, width: 8, height: 8), alignment: .center))
            placed.append(_PlacedView(view: AnyView(Text(name).font(.system(size: 12)).foregroundStyle(.secondary)), rect: CGRect(x: x + 12, y: y - 1, width: s.width + 2, height: 17), alignment: .leading))
            x += w
        }
    }

    func annotation(_ a: _Annotation, _ r: CGRect) -> _PlacedView {
        let sp = a.spacing ?? 4, bw: CGFloat = 200, bh: CGFloat = 60
        switch a.position {
        case .bottom: return _PlacedView(view: a.view, rect: CGRect(x: r.midX - bw / 2, y: r.maxY + sp, width: bw, height: bh), alignment: .top)
        case .leading: return _PlacedView(view: a.view, rect: CGRect(x: r.minX - sp - bw, y: r.midY - bh / 2, width: bw, height: bh), alignment: .trailing)
        case .trailing: return _PlacedView(view: a.view, rect: CGRect(x: r.maxX + sp, y: r.midY - bh / 2, width: bw, height: bh), alignment: .leading)
        case .overlay: return _PlacedView(view: a.view, rect: CGRect(x: r.midX - bw / 2, y: r.midY - bh / 2, width: bw, height: bh), alignment: a.alignment)
        default: return _PlacedView(view: a.view, rect: CGRect(x: r.midX - bw / 2, y: r.minY - sp - bh, width: bw, height: bh), alignment: .bottom)
        }
    }

    func compose(_ draws: [_ChartDraw], _ placed: [_PlacedView], _ l: _ChartLayers) -> AnyView {
        let plot = l.plot, clip = l.clip
        return AnyView(ZStack(alignment: .topLeading) {
            if let b = l.background { b.frame(width: size.width, height: size.height, alignment: l.backgroundAlignment) }
            if let p = l.plotStyle { p.frame(width: plot.width, height: plot.height).offset(x: plot.minX, y: plot.minY) }
            Canvas { context, _ in
                var ctx = context
                if clip { ctx.clip(to: Path(plot.insetBy(dx: -1, dy: -1))) }
                for d in draws {
                    var c = ctx
                    c.opacity = d.opacity
                    if let s = d.stroke { c.stroke(d.path, with: .style(d.style), style: s) } else { c.fill(d.path, with: .style(d.style)) }
                }
            }
            .frame(width: size.width, height: size.height)
            ForEach(0..<placed.count) { i in
                placed[i].view.frame(width: placed[i].rect.width, height: placed[i].rect.height, alignment: placed[i].alignment)
                    .offset(x: placed[i].rect.minX, y: placed[i].rect.minY)
            }
            if let g = l.gesture { g.frame(width: plot.width, height: plot.height).offset(x: plot.minX, y: plot.minY) }
            if let o = l.overlay { o.frame(width: size.width, height: size.height, alignment: l.overlayAlignment) }
        }.frame(width: size.width, height: size.height, alignment: .topLeading))
    }
}

/// A line through points with an interpolation method.
func _curve(_ pts: [CGPoint], _ m: InterpolationMethod) -> Path {
    var p = Path()
    guard let first = pts.first else { return p }
    p.move(to: first)
    guard pts.count > 1 else { return p }
    switch m.kind {
    case .linear: for q in pts.dropFirst() { p.addLine(to: q) }
    case .stepStart: for i in 1..<pts.count { p.addLine(to: CGPoint(x: pts[i - 1].x, y: pts[i].y)); p.addLine(to: pts[i]) }
    case .stepEnd: for i in 1..<pts.count { p.addLine(to: CGPoint(x: pts[i].x, y: pts[i - 1].y)); p.addLine(to: pts[i]) }
    case .stepCenter:
        for i in 1..<pts.count {
            let mx = (pts[i - 1].x + pts[i].x) / 2
            p.addLine(to: CGPoint(x: mx, y: pts[i - 1].y)); p.addLine(to: CGPoint(x: mx, y: pts[i].y)); p.addLine(to: pts[i])
        }
    case .catmullRom, .cardinal, .monotone:
        var tension: CGFloat = 0
        if case .cardinal(let t) = m.kind { tension = t }
        let k = (1 - tension) / 6
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            var c1 = CGPoint(x: p1.x + (p2.x - p0.x) * k, y: p1.y + (p2.y - p0.y) * k)
            var c2 = CGPoint(x: p2.x - (p3.x - p1.x) * k, y: p2.y - (p3.y - p1.y) * k)
            if m.kind == .monotone {          // keep the curve within each segment's values (no overshoot)
                let lo = min(p1.y, p2.y), hi = max(p1.y, p2.y)
                c1.y = min(hi, max(lo, c1.y)); c2.y = min(hi, max(lo, c2.y))
            }
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
    }
    return p
}
/// The area between a top line and a base line.
func _area(_ top: [CGPoint], _ base: [CGPoint], _ m: InterpolationMethod) -> Path {
    var p = _curve(top, m)
    _curve(base.reversed(), m).forEach { e in
        switch e {
        case .move(let q), .line(let q): p.addLine(to: q)
        case .quadCurve(let q, let c): p.addQuadCurve(to: q, control: c)
        case .curve(let q, let c1, let c2): p.addCurve(to: q, control1: c1, control2: c2)
        case .closeSubpath: break
        @unknown default: break
        }
    }
    p.closeSubpath()
    return p
}
