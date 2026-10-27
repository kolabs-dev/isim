// isim Spatial overlay: Rotation3D (a unit quaternion), EulerAngles and its order, interpolation and swing-twist.
// Euler angles are extrinsic ("static"): .xyz (pitch, yaw, roll) turns about x, then y, then z; .zxy about z, x, y.
import Darwin
@_exported import simd

/// The order of Euler angles: the fixed axes they turn about, first to last.
@frozen public enum __SPEulerAngleOrder: UInt32, Hashable, Sendable {
    case xyz = 1
    case zxy = 2
    /// pitch (x), yaw (y), then roll (z): `.xyz`
    public static var pitchYawRoll: __SPEulerAngleOrder { .xyz }
}

/// Three angles (radians, about x, y and z) and the order they apply in.
public struct EulerAngles: Sendable {
    public typealias Order = __SPEulerAngleOrder
    public var angles: simd_double3
    public var order: __SPEulerAngleOrder
    public init() { angles = .zero; order = .xyz }
    public init(angles: simd_double3, order: __SPEulerAngleOrder) { self.angles = angles; self.order = order }
    public init(angles: simd_float3, order: EulerAngles.Order) { self.init(angles: SIMD3<Double>(angles), order: order) }
    public init(x: Angle2D, y: Angle2D, z: Angle2D, order: EulerAngles.Order) {
        self.init(angles: SIMD3(x.radians, y.radians, z.radians), order: order)
    }
    public init(_ x: Angle2D, _ y: Angle2D, _ z: Angle2D, order: EulerAngles.Order) { self.init(x: x, y: y, z: z, order: order) }
}

/// A rotation in 3D, stored as a unit quaternion.
public struct Rotation3D: Hashable, Sendable, Codable, Rotatable3D, CustomReflectable {
    public var quaternion: simd_quatd

