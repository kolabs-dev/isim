// isim Spatial overlay: Point3D, Vector3D, Size3D, RotationAxis3D and SphericalCoordinates3D. Transforms apply as
// Apple documents: points take the whole transform (projective ones divide by w), vectors and sizes only its linear
// part; poses rotate (and scaled poses scale) and then translate points.
import Darwin
@_exported import simd

// MARK: - shared math

extension SIMD3 where Scalar == Double {
    /// through an affine transform: the 3x3 part, plus the translation for points
    func _affine(_ t: AffineTransform3D, point: Bool) -> SIMD3<Double> {
        let m = t.matrix
        return m.columns.0 * self.x + m.columns.1 * self.y + m.columns.2 * self.z + (point ? m.columns.3 : .zero)
    }
    /// through a projective transform: points are divided by w, vectors take the upper 3x3
    func _projective(_ t: ProjectiveTransform3D, point: Bool) -> SIMD3<Double> {
        let r = t.matrix * SIMD4(self, point ? 1 : 0)
        let v = SIMD3(r.x, r.y, r.z)
        return point && r.w != 0 && r.w != 1 ? v / r.w : v
    }
    var _isFinite: Bool { self.x.isFinite && self.y.isFinite && self.z.isFinite }
    var _isNaN: Bool { self.x.isNaN || self.y.isNaN || self.z.isNaN }
}

// MARK: - Point3D

/// A point in 3D.
public struct Point3D: Hashable, Codable, Sendable, Primitive3D, Rotatable3D, Scalable3D, Shearable3D, Translatable3D, CustomReflectable {
    public var x: Double, y: Double, z: Double
    public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
    public init<T: BinaryFloatingPoint>(x: T, y: T, z: T) { self.init(x: Double(x), y: Double(y), z: Double(z)) }
    public init(vector: simd_double3) { self.init(x: vector.x, y: vector.y, z: vector.z) }
    public init(_ v: simd_double3) { self.init(vector: v) }
    public init(_ v: simd_float3) { self.init(x: Double(v.x), y: Double(v.y), z: Double(v.z)) }
    public init(_ v: Vector3D) { self.init(vector: v.vector) }
    public init(_ s: Size3D) { self.init(vector: s.vector) }
    public init(_ s: SphericalCoordinates3D) { self.init(vector: s._cartesian) }
    public var vector: simd_double3 { get { SIMD3(x, y, z) } set { x = newValue.x; y = newValue.y; z = newValue.z } }
    public var simd: simd_double3 { vector }
    public var origin: Point3D { .zero }
    public var magnitudeSquared: Double { simd_length_squared(vector) }
    public static var zero: Point3D { Point3D() }
    public static var infinity: Point3D { Point3D(x: .infinity, y: .infinity, z: .infinity) }
    public var isZero: Bool { vector == .zero }
    public var isFinite: Bool { vector._isFinite }
    public var isNaN: Bool { vector._isNaN }
    public func distance(to other: Point3D) -> Double { simd_distance(vector, other.vector) }
    public func isApproximatelyEqual(to other: Point3D, tolerance: Double = .ulpOfOne.squareRoot()) -> Bool {
        simd_distance(vector, other.vector) <= tolerance
    }
    /// the rotation about the origin that turns this point's direction into the other's
    public func rotation(to other: Point3D) -> Rotation3D { Rotation3D(quaternion: simd_quatd(from: vector, to: other.vector)) }
    public mutating func clamp(to rect: Rect3D) { vector = simd_clamp(vector, rect.min.vector, rect.max.vector) }
    public mutating func scale(by factor: Double) { vector *= factor }
    public func applying(_ t: AffineTransform3D) -> Point3D { Point3D(vector: vector._affine(t, point: true)) }
    public func applying(_ t: ProjectiveTransform3D) -> Point3D { Point3D(vector: vector._projective(t, point: true)) }
    public func applying(_ p: Pose3D) -> Point3D { Point3D(vector: p.rotation.quaternion.act(vector) + p.position.vector) }
    public func applying(_ p: ScaledPose3D) -> Point3D { Point3D(vector: p.rotation.quaternion.act(vector * p.scale) + p.position.vector) }
    public func unapplying(_ p: Pose3D) -> Point3D { Point3D(vector: p.rotation.quaternion.inverse.act(vector - p.position.vector)) }
    public func unapplying(_ p: ScaledPose3D) -> Point3D {
        Point3D(vector: p.rotation.quaternion.inverse.act(vector - p.position.vector) / (p.scale == 0 ? 1 : p.scale))
    }
    public func rotated(by r: Rotation3D) -> Point3D { Point3D(vector: r.quaternion.act(vector)) }
    public func rotated(by r: Rotation3D, around pivot: Point3D) -> Point3D { Point3D(vector: r.quaternion.act(vector - pivot.vector) + pivot.vector) }
    public func rotated(by q: simd_quatd, around pivot: Point3D) -> Point3D { rotated(by: Rotation3D(quaternion: q), around: pivot) }
    public func scaled(by s: Size3D) -> Point3D { Point3D(vector: vector * s.vector) }
    public func sheared(_ s: AxisWithFactors) -> Point3D { Point3D(vector: s._matrix * vector) }
    public func translated(by v: Vector3D) -> Point3D { Point3D(vector: vector + v.vector) }
    public var customMirror: Mirror { Mirror(self, children: ["x": x, "y": y, "z": z]) }

