// isim Spatial overlay: AffineTransform3D (a 4x3 matrix), ProjectiveTransform3D (4x4), Pose3D (position and rotation)
// and ScaledPose3D (plus a uniform scale). Matrices are column-major and act on column vectors, so `a * b` applies b
// first. Rotating, scaling, shearing, flipping or translating a transform applies that change after it (on the left).
// Perspective projections are right-handed (the camera looks down -z) with depth 0...1, or 1...0 when reverseZ.
import Darwin
@_exported import simd

extension simd_double4x4 {
    init(_affine m: simd_double4x3) {
        self.init(SIMD4(m.columns.0, 0), SIMD4(m.columns.1, 0), SIMD4(m.columns.2, 0), SIMD4(m.columns.3, 1))
    }
    var _upper: simd_double3x3 {
        simd_double3x3(SIMD3(columns.0.x, columns.0.y, columns.0.z), SIMD3(columns.1.x, columns.1.y, columns.1.z),
                       SIMD3(columns.2.x, columns.2.y, columns.2.z))
    }
    var _isAffine: Bool { columns.0.w == 0 && columns.1.w == 0 && columns.2.w == 0 && columns.3.w == 1 }
    var _truncated: simd_double4x3 {
        simd_double4x3(SIMD3(columns.0.x, columns.0.y, columns.0.z), SIMD3(columns.1.x, columns.1.y, columns.1.z),
                       SIMD3(columns.2.x, columns.2.y, columns.2.z), SIMD3(columns.3.x, columns.3.y, columns.3.z))
    }
    init(_float m: simd_float4x4) {
        self.init(SIMD4<Double>(m.columns.0), SIMD4<Double>(m.columns.1), SIMD4<Double>(m.columns.2), SIMD4<Double>(m.columns.3))
    }
    var _elements: [Double] {
        [columns.0, columns.1, columns.2, columns.3].flatMap { [$0.x, $0.y, $0.z, $0.w] }
    }
}

/// The scale (column lengths, the first negated for a reflection), the rotation and whether the 3x3 holds no shear.
private func _decompose(_ m: simd_double3x3) -> (scale: SIMD3<Double>, rotation: simd_quatd?) {
    var s = SIMD3(simd_length(m.columns.0), simd_length(m.columns.1), simd_length(m.columns.2))
    if m.determinant < 0 { s.x = -s.x }
    guard s.x != 0, s.y != 0, s.z != 0 else { return (s, nil) }
    let r = simd_double3x3(m.columns.0 / s.x, m.columns.1 / s.y, m.columns.2 / s.z)
    let rtr = r.transpose * r, eps = 1e-9
    for c in 0..<3 { for row in 0..<3 where abs(rtr[c, row] - (c == row ? 1 : 0)) > eps { return (s, nil) } }
    return (s, simd_quatd(r).normalized)
}

private func _uniform(_ s: SIMD3<Double>, _ dims: Dimension3DSet) -> Bool {
    var v: [Double] = []
    if dims.contains(.x) { v.append(s.x) }
    if dims.contains(.y) { v.append(s.y) }
    if dims.contains(.z) { v.append(s.z) }
    return v.allSatisfy { abs($0 - v[0]) <= 1e-12 * Swift.max(1, abs(v[0])) }
}

private func _abs(_ v: SIMD3<Double>) -> SIMD3<Double> { SIMD3(abs(v.x), abs(v.y), abs(v.z)) }

private func _flipScale(_ axis: Axis3D) -> SIMD3<Double> {
    SIMD3(axis == .x ? -1 : 1, axis == .y ? -1 : 1, axis == .z ? -1 : 1)
}

private func _close(_ a: [Double], _ b: [Double], _ tolerance: Double) -> Bool {
    zip(a, b).allSatisfy { abs($0 - $1) <= tolerance }
}

// MARK: - AffineTransform3D

/// An affine transform: a linear 3x3 part and a translation.
public struct AffineTransform3D: Hashable, Codable, Sendable, Rotatable3D, Scalable3D, Shearable3D, Translatable3D, CustomReflectable {
    public var matrix: simd_double4x3

