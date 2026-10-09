// isim Charts — an independent re-implementation of a Swift Charts subset on isim's SwiftUI (not Apple's
// Charts). Chart content (marks, ForEach, modifiers) resolves into plain mark records that Chart.swift lays
// out and draws with public SwiftUI API (Canvas for the plot, Text views for axis labels and the legend).
@_exported import SwiftUI

// MARK: - Plottable values

public protocol Plottable {
    associatedtype PrimitivePlottable: Plottable
    var primitivePlottable: PrimitivePlottable { get }
    init?(primitivePlottable: PrimitivePlottable)
}
extension Plottable where Self: RawRepresentable, RawValue: Plottable {
    public var primitivePlottable: RawValue { rawValue }
    public init?(primitivePlottable: RawValue) { self.init(rawValue: primitivePlottable) }
}
extension String: Plottable {
    public var primitivePlottable: String { self }
    public init?(primitivePlottable: String) { self = primitivePlottable }
}
extension Date: Plottable {
    public var primitivePlottable: Date { self }
    public init?(primitivePlottable: Date) { self = primitivePlottable }
}
extension Double: Plottable {
    public var primitivePlottable: Double { self }
    public init?(primitivePlottable: Double) { self = primitivePlottable }
}
extension Float: Plottable {
    public var primitivePlottable: Float { self }
    public init?(primitivePlottable: Float) { self = primitivePlottable }
}
extension Int: Plottable {
    public var primitivePlottable: Int { self }
    public init?(primitivePlottable: Int) { self = primitivePlottable }
}
extension Int8: Plottable {
    public var primitivePlottable: Int8 { self }
    public init?(primitivePlottable: Int8) { self = primitivePlottable }
}
extension Int16: Plottable {
    public var primitivePlottable: Int16 { self }
    public init?(primitivePlottable: Int16) { self = primitivePlottable }
}
extension Int32: Plottable {
    public var primitivePlottable: Int32 { self }
    public init?(primitivePlottable: Int32) { self = primitivePlottable }
}
extension Int64: Plottable {
    public var primitivePlottable: Int64 { self }
    public init?(primitivePlottable: Int64) { self = primitivePlottable }
}
extension UInt: Plottable {
    public var primitivePlottable: UInt { self }
    public init?(primitivePlottable: UInt) { self = primitivePlottable }
}
extension UInt8: Plottable {
    public var primitivePlottable: UInt8 { self }
    public init?(primitivePlottable: UInt8) { self = primitivePlottable }
}
extension UInt16: Plottable {
    public var primitivePlottable: UInt16 { self }
    public init?(primitivePlottable: UInt16) { self = primitivePlottable }
}
extension UInt32: Plottable {
    public var primitivePlottable: UInt32 { self }
    public init?(primitivePlottable: UInt32) { self = primitivePlottable }
}
extension UInt64: Plottable {
    public var primitivePlottable: UInt64 { self }
    public init?(primitivePlottable: UInt64) { self = primitivePlottable }
}

