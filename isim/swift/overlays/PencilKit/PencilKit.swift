// isim PencilKit Swift overlay (issue #360): Apple's value types (PKDrawing, PKStroke, PKStrokePath, PKStrokePoint,
// PKInk, the tools) over the Objective-C classes they bridge to (PKDrawingReference, …), the PKTool protocol, and the
// Swift forms of the tool picker's items.
@_exported import PencilKit
import UIKit

// MARK: points and paths

@available(iOS 14.0, *)
public struct PKStrokePoint: Equatable {
    public var location: CGPoint
    public var timeOffset: TimeInterval
    public var size: CGSize
    public var opacity: CGFloat
    public var force: CGFloat
    public var azimuth: CGFloat
    public var altitude: CGFloat
    @available(iOS 17.0, *) public var secondaryScale: CGFloat { get { _secondaryScale } set { _secondaryScale = newValue } }
    @available(iOS 18.0, *) public var threshold: CGFloat { get { _threshold } set { _threshold = newValue } }
    @available(iOS 26.0, *) public var lateralJitter: CGFloat { get { _lateralJitter } set { _lateralJitter = newValue } }
    var _secondaryScale: CGFloat = 1, _threshold: CGFloat = 0, _lateralJitter: CGFloat = 0

    public init(location: CGPoint, timeOffset: TimeInterval, size: CGSize, opacity: CGFloat, force: CGFloat, azimuth: CGFloat,
                altitude: CGFloat) {
        self.location = location; self.timeOffset = timeOffset; self.size = size; self.opacity = opacity
        self.force = force; self.azimuth = azimuth; self.altitude = altitude
    }
    @available(iOS 17.0, *)
    public init(location: CGPoint, timeOffset: TimeInterval, size: CGSize, opacity: CGFloat, force: CGFloat, azimuth: CGFloat,
                altitude: CGFloat, secondaryScale: CGFloat) {
        self.init(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth, altitude: altitude)
        _secondaryScale = secondaryScale
    }
    @available(iOS 18.0, *)
    public init(location: CGPoint, timeOffset: TimeInterval, size: CGSize, opacity: CGFloat, force: CGFloat, azimuth: CGFloat,
                altitude: CGFloat, secondaryScale: CGFloat, threshold: CGFloat) {
        self.init(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth, altitude: altitude)
        _secondaryScale = secondaryScale; _threshold = threshold
    }
    @available(iOS 26.0, *)
    public init(location: CGPoint, timeOffset: TimeInterval, size: CGSize, opacity: CGFloat, force: CGFloat, azimuth: CGFloat,
                altitude: CGFloat, secondaryScale: CGFloat, threshold: CGFloat, lateralJitter: CGFloat) {
        self.init(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth, altitude: altitude)
        _secondaryScale = secondaryScale; _threshold = threshold; _lateralJitter = lateralJitter
    }
}
@available(iOS 14.0, *)
extension PKStrokePoint: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKStrokePointReference {
        if #available(iOS 26.0, *) {
            return PKStrokePointReference(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth,
                                          altitude: altitude, secondaryScale: _secondaryScale, threshold: _threshold, lateralJitter: _lateralJitter)
        }
        if #available(iOS 18.0, *) {
            return PKStrokePointReference(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth,
                                          altitude: altitude, secondaryScale: _secondaryScale, threshold: _threshold)
        }
        if #available(iOS 17.0, *) {
            return PKStrokePointReference(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth,
                                          altitude: altitude, secondaryScale: _secondaryScale)
        }
        return PKStrokePointReference(location: location, timeOffset: timeOffset, size: size, opacity: opacity, force: force, azimuth: azimuth,
                                      altitude: altitude)
    }
    public static func _forceBridgeFromObjectiveC(_ r: PKStrokePointReference, result: inout PKStrokePoint?) {
        var p = PKStrokePoint(location: r.location, timeOffset: r.timeOffset, size: r.size, opacity: r.opacity, force: r.force,
                              azimuth: r.azimuth, altitude: r.altitude)
        if #available(iOS 17.0, *) { p._secondaryScale = r.secondaryScale }
        if #available(iOS 18.0, *) { p._threshold = r.threshold }
        if #available(iOS 26.0, *) { p._lateralJitter = r.lateralJitter }
        result = p
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKStrokePointReference, result: inout PKStrokePoint?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKStrokePointReference?) -> PKStrokePoint {
        var result: PKStrokePoint?; _forceBridgeFromObjectiveC(r!, result: &result); return result!
    }
}