    public init() { matrix = simd_double4x3(1) }
    public init(matrix: simd_double4x3) { self.matrix = matrix }
    public init(_ matrix: simd_double4x3) { self.matrix = matrix }
    public init(matrix: simd_float4x3) {
        self.matrix = simd_double4x3(SIMD3<Double>(matrix.columns.0), SIMD3<Double>(matrix.columns.1), SIMD3<Double>(matrix.columns.2),
                                     SIMD3<Double>(matrix.columns.3))
    }
    public init(_ matrix: simd_float4x3) { self.init(matrix: matrix) }
    /// nil when the matrix's last row is not (0, 0, 0, 1)
    public init?(matrix: simd_double4x4) {
        guard matrix._isAffine else { return nil }
        self.matrix = matrix._truncated
    }
    public init?(_ matrix: simd_double4x4) { self.init(matrix: matrix) }
    public init?(matrix: simd_float4x4) { self.init(matrix: simd_double4x4(_float: matrix)) }
    public init?(_ matrix: simd_float4x4) { self.init(matrix: matrix) }
    public init?(projectiveTransform: ProjectiveTransform3D) { self.init(matrix: projectiveTransform.matrix) }
    /// The upper 4x3 of the matrix, whatever its last row.
    public init(truncating m: simd_double4x4) { matrix = m._truncated }
    public init(truncating m: simd_float4x4) { matrix = simd_double4x4(_float: m)._truncated }
    public init(truncating t: ProjectiveTransform3D) { matrix = t.matrix._truncated }
    public init(pose: Pose3D) { matrix = pose.matrix._truncated }
    public init(scaledPose: ScaledPose3D) { matrix = scaledPose.matrix._truncated }
    public init(scale: Size3D = .one, rotation: Rotation3D = .identity, translation: Vector3D = .zero) {
        let r = simd_double3x3(rotation.quaternion.normalized), s = scale.vector
        matrix = simd_double4x3(r.columns.0 * s.x, r.columns.1 * s.y, r.columns.2 * s.z, translation.vector)
    }
    public init(scale: Size3D = .one, rotation: Rotation3D = .identity, translation: Size3D) {
        self.init(scale: scale, rotation: rotation, translation: Vector3D(translation))
    }
    public init(translation: Size3D) { self.init(translation: Vector3D(translation)) }
    public init(shear: AxisWithFactors) {
        let m = shear._matrix
        matrix = simd_double4x3(m.columns.0, m.columns.1, m.columns.2, .zero)
    }

    public static var identity: AffineTransform3D { AffineTransform3D() }
    public var isIdentity: Bool { self == .identity }
    public var matrix3x3: simd_double3x3 { simd_double3x3(matrix.columns.0, matrix.columns.1, matrix.columns.2) }
    public var matrix4x4: simd_double4x4 { simd_double4x4(_affine: matrix) }
    public var translation: Vector3D {
        get { Vector3D(vector: matrix.columns.3) }
        set { matrix.columns.3 = newValue.vector }
    }
    public var offset: Vector3D { translation }
    public var scale: Size3D { Size3D(vector: _decompose(matrix3x3).scale) }
    /// nil when the transform shears or has a zero scale
    public var rotation: Rotation3D? { _decompose(matrix3x3).rotation.map { Rotation3D(quaternion: $0) } }
    public var isInvertible: Bool { matrix3x3.determinant != 0 }
    public var inverse: AffineTransform3D? {
        guard isInvertible else { return nil }
        return AffineTransform3D(truncating: matrix4x4.inverse)
    }
    public func inverted() -> AffineTransform3D? { inverse }
    public func isUniform(overDimensions dims: Dimension3DSet) -> Bool { _uniform(_abs(_decompose(matrix3x3).scale), dims) }
    public func isApproximatelyEqual(to other: AffineTransform3D, tolerance: Double = Double.ulpOfOne.squareRoot()) -> Bool {
        _close(matrix4x4._elements, other.matrix4x4._elements, tolerance)
    }
    /// This transform, given in the basis `from`, expressed in the basis `to`.
    public func changeBasis(from: AffineTransform3D, to: AffineTransform3D) -> AffineTransform3D? {
        guard let fi = from.inverse, let ti = to.inverse else { return nil }
        return ti * from * self * fi * to
    }

    public func rotated(by r: Rotation3D) -> AffineTransform3D { AffineTransform3D(rotation: r) * self }
    public func scaled(by s: Size3D) -> AffineTransform3D { AffineTransform3D(scale: s) * self }
    public func scaledBy(x: Double, y: Double, z: Double) -> AffineTransform3D { scaled(by: Size3D(width: x, height: y, depth: z)) }
    public func sheared(_ shear: AxisWithFactors) -> AffineTransform3D { AffineTransform3D(shear: shear) * self }
    public func translated(by offset: Vector3D) -> AffineTransform3D { AffineTransform3D(translation: offset) * self }
    public func flipped(along axis: Axis3D) -> AffineTransform3D { scaled(by: Size3D(vector: _flipScale(axis))) }
    public mutating func flip(along axis: Axis3D) { self = flipped(along: axis) }