/// A plotted value reduced to a number, a category or a date.
enum _PV: Hashable {
    case num(Double), str(String), date(Date)
    var number: Double? {
        switch self { case .num(let d): return d; case .date(let d): return d.timeIntervalSinceReferenceDate; case .str: return nil }
    }
    var category: String {
        switch self {
        case .str(let s): return s
        case .num(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
        case .date(let d): return _ChartFormat.date(d, span: 86400 * 30)
        }
    }
    static func of(_ v: Any, depth: Int = 0) -> _PV {
        switch v {
        case let s as String: return .str(s)
        case let d as Date: return .date(d)
        case let x as Double: return .num(x)
        case let x as Float: return .num(Double(x))
        case let x as any BinaryInteger: return .num(Double(x))
        case let x as any BinaryFloatingPoint: return .num(Double(x))
        default:
            if depth < 4, let p = v as? any Plottable { return of(p.primitivePlottable, depth: depth + 1) }
            return .str(String(describing: v))
        }
    }
}

public struct PlottableValue<Value: Plottable> {
    let label: String
    let value: Value
    let unit: Calendar.Component?
    var _pv: _PV { _PV.of(value) }
    @_disfavoredOverload public static func value<S: StringProtocol>(_ label: S, _ value: Value) -> PlottableValue<Value> {
        PlottableValue(label: String(label), value: value, unit: nil)
    }
    public static func value(_ label: LocalizedStringKey, _ value: Value) -> PlottableValue<Value> { PlottableValue(label: "", value: value, unit: nil) }
    public static func value(_ label: Text, _ value: Value) -> PlottableValue<Value> { PlottableValue(label: "", value: value, unit: nil) }
}
extension PlottableValue where Value == Date {
    /// A date binned to a calendar unit (bars span the unit).
    @_disfavoredOverload public static func value<S: StringProtocol>(_ label: S, _ value: Date, unit: Calendar.Component, calendar: Calendar = .current) -> PlottableValue<Date> {
        PlottableValue(label: String(label), value: calendar.dateInterval(of: unit, for: value)?.start ?? value, unit: unit)
    }
    public static func value(_ label: LocalizedStringKey, _ value: Date, unit: Calendar.Component, calendar: Calendar = .current) -> PlottableValue<Date> {
        PlottableValue(label: "", value: calendar.dateInterval(of: unit, for: value)?.start ?? value, unit: unit)
    }
}

// MARK: - Mark options

public struct MarkDimension: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Sendable {
    enum Kind: Sendable { case automatic, fixed(CGFloat), ratio(Double), inset(CGFloat) }
    let kind: Kind
    public static let automatic = MarkDimension(kind: .automatic)
    public static func fixed(_ v: CGFloat) -> MarkDimension { MarkDimension(kind: .fixed(v)) }
    public static func ratio(_ v: Double) -> MarkDimension { MarkDimension(kind: .ratio(v)) }
    public static func inset(_ v: CGFloat) -> MarkDimension { MarkDimension(kind: .inset(v)) }
    init(kind: Kind) { self.kind = kind }
    public init(floatLiteral value: Double) { kind = .fixed(value) }
    public init(integerLiteral value: Int) { kind = .fixed(CGFloat(value)) }
    /// The length within `band` (automatic: `auto`).
    func resolve(_ band: CGFloat, auto: CGFloat) -> CGFloat {
        switch kind {
        case .automatic: return auto
        case .fixed(let v): return v
        case .ratio(let r): return band * r
        case .inset(let i): return max(0, band - 2 * i)
        }
    }
}
public struct MarkStackingMethod: Equatable, Sendable {
    let id: Int
    public static let standard = MarkStackingMethod(id: 0), normalized = MarkStackingMethod(id: 1), center = MarkStackingMethod(id: 2), unstacked = MarkStackingMethod(id: 3)
}
public struct InterpolationMethod: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case linear, catmullRom, cardinal(Double), monotone, stepStart, stepCenter, stepEnd }
    let kind: Kind
    public static let linear = InterpolationMethod(kind: .linear)
    public static let catmullRom = InterpolationMethod(kind: .catmullRom)
    public static let cardinal = InterpolationMethod(kind: .cardinal(0))
    public static let monotone = InterpolationMethod(kind: .monotone)
    public static let stepStart = InterpolationMethod(kind: .stepStart)
    public static let stepCenter = InterpolationMethod(kind: .stepCenter)
    public static let stepEnd = InterpolationMethod(kind: .stepEnd)
    public static func cardinal(tension: Double) -> InterpolationMethod { InterpolationMethod(kind: .cardinal(tension)) }
    public static func catmullRom(alpha: Double) -> InterpolationMethod { InterpolationMethod(kind: .catmullRom) }
}
public struct AnnotationPosition: Equatable, Sendable {
    let id: Int
    public static let automatic = AnnotationPosition(id: 0), top = AnnotationPosition(id: 1), bottom = AnnotationPosition(id: 2)
    public static let leading = AnnotationPosition(id: 3), trailing = AnnotationPosition(id: 4), overlay = AnnotationPosition(id: 5)
    public static let topLeading = AnnotationPosition(id: 6), topTrailing = AnnotationPosition(id: 7)
    public static let bottomLeading = AnnotationPosition(id: 8), bottomTrailing = AnnotationPosition(id: 9)
}

