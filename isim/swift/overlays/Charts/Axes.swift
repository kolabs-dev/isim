// isim Charts: axes (AxisMarks with grid lines, ticks and value labels), scale domains, and the chart-level
// configuration modifiers (chartXAxis/chartYAxis, chartXScale/chartYScale, chartLegend,
// chartForegroundStyleScale, chartXAxisLabel/chartYAxisLabel), passed to Chart through the environment.
import SwiftUI

// MARK: - Axis content

public protocol AxisContent {}
public protocol AxisMark {}

public struct AxisMarkPosition: Equatable, Sendable {
    let id: Int
    public static let automatic = AxisMarkPosition(id: 0), leading = AxisMarkPosition(id: 1), trailing = AxisMarkPosition(id: 2)
    public static let top = AxisMarkPosition(id: 3), bottom = AxisMarkPosition(id: 4)
}
public struct AxisMarkPreset: Equatable, Sendable {
    let id: Int
    public static let automatic = AxisMarkPreset(id: 0), extended = AxisMarkPreset(id: 1), aligned = AxisMarkPreset(id: 2), inset = AxisMarkPreset(id: 3)
}
/// Where axis marks go: automatic (about `desiredCount` nice values), a stride, or explicit values.
public struct AxisMarkValues {
    enum Kind { case automatic(Int?), stride(Double), dateStride(Calendar.Component, Int), explicit([_PV]) }
    let kind: Kind
    public static var automatic: AxisMarkValues { AxisMarkValues(kind: .automatic(nil)) }
    public static func automatic(desiredCount: Int? = nil, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues { AxisMarkValues(kind: .automatic(desiredCount)) }
    public static func stride(by stepSize: Double, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues { AxisMarkValues(kind: .stride(stepSize)) }
    public static func stride(by component: Calendar.Component, count: Int = 1, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil, calendar: Calendar? = nil) -> AxisMarkValues {
        AxisMarkValues(kind: .dateStride(component, count))
    }
}

/// One value an axis marks, passed to AxisMarks' content.
public struct AxisValue {
    public let index: Int
    public let count: Int
    let pv: _PV
    public func `as`<P: Plottable>(_ type: P.Type) -> P? { _convert(pv, to: P.self, depth: 0) }
}
func _convert<P: Plottable>(_ pv: _PV, to: P.Type, depth: Int) -> P? {
    switch pv {
    case .num(let d):
        if let v = d as? P { return v }
        if P.self == Int.self { return Int(d.rounded()) as? P }
        if P.self == Float.self { return Float(d) as? P }
        if P.self == Int64.self { return Int64(d.rounded()) as? P }
        if P.self == Int32.self { return Int32(d.rounded()) as? P }
    case .str(let s): if let v = s as? P { return v }
    case .date(let d): if let v = d as? P { return v }
    }
    if depth < 3, P.PrimitivePlottable.self != P.self, let prim = _convert(pv, to: P.PrimitivePlottable.self, depth: depth + 1) { return P(primitivePlottable: prim) }
    return nil
}

/// How a value label is laid out (AxisValueLabel's options) and, with `format`, its text.
struct _AxisLabelOptions {
    var format: ((_PV) -> String?)? = nil
    var collision = AxisValueLabelCollisionResolution.automatic
    var orientation = AxisValueLabelOrientation.automatic
    var horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil
    var centered: Bool? = nil
}
enum _AxisPart {
    case grid(StrokeStyle?)
    case tick(CGFloat, StrokeStyle?)
    case label(AnyView?, UnitPoint?, _AxisLabelOptions)
}
struct _AxisPartList { var parts: [_AxisPart] = []; var style: AnyShapeStyle?; var font: Font? }
protocol _AxisPartProvider { var _parts: _AxisPartList { get } }

public struct AxisGridLine: AxisMark, _AxisPartProvider {
    let stroke: StrokeStyle?
    public init(centered: Bool? = nil, stroke: StrokeStyle? = nil) { self.stroke = stroke }
    var _parts: _AxisPartList { _AxisPartList(parts: [.grid(stroke)]) }
}
public struct AxisTick: AxisMark, _AxisPartProvider {
    let length: CGFloat, stroke: StrokeStyle?
    public init(centered: Bool? = nil, length: CGFloat = 5, stroke: StrokeStyle? = nil) { self.length = length; self.stroke = stroke }
    var _parts: _AxisPartList { _AxisPartList(parts: [.tick(length, stroke)]) }
}
/// How overlapping axis value labels are resolved: `automatic` and `greedy` keep a label only when it clears the ones
/// already placed (by `priority`, then in order, with `minimumSpacing`), `truncate` shortens labels to the room
/// between their neighbours, `disabled` draws them all.
public struct AxisValueLabelCollisionResolution: Sendable {
    enum Kind: Sendable { case automatic, greedy(Double, CGFloat?), truncate, disabled }
    let kind: Kind
    public static var automatic: AxisValueLabelCollisionResolution { .init(kind: .automatic) }
    public static var greedy: AxisValueLabelCollisionResolution { .init(kind: .greedy(0, nil)) }
    public static func greedy(priority: Double = 0, minimumSpacing: CGFloat? = nil) -> AxisValueLabelCollisionResolution {
        .init(kind: .greedy(priority, minimumSpacing))
    }
    public static var truncate: AxisValueLabelCollisionResolution { .init(kind: .truncate) }
    public static var disabled: AxisValueLabelCollisionResolution { .init(kind: .disabled) }
}
/// Which way axis value labels read: `vertical` turns them a quarter counterclockwise (bottom to top),
/// `verticalReversed` clockwise.
public struct AxisValueLabelOrientation: Sendable, Equatable {
    let id: Int
    public static var automatic: AxisValueLabelOrientation { .init(id: 0) }
    public static var horizontal: AxisValueLabelOrientation { .init(id: 1) }
    public static var vertical: AxisValueLabelOrientation { .init(id: 2) }
    public static var verticalReversed: AxisValueLabelOrientation { .init(id: 3) }
}
public struct AxisValueLabel: AxisMark, _AxisPartProvider {
    let view: AnyView?, anchor: UnitPoint?
    var options = _AxisLabelOptions()
    init(view: AnyView?, centered: Bool?, anchor: UnitPoint?, collisionResolution: AxisValueLabelCollisionResolution, orientation: AxisValueLabelOrientation,
         horizontalSpacing: CGFloat?, verticalSpacing: CGFloat?, format: ((_PV) -> String?)? = nil) {
        self.view = view; self.anchor = anchor
        options = _AxisLabelOptions(format: format, collision: collisionResolution, orientation: orientation,
                                    horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing, centered: centered)
    }
    /// the value, formatted like the axis
    public init(centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil,
                collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil,
                orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
        self.init(view: nil, centered: centered, anchor: anchor, collisionResolution: collisionResolution, orientation: orientation,
                  horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    public init<Content: View>(centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil,
                               collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil,
                               orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil,
                               @ViewBuilder content: () -> Content) {
        self.init(view: AnyView(content()), centered: centered, anchor: anchor, collisionResolution: collisionResolution, orientation: orientation,
                  horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    public init<S: StringProtocol>(_ label: S, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil,
                                   collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil,
                                   orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
        self.init(view: AnyView(Text(String(label))), centered: centered, anchor: anchor, collisionResolution: collisionResolution, orientation: orientation,
                  horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    public init(_ label: LocalizedStringKey, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil,
                collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil,
                orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
        self.init(view: AnyView(Text(label)), centered: centered, anchor: anchor, collisionResolution: collisionResolution, orientation: orientation,
                  horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    public init(_ label: LocalizedStringResource, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil,
                collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil,
                orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
        self.init(view: AnyView(Text(String(localized: label))), centered: centered, anchor: anchor, collisionResolution: collisionResolution,
                  orientation: orientation, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    /// the value, formatted by a format style of its type (a number, date, ... format)
    public init<Format: FormatStyle>(format: Format, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil,
                                     collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil,
                                     orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil)
        where Format.FormatInput: Plottable, Format.FormatOutput == String {
        self.init(view: nil, centered: centered, anchor: anchor, collisionResolution: collisionResolution, orientation: orientation,
                  horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing,
                  format: { pv in _convert(pv, to: Format.FormatInput.self, depth: 0).map { format.format($0) } })
    }
    // the initializers of isim 0.9 and earlier (kept for apps built with them; Apple's above are preferred)
    @_disfavoredOverload public init(centered: Bool? = nil, anchor: UnitPoint? = nil) {
        self.init(centered: centered, anchor: anchor, multiLabelAlignment: nil)
    }
    @_disfavoredOverload public init<C: View>(centered: Bool? = nil, anchor: UnitPoint? = nil, @ViewBuilder content: () -> C) {
        self.init(centered: centered, anchor: anchor, multiLabelAlignment: nil, content: content)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ label: S, centered: Bool? = nil, anchor: UnitPoint? = nil) {
        self.init(label, centered: centered, anchor: anchor, multiLabelAlignment: nil)
    }
    var _parts: _AxisPartList { _AxisPartList(parts: [.label(view, anchor, options)]) }
}
/// Grid line, tick and label: what AxisMarks draws without content.
public struct _DefaultAxisMark: AxisMark, _AxisPartProvider {
    var _parts: _AxisPartList { _AxisPartList(parts: [.grid(nil), .label(nil, nil, _AxisLabelOptions())]) }
}
public struct _AxisMarkGroup: AxisMark, _AxisPartProvider {
    let marks: [any AxisMark]
    var style: AnyShapeStyle?, font: Font?
    var _parts: _AxisPartList {
        var out = _AxisPartList(style: style, font: font)
        for m in marks {
            guard let p = (m as? _AxisPartProvider)?._parts else { continue }
            out.parts += p.parts
            if out.style == nil { out.style = p.style }
            if out.font == nil { out.font = p.font }
        }
        return out
    }
}
extension AxisMark {
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> _AxisMarkGroup { _AxisMarkGroup(marks: [self], style: AnyShapeStyle(style)) }
    public func font(_ font: Font?) -> _AxisMarkGroup { _AxisMarkGroup(marks: [self], font: font) }
}
@resultBuilder public struct AxisMarkBuilder {
    public static func buildExpression<M: AxisMark>(_ m: M) -> _AxisMarkGroup { _AxisMarkGroup(marks: [m]) }
    public static func buildBlock(_ parts: _AxisMarkGroup...) -> _AxisMarkGroup { _AxisMarkGroup(marks: parts) }
    public static func buildOptional(_ p: _AxisMarkGroup?) -> _AxisMarkGroup { p ?? _AxisMarkGroup(marks: []) }
    public static func buildEither(first p: _AxisMarkGroup) -> _AxisMarkGroup { p }
    public static func buildEither(second p: _AxisMarkGroup) -> _AxisMarkGroup { p }
}

public struct AxisMarks<Content: AxisMark>: AxisContent {
    let position: AxisMarkPosition, values: AxisMarkValues
    let content: (AxisValue) -> any AxisMark
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic) where Content == _DefaultAxisMark {
        self.position = position; self.values = values; content = { _ in _DefaultAxisMark() }
    }
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic,
                @AxisMarkBuilder content: @escaping (AxisValue) -> Content) {
        self.position = position; self.values = values; self.content = content
    }
    public init<V: Plottable>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: [V]) where Content == _DefaultAxisMark {
        self.position = position; self.values = AxisMarkValues(kind: .explicit(values.map { _PV.of($0) })); content = { _ in _DefaultAxisMark() }
    }
    public init<V: Plottable>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: [V],
                              @AxisMarkBuilder content: @escaping (AxisValue) -> Content) {
        self.position = position; self.values = AxisMarkValues(kind: .explicit(values.map { _PV.of($0) })); self.content = content
    }
}
public struct _AxisContentGroup: AxisContent { let items: [any AxisContent] }
/// A type-erased axis content (an axis whose marks are chosen at run time).
public struct AnyAxisContent: AxisContent {
    let base: any AxisContent
    public init(_ content: any AxisContent) { base = (content as? AnyAxisContent)?.base ?? content }
    public init(erasing content: some AxisContent) { self.init(content) }
}
@resultBuilder public struct AxisContentBuilder {
    public static func buildExpression<C: AxisContent>(_ c: C) -> _AxisContentGroup { _AxisContentGroup(items: [c]) }
    public static func buildBlock(_ parts: _AxisContentGroup...) -> _AxisContentGroup { _AxisContentGroup(items: parts) }
    public static func buildOptional(_ p: _AxisContentGroup?) -> _AxisContentGroup { p ?? _AxisContentGroup(items: []) }
    public static func buildEither(first p: _AxisContentGroup) -> _AxisContentGroup { p }
    public static func buildEither(second p: _AxisContentGroup) -> _AxisContentGroup { p }
}
/// The AxisMarks of an axis content tree (flattened).
struct _AxisMarksSpec {
    let position: AxisMarkPosition, values: AxisMarkValues, content: (AxisValue) -> any AxisMark
}
protocol _AxisMarksProvider { var _spec: _AxisMarksSpec { get } }
extension AxisMarks: _AxisMarksProvider { var _spec: _AxisMarksSpec { _AxisMarksSpec(position: position, values: values, content: content) } }
func _axisSpecs(_ c: any AxisContent) -> [_AxisMarksSpec] {
    if let g = c as? _AxisContentGroup { return g.items.flatMap { _axisSpecs($0) } }
    if let a = c as? AnyAxisContent { return _axisSpecs(a.base) }
    if let p = c as? _AxisMarksProvider { return [p._spec] }
    return []
}

// MARK: - Scale domains

public struct _ChartDomain {
    enum Kind { case automatic(includesZero: Bool?, reversed: Bool?), range(_PV, _PV), values([_PV]) }
    let kind: Kind
}
public protocol ScaleDomain { var _chartDomain: _ChartDomain { get } }
extension ClosedRange: ScaleDomain where Bound: Plottable {
    public var _chartDomain: _ChartDomain { _ChartDomain(kind: .range(_PV.of(lowerBound), _PV.of(upperBound))) }
}
extension Range: ScaleDomain where Bound: Plottable {
    public var _chartDomain: _ChartDomain { _ChartDomain(kind: .range(_PV.of(lowerBound), _PV.of(upperBound))) }
}
extension Array: ScaleDomain where Element: Plottable {
    public var _chartDomain: _ChartDomain { _ChartDomain(kind: .values(map { _PV.of($0) })) }
}
public struct AutomaticScaleDomain: ScaleDomain {
    let includesZero: Bool?, reversed: Bool?
    public var _chartDomain: _ChartDomain { _ChartDomain(kind: .automatic(includesZero: includesZero, reversed: reversed)) }
}
extension ScaleDomain where Self == AutomaticScaleDomain {
    public static var automatic: AutomaticScaleDomain { AutomaticScaleDomain(includesZero: nil, reversed: nil) }
    public static func automatic(includesZero: Bool? = nil, reversed: Bool? = nil) -> AutomaticScaleDomain { AutomaticScaleDomain(includesZero: includesZero, reversed: reversed) }
}
/// Scale types: how values map to positions. `log` (base 10, positive values), `squareRoot`, `power(exponent:)` and
/// `symmetricLog` (logarithmic away from zero, linear near it, for values of both signs) transform the values;
/// `category` makes the axis categorical and `date` a date axis.
public struct ScaleType: Equatable, Sendable {
    let id: Int
    var parameter: Double = 1
    public static let linear = ScaleType(id: 0), log = ScaleType(id: 1), squareRoot = ScaleType(id: 2), category = ScaleType(id: 3), date = ScaleType(id: 4)
    public static func power(exponent: Double = 1) -> ScaleType { ScaleType(id: 5, parameter: exponent) }
    public static var symmetricLog: ScaleType { ScaleType(id: 6) }
    public static func symmetricLog(slopeAtZero: Double) -> ScaleType { ScaleType(id: 6, parameter: slopeAtZero) }
}
/// The positions a scale's domain maps to: a `ClosedRange<CGFloat>` of points in the plot (x from its leading edge, y
/// from its bottom), or the plot's dimension with padding at the ends (`plotDimension`, the default).
public protocol PositionScaleRange { var _positionRange: _PositionRange { get } }
public struct _PositionRange { enum Kind { case points(CGFloat, CGFloat), padding(CGFloat, CGFloat) }; let kind: Kind }
public struct PlotDimensionScaleRange: PositionScaleRange {
    let startPadding: CGFloat, endPadding: CGFloat
    public var _positionRange: _PositionRange { _PositionRange(kind: .padding(startPadding, endPadding)) }
}
extension PositionScaleRange where Self == PlotDimensionScaleRange {
    public static var plotDimension: PlotDimensionScaleRange { PlotDimensionScaleRange(startPadding: 0, endPadding: 0) }
    public static func plotDimension(padding: CGFloat) -> PlotDimensionScaleRange { PlotDimensionScaleRange(startPadding: padding, endPadding: padding) }
    public static func plotDimension(startPadding: CGFloat, endPadding: CGFloat) -> PlotDimensionScaleRange {
        PlotDimensionScaleRange(startPadding: startPadding, endPadding: endPadding)
    }
}
extension ClosedRange: PositionScaleRange where Bound == CGFloat {
    public var _positionRange: _PositionRange { _PositionRange(kind: .points(lowerBound, upperBound)) }
}

// MARK: - Chart configuration (environment)

final class _AxisConfigBox { let specs: [_AxisMarksSpec]; init(_ s: [_AxisMarksSpec]) { specs = s } }
final class _StyleScaleBox { let keys: [String]?; let styles: [AnyShapeStyle]; init(_ k: [String]?, _ s: [AnyShapeStyle]) { keys = k; styles = s } }
final class _LegendBox { let visibility: Visibility; let position: AnnotationPosition; let content: AnyView?
    init(_ v: Visibility, _ p: AnnotationPosition, _ c: AnyView?) { visibility = v; position = p; content = c } }
/// chartXAxisLabel / chartYAxisLabel: the view and where it goes (position, alignment, spacing).
final class _ViewBox {
    let view: AnyView, position: AnnotationPosition, alignment: Alignment?, spacing: CGFloat?
    init(_ v: AnyView, _ p: AnnotationPosition = .automatic, _ a: Alignment? = nil, _ s: CGFloat? = nil) { view = v; position = p; alignment = a; spacing = s }
}
/// chartSymbolScale (symbols per series value) and chartSymbolSizeScale (symbol areas for symbolSize(by:)).
final class _SymbolScaleBox {
    let keys: [String]?, shapes: [(CGRect) -> Path]
    init(_ k: [String]?, _ s: [(CGRect) -> Path]) { keys = k; shapes = s }
}
final class _SymbolSizeScaleBox { let domain: (Double, Double)?, range: (Double, Double); init(_ d: (Double, Double)?, _ r: (Double, Double)) { domain = d; range = r } }

struct _ChartXAxisVisKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct _ChartYAxisVisKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct _ChartXAxisKey: EnvironmentKey { static var defaultValue: _AxisConfigBox? { nil } }
struct _ChartYAxisKey: EnvironmentKey { static var defaultValue: _AxisConfigBox? { nil } }
struct _ChartXScaleKey: EnvironmentKey { static var defaultValue: _ChartDomain? { nil } }
struct _ChartYScaleKey: EnvironmentKey { static var defaultValue: _ChartDomain? { nil } }
/// chartXScale / chartYScale's type and range (each modifier sets only what it is given)
struct _ChartXScaleTypeKey: EnvironmentKey { static var defaultValue: ScaleType? { nil } }
struct _ChartYScaleTypeKey: EnvironmentKey { static var defaultValue: ScaleType? { nil } }
struct _ChartXRangeKey: EnvironmentKey { static var defaultValue: _PositionRange? { nil } }
struct _ChartYRangeKey: EnvironmentKey { static var defaultValue: _PositionRange? { nil } }
struct _ChartStyleScaleKey: EnvironmentKey { static var defaultValue: _StyleScaleBox? { nil } }
struct _ChartLegendKey: EnvironmentKey { static var defaultValue: _LegendBox? { nil } }
struct _ChartXLabelKey: EnvironmentKey { static var defaultValue: _ViewBox? { nil } }
struct _ChartYLabelKey: EnvironmentKey { static var defaultValue: _ViewBox? { nil } }
struct _ChartSymbolScaleKey: EnvironmentKey { static var defaultValue: _SymbolScaleBox? { nil } }
struct _ChartSymbolSizeScaleKey: EnvironmentKey { static var defaultValue: _SymbolSizeScaleBox? { nil } }
extension EnvironmentValues {
    var _chartXAxisVisibility: Visibility { get { self[_ChartXAxisVisKey.self] } set { self[_ChartXAxisVisKey.self] = newValue } }
    var _chartYAxisVisibility: Visibility { get { self[_ChartYAxisVisKey.self] } set { self[_ChartYAxisVisKey.self] = newValue } }
    var _chartXAxis: _AxisConfigBox? { get { self[_ChartXAxisKey.self] } set { self[_ChartXAxisKey.self] = newValue } }
    var _chartYAxis: _AxisConfigBox? { get { self[_ChartYAxisKey.self] } set { self[_ChartYAxisKey.self] = newValue } }
    var _chartXScale: _ChartDomain? { get { self[_ChartXScaleKey.self] } set { self[_ChartXScaleKey.self] = newValue } }
    var _chartYScale: _ChartDomain? { get { self[_ChartYScaleKey.self] } set { self[_ChartYScaleKey.self] = newValue } }
    var _chartXScaleType: ScaleType? { get { self[_ChartXScaleTypeKey.self] } set { self[_ChartXScaleTypeKey.self] = newValue } }
    var _chartYScaleType: ScaleType? { get { self[_ChartYScaleTypeKey.self] } set { self[_ChartYScaleTypeKey.self] = newValue } }
    var _chartXRange: _PositionRange? { get { self[_ChartXRangeKey.self] } set { self[_ChartXRangeKey.self] = newValue } }
    var _chartYRange: _PositionRange? { get { self[_ChartYRangeKey.self] } set { self[_ChartYRangeKey.self] = newValue } }
    var _chartStyleScale: _StyleScaleBox? { get { self[_ChartStyleScaleKey.self] } set { self[_ChartStyleScaleKey.self] = newValue } }
    var _chartLegend: _LegendBox? { get { self[_ChartLegendKey.self] } set { self[_ChartLegendKey.self] = newValue } }
    var _chartXLabel: _ViewBox? { get { self[_ChartXLabelKey.self] } set { self[_ChartXLabelKey.self] = newValue } }
    var _chartYLabel: _ViewBox? { get { self[_ChartYLabelKey.self] } set { self[_ChartYLabelKey.self] = newValue } }
    var _chartSymbolScale: _SymbolScaleBox? { get { self[_ChartSymbolScaleKey.self] } set { self[_ChartSymbolScaleKey.self] = newValue } }
    var _chartSymbolSizeScale: _SymbolSizeScaleBox? { get { self[_ChartSymbolSizeScaleKey.self] } set { self[_ChartSymbolSizeScaleKey.self] = newValue } }
}

extension View {
    public func chartXAxis(_ visibility: Visibility) -> some View { environment(\._chartXAxisVisibility, visibility) }
    public func chartYAxis(_ visibility: Visibility) -> some View { environment(\._chartYAxisVisibility, visibility) }
    public func chartXAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> some View { environment(\._chartXAxis, _AxisConfigBox(_axisSpecs(content()))) }
    public func chartYAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> some View { environment(\._chartYAxis, _AxisConfigBox(_axisSpecs(content()))) }
    public func chartXScale<D: ScaleDomain>(domain: D, type: ScaleType? = nil) -> some View {
        environment(\._chartXScale, domain._chartDomain).modifier(_ScaleTypeModifier(x: true, type: type))
    }
    public func chartYScale<D: ScaleDomain>(domain: D, type: ScaleType? = nil) -> some View {
        environment(\._chartYScale, domain._chartDomain).modifier(_ScaleTypeModifier(x: false, type: type))
    }
    public func chartXScale<D: ScaleDomain, R: PositionScaleRange>(domain: D, range: R, type: ScaleType? = nil) -> some View {
        environment(\._chartXScale, domain._chartDomain).environment(\._chartXRange, range._positionRange).modifier(_ScaleTypeModifier(x: true, type: type))
    }
    public func chartYScale<D: ScaleDomain, R: PositionScaleRange>(domain: D, range: R, type: ScaleType? = nil) -> some View {
        environment(\._chartYScale, domain._chartDomain).environment(\._chartYRange, range._positionRange).modifier(_ScaleTypeModifier(x: false, type: type))
    }
    public func chartXScale<R: PositionScaleRange>(range: R, type: ScaleType? = nil) -> some View {
        environment(\._chartXRange, range._positionRange).modifier(_ScaleTypeModifier(x: true, type: type))
    }
    public func chartYScale<R: PositionScaleRange>(range: R, type: ScaleType? = nil) -> some View {
        environment(\._chartYRange, range._positionRange).modifier(_ScaleTypeModifier(x: false, type: type))
    }
    public func chartXScale(type: ScaleType? = nil) -> some View { modifier(_ScaleTypeModifier(x: true, type: type)) }
    public func chartYScale(type: ScaleType? = nil) -> some View { modifier(_ScaleTypeModifier(x: false, type: type)) }
    // isim 0.9 and earlier took the range as a ClosedRange<CGFloat> (kept for apps built with them)
    @_disfavoredOverload public func chartXScale<D: ScaleDomain>(domain: D, range: ClosedRange<CGFloat>, type: ScaleType? = nil) -> some View {
        environment(\._chartXScale, domain._chartDomain).environment(\._chartXRange, range._positionRange).modifier(_ScaleTypeModifier(x: true, type: type))
    }
    @_disfavoredOverload public func chartYScale<D: ScaleDomain>(domain: D, range: ClosedRange<CGFloat>, type: ScaleType? = nil) -> some View {
        environment(\._chartYScale, domain._chartDomain).environment(\._chartYRange, range._positionRange).modifier(_ScaleTypeModifier(x: false, type: type))
    }
    public func chartLegend(_ visibility: Visibility) -> some View { environment(\._chartLegend, _LegendBox(visibility, .automatic, nil)) }
    public func chartLegend(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartLegend, _LegendBox(.visible, position, nil))
    }
    public func chartLegend<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View {
        environment(\._chartLegend, _LegendBox(.visible, position, AnyView(content())))
    }
    public func chartForegroundStyleScale<D: Plottable, S: ShapeStyle>(_ mapping: KeyValuePairs<D, S>) -> some View {
        environment(\._chartStyleScale, _StyleScaleBox(mapping.map { _PV.of($0.key).category }, mapping.map { AnyShapeStyle($0.value) }))
    }
    public func chartForegroundStyleScale<D: Plottable, S: ShapeStyle>(domain: [D], range: [S], type: ScaleType? = nil) -> some View {
        environment(\._chartStyleScale, _StyleScaleBox(domain.map { _PV.of($0).category }, range.map { AnyShapeStyle($0) }))
    }
    public func chartForegroundStyleScale<S: ShapeStyle>(range: [S], type: ScaleType? = nil) -> some View {
        environment(\._chartStyleScale, _StyleScaleBox(nil, range.map { AnyShapeStyle($0) }))
    }
    /// The x axis title: below the plot by default (centered), or `.top`; `alignment` places it along the axis.
    public func chartXAxisLabel<S: StringProtocol>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartXLabel, _ViewBox(AnyView(Text(String(label))), position, alignment, spacing))
    }
    public func chartXAxisLabel(_ label: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartXLabel, _ViewBox(AnyView(Text(label)), position, alignment, spacing))
    }
    public func chartXAxisLabel(_ label: Text, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartXLabel, _ViewBox(AnyView(label), position, alignment, spacing))
    }
    public func chartXAxisLabel<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View {
        environment(\._chartXLabel, _ViewBox(AnyView(content()), position, alignment, spacing))
    }
    /// The y axis title: above the plot by default (on the axis' side), or `.leading` / `.trailing` (vertical text).
    public func chartYAxisLabel<S: StringProtocol>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartYLabel, _ViewBox(AnyView(Text(String(label))), position, alignment, spacing))
    }
    public func chartYAxisLabel(_ label: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartYLabel, _ViewBox(AnyView(Text(label)), position, alignment, spacing))
    }
    public func chartYAxisLabel(_ label: Text, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View {
        environment(\._chartYLabel, _ViewBox(AnyView(label), position, alignment, spacing))
    }
    public func chartYAxisLabel<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View {
        environment(\._chartYLabel, _ViewBox(AnyView(content()), position, alignment, spacing))
    }
    /// Symbols per `symbol(by:)` value.
    public func chartSymbolScale<D: Plottable, S: ChartSymbolShape>(_ mapping: KeyValuePairs<D, S>) -> some View {
        environment(\._chartSymbolScale, _SymbolScaleBox(mapping.map { _PV.of($0.key).category }, mapping.map { s in { s.value.path(in: $0) } }))
    }
    public func chartSymbolScale<D: Plottable, S: ChartSymbolShape>(domain: [D], range: [S]) -> some View {
        environment(\._chartSymbolScale, _SymbolScaleBox(domain.map { _PV.of($0).category }, range.map { s in { s.path(in: $0) } }))
    }
    public func chartSymbolScale<S: ChartSymbolShape>(range: [S]) -> some View {
        environment(\._chartSymbolScale, _SymbolScaleBox(nil, range.map { s in { s.path(in: $0) } }))
    }
    /// Symbol areas (square points) for `symbolSize(by:)` values: the data's extent maps onto `range`.
    public func chartSymbolSizeScale<D: Plottable>(domain: ClosedRange<D>, range: ClosedRange<Double>) -> some View {
        environment(\._chartSymbolSizeScale, _SymbolSizeScaleBox((_PV.of(domain.lowerBound).number ?? 0, _PV.of(domain.upperBound).number ?? 1), (range.lowerBound, range.upperBound)))
    }
    public func chartSymbolSizeScale(range: ClosedRange<Double>) -> some View {
        environment(\._chartSymbolSizeScale, _SymbolSizeScaleBox(nil, (range.lowerBound, range.upperBound)))
    }
}

/// sets an axis' scale type when one is given (nil keeps what an outer modifier set)
struct _ScaleTypeModifier: ViewModifier {
    let x: Bool, type: ScaleType?
    func body(content: Content) -> some View {
        content.transformEnvironment(\.self) { e in
            guard let type else { return }
            if x { e._chartXScaleType = type } else { e._chartYScaleType = type }
        }
    }
}