    public static func * (a: AffineTransform3D, b: AffineTransform3D) -> AffineTransform3D {
        AffineTransform3D(truncating: a.matrix4x4 * b.matrix4x4)
    }
    public static func *= (a: inout AffineTransform3D, b: AffineTransform3D) { a = a * b }
    public static func == (a: AffineTransform3D, b: AffineTransform3D) -> Bool { a.matrix == b.matrix }
    public func hash(into h: inout Hasher) { h.combine(matrix4x4._elements) }

    private enum CodingKeys: String, CodingKey { case matrix }
    public init(from decoder: any Decoder) throws {
        let e = try decoder.container(keyedBy: CodingKeys.self).decode([Double].self, forKey: .matrix)
        guard e.count == 12 else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "12 values")) }
        matrix = simd_double4x3(SIMD3(e[0], e[1], e[2]), SIMD3(e[3], e[4], e[5]), SIMD3(e[6], e[7], e[8]), SIMD3(e[9], e[10], e[11]))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let m = matrix.columns
        try c.encode([m.0, m.1, m.2, m.3].flatMap { [$0.x, $0.y, $0.z] }, forKey: .matrix)
    }
    public var customMirror: Mirror { Mirror(self, children: ["matrix": matrix]) }
}

extension AffineTransform3D {
    public init(translation: Vector3D) { self.init(scale: .one, rotation: .identity, translation: translation) }
}

// MARK: - ProjectiveTransform3D

/// A projective transform: any 4x4 matrix.
public struct ProjectiveTransform3D: Hashable, Codable, Sendable, Rotatable3D, Scalable3D, Shearable3D, Translatable3D, CustomReflectable {
    public var matrix: simd_double4x4

    public init() { matrix = simd_double4x4(1) }
    public init(matrix: simd_double4x4) { self.matrix = matrix }
    public init(_ matrix: simd_double4x4) { self.matrix = matrix }
    public init(matrix: simd_float4x4) { self.matrix = simd_double4x4(_float: matrix) }
    public init(_ matrix: simd_float4x4) { self.init(matrix: matrix) }
    public init(_ affine: AffineTransform3D) { matrix = affine.matrix4x4 }
    public init(pose: Pose3D) { matrix = pose.matrix }
    public init(scaledPose: ScaledPose3D) { matrix = scaledPose.matrix }
    public init(scale: Size3D = .one, rotation: Rotation3D = .identity, translation: Vector3D = .zero) {
        self.init(AffineTransform3D(scale: scale, rotation: rotation, translation: translation))
    }
    public init(scale: Size3D = .one, rotation: Rotation3D = .identity, translation: Size3D) {
        self.init(scale: scale, rotation: rotation, translation: Vector3D(translation))
    }
    public init(translation: Size3D) { self.init(translation: Vector3D(translation)) }
    public init(shear: AxisWithFactors) { self.init(AffineTransform3D(shear: shear)) }
    /// A right-handed perspective projection of the frustum with these tangents of its half-angles.
    public init(leftTangent: Double, rightTangent: Double, topTangent: Double, bottomTangent: Double, nearZ: Double, farZ: Double,
                reverseZ: Bool = false) {
        let xs = 2 / (leftTangent + rightTangent), ys = 2 / (topTangent + bottomTangent)
        let xo = (rightTangent - leftTangent) / (leftTangent + rightTangent), yo = (topTangent - bottomTangent) / (topTangent + bottomTangent)
        let zs: Double, zt: Double
        if farZ.isInfinite {
            zs = reverseZ ? 0 : -1; zt = reverseZ ? nearZ : -nearZ
        } else if reverseZ {
            zs = nearZ / (farZ - nearZ); zt = farZ * nearZ / (farZ - nearZ)
        } else {
            zs = farZ / (nearZ - farZ); zt = nearZ * farZ / (nearZ - farZ)
        }
        matrix = simd_double4x4(SIMD4(xs, 0, 0, 0), SIMD4(0, ys, 0, 0), SIMD4(xo, yo, zs, -1), SIMD4(0, 0, zt, 0))
    }
    public init(fovyRadians: Double, aspectRatio: Double, nearZ: Double, farZ: Double, reverseZ: Bool = false) {
        let t = Darwin.tan(fovyRadians / 2)
        self.init(leftTangent: t * aspectRatio, rightTangent: t * aspectRatio, topTangent: t, bottomTangent: t, nearZ: nearZ, farZ: farZ,
                  reverseZ: reverseZ)
    }
    public init(fovY: Angle2D, aspectRatio: Double, nearZ: Double, farZ: Double, reverseZ: Bool = false) {
        self.init(fovyRadians: fovY.radians, aspectRatio: aspectRatio, nearZ: nearZ, farZ: farZ, reverseZ: reverseZ)
    }

