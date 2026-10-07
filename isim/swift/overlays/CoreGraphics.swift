// isim CoreGraphics Swift overlay (self-authored): the Swift-side geometry API.
// CGFloat is imported from C as Double (64-bit CGFloat has the same representation);
// isim keeps it a typealias rather than Apple's distinct struct.
@_exported import CoreGraphics

public typealias CGFloat = Double

extension CGPoint: Equatable, Hashable, CustomStringConvertible {
    public static var zero: CGPoint { CGPoint(x: 0, y: 0) }
    public init(x: Int, y: Int) { self.init(x: CGFloat(x), y: CGFloat(y)) }
    public static func == (a: CGPoint, b: CGPoint) -> Bool { a.x == b.x && a.y == b.y }
    public func hash(into h: inout Hasher) { h.combine(x); h.combine(y) }
    public var description: String { "(\(x), \(y))" }
    public func applying(_ t: CGAffineTransform) -> CGPoint { CGPointApplyAffineTransform(self, t) }
}
extension CGSize: Equatable, Hashable, CustomStringConvertible {
    public static var zero: CGSize { CGSize(width: 0, height: 0) }
    public init(width: Int, height: Int) { self.init(width: CGFloat(width), height: CGFloat(height)) }
    public static func == (a: CGSize, b: CGSize) -> Bool { a.width == b.width && a.height == b.height }
    public func hash(into h: inout Hasher) { h.combine(width); h.combine(height) }
    public var description: String { "(\(width), \(height))" }
}
extension CGVector: Equatable {
    public static var zero: CGVector { CGVector(dx: 0, dy: 0) }
    public static func == (a: CGVector, b: CGVector) -> Bool { a.dx == b.dx && a.dy == b.dy }
}
extension CGRect: Equatable, Hashable, CustomStringConvertible {
    public static var zero: CGRect { CGRect(origin: .zero, size: .zero) }
    public static var null: CGRect { CGRectNull }
    public static var infinite: CGRect { CGRectInfinite }
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) { self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height)) }
    public init(x: Int, y: Int, width: Int, height: Int) { self.init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height)) }
    public static func == (a: CGRect, b: CGRect) -> Bool { a.origin == b.origin && a.size == b.size }
    public func hash(into h: inout Hasher) { h.combine(origin); h.combine(size) }
    public var description: String { "(\(origin.x), \(origin.y), \(size.width), \(size.height))" }
    public var width: CGFloat { CGRectGetWidth(self) }
    public var height: CGFloat { CGRectGetHeight(self) }
    public var minX: CGFloat { CGRectGetMinX(self) }
    public var midX: CGFloat { CGRectGetMidX(self) }
    public var maxX: CGFloat { CGRectGetMaxX(self) }
    public var minY: CGFloat { CGRectGetMinY(self) }
    public var midY: CGFloat { CGRectGetMidY(self) }
    public var maxY: CGFloat { CGRectGetMaxY(self) }
    public var isEmpty: Bool { CGRectIsEmpty(self) }
    public var isNull: Bool { CGRectIsNull(self) }
    public var standardized: CGRect { CGRectStandardize(self) }
    public var integral: CGRect { CGRectIntegral(self) }
    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect { CGRectInset(self, dx, dy) }
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect { CGRectOffset(self, dx, dy) }
    public func union(_ r: CGRect) -> CGRect { CGRectUnion(self, r) }
    public func intersection(_ r: CGRect) -> CGRect { CGRectIntersection(self, r) }
    public func intersects(_ r: CGRect) -> Bool { CGRectIntersectsRect(self, r) }
    public func contains(_ p: CGPoint) -> Bool { CGRectContainsPoint(self, p) }
    public func contains(_ r: CGRect) -> Bool { CGRectContainsRect(self, r) }
    public mutating func formUnion(_ r: CGRect) { self = union(r) }
    public mutating func formIntersection(_ r: CGRect) { self = intersection(r) }
}
extension CGAffineTransform: Equatable {
    public static var identity: CGAffineTransform { CGAffineTransformIdentity }
    public init(translationX tx: CGFloat, y ty: CGFloat) { self = CGAffineTransformMakeTranslation(tx, ty) }
    public init(scaleX sx: CGFloat, y sy: CGFloat) { self = CGAffineTransformMakeScale(sx, sy) }
    public init(rotationAngle angle: CGFloat) { self = CGAffineTransformMakeRotation(angle) }
    public var isIdentity: Bool { CGAffineTransformIsIdentity(self) }
    public func concatenating(_ t: CGAffineTransform) -> CGAffineTransform { CGAffineTransformConcat(self, t) }
    public func translatedBy(x: CGFloat, y: CGFloat) -> CGAffineTransform { CGAffineTransform(translationX: x, y: y).concatenating(self) }
    public func scaledBy(x: CGFloat, y: CGFloat) -> CGAffineTransform { CGAffineTransform(scaleX: x, y: y).concatenating(self) }
    public func rotated(by angle: CGFloat) -> CGAffineTransform { CGAffineTransform(rotationAngle: angle).concatenating(self) }
    public static func == (a: CGAffineTransform, b: CGAffineTransform) -> Bool {
        a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d && a.tx == b.tx && a.ty == b.ty
    }
}
extension CGAffineTransform {
    public func inverted() -> CGAffineTransform { CGAffineTransformInvert(self) }
}
extension CGSize {
    public func applying(_ t: CGAffineTransform) -> CGSize { CGSizeApplyAffineTransform(self, t) }
}
extension CGRect {
    public func applying(_ t: CGAffineTransform) -> CGRect { CGRectApplyAffineTransform(self, t) }
}