    public static func * (p: Point3D, s: Double) -> Point3D { Point3D(vector: p.vector * s) }
    public static func * (s: Double, p: Point3D) -> Point3D { Point3D(vector: p.vector * s) }
    public static func / (p: Point3D, s: Double) -> Point3D { Point3D(vector: p.vector / s) }
    public static func *= (p: inout Point3D, s: Double) { p.vector *= s }
    public static func /= (p: inout Point3D, s: Double) { p.vector /= s }
    public static func * (t: AffineTransform3D, p: Point3D) -> Point3D { p.applying(t) }
    public static func * (t: ProjectiveTransform3D, p: Point3D) -> Point3D { p.applying(t) }
    public static func * (t: Pose3D, p: Point3D) -> Point3D { p.applying(t) }
    public static func + (p: Point3D, s: Size3D) -> Point3D { Point3D(vector: p.vector + s.vector) }
    public static func + (s: Size3D, p: Point3D) -> Point3D { Point3D(vector: p.vector + s.vector) }
    public static func - (p: Point3D, s: Size3D) -> Point3D { Point3D(vector: p.vector - s.vector) }
    public static func - (s: Size3D, p: Point3D) -> Point3D { Point3D(vector: s.vector - p.vector) }
    public static func - (a: Point3D, b: Point3D) -> Vector3D { Vector3D(vector: a.vector - b.vector) }
    public static prefix func - (p: Point3D) -> Point3D { Point3D(vector: -p.vector) }
    public static func += (p: inout Point3D, v: Vector3D) { p.vector += v.vector }
    public static func += (p: inout Point3D, s: Size3D) { p.vector += s.vector }
    public static func -= (p: inout Point3D, v: Vector3D) { p.vector -= v.vector }
    public static func -= (p: inout Point3D, s: Size3D) { p.vector -= s.vector }
}

// MARK: - Vector3D