    public static var identity: ProjectiveTransform3D { ProjectiveTransform3D() }
    public var isIdentity: Bool { self == .identity }
    public var isAffine: Bool { matrix._isAffine }
    /// Whether the matrix projects (its last row is not (0, 0, 0, 1)).
    public func is3DProjection() -> Bool { !matrix._isAffine }
    public var translation: Vector3D {
        get { Vector3D(vector: SIMD3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)) }
        set { matrix.columns.3 = SIMD4(newValue.vector, matrix.columns.3.w) }
    }
    public var offset: Vector3D { translation }
    public var scaleComponent: Size3D { Size3D(vector: _decompose(matrix._upper).scale) }
    /// nil when the transform projects
    public var scale: Size3D? { isAffine ? scaleComponent : nil }
    /// nil when the transform projects, shears or has a zero scale
    public var rotation: Rotation3D? { isAffine ? _decompose(matrix._upper).rotation.map { Rotation3D(quaternion: $0) } : nil }
    public var isInvertible: Bool { matrix.determinant != 0 }
    public var inverse: ProjectiveTransform3D? { isInvertible ? ProjectiveTransform3D(matrix: matrix.inverse) : nil }
    public func inverted() -> ProjectiveTransform3D? { inverse }
    public func isUniform(overDimensions dims: Dimension3DSet) -> Bool { _uniform(_abs(scaleComponent.vector), dims) }
    public func isApproximatelyEqual(to other: ProjectiveTransform3D, tolerance: Double = Double.ulpOfOne.squareRoot()) -> Bool {
        _close(matrix._elements, other.matrix._elements, tolerance)
    }

    public func rotated(by r: Rotation3D) -> ProjectiveTransform3D { ProjectiveTransform3D(rotation: r) * self }
    public func scaled(by s: Size3D) -> ProjectiveTransform3D { ProjectiveTransform3D(scale: s) * self }
    public func scaledBy(x: Double, y: Double, z: Double) -> ProjectiveTransform3D { scaled(by: Size3D(width: x, height: y, depth: z)) }
    public func sheared(_ shear: AxisWithFactors) -> ProjectiveTransform3D { ProjectiveTransform3D(shear: shear) * self }
    public func translated(by offset: Vector3D) -> ProjectiveTransform3D { ProjectiveTransform3D(translation: offset) * self }
    public func flipped(along axis: Axis3D) -> ProjectiveTransform3D { scaled(by: Size3D(vector: _flipScale(axis))) }
    public mutating func flip(along axis: Axis3D) { self = flipped(along: axis) }

    public static func * (a: ProjectiveTransform3D, b: ProjectiveTransform3D) -> ProjectiveTransform3D {
        ProjectiveTransform3D(matrix: a.matrix * b.matrix)
    }
    public static func *= (a: inout ProjectiveTransform3D, b: ProjectiveTransform3D) { a = a * b }
    public static func == (a: ProjectiveTransform3D, b: ProjectiveTransform3D) -> Bool { a.matrix == b.matrix }
    public func hash(into h: inout Hasher) { h.combine(matrix._elements) }

    private enum CodingKeys: String, CodingKey { case matrix }
    public init(from decoder: any Decoder) throws {
        let e = try decoder.container(keyedBy: CodingKeys.self).decode([Double].self, forKey: .matrix)
        guard e.count == 16 else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "16 values")) }
        matrix = simd_double4x4(SIMD4(e[0], e[1], e[2], e[3]), SIMD4(e[4], e[5], e[6], e[7]), SIMD4(e[8], e[9], e[10], e[11]),
                                SIMD4(e[12], e[13], e[14], e[15]))
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(matrix._elements, forKey: .matrix)
    }
    public var customMirror: Mirror { Mirror(self, children: ["matrix": matrix]) }
}

extension ProjectiveTransform3D {
    public init(translation: Vector3D) { self.init(scale: .one, rotation: .identity, translation: translation) }
}

// MARK: - Pose3D

