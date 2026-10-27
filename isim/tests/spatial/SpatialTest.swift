// Spatial from Swift (SpatialTest.app, issue #370): points, vectors, sizes, rotations (quaternions, Euler angles,
// slerp, swing-twist), boxes, rays, affine and projective transforms, poses and scaled poses, and the double-precision
// simd matrices and quaternions under them.
import Foundation
import Spatial

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func near(_ a: Double, _ b: Double, _ tol: Double = 1e-9) -> Bool { abs(a - b) <= tol }
func near(_ a: Point3D, _ b: Point3D, _ tol: Double = 1e-9) -> Bool {
    let ok = a.isApproximatelyEqual(to: b, tolerance: tol)
    if !ok { print("      \(a.vector) != \(b.vector)") }
    return ok
}
func near(_ a: Vector3D, _ b: Vector3D, _ tol: Double = 1e-9) -> Bool { near(Point3D(a), Point3D(b), tol) }

@main enum SpatialTest {
    static func main() {
        // simd doubles
        let m = simd_double3x3(SIMD3(2, 0, 0), SIMD3(0, 3, 0), SIMD3(1, 0, 4))
        check(near(m.determinant, 24) && near(simd_determinant(m), 24), "simd_double3x3 determinant")
        let mi = m * m.inverse
        check(near(mi[0, 0], 1) && near(mi[2, 0], 0) && near(mi[2, 2], 1), "simd_double3x3 inverse")
        let m4 = simd_double4x4(SIMD4(1, 0, 0, 0), SIMD4(0, 2, 0, 0), SIMD4(0, 0, 4, 0), SIMD4(5, 6, 7, 1))
        let m4i = m4 * simd_inverse(m4)
        check(near(m4.determinant, 8) && near(m4i[3, 0], 0) && near(m4i[1, 1], 1) && near(m4i[3, 3], 1), "simd_double4x4 determinant, inverse")
        let q = simd_quatd(angle: .pi / 2, axis: SIMD3(0, 0, 1))
        let qv = q.act(SIMD3(1, 0, 0))
        check(near(qv.x, 0) && near(qv.y, 1) && near(q.angle, .pi / 2), "simd_quatd act, angle")
        let qh = simd_slerp(simd_quatd(angle: 0, axis: SIMD3(0, 0, 1)), q, 0.5)
        check(near(qh.angle, .pi / 4), "simd_slerp")
        let qm = simd_quatd(simd_double3x3(q))
        check(near(abs(simd_dot(qm, q)), 1), "simd_quatd from a matrix")

        // Angle2D
        check(near(Angle2D(degrees: 180).radians, .pi) && near(Angle2D.atan2(y: 1, x: 1).degrees, 45) && near(sin(Angle2D(degrees: 30)), 0.5),
              "Angle2D degrees, atan2, sin")
        check(near(Angle2D(degrees: 270).normalized.degrees, -90), "Angle2D normalized")

        // points, vectors, sizes
        let p = Point3D(x: 1, y: 2, z: 3), v = Vector3D(x: 0, y: 3, z: 4)
        check(v.length == 5 && near(v.normalized.length, 1) && p.distance(to: Point3D(x: 1, y: 5, z: 7)) == 5, "length, normalized, distance")
        check(Vector3D(x: 1, y: 0, z: 0).cross(Vector3D(x: 0, y: 1, z: 0)) == Vector3D(x: 0, y: 0, z: 1) && v.dot(Vector3D(x: 1, y: 1, z: 1)) == 7,
              "cross, dot")
        check(p + v == Point3D(x: 1, y: 5, z: 7) && Point3D(x: 1, y: 5, z: 7) - p == v, "point and vector arithmetic")
        check(p.translated(by: v) == Point3D(x: 1, y: 5, z: 7) && p.scaled(by: Size3D(width: 2, height: 2, depth: 2)) == Point3D(x: 2, y: 4, z: 6),
              "translated, scaled")
        check(p.sheared(.xAxis(yShearFactor: 1, zShearFactor: 0)) == Point3D(x: 1, y: 3, z: 3), "sheared")
        let s = SphericalCoordinates3D(x: 0, y: 0, z: 2)
        check(near(s.radius, 2) && near(s.inclination.radians, 0) && near(Point3D(s), Point3D(x: 0, y: 0, z: 2)), "SphericalCoordinates3D")

        // Rotation3D
        let r90z = Rotation3D(angle: .degrees(90), axis: .z)
        check(near(Point3D(x: 1, y: 0, z: 0).rotated(by: r90z), Point3D(x: 0, y: 1, z: 0)), "Rotation3D rotates a point")
        check(near(r90z.angle.degrees, 90) && near(r90z.axis.z, 1), "Rotation3D angle, axis")
        var r = r90z
        r.angle = .degrees(45)
        check(near(r.quaternion.angle, .pi / 4), "Rotation3D angle setter")
        check((r90z * r90z.inverse).isApproximatelyEqual(to: .identity, tolerance: 1e-12), "Rotation3D inverse")
        let r180 = r90z * r90z
        check(near(Point3D(x: 1, y: 0, z: 0).rotated(by: r180), Point3D(x: -1, y: 0, z: 0)) && near((r90z * 2).angle.degrees, 180),
              "Rotation3D composition, scaling")
        let e = EulerAngles(x: .degrees(10), y: .degrees(20), z: .degrees(30), order: .xyz)
        let re = Rotation3D(eulerAngles: e).eulerAngles(order: .xyz)
        check(near(re.angles.x, e.angles.x) && near(re.angles.y, e.angles.y) && near(re.angles.z, e.angles.z), "Euler angles round trip (xyz)")
        let ez = EulerAngles(angles: SIMD3(0.3, -0.5, 1.1), order: .zxy)
        let rz = Rotation3D(eulerAngles: ez).eulerAngles(order: .zxy)
        check(near(rz.angles.x, 0.3) && near(rz.angles.y, -0.5) && near(rz.angles.z, 1.1), "Euler angles round trip (zxy)")
        let half = Rotation3D.slerp(from: .identity, to: r90z, t: 0.5)
        check(near(half.angle.degrees, 45), "slerp")
        let longest = Rotation3D.slerp(from: .identity, to: r90z, t: 0.5, along: .longest)
        check(near(abs(longest.angle.degrees), 135), "slerp along the longest path")
        let twisted = Rotation3D(angle: .degrees(40), axis: .y) * Rotation3D(angle: .degrees(30), axis: .z)
        let (swing, twist) = twisted.swingTwist(twistAxis: .z)
        check(near(twist.angle.degrees, 30, 1e-6) && (swing * twist).isApproximatelyEqual(to: twisted, tolerance: 1e-12), "swing-twist")
        let look = Rotation3D(forward: Vector3D(x: 1, y: 0, z: 0))
        check(near(Vector3D.forward.rotated(by: look), Vector3D(x: 1, y: 0, z: 0)) && near(Vector3D.up.rotated(by: look), .up), "Rotation3D(forward:)")
        let target = Rotation3D(position: .zero, target: Point3D(x: 0, y: 5, z: 5))
        check(near(Vector3D.forward.rotated(by: target), Vector3D(x: 0, y: 1, z: 1).normalized), "Rotation3D(position:target:)")
        check(near(Vector3D(x: 1, y: 0, z: 0).rotation(to: Vector3D(x: 0, y: 1, z: 0)).angle.degrees, 90), "Vector3D.rotation(to:)")
        let data = try! JSONEncoder().encode(r90z)
        check(try! JSONDecoder().decode(Rotation3D.self, from: data) == r90z, "Rotation3D Codable")

        // Rect3D
        let box = Rect3D(origin: Point3D(x: 0, y: 0, z: 0), size: Size3D(width: 2, height: 4, depth: 6))
        check(box.center == Point3D(x: 1, y: 2, z: 3) && box.max == Point3D(x: 2, y: 4, z: 6) && box.cornerPoints.count == 8, "Rect3D center, max, corners")
        check(box.contains(point: Point3D(x: 1, y: 1, z: 1)) && !box.contains(point: Point3D(x: 3, y: 1, z: 1)), "Rect3D contains(point:)")
        let other = Rect3D(center: Point3D(x: 2, y: 4, z: 6), size: Size3D(width: 2, height: 2, depth: 2))
        check(box.intersection(other) == Rect3D(origin: Point3D(x: 1, y: 3, z: 5), size: Size3D(width: 1, height: 1, depth: 1)), "Rect3D intersection")
        check(box.union(other).max == Point3D(x: 3, y: 5, z: 7) && box.intersects(other), "Rect3D union, intersects")
        let far = Rect3D(origin: Point3D(x: 5, y: 0, z: 0), size: Size3D(width: 1, height: 1, depth: 1))
        check(box.distance(to: far) == 3 && box.intersection(far) == nil, "Rect3D distance")
        let negative = Rect3D(origin: Point3D(x: 2, y: 2, z: 2), size: Size3D(width: -2, height: -2, depth: -2))
        check(negative.standardized == Rect3D(origin: .zero, size: Size3D(width: 2, height: 2, depth: 2)), "Rect3D standardized")
        let spun = Rect3D(center: .zero, size: Size3D(width: 2, height: 2, depth: 2)).rotated(by: Rotation3D(angle: .degrees(45), axis: .z))
        check(near(spun.size.width, 2 * 2.0.squareRoot()) && near(spun.size.depth, 2), "Rect3D rotated (bounding box)")
        check(Rect3D(points: [Point3D(x: 1, y: -1, z: 0), Point3D(x: -2, y: 3, z: 4)]).min == Point3D(x: -2, y: -1, z: 0), "Rect3D(points:)")
        check(box.inset(by: Size3D(width: 0.5, height: 1, depth: 1)).size == Size3D(width: 1, height: 2, depth: 4), "Rect3D inset")

        // Ray3D
        let ray = Ray3D(origin: Point3D(x: -5, y: 1, z: 1), direction: Vector3D(x: 2, y: 0, z: 0))
        check(ray.direction == Vector3D(x: 1, y: 0, z: 0) && ray.intersects(box), "Ray3D normalizes, hits a box")
        check(!Ray3D(origin: Point3D(x: -5, y: 1, z: 1), direction: Vector3D(x: -1, y: 0, z: 0)).intersects(box), "Ray3D misses behind its origin")
        check(ray.intersects(sphereOrigin: Point3D(x: 0, y: 2, z: 1), sphereRadius: 1.5)
              && !ray.intersects(sphereOrigin: Point3D(x: 0, y: 4, z: 1), sphereRadius: 1), "Ray3D sphere intersection")

        // AffineTransform3D
        let t = AffineTransform3D(scale: Size3D(width: 2, height: 2, depth: 2), rotation: r90z, translation: Vector3D(x: 10, y: 0, z: 0))
        check(near(Point3D(x: 1, y: 0, z: 0).applying(t), Point3D(x: 10, y: 2, z: 0)), "AffineTransform3D applies scale, rotation, translation")
        check(near(Vector3D(x: 1, y: 0, z: 0).applying(t), Vector3D(x: 0, y: 2, z: 0)), "vectors skip the translation")
        check(near(t.scale.width, 2) && t.rotation!.isApproximatelyEqual(to: r90z, tolerance: 1e-12) && t.translation == Vector3D(x: 10, y: 0, z: 0),
              "AffineTransform3D decomposes")
        check(near(Point3D(x: 10, y: 2, z: 0).applying(t.inverse!), Point3D(x: 1, y: 0, z: 0)), "AffineTransform3D inverse")
        check(near(Point3D(x: 10, y: 2, z: 0).unapplying(t), Point3D(x: 1, y: 0, z: 0)), "unapplying")
        check(AffineTransform3D(shear: .xAxis(yShearFactor: 1, zShearFactor: 0)).rotation == nil, "a shear has no rotation")
        check(!AffineTransform3D(scale: Size3D(width: 1, height: 0, depth: 1)).isInvertible
              && AffineTransform3D(scale: Size3D(width: 1, height: 0, depth: 1)).inverse == nil, "a flat transform is not invertible")
        let moved = AffineTransform3D().translated(by: Vector3D(x: 1, y: 2, z: 3)).scaledBy(x: 2, y: 2, z: 2)
        check(near(Point3D.zero.applying(moved), Point3D(x: 2, y: 4, z: 6)), "transform builders apply after the transform")
        check(AffineTransform3D(matrix: simd_double4x4(1)) != nil && AffineTransform3D(matrix: simd_double4x4(diagonal: SIMD4(1, 1, 1, 2))) == nil,
              "init?(matrix:) needs an affine matrix")
        check(AffineTransform3D(scale: Size3D(width: 3, height: 3, depth: 3)).isUniform(overDimensions: .all)
              && !AffineTransform3D(scale: Size3D(width: 3, height: 1, depth: 3)).isUniform(overDimensions: .all), "isUniform")
        let flipped = AffineTransform3D().flipped(along: .x)
        check(Point3D(x: 1, y: 2, z: 3).applying(flipped) == Point3D(x: -1, y: 2, z: 3) && near(flipped.scale.width, -1), "flipped(along:)")
        check(near(Rect3D(origin: .zero, size: Size3D(width: 1, height: 1, depth: 1)).applying(t).min, Point3D(x: 8, y: 0, z: 0)), "Rect3D through a transform")
        check(try! JSONDecoder().decode(AffineTransform3D.self, from: JSONEncoder().encode(t)) == t, "AffineTransform3D Codable")

        // ProjectiveTransform3D
        let proj = ProjectiveTransform3D(fovY: .degrees(90), aspectRatio: 1, nearZ: 1, farZ: 100)
        check(near(Point3D(x: 0, y: 0, z: -1).applying(proj).z, 0) && near(Point3D(x: 0, y: 0, z: -100).applying(proj).z, 1, 1e-9), "perspective depth 0...1")
        check(near(Point3D(x: 2, y: 0, z: -2).applying(proj).x, 1), "perspective divides by w")
        let rev = ProjectiveTransform3D(fovyRadians: .pi / 2, aspectRatio: 1, nearZ: 1, farZ: 100, reverseZ: true)
        check(near(Point3D(x: 0, y: 0, z: -1).applying(rev).z, 1) && near(Point3D(x: 0, y: 0, z: -100).applying(rev).z, 0, 1e-9), "reverseZ")
        check(proj.is3DProjection() && !proj.isAffine && proj.scale == nil && proj.rotation == nil, "a projection is not affine")
        let pa = ProjectiveTransform3D(t)
        check(pa.isAffine && pa.rotation!.isApproximatelyEqual(to: r90z, tolerance: 1e-12) && AffineTransform3D(projectiveTransform: pa) == t,
              "affine projective transforms")
        check(near(Point3D(x: 1, y: 2, z: -3).applying(proj).unapplying(proj), Point3D(x: 1, y: 2, z: -3)), "ProjectiveTransform3D inverse")

        // Pose3D, ScaledPose3D
        let pose = Pose3D(position: Point3D(x: 1, y: 0, z: 0), rotation: r90z)
        check(near(Point3D(x: 1, y: 0, z: 0).applying(pose), Point3D(x: 1, y: 1, z: 0)), "Pose3D rotates then translates")
        check((pose * pose.inverse).isApproximatelyEqual(to: .identity, tolerance: 1e-12), "Pose3D inverse")
        let both = pose * Pose3D(position: Point3D(x: 0, y: 2, z: 0), rotation: .identity)
        check(near(Point3D.zero.applying(both), Point3D(x: -1, y: 0, z: 0)), "Pose3D * applies the right pose first")
        check(Pose3D(transform: AffineTransform3D(pose: pose))!.isApproximatelyEqual(to: pose, tolerance: 1e-12)
              && Pose3D(transform: t) == nil, "Pose3D from a transform")
        let lookAt = Pose3D(position: Point3D(x: 0, y: 0, z: -5), target: .zero)
        check(near(Vector3D.forward.applying(lookAt), Vector3D(x: 0, y: 0, z: 1)), "Pose3D(position:target:)")
        let sp = ScaledPose3D(position: Point3D(x: 0, y: 0, z: 1), rotation: r90z, scale: 3)
        check(near(Point3D(x: 1, y: 0, z: 0).applying(sp), Point3D(x: 0, y: 3, z: 1)), "ScaledPose3D scales, rotates, translates")
        check((sp * sp.inverse).isApproximatelyEqual(to: .identity, tolerance: 1e-12), "ScaledPose3D inverse")
        check(ScaledPose3D(transform: AffineTransform3D(scaledPose: sp))!.isApproximatelyEqual(to: sp, tolerance: 1e-12), "ScaledPose3D from a transform")
        check(near(Point3D(x: 1, y: 2, z: 3).applying(sp).unapplying(sp), Point3D(x: 1, y: 2, z: 3)), "ScaledPose3D unapplying")
        let pf = pose.flipped(along: .x)
        let mirrored = Point3D(x: 1, y: 0, z: 0).applying(pose)
        check(near(Point3D(x: -1, y: 0, z: 0).applying(pf), Point3D(x: -mirrored.x, y: mirrored.y, z: mirrored.z)), "Pose3D flipped(along:)")

        print("Spatial: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