/// A path of stroke points: a collection of its control points, with points interpolated between them.
@available(iOS 14.0, *)
public struct PKStrokePath: RandomAccessCollection {
    var _ref: PKStrokePathReference
    init(_ref: PKStrokePathReference) { self._ref = _ref }

    public init() { _ref = PKStrokePathReference() }
    public init<T: Sequence>(controlPoints: T, creationDate: Date) where T.Element == PKStrokePoint {
        _ref = PKStrokePathReference(controlPoints: Array(controlPoints), creationDate: creationDate)
    }
    @available(iOS 26.0, *)
    public init<T: Sequence>(controlPoints: T, creationDate: Date, id: UUID) where T.Element == PKStrokePoint {
        _ref = PKStrokePathReference(controlPoints: Array(controlPoints), creationDate: creationDate, strokePathID: id)
    }
    /// A path along a Bézier path: `pointProvider` gives the stroke point for each point sampled on it.
    @available(iOS 26.0, *)
    public init(bezierPath: CGPath, creationDate: Date, pointProvider: (PKStrokePath.ConvertedBezierPoint) -> PKStrokePoint) {
        _ref = withoutActuallyEscaping(pointProvider) { provider in
            PKStrokePathReference(bezierPath: bezierPath, creationDate: creationDate, pointProvider: {
                provider(PKStrokePath.ConvertedBezierPoint._unconditionallyBridgeFromObjectiveC($0))
            })
        }
    }

    public typealias Element = PKStrokePoint
    public typealias Index = Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { Int(_ref.count) }
    public subscript(index: Int) -> PKStrokePoint { _ref.point(at: index) }
    /// The part of the path between two parametric values.
    public subscript(range: ClosedRange<CGFloat>) -> PKStrokePath {
        _ref.subpath(with: __PKFloatRange(lowerBound: range.lowerBound, upperBound: range.upperBound))
    }

    public var creationDate: Date { _ref.creationDate }
    @available(iOS 26.0, *) public var id: UUID { _ref.strokePathID }
    @available(iOS 26.0, *) public var bezierRepresentation: CGPath { _ref.bezierRepresentation }

    public func interpolatedLocation(at parametricValue: CGFloat) -> CGPoint { _ref.interpolatedLocation(at: parametricValue) }
    public func interpolatedPoint(at parametricValue: CGFloat) -> PKStrokePoint { _ref.interpolatedPoint(at: parametricValue) }
    public func parametricValue(_ parametricValue: CGFloat, offsetBy step: InterpolatedSlice.Stride) -> CGFloat {
        switch step {
        case .distance(let d): return _ref.parametricValue(parametricValue, offsetByDistance: d)
        case .time(let t): return _ref.parametricValue(parametricValue, offsetByTime: t)
        case .parametricStep(let s): return Swift.min(Swift.max(parametricValue + s, 0), CGFloat(Swift.max(count - 1, 0)))
        }
    }
    /// The points interpolated along the path (all of it when `range` is nil), `stride` apart.
    public func interpolatedPoints(in range: ClosedRange<CGFloat>? = nil, by stride: InterpolatedSlice.Stride) -> InterpolatedSlice {
        InterpolatedSlice(path: self, range: range ?? 0...CGFloat(Swift.max(count - 1, 0)), stride: stride)
    }