/// Point mark symbols.
public protocol ChartSymbolShape: Shape {}
public struct BasicChartSymbolShape: Sendable {
    enum Kind: Sendable { case circle, square, triangle, diamond, pentagon, plus, cross, asterisk }
    let kind: Kind
    public func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2
        var p = Path()
        func poly(_ n: Int, _ start: Double) {
            p.addLines((0..<n).map { i in
                let a = start + Double(i) * 2 * .pi / Double(n)
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }); p.closeSubpath()
        }
        switch kind {
        case .circle: p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        case .square: p.addRect(CGRect(x: c.x - r * 0.85, y: c.y - r * 0.85, width: r * 1.7, height: r * 1.7))
        case .triangle: poly(3, -.pi / 2)
        case .diamond: poly(4, -.pi / 2)
        case .pentagon: poly(5, -.pi / 2)
        case .plus, .cross, .asterisk:
            let w = r * 0.35
            p.addRect(CGRect(x: c.x - r, y: c.y - w / 2, width: 2 * r, height: w))
            p.addRect(CGRect(x: c.x - w / 2, y: c.y - r, width: w, height: 2 * r))
            if kind == .cross { p = p.applying(CGAffineTransform(translationX: -c.x, y: -c.y).concatenating(CGAffineTransform(rotationAngle: .pi / 4)).concatenating(CGAffineTransform(translationX: c.x, y: c.y))) }
        }
        return p
    }
}
extension BasicChartSymbolShape: ChartSymbolShape {}
extension ChartSymbolShape where Self == BasicChartSymbolShape {
    public static var circle: BasicChartSymbolShape { BasicChartSymbolShape(kind: .circle) }
    public static var square: BasicChartSymbolShape { BasicChartSymbolShape(kind: .square) }
    public static var triangle: BasicChartSymbolShape { BasicChartSymbolShape(kind: .triangle) }
    public static var diamond: BasicChartSymbolShape { BasicChartSymbolShape(kind: .diamond) }
    public static var pentagon: BasicChartSymbolShape { BasicChartSymbolShape(kind: .pentagon) }
    public static var plus: BasicChartSymbolShape { BasicChartSymbolShape(kind: .plus) }
    public static var cross: BasicChartSymbolShape { BasicChartSymbolShape(kind: .cross) }
    public static var asterisk: BasicChartSymbolShape { BasicChartSymbolShape(kind: .asterisk) }
}

// MARK: - Resolved marks

enum _MarkKind { case bar, line, point, area, rule, rectangle, sector }
struct _Annotation { let position: AnnotationPosition; let alignment: Alignment; let spacing: CGFloat?; let view: AnyView }
/// One mark with its values and styling, as the chart lays it out.
struct _Mark {
    var kind: _MarkKind
    var x: _PV?, y: _PV?, xStart: _PV?, xEnd: _PV?, yStart: _PV?, yEnd: _PV?
    var xUnit: Calendar.Component?, yUnit: Calendar.Component?
    var angle: Double?
    var innerRadius = MarkDimension.automatic, outerRadius = MarkDimension.automatic, angularInset: CGFloat = 0
    var width = MarkDimension.automatic, height = MarkDimension.automatic
    var stacking = MarkStackingMethod.standard
    var series: String?
    var styleKey: String?
    var style: AnyShapeStyle?
    var symbolKey: String?
    var symbol: BasicChartSymbolShape?
    var symbolPath: ((CGRect) -> Path)?        // a custom ChartSymbolShape
    var symbolView: AnyView?                   // symbol { view }
    var symbolSize: CGFloat?
    var symbolSizeValue: Double?               // symbolSize(by:): mapped through the symbol size scale
    var interpolation = InterpolationMethod.linear
    var lineStyle: StrokeStyle?
    var opacity = 1.0
    var cornerRadius: CGFloat = 0
    var positionKey: String?
    var annotations: [_Annotation] = []
    var function: _FunctionPlot?               // LinePlot / AreaPlot of a function: sampled once the x domain is known
    init(_ kind: _MarkKind) { self.kind = kind }
}

// MARK: - ChartContent

@MainActor @preconcurrency
public protocol ChartContent {
    associatedtype Body: ChartContent
    @ChartContentBuilder var body: Body { get }
}
extension Never: ChartContent {}

/// Chart content isim resolves directly (marks, groups, modifiers).
@MainActor protocol _ChartPrimitive { func _marks() -> [_Mark] }

@MainActor func _resolveMarks<C: ChartContent>(_ c: C) -> [_Mark] {
    if let p = c as? _ChartPrimitive { return p._marks() }
    if C.Body.self == Never.self { return [] }
    return _resolveMarks(c.body)
}
@MainActor func _resolveAny(_ c: any ChartContent) -> [_Mark] { _resolveMarks(c) }

@resultBuilder public struct ChartContentBuilder {
    public static func buildBlock() -> EmptyChartContent { EmptyChartContent() }
    public static func buildBlock<C: ChartContent>(_ content: C) -> C { content }
    public static func buildBlock<each C: ChartContent>(_ content: repeat each C) -> TupleChartContent<(repeat each C)> { TupleChartContent(repeat each content) }
    public static func buildExpression<C: ChartContent>(_ content: C) -> C { content }
    public static func buildOptional<C: ChartContent>(_ content: C?) -> C? { content }
    public static func buildIf<C: ChartContent>(_ content: C?) -> C? { content }
    public static func buildEither<T: ChartContent, F: ChartContent>(first: T) -> _ConditionalChartContent<T, F> { _ConditionalChartContent(first: first) }
    public static func buildEither<T: ChartContent, F: ChartContent>(second: F) -> _ConditionalChartContent<T, F> { _ConditionalChartContent(second: second) }
    public static func buildLimitedAvailability<C: ChartContent>(_ content: C) -> AnyChartContent { AnyChartContent(content) }
}

