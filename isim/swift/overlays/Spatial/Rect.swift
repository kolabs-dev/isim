// isim Spatial overlay: Rect3D (an axis-aligned box) and Ray3D. A box that is rotated, sheared or put through a
// transform becomes the axis-aligned box around its transformed corners.
import Darwin
@_exported import simd

/// An axis-aligned box: an origin and a size (which may be negative until standardized).
public struct Rect3D: Hashable, Codable, Sendable, Primitive3D, Rotatable3D, Scalable3D, Shearable3D, Translatable3D, Volumetric,
    CustomReflectable {
    public var origin: Point3D
    public var size: Size3D

    public init() { origin = .zero; size = .zero }
    public init(origin: Point3D, size: Size3D) { self.origin = origin; self.size = size }
    public init(origin: Vector3D, size: Vector3D) { self.init(origin: Point3D(origin), size: Size3D(size)) }
    public init(origin: simd_double3, size: simd_double3) { self.init(origin: Point3D(origin), size: Size3D(size)) }
    public init(origin: simd_float3, size: simd_float3) { self.init(origin: Point3D(origin), size: Size3D(size)) }
    public init(center: Point3D, size: Size3D) { self.init(origin: Point3D(vector: center.vector - size.vector / 2), size: size) }
    public init(center: Vector3D, size: Vector3D) { self.init(center: Point3D(center), size: Size3D(size)) }
    public init(center: simd_double3, size: simd_double3) { self.init(center: Point3D(center), size: Size3D(size)) }
    public init(center: simd_float3, size: simd_float3) { self.init(center: Point3D(center), size: Size3D(size)) }
    /// The smallest box holding every point.
    public init(points: [Point3D]) {
        guard let first = points.first?.vector else { self.init(); return }
        var lo = first, hi = first
        for p in points.dropFirst() { lo = pointwiseMin(lo, p.vector); hi = pointwiseMax(hi, p.vector) }
        self.init(origin: Point3D(vector: lo), size: Size3D(vector: hi - lo))
    }

    public static var zero: Rect3D { Rect3D() }
    public static var infinity: Rect3D {
        let big = Double.greatestFiniteMagnitude
        return Rect3D(origin: Point3D(x: -big / 2, y: -big / 2, z: -big / 2), size: Size3D(width: big, height: big, depth: big))
    }

    public var standardized: Rect3D { Rect3D(origin: min, size: Size3D(vector: max.vector - min.vector)) }
    public var min: Point3D { Point3D(vector: pointwiseMin(origin.vector, origin.vector + size.vector)) }
    public var max: Point3D { Point3D(vector: pointwiseMax(origin.vector, origin.vector + size.vector)) }
    public var center: Point3D { Point3D(vector: origin.vector + size.vector / 2) }
    public var minX: Double { min.x }
    public var minY: Double { min.y }
    public var minZ: Double { min.z }
    public var maxX: Double { max.x }
    public var maxY: Double { max.y }
    public var maxZ: Double { max.z }
    public var midX: Double { center.x }
    public var midY: Double { center.y }
    public var midZ: Double { center.z }
    /// The smallest box with integral corners holding this one.
    public var integral: Rect3D {
        let lo = min.vector.rounded(.down), hi = max.vector.rounded(.up)
        return Rect3D(origin: Point3D(vector: lo), size: Size3D(vector: hi - lo))
    }
    /// The eight corners: min first, x fastest, then y, then z.
    public var cornerPoints: [Point3D] {
        let lo = min.vector, hi = max.vector
        var out: [Point3D] = []
        for z in [lo.z, hi.z] { for y in [lo.y, hi.y] { for x in [lo.x, hi.x] { out.append(Point3D(x: x, y: y, z: z)) } } }
        return out
    }
    public var isEmpty: Bool { size.width == 0 || size.height == 0 || size.depth == 0 }
    public var isFinite: Bool { origin.isFinite && size.isFinite }
    public var isNaN: Bool { origin.isNaN || size.isNaN }
    public var isZero: Bool { origin.isZero && size.isZero }

    // Volumetric
    public func contains(point: Point3D) -> Bool {
        let lo = min.vector, hi = max.vector, p = point.vector
        return all(p .>= lo) && all(p .<= hi)
    }
    public func contains(_ other: Rect3D) -> Bool { contains(point: other.min) && contains(point: other.max) }
    public func union(_ other: Rect3D) -> Rect3D { Rect3D(points: [min, max, other.min, other.max]) }
    public func intersection(_ other: Rect3D) -> Rect3D? {
        let lo = pointwiseMax(min.vector, other.min.vector), hi = pointwiseMin(max.vector, other.max.vector)
        guard all(lo .<= hi) else { return nil }
        return Rect3D(origin: Point3D(vector: lo), size: Size3D(vector: hi - lo))
    }
    public func intersects(_ other: Rect3D) -> Bool { intersection(other) != nil }
    /// The gap between the boxes (0 when they touch or overlap).
    public func distance(to other: Rect3D) -> Double {
        let gap = pointwiseMax(pointwiseMax(other.min.vector - max.vector, min.vector - other.max.vector), .zero)
        return simd_length(gap)
    }
    public func inset(by size: Size3D) -> Rect3D {
        let s = standardized
        return Rect3D(origin: Point3D(vector: s.origin.vector + size.vector), size: Size3D(vector: s.size.vector - 2 * size.vector))
    }
    public mutating func formInset(by size: Size3D) { self = inset(by: size) }

    // transforms
    private func _around(_ f: (SIMD3<Double>) -> SIMD3<Double>) -> Rect3D {
        Rect3D(points: cornerPoints.map { Point3D(vector: f($0.vector)) })
    }
    public func applying(_ t: AffineTransform3D) -> Rect3D { _around { $0._affine(t, point: true) } }
    public func applying(_ t: ProjectiveTransform3D) -> Rect3D { _around { $0._projective(t, point: true) } }
    public func applying(_ p: Pose3D) -> Rect3D { _around { Point3D(vector: $0).applying(p).vector } }
    public func applying(_ p: ScaledPose3D) -> Rect3D { _around { Point3D(vector: $0).applying(p).vector } }
    public func unapplying(_ p: ScaledPose3D) -> Rect3D { _around { Point3D(vector: $0).unapplying(p).vector } }
    public func rotated(by r: Rotation3D) -> Rect3D { _around { r.quaternion.act($0) } }
    public func rotated(by r: Rotation3D, around pivot: Point3D) -> Rect3D { _around { r.quaternion.act($0 - pivot.vector) + pivot.vector } }
    public func rotated(by q: simd_quatd, around pivot: Point3D) -> Rect3D { rotated(by: Rotation3D(quaternion: q), around: pivot) }
    /// The rotation that turns the direction of this box's center to that of `other`'s.
    public func rotation(to other: Rect3D) -> Rotation3D { center.rotation(to: other.center) }
    public func scaled(by s: Size3D) -> Rect3D { Rect3D(origin: Point3D(vector: origin.vector * s.vector), size: Size3D(vector: size.vector * s.vector)) }
    public func scaledBy(x: Double, y: Double, z: Double) -> Rect3D { scaled(by: Size3D(width: x, height: y, depth: z)) }
    public func sheared(_ shear: AxisWithFactors) -> Rect3D { let m = shear._matrix; return _around { m * $0 } }
    public func translated(by offset: Vector3D) -> Rect3D { Rect3D(origin: Point3D(vector: origin.vector + offset.vector), size: size) }

    public static func * (t: AffineTransform3D, r: Rect3D) -> Rect3D { r.applying(t) }
    public static func * (t: ProjectiveTransform3D, r: Rect3D) -> Rect3D { r.applying(t) }
    public static func * (t: Pose3D, r: Rect3D) -> Rect3D { r.applying(t) }

    public var customMirror: Mirror { Mirror(self, children: ["origin": origin, "size": size]) }
}