    /// Points interpolated along a stroke path.
    public struct InterpolatedSlice: Sequence {
        public enum Stride {
            case distance(CGFloat)
            case time(TimeInterval)
            case parametricStep(CGFloat)
        }
        let path: PKStrokePath, range: ClosedRange<CGFloat>, stride: Stride
        public typealias Element = PKStrokePoint
        public struct Iterator: IteratorProtocol {
            var points: IndexingIterator<[PKStrokePoint]>
            public mutating func next() -> PKStrokePoint? { points.next() }
        }
        public func makeIterator() -> Iterator {
            var points: [PKStrokePoint] = []
            let r = __PKFloatRange(lowerBound: range.lowerBound, upperBound: range.upperBound)
            let add: (PKStrokePoint, UnsafeMutablePointer<ObjCBool>) -> Void = { p, _ in points.append(p) }
            switch stride {
            case .distance(let d): path._ref.enumerateInterpolatedPoints(in: r, strideByDistance: d, using: add)
            case .time(let t): path._ref.enumerateInterpolatedPoints(in: r, strideByTime: t, using: add)
            case .parametricStep(let s): path._ref.enumerateInterpolatedPoints(in: r, strideByParametricStep: s, using: add)
            }
            return Iterator(points: points.makeIterator())
        }
    }

    /// A point of a Bézier path being converted to a stroke path.
    @available(iOS 26.0, *)
    public struct ConvertedBezierPoint {
        public let index: Int
        public let pointCount: Int
        public let location: CGPoint
        public let bezierSegmentIndex: Int
    }
}
@available(iOS 14.0, *)
extension PKStrokePath: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKStrokePathReference { _ref }
    public static func _forceBridgeFromObjectiveC(_ r: PKStrokePathReference, result: inout PKStrokePath?) {
        result = PKStrokePath(_ref: r.copy() as! PKStrokePathReference)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKStrokePathReference, result: inout PKStrokePath?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKStrokePathReference?) -> PKStrokePath {
        PKStrokePath(_ref: r!.copy() as! PKStrokePathReference)
    }
}
@available(iOS 26.0, *)
extension PKStrokePath.ConvertedBezierPoint: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKConvertedBezierPointReference {
        fatalError("PKStrokePath.ConvertedBezierPoint is made by PencilKit only")
    }
    public static func _forceBridgeFromObjectiveC(_ r: PKConvertedBezierPointReference, result: inout PKStrokePath.ConvertedBezierPoint?) {
        result = .init(index: r.index, pointCount: r.pointCount, location: r.location, bezierSegmentIndex: r.bezierSegmentIndex)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKConvertedBezierPointReference,
                                                          result: inout PKStrokePath.ConvertedBezierPoint?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKConvertedBezierPointReference?) -> PKStrokePath.ConvertedBezierPoint {
        var result: PKStrokePath.ConvertedBezierPoint?; _forceBridgeFromObjectiveC(r!, result: &result); return result!
    }
}

// MARK: inks and strokes

@available(iOS 14.0, *)
public struct PKInk: Equatable {
    public typealias InkType = PKInkingTool.InkType
    public var inkType: InkType
    public var color: UIColor
    public init(_ type: InkType, color: UIColor) { inkType = type; self.color = color }
    @available(iOS 17.0, *) public var requiredContentVersion: PKContentVersion { inkType.requiredContentVersion }
}
@available(iOS 14.0, *)
extension PKInk: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKInkReference { PKInkReference(inkType: __PKInkType(rawValue: inkType.rawValue), color: color) }
    public static func _forceBridgeFromObjectiveC(_ r: PKInkReference, result: inout PKInk?) {
        result = PKInk(InkType(rawValue: r.inkType.rawValue) ?? .pen, color: r.color)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKInkReference, result: inout PKInk?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKInkReference?) -> PKInk {
        var result: PKInk?; _forceBridgeFromObjectiveC(r!, result: &result); return result!
    }
}

