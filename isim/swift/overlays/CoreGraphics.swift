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