/// A direction and magnitude in 3D.
public struct Vector3D: Hashable, Codable, Sendable, Primitive3D, Rotatable3D, Scalable3D, Shearable3D, CustomReflectable {
    public var x: Double, y: Double, z: Double
    public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
    public init<T: BinaryFloatingPoint>(x: T, y: T, z: T) { self.init(x: Double(x), y: Double(y), z: Double(z)) }
    public init(vector: simd_double3) { self.init(x: vector.x, y: vector.y, z: vector.z) }
    public init(_ v: simd_double3) { self.init(vector: v) }
    public init(_ v: simd_float3) { self.init(x: Double(v.x), y: Double(v.y), z: Double(v.z)) }
    public init(_ a: RotationAxis3D) { self.init(vector: a.vector) }
    public init(_ p: Point3D) { self.init(vector: p.vector) }
    public init(_ s: Size3D) { self.init(vector: s.vector) }
    public init(_ s: SphericalCoordinates3D) { self.init(vector: s._cartesian) }
    public var vector: simd_double3 { get { SIMD3(x, y, z) } set { x = newValue.x; y = newValue.y; z = newValue.z } }
    public static let forward = Vector3D(x: 0, y: 0, z: 1)
    public static let right = Vector3D(x: 1, y: 0, z: 0)
    public static let up = Vector3D(x: 0, y: 1, z: 0)
    public static var zero: Vector3D { Vector3D() }
    public static var infinity: Vector3D { Vector3D(x: .infinity, y: .infinity, z: .infinity) }
    public var isZero: Bool { vector == .zero }
    public var isFinite: Bool { vector._isFinite }
    public var isNaN: Bool { vector._isNaN }
    public var length: Double { simd_length(vector) }
    public var lengthSquared: Double { simd_length_squared(vector) }
    public var normalized: Vector3D { let l = length; return l > 0 ? Vector3D(vector: vector / l) : self }
    public mutating func normalize() { self = normalized }
    public func dot(_ other: Vector3D) -> Double { simd_dot(vector, other.vector) }
    public func cross(_ other: Vector3D) -> Vector3D { Vector3D(vector: simd_cross(vector, other.vector)) }
    /// this vector's projection onto another
    public func projected(_ other: Vector3D) -> Vector3D {
        let d = other.lengthSquared
        return d > 0 ? Vector3D(vector: other.vector * (dot(other) / d)) : .zero
    }
    /// this vector reflected about a plane with the given normal
    public func reflected(_ normal: Vector3D) -> Vector3D {
        let n = normal.normalized.vector
        return Vector3D(vector: vector - 2 * simd_dot(vector, n) * n)
    }
    /// the rotation that turns this vector's direction into the other's
    public func rotation(to other: Vector3D) -> Rotation3D { Rotation3D(quaternion: simd_quatd(from: vector, to: other.vector)) }
    public func applying(_ t: AffineTransform3D) -> Vector3D { Vector3D(vector: vector._affine(t, point: false)) }
    public func applying(_ t: ProjectiveTransform3D) -> Vector3D { Vector3D(vector: vector._projective(t, point: false)) }
    public func applying(_ p: Pose3D) -> Vector3D { Vector3D(vector: p.rotation.quaternion.act(vector)) }
    public func applying(_ p: ScaledPose3D) -> Vector3D { Vector3D(vector: p.rotation.quaternion.act(vector * p.scale)) }
    public func unapplying(_ p: Pose3D) -> Vector3D { Vector3D(vector: p.rotation.quaternion.inverse.act(vector)) }
    public func unapplying(_ p: ScaledPose3D) -> Vector3D { Vector3D(vector: p.rotation.quaternion.inverse.act(vector) / (p.scale == 0 ? 1 : p.scale)) }
    public func rotated(by r: Rotation3D) -> Vector3D { Vector3D(vector: r.quaternion.act(vector)) }
    public func scaled(by s: Size3D) -> Vector3D { Vector3D(vector: vector * s.vector) }
    public func sheared(_ s: AxisWithFactors) -> Vector3D { Vector3D(vector: s._matrix * vector) }
    @available(iOS 26.0, macOS 26.0, *)
    public static func lerp(from a: Vector3D, to b: Vector3D, t: Vector3D) -> Vector3D { Vector3D(vector: a.vector + (b.vector - a.vector) * t.vector) }
    @available(iOS 26.0, macOS 26.0, *)
    public static func smoothstep(edge0: Vector3D, edge1: Vector3D, x: Vector3D) -> Vector3D {
        let t = simd_clamp((x.vector - edge0.vector) / (edge1.vector - edge0.vector), SIMD3(repeating: 0), SIMD3(repeating: 1))
        return Vector3D(vector: t * t * (3 - 2 * t))
    }
    public var customMirror: Mirror { Mirror(self, children: ["x": x, "y": y, "z": z]) }