@available(iOS 14.0, *)
public struct PKStroke {
    public var ink: PKInk
    public var path: PKStrokePath
    public var transform: CGAffineTransform
    public var mask: UIBezierPath?
    @available(iOS 16.0, *) public var randomSeed: UInt32 { get { _randomSeed } set { _randomSeed = newValue } }
    @available(iOS 26.0, *) public var id: UUID { get { _id } set { _id = newValue } }
    @available(iOS 26.0, *) public var renderGroupID: UUID? { get { _renderGroupID } set { _renderGroupID = newValue } }
    @available(iOS 26.0, *) public var renderState: RenderState? { get { _renderState as? RenderState } set { _renderState = newValue } }
    var _randomSeed: UInt32 = 0, _id = UUID(), _renderGroupID: UUID?, _renderState: Any?

    public init(ink: PKInk, path: PKStrokePath, transform: CGAffineTransform = .identity, mask: UIBezierPath? = nil) {
        self.ink = ink; self.path = path; self.transform = transform; self.mask = mask
        _randomSeed = UInt32.random(in: 1...UInt32.max)
    }
    @available(iOS 16.0, *)
    public init(ink: PKInk, path: PKStrokePath, transform: CGAffineTransform = .identity, mask: UIBezierPath? = nil, randomSeed: UInt32) {
        self.init(ink: ink, path: path, transform: transform, mask: mask)
        _randomSeed = randomSeed
    }
    @available(iOS 26.0, *)
    public init(ink: PKInk, path: PKStrokePath, transform: CGAffineTransform = .identity, mask: UIBezierPath? = nil, randomSeed: UInt32,
                id: UUID, renderGroupID: UUID? = nil, renderState: RenderState? = nil) {
        self.init(ink: ink, path: path, transform: transform, mask: mask)
        _randomSeed = randomSeed; _id = id; _renderGroupID = renderGroupID; _renderState = renderState
    }

    /// The bounds of the stroke as drawn, in drawing coordinates.
    public var renderBounds: CGRect { _bridgeToObjectiveC().renderBounds }
    /// The parametric ranges of the path that the mask leaves visible.
    public var maskedPathRanges: [ClosedRange<CGFloat>] {
        _bridgeToObjectiveC().maskedPathRanges.map { $0.lowerBound...$0.upperBound }
    }
    @available(iOS 17.0, *) public var requiredContentVersion: PKContentVersion { _bridgeToObjectiveC().requiredContentVersion }
    /// The part of the stroke between two parametric values of its path.
    @available(iOS 26.0, *)
    public func substroke(range: ClosedRange<CGFloat>) -> PKStroke {
        _bridgeToObjectiveC().substroke(with: __PKFloatRange(lowerBound: range.lowerBound, upperBound: range.upperBound))
    }

    /// How a stroke's ink was laid down (the grain of textured inks).
    @available(iOS 26.0, *)
    public struct RenderState {
        public var grainOffset: CGPoint?
        public init(grainOffset: CGPoint?) { self.grainOffset = grainOffset }
        public init(_ reference: PKStrokeRenderStateReference) { grainOffset = reference.grainOffset }
    }
}
@available(iOS 14.0, *)
extension PKStroke: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKStrokeReference {
        if #available(iOS 26.0, *) {
            return PKStrokeReference(ink: ink, strokePath: path, transform: transform, mask: mask, randomSeed: _randomSeed, strokeID: _id,
                                     renderGroupID: _renderGroupID, renderState: renderState?._bridgeToObjectiveC())
        }
        if #available(iOS 16.0, *) {
            return PKStrokeReference(ink: ink, strokePath: path, transform: transform, mask: mask, randomSeed: _randomSeed)
        }
        return PKStrokeReference(ink: ink, strokePath: path, transform: transform, mask: mask)
    }
    public static func _forceBridgeFromObjectiveC(_ r: PKStrokeReference, result: inout PKStroke?) {
        var s = PKStroke(ink: r.ink, path: r.path, transform: r.transform, mask: r.mask)
        if #available(iOS 16.0, *) { s._randomSeed = r.randomSeed }
        if #available(iOS 26.0, *) {
            s._id = r.strokeID; s._renderGroupID = r.renderGroupID; s._renderState = r.renderState.map(PKStroke.RenderState.init)
        }
        result = s
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKStrokeReference, result: inout PKStroke?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKStrokeReference?) -> PKStroke {
        var result: PKStroke?; _forceBridgeFromObjectiveC(r!, result: &result); return result!
    }
}
@available(iOS 26.0, *)
extension PKStroke.RenderState: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKStrokeRenderStateReference { PKStrokeRenderStateReference(grainOffset: grainOffset ?? .zero) }
    public static func _forceBridgeFromObjectiveC(_ r: PKStrokeRenderStateReference, result: inout PKStroke.RenderState?) {
        result = PKStroke.RenderState(r)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKStrokeRenderStateReference, result: inout PKStroke.RenderState?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKStrokeRenderStateReference?) -> PKStroke.RenderState {
        PKStroke.RenderState(r!)
    }
}

