// isim simd overlay (self-authored, Apple's API names): the double-precision matrices and quaternion (issue #370,
// what Spatial builds on) and the 4x3 matrices: simd_double3x3, simd_double4x3, simd_double4x4, simd_float4x3,
// simd_quatd, with Apple's free functions over them (simd_mul, simd_transpose, simd_inverse, simd_determinant,
// simd_quaternion, simd_act, simd_slerp, ...).
import Darwin

/// A 3x3 matrix of Doubles, stored as three columns.
@frozen public struct simd_double3x3: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
    public init(columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)) { self.columns = columns }
    public init() { columns = (.zero, .zero, .zero) }
    public init(_ scalar: Double) { self.init(diagonal: SIMD3(scalar, scalar, scalar)) }
    public init(diagonal d: SIMD3<Double>) { columns = (SIMD3(d.x, 0, 0), SIMD3(0, d.y, 0), SIMD3(0, 0, d.z)) }
    public init(_ c0: SIMD3<Double>, _ c1: SIMD3<Double>, _ c2: SIMD3<Double>) { columns = (c0, c1, c2) }
    public init(_ columns: [SIMD3<Double>]) { precondition(columns.count == 3); self.columns = (columns[0], columns[1], columns[2]) }
    public init(rows r: [SIMD3<Double>]) {
        precondition(r.count == 3)
        columns = (SIMD3(r[0].x, r[1].x, r[2].x), SIMD3(r[0].y, r[1].y, r[2].y), SIMD3(r[0].z, r[1].z, r[2].z))
    }
    /// the rotation a unit quaternion describes
    public init(_ q: simd_quatd) {
        let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real
        columns = (SIMD3(1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w)),
                   SIMD3(2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w)),
                   SIMD3(2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)))
    }
    public subscript(column: Int) -> SIMD3<Double> {
        get { column == 0 ? columns.0 : column == 1 ? columns.1 : columns.2 }
        set { if column == 0 { columns.0 = newValue } else if column == 1 { columns.1 = newValue } else { columns.2 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Double {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public var transpose: simd_double3x3 { simd_double3x3(rows: [columns.0, columns.1, columns.2]) }
    public var determinant: Double { simd_dot(columns.0, simd_cross(columns.1, columns.2)) }
    /// the inverse (a singular matrix stays as it is)
    public var inverse: simd_double3x3 {
        let det = determinant
        guard det != 0 else { return self }
        let r0 = simd_cross(columns.1, columns.2), r1 = simd_cross(columns.2, columns.0), r2 = simd_cross(columns.0, columns.1)
        return simd_double3x3(rows: [r0 / det, r1 / det, r2 / det])
    }
    public static func == (a: simd_double3x3, b: simd_double3x3) -> Bool { a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 && a.columns.2 == b.columns.2 }
    public static func * (m: simd_double3x3, v: SIMD3<Double>) -> SIMD3<Double> { m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z }
    public static func * (a: simd_double3x3, b: simd_double3x3) -> simd_double3x3 { simd_double3x3(a * b.columns.0, a * b.columns.1, a * b.columns.2) }
    public static func * (m: simd_double3x3, s: Double) -> simd_double3x3 { simd_double3x3(m.columns.0 * s, m.columns.1 * s, m.columns.2 * s) }
    public static func + (a: simd_double3x3, b: simd_double3x3) -> simd_double3x3 { simd_double3x3(a.columns.0 + b.columns.0, a.columns.1 + b.columns.1, a.columns.2 + b.columns.2) }
    public static func - (a: simd_double3x3, b: simd_double3x3) -> simd_double3x3 { simd_double3x3(a.columns.0 - b.columns.0, a.columns.1 - b.columns.1, a.columns.2 - b.columns.2) }
}

/// A 4x3 matrix of Doubles: four columns of three rows (an affine transform's linear part and translation).
@frozen public struct simd_double4x3: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
    public init(columns: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)) { self.columns = columns }
    public init() { columns = (.zero, .zero, .zero, .zero) }
    public init(_ scalar: Double) { columns = (SIMD3(scalar, 0, 0), SIMD3(0, scalar, 0), SIMD3(0, 0, scalar), .zero) }
    public init(_ c0: SIMD3<Double>, _ c1: SIMD3<Double>, _ c2: SIMD3<Double>, _ c3: SIMD3<Double>) { columns = (c0, c1, c2, c3) }
    public init(_ columns: [SIMD3<Double>]) { precondition(columns.count == 4); self.columns = (columns[0], columns[1], columns[2], columns[3]) }
    public init(rows r: [SIMD4<Double>]) {
        precondition(r.count == 3)
        columns = (SIMD3(r[0].x, r[1].x, r[2].x), SIMD3(r[0].y, r[1].y, r[2].y), SIMD3(r[0].z, r[1].z, r[2].z), SIMD3(r[0].w, r[1].w, r[2].w))
    }
    public subscript(column: Int) -> SIMD3<Double> {
        get { column == 0 ? columns.0 : column == 1 ? columns.1 : column == 2 ? columns.2 : columns.3 }
        set { if column == 0 { columns.0 = newValue } else if column == 1 { columns.1 = newValue } else if column == 2 { columns.2 = newValue } else { columns.3 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Double {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public static func == (a: simd_double4x3, b: simd_double4x3) -> Bool {
        a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 && a.columns.2 == b.columns.2 && a.columns.3 == b.columns.3
    }
    public static func * (m: simd_double4x3, v: SIMD4<Double>) -> SIMD3<Double> { m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z + m.columns.3 * v.w }
}

/// A 4x3 matrix of Floats.
@frozen public struct simd_float4x3: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
    public init(columns: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)) { self.columns = columns }
    public init() { columns = (.zero, .zero, .zero, .zero) }
    public init(_ scalar: Float) { columns = (SIMD3(scalar, 0, 0), SIMD3(0, scalar, 0), SIMD3(0, 0, scalar), .zero) }
    public init(_ c0: SIMD3<Float>, _ c1: SIMD3<Float>, _ c2: SIMD3<Float>, _ c3: SIMD3<Float>) { columns = (c0, c1, c2, c3) }
    public subscript(column: Int) -> SIMD3<Float> {
        get { column == 0 ? columns.0 : column == 1 ? columns.1 : column == 2 ? columns.2 : columns.3 }
        set { if column == 0 { columns.0 = newValue } else if column == 1 { columns.1 = newValue } else if column == 2 { columns.2 = newValue } else { columns.3 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Float {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public static func == (a: simd_float4x3, b: simd_float4x3) -> Bool {
        a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 && a.columns.2 == b.columns.2 && a.columns.3 == b.columns.3
    }
}

/// A 4x4 matrix of Doubles, stored as four columns.
@frozen public struct simd_double4x4: Equatable, Sendable, BitwiseCopyable {
    public var columns: (SIMD4<Double>, SIMD4<Double>, SIMD4<Double>, SIMD4<Double>)
    public init(columns: (SIMD4<Double>, SIMD4<Double>, SIMD4<Double>, SIMD4<Double>)) { self.columns = columns }
    public init() { columns = (.zero, .zero, .zero, .zero) }
    public init(_ scalar: Double) { self.init(diagonal: SIMD4(scalar, scalar, scalar, scalar)) }
    public init(diagonal d: SIMD4<Double>) { columns = (SIMD4(d.x, 0, 0, 0), SIMD4(0, d.y, 0, 0), SIMD4(0, 0, d.z, 0), SIMD4(0, 0, 0, d.w)) }
    public init(_ c0: SIMD4<Double>, _ c1: SIMD4<Double>, _ c2: SIMD4<Double>, _ c3: SIMD4<Double>) { columns = (c0, c1, c2, c3) }
    public init(_ columns: [SIMD4<Double>]) { precondition(columns.count == 4); self.columns = (columns[0], columns[1], columns[2], columns[3]) }
    public init(rows r: [SIMD4<Double>]) {
        precondition(r.count == 4)
        columns = (SIMD4(r[0].x, r[1].x, r[2].x, r[3].x), SIMD4(r[0].y, r[1].y, r[2].y, r[3].y),
                   SIMD4(r[0].z, r[1].z, r[2].z, r[3].z), SIMD4(r[0].w, r[1].w, r[2].w, r[3].w))
    }
    /// the rotation a unit quaternion describes (no translation)
    public init(_ q: simd_quatd) {
        let r = simd_double3x3(q)
        columns = (SIMD4(r.columns.0, 0), SIMD4(r.columns.1, 0), SIMD4(r.columns.2, 0), SIMD4(0, 0, 0, 1))
    }
    public subscript(column: Int) -> SIMD4<Double> {
        get { column == 0 ? columns.0 : column == 1 ? columns.1 : column == 2 ? columns.2 : columns.3 }
        set { if column == 0 { columns.0 = newValue } else if column == 1 { columns.1 = newValue } else if column == 2 { columns.2 = newValue } else { columns.3 = newValue } }
    }
    public subscript(column: Int, row: Int) -> Double {
        get { self[column][row] }
        set { var c = self[column]; c[row] = newValue; self[column] = c }
    }
    public var transpose: simd_double4x4 { simd_double4x4(rows: [columns.0, columns.1, columns.2, columns.3]) }
    public var determinant: Double {
        let a = self
        func m3(_ c: [Int], _ r: [Int]) -> Double {
            simd_double3x3(SIMD3(a[c[0], r[0]], a[c[0], r[1]], a[c[0], r[2]]), SIMD3(a[c[1], r[0]], a[c[1], r[1]], a[c[1], r[2]]),
                           SIMD3(a[c[2], r[0]], a[c[2], r[1]], a[c[2], r[2]])).determinant
        }
        return a[0, 0] * m3([1, 2, 3], [1, 2, 3]) - a[1, 0] * m3([0, 2, 3], [1, 2, 3]) + a[2, 0] * m3([0, 1, 3], [1, 2, 3]) - a[3, 0] * m3([0, 1, 2], [1, 2, 3])
    }
    /// the inverse by Gauss-Jordan elimination with partial pivoting (a singular matrix stays as it is)
    public var inverse: simd_double4x4 {
        var a = [[Double]](repeating: [Double](repeating: 0, count: 8), count: 4)
        for r in 0..<4 { for c in 0..<4 { a[r][c] = self[c, r] }; a[r][4 + r] = 1 }
        for col in 0..<4 {
            var p = col
            for r in col + 1..<4 where abs(a[r][col]) > abs(a[p][col]) { p = r }
            guard abs(a[p][col]) > 1e-300 else { return self }
            a.swapAt(p, col)
            let d = a[col][col]
            for k in 0..<8 { a[col][k] /= d }
            for r in 0..<4 where r != col {
                let f = a[r][col]
                if f != 0 { for k in 0..<8 { a[r][k] -= f * a[col][k] } }
            }
        }
        var out = simd_double4x4()
        for r in 0..<4 { for c in 0..<4 { out[c, r] = a[r][4 + c] } }
        return out
    }
    public static func == (a: simd_double4x4, b: simd_double4x4) -> Bool { a.columns.0 == b.columns.0 && a.columns.1 == b.columns.1 && a.columns.2 == b.columns.2 && a.columns.3 == b.columns.3 }
    public static func * (m: simd_double4x4, v: SIMD4<Double>) -> SIMD4<Double> { m.columns.0 * v.x + m.columns.1 * v.y + m.columns.2 * v.z + m.columns.3 * v.w }
    public static func * (a: simd_double4x4, b: simd_double4x4) -> simd_double4x4 { simd_double4x4(a * b.columns.0, a * b.columns.1, a * b.columns.2, a * b.columns.3) }
}

/// A quaternion of Doubles: vector = (ix, iy, iz, r).
@frozen public struct simd_quatd: Equatable, Hashable, Sendable, BitwiseCopyable {
    public var vector: SIMD4<Double>
    public init() { vector = SIMD4(0, 0, 0, 1) }
    public init(vector: SIMD4<Double>) { self.vector = vector }
    public init(ix: Double, iy: Double, iz: Double, r: Double) { vector = SIMD4(ix, iy, iz, r) }
    public init(real: Double, imag: SIMD3<Double>) { vector = SIMD4(imag.x, imag.y, imag.z, real) }
    /// rotation by `angle` radians around `axis` (normalized here)
    public init(angle: Double, axis: SIMD3<Double>) {
        let l = simd_length(axis)
        let a = l > 0 ? axis / l : SIMD3<Double>(0, 0, 1), s = Darwin.sin(angle / 2)
        vector = SIMD4(a.x * s, a.y * s, a.z * s, Darwin.cos(angle / 2))
    }
    /// the shortest rotation that turns one vector into another
    public init(from: SIMD3<Double>, to: SIMD3<Double>) {
        let a = simd_normalize(from), b = simd_normalize(to)
        let d = simd_dot(a, b)
        if d < -0.999999999 {
            var axis = simd_cross(SIMD3<Double>(1, 0, 0), a)
            if simd_length(axis) < 1e-9 { axis = simd_cross(SIMD3<Double>(0, 1, 0), a) }
            self.init(angle: .pi, axis: axis)
            return
        }
        let c = simd_cross(a, b)
        self.init(vector: simd_normalize(SIMD4(c.x, c.y, c.z, 1 + d)))
    }
    /// the rotation of an orthonormal rotation matrix
    public init(_ m: simd_double3x3) {
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
    /// the rotation of a 4x4 matrix's upper 3x3
    public init(_ m: simd_double4x4) {
        self.init(simd_double3x3(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z), SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                 SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)))
    }
    public var real: Double { get { vector.w } set { vector.w = newValue } }
    public var imag: SIMD3<Double> { get { SIMD3(vector.x, vector.y, vector.z) } set { vector = SIMD4(newValue.x, newValue.y, newValue.z, vector.w) } }
    public var length: Double { simd_length(vector) }
    public var normalized: simd_quatd { simd_quatd(vector: simd_normalize(vector)) }
    public var conjugate: simd_quatd { simd_quatd(real: real, imag: -imag) }
    public var inverse: simd_quatd { let l2 = simd_length_squared(vector); return simd_quatd(vector: conjugate.vector / l2) }
    public var angle: Double { 2 * Darwin.atan2(simd_length(imag), real) }
    public var axis: SIMD3<Double> { let l = simd_length(imag); return l > 0 ? imag / l : SIMD3(1, 0, 0) }
    /// rotates a vector
    public func act(_ v: SIMD3<Double>) -> SIMD3<Double> { (self * simd_quatd(real: 0, imag: v) * conjugate).imag }
    public static func * (a: simd_quatd, b: simd_quatd) -> simd_quatd {
        simd_quatd(real: a.real * b.real - simd_dot(a.imag, b.imag),
                   imag: b.imag * a.real + a.imag * b.real + simd_cross(a.imag, b.imag))
    }
    public static func + (a: simd_quatd, b: simd_quatd) -> simd_quatd { simd_quatd(vector: a.vector + b.vector) }
    public static func - (a: simd_quatd, b: simd_quatd) -> simd_quatd { simd_quatd(vector: a.vector - b.vector) }
    public static prefix func - (a: simd_quatd) -> simd_quatd { simd_quatd(vector: -a.vector) }
    public static func * (a: simd_quatd, s: Double) -> simd_quatd { simd_quatd(vector: a.vector * s) }
    public static func * (s: Double, a: simd_quatd) -> simd_quatd { simd_quatd(vector: a.vector * s) }
    public static func / (a: simd_quatd, s: Double) -> simd_quatd { simd_quatd(vector: a.vector / s) }
    public static func / (a: simd_quatd, b: simd_quatd) -> simd_quatd { a * b.inverse }
}

public typealias matrix_double3x3 = simd_double3x3
public typealias matrix_double4x3 = simd_double4x3
public typealias matrix_double4x4 = simd_double4x4
public typealias matrix_float4x3 = simd_float4x3
public typealias double3x3 = simd_double3x3
public typealias double4x3 = simd_double4x3
public typealias double4x4 = simd_double4x4
public typealias float4x3 = simd_float4x3
public let matrix_identity_double3x3 = simd_double3x3(diagonal: SIMD3<Double>(1, 1, 1))
public let matrix_identity_double4x4 = simd_double4x4(diagonal: SIMD4<Double>(1, 1, 1, 1))

public func simd_mul(_ a: simd_double3x3, _ b: simd_double3x3) -> simd_double3x3 { a * b }
public func simd_mul(_ m: simd_double3x3, _ v: SIMD3<Double>) -> SIMD3<Double> { m * v }
public func simd_mul(_ a: simd_double4x4, _ b: simd_double4x4) -> simd_double4x4 { a * b }
public func simd_mul(_ m: simd_double4x4, _ v: SIMD4<Double>) -> SIMD4<Double> { m * v }
public func simd_transpose(_ m: simd_double3x3) -> simd_double3x3 { m.transpose }
public func simd_transpose(_ m: simd_double4x4) -> simd_double4x4 { m.transpose }
public func simd_inverse(_ m: simd_double3x3) -> simd_double3x3 { m.inverse }
public func simd_inverse(_ m: simd_double4x4) -> simd_double4x4 { m.inverse }
public func simd_determinant(_ m: simd_double3x3) -> Double { m.determinant }
public func simd_determinant(_ m: simd_double4x4) -> Double { m.determinant }
public func simd_quaternion(_ angle: Double, _ axis: SIMD3<Double>) -> simd_quatd { simd_quatd(angle: angle, axis: axis) }
public func simd_quaternion(_ m: simd_double3x3) -> simd_quatd { simd_quatd(m) }
public func simd_quaternion(_ m: simd_double4x4) -> simd_quatd { simd_quatd(m) }
public func simd_quaternion(_ from: SIMD3<Double>, _ to: SIMD3<Double>) -> simd_quatd { simd_quatd(from: from, to: to) }
public func simd_length(_ q: simd_quatd) -> Double { simd_length(q.vector) }
public func simd_normalize(_ q: simd_quatd) -> simd_quatd { q.normalized }
public func simd_dot(_ a: simd_quatd, _ b: simd_quatd) -> Double { simd_dot(a.vector, b.vector) }
public func simd_conjugate(_ q: simd_quatd) -> simd_quatd { q.conjugate }
public func simd_inverse(_ q: simd_quatd) -> simd_quatd { q.inverse }
public func simd_mul(_ a: simd_quatd, _ b: simd_quatd) -> simd_quatd { a * b }
public func simd_angle(_ q: simd_quatd) -> Double { q.angle }
public func simd_axis(_ q: simd_quatd) -> SIMD3<Double> { q.axis }
public func simd_imag(_ q: simd_quatd) -> SIMD3<Double> { q.imag }
public func simd_real(_ q: simd_quatd) -> Double { q.real }
public func simd_act(_ q: simd_quatd, _ v: SIMD3<Double>) -> SIMD3<Double> { q.act(v) }
public func simd_matrix3x3(_ q: simd_quatd) -> simd_double3x3 { simd_double3x3(q) }
public func simd_matrix4x4(_ q: simd_quatd) -> simd_double4x4 { simd_double4x4(q) }
/// spherical interpolation between two rotations; `simd_slerp` takes the shorter arc, `simd_slerp_longest` the longer
public func simd_slerp(_ q0: simd_quatd, _ q1: simd_quatd, _ t: Double) -> simd_quatd { _simd_slerpd(q0, simd_dot(q0, q1) < 0 ? -q1 : q1, t) }
public func simd_slerp_longest(_ q0: simd_quatd, _ q1: simd_quatd, _ t: Double) -> simd_quatd { _simd_slerpd(q0, simd_dot(q0, q1) >= 0 ? -q1 : q1, t) }
func _simd_slerpd(_ a: simd_quatd, _ b: simd_quatd, _ t: Double) -> simd_quatd {
    let d = Swift.max(-1, Swift.min(1, simd_dot(a.vector, b.vector)))
    if d > 0.99995 { return simd_quatd(vector: simd_normalize(a.vector + (b.vector - a.vector) * t)) }
    let th = Darwin.acos(d), s = Darwin.sin(th)
    return simd_quatd(vector: a.vector * (Darwin.sin((1 - t) * th) / s) + b.vector * (Darwin.sin(t * th) / s))
}
/// the spline through four rotations (Shoemake's squad), between q1 and q2
public func simd_spline(_ q0: simd_quatd, _ q1: simd_quatd, _ q2: simd_quatd, _ q3: simd_quatd, _ t: Double) -> simd_quatd {
    func log(_ q: simd_quatd) -> simd_quatd {
        let l = simd_length(q.imag), a = Darwin.atan2(l, q.real)
        return simd_quatd(real: 0, imag: l > 0 ? q.imag / l * a : .zero)
    }
    func exp(_ q: simd_quatd) -> simd_quatd {
        let a = simd_length(q.imag)
        return simd_quatd(real: Darwin.cos(a), imag: a > 0 ? q.imag / a * Darwin.sin(a) : .zero)
    }
    func inner(_ p: simd_quatd, _ q: simd_quatd, _ n: simd_quatd) -> simd_quatd {
        let qi = q.inverse
        let s = (log(qi * n).vector + log(qi * p).vector) * -0.25
        return q * exp(simd_quatd(vector: s))
    }
    let a = inner(q0, q1, q2), b = inner(q1, q2, q3)
    return _simd_slerpd(_simd_slerpd(q1, q2, t), _simd_slerpd(a, b, t), 2 * t * (1 - t))
}
