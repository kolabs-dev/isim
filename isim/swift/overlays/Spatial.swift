// isim Spatial overlay (self-authored): the parts of Apple's Spatial framework isim's frameworks use — Angle2D
// (Charts' Chart3DPose) and Rotation3D / RotationAxis3D (Charts' symbolRotation). The other 3D geometry types (Point3D, ...)
// are not provided.
import Darwin

/// A planar angle (radians, with degrees for convenience).
public struct Angle2D: Hashable, Comparable, Sendable, Codable, AdditiveArithmetic {
    public var radians: Double
    public var degrees: Double {
        get { radians * 180 / .pi }
        set { radians = newValue * .pi / 180 }
    }
    public init() { radians = 0 }
    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { radians = degrees * .pi / 180 }
    public init<T: BinaryFloatingPoint>(radians: T) { self.radians = Double(radians) }
    public init<T: BinaryFloatingPoint>(degrees: T) { self.radians = Double(degrees) * .pi / 180 }
    public static func radians(_ r: Double) -> Angle2D { Angle2D(radians: r) }
    public static func degrees(_ d: Double) -> Angle2D { Angle2D(degrees: d) }
    public static var zero: Angle2D { Angle2D() }
    /// The angle in -pi ... pi.
    public var normalized: Angle2D {
        var r = radians.truncatingRemainder(dividingBy: 2 * .pi)
        if r > .pi { r -= 2 * .pi } else if r < -.pi { r += 2 * .pi }
        return Angle2D(radians: r)
    }
    public static func < (a: Angle2D, b: Angle2D) -> Bool { a.radians < b.radians }
    public static func + (a: Angle2D, b: Angle2D) -> Angle2D { Angle2D(radians: a.radians + b.radians) }
    public static func - (a: Angle2D, b: Angle2D) -> Angle2D { Angle2D(radians: a.radians - b.radians) }
    public static prefix func - (a: Angle2D) -> Angle2D { Angle2D(radians: -a.radians) }
    public static func * (a: Angle2D, s: Double) -> Angle2D { Angle2D(radians: a.radians * s) }
    public static func / (a: Angle2D, s: Double) -> Angle2D { Angle2D(radians: a.radians / s) }
}

public func sin(_ a: Angle2D) -> Double { Darwin.sin(a.radians) }
public func cos(_ a: Angle2D) -> Double { Darwin.cos(a.radians) }
public func tan(_ a: Angle2D) -> Double { Darwin.tan(a.radians) }

// MARK: - Rotations (the parts Charts' symbolRotation uses: an angle about an axis; no quaternion property)

/// A unit axis of rotation.
public struct RotationAxis3D: Hashable, Sendable, Codable {
    public var x: Double, y: Double, z: Double
    /// The axis through (x, y, z), normalized.
    public init(x: Double, y: Double, z: Double) {
        let l = (x * x + y * y + z * z).squareRoot()
        if l > 0 { self.x = x / l; self.y = y / l; self.z = z / l } else { self.x = 0; self.y = 0; self.z = 1 }
    }
    public static var x: RotationAxis3D { RotationAxis3D(x: 1, y: 0, z: 0) }
    public static var y: RotationAxis3D { RotationAxis3D(x: 0, y: 1, z: 0) }
    public static var z: RotationAxis3D { RotationAxis3D(x: 0, y: 0, z: 1) }
    public static var xy: RotationAxis3D { RotationAxis3D(x: 1, y: 1, z: 0) }
    public static var yz: RotationAxis3D { RotationAxis3D(x: 0, y: 1, z: 1) }
    public static var xz: RotationAxis3D { RotationAxis3D(x: 1, y: 0, z: 1) }
    public static var xyz: RotationAxis3D { RotationAxis3D(x: 1, y: 1, z: 1) }
}

/// A rotation in 3D: an angle about an axis.
public struct Rotation3D: Hashable, Sendable, Codable {
    public var angle: Angle2D
    public var axis: RotationAxis3D
    public init() { angle = .zero; axis = .z }
    public init(angle: Angle2D, axis: RotationAxis3D) { self.angle = angle; self.axis = axis }
    public static var identity: Rotation3D { Rotation3D() }
    public var isIdentity: Bool { angle.radians == 0 }
}
