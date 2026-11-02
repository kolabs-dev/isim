#!/usr/bin/env python3
"""generates isim's C <Spatial/Spatial.h> (issue #692): python3 tools/spatial-headers.py [DIR] (default
sdk-src/Frameworks/Spatial). The double functions are written below once; the …Float ones (iOS 26) are derived from
them and kept where Apple's SDK has them (FLOAT_NAMES). The semantics follow isim's Swift Spatial overlay
(swift/overlays/Spatial): column-major matrices acting on column vectors, transforms that rotate / scale / shear /
translate a transform apply that change after it, points take the whole transform (projective ones divide by w),
vectors and sizes only its linear part, boxes become the axis-aligned box around their transformed corners."""
import os, re, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sdk-src", "Frameworks", "Spatial")

TYPES = r"""
typedef enum { SPAxisX = 1, SPAxisY = 2, SPAxisZ = 4 } SPAxis;
typedef enum { SPEulerXYZ = 1, SPEulerZXY = 2, SPEulerPitchYawRoll = 1 } SPEulerAngleOrder;

typedef union { struct { double x, y, z; }; simd_double3 vector; } SPPoint3D;
typedef union { struct { double x, y, z; }; simd_double3 vector; } SPVector3D;
typedef union { struct { double width, height, depth; }; simd_double3 vector; } SPSize3D;
typedef union { struct { double x, y, z; }; simd_double3 vector; } SPRotationAxis3D;
typedef struct { double radians; } SPAngle;
typedef union { simd_quatd quaternion; simd_double4 vector; } SPRotation3D;
typedef struct { simd_double3 angles; SPEulerAngleOrder order; } SPEulerAngles;
typedef struct { SPPoint3D origin; SPSize3D size; } SPRect3D;
typedef struct { SPPoint3D origin; SPVector3D direction; } SPRay3D;
typedef union { struct { double radius; SPAngle inclination; SPAngle azimuth; }; simd_double3 vector; } SPSphericalCoordinates3D;
typedef struct { simd_double4x3 matrix; } SPAffineTransform3D;
typedef struct { simd_double4x4 matrix; } SPProjectiveTransform3D;
typedef struct { simd_double3 position; simd_quatd rotation; } SPPose3D;
typedef struct { simd_double3 position; simd_quatd rotation; double scale; } SPScaledPose3D;
"""

CONSTS = r"""
static const SPPoint3D SPPoint3DZero = { .vector = { 0, 0, 0 } };
static const SPPoint3D SPPoint3DInfinity = { .vector = { INFINITY, INFINITY, INFINITY } };
static const SPVector3D SPVector3DZero = { .vector = { 0, 0, 0 } };
static const SPVector3D SPVectorInfinity = { .vector = { INFINITY, INFINITY, INFINITY } };
static const SPSize3D SPSize3DZero = { .vector = { 0, 0, 0 } };
static const SPSize3D SPSize3DInfinity = { .vector = { INFINITY, INFINITY, INFINITY } };
static const SPSize3D SPSize3DInvalid = { .vector = { NAN, NAN, NAN } };
static const SPAngle SPAngleZero = { 0 };
static const SPRect3D SPRect3DZero = { { .vector = { 0, 0, 0 } }, { .vector = { 0, 0, 0 } } };
static const SPRect3D SPRect3DNull = { { .vector = { INFINITY, INFINITY, INFINITY } }, { .vector = { 0, 0, 0 } } };
static const SPRect3D SPRect3DInfinity = { { .vector = { -DBL_MAX / 2, -DBL_MAX / 2, -DBL_MAX / 2 } }, { .vector = { DBL_MAX, DBL_MAX, DBL_MAX } } };
static const SPRay3D SPRay3DZero = { { .vector = { 0, 0, 0 } }, { .vector = { 0, 0, 0 } } };
static const SPRay3D SPRay3DInfinity = { { .vector = { INFINITY, INFINITY, INFINITY } }, { .vector = { INFINITY, INFINITY, INFINITY } } };
static const SPRotation3D SPRotation3DInvalid = { .vector = { NAN, NAN, NAN, NAN } };
static const SPAffineTransform3D SPAffineTransform3DIdentity = { { { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { 0, 0, 0 } } } };
static const SPAffineTransform3D SPAffineTransform3DInvalid = { { { { NAN, NAN, NAN }, { NAN, NAN, NAN }, { NAN, NAN, NAN }, { NAN, NAN, NAN } } } };
static const SPProjectiveTransform3D SPProjectiveTransform3DIdentity = { { { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } } } };
static const SPProjectiveTransform3D SPProjectiveTransform3DInvalid = { { { { NAN, NAN, NAN, NAN }, { NAN, NAN, NAN, NAN }, { NAN, NAN, NAN, NAN }, { NAN, NAN, NAN, NAN } } } };
static const SPPose3D SPPose3DIdentity = { { 0, 0, 0 }, { { 0, 0, 0, 1 } } };
static const SPPose3D SPPose3DInvalid = { { NAN, NAN, NAN }, { { NAN, NAN, NAN, NAN } } };
static const SPScaledPose3D SPScaledPose3DIdentity = { { 0, 0, 0 }, { { 0, 0, 0, 1 } }, 1 };
static const SPScaledPose3D SPScaledPose3DInvalid = { { NAN, NAN, NAN }, { { NAN, NAN, NAN, NAN } }, NAN };
"""