// MARK: drawings

/// A drawing: strokes in order. isim: `dataRepresentation()` is isim's own format, not an Apple device's.
@available(iOS 13.0, *)
public struct PKDrawing {
    var _ref: PKDrawingReference
    init(_ref: PKDrawingReference) { self._ref = _ref }

    public init() { _ref = PKDrawingReference() }
    @available(iOS 14.0, *)
    public init<S: Sequence>(strokes: S) where S.Element == PKStroke { _ref = PKDrawingReference(strokes: Array(strokes)) }
    public init(data: Data) throws { _ref = try PKDrawingReference(data: data) }

    @available(iOS 14.0, *)
    public var strokes: [PKStroke] {
        get { _ref.strokes }
        set { _ref = PKDrawingReference(strokes: newValue) }
    }
    public var bounds: CGRect { _ref.bounds }
    @available(iOS 17.0, *) public var requiredContentVersion: PKContentVersion { _ref.requiredContentVersion }
    public func dataRepresentation() -> Data { _ref.dataRepresentation() }
    public func image(from rect: CGRect, scale: CGFloat) -> UIImage { _ref.image(from: rect, scale: scale) }
    /// Draws the part of the drawing in `from` into `frame` of the context.
    @available(iOS 26.0, *)
    public func draw(in context: CGContext, frame: CGRect, from: CGRect, darkUserInterfaceStyle: Bool) async {
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: darkUserInterfaceStyle ? .dark : .light).performAsCurrent {
            image = self.image(from: from, scale: from.width > 0 ? frame.width / from.width : 1)
        }
        guard let cg = image?.cgImage else { return }
        context.saveGState()
        context.translateBy(x: frame.minX, y: frame.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(cg, in: CGRect(origin: .zero, size: frame.size))
        context.restoreGState()
    }

    public func transformed(using transform: CGAffineTransform) -> PKDrawing { _ref.applying(transform) }
    public mutating func transform(using transform: CGAffineTransform) { _ref = _ref.applying(transform)._ref }
    public func appending(_ drawing: PKDrawing) -> PKDrawing { _ref.appending(drawing) }
    public mutating func append(_ drawing: PKDrawing) { _ref = _ref.appending(drawing)._ref }
    @available(iOS 26.0, *)
    public func erasingPath(_ path: PKStrokePath, mask: UIBezierPath? = nil, transform: CGAffineTransform = .identity) -> PKDrawing {
        _ref.erasingStrokePath(path, mask: mask, transform: transform)
    }
    @available(iOS 26.0, *)
    public mutating func erasePath(_ path: PKStrokePath, mask: UIBezierPath? = nil, transform: CGAffineTransform = .identity) {
        _ref = _ref.erasingStrokePath(path, mask: mask, transform: transform)._ref
    }
}
@available(iOS 13.0, *)
extension PKDrawing: Equatable {
    public static func == (a: PKDrawing, b: PKDrawing) -> Bool { a._ref === b._ref || a._ref.isEqual(b._ref) }
}
@available(iOS 13.0, *)
extension PKDrawing: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKDrawingReference { _ref }
    public static func _forceBridgeFromObjectiveC(_ r: PKDrawingReference, result: inout PKDrawing?) {
        result = PKDrawing(_ref: r.copy() as! PKDrawingReference)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKDrawingReference, result: inout PKDrawing?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKDrawingReference?) -> PKDrawing {
        PKDrawing(_ref: r.map { $0.copy() as! PKDrawingReference } ?? PKDrawingReference())
    }
}