public struct EmptyChartContent: ChartContent, _ChartPrimitive {
    public init() {}
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [] }
}
public struct TupleChartContent<T>: ChartContent, _ChartPrimitive {
    let children: [any ChartContent]
    init<each C: ChartContent>(_ c: repeat each C) where T == (repeat each C) {
        var list: [any ChartContent] = []
        repeat list.append(each c)
        children = list
    }
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { children.flatMap { _resolveAny($0) } }
}
public struct _ConditionalChartContent<T: ChartContent, F: ChartContent>: ChartContent, _ChartPrimitive {
    let first: T?, second: F?
    init(first: T) { self.first = first; second = nil }
    init(second: F) { first = nil; self.second = second }
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { first.map { _resolveMarks($0) } ?? second.map { _resolveMarks($0) } ?? [] }
}
public struct AnyChartContent: ChartContent, _ChartPrimitive {
    let base: any ChartContent
    public init<C: ChartContent>(_ content: C) { base = content }
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _resolveAny(base) }
}
extension Optional: ChartContent where Wrapped: ChartContent {
    public var body: Never { fatalError() }
}
extension Optional: _ChartPrimitive where Wrapped: ChartContent {
    func _marks() -> [_Mark] { map { _resolveMarks($0) } ?? [] }
}
extension ForEach: ChartContent where Content: ChartContent {
    public var body: Never { fatalError() }
}
extension ForEach: _ChartPrimitive where Content: ChartContent {
    func _marks() -> [_Mark] { data.flatMap { _resolveMarks(content($0)) } }
}
extension ForEach where Content: ChartContent {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ChartContentBuilder content: @escaping (Data.Element) -> Content) {
        self.init(_data: data, _id: { $0[keyPath: id] }, _content: content)
    }
}
extension ForEach where Content: ChartContent, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> Content) {
        self.init(_data: data, _id: { $0.id }, _content: content)
    }
}
extension ForEach where Content: ChartContent, Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @ChartContentBuilder content: @escaping (Int) -> Content) {
        self.init(_data: data, _id: { $0 }, _content: content)
    }
}

// MARK: - Marks

public struct BarMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.bar)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) {
        mark.x = x._pv; mark.y = y._pv; mark.xUnit = x.unit; mark.yUnit = y.unit; mark.width = width; mark.height = height; mark.stacking = stacking
    }
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) {
        mark.xStart = xStart._pv; mark.xEnd = xEnd._pv; mark.y = y._pv; mark.height = height; mark.stacking = .unstacked
    }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) {
        mark.x = x._pv; mark.xUnit = x.unit; mark.yStart = yStart._pv; mark.yEnd = yEnd._pv; mark.width = width; mark.stacking = .unstacked
    }
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {
        mark.xStart = xStart._pv; mark.xEnd = xEnd._pv; mark.yStart = yStart._pv; mark.yEnd = yEnd._pv; mark.stacking = .unstacked
    }
}
public struct LineMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.line)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) { mark.x = x._pv; mark.y = y._pv }
    public init<X: Plottable, Y: Plottable, S: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>) {
        mark.x = x._pv; mark.y = y._pv; mark.series = series._pv.category
    }
}
public struct PointMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.point)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) { mark.x = x._pv; mark.y = y._pv }
}
public struct AreaMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.area)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, stacking: MarkStackingMethod = .standard) {
        mark.x = x._pv; mark.y = y._pv; mark.stacking = stacking
    }
    public init<X: Plottable, Y: Plottable, S: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>, stacking: MarkStackingMethod = .standard) {
        mark.x = x._pv; mark.y = y._pv; mark.series = series._pv.category; mark.stacking = stacking
    }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {
        mark.x = x._pv; mark.yStart = yStart._pv; mark.yEnd = yEnd._pv; mark.stacking = .unstacked
    }
}
public struct RuleMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.rule)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<X: Plottable>(x: PlottableValue<X>) { mark.x = x._pv }
    public init<Y: Plottable>(y: PlottableValue<Y>) { mark.y = y._pv }
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>) { mark.xStart = xStart._pv; mark.xEnd = xEnd._pv; mark.y = y._pv }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) { mark.x = x._pv; mark.yStart = yStart._pv; mark.yEnd = yEnd._pv }
}
public struct RectangleMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.rectangle)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic) {
        mark.x = x._pv; mark.y = y._pv; mark.width = width; mark.height = height
    }
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {
        mark.xStart = xStart._pv; mark.xEnd = xEnd._pv; mark.yStart = yStart._pv; mark.yEnd = yEnd._pv
    }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) {
        mark.x = x._pv; mark.yStart = yStart._pv; mark.yEnd = yEnd._pv; mark.width = width
    }
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) {
        mark.xStart = xStart._pv; mark.xEnd = xEnd._pv; mark.y = y._pv; mark.height = height
    }
}
/// A pie or donut slice; angles are proportional to the values, starting at 12 o'clock, clockwise.
public struct SectorMark: ChartContent, _ChartPrimitive {
    var mark = _Mark(.sector)
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { [mark] }
    public init<V: Plottable>(angle: PlottableValue<V>, innerRadius: MarkDimension = .automatic, outerRadius: MarkDimension = .automatic, angularInset: CGFloat? = nil) {
        mark.angle = angle._pv.number ?? 0; mark.innerRadius = innerRadius; mark.outerRadius = outerRadius; mark.angularInset = angularInset ?? 0
    }
}

