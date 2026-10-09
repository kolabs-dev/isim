// isim Spatial overlay (self-authored): the parts of Apple's Spatial framework isim's frameworks use — Angle2D
// (Charts' Chart3DPose). The 3D geometry types (Point3D, Rotation3D, ...) are not provided.
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