// MARK: - CGPath (Apple's Swift API over the C functions)
extension CGPath {
    public var boundingBox: CGRect { CGPathGetBoundingBox(self) }
    public var boundingBoxOfPath: CGRect { CGPathGetPathBoundingBox(self) }
    public var isEmpty: Bool { CGPathIsEmpty(self) }
    public var currentPoint: CGPoint { CGPathGetCurrentPoint(self) }
    public func copy() -> CGPath? { CGPathCreateCopy(self) }
    public func mutableCopy() -> CGMutablePath? { CGPathCreateMutableCopy(self) }
    public func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding, transform: CGAffineTransform = .identity) -> Bool {
        var t = transform
        return CGPathContainsPoint(self, &t, point, rule == .evenOdd)
    }
    public func applyWithBlock(_ block: (UnsafePointer<CGPathElement>) -> Void) {
        withoutActuallyEscaping(block) { b in
            var ctx = b
            withUnsafeMutablePointer(to: &ctx) { p in
                CGPathApply(self, p) { info, el in
                    guard let info else { return }
                    info.assumingMemoryBound(to: ((UnsafePointer<CGPathElement>) -> Void).self).pointee(el)
                }
            }
        }
    }
}
public enum CGPathFillRule: Int, Sendable { case winding, evenOdd }

