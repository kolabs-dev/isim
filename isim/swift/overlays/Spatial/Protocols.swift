// isim Spatial overlay: the protocols the primitives share (Primitive3D, Rotatable3D, Scalable3D, Shearable3D,
// Translatable3D, Volumetric), their mutating forms, and the axis and dimension sets.
@_exported import simd

/// A primitive that transforms can be applied to.
public protocol Primitive3D: Hashable, Codable, Sendable {
    var isFinite: Bool { get }
    var isNaN: Bool { get }
    var isZero: Bool { get }
    static var infinity: Self { get }
    static var zero: Self { get }
    func applying(_ transform: AffineTransform3D) -> Self
    func applying(_ transform: ProjectiveTransform3D) -> Self
    func applying(_ pose: Pose3D) -> Self
    func unapplying(_ transform: AffineTransform3D) -> Self
    func unapplying(_ transform: ProjectiveTransform3D) -> Self
    func unapplying(_ pose: Pose3D) -> Self
}
extension Primitive3D {
    public mutating func apply(_ transform: AffineTransform3D) { self = applying(transform) }
    public mutating func apply(_ transform: ProjectiveTransform3D) { self = applying(transform) }
    public mutating func apply(_ pose: Pose3D) { self = applying(pose) }
    public mutating func unapply(_ transform: AffineTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ transform: ProjectiveTransform3D) { self = unapplying(transform) }
    public mutating func unapply(_ pose: Pose3D) { self = unapplying(pose) }
    public func unapplying(_ transform: AffineTransform3D) -> Self { transform.inverse.map { applying($0) } ?? self }
    public func unapplying(_ transform: ProjectiveTransform3D) -> Self { transform.inverse.map { applying($0) } ?? self }
    public func unapplying(_ pose: Pose3D) -> Self { applying(pose.inverse) }
}

/// A primitive that can be rotated.
public protocol Rotatable3D {
    func rotated(by rotation: Rotation3D) -> Self
    func rotated(by quaternion: simd_quatd) -> Self
}
extension Rotatable3D {
    public func rotated(by quaternion: simd_quatd) -> Self { rotated(by: Rotation3D(quaternion: quaternion)) }
    public mutating func rotate(by rotation: Rotation3D) { self = rotated(by: rotation) }
    public mutating func rotate(by quaternion: simd_quatd) { self = rotated(by: quaternion) }
}
/// Rotates a primitive.
public func * <T: Rotatable3D>(lhs: Rotation3D, rhs: T) -> T { rhs.rotated(by: lhs) }

/// A primitive that can be scaled.
public protocol Scalable3D {
    func scaled(by size: Size3D) -> Self
    func scaledBy(x: Double, y: Double, z: Double) -> Self
    func uniformlyScaled(by scale: Double) -> Self
}
extension Scalable3D {
    public func scaledBy(x: Double, y: Double, z: Double) -> Self { scaled(by: Size3D(width: x, height: y, depth: z)) }
    public func uniformlyScaled(by scale: Double) -> Self { scaledBy(x: scale, y: scale, z: scale) }
    public mutating func scale(by size: Size3D) { self = scaled(by: size) }
    public mutating func scaleBy(x: Double, y: Double, z: Double) { self = scaledBy(x: x, y: y, z: z) }
    public mutating func uniformlyScale(by scale: Double) { self = uniformlyScaled(by: scale) }
}

/// A primitive that can be sheared.
public protocol Shearable3D {
    func sheared(_ shear: AxisWithFactors) -> Self
}
extension Shearable3D {
    public mutating func shear(_ shear: AxisWithFactors) { self = sheared(shear) }
}

/// A primitive that can be translated.
public protocol Translatable3D {
    func translated(by offset: Vector3D) -> Self
}
extension Translatable3D {
    public func translated(by size: Size3D) -> Self { translated(by: Vector3D(size)) }
    public mutating func translate(by offset: Vector3D) { self = translated(by: offset) }
    public mutating func translate(by size: Size3D) { self = translated(by: size) }
}

/// A primitive with a volume.
public protocol Volumetric {
    var size: Size3D { get }
    func contains(_ other: Self) -> Bool
    func contains(point: Point3D) -> Bool
    func union(_ other: Self) -> Self
    func intersection(_ other: Self) -> Self?
}
extension Volumetric {
    public func contains(anyOf points: [Point3D]) -> Bool { points.contains { contains(point: $0) } }
    public func containsAny(of points: [Point3D]) -> Bool { contains(anyOf: points) }
    public mutating func formUnion(_ other: Self) { self = union(other) }
    public mutating func formIntersection(_ other: Self) { if let r = intersection(other) { self = r } }
}

/// An axis: x, y or z.
public struct Axis3D: RawRepresentable, Hashable, Sendable, Codable {
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public static var x: Axis3D { Axis3D(rawValue: 1) }
    public static var y: Axis3D { Axis3D(rawValue: 2) }
    public static var z: Axis3D { Axis3D(rawValue: 4) }
}
public let x = Axis3D.x
public let y = Axis3D.y
public let z = Axis3D.z

/// A set of the x, y and z dimensions.
public struct Dimension3DSet: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let x = Dimension3DSet(rawValue: 1)
    public static let y = Dimension3DSet(rawValue: 2)
    public static let z = Dimension3DSet(rawValue: 4)
    public static let all: Dimension3DSet = [.x, .y, .z]
}

/// A shear: one axis's coordinate moves the other two by factors.
public enum AxisWithFactors: Hashable, Sendable {
    /// y += yShearFactor * x, z += zShearFactor * x
    case xAxis(yShearFactor: Double, zShearFactor: Double)
    /// x += xShearFactor * y, z += zShearFactor * y
    case yAxis(xShearFactor: Double, zShearFactor: Double)
    /// x += xShearFactor * z, y += yShearFactor * z
    case zAxis(xShearFactor: Double, yShearFactor: Double)
    var _matrix: simd_double3x3 {
        switch self {
        case .xAxis(let a, let b): return simd_double3x3(SIMD3(1, a, b), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
        case .yAxis(let a, let b): return simd_double3x3(SIMD3(1, 0, 0), SIMD3(a, 1, b), SIMD3(0, 0, 1))
        case .zAxis(let a, let b): return simd_double3x3(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(a, b, 1))
        }
    }
}
