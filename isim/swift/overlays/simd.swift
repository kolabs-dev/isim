// isim simd (subset), self-authored: the C vector type names (vector_float2, simd_int2, ...) as the Swift
// standard library's SIMD types, and common geometric functions. Used by SpriteKit and GameplayKit.

import Darwin

public typealias vector_float2 = SIMD2<Float>
public typealias vector_float3 = SIMD3<Float>
public typealias vector_float4 = SIMD4<Float>
public typealias vector_double2 = SIMD2<Double>
public typealias vector_double3 = SIMD3<Double>
public typealias vector_double4 = SIMD4<Double>
public typealias vector_int2 = SIMD2<Int32>
public typealias vector_int3 = SIMD3<Int32>
public typealias vector_int4 = SIMD4<Int32>
public typealias vector_uint2 = SIMD2<UInt32>
public typealias vector_uint3 = SIMD3<UInt32>
public typealias vector_uint4 = SIMD4<UInt32>
public typealias simd_float2 = SIMD2<Float>
public typealias simd_float3 = SIMD3<Float>
public typealias simd_float4 = SIMD4<Float>
public typealias simd_double2 = SIMD2<Double>
public typealias simd_double3 = SIMD3<Double>
public typealias simd_double4 = SIMD4<Double>
public typealias simd_int2 = SIMD2<Int32>
public typealias simd_int3 = SIMD3<Int32>
public typealias simd_int4 = SIMD4<Int32>
public typealias simd_uint2 = SIMD2<UInt32>
public typealias simd_uint3 = SIMD3<UInt32>
public typealias simd_uint4 = SIMD4<UInt32>

@inlinable public func simd_dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { (a * b).sum() }
@inlinable public func simd_length_squared<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { (v * v).sum() }
@inlinable public func simd_length<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { (v * v).sum().squareRoot() }
@inlinable public func simd_distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length(a - b) }
@inlinable public func simd_distance_squared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length_squared(a - b) }
@inlinable public func simd_normalize<V: SIMD>(_ v: V) -> V where V.Scalar: FloatingPoint {
    let l = simd_length(v)
    return l > 0 ? v / l : v
}
@inlinable public func simd_mix<V: SIMD>(_ a: V, _ b: V, _ t: V) -> V where V.Scalar: FloatingPoint { a + (b - a) * t }
@inlinable public func simd_clamp<V: SIMD>(_ v: V, _ lo: V, _ hi: V) -> V where V.Scalar: Comparable { v.clamped(lowerBound: lo, upperBound: hi) }
@inlinable public func simd_min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable { pointwiseMin(a, b) }
@inlinable public func simd_max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable { pointwiseMax(a, b) }
@inlinable public func simd_abs<V: SIMD>(_ v: V) -> V where V.Scalar: FloatingPoint { var r = v; for i in r.indices { r[i] = abs(r[i]) }; return r }
@inlinable public func simd_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
@inlinable public func simd_cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

// the overloaded Swift spellings (simd module on iOS)
@inlinable public func dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_dot(a, b) }
@inlinable public func length<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length(v) }
@inlinable public func length_squared<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_length_squared(v) }
@inlinable public func distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_distance(a, b) }
@inlinable public func distance_squared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: FloatingPoint { simd_distance_squared(a, b) }
@inlinable public func normalize<V: SIMD>(_ v: V) -> V where V.Scalar: FloatingPoint { simd_normalize(v) }
@inlinable public func mix<V: SIMD>(_ a: V, _ b: V, t: V.Scalar) -> V where V.Scalar: FloatingPoint { a + (b - a) * t }
@inlinable public func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { simd_cross(a, b) }
@inlinable public func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> { simd_cross(a, b) }

// MARK: - 3x3 matrices and quaternions (subset; used by SKTransformNode)