@available(iOS 17.0, *)
extension PKContentVersion {
    /// The newest version (all of PencilKit's features).
    public static var latest: PKContentVersion { .version5 }
}

// MARK: tools

/// A tool a canvas draws, erases or selects with: PKInkingTool, PKEraserTool or PKLassoTool.
@available(iOS 13.0, *)
public protocol PKTool {}

@available(iOS 13.0, *)
func _pkToolReference(_ tool: any PKTool) -> __PKTool {
    switch tool {
    case let t as PKInkingTool: return t._bridgeToObjectiveC()
    case let t as PKEraserTool: return t._bridgeToObjectiveC()
    case let t as PKLassoTool: return t._bridgeToObjectiveC()
    default: fatalError("\(type(of: tool)) is not a PencilKit tool")
    }
}
@available(iOS 13.0, *)
func _pkTool(_ reference: __PKTool) -> any PKTool {
    switch reference {
    case let r as PKInkingToolReference: return PKInkingTool._unconditionallyBridgeFromObjectiveC(r)
    case let r as PKEraserToolReference: return PKEraserTool._unconditionallyBridgeFromObjectiveC(r)
    default: return PKLassoTool()
    }
}

@available(iOS 13.0, *)
public struct PKInkingTool: PKTool, Equatable {
    public enum InkType: String, Hashable, Sendable {
        case pen = "com.apple.ink.pen"
        case pencil = "com.apple.ink.pencil"
        case marker = "com.apple.ink.marker"
        @available(iOS 17.0, *) case monoline = "com.apple.ink.monoline"
        @available(iOS 17.0, *) case fountainPen = "com.apple.ink.fountainpen"
        @available(iOS 17.0, *) case watercolor = "com.apple.ink.watercolor"
        @available(iOS 17.0, *) case crayon = "com.apple.ink.crayon"
        @available(iOS 26.0, *) case reed = "com.apple.ink.reed"

        var _objc: __PKInkType { __PKInkType(rawValue: rawValue) }
        public var defaultWidth: CGFloat { PKInkingToolReference.defaultWidth(forInkType: _objc) }
        public var validWidthRange: ClosedRange<CGFloat> {
            PKInkingToolReference.minimumWidth(forInkType: _objc)...PKInkingToolReference.maximumWidth(forInkType: _objc)
        }
        @available(iOS 17.0, *)
        public var requiredContentVersion: PKContentVersion { PKInkReference(inkType: _objc, color: .black).requiredContentVersion }
    }

    public var inkType: InkType
    public var color: UIColor
    public var width: CGFloat
    @available(iOS 17.0, *) public var azimuth: CGFloat { get { _azimuth } set { _azimuth = newValue } }
    var _azimuth: CGFloat = 0

    public init(_ type: InkType, color: UIColor = .black, width: CGFloat? = nil) {
        inkType = type; self.color = color
        let w = width ?? type.defaultWidth, r = type.validWidthRange
        self.width = Swift.min(Swift.max(w, r.lowerBound), r.upperBound)
    }
    @available(iOS 17.0, *)
    public init(_ type: InkType, color: UIColor = .black, width: CGFloat? = nil, azimuth: CGFloat) {
        self.init(type, color: color, width: width)
        _azimuth = azimuth
    }
    @available(iOS 14.0, *)
    public init(ink: PKInk, width: CGFloat) { self.init(ink.inkType, color: ink.color, width: width) }