extension CGMutablePath {
    public func move(to p: CGPoint, transform: CGAffineTransform = .identity) { var t = transform; CGPathMoveToPoint(self, &t, p.x, p.y) }
    public func addLine(to p: CGPoint, transform: CGAffineTransform = .identity) { var t = transform; CGPathAddLineToPoint(self, &t, p.x, p.y) }
    public func addLines(between points: [CGPoint], transform: CGAffineTransform = .identity) {
        for (i, p) in points.enumerated() { if i == 0 { move(to: p, transform: transform) } else { addLine(to: p, transform: transform) } }
    }
    public func addQuadCurve(to end: CGPoint, control: CGPoint, transform: CGAffineTransform = .identity) {
        var t = transform; CGPathAddQuadCurveToPoint(self, &t, control.x, control.y, end.x, end.y)
    }
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint, transform: CGAffineTransform = .identity) {
        var t = transform; CGPathAddCurveToPoint(self, &t, control1.x, control1.y, control2.x, control2.y, end.x, end.y)
    }
    public func addRect(_ r: CGRect, transform: CGAffineTransform = .identity) { var t = transform; CGPathAddRect(self, &t, r) }
    public func addRects(_ rs: [CGRect], transform: CGAffineTransform = .identity) { for r in rs { addRect(r, transform: transform) } }
    public func addEllipse(in r: CGRect, transform: CGAffineTransform = .identity) { var t = transform; CGPathAddEllipseInRect(self, &t, r) }
    public func addRoundedRect(in r: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: CGAffineTransform = .identity) {
        var t = transform; CGPathAddRoundedRect(self, &t, r, cornerWidth, cornerHeight)
    }
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool, transform: CGAffineTransform = .identity) {
        var t = transform; CGPathAddArc(self, &t, center.x, center.y, radius, startAngle, endAngle, clockwise)
    }
    public func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, delta: CGFloat, transform: CGAffineTransform = .identity) {
        var t = transform; CGPathAddRelativeArc(self, &t, center.x, center.y, radius, startAngle, delta)
    }
    public func addPath(_ path: CGPath, transform: CGAffineTransform = .identity) { var t = transform; CGPathAddPath(self, &t, path) }
    public func closeSubpath() { CGPathCloseSubpath(self) }
}


// MARK: - CGContext (Apple's Swift API)
extension CGContext {
    public func saveGState() { CGContextSaveGState(self) }
    public func restoreGState() { CGContextRestoreGState(self) }
    public func translateBy(x: CGFloat, y: CGFloat) { CGContextTranslateCTM(self, x, y) }
    public func scaleBy(x: CGFloat, y: CGFloat) { CGContextScaleCTM(self, x, y) }
    public func rotate(by angle: CGFloat) { CGContextRotateCTM(self, angle) }
    public func concatenate(_ t: CGAffineTransform) { CGContextConcatCTM(self, t) }
    public func setFillColor(_ c: CGColor) { CGContextSetFillColorWithColor(self, c) }
    public func setStrokeColor(_ c: CGColor) { CGContextSetStrokeColorWithColor(self, c) }
    public func setFillColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { CGContextSetRGBFillColor(self, red, green, blue, alpha) }
    public func setStrokeColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { CGContextSetRGBStrokeColor(self, red, green, blue, alpha) }
    public func setLineWidth(_ w: CGFloat) { CGContextSetLineWidth(self, w) }
    public func setLineCap(_ cap: CGLineCap) { CGContextSetLineCap(self, cap) }
    public func setLineJoin(_ join: CGLineJoin) { CGContextSetLineJoin(self, join) }
    public func setMiterLimit(_ limit: CGFloat) { CGContextSetMiterLimit(self, limit) }
    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) { CGContextSetLineDash(self, phase, lengths, lengths.count) }
    public func setAlpha(_ a: CGFloat) { CGContextSetAlpha(self, a) }
    public var interpolationQuality: CGInterpolationQuality {
        get { CGContextGetInterpolationQuality(self) }
        set { CGContextSetInterpolationQuality(self, newValue) }
    }
    public func fill(_ r: CGRect) { CGContextFillRect(self, r) }
    public func stroke(_ r: CGRect) { CGContextStrokeRect(self, r) }
    public func fillEllipse(in r: CGRect) { CGContextFillEllipseInRect(self, r) }
    public func strokeEllipse(in r: CGRect) { CGContextStrokeEllipseInRect(self, r) }
    public func clear(_ r: CGRect) { CGContextClearRect(self, r) }
    public func beginPath() { CGContextBeginPath(self) }
    public func move(to p: CGPoint) { CGContextMoveToPoint(self, p.x, p.y) }
    public func addLine(to p: CGPoint) { CGContextAddLineToPoint(self, p.x, p.y) }
    public func addLines(between points: [CGPoint]) { CGContextAddLines(self, points, points.count) }
    public func addRect(_ r: CGRect) { CGContextAddRect(self, r) }
    public func addEllipse(in r: CGRect) { CGContextAddEllipseInRect(self, r) }
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) { CGContextAddCurveToPoint(self, control1.x, control1.y, control2.x, control2.y, end.x, end.y) }
    public func addQuadCurve(to end: CGPoint, control: CGPoint) { CGContextAddQuadCurveToPoint(self, control.x, control.y, end.x, end.y) }
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        CGContextAddArc(self, center.x, center.y, radius, startAngle, endAngle, clockwise ? 1 : 0)
    }
    public func addPath(_ p: CGPath) { CGContextAddPath(self, p) }
    public func closePath() { CGContextClosePath(self) }
    public func fillPath(using rule: CGPathFillRule = .winding) { rule == .evenOdd ? CGContextEOFillPath(self) : CGContextFillPath(self) }
    public func strokePath() { CGContextStrokePath(self) }
    public func drawPath(using mode: CGPathDrawingMode) { CGContextDrawPath(self, mode) }
    public func clip(using rule: CGPathFillRule = .winding) { rule == .evenOdd ? CGContextEOClip(self) : CGContextClip(self) }
    public func clip(to r: CGRect) { CGContextClipToRect(self, r) }
    public func strokeLineSegments(between points: [CGPoint]) { CGContextStrokeLineSegments(self, points, points.count) }
    public func draw(_ image: CGImage, in rect: CGRect, byTiling: Bool = false) {
        if byTiling { __draw(in: rect, byTiling: image) } else { CGContextDrawImage(self, rect, image) }
    }
    public func fill(_ rects: [CGRect]) { CGContextFillRects(self, rects, rects.count) }
    public func addRects(_ rects: [CGRect]) { CGContextAddRects(self, rects, rects.count) }
    public func clip(to rects: [CGRect]) { CGContextClipToRects(self, rects, rects.count) }
    public func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {
        __addArc(x1: tangent1End.x, y1: tangent1End.y, x2: tangent2End.x, y2: tangent2End.y, radius: radius)
    }
    public var textPosition: CGPoint {
        get { CGContextGetTextPosition(self) }
        set { CGContextSetTextPosition(self, newValue.x, newValue.y) }
    }
}