/// A 3x3 matrix of Floats, stored as three columns.
@frozen public struct simd_float3x3: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
    public init(columns: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)) { self.columns = columns }
    public init() { columns = (.zero, .zero, .zero) }
    public init(diagonal d: SIMD3<Float>) { columns = (SIMD3(d.x, 0, 0), SIMD3(0, d.y, 0), SIMD3(0, 0, d.z)) }
    public init(_ c0: SIMD3<Float>, _ c1: SIMD3<Float>, _ c2: SIMD3<Float>) { columns = (c0, c1, c2) }
    public init(_ columns: [SIMD3<Float>]) { precondition(columns.count == 3); self.columns = (columns[0], columns[1], columns[2]) }
    public init(rows r: [SIMD3<Float>]) {
        precondition(r.count == 3)
        columns = (SIMD3(r[0].x, r[1].x, r[2].x), SIMD3(r[0].y, r[1].y, r[2].y), SIMD3(r[0].z, r[1].z, r[2].z))
    }
    /// the rotation a unit quaternion describes
    public init(_ q: simd_quatf) {
        let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real
        columns = (SIMD3(1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w)),
                   SIMD3(2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w)),
                   SIMD3(2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)))
    }
    public subscript(column: Int) -> SIMD3<Float> {
        get { column == 0 ? columns.0 : column == 1 ? columns.1 : columns.2 }
        set { if column == 0 { columns.0 = newValue } else if column == 1 { columns.1 = newValue } else { columns.2 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Float {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public var transpose: simd_float3x3 {
        simd_float3x3(rows: [columns.0, columns.1, columns.2])
    }
    public static func == (a: simd_float3x3, b: simd_float3x3) -> Bool { a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 && a.columns.2 == b.columns.2 }
    public static func * (m: simd_float3x3, v: SIMD3<Float>) -> SIMD3<Float> { m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z }
    public static func * (a: simd_float3x3, b: simd_float3x3) -> simd_float3x3 { simd_float3x3(a * b.columns.0, a * b.columns.1, a * b.columns.2) }
}
public typealias matrix_float3x3 = simd_float3x3
public let matrix_identity_float3x3 = simd_float3x3(diagonal: SIMD3<Float>(1, 1, 1))
public func simd_mul(_ a: simd_float3x3, _ b: simd_float3x3) -> simd_float3x3 { a * b }
public func simd_mul(_ m: simd_float3x3, _ v: SIMD3<Float>) -> SIMD3<Float> { m * v }
public func simd_transpose(_ m: simd_float3x3) -> simd_float3x3 { m.transpose }

/// A 2x2 matrix of Floats, stored as two columns.
@frozen public struct simd_float2x2: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD2<Float>, SIMD2<Float>)
    public init(columns: (SIMD2<Float>, SIMD2<Float>)) { self.columns = columns }
    public init() { columns = (.zero, .zero) }
    public init(_ scalar: Float) { columns = (SIMD2(scalar, 0), SIMD2(0, scalar)) }
    public init(diagonal d: SIMD2<Float>) { columns = (SIMD2(d.x, 0), SIMD2(0, d.y)) }
    public init(_ c0: SIMD2<Float>, _ c1: SIMD2<Float>) { columns = (c0, c1) }
    public init(_ columns: [SIMD2<Float>]) { precondition(columns.count == 2); self.columns = (columns[0], columns[1]) }
    public init(rows r: [SIMD2<Float>]) { precondition(r.count == 2); columns = (SIMD2(r[0].x, r[1].x), SIMD2(r[0].y, r[1].y)) }
    public subscript(column: Int) -> SIMD2<Float> {
        get { column == 0 ? columns.0 : columns.1 }
        set { if column == 0 { columns.0 = newValue } else { columns.1 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Float {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public var transpose: simd_float2x2 { simd_float2x2(rows: [columns.0, columns.1]) }
    public static func == (a: simd_float2x2, b: simd_float2x2) -> Bool { a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 }
    public static func * (m: simd_float2x2, v: SIMD2<Float>) -> SIMD2<Float> { m.columns.0 * v.x + m.columns.1 * v.y }
    public static func * (a: simd_float2x2, b: simd_float2x2) -> simd_float2x2 { simd_float2x2(a * b.columns.0, a * b.columns.1) }
}
public typealias matrix_float2x2 = simd_float2x2
public let matrix_identity_float2x2 = simd_float2x2(diagonal: SIMD2<Float>(1, 1))
extension simd_float3x3 {
    public init(_ scalar: Float) { self.init(diagonal: SIMD3(scalar, scalar, scalar)) }
}

/// A 4x4 matrix of Floats, stored as four columns.
@frozen public struct simd_float4x4: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    public init(columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)) { self.columns = columns }
    public init() { columns = (.zero, .zero, .zero, .zero) }
    public init(_ scalar: Float) { self.init(diagonal: SIMD4(scalar, scalar, scalar, scalar)) }
    public init(diagonal d: SIMD4<Float>) { columns = (SIMD4(d.x, 0, 0, 0), SIMD4(0, d.y, 0, 0), SIMD4(0, 0, d.z, 0), SIMD4(0, 0, 0, d.w)) }
    public init(_ c0: SIMD4<Float>, _ c1: SIMD4<Float>, _ c2: SIMD4<Float>, _ c3: SIMD4<Float>) { columns = (c0, c1, c2, c3) }
    public init(_ columns: [SIMD4<Float>]) { precondition(columns.count == 4); self.columns = (columns[0], columns[1], columns[2], columns[3]) }
    /// the rotation a unit quaternion describes (no translation)
    public init(_ q: simd_quatf) {
        let r = simd_float3x3(q)
        columns = (SIMD4(r.columns.0, 0), SIMD4(r.columns.1, 0), SIMD4(r.columns.2, 0), SIMD4(0, 0, 0, 1))
    }
    public init(rows r: [SIMD4<Float>]) {
        precondition(r.count == 4)
        columns = (SIMD4(r[0].x, r[1].x, r[2].x, r[3].x), SIMD4(r[0].y, r[1].y, r[2].y, r[3].y),
                   SIMD4(r[0].z, r[1].z, r[2].z, r[3].z), SIMD4(r[0].w, r[1].w, r[2].w, r[3].w))
    }
    public subscript(column: Int) -> SIMD4<Float> {
        get { column == 0 ? columns.0 : column == 1 ? columns.1 : column == 2 ? columns.2 : columns.3 }
        set { if column == 0 { columns.0 = newValue } else if column == 1 { columns.1 = newValue } else if column == 2 { columns.2 = newValue } else { columns.3 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Float {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public var transpose: simd_float4x4 { simd_float4x4(rows: [columns.0, columns.1, columns.2, columns.3]) }
    public static func == (a: simd_float4x4, b: simd_float4x4) -> Bool { a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 && a.columns.2 == b.columns.2 && a.columns.3 == b.columns.3 }
    public static func * (m: simd_float4x4, v: SIMD4<Float>) -> SIMD4<Float> { m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z + m.columns.3 * v.w }
    public static func * (a: simd_float4x4, b: simd_float4x4) -> simd_float4x4 { simd_float4x4(a * b.columns.0, a * b.columns.1, a * b.columns.2, a * b.columns.3) }
}
public typealias matrix_float4x4 = simd_float4x4
public let matrix_identity_float4x4 = simd_float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))
public func simd_mul(_ a: simd_float2x2, _ b: simd_float2x2) -> simd_float2x2 { a * b }
public func simd_mul(_ a: simd_float4x4, _ b: simd_float4x4) -> simd_float4x4 { a * b }
public func simd_transpose(_ m: simd_float2x2) -> simd_float2x2 { m.transpose }
public func simd_transpose(_ m: simd_float4x4) -> simd_float4x4 { m.transpose }

/// A quaternion of Floats: vector = (ix, iy, iz, r).
@frozen public struct simd_quatf: Equatable, Sendable, BitwiseCopyable {
    public var vector: SIMD4<Float>
    public init() { vector = SIMD4(0, 0, 0, 1) }
    public init(vector: SIMD4<Float>) { self.vector = vector }
    public init(ix: Float, iy: Float, iz: Float, r: Float) { vector = SIMD4(ix, iy, iz, r) }
    public init(real: Float, imag: SIMD3<Float>) { vector = SIMD4(imag.x, imag.y, imag.z, real) }
    /// rotation by `angle` radians around `axis` (normalized here)
    public init(angle: Float, axis: SIMD3<Float>) {
        let a = simd_normalize(axis), s = sinf(angle / 2)
        vector = SIMD4(a.x * s, a.y * s, a.z * s, cosf(angle / 2))
    }
    /// the rotation of an orthonormal rotation matrix
    public init(_ m: simd_float3x3) {
        let m00 = m[0, 0], m11 = m[1, 1], m22 = m[2, 2]
        let t = m00 + m11 + m22
        if t > 0 {
            let s = (t + 1).squareRoot() * 2
            vector = SIMD4((m[1, 2] - m[2, 1]) / s, (m[2, 0] - m[0, 2]) / s, (m[0, 1] - m[1, 0]) / s, s / 4)
        } else if m00 > m11 && m00 > m22 {
            let s = (1 + m00 - m11 - m22).squareRoot() * 2
            vector = SIMD4(s / 4, (m[1, 0] + m[0, 1]) / s, (m[2, 0] + m[0, 2]) / s, (m[1, 2] - m[2, 1]) / s)
        } else if m11 > m22 {
            let s = (1 + m11 - m00 - m22).squareRoot() * 2
            vector = SIMD4((m[1, 0] + m[0, 1]) / s, s / 4, (m[2, 1] + m[1, 2]) / s, (m[2, 0] - m[0, 2]) / s)
        } else {
            let s = (1 + m22 - m00 - m11).squareRoot() * 2
            vector = SIMD4((m[2, 0] + m[0, 2]) / s, (m[2, 1] + m[1, 2]) / s, s / 4, (m[0, 1] - m[1, 0]) / s)
        }
    }
    public var real: Float { get { vector.w } set { vector.w = newValue } }
    public var imag: SIMD3<Float> { get { SIMD3(vector.x, vector.y, vector.z) } set { vector = SIMD4(newValue.x, newValue.y, newValue.z, vector.w) } }
    public var length: Float { simd_length(vector) }
    public var normalized: simd_quatf { simd_quatf(vector: simd_normalize(vector)) }
    public var conjugate: simd_quatf { simd_quatf(real: real, imag: -imag) }
    public var inverse: simd_quatf { let l2 = simd_length_squared(vector); return simd_quatf(vector: conjugate.vector / l2) }
    public var angle: Float { 2 * atan2f(simd_length(imag), real) }
    public var axis: SIMD3<Float> { let l = simd_length(imag); return l > 0 ? imag / l : SIMD3(1, 0, 0) }
    /// rotates a vector
    public func act(_ v: SIMD3<Float>) -> SIMD3<Float> { (self * simd_quatf(real: 0, imag: v) * conjugate).imag }
    public static func * (a: simd_quatf, b: simd_quatf) -> simd_quatf {
        simd_quatf(real: a.real * b.real - simd_dot(a.imag, b.imag),
                   imag: b.imag * a.real + a.imag * b.real + simd_cross(a.imag, b.imag))
    }
}
public func simd_quaternion(_ angle: Float, _ axis: SIMD3<Float>) -> simd_quatf { simd_quatf(angle: angle, axis: axis) }
extension simd_quatf {
    /// the shortest rotation that turns one unit vector into another
    public init(from: SIMD3<Float>, to: SIMD3<Float>) {
        let a = simd_normalize(from), b = simd_normalize(to)
        let d = simd_dot(a, b)
        if d < -0.999999 {
            // opposite: half a turn about any perpendicular axis
            var axis = simd_cross(SIMD3<Float>(1, 0, 0), a)
            if simd_length(axis) < 1e-6 { axis = simd_cross(SIMD3<Float>(0, 1, 0), a) }
            self.init(angle: .pi, axis: axis)
            return
        }
        let c = simd_cross(a, b)
        self.init(vector: simd_normalize(SIMD4(c.x, c.y, c.z, 1 + d)))
    }
    /// the rotation of a 4x4 matrix's upper 3x3
    public init(_ m: simd_float4x4) {
        self.init(simd_float3x3(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z), SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)))
    }
    public static func + (a: simd_quatf, b: simd_quatf) -> simd_quatf { simd_quatf(vector: a.vector + b.vector) }
    public static func - (a: simd_quatf, b: simd_quatf) -> simd_quatf { simd_quatf(vector: a.vector - b.vector) }
    public static prefix func - (a: simd_quatf) -> simd_quatf { simd_quatf(vector: -a.vector) }
    public static func * (a: simd_quatf, s: Float) -> simd_quatf { simd_quatf(vector: a.vector * s) }
    public static func * (s: Float, a: simd_quatf) -> simd_quatf { simd_quatf(vector: a.vector * s) }
    public static func / (a: simd_quatf, s: Float) -> simd_quatf { simd_quatf(vector: a.vector / s) }
    public static func / (a: simd_quatf, b: simd_quatf) -> simd_quatf { a * b.inverse }
}
public func simd_length(_ q: simd_quatf) -> Float { simd_length(q.vector) }
public func simd_normalize(_ q: simd_quatf) -> simd_quatf { q.normalized }
public func simd_dot(_ a: simd_quatf, _ b: simd_quatf) -> Float { simd_dot(a.vector, b.vector) }
public func simd_conjugate(_ q: simd_quatf) -> simd_quatf { q.conjugate }
public func simd_inverse(_ q: simd_quatf) -> simd_quatf { q.inverse }
public func simd_mul(_ a: simd_quatf, _ b: simd_quatf) -> simd_quatf { a * b }
public func simd_angle(_ q: simd_quatf) -> Float { q.angle }
public func simd_axis(_ q: simd_quatf) -> SIMD3<Float> { q.axis }
public func simd_imag(_ q: simd_quatf) -> SIMD3<Float> { q.imag }
public func simd_real(_ q: simd_quatf) -> Float { q.real }
public func simd_quaternion(_ m: simd_float3x3) -> simd_quatf { simd_quatf(m) }
public func simd_quaternion(_ m: simd_float4x4) -> simd_quatf { simd_quatf(m) }
public func simd_quaternion(_ from: SIMD3<Float>, _ to: SIMD3<Float>) -> simd_quatf { simd_quatf(from: from, to: to) }
public func simd_matrix4x4(_ q: simd_quatf) -> simd_float4x4 { simd_float4x4(q) }
/// spherical interpolation between two rotations; `simd_slerp` takes the shorter arc, `simd_slerp_longest` the longer
public func simd_slerp(_ q0: simd_quatf, _ q1: simd_quatf, _ t: Float) -> simd_quatf {
    _simd_slerp(q0, simd_dot(q0, q1) < 0 ? -q1 : q1, t)
}
public func simd_slerp_longest(_ q0: simd_quatf, _ q1: simd_quatf, _ t: Float) -> simd_quatf {
    _simd_slerp(q0, simd_dot(q0, q1) >= 0 ? -q1 : q1, t)
}
func _simd_slerp(_ a: simd_quatf, _ b: simd_quatf, _ t: Float) -> simd_quatf {
    let d = max(-1, min(1, simd_dot(a.vector, b.vector)))
    if d > 0.9995 { return simd_quatf(vector: simd_normalize(a.vector + (b.vector - a.vector) * t)) }
    let th = acosf(d), s = sinf(th)
    return simd_quatf(vector: a.vector * (sinf((1 - t) * th) / s) + b.vector * (sinf(t * th) / s))
}
public func simd_matrix3x3(_ q: simd_quatf) -> simd_float3x3 { simd_float3x3(q) }
public func simd_act(_ q: simd_quatf, _ v: SIMD3<Float>) -> SIMD3<Float> { q.act(v) }

// Apple's Swift names for the matrix types, and their inverses and determinants (issue #331)
public typealias float2x2 = simd_float2x2
public typealias float3x3 = simd_float3x3
public typealias float4x4 = simd_float4x4
extension simd_float4x4 {
    /// the inverse (cofactors; a singular matrix stays as it is)
    public var inverse: simd_float4x4 {
        var a = [Float](repeating: 0, count: 16)
        for c in 0..<4 { for r in 0..<4 { a[c * 4 + r] = self[c, r] } }
        var inv = [Float](repeating: 0, count: 16)
        inv[0] = a[5]*a[10]*a[15] - a[5]*a[11]*a[14] - a[9]*a[6]*a[15] + a[9]*a[7]*a[14] + a[13]*a[6]*a[11] - a[13]*a[7]*a[10]
        inv[4] = -a[4]*a[10]*a[15] + a[4]*a[11]*a[14] + a[8]*a[6]*a[15] - a[8]*a[7]*a[14] - a[12]*a[6]*a[11] + a[12]*a[7]*a[10]
        inv[8] = a[4]*a[9]*a[15] - a[4]*a[11]*a[13] - a[8]*a[5]*a[15] + a[8]*a[7]*a[13] + a[12]*a[5]*a[11] - a[12]*a[7]*a[9]
        inv[12] = -a[4]*a[9]*a[14] + a[4]*a[10]*a[13] + a[8]*a[5]*a[14] - a[8]*a[6]*a[13] - a[12]*a[5]*a[10] + a[12]*a[6]*a[9]
        inv[1] = -a[1]*a[10]*a[15] + a[1]*a[11]*a[14] + a[9]*a[2]*a[15] - a[9]*a[3]*a[14] - a[13]*a[2]*a[11] + a[13]*a[3]*a[10]
        inv[5] = a[0]*a[10]*a[15] - a[0]*a[11]*a[14] - a[8]*a[2]*a[15] + a[8]*a[3]*a[14] + a[12]*a[2]*a[11] - a[12]*a[3]*a[10]
        inv[9] = -a[0]*a[9]*a[15] + a[0]*a[11]*a[13] + a[8]*a[1]*a[15] - a[8]*a[3]*a[13] - a[12]*a[1]*a[11] + a[12]*a[3]*a[9]
        inv[13] = a[0]*a[9]*a[14] - a[0]*a[10]*a[13] - a[8]*a[1]*a[14] + a[8]*a[2]*a[13] + a[12]*a[1]*a[10] - a[12]*a[2]*a[9]
        inv[2] = a[1]*a[6]*a[15] - a[1]*a[7]*a[14] - a[5]*a[2]*a[15] + a[5]*a[3]*a[14] + a[13]*a[2]*a[7] - a[13]*a[3]*a[6]
        inv[6] = -a[0]*a[6]*a[15] + a[0]*a[7]*a[14] + a[4]*a[2]*a[15] - a[4]*a[3]*a[14] - a[12]*a[2]*a[7] + a[12]*a[3]*a[6]
        inv[10] = a[0]*a[5]*a[15] - a[0]*a[7]*a[13] - a[4]*a[1]*a[15] + a[4]*a[3]*a[13] + a[12]*a[1]*a[7] - a[12]*a[3]*a[5]
        inv[14] = -a[0]*a[5]*a[14] + a[0]*a[6]*a[13] + a[4]*a[1]*a[14] - a[4]*a[2]*a[13] - a[12]*a[1]*a[6] + a[12]*a[2]*a[5]
        inv[3] = -a[1]*a[6]*a[11] + a[1]*a[7]*a[10] + a[5]*a[2]*a[11] - a[5]*a[3]*a[10] - a[9]*a[2]*a[7] + a[9]*a[3]*a[6]
        inv[7] = a[0]*a[6]*a[11] - a[0]*a[7]*a[10] - a[4]*a[2]*a[11] + a[4]*a[3]*a[10] + a[8]*a[2]*a[7] - a[8]*a[3]*a[6]
        inv[11] = -a[0]*a[5]*a[11] + a[0]*a[7]*a[9] + a[4]*a[1]*a[11] - a[4]*a[3]*a[9] - a[8]*a[1]*a[7] + a[8]*a[3]*a[5]
        inv[15] = a[0]*a[5]*a[10] - a[0]*a[6]*a[9] - a[4]*a[1]*a[10] + a[4]*a[2]*a[9] + a[8]*a[1]*a[6] - a[8]*a[2]*a[5]
        let det = a[0] * inv[0] + a[1] * inv[4] + a[2] * inv[8] + a[3] * inv[12]
        guard det != 0 else { return self }
        var out = simd_float4x4()
        for c in 0..<4 { for r in 0..<4 { out[c, r] = inv[c * 4 + r] / det } }
        return out
    }
}
public func simd_inverse(_ m: simd_float4x4) -> simd_float4x4 { m.inverse }