/// A ray: an origin and a unit direction.
public struct Ray3D: Hashable, Codable, Sendable, Primitive3D, Rotatable3D, Translatable3D, CustomReflectable {
    public var origin: Point3D
    public var direction: Vector3D

    public init() { origin = .zero; direction = Vector3D(x: 0, y: 0, z: 1) }
    /// A ray from `origin` along `direction` (normalized).
    public init(origin: Point3D, direction: Vector3D) {
        self.origin = origin
        let l = simd_length(direction.vector)
        self.direction = l > 0 ? Vector3D(vector: direction.vector / l) : direction
    }
    public init(origin: simd_double3, direction: simd_double3) { self.init(origin: Point3D(origin), direction: Vector3D(direction)) }
    public init(origin: simd_float3, direction: simd_float3) { self.init(origin: Point3D(origin), direction: Vector3D(direction)) }

    public static var zero: Ray3D { Ray3D(origin: .zero, direction: .zero) }
    public static var infinity: Ray3D { Ray3D(origin: .infinity, direction: .infinity) }
    public var isFinite: Bool { origin.isFinite && direction.isFinite }
    public var isNaN: Bool { origin.isNaN || direction.isNaN }
    public var isZero: Bool { origin.isZero && direction.isZero }

    /// Whether the ray passes through the box (slab test, ahead of the origin only).
    public func intersects(_ rect: Rect3D) -> Bool {
        let o = origin.vector, d = direction.vector, lo = rect.min.vector, hi = rect.max.vector
        var t0 = 0.0, t1 = Double.infinity
        for i in 0..<3 {
            if d[i] == 0 {
                if o[i] < lo[i] || o[i] > hi[i] { return false }
                continue
            }
            var a = (lo[i] - o[i]) / d[i], b = (hi[i] - o[i]) / d[i]
            if a > b { swap(&a, &b) }
            t0 = Swift.max(t0, a); t1 = Swift.min(t1, b)
            if t0 > t1 { return false }
        }
        return true
    }
    /// Whether the ray passes through the sphere (ahead of the origin only).
    public func intersects(sphereOrigin: Point3D, sphereRadius: Double) -> Bool {
        let d = direction.vector, l = simd_length(d)
        let oc = sphereOrigin.vector - origin.vector
        guard l > 0 else { return simd_length(oc) <= sphereRadius }
        let t = Swift.max(0, simd_dot(oc, d / l))
        return simd_length(oc - t * d / l) <= sphereRadius
    }