# the functions; F declares an API function (overloadable static inline), H an internal helper
FUNCS = r"""
/* ---- helpers ---- */
H simd_double3 _spd_pt(SPPoint3D p) { return p.vector; }
H double _spd_eps(void) { return 1.4901161193847656e-08; }
H bool _spd_finite3(simd_double3 v) { return isfinite(v.x) && isfinite(v.y) && isfinite(v.z); }
H bool _spd_nan3(simd_double3 v) { return isnan(v.x) || isnan(v.y) || isnan(v.z); }
H bool _spd_zero3(simd_double3 v) { return v.x == 0 && v.y == 0 && v.z == 0; }
H bool _spd_eq3(simd_double3 a, simd_double3 b) { return a.x == b.x && a.y == b.y && a.z == b.z; }
H bool _spd_close3(simd_double3 a, simd_double3 b, double t) { return fabs(a.x - b.x) <= t && fabs(a.y - b.y) <= t && fabs(a.z - b.z) <= t; }
H simd_double4x4 _spd_m44(simd_double4x3 m) {
    return simd_matrix(simd_make_double4(m.columns[0], 0), simd_make_double4(m.columns[1], 0), simd_make_double4(m.columns[2], 0), simd_make_double4(m.columns[3], 1));
}
H simd_double4x3 _spd_trunc(simd_double4x4 m) { return simd_matrix(m.columns[0].xyz, m.columns[1].xyz, m.columns[2].xyz, m.columns[3].xyz); }
H bool _spd_isaffine(simd_double4x4 m) { return m.columns[0].w == 0 && m.columns[1].w == 0 && m.columns[2].w == 0 && m.columns[3].w == 1; }
H simd_double3x3 _spd_upper(simd_double4x4 m) { return simd_matrix(m.columns[0].xyz, m.columns[1].xyz, m.columns[2].xyz); }
H simd_double3x3 _spd_linear(simd_double4x3 m) { return simd_matrix(m.columns[0], m.columns[1], m.columns[2]); }
H simd_double3 _spd_affine(simd_double4x3 m, simd_double3 v, bool point) { return m.columns[0] * v.x + m.columns[1] * v.y + m.columns[2] * v.z + (point ? m.columns[3] : (simd_double3)0); }
H simd_double3 _spd_proj(simd_double4x4 m, simd_double3 v, bool point) {
    simd_double4 r = simd_mul(m, simd_make_double4(v, point ? 1 : 0));
    return point && r.w != 0 && r.w != 1 ? r.xyz / r.w : r.xyz;
}
H simd_quatd _spd_qnorm(simd_quatd q) { double l = simd_length(q.vector); return l > 0 ? simd_quaternion(q.vector / l) : q; }
/* the scale (column lengths, the first negated for a reflection) and the rotation, when the 3x3 holds no shear */
H bool _spd_decompose(simd_double3x3 m, simd_double3 *scale, simd_quatd *rot) {
    simd_double3 s = { simd_length(m.columns[0]), simd_length(m.columns[1]), simd_length(m.columns[2]) };
    if (simd_determinant(m) < 0) s.x = -s.x;
    *scale = s;
    if (s.x == 0 || s.y == 0 || s.z == 0) return false;
    simd_double3x3 r = simd_matrix(m.columns[0] / s.x, m.columns[1] / s.y, m.columns[2] / s.z);
    simd_double3x3 rtr = simd_mul(simd_transpose(r), r);
    for (int c = 0; c < 3; c++) for (int k = 0; k < 3; k++) if (fabs(rtr.columns[c][k] - (c == k ? 1 : 0)) > 1e-9) return false;
    *rot = _spd_qnorm(simd_quaternion(r));
    return true;
}
H bool _spd_uniform(simd_double3 s, SPAxis dims) {
    double v[3]; int n = 0;
    if (dims & SPAxisX) v[n++] = fabs(s.x);
    if (dims & SPAxisY) v[n++] = fabs(s.y);
    if (dims & SPAxisZ) v[n++] = fabs(s.z);
    for (int i = 1; i < n; i++) if (fabs(v[i] - v[0]) > 1e-12 * (fabs(v[0]) > 1 ? fabs(v[0]) : 1)) return false;
    return true;
}
H simd_double3x3 _spd_shear(SPAxis axis, double a, double b) {
    if (axis == SPAxisX) return simd_matrix((simd_double3){ 1, a, b }, (simd_double3){ 0, 1, 0 }, (simd_double3){ 0, 0, 1 });
    if (axis == SPAxisY) return simd_matrix((simd_double3){ 1, 0, 0 }, (simd_double3){ a, 1, b }, (simd_double3){ 0, 0, 1 });
    return simd_matrix((simd_double3){ 1, 0, 0 }, (simd_double3){ 0, 1, 0 }, (simd_double3){ a, b, 1 });
}
H simd_double3 _spd_flipscale(SPAxis axis) { return (simd_double3){ axis == SPAxisX ? -1 : 1, axis == SPAxisY ? -1 : 1, axis == SPAxisZ ? -1 : 1 }; }
H simd_quatd _spd_qlog(simd_quatd q) { double l = simd_length(q.vector.xyz), a = atan2(l, q.vector.w); simd_double3 i = l > 0 ? q.vector.xyz / l * a : (simd_double3)0; return simd_quaternion(i.x, i.y, i.z, 0.0); }
H simd_quatd _spd_qexp(simd_quatd q) { double a = simd_length(q.vector.xyz); simd_double3 i = a > 0 ? q.vector.xyz / a * sin(a) : (simd_double3)0; return simd_quaternion(i.x, i.y, i.z, cos(a)); }
H simd_quatd _spd_inner(simd_quatd p, simd_quatd q, simd_quatd n) {
    simd_quatd qi = simd_inverse(q);
    simd_double4 s = (_spd_qlog(simd_mul(qi, n)).vector + _spd_qlog(simd_mul(qi, p)).vector) * -0.25;
    return simd_mul(q, _spd_qexp(simd_quaternion(s)));
}
H simd_quatd _spd_slerp(simd_quatd a, simd_quatd b, double t) {
    double d = simd_dot(a.vector, b.vector); d = d > 1 ? 1 : d < -1 ? -1 : d;
    if (d > 0.99995) return simd_quaternion(simd_normalize(a.vector + (b.vector - a.vector) * t));
    double th = acos(d), s = sin(th);
    return simd_quaternion(a.vector * (sin((1 - t) * th) / s) + b.vector * (sin(t * th) / s));
}
/* the rotation that turns +z to forward, keeping +y as close to up as it can */
H simd_quatd _spd_forward(simd_double3 forward, simd_double3 up) {
    simd_double3 f = simd_normalize(forward), r = simd_cross(up, f);
    if (!(simd_length(r) > 1e-12) || !_spd_finite3(f)) return simd_quaternion((simd_double3){ 0, 0, 1 }, f);
    simd_double3 rn = simd_normalize(r);
    return _spd_qnorm(simd_quaternion(simd_matrix(rn, simd_cross(f, rn), f)));
}
H simd_double3 _spd_min(simd_double3 a, simd_double3 b) { return simd_min(a, b); }
H simd_double3 _spd_max(simd_double3 a, simd_double3 b) { return simd_max(a, b); }
H SPRect3D _spd_rect(simd_double3 lo, simd_double3 hi) { SPRect3D r; r.origin.vector = lo; r.size.vector = hi - lo; return r; }
H simd_double3 _spd_rmin(SPRect3D r) { return simd_min(r.origin.vector, r.origin.vector + r.size.vector); }
H simd_double3 _spd_rmax(SPRect3D r) { return simd_max(r.origin.vector, r.origin.vector + r.size.vector); }
H void _spd_corners(SPRect3D r, simd_double3 out[8]) {
    simd_double3 lo = _spd_rmin(r), hi = _spd_rmax(r); int k = 0;
    for (int z = 0; z < 2; z++) for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++) out[k++] = (simd_double3){ x ? hi.x : lo.x, y ? hi.y : lo.y, z ? hi.z : lo.z };
}
H SPRect3D _spd_bound(simd_double3 p[8]) { simd_double3 lo = p[0], hi = p[0]; for (int i = 1; i < 8; i++) { lo = simd_min(lo, p[i]); hi = simd_max(hi, p[i]); } return _spd_rect(lo, hi); }

/* ---- SPAngle ---- */
F SPAngle SPAngleMakeWithRadians(double radians) { SPAngle a = { radians }; return a; }
F SPAngle SPAngleMakeWithDegrees(double degrees) { SPAngle a = { degrees * M_PI / 180 }; return a; }
F double SPAngleGetDegrees(SPAngle angle) { return angle.radians * 180 / M_PI; }
F SPAngle SPAngleAcos(double x) { return SPAngleMakeWithRadians(acos(x)); }
F SPAngle SPAngleAcosh(double x) { return SPAngleMakeWithRadians(acosh(x)); }
F SPAngle SPAngleAsin(double x) { return SPAngleMakeWithRadians(asin(x)); }
F SPAngle SPAngleAsinh(double x) { return SPAngleMakeWithRadians(asinh(x)); }
F SPAngle SPAngleAtan(double x) { return SPAngleMakeWithRadians(atan(x)); }
F SPAngle SPAngleAtan2(double y, double x) { return SPAngleMakeWithRadians(atan2(y, x)); }
F SPAngle SPAngleAtanh(double x) { return SPAngleMakeWithRadians(atanh(x)); }
F double SPAngleCos(SPAngle angle) { return cos(angle.radians); }
F double SPAngleCosh(SPAngle angle) { return cosh(angle.radians); }
F double SPAngleSin(SPAngle angle) { return sin(angle.radians); }
F double SPAngleSinh(SPAngle angle) { return sinh(angle.radians); }
F double SPAngleTan(SPAngle angle) { return tan(angle.radians); }
F double SPAngleTanh(SPAngle angle) { return tanh(angle.radians); }
F bool SPAngleEqualToAngle(SPAngle angle1, SPAngle angle2) { return angle1.radians == angle2.radians; }
F SPAngle SPAngleNegate(SPAngle angle) { return SPAngleMakeWithRadians(-angle.radians); }
/* into -π...π */
F SPAngle SPAngleNormalize(SPAngle angle) {
    double r = fmod(angle.radians, 2 * M_PI);
    if (r > M_PI) r -= 2 * M_PI; else if (r <= -M_PI) r += 2 * M_PI;
    return SPAngleMakeWithRadians(r);
}

/* ---- SPPoint3D, SPVector3D, SPSize3D, SPRotationAxis3D: making ---- */
F SPPoint3D SPPoint3DMake(double x, double y, double z) { SPPoint3D p; p.vector = (simd_double3){ x, y, z }; return p; }
F SPPoint3D SPPoint3DMakeWithVector(simd_double3 xyz) { SPPoint3D p; p.vector = xyz; return p; }
F SPPoint3D SPPoint3DMakeWithVector(SPVector3D xyz) { return SPPoint3DMakeWithVector(xyz.vector); }
F SPPoint3D SPPoint3DMakeWithSize(SPSize3D size) { return SPPoint3DMakeWithVector(size.vector); }
F SPPoint3D SPPoint3DMakeWithPackedVector(simd_packed_double4 source) { return SPPoint3D__MAKE3(source); }
F simd_double3 SPPoint3DGetVector(SPPoint3D point) { return point.vector; }
F simd_packed_double4 SPPoint3DGetPackedVector(SPPoint3D point) { return SP__PACK(point.vector, 0); }
F SPPoint3D SPPoint3DGetOrigin(SPPoint3D point) { (void)point; return SPPoint3DZero; }
F SPVector3D SPVector3DMake(double x, double y, double z) { SPVector3D v; v.vector = (simd_double3){ x, y, z }; return v; }
F SPVector3D SPVector3DMakeWithVector(simd_double3 xyz) { SPVector3D v; v.vector = xyz; return v; }
F SPVector3D SPVector3DMakeWithPoint(SPPoint3D point) { return SPVector3DMakeWithVector(point.vector); }
F SPVector3D SPVector3DMakeWithSize(SPSize3D size) { return SPVector3DMakeWithVector(size.vector); }
F SPVector3D SPVector3DMakeWithRotationAxis(SPRotationAxis3D axis) { return SPVector3DMakeWithVector(axis.vector); }
F SPVector3D SPVector3DMakeWithPackedVector(simd_packed_double4 source) { return SPVector3D__MAKE3(source); }
F simd_packed_double4 SPVector3DGetPackedVector(SPVector3D vector) { return SP__PACK(vector.vector, 0); }
F SPSize3D SPSize3DMake(double width, double height, double depth) { SPSize3D s; s.vector = (simd_double3){ width, height, depth }; return s; }
F SPSize3D SPSize3DMakeWithVector(simd_double3 xyz) { SPSize3D s; s.vector = xyz; return s; }
F SPSize3D SPSize3DMakeWithVector(SPVector3D xyz) { return SPSize3DMakeWithVector(xyz.vector); }
F SPSize3D SPSize3DMakeWithPoint(SPPoint3D point) { return SPSize3DMakeWithVector(point.vector); }
F SPSize3D SPSize3DMakeWithPackedVector(simd_packed_double4 source) { return SPSize3D__MAKE3(source); }
F simd_double3 SPSize3DGetVector(SPSize3D size) { return size.vector; }
F simd_packed_double4 SPSize3DGetPackedVector(SPSize3D size) { return SP__PACK(size.vector, 0); }
/* normalized when it has a length */
F SPRotationAxis3D SPRotationAxis3DMakeWithVector(simd_double3 xyz) { SPRotationAxis3D a; double l = simd_length(xyz); a.vector = l > 0 ? xyz / l : xyz; return a; }
F SPRotationAxis3D SPRotationAxis3DMake(double x, double y, double z) { return SPRotationAxis3DMakeWithVector((simd_double3){ x, y, z }); }
F SPRotationAxis3D SPRotationAxis3DMakeWithVector(SPVector3D xyz) { return SPRotationAxis3DMakeWithVector(xyz.vector); }
F SPRotationAxis3D SPRotationAxis3DMakeWithPackedVector(simd_packed_double4 source) { return SPRotationAxis3DMakeWithVector((simd_double3){ source.x, source.y, source.z }); }
F simd_double3 SPRotationAxis3DGetVector(SPRotationAxis3D axis) { return axis.vector; }
F simd_packed_double4 SPRotationAxis3DGetPackedVector(SPRotationAxis3D axis) { return SP__PACK(axis.vector, 0); }
F bool SPRotationAxis3DEqualToRotationAxis(SPRotationAxis3D axis1, SPRotationAxis3D axis2) { return _spd_eq3(axis1.vector, axis2.vector); }

/* ---- spherical coordinates ---- */
F SPSphericalCoordinates3D SPSphericalCoordinates3DMakeWithCartesianVector(simd_double3 v) {
    SPSphericalCoordinates3D s; double r = simd_length(v); double c = r > 0 ? v.z / r : 0; c = c > 1 ? 1 : c < -1 ? -1 : c;
    s.radius = r; s.inclination.radians = r > 0 ? acos(c) : 0; s.azimuth.radians = atan2(v.y, v.x); return s;
}
F SPSphericalCoordinates3D SPSphericalCoordinates3DMakeWithCartesianVector(SPVector3D xyz) { return SPSphericalCoordinates3DMakeWithCartesianVector(xyz.vector); }
F SPSphericalCoordinates3D SPSphericalCoordinates3DMakeWithCartesianPoint(SPPoint3D xyz) { return SPSphericalCoordinates3DMakeWithCartesianVector(xyz.vector); }
F SPSphericalCoordinates3D SPSphericalCoordinates3DMakeWithPackedVector(simd_packed_double4 source) { SPSphericalCoordinates3D s; s.radius = source.x; s.inclination.radians = source.y; s.azimuth.radians = source.z; return s; }
F simd_packed_double4 SPSphericalCoordinates3DGetPackedVector(SPSphericalCoordinates3D coords) { return SP__PACK(((simd_double3){ coords.radius, coords.inclination.radians, coords.azimuth.radians }), 0); }
H simd_double3 _spd_cartesian(SPSphericalCoordinates3D s) {
    return s.radius * (simd_double3){ sin(s.inclination.radians) * cos(s.azimuth.radians), sin(s.inclination.radians) * sin(s.azimuth.radians), cos(s.inclination.radians) };
}
F SPPoint3D SPPoint3DMakeWithSphericalCoordinates(SPSphericalCoordinates3D coords) { return SPPoint3DMakeWithVector(_spd_cartesian(coords)); }
F SPVector3D SPVector3DMakeWithSphericalCoordinates(SPSphericalCoordinates3D coords) { return SPVector3DMakeWithVector(_spd_cartesian(coords)); }

/* ---- SPRotation3D ---- */
F SPRotation3D SPRotation3DMakeWithQuaternion(simd_quatd quaternion) { SPRotation3D r; r.quaternion = quaternion; return r; }
F SPRotation3D SPRotation3DMake(SPRotationAxis3D axis, SPAngle angle) { return SPRotation3DMakeWithQuaternion(simd_quaternion(angle.radians, axis.vector)); }
F SPRotation3D SPRotation3DMakeWithPackedVector(simd_packed_double4 source) { SPRotation3D r; r.vector = (simd_double4){ source.x, source.y, source.z, source.w }; return r; }
F simd_packed_double4 SPRotation3DGetPackedVector(SPRotation3D rotation) { return SP__PACK(rotation.vector.xyz, rotation.vector.w); }
F simd_quatd SPRotation3DGetQuaternion(SPRotation3D rotation) { return rotation.quaternion; }
F SPAngle SPRotation3DGetAngle(SPRotation3D rotation) { return SPAngleMakeWithRadians(simd_angle(rotation.quaternion)); }
F SPRotationAxis3D SPRotation3DGetAxis(SPRotation3D rotation) { SPRotationAxis3D a; a.vector = simd_length(rotation.quaternion.vector.xyz) > 0 ? simd_axis(rotation.quaternion) : (simd_double3){ 1, 0, 0 }; return a; }
F void SPRotation3DSetAngle(SPRotation3D *rotation, SPAngle angle) { *rotation = SPRotation3DMake(SPRotation3DGetAxis(*rotation), angle); }
F void SPRotation3DSetAxis(SPRotation3D *rotation, SPRotationAxis3D axis) { *rotation = SPRotation3DMake(axis, SPRotation3DGetAngle(*rotation)); }
F bool SPRotation3DIsValid(SPRotation3D rotation) { double l = simd_length(rotation.vector); return isfinite(l) && fabs(l - 1) < 1e-6; }
F bool SPRotation3DEqualToRotation(SPRotation3D rotation1, SPRotation3D rotation2) {
    return rotation1.vector.x == rotation2.vector.x && rotation1.vector.y == rotation2.vector.y && rotation1.vector.z == rotation2.vector.z && rotation1.vector.w == rotation2.vector.w;
}
/* q and -q are the same rotation */
F bool SPRotation3DAlmostEqualToRotation(SPRotation3D r1, SPRotation3D r2, double tolerance) {
    simd_double4 d = r1.vector - r2.vector, s = r1.vector + r2.vector;
    return simd_reduce_max(simd_abs(d)) <= tolerance || simd_reduce_max(simd_abs(s)) <= tolerance;
}
F bool SPRotation3DAlmostEqualToRotation(SPRotation3D r1, SPRotation3D r2) { return SPRotation3DAlmostEqualToRotation(r1, r2, _spd_eps()); }
F SPRotation3D SPRotation3DMakeWithEulerAngles(SPEulerAngles eulerAngles) {
    simd_quatd qx = simd_quaternion(eulerAngles.angles.x, (simd_double3){ 1, 0, 0 }), qy = simd_quaternion(eulerAngles.angles.y, (simd_double3){ 0, 1, 0 });
    simd_quatd qz = simd_quaternion(eulerAngles.angles.z, (simd_double3){ 0, 0, 1 });
    return SPRotation3DMakeWithQuaternion(eulerAngles.order == SPEulerZXY ? simd_mul(simd_mul(qy, qx), qz) : simd_mul(simd_mul(qz, qy), qx));
}
F SPEulerAngles SPRotation3DGetEulerAngles(SPRotation3D rotation, SPEulerAngleOrder order) {
    simd_double3x3 m = simd_matrix3x3(_spd_qnorm(rotation.quaternion));
#define R(row, col) m.columns[col][row]
    simd_double3 a = 0;
    if (order == SPEulerZXY) {
        double s = -R(1, 2); a.x = asin(s > 1 ? 1 : s < -1 ? -1 : s);
        if (fabs(R(1, 2)) < 0.9999999) { a.y = atan2(R(0, 2), R(2, 2)); a.z = atan2(R(1, 0), R(1, 1)); }
        else { a.y = atan2(-R(2, 0), R(0, 0)); a.z = 0; }
    } else {
        double s = -R(2, 0); a.y = asin(s > 1 ? 1 : s < -1 ? -1 : s);
        if (fabs(R(2, 0)) < 0.9999999) { a.x = atan2(R(2, 1), R(2, 2)); a.z = atan2(R(1, 0), R(0, 0)); }
        else { a.x = atan2(-R(1, 2), R(1, 1)); a.z = 0; }
    }
#undef R
    SPEulerAngles e = { a, order }; return e;
}
F SPRotation3D SPRotation3DMakeLookAt(SPPoint3D position, SPPoint3D target, SPVector3D up) { return SPRotation3DMakeWithQuaternion(_spd_forward(target.vector - position.vector, up.vector)); }
F SPRotation3D SPRotation3DMakeLookAt(SPPoint3D target, SPVector3D up) { return SPRotation3DMakeWithQuaternion(_spd_forward(target.vector, up.vector)); }
F SPRotation3D SPRotation3DSlerp(SPRotation3D from, SPRotation3D to, double t) {
    simd_quatd b = simd_dot(from.quaternion.vector, to.quaternion.vector) < 0 ? simd_quaternion(-to.vector) : to.quaternion;
    return SPRotation3DMakeWithQuaternion(_spd_slerp(from.quaternion, b, t));
}
F SPRotation3D SPRotation3DSlerpLongest(SPRotation3D from, SPRotation3D to, double t) {
    simd_quatd b = simd_dot(from.quaternion.vector, to.quaternion.vector) >= 0 ? simd_quaternion(-to.vector) : to.quaternion;
    return SPRotation3DMakeWithQuaternion(_spd_slerp(from.quaternion, b, t));
}
/* Shoemake's squad through r0…r3, between r1 and r2 */
F SPRotation3D SPRotation3DSpline(SPRotation3D r0, SPRotation3D r1, SPRotation3D r2, SPRotation3D r3, double t) {
    simd_quatd a = _spd_inner(r0.quaternion, r1.quaternion, r2.quaternion), b = _spd_inner(r1.quaternion, r2.quaternion, r3.quaternion);
    return SPRotation3DMakeWithQuaternion(_spd_slerp(_spd_slerp(r1.quaternion, r2.quaternion, t), _spd_slerp(a, b, t), 2 * t * (1 - t)));
}
F SPRotation3D SPVector3DRotationToVector(SPVector3D vector, SPVector3D other) { return SPRotation3DMakeWithQuaternion(simd_quaternion(vector.vector, other.vector)); }

/* ---- vector math ---- */
F double SPVector3DDotProduct(SPVector3D x, SPVector3D y) { return simd_dot(x.vector, y.vector); }
F SPVector3D SPVector3DCrossProduct(SPVector3D x, SPVector3D y) { return SPVector3DMakeWithVector(simd_cross(x.vector, y.vector)); }
F double SPVector3DLength(SPVector3D x) { return simd_length(x.vector); }
F double SPVector3DLengthSquared(SPVector3D x) { return simd_length_squared(x.vector); }
F SPVector3D SPVector3DNormalize(SPVector3D x) { double l = simd_length(x.vector); return l > 0 ? SPVector3DMakeWithVector(x.vector / l) : x; }
F SPVector3D SPVector3DProject(SPVector3D x, SPVector3D y) { double d = simd_dot(y.vector, y.vector); return d == 0 ? SPVector3DZero : SPVector3DMakeWithVector(simd_dot(x.vector, y.vector) / d * y.vector); }
F SPVector3D SPVector3DReflect(SPVector3D x, SPVector3D y) { simd_double3 n = simd_normalize(y.vector); return SPVector3DMakeWithVector(x.vector - 2 * simd_dot(x.vector, n) * n); }
F SPVector3D SPVector3DLerp(SPVector3D from, SPVector3D to, SPVector3D t) { return SPVector3DMakeWithVector(from.vector + (to.vector - from.vector) * t.vector); }
F SPVector3D SPVector3DSmoothstep(SPVector3D edge0, SPVector3D edge1, SPVector3D x) { return SPVector3DMakeWithVector(simd_smoothstep(edge0.vector, edge1.vector, x.vector)); }

/* ---- characteristics ---- */
F bool SPPoint3DEqualToPoint(SPPoint3D point1, SPPoint3D point2) { return _spd_eq3(point1.vector, point2.vector); }
F bool SPPoint3DAlmostEqualToPoint(SPPoint3D p1, SPPoint3D p2, double tolerance) { return _spd_close3(p1.vector, p2.vector, tolerance); }
F bool SPPoint3DAlmostEqualToPoint(SPPoint3D p1, SPPoint3D p2) { return _spd_close3(p1.vector, p2.vector, _spd_eps()); }
F bool SPPoint3DIsFinite(SPPoint3D point) { return _spd_finite3(point.vector); }
F bool SPPoint3DIsNaN(SPPoint3D point) { return _spd_nan3(point.vector); }
F bool SPPoint3DIsZero(SPPoint3D point) { return _spd_zero3(point.vector); }
F double SPPoint3DDistanceToPoint(SPPoint3D from, SPPoint3D to) { return simd_distance(from.vector, to.vector); }
F bool SPVector3DEqualToVector(SPVector3D vector1, SPVector3D vector2) { return _spd_eq3(vector1.vector, vector2.vector); }
F bool SPVector3DIsFinite(SPVector3D vector) { return _spd_finite3(vector.vector); }
F bool SPVector3DIsNaN(SPVector3D vector) { return _spd_nan3(vector.vector); }
F bool SPVector3DIsZero(SPVector3D vector) { return _spd_zero3(vector.vector); }
F bool SPSize3DEqualToSize(SPSize3D size1, SPSize3D size2) { return _spd_eq3(size1.vector, size2.vector); }
F bool SPSize3DIsFinite(SPSize3D size) { return _spd_finite3(size.vector); }
F bool SPSize3DIsNaN(SPSize3D size) { return _spd_nan3(size.vector); }
F bool SPSize3DIsZero(SPSize3D size) { return _spd_zero3(size.vector); }
O bool SPRotationAxis3DIsZero(SPRotationAxis3D axis) { return _spd_zero3(axis.vector); }
F bool SPSize3DIsValid(SPSize3D size) { return !_spd_nan3(size.vector) && size.width >= 0 && size.height >= 0 && size.depth >= 0; }
F bool SPSize3DContainsSize(SPSize3D size, SPSize3D other) { return simd_all(other.vector <= size.vector); }
F bool SPSize3DContainsPoint(SPSize3D size, SPPoint3D other) { return simd_all(other.vector >= 0) && simd_all(other.vector <= size.vector); }
F bool SPSize3DContainsAnyPoint(SPSize3D size, const SPPoint3D *points, int pointCount) { for (int i = 0; i < pointCount; i++) if (SPSize3DContainsPoint(size, points[i])) return true; return false; }
F SPSize3D SPSize3DUnion(SPSize3D size, SPSize3D other) { return SPSize3DMakeWithVector(simd_max(size.vector, other.vector)); }
F SPSize3D SPSize3DIntersection(SPSize3D size, SPSize3D other) { return SPSize3DMakeWithVector(simd_min(size.vector, other.vector)); }

/* ---- rotating, scaling, shearing, translating primitives ---- */
F SPPoint3D SPPoint3DRotateByQuaternion(SPPoint3D point, simd_quatd quaternion) { return SPPoint3DMakeWithVector(simd_act(quaternion, point.vector)); }
F SPPoint3D SPPoint3DRotate(SPPoint3D point, SPRotation3D rotation) { return SPPoint3DRotateByQuaternion(point, rotation.quaternion); }
F SPPoint3D SPPoint3DTranslate(SPPoint3D point, SPVector3D offset) { return SPPoint3DMakeWithVector(point.vector + offset.vector); }
F SPPoint3D SPPoint3DTranslate(SPPoint3D point, SPSize3D offset) { return SPPoint3DMakeWithVector(point.vector + offset.vector); }
F SPPoint3D SPPoint3DClampToRect(SPPoint3D point, SPRect3D rect) { return SPPoint3DMakeWithVector(simd_clamp(point.vector, _spd_rmin(rect), _spd_rmax(rect))); }
F SPVector3D SPVector3DRotateByQuaternion(SPVector3D vector, simd_quatd quaternion) { return SPVector3DMakeWithVector(simd_act(quaternion, vector.vector)); }
F SPVector3D SPVector3DRotate(SPVector3D vector, SPRotation3D rotation) { return SPVector3DRotateByQuaternion(vector, rotation.quaternion); }
F SPVector3D SPVector3DScaleBySize(SPVector3D vector, SPSize3D scale) { return SPVector3DMakeWithVector(vector.vector * scale.vector); }
F SPVector3D SPVector3DScaleBy(SPVector3D vector, double x, double y, double z) { return SPVector3DMakeWithVector(vector.vector * (simd_double3){ x, y, z }); }
F SPVector3D SPVector3DScaleUniform(SPVector3D vector, double scale) { return SPVector3DMakeWithVector(vector.vector * scale); }
F SPVector3D SPVector3DShear(SPVector3D vector, SPAxis shearAxis, double shearFactor0, double shearFactor1) { return SPVector3DMakeWithVector(simd_mul(_spd_shear(shearAxis, shearFactor0, shearFactor1), vector.vector)); }
F SPSize3D SPSize3DRotateByQuaternion(SPSize3D size, simd_quatd quaternion) { return SPSize3DMakeWithVector(simd_act(quaternion, size.vector)); }
F SPSize3D SPSize3DRotate(SPSize3D size, SPRotation3D rotation) { return SPSize3DRotateByQuaternion(size, rotation.quaternion); }
F SPSize3D SPSize3DScaleBySize(SPSize3D size, SPSize3D scale) { return SPSize3DMakeWithVector(size.vector * scale.vector); }
F SPSize3D SPSize3DScaleBy(SPSize3D size, double x, double y, double z) { return SPSize3DMakeWithVector(size.vector * (simd_double3){ x, y, z }); }
F SPSize3D SPSize3DScaleUniform(SPSize3D size, double scale) { return SPSize3DMakeWithVector(size.vector * scale); }
F SPSize3D SPSize3DShear(SPSize3D size, SPAxis shearAxis, double shearFactor0, double shearFactor1) { return SPSize3DMakeWithVector(simd_mul(_spd_shear(shearAxis, shearFactor0, shearFactor1), size.vector)); }

/* ---- SPAffineTransform3D ---- */
H SPAffineTransform3D _spd_affine4(simd_double4x4 matrix) { SPAffineTransform3D t; t.matrix = _spd_isaffine(matrix) ? _spd_trunc(matrix) : SPAffineTransform3DInvalid.matrix; return t; }
F SPAffineTransform3D SPAffineTransform3DMakeWith4x4Matrix(simd_double4x4 matrix) { return _spd_affine4(matrix); }
F SPAffineTransform3D SPAffineTransform3DMakeWithProjective(SPProjectiveTransform3D transform) { return SPAffineTransform3DMakeWith4x4Matrix(transform.matrix); }
F SPAffineTransform3D SPAffineTransform3DMake(SPSize3D scale, SPRotation3D rotation, SPVector3D translation) {
    simd_double3x3 r = simd_matrix3x3(_spd_qnorm(rotation.quaternion)); simd_double3 s = scale.vector; SPAffineTransform3D t;
    t.matrix = simd_matrix(r.columns[0] * s.x, r.columns[1] * s.y, r.columns[2] * s.z, translation.vector); return t;
}
F SPAffineTransform3D SPAffineTransform3DMake(SPSize3D scale, SPRotation3D rotation, SPSize3D translation) { return SPAffineTransform3DMake(scale, rotation, SPVector3DMakeWithVector(translation.vector)); }
F SPAffineTransform3D SPAffineTransform3DMakeScale(SPSize3D scale) { return SPAffineTransform3DMake(scale, SPRotation3DMakeWithQuaternion(simd_quaternion(0.0, 0.0, 0.0, 1.0)), SPVector3DZero); }
F SPAffineTransform3D SPAffineTransform3DMakeRotation(SPRotation3D rotation) { return SPAffineTransform3DMake(SPSize3DMake(1, 1, 1), rotation, SPVector3DZero); }
F SPAffineTransform3D SPAffineTransform3DMakeTranslation(SPVector3D offset) { SPAffineTransform3D t = SPAffineTransform3DIdentity; t.matrix.columns[3] = offset.vector; return t; }
F SPAffineTransform3D SPAffineTransform3DMakeTranslation(SPSize3D translation) { return SPAffineTransform3DMakeTranslation(SPVector3DMakeWithVector(translation.vector)); }
F SPAffineTransform3D SPAffineTransform3DMakeShear(SPAxis shearAxis, double shearFactor0, double shearFactor1) {
    simd_double3x3 m = _spd_shear(shearAxis, shearFactor0, shearFactor1); SPAffineTransform3D t; t.matrix = simd_matrix(m.columns[0], m.columns[1], m.columns[2], (simd_double3)0); return t;
}
F SPAffineTransform3D SPAffineTransform3DMakeWithPose(SPPose3D pose) { return SPAffineTransform3DMake(SPSize3DMake(1, 1, 1), SPRotation3DMakeWithQuaternion(pose.rotation), SPVector3DMakeWithVector(pose.position)); }
F SPAffineTransform3D SPAffineTransform3DMakeWithScaledPose(SPScaledPose3D pose) { return SPAffineTransform3DMake(SPSize3DMake(pose.scale, pose.scale, pose.scale), SPRotation3DMakeWithQuaternion(pose.rotation), SPVector3DMakeWithVector(pose.position)); }
F SPAffineTransform3D SPAffineTransform3DConcatenation(SPAffineTransform3D t1, SPAffineTransform3D t2) { SPAffineTransform3D t; t.matrix = _spd_trunc(simd_mul(_spd_m44(t1.matrix), _spd_m44(t2.matrix))); return t; }
F SPVector3D SPAffineTransform3DGetTranslation(SPAffineTransform3D transform) { return SPVector3DMakeWithVector(transform.matrix.columns[3]); }
F SPVector3D SPAffineTransform3DGetOffset(SPAffineTransform3D transform) { return SPAffineTransform3DGetTranslation(transform); }
F void SPAffineTransform3DSetTranslation(SPAffineTransform3D *transform, SPVector3D offset) { transform->matrix.columns[3] = offset.vector; }
F void SPAffineTransform3DSetOffset(SPAffineTransform3D *transform, SPVector3D offset) { transform->matrix.columns[3] = offset.vector; }
F SPRotation3D SPAffineTransform3DGetRotation(SPAffineTransform3D transform) { simd_double3 s; simd_quatd q; return _spd_decompose(_spd_linear(transform.matrix), &s, &q) ? SPRotation3DMakeWithQuaternion(q) : SPRotation3DInvalid; }
F SPAffineTransform3D SPAffineTransform3DInverted(SPAffineTransform3D transform) {
    if (simd_determinant(_spd_linear(transform.matrix)) == 0) return SPAffineTransform3DInvalid;
    SPAffineTransform3D t; t.matrix = _spd_trunc(simd_inverse(_spd_m44(transform.matrix))); return t;
}
F bool SPAffineTransform3DIsValid(SPAffineTransform3D transform) {
    for (int c = 0; c < 4; c++) if (!_spd_finite3(transform.matrix.columns[c])) return false;
    return true;
}
F bool SPAffineTransform3DIsIdentity(SPAffineTransform3D transform) { return simd_equal(transform.matrix, SPAffineTransform3DIdentity.matrix); }
F bool SPAffineTransform3DIsTranslation(SPAffineTransform3D transform) { return simd_equal(_spd_linear(transform.matrix), matrix_identity_double3x3); }
/* a scale and a rotation, no shear */
F bool SPAffineTransform3DIsRectilinear(SPAffineTransform3D transform) { simd_double3 s; simd_quatd q; return _spd_decompose(_spd_linear(transform.matrix), &s, &q); }
F bool SPAffineTransform3DIsUniformOverDimensions(SPAffineTransform3D transform, SPAxis dimensionFlags) { simd_double3 s; simd_quatd q; _spd_decompose(_spd_linear(transform.matrix), &s, &q); return _spd_uniform(s, dimensionFlags); }
F bool SPAffineTransform3DIsUniform(SPAffineTransform3D transform) { return SPAffineTransform3DIsUniformOverDimensions(transform, (SPAxis)(SPAxisX | SPAxisY | SPAxisZ)); }
F bool SPAffineTransform3DAlmostEqualToTransform(SPAffineTransform3D t1, SPAffineTransform3D t2, double tolerance) { return simd_almost_equal_elements(t1.matrix, t2.matrix, tolerance); }
F bool SPAffineTransform3DAlmostEqualToTransform(SPAffineTransform3D t1, SPAffineTransform3D t2) { return simd_almost_equal_elements(t1.matrix, t2.matrix, _spd_eps()); }
F SPAffineTransform3D SPAffineTransform3DRotate(SPAffineTransform3D transform, SPRotation3D rotation) { return SPAffineTransform3DConcatenation(SPAffineTransform3DMakeRotation(rotation), transform); }
F SPAffineTransform3D SPAffineTransform3DRotateByQuaternion(SPAffineTransform3D transform, simd_quatd quaternion) { return SPAffineTransform3DRotate(transform, SPRotation3DMakeWithQuaternion(quaternion)); }
F SPAffineTransform3D SPAffineTransform3DScaleBySize(SPAffineTransform3D transform, SPSize3D scale) { return SPAffineTransform3DConcatenation(SPAffineTransform3DMakeScale(scale), transform); }
F SPAffineTransform3D SPAffineTransform3DScaleBy(SPAffineTransform3D transform, double x, double y, double z) { return SPAffineTransform3DScaleBySize(transform, SPSize3DMake(x, y, z)); }
F SPAffineTransform3D SPAffineTransform3DScaleUniform(SPAffineTransform3D transform, double scale) { return SPAffineTransform3DScaleBySize(transform, SPSize3DMake(scale, scale, scale)); }
F SPAffineTransform3D SPAffineTransform3DShear(SPAffineTransform3D transform, SPAxis shearAxis, double shearFactor0, double shearFactor1) { return SPAffineTransform3DConcatenation(SPAffineTransform3DMakeShear(shearAxis, shearFactor0, shearFactor1), transform); }
F SPAffineTransform3D SPAffineTransform3DTranslate(SPAffineTransform3D transform, SPVector3D offset) { return SPAffineTransform3DConcatenation(SPAffineTransform3DMakeTranslation(offset), transform); }
F SPAffineTransform3D SPAffineTransform3DTranslate(SPAffineTransform3D transform, SPSize3D size) { return SPAffineTransform3DTranslate(transform, SPVector3DMakeWithVector(size.vector)); }
F SPAffineTransform3D SPAffineTransform3DFlip(SPAffineTransform3D transform, SPAxis flipAxis) { return SPAffineTransform3DScaleBySize(transform, SPSize3DMakeWithVector(_spd_flipscale(flipAxis))); }
/* this transform, given in the basis `from`, expressed in the basis `to` */
F SPAffineTransform3D SPAffineTransform3DChangeBasis(SPAffineTransform3D transform, SPAffineTransform3D from, SPAffineTransform3D to) {
    SPAffineTransform3D fi = SPAffineTransform3DInverted(from), ti = SPAffineTransform3DInverted(to);
    if (!SPAffineTransform3DIsValid(fi) || !SPAffineTransform3DIsValid(ti)) return SPAffineTransform3DInvalid;
    return SPAffineTransform3DConcatenation(SPAffineTransform3DConcatenation(SPAffineTransform3DConcatenation(SPAffineTransform3DConcatenation(ti, from), transform), fi), to);
}

/* ---- SPProjectiveTransform3D ---- */
F SPProjectiveTransform3D SPProjectiveTransform3DMake(SPSize3D scale, SPRotation3D rotation, SPVector3D translation) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMake(scale, rotation, translation).matrix); return t; }
F SPProjectiveTransform3D SPProjectiveTransform3DMake(SPSize3D scale, SPRotation3D rotation, SPSize3D translation) { return SPProjectiveTransform3DMake(scale, rotation, SPVector3DMakeWithVector(translation.vector)); }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeScale(SPSize3D scale) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMakeScale(scale).matrix); return t; }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeRotation(SPRotation3D rotation) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMakeRotation(rotation).matrix); return t; }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeTranslation(SPVector3D offset) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMakeTranslation(offset).matrix); return t; }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeTranslation(SPSize3D translation) { return SPProjectiveTransform3DMakeTranslation(SPVector3DMakeWithVector(translation.vector)); }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeShear(SPAxis shearAxis, double shearFactor0, double shearFactor1) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMakeShear(shearAxis, shearFactor0, shearFactor1).matrix); return t; }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeWithPose(SPPose3D pose) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMakeWithPose(pose).matrix); return t; }
F SPProjectiveTransform3D SPProjectiveTransform3DMakeWithScaledPose(SPScaledPose3D pose) { SPProjectiveTransform3D t; t.matrix = _spd_m44(SPAffineTransform3DMakeWithScaledPose(pose).matrix); return t; }
/* right-handed (the camera looks down -z), depth 0...1, or 1...0 when reverseZ */
F SPProjectiveTransform3D SPProjectiveTransform3DMakeWithRHPerspective(double fovyRadians, double aspectRatio, double nearZ, double farZ, bool reverseZ) {
    double ys = 1 / tan(fovyRadians / 2), xs = ys / aspectRatio, zs, zt;
    if (isinf(farZ)) { zs = reverseZ ? 0 : -1; zt = reverseZ ? nearZ : -nearZ; }
    else if (reverseZ) { zs = nearZ / (farZ - nearZ); zt = farZ * nearZ / (farZ - nearZ); }
    else { zs = farZ / (nearZ - farZ); zt = nearZ * farZ / (nearZ - farZ); }
    SPProjectiveTransform3D t; t.matrix = simd_matrix((simd_double4){ xs, 0, 0, 0 }, (simd_double4){ 0, ys, 0, 0 }, (simd_double4){ 0, 0, zs, -1 }, (simd_double4){ 0, 0, zt, 0 }); return t;
}
F SPProjectiveTransform3D SPProjectiveTransform3DMakeWithRHPerspective(double fovyRadians, double aspectRatio, double nearZ, double farZ) { return SPProjectiveTransform3DMakeWithRHPerspective(fovyRadians, aspectRatio, nearZ, farZ, false); }
F SPProjectiveTransform3D SPProjectiveTransform3DConcatenation(SPProjectiveTransform3D t1, SPProjectiveTransform3D t2) { SPProjectiveTransform3D t; t.matrix = simd_mul(t1.matrix, t2.matrix); return t; }
F SPVector3D SPProjectiveTransform3DGetTranslation(SPProjectiveTransform3D transform) { return SPVector3DMakeWithVector(transform.matrix.columns[3].xyz); }
F SPVector3D SPProjectiveTransform3DGetOffset(SPProjectiveTransform3D transform) { return SPProjectiveTransform3DGetTranslation(transform); }
F void SPProjectiveTransform3DSetTranslation(SPProjectiveTransform3D *transform, SPVector3D offset) { transform->matrix.columns[3].xyz = offset.vector; }
F void SPProjectiveTransform3DSetOffset(SPProjectiveTransform3D *transform, SPVector3D offset) { transform->matrix.columns[3].xyz = offset.vector; }
F SPSize3D SPProjectiveTransform3DGetScale(SPProjectiveTransform3D transform) { simd_double3 s; simd_quatd q; _spd_decompose(_spd_upper(transform.matrix), &s, &q); return SPSize3DMakeWithVector(s); }
F SPRotation3D SPProjectiveTransform3DGetRotation(SPProjectiveTransform3D transform) {
    simd_double3 s; simd_quatd q;
    return _spd_isaffine(transform.matrix) && _spd_decompose(_spd_upper(transform.matrix), &s, &q) ? SPRotation3DMakeWithQuaternion(q) : SPRotation3DInvalid;
}
F SPProjectiveTransform3D SPProjectiveTransform3DInverted(SPProjectiveTransform3D transform) {
    if (simd_determinant(transform.matrix) == 0) return SPProjectiveTransform3DInvalid;
    SPProjectiveTransform3D t; t.matrix = simd_inverse(transform.matrix); return t;
}
F bool SPProjectiveTransform3DIsValid(SPProjectiveTransform3D transform) { for (int c = 0; c < 4; c++) if (!_spd_finite3(transform.matrix.columns[c].xyz) || !isfinite(transform.matrix.columns[c].w)) return false; return true; }
F bool SPProjectiveTransform3DIsIdentity(SPProjectiveTransform3D transform) { return simd_equal(transform.matrix, matrix_identity_double4x4); }
F bool SPProjectiveTransform3DIsTranslation(SPProjectiveTransform3D transform) { return _spd_isaffine(transform.matrix) && simd_equal(_spd_upper(transform.matrix), matrix_identity_double3x3); }
F bool SPProjectiveTransform3DIsRectilinear(SPProjectiveTransform3D transform) { simd_double3 s; simd_quatd q; return _spd_isaffine(transform.matrix) && _spd_decompose(_spd_upper(transform.matrix), &s, &q); }
F bool SPProjectiveTransform3DIsUniformOverDimensions(SPProjectiveTransform3D transform, SPAxis dimensionFlags) { simd_double3 s; simd_quatd q; _spd_decompose(_spd_upper(transform.matrix), &s, &q); return _spd_uniform(s, dimensionFlags); }
F bool SPProjectiveTransform3DIsUniform(SPProjectiveTransform3D transform) { return SPProjectiveTransform3DIsUniformOverDimensions(transform, (SPAxis)(SPAxisX | SPAxisY | SPAxisZ)); }
F bool SPProjectiveTransform3DAlmostEqualToTransform(SPProjectiveTransform3D t1, SPProjectiveTransform3D t2, double tolerance) { return simd_almost_equal_elements(t1.matrix, t2.matrix, tolerance); }
F bool SPProjectiveTransform3DAlmostEqualToTransform(SPProjectiveTransform3D t1, SPProjectiveTransform3D t2) { return simd_almost_equal_elements(t1.matrix, t2.matrix, _spd_eps()); }
F SPProjectiveTransform3D SPProjectiveTransform3DRotate(SPProjectiveTransform3D transform, SPRotation3D rotation) { return SPProjectiveTransform3DConcatenation(SPProjectiveTransform3DMakeRotation(rotation), transform); }
F SPProjectiveTransform3D SPProjectiveTransform3DRotateByQuaternion(SPProjectiveTransform3D transform, simd_quatd quaternion) { return SPProjectiveTransform3DRotate(transform, SPRotation3DMakeWithQuaternion(quaternion)); }
F SPProjectiveTransform3D SPProjectiveTransform3DScaleBySize(SPProjectiveTransform3D transform, SPSize3D scale) { return SPProjectiveTransform3DConcatenation(SPProjectiveTransform3DMakeScale(scale), transform); }
F SPProjectiveTransform3D SPProjectiveTransform3DScaleBy(SPProjectiveTransform3D transform, double x, double y, double z) { return SPProjectiveTransform3DScaleBySize(transform, SPSize3DMake(x, y, z)); }
F SPProjectiveTransform3D SPProjectiveTransform3DScaleUniform(SPProjectiveTransform3D transform, double scale) { return SPProjectiveTransform3DScaleBySize(transform, SPSize3DMake(scale, scale, scale)); }
F SPProjectiveTransform3D SPProjectiveTransform3DShear(SPProjectiveTransform3D transform, SPAxis shearAxis, double shearFactor0, double shearFactor1) { return SPProjectiveTransform3DConcatenation(SPProjectiveTransform3DMakeShear(shearAxis, shearFactor0, shearFactor1), transform); }
F SPProjectiveTransform3D SPProjectiveTransform3DTranslate(SPProjectiveTransform3D transform, SPVector3D offset) { return SPProjectiveTransform3DConcatenation(SPProjectiveTransform3DMakeTranslation(offset), transform); }
F SPProjectiveTransform3D SPProjectiveTransform3DTranslate(SPProjectiveTransform3D transform, SPSize3D size) { return SPProjectiveTransform3DTranslate(transform, SPVector3DMakeWithVector(size.vector)); }
F SPProjectiveTransform3D SPProjectiveTransform3DFlip(SPProjectiveTransform3D transform, SPAxis flipAxis) { return SPProjectiveTransform3DScaleBySize(transform, SPSize3DMakeWithVector(_spd_flipscale(flipAxis))); }

/* ---- SPPose3D ---- */
F SPPose3D SPPose3DMakeWithVector(simd_double3 position, simd_quatd rotation) { SPPose3D p = { position, rotation }; return p; }
F SPPose3D SPPose3DMake(SPPoint3D position, SPRotation3D rotation) { return SPPose3DMakeWithVector(position.vector, rotation.quaternion); }
F SPPose3D SPPose3DMakeLookAt(SPPoint3D position, SPPoint3D target, SPVector3D up) { return SPPose3DMakeWithVector(position.vector, _spd_forward(target.vector - position.vector, up.vector)); }
F SPPose3D SPPose3DMakeLookAt(SPPoint3D target, SPVector3D up) { return SPPose3DMakeWithVector((simd_double3)0, _spd_forward(target.vector, up.vector)); }
F SPPose3D SPPose3DMakeLookAt(SPVector3D forward, SPVector3D up) { return SPPose3DMakeWithVector((simd_double3)0, _spd_forward(forward.vector, up.vector)); }
/* invalid when the transform scales or shears */
F SPPose3D SPPose3DMakeWithAffineTransform(SPAffineTransform3D transform) {
    simd_double3 s; simd_quatd q;
    if (!_spd_decompose(_spd_linear(transform.matrix), &s, &q) || simd_length(s - 1) >= 1e-9) return SPPose3DInvalid;
    return SPPose3DMakeWithVector(transform.matrix.columns[3], q);
}
F SPPose3D SPPose3DMakeWithProjectiveTransform(SPProjectiveTransform3D transform) { return _spd_isaffine(transform.matrix) ? SPPose3DMakeWithAffineTransform(_spd_affine4(transform.matrix)) : SPPose3DInvalid; }
F SPPose3D SPPose3DMakeWith4x4Matrix(simd_double4x4 matrix) { SPProjectiveTransform3D t = { matrix }; return SPPose3DMakeWithProjectiveTransform(t); }
F simd_double4x4 SPPose3DGet4x4Matrix(SPPose3D pose) { return _spd_m44(SPAffineTransform3DMakeWithPose(pose).matrix); }
F SPPose3D SPPose3DGetInverse(SPPose3D pose) { simd_quatd r = simd_inverse(pose.rotation); return SPPose3DMakeWithVector(-simd_act(r, pose.position), r); }
/* the pose that applies rhs first, then lhs */
F SPPose3D SPPose3DConcatenation(SPPose3D lhs, SPPose3D rhs) { return SPPose3DMakeWithVector(simd_act(lhs.rotation, rhs.position) + lhs.position, simd_mul(lhs.rotation, rhs.rotation)); }
F bool SPPose3DIsIdentity(SPPose3D pose) { return _spd_zero3(pose.position) && _spd_zero3(pose.rotation.vector.xyz) && fabs(pose.rotation.vector.w) == 1; }
F bool SPPose3DIsValid(SPPose3D pose) { return _spd_finite3(pose.position) && SPRotation3DIsValid(SPRotation3DMakeWithQuaternion(pose.rotation)); }
F bool SPPose3DEqualToPose(SPPose3D pose1, SPPose3D pose2) { return _spd_eq3(pose1.position, pose2.position) && SPRotation3DEqualToRotation(SPRotation3DMakeWithQuaternion(pose1.rotation), SPRotation3DMakeWithQuaternion(pose2.rotation)); }
F bool SPPose3DAlmostEqualToPose(SPPose3D p1, SPPose3D p2, double tolerance) { return _spd_close3(p1.position, p2.position, tolerance) && SPRotation3DAlmostEqualToRotation(SPRotation3DMakeWithQuaternion(p1.rotation), SPRotation3DMakeWithQuaternion(p2.rotation), tolerance); }
F bool SPPose3DAlmostEqualToPose(SPPose3D p1, SPPose3D p2) { return SPPose3DAlmostEqualToPose(p1, p2, _spd_eps()); }
F SPPose3D SPPose3DRotate(SPPose3D pose, SPRotation3D rotation) { return SPPose3DMakeWithVector(simd_act(rotation.quaternion, pose.position), simd_mul(rotation.quaternion, pose.rotation)); }
F SPPose3D SPPose3DRotateByQuaternion(SPPose3D pose, simd_quatd quaternion) { return SPPose3DRotate(pose, SPRotation3DMakeWithQuaternion(quaternion)); }
F SPPose3D SPPose3DTranslate(SPPose3D pose, SPVector3D offset) { return SPPose3DMakeWithVector(pose.position + offset.vector, pose.rotation); }
F SPPose3D SPPose3DTranslate(SPPose3D pose, SPSize3D offset) { return SPPose3DMakeWithVector(pose.position + offset.vector, pose.rotation); }
/* mirrored through the plane across flipAxis: the position flips, the rotation turns the mirrored way */
F SPPose3D SPPose3DFlip(SPPose3D pose, SPAxis flipAxis) {
    simd_double3 f = _spd_flipscale(flipAxis), imag = -f * pose.rotation.vector.xyz;
    return SPPose3DMakeWithVector(pose.position * f, simd_quaternion(imag.x, imag.y, imag.z, pose.rotation.vector.w));
}

/* ---- SPScaledPose3D ---- */
F SPScaledPose3D SPScaledPose3DMakeWithVector(simd_double3 position, simd_quatd rotation, double scale) { SPScaledPose3D p = { position, rotation, scale }; return p; }
F SPScaledPose3D SPScaledPose3DMake(SPPoint3D position, SPRotation3D rotation, double scale) { return SPScaledPose3DMakeWithVector(position.vector, rotation.quaternion, scale); }
F SPScaledPose3D SPScaledPose3DMake(SPPose3D pose, double scale) { return SPScaledPose3DMakeWithVector(pose.position, pose.rotation, scale); }
F SPScaledPose3D SPScaledPose3DMakeLookAt(SPPoint3D position, SPPoint3D target, double scale, SPVector3D up) { return SPScaledPose3DMakeWithVector(position.vector, _spd_forward(target.vector - position.vector, up.vector), scale); }
F SPScaledPose3D SPScaledPose3DMakeLookAt(SPPoint3D target, double scale, SPVector3D up) { return SPScaledPose3DMakeWithVector((simd_double3)0, _spd_forward(target.vector, up.vector), scale); }
F SPScaledPose3D SPScaledPose3DMakeLookAt(SPVector3D forward, double scale, SPVector3D up) { return SPScaledPose3DMakeWithVector((simd_double3)0, _spd_forward(forward.vector, up.vector), scale); }
/* invalid when the scale is not uniform and positive, or the transform shears */
F SPScaledPose3D SPScaledPose3DMakeWithAffineTransform(SPAffineTransform3D transform) {
    simd_double3 s; simd_quatd q;
    if (!_spd_decompose(_spd_linear(transform.matrix), &s, &q) || !(s.x > 0) || !_spd_uniform(s, (SPAxis)(SPAxisX | SPAxisY | SPAxisZ))) return SPScaledPose3DInvalid;
    return SPScaledPose3DMakeWithVector(transform.matrix.columns[3], q, s.x);
}
F SPScaledPose3D SPScaledPose3DMakeWithProjectiveTransform(SPProjectiveTransform3D transform) { return _spd_isaffine(transform.matrix) ? SPScaledPose3DMakeWithAffineTransform(_spd_affine4(transform.matrix)) : SPScaledPose3DInvalid; }
F SPScaledPose3D SPScaledPose3DMakeWith4x4Matrix(simd_double4x4 matrix) { SPProjectiveTransform3D t = { matrix }; return SPScaledPose3DMakeWithProjectiveTransform(t); }
F simd_double4x4 SPScaledPose3DGet4x4Matrix(SPScaledPose3D scaledPose) { return _spd_m44(SPAffineTransform3DMakeWithScaledPose(scaledPose).matrix); }
F SPScaledPose3D SPScaledPose3DGetInverse(SPScaledPose3D scaledPose) { simd_quatd r = simd_inverse(scaledPose.rotation); double s = scaledPose.scale == 0 ? 0 : 1 / scaledPose.scale; return SPScaledPose3DMakeWithVector(-simd_act(r, scaledPose.position) * s, r, s); }
F SPScaledPose3D SPScaledPose3DConcatenation(SPScaledPose3D lhs, SPScaledPose3D rhs) { return SPScaledPose3DMakeWithVector(simd_act(lhs.rotation, rhs.position * lhs.scale) + lhs.position, simd_mul(lhs.rotation, rhs.rotation), lhs.scale * rhs.scale); }
F SPScaledPose3D SPScaledPose3DConcatenation(SPScaledPose3D lhs, SPPose3D rhs) { return SPScaledPose3DConcatenation(lhs, SPScaledPose3DMake(rhs, 1)); }
F SPScaledPose3D SPScaledPose3DConcatenation(SPPose3D lhs, SPScaledPose3D rhs) { return SPScaledPose3DConcatenation(SPScaledPose3DMake(lhs, 1), rhs); }
F bool SPScaledPose3DIsIdentity(SPScaledPose3D scaledPose) { return _spd_zero3(scaledPose.position) && _spd_zero3(scaledPose.rotation.vector.xyz) && fabs(scaledPose.rotation.vector.w) == 1 && scaledPose.scale == 1; }
F bool SPScaledPose3DIsValid(SPScaledPose3D pose) { return _spd_finite3(pose.position) && isfinite(pose.scale) && SPRotation3DIsValid(SPRotation3DMakeWithQuaternion(pose.rotation)); }
F bool SPScaledPose3DEqualToPose(SPScaledPose3D scaledPose1, SPScaledPose3D scaledPose2) {
    return _spd_eq3(scaledPose1.position, scaledPose2.position) && scaledPose1.scale == scaledPose2.scale
        && SPRotation3DEqualToRotation(SPRotation3DMakeWithQuaternion(scaledPose1.rotation), SPRotation3DMakeWithQuaternion(scaledPose2.rotation));
}
F bool SPScaledPose3DAlmostEqualToPose(SPScaledPose3D p1, SPScaledPose3D p2, double tolerance) {
    return _spd_close3(p1.position, p2.position, tolerance) && fabs(p1.scale - p2.scale) <= tolerance
        && SPRotation3DAlmostEqualToRotation(SPRotation3DMakeWithQuaternion(p1.rotation), SPRotation3DMakeWithQuaternion(p2.rotation), tolerance);
}
F bool SPScaledPose3DAlmostEqualToPose(SPScaledPose3D p1, SPScaledPose3D p2) { return SPScaledPose3DAlmostEqualToPose(p1, p2, _spd_eps()); }
F SPScaledPose3D SPScaledPose3DRotate(SPScaledPose3D scaledPose, SPRotation3D rotation) { return SPScaledPose3DMakeWithVector(simd_act(rotation.quaternion, scaledPose.position), simd_mul(rotation.quaternion, scaledPose.rotation), scaledPose.scale); }
F SPScaledPose3D SPScaledPose3DRotateByQuaternion(SPScaledPose3D scaledPose, simd_quatd quaternion) { return SPScaledPose3DRotate(scaledPose, SPRotation3DMakeWithQuaternion(quaternion)); }
F SPScaledPose3D SPScaledPose3DTranslate(SPScaledPose3D scaledPose, SPVector3D offset) { return SPScaledPose3DMakeWithVector(scaledPose.position + offset.vector, scaledPose.rotation, scaledPose.scale); }
F SPScaledPose3D SPScaledPose3DFlip(SPScaledPose3D scaledPose, SPAxis flipAxis) { SPPose3D p = SPPose3DFlip(SPPose3DMakeWithVector(scaledPose.position, scaledPose.rotation), flipAxis); return SPScaledPose3DMake(p, scaledPose.scale); }

/* ---- applying transforms ---- */
F SPPoint3D SPPoint3DApplyAffineTransform(SPPoint3D point, SPAffineTransform3D transform) { return SPPoint3DMakeWithVector(_spd_affine(transform.matrix, point.vector, true)); }
F SPPoint3D SPPoint3DApplyProjectiveTransform(SPPoint3D point, SPProjectiveTransform3D transform) { return SPPoint3DMakeWithVector(_spd_proj(transform.matrix, point.vector, true)); }
F SPPoint3D SPPoint3DApplyPose(SPPoint3D point, SPPose3D pose) { return SPPoint3DMakeWithVector(simd_act(pose.rotation, point.vector) + pose.position); }
F SPPoint3D SPPoint3DApplyScaledPose(SPPoint3D point, SPScaledPose3D pose) { return SPPoint3DMakeWithVector(simd_act(pose.rotation, point.vector * pose.scale) + pose.position); }
F SPPoint3D SPPoint3DUnapplyAffineTransform(SPPoint3D point, SPAffineTransform3D transform) { return SPPoint3DApplyAffineTransform(point, SPAffineTransform3DInverted(transform)); }
F SPPoint3D SPPoint3DUnapplyProjectiveTransform(SPPoint3D point, SPProjectiveTransform3D transform) { return SPPoint3DApplyProjectiveTransform(point, SPProjectiveTransform3DInverted(transform)); }
F SPPoint3D SPPoint3DUnapplyPose(SPPoint3D point, SPPose3D pose) { return SPPoint3DMakeWithVector(simd_act(simd_inverse(pose.rotation), point.vector - pose.position)); }
F SPPoint3D SPPoint3DUnapplyScaledPose(SPPoint3D point, SPScaledPose3D pose) { return SPPoint3DApplyScaledPose(point, SPScaledPose3DGetInverse(pose)); }
F SPVector3D SPVector3DApplyAffineTransform(SPVector3D vector, SPAffineTransform3D transform) { return SPVector3DMakeWithVector(_spd_affine(transform.matrix, vector.vector, false)); }
F SPVector3D SPVector3DApplyProjectiveTransform(SPVector3D vector, SPProjectiveTransform3D transform) { return SPVector3DMakeWithVector(_spd_proj(transform.matrix, vector.vector, false)); }
F SPVector3D SPVector3DApplyPose(SPVector3D vector, SPPose3D pose) { return SPVector3DMakeWithVector(simd_act(pose.rotation, vector.vector)); }
F SPVector3D SPVector3DApplyScaledPose(SPVector3D vector, SPScaledPose3D pose) { return SPVector3DMakeWithVector(simd_act(pose.rotation, vector.vector * pose.scale)); }
F SPVector3D SPVector3DUnapplyAffineTransform(SPVector3D vector, SPAffineTransform3D transform) { return SPVector3DApplyAffineTransform(vector, SPAffineTransform3DInverted(transform)); }
F SPVector3D SPVector3DUnapplyProjectiveTransform(SPVector3D vector, SPProjectiveTransform3D transform) { return SPVector3DApplyProjectiveTransform(vector, SPProjectiveTransform3DInverted(transform)); }
F SPVector3D SPVector3DUnapplyPose(SPVector3D vector, SPPose3D pose) { return SPVector3DMakeWithVector(simd_act(simd_inverse(pose.rotation), vector.vector)); }
F SPVector3D SPVector3DUnapplyScaledPose(SPVector3D vector, SPScaledPose3D pose) { return SPVector3DMakeWithVector(simd_act(simd_inverse(pose.rotation), vector.vector) / (pose.scale == 0 ? 1 : pose.scale)); }
F SPSize3D SPSize3DApplyAffineTransform(SPSize3D size, SPAffineTransform3D transform) { return SPSize3DMakeWithVector(_spd_affine(transform.matrix, size.vector, false)); }
F SPSize3D SPSize3DApplyProjectiveTransform(SPSize3D size, SPProjectiveTransform3D transform) { return SPSize3DMakeWithVector(_spd_proj(transform.matrix, size.vector, false)); }
F SPSize3D SPSize3DApplyPose(SPSize3D size, SPPose3D pose) { return SPSize3DMakeWithVector(simd_act(pose.rotation, size.vector)); }
F SPSize3D SPSize3DApplyScaledPose(SPSize3D size, SPScaledPose3D pose) { return SPSize3DMakeWithVector(simd_act(pose.rotation, size.vector * pose.scale)); }
F SPSize3D SPSize3DUnapplyAffineTransform(SPSize3D size, SPAffineTransform3D transform) { return SPSize3DApplyAffineTransform(size, SPAffineTransform3DInverted(transform)); }
F SPSize3D SPSize3DUnapplyProjectiveTransform(SPSize3D size, SPProjectiveTransform3D transform) { return SPSize3DApplyProjectiveTransform(size, SPProjectiveTransform3DInverted(transform)); }
F SPSize3D SPSize3DUnapplyPose(SPSize3D size, SPPose3D pose) { return SPSize3DMakeWithVector(simd_act(simd_inverse(pose.rotation), size.vector)); }
F SPSize3D SPSize3DUnapplyScaledPose(SPSize3D size, SPScaledPose3D pose) { return SPSize3DMakeWithVector(simd_act(simd_inverse(pose.rotation), size.vector) / (pose.scale == 0 ? 1 : pose.scale)); }

/* ---- SPRect3D ---- */
F SPRect3D SPRect3DMakeAtOriginWithVector(simd_double3 origin, simd_double3 size) { SPRect3D r; r.origin.vector = origin; r.size.vector = size; return r; }
F SPRect3D SPRect3DMakeAtOriginWithVector(SPVector3D origin, SPVector3D size) { return SPRect3DMakeAtOriginWithVector(origin.vector, size.vector); }
F SPRect3D SPRect3DMakeAtCenterWithVector(simd_double3 center, simd_double3 size) { return SPRect3DMakeAtOriginWithVector(center - size / 2, size); }
F SPRect3D SPRect3DMakeAtCenterWithVector(SPVector3D center, SPVector3D size) { return SPRect3DMakeAtCenterWithVector(center.vector, size.vector); }
F SPRect3D SPRect3DMakeBoundingFromPoints(SPPoint3D points[], int pointCount) {
    if (pointCount <= 0) return SPRect3DZero;
    simd_double3 lo = points[0].vector, hi = lo;
    for (int i = 1; i < pointCount; i++) { lo = simd_min(lo, points[i].vector); hi = simd_max(hi, points[i].vector); }
    return _spd_rect(lo, hi);
}
F void SPRect3DGetCornerPoints(SPRect3D rect, SPPoint3D points[]) { simd_double3 c[8]; _spd_corners(rect, c); for (int i = 0; i < 8; i++) points[i].vector = c[i]; }
F bool SPRect3DEqualToRect(SPRect3D rect1, SPRect3D rect2) { return _spd_eq3(rect1.origin.vector, rect2.origin.vector) && _spd_eq3(rect1.size.vector, rect2.size.vector); }
F bool SPRect3DIsFinite(SPRect3D rect) { return _spd_finite3(rect.origin.vector) && _spd_finite3(rect.size.vector); }
F bool SPRect3DIsNaN(SPRect3D rect) { return _spd_nan3(rect.origin.vector) || _spd_nan3(rect.size.vector); }
F bool SPRect3DIsZero(SPRect3D rect) { return _spd_zero3(rect.origin.vector) && _spd_zero3(rect.size.vector); }
F bool SPRect3DIsNull(SPRect3D rect) { return isinf(rect.origin.x) || isinf(rect.origin.y) || isinf(rect.origin.z); }
F bool SPRect3DContainsPoint(SPRect3D rect, SPPoint3D other) { return simd_all(other.vector >= _spd_rmin(rect)) && simd_all(other.vector <= _spd_rmax(rect)); }
F bool SPRect3DContainsRect(SPRect3D rect, SPRect3D other) { return SPRect3DContainsPoint(rect, SPPoint3DMakeWithVector(_spd_rmin(other))) && SPRect3DContainsPoint(rect, SPPoint3DMakeWithVector(_spd_rmax(other))); }
F bool SPRect3DContainsAnyPoint(SPRect3D rect, const SPPoint3D *points, int pointCount) { for (int i = 0; i < pointCount; i++) if (SPRect3DContainsPoint(rect, points[i])) return true; return false; }
F SPRect3D SPRect3DUnion(SPRect3D rect, SPRect3D other) { return _spd_rect(simd_min(_spd_rmin(rect), _spd_rmin(other)), simd_max(_spd_rmax(rect), _spd_rmax(other))); }
/* SPRect3DNull when they do not meet */
F SPRect3D SPRect3DIntersection(SPRect3D rect, SPRect3D other) {
    simd_double3 lo = simd_max(_spd_rmin(rect), _spd_rmin(other)), hi = simd_min(_spd_rmax(rect), _spd_rmax(other));
    return simd_all(lo <= hi) ? _spd_rect(lo, hi) : SPRect3DNull;
}
F double SPRect3DDistanceBetweenOrigins(SPRect3D rect, SPRect3D other) { return simd_distance(rect.origin.vector, other.origin.vector); }
/* the gap between the boxes (0 when they touch or overlap) */
F double SPRect3DDistanceToRect(SPRect3D rect, SPRect3D other) {
    simd_double3 gap = simd_max(simd_max(_spd_rmin(other) - _spd_rmax(rect), _spd_rmin(rect) - _spd_rmax(other)), (simd_double3)0);
    return simd_length(gap);
}
F SPRotation3D SPRect3DRotationToRect(SPRect3D rect, SPRect3D other) {
    return SPRotation3DMakeWithQuaternion(simd_quaternion(rect.origin.vector + rect.size.vector / 2, other.origin.vector + other.size.vector / 2));
}
F SPRect3D SPRect3DTranslate(SPRect3D rect, SPVector3D offset) { rect.origin.vector += offset.vector; return rect; }
F SPRect3D SPRect3DTranslate(SPRect3D rect, SPSize3D offset) { rect.origin.vector += offset.vector; return rect; }
F SPRect3D SPRect3DScaleBySize(SPRect3D rect, SPSize3D scale) { rect.origin.vector *= scale.vector; rect.size.vector *= scale.vector; return rect; }
F SPRect3D SPRect3DScaleBy(SPRect3D rect, double x, double y, double z) { return SPRect3DScaleBySize(rect, SPSize3DMake(x, y, z)); }
F SPRect3D SPRect3DScaleUniform(SPRect3D rect, double scale) { return SPRect3DScaleBySize(rect, SPSize3DMake(scale, scale, scale)); }
#define _SPD_AROUND(rect, expr) do { simd_double3 c[8]; _spd_corners(rect, c); for (int i = 0; i < 8; i++) { simd_double3 p = c[i]; c[i] = (expr); } return _spd_bound(c); } while (0)
F SPRect3D SPRect3DShear(SPRect3D rect, SPAxis shearAxis, double shearFactor0, double shearFactor1) { simd_double3x3 m = _spd_shear(shearAxis, shearFactor0, shearFactor1); _SPD_AROUND(rect, simd_mul(m, p)); }
F SPRect3D SPRect3DRotateByQuaternion(SPRect3D rect, simd_quatd quaternion) { _SPD_AROUND(rect, simd_act(quaternion, p)); }
F SPRect3D SPRect3DRotate(SPRect3D rect, SPRotation3D rotation) { return SPRect3DRotateByQuaternion(rect, rotation.quaternion); }
F SPRect3D SPRect3DApplyAffineTransform(SPRect3D rect, SPAffineTransform3D transform) { _SPD_AROUND(rect, _spd_affine(transform.matrix, p, true)); }
F SPRect3D SPRect3DApplyProjectiveTransform(SPRect3D rect, SPProjectiveTransform3D transform) { _SPD_AROUND(rect, _spd_proj(transform.matrix, p, true)); }
F SPRect3D SPRect3DApplyPose(SPRect3D rect, SPPose3D pose) { _SPD_AROUND(rect, simd_act(pose.rotation, p) + pose.position); }
F SPRect3D SPRect3DApplyScaledPose(SPRect3D rect, SPScaledPose3D pose) { _SPD_AROUND(rect, simd_act(pose.rotation, p * pose.scale) + pose.position); }
F SPRect3D SPRect3DUnapplyAffineTransform(SPRect3D rect, SPAffineTransform3D transform) { return SPRect3DApplyAffineTransform(rect, SPAffineTransform3DInverted(transform)); }
F SPRect3D SPRect3DUnapplyProjectiveTransform(SPRect3D rect, SPProjectiveTransform3D transform) { return SPRect3DApplyProjectiveTransform(rect, SPProjectiveTransform3DInverted(transform)); }
F SPRect3D SPRect3DUnapplyPose(SPRect3D rect, SPPose3D pose) { return SPRect3DApplyPose(rect, SPPose3DGetInverse(pose)); }
F SPRect3D SPRect3DUnapplyScaledPose(SPRect3D rect, SPScaledPose3D pose) { return SPRect3DApplyScaledPose(rect, SPScaledPose3DGetInverse(pose)); }
#undef _SPD_AROUND

/* ---- SPRay3D ---- */
/* the direction is normalized */
F SPRay3D SPRay3DMakeWithVector(simd_double3 origin, simd_double3 direction) { SPRay3D r; double l = simd_length(direction); r.origin.vector = origin; r.direction.vector = l > 0 ? direction / l : direction; return r; }
F SPRay3D SPRay3DMake(SPPoint3D origin, SPVector3D direction) { return SPRay3DMakeWithVector(origin.vector, direction.vector); }
F bool SPRay3DEqualToRay(SPRay3D ray1, SPRay3D ray2) { return _spd_eq3(ray1.origin.vector, ray2.origin.vector) && _spd_eq3(ray1.direction.vector, ray2.direction.vector); }
F bool SPRay3DIsFinite(SPRay3D ray) { return _spd_finite3(ray.origin.vector) && _spd_finite3(ray.direction.vector); }
F bool SPRay3DIsNaN(SPRay3D ray) { return _spd_nan3(ray.origin.vector) || _spd_nan3(ray.direction.vector); }
F bool SPRay3DIsZero(SPRay3D ray) { return _spd_zero3(ray.origin.vector) && _spd_zero3(ray.direction.vector); }
/* the slab test, ahead of the origin only */
F bool SPRay3DIntersectsRect(SPRay3D ray, SPRect3D rect) {
    simd_double3 o = ray.origin.vector, d = ray.direction.vector, lo = _spd_rmin(rect), hi = _spd_rmax(rect);
    double t0 = 0, t1 = INFINITY;
    for (int i = 0; i < 3; i++) {
        if (d[i] == 0) { if (o[i] < lo[i] || o[i] > hi[i]) return false; continue; }
        double a = (lo[i] - o[i]) / d[i], b = (hi[i] - o[i]) / d[i];
        if (a > b) { double t = a; a = b; b = t; }
        if (a > t0) t0 = a;
        if (b < t1) t1 = b;
        if (t0 > t1) return false;
    }
    return true;
}
F SPRay3D SPRay3DTranslate(SPRay3D ray, SPVector3D offset) { ray.origin.vector += offset.vector; return ray; }
F SPRay3D SPRay3DTranslate(SPRay3D ray, SPSize3D offset) { ray.origin.vector += offset.vector; return ray; }
F SPRay3D SPRay3DRotateByQuaternion(SPRay3D ray, simd_quatd quaternion) { return SPRay3DMakeWithVector(simd_act(quaternion, ray.origin.vector), simd_act(quaternion, ray.direction.vector)); }
F SPRay3D SPRay3DRotate(SPRay3D ray, SPRotation3D rotation) { return SPRay3DRotateByQuaternion(ray, rotation.quaternion); }
F SPRay3D SPRay3DRotateByQuaternionAroundPoint(SPRay3D ray, simd_quatd quaternion, SPPoint3D pivot) {
    return SPRay3DMakeWithVector(simd_act(quaternion, ray.origin.vector - pivot.vector) + pivot.vector, simd_act(quaternion, ray.direction.vector));
}
F SPRay3D SPRay3DRotateAroundPoint(SPRay3D ray, SPRotation3D rotation, SPPoint3D pivot) { return SPRay3DRotateByQuaternionAroundPoint(ray, rotation.quaternion, pivot); }
F SPRay3D SPRay3DApplyAffineTransform(SPRay3D ray, SPAffineTransform3D transform) { return SPRay3DMakeWithVector(_spd_affine(transform.matrix, ray.origin.vector, true), _spd_affine(transform.matrix, ray.direction.vector, false)); }
/* the direction is that between the transformed origin and the transformed point one step along the ray */
F SPRay3D SPRay3DApplyProjectiveTransform(SPRay3D ray, SPProjectiveTransform3D transform) {
    simd_double3 o = _spd_proj(transform.matrix, ray.origin.vector, true), e = _spd_proj(transform.matrix, ray.origin.vector + ray.direction.vector, true);
    return SPRay3DMakeWithVector(o, e - o);
}
F SPRay3D SPRay3DApplyPose(SPRay3D ray, SPPose3D pose) { return SPRay3DMakeWithVector(simd_act(pose.rotation, ray.origin.vector) + pose.position, simd_act(pose.rotation, ray.direction.vector)); }
F SPRay3D SPRay3DApplyScaledPose(SPRay3D ray, SPScaledPose3D pose) { return SPRay3DMakeWithVector(simd_act(pose.rotation, ray.origin.vector * pose.scale) + pose.position, simd_act(pose.rotation, ray.direction.vector * pose.scale)); }
F SPRay3D SPRay3DUnapplyAffineTransform(SPRay3D ray, SPAffineTransform3D transform) { return SPRay3DApplyAffineTransform(ray, SPAffineTransform3DInverted(transform)); }
F SPRay3D SPRay3DUnapplyProjectiveTransform(SPRay3D ray, SPProjectiveTransform3D transform) { return SPRay3DApplyProjectiveTransform(ray, SPProjectiveTransform3DInverted(transform)); }
F SPRay3D SPRay3DUnapplyPose(SPRay3D ray, SPPose3D pose) { return SPRay3DApplyPose(ray, SPPose3DGetInverse(pose)); }
F SPRay3D SPRay3DUnapplyScaledPose(SPRay3D ray, SPScaledPose3D pose) { return SPRay3DApplyScaledPose(ray, SPScaledPose3DGetInverse(pose)); }
"""