    public static func * (v: Vector3D, s: Double) -> Vector3D { Vector3D(vector: v.vector * s) }
    public static func * (s: Double, v: Vector3D) -> Vector3D { Vector3D(vector: v.vector * s) }
    public static func / (v: Vector3D, s: Double) -> Vector3D { Vector3D(vector: v.vector / s) }
    public static func *= (v: inout Vector3D, s: Double) { v.vector *= s }
    public static func /= (v: inout Vector3D, s: Double) { v.vector /= s }
    public static func * (t: AffineTransform3D, v: Vector3D) -> Vector3D { v.applying(t) }
    public static func * (t: ProjectiveTransform3D, v: Vector3D) -> Vector3D { v.applying(t) }
    public static func * (t: Pose3D, v: Vector3D) -> Vector3D { v.applying(t) }
    public static func + (a: Vector3D, b: Vector3D) -> Vector3D { Vector3D(vector: a.vector + b.vector) }
    public static func - (a: Vector3D, b: Vector3D) -> Vector3D { Vector3D(vector: a.vector - b.vector) }
    public static prefix func - (v: Vector3D) -> Vector3D { Vector3D(vector: -v.vector) }
    public static func += (a: inout Vector3D, b: Vector3D) { a.vector += b.vector }
    public static func -= (a: inout Vector3D, b: Vector3D) { a.vector -= b.vector }
    public static func + (v: Vector3D, s: Size3D) -> Size3D { Size3D(vector: v.vector + s.vector) }
    public static func + (s: Size3D, v: Vector3D) -> Size3D { Size3D(vector: v.vector + s.vector) }
    public static func - (v: Vector3D, s: Size3D) -> Size3D { Size3D(vector: v.vector - s.vector) }
    public static func - (s: Size3D, v: Vector3D) -> Size3D { Size3D(vector: s.vector - v.vector) }
    public static func + (v: Vector3D, p: Point3D) -> Point3D { Point3D(vector: v.vector + p.vector) }
    public static func + (p: Point3D, v: Vector3D) -> Point3D { Point3D(vector: v.vector + p.vector) }
    public static func - (v: Vector3D, p: Point3D) -> Point3D { Point3D(vector: v.vector - p.vector) }
    public static func - (p: Point3D, v: Vector3D) -> Point3D { Point3D(vector: p.vector - v.vector) }
}

// MARK: - Size3D

