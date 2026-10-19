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
/// A type-erased symbol shape.
public struct AnyChartSymbolShape: ChartSymbolShape, @unchecked Sendable {
    let shape: (CGRect) -> Path
    public init(_ shape: any ChartSymbolShape) { self.shape = { shape.path(in: $0) } }
    init(path: @escaping (CGRect) -> Path) { shape = path }
    public func path(in rect: CGRect) -> Path { shape(rect) }
}
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
struct _Annotation {
    let position: AnnotationPosition; let alignment: Alignment; let spacing: CGFloat?; let view: AnyView
    var overflow = AnnotationOverflowResolution.automatic
}
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
    var lineStyleKey: String?                  // lineStyle(by:): through chartLineStyleScale or the default dashes
    var opacity = 1.0
    // ChartContent offset / zIndex / mask / clipShape / shadow / blur
    var offset = CGSize.zero
    var rangeOffset: (xStart: CGFloat, xEnd: CGFloat, yStart: CGFloat, yEnd: CGFloat)?
    var zIndex = 0.0
    var maskGroup: Int?                        // drawn through the mask of this group
    var maskOf: Int?                           // a mark of this group's mask: draws into the clip, not the plot
    var clip: (shape: (CGRect) -> Path, eoFill: Bool)?
    var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)?
    var blur: CGFloat = 0
    var cornerRadius: CGFloat = 0
    var positionKey: String?
    var annotations: [_Annotation] = []
    var function: _FunctionPlot?               // LinePlot / AreaPlot of a function: sampled once the x domain is known
    var v3: [_V3]?                             // a 3D mark's x, y, z (values or ranges)
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
    /// Styles lines by a value (series): chartLineStyleScale, else solid, dashed, dotted, ... per value.
    public func lineStyle<D: Plottable>(by value: PlottableValue<D>) -> _ChartModified<Self> { let k = value._pv.category; return _modify { $0.lineStyleKey = k } }
    /// Moves the marks by points (screen coordinates); the range forms move a range mark's edges.
    public func offset(_ offset: CGSize) -> _ChartModified<Self> { _modify { $0.offset.width += offset.width; $0.offset.height += offset.height } }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> _ChartModified<Self> { offset(CGSize(width: x, height: y)) }
    public func offset(x: CGFloat = 0, yStart: CGFloat = 0, yEnd: CGFloat = 0) -> _ChartModified<Self> {
        _modify { $0.offset.width += x; $0.rangeOffset = (0, 0, yStart, yEnd) }
    }
    public func offset(xStart: CGFloat = 0, xEnd: CGFloat = 0, y: CGFloat = 0) -> _ChartModified<Self> {
        _modify { $0.offset.height += y; $0.rangeOffset = (xStart, xEnd, 0, 0) }
    }
    public func offset(xStart: CGFloat = 0, xEnd: CGFloat = 0, yStart: CGFloat = 0, yEnd: CGFloat = 0) -> _ChartModified<Self> {
        _modify { $0.rangeOffset = (xStart, xEnd, yStart, yEnd) }
    }
    /// Draw order: higher above (marks of equal zIndex in the order they are declared).
    public func zIndex(_ value: Double) -> _ChartModified<Self> { _modify { $0.zIndex = value } }
    /// Clips the marks to a shape fitted to the plot area.
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> _ChartModified<Self> {
        let path: (CGRect) -> Path = { shape.path(in: $0) }, eo = style.isEOFilled
        return _modify { $0.clip = (path, eo) }
    }
    public func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> _ChartModified<Self> {
        _modify { $0.shadow = (color, radius, x, y) }
    }
    public func blur(radius: CGFloat) -> _ChartModified<Self> { _modify { $0.blur = radius } }
    /// Shows the marks only where the mask's marks are drawn (laid out on the same scales).
    public func mask<C: ChartContent>(@ChartContentBuilder content: () -> C) -> _ChartMasked<Self, C> { _ChartMasked(content: self, mask: content()) }
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
    /// An annotation kept inside the plot or the chart (`fit`), or allowed to overflow (`disabled`).
    public func annotation<V: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil,
                                    overflowResolution: AnnotationOverflowResolution, @ViewBuilder content: () -> V) -> _ChartModified<Self> {
        var a = _Annotation(position: position, alignment: alignment, spacing: spacing, view: AnyView(content()))
        a.overflow = overflowResolution
        return _modify { $0.annotations.append(a) }
    }
    public func accessibilityLabel(_ label: Text) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityValue(_ value: Text) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> _ChartModified<Self> { _modify { _ in } }
    public func accessibilityHidden(_ hidden: Bool) -> _ChartModified<Self> { _modify { _ in } }
}

