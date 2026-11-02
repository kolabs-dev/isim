// The Swift side of the Spatial C test (SpatialSwiftTest.app, issue #692): the same cases as SpatialCases.h, computed
// with Swift's Spatial and printed in the same "name values" lines, which test_spatial.py compares with SpatialCTest's.
import Foundation
import Spatial

func L(_ name: String, _ values: Double...) {
    print(([name] + values.map { String(format: "%.4f", abs($0) < 5e-5 ? 0.0 : $0) }).joined(separator: " "))
}
func V3(_ name: String, _ v: simd_double3) { L(name, v.x, v.y, v.z) }
func V3(_ name: String, _ p: Point3D) { V3(name, p.vector) }
func V3(_ name: String, _ v: Vector3D) { V3(name, v.vector) }
func S3(_ name: String, _ s: Size3D) { V3(name, s.vector) }
func Q(_ name: String, _ q: simd_quatd) { L(name, q.vector.x, q.vector.y, q.vector.z, q.vector.w) }
func R(_ name: String, _ r: Rect3D?) { let r = r!; L(name, r.origin.x, r.origin.y, r.origin.z, r.size.width, r.size.height, r.size.depth) }
func B(_ b: Bool) -> Double { b ? 1 : 0 }

@main enum SpatialSwiftTest {
    static func main() {
        let p = Point3D(x: 1, y: 2, z: 3), v = Vector3D(x: 0, y: 3, z: 4), w = Vector3D(x: 1, y: 2, z: 3)
        L("length", v.length)
        V3("normalize", v.normalized)
        V3("cross", v.cross(w))
        L("dot", v.dot(w))
        L("distance", p.distance(to: Point3D(x: 1, y: 5, z: 7)))
        V3("reflect", w.reflected(Vector3D(x: 0, y: 1, z: 0)))
        V3("project", w.projected(v))
        V3("translate", p.translated(by: v))
        V3("scale", w.scaled(by: Size3D(width: 2, height: 3, depth: 4)))
        V3("shear", w.sheared(.xAxis(yShearFactor: 1, zShearFactor: 0.5)))

        let id = Rotation3D.identity
        let r90z = Rotation3D(angle: .degrees(90), axis: .z)
        V3("rotate", Point3D(x: 1, y: 0, z: 0).rotated(by: r90z))
        L("angle", r90z.angle.degrees)
        V3("axis", r90z.axis.vector)
        let ry = Rotation3D(angle: .degrees(40), axis: .y)
        Q("compose", (ry * r90z).quaternion)
        Q("inverse", r90z.inverse.quaternion)
        V3("euler xyz", Rotation3D(eulerAngles: EulerAngles(angles: SIMD3(0.3, -0.5, 1.1), order: .xyz)).eulerAngles(order: .xyz).angles)
        V3("euler zxy", Rotation3D(eulerAngles: EulerAngles(angles: SIMD3(0.3, -0.5, 1.1), order: .zxy)).eulerAngles(order: .zxy).angles)
        L("slerp", Rotation3D.slerp(from: id, to: r90z, t: 0.5).angle.degrees)
        L("slerp longest", Rotation3D.slerp(from: id, to: r90z, t: 0.5, along: .longest).angle.degrees)
        Q("spline", Rotation3D.spline(leftEndpoint: id, from: r90z, to: ry, rightEndpoint: id, t: 0.25).quaternion)
        Q("look at", Rotation3D(position: Point3D(x: 0, y: 0, z: 0), target: Point3D(x: 0, y: 5, z: 5), up: Vector3D(x: 0, y: 1, z: 0)).quaternion)
        Q("rotation to", Vector3D(x: 1, y: 0, z: 0).rotation(to: Vector3D(x: 0, y: 1, z: 1)).quaternion)

        let box = Rect3D(origin: Point3D(x: 0, y: 0, z: 0), size: Size3D(width: 2, height: 4, depth: 6))
        let other = Rect3D(center: Point3D(x: 2, y: 4, z: 6), size: Size3D(width: 2, height: 2, depth: 2))
        R("intersection", box.intersection(other))
        R("union", box.union(other))
        L("contains", B(box.contains(point: Point3D(x: 1, y: 1, z: 1))), B(box.contains(point: Point3D(x: 3, y: 1, z: 1))))
        L("rect distance", box.distance(to: Rect3D(origin: Point3D(x: 5, y: 0, z: 0), size: Size3D(width: 1, height: 1, depth: 1))))
        R("rect rotate", Rect3D(center: .zero, size: Size3D(width: 2, height: 2, depth: 2)).rotated(by: Rotation3D(angle: .degrees(45), axis: .z)))
        R("bounding", Rect3D(points: [Point3D(x: 1, y: -1, z: 0), Point3D(x: -2, y: 3, z: 4)]))
        V3("corner 7", box.cornerPoints[7])

        let ray = Ray3D(origin: Point3D(x: -5, y: 1, z: 1), direction: Vector3D(x: 2, y: 0, z: 0))
        V3("ray direction", ray.direction)
        L("ray hits", B(ray.intersects(box)), B(Ray3D(origin: Point3D(x: -5, y: 1, z: 1), direction: Vector3D(x: -1, y: 0, z: 0)).intersects(box)))

        let t = AffineTransform3D(scale: Size3D(width: 2, height: 2, depth: 2), rotation: r90z, translation: Vector3D(x: 10, y: 0, z: 0))
        V3("affine point", Point3D(x: 1, y: 0, z: 0).applying(t))
        V3("affine vector", Vector3D(x: 1, y: 0, z: 0).applying(t))
        V3("affine inverse", Point3D(x: 10, y: 2, z: 0).applying(t.inverse!))
        V3("affine unapply", Point3D(x: 10, y: 2, z: 0).unapplying(t))
        Q("affine rotation", t.rotation!.quaternion)
        V3("affine translation", t.translation)
        V3("affine concat", Point3D(x: 1, y: 1, z: 1).applying(t * AffineTransform3D(translation: Vector3D(x: 0, y: 0, z: 5))))
        V3("affine shear", p.applying(AffineTransform3D(shear: .yAxis(xShearFactor: 0.5, zShearFactor: 2))))
        R("affine rect", box.applying(t))

        let proj = ProjectiveTransform3D(fovyRadians: .pi / 2, aspectRatio: 1.5, nearZ: 1, farZ: 100)
        V3("perspective", Point3D(x: 1, y: 2, z: -10).applying(proj))

        let pose = Pose3D(position: Point3D(x: 1, y: 2, z: 3), rotation: r90z)
        V3("pose point", Point3D(x: 1, y: 0, z: 0).applying(pose))
        V3("pose unapply", Point3D(x: 1, y: 0, z: 0).unapplying(pose))
        let pc = pose.concatenating(Pose3D(position: Point3D(x: 0, y: 1, z: 0), rotation: ry))
        V3("pose concat", pc.position)
        Q("pose concat rotation", pc.rotation.quaternion)
        V3("pose inverse", pose.inverse.position)
        let sp = ScaledPose3D(position: Point3D(x: 1, y: 2, z: 3), rotation: r90z, scale: 3)
        V3("scaled pose point", Point3D(x: 1, y: 0, z: 0).applying(sp))
        V3("scaled pose inverse", sp.inverse.position)

        let sc = SphericalCoordinates3D(Point3D(x: 1, y: 1, z: 1))
        L("spherical", sc.radius, sc.inclination.radians, sc.azimuth.radians)
        V3("cartesian", Point3D(sc))
        L("normalize angle", Angle2D(degrees: 270).normalized.degrees)
        L("atan2", Angle2D.atan2(y: 1, x: 1).degrees)
        S3("size union", Size3D(width: 1, height: 5, depth: 2).union(Size3D(width: 3, height: 1, depth: 2)))
        print("SpatialSwiftTest: done")
    }
}