/// A width, height and depth.
public struct Size3D: Hashable, Codable, Sendable, Primitive3D, Rotatable3D, Scalable3D, Shearable3D, Volumetric, CustomReflectable {
    public var width: Double, height: Double, depth: Double
    public init() { width = 0; height = 0; depth = 0 }
    public init(width: Double, height: Double, depth: Double) { self.width = width; self.height = height; self.depth = depth }
    public init<T: BinaryFloatingPoint>(width: T, height: T, depth: T) { self.init(width: Double(width), height: Double(height), depth: Double(depth)) }
    public init(vector: simd_double3) { self.init(width: vector.x, height: vector.y, depth: vector.z) }
    public init(_ v: simd_double3) { self.init(vector: v) }
    public init(_ v: simd_float3) { self.init(width: Double(v.x), height: Double(v.y), depth: Double(v.z)) }
    public init(_ p: Point3D) { self.init(vector: p.vector) }
    public init(_ v: Vector3D) { self.init(vector: v.vector) }
    public var vector: simd_double3 { get { SIMD3(width, height, depth) } set { width = newValue.x; height = newValue.y; depth = newValue.z } }
    public var simd: simd_double3 { vector }
    public var size: Size3D { self }
    public static let one = Size3D(width: 1, height: 1, depth: 1)
    public static var zero: Size3D { Size3D() }
    public static var infinity: Size3D { Size3D(width: .infinity, height: .infinity, depth: .infinity) }
    public var isZero: Bool { vector == .zero }
    public var isFinite: Bool { vector._isFinite }
    public var isNaN: Bool { vector._isNaN }
    /// as a box from the origin
    public func contains(_ other: Size3D) -> Bool { all(other.vector .<= vector) }
    public func contains(point: Point3D) -> Bool { all(point.vector .>= .zero) && all(point.vector .<= vector) }
    public func union(_ other: Size3D) -> Size3D { Size3D(vector: simd_max(vector, other.vector)) }
    public func intersection(_ other: Size3D) -> Size3D? {
        let m = simd_min(vector, other.vector)
        return any(m .< .zero) ? nil : Size3D(vector: m)
    }
    public func applying(_ t: AffineTransform3D) -> Size3D { Size3D(vector: vector._affine(t, point: false)) }
    public func applying(_ t: ProjectiveTransform3D) -> Size3D { Size3D(vector: vector._projective(t, point: false)) }
    public func applying(_ p: Pose3D) -> Size3D { Size3D(vector: p.rotation.quaternion.act(vector)) }
    public func applying(_ p: ScaledPose3D) -> Size3D { Size3D(vector: p.rotation.quaternion.act(vector * p.scale)) }
    public func unapplying(_ p: Pose3D) -> Size3D { Size3D(vector: p.rotation.quaternion.inverse.act(vector)) }
    public func unapplying(_ p: ScaledPose3D) -> Size3D { Size3D(vector: p.rotation.quaternion.inverse.act(vector) / (p.scale == 0 ? 1 : p.scale)) }
    public func rotated(by r: Rotation3D) -> Size3D { Size3D(vector: r.quaternion.act(vector)) }
    public func scaled(by s: Size3D) -> Size3D { Size3D(vector: vector * s.vector) }
    public func sheared(_ s: AxisWithFactors) -> Size3D { Size3D(vector: s._matrix * vector) }
    public var customMirror: Mirror { Mirror(self, children: ["width": width, "height": height, "depth": depth]) }

    public static func * (v: Size3D, s: Double) -> Size3D { Size3D(vector: v.vector * s) }
    public static func * (s: Double, v: Size3D) -> Size3D { Size3D(vector: v.vector * s) }
    public static func / (v: Size3D, s: Double) -> Size3D { Size3D(vector: v.vector / s) }
    public static func *= (v: inout Size3D, s: Double) { v.vector *= s }
    public static func /= (v: inout Size3D, s: Double) { v.vector /= s }
    public static func * (t: AffineTransform3D, v: Size3D) -> Size3D { v.applying(t) }
    public static func * (t: ProjectiveTransform3D, v: Size3D) -> Size3D { v.applying(t) }
    public static func * (t: Pose3D, v: Size3D) -> Size3D { v.applying(t) }
    public static func + (a: Size3D, b: Size3D) -> Size3D { Size3D(vector: a.vector + b.vector) }
    public static func - (a: Size3D, b: Size3D) -> Size3D { Size3D(vector: a.vector - b.vector) }
    public static prefix func - (v: Size3D) -> Size3D { Size3D(vector: -v.vector) }
    public static func += (a: inout Size3D, b: Size3D) { a.vector += b.vector }
    public static func -= (a: inout Size3D, b: Size3D) { a.vector -= b.vector }
    public static func += (a: inout Size3D, b: Vector3D) { a.vector += b.vector }
    public static func -= (a: inout Size3D, b: Vector3D) { a.vector -= b.vector }
}

// MARK: - RotationAxis3D