// MARK: - CGColor
extension CGColor {
    /// The components in the color's color space (alpha last).
    public var components: [CGFloat]? {
        guard let p = CGColorGetComponents(self) else { return nil }
        return Array(UnsafeBufferPointer(start: p, count: numberOfComponents))
    }
}

// MARK: - CGImage
extension CGImage {
    public var decode: [CGFloat]? {
        guard let p = CGImageGetDecode(self) else { return nil }
        return Array(UnsafeBufferPointer(start: p, count: 2 * (colorSpace?.numberOfComponents ?? 1)))
    }
}

// MARK: - ABI compatibility (apps built with isim 0.2.0)
// These were Swift members in 0.2.0; they are now imported from the C headers (CG_SWIFT_NAME) or gained
// parameters. The old entry points stay exported under their original symbol names so existing binaries keep
// running. They are internal: new code uses the current API.
extension CGImage {
    @_silgen_name("$sSo10CGImageRefa12CoreGraphicsE5widthSivg")
    @usableFromInline func _abi020_width() -> Int { width }
    @_silgen_name("$sSo10CGImageRefa12CoreGraphicsE6heightSivg")
    @usableFromInline func _abi020_height() -> Int { height }
    @_silgen_name("$sSo10CGImageRefa12CoreGraphicsE8cropping2toABSgSo6CGRectV_tF")
    @usableFromInline func _abi020_cropping(to rect: CGRect) -> CGImage? { cropping(to: rect) }
}
extension CGContext {
    @_silgen_name("$sSo12CGContextRefa12CoreGraphicsE4draw_2inySo07CGImageB0a_So6CGRectVtF")
    @usableFromInline func _abi020_draw(_ image: CGImage, in rect: CGRect) { draw(image, in: rect, byTiling: false) }
}