/// mask(content:): the content's marks drawn through the mask's
public struct _ChartMasked<C: ChartContent, M: ChartContent>: ChartContent, _ChartPrimitive {
    let content: C, mask: M
    public var body: Never { fatalError() }
    func _marks() -> [_Mark] {
        _maskGroups += 1
        let g = _maskGroups
        return _resolveMarks(content).map { var m = $0; m.maskGroup = m.maskGroup ?? g; return m }
            + _resolveMarks(mask).map { var m = $0; m.maskOf = g; m.annotations = []; return m }
    }
}
@MainActor var _maskGroups = 0

// MARK: - annotation overflow

/// How an annotation that would cross a boundary is placed, per axis: `fit` moves it inside the boundary (the plot,
/// the chart, or automatic: the chart), `disabled` lets it overflow; `padScale` is placed as `fit`. isim's `automatic`
/// places annotations as before, beside their mark, without fitting them.
public struct AnnotationOverflowResolution: Sendable {
    public struct Boundary: Sendable, Equatable {
        let id: Int
        public static let automatic = Boundary(id: 0), plot = Boundary(id: 1), chart = Boundary(id: 2)
    }
    public struct Strategy: Sendable {
        enum Kind: Sendable { case automatic, fit(Boundary), disabled, padScale }
        let kind: Kind
        public static let automatic = Strategy(kind: .automatic)
        public static let fit = Strategy(kind: .fit(.automatic))
        public static func fit(to boundary: Boundary) -> Strategy { Strategy(kind: .fit(boundary)) }
        public static let disabled = Strategy(kind: .disabled)
        public static let padScale = Strategy(kind: .padScale)
        /// the boundary it keeps the annotation in (nil: none)
        var boundary: Boundary? {
            switch kind {
            case .disabled, .automatic: return nil
            case .fit(let b): return b
            case .padScale: return .automatic
            }
        }
    }
    let x: Strategy, y: Strategy
    public init(x: Strategy = .automatic, y: Strategy = .automatic) { self.x = x; self.y = y }
    public static let automatic = AnnotationOverflowResolution(x: .automatic, y: .automatic)
}

// MARK: - bins

/// The range of one bin.
public struct ChartBinRange<Bound: Comparable>: Sendable where Bound: Sendable {
    public let lowerBound: Bound
    public let upperBound: Bound
}

/// Number bins: thresholds splitting a range into bins of nice sizes; bin i is thresholds[i] ..< thresholds[i + 1].
public struct NumberBins<Value: Comparable & Numeric & Sendable>: RandomAccessCollection, Sendable {
    public let thresholds: [Value]
    public init(thresholds: [Value]) { self.thresholds = thresholds.sorted() }
    public var startIndex: Int { 0 }
    public var endIndex: Int { Swift.max(0, thresholds.count - 1) }
    public subscript(i: Int) -> ChartBinRange<Value> { ChartBinRange(lowerBound: thresholds[i], upperBound: thresholds[i + 1]) }
    /// the bin a value falls in (the last bin includes its upper bound); clamped to the bins
    public func index(for value: Value) -> Int {
        guard thresholds.count > 1 else { return 0 }
        var lo = 0, hi = thresholds.count - 1
        while hi - lo > 1 { let mid = (lo + hi) / 2; if value < thresholds[mid] { hi = mid } else { lo = mid } }
        return value < thresholds[0] ? 0 : lo
    }
}
extension NumberBins where Value: BinaryFloatingPoint {
    public init(size: Value, range: ClosedRange<Value>) {
        var t: [Value] = [], v = (range.lowerBound / size).rounded(.down) * size
        while v < range.upperBound && t.count < 10_000 { t.append(v); v += size }
        t.append(v)
        self.init(thresholds: t)
    }
    public init(range: ClosedRange<Value>, count: Int) {
        let n = Swift.max(1, count), step = (range.upperBound - range.lowerBound) / Value(n)
        self.init(thresholds: (0...n).map { range.lowerBound + step * Value($0) })
    }
    public init(range: ClosedRange<Value>, desiredCount: Int, minimumStride: Value = 0) {
        let span = Double(range.upperBound - range.lowerBound)
        let step = Swift.max(Value(_niceStep(span, Swift.max(1, desiredCount))), minimumStride)
        self.init(size: step > 0 ? step : 1, range: range)
    }
    public init(data: [Value], desiredCount: Int? = nil, minimumStride: Value = 0) {
        let lo = data.min() ?? 0, hi = data.max() ?? 1
        self.init(range: lo...Swift.max(hi, lo + 1), desiredCount: desiredCount ?? Int(Double(data.count).squareRoot().rounded(.up)), minimumStride: minimumStride)
    }
}
extension NumberBins where Value: BinaryInteger {
    public init(size: Value, range: ClosedRange<Value>) {
        let s = Swift.max(1, size)
        var t: [Value] = [], v = range.lowerBound - ((range.lowerBound % s) + s) % s
        while v < range.upperBound && t.count < 10_000 { t.append(v); v += s }
        t.append(v)
        self.init(thresholds: t)
    }
    public init(range: ClosedRange<Value>, count: Int) {
        let n = Swift.max(1, count), span = range.upperBound - range.lowerBound
        let step = Swift.max(1, (span + Value(n) - 1) / Value(n))
        self.init(size: step, range: range)
    }
    public init(range: ClosedRange<Value>, desiredCount: Int, minimumStride: Value = 1) {
        let span = Double(range.upperBound - range.lowerBound)
        let step = Swift.max(Value(_niceStep(span, Swift.max(1, desiredCount)).rounded(.up)), Swift.max(1, minimumStride))
        self.init(size: step, range: range)
    }
    public init(data: [Value], desiredCount: Int? = nil, minimumStride: Value = 1) {
        let lo = data.min() ?? 0, hi = data.max() ?? 1
        self.init(range: lo...Swift.max(hi, lo + 1), desiredCount: desiredCount ?? Int(Double(data.count).squareRoot().rounded(.up)), minimumStride: minimumStride)
    }
}