/// A position and an orientation: rotates, then translates.
public struct Pose3D: Hashable, Codable, Sendable, Rotatable3D, Translatable3D, CustomReflectable {
    public var position: Point3D
    public var rotation: Rotation3D

    public init() { position = .zero; rotation = .identity }
    public init(position: Point3D, rotation: Rotation3D) { self.position = position; self.rotation = rotation }
    public init(position: simd_double3, rotation: simd_quatd) { self.init(position: Point3D(position), rotation: Rotation3D(quaternion: rotation)) }
    public init(position: simd_float3, rotation: simd_quatf) { self.init(position: Point3D(position), rotation: Rotation3D(quaternion: rotation)) }
    /// At the origin, looking along `forward`.
    public init(forward: Vector3D, up: Vector3D = .up) { self.init(position: .zero, rotation: Rotation3D(forward: forward, up: up)) }
    /// At `position`, looking at `target`.
    public init(position: Point3D, target: Point3D, up: Vector3D = .up) {
        self.init(position: position, rotation: Rotation3D(position: position, target: target, up: up))
    }
    /// nil when the transform scales or shears
    public init?(transform: AffineTransform3D) {
        guard let r = transform.rotation, simd_length(transform.scale.vector - SIMD3(1, 1, 1)) < 1e-9 else { return nil }
        self.init(position: Point3D(transform.translation), rotation: r)
    }
    public init?(transform: ProjectiveTransform3D) {
        guard let a = AffineTransform3D(projectiveTransform: transform) else { return nil }
        self.init(transform: a)
    }
    public init?(matrix: simd_double4x4) { self.init(transform: ProjectiveTransform3D(matrix: matrix)) }
    public init?(_ matrix: simd_double4x4) { self.init(matrix: matrix) }
    public init?(matrix: simd_float4x4) { self.init(matrix: simd_double4x4(_float: matrix)) }
    public init?(_ matrix: simd_float4x4) { self.init(matrix: matrix) }

    public static var identity: Pose3D { Pose3D() }
    public var isIdentity: Bool { position.isZero && rotation.isIdentity }
    public var matrix: simd_double4x4 { AffineTransform3D(rotation: rotation, translation: Vector3D(position)).matrix4x4 }
    public var inverse: Pose3D {
        let r = rotation.inverse
        return Pose3D(position: Point3D(vector: -r.quaternion.act(position.vector)), rotation: r)
    }
    /// The pose that applies `other` first, then this one.
    public func concatenating(_ other: Pose3D) -> Pose3D { self * other }
    public func concatenating(_ other: ScaledPose3D) -> ScaledPose3D { ScaledPose3D(self) * other }
    public func isApproximatelyEqual(to other: Pose3D, tolerance: Double = Double.ulpOfOne.squareRoot()) -> Bool {
        _close([position.x, position.y, position.z], [other.position.x, other.position.y, other.position.z], tolerance)
            && rotation.isApproximatelyEqual(to: other.rotation, tolerance: tolerance)
    }
    public func rotated(by r: Rotation3D) -> Pose3D { Pose3D(position: position.rotated(by: r), rotation: r * rotation) }
    public func translated(by offset: Vector3D) -> Pose3D { Pose3D(position: position.translated(by: offset), rotation: rotation) }
    /// Mirrored through the plane across `axis`: the position flips and the rotation turns the mirrored way.
    public func flipped(along axis: Axis3D) -> Pose3D {
        let f = _flipScale(axis), q = rotation.quaternion
        // reflecting conjugates the rotation: the imaginary part flips like a pseudovector
        let imag = -f * q.imag
        return Pose3D(position: Point3D(vector: position.vector * f), rotation: Rotation3D(quaternion: simd_quatd(real: q.real, imag: imag)))
    }
    public mutating func flip(along axis: Axis3D) { self = flipped(along: axis) }

    public static func * (a: Pose3D, b: Pose3D) -> Pose3D {
        Pose3D(position: Point3D(vector: a.rotation.quaternion.act(b.position.vector) + a.position.vector), rotation: a.rotation * b.rotation)
    }
    public static func *= (a: inout Pose3D, b: Pose3D) { a = a * b }
    public var customMirror: Mirror { Mirror(self, children: ["position": position, "rotation": rotation]) }
}

// MARK: - ScaledPose3D

/// A position, an orientation and a uniform scale: scales, rotates, then translates.
public struct ScaledPose3D: Hashable, Codable, Sendable, Rotatable3D, Translatable3D, CustomReflectable {
    public var position: Point3D
    public var rotation: Rotation3D
    public var scale: Double