/// A unit axis of rotation.
public struct RotationAxis3D: Hashable, Sendable, Codable, CustomReflectable {
    public var x: Double, y: Double, z: Double
    public init() { x = 0; y = 0; z = 0 }
    /// The axis through (x, y, z), normalized.
    public init(x: Double, y: Double, z: Double) {
        let l = (x * x + y * y + z * z).squareRoot()
        if l > 0 { self.x = x / l; self.y = y / l; self.z = z / l } else { self.x = 0; self.y = 0; self.z = 0 }
    }
    public init<T: BinaryFloatingPoint>(x: T, y: T, z: T) { self.init(x: Double(x), y: Double(y), z: Double(z)) }
    public init(vector: simd_double3) { self.init(x: vector.x, y: vector.y, z: vector.z) }
    public init(_ v: simd_double3) { self.init(vector: v) }
    public init(_ v: simd_float3) { self.init(x: Double(v.x), y: Double(v.y), z: Double(v.z)) }
    public init(_ v: Vector3D) { self.init(vector: v.vector) }
    public var vector: simd_double3 { get { SIMD3(x, y, z) } set { self = RotationAxis3D(vector: newValue) } }
    public var simd: simd_double3 { vector }
    public var isZero: Bool { x == 0 && y == 0 && z == 0 }
    public static var x: RotationAxis3D { RotationAxis3D(x: 1, y: 0, z: 0) }
    public static var y: RotationAxis3D { RotationAxis3D(x: 0, y: 1, z: 0) }
    public static var z: RotationAxis3D { RotationAxis3D(x: 0, y: 0, z: 1) }
    public static var xy: RotationAxis3D { RotationAxis3D(x: 1, y: 1, z: 0) }
    public static var yz: RotationAxis3D { RotationAxis3D(x: 0, y: 1, z: 1) }
    public static var xz: RotationAxis3D { RotationAxis3D(x: 1, y: 0, z: 1) }
    public static var xyz: RotationAxis3D { RotationAxis3D(x: 1, y: 1, z: 1) }
    public static let zero = RotationAxis3D()
    public var customMirror: Mirror { Mirror(self, children: ["x": x, "y": y, "z": z]) }
}

// MARK: - SphericalCoordinates3D

/// A point in spherical coordinates: a radius, an inclination from the z axis and an azimuth in the xy-plane from
/// the x axis (ISO 80000-2).
public struct SphericalCoordinates3D: Hashable, Codable, Sendable, CustomReflectable {
    public var radius: Double
    public var inclination: Angle2D
    public var azimuth: Angle2D
    public init() { radius = 0; inclination = .zero; azimuth = .zero }
    public init(radius: Double, inclination: Angle2D, azimuth: Angle2D) { self.radius = radius; self.inclination = inclination; self.azimuth = azimuth }
    public init(vector v: simd_double3) {
        radius = simd_length(v)
        inclination = Angle2D(radians: radius > 0 ? Darwin.acos(Swift.max(-1, Swift.min(1, v.z / radius))) : 0)
        azimuth = Angle2D(radians: Darwin.atan2(v.y, v.x))
    }
    public init(_ v: simd_double3) { self.init(vector: v) }
    public init(x: Double, y: Double, z: Double) { self.init(vector: SIMD3(x, y, z)) }
    public init(_ p: Point3D) { self.init(vector: p.vector) }
    public init(_ v: Vector3D) { self.init(vector: v.vector) }
    /// (radius, inclination, azimuth) in radians
    public var vector: simd_double3 { SIMD3(radius, inclination.radians, azimuth.radians) }
    var _cartesian: simd_double3 {
        let s = Darwin.sin(inclination.radians)
        return SIMD3(radius * s * Darwin.cos(azimuth.radians), radius * s * Darwin.sin(azimuth.radians), radius * Darwin.cos(inclination.radians))
    }
    public var customMirror: Mirror { Mirror(self, children: ["radius": radius, "inclination": inclination, "azimuth": azimuth]) }
}