# conversions between the double and float types (iOS 26), added after both are generated
CONVERSIONS = [
    ("SPPoint3D", "point", "{T} r; r.vector = __builtin_convertvector(point.vector, {V3}); return r;"),
    ("SPVector3D", "vector", "{T} r; r.vector = __builtin_convertvector(vector.vector, {V3}); return r;"),
    ("SPSize3D", "size", "{T} r; r.vector = __builtin_convertvector(size.vector, {V3}); return r;"),
    ("SPRotationAxis3D", "axis", "{T} r; r.vector = __builtin_convertvector(axis.vector, {V3}); return r;"),
    ("SPRotation3D", "rotation", "{T} r; r.vector = __builtin_convertvector(rotation.vector, {V4}); return r;"),
    ("SPAngle", "angle", "{T} r = {{ angle.radians }}; return r;"),
    ("SPRect3D", "rect", "{T} r; r.origin.vector = __builtin_convertvector(rect.origin.vector, {V3}); r.size.vector = __builtin_convertvector(rect.size.vector, {V3}); return r;"),
    ("SPRay3D", "ray", "{T} r; r.origin.vector = __builtin_convertvector(ray.origin.vector, {V3}); r.direction.vector = __builtin_convertvector(ray.direction.vector, {V3}); return r;"),
    ("SPSphericalCoordinates3D", "coords", "{T} r; r.radius = coords.radius; r.inclination.radians = coords.inclination.radians; r.azimuth.radians = coords.azimuth.radians; return r;"),
    ("SPAffineTransform3D", "transform", "{T} r; for (int c = 0; c < 4; c++) r.matrix.columns[c] = __builtin_convertvector(transform.matrix.columns[c], {V3}); return r;"),
    ("SPProjectiveTransform3D", "transform", "{T} r; for (int c = 0; c < 4; c++) r.matrix.columns[c] = __builtin_convertvector(transform.matrix.columns[c], {V4}); return r;"),
    ("SPPose3D", "pose", "{T} r; r.position = __builtin_convertvector(pose.position, {V3}); r.rotation.vector = __builtin_convertvector(pose.rotation.vector, {V4}); return r;"),
    ("SPScaledPose3D", "pose", "{T} r; r.position = __builtin_convertvector(pose.position, {V3}); r.rotation.vector = __builtin_convertvector(pose.rotation.vector, {V4}); r.scale = pose.scale; return r;"),
]