    @available(iOS 14.0, *) public var ink: PKInk { PKInk(inkType, color: color) }
    @available(iOS 17.0, *) public var requiredContentVersion: PKContentVersion { inkType.requiredContentVersion }

    /// A color as the other interface style shows it (dark inks lighten in dark mode, and back).
    @available(iOS 14.0, *)
    public static func convertColor(_ color: UIColor, from: UIUserInterfaceStyle, to: UIUserInterfaceStyle) -> UIColor {
        PKInkingToolReference.convert(color, from: from, to: to)
    }
}
@available(iOS 13.0, *)
extension PKInkingTool: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKInkingToolReference {
        PKInkingToolReference(inkType: inkType._objc, color: color, width: width, azimuth: _azimuth)
    }
    public static func _forceBridgeFromObjectiveC(_ r: PKInkingToolReference, result: inout PKInkingTool?) {
        var t = PKInkingTool(InkType(rawValue: r.inkType.rawValue) ?? .pen, color: r.color, width: r.width)
        t._azimuth = r.azimuth
        result = t
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKInkingToolReference, result: inout PKInkingTool?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKInkingToolReference?) -> PKInkingTool {
        var result: PKInkingTool?; _forceBridgeFromObjectiveC(r!, result: &result); return result!
    }
}

@available(iOS 13.0, *)
public struct PKEraserTool: PKTool, Equatable {
    public enum EraserType: Int, Hashable, Sendable {
        case vector, bitmap
        @available(iOS 16.4, *) case fixedWidthBitmap

        var _objc: __PKEraserType { __PKEraserType(rawValue: rawValue)! }
        @available(iOS 16.4, *) public var defaultWidth: CGFloat { PKEraserToolReference.defaultWidth(for: _objc) }
        @available(iOS 16.4, *)
        public var validWidthRange: ClosedRange<CGFloat> {
            PKEraserToolReference.minimumWidth(for: _objc)...PKEraserToolReference.maximumWidth(for: _objc)
        }
    }
    public var eraserType: EraserType
    @available(iOS 16.4, *) public var width: CGFloat { get { _width } set { _width = newValue } }
    var _width: CGFloat

    public init(_ type: EraserType) { eraserType = type; _width = PKEraserToolReference.defaultWidth(for: type._objc) }
    @available(iOS 16.4, *)
    public init(_ type: EraserType, width: CGFloat) {
        eraserType = type
        _width = Swift.min(Swift.max(width, type.validWidthRange.lowerBound), type.validWidthRange.upperBound)
    }
}
@available(iOS 13.0, *)
extension PKEraserTool: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKEraserToolReference { PKEraserToolReference(eraserType: eraserType._objc, width: _width) }
    public static func _forceBridgeFromObjectiveC(_ r: PKEraserToolReference, result: inout PKEraserTool?) {
        var t = PKEraserTool(EraserType(rawValue: r.eraserType.rawValue) ?? .vector)
        t._width = r.width
        result = t
    }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKEraserToolReference, result: inout PKEraserTool?) -> Bool {
        _forceBridgeFromObjectiveC(r, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKEraserToolReference?) -> PKEraserTool {
        var result: PKEraserTool?; _forceBridgeFromObjectiveC(r!, result: &result); return result!
    }
}

@available(iOS 13.0, *)
public struct PKLassoTool: PKTool, Equatable {
    public init() {}
}
@available(iOS 13.0, *)
extension PKLassoTool: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> PKLassoToolReference { PKLassoToolReference() }
    public static func _forceBridgeFromObjectiveC(_ r: PKLassoToolReference, result: inout PKLassoTool?) { result = PKLassoTool() }
    public static func _conditionallyBridgeFromObjectiveC(_ r: PKLassoToolReference, result: inout PKLassoTool?) -> Bool {
        result = PKLassoTool(); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ r: PKLassoToolReference?) -> PKLassoTool { PKLassoTool() }
}