// MARK: - Content modifiers

public struct _ChartModified<C: ChartContent>: ChartContent, _ChartPrimitive {
    let content: C
    let change: (inout _Mark) -> Void
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] { _resolveMarks(content).map { var m = $0; change(&m); return m } }
}
extension ChartContent {
    func _modify(_ change: @escaping (inout _Mark) -> Void) -> _ChartModified<Self> { _ChartModified(content: self, change: change) }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> _ChartModified<Self> { _modify { $0.style = AnyShapeStyle(style) } }
    /// Colors marks by a value (series): the default palette or chartForegroundStyleScale, with a legend.
    public func foregroundStyle<D: Plottable>(by value: PlottableValue<D>) -> _ChartModified<Self> { let k = value._pv.category; return _modify { $0.styleKey = k } }
    public func symbol<D: Plottable>(by value: PlottableValue<D>) -> _ChartModified<Self> { let k = value._pv.category; return _modify { $0.symbolKey = k } }
    public func symbol<S: ChartSymbolShape>(_ symbol: S) -> _ChartModified<Self> {
        if let b = symbol as? BasicChartSymbolShape { return _modify { $0.symbol = b; $0.symbolPath = nil; $0.symbolView = nil } }
        let path: (CGRect) -> Path = { symbol.path(in: $0) }
        return _modify { $0.symbolPath = path; $0.symbolView = nil }
    }
    /// A view as the symbol of each point (centered on it).
    public func symbol<V: View>(@ViewBuilder symbol: () -> V) -> _ChartModified<Self> {
        let v = AnyView(symbol())
        return _modify { $0.symbolView = v }
    }
    public func symbolSize(_ size: CGFloat) -> _ChartModified<Self> { _modify { $0.symbolSize = size } }
    /// Sizes symbols by a value through the symbol size scale (chartSymbolSizeScale; default areas 20...200).
    public func symbolSize<D: Plottable>(by value: PlottableValue<D>) -> _ChartModified<Self> {
        let v = value._pv.number ?? 0
        return _modify { $0.symbolSizeValue = v }
    }
    public func symbolSize(_ size: CGSize) -> _ChartModified<Self> { _modify { $0.symbolSize = (size.width * size.height).squareRoot() } }
    public func interpolationMethod(_ method: InterpolationMethod) -> _ChartModified<Self> { _modify { $0.interpolation = method } }
    public func lineStyle(_ style: StrokeStyle) -> _ChartModified<Self> { _modify { $0.lineStyle = style } }
    public func opacity(_ opacity: Double) -> _ChartModified<Self> { _modify { $0.opacity *= opacity } }
    public func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle = .continuous) -> _ChartModified<Self> { _modify { $0.cornerRadius = radius } }
    /// Grouped (side by side) bars by a value.
    public func position<P: Plottable>(by value: PlottableValue<P>, axis: Axis? = nil, span: MarkDimension = .automatic) -> _ChartModified<Self> {
        let k = value._pv.category; return _modify { $0.positionKey = k }
    }
    public func annotation<V: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil,
                                    @ViewBuilder content: () -> V) -> _ChartModified<Self> {
        let a = _Annotation(position: position, alignment: alignment, spacing: spacing, view: AnyView(content()))
        return _modify { $0.annotations.append(a) }
    }
    public func accessibilityLabel(_ label: Text) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityValue(_ value: Text) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityHidden(_ hidden: Bool) -> _ChartModified<Self> { _modify { _ in } }
}