KINDS = r"Point|Vector|Size|Rect|Ray|RotationAxis|Rotation|ScaledPose|Pose|AffineTransform|ProjectiveTransform|SphericalCoordinates"


# functions outside Apple's documented list (Apple documents these through their Swift names), kept in both precisions
EXTRAS = ["SPAngleMakeWithRadians", "SPAngleMakeWithDegrees", "SPAngleGetDegrees", "SPRotation3DMakeWithEulerAngles",
          "SPRotation3DGetEulerAngles", "SPPoint3DDistanceToPoint"]


def to_float(s):
    s = re.sub(r"\bSP(%s)3D(?!Float)" % KINDS, r"SP\g<1>3DFloat", s)
    s = re.sub(r"\bSPAngle(?!Float|Order)", "SPAngleFloat", s)
    s = re.sub(r"\bSPEulerAngles(?!Float)", "SPEulerAnglesFloat", s)
    s = s.replace("SPVectorInfinity", "SPVector3DFloatInfinity")
    s = s.replace("simd_double", "simd_float").replace("simd_quatd", "simd_quatf").replace("simd_packed_double4", "simd_packed_float4")
    s = s.replace("matrix_identity_double", "matrix_identity_float")
    s = re.sub(r"\bdouble\b", "float", s)
    s = s.replace("_spd_", "_spf_").replace("_SPD_", "_SPF_").replace("DBL_MAX", "FLT_MAX")
    s = re.sub(r"\b(acosh|asinh|atanh|acos|asin|atan2|atan|cosh|sinh|tanh|cos|sin|tan|fabs|fmod|sqrt)\(", r"\1f(", s)
    s = s.replace("simd_make_double", "simd_make_float")
    s = s.replace("1.4901161193847656e-08", "3.4526698300124393e-04").replace("0.9999999", "0.9999")
    s = s.replace("1e-9", "1e-5").replace("1e-12", "1e-6").replace("fabsf(l - 1) < 1e-6", "fabsf(l - 1) < 1e-3")
    s = s.replace("M_PI", "(float)M_PI")
    # every floating literal is a float: no double arithmetic, no ambiguous overloads (simd_quaternion(0.0, …))
    s = re.sub(r"(?<![\w.])(\d+\.\d*(?:e-?\d+)?|\d+e-?\d+)(?![\w.])", r"\1f", s)
    return s