// MARK: the canvas and the tool picker

@available(iOS 13.0, *)
extension PKCanvasView {
    /// The tool touches draw, erase or select with.
    public var tool: any PKTool {
        get { _pkTool(__tool) }
        set { __tool = _pkToolReference(newValue) }
    }
}

@available(iOS 13.0, *)
extension PKToolPicker {
    @available(iOS, introduced: 13.0, deprecated: 18.0, message: "use selectedToolItem")
    public var selectedTool: any PKTool {
        get { _pkTool(__selectedTool) }
        set { __selectedTool = _pkToolReference(newValue) }
    }
}

@available(iOS 18.0, *)
extension PKToolPickerItem {
    /// The tool the item selects (none for the ruler and Scribble).
    public var tool: (any PKTool)? { __tool.map(_pkTool) }
}

@available(iOS 18.0, *)
extension PKToolPickerInkingItem {
    public convenience init(type: PKInkingTool.InkType, color: UIColor? = nil, width: CGFloat? = nil, identifier: String? = nil) {
        self.init(__inkType: type._objc, color: color, width: width ?? 0, identifier: identifier)
    }
    @available(iOS 26.0, *)
    public convenience init(type: PKInkingTool.InkType, color: UIColor? = nil, width: CGFloat? = nil, azimuth: CGFloat? = nil,
                            identifier: String? = nil) {
        self.init(__inkType: type._objc, color: color, width: width ?? 0, azimuth: azimuth ?? 0, identifier: identifier)
    }
}

@available(iOS 18.0, *)
extension PKToolPickerEraserItem {
    public convenience init(type: PKEraserTool.EraserType) { self.init(__eraserType: type._objc) }
    public convenience init(type: PKEraserTool.EraserType, width: CGFloat) { self.init(__eraserType: type._objc, width: width) }
}

@available(iOS 18.0, *)
extension PKToolPickerCustomItem {
    /// A custom item's settings.
    public struct Configuration {
        public var identifier: String
        public var name: String
        public var imageProvider: ((PKToolPickerCustomItem) -> UIImage)?
        public var viewControllerProvider: ((PKToolPickerCustomItem) -> UIViewController)?
        public var defaultColor: UIColor = .black
        public var allowsColorSelection: Bool = true
        public var defaultWidth: CGFloat = 4
        public var widthVariants: [CGFloat: UIImage] = [:]
        public var toolAttributeControls: PKToolPickerCustomItem.ControlOptions = []
        public init(identifier: String, name: String) { self.identifier = identifier; self.name = name }

        var _objc: __PKToolPickerCustomItemConfiguration {
            let c = __PKToolPickerCustomItemConfiguration(identifier: identifier, name: name)
            c.imageProvider = imageProvider
            c.viewControllerProvider = viewControllerProvider
            c.defaultColor = defaultColor
            c.allowsColorSelection = allowsColorSelection
            c.defaultWidth = defaultWidth
            c.widthVariants = Dictionary(uniqueKeysWithValues: widthVariants.map { (NSNumber(value: Double($0.key)), $0.value) })
            c.toolAttributeControls = toolAttributeControls
            return c
        }
        init(_ c: __PKToolPickerCustomItemConfiguration) {
            identifier = c.identifier; name = c.name
            imageProvider = c.imageProvider; viewControllerProvider = c.viewControllerProvider
            defaultColor = c.defaultColor; allowsColorSelection = c.allowsColorSelection; defaultWidth = c.defaultWidth
            widthVariants = Dictionary(uniqueKeysWithValues: c.widthVariants.map { (CGFloat($0.key.doubleValue), $0.value) })
            toolAttributeControls = c.toolAttributeControls
        }
    }
    public convenience init(configuration: Configuration) { self.init(__configuration: configuration._objc) }
    public var configuration: Configuration { Configuration(__configuration) }
}
