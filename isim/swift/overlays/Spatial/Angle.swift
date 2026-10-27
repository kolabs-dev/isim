// isim Spatial overlay (self-authored, Apple's API names): Spatial's 3D geometry in Double precision, as pure Swift
// math over simd (issue #370; Angle2D and Rotation3D first came for Charts). This file: Angle2D and the trigonometric
// functions of angles.
import Darwin
@_exported import simd

/// A planar angle (radians, with degrees for convenience).
public struct Angle2D: Hashable, Comparable, Sendable, Codable, AdditiveArithmetic, CustomReflectable {
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
    public static func acos(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.acos(x)) }
    public static func acosh(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.acosh(x)) }
    public static func asin(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.asin(x)) }
    public static func asinh(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.asinh(x)) }
    public static func atan(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.atan(x)) }
    public static func atan2(y: Double, x: Double) -> Angle2D { Angle2D(radians: Darwin.atan2(y, x)) }
    public static func atanh(_ x: Double) -> Angle2D { Angle2D(radians: Darwin.atanh(x)) }
    public static func < (a: Angle2D, b: Angle2D) -> Bool { a.radians < b.radians }
    public static func + (a: Angle2D, b: Angle2D) -> Angle2D { Angle2D(radians: a.radians + b.radians) }
    public static func - (a: Angle2D, b: Angle2D) -> Angle2D { Angle2D(radians: a.radians - b.radians) }
    public static prefix func + (a: Angle2D) -> Angle2D { a }
    public static prefix func - (a: Angle2D) -> Angle2D { Angle2D(radians: -a.radians) }
    public static func += (a: inout Angle2D, b: Angle2D) { a.radians += b.radians }
    public static func -= (a: inout Angle2D, b: Angle2D) { a.radians -= b.radians }
    public static func * (a: Angle2D, s: Double) -> Angle2D { Angle2D(radians: a.radians * s) }
    public static func / (a: Angle2D, s: Double) -> Angle2D { Angle2D(radians: a.radians / s) }
    public var customMirror: Mirror { Mirror(self, children: ["radians": radians, "degrees": degrees]) }
}

public func sin(_ a: Angle2D) -> Double { Darwin.sin(a.radians) }
public func cos(_ a: Angle2D) -> Double { Darwin.cos(a.radians) }
public func tan(_ a: Angle2D) -> Double { Darwin.tan(a.radians) }
public func sinh(_ a: Angle2D) -> Double { Darwin.sinh(a.radians) }
public func cosh(_ a: Angle2D) -> Double { Darwin.cosh(a.radians) }
public func tanh(_ a: Angle2D) -> Double { Darwin.tanh(a.radians) }
