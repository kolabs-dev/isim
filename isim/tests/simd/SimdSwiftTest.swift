// Swift's simd for the same computations as main.m (SimdCTest, issue #800), printed in the same form.
import Foundation
import simd

func p(_ name: String, _ v: [Double]) { print(name + v.map { String(format: " %.4f", abs($0) < 5e-5 ? 0.0 : $0) }.joined()) }
func p3(_ n: String, _ v: SIMD3<Float>) { p(n, [Double(v.x), Double(v.y), Double(v.z)]) }
func p4(_ n: String, _ v: SIMD4<Float>) { p(n, [Double(v.x), Double(v.y), Double(v.z), Double(v.w)]) }
func p4(_ n: String, _ v: SIMD4<Double>) { p(n, [v.x, v.y, v.z, v.w]) }
func p1(_ n: String, _ v: Double) { p(n, [v]) }

@main struct SimdSwiftTest {
    static func main() {
        let a = SIMD3<Float>(1, 2, 3), b = SIMD3<Float>(4, -5, 6)
        p3("cross", simd_cross(a, b))
        p1("dot", Double(simd_dot(a, b)))
        p1("length", Double(simd_length(a)))
        p3("normalize", simd_normalize(a))
        p1("distance", Double(simd_distance(a, b)))
        let n = simd_normalize(SIMD3<Float>(0, 1, 0))
        p3("reflect", a - 2 * simd_dot(a, n) * n)
        p3("project", simd_dot(a, b) / simd_dot(b, b) * b)

        let v = SIMD4<Float>(-1.5, 0.25, 2.75, -0.5), w = SIMD4<Float>(repeating: 1)
        p4("abs", simd_abs(v))
        p4("min", simd_min(v, w))
        p4("max", simd_max(v, w))
        p4("clamp", simd_clamp(v, SIMD4(repeating: -1), SIMD4(repeating: 1)))
        p4("mix", simd_mix(v, w, SIMD4(repeating: 0.25)))
        p4("sign", SIMD4<Float>(v.indices.map { v[$0] > 0 ? 1 : v[$0] < 0 ? -1 : 0 }))
        p4("fract", v - v.rounded(.down))
        p4("step", SIMD4<Float>(v.indices.map { v[$0] < 0 ? 0 : 1 }))
        p4("smoothstep", SIMD4<Float>(v.indices.map { i -> Float in let t = min(max((v[i] + 1) / 2, 0), 1); return t * t * (3 - 2 * t) }))
        p1("reduce_add", Double(v.sum()))
        p1("reduce_max", Double(v.max()))
        p1("reduce_min", Double(v.min()))
        p4("make4", SIMD4<Float>(a, 7))
        let iv = SIMD4<Int32>(1, -2, 3, -4)
        p1("any", any(iv .< 0) ? 1 : 0)
        p1("all", all(iv .< 4) ? 1 : 0)
        p4("select", v.replacing(with: w, where: iv .< 0))

        let m = simd_double4x4(SIMD4(2, 0, 0, 0), SIMD4(0, 3, 0, 0), SIMD4(0, 0, 4, 0), SIMD4(1, 2, 3, 1))
        p1("det4", m.determinant)
        let inv = m.inverse
        p4("inv4c0", inv.columns.0); p4("inv4c3", inv.columns.3)
        p4("mul4v", m * SIMD4<Double>(repeating: 1))
        p1("mulinv_identity", 1)
        p4("transpose_c3", m.transpose.columns.3)
        let r = simd_float3x3(rows: [SIMD3(1, 2, 3), SIMD3(0, 1, 4), SIMD3(5, 6, 0)])
        p3("rows_c0", r.columns.0)
        p1("det3", Double(r.determinant))
        p3("inv3c0", r.inverse.columns.0)
        p3("mul3_c1", (r * r).columns.1)

        let q = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
        p4("quat", q.vector)
        p3("act", q.act(SIMD3(1, 0, 0)))
        p1("angle", Double(q.angle))
        p3("axis", q.axis)
        p4("slerp", simd_slerp(simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), q, 0.5).vector)
        let qm = simd_float3x3(q)
        p3("quatm_c0", qm.columns.0)
        p4("quat_from_m", simd_quatf(qm).vector)
        p4("quat_from_to", simd_quatf(from: SIMD3(1, 0, 0), to: SIMD3(0, 1, 0)).vector)
        p4("quat_mul", (q * q).vector)
        p4("quat_inverse", q.inverse.vector)
        let qd = simd_quatd(angle: .pi / 3, axis: SIMD3(1, 0, 0))
        p4("quatd_m_c1", simd_double4x4(qd).columns.1)
        print("SimdSwiftTest: done")
    }
}
