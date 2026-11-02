// The C simd interface (SimdCTest.app, issue #800): vectors, geometry, common functions, logic, matrices and
// quaternions from <simd/simd.h>, printed one result per line ("name values"). test_simd.py compares the lines with
// SimdSwiftTest's, which computes the same with Swift's simd.
#import <Foundation/Foundation.h>
#include <simd/simd.h>
#include <stdio.h>

static void p(const char *name, const double *v, int n) {
    printf("%s", name);
    for (int i = 0; i < n; i++) printf(" %.4f", fabs(v[i]) < 5e-5 ? 0.0 : v[i]);
    printf("\n");
}
#define P3(name, v) do { double t[3] = { (v).x, (v).y, (v).z }; p(name, t, 3); } while (0)
#define P4(name, v) do { double t[4] = { (v).x, (v).y, (v).z, (v).w }; p(name, t, 4); } while (0)
#define P1(name, v) do { double t[1] = { (v) }; p(name, t, 1); } while (0)

int main(void) {
    @autoreleasepool {
        simd_float3 a = simd_make_float3(1, 2, 3), b = { 4, -5, 6 };
        P3("cross", simd_cross(a, b));
        P1("dot", simd_dot(a, b));
        P1("length", simd_length(a));
        P3("normalize", simd_normalize(a));
        P1("distance", simd_distance(a, b));
        P3("reflect", simd_reflect(a, simd_normalize((simd_float3){ 0, 1, 0 })));
        P3("project", simd_project(a, b));

        simd_float4 v = { -1.5f, 0.25f, 2.75f, -0.5f }, w = { 1, 1, 1, 1 };
        P4("abs", simd_abs(v));
        P4("min", simd_min(v, w));
        P4("max", simd_max(v, w));
        P4("clamp", simd_clamp(v, (simd_float4)-1, (simd_float4)1));
        P4("mix", simd_mix(v, w, (simd_float4)0.25f));
        P4("sign", simd_sign(v));
        P4("fract", simd_fract(v));
        P4("step", simd_step((simd_float4)0, v));
        P4("smoothstep", simd_smoothstep((simd_float4)-1, (simd_float4)1, v));
        P1("reduce_add", simd_reduce_add(v));
        P1("reduce_max", simd_reduce_max(v));
        P1("reduce_min", simd_reduce_min(v));
        P4("make4", simd_make_float4(a, 7));
        simd_int4 iv = { 1, -2, 3, -4 };
        P1("any", simd_any(iv < 0));
        P1("all", simd_all(iv < 4));
        P4("select", simd_select(v, w, iv < 0));

        simd_double4x4 m = simd_matrix((simd_double4){ 2, 0, 0, 0 }, (simd_double4){ 0, 3, 0, 0 }, (simd_double4){ 0, 0, 4, 0 }, (simd_double4){ 1, 2, 3, 1 });
        P1("det4", simd_determinant(m));
        simd_double4x4 inv = simd_inverse(m);
        P4("inv4c0", inv.columns[0]); P4("inv4c3", inv.columns[3]);
        P4("mul4v", simd_mul(m, (simd_double4){ 1, 1, 1, 1 }));
        simd_double4x4 id = simd_mul(m, inv);
        P1("mulinv_identity", simd_almost_equal_elements(id, matrix_identity_double4x4, 1e-9));
        simd_double4x4 tr = simd_transpose(m);
        P4("transpose_c3", tr.columns[3]);
        simd_float3x3 r = simd_matrix_from_rows((simd_float3){ 1, 2, 3 }, (simd_float3){ 0, 1, 4 }, (simd_float3){ 5, 6, 0 });
        P3("rows_c0", r.columns[0]);
        P1("det3", simd_determinant(r));
        simd_float3x3 ri = simd_inverse(r);
        P3("inv3c0", ri.columns[0]);
        simd_float3x3 rr = simd_mul(r, r);
        P3("mul3_c1", rr.columns[1]);

        simd_quatf q = simd_quaternion((float)M_PI / 2, (simd_float3){ 0, 0, 1 });
        P4("quat", q.vector);
        P3("act", simd_act(q, (simd_float3){ 1, 0, 0 }));
        P1("angle", simd_angle(q));
        P3("axis", simd_axis(q));
        simd_quatf h = simd_slerp(simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f), q, 0.5f);
        P4("slerp", h.vector);
        simd_float3x3 qm = simd_matrix3x3(q);
        P3("quatm_c0", qm.columns[0]);
        P4("quat_from_m", simd_quaternion(qm).vector);
        P4("quat_from_to", simd_quaternion((simd_float3){ 1, 0, 0 }, (simd_float3){ 0, 1, 0 }).vector);
        P4("quat_mul", simd_mul(q, q).vector);
        P4("quat_inverse", simd_inverse(q).vector);
        simd_quatd qd = simd_quaternion(M_PI / 3, (simd_double3){ 1, 0, 0 });
        simd_double4x4 qdm = simd_matrix4x4(qd);
        P4("quatd_m_c1", qdm.columns[1]);
        printf("SimdCTest: done\n");
    }
    return 0;
}