def funcs(text, F, H, keep=None):
    """the functions of text with F / H expanded; keep: the API names to keep (None: all). O marks a function Apple has only
    as …Float: kept only in the float pass (keep given)."""
    out, cur = [], []
    for line in text.splitlines(True):
        if line.startswith(("F ", "H ", "O ")) and cur:
            out.append("".join(cur)); cur = []
        cur.append(line)
    if cur:
        out.append("".join(cur))
    res = []
    for block in out:
        if block.startswith("O "):
            if keep is None:
                continue
            block = "F" + block[1:]
        m = re.match(r"F \S+ (\w+)\(", block)
        if m and keep is not None and m.group(1) not in keep:
            continue
        res.append(re.sub(r"^F ", F + " ", re.sub(r"^H ", H + " ", block, flags=re.M), flags=re.M))
    return "".join(res)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    names = set()
    with open(os.path.join(here, "..", "data", "spatial-float-names.txt")) as f:
        names = {l.strip() for l in f if l.strip() and not l.startswith("#")}
    F = "SPATIAL_INLINE SPATIAL_OVERLOADABLE"
    H = "SPATIAL_INLINE SPATIAL_OVERLOADABLE"
    double_text = funcs(FUNCS, F, H)
    extras = {to_float(n) for n in EXTRAS}
    float_text = funcs(to_float(FUNCS), F, H, keep=names | extras | {n for n in re.findall(r"^H \S+ (\w+)\(", to_float(FUNCS), re.M)})
    conv = []
    for t, arg, body in CONVERSIONS:
        tf = to_float(t)
        for src, dst, V3, V4 in ((t, tf, "simd_float3", "simd_float4"), (tf, t, "simd_double3", "simd_double4")):
            name = dst + "Make"
            conv.append(f"{F} {dst} {name}({src} {arg}) {{ " + body.format(T=dst, V3=V3, V4=V4) + " }\n")
    header = """#pragma once
/* isim Spatial for C and Objective-C (issue #692; generated by tools/spatial-headers.py): Apple's SP* types and their
 * inline functions over <simd/simd.h>, header-only like Apple's. The semantics are those of isim's Swift Spatial overlay
 * (swift/overlays/Spatial), which Swift uses; these declarations are hidden from Swift. The …Float types and functions
 * are iOS 26. */
#include <simd/simd.h>
#include <math.h>
#include <float.h>
#include <stdbool.h>
#if !defined(__swift__)
#define SPATIAL_INLINE static inline __attribute__((__always_inline__, __nodebug__))
#define SPATIAL_OVERLOADABLE __attribute__((__overloadable__))
#define SPATIAL_REFINED_FOR_SWIFT
#define SPATIAL_SWIFT_NAME(_name)
#define SPPoint3D__MAKE3(s) SPPoint3DMake((s).x, (s).y, (s).z)
#define SPVector3D__MAKE3(s) SPVector3DMake((s).x, (s).y, (s).z)
#define SPSize3D__MAKE3(s) SPSize3DMake((s).x, (s).y, (s).z)
#define SPPoint3DFloat__MAKE3(s) SPPoint3DFloatMake((s).x, (s).y, (s).z)
#define SPVector3DFloat__MAKE3(s) SPVector3DFloatMake((s).x, (s).y, (s).z)
#define SPSize3DFloat__MAKE3(s) SPSize3DFloatMake((s).x, (s).y, (s).z)
#define SP__PACK(v3, w) ((__typeof__(simd_make_double4((v3), (w))))simd_make_double4((v3), (w)))
"""
    header = header.replace("#define SP__PACK(v3, w) ((__typeof__(simd_make_double4((v3), (w))))simd_make_double4((v3), (w)))\n",
                            "")
    body = []
    body.append(TYPES)
    body.append(to_float(TYPES).replace("typedef enum { SPAxisX = 1, SPAxisY = 2, SPAxisZ = 4 } SPAxis;\n", "")
                .replace("typedef enum { SPEulerXYZ = 1, SPEulerZXY = 2, SPEulerPitchYawRoll = 1 } SPEulerAngleOrder;\n", ""))
    body.append(CONSTS)
    fconsts = to_float(CONSTS)
    body.append("\n".join(l for l in fconsts.splitlines() if re.search(r"\b(SP\w+Float\w*)\s*=", l) and re.search(r"\b(SP\w+Float\w*)\s*=", l).group(1) in names))
    body.append("\n/* packs a 3-vector and a fourth value into a packed 4-vector */\n")
    body.append("SPATIAL_INLINE SPATIAL_OVERLOADABLE simd_packed_double4 SP__PACK(simd_double3 v, double w) { simd_packed_double4 p; p.x = v.x; p.y = v.y; p.z = v.z; p.w = w; return p; }\n")
    body.append("SPATIAL_INLINE SPATIAL_OVERLOADABLE simd_packed_float4 SP__PACK(simd_float3 v, float w) { simd_packed_float4 p; p.x = v.x; p.y = v.y; p.z = v.z; p.w = w; return p; }\n")
    body.append(double_text)
    body.append("\n/* ---- the Float variants (iOS 26) ---- */\n")
    body.append(float_text)
    body.append("\n/* ---- double <-> float ---- */\n")
    body.append("".join(conv))
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Spatial.h"), "w") as f:
        f.write(header + "".join(body) + "\n#endif\n")


main()