    public func applying(_ t: AffineTransform3D) -> Ray3D { Ray3D(origin: origin.applying(t), direction: direction.applying(t)) }
    public func applying(_ t: ProjectiveTransform3D) -> Ray3D {
        let a = origin.applying(t), b = Point3D(vector: origin.vector + direction.vector).applying(t)
        return Ray3D(origin: a, direction: Vector3D(vector: b.vector - a.vector))
    }
    public func applying(_ p: Pose3D) -> Ray3D { Ray3D(origin: origin.applying(p), direction: direction.applying(p)) }
    public func applying(_ p: ScaledPose3D) -> Ray3D { Ray3D(origin: origin.applying(p), direction: direction.applying(p)) }
    public func unapplying(_ p: ScaledPose3D) -> Ray3D { Ray3D(origin: origin.unapplying(p), direction: direction.unapplying(p)) }
    public func rotated(by r: Rotation3D) -> Ray3D { Ray3D(origin: origin.rotated(by: r), direction: direction.rotated(by: r)) }
    public func rotated(by r: Rotation3D, around pivot: Point3D) -> Ray3D {
        Ray3D(origin: origin.rotated(by: r, around: pivot), direction: direction.rotated(by: r))
    }
    public func rotated(by q: simd_quatd, around pivot: Point3D) -> Ray3D { rotated(by: Rotation3D(quaternion: q), around: pivot) }
    public func translated(by offset: Vector3D) -> Ray3D { Ray3D(origin: origin.translated(by: offset), direction: direction) }

    public static func * (p: Pose3D, r: Ray3D) -> Ray3D { r.applying(p) }

    public var customMirror: Mirror { Mirror(self, children: ["origin": origin, "direction": direction]) }
}