/// Date bins on calendar units (days, weeks, months, ...) or fixed intervals.
public struct DateBins: RandomAccessCollection, Sendable {
    public let thresholds: [Date]
    public init(thresholds: [Date]) { self.thresholds = thresholds.sorted() }
    public init(unit: Calendar.Component, by step: Int = 1, range: ClosedRange<Date>, calendar: Calendar = .current) {
        var d = calendar.dateInterval(of: unit, for: range.lowerBound)?.start ?? range.lowerBound
        var t: [Date] = [d]
        while d < range.upperBound && t.count < 10_000 {
            guard let n = calendar.date(byAdding: unit, value: Swift.max(1, step), to: d), n > d else { break }
            d = n; t.append(d)
        }
        self.init(thresholds: t)
    }
    public init(timeInterval: TimeInterval, range: ClosedRange<Date>) {
        let s = Swift.max(1, timeInterval)
        var v = (range.lowerBound.timeIntervalSinceReferenceDate / s).rounded(.down) * s
        var t: [Date] = []
        while v < range.upperBound.timeIntervalSinceReferenceDate && t.count < 10_000 { t.append(Date(timeIntervalSinceReferenceDate: v)); v += s }
        t.append(Date(timeIntervalSinceReferenceDate: v))
        self.init(thresholds: t)
    }
    /// bins of the calendar unit that gives about `desiredCount` of them
    public init(range: ClosedRange<Date>, desiredCount: Int, calendar: Calendar = .current) {
        let span = range.upperBound.timeIntervalSince(range.lowerBound), want = Double(Swift.max(1, desiredCount))
        let units: [(Calendar.Component, Int, Double)] = [(.second, 1, 1), (.minute, 1, 60), (.minute, 15, 900), (.hour, 1, 3600), (.hour, 6, 21600),
                                                          (.day, 1, 86400), (.weekOfYear, 1, 604800), (.month, 1, 2_629_800), (.quarter, 1, 7_889_400),
                                                          (.year, 1, 31_557_600)]
        let best = units.min { abs(span / $0.2 - want) < abs(span / $1.2 - want) } ?? (.day, 1, 86400)
        self.init(unit: best.0, by: best.1, range: range, calendar: calendar)
    }
    public init(data: [Date], desiredCount: Int? = nil, calendar: Calendar = .current) {
        let lo = data.min() ?? Date(), hi = data.max() ?? lo.addingTimeInterval(86400)
        self.init(range: lo...Swift.max(hi, lo.addingTimeInterval(1)), desiredCount: desiredCount ?? Swift.max(1, Int(Double(data.count).squareRoot().rounded(.up))),
                  calendar: calendar)
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { Swift.max(0, thresholds.count - 1) }
    public subscript(i: Int) -> ChartBinRange<Date> { ChartBinRange(lowerBound: thresholds[i], upperBound: thresholds[i + 1]) }
    public func index(for date: Date) -> Int {
        guard thresholds.count > 1 else { return 0 }
        var lo = 0, hi = thresholds.count - 1
        while hi - lo > 1 { let mid = (lo + hi) / 2; if date < thresholds[mid] { hi = mid } else { lo = mid } }
        return date < thresholds[0] ? 0 : lo
    }
}
