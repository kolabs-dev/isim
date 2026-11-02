// The Spatial C cases (issue #692), included twice by main.m: in double precision (SUF empty) and with the …Float types
// and functions (SUF Float). N(SPPoint3D, Make) names SPPoint3DMake or SPPoint3DFloatMake. Each line is
// "<prefix><name> <values>"; SpatialSwiftTest prints the same names computed with Swift's Spatial.
#define N__(a, s, b) a##s##b
#define N_(a, s, b) N__(a, s, b)
#define N(a, b) N_(a, SUF, b)
{
    __auto_type p = N(SPPoint3D, Make)(1, 2, 3);
    __auto_type v = N(SPVector3D, Make)(0, 3, 4);
    __auto_type w = N(SPVector3D, Make)(1, 2, 3);
    L("length", 1, N(SPVector3D, Length)(v));
    V3("normalize", N(SPVector3D, Normalize)(v));
    V3("cross", N(SPVector3D, CrossProduct)(v, w));
    L("dot", 1, N(SPVector3D, DotProduct)(v, w));
    L("distance", 1, N(SPPoint3D, DistanceToPoint)(p, N(SPPoint3D, Make)(1, 5, 7)));
    V3("reflect", N(SPVector3D, Reflect)(w, N(SPVector3D, Make)(0, 1, 0)));
    V3("project", N(SPVector3D, Project)(w, v));
    V3("translate", N(SPPoint3D, Translate)(p, v));
    V3("scale", N(SPVector3D, ScaleBySize)(w, N(SPSize3D, Make)(2, 3, 4)));
    V3("shear", N(SPVector3D, Shear)(w, SPAxisX, 1, 0.5));

    __auto_type id = N(SPRotation3D, MakeWithQuaternion)(N(SPPose3D, Identity).rotation);
    __auto_type az = N(SPRotationAxis3D, Make)(0, 0, 1);
    __auto_type r90z = N(SPRotation3D, Make)(az, N(SPAngle, MakeWithDegrees)(90));
    V3("rotate", N(SPPoint3D, Rotate)(N(SPPoint3D, Make)(1, 0, 0), r90z));
    L("angle", 1, N(SPAngle, GetDegrees)(N(SPRotation3D, GetAngle)(r90z)));
    V3("axis", N(SPRotation3D, GetAxis)(r90z));
    __auto_type ry = N(SPRotation3D, Make)(N(SPRotationAxis3D, Make)(0, 1, 0), N(SPAngle, MakeWithDegrees)(40));
    Q("compose", N(SPRotation3D, GetQuaternion)(N(SPRotation3D, MakeWithQuaternion)(simd_mul(ry.quaternion, r90z.quaternion))));
    Q("inverse", simd_inverse(r90z.quaternion));
    __auto_type e = N(SPRotation3D, GetEulerAngles)(N(SPRotation3D, MakeWithEulerAngles)(
        (N(SPEulerAngles,)){ .angles = { 0.3, -0.5, 1.1 }, .order = SPEulerXYZ }), SPEulerXYZ);
    V3("euler xyz", e.angles);
    e = N(SPRotation3D, GetEulerAngles)(N(SPRotation3D, MakeWithEulerAngles)(
        (N(SPEulerAngles,)){ .angles = { 0.3, -0.5, 1.1 }, .order = SPEulerZXY }), SPEulerZXY);
    V3("euler zxy", e.angles);
    L("slerp", 1, N(SPAngle, GetDegrees)(N(SPRotation3D, GetAngle)(N(SPRotation3D, Slerp)(id, r90z, 0.5))));
    L("slerp longest", 1, N(SPAngle, GetDegrees)(N(SPRotation3D, GetAngle)(N(SPRotation3D, SlerpLongest)(id, r90z, 0.5))));
    Q("spline", N(SPRotation3D, Spline)(id, r90z, ry, id, 0.25).quaternion);
    Q("look at", N(SPRotation3D, MakeLookAt)(N(SPPoint3D, Make)(0, 0, 0), N(SPPoint3D, Make)(0, 5, 5), N(SPVector3D, Make)(0, 1, 0)).quaternion);
    Q("rotation to", N(SPVector3D, RotationToVector)(N(SPVector3D, Make)(1, 0, 0), N(SPVector3D, Make)(0, 1, 1)).quaternion);

    __auto_type box = N(SPRect3D, MakeAtOriginWithVector)(N(SPVector3D, Make)(0, 0, 0), N(SPVector3D, Make)(2, 4, 6));
    __auto_type other = N(SPRect3D, MakeAtCenterWithVector)(N(SPVector3D, Make)(2, 4, 6), N(SPVector3D, Make)(2, 2, 2));
    R("intersection", N(SPRect3D, Intersection)(box, other));
    R("union", N(SPRect3D, Union)(box, other));
    L("contains", 2, (double)N(SPRect3D, ContainsPoint)(box, N(SPPoint3D, Make)(1, 1, 1)), (double)N(SPRect3D, ContainsPoint)(box, N(SPPoint3D, Make)(3, 1, 1)));
#if !SP_FLOAT   // double only, like Apple's
    L("rect distance", 1, N(SPRect3D, DistanceToRect)(box, N(SPRect3D, MakeAtOriginWithVector)(N(SPVector3D, Make)(5, 0, 0), N(SPVector3D, Make)(1, 1, 1))));
#endif
    R("rect rotate", N(SPRect3D, Rotate)(N(SPRect3D, MakeAtCenterWithVector)(N(SPVector3D, Make)(0, 0, 0), N(SPVector3D, Make)(2, 2, 2)),
                                          N(SPRotation3D, Make)(az, N(SPAngle, MakeWithDegrees)(45))));
    N(SPPoint3D,) pts[2] = { N(SPPoint3D, Make)(1, -1, 0), N(SPPoint3D, Make)(-2, 3, 4) };
    R("bounding", N(SPRect3D, MakeBoundingFromPoints)(pts, 2));
    N(SPPoint3D,) corners[8];
    N(SPRect3D, GetCornerPoints)(box, corners);
    V3("corner 7", corners[7]);

    __auto_type ray = N(SPRay3D, Make)(N(SPPoint3D, Make)(-5, 1, 1), N(SPVector3D, Make)(2, 0, 0));
    V3("ray direction", ray.direction);
    L("ray hits", 2, (double)N(SPRay3D, IntersectsRect)(ray, box),
      (double)N(SPRay3D, IntersectsRect)(N(SPRay3D, Make)(N(SPPoint3D, Make)(-5, 1, 1), N(SPVector3D, Make)(-1, 0, 0)), box));

    __auto_type t = N(SPAffineTransform3D, Make)(N(SPSize3D, Make)(2, 2, 2), r90z, N(SPVector3D, Make)(10, 0, 0));
    V3("affine point", N(SPPoint3D, ApplyAffineTransform)(N(SPPoint3D, Make)(1, 0, 0), t));
    V3("affine vector", N(SPVector3D, ApplyAffineTransform)(N(SPVector3D, Make)(1, 0, 0), t));
    V3("affine inverse", N(SPPoint3D, ApplyAffineTransform)(N(SPPoint3D, Make)(10, 2, 0), N(SPAffineTransform3D, Inverted)(t)));
    V3("affine unapply", N(SPPoint3D, UnapplyAffineTransform)(N(SPPoint3D, Make)(10, 2, 0), t));
    Q("affine rotation", N(SPAffineTransform3D, GetRotation)(t).quaternion);
    V3("affine translation", N(SPAffineTransform3D, GetTranslation)(t));
    V3("affine concat", N(SPPoint3D, ApplyAffineTransform)(N(SPPoint3D, Make)(1, 1, 1),
        N(SPAffineTransform3D, Concatenation)(t, N(SPAffineTransform3D, MakeTranslation)(N(SPVector3D, Make)(0, 0, 5)))));
    V3("affine shear", N(SPPoint3D, ApplyAffineTransform)(p, N(SPAffineTransform3D, MakeShear)(SPAxisY, 0.5, 2)));
    R("affine rect", N(SPRect3D, ApplyAffineTransform)(box, t));

#if !SP_FLOAT
    __auto_type proj = N(SPProjectiveTransform3D, MakeWithRHPerspective)(M_PI / 2, 1.5, 1, 100);
    V3("perspective", N(SPPoint3D, ApplyProjectiveTransform)(N(SPPoint3D, Make)(1, 2, -10), proj));
#endif

    __auto_type pose = N(SPPose3D, Make)(N(SPPoint3D, Make)(1, 2, 3), r90z);
    V3("pose point", N(SPPoint3D, ApplyPose)(N(SPPoint3D, Make)(1, 0, 0), pose));
    V3("pose unapply", N(SPPoint3D, UnapplyPose)(N(SPPoint3D, Make)(1, 0, 0), pose));
    __auto_type pc = N(SPPose3D, Concatenation)(pose, N(SPPose3D, Make)(N(SPPoint3D, Make)(0, 1, 0), ry));
    V3("pose concat", pc.position);
    Q("pose concat rotation", pc.rotation);
    V3("pose inverse", N(SPPose3D, GetInverse)(pose).position);
    __auto_type sp = N(SPScaledPose3D, Make)(N(SPPoint3D, Make)(1, 2, 3), r90z, 3);
    V3("scaled pose point", N(SPPoint3D, ApplyScaledPose)(N(SPPoint3D, Make)(1, 0, 0), sp));
    V3("scaled pose inverse", N(SPScaledPose3D, GetInverse)(sp).position);

    __auto_type sc = N(SPSphericalCoordinates3D, MakeWithCartesianPoint)(N(SPPoint3D, Make)(1, 1, 1));
    L("spherical", 3, sc.radius, sc.inclination.radians, sc.azimuth.radians);
    V3("cartesian", N(SPPoint3D, MakeWithSphericalCoordinates)(sc));
    L("normalize angle", 1, N(SPAngle, GetDegrees)(N(SPAngle, Normalize)(N(SPAngle, MakeWithDegrees)(270))));
    L("atan2", 1, N(SPAngle, GetDegrees)(N(SPAngle, Atan2)(1, 1)));
    S3("size union", N(SPSize3D, Union)(N(SPSize3D, Make)(1, 5, 2), N(SPSize3D, Make)(3, 1, 2)));
}
#undef N
#undef N_
#undef N__