    public init() { quaternion = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1) }
    public init(quaternion: simd_quatd) { self.quaternion = quaternion }
    public init(_ quaternion: simd_quatd) { self.quaternion = quaternion }
    public init(quaternion: simd_quatf) { self.quaternion = simd_quatd(vector: SIMD4<Double>(quaternion.vector)) }
    public init(_ quaternion: simd_quatf) { self.init(quaternion: quaternion) }
    public init(angle: Angle2D, axis: RotationAxis3D) { quaternion = simd_quatd(angle: angle.radians, axis: axis.vector) }
    public init(axis: RotationAxis3D, angle: Angle2D) { self.init(angle: angle, axis: axis) }
    public init(eulerAngles e: EulerAngles) {
        let qx = simd_quatd(angle: e.angles.x, axis: SIMD3(1, 0, 0))
        let qy = simd_quatd(angle: e.angles.y, axis: SIMD3(0, 1, 0))
        let qz = simd_quatd(angle: e.angles.z, axis: SIMD3(0, 0, 1))
        quaternion = e.order == .zxy ? qy * qx * qz : qz * qy * qx
    }
    /// The rotation that turns +z to `forward`, keeping +y as close to `up` as it can.
    public init(forward: Vector3D, up: Vector3D = .up) {
        let f = simd_normalize(forward.vector), r = simd_cross(up.vector, f)
        guard simd_length(r) > 1e-12, f.x.isFinite, f.y.isFinite, f.z.isFinite else {
            quaternion = simd_quatd(from: SIMD3(0, 0, 1), to: f)
            return
        }
        let rn = simd_normalize(r)
        quaternion = simd_quatd(simd_double3x3(rn, simd_cross(f, rn), f)).normalized
    }
    public init(forward: Vector3D) { self.init(forward: forward, up: .up) }
    /// The rotation that looks from `position` toward `target`.
    public init(position: Point3D, target: Point3D, up: Vector3D = .up) {
        self.init(forward: Vector3D(vector: target.vector - position.vector), up: up)
    }
    public init(eye: Point3D, target: Point3D, up: Vector3D = .up) { self.init(position: eye, target: target, up: up) }

    /// The rotation with a zero angle.
    public static let zero = Rotation3D()
    public static var identity: Rotation3D { Rotation3D() }

    public var vector: simd_double4 {
        get { quaternion.vector }
        set { quaternion = simd_quatd(vector: newValue) }
    }
    public var angle: Angle2D {
        get { Angle2D(radians: quaternion.angle) }
        set { quaternion = simd_quatd(angle: newValue.radians, axis: quaternion.axis) }
    }
    public var axis: RotationAxis3D {
        get { RotationAxis3D(vector: quaternion.axis) }
        set { quaternion = simd_quatd(angle: quaternion.angle, axis: newValue.vector) }
    }
    public var isIdentity: Bool { quaternion.imag == .zero && abs(quaternion.real) == 1 }
    public var isZero: Bool { isIdentity }
    public var inverse: Rotation3D { Rotation3D(quaternion: quaternion.inverse) }

    public func eulerAngles(order: __SPEulerAngleOrder) -> EulerAngles {
        let m = simd_double3x3(quaternion.normalized)
        func r(_ row: Int, _ col: Int) -> Double { m[col, row] }
        var a = SIMD3<Double>()
        if order == .zxy {
            // R = Ry Rx Rz
            a.x = Darwin.asin(Swift.max(-1, Swift.min(1, -r(1, 2))))
            if abs(r(1, 2)) < 0.9999999 {
                a.y = Darwin.atan2(r(0, 2), r(2, 2)); a.z = Darwin.atan2(r(1, 0), r(1, 1))
            } else {
                a.y = Darwin.atan2(-r(2, 0), r(0, 0)); a.z = 0
            }
        } else {
            // R = Rz Ry Rx
            a.y = Darwin.asin(Swift.max(-1, Swift.min(1, -r(2, 0))))
            if abs(r(2, 0)) < 0.9999999 {
                a.x = Darwin.atan2(r(2, 1), r(2, 2)); a.z = Darwin.atan2(r(1, 0), r(0, 0))
            } else {
                a.x = Darwin.atan2(-r(1, 2), r(1, 1)); a.z = 0
            }
        }
        return EulerAngles(angles: a, order: order)
    }

    /// The part of the rotation about `twistAxis`.
    public func twist(twistAxis: RotationAxis3D) -> Rotation3D {
        let a = simd_normalize(twistAxis.vector), p = simd_dot(quaternion.imag, a) * a
        let t = simd_quatd(real: quaternion.real, imag: p)
        return t.length < 1e-12 ? .identity : Rotation3D(quaternion: t.normalized)
    }
    /// The rest of the rotation: `swing * twist == self`.
    public func swing(twistAxis: RotationAxis3D) -> Rotation3D { swingTwist(twistAxis: twistAxis).swing }
    public func swingTwist(twistAxis: RotationAxis3D) -> (swing: Rotation3D, twist: Rotation3D) {
        let t = twist(twistAxis: twistAxis)
        return (Rotation3D(quaternion: quaternion * t.quaternion.inverse), t)
    }

    /// The path a spherical interpolation takes.
    public enum SlerpPath: Hashable, Sendable {
        case automatic
        case shortest
        case longest
    }
    public static func slerp(from: Rotation3D, to: Rotation3D, t: Double, along path: SlerpPath = .automatic) -> Rotation3D {
        switch path {
        case .longest: return Rotation3D(quaternion: simd_slerp_longest(from.quaternion, to.quaternion, t))
        case .automatic, .shortest: return Rotation3D(quaternion: simd_slerp(from.quaternion, to.quaternion, t))
        }
    }
    public static func spline(leftEndpoint: Rotation3D, from: Rotation3D, to: Rotation3D, rightEndpoint: Rotation3D, t: Double) -> Rotation3D {
        Rotation3D(quaternion: simd_spline(leftEndpoint.quaternion, from.quaternion, to.quaternion, rightEndpoint.quaternion, t))
    }

    public func isApproximatelyEqual(to other: Rotation3D, tolerance: Double = Double.ulpOfOne.squareRoot()) -> Bool {
        let a = quaternion.vector, b = other.quaternion.vector
        func close(_ d: SIMD4<Double>) -> Bool { abs(d.x) <= tolerance && abs(d.y) <= tolerance && abs(d.z) <= tolerance && abs(d.w) <= tolerance }
        return close(a - b) || close(a + b)
    }

    public func rotated(by rotation: Rotation3D) -> Rotation3D { rotation * self }

    public static func * (a: Rotation3D, b: Rotation3D) -> Rotation3D { Rotation3D(quaternion: a.quaternion * b.quaternion) }
    public static func *= (a: inout Rotation3D, b: Rotation3D) { a = a * b }
    /// The rotation about the same axis by `s` times the angle.
    public static func * (r: Rotation3D, s: Double) -> Rotation3D { Rotation3D(angle: r.angle * s, axis: r.axis) }
    public static func * (s: Double, r: Rotation3D) -> Rotation3D { r * s }

    public static func == (a: Rotation3D, b: Rotation3D) -> Bool { a.quaternion == b.quaternion }
    public func hash(into h: inout Hasher) { h.combine(quaternion.vector) }

    private enum CodingKeys: String, CodingKey { case vector }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quaternion = simd_quatd(vector: try c.decode(SIMD4<Double>.self, forKey: .vector))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(quaternion.vector, forKey: .vector)
    }
    public var customMirror: Mirror { Mirror(self, children: ["angle": angle, "axis": axis]) }
}