    public init() { position = .zero; rotation = .identity; scale = 1 }
    public init(position: Point3D, rotation: Rotation3D, scale: Double) {
        self.position = position; self.rotation = rotation; self.scale = scale
    }
    public init(position: simd_double3, rotation: simd_quatd, scale: Double) {
        self.init(position: Point3D(position), rotation: Rotation3D(quaternion: rotation), scale: scale)
    }
    public init(position: simd_float3, rotation: simd_quatf, scale: Float) {
        self.init(position: Point3D(position), rotation: Rotation3D(quaternion: rotation), scale: Double(scale))
    }
    public init(forward: Vector3D, scale: Double = 1, up: Vector3D = .up) {
        self.init(position: .zero, rotation: Rotation3D(forward: forward, up: up), scale: scale)
    }
    public init(position: Point3D, target: Point3D, scale: Double = 1, up: Vector3D = .up) {
        self.init(position: position, rotation: Rotation3D(position: position, target: target, up: up), scale: scale)
    }
    init(_ pose: Pose3D) { self.init(position: pose.position, rotation: pose.rotation, scale: 1) }
    /// nil when the transform's scale is not uniform and positive, or it shears
    public init?(transform: AffineTransform3D) {
        let s = transform.scale.vector
        guard let r = transform.rotation, s.x > 0, transform.isUniform(overDimensions: .all) else { return nil }
        self.init(position: Point3D(transform.translation), rotation: r, scale: s.x)
    }
    public init?(transform: ProjectiveTransform3D) {
        guard let a = AffineTransform3D(projectiveTransform: transform) else { return nil }
        self.init(transform: a)
    }
    public init?(_ matrix: simd_double4x4) { self.init(transform: ProjectiveTransform3D(matrix: matrix)) }
    public init?(_ matrix: simd_float4x4) { self.init(simd_double4x4(_float: matrix)) }

    public static var identity: ScaledPose3D { ScaledPose3D() }
    public var isIdentity: Bool { position.isZero && rotation.isIdentity && scale == 1 }
    public var matrix: simd_double4x4 {
        AffineTransform3D(scale: Size3D(width: scale, height: scale, depth: scale), rotation: rotation, translation: Vector3D(position)).matrix4x4
    }
    public var inverse: ScaledPose3D {
        let r = rotation.inverse, s = scale == 0 ? 0 : 1 / scale
        return ScaledPose3D(position: Point3D(vector: -r.quaternion.act(position.vector) * s), rotation: r, scale: s)
    }
    public func concatenating(_ other: Pose3D) -> ScaledPose3D { self * other }
    public func concatenating(_ other: ScaledPose3D) -> ScaledPose3D { self * other }
    public func isApproximatelyEqual(to other: ScaledPose3D, tolerance: Double = Double.ulpOfOne.squareRoot()) -> Bool {
        _close([position.x, position.y, position.z, scale], [other.position.x, other.position.y, other.position.z, other.scale], tolerance)
            && rotation.isApproximatelyEqual(to: other.rotation, tolerance: tolerance)
    }
    public func rotated(by r: Rotation3D) -> ScaledPose3D { ScaledPose3D(position: position.rotated(by: r), rotation: r * rotation, scale: scale) }
    public func translated(by offset: Vector3D) -> ScaledPose3D {
        ScaledPose3D(position: position.translated(by: offset), rotation: rotation, scale: scale)
    }
    public func flipped(along axis: Axis3D) -> ScaledPose3D {
        let p = Pose3D(position: position, rotation: rotation).flipped(along: axis)
        return ScaledPose3D(position: p.position, rotation: p.rotation, scale: scale)
    }
    public mutating func flip(along axis: Axis3D) { self = flipped(along: axis) }

    public static func * (a: ScaledPose3D, b: ScaledPose3D) -> ScaledPose3D {
        ScaledPose3D(position: Point3D(vector: a.rotation.quaternion.act(b.position.vector * a.scale) + a.position.vector),
                     rotation: a.rotation * b.rotation, scale: a.scale * b.scale)
    }
    public static func * (a: ScaledPose3D, b: Pose3D) -> ScaledPose3D { a * ScaledPose3D(b) }
    public static func * (a: Pose3D, b: ScaledPose3D) -> ScaledPose3D { ScaledPose3D(a) * b }
    public static func *= (a: inout ScaledPose3D, b: ScaledPose3D) { a = a * b }
    public var customMirror: Mirror { Mirror(self, children: ["position": position, "rotation": rotation, "scale": scale]) }
}
